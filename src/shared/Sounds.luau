-- Little sound effects (docs/GAME_DESIGN.md, "Immersion"). Each one is a named Sound; put an id
-- from the Roblox audio library ("rbxassetid://...") in Ids to hear it. Empty ids stay silent.

local Debris = game:GetService("Debris")

local Sounds = {}

Sounds.Ids = {
	Thunk = "", -- a tool set down in the truck bed or on the floor
	Pickup = "", -- taking a tool off the wall or out of the truck
	Hang = "", -- hanging a tool back up
	Bucket = "", -- a hand tool dropped in the tool bucket
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
