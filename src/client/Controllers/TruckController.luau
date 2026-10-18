-- The "Truck" menu: a checklist of what's in the truck, what's on the rack and what the job needs.
-- Loading happens by hand (see CarryController); only tools in the truck come along on a job.

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
	if job and job.tools then
		local names = {}
		for _, category in job.tools do
			table.insert(names, Items.CategoryInfo[category].toolName)
		end
		hint.Text = `This job needs: {table.concat(names, ", ")}. Carry them from the rack to the truck.`
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
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })
		UI.label(info.toolName, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 22),
			TextSize = 20,
			Parent = card,
		})
		UI.label(if item then item.name else "Not owned yet. Buy one at the hardware store.", {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -150, 0, 18),
			TextSize = 15,
			TextColor3 = UI.Colors.SubText,
			Parent = card,
		})

		if item then
			UI.label(if loaded then "In the truck" elseif held then "In your hands" else "On the rack", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
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
		TextSize = 15,
		TextColor3 = UI.Colors.SubText,
		Parent = content,
	})
	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
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
