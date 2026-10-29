-- First person (docs/GAME_DESIGN.md, "Camera"). The camera is locked in first person
-- (StarterPlayer.CameraMode, set again here), except during the drive cutscene, which runs its
-- own camera and hands it back after. This also:
--   * frees the mouse while a menu is open, or while you hold Left Alt: in first person
--     it's locked to the middle of the screen, so menu buttons couldn't be clicked otherwise
--   * draws the dot in the middle of the screen that you aim with (InteractController says when
--     it's on something you can use, or something that won't work there), and around it the hold
--     ring that fills while you hold E to work on a tool
--   * bobs the camera a little as you walk and shakes it slightly while a gas engine you're using
--     is running (harder while a mower is cutting thick grass), unless camera motion is switched
--     off (GameConfig.Camera, or the player's "Camera motion" switch in the Guide, or V)
--   * turns the camera the way the server says to face after it moves you (back at the shop after
--     a respawn or a job, at the house on a job, at a new crew's shop): first person would keep
--     looking wherever it was, and turn your character back to match
-- Your arms are drawn by ArmsController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local GuiLayout = require(Shared.GuiLayout)
local Maintenance = require(Shared.Config.Maintenance)
local Signal = require(Shared.Signal)
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer
local Settings = GameConfig.Camera

-- The camera counts as first person while it's this close to your head.
local FIRST_PERSON_RANGE = 1.5
-- Head bob: how far along the bob cycle each stud walked moves (one cycle is two steps), how far
-- the camera sways side to side and how far it dips at each step.
local BOB_RATE = 0.45
local BOB_SWAY = 0.05
local BOB_DIP = 0.08
-- Engine shake: how far the camera shakes on foot and riding, and how fast.
local SHAKE_ON_FOOT = 0.012
local SHAKE_RIDING = 0.025
local SHAKE_SPEED = 22
-- The plain dot's size, while the dot's art isn't uploaded (with it, it's UiLayout's Reticle).
local PLAIN_DOT = 6

local CameraController = {}

-- Fired when camera motion is switched on or off.
CameraController.MotionChanged = Signal.new()

local motionOn = true
local altHeld = false
local cursorButton: TextButton
local crosshair: ScreenGui
local bobPhase = 0
local bobAmount = 0
-- The dot, and what it's on: "Idle", "Active" (something you can use) or "Blocked".
local reticle: GuiObject
local reticleState = "Idle"
local RETICLE_ART = { Idle = "Reticle", Active = "Reticle_Active", Blocked = "Reticle_Blocked" }

function CameraController.isFirstPerson(): boolean
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not (camera and camera.CameraType == Enum.CameraType.Custom and head and head:IsA("BasePart")) then
		return false
	end
	return (camera.CFrame.Position - head.Position).Magnitude < FIRST_PERSON_RANGE
end

-- Whether the game has any camera motion at all (GameConfig.Camera), for the switch to show.
function CameraController.hasMotion(): boolean
	return Settings.HeadBob or Settings.EngineShake
end

function CameraController.isMotionOn(): boolean
	return motionOn
end

function CameraController.setMotion(on: boolean)
	if CameraController.hasMotion() and motionOn ~= on then
		motionOn = on
		CameraController.MotionChanged:Fire(on)
	end
end

-- What the dot is on: "Idle", "Active" (something you can use) or "Blocked" (it won't work there).
-- With its art, each has its own dot; plain, the dot turns green or red.
function CameraController.setReticle(state: string)
	if state == reticleState or not reticle then
		return
	end
	reticleState = state
	if reticle:IsA("ImageLabel") then
		local image = Art.kit(RETICLE_ART[state] or "Reticle")
		reticle.Image = if image ~= "" then image else Art.kit("Reticle")
	else
		reticle.BackgroundColor3 = if state == "Active"
			then UI.Colors.Accent
			elseif state == "Blocked" then UI.Colors.Danger
			else Color3.new(1, 1, 1)
	end
end

-- The hold ring: while you hold E to work on a tool (the server sets MaintainingUntil), it fills
-- clockwise round the dot until the work's done. Only with its art: plain, the HUD's "Working on
-- it... 3s" says the same.
local function buildHoldRing()
	local track, fill = Art.kit("HoldRing"), Art.kit("HoldRing_Fill")
	if track == "" or fill == "" then
		return
	end
	local ring = UI.new("Frame", {
		Name = "HoldRing",
		BackgroundTransparency = 1,
		Visible = false,
		Parent = crosshair,
	})
	UI.keepPlaced(ring, "HoldRing")
	UI.new("ImageLabel", { Image = track, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = ring })
	-- Each half shows the fill through a gradient that's opaque on one side of a line through the
	-- middle: turning the line sweeps the fill round (GuiLayout.ring).
	local edge = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	local gradients = {}
	for index, x in { 0.5, 0 } do
		local half = UI.new("Frame", {
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = ring,
		})
		local image = UI.new("ImageLabel", {
			Image = fill,
			Position = UDim2.fromScale(-x * 2, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundTransparency = 1,
			Parent = half,
		})
		gradients[index] = UI.new("UIGradient", { Transparency = edge, Parent = image })
	end
	local filling: RBXScriptConnection? = nil
	local function update()
		if filling then
			filling:Disconnect()
			filling = nil
		end
		local untilTime = player:GetAttribute("MaintainingUntil")
		ring.Visible = typeof(untilTime) == "number"
		if typeof(untilTime) ~= "number" then
			return
		end
		local from = workspace:GetServerTimeNow()
		local length = math.max(0.05, untilTime - from)
		filling = RunService.RenderStepped:Connect(function()
			local right, left = GuiLayout.ring((workspace:GetServerTimeNow() - from) / length)
			gradients[1].Rotation = right
			gradients[2].Rotation = left
		end)
	end
	player:GetAttributeChangedSignal("MaintainingUntil"):Connect(update)
	update()
end

-- A visible Modal button frees the mouse in first person; it's only shown while it's needed.
local function updateCursor()
	cursorButton.Visible = altHeld or UI.needsCursor()
end

-- The bob while walking plus the shake of a running engine, as Humanoid.CameraOffset.
local function updateMotion(deltaTime: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and root and root:IsA("BasePart")) then
		return
	end

	local offset = Vector3.zero
	if motionOn and CameraController.isFirstPerson() then
		local tool = character:FindFirstChildOfClass("Tool")
		local riding = tool ~= nil and tool:GetAttribute("Ride") == true
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local walking = Settings.HeadBob
			and not riding
			and humanoid.MoveDirection.Magnitude > 0.1
			and humanoid.FloorMaterial ~= Enum.Material.Air
		local wanted = if walking then math.clamp(speed / GameConfig.DefaultWalkSpeed, 0, 1.2) else 0
		bobAmount += (wanted - bobAmount) * math.min(deltaTime * 8, 1)
		bobPhase = (bobPhase + speed * BOB_RATE * deltaTime) % (2 * math.pi)
		local sway = math.sin(bobPhase) * BOB_SWAY
		local dip = (math.abs(math.cos(bobPhase)) - 0.5) * BOB_DIP
		offset = Vector3.new(sway, dip, 0) * bobAmount

		local item = tool and Tools.get(tool:GetAttribute("ItemId"))
		if
			Settings.EngineShake
			and tool
			and item
			and tool:GetAttribute("Working") == true
			and Maintenance.burnsFuel(item)
		then
			local time = os.clock() * SHAKE_SPEED
			local strength = if riding then SHAKE_RIDING else SHAKE_ON_FOOT
			-- The engine labours harder in thick grass.
			if tool:GetAttribute("Cutting") == true then
				strength *= GameConfig.CuttingShake
			end
			offset += Vector3.new(math.noise(time, 0.5), math.noise(0.5, time), 0) * 2 * strength
		end
	end
	if humanoid.CameraOffset ~= offset then
		humanoid.CameraOffset = offset
	end
end

-- Whether the title card is still up. It turns the camera for the move at join itself.
local function titleCardUp(): boolean
	if player:GetAttribute("TitleCardDone") == true then
		return false
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	return playerGui ~= nil and playerGui:FindFirstChild("TitleCard") ~= nil
end

-- Each time the server moves you, it says which way you should face (ArrivedFacing) and counts the
-- move (Arrivals; see setArrivedFacing in JobService). FacedArrival, on this screen only, is the
-- move the camera was last turned for, here or by the title card. The camera turns to face that
-- way, looking level, once it's back in first person on your character with the game's screen
-- showing. So not while the title card is up, or while the drive cutscene or a dialogue scene has
-- the camera (it turns as they hand it back), or before your new character's in.
-- This runs just after the default camera's update, which carries on next frame from wherever the
-- camera looks. On the frame a new character arrives, that update turns the camera the way the
-- character faces, so turning before it wouldn't stick.
local function faceArrival()
	local arrivals = player:GetAttribute("Arrivals")
	local faced = player:GetAttribute("FacedArrival")
	if typeof(arrivals) ~= "number" or (typeof(faced) == "number" and faced >= arrivals) then
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local facing = player:GetAttribute("ArrivedFacing")
	if
		not (camera and humanoid and typeof(facing) == "Vector3")
		or camera.CameraSubject ~= humanoid
		or not CameraController.isFirstPerson()
		or not UI.getScreen().Enabled
		or titleCardUp()
	then
		return
	end
	local level = Vector3.new(facing.X, 0, facing.Z)
	if level.Magnitude > 0.01 then
		local from = camera.CFrame.Position
		camera.CFrame = CFrame.lookAt(from, from + level)
	end
	player:SetAttribute("FacedArrival", arrivals)
end

local function setUpCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = Settings.FieldOfView
	end
end

function CameraController:Start()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	setUpCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(setUpCamera)
	motionOn = CameraController.hasMotion()

	cursorButton = UI.new("TextButton", {
		Name = "FreeCursor",
		Modal = true,
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Size = UDim2.fromOffset(1, 1),
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.CursorChanged:Connect(updateCursor)

	crosshair = UI.new("ScreenGui", {
		Name = "Crosshair",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local dot = Art.kit("Reticle")
	if dot ~= "" then
		reticle = UI.new("ImageLabel", {
			Name = "Dot",
			Image = dot,
			BackgroundTransparency = 1,
			Parent = crosshair,
		})
		UI.place(reticle, "Reticle")
	else
		reticle = UI.new("Frame", {
			Name = "Dot",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.15,
			Parent = crosshair,
		}, { UI.corner(3), UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5 }) })
		UI.place(reticle, "Reticle")
		reticle.Size = UDim2.fromOffset(PLAIN_DOT, PLAIN_DOT)
	end
	buildHoldRing()

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			altHeld = true
			updateCursor()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			altHeld = false
			updateCursor()
		end
	end)
	-- Alt-tabbing away never sends the key release.
	UserInputService.WindowFocusReleased:Connect(function()
		altHeld = false
		updateCursor()
	end)

	-- Before the camera moves, so it picks up this frame's offset.
	RunService:BindToRenderStep("CameraMotion", Enum.RenderPriority.Camera.Value - 1, updateMotion)
	-- Just after it moves (see faceArrival).
	RunService:BindToRenderStep("FaceArrival", Enum.RenderPriority.Camera.Value + 1, faceArrival)
	RunService.RenderStepped:Connect(function()
		-- The game's own screen is switched off during the cutscene, and the dot goes with it.
		crosshair.Enabled = UI.getScreen().Enabled and not cursorButton.Visible and CameraController.isFirstPerson()
	end)
end

return CameraController
