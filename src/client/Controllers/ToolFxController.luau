-- Makes tools look alive on everyone's screen: wheels roll as the player moves, and mower blades
-- and trimmer spools spin while the tool is working. Also sits you down on riding mowers.
--
-- Kit tools get a Motor6D with a "Spin" attribute on each moving part (see Assets.toTool), and the
-- server sets a "Working" attribute on the tool (see ToolService). This only turns the motors.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Radians per second.
local SPIN_SPEEDS = {
	Rotor = 45,
	Spool = 60,
}

local ToolFxController = {}

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

local function spinTool(tool: Tool, root: BasePart, deltaTime: number)
	local forwardSpeed = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	local working = tool:GetAttribute("Working") == true
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

-- Plays your avatar's own sit animation while you ride a mower.
local function updateSit(character: Model?)
	local tool = character and character:FindFirstChildOfClass("Tool")
	local riding = tool ~= nil and tool:GetAttribute("Ride") == true
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
	end)
end

return ToolFxController
