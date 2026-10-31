-- The small drawing pieces more than one part of the HUD uses: the framed progress bar (Grandma's goal
-- banner and the job card's to-dos), the key badge on a square's top left corner (the menu squares and
-- the right strip), the gap between a square's face and the label under it, and a small pop's size.
--
--   Bits.framedBar({ Size = ..., Parent = row }, "Grass", TRACK_DARK)
--   local key, keyText = Bits.addCornerKey(face, Enum.KeyCode.B, 76)

local UserInputService = game:GetService("UserInputService")

local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)

local Bits = {}

-- A square's pieces (its spec, button, face, label and key badge), for fitting it to the screen.
export type Piece = {
	spec: any,
	button: TextButton,
	face: Frame,
	label: GuiObject?,
	key: GuiObject?,
	keyText: TextLabel?,
}

-- A key badge on a face's top left corner: its size and how far in its middle is. A face under
-- KEY_SMALL_FACE px (the right strip on a phone, Settings anywhere) gets the small badge, so it does
-- not cover the glyph.
local SQUARE_KEY_SIZE = 22
local SQUARE_KEY_SMALL = 16
local KEY_SMALL_FACE = 60
local SQUARE_KEY_INSET = 8
-- A square's label sits this far under its face.
Bits.SQUARE_LABEL_GAP = 12
-- A bar's track on the cards and the banner is this tall, in an ink outline of its own.
local BAR_HEIGHT = 13
local BAR_STROKE = 2
Bits.BAR_HEIGHT = BAR_HEIGHT
-- The pops that lift off under a bigger one (the pay panel's tip, an XP gain) are this many pixels tall.
Bits.SMALL_POP = 16

-- A progress bar for the cards and the banner: UI.bar's striped fill (`kind`: "Grass" or "Money") in
-- a `BAR_HEIGHT` px track of colour `track` with an ink outline. UI.bar's own track is hidden, so the
-- outline is one rounded frame; its `frame` (the thing to place or hide) is that outer one, and `set`
-- and `fill` are UI.bar's. `props` (Size, Position, LayoutOrder, Parent...) are the outer frame's.
function Bits.framedBar(props, kind: string, track: Color3): UI.Bar
	local outer = UI.new("Frame", {
		BackgroundColor3 = track,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
	}, {
		UI.corner(BAR_HEIGHT / 2),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Juicy.Palette.Ink,
			Thickness = BAR_STROKE,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})
	for key, value in props do
		if key ~= "Parent" then
			outer[key] = value
		end
	end
	local inner = UI.bar({ Size = UDim2.fromScale(1, 1), Parent = outer }, kind)
	inner.frame.BackgroundTransparency = 1
	if inner.frame:IsA("ImageLabel") then
		inner.frame.ImageTransparency = 1
	end
	if props.Parent then
		outer.Parent = props.Parent
	end
	return { frame = outer, set = inner.set, fill = inner.fill }
end

-- Sizes a key badge for a face `faceHeight` px tall: the small one under KEY_SMALL_FACE.
function Bits.fitCornerKey(badge: GuiObject, text: TextLabel, faceHeight: number)
	local small = faceHeight < KEY_SMALL_FACE
	local size = if small then SQUARE_KEY_SMALL else SQUARE_KEY_SIZE
	badge.Size = UDim2.fromOffset(size, size)
	text.TextSize = if small then 11 else 14
end

-- A key badge on a face's top left corner (the key's name in a small dark square), with a keyboard.
-- Returns it and its text, or nothing without one; fitCornerKey sizes it for the face.
function Bits.addCornerKey(face: Frame, key: Enum.KeyCode, faceHeight: number): (GuiObject?, TextLabel?)
	if not UserInputService.KeyboardEnabled then
		return nil, nil
	end
	local badge = UI.sliced("KeyBadge", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(SQUARE_KEY_INSET, SQUARE_KEY_INSET),
		ZIndex = 8,
		Parent = face,
	}, { color = UI.Colors.Ink, transparency = 0.3, radius = 6 })
	local text = UI.heading(UserInputService:GetStringForKeyCode(key), {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
		Parent = badge,
	})
	Bits.fitCornerKey(badge, text, faceHeight)
	return badge, text
end

return Bits
