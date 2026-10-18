-- The job computer in your shop (docs/GAME_DESIGN.md, "The shop as the hub"). Look at the desk
-- and press E: you step up to it, the camera eases in to the screen and the desktop opens, with
-- its apps:
--   Jobs      today's jobs, hints only (anyone can look; only the crew leader can take one)
--   Orders    tools and supplies, delivered in a box to the shop, and selling
--   Business  building upgrades, trucks and trailers
--   Crew      inviting and managing your crew
-- The apps are the game's usual menus, shown inside the monitor. Back, or walking away, eases the
-- camera back to first person. The desk's ScreenView attachment is where the camera goes and
-- UseSpot is where you stand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local ShopController = require(script.Parent.ShopController)

local player = Players.LocalPlayer

-- How long the camera takes to ease in and out.
local EASE_TIME = 0.6
-- Narrower view at the screen, so the monitor fills it.
local SCREEN_FOV = 50
-- Walking this far from the desk (or starting to walk) puts the computer away.
local WALK_AWAY = 3
local WALK_GRACE = 0.5

local APPS = {
	{
		name = "Jobs",
		hint = "Today's jobs",
		open = function()
			UI.open("Jobs")
		end,
	},
	{
		name = "Orders",
		hint = "Tools and supplies",
		open = function()
			ShopController.openApp("Orders")
		end,
	},
	{
		name = "Business",
		hint = "Building, truck, trailer",
		open = function()
			ShopController.openApp("Business")
		end,
	},
	{
		name = "Crew",
		hint = "Your crew",
		open = function()
			UI.open("Crew")
		end,
	},
}

local ComputerController = {}

local screen: ScreenGui
local appArea: Frame
local desktop: Frame
local using: { desk: Model, spot: Vector3, since: number }? = nil

local function ease(): TweenInfo
	return TweenInfo.new(EASE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

function ComputerController.isUsing(): boolean
	return using ~= nil
end

-- Puts the computer away. `instantly` skips easing the camera back (the cutscene takes it).
function ComputerController.leave(instantly: boolean?)
	if not using then
		return
	end
	using = nil
	UI.closeAll()
	UI.setHost(nil)
	screen.Enabled = false
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local function backToFirstPerson()
		if camera.CameraType == Enum.CameraType.Scriptable and not using then
			camera.CameraType = Enum.CameraType.Custom
		end
		camera.FieldOfView = GameConfig.Camera.FieldOfView
	end
	if instantly or not (head and head:IsA("BasePart")) then
		backToFirstPerson()
		return
	end
	local back = TweenService:Create(camera, ease(), {
		CFrame = head.CFrame,
		FieldOfView = GameConfig.Camera.FieldOfView,
	})
	back.Completed:Once(backToFirstPerson)
	back:Play()
end

function ComputerController.use(desk: Model)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local spot = desk:FindFirstChild("UseSpot", true)
	local view = desk:FindFirstChild("ScreenView", true)
	if not (root and root:IsA("BasePart") and humanoid and spot and spot:IsA("Attachment")) then
		return
	end
	if using then
		return
	end

	-- Step up to the desk, facing it.
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local stand = spot.WorldCFrame + Vector3.new(0, legs + root.Size.Y / 2, 0)
	character:PivotTo(stand)
	using = { desk = desk, spot = stand.Position, since = os.clock() }

	local camera = workspace.CurrentCamera
	if view and view:IsA("Attachment") then
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(camera, ease(), { CFrame = view.WorldCFrame, FieldOfView = SCREEN_FOV }):Play()
	end
	UI.closeAll()
	UI.setHost(appArea)
	screen.Enabled = true
	desktop.Visible = true
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
		Size = UDim2.fromScale(0.96, 0.92),
		BackgroundColor3 = Color3.fromRGB(22, 22, 26),
		Parent = screen,
	}, { UI.corner(14), UI.new("UISizeConstraint", { MaxSize = Vector2.new(1000, 640) }) })
	local display = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(34, 70, 50),
		ClipsDescendants = true,
		Parent = bezel,
	}, { UI.corner(6) })
	appArea = UI.new("Frame", {
		Name = "Apps",
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Parent = display,
	})

	-- The desktop, under the apps: one big icon per app.
	desktop = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.9, 0, 0, 130),
		BackgroundTransparency = 1,
		Parent = display,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 120),
			CellPadding = UDim2.fromOffset(16, 16),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, app in APPS do
		local icon = UI.button(app.name, app.open, {
			LayoutOrder = index,
			TextSize = 24,
			BackgroundColor3 = UI.Colors.Panel,
			Parent = desktop,
		})
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
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(20, 30, 24),
		BackgroundTransparency = 0.1,
		Parent = display,
	}, { UI.padding(6) })
	local buttons = UI.new("Frame", {
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Parent = taskbar,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	for index, app in APPS do
		UI.button(app.name, app.open, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(96, 36),
			TextSize = 16,
			BackgroundColor3 = UI.Colors.Card,
			Parent = buttons,
		})
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
	end)
	-- Walking away, dying or heading off on a job puts it away.
	RunService.Heartbeat:Connect(function()
		local current = using
		if not current then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and current.desk.Parent) then
			ComputerController.leave(true)
			return
		end
		local wandered = (root.Position - current.spot).Magnitude > WALK_AWAY
		local walking = humanoid.MoveDirection.Magnitude > 0.5 and os.clock() - current.since > WALK_GRACE
		if wandered or walking then
			ComputerController.leave()
		end
	end)
	Net.event("TravelStarted").OnClientEvent:Connect(function()
		ComputerController.leave(true)
	end)
	ClientState.Changed:Connect(function(key)
		-- A job taken: off to load the truck.
		if key == "job" and using and ClientState.job and ClientState.job.state == "Traveling" then
			ComputerController.leave(true)
		end
	end)
end

return ComputerController
