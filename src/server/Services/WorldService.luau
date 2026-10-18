-- The town: a hardware store in the middle and a business plot for every player.
-- Your business (shed -> garage -> small office -> equipment yard) is where your crew hangs out
-- between jobs: check the job board, carry tools from storage to the truck, then drive off.
-- What's in storage is laid out by BusinessStorage.
--
-- To build the town yourself in Studio, make a Model named "Town" in Workspace with:
--   * a SpawnLocation
--   * a ProximityPrompt with attribute OpensPanel = "Shop" (the hardware store)
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

-- How close (studs from the plot's center) counts as "at your business".
local PLOT_RADIUS = 40
local PLOT_SIZE = Vector3.new(60, 1, 60)
-- How close you need to be to your business's storage to grab or put back a tool.
local STORAGE_REACH = 10
-- How close you need to be to the workbench to work on tools (a bit more than its prompt's reach).
local WORKBENCH_REACH = 14

local WorldService = {}
-- Fired with (owner) after a business plot is (re)built, so the truck bed can be refilled.
WorldService.PlotBuilt = Signal.new()

local businessFolder: Folder

local spawnCFrame = CFrame.new(0, 5, 0)
-- Each plot: { cframe = CFrame, owner = Player?, model = Model? }
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

local function prompt(target: BasePart, actionText: string, objectText: string, attributes)
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.ActionText = actionText
	proximityPrompt.ObjectText = objectText
	proximityPrompt.HoldDuration = 0
	proximityPrompt.MaxActivationDistance = 12
	proximityPrompt.RequiresLineOfSight = false
	for key, value in attributes do
		proximityPrompt:SetAttribute(key, value)
	end
	proximityPrompt.Parent = target
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

	local store = part(town, {
		Name = "HardwareStore",
		Size = Vector3.new(40, 16, 20),
		CFrame = CFrame.lookAt(Vector3.new(-70, 8, -30), Vector3.new(0, 8, -30)),
		Color = Color3.fromRGB(60, 90, 160),
	})
	sign(store, "HARDWARE STORE", Enum.NormalId.Front)
	local counter = part(town, {
		Name = "StoreCounter",
		Size = Vector3.new(4, 4, 12),
		Position = Vector3.new(-46, 2, -30),
		Color = Color3.fromRGB(120, 85, 50),
	})
	prompt(counter, "Shop", "Hardware Store", { OpensPanel = "Shop" })

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

	local signPost = part(model, {
		Name = "BusinessSign",
		Size = Vector3.new(16, 4, 0.5),
		CFrame = at(-18, 3, -26),
		Color = Color3.fromRGB(240, 240, 230),
	})
	sign(signPost, `{owner.DisplayName}'s Lawn Care`, Enum.NormalId.Front)

	local board = part(model, {
		Name = "JobBoard",
		Size = Vector3.new(8, 6, 0.6),
		CFrame = at(-16, 4, -4),
		Color = Color3.fromRGB(120, 85, 50),
	})
	sign(board, "JOBS", Enum.NormalId.Front)
	prompt(board, "View Jobs", "Job Board", { OpensPanel = "Jobs" })

	-- Each player sees their own tools in storage on their screen (see CarryController).
	BusinessStorage.build(model, origin, data.equipped.Business or "Shed")

	-- Where the crew fixes up their tools (see MaintenanceService).
	local bench = Assets.prop("Workbench")
	Assets.anchor(bench)
	Assets.placeAt(bench, at(10, 0, 11))
	bench.Name = "Workbench"
	bench.Parent = model
	local benchPart = bench.PrimaryPart or bench:FindFirstChildWhichIsA("BasePart", true)
	if benchPart then
		prompt(benchPart, "Work on Tools", "Workbench", { OpensPanel = "Workbench" })
	end

	local truck = Assets.truck(data.equipped.Truck or Items.Catalog.Truck[1].id, data.equipped.Trailer)
	Assets.anchor(truck)
	Assets.placeOnGround(truck, at(-4, 0, -18) * CFrame.Angles(0, math.rad(90), 0))
	truck.Name = "CrewTruck"
	truck.Parent = model
	prompt(truck.PrimaryPart :: BasePart, "Drive to Job", "Crew Truck", {
		Action = "DriveToJob",
		OwnerUserId = owner.UserId,
	})
	local bed = truck:FindFirstChild("BedArea", true)
	prompt(if bed and bed:IsA("BasePart") then bed else truck.PrimaryPart :: BasePart, "Load Tool", "Truck Bed", {
		Action = "LoadTool",
		OwnerUserId = owner.UserId,
	})

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
