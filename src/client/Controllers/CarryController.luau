-- Carrying tools by hand at your business.
--
-- Your own tools are laid out in your crew's business storage (only on your screen, so crew
-- members each see their own): hand tools hang on pegboards, long tools stand in wall racks,
-- power tools hang on hooks, supplies sit on shelves and machines park on floor spots and in
-- equipment bays (see BusinessStorage on the server). Each tool goes in the spot you last put it
-- in (profile.spots), or the first free one of its kind; anything without a free spot sits on
-- the ground nearby. Hand tools in your tool bucket are in the bucket, not on the wall.
-- Every tool can be taken by looking at it, and every free spot has an invisible marker you can
-- look at to put something back (see InteractController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Deliveries = require(Shared.Deliveries)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

-- Tools without a storage spot go in rows on the ground this wide.
local OVERFLOW_ROW_LENGTH = 18
local OVERFLOW_ROW_GAP = 4

local CarryController = {}

-- The storage (and its spots, which can stream in later) that's drawn right now.
local shownStorage: Instance? = nil
local shownSpots: Instance? = nil
local storageFolder: Folder? = nil
local carryLabel: TextLabel

local function carrying(): string?
	return player:GetAttribute("Carrying")
end

-- The Storage folder at your crew leader's business.
function CarryController.findStorage(): Folder?
	local business = ClientState.crewBusiness()
	local storage = business and business:FindFirstChild("Storage")
	return if storage and storage:IsA("Folder") then storage else nil
end

-- What putting a tool back in each kind of spot is called.
local PUT_BACK_TEXT = {
	Pegboard = "Hang up",
	WallHooks = "Hang up",
	WallRack = "Put in rack",
	Shelf = "Put on shelf",
	Floor = "Set down",
	Bay = "Park",
}

-- Every storage spot, by kind, in order.
local function spotsByKind(storage: Folder)
	local byKind = {}
	local holder = storage:FindFirstChild("Spots")
	if not holder then
		return byKind
	end
	for _, attachment in holder:GetChildren() do
		local kind = attachment:GetAttribute("Spot")
		if attachment:IsA("Attachment") and kind then
			byKind[kind] = byKind[kind] or {}
			table.insert(byKind[kind], attachment)
		end
	end
	for _, list in byKind do
		table.sort(list, function(a, b)
			return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
		end)
	end
	return byKind
end

-- [free-spot marker part] = the spot it's over
local markerSpots = setmetatable({}, { __mode = "k" })

-- The spot a free-spot marker (see marker below) is over.
function CarryController.spotOfMarker(part: Instance): Attachment?
	return markerSpots[part]
end

-- One storage spot of your crew's business, by kind and Index.
function CarryController.spot(kind: string, index: number): Attachment?
	local storage = CarryController.findStorage()
	for _, attachment in if storage then spotsByKind(storage)[kind] or {} else {} do
		if attachment:GetAttribute("Index") == index then
			return attachment
		end
	end
	return nil
end

function CarryController.floorY(): number
	local storage = CarryController.findStorage()
	return storage and storage:GetAttribute("FloorY") or 0
end

-- Puts a tool in its spot: hung on a pegboard or hook, stood up in a wall rack, or placed on a
-- shelf or the floor.
function CarryController.placeInSpot(display: Model, spot: Attachment, floorY: number)
	local frame = spot.WorldCFrame
	local mount = spot:GetAttribute("Mount")
	if mount == "Place" then
		Assets.placeOnGround(display, frame)
		return
	end
	-- On the wall: longest side straight up. A tool hung on a pegboard lies flat against it;
	-- in a rack or on a hook it hangs edge-on, so the tools next to it have room.
	local flat = mount == "Hang"
	local long, middle, thin =
		Assets.align(display, frame.Position, frame.UpVector, if flat then frame.LookVector else frame.RightVector)
	local sticksOut = if flat then thin else middle
	local depth = spot:GetAttribute("Depth") or 0
	-- Keep it clear of the wall, and never below the floor.
	local out = math.max(depth, sticksOut / 2 + 0.05) - depth
	local y = if mount == "Stand" then floorY + long / 2 else frame.Position.Y - long / 2
	y = math.max(y, floorY + long / 2)
	local center = Vector3.new(frame.Position.X, y, frame.Position.Z) + frame.LookVector * out
	display:PivotTo(display:GetPivot() + (center - frame.Position))
end

-- An invisible part over a free spot, to look at to put a tool back there.
local function marker(folder: Folder, spot: Attachment)
	local kind = spot:GetAttribute("Spot")
	local mount = spot:GetAttribute("Mount")
	local frame = spot.WorldCFrame
	local part = Instance.new("Part")
	part.Name = "FreeSpot"
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	if kind == "Floor" or kind == "Bay" then
		part.Size = if kind == "Bay" then Vector3.new(5, 1, 7) else Vector3.new(3, 1.2, 4)
		part.CFrame = frame * CFrame.new(0, part.Size.Y / 2, 0)
	elseif mount == "Place" then
		part.Size = Vector3.new(1.4, 1.2, 1.4)
		part.CFrame = frame * CFrame.new(0, 0.6, 0)
	else
		-- Tools hang (or stand) below their slot.
		part.Size = Vector3.new(1.2, 2.4, 1.2)
		part.CFrame = frame * CFrame.new(0, -1, -0.4)
	end
	part:SetAttribute("Interact", "PutBack")
	part:SetAttribute("InteractText", PUT_BACK_TEXT[kind] or "Put back")
	part:SetAttribute("SpotKind", kind)
	part:SetAttribute("SpotIndex", spot:GetAttribute("Index"))
	part:SetAttribute("ManualOnly", spot:GetAttribute("ManualOnly"))
	part.Parent = folder
	markerSpots[part] = spot
	return part
end

-- Rebuilds your tools in storage: everything you own that isn't in the truck or your hands.
local function renderStorage()
	if storageFolder then
		storageFolder:Destroy()
		storageFolder = nil
	end
	local storage = CarryController.findStorage()
	shownStorage = storage
	shownSpots = storage and storage:FindFirstChild("Spots")
	local profile = ClientState.profile
	if not storage or not profile then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "MyStorage"
	local floorY = storage:GetAttribute("FloorY") or 0
	local spots = spotsByKind(storage)
	local taken = {}
	local overflowAttachment = storage:FindFirstChild("Overflow", true)
	local overflowFrame = if overflowAttachment and overflowAttachment:IsA("Attachment")
		then overflowAttachment.WorldCFrame
		else nil
	local overflowX, overflowRow = 0, 0
	local held = carrying()
	local chosen = profile.spots or {}
	local inBucket = profile.bucket or {}
	local function fits(candidate: Attachment, item): boolean
		return not taken[candidate] and not (candidate:GetAttribute("ManualOnly") and item.sizeClass == "FloorEngine")
	end

	-- Every tool keeps a spot, even while it's in the truck, in your hands or in the bucket, so
	-- storage doesn't shuffle around: first the spots you picked, then the first free ones.
	local tools = Items.ownedTools(profile.owned)
	local spotOf = {}
	for _, item in tools do
		for _, candidate in spots[Storage.spotOf(item)] or {} do
			if candidate:GetAttribute("Index") == chosen[item.id] and fits(candidate, item) then
				spotOf[item.id] = candidate
				taken[candidate] = true
				break
			end
		end
	end
	for _, item in tools do
		if spotOf[item.id] then
			continue
		end
		for _, candidate in spots[Storage.spotOf(item)] or {} do
			if fits(candidate, item) then
				spotOf[item.id] = candidate
				taken[candidate] = true
				break
			end
		end
	end

	for _, item in tools do
		local spot: Attachment? = spotOf[item.id]
		-- In the truck, in the bucket or still in its delivery box: not on the wall.
		if profile.loadout[item.id] or inBucket[item.id] or Deliveries.pending(profile.deliveries, item.id) then
			continue
		end
		if held == item.id then
			-- In your hands: its spot is free to put it back in.
			if spot then
				taken[spot] = nil
			end
			continue
		end

		local display = Assets.toolDisplay(item.category, item.id)
		Assets.anchor(display)
		if spot then
			CarryController.placeInSpot(display, spot, floorY)
		elseif overflowFrame then
			-- No spot for it here: keep it on the ground, in rows.
			local _, size = display:GetBoundingBox()
			local width = math.max(size.X, size.Z)
			if overflowX > 0 and overflowX + width > OVERFLOW_ROW_LENGTH then
				overflowX, overflowRow = 0, overflowRow + 1
			end
			Assets.placeOnGround(
				display,
				overflowFrame * CFrame.new(overflowX + width / 2, 0, -overflowRow * OVERFLOW_ROW_GAP)
			)
			overflowX += width + 0.6
		else
			display:Destroy()
			continue
		end

		display:SetAttribute("Interact", "PickUp")
		display:SetAttribute("InteractText", if item.ride then "Get on" else "Take")
		display:SetAttribute("InteractName", item.name)
		display:SetAttribute("ToolId", item.id)
		if item.id == Storage.BucketId then
			local count = 0
			for _ in inBucket do
				count += 1
			end
			display:SetAttribute("BucketCount", count)
		end
		display.Parent = folder
	end

	-- Free spots, to put things back in.
	for _, list in spots do
		for _, spot in list do
			if not taken[spot] then
				marker(folder, spot)
			end
		end
	end
	folder.Parent = workspace
	storageFolder = folder
end

local function updateCarryLabel()
	local held = carrying()
	local tool = held and Tools.get(held)
	carryLabel.Visible = tool ~= nil
	if tool then
		carryLabel.Text = if tool.sizeClass == "Bay"
			then `Driving your {tool.name}. Park it on a trailer bay, or back in its bay.`
			else `Carrying your {tool.name}. Look at the truck bed to load it, or at a free spot to put it back.`
	end
end

function CarryController.pickUp(toolId: string)
	local _, message = Net.func("PickUpTool"):InvokeServer(toolId)
	UI.notify(message)
end

-- Puts what you're carrying back where it was.
function CarryController.putBack()
	local _, message = Net.func("PutBackTool"):InvokeServer()
	UI.notify(message)
end

function CarryController:Start()
	carryLabel = UI.label("", {
		Name = "CarryHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.new(0.9, 0, 0, 34),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = UI.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = 16,
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.corner(8).Parent = carryLabel
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge), Parent = carryLabel })

	-- Several changes come together (a load changes what you carry and your profile), so they
	-- redraw storage once.
	local queued = false
	local function queueRender()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				renderStorage()
			end)
		end
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		updateCarryLabel()
		queueRender()
	end)
	ClientState.Changed:Connect(function(key)
		if key == "profile" or key == "party" then
			queueRender()
		end
	end)

	-- Storage can appear later (streaming in, or the business getting rebuilt after an upgrade).
	task.spawn(function()
		while true do
			task.wait(1)
			local storage = CarryController.findStorage()
			if storage ~= shownStorage or (storage and storage:FindFirstChild("Spots")) ~= shownSpots then
				renderStorage()
			end
		end
	end)
end

return CarryController
