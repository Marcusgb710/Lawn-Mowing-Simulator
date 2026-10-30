-- The front-page HUD's colours, and nothing else (the plan's first ruling). Each face is a pair: a
-- lighter `top` and a darker `bottom` that Juicy draws as a top-to-bottom gradient. Ink is the
-- outline and lip colour, Badge the tilted yellow tag, Glass the dark panel behind the hotbar.
-- It builds no Instances and uses no services, so scripts/check-gui can load it under Lune and
-- check the pairs. Juicy.luau puts it on screen.

local function face(top: Color3, bottom: Color3)
	return { top = top, bottom = bottom }
end

local Palette = {
	Ink = Color3.fromRGB(27, 42, 30), -- #1B2A1E
	Badge = Color3.fromRGB(255, 224, 102), -- #FFE066
	Glass = Color3.fromRGB(27, 42, 30), -- #1B2A1E at GlassTransparency (rgba .88)
	GlassTransparency = 0.12,

	Money = face(Color3.fromRGB(105, 226, 90), Color3.fromRGB(61, 174, 56)), -- #69E25A / #3DAE38
	Level = face(Color3.fromRGB(143, 216, 255), Color3.fromRGB(61, 155, 232)), -- #8FD8FF / #3D9BE8
	Streak = face(Color3.fromRGB(255, 179, 71), Color3.fromRGB(240, 102, 29)), -- #FFB347 / #F0661D
	Countdown = face(Color3.fromRGB(180, 140, 255), Color3.fromRGB(107, 79, 191)), -- #B48CFF / #6B4FBF
	Truck = face(Color3.fromRGB(116, 192, 255), Color3.fromRGB(45, 127, 224)), -- #74C0FF / #2D7FE0
	Guide = face(Color3.fromRGB(255, 200, 92), Color3.fromRGB(240, 138, 29)), -- #FFC85C / #F08A1D
	Crew = face(Color3.fromRGB(201, 166, 255), Color3.fromRGB(138, 91, 232)), -- #C9A6FF / #8A5BE8
	Contracts = face(Color3.fromRGB(255, 154, 122), Color3.fromRGB(232, 85, 58)), -- #FF9A7A / #E8553A
	Shop = face(Color3.fromRGB(94, 224, 200), Color3.fromRGB(31, 169, 143)), -- #5EE0C8 / #1FA98F
	Gifts = face(Color3.fromRGB(255, 154, 201), Color3.fromRGB(232, 69, 154)), -- #FF9AC9 / #E8459A
	TopLawns = face(Color3.fromRGB(255, 224, 102), Color3.fromRGB(232, 166, 30)), -- #FFE066 / #E8A61E
	Settings = face(Color3.fromRGB(201, 211, 204), Color3.fromRGB(138, 154, 142)), -- #C9D3CC / #8A9A8E
	Cream = face(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 241, 194)), -- #FFFFFF / #FFF1C2
	Danger = face(Color3.fromRGB(255, 122, 107), Color3.fromRGB(224, 85, 63)), -- #FF7A6B / #E0553F
	Gold = face(Color3.fromRGB(255, 224, 102), Color3.fromRGB(242, 185, 47)), -- #FFE066 / #F2B92F, bars and titles
	Muted = face(Color3.fromRGB(92, 107, 97), Color3.fromRGB(63, 76, 67)), -- #5C6B61 / #3F4C43, the choices not taken in Settings
}

return Palette
