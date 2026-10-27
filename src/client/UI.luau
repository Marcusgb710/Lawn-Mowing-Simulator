-- The game's look ("Maple Grove Summer", alphainstructions/instructions38.md) and small helpers for
-- building UI in code: colours from the art's palette, the fonts, and windows, cards, buttons,
-- tabs and bars drawn with the art's kit (Art.luau), plus price tags, tier badges, a tool's
-- condition, rubber stamps and sparkles. Any piece of art that isn't uploaded yet is drawn with
-- plain rounded frames in the same colours instead, so the game looks finished either way, and
-- uploading the art (Config/GuiArt.luau) changes nothing else. Where each piece of the play
-- screen goes is in UiLayout.luau, and UI.place puts it there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuiLayout = require(Shared:WaitForChild("GuiLayout"))
local Signal = require(Shared:WaitForChild("Signal"))
local Art = require(script.Parent.Art)
local BitmapText = require(script.Parent.BitmapText)
local UiLayout = require(script.Parent.UiLayout)

local UI = {}

-- Fired when a menu opens or closes. In first person the mouse is locked to the middle of the
-- screen, so CameraController frees it while a menu is open (see UI.needsCursor).
UI.CursorChanged = Signal.new()

local palette = Art.color
UI.Colors = {
	Background = palette("panel"), -- windows and HUD panels
	Panel = palette("panel"):Lerp(palette("card"), 0.45), -- panes inside a window
	Card = palette("card"),
	LockedCard = palette("locked_card"),
	Accent = palette("accent"), -- grass green: highlights, bars, "GOAL"
	AccentDark = palette("accent_dark"),
	Primary = palette("primary_face"), -- a green button's face
	Money = palette("money"),
	Danger = palette("danger"),
	DangerFace = palette("danger_face"), -- a red button's face
	Disabled = palette("disabled"),
	Info = palette("info"),
	Text = palette("text"), -- cream
	SubText = palette("subtext"),
	Ink = palette("ink"), -- the deep green outline, and dark text on light faces
	Robux = palette("gold"),
	-- The story's dialogue box, speech bubbles and texts (DialogueController, the Messages app).
	Outline = palette("ink"), -- the dark edge around boxes, bubbles and name tags
	Letterbox = palette("ink"):Lerp(Color3.new(0, 0, 0), 0.55),
	Track = palette("ink"):Lerp(palette("panel"), 0.35), -- an empty progress bar
	Bubble = palette("text"),
	BubbleText = palette("ink"),
	-- Grandma June's straw hat (her name tag and sticky note) and its red band.
	Grandma = palette("grandma"),
	HatBand = palette("hat_band"),
	-- TurfKing and Gloria's side: the "Taken by TurfKing" job card, and her side of the contest.
	TurfKing = palette("rival"), -- TurfKing's purple
	Gold = palette("gold"), -- TurfKing's gold
	Rival = Color3.fromRGB(185, 166, 238), -- light purple writing on a dark panel
	RivalFill = palette("rival"), -- her score bars
	-- Each character's color (by their key in Config/Story.luau's Cast): the caption on their
	-- speech bubbles, and their circle where there's no portrait yet.
	Cast = {
		June = palette("grandma"),
		Gloria = palette("rival"),
		Chad = palette("rival"),
		Sam = Color3.fromRGB(110, 190, 180),
		Edna = Color3.fromRGB(232, 160, 184),
		BridgeClub = Color3.fromRGB(168, 200, 232),
		Rossi = Color3.fromRGB(232, 180, 140),
		Nguyen = Color3.fromRGB(170, 210, 190),
		Customer = Color3.fromRGB(232, 160, 184),
		Judge1 = Color3.fromRGB(190, 210, 230),
		Judge2 = Color3.fromRGB(240, 170, 120),
	},
}

-- The fonts. Live text uses two of Roblox's built-in families, picked with the art: DenkOne for
-- headings and Nunito for everything else. A family this Roblox doesn't have falls back to the
-- game's old Fredoka One. The display face (big numbers and headlines) is drawn by BitmapText.
local function family(name: string): (string, Enum.Font)
	local ok, enum = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	if ok and enum then
		return `rbxasset://fonts/families/{name}.json`, enum
	end
	return "rbxasset://fonts/families/FredokaOne.json", Enum.Font.FredokaOne
end
local headingFamily, headingEnum = family(Art.typography.heading)
local bodyFamily, bodyEnum = family(Art.typography.body)
UI.Fonts = {
	Heading = Font.new(headingFamily, Enum.FontWeight.Regular),
	Body = Font.new(bodyFamily, Enum.FontWeight.Regular),
	Medium = Font.new(bodyFamily, Enum.FontWeight.SemiBold),
	Bold = Font.new(bodyFamily, Enum.FontWeight.Bold),
	Heavy = Font.new(bodyFamily, Enum.FontWeight.ExtraBold),
}
-- The body font as an Enum.Font, for TextService:GetTextSize (it measures Fonts.Body exactly),
-- and the heading font's.
UI.Font = bodyEnum
UI.HeadingFont = headingEnum

-- How wide `text` is at `size` in the body font (or the heading font).
function UI.textWidth(text: string, size: number, heading: boolean?): number
	return TextService:GetTextSize(text, size, if heading then headingEnum else bodyEnum, Vector2.new(4000, 1000)).X
end

local screen: ScreenGui = nil
local panels = {}
-- While set, menus open inside this frame (the shop computer's screen) instead of on their own.
local host: Frame? = nil

-- UI.new("Frame", { Size = ... }, { children })
function UI.new(className: string, props, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UI.padding(pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return UI.new(
		"UIPadding",
		{ PaddingTop = amount, PaddingBottom = amount, PaddingLeft = amount, PaddingRight = amount }
	)
end

function UI.list(padding: number?, direction: Enum.FillDirection?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.label(text: string, props): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = UI.Fonts.Bold,
		Text = text,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
	})
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

-- A label in the heading font (DenkOne): titles, names on cards.
function UI.heading(text: string, props): TextLabel
	local label = UI.label(text, { FontFace = UI.Fonts.Heading })
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

-- Where things go -------------------------------------------------------------------------------

-- Where every element on the play screen goes, by name (UiLayout.luau, which the layout editor
-- reads and rewrites), and the rules for the screens they're on (UI.Layout.__screen).
UI.Layout = UiLayout

-- Whether this is a touch screen (a phone or a tablet): the phone buttons show there, and
-- UiLayout's `touch` places are used.
function UI.isTouch(): boolean
	return UserInputService.TouchEnabled
end

-- Whether this is a short screen, like a phone held sideways: the whole screen (the camera's view,
-- as the layout editor counts it) is less than UiLayout's __screen.compactHeight tall, and
-- UiLayout's `compact` places are used.
function UI.isCompact(): boolean
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 0
	return height > 1 and height < UiLayout.__screen.compactHeight
end

export type Placement = {
	anchor: Vector2?,
	position: UDim2?,
	size: UDim2?,
	autoSize: Enum.AutomaticSize?,
	min: Vector2?,
	max: Vector2?,
	order: number?,
	-- How much bigger or smaller it's drawn: 1 unless its entry says.
	scale: number,
}

local function udim2(value: { number }?): UDim2?
	return if value then UDim2.new(value[1], value[2], value[3], value[4]) else nil
end

-- Element `id`'s place on this screen (UiLayout.luau): its own anchor, position, size and scale,
-- with its `touch` ones over them on a touch screen, and its `compact` ones over those on a short
-- screen. `compact` says whether to use the short screen's, for a caller that works it out itself
-- (the dialogue); without it, it's UI.isCompact().
function UI.layout(id: string, compact: boolean?): Placement
	local entry = UiLayout[id]
	if not entry then
		error(`UiLayout.luau has no {id}`, 2)
	end
	if compact == nil then
		compact = UI.isCompact()
	end
	local touch = if UI.isTouch() then entry.touch else nil
	local short = if compact then entry.compact else nil
	local function pick(key: string): any
		return (short and short[key]) or (touch and touch[key]) or entry[key]
	end
	local anchor, min, max, scale = pick("anchor"), entry.min, entry.max, pick("scale")
	return {
		anchor = if anchor then Vector2.new(anchor[1], anchor[2]) else nil,
		position = udim2(pick("position")),
		size = udim2(pick("size")),
		autoSize = if entry.autoSize then (Enum.AutomaticSize :: any)[entry.autoSize] else nil,
		-- A side without a limit can be any size.
		min = if min then Vector2.new(min.width or 0, min.height or 0) else nil,
		max = if max then Vector2.new(max.width or math.huge, max.height or math.huge) else nil,
		order = entry.order,
		scale = if typeof(scale) == "number" then scale else 1,
	}
end

-- The UIScale UI.place gives an element whose `scale` isn't 1, by its name.
local LAYOUT_SCALE = "LayoutScale"

-- The UIScale on `gui` that its own code drives (UI.scaler), if it has one.
local function codeScale(gui: Instance): Instance?
	for _, child in gui:GetChildren() do
		if child:IsA("UIScale") and child.Name ~= LAYOUT_SCALE then
			return child
		end
	end
	return nil
end

-- Puts `gui` where UiLayout.luau says element `id` goes (see UI.layout): its AnchorPoint,
-- Position, Size and AutomaticSize, its limits (a UISizeConstraint), its place in its parent's
-- list, the gaps in its own list, and its scale. What the entry leaves out stays as it is. Returns
-- `gui`. It's placed once: UI.keepPlaced places it again when the screen turns short or tall.
function UI.place<T>(gui: T, id: string, compact: boolean?): T
	local object = gui :: any
	local placement = UI.layout(id, compact)
	if placement.anchor then
		object.AnchorPoint = placement.anchor
	end
	if placement.position then
		object.Position = placement.position
	end
	if placement.size then
		object.Size = placement.size
	end
	if placement.autoSize then
		object.AutomaticSize = placement.autoSize
	end
	if placement.order then
		object.LayoutOrder = placement.order
	end
	if placement.min or placement.max then
		local limits = object:FindFirstChildOfClass("UISizeConstraint")
			or UI.new("UISizeConstraint", { Parent = object })
		limits.MinSize = placement.min or Vector2.zero
		limits.MaxSize = placement.max or Vector2.new(math.huge, math.huge)
	end
	local list = UiLayout[id].list
	if list then
		local layout = object:FindFirstChildOfClass("UIListLayout") or UI.list()
		layout.FillDirection = (Enum.FillDirection :: any)[list.direction or "Vertical"]
		layout.Padding = UDim.new(0, list.padding or 0)
		layout.HorizontalAlignment = (Enum.HorizontalAlignment :: any)[list.align or "Left"]
		layout.Parent = object
	end
	-- Its scale, as a UIScale of its own: Roblox draws it and what's in it that much bigger or
	-- smaller about its AnchorPoint, and a list it's in makes room for it at that size. One whose
	-- code scales it already (UI.scaler) multiplies its scale into that instead, since Roblox only
	-- honours one UIScale on an element.
	local layoutScale = object:FindFirstChild(LAYOUT_SCALE)
	if placement.scale ~= 1 and not codeScale(object) then
		if not layoutScale then
			layoutScale = UI.new("UIScale", { Name = LAYOUT_SCALE, Parent = object })
		end
		layoutScale.Scale = placement.scale
	elseif layoutScale then
		layoutScale:Destroy()
	end
	return gui
end

-- A UIScale for `gui` that its own code drives, to fit it to the screen or to pop it in, starting
-- at `scale` (1 by default). It takes the place of the LayoutScale UI.place gives an element with a
-- `scale`, so the code multiplies its element's scale (UI.layout(id).scale) into what it sets, and
-- UI.place leaves this one alone.
function UI.scaler(gui: GuiObject, scale: number?): UIScale
	local layoutScale = gui:FindFirstChild(LAYOUT_SCALE)
	if layoutScale then
		layoutScale:Destroy()
	end
	return UI.new("UIScale", { Scale = scale or 1, Parent = gui })
end

-- Takes away the scale UI.place gave `gui`, for while it's drawn at a size it doesn't decide (a
-- menu filling the shop computer's screen). Placing it again gives it back.
function UI.unscale(gui: GuiObject)
	local layoutScale = gui:FindFirstChild(LAYOUT_SCALE)
	if layoutScale then
		layoutScale:Destroy()
	end
end

-- Fired with UI.isCompact() when the screen turns short or tall, once what's placed with
-- UI.keepPlaced has been placed again: anything that places itself listens, to do it again.
UI.CompactChanged = Signal.new()

-- What's placed with UI.keepPlaced and has compact places, by its element: placed again when the
-- screen turns short or tall.
local kept: { [Instance]: string } = {}
local wasCompact: boolean? = nil
local function followScreen()
	if wasCompact ~= nil then
		return
	end
	wasCompact = UI.isCompact()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local compact = UI.isCompact()
		if compact == wasCompact then
			return
		end
		wasCompact = compact
		for gui, id in kept do
			UI.place(gui, id)
		end
		UI.CompactChanged:Fire(compact)
	end)
end

-- Puts `gui` where element `id` goes, like UI.place, and again whenever the screen turns short or
-- tall (a window resized), so its `compact` places follow the screen. For anything that isn't
-- moved again once it's placed; what moves itself listens to UI.CompactChanged instead.
function UI.keepPlaced<T>(gui: T, id: string): T
	local object = gui :: any
	UI.place(object, id)
	followScreen()
	if UiLayout[id].compact and not kept[object] then
		kept[object] = id
		object.Destroying:Connect(function()
			kept[object] = nil
		end)
	end
	return gui
end

-- Kit pieces -------------------------------------------------------------------------------

-- The kit piece each image shows, so its slice scale can be fitted again when it changes size.
local sliceOf: { [ImageLabel]: Art.Slice } = setmetatable({} :: any, { __mode = "k" })

-- Keeps a 9-slice's corners in proportion when it's drawn smaller than the art (a thin button,
-- a short card): its slice scale shrinks so the corners never overlap.
local function fitSlice(image: ImageLabel)
	local slice = sliceOf[image]
	local center = slice and slice.center
	local size = image.AbsoluteSize
	if not (slice and center and size.X > 0 and size.Y > 0) then
		return
	end
	local fixed = Vector2.new(center.Min.X + slice.size.X - center.Max.X, center.Min.Y + slice.size.Y - center.Max.Y)
	image.SliceScale =
		math.min(GuiLayout.sliceScale(fixed.X, size.X, slice.scale), GuiLayout.sliceScale(fixed.Y, size.Y, slice.scale))
end

-- Calls `loaded` once `image` has downloaded (straight away if it already has). Phones fetch new
-- art slowly the first time, so what the art replaces stays up until then. IsLoaded doesn't
-- reliably say when it changes, so the images still waiting are looked at a few times a second.
local waiting: { [ImageLabel]: () -> () } = setmetatable({} :: any, { __mode = "k" })
local watching = false
local LOAD_CHECK = 0.25
local function whenLoaded(image: ImageLabel, loaded: () -> ())
	if image.IsLoaded then
		loaded()
		return
	end
	waiting[image] = loaded
	if watching then
		return
	end
	watching = true
	task.spawn(function()
		while next(waiting) ~= nil do
			task.wait(LOAD_CHECK)
			for waitingImage, done in waiting do
				if waitingImage.IsLoaded then
					waiting[waitingImage] = nil
					done()
				end
			end
		end
		watching = false
	end)
end
UI.whenLoaded = whenLoaded

-- Makes `image` show the kit piece `slice` (a 9-slice, or a piece that scales evenly), its corners
-- kept in proportion as it changes size.
local function applySlice(image: ImageLabel, slice: Art.Slice)
	local first = sliceOf[image] == nil
	sliceOf[image] = slice
	image.Image = slice.image
	image.BackgroundTransparency = 1
	if slice.center then
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = slice.center
		image.SliceScale = slice.scale
	else
		image.ScaleType = Enum.ScaleType.Stretch
	end
	if first then
		image:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			fitSlice(image)
		end)
	end
	fitSlice(image)
end
UI.applySlice = applySlice

export type Fallback = {
	color: Color3?,
	transparency: number?,
	radius: number?,
	stroke: Color3?,
	strokeThickness: number?,
}

-- A frame drawn as the kit piece `name` (a 9-slice from Art.slice). While that isn't uploaded, a
-- plain frame in `fallback.color` with round corners (and an outline in `fallback.stroke`).
function UI.sliced(name: string, props, fallback: Fallback?): GuiObject
	local slice = Art.slice(name)
	local plain = fallback or {}
	local frame: GuiObject
	if slice then
		local image = UI.new("ImageLabel", {}) :: ImageLabel
		applySlice(image, slice)
		frame = image
		-- Until the art has downloaded, the plain frame's look stands in for it.
		if not image.IsLoaded then
			image.BackgroundColor3 = plain.color or UI.Colors.Background
			image.BackgroundTransparency = plain.transparency or 0
			local corner = UI.corner(plain.radius or 8)
			corner.Parent = image
			whenLoaded(image, function()
				image.BackgroundTransparency = 1
				corner:Destroy()
			end)
		end
	else
		frame = UI.new("Frame", {
			BackgroundColor3 = plain.color or UI.Colors.Background,
			BackgroundTransparency = plain.transparency or 0,
			BorderSizePixel = 0,
		}, { UI.corner(plain.radius or 8) })
		if plain.stroke then
			UI.new("UIStroke", {
				Color = plain.stroke,
				Thickness = plain.strokeThickness or 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = frame,
			})
		end
	end
	for key, value in props or {} do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	if props and props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

-- A card in a list: "Card", or "Card_Selected" / "Card_Locked". Plain: a Card-coloured frame.
function UI.card(props, kind: string?): GuiObject
	local name = if kind then `Card_{kind}` else "Card"
	local color = if kind == "Locked" then UI.Colors.LockedCard else UI.Colors.Card
	return UI.sliced(name, props, { color = color, radius = 8 })
end

-- A white glyph (Icons/<name>.png) tinted `color`, or nil while it isn't uploaded (whoever asked
-- leaves room for it only when there is one).
function UI.icon(name: string, props, color: Color3?): ImageLabel?
	return UI.glyph(Art.icon(name), props, color, name)
end

-- The same, by the glyph's image id (from Art.icon), for glyphs looked up from a table.
function UI.glyph(image: string, props, color: Color3?, name: string?): ImageLabel?
	if image == "" then
		return nil
	end
	local icon = UI.new("ImageLabel", {
		Name = name or "Icon",
		Image = image,
		ImageColor3 = color or UI.Colors.Text,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(24, 24),
	})
	for key, value in props or {} do
		if key ~= "Parent" then
			icon[key] = value
		end
	end
	if props and props.Parent then
		icon.Parent = props.Parent
	end
	return icon
end

-- A picture (an item, a portrait, an app icon...) by its image id, fitted into its frame, or nil
-- while it isn't uploaded.
function UI.picture(image: string, props): ImageLabel?
	if image == "" then
		return nil
	end
	local picture = UI.new("ImageLabel", {
		Image = image,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
	})
	for key, value in props or {} do
		if key ~= "Parent" then
			picture[key] = value
		end
	end
	if props and props.Parent then
		picture.Parent = props.Parent
	end
	return picture
end

-- Big text in the display face (BitmapText): "Numbers" for money, scores and timers, "Headline"
-- for headlines. `props` are its frame's.
function UI.display(kind: string, text: string, options: BitmapText.Options?, props): BitmapText.BitmapText
	local display = BitmapText.new(`Display_{kind}`, options, props)
	display:SetText(text)
	return display
end

-- A finished wordmark ("JobComplete", "Act2"...) as tall as `height`, or until it's uploaded the
-- same words in the display face. Returns its frame.
function UI.wordmark(name: string, text: string, height: number, props): GuiObject
	local image = Art.wordmark(name)
	local frame: GuiObject
	if image ~= "" then
		frame = UI.new("ImageLabel", {
			Name = name,
			Image = image,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(math.floor(height * Art.aspect(`Wordmarks/{name}.png`)), height),
		})
	else
		local headline = UI.display(
			"Headline",
			text,
			{ TextSize = height * 0.95, Color = UI.Colors.Text, XAlignment = "Center", Fit = true },
			{ Name = name, Size = UDim2.new(1, 0, 0, height) }
		)
		frame = headline.Frame
	end
	for key, value in props or {} do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	if props and props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

-- Buttons ----------------------------------------------------------------------------------

-- How a button can look: its kit piece (and the darker one it sinks to while held), and its face
-- and text colours when drawn plain.
local BUTTON_STYLES = {
	Primary = { art = "Button_Primary", pressed = "Button_Primary_Pressed", face = "Primary", text = "Text" },
	Money = { art = "Button_Money", pressed = "Button_Money_Pressed", face = "Money", text = "Ink" },
	Danger = { art = "Button_Danger", pressed = "Button_Danger_Pressed", face = "DangerFace", text = "Text" },
	Neutral = { art = "Button_Neutral", pressed = "Button_Neutral_Pressed", face = "Card", text = "Text" },
	Disabled = { art = "Button_Disabled", pressed = "Button_Disabled_Pressed", face = "Disabled", text = "Text" },
	Robux = { art = "Button_Robux", pressed = "Button_Robux_Pressed", face = "Robux", text = "Ink" },
	Tab = { art = "Tab", face = "Card", text = "Text" },
	TabActive = { art = "Tab_Active", face = "Primary", text = "Text" },
	Menu = { art = "MenuButton", face = "Background", text = "Text" },
}
UI.ButtonStyles = BUTTON_STYLES

-- The style a button colour stands for, for buttons made (or changed) with a BackgroundColor3.
local function styleFor(color: Color3?): string
	local colors = UI.Colors
	if color == colors.Money then
		return "Money"
	elseif color == colors.Accent or color == colors.Primary or color == colors.AccentDark then
		return "Primary"
	elseif color == colors.Danger or color == colors.DangerFace then
		return "Danger"
	elseif color == colors.Disabled then
		return "Disabled"
	elseif color == colors.Robux then
		return "Robux"
	end
	return "Neutral"
end

-- The text properties a button's own text has, which a button with art copies onto the label
-- drawn over the art (a child is always drawn over its parent, text and all).
local MIRRORED = {
	Text = true,
	TextColor3 = true,
	TextSize = true,
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = true,
	TextYAlignment = true,
	TextTruncate = true,
	RichText = true,
	FontFace = true,
	LineHeight = true,
	TextStrokeColor3 = true,
	TextStrokeTransparency = true,
}
-- Room for a glyph beside a button's text.
local ICON_GAP = 6

type ButtonInfo = {
	style: string,
	skin: ImageLabel?,
	label: TextLabel?,
	icon: ImageLabel?,
	iconSize: number,
	padding: UIPadding?,
	ownPadding: boolean,
	pressed: boolean,
}
local buttons: { [TextButton]: ButtonInfo } = setmetatable({} :: any, { __mode = "k" })

-- Where a button's glyph sits: beside the text in the left padding, or in the middle of a button
-- with no text.
local function placeIcon(button: TextButton, info: ButtonInfo)
	local icon = info.icon
	if not icon then
		return
	end
	local drop = if info.pressed then 1 else 0
	if button.Text == "" then
		-- Centred on the whole button, whatever room the padding keeps for a glyph beside words.
		local padding = info.padding
		local shift = if padding then (padding.PaddingLeft.Offset - padding.PaddingRight.Offset) / 2 else 0
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, -shift, 0.5, drop)
	else
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, -(info.iconSize + ICON_GAP), 0.5, drop)
	end
end

-- The skin fills the whole button, padding and all.
local function fitSkin(info: ButtonInfo)
	local skin, padding = info.skin, info.padding
	if not skin then
		return
	end
	if padding then
		local left, top = padding.PaddingLeft.Offset, padding.PaddingTop.Offset
		skin.Position = UDim2.fromOffset(-left, -top)
		skin.Size = UDim2.new(1, left + padding.PaddingRight.Offset, 1, top + padding.PaddingBottom.Offset)
	else
		skin.Position = UDim2.new()
		skin.Size = UDim2.fromScale(1, 1)
	end
end

-- Takes on a UIPadding put in the button: the skin reaches past it, and a glyph sits in it.
local function adoptPadding(button: TextButton, info: ButtonInfo, padding: UIPadding)
	if info.padding == padding then
		return
	end
	if info.padding and info.ownPadding then
		info.padding:Destroy()
	end
	info.padding = padding
	info.ownPadding = false
	if info.icon and button.Text ~= "" then
		padding.PaddingLeft = UDim.new(0, padding.PaddingLeft.Offset + info.iconSize + ICON_GAP)
	end
	fitSkin(info)
	placeIcon(button, info)
end

local function setPressed(button: TextButton, info: ButtonInfo, pressed: boolean)
	if info.pressed == pressed then
		return
	end
	info.pressed = pressed
	local style = BUTTON_STYLES[info.style]
	local art = Art.slice(if pressed and style.pressed then style.pressed else style.art)
	if info.skin and art then
		info.skin.Image = art.image
	end
	-- The pressed art's face is 2 source pixels (1 on screen) lower: the text sinks with it.
	if info.label then
		info.label.Position = UDim2.fromOffset(0, if pressed then 1 else 0)
	end
	placeIcon(button, info)
end

-- Sets a button's style ("Primary", "Money", "Danger", "Neutral", "Disabled", "Robux", "Tab",
-- "TabActive", "Menu"): its art, or its face colour, and its text colour.
function UI.setStyle(button: TextButton, style: string)
	local info = buttons[button]
	local look = BUTTON_STYLES[style] or BUTTON_STYLES.Neutral
	if info then
		info.style = style
	end
	button.BackgroundColor3 = UI.Colors[look.face]
	button.TextColor3 = UI.Colors[look.text]
	if info then
		local art = Art.slice(if info.pressed and look.pressed then look.pressed else look.art)
		if info.skin and art then
			applySlice(info.skin, art)
		end
	end
end

-- Draws a button with its art (and a glyph): its own text is hidden, and a label over the art
-- copies it, so callers can keep setting button.Text and friends.
local function dress(button: TextButton, info: ButtonInfo, glyph: string)
	local style = BUTTON_STYLES[info.style]
	local art = Art.slice(style.art)
	if art then
		button.AutoButtonColor = false
		local skin = UI.new("ImageLabel", { Name = "Skin", ZIndex = 1 })
		applySlice(skin, art)
		skin.Parent = button
		info.skin = skin
		-- The plain face (its colour and round corners) shows until the art has downloaded.
		whenLoaded(skin, function()
			button.BackgroundTransparency = 1
			local corner = button:FindFirstChildOfClass("UICorner")
			if corner then
				corner:Destroy()
			end
		end)
	end
	local label = UI.new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	for property in MIRRORED do
		(label :: any)[property] = (button :: any)[property]
	end
	label.Parent = button
	info.label = label
	button.TextTransparency = 1
	if glyph ~= "" then
		info.icon = UI.new("ImageLabel", {
			Name = "Icon",
			Image = glyph,
			ImageColor3 = button.TextColor3,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(info.iconSize, info.iconSize),
			ZIndex = 2,
			Parent = button,
		})
		if button.Text ~= "" then
			local padding = UI.new("UIPadding", {
				Name = "IconRoom",
				PaddingLeft = UDim.new(0, 8 + info.iconSize + ICON_GAP),
				PaddingRight = UDim.new(0, 8),
			})
			info.padding = padding
			info.ownPadding = true
			padding.Parent = button
		end
	end
	fitSkin(info)
	placeIcon(button, info)
	for _, child in button:GetChildren() do
		if child:IsA("UIPadding") and child ~= info.padding then
			adoptPadding(button, info, child)
		end
	end
	button.ChildAdded:Connect(function(child)
		if child:IsA("UIPadding") then
			adoptPadding(button, info, child)
		elseif child:IsA("UITextSizeConstraint") then
			child:Clone().Parent = label
		end
	end)
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			setPressed(button, info, true)
		end
	end)
	button.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			setPressed(button, info, false)
		end
	end)
	button.MouseLeave:Connect(function()
		setPressed(button, info, false)
	end)
end

-- A button. `props` are the TextButton's, plus:
--   Style      "Primary" (the default), "Money", "Danger", "Neutral", "Disabled", "Robux"... (see
--              UI.setStyle); a BackgroundColor3 from UI.Colors picks one too
--   Icon       a glyph's name (Icons/<name>.png) to show beside the text, or alone if it has none
--   IconImage  any image to show there instead (an app's icon)
--   IconSize   how big the glyph is (20 by default)
-- With the art uploaded it's drawn with the kit's button, sinking while it's held down.
function UI.button(text: string, onClick: () -> (), props): TextButton
	props = props or {}
	local style = props.Style or (if props.BackgroundColor3 then styleFor(props.BackgroundColor3) else "Primary")
	local look = BUTTON_STYLES[style] or BUTTON_STYLES.Primary
	local glyph = props.IconImage or (if props.Icon then Art.icon(props.Icon) else "")
	local button = UI.new("TextButton", {
		BackgroundColor3 = UI.Colors[look.face],
		FontFace = UI.Fonts.Heavy,
		Text = text,
		TextColor3 = UI.Colors[look.text],
		TextSize = 18,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(110, 36),
	}, { UI.corner(8) })
	for key, value in props do
		if key ~= "Parent" and key ~= "Style" and key ~= "Icon" and key ~= "IconImage" and key ~= "IconSize" then
			button[key] = value
		end
	end
	-- The style's face, whatever colour picked it (a green button's face is the darker green).
	button.BackgroundColor3 = UI.Colors[look.face]
	local info: ButtonInfo = {
		style = style,
		skin = nil,
		label = nil,
		icon = nil,
		iconSize = props.IconSize or 20,
		padding = nil,
		ownPadding = false,
		pressed = false,
	}
	buttons[button] = info
	if Art.slice(look.art) or glyph ~= "" then
		dress(button, info, glyph)
	end
	button.Changed:Connect(function(property)
		local label = info.label
		if label and MIRRORED[property] then
			(label :: any)[property] = (button :: any)[property]
			if property == "TextColor3" and info.icon then
				info.icon.ImageColor3 = button.TextColor3
			elseif property == "Text" then
				placeIcon(button, info)
			end
		elseif property == "BackgroundColor3" then
			-- A colour set later picks the style, as it would have when it was made (setting the
			-- style's own face colour, as UI.setStyle does, keeps the style).
			local current = BUTTON_STYLES[info.style]
			if not (current and button.BackgroundColor3 == UI.Colors[current.face]) then
				UI.setStyle(button, styleFor(button.BackgroundColor3))
			end
		end
	end)
	button.Activated:Connect(onClick)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

-- A round phone button (TouchButton, or TouchButton_Small when `small`) with a glyph in it and
-- its words under it, like the art's Snip and Pick up. Plain, it's a round green button with the
-- words in it. Set its words with button.Text, and its glyph with UI.setTouchIcon.
function UI.touchButton(text: string, icon: string?, props, small: boolean?): TextButton
	local art = Art.slice(if small then "TouchButton_Small" else "TouchButton")
	local glyph = if icon then Art.icon(icon) else ""
	local button = UI.new("TextButton", {
		BackgroundColor3 = UI.Colors.Primary,
		FontFace = UI.Fonts.Heavy,
		Text = text,
		TextColor3 = UI.Colors.Text,
		TextSize = 22,
		TextWrapped = true,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(110, 110),
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	for key, value in props or {} do
		if key ~= "Parent" then
			button[key] = value
		end
	end
	if art and glyph ~= "" then
		button.AutoButtonColor = false
		button.TextTransparency = 1
		local skin = UI.new("ImageLabel", { Name = "Skin", Size = UDim2.fromScale(1, 1), Parent = button })
		applySlice(skin, art)
		-- Until the art has downloaded, the plain round green button shows behind the glyph, so
		-- there's always something to tap.
		whenLoaded(skin, function()
			button.BackgroundTransparency = 1
		end)
		local image = UI.new("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.46, 0.46),
			Image = glyph,
			ImageColor3 = UI.Colors.Text,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
			Parent = button,
		})
		local caption = UI.label(text, {
			Name = "Caption",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.new(1, 40, 0, 24),
			FontFace = UI.Fonts.Heavy,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = UI.Colors.Ink,
			TextStrokeTransparency = 0.2,
			ZIndex = 2,
			Parent = button,
		})
		button:GetPropertyChangedSignal("Text"):Connect(function()
			caption.Text = button.Text
		end)
		-- Held down, it darkens and its glyph sinks a little.
		local function press(down: boolean)
			skin.ImageColor3 = if down then Color3.fromRGB(215, 215, 215) else Color3.new(1, 1, 1)
			image.Position = UDim2.new(0.5, 0, 0.5, if down then 2 else 0)
		end
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				press(true)
			end
		end)
		button.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				press(false)
			end
		end)
	end
	if props and props.Parent then
		button.Parent = props.Parent
	end
	return button
end

-- Changes a round phone button's glyph (an Icons name).
function UI.setTouchIcon(button: TextButton, icon: string)
	local image = button:FindFirstChild("Icon")
	local glyph = Art.icon(icon)
	if image and image:IsA("ImageLabel") and glyph ~= "" and image.Image ~= glyph then
		image.Image = glyph
	end
end

-- Greys a round phone button out (with its art) or turns it grey (plain) when what it does won't
-- work there.
function UI.setTouchBlocked(button: TextButton, blocked: boolean)
	local skin = button:FindFirstChild("Skin")
	if skin and skin:IsA("ImageLabel") then
		local tint = if blocked then Color3.fromRGB(150, 150, 150) else Color3.new(1, 1, 1)
		if skin.ImageColor3 ~= tint then
			skin.ImageColor3 = tint
		end
	else
		local face = if blocked then UI.Colors.Disabled else UI.Colors.Primary
		if button.BackgroundColor3 ~= face then
			button.BackgroundColor3 = face
		end
	end
end

-- A tab along the top of a menu (a shop category), with a glyph if it has one. Show which one's
-- picked with UI.setTab.
function UI.tab(text: string, icon: string?, onClick: () -> (), props): TextButton
	local options = {
		Style = "Tab",
		Icon = icon,
		IconSize = 18,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 16,
		FontFace = UI.Fonts.Bold,
	}
	for key, value in props or {} do
		options[key] = value
	end
	local tab = UI.button(text, onClick, options)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = tab })
	return tab
end

function UI.setTab(tab: TextButton, active: boolean)
	UI.setStyle(tab, if active then "TabActive" else "Tab")
end

-- Look-at prompts ---------------------------------------------------------------------------

export type PromptLine = { key: string?, text: string, blocked: boolean? }
export type Prompt = { frame: Frame, set: (lines: { PromptLine }) -> () }

-- The look-at prompt under the dot: a line for each thing you can do ("[E] Take  Reel Push
-- Mower", "[R] Take one out"), red with the reason when it won't work. With its art each line is a
-- Prompt pill (Prompt_Blocked when it won't work) with the key in a KeyBadge; plain, it's the
-- words with a dark edge, as it's always been. `props` are its frame's (it grows downwards).
-- Setting the same lines again changes nothing, so it can be set every frame.
function UI.prompt(props): Prompt
	local holder = UI.new("Frame", {
		Name = "Prompt",
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	for key, value in props or {} do
		if key ~= "Parent" then
			holder[key] = value
		end
	end
	holder.Parent = props and props.Parent
	local shown = ""
	if not Art.slice("Prompt") then
		local label = UI.label("", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			TextSize = 17,
			TextStrokeTransparency = 0.4,
			Parent = holder,
		})
		return {
			frame = holder,
			set = function(lines: { PromptLine })
				local parts = {}
				for _, line in lines do
					table.insert(parts, (if line.key then `[{line.key}] ` else "") .. line.text)
				end
				local text = table.concat(parts, "\n")
				local blocked = lines[1] ~= nil and lines[1].blocked == true
				if text .. tostring(blocked) ~= shown then
					shown = text .. tostring(blocked)
					label.Text = text
					label.TextColor3 = if blocked then UI.Colors.Danger else UI.Colors.Text
				end
			end,
		}
	end
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	local pills = {}
	local function pill(index: number)
		local made = pills[index]
		if made then
			return made
		end
		local frame = UI.sliced("Prompt", {
			Size = UDim2.fromOffset(0, 46),
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = index,
			Parent = holder,
		})
		UI.new("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			Parent = frame,
		})
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
		local badge = UI.sliced("KeyBadge", {
			Size = UDim2.fromOffset(34, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			Parent = frame,
		}, { color = UI.Colors.Ink, radius = 8 })
		local key = UI.heading("", {
			Size = UDim2.fromOffset(34, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = badge,
		})
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = key })
		local text = UI.label("", {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.XY,
			FontFace = UI.Fonts.Heavy,
			TextSize = 19,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = frame,
		})
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge), Parent = text })
		made = { frame = frame :: ImageLabel, badge = badge, key = key, text = text, blocked = false }
		pills[index] = made
		return made
	end
	return {
		frame = holder,
		set = function(lines: { PromptLine })
			local signature = {}
			for _, line in lines do
				table.insert(signature, `{line.key or ""}|{line.text}|{line.blocked == true}`)
			end
			local text = table.concat(signature, "\n")
			if text == shown then
				return
			end
			shown = text
			for index, line in lines do
				local made = pill(index)
				made.frame.Visible = true
				made.badge.Visible = line.key ~= nil
				made.key.Text = line.key or ""
				made.text.Text = line.text
				local blocked = line.blocked == true
				if blocked ~= made.blocked then
					made.blocked = blocked
					local art = Art.slice(if blocked then "Prompt_Blocked" else "Prompt")
					if art then
						made.frame.Image = art.image
					end
				end
			end
			for index = #lines + 1, #pills do
				pills[index].frame.Visible = false
			end
		end,
	}
end

-- Progress bars -----------------------------------------------------------------------------

-- What a bar fills with: mowing stripes in green, gold (money), TurfKing's purple, or your side
-- and Gloria's in the contest. Plain, a solid colour.
local FILLS = {
	Grass = { art = "ProgressFill", color = "Accent" },
	Money = { art = "ProgressFill_Money", color = "Money" },
	TurfKing = { art = "ProgressFill_TurfKing", color = "RivalFill" },
	Danger = { art = "ProgressFill_Money", color = "Danger", tint = "Danger" },
	You = { art = "ScoreFill_You", color = "Accent" },
	Rival = { art = "ScoreFill_Rival", color = "RivalFill" },
}

export type Bar = {
	frame: GuiObject,
	set: (fraction: number) -> (),
	fill: (kind: string) -> (),
}

-- A progress bar: a track (`track`: "ProgressTrack" or "ScoreTrack") and a fill of `kind` whose
-- stripes tile across it rather than stretch. `props` are the track's (its height should be an
-- offset). Returns the track, and functions to set how full it is and what it fills with.
function UI.bar(props, kind: string?, track: string?): Bar
	local frame = UI.sliced(track or "ProgressTrack", props, { color = UI.Colors.Track, radius = 6 })
	frame.ClipsDescendants = true
	local inset = if Art.slice(track or "ProgressTrack") then 2 else 0
	local fill: GuiObject = nil
	local fraction = 0
	local current = ""
	-- The striped fill's tile size at its own height, while it has one.
	local tile: { number }? = nil
	local function size()
		fill.Size = UDim2.new(fraction, -inset * 2 * fraction, 1, -inset * 2)
	end
	local function fitTiles()
		local height = frame.AbsoluteSize.Y
		if tile and fill:IsA("ImageLabel") then
			fill.TileSize = UDim2.new(0, GuiLayout.tileWidth(tile, if height > 0 then height else tile[2]), 1, 0)
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTiles)
	local function setKind(name: string)
		if name == current then
			return
		end
		current = name
		local look = FILLS[name] or FILLS.Grass
		local art = Art.slice(look.art)
		if fill then
			fill:Destroy()
		end
		tile = if art then art.tile else nil
		if art and art.tile then
			fill = UI.new("ImageLabel", {
				Name = "Fill",
				Image = art.image,
				ImageColor3 = if look.tint then UI.Colors[look.tint] else Color3.new(1, 1, 1),
				ScaleType = Enum.ScaleType.Tile,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, inset),
			})
			fitTiles()
		else
			fill = UI.new("Frame", {
				Name = "Fill",
				BackgroundColor3 = UI.Colors[look.color],
				BorderSizePixel = 0,
			}, { UI.corner(6) })
		end
		size()
		fill.Parent = frame
	end
	setKind(kind or "Grass")
	return {
		frame = frame,
		set = function(value: number)
			fraction = math.clamp(value, 0, 1)
			size()
		end,
		fill = setKind,
	}
end

-- Screens and menus -----------------------------------------------------------------------------

function UI.getScreen(): ScreenGui
	if not screen then
		screen = UI.new("ScreenGui", {
			Name = "LawnUI",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
	end
	return screen
end

-- The window's title band (the Panel art's darker top) and where its content starts, docked in
-- the shop computer or on its own.
local function panelTop(docked: boolean): number
	if Art.slice("Panel") then
		return if docked then 50 else 58
	end
	return if docked then 40 else 52
end

-- A window with a title and close button, where every menu's goes (UiLayout's MenuWindow).
-- Returns the window and its content frame.
function UI.panel(name: string, title: string)
	local window = UI.sliced("Panel", {
		Name = name,
		Visible = false,
		Parent = host or UI.getScreen(),
	}, { color = UI.Colors.Background, radius = 12 })
	UI.place(window, "MenuWindow")
	followScreen()
	UI.heading(title, {
		Name = "Title",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 32),
		TextSize = 28,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = window,
	})

	local closeArt = Art.icon("Close") ~= ""
	UI.button(if closeArt then "" else "X", function()
		UI.close(name)
	end, {
		Name = "Close",
		Style = "Danger",
		Icon = "Close",
		IconSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		Parent = window,
	})

	local top = panelTop(false)
	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, top),
		Size = UDim2.new(1, -32, 1, -(top + 16)),
		Parent = window,
	})

	panels[name] = window
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		UI.CursorChanged:Fire()
	end)
	return window, content
end

function UI.scrollingList(parent: Instance, props): ScrollingFrame
	local frame = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Colors.SubText,
		Parent = parent,
	}, { UI.list(8) })
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function UI.clearList(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Puts a menu inside the host frame (filling it, with a slimmer title so a phone's small screen
-- has room for the list), or back on the screen on its own.
local function dock(panel: GuiObject)
	local docked = host ~= nil
	panel.Parent = host or UI.getScreen()
	if docked then
		-- The whole of the computer's screen, however big that is, so not at its own scale.
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromScale(1, 1)
		local constraint = panel:FindFirstChildOfClass("UISizeConstraint")
		if constraint then
			constraint.MaxSize = Vector2.new(math.huge, math.huge)
		end
		UI.unscale(panel)
	else
		UI.place(panel, "MenuWindow")
	end
	local edge, top = if docked then 10 else 16, panelTop(docked)
	local title = panel:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Position = UDim2.fromOffset(edge + (if docked then 4 else 0), if docked then 6 else 10)
		title.Size = UDim2.new(1, -80, 0, if docked then 32 else 32)
		title.TextSize = if docked then 24 else 28
	end
	local close = panel:FindFirstChild("Close")
	if close and close:IsA("GuiObject") then
		close.Position = if docked then UDim2.new(1, -8, 0, 6) else UDim2.new(1, -10, 0, 10)
		close.Size = if docked then UDim2.fromOffset(34, 34) else UDim2.fromOffset(36, 36)
	end
	local content = panel:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		content.Position = UDim2.fromOffset(edge, top)
		content.Size = UDim2.new(1, -edge * 2, 1, -(top + edge))
	end
end

-- Whether menus are showing inside the shop computer's screen: someone's at the computer.
function UI.hosted(): boolean
	return host ~= nil
end

-- Shows menus inside `frame` (the shop computer's screen) until it's set back to nil.
function UI.setHost(frame: Frame?)
	host = frame
	for _, panel in panels do
		dock(panel)
	end
	UI.CursorChanged:Fire()
end

-- On their own, the menus' windows follow the screen turning short or tall, like what's placed
-- with UI.keepPlaced. Docked, they fill the computer's screen whatever the screen is.
UI.CompactChanged:Connect(function()
	if not host then
		for _, panel in panels do
			UI.place(panel, "MenuWindow")
		end
	end
end)

-- Only one panel is open at a time.
function UI.open(name: string)
	for otherName, panel in panels do
		panel.Visible = otherName == name
	end
end

function UI.close(name: string)
	if panels[name] then
		panels[name].Visible = false
	end
end

function UI.toggle(name: string)
	if panels[name] and panels[name].Visible then
		UI.close(name)
	else
		UI.open(name)
	end
end

function UI.isOpen(name: string): boolean
	return panels[name] ~= nil and panels[name].Visible
end

function UI.anyOpen(): boolean
	for _, panel in panels do
		if panel.Visible then
			return true
		end
	end
	return false
end

function UI.closeAll()
	for _, panel in panels do
		panel.Visible = false
	end
end

-- A menu's window, to change its title.
function UI.panelWindow(name: string): GuiObject?
	return panels[name]
end

-- Things besides menus that need the mouse free while they're up (the dialogue box), by name.
local cursorHolders: { [string]: boolean } = {}
function UI.holdCursor(reason: string, held: boolean)
	cursorHolders[reason] = if held then true else nil
	UI.CursorChanged:Fire()
end

-- Whether a menu (or the shop computer, or the dialogue box) is open, which needs the mouse to
-- click on.
function UI.needsCursor(): boolean
	return host ~= nil or UI.anyOpen() or next(cursorHolders) ~= nil
end

-- Hides the game's own screen (the HUD, menus, the dot) and the hotbar while something else
-- takes over the screen: the drive cutscene, or a dialogue. Each says why, so one ending doesn't
-- bring them back while the other's still up.
local hiders: { [string]: boolean } = {}
-- Roblox's hotbar (the Backpack) is only for switching between your loaded tools on a job site.
-- Everywhere else you carry one thing at a time, and its slot would just be a dark box.
local hotbarWanted = false
local function showHotbar()
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, hotbarWanted and next(hiders) == nil)
end
function UI.hideGame(reason: string, hidden: boolean)
	hiders[reason] = if hidden then true else nil
	UI.getScreen().Enabled = next(hiders) == nil
	showHotbar()
end

-- Whether Roblox's hotbar shows (when nothing's hiding the game): on a job site, not elsewhere.
function UI.setHotbar(wanted: boolean)
	hotbarWanted = wanted
	showHotbar()
end

-- A story line (Config/Story.luau) for a RichText label: its `*highlights*` in the highlight
-- color, and anything RichText would read as a tag escaped.
function UI.highlight(text: string, color: Color3?): string
	local escaped = string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" })
	local hex = (color or UI.Colors.Money):ToHex()
	return (string.gsub(escaped, "%*(.-)%*", `<font color="#{hex}">%1</font>`))
end

-- Toasts and big moments ---------------------------------------------------------------------

-- Little messages pop up in a stack near the top of the screen (UiLayout's Toasts). Toasts have a
-- screen of their own, above the shop computer's monitor (so its replies show) but under the
-- drive cutscene.
local toastScreen: ScreenGui = nil
local toastHolder: Frame = nil
-- What the toasts stay below (see UI.keepToastsBelow), and how far below it they start.
local toastsUnder: GuiObject? = nil
local TOAST_GAP = 8
local function placeToasts()
	if not toastHolder then
		return
	end
	local base = UI.layout("Toasts").position :: UDim2
	local under = toastsUnder
	if under and under.Visible then
		-- In pixels down the screen: where the stack would start, and just under `under`.
		local top = base.Y.Scale * toastScreen.AbsoluteSize.Y + base.Y.Offset
		local below = under.AbsolutePosition.Y + under.AbsoluteSize.Y + TOAST_GAP
		if below > top then
			toastHolder.Position = base + UDim2.fromOffset(0, below - top)
			return
		end
	end
	toastHolder.Position = base
end
local function toastStack(): Frame
	if not toastHolder then
		toastScreen = UI.new("ScreenGui", {
			Name = "Toasts",
			ResetOnSpawn = false,
			DisplayOrder = 5,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		toastHolder = UI.new("Frame", {
			Name = "Toasts",
			BackgroundTransparency = 1,
			Parent = toastScreen,
		})
		UI.keepPlaced(toastHolder, "Toasts")
		placeToasts()
		-- Placed again when the screen turns short or tall, then under the coach again.
		UI.CompactChanged:Connect(placeToasts)
	end
	return toastHolder
end

-- Keeps the toasts just below `gui` while it shows (the first-job coach at the top of the
-- screen), so they never sit on top of it.
function UI.keepToastsBelow(gui: GuiObject)
	toastsUnder = gui
	for _, property in { "AbsoluteSize", "AbsolutePosition", "Visible" } do
		gui:GetPropertyChangedSignal(property):Connect(placeToasts)
	end
	placeToasts()
end

-- Puts a toast of your own (a CanvasGroup, as wide as the stack) in the stack for `seconds`, then
-- fades it out: a new text in the Messages app, say.
function UI.toast(toast: CanvasGroup, seconds: number)
	toast.Parent = toastStack()
	task.delay(seconds, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.4), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		toast:Destroy()
	end)
end

-- The toast's background: the Toast kit piece, or a plain dark frame. Goes first in a toast.
function UI.toastBackground(parent: Instance)
	local back = UI.sliced(
		"Toast",
		{ Name = "Back", Size = UDim2.fromScale(1, 1), Parent = parent },
		{ color = UI.Colors.Background, transparency = 0.1, radius = 10 }
	)
	return back
end

local TOAST_TEXT = 17
function UI.notify(message: string)
	-- As tall as the message wraps to (the stack is at most its max width, less the padding), in
	-- the stack's own pixels, before its scale.
	local placement = UI.layout("Toasts")
	local stack = toastStack().AbsoluteSize.X / placement.scale
	local max = placement.max
	local widest = if max then max.X else stack
	local width = (if stack > 100 then math.min(widest, stack) else widest) - 32
	local lines = TextService:GetTextSize(message, TOAST_TEXT, UI.Font, Vector2.new(math.max(100, width - 12), 1000))
	local toast = UI.new("CanvasGroup", {
		Name = "Notice",
		Size = UDim2.new(1, 0, 0, math.max(40, lines.Y + 20)),
		BackgroundTransparency = 1,
	})
	UI.toastBackground(toast)
	UI.label(message, {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -32, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = TOAST_TEXT,
		ZIndex = 2,
		Parent = toast,
	})
	UI.toast(toast, 3.5)
end

-- A big moment over the middle of the screen for a couple of seconds: a wordmark ("LevelUp",
-- "NewTool", "Payday", "Act2"...) with `text` as its fallback, and a line under it.
local momentHolder: Frame? = nil
function UI.moment(name: string, text: string, subtitle: string?, seconds: number?)
	toastStack()
	if momentHolder then
		momentHolder:Destroy()
	end
	local holder = UI.new("CanvasGroup", {
		Name = "Moment",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = toastScreen,
	})
	UI.place(holder, "Moment")
	momentHolder = holder
	local words = UI.wordmark(name, text, 84, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = holder,
	})
	-- A little burst of sparkles over the words as they pop in.
	UI.sparkle(words, 7, 34)
	if subtitle then
		UI.label(subtitle, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 92),
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = 24,
			FontFace = UI.Fonts.Heavy,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = UI.Colors.Ink,
			TextStrokeTransparency = 0.3,
			Parent = holder,
		})
	end
	-- It pops in from a little smaller, to its own scale (UiLayout's Moment).
	local size = UI.layout("Moment").scale
	local scale = UI.scaler(holder, 0.6 * size)
	local pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(scale, pop, { Scale = size }):Play()
	TweenService:Create(holder, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	task.delay(seconds or 2.4, function()
		if momentHolder ~= holder then
			return
		end
		local fade = TweenService:Create(holder, TweenInfo.new(0.4), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		holder:Destroy()
		if momentHolder == holder then
			momentHolder = nil
		end
	end)
end

-- Sparkles -------------------------------------------------------------------------------------

-- The sparkle sheet (Moments/Sparkle), and where each of its frames is on it: they play once, left
-- to right then top to bottom.
local sparkleSheet, sparkleImage = Art.sheet("Sparkle")
local sparkleFrame = Vector2.new(128, 128)
local SPARKLE_FRAMES: { Vector2 } = {}
if sparkleSheet then
	sparkleFrame = Vector2.new(sparkleSheet.frameSize[1], sparkleSheet.frameSize[2])
	for index = 0, sparkleSheet.frames - 1 do
		local column, row = index % sparkleSheet.columns, index // sparkleSheet.columns
		table.insert(SPARKLE_FRAMES, Vector2.new(column * sparkleFrame.X, row * sparkleFrame.Y))
	end
end
local SPARKLE_STEP = 1 / (if sparkleSheet then sparkleSheet.fps else 12)
-- Plain, a sparkle is a little cream diamond that winks in and out over four steps instead.
local PLAIN_TWINKLE = { 0.5, 0, 0.25, 0.7 }
-- Sparkles that are done, to use again, and ones destroyed along with what they were over.
local sparklePool: { GuiObject } = {}
local sparkleGone: { [GuiObject]: boolean } = setmetatable({} :: any, { __mode = "k" })

local function newSparkle(): GuiObject
	local sprite: GuiObject
	if sparkleImage ~= "" then
		sprite = UI.new("ImageLabel", {
			Image = sparkleImage,
			ImageRectSize = sparkleFrame,
			BackgroundTransparency = 1,
		})
	else
		sprite = UI.new("Frame", { BackgroundColor3 = UI.Colors.Text, BorderSizePixel = 0, Rotation = 45 })
	end
	sprite.Name = "Sparkle"
	sprite.AnchorPoint = Vector2.new(0.5, 0.5)
	sprite.ZIndex = 10
	sprite.Destroying:Connect(function()
		sparkleGone[sprite] = true
	end)
	return sprite
end

-- Plays one sparkle once after `delay` seconds, then puts it away to use again.
local function twinkle(sprite: GuiObject, delay: number)
	task.wait(delay)
	local image = if sprite:IsA("ImageLabel") then sprite else nil
	local steps = if image then #SPARKLE_FRAMES else #PLAIN_TWINKLE
	for step = 1, steps do
		if sparkleGone[sprite] then
			return
		end
		if image then
			image.ImageRectOffset = SPARKLE_FRAMES[step]
		else
			(sprite :: Frame).BackgroundTransparency = PLAIN_TWINKLE[step]
		end
		sprite.Visible = true
		task.wait(SPARKLE_STEP)
	end
	if not sparkleGone[sprite] then
		sprite.Visible = false
		sprite.Parent = nil
		table.insert(sparklePool, sprite)
	end
end

-- A little burst of sparkles over `parent` (a big moment's words, a stamp, a new tool's card):
-- `count` of them (5 by default) scattered over its box, about `size` pixels across, each playing
-- once at its own moment. `parent` mustn't have a list or grid layout in it. With the art they're
-- the sparkle sheet; plain, little cream diamonds that wink. The sparkles are kept and reused.
function UI.sparkle(parent: GuiObject, count: number?, size: number?)
	local across = size or 28
	for index = 1, count or 5 do
		local sprite = table.remove(sparklePool) or newSparkle()
		local pixels = across * (0.6 + math.random() * 0.6)
		if not sprite:IsA("ImageLabel") then
			-- A diamond's corners reach past its frame.
			pixels *= 0.45
		end
		pixels = math.floor(pixels + 0.5)
		sprite.Size = UDim2.fromOffset(pixels, pixels)
		sprite.Position = UDim2.fromScale(0.1 + math.random() * 0.8, 0.1 + math.random() * 0.8)
		sprite.Visible = false
		sprite.Parent = parent
		task.spawn(twinkle, sprite, (index - 1) * 0.05 + math.random() * 0.12)
	end
end

-- Rubber stamps ----------------------------------------------------------------------------------

export type Stamp = {
	frame: CanvasGroup,
	flash: (name: string, at: Vector2?, sparkles: number?) -> (),
}

-- How long a stamp stays down before it fades, and how it lands: big, then thump.
local STAMP_HOLD = 0.8
local STAMP_LAND = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Rubber stamps that thump down over `parent` and fade away, like the shop's Bought and Sold.
-- `stamps` maps each stamp's wordmark ("Stamp_Bought") to its words, drawn in the display face
-- until it's uploaded; they're all `height` tall. They're made once and reused:
-- stamp.flash(name, at, sparkles) lands one with its middle at `at` (fractions of `parent`'s size,
-- its middle by default), with that many sparkles round it.
function UI.stamp(parent: GuiObject, stamps: { [string]: string }, height: number): Stamp
	local widest = 1
	for name in stamps do
		widest = math.max(widest, Art.aspect(`Wordmarks/{name}.png`))
	end
	-- Room round the stamp for its sparkles (a CanvasGroup cuts off what's outside it).
	local holder = UI.new("CanvasGroup", {
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(math.ceil(height * widest) + 40, height + 40),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local scale = UI.new("UIScale", { Parent = holder })
	local words: { [string]: GuiObject } = {}
	for name, text in stamps do
		words[name] = UI.wordmark(name, text, height, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = false,
			Parent = holder,
		})
	end
	local land = TweenService:Create(scale, STAMP_LAND, { Scale = 1 })
	local show = TweenService:Create(holder, TweenInfo.new(0.1), { GroupTransparency = 0 })
	local hide = TweenService:Create(holder, TweenInfo.new(0.35), { GroupTransparency = 1 })
	hide.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			holder.Visible = false
		end
	end)
	local flashes = 0
	return {
		frame = holder,
		flash = function(name: string, at: Vector2?, sparkles: number?)
			flashes += 1
			local this = flashes
			for other, frame in words do
				frame.Visible = other == name
			end
			local spot = at or Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(math.clamp(spot.X, 0.15, 0.85), math.clamp(spot.Y, 0.12, 0.88))
			holder.Rotation = math.random(-6, 3)
			land:Cancel()
			show:Cancel()
			hide:Cancel()
			scale.Scale = 1.8
			holder.GroupTransparency = 1
			holder.Visible = true
			land:Play()
			show:Play()
			if sparkles then
				UI.sparkle(holder, sparkles)
			end
			task.delay(STAMP_HOLD, function()
				if flashes == this then
					hide:Play()
				end
			end)
		end,
	}
end

-- Prices ----------------------------------------------------------------------------------------

-- A price on a garden plant tag (the kit's PriceTag, with its hole on the left), like the tags in
-- a nursery's pots; plain, a sunflower-yellow tag with round corners. It's as wide as the price,
-- and `props` are its frame's (give it a height). `dim` shades it when the price is out of reach.
function UI.priceTag(text: string, props, dim: boolean?): GuiObject
	local art = Art.slice("PriceTag")
	local tag = UI.sliced("PriceTag", props, { color = UI.Colors.Money, radius = 6 })
	tag.Name = "PriceTag"
	tag.AutomaticSize = Enum.AutomaticSize.X
	UI.new("UIPadding", {
		-- With the art, the price starts past the tag's hole.
		PaddingLeft = UDim.new(0, if art then 22 else 10),
		PaddingRight = UDim.new(0, 10),
		Parent = tag,
	})
	local label = UI.label(text, {
		Name = "Price",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = UI.Fonts.Heavy,
		TextSize = 18,
		TextColor3 = UI.Colors.Ink,
		Parent = tag,
	})
	if dim and art then
		(tag :: ImageLabel).ImageColor3 = Color3.fromRGB(170, 170, 170)
	elseif dim then
		tag.BackgroundColor3 = UI.Colors.Disabled
		label.TextColor3 = UI.Colors.Text
	end
	return tag
end

-- Tiers -----------------------------------------------------------------------------------------

-- Each tier's glyph (a shield with one, two or three chevrons) and colour.
local TIERS = {
	Homeowner = { glyph = Art.icon("Tier_Homeowner"), color = "SubText" },
	Serious = { glyph = Art.icon("Tier_Serious"), color = "Info" },
	Pro = { glyph = Art.icon("Tier_Pro"), color = "Money" },
}

-- A small badge with a tool's or a job's tier ("Homeowner", "Serious" or "Pro"): its glyph and
-- name in the tier's colour on a dark pill (plain, just the name). `props` are its frame's.
function UI.tierBadge(tier: string, props): Frame
	local look = TIERS[tier]
	local color = UI.Colors[if look then look.color else "SubText"]
	local image = if look then look.glyph else ""
	local badge = UI.new("Frame", {
		Name = "Tier",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, {
		UI.corner(12),
		UI.new("UIPadding", {
			PaddingLeft = UDim.new(0, if image ~= "" then 5 else 10),
			PaddingRight = UDim.new(0, 10),
		}),
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 4),
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.glyph(image, { Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = badge }, color)
	UI.label(tier, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 14,
		TextColor3 = color,
		LayoutOrder = 2,
		Parent = badge,
	})
	for key, value in props or {} do
		if key ~= "Parent" then
			(badge :: any)[key] = value
		end
	end
	if props and props.Parent then
		badge.Parent = props.Parent
	end
	return badge
end

-- Tool condition --------------------------------------------------------------------------------

-- The glyph for each part of a tool's condition (Maintenance.parts): a wrecked engine shows the
-- wrench, a sharp blade the Sharp glyph and a dull one the plain blade. A supply's uses have none,
-- so nothing hints at which supply fixes what.
local PART_GLYPHS = {
	Engine = Art.icon("Wrench"),
	Fuel = Art.icon("Fuel"),
	Tire = Art.icon("Tire"),
	Blade = Art.icon("Blade"),
	Line = Art.icon("Spool"),
}
local SHARP_GLYPH = Art.icon("Sharp")
-- The glyph for working on a tool with a supply, by what it does (Maintenance.Supplies' actions).
local ACTION_GLYPHS = {
	Fuel = PART_GLYPHS.Fuel,
	Inflate = PART_GLYPHS.Tire,
	Patch = PART_GLYPHS.Tire,
	SwapTire = PART_GLYPHS.Tire,
	Sharpen = SHARP_GLYPH,
	SwapBlade = PART_GLYPHS.Blade,
	Reload = PART_GLYPHS.Line,
	Repair = PART_GLYPHS.Engine,
}
-- Fine is green, worth a look yellow, and won't work red.
local STATE_COLORS = { Good = "Accent", Low = "Money", Out = "Danger" }

-- A condition part's glyph ("" for none, or while it isn't uploaded) and colour.
function UI.partGlyph(part: string, state: string): (string, Color3)
	local image = if part == "Blade" and state == "Good" then SHARP_GLYPH else PART_GLYPHS[part] or ""
	return image, UI.Colors[STATE_COLORS[state] or "Money"]
end

-- The glyph for working on a tool with a supply that does `action` (the wrench for anything else).
function UI.actionGlyph(action: string?): string
	return if action and ACTION_GLYPHS[action] then ACTION_GLYPHS[action] else PART_GLYPHS.Engine
end

-- A tool's condition on a card (the Truck menu, the shop's): a glyph for each part
-- (Maintenance.parts) in its colour, with the words for what's wrong after it, or "In good shape".
-- Plain, just the words. `props` are its frame's (it's as tall as it wraps to).
function UI.conditionRow(parts: { any }, props): Frame
	local row = UI.new("Frame", {
		Name = "Condition",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	})
	local function words(text: string, color: Color3, order: number, parent: Instance)
		UI.label(text, {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 14,
			TextColor3 = color,
			LayoutOrder = order,
			Parent = parent,
		})
	end
	local said = false
	for index, part in parts do
		local image, color = UI.partGlyph(part.part, part.state)
		if image ~= "" or part.text ~= "" then
			local chip = UI.new("Frame", {
				Size = UDim2.fromOffset(0, 18),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Parent = row,
			}, { UI.list(4, Enum.FillDirection.Horizontal) })
			UI.glyph(image, { Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = chip }, color)
			if part.text ~= "" then
				words(part.text, color, 2, chip)
				said = true
			end
		end
	end
	if not said then
		words("In good shape", UI.Colors.Accent, #parts + 1, row)
	end
	for key, value in props or {} do
		if key ~= "Parent" then
			(row :: any)[key] = value
		end
	end
	if props and props.Parent then
		row.Parent = props.Parent
	end
	return row
end

return UI
