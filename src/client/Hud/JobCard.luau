-- The job card in the right column and the boost pills under it. The card is dark glass: the job's
-- name in gold with its stars once it is paid, a big timer with par, the hint, the to-dos with their
-- bars, and the damage so far with a Call off pill (two taps: the first asks "Sure?"); smaller on a
-- short screen. The boost pills are the Crew, Curb, Truck and Business pay bonuses the server sends,
-- while they are above zero. HudController builds them (JobCard.build), hands every job update to
-- JobCard.update and ticks the timer and the pills; it asks JobCard.isShown before it shows what
-- depends on the card (curb appeal on a phone, the "Show what I missed" button).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local Bits = require(script.Parent.Bits)
local Columns = require(script.Parent.Columns)

local player = Players.LocalPlayer

local JobCard = {}

-- The Call off pill asks "Sure?" for this many seconds after the first tap, and the second tap calls
-- the job off.
local CALL_OFF_SURE = 3
-- A finished mowing row gets a stamp over it (the art's "Job Complete!", the only stamp that says
-- done), this tall, with this many sparkles round it.
local DONE_STAMP_HEIGHT = 40
local DONE_SPARKLES = 5
local WHITE = Color3.new(1, 1, 1)
-- On a short screen the job tracker's timer goes beside the job's name, in a box this wide.
local COMPACT_TIMER = 112
-- The job card and the boost pills are dark glass: how round it is, its outline and the lip under it,
-- and how the track of a bar on it looks.
local CARD_RADIUS = 20
local CARD_STROKE = 4
local CARD_LIP = 6
local TRACK_DARK = Color3.fromHex("0F1A12")
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
-- The Call off pill's words when it is not asking "Sure?", and whether it is asking now (the first tap
-- asks, a second within CALL_OFF_SURE seconds calls the job off).
local callOffWords = "Call off job"
local callOffSure = false
local callOffAskedAt = 0

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
-- The lawn map under the pills (LawnMap) is the same glass.
JobCard.glassPanel = glassPanel

local function callOffJob()
	Net.event("AbandonJob"):FireServer()
end

-- The call-off button's words on both of the tracker's layouts: what the job's state says, or "Sure?"
-- while it is asking.
local function showCallOffWords()
	local words = if callOffSure then "Sure?" else callOffWords
	callOffLabel.Text = words
	compactCallOffLabel.Text = words
end

-- Calling a job off sends the whole crew home when you lead, so it takes two taps: the first turns the
-- pill into "Sure?" for CALL_OFF_SURE seconds (the Shop's sell confirm does the same), the second sends it.
local function pressCallOff()
	if callOffSure then
		callOffSure = false
		showCallOffWords()
		callOffJob()
		return
	end
	callOffSure = true
	callOffAskedAt = os.clock()
	showCallOffWords()
	task.delay(CALL_OFF_SURE, function()
		if callOffSure and os.clock() - callOffAskedAt >= CALL_OFF_SURE then
			callOffSure = false
			showCallOffWords()
		end
	end)
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
	local compact = Columns.shortScreen()
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
	local button, face = Juicy.button("Danger", pressCallOff, {
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
	Columns.placeInColumn(tracker, "JobTracker")
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
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = damageRow,
	})
	trackerButton, callOffLabel = callOffPill(CALL_OFF, 15, damageRow)
	Columns.addHitStrips(trackerButton, pressCallOff, "RightColumn")

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
	Columns.addHitStrips(compactButton, pressCallOff, "RightColumn")

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
	Columns.placeInColumn(boostRow, "BoostPills")
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

-- The job card, then the boost pills under it.
function JobCard.build()
	buildTracker()
	buildBoosts()
end

-- Whether the job card is on screen.
function JobCard.isShown(): boolean
	return tracker.Visible
end

-- The call-off button's words, on both of the tracker's layouts.
local function setCallOffText(text: string)
	callOffWords = text
	showCallOffWords()
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
JobCard.updateTimer = updateTimer

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
	local bar = Bits.framedBar(
		{ Position = UDim2.fromOffset(x, 22), Size = UDim2.new(1, -x, 0, Bits.BAR_HEIGHT), Parent = frame },
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

-- The pay bonuses on the job you're on, as the pills under its card: Crew, Curb, Truck and Business, the
-- factors the server sends with every job update (JobService's payBonuses, the same ones the pay is
-- worked out from, so a crew member sees the leader's truck and business too). Shown only while the card
-- is, and a pill only while its bonus is above zero.
local function updateBoosts()
	local job = ClientState.job
	local words: { [string]: string? } = {}
	if job and tracker.Visible then
		words.Crew = boostWords("Crew", (job.crewBonus or 1) - 1)
		words.Curb = boostWords("Curb", (job.curbBonus or 1) - 1)
		words.Truck = boostWords("Truck", (job.truckBonus or 1) - 1)
		words.Business = boostWords("Business", (job.businessBonus or 1) - 1)
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
JobCard.updateBoosts = updateBoosts

-- The card and the pills for a job update (`job` is ClientState.job, nil once there is none). Returns
-- whether this is a different job from the last one shown, so HudController can put the last job's pay
-- panel away.
function JobCard.update(job): boolean
	if not job then
		tracker.Visible = false
		-- A "Sure?" that was waiting goes with the job.
		callOffSure = false
		showCallOffWords()
		clearTaskRows()
		updateStars(nil)
		updateBoosts()
		return false
	end

	local isNew = job.id ~= shownJobId
	if isNew then
		shownJobId = job.id
		callOffSure = false
		clearTaskRows()
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
	end
	-- A "Sure?" does not outlast the button (a job that is starting, done or no longer yours to call off).
	if not callOffShown then
		callOffSure = false
	end
	showCallOffWords()
	updateStars(job)
	updateTimer()
	updateBoosts()

	if not job.tasks then
		clearTaskRows()
		return isNew
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
	return isNew
end

return JobCard
