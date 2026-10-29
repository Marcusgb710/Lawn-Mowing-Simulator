-- Checks the Busy Season's tables and rules outside Roblox:
--   lune run scripts/check-season
-- It checks the milestone rail's list and which milestones are nearest to done
-- (src/shared/Config/Milestones.luau), the level rewards and what comes next
-- (src/shared/Config/Levels.luau), and how a job's performance becomes stars and tips
-- (src/shared/Config/Stars.luau), and how a save becomes a version 13 save and who is still a
-- first-timer (src/shared/Config/Season.luau), and that the six sounds the Busy Season rings
-- (cash, level up, goal done, star, find, streak) have ids (src/shared/Sounds.luau). Exits with an
-- error if anything's off.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Levels = require("../src/shared/Config/Levels")
local Milestones = require("../src/shared/Config/Milestones")
local Sounds = require("../src/shared/Sounds")
local Stars = require("../src/shared/Config/Stars")

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL  " .. message)
	end
end

-- Milestones ----------------------------------------------------------------------------------

-- The list is well formed: ids are unique, each kind climbs, no one is paid less than nothing.
local listedIds = {}
local seenIds = {}
local lastAt = {}
for _, milestone in Milestones.List do
	table.insert(listedIds, milestone.id)
	check(not seenIds[milestone.id], `{milestone.id} is listed twice`)
	seenIds[milestone.id] = true
	check(milestone.id == `{milestone.kind}:{milestone.at}`, `{milestone.id} is not its kind and number`)
	check(milestone.at > (lastAt[milestone.kind] or 0), `{milestone.id} is not above the one before it`)
	lastAt[milestone.kind] = milestone.at
	check(milestone.cash >= 0, `{milestone.id} pays less than nothing`)
	check(typeof(milestone.text) == "string" and #milestone.text > 0, `{milestone.id} has no text`)
end
check(Milestones.List[1].text == "Finish 1 job" and Milestones.List[2].text == "Finish 3 jobs", "jobs text")
check(Milestones.List[11].text == "Earn $2,000" and Milestones.List[14].text == "Earn $250,000", "earned text")
check(
	Milestones.List[15].text == "Get 1 three-star job" and Milestones.List[16].text == "Get 5 three-star jobs",
	"stars text"
)

check(#Milestones.List == 18, "18 milestones")
check(Milestones.List[2].id == "Jobs:3" and Milestones.List[2].cash == 30, "3 jobs pays $30")
check(Milestones.List[9].cash == 2500, "500 jobs is capped at $2500")
check(Milestones.List[10].kind == "Earned" and Milestones.List[10].cash == 0, "earned milestones pay nothing")
check(Milestones.List[18].id == "Stars:100" and Milestones.List[18].cash == 2500, "100 three-star jobs pays $2500")
-- Nearest is the smallest share still to go, (at - have) / at: $500 at 4/5 has 1/5 to go, 3 jobs at
-- 2/3 has 1/3, so the $500 comes first. With $300 earned ($500 at 3/5, 2/5 to go) the jobs lead.
local nearest = Milestones.next({ jobs = 2, earned = 400, stars = 0 }, { ["Jobs:1"] = true }, 2)
check(nearest[1].id == "Earned:500" and nearest[2].id == "Jobs:3", "nearest first: $500 at 4/5, then 3 jobs at 2/3")
nearest = Milestones.next({ jobs = 2, earned = 300, stars = 0 }, { ["Jobs:1"] = true }, 2)
check(nearest[1].id == "Jobs:3" and nearest[2].id == "Earned:500", "nearest first: 3 jobs at 2/3, then $500 at 3/5")
check(
	Milestones.next({ jobs = 0, earned = 0, stars = 0 }, {}, 3)[3].id == "Jobs:5",
	"a tie keeps the list's order: all at 0, the first three are 1, 3 and 5 jobs"
)
check(#Milestones.next({ jobs = 0, earned = 0, stars = 0 }, {}, 0) == 0, "asking for none gives none")
check(#Milestones.next({ jobs = 0, earned = 0, stars = 0 }, {}, 99) == 18, "asking for more gives what there is")
local unchanged = #Milestones.List == #listedIds
for index, id in listedIds do
	unchanged = unchanged and Milestones.List[index].id == id
end
check(unchanged, "next leaves the list as it was")
check(
	#Milestones.next({ jobs = 2, earned = 400, stars = 0 }, { ["Jobs:1"] = true, ["Jobs:3"] = true }, 1) == 1,
	"a reached milestone is never offered again"
)
local reached = Milestones.reachedBy({ jobs = 3, earned = 600, stars = 1 }, { ["Jobs:1"] = true })
check(
	#reached == 3 and reached[1].id == "Jobs:3" and reached[2].id == "Earned:500" and reached[3].id == "Stars:1",
	"everything met and unreached, in list order"
)

-- Level rewards -------------------------------------------------------------------------------

check(Levels.rewardFor(1) == nil and Levels.rewardFor(2).cash == 100, "level 2 pays $100")
check(Levels.rewardFor(3).paint == "RacingRed" and Levels.rewardFor(12).paint == "MidnightBlack", "tints at 3 and 12")
check(Levels.rewardFor(20).sign == true and Levels.rewardFor(20).cash == 5000, "the gold sign at 20")
check(
	Levels.rewardFor(21).cash == 3000 and Levels.rewardFor(25).cash == 5000 and Levels.rewardFor(25).stamp == true,
	"past 20"
)
for level = 2, 20 do
	check(Levels.rewardFor(level) ~= nil, `level {level} has a reward`)
end
check(#Levels.nextRewards(3, 5) == 5 and Levels.nextRewards(3, 5)[1].level == 4, "the next five from level 3")

-- Every listed level pays something and says what; the tints come in order, once each; the
-- stamp and the sign are earned where the spec puts them and nowhere else.
local tints = {}
for level = 2, 40 do
	local reward = Levels.rewardFor(level)
	check(reward ~= nil and reward.cash >= 0 and #reward.text > 0, `level {level} pays something and names it`)
	if reward then
		check(reward.cash > 0 or reward.paint ~= nil, `level {level} pays cash or a tint`)
		check(reward.stamp == (if level > 20 and level % 5 == 0 then true else nil), `level {level}'s stamp`)
		check(reward.sign == (if level == 20 then true else nil), `level {level}'s sign`)
		if reward.paint then
			table.insert(tints, `{reward.paint}:{level}`)
		end
	end
end
check(table.concat(tints, " ") == "RacingRed:3 ForestGreen:6 SkyBlue:9 MidnightBlack:12", "four tints, in order")
check(Levels.rewardFor(0) == nil and Levels.rewardFor(-3) == nil, "no reward at or below level 1")
check(Levels.rewardFor(2).text == "$100" and Levels.rewardFor(4).text == "$250", "cash text")
check(Levels.rewardFor(3).text == "Racing Red tint" and Levels.rewardFor(3).cash == 0, "a tint on its own")
check(Levels.rewardFor(6).text == "Forest Green tint and $400", "a tint with cash")
check(Levels.rewardFor(20).text == "A gold business sign and $5,000", "the sign with cash")
check(Levels.rewardFor(21).text == "$3,000" and Levels.rewardFor(30).text == "$5,000 and a HUD stamp", "past 20")
local upcoming = Levels.nextRewards(18, 4)
check(
	#upcoming == 4
		and upcoming[1].level == 19
		and upcoming[2].reward.sign == true
		and upcoming[3].level == 21
		and upcoming[4].level == 22,
	"the next four from level 18 run on past 20"
)
check(Levels.nextRewards(1, 1)[1].level == 2, "from level 1 the first reward is level 2")
check(#Levels.nextRewards(5, 0) == 0, "asking for none gives none")

-- Stars ---------------------------------------------------------------------------------------

check(
	Stars.of(1.1, false) == 3 and Stars.of(1.1, true) == 2 and Stars.of(0.9, true) == 2 and Stars.of(0.89, false) == 1,
	"star thresholds"
)
check(Stars.tipRate(3) == 0.15 and Stars.tipRate(2) == 0.05 and Stars.tipRate(1) == 0, "tip rates")
check(
	Stars.of(2, true) == 2 and Stars.of(0, false) == 1 and Stars.of(5, false) == 3,
	"a penalty never costs more than a star"
)
check(Stars.of(0.89, true) == 1 and Stars.of(1.09, false) == 2, "just under a threshold is the star below")
check(Stars.tipRate(0) == 0 and Stars.tipRate(4) == 0.15, "stars out of range are held to 1 and 3")

-- A blend that lands a hair under a line in floating point still counts: JobService rounds the
-- factor to three decimals (Stars.round) before it asks for the stars.
check(Stars.of(1.0999999, false) == 2, "1.0999999 as it stands is under the three-star line")
check(Stars.round(1.0999999) == 1.1, "1.0999999 rounds to 1.1")
check(Stars.of(Stars.round(1.0999999), false) == 3, "the rounded 1.0999999 earns three stars")
check(Stars.of(Stars.round(0.8999999), false) == 2, "the rounded 0.8999999 earns two stars")
check(Stars.of(Stars.round(1.0994), false) == 2, "1.0994 rounds down to 1.099: two stars")
check(Stars.round(1) == 1 and Stars.round(0) == 0, "whole factors stay as they are")

-- Sounds --------------------------------------------------------------------------------------

-- Find and Streak are for the slices after this one; they are set now so this holds from the start.
for _, name in { "Cash", "LevelUp", "GoalDone", "Star", "Find", "Streak" } do
	local id = Sounds.Ids[name]
	check(typeof(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://", `{name} has an rbxassetid:// id`)
	check(typeof(id) == "string" and tonumber(string.sub(id, 14)) ~= nil, `{name}'s id ends in a number`)
end

-- The save ------------------------------------------------------------------------------------

-- Season reaches GameConfig through `script`, which Lune doesn't have, and GameConfig builds a
-- Vector3 as it loads. So GameConfig is loaded here with Lune's Vector3 and handed to Season as
-- its sibling: levelFromXp below is the real one. Run from the repo root, like the command at
-- the top.
local GameConfig = luau.load(fs.readFile("src/shared/Config/GameConfig.luau"), {
	debugName = "GameConfig",
	environment = { Vector3 = roblox.Vector3 },
})()
local Season = luau.load(fs.readFile("src/shared/Config/Season.luau"), {
	debugName = "Season",
	environment = {
		script = { Parent = { GameConfig = GameConfig } },
		require = function(module)
			return module
		end,
	},
})()

local fresh = { money = 0, xp = 0, jobsCompleted = 0 }
Season.upgradeSave(fresh)
check(
	fresh.earned == 0 and next(fresh.levelRewards) == nil and fresh.firstJob == false,
	"a fresh save is a first-timer with nothing claimed"
)
local old = { money = 1234.5, xp = 1800, jobsCompleted = 30 } -- level 7
Season.upgradeSave(old)
check(old.earned == 1234 and old.firstJob == true, "an old save keeps its money as earned and is not a first-timer")
for level = 2, 7 do
	check(old.levelRewards[tostring(level)] == true, `old save has claimed level {level}`)
end
check(old.levelRewards["8"] == nil, "nothing above its level is claimed")
check(Season.levelKey(12) == "12", "level keys are strings")
local kept = {
	money = 10,
	xp = 0,
	jobsCompleted = 0,
	earned = 99,
	stars = { QuickMow = 2 },
	milestones = { ["Jobs:1"] = true },
	levelRewards = { ["2"] = true },
	firstJob = true,
}
Season.upgradeSave(kept)
check(
	kept.earned == 99
		and kept.stars.QuickMow == 2
		and kept.milestones["Jobs:1"]
		and kept.levelRewards["2"]
		and kept.firstJob == true,
	"upgrade keeps what is there"
)
check(Season.isFirstTimer({ firstJob = false, jobsCompleted = 0 }, false) == true, "fresh and idle is a first-timer")
check(Season.isFirstTimer({ firstJob = false, jobsCompleted = 0 }, true) == false, "with a job accepted it is not")
check(Season.isFirstTimer({ firstJob = true, jobsCompleted = 0 }, false) == false, "once started it is not")

-- Past the brief: the upgrade is idempotent, leaves money, xp and jobs alone, fills in a field of
-- the wrong type again, and never starts anyone with negative earnings.
local twice = { money = 1234.5, xp = 1800, jobsCompleted = 30 }
Season.upgradeSave(twice)
Season.upgradeSave(twice)
local sameAsOnce = twice.earned == old.earned and twice.firstJob == old.firstJob
for level = 2, 8 do
	sameAsOnce = sameAsOnce and twice.levelRewards[tostring(level)] == old.levelRewards[tostring(level)]
end
check(sameAsOnce, "upgrading twice is upgrading once")
check(old.money == 1234.5 and old.xp == 1800 and old.jobsCompleted == 30, "the upgrade leaves money, xp and jobs alone")
local broken = {
	money = 50,
	xp = 0,
	jobsCompleted = 2,
	earned = "lots",
	stars = 3,
	milestones = false,
	levelRewards = 7,
	firstJob = "yes",
}
Season.upgradeSave(broken)
check(
	broken.earned == 50
		and typeof(broken.stars) == "table"
		and typeof(broken.milestones) == "table"
		and next(broken.levelRewards) == nil
		and broken.firstJob == true,
	"a field of the wrong type is filled in again"
)
local owing = { money = -40, xp = 0, jobsCompleted = 0 }
Season.upgradeSave(owing)
check(owing.earned == 0, "no one starts with negative earnings")
check(Season.isFirstTimer({ firstJob = false }, false) == true, "a save with no job count has done none")
check(
	Season.isFirstTimer({ firstJob = false, jobsCompleted = 1 }, false) == false,
	"a finished job is not a first-timer"
)

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("Season checks passed")
