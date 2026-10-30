-- The HUD's two columns, down the left and down the right of the screen (UiLayout's LeftColumn and
-- RightColumn), and the rules every piece in them shares: where a piece goes (placeInColumn), how a
-- column shrinks to fit a short screen (fitColumn), what counts as a short screen (shortScreen), and
-- the hit strips that keep a small control in a column at least HIT_MIN px tall to a thumb
-- (addHitStrips). HudController builds the columns when it starts (Columns.build), before any piece.
--
--   Columns.placeInColumn(frame, "MoneyPanel")
--   Columns.addHitStrips(button, onActivate, "RightColumn")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local UI = require(script.Parent.Parent.UI)

local Columns = {}

-- The columns down each side are full size on screens at least `fullHeight` tall (in pixels), and
-- shrink on shorter ones (phones held sideways), down to `minScale`, or further (to `tightScale`)
-- if that's what it takes to fit everything in a column on the screen. A piece taken out of its
-- column shrinks the same way on its own.
local COLUMNS = UI.Layout.__screen.scaling.Columns
-- Every control that acts has a hit area at least this many pixels tall once its column's scale is
-- applied (addHitStrips); a chip that only shows is exempt.
local HIT_MIN = 40
local HIT_CLICK_VOLUME = 0.4

-- How tall the game's own screen is (the camera's view, until the screen has a size).
local function screenHeight(): number
	local height = UI.getScreen().AbsoluteSize.Y
	if height <= 0 then
		local camera = workspace.CurrentCamera
		height = if camera then camera.ViewportSize.Y else COLUMNS.fullHeight
	end
	return height
end

-- A screen too short for the HUD at full size, like a phone held sideways: curb appeal hides there
-- during a job, and the job tracker is laid out small, so the tracker and the phone buttons fit.
function Columns.shortScreen(): boolean
	return screenHeight() < COLUMNS.fullHeight
end

-- Scales a column, or a piece taken out of one, to fit (UiLayout's __screen.scaling.Columns): full
-- size on a tall screen, smaller on a short one, and smaller still if it wouldn't otherwise fit in
-- the screen's height less a margin, a bigger one on a touch screen so it ends above Roblox's move
-- stick and jump button. Its own scale (UiLayout's `scale`) multiplies into that.
local function fitColumn(gui: GuiObject, id: string)
	local scale = UI.scaler(gui)
	local margin = if UI.isTouch() then COLUMNS.touchMargin else COLUMNS.margin
	local function fit()
		local height = screenHeight()
		local wanted = math.clamp(height / COLUMNS.fullHeight, COLUMNS.minScale, 1)
		-- Its own height, before scaling.
		local content = gui.AbsoluteSize.Y / math.max(scale.Scale, 0.01)
		if content > 0 then
			wanted = math.min(wanted, math.max(COLUMNS.tightScale, (height - margin) / content))
		end
		wanted *= UI.layout(id).scale
		if math.abs(scale.Scale - wanted) > 0.005 then
			scale.Scale = wanted
		end
	end
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

-- The two columns, by their names in UiLayout.
local columns: { [string]: Frame } = {}

-- The money and level panel, the menu buttons and the goal stack in one column down the left, so
-- they can't run into each other on a short screen (a phone held sideways), and it shrinks to fit.
function Columns.build()
	local side = UI.new("Frame", { Name = "Side", BackgroundTransparency = 1, Parent = UI.getScreen() })
	UI.keepPlaced(side, "LeftColumn")
	fitColumn(side, "LeftColumn")
	columns.LeftColumn = side

	-- Curb appeal and the job tracker down the right. It scales from its top right corner, so it
	-- stays in the corner.
	local right = UI.new("Frame", { Name = "Right", BackgroundTransparency = 1, Parent = UI.getScreen() })
	UI.keepPlaced(right, "RightColumn")
	fitColumn(right, "RightColumn")
	columns.RightColumn = right
end

-- Puts one of the columns' pieces (its UiLayout entry's `detach` says which column it belongs in)
-- where its entry says: in that column while the entry has it as its `parent`, or otherwise on
-- the game's own screen on its own, where it shrinks to fit by the columns' rule, so on a phone it's
-- the size it would be in the column.
function Columns.placeInColumn(gui: GuiObject, id: string)
	local column = columns[UI.layout(id).parent or ""]
	gui.Parent = column or UI.getScreen()
	UI.keepPlaced(gui, id)
	if not column then
		fitColumn(gui, id)
	end
end

-- Gives `button` a hit area at least HIT_MIN px tall once its column is scaled, on a touch screen: two
-- invisible strips just above and below it (children of it, so they follow it and its visibility) that
-- do what it does, each as tall as the missing part needs. Its width is enough already. The strips lie
-- over the card or the gap around the button, never over another control. `column` is the column it is
-- in, by its name in UiLayout.
function Columns.addHitStrips(button: TextButton, onActivate: () -> (), column: string)
	local scale = columns[column]:FindFirstChildOfClass("UIScale")
	local strips: { TextButton } = {}
	for _, below in { false, true } do
		local strip = UI.new("TextButton", {
			Name = if below then "HitBelow" else "HitAbove",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AnchorPoint = Vector2.new(0, if below then 0 else 1),
			Position = UDim2.fromScale(0, if below then 1 else 0),
			Size = UDim2.fromScale(1, 0),
			Visible = false,
			Parent = button,
		})
		strip.Activated:Connect(function()
			Sounds.playUi("Click", HIT_CLICK_VOLUME)
			onActivate()
		end)
		table.insert(strips, strip)
	end
	local function fit()
		local factor = if scale then math.max(scale.Scale, 0.01) else 1
		local extra = 0
		if UI.isTouch() then
			extra = math.max(0, math.ceil((HIT_MIN / factor - button.Size.Y.Offset) / 2))
		end
		for _, strip in strips do
			strip.Size = UDim2.new(1, 0, 0, extra)
			strip.Visible = extra > 0
		end
	end
	if scale then
		scale:GetPropertyChangedSignal("Scale"):Connect(fit)
	end
	UI.CompactChanged:Connect(fit)
	fit()
end

return Columns
