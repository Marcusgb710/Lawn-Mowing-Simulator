-- The clean-stripe splash: a clean stripe (GrassController.StripDone: a mower pass of 30 studs or more
-- with no blade hit) is cheered in the middle of the screen by a tilted gold NICE STRIPE! (or CLEAN CUT!,
-- PERFECT LINE! in turn), at most once every 8 seconds and never over a menu, the pay panel or a scene.
-- It is cosmetic: it pays nothing and tells the server nothing. HudController starts it
-- (Splash.start) with a way to tell whether its pay panel is open.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local GrassController = require(script.Parent.Parent.Controllers.GrassController)

local Splash = {}

-- The words it says in turn, at least this many seconds between two (so a field of stripes is not a
-- wall of them), how long it stays before it fades and how long the fade takes, its text size (smaller
-- on a touch or short screen), the ink stroke round it, its tilt in degrees and the quiet star chime
-- that goes with it. UiLayout's Splash is where it is, 0.42 of the way down.
local SPLASH_WORDS = { "NICE STRIPE!", "CLEAN CUT!", "PERFECT LINE!" }
local SPLASH_COOLDOWN = 8
local SPLASH_SHOWN = 1.2
local SPLASH_FADE = 0.3
local SPLASH_TEXT_SIZE = 54
local SPLASH_TEXT_SIZE_SMALL = 40
local SPLASH_STROKE = 4
local SPLASH_TILT = -4
local SPLASH_VOLUME = 0.4

-- When the last splash came (os.clock seconds), whose turn the words are on, and the splash on screen.
local splashAt = -math.huge
local splashTurn = 1
local splashHolder: Frame? = nil
-- Whether HudController's pay panel is open (Splash.start hands it over).
local payShown: () -> boolean = function()
	return false
end

-- Whether a splash may show now: not while a scene or the drive has the screen (the HUD's screen is off),
-- the title card is up, a menu or the dialogue has the mouse, or the pay panel is open. It is cosmetic,
-- so it never waits: a stripe cheered late is no cheer.
local function splashFree(): boolean
	return UI.getScreen().Enabled and UI.titleCardDone() and not UI.needsCursor() and not payShown()
end

-- A clean stripe was cut (StripDone): the gold words pop in over the middle of the lawn, hold for
-- SPLASH_SHOWN seconds and fade, with a quiet star chime. No XP, no cash, nothing sent to the server.
local function showSplash(_length: number)
	local now = os.clock()
	if now - splashAt < SPLASH_COOLDOWN or not splashFree() then
		return
	end
	splashAt = now
	local words = SPLASH_WORDS[splashTurn]
	splashTurn = splashTurn % #SPLASH_WORDS + 1
	if splashHolder then
		splashHolder:Destroy()
	end

	local holder = UI.new("Frame", {
		Name = "Splash",
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = UI.getScreen(),
	})
	UI.keepPlaced(holder, "Splash")
	splashHolder = holder
	-- The words pop on an inner frame (holder is placed, and Juicy.pop would fight its layout scale).
	local inner = UI.new("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = SPLASH_TILT,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = holder,
	})
	local small = UI.isTouch() or UI.isCompact()
	local label = Juicy.text(words, {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		TextSize = if small then SPLASH_TEXT_SIZE_SMALL else SPLASH_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 21,
		Parent = inner,
	}, SPLASH_STROKE)
	-- Gold: the text's white takes the palette's Gold top to bottom.
	UI.new("UIGradient", {
		Color = ColorSequence.new(Juicy.Palette.Gold.top, Juicy.Palette.Gold.bottom),
		Rotation = 90,
		Parent = label,
	})
	Juicy.pop(inner)
	Sounds.playUi("Star", SPLASH_VOLUME)

	task.delay(SPLASH_SHOWN, function()
		if splashHolder ~= holder or not holder.Parent then
			return
		end
		local fade = TweenInfo.new(SPLASH_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
		task.delay(SPLASH_FADE, function()
			if splashHolder == holder then
				splashHolder = nil
			end
			holder:Destroy()
		end)
	end)
end

-- Cheers each clean stripe from now on. `isPayShown` says whether the pay panel is open.
function Splash.start(isPayShown: () -> boolean)
	payShown = isPayShown
	GrassController.StripDone:Connect(showSplash)
end

return Splash
