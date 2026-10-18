-- Carrying tools between storage and the crew truck (docs/GAME_DESIGN.md, "Immersion").
--
-- At your business your tools sit in storage (each player only sees their own, see
-- CarryController). You look at one and take it into your hands, carry it to the truck and look
-- at the bed to set it down. The bed is a grid of cells (BedGrid): the client says which cells,
-- and the server checks you're holding the tool, you're at your crew's truck and it fits there.
-- A tool you use is in your hands as the real thing, held the way it is on a job, so it works on
-- your own lawn (see HomeLawnService); putting it away in the hotbar puts it back in storage.
-- Ride-on machines are driven: you get on, drive up the equipment trailer's ramp and park on a
-- bay. Supplies and gloves are just carried, and the tow-behind attachment is rolled along in
-- front of you. Hand tools can be dropped in the tool bucket, which then carries them all in one
-- cell. Putting a tool back works the same way: look at a free spot of its kind in storage.
--
-- Loaded tools lie in the truck where the whole crew can see them, and only the owner can take
-- theirs back out. A crew rides in the leader's truck, so everyone's tools share its cells and
-- its trailer's bays. Where each tool lies is kept for the session; tools loaded before (or that
-- don't fit where they were any more) go in the first free cells.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local BedGrid = require(Shared.BedGrid)
local BedLayout = require(Shared.BedLayout)
local Deliveries = require(Shared.Deliveries)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local ToolService = require(script.Parent.ToolService)
local WorldService = require(script.Parent.WorldService)

-- Carrying a tool slows you down a little.
local CARRY_WALK_SPEED = 12
-- Where the hand-hold point of a carried tool sits, relative to the HumanoidRootPart.
local CARRY_OFFSET = CFrame.new(0.6, 0.3, -1.4)
-- Machines that are just carried, not used (the tow-behind attachment), are rolled along the
-- ground in front of you, this far ahead.
local PUSH_GAP = 1.2
local PUSHED = { FloorManual = true, FloorEngine = true, Bay = true }
-- Seconds between carry requests from one player, so they can't be spammed.
local COOLDOWN = 0.25
-- How close to the truck (its bounding box) you need to be to load or unload it.
local TRUCK_REACH = 8
-- How close (across the ground) a ride-on has to be to a bay to park on it.
local PARK_REACH = 6
-- A tool set down in the bed drops this far onto its cells, over this many seconds.
local SETTLE_DROP = 1
local SETTLE_TIME = 0.25

local TruckService = {}

-- [Player] = the tool model they're carrying, or the ride-on Tool they're driving
local carried = {}
-- [Player] = when they last picked up, put back, loaded or unloaded something
local lastRequest = {}
-- [Player] = { [toolId] = { bed = number, anchor = number } }: where their loaded tools lie
local placements = {}
-- [truck owner] = { beds = { BedLayout.Bed }, taken = { [bed] = { [cell] = true } }, bays = { BasePart }, baysTaken = { [BasePart] = true } }
local layouts = {}
-- [Player] = the tool they just set down, so it settles into place instead of appearing there
local settling = {}

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

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function ownedTool(data, toolId)
	local tool = typeof(toolId) == "string" and Tools.get(toolId)
	local item = tool and Items.get(tool.category, toolId)
	return if item and data.owned[item.category] and data.owned[item.category][toolId] then item else nil
end

local function leaderOf(player: Player): Player
	local party = PartyService:GetParty(player)
	return if party then party.leader else player
end

-- Carrying a tool, or placing a decoration (see DecorService).
local function handsFull(player: Player): boolean
	return carried[player] ~= nil or player:GetAttribute("PlacingDecor") ~= nil
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
		-- Off a ride-on: back down to the ground.
		ToolService:ResetRider(player)
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
	local root = rootOf(player)
	if not (character and root) then
		return false
	end

	-- Tools you use come out as the real thing, so they work on your own lawn: ride-ons to drive,
	-- the rest in your hands. Supplies, gloves and the tow-behind attachment are just carried.
	if ToolService.isHeld(item) then
		local tool = ToolService:GiveHeld(player, item.id)
		if not tool then
			return false
		end
		carried[player] = tool
		player:SetAttribute("Carrying", item.id)
		local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
		if handle and handle:IsA("BasePart") then
			Sounds.play(handle, "Pickup")
		end
		-- Putting it away in the hotbar puts it back in storage; anything else taking it away
		-- (a crew change, a respawn) does the same, quietly.
		tool.Unequipped:Connect(function()
			if carried[player] == tool then
				stopCarrying(player)
				notify(
					player,
					if item.ride then `You leave the {item.name} in its bay.` else `You put the {item.name} back.`
				)
			end
		end)
		tool.Destroying:Connect(function()
			if carried[player] == tool then
				stopCarrying(player)
			end
		end)
		return true
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
	Sounds.play(primary, "Pickup")

	carried[player] = model
	player:SetAttribute("Carrying", item.id)
	if humanoid then
		humanoid.WalkSpeed = CARRY_WALK_SPEED
	end
	return true
end

-- The look-at attributes InteractController uses (see there).
local function interactable(target: Instance, action: string, text: string, name: string)
	target:SetAttribute("Interact", action)
	target:SetAttribute("InteractText", text)
	target:SetAttribute("InteractName", name)
end

-- Drops a display a little onto where it was placed.
local function settle(display: Model)
	local resting = display:GetPivot()
	local value = Instance.new("CFrameValue")
	value.Value = resting + Vector3.new(0, SETTLE_DROP, 0)
	display:PivotTo(value.Value)
	local connection = value.Changed:Connect(function(frame)
		if display.Parent then
			display:PivotTo(frame)
		end
	end)
	local tween =
		TweenService:Create(value, TweenInfo.new(SETTLE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Value = resting,
		})
	tween.Completed:Once(function()
		connection:Disconnect()
		value:Destroy()
		if display.PrimaryPart then
			Sounds.play(display.PrimaryPart, "Thunk")
		end
	end)
	tween:Play()
end

-- Shows every loaded tool in the truck parked at `owner`'s business, and remembers which cells
-- and bays are taken.
local function renderBed(owner: Player)
	local truck = WorldService:GetPlotTruck(owner)
	local ownerData = DataService:Get(owner)
	if not (truck and ownerData) then
		layouts[owner] = nil
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
	local beds = BedLayout.beds(truck, truckItem.space, if trailerItem then trailerItem.space else 0)
	local taken = {}
	for index in beds do
		taken[index] = {}
	end
	local bays = {}
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "BaySpot" then
			table.insert(bays, descendant)
		end
	end
	local baysTaken = {}
	local layout = { beds = beds, taken = taken, bays = bays, baysTaken = baysTaken }
	layouts[owner] = layout

	-- If the owner rides in someone else's crew, their own truck stays empty.
	local party = PartyService:GetParty(owner)
	local members = if not party then { owner } elseif party.leader == owner then party.members else {}
	local piled = 0
	local function pile(display: Model)
		piled += 1
		-- Anything that doesn't fit (crews can overfill the truck) gets piled on top.
		Assets.placeOnGround(display, truck:GetPivot() * CFrame.new(0, 4 + piled, 0))
	end
	local function claim(bed: number, cells: { number })
		for _, cell in cells do
			taken[bed][cell] = true
		end
	end

	-- Tools keep the cells they were put in while those are still free; the rest go in the first
	-- free cells.
	local pending = {}
	for _, member in members do
		local data = DataService:Get(member)
		if not data then
			continue
		end
		placements[member] = placements[member] or {}
		local bucketLoaded = data.loadout[Storage.BucketId] ~= nil
		for _, id in Storage.loadedIds(data.loadout) do
			local item = ownedTool(data, id)
			-- Hand tools in the bucket ride inside it.
			if not item or (bucketLoaded and data.bucket[id]) then
				continue
			end
			local display = Assets.toolDisplay(item.category, id)
			Assets.anchor(display)
			display.Parent = folder
			interactable(display, "Unload", "Take", item.name)
			display:SetAttribute("OnlyFor", member.UserId)
			display:SetAttribute("ToolId", id)
			if id == Storage.BucketId then
				display:SetAttribute("BucketCount", Storage.bucketCount(data.bucket))
			end
			local entry = { member = member, item = item, display = display }

			if item.sizeClass == "Bay" then
				local spot
				for _, candidate in bays do
					if not baysTaken[candidate] then
						spot = candidate
						break
					end
				end
				if spot then
					baysTaken[spot] = true
					Assets.placeOnGround(display, spot.CFrame * CFrame.new(0, spot.Size.Y / 2, 0))
				else
					pile(display)
				end
				continue
			end
			local place = placements[member][id]
			local bed = place and beds[place.bed]
			local cells = bed and BedGrid.cells(bed.grid, item.sizeClass, place.anchor)
			if bed and cells and BedGrid.free(taken[bed.index], cells) then
				claim(bed.index, cells)
				BedLayout.place(display, bed, cells, item.sizeClass)
			else
				table.insert(pending, entry)
			end
		end
	end
	for _, entry in pending do
		local placed = false
		for _, bed in beds do
			local anchor = BedGrid.firstFit(bed.grid, taken[bed.index], entry.item.sizeClass)
			local cells = anchor and BedGrid.cells(bed.grid, entry.item.sizeClass, anchor)
			if anchor and cells then
				claim(bed.index, cells)
				placements[entry.member][entry.item.id] = { bed = bed.index, anchor = anchor }
				BedLayout.place(entry.display, bed, cells, entry.item.sizeClass)
				placed = true
				break
			end
		end
		if not placed then
			pile(entry.display)
		end
	end

	-- What the client needs to preview a tool in the bed.
	for _, bed in beds do
		local list = {}
		for cell in taken[bed.index] do
			table.insert(list, cell)
		end
		bed.part:SetAttribute("BedIndex", bed.index)
		bed.part:SetAttribute("Cells", bed.grid.cells)
		bed.part:SetAttribute("Taken", table.concat(list, ","))
	end
	for index, spot in bays do
		spot:SetAttribute("BayIndex", index)
		spot:SetAttribute("Taken", baysTaken[spot] == true)
	end

	folder.Parent = truck
	for _, member in members do
		local justPlaced = settling[member]
		settling[member] = nil
		for _, display in folder:GetChildren() do
			if
				display:IsA("Model")
				and display:GetAttribute("OnlyFor") == member.UserId
				and display:GetAttribute("ToolId") == justPlaced
			then
				settle(display)
			end
		end
	end
end

local function renderCrew(party)
	for _, member in party.members do
		renderBed(member)
	end
end

-- Re-shows their menus and the truck their crew rides in (the crew refresh redraws its bed).
local function refresh(player: Player)
	DataService:Changed(player)
	if PartyService:GetParty(player) then
		PartyService:Refresh(player)
	else
		renderBed(player)
	end
end

-- Trailers unlock for the truck's owner (the crew leader) the first time its truck fills up.
local function unlockTrailers(player: Player)
	local owner = leaderOf(player)
	local ownerData = DataService:Get(owner)
	if ownerData and not ownerData.trailerUnlocked then
		ownerData.trailerUnlocked = true
		DataService:Changed(owner)
		notify(owner, "Your truck is full! Trailers are now unlocked at the hardware store.")
	end
end

-- The crew's truck, if the player is standing at it.
local function truckInReach(player: Player): Model?
	local truck = WorldService:GetPlotTruck(leaderOf(player))
	return if truck and WorldService:IsNear(player, truck, TRUCK_REACH) then truck else nil
end

-- The storage spot attachments of one kind at the crew's business, by Index.
local function spotsOf(player: Player, kind: string): { [number]: Attachment }
	local spots = {}
	local storage = WorldService:GetCrewStorage(player)
	local holder = storage and storage:FindFirstChild("Spots")
	if holder then
		for _, attachment in holder:GetChildren() do
			local index = attachment:GetAttribute("Index")
			if
				attachment:IsA("Attachment")
				and attachment:GetAttribute("Spot") == kind
				and typeof(index) == "number"
			then
				spots[index] = attachment
			end
		end
	end
	return spots
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
	if handsFull(player) then
		return false, "Your hands are full."
	end
	if data.loadout[item.id] then
		return false, "That's already in the truck."
	end
	if data.bucket[item.id] then
		return false, "That's in your tool bucket."
	end
	if Deliveries.pending(data.deliveries, item.id) then
		return false, "That's still in its box."
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
	if item.sizeClass == "Bay" then
		return true, `Take the {item.name} up the trailer's ramp and park it on a bay.`
	end
	return true, `Take the {item.name} to the truck.`
end

-- Puts a tool straight into the player's hands, as it comes out of its delivery box (the caller
-- checks they can take it).
function TruckService:Hand(player: Player, toolId: string): boolean
	local data = DataService:Get(player)
	local item = data and ownedTool(data, toolId)
	if not item or handsFull(player) or Maintenance.isStationary(item.id) then
		return false
	end
	return startCarrying(player, item)
end

function TruckService:IsCarryingAnything(player: Player): boolean
	return handsFull(player)
end

-- Puts what you're carrying back in storage: in spot `index` of its kind if you say which (and
-- it's free), otherwise wherever it was.
function TruckService:PutBack(player: Player, index: number?): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	local item = data and ownedTool(data, player:GetAttribute("Carrying"))
	if not item then
		return false, "You're not carrying anything."
	end
	if not WorldService:IsNearStorage(player) then
		return false, "Get closer to your storage."
	end
	local kind = Storage.spotOf(item)
	if typeof(index) == "number" then
		local spot = spotsOf(player, kind)[index]
		if not spot then
			return false, "That's not a spot for it."
		end
		if spot:GetAttribute("ManualOnly") and item.sizeClass == "FloorEngine" then
			return false, "No engines in here."
		end
		-- Whatever of yours was assigned there moves to the first free spot instead.
		for otherId, otherIndex in data.spots do
			local other = Tools.get(otherId)
			if otherId ~= item.id and otherIndex == index and other and Storage.spotOf(other) == kind then
				data.spots[otherId] = nil
			end
		end
		data.spots[item.id] = index
	end
	stopCarrying(player)
	DataService:Changed(player)
	return true, `Put the {item.name} back.`
end

-- Sets what the player is carrying down in their crew's truck, on cells starting at `anchor`
-- of bed `bed` (as the client aimed), or in the first free cells if they didn't say.
function TruckService:Load(player: Player, bed: number?, anchor: number?): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	local item = data and ownedTool(data, player:GetAttribute("Carrying"))
	if not item then
		return false, "Grab a tool from your storage first."
	end
	if Maintenance.isStationary(item.id) then
		return false, `The {item.name} stays in the building.`
	end
	if item.sizeClass == "Bay" then
		return false, "Take it up the trailer's ramp and park it on a bay."
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end
	if not truckInReach(player) then
		return false, "Get closer to your crew's truck."
	end

	local leader = leaderOf(player)
	if not layouts[leader] then
		renderBed(leader)
	end
	local layout = layouts[leader]
	if not layout or #layout.beds == 0 then
		return false, "There's no room in that truck."
	end
	local target, at
	if bed ~= nil or anchor ~= nil then
		-- Where they aimed: it has to be a real bed and whole cells that are free.
		local chosen = if typeof(bed) == "number" then layout.beds[bed] else nil
		local cells = chosen and typeof(anchor) == "number" and BedGrid.cells(chosen.grid, item.sizeClass, anchor)
		if not (chosen and cells and BedGrid.free(layout.taken[chosen.index], cells)) then
			return false, "That won't fit there."
		end
		target, at = chosen, anchor :: number
	else
		-- No place given: the first one that fits.
		for _, candidate in layout.beds do
			local first = BedGrid.firstFit(candidate.grid, layout.taken[candidate.index], item.sizeClass)
			if first then
				target, at = candidate, first
				break
			end
		end
		if not (target and at) then
			unlockTrailers(player)
			return false, "That won't fit. Take something out or hitch up a trailer."
		end
	end

	placements[player] = placements[player] or {}
	placements[player][item.id] = { bed = target.index, anchor = at }
	data.loadout[item.id] = true
	DataService.reconcileStorage(data)
	settling[player] = item.id
	stopCarrying(player)
	if not BedGrid.firstFit(target.grid, layout.taken[target.index], "Hand") then
		unlockTrailers(player)
	end
	refresh(player)
	return true, `{item.name} loaded into the truck.`
end

-- Takes one of the player's own tools out of the truck and puts it in their hands (on a
-- ride-on, in the seat).
function TruckService:Unload(player: Player, toolId: string): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	local item = data and ownedTool(data, toolId)
	if not item or not data.loadout[item.id] or data.bucket[item.id] then
		return false, "That's not yours to take."
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end
	if handsFull(player) then
		return false, "Your hands are full. Load or put back what you're carrying first."
	end
	if not truckInReach(player) then
		return false, "Get closer to the truck."
	end

	data.loadout[item.id] = nil
	-- The bucket's hand tools come out with it.
	DataService.reconcileStorage(data)
	if placements[player] then
		placements[player][item.id] = nil
	end
	if not startCarrying(player, item) then
		data.loadout[item.id] = true
		DataService.reconcileStorage(data)
		return false, "You can't take that right now."
	end
	refresh(player)
	return true, `Took the {item.name} out.`
end

-- Drops the hand tool you're carrying into your tool bucket, wherever it is: in the truck or in
-- storage.
function TruckService:PutInBucket(player: Player): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	local item = data and ownedTool(data, player:GetAttribute("Carrying"))
	if not item or item.sizeClass ~= "Hand" then
		return false, "Only hand tools go in the bucket."
	end
	if not ownedTool(data, Storage.BucketId) then
		return false, "You don't have a tool bucket."
	end
	if Storage.bucketCount(data.bucket) >= Storage.BucketHolds then
		return false, "The bucket's full."
	end
	local inTruck = data.loadout[Storage.BucketId] ~= nil
	if inTruck and not truckInReach(player) then
		return false, "Get closer to the truck."
	elseif not inTruck and not WorldService:IsNearStorage(player) then
		return false, "Get closer to your storage."
	end
	data.bucket[item.id] = true
	DataService.reconcileStorage(data)
	stopCarrying(player)
	refresh(player)
	return true, `Dropped the {item.name} in the bucket.`
end

-- Takes a hand tool out of your tool bucket (the first one, in shop order) into your hands.
function TruckService:TakeFromBucket(player: Player): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	if not data or handsFull(player) then
		return false, "Your hands are full."
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end
	local inTruck = data.loadout[Storage.BucketId] ~= nil
	if inTruck and not truckInReach(player) then
		return false, "Get closer to the truck."
	elseif not inTruck and not WorldService:IsNearStorage(player) then
		return false, "Get closer to your storage."
	end
	local item
	for _, tool in Items.ownedTools(data.owned) do
		if data.bucket[tool.id] then
			item = tool
			break
		end
	end
	if not item then
		return false, "The bucket's empty."
	end
	data.bucket[item.id] = nil
	data.loadout[item.id] = nil
	if not startCarrying(player, item) then
		data.bucket[item.id] = true
		DataService.reconcileStorage(data)
		return false, "You can't take that right now."
	end
	refresh(player)
	return true, `Took the {item.name} out of the bucket.`
end

-- Parks the ride-on you're driving: on a free bay of your crew's equipment trailer (loading it),
-- or back on an equipment bay in storage.
function TruckService:Park(player: Player): (boolean, string)
	if tooSoon(player) then
		return false, "One thing at a time."
	end
	local data = DataService:Get(player)
	local item = data and ownedTool(data, player:GetAttribute("Carrying"))
	local root = rootOf(player)
	if not (item and item.sizeClass == "Bay" and root) then
		return false, "You've nothing to park."
	end
	local function across(position: Vector3): number
		local offset = position - root.Position
		return Vector2.new(offset.X, offset.Z).Magnitude
	end

	-- A free bay on the trailer.
	local leader = leaderOf(player)
	if not layouts[leader] then
		renderBed(leader)
	end
	local layout = layouts[leader]
	if layout and not JobService:IsBusy(player) then
		for _, spot in layout.bays do
			if not layout.baysTaken[spot] and across(spot.Position) <= PARK_REACH then
				data.loadout[item.id] = true
				stopCarrying(player)
				refresh(player)
				return true, `Parked the {item.name} on the trailer.`
			end
		end
	end

	-- Back in a bay in storage.
	for index, spot in spotsOf(player, "Bay") do
		if across(spot.WorldPosition) <= PARK_REACH then
			data.spots[item.id] = index
			stopCarrying(player)
			DataService:Changed(player)
			return true, `Parked the {item.name} back in its bay.`
		end
	end
	if layout and #layout.bays == 0 then
		unlockTrailers(player)
		return false, "Ride-on machines only travel on an equipment trailer with a ramp."
	end
	return false, "Drive onto a free bay to park it."
end

-- Call after a player's tools or vehicles change (buying, selling, swapping trucks): rebuilds
-- the truck bed and drops a carried tool they don't own anymore.
function TruckService:GearChanged(player: Player)
	local data = DataService:Get(player)
	if data then
		-- A sold tool leaves its spot and the bucket (and a sold bucket empties out).
		DataService.reconcileStorage(data)
	end
	if player:GetAttribute("Carrying") and not (data and ownedTool(data, player:GetAttribute("Carrying"))) then
		stopCarrying(player)
	end
	renderBed(leaderOf(player))
end

function TruckService:IsCarrying(player: Player, toolId: string): boolean
	return player:GetAttribute("Carrying") == toolId
end

-- Lifecycle ----------------------------------------------------------------------------------

function TruckService:Init()
	Net.func("PickUpTool").OnServerInvoke = function(player, toolId)
		return self:PickUp(player, toolId)
	end
	Net.func("PutBackTool").OnServerInvoke = function(player, index)
		return self:PutBack(player, if typeof(index) == "number" then index else nil)
	end
	Net.func("LoadTool").OnServerInvoke = function(player, bed, anchor)
		return self:Load(
			player,
			if typeof(bed) == "number" then bed else nil,
			if typeof(anchor) == "number" then anchor else nil
		)
	end
	Net.func("UnloadTool").OnServerInvoke = function(player, toolId)
		return self:Unload(player, toolId)
	end
	Net.func("PutInBucket").OnServerInvoke = function(player)
		return self:PutInBucket(player)
	end
	Net.func("TakeFromBucket").OnServerInvoke = function(player)
		return self:TakeFromBucket(player)
	end
	Net.func("ParkRide").OnServerInvoke = function(player)
		return self:Park(player)
	end
end

function TruckService:Start()
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
		placements[player] = nil
		layouts[player] = nil
		settling[player] = nil
	end)
end

return TruckService
