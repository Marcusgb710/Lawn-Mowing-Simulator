-- Two apps on the shop computer (see ComputerController), one tab per category:
--   Orders    tools and supplies (delivered in a box to the shop), yard decorations for your
--             crew's business, a Premium tab of things bought with Robux (see Premium.luau), and
--             a Sell tab for tools you don't need, to free up storage
--   Business  building upgrades, trucks and trailers
-- Every tool says what it's for: that's how players learn which tool fits which job. Each tab has
-- its category's glyph and each card its item's picture, from the GUI art (plain until uploaded).
-- A card's price hangs on a garden plant tag over its button, tools wear a badge with their tier
-- and owned tools show their condition. Buying stamps the card "Bought" (with a few sparkles) and
-- selling stamps it "Sold".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Decorations = require(Shared.Config.Decorations)
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Premium = require(Shared.Config.Premium)
local Shop = require(Shared.Shop)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

-- Selling takes a second tap within this many seconds, so it can't happen by accident.
local SELL_CONFIRM_TIME = 3
-- After something's bought, its button rests this many seconds, so tapping Buy a few times
-- doesn't start selling it straight back (or restock it twice).
local BUY_REST = 1.5
-- How tall the Bought and Sold stamps are, and how many sparkles a purchase gets.
local STAMP_HEIGHT = 64
local SPARKLES = 6

local ShopController = {}

local SELL_TAB = "Sell"
local DECOR_TAB = "Decorations"
local PREMIUM_TAB = "Premium"
-- What each Robux perk says on a premium card.
local PERK_TEXT = {
	neverDull = "Blade never dulls",
	neverFlat = "Tires never go flat",
	endlessLine = "Line never runs out",
	bigTank = "Fuel lasts 3x as long",
}
-- The glyph on each tab (Icons/<name>.png): the tool categories' are Cat_<category>.
local TAB_ICONS = {
	[DECOR_TAB] = "Cat_Decorations",
	[PREMIUM_TAB] = "Premium",
	[SELL_TAB] = "Sell",
}
-- How big an item's picture is on its card, and how wide its button.
local PICTURE = 84
local BUTTON_WIDTH = 124
-- Which tabs each app shows.
local APPS = {
	Orders = { title = "Orders", tabs = table.clone(Items.ToolCategories) },
	Business = { title = "Business", tabs = { "Business", "Truck", "Trailer" } },
}
table.insert(APPS.Orders.tabs, DECOR_TAB)
table.insert(APPS.Orders.tabs, PREMIUM_TAB)
table.insert(APPS.Orders.tabs, SELL_TAB)

local window: GuiObject
local stamp: UI.Stamp
-- Where the last Robux button tapped was, for the stamp once Roblox's prompt says it's bought.
local premiumSpot: Vector2? = nil
local selectedCategory = Items.Categories[1]
local tabButtons = {}
local list: ScrollingFrame
-- The tool id waiting for a second tap to sell, and when the first tap was.
local confirmingSell: string? = nil
local confirmingSince = 0
-- [item id] = os.clock() it was last bought
local boughtAt: { [string]: number } = {}

local function resting(item): boolean
	local at = boughtAt[item.id]
	return at ~= nil and os.clock() - at < BUY_REST
end

local function storageText(business): string
	local parts = {}
	for _, spot in Storage.SpotOrder do
		local count = business.storage[spot] or 0
		if count > 0 then
			local name = Storage.Spots[spot].name
			table.insert(parts, `{name} {count}`)
		end
	end
	return table.concat(parts, "  ·  ") .. (if business.noEngines then "  ·  no engines" else "")
end

local function statsText(item): string
	if Decorations.get(item.id) == item then
		local parts = { `Curb appeal +{item.appeal}` }
		if item.onLawn then
			table.insert(parts, "Can stand on the lawn")
		end
		if item.snaps then
			table.insert(parts, "Joins end to end")
		end
		if item.shrub then
			table.insert(parts, "Keep it trimmed with a hedge tool")
		end
		return table.concat(parts, "  ·  ")
	elseif item.category == "Truck" then
		return `Job pay +{math.floor(item.payoutBonus * 100)}%  ·  Holds {item.space} space`
	elseif item.category == "Trailer" then
		local text = `+{item.space} space`
		return if item.bays > 0 then `{text}  ·  {item.bays} ride-on bays` else text
	elseif item.category == "Business" then
		return `Job pay +{math.floor(item.payoutBonus * 100)}%\nStores: {storageText(item)}`
	end
	local size = Tools.SizeClasses[item.sizeClass]
	local truck = if item.sizeClass == "Bay"
		then "needs a trailer bay"
		elseif item.id == Storage.BucketId then `1 space, holds {Storage.BucketHolds} hand tools`
		else `{size.space} truck space`
	-- The tier is on the card's badge.
	local parts = { `{size.label}, {string.lower(Storage.Spots[size.spot].name)}, {truck}` }
	-- A mower's power no longer meters its mowing (its deck cuts everything under it), so it only
	-- shows how far its deck reaches.
	if item.power and item.category == "Mower" then
		table.insert(parts, `Reach {item.radius}`)
	elseif item.power then
		table.insert(parts, `Power {item.power}  ·  Reach {item.radius}`)
	end
	if item.cutQuality then
		table.insert(parts, `Cut {math.floor(item.cutQuality * 100)}%`)
	end
	if item.walkSpeed then
		table.insert(parts, `Speed {item.walkSpeed}`)
	end
	if item.motorized == false then
		table.insert(parts, "No motor")
	end
	local supply = Maintenance.Supplies[item.id]
	if supply and supply.uses then
		table.insert(parts, if supply.uses == 1 then "One use" else `{supply.uses} uses, then restock`)
	end
	if supply and supply.stationary then
		table.insert(parts, "Stays in the building")
	end
	return table.concat(parts, "  ·  ")
end

-- How full each kind of storage is at your business, for the tool tabs.
local function storageSummary(profile): string
	local parts = {}
	for _, spot in Storage.SpotOrder do
		local capacity = Storage.capacity(profile.equipped.Business, spot)
		local used = Storage.used(profile.owned, spot)
		if capacity > 0 or used > 0 then
			table.insert(parts, `{Storage.Spots[spot].name} {used}/{capacity}`)
		end
	end
	return "Your storage: " .. table.concat(parts, "  ·  ")
end

local render

-- Where the middle of `target` is in the window, as fractions of its size (for the stamp: they
-- stay right whatever scales the window).
local function spotIn(target: GuiObject): Vector2?
	local size = window.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local middle = target.AbsolutePosition + target.AbsoluteSize / 2 - window.AbsolutePosition
	return Vector2.new(middle.X / size.X, middle.Y / size.Y)
end

-- `source` is the card's button, where the stamp lands.
local function act(action: string, item, category: string, source: GuiObject?)
	if resting(item) then
		return
	end
	if action == "SellItem" and confirmingSell ~= item.id then
		confirmingSell = item.id
		confirmingSince = os.clock()
		render()
		task.delay(SELL_CONFIRM_TIME, function()
			if confirmingSell == item.id and os.clock() - confirmingSince >= SELL_CONFIRM_TIME then
				confirmingSell = nil
				render()
			end
		end)
		return
	end
	confirmingSell = nil
	-- Before asking: the card's drawn again (and its button gone) when the new profile arrives.
	local at = if source then spotIn(source) else nil
	if action == "BuyItem" then
		-- Before asking, since the new profile (and its Sell button) can arrive first.
		boughtAt[item.id] = os.clock()
	end
	local ok, message = Net.func(action):InvokeServer(category, item.id)
	if ok and action == "BuyItem" then
		stamp.flash("Stamp_Bought", at, SPARKLES)
	elseif ok and action == "SellItem" then
		stamp.flash("Stamp_Sold", at)
	end
	if action == "BuyItem" then
		if ok then
			task.delay(BUY_REST, render)
		else
			boughtAt[item.id] = nil
		end
	end
	UI.notify(message)
end

-- What the button on an item's card says and does (its style, see UI.setStyle), a note under it
-- (why it's locked, if it is, or the Best Yard prize's discount) and, while it's for sale, its
-- price for the plant tag over the button.
local function buttonFor(profile, item, category: string): (string, string, string?, string?, number?)
	if category == DECOR_TAB then
		if resting(item) then
			return "Bought", "Disabled", nil, nil, nil
		end
		local affordable = profile.money >= item.price
		return "Buy", if affordable then "Primary" else "Disabled", "BuyItem", nil, item.price
	end
	local owned = profile.owned[category] and profile.owned[category][item.id]
	if Items.isToolCategory(category) then
		if owned and resting(item) then
			return "Bought", "Disabled", nil, nil, nil
		elseif owned then
			if Shop.canRestock(profile, item.id) then
				local affordable = profile.money >= item.price
				return "Restock", if affordable then "Primary" else "Disabled", "BuyItem", nil, item.price
			elseif not Shop.canSell(item) then
				return "Starter", "Disabled", nil, nil, nil
			elseif confirmingSell == item.id then
				return "Tap to sell", "Danger", "SellItem", nil, nil
			end
			local sellPrice = Shop.sellPrice(item, profile.condition and profile.condition[item.id])
			return `Sell {Format.money(sellPrice)}`, "Danger", "SellItem", nil, nil
		end
	elseif profile.equipped[category] == item.id then
		return if category == "Business" then "Current" else "Equipped", "Disabled", nil, nil, nil
	elseif owned then
		if category == "Business" then
			return "Owned", "Disabled", nil, nil, nil
		end
		return "Equip", "Primary", "EquipItem", nil, nil
	end

	local allowed, reason = Shop.canBuy(profile, category, item.id)
	local price = Shop.price(profile, category, item.id)
	local prize = if price < item.price
		then `Best Yard prize: half off, {Format.money(price)} instead of {Format.money(item.price)}.`
		else nil
	if not allowed then
		return "Locked", "Disabled", nil, if prize then `{reason}\n{prize}` else reason, price
	end
	local affordable = profile.money >= price
	return "Buy", if affordable then "Primary" else "Disabled", "BuyItem", prize, price
end

-- An item card: the art's card (greyed when it's locked), with the item's picture on the left
-- when it's uploaded. Returns the card and the frame its words go in (left of the button).
local function itemCard(order: number, image: string, locked: boolean, round: boolean?): (GuiObject, Frame)
	local card = UI.card({
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = list,
	}, if locked then "Locked" else nil)
	local left = 0
	if image ~= "" then
		-- The picture's frame also keeps the card at least as tall as the picture.
		local holder = UI.new("Frame", {
			Name = "Picture",
			Size = UDim2.fromOffset(PICTURE + 20, PICTURE + 20),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local picture = UI.picture(image, {
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(PICTURE, PICTURE),
			Parent = holder,
		}) :: ImageLabel
		if round then
			UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = picture })
		end
		left = PICTURE + 14
	end
	local details = UI.new("Frame", {
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -150 - left, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { UI.list(3), UI.padding(10) })
	return card, details
end

-- The button on the right of a card, and while it's for sale its `price` on a plant tag over it
-- (shaded when it's out of reach). A price given as text ("Earned", for a paint that was a level
-- reward) goes on the tag as it is, and is never shaded. Returns the button.
local function cardButton(
	card: GuiObject,
	text: string,
	style: string,
	onClick: (button: TextButton) -> (),
	price: (number | string)?
): TextButton
	-- The tag and the button, 34 + 6 + 40 tall, sit together in the middle of the card's right.
	local button: TextButton
	button = UI.button(text, function()
		onClick(button)
	end, {
		Style = style,
		Icon = if text == "Locked" then "Lock" else nil,
		IconSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, if price then 20 else 0),
		Size = UDim2.fromOffset(BUTTON_WIDTH, 40),
		TextScaled = true,
		Parent = card,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = button })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = button })
	if price then
		local dollars = typeof(price) == "number"
		UI.priceTag(if typeof(price) == "number" then Format.money(price) else price, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(1, -12 - BUTTON_WIDTH / 2, 0.5, -6),
			Size = UDim2.fromOffset(0, 34),
			Rotation = -3,
			Parent = card,
		}, dollars and style == "Disabled")
		-- The card's at least as tall as the tag and the button.
		UI.new("Frame", { Size = UDim2.fromOffset(1, 96), BackgroundTransparency = 1, Parent = card })
	end
	return button
end

-- One card on the Premium tab: its picture (a pass's circle, a tool or a truck), name,
-- description and details down the left, a button on the right, and a `tag` over the button when
-- it has one (the paints that were earned, not bought, say "Earned").
local function premiumCard(
	order: number,
	image: string,
	name: string,
	description: string,
	details: string,
	note: string?,
	buttonText: string,
	style: string,
	onClick: (() -> ())?,
	tag: string?
)
	local card, text = itemCard(order, image, false, string.find(image, "Pass_") ~= nil)
	UI.heading(name, { TextSize = 20, LayoutOrder = 1, Parent = text })
	for index, line in { description, details, note or "" } do
		if line ~= "" then
			UI.label(line, {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 14,
				FontFace = if index == 1 then UI.Fonts.Body else UI.Fonts.Medium,
				TextColor3 = if index == 1
					then UI.Colors.Text
					elseif index == 2 then UI.Colors.SubText
					else UI.Colors.Money,
				LayoutOrder = index + 1,
				Parent = text,
			})
		end
	end
	cardButton(card, buttonText, style, function(button)
		if onClick then
			premiumSpot = spotIn(button)
			onClick()
		end
	end, tag)
end

local function premiumHeading(order: number, text: string)
	UI.heading(string.upper(text), {
		Size = UDim2.new(1, -8, 0, 30),
		TextSize = 22,
		TextColor3 = UI.Colors.Money,
		LayoutOrder = order,
		Parent = list,
	})
end

-- The Premium tab: Pro upgrades (game passes), premium tools and truck paint, bought with Robux.
-- Roblox's own prompt does the buying; the server grants it (see PremiumService).
local function renderPremium(profile)
	local premium = profile.premium or Premium.empty()
	local player = Players.LocalPlayer
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function price(robux: number): string
		return `R$ {robux}`
	end

	premiumHeading(nextOrder(), "Pro upgrades")
	for _, pass in Premium.Passes do
		local owned = premium.passes and premium.passes[pass.id]
		local text, style, onClick =
			price(pass.robux), "Robux", function()
				MarketplaceService:PromptGamePassPurchase(player, pass.gamePassId)
			end
		if owned then
			text, style, onClick = "Owned", "Disabled", nil
		elseif pass.gamePassId == 0 then
			text, style, onClick = "Soon", "Disabled", nil
		end
		premiumCard(
			nextOrder(),
			Art.store(`Pass_{pass.id}`),
			pass.name,
			pass.description,
			"Works on every tool you own",
			nil,
			text,
			style,
			onClick
		)
	end

	premiumHeading(nextOrder(), "Premium tools")
	for _, variant in Premium.Variants do
		local base = Tools.get(variant.baseId)
		local baseName = if base then base.name else variant.baseId
		local perks = {}
		for perk in variant.perks do
			table.insert(perks, PERK_TEXT[perk] or perk)
		end
		table.sort(perks)
		local ownsBase = base ~= nil and profile.owned[base.category] and profile.owned[base.category][base.id]
		local text, style, note, onClick =
			price(variant.robux), "Robux", nil, function()
				MarketplaceService:PromptProductPurchase(player, variant.productId)
			end
		if premium.owned and premium.owned[variant.id] then
			text, style, onClick = "Owned", "Disabled", nil
		elseif variant.productId == 0 then
			text, style, onClick = "Soon", "Disabled", nil
		elseif not ownsBase then
			text, style, note, onClick = "Locked", "Disabled", `Needs your own {baseName} first.`, nil
		end
		premiumCard(
			nextOrder(),
			Art.item(variant.id),
			variant.name,
			variant.description,
			`Upgrades your {baseName}  ·  {table.concat(perks, "  ·  ")}`,
			note,
			text,
			style,
			onClick
		)
	end

	premiumHeading(nextOrder(), "Truck paint")
	local current = Premium.paintFor(premium)
	if current then
		premiumCard(
			nextOrder(),
			Art.item("WorkPickup"),
			"Factory paint",
			"Take the paint job off.",
			"",
			nil,
			"Use",
			"Primary",
			function()
				local _, message = Net.func("SetTruckPaint"):InvokeServer("")
				UI.notify(message)
			end
		)
	end
	for _, paint in Premium.Paints do
		local owned = premium.owned and premium.owned[paint.id]
		local text, style, onClick =
			price(paint.robux), "Robux", function()
				MarketplaceService:PromptProductPurchase(player, paint.productId)
			end
		if current == paint then
			text, style, onClick = "In use", "Disabled", nil
		elseif owned then
			text, style, onClick =
				"Use", "Primary", function()
					local _, message = Net.func("SetTruckPaint"):InvokeServer(paint.id)
					UI.notify(message)
				end
		elseif paint.productId == 0 then
			text, style, onClick = "Soon", "Disabled", nil
		end
		local look = if paint.finish then `{paint.finish} finish` else "Paint"
		-- A paint they own that wasn't bought (a level reward) says so where the price would be.
		local earned = owned and premium.earnedPaints ~= nil and premium.earnedPaints[paint.id] == true
		premiumCard(
			nextOrder(),
			Art.item(paint.id),
			paint.name,
			`A {string.lower(paint.name)} paint job for whichever truck you drive. Looks only.`,
			look,
			nil,
			text,
			style,
			onClick,
			if earned then "Earned" else nil
		)
	end
end

-- The window's title: the app, then the tab ("Orders / Mowers").
local function setTitle()
	local title = window:FindFirstChild("Title")
	if not (title and title:IsA("TextLabel")) then
		return
	end
	local app = if table.find(APPS.Business.tabs, selectedCategory) then APPS.Business else APPS.Orders
	local info = Items.CategoryInfo[selectedCategory]
	title.Text = `{app.title}  /  {if info then info.displayName else selectedCategory}`
end

function render()
	for category, button in tabButtons do
		UI.setTab(button, category == selectedCategory)
	end
	setTitle()

	UI.clearList(list)
	local profile = ClientState.profile
	if not profile then
		return
	end
	if selectedCategory == PREMIUM_TAB then
		renderPremium(profile)
		return
	end
	local header = nil
	if selectedCategory == "Trailer" and not profile.trailerUnlocked then
		header = "Fill up your truck to unlock trailers."
	elseif selectedCategory == SELL_TAB then
		header = "Sell tools you don't use to free up storage. You get half their price back, less wear."
	elseif selectedCategory == DECOR_TAB then
		local party = ClientState.party
		local whose = if party and party.leader ~= Players.LocalPlayer then `{party.leader.DisplayName}'s` else "your"
		header = `For {whose} yard. Each comes in a box at the shop: open it, then put it where you like `
			.. "(not on the driveway). A good-looking yard is curb appeal, worth up to +15% on every job."
	elseif Items.isToolCategory(selectedCategory) then
		header = storageSummary(profile)
	end
	if header then
		UI.label(header, {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 15,
			TextColor3 = UI.Colors.Money,
			LayoutOrder = 0,
			Parent = list,
		})
	end

	-- The Sell tab lists every tool you could sell, from every tab.
	local items = {}
	if selectedCategory == SELL_TAB then
		for _, tool in Items.ownedTools(profile.owned) do
			if Shop.canSell(tool) and not (profile.loadout[tool.id] or Shop.canRestock(profile, tool.id)) then
				table.insert(items, tool)
			end
		end
		if #items == 0 then
			UI.label("Nothing to sell. Your starter gear stays, and tools in the truck have to come out first.", {
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 15,
				TextColor3 = UI.Colors.SubText,
				LayoutOrder = 1,
				Parent = list,
			})
		end
	elseif selectedCategory == DECOR_TAB then
		-- Everything but what's only won (the Best Yard Trophy).
		items = {}
		for _, decoration in Decorations.List do
			if not decoration.won then
				table.insert(items, decoration)
			end
		end
	else
		items = Items.Catalog[selectedCategory]
	end

	for index, item in items do
		local category = item.category or selectedCategory
		local text, style, action, lockedBecause, price = buttonFor(profile, item, category)
		-- Text down the left (it wraps, so long descriptions grow the card); button on the right.
		local card, details = itemCard(index, Art.item(item.id), text == "Locked")

		UI.heading(item.name, { TextSize = 20, LayoutOrder = 1, Parent = details })
		if item.tier then
			UI.tierBadge(item.tier, { LayoutOrder = 2, Parent = details })
		end
		UI.label(item.description, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			FontFace = UI.Fonts.Body,
			TextColor3 = UI.Colors.Text,
			LayoutOrder = 3,
			Parent = details,
		})
		UI.label(statsText(item), {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 4,
			Parent = details,
		})
		-- A tool you own: what shape it's in (wear takes off what it sells for).
		local owned = profile.owned[category] and profile.owned[category][item.id]
		if owned and Items.isToolCategory(category) then
			local parts = Maintenance.parts(item, profile.condition and profile.condition[item.id] or {})
			if #parts > 0 then
				UI.conditionRow(parts, { LayoutOrder = 5, Parent = details })
			end
		end
		if lockedBecause then
			UI.label(lockedBecause, {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 14,
				TextColor3 = UI.Colors.Money,
				LayoutOrder = 6,
				Parent = details,
			})
		end
		cardButton(card, text, style, function(button)
			if action then
				act(action, item, category, button)
			end
		end, price)
	end
end

-- Opens one of the shop computer's apps ("Orders" or "Business") on its first tab.
function ShopController.openApp(name: string)
	local app = APPS[name]
	if not app then
		return
	end
	for category, button in tabButtons do
		button.Visible = table.find(app.tabs, category) ~= nil
	end
	if not table.find(app.tabs, selectedCategory) then
		selectedCategory = app.tabs[1]
	end
	confirmingSell = nil
	UI.open("Shop")
	render()
end

function ShopController:Start()
	local content
	window, content = UI.panel("Shop", "Orders")

	local tabs = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = content,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })

	local allTabs = table.clone(Items.Categories)
	table.insert(allTabs, DECOR_TAB)
	table.insert(allTabs, PREMIUM_TAB)
	table.insert(allTabs, SELL_TAB)
	for index, category in allTabs do
		local info = Items.CategoryInfo[category]
		local name = if info then info.displayName else category
		tabButtons[category] = UI.tab(name, TAB_ICONS[category] or `Cat_{category}`, function()
			selectedCategory = category
			confirmingSell = nil
			render()
		end, { LayoutOrder = index, Parent = tabs })
	end

	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
	})
	-- Over the window, not the list, so a card drawn again doesn't take its stamp with it.
	stamp = UI.stamp(window, { Stamp_Bought = "Bought!", Stamp_Sold = "Sold!" }, STAMP_HEIGHT)

	-- A Robux purchase that went through is stamped too (the server grants it, see PremiumService).
	local player = Players.LocalPlayer
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
		if purchased and userId == player.UserId and window.Visible then
			stamp.flash("Stamp_Bought", premiumSpot, SPARKLES)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, _, purchased)
		if purchased and buyer == player and window.Visible then
			stamp.flash("Stamp_Bought", premiumSpot, SPARKLES)
		end
	end)

	ClientState.Changed:Connect(function(key)
		if key == "profile" and window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
end

return ShopController
