-- The Levels panel: your level and the XP to the next one, your streak ("Streak: Day 3 of 7, next
-- $300", once the server has sent it), then what the next five levels pay.
-- The XP bar in the stats panel opens it (HudController calls LevelsController.toggle), and so does
-- L on a keyboard. Its Close button, the X in its corner and Escape close it.
--
-- It's a window of its own in the middle of the game's screen, not one of UI.panel's menus, so it
-- looks after its own closing: when your job changes state (one accepted, the truck pulling out,
-- the lawn done), when a scene, the drive or the contest takes the screen, when you sit down at the
-- shop computer, and when you open one of the menus, since only one window is up at a time. It's
-- scaled down to fit the screen the way the pay breakdown is (UiLayout's
-- __screen.scaling.LevelsPanel). Centred, it's already clear of Roblox's move stick and jump
-- button, so a touch screen gets the same margin.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Levels = require(Shared.Config.Levels)
local Season = require(Shared.Config.Season)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local ContractsController = require(script.Parent.ContractsController)

local LevelsController = {}

local OPEN_KEY = Enum.KeyCode.L
-- How many of the levels ahead it lists, and how tall each one's row is, with the gap between.
local ROWS = 5
local ROW_HEIGHT = 44
local ROW_GAP = 4
-- The panel is never drawn smaller than this, however short the screen is: past it, it couldn't
-- be read anyway.
local SMALLEST_SCALE = 0.25
-- What it holds the mouse free under while it's up (UI.holdCursor), so first person lets go of it.
local CURSOR_HOLDER = "Levels"

local panel: GuiObject
local scale: UIScale
local panelWidth = 0
local panelHeight = 0
local header: TextLabel
local streakLine: TextLabel
local xpBar: UI.Bar
local rows: Frame
-- Your job's id and state the last time either changed, to close the panel when they do.
local jobStep: string? = nil

-- 1234 -> "1,234". Format.money does the commas, so its dollar sign comes off.
local function commas(amount: number): string
	return string.sub(Format.money(amount), 2)
end

-- Draws a row for level `level`, the `index`th down: "Level 4" on the left, what it pays on the
-- right (it wraps to two lines for the long ones, like "A gold business sign and $5,000"). A level
-- already claimed has a tick in front of it and its words muted; none should be ahead of you, but
-- the save is what says.
local function addRow(index: number, level: number, text: string, claimed: boolean)
	local row = UI.card({
		Name = `Level{level}`,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = index,
		Parent = rows,
	})
	local x = 12
	if claimed then
		local tick = UI.icon("Check", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Parent = row,
		}, UI.Colors.Money)
		if not tick then
			UI.label("✓", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, x, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				TextSize = 16,
				TextColor3 = UI.Colors.Money,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = row,
			})
		end
		x += 24
	end
	UI.label(`Level {level}`, {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(0, 76, 1, 0),
		TextSize = 17,
		FontFace = UI.Fonts.Heavy,
		TextColor3 = if claimed then UI.Colors.SubText else UI.Colors.Text,
		Parent = row,
	})
	UI.label(text, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(1, -(x + 88), 1, 0),
		TextSize = 16,
		FontFace = UI.Fonts.Medium,
		TextColor3 = if claimed then UI.Colors.SubText else UI.Colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
end

-- Your level and the XP to the next, your streak, the bar, and the next five rewards, from the
-- profile (and the day's view, for the streak). The streak line is hidden until there's one.
local function render()
	local profile = ClientState.profile
	if not profile then
		return
	end
	local level = profile.level
	local from = GameConfig.xpForLevel(level)
	local to = GameConfig.xpForLevel(level + 1)
	header.Text = `Level {level}, {commas(math.max(0, to - profile.xp))} XP to level {level + 1}`
	local streak = ContractsController.streakLine(ClientState.contracts)
	streakLine.Visible = streak ~= nil
	if streak then
		streakLine.Text = `Streak: {streak}`
	end
	xpBar.set((profile.xp - from) / (to - from))
	UI.clearList(rows)
	local claimed = profile.levelRewards or {}
	for index, upcoming in Levels.nextRewards(level, ROWS) do
		addRow(index, upcoming.level, upcoming.reward.text, claimed[Season.levelKey(upcoming.level)] == true)
	end
end

-- Sizes the panel to the screen (__screen.scaling.LevelsPanel): the smallest of its biggest scale
-- and what fits the screen's height and width less their margins (the touch height margin is the
-- same as the other), times its own scale in UiLayout.
local function fit()
	local screen = UI.getScreen().AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	local rule = UI.Layout.__screen.scaling.LevelsPanel
	local margin = if UI.isTouch() then rule.touchMargin else rule.margin
	local wanted = math.min(rule.scale, (screen.Y - margin) / panelHeight, (screen.X - rule.margin) / panelWidth)
	scale.Scale = math.max(wanted, SMALLEST_SCALE) * UI.layout("LevelsPanel").scale
end

local function close()
	if not panel or not panel.Visible then
		return
	end
	panel.Visible = false
	UI.holdCursor(CURSOR_HOLDER, false)
end

-- Opens it, once the profile's here and the game's own screen is up. Not inside the shop
-- computer's screen, where it has no room.
local function open()
	if not panel or panel.Visible or not ClientState.profile then
		return
	end
	if UI.hosted() or not UI.getScreen().Enabled then
		return
	end
	-- One window at a time: it takes the place of an open menu.
	UI.closeAll()
	render()
	fit()
	panel.Visible = true
	UI.holdCursor(CURSOR_HOLDER, true)
end

-- Opens it, or closes it if it's open. The XP bar and the L key both come here.
function LevelsController.toggle()
	if panel and panel.Visible then
		close()
	else
		open()
	end
end

function LevelsController.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

-- The window: its title and X like every menu's, then (in a column) the header line, the streak
-- line, the XP bar, the five rows and a Close button.
local function build()
	panel = UI.sliced("Panel", {
		Name = "LevelsPanel",
		Visible = false,
		-- Over the pay breakdown (5) should the two ever be up together.
		ZIndex = 6,
		Parent = UI.getScreen(),
	}, { color = UI.Colors.Background, radius = 14 })
	UI.keepPlaced(panel, "LevelsPanel")
	scale = UI.scaler(panel)
	panelWidth, panelHeight = panel.Size.X.Offset, panel.Size.Y.Offset
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	UI.heading("Levels", {
		Name = "Title",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 32),
		TextSize = 28,
		Parent = panel,
	})
	UI.button(if Art.icon("Close") ~= "" then "" else "X", close, {
		Name = "Close",
		Style = "Danger",
		Icon = "Close",
		IconSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		Parent = panel,
	})

	-- Where a menu's content starts under the Panel art's title band (UI.panel's).
	local top = if Art.slice("Panel") then 58 else 52
	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, top),
		Size = UDim2.new(1, -32, 1, -(top + 16)),
		Parent = panel,
	}, { UI.list(8) })
	header = UI.label("", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 22),
		TextScaled = true,
		TextSize = 18,
		LayoutOrder = 1,
		Parent = content,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = header })
	-- One line like the header, in the quieter colour; the longest (past the first week, with the
	-- real count) shrinks to fit it.
	streakLine = UI.label("", {
		Name = "Streak",
		Size = UDim2.new(1, 0, 0, 20),
		TextScaled = true,
		TextSize = 16,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		Visible = false,
		LayoutOrder = 2,
		Parent = content,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11, Parent = streakLine })
	xpBar = UI.bar({ Name = "XpBar", Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 3, Parent = content })
	rows = UI.new("Frame", {
		Name = "Rows",
		Size = UDim2.new(1, 0, 0, ROWS * ROW_HEIGHT + (ROWS - 1) * ROW_GAP),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = content,
	}, { UI.list(ROW_GAP) })
	UI.button("Close", close, {
		Name = "CloseButton",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 20,
		LayoutOrder = 5,
		Parent = content,
	})
end

-- The job's id and state as one string, or nil without a job: it changes when a job is accepted,
-- starts the drive, gets going, finishes or is gone.
local function stepOf(job): string?
	return if job then `{job.id}/{job.state}` else nil
end

local function onChanged(key: string)
	if key == "profile" or key == "contracts" then
		if panel.Visible then
			render()
		end
	elseif key == "job" then
		local step = stepOf(ClientState.job)
		if step ~= jobStep then
			jobStep = step
			close()
		end
	end
end

-- A menu opening (the panels' Visible changes fire this, so it's heard when another menu is
-- shown over it) or the shop computer starting to host the menus.
local function onCursorChanged()
	if panel.Visible and (UI.hosted() or UI.anyOpen()) then
		close()
	end
end

local function onKey(input: InputObject, processed: boolean)
	-- Roblox's own menu usually takes Escape (and marks it processed), so it closes either way.
	if input.KeyCode == Enum.KeyCode.Escape then
		close()
		return
	end
	-- `processed` is set while typing in chat or a text box. While a scene or the drive cutscene
	-- has the screen, the HUD is hidden and its keys do nothing.
	if processed or not UI.getScreen().Enabled then
		return
	end
	if input.KeyCode == OPEN_KEY then
		LevelsController.toggle()
	end
end

function LevelsController:Start()
	build()
	jobStep = stepOf(ClientState.job)
	ClientState.Changed:Connect(onChanged)
	UI.CursorChanged:Connect(onCursorChanged)
	-- A scene, the drive and the contest results switch the game's screen off (UI.hideGame).
	UI.getScreen():GetPropertyChangedSignal("Enabled"):Connect(function()
		if not UI.getScreen().Enabled then
			close()
		end
	end)
	-- Escape opens Roblox's own menu; the panel gives way to it.
	GuiService.MenuOpened:Connect(close)
	UserInputService.InputBegan:Connect(onKey)
end

return LevelsController
