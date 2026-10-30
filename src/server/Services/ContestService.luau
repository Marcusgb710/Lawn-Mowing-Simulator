-- The Maple Grove Best Yard contest (docs/STORY.md, act 4). Your business's own yard against
-- Gloria's, which TurfKing does:
--   1. Once you're in act 4, June offers to enter you: she texts that the judges are in town, says
--      so on her porch, and the Messages app's goal card has a "Call the judges" button.
--   2. You call them when you're ready (StartJudging). Your yard is scored there and then from
--      what the game already measures (Config/Contest.luau: the lawn, its edge, beds and shrubs,
--      decorations), against Gloria's bar for the summer, and the judging scene is queued: the
--      judges walk your yard, then Gloria's, and the first time the 1994 secret comes out.
--   3. After the scene the results screen shows (ContestController). Collect (CollectContest)
--      pays out and plays the ending: June scratches Gloria's name onto the trophy, or Gloria
--      wins, insufferably.
--   4. The first judging day comes by the jobs (Contest.state), so the story lands the first time.
--      After it, judging day is every Saturday (UTC, by the server's Clock; Contest.calendarState):
--      the judges can be called once on each. A win starts next summer, with Gloria's bar a little
--      higher, and so do four Saturdays without one; a Saturday you miss changes nothing.
-- Winning pays Contest.Prize, and the first win also brings the Best Yard Trophy (a decoration,
-- delivered in a box like an order) and half off the Small Office (or the Equipment Yard, if you
-- have the office). The server decides all of it; the client only asks to start and to collect.
--
-- Saved in the player's data as `contest` (DataService, version 11, and version 14 for the last two):
--   summer    which summer it is (1 at first; a win starts the next one, and so do four Saturdays
--             without a win)
--   wins      how many times you've won, and `judged`, how many judging days you've had
--   last      the last result: { summer, won, you, gloria } (totals), or false
--   pending   the result waiting to be collected: { summer, first, won, you, gloria, rewards,
--             scene }, or false. It's decided when judging starts, so leaving doesn't change it.
--   nextAt    the jobs done when the first judging day comes round (it gates nothing after it)
--   offered   how many judging days there had been when June last texted it's open (-1: never)
--   discount  the building a win took half off, until it's bought (Shop.price), or false
--   lastJudged  the day key (Daily.dayKey) of the last time the judges were called ("" for never)
--   saturdays   the Saturdays judged without a win since the last new summer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contest = require(Shared.Config.Contest)
local Daily = require(Shared.Daily)
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local Clock = require(script.Parent.Parent.Clock)
local DataService = require(script.Parent.DataService)
local DecorService = require(script.Parent.DecorService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local JobService = require(script.Parent.JobService)
local StoryService = require(script.Parent.StoryService)

-- Seconds between a player's requests (starting judging, collecting).
local COOLDOWN = 1
-- How long the client's first request waits for the player's story.
local JOIN_WAIT = 30

local ContestService = {}

-- [Player] = os.clock() of their last request
local lastRequest = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- Their saved contest, made sound if the save holds something odd.
local function stateOf(data)
	local contest = data.contest
	if typeof(contest) ~= "table" then
		contest = {}
		data.contest = contest
	end
	contest.summer = if typeof(contest.summer) == "number" then math.max(1, math.floor(contest.summer)) else 1
	for _, key in { "wins", "judged", "nextAt", "saturdays" } do
		contest[key] = if typeof(contest[key]) == "number" then math.max(0, math.floor(contest[key])) else 0
	end
	-- The day key of the last judging ("" for never). A contest rebuilt from {} (OpenForTesting's
	-- reset) has neither this nor `saturdays` until here.
	if typeof(contest.lastJudged) ~= "string" then
		contest.lastJudged = ""
	end
	if typeof(contest.offered) ~= "number" then
		contest.offered = -1
	end
	for _, key in { "last", "pending" } do
		if typeof(contest[key]) ~= "table" then
			contest[key] = false
		end
	end
	if typeof(contest.discount) ~= "string" then
		contest.discount = false
	end
	return contest
end

-- Where their contest is at `now` (the server's Clock unless a caller already has the moment):
-- the jobs rule for the first judging day, Saturdays after it (Contest.calendarState).
local function stateFor(player: Player, data, contest, now: number?): string
	return Contest.calendarState(contest, StoryService:GetAct(player), data.jobsCompleted or 0, now or Clock.now())
end

-- How many jobs until the first judging day comes round, and how many the wait was. Once that
-- day's been played the jobs count for nothing and the calendar says when it is.
local function jobsUntil(data, contest): (number, number)
	local length = if contest.last and contest.last.won then Contest.SummerJobs else Contest.RetryJobs
	return math.max(0, contest.nextAt - (data.jobsCompleted or 0)), length
end

-- "1 day", "2 days".
local function inDays(days: number): string
	return `{days} {if days == 1 then "day" else "days"}`
end

-- What the client is sent: everything it shows, nothing it decides. `calendar` says judging day
-- is on Saturdays now (the first has been played), so `daysLeft` is the wait and not `jobsLeft`.
local function view(player: Player, data)
	local contest = stateOf(data)
	local now = Clock.now()
	local jobsLeft, jobsWait = jobsUntil(data, contest)
	return {
		state = stateFor(player, data, contest, now),
		summer = contest.summer,
		bar = Contest.bar(contest.summer),
		wins = contest.wins,
		jobsLeft = jobsLeft,
		jobsWait = jobsWait,
		daysLeft = Contest.daysUntilJudging(contest, now),
		calendar = contest.judged > 0,
		result = if contest.pending then contest.pending else nil,
	}
end

local function update(player: Player)
	local data = DataService:Get(player)
	if data and StoryService:HasJoined(player) then
		Net.event("ContestUpdated"):FireClient(player, view(player, data))
	end
end

-- June's text once judging day is open: the first time, after a loss, or each summer after a win.
local function offer(player: Player)
	local data = DataService:Get(player)
	if not (data and StoryService:HasJoined(player)) then
		return
	end
	local contest = stateOf(data)
	if stateFor(player, data, contest) ~= "Open" or contest.offered == contest.judged then
		return
	end
	contest.offered = contest.judged
	local texts = if contest.judged == 0
		then Story.ContestTexts.Open
		elseif contest.last and contest.last.won then Story.ContestTexts.Again
		else Story.ContestTexts.Retry
	StoryService:SendTexts(player, texts, { rival = Contest.bar(contest.summer) })
end

-- What the judges look at in the player's own yard, or nil if it isn't built.
local function measure(player: Player)
	local lawn = HomeLawnService:YardMeasures(player)
	if not lawn then
		return nil
	end
	local measures = DecorService:YardMeasures(player, Contest.BedIds)
	measures.lawnShare = lawn.lawnShare
	measures.edgeShare = lawn.edgeShare
	measures.junk = lawn.junk
	return measures
end

-- Public API ---------------------------------------------------------------------------------

-- Sends the client where their contest stands now. DailyService calls it when the UTC day turns:
-- judging day is a day of the week, and nothing else wakes the contest at midnight.
function ContestService:Update(player: Player)
	update(player)
end

-- Calls the judges: scores the player's yard now and queues judging day's scene. The result is
-- kept until they collect it.
function ContestService:StartJudging(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not (data and StoryService:HasJoined(player)) then
		return false, "Try again in a moment."
	end
	local contest = stateOf(data)
	-- One moment for the whole call, so the day it's allowed on is the day it's marked judged.
	local now = Clock.now()
	local state = stateFor(player, data, contest, now)
	if state == "Locked" then
		return false, "The contest isn't till the end of summer."
	elseif state == "Results" then
		return false, "The judges have been. Go and see the results."
	elseif state == "Waiting" then
		if contest.judged > 0 then
			return false, `Judging day is Saturday. {inDays(Contest.daysUntilJudging(contest, now))} to go.`
		end
		local jobsLeft = jobsUntil(data, contest)
		return false, `The judges come back in {jobsLeft} {if jobsLeft == 1 then "job" else "jobs"}.`
	end
	if JobService:IsBusy(player) then
		return false, "Finish the job first."
	end
	local measures = measure(player)
	if not measures then
		return false, "Your yard isn't ready for the judges yet."
	end

	local you = Contest.score(measures)
	local gloria = Contest.gloriaScores(contest.summer)
	local won = Contest.won(you, gloria)
	local first = contest.judged == 0
	local scene = if first then "ContestJudging" else "ContestJudgingAgain"
	contest.pending = {
		summer = contest.summer,
		first = first,
		won = won,
		you = you,
		gloria = gloria,
		-- June's wins before this one, for the screen's "June's 31st win".
		juneWins = Contest.JuneWins + contest.wins,
		rewards = if won then Contest.rewards(contest.wins, data.owned.Business) else nil,
		retryJobs = if won then nil else Contest.RetryJobs,
		scene = scene,
	}
	contest.judged += 1
	-- Today's judging, so this Saturday can't be judged twice. Set on the first day too, whatever
	-- day it falls on: it only matters once the calendar takes over, and then it's harmless.
	contest.lastJudged = Daily.dayKey(now)
	StoryService:SendTexts(player, Story.ContestTexts.Start)
	StoryService:PlayScene(player, scene)
	update(player)
	return true, "June's calling the judges. Go and stand by your yard."
end

-- Collects the result: pays out a win and plays the ending.
function ContestService:Collect(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Try again in a moment."
	end
	local contest = stateOf(data)
	local pending = contest.pending
	if not pending then
		return false, "There's nothing to collect."
	end
	contest.pending = false
	local jobs = data.jobsCompleted or 0
	local won = pending.won == true
	contest.last = {
		summer = pending.summer,
		won = won,
		you = pending.you and pending.you.total,
		gloria = pending.gloria and pending.gloria.total,
	}
	-- Collecting comes after the judges have been, so `judged` is already 1 or more and the calendar
	-- has taken over: this wait in jobs no longer gates anything. It is still set, which is harmless.
	contest.nextAt = Contest.nextAt(won, jobs)

	local message
	if won then
		local rewards = pending.rewards or Contest.rewards(contest.wins, data.owned.Business)
		contest.wins += 1
		contest.summer += 1
		contest.saturdays = 0
		-- The prize is money they made, so it counts toward `earned`.
		local prize = rewards.money or 0
		if prize > 0 then
			DataService:Earn(player, prize)
		end
		if rewards.trophy then
			DecorService:Gift(player, rewards.trophy)
		end
		local building = rewards.discount and Items.get("Business", rewards.discount)
		if building and not data.owned.Business[building.id] then
			contest.discount = building.id
		end
		DataService:Changed(player)
		StoryService:PlayScene(player, if contest.wins == 1 then "ContestWin" else "ContestWinAgain")
		message = `Best Yard! You won {Format.money(rewards.money or 0)}.`
		if rewards.trophy then
			message ..= " The trophy's on its way to your shop."
		end
	else
		-- Every Saturday after the first judging day that goes by without a win counts; the
		-- fourth starts a new summer anyway, and Gloria's bar goes up a step.
		if contest.judged > 1 then
			contest.saturdays = (contest.saturdays or 0) + 1
			if contest.saturdays >= Contest.SaturdaysPerSummer then
				contest.summer += 1
				contest.saturdays = 0
			end
		end
		StoryService:PlayScene(player, "ContestLose")
		message = "Gloria wins this one. The judges come back on Saturday."
	end
	update(player)
	return true, message
end

-- Lifecycle ----------------------------------------------------------------------------------

function ContestService:Init()
	Net.func("GetContest").OnServerInvoke = function(player)
		local deadline = os.clock() + JOIN_WAIT
		while not StoryService:HasJoined(player) and player.Parent == Players and os.clock() < deadline do
			task.wait(0.1)
		end
		local data = DataService:Get(player)
		return if data and StoryService:HasJoined(player) then view(player, data) else nil
	end
	-- The client only asks; it sends nothing else, and anything it does send is ignored.
	Net.func("StartJudging").OnServerInvoke = function(player)
		if tooSoon(player) then
			return false, nil
		end
		return self:StartJudging(player)
	end
	Net.func("CollectContest").OnServerInvoke = function(player)
		if tooSoon(player) then
			return false, nil
		end
		return self:Collect(player)
	end
	-- What June says on her porch in act 4 is about the contest.
	StoryService:SetTalkValues(function(player)
		local data = DataService:Get(player)
		if not data or StoryService:GetAct(player) < Contest.FromAct then
			return nil
		end
		local contest = stateOf(data)
		local now = Clock.now()
		local state = stateFor(player, data, contest, now)
		-- While judging day is waiting, June counts the jobs to the first one and the days to each
		-- Saturday after it (Story.JuneTalk.Contest.Waiting has a line for each).
		local waiting = state == "Waiting"
		local calendar = contest.judged > 0
		return {
			contest = state,
			rival = if state == "Open" then Contest.bar(contest.summer) else nil,
			jobs = if waiting and not calendar then jobsUntil(data, contest) else nil,
			days = if waiting and calendar then inDays(Contest.daysUntilJudging(contest, now)) else nil,
		}
	end)
end

-- For testing in Studio (StudioTestService): the first judging day's wait in jobs is over, so it is
-- open now, and any result waiting to be collected is dropped. Once a judging day has been played
-- it is a Saturday by the Clock that opens it, not this. `reset` starts the contest over from the
-- first summer.
function ContestService:OpenForTesting(player: Player, reset: boolean?): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	if reset then
		data.contest = nil
	end
	local contest = stateOf(data)
	contest.pending = false
	contest.nextAt = data.jobsCompleted or 0
	contest.offered = -1
	offer(player)
	update(player)
	return true
end

function ContestService:Start()
	-- Act 4 starting, or the jobs that bring judging day round again.
	StoryService.ActStarted:Connect(function(player)
		offer(player)
		update(player)
	end)
	JobService.JobFinished:Connect(function(player)
		task.defer(function()
			offer(player)
			update(player)
		end)
	end)

	local function onPlayerAdded(player: Player)
		local deadline = os.clock() + JOIN_WAIT
		while not StoryService:HasJoined(player) and player.Parent == Players and os.clock() < deadline do
			task.wait(0.2)
		end
		if StoryService:HasJoined(player) then
			offer(player)
			update(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ContestService
