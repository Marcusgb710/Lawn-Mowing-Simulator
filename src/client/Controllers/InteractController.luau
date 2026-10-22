-- Using things by looking at them (docs/GAME_DESIGN.md, "Immersion"): aim the dot in the middle
-- of the screen at something within reach and press E, or tap the big button on a phone.
-- Anything with an `Interact` attribute (on the part you look at, or a model it's in) can be used:
--   OpenPanel    opens the menu named in OpensPanel
--   SetDown      sets the tool you're holding down to work on it (SpotKind "Floor" or "Vise"),
--                at a workbench or by the truck on a job; see MaintenanceService
--   ServiceTool  your tool set down: hold a supply and hold E to use it on it (R for the
--                building's own machines), or pick it back up
--   TakeSupply   one of the supplies you brought, by the tailgate on a job; the truck takes it back
--   UseComputer  sits you down at the shop computer (see ComputerController)
--   OpenBox      opens one of your delivery boxes (BoxKey, OnlyFor), or one of your crew's
--                decoration boxes (BoxKind "Decor", ForCrew)
--   MoveDecor    picks up one of your crew's yard decorations to move it (DecorOwner, DecorKey;
--                R opens the mailbox), see DecorController
--   DriveToJob   heads off in the crew truck
--   PickUpDebris picks up junk hidden in a lawn's grass, whatever's in your hands (see
--                Config/Debris.luau)
--   Talk         talks to Grandma June on her porch (see DialogueController)
--   PickUp       takes one of your tools out of storage (ToolId)
--   PutBack      puts what you're carrying back in this free spot (SpotKind, SpotIndex)
--   Unload       takes one of your tools back out of the truck (ToolId, OnlyFor)
-- While you carry a tool, looking at your crew's truck bed shows a ghost of it on the cells under
-- the dot (red if it won't fit), and E sets it down there; looking at a free spot shows it there.
-- Looking at your tool bucket drops a hand tool in, or with empty hands R takes one back out.
-- Driving a ride-on, E parks it on the trailer bay (or storage bay) you're on.
-- The client only says what you want to do: the server checks all of it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local BedGrid = require(Shared.BedGrid)
local BedLayout = require(Shared.BedLayout)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Service = require(Shared.Service)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local CameraController = require(script.Parent.CameraController)
local CarryController = require(script.Parent.CarryController)
local ComputerController = require(script.Parent.ComputerController)
local DialogueController = require(script.Parent.DialogueController)

local player = Players.LocalPlayer

-- How far from the camera you can use things.
local REACH = 10
-- How close (across the ground) a ride-on has to be to a bay to park on it.
local PARK_REACH = 6
-- How many of your crewmates' delivery boxes you can look past to one of yours behind them.
local OTHERS_BOXES = 4
-- The truck's beds and bays are read again this often (seconds), not every frame.
local TRUCK_REFRESH = 0.4
local GHOST_FITS = Color3.fromRGB(120, 220, 90)
local GHOST_BLOCKED = Color3.fromRGB(230, 70, 60)

type Target = {
	action: string,
	text: string,
	name: string?,
	fits: boolean, -- false: shown, but it won't work (it doesn't fit there)
	reason: string?,
	toolId: string?,
	panel: string?,
	spotIndex: number?,
	spot: Attachment?,
	bed: BedLayout.Bed?,
	anchor: number?,
	cells: { number }?,
	instance: Instance?,
	key: number?,
	kind: string?,
	ownerId: number?,
	-- Held down to do it (working on a tool), not just pressed.
	hold: boolean?,
	partName: string?,
	second: { action: string, text: string, hold: boolean?, fixture: string? }?,
}

local InteractController = {}

local current: Target? = nil
local busy = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local screen: ScreenGui
local hint: TextLabel
local button: TextButton
local secondButton: TextButton

local ghost: Model? = nil
local ghostId: string? = nil
local ghostPlace: string? = nil
local highlight: Highlight

local truckCache = {
	truck = nil :: Model?,
	beds = {} :: { BedLayout.Bed },
	taken = {} :: { [number]: { [number]: boolean } },
	bays = {} :: { BasePart },
	at = 0,
}

-- The crew leader's user id (yours when you're on your own): whose shop and yard you're at.
local function crewLeaderId(): number
	local party = ClientState.party
	return if party then party.leader.UserId else player.UserId
end

local function carriedItem()
	local id = player:GetAttribute("Carrying")
	return if typeof(id) == "string" then Tools.get(id) else nil
end

-- Your crew's truck, at the crew leader's business.
local function crewTruck(): Model?
	local business = ClientState.crewBusiness()
	local truck = business and business:FindFirstChild("CrewTruck")
	return if truck and truck:IsA("Model") then truck else nil
end

local function truckInfo()
	if os.clock() - truckCache.at > TRUCK_REFRESH then
		local truck = crewTruck()
		truckCache.truck = truck
		truckCache.beds = if truck then BedLayout.read(truck) else {}
		truckCache.taken = {}
		for index, bed in truckCache.beds do
			truckCache.taken[index] = BedLayout.taken(bed.part)
		end
		truckCache.bays = {}
		if truck then
			for _, descendant in truck:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.Name == "BaySpot" then
					table.insert(truckCache.bays, descendant)
				end
			end
		end
		truckCache.at = os.clock()
	end
	return truckCache
end

-- The thing with Interact attributes that `part` belongs to: itself or a model it's in.
local function interactableOf(part: Instance): Instance?
	local node: Instance? = part
	for _ = 1, 6 do
		if not node or node == workspace then
			return nil
		end
		if node:GetAttribute("Interact") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Your tool bucket: drop a hand tool in, or take the bucket (R takes one tool out).
local function bucketTarget(thing: Instance, item, take: string): Target?
	local count = thing:GetAttribute("BucketCount")
	count = if typeof(count) == "number" then count else 0
	if item then
		if item.sizeClass ~= "Hand" then
			return nil
		end
		return {
			action = "PutInBucket",
			text = "Put in bucket",
			name = item.name,
			fits = count < Storage.BucketHolds,
			reason = "The bucket's full.",
		}
	end
	return {
		action = take,
		text = "Take",
		name = if count > 0 then `Tool Bucket ({count} inside)` else "Tool Bucket",
		fits = true,
		toolId = Storage.BucketId,
		second = if count > 0 then { action = "TakeFromBucket", text = "Take one out" } else nil,
	}
end

-- The tool in your hands you could work on: carried at the business, equipped on a job.
local function heldTool()
	local item = carriedItem()
	if item then
		return if Maintenance.Supplies[item.id] then nil else item
	end
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ItemId")
	return if typeof(id) == "string" then Tools.get(id) else nil
end

-- Your tool set down to be worked on: what the supply in your hands does to it, or picking it
-- back up (and the building's machines) with empty hands.
local function serviceTarget(thing: Instance, item, hit: Instance?): Target?
	local toolId = thing:GetAttribute("ToolId")
	local tool = if typeof(toolId) == "string" then Tools.get(toolId) else nil
	local profile = ClientState.profile
	if not (tool and profile) then
		return nil
	end
	local condition = profile.condition and profile.condition[tool.id] or {}
	local state =
		{ bladeOff = thing:GetAttribute("BladeOff") == true, wheelOff = thing:GetAttribute("WheelOff") == true }
	local spot = if thing:GetAttribute("SpotKind") == "Vise" then "Vise" else "Floor"
	local partName = if hit then hit.Name else nil
	local part = Service.partKind(partName or "")
	if item then
		if not Maintenance.Supplies[item.id] then
			return nil
		end
		local step, reason = Service.step(tool, condition, item.id, state, spot, part)
		return {
			action = "Service",
			text = if step then step.text else "Use",
			name = tool.name,
			fits = step ~= nil,
			reason = reason,
			hold = true,
			partName = partName,
		}
	end
	local second = nil
	for _, fixture in { "AirCompressor", "BenchGrinder" } do
		if thing:GetAttribute("Has" .. fixture) and not second then
			local step = Service.step(tool, condition, fixture, state, spot, part)
			if step then
				second = { action = "Service", text = step.text, hold = true, fixture = fixture }
			end
		end
	end
	local ready, reason = Service.canPickUp(state)
	return {
		action = "PickUpServiced",
		text = "Pick up",
		name = tool.name,
		fits = ready,
		reason = reason,
		partName = partName,
		second = second,
	}
end

local function targetFor(thing: Instance, item, hit: Instance?): Target?
	local action = thing:GetAttribute("Interact")
	local text = thing:GetAttribute("InteractText")
	local name = thing:GetAttribute("InteractName")
	text = if typeof(text) == "string" then text else "Use"
	name = if typeof(name) == "string" then name else nil
	if action == "OpenPanel" then
		local panel = thing:GetAttribute("OpensPanel")
		return { action = action, text = text, name = name, fits = true, panel = panel }
	elseif action == "SetDown" then
		local held = heldTool()
		if not held or thing:GetAttribute("Occupied") then
			return nil
		end
		local spot = Service.spotFor(held)
		return {
			action = action,
			text = text,
			name = held.name,
			fits = spot == thing:GetAttribute("SpotKind"),
			reason = if spot == "Vise" then "that goes in the vise" else "that goes on the floor",
			instance = thing,
		}
	elseif action == "ServiceTool" then
		if thing:GetAttribute("OnlyFor") ~= player.UserId then
			return nil
		end
		return serviceTarget(thing, item, hit)
	elseif action == "TakeSupply" then
		local toolId = thing:GetAttribute("ToolId")
		if item or thing:GetAttribute("OnlyFor") ~= player.UserId or typeof(toolId) ~= "string" then
			return nil
		end
		return { action = action, text = text, name = name, fits = true, toolId = toolId }
	elseif action == "Tailgate" then
		if not (item and Maintenance.Supplies[item.id]) then
			return nil
		end
		return { action = "PutBackSupply", text = text, name = item.name, fits = true }
	elseif action == "PickUpDebris" or action == "Talk" then
		return { action = action, text = text, name = name, fits = true, instance = thing }
	elseif action == "DriveToJob" or action == "UseComputer" then
		if item then
			return nil
		end
		local business = ClientState.crewBusiness()
		return {
			action = action,
			text = text,
			name = name,
			fits = business ~= nil and thing:IsDescendantOf(business),
			reason = "not your crew's",
			instance = thing,
		}
	elseif action == "OpenBox" and thing:GetAttribute("BoxKind") == "Decor" then
		local key = thing:GetAttribute("BoxKey")
		if thing:GetAttribute("ForCrew") ~= crewLeaderId() or typeof(key) ~= "number" then
			return nil
		end
		return {
			action = action,
			text = text,
			name = name,
			fits = item == nil,
			reason = "your hands are full",
			key = key,
			kind = "Decor",
		}
	elseif action == "MoveDecor" then
		local ownerId, key = thing:GetAttribute("DecorOwner"), thing:GetAttribute("DecorKey")
		if ownerId ~= crewLeaderId() or typeof(key) ~= "number" then
			return nil
		end
		local mailbox = thing:GetAttribute("DecorId") == "Mailbox"
		return {
			action = action,
			text = text,
			name = name,
			fits = item == nil,
			reason = "your hands are full",
			key = key,
			ownerId = ownerId,
			second = if mailbox then { action = "UseMailbox", text = "Open or close" } else nil,
		}
	elseif action == "OpenBox" then
		local key = thing:GetAttribute("BoxKey")
		if thing:GetAttribute("OnlyFor") ~= player.UserId or typeof(key) ~= "number" then
			return nil
		end
		return {
			action = action,
			text = text,
			name = name,
			fits = item == nil,
			reason = "your hands are full",
			key = key,
		}
	elseif action == "PickUp" or action == "Unload" then
		if action == "Unload" and thing:GetAttribute("OnlyFor") ~= player.UserId then
			return nil
		end
		local toolId = thing:GetAttribute("ToolId")
		if toolId == Storage.BucketId then
			return bucketTarget(thing, item, action)
		end
		if item or typeof(toolId) ~= "string" then
			return nil
		end
		return { action = action, text = text, name = name, fits = true, toolId = toolId }
	elseif action == "PutBack" then
		local kind = thing:GetAttribute("SpotKind")
		local index = thing:GetAttribute("SpotIndex")
		if not item or Storage.spotOf(item) ~= kind or typeof(index) ~= "number" then
			return nil
		end
		local noEngines = thing:GetAttribute("ManualOnly") == true and item.sizeClass == "FloorEngine"
		return {
			action = action,
			text = text,
			name = item.name,
			fits = not noEngines,
			reason = "No engines in here.",
			spotIndex = index,
			spot = CarryController.spotOfMarker(thing),
		}
	end
	return nil
end

-- Where the tool in your hands would go in your crew's truck bed, aiming along the ray.
local function bedTarget(item, origin: Vector3, direction: Vector3, reach: number): Target?
	if not BedGrid.footprint(item.sizeClass) or Maintenance.isStationary(item.id) then
		return nil
	end
	local info = truckInfo()
	for index, bed in info.beds do
		local column, row = BedLayout.aim(bed, origin, direction, reach)
		if column and row then
			local anchor = BedGrid.anchorAround(bed.grid, item.sizeClass, column, row)
			local cells = anchor and BedGrid.cells(bed.grid, item.sizeClass, anchor)
			return {
				action = "Place",
				text = "Place",
				name = item.name,
				fits = cells ~= nil and BedGrid.free(info.taken[index] or {}, cells),
				reason = if cells then "That won't fit there." else "That's too big for this bed.",
				bed = bed,
				anchor = anchor,
				cells = cells,
			}
		end
	end
	return nil
end

-- Your tool lying on the bed cell you're looking down at, for when the truck's side hides it
-- (small tools at the front of a tall bed). The server notes each tool's cells (BedIndex and
-- BedCells, see TruckService).
local function bedItemTarget(origin: Vector3, direction: Vector3): Target?
	local info = truckInfo()
	local items = info.truck and info.truck:FindFirstChild("BedItems")
	if not items then
		return nil
	end
	for index, bed in info.beds do
		local column, row = BedLayout.aim(bed, origin, direction, REACH)
		if column and row then
			local cell = tostring(BedGrid.indexOf(bed.grid, column, row))
			for _, display in items:GetChildren() do
				local cells = display:GetAttribute("BedCells")
				if
					display:GetAttribute("BedIndex") == index
					and typeof(cells) == "string"
					and table.find(string.split(cells, ","), cell)
				then
					return targetFor(display, nil, nil)
				end
			end
		end
	end
	return nil
end

-- Parking the ride-on you're driving: on a free trailer bay, or a free bay in storage.
local function parkTarget(root: BasePart): Target?
	local function across(position: Vector3): number
		local offset = position - root.Position
		return Vector2.new(offset.X, offset.Z).Magnitude
	end
	for _, spot in truckInfo().bays do
		if spot:GetAttribute("Taken") ~= true and across(spot.Position) <= PARK_REACH then
			return { action = "Park", text = "Park", name = "Trailer bay", fits = true }
		end
	end
	local mine = workspace:FindFirstChild("MyStorage")
	if mine then
		for _, marker in mine:GetChildren() do
			if
				marker:IsA("BasePart")
				and marker:GetAttribute("SpotKind") == "Bay"
				and across(marker.Position) <= PARK_REACH
			then
				return { action = "Park", text = "Park", name = "Equipment bay", fits = true }
			end
		end
	end
	return nil
end

local function resolve(): Target?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if
		busy
		-- Placing a decoration has its own keys (see DecorController).
		or player:GetAttribute("PlacingDecor") ~= nil
		or not (character and root and root:IsA("BasePart") and camera)
		or not CameraController.isFirstPerson()
		or UI.needsCursor()
		or not UI.getScreen().Enabled
	then
		return nil
	end
	local item = carriedItem()
	if item and item.sizeClass == "Bay" then
		return parkTarget(root)
	end

	local origin, direction = camera.CFrame.Position, camera.CFrame.LookVector
	local ignore: { Instance } = { character }
	rayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, direction * REACH, rayParams)
	local thing = result and interactableOf(result.Instance)
	-- Look past your crewmates' delivery boxes, to yours.
	for _ = 1, OTHERS_BOXES do
		if not (thing and thing:GetAttribute("Interact") == "OpenBox") then
			break
		end
		local crewBox = thing:GetAttribute("BoxKind") == "Decor" and thing:GetAttribute("ForCrew") == crewLeaderId()
		if crewBox or thing:GetAttribute("OnlyFor") == player.UserId then
			break
		end
		table.insert(ignore, thing)
		rayParams.FilterDescendantsInstances = ignore
		result = workspace:Raycast(origin, direction * REACH, rayParams)
		thing = result and interactableOf(result.Instance)
	end
	local target = thing and targetFor(thing, item, result and result.Instance)
	local here = target and target.action
	if here == "PutBack" or here == "PutInBucket" or here == "SetDown" or here == "Service" then
		return target
	end
	if not item and (target == nil or here == "DriveToJob") then
		local truck = truckInfo().truck
		if result and truck and result.Instance:IsDescendantOf(truck) then
			local inBed = bedItemTarget(origin, direction)
			if inBed then
				return inBed
			end
		end
	end
	if item then
		-- Aiming at the truck (or something in its bed) counts all the way down to the bed.
		local truck = truckInfo().truck
		local onTruck = result ~= nil and truck ~= nil and result.Instance:IsDescendantOf(truck)
		local reach = if result and not onTruck then result.Distance + 0.5 else REACH
		local placing = bedTarget(item, origin, direction, reach)
		if placing then
			return placing
		end
	end
	return target
end

local function hideGhost()
	if ghost then
		ghost.Parent = nil
	end
	ghostPlace = nil
end

-- A see-through copy of what you're carrying, where it would go.
local function showGhost(target: Target?)
	local item = carriedItem()
	local placing = target and item and target.action == "Place" and target.cells and target.bed
	local hanging = target and item and target.action == "PutBack" and target.spot
	if not (target and item and (placing or hanging)) then
		hideGhost()
		return
	end
	if ghostId ~= item.id or not ghost then
		if ghost then
			-- The highlight lives on; only the old copy goes.
			highlight.Parent = nil
			ghost:Destroy()
		end
		local model = Assets.toolDisplay(item.category, item.id)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Transparency = math.max(part.Transparency, 0.5)
			end
		end
		highlight.Adornee = model
		highlight.Parent = model
		ghost, ghostId, ghostPlace = model, item.id, nil
	end
	local model = ghost :: Model
	model.Parent = workspace.CurrentCamera
	-- Only move it when it should go somewhere new.
	local place = if placing
		then `bed{(target.bed :: BedLayout.Bed).index}:{target.anchor}`
		else `spot{target.spotIndex}`
	if place ~= ghostPlace then
		ghostPlace = place
		if placing then
			BedLayout.place(model, target.bed :: BedLayout.Bed, target.cells :: { number }, item.sizeClass)
		else
			CarryController.placeInSpot(model, target.spot :: Attachment, CarryController.floorY())
		end
	end
	highlight.FillColor = if target.fits then GHOST_FITS else GHOST_BLOCKED
	highlight.OutlineColor = highlight.FillColor
end

local function invoke(name: string, ...): (boolean?, string?)
	local ok, result, message = pcall(Net.func(name).InvokeServer, Net.func(name), ...)
	if not ok then
		return false, nil
	end
	return result, message
end

local function perform(target: Target, second: boolean)
	local action = if second and target.second then target.second.action else target.action
	if not second and not target.fits then
		UI.notify(target.reason or "That won't work here.")
		return
	end
	if action == "OpenPanel" then
		if typeof(target.panel) == "string" then
			UI.open(target.panel)
		end
		return
	elseif action == "UseComputer" then
		local desk = target.instance
		if desk and desk:IsA("Model") then
			ComputerController.use(desk)
		end
		return
	elseif action == "Talk" then
		if target.instance then
			DialogueController.talk(target.instance)
		end
		return
	end
	busy = true
	task.spawn(function()
		local _, message
		if action == "DriveToJob" then
			_, message = invoke("DriveToJob")
		elseif action == "PickUpDebris" then
			_, message = invoke("PickUpDebris", target.instance)
		elseif action == "PickUp" then
			_, message = invoke("PickUpTool", target.toolId)
		elseif action == "Unload" then
			_, message = invoke("UnloadTool", target.toolId)
		elseif action == "PutBack" then
			_, message = invoke("PutBackTool", target.spotIndex)
		elseif action == "Place" then
			_, message = invoke("LoadTool", target.bed and target.bed.index, target.anchor)
		elseif action == "PutInBucket" then
			_, message = invoke("PutInBucket")
		elseif action == "TakeFromBucket" then
			_, message = invoke("TakeFromBucket")
		elseif action == "Park" then
			_, message = invoke("ParkRide")
		elseif action == "OpenBox" then
			_, message = invoke("OpenBox", target.key, target.kind)
		elseif action == "MoveDecor" then
			_, message = invoke("MoveDecor", target.ownerId, target.key)
		elseif action == "UseMailbox" then
			_, message = invoke("UseMailbox", target.ownerId, target.key)
		elseif action == "SetDown" then
			_, message = invoke("SetDownTool", target.instance)
		elseif action == "PickUpServiced" then
			_, message = invoke("PickUpServiced")
		elseif action == "TakeSupply" then
			_, message = invoke("TakeSupply", target.toolId)
		elseif action == "PutBackSupply" then
			_, message = invoke("PutBackSupply")
		end
		if typeof(message) == "string" then
			UI.notify(message)
		end
		busy = false
	end)
end

-- Working on a tool happens while E (or the button) is held down. Each press is its own hold, so
-- a late reply to an old one can't end a newer one.
local holding: {}? = nil

local function isHold(target: Target, second: boolean): boolean
	return if second then target.second ~= nil and target.second.hold == true else target.hold == true
end

local function startHold(target: Target, second: boolean)
	if holding or busy then
		return
	end
	if not second and not target.fits then
		UI.notify(target.reason or "That won't work here.")
		return
	end
	local hold = {}
	holding = hold
	local fixture = if second and target.second then target.second.fixture else nil
	task.spawn(function()
		local ok, message = invoke("StartService", fixture, target.partName)
		if typeof(message) == "string" then
			UI.notify(message)
		end
		if not ok and holding == hold then
			holding = nil
		end
	end)
end

local function stopHold()
	if holding then
		holding = nil
		Net.event("StopService"):FireServer()
	end
end

-- The look-at button on a phone: tapped, or held down for work. What a press does is decided when
-- it starts, and a hold ends when that touch ends, wherever the finger has slid to.
local heldByButton = false
local function pressable(gui: GuiButton, second: boolean)
	gui.InputBegan:Connect(function(input)
		local pressing = input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		if not (pressing and current and isHold(current, second)) then
			return
		end
		heldByButton = true
		startHold(current, second)
		local connection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				stopHold()
				-- The tap that ends a hold isn't a tap.
				task.defer(function()
					heldByButton = false
				end)
			end
		end)
	end)
end

local function updateUI()
	local target = current
	local touch = UserInputService.TouchEnabled
	if not target then
		hint.Visible = false
		button.Visible = false
		secondButton.Visible = false
		return
	end
	local label = target.text .. (if target.name then `  {target.name}` else "")
	if not target.fits then
		label ..= `  ({target.reason or "won't work"})`
	end
	if UserInputService.KeyboardEnabled then
		label = (if target.hold then "[Hold E] " else "[E] ") .. label
		if target.second then
			label ..= (if target.second.hold then "\n[Hold R] " else "\n[R] ") .. target.second.text
		end
	end
	hint.Text = label
	hint.TextColor3 = if target.fits then UI.Colors.Text else UI.Colors.Danger
	hint.Visible = not touch or target.name ~= nil
	button.Visible = touch
	button.Text = target.text
	button.BackgroundColor3 = if target.fits then UI.Colors.Accent else UI.Colors.Disabled
	secondButton.Visible = touch and target.second ~= nil
	if target.second then
		secondButton.Text = target.second.text
	end
end

function InteractController:Start()
	screen = UI.new("ScreenGui", {
		Name = "Interact",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	hint = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = screen,
	})
	button = UI.button("", function()
		if current and not heldByButton and not isHold(current, false) then
			perform(current, false)
		end
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.55, 0),
		Size = UDim2.fromOffset(110, 110),
		TextSize = 22,
		TextWrapped = true,
		Visible = false,
		Parent = screen,
	})
	UI.corner(55).Parent = button
	secondButton = UI.button("", function()
		if current and current.second and not heldByButton and not isHold(current, true) then
			perform(current, true)
		end
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 0.55, -66),
		Size = UDim2.fromOffset(110, 44),
		TextSize = 16,
		BackgroundColor3 = UI.Colors.Card,
		Visible = false,
		Parent = screen,
	})

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded

	pressable(button, false)
	pressable(secondButton, true)

	local function onInput(second: boolean)
		return function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				if holding then
					stopHold()
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			if state ~= Enum.UserInputState.Begin or not current then
				return Enum.ContextActionResult.Pass
			end
			if second and not current.second then
				return Enum.ContextActionResult.Pass
			end
			if isHold(current, second) then
				startHold(current, second)
			else
				perform(current, second)
			end
			return Enum.ContextActionResult.Sink
		end
	end
	ContextActionService:BindActionAtPriority(
		"Interact",
		onInput(false),
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:BindActionAtPriority(
		"InteractSecond",
		onInput(true),
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonY
	)

	RunService.RenderStepped:Connect(function()
		current = resolve()
		updateUI()
		showGhost(current)
	end)
	-- A new carry, a new truck: look again straight away.
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		truckCache.at = 0
	end)
end

return InteractController
