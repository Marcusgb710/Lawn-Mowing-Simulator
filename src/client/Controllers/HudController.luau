-- Always-on screen stuff, laid out like the art's HUD (alphainstructions/instructions38.md):
--   * down the left: the money pill (a gold coin and the money counter in the display face, which
--     counts up when money comes in), under it the level pill (a star, "LVL 3" and the XP bar, one
--     button that opens the Levels panel, LevelsController, with the star gold once you have the gold
--     business sign) beside the streak pill ("DAY 3", once there is a streak), the judging day
--     countdown pill (once judging day is on the calendar), the four menu squares (Truck, Guide,
--     Crew and Contracts: glossy colour squares with their glyphs and names under them, and on a
--     keyboard their keys, T, G, C, on a corner; a column on a PC and a 2x2 grid on a phone; the
--     Contracts one opens the contracts panel, ContractsController, and a yellow badge on it counts
--     the contracts left today), Grandma's sticky note with your story goal and, under it, the goals
--     rail: your next two milestones;
--   * down the right: your business's curb appeal, on a phone the Next chip (the next milestone,
--     where the rail has no room), the job tracker on the art's GoalTracker card (to-dos, a timer
--     against par, damage), smaller on a phone, and under it, late in the mowing, the button that
--     lights up the grass you missed (M on a keyboard);
--   * the condition of the tool in your hands, a glyph for each thing wrong ("Running low on
--     fuel" by the fuel can), or what you're doing to one at the workbench;
--   * the pay breakdown when a job's done, and the big moments: Level Up! (when the server says
--     what the level paid, LevelReward), New Tool!, and a Payday for the Bonus Day (BonusDay) and
--     for each day the streak grows (StreakAdvanced);
--   * cash and XP coming in lift off the piece of the HUD they came from (FloatingText) and ring
--     (Sounds.playUi): the pay panel's total and tip, a goal's row or the Next chip, the Contracts
--     square (ContractDone), the money counter (the streak's day), the level pill and the XP bar.
-- On a keyboard V switches camera motion on and off. Where each piece goes is in UiLayout.luau,
-- which can also take any of the columns' pieces out of its column to go anywhere on the screen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daily = require(Shared.Daily)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Jobs = require(Shared.Config.Jobs)
local Maintenance = require(Shared.Config.Maintenance)
local Milestones = require(Shared.Config.Milestones)
local Net = require(Shared.Net)
local PayBreakdown = require(Shared.PayBreakdown)
local Sounds = require(Shared.Sounds)
local Streak = require(Shared.Config.Streak)
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local FloatingText = require(script.Parent.Parent.FloatingText)
local Goal = require(script.Parent.Parent.Goal)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)
local GrassController = require(script.Parent.GrassController)
local LevelsController = require(script.Parent.LevelsController)

local player = Players.LocalPlayer

-- The menu buttons down the left, their glyphs, the key that opens each one, and its button's
-- place in UiLayout.luau. Jobs and orders are on the computer in your shop (see
-- ComputerController).
local MENUS = {
	{ name = "Truck", key = Enum.KeyCode.T, layout = "TruckButton", color = "Truck" },
	{ name = "Guide", key = Enum.KeyCode.G, layout = "GuideButton", color = "Guide" },
	{ name = "Crew", key = Enum.KeyCode.C, layout = "CrewButton", color = "Crew" },
}
-- The fourth square opens the contracts panel (no key; the mailbox at the curb opens it too).
local CONTRACTS_SQUARE = { name = "Contracts", layout = "ContractsButton", color = "Contracts", icon = "Jobs" }
-- The squares are 76 px faces (UiLayout's TruckButton and the rest are that and the label under it).
-- On a touch or short screen they sit in a 2x2 grid with this much between them across and down; the
-- grid's scale is MenuButtons' own (UiLayout), and check-gui works out from these that a square is
-- 44 px or more on a phone.
local SQUARE_FACE = 76
local SQUARE_GAP_X = 16
local SQUARE_GAP_Y = 8
-- A key badge on a square's top left corner: its size and how far in its middle is.
local SQUARE_KEY_SIZE = 22
local SQUARE_KEY_INSET = 8
-- The Contracts square's count badge hangs this far off its top right corner.
local COUNT_BADGE_OVERHANG = 8
local MOTION_KEY = Enum.KeyCode.V
-- The key for the "Show what I missed" button (see buildMissedButton).
local MISSED_KEY = Enum.KeyCode.M
-- A finished mowing row gets a stamp over it (the art's "Job Complete!", the only stamp that says
-- done), this tall, with this many sparkles round it.
local DONE_STAMP_HEIGHT = 40
local DONE_SPARKLES = 5
-- The goals rail under the story goal: this many milestones, each in a row this tall (its words over
-- a thin bar). A milestone just reached stays on its row, done, under a stamp this tall, for
-- RAIL_HOLD seconds before the rail moves on to the next.
local RAIL_ROWS = 2
local RAIL_ROW_HEIGHT = 32
local RAIL_STAMP_HEIGHT = 24
local RAIL_HOLD = 1.2
-- The Next chip's line is one line of 10 to 14 px words; past this many characters it drops its
-- "Next: " so the rest can stay readable.
local CHIP_LONG_LINE = 24
-- The pay breakdown's three star slots (a job's stars): each is this big, and the stars it earned
-- fill in gold one every STAR_STEP seconds, each landing over that time.
local STAR_GLYPH = "★"
local STAR_SIZE = 44
local STAR_STEP = 0.35
-- Each star's chime is quieter than the default, so up to three ringing together aren't a smudge.
local STAR_VOLUME = 0.35
-- The cash pops on the pay panel come this long after it opens, once it has been laid out and
-- scaled to fit (where its total and tip are is only known then); its chime doesn't wait. The
-- tip's and the XP's are this many pixels tall, under the cash's.
local PAY_POP_DELAY = 0.25
local SMALL_POP = 16
-- A level's cash lifts off the level line this long after the level-up arrives, so it doesn't ride
-- the XP pop off the bar just under it (and lines up with the Level Up moment).
local LEVEL_POP_DELAY = 0.3
-- Contracts paid in the same moment (one job can meet two) ring and pop this far apart, and the Bonus
-- Day after them, so each one is heard and seen on its own and the payoff comes last.
local CONTRACT_GAP = 0.6
-- The columns down each side are full size on screens at least `fullHeight` tall (in pixels), and
-- shrink on shorter ones (phones held sideways), down to `minScale`, or further (to `tightScale`)
-- if that's what it takes to fit everything in a column on the screen. A piece taken out of its
-- column shrinks the same way on its own.
local COLUMNS = UI.Layout.__screen.scaling.Columns
-- Room for the key badge at the left of a menu button.
local KEY_ROOM = 46
-- The money pill and the pills under it (UiLayout's MoneyPanel, StatPills and Countdown, whose heights
-- are these and the 6 px a pill's lip and outline hang below it), in pixels.
local MONEY_PILL = Vector2.new(250, 70)
local LEVEL_PILL = Vector2.new(136, 36)
local STREAK_PILL = Vector2.new(106, 36)
local COUNTDOWN_PILL = Vector2.new(250, 34)
local MONEY_TEXT_SIZE = 38
local PILL_TEXT_SIZE = 17
-- The coin beside the money: its size, and how far in from the pill's left edge and from the money.
local COIN_SIZE = 46
local COIN_LEFT = 12
local COIN_GAP = 10
-- Money that comes in counts up to its new total over this long.
local MONEY_COUNT_TIME = 0.4
-- The level pill: where its words start, where the XP bar starts, and how tall the bar is; and the
-- room the Levels button's hit area takes above and below the pill (the column's gaps are wider).
local LEVEL_TEXT_LEFT = 31
local XP_BAR_LEFT = 87
local XP_BAR_HEIGHT = 10
local LEVELS_BUTTON_REACH = 11
-- The streak pill's flame: how far in its middle is, and how wide its body is.
local FLAME_MIDDLE = 19
local FLAME_WIDTH = 16
-- The countdown is worked out again this often (seconds): it counts down in hours.
local COUNTDOWN_REFRESH = 60
local WHITE = Color3.new(1, 1, 1)
local COIN_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FFF3A8")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFD24A")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("E8A61E")),
})
local FLAME_OUTER = Color3.fromHex("FF5A1F")
local FLAME_INNER = Color3.fromHex("FFE066")
-- On a short screen the job tracker's timer goes beside the job's name, in a box this wide.
local COMPACT_TIMER = 112

local HudController = {}

-- The money counter, the pill it is on, and the money the last profile had (nil before the first), so
-- a gain counts up.
local money
local moneyPill: Frame
local lastMoney: number? = nil
local levelLabel: TextLabel
-- The star on the level pill (an icon, or a letter star while there is no art), gold with the sign.
local levelGlyph: GuiObject
-- The XP bar on the level pill: its track (what XP pops lift off) and how full it is.
local xpBar: { frame: GuiObject, set: (fraction: number) -> () }
local streakPill: Frame
local streakLabel: TextLabel
-- The countdown's piece of the column (hidden when there is nothing to count down to) and its words.
local countdownPanel: Frame
local countdownLabel: TextLabel
-- The XP the last profile had (nil before the first), so a rise can be shown as "+40 XP".
local lastXp: number? = nil
local curbPanel: GuiObject
local curbValue: TextLabel
local curbBar: UI.Bar

local goalNote: GuiObject
local goalText: TextLabel
local goalValue: TextLabel
local goalBar: UI.Bar

-- The goals rail's rows, in order: what each shows now (nil while it's empty) and, while its
-- milestone's being celebrated, that one, which keeps the row until the celebration's over.
type Milestone = Milestones.Milestone
type RailRow = {
	frame: Frame,
	label: TextLabel,
	bar: UI.Bar,
	shown: Milestone?,
	held: Milestone?,
	stamp: UI.Stamp?,
}
local railRows: { RailRow } = {}
-- The Next chip, its label and stamp, and the milestone being celebrated on it, if one is.
local nextChip: GuiObject
local nextChipLabel: TextLabel
local chipStamp: UI.Stamp?
local chipHeld: Milestone?
-- The menu squares' holder, the mouse hint in it (with a keyboard), the Contracts square's face (cash
-- lifts off it) and the count badge on it, with its number, while there are contracts left today.
local menuHolder: Frame
local mouseHint: TextLabel?
local contractsFace: Frame
local contractsBadge: Frame?
local contractsBadgeText: TextLabel?
-- Milestones MilestoneReached has said are reached that the profile doesn't have yet. The server
-- sends the profile first, so this is normally empty; it keeps a late profile from drawing a
-- reached milestone as still to do.
local pending: { [string]: boolean } = {}
-- Where the rail had a milestone the profile says is reached, by its id: the row's index. The
-- profile comes before MilestoneReached and moves the rail on, so this is how the celebration
-- finds the row the milestone was on.
local leftRail: { [string]: number } = {}
-- Whether the rail was last drawn for a short screen, so a window turning short or tall redraws it.
local railCompact: boolean? = nil

local tracker: GuiObject
local trackerPadding: UIPadding
local trackerLayout: UIListLayout
local trackerHeader: Frame
local trackerTitle: TextLabel
local trackerHint: TextLabel
local timerRow: Frame
local timer
local damageRow: Frame
local damageLabel: TextLabel
local taskList: Frame
local taskLayout: UIListLayout
local trackerButton: TextButton
local taskRows = {}
local shownJobId = nil
-- The tracker on a short screen (layoutTracker): the timer beside the job's name, and the damage
-- and a small call-off button sharing a row at the bottom.
local trackerCompact = false
local compactTimer
local compactFooter: Frame
local compactDamage: TextLabel
local compactButton: TextButton
-- What the tracker shows for the job, whichever way it's laid out: the timer and damage (while
-- you work), the damage so far, and whether there's a button to call the job off.
local trackerTimed = false
local trackerPenalty = 0
local callOffShown = false
local conditionPanel: GuiObject
-- The chips on it, one for each thing wrong (a glyph and its words), made as they're needed and
-- then reused.
local conditionChips: { { frame: Frame, glyph: ImageLabel?, label: TextLabel } } = {}
-- The held tool's condition, read from its attributes into the same table each time.
local heldCondition = {}

local payPanel: GuiObject
local payShownFor = nil
local knownTools: { [string]: boolean }? = nil

-- Tool attributes the server keeps up to date (see ToolService), as a condition table.
local CONDITION_ATTRIBUTES =
	{ fuel = "Fuel", pressure = "Pressure", flat = "Flat", sharpness = "Sharpness", line = "Line", broken = "Broken" }

-- A HUD panel: the art's see-through HudPanel, or a plain dark frame.
local function hudPanel(props): GuiObject
	return UI.sliced("HudPanel", props, { color = UI.Colors.Background, transparency = 0.2, radius = 10 })
end

-- The `index`th chip on the condition panel (made the first time, reused after), showing `image`
-- (a glyph's id) and `text` in `color`.
local function setConditionChip(index: number, image: string, text: string, color: Color3)
	local chip = conditionChips[index]
	if not chip then
		local frame = UI.new("Frame", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = conditionPanel,
		}, {
			UI.new("UIListLayout", {
				Padding = UDim.new(0, 6),
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		chip = {
			frame = frame,
			-- No glyph art: the words alone.
			glyph = UI.glyph(UI.actionGlyph(nil), { Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, Parent = frame }),
			label = UI.label("", {
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				TextSize = 16,
				LayoutOrder = 2,
				Parent = frame,
			}),
		}
		conditionChips[index] = chip
	end
	chip.frame.Visible = true
	local glyph = chip.glyph
	if glyph then
		glyph.Visible = image ~= ""
		glyph.Image = image
		glyph.ImageColor3 = color
	end
	chip.label.Text = text
	chip.label.TextColor3 = color
end

-- What's in your hands: carried at the business, or a tool out on a job.
local function heldItemId(): string?
	local carrying = player:GetAttribute("Carrying")
	if typeof(carrying) == "string" then
		return carrying
	end
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ItemId")
	return if typeof(id) == "string" then id else nil
end

-- Shows what's wrong with the tool you're holding (a chip for each thing, yellow when it's worth
-- a look and red when it won't work), or how long until you finish working on one, with the
-- glyph for what you're doing (filling the tank, a tire, sharpening, new line...).
local function updateCondition()
	local shown = 0
	local untilTime = player:GetAttribute("MaintainingUntil")
	if typeof(untilTime) == "number" then
		local left = math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow()))
		local supply = Maintenance.Supplies[heldItemId() or ""]
		setConditionChip(1, UI.actionGlyph(supply and supply.action), `Working on it... {left}s`, UI.Colors.Money)
		shown = 1
	else
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local item = tool and Tools.get(tool:GetAttribute("ItemId"))
		if tool and item then
			for key, attribute in CONDITION_ATTRIBUTES do
				heldCondition[key] = tool:GetAttribute(attribute)
			end
			for _, part in Maintenance.parts(item, heldCondition) do
				if part.state ~= "Good" then
					shown += 1
					local image, color = UI.partGlyph(part.part, part.state)
					setConditionChip(shown, image, part.text, color)
				end
			end
		end
	end
	conditionPanel.Visible = shown > 0
	for index = shown + 1, #conditionChips do
		conditionChips[index].frame.Visible = false
	end
end

local function buildCondition()
	conditionPanel = UI.sliced("Tooltip", {
		Name = "ToolCondition",
		Visible = false,
		Parent = UI.getScreen(),
	}, { color = UI.Colors.Background, transparency = 0.25, radius = 8 })
	UI.keepPlaced(conditionPanel, "ToolCondition")
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = conditionPanel,
	})
	-- The chips side by side in the middle, onto a second line if they don't fit.
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 14),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = true,
		Parent = conditionPanel,
	})
end

-- The columns down each side -------------------------------------------------------------------

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
local function shortScreen(): boolean
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
local function buildColumns()
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
local function placeInColumn(gui: GuiObject, id: string)
	local column = columns[UI.layout(id).parent or ""]
	gui.Parent = column or UI.getScreen()
	UI.keepPlaced(gui, id)
	if not column then
		fitColumn(gui, id)
	end
end

-- The money pill: a gold coin and the money, big and white with an ink outline, on a green pill. The
-- column's piece is a plain frame the size of the pill and its lip (UiLayout's MoneyPanel) and the
-- pill sits in it, so the pill can pulse about its middle without moving the column.
local function buildStats()
	local frame = UI.new("Frame", { Name = "Stats", BackgroundTransparency = 1 })
	placeInColumn(frame, "MoneyPanel")
	local face: Frame
	moneyPill, face = Juicy.pill("Money", {
		Name = "MoneyPill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, MONEY_PILL.Y / 2),
		Size = UDim2.fromOffset(MONEY_PILL.X, MONEY_PILL.Y),
		Parent = frame,
	})
	-- The coin: a round gold gradient with an ink rim and an ink "$".
	local coin = UI.new("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, COIN_LEFT, 0.5, 0),
		Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = face,
	}, {
		UI.corner(COIN_SIZE / 2),
		UI.new("UIGradient", { Color = COIN_GRADIENT, Rotation = 45 }),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Juicy.Palette.Ink,
			Thickness = 3,
		}),
	})
	Juicy.text("$", {
		Name = "Sign",
		Size = UDim2.fromScale(1, 1),
		TextSize = 30,
		TextColor3 = Juicy.Palette.Ink,
		ZIndex = 6,
		Parent = coin,
	}, 0)
	local moneyX = COIN_LEFT + COIN_SIZE + COIN_GAP
	money = UI.display(
		"Numbers",
		"$0",
		{ TextSize = MONEY_TEXT_SIZE, Color = WHITE, OutlineColor = Juicy.Palette.Ink, Fit = true, ZIndex = 5 },
		{
			Position = UDim2.fromOffset(moneyX, 0),
			Size = UDim2.new(1, -moneyX - COIN_GAP - 4, 1, 0),
			ZIndex = 5,
			Parent = face,
		}
	)
end

-- A flame: a round body with a rotated rounded square for its tip, `width` wide, its middle `middle`
-- px in from the left and its bottom `bottom` px down the face.
local function flameShape(parent: GuiObject, color: Color3, middle: number, bottom: number, width: number, z: number)
	local radius = width / 2
	UI.new("Frame", {
		Name = "FlameBody",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(middle, bottom - radius),
		Size = UDim2.fromOffset(width, width),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { UI.corner(radius) })
	local tip = math.round(width * 0.72)
	UI.new("Frame", {
		Name = "FlameTip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(middle, bottom - radius - math.round(width * 0.28)),
		Size = UDim2.fromOffset(tip, tip),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { UI.corner(math.round(tip * 0.18)) })
end

-- The star on the level pill takes its colour (gold with the business's gold sign).
local function colorLevelGlyph(color: Color3)
	if levelGlyph:IsA("ImageLabel") then
		levelGlyph.ImageColor3 = color
	elseif levelGlyph:IsA("TextLabel") then
		levelGlyph.TextColor3 = color
	end
end

-- A pill's words: white Fredoka with an ink stroke, shrinking to fit the room, which starts `left` px
-- in and stops `right` px short of the pill's right edge.
local function pillText(face: Frame, name: string, text: string, left: number, right: number, size: number): TextLabel
	local label = Juicy.text(text, {
		Name = name,
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left - right, 1, 0),
		TextSize = size,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = face,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 9, Parent = label })
	return label
end

-- The pills under the money: the level and streak pills side by side in one piece of the column
-- (UiLayout's StatPills), then the judging day countdown pill (Countdown).
local function buildPills()
	local row = UI.new("Frame", { Name = "StatPills", BackgroundTransparency = 1 })
	placeInColumn(row, "StatPills")

	-- The level pill: a star, "LVL 3" and the XP bar. The Levels button is invisible over it, and
	-- reaches a little above and below it so it is a thumb's size on a phone.
	local levelHolder, levelFace = Juicy.pill("Level", {
		Name = "LevelPill",
		Size = UDim2.fromOffset(LEVEL_PILL.X, LEVEL_PILL.Y),
		LayoutOrder = 1,
		Parent = row,
	})
	local star = UI.icon("Level", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 5,
		Parent = levelFace,
	}, WHITE)
	if not star then
		star = UI.label("★", {
			Name = "Level",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			TextSize = 16,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
			Parent = levelFace,
		})
	end
	levelGlyph = star :: GuiObject
	levelLabel = pillText(levelFace, "Level", "LVL 1", LEVEL_TEXT_LEFT, LEVEL_PILL.X - XP_BAR_LEFT + 4, PILL_TEXT_SIZE)
	-- The XP bar: a dark track and a gold fill.
	local track = UI.new("Frame", {
		Name = "XpBar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, XP_BAR_LEFT, 0.5, 0),
		Size = UDim2.new(1, -XP_BAR_LEFT - 10, 0, XP_BAR_HEIGHT),
		BackgroundColor3 = Juicy.Palette.Ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = levelFace,
	}, { UI.corner(XP_BAR_HEIGHT / 2) })
	local fill = UI.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Juicy.Palette.Badge,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 6,
		Parent = track,
	}, { UI.corner(XP_BAR_HEIGHT / 2) })
	xpBar = {
		frame = track,
		set = function(fraction: number)
			fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		end,
	}
	local levelsButton = UI.new("TextButton", {
		Name = "LevelsButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, -LEVELS_BUTTON_REACH),
		Size = UDim2.new(1, 0, 0, LEVEL_PILL.Y + 2 * LEVELS_BUTTON_REACH),
		ZIndex = 10,
		Parent = levelHolder,
	})
	levelsButton.Activated:Connect(function()
		Sounds.playUi("Click", 0.4)
		LevelsController.toggle()
	end)

	-- The streak pill: a flame (a gold flame inside an orange one, both with an ink rim) and "DAY 3".
	-- It is hidden until there is a streak.
	local face: Frame
	streakPill, face = Juicy.pill("Streak", {
		Name = "StreakPill",
		Size = UDim2.fromOffset(STREAK_PILL.X, STREAK_PILL.Y),
		LayoutOrder = 2,
		Visible = false,
		Parent = row,
	})
	local bottom = STREAK_PILL.Y - 5
	flameShape(face, Juicy.Palette.Ink, FLAME_MIDDLE, bottom + 2, FLAME_WIDTH + 4, 5)
	flameShape(face, FLAME_OUTER, FLAME_MIDDLE, bottom, FLAME_WIDTH, 6)
	flameShape(face, FLAME_INNER, FLAME_MIDDLE, bottom - 2, FLAME_WIDTH / 2, 7)
	streakLabel = pillText(face, "Days", "DAY 1", 38, 8, PILL_TEXT_SIZE)

	-- The countdown pill: a stopwatch and the words. The column's piece is a frame of its own that
	-- hides, so the column closes up when there is nothing to count down to.
	countdownPanel = UI.new("Frame", { Name = "Countdown", BackgroundTransparency = 1, Visible = false })
	placeInColumn(countdownPanel, "Countdown")
	local _, countdownFace = Juicy.pill("Countdown", {
		Name = "CountdownPill",
		Size = UDim2.fromOffset(COUNTDOWN_PILL.X, COUNTDOWN_PILL.Y),
		Parent = countdownPanel,
	})
	UI.icon("Timer", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 5,
		Parent = countdownFace,
	}, WHITE)
	countdownLabel = pillText(countdownFace, "Words", "Judging day", 42, 12, 16)
end

-- Shows the star beside the level in gold while the player has the gold business sign (the server
-- sets GoldSign at level 20).
local function updateGoldSign()
	colorLevelGlyph(if player:GetAttribute("GoldSign") == true then UI.Colors.Gold else WHITE)
end

-- The streak pill: "DAY 3" from the day's view (ClientState.contracts), hidden with no streak.
local function updateStreak()
	local view = ClientState.contracts
	local days = if view and view.streak then view.streak.days or 0 else 0
	streakPill.Visible = days > 0
	if days > 0 then
		streakLabel.Text = `DAY {days}`
	end
end

-- The judging day countdown, from the contest view (ClientState.contest) and this computer's clock:
-- only for someone with judging day on the Saturday calendar, "Judging day in 2d 5h" while it is
-- coming and "Judging day is today!" while it is open.
local function updateCountdown()
	local contest = ClientState.contest
	local text: string? = nil
	if contest and contest.calendar then
		if contest.state == "Open" then
			text = "Judging day is today!"
		elseif contest.state == "Waiting" then
			local now = os.time()
			local target = Daily.nextSaturday(now)
			-- A Saturday they have judged on already looks to the next one.
			if target <= now then
				target = Daily.nextSaturday(Daily.midnightAfter(now))
			end
			local left = target - now
			local days = left // 86400
			local hours = (left % 86400) // 3600
			text = if days > 0
				then `Judging day in {days}d {hours}h`
				elseif hours > 0 then `Judging day in {hours}h`
				else "Judging day in under 1h"
		end
	end
	countdownPanel.Visible = text ~= nil
	if text then
		countdownLabel.Text = text
	end
end

-- Your crew's business's curb appeal (see HomeLawnService), which pays a bonus on jobs.
local function buildCurbAppeal()
	curbPanel = hudPanel({ Name = "CurbAppeal", Visible = false })
	placeInColumn(curbPanel, "CurbAppeal")
	UI.padding(10).Parent = curbPanel
	local icon = UI.icon(
		"CurbAppeal",
		{ Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(0, 4), Parent = curbPanel }
	)
	local x = if icon then 40 else 0
	UI.label("Curb appeal", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x, 0, 18),
		TextSize = 15,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		Parent = curbPanel,
	})
	curbValue = UI.label("", {
		Position = UDim2.fromOffset(x, 18),
		Size = UDim2.new(1, -x, 0, 22),
		TextSize = 20,
		FontFace = UI.Fonts.Heavy,
		Parent = curbPanel,
	})
	curbBar = UI.bar({ Position = UDim2.fromOffset(x, 46), Size = UDim2.new(1, -x, 0, 10), Parent = curbPanel })
end

local function updateCurbAppeal()
	local party = ClientState.party
	local owner = if party then party.leader else player
	local value = owner and owner:GetAttribute("CurbAppeal")
	-- On a short screen (a phone) the job tracker needs the room while a job's on, wherever the two
	-- are placed.
	curbPanel.Visible = typeof(value) == "number" and not (shortScreen() and tracker.Visible)
	if typeof(value) == "number" then
		curbValue.Text = `{value} / 100`
		curbBar.set(value / 100)
	end
end

-- Makes room at the left of a Menu-style button with a glyph for the key that does the same, and on
-- a keyboard shows the key there, in a badge (the glyph goes after it).
local function addKeyBadge(button: TextButton, key: Enum.KeyCode)
	local keyboard = UserInputService.KeyboardEnabled
	local iconRoom = if button:FindFirstChild("Icon") then 26 else 0
	local left = if keyboard then KEY_ROOM else 10
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, left), PaddingRight = UDim.new(0, 8), Parent = button })
	if keyboard then
		local badge = UI.sliced("KeyBadge", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6 - left - iconRoom, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			ZIndex = 3,
			Parent = button,
		}, { color = UI.Colors.Ink, transparency = 0.3, radius = 6 })
		UI.heading(UserInputService:GetStringForKeyCode(key), {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 18,
			ZIndex = 3,
			Parent = badge,
		})
	end
end

-- A key badge on a square's top left corner (the key's name in a small dark square), with a keyboard.
local function addCornerKey(face: Frame, key: Enum.KeyCode)
	if not UserInputService.KeyboardEnabled then
		return
	end
	local badge = UI.sliced("KeyBadge", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(SQUARE_KEY_INSET, SQUARE_KEY_INSET),
		Size = UDim2.fromOffset(SQUARE_KEY_SIZE, SQUARE_KEY_SIZE),
		ZIndex = 8,
		Parent = face,
	}, { color = UI.Colors.Ink, transparency = 0.3, radius = 6 })
	UI.heading(UserInputService:GetStringForKeyCode(key), {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		ZIndex = 9,
		Parent = badge,
	})
end

-- One menu square: a glossy face in its colour with its glyph and its name under it, placed by its
-- UiLayout entry in the holder. Returns the button and its face.
local function buildSquare(spec, onClick: () -> ()): (TextButton, Frame)
	local button, face = Juicy.button(spec.color, onClick, {
		Name = spec.name .. "Button",
		Icon = spec.icon or spec.name,
		Label = spec.name,
		Size = UDim2.fromOffset(SQUARE_FACE, SQUARE_FACE),
		Parent = menuHolder,
	})
	UI.keepPlaced(button, spec.layout)
	return button, face
end

-- The squares are a column on a PC and a 2x2 grid on a touch screen or a short one (the mouse hint
-- goes with the column). UI.place gives the holder its list and its touch and compact size and scale,
-- so this takes the list away for a grid, and gives it back when the screen is tall again.
local function layoutMenu()
	local grid = menuHolder:FindFirstChildOfClass("UIGridLayout")
	local list = menuHolder:FindFirstChildOfClass("UIListLayout")
	local asGrid = UI.isTouch() or UI.isCompact()
	if asGrid then
		if list then
			list:Destroy()
		end
		if not grid then
			UI.new("UIGridLayout", {
				CellSize = UI.layout("TruckButton").size,
				CellPadding = UDim2.fromOffset(SQUARE_GAP_X, SQUARE_GAP_Y),
				FillDirection = Enum.FillDirection.Horizontal,
				FillDirectionMaxCells = 2,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				StartCorner = Enum.StartCorner.TopLeft,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Parent = menuHolder,
			})
		end
	else
		if grid then
			grid:Destroy()
		end
		if not list then
			UI.place(menuHolder, "MenuButtons")
		end
	end
	if mouseHint then
		mouseHint.Visible = not asGrid
	end
end

local function buildMenuButtons()
	menuHolder = UI.new("Frame", { Name = "Menu", BackgroundTransparency = 1 })
	placeInColumn(menuHolder, "MenuButtons")

	for _, menu in MENUS do
		local _button, face = buildSquare(menu, function()
			UI.toggle(menu.name)
		end)
		addCornerKey(face, menu.key)
	end
	local _contracts, face = buildSquare(CONTRACTS_SQUARE, function()
		UI.toggle("Contracts")
	end)
	contractsFace = face
	if UserInputService.KeyboardEnabled then
		-- The mouse is locked to the middle of the screen in first person.
		mouseHint = UI.label("Hold Alt for the mouse", {
			TextSize = 13,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			TextStrokeTransparency = 0.6,
			Parent = menuHolder,
		})
		UI.keepPlaced(mouseHint, "MouseHint")
	end
	layoutMenu()
	UI.CompactChanged:Connect(layoutMenu)
end

-- Grandma's sticky note: your story goal, and how close you are.
local function buildGoal()
	goalNote = UI.sliced("StickyNote", {
		Name = "Goal",
		Visible = false,
	}, { color = UI.Colors.Grandma, radius = 6 })
	placeInColumn(goalNote, "GrandmaGoal")
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 14),
		Parent = goalNote,
	})
	UI.list(4).Parent = goalNote
	local header = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = goalNote,
	})
	local flag = UI.icon("Goal", { Size = UDim2.fromOffset(20, 20), Parent = header }, UI.Colors.Ink)
	local x = if flag then 26 else 0
	UI.heading("GRANDMA'S GOAL", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x, 1, 0),
		TextSize = 18,
		TextColor3 = UI.Colors.Ink,
		Parent = header,
	})
	goalText = UI.label("", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 16,
		FontFace = UI.Fonts.Bold,
		TextColor3 = UI.Colors.Ink,
		LayoutOrder = 2,
		Parent = goalNote,
	})
	goalValue = UI.label("", {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 19,
		FontFace = UI.Fonts.Heavy,
		TextColor3 = UI.Colors.Ink,
		LayoutOrder = 3,
		Parent = goalNote,
	})
	goalBar = UI.bar({ Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 4, Parent = goalNote })
	-- The goals rail under the bar (updateMilestones fills it in): a row for each milestone, one line
	-- of words (they shrink to fit it, up to 15 px) over a thin bar. A row has no list in it, so its
	-- stamp and sparkles go where they're put.
	for index = 1, RAIL_ROWS do
		local frame = UI.new("Frame", {
			Name = `Milestone{index}`,
			Size = UDim2.new(1, 0, 0, RAIL_ROW_HEIGHT),
			BackgroundTransparency = 1,
			Visible = false,
			LayoutOrder = 4 + index,
			Parent = goalNote,
		})
		local label = UI.label("", {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 18),
			TextScaled = true,
			TextSize = 15,
			FontFace = UI.Fonts.Bold,
			TextColor3 = UI.Colors.Ink,
			Parent = frame,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10, Parent = label })
		local bar = UI.bar({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 6), Parent = frame })
		railRows[index] = { frame = frame, label = label, bar = bar }
	end
	-- Out of its column at the top of the screen (on a touch screen), the toasts keep below it.
	UI.keepToastsBelow(goalNote)
end

-- The Next chip: the rail's next milestone on one line in the right column, under curb appeal, on a
-- short screen (a phone held sideways), where the note has no room for the rail. Nothing hides it:
-- it stays up through a job, which curb appeal doesn't.
local function buildNextChip()
	nextChip = UI.sliced("Tooltip", {
		Name = "NextChip",
		Visible = false,
	}, { color = UI.Colors.Background, transparency = 0.25, radius = 8 })
	placeInColumn(nextChip, "NextChip")
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = nextChip,
	})
	nextChipLabel = UI.label("", {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = nextChip,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 10, Parent = nextChipLabel })
end

-- The Contracts square's count badge: how many of today's contracts are left (the day's three less
-- the ones done), a tilted yellow tag on the square's top right corner. It is not there at 0 and
-- before the server has sent the day's contracts. It is built when the count comes from 0 and
-- destroyed when it goes to 0; any other change only sets its number.
local function updateContractsBadge()
	local view = ClientState.contracts
	local left = 0
	if view then
		left = #view.contracts
		for _, contract in view.contracts do
			if contract.done then
				left -= 1
			end
		end
	end
	if left <= 0 then
		if contractsBadge then
			contractsBadge:Destroy()
			contractsBadge = nil
			contractsBadgeText = nil
		end
		return
	end
	local text = tostring(left)
	if contractsBadgeText then
		contractsBadgeText.Text = text
		return
	end
	local badge, badgeFace = Juicy.badge(text, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, COUNT_BADGE_OVERHANG, 0, -COUNT_BADGE_OVERHANG),
		ZIndex = 8,
		Parent = contractsFace,
	})
	contractsBadge = badge
	contractsBadgeText = badgeFace:FindFirstChild("Text") :: TextLabel
end

-- The `count` milestones nearest to done, never one MilestoneReached has said is reached, which a
-- profile that's behind would still list.
local function nextMilestones(count: number): { Milestone }
	local late = 0
	for _ in pending do
		late += 1
	end
	local nearest = {}
	for _, milestone in Goal.milestones(count + late) do
		if #nearest < count and not pending[milestone.id] then
			table.insert(nearest, milestone)
		end
	end
	return nearest
end

-- Draws `milestone` on a rail row: its words and how far along you are, over the bar, or done.
local function fillRailRow(row: RailRow, milestone: Milestone, done: boolean)
	local have, progress = Goal.milestoneProgress(milestone, if done then milestone.at else nil)
	row.label.Text = `{milestone.text}   {progress}`
	row.bar.fill(if done then "Money" else "Grass")
	row.bar.set(have / milestone.at)
end

-- The goals rail and the Next chip, from the profile (Goal.milestones). The rows are hidden on a
-- short screen (shortScreen, the test that hides curb appeal during a job), where the chip shows
-- instead, whenever there's a milestone left. A row that's celebrating keeps its milestone, and
-- the rows after it take the next ones.
local function updateMilestones()
	local compact = shortScreen()
	railCompact = compact
	local profile = ClientState.profile
	local reached = if profile and profile.milestones then profile.milestones else {}
	for id in pending do
		if reached[id] then
			pending[id] = nil
		end
	end
	local free = {}
	for index, row in railRows do
		if not row.held then
			table.insert(free, index)
		end
	end
	local nearest = nextMilestones(#free)
	for place, index in free do
		local row = railRows[index]
		local milestone = nearest[place]
		local before = row.shown
		-- The profile comes before MilestoneReached, so a row can give up a milestone here that
		-- the event hasn't said is reached yet: keep where it was.
		if before and not (milestone and milestone.id == before.id) and (reached[before.id] or pending[before.id]) then
			leftRail[before.id] = index
		end
		row.shown = milestone
		row.frame.Visible = milestone ~= nil and not compact
		if milestone then
			fillRailRow(row, milestone, false)
		end
	end
	local chipMilestone = chipHeld or nextMilestones(1)[1]
	nextChip.Visible = compact and chipMilestone ~= nil
	if chipMilestone then
		local _, progress = Goal.milestoneProgress(chipMilestone, if chipHeld then chipMilestone.at else nil)
		local line = `{if chipHeld then "Done" else "Next"}: {chipMilestone.text} {progress}`
		-- A long line would shrink past reading on a phone, so "Next: " goes (the chip says what it is).
		if not chipHeld and #line > CHIP_LONG_LINE then
			line = `{chipMilestone.text} {progress}`
		end
		nextChipLabel.Text = line
	end
end

-- The row that has the milestone `id` on the rail, or just had it (see leftRail).
local function railRowOf(id: string): RailRow?
	for _, row in railRows do
		if row.shown and row.shown.id == id then
			return row
		end
	end
	local index = leftRail[id]
	return if index then railRows[index] else nil
end

-- A milestone's reached: sparkles and a DONE stamp land on the row it was on, or on the chip on a
-- short screen, and that shows it done for RAIL_HOLD seconds, about as long as the stamp lasts,
-- before the rail goes on to the next. The stamp is only the words DONE (UI.stampText): the art's
-- Job Complete stamp would say "Job Complete!" on a milestone like "Earn $500". The caller
-- redraws. Returns what the stamp landed on (the row's frame, or the chip), or nil where it landed
-- on nothing.
local function celebrateMilestone(milestone: Milestone): GuiObject?
	if shortScreen() then
		chipHeld = milestone
		local stamp = chipStamp or UI.stampText(nextChip, "DONE", RAIL_STAMP_HEIGHT)
		chipStamp = stamp
		UI.sparkle(nextChip, 5, 22)
		stamp.flash("Text")
		task.delay(RAIL_HOLD, function()
			if chipHeld == milestone then
				chipHeld = nil
				updateMilestones()
			end
		end)
		return nextChip
	end
	local row = railRowOf(milestone.id)
	if row and row.held then
		-- Another milestone reached with this one has its row: this one takes the next row that's free.
		row = nil
		for _, other in railRows do
			if not other.held then
				row = other
				break
			end
		end
	end
	if not row then
		return nil
	end
	row.held = milestone
	row.shown = milestone
	fillRailRow(row, milestone, true)
	row.frame.Visible = true
	local stamp = row.stamp or UI.stampText(row.frame, "DONE", RAIL_STAMP_HEIGHT)
	row.stamp = stamp
	UI.sparkle(row.frame, 6, 24)
	stamp.flash("Text")
	task.delay(RAIL_HOLD, function()
		if row.held == milestone then
			row.held = nil
			row.shown = nil
			updateMilestones()
		end
	end)
	return row.frame
end

local function milestoneById(id: string): Milestone?
	for _, milestone in Milestones.List do
		if milestone.id == id then
			return milestone
		end
	end
	return nil
end

-- The server's told us a milestone's reached (`info`: its id, its words and the cash it paid). It
-- rings, and the cash it paid lifts off the row (or the chip) the stamp landed on, or off the money
-- counter where there was no row to land on or it's hidden (on a touch screen the goal's note waits
-- for the first-job coach and a crew invite).
local function onMilestoneReached(info: { id: string, text: string, cash: number })
	pending[info.id] = true
	local milestone = milestoneById(info.id)
	local on = if milestone then celebrateMilestone(milestone) else nil
	leftRail[info.id] = nil
	Sounds.playUi("GoalDone")
	if info.cash > 0 then
		local cash = `+{Format.money(info.cash)}`
		if not (on and FloatingText.show(on, cash)) then
			FloatingText.show(money.Frame, cash)
		end
	end
	updateMilestones()
end

local function updateGoal()
	updateMilestones()
	local goal = Goal.current()
	-- Where it gives way to something else that takes its spot (on a touch screen, the first-job
	-- coach and a crew invite at the top of the screen), it hides while that shows.
	goalNote.Visible = goal ~= nil and not UI.givesWay("GrandmaGoal")
	if not goal then
		return
	end
	goalText.Text = goal.text
	local hasButton = goal.button ~= nil
	goalBar.frame.Visible = not hasButton
	if hasButton then
		-- The contest's: done on the shop computer.
		goalValue.Text = if goal.action == "Start" then "Call the judges from the computer" else "See the computer"
		goalValue.TextSize = 15
		return
	end
	local have, value = Goal.progress(goal)
	goalValue.Text = value
	goalValue.TextSize = 19
	goalBar.set(if goal.need > 0 then have / goal.need else 1)
end

-- "Show what I missed" -------------------------------------------------------------------------

local missedButton: TextButton

-- Lights up the grass that's still tall on the job's lawn for a few seconds.
local function showMissed()
	local folder = GrassController.jobLawnFolder()
	if folder then
		GrassController.highlightUncut(folder, GameConfig.MissedSpotsSeconds)
	end
end

-- The button under the job tracker, with its key on a keyboard. It's only there late in the
-- mowing (see updateMissedButton).
local function buildMissedButton()
	missedButton = UI.button("Show what I missed", showMissed, {
		Name = "MissedButton",
		Style = "Menu",
		Icon = "Goal",
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
	})
	placeInColumn(missedButton, "MissedButton")
	addKeyBadge(missedButton, MISSED_KEY)
end

local function onKey(input: InputObject, processed: boolean)
	-- `processed` is set while typing in chat or a text box. While a scene or the drive cutscene
	-- has the screen, the HUD is hidden and its keys do nothing.
	if processed or not UI.getScreen().Enabled then
		return
	end
	for _, menu in MENUS do
		if input.KeyCode == menu.key then
			UI.toggle(menu.name)
			return
		end
	end
	if input.KeyCode == MISSED_KEY and missedButton.Visible then
		showMissed()
		return
	end
	if input.KeyCode == MOTION_KEY and CameraController.hasMotion() then
		local on = not CameraController.isMotionOn()
		CameraController.setMotion(on)
		UI.notify(if on then "Camera motion on" else "Camera motion off")
	end
end

-- The job tracker --------------------------------------------------------------------------------

local function callOffJob()
	Net.event("AbandonJob"):FireServer()
end

-- A to-do's row: its words over a bar of how far along it is, or on a short screen just the words,
-- on one line.
local function layoutTaskRow(row)
	row.frame.Size = UDim2.new(1, 0, 0, if trackerCompact then 18 else 38)
	row.bar.frame.Visible = not trackerCompact
end

-- Lays the tracker out for the screen and for what it's showing. On a short screen (a phone held
-- sideways) it's small, so the look-at and Snip buttons fit under it: no hint, the timer beside the
-- job's name, each to-do on one line, and the damage (once there is some) and the call-off button
-- sharing a slim row at the bottom. It's the full card on a taller screen.
local function layoutTracker()
	local compact = shortScreen()
	if compact ~= trackerCompact then
		trackerCompact = compact
		trackerPadding.PaddingTop = UDim.new(0, if compact then 10 else 12)
		trackerPadding.PaddingBottom = UDim.new(0, if compact then 12 else 14)
		trackerLayout.Padding = UDim.new(0, if compact then 4 else 6)
		taskLayout.Padding = UDim.new(0, if compact then 4 else 6)
		trackerHeader.Size = UDim2.new(1, 0, 0, if compact then 26 else 28)
		trackerTitle.TextSize = if compact then 20 else 24
		for _, row in taskRows do
			layoutTaskRow(row)
		end
	end
	trackerHint.Visible = not compact
	timerRow.Visible = trackerTimed and not compact
	damageRow.Visible = trackerTimed and not compact
	trackerButton.Visible = callOffShown and not compact
	compactTimer.Frame.Visible = trackerTimed and compact
	-- The name leaves room for the timer beside it.
	trackerTitle.Size = if trackerTimed and compact
		then UDim2.new(1, -(COMPACT_TIMER + 6), 1, 0)
		else UDim2.fromScale(1, 1)
	compactDamage.Visible = trackerTimed and trackerPenalty > 0
	compactButton.Visible = callOffShown
	compactFooter.Visible = compact and (compactDamage.Visible or callOffShown)
end

-- The job tracker: the art's GoalTracker card, as in the HUD style frame, or a plain dark one.
local function buildTracker()
	tracker = UI.sliced("GoalTracker", {
		Name = "JobTracker",
		Visible = false,
	}, { color = UI.Colors.Background, transparency = 0.2, radius = 10 })
	placeInColumn(tracker, "JobTracker")
	trackerPadding = UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = tracker,
	})
	trackerLayout = UI.list(6)
	trackerLayout.Parent = tracker

	-- The job's name, and on a short screen the timer beside it.
	trackerHeader = UI.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = tracker,
	})
	trackerTitle = UI.heading("", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 24,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = trackerHeader,
	})
	compactTimer = UI.display(
		"Numbers",
		"",
		{ TextSize = 20, Color = UI.Colors.Money, XAlignment = "Right", Fit = true },
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, COMPACT_TIMER, 1, 0),
			Visible = false,
			Parent = trackerHeader,
		}
	)
	trackerHint = UI.label("", {
		TextSize = 15,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = tracker,
	})
	taskLayout = UI.list(6)
	taskList = UI.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = tracker,
	}, { taskLayout })
	-- "03:24 / 05:00" against par, in the display face.
	timerRow = UI.new("Frame", {
		Name = "Timer",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Visible = false,
		Parent = tracker,
	})
	local clock =
		UI.icon("Timer", { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(0, 5), Parent = timerRow })
	local x = if clock then 30 else 0
	timer = UI.display(
		"Numbers",
		"",
		{ TextSize = 30, Color = UI.Colors.Money, Fit = true },
		{ Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x, 1, 0), Parent = timerRow }
	)
	damageRow = UI.new("Frame", {
		Name = "Damage",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Visible = false,
		Parent = tracker,
	})
	local warning = UI.icon(
		"Damage",
		{ Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(1, 1), Parent = damageRow },
		UI.Colors.Danger
	)
	local damageX = if warning then 30 else 0
	damageLabel = UI.label("", {
		Position = UDim2.fromOffset(damageX, 0),
		Size = UDim2.new(1, -damageX, 1, 0),
		TextSize = 16,
		Parent = damageRow,
	})
	trackerButton = UI.button("", callOffJob, {
		Size = UDim2.new(1, 0, 0, 36),
		Style = "Danger",
		TextSize = 16,
		LayoutOrder = 6,
		Parent = tracker,
	})

	-- On a short screen the damage (once there is some) and a small call-off button share a row at
	-- the bottom instead.
	compactFooter = UI.new("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 7,
		Visible = false,
		Parent = tracker,
	})
	compactDamage = UI.label("", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -124, 0, 18),
		TextSize = 15,
		TextColor3 = UI.Colors.Danger,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = compactFooter,
	})
	compactButton = UI.button("", callOffJob, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Style = "Danger",
		TextSize = 14,
		Parent = compactFooter,
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = compactButton })

	-- Small or full size as the screen changes, like curb appeal's rule.
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTracker)
	layoutTracker()
end

-- The call-off button's words, on both of the tracker's layouts.
local function setCallOffText(text: string)
	trackerButton.Text = text
	compactButton.Text = text
end

-- "0:42 / 1:30" against par, and the damage so far.
local function updateTimer()
	local job = ClientState.job
	trackerTimed = job ~= nil and job.state == "Working" and job.startedAt ~= nil
	if job and trackerTimed then
		local elapsed = workspace:GetServerTimeNow() - job.startedAt
		local text = `{Format.time(elapsed)} / {Format.time(job.parTime)}`
		local color = if elapsed <= job.parTime then UI.Colors.Money else UI.Colors.Danger
		timer:SetText(text)
		timer:SetColor(color)
		compactTimer:SetText(text)
		compactTimer:SetColor(color)
		trackerPenalty = job.penalty
		damageLabel.Text = `Damage  -{Format.money(job.penalty)}`
		damageLabel.TextColor3 = if job.penalty > 0 then UI.Colors.Danger else UI.Colors.SubText
		compactDamage.Text = damageLabel.Text
	end
	layoutTracker()
end

local function getTaskRow(taskName: string, order: number)
	local row = taskRows[taskName]
	if row then
		return row
	end

	local frame = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = taskList,
	})
	local flag = UI.icon(
		"Goal",
		{ Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(0, 1), Parent = frame },
		UI.Colors.SubText
	)
	local x = if flag then 24 else 0
	local label = UI.label("", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x, 0, 18),
		TextSize = 15,
		Parent = frame,
	})
	local bar = UI.bar({ Position = UDim2.fromOffset(x, 22), Size = UDim2.new(1, -x, 0, 12), Parent = frame })

	-- updateJob adds `fraction` (how done it was at the last update, so it can tell when it's just
	-- been finished) and celebrate adds `stamp`.
	row = { frame = frame, label = label, bar = bar, flag = flag }
	taskRows[taskName] = row
	layoutTaskRow(row)
	return row
end

-- A to-do's line: its words, how far along, and a check once it's done.
local function setTaskRow(row, text: string, fraction: number, fill: string)
	row.label.Text = text
	row.bar.set(fraction)
	row.bar.fill(fill)
	local done = fraction >= 1
	local image = Art.icon(if done then "Check" else "Goal")
	if row.flag and image ~= "" then
		row.flag.Image = image
		row.flag.ImageColor3 = if done then UI.Colors.Accent else UI.Colors.SubText
	end
end

local function clearTaskRows()
	for _, row in taskRows do
		row.frame:Destroy()
	end
	table.clear(taskRows)
end

-- A share (0-1) as a whole percent, rounded down so 100% means all of it. The nudge keeps a share
-- like 0.29, which times 100 comes to 28.999999999999996, from reading 28.
local function percentText(share: number): string
	return `{math.floor(share * 100 + 1e-6)}%`
end

-- Chimes, and thumps the "done" stamp down over a to-do's row (it fades by itself).
local function celebrate(row)
	Sounds.play(workspace.CurrentCamera, "LawnDone", 0.8)
	if not row.stamp then
		row.stamp = UI.stamp(row.frame, { JobComplete = "Job Complete!" }, DONE_STAMP_HEIGHT)
	end
	row.stamp.flash("JobComplete", nil, DONE_SPARKLES)
end

-- Whether the "Show what I missed" button shows: while the job tracker does, from the time a
-- mowing to-do (the one with a percent, of what the job requires) is MissedSpotsFrom done until it
-- counts as finished, and only while there's a lawn to light up: one on a job site, near you and
-- drawn as a surface (the simple renderer has nothing to tint). Where you are and what's drawn
-- change without a job update, so the 0.25 s loop in Start checks again.
local function updateMissedButton()
	local job = ClientState.job
	local show = false
	if job and job.tasks and tracker.Visible and GrassController.jobLawnFolder() then
		for _, info in job.tasks do
			if info.percent and info.percent >= GameConfig.MissedSpotsFrom and info.done < info.needed then
				show = true
				break
			end
		end
	end
	missedButton.Visible = show
end

-- The pay breakdown ------------------------------------------------------------------------------

local WANTED = {
	Quality = "a perfect finish",
	Speed = "it done fast",
	Balanced = "a good job in good time",
}

local function hidePay()
	if payPanel then
		payPanel:Destroy()
		payPanel = nil :: any
		UI.holdCursor("PayBreakdown", false)
	end
end

-- After a job: Job Complete!, a line for what each part was worth (the customer's tip last), what
-- you earned, and the job's stars filling in under it, until you close it (or the next job starts).
local function showPay(job)
	hidePay()
	local result = job.result
	local weights = Jobs.Preferences[result.preference] or Jobs.Preferences.Balanced
	local lines, total = PayBreakdown.lines(result, weights)
	payPanel = UI.sliced("Panel", {
		Name = "PayBreakdown",
		ZIndex = 5,
		Parent = UI.getScreen(),
	}, { color = UI.Colors.Background, radius = 14 })
	UI.keepPlaced(payPanel, "PayBreakdown")
	-- Scaled down to fit a short screen, keeping `margin` clear (UiLayout.luau), times its own scale.
	local scale = UI.scaler(payPanel)
	local margin = UI.Layout.__screen.scaling.PayBreakdown.margin
	local width = payPanel.Size.X.Offset
	local function fit()
		local screen = UI.getScreen().AbsoluteSize
		local height = payPanel.AbsoluteSize.Y / math.max(scale.Scale, 0.01)
		if height > 0 and screen.Y > 0 then
			scale.Scale = math.min(1, (screen.Y - margin) / height, (screen.X - margin) / width)
				* UI.layout("PayBreakdown").scale
		end
	end
	payPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 28),
		PaddingRight = UDim.new(0, 28),
		Parent = payPanel,
	})
	local layout = UI.list(6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = payPanel
	local words = UI.wordmark("JobComplete", "Job Complete!", 64, { LayoutOrder = 1, Parent = payPanel })
	UI.sparkle(words, 6, 30)
	UI.heading(string.upper(job.name or "Job"), {
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = payPanel,
	})
	-- The tip's amount, where its pop lifts off: the tip is the last line, when there is one.
	local tipAmount: TextLabel? = nil
	for index, line in lines do
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = 2 + index,
			Parent = payPanel,
		})
		UI.label(
			line.label,
			{ Size = UDim2.new(1, -110, 1, 0), TextSize = 18, FontFace = UI.Fonts.Medium, Parent = row }
		)
		local sign = if line.amount < 0 then "-" else "+"
		local amount = UI.label(`{sign}{Format.money(math.abs(line.amount))}`, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 110, 1, 0),
			TextSize = 19,
			FontFace = UI.Fonts.Heavy,
			TextColor3 = if line.amount < 0 then UI.Colors.Danger else UI.Colors.Money,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		if index == #lines and (result.tip or 0) > 0 then
			tipAmount = amount
		end
	end
	local rule = UI.bar({ Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 50, Parent = payPanel })
	rule.set(1)
	local totalRow = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 51,
		Parent = payPanel,
	})
	UI.heading("TOTAL EARNED", { Size = UDim2.fromScale(0.5, 1), TextSize = 24, Parent = totalRow })
	local totalDisplay = UI.display(
		"Numbers",
		Format.money(total),
		{ TextSize = 54, Color = UI.Colors.Money, XAlignment = "Right", Fit = true },
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),
			Parent = totalRow,
		}
	)
	-- The job's stars: three slots, grey until the stars it earned fill in gold, one by one.
	local earnedStars = math.clamp(result.stars or 0, 0, 3)
	local starRow = UI.new("Frame", {
		Name = "Stars",
		Size = UDim2.new(1, 0, 0, STAR_SIZE),
		BackgroundTransparency = 1,
		LayoutOrder = 52,
		Parent = payPanel,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- Each star is a label in the middle of a plain slot: a UIScale grows from the anchor point of
	-- what it's on, so the pop is on the label, and grows from the star's middle.
	local slots: { TextLabel } = {}
	for index = 1, 3 do
		local slot = UI.new("Frame", {
			Name = `Slot{index}`,
			Size = UDim2.fromOffset(STAR_SIZE, STAR_SIZE),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = starRow,
		})
		slots[index] = UI.label(STAR_GLYPH, {
			Name = `Star{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			TextSize = 40,
			FontFace = UI.Fonts.Heavy,
			TextColor3 = UI.Colors.Disabled,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = slot,
		})
	end
	local thisPanel = payPanel
	task.spawn(function()
		for index = 1, earnedStars do
			task.wait(STAR_STEP)
			-- Closed (or a newer job's panel up) in the meantime.
			if payPanel ~= thisPanel then
				return
			end
			local slot = slots[index]
			slot.TextColor3 = UI.Colors.Gold
			local pop = UI.new("UIScale", { Scale = 1.7, Parent = slot })
			TweenService:Create(pop, TweenInfo.new(STAR_STEP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
			UI.sparkle(slot, 3, 26)
			Sounds.playUi("Star", STAR_VOLUME)
		end
	end)
	-- The cash lands: it rings the instant the panel opens (not when the pop does, so it's clear of
	-- the first star's sound), and "+$142" lifts off the total, and "+$12 tip" off the tip line,
	-- once the panel's laid out, unless it's been closed by then. A job that paid nothing is silent.
	if total > 0 then
		Sounds.playUi("Cash")
	end
	task.delay(PAY_POP_DELAY, function()
		if payPanel ~= thisPanel or total <= 0 then
			return
		end
		if tipAmount then
			FloatingText.show(tipAmount, `+{Format.money(result.tip)} tip`, nil, SMALL_POP)
		end
		FloatingText.show(totalDisplay.Frame, `+{Format.money(total)}`)
	end)
	-- What the customer wanted, the tools and the junk, in words.
	local notes = { `The customer wanted {WANTED[result.preference] or WANTED.Balanced}.` }
	if result.toolFit < 0.995 then
		table.insert(notes, `Right tools for the job: {Format.percent(result.toolFit)}.`)
	end
	local left, hit = result.debrisLeft or 0, result.debrisHit or 0
	if left > 0 then
		table.insert(notes, `{left} bits of junk left in the grass.`)
	end
	if hit > 0 then
		table.insert(notes, `{hit} chewed up by a mower.`)
	end
	UI.label(table.concat(notes, " "), {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 15,
		FontFace = UI.Fonts.Body,
		TextColor3 = UI.Colors.SubText,
		LayoutOrder = 53,
		Parent = payPanel,
	})
	local buttonRow = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = 54,
		Parent = payPanel,
	})
	UI.button("Nice!", hidePay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(220, 46),
		TextSize = 20,
		Parent = buttonRow,
	})
	fit()
	UI.holdCursor("PayBreakdown", true)
end

-- Updating it all ----------------------------------------------------------------------------------

-- The big moment for a new tool (not the ones you had when you joined). A new level's is
-- onLevelReward, from the server, which knows what the level paid.
local function moments(profile)
	local now = {}
	for _, item in Items.ownedTools(profile.owned) do
		now[item.id] = true
		if knownTools and not knownTools[item.id] then
			UI.moment("NewTool", "New Tool!", item.name)
		end
	end
	knownTools = now
end

-- The server's paid a level's reward (`info`: the level, the line that names what it paid, and the
-- cash). Level Up! is announced here and only here, with the reward under it.
local function onLevelReward(info: { level: number, text: string, cash: number })
	-- The art's wordmark has no number in it, so the subtitle carries the level too.
	UI.moment("LevelUp", `Level {info.level}!`, if info.text ~= "" then `Level {info.level}: {info.text}` else nil)
	Sounds.playUi("LevelUp")
	if info.cash > 0 then
		task.delay(LEVEL_POP_DELAY, function()
			FloatingText.show(levelLabel, `+{Format.money(info.cash)}`)
		end)
	end
end

-- When the next paid contract (or the Bonus Day) may ring and pop (os.clock seconds).
local contractFreeAt = 0

-- Runs `play(info)` now, or when the one before it has had its turn, and books the turn after it
-- CONTRACT_GAP later.
local function inTurn(play: (info: any) -> (), info: any)
	local wait = math.max(0, contractFreeAt - os.clock())
	contractFreeAt = os.clock() + wait + CONTRACT_GAP
	if wait > 0 then
		task.delay(wait, play, info)
	else
		play(info)
	end
end

-- Moments the login brings (the streak's day, and a contract or the Bonus Day that its cash meets)
-- come as soon as the save loads, while the title card is still up over the screen they play on, so
-- nobody would see or hear them. They wait here for the card to go (UI.titleCardDone), then play in
-- the order they came, each in its turn. The counts, the badge and the panels don't wait: only the
-- moments and their sounds.
local held: { { play: (info: any) -> (), info: any } } = {}

local function afterTitleCard(play: (info: any) -> (), info: any)
	-- Behind anything already held too, so a late arrival can't pass what is waiting.
	if UI.titleCardDone() and #held == 0 then
		inTurn(play, info)
	else
		table.insert(held, { play = play, info = info })
	end
end

-- The title card is gone: what waited plays now, in order.
local function playHeld()
	local waiting = held
	held = {}
	for _, item in waiting do
		inTurn(item.play, item.info)
	end
end

-- The goal chime and the cash for a paid contract: the cash lifts off the Contracts square, or off the
-- money counter where the square isn't showing.
local function showContractDone(info: { id: string, text: string, reward: number })
	Sounds.playUi("GoalDone")
	if info.reward > 0 then
		local cash = `+{Format.money(info.reward)}`
		if not FloatingText.show(contractsFace, cash) then
			FloatingText.show(money.Frame, cash)
		end
	end
end

-- The server's paid a contract (`info`: its id, its words and its cash). Two paid in one frame
-- (one job can meet two) don't play on top of each other: each waits its turn, CONTRACT_GAP after the
-- one before, and all of them wait for the title card. The chip's count follows with the view, which
-- the server sends once it has paid.
local function onContractDone(info: { id: string, text: string, reward: number })
	afterTitleCard(showContractDone, info)
end

-- The Bonus Day's Payday moment and the cash register. The art's wordmark reads Payday! and nothing
-- else, so the subtitle carries the name.
local function showBonusDay(info: { cash: number })
	UI.moment("Payday", "Bonus Day!", `Bonus Day: +{Format.money(info.cash)}`, 3)
	Sounds.playUi("Cash")
end

-- All three contracts are paid and so is the Bonus Day (`info`: its cash). It comes in the same frame
-- as the last contract, and takes its turn behind that contract's chime, so the payoff is last.
local function onBonusDay(info: { cash: number })
	afterTitleCard(showBonusDay, info)
end

-- The streak grew (`info`: the days in a row, what today paid, the flag today gave if it gave one,
-- and what tomorrow pays): a Payday moment saying the day, what it paid and what's next, or on the
-- day that gave the truck its pennant, that, the streak chime, and the cash lifts off the money
-- counter. The art's wordmark reads Payday! and nothing else, so the subtitle carries the day too.
local function showStreakAdvanced(info: { days: number, cash: number, flag: string?, tomorrow: number })
	local cash = Format.money(info.cash)
	-- Day 7 drops its "of 7" so that it fits a phone.
	local subtitle = if info.flag
		then `Day {info.days}: +{cash} and a pennant for the truck`
		else `{Streak.text(info.days)}: +{cash} today, {Format.money(info.tomorrow)} tomorrow`
	UI.moment("Payday", Streak.text(info.days), subtitle, 4)
	Sounds.playUi("Streak")
	if info.cash > 0 then
		FloatingText.show(money.Frame, `+{Format.money(info.cash)}`)
	end
end

-- The streak grew: the moment above, once the title card is gone, which is when it is on a login.
local function onStreakAdvanced(info: { days: number, cash: number, flag: string?, tomorrow: number })
	afterTitleCard(showStreakAdvanced, info)
end

local function updateProfile()
	local profile = ClientState.profile
	if not profile then
		return
	end
	-- Money that came in counts up and the pill pulses; anything else (the first profile, a spend) is set.
	if profile.money ~= lastMoney then
		if lastMoney and profile.money > lastMoney then
			Juicy.countTo(money, lastMoney, profile.money, MONEY_COUNT_TIME, Format.money)
			Juicy.pulse(moneyPill)
		else
			Juicy.countTo(money, profile.money, profile.money, 0, Format.money)
		end
		lastMoney = profile.money
	end
	levelLabel.Text = `LVL {profile.level}`
	local from = GameConfig.xpForLevel(profile.level)
	local to = GameConfig.xpForLevel(profile.level + 1)
	xpBar.set((profile.xp - from) / (to - from))
	-- XP that came in lifts off the bar (not on the first profile, which is only what you had).
	if lastXp and profile.xp > lastXp then
		FloatingText.show(xpBar.frame, `+{profile.xp - lastXp} XP`, UI.Colors.Accent, SMALL_POP)
	end
	lastXp = profile.xp
	moments(profile)
	updateGoal()
end

local function updateJob()
	local job = ClientState.job
	if not job then
		tracker.Visible = false
		clearTaskRows()
		updateMissedButton()
		updateCurbAppeal()
		return
	end

	if job.id ~= shownJobId then
		shownJobId = job.id
		clearTaskRows()
		if payShownFor ~= job.id then
			hidePay()
		end
	end
	-- It steps aside for what takes its spot (the decorating buttons, on a touch screen).
	tracker.Visible = not UI.givesWay("JobTracker")
	trackerTitle.Text = string.upper(job.name)
	local isLeader = job.leader == player
	-- Whether there's a button to call the job off: updateTimer lays the tracker out with it.
	callOffShown = true

	if job.state == "Ready" then
		trackerHint.Text = if isLeader
			then `{job.address} · {Format.money(job.payout)}\nLoad the tools you think you'll need, then hop in!`
			else `{job.address} · {Format.money(job.payout)}\nWaiting for {job.leader.DisplayName} to start the truck.`
		setCallOffText("Cancel job")
		callOffShown = isLeader
	elseif job.state == "Traveling" then
		trackerHint.Text = `Driving to {job.address}...`
		callOffShown = false
	elseif job.state == "Working" then
		trackerHint.Text = if job.story then `"{job.story}"  - {job.customer}` else "Don't hit the flowers or gnomes!"
		if job.soil then
			trackerHint.Text ..= `\nSoil probe: {job.soil}`
		end
		setCallOffText(if isLeader then "Call off job" else "Leave job")
	elseif job.state == "Complete" then
		trackerHint.Text = if job.result
			then `You earned {Format.money(job.result.share + (job.result.tip or 0))}! Heading back soon...`
			else "Job done!"
		callOffShown = false
		if job.result and payShownFor ~= job.id then
			payShownFor = job.id
			showPay(job)
		end
	end
	updateTimer()
	updateCurbAppeal()

	if not job.tasks then
		clearTaskRows()
		updateMissedButton()
		return
	end
	for order, info in job.tasks do
		local row = getTaskRow(info.task, order)
		local fraction = if info.needed > 0 then info.done / info.needed else 1
		-- Mowing says how much of the lawn is cut; the other to-dos count what's done.
		local progress = if info.percent then percentText(info.percent) else `{info.done}/{info.needed}`
		setTaskRow(row, `{info.label}  {progress}`, fraction, if fraction >= 1 then "Money" else "Grass")
		-- Finishing the mowing gets a chime and a stamp, once. A row that's first seen finished (you
		-- joined a job that was already there) doesn't: it has to be seen not done first.
		if info.percent and row.fraction and row.fraction < 1 and fraction >= 1 then
			celebrate(row)
		end
		row.fraction = fraction
	end
	updateMissedButton()
	-- Junk hidden in the grass: how much has been found (it costs if it's left, or run over).
	local debris = job.debris
	if debris and debris.total > 0 then
		local row = getTaskRow("Debris", #job.tasks + 1)
		local fraction = (debris.picked + debris.hit) / debris.total
		setTaskRow(
			row,
			`Pick up junk in the grass  {debris.picked}/{debris.total}`
				.. (if debris.hit > 0 then `  ({debris.hit} chewed up)` else ""),
			fraction,
			if debris.hit > 0 then "Danger" elseif fraction >= 1 then "Money" else "Grass"
		)
	end
end

function HudController:Start()
	buildColumns()
	buildStats()
	buildPills()
	buildMenuButtons()
	buildGoal()
	buildCurbAppeal()
	buildNextChip()
	buildTracker()
	buildMissedButton()
	buildCondition()

	ClientState.Changed:Connect(function(key)
		if key == "profile" then
			updateProfile()
		elseif key == "job" then
			updateJob()
		elseif key == "story" or key == "contest" then
			updateGoal()
			if key == "contest" then
				updateCountdown()
			end
		elseif key == "contracts" then
			updateContractsBadge()
			updateStreak()
		end
	end)
	player:GetAttributeChangedSignal("CurbAppeal"):Connect(updateGoal)
	player:GetAttributeChangedSignal("GoldSign"):Connect(updateGoldSign)
	updateGoldSign()
	UI.onGiveWay("GrandmaGoal", updateGoal)
	UI.onGiveWay("JobTracker", updateJob)
	-- The rail hides and the Next chip shows when the screen turns short, and the other way (a window
	-- resized).
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shortScreen() ~= railCompact then
			updateMilestones()
		end
	end)
	Net.event("MilestoneReached").OnClientEvent:Connect(onMilestoneReached)
	Net.event("LevelReward").OnClientEvent:Connect(onLevelReward)
	Net.event("ContractDone").OnClientEvent:Connect(onContractDone)
	Net.event("BonusDay").OnClientEvent:Connect(onBonusDay)
	Net.event("StreakAdvanced").OnClientEvent:Connect(onStreakAdvanced)
	UI.TitleCardDone:Connect(playHeld)
	updateGoal()
	updateContractsBadge()
	updateStreak()
	updateCountdown()

	task.spawn(function()
		while true do
			task.wait(COUNTDOWN_REFRESH)
			updateCountdown()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			updateTimer()
			updateCondition()
			updateCurbAppeal()
			updateMissedButton()
		end
	end)

	UserInputService.InputBegan:Connect(onKey)

	-- Any ProximityPrompt with an OpensPanel attribute opens that menu (job board, shop...).
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("OpensPanel")
		if typeof(panel) == "string" then
			UI.open(panel)
		end
	end)
end

return HudController
