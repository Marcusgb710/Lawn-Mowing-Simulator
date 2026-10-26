-- Always-on screen stuff, laid out like the art's HUD (alphainstructions/instructions38.md):
--   * down the left: money and level (the money counter in the display face), the menu buttons
--     with their glyphs (and on a keyboard their keys: T, G, C), and Grandma's sticky note with
--     your story goal;
--   * down the right: your business's curb appeal, and the job tracker (to-dos, a timer against
--     par, damage);
--   * the condition of the tool in your hands ("Running low on fuel");
--   * the pay breakdown when a job's done, and the big moments: Level Up! and New Tool!
-- On a keyboard V switches camera motion on and off.

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
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local Goal = require(script.Parent.Parent.Goal)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

-- The menu buttons down the left, their glyphs, and the key that opens each one. Jobs and orders
-- are on the computer in your shop (see ComputerController).
local MENUS = {
	{ name = "Truck", key = Enum.KeyCode.T },
	{ name = "Guide", key = Enum.KeyCode.G },
	{ name = "Crew", key = Enum.KeyCode.C },
}
local MOTION_KEY = Enum.KeyCode.V
-- The columns down each side are full size on screens at least this tall (in pixels), and shrink
-- on shorter ones (phones held sideways), down to SIDE_MIN_SCALE, or further (to SIDE_TIGHT_SCALE)
-- if that's what it takes to fit everything in a column on the screen.
local SIDE_FULL_HEIGHT = 560
local SIDE_MIN_SCALE = 0.7
local SIDE_TIGHT_SCALE = 0.5
local SIDE_WIDTH = 220
local TRACKER_WIDTH = 280
-- Room for the key badge at the left of a menu button.
local KEY_ROOM = 46

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
local trackerTitle: TextLabel
local trackerHint: TextLabel
local timerRow: Frame
local timer
local damageLabel: TextLabel
local taskList: Frame
local trackerButton: TextButton
local taskRows = {}
local shownJobId = nil
local conditionPanel: GuiObject
local conditionLabel: TextLabel

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

-- Shows what's wrong with the tool you're holding, or how long until you finish working on one.
local function updateCondition()
	local untilTime = player:GetAttribute("MaintainingUntil")
	if typeof(untilTime) == "number" then
		local left = math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow()))
		conditionLabel.Text = `Working on it... {left}s`
		conditionPanel.Visible = true
		return
	end
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local item = tool and Tools.get(tool:GetAttribute("ItemId"))
	if not (tool and item) then
		conditionPanel.Visible = false
		return
	end
	local condition = {}
	for key, attribute in CONDITION_ATTRIBUTES do
		condition[key] = tool:GetAttribute(attribute)
	end
	local warnings = Maintenance.warnings(item, condition)
	conditionPanel.Visible = #warnings > 0
	conditionLabel.Text = table.concat(warnings, "  ·  ")
end

local function buildCondition()
	conditionPanel = UI.sliced("Tooltip", {
		Name = "ToolCondition",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.new(0.9, 0, 0, 36),
		Visible = false,
		Parent = UI.getScreen(),
	}, { color = UI.Colors.Background, transparency = 0.25, radius = 8 })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge), Parent = conditionPanel })
	local icon = UI.icon("Wrench", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Parent = conditionPanel,
	}, UI.Colors.Money)
	local left = if icon then 38 else 10
	conditionLabel = UI.label("", {
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + 10), 1, 0),
		TextColor3 = UI.Colors.Money,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextScaled = true,
		Parent = conditionPanel,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = conditionLabel })
end

-- The columns down each side -------------------------------------------------------------------

-- Scales a column to fit: full size on a tall screen, smaller on a short one, and smaller still if
-- everything in it wouldn't otherwise fit on the screen.
local function fitColumn(column: Frame, scale: UIScale)
	local function fit()
		local height = UI.getScreen().AbsoluteSize.Y
		if height <= 0 then
			local camera = workspace.CurrentCamera
			height = if camera then camera.ViewportSize.Y else SIDE_FULL_HEIGHT
		end
		local wanted = math.clamp(height / SIDE_FULL_HEIGHT, SIDE_MIN_SCALE, 1)
		-- The column's own height, before scaling.
		local content = column.AbsoluteSize.Y / math.max(scale.Scale, 0.01)
		if content > 0 then
			wanted = math.min(wanted, math.max(SIDE_TIGHT_SCALE, (height - 24) / content))
		end
		if math.abs(scale.Scale - wanted) > 0.005 then
			scale.Scale = wanted
		end
	end
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	column:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

-- The money and level panel, the menu buttons and the goal stack in one column down the left, so
-- they can't run into each other on a short screen (a phone held sideways), and it shrinks to fit.
local side: Frame
local right: Frame
local function buildColumns()
	side = UI.new("Frame", {
		Name = "Side",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(SIDE_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = UI.getScreen(),
	}, { UI.list(10) })
	fitColumn(side, UI.new("UIScale", { Parent = side }))

	-- Curb appeal and the job tracker down the right.
	right = UI.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(TRACKER_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = UI.getScreen(),
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local rightScale = UI.new("UIScale", { Parent = right })
	-- It scales from its top right corner, so it stays in the corner.
	fitColumn(right, rightScale)
end

local function buildStats()
	local frame = hudPanel({
		Name = "Stats",
		Size = UDim2.fromOffset(SIDE_WIDTH, 104),
		LayoutOrder = 1,
		Parent = side,
	})
	UI.padding(10).Parent = frame
	local moneyIcon = UI.icon(
		"Money",
		{ Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, 5), Parent = frame },
		UI.Colors.Money
	)
	local moneyX = if moneyIcon then 36 else 0
	money = UI.display(
		"Numbers",
		"$0",
		{ TextSize = 30, Color = UI.Colors.Money, Fit = true },
		{ Position = UDim2.fromOffset(moneyX, 2), Size = UDim2.new(1, -moneyX, 0, 34), Parent = frame }
	)
	local levelIcon =
		UI.icon("Level", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 44), Parent = frame })
	local levelX = if levelIcon then 24 else 0
	levelLabel = UI.label("Level 1", {
		Position = UDim2.fromOffset(levelX, 42),
		Size = UDim2.new(1, -levelX, 0, 20),
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Parent = frame,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = levelLabel })
	xpBar = UI.bar({
		Position = UDim2.fromOffset(levelX, 68),
		Size = UDim2.new(1, -levelX, 0, 10),
		Parent = frame,
	})
end

-- Your crew's business's curb appeal (see HomeLawnService), which pays a bonus on jobs.
local function buildCurbAppeal()
	curbPanel = hudPanel({
		Name = "CurbAppeal",
		Size = UDim2.fromOffset(SIDE_WIDTH, 78),
		LayoutOrder = 1,
		Visible = false,
		Parent = right,
	})
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
	-- On a short screen (a phone) the job tracker needs the room while a job's on.
	local short = UI.getScreen().AbsoluteSize.Y < SIDE_FULL_HEIGHT
	curbPanel.Visible = typeof(value) == "number" and not (short and tracker.Visible)
	if typeof(value) == "number" then
		curbValue.Text = `{value} / 100`
		curbBar.set(value / 100)
	end
end

local function buildMenuButtons()
	local frame = UI.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(150, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = side,
	}, { UI.list(8) })

	local keyboard = UserInputService.KeyboardEnabled
	for index, menu in MENUS do
		local button = UI.button(menu.name, function()
			UI.toggle(menu.name)
		end, {
			Style = "Menu",
			Icon = menu.name,
			Size = UDim2.fromOffset(150, 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
			Parent = frame,
		})
		-- Room for the key badge on the left (the glyph goes after it).
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
			UI.heading(UserInputService:GetStringForKeyCode(menu.key), {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 18,
				ZIndex = 3,
				Parent = badge,
			})
		end
	end
	if keyboard then
		-- The mouse is locked to the middle of the screen in first person.
		UI.label("Hold Alt for the mouse", {
			Size = UDim2.fromOffset(150, 16),
			TextSize = 13,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			TextStrokeTransparency = 0.6,
			LayoutOrder = #MENUS + 1,
			Parent = frame,
		})
	end
end

-- Grandma's sticky note: your story goal, and how close you are.
local function buildGoal()
	goalNote = UI.sliced("StickyNote", {
		Name = "Goal",
		Size = UDim2.fromOffset(SIDE_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
		Parent = side,
	}, { color = UI.Colors.Grandma, radius = 6 })
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
end

local function updateGoal()
	local goal = Goal.current()
	goalNote.Visible = goal ~= nil
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
	if input.KeyCode == MOTION_KEY and CameraController.hasMotion() then
		local on = not CameraController.isMotionOn()
		CameraController.setMotion(on)
		UI.notify(if on then "Camera motion on" else "Camera motion off")
	end
end

-- The job tracker --------------------------------------------------------------------------------

local function buildTracker()
	tracker = hudPanel({
		Name = "JobTracker",
		Size = UDim2.fromOffset(TRACKER_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Visible = false,
		Parent = right,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = tracker,
	})
	UI.list(6).Parent = tracker

	trackerTitle = UI.heading("", {
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 24,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = tracker,
	})
	trackerHint = UI.label("", {
		TextSize = 15,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = tracker,
	})
	taskList = UI.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = tracker,
	}, { UI.list(6) })
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
	local damageRow = UI.new("Frame", {
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
	trackerButton = UI.button("", function()
		Net.event("AbandonJob"):FireServer()
	end, {
		Size = UDim2.new(1, 0, 0, 36),
		Style = "Danger",
		TextSize = 16,
		LayoutOrder = 6,
		Parent = tracker,
	})
end

-- "0:42 / 1:30" against par, and the damage so far.
local function updateTimer()
	local job = ClientState.job
	local damageRow = damageLabel.Parent :: Frame
	if not (job and job.state == "Working" and job.startedAt) then
		timerRow.Visible = false
		damageRow.Visible = false
		return
	end
	local elapsed = workspace:GetServerTimeNow() - job.startedAt
	timer:SetText(`{Format.time(elapsed)} / {Format.time(job.parTime)}`)
	timer:SetColor(if elapsed <= job.parTime then UI.Colors.Money else UI.Colors.Danger)
	timerRow.Visible = true
	damageRow.Visible = true
	damageLabel.Text = `Damage  -{Format.money(job.penalty)}`
	damageLabel.TextColor3 = if job.penalty > 0 then UI.Colors.Danger else UI.Colors.SubText
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

	row = { frame = frame, label = label, bar = bar, flag = flag }
	taskRows[taskName] = row
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
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = UI.getScreen(),
	}, { color = UI.Colors.Background, radius = 14 })
	-- Scaled down to fit a short screen.
	local scale = UI.new("UIScale", { Parent = payPanel })
	local function fit()
		local screen = UI.getScreen().AbsoluteSize
		local height = payPanel.AbsoluteSize.Y / math.max(scale.Scale, 0.01)
		if height > 0 and screen.Y > 0 then
			scale.Scale = math.min(1, (screen.Y - 24) / height, (screen.X - 24) / 500)
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
	UI.wordmark("JobComplete", "Job Complete!", 64, { LayoutOrder = 1, Parent = payPanel })
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
	tracker.Visible = true
	trackerTitle.Text = string.upper(job.name)
	local isLeader = job.leader == player
	trackerButton.Visible = true

	if job.state == "Ready" then
		trackerHint.Text = if isLeader
			then `{job.address} · {Format.money(job.payout)}\nLoad the tools you think you'll need, then hop in!`
			else `{job.address} · {Format.money(job.payout)}\nWaiting for {job.leader.DisplayName} to start the truck.`
		trackerButton.Text = "Cancel job"
		trackerButton.Visible = isLeader
	elseif job.state == "Traveling" then
		trackerHint.Text = `Driving to {job.address}...`
		trackerButton.Visible = false
	elseif job.state == "Working" then
		trackerHint.Text = if job.story then `"{job.story}"  - {job.customer}` else "Don't hit the flowers or gnomes!"
		if job.soil then
			trackerHint.Text ..= `\nSoil probe: {job.soil}`
		end
		trackerButton.Text = if isLeader then "Call off job" else "Leave job"
	elseif job.state == "Complete" then
		trackerHint.Text = if job.result
			then `You earned {Format.money(job.result.share)}! Heading back soon...`
			else "Job done!"
		trackerButton.Visible = false
		if job.result and payShownFor ~= job.id then
			payShownFor = job.id
			showPay(job)
		end
	end
	updateTimer()
	updateCurbAppeal()

	if not job.tasks then
		clearTaskRows()
		return
	end
	for order, info in job.tasks do
		local row = getTaskRow(info.task, order)
		local fraction = if info.needed > 0 then info.done / info.needed else 1
		setTaskRow(row, `{info.label}  {info.done}/{info.needed}`, fraction, if fraction >= 1 then "Money" else "Grass")
	end
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
	updateGoal()

	task.spawn(function()
		while true do
			task.wait(0.25)
			updateTimer()
			updateCondition()
			updateCurbAppeal()
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
