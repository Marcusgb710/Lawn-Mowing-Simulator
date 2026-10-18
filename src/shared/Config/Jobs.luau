-- Job types for the job board. See docs/GAME_DESIGN.md.
--
-- Customers say what they want done and hint at how they want it done. Nothing on the board
-- or on site ever names a tool: players have to know which tool fits each task.
--
--   tier      "Homeowner", "Serious" or "Pro"
--   lawn      the yard: columns and rows (tiles of GameConfig.TileSize studs) and how many
--             flower patches / gnomes the crew must not hit
--   tasks     { type = a TaskTypes id, amount = how many } in the order the customer lists them.
--             A job without a mowing task gets an already-mown lawn.
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

local byId = {}
for _, template in Jobs.Templates do
	byId[template.id] = template
	for _, task in template.tasks do
		assert(TaskTypes.get(task.type), `{template.id} uses unknown task type {task.type}`)
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
