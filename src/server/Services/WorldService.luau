-- The town: a business plot for every player. Your business (shed -> garage -> small office ->
-- equipment yard) is the hub (docs/GAME_DESIGN.md, "The shop as the hub"): the crew picks jobs and
-- orders gear on the computer inside, unboxes deliveries by the door, carries tools from storage
-- to the truck and drives off from there.
-- What's in storage is laid out by BusinessStorage. Walk-in buildings (docs/GAME_DESIGN.md,
-- "Immersion") have their storage, workbench, lights and truck parking marked inside the model,
-- and their doors are modelled open. The truck waits at the door with its tailgate (or ramp, or
-- rear door) open, and closes it to drive off.
--
-- To build the town yourself in Studio, make a Model named "Town" in Workspace with:
--   * a SpawnLocation
--   * a Folder named "Plots" with one Part per business plot. A plot's front (LookVector)
--     should face the street. Everything on the plot is placed relative to that part.
-- Otherwise a placeholder town is built here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local BusinessStorage = require(script.Parent.Parent.BusinessStorage)
local DataService = require(script.Parent.DataService)
local Openings = require(script.Parent.Parent.Openings)

-- Deep enough for the building at the back, a driveway that fits a truck and trailer, and the
-- front lawn beside it.
local PLOT_SIZE = Vector3.new(90, 1, 90)
-- How far back the building stands, and how wide the driveway is.
local BUILDING_Z = 22
local DRIVEWAY_WIDTH = 10
-- Where the business's own lawn goes (Hub 3), on the left of the driveway, in plot space.
local LAWN_CENTER, LAWN_SIZE = Vector3.new(-23, 0, -25), Vector3.new(30, 0, 34)
-- The crew truck pulls out of the driveway and back in over this many seconds.
local DRIVE_TIME = 2.5
-- How close you need to be to your business's storage to grab or put back a tool.
local STORAGE_REACH = 10
-- How close you need to be to the workbench to work on tools (a bit more than its prompt's reach).
local WORKBENCH_REACH = 14
-- How long the truck's tailgate takes to open or close.
local TAILGATE_TIME = 0.6
-- How close to the job computer's desk you need to be to use it (and buy, sell or take jobs).
local COMPUTER_REACH = 8
-- The building's own machines, for its Compressor and Grinder mounts.
local SHOP_MACHINES = { Compressor = "AirCompressor", Grinder = "BenchGrinder" }
-- Walls put up for a walk-in building whose walls don't collide properly (see makeWalkable).
local FALLBACK_WALL = 0.8

local WorldService = {}
-- Fired with (owner) after a business plot is (re)built, so the truck bed can be refilled.
WorldService.PlotBuilt = Signal.new()

local businessFolder: Folder

local spawnCFrame = CFrame.new(0, 5, 0)
-- Each plot: { cframe = CFrame, width = number, depth = number, owner = Player?, model = Model?,
--   deliveryFrame = CFrame?, truckHome = CFrame?, lawnFrame = CFrame?, lawnSize = Vector3?,
--   awayTruck = Model? (out on a trip, see PullOut), trip = {}? }
local plots = {}
-- [Player] = plot
local playerPlots = {}
-- Who a player's crew leader is, so crews hang out at the leader's business. Set by PartyService.
local getLeader = function(player: Player): Player
	return player
end

local function part(parent: Instance, props): Part
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(newPart :: any)[key] = value
	end
	newPart.Parent = parent
	return newPart
end

local function sign(target: BasePart, text: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	gui.Parent = target
end

-- Makes something usable by looking at it and pressing E (see InteractController): "OpenPanel"
-- opens a menu (attribute OpensPanel), anything else asks the server.
local function interactable(target: Instance, action: string, actionText: string, objectText: string, attributes)
	target:SetAttribute("Interact", action)
	target:SetAttribute("InteractText", actionText)
	target:SetAttribute("InteractName", objectText)
	for key, value in attributes do
		target:SetAttribute(key, value)
	end
end

local function buildPlaceholderTown(): Model
	local town = Instance.new("Model")
	town.Name = "Town"

	part(town, {
		Name = "Ground",
		Size = Vector3.new(660, 2, 500),
		Position = Vector3.new(0, -1, -30),
		Color = Color3.fromRGB(90, 150, 70),
		Material = Enum.Material.Grass,
	})
	for _, z in { 20, -80 } do
		part(town, {
			Name = "Road",
			Size = Vector3.new(660, 0.2, 24),
			Position = Vector3.new(0, 0.1, z),
			Color = Color3.fromRGB(55, 55, 60),
			Material = Enum.Material.Asphalt,
		})
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Vector3.new(0, 0.5, -30)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Color = Color3.fromRGB(240, 200, 60)
	spawnLocation.Parent = town

	-- Business plots line both streets. Front of each plot faces its street.
	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plots"
	plotFolder.Parent = town
	local index = 0
	for _, x in { -250, -150, -50, 50, 150, 250 } do
		for _, row in { { z = 80, faces = 20 }, { z = -140, faces = -80 } } do
			index += 1
			part(plotFolder, {
				Name = "Plot" .. index,
				Size = PLOT_SIZE,
				CFrame = CFrame.lookAt(Vector3.new(x, -0.4, row.z), Vector3.new(x, -0.4, row.faces)),
				Color = Color3.fromRGB(110, 165, 80),
				Material = Enum.Material.Grass,
			})
		end
	end

	town.Parent = workspace
	return town
end

-- A walk-in building needs walls you can't walk through but doors you can. Its wall meshes have
-- real holes for the doors, which collide properly with the Default or
-- PreciseConvexDecomposition CollisionFidelity (set in Studio: scripts can't change it). A wall
-- mesh left on Box or Hull collides as one solid block, so it stops colliding and plain invisible
-- walls go up around the building instead, open where its doors are.
local function isDoor(name: string): boolean
	return string.sub(name, -6) == "__Door" or string.sub(name, -12) == "__GarageDoor"
end

local function makeWalkable(building: Model, markers)
	local shells = {}
	for _, descendant in building:GetDescendants() do
		if
			descendant:IsA("MeshPart")
			and descendant.CanCollide
			and not isDoor(descendant.Name)
			and (descendant.CollisionFidelity == Enum.CollisionFidelity.Box or descendant.CollisionFidelity == Enum.CollisionFidelity.Hull)
			and math.max(descendant.Size.X, descendant.Size.Z) >= 8
			and descendant.Size.Y >= 4
		then
			table.insert(shells, descendant)
		end
	end
	if #shells == 0 then
		return
	end
	for _, shell in shells do
		shell.CanCollide = false
	end

	local box, size = building:GetBoundingBox()
	local height = math.min(size.Y, 16)
	local half = size / 2
	local function nearestWall(point: Vector3): (string, number)
		local distances = {
			Front = math.abs(point.Z + half.Z),
			Back = math.abs(point.Z - half.Z),
			Left = math.abs(point.X + half.X),
			Right = math.abs(point.X - half.X),
		}
		local wall, nearest = "Front", math.huge
		for name, distance in distances do
			if distance < nearest then
				wall, nearest = name, distance
			end
		end
		return wall, if wall == "Front" or wall == "Back" then point.X else point.Z
	end

	-- Each door's opening along the wall it's in, from the floor up. A garage door is modelled
	-- rolled up over its opening. A hinged door is modelled swung open, beside its opening, so
	-- the opening is taken to be where the truck parks in front of (or, without a parking
	-- marker, where the door is).
	local gaps = { Front = {}, Back = {}, Left = {}, Right = {} }
	for _, descendant in building:GetDescendants() do
		if descendant:IsA("BasePart") and isDoor(descendant.Name) then
			local center = box:PointToObjectSpace(descendant.Position)
			local garage = string.sub(descendant.Name, -12) == "__GarageDoor"
			local width = math.max(descendant.Size.X, descendant.Size.Z)
			local top = center.Y + descendant.Size.Y / 2 + half.Y
			if not garage then
				top = descendant.Size.Y + 0.3
				width = math.max(width, 4) + 0.6
				if markers.parking then
					center = box:PointToObjectSpace(markers.parking.Position)
				end
			end
			local wall, along = nearestWall(center)
			table.insert(gaps[wall], { from = along - width / 2, to = along + width / 2, height = top })
		end
	end

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	local function wallPiece(center: Vector3, pieceSize: Vector3)
		if pieceSize.X > 0.05 and pieceSize.Y > 0.05 and pieceSize.Z > 0.05 then
			part(walls, {
				Name = "Wall",
				Size = pieceSize,
				CFrame = box * CFrame.new(center),
				Transparency = 1,
				CanQuery = false,
			})
		end
	end
	local floor = -half.Y
	for wall, list in gaps do
		local across = wall == "Front" or wall == "Back"
		local length = if across then size.X else size.Z
		local offset = if wall == "Front"
			then -half.Z
			elseif wall == "Back" then half.Z
			elseif wall == "Left" then -half.X
			else half.X
		local function piece(from: number, to: number, bottom: number)
			local middle, span = (from + to) / 2, to - from
			local y = floor + (bottom + height) / 2
			if across then
				wallPiece(Vector3.new(middle, y, offset), Vector3.new(span, height - bottom, FALLBACK_WALL))
			else
				wallPiece(Vector3.new(offset, y, middle), Vector3.new(FALLBACK_WALL, height - bottom, span))
			end
		end
		table.sort(list, function(a, b)
			return a.from < b.from
		end)
		local cursor = -length / 2
		for _, gap in list do
			piece(cursor, math.max(cursor, gap.from), 0)
			-- Above the door.
			piece(math.max(cursor, gap.from), gap.to, math.min(gap.height, height))
			cursor = math.max(cursor, gap.to)
		end
		piece(cursor, length / 2, 0)
	end
	walls.Parent = building
end

-- Where a plot's truck ends up when it pulls out: straight ahead into the street.
local function streetFrame(plot): CFrame
	local home: CFrame = plot.truckHome
	local ahead = plot.cframe:PointToObjectSpace(home.Position).Z + plot.depth / 2 + 12
	return home + home.LookVector * ahead
end

-- Rebuilds everything on a plot to match its owner's business tier, truck and trailer.
local function buildPlot(plot)
	if plot.model then
		plot.model:Destroy()
		plot.model = nil
	end
	local owner = plot.owner
	local data = owner and DataService:Get(owner)
	if not data then
		return
	end

	local model = Instance.new("Model")
	model.Name = owner.Name .. "_Business"
	model:SetAttribute("OwnerUserId", owner.UserId)
	local origin = plot.cframe
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- Building at the back of the plot, front door facing the street.
	local building = Assets.building(data.equipped.Business or "Shed")
	Assets.anchor(building)
	Assets.placeOnGround(building, at(0, 0, BUILDING_Z))
	building.Parent = model
	-- How far toward the street the building's front comes, for what stands in front of it.
	local buildingBox, buildingSize = building:GetBoundingBox()
	local frontZ = origin:PointToObjectSpace(buildingBox.Position).Z - buildingSize.Z / 2
	local markers = BusinessStorage.markers(building)
	local walkIn = next(markers.mounts) ~= nil or #markers.floor > 0 or #markers.bays > 0
	if walkIn then
		makeWalkable(building, markers)
	end
	for _, light in markers.lights do
		local pointLight = Instance.new("PointLight")
		pointLight.Range = 18
		pointLight.Brightness = 1.2
		pointLight.Color = Color3.fromRGB(255, 238, 210)
		pointLight.Shadows = false
		pointLight.Parent = light
	end

	local signPost = part(model, {
		Name = "BusinessSign",
		Size = Vector3.new(16, 4, 0.5),
		CFrame = at(26, 3, -42),
		Color = Color3.fromRGB(240, 240, 230),
	})
	sign(signPost, `{owner.DisplayName}'s Lawn Care`, Enum.NormalId.Front)

	-- The job computer: jobs, orders, upgrades and the crew, at the desk (see ComputerController).
	local businessItem = Items.get("Business", data.equipped.Business or "Shed") or Items.Catalog.Business[1]
	local desk = Assets.prop(businessItem.desk)
	Assets.anchor(desk)
	-- Older buildings can't be walked into, so the desk stands out front, facing the street.
	Assets.placeAt(desk, markers.desk or at(-22, 0, math.min(4, frontZ - 3)))
	desk.Name = "Desk"
	desk.Parent = model
	interactable(desk, "UseComputer", "Use Computer", "Shop Computer", {})
	plot.deliveryFrame = markers.delivery or at(-12, 0, math.min(2, frontZ - 2))

	-- The driveway, from the street to the door.
	local drivewayLength = frontZ + plot.depth / 2
	part(model, {
		Name = "Driveway",
		Size = Vector3.new(DRIVEWAY_WIDTH, 0.1, drivewayLength),
		CFrame = at(0, 0.05, frontZ - drivewayLength / 2),
		Color = Color3.fromRGB(170, 170, 165),
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	plot.lawnFrame, plot.lawnSize = at(LAWN_CENTER.X, 0, LAWN_CENTER.Z), LAWN_SIZE

	-- Each player sees their own tools in storage on their screen (see CarryController).
	BusinessStorage.build(model, origin, data.equipped.Business or "Shed", markers)

	-- Where the crew fixes up their tools (see MaintenanceService).
	local bench = Assets.prop("Workbench")
	Assets.anchor(bench)
	Assets.placeAt(
		bench,
		if markers.mounts.Workbench then markers.mounts.Workbench[1] else at(-31, 0, math.min(-2, frontZ - 5))
	)
	bench.Name = "Workbench"
	bench.Parent = model
	-- The building's own air compressor and bench grinder, where it has room for them.
	for kind, toolId in SHOP_MACHINES do
		local tool = markers.mounts[kind] and Items.get("Supplies", toolId)
		if tool then
			local machine = Assets.toolDisplay(tool.category, toolId)
			Assets.anchor(machine)
			Assets.placeOnGround(machine, markers.mounts[kind][1])
			machine.Name = kind
			machine.Parent = model
		end
	end
	interactable(bench, "OpenPanel", "Work on Tools", "Workbench", { OpensPanel = "Workbench" })

	local truck = Assets.truck(data.equipped.Truck or Items.Catalog.Truck[1].id, data.equipped.Trailer)
	Assets.anchor(truck)
	-- On the driveway with its tailgate to the door (on older buildings, about 10 studs out, like
	-- the TruckParking marker says for the new ones).
	local parking = markers.parking or at(0, 0, frontZ - 10)
	Assets.placeOnGround(truck, parking)
	-- At the door, a trailer's ramp goes where the tailgate would be, with the truck ahead of it.
	local trailer = truck:FindFirstChild("Trailer")
	if trailer and trailer:IsA("Model") then
		local _, trailerSize = trailer:GetBoundingBox()
		truck:PivotTo(truck:GetPivot() + parking.LookVector * (trailerSize.Z + 1))
	end
	truck.Name = "CrewTruck"
	truck.Parent = model
	plot.truckHome = truck:GetPivot()
	-- Parked with the tailgate down (and the trailer's ramp), ready to load.
	Openings.set(truck, true)
	-- Getting in at the driver's door heads off on the job (see JobService). Carried tools go in
	-- its bed by looking at the bed (see InteractController).
	local driverDoor
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -12) == "__DriverDoor" then
			driverDoor = descendant
		end
	end
	interactable(driverDoor or truck, "DriveToJob", "Get In", "Crew Truck", { OwnerUserId = owner.UserId })
	-- The glass is part of the door, so looking at the window works too.
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -17) == "__DriverDoorGlass" then
			interactable(descendant, "DriveToJob", "Get In", "Crew Truck", { OwnerUserId = owner.UserId })
		end
	end
	if plot.awayTruck then
		-- Rebuilt while the crew's out: the new truck is the one that comes back.
		plot.awayTruck:Destroy()
		plot.awayTruck = truck
		truck:PivotTo(streetFrame(plot))
		truck.Parent = nil
	end

	model.Parent = businessFolder
	plot.model = model
	WorldService.PlotBuilt:Fire(owner)
end

-- Public API ---------------------------------------------------------------------------------

function WorldService:SetLeaderLookup(lookup: (Player) -> Player)
	getLeader = lookup
end

-- Call after a player upgrades their business, truck or trailer.
function WorldService:RefreshPlot(player: Player)
	local plot = playerPlots[player]
	if plot then
		buildPlot(plot)
	end
end

-- Where a player should stand when they're not on a job: their crew leader's business.
function WorldService:GetHomeCFrame(player: Player, index: number?): CFrame
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local base = if plot then plot.cframe * CFrame.new(12, 3.5, -40) else spawnCFrame
	return base * CFrame.new(((index or 1) - 1) * 3 - 4.5, 0, 0)
end

-- Opens or closes the tailgate (ramp, rear door) of the truck at this player's business: it
-- closes before the crew drives off and opens again when they're back.
function WorldService:SetTruckOpen(player: Player, open: boolean)
	local truck = WorldService:GetPlotTruck(player)
	if truck then
		Openings.set(truck, open, TAILGATE_TIME)
	end
end

-- Drives a truck from one spot to another over `seconds`, easing in and out. Every client
-- animates it smoothly (see CutsceneController), and the server puts it at the end once it's
-- there. A newer drive of the same truck takes over.
local driving = setmetatable({}, { __mode = "k" })
local function drive(truck: Model, from: CFrame, to: CFrame, seconds: number, done: (() -> ())?)
	local token = {}
	driving[truck] = token
	truck:PivotTo(from)
	Net.event("TruckDrive"):FireAllClients(truck, from, to, workspace:GetServerTimeNow(), seconds)
	task.delay(seconds, function()
		if driving[truck] == token then
			driving[truck] = nil
			truck:PivotTo(to)
			if done then
				done()
			end
		end
	end)
end

-- The crew leaves from the business: the driver's door opens and shuts, then the truck pulls out
-- of the driveway into the street (GameConfig.PullOutTime in all). While the crew is away the
-- truck is gone from the plot, until ReturnTruck brings it back.
function WorldService:PullOut(player: Player)
	local plot = playerPlots[player]
	local truck = WorldService:GetPlotTruck(player)
	if not (plot and truck and plot.truckHome) or plot.awayTruck then
		return
	end
	plot.awayTruck = truck
	local trip = {}
	plot.trip = trip
	Openings.set(truck, true, 0.35, "DriverDoor")
	task.delay(0.6, function()
		if plot.trip == trip then
			Openings.set(truck, false, 0.35, "DriverDoor")
		end
	end)
	local driveTime = math.max(GameConfig.PullOutTime - 1, 0.5)
	task.delay(1, function()
		if plot.trip ~= trip or not truck.Parent then
			return
		end
		drive(truck, plot.truckHome, streetFrame(plot), driveTime, function()
			-- Off to the job: out of sight until it's back.
			if plot.trip == trip then
				truck.Parent = nil
			end
		end)
	end)
end

-- Brings the truck back from a trip: it pulls back in from the street and drops its tailgate,
-- or, `instantly` (the trip was called off before it started), it's simply back at the door.
-- Does nothing if it's already back.
function WorldService:ReturnTruck(player: Player, instantly: boolean?)
	local plot = playerPlots[player]
	local truck = plot and plot.awayTruck
	if not (plot and truck) then
		return
	end
	plot.awayTruck = nil
	local trip = {}
	plot.trip = trip
	if not plot.model then
		truck:Destroy()
		return
	end
	truck.Parent = plot.model
	if instantly then
		drive(truck, plot.truckHome, plot.truckHome, 0)
		Openings.set(truck, false, 0.35, "DriverDoor")
		Openings.set(truck, true, TAILGATE_TIME)
		return
	end
	drive(truck, streetFrame(plot), plot.truckHome, DRIVE_TIME, function()
		if plot.trip == trip then
			Openings.set(truck, true, TAILGATE_TIME)
		end
	end)
end

-- True while this player's truck is out on a trip.
function WorldService:IsTruckAway(player: Player): boolean
	local plot = playerPlots[player]
	return plot ~= nil and plot.awayTruck ~= nil
end

-- The front lawn of the player's own business, as (centre on the ground, size).
function WorldService:GetLawnArea(player: Player): (CFrame?, Vector3?)
	local plot = playerPlots[player]
	return plot and plot.lawnFrame, plot and plot.lawnSize
end

-- The truck parked at this player's own business.
function WorldService:GetPlotTruck(player: Player): Model?
	local plot = playerPlots[player]
	local truck = plot and plot.model and plot.model:FindFirstChild("CrewTruck")
	return if truck and truck:IsA("Model") then truck else nil
end

-- How far a point is from the nearest point of a part.
local function distanceTo(target: BasePart, point: Vector3): number
	local offset = target.CFrame:PointToObjectSpace(point)
	local half = target.Size / 2
	local inside = Vector3.new(
		math.clamp(offset.X, -half.X, half.X),
		math.clamp(offset.Y, -half.Y, half.Y),
		math.clamp(offset.Z, -half.Z, half.Z)
	)
	return (offset - inside).Magnitude
end

-- The storage of the player's crew's business (where their own tools are laid out).
function WorldService:GetCrewStorage(player: Player): Folder?
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local storage = plot and plot.model and plot.model:FindFirstChild("Storage")
	return if storage and storage:IsA("Folder") then storage else nil
end

-- True if the player is standing within `reach` studs of the model (its bounding box).
function WorldService:IsNear(player: Player, model: Model, reach: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local box, size = model:GetBoundingBox()
	local offset = box:PointToObjectSpace(root.Position)
	local half = size / 2
	local outside = offset
		- Vector3.new(
			math.clamp(offset.X, -half.X, half.X),
			math.clamp(offset.Y, -half.Y, half.Y),
			math.clamp(offset.Z, -half.Z, half.Z)
		)
	return outside.Magnitude <= reach
end

-- True if the player is at their crew's job computer.
function WorldService:IsAtComputer(player: Player): boolean
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local desk = plot and plot.model and plot.model:FindFirstChild("Desk")
	return desk ~= nil and desk:IsA("Model") and WorldService:IsNear(player, desk, COMPUTER_REACH)
end

-- Where delivered boxes go at the player's crew's business.
function WorldService:GetDeliveryFrame(player: Player): CFrame?
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	return plot and plot.model and plot.deliveryFrame
end

-- The business model the player's crew hangs out at.
function WorldService:GetCrewBusiness(player: Player): Model?
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	return plot and plot.model
end

-- True if the player is standing at the storage of their crew's business.
function WorldService:IsNearStorage(player: Player): boolean
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local storage = plot and plot.model and plot.model:FindFirstChild("Storage")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (storage and root and root:IsA("BasePart")) then
		return false
	end
	for _, child in storage:GetChildren() do
		if
			child:IsA("BasePart")
			and child:GetAttribute("StorageArea")
			and distanceTo(child, root.Position) <= STORAGE_REACH
		then
			return true
		end
	end
	return false
end

-- If the player is standing at their crew's workbench, the id of that business (its building
-- decides which shop machines are there).
function WorldService:GetWorkbenchBusiness(player: Player): string?
	local leader = getLeader(player)
	local plot = playerPlots[leader] or playerPlots[player]
	local bench = plot and plot.model and plot.model:FindFirstChild("Workbench")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (bench and bench:IsA("Model") and root and root:IsA("BasePart")) then
		return nil
	end
	if (root.Position - bench:GetPivot().Position).Magnitude > WORKBENCH_REACH then
		return nil
	end
	local ownerData = plot.owner and DataService:Get(plot.owner)
	return ownerData and ownerData.equipped.Business or "Shed"
end

function WorldService:IsAtBusiness(player: Player): boolean
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plot or not root or not root:IsA("BasePart") then
		return false
	end
	local offset = plot.cframe:PointToObjectSpace(root.Position)
	return math.abs(offset.X) <= plot.width / 2 and math.abs(offset.Z) <= plot.depth / 2
end

-- Lifecycle ----------------------------------------------------------------------------------

function WorldService:Init()
	businessFolder = Instance.new("Folder")
	businessFolder.Name = "Businesses"
	businessFolder.Parent = workspace

	local town = workspace:FindFirstChild("Town") or buildPlaceholderTown()
	local spawnLocation = town:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		spawnCFrame = spawnLocation.CFrame + Vector3.new(0, 4, 0)
	end

	local plotFolder = town:FindFirstChild("Plots")
	if plotFolder then
		for _, pad in plotFolder:GetChildren() do
			if pad:IsA("BasePart") then
				-- Plot origin sits on top of the pad.
				table.insert(plots, {
					cframe = pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0),
					width = pad.Size.X,
					depth = pad.Size.Z,
				})
			end
		end
	end
	if #plots == 0 then
		warn("No business plots found in Town.Plots, players won't get a business")
	end
end

function WorldService:Start()
	local function onPlayerAdded(player: Player)
		if not DataService:WaitForData(player) then
			return
		end
		for _, plot in plots do
			if not plot.owner then
				plot.owner = player
				playerPlots[player] = plot
				buildPlot(plot)
				break
			end
		end
		if not playerPlots[player] then
			warn(`No free business plot for {player.Name}. Lower Max Players or add more plots.`)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local plot = playerPlots[player]
		playerPlots[player] = nil
		if plot then
			plot.owner = nil
			if plot.awayTruck then
				plot.awayTruck:Destroy()
				plot.awayTruck = nil
			end
			plot.trip = nil
			buildPlot(plot)
		end
	end)
end

return WorldService
