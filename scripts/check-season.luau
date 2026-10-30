-- Checks the Busy Season's tables and rules outside Roblox:
--   lune run scripts/check-season
-- It checks the milestone rail's list and which milestones are nearest to done
-- (src/shared/Config/Milestones.luau), the level rewards and what comes next
-- (src/shared/Config/Levels.luau), and how a job's performance becomes stars and tips
-- (src/shared/Config/Stars.luau) and that the pay is built on that same factor
-- (GameConfig.performance), and how a save becomes a version 14 save (the ladder's fields, then
-- the day's contracts, the streak, the flags and the judging calendar) and who is still a
-- first-timer, without back pay for the milestones or levels it has already passed
-- (src/shared/Config/Season.luau), and that the six sounds the Busy Season rings
-- (cash, level up, goal done, star, find, streak) have ids (src/shared/Sounds.luau), and how a
-- moment becomes a UTC day key, a Saturday and the midnight after it (src/shared/Daily.luau), and
-- that the server's clock loads and starts at the real time (src/server/Clock.luau), and the day's
-- three contracts by level band with how far along each is (src/shared/Config/Contracts.luau), and
-- the streak's rewards and when a day adds to it (src/shared/Config/Streak.luau), and that the
-- streak's pennant goes on a truck once, with or without a bed, anchored and out of the way of the aim
-- (Assets.addPennant, src/shared/Assets.luau), and the Settings window's three choices (what
-- Settings.clean keeps, fills in and drops, the sound volumes and grass shell counts, the Effects
-- volume in src/shared/Sounds.luau, and that the save and the SaveSettings handler use the rule).
-- Exits with an error if anything's off.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Clock = require("../src/server/Clock")
local Contracts = require("../src/shared/Config/Contracts")
local Daily = require("../src/shared/Daily")
local Format = require("../src/shared/Format")
local Levels = require("../src/shared/Config/Levels")
local Milestones = require("../src/shared/Config/Milestones")
local Sounds = require("../src/shared/Sounds")
local Stars = require("../src/shared/Config/Stars")
local Streak = require("../src/shared/Config/Streak")

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
local tied = Milestones.next({ jobs = 0, earned = 0, stars = 0 }, {}, 3)
check(
	tied[1].id == "Jobs:1" and tied[2].id == "Jobs:3" and tied[3].id == "Jobs:5",
	"a tie keeps the list's order: all at 0, the first three are 1, 3 and 5 jobs"
)
-- Milestones already met but not yet marked reached (the rail can draw in between) have nothing to
-- go and tie, however far they were passed, so they keep the list's order too: 5 stars pass the
-- 1-star milestone by more of its size than $1,000 passes $500, and would lead if that counted, but
-- the $500 is listed first.
local overmet = Milestones.next({ jobs = 0, earned = 1000, stars = 5 }, {}, 3)
check(
	overmet[1].id == "Earned:500" and overmet[2].id == "Stars:1" and overmet[3].id == "Stars:5",
	"milestones already met tie at nothing to go and keep the list's order"
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
-- Milestones.luau and Levels.luau each carry their own copy of Format.money (they have no
-- requires, so Lune can load them). Here is where the copies can't drift: every Earned milestone
-- says its number the way Format.money does, and every reward that pays cash names it that way.
for _, milestone in Milestones.List do
	if milestone.kind == "Earned" then
		check(milestone.text == "Earn " .. Format.money(milestone.at), `{milestone.id}'s text isn't Format.money's`)
	end
end
for level = 2, 40 do
	local reward = Levels.rewardFor(level)
	if reward and reward.cash > 0 then
		check(
			string.find(reward.text, Format.money(reward.cash), 1, true) ~= nil,
			`level {level}'s text doesn't hold {Format.money(reward.cash)} the way Format.money writes it`
		)
	end
end
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

-- Days ----------------------------------------------------------------------------------------

-- 1793232000 is 00:00 UTC on Thursday 29 October 2026; a day is 86400 seconds, and Saturday the 31st
-- starts at 1793404800.
check(
	Daily.dayKey(1793232000) == "20261029" and Daily.dayKey(1793232000 + 86399) == "20261029",
	"a day key covers the whole UTC day"
)
check(Daily.dayKey(1793232000 + 86400) == "20261030", "one day later is the next day")
check(Daily.dayKey(1767571200) == "20260105", "months and days are zero-padded")
check(Daily.isSaturday(1793404800) and not Daily.isSaturday(1793232000), "Saturdays")
check(Daily.nextSaturday(1793232000) == 1793404800, "Thursday's next Saturday is in two days")
check(Daily.nextSaturday(1793404800 + 3600) == 1793404800, "a Saturday morning is still judging day")
check(Daily.nextSaturday(1793404800 - 1) == 1793404800, "late Friday is still the day before judging day")
check(Daily.nextSaturday(1793404800 + 86400) == 1794009600, "Sunday waits a week")
check(
	Daily.daysUntil(1793232000 + 3600, 1793404800) == 2 and Daily.daysUntil(1793404800, 1793404800) == 0,
	"days until"
)
check(Daily.midnightAfter(1793232000 + 100) == 1793232000 + 86400, "midnight after")

-- The Clock loads with nothing but its table (it looks RunService up only inside setOffset, and Lune
-- has no `game`), so it can be required here. Outside Studio the offset stays 0 and now() is the
-- real time.
check(Clock.offset() == 0, "the clock starts with no offset")
check(math.abs(Clock.now() - os.time()) <= 2, "the clock reads the real time while the offset is 0")

-- Sounds --------------------------------------------------------------------------------------

-- Find and Streak are for the slices after this one; they are set now so this holds from the start.
for _, name in { "Cash", "LevelUp", "GoalDone", "Star", "Find", "Streak" } do
	local id = Sounds.Ids[name]
	check(typeof(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://", `{name} has an rbxassetid:// id`)
	check(typeof(id) == "string" and tonumber(string.sub(id, 14)) ~= nil, `{name}'s id ends in a number`)
end

-- The save ------------------------------------------------------------------------------------

-- Season reaches GameConfig and Milestones through `script`, which Lune doesn't have, and
-- GameConfig builds a Vector3 as it loads. So GameConfig is loaded here with Lune's Vector3 and
-- handed to Season as its sibling, with Milestones: levelFromXp and reachedBy below are the real
-- ones. Run from the repo root, like the command at the top.
local GameConfig = luau.load(fs.readFile("src/shared/Config/GameConfig.luau"), {
	debugName = "GameConfig",
	environment = { Vector3 = roblox.Vector3 },
})()
local Season = luau.load(fs.readFile("src/shared/Config/Season.luau"), {
	debugName = "Season",
	environment = {
		script = { Parent = { GameConfig = GameConfig, Milestones = Milestones } },
		require = function(module)
			return module
		end,
	},
})()

-- Pay and stars come from one blend of finish and speed: GameConfig.performance, which jobPay
-- multiplies in and JobService's completeJob rounds (Stars.round) and rates. So the pay is the
-- base pay x tool fit x that blend x the bonuses, less the penalty.
local sample = {
	basePay = 100,
	toolFit = 0.9,
	quality = 0.82,
	elapsed = 120,
	parTime = 150,
	weights = { quality = 0.5, time = 0.5 },
	bonus = 1.1,
	penalty = 7,
}
local blend = GameConfig.performance(sample.quality, sample.elapsed, sample.parTime, sample.weights)
check(
	blend
		== sample.weights.quality * GameConfig.qualityMultiplier(sample.quality)
			+ sample.weights.time * GameConfig.speedMultiplier(sample.elapsed, sample.parTime),
	"performance is the weights' blend of the finish and speed multipliers"
)
check(
	GameConfig.jobPay(sample) == math.floor(sample.basePay * sample.toolFit * blend * sample.bonus - sample.penalty),
	"jobPay is floor(basePay * toolFit * performance * bonus - penalty)"
)

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

-- A version 12 save is not showered with back pay for milestones any more than for levels: every
-- one its numbers already meet is marked reached when `milestones` is first made, and nothing
-- else. 60 jobs and $12,000 meet Jobs:1 to Jobs:50 and Earned:500 to Earned:10000, no more.
local veteran = { money = 12000, xp = 1800, jobsCompleted = 60 }
Season.upgradeSave(veteran)
local reachedIds = {}
for id in veteran.milestones do
	table.insert(reachedIds, id)
end
table.sort(reachedIds)
check(
	table.concat(reachedIds, " ") == "Earned:10000 Earned:2000 Earned:500 Jobs:1 Jobs:10 Jobs:25 Jobs:3 Jobs:5 Jobs:50",
	"a v12 save with 60 jobs and $12,000 has Jobs:1 to Jobs:50 and Earned:500 to Earned:10000 reached, nothing else"
)
check(
	veteran.milestones["Jobs:100"] == nil
		and veteran.milestones["Earned:50000"] == nil
		and veteran.milestones["Stars:1"] == nil,
	"nothing past its numbers is reached, and no three-star job is credited"
)
check(next(fresh.milestones) == nil, "a fresh save has nothing reached")
-- `old` (30 jobs, $1,234) from above.
check(
	old.milestones["Jobs:25"] == true and old.milestones["Earned:500"] == true and old.milestones["Jobs:50"] == nil,
	"an old save is marked up to its own numbers"
)
local oldMilestones = { ["Jobs:1"] = true }
local sixtyJobs = { money = 12000, xp = 1800, jobsCompleted = 60, milestones = oldMilestones }
Season.upgradeSave(sixtyJobs)
check(
	sixtyJobs.milestones == oldMilestones and next(oldMilestones) == "Jobs:1" and next(oldMilestones, "Jobs:1") == nil,
	"a milestones table that is already there is kept as it is, not filled up"
)
-- A save with no finished job has made nothing from jobs: it starts at 0 earned whatever money it
-- holds, so a raised StartingMoney would not start new players part way to Earned:500.
local rich = { money = 800, xp = 0, jobsCompleted = 0 }
Season.upgradeSave(rich)
check(rich.earned == 0 and next(rich.milestones) == nil, "no finished job: earned is 0 and nothing is reached")
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

-- Version 14: the day's contracts, the streak, the flags and the judging calendar. DataService makes
-- the contest table (the 10 -> 11 migration, or defaultData) before it runs upgradeSave, so a fresh
-- save here carries one the same way.
local fresh14 = { money = 0, xp = 0, jobsCompleted = 0, contest = { summer = 1, judged = 0 } }
Season.upgradeSave(fresh14)
check(
	fresh14.daily.day == ""
		and next(fresh14.daily.contracts) == nil
		and next(fresh14.daily.done) == nil
		and fresh14.daily.bonus == false,
	"a fresh save has no day, no contracts, nothing done and no bonus"
)
check(
	fresh14.daily.count.jobs == 0
		and fresh14.daily.count.earned == 0
		and fresh14.daily.count.junk == 0
		and fresh14.daily.count.stars == 0,
	"a fresh day's counts all start at 0"
)
check(
	fresh14.streak.days == 0 and fresh14.streak.last == "" and fresh14.streak.claimed == "",
	"a fresh save has no streak and has claimed no gift"
)
check(next(fresh14.flags) == nil, "a fresh save owns no flags")
check(
	fresh14.contest.lastJudged == "" and fresh14.contest.saturdays == 0 and fresh14.contest.offeredDay == "",
	"a fresh contest has judged on no day, no Saturdays without a win and told June's offer on no day"
)
check(fresh14.contest.summer == 1 and fresh14.contest.judged == 0, "the contest's other fields are left alone")
check(fresh.contest == nil, "a save with no contest table is not given a stub of one")
local noContest = { money = 0, xp = 0, jobsCompleted = 0, contest = false }
Season.upgradeSave(noContest)
check(noContest.contest == false, "a contest that is not a table is left alone, whatever it is")

-- A day already in progress keeps its day, contracts, done list and bonus, and gains the counts it
-- lacked. The tables are the ones that were there, not copies.
local contracts = { { id = "Mow", kind = "Mow", text = "Mow 2 lawns", need = 2, reward = 60 } }
local done = {}
local midDay = {
	money = 0,
	xp = 0,
	jobsCompleted = 0,
	daily = { day = "20261029", contracts = contracts, done = done, bonus = true },
}
Season.upgradeSave(midDay)
check(
	midDay.daily.day == "20261029"
		and midDay.daily.contracts == contracts
		and midDay.daily.done == done
		and midDay.daily.bonus == true,
	"a day in progress keeps its day, contracts, done list and bonus"
)
check(
	midDay.daily.count.jobs == 0
		and midDay.daily.count.earned == 0
		and midDay.daily.count.junk == 0
		and midDay.daily.count.stars == 0,
	"a day with no counts gains them at 0"
)
local partial = { money = 0, xp = 0, jobsCompleted = 0, daily = { count = { jobs = 2, earned = 90 } } }
Season.upgradeSave(partial)
check(
	partial.daily.count.jobs == 2
		and partial.daily.count.earned == 90
		and partial.daily.count.junk == 0
		and partial.daily.count.stars == 0,
	"counts that are there are kept and the missing ones start at 0"
)
local kept14 = {
	money = 0,
	xp = 0,
	jobsCompleted = 0,
	streak = { days = 4, last = "20261028" },
	flags = { TruckPennant = true },
	contest = { lastJudged = "20261024", saturdays = 2 },
}
Season.upgradeSave(kept14)
check(
	kept14.streak.days == 4 and kept14.streak.last == "20261028" and kept14.flags.TruckPennant == true,
	"a streak and flags that are there are kept"
)
-- A streak from before gifts were claimed ({days, last}) had its day paid when it was kept, so it
-- counts that day's gift as claimed: nobody is paid twice for one day.
check(kept14.streak.claimed == "20261028", "a streak with no claimed day has claimed the day it was last kept")
check(not Streak.waiting(kept14.streak, "20261028"), "so an upgraded streak has no gift waiting on its own day")
local claimedKept = { money = 0, xp = 0, jobsCompleted = 0, streak = { days = 2, last = "20261029", claimed = "" } }
Season.upgradeSave(claimedKept)
check(claimedKept.streak.claimed == "", "a claimed day that is there is kept, even an empty one")
local claimedWrong = { money = 0, xp = 0, jobsCompleted = 0, streak = { days = 2, last = "20261029", claimed = 7 } }
Season.upgradeSave(claimedWrong)
check(claimedWrong.streak.claimed == "20261029", "a claimed day that is not a string is the day last kept")
check(
	kept14.contest.lastJudged == "20261024" and kept14.contest.saturdays == 2,
	"a judging calendar that is there is kept"
)

-- Running the upgrade again changes nothing, for a fresh save, an old one and one with a day in it.
local function sameTable(a: any, b: any): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not sameTable(value, b[key]) then
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
local function copyOf(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = copyOf(inner)
	end
	return copy
end

-- Two saves with fields of the wrong type, made here for the list below (the checks on them are after
-- it). The list holds copies, so those checks still upgrade each of them for the first time.
local scrambled = {
	money = 0,
	xp = 0,
	jobsCompleted = 0,
	daily = { day = 5, contracts = false, done = 1, count = 3, bonus = "yes" },
	streak = { days = "many", last = 7 },
	flags = true,
	contest = { lastJudged = 7, saturdays = "two", offeredDay = 3 },
}
local noDay = { money = 0, xp = 0, jobsCompleted = 0, daily = 7, streak = "x" }
-- A day whose second contract has lost its `need`: Contracts.have would throw on it.
local brokenContract = {
	money = 0,
	xp = 0,
	jobsCompleted = 0,
	daily = {
		day = "20261029",
		contracts = {
			{ id = "Mow", kind = "Mow", text = "Mow 2 lawns", need = 2, reward = 60 },
			{ id = "Earn", kind = "Earn", text = "Earn $150", reward = 60 },
		},
		done = { Mow = true },
		count = { jobs = 2, earned = 90, junk = 0, stars = 0 },
		bonus = false,
	},
}
local sampleSaves = {
	fresh14,
	midDay,
	partial,
	kept14,
	{ money = 1234.5, xp = 1800, jobsCompleted = 30, contest = { summer = 2, wins = 1, judged = 3 } },
	{ money = 50, xp = 0, jobsCompleted = 0, contest = { judged = 1 } },
	{ money = 0, xp = 0, jobsCompleted = 0 },
	copyOf(scrambled),
	copyOf(noDay),
	copyOf(brokenContract),
}
for index, save in sampleSaves do
	Season.upgradeSave(save)
	local once = copyOf(save)
	Season.upgradeSave(save)
	check(sameTable(once, save), `upgrading save {index} twice is upgrading it once`)
end

-- A field of the wrong type is filled in again, the way the version 13 fields are.
Season.upgradeSave(scrambled)
check(
	scrambled.daily.day == ""
		and next(scrambled.daily.contracts) == nil
		and next(scrambled.daily.done) == nil
		and scrambled.daily.bonus == false
		and scrambled.daily.count.jobs == 0
		and scrambled.daily.count.stars == 0,
	"a day of the wrong types is made again"
)
check(
	scrambled.streak.days == 0
		and scrambled.streak.last == ""
		and scrambled.streak.claimed == ""
		and next(scrambled.flags) == nil
		and scrambled.contest.lastJudged == ""
		and scrambled.contest.saturdays == 0
		and scrambled.contest.offeredDay == "",
	"a streak, flags and judging calendar of the wrong types are made again"
)
Season.upgradeSave(noDay)
check(
	noDay.daily.day == "" and noDay.daily.count.junk == 0 and noDay.streak.days == 0,
	"a day or streak that is not a table is made whole"
)
Season.upgradeSave(brokenContract)
check(
	brokenContract.daily.day == "" and next(brokenContract.daily.contracts) == nil,
	"a day with a contract that has lost a field is blanked, so the next Refresh makes it again"
)
-- A complete stored version 14 save (DataService runs upgradeSave on every one it loads) whose second
-- contract has lost its `need`: the list is emptied and the day blanked, and nothing else moves.
local stored = {
	version = 14,
	money = 1234,
	xp = 1800,
	jobsCompleted = 30,
	earned = 5000,
	stars = { ["3"] = 2 },
	milestones = { ["Jobs:1"] = true },
	levelRewards = { ["2"] = true },
	firstJob = true,
	daily = {
		day = "20261029",
		contracts = {
			{ id = "Mow", kind = "Mow", text = "Mow 3 lawns", need = 3, reward = 150 },
			{ id = "Earn", kind = "Earn", text = "Earn $400", reward = 150 },
			{ id = "Junk", kind = "Junk", text = "Pick up 4 pieces of junk", need = 4, reward = 150 },
		},
		done = { Mow = true },
		count = { jobs = 3, earned = 250, junk = 1, stars = 0 },
		bonus = false,
	},
	streak = { days = 4, last = "20261029", claimed = "20261028" },
	flags = { TruckPennant = true },
	contest = { summer = 2, wins = 1, judged = 3, lastJudged = "20261024", saturdays = 2, offeredDay = "20261024" },
}
local storedBefore = copyOf(stored)
Season.upgradeSave(stored)
check(
	stored.daily.day == "" and next(stored.daily.contracts) == nil,
	"a stored version 14 save with a contract missing its need has its day blanked and its list emptied"
)
storedBefore.daily.day = ""
storedBefore.daily.contracts = {}
check(
	sameTable(storedBefore, stored),
	"and nothing else in it moves: money, xp, the streak, the flags, the contest and what was counted"
)
local goodStored = copyOf(storedBefore)
goodStored.daily.day = "20261029"
goodStored.daily.contracts = { { id = "Mow", kind = "Mow", text = "Mow 3 lawns", need = 3, reward = 150 } }
local goodBefore = copyOf(goodStored)
Season.upgradeSave(goodStored)
check(sameTable(goodBefore, goodStored), "a stored version 14 save whose contracts are whole comes out as it went in")

local notWhole = {
	{ id = "Mow", kind = "Mow", text = "Mow 2 lawns", need = "2", reward = 60 },
	{ id = "Mow", kind = "Mow", text = "Mow 2 lawns", need = 2 },
	{ id = 1, kind = "Mow", text = "Mow 2 lawns", need = 2, reward = 60 },
	{ kind = "Mow", text = "Mow 2 lawns", need = 2, reward = 60 },
	{ id = "Mow", kind = "Mow", need = 2, reward = 60 },
	"Mow",
	7,
	true,
}
for _, broken in notWhole do
	local save = { money = 0, xp = 0, jobsCompleted = 0, daily = { day = "20261029", contracts = { broken } } }
	Season.upgradeSave(save)
	check(save.daily.day == "" and next(save.daily.contracts) == nil, "a contract that is not whole blanks the day")
end

-- The day's contracts -------------------------------------------------------------------------

-- Four bands of levels with no gap or overlap, the last open to 999.
local lastMax = 0
for index, band in Contracts.Bands do
	check(band.min == lastMax + 1 and band.max >= band.min, `band {index} starts where the band before it ends`)
	lastMax = band.max
end
check(#Contracts.Bands == 4 and lastMax == 999, "four bands, the last one open to level 999")
check(
	Contracts.bandFor(1) == 1 and Contracts.bandFor(2) == 1 and Contracts.bandFor(3) == 2,
	"levels 1 and 2 are band 1 and level 3 starts band 2"
)
check(
	Contracts.bandFor(7) == 2
		and Contracts.bandFor(8) == 3
		and Contracts.bandFor(11) == 3
		and Contracts.bandFor(12) == 4,
	"level 7 ends band 2, levels 8 to 11 are band 3 and level 12 starts band 4"
)
check(Contracts.bandFor(999) == 4 and Contracts.bandFor(1500) == 4, "a level past the last band stays in it")
check(Contracts.bandFor(0) == 1, "a level below 1 is held to band 1")

check(table.concat(Contracts.Need.Mow, " ") == "2 3 4 5", "Mow needs by band")
check(table.concat(Contracts.Need.Earn, " ") == "150 400 1200 3000", "Earn needs by band")
check(table.concat(Contracts.Need.Junk, " ") == "3 4 6 8", "Junk needs by band")
check(table.concat(Contracts.Need.Stars, " ") == "1 1 2 2", "Stars needs by band")
check(table.concat(Contracts.Reward, " ") == "60 150 400 900", "a contract pays 60, 150, 400 or 900 by band")
check(Contracts.BonusCash == 500, "the Bonus Day pays $500")

-- A level 5 player is in band 2: 3 lawns, $400, and a $150 reward on each.
local day = Contracts.generate(Contracts.seed("20261029", 1234), 5)
check(#day == 3 and day[1].id == "Mow" and day[2].id == "Earn", "a day is a Mow, an Earn and one more")
check(day[3].id == "Junk" or day[3].id == "Stars", "the one more is Junk or Stars")
check(day[1].kind == "Mow" and day[2].kind == "Earn" and day[3].kind == day[3].id, "a contract's kind is its id")
check(day[1].need == 3 and day[2].need == 400, "band 2 asks for 3 lawns and $400")
check(day[1].reward == 150 and day[2].reward == 150 and day[3].reward == 150, "band 2 pays $150 a contract")
check(day[1].text == "Mow 3 lawns" and day[2].text == "Earn $400", "the Mow and Earn text")

-- A day's third contract at this level, found by trying seeds until one picks `kind`.
local function flavour(kind: string, level: number)
	for seed = 1, 200 do
		local contract = Contracts.generate(seed, level)[3]
		if contract.kind == kind then
			return contract
		end
	end
	error(`no seed from 1 to 200 gave a {kind} contract at level {level}`)
end
check(
	flavour("Junk", 5).need == 4 and flavour("Junk", 5).text == "Pick up 4 pieces of junk",
	"band 2's Junk contract is 4 pieces"
)
check(
	flavour("Stars", 5).need == 1 and flavour("Stars", 5).text == "Get a three-star job",
	"band 2's Stars contract is one three-star job"
)
check(
	flavour("Stars", 9).need == 2 and flavour("Stars", 9).text == "Get 2 three-star jobs",
	"band 3's Stars contract is two three-star jobs"
)
local firstBand = Contracts.generate(1, 1)
check(
	firstBand[1].text == "Mow 2 lawns" and firstBand[2].text == "Earn $150" and firstBand[1].reward == 60,
	"level 1 asks for 2 lawns and $150, and pays $60 a contract"
)
local thirdBand = Contracts.generate(1, 8)
check(
	thirdBand[2].text == "Earn $1,200" and thirdBand[2].need == 1200 and thirdBand[2].reward == 400,
	"level 8 asks for $1,200 and pays $400 a contract"
)
local lastBand = Contracts.generate(1, 12)
check(
	lastBand[1].text == "Mow 5 lawns" and lastBand[2].text == "Earn $3,000" and lastBand[3].reward == 900,
	"level 12 asks for 5 lawns and $3,000, and pays $900 a contract"
)

-- The same seed and level are the same day, and the seeds do not all pick the same third contract.
check(sameTable(Contracts.generate(777, 5), Contracts.generate(777, 5)), "the same seed and level give the same list")
local picked = {}
for seed = 1, 50 do
	picked[Contracts.generate(seed, 5)[3].kind] = true
end
check(picked.Junk == true and picked.Stars == true, "50 seeds in a row give both Junk and Stars")
local pickedByDay = {}
for offset = 0, 49 do
	local key = Daily.dayKey(1793232000 + offset * 86400)
	pickedByDay[Contracts.generate(Contracts.seed(key, 1234), 5)[3].kind] = true
end
check(pickedByDay.Junk == true and pickedByDay.Stars == true, "one player gets both Junk and Stars over 50 days")
local pickedByPlayer = {}
for userId = 1, 50 do
	pickedByPlayer[Contracts.generate(Contracts.seed("20261029", userId), 5)[3].kind] = true
end
check(pickedByPlayer.Junk == true and pickedByPlayer.Stars == true, "50 players on one day get both Junk and Stars")

local seed = Contracts.seed("20261029", 1234)
check(seed == Contracts.seed("20261029", 1234), "the same day and player give the same seed")
check(math.floor(seed) == seed and seed >= 0, "a seed is a whole number, 0 or more")
check(seed ~= Contracts.seed("20261029", 1235), "another player gets another seed")
check(seed ~= Contracts.seed("20261030", 1234), "another day gets another seed")
-- Studio's test players have negative ids.
local studioSeed = Contracts.seed("20261029", -1)
check(math.floor(studioSeed) == studioSeed and studioSeed >= 0, "a Studio player's negative id still gives a seed")
check(studioSeed ~= Contracts.seed("20261029", -2), "Studio's test players get seeds of their own")

-- have: how far along a contract is, never past its need, from the counter of its own kind.
check(Contracts.have({ kind = "Earn", need = 400 }, { earned = 950 }) == 400, "have stops at the need")
check(Contracts.have({ kind = "Earn", need = 400 }, { earned = 150 }) == 150, "have is the count while under the need")
check(Contracts.have({ kind = "Mow", need = 3 }, { jobs = 2 }) == 2, "Mow counts jobs")
check(Contracts.have({ kind = "Junk", need = 4 }, { junk = 1 }) == 1, "Junk counts junk")
check(Contracts.have({ kind = "Stars", need = 2 }, { stars = 5 }) == 2, "Stars counts three-star jobs")
check(
	Contracts.have({ kind = "Junk", need = 4 }, { jobs = 9, earned = 999, stars = 9 }) == 0
		and Contracts.have({ kind = "Mow", need = 3 }, {}) == 0,
	"a contract ignores the other kinds' counts, and a count that is missing is 0"
)

-- The streak ----------------------------------------------------------------------------------

local cashes = {}
for number = 1, 7 do
	table.insert(cashes, Streak.rewardFor(number).cash)
end
check(#Streak.Rewards == 7, "a streak week has seven rewards")
check(table.concat(cashes, " ") == "100 150 200 300 400 600 1000", "the week pays 100, 150, 200, 300, 400, 600, 1000")
check(Streak.rewardFor(7).flag == "TruckPennant" and Streak.rewardFor(6).flag == nil, "day 7 has the truck pennant")
check(
	Streak.rewardFor(14).cash == 1000 and Streak.rewardFor(14).flag == nil,
	"day 14 pays like day 7 but the pennant is only given once"
)
check(Streak.rewardFor(8).cash == 100 and Streak.rewardFor(10).cash == 200, "the week repeats with cash")
check(Streak.rewardFor(0).cash == 100, "a streak below 1 is held to day 1")
local reward = Streak.rewardFor(7)
reward.cash = 1
check(Streak.rewardFor(7).cash == 1000 and Streak.Rewards[7].cash == 1000, "a reward is a copy, not the table's own")

-- advance: a new day adds one, the same day twice adds nothing, a missed day starts again.
local running = { days = 3, last = "20261028" }
check(
	Streak.advance(running, "20261029", "20261028") == true and running.days == 4 and running.last == "20261029",
	"the day after the last one adds a day"
)
check(
	Streak.advance(running, "20261029", "20261028") == false and running.days == 4 and running.last == "20261029",
	"the same day again changes nothing"
)
local missed = { days = 3, last = "20261020" }
check(
	Streak.advance(missed, "20261029", "20261028") == true and missed.days == 1 and missed.last == "20261029",
	"a missed day starts the streak again at 1"
)
local beginner = { days = 0, last = "" }
check(
	Streak.advance(beginner, "20261029", "20261028") == true and beginner.days == 1 and beginner.last == "20261029",
	"the first day of all is day 1"
)
local week = { days = 0, last = "" }
for offset = 0, 7 do
	Streak.advance(week, Daily.dayKey(1793232000 + offset * 86400), Daily.dayKey(1793232000 + (offset - 1) * 86400))
end
check(week.days == 8 and week.last == "20261105", "eight days in a row make a streak of 8")
check(Streak.text(3) == "Day 3 of 7" and Streak.text(7) == "Day 7 of 7", "the streak line reads Day N of 7")
check(Streak.text(8) == "Day 1 of 7" and Streak.text(14) == "Day 7 of 7", "a second week starts again at day 1")

-- The gift: the day turn moves the streak on and the day's cash waits to be claimed (Gifts). A gift
-- left unclaimed is paid by the next turn, once, so nobody loses a day's cash.
check(
	Streak.waiting({ days = 3, last = "20261029", claimed = "20261028" }, "20261029"),
	"a streak kept today and not claimed today has a gift waiting"
)
check(
	not Streak.waiting({ days = 3, last = "20261029", claimed = "20261029" }, "20261029"),
	"a gift claimed today is not waiting"
)
check(
	not Streak.waiting({ days = 3, last = "20261028", claimed = "" }, "20261029"),
	"a streak not yet kept today has nothing waiting today (the turn comes first)"
)
check(not Streak.waiting({ days = 0, last = "", claimed = "" }, "20261029"), "no streak, no gift")

-- turn: the first day of all, then claimed, then the next day owes nothing.
local gift = { days = 0, last = "", claimed = "" }
local advanced, owed, owedDays = Streak.turn(gift, "20261029", "20261028")
check(
	advanced == true and owed == nil and owedDays == nil and gift.days == 1 and gift.last == "20261029",
	"the first turn of all starts the streak and owes nothing"
)
check(Streak.waiting(gift, "20261029"), "and day 1's gift waits")
local claimedReward = Streak.claim(gift, "20261029")
check(
	claimedReward ~= nil and claimedReward.cash == 100 and gift.claimed == "20261029",
	"claiming day 1 pays its $100 and marks it claimed"
)
check(Streak.claim(gift, "20261029") == nil, "a gift is claimed once")
check(not Streak.waiting(gift, "20261029"), "and is not waiting after")
advanced, owed = Streak.turn(gift, "20261030", "20261029")
check(advanced == true and owed == nil and gift.days == 2, "a claimed day owes nothing at the next turn")
check(
	Streak.turn(gift, "20261030", "20261029") == false and gift.days == 2,
	"the same day's turn again changes nothing"
)

-- A missed claim is paid by the next turn, exactly once, and the new day's gift waits.
local unclaimed = { days = 3, last = "20261029", claimed = "20261028" }
advanced, owed, owedDays = Streak.turn(unclaimed, "20261030", "20261029")
check(
	advanced == true and owed == 200 and owedDays == 3,
	"an unclaimed day 3 is paid at the next turn: $200 for day 3"
)
check(unclaimed.days == 4 and unclaimed.last == "20261030", "and the streak moves on to day 4")
check(Streak.waiting(unclaimed, "20261030"), "and day 4's gift waits to be claimed")
local again, owedAgain = Streak.turn(unclaimed, "20261030", "20261029")
check(again == false and owedAgain == nil, "the owed gift is paid once: the same day's turn again owes nothing")
check(Streak.claim(unclaimed, "20261030").cash == 300, "the new day's gift is still its own: day 4 pays $300")
check(Streak.claim(unclaimed, "20261030") == nil, "and is claimed once")

-- Day 7's gift: the pennant flag comes with the turn onto day 7 (the caller gives it then), the
-- owed gift is cash only, and the turn past day 7 brings no flag.
local seventh = { days = 6, last = "20261028", claimed = "20261028" }
advanced, owed = Streak.turn(seventh, "20261029", "20261028")
check(
	advanced == true and owed == nil and seventh.days == 7 and Streak.rewardFor(seventh.days).flag == "TruckPennant",
	"the turn onto day 7 is the one with the pennant"
)
advanced, owed, owedDays = Streak.turn(seventh, "20261030", "20261029")
check(
	advanced == true and owed == 1000 and owedDays == 7,
	"an unclaimed day 7 pays its $1,000 at the next turn"
)
check(
	seventh.days == 8 and Streak.rewardFor(seventh.days).flag == nil,
	"and the turn past day 7 has no flag, so the pennant is never given twice"
)

-- A gap of two days starts again at day 1 and still pays the one day that went unclaimed.
local gap = { days = 3, last = "20261027", claimed = "20261026" }
advanced, owed, owedDays = Streak.turn(gap, "20261030", "20261029")
check(
	advanced == true and owed == 200 and owedDays == 3 and gap.days == 1 and gap.last == "20261030",
	"a two-day gap starts again at day 1 and pays the unclaimed day 3 once"
)
check(Streak.waiting(gap, "20261030"), "and day 1's gift waits")

-- A save from before gifts: the upgrade gives it claimed = last, so its paid day owes nothing.
local oldSave = { money = 0, xp = 0, jobsCompleted = 0, streak = { days = 5, last = "20261029" } }
Season.upgradeSave(oldSave)
check(
	oldSave.streak.claimed == "20261029" and not Streak.waiting(oldSave.streak, "20261029"),
	"an upgraded {days, last} save has claimed its last day and nothing waits"
)
advanced, owed = Streak.turn(oldSave.streak, "20261030", "20261029")
check(advanced == true and owed == nil and oldSave.streak.days == 6, "and its next turn owes nothing (it was paid)")

-- The truck's pennant ---------------------------------------------------------------------------

-- Assets is Roblox code: it asks `game` for services, asks a model for its pivot, and reaches
-- Placeholders and the Config tables through `script`, none of which Lune has. So it is loaded the
-- way Season is, with those stood in: `game` hands out empty folders (so every model is its block
-- placeholder, and the pennant is Placeholders' TruckPennant), a model's pivot is its PrimaryPart's,
-- and `script` and `require` find the files under src/shared.
do
	roblox.implementMethod("Model", "GetPivot", function(model)
		return model.PrimaryPart.CFrame
	end)
	roblox.implementMethod("Model", "PivotTo", function(model, target)
		local step = target * model.PrimaryPart.CFrame:Inverse()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CFrame = step * descendant.CFrame
			end
		end
	end)

	local function located(path: string)
		return setmetatable({ path = path }, {
			__index = function(self, key)
				if key == "Parent" then
					return located(string.match(self.path, "^(.*)/[^/]+$"))
				end
				return located(`{self.path}/{key}`)
			end,
		})
	end
	local standIns: { [string]: any } = {}
	for name, value in roblox do
		standIns[name] = value
	end
	local serverStorage = roblox.Instance.new("Folder")
	standIns.game = {
		GetService = function(_, name)
			if name == "RunService" then
				return {
					IsServer = function()
						return true
					end,
				}
			elseif name == "ServerStorage" then
				return serverStorage
			end
			return roblox.Instance.new("Folder")
		end,
	}
	local loaded = {}
	local function load(module)
		if not loaded[module.path] then
			local environment = table.clone(standIns)
			environment.script = located(module.path)
			environment.require = load
			loaded[module.path] = luau.load(fs.readFile(`{module.path}.luau`), {
				debugName = module.path,
				environment = environment,
			})()
		end
		return loaded[module.path]
	end
	local Assets = load(located("src/shared/Assets"))

	-- A truck of a root and a body, and a BedArea over its rear when it is to have one.
	local function truck(withBed: boolean)
		local model = roblox.Instance.new("Model")
		local function add(name: string, size, at, transparency: number)
			local newPart = roblox.Instance.new("Part")
			newPart.Name = name
			newPart.Size = size
			newPart.Position = at
			newPart.Transparency = transparency
			newPart.Parent = model
			return newPart
		end
		model.PrimaryPart = add("Root", roblox.Vector3.new(1, 1, 1), roblox.Vector3.new(0, 0.5, 0), 1)
		add("Body", roblox.Vector3.new(6, 3, 12), roblox.Vector3.new(0, 2, 0), 0)
		if withBed then
			add("BedArea", roblox.Vector3.new(6, 0.2, 6), roblox.Vector3.new(0, 2.3, 3), 1)
		end
		return model
	end
	local function pennantsOn(model): number
		local count = 0
		for _, child in model:GetChildren() do
			if child.Name == "Pennant" then
				count += 1
			end
		end
		return count
	end

	local withBed = truck(true)
	Assets.addPennant(withBed)
	Assets.addPennant(withBed)
	check(pennantsOn(withBed) == 1, "a truck that is given the pennant twice has one")

	local noBed = truck(false)
	local ok = pcall(Assets.addPennant, noBed)
	check(ok and pennantsOn(noBed) == 1, "a truck with no BedArea does not error and still gets the pennant")

	-- The placeholder pennant is built anchored, so it cannot show that addPennant anchors. A real
	-- Props/TruckPennant model comes in loose: stand one in (ServerStorage.Assets.Props.TruckPennant,
	-- where Assets.prop looks first) with two unanchored parts that the aim can hit, and check the
	-- pennant on a truck comes back anchored and out of the aim's way.
	local assets = roblox.Instance.new("Folder")
	assets.Name = "Assets"
	local props = roblox.Instance.new("Folder")
	props.Name = "Props"
	props.Parent = assets
	local standIn = roblox.Instance.new("Model")
	standIn.Name = "TruckPennant"
	for _, name in { "Root", "Pole" } do
		local loosePart = roblox.Instance.new("Part")
		loosePart.Name = name
		loosePart.Anchored = false
		loosePart.CanQuery = true
		loosePart.Parent = standIn
	end
	standIn.PrimaryPart = standIn.Root
	standIn.Parent = props
	assets.Parent = serverStorage

	local real = truck(true)
	Assets.addPennant(real)
	local pieces, loose = 0, 0
	for _, descendant in real.Pennant:GetDescendants() do
		if descendant:IsA("BasePart") then
			pieces += 1
			if not descendant.Anchored or descendant.CanQuery then
				loose += 1
			end
		end
	end
	check(pieces == 2, "the stand-in model is the pennant that was put on the truck")
	check(loose == 0, "every part of the pennant comes back anchored and out of the way of the aim (CanQuery off)")
end

-- Settings -----------------------------------------------------------------------------------------

-- The three choices a player saves (src/shared/Config/Settings.luau, which has no requires so Lune can
-- load it). `clean` is the one rule everything trusts: the server runs it on a SaveSettings call and on
-- a save as it loads, the client on the profile, so a tampered or old value never gets further.
local Settings = require("../src/shared/Config/Settings")
local GrassImages = require("../src/shared/GrassImages")

check(Settings.Defaults.sound == "High", "the default sound is High")
check(Settings.Defaults.grass == "Auto", "the default grass detail is Auto")
-- Settings has no requires, so its motion default is a copy of what GameConfig.Camera says: a player
-- who never touches Settings keeps today's behaviour, camera motion as the game's config has it.
check(
	Settings.Defaults.motion == (GameConfig.Camera.HeadBob or GameConfig.Camera.EngineShake),
	"the default for camera motion is what GameConfig.Camera says"
)
for key, options in Settings.Options do
	check(table.find(options, Settings.Defaults[key]) ~= nil, `the default for {key} is one of its options`)
end
check(
	#Settings.Options.sound == 3 and #Settings.Options.motion == 2 and #Settings.Options.grass == 3,
	"Sound has three options, Camera motion two and Grass detail three"
)

-- Good values are kept, whatever they are.
local liked = { sound = "Low", motion = not Settings.Defaults.motion, grass = "High" }
check(sameTable(Settings.clean(liked), liked), "clean keeps good values")
for _, sound in Settings.Options.sound do
	check(Settings.clean({ sound = sound }).sound == sound, `clean keeps the sound {sound}`)
end
for _, grass in Settings.Options.grass do
	check(Settings.clean({ grass = grass }).grass == grass, `clean keeps the grass detail {grass}`)
end
for _, motion in Settings.Options.motion do
	check(Settings.clean({ motion = motion }).motion == motion, `clean keeps motion {motion}`)
end
check(sameTable(Settings.clean(Settings.Defaults), Settings.Defaults), "cleaning the defaults changes nothing")

-- Bad or missing values become the defaults, one at a time (a good one beside a bad one stays).
check(sameTable(Settings.clean({}), Settings.Defaults), "an empty table is the defaults")
local mixed = Settings.clean({ sound = "Low", motion = "yes", grass = 3 })
check(
	mixed.sound == "Low" and mixed.motion == Settings.Defaults.motion and mixed.grass == "Auto",
	"a bad value is replaced and the good one beside it stays"
)
local wrongCase = Settings.clean({ sound = "low", grass = "HIGH" })
check(wrongCase.sound == "High" and wrongCase.grass == "Auto", "values are matched exactly, not by case")
check(Settings.clean({ sound = 1 }).sound == "High", "a number is not a sound")
check(Settings.clean({ sound = { "Low" } }).sound == "High", "a table is not a sound")
check(Settings.clean({ motion = 1 }).motion == Settings.Defaults.motion, "1 is not true")
check(Settings.clean({ motion = "false" }).motion == Settings.Defaults.motion, '"false" is not false')
check(Settings.clean({ grass = "" }).grass == "Auto", "an empty string is not a grass detail")
check(Settings.clean({ sound = 0 / 0 }).sound == "High", "NaN is not a sound")

-- Anything that is not a table gives the defaults, and never errors.
for _, junk in { 5, "Low", true, false } do
	local ok, result = pcall(Settings.clean, junk)
	check(ok and sameTable(result, Settings.Defaults), `clean({tostring(junk)}) gives the defaults`)
end
local okNil, fromNil = pcall(Settings.clean, nil)
check(okNil and sameTable(fromNil, Settings.Defaults), "clean(nil) gives the defaults")
local okFn, fromFn = pcall(Settings.clean, print)
check(okFn and sameTable(fromFn, Settings.Defaults), "clean(a function) gives the defaults")

-- Unknown keys are dropped, whatever they hold, and only the three known keys come out.
local noisy = Settings.clean({ sound = "Low", cheat = true, money = 1e9, [1] = "x", [true] = "y" })
local keyCount = 0
for _ in noisy do
	keyCount += 1
end
check(keyCount == 3 and noisy.cheat == nil and noisy.money == nil and noisy[1] == nil, "clean drops unknown keys")
check(noisy.sound == "Low", "clean keeps the good value beside unknown keys")

-- It hands back a table of its own: the caller's table is not touched and the defaults cannot be
-- changed through the result.
local given = { sound = "Low", extra = 1 }
local cleaned = Settings.clean(given)
check(cleaned ~= given and given.extra == 1 and given.sound == "Low", "clean leaves the table it is given alone")
cleaned.sound = "Off"
check(
	Settings.Defaults.sound == "High" and Settings.clean({}).sound == "High",
	"the defaults cannot be changed through clean"
)
check(Settings.clean({}) ~= Settings.clean({}), "every clean is a new table")

-- Sound is a volume on the Effects group: Off 0, Low 0.5, High 1 (a bad name is the default's).
check(
	Settings.volume("Off") == 0 and Settings.volume("Low") == 0.5 and Settings.volume("High") == 1,
	"the sound volumes"
)
check(Settings.volume("Loud") == 1 and Settings.volume(nil :: any) == 1, "an unknown sound is the default volume")

-- Grass detail is a shell count: Auto is today's rule (GrassImages.shellCount: 4 on touch, 6
-- otherwise), High is the full 6 and Low the touch 4, on any device.
check(
	Settings.shells("Auto", true) == 4 and Settings.shells("Auto", false) == 6,
	"Auto is 4 shells on touch and 6 otherwise"
)
check(Settings.shells("High", true) == 6 and Settings.shells("High", false) == 6, "High is 6 shells everywhere")
check(Settings.shells("Low", true) == 4 and Settings.shells("Low", false) == 4, "Low is 4 shells everywhere")
check(Settings.shells("Fancy", false) == 6 and Settings.shells("Fancy", true) == 4, "an unknown grass detail is Auto")
check(
	Settings.shells("Auto", true) == GrassImages.shellCount(true)
		and Settings.shells("Auto", false) == GrassImages.shellCount(false),
	"Auto is GrassImages.shellCount"
)
check(
	Settings.shells("High", true) == GrassImages.shellCount(false)
		and Settings.shells("Low", false) == GrassImages.shellCount(true),
	"High and Low are the two shell counts GrassImages has"
)

-- Sounds keeps the level for the Effects group (the group itself is made on first use, in a client,
-- so none of this touches `game`): it is held between 0 and 1 and starts at full volume.
check(
	typeof(Sounds.setVolume) == "function" and typeof(Sounds.getVolume) == "function",
	"Sounds has setVolume and getVolume"
)
if typeof(Sounds.setVolume) == "function" and typeof(Sounds.getVolume) == "function" then
	check(Sounds.getVolume() == 1, "the Effects volume starts at full")
	Sounds.setVolume(0.5)
	check(Sounds.getVolume() == 0.5, "setVolume sets the level")
	Sounds.setVolume(7)
	check(Sounds.getVolume() == 1, "the level is held at 1")
	Sounds.setVolume(-3)
	check(Sounds.getVolume() == 0, "the level is held at 0")
	Sounds.setVolume(1)
end

-- The save and the server: the wiring is checked in the text, as DataService cannot load here.
local function source(path: string): string
	return if fs.isFile(path) then fs.readFile(path) else ""
end
local function has(text: string, wanted: string): boolean
	return string.find(text, wanted, 1, true) ~= nil
end
local dataService = source("src/server/Services/DataService.luau")
check(has(source("src/shared/Net.luau"), '"SaveSettings"'), "Net has the SaveSettings function")
local fromDefault = string.match(dataService, "local function defaultData%(%).-\nend\n") or ""
check(has(fromDefault, "settings = Settings.clean("), "defaultData has the top-level settings key")
local fromReconcile = string.match(dataService, "local function reconcile%(data%).-\nend\n") or ""
check(
	has(fromReconcile, "data.settings = Settings.clean(data.settings)"),
	"reconcile fills the settings key and cleans a tampered or old value on load"
)
local fromSnapshot = string.match(dataService, "local function snapshot%(data%).-\nend\n") or ""
check(has(fromSnapshot, "settings = data.settings"), "snapshot sends the settings")
local fromHandler = string.match(dataService, 'Net.func%("SaveSettings"%).-\n\tend\n') or ""
check(fromHandler ~= "", "DataService answers SaveSettings")
check(has(fromHandler, 'typeof(value) ~= "table"'), "SaveSettings refuses anything that is not a table")
check(has(fromHandler, "Settings.clean(value)"), "SaveSettings cleans what it is sent")
check(has(fromHandler, "SETTINGS_COOLDOWN"), "SaveSettings is rate limited")
check(has(fromHandler, "self:Changed(player)"), "SaveSettings pushes the profile")
check(has(dataService, "DATA_VERSION = 14"), "no version bump for the settings key")
local soundsSource = source("src/shared/Sounds.luau")
check(has(soundsSource, "SoundGroup") and has(soundsSource, '"Effects"'), "Sounds has the Effects SoundGroup")

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("Season checks passed")
