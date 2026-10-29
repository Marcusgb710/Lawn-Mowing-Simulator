-- A few words that lift off a piece of the HUD and fade: "+$30" off a goal's row, "+$120" off the
-- pay panel's total, "+40 XP" off the XP bar. They sit in the HUD's screen at the middle of the
-- piece they come from, so whatever scale or column that piece is in, they start right on it.
--
--   FloatingText.show(row.frame, "+$30")                              -- gold, for cash
--   FloatingText.show(xpBar.frame, "+40 XP", UI.Colors.Accent, 16)    -- another colour, smaller

local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local FloatingText = {}

local TEXT_SIZE = 20
-- How far one rises, and for how long, in pixels and seconds.
local RISE = 40
local LIFETIME = 0.9
-- A lot at once (a milestone, a level and the XP for it) are fine; past this many the oldest goes.
local MAX_LIVE = 8
-- Over the HUD's panels and what the pay panel draws.
local Z_INDEX = 100

local RISE_TWEEN = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- It holds its colour while it climbs, then goes.
local FADE_TWEEN = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- What's showing, oldest first.
local live: { TextLabel } = {}

local function forget(label: TextLabel)
	local index = table.find(live, label)
	if index then
		table.remove(live, index)
	end
end

-- Whether `from` is drawn: it's in the game, it and every GuiObject it's inside are Visible, and it
-- has a width. A hidden piece's AbsolutePosition can be stale or zero, so a pop off one would float
-- over nothing.
local function isShowing(from: GuiObject): boolean
	if not from:IsDescendantOf(game) or from.AbsoluteSize.X == 0 then
		return false
	end
	local piece: Instance? = from
	while piece and piece:IsA("GuiObject") do
		if not piece.Visible then
			return false
		end
		piece = piece.Parent
	end
	return true
end

-- Lifts `text` off the middle of `from` (gold unless `color` says otherwise, TEXT_SIZE pixels tall
-- unless `size` says) and returns its label. Nothing shows, and nothing comes back, if `from` has
-- gone from the screen or is hidden, so a caller can pop off something else.
function FloatingText.show(from: GuiObject, text: string, color: Color3?, size: number?): TextLabel?
	if not isShowing(from) then
		return nil
	end
	local screen = UI.getScreen()
	while #live >= MAX_LIVE do
		local oldest = table.remove(live, 1) :: TextLabel
		oldest:Destroy()
	end

	-- In the screen's own pixels (its top sits under Roblox's top bar), whatever scale `from` is in.
	local middle = from.AbsolutePosition + from.AbsoluteSize / 2 - screen.AbsolutePosition
	local label = UI.label(text, {
		Name = "FloatingText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(middle.X, middle.Y),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = UI.Fonts.Heavy,
		TextSize = size or TEXT_SIZE,
		TextColor3 = color or UI.Colors.Gold,
		TextStrokeColor3 = UI.Colors.Ink,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = Z_INDEX,
		Parent = screen,
	})
	table.insert(live, label)

	local rise = TweenService:Create(label, RISE_TWEEN, {
		Position = UDim2.fromOffset(middle.X, middle.Y - RISE),
	})
	local fade = TweenService:Create(label, FADE_TWEEN, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	rise:Play()
	fade:Play()
	fade.Completed:Once(function()
		forget(label)
		label:Destroy()
	end)
	-- One that was destroyed early (the oldest of nine) leaves the list with it.
	label.Destroying:Once(function()
		forget(label)
	end)
	return label
end

return FloatingText
