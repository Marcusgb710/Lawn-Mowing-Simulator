-- Always-on screen stuff, laid out like the art's HUD (alphainstructions/instructions38.md):
--   * down the left: money and level (the money counter in the display face), the menu buttons
--     with their glyphs (and on a keyboard their keys: T, G, C), and Grandma's sticky note with
--     your story goal;
--   * down the right: your business's curb appeal, the job tracker on the art's GoalTracker
--     card (to-dos, a timer against par, damage), smaller on a phone, and under it, late in the
--     mowing, the button that lights up the grass you missed (M on a keyboard);
--   * the condition of the tool in your hands, a glyph for each thing wrong ("Running low on
--     fuel" by the fuel can), or what you're doing to one at the workbench;
--   * the pay breakdown when a job's done, and the big moments: Level Up! and New Tool!
-- On a keyboard V switches camera motion on and off. Where each piece goes is in UiLayout.luau,
-- which can also take any of the columns' pieces out of its column to go anywhere on the screen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Jobs = require(Shared.Config.Jobs)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local PayBreakdown = require(Shared.PayBreakdown)
local Sounds = require(Shared.Sounds)
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local Goal = require(script.Parent.Parent.Goal)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)
local GrassController = require(script.Parent.GrassController)

local player = Players.LocalPlayer

-- The menu buttons down the left, their glyphs, the key that opens each one, and its button's
-- place in UiLayout.luau. Jobs and orders are on the computer in your shop (see
-- ComputerController).
local MENUS = {
	{ name = "Truck", key = Enum.KeyCode.T, layout = "TruckButton" },
	{ name = "Guide", key = Enum.KeyCode.G, layout = "GuideButton" },
	{ name = "Crew", key = Enum.KeyCode.C, layout = "CrewButton" },
}
local MOTION_KEY = Enum.KeyCode.V
-- The key for the "Show what I missed" button (see buildMissedButton).
local MISSED_KEY = Enum.KeyCode.M
-- A finished mowing row gets a stamp over it (the art's "Job Complete!", the only stamp that says
-- done), this tall, with this many sparkles round it.
local DONE_STAMP_HEIGHT = 40
local DONE_SPARKLES = 5
-- The columns down each side are full size on screens at least `fullHeight` tall (in pixels), and
-- shrink on shorter ones (phones held sideways), down to `minScale`, or further (to `tightScale`)
-- if that's what it takes to fit everything in a column on the screen. A piece taken out of its
-- column shrinks the same way on its own.
local COLUMNS = UI.Layout.__screen.scaling.Columns
-- Room for the key badge at the left of a menu button.
local KEY_ROOM = 46
-- On a short screen the job tracker's timer goes beside the job's name, in a box this wide.
local COMPACT_TIMER = 112

local HudController = {}

local money
local levelLabel: TextLabel
local xpBar: UI.Bar
local curbPanel: GuiObject
local curbValue: TextLabel
local curbBar: UI.Bar

local goalNote: GuiObject
local goalText: TextLabel
local goalValue: TextLabel
local goalBar: UI.Bar

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
local lastLevel: number? = nil
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

-- Low and wide, so it takes little of a short screen's height: the money, then your level and jobs
-- done, then the XP bar, close together.
local function buildStats()
	local frame = hudPanel({ Name = "Stats" })
	placeInColumn(frame, "MoneyPanel")
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = frame,
	})
	local moneyIcon = UI.icon(
		"Money",
		{ Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(0, 2), Parent = frame },
		UI.Colors.Money
	)
	local moneyX = if moneyIcon then 32 else 0
	money = UI.display(
		"Numbers",
		"$0",
		{ TextSize = 26, Color = UI.Colors.Money, Fit = true },
		{ Position = UDim2.fromOffset(moneyX, 0), Size = UDim2.new(1, -moneyX, 0, 28), Parent = frame }
	)
	local levelIcon =
		UI.icon("Level", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 32), Parent = frame })
	local levelX = if levelIcon then 22 else 0
	levelLabel = UI.label("Level 1", {
		Position = UDim2.fromOffset(levelX, 30),
		Size = UDim2.new(1, -levelX, 0, 18),
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Parent = frame,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 15, Parent = levelLabel })
	xpBar = UI.bar({
		Position = UDim2.fromOffset(levelX, 51),
		Size = UDim2.new(1, -levelX, 0, 8),
		Parent = frame,
	})
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

local function buildMenuButtons()
	local frame = UI.new("Frame", { Name = "Menu", BackgroundTransparency = 1 })
	placeInColumn(frame, "MenuButtons")

	for _, menu in MENUS do
		local button = UI.button(menu.name, function()
			UI.toggle(menu.name)
		end, {
			Style = "Menu",
			Icon = menu.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		UI.keepPlaced(button, menu.layout)
		addKeyBadge(button, menu.key)
	end
	if UserInputService.KeyboardEnabled then
		-- The mouse is locked to the middle of the screen in first person.
		local hint = UI.label("Hold Alt for the mouse", {
			TextSize = 13,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			TextStrokeTransparency = 0.6,
			Parent = frame,
		})
		UI.keepPlaced(hint, "MouseHint")
	end
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
	-- Out of its column at the top of the screen (on a touch screen), the toasts keep below it.
	UI.keepToastsBelow(goalNote)
end

local function updateGoal()
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

-- After a job: Job Complete!, a line for what each part was worth, and what you earned, until you
-- close it (or the next job starts).
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
		UI.label(`{sign}{Format.money(math.abs(line.amount))}`, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 110, 1, 0),
			TextSize = 19,
			FontFace = UI.Fonts.Heavy,
			TextColor3 = if line.amount < 0 then UI.Colors.Danger else UI.Colors.Money,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
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
	UI.display(
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
		LayoutOrder = 52,
		Parent = payPanel,
	})
	local buttonRow = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = 53,
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

-- The big moments: a new level, a new tool (not the ones you had when you joined).
local function moments(profile)
	if lastLevel and profile.level > lastLevel then
		UI.moment("LevelUp", "Level Up!", `Level {profile.level}`)
	end
	lastLevel = profile.level
	local now = {}
	for _, item in Items.ownedTools(profile.owned) do
		now[item.id] = true
		if knownTools and not knownTools[item.id] then
			UI.moment("NewTool", "New Tool!", item.name)
		end
	end
	knownTools = now
end

local function updateProfile()
	local profile = ClientState.profile
	if not profile then
		return
	end
	money:SetText(Format.money(profile.money))
	levelLabel.Text =
		`Level {profile.level}  ·  {profile.jobsCompleted} {if profile.jobsCompleted == 1 then "job" else "jobs"} done`
	local from = GameConfig.xpForLevel(profile.level)
	local to = GameConfig.xpForLevel(profile.level + 1)
	xpBar.set((profile.xp - from) / (to - from))
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
			then `You earned {Format.money(job.result.share)}! Heading back soon...`
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
	buildMenuButtons()
	buildGoal()
	buildCurbAppeal()
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
		end
	end)
	player:GetAttributeChangedSignal("CurbAppeal"):Connect(updateGoal)
	UI.onGiveWay("GrandmaGoal", updateGoal)
	UI.onGiveWay("JobTracker", updateJob)
	updateGoal()

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
