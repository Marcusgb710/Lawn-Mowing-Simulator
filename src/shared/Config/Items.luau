-- Everything you can buy in the shop. Each category is a list of tiers, cheapest first.
-- Players start owning every item with price = 0 (the reel mower and the rusty pickup).
--
-- Truck bed: each truck holds `bedSlots` tools. Only tools loaded in your truck bed come with you
-- to a job. Once your bed is full, trailers unlock and each one adds `extraSlots`.
--
-- Tool stats:
--   power     how much work the tool does per second (higher = faster)
--   radius    how far around you the tool reaches, in studs
--   walkSpeed only for mowers, your speed while pushing/riding it
--   motorized only for mowers, false means it only cuts while you're moving
--   ride      only for riding mowers: you sit on it instead of holding it. `seat` is where you sit,
--             in studs from where the tool's hand grip is (the steering wheel or lap bars):
--             X right, Y up, Z back. Tune it in Studio until the player sits on the seat.
--
-- Model swap: put a model named after the item's `id` in ReplicatedStorage.Assets.Tools
-- (or Assets.Trucks for trucks) and it replaces the placeholder automatically.

local Items = {}

Items.Categories = { "Mower", "Trimmer", "Rake", "Edger", "HedgeTrimmer", "Truck", "Trailer", "Business" }
Items.ToolCategories = { "Mower", "Trimmer", "Rake", "Edger", "HedgeTrimmer" }

Items.CategoryInfo = {
	-- damagesHazards: this tool wrecks flower patches and gnomes if you hit them with it.
	Mower = { displayName = "Mowers", toolName = "Mower", task = "Mow", damagesHazards = true },
	Trimmer = { displayName = "Weed Whackers", toolName = "Weed Whacker", task = "Weeds", damagesHazards = true },
	Rake = { displayName = "Rakes & Blowers", toolName = "Rake", task = "Leaves" },
	Edger = { displayName = "Edgers", toolName = "Edger", task = "Edge", damagesHazards = true },
	HedgeTrimmer = { displayName = "Hedge Trimmers", toolName = "Hedge Trimmer", task = "Hedge" },
	Truck = { displayName = "Trucks" },
	Trailer = { displayName = "Trailers" },
	Business = { displayName = "Business" },
}

Items.Catalog = {
	Mower = {
		{
			id = "ReelMower",
			name = "Reel Push Mower",
			price = 0,
			power = 3,
			radius = 2.5,
			walkSpeed = 12,
			motorized = false,
			color = Color3.fromRGB(120, 120, 120),
			description = "No motor. It only cuts while you keep pushing.",
		},
		{
			id = "GasPushMower",
			name = "Gas Push Mower",
			price = 750,
			power = 5,
			radius = 3.5,
			walkSpeed = 14,
			motorized = true,
			color = Color3.fromRGB(200, 40, 40),
			description = "A real engine. Cuts even when you stop.",
		},
		{
			id = "SelfPropelledMower",
			name = "Self-Propelled Mower",
			price = 3000,
			power = 6,
			radius = 4,
			walkSpeed = 18,
			motorized = true,
			color = Color3.fromRGB(40, 120, 200),
			description = "Drives itself forward so you can walk faster.",
		},
		{
			id = "RidingMower",
			name = "Riding Mower",
			price = 12000,
			power = 8,
			radius = 6,
			walkSpeed = 24,
			motorized = true,
			ride = { seat = Vector3.new(0, -0.9, 1.2) },
			color = Color3.fromRGB(40, 150, 60),
			description = "Sit down and mow big lawns quickly.",
		},
		{
			id = "ZeroTurnMower",
			name = "Zero-Turn Mower",
			price = 40000,
			power = 12,
			radius = 8,
			walkSpeed = 32,
			motorized = true,
			ride = { seat = Vector3.new(0, -0.6, 1) },
			color = Color3.fromRGB(240, 160, 20),
			description = "What the pros use. Very fast, very wide.",
		},
	},

	Trimmer = {
		{
			id = "GardenShears",
			name = "Garden Shears",
			price = 100,
			power = 1,
			radius = 3,
			color = Color3.fromRGB(150, 150, 150),
			description = "Snip snip. Slow, but it gets the weeds.",
		},
		{
			id = "ElectricTrimmer",
			name = "Electric String Trimmer",
			price = 400,
			power = 2,
			radius = 4,
			color = Color3.fromRGB(60, 160, 220),
			description = "A corded weed whacker.",
		},
		{
			id = "GasTrimmer",
			name = "Gas String Trimmer",
			price = 2000,
			power = 4,
			radius = 5,
			color = Color3.fromRGB(230, 120, 30),
			description = "More power, no cord.",
		},
		{
			id = "Brushcutter",
			name = "Pro Brushcutter",
			price = 8000,
			power = 7,
			radius = 7,
			color = Color3.fromRGB(200, 30, 30),
			description = "Tears through anything.",
		},
	},

	Rake = {
		{
			id = "OldRake",
			name = "Old Rake",
			price = 60,
			power = 1,
			radius = 4,
			color = Color3.fromRGB(140, 100, 60),
			description = "A few teeth are missing.",
		},
		{
			id = "WideRake",
			name = "Wide Rake",
			price = 300,
			power = 1.6,
			radius = 5,
			color = Color3.fromRGB(60, 140, 60),
			description = "Gathers more leaves per pull.",
		},
		{
			id = "LeafBlower",
			name = "Leaf Blower",
			price = 1800,
			power = 3,
			radius = 8,
			color = Color3.fromRGB(230, 120, 30),
			description = "Loud and effective.",
		},
		{
			id = "BackpackBlower",
			name = "Backpack Blower",
			price = 7000,
			power = 5,
			radius = 12,
			color = Color3.fromRGB(200, 30, 30),
			description = "Clears a yard in seconds.",
		},
	},

	Edger = {
		{
			id = "HalfMoonEdger",
			name = "Half-Moon Edger",
			price = 120,
			power = 1,
			radius = 3,
			color = Color3.fromRGB(130, 130, 130),
			description = "A sharp metal blade on a stick.",
		},
		{
			id = "ElectricEdger",
			name = "Electric Edger",
			price = 450,
			power = 2,
			radius = 4,
			color = Color3.fromRGB(60, 160, 220),
			description = "Clean lines with less effort.",
		},
		{
			id = "GasStickEdger",
			name = "Gas Stick Edger",
			price = 2200,
			power = 3.5,
			radius = 5,
			color = Color3.fromRGB(230, 120, 30),
			description = "Fast and precise.",
		},
		{
			id = "WalkBehindEdger",
			name = "Walk-Behind Edger",
			price = 8500,
			power = 6,
			radius = 6,
			color = Color3.fromRGB(200, 30, 30),
			description = "Perfect edges at walking speed.",
		},
	},

	HedgeTrimmer = {
		{
			id = "HandHedgeShears",
			name = "Hand Hedge Shears",
			price = 150,
			power = 1,
			radius = 5,
			color = Color3.fromRGB(150, 150, 150),
			description = "Big scissors for big bushes.",
		},
		{
			id = "ElectricHedgeTrimmer",
			name = "Electric Hedge Trimmer",
			price = 400,
			power = 2,
			radius = 6,
			color = Color3.fromRGB(60, 160, 220),
			description = "Buzzes through hedges.",
		},
		{
			id = "CordlessHedgeTrimmer",
			name = "Cordless Hedge Trimmer",
			price = 2000,
			power = 3.5,
			radius = 7,
			color = Color3.fromRGB(230, 120, 30),
			description = "Battery powered, longer reach.",
		},
		{
			id = "GasHedgeTrimmer",
			name = "Gas Hedge Trimmer",
			price = 8000,
			power = 6,
			radius = 8,
			color = Color3.fromRGB(200, 30, 30),
			description = "Shapes hedges in a few passes.",
		},
	},

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

local byId = {}
for category, list in Items.Catalog do
	byId[category] = {}
	for index, item in list do
		item.category = category
		item.tier = index
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
