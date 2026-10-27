-- The Maple Grove Best Yard contest on this screen (docs/STORY.md, act 4). The server decides
-- everything (ContestService); this only shows it:
--   * judging day's scene: a "Yard" camera shot of your own front lawn (DialogueController.addShot)
--     and the two judges walking your yard, then Gloria's, as the scene's lines say (`judges`);
--   * the results screen, once the scene's over: the title, your yard's card, the trophy and
--     Gloria's card, the four categories with your bar and hers, what you won, Gloria's last word
--     and a Collect button. Collecting asks the server, which pays out and plays the ending.
-- Colors and fonts are UI's (the scores in the display face); the art is StoryArt.Contest (plain
-- frames until it's uploaded).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Contest = require(Shared.Config.Contest)
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local ClientState = require(script.Parent.Parent.ClientState)
local StoryArt = require(script.Parent.Parent.StoryArt)
local UI = require(script.Parent.Parent.UI)
local DialogueController = require(script.Parent.DialogueController)

local player = Players.LocalPlayer

-- The results screen is laid out at its size in UiLayout.luau and scaled to fit, keeping a margin
-- clear and never past `maxScale` (UiLayout's __screen.scaling.ContestResults).
local RESULTS_SIZE = UI.layout("ContestResults").size :: UDim2
local LAYOUT = Vector2.new(RESULTS_SIZE.X.Offset, RESULTS_SIZE.Y.Offset)
local FIT = UI.Layout.__screen.scaling.ContestResults
-- How fast the judges walk (studs a second), how far behind the first the second one follows,
-- and how much they bob.
local WALK_SPEED = 3.2
local FOLLOW = 3
local BOB = 0.12
-- Where the judges walk in Gloria's yard, in her lot's space (the street toward -Z), in view of
-- the "Gloria" shot.
local GLORIA_WALK = {
	Vector3.new(-16, 0, -24),
	Vector3.new(-4, 0, -18),
	Vector3.new(6, 0, -24),
	Vector3.new(14, 0, -16),
}
-- How often (seconds) to see whether the results can show.
local CHECK_EVERY = 0.25
-- How many bits of confetti fall over a win.
local CONFETTI = 36
-- The category table's columns: where your bars and hers start, and how long they are.
local COLUMN_YOU, COLUMN_GLORIA, BAR_WIDTH = 244, 614, 280

local ContestController = {}

local screen: ScreenGui
local panel: Frame
local scale: UIScale
-- The result showing, and whether Collect is waiting on the server.
local showing = nil
local collecting = false
-- The judges walking now: their models and the connection moving them.
local judges: { Model } = {}
local walking: RBXScriptConnection? = nil

-- Your own front lawn (HomeLawnService builds it on your plot), its middle, size and ground height.
local function homeLawn(): (Vector3?, Vector3?, number?)
	local lawns = workspace:FindFirstChild("HomeLawns")
	local lawn = lawns and lawns:FindFirstChild("HomeLawn_" .. player.UserId)
	if not (lawn and lawn:IsA("Model")) then
		return nil, nil, nil
	end
	local box, size = lawn:GetBoundingBox()
	local turf = lawn:FindFirstChild("Turf")
	local ground = if turf and turf:IsA("BasePart")
		then turf.Position.Y + turf.Size.Y / 2
		else box.Position.Y - size.Y / 2
	return box.Position, size, ground
end

-- The "Yard" shot: from the street, looking over your lawn (plots face the street to -Z).
local function yardShot(): CFrame?
	local center, size = homeLawn()
	if not (center and size) then
		return nil
	end
	local from = center + Vector3.new(size.X * 0.35, 10, -(size.Z / 2 + 16))
	return CFrame.lookAt(from, center + Vector3.new(0, 1, 0))
end

-- The judges ----------------------------------------------------------------------------------

local function stopJudges()
	if walking then
		walking:Disconnect()
		walking = nil
	end
	for _, model in judges do
		model:Destroy()
	end
	table.clear(judges)
end

-- Where along `path` (points on the ground) `distance` studs is, and which way it's heading.
local function along(path: { Vector3 }, distance: number): (Vector3, Vector3)
	local left = math.max(0, distance)
	for index = 1, #path - 1 do
		local from, to = path[index], path[index + 1]
		local length = (to - from).Magnitude
		if left <= length and length > 0 then
			return from:Lerp(to, left / length), (to - from).Unit
		end
		left -= length
	end
	local last, before = path[#path], path[#path - 1] or path[#path]
	local heading = last - before
	return last, if heading.Magnitude > 0 then heading.Unit else Vector3.new(0, 0, -1)
end

-- Walks the two judges along `path`, the second a little behind the first.
local function walkJudges(path: { Vector3 })
	stopJudges()
	if #path < 2 then
		return
	end
	for _, id in { "NPC_Judge1", "NPC_Judge2" } do
		local model = Assets.story(id)
		Assets.anchor(model)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		model.Parent = workspace
		table.insert(judges, model)
	end
	local total = 0
	for index = 1, #path - 1 do
		total += (path[index + 1] - path[index]).Magnitude
	end
	local started = os.clock()
	walking = RunService.RenderStepped:Connect(function()
		local walked = (os.clock() - started) * WALK_SPEED
		for index, model in judges do
			local distance = walked - (index - 1) * FOLLOW
			local position, heading = along(path, distance)
			local flat = Vector3.new(heading.X, 0, heading.Z)
			local moving = distance > 0 and distance < total
			local bob = if moving then math.abs(math.sin(os.clock() * 7 + index)) * BOB else 0
			local facing = if flat.Magnitude > 0 then flat.Unit else Vector3.new(0, 0, -1)
			Assets.placeAt(model, CFrame.lookAt(position + Vector3.new(0, bob, 0), position + facing))
		end
	end)
end

-- The path across your yard: along the front, then up toward the house.
local function yardPath(): { Vector3 }
	local center, size, ground = homeLawn()
	if not (center and size and ground) then
		return {}
	end
	local base = Vector3.new(center.X, ground, center.Z)
	return {
		base + Vector3.new(-size.X / 2 + 1.5, 0, -size.Z / 2 + 2),
		base + Vector3.new(size.X / 2 - 1.5, 0, -size.Z / 2 + 2),
		base + Vector3.new(size.X / 2 - 4, 0, 0),
		base + Vector3.new(0, 0, size.Z * 0.15),
	}
end

local function gloriaPath(): { Vector3 }
	local house = workspace:FindFirstChild("GloriasHouse")
	local anchor = house and house:FindFirstChild("Anchor")
	if not (anchor and anchor:IsA("BasePart")) then
		return {}
	end
	local path = {}
	for _, point in GLORIA_WALK do
		table.insert(path, anchor.CFrame:PointToWorldSpace(point))
	end
	return path
end

-- The results screen ------------------------------------------------------------------------

local function ordinal(number: number): string
	local last, lastTwo = number % 10, number % 100
	local suffix = if lastTwo >= 11 and lastTwo <= 13
		then "th"
		elseif last == 1 then "st"
		elseif last == 2 then "nd"
		elseif last == 3 then "rd"
		else "th"
	return `{number}{suffix}`
end

-- A bar out of the category's points: the art's score track, striped in your green or Gloria's
-- purple (`fill`: "You" or "Rival"), or plain ones. It fills up as the screen opens.
local function scoreBar(parent: Instance, value: number, fill: string, props): GuiObject
	local options = table.clone(props)
	options.Parent = parent
	local bar = UI.bar(options, fill, StoryArt.Contest.ScoreTrack)
	local share = math.clamp(value / Contest.CategoryPoints, 0, 1)
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(current)
		bar.set(current)
	end)
	local tween = TweenService:Create(
		progress,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = share }
	)
	tween.Completed:Once(function()
		progress:Destroy()
	end)
	tween:Play()
	return bar.frame
end

-- A yard's card: who it is, a line under, and the big score. The winner's stands out (the art's
-- selected card, or a colored outline), and the yard TurfKing did (`crown`) wears its gold crown.
local function yardCard(parent: Instance, x: number, info)
	local card = UI.sliced(if info.winner then "Card_Selected" else "Card", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(330, 190),
		Parent = parent,
	}, {
		color = UI.Colors.Panel,
		radius = 20,
		stroke = if info.winner then info.color else UI.Colors.Card,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 18),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 22),
		PaddingRight = UDim.new(0, 22),
		Parent = card,
	})
	UI.heading(info.tag, { Size = UDim2.new(1, 0, 0, 18), TextSize = 16, TextColor3 = info.color, Parent = card })
	if info.crown then
		UI.icon("Crown", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -6),
			Size = UDim2.fromOffset(30, 30),
			Rotation = 12,
			Parent = card,
		}, UI.Colors.Gold)
	end
	UI.heading(
		info.name,
		{ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Parent = card }
	)
	UI.label(info.line, {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		Parent = card,
	})
	UI.display("Numbers", `{info.score}/{Contest.CategoryPoints * #Contest.Categories}`, {
		TextSize = 76,
		Color = info.color,
		Fit = true,
	}, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 66),
		Parent = card,
	})
end

-- The trophy in the middle: its art, or a plain gold cup on a green base. Returns its frame.
local function trophy(parent: Instance, won: boolean): Frame
	local holder = UI.new("Frame", {
		Position = UDim2.fromOffset(355, 0),
		Size = UDim2.fromOffset(310, 190),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	if StoryArt.Contest.Trophy ~= "" then
		UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(150, 150),
			Image = StoryArt.Contest.Trophy,
			BackgroundTransparency = 1,
			Parent = holder,
		})
	else
		local gold = UI.Colors.Money
		local cup = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(64, 72),
			BackgroundColor3 = gold,
			Parent = holder,
		}, { UI.corner(22), UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 4 }) })
		for _, side in { -1, 1 } do
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, side * 40, 0, 44),
				Size = UDim2.fromOffset(26, 34),
				BackgroundTransparency = 1,
				Parent = holder,
			}, { UI.corner(13), UI.new("UIStroke", { Color = gold, Thickness = 6 }) })
		end
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 84),
			Size = UDim2.fromOffset(16, 22),
			BackgroundColor3 = gold:Lerp(Color3.new(0, 0, 0), 0.15),
			BorderSizePixel = 0,
			Parent = holder,
		})
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 104),
			Size = UDim2.fromOffset(56, 18),
			BackgroundColor3 = Color3.fromRGB(94, 140, 74),
			Parent = holder,
		}, { UI.corner(4), UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 4 }) })
		cup.ZIndex = 2
	end
	local wordmark = if won then StoryArt.Contest.Winner else StoryArt.Contest.SoClose
	if wordmark ~= "" then
		UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(260, 44),
			Image = wordmark,
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
			Parent = holder,
		})
	else
		UI.label(if won then `June's {ordinal(showing.juneWins + 1)} win` else "So close", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})
	end
	return holder
end

-- One row of the category table: its icon and name, your bar and score, then hers.
local function categoryRow(parent: Instance, index: number, category, yours: number, hers: number)
	local row = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = index + 1,
		Parent = parent,
	})
	local icon = StoryArt.Contest.Categories[category.id] or ""
	local nameX = 0
	if icon ~= "" then
		UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(26, 26),
			Image = icon,
			ImageColor3 = UI.Colors.SubText,
			BackgroundTransparency = 1,
			Parent = row,
		})
		nameX = 34
	end
	UI.label(category.name, {
		Position = UDim2.fromOffset(nameX, 0),
		Size = UDim2.new(0, 230 - nameX, 1, 0),
		TextSize = 20,
		Parent = row,
	})
	local sides = {
		{ yours, StoryArt.Contest.ScoreFillYou, UI.Colors.Accent },
		{ hers, StoryArt.Contest.ScoreFillRival, UI.Colors.Rival },
	}
	for side, info in sides do
		local x = COLUMN_YOU + (side - 1) * (COLUMN_GLORIA - COLUMN_YOU)
		scoreBar(row, info[1], info[2], {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x, 0.5, 0),
			Size = UDim2.fromOffset(BAR_WIDTH, 14),
		})
		UI.label(tostring(info[1]), {
			Position = UDim2.fromOffset(x + BAR_WIDTH + 8, 0),
			Size = UDim2.new(0, 60, 1, 0),
			TextSize = 20,
			FontFace = UI.Fonts.Heavy,
			TextColor3 = info[3],
			Parent = row,
		})
	end
end

-- What you won, as chips (or, after a loss, when you can try again).
local function chips(parent: Instance, result)
	-- In a row, each as wide as its words, wrapping onto a second row if they need it.
	local list = UI.new("Frame", {
		Size = UDim2.fromOffset(560, 92),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local entries = {}
	local rewards = result.rewards
	if result.won and rewards then
		table.insert(entries, { text = `+ {Format.money(rewards.money or 0)}`, color = UI.Colors.Money })
		if rewards.trophy then
			table.insert(entries, { text = "Best Yard Trophy for your yard" })
		end
		local building = rewards.discount and Items.get("Business", rewards.discount)
		if building then
			table.insert(entries, { text = `{building.name}: half price` })
		end
	else
		table.insert(entries, { text = "Gloria takes the trophy", color = UI.Colors.Rival })
		local jobs = result.retryJobs or Contest.RetryJobs
		table.insert(entries, { text = `Try again in {jobs} {if jobs == 1 then "job" else "jobs"}` })
	end
	for index, entry in entries do
		local chip = UI.label(entry.text, {
			Size = UDim2.fromOffset(0, 42),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 19,
			TextColor3 = entry.color or UI.Colors.Text,
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.Colors.Panel,
			LayoutOrder = index,
			Parent = list,
		})
		UI.corner(12).Parent = chip
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = chip })
	end
	return list
end

-- Confetti over a win: the art's frames, or little colored squares, falling and turning.
local function confetti()
	local colors = { UI.Colors.Accent, UI.Colors.Money, UI.Colors.Rival, UI.Colors.Bubble, UI.Colors.Danger }
	local art = StoryArt.Contest.Confetti
	for index = 1, CONFETTI do
		local piece: GuiObject
		if art.image ~= "" then
			local cell = (index - 1) % (art.columns * art.rows)
			local size = art.frameSize
			piece = UI.new("ImageLabel", {
				Image = art.image,
				ImageRectSize = size,
				ImageRectOffset = Vector2.new(cell % art.columns * size.X, cell // art.columns * size.Y),
				Size = UDim2.fromOffset(48, 48),
				BackgroundTransparency = 1,
			})
		else
			piece = UI.new("Frame", {
				Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
				BackgroundColor3 = colors[math.random(1, #colors)],
				BorderSizePixel = 0,
			})
		end
		piece.Position = UDim2.new(math.random(), 0, 0, -30 - math.random(0, 160))
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 5
		piece.Parent = panel
		local fall = TweenService:Create(piece, TweenInfo.new(2.5 + math.random() * 2, Enum.EasingStyle.Linear), {
			Position = piece.Position + UDim2.fromOffset(math.random(-80, 80), LAYOUT.Y + 220),
			Rotation = piece.Rotation + math.random(180, 720),
		})
		fall.Completed:Once(function()
			piece:Destroy()
		end)
		fall:Play()
	end
end

-- Its UIScale: what fits the screen, times its own scale (UiLayout's ContestResults).
local function fit()
	local size = screen.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		scale.Scale = math.min(size.X / (LAYOUT.X + FIT.marginX), size.Y / (LAYOUT.Y + FIT.marginY), FIT.maxScale)
			* UI.layout("ContestResults").scale
	end
end

local function hide()
	if not showing then
		return
	end
	showing = nil
	screen.Enabled = false
	UI.clearList(panel)
	UI.holdCursor("Contest", false)
	UI.hideGame("Contest", false)
end

local function collect()
	if collecting then
		return
	end
	collecting = true
	local result = showing
	local ok, success, message = pcall(function()
		return Net.func("CollectContest"):InvokeServer()
	end)
	collecting = false
	if ok and success then
		hide()
		-- Payday! for the prize money.
		local prize = result and result.won and result.rewards and result.rewards.money
		if prize and prize > 0 then
			UI.moment("Payday", "Payday!", `+{Format.money(prize)}`)
		end
	end
	if ok and typeof(message) == "string" then
		UI.notify(message)
	end
end

local function show(result)
	showing = result
	UI.clearList(panel)
	UI.closeAll()
	UI.hideGame("Contest", true)
	UI.holdCursor("Contest", true)
	local won = result.won == true

	-- The title: its wordmark on the ribbon, or the words in yellow.
	UI.heading(if (result.summer or 1) > 1 then `END OF SUMMER {result.summer}` else "END OF SUMMER", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 17,
		TextColor3 = UI.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})
	local art = StoryArt.Contest
	if art.Ribbon then
		local ribbon = UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(660, 70),
			Parent = panel,
		})
		UI.applySlice(ribbon, art.Ribbon)
	end
	if art.Title ~= "" then
		UI.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 20),
			Size = UDim2.fromOffset(560, 56),
			Image = art.Title,
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = panel,
		})
	else
		local title = UI.display(
			"Headline",
			"Maple Grove Best Yard",
			{ TextSize = 60, Color = UI.Colors.Money, XAlignment = "Center", Fit = true, ZIndex = 2 },
			{ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 56), Parent = panel }
		)
		title.Frame.ZIndex = 2
	end

	-- Your yard, the trophy, Gloria's yard.
	local cards = UI.new("Frame", {
		Position = UDim2.fromOffset(40, 92),
		Size = UDim2.fromOffset(1020, 190),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local yours, hers = result.you or {}, result.gloria or {}
	yardCard(cards, 0, {
		tag = if won then "YOUR YARD · WINNER" else "YOUR YARD · RUNNER-UP",
		name = "Grandma June's",
		line = "Kept by you and your crew",
		score = yours.total or 0,
		color = UI.Colors.Accent,
		winner = won,
	})
	local cup = trophy(cards, won)
	yardCard(cards, 690, {
		tag = if won then "NEXT DOOR · RUNNER-UP" else "NEXT DOOR · WINNER",
		name = "Gloria Pemberton's",
		line = "Done by TurfKing",
		crown = true,
		score = hers.total or 0,
		color = UI.Colors.Rival,
		winner = not won,
	})

	-- The categories.
	local scores = UI.new("Frame", {
		Position = UDim2.fromOffset(40, 300),
		Size = UDim2.fromOffset(1020, 196),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = panel,
	}, {
		UI.corner(18),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 22),
			PaddingRight = UDim.new(0, 22),
		}),
		UI.list(10),
	})
	local header =
		UI.new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1, Parent = scores })
	for _, column in { { "JUDGED ON", 0 }, { "YOU", COLUMN_YOU }, { "GLORIA", COLUMN_GLORIA } } do
		UI.label(column[1], {
			Position = UDim2.fromOffset(column[2], 0),
			Size = UDim2.fromOffset(200, 18),
			TextSize = 15,
			TextColor3 = UI.Colors.SubText,
			Parent = header,
		})
	end
	for index, category in Contest.Categories do
		categoryRow(scores, index, category, yours[category.id] or 0, hers[category.id] or 0)
	end

	-- What you won, Gloria's last word and Collect.
	local footer = UI.new("Frame", {
		Position = UDim2.fromOffset(40, 514),
		Size = UDim2.fromOffset(1020, 100),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	chips(footer, result)
	local closing = if won then Story.ContestClosing.Win else Story.ContestClosing.Lose
	local who = Story.Cast[closing.speaker]
	UI.label(`{if who then who.name else closing.speaker}: “{Story.plain(closing.text)}”`, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -196, 0, 0),
		Size = UDim2.fromOffset(250, 92),
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = UI.Colors.SubText,
		FontFace = Font.new(UI.Fonts.Body.Family, Enum.FontWeight.SemiBold, Enum.FontStyle.Italic),
		Parent = footer,
	})
	local button = UI.button("Collect", collect, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 14),
		Size = UDim2.fromOffset(180, 66),
		TextSize = 26,
		Style = "Primary",
		Parent = footer,
	})
	-- Plain, it gets a dark outline (the art has its own).
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 14)
		UI.new("UIStroke", {
			Color = UI.Colors.Outline,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
	end

	fit()
	screen.Enabled = true
	if won then
		confetti()
		-- And the trophy sparkles.
		UI.sparkle(cup, 8, 34)
	end
end

-- Whether the results can show now: there's a result, its scene is over, and nothing else is up.
local function ready()
	local contest = ClientState.contest
	local result = contest and contest.state == "Results" and contest.result
	if not result then
		return nil
	end
	if result.scene and DialogueController.isPending(result.scene) then
		return nil
	end
	if DialogueController.isOpen() or not DialogueController.canPlay() then
		return nil
	end
	return result
end

local function build()
	screen = UI.new("ScreenGui", {
		Name = "BestYard",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 9,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	pcall(function()
		(screen :: any).ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	-- A dim backdrop that keeps clicks off the world (and frees the mouse first person locks).
	UI.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Letterbox,
		BackgroundTransparency = 0.25,
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		Parent = screen,
	})
	panel = UI.sliced("Panel", {
		Name = "Results",
		ClipsDescendants = true,
		Parent = screen,
	}, { color = UI.Colors.Background, radius = 24 }) :: Frame
	UI.keepPlaced(panel, "ContestResults")
	UI.new("UIPadding", { PaddingTop = UDim.new(0, 24), Parent = panel })
	scale = UI.scaler(panel)
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end

function ContestController:Start()
	build()
	DialogueController.addShot("Yard", yardShot)
	DialogueController.LineShown:Connect(function(_sceneId, _index, line)
		if line.judges == "Yard" then
			walkJudges(yardPath())
		elseif line.judges == "Gloria" then
			walkJudges(gloriaPath())
		end
	end)
	DialogueController.Closed:Connect(stopJudges)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			if showing then
				-- Collected (or gone) somewhere else.
				local contest = ClientState.contest
				if not (contest and contest.state == "Results") then
					hide()
				end
			else
				local result = ready()
				if result then
					show(result)
				end
			end
		end
	end)
end

return ContestController
