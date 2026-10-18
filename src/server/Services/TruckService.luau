-- Carrying tools between storage and the crew truck.
--
-- At your business your tools sit in storage (each player only sees their own, see
-- CarryController). Pick one up, carry it to the truck and load it. Push and ride-on machines
-- are rolled along the ground in front of you instead of carried. Loaded tools lie in the truck
-- where the whole crew can see them, and only the owner can take theirs back out.
-- A crew rides in the leader's truck, so everyone's tools share its space (Storage.load) and its
-- trailer's ride-on bays.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

-- Carrying a tool slows you down a little.
local CARRY_WALK_SPEED = 12
-- Where the hand-hold point of a carried tool sits, relative to the HumanoidRootPart.
local CARRY_OFFSET = CFrame.new(0.6, 0.3, -1.4)
-- Machines you push or drive are rolled along the ground in front of you, this far ahead.
local PUSH_GAP = 1.2
local PUSHED = { FloorManual = true, FloorEngine = true, Bay = true }
-- Machines that stand up in the truck bed instead of lying across it.
local STANDING = { FloorManual = true, FloorEngine = true }
-- Seconds between carry requests from one player, so they can't be spammed.
local COOLDOWN = 0.25

local TruckService = {}

-- [Player] = the tool model they're carrying
local carried = {}
-- [Player] = when they last picked up, put back, loaded or unloaded something
local lastRequest = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function ownedTool(data, toolId)
	local tool = typeof(toolId) == "string" and Tools.get(toolId)
	local item = tool and Items.get(tool.category, toolId)
	return if item and data.owned[item.category] and data.owned[item.category][toolId] then item else nil
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

-- Puts a machine on the ground just in front of the player, facing the way they face.
local function rollInFront(model: Model, root: BasePart, humanoid: Humanoid?)
	local legs = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local floor = root.Position - Vector3.new(0, root.Size.Y / 2 + legs, 0)
	Assets.placeOnGround(model, CFrame.new(floor) * root.CFrame.Rotation)
	-- Move it forward until its back end is just ahead of the player.
	local box, size = model:GetBoundingBox()
	local back = root.CFrame:PointToObjectSpace(box.Position).Z + math.max(size.X, size.Z) / 2
	model:PivotTo(model:GetPivot() + root.CFrame.LookVector * (back + PUSH_GAP))
end

local function startCarrying(player: Player, item): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end

	local model = Assets.toolDisplay(item.category, item.id)
	local primary = model.PrimaryPart
	if not primary then
		model:Destroy()
		return false
	end
	model.Name = "CarriedTool"
	local humanoid = getHumanoid(player)
	if PUSHED[item.sizeClass] then
		rollInFront(model, root, humanoid)
	else
		model:PivotTo(root.CFrame * CARRY_OFFSET)
	end
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
	player:SetAttribute("Carrying", item.id)
	if humanoid then
		humanoid.WalkSpeed = CARRY_WALK_SPEED
	end
	return true
end

-- Where loaded things go in a truck and its trailer: "BedArea" parts for tools, each holding
-- its share of its vehicle's space, and "BaySpot" parts (on equipment trailers) for ride-on machines.
local function cargoAreas(truck: Model, truckSpace: number, trailerSpace: number)
	local trailer = truck:FindFirstChild("Trailer")
	local truckBeds, trailerBeds, bays = {}, {}, {}
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.Name == "BaySpot" then
				table.insert(bays, descendant)
			elseif descendant.Name == "BedArea" then
				table.insert(
					if trailer and descendant:IsDescendantOf(trailer) then trailerBeds else truckBeds,
					descendant
				)
			end
		end
	end
	local lanes = {}
	for _, group in { { beds = truckBeds, space = truckSpace }, { beds = trailerBeds, space = trailerSpace } } do
		for _, bed in group.beds do
			table.insert(lanes, { part = bed, space = group.space / #group.beds, items = {}, used = 0 })
		end
	end
	return lanes, bays
end

local function takeOutPrompt(display: Model, member: Player, item)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take Out"
	prompt.ObjectText = `{member.DisplayName}'s {item.name}`
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", "UnloadTool")
	prompt:SetAttribute("OnlyFor", member.UserId)
	prompt:SetAttribute("ToolId", item.id)
	prompt.Parent = display.PrimaryPart or display:FindFirstChildWhichIsA("BasePart", true)
end

-- Shows every loaded tool in the truck parked at `owner`'s business.
local function renderBed(owner: Player)
	local truck = WorldService:GetPlotTruck(owner)
	local ownerData = DataService:Get(owner)
	if not (truck and ownerData) then
		return
	end
	local old = truck:FindFirstChild("BedItems")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BedItems"

	local truckItem = Items.get("Truck", ownerData.equipped.Truck) or Items.Catalog.Truck[1]
	local trailerItem = ownerData.equipped.Trailer and Items.get("Trailer", ownerData.equipped.Trailer)
	local lanes, bays = cargoAreas(truck, truckItem.space, if trailerItem then trailerItem.space else 0)

	-- If the owner rides in someone else's crew, their own truck stays empty.
	local party = PartyService:GetParty(owner)
	local members = if not party then { owner } elseif party.leader == owner then party.members else {}
	local piled = 0
	local function pile(display: Model)
		piled += 1
		-- Anything that doesn't fit (crews can overfill the truck) gets piled on top.
		Assets.placeOnGround(display, truck:GetPivot() * CFrame.new(0, 4 + piled, 0))
	end

	local bayIndex = 0
	local lane = 1
	for _, member in members do
		local data = DataService:Get(member)
		if not data then
			continue
		end
		for _, id in Storage.loadedIds(data.loadout) do
			local item = ownedTool(data, id)
			if not item then
				continue
			end
			local display = Assets.toolDisplay(item.category, id)
			Assets.anchor(display)
			display.Parent = folder
			takeOutPrompt(display, member, item)

			if item.sizeClass == "Bay" then
				bayIndex += 1
				local spot = bays[bayIndex]
				if spot then
					Assets.placeOnGround(display, spot.CFrame * CFrame.new(0, spot.Size.Y / 2, 0))
				else
					pile(display)
				end
				continue
			end
			-- Each tool takes a stretch of a bed as long as its truck space (bucketed hand tools too).
			local units = math.max(1, Storage.spaceOf(item))
			while lanes[lane + 1] and lanes[lane].used + units > lanes[lane].space do
				lane += 1
			end
			local current = lanes[lane]
			if not current then
				pile(display)
				continue
			end
			table.insert(current.items, { display = display, item = item, units = units })
			current.used += units
		end
	end

	for _, current in lanes do
		local bed: BasePart = current.part
		local unit = bed.Size.Z / math.max(current.space, current.used, 1)
		local cursor = -bed.Size.Z / 2
		for _, entry in current.items do
			local length = entry.units * unit
			local top = bed.CFrame * CFrame.new(0, bed.Size.Y / 2, cursor + length / 2)
			cursor += length
			if STANDING[entry.item.sizeClass] then
				Assets.placeOnGround(entry.display, top)
			else
				-- Lay it flat across the bed.
				local up = top.UpVector
				local _, _, thin = Assets.align(entry.display, top.Position, top.RightVector, up)
				entry.display:PivotTo(entry.display:GetPivot() + up * (thin / 2))
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

-- Trailers unlock for the truck's owner (the crew leader) the first time its truck fills up.
local function unlockTrailers(player: Player)
	local party = PartyService:GetParty(player)
	local owner = if party then party.leader else player
	local ownerData = DataService:Get(owner)
	if ownerData and not ownerData.trailerUnlocked then
		ownerData.trailerUnlocked = true
		DataService:Changed(owner)
		notify(owner, "Your truck is full! Trailers are now unlocked at the hardware store.")
	end
end

-- How much more truck space and how many more bays a tool takes if this player loads it.
-- (A tool bucket makes the hand tools it carries free, so it can even be negative.)
local function extraLoad(data, toolId: string): (number, number)
	local ids = Storage.loadedIds(data.loadout)
	local space, bays = Storage.load(ids)
	table.insert(ids, toolId)
	local newSpace, newBays = Storage.load(ids)
	return newSpace - space, newBays - bays
end

-- Public API ---------------------------------------------------------------------------------

function TruckService:PickUp(player: Player, toolId: string): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	local item = data and ownedTool(data, toolId)
	if not item then
		return false, "You don't own one of those yet."
	end
	if carried[player] then
		return false, "Your hands are full."
	end
	if data.loadout[item.id] then
		return false, "That's already in the truck."
	end
	if Maintenance.isStationary(item.id) then
		return false, `The {item.name} stays in the building.`
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end
	if not WorldService:IsNearStorage(player) then
		return false, "Get closer to your storage."
	end
	if not startCarrying(player, item) then
		return false, "You can't pick that up right now."
	end
	return true, `Take the {item.name} to the truck.`
end

function TruckService:PutBack(player: Player): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local toolId = player:GetAttribute("Carrying")
	local item = toolId and Tools.get(toolId)
	if not item then
		return false, "You're not carrying anything."
	end
	if not WorldService:IsNearStorage(player) then
		return false, "Get closer to your storage."
	end
	stopCarrying(player)
	return true, `Put the {item.name} back.`
end

-- Loads whatever the player is carrying into the truck that `truckOwnerId` parked.
function TruckService:Load(player: Player, truckOwnerId: number)
	local data = DataService:Get(player)
	local item = data and ownedTool(data, player:GetAttribute("Carrying"))
	local party = PartyService:GetParty(player)
	local leader = if party then party.leader else player
	if not item then
		notify(player, "Grab a tool from your storage first.")
		return
	end
	if truckOwnerId ~= leader.UserId then
		notify(player, "That's not your crew's truck.")
		return
	end
	if JobService:IsBusy(player) then
		return
	end

	local used, capacity, baysUsed, bays = PartyService:GetTruckLoad(player)
	local extraSpace, extraBays = extraLoad(data, item.id)
	if extraBays > 0 and baysUsed + extraBays > bays then
		if bays == 0 then
			notify(player, "Ride-on machines only fit on an equipment trailer with a ramp.")
			unlockTrailers(player)
		else
			notify(player, "The equipment trailer's bays are full.")
		end
		return
	end
	-- Something that takes no extra room (a ride-on, or a bucket that packs hand tools) always fits.
	if extraSpace > 0 and used + extraSpace > capacity then
		notify(player, "That won't fit. Take something out or hitch up a trailer.")
		unlockTrailers(player)
		return
	end

	data.loadout[item.id] = true
	stopCarrying(player)
	if used + extraSpace >= capacity then
		unlockTrailers(player)
	end
	DataService:Changed(player)
	PartyService:Refresh(player)
	notify(player, `{item.name} loaded into the truck.`)
end

-- Takes one of the player's own tools out of the truck and puts it in their hands.
function TruckService:Unload(player: Player, ownerId: number, toolId: string)
	local data = DataService:Get(player)
	if ownerId ~= player.UserId then
		notify(player, "That's someone else's tool.")
		return
	end
	local item = data and ownedTool(data, toolId)
	if not item or not data.loadout[item.id] or JobService:IsBusy(player) then
		return
	end
	if carried[player] then
		notify(player, "Your hands are full. Load or put back what you're carrying first.")
		return
	end
	if item.id == Storage.BucketId then
		-- Without the bucket its hand tools take a space each again.
		local used, capacity = PartyService:GetTruckLoad(player)
		local ids = Storage.loadedIds(data.loadout)
		local withBucket = Storage.load(ids)
		table.remove(ids, table.find(ids, item.id))
		local withoutBucket = Storage.load(ids)
		if used + withoutBucket - withBucket > capacity then
			notify(player, "There's no room for the loose hand tools. Take some out of the bucket first.")
			return
		end
	end

	data.loadout[item.id] = nil
	startCarrying(player, item)
	DataService:Changed(player)
	PartyService:Refresh(player)
end

-- Call after a player's tools or vehicles change (buying, selling, swapping trucks): rebuilds
-- the truck bed and drops a carried tool they don't own anymore.
function TruckService:GearChanged(player: Player)
	local data = DataService:Get(player)
	if player:GetAttribute("Carrying") and not (data and ownedTool(data, player:GetAttribute("Carrying"))) then
		stopCarrying(player)
	end
	local party = PartyService:GetParty(player)
	renderBed(if party then party.leader else player)
end

function TruckService:IsCarrying(player: Player, toolId: string): boolean
	return player:GetAttribute("Carrying") == toolId
end

-- Lifecycle ----------------------------------------------------------------------------------

function TruckService:Init()
	Net.func("PickUpTool").OnServerInvoke = function(player, toolId)
		return self:PickUp(player, toolId)
	end
	Net.func("PutBackTool").OnServerInvoke = function(player)
		return self:PutBack(player)
	end
end

function TruckService:Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		if (action == "LoadTool" or action == "UnloadTool") and tooSoon(player) then
			return
		end
		if action == "LoadTool" then
			self:Load(player, prompt:GetAttribute("OwnerUserId"))
		elseif action == "UnloadTool" then
			self:Unload(player, prompt:GetAttribute("OnlyFor"), prompt:GetAttribute("ToolId"))
		end
	end)

	-- Crew changes move tools between trucks, and rebuilt plots need their truck refilled.
	PartyService.Changed:Connect(renderCrew)
	WorldService.PlotBuilt:Connect(renderBed)

	-- Heading out on a job (or dying) puts whatever you were carrying back in storage.
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
		lastRequest[player] = nil
	end)
end

return TruckService
