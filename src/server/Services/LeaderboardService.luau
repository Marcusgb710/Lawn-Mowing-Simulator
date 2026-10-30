-- The two leaderboards on the sign at the town spawn (docs/superpowers/specs/2026-10-29-busy-season-design.md,
-- 2c): lawns mowed (jobs finished) and money earned, an OrderedDataStore each (GameConfig's
-- LeaderboardStores), keyed "u<UserId>".
--   Record   writes a player's two numbers when a job of theirs finishes, at most once every
--            GameConfig.LeaderboardWriteInterval seconds each. A finish inside that window is
--            not lost: the player is marked, and the next Refresh (or their leaving) writes them.
--   Refresh  reads both boards: the top GameConfig.LeaderboardTop for the sign and, a few pages
--            deep (LeaderboardRankPages), where everyone online stands. It runs once shortly
--            after the server starts and then every LeaderboardRefreshInterval seconds, and the
--            result goes to every screen as LeaderboardUpdated. Joining players get the last
--            result straight away.
-- The server decides all of it. The client (LeaderboardController) only draws what it is sent.
--
-- DataStores can be missing: Studio without "Enable Studio Access to API Services", or an outage.
-- The game plays on either way, and no call here is made outside a pcall.
--   * Studio with API access off, or stores that couldn't be made, switch the leaderboards off for
--     the session: one warning, then no DataStore call is made again, and the sign says so.
--   * Any other failed read keeps the last result on the sign and waits for the next tick. If
--     there is no result yet, the sign says it is off until a read works.
--   * A failed write is a warning, and not tried again until the player's next job.
--   * Names are looked up for the top lists only when the player isn't online, and a read gives up
--     on lookups after a few fail (the rest show a name already known, or "Player"). A name that
--     failed is left alone for the next few reads.
--
-- The payload each screen is sent (the boards are the same for everyone, `you` is their own):
--   { available = true, lawns = { { name, value } }, money = { { name, value } },
--     you = { lawnsRank = number?, moneyRank = number?, lawns = jobs finished, money = earned } }
-- or just { available = false } when the leaderboards are off. A rank is nil when they aren't in
-- the pages that were read.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)

-- The first read comes this many seconds after the server starts, once players have had a moment
-- to load in.
local FIRST_READ_DELAY = 10
-- The longest a joining player's screen is waited for before it is sent the boards the second
-- time (see onPlayerAdded).
local ARRIVAL_WAIT = 60
-- The name shown for a player whose name couldn't be looked up.
local UNKNOWN_NAME = "Player"
-- One read stops looking names up after this many lookups have failed in it.
local MAX_NAME_FAILURES = 3
-- A name whose lookup failed isn't asked for again for this many reads.
local MISS_READS = 3
-- The boards, in the order they are written and read.
local BOARDS = { "Lawns", "Money" }

type Row = { name: string, value: number }
-- One good read: each board's top list with names, and each board's ranks by key.
type Board = {
	lawns: { Row },
	money: { Row },
	lawnRanks: { [string]: number },
	moneyRanks: { [string]: number },
}

local LeaderboardService = {}

-- { Lawns = OrderedDataStore, Money = OrderedDataStore }, once both exist.
local stores: { [string]: OrderedDataStore }? = nil
-- Whether DataStores may be called at all.
local available = false
-- Set the first time the leaderboards are switched off, so that happens (and is warned of) once.
local switchedOff = false
-- True while there is nothing to show and no way to get it yet: the sign says the boards are off.
local off = false
-- True while a read is under way (it yields), so a second one doesn't start on top of it.
local refreshing = false
-- The last good read, kept while later reads fail.
local board: Board? = nil
-- [Player] = os.clock() of their last write, for the throttle.
local lastWrite: { [Player]: number } = {}
-- [Player] = true for a player whose job finished inside the write window, so the boards are a job
-- behind them: they are written at the next Refresh or when they leave.
local dirty: { [Player]: boolean } = {}
-- [UserId] = name, for the players names have been looked up for.
local names: { [number]: string } = {}
-- Which read this is (every read counts, good or not), how many lookups have failed in it, and
-- [UserId] = the first read a name that failed may be asked for again in.
local readNumber = 0
local nameFailures = 0
local missedUntil: { [number]: number } = {}

local function keyFor(userId: number): string
	return "u" .. userId
end

-- Whether a DataStore error is Studio saying its API access is off (worded as DataService has it).
-- Nothing changes that until the game is stopped, so it is not worth asking again.
local function isStudioDenied(err: any): boolean
	local message = tostring(err)
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "Studio access to APIs is not allowed", 1, true) ~= nil
end

local function reasonFor(err: any): string
	if isStudioDenied(err) then
		return "Studio has no access to DataStores. Turn on Game Settings > Security > Enable Studio Access to API Services to see them."
	end
	return tostring(err)
end

-- Runs one player's work so that an error in it is a warning, not the end of everyone else's.
local function guarded(what: string, player: Player, work: () -> ())
	local ok, err = pcall(work)
	if not ok then
		warn(`LeaderboardService: {what} failed for {player.Name}: {err}`)
	end
end

-- What one player's screen is sent, or nil when there is nothing to send yet (no read has worked,
-- or their save hasn't loaded, which their own line needs).
local function payloadFor(player: Player)
	if board then
		local data = DataService:Get(player)
		if not data then
			return nil
		end
		local key = keyFor(player.UserId)
		return {
			available = true,
			lawns = board.lawns,
			money = board.money,
			you = {
				lawnsRank = board.lawnRanks[key],
				moneyRank = board.moneyRanks[key],
				lawns = data.jobsCompleted or 0,
				money = math.floor(data.earned or 0),
			},
		}
	end
	if off then
		return { available = false }
	end
	return nil
end

local function sendTo(player: Player)
	local payload = payloadFor(player)
	if payload then
		Net.event("LeaderboardUpdated"):FireClient(player, payload)
	end
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		sendTo(player)
	end
end

-- The leaderboards can't work this session: one warning, no more DataStore calls, and a sign
-- that says so (unless it already has boards, which it keeps).
local function switchOff(reason: string)
	if switchedOff then
		return
	end
	switchedOff = true
	available = false
	warn("LeaderboardService: the leaderboards are off. " .. reason)
	if not board then
		off = true
		broadcast()
	end
end

-- A player's name: the one they're online with, else the one looked up before, else a lookup. A
-- failed lookup gives UNKNOWN_NAME and is remembered, so that name isn't asked for again for
-- MISS_READS reads (a banned or deleted account is not asked about every tick), and once
-- MAX_NAME_FAILURES have failed in one read the rest of that read don't ask at all.
local function nameOf(key: string, online: { [number]: string }): string
	local userId = tonumber(string.sub(key, 2))
	if not userId then
		return UNKNOWN_NAME
	end
	local known = online[userId] or names[userId]
	if known then
		return known
	end
	if nameFailures >= MAX_NAME_FAILURES or readNumber < (missedUntil[userId] or 0) then
		return UNKNOWN_NAME
	end
	local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and typeof(result) == "string" then
		names[userId] = result
		missedUntil[userId] = nil
		return result
	end
	nameFailures += 1
	missedUntil[userId] = readNumber + MISS_READS + 1
	return UNKNOWN_NAME
end

-- One board: its top list as it came (entries of { key, value }) and the rank of everyone in the
-- first LeaderboardRankPages pages, by key. The first page is the top list, so one request serves
-- both. It throws when a DataStore call does; Refresh keeps it inside a pcall.
local function readBoard(store: OrderedDataStore): ({ any }, { [string]: number })
	local pages = store:GetSortedAsync(false, GameConfig.LeaderboardTop)
	local top = pages:GetCurrentPage()
	local ranks = {}
	local rank = 0
	local page = top
	for number = 1, GameConfig.LeaderboardRankPages do
		for _, entry in page do
			rank += 1
			ranks[entry.key] = rank
		end
		if number == GameConfig.LeaderboardRankPages or pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
		page = pages:GetCurrentPage()
	end
	return top, ranks
end

local function rowsOf(top: { any }, online: { [number]: string }): { Row }
	local rows = {}
	for _, entry in top do
		table.insert(rows, { name = nameOf(entry.key, online), value = entry.value })
	end
	return rows
end

-- Both boards, with names. Throws when a DataStore call does.
local function readBoards(): Board
	readNumber += 1
	nameFailures = 0
	local found = stores :: { [string]: OrderedDataStore }
	local lawnsTop, lawnRanks = readBoard(found.Lawns)
	local moneyTop, moneyRanks = readBoard(found.Money)
	local online = {}
	for _, player in Players:GetPlayers() do
		online[player.UserId] = player.Name
	end
	return {
		lawns = rowsOf(lawnsTop, online),
		money = rowsOf(moneyTop, online),
		lawnRanks = lawnRanks,
		moneyRanks = moneyRanks,
	}
end

-- Once their save is loaded: the boards as the last read found them, at once. A push can land before
-- their screen is listening (init.client asks for its profile for the same reason), so once they've
-- arrived where the game starts for them (the title card waits on that, so their screen is up) it
-- is sent again. The next read would reach them anyway, but not for a couple of minutes.
local function onPlayerAdded(player: Player)
	if not DataService:WaitForData(player) then
		return
	end
	sendTo(player)
	if player:GetAttribute("ArrivedAtBusiness") == true then
		return
	end
	local giveUp = os.clock() + ARRIVAL_WAIT
	while player.Parent == Players and player:GetAttribute("ArrivedAtBusiness") ~= true and os.clock() < giveUp do
		task.wait(0.5)
	end
	if player.Parent == Players then
		sendTo(player)
	end
end

-- Writes a player's two numbers, one write to each board. The numbers are read before the first
-- write, which yields. A failed write is a warning; Studio's refusal switches the boards off.
local function writeScores(player: Player, found: { [string]: OrderedDataStore })
	local data = DataService:Get(player)
	if not data then
		return
	end
	local key = keyFor(player.UserId)
	local values = { Lawns = data.jobsCompleted or 0, Money = math.floor(data.earned or 0) }
	for _, which in BOARDS do
		local store = found[which]
		local ok, err = pcall(store.SetAsync, store, key, values[which])
		if not ok then
			if isStudioDenied(err) then
				switchOff(reasonFor(err))
				return
			end
			warn(`LeaderboardService: couldn't save {player.Name}'s {string.lower(which)} score: {err}`)
		end
	end
end

-- Writes a player a finish was held back for (see Record), if the boards are on and their save is
-- one that is being kept. Marked clean before the write, which yields, so two flushes at once (the
-- tick and their leaving) write once.
local function flush(player: Player)
	if not dirty[player] then
		return
	end
	dirty[player] = nil
	local found = stores
	if not (available and found) or not DataService:CanSave(player) then
		return
	end
	lastWrite[player] = os.clock()
	writeScores(player, found)
end

-- Public API ---------------------------------------------------------------------------------

-- Whether the leaderboards are working this session: their stores were made, and nothing has
-- switched them off since (Studio refusing DataStore access, say). A read that failed for another
-- reason does not count: the next tick tries again.
function LeaderboardService:IsAvailable(): boolean
	return available
end

-- Writes a player's lawns mowed and money earned to the boards, unless they were written less than
-- LeaderboardWriteInterval seconds ago (a crew's jobs finishing together write once each): then the
-- player is marked, and the next Refresh or their leaving writes them. A save that isn't being kept
-- (it couldn't be loaded, or Studio reset it) is never written: its numbers start again from
-- nothing and would take a real score down.
function LeaderboardService:Record(player: Player)
	local found = stores
	if not (available and found) or not DataService:CanSave(player) then
		return
	end
	local now = os.clock()
	local last = lastWrite[player]
	if last and now - last < GameConfig.LeaderboardWriteInterval then
		dirty[player] = true
		return
	end
	if not DataService:Get(player) then
		return
	end
	-- Stamped before the first write, which yields.
	lastWrite[player] = now
	dirty[player] = nil
	writeScores(player, found)
end

-- Writes the players a finish was held back for, then reads both boards and sends every player the
-- result. A read that fails leaves what the sign shows as it was (or, if it shows nothing yet, says
-- it is off) and is not tried again until the next tick. Does nothing while the leaderboards are off
-- or a read is already under way. Returns true when it read the boards, and false when it did not:
-- it skipped, or the read failed (which is warned).
function LeaderboardService:Refresh(): boolean
	if not available or refreshing then
		return false
	end
	refreshing = true
	local held = {}
	for player in dirty do
		table.insert(held, player)
	end
	for _, player in held do
		guarded("score write", player, function()
			flush(player)
		end)
	end
	if not available then
		-- A write found Studio has no DataStore access: the boards are off, and nothing is read.
		refreshing = false
		return false
	end
	local ok, result = pcall(readBoards)
	refreshing = false
	if ok then
		board = result
		broadcast()
		return true
	end
	if isStudioDenied(result) then
		switchOff(reasonFor(result))
		return false
	end
	warn(
		`LeaderboardService: couldn't read the leaderboards, trying again in {GameConfig.LeaderboardRefreshInterval} s: {result}`
	)
	if not board and not off then
		off = true
		broadcast()
	end
	return false
end

-- Lifecycle ----------------------------------------------------------------------------------

function LeaderboardService:Init()
	local made = {}
	local failure: any = nil
	for _, which in BOARDS do
		local ok, result =
			pcall(DataStoreService.GetOrderedDataStore, DataStoreService, GameConfig.LeaderboardStores[which])
		if ok then
			made[which] = result
		elseif failure == nil then
			failure = result
		end
	end
	if failure ~= nil then
		switchOff(reasonFor(failure))
	else
		stores = made
		available = true
	end

	JobService.JobFinished:Connect(function(player)
		guarded("score write", player, function()
			self:Record(player)
		end)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- DataService lets the save go only after writing it out (which yields), so it is still here.
		guarded("score write", player, function()
			flush(player)
		end)
		lastWrite[player] = nil
		dirty[player] = nil
	end)
end

function LeaderboardService:Start()
	if not available then
		return
	end
	task.wait(FIRST_READ_DELAY)
	while available do
		self:Refresh()
		task.wait(GameConfig.LeaderboardRefreshInterval)
	end
end

return LeaderboardService
