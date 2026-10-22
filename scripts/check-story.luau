-- Checks the story's config and logic (src/shared/Config/Story.luau) outside Roblox:
--   lune run scripts/check-story
-- It checks every scene, beat and act points at things that exist, and that the act gates and
-- beats fire when docs/STORY.md says they should. Exits with an error if anything's off.

local process = require("@lune/process")

local Story = require("../src/shared/Config/Story")

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

for id, scene in Story.Scenes do
	check(#scene.lines > 0, `scene {id} has no lines`)
	for index, line in scene.lines do
		local where = `scene {id} line {index}`
		check(typeof(line.text) == "string" and #line.text > 0, `{where} has no text`)
		checkText(line.text, where)
		check(line.speaker == nil or Story.Cast[line.speaker] ~= nil, `{where}: unknown speaker {line.speaker}`)
		check(line.shot == nil or line.shot == "June" or line.shot == "Gloria", `{where}: unknown shot {line.shot}`)
		check(not line.bubble or line.speaker ~= nil, `{where}: a bubble needs a speaker`)
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
local perfect = { kind = "JobFinished", customer = "Ms. Nguyen", quality = 0.92, preference = "Quality", crew = 1 }
check(#beatIds(perfect, facts({ act = 1, jobsCompleted = 9 })) == 0, "beating TurfKing waits for act 2")
check(
	same(beatIds(perfect, facts({ act = 2, jobsCompleted = 9 })), { "QualityWin" }),
	"a 90% finish for a Quality customer beats TurfKing"
)
local almost = { kind = "JobFinished", customer = "Ms. Nguyen", quality = 0.89, preference = "Quality", crew = 1 }
check(#beatIds(almost, facts({ act = 2, jobsCompleted = 9 })) == 0, "89% isn't enough to beat TurfKing")

check(Story.critique(facts({ jobsCompleted = 1 }), job) == nil, "the first job has its own texts, no critique")
check(Story.critique(facts({ jobsCompleted = 2 }), job) ~= nil, "June critiques the second job")
check(Story.critique(facts({ act = 2, jobsCompleted = 5 }), job) == nil, "June stops critiquing after act 1")
local poor = Story.critique(facts({ jobsCompleted = 2 }), { kind = "JobFinished", quality = 0.4 })
check(poor == Story.Critiques[3].lines[1], "a poor finish gets a poor critique")

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

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("Story checks passed")
