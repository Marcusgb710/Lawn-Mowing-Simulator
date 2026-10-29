-- The Busy Season's part of the save (docs/superpowers/specs/2026-10-29-busy-season-design.md):
-- `earned`, `stars`, `milestones`, `levelRewards` and `firstJob`, and who still counts as a
-- first-timer. upgradeSave is the one place those fields get their starting values: DataService
-- runs it for a brand new save and as the 12 -> 13 migration, so the two can't drift apart. It
-- touches nothing else in a save, and nothing here pays or saves anything.
--
-- scripts/check-season.luau gates this file. It reaches GameConfig through `script`, which Lune
-- doesn't have, so the check loads it with GameConfig handed in.

local GameConfig = require(script.Parent.GameConfig)

local Season = {}

-- The key a level goes under in `levelRewards`. Every reader and writer uses this.
function Season.levelKey(level: number): string
	return tostring(level)
end

-- Fills in what a version 13 save carries and keeps whatever is already there with the right
-- type, so it is safe on any save and safe to run twice.
--   earned        what they've made from jobs and rewards; an old save counts the money it has
--   stars         [job template id] = their best star count on that job
--   milestones    [milestone id] = true for each one reached
--   levelRewards  [Season.levelKey(level)] = true for each level's reward claimed; an old save has
--                 claimed every level it has reached, so nobody is paid back pay for the past.
--                 The keys are strings on purpose: levels start at 2, and a table with integer
--                 keys that don't start at 1 is a sparse array, which the DataStore's JSON turns
--                 into an array with holes. String keys keep it a dictionary, the way
--                 story.read keys its threads. Read and write it through levelKey so there is one
--                 spelling.
--   firstJob      true once the first-timer opening has run; a save that has finished jobs is
--                 already past it
function Season.upgradeSave(data: { [string]: any })
	if typeof(data.earned) ~= "number" then
		data.earned = math.max(0, math.floor(data.money or 0))
	end
	if typeof(data.stars) ~= "table" then
		data.stars = {}
	end
	if typeof(data.milestones) ~= "table" then
		data.milestones = {}
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
end

-- Whether to guide this player through their very first job: they haven't started one, haven't
-- finished one, and haven't got one accepted right now (`hasJob`, which the caller knows).
function Season.isFirstTimer(data: { [string]: any }, hasJob: boolean): boolean
	return data.firstJob == false and (data.jobsCompleted or 0) == 0 and not hasJob
end

return Season
