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
local Items = require(Shared.Config.Items)
local Signal = require(Shared.Signal)

local BusinessStorage = require(script.Parent.Parent.BusinessStorage)
local DataService = require(script.Parent.DataService)
local Openings = require(script.Parent.Parent.Openings)

-- How close (studs from the plot's center) counts as "at your business".
local PLOT_RADIUS = 40
local PLOT_SIZE = Vector3.new(60, 1, 60)
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
-- Each plot: { cframe = CFrame, owner = Player?, model = Model?, deliveryFrame = CFrame? }
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
		Size = Vector3.new(520, 2, 420),
		Position = Vector3.new(0, -1, -30),
		Color = Color3.fromRGB(90, 150, 70),
		Material = Enum.Material.Grass,
	})
	for _, z in { 20, -80 } do
		part(town, {
			Name = "Road",
			Size = Vector3.new(520, 0.2, 24),
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
	for _, x in { -210, -140, -70, 70, 140, 210 } do
		for _, row in { { z = 70, faces = 20 }, { z = -130, faces = -80 } } do
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
	Assets.placeOnGround(building, at(0, 0, 14))
	building.Parent = model
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
		CFrame = at(-18, 3, -26),
		Color = Color3.fromRGB(240, 240, 230),
	})
	sign(signPost, `{owner.DisplayName}'s Lawn Care`, Enum.NormalId.Front)

	-- The job computer: jobs, orders, upgrades and the crew, at the desk (see ComputerController).
	local businessItem = Items.get("Business", data.equipped.Business or "Shed") or Items.Catalog.Business[1]
	local desk = Assets.prop(businessItem.desk)
	Assets.anchor(desk)
	-- Older buildings can't be walked into, so the desk stands out front, facing the street.
	Assets.placeAt(desk, markers.desk or at(-14, 0, -2))
	desk.Name = "Desk"
	desk.Parent = model
	interactable(desk, "UseComputer", "Use Computer", "Shop Computer", {})
	plot.deliveryFrame = markers.delivery or at(9, 0, 1)

	-- Each player sees their own tools in storage on their screen (see CarryController).
	BusinessStorage.build(model, origin, data.equipped.Business or "Shed", markers)

	-- Where the crew fixes up their tools (see MaintenanceService).
	local bench = Assets.prop("Workbench")
	Assets.anchor(bench)
	Assets.placeAt(bench, if markers.mounts.Workbench then markers.mounts.Workbench[1] else at(10, 0, 11))
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
	Assets.placeOnGround(truck, markers.parking or at(-4, 0, -18) * CFrame.Angles(0, math.rad(90), 0))
	-- At the door, a trailer's ramp goes where the tailgate would be, with the truck ahead of it.
	local trailer = truck:FindFirstChild("Trailer")
	if markers.parking and trailer and trailer:IsA("Model") then
		local _, trailerSize = trailer:GetBoundingBox()
		truck:PivotTo(truck:GetPivot() + markers.parking.LookVector * (trailerSize.Z + 1))
	end
	truck.Name = "CrewTruck"
	truck.Parent = model
	-- Parked with the tailgate down (and the trailer's ramp), ready to load.
	Openings.set(truck, true)
	-- Carried tools go in its bed by looking at the bed (see InteractController).
	interactable(truck, "DriveToJob", "Drive to Job", "Crew Truck", { OwnerUserId = owner.UserId })

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
	local base = if plot then plot.cframe * CFrame.new(0, 3.5, -6) else spawnCFrame
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
	local offset = root.Position - plot.cframe.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= PLOT_RADIUS
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
				table.insert(plots, { cframe = pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0) })
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
			buildPlot(plot)
		end
	end)
end

return WorldService
