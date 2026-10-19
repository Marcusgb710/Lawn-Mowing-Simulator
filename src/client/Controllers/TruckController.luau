-- The "Truck" menu: a checklist of your tools (what each is for, how much room it takes, what
-- shape it's in, and whether it's in the truck, in your hands or in storage) next to the
-- customer's to-do list. It never says which tool a job needs, or which supply fixes a tool. Loading happens by hand (see CarryController); "Grab" here
-- picks a tool out of storage for you when you're standing at it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Deliveries = require(Shared.Deliveries)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local CarryController = require(script.Parent.CarryController)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local TruckController = {}

local window: Frame
local summary: TextLabel
local hint: TextLabel
local list: ScrollingFrame

-- In a crew everyone shares the leader's truck, so the server tells us the crew totals.
local function truckSpace(profile)
	local party = ClientState.party
	if party and #party.members > 1 and party.truck then
		return party.truck
	end
	return profile.truck
end

local function spaceText(item): string
	if item.sizeClass == "Bay" then
		return "Trailer bay"
	elseif item.id == Storage.BucketId then
		return `1 space, holds {Storage.BucketHolds} hand tools`
	end
	local space = Tools.SizeClasses[item.sizeClass].space
	return if space == 1 then "1 space" else `{space} space`
end

-- What shape a tool is in, in words ("Tire looks soft"), and whether that's a problem.
local function conditionText(item, condition): (string, boolean)
	local warnings = Maintenance.warnings(item, condition or {})
	if #warnings > 0 then
		return table.concat(warnings, "  ·  "), true
	end
	local supply = Maintenance.Supplies[item.id]
	if supply and supply.uses and condition and condition.uses then
		return `{condition.uses} of {supply.uses} left`, false
	end
	return "In good shape", false
end

local function render()
	UI.clearList(list)
	local profile = ClientState.profile
	if not profile then
		return
	end

	local truck = truckSpace(profile)
	local party = ClientState.party
	local owner = if party and party.leader ~= player then `{party.leader.DisplayName}'s truck` else "Your truck"
	local text = `{owner}: {truck.used}/{truck.space} space`
	if truck.bays > 0 or truck.baysUsed > 0 then
		text ..= `  ·  ride-on bays {truck.baysUsed}/{truck.bays}`
	end
	summary.Text = text

	local job = ClientState.job
	if job and job.todo then
		hint.Text = `The customer wants: {table.concat(job.todo, "; ")}.`
	elseif not profile.trailerUnlocked then
		hint.Text =
			"Fill the truck to unlock trailers (in Business, on the shop computer). A tool bucket packs hand tools tight."
	elseif not profile.equipped.Trailer then
		hint.Text = "Trailers are unlocked! Order one in Business, on the shop computer, for more room."
	else
		hint.Text = "Carry tools from storage to the truck. Only tools in the truck come with you."
	end

	local held = player:GetAttribute("Carrying")
	for index, item in Items.ownedTools(profile.owned) do
		local loaded = profile.loadout[item.id] == true
		local inHands = held == item.id
		local inBucket = profile.bucket ~= nil and profile.bucket[item.id] == true
		local boxed = Deliveries.pending(profile.deliveries, item.id)

		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })
		local details = UI.new("Frame", {
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(2), UI.padding(8) })
		UI.label(item.name, { TextSize = 19, LayoutOrder = 1, Parent = details })
		UI.label(item.description, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 2,
			Parent = details,
		})
		UI.label(`{Items.CategoryInfo[item.category].toolName}  ·  {spaceText(item)}`, {
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 3,
			Parent = details,
		})
		local shape, worn = conditionText(item, profile.condition and profile.condition[item.id])
		UI.label(shape, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			TextColor3 = if worn then UI.Colors.Money else UI.Colors.Accent,
			LayoutOrder = 4,
			Parent = details,
		})

		local servicing = Players.LocalPlayer:GetAttribute("Servicing") == item.id
		local where = if boxed
			then "In its delivery box"
			elseif servicing then "At the workbench"
			elseif inBucket and loaded then "In the bucket, in the truck"
			elseif inBucket then "In the tool bucket"
			elseif loaded then "In the truck"
			elseif inHands then "In your hands"
			else "In storage"
		UI.label(where, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(130, 24),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if loaded then UI.Colors.Accent elseif inHands then UI.Colors.Money else UI.Colors.SubText,
			Parent = card,
		})
		-- Pegboards get crowded, so you can also grab a tool from here while standing at storage.
		local atBusiness = job == nil or job.state == "Ready"
		if atBusiness and not loaded and not inBucket and not boxed and not servicing and (held == nil or inHands) then
			UI.button(if inHands then "Put back" else "Grab", function()
				if inHands then
					CarryController.putBack()
				else
					CarryController.pickUp(item.id)
				end
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 40),
				Size = UDim2.fromOffset(110, 32),
				TextSize = 16,
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
	player:GetAttributeChangedSignal("Servicing"):Connect(function()
		if window.Visible then
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
