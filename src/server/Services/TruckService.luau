-- Carrying tools between the tool rack and the crew truck.
--
-- At your business your tools sit in front of the tool rack (each player only sees their own,
-- see CarryController). Pick one up, carry it to the truck and load it. Loaded tools lie in the
-- truck bed where the whole crew can see them, and only the owner can take theirs back out.
-- A crew rides in the leader's truck, so everyone's tools go in that one bed.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

-- Carrying a tool slows you down a little.
local CARRY_WALK_SPEED = 12
-- Where the hand-hold point of a carried tool sits, relative to the HumanoidRootPart.
local CARRY_OFFSET = CFrame.new(0.6, 0.3, -1.4)

local TruckService = {}

-- [Player] = the tool model they're carrying
local carried = {}

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function isTool(category): boolean
	return typeof(category) == "string" and table.find(Items.ToolCategories, category) ~= nil
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function toolName(category: string): string
	return Items.CategoryInfo[category].toolName
end

local function stopCarrying(player: Player)
	local model = carried[player]
	carried[player] = nil
	if model then
		model:Destroy()
	end
	if player:GetAttribute("Carrying") ~= nil then
		player:SetAttribute("Carrying", nil)
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		end
	end
end

local function startCarrying(player: Player, category: string): boolean
	local data = DataService:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local itemId = data and data.equipped[category]
	if not (itemId and root and root:IsA("BasePart")) then
		return false
	end

	local model = Assets.toolDisplay(category, itemId)
	local primary = model.PrimaryPart
	if not primary then
		model:Destroy()
		return false
	end
	model.Name = "CarriedTool"
	model:PivotTo(root.CFrame * CARRY_OFFSET)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = if descendant == primary then root else primary
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = character

	carried[player] = model
	player:SetAttribute("Carrying", category)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = CARRY_WALK_SPEED
	end
	return true
end

-- Spots in a truck (and its trailer) where loaded tools lie, from "BedArea" parts.
local function bedSlots(truck: Model): { CFrame }
	local slots = {}
	for _, area in truck:GetDescendants() do
		if area:IsA("BasePart") and area.Name == "BedArea" then
			local count = area:GetAttribute("Slots") or 1
			for index = 1, count do
				local z = area.Size.Z * ((index - 0.5) / count - 0.5)
				-- Lay tools across the bed.
				table.insert(slots, area.CFrame * CFrame.new(0, area.Size.Y / 2, z) * CFrame.Angles(0, math.pi / 2, 0))
			end
		end
	end
	return slots
end

-- Shows every loaded tool in the truck parked at `owner`'s business.
local function renderBed(owner: Player)
	local truck = WorldService:GetPlotTruck(owner)
	if not truck then
		return
	end
	local old = truck:FindFirstChild("BedItems")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BedItems"

	-- If the owner rides in someone else's crew, their own truck stays empty.
	local party = PartyService:GetParty(owner)
	local members = if not party then { owner } elseif party.leader == owner then party.members else {}
	local slots = bedSlots(truck)
	local count = 0
	for _, member in members do
		local data = DataService:Get(member)
		for _, category in Items.ToolCategories do
			if data and data.loadout[category] and data.equipped[category] then
				count += 1
				-- Anything that doesn't fit (crews can overfill the truck) gets piled on top.
				local slot = slots[count] or (truck:GetPivot() * CFrame.new(0, 4 + count, 0))
				local display = Assets.toolDisplay(category, data.equipped[category])
				Assets.anchor(display)
				Assets.placeOnGround(display, slot)
				display.Parent = folder

				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Take Out"
				prompt.ObjectText = `{member.DisplayName}'s {toolName(category)}`
				prompt.KeyboardKeyCode = Enum.KeyCode.R
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt:SetAttribute("Action", "UnloadTool")
				prompt:SetAttribute("OnlyFor", member.UserId)
				prompt:SetAttribute("Category", category)
				prompt.Parent = display.PrimaryPart or display:FindFirstChildWhichIsA("BasePart", true)
			end
		end
	end
	folder.Parent = truck
end

local function renderCrew(party)
	for _, member in party.members do
		renderBed(member)
	end
end

-- Trailers unlock for the truck's owner (the crew leader) the first time its bed fills up.
local function checkTrailerUnlock(player: Player)
	local used, capacity = PartyService:GetTruckLoad(player)
	local party = PartyService:GetParty(player)
	local owner = if party then party.leader else player
	local ownerData = DataService:Get(owner)
	if ownerData and not ownerData.trailerUnlocked and used >= capacity then
		ownerData.trailerUnlocked = true
		DataService:Changed(owner)
		notify(owner, "Your truck bed is full! Trailers are now unlocked at the hardware store.")
	end
end

-- Public API ---------------------------------------------------------------------------------

function TruckService:PickUp(player: Player, category: string): (boolean, string)
	local data = DataService:Get(player)
	if not data or not isTool(category) or not data.equipped[category] then
		return false, "You don't own one of those yet."
	end
	if carried[player] then
		return false, "Your hands are full."
	end
	if data.loadout[category] then
		return false, "That's already in the truck."
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end
	if not WorldService:IsNearRack(player) then
		return false, "Get closer to the tool rack."
	end
	if not startCarrying(player, category) then
		return false, "You can't pick that up right now."
	end
	return true, `Carry the {toolName(category)} to the truck.`
end

function TruckService:PutBack(player: Player): (boolean, string)
	local category = player:GetAttribute("Carrying")
	if not category then
		return false, "You're not carrying anything."
	end
	if not WorldService:IsNearRack(player) then
		return false, "Get closer to the tool rack."
	end
	stopCarrying(player)
	return true, `Put the {toolName(category)} back on the rack.`
end

-- Loads whatever the player is carrying into the truck that `truckOwnerId` parked.
function TruckService:Load(player: Player, truckOwnerId: number)
	local category = player:GetAttribute("Carrying")
	local data = DataService:Get(player)
	local party = PartyService:GetParty(player)
	local leader = if party then party.leader else player
	if not category or not data then
		notify(player, "Grab a tool from the tool rack first.")
		return
	end
	if truckOwnerId ~= leader.UserId then
		notify(player, "That's not your crew's truck.")
		return
	end
	if JobService:IsBusy(player) then
		return
	end
	local used, capacity = PartyService:GetTruckLoad(player)
	if used >= capacity then
		notify(player, "The truck bed is full. Put something back or hitch up a trailer.")
		return
	end

	data.loadout[category] = true
	stopCarrying(player)
	checkTrailerUnlock(player)
	DataService:Changed(player)
	PartyService:Refresh(player)
	notify(player, `{toolName(category)} loaded into the truck.`)
end

-- Takes one of the player's own tools out of the truck and puts it in their hands.
function TruckService:Unload(player: Player, ownerId: number, category: string)
	local data = DataService:Get(player)
	if ownerId ~= player.UserId then
		notify(player, "That's someone else's tool.")
		return
	end
	if not data or not isTool(category) or not data.loadout[category] or JobService:IsBusy(player) then
		return
	end
	if carried[player] then
		notify(player, "Your hands are full. Load or put back what you're carrying first.")
		return
	end

	data.loadout[category] = nil
	startCarrying(player, category)
	DataService:Changed(player)
	PartyService:Refresh(player)
end

-- Call after a player buys or equips gear: rebuilds the truck bed and drops a carried tool
-- that just got swapped for a different one.
function TruckService:GearChanged(player: Player, category: string)
	if player:GetAttribute("Carrying") == category then
		stopCarrying(player)
	end
	local party = PartyService:GetParty(player)
	renderBed(if party then party.leader else player)
end

-- Lifecycle ----------------------------------------------------------------------------------

function TruckService:Init()
	Net.func("PickUpTool").OnServerInvoke = function(player, category)
		return self:PickUp(player, category)
	end
	Net.func("PutBackTool").OnServerInvoke = function(player)
		return self:PutBack(player)
	end
end

function TruckService:Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		if action == "LoadTool" then
			self:Load(player, prompt:GetAttribute("OwnerUserId"))
		elseif action == "UnloadTool" then
			self:Unload(player, prompt:GetAttribute("OnlyFor"), prompt:GetAttribute("Category"))
		end
	end)

	-- Crew changes move tools between trucks, and rebuilt plots need their truck refilled.
	PartyService.Changed:Connect(renderCrew)
	WorldService.PlotBuilt:Connect(renderBed)

	-- Heading out on a job (or dying) puts whatever you were carrying back on the rack.
	JobService.PlayerStateChanged:Connect(stopCarrying)

	local function onPlayerAdded(player: Player)
		player.CharacterRemoving:Connect(function()
			stopCarrying(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		carried[player] = nil
	end)
end

return TruckService
