-- The Finds Book, the shop computer's Finds app (ComputerController; docs/superpowers/specs/
-- 2026-10-29-busy-season-design.md, "Slice 3: Finds"). The thirty Finds fill a scrolling book, by
-- rarity and in the list's order inside each. One not found yet is a dark cell with a question mark.
-- A found one shows its placeholder colour, its name, its rarity in that rarity's colour (a frame drawn
-- in code from Finds.Rarities, not a picture) and how many you hold. Under the book are the five sets,
-- each with how many of it you have found, its perk and whether it is complete. Tapping a Find shows
-- it in the pane beside the book: its story, and for one you hold a Sell button that takes a second
-- tap, like the shop's (ShopService:SellFind pays). A Find you sold or returned stays found, so it
-- stays in the book and still counts toward its set. While the book is open it is drawn again when the
-- Finds or sets in the profile change (or another Find is tapped), so a pickup or a sale shows at once;
-- a money or XP push, which changes the profile but not them, leaves the cells alone, so one is never
-- rebuilt under a finger mid-tap. The pane is redrawn every time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Finds = require(Shared.Config.Finds)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

-- Selling takes a second tap within this many seconds, so it can't happen by accident.
local SELL_CONFIRM_TIME = 3
-- A cell in the book and the gap between cells, in pixels: docked in the monitor nothing scales the
-- window (UI.unscale), and check-gui fits these to the phone.
local CELL_WIDTH = 96
local CELL_HEIGHT = 84
local CELL_GAP = 6
-- The pane beside the book and the gap between them.
local DETAIL_WIDTH = 220
local PANE_GAP = 10
-- Room the book keeps on its width: the scroll bar (6 px) and, either side, room for the cells' frames
-- (FRAME_ROOM each), which are drawn just outside the cells.
local SCROLL_ROOM = 12
local FRAME_ROOM = 3
-- Inside the pane: its padding, the name and rarity lines at its top, at least this much story under
-- them (two lines; a long story scrolls), and the Sell button along its bottom.
local DETAIL_PAD = 8
local DETAIL_HEAD = 50
local STORY_ROOM = 40
local SELL_HEIGHT = 44
-- A set's row under the book.
local SET_HEIGHT = 50
-- A cell for a Find not found yet: a dark silhouette with a dim edge and a question mark.
local SILHOUETTE = Color3.fromRGB(26, 32, 28)
local SILHOUETTE_EDGE = Color3.fromRGB(78, 88, 80)

local FindsController = {}

local window: GuiObject
local book: ScrollingFrame
local paneName: TextLabel
local paneRarity: TextLabel
local paneStory: TextLabel
local paneNote: TextLabel
local sellButton: TextButton
-- The Find whose story the pane shows, the one waiting for its second Sell tap (and since when), and
-- whether a sale is on its way to the server.
local selected: string? = nil
local confirming: string? = nil
local confirmingSince = 0
local selling = false
-- What the book on screen was drawn from (see bookSignature), so a profile push that changes none of it
-- doesn't rebuild the cells.
local drawn: string? = nil

local function colorOf(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- How many of a Find the profile says were ever found, and how many are held now.
local function countsOf(profile, id: string): (number, number)
	local finds = if profile then profile.finds else nil
	local entry = if typeof(finds) == "table" then finds[id] else nil
	if typeof(entry) ~= "table" then
		return 0, 0
	end
	return tonumber(entry.found) or 0, tonumber(entry.held) or 0
end

local function isComplete(profile, set): boolean
	local sets = if profile then profile.sets else nil
	if typeof(sets) == "table" and sets[set.id] == true then
		return true
	end
	return Finds.setProgress(if profile then profile.finds else nil, set) >= #set.members
end

local render

-- The pane: the tapped Find (its name, rarity, story and Sell button), or how to use the book.
local function renderPane(profile)
	local find = if selected then Finds.get(selected) else nil
	local found, held = 0, 0
	if find then
		found, held = countsOf(profile, find.id)
	end
	local canSell = find ~= nil and found >= 1 and held >= 1
	if not find then
		paneName.Text = "Finds Book"
		paneRarity.Text = `{Finds.foundCount(if profile then profile.finds else nil)} of {#Finds.List} found`
		paneRarity.TextColor3 = UI.Colors.Text
		paneStory.Text = "Tap a Find to read its story. Job lawns hide more of them, so keep an eye on the grass."
		paneNote.Text = "A Find you hold can be sold here."
	elseif found < 1 then
		paneName.Text = "Not found yet"
		paneRarity.Text = find.rarity
		paneRarity.TextColor3 = colorOf(Finds.Rarities[find.rarity].frame)
		paneStory.Text = "It's out there in somebody's grass. Keep mowing."
		paneNote.Text = ""
	else
		paneName.Text = find.name
		paneRarity.Text = if held > 0 then `{find.rarity}, you have {held}` else find.rarity
		paneRarity.TextColor3 = colorOf(Finds.Rarities[find.rarity].frame)
		paneStory.Text = find.story
		paneNote.Text = if canSell then "" else "None held now. It stays in your book and its set."
	end
	sellButton.Visible = canSell
	paneNote.Visible = not canSell
	if find and canSell then
		local value = Format.money(Finds.Rarities[find.rarity].value)
		if selling then
			sellButton.Text = "Selling..."
			UI.setStyle(sellButton, "Disabled")
		elseif confirming == find.id then
			sellButton.Text = `Sell {value}?`
			UI.setStyle(sellButton, "Danger")
		else
			sellButton.Text = `Sell {value}`
			UI.setStyle(sellButton, "Money")
		end
	end
end

-- One Find's cell in the book.
local function cell(find, profile, order: number, parent: Instance)
	local found, held = countsOf(profile, find.id)
	local isFound = found >= 1
	local frameColor = colorOf(Finds.Rarities[find.rarity].frame)
	local button = UI.new("TextButton", {
		Name = find.id,
		LayoutOrder = order,
		BackgroundColor3 = if isFound then UI.Colors.Card else SILHOUETTE,
		AutoButtonColor = true,
		Text = "",
		Parent = parent,
	}, { UI.corner(8) })
	UI.new("UIStroke", {
		Color = if isFound then frameColor elseif selected == find.id then UI.Colors.Text else SILHOUETTE_EDGE,
		Thickness = if selected == find.id then FRAME_ROOM else 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	if not isFound then
		UI.label("?", {
			Size = UDim2.fromScale(1, 1),
			TextSize = 36,
			FontFace = UI.Fonts.Heavy,
			TextColor3 = SILHOUETTE_EDGE,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
	else
		-- Its placeholder colour, until the Finds have pictures.
		UI.new("Frame", {
			Name = "Swatch",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = colorOf(find.color),
			Parent = button,
		}, { UI.corner(13), UI.new("UIStroke", { Color = UI.Colors.Ink, Thickness = 1 }) })
		UI.label(find.name, {
			Position = UDim2.fromOffset(4, 34),
			Size = UDim2.new(1, -8, 0, 30),
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = button,
		})
		UI.label(find.rarity, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -8, 0, 14),
			TextSize = 12,
			FontFace = UI.Fonts.Heavy,
			TextColor3 = frameColor,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		if held > 0 then
			UI.label(`x{held}`, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, 3),
				Size = UDim2.fromOffset(34, 16),
				TextSize = 13,
				FontFace = UI.Fonts.Heavy,
				TextColor3 = UI.Colors.Money,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = button,
			})
		end
	end
	button.Activated:Connect(function()
		if selected ~= find.id then
			selected = find.id
			confirming = nil
		end
		render()
	end)
end

-- A set's row: its name, how many of it are found (or Complete), and its perk.
local function setRow(set, profile, order: number)
	local done = isComplete(profile, set)
	local have = Finds.setProgress(if profile then profile.finds else nil, set)
	local row = UI.new("Frame", {
		Name = set.id,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, SET_HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = book,
	}, { UI.corner(8) })
	if done then
		UI.new("UIStroke", { Color = UI.Colors.Gold, Thickness = 2, Parent = row })
	end
	UI.heading(set.name, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -120, 0, 24),
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	UI.label(if done then "Complete" else `{have}/{#set.members}`, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4),
		Size = UDim2.fromOffset(100, 24),
		TextSize = 18,
		FontFace = UI.Fonts.Heavy,
		TextColor3 = if done then UI.Colors.Gold else UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	UI.label(set.text, {
		Position = UDim2.fromOffset(10, 27),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = 14,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
end

local function renderBook(profile)
	-- Drawn again from scratch, at the same scroll.
	local scrolled = book.CanvasPosition
	UI.clearList(book)
	local sets = 0
	for _, set in Finds.Sets do
		if isComplete(profile, set) then
			sets += 1
		end
	end
	local finds = if profile then profile.finds else nil
	UI.label(`{Finds.foundCount(finds)} of {#Finds.List} found, {sets} of {#Finds.Sets} sets complete`, {
		LayoutOrder = 1,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = book,
	})
	for rank, rarity in Finds.RarityOrder do
		local have, total = 0, 0
		for _, find in Finds.List do
			if find.rarity == rarity then
				total += 1
				if (countsOf(profile, find.id)) >= 1 then
					have += 1
				end
			end
		end
		UI.heading(`{rarity}  {have}/{total}`, {
			LayoutOrder = rank * 10,
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 18,
			TextColor3 = colorOf(Finds.Rarities[rarity].frame),
			Parent = book,
		})
		-- The rarity's cells, in the list's order, wrapping to the book's width.
		local grid = UI.new("Frame", {
			Name = rarity,
			LayoutOrder = rank * 10 + 1,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = book,
		}, {
			UI.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT),
				CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for index, find in Finds.List do
			if find.rarity == rarity then
				cell(find, profile, index, grid)
			end
		end
	end
	UI.heading("Sets", {
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		Parent = book,
	})
	for index, set in Finds.Sets do
		setRow(set, profile, 100 + index)
	end
	book.CanvasPosition = scrolled
end

-- Everything the cells and sets are drawn from, as one short string: how many of each Find were found
-- and are held, which sets are done, and which Find is tapped (its cell has a thicker frame). Money
-- and XP are not in it.
local function bookSignature(profile): string
	local parts = { selected or "-" }
	for _, find in Finds.List do
		local found, held = countsOf(profile, find.id)
		table.insert(parts, `{found}:{held}`)
	end
	local sets = if profile and typeof(profile.sets) == "table" then profile.sets else {}
	for _, set in Finds.Sets do
		table.insert(parts, if sets[set.id] == true then "1" else "0")
	end
	return table.concat(parts, ",")
end

function render()
	if not (window and window.Visible) then
		return
	end
	local profile = ClientState.profile
	local signature = bookSignature(profile)
	if signature ~= drawn then
		drawn = signature
		renderBook(profile)
	end
	renderPane(profile)
end

-- The Sell button: the first tap asks, a second one within SELL_CONFIRM_TIME sells one copy.
local function sell()
	local find = if selected then Finds.get(selected) else nil
	if not find or selling then
		return
	end
	if confirming ~= find.id then
		local since = os.clock()
		confirming = find.id
		confirmingSince = since
		render()
		task.delay(SELL_CONFIRM_TIME, function()
			if confirming == find.id and confirmingSince == since then
				confirming = nil
				render()
			end
		end)
		return
	end
	confirming = nil
	selling = true
	render()
	local called, ok, message = pcall(function()
		return Net.func("SellFind"):InvokeServer(find.id)
	end)
	selling = false
	if called and ok then
		Sounds.playUi("Cash")
	end
	UI.notify(if called and typeof(message) == "string" then message else "That didn't sell. Try again.")
	render()
end

function FindsController:Start()
	local content
	window, content = UI.panel("Finds", "Finds Book")

	book = UI.scrollingList(content, {
		Name = "Book",
		Size = UDim2.new(1, -(DETAIL_WIDTH + PANE_GAP), 1, 0),
		ScrollBarThickness = SCROLL_ROOM - 2 * FRAME_ROOM,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	})
	-- Room for the cells' frames, which are drawn just outside them, so the edge doesn't cut them.
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, FRAME_ROOM),
		PaddingRight = UDim.new(0, FRAME_ROOM),
		PaddingTop = UDim.new(0, FRAME_ROOM),
		PaddingBottom = UDim.new(0, FRAME_ROOM),
		Parent = book,
	})

	local pane = UI.new("Frame", {
		Name = "Pane",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, DETAIL_WIDTH, 1, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = content,
	}, { UI.corner(10), UI.padding(DETAIL_PAD) })
	paneName = UI.heading("", {
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 20,
		TextScaled = true,
		Parent = pane,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12, Parent = paneName })
	paneRarity = UI.label("", {
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		FontFace = UI.Fonts.Heavy,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pane,
	})
	-- The story, scrolling if it's longer than the pane has room for.
	local story = UI.new("ScrollingFrame", {
		Name = "Story",
		Position = UDim2.fromOffset(0, DETAIL_HEAD),
		Size = UDim2.new(1, 0, 1, -(DETAIL_HEAD + DETAIL_PAD + SELL_HEIGHT)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = UI.Colors.SubText,
		Parent = pane,
	}, { UI.new("UISizeConstraint", { MinSize = Vector2.new(0, STORY_ROOM) }) })
	paneStory = UI.label("", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		FontFace = UI.Fonts.Medium,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = story,
	})
	sellButton = UI.button("", sell, {
		Name = "Sell",
		Style = "Money",
		Icon = "Sell",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, SELL_HEIGHT),
		TextSize = 18,
		Visible = false,
		Parent = pane,
	})
	paneNote = UI.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, SELL_HEIGHT),
		TextSize = 14,
		FontFace = UI.Fonts.Medium,
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		Parent = pane,
	})

	ClientState.Changed:Connect(function(key)
		if key == "profile" then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		else
			-- A fresh book next time: nothing tapped, nothing waiting to sell.
			selected = nil
			confirming = nil
		end
	end)
end

return FindsController
