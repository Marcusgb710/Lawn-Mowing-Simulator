-- First-person arms (docs/GAME_DESIGN.md, "Camera"). Roblox hides your own character in first
-- person, so these are a pair of simple arms drawn only on your screen (parented to the camera),
-- reaching from your shoulders to whatever you're using: both hands on a mower's handlebar or a
-- barrow's handles, up a rake's shaft, on a trimmer's two handles, on a ride-on's controls,
-- around a tool you're carrying. Empty-handed they drop out of view, and they come up when you
-- take something and drop back down when you put it away.
--
-- The tool in your hands is posed for the view too, on your screen only (everyone else sees the
-- normal pose, and the work still happens just in front of you): machines and string trimmers
-- stand on the ground ahead of you the way they were modelled, rakes and shovels lean out ahead,
-- small hand tools sit low on the right. Nothing gets closer to the camera than
-- CAMERA_CLEARANCE. A model can say exactly where the hands go with Attachments named GripLeft
-- and GripRight; otherwise they go where that kind of tool is usually held.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)

local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

-- Arm sizes. Slimmer than avatar arms, which look huge this close to the camera.
local UPPER_ARM = 1.15
local FOREARM = 1.1 -- elbow to the middle of the hand
local ARM_WIDTH = 0.4
local HAND_SIZE = Vector3.new(0.4, 0.4, 0.5)
local SLEEVE_COLOR = Color3.fromRGB(70, 95, 60)
local SKIN_COLOR = Color3.fromRGB(234, 184, 146) -- until the avatar's own has loaded

-- How long the arms take to come up or drop away, in seconds.
local BLEND_TIME = 0.25
-- A tool rises into view from this far below its pose as you take it out.
local RAISE = 1.2
-- The hands sit this far either side of the middle of a handlebar.
local HANDLEBAR = 0.65
-- How close to the camera (in front of it) any part of a held tool near eye level may come, and
-- how far below the eyes "near eye level" reaches.
local CAMERA_CLEARANCE = 0.7
local EYE_LEVEL = 0.6

-- How each size class is held. Other tools are "Back" when they're worn on your back (`onBack`),
-- "Reach" when they reach the ground from your hand (string trimmers, edgers) and "Hand"
-- otherwise. Ride-ons are "Ride".
local HOLDS = {
	FloorManual = "Machine",
	FloorEngine = "Machine",
	Bay = "Machine",
	Long = "Long",
}
local REACH_DEPTH = 1.5

-- Where held tools sit, measured from the floor under you (X right, -Z ahead).
local MACHINE_AHEAD = 1.7 -- the handlebar, centred in front of you
local LONG_SIDE, LONG_AHEAD = 0.2, 1.4
local LONG_TILT_MIN, LONG_TILT_MAX = math.rad(20), math.rad(60)
local REACH_SIDE, REACH_AHEAD = 0.3, 1.1
-- Hand tools are posed from the camera instead: low and to the right, tipped down a little.
-- They follow part of the way when you look up or down.
local HAND_POSE = CFrame.new(0.62, -0.72, -1.55) * CFrame.Angles(math.rad(-12), math.rad(-6), 0)
local HAND_PITCH_FOLLOW = 0.7
-- Ride-on controls (steering wheel or lap bars), from the camera, unless the model has grips.
local RIDE_RIGHT = Vector3.new(0.5, -1, -1.45)

local SHOULDER_JOINTS = {
	Right = { { "RightUpperArm", "RightShoulder" }, { "Torso", "Right Shoulder" } },
	Left = { { "LeftUpperArm", "LeftShoulder" }, { "Torso", "Left Shoulder" } },
}

local ArmsController = {}

type Shape = {
	parts: { BasePart },
	corners: { Vector3 }, -- the corners of the tool's box, relative to the handle
	below: number, -- how far the tool reaches below the handle
	above: number, -- and above it
	far: Vector3, -- its point farthest from the handle
	gripLeft: Vector3?, -- the GripLeft / GripRight attachments, relative to the handle
	gripRight: Vector3?,
}
type Arm = { upper: BasePart, forearm: BasePart, hand: BasePart }

-- [Tool or carried Model] = its Shape
local shapes = setmetatable({}, { __mode = "k" })

local arms: Model? = nil
local armParts: { [string]: Arm } = {}
-- The weld holding your tool, while it's posed for the view, and what it was before.
local posed: { weld: Weld, c0: CFrame }? = nil

-- What's in your hands, how far the hands have come since it changed (0-1), where they started
-- from and where they're shown, relative to the floor under you.
local heldKey: Instance? = nil
local blend = 1
local fromRight: Vector3? = nil
local fromLeft: Vector3? = nil
local shownRight: Vector3? = nil
local shownLeft: Vector3? = nil

local function ease(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

local function shapeOf(container: Instance, handle: BasePart): Shape
	local cached = shapes[container]
	if cached then
		return cached
	end
	local shape: Shape = { parts = {}, corners = {}, below = 0, above = 0, far = Vector3.zero }
	local frame = handle.CFrame
	local low, high = Vector3.zero, Vector3.zero
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(shape.parts, descendant)
			if descendant ~= handle then
				local half = descendant.Size / 2
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							local world = descendant.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
							local corner = frame:PointToObjectSpace(world)
							low, high = low:Min(corner), high:Max(corner)
							if corner.Magnitude > shape.far.Magnitude then
								shape.far = corner
							end
						end
					end
				end
			end
		elseif descendant:IsA("Attachment") then
			if descendant.Name == "GripLeft" then
				shape.gripLeft = frame:PointToObjectSpace(descendant.WorldPosition)
			elseif descendant.Name == "GripRight" then
				shape.gripRight = frame:PointToObjectSpace(descendant.WorldPosition)
			end
		end
	end
	-- Only the corners of the whole tool's box are kept, so posing it every frame stays cheap
	-- however detailed the model is.
	for _, x in { low.X, high.X } do
		for _, y in { low.Y, high.Y } do
			for _, z in { low.Z, high.Z } do
				table.insert(shape.corners, Vector3.new(x, y, z))
			end
		end
	end
	shape.below, shape.above = -low.Y, high.Y
	shapes[container] = shape
	return shape
end

local function itemOf(id: unknown)
	return if typeof(id) == "string" then Tools.get(id) else nil
end

local function holdOf(item, shape: Shape): string
	if item and item.onBack then
		return "Back"
	end
	local hold = item and HOLDS[item.sizeClass]
	return hold or (if shape.below >= REACH_DEPTH then "Reach" else "Hand")
end

-- The floor under you, facing the way you face.
local function bodyFrame(character: Model, root: BasePart): CFrame
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local legs = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local floor = root.Position - Vector3.new(0, root.Size.Y / 2 + legs, 0)
	return CFrame.lookAt(floor, floor + flat)
end

local function shoulderOf(character: Model, side: string): Vector3?
	for _, path in SHOULDER_JOINTS[side] do
		local part = character:FindFirstChild(path[1])
		local joint = part and part:FindFirstChild(path[2])
		if joint and joint:IsA("Motor6D") and joint.Part0 then
			return (joint.Part0.CFrame * joint.C0).Position
		end
	end
	return nil
end

-- Moves a pose (the handle's frame, from the floor under you) ahead until no part of the tool
-- near eye height is closer to the camera than CAMERA_CLEARANCE.
local function clearCamera(shape: Shape, pose: CFrame, camera: Vector3): CFrame
	local push = 0
	for _, corner in shape.corners do
		local point = pose * corner
		if point.Y > camera.Y - EYE_LEVEL then
			push = math.max(push, point.Z - (camera.Z - CAMERA_CLEARANCE))
		end
	end
	return CFrame.new(0, 0, -math.min(push, 3)) * pose
end

-- Rakes, shovels and forks lean forward with their head on the ground ahead, just far enough
-- that the top of the shaft stays below your eyes.
local function longPose(shape: Shape, camera: Vector3): CFrame
	local length = math.max(shape.below + shape.above, 0.1)
	local tilt = math.acos(math.clamp((camera.Y - EYE_LEVEL - 0.2) / length, -1, 1))
	local lean = CFrame.Angles(math.clamp(tilt, LONG_TILT_MIN, LONG_TILT_MAX), 0, 0)
	local lowest = 0
	for _, corner in shape.corners do
		lowest = math.min(lowest, (lean * corner).Y)
	end
	return clearCamera(shape, CFrame.new(LONG_SIDE, 0.05 - lowest, -LONG_AHEAD) * lean, camera)
end

-- Small tools, from the camera: low on the right, following your view part of the way.
local function handPose(shape: Shape, body: CFrame, view: CFrame): CFrame
	local pitch = math.asin(math.clamp(view.LookVector.Y, -1, 1))
	local frame = CFrame.new(view.Position)
		* body.Rotation
		* CFrame.Angles(math.clamp(pitch, -0.95, 0.5) * HAND_PITCH_FOLLOW, 0, 0)
	local push = 0
	for _, corner in shape.corners do
		push = math.max(push, (HAND_POSE * corner).Z + CAMERA_CLEARANCE)
	end
	return frame * CFrame.new(0, 0, -math.min(push, 2)) * HAND_POSE
end

local function restorePose()
	if posed then
		if posed.weld.Parent then
			posed.weld.C0 = posed.c0
		end
		posed = nil
	end
end

-- Moves the RightGrip weld holding `handle` so the handle sits at `pose`, on this screen only.
local function setPose(character: Model, handle: BasePart, pose: CFrame)
	local weld = if posed and posed.weld.Parent and posed.weld.Part1 == handle then posed.weld else nil
	if not weld then
		restorePose()
		for _, name in { "RightHand", "Right Arm" } do
			local hand = character:FindFirstChild(name)
			local grip = hand and hand:FindFirstChild("RightGrip")
			if grip and grip:IsA("Weld") and grip.Part1 == handle then
				weld = grip
				posed = { weld = grip, c0 = grip.C0 }
				break
			end
		end
	end
	if weld and weld.Part0 then
		weld.C0 = weld.Part0.CFrame:Inverse() * pose * weld.C1
	end
end

-- Where both hands go on a tool held at `pose` (world positions: right, left).
local function handsOn(shape: Shape, hold: string, pose: CFrame, body: CFrame): (Vector3, Vector3)
	local right, left
	if hold == "Machine" then
		right = pose.Position + body.RightVector * HANDLEBAR
		left = pose.Position - body.RightVector * HANDLEBAR
	elseif hold == "Long" then
		-- The other hand further up the shaft, or down it when you hold the top (a D-handle).
		right = pose.Position
		left = if shape.above >= 1
			then pose * Vector3.new(0, math.min(1.5, shape.above - 0.2), 0)
			else pose * Vector3.new(0, -0.75, 0)
	elseif hold == "Reach" then
		-- The other hand on the front handle, which sits up on the shaft a little way ahead.
		local ahead = Vector3.new(shape.far.X, 0, shape.far.Z)
		ahead = if ahead.Magnitude > 1e-3 then ahead.Unit * 0.9 else Vector3.new(0, 0, -0.9)
		right = pose.Position
		left = pose * (ahead + Vector3.new(-0.15, 0.15, 0))
	elseif hold == "Back" then
		-- The other hand further along the wand or tube.
		right = pose.Position
		left = pose.Position + body.LookVector * 0.9 - body.RightVector * 0.2 - Vector3.new(0, 0.1, 0)
	else
		-- One-handed: the other hand stays ready beside it.
		right = pose.Position
		left = pose.Position - body.RightVector * 0.55 - body.LookVector * 0.2 - Vector3.new(0, 0.2, 0)
	end
	return if shape.gripRight then pose * shape.gripRight else right,
		if shape.gripLeft then pose * shape.gripLeft else left
end

-- The tool or carried model in your hands, if any.
local function heldThing(character: Model): Instance?
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		return tool
	end
	local carried = character:FindFirstChild("CarriedTool")
	return if carried and carried:IsA("Model") and carried.PrimaryPart then carried else nil
end

-- Where your hands go on what you're holding (right, left), posing an equipped tool for the
-- view. `raise` (0-1) is how far a tool you just took out has come up into view.
local function grips(held: Instance, character: Model, body: CFrame, view: CFrame, raise: number): (Vector3?, Vector3?)
	local camera = body:PointToObjectSpace(view.Position)
	if held:IsA("Tool") then
		if held:GetAttribute("Ride") == true then
			local base = held:FindFirstChild("RideRoot")
			if not (base and base:IsA("BasePart")) then
				return nil, nil
			end
			local shape = shapeOf(held, base)
			local right = if shape.gripRight then base.CFrame * shape.gripRight else body * (camera + RIDE_RIGHT)
			local left = if shape.gripLeft
				then base.CFrame * shape.gripLeft
				else body * (camera + RIDE_RIGHT * Vector3.new(-1, 1, 1))
			return right, left
		end

		local handle = held:FindFirstChild("Handle")
		if not (handle and handle:IsA("BasePart")) then
			return nil, nil
		end
		local shape = shapeOf(held, handle)
		local hold = holdOf(itemOf(held:GetAttribute("ItemId")), shape)
		if hold == "Back" then
			-- Modelled as worn (the pack behind your hand, the wand ahead), so the normal hold works.
			restorePose()
			return handsOn(shape, hold, handle.CFrame, body)
		end
		local pose
		if hold == "Machine" then
			pose = body * clearCamera(shape, CFrame.new(0, shape.below + 0.02, -MACHINE_AHEAD), camera)
		elseif hold == "Long" then
			pose = body * longPose(shape, camera)
		elseif hold == "Reach" then
			pose = body * clearCamera(shape, CFrame.new(REACH_SIDE, shape.below + 0.05, -REACH_AHEAD), camera)
		else
			pose = handPose(shape, body, view)
		end
		-- Machines stay on the ground; everything else comes up into view.
		if hold ~= "Machine" then
			pose -= Vector3.new(0, (1 - raise) * RAISE, 0)
		end
		setPose(character, handle, pose)
		return handsOn(shape, hold, pose, body)
	end

	-- A tool you're carrying around the business: welded in front of you by the server. Roblox
	-- hides it with the rest of your character in first person, so show it again.
	local model = held :: Model
	local handle = model.PrimaryPart :: BasePart
	local shape = shapeOf(model, handle)
	for _, part in shape.parts do
		if part.LocalTransparencyModifier ~= 0 then
			part.LocalTransparencyModifier = 0
		end
	end
	return handsOn(shape, holdOf(itemOf(player:GetAttribute("Carrying")), shape), handle.CFrame, body)
end

-- Two-bone arm from the shoulder to the hand, the elbow bending down and out.
local function placeArm(arm: Arm, shoulder: Vector3, hand: Vector3, outward: Vector3, body: CFrame)
	local reach = (UPPER_ARM + FOREARM) * 0.999
	local offset = hand - shoulder
	local distance = offset.Magnitude
	local direction = if distance > 1e-3 then offset / distance else -Vector3.yAxis
	-- Out of reach: bend the arm as if the shoulder came forward, and stretch the upper arm
	-- (mostly off screen) back to it, rather than let go of the handle.
	local root = shoulder
	if distance > reach then
		root = hand - direction * reach
		distance = reach
	end
	distance = math.max(distance, math.abs(UPPER_ARM - FOREARM) + 0.05)
	local cosine = (UPPER_ARM ^ 2 + distance ^ 2 - FOREARM ^ 2) / (2 * UPPER_ARM * distance)
	local angle = math.acos(math.clamp(cosine, -1, 1))
	local pole = outward * 0.6 - Vector3.yAxis - body.LookVector * 0.2
	local bend = pole - direction * pole:Dot(direction)
	bend = if bend.Magnitude > 1e-3 then bend.Unit else outward
	local elbow = root + direction * (UPPER_ARM * math.cos(angle)) + bend * (UPPER_ARM * math.sin(angle))
	local upper = (elbow - shoulder).Magnitude
	if math.abs(arm.upper.Size.Z - upper) > 0.01 then
		arm.upper.Size = Vector3.new(ARM_WIDTH, ARM_WIDTH, upper)
	end
	arm.upper.CFrame = CFrame.lookAt((shoulder + elbow) / 2, elbow)
	arm.forearm.CFrame = CFrame.lookAt((elbow + hand) / 2, hand)
	arm.hand.CFrame = CFrame.lookAt(hand, hand + (hand - elbow))
end

local function newPart(model: Model, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function buildArms()
	if arms then
		arms:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "FirstPersonArms"
	for _, side in { "Right", "Left" } do
		armParts[side] = {
			upper = newPart(model, side .. "UpperArm", Vector3.new(ARM_WIDTH, ARM_WIDTH, UPPER_ARM), SLEEVE_COLOR),
			forearm = newPart(
				model,
				side .. "Forearm",
				Vector3.new(1, 1, 0) * ARM_WIDTH * 0.9 + Vector3.zAxis * FOREARM,
				SKIN_COLOR
			),
			hand = newPart(model, side .. "Hand", HAND_SIZE, SKIN_COLOR),
		}
	end
	arms = model
end

-- The avatar's skin color, which loads a moment after the character.
local function recolor(character: Model)
	local part = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local skin = if part and part:IsA("BasePart") then part.Color else SKIN_COLOR
	for _, arm in armParts do
		arm.forearm.Color = skin
		arm.hand.Color = skin
	end
end

local function setVisible(visible: boolean)
	local parent = if visible then workspace.CurrentCamera else nil
	if arms and arms.Parent ~= parent then
		arms.Parent = parent
	end
end

local function reset()
	restorePose()
	setVisible(false)
	heldKey, fromRight, fromLeft, shownRight, shownLeft = nil, nil, nil, nil, nil
	blend = 1
end

local function update(deltaTime: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (character and root and root:IsA("BasePart") and camera and CameraController.isFirstPerson()) then
		reset()
		return
	end

	local body = bodyFrame(character, root)
	local rightShoulder = shoulderOf(character, "Right") or body * Vector3.new(0.95, 3.5, 0)
	local leftShoulder = shoulderOf(character, "Left") or body * Vector3.new(-0.95, 3.5, 0)
	local hang = Vector3.yAxis * ((UPPER_ARM + FOREARM) * 0.95) - body.LookVector * 0.3
	local restRight = body:PointToObjectSpace(rightShoulder - hang)
	local restLeft = body:PointToObjectSpace(leftShoulder - hang)

	local held = heldThing(character)
	if held ~= heldKey then
		-- Something new in your hands (or nothing): the hands move over from where they are.
		heldKey = held
		blend = 0
		fromRight, fromLeft = shownRight or restRight, shownLeft or restLeft
		recolor(character)
	end
	blend = math.min(1, blend + deltaTime / BLEND_TIME)
	local alpha = ease(blend)

	local right, left = nil, nil
	if held then
		right, left = grips(held, character, body, camera.CFrame, alpha)
	end
	if not (held and held:IsA("Tool")) then
		restorePose()
	end
	local nextRight = if right then body:PointToObjectSpace(right) else restRight
	local nextLeft = if left then body:PointToObjectSpace(left) else restLeft
	shownRight = (fromRight or restRight):Lerp(nextRight, alpha)
	shownLeft = (fromLeft or restLeft):Lerp(nextLeft, alpha)

	-- Empty hands rest out of view; stop drawing them once they're down.
	if not right and blend >= 1 then
		setVisible(false)
		return
	end
	setVisible(true)
	placeArm(armParts.Right, rightShoulder, body * (shownRight :: Vector3), body.RightVector, body)
	placeArm(armParts.Left, leftShoulder, body * (shownLeft :: Vector3), -body.RightVector, body)
end

function ArmsController:Start()
	buildArms()
	player.CharacterAdded:Connect(reset)
	-- After the camera (and Roblox hiding your character) for this frame.
	RunService:BindToRenderStep("FirstPersonArms", Enum.RenderPriority.Camera.Value + 1, update)
end

return ArmsController
