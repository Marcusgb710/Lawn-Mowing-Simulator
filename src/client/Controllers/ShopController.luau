-- Two apps on the shop computer (see ComputerController), one tab per category:
--   Orders    tools and supplies (delivered in a box to the shop), yard decorations for your
--             crew's business, and a Sell tab for tools you don't need, to free up storage
--   Business  building upgrades, trucks and trailers
-- Every tool says what it's for: that's how players learn which tool fits which job.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Decorations = require(Shared.Config.Decorations)
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Shop = require(Shared.Shop)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

-- Selling takes a second tap within this many seconds, so it can't happen by accident.
local SELL_CONFIRM_TIME = 3

local ShopController = {}

local SELL_TAB = "Sell"
local DECOR_TAB = "Decorations"
-- Which tabs each app shows.
local APPS = {
	Orders = { title = "Orders", tabs = table.clone(Items.ToolCategories) },
	Business = { title = "Business", tabs = { "Business", "Truck", "Trailer" } },
}
table.insert(APPS.Orders.tabs, DECOR_TAB)
table.insert(APPS.Orders.tabs, SELL_TAB)

local window: Frame
local selectedCategory = Items.Categories[1]
local tabButtons = {}
local list: ScrollingFrame
-- The tool id waiting for a second tap to sell, and when the first tap was.
local confirmingSell: string? = nil
local confirmingSince = 0

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
	local _, message = Net.func(action):InvokeServer(category, item.id)
	UI.notify(message)
end

-- What the button on an item's card says and does, plus why it's locked (if it is).
local function buttonFor(profile, item, category: string): (string, Color3, string?, string?)
	if category == DECOR_TAB then
		local affordable = profile.money >= item.price
		return Format.money(item.price), if affordable then UI.Colors.Money else UI.Colors.Disabled, "BuyItem", nil
	end
	local owned = profile.owned[category] and profile.owned[category][item.id]
	if Items.isToolCategory(category) then
		if owned then
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
	if not allowed then
		return "Locked", UI.Colors.Disabled, nil, reason
	end
	local affordable = profile.money >= item.price
	return Format.money(item.price), if affordable then UI.Colors.Money else UI.Colors.Disabled, "BuyItem", nil
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
		items = Decorations.List
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
