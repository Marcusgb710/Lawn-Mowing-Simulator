-- Juicy: the front-page HUD's look, drawn in code so no art is uploaded. A glossy gradient face
-- with a thick ink outline and a lip under it, a diagonal shine and a thin highlight, buttons that
-- grow on hover and squash on press, pills, tilted badges, and white Fredoka text with an ink
-- stroke. Plus three small animations the HUD reuses: pulse, pop and countTo. The colours are in
-- JuicyPalette.luau (which scripts/check-gui reads outside Roblox); this file builds the Instances.
--
-- Sizes are in pixels. A face's lip hangs below the Size you give (by Lip pixels) and its outline
-- sticks out Stroke pixels all round, so leave that much room, as the HUD's columns do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local JuicyPalette = require(script.Parent.JuicyPalette)
local UI = require(script.Parent.UI)

local Juicy = {}

Juicy.Palette = JuicyPalette

-- FredokaOne has one face (Regular), so that is the weight asked for: asking for Bold would only
-- make Roblox pick the nearest and could smear it.
Juicy.Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

local WHITE = Color3.new(1, 1, 1)

-- A face's measurements, in pixels: pieces (buttons, squares) and pills (the money row, badges).
local FACE_RADIUS = 18
local FACE_STROKE = 4
local FACE_LIP = 6
local PILL_STROKE = 3
local PILL_LIP = 4
-- The shine is a diagonal band that crosses the face once.
local SHINE_ROTATION = 60
local SHINE_BAND_START = 0.25
local SHINE_BAND_END = 0.4
local SHINE_BAND_TRANSPARENCY = 0.72
-- The thin white line under the top edge.
local HIGHLIGHT_INSET = 6
local HIGHLIGHT_HEIGHT = 4
local HIGHLIGHT_TRANSPARENCY = 0.55

-- A button's feel.
local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.92
local HOVER_TIME = 0.12
local PRESS_TIME = 0.06
local RELEASE_TIME = 0.25
local CLICK_VOLUME = 0.4
-- The label under a button: its height, its gap under the lip, and how much wider than the face it
-- may run (a long word is not cut off).
local LABEL_HEIGHT = 22
local LABEL_GAP = 8
local LABEL_TEXT_SIZE = 16
local LABEL_OVERHANG = 20
-- A glyph in a face fills this much of it.
local ICON_FRACTION = 0.6

-- A badge: its size when none is given, and its tilt and bob.
local BADGE_HEIGHT = 22
local BADGE_TEXT_SIZE = 14
local BADGE_PADDING = 16
local BADGE_TILT = 8
local BADGE_BOB = 2
local BADGE_BOB_TIME = 0.8

local PULSE_SCALE = 1.08
local PULSE_TIME = 0.25
local POP_FROM = 0.6
local POP_TIME = 0.35
-- The scale pulse and pop share, so one never fights the other.
local SCALE_NAME = "JuicyScale"

-- Copies `props` onto `instance`, leaving out the keys Juicy takes for itself.
local function applyProps(instance: Instance, props, skip: { [string]: boolean })
	for key, value in props or {} do
		if not skip[key] then
			(instance :: any)[key] = value
		end
	end
end

-- Text -------------------------------------------------------------------------------------------

-- White Fredoka text with an ink stroke that follows the letters. `props` are the TextLabel's; the
-- stroke is `stroke` pixels, else 2 (3 from 26 px up, as the plan has it). Pass 0 for no stroke
-- (a badge's ink text).
function Juicy.text(text: string, props, stroke: number?): TextLabel
	local textSize = (props and props.TextSize) or 18
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Juicy.Font,
		Text = text,
		TextColor3 = WHITE,
		TextSize = textSize,
		Size = UDim2.new(1, 0, 0, textSize + 6),
	})
	applyProps(label, props, { Parent = true })
	local thickness = stroke or (if textSize >= 26 then 3 else 2)
	if thickness > 0 then
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = JuicyPalette.Ink,
			Thickness = thickness,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	if props and props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Faces ------------------------------------------------------------------------------------------

local FACE_KEYS = { Radius = true, Stroke = true, Lip = true, Parent = true, ZIndex = true }

local function newFace(top: Color3, bottom: Color3, props, radius: number, stroke: number, lip: number)
	local base = (props and props.ZIndex) or 1
	local holder = UI.new("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(76, 76),
		ZIndex = base,
	})
	applyProps(holder, props, FACE_KEYS)

	-- The lip: an ink copy of the face a few pixels lower, behind it. It has the face's outline
	-- too, so it shows `lip` pixels below the face's own outline.
	UI.new("Frame", {
		Name = "Lip",
		BackgroundColor3 = JuicyPalette.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.fromScale(1, 1),
		ZIndex = base,
		Parent = holder,
	}, {
		UI.corner(radius),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = JuicyPalette.Ink,
			Thickness = stroke,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})

	-- The face: white, painted top to bottom by its gradient.
	local face = UI.new("Frame", {
		Name = "Face",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = base + 1,
		Parent = holder,
	}, {
		UI.corner(radius),
		UI.new("UIGradient", {
			Color = ColorSequence.new(top, bottom),
			Rotation = 90,
		}),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = JuicyPalette.Ink,
			Thickness = stroke,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})

	-- The shine: a white frame that is clear except for one soft diagonal band.
	UI.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = base + 2,
		Parent = face,
	}, {
		UI.corner(radius),
		UI.new("UIGradient", {
			Rotation = SHINE_ROTATION,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(SHINE_BAND_START - 0.01, 1),
				NumberSequenceKeypoint.new(SHINE_BAND_START, SHINE_BAND_TRANSPARENCY),
				NumberSequenceKeypoint.new(SHINE_BAND_END, SHINE_BAND_TRANSPARENCY),
				NumberSequenceKeypoint.new(SHINE_BAND_END + 0.01, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- The highlight: a thin white line just under the top edge.
	UI.new("Frame", {
		Name = "Highlight",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = HIGHLIGHT_TRANSPARENCY,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(HIGHLIGHT_INSET, HIGHLIGHT_INSET),
		Size = UDim2.new(1, -2 * HIGHLIGHT_INSET, 0, HIGHLIGHT_HEIGHT),
		ZIndex = base + 3,
		Parent = face,
	}, { UI.corner(2) })

	if props and props.Parent then
		holder.Parent = props.Parent
	end
	return holder, face
end

local function colorsOf(color: string): (Color3, Color3)
	local pair = JuicyPalette[color]
	assert(typeof(pair) == "table" and pair.top and pair.bottom, `Juicy: no face colour named "{color}"`)
	return pair.top, pair.bottom
end

-- A glossy face in the palette colour `color` ("Money", "Shop", "Cream"...). `props` go on the
-- holder (Size, Position, AnchorPoint, Parent, LayoutOrder...), plus Radius (default 18), Stroke
-- (4) and Lip (6), and ZIndex, which is the base the pieces stack up from. Returns the holder
-- (transparent, the size asked for, with Lip and Face inside) and the Face frame, where a glyph or
-- text goes: put it in the Face, above ZIndex + 3.
function Juicy.face(color: string, props): (Frame, Frame)
	local top, bottom = colorsOf(color)
	local radius = (props and props.Radius) or FACE_RADIUS
	local stroke = (props and props.Stroke) or FACE_STROKE
	local lip = (props and props.Lip) or FACE_LIP
	return newFace(top, bottom, props, radius, stroke, lip)
end

-- A face rounded to its full height (Size's Y in pixels), with a 3 px outline and a 4 px lip.
-- Radius, Stroke and Lip in `props` still win. Returns the holder and the Face.
function Juicy.pill(color: string, props): (Frame, Frame)
	local top, bottom = colorsOf(color)
	local sized = table.clone(props or {})
	sized.Size = sized.Size or UDim2.fromOffset(100, 36)
	local radius = sized.Radius or math.max(sized.Size.Y.Offset / 2, 2)
	local stroke = sized.Stroke or PILL_STROKE
	local lip = sized.Lip or PILL_LIP
	return newFace(top, bottom, sized, radius, stroke, lip)
end

-- Buttons ----------------------------------------------------------------------------------------

local BUTTON_KEYS = {
	Size = true,
	Label = true,
	Icon = true,
	Radius = true,
	Stroke = true,
	Lip = true,
	Parent = true,
	ZIndex = true,
}

-- Whether the hover feel applies: a phone has no pointer, so nothing grows under a finger.
local function hasPointer(): boolean
	return not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
end

-- A button: a face (colour `color`, the size in props.Size, 76 x 76 by default; give its height in
-- pixels) with props.Icon (a glyph name UI.icon knows) in the middle and props.Label under it.
-- The button's own size is the face plus the label. It grows on hover, squashes when pressed,
-- springs back, and plays the Click sound; `onClick` runs on a press or a tap. Everything is drawn
-- inside a "Content" frame that holds the UIScale, so the button keeps one hit area and grows from
-- its middle wherever it is anchored. Other props (Position, AnchorPoint, LayoutOrder, Name,
-- Visible, Parent...) go on the TextButton. Returns the button and its Face frame.
function Juicy.button(color: string, onClick: (() -> ())?, props): (TextButton, Frame)
	props = props or {}
	local faceSize: UDim2 = props.Size or UDim2.fromOffset(76, 76)
	assert(faceSize.Y.Scale == 0, "Juicy.button: Size's height must be in pixels")
	local base = props.ZIndex or 1
	local extra = if props.Label then LABEL_GAP + LABEL_HEIGHT else 0

	local button = UI.new("TextButton", {
		Name = "JuicyButton",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(faceSize.X.Scale, faceSize.X.Offset, 0, faceSize.Y.Offset + extra),
		ZIndex = base,
	})
	applyProps(button, props, BUTTON_KEYS)

	local content = UI.new("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = base,
		Parent = button,
	})
	local scale = UI.new("UIScale", { Scale = 1, Parent = content })

	local _body, face = Juicy.face(color, {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, faceSize.Y.Offset),
		Radius = props.Radius,
		Stroke = props.Stroke,
		Lip = props.Lip,
		ZIndex = base,
		Parent = content,
	})

	if props.Icon then
		local icon = UI.icon(props.Icon, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ICON_FRACTION, ICON_FRACTION),
			ZIndex = base + 4,
		}, WHITE)
		if icon then
			-- Square, as large as fits in the 60 percent box, so a wide face does not stretch it.
			UI.new("UIAspectRatioConstraint", {
				AspectRatio = 1,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			}).Parent =
				icon
			icon.Parent = face
		end
	end

	if props.Label then
		Juicy.text(props.Label, {
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, faceSize.Y.Offset + LABEL_GAP),
			Size = UDim2.new(1, LABEL_OVERHANG, 0, LABEL_HEIGHT),
			TextSize = LABEL_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = base + 1,
			Parent = content,
		})
	end

	-- The feel: hover grows, press squashes, release springs back to wherever it should rest.
	local hovered = false
	local pressed = false
	local running: Tween? = nil
	local function goTo(target: number, info: TweenInfo)
		if running then
			running:Cancel()
		end
		local tween = TweenService:Create(scale, info, { Scale = target })
		running = tween
		tween:Play()
	end
	local function rest(): number
		return if hovered then HOVER_SCALE else 1
	end
	local function release()
		if pressed then
			pressed = false
			goTo(rest(), TweenInfo.new(RELEASE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		end
	end
	button.MouseEnter:Connect(function()
		if not hasPointer() then
			return
		end
		hovered = true
		if not pressed then
			goTo(HOVER_SCALE, TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		end
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		if pressed then
			release()
		else
			goTo(1, TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		end
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		goTo(PRESS_SCALE, TweenInfo.new(PRESS_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end)
	button.MouseButton1Up:Connect(release)
	-- A finger lifted off the button, or dragged away, ends the press too.
	button.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			release()
		end
	end)
	button.Activated:Connect(function()
		Sounds.playUi("Click", CLICK_VOLUME)
		if onClick then
			onClick()
		end
	end)

	if props.Parent then
		button.Parent = props.Parent
	end
	return button, face
end

-- Badges -----------------------------------------------------------------------------------------

-- A small yellow pill with ink text, tilted 8 degrees and bobbing a couple of pixels, for a count
-- or a CLAIM tag on a button's corner. `props` are the outer frame's (Position, AnchorPoint,
-- Parent, Size...); Size defaults to the text's width, 22 tall. The pill inside is what bobs, so
-- moving the returned frame never fights the bob, and the bob ends when the badge is destroyed.
-- Returns the outer frame and the pill's Face.
function Juicy.badge(text: string, props): (Frame, Frame)
	props = props or {}
	local size: UDim2 = props.Size
	if not size then
		local width =
			TextService:GetTextSize(text, BADGE_TEXT_SIZE, Enum.Font.FredokaOne, Vector2.new(1000, BADGE_HEIGHT)).X
		size = UDim2.fromOffset(math.max(BADGE_HEIGHT, math.ceil(width) + BADGE_PADDING), BADGE_HEIGHT)
	end
	local outer = UI.new("Frame", {
		Name = "Badge",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = BADGE_TILT,
		Size = size,
	})
	applyProps(outer, props, { Size = true, Parent = true })

	local pill, face = Juicy.pill("Gold", {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		Radius = size.Y.Offset / 2,
		ZIndex = props.ZIndex,
		Parent = outer,
	})
	Juicy.text(text, {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = JuicyPalette.Ink,
		TextSize = BADGE_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = (props.ZIndex or 1) + 4,
		Parent = face,
	}, 0)

	local bob = TweenService:Create(
		pill,
		TweenInfo.new(BADGE_BOB_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, -BADGE_BOB) }
	)
	bob:Play()
	outer.Destroying:Once(function()
		bob:Cancel()
	end)

	if props.Parent then
		outer.Parent = props.Parent
	end
	return outer, face
end

-- Pulse, pop and count ---------------------------------------------------------------------------

local scaleTweens: { [UIScale]: Tween } = setmetatable({}, { __mode = "k" }) :: any

-- The UIScale pulse and pop share on `gui`, made if it has none.
local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild(SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return UI.new("UIScale", { Name = SCALE_NAME, Scale = 1, Parent = gui })
end

local function playScale(scale: UIScale, info: TweenInfo, goal: number)
	local running = scaleTweens[scale]
	if running then
		running:Cancel()
	end
	local tween = TweenService:Create(scale, info, { Scale = goal })
	scaleTweens[scale] = tween
	tween:Play()
end

-- A quick grow and shrink, 1 to 1.08 and back in a quarter of a second: money coming in, a gift
-- waiting. It scales about `gui`'s AnchorPoint.
function Juicy.pulse(gui: GuiObject)
	local scale = scaleOf(gui)
	scale.Scale = 1
	playScale(
		scale,
		TweenInfo.new(PULSE_TIME / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
		PULSE_SCALE
	)
end

-- Appears from 60 percent and overshoots to full size (0.35 s, Back Out). Scales about `gui`'s
-- AnchorPoint.
function Juicy.pop(gui: GuiObject)
	local scale = scaleOf(gui)
	scale.Scale = POP_FROM
	playScale(scale, TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 1)
end

local counts: { [any]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

local function plainNumber(value: number): string
	return tostring(value)
end

-- Counts `label` from `from` to `to` over `seconds`, easing out, writing format(value) each frame
-- (the whole number nearest, then exactly `to`). `label` is a TextLabel, or a BitmapText (anything
-- with a SetText method). Starting a count on a label that is already counting stops the first.
function Juicy.countTo(label: any, from: number, to: number, seconds: number, format: ((number) -> string)?)
	local previous = counts[label]
	if previous then
		previous:Disconnect()
		counts[label] = nil
	end
	local render = format or plainNumber
	local function show(value: number)
		local text = render(value)
		if typeof(label) == "Instance" then
			label.Text = text
		else
			label:SetText(text)
		end
	end
	if seconds <= 0 or from == to then
		show(to)
		return
	end

	local elapsed = 0
	local connection: RBXScriptConnection
	local function stop()
		connection:Disconnect()
		if counts[label] == connection then
			counts[label] = nil
		end
	end
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= seconds then
			stop()
			show(to)
			return
		end
		local t = elapsed / seconds
		local eased = 1 - (1 - t) * (1 - t)
		show(math.floor(from + (to - from) * eased + 0.5))
	end)
	counts[label] = connection
	if typeof(label) == "Instance" then
		label.Destroying:Once(function()
			if counts[label] == connection then
				stop()
			end
		end)
	end
	show(from)
end

return Juicy
