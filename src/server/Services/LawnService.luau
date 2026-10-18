-- Builds a customer's yard for a job and tracks how much of each task is done.
--
-- Layout of a job site, looking down (street at the bottom):
--
--   fence [            house            ]
--     |   [  hedges in the flower bed   ]
--     |   +-----------------------------+ +------+
--     |   |                             | |      |
--  weeds  |   grass tiles to mow,       | | drive|
--  along  |   leaf piles to rake,       |e| way  |
--  side   |   flowers/gnomes to AVOID   |d|      |
--         +-----------edge--------------+ +------+
--         ========= sidewalk ==========================
--         ============ road (truck parks here) ========
--
-- Everything uses the Lawn Mowing kit (Assets.Kit) when it's there and falls back to blocks.
-- Grass is special: the server only tracks which tiles are mowed (see LawnGrid) and each client
-- draws the grass itself (see GrassController), which keeps big lawns cheap on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Jobs = require(Shared.Config.Jobs)
local LawnGrid = require(Shared.LawnGrid)

local COLORS = {
	Turf = Color3.fromRGB(70, 125, 45),
	Neighborhood = Color3.fromRGB(85, 140, 60),
	Concrete = Color3.fromRGB(190, 190, 185),
	Road = Color3.fromRGB(55, 55, 60),
	Mulch = Color3.fromRGB(90, 60, 40),
	Weed = Color3.fromRGB(150, 170, 50),
	OvergrownEdge = Color3.fromRGB(80, 140, 50),
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

local WEED_KINDS = { "Weed_Dandelion", "Weed_Broadleaf", "Weed_Clover", "Weed_Thistle", "Weed_DryTuft" }

local SIDEWALK_DEPTH = 6
local DRIVEWAY_WIDTH = 12
local BED_DEPTH = 4
-- The kit's curb and edge strip are 1 m (about 3.6 studs) long.
local CURB_LENGTH = 3.57

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

-- A kit piece, or a plain block with these props if the kit isn't in the game.
local function kitOrBlock(kitName: string, parent: Instance, blockProps): (BasePart, boolean)
	local part = Assets.kitPart(kitName)
	if part then
		part.Parent = parent
		return part, true
	end
	local block = makePart(parent, blockProps)
	ghost(block)
	return block, false
end

-- A kit piece stood on the ground, or nothing if the kit isn't in the game. For decoration only.
local function decorate(kitName: string, parent: Instance, ground: CFrame, scale: number?)
	local part = Assets.kitPart(kitName)
	if part then
		Assets.standOn(part, ground, part.Size * (scale or 1))
		part.Parent = parent
	end
	return part
end

-- Shrinks a target's part toward the ground. `scale` multiplies the size it started at.
local function shrink(target, scale: Vector3)
	Assets.standOn(target.part, target.ground, target.startSize * scale)
end

-- How each kind of target looks as it gets worked on. `fraction` goes from 0 (untouched) to 1 (done).
local VISUALS = {
	Mow = function(target, fraction: number)
		if fraction >= 1 then
			target.lawn:_setGrass(target.index, LawnGrid.MOWED)
		end
	end,

	-- The overgrown strip gets cut back until only the curb is left.
	Edge = function(target, fraction: number)
		if fraction >= 1 then
			target.part:Destroy()
		else
			shrink(target, Vector3.new(1, 1 - fraction * 0.6, 1))
		end
	end,

	Weeds = function(target, fraction: number)
		if fraction >= 1 then
			target.part:Destroy()
		else
			shrink(target, Vector3.one * (1 - fraction * 0.7))
		end
	end,

	-- Raked piles shrink, then get bagged up.
	Leaves = function(target, fraction: number)
		if fraction < 1 then
			shrink(target, Vector3.one * (1 - fraction * 0.8))
			return
		end
		local parent = target.part.Parent
		target.part:Destroy()
		if parent then
			decorate("Prop_YardWasteBag", parent, target.ground)
		end
	end,

	Hedge = function(target, fraction: number)
		local size = target.startSize:Lerp(target.trimmedSize, fraction)
		Assets.standOn(target.part, target.ground, size)
		if not target.isKit then
			target.part.Color = COLORS.HedgeOvergrown:Lerp(COLORS.HedgeTrimmed, fraction)
		end
	end,
}

function Lawn:_addTarget(taskName: string, part: BasePart?, position: Vector3, reach: number, extra)
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
	-- Darker turf under the customer's lawn, showing between grass clumps.
	local turf = makePart(folder, {
		Name = "Turf",
		Size = Vector3.new(width, 0.04, depth),
		Position = origin + Vector3.new(width / 2, 0, depth / 2),
		Color = COLORS.Turf,
		Material = Enum.Material.Grass,
	})
	ghost(turf)
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

-- A few kit props so yards don't look empty. Skipped entirely without the kit.
function Lawn:_buildDecor(rng: Random)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = self.folder
	local origin = self.origin
	local width, depth = self.width, self.depth

	-- A cedar fence down the left side of the yard, from the sidewalk to the house.
	local fenceLength = depth + BED_DEPTH
	local panels = math.max(1, math.ceil(fenceLength / 7.5))
	for index = 0, panels - 1 do
		local panel = Assets.kitPart("Fence_Cedar_2m")
		if not panel then
			break
		end
		local z = fenceLength * (index + 0.5) / panels
		local ground = CFrame.new(origin + Vector3.new(-5.5, 0, z)) * CFrame.Angles(0, math.pi / 2, 0)
		-- Stretch the panels a touch so they meet.
		Assets.standOn(panel, ground, Vector3.new(fenceLength / panels, panel.Size.Y, panel.Size.Z))
		panel.Parent = decor
	end

	-- Bin and hose up by the garage end of the driveway.
	local driveFar = origin + Vector3.new(width + DRIVEWAY_WIDTH - 1.5, 0.3, depth + BED_DEPTH - 2)
	decorate("Prop_WheelieBin", decor, CFrame.new(driveFar) * CFrame.Angles(0, math.pi / 2, 0))
	decorate("Prop_GardenHose_Coil", decor, CFrame.new(driveFar + Vector3.new(-3, 0, -3)))

	-- Rocks in the corners of the flower bed.
	for _, x in { 1.2, width - 1.2 } do
		local rock = if rng:NextNumber() < 0.5 then "Rock_Field_A" else "Rock_Field_B"
		decorate(
			rock,
			decor,
			CFrame.new(origin + Vector3.new(x, 0.3, depth + BED_DEPTH / 2))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		)
	end

	-- Cones on the road around where the truck parks.
	for _, x in { -18, 18 } do
		decorate("Prop_TrafficCone", decor, CFrame.new(origin + Vector3.new(width / 2 + x, 0.2, -SIDEWALK_DEPTH - 5)))
	end
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

-- Grass tiles are only data here. The "Grass" folder tells clients what to draw.
function Lawn:_buildGrass(hazardTiles)
	local tile = GameConfig.TileSize
	self.grassState = {}

	for column = 0, self.columns - 1 do
		for row = 0, self.rows - 1 do
			local index = LawnGrid.index(column, row, self.rows)
			if nearHazard(hazardTiles, column, row, 0) then
				self.grassState[index] = LawnGrid.EMPTY
				continue
			end
			self.grassState[index] = LawnGrid.TALL
			-- Grass right next to flowers doesn't count against you if you leave it.
			local optional = nearHazard(hazardTiles, column, row, 1)
			self:_addTarget("Mow", nil, LawnGrid.center(self.origin, tile, column, row), tile * 0.35, {
				lawn = self,
				index = index,
				optional = optional,
			})
			if optional then
				self.optional.Mow += 1
			end
		end
	end

	local grass = Instance.new("Folder")
	grass.Name = "Grass"
	grass:SetAttribute("Origin", self.origin)
	grass:SetAttribute("TileSize", tile)
	grass:SetAttribute("Columns", self.columns)
	grass:SetAttribute("Rows", self.rows)
	grass:SetAttribute("State", table.concat(self.grassState))
	grass.Parent = self.folder
	self.grassFolder = grass
end

function Lawn:_setGrass(index: number, state: string)
	self.grassState[index] = state
	self.grassDirty = true
end

function Lawn:_buildHazards(rng: Random, hazardTiles)
	local tile = GameConfig.TileSize
	local folder = Instance.new("Folder")
	folder.Name = "DoNotMow"
	folder.Parent = self.folder

	for _, spot in hazardTiles do
		local kind = if rng:NextNumber() < 0.25 then "GardenGnome" else "FlowerPatch"
		local position = LawnGrid.center(self.origin, tile, spot.column, spot.row)
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

-- A concrete curb along the sidewalk and driveway, with overgrown grass flopping over it that
-- the edger cuts back.
function Lawn:_buildEdges()
	local tile = GameConfig.TileSize
	local origin = self.origin
	local edges = Instance.new("Folder")
	edges.Name = "Edges"
	edges.Parent = self.folder

	-- `start` is one end of the run on the ground, `along` the unit direction it runs in.
	local function edgeRun(start: Vector3, along: Vector3, length: number, segments: number)
		local facing = CFrame.lookAt(Vector3.zero, along) * CFrame.Angles(0, math.pi / 2, 0)

		local curbs = math.max(1, math.ceil(length / CURB_LENGTH))
		for index = 0, curbs - 1 do
			local ground = CFrame.new(start + along * (length * (index + 0.5) / curbs)) * facing
			local curb, isKit = kitOrBlock("Curb_Concrete_1m", edges, {
				Name = "Curb",
				Color = COLORS.Concrete,
				Material = Enum.Material.Concrete,
			})
			local height = if isKit then curb.Size.Y else 0.5
			Assets.standOn(curb, ground, Vector3.new(length / curbs, height, if isKit then curb.Size.Z else 0.5))
		end

		for index = 0, segments - 1 do
			local center = start + along * (tile * (index + 0.5))
			local ground = CFrame.new(center) * facing
			local strip, isKit = kitOrBlock("Grass_EdgeStrip_1m", edges, {
				Name = "Overgrowth",
				Color = COLORS.OvergrownEdge,
				Material = Enum.Material.Grass,
			})
			local size = if isKit
				then Vector3.new(tile, strip.Size.Y * 0.8, strip.Size.Z * 1.2)
				else Vector3.new(tile, 0.8, 1)
			Assets.standOn(strip, ground, size)
			self:_addTarget("Edge", strip, center, 1, { ground = ground, startSize = size })
		end
	end

	-- Along the sidewalk at the front, then along the driveway on the right.
	edgeRun(origin + Vector3.new(0, 0, -0.3), Vector3.xAxis, self.width, self.columns)
	edgeRun(origin + Vector3.new(self.width + 0.3, 0, 0), Vector3.zAxis, self.depth, self.rows)
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
		local ground = CFrame.new(origin + offset) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0)
		local part, isKit = kitOrBlock("Shrub_Rounded", hedges, {
			Name = "Hedge",
			Color = COLORS.HedgeOvergrown,
			Material = Enum.Material.LeafyGrass,
		})
		if not isKit then
			-- Block hedges are solid; kit shrubs have no collision.
			part.CanCollide = true
		end
		Assets.standOn(part, ground, startSize)
		self:_addTarget("Hedge", part, ground.Position, 2.5, {
			ground = ground,
			startSize = startSize,
			trimmedSize = Vector3.new(4, 3.5, 2.5),
			isKit = isKit,
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

		local base = origin + offset
		local ground = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local part, isKit = kitOrBlock(WEED_KINDS[rng:NextInteger(1, #WEED_KINDS)], weeds, {
			Name = "Weed",
			Color = COLORS.Weed,
			Material = Enum.Material.Grass,
		})
		-- Kit weeds are life-size, which is tiny next to a player, so blow them up a bit.
		local size = if isKit then part.Size * rng:NextNumber(1.6, 2.2) else Vector3.new(1, rng:NextNumber(1.6, 2.6), 1)
		Assets.standOn(part, ground, size)
		part:SetAttribute("OriginalSize", size)
		self:_addTarget("Weeds", part, base, 0.5, { ground = ground, startSize = size })
	end
end

function Lawn:_buildLeaves(rng: Random, count: number)
	local origin = self.origin
	local leaves = Instance.new("Folder")
	leaves.Name = "Leaves"
	leaves.Parent = self.folder

	for _ = 1, count do
		local base = origin + Vector3.new(rng:NextNumber(2, self.width - 2), 0, rng:NextNumber(2, self.depth - 2))
		local ground = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		-- The kit has no leaf pile, so a big clippings pile stands in for one.
		local part, isKit = kitOrBlock("Grass_Clippings_Pile", leaves, {
			Name = "LeafPile",
			Color = COLORS.Leaves[rng:NextInteger(1, #COLORS.Leaves)],
			Material = Enum.Material.LeafyGrass,
		})
		if not isKit then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		local startSize = Vector3.new(rng:NextNumber(3, 4.5), rng:NextNumber(0.8, 1.4), rng:NextNumber(3, 4.5))
		Assets.standOn(part, ground, startSize)
		self:_addTarget("Leaves", part, base, 1.5, { ground = ground, startSize = startSize })
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
	lawn:_buildGrass(hazardTiles)
	lawn:_buildHazards(rng, hazardTiles)
	if template.edging then
		lawn:_buildEdges()
	end
	lawn:_buildHedges(rng, template.hedges)
	lawn:_buildWeeds(rng, template.weeds)
	lawn:_buildLeaves(rng, template.leafPiles)
	lawn:_buildDecor(rng)

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

	-- One attribute update per tick, however many tiles just got mowed.
	if self.grassDirty then
		self.grassDirty = false
		self.grassFolder:SetAttribute("State", table.concat(self.grassState))
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
