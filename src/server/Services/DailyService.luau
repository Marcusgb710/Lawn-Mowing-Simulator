-- The day's contracts and the login streak (docs/superpowers/specs/2026-10-29-busy-season-design.md,
-- 2a and 2b): hands each player their three contracts when a new UTC day starts, advances their
-- streak when they come back, leaves the day's streak cash as a gift to claim, counts what they do
-- toward the contracts, and pays each contract the moment it is met.
--   Refresh   is the one place a day turns over. If the save's day is not today it makes today's
--             contracts (Config/Contracts.luau) with the counts at zero, then turns the streak
--             (Config/Streak.luau): a gift from the day before that was never claimed is paid now,
--             once, the streak moves on, and on day 7 it gives the pennant flag. The new day's cash
--             is not paid: it waits as a gift (the HUD's Gifts button shows a CLAIM tag).
--             It runs when a player joins and again every minute for everyone online, and a
--             second Refresh on the same day only pays a contract that was met but not yet paid.
--             When the day turns it also wakes the player's contest (ContestService): judging day
--             is a day of the week, and nothing else wakes the contest when midnight UTC comes.
--   Claim     (ClaimStreak) pays today's gift if it is waiting: marked claimed in the save, then the
--             cash, then the Payday card (StreakAdvanced). It turns the day first, so a claim just
--             after midnight claims the new day's gift (and the turn pays yesterday's).
--   Counting  a finished job adds a job, a three-star job when it got three stars, and the junk
--             picked up on the lawn; any money they earn (DataService.Earned) adds to the dollars
--             earned. Then every contract that is met is paid, and when all three are paid the
--             Bonus Day too.
-- The server decides all of it. The client is told where things stand (ContractsUpdated, the same
-- view GetContracts returns) and what was paid (ContractDone, BonusDay, StreakAdvanced for a claimed
-- gift, StreakGiftPaid for an unclaimed one the turn paid), to show it.
--
-- A contract is marked done in the save, and the client's totals sent, before its cash goes in, and
-- the cash goes in before the client is told, so a contract is never paid twice and the screen never
-- shows one the save doesn't have. If a pay fails part way, the contract stays marked and goes unpaid,
-- which is the safe side of that. The cash is money earned, so it counts toward the Earn contract
-- like any other pay; it is added at once, but any contract it meets is paid after the pay that
-- caused it, never in the middle of it.
--
-- Kept in the player's data (DataService, version 14; Config/Season.luau explains the fields):
--   daily    the day's contracts, what is done and counted toward them, and whether the Bonus Day is paid
--   streak   how many days in a row, the day it was last kept and the day whose gift was last claimed
--   flags    [flag id] = true for each cosmetic flag they own (day 7 of the streak gives TruckPennant)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contracts = require(Shared.Config.Contracts)
local Daily = require(Shared.Daily)
local Net = require(Shared.Net)
local Streak = require(Shared.Config.Streak)

local Clock = require(script.Parent.Parent.Clock)
local ContestService = require(script.Parent.ContestService)
local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local WorldService = require(script.Parent.WorldService)

local DailyService = {}

local SECONDS_PER_DAY = 86400
-- How often everyone online is looked at, so a day that turns over while they play is noticed.
local REFRESH_SECONDS = 60
-- Seconds between gift claims from one player, so the remote can't be spammed.
local CLAIM_COOLDOWN = 0.5

-- [Player] = true while they are being paid, by settle or by a gift (owed or claimed). Paying is money
-- earned, so it fires DataService.Earned, which counts the dollars and asks for a look at the
-- contracts in the middle of the pay; `recheck` remembers that one was asked for, so it is made once
-- the pay is done instead of inside it.
local paying = {}
local recheck = {}
-- [Player] = when they last asked to claim their gift (os.clock).
local lastClaim = {}

-- Runs one player's work so that an error in it is a warning, not the end of everyone else's.
local function guarded(what: string, player: Player, work: () -> ())
	local ok, err = pcall(work)
	if not ok then
		warn(`DailyService: {what} failed for {player.Name}: {err}`)
	end
end

-- The view the screen draws, from their save: today's contracts with how far along each is and
-- whether it is paid, the Bonus Day, and the streak with what tomorrow's day pays, whether the save's
-- day has a gift waiting to be claimed, and that gift's cash.
local function viewOf(data)
	local daily = data.daily
	local contracts = {}
	for _, contract in daily.contracts do
		table.insert(contracts, {
			id = contract.id,
			kind = contract.kind,
			text = contract.text,
			need = contract.need,
			have = Contracts.have(contract, daily.count),
			reward = contract.reward,
			done = daily.done[contract.id] == true,
		})
	end
	return {
		day = daily.day,
		contracts = contracts,
		bonus = daily.bonus,
		streak = {
			days = data.streak.days,
			last = data.streak.last,
			next = Streak.rewardFor(data.streak.days + 1).cash,
			claimable = Streak.waiting(data.streak, daily.day),
			cash = Streak.rewardFor(data.streak.days).cash,
		},
	}
end

-- [Player] = the view last sent to them, so the minute's look doesn't rebuild an open panel with a
-- view that hasn't changed. A player's first send (their join) is always made.
-- Weak by player, so a player who has left cannot be kept here by the minute's loop while their save
-- is still being written out.
local lastView = setmetatable({}, { __mode = "k" })

-- Whether two views (plain tables of numbers, strings and booleans) hold the same things.
local function sameView(a: any, b: any): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not sameView(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Tells the screen where things stand, unless it was told exactly this already.
local function sendView(player: Player, data)
	local view = viewOf(data)
	if sameView(lastView[player], view) then
		return
	end
	Net.event("ContractsUpdated"):FireClient(player, view)
	-- After the send, so one that failed is tried again.
	lastView[player] = view
end

-- Whether the day has contracts and every one of them is paid. A day with none (before the first
-- Refresh) has not finished them.
local function allDone(daily): boolean
	if #daily.contracts == 0 then
		return false
	end
	for _, contract in daily.contracts do
		if not daily.done[contract.id] then
			return false
		end
	end
	return true
end

-- Pays every contract that is met and not yet paid, then the Bonus Day if that finished all three,
-- and again if paying them met another (their cash counts toward the Earn contract). A contract is
-- marked in the save, and the client's totals sent, before its cash goes in.
local function payDone(player: Player, data)
	local daily = data.daily
	repeat
		recheck[player] = nil
		for _, contract in daily.contracts do
			if daily.done[contract.id] or Contracts.have(contract, daily.count) < contract.need then
				continue
			end
			daily.done[contract.id] = true
			DataService:Changed(player)
			if contract.reward > 0 then
				DataService:Earn(player, contract.reward)
			end
			Net.event("ContractDone"):FireClient(player, {
				id = contract.id,
				text = contract.text,
				reward = contract.reward,
			})
		end
		if not daily.bonus and allDone(daily) then
			daily.bonus = true
			DataService:Changed(player)
			DataService:Earn(player, Contracts.BonusCash)
			Net.event("BonusDay"):FireClient(player, { cash = Contracts.BonusCash })
		end
	until not recheck[player]
end

-- Pays what their counts have met. A call that comes while they are being paid (the cash is money
-- earned, so it asks again) only asks for one more look when the pay is done.
local function settle(player: Player)
	if paying[player] then
		recheck[player] = true
		return
	end
	local data = DataService:Get(player)
	if not data then
		return
	end
	paying[player] = true
	local ok, err = pcall(payDone, player, data)
	-- Whatever went wrong, the next settle can still run.
	paying[player] = nil
	recheck[player] = nil
	if not ok then
		error(err, 0)
	end
end

-- Adds to what the day has counted (`add` is handed the counts), pays whatever that met, and tells
-- the screen where it stands. If the day has turned since the last Refresh (the minute's loop has not
-- come round yet) it turns first, so what is counted goes to the day it happened on. Inside a pay
-- there is nothing to settle or tell yet: that pay looks again and tells the screen itself when it is
-- done.
local function counted(player: Player, add: (counts: Contracts.Count) -> ())
	local data = DataService:Get(player)
	if not data then
		return
	end
	if data.daily.day ~= Daily.dayKey(Clock.now()) then
		-- Inside a pay Refresh does nothing, so this cannot come back round into itself.
		guarded("rollover", player, function()
			DailyService:Refresh(player)
		end)
	end
	add(data.daily.count)
	local inside = paying[player] == true
	settle(player)
	if not inside then
		sendView(player, data)
	end
end

-- Public API ---------------------------------------------------------------------------------

-- What the screen draws for this player, the same table ContractsUpdated carries (nil before their
-- save has loaded).
function DailyService:View(player: Player)
	local data = DataService:Get(player)
	return data and viewOf(data)
end

-- Pays `cash` of the streak's (an owed gift, or a claimed one) under `paying`, then runs `tell`. The
-- cash is money earned, which counts toward today's Earn contract and may meet it: that look is held
-- until the pay is done, so the screen hears of the gift first and the contract is paid once, by the
-- settle the caller runs after this. Rethrows what went wrong once `paying` is cleared.
local function payGift(player: Player, cash: number, tell: () -> ())
	paying[player] = true
	local ok, err = pcall(function()
		if cash > 0 then
			DataService:Earn(player, cash)
		end
		tell()
	end)
	paying[player] = nil
	recheck[player] = nil
	if not ok then
		error(err, 0)
	end
end

-- Turns the day over if it is a new one, and keeps the streak: on a new UTC day it makes the day's
-- contracts for their level with every count at zero, and turns the streak: a gift from the day it
-- was last kept that was never claimed is paid now (and they are told, StreakGiftPaid), the streak
-- grows or starts again, day 7 gives its flag, and the new day's gift is left waiting for a claim.
-- A new day also wakes their contest, since judging day is a day of the week. Then it pays anything
-- met and still unpaid (so the minute's look is a safety net for a pay that failed) and sends the
-- view if it has changed.
-- Safe to call as often as you like: on the day the save already has, nothing changes. A call that
-- comes in the middle of a pay (settle's, or a gift's) does nothing, the next one will.
function DailyService:Refresh(player: Player)
	if paying[player] then
		return
	end
	local data = DataService:Get(player)
	if not data then
		return
	end

	local now = Clock.now()
	local today = Daily.dayKey(now)
	local yesterday = Daily.dayKey(now - SECONDS_PER_DAY)

	local daily = data.daily
	local turned = daily.day ~= today
	if turned then
		daily.day = today
		daily.contracts = Contracts.generate(Contracts.seed(today, player.UserId), DataService:GetLevel(player))
		daily.done = {}
		daily.count = { jobs = 0, earned = 0, junk = 0, stars = 0 }
		daily.bonus = false
		-- Judging day may have come round with this one, and nothing else tells the contest.
		guarded("contest view", player, function()
			ContestService:Update(player)
		end)
	end

	-- The turn marks an owed gift claimed before its cash goes in, so it is never paid twice; a pay
	-- that fails part way leaves it marked and unpaid, the safe side, like a contract.
	local streak = data.streak
	local owedDay = streak.last
	local advanced, owed = Streak.turn(streak, today, yesterday)
	local flag = if advanced then Streak.rewardFor(streak.days).flag else nil
	if flag then
		data.flags[flag] = true
	end
	if turned or advanced then
		DataService:Changed(player)
	end

	local ok, err = true, nil
	if owed then
		-- Counted toward the new day's Earn contract (its counts were zeroed above), the way the
		-- streak's cash always was.
		ok, err = pcall(payGift, player, owed, function()
			Net.event("StreakGiftPaid"):FireClient(player, {
				cash = owed,
				yesterday = owedDay == yesterday,
			})
		end)
	end
	-- Puts the pennant on the truck. The flag is saved before the pay, so this comes before anything
	-- below can rethrow.
	if flag then
		guarded("pennant", player, function()
			WorldService:RefreshPennant(player)
		end)
	end

	-- Pays what is met and not yet paid: the owed gift's cash may have met the Earn contract, and a
	-- contract a failed pass left unpaid is paid by the next look. Guarded so the view still goes out.
	guarded("streak settle", player, function()
		settle(player)
	end)
	sendView(player, data)
	if not ok then
		error(err, 0)
	end
end

-- Claims today's gift for `player` (ClaimStreak): true when it was paid, else false and why (nil
-- when there is nothing to say). The day is turned first, so a claim just after midnight claims the
-- new day's gift (the turn pays the old one if it was waiting). The gift is marked claimed in the
-- save before its cash goes in, the cash goes in before the Payday card is told (StreakAdvanced: the
-- days, the cash, day 7's flag and what tomorrow pays), and the contracts its cash meets are paid
-- after it, once.
function DailyService:Claim(player: Player): (boolean, string?)
	local now = os.clock()
	if now - (lastClaim[player] or 0) < CLAIM_COOLDOWN then
		return false, nil
	end
	lastClaim[player] = now
	if paying[player] then
		return false, nil
	end
	local data = DataService:Get(player)
	if not data then
		return false, "Your save is still loading."
	end
	guarded("claim rollover", player, function()
		DailyService:Refresh(player)
	end)

	local streak = data.streak
	local reward = Streak.claim(streak, Daily.dayKey(Clock.now()))
	if not reward then
		return false, "No gift waiting. Come back tomorrow for the next one."
	end
	DataService:Changed(player)
	local ok, err = pcall(payGift, player, reward.cash, function()
		Net.event("StreakAdvanced"):FireClient(player, {
			days = streak.days,
			cash = reward.cash,
			flag = reward.flag,
			tomorrow = Streak.rewardFor(streak.days + 1).cash,
		})
	end)
	guarded("claim settle", player, function()
		settle(player)
	end)
	sendView(player, data)
	if not ok then
		-- Claimed and maybe unpaid, the safe side. Said in the output, not to the player.
		warn(`DailyService: paying {player.Name}'s gift failed: {err}`)
	end
	return true, nil
end

-- Lifecycle ----------------------------------------------------------------------------------

-- Once their save is loaded: today's contracts and the streak.
local function onPlayerAdded(player: Player)
	local data = DataService:WaitForData(player)
	if not data then
		return
	end
	guarded("join", player, function()
		DailyService:Refresh(player)
	end)
end

function DailyService:Init()
	-- A finished job: a job, a three-star job if it got three stars, and the junk picked up.
	JobService.JobFinished:Connect(function(player, info)
		guarded("job count", player, function()
			counted(player, function(counts)
				counts.jobs = (counts.jobs or 0) + 1
				if info and info.stars == 3 then
					counts.stars = (counts.stars or 0) + 1
				end
				counts.junk = (counts.junk or 0) + ((info and info.junkPicked) or 0)
			end)
		end)
	end)
	-- Any money they make, tips and level cash included.
	DataService.Earned:Connect(function(player, amount)
		guarded("earned count", player, function()
			counted(player, function(counts)
				counts.earned = (counts.earned or 0) + amount
			end)
		end)
	end)

	Net.func("GetContracts").OnServerInvoke = function(player)
		return self:View(player)
	end
	-- Takes no arguments: anything the client sends is ignored, since the server knows the day.
	Net.func("ClaimStreak").OnServerInvoke = function(player)
		return self:Claim(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		paying[player] = nil
		recheck[player] = nil
		lastClaim[player] = nil
		lastView[player] = nil
	end)

	-- One loop for everyone: a day that turns over while they play (or a streak that is due) is
	-- noticed within a minute. Each player is looked at on their own, so one failing is a warning.
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				if DataService:Get(player) then
					guarded("refresh", player, function()
						self:Refresh(player)
					end)
				end
			end
		end
	end)
end

return DailyService
