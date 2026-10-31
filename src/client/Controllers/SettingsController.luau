-- The Settings window (the HUD's Settings button, or comma on a keyboard): three choices that are
-- saved in your profile. Sound (Off, Low, High) is the volume of every game sound (Sounds.setVolume),
-- Camera motion (On, Off) is the head bob and engine shake (CameraController.setMotion), and Grass
-- detail (Auto, High, Low) is how many layers the grass is drawn with, which GrassController decides
-- once as it draws its first lawn (so it takes effect when you rejoin). The rules for what is allowed
-- are in Config/Settings.luau.
--
-- This is the one writer. A choice applies at once, and is sent to the server (SaveSettings) a
-- moment later, after you stop tapping, no faster than the server accepts. The Guide's camera switch
-- and the V key choose camera motion through setMotion here, so all three stay in step. When the
-- profile comes in (and nothing is waiting to be sent) it is what the window shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Settings = require(Shared.Config.Settings)
local Sounds = require(Shared.Sounds)

local ClientState = require(script.Parent.Parent.ClientState)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)

local SettingsController = {}

-- A choice is sent this long after the last tap, and never sooner than MIN_GAP after the one before.
-- The server refuses a second save inside Settings.Cooldown (half a second), measured between arrivals
-- where this measures between sends, so MIN_GAP leaves the network's jitter some room.
local SAVE_DELAY = 0.3
local MIN_GAP = 0.9

-- The window's measurements: a row's height, the room its words leave for the choices, and a choice's
-- width and height (the pill's lip hangs a few pixels below).
local ROW_HEIGHT = 72
local ROW_MARGIN = 14
local CHOICE_WIDTH = 78
local CHOICE_HEIGHT = 38
local CHOICE_GAP = 8
local CHOICE_TEXT_SIZE = 18
local CHOICE_STROKE = 3
local CHOICE_LIP = 4

-- The rows, in the window's order: the setting's key (Settings.Keys), what it is called, a line of
-- small print under that (or none), and the words on its choices.
local ROWS = {
	{ key = "sound", title = "Sound", note = nil, words = { Off = "Off", Low = "Low", High = "High" } },
	{
		key = "motion",
		title = "Camera motion",
		note = "Head bob and engine shake.",
		words = { [true] = "On", [false] = "Off" },
	},
	{
		key = "grass",
		title = "Grass detail",
		note = "Takes effect when you rejoin.",
		words = { Auto = "Auto", High = "High", Low = "Low" },
	},
}

-- What the window shows and what is in force: a table of Settings.Values, kept clean.
local current = Settings.clean(nil)
-- A choice is waiting to be sent, or a send is under way.
local dirty = false
local sending = false
local lastSent = -MIN_GAP
local saveTicket = 0

local window: GuiObject
local choiceHolders: { [string]: Frame } = {}

-- Puts what is in `current` to use: the sound volume and the camera motion. (Grass detail has nothing
-- to apply: GrassController reads it when it first draws a lawn.)
local function apply()
	Sounds.setVolume(Settings.volume(current.sound))
	CameraController.setMotion(current.motion)
end

-- Draws each row's choices: the chosen one in the Settings colour, the others greyed.
local function render()
	for _, row in ROWS do
		local holder = choiceHolders[row.key]
		if not holder then
			continue
		end
		UI.clearList(holder)
		for index, option in Settings.Options[row.key] do
			local chosen = current[row.key] == option
			local _button, face = Juicy.button(if chosen then "Settings" else "Muted", function()
				SettingsController.set(row.key, option)
			end, {
				Name = tostring(option),
				Size = UDim2.fromOffset(CHOICE_WIDTH, CHOICE_HEIGHT),
				Radius = CHOICE_HEIGHT / 2,
				Stroke = CHOICE_STROKE,
				Lip = CHOICE_LIP,
				LayoutOrder = index,
				Parent = holder,
			})
			-- The chosen choice is the light Settings face with dark words, the others the dark Muted face with
			-- white ones: white on the light face would not read.
			Juicy.text(row.words[option], {
				Name = "Words",
				Size = UDim2.fromScale(1, 1),
				TextSize = CHOICE_TEXT_SIZE,
				TextColor3 = if chosen then Juicy.Palette.Ink else Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 5,
				Parent = face,
			}, if chosen then 0 else nil)
		end
	end
end

-- Draws the choices only while the window is up: they are drawn again as it opens (Start), so a choice
-- made with the window away (the V key) or a profile that comes in costs nothing.
local function renderIfShown()
	if window.Visible then
		render()
	end
end

-- Takes the profile's settings as what is in force, unless a choice of ours is still on its way to
-- the server (its answer would only put the old one back for a moment).
local function adopt()
	local profile = ClientState.profile
	if not profile or dirty or sending then
		return
	end
	current = Settings.clean(profile.settings)
	apply()
	renderIfShown()
end

-- Asks the server to save `sent`: whether it answered with the saved choices.
local function ask(sent): boolean
	local ok, saved = pcall(function()
		return Net.func("SaveSettings"):InvokeServer(sent)
	end)
	return ok and typeof(saved) == "table"
end

-- Sends `current` to the server, once it has been quiet for SAVE_DELAY, and again if it changed
-- while it was away. If the server refuses (or can't be reached) the profile's copy is the truth.
local function send()
	sending = true
	while dirty do
		local wait = lastSent + MIN_GAP - os.clock()
		if wait > 0 then
			task.wait(wait)
		end
		dirty = false
		lastSent = os.clock()
		local sent = table.clone(current)
		local saved = ask(sent)
		if not saved and not dirty then
			-- A nil answer is usually the server's cooldown, which a slow first request and a quick second
			-- can trip: wait out the gap and ask once more before giving the choice up.
			task.wait(MIN_GAP)
			if not dirty then
				lastSent = os.clock()
				saved = ask(sent)
			end
		end
		if not saved and not dirty then
			local profile = ClientState.profile
			if profile then
				current = Settings.clean(profile.settings)
				apply()
				renderIfShown()
			end
		end
	end
	sending = false
end

local function scheduleSave()
	dirty = true
	saveTicket += 1
	local ticket = saveTicket
	task.delay(SAVE_DELAY, function()
		if ticket == saveTicket and not sending then
			send()
		end
	end)
end

-- What each setting is now (a copy).
function SettingsController.get(): Settings.Values
	return table.clone(current)
end

-- Chooses `value` for the setting `key`: used at once and saved. A value the setting does not allow
-- is ignored.
function SettingsController.set(key: string, value: any)
	local options = Settings.Options[key]
	if not (options and table.find(options, value)) or current[key] == value then
		return
	end
	current[key] = value
	apply()
	renderIfShown()
	scheduleSave()
end

-- Camera motion on or off: the Guide's switch and the V key choose it here.
function SettingsController.setMotion(on: boolean)
	SettingsController.set("motion", on)
end

function SettingsController:Start()
	local content
	window, content = UI.panel("Settings", "Settings")

	local list = UI.scrollingList(content, {})
	for index, row in ROWS do
		if row.key == "motion" and not CameraController.hasMotion() then
			continue
		end
		local card = UI.card({
			Name = row.title,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = list,
		})
		local words = UDim2.new(1, -(CHOICE_WIDTH * 3 + CHOICE_GAP * 2 + ROW_MARGIN * 3), 0, 26)
		UI.label(row.title, {
			Name = "Title",
			Position = UDim2.fromOffset(ROW_MARGIN, if row.note then 10 else 23),
			Size = words,
			FontFace = UI.Fonts.Heavy,
			TextSize = 20,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		if row.note then
			UI.label(row.note, {
				Name = "Note",
				Position = UDim2.fromOffset(ROW_MARGIN, 38),
				Size = UDim2.new(words.X.Scale, words.X.Offset, 0, 20),
				TextSize = 14,
				TextColor3 = UI.Colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = card,
			})
		end
		local count = #Settings.Options[row.key]
		choiceHolders[row.key] = UI.new("Frame", {
			Name = "Choices",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -ROW_MARGIN, 0.5, -2),
			Size = UDim2.fromOffset(CHOICE_WIDTH * count + CHOICE_GAP * (count - 1), CHOICE_HEIGHT),
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(CHOICE_GAP, Enum.FillDirection.Horizontal) })
	end

	-- The Settings button on the HUD opens this window (and comma on a keyboard).
	require(script.Parent.HudController).setRightAction("Settings", function()
		UI.toggle("Settings")
	end)
	-- Sounds the server plays go through the same volume.
	Sounds.watch()

	ClientState.Changed:Connect(function(key)
		if key == "profile" then
			adopt()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	adopt()
end

return SettingsController
