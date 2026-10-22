-- The story, "Grandma's Rival" (docs/STORY.md). Each player's place in it is saved in their data's
-- `story`:
--   act       the act they're in (Story.Acts in Config/Story.luau)
--   seen      the beats they've had ([beat id] = true): every beat fires once
--   scenes    dialogue scenes still to play. The client plays them when the moment's right and
--             says when each has been watched or skipped; it can only take scenes off this list.
--   texts     their inbox, oldest first, at most Story.InboxCap of them
--   read      the last text they've read in each thread ([thread] = text number)
-- It keeps no counts of its own. It listens for what already happens (a job finished, something
-- bought, a level up, the business's curb appeal changing) and checks the beats and act gates in
-- Story.luau against the save. Players who were already playing when the story arrived are
-- caught up to their act on joining, quietly: the act's texts arrive, but no scenes play for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local JobService = require(script.Parent.JobService)
local ShopService = require(script.Parent.ShopService)

-- How long joining waits for the business's curb appeal (its lawn is built just after the plot),
-- so a returning player is caught up to the right act.
local CURB_APPEAL_WAIT = 10
-- How long the client's first request for the story waits for the player to join it.
local JOIN_WAIT = 30

local StoryService = {}

-- [Player] = true once they've joined the story this session
local joined = {}

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

-- Their saved story, made sound if the save holds something odd.
local function storyOf(data)
	local story = data.story
	if typeof(story) ~= "table" then
		story = {}
		data.story = story
	end
	story.act = if typeof(story.act) == "number" then math.clamp(math.floor(story.act), 1, #Story.Acts) else 1
	for _, key in { "seen", "scenes", "texts", "read" } do
		if typeof(story[key]) ~= "table" then
			story[key] = {}
		end
	end
	if typeof(story.nextText) ~= "number" then
		story.nextText = 1
	end
	return story
end

-- What the beats and act gates are checked against, all read from what the game already keeps.
local function factsFor(player: Player, data, story)
	local owned = {}
	local motorMower = false
	for _, tool in Items.ownedTools(data.owned) do
		owned[tool.id] = true
		if tool.category == "Mower" and tool.motorized then
			motorMower = true
		end
	end
	return {
		act = story.act,
		level = GameConfig.levelFromXp(data.xp),
		jobsCompleted = data.jobsCompleted or 0,
		curbAppeal = HomeLawnService:CurbAppeal(player),
		money = data.money,
		owned = owned,
		motorMower = motorMower,
	}
end

-- The goal card for an act: what to do, and how far along they are (Money: their money toward a
-- price; CurbAppeal: their curb appeal toward a number). The client fills in the progress.
local function goalFor(act: number)
	local goal = Story.Acts[act] and Story.Acts[act].goal
	if not goal then
		return nil
	end
	if goal.buy then
		local tool = Tools.get(goal.buy)
		local text = Story.fill(goal.text, { item = if tool then tool.name else goal.buy }) or goal.text
		return { text = text, kind = "Money", need = if tool then tool.price else 0 }
	end
	local text = Story.fill(goal.text, { bar = Story.ContestBar }) or goal.text
	return { text = text, kind = "CurbAppeal", need = goal.curbAppeal or Story.ContestBar }
end

-- What the client is sent: everything it shows, nothing it decides.
local function view(story)
	return {
		act = story.act,
		actName = Story.Acts[story.act].name,
		goal = goalFor(story.act),
		scenes = story.scenes,
		texts = story.texts,
		read = story.read,
	}
end

local function update(player: Player)
	local data = DataService:Get(player)
	if data and joined[player] then
		Net.event("StoryUpdated"):FireClient(player, view(storyOf(data)))
	end
end

-- Puts a text in the inbox, dropping the oldest past the cap (and forgetting which of a thread's
-- texts were read once none of its texts are left).
local function addText(story, thread: string, text: string, from: string?, mine: boolean?)
	table.insert(story.texts, {
		n = story.nextText,
		thread = thread,
		text = text,
		from = from,
		mine = if mine then true else nil,
		at = os.time(),
	})
	story.nextText += 1
	while #story.texts > Story.InboxCap do
		table.remove(story.texts, 1)
	end
	local threads = {}
	for _, entry in story.texts do
		threads[entry.thread] = true
	end
	for id in story.read do
		if not threads[id] then
			story.read[id] = nil
		end
	end
end

-- Sends a beat's texts, with their placeholders filled in. Catching up, they arrive quietly.
local function sendTexts(player: Player, story, texts, values, quiet: boolean?)
	for _, entry in texts do
		local thread = Story.fill(entry.thread, values)
		local text = Story.fill(entry.text, values)
		if thread and text then
			addText(story, thread, text, entry.from, entry.mine)
			if not quiet and not entry.mine then
				notify(player, `{Story.thread(thread).name}: {Story.plain(text)}`)
			end
		end
	end
end

local function queueScene(story, id: string?)
	if id and Story.Scenes[id] and not table.find(story.scenes, id) and #story.scenes < Story.SceneQueueCap then
		table.insert(story.scenes, id)
	end
end

-- The placeholder values an event brings (see Story.luau).
local function valuesFor(event)
	local values = {}
	if event.customer then
		values.customer = event.customer
		values.who = Story.JuneCalls[event.customer] or event.customer
	end
	if event.pay then
		values.pay = Format.money(event.pay)
	end
	return values
end

-- Something happened: fires the beats it sets off, June's job critique in act 1, and the acts
-- whose gates it opens. `quiet` is for catching up on joining: acts start without their scenes and
-- texts arrive without a toast.
local function handle(player: Player, event, quiet: boolean?)
	local data = DataService:Get(player)
	if not (data and joined[player]) then
		return
	end
	local story = storyOf(data)
	local facts = factsFor(player, data, story)
	local values = valuesFor(event)
	local changed = false

	for _, beat in Story.beatsFor(event, facts, story.seen, story.act) do
		story.seen[beat.id] = true
		queueScene(story, beat.scene)
		sendTexts(player, story, beat.texts or {}, values, quiet)
		changed = true
	end
	local critique = Story.critique(facts, event)
	if critique then
		sendTexts(player, story, { { thread = "June", text = critique } }, values, quiet)
		changed = true
	end

	local started = Story.actsToStart(story.act, facts, event)
	for index, act in started do
		story.act = act
		local info = Story.Acts[act]
		-- A jump over several acts only plays the last one's scene.
		if index == #started and not quiet then
			queueScene(story, Story.openingScene(act, event))
			notify(player, `Act {act}: {info.name}`)
		end
		sendTexts(player, story, info.texts or {}, values, quiet)
		changed = true
	end
	if changed then
		update(player)
	end
end

local function join(player: Player)
	local data = DataService:WaitForData(player)
	if not data or player.Parent ~= Players then
		return
	end
	local deadline = os.clock() + CURB_APPEAL_WAIT
	while player:GetAttribute("CurbAppeal") == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.2)
	end
	if player.Parent ~= Players then
		return
	end
	joined[player] = true
	handle(player, { kind = "Joined" }, true)
	update(player)
end

-- Public API ---------------------------------------------------------------------------------

-- The act this player is in (1 until they've joined the story).
function StoryService:GetAct(player: Player): number
	local data = DataService:Get(player)
	return if data then storyOf(data).act else 1
end

-- Queues a scene from Story.Scenes for this player (the contest's judging, say).
function StoryService:PlayScene(player: Player, sceneId: string)
	local data = DataService:Get(player)
	if data then
		queueScene(storyOf(data), sceneId)
		update(player)
	end
end

-- Lifecycle ----------------------------------------------------------------------------------

function StoryService:Init()
	Net.func("GetStory").OnServerInvoke = function(player)
		local deadline = os.clock() + JOIN_WAIT
		while not joined[player] and player.Parent == Players and os.clock() < deadline do
			task.wait(0.1)
		end
		local data = DataService:Get(player)
		return if data and joined[player] then view(storyOf(data)) else nil
	end
	-- The client watched (or skipped) a scene it was sent.
	Net.event("SceneWatched").OnServerEvent:Connect(function(player, sceneId)
		local data = DataService:Get(player)
		if typeof(sceneId) ~= "string" or not data then
			return
		end
		local story = storyOf(data)
		local index = table.find(story.scenes, sceneId)
		if index then
			table.remove(story.scenes, index)
			update(player)
		end
	end)
end

function StoryService:Start()
	JobService.JobFinished:Connect(function(player, info)
		handle(player, {
			kind = "JobFinished",
			customer = info.customer,
			pay = info.pay,
			quality = info.quality,
			preference = info.preference,
			crew = info.crew,
		})
	end)
	ShopService.Bought:Connect(function(player, category, itemId)
		handle(player, { kind = "Bought", category = category, itemId = itemId })
	end)
	DataService.LeveledUp:Connect(function(player, level)
		handle(player, { kind = "LevelUp", level = level })
	end)

	local function onPlayerAdded(player: Player)
		player:GetAttributeChangedSignal("CurbAppeal"):Connect(function()
			handle(player, { kind = "CurbAppeal" })
		end)
		join(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
	end)
end

return StoryService
