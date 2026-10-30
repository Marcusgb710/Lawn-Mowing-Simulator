-- Draws the two leaderboards on the sign at the town spawn (LeaderboardService sends what they show).
-- The sign is a prop the server stands there, Props/LeaderboardSign: a board for each list,
-- `LawnsBoard` and `MoneyBoard`, left blank in the world. This puts one SurfaceGui on each board's
-- front, the face the server's own signs are drawn on: the title ("MOST LAWNS MOWED", "MOST
-- EARNED"), the top players as rows ("12. Name" with their number on the right), then a divider and
-- the viewer's own line ("You: #12 with 40 lawns", or "You: not in the top 100 yet, 3 lawns").
-- When the server says the leaderboards are off (Studio without API access, or an outage) both
-- boards say so and show nothing else.
--
-- Text is 18 px and never scaled, at 40 pixels a stud like the server's signs. A board shows the
-- rows its own size has room for, up to the 25 the server sends, so the sign can be remodelled
-- without text running off it. Every update draws both boards again from the start.
--
-- The sign streams in with the town, and its boards may arrive after it, so this waits for them
-- (the server keeps the sign streamed in for everyone). What the last update said is kept, so a
-- board that appears late is drawn at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = require(script.Parent.Parent.UI)

-- What LeaderboardService sends: the boards (the first LeaderboardTop players of each) and the
-- viewer's own line.
export type Row = { name: string, value: number }
export type View = {
	available: boolean,
	-- What to say instead of boards when `available` is false (the server picks it).
	notice: string?,
	lawns: { Row }?,
	money: { Row }?,
	you: { lawnsRank: number?, moneyRank: number?, lawns: number, money: number }?,
}

local LeaderboardController = {}

-- 1234 -> "1,234". Format.money does the commas, so its dollar sign comes off.
local function commas(amount: number): string
	return string.sub(Format.money(amount), 2)
end

-- The name of the SurfaceGui drawn on each board, so a redraw finds the last one.
local GUI_NAME = "Leaderboard"
local PIXELS_PER_STUD = 40
local TEXT_SIZE = 18
local TITLE_SIZE = 26
-- Said when the server sends no words of its own with `available = false`.
local OFF_TEXT = "Leaderboards are off in this place"
local OFF_SIZE = 24
-- Where things go on a board, in pixels: the margin all round, the title's height, the gap
-- between the parts, a row's height, the divider's, and the viewer's own line (two lines of text,
-- for the long "not in the top 100 yet" one).
local PADDING = 10
local TITLE_HEIGHT = 36
local GAP = 6
local ROW_HEIGHT = 20
local DIVIDER_HEIGHT = 2
local YOU_HEIGHT = 44
-- The first three rows' names are in gold.
local PODIUM = 3

-- The two boards: the part of the sign each is drawn on, its title, which list of the update it
-- shows, the rank and number that are the viewer's own, and how a number reads in a row and in
-- the viewer's line.
local BOARDS = {
	{
		part = "LawnsBoard",
		title = "MOST LAWNS MOWED",
		list = "lawns",
		rank = "lawnsRank",
		number = "lawns",
		inRow = commas,
		inLine = function(value: number): string
			return `{commas(value)} {if value == 1 then "lawn" else "lawns"}`
		end,
	},
	{
		part = "MoneyBoard",
		title = "MOST EARNED",
		list = "money",
		rank = "moneyRank",
		number = "money",
		inRow = Format.money,
		inLine = Format.money,
	},
}

-- The last update, drawn on any board that is there, and drawn again when one turns up.
local latest: View? = nil

local function findBoard(name: string): BasePart?
	local town = workspace:FindFirstChild("Town")
	local sign = town and town:FindFirstChild("LeaderboardSign")
	local found = sign and sign:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- A divider under the rows, over the viewer's own line, at the foot of the board.
local function addFooter(face: Frame, board, view: View)
	local you = view.you
	local footer = UI.new("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, PADDING, 1, -PADDING),
		Size = UDim2.new(1, -2 * PADDING, 0, DIVIDER_HEIGHT + GAP + YOU_HEIGHT),
		BackgroundTransparency = 1,
		Parent = face,
	})
	UI.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
		BackgroundColor3 = UI.Colors.Accent,
		BorderSizePixel = 0,
		Parent = footer,
	})
	if not you then
		return
	end
	local rank = you[board.rank]
	local number = board.inLine(you[board.number])
	local line = if rank
		then `You: #{rank} with {number}`
		else `You: not in the top {GameConfig.LeaderboardTop * GameConfig.LeaderboardRankPages} yet, {number}`
	UI.label(line, {
		Name = "You",
		Position = UDim2.fromOffset(0, DIVIDER_HEIGHT + GAP),
		Size = UDim2.new(1, 0, 0, YOU_HEIGHT),
		TextSize = TEXT_SIZE,
		TextColor3 = UI.Colors.Money,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = footer,
	})
end

-- The players' rows, `shown` of them from the top of `list`: "12. Name" on the left (cut short
-- with "..." if it won't fit) and the number right-aligned, wide enough for the longest.
local function addRows(face: Frame, board, list: { Row }, shown: number)
	local rows = UI.new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + GAP),
		Size = UDim2.new(1, -2 * PADDING, 0, shown * ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = face,
	})
	UI.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = rows })
	local texts = {}
	local widest = 0
	for index = 1, shown do
		texts[index] = board.inRow(list[index].value)
		widest = math.max(widest, UI.textWidth(texts[index], TEXT_SIZE))
	end
	local valueWidth = math.ceil(widest) + GAP
	for index = 1, shown do
		local row = UI.new("Frame", {
			Name = `Row{index}`,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			Parent = rows,
		})
		UI.label(`{index}. {list[index].name}`, {
			Name = "Name",
			Size = UDim2.new(1, -valueWidth, 1, 0),
			TextSize = TEXT_SIZE,
			TextColor3 = if index <= PODIUM then UI.Colors.Gold else UI.Colors.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		UI.label(texts[index], {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, valueWidth, 1, 0),
			TextSize = TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
end

-- Draws one board on its part: the leaderboards-are-off notice, or the title, rows and the
-- viewer's line. `view` is nil before the first update, which draws the title and a waiting line.
local function build(part: BasePart, board, view: View?)
	local old = part:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end
	local canvas = Vector2.new(part.Size.X, part.Size.Y) * PIXELS_PER_STUD
	local gui = UI.new("SurfaceGui", {
		Name = GUI_NAME,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		-- Lit as it is, like the sign's header (WorldService), however dark it is out.
		LightInfluence = 0,
	})
	local face = UI.new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	if view and not view.available then
		UI.label(view.notice or OFF_TEXT, {
			Name = "Off",
			Position = UDim2.fromOffset(PADDING, 0),
			Size = UDim2.new(1, -2 * PADDING, 1, 0),
			FontFace = UI.Fonts.Heavy,
			TextSize = OFF_SIZE,
			TextColor3 = UI.Colors.SubText,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = face,
		})
		gui.Parent = part
		return
	end

	UI.heading(board.title, {
		Name = "Title",
		Position = UDim2.fromOffset(PADDING, PADDING),
		Size = UDim2.new(1, -2 * PADDING, 0, TITLE_HEIGHT),
		TextSize = TITLE_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = face,
	})
	if not view then
		UI.label("Loading...", {
			Name = "Waiting",
			Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + GAP),
			Size = UDim2.new(1, -2 * PADDING, 0, ROW_HEIGHT),
			TextSize = TEXT_SIZE,
			TextColor3 = UI.Colors.SubText,
			Parent = face,
		})
		gui.Parent = part
		return
	end

	local list = view[board.list] or {}
	-- What fits between the title and the viewer's line.
	local room = canvas.Y - 2 * PADDING - TITLE_HEIGHT - 2 * GAP - (DIVIDER_HEIGHT + GAP + YOU_HEIGHT)
	local shown = math.clamp(math.floor(room / ROW_HEIGHT), 0, math.min(#list, GameConfig.LeaderboardTop))
	if #list > 0 then
		addRows(face, board, list, shown)
	else
		UI.label("Nobody yet. Finish a job to be first.", {
			Name = "Empty",
			Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + GAP),
			Size = UDim2.new(1, -2 * PADDING, 0, 2 * ROW_HEIGHT),
			TextSize = TEXT_SIZE,
			TextColor3 = UI.Colors.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = face,
		})
	end
	addFooter(face, board, view)
	gui.Parent = part
end

-- Draws every board that is in the world now.
local function draw()
	for _, board in BOARDS do
		local part = findBoard(board.part)
		if part then
			build(part, board, latest)
		end
	end
end

-- Waits for the sign to reach this screen, then draws what the last update said on it, and again
-- whenever one of its boards turns up after that.
local function watchSign()
	local town = workspace:WaitForChild("Town", 30)
	local sign = town and town:WaitForChild("LeaderboardSign", 30)
	if not sign then
		return
	end
	sign.DescendantAdded:Connect(function(added)
		for _, board in BOARDS do
			if added.Name == board.part then
				task.defer(draw)
				return
			end
		end
	end)
	draw()
end

function LeaderboardController:Start()
	Net.event("LeaderboardUpdated").OnClientEvent:Connect(function(view: View)
		latest = view
		draw()
	end)
	task.spawn(watchSign)
end

return LeaderboardController
