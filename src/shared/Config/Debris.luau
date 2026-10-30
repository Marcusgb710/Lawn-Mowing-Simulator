-- Junk hidden in the uncut grass (docs/GAME_DESIGN.md, "Junk in the grass"): sticks, a dog's ball,
-- a kid's toy, rocks. Every lawn that needs mowing has some, and players have to spot it and pick
-- it up (look at it and press E, or tap the button) before they cut there:
--   - grass shears and reel mowers can't cut a spot with something in it;
--   - a motorized mower runs right over it and chews it up, which takes a big bite out of its
--     blade's edge (see Maintenance.strike) and stalls the engine for a moment.
-- Whatever's still on the lawn when the job's done, or got chewed up, counts against the finish
-- and the pay (GameConfig.DebrisQualityHit and DebrisPenalty).
--
--   id     its model in Assets/Props (a block placeholder until one exists)
--   name   what players are told it is ("There's a stick in the grass there.")
--   label  its name on the look-at hint
--   odds   how often it turns up, compared to the others
--   wear   blade sharpness (0-1) a motorized mower loses chewing it up
--   hit    what the player's told when their mower chews it up
--   color  the bits that fly out when it does

local Debris = {}

Debris.Kinds = {
	{
		id = "DebrisStick",
		name = "stick",
		label = "Stick",
		odds = 4,
		wear = 0.15,
		hit = "CRACK! The blade chewed up a stick hidden in the grass.",
		color = Color3.fromRGB(110, 80, 50),
	},
	{
		id = "DebrisRock",
		name = "rock",
		label = "Rock",
		odds = 2,
		wear = 0.3,
		hit = "THUNK! The blade hit a rock hidden in the grass.",
		color = Color3.fromRGB(130, 130, 125),
	},
	{
		id = "DebrisDogBall",
		name = "dog's ball",
		label = "Dog's ball",
		odds = 2,
		wear = 0.05,
		hit = "The blade shredded a dog's ball hidden in the grass.",
		color = Color3.fromRGB(200, 230, 60),
	},
	{
		id = "DebrisToyTruck",
		name = "toy truck",
		label = "Toy truck",
		odds = 1,
		wear = 0.15,
		hit = "CRUNCH! The blade smashed a toy truck hidden in the grass.",
		color = Color3.fromRGB(220, 50, 40),
	},
	{
		id = "DebrisFrisbee",
		name = "frisbee",
		label = "Frisbee",
		odds = 1,
		wear = 0.05,
		hit = "The blade chopped up a frisbee hidden in the grass.",
		color = Color3.fromRGB(240, 130, 30),
	},
}

-- How long a motorized mower stalls after it hits something, in seconds.
Debris.StallTime = 1.5

-- How much a customer's lawn hides: one piece per this many lawn tiles (by the job's tier),
-- rounded, at least 1 and at most Max. A job's own `junk` sets it outright (0 for none, which is
-- how the first-timer's strip hides nothing), and so does its lawn's `debris`. Only lawns that
-- need mowing have any.
Debris.TilesPerPiece = { Homeowner = 16, Serious = 14, Pro = 12 }
Debris.Max = 10

-- Your own lawn starts with this many, and each bit of grass that grows back has this chance of
-- something new turning up in it, up to HomeMax at a time.
Debris.Home = 2
Debris.HomeRegrowChance = 0.05
Debris.HomeMax = 3

local byId = {}
local totalOdds = 0
for _, kind in Debris.Kinds do
	assert(not byId[kind.id], "Duplicate debris id " .. kind.id)
	byId[kind.id] = kind
	totalOdds += kind.odds
end

function Debris.get(id: string)
	return byId[id]
end

-- How many pieces hide in a job's lawn.
function Debris.countFor(template): number
	if template.junk then
		return template.junk
	end
	local lawn = template.lawn
	if lawn.debris then
		return lawn.debris
	end
	local perPiece = Debris.TilesPerPiece[template.tier] or Debris.TilesPerPiece.Homeowner
	return math.clamp(math.floor(lawn.columns * lawn.rows / perPiece + 0.5), 1, Debris.Max)
end

-- A kind of junk, by its odds, for a random 0-1 number.
function Debris.pick(random: number)
	local roll = math.clamp(random, 0, 1) * totalOdds
	for _, kind in Debris.Kinds do
		roll -= kind.odds
		if roll < 0 then
			return kind
		end
	end
	return Debris.Kinds[#Debris.Kinds]
end

-- What a player is told when junk in the grass stops their tool: grass shears (a snip), or a mower
-- that won't cut through it.
function Debris.blockedMessage(kind, snip: boolean): string
	if snip then
		return `There's a {kind.name} in the grass there. Pick it up first.`
	end
	return `The mower jams on a {kind.name} hidden in the grass. Pick it up first.`
end

return Debris
