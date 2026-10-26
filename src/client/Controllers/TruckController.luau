-- The "Truck" menu: a checklist of your tools (each with its picture: what it's for, how much room
-- it takes, what shape it's in with a glyph for each part, and whether it's in the truck, in your
-- hands or in storage) next to the customer's to-do list. It never says which tool a job needs, or
-- which supply fixes a tool. Loading happens by hand (see CarryController); "Grab" here picks a
-- tool out of storage for you when you're standing at it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Deliveries = require(Shared.Deliveries)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local Art = require(script.Parent.Parent.Art)
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

		local card = UI.card({
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = list,
		}, if loaded or inHands then "Selected" else nil)
		-- The tool's picture on the left, when it's uploaded (its frame keeps the card that tall).
		local image = Art.item(item.id)
		local left = 0
		if image ~= "" then
			local holder =
				UI.new("Frame", { Size = UDim2.fromOffset(80, 80), BackgroundTransparency = 1, Parent = card })
			UI.picture(image, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(64, 64), Parent = holder })
			left = 72
		end
		local details = UI.new("Frame", {
			Position = UDim2.fromOffset(left, 0),
			Size = UDim2.new(1, -150 - left, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(2), UI.padding(8) })
		UI.heading(item.name, { TextSize = 19, LayoutOrder = 1, Parent = details })
		UI.label(item.description, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 14,
			FontFace = UI.Fonts.Body,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 2,
			Parent = details,
		})
		UI.label(`{Items.CategoryInfo[item.category].toolName}  ·  {spaceText(item)}`, {
			TextSize = 14,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 3,
			Parent = details,
		})
		-- What shape it's in: fuel, tires, blade and line ("Tire looks soft"), or a supply's uses.
		local condition = profile.condition and profile.condition[item.id] or {}
		UI.conditionRow(Maintenance.parts(item, condition), { LayoutOrder = 4, Parent = details })

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
				Style = if inHands then "Neutral" else "Primary",
				Icon = if inHands then "PutBack" else "PickUp",
				IconSize = 18,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 40),
				Size = UDim2.fromOffset(124, 40),
				TextSize = 16,
				Parent = card,
			})
		end
	end
end

function TruckController:Start()
	local content
	window, content = UI.panel("Truck", "Your Truck")
	summary = UI.heading("", { TextSize = 20, Parent = content })
	hint = UI.label("", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		FontFace = UI.Fonts.Medium,
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
