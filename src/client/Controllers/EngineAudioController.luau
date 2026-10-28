-- Gives mowers a voice, on everyone's screen. A petrol mower idles with a looping engine note that
-- crossfades into a lower, labouring one while it's cutting thick grass (the server's "Cutting"
-- attribute on the tool, see ToolService) and pitches down a little with the load. It also plays
-- a pull-start the first time it runs after it's equipped. A reel mower has no engine: it whirrs
-- while its pusher walks.
--
-- Every player's equipped mower is covered, so each client hears everyone else's. The sounds sit on
-- the tool's Handle and live only while the tool is working. Their ids are in Shared/Sounds, where
-- an empty id stays silent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maintenance = require(Shared.Config.Maintenance)
local Sounds = require(Shared.Sounds)
local Tools = require(Shared.Config.Tools)

-- How loud each loop is at full volume.
local IDLE_VOLUME = 0.5
local LOAD_VOLUME = 0.6
local WHIRR_VOLUME = 0.4
-- Seconds for a full crossfade, and for the pitch to settle on a new speed.
local FADE_TIME = 0.15
-- Pitch while cutting, normally 1, and how much it rises while the mower is moving.
local LOAD_SPEED = 0.85
local MOVING_NUDGE = 0.05
-- Fewest studs a second that count as moving, for characters whose MoveDirection isn't known here.
local MOVING_SPEED = 1
local ROLL_OFF = 60

local EngineAudioController = {}

type State = {
	-- The frame this tool was last seen equipped, and whether its pull-start has played.
	seen: number,
	pulled: boolean,
	-- "Motor", "Reel" or "Other"; nil until the tool's ItemId has arrived.
	kind: string?,
	-- 0-1: how far the engine has crossfaded to its load note (a reel mower: to its whirr).
	mix: number,
	speed: number,
	-- Looping Sounds, by their name in Sounds.Ids.
	sounds: { [string]: Sound },
}

-- [Tool] = State, for every tool that's equipped and has ever been working.
local states = setmetatable({}, { __mode = "k" })
local frameNumber = 0

local function kindOf(tool: Tool): string?
	local id = tool:GetAttribute("ItemId")
	local item = if typeof(id) == "string" then Tools.get(id) else nil
	if not item then
		return nil
	end
	if Maintenance.isReelMower(item) then
		return "Reel"
	elseif Tools.hasVerb(item, "Mow") and Maintenance.burnsFuel(item) then
		return "Motor"
	end
	return "Other"
end

local function baseOf(tool: Tool): BasePart?
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	return tool:FindFirstChildWhichIsA("BasePart", true)
end

-- The same test the head bob uses. MoveDirection may not be known for other players' characters,
-- so how fast they're really going counts too.
local function isMoving(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local velocity = root.AssemblyLinearVelocity
		return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
	end
	return false
end

-- The looping Sound called `name`, started silent the first time it's asked for. Nil if it has no id.
local function loopOf(state: State, name: string, base: BasePart): Sound?
	local known = state.sounds[name]
	if known then
		return known
	end
	local id = Sounds.Ids[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMaxDistance = ROLL_OFF
	sound.Parent = base
	sound:Play()
	state.sounds[name] = sound
	return sound
end

local function silence(state: State)
	for _, sound in state.sounds do
		sound:Stop()
		sound:Destroy()
	end
	table.clear(state.sounds)
	state.mix = 0
	state.speed = 1
end

local function updateTool(tool: Tool, character: Model, deltaTime: number)
	local working = tool:GetAttribute("Working") == true
	local state: State? = states[tool]
	if not state then
		if not working then
			return
		end
		state = { seen = frameNumber, pulled = false, kind = nil, mix = 0, speed = 1, sounds = {} }
		states[tool] = state
	end
	state.seen = frameNumber
	if not working then
		silence(state)
		return
	end

	state.kind = state.kind or kindOf(tool)
	local base = baseOf(tool)
	if not base or (state.kind ~= "Motor" and state.kind ~= "Reel") then
		return
	end
	local moving = isMoving(character)
	local fade = deltaTime / FADE_TIME

	if state.kind == "Reel" then
		local wanted = if moving then 1 else 0
		state.mix += math.clamp(wanted - state.mix, -fade, fade)
		local whirr = loopOf(state, "ReelWhirr", base)
		if whirr then
			whirr.Volume = WHIRR_VOLUME * state.mix
		end
		return
	end

	-- The pull-start is for the first time it runs after it's equipped, not each time it starts up.
	if not state.pulled then
		state.pulled = true
		Sounds.play(base, "PullStart")
	end
	local cutting = tool:GetAttribute("Cutting") == true
	state.mix += math.clamp((if cutting then 1 else 0) - state.mix, -fade, fade)
	local speed = (if cutting then LOAD_SPEED else 1) + (if moving then MOVING_NUDGE else 0)
	state.speed += (speed - state.speed) * math.min(fade, 1)
	local idle = loopOf(state, "EngineIdle", base)
	if idle then
		idle.Volume = IDLE_VOLUME * (1 - state.mix)
		idle.PlaybackSpeed = state.speed
	end
	local load = loopOf(state, "EngineLoad", base)
	if load then
		load.Volume = LOAD_VOLUME * state.mix
		load.PlaybackSpeed = state.speed
	end
end

function EngineAudioController:Start()
	RunService.Stepped:Connect(function(_, deltaTime)
		frameNumber += 1
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local tool = character and character:FindFirstChildOfClass("Tool")
			if character and tool then
				updateTool(tool, character, deltaTime)
			end
		end
		-- A tool nobody holds any more (put away, or its player gone) goes quiet, and is forgotten so
		-- that its next equip starts clean.
		for tool, state in states do
			if state.seen ~= frameNumber then
				silence(state)
				states[tool] = nil
			end
		end
	end)
end

return EngineAudioController
