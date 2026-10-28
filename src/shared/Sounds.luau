-- Little sound effects (docs/GAME_DESIGN.md, "Immersion"). Each one is a named Sound; put an id
-- from the Roblox audio library ("rbxassetid://...") in Ids to hear it. Empty ids stay silent.

local Debris = game:GetService("Debris")

local Sounds = {}

Sounds.Ids = {
	Thunk = "", -- a tool set down in the truck bed or on the floor
	Pickup = "", -- taking a tool off the wall or out of the truck
	Hang = "", -- hanging a tool back up
	Bucket = "", -- a hand tool dropped in the tool bucket
	Snip = "", -- a snip of grass shears
	BladeHit = "", -- a mower's blade hitting a rock or a stick hidden in the grass
	LawnDone = "rbxassetid://103516326607012", -- the chime when a lawn is mowed enough to count as done; "mixkit achievement bell" (free, Creator Store)
	EngineIdle = "rbxassetid://9116244745", -- a petrol mower idling, looped; Pro Sound Effects "Lawn Mower Motor 1" (free, Creator Store)
	EngineLoad = "rbxassetid://9116245012", -- the same engine bogging down in thick grass, looped; Pro Sound Effects "Lawn Mower Motor 2"
	PullStart = "rbxassetid://9116246961", -- a petrol mower's pull-start, once when it first runs; Pro Sound Effects "Lawn Mower Old Push Style Cu Start Stop 1"
	ReelWhirr = "rbxassetid://9116245925", -- a reel mower's blades whirring while it moves, looped; Pro Sound Effects "Lawn Mower Old Push Style 1"
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
	sound.RollOffMaxDistance = 60
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5)
end

return Sounds
