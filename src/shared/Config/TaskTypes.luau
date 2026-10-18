-- Every kind of task a job can ask for, and which tools fit it. See docs/GAME_DESIGN.md.
--
-- Players are never told which tool to use. The labels and to-do lines here are what customers
-- ask for, so they must never name a tool.
--
--   verb         the action the task needs (a tool with this verb can always try it)
--   label        short line for the on-site tracker
--   todo         line for the job board; "{n}" becomes the task's amount
--   target       what the yard builder makes for it (see LawnService): "Grass", "Edge",
--                "Weed", "LeafPile", "Hedge", the garden kinds ("Pot", "Bulb", "Rose"...), or
--                nil if its targets come in a later phase
--   workPerTarget how much work each target takes
--   ideal/good/poor  tool ids. Ideal pays and works at 100%, good 80%, poor 55%.
--                Any other tool with the verb counts as poor. A tool without the verb that
--                isn't listed can't do the task at all.
--   exclude      tools with the verb that still can't do it (e.g. snips on woody stems)
--   qualityHits  [tool id] = multiplier on the finish quality (e.g. a bow rake tears turf)
--   speedHits    [tool id] = extra multiplier on work speed (e.g. a shovel on hard ground)
--   grassHeight  inches of grass; mowers whose maxGrassHeight is lower can't cut it
--   protection   "Thorns" or "Chemicals": gloves that protect from it are needed
--   rocky        [tool id] = speed multiplier on targets in rocky ground (a job sets how many
--                with `rocky` on the task)
--   heavy        hauling tasks whose loads can tip a one-wheeled barrow
--   tight        lawns full of obstacles and banks: speed scales with the mower's maneuverability
--   step         the task's place in a turf renovation (1 probe, 2 dethatch, 3 aerate, 4 overseed,
--                5 fertilize, 6 water); doing them out of order lowers the finish (LawnService)
--   phase        when the task's yard targets arrive, for tasks not used yet

local Tools = require(script.Parent.Tools)

local TaskTypes = {}

TaskTypes.FitMultipliers = {
	Ideal = 1,
	Good = 0.8,
	Poor = 0.55,
}

TaskTypes.List = {
	----------------------------------------------------------------------------------------------
	-- Lawns (used by today's jobs)
	----------------------------------------------------------------------------------------------
	{
		id = "MowSmallLawn",
		verb = "Mow",
		label = "Mow the lawn",
		todo = "Mow the small front lawn",
		target = "Grass",
		workPerTarget = 1,
		grassHeight = 3,
		ideal = { "ReelMower", "GasPushMower", "SelfPropelledMower" },
		good = { "RidingMower", "StandOnMower" },
	},
	{
		id = "MowMediumLawn",
		verb = "Mow",
		label = "Mow the lawn",
		todo = "Mow the lawn",
		target = "Grass",
		workPerTarget = 1,
		grassHeight = 3.5,
		ideal = { "SelfPropelledMower", "RidingMower", "ZeroTurnMower" },
		good = { "GasPushMower", "StandOnMower", "CommercialZeroTurn" },
	},
	{
		id = "MowLargeLawn",
		verb = "Mow",
		label = "Mow the lawn",
		todo = "Mow a big, open lawn",
		target = "Grass",
		workPerTarget = 1,
		grassHeight = 3.5,
		ideal = { "CommercialZeroTurn" },
		good = { "StandOnMower", "ZeroTurnMower", "RidingMower" },
	},
	{
		id = "MowShowLawn",
		verb = "Mow",
		label = "Mow the lawn short and perfect",
		todo = "Mow a short, show-quality lawn",
		target = "Grass",
		workPerTarget = 1,
		grassHeight = 1.25,
		ideal = { "CommercialReelMower", "ReelMower" },
	},
	{
		id = "MowTallGrass",
		verb = "Mow",
		label = "Cut down the overgrown grass",
		todo = "Cut a lawn that's grown knee-high",
		target = "Grass",
		workPerTarget = 1.5,
		grassHeight = 9,
		ideal = { "GasPushMower", "SelfPropelledMower" },
		good = { "CommercialZeroTurn", "StandOnMower" },
	},
	{
		id = "MowTightOrSloped",
		verb = "Mow",
		label = "Mow the lawn",
		todo = "Mow a tight, sloped lawn full of obstacles",
		target = "Grass",
		workPerTarget = 1,
		grassHeight = 3.5,
		-- Trees, beds and banks everywhere: clumsy machines lose a lot of time turning.
		tight = true,
		ideal = { "StandOnMower" },
		good = { "SelfPropelledMower", "GasPushMower", "ZeroTurnMower" },
	},
	{
		id = "EdgeSidewalk",
		verb = "Edge",
		label = "Edge along the sidewalk and driveway",
		todo = "Edge the lawn along the sidewalk and driveway",
		target = "Edge",
		workPerTarget = 1.5,
		ideal = { "HalfMoonEdger", "ElectricEdger", "WalkBehindEdger", "GasStickEdger" },
		good = { "GardenSpade" },
		-- Turning a string trimmer on its side works, but the edge comes out ragged.
		poor = { "ElectricTrimmer", "GasTrimmer", "StraightShaftTrimmer" },
		qualityHits = { ElectricTrimmer = 0.85, GasTrimmer = 0.85, StraightShaftTrimmer = 0.85 },
	},
	{
		id = "EdgeHardscape",
		verb = "Edge",
		label = "Cut crisp edges along the hardscape",
		todo = "Crisp, deep edges along every walk and drive",
		target = "Edge",
		workPerTarget = 2,
		ideal = { "GasStickEdger" },
		good = { "WalkBehindEdger", "ElectricEdger" },
		poor = { "GardenSpade", "ElectricTrimmer", "GasTrimmer", "StraightShaftTrimmer" },
		qualityHits = { ElectricTrimmer = 0.85, GasTrimmer = 0.85, StraightShaftTrimmer = 0.85 },
	},
	{
		id = "TrimAroundObstacles",
		verb = "Trim",
		label = "Cut back long grass and weeds along the house",
		todo = "Cut back long grass and weeds along the house, fence and driveway ({n} spots)",
		target = "Weed",
		workPerTarget = 2,
		ideal = { "StraightShaftTrimmer", "GasTrimmer", "ElectricTrimmer" },
		good = { "GardenShears", "Brushcutter" },
		qualityHits = { Brushcutter = 0.9 },
	},
	{
		id = "RakeLeaves",
		verb = "Rake",
		label = "Clear the leaf piles",
		todo = "Clear {n} piles of leaves off the lawn",
		target = "LeafPile",
		workPerTarget = 3,
		ideal = { "OldRake", "WideRake" },
		good = { "LeafBlower", "BackpackBlower" },
		poor = { "BowRake" },
		-- Rigid steel tines tear up the turf.
		qualityHits = { BowRake = 0.6 },
	},
	{
		id = "ShearHedges",
		verb = "Shear",
		label = "Shape the hedges",
		todo = "Shape {n} overgrown hedges",
		target = "Hedge",
		workPerTarget = 6,
		ideal = { "ElectricHedgeTrimmer", "CordlessHedgeTrimmer", "GasHedgeTrimmer" },
		good = { "HandHedgeShears", "ArticulatingHedgeTrimmer" },
	},
	{
		id = "ShearTallHedges",
		verb = "Shear",
		label = "Shape the tall hedges, tops included",
		todo = "Shape {n} tall, wide hedges, tops included",
		target = "Hedge",
		workPerTarget = 8,
		ideal = { "ArticulatingHedgeTrimmer" },
		good = { "GasHedgeTrimmer", "CordlessHedgeTrimmer" },
	},

	----------------------------------------------------------------------------------------------
	-- Beds, planting and pruning (phase C)
	----------------------------------------------------------------------------------------------
	{
		id = "PotUpPlants",
		verb = "Plant",
		label = "Pot up the plants",
		todo = "Pot up {n} plants into containers",
		target = "Pot",
		workPerTarget = 2,
		ideal = { "HandTrowel" },
		-- A transplanter is too narrow to scoop potting mix.
		poor = { "HandTransplanter" },
		qualityHits = { HandTransplanter = 0.85 },
		exclude = { "Dibber" },
	},
	{
		id = "TransplantSeedlings",
		verb = "Plant",
		label = "Plant the seedlings",
		todo = "Plant {n} small seedling plugs",
		target = "Plug",
		workPerTarget = 1,
		ideal = { "Dibber" },
		good = { "HandTrowel", "HandTransplanter" },
	},
	{
		id = "TransplantPerennials",
		verb = "Plant",
		label = "Move the perennials",
		todo = "Move {n} perennials with big root balls",
		target = "Perennial",
		workPerTarget = 3,
		ideal = { "HandTrowel" },
		good = { "HandTransplanter" },
		exclude = { "Dibber" },
	},
	{
		id = "PlantBulbsAtDepth",
		verb = "Plant",
		label = "Plant the bulbs at the right depth",
		todo = "Plant {n} bulbs, 6 inches deep, in the side garden",
		target = "Bulb",
		workPerTarget = 1.5,
		ideal = { "HandTransplanter" },
		good = { "HandTrowel" },
		-- Only small bulbs fit a dibber hole.
		poor = { "Dibber" },
		qualityHits = { Dibber = 0.8 },
	},
	{
		id = "SowSeedRows",
		verb = "Plant",
		label = "Sow the seed rows",
		todo = "Sow {n} rows of vegetable seed",
		target = "SeedRow",
		workPerTarget = 1,
		ideal = { "Dibber" },
		good = { "HandTrowel" },
	},
	{
		id = "LoosenBedTopsoil",
		verb = "Cultivate",
		label = "Loosen the bed's topsoil",
		todo = "Loosen the crusted topsoil in {n} flower beds",
		target = "CrustedSoil",
		workPerTarget = 2,
		ideal = { "HandCultivator" },
		good = { "HandTrowel" },
	},
	{
		id = "PullShallowWeeds",
		verb = "Weed",
		label = "Weed the beds",
		todo = "Pull the young weeds from {n} beds",
		target = "Sprout",
		workPerTarget = 1.5,
		ideal = { "HandCultivator" },
		good = { "StirrupHoe", "HandTrowel" },
	},
	{
		id = "RemoveDandelions",
		verb = "Weed",
		label = "Get the dandelions out of the lawn",
		todo = "Get {n} dandelions out of the lawn, roots and all",
		target = "Dandelion",
		workPerTarget = 1.5,
		ideal = { "DandelionWeeder" },
		-- Works, but leaves a hole in the turf.
		good = { "HandTransplanter" },
		poor = { "HandTrowel" },
		qualityHits = { HandTransplanter = 0.85, HandTrowel = 0.75 },
		-- A hoe only slices the top off; the taproot grows right back.
		exclude = { "StirrupHoe" },
	},
	{
		id = "PruneLiveStems",
		verb = "Prune",
		label = "Prune the shrubs",
		todo = "Prune {n} shrubs back to healthy, green wood",
		target = "Shrub",
		workPerTarget = 2,
		ideal = { "BypassPruners" },
		-- Crushes live stems instead of cutting them cleanly.
		good = { "AnvilPruners" },
		poor = { "FloralSnips" },
		qualityHits = { AnvilPruners = 0.7, FloralSnips = 0.8 },
	},
	{
		id = "PruneRoses",
		verb = "Prune",
		label = "Prune the rose bushes",
		todo = "Prune {n} rose bushes (watch the thorns)",
		target = "Rose",
		workPerTarget = 2,
		ideal = { "BypassPruners" },
		good = { "AnvilPruners" },
		poor = { "FloralSnips" },
		qualityHits = { AnvilPruners = 0.7, FloralSnips = 0.8 },
		protection = "Thorns",
	},
	{
		id = "CutDeadWood",
		verb = "Prune",
		label = "Cut out the dead stems",
		todo = "Cut the dead, dry stems out of {n} shrubs",
		target = "DeadWood",
		workPerTarget = 2,
		ideal = { "AnvilPruners" },
		good = { "BypassPruners" },
		exclude = { "FloralSnips" },
	},
	{
		id = "DeadheadAndCutFlowers",
		verb = "Prune",
		label = "Deadhead and cut flowers",
		todo = "Deadhead {n} flower clumps and cut a bouquet",
		target = "FlowerClump",
		workPerTarget = 1,
		ideal = { "FloralSnips" },
		good = { "BypassPruners" },
	},
	{
		id = "WaterBeds",
		verb = "Water",
		label = "Water the beds",
		todo = "Give {n} beds and shrubs a good soak",
		target = "DryBed",
		workPerTarget = 2,
		ideal = { "GardenHoseWand" },
		good = { "WateringCan" },
		speedHits = { WateringCan = 0.6 },
	},
	{
		id = "WaterSeedlings",
		verb = "Water",
		label = "Water the seedlings gently",
		todo = "Water {n} trays of seedlings and fresh seed gently",
		target = "SeedTray",
		workPerTarget = 1,
		ideal = { "WateringCan" },
		-- Strong enough to wash seed and seedlings out.
		good = { "GardenHoseWand" },
		qualityHits = { GardenHoseWand = 0.6 },
	},

	----------------------------------------------------------------------------------------------
	-- Digging, hauling and lawn treatments (phase D)
	----------------------------------------------------------------------------------------------
	{
		id = "DigPlantingHole",
		verb = "Dig",
		label = "Dig the planting holes",
		todo = "Dig {n} holes for new shrubs and trees",
		target = "PlantingHole",
		workPerTarget = 3,
		ideal = { "RoundPointShovel" },
		good = { "GardenSpade" },
		poor = { "Mattock" },
		-- Some holes land in rocky ground: there a mattock tears through and a shovel barely bites.
		rocky = { Mattock = 2.4, RoundPointShovel = 0.45, GardenSpade = 0.35 },
	},
	{
		id = "CutBedEdgeOrSod",
		verb = "Dig",
		label = "Cut the new bed edge",
		todo = "Cut a clean new bed edge and lift the sod ({n} sections)",
		target = "Sod",
		workPerTarget = 2,
		ideal = { "GardenSpade" },
		good = { "RoundPointShovel", "HalfMoonEdger" },
	},
	{
		id = "DeepLoosenBed",
		verb = "Cultivate",
		label = "Loosen the beds deep down",
		todo = "Loosen {n} vegetable beds a foot deep",
		target = "DeepBed",
		workPerTarget = 3,
		ideal = { "Broadfork" },
		good = { "DiggingFork" },
	},
	{
		id = "TurnHeavySoilOrLiftRoots",
		verb = "Dig",
		label = "Turn the heavy soil",
		todo = "Turn over {n} patches of heavy clay and lift the old roots",
		target = "HeavySoil",
		workPerTarget = 3,
		ideal = { "DiggingFork" },
		good = { "GardenSpade" },
		poor = { "RoundPointShovel" },
	},
	{
		id = "BreakHardGround",
		verb = "Dig",
		label = "Break up the hard ground",
		todo = "Break up {n} patches of rock-hard, root-filled ground",
		target = "HardGround",
		workPerTarget = 4,
		ideal = { "Mattock" },
		poor = { "RoundPointShovel" },
		speedHits = { RoundPointShovel = 0.6 },
		exclude = { "HandTrowel", "HandTransplanter", "GardenSpade" },
	},
	{
		id = "LevelSoilSpreadMulch",
		verb = "Rake",
		label = "Spread and level the mulch",
		todo = "Spread and level mulch in {n} beds",
		target = "MulchHeap",
		workPerTarget = 2,
		ideal = { "BowRake" },
		-- Flexible leaf tines skate over soil and gravel instead of moving it.
		poor = { "OldRake", "WideRake" },
		qualityHits = { OldRake = 0.7, WideRake = 0.7 },
	},
	{
		id = "HoeRowWeeds",
		verb = "Weed",
		label = "Weed between the rows",
		todo = "Weed between {n} rows of vegetables",
		target = "RowWeeds",
		workPerTarget = 1.5,
		ideal = { "StirrupHoe" },
		good = { "HandCultivator" },
	},
	{
		id = "CutBranchesMedium",
		verb = "Prune",
		label = "Cut back the branches",
		todo = "Cut back {n} branches about 1-2 inches thick",
		target = "BranchMedium",
		workPerTarget = 2,
		ideal = { "Loppers" },
		good = { "PruningSaw" },
		exclude = { "BypassPruners", "AnvilPruners", "FloralSnips" },
	},
	{
		id = "CutBranchesThick",
		verb = "Prune",
		label = "Cut the thick branches",
		todo = "Cut {n} branches thicker than 2 inches",
		target = "BranchThick",
		workPerTarget = 3,
		ideal = { "PruningSaw" },
		exclude = { "Loppers", "BypassPruners", "AnvilPruners", "FloralSnips" },
	},
	{
		id = "HaulHeavyMaterial",
		verb = "Haul",
		label = "Move the soil and stone",
		todo = "Move {n} loads of soil and stone from the pile to the beds",
		target = "HaulHeavy",
		-- A shovel moves material, but you can't carry a load across the yard in it.
		exclude = { "RoundPointShovel" },
		workPerTarget = 3,
		ideal = { "DualWheelbarrow", "SingleWheelbarrow" },
		good = { "SingleWheelbarrowFlatFree" },
		poor = { "PolyCart" },
		-- A one-wheeled barrow can tip under soil and stone.
		heavy = true,
	},
	{
		id = "HaulBulkyLight",
		verb = "Haul",
		label = "Move the leaves and mulch",
		todo = "Move {n} big loads of leaves and mulch",
		target = "HaulLight",
		-- A shovel moves material, but you can't carry a load across the yard in it.
		exclude = { "RoundPointShovel" },
		workPerTarget = 2,
		ideal = { "PolyCart" },
		good = { "DualWheelbarrow", "SingleWheelbarrow", "SingleWheelbarrowFlatFree" },
	},
	{
		id = "FertilizeLawn",
		verb = "Spread",
		label = "Fertilize the lawn evenly",
		todo = "Feed the lawn with granular fertilizer",
		target = "Fertilize",
		workPerTarget = 1,
		ideal = { "BroadcastSpreader" },
		good = { "RideOnSpreaderSprayer" },
	},
	{
		id = "SpotSprayWeeds",
		verb = "Spray",
		label = "Spot-spray the weeds",
		todo = "Spot-treat {n} patches of weeds with herbicide",
		target = "SprayWeed",
		workPerTarget = 1.5,
		ideal = { "BackpackSprayer" },
		protection = "Chemicals",
	},

	----------------------------------------------------------------------------------------------
	-- Pro turf renovation, done in order (phase F)
	----------------------------------------------------------------------------------------------
	{
		id = "ProbeSoil",
		verb = "Measure",
		label = "Check the soil first",
		todo = "Check soil temperature and moisture before starting",
		target = "Probe",
		step = 1,
		workPerTarget = 1,
		ideal = { "SoilProbe" },
	},
	{
		id = "DethatchLawn",
		verb = "Dethatch",
		label = "Pull out the thatch",
		todo = "Tear out the thick thatch layer",
		target = "Thatch",
		step = 2,
		workPerTarget = 2,
		ideal = { "PowerRakeDethatcher" },
		poor = { "BowRake" },
		speedHits = { BowRake = 0.5 },
	},
	{
		id = "CoreAerate",
		verb = "Aerate",
		label = "Core aerate the lawn",
		todo = "Core aerate the compacted lawn",
		target = "Aerate",
		step = 3,
		workPerTarget = 2,
		ideal = { "StandOnAerator" },
		good = { "TowBehindAerator" },
		-- Spiking with a fork helps a little, but pulls no cores.
		poor = { "DiggingFork" },
		qualityHits = { DiggingFork = 0.7 },
		speedHits = { DiggingFork = 0.4 },
	},
	{
		id = "Overseed",
		verb = "Seed",
		label = "Overseed the lawn",
		todo = "Overseed the thin lawn",
		target = "Overseed",
		step = 4,
		workPerTarget = 2,
		ideal = { "SlitOverseeder" },
		-- Seed sitting on top of the soil sprouts patchy.
		good = { "BroadcastSpreader" },
		qualityHits = { BroadcastSpreader = 0.8 },
	},
	{
		id = "FertilizeLargeLawn",
		verb = "Spread",
		label = "Fertilize the lawn evenly",
		todo = "Feed a big lawn with granular fertilizer",
		target = "Fertilize",
		step = 5,
		workPerTarget = 1,
		ideal = { "RideOnSpreaderSprayer" },
		good = { "BroadcastSpreader" },
	},
	{
		id = "WaterNewSeed",
		verb = "Water",
		label = "Water in the new seed",
		todo = "Water in the new seed without washing it away",
		target = "WaterSeed",
		step = 6,
		workPerTarget = 1,
		ideal = { "GardenHoseWand" },
		good = { "WateringCan" },
		speedHits = { WateringCan = 0.5 },
	},
}

local byId = {}
for _, taskType in TaskTypes.List do
	assert(not byId[taskType.id], "Duplicate task type " .. taskType.id)
	byId[taskType.id] = taskType
end

function TaskTypes.get(id: string)
	return byId[id]
end

-- The to-do line for the job board.
function TaskTypes.todo(id: string, amount: number?): string
	local taskType = byId[id]
	local text = string.gsub(taskType.todo, "{n}", tostring(amount or 0))
	return text
end

-- How well a tool fits a task, or nil if it can't do it at all.
--   rating   "Ideal", "Good" or "Poor"
--   speed    multiplier on how fast it works
--   pay      multiplier on the job's pay
--   quality  0-1 finish it leaves
export type Fit = { rating: string, speed: number, pay: number, quality: number }

function TaskTypes.fit(taskTypeId: string, toolId: string): Fit?
	local taskType = byId[taskTypeId]
	local tool = Tools.get(toolId)
	if not taskType or not tool then
		return nil
	end
	if taskType.exclude and table.find(taskType.exclude, toolId) then
		return nil
	end
	if taskType.grassHeight and tool.maxGrassHeight and tool.maxGrassHeight < taskType.grassHeight then
		return nil
	end

	local rating
	if table.find(taskType.ideal or {}, toolId) then
		rating = "Ideal"
	elseif table.find(taskType.good or {}, toolId) then
		rating = "Good"
	elseif table.find(taskType.poor or {}, toolId) or Tools.hasVerb(tool, taskType.verb) then
		rating = "Poor"
	else
		return nil
	end

	local multiplier = TaskTypes.FitMultipliers[rating]
	local qualityHit = taskType.qualityHits and taskType.qualityHits[toolId] or 1
	local speedHit = taskType.speedHits and taskType.speedHits[toolId] or 1
	if taskType.tight then
		speedHit *= 0.4 + 0.6 * (tool.maneuverability or 1)
	end
	return {
		rating = rating,
		speed = multiplier * speedHit,
		pay = multiplier,
		quality = Tools.quality(tool) * qualityHit,
	}
end

return TaskTypes
