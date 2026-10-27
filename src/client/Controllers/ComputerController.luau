-- The job computer in your shop (docs/GAME_DESIGN.md, "The shop as the hub"). Look at the desk
-- and press E: you step up to it, the camera eases in to the screen and the desktop opens, with
-- its apps:
--   Jobs      today's jobs, hints only (anyone can look; only the crew leader can take one)
--   Orders    tools and supplies, delivered in a box to the shop, and selling
--   Business  building upgrades, trucks and trailers
--   Crew      inviting and managing your crew
--   Messages  texts from Grandma June and the neighborhood, and your goal (MessagesController);
--             its buttons show how many texts are unread
-- The apps are the game's usual menus, shown inside the monitor, over the art's wallpaper, with
-- each app's icon on the desktop and the taskbar, and your money at its end. The open app's
-- button on the taskbar is green. Back, or walking away, eases the camera back to first person.
-- The desk's ScreenView attachment is where the camera goes and UseSpot is where you stand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local ShopController = require(script.Parent.ShopController)

local player = Players.LocalPlayer

-- How long the camera takes to ease in and out.
local EASE_TIME = 0.6
-- Narrower view at the screen, so the monitor fills it.
local SCREEN_FOV = 50
-- Height of the taskbar along the bottom of the screen.
local TASKBAR = 48
-- Your money shows at the taskbar's end on screens at least this wide (pixels), and how wide.
local MONEY_FROM = 760
local MONEY_WIDTH = 120
-- The taskbar's buttons show their app's name beside its icon on screens at least this wide;
-- narrower (a phone), just the icon, centred, so the words never run into each other.
local NAMES_FROM = 1100
local BACK_WIDTH = 104
-- Walking this far from the desk (or starting to walk) puts the computer away.
local WALK_AWAY = 3
local WALK_GRACE = 0.5
-- When the shop's rebuilt (a new truck, trailer or building), you move to its new desk if it turns
-- up within this many seconds.
local REBUILD_GRACE = 2

-- Each app opens a menu (`panel`); Orders and Business share the shop's.
local APPS = {
	{
		name = "Jobs",
		hint = "Today's jobs",
		panel = "Jobs",
		open = function()
			UI.open("Jobs")
		end,
	},
	{
		name = "Orders",
		hint = "Tools and supplies",
		panel = "Shop",
		open = function()
			ShopController.openApp("Orders")
		end,
	},
	{
		name = "Business",
		hint = "Building, truck, trailer",
		panel = "Shop",
		open = function()
			ShopController.openApp("Business")
		end,
	},
	{
		name = "Crew",
		hint = "Your crew",
		panel = "Crew",
		open = function()
			UI.open("Crew")
		end,
	},
	{
		name = "Messages",
		hint = "Texts and your goal",
		panel = "Messages",
		-- Its buttons show how many texts are unread.
		badge = true,
		open = function()
			UI.open("Messages")
		end,
	},
}

local ComputerController = {}

local screen: ScreenGui
local appArea: Frame
local desktop: Frame
local using: { desk: Model, spot: Vector3, since: number, lostAt: number? }? = nil
-- The camera easing in to the screen or back out, so it can be stopped.
local cameraTween: Tween? = nil
-- The app that's open (its taskbar button is green), the taskbar's buttons, and the unread badges.
local activeApp = nil
local taskButtons: { [any]: TextButton } = {}
local badges: { GuiObject } = {}
local taskbarButtons: Frame
local money

local function moveCamera(goal: { [string]: any }): Tween
	if cameraTween then
		cameraTween:Cancel()
	end
	local tween = TweenService:Create(
		workspace.CurrentCamera,
		TweenInfo.new(EASE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		goal
	)
	cameraTween = tween
	tween:Play()
	return tween
end

local function stopCamera()
	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end
end

function ComputerController.isUsing(): boolean
	return using ~= nil
end

-- Puts the computer away. The camera eases back to first person, or snaps back `instantly`. When
-- something else is `takingCamera` (the drive cutscene), it's left to that, which puts it back.
function ComputerController.leave(instantly: boolean?, takingCamera: boolean?)
	local camera = workspace.CurrentCamera
	if takingCamera then
		-- Even if the computer's already put away: the camera may still be easing back.
		stopCamera()
		camera.FieldOfView = GameConfig.Camera.FieldOfView
	end
	if not using then
		return
	end
	using = nil
	UI.closeAll()
	UI.setHost(nil)
	screen.Enabled = false
	if takingCamera then
		return
	end
	local function backToFirstPerson()
		cameraTween = nil
		if camera.CameraType == Enum.CameraType.Scriptable and not using then
			camera.CameraType = Enum.CameraType.Custom
		end
		camera.FieldOfView = GameConfig.Camera.FieldOfView
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if instantly or not (head and head:IsA("BasePart")) then
		stopCamera()
		backToFirstPerson()
		return
	end
	local back = moveCamera({ CFrame = head.CFrame, FieldOfView = GameConfig.Camera.FieldOfView })
	back.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			backToFirstPerson()
		end
	end)
end

-- Steps up to the desk, facing it, and eases the camera in to its screen. False if it can't.
local function sitAt(desk: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local spot = desk:FindFirstChild("UseSpot", true)
	local view = desk:FindFirstChild("ScreenView", true)
	if not (character and root and root:IsA("BasePart") and humanoid and spot and spot:IsA("Attachment")) then
		return false
	end
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local stand = spot.WorldCFrame + Vector3.new(0, legs + root.Size.Y / 2, 0)
	character:PivotTo(stand)
	using = { desk = desk, spot = stand.Position, since = os.clock() }
	if view and view:IsA("Attachment") then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		moveCamera({ CFrame = view.WorldCFrame, FieldOfView = SCREEN_FOV })
	end
	return true
end

function ComputerController.use(desk: Model)
	if using or not sitAt(desk) then
		return
	end
	UI.closeAll()
	UI.setHost(appArea)
	screen.Enabled = true
	desktop.Visible = true
end

-- The shop was rebuilt under you (a new truck, trailer or building): carry on at its new desk.
local function followDesk(current)
	local business = ClientState.crewBusiness()
	local desk = business and business:FindFirstChild("Desk")
	local spot = desk and desk:FindFirstChild("UseSpot", true)
	if not (desk and desk:IsA("Model") and spot and spot:IsA("Attachment")) then
		-- Not here yet (or gone for good).
		current.lostAt = current.lostAt or os.clock()
		if os.clock() - current.lostAt > REBUILD_GRACE then
			ComputerController.leave(true)
		end
		return
	end
	if (spot.WorldPosition - current.spot).Magnitude > 4 then
		-- A new building: over to where its desk is.
		if not sitAt(desk) then
			ComputerController.leave(true)
		end
	else
		current.desk = desk
		current.lostAt = nil
	end
end

-- Greens the open app's taskbar button.
local function updateActive()
	if activeApp and not UI.isOpen(activeApp.panel) then
		activeApp = nil
	end
	for app, button in taskButtons do
		UI.setStyle(button, if app == activeApp then "Primary" else "Neutral")
	end
end

local function openApp(app)
	activeApp = app
	app.open()
	updateActive()
end

-- The unread count in the top right corner of an app's button: the art's round badge, or a yellow
-- circle.
local function addBadge(button: GuiObject, inset: number)
	local art = Art.kit("Badge_Unread")
	local badge = UI.sliced("Badge_Unread", {
		Name = "Unread",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -inset, 0, inset),
		Size = UDim2.fromOffset(24, 24),
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { color = UI.Colors.Money, radius = 12 })
	UI.label("", {
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = if art ~= "" then UI.Colors.Text else UI.Colors.BubbleText,
		TextSize = 14,
		FontFace = UI.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = badge,
	})
	table.insert(badges, badge)
end

local function updateBadges()
	local story = ClientState.story
	local unread = if story then Story.unread(story.texts, story.read) else 0
	for _, badge in badges do
		badge.Visible = unread > 0
		local count = badge:FindFirstChild("Count")
		if count and count:IsA("TextLabel") then
			count.Text = if unread > 9 then "9+" else tostring(unread)
		end
	end
end

-- Your money at the taskbar's end, where there's room for it.
local function updateMoney()
	local profile = ClientState.profile
	if money and profile then
		money:SetText(Format.money(profile.money))
	end
end

local function fitTaskbar(display: GuiObject)
	local width = display.AbsoluteSize.X
	local wide = width >= MONEY_FROM
	money.Frame.Visible = wide
	taskbarButtons.Size = UDim2.new(1, -(BACK_WIDTH + 8 + (if wide then MONEY_WIDTH else 0)), 1, 0)
	local named = width >= NAMES_FROM
	for app, button in taskButtons do
		local text = if named then app.name else ""
		if button.Text ~= text then
			button.Text = text
		end
	end
end

-- An app on the desktop: its icon from the art over its name and what it's for, or a plain
-- button with the words.
local function desktopIcon(app, index: number)
	local image = Art.computer(`App_{app.name}`)
	local icon
	if image ~= "" then
		icon = UI.new("TextButton", {
			Name = app.name,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
			Parent = desktop,
		})
		local picture = UI.picture(image, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, 0, 1, -40),
			Parent = icon,
		}) :: ImageLabel
		UI.new("UIAspectRatioConstraint", { Parent = picture })
		UI.label(app.name, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -18),
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = 18,
			FontFace = UI.Fonts.Heavy,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = UI.Colors.Ink,
			TextStrokeTransparency = 0.3,
			Parent = icon,
		})
		-- Held down, the icon dips a little.
		icon.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				picture.Position = UDim2.new(0.5, 0, 0, 2)
			end
		end)
		icon.InputEnded:Connect(function()
			picture.Position = UDim2.fromScale(0.5, 0)
		end)
		icon.Activated:Connect(function()
			openApp(app)
		end)
		if app.badge then
			addBadge(picture, 6)
		end
	else
		icon = UI.button(app.name, function()
			openApp(app)
		end, {
			LayoutOrder = index,
			TextSize = 24,
			Style = "Neutral",
			Parent = desktop,
		})
		if app.badge then
			addBadge(icon, 6)
		end
	end
	UI.label(app.hint, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, if image ~= "" then 0 else -8),
		Size = UDim2.new(1, -10, 0, 18),
		TextSize = 14,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = UI.Colors.Ink,
		TextStrokeTransparency = if image ~= "" then 0.4 else 1,
		ZIndex = 2,
		Parent = icon,
	})
end

local function build()
	screen = UI.new("ScreenGui", {
		Name = "Computer",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- The monitor: a dark bezel around the screen.
	local bezel = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(22, 22, 26),
		-- Taps on the monitor stay on it, instead of reaching the thumbstick and walking you off.
		Active = true,
		Parent = screen,
	}, { UI.corner(14) })
	UI.keepPlaced(bezel, "ComputerMonitor")
	local display = UI.new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundColor3 = Color3.fromRGB(34, 70, 50),
		ClipsDescendants = true,
		Parent = bezel,
	}, { UI.corner(6) })
	-- The wallpaper: a freshly striped lawn with Grandma's porch at the edge.
	UI.picture(Art.computer("Wallpaper"), {
		Name = "Wallpaper",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		Parent = display,
	})
	appArea = UI.new("Frame", {
		Name = "Apps",
		Size = UDim2.new(1, 0, 1, -TASKBAR),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = display,
	})

	-- The desktop, under the apps: one big icon per app, in a row that shrinks to fit a phone.
	desktop = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -TASKBAR / 2),
		Size = UDim2.new(0.94, 0, 0, 130),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = display,
	}, {
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(680, 130) }),
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / #APPS, -12, 1, 0),
			CellPadding = UDim2.fromOffset(12 * #APPS / (#APPS - 1), 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, app in APPS do
		desktopIcon(app, index)
	end

	-- The taskbar along the bottom.
	local taskbar = UI.sliced("Computer/Taskbar", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, TASKBAR),
		ZIndex = 3,
		Parent = display,
	}, { color = UI.Colors.Ink, transparency = 0.1, radius = 0 })
	UI.padding(5).Parent = taskbar
	taskbarButtons = UI.new("Frame", {
		Size = UDim2.new(1, -(BACK_WIDTH + 8), 1, 0),
		BackgroundTransparency = 1,
		Parent = taskbar,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	-- The buttons share the bar, so all five fit on a phone.
	for index, app in APPS do
		local button = UI.button(app.name, function()
			openApp(app)
		end, {
			Style = "Neutral",
			IconImage = Art.computer(`App_{app.name}`),
			IconSize = 24,
			LayoutOrder = index,
			Size = UDim2.new(1 / #APPS, -6, 1, 0),
			TextScaled = true,
			FontFace = UI.Fonts.Bold,
			Parent = taskbarButtons,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = button })
		taskButtons[app] = button
		if app.badge then
			addBadge(button, 2)
		end
	end
	money = UI.display("Numbers", "", { TextSize = 24, Color = UI.Colors.Money, XAlignment = "Right", Fit = true }, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(BACK_WIDTH + 8), 0, 0),
		Size = UDim2.new(0, MONEY_WIDTH - 12, 1, 0),
		Parent = taskbar,
	})
	UI.button("Back", function()
		ComputerController.leave()
	end, {
		Style = "Neutral",
		Icon = "Back",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, BACK_WIDTH, 1, 0),
		TextSize = 16,
		Parent = taskbar,
	})
	display:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitTaskbar(display)
	end)
	fitTaskbar(display)
	updateMoney()
end

function ComputerController:Start()
	build()

	-- The desktop shows while no app is open.
	UI.CursorChanged:Connect(function()
		if desktop then
			desktop.Visible = using ~= nil and not UI.anyOpen()
		end
		updateActive()
	end)
	updateBadges()
	-- Walking away, dying or heading off on a job puts it away.
	RunService.Heartbeat:Connect(function()
		local current = using
		if not current then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
			ComputerController.leave(true)
			return
		end
		if not current.desk.Parent then
			followDesk(current)
			return
		end
		local wandered = (root.Position - current.spot).Magnitude > WALK_AWAY
		local walking = humanoid.MoveDirection.Magnitude > 0.5 and os.clock() - current.since > WALK_GRACE
		if wandered or walking then
			ComputerController.leave()
		end
	end)
	-- The crew heading out takes the camera (to the cab, then the road).
	for _, name in { "PullingOut", "TravelStarted" } do
		Net.event(name).OnClientEvent:Connect(function()
			ComputerController.leave(true, true)
		end)
	end
	ClientState.Changed:Connect(function(key)
		-- Driving off to a job: the cutscene takes the camera.
		if key == "job" and using and ClientState.job and ClientState.job.state == "Traveling" then
			ComputerController.leave(true, true)
		elseif key == "story" then
			updateBadges()
		elseif key == "profile" then
			updateMoney()
		end
	end)
end

return ComputerController
