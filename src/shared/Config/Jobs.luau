-- Job types for the job board. See docs/GAME_DESIGN.md.
--
-- Customers say what they want done and hint at how they want it done. Nothing on the board
-- or on site ever names a tool: players have to know which tool fits each task.
--
--   tier      "Homeowner", "Serious" or "Pro"
--   lawn      the yard: columns and rows (tiles of GameConfig.TileSize studs) and how many
--             flower patches / gnomes the crew must not hit
--   tasks     { type = a TaskTypes id, amount = how many } in the order the customer lists them.
--             A job without a mowing task gets an already-mown lawn. `rocky` (0-1) is the share of
--             a task's targets in rocky ground, for tasks with TaskTypes `rocky`.
--   notes     extra things this customer might say (one is picked at random)
--   parTime   seconds a solo player should take; beating it pays more on Speed jobs
--   basePay, xp, minLevel

local TaskTypes = require(script.Parent.TaskTypes)

local Jobs = {}

-- How much the finish (quality) and the clock (time) count toward pay. They add up to 1.
Jobs.Preferences = {
	Quality = { quality = 0.75, time = 0.25 },
	Balanced = { quality = 0.5, time = 0.5 },
	Speed = { quality = 0.25, time = 0.75 },
}
-- How often each preference shows up on the board.
Jobs.PreferenceOdds = { Balanced = 0.5, Quality = 0.25, Speed = 0.25 }

-- What customers say. It's the only hint about whether they care about a perfect finish or a
-- fast job, so keep the wording clear.
Jobs.Stories = {
	Quality = {
		"We're having wedding photos in the backyard on Saturday. It has to look immaculate.",
		"The garden club judges our street next week. I want it looking like a magazine cover.",
		"The house goes on the market tomorrow and the photographer comes first thing. Make it perfect.",
		"My father kept this yard like a putting green for forty years. Please do it justice.",
		"Our in-laws arrive tonight and they notice everything. Take your time and get it right.",
	},
	Speed = {
		"Just knock it down before the HOA inspection at noon.",
		"The movers come in an hour. Quick and tidy is all I need.",
		"The neighbors have started complaining. As fast as you can, please.",
		"We've got a barbecue starting soon. Get it presentable, quickly.",
		"I'm renting it out this afternoon. Doesn't need to be fancy, just done.",
	},
	Balanced = {
		"The usual tidy-up. Nothing fancy, but do it properly.",
		"Regular maintenance, please. Keep it neat.",
		"We've been away for a couple of weeks. Bring it back to normal.",
		"Same as every month: make it look looked-after.",
	},
}

Jobs.Customers = {
	"Mrs. Alvarez",
	"Mr. Chen",
	"The Okafors",
	"Dr. Patel",
	"Mr. Kowalski",
	"Ms. Nguyen",
	"The Hendersons",
	"Mrs. Rossi",
	"Mr. Haddad",
	"The Lindqvists",
	"Ms. Ortega",
	"Pastor Green",
}

Jobs.Templates = {
	{
		id = "QuickMow",
		name = "Quick Mow",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "MowSmallLawn" } },
		notes = { "It's only a small patch out front, and the grass isn't very long." },
		parTime = 45,
		basePay = 40,
		xp = 10,
	},
	{
		id = "EdgingTouchUp",
		name = "Edging Touch-Up",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 7, rows = 5, flowerPatches = 0 },
		tasks = { { type = "EdgeSidewalk" } },
		notes = { "The lawn's fine, but the grass is creeping over the sidewalk." },
		parTime = 50,
		basePay = 45,
		xp = 10,
	},
	{
		id = "LeafCleanup",
		name = "Leaf Cleanup",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 8, rows = 6, flowerPatches = 1 },
		tasks = { { type = "RakeLeaves", amount = 6 } },
		notes = { "The big maple dropped everything at once. The lawn's buried." },
		parTime = 70,
		basePay = 60,
		xp = 15,
	},
	{
		id = "TinyFrontYard",
		name = "Tiny Front Yard",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 7, rows = 5, flowerPatches = 1 },
		tasks = {
			{ type = "MowSmallLawn" },
			{ type = "EdgeSidewalk" },
			{ type = "TrimAroundObstacles", amount = 3 },
		},
		parTime = 90,
		basePay = 90,
		xp = 20,
	},
	-- Garden housework (design phase C): small hand-tool jobs for new players.
	{
		id = "PottingDay",
		name = "Potting Day",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "PotUpPlants", amount = 4 } },
		notes = { "The nursery plants are lined up on the patio, and the potting mix is nice and loose." },
		parTime = 60,
		basePay = 45,
		xp = 12,
	},
	{
		id = "SpringBulbs",
		name = "Spring Bulbs",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "PlantBulbsAtDepth", amount = 8 } },
		notes = { "Six inches deep, exactly. Any shallower and the squirrels get them, any deeper and they rot." },
		parTime = 70,
		basePay = 55,
		xp = 14,
	},
	{
		id = "SeedlingDay",
		name = "Seedling Day",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "TransplantSeedlings", amount = 8 }, { type = "WaterSeedlings", amount = 2 } },
		notes = { "The seedlings are tiny plugs, and the trays have gone bone dry. Go gently on them." },
		parTime = 85,
		basePay = 65,
		xp = 16,
	},
	{
		id = "VegetablePatch",
		name = "Vegetable Patch",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 0 },
		tasks = { { type = "LoosenBedTopsoil", amount = 2 }, { type = "SowSeedRows", amount = 4 } },
		notes = { "The soil crusted over after the last storm. The seed packets are waiting by the bed." },
		parTime = 80,
		basePay = 60,
		xp = 15,
	},
	{
		id = "DandelionPatrol",
		name = "Dandelion Patrol",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 7, rows = 5, flowerPatches = 1 },
		tasks = { { type = "RemoveDandelions", amount = 8 } },
		notes = { "Get the whole root or they're back in a week. And please don't leave holes all over the lawn." },
		parTime = 70,
		basePay = 50,
		xp = 13,
	},
	{
		id = "BedTidy",
		name = "Flower Bed Tidy",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "PullShallowWeeds", amount = 6 }, { type = "WaterBeds", amount = 3 } },
		notes = { "The weeds are only just coming up, and the beds haven't had a drink in days." },
		parTime = 90,
		basePay = 70,
		xp = 18,
	},
	{
		id = "CuttingGarden",
		name = "Cutting Garden",
		tier = "Homeowner",
		minLevel = 1,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "DeadheadAndCutFlowers", amount = 6 }, { type = "WaterBeds", amount = 2 } },
		notes = { "Snip off the spent flowers, and cut us a bouquet of soft stems for the table." },
		parTime = 70,
		basePay = 60,
		xp = 15,
	},
	{
		id = "LawnAndWeeds",
		name = "Lawn and Weeds",
		tier = "Homeowner",
		minLevel = 2,
		lawn = { columns = 7, rows = 5, flowerPatches = 1 },
		tasks = { { type = "MowSmallLawn" }, { type = "RemoveDandelions", amount = 5 } },
		notes = { "Mowing only chops the dandelion tops off. They need to come out." },
		parTime = 100,
		basePay = 80,
		xp = 20,
	},
	{
		id = "RosePruning",
		name = "Rose Pruning",
		tier = "Homeowner",
		minLevel = 2,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "PruneRoses", amount = 3 }, { type = "CutDeadWood", amount = 2 } },
		notes = { "The climbing roses are lovely and vicious. Some of the old shrubs are just dead sticks now." },
		parTime = 100,
		basePay = 85,
		xp = 22,
	},
	{
		id = "ShrubShaping",
		name = "Shrub Shaping",
		tier = "Homeowner",
		minLevel = 2,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "PruneLiveStems", amount = 3 }, { type = "CutDeadWood", amount = 3 } },
		notes = { "Some branches are fresh and green, some are dry and brittle. Treat them differently." },
		parTime = 100,
		basePay = 80,
		xp = 20,
	},
	{
		id = "PerennialMove",
		name = "Moving the Perennials",
		tier = "Homeowner",
		minLevel = 2,
		lawn = { columns = 6, rows = 5, flowerPatches = 1 },
		tasks = { { type = "TransplantPerennials", amount = 3 }, { type = "WaterBeds", amount = 3 } },
		notes = { "The hostas got huge. Move them, big root balls and all, then soak them in." },
		parTime = 110,
		basePay = 85,
		xp = 22,
	},
	{
		id = "GrandmasGarden",
		name = "Grandma's Garden",
		tier = "Homeowner",
		minLevel = 3,
		lawn = { columns = 7, rows = 6, flowerPatches = 2 },
		tasks = {
			{ type = "PotUpPlants", amount = 3 },
			{ type = "PlantBulbsAtDepth", amount = 5 },
			{ type = "PruneRoses", amount = 2 },
			{ type = "WaterSeedlings", amount = 2 },
		},
		notes = { "It's my grandmother's garden, and she'll be watching every move from the porch." },
		parTime = 180,
		basePay = 140,
		xp = 35,
	},
	-- Serious gardening (design phase D): digging, hauling, feeding and spraying.
	{
		id = "NewShrubBorder",
		name = "New Shrub Border",
		tier = "Serious",
		minLevel = 3,
		lawn = { columns = 8, rows = 6, flowerPatches = 1 },
		tasks = {
			{ type = "CutBedEdgeOrSod", amount = 4 },
			{ type = "DigPlantingHole", amount = 3, rocky = 0.3 },
			{ type = "LevelSoilSpreadMulch", amount = 2 },
		},
		notes = { "The back corner of this yard is full of old rubble." },
		parTime = 200,
		basePay = 230,
		xp = 55,
	},
	{
		id = "TreePlanting",
		name = "Tree Planting",
		tier = "Serious",
		minLevel = 4,
		lawn = { columns = 8, rows = 6, flowerPatches = 1 },
		tasks = {
			{ type = "DigPlantingHole", amount = 4, rocky = 0.6 },
			{ type = "HaulHeavyMaterial", amount = 3 },
		},
		notes = { "The builders buried half their rubble here. Expect to hit rock, and bring in fresh topsoil." },
		parTime = 240,
		basePay = 300,
		xp = 70,
	},
	{
		id = "VegetableBeds",
		name = "Vegetable Beds",
		tier = "Serious",
		minLevel = 3,
		lawn = { columns = 8, rows = 6, flowerPatches = 0 },
		tasks = {
			{ type = "DeepLoosenBed", amount = 2 },
			{ type = "HoeRowWeeds", amount = 4 },
			{ type = "HaulBulkyLight", amount = 3 },
		},
		notes = { "Loosen the beds deep down, but don't flip the soil over. The leaf mulch pile is on the driveway." },
		parTime = 220,
		basePay = 240,
		xp = 55,
	},
	{
		id = "ClayGarden",
		name = "Clay Garden",
		tier = "Serious",
		minLevel = 4,
		lawn = { columns = 8, rows = 6, flowerPatches = 1 },
		tasks = {
			{ type = "TurnHeavySoilOrLiftRoots", amount = 3 },
			{ type = "BreakHardGround", amount = 2 },
		},
		notes = { "Heavy clay, old roots everywhere, and one patch that's practically concrete." },
		parTime = 220,
		basePay = 260,
		xp = 60,
	},
	{
		id = "TreeTrimming",
		name = "Tree Trimming",
		tier = "Serious",
		minLevel = 3,
		lawn = { columns = 8, rows = 6, flowerPatches = 1 },
		tasks = {
			{ type = "CutBranchesMedium", amount = 4 },
			{ type = "CutBranchesThick", amount = 2 },
			{ type = "HaulBulkyLight", amount = 2 },
		},
		notes = { "Most of the branches are thumb-thick, but a couple are as thick as my wrist." },
		parTime = 210,
		basePay = 250,
		xp = 58,
	},
	{
		id = "LawnFeed",
		name = "Lawn Feed",
		tier = "Serious",
		minLevel = 3,
		lawn = { columns = 9, rows = 7, flowerPatches = 2 },
		tasks = { { type = "MowMediumLawn" }, { type = "FertilizeLawn" } },
		notes = { "The lawn looks hungry. Feed it evenly: no stripes, no bald patches." },
		parTime = 200,
		basePay = 220,
		xp = 50,
	},
	{
		id = "WeedControl",
		name = "Weed Control",
		tier = "Serious",
		minLevel = 4,
		lawn = { columns = 9, rows = 7, flowerPatches = 2 },
		tasks = { { type = "SpotSprayWeeds", amount = 6 }, { type = "FertilizeLawn" } },
		notes = { "Kill the thistles, not my lawn. And be careful handling that weed killer." },
		parTime = 220,
		basePay = 260,
		xp = 60,
	},
	{
		id = "GravelPath",
		name = "Gravel Path",
		tier = "Serious",
		minLevel = 5,
		lawn = { columns = 8, rows = 6, flowerPatches = 1 },
		tasks = {
			{ type = "HaulHeavyMaterial", amount = 5 },
			{ type = "LevelSoilSpreadMulch", amount = 3 },
		},
		notes = { "The gravel for the new path got dumped on the driveway. It's heavy, so don't spill it." },
		parTime = 260,
		basePay = 340,
		xp = 80,
	},
	{
		id = "FallCleanup",
		name = "Fall Cleanup",
		tier = "Serious",
		minLevel = 4,
		lawn = { columns = 9, rows = 7, flowerPatches = 1 },
		tasks = {
			{ type = "RakeLeaves", amount = 6 },
			{ type = "HaulBulkyLight", amount = 4 },
			{ type = "CutBranchesMedium", amount = 2 },
		},
		notes = { "Clear up every leaf, and take the big pile on the driveway out back to the compost." },
		parTime = 240,
		basePay = 280,
		xp = 65,
	},
	{
		id = "HedgeShaping",
		name = "Hedge Shaping",
		tier = "Serious",
		minLevel = 2,
		lawn = { columns = 9, rows = 6, flowerPatches = 1 },
		tasks = { { type = "ShearHedges", amount = 4 } },
		notes = { "The hedges in front of the house have gone shaggy." },
		parTime = 90,
		basePay = 120,
		xp = 30,
	},
	{
		id = "SuburbanLawn",
		name = "Suburban Lawn",
		tier = "Serious",
		minLevel = 2,
		lawn = { columns = 9, rows = 7, flowerPatches = 2 },
		tasks = {
			{ type = "MowMediumLawn" },
			{ type = "EdgeSidewalk" },
			{ type = "TrimAroundObstacles", amount = 6 },
			{ type = "RakeLeaves", amount = 4 },
		},
		parTime = 150,
		basePay = 170,
		xp = 40,
	},
	{
		id = "CornerLot",
		name = "Corner Lot",
		tier = "Serious",
		minLevel = 3,
		lawn = { columns = 12, rows = 9, flowerPatches = 3 },
		tasks = {
			{ type = "MowMediumLawn" },
			{ type = "EdgeSidewalk" },
			{ type = "TrimAroundObstacles", amount = 10 },
			{ type = "RakeLeaves", amount = 6 },
			{ type = "ShearHedges", amount = 4 },
		},
		parTime = 240,
		basePay = 320,
		xp = 80,
	},
	{
		id = "BigBackyard",
		name = "Big Backyard",
		tier = "Serious",
		minLevel = 5,
		lawn = { columns = 15, rows = 12, flowerPatches = 4 },
		tasks = {
			{ type = "MowMediumLawn" },
			{ type = "EdgeSidewalk" },
			{ type = "TrimAroundObstacles", amount = 14 },
			{ type = "RakeLeaves", amount = 10 },
			{ type = "ShearHedges", amount = 5 },
		},
		parTime = 360,
		basePay = 650,
		xp = 160,
	},
	{
		id = "NeighborhoodPark",
		name = "Neighborhood Park",
		tier = "Pro",
		minLevel = 8,
		lawn = { columns = 22, rows = 16, flowerPatches = 6 },
		tasks = {
			{ type = "MowLargeLawn" },
			{ type = "EdgeHardscape" },
			{ type = "TrimAroundObstacles", amount = 24 },
			{ type = "RakeLeaves", amount = 18 },
			{ type = "ShearHedges", amount = 8 },
		},
		notes = { "The park board wants it looking sharp for the summer concerts." },
		parTime = 600,
		basePay = 1500,
		xp = 375,
	},
	{
		id = "MansionEstate",
		name = "Mansion Estate",
		tier = "Pro",
		minLevel = 12,
		lawn = { columns = 28, rows = 22, flowerPatches = 8 },
		tasks = {
			{ type = "MowLargeLawn" },
			{ type = "EdgeHardscape" },
			{ type = "TrimAroundObstacles", amount = 34 },
			{ type = "RakeLeaves", amount = 26 },
			{ type = "ShearTallHedges", amount = 12 },
		},
		notes = { "The hedges along the drive are taller than the gardener." },
		parTime = 900,
		basePay = 3500,
		xp = 875,
	},
}

local STREETS = {
	"Maple St",
	"Oak Ave",
	"Birch Ln",
	"Willow Way",
	"Cedar Ct",
	"Elm St",
	"Pine Rd",
	"Sunset Blvd",
	"Meadow Dr",
	"Clover Ln",
}

-- Targets that cover the lawn itself; every other kind is placed a set number of times.
local LAWN_TARGETS = { Grass = true, Edge = true, Fertilize = true }

-- Catch templates that would make a job that can't be finished.
local byId = {}
for _, template in Jobs.Templates do
	byId[template.id] = template
	local targets = {}
	for _, task in template.tasks do
		local taskType = TaskTypes.get(task.type)
		assert(taskType, `{template.id} uses unknown task type {task.type}`)
		assert(taskType.target, `{template.id}: {task.type} has no yard targets until phase {taskType.phase}`)
		assert(not targets[taskType.target], `{template.id}: two tasks use {taskType.target} targets`)
		targets[taskType.target] = true
		if not LAWN_TARGETS[taskType.target] then
			assert((task.amount or 0) > 0, `{template.id}: {task.type} needs an amount`)
		end
	end
end

function Jobs.get(id: string)
	return byId[id]
end

function Jobs.randomAddress(rng: Random): string
	return string.format("%d %s", rng:NextInteger(10, 999), STREETS[rng:NextInteger(1, #STREETS)])
end

function Jobs.pickPreference(rng: Random): string
	local roll = rng:NextNumber()
	for _, preference in { "Balanced", "Quality", "Speed" } do
		roll -= Jobs.PreferenceOdds[preference]
		if roll <= 0 then
			return preference
		end
	end
	return "Balanced"
end

-- What the customer says: their general request plus, sometimes, a note about this yard.
function Jobs.story(rng: Random, template, preference: string): string
	local pool = Jobs.Stories[preference]
	local story = pool[rng:NextInteger(1, #pool)]
	if template.notes and #template.notes > 0 then
		story = template.notes[rng:NextInteger(1, #template.notes)] .. " " .. story
	end
	return story
end

-- The customer's to-do list, e.g. { "Mow the lawn", "Clear 4 piles of leaves off the lawn" }
function Jobs.todoList(template): { string }
	local list = {}
	for _, task in template.tasks do
		table.insert(list, TaskTypes.todo(task.type, task.amount))
	end
	return list
end

function Jobs.hasMowing(template): boolean
	for _, task in template.tasks do
		if TaskTypes.get(task.type).target == "Grass" then
			return true
		end
	end
	return false
end

return Jobs
