-- Builds a customer's yard for a job and tracks how much of each task is done.
--
-- Layout of a job site, looking down (street at the bottom):
--
--        [            house            ]
--        [  hedges in the flower bed   ]
--        +-----------------------------+ +------+
--        |                             | |      |
--  weeds |   grass tiles to mow,       | | drive|
--  along |   leaf piles to rake,       |e| way  |
--  side  |   flowers/gnomes to AVOID   |d|      |
--        +-----------edge--------------+ +------+
--        ========= sidewalk ==========================
--        ============ road (truck parks here) ========

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Jobs = require(Shared.Config.Jobs)

local COLORS = {
	TallGrass = Color3.fromRGB(70, 125, 45),
	MowedLight = Color3.fromRGB(120, 200, 75),
	MowedDark = Color3.fromRGB(100, 178, 62),
	Neighborhood = Color3.fromRGB(85, 140, 60),
	Concrete = Color3.fromRGB(190, 190, 185),
	Road = Color3.fromRGB(55, 55, 60),
	Mulch = Color3.fromRGB(90, 60, 40),
	Weed = Color3.fromRGB(150, 170, 50),
	Dandelion = Color3.fromRGB(250, 220, 40),
	OvergrownEdge = Color3.fromRGB(80, 140, 50),
	CleanEdge = Color3.fromRGB(70, 50, 35),
	HedgeOvergrown = Color3.fromRGB(90, 150, 60),
	HedgeTrimmed = Color3.fromRGB(40, 100, 40),
	Leaves = {
		Color3.fromRGB(210, 110, 30),
		Color3.fromRGB(190, 60, 30),
		Color3.fromRGB(220, 170, 40),
	},
}

local HAZARD_NAMES = {
	FlowerPatch = "flower patch",
	GardenGnome = "garden gnome",
}

local SIDEWALK_DEPTH = 6
local DRIVEWAY_WIDTH = 12
local BED_DEPTH = 4

local LawnService = {}

local Lawn = {}
Lawn.__index = Lawn

local function makePart(parent: Instance, props): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Decoration that players walk through instead of bumping into.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- How each kind of target looks as it gets worked on. `fraction` goes from 0 (untouched) to 1 (done).
local VISUALS = {
	Mow = function(target, fraction: number)
		local height = target.startHeight + (GameConfig.MowedGrassHeight - target.startHeight) * fraction
		local part = target.part
		part.Size = Vector3.new(part.Size.X, height, part.Size.Z)
		part.Position = Vector3.new(part.Position.X, target.base + height / 2, part.Position.Z)
		if fraction >= 1 then
			part.Color = target.stripe
		end
	end,

	Edge = function(target, fraction: number)
		if fraction >= 1 then
			local part = target.part
			part.Color = COLORS.CleanEdge
			part.Material = Enum.Material.Ground
			part.Size = target.cleanSize
			part.CFrame = target.cleanCFrame
		end
	end,

	Weeds = function(target, fraction: number)
		if fraction >= 1 then
			target.part:Destroy()
			return
		end
		local scale = 1 - fraction * 0.7
		for _, piece in target.part:GetChildren() do
			if piece:IsA("BasePart") then
				local original = piece:GetAttribute("OriginalSize")
				piece.Size = original * Vector3.new(1, scale, 1)
			end
		end
	end,

	Leaves = function(target, fraction: number)
		if fraction >= 1 then
			target.part:Destroy()
			return
		end
		local part = target.part
		part.Size = target.startSize * (1 - fraction * 0.8)
		part.Position = Vector3.new(part.Position.X, target.base + part.Size.Y / 2, part.Position.Z)
	end,

	Hedge = function(target, fraction: number)
		local part = target.part
		local size = target.startSize:Lerp(target.trimmedSize, fraction)
		part.Size = size
		part.Position = Vector3.new(part.Position.X, target.base + size.Y / 2, part.Position.Z)
		part.Color = COLORS.HedgeOvergrown:Lerp(COLORS.HedgeTrimmed, fraction)
		if fraction >= 1 then
			part.Material = Enum.Material.Grass
		end
	end,
}

function Lawn:_addTarget(taskName: string, part: Instance, position: Vector3, reach: number, extra)
	local work = Jobs.TaskInfo[taskName].workPerTarget
	local target = extra or {}
	target.part = part
	target.position = position
	target.reach = reach
	target.work = work
	target.maxWork = work
	table.insert(self.targets[taskName], target)
	self.totals[taskName] += 1
	return target
end

function Lawn:_buildGround()
	local folder = self.folder
	local origin = self.origin
	local width, depth = self.width, self.depth

	-- Big grass base everything sits on. Its top is at y = 0 relative to the site.
	makePart(folder, {
		Name = "Ground",
		Size = Vector3.new(width + 160, 4, depth + 160),
		Position = origin + Vector3.new(width / 2, -2, depth / 2),
		Color = COLORS.Neighborhood,
		Material = Enum.Material.Grass,
	})
	makePart(folder, {
		Name = "Road",
		Size = Vector3.new(width + 160, 0.2, 20),
		Position = origin + Vector3.new(width / 2, 0.1, -SIDEWALK_DEPTH - 10),
		Color = COLORS.Road,
		Material = Enum.Material.Asphalt,
	})
	makePart(folder, {
		Name = "Sidewalk",
		Size = Vector3.new(width + 160, 0.3, SIDEWALK_DEPTH),
		Position = origin + Vector3.new(width / 2, 0.15, -SIDEWALK_DEPTH / 2),
		Color = COLORS.Concrete,
		Material = Enum.Material.Concrete,
	})
	makePart(folder, {
		Name = "Driveway",
		Size = Vector3.new(DRIVEWAY_WIDTH, 0.3, depth + BED_DEPTH),
		Position = origin + Vector3.new(width + DRIVEWAY_WIDTH / 2, 0.15, (depth + BED_DEPTH) / 2),
		Color = COLORS.Concrete,
		Material = Enum.Material.Concrete,
	})
	makePart(folder, {
		Name = "FlowerBed",
		Size = Vector3.new(width, 0.3, BED_DEPTH),
		Position = origin + Vector3.new(width / 2, 0.15, depth + BED_DEPTH / 2),
		Color = COLORS.Mulch,
		Material = Enum.Material.Ground,
	})

	-- The house sits behind the flower bed, front door facing the street.
	local house = Assets.prop("House")
	Assets.anchor(house)
	house:PivotTo(CFrame.new(origin))
	local boxCFrame, boxSize = house:GetBoundingBox()
	local wanted = origin + Vector3.new(width / 2, boxSize.Y / 2, depth + BED_DEPTH + boxSize.Z / 2)
	house:PivotTo(house:GetPivot() + (wanted - boxCFrame.Position))
	house.Parent = folder

	-- Mailbox with the address on it, at the end of the driveway.
	local post = makePart(folder, {
		Name = "Mailbox",
		Size = Vector3.new(0.4, 3.5, 0.4),
		Position = origin + Vector3.new(width + DRIVEWAY_WIDTH + 1.5, 1.75, -1),
		Color = Color3.fromRGB(110, 80, 50),
	})
	makePart(folder, {
		Name = "MailboxBox",
		Size = Vector3.new(1.2, 1.2, 2),
		Position = post.Position + Vector3.new(0, 2.1, 0),
		Color = Color3.fromRGB(60, 60, 70),
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = self.address
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = post
end

-- Picks tiles inside the lawn for flower patches and gnomes, spread apart from each other.
function Lawn:_pickHazardTiles(rng: Random, count: number)
	local picked = {}
	for _ = 1, count * 20 do
		if #picked >= count then
			break
		end
		local column = rng:NextInteger(1, math.max(1, self.columns - 2))
		local row = rng:NextInteger(1, math.max(1, self.rows - 2))
		local tooClose = false
		for _, other in picked do
			if math.abs(other.column - column) < 3 and math.abs(other.row - row) < 3 then
				tooClose = true
				break
			end
		end
		if not tooClose then
			table.insert(picked, { column = column, row = row })
		end
	end
	return picked
end

local function nearHazard(hazardTiles, column: number, row: number, distance: number): boolean
	for _, spot in hazardTiles do
		if math.abs(spot.column - column) <= distance and math.abs(spot.row - row) <= distance then
			return true
		end
	end
	return false
end

function Lawn:_buildGrass(rng: Random, hazardTiles)
	local tile = GameConfig.TileSize
	local grass = Instance.new("Folder")
	grass.Name = "Grass"
	grass.Parent = self.folder

	for column = 0, self.columns - 1 do
		local stripe = if column % 2 == 0 then COLORS.MowedLight else COLORS.MowedDark
		for row = 0, self.rows - 1 do
			if nearHazard(hazardTiles, column, row, 0) then
				continue
			end
			local height = GameConfig.TallGrassHeight * rng:NextNumber(0.85, 1.15)
			local position = self.origin + Vector3.new(column * tile + tile / 2, height / 2, row * tile + tile / 2)
			local part = makePart(grass, {
				Name = "Tile",
				Size = Vector3.new(tile, height, tile),
				Position = position,
				Color = COLORS.TallGrass,
				Material = Enum.Material.Grass,
			})
			ghost(part)
			-- Grass right next to flowers doesn't count against you if you leave it.
			local optional = nearHazard(hazardTiles, column, row, 1)
			self:_addTarget("Mow", part, position, tile * 0.35, {
				startHeight = height,
				base = self.origin.Y,
				stripe = stripe,
				optional = optional,
			})
			if optional then
				self.optional.Mow += 1
			end
		end
	end
end

function Lawn:_buildHazards(rng: Random, hazardTiles)
	local tile = GameConfig.TileSize
	local folder = Instance.new("Folder")
	folder.Name = "DoNotMow"
	folder.Parent = self.folder

	for _, spot in hazardTiles do
		local kind = if rng:NextNumber() < 0.25 then "GardenGnome" else "FlowerPatch"
		local position = self.origin + Vector3.new(spot.column * tile + tile / 2, 0, spot.row * tile + tile / 2)
		local model = Assets.prop(kind)
		Assets.anchor(model)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				ghost(descendant)
			end
		end
		Assets.placeOnGround(model, CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		model.Parent = folder
		table.insert(self.hazards, {
			model = model,
			kind = kind,
			name = HAZARD_NAMES[kind],
			position = position,
			reach = if kind == "GardenGnome" then 0.8 else 1.8,
			damaged = false,
		})
	end
end

local function wreck(hazard)
	local model = hazard.model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = descendant.Color:Lerp(Color3.fromRGB(90, 70, 50), 0.7)
			if descendant.Name == "Flower" then
				descendant.Size *= 0.5
				descendant.Position -= Vector3.new(0, 0.5, 0)
			end
		end
	end
	if hazard.kind == "GardenGnome" then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(85)))
	end
end

function Lawn:_buildEdges()
	local tile = GameConfig.TileSize
	local origin = self.origin
	local edges = Instance.new("Folder")
	edges.Name = "Edges"
	edges.Parent = self.folder

	local function addEdge(center: Vector3, size: Vector3, cleanSize: Vector3, cleanOffset: Vector3)
		local part = makePart(edges, {
			Name = "Edge",
			Size = size,
			Position = center,
			Color = COLORS.OvergrownEdge,
			Material = Enum.Material.Grass,
		})
		ghost(part)
		local cleanCFrame = CFrame.new(center + cleanOffset)
		self:_addTarget("Edge", part, center, 1, {
			cleanSize = cleanSize,
			cleanCFrame = cleanCFrame,
		})
	end

	-- Grass creeping over the sidewalk along the front...
	for column = 0, self.columns - 1 do
		addEdge(
			origin + Vector3.new(column * tile + tile / 2, 0.55, -0.4),
			Vector3.new(tile, 0.5, 1),
			Vector3.new(tile, 0.1, 0.3),
			Vector3.new(0, -0.27, 0.35)
		)
	end
	-- ...and over the driveway along the side.
	for row = 0, self.rows - 1 do
		addEdge(
			origin + Vector3.new(self.width + 0.4, 0.55, row * tile + tile / 2),
			Vector3.new(1, 0.5, tile),
			Vector3.new(0.3, 0.1, tile),
			Vector3.new(-0.35, -0.27, 0)
		)
	end
end

function Lawn:_buildHedges(rng: Random, count: number)
	local origin = self.origin
	local hedges = Instance.new("Folder")
	hedges.Name = "Hedges"
	hedges.Parent = self.folder

	local positions = {}
	-- Fill the flower bed first, then line the left side of the yard.
	local bedSlots = math.max(1, math.floor(self.width / 7))
	local inBed = math.min(count, bedSlots)
	for index = 1, inBed do
		table.insert(positions, Vector3.new(self.width * index / (inBed + 1), 0, self.depth + BED_DEPTH / 2))
	end
	local onSide = count - inBed
	for index = 1, onSide do
		table.insert(positions, Vector3.new(-2.5, 0, self.depth * index / (onSide + 1)))
	end

	for _, offset in positions do
		local startSize = Vector3.new(rng:NextNumber(4.5, 5.5), rng:NextNumber(5.5, 6.5), rng:NextNumber(3.5, 4.5))
		local position = origin + offset + Vector3.new(0, startSize.Y / 2, 0)
		local part = makePart(hedges, {
			Name = "Hedge",
			Size = startSize,
			Position = position,
			Color = COLORS.HedgeOvergrown,
			Material = Enum.Material.LeafyGrass,
		})
		self:_addTarget("Hedge", part, position, 2.5, {
			startSize = startSize,
			trimmedSize = Vector3.new(4, 3.5, 2.5),
			base = origin.Y,
		})
	end
end

function Lawn:_buildWeeds(rng: Random, count: number)
	local origin = self.origin
	local weeds = Instance.new("Folder")
	weeds.Name = "Weeds"
	weeds.Parent = self.folder

	for _ = 1, count do
		-- Weeds grow where mowers can't reach: by the house, along the side, and in driveway cracks.
		local spot = rng:NextInteger(1, 3)
		local offset
		if spot == 1 then
			offset = Vector3.new(rng:NextNumber(1, self.width - 1), 0, rng:NextNumber(self.depth - 1, self.depth + 3))
		elseif spot == 2 then
			offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(1, self.depth - 1))
		else
			offset = Vector3.new(self.width + rng:NextNumber(1, DRIVEWAY_WIDTH - 1), 0, rng:NextNumber(1, self.depth))
		end

		local clump = Instance.new("Model")
		clump.Name = "Weed"
		local base = origin + offset
		for leaf = 1, 3 do
			local height = rng:NextNumber(1.6, 2.6)
			local size = Vector3.new(0.3, height, 0.6)
			local part = makePart(clump, {
				Name = "Leaf",
				Size = size,
				CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0))
					* CFrame.Angles(0, math.rad(leaf * 60), math.rad(rng:NextNumber(-20, 20))),
				Color = COLORS.Weed,
				Material = Enum.Material.Grass,
			})
			part:SetAttribute("OriginalSize", size)
			ghost(part)
		end
		if rng:NextNumber() < 0.5 then
			local flower = makePart(clump, {
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.7, 0.7, 0.7),
				Position = base + Vector3.new(0, 2.4, 0),
				Color = COLORS.Dandelion,
			})
			flower:SetAttribute("OriginalSize", flower.Size)
			ghost(flower)
		end
		clump.Parent = weeds
		self:_addTarget("Weeds", clump, base, 0.5)
	end
end

function Lawn:_buildLeaves(rng: Random, count: number)
	local origin = self.origin
	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = self.folder

	for _ = 1, count do
		local startSize = Vector3.new(rng:NextNumber(3, 4.5), rng:NextNumber(1, 1.6), rng:NextNumber(3, 4.5))
		local position = origin
			+ Vector3.new(rng:NextNumber(2, self.width - 2), startSize.Y / 2, rng:NextNumber(2, self.depth - 2))
		local part = makePart(leaves, {
			Name = "LeafPile",
			Size = startSize,
			Position = position,
			Color = COLORS.Leaves[rng:NextInteger(1, #COLORS.Leaves)],
			Material = Enum.Material.LeafyGrass,
		})
		ghost(part)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		self:_addTarget("Leaves", part, position, 1.5, { startSize = startSize, base = origin.Y })
	end
end

-- Public API ---------------------------------------------------------------------------------

-- `origin` is the front-left corner of the lawn, where it meets the sidewalk.
function LawnService:Build(template, origin: Vector3, address: string)
	local rng = Random.new()
	local tile = GameConfig.TileSize

	local folder = Instance.new("Model")
	folder.Name = "JobSite"

	local lawn = setmetatable({
		folder = folder,
		origin = origin,
		address = address,
		columns = template.columns,
		rows = template.rows,
		width = template.columns * tile,
		depth = template.rows * tile,
		targets = {},
		totals = {},
		done = {},
		optional = {},
		hazards = {},
	}, Lawn)
	for _, taskName in Jobs.TaskOrder do
		lawn.targets[taskName] = {}
		lawn.totals[taskName] = 0
		lawn.done[taskName] = 0
		lawn.optional[taskName] = 0
	end

	local hazardTiles = lawn:_pickHazardTiles(rng, template.flowerPatches)
	lawn:_buildGround()
	lawn:_buildGrass(rng, hazardTiles)
	lawn:_buildHazards(rng, hazardTiles)
	if template.edging then
		lawn:_buildEdges()
	end
	lawn:_buildHedges(rng, template.hedges)
	lawn:_buildWeeds(rng, template.weeds)
	lawn:_buildLeaves(rng, template.leafPiles)

	-- The truck parks on the road facing along the curb; the crew hops out onto the sidewalk.
	lawn.truckCFrame = CFrame.new(origin + Vector3.new(lawn.width / 2, 0.2, -SIDEWALK_DEPTH - 5))
		* CFrame.Angles(0, math.rad(90), 0)
	lawn.spawnCFrame = CFrame.lookAt(
		origin + Vector3.new(lawn.width / 2, 3.5, -SIDEWALK_DEPTH / 2),
		origin + Vector3.new(lawn.width / 2, 3.5, lawn.depth / 2)
	)

	return lawn
end

-- Applies `amount` of work to every target of `taskName` within `radius` of `position`.
-- Returns true if anything changed.
function Lawn:ApplyWork(position: Vector3, radius: number, taskName: string, amount: number): boolean
	local targets = self.targets[taskName]
	if not targets then
		return false
	end

	local visual = VISUALS[taskName]
	local changed = false
	for _, target in targets do
		if target.work > 0 then
			local offset = target.position - position
			local flatDistance = Vector2.new(offset.X, offset.Z).Magnitude
			if flatDistance <= radius + target.reach then
				target.work = math.max(0, target.work - amount)
				visual(target, 1 - target.work / target.maxWork)
				if target.work == 0 then
					self.done[taskName] += 1
				end
				changed = true
			end
		end
	end
	return changed
end

-- Wrecks any flower patch or gnome within `radius` of `position`. Returns the ones that just got hit.
function Lawn:CheckHazards(position: Vector3, radius: number)
	local hits = {}
	for _, hazard in self.hazards do
		if not hazard.damaged then
			local offset = hazard.position - position
			if Vector2.new(offset.X, offset.Z).Magnitude <= radius + hazard.reach then
				hazard.damaged = true
				wreck(hazard)
				table.insert(hits, hazard)
			end
		end
	end
	return hits
end

-- The number of targets that must be done for a task to count as finished.
function Lawn:Needed(taskName: string): number
	return math.ceil((self.totals[taskName] - self.optional[taskName]) * GameConfig.CompletionThreshold)
end

function Lawn:IsComplete(): boolean
	for _, taskName in Jobs.TaskOrder do
		if self.done[taskName] < self:Needed(taskName) then
			return false
		end
	end
	return true
end

-- Progress for the HUD: { { task = "Mow", label = "...", done = 10, needed = 29 }, ... }
function Lawn:GetProgress()
	local progress = {}
	for _, taskName in Jobs.TaskOrder do
		if self.totals[taskName] > 0 then
			table.insert(progress, {
				task = taskName,
				label = Jobs.TaskInfo[taskName].label,
				tool = Jobs.TaskInfo[taskName].tool,
				done = math.min(self.done[taskName], self:Needed(taskName)),
				needed = self:Needed(taskName),
			})
		end
	end
	return progress
end

function Lawn:Destroy()
	self.folder:Destroy()
end

return LawnService
