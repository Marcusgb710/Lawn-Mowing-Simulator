-- The hardware store: one tab per category. Buy tools, trucks, trailers and business upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local ShopController = {}

local selectedCategory = Items.Categories[1]
local tabButtons = {}
local list: ScrollingFrame

local function statsText(item): string
	if item.category == "Truck" then
		return `Job pay +{math.floor(item.payoutBonus * 100)}%  ·  Holds {item.bedSlots} tools`
	elseif item.category == "Trailer" then
		return `+{item.extraSlots} truck bed slots`
	elseif item.category == "Business" then
		return `Job pay +{math.floor(item.payoutBonus * 100)}%`
	end
	local parts = { `Power {item.power}`, `Reach {item.radius}` }
	if item.walkSpeed then
		table.insert(parts, `Speed {item.walkSpeed}`)
	end
	if item.motorized == false then
		table.insert(parts, "No motor")
	end
	return table.concat(parts, "  ·  ")
end

local function render()
	for category, button in tabButtons do
		button.BackgroundColor3 = if category == selectedCategory then UI.Colors.Accent else UI.Colors.Card
	end

	UI.clearList(list)
	local profile = ClientState.profile
	if not profile then
		return
	end
	if selectedCategory == "Trailer" and not profile.trailerUnlocked then
		UI.label("Fill up your truck bed to unlock trailers.", {
			TextColor3 = UI.Colors.Money,
			LayoutOrder = 0,
			Parent = list,
		})
	end

	for index, item in Items.Catalog[selectedCategory] do
		local owned = profile.owned[selectedCategory] and profile.owned[selectedCategory][item.id]
		local equipped = profile.equipped[selectedCategory] == item.id

		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 76),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })

		UI.label(item.name, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -150, 0, 22),
			TextSize = 20,
			Parent = card,
		})
		UI.label(item.description, {
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -150, 0, 18),
			TextSize = 15,
			TextColor3 = UI.Colors.SubText,
			Parent = card,
		})
		UI.label(statsText(item), {
			Position = UDim2.fromOffset(12, 52),
			Size = UDim2.new(1, -150, 0, 16),
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			Parent = card,
		})

		local text, color, action
		local previous = Items.Catalog[selectedCategory][item.tier - 1]
		local locked = (selectedCategory == "Trailer" and not profile.trailerUnlocked)
			or (selectedCategory == "Business" and previous and not profile.owned.Business[previous.id])
		if equipped then
			text, color = if selectedCategory == "Business" then "Current" else "Equipped", UI.Colors.Disabled
		elseif owned then
			if selectedCategory == "Business" then
				text, color = "Owned", UI.Colors.Disabled
			else
				text, color, action = "Equip", UI.Colors.Accent, "EquipItem"
			end
		elseif locked then
			text, color = "Locked", UI.Colors.Disabled
		else
			local affordable = profile.money >= item.price
			text = Format.money(item.price)
			color = if affordable then UI.Colors.Money else UI.Colors.Disabled
			action = "BuyItem"
		end

		UI.button(text, function()
			if action then
				local _, message = Net.func(action):InvokeServer(selectedCategory, item.id)
				UI.notify(message)
			end
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 36),
			BackgroundColor3 = color,
			TextColor3 = if color == UI.Colors.Money then UI.Colors.Background else UI.Colors.Text,
			Parent = card,
		})
	end
end

function ShopController:Start()
	local window, content = UI.panel("Shop", "Hardware Store")

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

	for index, category in Items.Categories do
		tabButtons[category] = UI.button(Items.CategoryInfo[category].displayName, function()
			selectedCategory = category
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
