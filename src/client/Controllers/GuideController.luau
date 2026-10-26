-- The "Guide" menu: what every tool in the store is for, by shop tab. Jobs never say which tool
-- to bring, so this is where players look things up (the same text as in the shop). It also has
-- the switch for camera motion (head bob and engine shake).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)

local GuideController = {}

local selectedCategory = Items.ToolCategories[1]
local tabButtons = {}
local list: ScrollingFrame

local function render()
	for category, button in tabButtons do
		UI.setTab(button, category == selectedCategory)
	end
	UI.clearList(list)
	local profile = ClientState.profile

	if CameraController.hasMotion() then
		local motion = UI.card({
			Size = UDim2.new(1, -8, 0, 52),
			LayoutOrder = -1,
			Parent = list,
		})
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
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(90, 36),
			Style = if on then "Primary" else "Disabled",
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
		local card = UI.card({
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = list,
		})
		-- The item's picture on the left, when it's uploaded (its frame keeps the card that tall).
		local image = Art.item(item.id)
		local picture = if image ~= ""
			then UI.new("Frame", { Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, Parent = card })
			else nil
		if picture then
			UI.picture(
				image,
				{ Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(64, 64), Parent = picture }
			)
		end
		local words = UI.new("Frame", {
			Position = UDim2.fromOffset(if picture then 74 else 0, 0),
			Size = UDim2.new(1, if picture then -74 else 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(3), UI.padding(10) })
		UI.heading(
			if owned then `{item.name}  (yours)` else item.name,
			{ TextSize = 19, LayoutOrder = 1, Parent = words }
		)
		if item.tier then
			UI.tierBadge(item.tier, { LayoutOrder = 2, Parent = words })
		end
		UI.label(item.description, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			FontFace = UI.Fonts.Body,
			LayoutOrder = 3,
			Parent = words,
		})
		local size = Tools.SizeClasses[item.sizeClass]
		local spot = string.lower(Storage.Spots[size.spot].name)
		UI.label(`{size.label}, stored on a {spot}`, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 4,
			Parent = words,
		})
	end
end

function GuideController:Start()
	local window, content = UI.panel("Guide", "Tool Guide")
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
	for index, category in Items.ToolCategories do
		tabButtons[category] = UI.tab(Items.CategoryInfo[category].displayName, `Cat_{category}`, function()
			selectedCategory = category
			render()
		end, { LayoutOrder = index, Parent = tabs })
	end
	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
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
