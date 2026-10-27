-- Yard decorations for your crew's business (docs/GAME_DESIGN.md, "Decorations"; models in
-- alphainstructions/instructions34.md). They're ordered from the Decorations tab of the shop
-- computer's Orders app, come in a box like tools, and are placed in first person anywhere on the
-- plot but the driveway and the building. They add to the business's curb appeal (`appeal`,
-- with less for each extra one of the same kind; see HomeLawn.decorShare).
--
--   size     about how big it is (W x H x D, studs), for the placeholder
--   box      the delivery box it comes in
--   onLawn   small enough to stand on the grass (a stake or a post); everything else stays off it
--   snaps    joins end to end with others like it (SnapL / SnapR markers)
--   shrub    shows its `<Id>__Overgrowth` until it's trimmed with a hedge tool, then grows back
--   holds    ground cover other decorations stand in or on (a bed's shrubs, a bench on pavers)
--   won      never sold: it's won (the Best Yard Trophy, from the contest; see ContestService),
--            comes in a box like an order and can't be sent back
--
-- Model swap: put a model named after the id in assets/Decorations.

local Decorations = {}

Decorations.List = {
	-- Borders and paths
	{
		id = "PicketFenceSection",
		name = "Picket Fence Section",
		price = 60,
		appeal = 3,
		size = Vector3.new(8.6, 3.2, 0.4),
		box = "DeliveryBoxLong",
		snaps = true,
		color = Color3.fromRGB(245, 245, 240),
		description = "An eight-foot panel of white pickets. Line them up along the street.",
	},
	{
		id = "StoneEdgingSection",
		name = "Stone Edging",
		price = 35,
		appeal = 2,
		size = Vector3.new(4.3, 0.55, 0.9),
		box = "DeliveryBoxLong",
		snaps = true,
		color = Color3.fromRGB(150, 140, 125),
		description = "Tumbled stone blocks for a crisp border around a bed or path.",
	},
	{
		id = "PaverPathSection",
		name = "Paver Path",
		price = 45,
		appeal = 2,
		size = Vector3.new(4.3, 0.2, 4.3),
		box = "DeliveryBoxLarge",
		snaps = true,
		holds = true,
		color = Color3.fromRGB(175, 160, 145),
		description = "A square of herringbone pavers. Lay a few in a row for a path to the door.",
	},
	{
		id = "MulchBedSection",
		name = "Mulch Bed",
		price = 70,
		appeal = 3,
		size = Vector3.new(8.6, 0.4, 4.3),
		box = "DeliveryBoxLarge",
		snaps = true,
		holds = true,
		color = Color3.fromRGB(110, 75, 50),
		description = "Steel-edged bed of shredded bark, ready for shrubs and planters.",
	},
	-- Plants
	{
		id = "BoxwoodShrub",
		name = "Boxwood Shrub",
		price = 45,
		appeal = 3,
		size = Vector3.new(2.9, 2.9, 2.9),
		box = "DeliveryBoxLarge",
		shrub = true,
		color = Color3.fromRGB(60, 120, 55),
		description = "A rounded evergreen. Keep it clipped or it gets shaggy.",
	},
	{
		id = "HydrangeaBush",
		name = "Hydrangea",
		price = 55,
		appeal = 4,
		size = Vector3.new(4, 3.6, 4),
		box = "DeliveryBoxLarge",
		shrub = true,
		color = Color3.fromRGB(120, 140, 210),
		description = "Big blue-to-pink flower heads all summer. Needs a trim now and then.",
	},
	{
		id = "JapaneseMaple",
		name = "Japanese Maple",
		price = 250,
		appeal = 7,
		size = Vector3.new(9, 9, 9),
		box = "DeliveryCrate",
		color = Color3.fromRGB(170, 40, 40),
		description = "A small tree with a layered red canopy. The showpiece of a front yard.",
	},
	{
		id = "TerracottaPlanter",
		name = "Terracotta Planter",
		price = 80,
		appeal = 3,
		size = Vector3.new(2, 2.8, 2),
		box = "DeliveryBoxLarge",
		color = Color3.fromRGB(190, 100, 60),
		description = "A big rolled-rim pot spilling over with petunias and ivy.",
	},
	{
		id = "RaisedGardenBed",
		name = "Raised Garden Bed",
		price = 180,
		appeal = 5,
		size = Vector3.new(8.6, 2.5, 4.3),
		box = "DeliveryCrate",
		color = Color3.fromRGB(160, 110, 70),
		description = "A cedar bed of tomatoes, lettuce and peppers.",
	},
	-- Features
	{
		id = "BirdBath",
		name = "Bird Bath",
		price = 120,
		appeal = 4,
		size = Vector3.new(2.2, 2.6, 2.2),
		box = "DeliveryBoxLarge",
		color = Color3.fromRGB(185, 180, 170),
		description = "A cast-concrete bowl on a fluted pedestal. The birds will find it.",
	},
	{
		id = "TieredFountain",
		name = "Tiered Fountain",
		price = 900,
		appeal = 10,
		size = Vector3.new(6, 5.4, 6),
		box = "DeliveryCrate",
		color = Color3.fromRGB(190, 185, 175),
		description = "Three tiers of cast stone and running water. The whole street will notice.",
	},
	{
		id = "GardenArbor",
		name = "Garden Arbor",
		price = 300,
		appeal = 7,
		size = Vector3.new(4.6, 8.2, 2.2),
		box = "DeliveryCrate",
		color = Color3.fromRGB(245, 245, 240),
		description = "A white arched arbor with climbing roses, wide enough to walk through.",
	},
	{
		id = "GardenBench",
		name = "Garden Bench",
		price = 350,
		appeal = 5,
		size = Vector3.new(5.4, 3.2, 2.2),
		box = "DeliveryCrate",
		color = Color3.fromRGB(150, 105, 65),
		description = "A three-seat teak bench. Take a seat and admire your work.",
	},
	{
		id = "PatioSet",
		name = "Patio Set",
		price = 800,
		appeal = 7,
		size = Vector3.new(8.6, 8, 8.6),
		box = "DeliveryCrate",
		color = Color3.fromRGB(40, 40, 45),
		description = "A round table, four chairs and a market umbrella.",
	},
	{
		id = "FirePit",
		name = "Fire Pit",
		price = 250,
		appeal = 5,
		size = Vector3.new(4, 1.4, 4),
		box = "DeliveryCrate",
		color = Color3.fromRGB(120, 115, 110),
		description = "A ring of stacked stone with a fire going.",
	},
	{
		id = "Mailbox",
		name = "Mailbox",
		price = 90,
		appeal = 3,
		size = Vector3.new(1.2, 4, 2.2),
		box = "DeliveryBoxLong",
		onLawn = true,
		color = Color3.fromRGB(60, 60, 65),
		description = "A rural mailbox on a wooden post, flag and all.",
	},
	{
		id = "LampPost",
		name = "Lamp Post",
		price = 220,
		appeal = 4,
		size = Vector3.new(1.3, 7.6, 1.3),
		box = "DeliveryBoxLong",
		onLawn = true,
		color = Color3.fromRGB(30, 30, 35),
		description = "A black lamp post with a four-sided lantern that lights up.",
	},
	{
		id = "SolarPathLight",
		name = "Solar Path Light",
		price = 15,
		appeal = 1,
		size = Vector3.new(0.5, 1.4, 0.5),
		box = "DeliveryBoxSmall",
		onLawn = true,
		color = Color3.fromRGB(180, 180, 185),
		description = "A little stake light. Line a path with them.",
	},
	{
		id = "BirdFeeder",
		name = "Bird Feeder",
		price = 40,
		appeal = 2,
		size = Vector3.new(1.6, 7.2, 0.6),
		box = "DeliveryBoxLong",
		onLawn = true,
		color = Color3.fromRGB(150, 110, 70),
		description = "A wooden feeder hanging from a shepherd's hook.",
	},
	{
		id = "Birdhouse",
		name = "Birdhouse",
		price = 45,
		appeal = 2,
		size = Vector3.new(1, 6.4, 1),
		box = "DeliveryBoxLong",
		onLawn = true,
		color = Color3.fromRGB(170, 120, 75),
		description = "A pitched-roof birdhouse on a post.",
	},
	{
		id = "PinkFlamingo",
		name = "Pink Flamingo",
		price = 12,
		appeal = 1,
		size = Vector3.new(1.1, 3, 1.8),
		box = "DeliveryBoxSmall",
		onLawn = true,
		color = Color3.fromRGB(240, 120, 170),
		description = "The classic plastic lawn flamingo. One is charming.",
	},
	{
		id = "GardenWindmill",
		name = "Garden Windmill",
		price = 150,
		appeal = 4,
		size = Vector3.new(2.4, 5.4, 2),
		box = "DeliveryBoxLarge",
		color = Color3.fromRGB(165, 120, 80),
		description = "A wooden windmill whose sails turn in the breeze.",
	},
	{
		id = "GardenGnome",
		name = "Garden Gnome",
		price = 25,
		appeal = 1,
		size = Vector3.new(1, 2, 1),
		box = "DeliveryBoxSmall",
		onLawn = true,
		color = Color3.fromRGB(200, 50, 50),
		description = "A cheerful gnome. Just don't mow him.",
	},
	{
		id = "FlowerPatch",
		name = "Flower Patch",
		price = 30,
		appeal = 2,
		size = Vector3.new(3, 1, 3),
		box = "DeliveryBoxLarge",
		color = Color3.fromRGB(230, 90, 140),
		description = "A patch of bright annuals.",
	},
	-- Won, not sold.
	{
		id = "BestYardTrophy",
		name = "Best Yard Trophy",
		price = 0,
		appeal = 8,
		size = Vector3.new(2.6, 5.4, 2.6),
		box = "DeliveryCrate",
		won = true,
		color = Color3.fromRGB(214, 172, 52),
		description = "The Maple Grove Best Yard trophy, on a white stand with a skirt of real turf. "
			.. "June's 31st. Gloria's name is on it too.",
	},
}

local byId = {}
for index, decoration in Decorations.List do
	decoration.rank = index
	byId[decoration.id] = decoration
end

function Decorations.get(id: unknown)
	return if typeof(id) == "string" then byId[id] else nil
end

return Decorations
