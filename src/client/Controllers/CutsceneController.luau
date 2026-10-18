-- The "drive" between your business and a job: a little road scene built only on this player's screen,
-- with the crew's truck driving down it. Swap this out for whatever cutscene you want later;
-- the server only needs it to last about `info.duration` seconds.
-- Before it, at the business, you're in the cab: the camera sits in your seat (the truck's
-- DriverSeat attachment, or beside it for the rest of the crew) while the truck pulls out of the
-- driveway.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Net = require(Shared.Net)

local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

-- Far away from everything, so nothing in the real world shows up in the shot.
local SCENE_ORIGIN = Vector3.new(-8000, 400, 0)
local DRIVE_SPEED = 70
local FADE_TIME = 0.35
local LANE_OFFSET = 5

-- Where each seat is from the driver's: passenger, then the back seat.
local SEAT_OFFSETS = { Vector3.zero, Vector3.new(2.6, 0, 0), Vector3.new(0.4, 0, 2.4), Vector3.new(2.2, 0, 2.4) }
-- Where the driver's eyes are on a truck without a DriverSeat attachment, from its pivot.
local DEFAULT_SEAT = CFrame.new(-1.5, 4.8, -2.8)

local CutsceneController = {}

local overlay: ScreenGui
local fade: Frame
local title: TextLabel
local subtitle: TextLabel
local currentToken = nil
-- The camera's ride in the cab while the truck pulls out, until the trip starts.
local pullOut: RBXScriptConnection? = nil

local function part(parent: Instance, props)
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CastShadow = false
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(newPart :: any)[key] = value
	end
	newPart.Parent = parent
	return newPart
end

local function buildScene(truckId: string, trailerId: string?, roadLength: number)
	local folder = Instance.new("Folder")
	folder.Name = "TruckCutscene"
	local rng = Random.new(7)

	part(folder, {
		Size = Vector3.new(400, 2, roadLength + 300),
		Position = SCENE_ORIGIN + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(90, 150, 70),
		Material = Enum.Material.Grass,
	})
	part(folder, {
		Size = Vector3.new(22, 0.2, roadLength + 300),
		Position = SCENE_ORIGIN + Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(55, 55, 60),
		Material = Enum.Material.Asphalt,
	})

	local half = roadLength / 2 + 150
	for z = -half, half, 20 do
		part(folder, {
			Size = Vector3.new(0.4, 0.05, 7),
			Position = SCENE_ORIGIN + Vector3.new(0, 0.22, z),
			Color = Color3.fromRGB(240, 200, 60),
		})
	end

	-- Trees and houses along both sides of the road.
	for z = -half, half, 36 do
		for _, side in { -1, 1 } do
			local x = side * rng:NextNumber(24, 60)
			if rng:NextNumber() < 0.6 then
				local height = rng:NextNumber(6, 10)
				part(folder, {
					Size = Vector3.new(1.5, height, 1.5),
					Position = SCENE_ORIGIN + Vector3.new(x, height / 2, z),
					Color = Color3.fromRGB(100, 70, 45),
				})
				local leaves = rng:NextNumber(7, 11)
				part(folder, {
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(leaves, leaves, leaves),
					Position = SCENE_ORIGIN + Vector3.new(x, height + leaves / 3, z),
					Color = Color3.fromRGB(60, 130 + rng:NextInteger(0, 40), 50),
					Material = Enum.Material.LeafyGrass,
				})
			else
				local size = Vector3.new(rng:NextNumber(16, 24), rng:NextNumber(9, 13), rng:NextNumber(14, 20))
				part(folder, {
					Size = size,
					Position = SCENE_ORIGIN + Vector3.new(x + side * size.X / 2, size.Y / 2, z),
					Color = Color3.fromHSV(rng:NextNumber(), 0.25, 0.9),
				})
			end
		end
	end

	local truck = Assets.truck(truckId, trailerId)
	Assets.anchor(truck)
	truck.Parent = folder
	folder.Parent = workspace
	return folder, truck
end

local function tweenFade(transparency: number)
	TweenService:Create(fade, TweenInfo.new(FADE_TIME), { BackgroundTransparency = transparency }):Play()
end

local function setGameUiVisible(visible: boolean)
	UI.getScreen().Enabled = visible
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible)
end

-- Back to the normal camera, which is locked in first person (see CameraController).
local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Three camera shots: alongside the truck, in front of it, then chasing it.
local function cameraFor(truckPosition: Vector3, alpha: number): CFrame
	if alpha < 0.4 then
		return CFrame.lookAt(truckPosition + Vector3.new(26, 6, 8), truckPosition + Vector3.new(0, 2, 0))
	elseif alpha < 0.75 then
		return CFrame.lookAt(truckPosition + Vector3.new(-8, 3, -32), truckPosition + Vector3.new(0, 3, 0))
	end
	return CFrame.lookAt(truckPosition + Vector3.new(0, 11, 30), truckPosition + Vector3.new(0, 0, -20))
end

-- Sits the camera in your seat in the cab while the truck pulls out of the driveway.
local function startPullOut(info)
	local truck = info.truck
	if typeof(truck) ~= "Instance" or not truck:IsA("Model") then
		return
	end
	if pullOut then
		pullOut:Disconnect()
	end
	local seat = truck:FindFirstChild("DriverSeat", true)
	local driver = if seat and seat:IsA("Attachment")
		then truck:GetPivot():ToObjectSpace(seat.WorldCFrame)
		else DEFAULT_SEAT
	local offset = SEAT_OFFSETS[math.clamp(tonumber(info.seat) or 1, 1, #SEAT_OFFSETS)]
	local view = driver * CFrame.new(offset)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	pullOut = RunService.RenderStepped:Connect(function()
		if truck.Parent then
			camera.CFrame = truck:GetPivot() * view
		end
	end)
	-- In case the trip never comes (the job was called off), give the camera back.
	local connection = pullOut
	task.delay((tonumber(info.duration) or 3) + 1.5, function()
		if pullOut == connection and pullOut then
			pullOut:Disconnect()
			pullOut = nil
			if not currentToken then
				restoreCamera()
			end
		end
	end)
end

local function play(info)
	local token = {}
	currentToken = token
	local function stillPlaying()
		return currentToken == token
	end

	overlay.Enabled = true
	tweenFade(0)
	task.wait(FADE_TIME)
	if not stillPlaying() then
		return
	end

	-- Out of the cab, onto the road.
	if pullOut then
		pullOut:Disconnect()
		pullOut = nil
	end
	local driveTime = math.max(info.duration - FADE_TIME * 2 - 0.2, 1)
	local distance = DRIVE_SPEED * driveTime
	local scene, truck = buildScene(info.truckId, info.trailerId, distance)
	local startCFrame = CFrame.new(SCENE_ORIGIN + Vector3.new(LANE_OFFSET, 0.2, distance / 2))
	local endCFrame = CFrame.new(SCENE_ORIGIN + Vector3.new(LANE_OFFSET, 0.2, -distance / 2))
	Assets.placeOnGround(truck, startCFrame)
	local groundOffset = truck:GetPivot().Position - startCFrame.Position

	title.Text = info.title or ""
	subtitle.Text = info.subtitle or ""
	setGameUiVisible(false)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	tweenFade(1)

	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - started) / driveTime, 0, 1)
		local bounce = Vector3.new(0, math.sin(os.clock() * 18) * 0.06, 0)
		local pivot = startCFrame:Lerp(endCFrame, alpha) + groundOffset + bounce
		truck:PivotTo(pivot)
		camera.CFrame = cameraFor(pivot.Position, alpha)
	end)

	task.wait(driveTime)
	tweenFade(0)
	task.wait(FADE_TIME)
	connection:Disconnect()
	scene:Destroy()
	if not stillPlaying() then
		return
	end

	-- Give the server a moment to move our character before showing the world again.
	task.wait(0.4)
	if not stillPlaying() then
		return
	end
	title.Text = ""
	subtitle.Text = ""
	restoreCamera()
	setGameUiVisible(true)
	tweenFade(1)
	task.wait(FADE_TIME)
	if stillPlaying() then
		overlay.Enabled = false
		currentToken = nil
	end
end

function CutsceneController:Start()
	overlay = UI.new("ScreenGui", {
		Name = "Cutscene",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	fade = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = overlay,
	})
	for _, anchorY in { 0, 1 } do
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0, anchorY),
			Position = UDim2.fromScale(0, anchorY),
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = overlay,
		})
	end
	title = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.88, -36),
		Size = UDim2.new(0.8, 0, 0, 40),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		ZIndex = 3,
		Parent = overlay,
	})
	subtitle = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.88, -8),
		Size = UDim2.new(0.8, 0, 0, 26),
		TextSize = 22,
		TextColor3 = UI.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		ZIndex = 3,
		Parent = overlay,
	})

	Net.event("TravelStarted").OnClientEvent:Connect(function(info)
		task.spawn(play, info)
	end)
	Net.event("PullingOut").OnClientEvent:Connect(startPullOut)
end

return CutsceneController
