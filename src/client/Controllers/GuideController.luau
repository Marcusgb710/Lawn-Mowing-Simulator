-- The "Guide" menu: what every tool in the store is for, by shop tab. Jobs never say which tool
-- to bring, so this is where players look things up (the same text as in the shop). It also has
-- the switch for camera motion (head bob and engine shake).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)

local GuideController = {}

local selectedCategory = Items.ToolCategories[1]
local tabButtons = {}
local list: ScrollingFrame

local function render()
	for category, button in tabButtons do
		button.BackgroundColor3 = if category == selectedCategory then UI.Colors.Accent else UI.Colors.Card
	end
	UI.clearList(list)
	local profile = ClientState.profile

	if CameraController.hasMotion() then
		local motion = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 44),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = -1,
			Parent = list,
		}, { UI.corner(8) })
		UI.label("Camera motion (head bob, engine shake)", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -120, 1, 0),
			TextSize = 15,
			TextWrapped = true,
			Parent = motion,
		})
		local on = CameraController.isMotionOn()
		-- MotionChanged redraws the Guide.
		UI.button(if on then "On" else "Off", function()
			CameraController.setMotion(not CameraController.isMotionOn())
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(90, 30),
			BackgroundColor3 = if on then UI.Colors.Accent else UI.Colors.Disabled,
			Parent = motion,
		})
	end

	UI.label("Jobs never say which tool to use. Here's what each one is for.", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 15,
		TextColor3 = UI.Colors.Money,
		LayoutOrder = 0,
		Parent = list,
	})
	for index, item in Items.Catalog[selectedCategory] do
		local owned = profile and profile.owned[selectedCategory] and profile.owned[selectedCategory][item.id]
		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8), UI.list(3), UI.padding(10) })
		UI.label(if owned then `{item.name}  (yours)` else item.name, { TextSize = 19, LayoutOrder = 1, Parent = card })
		UI.label(item.description, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			LayoutOrder = 2,
			Parent = card,
		})
		local size = Tools.SizeClasses[item.sizeClass]
		local spot = string.lower(Storage.Spots[size.spot].name)
		UI.label(`{item.tier}  ·  {size.label}, stored on a {spot}`, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 3,
			Parent = card,
		})
	end
end

function GuideController:Start()
	local window, content = UI.panel("Guide", "Tool Guide")
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
	for index, category in Items.ToolCategories do
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
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	CameraController.MotionChanged:Connect(function()
		if window.Visible then
			render()
		end
	end)
end

return GuideController
