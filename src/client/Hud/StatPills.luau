-- The pills at the top of the left column: the money pill (a gold coin and the money counter, which
-- counts up when money comes in), and under it the level pill (a star, "LVL 3" and the XP bar, one
-- button that opens the Levels panel, with the star gold once you have the gold business sign) beside
-- the streak pill ("DAY 3", once there is a streak), then the judging day countdown pill (once judging
-- day is on the calendar). HudController builds them (StatPills.build) and tells them when the profile,
-- the gold sign, the day's view or the contest view changes; cash and XP pops lift off moneyFrame and
-- levelLine.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daily = require(Shared.Daily)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)

local ClientState = require(script.Parent.Parent.ClientState)
local FloatingText = require(script.Parent.Parent.FloatingText)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local LevelsController = require(script.Parent.Parent.Controllers.LevelsController)
local Bits = require(script.Parent.Bits)
local Columns = require(script.Parent.Columns)

local player = Players.LocalPlayer

local StatPills = {}

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
local LEVELS_BUTTON_REACH = 13
-- The streak pill's flame: how far in its middle is, and how wide its body is.
local FLAME_MIDDLE = 19
local FLAME_WIDTH = 16
local WHITE = Color3.new(1, 1, 1)
local COIN_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FFF3A8")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFD24A")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("E8A61E")),
})
local FLAME_OUTER = Color3.fromHex("FF5A1F")
local FLAME_INNER = Color3.fromHex("FFE066")

-- The money counter, the pill it is on, the money the last profile had (nil before the first), so a gain
-- counts up, and the number the counter shows right now (its count writes it), so a gain that arrives
-- mid-count carries on from what is on screen.
local money
local moneyPill: Frame
local lastMoney: number? = nil
local shownMoney: number? = nil
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

-- The money pill: a gold coin and the money, big and white with an ink outline, on a green pill. The
-- column's piece is a plain frame the size of the pill and its lip (UiLayout's MoneyPanel) and the
-- pill sits in it, so the pill can pulse about its middle without moving the column.
local function buildStats()
	local frame = UI.new("Frame", { Name = "Stats", BackgroundTransparency = 1 })
	Columns.placeInColumn(frame, "MoneyPanel")
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
	Columns.placeInColumn(row, "StatPills")

	-- The level pill: a star, "LVL 3" and the XP bar. The Levels button is invisible over it, and
	-- reaches a little above and below it so it is a thumb's size on a phone.
	-- The pill sits in a slot the row lays out, so a pop of the pill (pressing it) never lays the row out
	-- again.
	local levelSlot = UI.new("Frame", {
		Name = "LevelSlot",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(LEVEL_PILL.X, LEVEL_PILL.Y),
		LayoutOrder = 1,
		Parent = row,
	})
	local levelHolder, levelFace = Juicy.pill("Level", {
		Name = "LevelPill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LEVEL_PILL.X, LEVEL_PILL.Y),
		Parent = levelSlot,
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
		Parent = levelSlot,
	})
	levelsButton.Activated:Connect(LevelsController.toggle)
	-- The pill grows under the pointer, squashes when pressed and clicks, like the squares (the button
	-- is laid over the pill, so the pill is what moves).
	Juicy.juice(levelsButton, levelHolder)

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
	Columns.placeInColumn(countdownPanel, "Countdown")
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

-- The money pill, then the level, streak and countdown pills under it.
function StatPills.build()
	buildStats()
	buildPills()
end

-- What cash pops lift off: the money counter.
function StatPills.moneyFrame(): GuiObject
	return money.Frame
end

-- What a level's cash lifts off: the level pill's words.
function StatPills.levelLine(): TextLabel
	return levelLabel
end

-- Shows the star beside the level in gold while the player has the gold business sign (the server
-- sets GoldSign at level 20).
function StatPills.updateGoldSign()
	colorLevelGlyph(if player:GetAttribute("GoldSign") == true then UI.Colors.Gold else WHITE)
end

-- The streak pill: "DAY 3" from the day's view (ClientState.contracts), hidden with no streak.
function StatPills.updateStreak()
	local view = ClientState.contracts
	local days = if view and view.streak then view.streak.days or 0 else 0
	streakPill.Visible = days > 0
	if days > 0 then
		streakLabel.Text = `DAY {days}`
	end
end

-- The judging day countdown, from the contest view (ClientState.contest) and this computer's clock:
-- only for someone with judging day on the Saturday calendar, "Judging day in 2d 5h" while it is
-- coming and "Judging day is today!" while it is open. The words are Daily.judgingText's, which also
-- copes with a view that is older than today (the server sends it rarely, so one held across Saturday's
-- midnight is out of date).
function StatPills.updateCountdown()
	local contest = ClientState.contest
	local text: string? = nil
	if contest and contest.calendar then
		text = Daily.judgingText(contest.state, contest.daysLeft, os.time())
	end
	countdownPanel.Visible = text ~= nil
	if text then
		countdownLabel.Text = text
	end
end

-- The money counter's words for a number, noting that it is the one on screen now.
local function moneyText(value: number): string
	shownMoney = value
	return Format.money(value)
end

-- The money, the level and the XP bar from a profile.
function StatPills.updateProfile(profile)
	-- Money that came in counts up from the number on screen and the pill pulses; anything else (the
	-- first profile, a spend) is set.
	if profile.money ~= lastMoney then
		if lastMoney and profile.money > lastMoney then
			Juicy.countTo(money, shownMoney or lastMoney, profile.money, MONEY_COUNT_TIME, moneyText)
			Juicy.pulse(moneyPill)
		else
			Juicy.countTo(money, profile.money, profile.money, 0, moneyText)
		end
		lastMoney = profile.money
	end
	levelLabel.Text = `LVL {profile.level}`
	local from = GameConfig.xpForLevel(profile.level)
	local to = GameConfig.xpForLevel(profile.level + 1)
	xpBar.set((profile.xp - from) / (to - from))
	-- XP that came in lifts off the bar (not on the first profile, which is only what you had).
	if lastXp and profile.xp > lastXp then
		FloatingText.show(xpBar.frame, `+{profile.xp - lastXp} XP`, UI.Colors.Accent, Bits.SMALL_POP)
	end
	lastXp = profile.xp
end

return StatPills
