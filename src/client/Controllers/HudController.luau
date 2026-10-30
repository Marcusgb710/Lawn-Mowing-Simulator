-- Always-on screen stuff, laid out like the art's HUD (alphainstructions/instructions38.md):
--   * down the left: the money pill (a gold coin and the money counter in the display face, which
--     counts up when money comes in), under it the level pill (a star, "LVL 3" and the XP bar, one
--     button that opens the Levels panel, LevelsController, with the star gold once you have the gold
--     business sign) beside the streak pill ("DAY 3", once there is a streak), the judging day
--     countdown pill (once judging day is on the calendar), the four menu squares (Truck, Guide,
--     Crew and Contracts: glossy colour squares with their glyphs and names under them, and on a
--     keyboard their keys, T, G, C, on a corner; a column on a PC and a 2x2 grid on a phone; the
--     Contracts one opens the contracts panel, ContractsController, and a yellow badge on it counts
--     the contracts left today);
--   * at the top in the middle, on every screen: Grandma's goal, a cream banner with a red flag, your
--     story goal, its reward when it has one and a striped bar, and under it, in the cream, the goals
--     rail: your next two milestones (the first-job coach and a crew invite take its spot in turn);
--   * down the right: your business's curb appeal, on a phone the Next chip (the next milestone,
--     where the rail has no room), the job tracker on a dark glass card (the job's name in gold with
--     its stars once it is paid, a big timer with par, to-dos, damage and a Call off pill), smaller on
--     a phone, under it the boost pills (Crew, Curb, Truck and Business pay bonuses, while they
--     are above zero), and under those, late in the mowing, the button that lights up the grass you
--     missed (M on a keyboard);
--   * down the right edge, outside that column: the right buttons, glossy squares for the Shop (the
--     Orders window, from anywhere: B on a keyboard), Gifts (claims the day's streak gift, ClaimStreak,
--     with a tilted CLAIM tag and a pulse while one waits; with none, the contracts panel), Top Lawns
--     (the two leaderboards, TopLawnsController: F) and Settings (comma): faces 76 px with their names
--     under them on a PC, 56 px and bare on a phone or a short screen (the column moves in to clear
--     them, UiLayout's RightColumn);
--   * the condition of the tool in your hands, a glyph for each thing wrong ("Running low on
--     fuel" by the fuel can), or what you're doing to one at the workbench;
--   * the pay breakdown when a job's done, and the big moments: Level Up! (when the server says
--     what the level paid, LevelReward), New Tool!, and a Payday for the Bonus Day (BonusDay) and
--     for each day's gift claimed (StreakAdvanced), and a toast for an unclaimed gift the day turn
--     paid (StreakGiftPaid);
--   * cash and XP coming in lift off the piece of the HUD they came from (FloatingText) and ring
--     (Sounds.playUi): the pay panel's total and tip, a goal's row or the Next chip, the Contracts
--     square (ContractDone), the money counter (the streak's gift), the level pill and the XP bar.
-- On a keyboard V switches camera motion on and off (saved, through SettingsController). Where each piece goes is in UiLayout.luau,
-- which can also take any of the columns' pieces out of its column to go anywhere on the screen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daily = require(Shared.Daily)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local HomeLawn = require(Shared.HomeLawn)
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
local SettingsController = require(script.Parent.SettingsController)
local ShopController = require(script.Parent.ShopController)

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
-- The Gifts button's CLAIM tag while the day's gift waits: it hangs this far off the face's top left
-- corner, tilted the other way from a count badge, and the button pulses every few seconds.
local GIFT_TAG_OVERHANG = 8
local GIFT_TAG_TILT = -8
local GIFT_PULSE_EVERY = 2.5
-- The right buttons: the strip's four squares, their face colours, glyphs and keys (Gifts has no key
-- and a present drawn in code, since the Premium glyph is a diamond; the key badge sits on a face's
-- top left corner, with a keyboard only), and where each is placed in UiLayout.luau. What each does
-- is in rightActions, so a later task can change it (HudController.setRightAction).
local RIGHT_BUTTONS = {
	{ id = "Shop", label = "Shop", layout = "ShopButton", color = "Shop", icon = "Orders", key = Enum.KeyCode.B },
	{ id = "Gifts", label = "Gifts", layout = "GiftsButton", color = "Gifts" },
	{
		id = "TopLawns",
		label = "Top Lawns",
		layout = "TopLawnsButton",
		color = "TopLawns",
		icon = "Crown",
		key = Enum.KeyCode.F,
	},
	{
		id = "Settings",
		label = "Settings",
		layout = "SettingsButton",
		color = "Settings",
		icon = "Wrench",
		key = Enum.KeyCode.Comma,
	},
}
-- On a PC a right button's piece is its face and, under it, the label's 12 px gap and 22 px of room
-- (UiLayout's ShopButton and the rest are 34 taller than the face); on a touch or short screen it is
-- the bare face.
local SQUARE_LABEL_GAP = 12
local SQUARE_LABEL_ROOM = 34
-- F also sends a decoration you own back to your inventory while you are placing one (DecorController),
-- so the Top Lawns key leaves it be then.
local PLACING_ATTRIBUTE = "PlacingDecor"
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
-- Grandma's goal banner: how round its cream face is, the red flag circle at its left, and the room
-- at the right of its bar for the words that say how far along it is ("$66 / $150").
local GOAL_RADIUS = 22
local GOAL_FLAG = 34
local GOAL_VALUE_ROOM = 104
local FLAG_RED = Color3.fromHex("FF5A5F")
-- The job card and the boost pills are dark glass: how round it is, its outline and the lip under it,
-- and how the track of a bar on it (or on the cream banner) looks. A bar's track is this tall, in an
-- outline of its own.
local CARD_RADIUS = 20
local CARD_STROKE = 4
local CARD_LIP = 6
local BAR_HEIGHT = 13
local BAR_STROKE = 2
local TRACK_DARK = Color3.fromHex("0F1A12")
local TRACK_CREAM = Color3.fromHex("D9D2BC")
-- The job's stars on the card's title row: each this big, the gap between them, and the grey of one
-- not earned. "par 2:30" is this pale green.
local CARD_STAR = 20
local CARD_STAR_GAP = 2
local STAR_OFF = Color3.fromHex("4A5A4C")
local PAR_COLOR = Color3.fromHex("CFE3C6")
-- The Call off pill, on the full card and on the short screen's one-row footer, and how tall each of
-- those rows is.
local CALL_OFF = Vector2.new(104, 30)
local COMPACT_CALL_OFF = Vector2.new(92, 28)
local FOOTER_HEIGHT = 32
-- A boost pill: its height, its outline and lip, and its glyph.
local BOOST_HEIGHT = 26
local BOOST_STROKE = 3
local BOOST_LIP = 3
local BOOST_ICON = 14
-- The pay bonuses the pills show, in order: the key HudController reads them under, the glyph, and
-- the palette face whose light colour tints the glyph. Each is a pill while its bonus is above zero.
local BOOSTS = {
	{ id = "Crew", label = "Crew", icon = "Crew", tint = "Crew" },
	{ id = "Curb", label = "Curb", icon = "CurbAppeal", tint = "Money" },
	{ id = "Truck", label = "Truck", icon = "Truck", tint = "Truck" },
	{ id = "Business", label = "Business", icon = "Business", tint = "Gold" },
}

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

-- Grandma's goal banner, its words, the reward at their right (only for a goal that has one), the
-- words that say how far along it is, and its bar.
local goalNote: GuiObject
local goalText: TextLabel
local goalReward: TextLabel
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
-- The right buttons' strip, and each one's pieces (its spec, button, face and label), for fitting them
-- to the screen.
local rightHolder: Frame
local rightPieces: { { spec: any, button: TextButton, face: Frame, label: GuiObject? } } = {}
-- What each right button does (by its id), so it can be changed without building the button again.
local rightActions: { [string]: () -> () } = {}
-- The Gifts button's CLAIM tag while a gift waits, and whether a claim is on its way to the server.
local giftTag: Frame? = nil
local claiming = false
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

-- The job card: the glass piece the column holds, and the frame inside it that lays its words out.
local tracker: GuiObject
local trackerBody: Frame
local trackerPadding: UIPadding
local trackerLayout: UIListLayout
local trackerHeader: Frame
local trackerTitle: TextLabel
-- The three stars on the title row (shown once the job is paid) and the star in each place.
local trackerStars: Frame
local trackerStarIcons: { GuiObject } = {}
local trackerHint: TextLabel
local timerRow: Frame
local timer
local parLabel: TextLabel
-- The full card's last row: the damage so far at the left (while you work) and the Call off pill.
local damageRow: Frame
local damageIcon: GuiObject?
local damageLabel: TextLabel
local taskList: Frame
local taskLayout: UIListLayout
local trackerButton: TextButton
local callOffLabel: TextLabel
local taskRows = {}
-- The pay bonus pills under the card, by their BOOSTS id: the pill, and the words on it.
local boostRow: Frame
local boostPills: { [string]: { frame: Frame, label: TextLabel } } = {}
local shownJobId = nil
-- The tracker on a short screen (layoutTracker): the timer beside the job's name, and the damage
-- and a small call-off button sharing a row at the bottom.
local trackerCompact = false
local compactTimer
local compactFooter: Frame
local compactDamage: TextLabel
local compactButton: TextButton
local compactCallOffLabel: TextLabel
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

-- A dark glass panel in Juicy's Glass colour at its GlassTransparency, with the face's ink outline and
-- a lip under it. Juicy.face only paints a palette gradient, so this is a plain frame built the same
-- way: the holder (what `props` go on, transparent), an ink Lip behind that shows `lip` px below the
-- face (the strip is as tall as the corner is round, so the corners meet), and the glass Face with
-- its rounded outline. Words go in the Face, or in a frame beside it (ZIndex 3 or more) when the
-- holder grows with them (then size the holder through `AutomaticSize`). Returns the holder and the Face.
local function glassPanel(props, radius: number, stroke: number, lip: number): (Frame, Frame)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 })
	for key, value in props do
		if key ~= "Parent" then
			holder[key] = value
		end
	end
	UI.new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Juicy.Palette.Ink,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -radius),
		Size = UDim2.new(1, 0, 0, radius + lip),
		ZIndex = 1,
		Parent = holder,
	}, {
		UI.corner(radius),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Juicy.Palette.Ink,
			Thickness = stroke,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})
	local face = UI.new("Frame", {
		Name = "Face",
		BackgroundColor3 = Juicy.Palette.Glass,
		BackgroundTransparency = Juicy.Palette.GlassTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	}, {
		UI.corner(radius),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Juicy.Palette.Ink,
			Thickness = stroke,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	})
	if props.Parent then
		holder.Parent = props.Parent
	end
	return holder, face
end

-- A progress bar for the cards and the banner: UI.bar's striped fill (`kind`: "Grass" or "Money") in
-- a `BAR_HEIGHT` px track of colour `track` with an ink outline. UI.bar's own track is hidden, so the
-- outline is one rounded frame; its `frame` (the thing to place or hide) is that outer one, and `set`
-- and `fill` are UI.bar's. `props` (Size, Position, LayoutOrder, Parent...) are the outer frame's.
local function framedBar(props, kind: string, track: Color3): UI.Bar
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

-- A present on a face, drawn from frames: a white box with its lid, a yellow ribbon down the middle
-- and a bow of two loops and a knot on top, all in the ink outline. Sized in fractions of the face, so
-- it keeps its shape at any face size.
local GIFT_SIZE = 0.62
local GIFT_STROKE = 1.5
local function drawGift(face: Frame)
	local function piece(name: string, color: Color3, position: Vector2, size: Vector2, order: number, round: number)
		return UI.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(position.X, position.Y),
			Size = UDim2.fromScale(size.X, size.Y),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = order,
		}, {
			UI.new("UICorner", { CornerRadius = UDim.new(round, 0) }),
			UI.new("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Juicy.Palette.Ink,
				Thickness = GIFT_STROKE,
				LineJoinMode = Enum.LineJoinMode.Round,
			}),
		})
	end
	local gift = UI.new("Frame", {
		Name = "Gift",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(GIFT_SIZE, GIFT_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = face,
	})
	local ribbon = Juicy.Palette.Badge
	piece("Box", WHITE, Vector2.new(0.5, 0.75), Vector2.new(0.8, 0.5), 1, 0.1).Parent = gift
	piece("Lid", WHITE, Vector2.new(0.5, 0.42), Vector2.new(1, 0.24), 2, 0.2).Parent = gift
	piece("Ribbon", ribbon, Vector2.new(0.5, 0.7), Vector2.new(0.16, 0.6), 3, 0.1).Parent = gift
	local left = piece("LeftLoop", ribbon, Vector2.new(0.36, 0.2), Vector2.new(0.3, 0.2), 4, 0.5)
	left.Rotation = -28
	left.Parent = gift
	local right = piece("RightLoop", ribbon, Vector2.new(0.64, 0.2), Vector2.new(0.3, 0.2), 4, 0.5)
	right.Rotation = 28
	right.Parent = gift
	piece("Knot", ribbon, Vector2.new(0.5, 0.26), Vector2.new(0.16, 0.16), 5, 0.5).Parent = gift
end

-- Sets a right button's face, label and corner to the size its UiLayout entry gives on this screen: on
-- a PC the entry is the face and the label's room, on a touch or short screen just the face, and the
-- label goes. UI.place has already put the button at that size; the face is Juicy's Body frame, which
-- is as tall as the face was built, so it is set to match.
local function fitRightButton(piece)
	local small = UI.isTouch() or UI.isCompact()
	local height = UI.layout(piece.spec.layout).size.Y.Offset
	local faceHeight = if small then height else height - SQUARE_LABEL_ROOM
	local body = piece.face.Parent
	if body and body:IsA("GuiObject") then
		body.Size = UDim2.new(1, 0, 0, faceHeight)
	end
	local label = piece.label
	if label then
		label.Visible = not small
		label.Position = UDim2.new(0.5, 0, 0, faceHeight + SQUARE_LABEL_GAP)
	end
end

-- Whether the day's view says today's gift (the streak's cash) is waiting to be claimed.
local function giftWaiting(): boolean
	local view = ClientState.contracts
	return view ~= nil and view.streak ~= nil and view.streak.claimable == true
end

-- The Gifts button: claims the waiting gift (the server pays it and the Payday card follows, from
-- StreakAdvanced), or with none waiting opens the contracts panel, whose streak card says what
-- tomorrow's pays. One claim at a time; when one doesn't go through the server says why.
local function pressGifts()
	if not giftWaiting() then
		UI.toggle("Contracts")
		return
	end
	if claiming then
		return
	end
	claiming = true
	task.spawn(function()
		local ok, claimed, message = pcall(function()
			return Net.func("ClaimStreak"):InvokeServer()
		end)
		claiming = false
		if not ok then
			UI.notify("Your gift didn't come through. Try again in a moment.")
		elseif not claimed and typeof(message) == "string" then
			UI.notify(message)
		end
	end)
end

-- The strip down the right edge (UiLayout's RightButtons): Shop, Gifts, Top Lawns and Settings. Built
-- straight at the size this screen asks (a UIScale on the strip would leave the buttons' sizes to the
-- layout's mercy), and fitted again if the screen turns short or tall.
local function buildRightButtons()
	rightHolder = UI.new("Frame", {
		Name = "RightButtons",
		BackgroundTransparency = 1,
		Parent = UI.getScreen(),
	})
	UI.keepPlaced(rightHolder, "RightButtons")

	local small = UI.isTouch() or UI.isCompact()
	for _, spec in RIGHT_BUTTONS do
		local size = UI.layout(spec.layout).size
		local face = if small then size.Y.Offset else size.Y.Offset - SQUARE_LABEL_ROOM
		local button, faceFrame = Juicy.button(spec.color, function()
			rightActions[spec.id]()
		end, {
			Name = spec.id .. "Button",
			Icon = spec.icon,
			Label = spec.label,
			Size = UDim2.fromOffset(size.X.Offset, face),
			Parent = rightHolder,
		})
		UI.keepPlaced(button, spec.layout)
		if spec.key then
			addCornerKey(faceFrame, spec.key)
		end
		if spec.id == "Gifts" then
			drawGift(faceFrame)
		end
		local piece = {
			spec = spec,
			button = button,
			face = faceFrame,
			label = button:FindFirstChild("Label", true),
		}
		table.insert(rightPieces, piece)
		fitRightButton(piece)
	end

	-- Where each button goes: the Shop opens the Orders window (or puts it away when it is up), Gifts
	-- claims the day's gift (or shows the contracts panel's streak card when none waits), Top Lawns the
	-- leaderboards, and Settings the Settings window (SettingsController gives it that when it starts,
	-- through setRightAction). Opening one closes any other menu, since only one is up at a time
	-- (UI.open).
	rightActions.Shop = function()
		if UI.isOpen("Shop") then
			UI.close("Shop")
		else
			ShopController.openApp("Orders")
		end
	end
	rightActions.Gifts = pressGifts
	rightActions.TopLawns = function()
		UI.toggle("TopLawns")
	end
	rightActions.Settings = function() end

	-- Other controllers build on the Gifts and Settings buttons (a tag on Gifts, the window behind Settings).
	HudController.giftsButton = rightPieces[2].button
	HudController.giftsFace = rightPieces[2].face
	HudController.settingsButton = rightPieces[4].button
	HudController.settingsFace = rightPieces[4].face

	UI.CompactChanged:Connect(function()
		for _, piece in rightPieces do
			fitRightButton(piece)
		end
	end)
end

-- Changes what a right button does ("Gifts" or "Settings", or any of the four by its id), so the task
-- that wires it up needs no new button.
function HudController.setRightAction(id: string, action: () -> ())
	assert(rightActions[id] ~= nil, `HudController has no right button {id}`)
	rightActions[id] = action
end

-- A pulse of the Gifts button: its Content frame, which grows from its middle and holds the hover
-- scale (Juicy.pulse works relative to that and gives way to a hover or a press).
local function pulseGifts()
	local button = HudController.giftsButton
	local content = button and button:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		Juicy.pulse(content)
	end
end

-- The CLAIM tag on the Gifts button's face, from the day's view: on while a gift waits (with a pulse
-- as it appears, then every GIFT_PULSE_EVERY seconds from Start's loop), gone once it is claimed.
local function updateGiftTag()
	local face = HudController.giftsFace
	if not face then
		return
	end
	local waiting = giftWaiting()
	if waiting and not giftTag then
		local tag = Juicy.badge("CLAIM", {
			Name = "ClaimTag",
			Position = UDim2.fromOffset(-GIFT_TAG_OVERHANG, -GIFT_TAG_OVERHANG),
			Rotation = GIFT_TAG_TILT,
			ZIndex = 8,
			Parent = face,
		})
		giftTag = tag
		pulseGifts()
	elseif not waiting and giftTag then
		giftTag:Destroy()
		giftTag = nil
	end
end

-- Grandma's goal: a cream banner at the top in the middle of the screen (UiLayout's GrandmaGoal), a red
-- flag, your story goal in a line or two, what finishing it pays when it pays something, and a bar
-- for how close you are, and under that the goals rail's rows. The banner is a Juicy cream face
-- whose holder grows with the words: the holder is the piece UiLayout places, the Face behind and the
-- Lip under it are as tall as it, and the words sit in a Body beside them that sets the height.
local function buildGoal()
	goalNote = Juicy.face("Cream", { Name = "Goal", Radius = GOAL_RADIUS, Visible = false })
	placeInColumn(goalNote, "GrandmaGoal")
	local body = UI.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = goalNote,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 11),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		Parent = body,
	})
	UI.list(5).Parent = body

	-- The flag and the goal's column side by side, the flag in the middle of the column's height.
	local main = UI.new("Frame", {
		Name = "Main",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = body,
	})
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		Parent = main,
	})
	local flag = UI.new("Frame", {
		Name = "Flag",
		BackgroundColor3 = FLAG_RED,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(GOAL_FLAG, GOAL_FLAG),
		LayoutOrder = 1,
		Parent = main,
	}, {
		UI.corner(GOAL_FLAG / 2),
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Juicy.Palette.Ink,
			Thickness = 3,
		}),
	})
	local glyph = UI.icon("Goal", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Parent = flag,
	}, WHITE)
	if not glyph then
		Juicy.text("!", { Size = UDim2.fromScale(1, 1), TextSize = 20, Parent = flag }, 0)
	end
	local column = UI.new("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(GOAL_FLAG + 10), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = main,
	})
	UI.list(4).Parent = column

	-- The goal's words (they wrap) with the reward at the right while there is one: updateGoal gives the
	-- words the room it takes.
	local titleRow = UI.new("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = column,
	})
	goalText = Juicy.text("", {
		Name = "Words",
		Size = UDim2.new(1, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = Juicy.Palette.Ink,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleRow,
	}, 0)
	goalReward = Juicy.text("", {
		Name = "Reward",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(0, 24),
		TextColor3 = Juicy.Palette.Money.bottom,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = titleRow,
	}, 0)

	-- The bar, and at its right how far along it is in words ("$66 / $150"). A goal with a button (the
	-- contest's) has no bar: its line, which says what to do on the computer, takes the whole row.
	local barRow = UI.new("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 2,
		Parent = column,
	})
	goalBar = framedBar({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -GOAL_VALUE_ROOM, 0, BAR_HEIGHT),
		Parent = barRow,
	}, "Grass", TRACK_CREAM)
	goalValue = Juicy.text("", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, GOAL_VALUE_ROOM - 10, 1, 0),
		TextColor3 = Juicy.Palette.Ink,
		TextSize = 14,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = barRow,
	}, 0)
	UI.new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9, Parent = goalValue })

	-- The goals rail under that, in the cream (updateMilestones fills it in): a row for each milestone,
	-- one line of words (they shrink to fit it, up to 15 px) over a thin bar. A row has no list in it, so
	-- its stamp and sparkles go where they're put.
	for index = 1, RAIL_ROWS do
		local frame = UI.new("Frame", {
			Name = `Milestone{index}`,
			Size = UDim2.new(1, 0, 0, RAIL_ROW_HEIGHT),
			BackgroundTransparency = 1,
			Visible = false,
			LayoutOrder = 4 + index,
			Parent = body,
		})
		local label = UI.label("", {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 18),
			TextScaled = true,
			TextSize = 15,
			FontFace = Juicy.Font,
			TextColor3 = Juicy.Palette.Ink,
			Parent = frame,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10, Parent = label })
		local bar = UI.bar({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 6), Parent = frame })
		railRows[index] = { frame = frame, label = label, bar = bar }
	end
	-- At the top of the screen, in the toasts' way: they keep below it.
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

-- What finishing `goal` pays, in words ("+$60 · 25 XP"), or nil: only a goal that carries a `cash`
-- or an `xp` has anything to show.
local function rewardText(goal): string?
	local parts = {}
	if typeof(goal.cash) == "number" and goal.cash > 0 then
		table.insert(parts, `+{Format.money(goal.cash)}`)
	end
	if typeof(goal.xp) == "number" and goal.xp > 0 then
		table.insert(parts, `{goal.xp} XP`)
	end
	return if #parts > 0 then table.concat(parts, " · ") else nil
end

-- The banner's progress line: under the bar and at its right, or with a button goal (done at the
-- shop computer) the whole row, at the left, since there is no bar.
local function setGoalValueWide(wide: boolean)
	goalValue.AnchorPoint = Vector2.new(if wide then 0 else 1, 0.5)
	goalValue.Position = UDim2.fromScale(if wide then 0 else 1, 0.5)
	goalValue.Size = if wide then UDim2.fromScale(1, 1) else UDim2.new(0, GOAL_VALUE_ROOM - 10, 1, 0)
	goalValue.TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
end

local function updateGoal()
	updateMilestones()
	local goal = Goal.current()
	-- Where it gives way to something else that takes its spot (the first-job coach and a crew
	-- invite, at the top of the screen too), it hides while that shows.
	goalNote.Visible = goal ~= nil and not UI.givesWay("GrandmaGoal")
	if not goal then
		return
	end
	goalText.Text = goal.text
	-- The reward sits at the right of the words, which leave it room; with none the words have it all.
	local reward = rewardText(goal)
	goalReward.Visible = reward ~= nil
	if reward then
		goalReward.Text = reward
		local width = TextService:GetTextSize(reward, 14, Enum.Font.FredokaOne, Vector2.new(400, 24)).X
		goalReward.Size = UDim2.fromOffset(math.ceil(width) + 2, 24)
		goalText.Size = UDim2.new(1, -(math.ceil(width) + 10), 0, 24)
	else
		goalText.Size = UDim2.new(1, 0, 0, 24)
	end
	local hasButton = goal.button ~= nil
	goalBar.frame.Visible = not hasButton
	setGoalValueWide(hasButton)
	if hasButton then
		-- The contest's: done on the shop computer.
		goalValue.Text = if goal.action == "Start" then "Call the judges from the computer" else "See the computer"
		return
	end
	local have, value = Goal.progress(goal)
	goalValue.Text = value
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
	for _, button in RIGHT_BUTTONS do
		if button.key and input.KeyCode == button.key then
			if button.id == "TopLawns" and player:GetAttribute(PLACING_ATTRIBUTE) ~= nil then
				return
			end
			rightActions[button.id]()
			return
		end
	end
	if input.KeyCode == MISSED_KEY and missedButton.Visible then
		showMissed()
		return
	end
	if input.KeyCode == MOTION_KEY and CameraController.hasMotion() then
		local on = not CameraController.isMotionOn()
		SettingsController.setMotion(on)
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
-- job's name, each to-do on one line, and the damage (once there is some) and a small Call off pill
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
		for _, row in taskRows do
			layoutTaskRow(row)
		end
	end
	trackerHint.Visible = not compact
	timerRow.Visible = trackerTimed and not compact
	-- The full card's last row has the damage (while you work) and the Call off pill.
	damageRow.Visible = not compact and (trackerTimed or callOffShown)
	damageLabel.Visible = trackerTimed
	if damageIcon then
		damageIcon.Visible = trackerTimed
	end
	trackerButton.Visible = callOffShown
	compactTimer.Frame.Visible = trackerTimed and compact
	-- The name leaves room for what is beside it: the timer on a short screen, or the stars.
	local beside = 0
	if trackerTimed and compact then
		beside = COMPACT_TIMER + 6
	elseif trackerStars.Visible then
		beside = 3 * CARD_STAR + 2 * CARD_STAR_GAP + 6
	end
	trackerTitle.Size = UDim2.new(1, -beside, 1, 0)
	compactDamage.Visible = trackerTimed and trackerPenalty > 0
	compactButton.Visible = callOffShown
	compactFooter.Visible = compact and (compactDamage.Visible or callOffShown)
end

-- A Call off pill: Juicy's Danger button with `words` in its face, `size` big, in `parent` at its
-- right. Returns the button and the words.
local function callOffPill(size: Vector2, textSize: number, parent: Frame): (TextButton, TextLabel)
	local button, face = Juicy.button("Danger", callOffJob, {
		Name = "CallOff",
		Size = UDim2.fromOffset(size.X, size.Y),
		Radius = size.Y / 2,
		Stroke = 3,
		Lip = 4,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, -2),
		Parent = parent,
	})
	local words = Juicy.text("", {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
		Parent = face,
	})
	return button, words
end

-- The job tracker: a dark glass card (Juicy's Glass, with the outline and lip of the other pieces) whose
-- holder grows with its words, like the goal banner's: the glass and its lip are as tall as the holder
-- and the words sit in a Body beside them. Down it: the job's name in gold with its stars, the big
-- timer with par, the hint, the to-dos, and the damage with the Call off pill.
local function buildTracker()
	tracker = glassPanel({ Name = "JobTracker", Visible = false }, CARD_RADIUS, CARD_STROKE, CARD_LIP)
	placeInColumn(tracker, "JobTracker")
	trackerBody = UI.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = tracker,
	})
	trackerPadding = UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = trackerBody,
	})
	trackerLayout = UI.list(6)
	trackerLayout.Parent = trackerBody

	-- The job's name, and on a short screen the timer beside it. Once the job is paid its three stars
	-- (grey, filled in gold for the ones it earned) take the timer's place.
	trackerHeader = UI.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = trackerBody,
	})
	trackerTitle = Juicy.text("", {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Juicy.Palette.Gold.top,
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = trackerHeader,
	})
	trackerStars = UI.new("Frame", {
		Name = "Stars",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(3 * CARD_STAR + 2 * CARD_STAR_GAP, CARD_STAR),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = trackerHeader,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, CARD_STAR_GAP),
		}),
	})
	for index = 1, 3 do
		local star: GuiObject? = UI.icon("Level", {
			Name = `Star{index}`,
			Size = UDim2.fromOffset(CARD_STAR, CARD_STAR),
			LayoutOrder = index,
			Parent = trackerStars,
		}, STAR_OFF)
		if not star then
			star = UI.label("★", {
				Name = `Star{index}`,
				Size = UDim2.fromOffset(CARD_STAR, CARD_STAR),
				FontFace = Juicy.Font,
				TextSize = 18,
				TextColor3 = STAR_OFF,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = index,
				Parent = trackerStars,
			})
		end
		trackerStarIcons[index] = star :: GuiObject
	end
	compactTimer = UI.display(
		"Numbers",
		"",
		{ TextSize = 20, Color = WHITE, OutlineColor = Juicy.Palette.Ink, XAlignment = "Right", Fit = true },
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, COMPACT_TIMER, 1, 0),
			Visible = false,
			Parent = trackerHeader,
		}
	)

	-- The timer: "0:42" big and white with an ink outline (red once it is past par), "par 2:30" beside
	-- it at the right.
	timerRow = UI.new("Frame", {
		Name = "Timer",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Visible = false,
		Parent = trackerBody,
	})
	timer = UI.display(
		"Numbers",
		"",
		{ TextSize = 30, Color = WHITE, OutlineColor = Juicy.Palette.Ink, Fit = true },
		{ Size = UDim2.new(1, -104, 1, 0), Parent = timerRow }
	)
	parLabel = Juicy.text("", {
		Name = "Par",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(100, 20),
		TextColor3 = PAR_COLOR,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = timerRow,
	}, 0)
	trackerHint = UI.label("", {
		TextSize = 15,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = trackerBody,
	})
	taskLayout = UI.list(6)
	taskList = UI.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = trackerBody,
	}, { taskLayout })

	-- The full card's last row: the damage so far at the left (while you work) and the Call off pill at
	-- the right (words from setCallOffText).
	damageRow = UI.new("Frame", {
		Name = "Damage",
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Visible = false,
		Parent = trackerBody,
	})
	damageIcon = UI.icon("Damage", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 1, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Parent = damageRow,
	}, UI.Colors.Danger)
	local damageX = if damageIcon then 30 else 0
	damageLabel = UI.label("", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, damageX, 0.5, 0),
		Size = UDim2.new(1, -(damageX + CALL_OFF.X + 8), 0, 22),
		TextSize = 16,
		Parent = damageRow,
	})
	trackerButton, callOffLabel = callOffPill(CALL_OFF, 15, damageRow)

	-- On a short screen the damage (once there is some) and a small Call off pill share a row at the
	-- bottom instead.
	compactFooter = UI.new("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		Visible = false,
		Parent = trackerBody,
	})
	compactDamage = UI.label("", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -(COMPACT_CALL_OFF.X + 12), 0, 18),
		TextSize = 15,
		TextColor3 = UI.Colors.Danger,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = compactFooter,
	})
	compactButton, compactCallOffLabel = callOffPill(COMPACT_CALL_OFF, 14, compactFooter)

	-- Small or full size as the screen changes, like curb appeal's rule.
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTracker)
	layoutTracker()
end

-- The pay bonus pills under the job card: a dark glass pill with a glyph for each of the crew, curb
-- appeal, truck and business bonuses, made once here and shown by updateBoosts while their bonus is
-- above zero. The row is the column's piece (UiLayout's BoostPills): a wrapping, right-aligned row that
-- grows with its pills, and it is hidden when no pill shows.
local function buildBoosts()
	boostRow = UI.new("Frame", { Name = "BoostPills", BackgroundTransparency = 1, Visible = false })
	-- A row of pills that wraps to a second line; UiLayout's entry gives it the rest (direction, gap).
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = true,
		Parent = boostRow,
	})
	placeInColumn(boostRow, "BoostPills")
	for order, boost in BOOSTS do
		local pill = glassPanel({
			Name = boost.id,
			Size = UDim2.fromOffset(0, BOOST_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
			Visible = false,
			Parent = boostRow,
		}, BOOST_HEIGHT / 2, BOOST_STROKE, BOOST_LIP)
		-- The pill's words and glyph sit in a frame beside the glass that sets the pill's width.
		local inside = UI.new("Frame", {
			Name = "Inside",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, BOOST_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 5,
			Parent = pill,
		}, {
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 10) }),
			UI.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 5),
			}),
		})
		UI.icon(boost.icon, {
			Size = UDim2.fromOffset(BOOST_ICON, BOOST_ICON),
			LayoutOrder = 1,
			Parent = inside,
		}, (Juicy.Palette :: any)[boost.tint].top)
		local label = Juicy.text("", {
			Name = "Words",
			Size = UDim2.fromOffset(0, BOOST_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 12,
			LayoutOrder = 2,
			Parent = inside,
		})
		boostPills[boost.id] = { frame = pill, label = label }
	end
end

-- The call-off button's words, on both of the tracker's layouts.
local function setCallOffText(text: string)
	callOffLabel.Text = text
	compactCallOffLabel.Text = text
end

-- "0:42" big with "par 1:30" beside it (the short screen's one is "0:42 / 1:30", beside the job's
-- name), white until it is past par and then red, and the damage so far.
local function updateTimer()
	local job = ClientState.job
	trackerTimed = job ~= nil and job.state == "Working" and job.startedAt ~= nil
	if job and trackerTimed then
		local elapsed = workspace:GetServerTimeNow() - job.startedAt
		local par = Format.time(job.parTime)
		local color = if elapsed <= job.parTime then WHITE else UI.Colors.Danger
		timer:SetText(Format.time(elapsed))
		timer:SetColor(color)
		parLabel.Text = `par {par}`
		compactTimer:SetText(`{Format.time(elapsed)} / {par}`)
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
		FontFace = Juicy.Font,
		Parent = frame,
	})
	-- The bar: a striped fill in a dark track with an ink outline. The mowing row's is the "Mowed"
	-- bar, yellow (setTaskRow).
	local bar = framedBar(
		{ Position = UDim2.fromOffset(x, 22), Size = UDim2.new(1, -x, 0, BAR_HEIGHT), Parent = frame },
		"Grass",
		TRACK_DARK
	)

	-- updateJob adds `fraction` (how done it was at the last update, so it can tell when it's just
	-- been finished) and celebrate adds `stamp`.
	row = { frame = frame, label = label, bar = bar, flag = flag }
	taskRows[taskName] = row
	layoutTaskRow(row)
	return row
end

-- A to-do's line: its words, how far along, and a check once it's done. The bar is `fraction` full,
-- or `shown` when the words say a different share (the mowing row's percent).
local function setTaskRow(row, text: string, fraction: number, fill: string, shown: number?)
	row.label.Text = text
	row.bar.set(shown or fraction)
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

-- Moments the login brings (an unclaimed gift the day turn paid, and a contract or the Bonus Day that
-- its cash meets)
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

-- The day's gift was claimed (`info`: the days in a row, what today paid, day 7's flag if it is day 7,
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

-- A gift was claimed (the Gifts button): the moment above, in turn with the chime of a contract its
-- cash meets, which comes after it. A claim is a press, so the title card is long gone.
local function onStreakAdvanced(info: { days: number, cash: number, flag: string?, tomorrow: number })
	afterTitleCard(showStreakAdvanced, info)
end

-- A gift left unclaimed that the day turn paid for them (`info`: its cash, and whether it was
-- yesterday's or from a visit before that): a toast saying so, the cash register, and the cash lifts
-- off the money counter.
local function showGiftPaid(info: { cash: number, yesterday: boolean })
	local cash = `+{Format.money(info.cash)}`
	UI.notify(if info.yesterday then `Yesterday's gift: {cash}` else `Your unclaimed gift: {cash}`)
	Sounds.playUi("Cash")
	FloatingText.show(money.Frame, cash)
end

-- The turn paid an unclaimed gift: mostly on a login, so it waits for the title card like the
-- contracts and the Bonus Day its cash can meet, which come after it.
local function onGiftPaid(info: { cash: number, yesterday: boolean })
	afterTitleCard(showGiftPaid, info)
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

-- The job's stars on the card's title row: shown once the job is paid, gold for each one it earned
-- and grey for the rest. The count is the server's (`result.stars`, from Stars.of over the finish and
-- the speed); the client can't work it out itself while the job runs, since it is never told the
-- finish's quality or what the customer wanted (the server keeps that off the job it sends), so
-- until the result comes there are no stars rather than a guess.
local function updateStars(job)
	local earned = job and job.result and job.result.stars
	local shown = typeof(earned) == "number"
	trackerStars.Visible = shown
	if not shown then
		return
	end
	for index, star in trackerStarIcons do
		local color = if index <= earned then Juicy.Palette.Gold.top else STAR_OFF
		if star:IsA("ImageLabel") then
			star.ImageColor3 = color
		elseif star:IsA("TextLabel") then
			star.TextColor3 = color
		end
	end
end

-- A bonus as the pill's words: "Crew +15%", the share above zero as a whole percent, or nil when it
-- rounds to nothing.
local function boostWords(label: string, bonus: number): string?
	local percent = math.floor(bonus * 100 + 0.5)
	return if percent > 0 then `{label} +{percent}%` else nil
end

-- The pay bonuses on the job you're on, as the pills under its card: Crew (GameConfig.CrewBonusPerMember
-- for each member of your crew besides its leader), Curb (HomeLawn.payBonus of the leader's curb
-- appeal, which is a player attribute everyone can read) and Truck and Business (the payoutBonus of the
-- items the leader has equipped). JobService works the pay out the same way. The leader's equipped
-- items are only in your own profile, so Truck and Business show when you are the one leading; as a
-- crew member you can't see them and they are left off rather than guessed. Shown only while the card
-- is, and a pill only while its bonus is above zero.
local function updateBoosts()
	local job = ClientState.job
	local words: { [string]: string? } = {}
	if job and tracker.Visible then
		local party = ClientState.party
		local members = if party then #party.members else 1
		words.Crew = boostWords("Crew", GameConfig.CrewBonusPerMember * math.max(0, members - 1))
		local leader = job.leader
		local appeal = if leader then leader:GetAttribute("CurbAppeal") else nil
		if typeof(appeal) == "number" then
			words.Curb = boostWords("Curb", HomeLawn.payBonus(appeal) - 1)
		end
		local profile = ClientState.profile
		if leader == player and profile and profile.equipped then
			local truck = if profile.equipped.Truck then Items.get("Truck", profile.equipped.Truck) else nil
			local business = if profile.equipped.Business then Items.get("Business", profile.equipped.Business) else nil
			words.Truck = if truck then boostWords("Truck", truck.payoutBonus) else nil
			words.Business = if business then boostWords("Business", business.payoutBonus) else nil
		end
	end
	local any = false
	for id, pill in boostPills do
		local text = words[id]
		pill.frame.Visible = text ~= nil
		if text then
			pill.label.Text = text
			any = true
		end
	end
	boostRow.Visible = any
end

local function updateJob()
	local job = ClientState.job
	if not job then
		tracker.Visible = false
		clearTaskRows()
		updateMissedButton()
		updateCurbAppeal()
		updateStars(nil)
		updateBoosts()
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
	updateStars(job)
	updateTimer()
	updateCurbAppeal()
	updateBoosts()

	if not job.tasks then
		clearTaskRows()
		updateMissedButton()
		return
	end
	for order, info in job.tasks do
		local row = getTaskRow(info.task, order)
		local fraction = if info.needed > 0 then info.done / info.needed else 1
		-- Mowing says how much of the lawn is cut, on the yellow Mowed bar; the other to-dos count what's
		-- done, on a green one that goes yellow when it is.
		local progress = if info.percent then percentText(info.percent) else `{info.done}/{info.needed}`
		local fill = if info.percent or fraction >= 1 then "Money" else "Grass"
		setTaskRow(row, `{info.label}  {progress}`, fraction, fill, info.percent)
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
	buildRightButtons()
	buildGoal()
	buildCurbAppeal()
	buildNextChip()
	buildTracker()
	buildBoosts()
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
			updateGiftTag()
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
	Net.event("StreakGiftPaid").OnClientEvent:Connect(onGiftPaid)
	UI.TitleCardDone:Connect(playHeld)
	updateGoal()
	updateContractsBadge()
	updateStreak()
	updateGiftTag()
	updateCountdown()

	-- The Gifts button pulses while its CLAIM tag is up.
	task.spawn(function()
		while true do
			task.wait(GIFT_PULSE_EVERY)
			if giftTag then
				pulseGifts()
			end
		end
	end)

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
			updateBoosts()
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
