-- Two apps on the shop computer (see ComputerController), one tab per category:
--   Orders    tools and supplies (delivered in a box to the shop), yard decorations for your
--             crew's business, a Premium tab of things bought with Robux (see Premium.luau), and
--             a Sell tab for tools you don't need, to free up storage
--   Business  building upgrades, trucks and trailers
-- Every tool says what it's for: that's how players learn which tool fits which job.

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

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

-- Selling takes a second tap within this many seconds, so it can't happen by accident.
local SELL_CONFIRM_TIME = 3
-- After something's bought, its button rests this many seconds, so tapping Buy a few times
-- doesn't start selling it straight back (or restock it twice).
local BUY_REST = 1.5

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
-- Which tabs each app shows.
local APPS = {
	Orders = { title = "Orders", tabs = table.clone(Items.ToolCategories) },
	Business = { title = "Business", tabs = { "Business", "Truck", "Trailer" } },
}
table.insert(APPS.Orders.tabs, DECOR_TAB)
table.insert(APPS.Orders.tabs, PREMIUM_TAB)
table.insert(APPS.Orders.tabs, SELL_TAB)

local window: Frame
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
	local parts = { item.tier, `{size.label}, {string.lower(Storage.Spots[size.spot].name)}, {truck}` }
	if item.power then
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

local function act(action: string, item, category: string)
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
	if action == "BuyItem" then
		-- Before asking, since the new profile (and its Sell button) can arrive first.
		boughtAt[item.id] = os.clock()
	end
	local ok, message = Net.func(action):InvokeServer(category, item.id)
	if action == "BuyItem" then
		if ok then
			task.delay(BUY_REST, render)
		else
			boughtAt[item.id] = nil
		end
	end
	UI.notify(message)
end

-- What the button on an item's card says and does, plus a note under it: why it's locked (if it
-- is), or the Best Yard prize's discount.
local function buttonFor(profile, item, category: string): (string, Color3, string?, string?)
	if category == DECOR_TAB then
		if resting(item) then
			return "Bought", UI.Colors.Disabled, nil, nil
		end
		local affordable = profile.money >= item.price
		return Format.money(item.price), if affordable then UI.Colors.Money else UI.Colors.Disabled, "BuyItem", nil
	end
	local owned = profile.owned[category] and profile.owned[category][item.id]
	if Items.isToolCategory(category) then
		if owned and resting(item) then
			return "Bought", UI.Colors.Disabled, nil, nil
		elseif owned then
			if Shop.canRestock(profile, item.id) then
				local affordable = profile.money >= item.price
				return `Restock {Format.money(item.price)}`,
					if affordable then UI.Colors.Money else UI.Colors.Disabled,
					"BuyItem",
					nil
			elseif not Shop.canSell(item) then
				return "Starter", UI.Colors.Disabled, nil, nil
			elseif confirmingSell == item.id then
				return "Tap to sell", UI.Colors.Danger, "SellItem", nil
			end
			local sellPrice = Shop.sellPrice(item, profile.condition and profile.condition[item.id])
			return `Sell {Format.money(sellPrice)}`, UI.Colors.Card, "SellItem", nil
		end
	elseif profile.equipped[category] == item.id then
		return if category == "Business" then "Current" else "Equipped", UI.Colors.Disabled, nil, nil
	elseif owned then
		if category == "Business" then
			return "Owned", UI.Colors.Disabled, nil, nil
		end
		return "Equip", UI.Colors.Accent, "EquipItem", nil
	end

	local allowed, reason = Shop.canBuy(profile, category, item.id)
	local price = Shop.price(profile, category, item.id)
	local prize = if price < item.price
		then `Best Yard prize: half off, {Format.money(price)} instead of {Format.money(item.price)}.`
		else nil
	if not allowed then
		return "Locked", UI.Colors.Disabled, nil, if prize then `{reason}\n{prize}` else reason
	end
	local affordable = profile.money >= price
	return Format.money(price), if affordable then UI.Colors.Money else UI.Colors.Disabled, "BuyItem", prize
end

-- One card on the Premium tab: name, description and details down the left, a button on the right.
local function premiumCard(
	order: number,
	name: string,
	description: string,
	details: string,
	note: string?,
	buttonText: string,
	color: Color3,
	onClick: (() -> ())?
)
	local card = UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Card,
		LayoutOrder = order,
		Parent = list,
	}, { UI.corner(8) })
	local text = UI.new("Frame", {
		Size = UDim2.new(1, -150, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { UI.list(3), UI.padding(10) })
	UI.label(name, { TextSize = 20, LayoutOrder = 1, Parent = text })
	for index, line in { description, details, note or "" } do
		if line ~= "" then
			UI.label(line, {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 14,
				Font = if index == 1 then Enum.Font.Gotham else nil,
				TextColor3 = if index == 1
					then UI.Colors.Text
					elseif index == 2 then UI.Colors.SubText
					else UI.Colors.Money,
				LayoutOrder = index + 1,
				Parent = text,
			})
		end
	end
	UI.button(buttonText, function()
		if onClick then
			onClick()
		end
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = color,
		TextColor3 = if color == UI.Colors.Money then UI.Colors.Background else UI.Colors.Text,
		TextScaled = true,
		Parent = card,
	})
end

local function premiumHeading(order: number, text: string)
	UI.label(text, {
		Size = UDim2.new(1, -8, 0, 28),
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
		local text, color, onClick =
			price(pass.robux), UI.Colors.Money, function()
				MarketplaceService:PromptGamePassPurchase(player, pass.gamePassId)
			end
		if owned then
			text, color, onClick = "Owned", UI.Colors.Disabled, nil
		elseif pass.gamePassId == 0 then
			text, color, onClick = "Soon", UI.Colors.Disabled, nil
		end
		premiumCard(nextOrder(), pass.name, pass.description, "Works on every tool you own", nil, text, color, onClick)
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
		local text, color, note, onClick =
			price(variant.robux), UI.Colors.Money, nil, function()
				MarketplaceService:PromptProductPurchase(player, variant.productId)
			end
		if premium.owned and premium.owned[variant.id] then
			text, color, onClick = "Owned", UI.Colors.Disabled, nil
		elseif variant.productId == 0 then
			text, color, onClick = "Soon", UI.Colors.Disabled, nil
		elseif not ownsBase then
			text, color, note, onClick = "Locked", UI.Colors.Disabled, `Needs your own {baseName} first.`, nil
		end
		premiumCard(
			nextOrder(),
			variant.name,
			variant.description,
			`Upgrades your {baseName}  ·  {table.concat(perks, "  ·  ")}`,
			note,
			text,
			color,
			onClick
		)
	end

	premiumHeading(nextOrder(), "Truck paint")
	local current = Premium.paintFor(premium)
	if current then
		premiumCard(
			nextOrder(),
			"Factory paint",
			"Take the paint job off.",
			"",
			nil,
			"Use",
			UI.Colors.Accent,
			function()
				local _, message = Net.func("SetTruckPaint"):InvokeServer("")
				UI.notify(message)
			end
		)
	end
	for _, paint in Premium.Paints do
		local owned = premium.owned and premium.owned[paint.id]
		local text, color, onClick =
			price(paint.robux), UI.Colors.Money, function()
				MarketplaceService:PromptProductPurchase(player, paint.productId)
			end
		if current == paint then
			text, color, onClick = "In use", UI.Colors.Disabled, nil
		elseif owned then
			text, color, onClick =
				"Use", UI.Colors.Accent, function()
					local _, message = Net.func("SetTruckPaint"):InvokeServer(paint.id)
					UI.notify(message)
				end
		elseif paint.productId == 0 then
			text, color, onClick = "Soon", UI.Colors.Disabled, nil
		end
		local look = if paint.finish then `{paint.finish} finish` else "Paint"
		premiumCard(
			nextOrder(),
			paint.name,
			`A {string.lower(paint.name)} paint job for whichever truck you drive. Looks only.`,
			look,
			nil,
			text,
			color,
			onClick
		)
	end
end

function render()
	for category, button in tabButtons do
		button.BackgroundColor3 = if category == selectedCategory then UI.Colors.Accent else UI.Colors.Card
	end

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
		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })
		-- Text down the left (it wraps, so long descriptions grow the card); button on the right.
		local details = UI.new("Frame", {
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(3), UI.padding(10) })

		UI.label(item.name, { TextSize = 20, LayoutOrder = 1, Parent = details })
		UI.label(item.description, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextColor3 = UI.Colors.Text,
			LayoutOrder = 2,
			Parent = details,
		})
		UI.label(statsText(item), {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 3,
			Parent = details,
		})

		local text, color, action, lockedBecause = buttonFor(profile, item, category)
		if lockedBecause then
			UI.label(lockedBecause, {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 14,
				TextColor3 = UI.Colors.Money,
				LayoutOrder = 4,
				Parent = details,
			})
		end
		UI.button(text, function()
			if action then
				act(action, item, category)
			end
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 36),
			BackgroundColor3 = color,
			TextColor3 = if color == UI.Colors.Money then UI.Colors.Background else UI.Colors.Text,
			TextScaled = true,
			Parent = card,
		})
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
	local title = window:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = app.title
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
		Size = UDim2.new(1, 0, 0, 40),
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
		tabButtons[category] = UI.button(name, function()
			selectedCategory = category
			confirmingSell = nil
			render()
		end, {
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			TextSize = 16,
			Parent = tabs,
		})
		UI.padding(8).Parent = tabButtons[category]
	end

	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
	})

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
