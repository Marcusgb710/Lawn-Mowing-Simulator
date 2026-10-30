-- The three choices a player keeps in the Settings window (the HUD's Settings button): Sound (Off,
-- Low, High), Camera motion (on or off) and Grass detail (Auto, High, Low). They are saved in the
-- profile as `settings = { sound, motion, grass }`. This file is the rule for what is allowed:
-- `clean` makes any value into a good one, and it is what the server runs on every SaveSettings call
-- and on a save as it loads, so a tampered or old value never gets further. Nothing here reads the
-- game or saves anything.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it: the motion
-- default is a copy of what GameConfig.Camera says (the check compares them) and the shell counts are
-- the two GrassImages.shellCount has.

export type Values = { sound: string, motion: boolean, grass: string }

local Settings = {}

-- The keys, in the order the window shows them.
Settings.Keys = { "sound", "motion", "grass" }

-- What each key may be. The first of each list is not special: Defaults says what a player who
-- never opens the window has.
Settings.Options = {
	sound = { "Off", "Low", "High" },
	motion = { true, false },
	grass = { "Auto", "High", "Low" },
}

-- Today's behaviour exactly: full sound, camera motion as GameConfig.Camera has it (on), and the
-- grass the way the game has always chosen it (4 shells on a phone, 6 otherwise).
Settings.Defaults = { sound = "High", motion = true, grass = "Auto" }

-- How loud each Sound choice is, as the volume of the Effects SoundGroup.
local VOLUMES = { Off = 0, Low = 0.5, High = 1 }
-- How many shells the grass is drawn with at a phone and at a PC (GrassImages.shellCount).
local TOUCH_SHELLS = 4
local FULL_SHELLS = 6

-- A new table with the three keys: a good value is kept, a bad or missing one is the default, and
-- anything else (other keys, other types, a value that is not a table at all) is dropped. Values are
-- matched exactly. It never errors, whatever it is given.
function Settings.clean(source: any): Values
	local given = if typeof(source) == "table" then source else {}
	local values = {}
	for _, key in Settings.Keys do
		local value = rawget(given, key)
		values[key] = if table.find(Settings.Options[key], value) then value else Settings.Defaults[key]
	end
	return values :: any
end

-- The volume of the Effects group for a Sound choice (the default's for anything unknown).
function Settings.volume(sound: string): number
	return VOLUMES[sound] or VOLUMES[Settings.Defaults.sound]
end

-- How many shells the grass is drawn with, for a Grass detail choice on a touch screen or not. Auto
-- is the old rule; High and Low are the two counts on any device.
function Settings.shells(grass: string, touch: boolean): number
	if grass == "High" then
		return FULL_SHELLS
	elseif grass == "Low" then
		return TOUCH_SHELLS
	end
	return if touch then TOUCH_SHELLS else FULL_SHELLS
end

return Settings
