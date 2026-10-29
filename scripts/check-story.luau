-- Checks the story's config and logic outside Roblox:
--   lune run scripts/check-story
-- It checks every scene, beat and act points at things that exist, that the act gates and beats
-- fire when docs/STORY.md says they should (src/shared/Config/Story.luau), TurfKing's rules for
-- taking jobs and winning customers back (src/shared/Config/TurfKing.luau), and the Best Yard
-- contest's scoring, Gloria's bar and when judging day comes round
-- (src/shared/Config/Contest.luau), and the nine people's catalog outfits
-- (src/shared/Config/Cast.luau; scripts/cast-check.py asks the catalog about their ids), and where
-- CastService puts a rig's Root so it stands on the spot a statue did (src/shared/CastRig.luau). Exits
-- with an error if anything's off.

local process = require("@lune/process")

local Cast = require("../src/shared/Config/Cast")
local CastRig = require("../src/shared/CastRig")
local Contest = require("../src/shared/Config/Contest")
local Story = require("../src/shared/Config/Story")
local TurfKing = require("../src/shared/Config/TurfKing")

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

check(same(beatIds({ kind = "Joined" }, facts()), { "Intro" }), "a new player gets the intro")
check(
	same(beatIds({ kind = "Joined" }, facts({ jobsCompleted = 5 })), { "WelcomeBack" }),
	"a returning player gets the welcome back"
)
check(#beatIds({ kind = "Joined" }, facts(), { Intro = true }) == 0, "the intro plays once")
check(
	#beatIds({ kind = "Joined" }, facts({ jobsCompleted = 3, seen = { Intro = true } }), { Intro = true }) == 0,
	"someone who had the intro isn't welcomed back"
)
local job =
	{ kind = "JobFinished", customer = "Mrs. Alvarez", pay = 66, quality = 0.8, preference = "Balanced", crew = 1 }
check(same(beatIds(job, facts({ jobsCompleted = 1 })), { "FirstJob" }), "June texts after the first job")
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
			description.HairAccessory == (if person.hair then tostring(person.hair) else ""),
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
