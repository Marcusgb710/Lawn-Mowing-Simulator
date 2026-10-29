-- Little sound effects (docs/GAME_DESIGN.md, "Immersion"). Each one is a named Sound; put an id
-- from the Roblox audio library ("rbxassetid://...") in Ids to hear it. Empty ids stay silent.

local Debris = game:GetService("Debris")

-- How far away a sound can still be heard, in studs.
local ROLL_OFF_DISTANCE = 60

local Sounds = {}

Sounds.Ids = {
	Thunk = "", -- a tool set down in the truck bed or on the floor
	Pickup = "", -- taking a tool off the wall or out of the truck
	Hang = "", -- hanging a tool back up
	Bucket = "", -- a hand tool dropped in the tool bucket
	Snip = "", -- a snip of grass shears
	BladeHit = "", -- a mower's blade hitting a rock or a stick hidden in the grass
	-- The next five are free Creator Store audio. Four are Pro Sound Effects' "Lawn Mower ..." (titled
	-- below without that start); LawnDone is from mixkit.
	LawnDone = "rbxassetid://103516326607012", -- lawn done chime; mixkit achievement bell (free, Creator Store)
	EngineIdle = "rbxassetid://9116244745", -- a petrol mower idling; "Motor 1" (free, Creator Store)
	EngineLoad = "rbxassetid://9116245012", -- a mower bogging down in thick grass; "Motor 2" (free, Creator Store)
	PullStart = "rbxassetid://9116246961", -- pull-start; "Old Push Style Cu Start Stop 1" (free, Creator Store)
	ReelWhirr = "rbxassetid://9116245925", -- a reel mower whirring; "Old Push Style 1" (free, Creator Store)
}

-- Plays `name` from `parent` (a part or attachment), if it has an id.
function Sounds.play(parent: Instance, name: string, volume: number?)
	local id = Sounds.Ids[name]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = ROLL_OFF_DISTANCE
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5)
end

-- A looping `name` Sound on `parent`, if it has an id. It's silent and not playing yet: the caller
-- sets its Volume, plays it and, when done, destroys it.
function Sounds.loop(parent: Instance, name: string): Sound?
	local id = Sounds.Ids[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMaxDistance = ROLL_OFF_DISTANCE
	sound.Parent = parent
	return sound
end

return Sounds
