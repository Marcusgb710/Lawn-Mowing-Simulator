-- The Top Lawns window: the same two leaderboards as the sign at the town spawn, in a menu you can
-- open from anywhere (the HUD's Top Lawns button, or F on a keyboard). Two tabs, Lawns mowed and
-- Money earned, each a list of up to 25 players (their rank, in gold for the first three, their name
-- and their number), and under the list your own line, the sign's words ("You: #12 with 40 lawns").
-- When the server says the leaderboards are off (Studio without API access, or an outage) the window
-- says so, in the server's words, instead of the lists.
--
-- It draws what LeaderboardController keeps in ClientState.leaderboard, the last LeaderboardUpdated
-- payload, and draws it again when a new one comes while the window is open. How a number reads in a
-- row and in your line are LeaderboardController's, so the window and the sign always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local ClientState = require(script.Parent.Parent.ClientState)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local LeaderboardController = require(script.Parent.LeaderboardController)

local TopLawnsController = {}

-- The two tabs: which list of the payload each shows, its name, and its glyph.
local BOARDS = {
	{ list = "lawns", name = "Lawns mowed", icon = "Jobs" },
	{ list = "money", name = "Money earned", icon = "Money" },
}
-- The tabs' height and the gap under them, and how tall the viewer's own line at the foot is (a rule
-- over the words, which may take two lines).
local TABS_HEIGHT = 44
local TABS_GAP = 8
local YOU_HEIGHT = 44
local DIVIDER_HEIGHT = 2
local DIVIDER_GAP = 6
-- A player's row: its height, the room for the rank at its left, and how many show.
local ROW_HEIGHT = 36
local RANK_WIDTH = 52
local ROWS_SHOWN = GameConfig.LeaderboardTop
-- The first three ranks are in gold.
local PODIUM = 3

local window: GuiObject
local tabButtons: { [string]: TextButton } = {}
local list: ScrollingFrame
local youLine: TextLabel
local divider: Frame
local selected = BOARDS[1].list

-- One line of words in the list, for what it has no rows to show.
local function note(text: string, order: number)
	UI.label(text, {
		Name = "Note",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 18,
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = order,
		Parent = list,
	})
end

-- A player's row: "1" in gold (the first three) or cream, their name cut short with "..." if it
-- won't fit, and their number at the right.
local function addRow(index: number, row: LeaderboardController.Row)
	local card = UI.card({
		Name = `Row{index}`,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		LayoutOrder = index,
		Parent = list,
	})
	UI.label(tostring(index), {
		Name = "Rank",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, RANK_WIDTH, 1, 0),
		FontFace = UI.Fonts.Heavy,
		TextSize = 18,
		TextColor3 = if index <= PODIUM then UI.Colors.Gold else UI.Colors.Text,
		Parent = card,
	})
	local value = LeaderboardController.rowText(selected, row.value)
	local valueWidth = math.ceil(UI.textWidth(value, 18)) + 8
	UI.label(row.name, {
		Name = "Name",
		Position = UDim2.fromOffset(12 + RANK_WIDTH, 0),
		Size = UDim2.new(1, -(24 + RANK_WIDTH + valueWidth), 1, 0),
		TextSize = 18,
		TextColor3 = if index <= PODIUM then UI.Colors.Gold else UI.Colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	UI.label(value, {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, valueWidth, 1, 0),
		FontFace = UI.Fonts.Heavy,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
end

-- Draws the window from the last payload: the tabs, the list (or the notice, or a waiting line) and
-- your own line.
local function render()
	for _, board in BOARDS do
		UI.setTab(tabButtons[board.list], board.list == selected)
	end
	UI.clearList(list)
	local view: LeaderboardController.View? = ClientState.leaderboard
	local line: string? = nil
	if not view then
		note("Loading...", 1)
	elseif not view.available then
		note(LeaderboardController.offText(view), 1)
	else
		local rows = view[selected] or {}
		if #rows == 0 then
			note("Nobody yet. Finish a job to be first.", 1)
		end
		for index = 1, math.min(#rows, ROWS_SHOWN) do
			addRow(index, rows[index])
		end
		line = LeaderboardController.youLine(selected, view)
	end
	youLine.Text = line or ""
	youLine.Visible = line ~= nil
	divider.Visible = line ~= nil
end

function TopLawnsController:Start()
	local content
	window, content = UI.panel("TopLawns", "Top Lawns")
	-- The tabs feel like the HUD's buttons (Juicy.juice); the window's X does through UI.panel.

	local tabs = UI.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, TABS_HEIGHT),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	for index, board in BOARDS do
		local tab = UI.tab(board.name, board.icon, function()
			selected = board.list
			render()
		end, { LayoutOrder = index, Parent = tabs })
		Juicy.juice(tab)
		tabButtons[board.list] = tab
	end

	local footer = YOU_HEIGHT + DIVIDER_HEIGHT + DIVIDER_GAP
	local top = TABS_HEIGHT + TABS_GAP
	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -(top + footer)),
	})
	divider = UI.new("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -YOU_HEIGHT - DIVIDER_GAP),
		Size = UDim2.new(1, -8, 0, DIVIDER_HEIGHT),
		BackgroundColor3 = UI.Colors.Accent,
		BorderSizePixel = 0,
		Parent = content,
	})
	youLine = UI.label("", {
		Name = "You",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -8, 0, YOU_HEIGHT),
		TextSize = 18,
		TextColor3 = UI.Colors.Money,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = content,
	})

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	ClientState.Changed:Connect(function(key)
		if key == "leaderboard" and window.Visible then
			render()
		end
	end)
	render()
end

return TopLawnsController
