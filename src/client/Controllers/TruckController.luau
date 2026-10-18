-- The "Truck" menu: a checklist of your tools (what each is for, and whether it's in the truck,
-- in your hands or on the rack) next to the customer's to-do list. It never says which tool a
-- job needs. Loading happens by hand (see CarryController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local TruckController = {}

local window: Frame
local summary: TextLabel
local hint: TextLabel
local list: ScrollingFrame

-- In a crew everyone shares the leader's truck, so the server tells us the crew totals.
local function truckSpace(profile): (number, number)
	local party = ClientState.party
	if party and #party.members > 1 and party.truckCapacity then
		return party.truckUsed, party.truckCapacity
	end
	return Items.countLoaded(profile.loadout), profile.bedCapacity
end

local function render()
	UI.clearList(list)
	local profile = ClientState.profile
	if not profile then
		return
	end

	local used, capacity = truckSpace(profile)
	local party = ClientState.party
	local owner = if party and party.leader ~= player then `{party.leader.DisplayName}'s truck` else "Your truck"
	summary.Text = `{owner}: {used}/{capacity} tools loaded`

	local job = ClientState.job
	if job and job.todo then
		hint.Text = `The customer wants: {table.concat(job.todo, "; ")}.`
	elseif not profile.trailerUnlocked then
		hint.Text = "Fill the truck bed to unlock trailers at the hardware store."
	elseif not profile.equipped.Trailer then
		hint.Text = "Trailers are unlocked! Buy one at the hardware store for more room."
	else
		hint.Text = "Carry tools from the rack to the truck. Only tools in the truck come with you."
	end

	for index, category in Items.ToolCategories do
		local info = Items.CategoryInfo[category]
		local itemId = profile.equipped[category]
		local item = itemId and Items.get(category, itemId)
		local loaded = profile.loadout[category] == true
		local held = player:GetAttribute("Carrying") == category

		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })
		local text = UI.new("Frame", {
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(2), UI.padding(8) })
		UI.label(if item then item.name else info.toolName, { TextSize = 19, LayoutOrder = 1, Parent = text })
		UI.label(if item then item.description else "None yet. Buy one at the hardware store.", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 2,
			Parent = text,
		})

		if item then
			UI.label(if loaded then "In the truck" elseif held then "In your hands" else "On the rack", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 10),
				Size = UDim2.fromOffset(130, 24),
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if loaded then UI.Colors.Accent elseif held then UI.Colors.Money else UI.Colors.SubText,
				Parent = card,
			})
		end
	end
end

function TruckController:Start()
	local content
	window, content = UI.panel("Truck", "Your Truck")
	summary = UI.label("", { TextSize = 20, Parent = content })
	hint = UI.label("", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.Colors.SubText,
		Parent = content,
	})
	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70),
	})

	ClientState.Changed:Connect(function(key)
		if (key == "profile" or key == "party" or key == "job") and window.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
end

return TruckController
