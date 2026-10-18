-- Makes tools look alive on everyone's screen: wheels roll as the player moves, and mower blades
-- and trimmer spools spin while the tool is working. Also sits you down on riding mowers.
--
-- Kit tools get a Motor6D with a "Spin" attribute on each moving part (see Assets.toTool), and the
-- server sets a "Working" attribute on the tool (see ToolService).
--
-- Tools also show how they're doing (docs/GAME_DESIGN.md, "Hands-on maintenance"), held or set
-- down to be worked on: an engine low on fuel sputters with puffs of smoke (a wrecked one just
-- smokes), soft tires sag and flat ones squash, and a trimmer spool that's running out of line
-- shows bare. The server copies the condition onto them as attributes (Fuel, Pressure, Flat,
-- Line, Broken).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maintenance = require(Shared.Config.Maintenance)
local Service = require(Shared.Service)

local player = Players.LocalPlayer

-- Radians per second.
local SPIN_SPEEDS = {
	Rotor = 45,
	Spool = 60,
}

-- How squashed a tire looks: soft, then flat (share of its height).
local SOFT_SQUASH, FLAT_SQUASH = 0.9, 0.62
-- Seconds between puffs of smoke from an engine low on fuel, and how long each sputter lasts.
local PUFF_EVERY = { 0.8, 2.2 }
local SPUTTER_TIME = 0.25
local BARE_SPOOL = Color3.fromRGB(120, 120, 120)

local ToolFxController = {}

-- [Tool or Model] = { wheels, spools, smoke, nextPuff, sputterUntil }
local wear = setmetatable({}, { __mode = "k" })
local rng = Random.new()

-- [Tool] = { { motor = Motor6D, spin = string, radius = number, angle = number } }
local spinners = setmetatable({}, { __mode = "k" })
local sitTrack: AnimationTrack? = nil

local function motorsOf(tool: Tool)
	local cached = spinners[tool]
	if cached then
		return cached
	end
	local motors = {}
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("Motor6D") and typeof(descendant:GetAttribute("Spin")) == "string" then
			local part = descendant.Part1
			table.insert(motors, {
				motor = descendant,
				spin = descendant:GetAttribute("Spin"),
				radius = if part then math.max(part.Size.Y / 2, 0.1) else 1,
				angle = 0,
			})
		end
	end
	spinners[tool] = motors
	return motors
end

-- The parts of a tool that show its wear, found once.
local function wearOf(container: Instance)
	local known = wear[container]
	if known then
		return known
	end
	known = { wheels = {}, spools = {}, nextPuff = 0, sputterUntil = 0, smoke = nil }
	for _, part in container:GetDescendants() do
		if part:IsA("BasePart") then
			local kind = Service.partKind(part.Name)
			if kind == "Wheel" then
				table.insert(known.wheels, { part = part, size = part.Size })
			elseif kind == "Spool" then
				table.insert(known.spools, { part = part, color = part.Color })
			end
		end
	end
	local handle = container:FindFirstChild("Handle") or container:FindFirstChildWhichIsA("BasePart", true)
	if handle and handle:IsA("BasePart") then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "WearSmoke"
		smoke.Color = ColorSequence.new(Color3.fromRGB(70, 70, 70), Color3.fromRGB(150, 150, 150))
		smoke.Size = NumberSequence.new(0.4, 1.4)
		smoke.Transparency = NumberSequence.new(0.3, 1)
		smoke.Lifetime = NumberRange.new(0.8, 1.4)
		smoke.Speed = NumberRange.new(1, 2.5)
		smoke.SpreadAngle = Vector2.new(25, 25)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Rate = 0
		smoke.Parent = handle
		known.smoke = smoke
	end
	wear[container] = known
	return known
end

-- Shows a tool's wear. Returns whether its engine is sputtering right now.
local function showWear(container: Instance, working: boolean, now: number): boolean
	local known = wearOf(container)
	local flat = container:GetAttribute("Flat") == true
	local pressure = container:GetAttribute("Pressure")
	local squash = if flat
		then FLAT_SQUASH
		elseif typeof(pressure) == "number" and pressure < Maintenance.LowPressure then SOFT_SQUASH
		else 1
	for _, wheel in known.wheels do
		local size = wheel.size * Vector3.new(1, squash, 1)
		if wheel.part.Size ~= size then
			wheel.part.Size = size
		end
	end
	local line = container:GetAttribute("Line")
	for _, spool in known.spools do
		local color = if typeof(line) == "number"
			then BARE_SPOOL:Lerp(spool.color, math.clamp(line, 0, 1))
			else spool.color
		if spool.part.Color ~= color then
			spool.part.Color = color
		end
	end
	local smoke = known.smoke
	if not smoke then
		return false
	end
	local broken = container:GetAttribute("Broken") == true
	smoke.Rate = if broken then 6 else 0
	local fuel = container:GetAttribute("Fuel")
	local low = typeof(fuel) == "number" and fuel < Maintenance.LowFuel
	if working and low and now >= known.nextPuff then
		known.nextPuff = now + rng:NextNumber(PUFF_EVERY[1], PUFF_EVERY[2])
		known.sputterUntil = now + SPUTTER_TIME
		smoke:Emit(5)
	end
	return now < known.sputterUntil
end

local function spinTool(tool: Tool, root: BasePart, deltaTime: number)
	local forwardSpeed = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	-- A sputtering engine catches for a moment before it goes again.
	local working = tool:GetAttribute("Working") == true
		and not showWear(tool, tool:GetAttribute("Working") == true, os.clock())
	for _, entry in motorsOf(tool) do
		if entry.spin == "Wheel" then
			-- Rolling forward turns the top of the wheel forward (-Z), which is a negative turn around X.
			entry.angle -= forwardSpeed / entry.radius * deltaTime
			entry.motor.Transform = CFrame.Angles(entry.angle, 0, 0)
		elseif working then
			entry.angle += (SPIN_SPEEDS[entry.spin] or 0) * deltaTime
			entry.motor.Transform = CFrame.Angles(0, entry.angle, 0)
		end
	end
end

-- Plays your avatar's own sit animation while you ride a mower (not on stand-on machines).
local function updateSit(character: Model?)
	local tool = character and character:FindFirstChildOfClass("Tool")
	local riding = tool ~= nil and tool:GetAttribute("Ride") == true and tool:GetAttribute("Stand") ~= true
	if riding and not sitTrack and character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animate = character:FindFirstChild("Animate")
		local sit = animate and animate:FindFirstChild("sit")
		local animation = sit and sit:FindFirstChildWhichIsA("Animation")
		if animator and animation then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
			sitTrack = track
		end
	elseif not riding and sitTrack then
		sitTrack:Stop(0.2)
		sitTrack = nil
	end
end

function ToolFxController:Start()
	player.CharacterAdded:Connect(function()
		-- The old track went away with the old character.
		sitTrack = nil
	end)

	RunService.Stepped:Connect(function(_, deltaTime)
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local tool = character and character:FindFirstChildOfClass("Tool")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if tool and tool:GetAttribute("Category") and root and root:IsA("BasePart") then
				spinTool(tool, root, deltaTime)
			end
		end
		updateSit(player.Character)
		-- Tools set down to be worked on show their wear too.
		local servicing = workspace:FindFirstChild("Servicing")
		for _, model in if servicing then servicing:GetChildren() else {} do
			showWear(model, false, os.clock())
		end
	end)
end

return ToolFxController
