-- Builds a customer's yard for a job and tracks how much of each task is done.
--
-- Layout of a job site, looking down (street at the bottom):
--
--  side      fence [            house            ]
--  garden      |   [  hedges in the flower bed   ]
--  plots       |   +-----------------------------+ +------+
--  (pots,      |   |                             | |      |
--  bulbs,   weeds  |   grass tiles to mow,       | | drive|
--  roses,   along  |   leaf piles to rake,       |e| way  |
--  beds...) side   |   flowers/gnomes to AVOID   |d|      |
--                  +-----------edge--------------+ +------+
--                  ========= sidewalk ==========================
--                  ============ road (truck parks here) ========
--
-- Everything uses the Lawn Mowing kit (Assets.Kit) when it's there and falls back to blocks.
-- Grass is special: the server only tracks which tiles are mowed (see LawnGrid) and each client
-- draws the grass itself (see GrassController), which keeps big lawns cheap on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local LawnGrid = require(Shared.LawnGrid)
local TaskTypes = require(Shared.Config.TaskTypes)
local Tools = require(Shared.Config.Tools)

local COLORS = {
	Turf = Color3.fromRGB(70, 125, 45),
	Neighborhood = Color3.fromRGB(85, 140, 60),
	Concrete = Color3.fromRGB(190, 190, 185),
	Road = Color3.fromRGB(55, 55, 60),
	Mulch = Color3.fromRGB(90, 60, 40),
	Weed = Color3.fromRGB(150, 170, 50),
	Soil = Color3.fromRGB(70, 50, 35),
	DrySoil = Color3.fromRGB(165, 135, 100),
	Patio = Color3.fromRGB(175, 165, 150),
	Leaf = Color3.fromRGB(70, 130, 50),
	Wilted = Color3.fromRGB(150, 150, 70),
	Dead = Color3.fromRGB(110, 80, 50),
	Terracotta = Color3.fromRGB(190, 95, 60),
	NurseryPot = Color3.fromRGB(30, 30, 30),
	Clay = Color3.fromRGB(170, 100, 55),
	Hardpan = Color3.fromRGB(120, 110, 100),
	Stone = Color3.fromRGB(140, 140, 135),
	Bark = Color3.fromRGB(95, 70, 45),
	Sod = Color3.fromRGB(80, 140, 55),
	Gravel = Color3.fromRGB(160, 155, 145),
	Fertilizer = Color3.fromRGB(225, 235, 210),
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

-- How each kind of yard target looks as it gets worked on. `fraction` goes from 0 (untouched)
-- to 1 (done). The kinds match TaskTypes' `target` field.
local VISUALS = {
	Grass = function(target, fraction: number)
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

	Weed = function(target, fraction: number)
		if fraction >= 1 then
			target.part:Destroy()
		else
			shrink(target, Vector3.one * (1 - fraction * 0.7))
		end
	end,

	-- Raked piles shrink, then get bagged up.
	LeafPile = function(target, fraction: number)
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

	-- Pulled whole, leaving a little patch of bare soil.
	Dandelion = function(target, fraction: number)
		if fraction < 1 then
			shrink(target, Vector3.one * (1 - fraction * 0.5))
			return
		end
		local parent = target.part.Parent
		target.part:Destroy()
		if parent then
			local hole = makePart(parent, {
				Name = "Hole",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, 0.8, 0.8),
				CFrame = target.ground * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = COLORS.Soil,
				Material = Enum.Material.Ground,
			})
			ghost(hole)
		end
	end,
}

function Lawn:_addTarget(task, part: BasePart?, position: Vector3, reach: number, extra)
	local work = task.type.workPerTarget
	local target = extra or {}
	target.kind = task.type.target
	target.part = part
	target.position = position
	target.reach = reach
	target.work = work
	target.maxWork = work
	table.insert(task.targets, target)
	task.total += 1
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

	-- A cedar fence down the left side of the yard, from the sidewalk to the house (unless the
	-- side garden is there).
	local fenceLength = depth + BED_DEPTH
	local panels = if self.garden then 0 else math.max(1, math.ceil(fenceLength / 7.5))
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
-- Without a mowing task the lawn is already mown and there's nothing to do on it.
function Lawn:_buildGrass(task, hazardTiles)
	local tile = GameConfig.TileSize
	self.grassState = {}

	for column = 0, self.columns - 1 do
		for row = 0, self.rows - 1 do
			local index = LawnGrid.index(column, row, self.rows)
			if nearHazard(hazardTiles, column, row, 0) then
				self.grassState[index] = LawnGrid.EMPTY
				continue
			end
			if not task then
				self.grassState[index] = LawnGrid.MOWED
				continue
			end
			self.grassState[index] = LawnGrid.TALL
			-- Grass right next to flowers doesn't count against you if you leave it.
			local optional = nearHazard(hazardTiles, column, row, 1)
			self:_addTarget(task, nil, LawnGrid.center(self.origin, tile, column, row), tile * 0.35, {
				lawn = self,
				index = index,
				optional = optional,
			})
			if optional then
				task.optional += 1
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
function Lawn:_buildEdges(task)
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
			self:_addTarget(task, strip, center, 1, { ground = ground, startSize = size })
		end
	end

	-- Along the sidewalk at the front, then along the driveway on the right.
	edgeRun(origin + Vector3.new(0, 0, -0.3), Vector3.xAxis, self.width, self.columns)
	edgeRun(origin + Vector3.new(self.width + 0.3, 0, 0), Vector3.zAxis, self.depth, self.rows)
end

function Lawn:_buildHedges(task, rng: Random, count: number)
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
		self:_addTarget(task, part, ground.Position, 2.5, {
			ground = ground,
			startSize = startSize,
			trimmedSize = Vector3.new(4, 3.5, 2.5),
			isKit = isKit,
		})
	end
end

function Lawn:_buildWeeds(task, rng: Random, count: number)
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
		self:_addTarget(task, part, base, 0.5, { ground = ground, startSize = size })
	end
end

function Lawn:_buildLeaves(task, rng: Random, count: number)
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
		self:_addTarget(task, part, base, 1.5, { ground = ground, startSize = startSize })
	end
end

-- The side garden ----------------------------------------------------------------------------
-- Garden jobs (pots, bulbs, beds, roses...) each get a plot left of the yard. Each kind of
-- target has a look before and after: `build` makes one standing at `ground` and returns its main
-- part plus whatever its `visual` needs; `visual` shows it `fraction` (0-1) done.

local GARDEN_START_X = -7
local GARDEN_GAP = 1.5

local function block(parent: Instance, props): BasePart
	local part = makePart(parent, props)
	ghost(part)
	return part
end

-- A flat round patch lying on `ground`.
local function disc(parent: Instance, ground: CFrame, diameter: number, color: Color3, height: number?): BasePart
	local thick = height or 0.06
	return block(parent, {
		Name = "Patch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thick, diameter, diameter),
		CFrame = ground * CFrame.new(0, thick / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Ground,
	})
end

local function ball(parent: Instance, position: Vector3, size: number, color: Color3): BasePart
	return block(parent, {
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Position = position,
		Color = color,
		Material = Enum.Material.LeafyGrass,
	})
end

local function stick(parent: Instance, from: Vector3, to: Vector3, thickness: number, color: Color3): BasePart
	return block(parent, {
		Name = "Stem",
		Size = Vector3.new(thickness, (to - from).Magnitude, thickness),
		CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(math.pi / 2, 0, 0),
		Color = color,
		Material = Enum.Material.Wood,
	})
end

-- A small shrub: the kit's rounded shrub, or a green ball.
local function bush(parent: Instance, ground: CFrame, size: Vector3, color: Color3): BasePart
	local part, isKit = kitOrBlock("Shrub_Rounded", parent, {
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Color = color,
		Material = Enum.Material.LeafyGrass,
	})
	Assets.standOn(part, ground, if isKit then size else Vector3.one * size.X)
	return part
end

-- Sticks poking out of the top of a shrub (leggy growth, long canes or dead wood).
local function sprigs(
	parent: Instance,
	ground: CFrame,
	height: number,
	count: number,
	length: number,
	color: Color3,
	rng: Random
)
	local list = {}
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local base = (ground * CFrame.new(math.cos(angle) * 0.5, height * 0.8, math.sin(angle) * 0.5)).Position
		local tip = base + Vector3.new(math.cos(angle) * 0.6, length, math.sin(angle) * 0.6)
		table.insert(list, stick(parent, base, tip, 0.12, color))
	end
	return list
end

local function destroyAll(parts)
	for _, part in parts do
		part:Destroy()
	end
end

local GARDEN = {
	-- A nursery plant in a little black pot, next to the empty container it's going into.
	Pot = {
		spacing = 3.4,
		base = COLORS.Patio,
		build = function(parent, ground: CFrame)
			block(parent, {
				Name = "Container",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.3, 1.5, 1.5),
				CFrame = ground * CFrame.new(0.8, 0.65, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = COLORS.Terracotta,
				Material = Enum.Material.Slate,
			})
			local pot = block(parent, {
				Name = "NurseryPot",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 0.9, 0.9),
				CFrame = ground * CFrame.new(-0.8, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = COLORS.NurseryPot,
			})
			local plant = ball(parent, (ground * CFrame.new(-0.8, 1.2, 0)).Position, 1, COLORS.Leaf)
			return pot, { plant = plant, into = (ground * CFrame.new(0.8, 1.6, 0)).Position }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				target.plant.Position = target.into
				target.part:Destroy()
			end
		end,
	},

	-- A neat hole in the bed for each seedling plug.
	Plug = {
		spacing = 1.8,
		columns = 4,
		base = COLORS.Soil,
		build = function(parent, ground: CFrame)
			return disc(parent, ground, 0.6, Color3.fromRGB(45, 32, 22), 0.04), {}
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 and target.parent then
				ball(target.parent, (target.ground * CFrame.new(0, 0.3, 0)).Position, 0.5, COLORS.Leaf)
			end
		end,
	},

	-- A perennial dug up with its root ball, next to the hole it's moving to.
	Perennial = {
		spacing = 4,
		columns = 3,
		base = COLORS.Soil,
		build = function(parent, ground: CFrame)
			local hole = disc(parent, ground * CFrame.new(1, 0, 0), 1.6, Color3.fromRGB(40, 28, 20), 0.04)
			local roots = ball(parent, (ground * CFrame.new(-1, 0.6, 0)).Position, 1.2, COLORS.Dead)
			local plant = ball(parent, (ground * CFrame.new(-1, 1.5, 0)).Position, 1.8, COLORS.Leaf)
			return hole, { roots = roots, plant = plant }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				local spot = target.ground * CFrame.new(1, 0, 0)
				target.roots.Position = (spot * CFrame.new(0, 0.2, 0)).Position
				target.plant.Position = (spot * CFrame.new(0, 1, 0)).Position
				target.part:Destroy()
			end
		end,
	},

	-- A marker flag where each bulb goes.
	Bulb = {
		spacing = 1.8,
		columns = 4,
		base = COLORS.Soil,
		build = function(parent, ground: CFrame)
			local pole =
				stick(parent, ground.Position, ground.Position + Vector3.new(0, 1.2, 0), 0.08, Color3.new(1, 1, 1))
			local flag = block(parent, {
				Name = "Flag",
				Size = Vector3.new(0.45, 0.3, 0.04),
				CFrame = ground * CFrame.new(0.24, 1.05, 0),
				Color = Color3.fromRGB(230, 60, 60),
			})
			return pole, { flag = flag }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				target.flag:Destroy()
				target.part:Destroy()
				if target.parent then
					disc(target.parent, target.ground, 0.8, COLORS.Soil, 0.15)
				end
			end
		end,
	},

	-- A furrow in the vegetable bed for each row of seed.
	SeedRow = {
		cell = Vector2.new(1.6, 6),
		oneRow = true,
		base = COLORS.Soil,
		build = function(parent, ground: CFrame)
			return block(parent, {
				Name = "Furrow",
				Size = Vector3.new(0.45, 0.06, 5.4),
				CFrame = ground * CFrame.new(0, 0.03, 0),
				Color = Color3.fromRGB(40, 28, 20),
				Material = Enum.Material.Ground,
			}),
				{}
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 and target.parent then
				target.part.Color = COLORS.Soil:Lerp(Color3.new(1, 1, 1), 0.1)
				target.part.Size = Vector3.new(0.6, 0.15, 5.4)
				target.part.CFrame = target.ground * CFrame.new(0, 0.075, 0)
				stick(
					target.parent,
					(target.ground * CFrame.new(0, 0, -2.9)).Position,
					(target.ground * CFrame.new(0, 0.9, -2.9)).Position,
					0.1,
					Color3.new(1, 1, 1)
				)
			end
		end,
		reach = 2.6,
	},

	-- A patch of pale, crusted-over soil that turns dark and crumbly once it's loosened.
	CrustedSoil = {
		spacing = 3,
		columns = 3,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame)
			return block(parent, {
				Name = "Crust",
				Size = Vector3.new(2.6, 0.12, 2.6),
				CFrame = ground * CFrame.new(0, 0.06, 0),
				Color = COLORS.DrySoil,
				Material = Enum.Material.Slate,
			}),
				{}
		end,
		visual = function(target, fraction: number)
			target.part.Color = COLORS.DrySoil:Lerp(COLORS.Soil, fraction)
			if fraction >= 1 then
				target.part.Material = Enum.Material.Ground
			end
		end,
		reach = 1.4,
	},

	-- Young weeds coming up in a bed.
	Sprout = {
		spacing = 1.8,
		columns = 4,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame, rng: Random)
			local part, isKit = kitOrBlock(if rng:NextNumber() < 0.5 then "Weed_Clover" else "Weed_Broadleaf", parent, {
				Name = "Sprout",
				Color = COLORS.Weed,
				Material = Enum.Material.Grass,
			})
			local size = if isKit then part.Size * 1.3 else Vector3.new(0.5, 0.6, 0.5)
			Assets.standOn(part, ground, size)
			return part, { startSize = size }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				target.part:Destroy()
			else
				shrink(target, Vector3.one * (1 - fraction * 0.7))
			end
		end,
	},

	-- A shrub with long, leggy shoots to prune back.
	Shrub = {
		spacing = 4,
		columns = 3,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame, rng: Random)
			local part = bush(parent, ground, Vector3.new(2.4, 2.2, 2.4), COLORS.HedgeOvergrown)
			return part, { stems = sprigs(parent, ground, 2.2, 4, 1.6, Color3.fromRGB(110, 140, 60), rng) }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				destroyAll(target.stems)
			end
		end,
		reach = 1.6,
	},

	-- A rose bush with long thorny canes and a few roses.
	Rose = {
		spacing = 4,
		columns = 3,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame, rng: Random)
			local part = bush(parent, ground, Vector3.new(2, 1.8, 2), Color3.fromRGB(45, 95, 40))
			for index = 1, 4 do
				local angle = index * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
				ball(
					parent,
					(ground * CFrame.new(math.cos(angle) * 0.8, 1.6, math.sin(angle) * 0.8)).Position,
					0.38,
					Color3.fromRGB(200, 30, 50)
				)
			end
			return part, { stems = sprigs(parent, ground, 1.8, 3, 1.9, Color3.fromRGB(80, 100, 45), rng) }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				destroyAll(target.stems)
			end
		end,
		reach = 1.5,
	},

	-- A shrub with dead, dry branches sticking out of it.
	DeadWood = {
		spacing = 4,
		columns = 3,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame, rng: Random)
			local part = bush(parent, ground, Vector3.new(2.4, 2.2, 2.4), COLORS.HedgeOvergrown)
			return part, { stems = sprigs(parent, ground, 2.2, 3, 1.4, COLORS.Dead, rng) }
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				destroyAll(target.stems)
			end
		end,
		reach = 1.6,
	},

	-- A clump of flowers gone over, with brown spent heads.
	FlowerClump = {
		spacing = 2.6,
		columns = 4,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame, rng: Random)
			local part = ball(parent, (ground * CFrame.new(0, 0.6, 0)).Position, 1.4, COLORS.Leaf)
			local heads = {}
			for index = 1, 4 do
				local angle = index * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
				table.insert(
					heads,
					ball(
						parent,
						(ground * CFrame.new(math.cos(angle) * 0.5, 1.4, math.sin(angle) * 0.5)).Position,
						0.35,
						COLORS.Dead
					)
				)
			end
			return part,
				{
					heads = heads,
					bloom = if rng:NextNumber() < 0.5
						then Color3.fromRGB(240, 120, 170)
						else Color3.fromRGB(250, 210, 60),
				}
		end,
		visual = function(target, fraction: number)
			if fraction >= 1 then
				for _, head in target.heads do
					head.Color = target.bloom
				end
			end
		end,
	},

	-- A dry bed with a wilting plant that perks up as it gets a soak.
	DryBed = {
		spacing = 3.4,
		columns = 3,
		base = COLORS.Mulch,
		build = function(parent, ground: CFrame)
			local soil = block(parent, {
				Name = "DrySoil",
				Size = Vector3.new(3, 0.12, 3),
				CFrame = ground * CFrame.new(0, 0.06, 0),
				Color = COLORS.DrySoil,
				Material = Enum.Material.Ground,
			})
			return soil, { plant = ball(parent, (ground * CFrame.new(0, 0.7, 0)).Position, 1.2, COLORS.Wilted) }
		end,
		visual = function(target, fraction: number)
			target.part.Color = COLORS.DrySoil:Lerp(COLORS.Soil, fraction)
			target.plant.Color = COLORS.Wilted:Lerp(COLORS.Leaf, fraction)
		end,
		reach = 1.6,
	},

	-- A tray of tiny seedlings in dry potting mix.
	SeedTray = {
		spacing = 2.8,
		columns = 3,
		base = COLORS.Patio,
		build = function(parent, ground: CFrame)
			block(parent, {
				Name = "Tray",
				Size = Vector3.new(2.2, 0.35, 1.3),
				CFrame = ground * CFrame.new(0, 0.175, 0),
				Color = COLORS.NurseryPot,
			})
			local mix = block(parent, {
				Name = "Mix",
				Size = Vector3.new(2, 0.05, 1.1),
				CFrame = ground * CFrame.new(0, 0.37, 0),
				Color = COLORS.DrySoil,
				Material = Enum.Material.Ground,
			})
			for index = 1, 6 do
				ball(
					parent,
					(ground * CFrame.new(((index - 1) % 3 - 1) * 0.6, 0.45, if index <= 3 then -0.25 else 0.25)).Position,
					0.18,
					COLORS.Leaf
				)
			end
			return mix, {}
		end,
		visual = function(target, fraction: number)
			target.part.Color = COLORS.DrySoil:Lerp(COLORS.Soil, fraction)
		end,
	},
}
-- Serious-gardener work (design phase D) ------------------------------------------------------

-- A few stones scattered around a spot (rocky or hard ground).
local function stones(parent: Instance, ground: CFrame, count: number, rng: Random, spread: number)
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(0.4, spread)
		ball(
			parent,
			(ground * CFrame.new(math.cos(angle) * distance, 0.15, math.sin(angle) * distance)).Position,
			rng:NextNumber(0.3, 0.6),
			COLORS.Stone
		).Material =
			Enum.Material.Slate
	end
end

-- A bare tree trunk with one branch to cut off, as thick as `thickness`.
local function branchTree(parent: Instance, ground: CFrame, thickness: number, rng: Random)
	stick(parent, ground.Position, ground.Position + Vector3.new(0, 4, 0), 0.7, COLORS.Bark)
	ball(parent, ground.Position + Vector3.new(0, 4.8, 0), 3, COLORS.Leaf)
	local angle = rng:NextNumber(0, math.pi * 2)
	local base = ground.Position + Vector3.new(0, rng:NextNumber(1.8, 2.8), 0)
	local tip = base + Vector3.new(math.cos(angle) * 2.4, 0.8, math.sin(angle) * 2.4)
	local branch = stick(parent, base, tip, thickness, COLORS.Bark)
	local leaves = ball(parent, tip, 1.2, COLORS.Leaf)
	return branch, { leaves = leaves }
end

local function cutBranch(target, fraction: number)
	if fraction >= 1 then
		target.leaves:Destroy()
		target.part:Destroy()
	end
end

GARDEN.PlantingHole = {
	spacing = 4,
	columns = 3,
	base = COLORS.Sod,
	-- A marked spot with the shrub waiting beside it, some of them in rocky ground.
	build = function(parent, ground: CFrame, rng: Random, task)
		local mark = disc(parent, ground, 1.8, Color3.fromRGB(235, 235, 225), 0.04)
		local rootball = ball(parent, (ground * CFrame.new(1.4, 0.5, 0)).Position, 1, Color3.fromRGB(160, 130, 90))
		local sapling = ball(parent, (ground * CFrame.new(1.4, 1.5, 0)).Position, 1.4, COLORS.Leaf)
		local extra = { rootball = rootball, sapling = sapling }
		if rng:NextNumber() < (task.rocky or 0) then
			stones(parent, ground, 5, rng, 1.2)
			extra.speedHits = task.type.rocky
		end
		return mark, extra
	end,
	visual = function(target, fraction: number)
		if fraction >= 1 then
			target.part.Color = COLORS.Soil
			target.rootball.Position = (target.ground * CFrame.new(0, 0.3, 0)).Position
			target.sapling.Position = (target.ground * CFrame.new(0, 1.3, 0)).Position
		end
	end,
}

GARDEN.Sod = {
	cell = Vector2.new(2.8, 2),
	oneRow = true,
	base = COLORS.Soil,
	-- A strip of turf to slice free and lift along the new bed's edge.
	build = function(parent, ground: CFrame)
		return block(parent, {
			Name = "Sod",
			Size = Vector3.new(2.6, 0.3, 1.8),
			CFrame = ground * CFrame.new(0, 0.15, 0),
			Color = COLORS.Sod,
			Material = Enum.Material.Grass,
		}),
			{}
	end,
	visual = function(target, fraction: number)
		if fraction >= 1 then
			target.part:Destroy()
		else
			target.part.CFrame = target.ground
				* CFrame.new(0, 0.15 + fraction * 0.3, 0)
				* CFrame.Angles(fraction * 0.3, 0, 0)
		end
	end,
	reach = 1.4,
}

GARDEN.DeepBed = {
	spacing = 3.6,
	columns = 2,
	base = COLORS.Mulch,
	-- Packed-down soil that turns deep and fluffy.
	build = function(parent, ground: CFrame)
		return block(parent, {
			Name = "PackedSoil",
			Size = Vector3.new(3.2, 0.15, 3.2),
			CFrame = ground * CFrame.new(0, 0.075, 0),
			Color = COLORS.Hardpan:Lerp(COLORS.Soil, 0.4),
			Material = Enum.Material.Slate,
		}),
			{}
	end,
	visual = function(target, fraction: number)
		target.part.Color = COLORS.Hardpan:Lerp(COLORS.Soil, 0.4 + 0.6 * fraction)
		if fraction >= 1 then
			target.part.Material = Enum.Material.Ground
			target.part.Size = Vector3.new(3.2, 0.4, 3.2)
			target.part.CFrame = target.ground * CFrame.new(0, 0.2, 0)
		end
	end,
	reach = 1.8,
}

GARDEN.HeavySoil = {
	spacing = 3.4,
	columns = 3,
	base = COLORS.Mulch,
	-- Sticky clay with old roots through it.
	build = function(parent, ground: CFrame, rng: Random)
		local clay = block(parent, {
			Name = "Clay",
			Size = Vector3.new(3, 0.18, 3),
			CFrame = ground * CFrame.new(0, 0.09, 0),
			Color = COLORS.Clay,
			Material = Enum.Material.Slate,
		})
		local roots = sprigs(parent, ground * CFrame.new(0, -0.1, 0), 0.2, 3, 0.3, COLORS.Bark, rng)
		return clay, { roots = roots }
	end,
	visual = function(target, fraction: number)
		target.part.Color = COLORS.Clay:Lerp(COLORS.Soil, fraction)
		if fraction >= 1 then
			target.part.Material = Enum.Material.Ground
			destroyAll(target.roots)
		end
	end,
	reach = 1.6,
}

GARDEN.HardGround = {
	spacing = 3.4,
	columns = 3,
	base = COLORS.Mulch,
	-- Rock-hard ground full of stones.
	build = function(parent, ground: CFrame, rng: Random)
		local hard = block(parent, {
			Name = "Hardpan",
			Size = Vector3.new(3, 0.2, 3),
			CFrame = ground * CFrame.new(0, 0.1, 0),
			Color = COLORS.Hardpan,
			Material = Enum.Material.Slate,
		})
		stones(parent, ground, 4, rng, 1.2)
		return hard, {}
	end,
	visual = function(target, fraction: number)
		target.part.Color = COLORS.Hardpan:Lerp(COLORS.Soil, fraction)
		if fraction >= 1 then
			target.part.Material = Enum.Material.Ground
		end
	end,
	reach = 1.6,
}

GARDEN.MulchHeap = {
	spacing = 3.6,
	columns = 3,
	base = COLORS.Soil,
	-- A dumped heap that gets raked out flat across the bed.
	build = function(parent, ground: CFrame, rng: Random)
		local gravel = rng:NextNumber() < 0.3
		local heap = block(parent, {
			Name = "Heap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.2, 1.8),
			Position = (ground * CFrame.new(0, 0.3, 0)).Position,
			Color = if gravel then COLORS.Gravel else COLORS.Mulch,
			Material = if gravel then Enum.Material.Pebble else Enum.Material.Ground,
		})
		return heap, {}
	end,
	visual = function(target, fraction: number)
		local size = Vector3.new(1.8, 1.2, 1.8):Lerp(Vector3.new(3.2, 0.2, 3.2), fraction)
		target.part.Shape = if fraction >= 1 then Enum.PartType.Block else Enum.PartType.Ball
		target.part.Size = size
		target.part.CFrame = target.ground * CFrame.new(0, size.Y / 2, 0)
	end,
	reach = 1.8,
}

GARDEN.RowWeeds = {
	cell = Vector2.new(1.8, 6),
	oneRow = true,
	base = COLORS.Soil,
	-- Weeds coming up between two rows of vegetables.
	build = function(parent, ground: CFrame, rng: Random)
		for _, side in { -0.6, 0.6 } do
			for z = -2, 2, 1 do
				ball(parent, (ground * CFrame.new(side, 0.3, z)).Position, 0.5, COLORS.Leaf)
			end
		end
		local weeds = {}
		for _ = 1, 4 do
			table.insert(
				weeds,
				ball(parent, (ground * CFrame.new(0, 0.15, rng:NextNumber(-2.4, 2.4))).Position, 0.35, COLORS.Weed)
			)
		end
		local strip = block(parent, {
			Name = "Gap",
			Size = Vector3.new(0.5, 0.04, 5.4),
			CFrame = ground * CFrame.new(0, 0.02, 0),
			Color = COLORS.Soil,
			Material = Enum.Material.Ground,
		})
		return strip, { weeds = weeds }
	end,
	visual = function(target, fraction: number)
		if fraction >= 1 then
			destroyAll(target.weeds)
		end
	end,
	reach = 2.6,
}

GARDEN.BranchMedium = {
	spacing = 5,
	columns = 3,
	base = COLORS.Sod,
	build = function(parent, ground: CFrame, rng: Random)
		return branchTree(parent, ground, 0.22, rng)
	end,
	visual = cutBranch,
	reach = 2.4,
}

GARDEN.BranchThick = {
	spacing = 5,
	columns = 3,
	base = COLORS.Sod,
	build = function(parent, ground: CFrame, rng: Random)
		return branchTree(parent, ground, 0.45, rng)
	end,
	visual = cutBranch,
	reach = 2.4,
}

for kind, style in GARDEN do
	VISUALS[kind] = style.visual
end
-- Hauling, fertilizing and spraying keep their own state (see below), so they draw themselves.
for _, kind in { "HaulHeavy", "HaulLight", "Fertilize", "SprayWeed" } do
	VISUALS[kind] = VISUALS[kind] or function() end
end

-- Finds room for a plot `size` big (X wide, Y deep) in the side garden and returns its
-- front-right corner. Plots stack from the sidewalk toward the house, then start a new column
-- further left.
function Lawn:_nextPlot(size: Vector2): Vector3
	if not self.garden then
		self.garden = Instance.new("Folder")
		self.garden.Name = "Garden"
		self.garden.Parent = self.folder
	end
	local cursor = self.gardenCursor
	if cursor.z > 0 and cursor.z + size.Y > self.depth + BED_DEPTH then
		cursor.x -= cursor.columnWidth + GARDEN_GAP
		cursor.z = 0
		cursor.columnWidth = 0
	end
	local corner = self.origin + Vector3.new(cursor.x - size.X, 0, cursor.z)
	cursor.z += size.Y + GARDEN_GAP
	cursor.columnWidth = math.max(cursor.columnWidth, size.X)
	return corner
end

-- One plot in the side garden for a garden task, with a target per thing to do.
function Lawn:_buildGardenPlot(task, rng: Random)
	local style = GARDEN[task.type.target]
	local count = math.max(1, task.amount)
	local columns = if style.oneRow then count else math.min(count, style.columns or 4)
	local rows = math.ceil(count / columns)
	local cell = style.cell or Vector2.new(style.spacing, style.spacing)
	local size = Vector2.new(columns * cell.X + 1, rows * cell.Y + 1)

	local corner = self:_nextPlot(size)
	local folder = Instance.new("Folder")
	folder.Name = task.id
	folder.Parent = self.garden
	block(folder, {
		Name = "Plot",
		Size = Vector3.new(size.X, 0.3, size.Y),
		Position = corner + Vector3.new(size.X / 2, 0.15, size.Y / 2),
		Color = style.base,
		Material = if style.base == COLORS.Patio then Enum.Material.Concrete else Enum.Material.Ground,
	})
	for index = 1, count do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local position = corner + Vector3.new(0.5 + (column + 0.5) * cell.X, 0.3, 0.5 + (row + 0.5) * cell.Y)
		local ground = CFrame.new(position)
		local part, extra = style.build(folder, ground, rng, task)
		extra.ground = ground
		extra.parent = folder
		extra.startSize = extra.startSize or part.Size
		self:_addTarget(task, part, position, style.reach or 1, extra)
	end
end

-- A delivered pile on the driveway and an empty bed in the side garden: each load gets filled
-- at the pile and dumped in the bed (see Lawn:_applyHaul).
function Lawn:_buildHaul(task)
	local heavy = task.type.heavy == true
	local loads = math.max(1, task.amount)
	local folder = Instance.new("Folder")
	folder.Name = task.id
	folder.Parent = self.folder

	local pileIndex = self.piles or 0
	self.piles = pileIndex + 1
	local pileAt = self.origin + Vector3.new(self.width + DRIVEWAY_WIDTH / 2, 0.3, 4 + pileIndex * 7)
	local pileColor = if heavy then COLORS.Clay else COLORS.Mulch
	local pileSize = Vector3.new(5, 2.2, 5)
	local pile = block(folder, {
		Name = "Pile",
		Shape = Enum.PartType.Ball,
		Size = pileSize,
		Position = pileAt + Vector3.new(0, pileSize.Y * 0.3, 0),
		Color = pileColor,
		Material = if heavy then Enum.Material.Slate else Enum.Material.Ground,
	})
	if heavy then
		stones(folder, CFrame.new(pileAt), 6, Random.new(), 2.2)
	end

	local bedSize = Vector2.new(6, 4)
	local corner = self:_nextPlot(bedSize)
	local bedAt = corner + Vector3.new(bedSize.X / 2, 0, bedSize.Y / 2)
	block(self.garden, {
		Name = "EmptyBed",
		Size = Vector3.new(bedSize.X, 0.2, bedSize.Y),
		Position = bedAt + Vector3.new(0, 0.1, 0),
		Color = COLORS.Hardpan,
		Material = Enum.Material.Ground,
	})
	local fill = block(self.garden, {
		Name = "Fill",
		Size = Vector3.new(bedSize.X - 0.4, 0.05, bedSize.Y - 0.4),
		Position = bedAt + Vector3.new(0, 0.22, 0),
		Color = pileColor,
		Material = Enum.Material.Ground,
		Transparency = 1,
	})

	task.haul = {
		heavy = heavy,
		pile = pile,
		pileAt = pileAt,
		pileSize = pileSize,
		bedAt = bedAt,
		fill = fill,
		-- [holder] = how full their barrow is (0 to the task's workPerTarget)
		loads = {},
	}
	for _ = 1, loads do
		self:_addTarget(task, nil, bedAt, 3)
	end
end

-- Every lawn tile gets an even pass of fertilizer; a pale dusting shows where it's landed.
function Lawn:_buildFertilize(task, hazardTiles)
	local tile = GameConfig.TileSize
	local folder = Instance.new("Folder")
	folder.Name = "Fertilizer"
	folder.Parent = self.folder
	task.dustFolder = folder
	for column = 0, self.columns - 1 do
		for row = 0, self.rows - 1 do
			if nearHazard(hazardTiles, column, row, 0) then
				continue
			end
			local optional = nearHazard(hazardTiles, column, row, 1)
			self:_addTarget(task, nil, LawnGrid.center(self.origin, tile, column, row), tile * 0.35, {
				folder = folder,
				optional = optional,
			})
			if optional then
				task.optional += 1
			end
		end
	end
end

VISUALS.Fertilize = function(target, fraction: number)
	if fraction >= 1 then
		local tile = GameConfig.TileSize
		local dust = block(target.folder, {
			Name = "Dust",
			Size = Vector3.new(tile * 0.9, 0.02, tile * 0.9),
			Position = target.position + Vector3.new(0, 0.05, 0),
			Color = COLORS.Fertilizer,
			Material = Enum.Material.Sand,
			Transparency = 0.6,
		})
		dust.CastShadow = false
	end
end

-- Weeds in the lawn and the driveway cracks that need a dose of weed killer. Sprayed ones wilt.
function Lawn:_buildSprayWeeds(task, rng: Random, hazardTiles)
	local tile = GameConfig.TileSize
	local folder = Instance.new("Folder")
	folder.Name = "SprayWeeds"
	folder.Parent = self.folder
	for index = 1, task.amount do
		local position
		if index % 3 == 0 then
			position = self.origin
				+ Vector3.new(self.width + rng:NextNumber(1, DRIVEWAY_WIDTH - 1), 0.3, rng:NextNumber(1, self.depth))
		else
			local column, row = rng:NextInteger(0, self.columns - 1), rng:NextInteger(0, self.rows - 1)
			if nearHazard(hazardTiles, column, row, 1) then
				column, row = 0, 0
			end
			position = LawnGrid.center(self.origin, tile, column, row)
				+ Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		end
		local ground = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local part, isKit = kitOrBlock(if rng:NextNumber() < 0.5 then "Weed_Thistle" else "Weed_Broadleaf", folder, {
			Name = "Weed",
			Color = COLORS.Weed,
			Material = Enum.Material.Grass,
		})
		local size = if isKit then part.Size * 1.8 else Vector3.new(1, 1.2, 1)
		Assets.standOn(part, ground, size)
		self:_addTarget(task, part, position, 0.8, { ground = ground, startSize = size, isKit = isKit })
	end
end

VISUALS.SprayWeed = function(target, fraction: number)
	if fraction >= 1 then
		shrink(target, Vector3.new(1, 0.4, 1))
		if not target.isKit then
			target.part.Color = COLORS.Dead
		end
	end
end

-- Dandelions dotted around the lawn, away from the flowers.
function Lawn:_buildDandelions(task, rng: Random, hazardTiles)
	local tile = GameConfig.TileSize
	local folder = Instance.new("Folder")
	folder.Name = "Dandelions"
	folder.Parent = self.folder
	local used = {}
	for _ = 1, task.amount * 20 do
		if #task.targets >= task.amount then
			break
		end
		local column = rng:NextInteger(0, self.columns - 1)
		local row = rng:NextInteger(0, self.rows - 1)
		local key = column * 1000 + row
		if used[key] or nearHazard(hazardTiles, column, row, 1) then
			continue
		end
		used[key] = true
		local center = LawnGrid.center(self.origin, tile, column, row)
		local base = center + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		local ground = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local part, isKit = kitOrBlock("Weed_Dandelion", folder, {
			Name = "Dandelion",
			Color = Color3.fromRGB(230, 200, 40),
			Material = Enum.Material.Grass,
		})
		local size = if isKit then part.Size * 1.8 else Vector3.new(0.8, 0.9, 0.8)
		Assets.standOn(part, ground, size)
		self:_addTarget(task, part, base, 0.6, { ground = ground, startSize = size })
	end
end

-- Public API ---------------------------------------------------------------------------------

-- `origin` is the front-left corner of the lawn, where it meets the sidewalk.
function LawnService:Build(template, origin: Vector3, address: string)
	local rng = Random.new()
	local tile = GameConfig.TileSize
	local layout = template.lawn

	local folder = Instance.new("Model")
	folder.Name = "JobSite"

	local lawn = setmetatable({
		folder = folder,
		origin = origin,
		address = address,
		columns = layout.columns,
		rows = layout.rows,
		width = layout.columns * tile,
		depth = layout.rows * tile,
		-- One entry per task in the job, in the customer's order.
		tasks = {},
		hazards = {},
		-- Where the next side garden plot goes (left of the yard, from the sidewalk back).
		gardenCursor = { x = GARDEN_START_X, z = 0, columnWidth = 0 },
	}, Lawn)

	-- Which task each kind of yard target belongs to (one task per kind).
	local byTarget = {}
	for _, entry in template.tasks do
		local taskType = TaskTypes.get(entry.type)
		local task = {
			id = entry.type,
			type = taskType,
			amount = entry.amount or 0,
			-- Share of this task's targets in rocky ground (see TaskTypes `rocky`).
			rocky = entry.rocky,
			targets = {},
			total = 0,
			done = 0,
			optional = 0,
		}
		table.insert(lawn.tasks, task)
		if taskType.target and not byTarget[taskType.target] then
			byTarget[taskType.target] = task
		end
	end

	local hazardTiles = lawn:_pickHazardTiles(rng, layout.flowerPatches)
	lawn:_buildGround()
	lawn:_buildGrass(byTarget.Grass, hazardTiles)
	lawn:_buildHazards(rng, hazardTiles)
	if byTarget.Edge then
		lawn:_buildEdges(byTarget.Edge)
	end
	if byTarget.Hedge then
		lawn:_buildHedges(byTarget.Hedge, rng, byTarget.Hedge.amount)
	end
	if byTarget.Weed then
		lawn:_buildWeeds(byTarget.Weed, rng, byTarget.Weed.amount)
	end
	if byTarget.LeafPile then
		lawn:_buildLeaves(byTarget.LeafPile, rng, byTarget.LeafPile.amount)
	end
	if byTarget.Dandelion then
		lawn:_buildDandelions(byTarget.Dandelion, rng, hazardTiles)
	end
	if byTarget.Fertilize then
		lawn:_buildFertilize(byTarget.Fertilize, hazardTiles)
	end
	if byTarget.SprayWeed then
		lawn:_buildSprayWeeds(byTarget.SprayWeed, rng, hazardTiles)
	end
	for _, task in lawn.tasks do
		local kind = task.type.target
		if kind and GARDEN[kind] then
			lawn:_buildGardenPlot(task, rng)
		elseif kind == "HaulHeavy" or kind == "HaulLight" then
			lawn:_buildHaul(task)
		end
	end
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

export type WorkResult = {
	-- Something got worked on.
	changed: boolean,
	-- There was unfinished work in reach that this tool can't do.
	blocked: boolean,
	-- Work done, and the same work weighted by tool fit (for pay) and by finish quality.
	work: number,
	fitWork: number,
	qualityWork: number,
	-- The protection ("Thorns", "Chemicals") the player needed but didn't have.
	hurt: string?,
	-- Something worth telling the player (a barrow filled up, tipped over...).
	message: string?,
}

-- Who's doing the work and how, for things that depend on it.
--   protections  hazards their gloves protect from
--   holder       whose barrow a load is in (one load per player)
--   moving       whether they're walking
--   seconds      how long this bit of work took
export type WorkContext = {
	protections: { [string]: boolean }?,
	holder: any?,
	moving: boolean?,
	seconds: number?,
}

-- A one-wheeled barrow carrying something heavy tips over about this often per second of walking.
local TIP_CHANCE = 0.05
local tipRng = Random.new()

-- Uses tool `toolId` on everything within `radius` of `position` that it can work on. `amount`
-- is the work a perfectly fitting tool would do this tick; worse fits do less.
function Lawn:ApplyWork(
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	context: WorkContext?
): WorkResult
	local result =
		{ changed = false, blocked = false, work = 0, fitWork = 0, qualityWork = 0, hurt = nil, message = nil }
	local protections = context and context.protections

	-- Lawn grass is everywhere, so walking a tool across it on the way to its real work isn't a
	-- mistake. Grass only counts as "wrong tool" when the tool has nothing left to do here.
	local fits = {}
	local usefulHere = false
	for _, task in self.tasks do
		fits[task] = TaskTypes.fit(task.id, toolId) or false
		if fits[task] and task.done < task.total then
			usefulHere = true
		end
	end

	for _, task in self.tasks do
		local fit = fits[task]
		if task.haul then
			self:_applyHaul(task, fit, position, radius, toolId, amount, context, result)
			continue
		end
		local needs = task.type.protection
		local unprotected = needs ~= nil and not (protections and protections[needs])
		for _, target in task.targets do
			if target.work <= 0 then
				continue
			end
			local offset = target.position - position
			if Vector2.new(offset.X, offset.Z).Magnitude > radius + target.reach then
				continue
			end
			if not fit then
				if target.kind ~= "Grass" or not usefulHere then
					result.blocked = true
				end
				break
			end
			if unprotected then
				result.hurt = needs
				break
			end
			-- Some targets are harder for some tools (rocky ground).
			local hit = target.speedHits and target.speedHits[toolId] or 1
			local applied = math.min(target.work, amount * fit.speed * hit)
			target.work -= applied
			VISUALS[target.kind](target, 1 - target.work / target.maxWork)
			if target.work <= 0 then
				target.work = 0
				task.done += 1
			end
			result.changed = true
			result.work += applied
			result.fitWork += applied * fit.pay
			result.qualityWork += applied * fit.quality
		end
	end

	-- One attribute update per tick, however many tiles just got mowed.
	if self.grassDirty then
		self.grassDirty = false
		self.grassFolder:SetAttribute("State", table.concat(self.grassState))
	end
	return result
end

-- Hauling: fill your barrow at the pile, push it to the bed and dump it. Each player carries one
-- load at a time. A one-wheeled barrow full of soil or stone can tip if you walk it around.
function Lawn:_applyHaul(
	task,
	fit,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	context: WorkContext?,
	result
)
	local haul = task.haul
	local function near(point: Vector3, reach: number): boolean
		local offset = point - position
		return Vector2.new(offset.X, offset.Z).Magnitude <= radius + reach
	end
	local atPile, atBed = near(haul.pileAt, 3), near(haul.bedAt, 3)
	if task.done >= task.total then
		return
	end
	if not fit then
		if atPile or atBed then
			result.blocked = true
		end
		return
	end

	local holder = context and context.holder or "crew"
	local loadSize = task.type.workPerTarget
	local load = haul.loads[holder] or 0
	if load < loadSize then
		if not atPile then
			return
		end
		local applied = math.min(loadSize - load, amount * fit.speed)
		haul.loads[holder] = load + applied
		result.changed = true
		result.work += applied
		result.fitWork += applied * fit.pay
		result.qualityWork += applied * fit.quality
		if load + applied >= loadSize then
			result.message = "Loaded up. Take it to the bed."
		end
		return
	end

	if atBed then
		haul.loads[holder] = nil
		for _, target in task.targets do
			if target.work > 0 then
				target.work = 0
				break
			end
		end
		task.done += 1
		local fraction = task.done / task.total
		haul.fill.Transparency = 0
		haul.fill.Size = Vector3.new(haul.fill.Size.X, 0.05 + fraction * 0.5, haul.fill.Size.Z)
		haul.fill.Position = haul.bedAt + Vector3.new(0, 0.2 + haul.fill.Size.Y / 2, 0)
		local remaining = 1 - fraction
		if remaining <= 0 then
			haul.pile:Destroy()
		else
			haul.pile.Size = haul.pileSize * (0.35 + 0.65 * remaining)
		end
		result.changed = true
	elseif haul.heavy and context and context.moving then
		local tool = Tools.get(toolId)
		if tool and tool.tips and tipRng:NextNumber() < TIP_CHANCE * (context.seconds or 0.1) then
			haul.loads[holder] = nil
			result.message = "Whoa! The barrow tipped over and dumped the load."
		end
	end
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
local function needed(task): number
	return math.ceil((task.total - task.optional) * GameConfig.CompletionThreshold)
end

function Lawn:IsComplete(): boolean
	for _, task in self.tasks do
		if task.done < needed(task) then
			return false
		end
	end
	return true
end

-- Progress for the HUD: { { task = "MowSmallLawn", label = "Mow the lawn", done = 10, needed = 29 }, ... }
function Lawn:GetProgress()
	local progress = {}
	for _, task in self.tasks do
		if task.total > 0 then
			table.insert(progress, {
				task = task.id,
				label = task.type.label,
				done = math.min(task.done, needed(task)),
				needed = needed(task),
			})
		end
	end
	return progress
end

function Lawn:Destroy()
	self.folder:Destroy()
end

return LawnService
