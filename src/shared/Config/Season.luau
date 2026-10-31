-- The Busy Season's part of the save (docs/superpowers/specs/2026-10-29-busy-season-design.md):
-- `earned`, `stars`, `milestones`, `levelRewards` and `firstJob`, then the day's `daily`, `streak`
-- and `flags` and the judging calendar kept on `contest`, and who still counts as a first-timer.
-- upgradeSave is the one place those fields get their starting values: DataService runs it for a
-- brand new save and as the 12 -> 13 and 13 -> 14 migrations, so they can't drift apart. It touches
-- nothing else in a save, and nothing here pays or saves anything.
--
-- scripts/check-season.luau gates this file. It reaches GameConfig and Milestones through
-- `script`, which Lune doesn't have, so the check loads it with both handed in.

local GameConfig = require(script.Parent.GameConfig)
local Milestones = require(script.Parent.Milestones)

local Season = {}

-- The key a level goes under in `levelRewards`. Every reader and writer uses this.
function Season.levelKey(level: number): string
	return tostring(level)
end

-- Fills in what a version 14 save carries and keeps whatever is already there with the right
-- type, so it is safe on any save and safe to run twice. The version 13 fields:
--   earned        what they've made from jobs and rewards; an old save counts the money it has,
--                 unless it has finished no job, which has made nothing: a brand new save starts
--                 at 0 whatever StartingMoney is, so raising it never starts a player part way to
--                 Earned:500
--   stars         [job template id] = their best star count on that job
--   milestones    [milestone id] = true for each one reached; made for the first time, it holds
--                 every milestone the save's jobs and earned already meet (no three-star jobs are
--                 credited, `stars` starts empty), so an old save is paid no back pay for those
--                 either. One that's already there is kept as it is.
--   levelRewards  [Season.levelKey(level)] = true for each level's reward claimed; an old save has
--                 claimed every level it has reached, so nobody is paid back pay for the past.
--                 The keys are strings on purpose: levels start at 2, and a table with integer
--                 keys that don't start at 1 is a sparse array, which the DataStore's JSON turns
--                 into an array with holes. String keys keep it a dictionary, the way
--                 story.read keys its threads. Read and write it through levelKey so there is one
--                 spelling.
--   firstJob      true once the first-timer opening has run; a save that has finished jobs is
--                 already past it
-- The version 14 fields, which every save starts with empty. Each one is filled in on its own, so
-- a day that has some of its fields keeps those and gains the rest:
--   daily         the day's contracts: `day` is its UTC day key (Daily.dayKey; "" before the first),
--                 `contracts` is the list made for that day, `done` has [contract id] = true for
--                 each one paid, `count` is what they've done toward them today (jobs, earned, junk
--                 and stars), and `bonus` is true once the bonus for finishing all of them is paid.
--                 A list with a contract that is missing a field (an id, kind, text, or a need or
--                 reward that is a number) is emptied and `day` is blanked, and DailyService makes
--                 the day again at its next Refresh (DataService runs this on every save it loads)
--   streak        the login streak: how many `days` in a row, the day key it was `last` kept, and
--                 the day key whose gift was last `claimed` (Config/Streak.luau). A streak without
--                 `claimed` comes from before gifts were claimed, when the day was paid as it was
--                 kept, so `claimed` starts as its `last`: a day already paid is never paid again.
--                 No version bump: this runs on every save DataService loads.
--   flags         [flag id] = true for each cosmetic flag they own
--   contest       gains `lastJudged`, the day key of the last Saturday judged ("" for none),
--                 `saturdays`, the Saturdays judged without a win since the last one, and
--                 `offeredDay`, the day key of June's last "judges are back" text. The contest
--                 table itself is made by the 10 -> 11 migration and by DataService's defaultData,
--                 both before this runs, so a save without one is left alone: nothing here makes
--                 the contest, and a stub would only hide a save that lost it.
function Season.upgradeSave(data: { [string]: any })
	if typeof(data.earned) ~= "number" then
		local jobs = data.jobsCompleted or 0
		data.earned = if jobs > 0 then math.max(0, math.floor(data.money or 0)) else 0
	end
	if typeof(data.stars) ~= "table" then
		data.stars = {}
	end
	if typeof(data.milestones) ~= "table" then
		-- Marked, not paid: SeasonService only pays what isn't marked yet.
		local reached = {}
		local stats = { jobs = data.jobsCompleted or 0, earned = data.earned, stars = 0 }
		for _, milestone in Milestones.reachedBy(stats, {}) do
			reached[milestone.id] = true
		end
		data.milestones = reached
	end
	if typeof(data.levelRewards) ~= "table" then
		local claimed = {}
		for level = 2, GameConfig.levelFromXp(data.xp or 0) do
			claimed[Season.levelKey(level)] = true
		end
		data.levelRewards = claimed
	end
	if typeof(data.firstJob) ~= "boolean" then
		data.firstJob = (data.jobsCompleted or 0) > 0
	end

	if typeof(data.daily) ~= "table" then
		data.daily = {}
	end
	local daily = data.daily
	if typeof(daily.day) ~= "string" then
		daily.day = ""
	end
	-- A list of contract tables, which the DataStore's JSON keeps as an array.
	if typeof(daily.contracts) ~= "table" then
		daily.contracts = {}
	end
	-- Each one has to be whole, or what reads it (Contracts.have, the view) would throw: a list with
	-- a broken entry is dropped and the day is blanked, so the next Refresh makes a new one.
	for _, contract in daily.contracts do
		if
			typeof(contract) ~= "table"
			or typeof(contract.id) ~= "string"
			or typeof(contract.kind) ~= "string"
			or typeof(contract.text) ~= "string"
			or typeof(contract.need) ~= "number"
			or typeof(contract.reward) ~= "number"
		then
			daily.contracts = {}
			daily.day = ""
			break
		end
	end
	if typeof(daily.done) ~= "table" then
		daily.done = {}
	end
	if typeof(daily.count) ~= "table" then
		daily.count = {}
	end
	for _, counter in { "jobs", "earned", "junk", "stars" } do
		if typeof(daily.count[counter]) ~= "number" then
			daily.count[counter] = 0
		end
	end
	if typeof(daily.bonus) ~= "boolean" then
		daily.bonus = false
	end

	if typeof(data.streak) ~= "table" then
		data.streak = {}
	end
	if typeof(data.streak.days) ~= "number" then
		data.streak.days = 0
	end
	if typeof(data.streak.last) ~= "string" then
		data.streak.last = ""
	end
	-- Filled from `last`: a streak kept before gifts were claimed had that day paid when it was kept,
	-- so its gift counts as claimed and nobody is paid twice for one day.
	if typeof(data.streak.claimed) ~= "string" then
		data.streak.claimed = data.streak.last
	end

	if typeof(data.flags) ~= "table" then
		data.flags = {}
	end

	if typeof(data.contest) == "table" then
		if typeof(data.contest.lastJudged) ~= "string" then
			data.contest.lastJudged = ""
		end
		if typeof(data.contest.saturdays) ~= "number" then
			data.contest.saturdays = 0
		end
		if typeof(data.contest.offeredDay) ~= "string" then
			data.contest.offeredDay = ""
		end
	end
end

-- Whether to guide this player through their very first job: they haven't started one, haven't
-- finished one, and haven't got one accepted right now (`hasJob`, which the caller knows).
function Season.isFirstTimer(data: { [string]: any }, hasJob: boolean): boolean
	return data.firstJob == false and (data.jobsCompleted or 0) == 0 and not hasJob
end

return Season
