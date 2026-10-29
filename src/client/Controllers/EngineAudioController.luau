-- Gives mowers a voice, on everyone's screen. A petrol mower idles with a looping engine note that
-- crossfades into a lower, labouring one while it's cutting thick grass (the server's "Cutting"
-- attribute on the tool, see ToolService) and pitches down a little with the load. It also plays
-- a pull-start the first time it runs after it's equipped. A reel mower has no engine: it whirrs
-- while it's working, which the server only allows while its pusher walks.
--
-- Every player's equipped mower is covered, so each client hears everyone else's. The sounds sit on
-- the tool's base part and live only while the tool is working: they fade in and out over a
-- moment. Their ids are in Shared/Sounds, where an empty id stays silent.

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
-- Seconds for a full crossfade, for the loops to fade in or out, and for the pitch to settle.
local FADE_TIME = 0.15
-- Pitch while cutting, normally 1, and how much it rises while the mower is moving.
local LOAD_SPEED = 0.85
local MOVING_NUDGE = 0.05

local EngineAudioController = {}

type State = {
	-- The frame this tool was last seen equipped, and whether its pull-start has played.
	seen: number,
	pulled: boolean,
	-- "Motor", "Reel" or "Other"; nil until the tool's ItemId has arrived.
	kind: string?,
	-- 0-1: how far the engine has crossfaded from its idle note to its load note.
	mix: number,
	-- 0-1: how far the loops have faded in. It falls to 0 once the tool stops working.
	gain: number,
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

-- The part everything in a tool is welded to: "Handle", or "RideRoot" on riding mowers (see ToolService).
local function baseOf(tool: Tool): BasePart?
	local base = tool:FindFirstChild("Handle") or tool:FindFirstChild("RideRoot")
	if base and base:IsA("BasePart") then
		return base
	end
	return tool:FindFirstChildWhichIsA("BasePart", true)
end

-- The same test the head bob uses (see CameraController).
local function isMoving(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
end

-- Makes sure the loop called `name` is playing on `base`, silent to start with. A loop on a base
-- that's since been replaced (streamed out and back in) died with it, so it's started again.
local function ensureLoop(state: State, name: string, base: BasePart)
	local known = state.sounds[name]
	if known and known.Parent == base then
		return
	end
	if known then
		known:Destroy()
		state.sounds[name] = nil
	end
	local sound = Sounds.loop(base, name)
	if sound then
		sound:Play()
		state.sounds[name] = sound
	end
end

-- How loud the loop `name` is right now, before it fades in or out.
local function volumeOf(name: string, mix: number): number
	if name == "EngineIdle" then
		return IDLE_VOLUME * (1 - mix)
	elseif name == "EngineLoad" then
		return LOAD_VOLUME * mix
	end
	return WHIRR_VOLUME
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
		state = { seen = frameNumber, pulled = false, kind = nil, mix = 0, gain = 0, speed = 1, sounds = {} }
		states[tool] = state
	end
	state.seen = frameNumber
	if working and not state.kind then
		state.kind = kindOf(tool)
	end

	-- A working mower we can hear has a base to sound from. Anything else fades out what it had.
	local base = if working and (state.kind == "Motor" or state.kind == "Reel") then baseOf(tool) else nil
	local fade = deltaTime / FADE_TIME
	state.gain = math.clamp(state.gain + (if base then fade else -fade), 0, 1)
	if not base and state.gain == 0 then
		silence(state)
		return
	end

	if base then
		if state.kind == "Reel" then
			ensureLoop(state, "ReelWhirr", base)
		else
			-- The pull-start is for the first time it runs after it's equipped, not each time it starts up.
			if not state.pulled then
				state.pulled = true
				Sounds.play(base, "PullStart")
			end
			local cutting = tool:GetAttribute("Cutting") == true
			state.mix += math.clamp((if cutting then 1 else 0) - state.mix, -fade, fade)
			local speed = (if cutting then LOAD_SPEED else 1) + (if isMoving(character) then MOVING_NUDGE else 0)
			state.speed += (speed - state.speed) * math.min(fade, 1)
			ensureLoop(state, "EngineIdle", base)
			ensureLoop(state, "EngineLoad", base)
		end
	end
	for name, sound in state.sounds do
		sound.Volume = volumeOf(name, state.mix) * state.gain
		sound.PlaybackSpeed = state.speed
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
		-- A tool nobody holds any more (put away, or its player gone) goes quiet at once, with its
		-- sounds going away with it, and is forgotten so that its next equip starts clean.
		for tool, state in states do
			if state.seen ~= frameNumber then
				silence(state)
				states[tool] = nil
			end
		end
	end)
end

return EngineAudioController
