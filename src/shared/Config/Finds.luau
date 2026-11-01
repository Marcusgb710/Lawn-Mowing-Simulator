-- The Finds (docs/superpowers/specs/2026-10-29-busy-season-design.md, "Slice 3: Finds"): thirty things
-- a lawn can hide that are worth picking up, in four rarities and five sets. This file holds the list,
-- what each rarity is worth, the sets and their small permanent perks, and the roll that decides
-- whether a job lawn hides a Find and which. It also cleans the four save keys Finds adds (`finds`,
-- `sets`, `buster` and `findLuck`), so a save from before Finds, or a scrambled one, always loads.
-- Nothing here keeps state or reads the clock or the game: whoever calls these places the Find,
-- saves the counts and pays the cash.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it and the server
-- can clean a save without pulling anything else in. Colours are plain { r, g, b } arrays (0 to 255)
-- for the same reason: the code that builds a Color3 from one lives where Color3 does.

export type Color = { number }
export type Find = { id: string, name: string, story: string, rarity: string, color: Color }
export type Rarity = { weight: number, value: number, frame: Color }
export type Perk = { kind: string, amount: number }
export type Set = { id: string, name: string, members: { string }, perk: Perk, text: string }
-- How many of a Find the player has ever found, and how many they still hold (a sold or returned
-- one still counts as found, so the book and the sets keep it).
export type Entry = { found: number, held: number }
-- What the roll may be nudged by: three-star jobs in a row, Buster, and a sure Find after a Bonus Day.
export type Bonuses = { run: number?, buster: boolean?, owed: boolean? }

-- A small LCG (the Numerical Recipes one, as in Contracts.randoms, copied here because this file has
-- no requires) so a seed picks the same Find on every server and every run. The modulus is 2^32, so
-- state * multiplier stays under 2^53 and the maths stays exact.
local LCG_MULTIPLIER = 1664525
local LCG_INCREMENT = 1013904223
local LCG_MODULUS = 4294967296

-- A seed is a whole number below 2^31. A day key is a number like 20261101, so it is spread by a
-- prime before the player's id and the job are added, which keeps nearby days, players and jobs apart.
local SEED_MODULUS = 2147483648
local DAY_PRIME = 7919
local USER_PRIME = 31
local JOB_PRIME = 104729

-- Three-star jobs in a row add this much to the chance each, up to RUN_CAP of them; Buster adds more.
local RUN_STEP = 0.05
local RUN_CAP = 3
local BUSTER_STEP = 0.10

-- A count in a save is held below this, so a scrambled one cannot grow without end.
local MAX_COUNT = 999999999
-- Buster's name: 20 characters at most, Buster if it is missing or empty.
local NAME_LENGTH = 20
local DEFAULT_NAME = "Buster"

local Finds = {}

-- The rarities, rarest last. `weight` is the share out of 100 of a roll that lands there, `value` what a
-- Find sells for, and `frame` the colour of its frame and text in the cards and the book.
Finds.RarityOrder = { "Common", "Uncommon", "Rare", "Legendary" }
Finds.Rarities = {
	Common = { weight = 70, value = 10, frame = { 185, 194, 187 } },
	Uncommon = { weight = 22, value = 40, frame = { 105, 226, 90 } },
	Rare = { weight = 7, value = 200, frame = { 61, 155, 232 } },
	Legendary = { weight = 1, value = 1000, frame = { 255, 210, 74 } },
}

-- The chance a job lawn hides a Find, by the job's tier (Jobs.luau's tier names). A tier that is not
-- here has the Homeowner chance.
Finds.TierChance = { Homeowner = 0.35, Serious = 0.50, Pro = 0.65 }

-- The thirty, in this order: Common, Uncommon, Rare, Legendary. `color` is the placeholder block's
-- colour until the models land.
Finds.List = {
	-- Common
	{
		id = "BottleCap",
		name = "Bottle Cap",
		story = "A soda cap from some long-ago cookout on Maple Grove.",
		rarity = "Common",
		color = { 196, 60, 52 },
	},
	{
		id = "TennisBall",
		name = "Lost Tennis Ball",
		story = "Chewed, faded and still the best thing in the yard to somebody's dog.",
		rarity = "Common",
		color = { 206, 224, 74 },
	},
	{
		id = "SprinklerHead",
		name = "Broken Sprinkler Head",
		story = "It stopped turning years ago, and the brown patch it left is still there.",
		rarity = "Common",
		color = { 70, 70, 76 },
	},
	{
		id = "OldKey",
		name = "Old Key",
		story = "It fits no lock on the street, which makes it more interesting.",
		rarity = "Common",
		color = { 176, 140, 66 },
	},
	{
		id = "DogTag",
		name = "Dog Tag",
		story = "The name has worn off, but whoever wore it was loved.",
		rarity = "Common",
		color = { 190, 196, 204 },
	},
	{
		id = "Marble",
		name = "Marble",
		story = "A swirl of green glass that rolled away from a kid on a summer day.",
		rarity = "Common",
		color = { 66, 170, 120 },
	},
	{
		id = "GolfBall",
		name = "Golf Ball",
		story = "A slice from somebody's backyard putting green, lost ever since.",
		rarity = "Common",
		color = { 240, 240, 236 },
	},
	{
		id = "ToySoldier",
		name = "Toy Soldier",
		story = "He has stood guard in the grass since before the hedge was planted.",
		rarity = "Common",
		color = { 92, 120, 64 },
	},
	{
		id = "Seashell",
		name = "Seashell",
		story = "Somebody brought the beach home, and the lawn kept a piece of it.",
		rarity = "Common",
		color = { 240, 214, 196 },
	},
	{
		id = "BirthdayCandle",
		name = "Birthday Candle",
		story = "Blown out and tossed from the party, and the wish may still come true.",
		rarity = "Common",
		color = { 238, 120, 170 },
	},
	{
		id = "Screwdriver",
		name = "Screwdriver",
		story = "A good Phillips head, left out by a weekend project that never got finished.",
		rarity = "Common",
		color = { 210, 150, 50 },
	},
	{
		id = "BentSpoon",
		name = "Bent Spoon",
		story = "It was the digging spoon in a kid's mud kitchen, and a serious one.",
		rarity = "Common",
		color = { 200, 204, 210 },
	},
	-- Uncommon
	{
		id = "ClassRing",
		name = "Class Ring",
		story = "Maple Grove High, class of 1987, a little green around the stone.",
		rarity = "Uncommon",
		color = { 70, 110, 200 },
	},
	{
		id = "PocketKnife",
		name = "Pocket Knife",
		story = "The initials on the handle belong to somebody's grandfather.",
		rarity = "Uncommon",
		color = { 180, 52, 44 },
	},
	{
		id = "OldPhone",
		name = "Old Phone",
		story = "A flip phone from the days of ringtones, still hoping somebody will call.",
		rarity = "Uncommon",
		color = { 100, 108, 120 },
	},
	{
		id = "Arrowhead",
		name = "Arrowhead",
		story = "Chipped from flint a very long time before Maple Grove had a name.",
		rarity = "Uncommon",
		color = { 150, 136, 120 },
	},
	{
		id = "Horseshoe",
		name = "Lucky Horseshoe",
		story = "It hung over a barn door once, and the luck seems mostly intact.",
		rarity = "Uncommon",
		color = { 128, 112, 100 },
	},
	{
		id = "Cassette",
		name = "1980s Cassette",
		story = "A mixtape, handwritten label and all, that somebody made for somebody else.",
		rarity = "Uncommon",
		color = { 60, 64, 90 },
	},
	{
		id = "WeddingBand",
		name = "Wedding Band",
		story = "Somebody is missing this, and they would pay a lot to have it back.",
		rarity = "Uncommon",
		color = { 236, 196, 80 },
	},
	{
		id = "CoinJar",
		name = "Jar of Coins",
		story = "A kid's savings, buried for safekeeping and never dug up.",
		rarity = "Uncommon",
		color = { 150, 190, 180 },
	},
	{
		id = "Lighter",
		name = "Vintage Lighter",
		story = "Brass, engraved and good for one more spark.",
		rarity = "Uncommon",
		color = { 196, 160, 70 },
	},
	{
		id = "Compass",
		name = "Compass",
		story = "The needle still points north, whichever way the mower is headed.",
		rarity = "Uncommon",
		color = { 150, 120, 60 },
	},
	-- Rare
	{
		id = "SilverDollar",
		name = "Silver Dollar",
		story = "Heavy, bright and worth far more than a dollar to the right collector.",
		rarity = "Rare",
		color = { 220, 224, 230 },
	},
	{
		id = "FossilShell",
		name = "Fossil Shell",
		story = "A shell turned to stone, millions of years older than the lawn.",
		rarity = "Rare",
		color = { 160, 148, 124 },
	},
	{
		id = "MeteoriteChip",
		name = "Meteorite Chip",
		story = "It fell from the sky once and landed in somebody's tomato patch.",
		rarity = "Rare",
		color = { 56, 56, 64 },
	},
	{
		id = "AntiqueWatch",
		name = "Antique Watch",
		story = "It stopped at ten past three, and nobody remembers why.",
		rarity = "Rare",
		color = { 214, 186, 110 },
	},
	{
		id = "BottleMessage",
		name = "Message in a Bottle",
		story = "The note inside is signed by a kid who was hoping for a friend.",
		rarity = "Rare",
		color = { 110, 180, 170 },
	},
	{
		id = "BestYardMedal",
		name = "1994 Best Yard Medal",
		story = "Grandma June's medal from the Best Yard contest, still shining.",
		rarity = "Rare",
		color = { 232, 188, 60 },
	},
	-- Legendary
	{
		id = "GoldenGnome",
		name = "Golden Gnome",
		story = "Every old street has a legend, and Maple Grove's wears a pointed gold hat.",
		rarity = "Legendary",
		color = { 255, 200, 60 },
	},
	{
		id = "JuneLocket",
		name = "Grandma June's Locket",
		story = "It went missing the summer she won Best Yard, and the street has wondered ever since.",
		rarity = "Legendary",
		color = { 255, 214, 120 },
	},
}

-- The sets, each done when every member has been found once (found, then kept, sold or returned).
-- A perk's `kind` says what it changes and `amount` by how much:
--   Reach          studs added to the pick-up reach
--   Pay            a share added to the pay multiplier (0.03 is 3 percent)
--   FlowerPenalty  what share of the flower-bed damage penalty is left (0.5 is half)
--   GoldSign       the gold business sign comes early (1 is on)
Finds.Sets = {
	{
		id = "Playground",
		name = "Playground",
		members = { "TennisBall", "Marble", "GolfBall", "ToySoldier", "BirthdayCandle", "Cassette" },
		perk = { kind = "Reach", amount = 2 },
		text = "Pick-up reach +2 studs",
	},
	{
		id = "Pocket",
		name = "Pocket",
		members = { "BottleCap", "OldKey", "DogTag", "BentSpoon", "Screwdriver", "PocketKnife", "OldPhone", "Lighter" },
		perk = { kind = "Pay", amount = 0.03 },
		text = "Pay +3 percent",
	},
	{
		id = "Garden",
		name = "Garden",
		members = { "SprinklerHead", "Seashell", "Arrowhead", "Horseshoe", "Compass", "FossilShell" },
		perk = { kind = "FlowerPenalty", amount = 0.5 },
		text = "Flower bed damage costs half",
	},
	{
		id = "Treasure",
		name = "Treasure",
		members = {
			"ClassRing",
			"WeddingBand",
			"CoinJar",
			"SilverDollar",
			"MeteoriteChip",
			"AntiqueWatch",
			"BottleMessage",
		},
		perk = { kind = "Pay", amount = 0.05 },
		text = "Pay +5 percent",
	},
	{
		id = "MapleGrove",
		name = "Maple Grove",
		members = { "BestYardMedal", "GoldenGnome", "JuneLocket" },
		perk = { kind = "GoldSign", amount = 1 },
		text = "The gold business sign, early",
	},
}

local byId: { [string]: Find } = {}
local byRarity: { [string]: { string } } = {}
local rankOf: { [string]: number } = {}
for rank, name in Finds.RarityOrder do
	rankOf[name] = rank
	byRarity[name] = {}
end
for _, find in Finds.List do
	byId[find.id] = find
	table.insert(byRarity[find.rarity], find.id)
end

-- The Find with this id, or nil for anything that is not one.
function Finds.get(id: string): Find?
	if typeof(id) ~= "string" then
		return nil
	end
	return byId[id]
end

-- Gives the next number from 0 up to (not including) 1 each time it's called.
local function randoms(seed: number): () -> number
	local state = math.floor(seed) % LCG_MODULUS
	local function step(): number
		state = (state * LCG_MULTIPLIER + LCG_INCREMENT) % LCG_MODULUS
		return state / LCG_MODULUS
	end
	-- Seeds next to each other (one per job, say) start out alike, so let it run a little first.
	step()
	step()
	return step
end

-- A whole number from 0 up from anything: a count that is not a number, is NaN or is negative is 0, a
-- fraction is floored, and nothing goes past MAX_COUNT.
local function whole(value: any): number
	if typeof(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	return math.min(math.floor(value), MAX_COUNT)
end

-- The seed for one job lawn: a whole number from 0 up, the same every time for the same `dayKey`
-- ("20261101", from Daily.dayKey), `userId` and `jobIndex` (which job of the day this is). A day key
-- that is not a number counts as 0.
function Finds.seed(dayKey: string, userId: number, jobIndex: number): number
	local day = whole(tonumber(dayKey))
	-- A user id is far past the count cap (most are over a billion), so it has its own handling: a
	-- positive, finite number is floored and taken modulo the seed modulus, anything else is 0.
	local user = 0
	if typeof(userId) == "number" and userId > 0 and userId < math.huge then
		user = math.floor(userId) % SEED_MODULUS
	end
	local base = (day * DAY_PRIME + user) % SEED_MODULUS
	return (base * USER_PRIME + whole(jobIndex) * JOB_PRIME) % SEED_MODULUS
end

-- Which rarity a roll from 0 up to 1 lands in, by the weights.
local function rarityFor(roll: number): string
	local total = 0
	for _, name in Finds.RarityOrder do
		total += Finds.Rarities[name].weight
	end
	local target = roll * total
	local passed = 0
	for _, name in Finds.RarityOrder do
		passed += Finds.Rarities[name].weight
		if target < passed then
			return name
		end
	end
	return Finds.RarityOrder[#Finds.RarityOrder]
end

-- The Find this lawn hides, or nil for none. `tier` is the job's tier ("Homeowner", "Serious" or
-- "Pro"; any other has the Homeowner chance). `bonuses.run` is the three-star jobs in a row (5 points
-- each, up to 3), `bonuses.buster` adds 10 points and rerolls a Common once, keeping the rarer of the
-- two, and `bonuses.owed` makes it a sure Find whatever the chance. The same seed, tier and bonuses
-- always give the same answer.
function Finds.roll(seed: number, tier: string, bonuses: Bonuses?): string?
	local given = if typeof(bonuses) == "table" then bonuses else {}
	local random = randoms(seed)
	local chance = Finds.TierChance[tier] or Finds.TierChance.Homeowner
	chance += RUN_STEP * math.min(whole(given.run), RUN_CAP)
	if given.buster == true then
		chance += BUSTER_STEP
	end
	-- Every draw is taken in the same order whatever the answer, so a bonus changes a lawn's Find only
	-- through the chance and the reroll, never by shifting what the draws mean.
	local gate = random()
	local first = rarityFor(random())
	local second = rarityFor(random())
	local pick = random()
	if given.owed ~= true and gate >= math.min(chance, 1) then
		return nil
	end
	local rarity = first
	if given.buster == true and first == "Common" and rankOf[second] > rankOf[first] then
		rarity = second
	end
	local ids = byRarity[rarity]
	return ids[math.floor(pick * #ids) + 1]
end

-- Whether every member of a set has been found at least once, by the save's `finds`.
local function isComplete(finds: any, set: Set): boolean
	if typeof(finds) ~= "table" then
		return false
	end
	for _, member in set.members do
		local entry = finds[member]
		if typeof(entry) ~= "table" or whole(entry.found) < 1 then
			return false
		end
	end
	return true
end

-- The sets that are complete by `finds` and not yet marked in `sets` (a map of set id to true), in the
-- sets' order. A set the player completes shows up here once: they mark it, and it is never new again.
function Finds.newlyComplete(finds: any, sets: any): { string }
	local marked = if typeof(sets) == "table" then sets else {}
	local ids = {}
	for _, set in Finds.Sets do
		if marked[set.id] ~= true and isComplete(finds, set) then
			table.insert(ids, set.id)
		end
	end
	return ids
end

-- The sum of one kind of perk over the sets in `sets` (a map of set id to true), to the thousandth so
-- 0.03 and 0.05 add to 0.08 exactly.
local function perkTotal(sets: any, kind: string): number
	local total = 0
	if typeof(sets) == "table" then
		for _, set in Finds.Sets do
			if sets[set.id] == true and set.perk.kind == kind then
				total += set.perk.amount
			end
		end
	end
	return math.floor(total * 1000 + 0.5) / 1000
end

-- The pay multiplier the completed sets give: 1 with none, 1.03 with Pocket, 1.08 with Pocket and
-- Treasure.
function Finds.payBonus(sets: any): number
	return 1 + perkTotal(sets, "Pay")
end

-- The studs the completed sets add to the pick-up reach (0 with none).
function Finds.reachBonus(sets: any): number
	return perkTotal(sets, "Reach")
end

-- What share of the flower-bed damage penalty is left: 1 normally, 0.5 with the Garden set.
function Finds.flowerFactor(sets: any): number
	if typeof(sets) == "table" then
		for _, set in Finds.Sets do
			if sets[set.id] == true and set.perk.kind == "FlowerPenalty" then
				return set.perk.amount
			end
		end
	end
	return 1
end

-- The ids of the Finds the player holds (`held` above 0), at most `count`, rarest first and then in the
-- list's order: what the shelf shows.
function Finds.rarest(finds: any, count: number): { string }
	local ids = {}
	if typeof(finds) ~= "table" then
		return ids
	end
	-- A count that is not a number (or is NaN) asks for none.
	if typeof(count) ~= "number" or count ~= count then
		count = 0
	end
	for rank = #Finds.RarityOrder, 1, -1 do
		for _, id in byRarity[Finds.RarityOrder[rank]] do
			local entry = finds[id]
			if #ids >= count then
				return ids
			end
			if typeof(entry) == "table" and whole(entry.held) > 0 then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

-- The words for a card or a toast when a Find is picked up: "Rare find: Silver Dollar" and its story.
-- An id that is not a Find has none.
function Finds.cardText(id: string): (string, string)
	local find = Finds.get(id)
	if find == nil then
		return "", ""
	end
	return `{find.rarity} find: {find.name}`, find.story
end

-- The `finds` key: a new map with only the thirty known ids, each with whole counts and held no more
-- than found. A Find with nothing found is left out.
local function cleanFinds(source: any): { [string]: Entry }
	local cleaned = {}
	if typeof(source) ~= "table" then
		return cleaned
	end
	for _, find in Finds.List do
		local entry = rawget(source, find.id)
		if typeof(entry) == "table" then
			local found = whole(rawget(entry, "found"))
			if found > 0 then
				cleaned[find.id] = { found = found, held = math.min(whole(rawget(entry, "held")), found) }
			end
		end
	end
	return cleaned
end

-- The `sets` key: every set that is in fact complete by `finds`, and no other. What the save said is
-- not trusted either way, so a missing one is added and a false one dropped.
local function cleanSets(finds: { [string]: Entry }): { [string]: boolean }
	local cleaned = {}
	for _, set in Finds.Sets do
		if isComplete(finds, set) then
			cleaned[set.id] = true
		end
	end
	return cleaned
end

-- Buster's name: no control characters, trimmed, at most NAME_LENGTH characters (cut between
-- characters, never inside one), and Buster for anything that is not text or comes out empty.
local function cleanName(value: any): string
	if typeof(value) ~= "string" then
		return DEFAULT_NAME
	end
	local text = string.gsub(value, "%c", "")
	text = string.match(text, "^%s*(.-)%s*$") or ""
	local length = utf8.len(text)
	if length == nil then
		return DEFAULT_NAME
	end
	if length > NAME_LENGTH then
		text = string.sub(text, 1, (utf8.offset(text, NAME_LENGTH + 1) or (#text + 1)) - 1)
		text = string.match(text, "^(.-)%s*$") or ""
	end
	return if text == "" then DEFAULT_NAME else text
end

-- The `buster` key: { owned, name }.
local function cleanBuster(source: any): { owned: boolean, name: string }
	local given = if typeof(source) == "table" then source else {}
	return { owned = rawget(given, "owned") == true, name = cleanName(rawget(given, "name")) }
end

-- The `findLuck` key: { run, owed }, the three-star jobs in a row (0 to 3) and whether a sure Find is
-- owed on the next job.
local function cleanLuck(source: any): { run: number, owed: boolean }
	local given = if typeof(source) == "table" then source else {}
	return { run = math.min(whole(rawget(given, "run")), RUN_CAP), owed = rawget(given, "owed") == true }
end

-- Fills and cleans the four keys Finds adds to a save, in the table it is given, and gives that table
-- back (nil, or anything that is not a table, gives a new one). An old save gets the defaults, and a
-- scrambled one keeps what is good in it. Running it again changes nothing.
function Finds.cleanSave(data: any): any
	local save = if typeof(data) == "table" then data else {}
	save.finds = cleanFinds(save.finds)
	save.sets = cleanSets(save.finds)
	save.buster = cleanBuster(save.buster)
	save.findLuck = cleanLuck(save.findLuck)
	return save
end

return Finds
