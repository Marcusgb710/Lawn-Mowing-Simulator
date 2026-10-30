-- Checks the story's config and logic outside Roblox:
--   lune run scripts/check-story
-- It checks every scene, beat and act points at things that exist, that the act gates and beats
-- fire when docs/STORY.md says they should (src/shared/Config/Story.luau), TurfKing's rules for
-- taking jobs and winning customers back (src/shared/Config/TurfKing.luau), and the Best Yard
-- contest's scoring, Gloria's bar and when judging day comes round, in jobs for the first one and
-- on Saturdays (UTC) after it (src/shared/Config/Contest.luau, with src/shared/Daily.luau handed
-- in), and the nine people's catalog outfits
-- (src/shared/Config/Cast.luau; scripts/cast-check.py asks the catalog about their ids), and where
-- CastService puts a rig's Root so it stands on the spot a statue did (src/shared/CastRig.luau), and
-- which pose NpcAnimator picks for a person and how fast the judges' walk plays
-- (src/shared/NpcAnimator.luau), and that the first-timer's job never reaches the job board
-- (src/shared/Config/Jobs.luau) and hides no junk in its grass (src/shared/Config/Debris.luau).
-- Exits with an error if anything's off.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Cast = require("../src/shared/Config/Cast")
local CastRig = require("../src/shared/CastRig")
local Daily = require("../src/shared/Daily")
local Story = require("../src/shared/Config/Story")
local TurfKing = require("../src/shared/Config/TurfKing")

-- Contest reaches Daily through `script` (script.Parent.Parent.Daily), which Lune doesn't have. So
-- it is loaded here with Daily stood in for and handed to its require, the way check-season loads
-- Season and gives it GameConfig: the Saturday rules below are the real ones. Run from the repo
-- root, like the command at the top.
local Contest = luau.load(fs.readFile("src/shared/Config/Contest.luau"), {
	debugName = "Contest",
	environment = {
		script = { Parent = { Parent = { Daily = Daily } } },
		require = function(module)
			return module
		end,
	},
})()

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL  " .. message)
	end
end

local function same(a: { any }, b: { any }): boolean
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

local function facts(overrides)
	local base = {
		act = 1,
		level = 1,
		jobsCompleted = 0,
		curbAppeal = 0,
		money = 0,
		owned = { GardenShears = true },
		motorMower = false,
		seen = {},
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function beatIds(event, someFacts, seen, act): { string }
	local ids = {}
	for _, beat in Story.beatsFor(event, someFacts, seen or {}, act or someFacts.act) do
		table.insert(ids, beat.id)
	end
	return ids
end

-- The config fits together ------------------------------------------------------------------

local placeholders = {
	pay = true,
	customer = true,
	who = true,
	item = true,
	left = true,
	appeal = true,
	bar = true,
	rival = true,
	jobs = true,
	days = true,
}
local function checkText(text: string, where: string)
	for name in string.gmatch(text, "{(%w+)}") do
		check(placeholders[name] == true, `{where}: unknown placeholder {"{"}{name}{"}"}`)
	end
	local _, stars = string.gsub(text, "%*", "")
	check(stars % 2 == 0, `{where}: an unclosed *highlight*`)
end
local function checkThread(thread: string, where: string)
	check(Story.Threads[thread] ~= nil or thread == "{customer}", `{where}: unknown thread {thread}`)
end

-- A mood is one of the speaker's portraits.
local function checkMood(speaker: string?, mood: string?, where: string)
	local cast = speaker and Story.Cast[speaker]
	check(
		mood == nil or (cast ~= nil and cast.moods ~= nil and table.find(cast.moods, mood) ~= nil),
		`{where}: {speaker} has no {mood} portrait`
	)
end

for id, scene in Story.Scenes do
	check(#scene.lines > 0, `scene {id} has no lines`)
	check(scene.act == nil or Story.Acts[scene.act] ~= nil, `scene {id}: no act {scene.act}`)
	for index, line in scene.lines do
		local where = `scene {id} line {index}`
		check(typeof(line.text) == "string" and #line.text > 0, `{where} has no text`)
		checkText(line.text, where)
		check(line.speaker == nil or Story.Cast[line.speaker] ~= nil, `{where}: unknown speaker {line.speaker}`)
		check(
			line.shot == nil or line.shot == "June" or line.shot == "Gloria" or line.shot == "Yard",
			`{where}: unknown shot {line.shot}`
		)
		check(line.judges == nil or line.judges == "Yard" or line.judges == "Gloria", `{where}: judges walk where?`)
		check(not line.bubble or line.speaker ~= nil, `{where}: a bubble needs a speaker`)
		checkMood(line.speaker, line.mood, where)
	end
end

local beatSeen = {}
for _, beat in Story.Beats do
	check(not beatSeen[beat.id], `beat {beat.id} is listed twice`)
	beatSeen[beat.id] = true
	check(beat.scene == nil or Story.Scenes[beat.scene] ~= nil, `beat {beat.id}: no scene {beat.scene}`)
	for index, text in beat.texts or {} do
		checkThread(text.thread, `beat {beat.id} text {index}`)
		checkText(text.text, `beat {beat.id} text {index}`)
	end
end

for index, act in Story.Acts do
	check(typeof(act.name) == "string", `act {index} has no name`)
	check(act.goal ~= nil, `act {index} has no goal`)
	if index > 1 then
		check(act.startsWhen ~= nil, `act {index} never starts`)
		check(act.scene == nil or Story.Scenes[act.scene] ~= nil, `act {index}: no scene {act.scene}`)
		check(act.mowerScene == nil or Story.Scenes[act.mowerScene] ~= nil, `act {index}: no scene {act.mowerScene}`)
	end
	for textIndex, text in act.texts or {} do
		checkThread(text.thread, `act {index} text {textIndex}`)
		checkText(text.text, `act {index} text {textIndex}`)
	end
end

for _, band in Story.Critiques do
	for _, line in band.lines do
		checkText(line, "critique")
	end
end
for act, lines in Story.JuneTalk.Progress do
	for _, line in lines do
		checkText(line, `June's act {act} talk`)
	end
end
for state, lines in Story.JuneTalk.Contest do
	for _, line in lines do
		checkText(line, `June's contest talk ({state})`)
	end
end
for kind, texts in Story.ContestTexts do
	for index, text in texts do
		checkThread(text.thread, `contest text {kind} {index}`)
		checkText(text.text, `contest text {kind} {index}`)
	end
end
for kind, closing in Story.ContestClosing do
	check(Story.Cast[closing.speaker] ~= nil, `the contest's {kind} closing line has no speaker`)
	checkMood(closing.speaker, closing.mood, `the contest's {kind} closing line`)
end
-- The scenes ContestService plays.
for _, id in { "ContestJudging", "ContestJudgingAgain", "ContestWin", "ContestWinAgain", "ContestLose" } do
	check(Story.Scenes[id] ~= nil, `no {id} scene`)
end
check(#Story.GloriaRemarks == #Story.Acts, "Gloria has remarks for every act")
for act, lines in Story.GloriaRemarks do
	check(#lines > 0, `Gloria has nothing to say in act {act}`)
	for _, line in lines do
		checkText(line, `Gloria's act {act} remark`)
	end
end
for _, line in Story.ChadRemarks do
	checkText(line, "Chad's remark")
end
for _, line in Story.TurfKingTexts do
	checkText(line, "Chad's text when TurfKing takes a job")
end
check(#Story.GloriaYard.Stages == #Story.Acts, "Gloria's yard has a stage for every act")
for act, stage in Story.GloriaYard.Stages do
	check(stage >= 1 and stage <= 3, `act {act}: no yard stage {stage}`)
end

-- Act gates -----------------------------------------------------------------------------------

local none = { kind = "Joined" }
check(same(Story.actsToStart(1, facts(), none), {}), "a new player stays in act 1")
check(same(Story.actsToStart(1, facts({ owned = { ReelMower = true } }), none), { 2 }), "the reel mower starts act 2")
check(same(Story.actsToStart(1, facts({ level = 3 }), none), { 2 }), "level 3 starts act 2 without a mower")
check(
	same(Story.actsToStart(1, facts({ owned = { GasPushMower = true }, motorMower = true }), none), { 2, 3 }),
	"a gas mower straight away goes through act 2 to act 3"
)
check(
	same(Story.actsToStart(2, facts({ owned = { ReelMower = true } }), none), {}),
	"act 2 waits for a motorized mower"
)
check(
	same(Story.actsToStart(2, facts({ owned = { ReelMower = true } }), { kind = "JobFinished", crew = 2 }), { 3 }),
	"a crew job starts act 3"
)
check(
	same(Story.actsToStart(2, facts({ owned = { ReelMower = true } }), { kind = "JobFinished", crew = 1 }), {}),
	"a solo job doesn't start act 3"
)
check(same(Story.actsToStart(2, facts({ level = 4 }), none), { 3 }), "level 4 starts act 3")
check(same(Story.actsToStart(3, facts({ curbAppeal = Story.ContestBar - 1 }), none), {}), "act 3 waits for the bar")
check(same(Story.actsToStart(3, facts({ curbAppeal = Story.ContestBar }), none), { 4 }), "the bar starts act 4")
check(same(Story.actsToStart(3, facts({ level = 10 }), none), { 4 }), "level 10 starts act 4")
check(same(Story.actsToStart(4, facts({ level = 99, curbAppeal = 100 }), none), {}), "there's no act 5")
check(
	same(Story.actsToStart(1, facts({ owned = { ReelMower = true }, level = 4 }), none), { 2, 3 }),
	"a returning level 4 player is caught up to act 3"
)

check(
	Story.openingScene(2, { kind = "Bought", category = "Mower", itemId = "ReelMower" }) == "Act2Mower",
	"buying the reel mower opens act 2 with June's mower line"
)
check(Story.openingScene(2, { kind = "LevelUp", level = 3 }) == "Act2", "reaching level 3 opens act 2 without it")
check(Story.openingScene(4, none) == "Act4", "act 4 has its scene")

-- Beats ---------------------------------------------------------------------------------------

-- A new player starts on a lawn with the shears in hand (JobService:StartFirstJob), so nothing
-- plays as they join: June's welcome waits for their first payday, ahead of her texts about it.
check(#beatIds({ kind = "Joined" }, facts()) == 0, "no beat fires as a new player joins")
check(
	same(beatIds({ kind = "Joined" }, facts({ jobsCompleted = 5 })), { "WelcomeBack" }),
	"a returning player gets the welcome back"
)
check(
	#beatIds({ kind = "Joined" }, facts({ jobsCompleted = 3, seen = { Intro = true } }), { Intro = true }) == 0,
	"someone who had the intro isn't welcomed back"
)
local job =
	{ kind = "JobFinished", customer = "Mrs. Alvarez", pay = 66, quality = 0.8, preference = "Balanced", crew = 1 }
local intro = Story.beat("Intro")
check(intro ~= nil and intro.on == "JobFinished", "the intro waits for a finished job")
check(
	intro ~= nil and intro.when(facts({ jobsCompleted = 1, seen = {} }), job) == true,
	"the intro plays at the first payday"
)
check(
	intro ~= nil and intro.when(facts({ jobsCompleted = 1, seen = { Intro = true } }), job) == false,
	"the intro plays once"
)
check(
	same(beatIds(job, facts({ jobsCompleted = 1 })), { "Intro", "FirstJob" }),
	"the first payday plays the intro, then June texts"
)
check(
	same(beatIds(job, facts({ jobsCompleted = 1, seen = { Intro = true } }), { Intro = true }), { "FirstJob" }),
	"June texts after the first job"
)
check(same(beatIds(job, facts({ jobsCompleted = 2 })), { "SecondJob" }), "Mrs. Rossi texts after the second job")
-- Winning a customer back from TurfKing: JobService says `wonBack` when it pays their bonus.
local perfect = {
	kind = "JobFinished",
	customer = "Ms. Nguyen",
	quality = 0.92,
	preference = "Quality",
	crew = 1,
	wonBack = TurfKing.winsBack(2, "Quality", 0.92),
}
check(perfect.wonBack, "a 90% finish for a Quality customer wins them back")
check(not TurfKing.winsBack(2, "Quality", 0.89), "89% isn't enough to beat TurfKing")
check(not TurfKing.winsBack(1, "Quality", 0.99), "beating TurfKing waits for act 2")
check(not TurfKing.winsBack(3, "Balanced", 0.99), "only customers who wanted it perfect are won back")
check(#beatIds(perfect, facts({ act = 1, jobsCompleted = 9 })) == 0, "the won-back text waits for act 2")
check(same(beatIds(perfect, facts({ act = 2, jobsCompleted = 9 })), { "QualityWin" }), "the won-back customer texts")
local wonBefore = { ["QualityWin:Ms. Nguyen"] = true }
check(#beatIds(perfect, facts({ act = 2 }), wonBefore) == 0, "a customer is only won back once")
local another = table.clone(perfect)
another.customer = "Mr. Chen"
check(same(beatIds(another, facts({ act = 2 }), wonBefore), { "QualityWin" }), "each customer can be won back")
local notWon = table.clone(perfect)
notWon.wonBack = false
check(#beatIds(notWon, facts({ act = 2 })) == 0, "no text without the bonus")
check(Story.beatKey(Story.beat("QualityWin"), perfect) == "QualityWin:Ms. Nguyen", "won-back beats are per customer")
check(Story.beatKey(Story.beat("FirstJob"), perfect) == "FirstJob", "other beats fire once in all")
for _, payout in { 0, 45, 66, 250, 650, 3500 } do
	local bonus = TurfKing.bonus(payout)
	check(
		bonus >= TurfKing.WinBonusMin and bonus <= TurfKing.WinBonusMax and bonus % 5 == 0,
		`the won-back bonus on {payout} is {bonus}`
	)
end
check(TurfKing.bonus(3500) == TurfKing.WinBonusMax, "the won-back bonus is capped")

check(Story.critique(facts({ jobsCompleted = 1 }), job) == nil, "the first job has its own texts, no critique")
check(Story.critique(facts({ jobsCompleted = 2 }), job) ~= nil, "June critiques the second job")
check(Story.critique(facts({ act = 2, jobsCompleted = 5 }), job) == nil, "June stops critiquing after act 1")
local poor = Story.critique(facts({ jobsCompleted = 2 }), { kind = "JobFinished", quality = 0.4 })
check(poor == Story.Critiques[3].lines[1], "a poor finish gets a poor critique")

-- The first job -------------------------------------------------------------------------------

-- Jobs reaches TaskTypes, and TaskTypes reaches Tools, through `script`, which Lune doesn't have,
-- and Tools builds Color3s and Vector3s as it loads. So each is loaded here with Lune's and handed
-- to the next as its sibling, the way check-season loads Season. Run from the repo root, like the
-- command at the top.
local function loadConfig(name: string, siblings: { [string]: any }?)
	return luau.load(fs.readFile(`src/shared/Config/{name}.luau`), {
		debugName = name,
		environment = {
			Color3 = roblox.Color3,
			Vector3 = roblox.Vector3,
			script = { Parent = siblings or {} },
			require = function(module)
				return module
			end,
		},
	})()
end
local Tools = loadConfig("Tools")
local TaskTypes = loadConfig("TaskTypes", { Tools = Tools })
local Jobs = loadConfig("Jobs", { TaskTypes = TaskTypes })
local Debris = loadConfig("Debris")

local firstMow = Jobs.get("FirstMow")
check(firstMow ~= nil and firstMow.hidden == true, "the first-timer's job is hidden")
check(typeof(Jobs.boardTemplates) == "function", "Jobs.boardTemplates is there")
local onBoard = if typeof(Jobs.boardTemplates) == "function" then Jobs.boardTemplates() else {}
local hiddenOnBoard = false
for _, template in onBoard do
	hiddenOnBoard = hiddenOnBoard or template.hidden == true
end
check(not hiddenOnBoard, "a hidden template is never on the board")
check(#onBoard == #Jobs.Templates - 1, "the board offers every template but the first-timer's")
-- The first strip hides no junk: the coach teaches the snip and nothing else, so a first-timer
-- who never spotted a stick would lose stars, the tip and the first milestone for it. The count
-- comes from the same function LawnService builds the lawn with.
check(firstMow ~= nil and Debris.countFor(firstMow) == 0, "the first strip hides no junk")
check(Debris.countFor(Jobs.get("QuickMow")) == 4, "the board's Front Lawn still hides its 4 pieces")
local junkLawn = { columns = 9, rows = 7 }
check(Debris.countFor({ tier = "Homeowner", lawn = junkLawn, junk = 0 }) == 0, "a template's junk of 0 is honoured")
check(Debris.countFor({ tier = "Homeowner", lawn = junkLawn, junk = 3 }) == 3, "a template's junk sets the count")
check(Debris.countFor({ tier = "Homeowner", lawn = junkLawn }) == 4, "no junk set: the lawn's size and tier decide")
check(
	Debris.countFor({ tier = "Homeowner", lawn = { columns = 9, rows = 7, debris = 2 } }) == 2,
	"lawn.debris still sets it"
)

-- TurfKing taking jobs ------------------------------------------------------------------------

check(not TurfKing.canFlip(1, 20, nil), "TurfKing doesn't take jobs in act 1")
check(TurfKing.canFlip(2, 5, nil), "TurfKing can take a job once act 2 starts")
check(not TurfKing.canFlip(2, 6, 5), "TurfKing waits a few jobs between takes")
check(not TurfKing.canFlip(4, 5 + TurfKing.FlipEveryJobs - 1, 5), "...all of them")
check(TurfKing.canFlip(3, 5 + TurfKing.FlipEveryJobs, 5), "...then it can take another")
local board = {
	{ id = "1", kind = "StarterGear", minLevel = 1 },
	{ id = "2", kind = "Homeowner", minLevel = 1 },
	{ id = "3", kind = "Homeowner", minLevel = 1 },
	{ id = "4", kind = "Open", minLevel = 1 },
	{ id = "5", kind = "Open", minLevel = 6 },
	{ id = "6", kind = "Open", minLevel = 2 },
}
local ids = {}
for _, offer in TurfKing.candidates(board, { ["2"] = true }, { ["4"] = true }, 3) do
	table.insert(ids, offer.id)
end
check(same(ids, { "3", "6" }), "TurfKing never takes the starter job, a taken or accepted one, or a locked one")
check(#TurfKing.candidates({ board[1] }, nil, nil, 99) == 0, "a board with only the starter job is safe")

-- Gloria's yard ------------------------------------------------------------------------------

local stages = {}
for act = 1, #Story.Acts do
	local stage, turfKing = Story.gloriaStage(act)
	stages[act] = `{stage}{if turfKing then "+" else ""}`
end
check(same(stages, { "1", "2+", "2+", "3+" }), "Gloria's yard: tired, TurfKing's, TurfKing's, over the top")
local speaker, line = Story.porchRemark(1, 2)
check(speaker == "Gloria", "Chad isn't across the street in act 1")
speaker, line = Story.porchRemark(2, 2)
check(speaker == "Chad" and line == "Cute scissors, bud.", "Chad's first word from her drive")
speaker = Story.porchRemark(2, 3)
check(speaker == "Gloria", "Gloria and Chad take turns")
for act = 1, #Story.Acts do
	for turn = 1, 8 do
		local _, remark = Story.porchRemark(act, turn)
		check(typeof(remark) == "string" and #remark > 0, `a porch remark, act {act} turn {turn}`)
	end
end
for count = 1, 6 do
	local text = Story.turfKingText(count, "Mr. Chen")
	check(not string.find(text, "{", 1, true), `Chad's text {count} fills in`)
end
check(Story.turfKingText(1, nil) ~= "", "Chad has something to say without a customer")

-- The Best Yard contest -------------------------------------------------------------------------

local function scored(overrides)
	local measures = {
		lawnShare = 1,
		edgeShare = 1,
		junk = 0,
		beds = Contest.BedsWanted,
		tidyShrubs = Contest.ShrubsWanted,
		shaggyShrubs = 0,
		decorShare = Contest.CharmShare,
		kinds = Contest.KindsWanted,
	}
	for key, value in overrides or {} do
		measures[key] = value
	end
	return Contest.score(measures)
end
local full = Contest.CategoryPoints
local perfectYard = scored()
check(perfectYard.total == full * 4, "a perfect yard scores 100")
for _, category in Contest.Categories do
	check(perfectYard[category.id] == full, `a perfect yard gets full marks for {category.name}`)
end
local nothing = Contest.score({})
check(nothing.total == 0, "an empty yard scores nothing")
check(scored({ lawnShare = 0.5 }).Lawn == 13, "half the lawn done is half the lawn's points")
check(scored({ junk = 2 }).Lawn == full - 2 * Contest.JunkPoints, "junk in the grass costs lawn points")
check(scored({ lawnShare = 0, junk = 9 }).Lawn == 0, "the lawn can't go below 0")
check(scored({ edgeShare = 0 }).Edges == 0, "edges come from the edge targets")
check(scored({ beds = 0 }).Beds == 13, "beds are half of beds and shrubs")
check(
	scored({ tidyShrubs = 0, shaggyShrubs = Contest.ShrubsWanted }).Beds
		< scored({ tidyShrubs = Contest.ShrubsWanted }).Beds,
	"shaggy shrubs count for less than trimmed ones"
)
check(scored({ beds = 99, tidyShrubs = 99 }).Beds == full, "beds and shrubs top out")
check(scored({ decorShare = 1, kinds = 99 }).Charm == full, "charm tops out")
check(scored({ kinds = 0 }).Charm < full, "a yard of one kind of thing is less charming")
check(scored({ decorShare = 0, kinds = 0 }).Charm == 0, "no decorations, no charm")
-- A yard fresh from act 3's curb appeal bar (a tidy lawn and a few decorations) isn't enough.
local actThreeYard = scored({ beds = 1, tidyShrubs = 2, decorShare = 0.375, kinds = 4 })
check(not Contest.won(actThreeYard, Contest.gloriaScores(1)), "a few decorations don't beat Gloria")

check(Contest.bar(1) == 88, "Gloria's bar is 88 the first summer")
check(Contest.bar(2) > Contest.bar(1), "her bar goes up each summer")
check(Contest.bar(99) == Contest.GloriaBar.Max, "her bar is capped")
for summer = 1, 12 do
	local hers = Contest.gloriaScores(summer)
	local sum, highest = 0, 0
	for _, category in Contest.Categories do
		sum += hers[category.id]
		highest = math.max(highest, hers[category.id])
	end
	check(sum == hers.total and hers.total == Contest.bar(summer), `Gloria's scores add up, summer {summer}`)
	check(highest <= full, `none of Gloria's scores is over {full}, summer {summer}`)
end
check(Contest.gloriaScores(1).Edges >= Contest.gloriaScores(1).Charm, "TurfKing's edges are its best")
check(Contest.won({ total = 88 }, { total = 88 }), "a tie goes to June")
check(not Contest.won({ total = 87 }, { total = 88 }), "one short loses")

local fresh = { pending = false, nextAt = 0 }
check(Contest.state(fresh, 3, 40) == "Locked", "no contest before act 4")
check(Contest.state(fresh, 4, 40) == "Open", "June offers in act 4")
check(Contest.state({ pending = { won = true }, nextAt = 0 }, 4, 40) == "Results", "judged: the results wait")
check(Contest.state({ pending = false, nextAt = 44 }, 4, 41) == "Waiting", "after judging day, a wait")
check(Contest.state({ pending = false, nextAt = 44 }, 4, 44) == "Open", "then it's open again")
check(Contest.nextAt(false, 40) == 40 + Contest.RetryJobs, "a loss can be tried again in a few jobs")
check(Contest.nextAt(true, 40) == 40 + Contest.SummerJobs, "a win brings next summer's contest later")
check(Contest.RetryJobs < Contest.SummerJobs, "trying again comes sooner than next summer")

-- Judging day on the calendar: the first one follows the jobs rule above, and once it has been
-- played judging day is every Saturday (UTC). The dates are fixed: 00:00 UTC on Thursday 29 October
-- 2026 is 1793232000, and on Saturday 31 October 2026 it is 1793404800. An hour is added to most
-- of them, so the moment is well inside its day and not on the second the day begins.
local THURSDAY = 1793232000
local SATURDAY = 1793404800
local HOUR = 3600
local DAY = 86400
local calendar = { judged = 1, lastJudged = "", pending = false }
check(Contest.calendarState(calendar, 4, 40, THURSDAY + HOUR) == "Waiting", "Thursday waits for Saturday")
check(Contest.daysUntilJudging(calendar, THURSDAY + HOUR) == 2, "Thursday is 2 days from judging day")
check(Contest.daysUntilJudging(calendar, SATURDAY - HOUR) == 1, "Friday is 1 day from judging day")
check(Contest.calendarState(calendar, 4, 40, SATURDAY + HOUR) == "Open", "Saturday is judging day")
check(Contest.calendarState(calendar, 4, 40, SATURDAY + DAY - 1) == "Open", "all of Saturday is judging day")
check(Contest.daysUntilJudging(calendar, SATURDAY + HOUR) == 0, "on judging day there are no days to wait")
check(Contest.calendarState(calendar, 4, 40, SATURDAY + DAY + HOUR) == "Waiting", "Sunday waits again")
check(Contest.daysUntilJudging(calendar, SATURDAY + DAY + HOUR) == 6, "Sunday is 6 days from judging day")
check(
	Contest.calendarState({ judged = 1, pending = false }, 4, 40, SATURDAY + HOUR) == "Open",
	"a save with no last judging day has not judged this Saturday"
)
local judgedSaturday = { judged = 2, lastJudged = "20261031", pending = false }
check(Contest.calendarState(judgedSaturday, 4, 40, SATURDAY + HOUR) == "Waiting", "judged once, not twice, a Saturday")
check(Contest.daysUntilJudging(judgedSaturday, SATURDAY + HOUR) == 7, "after judging, next Saturday is 7 days away")
check(Contest.daysUntilJudging(judgedSaturday, SATURDAY + DAY - 1) == 7, "...till midnight")
check(Contest.calendarState(judgedSaturday, 4, 40, SATURDAY + 7 * DAY + HOUR) == "Open", "next Saturday is open again")
check(Contest.daysUntilJudging(judgedSaturday, SATURDAY + DAY + HOUR) == 6, "Sunday after judging is 6 days away")
check(Contest.calendarState(calendar, 3, 40, SATURDAY + HOUR) == "Locked", "no judging day before act 4")
local calendarResults = { judged = 1, lastJudged = "20261031", pending = { won = true } }
check(Contest.calendarState(calendarResults, 4, 40, THURSDAY + HOUR) == "Results", "judged: the results wait")
check(Contest.calendarState(calendarResults, 4, 40, SATURDAY + HOUR) == "Results", "...even on a Saturday")
-- Before the first judging day it is still jobs, not the calendar: open on a Thursday, and waiting
-- on a Saturday.
local firstDay = { judged = 0, lastJudged = "", pending = false, nextAt = 0 }
check(Contest.calendarState(firstDay, 4, 0, THURSDAY + HOUR) == "Open", "the first judging day is open on any day")
check(
	Contest.calendarState({ pending = false }, 4, 0, THURSDAY + HOUR) == "Open",
	"a save with no judged count is a first day"
)
firstDay.nextAt = 5
check(Contest.calendarState(firstDay, 4, 2, THURSDAY + HOUR) == "Waiting", "the first day waits for its jobs")
check(Contest.calendarState(firstDay, 4, 2, SATURDAY + HOUR) == "Waiting", "...even on a Saturday")
check(Contest.calendarState(firstDay, 4, 5, THURSDAY + HOUR) == "Open", "...and opens when they are done")
check(Contest.calendarState(firstDay, 3, 9, THURSDAY + HOUR) == "Locked", "the first day is locked before act 4 too")

-- Lost Saturdays count toward a new summer: the first judging day is the jobs rule's and counts for
-- nothing, then each loss adds one, and the fourth starts a new summer and the count again.
check(Contest.SaturdaysPerSummer == 4, "four lost Saturdays start a new summer")
local lostSaturdays, newSummer = Contest.afterLoss(1, 0)
check(lostSaturdays == 0 and newSummer == false, "losing the first judging day counts no Saturday")
lostSaturdays, newSummer = Contest.afterLoss(1, 2)
check(lostSaturdays == 2 and newSummer == false, "...and leaves the count that was there alone")
lostSaturdays, newSummer = Contest.afterLoss(5, 0)
check(lostSaturdays == 1 and newSummer == false, "a loss on a later judging day adds one Saturday")
local counts, summers = {}, {}
lostSaturdays = 0
for judged = 2, 5 do
	lostSaturdays, newSummer = Contest.afterLoss(judged, lostSaturdays)
	table.insert(counts, lostSaturdays)
	table.insert(summers, tostring(newSummer))
end
check(
	table.concat(counts, ",") == "1,2,3,0" and table.concat(summers, ",") == "false,false,false,true",
	"four lost Saturdays in a row count 1, 2, 3, then 0 with a new summer only on the fourth"
)
lostSaturdays, newSummer = Contest.afterLoss(6, lostSaturdays)
check(lostSaturdays == 1 and newSummer == false, "the count starts again after a new summer")

local firstWin = Contest.rewards(0, { Shed = true, Garage = true })
check(firstWin.money == Contest.Prize and firstWin.money == 2500, "winning pays $2,500")
check(firstWin.trophy == "BestYardTrophy", "the first win brings the trophy")
check(firstWin.discount == "SmallOffice", "...and half off the Small Office")
check(Contest.rewards(0, { SmallOffice = true }).discount == "EquipmentYard", "with the office, the Equipment Yard")
check(Contest.rewards(0, { SmallOffice = true, EquipmentYard = true }).discount == nil, "owning both, no discount")
local secondWin = Contest.rewards(1, {})
check(secondWin.trophy == nil and secondWin.discount == nil, "later wins pay the prize only")
check(Contest.discounted(20000) == 10000, "half off")

for _, state in { "Open", "Waiting", "Results" } do
	for turn = 1, 6 do
		local said =
			Story.juneLine(4, turn, { appeal = 80, bar = Story.ContestBar, contest = state, rival = 88, jobs = 3 })
		check(not string.find(said, "{", 1, true), `June's contest line, {state} turn {turn}`)
	end
end
local offerLine = Story.juneLine(4, 1, { appeal = 80, contest = "Open", rival = 88 })
check(string.find(offerLine, "88", 1, true) ~= nil, "June says what Gloria's yard would score")
check(
	not string.find(Story.juneLine(4, 1, { appeal = 80, contest = "Waiting" }), "{", 1, true),
	"June still has something to say about the contest without the jobs left"
)
-- On the calendar she counts the days to Saturday instead of the jobs.
for turn = 1, 6 do
	local said = Story.juneLine(4, turn, { appeal = 80, bar = Story.ContestBar, contest = "Waiting", days = "2 days" })
	check(not string.find(said, "{", 1, true), `June's calendar line, turn {turn}`)
end
local calendarLine = Story.juneLine(4, 1, { appeal = 80, contest = "Waiting", days = "2 days" })
check(
	string.find(calendarLine, "Saturday", 1, true) ~= nil and string.find(calendarLine, "2 days", 1, true) ~= nil,
	"June says how many days to Saturday"
)
check(
	string.find(Story.juneLine(4, 1, { appeal = 80, contest = "Waiting", jobs = 3 }), "3 jobs", 1, true) ~= nil,
	"before the calendar, June still counts the jobs"
)

-- The cast's outfits --------------------------------------------------------------------------

-- Every person in Cast.People, and which of Story.Cast they are (for their name).
local castPeople = {
	NPC_Gloria = "Gloria",
	NPC_Chad = "Chad",
	NPC_Edna = "Edna",
	NPC_June_Sitting = "June",
	NPC_June_Standing = "June",
	NPC_Sam_Casual = "Sam",
	NPC_Sam_TurfKing = "Sam",
	NPC_Judge1 = "Judge1",
	NPC_Judge2 = "Judge2",
}
-- Enum.AccessoryType names a layered garment can have (asset types 64 to 72).
local layeredTypes = {
	TShirt = true,
	Shirt = true,
	Pants = true,
	Jacket = true,
	Sweater = true,
	Shorts = true,
	LeftShoe = true,
	RightShoe = true,
	DressSkirt = true,
}

-- Lune has no Color3 or Vector3, so Cast.luau keeps colors as { r, g, b } and seats as { x, y, z }.
local function isColor(color): boolean
	if typeof(color) ~= "table" then
		return false
	end
	for _, key in { "r", "g", "b" } do
		local channel = color[key]
		if typeof(channel) ~= "number" or channel < 0 or channel > 255 or channel % 1 ~= 0 then
			return false
		end
	end
	return true
end
local function isAssetId(id: any): boolean
	return typeof(id) == "number" and id >= 0 and id % 1 == 0
end
local function sameColor(a, b): boolean
	return (a == nil and b == nil) or (a ~= nil and b ~= nil and a.r == b.r and a.g == b.g and a.b == b.b)
end

for id, who in castPeople do
	local person = Cast.People[id]
	check(person ~= nil, `the cast has no {id}`)
	if person then
		local where = `cast {id}`
		check(Cast.Poses[person.pose] ~= nil, `{where}: no pose {person.pose}`)
		check(person.name == Story.Cast[who].name, `{where} is called {person.name}, not {Story.Cast[who].name}`)
		check(isColor(person.body.skin), `{where}: skin is not an {"{ r, g, b }"} color`)
		for _, scale in { "heightScale", "widthScale", "headScale" } do
			local value = person.body[scale]
			check(
				typeof(value) == "number" and value >= 0.9 and value <= 1.1,
				`{where}: {scale} {value} is not 0.9 to 1.1`
			)
		end
		check(person.body.proportion >= 0 and person.body.proportion <= 1, `{where}: proportion is not 0 to 1`)
		for _, slot in { "hair", "hat", "face", "shirt", "pants", "tshirt" } do
			check(person[slot] == nil or isAssetId(person[slot]), `{where}: {slot} is not a catalog id`)
		end
		check(
			person.hairColor == nil or isColor(person.hairColor),
			`{where}: hairColor is not an {"{ r, g, b }"} color`
		)
		check(person.hairColor == nil or person.hair ~= nil, `{where}: hairColor without hair`)
		local orders = {}
		for index, garment in person.layered do
			check(isAssetId(garment.id) and garment.id > 0, `{where}: layered {index} has no catalog id`)
			check(layeredTypes[garment.type] == true, `{where}: layered {index} is a {garment.type}`)
			check(not orders[garment.order], `{where}: two layered garments at order {garment.order}`)
			orders[garment.order] = true
		end
		-- A sitting person has somewhere to sit; no one else does.
		local seat = person.seat
		check((person.pose == "Sit") == (seat ~= nil), `{where}: a seat goes with the Sit pose and nothing else`)
		if seat then
			check(
				typeof(seat.x) == "number" and typeof(seat.y) == "number" and typeof(seat.z) == "number",
				`{where}: seat is not an {"{ x, y, z }"} table`
			)
		end
		-- The description is what CastService hands the HumanoidDescription: strings and numbers only.
		local description = Cast.describe(person)
		for property, value in description do
			check(typeof(value) == "string" or typeof(value) == "number", `{where}: {property} is a {typeof(value)}`)
		end
		check(description.HeightScale == person.body.heightScale, `{where}: describe loses the height`)
		check(description.Shirt == (person.shirt or 0), `{where}: describe loses the shirt`)
		check(
			description.HairAccessory == (if person.hair and person.hair > 0 then tostring(person.hair) else ""),
			`{where}: describe's hair`
		)
	end
end
for id in Cast.People do
	check(castPeople[id] ~= nil, `{id} is in the cast but not a story person`)
end
check(typeof(Cast.People.NPC_June_Sitting.seat) == "table", "June's rocker seat is a table")
check(Cast.describe(Cast.People.NPC_Chad).HatAccessory == "607702162", "Chad wears the baseball cap")
check(Cast.describe(Cast.People.NPC_Gloria).HairAccessory == "376526888", "Gloria has the straight blonde hair")
check(Cast.describe(Cast.People.NPC_Gloria).HatAccessory == "", "Gloria wears no hat")
-- An id of 0 means nothing, as it does for the tshirt, so it never becomes the string "0".
local noHairOrHat = table.clone(Cast.People.NPC_Chad)
noHairOrHat.hair = 0
noHairOrHat.hat = 0
local noHairOrHatDescription = Cast.describe(noHairOrHat)
check(
	noHairOrHatDescription.HairAccessory == "" and noHairOrHatDescription.HatAccessory == "",
	"describe turns a hair or hat id of 0 into no accessory, not the string 0"
)

-- The free catalog has no grey hair, so the older people get theirs from `hairColor`.
for _, id in { "NPC_Gloria", "NPC_June_Sitting", "NPC_June_Standing", "NPC_Edna", "NPC_Judge1" } do
	local color = Cast.People[id].hairColor
	check(
		color ~= nil and color.r >= 150 and math.abs(color.r - color.g) <= 12 and math.abs(color.g - color.b) <= 12,
		`{id}'s hair is not grey`
	)
end

-- The same person is the same person in both poses and both outfits.
for _, pair in { { "NPC_June_Sitting", "NPC_June_Standing" }, { "NPC_Sam_Casual", "NPC_Sam_TurfKing" } } do
	local a, b = Cast.People[pair[1]], Cast.People[pair[2]]
	check(
		a.hair == b.hair and sameColor(a.hairColor, b.hairColor) and sameColor(a.body.skin, b.body.skin),
		`{pair[1]} and {pair[2]} have different faces`
	)
	check(
		a.body.heightScale == b.body.heightScale and a.body.widthScale == b.body.widthScale,
		`{pair[1]} and {pair[2]} are different sizes`
	)
end
-- Chad and Sam read as TurfKing: the same top (or the same crown graphic) and a cap or visor each.
local chad, turfKingSam = Cast.People.NPC_Chad, Cast.People.NPC_Sam_TurfKing
check(chad.shirt == turfKingSam.shirt and chad.tshirt == turfKingSam.tshirt, "Chad and Sam wear the same TurfKing top")
check(chad.hat ~= nil and turfKingSam.hat ~= nil, "Chad and Sam each wear a cap or visor")
check(Cast.People.NPC_Sam_Casual.shirt ~= turfKingSam.shirt, "Sam is out of the TurfKing top after quitting")

-- A rig's Root sits 0.5 above its feet, like every other model's. The feet are a Humanoid's HipHeight
-- plus half the HumanoidRootPart's height below the HumanoidRootPart's centre.
check(CastRig.feetOffset(2, 2) == 3, "the feet are 3 below a 2-tall root with 2 of hip height")
check(CastRig.rootPlacement(2, 2) == 2.5, "Root sits 2.5 below that root's centre")
for _, hip in { 0, 1.35, 2, 2.6 } do
	for _, size in { 1, 2, 2.2 } do
		local gap = CastRig.feetOffset(hip, size) - CastRig.rootPlacement(hip, size)
		check(math.abs(gap - 0.5) < 1e-9, `hip {hip} root {size}: Root is {gap} above the feet, not 0.5`)
	end
end

-- Roblox's own animations, each looping.
local expectedPoses = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Sit = "rbxassetid://2506281703",
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
	Inspect = "rbxassetid://507770453",
	Note = "rbxassetid://507766666",
}
for name, id in expectedPoses do
	local pose = Cast.Poses[name]
	check(pose ~= nil and pose.id == id and pose.looped == true, `pose {name} is {id}, looping`)
end
for name in Cast.Poses do
	check(expectedPoses[name] ~= nil, `pose {name} isn't in the brief`)
end

-- Which pose a person plays. NpcAnimator reaches Cast through `script`, which Lune doesn't have, so
-- it is loaded with `script` stood in for and Cast handed to its require. It touches nothing
-- from Roblox until it plays. Run from the repo root, like the command at the top.
local stub = {}
setmetatable(stub, {
	__index = function()
		return stub
	end,
})
local NpcAnimator = luau.load(fs.readFile("src/shared/NpcAnimator.luau"), {
	debugName = "NpcAnimator",
	environment = {
		script = stub,
		require = function()
			return Cast
		end,
	},
})()
check(typeof(NpcAnimator.play) == "function", "NpcAnimator.play is there")
check(typeof(NpcAnimator.stop) == "function", "NpcAnimator.stop is there")
check(NpcAnimator.resolve("Idle", "Walk") == "Walk", "a requested pose wins over the Pose attribute")
check(NpcAnimator.resolve(nil, "Walk") == "Walk", "a requested pose needs no attribute")
check(NpcAnimator.resolve("Sit", nil) == "Sit", "the Pose attribute is the fallback")
check(NpcAnimator.resolve(nil, nil) == nil, "no pose asked for and no attribute is no pose")
check(NpcAnimator.resolve("Dance", nil) == nil, "an attribute that is not in Cast.Poses is no pose")
check(NpcAnimator.resolve(nil, "Dance") == nil, "a requested pose that is not in Cast.Poses is no pose")
check(NpcAnimator.resolve("Idle", "Dance") == nil, "a pose that is not in Cast.Poses is not swapped for the attribute")
check(NpcAnimator.resolve(nil, "") == nil, "an empty pose name is no pose")
check(NpcAnimator.resolve(12 :: any, nil) == nil, "a Pose attribute that is not text is no pose")
for name in Cast.Poses do
	check(NpcAnimator.resolve(nil, name) == name, `{name} can be asked for`)
	check(NpcAnimator.resolve(name, nil) == name, `{name} can be a Pose attribute`)
end
-- What CastService sets as each rig's Pose attribute is what plays.
for id, person in Cast.People do
	check(NpcAnimator.resolve(person.pose, nil) == person.pose, `{id}'s pose plays as it is`)
end
-- The judges walk and stop.
check(NpcAnimator.resolve(Cast.People.NPC_Judge1.pose, "Walk") == "Walk", "a judge can be asked to walk")
check(NpcAnimator.resolve(Cast.People.NPC_Judge1.pose, "Idle") == "Idle", "a judge can be asked to stand")
-- The judges' walk plays at the pace they cross the yard: Roblox's R15 walk is made for 14.5
-- studs a second, so a slower glide plays it slower, in step with the ground.
check(NpcAnimator.WALK_STUDS_PER_SECOND == 14.5, "the R15 walk is made for 14.5 studs a second")
check(NpcAnimator.walkSpeed(14.5) == 1, "walking at the pace the animation is made for plays it at full speed")
check(
	math.abs(NpcAnimator.walkSpeed(3.2) - 3.2 / 14.5) < 1e-9,
	"a slower walk plays the animation slower, in proportion"
)
check(NpcAnimator.walkSpeed(0) == 0, "standing still plays the walk at no speed")

-- Lines ---------------------------------------------------------------------------------------

local values = { customer = "Mrs. Alvarez", who = "Edna", pay = "$66" }
check(
	Story.fill("{pay}?? I got $4 a lawn in 1971.", values) == "$66?? I got $4 a lawn in 1971.",
	"placeholders fill in"
)
check(Story.fill("That reel mower's {left} away.", values) == nil, "a line missing a value is skipped")
check(Story.plain("goes and *hires* somebody") == "goes and hires somebody", "highlights come off")
check(Story.thread("June").name == "Grandma June", "June's thread")
check(Story.thread("Mrs. Alvarez").cast == "Edna", "Edna's thread has her face")
check(Story.thread("Mr. Chen").cast == "Customer", "other customers are customers")

for act = 1, #Story.Acts do
	for turn = 1, 8 do
		local line = Story.juneLine(act, turn, { left = "$84", appeal = 40, bar = Story.ContestBar })
		check(typeof(line) == "string" and not string.find(line, "{", 1, true), `June's line, act {act} turn {turn}`)
	end
	-- With the mower already affordable there's no {left}, and she still has something to say.
	local line = Story.juneLine(act, 1, { appeal = 40, bar = Story.ContestBar })
	check(not string.find(line, "{", 1, true), `June's line with nothing left to save, act {act}`)
end
check(Story.juneLine(1, 1, { left = "$84" }) ~= Story.juneLine(1, 2, { left = "$84" }), "June takes turns")

-- Unread texts --------------------------------------------------------------------------------

local inbox = {
	{ n = 1, thread = "June" },
	{ n = 2, thread = "June" },
	{ n = 3, thread = "June", mine = true },
	{ n = 4, thread = "BridgeClub" },
	{ n = 5, thread = "June" },
}
local total, byThread = Story.unread(inbox, {})
check(total == 4 and byThread.June == 3 and byThread.BridgeClub == 1, "unread counts every thread, not yours")
total, byThread = Story.unread(inbox, { June = 3 })
check(total == 2 and byThread.June == 1, "reading a thread clears what came before")
total = Story.unread(inbox, { June = 5, BridgeClub = 4 })
check(total == 0, "all read")

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("Story checks passed")
