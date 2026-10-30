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
--     should face the street, and the street should be to the south (-Z): every plot's front
--     lawn is drawn on a grid along the world's axes, edged along -Z and +X (see
--     HomeLawnService). Everything on the plot is placed relative to that part.
-- Otherwise a placeholder town is built here.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Premium = require(Shared.Config.Premium)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local BusinessStorage = require(script.Parent.Parent.BusinessStorage)
local DataService = require(script.Parent.DataService)
local GrandmaJune = require(script.Parent.Parent.GrandmaJune)
local Openings = require(script.Parent.Parent.Openings)
local ServiceSpots = require(script.Parent.Parent.ServiceSpots)

-- Deep enough for the building at the back, a driveway that fits a truck and trailer, and the
-- front lawn beside it.
local PLOT_SIZE = Vector3.new(90, 1, 90)
-- How far back the building stands, and how wide the driveway is.
local BUILDING_Z = 22
local DRIVEWAY_WIDTH = 10
-- The curb mailbox stands at the driveway's street end, this far past the driveway's right edge
-- (the side away from the lawn) and this far in from the plot's street edge.
local MAILBOX_BESIDE, MAILBOX_FROM_STREET = 1.5, 2
-- Where the business's own lawn goes (see HomeLawnService), on the left of the driveway, in plot
-- space: its edge runs a couple of studs from the driveway. Where a building's truck parks further
-- left, the lawn moves left with the driveway, staying LAWN_GAP from it.
local LAWN_CENTER, LAWN_SIZE = Vector3.new(-21.5, 0, -25), Vector3.new(30, 0, 34)
local LAWN_GAP = 1.5
-- Room to walk (and push a mower) between the truck's open tailgate, or its trailer's ramp, and
-- the building's front.
local WALKWAY = 6
-- Decorations keep this far from the driveway, the building and what stands around it.
local DECOR_CLEARANCE = 1
-- The patch in front of the delivery spot where boxes stand (see DeliveryService), in its space:
-- room for the rows of boxes it shows at once.
local DELIVERY_PATCH = { x = 0, z = -8, width = 10, depth = 16 }
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
-- Grandma June's porch (or just her rocker, see GrandmaJune) stands to the right of the building,
-- leaving JUNE_GAP of ground between them, its middle JUNE_AHEAD in front of the building's
-- front, turned JUNE_TURN toward the driveway. Beside an older building, whose delivery boxes
-- stand out front on the right, its near edge is at least JUNE_PAST_BOXES across, and its far edge
-- never closer than JUNE_EDGE to the plot's side. Where her porch won't fit, she gets just the
-- rocker.
local JUNE_GAP, JUNE_AHEAD, JUNE_TURN = 3, 2.5, math.rad(30)
local JUNE_PAST_BOXES, JUNE_EDGE = 23, 5
-- Walls put up for a walk-in building whose walls don't collide properly (see makeWalkable).
local FALLBACK_WALL = 0.8
-- A wall mesh no thicker than this (studs) is a flat piece that collides fine as it is, and one
-- whose bottom is this high above the floor is out of the way overhead (see makeWalkable).
local FLAT_WALL = 1
local HEADROOM = 7
-- The most a joining player's device is given to load their business once it's built, before that
-- request gives up (JobService asks again when it moves them in).
local FIRST_STREAM_TIMEOUT = 15

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
-- [Player] = true once they've been given a plot and it's built, or there was none free.
local settled = setmetatable({}, { __mode = "k" })
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
	-- So GloriaService knows where it may put her house.
	town:SetAttribute("Placeholder", true)

	part(town, {
		Name = "Ground",
		Size = Vector3.new(660, 2, 500),
		Position = Vector3.new(0, -1, -30),
		Color = Color3.fromRGB(90, 150, 70),
		Material = Enum.Material.Grass,
	})
	-- Studio's default Baseplate has its top at Y = 0 as well, and where two surfaces share a
	-- height they flicker through each other as the camera moves (the grass "vanishing" into the
	-- grey grid). Drop it under the town; past the town's edge it's still there to stand on.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Position -= Vector3.new(0, 1, 0)
	end
	for _, z in { 20, -120 } do
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
	spawnLocation.Position = Vector3.new(0, 0.5, -2)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Color = Color3.fromRGB(240, 200, 60)
	spawnLocation.Parent = town

	-- Business plots line both streets, every one facing its street to the south (-Z), so their
	-- front lawns line up with the grid lawns are drawn on (see HomeLawnService).
	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plots"
	plotFolder.Parent = town
	local index = 0
	for _, x in { -250, -150, -50, 50, 150, 250 } do
		for _, row in { { z = 80, faces = 20 }, { z = -60, faces = -120 } } do
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

-- A part's extent in `frame`'s space: (low corner, high corner).
local function extentIn(piece: BasePart, frame: CFrame): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local half = piece.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = frame:PointToObjectSpace(piece.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return low, high
end

local function makeWalkable(building: Model, markers)
	local box, size = building:GetBoundingBox()
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
			-- A flat wall piece (the model's walls come split around their doorways) or a roof up
			-- out of reach collides fine as it is. Only a box-shaped mesh around people's heads,
			-- whose hull would fill its doorways, needs the plain walls below instead.
			local low, high = extentIn(descendant, box)
			local flat = math.min(high.X - low.X, high.Z - low.Z) <= FLAT_WALL
			local overhead = low.Y + size.Y / 2 > HEADROOM
			if not (flat or overhead) then
				table.insert(shells, descendant)
			end
		end
	end
	if #shells == 0 then
		return
	end
	for _, shell in shells do
		shell.CanCollide = false
	end

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
	-- rolled up over its opening. A hinged door is modelled swung open, beside its opening; the
	-- wall is the one the door is at, and on the front the opening is taken to be where the truck
	-- parks in front of (elsewhere, or without a parking marker, where the door is).
	local gaps = { Front = {}, Back = {}, Left = {}, Right = {} }
	for _, descendant in building:GetDescendants() do
		if descendant:IsA("BasePart") and isDoor(descendant.Name) then
			local center = box:PointToObjectSpace(descendant.Position)
			local garage = string.sub(descendant.Name, -12) == "__GarageDoor"
			local width = math.max(descendant.Size.X, descendant.Size.Z)
			local top = center.Y + descendant.Size.Y / 2 + half.Y
			local wall, along = nearestWall(center)
			if not garage then
				top = descendant.Size.Y + 0.3
				width = math.max(width, 4) + 0.6
				if markers.parking and wall == "Front" then
					along = box:PointToObjectSpace(markers.parking.Position).X
				end
			end
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

-- How far a part reaches along `frame`'s Z axis: (nearest, furthest).
local function zRange(piece: BasePart, frame: CFrame): (number, number)
	local low, high = math.huge, -math.huge
	local half = piece.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = frame:PointToObjectSpace(piece.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
				low = math.min(low, corner.Z)
				high = math.max(high, corner.Z)
			end
		end
	end
	return low, high
end

-- Pulls the truck (and its trailer) forward off `parking`, if it has to, so there's WALKWAY
-- between the back of it (its open tailgate or ramp) and the front of the building. Parking
-- markers put the truck's middle on the spot, which leaves its open tailgate against the wall.
-- In `parking`'s space the truck faces -Z and the building is behind it, at +Z.
local function leaveWalkway(truck: Model, parking: CFrame, building: Model)
	-- The building's front: its frontmost wall, or the front of the whole model for one without
	-- walls of its own (the older, solid buildings).
	local front = math.huge
	for _, descendant in building:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(descendant.Name, "__Walls", 1, true) then
			front = math.min(front, (zRange(descendant, parking)))
		end
	end
	if front == math.huge then
		for _, descendant in building:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				front = math.min(front, (zRange(descendant, parking)))
			end
		end
	end
	local back = -math.huge
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local _, far = zRange(descendant, parking)
			back = math.max(back, far)
		end
	end
	local short = WALKWAY - (front - back)
	if front < math.huge and back > -math.huge and short > 0 then
		truck:PivotTo(truck:GetPivot() + parking.LookVector * short)
	end
end

-- Where a plot's truck ends up when it pulls out: straight ahead into the street.
local function streetFrame(plot): CFrame
	local home: CFrame = plot.truckHome
	local ahead = plot.cframe:PointToObjectSpace(home.Position).Z + plot.depth / 2 + 12
	return home + home.LookVector * ahead
end

-- Where something stands, as a rectangle in plot space (see DecorPlacement), grown by `margin`.
local function plotRect(origin: CFrame, frame: CFrame, size: Vector3, margin: number)
	local relative = origin:ToObjectSpace(frame)
	local look = relative.LookVector
	return {
		x = relative.Position.X,
		z = relative.Position.Z,
		turn = math.atan2(-look.X, -look.Z),
		width = size.X + margin * 2,
		depth = size.Z + margin * 2,
	}
end

-- Where decorations can't go on a plot: the driveway, the building, and everything standing
-- around it (desk, workbench, sign, storage out front, where delivery boxes stand). Saved on the
-- plot and on its model (attribute DecorArea, JSON) so the client can colour its ghost.
local function decorArea(plot, model: Model)
	local origin = plot.cframe
	local blocked = {}
	local function block(instance: Instance)
		if instance:IsA("Model") then
			local frame, size = instance:GetBoundingBox()
			table.insert(blocked, plotRect(origin, frame, size, DECOR_CLEARANCE))
		elseif instance:IsA("BasePart") and not (instance.Transparency >= 1 and not instance.CanCollide) then
			table.insert(blocked, plotRect(origin, instance.CFrame, instance.Size, DECOR_CLEARANCE))
		end
	end
	for _, child in model:GetChildren() do
		if child.Name == "Storage" then
			for _, fixture in child:GetChildren() do
				block(fixture)
			end
		elseif child.Name ~= "CrewTruck" and child.Name ~= "Deliveries" then
			block(child)
		end
	end
	if plot.deliveryFrame then
		local patch = plot.deliveryFrame * CFrame.new(DELIVERY_PATCH.x, 0, DELIVERY_PATCH.z)
		table.insert(blocked, plotRect(origin, patch, Vector3.new(DELIVERY_PATCH.width, 0, DELIVERY_PATCH.depth), 0))
	end
	local lawn = if plot.lawnFrame and plot.lawnSize then plotRect(origin, plot.lawnFrame, plot.lawnSize, 0) else nil
	plot.decor = { width = plot.width, depth = plot.depth, blocked = blocked, lawn = lawn }
	model:SetAttribute("PlotFrame", origin)
	model:SetAttribute("DecorArea", HttpService:JSONEncode(plot.decor))
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
	-- Older buildings get their deliveries out front on the right of the driveway, clear of the lawn.
	plot.deliveryFrame = markers.delivery or at(16, 0, math.min(2, frontZ - 2))

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
	-- Machines are set down in front of it to be worked on, and hand tools go in its vise.
	ServiceSpots.add(bench, ServiceSpots.forBench(bench))

	-- Grandma June on her porch rocker beside the shop, looking out over the driveway.
	local buildingRight = origin:PointToObjectSpace(buildingBox.Position).X + buildingSize.X / 2
	local juneZ = frontZ - JUNE_AHEAD
	-- The delivery boxes' patch, in plot space, which her porch keeps clear of.
	local patchLow, patchHigh = nil, nil
	if plot.deliveryFrame then
		local patch = plot.deliveryFrame * CFrame.new(DELIVERY_PATCH.x, 0, DELIVERY_PATCH.z)
		for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			local point = origin:PointToObjectSpace(
				patch * Vector3.new(corner.X * DELIVERY_PATCH.width / 2, 0, corner.Z * DELIVERY_PATCH.depth / 2)
			)
			patchLow = if patchLow then patchLow:Min(point) else point
			patchHigh = if patchHigh then patchHigh:Max(point) else point
		end
	end
	-- Where her porch (or rocker) goes across the plot, and whether it fits there.
	local function juneSpot(withPorch: boolean): (number, boolean)
		local foot = GrandmaJune.footprint(withPorch)
		local cos, sin = math.abs(math.cos(JUNE_TURN)), math.abs(math.sin(JUNE_TURN))
		local half = Vector2.new(foot.X * cos + foot.Y * sin, foot.X * sin + foot.Y * cos) / 2
		local x = buildingRight + JUNE_GAP + half.X
		if not markers.delivery then
			x = math.max(x, JUNE_PAST_BOXES + half.X)
		end
		-- Past the delivery patch, if it would stand on it.
		if
			patchLow
			and patchHigh
			and x - half.X < patchHigh.X
			and x + half.X > patchLow.X
			and juneZ - half.Y < patchHigh.Z
			and juneZ + half.Y > patchLow.Z
		then
			x = patchHigh.X + 1 + half.X
		end
		local fits = x + half.X <= plot.width / 2 - JUNE_EDGE
		return math.min(x, plot.width / 2 - JUNE_EDGE - half.X), fits
	end
	local withPorch = GrandmaJune.hasPorch()
	local juneX, fits = juneSpot(withPorch)
	if withPorch and not fits then
		withPorch = false
		juneX = juneSpot(false)
	end
	local june, porch = GrandmaJune.build(at(juneX, 0, juneZ) * CFrame.Angles(0, JUNE_TURN, 0), withPorch)
	june:SetAttribute("OwnerUserId", owner.UserId)
	june.Parent = model
	if porch then
		porch.Parent = model
	end

	local truck = Assets.truck(data.equipped.Truck or Items.Catalog.Truck[1].id, data.equipped.Trailer)
	-- Their Robux paint job, if they've put one on (see Premium.luau).
	Premium.applyPaint(truck, Premium.paintFor(data.premium))
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
	-- Parked with the tailgate down (and the trailer's ramp), ready to load, with room to walk
	-- between it and the building.
	Openings.set(truck, true)
	leaveWalkway(truck, parking, building)
	plot.truckHome = truck:GetPivot()

	-- The driveway, from the street to the door, under the truck. The lawn keeps clear of it.
	local truckBox, truckSize = truck:GetBoundingBox()
	local truckAt = origin:PointToObjectSpace(truckBox.Position)
	local drivewayWidth = math.max(DRIVEWAY_WIDTH, math.min(truckSize.X, truckSize.Z) + 2)
	local drivewayLength = frontZ + plot.depth / 2
	part(model, {
		Name = "Driveway",
		Size = Vector3.new(drivewayWidth, 0.1, drivewayLength),
		CFrame = at(truckAt.X, 0.05, frontZ - drivewayLength / 2),
		Color = Color3.fromRGB(170, 170, 165),
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	local lawnRight = math.min(LAWN_CENTER.X + LAWN_SIZE.X / 2, truckAt.X - drivewayWidth / 2 - LAWN_GAP)
	plot.lawnFrame, plot.lawnSize = at(lawnRight - LAWN_SIZE.X / 2, 0, LAWN_CENTER.Z), LAWN_SIZE
	-- The curb mailbox, where the day's contracts are (see DailyService): at the driveway's street
	-- end on the right, facing the street. A plain prop, not a decoration (no DecorId, so nobody
	-- buys, moves or loses it), though decorations keep clear of it like anything else on the plot.
	local mailbox = Assets.prop("CurbMailbox")
	Assets.anchor(mailbox)
	Assets.placeOnGround(
		mailbox,
		at(truckAt.X + drivewayWidth / 2 + MAILBOX_BESIDE, 0, -plot.depth / 2 + MAILBOX_FROM_STREET)
	)
	mailbox.Name = "CurbMailbox"
	mailbox.Parent = model
	interactable(mailbox, "OpenPanel", "Check the mail", "Mailbox", { OpensPanel = "Contracts" })
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
	-- The streak's pennant, once they've earned it (see RefreshPennant). The truck is measured by
	-- now, and the pennant leaves its pivot alone.
	if WorldService:HasPennant(owner) then
		Assets.addPennant(truck)
	end
	decorArea(plot, model)
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
-- Where the crew stands at their business: on the right of the driveway, facing the shop.
function WorldService:GetHomeCFrame(player: Player, index: number?): CFrame
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local base = if plot then plot.cframe * CFrame.new(12, 3.5, -24) * CFrame.Angles(0, math.pi, 0) else spawnCFrame
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

-- Where decorations may go on this player's own plot: its frame (plot space is relative to it)
-- and its DecorPlacement area ({ width, depth, blocked, lawn }).
function WorldService:GetDecorArea(player: Player): (CFrame?, any)
	local plot = playerPlots[player]
	if not (plot and plot.model and plot.decor) then
		return nil, nil
	end
	return plot.cframe, plot.decor
end

-- The plot's DecorArea as saved on its model (JSON), to tell when it changed.
function WorldService:GetDecorAreaRaw(player: Player): string?
	local plot = playerPlots[player]
	local raw = plot and plot.model and plot.model:GetAttribute("DecorArea")
	return if typeof(raw) == "string" then raw else nil
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

-- Whether this player has flown the streak's pennant: day 7 of a streak gives the flag
-- (Config/Streak, DailyService). Read from the save, so WorldService needs nothing from DailyService.
function WorldService:HasPennant(player: Player): boolean
	local data = DataService:Get(player)
	local flags = data and data.flags
	return flags ~= nil and flags.TruckPennant == true
end

-- Puts the pennant on this player's truck if they've earned it, and does nothing if they haven't or
-- it's there already. DailyService calls this when it pays the flag. The truck out on a trip counts:
-- it's the one that comes back. (buildPlot and JobService.buildSite add it to a truck as they build it.)
function WorldService:RefreshPennant(player: Player)
	local plot = playerPlots[player]
	local truck = plot and (plot.awayTruck or WorldService:GetPlotTruck(player))
	if truck and WorldService:HasPennant(player) then
		Assets.addPennant(truck)
	end
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
-- The building (business item id) of the player's crew's business.
function WorldService:GetCrewBusinessId(player: Player): string?
	local plot = playerPlots[getLeader(player)] or playerPlots[player]
	local ownerData = plot and plot.owner and DataService:Get(plot.owner)
	return if ownerData then ownerData.equipped.Business or "Shed" else nil
end

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

-- Waits, for at most `timeout` seconds, until the player has been given their business plot and
-- it's built (or there was none free for them).
function WorldService:WaitForPlot(player: Player, timeout: number)
	local deadline = os.clock() + timeout
	while not settled[player] and player.Parent == Players and os.clock() < deadline do
		task.wait()
	end
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
	for _, plot in plots do
		if plot.cframe.LookVector.Z > -0.99 then
			warn("A business plot doesn't face south (-Z): its front lawn's edges will be on the wrong sides")
			break
		end
	end
end

function WorldService:Start()
	local function onPlayerAdded(player: Player)
		if not DataService:WaitForData(player) or player.Parent ~= Players then
			return
		end
		for _, plot in plots do
			if not plot.owner then
				plot.owner = player
				playerPlots[player] = plot
				local started = os.clock()
				buildPlot(plot)
				-- Joining waits on this, so it's in the F9 console (the title card logs its side).
				print(string.format("[Load] %s's business built in %.2f s", player.Name, os.clock() - started))
				-- Start loading it on their device now. Their character may not even be in yet, and
				-- JobService only moves them in once it's loaded, so it's often there already.
				task.spawn(
					pcall,
					player.RequestStreamAroundAsync,
					player,
					WorldService:GetHomeCFrame(player).Position,
					FIRST_STREAM_TIMEOUT
				)
				break
			end
		end
		if not playerPlots[player] then
			warn(`No free business plot for {player.Name}. Lower Max Players or add more plots.`)
		end
		settled[player] = true
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
