-- Big characterful text in the display face (Lilita One), drawn from its bitmap fonts
-- (alphainstructions/instructions38.md, "The display font"): the money counter, scores and
-- timers in Display_Numbers, headlines and act titles in Display_Headline. Each glyph is two
-- images from two matching atlases: the deep green outline and shadow underneath, and the white
-- face on top, tinted.
-- While a font's atlases aren't uploaded (Config/GuiArt.luau), or the text has a character the
-- font doesn't, it's a live TextLabel in the chunky Fredoka One with a dark outline instead.
--
--   local money = BitmapText.new("Display_Numbers", { TextSize = 40, Color = UI.Colors.Money })
--   money.Frame.Parent = panel
--   money:SetText("$12,450")
--
-- The glyph images are kept and reused, so changing the text (a timer ticking) makes no new ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GuiLayout"))
local Art = require(script.Parent.Art)

local BitmapText = {}
BitmapText.__index = BitmapText

-- The live font when the atlas isn't there: the closest built-in face to Lilita One.
local FALLBACK_FONT = Font.fromEnum(Enum.Font.FredokaOne)
local OUTLINE = Art.color("ink")

export type Options = {
	-- How big, like a TextLabel's TextSize (the font's size in pixels).
	TextSize: number?,
	-- The face's colour (white, as drawn, by default), and the outline's tint (as drawn).
	Color: Color3?,
	OutlineColor: Color3?,
	-- "Left", "Center" or "Right" in the frame. Up and down, the capitals sit in the middle.
	XAlignment: string?,
	-- Shrink to fit the frame's width, rather than run past it.
	Fit: boolean?,
	ZIndex: number?,
}

export type BitmapText = typeof(setmetatable(
	{} :: {
		Frame: Frame,
		font: any,
		ready: boolean,
		text: string,
		options: Options,
		glyphs: { { outline: ImageLabel, face: ImageLabel } },
		fallback: TextLabel?,
		connection: RBXScriptConnection?,
	},
	BitmapText
))

-- A frame that shows text in `fontName` ("Display_Numbers" or "Display_Headline"). `props` are
-- the frame's (Size, Position, Parent...).
function BitmapText.new(fontName: string, options: Options?, props: { [string]: any }?): BitmapText
	local font, ready = Art.font(fontName)
	local frame = Instance.new("Frame")
	frame.Name = fontName
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(200, 48)
	local given: { [string]: any } = props or {}
	for key, value in given do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	local self = setmetatable({
		Frame = frame,
		font = font,
		ready = ready and font ~= nil,
		text = "",
		options = table.clone(options or {}),
		glyphs = {},
		fallback = nil,
		connection = nil,
	}, BitmapText)
	self.connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	if given.Parent then
		frame.Parent = given.Parent
	end
	return self
end

-- The live label, made the first time it's needed.
function BitmapText._live(self: BitmapText): TextLabel
	local label = self.fallback
	if label then
		return label
	end
	local options = self.options
	local size = options.TextSize or 32
	label = Instance.new("TextLabel")
	label.Name = "Live"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FALLBACK_FONT
	label.TextSize = size
	label.TextColor3 = options.Color or Color3.new(1, 1, 1)
	label.TextXAlignment = (Enum.TextXAlignment :: any)[options.XAlignment or "Left"]
	label.ZIndex = options.ZIndex or 1
	if options.Fit then
		label.TextScaled = true
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = size
		constraint.Parent = label
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = math.max(1, math.floor(size / 16))
	stroke.Parent = label
	label.Parent = self.Frame
	self.fallback = label
	return label
end

-- The glyph images for the `index`th glyph (made the first time, reused after).
function BitmapText._glyph(self: BitmapText, index: number)
	local pair = self.glyphs[index]
	if pair then
		return pair
	end
	local zIndex = self.options.ZIndex or 1
	local function layer(name: string, image: string, z: number): ImageLabel
		local label = Instance.new("ImageLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Image = image
		label.ZIndex = z
		label.Parent = self.Frame
		return label
	end
	pair = {
		outline = layer("Outline", Art.image(self.font.outline), zIndex),
		face = layer("Face", Art.image(self.font.face), zIndex + 1),
	}
	self.glyphs[index] = pair
	return pair
end

-- How much the UIScales on `gui` and everything it's in scale it on the screen: its AbsoluteSize
-- over this is its size in its own pixels, the ones its children's offsets are in.
function BitmapText.scaleOf(gui: Instance): number
	local scale = 1
	local current: Instance? = gui
	while current and not current:IsA("LayerCollector") do
		local uiScale = current:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		current = current.Parent
	end
	return scale
end

function BitmapText._layout(self: BitmapText)
	local options = self.options
	local prepared = if self.ready then GuiLayout.prepare(self.font, self.text) else nil
	if not prepared then
		-- The live font: no glyphs.
		for _, pair in self.glyphs do
			pair.outline.Visible = false
			pair.face.Visible = false
		end
		local label = self:_live()
		label.Text = self.text
		label.Visible = true
		return
	end
	if self.fallback then
		self.fallback.Visible = false
	end
	-- Set out in the frame's own pixels: a UIScale over it (a HUD column fitting a phone, a piece's
	-- scale) scales the glyphs along with everything else.
	local box = self.Frame.AbsoluteSize / math.max(BitmapText.scaleOf(self.Frame), 0.01)
	local scale = GuiLayout.scaleFor(self.font, options.TextSize or 32)
	local line = GuiLayout.text(self.font, prepared, scale)
	if options.Fit and box.X > 0 and line.width > box.X then
		scale *= box.X / line.width
		line = GuiLayout.text(self.font, prepared, scale)
	end
	local x = GuiLayout.align(line.width, box.X, options.XAlignment or "Left")
	local y = GuiLayout.centreCaps(line, box.Y)
	local color = options.Color or Color3.new(1, 1, 1)
	local outline = options.OutlineColor or Color3.new(1, 1, 1)
	for index, quad in line.quads do
		local pair = self:_glyph(index)
		for _, image in { pair.outline, pair.face } do
			image.Position = UDim2.fromOffset(math.floor(x + quad.x + 0.5), math.floor(y + quad.y + 0.5))
			image.Size = UDim2.fromOffset(math.ceil(quad.width), math.ceil(quad.height))
			image.ImageRectOffset = Vector2.new(quad.atlasX, quad.atlasY)
			image.ImageRectSize = Vector2.new(quad.atlasWidth, quad.atlasHeight)
			image.Visible = true
		end
		pair.face.ImageColor3 = color
		pair.outline.ImageColor3 = outline
	end
	for index = #line.quads + 1, #self.glyphs do
		self.glyphs[index].outline.Visible = false
		self.glyphs[index].face.Visible = false
	end
end

function BitmapText.SetText(self: BitmapText, text: string)
	if text ~= self.text then
		self.text = text
		self:_layout()
	end
end

function BitmapText.SetColor(self: BitmapText, color: Color3)
	if self.options.Color ~= color then
		self.options.Color = color
		if self.fallback then
			self.fallback.TextColor3 = color
		end
		for _, pair in self.glyphs do
			pair.face.ImageColor3 = color
		end
	end
end

function BitmapText.SetTextSize(self: BitmapText, size: number)
	if self.options.TextSize ~= size then
		self.options.TextSize = size
		if self.fallback then
			self.fallback.TextSize = size
			local constraint = self.fallback:FindFirstChildOfClass("UITextSizeConstraint")
			if constraint then
				constraint.MaxTextSize = size
			end
		end
		self:_layout()
	end
end

function BitmapText.Destroy(self: BitmapText)
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	self.Frame:Destroy()
end

return BitmapText
