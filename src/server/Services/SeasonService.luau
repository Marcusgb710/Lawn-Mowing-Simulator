-- The Busy Season's ladder (docs/superpowers/specs/2026-10-29-busy-season-design.md, 1b and 1c):
-- pays what a player has reached.
--   1. Milestones (Config/Milestones.luau): jobs finished, money earned and three-star jobs.
--      CheckMilestones looks at their numbers after every finished job and after every bit of
--      money they earn (tips and level cash count too), and pays each milestone they've just met.
--   2. Level rewards (Config/Levels.luau): cash, a truck paint tint and the gold business sign.
--      ClaimLevels pays every level they've reached and haven't claimed, in order: when a
--      level-up takes them past one, and once when they join, which is how an old save or a
--      reward a later slice adds gets paid.
-- The server decides all of it. The client is only told what was paid (MilestoneReached and
-- LevelReward), to show it.
--
-- Both mark the save, and send the client its new totals, before they pay, and pay before they
-- tell the client, so a reward is never paid twice and the screen never shows one the save
-- doesn't have. If a pay fails part way, the reward stays marked and goes unpaid, which is the
-- safe side of that.
--
-- Cash is money earned, so a level's cash can meet a milestone and a milestone's cash can meet
-- another. Those are looked for after the pay that caused them, never in the middle of it, so
-- the client is told in the order things happened: a level, then the milestones its cash met.
--
-- Kept in the player's data (DataService, version 13; Config/Season.luau explains the fields):
--   milestones    [milestone id] = true for each one paid
--   levelRewards  [Season.levelKey(level)] = true for each level paid
--   stars         [job template id] = their best star count on that job
-- The gold sign is the `GoldSign` attribute on the player, set for any level that gives one,
-- claimed now or on an earlier visit. Whatever shows the sign reads it from there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Config.Levels)
local Milestones = require(Shared.Config.Milestones)
local Net = require(Shared.Net)
local Season = require(Shared.Config.Season)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PremiumService = require(script.Parent.PremiumService)

local SeasonService = {}

-- [Player] = true while they are being paid, by CheckMilestones or ClaimLevels. Paying is money
-- earned, so it fires DataService.Earned, which asks for a milestone check in the middle of the
-- pay; `recheck` remembers that one was asked for, so it runs once the pay is done instead of
-- inside it.
local paying = {}
local recheck = {}

-- Runs one player's work so that an error in it is a warning, not the end of everyone else's.
local function guarded(what: string, player: Player, work: () -> ())
	local ok, err = pcall(work)
	if not ok then
		warn(`SeasonService: {what} failed for {player.Name}: {err}`)
	end
end

-- The numbers Milestones.reachedBy reads, from their save. A three-star job is a job they've
-- done with three stars as their best.
local function statsOf(data)
	local stars = 0
	for _, best in data.stars do
		if best == 3 then
			stars += 1
		end
	end
	return { jobs = data.jobsCompleted or 0, earned = data.earned or 0, stars = stars }
end

-- Pays every milestone they've met, then once more if paying them met another. A milestone is
-- marked in the save, and the client's totals sent, before its cash goes in.
local function payReached(player: Player, data)
	repeat
		recheck[player] = nil
		for _, milestone in Milestones.reachedBy(statsOf(data), data.milestones) do
			data.milestones[milestone.id] = true
			DataService:Changed(player)
			if milestone.cash > 0 then
				DataService:Earn(player, milestone.cash)
			end
			Net.event("MilestoneReached"):FireClient(player, {
				id = milestone.id,
				text = milestone.text,
				cash = milestone.cash,
			})
		end
	until not recheck[player]
end

-- Pays every level from 2 up to their level that isn't claimed, lowest first. A level is marked
-- claimed in the save, and the client's totals sent, before its cash, paint and sign are given,
-- and the client is told last.
local function payLevels(player: Player, data)
	for level = 2, DataService:GetLevel(player) do
		local key = Season.levelKey(level)
		local reward = Levels.rewardFor(level)
		if data.levelRewards[key] or not reward then
			continue
		end
		data.levelRewards[key] = true
		DataService:Changed(player)
		if reward.cash > 0 then
			DataService:Earn(player, reward.cash)
		end
		if reward.paint then
			PremiumService:GrantPaint(player, reward.paint)
		end
		if reward.sign then
			player:SetAttribute("GoldSign", true)
		end
		Net.event("LevelReward"):FireClient(player, { level = level, text = reward.text, cash = reward.cash })
	end
end

-- Public API ---------------------------------------------------------------------------------

-- Pays the milestones their jobs, money earned and three-star jobs have reached and the save
-- doesn't have yet. Safe to call as often as you like. A call that comes while they are being
-- paid (the cash is money earned, so it asks again) only asks for one more look when the pay
-- is done.
function SeasonService:CheckMilestones(player: Player)
	if paying[player] then
		recheck[player] = true
		return
	end
	local data = DataService:Get(player)
	if not data then
		return
	end
	paying[player] = true
	local ok, err = pcall(payReached, player, data)
	-- Whatever went wrong, the next check can still run.
	paying[player] = nil
	recheck[player] = nil
	if not ok then
		error(err, 0)
	end
end

-- Pays every level from 2 up to their level whose reward isn't claimed, lowest first, and tells
-- the client of each. Safe to call as often as you like: a level that's claimed is skipped.
-- The cash is money earned, so milestone checks are held until every level is paid and told, and
-- done once then: a milestone is never told before the level whose cash reached it.
function SeasonService:ClaimLevels(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	-- Inside a milestone pay, that pay already holds the checks.
	local holding = not paying[player]
	paying[player] = true
	local ok, err = pcall(payLevels, player, data)
	if holding then
		paying[player] = nil
		if recheck[player] then
			recheck[player] = nil
			self:CheckMilestones(player)
		end
	end
	if not ok then
		error(err, 0)
	end
end

-- Lifecycle ----------------------------------------------------------------------------------

-- Once their save is loaded: the gold sign if a level they've claimed gave one, then whatever
-- level rewards they haven't been paid.
local function onPlayerAdded(player: Player)
	local data = DataService:WaitForData(player)
	if not data then
		return
	end
	guarded("join", player, function()
		for key in data.levelRewards do
			local reward = Levels.rewardFor(tonumber(key) or 0)
			if reward and reward.sign then
				player:SetAttribute("GoldSign", true)
			end
			-- A migrated save claims its past levels without being paid, so this is where it comes to
			-- own the tints it passed (cash stays unpaid). GrantPaint skips one they already own.
			if reward and reward.paint then
				PremiumService:GrantPaint(player, reward.paint)
			end
		end
		SeasonService:ClaimLevels(player)
	end)
end

function SeasonService:Init()
	-- Any money they make, tips and level cash included.
	DataService.Earned:Connect(function(player)
		guarded("milestone check", player, function()
			self:CheckMilestones(player)
		end)
	end)
	-- Their jobs and three-star jobs have gone up.
	JobService.JobFinished:Connect(function(player)
		guarded("milestone check", player, function()
			self:CheckMilestones(player)
		end)
	end)
	DataService.LeveledUp:Connect(function(player)
		guarded("level rewards", player, function()
			self:ClaimLevels(player)
		end)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		paying[player] = nil
		recheck[player] = nil
	end)
end

return SeasonService
