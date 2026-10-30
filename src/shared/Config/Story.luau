-- The story, "Grandma's Rival" (docs/STORY.md): every line, beat and act gate, so the writing can
-- be changed here without touching any code. StoryService (on the server) decides when a beat
-- fires and saves it; the dialogue box and the Messages app on the shop computer only show what
-- it sends them.
--
-- Placeholders in a line are filled in as it fires:
--   {pay}       what the job paid you
--   {customer}  the customer's name; a text to thread "{customer}" goes to their own thread
--   {who}       what June calls that customer ("Edna" for Mrs. Alvarez)
--   {item}      the thing the act's goal says to buy
--   {left}      the money you still need for it
--   {appeal}    your business's curb appeal
--   {bar}       the contest bar (ContestBar)
--   {rival}     Gloria's score this summer (Config/Contest.luau), while the contest is open
--   {jobs}      how many jobs until judging day comes round again
-- A line with a placeholder that has no value right then is skipped.
-- `*word*` in a line is shown in the highlight color.
--
-- This file has no Roblox requires, so scripts/check-story.luau can test it with Lune.

local Story = {}

-- Curb appeal (0-100) the yard needs for judging day: it ends act 3. A fully tidy lawn is 60 of
-- it (GameConfig.CurbAppeal), so 75 takes a few decorations too.
Story.ContestBar = 75
-- At most this many texts are kept in a player's inbox (the oldest go first), and this many
-- scenes wait to be played.
Story.InboxCap = 60
Story.SceneQueueCap = 4

-- Every new player's first job is Edna's front lawn: the board's starter job is always hers.
Story.FirstCustomer = "Mrs. Alvarez"
-- What June calls the bridge club ladies who are customers (Jobs.Customers).
Story.JuneCalls = { ["Mrs. Alvarez"] = "Edna" }

-- Who's who. The key is their picture's in the client's StoryArt (and their color in
-- UI.Colors.Cast); `initials` stand in for a picture that isn't uploaded yet. `moods` are the
-- expressions they have portraits for (a line's `mood`), the first the one they usually wear;
-- someone with none has one portrait (or none, for customers without a face).
Story.Cast = {
	June = {
		name = "Grandma June",
		initials = "GJ",
		moods = { "Neutral", "Smug", "Annoyed", "Proud", "Laughing" },
	},
	Gloria = {
		name = "Gloria Pemberton",
		caption = "Gloria Pemberton · next door",
		initials = "GP",
		moods = { "Smug", "FakeSmile", "Furious", "Defeated" },
	},
	Chad = { name = "Chad", caption = "Chad · TurfKing", initials = "CH", moods = { "Cocky", "Panicked" } },
	Sam = { name = "Sam Pemberton", initials = "SP", moods = { "Happy", "FedUp" } },
	Edna = { name = "Edna Alvarez", initials = "EA", moods = { "Happy" } },
	BridgeClub = { name = "Bridge Club", initials = "BC" },
	Rossi = { name = "Mrs. Rossi", initials = "MR", moods = { "Gossip" } },
	Nguyen = { name = "Ms. Nguyen", initials = "MN", moods = { "Picky" } },
	Customer = { name = "Customer", initials = "" },
	-- The Best Yard judges.
	Judge1 = { name = "Judge Pruitt", caption = "Judge Pruitt · Best Yard", initials = "JP" },
	Judge2 = { name = "Judge Marigold", caption = "Judge Marigold · Best Yard", initials = "JM" },
}

-- The Messages app's threads. A customer's thread is named after them (see Story.thread).
Story.Threads = {
	June = { name = "Grandma June", status = "on the porch, watching", cast = "June" },
	BridgeClub = { name = "Bridge Club", status = "Edna, Mrs. Rossi and Ms. Nguyen", cast = "BridgeClub" },
	Chad = { name = "Chad · TurfKing", status = "TurfKing Lawn Co.", cast = "Chad" },
	Sam = { name = "Sam", status = "Gloria's grandkid", cast = "Sam" },
}
-- Customers with a face of their own.
Story.CustomerCast = { ["Mrs. Alvarez"] = "Edna", ["Mrs. Rossi"] = "Rossi", ["Ms. Nguyen"] = "Nguyen" }

-- Dialogue scenes, played in the box at the bottom of the screen (DialogueController).
--   caption   shown in the top letterbox bar
--   skipText  the Skip button's text on a computer (phones always say "Skip")
--   act       an act's opening scene: its title card ("Act 2: TurfKing") shows as it starts
--   lines     in order. `speaker` is a Cast key (none: the narrator), and `mood` which of their
--             Cast `moods` their portrait wears for it (none: their usual one). `shot` points the camera at
--             "June" (on her porch at your shop), "Gloria" (her house) or "Yard" (your own front
--             lawn); it stays put until a line changes it. `bubble` also shows the line in a
--             speech bubble over the speaker. `card` pops up a card (a new tool). `judges` walks
--             the two Best Yard judges across "Yard" (yours) or "Gloria" (hers).
Story.Scenes = {
	Intro = {
		act = 1,
		caption = "Maple Grove · First day of summer",
		skipText = "Skip intro",
		lines = {
			{
				shot = "Gloria",
				text = "Sunrise over Maple Grove. A purple TurfKing truck pulls into the drive next door.",
			},
			{
				speaker = "Gloria",
				mood = "Smug",
				shot = "Gloria",
				bubble = true,
				text = "Morning, June! Lovely… dandelions.",
			},
			{
				speaker = "June",
				mood = "Annoyed",
				shot = "June",
				text = "Thirty years. Thirty years I've won Best Yard on this street… and Gloria Pemberton goes and *hires* somebody.",
			},
			{
				speaker = "June",
				mood = "Proud",
				text = "My mower died in '09. These never did. They won me the trophy in '94, so don't you lose 'em.",
				card = { label = "Already yours", name = "Grandma's Grass Shears", icon = "Shears" },
			},
			{
				speaker = "June",
				text = "Contest's end of summer. Make our yard the best on the street, and make some money doing it.",
			},
			{
				speaker = "June",
				text = "Edna's front lawn is next. Computer's in the shed. Go.",
			},
		},
	},
	-- For players who were already playing before the story: the set-up, without the shears.
	WelcomeBack = {
		caption = "Maple Grove",
		lines = {
			{
				speaker = "Gloria",
				mood = "Smug",
				shot = "Gloria",
				bubble = true,
				text = "Morning, June! Lovely… dandelions.",
			},
			{
				speaker = "June",
				mood = "Annoyed",
				shot = "June",
				text = "Thirty years. Thirty years I've won Best Yard on this street… and Gloria Pemberton goes and *hires* somebody.",
			},
			{
				speaker = "June",
				text = "Contest's end of summer. Make our yard the best on the street, and make some money doing it.",
			},
		},
	},
	Act2 = {
		act = 2,
		caption = "Act 2 · TurfKing",
		lines = {
			{
				speaker = "Gloria",
				mood = "FakeSmile",
				shot = "Gloria",
				bubble = true,
				text = "Isn't it sweet, June's little helper.",
			},
		},
	},
	-- Act 2 when it starts with a new mower.
	Act2Mower = {
		act = 2,
		caption = "Act 2 · TurfKing",
		lines = {
			{
				speaker = "June",
				mood = "Laughing",
				shot = "June",
				text = "Now THAT's a mower. Your grandfather had one just like it. He was terrible with it.",
			},
			{
				speaker = "Gloria",
				mood = "FakeSmile",
				shot = "Gloria",
				bubble = true,
				text = "Isn't it sweet, June's little helper.",
			},
		},
	},
	Act3 = {
		act = 3,
		caption = "Act 3 · The Crew",
		lines = {
			{
				speaker = "June",
				mood = "Annoyed",
				shot = "June",
				text = "Contest's coming. Our yard looks like a vacant lot. Fix it.",
			},
		},
	},
	-- Act 3 when it starts with your first motorized mower.
	Act3Mower = {
		act = 3,
		caption = "Act 3 · The Crew",
		lines = {
			{
				speaker = "June",
				mood = "Proud",
				shot = "June",
				text = "Well. Look at you. Gloria's boys have three of those, so don't get cocky.",
			},
			{
				speaker = "June",
				mood = "Annoyed",
				text = "Contest's coming. Our yard looks like a vacant lot. Fix it.",
			},
		},
	},
	Act4 = {
		act = 4,
		caption = "Act 4 · The Contest",
		lines = {
			{
				speaker = "June",
				mood = "Proud",
				shot = "June",
				text = "Hmph. It doesn't look like a vacant lot any more.",
			},
			{ speaker = "June", text = "Judges walk the street at the end of summer. Keep it sharp till then." },
		},
	},
	-- Judging day (ContestService): the judges walk your yard, then Gloria's, and the first time
	-- the 1994 secret comes out. The results screen follows.
	ContestJudging = {
		caption = "Judging day",
		skipText = "Skip to the results",
		lines = {
			{
				shot = "Yard",
				judges = "Yard",
				text = "Judging day. Two judges with clipboards walk the length of your yard.",
			},
			{ speaker = "Judge1", text = "Hmm. *Edges.*" },
			{ speaker = "Judge2", text = "Noted. Very noted." },
			{
				shot = "Gloria",
				judges = "Gloria",
				text = "Then they cross the street to Gloria's. TurfKing's stripes are very, very straight.",
			},
			{
				speaker = "Gloria",
				mood = "Smug",
				shot = "Gloria",
				bubble = true,
				text = "Half that trophy's always been mine, June. You know it.",
			},
			{ shot = "June", text = "June goes quiet for the first time all summer." },
			{
				text = "The very first Best Yard, in 1994, June and Gloria won together. Only June's name went on the trophy.",
			},
		},
	},
	-- Every judging day after the first.
	ContestJudgingAgain = {
		caption = "Judging day",
		skipText = "Skip to the results",
		lines = {
			{ shot = "Yard", judges = "Yard", text = "Judging day again. The judges start with your yard." },
			{ speaker = "Judge1", text = "Hmm. *Edges.*" },
			{ shot = "Gloria", judges = "Gloria", text = "Then Gloria's, which has somehow grown more flamingos." },
			{
				speaker = "Gloria",
				mood = "Smug",
				shot = "Gloria",
				bubble = true,
				text = "This year, June. *This* year.",
			},
		},
	},
	ContestWin = {
		caption = "Best Yard",
		lines = {
			{ shot = "June", text = "June scratches Gloria's name onto the new trophy, next to hers." },
			{ speaker = "June", mood = "Proud", text = "There. Should've done that in '94." },
			{
				speaker = "Gloria",
				mood = "Defeated",
				shot = "Gloria",
				bubble = true,
				text = "Fine. FINE. Same time next year, June.",
			},
		},
	},
	ContestWinAgain = {
		caption = "Best Yard",
		lines = {
			{
				speaker = "June",
				mood = "Laughing",
				shot = "June",
				text = "Another one for the mantel. Don't let it go to your head.",
			},
			{
				speaker = "Gloria",
				mood = "Defeated",
				shot = "Gloria",
				bubble = true,
				text = "Fine. FINE. Same time next year, June.",
			},
		},
	},
	-- Gloria wins, insufferably.
	ContestLose = {
		caption = "Best Yard",
		lines = {
			{
				speaker = "Gloria",
				mood = "Smug",
				shot = "Gloria",
				bubble = true,
				text = "Oh, June. Thirty years, and all it took was a *franchise*.",
			},
			{
				speaker = "Gloria",
				mood = "FakeSmile",
				bubble = true,
				text = "I'll keep it polished for you. You can visit.",
			},
			{
				speaker = "June",
				mood = "Annoyed",
				shot = "June",
				text = "Next summer. And you're mowing every Tuesday.",
			},
		},
	},
}

-- The acts, in order. Each one after the first starts as soon as ANY of its `startsWhen` is true
-- (and only once the act before it has started):
--   owns        you own one of these tools
--   motorMower  you own a mower with a motor (Tools `motorized`)
--   crewJob     a job you just finished had more than one of you on it
--   level       you're at least this level
--   curbAppeal  your business's curb appeal is at least this
-- When an act starts, its scene plays (`mowerScene` instead when buying a mower started it) and
-- its texts arrive. `goal` is the goal card in the Messages app: `buy` a tool, or reach a
-- `curbAppeal`.
--
-- The levels are tuned to the real progression (GameConfig.levelFromXp and the xp in Jobs.luau):
-- level 3 is about 10 early jobs, level 4 about 18, level 10 a good run of pro jobs. They only
-- catch players who skip the purchase that normally moves the story on.
Story.Acts = {
	{
		name = "The Shears",
		goal = { text = "Buy the {item}", buy = "ReelMower" },
	},
	{
		name = "TurfKing",
		startsWhen = { owns = { "ReelMower" }, motorMower = true, level = 3 },
		scene = "Act2",
		mowerScene = "Act2Mower",
		texts = {
			{ thread = "Chad", text = "Cute scissors, bud. Heard you're doing lawns. Stay in your lane." },
		},
		goal = { text = "Buy the {item}", buy = "GasPushMower" },
	},
	{
		name = "The Crew",
		startsWhen = { motorMower = true, crewJob = true, level = 4 },
		scene = "Act3",
		mowerScene = "Act3Mower",
		texts = {
			{
				thread = "Sam",
				text = "hey it's Sam. Gloria's grandkid. I quit TurfKing today. Chad tried to mow a rock garden. if you ever need help lmk.",
			},
			{ thread = "June", text = "Contest's coming. Our yard looks like a vacant lot. Fix it." },
		},
		goal = { text = "Raise curb appeal to {bar}", curbAppeal = Story.ContestBar },
	},
	{
		name = "The Contest",
		startsWhen = { curbAppeal = Story.ContestBar, level = 10 },
		scene = "Act4",
		texts = {
			{ thread = "June", text = "Judges walk the street at the end of summer. Keep it sharp till then." },
		},
		goal = { text = "Keep the yard sharp for judging day", curbAppeal = 100 },
	},
}

-- Beats: things that happen once (each is remembered in the save's `seen` by its id).
--   on        what it waits for: "Joined" (you came into the game), "JobFinished", "Bought",
--             "LevelUp" or "CurbAppeal"
--   fromAct   only from this act on (and `toAct`, up to this one)
--   when      (facts, event) -> whether it fires now. `facts` is { act, level, jobsCompleted,
--             curbAppeal, money, owned = { [toolId] = true }, motorMower, seen }; a finished job's
--             event has { customer, pay, quality (0-1), preference, crew (how many of you),
--             wonBack (the customer was won back from TurfKing) }
--   scene     a scene to play; `texts` texts to send ({ thread, text, from = who in a group
--             thread, mine = you sent it })
--   perCustomer  fires once for each customer instead of once in all (it's remembered as
--             "<id>:<customer>", see Story.beatKey)
Story.Beats = {
	-- June's welcome. A new player starts on their first lawn with her shears already in hand
	-- (JobService:StartFirstJob), so it plays when the truck brings them home from that first
	-- payday, ahead of her texts about it (FirstJob): it's listed first so it comes first.
	{
		id = "Intro",
		on = "JobFinished",
		when = function(facts)
			return facts.jobsCompleted == 1 and not facts.seen.Intro
		end,
		scene = "Intro",
	},
	-- Players who were already playing before the story came: they never had the intro.
	{
		id = "WelcomeBack",
		on = "Joined",
		when = function(facts)
			return facts.jobsCompleted > 0 and not facts.seen.Intro
		end,
		scene = "WelcomeBack",
	},
	{
		id = "FirstJob",
		on = "JobFinished",
		when = function(facts)
			return facts.jobsCompleted == 1
		end,
		texts = {
			{ thread = "{customer}", text = "Thank you, dear! Same time next week?" },
			{ thread = "June", text = "Saw you finish {who}'s lawn from my porch. You missed a spot by the birdbath." },
			{ thread = "June", text = "{pay}?? I got $4 a lawn in 1971. Put it toward a mower. A REAL one." },
			{ thread = "June", mine = true, text = "Saving for the reel mower." },
			{
				thread = "June",
				text = "Good. Gloria's TurfKing boys scalped her front lawn this morning. I took pictures.",
			},
		},
	},
	{
		id = "SecondJob",
		on = "JobFinished",
		when = function(facts)
			return facts.jobsCompleted == 2
		end,
		texts = {
			{ thread = "BridgeClub", from = "Mrs. Rossi", text = "Is the grandchild free Thursday?" },
		},
	},
	-- Beating TurfKing on quality: a customer who wanted it perfect got a 90%+ finish (see
	-- Config/TurfKing.luau), so they're yours for good. JobService says so (`wonBack`) when it
	-- pays their bonus, the first time for each customer.
	{
		id = "QualityWin",
		on = "JobFinished",
		fromAct = 2,
		perCustomer = true,
		when = function(_facts, event)
			return event.wonBack == true
		end,
		texts = {
			{ thread = "{customer}", text = "TurfKing scalped my lawn last month. You're hired for good." },
		},
	},
}

-- In act 1 June critiques every job by text (after the first, which has its own beat). The first
-- band whose `atLeast` the job's finish (0-1) reaches is used, its lines taking turns.
Story.Critiques = {
	{
		atLeast = 0.85,
		lines = { "Clean edges. Don't let it go to your head.", "Hmph. Gloria's TurfKing boys couldn't do better." },
	},
	{
		atLeast = 0.7,
		lines = { "Not bad. Not good. Faster next time.", "Mostly tidy. I could see one patch from the porch." },
	},
	{
		atLeast = 0,
		lines = { "You missed a spot. I could see it from the porch.", "Was that a lawn or a haircut by a goat?" },
	},
}

-- What June says when you talk to her on her porch: a line about how you're doing in this act,
-- then one about Gloria, taking turns.
Story.JuneTalk = {
	Progress = {
		{
			"That reel mower's {left} away. Chop chop.",
			"These shears won me the trophy in '94. Don't you lose 'em.",
			"Edna says you're polite. Don't let it slow you down.",
		},
		{
			"A gas mower's {left} away. Gloria's boys have three.",
			"TurfKing's taking lawns all over Maple Grove. Take them back.",
			"That Chad came by in his little polo. I didn't open the door.",
		},
		{
			"Curb appeal {appeal}. The judges want {bar}. Get to work.",
			"Judges look at edges. Fix the edges.",
			"Shrubs. Flowers. A birdbath wouldn't kill you.",
		},
		{
			"Curb appeal {appeal}. Keep it there till judging day.",
			"Judging day's coming. Gloria's pacing her porch.",
		},
	},
	-- In act 4, the contest's turn about your progress, by where the contest is (Contest.state).
	Contest = {
		Open = {
			"Gloria's yard'd score about {rival}. Ours has to beat it. Text me when you're ready and I'll call the judges.",
			"Judges are in town. Mow, edge, trim. Then text me.",
		},
		Waiting = {
			"The judges come back in {jobs} jobs. Mow every Tuesday.",
			"Next time: edges. Then shrubs. Then we'll see.",
		},
		Results = {
			"Well? Go and look at the scores.",
		},
	},
	Gloria = {
		"Gloria's been watching you all morning. Pretending to water her hydrangeas.",
		"Gloria says her TurfKing boys use a laser level. On grass.",
		"Don't wave at Gloria. It only encourages her.",
		"Thirty years she's lost. Thirty. And she still brings a casserole to the judging.",
	},
}

-- Gloria's yard across the street (GloriaService builds it, GloriaController shows it). Each
-- player sees it as it is in their own act: `Stages[act]` is which of her three yards shows
-- (1 before TurfKing, 2 TurfKing's sharp stripes and sign, 3 over the top for contest week), and
-- from act `TurfKingFrom` TurfKing's purple truck is parked in her drive with Chad beside it.
Story.GloriaYard = {
	Stages = { 1, 2, 2, 3 },
	TurfKingFrom = 2,
}

-- What Gloria says from her porch now and then, when you're in sight of it (a speech bubble),
-- by act, taking turns. From act 2 Chad, by his truck, gets a word in every other time.
Story.GloriaRemarks = {
	{
		"Morning, June! Lovely… dandelions.",
		"Are those *scissors*? How quaint.",
		"June, dear, your grass is waving at me.",
	},
	{
		"Isn't it sweet, June's little helper.",
		"TurfKing does my edges with a laser, you know.",
		"Chad says your mower is *vintage*. That's one word for it.",
	},
	{
		"Oh, a crew! How ambitious.",
		"My hedges are squared, June. *Squared*.",
		"I saw you bought a shrub. Just the one?",
	},
	{
		"Flamingos, June. In *formation*.",
		"The judges adore a fountain. Or so I've heard.",
		"Thirty years. This is my year, June. I can feel it.",
	},
}
Story.ChadRemarks = {
	"Cute scissors, bud.",
	"Stay in your lane, bud.",
	"TurfKing, bud. Look it up.",
	"That's a lot of grass for one kid, bud.",
}

-- Chad's texts when TurfKing takes a job off your board (Config/TurfKing.luau), taking turns.
-- {customer} is whose job it was.
Story.TurfKingTexts = {
	"Took the {customer} job. Snooze you lose, bud.",
	"{customer} went with the professionals. No hard feelings, bud.",
	"Another one for TurfKing. Maybe try a mower, bud.",
	"We'll handle {customer}. You handle your little scissors.",
}

-- The contest (ContestService, Config/Contest.luau): June's texts when judging day's open, the
-- first summer (`Open`), after a loss (`Retry`) and every summer after a win (`Again`), once each,
-- and the texts when you call the judges from the Messages app (`Start`).
Story.ContestTexts = {
	Open = {
		{
			thread = "June",
			text = "Judges are in town. Gloria's yard'd score about {rival}. Text me when you're ready and I'll call them.",
		},
	},
	Retry = {
		{ thread = "June", text = "Judges are back for another look. Text me when you're ready. And fix those edges." },
	},
	Again = {
		{
			thread = "June",
			text = "Judges are back. Gloria's bought more flamingos. A LOT more flamingos. Text me when you're ready.",
		},
	},
	Start = {
		{ thread = "June", mine = true, text = "Call the judges. We're ready." },
		{ thread = "June", text = "Calling them now. Go stand by the yard and don't touch anything." },
	},
}
-- Who has the last word on the results screen, and what they say.
Story.ContestClosing = {
	Win = { speaker = "Gloria", mood = "Defeated", text = "Fine. FINE. Same time next year, June." },
	Lose = { speaker = "Gloria", mood = "Smug", text = "Better luck next summer, June. Truly." },
}

-- Helpers -------------------------------------------------------------------------------------

-- Fills in a line's placeholders, or nil if one of them has no value.
function Story.fill(text: string, values: { [string]: any }?): string?
	local missing = false
	local filled = string.gsub(text, "{(%w+)}", function(name)
		local value = values and values[name]
		if value == nil then
			missing = true
			return ""
		end
		return tostring(value)
	end)
	return if missing then nil else filled
end

-- A line without its `*highlight*` marks.
function Story.plain(text: string): string
	return (string.gsub(text, "%*", ""))
end

-- A thread's name, status and who's in it (Cast key). Anything that isn't one of Story.Threads
-- is a customer's thread, named after them.
function Story.thread(id: string)
	local known = Story.Threads[id]
	if known then
		return known
	end
	return { name = id, status = "Customer", cast = Story.CustomerCast[id] or "Customer" }
end

-- How many texts haven't been read, in all and by thread. `texts` and `read` are the inbox as
-- StoryService sends it: { n, thread, mine } each, and the last text read in each thread.
function Story.unread(texts: { any }, read: { [string]: number }): (number, { [string]: number })
	local total, byThread = 0, {}
	for _, text in texts do
		if not text.mine and text.n > (read[text.thread] or 0) then
			total += 1
			byThread[text.thread] = (byThread[text.thread] or 0) + 1
		end
	end
	return total, byThread
end

-- Whether any of an act's `startsWhen` is true.
function Story.gateMet(gate, facts, event): boolean
	if not gate then
		return false
	end
	for _, id in gate.owns or {} do
		if facts.owned and facts.owned[id] then
			return true
		end
	end
	if gate.motorMower and facts.motorMower then
		return true
	end
	if gate.crewJob and event and event.kind == "JobFinished" and (event.crew or 1) > 1 then
		return true
	end
	if gate.level and (facts.level or 1) >= gate.level then
		return true
	end
	if gate.curbAppeal and (facts.curbAppeal or 0) >= gate.curbAppeal then
		return true
	end
	return false
end

-- The acts that start now, in order, for someone in act `act` (one after another, so a big jump
-- can start several).
function Story.actsToStart(act: number, facts, event): { number }
	local started = {}
	local current = act
	while Story.Acts[current + 1] and Story.gateMet(Story.Acts[current + 1].startsWhen, facts, event) do
		current += 1
		table.insert(started, current)
	end
	return started
end

-- The scene an act opens with: its mower scene when buying a mower started it.
function Story.openingScene(act: number, event): string?
	local info = Story.Acts[act]
	if not info then
		return nil
	end
	local boughtMower = event and event.kind == "Bought" and event.category == "Mower"
	return if boughtMower and info.mowerScene then info.mowerScene else info.scene
end

-- What a beat is remembered as in the save's `seen` once it's fired for `event`: its id, or
-- "<id>:<customer>" for a beat that fires once per customer.
function Story.beatKey(beat, event): string
	if beat.perCustomer then
		return `{beat.id}:{event and event.customer or ""}`
	end
	return beat.id
end

-- The beat with this id.
function Story.beat(id: string)
	for _, beat in Story.Beats do
		if beat.id == id then
			return beat
		end
	end
	return nil
end

-- The beats that fire for `event`: not seen yet, in their acts, and their `when` is true.
function Story.beatsFor(event, facts, seen: { [string]: boolean }, act: number)
	local beats = {}
	for _, beat in Story.Beats do
		if
			beat.on == event.kind
			and not seen[Story.beatKey(beat, event)]
			and act >= (beat.fromAct or 1)
			and act <= (beat.toAct or #Story.Acts)
			and (beat.when == nil or beat.when(facts, event))
		then
			table.insert(beats, beat)
		end
	end
	return beats
end

-- June's text about a finished job in act 1 (after the first job), or nil.
function Story.critique(facts, event): string?
	if facts.act ~= 1 or event.kind ~= "JobFinished" or (facts.jobsCompleted or 0) < 2 then
		return nil
	end
	local quality = event.quality or 0
	for _, band in Story.Critiques do
		if quality >= band.atLeast then
			return band.lines[(facts.jobsCompleted - 2) % #band.lines + 1]
		end
	end
	return nil
end

-- Which of Gloria's yards shows for someone in act `act`, and whether TurfKing's truck (and Chad)
-- is in her drive.
function Story.gloriaStage(act: number): (number, boolean)
	local stages = Story.GloriaYard.Stages
	local stage = stages[math.clamp(act, 1, #stages)]
	return stage, act >= Story.GloriaYard.TurfKingFrom
end

-- What's said from Gloria's porch the `turn`th time (1, 2, 3...) in act `act`: who says it (a
-- Cast key) and the line. Gloria takes turns with Chad once TurfKing's in her drive.
function Story.porchRemark(act: number, turn: number): (string, string)
	local _, turfKing = Story.gloriaStage(act)
	if turfKing and turn % 2 == 0 then
		local lines = Story.ChadRemarks
		return "Chad", lines[(turn // 2 - 1) % #lines + 1]
	end
	local lines = Story.GloriaRemarks[math.clamp(act, 1, #Story.GloriaRemarks)]
	local index = if turfKing then (turn - 1) // 2 else turn - 1
	return "Gloria", lines[index % #lines + 1]
end

-- Chad's text the `count`th time TurfKing takes one of your jobs (1, 2, 3...), for that job's
-- customer. Lines that don't fill are skipped.
function Story.turfKingText(count: number, customer: string?): string
	local usable = {}
	for _, line in Story.TurfKingTexts do
		local filled = Story.fill(line, { customer = customer })
		if filled then
			table.insert(usable, filled)
		end
	end
	if #usable == 0 then
		return "Another one for TurfKing, bud."
	end
	return usable[(count - 1) % #usable + 1]
end

-- What June says the `turn`th time you talk to her (1, 2, 3...), in act `act`. In the last act,
-- `values.contest` (Contest.state) picks her lines about the contest.
function Story.juneLine(act: number, turn: number, values: { [string]: any }?): string
	local progress = Story.JuneTalk.Progress[math.clamp(act, 1, #Story.JuneTalk.Progress)]
	local contest = values and values.contest and Story.JuneTalk.Contest[values.contest]
	if contest and act >= #Story.Acts then
		progress = contest
	end
	local pool = if turn % 2 == 1 then progress else Story.JuneTalk.Gloria
	local usable = {}
	for _, line in pool do
		local filled = Story.fill(line, values)
		if filled then
			table.insert(usable, filled)
		end
	end
	if #usable == 0 then
		return Story.JuneTalk.Gloria[1]
	end
	return usable[(turn - 1) // 2 % #usable + 1]
end

return Story
