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
--     are above zero), under those the lawn map (a top-down picture of the job's lawn, cut and uncut, where
--     there's room), and under that, late in the mowing, the button that lights up the grass you
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
--   * a clean stripe (GrassController.StripDone: a mower pass of 30 studs or more with no blade hit) is
--     cheered in the middle of the screen by a tilted gold NICE STRIPE! (or CLEAN CUT!, PERFECT LINE! in
--     turn), at most once every 8 seconds and never over a menu, the pay panel or a scene: cosmetic, it
--     pays nothing and tells the server nothing;
--   * cash and XP coming in lift off the piece of the HUD they came from (FloatingText) and ring
--     (Sounds.playUi): the pay panel's total and tip, a goal's row or the Next chip, the Contracts
--     square (ContractDone), the money counter (the streak's gift), the level pill and the XP bar.
-- On a keyboard V switches camera motion on and off (saved, through SettingsController). Where each piece goes is in UiLayout.luau,
-- which can also take any of the columns' pieces out of its column to go anywhere on the screen.
-- This file builds the HUD and keeps it up to date; the front-page pieces are drawn in their own
-- modules in src/client/Hud (a module's top level holds at most 200 locals, and one file had hit that):
-- Columns (the two columns and their placing and fitting rules), Bits (the framed bar and corner key
-- badge they share), StatPills (the money, level, streak and countdown pills), MenuSquares (the four
-- left squares and the Contracts badge), RightStrip (Shop, Gifts, Top Lawns and Settings), JobCard (the
-- job card and the boost pills), LawnMap (the lawn map under them) and Splash (the clean-stripe cheer). Grandma's goal banner, the goals
-- rail, curb appeal, the tool's condition, the pay breakdown and the big moments are drawn here.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local ClientState = require(script.Parent.Parent.ClientState)
local FloatingText = require(script.Parent.Parent.FloatingText)
local Goal = require(script.Parent.Parent.Goal)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)
local GrassController = require(script.Parent.GrassController)
local SettingsController = require(script.Parent.SettingsController)
local Hud = script.Parent.Parent.Hud
local Bits = require(Hud.Bits)
local Columns = require(Hud.Columns)
local JobCard = require(Hud.JobCard)
local MenuSquares = require(Hud.MenuSquares)
local RightStrip = require(Hud.RightStrip)
local Splash = require(Hud.Splash)
local StatPills = require(Hud.StatPills)

local player = Players.LocalPlayer

local MOTION_KEY = Enum.KeyCode.V
-- The key for the "Show what I missed" button (see buildMissedButton).
local MISSED_KEY = Enum.KeyCode.M
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
-- tip's is Bits.SMALL_POP pixels tall, under the cash's.
local PAY_POP_DELAY = 0.25
-- A level's cash lifts off the level line this long after the level-up arrives, so it doesn't ride
-- the XP pop off the bar just under it (and lines up with the Level Up moment).
local LEVEL_POP_DELAY = 0.3
-- Contracts paid in the same moment (one job can meet two) ring and pop this far apart, and the Bonus
-- Day after them, so each one is heard and seen on its own and the payoff comes last.
local CONTRACT_GAP = 0.6
-- Room for the key badge at the left of a menu button.
local KEY_ROOM = 46
-- The countdown is worked out again this often (seconds): it counts down in hours.
local COUNTDOWN_REFRESH = 60
local WHITE = Color3.new(1, 1, 1)
-- Grandma's goal banner: how round its cream face is, the red flag circle at its left, and the room
-- at the right of its bar for the words that say how far along it is ("$66 / $150").
local GOAL_RADIUS = 22
local GOAL_FLAG = 34
local GOAL_VALUE_ROOM = 104
local FLAG_RED = Color3.fromHex("FF5A5F")
-- The track of the banner's bar.
local TRACK_CREAM = Color3.fromHex("D9D2BC")

local HudController = {}

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

-- Your crew's business's curb appeal (see HomeLawnService), which pays a bonus on jobs.
local function buildCurbAppeal()
	curbPanel = hudPanel({ Name = "CurbAppeal", Visible = false })
	Columns.placeInColumn(curbPanel, "CurbAppeal")
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
	curbPanel.Visible = typeof(value) == "number" and not (Columns.shortScreen() and JobCard.isShown())
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

-- Changes what a right button does ("Gifts" or "Settings", or any of the four by its id), so the task
-- that wires it up needs no new button (RightStrip keeps the buttons and what they do).
function HudController.setRightAction(id: string, action: () -> ())
	RightStrip.setRightAction(id, action)
end

-- Grandma's goal: a cream banner at the top in the middle of the screen (UiLayout's GrandmaGoal), a red
-- flag, your story goal in a line or two, what finishing it pays when it pays something, and a bar
-- for how close you are, and under that the goals rail's rows. The banner is a Juicy cream face
-- whose holder grows with the words: the holder is the piece UiLayout places, the Face behind and the
-- Lip under it are as tall as it, and the words sit in a Body beside them that sets the height.
local function buildGoal()
	goalNote = Juicy.face("Cream", { Name = "Goal", Radius = GOAL_RADIUS, Visible = false })
	Columns.placeInColumn(goalNote, "GrandmaGoal")
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
	goalBar = Bits.framedBar({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -GOAL_VALUE_ROOM, 0, Bits.BAR_HEIGHT),
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
	Columns.placeInColumn(nextChip, "NextChip")
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
	local compact = Columns.shortScreen()
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
	if Columns.shortScreen() then
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
			FloatingText.show(StatPills.moneyFrame(), cash)
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
	Columns.placeInColumn(missedButton, "MissedButton")
	-- The key badge goes on before the button is juiced: juice moves the kit's Icon into an inner frame, and
	-- the badge looks for the Icon (as a direct child) to see how much room to leave it.
	addKeyBadge(missedButton, MISSED_KEY)
	Juicy.juice(missedButton)
	Columns.addHitStrips(missedButton, showMissed, "RightColumn")
end

local function onKey(input: InputObject, processed: boolean)
	-- `processed` is set while typing in chat or a text box. While a scene or the drive cutscene
	-- has the screen, the HUD is hidden and its keys do nothing.
	if processed or not UI.getScreen().Enabled then
		return
	end
	for _, menu in MenuSquares.MENUS do
		if input.KeyCode == menu.key then
			UI.toggle(menu.name)
			return
		end
	end
	if RightStrip.pressKey(input.KeyCode) then
		return
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

-- The job tracker (JobCard draws it) ---------------------------------------------------------------

-- Whether the "Show what I missed" button shows: while the job tracker does, from the time a
-- mowing to-do (the one with a percent, of what the job requires) is MissedSpotsFrom done until it
-- counts as finished, and only while there's a lawn to light up: one on a job site, near you and
-- drawn as a surface (the simple renderer has nothing to tint). Where you are and what's drawn
-- change without a job update, so the 0.25 s loop in Start checks again.
local function updateMissedButton()
	local job = ClientState.job
	local show = false
	if job and job.tasks and JobCard.isShown() and GrassController.jobLawnFolder() then
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
			FloatingText.show(tipAmount, `+{Format.money(result.tip)} tip`, nil, Bits.SMALL_POP)
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
	-- Its handler destroys the panel, and so the button, so it plays its own click first (silent).
	local niceButton = UI.button("Nice!", function()
		Juicy.click()
		hidePay()
	end, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(220, 46),
		TextSize = 20,
		Parent = buttonRow,
	})
	Juicy.juice(niceButton, nil, true)
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
			FloatingText.show(StatPills.levelLine(), `+{Format.money(info.cash)}`)
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
		if not FloatingText.show(MenuSquares.contractsFace(), cash) then
			FloatingText.show(StatPills.moneyFrame(), cash)
		end
	end
end

-- The server's paid a contract (`info`: its id, its words and its cash). Two paid in one frame
-- (one job can meet two) don't play on top of each other: each waits its turn, CONTRACT_GAP after the
-- one before, and all of them wait for the title card. The Contracts square's badge follows with the
-- view, which the server sends once it has paid.
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
		FloatingText.show(StatPills.moneyFrame(), `+{Format.money(info.cash)}`)
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
	FloatingText.show(StatPills.moneyFrame(), cash)
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
	StatPills.updateProfile(profile)
	moments(profile)
	updateGoal()
end

-- A job update: the card and its pills (JobCard), then what goes with them here. A different job puts
-- the last one's pay panel away, and a finished one with its result shows its own, once.
local function updateJob()
	local job = ClientState.job
	local newJob = JobCard.update(job)
	if job then
		if newJob and payShownFor ~= job.id then
			hidePay()
		end
		if job.state == "Complete" and job.result and payShownFor ~= job.id then
			payShownFor = job.id
			showPay(job)
		end
	end
	updateCurbAppeal()
	updateMissedButton()
end

function HudController:Start()
	Columns.build()
	StatPills.build()
	MenuSquares.build()
	-- Other controllers build on the Gifts and Settings buttons (a tag on Gifts, the window behind Settings).
	local strip = RightStrip.build()
	HudController.giftsButton = strip.giftsButton
	HudController.giftsFace = strip.giftsFace
	HudController.settingsButton = strip.settingsButton
	HudController.settingsFace = strip.settingsFace
	buildGoal()
	buildCurbAppeal()
	buildNextChip()
	JobCard.build()
	-- The lawn map under the boost pills. Required here and not at the top, which keeps HudController's top
	-- level (at most 200 locals, see scripts/check-compile) where it was.
	require(Hud.LawnMap).build()
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
				StatPills.updateCountdown()
			end
		elseif key == "contracts" then
			MenuSquares.updateContractsBadge()
			StatPills.updateStreak()
			RightStrip.updateGiftTag()
		end
	end)
	player:GetAttributeChangedSignal("CurbAppeal"):Connect(updateGoal)
	player:GetAttributeChangedSignal("GoldSign"):Connect(StatPills.updateGoldSign)
	StatPills.updateGoldSign()
	UI.onGiveWay("GrandmaGoal", updateGoal)
	UI.onGiveWay("JobTracker", updateJob)
	-- The rail hides and the Next chip shows when the screen turns short, and the other way (a window
	-- resized).
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if Columns.shortScreen() ~= railCompact then
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
	-- The clean-stripe splash keeps off the pay panel.
	Splash.start(function()
		return payPanel ~= nil
	end)
	updateGoal()
	MenuSquares.updateContractsBadge()
	StatPills.updateStreak()
	RightStrip.updateGiftTag()
	StatPills.updateCountdown()

	-- The Gifts button pulses while its CLAIM tag is up.
	task.spawn(function()
		while true do
			task.wait(RightStrip.GIFT_PULSE_EVERY)
			RightStrip.pulseWaitingGift()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(COUNTDOWN_REFRESH)
			StatPills.updateCountdown()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			JobCard.updateTimer()
			updateCondition()
			updateCurbAppeal()
			JobCard.updateBoosts()
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
