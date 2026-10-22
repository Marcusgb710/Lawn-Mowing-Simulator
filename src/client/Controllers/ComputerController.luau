-- The job computer in your shop (docs/GAME_DESIGN.md, "The shop as the hub"). Look at the desk
-- and press E: you step up to it, the camera eases in to the screen and the desktop opens, with
-- its apps:
--   Jobs      today's jobs, hints only (anyone can look; only the crew leader can take one)
--   Orders    tools and supplies, delivered in a box to the shop, and selling
--   Business  building upgrades, trucks and trailers
--   Crew      inviting and managing your crew
--   Messages  texts from Grandma June and the neighborhood, and your goal (MessagesController);
--             its buttons show how many texts are unread
-- The apps are the game's usual menus, shown inside the monitor. The open app's button on the
-- taskbar is green. Back, or walking away, eases the camera back to first person. The desk's
-- ScreenView attachment is where the camera goes and UseSpot is where you stand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local ShopController = require(script.Parent.ShopController)

local player = Players.LocalPlayer

-- How long the camera takes to ease in and out.
local EASE_TIME = 0.6
-- Narrower view at the screen, so the monitor fills it.
local SCREEN_FOV = 50
-- Height of the taskbar along the bottom of the screen.
local TASKBAR = 44
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
local badges: { TextLabel } = {}

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
		local active = app == activeApp
		button.BackgroundColor3 = if active then UI.Colors.Accent else UI.Colors.Card
		button.TextColor3 = if active then UI.Colors.BubbleText else UI.Colors.Text
	end
end

local function openApp(app)
	activeApp = app
	app.open()
	updateActive()
end

-- A yellow unread count in the top right corner of an app's button.
local function addBadge(button: GuiObject, inset: number)
	local badge = UI.label("", {
		Name = "Unread",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -inset, 0, inset),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Colors.Money,
		TextColor3 = UI.Colors.BubbleText,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})
	UI.corner(12).Parent = badge
	table.insert(badges, badge)
end

local function updateBadges()
	local story = ClientState.story
	local unread = if story then Story.unread(story.texts, story.read) else 0
	for _, badge in badges do
		badge.Visible = unread > 0
		badge.Text = if unread > 9 then "9+" else tostring(unread)
	end
end

local function build()
	screen = UI.new("ScreenGui", {
		Name = "Computer",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- The monitor: a dark bezel around the screen.
	local bezel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.98, 0.96),
		BackgroundColor3 = Color3.fromRGB(22, 22, 26),
		-- Taps on the monitor stay on it, instead of reaching the thumbstick and walking you off.
		Active = true,
		Parent = screen,
	}, { UI.corner(14), UI.new("UISizeConstraint", { MaxSize = Vector2.new(1000, 640) }) })
	local display = UI.new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundColor3 = Color3.fromRGB(34, 70, 50),
		ClipsDescendants = true,
		Parent = bezel,
	}, { UI.corner(6) })
	appArea = UI.new("Frame", {
		Name = "Apps",
		Size = UDim2.new(1, 0, 1, -TASKBAR),
		BackgroundTransparency = 1,
		Parent = display,
	})

	-- The desktop, under the apps: one big icon per app, in a row that shrinks to fit a phone.
	desktop = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -TASKBAR / 2),
		Size = UDim2.new(0.94, 0, 0, 110),
		BackgroundTransparency = 1,
		Parent = display,
	}, {
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(660, 110) }),
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / #APPS, -12, 1, 0),
			CellPadding = UDim2.fromOffset(12 * #APPS / (#APPS - 1), 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, app in APPS do
		local icon = UI.button(app.name, function()
			openApp(app)
		end, {
			LayoutOrder = index,
			TextSize = 24,
			BackgroundColor3 = UI.Colors.Panel,
			Parent = desktop,
		})
		if app.badge then
			addBadge(icon, 6)
		end
		UI.label(app.hint, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -10, 0, 18),
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = icon,
		})
	end

	-- The taskbar along the bottom.
	local taskbar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, TASKBAR),
		BackgroundColor3 = Color3.fromRGB(20, 30, 24),
		BackgroundTransparency = 0.1,
		Parent = display,
	}, { UI.padding(4) })
	local buttons = UI.new("Frame", {
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Parent = taskbar,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	-- The buttons share the bar, so all five fit on a phone.
	for index, app in APPS do
		local button = UI.button(app.name, function()
			openApp(app)
		end, {
			LayoutOrder = index,
			Size = UDim2.new(1 / #APPS, -6, 1, 0),
			TextScaled = true,
			BackgroundColor3 = UI.Colors.Card,
			Parent = buttons,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = button })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = button })
		taskButtons[app] = button
		if app.badge then
			addBadge(button, 2)
		end
	end
	UI.button("Back", function()
		ComputerController.leave()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(100, 36),
		TextSize = 16,
		BackgroundColor3 = UI.Colors.Danger,
		Parent = taskbar,
	})
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
		end
	end)
end

return ComputerController
