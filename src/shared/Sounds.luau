-- Little sound effects (docs/GAME_DESIGN.md, "Immersion"). Each one is a named Sound; put an id
-- from the Roblox audio library ("rbxassetid://...") in Ids to hear it. Empty ids stay silent.

-- The services are fetched where they're used, not as the module loads, so scripts/check-season can
-- load this file under Lune (which has no `game`) and read Ids.
--
-- Every sound made here goes through the "Effects" SoundGroup, which the player's Sound setting (the
-- Settings window) turns up or down with setVolume. The group is made on a client the first time a
-- sound is made, and sounds are put in it by their SoundGroup property, not by parenting them under
-- it, so a sound on a tool or a part keeps its place in the world. A sound the server makes (the
-- server plays some, and its ids are all still empty) carries a tag, and `watch`, which a client runs
-- once, puts those in the group as they arrive.

-- How far away a sound can still be heard, in studs.
local ROLL_OFF_DISTANCE = 60
-- A UI sound that never ends (an id that fails to load never fires Ended) is cleaned up after this.
local UI_SOUND_LIMIT = 30
-- The tag on a sound the server made, for `watch`.
local EFFECTS_TAG = "EffectsSound"

local Sounds = {}

-- The Effects group's volume, 0 to 1, and the group once a client has made it. The level is kept
-- here so a group made later starts at it.
local level = 1
local effects: SoundGroup? = nil

-- The Effects SoundGroup, under SoundService, made when it is first wanted. Only a client has one.
local function effectsGroup(): SoundGroup
	local group = effects
	if group and group.Parent then
		return group
	end
	local made = Instance.new("SoundGroup")
	made.Name = "Effects"
	made.Volume = level
	made.Parent = game:GetService("SoundService")
	effects = made
	return made
end

-- Sends `sound` through the Effects group: a client's own sounds now, a server's sounds by their tag.
local function route(sound: Sound)
	if game:GetService("RunService"):IsClient() then
		sound.SoundGroup = effectsGroup()
	else
		game:GetService("CollectionService"):AddTag(sound, EFFECTS_TAG)
	end
end

-- Sets how loud every sound made here is, 0 (silent) to 1 (full). The player's Sound setting calls
-- this. It makes no group: one made later starts at this level.
function Sounds.setVolume(newLevel: number)
	level = math.clamp(newLevel, 0, 1)
	local group = effects
	if group and group.Parent then
		group.Volume = level
	end
end

function Sounds.getVolume(): number
	return level
end

-- Puts the sounds the server makes (tagged in `route`) through this client's Effects group, the ones
-- already here and each one that arrives. A client calls this once.
function Sounds.watch()
	local collection = game:GetService("CollectionService")
	local function adopt(instance: Instance)
		if instance:IsA("Sound") then
			instance.SoundGroup = effectsGroup()
		end
	end
	collection:GetInstanceAddedSignal(EFFECTS_TAG):Connect(adopt)
	for _, instance in collection:GetTagged(EFFECTS_TAG) do
		adopt(instance)
	end
end

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
	-- The Busy Season's UI sounds, played with playUi. All six are Roblox's own public audio (creator
	-- Roblox, id 1, checked on the Creator Store); Find and Streak are for the slices after the first.
	Cash = "rbxassetid://127645268874265", -- CoinTransfer_01 (Roblox): cash coming in
	LevelUp = "rbxassetid://12222253", -- victory.wav (Roblox): a new level
	GoalDone = "rbxassetid://17208361335", -- Roblox GUI - Notification High (Roblox): a milestone reached
	Star = "rbxassetid://15675055424", -- Roblox_UI_Cute_Pop (Roblox): a star landing on the pay panel
	Find = "rbxassetid://17208319162", -- Roblox GUI - Pickup (Roblox): finding something in a yard
	Streak = "rbxassetid://15675043410", -- Roblox_UI_Tonal_Stinger (Roblox): a streak growing
	-- The front-page HUD's button sound (Juicy.button plays it on every press). Found the same way:
	-- the toolbox search for "Roblox UI click", kept to audio whose creator is Roblox (id 1).
	Click = "rbxassetid://15675032796", -- Roblox_UI_Small_Click (Roblox): a HUD button pressed
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
	route(sound)
	sound.Parent = parent
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 5)
end

-- Plays `name` for this player alone, if it has an id: from SoundService, so it has no place in the
-- world and is heard the same everywhere (the pay panel's cash, a goal ticking over). `play` is for
-- sounds that come from somewhere.
function Sounds.playUi(name: string, volume: number?)
	local id = Sounds.Ids[name]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume or 0.5
	route(sound)
	sound.Parent = game:GetService("SoundService")
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	game:GetService("Debris"):AddItem(sound, UI_SOUND_LIMIT)
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
	route(sound)
	sound.Parent = parent
	return sound
end

return Sounds
