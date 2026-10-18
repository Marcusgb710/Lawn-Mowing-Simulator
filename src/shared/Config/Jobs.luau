-- Job types that show up on the job board, and the lawn care tasks a job can include.
-- Lawn size is in tiles (each tile is GameConfig.TileSize studs).
-- Set weeds / leafPiles / hedges to 0, or edging to false, to leave that task out.
-- flowerPatches are things the crew must NOT hit (flowers and garden gnomes).
-- parTime is how many seconds a solo player should take; beating it pays more.

local Jobs = {}

Jobs.TaskOrder = { "Mow", "Edge", "Weeds", "Leaves", "Hedge" }

Jobs.TaskInfo = {
	Mow = { label = "Mow the lawn", tool = "Mower", workPerTarget = 1 },
	Edge = { label = "Edge the sidewalk & driveway", tool = "Edger", workPerTarget = 1.5 },
	Weeds = { label = "Whack the weeds", tool = "Trimmer", workPerTarget = 2 },
	Leaves = { label = "Rake the leaves", tool = "Rake", workPerTarget = 3 },
	Hedge = { label = "Trim the hedges", tool = "HedgeTrimmer", workPerTarget = 6 },
}

Jobs.Templates = {
	{
		id = "QuickMow",
		name = "Quick Mow",
		minLevel = 1,
		columns = 6,
		rows = 5,
		edging = false,
		weeds = 0,
		leafPiles = 0,
		hedges = 0,
		flowerPatches = 1,
		parTime = 45,
		basePay = 40,
		xp = 10,
	},
	{
		id = "TinyFrontYard",
		name = "Tiny Front Yard",
		minLevel = 1,
		columns = 7,
		rows = 5,
		edging = true,
		weeds = 3,
		leafPiles = 0,
		hedges = 0,
		flowerPatches = 1,
		parTime = 90,
		basePay = 90,
		xp = 20,
	},
	{
		id = "SuburbanLawn",
		name = "Suburban Lawn",
		minLevel = 2,
		columns = 9,
		rows = 7,
		edging = true,
		weeds = 6,
		leafPiles = 4,
		hedges = 0,
		flowerPatches = 2,
		parTime = 150,
		basePay = 170,
		xp = 40,
	},
	{
		id = "CornerLot",
		name = "Corner Lot",
		minLevel = 3,
		columns = 12,
		rows = 9,
		edging = true,
		weeds = 10,
		leafPiles = 6,
		hedges = 4,
		flowerPatches = 3,
		parTime = 240,
		basePay = 320,
		xp = 80,
	},
	{
		id = "BigBackyard",
		name = "Big Backyard",
		minLevel = 5,
		columns = 15,
		rows = 12,
		edging = true,
		weeds = 14,
		leafPiles = 10,
		hedges = 5,
		flowerPatches = 4,
		parTime = 360,
		basePay = 650,
		xp = 160,
	},
	{
		id = "NeighborhoodPark",
		name = "Neighborhood Park",
		minLevel = 8,
		columns = 22,
		rows = 16,
		edging = true,
		weeds = 24,
		leafPiles = 18,
		hedges = 8,
		flowerPatches = 6,
		parTime = 600,
		basePay = 1500,
		xp = 375,
	},
	{
		id = "MansionEstate",
		name = "Mansion Estate",
		minLevel = 12,
		columns = 28,
		rows = 22,
		edging = true,
		weeds = 34,
		leafPiles = 26,
		hedges = 12,
		flowerPatches = 8,
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
end

function Jobs.get(id: string)
	return byId[id]
end

function Jobs.randomAddress(rng: Random): string
	return string.format("%d %s", rng:NextInteger(10, 999), STREETS[rng:NextInteger(1, #STREETS)])
end

-- Which tool categories a crew needs to bring for this job, e.g. { "Mower", "Edger" }
function Jobs.requiredTools(template): { string }
	local tools = { Jobs.TaskInfo.Mow.tool }
	if template.edging then
		table.insert(tools, Jobs.TaskInfo.Edge.tool)
	end
	if template.weeds > 0 then
		table.insert(tools, Jobs.TaskInfo.Weeds.tool)
	end
	if template.leafPiles > 0 then
		table.insert(tools, Jobs.TaskInfo.Leaves.tool)
	end
	if template.hedges > 0 then
		table.insert(tools, Jobs.TaskInfo.Hedge.tool)
	end
	return tools
end

-- Short task list for the job board, e.g. { "Mow", "Edge", "6 weeds", "2 hedges" }
function Jobs.describe(template): { string }
	local parts = { "Mow" }
	if template.edging then
		table.insert(parts, "Edge")
	end
	if template.weeds > 0 then
		table.insert(parts, template.weeds .. " weeds")
	end
	if template.leafPiles > 0 then
		table.insert(parts, template.leafPiles .. " leaf piles")
	end
	if template.hedges > 0 then
		table.insert(parts, template.hedges .. " hedges")
	end
	return parts
end

return Jobs
