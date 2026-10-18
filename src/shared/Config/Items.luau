-- Everything you can buy in the shop, by shop tab.
-- Tools come from Tools.luau (only the ones available right now are sold); trucks, trailers and
-- business upgrades are listed below. Each tab is cheapest first, and `rank` is an item's place
-- in its tab. Players start owning every item with price = 0 (the reel mower, the rusty pickup
-- and the tool shed).
--
-- Truck space: every tool takes some `space` by its size class (Tools.SizeClasses), and each
-- truck holds `space` units. Once the truck is full, trailers unlock and each one adds its own
-- `space`. Ride-on machines don't fit in a truck at all: they need a trailer with `bays`.
--
-- Storage: each business building has room for a set number of tools of each kind (`storage`,
-- see Storage.luau). You can't buy a tool without a free spot for it.
--
-- Model swap: put a model named after the item's `id` in ReplicatedStorage.Assets.Tools
-- (or Assets.Trucks for trucks) and it replaces the placeholder automatically.

local Tools = require(script.Parent.Tools)

local Items = {}

-- Shop tabs filled from Tools.luau. Everything in them is carried to the truck by hand.
Items.ToolCategories = {
	"Mower",
	"Trimmer",
	"Rake",
	"Edger",
	"HedgeTrimmer",
	"HandTool",
	"Pruning",
	"Watering",
	"Digging",
	"Hauling",
	"LawnCare",
	"Protection",
	"Supplies",
}
-- Every shop tab, in order: the tools, then vehicles and the business.
Items.Categories = table.clone(Items.ToolCategories)
for _, category in { "Truck", "Trailer", "Business" } do
	table.insert(Items.Categories, category)
end

Items.CategoryInfo = {
	Mower = { displayName = "Mowers", toolName = "Mower" },
	Trimmer = { displayName = "Trimmers", toolName = "Trimmer" },
	Rake = { displayName = "Rakes & Blowers", toolName = "Rake" },
	Edger = { displayName = "Edgers", toolName = "Edger" },
	HedgeTrimmer = { displayName = "Hedge Tools", toolName = "Hedge Tool" },
	HandTool = { displayName = "Planting & Weeding", toolName = "Hand Tool" },
	Pruning = { displayName = "Pruning", toolName = "Pruner" },
	Watering = { displayName = "Watering", toolName = "Watering" },
	Digging = { displayName = "Digging", toolName = "Digging Tool" },
	Hauling = { displayName = "Barrows & Carts", toolName = "Barrow" },
	LawnCare = { displayName = "Lawn Care", toolName = "Lawn Machine" },
	Protection = { displayName = "Gloves", toolName = "Gloves" },
	Supplies = { displayName = "Supplies", toolName = "Supplies" },
	Truck = { displayName = "Trucks" },
	Trailer = { displayName = "Trailers" },
	Business = { displayName = "Business" },
}

Items.Catalog = {
	Truck = {
		{
			id = "RustyPickup",
			name = "Rusty Pickup",
			price = 0,
			payoutBonus = 0,
			space = 6,
			color = Color3.fromRGB(150, 90, 60),
			description = "It runs. Mostly.",
		},
		{
			id = "WorkPickup",
			name = "Work Pickup",
			price = 5000,
			payoutBonus = 0.1,
			space = 8,
			color = Color3.fromRGB(240, 240, 240),
			description = "Customers trust a clean truck. +10% pay.",
		},
		{
			id = "HeavyDutyPickup",
			name = "Heavy Duty Pickup",
			price = 20000,
			payoutBonus = 0.25,
			space = 10,
			color = Color3.fromRGB(30, 90, 170),
			description = "Built tough, with a longer bed. +25% pay.",
		},
		{
			id = "LandscapingTruck",
			name = "Landscaping Box Truck",
			price = 60000,
			payoutBonus = 0.5,
			space = 14,
			color = Color3.fromRGB(40, 140, 60),
			description = "You're a real business now. +50% pay.",
		},
	},

	-- Locked until your truck is full. Only one trailer can be hitched at a time.
	Trailer = {
		{
			id = "UtilityTrailer",
			name = "Small Utility Trailer",
			price = 1200,
			space = 6,
			bays = 0,
			color = Color3.fromRGB(110, 110, 110),
			description = "An open trailer with low rails. Hitch it up for more room for tools and push machines.",
		},
		{
			id = "LandscapeTrailer",
			name = "Enclosed Landscape Trailer",
			price = 3000,
			space = 10,
			bays = 0,
			color = Color3.fromRGB(240, 240, 240),
			description = "A big enclosed box trailer that locks. Lots of room, but no ramp for ride-on machines.",
		},
		{
			id = "EquipmentTrailer",
			name = "Equipment Trailer",
			price = 6000,
			space = 4,
			bays = 2,
			color = Color3.fromRGB(45, 45, 50),
			description = "A low flatbed with a fold-down ramp. Two ride-on machines drive up onto it, with a "
				.. "little room up front for tools. The only way to bring a riding mower to a job.",
		},
	},

	-- Your home base. Upgrades must be bought in order, and the building on your plot changes.
	-- `storage` is how many tools of each kind it holds (see Storage.luau). `noEngines` means its
	-- floor spots only take push machines without an engine. Every business has a workbench;
	-- `fixtures` are shop machines that come with the building (see Maintenance.luau). `desk` is
	-- the job computer desk that stands inside (Props/<desk>).
	-- Model swap: put a model named after the id in ReplicatedStorage.Assets.Buildings.
	Business = {
		{
			id = "Shed",
			name = "Tool Shed",
			price = 0,
			payoutBonus = 0,
			storage = { Pegboard = 12, WallRack = 4, WallHooks = 1, Shelf = 4, Floor = 1, Bay = 0 },
			desk = "JobLaptopTable",
			noEngines = true,
			color = Color3.fromRGB(150, 105, 65),
			description = "Where every lawn empire starts. Room for hand tools, a few rakes, one trimmer and "
				.. "one push mower without an engine.",
		},
		{
			id = "Garage",
			name = "Garage",
			price = 4000,
			payoutBonus = 0.1,
			storage = { Pegboard = 16, WallRack = 8, WallHooks = 4, Shelf = 8, Floor = 2, Bay = 0 },
			desk = "JobComputerDesk",
			color = Color3.fromRGB(200, 200, 190),
			description = "A real roll-up door, and floor room for gas mowers. Customers pay +10%.",
		},
		{
			id = "SmallOffice",
			name = "Small Office",
			price = 20000,
			payoutBonus = 0.25,
			storage = { Pegboard = 24, WallRack = 12, WallHooks = 6, Shelf = 12, Floor = 4, Bay = 2 },
			desk = "JobOfficeDesk",
			fixtures = { "AirCompressor" },
			color = Color3.fromRGB(70, 120, 60),
			description = "You're official now, with two equipment bays for ride-on mowers and a shop air "
				.. "compressor. Customers pay +25%.",
		},
		{
			id = "EquipmentYard",
			name = "Equipment Yard",
			price = 75000,
			payoutBonus = 0.4,
			storage = { Pegboard = 32, WallRack = 16, WallHooks = 10, Shelf = 16, Floor = 6, Bay = 5 },
			desk = "JobOfficeDesk",
			fixtures = { "AirCompressor", "BenchGrinder" },
			color = Color3.fromRGB(180, 185, 185),
			description = "A metal shop with a big roll-up door, covered bays for five ride-on machines, an air "
				.. "compressor and a bench grinder. Customers pay +40%.",
		},
	},
}

-- Tool tabs come straight from Tools.luau.
for _, category in Items.ToolCategories do
	Items.Catalog[category] = Tools.inCategory(category)
end

local byId = {}
for category, list in Items.Catalog do
	byId[category] = {}
	for index, item in list do
		item.category = category
		item.rank = index
		byId[category][item.id] = item
	end
end

function Items.get(category: string, id: string)
	local list = byId[category]
	return list and list[id]
end

function Items.isToolCategory(category): boolean
	return typeof(category) == "string" and table.find(Items.ToolCategories, category) ~= nil
end

-- The free item a player starts with in this category, if there is one.
function Items.starter(category: string)
	local first = Items.Catalog[category][1]
	return if first and first.price == 0 then first else nil
end

-- Every free tool a new player starts with, in shop order.
function Items.starterTools()
	local list = {}
	for _, category in Items.ToolCategories do
		for _, item in Items.Catalog[category] do
			if item.price == 0 then
				table.insert(list, item)
			end
		end
	end
	return list
end

-- Every tool in `owned` ({ [category] = { [id] = true } }), in shop order.
function Items.ownedTools(owned)
	local list = {}
	for _, category in Items.ToolCategories do
		local ids = owned[category]
		if ids then
			for _, item in Items.Catalog[category] do
				if ids[item.id] then
					table.insert(list, item)
				end
			end
		end
	end
	return list
end

-- Truck space and ride-on bays for these equipped vehicles.
function Items.vehicleSpace(equipped): (number, number)
	local truck = Items.get("Truck", equipped.Truck) or Items.Catalog.Truck[1]
	local trailer = equipped.Trailer and Items.get("Trailer", equipped.Trailer)
	return truck.space + (if trailer then trailer.space else 0), if trailer then trailer.bays else 0
end

return Items
