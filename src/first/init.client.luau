-- The title card (docs/GAME_DESIGN.md, "Joining"). It runs from ReplicatedFirst, before anything
-- else, and covers the screen while the world loads, the server reads the player's save and
-- builds their business, and they're moved to it (the server sets the "ArrivedAtBusiness"
-- attribute). Then it asks for a tap or click and fades out on the player standing at their shop,
-- and sets the TitleCardDone attribute (on this screen only) for the story's intro to start.
-- Its art is in TitleCardArt; anything not uploaded yet is drawn instead.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Art = require(script:WaitForChild("TitleCardArt"))

-- The card stays up at least this long, so it reads as a title card and not a flicker.
local MIN_SHOWN = 2.5
-- Give up waiting for the server after this long and let them in anyway.
local GIVE_UP = 25
-- How long the ground under the player may take to stream in once they've arrived.
local GROUND_WAIT = 5
local FADE_TIME = 0.6
-- How long the art takes to fade in over the drawn card once it has loaded.
local ART_FADE = 0.4
local FONT = Enum.Font.FredokaOne
local SKY_TOP, SKY_BOTTOM = Color3.fromRGB(120, 185, 235), Color3.fromRGB(255, 214, 150)
local STRIPES = { Color3.fromRGB(96, 168, 62), Color3.fromRGB(78, 146, 50) }
local BAR_TRACK = Color3.fromRGB(30, 40, 30)
local BAR_FILL = Color3.fromRGB(120, 200, 75)

local player = Players.LocalPlayer
local started = os.clock()

pcall(ReplicatedFirst.RemoveDefaultLoadingScreen, ReplicatedFirst)

-- Roblox's chat window and chat bar would open on top of the card; they come back when the card
-- goes. Their settings may not have loaded yet this early.
local hiddenChat: { [Instance]: boolean } = {}
local cardUp = true
for _, name in { "ChatWindowConfiguration", "ChatInputBarConfiguration" } do
	task.spawn(function()
		local found = TextChatService:WaitForChild(name, 10)
		if found and cardUp then
			hiddenChat[found] = (found :: any).Enabled;
			(found :: any).Enabled = false
		end
	end)
end

local function new(className: string, props, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number): Instance
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local gui = new("ScreenGui", {
	Name = "TitleCard",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}) :: ScreenGui
pcall(function()
	(gui :: any).ScreenInsets = Enum.ScreenInsets.None
end)

-- Everything fades out together.
local card = new("CanvasGroup", {
	Name = "Card",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = SKY_BOTTOM,
	BorderSizePixel = 0,
	Parent = gui,
}) :: CanvasGroup

-- The background: a drawn sunrise over a freshly mown lawn, and the key art over it once it has
-- loaded, covering the screen and cropped to it.
new("Frame", {
	Size = UDim2.fromScale(1, 0.62),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = card,
}, {
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(SKY_TOP, SKY_BOTTOM) }),
})
local lawn = new("Frame", {
	Position = UDim2.fromScale(0, 0.62),
	Size = UDim2.fromScale(1, 0.38),
	BackgroundColor3 = STRIPES[1],
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = card,
})
-- Mowing stripes running off toward the horizon.
local count = 12
for index = 0, count - 1 do
	new("Frame", {
		Position = UDim2.fromScale(index / count, 0),
		Size = UDim2.fromScale(1 / count, 1),
		BackgroundColor3 = STRIPES[index % 2 + 1],
		BorderSizePixel = 0,
		Parent = lawn,
	})
end
new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	Parent = lawn,
}, {
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(0.55, 1),
	}),
})

-- Pieces of art that fade in over what's drawn once they've loaded.
local fadeIn: { ImageLabel } = {}
if Art.Background[1] ~= "" then
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = card,
	}) :: Frame
	-- As wide or as tall as it takes to cover the screen at 16:9, like ScaleType Crop.
	local function cover()
		local screen = card.AbsoluteSize
		local width = math.max(screen.X, screen.Y * 16 / 9)
		holder.Size = UDim2.fromOffset(width, width * 9 / 16)
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(cover)
	cover()
	for index, image in Art.Background do
		local column, row = (index - 1) % 2, (index - 1) // 2
		table.insert(
			fadeIn,
			new("ImageLabel", {
				Image = image,
				ImageTransparency = 1,
				Position = UDim2.fromScale(column / 2, row / 2),
				Size = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Parent = holder,
			}) :: ImageLabel
		)
	end
end

-- The logo, or the name set in big letters.
local logoArea = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.1),
	Size = UDim2.fromScale(0.62, 0.36),
	BackgroundTransparency = 1,
	Parent = card,
}, {
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 450) }),
})
-- The name in big letters shows until the logo has loaded, then gives way to it.
local words: { TextLabel } = {}
local function word(text: string, y: number, height: number)
	table.insert(
		words,
		new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(1, height),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = text,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = logoArea,
		}, {
			new("UIStroke", { Color = Color3.fromRGB(35, 70, 30), Thickness = 4 }),
		}) :: TextLabel
	)
end
word("LAWN MOWING", 0.05, 0.58)
word("SIMULATOR", 0.64, 0.3)
if Art.Logo ~= "" then
	table.insert(
		fadeIn,
		new("ImageLabel", {
			Image = Art.Logo,
			ImageTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Parent = logoArea,
		}) :: ImageLabel
	)
end

-- The loading bar along the bottom: the status line, a track that fills with mown stripes, and a
-- mower that rolls along at the front of it.
local barArea = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.9),
	Size = UDim2.new(0.5, 0, 0, 70),
	BackgroundTransparency = 1,
	Parent = card,
}, {
	new("UISizeConstraint", { MinSize = Vector2.new(260, 70), MaxSize = Vector2.new(640, 70) }),
})
local status = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "Loading the neighborhood...",
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	Parent = barArea,
}, {
	new("UIStroke", { Color = Color3.fromRGB(35, 70, 30), Thickness = 2 }),
}) :: TextLabel
local track = new("Frame", {
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundColor3 = BAR_TRACK,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Parent = barArea,
}, { corner(9) })
local fill = new(if Art.Stripes ~= "" then "ImageLabel" else "Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = BAR_FILL,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = track,
}, { corner(9) }) :: GuiObject
if Art.Stripes ~= "" then
	local image = fill :: ImageLabel
	image.Image = Art.Stripes
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(64, 16)
end
local mower = new(if Art.Mower ~= "" then "ImageLabel" else "Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = barArea,
}) :: GuiObject
if Art.Mower ~= "" then
	(mower :: ImageLabel).Image = Art.Mower
else
	-- A little red push mower: deck, handle and two wheels.
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.45, 0.78),
		Size = UDim2.fromScale(0.7, 0.3),
		BackgroundColor3 = Color3.fromRGB(205, 50, 45),
		BorderSizePixel = 0,
		Parent = mower,
	}, { corner(4) })
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.7, 0.55),
		Size = UDim2.fromScale(0.08, 0.5),
		Rotation = 30,
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0,
		Parent = mower,
	})
	for _, x in { 0.22, 0.68 } do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(x, 1),
			Size = UDim2.fromScale(0.26, 0.26),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 0,
			Parent = mower,
		}, { corner(20) })
	end
end

local prompt = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.9),
	Size = UDim2.fromOffset(420, 40),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Tap to start"
		else "Click or press any key to start",
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
	Parent = card,
}, {
	new("UIStroke", { Color = Color3.fromRGB(35, 70, 30), Thickness = 3 }),
}) :: TextLabel

gui.Parent = player:WaitForChild("PlayerGui")

-- Shows how far along joining is (0-1), with what's happening.
local function progress(amount: number, text: string)
	status.Text = text
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(fill, info, { Size = UDim2.fromScale(amount, 1) }):Play()
	TweenService:Create(mower, info, { Position = UDim2.new(amount, 0, 0, 40) }):Play()
end

-- Waits for `check` to be true, up to `seconds`.
local function waitFor(check: () -> boolean, seconds: number)
	local deadline = os.clock() + seconds
	while not check() and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- Each step of joining goes in the F9 console, so a slow join (on a phone, say) shows where the
-- time went: how long the step took, and how long since the card went up. The server logs its
-- side (loading the save, building the business).
local stepStarted = started
local function logStep(step: string)
	local now = os.clock()
	print(string.format("[Load] %s after %.1f s (%.1f s in)", step, now - stepStarted, now - started))
	stepStarted = now
end

local images = { Art.Logo, Art.Mower, Art.Stripes }
for _, image in Art.Background do
	table.insert(images, image)
end
local toLoad = {}
for _, image in images do
	if image ~= "" then
		table.insert(toLoad, image)
	end
end
-- Once the art has loaded, it fades in over what's drawn (and the logo takes over from the words).
task.spawn(function()
	if #toLoad > 0 then
		pcall(ContentProvider.PreloadAsync, ContentProvider, toLoad)
	end
	if #fadeIn == 0 then
		return
	end
	local info = TweenInfo.new(ART_FADE)
	for _, image in fadeIn do
		TweenService:Create(image, info, { ImageTransparency = 0 }):Play()
	end
	if Art.Logo ~= "" then
		for _, label in words do
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, info, { Transparency = 1 }):Play()
			end
		end
	end
end)

progress(0.1, "Loading the neighborhood...")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
logStep("Game loaded")

progress(0.45, "Opening up your shop...")
local function arrived(): boolean
	return player:GetAttribute("ArrivedAtBusiness") == true
end
waitFor(arrived, GIVE_UP - (os.clock() - started))
logStep(if arrived() then "At their business" else "Gave up waiting for their business")

progress(0.8, "Getting your tools ready...")
local params = RaycastParams.new()
local function onGround(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	params.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params) ~= nil
end
waitFor(onGround, GROUND_WAIT)
logStep(if onGround() then "Ground loaded under them" else "Gave up waiting for the ground")

progress(1, "Ready!")
task.wait(math.max(0.6, MIN_SHOWN - (os.clock() - started)))

-- The bar makes way for the start prompt, which breathes until they tap, click or press a key.
barArea.Visible = false
prompt.Visible = true
local breathing = TweenService:Create(
	prompt,
	TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.45 }
)
breathing:Play()
logStep("Tap to start showing")
local go = Instance.new("BindableEvent")
local connection = UserInputService.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if
		kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.Touch
		or kind == Enum.UserInputType.Keyboard
		or kind == Enum.UserInputType.Gamepad1
	then
		go:Fire()
	end
end)
go.Event:Wait()
connection:Disconnect()
breathing:Cancel()
logStep("Started")

-- The server turned them to face their shop, but a first-person camera keeps looking the way it
-- was (and turns the character with it), so point the camera the way the server said. Once the
-- card's gone, CameraController turns it after each move. FacedArrival says which move this was,
-- so it doesn't turn the camera for this one again.
local facing = player:GetAttribute("ArrivedFacing")
local camera = workspace.CurrentCamera
if typeof(facing) == "Vector3" and camera then
	local from = camera.CFrame.Position
	camera.CFrame = CFrame.lookAt(from, from + Vector3.new(facing.X, 0, facing.Z))
	player:SetAttribute("FacedArrival", player:GetAttribute("Arrivals"))
end
cardUp = false
for config, wasOn in hiddenChat do
	(config :: any).Enabled = wasOn
end

local fade = TweenService:Create(card, TweenInfo.new(FADE_TIME), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
-- The story's intro plays now (see DialogueController). Only this player's screen sees it.
player:SetAttribute("TitleCardDone", true)
