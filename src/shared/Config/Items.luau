-- Everything you can buy in the shop, by shop tab.
-- Tools come from Tools.luau (only the ones available right now are sold); trucks, trailers and
-- business upgrades are listed below. Each tab is cheapest first, and `rank` is an item's place
-- in its tab. Players start owning every item with price = 0 (the reel mower, the rusty pickup
-- and the tool shed).
--
-- Truck bed: each truck holds `bedSlots` tools. Only tools loaded in your truck bed come with you
-- to a job. Once your bed is full, trailers unlock and each one adds `extraSlots`.
--
-- Model swap: put a model named after the item's `id` in ReplicatedStorage.Assets.Tools
-- (or Assets.Trucks for trucks) and it replaces the placeholder automatically.

local Tools = require(script.Parent.Tools)

local Items = {}

Items.Categories = { "Mower", "Trimmer", "Rake", "Edger", "HedgeTrimmer", "Truck", "Trailer", "Business" }
Items.ToolCategories = { "Mower", "Trimmer", "Rake", "Edger", "HedgeTrimmer" }

Items.CategoryInfo = {
	Mower = { displayName = "Mowers", toolName = "Mower" },
	Trimmer = { displayName = "Trimmers", toolName = "Trimmer" },
	Rake = { displayName = "Rakes & Blowers", toolName = "Rake" },
	Edger = { displayName = "Edgers", toolName = "Edger" },
	HedgeTrimmer = { displayName = "Hedge Tools", toolName = "Hedge Tool" },
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
			bedSlots = 3,
			color = Color3.fromRGB(150, 90, 60),
			description = "It runs. Mostly.",
		},
		{
			id = "WorkPickup",
			name = "Work Pickup",
			price = 5000,
			payoutBonus = 0.1,
			bedSlots = 3,
			color = Color3.fromRGB(240, 240, 240),
			description = "Customers trust a clean truck. +10% pay.",
		},
		{
			id = "HeavyDutyPickup",
			name = "Heavy Duty Pickup",
			price = 20000,
			payoutBonus = 0.25,
			bedSlots = 3,
			color = Color3.fromRGB(30, 90, 170),
			description = "Built tough. +25% pay.",
		},
		{
			id = "LandscapingTruck",
			name = "Landscaping Box Truck",
			price = 60000,
			payoutBonus = 0.5,
			bedSlots = 3,
			color = Color3.fromRGB(40, 140, 60),
			description = "You're a real business now. +50% pay.",
		},
	},

	-- Locked until your truck bed is full. Only one trailer can be hitched at a time.
	Trailer = {
		{
			id = "UtilityTrailer",
			name = "Small Utility Trailer",
			price = 1200,
			extraSlots = 1,
			color = Color3.fromRGB(110, 110, 110),
			description = "Hitch it up and carry one more tool.",
		},
		{
			id = "LandscapeTrailer",
			name = "Enclosed Landscape Trailer",
			price = 3000,
			extraSlots = 2,
			color = Color3.fromRGB(240, 240, 240),
			description = "Room for two more tools, and it locks.",
		},
	},

	-- Your home base. Upgrades must be bought in order, and the building on your plot changes.
	-- Model swap: put a model named after the id in ReplicatedStorage.Assets.Buildings.
	Business = {
		{
			id = "Shed",
			name = "Tool Shed",
			price = 0,
			payoutBonus = 0,
			color = Color3.fromRGB(150, 105, 65),
			description = "Where every lawn empire starts.",
		},
		{
			id = "Garage",
			name = "Garage",
			price = 4000,
			payoutBonus = 0.1,
			color = Color3.fromRGB(200, 200, 190),
			description = "A real roll-up door. Customers pay +10%.",
		},
		{
			id = "SmallOffice",
			name = "Small Office",
			price = 20000,
			payoutBonus = 0.25,
			color = Color3.fromRGB(70, 120, 60),
			description = "You're official now. Customers pay +25%.",
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

-- The free item a player starts with in this category, if there is one.
function Items.starter(category: string)
	local first = Items.Catalog[category][1]
	return if first.price == 0 then first else nil
end

-- How many tools fit in a truck bed (plus trailer) for these equipped items.
function Items.bedCapacity(equipped): number
	local truck = Items.get("Truck", equipped.Truck)
	local trailer = equipped.Trailer and Items.get("Trailer", equipped.Trailer)
	return (if truck then truck.bedSlots else 3) + (if trailer then trailer.extraSlots else 0)
end

function Items.countLoaded(loadout): number
	local count = 0
	for _, category in Items.ToolCategories do
		if loadout[category] then
			count += 1
		end
	end
	return count
end

return Items
