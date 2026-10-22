-- The story's dialogue (docs/STORY.md, "How the story is told in game"):
--   * Scenes: letterbox bars, and a box along the bottom with the speaker's round portrait, a
--     name tag, the line, a dot for each line and "Click to continue" ("Tap" on a phone), with
--     Skip up top. The camera cuts to Grandma June on her porch or to Gloria's house as the
--     lines say. The HUD hides and you can't walk while it's up. A click or tap anywhere, Space
--     or Enter goes on (finishing the line first if it's still typing out).
--   * Speech bubbles over people in the world (BillboardGuis): Gloria's remarks in a scene, and
--     what June says when you talk to her on her porch.
-- The server queues the scenes (StoryService). They play here once the moment's right (after
-- the title card, not on a job, at the computer or in a menu), and the server's told when each
-- has been watched or skipped. The first one a new player gets is the intro, and the first-job
-- coach (TutorialController) waits for it. The lines are in Config/Story.luau, the art in
-- StoryArt (plain frames until it's uploaded), and the colors and font in UI.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Story = require(Shared.Config.Story)

local ClientState = require(script.Parent.Parent.ClientState)
local StoryArt = require(script.Parent.Parent.StoryArt)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)
local ComputerController = require(script.Parent.ComputerController)

local player = Players.LocalPlayer

-- How fast a line types out, in characters a second.
local TYPE_SPEED = 55
-- How long the camera takes to move between shots near each other, and back to first person.
local SHOT_TIME = 0.8
-- Shots further apart than this (studs) cut, behind a quick fade, instead of flying across town.
local CUT_DISTANCE = 60
local FADE_TIME = 0.25
-- How long a speech bubble stays up: at least this, and a little longer for a long line.
local BUBBLE_TIME = 4
local BUBBLE_PER_CHARACTER = 0.05
-- Bubbles further from the camera than this (studs) aren't drawn.
local BUBBLE_DISTANCE = 300
-- If the title card never says it's gone, scenes wait this long (seconds) after joining.
local TITLE_CARD_WAIT = 40
-- Screens shorter than this (pixels) get the smaller sizes: phones held sideways.
local COMPACT_HEIGHT = 500
-- How often (seconds) to look for a scene to play.
local CHECK_EVERY = 0.25

local DialogueController = {}
-- Fired when a scene starts and when it's over.
DialogueController.Opened = Signal.new()
DialogueController.Closed = Signal.new()

local bars: ScreenGui
local screen: ScreenGui
local fade: Frame
local topBar: Frame
local bottomBar: Frame
local caption: TextLabel
local skipButton: TextButton
local skipLabel: TextLabel
local box: GuiObject
local portrait: Frame
local nameTag: GuiObject
local nameLabel: TextLabel
local lineLabel: TextLabel
local dots: Frame
local continueButton: TextButton
local continueLabel: TextLabel
local card: GuiObject
local cardIcon: Frame
local cardLabel: TextLabel
local cardName: TextLabel

-- The scene playing: its id, the line it's on, and whether it's been skipped or called off.
local playing: { id: string, scene: any, index: number, skipped: boolean, aborted: boolean }? = nil
-- Fired to move on to the next line.
local stepped = Instance.new("BindableEvent")
-- Scenes watched this session (the server's list can lag a moment behind).
local played: { [string]: boolean } = {}
local joinedAt = os.clock()
-- The camera before the scene took it, to give it back, and a token for the scene that has it (a
-- shot still fading in once the scene's over leaves the camera alone).
local savedCamera: CFrame? = nil
local cameraToken: {}? = nil
local cameraTween: Tween? = nil
local typing: RBXScriptConnection? = nil
local controls = nil
local talking = false
-- [adornee] = the speech bubble showing over it
local bubbles: { [Instance]: BillboardGui } = {}

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Sizes for this screen: the mock-up's on a computer, smaller on a phone held sideways.
local function metrics()
	-- The dialogue's own screen, which keeps clear of a phone's notch.
	local camera = workspace.CurrentCamera
	local viewport = if screen and screen.AbsoluteSize.X > 0
		then screen.AbsoluteSize
		elseif camera then camera.ViewportSize
		else Vector2.new(1280, 720)
	local compact = viewport.Y < COMPACT_HEIGHT
	return {
		compact = compact,
		topBar = if compact then 52 else 56,
		bottomBar = if compact then 36 else 56,
		boxWidth = math.max(200, math.min(viewport.X - 32, if compact then 812 else 900)),
		boxBottom = if compact then 14 else 30,
		portrait = if compact then 84 else 116,
		-- How far above the text the portrait's top is (it pokes up out of the box).
		portraitRise = if compact then 36 else 48,
		padX = if compact then 18 else 28,
		padTop = if compact then 20 else 26,
		padBottom = if compact then 6 else 12,
		gap = if compact then 16 else 24,
		text = if compact then 20 else 26,
		name = if compact then 16 else 20,
		footer = 44,
		bubbleWidth = if compact then 240 else 320,
		bubbleText = if compact then 16 else 19,
	}
end

-- Pieces drawn from art, or with plain frames until it's uploaded ----------------------------

-- Corners that make a circle of a square.
local function round(): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end

-- A box from a 9-slice image, or a plain rounded frame with a dark outline.
local function sliced(art, color: Color3, radius: number, props): GuiObject
	local frame: GuiObject
	if art.image ~= "" then
		frame = UI.new("ImageLabel", {
			Image = art.image,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = art.slice,
			BackgroundTransparency = 1,
		})
	else
		frame = UI.new("Frame", { BackgroundColor3 = color }, {
			UI.corner(radius),
			UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 3 }),
		})
	end
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	frame.Parent = props.Parent
	return frame
end

-- A chevron, pointing "Down" or "Right": its image, or two short strokes.
local function chevron(image: string, pointing: string, color: Color3, size: number, props): GuiObject
	local holder: GuiObject
	if image ~= "" then
		holder = UI.new("ImageLabel", { Image = image, ImageColor3 = color, BackgroundTransparency = 1 })
	else
		holder = UI.new("Frame", { BackgroundTransparency = 1 })
		for _, side in { -1, 1 } do
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + side * 0.15, 0.5),
				Size = UDim2.new(0.5, 0, 0, 3),
				Rotation = side * -45,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = holder,
			}, { UI.corner(2) })
		end
	end
	holder.Size = UDim2.fromOffset(size, size)
	-- The strokes make a "v": turned, a ">". (An image is drawn pointing the right way.)
	holder.Rotation = if image == "" and pointing == "Right" then -90 else 0
	for key, value in props do
		if key ~= "Parent" then
			(holder :: any)[key] = value
		end
	end
	holder.Parent = props.Parent
	return holder
end

-- A round face for someone in Config/Story.luau's Cast: their portrait, or their initials on
-- their color until it's uploaded. Also used by the Messages app.
function DialogueController.face(castKey: string, size: number): Frame
	local frame = UI.new("Frame", {
		Name = "Face",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UI.Colors.Card,
	}, { round() })
	DialogueController.setFace(frame, castKey)
	return frame
end

-- Changes who a face shows.
function DialogueController.setFace(frame: Frame, castKey: string)
	for _, child in frame:GetChildren() do
		if child.Name == "Picture" then
			child:Destroy()
		end
	end
	local image = StoryArt.Portraits[castKey] or ""
	local cast = Story.Cast[castKey]
	if image ~= "" then
		UI.new("ImageLabel", {
			Name = "Picture",
			Image = image,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Crop,
			Parent = frame,
		}, { round() })
		return
	end
	UI.new("TextLabel", {
		Name = "Picture",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Cast[castKey] or UI.Colors.Card,
		Font = UI.Font,
		Text = if cast then cast.initials else "",
		TextScaled = true,
		TextColor3 = UI.Colors.BubbleText,
		Parent = frame,
	}, {
		round(),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0.28, 0),
			PaddingBottom = UDim.new(0.28, 0),
			PaddingLeft = UDim.new(0.2, 0),
			PaddingRight = UDim.new(0.2, 0),
		}),
	})
end

-- Speech bubbles ------------------------------------------------------------------------------

-- Shows `text` in a speech bubble over `adornee` (a part or an attachment) for a few seconds,
-- with who's talking (a Cast key) in their color on top. A newer bubble there replaces it.
function DialogueController.bubble(adornee: Instance, speaker: string?, text: string, seconds: number?)
	local old = bubbles[adornee]
	if old then
		old:Destroy()
	end
	local sizes = metrics()
	local gui = UI.new("BillboardGui", {
		Name = "SpeechBubble",
		Adornee = adornee,
		Size = UDim2.fromOffset(sizes.bubbleWidth, 200),
		-- Its bottom (the tail) sits just over the adornee.
		SizeOffset = Vector2.new(0, 0.5),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = BUBBLE_DISTANCE,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local frame = sliced(StoryArt.Bubble, UI.Colors.Bubble, 16, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = gui,
	})
	UI.padding(12).Parent = frame
	UI.list(2).Parent = frame
	local cast = speaker and Story.Cast[speaker]
	if cast then
		UI.label(string.upper(cast.caption or cast.name), {
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 14,
			TextColor3 = UI.Colors.Cast[speaker :: string] or UI.Colors.BubbleText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
			ZIndex = 3,
			Parent = frame,
		})
	end
	UI.label(UI.highlight(text, UI.Colors.Danger), {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		RichText = true,
		TextWrapped = true,
		TextSize = sizes.bubbleText,
		TextColor3 = UI.Colors.BubbleText,
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = frame,
	})
	-- The tail, half tucked under the bubble.
	if StoryArt.BubbleTail ~= "" then
		UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(26, 16),
			Image = StoryArt.BubbleTail,
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = gui,
		})
	else
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.fromOffset(16, 16),
			Rotation = 45,
			BackgroundColor3 = UI.Colors.Bubble,
			ZIndex = 1,
			Parent = gui,
		}, { UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 3 }) })
	end
	bubbles[adornee] = gui
	local shown = seconds or (BUBBLE_TIME + #text * BUBBLE_PER_CHARACTER)
	task.delay(shown, function()
		if bubbles[adornee] == gui then
			bubbles[adornee] = nil
		end
		gui:Destroy()
	end)
	return gui
end

-- Where in the world people are ------------------------------------------------------------

-- Grandma June at your crew's shop (see GrandmaJune on the server).
local function juneModel(): Model?
	local business = ClientState.crewBusiness()
	local june = business and business:FindFirstChild("GrandmaJune")
	return if june and june:IsA("Model") then june else nil
end

local function gloriasHouse(): Model?
	local house = workspace:FindFirstChild("GloriasHouse")
	return if house and house:IsA("Model") then house else nil
end

-- A marker attachment on June or Gloria's house: "Bubble", "TalkView" or "IntroView".
local function marker(who: string, name: string): Attachment?
	local model = if who == "June" then juneModel() elseif who == "Gloria" then gloriasHouse() else nil
	local found = model and model:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found else nil
end

-- The camera --------------------------------------------------------------------------------

local function fadeTo(transparency: number)
	local tween = TweenService:Create(fade, TweenInfo.new(FADE_TIME), { BackgroundTransparency = transparency })
	tween:Play()
	tween.Completed:Wait()
end

-- Points the camera at June or Gloria's house. The first shot takes the camera over.
local function shoot(who: string)
	local view = marker(who, if who == "June" then "TalkView" else "IntroView")
	local camera = workspace.CurrentCamera
	local token = cameraToken
	if not (view and camera and token) then
		return
	end
	if not savedCamera then
		savedCamera = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end
	local goal = view.WorldCFrame
	if (camera.CFrame.Position - goal.Position).Magnitude > CUT_DISTANCE then
		fadeTo(0)
		if cameraToken ~= token then
			return
		end
		camera.CFrame = goal
		fadeTo(1)
	else
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(SHOT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = goal }
		)
		cameraTween = tween
		tween:Play()
	end
end

-- Gives the camera back to first person, looking the way it was before the scene.
local function giveCameraBack()
	local camera = workspace.CurrentCamera
	cameraToken = nil
	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end
	local before = savedCamera
	savedCamera = nil
	if not (before and camera) then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local goal = if head and head:IsA("BasePart") then CFrame.new(head.Position) * before.Rotation else before
	if (camera.CFrame.Position - goal.Position).Magnitude > CUT_DISTANCE then
		fadeTo(0)
		camera.CFrame = goal
		fadeTo(1)
	else
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(SHOT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = goal }
		)
		tween:Play()
		tween.Completed:Wait()
	end
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	-- First person keeps looking whichever way the camera was turned.
	camera.CFrame = goal
end

-- Walking (and the thumbstick on a phone) is off while a scene plays.
local function setControls(enabled: boolean)
	if not controls then
		local ok, module = pcall(function()
			local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
			return playerModule and (require :: any)(playerModule)
		end)
		controls = if ok and module then module:GetControls() else nil
	end
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

-- The box ----------------------------------------------------------------------------------

local function setDots(count: number, current: number)
	UI.clearList(dots)
	for index = 1, count do
		UI.new("Frame", {
			Size = UDim2.fromOffset(22, 6),
			BackgroundColor3 = if index <= current then UI.Colors.Accent else UI.Colors.Track,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = dots,
		}, { UI.corner(3) })
	end
end

-- Lays the box out for this line and screen: the text's height decides the box's.
local function layoutBox(text: string, speaking: boolean)
	local sizes = metrics()
	local textX = sizes.padX + (if speaking then sizes.portrait + sizes.gap else 0)
	local textWidth = sizes.boxWidth - textX - sizes.padX
	local bounds = TextService:GetTextSize(Story.plain(text), sizes.text, UI.Font, Vector2.new(textWidth, math.huge))
	local height = sizes.padTop + bounds.Y + 6 + sizes.footer + sizes.padBottom

	topBar.Size = UDim2.new(1, 0, 0, sizes.topBar)
	bottomBar.Size = UDim2.new(1, 0, 0, sizes.bottomBar)
	box.Position = UDim2.new(0.5, 0, 1, -sizes.boxBottom)
	box.Size = UDim2.fromOffset(sizes.boxWidth, height)
	portrait.Size = UDim2.fromOffset(sizes.portrait, sizes.portrait)
	portrait.Position = UDim2.fromOffset(sizes.padX, sizes.padTop - sizes.portraitRise)
	nameLabel.TextSize = sizes.name
	nameTag.Position = UDim2.fromOffset(textX - 12, -(sizes.name + 12) / 2 - 3)
	lineLabel.TextSize = sizes.text
	lineLabel.Position = UDim2.fromOffset(textX, sizes.padTop)
	lineLabel.Size = UDim2.fromOffset(textWidth, bounds.Y + 6)
	dots.Position = UDim2.new(0, textX, 1, -sizes.padBottom - sizes.footer / 2)
	continueButton.Position = UDim2.new(1, -sizes.padX + 6, 1, -sizes.padBottom)
	continueLabel.TextSize = if sizes.compact then 16 else 18
	skipLabel.TextSize = if sizes.compact then 16 else 17
	card.Position = UDim2.new(0.5, 0, 0, sizes.topBar + 14)
end

-- Types the line out; going on while it's typing shows the rest of it.
local function typeOut(total: number)
	if typing then
		typing:Disconnect()
	end
	local started = os.clock()
	lineLabel.MaxVisibleGraphemes = 0
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local shown = math.floor((os.clock() - started) * TYPE_SPEED)
		if shown >= total then
			lineLabel.MaxVisibleGraphemes = -1
			connection:Disconnect()
			if typing == connection then
				typing = nil
			end
		else
			lineLabel.MaxVisibleGraphemes = shown
		end
	end)
	typing = connection
end

local function showCard(info)
	card.Visible = info ~= nil
	if not info then
		return
	end
	cardLabel.Text = string.upper(info.label or "")
	cardName.Text = info.name or ""
	for _, child in cardIcon:GetChildren() do
		child:Destroy()
	end
	local image = info.icon and StoryArt.CardIcons[info.icon] or ""
	if image ~= "" then
		UI.new("ImageLabel", {
			Image = image,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = cardIcon,
		})
	elseif info.icon == "Shears" then
		-- A pair of shears: two blades crossing over two finger rings.
		for _, side in { -1, 1 } do
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.38),
				Size = UDim2.new(0, 4, 0.55, 0),
				Rotation = side * 30,
				BackgroundColor3 = UI.Colors.Text,
				BorderSizePixel = 0,
				Parent = cardIcon,
			}, { UI.corner(2) })
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + side * 0.17, 0.72),
				Size = UDim2.fromScale(0.28, 0.28),
				BackgroundTransparency = 1,
				Parent = cardIcon,
			}, { UI.corner(20), UI.new("UIStroke", { Color = UI.Colors.Money, Thickness = 3 }) })
		end
	end
end

local function showLine(scene, index: number)
	local line = scene.lines[index]
	local cast = line.speaker and Story.Cast[line.speaker]
	portrait.Visible = cast ~= nil
	nameTag.Visible = cast ~= nil
	if cast then
		DialogueController.setFace(portrait, line.speaker)
		nameLabel.Text = cast.name
	end
	lineLabel.Text = UI.highlight(line.text)
	-- The narrator's lines are a touch quieter than people's.
	lineLabel.TextColor3 = if cast then UI.Colors.Text else UI.Colors.SubText
	layoutBox(line.text, cast ~= nil)
	setDots(#scene.lines, index)
	showCard(line.card)
	typeOut(utf8.len(Story.plain(line.text)) or #line.text)
	if line.shot then
		task.spawn(shoot, line.shot)
	end
	if line.bubble and line.speaker then
		local anchor = marker(line.speaker, "Bubble")
		if anchor then
			DialogueController.bubble(anchor, line.speaker, line.text)
		end
	end
end

-- Goes on: finishes the line if it's still typing, otherwise moves to the next one.
local function advance()
	if not playing then
		return
	end
	if typing then
		typing:Disconnect()
		typing = nil
		lineLabel.MaxVisibleGraphemes = -1
		return
	end
	stepped:Fire()
end

local function skip()
	if playing then
		playing.skipped = true
		stepped:Fire()
	end
end

local function onKey(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		advance()
	end
	return Enum.ContextActionResult.Sink
end

local function open(scene)
	local touch = touchOnly()
	caption.Text = string.upper(scene.caption or "")
	skipLabel.Text = if touch then "Skip" else scene.skipText or "Skip"
	continueLabel.Text = if touch then "Tap to continue" else "Click to continue"
	UI.closeAll()
	UI.hideGame("Dialogue", true)
	UI.holdCursor("Dialogue", true)
	setControls(false)
	cameraToken = {}
	fade.BackgroundTransparency = 1
	bars.Enabled = true
	screen.Enabled = true
	ContextActionService:BindActionAtPriority(
		"DialogueNext",
		onKey,
		false,
		Enum.ContextActionPriority.High.Value + 1,
		Enum.KeyCode.Space,
		Enum.KeyCode.Return,
		Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.ButtonA
	)
	DialogueController.Opened:Fire()
end

local function close()
	ContextActionService:UnbindAction("DialogueNext")
	if typing then
		typing:Disconnect()
		typing = nil
	end
	showCard(nil)
	screen.Enabled = false
	giveCameraBack()
	bars.Enabled = false
	setControls(true)
	UI.holdCursor("Dialogue", false)
	UI.hideGame("Dialogue", false)
	DialogueController.Closed:Fire()
end

-- Plays a scene from Config/Story.luau to the end (or until it's skipped).
local function play(sceneId: string)
	local scene = Story.Scenes[sceneId]
	if not scene or playing then
		return
	end
	local current = { id = sceneId, scene = scene, index = 0, skipped = false, aborted = false }
	playing = current
	open(scene)
	for index = 1, #scene.lines do
		current.index = index
		showLine(scene, index)
		stepped.Event:Wait()
		if current.skipped or current.aborted then
			break
		end
	end
	playing = nil
	close()
	if current.aborted then
		-- Called off (the crew drove off to a job): it plays again later.
		return
	end
	played[sceneId] = true
	Net.event("SceneWatched"):FireServer(sceneId)
	-- Off the list here too, until the server's update comes back.
	local story = ClientState.story
	local queued = story and table.find(story.scenes, sceneId)
	if queued then
		table.remove(story.scenes, queued)
		ClientState.Changed:Fire("story")
	end
end

-- When scenes may play -----------------------------------------------------------------------

local function titleCardGone(): boolean
	if player:GetAttribute("TitleCardDone") == true then
		return true
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	return os.clock() - joinedAt > TITLE_CARD_WAIT and not (playerGui and playerGui:FindFirstChild("TitleCard"))
end

-- Not on a job or at the computer, no menu open, nothing else on the screen.
local function goodMoment(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return titleCardGone()
		and humanoid ~= nil
		and humanoid.Health > 0
		and ClientState.job == nil
		and not ComputerController.isUsing()
		and not UI.anyOpen()
		and UI.getScreen().Enabled
		and CameraController.isFirstPerson()
		and player:GetAttribute("PlacingDecor") == nil
end

local function nextScene(): string?
	local story = ClientState.story
	for _, id in if story then story.scenes else {} do
		if not played[id] and Story.Scenes[id] then
			return id
		end
	end
	return nil
end

-- Public API ---------------------------------------------------------------------------------

function DialogueController.isOpen(): boolean
	return playing ~= nil
end

-- Whether a scene is waiting to play (or playing): the intro, say.
function DialogueController.isPending(sceneId: string): boolean
	local story = ClientState.story
	return (playing ~= nil and playing.id == sceneId)
		or (story ~= nil and table.find(story.scenes, sceneId) ~= nil and not played[sceneId])
end

-- Talks to Grandma June on her porch (InteractController): the server picks what she says, and
-- it shows in a bubble over her.
function DialogueController.talk(june: Instance)
	if talking or playing then
		return
	end
	talking = true
	task.spawn(function()
		local ok, line = pcall(function()
			return Net.func("TalkToJune"):InvokeServer(june)
		end)
		if ok and typeof(line) == "string" then
			local anchor = june:FindFirstChild("Bubble", true)
			DialogueController.bubble(anchor or june, "June", line)
		end
		talking = false
	end)
end

-- Building it --------------------------------------------------------------------------------

local function build()
	local playerGui = player:WaitForChild("PlayerGui")
	-- The letterbox bars and the fade fill the whole screen, notches and all.
	bars = UI.new("ScreenGui", {
		Name = "DialogueBars",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Enabled = false,
		Parent = playerGui,
	})
	-- What you read and press stays clear of a phone's notch.
	screen = UI.new("ScreenGui", {
		Name = "Dialogue",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 9,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	pcall(function()
		(bars :: any).ScreenInsets = Enum.ScreenInsets.None;
		(screen :: any).ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)

	fade = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Letterbox,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = bars,
	})
	topBar = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = UI.Colors.Letterbox,
		BorderSizePixel = 0,
		Parent = bars,
	})
	bottomBar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = UI.Colors.Letterbox,
		BorderSizePixel = 0,
		Parent = bars,
	})

	-- A click or tap anywhere goes on.
	local catcher = UI.new("TextButton", {
		Name = "Continue",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = screen,
	})
	catcher.Activated:Connect(advance)

	-- Up top: where and when (in the middle, clear of Roblox's own buttons), and Skip.
	caption = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.5, 0, 0, 44),
		TextSize = 16,
		TextColor3 = UI.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = screen,
	})
	skipButton = UI.new("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		Text = "",
		Parent = screen,
	}, {
		UI.corner(12),
		UI.new("UIStroke", { Color = UI.Colors.Card, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12) }),
		UI.list(6, Enum.FillDirection.Horizontal),
	})
	local skipList = skipButton:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	skipList.VerticalAlignment = Enum.VerticalAlignment.Center
	skipLabel = UI.label("Skip", {
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 17,
		LayoutOrder = 1,
		Parent = skipButton,
	})
	chevron(StoryArt.SkipChevron, "Right", UI.Colors.Text, 16, { LayoutOrder = 2, Parent = skipButton })
	skipButton.Activated:Connect(skip)

	-- The box along the bottom.
	box = sliced(StoryArt.DialogueBox, UI.Colors.Panel, 20, {
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(900, 160),
		ZIndex = 2,
		Parent = screen,
	})
	portrait = DialogueController.face("June", 116)
	portrait.ZIndex = 3
	portrait.Parent = box
	UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 3, Parent = portrait })
	nameTag = sliced(StoryArt.NameTag, UI.Colors.Accent, 12, {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 3,
		Parent = box,
	})
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = nameTag,
	})
	nameLabel = UI.label("", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextColor3 = UI.Colors.BubbleText,
		ZIndex = 4,
		Parent = nameTag,
	})
	lineLabel = UI.label("", {
		TextWrapped = true,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = box,
	})
	dots = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(300, 10),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = box,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	continueButton = UI.new("TextButton", {
		Name = "Next",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
		Parent = box,
	}, {
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 6) }),
		UI.list(6, Enum.FillDirection.Horizontal),
	})
	local continueList = continueButton:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	continueList.VerticalAlignment = Enum.VerticalAlignment.Center
	continueLabel = UI.label("Click to continue", {
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = UI.Colors.SubText,
		LayoutOrder = 1,
		ZIndex = 4,
		Parent = continueButton,
	})
	chevron(StoryArt.ContinueChevron, "Down", UI.Colors.SubText, 20, {
		LayoutOrder = 2,
		ZIndex = 4,
		Parent = continueButton,
	})
	continueButton.Activated:Connect(advance)

	-- The card that pops up for a new tool.
	card = sliced({ image = "" }, UI.Colors.Panel, 16, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 64),
		Visible = false,
		ZIndex = 2,
		Parent = screen,
	})
	cardIcon = UI.new("Frame", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = UI.Colors.Card,
		ZIndex = 3,
		Parent = card,
	}, { UI.corner(10) })
	cardLabel = UI.label("", {
		Position = UDim2.fromOffset(68, 10),
		Size = UDim2.new(1, -80, 0, 18),
		TextSize = 13,
		TextColor3 = UI.Colors.Accent,
		ZIndex = 3,
		Parent = card,
	})
	cardName = UI.label("", {
		Position = UDim2.fromOffset(68, 28),
		Size = UDim2.new(1, -80, 0, 24),
		TextSize = 18,
		TextScaled = true,
		ZIndex = 3,
		Parent = card,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = cardName })
end

function DialogueController:Start()
	build()
	-- The screen turned or resized (a phone rotating): lay the line out again.
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local current = playing
			if current and current.index > 0 then
				local line = current.scene.lines[current.index]
				layoutBox(line.text, line.speaker ~= nil)
			end
		end)
	end
	-- The crew heading out to a job takes the camera: the scene stops, to play again later.
	ClientState.Changed:Connect(function(key)
		local current = playing
		if key == "job" and current and ClientState.job ~= nil then
			current.aborted = true
			stepped:Fire()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			if not playing then
				local sceneId = nextScene()
				if sceneId and goodMoment() then
					play(sceneId)
				end
			end
		end
	end)
end

return DialogueController
