-- The day's contracts (docs/superpowers/specs/2026-10-29-busy-season-design.md): three small jobs
-- to do before midnight UTC, always one Mow, one Earn and one more that is Junk or Stars. How much
-- each asks for, and what it pays, depends on the player's level band, so a new player is asked for
-- 2 lawns and a veteran for 5. `seed` turns a day and a player into one number, and `generate`
-- builds the list from it, so the same player on the same day always gets the same list and
-- another day or player gets another. `have` says how far along a contract is. Nothing here keeps
-- state or reads the clock: whoever calls these saves the list and its counts, and pays the cash.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

export type Kind = "Mow" | "Earn" | "Junk" | "Stars"
export type Contract = { id: string, kind: Kind, need: number, reward: number, text: string }
-- What a day has counted so far. A counter that is not there counts as 0.
export type Count = { jobs: number?, earned: number?, junk: number?, stars: number? }

-- A small LCG (the Numerical Recipes one, as in GrassImages.randoms, copied here because this file
-- has no requires) so a seed picks the same contracts on every server and every run. The modulus is
-- 2^32, so state * multiplier stays under 2^53 and the maths stays exact.
local LCG_MULTIPLIER = 1664525
local LCG_INCREMENT = 1013904223
local LCG_MODULUS = 4294967296

-- A seed is a whole number below 2^31. A day key is a number like 20261029, so it is spread by a
-- prime before the player's id is added, which keeps nearby days and nearby players apart.
local SEED_MODULUS = 2147483648
local DAY_PRIME = 7919

-- The counter in `daily.count` that each kind of contract reads.
local COUNTER = { Mow = "jobs", Earn = "earned", Junk = "junk", Stars = "stars" }

local Contracts = {}

-- The level bands, in order. A level in no band is held to the nearest one (below 1 is band 1, above
-- 999 is band 4).
Contracts.Bands = { { min = 1, max = 2 }, { min = 3, max = 7 }, { min = 8, max = 11 }, { min = 12, max = 999 } }

-- What each kind asks for, one number for each band. Mow is lawns finished, Earn is dollars earned,
-- Junk is pieces picked up, Stars is three-star jobs. These and the rewards are the numbers to change
-- when the daily contracts need tuning.
Contracts.Need = {
	Mow = { 2, 3, 4, 5 },
	Earn = { 150, 400, 1200, 3000 },
	Junk = { 3, 4, 6, 8 },
	Stars = { 1, 1, 2, 2 },
}

-- What each contract pays when it is done, one number for each band, and what finishing all three
-- in a day pays on top (the Bonus Day).
Contracts.Reward = { 60, 150, 400, 900 }
Contracts.BonusCash = 500

-- 1200 -> "$1,200". Format.money does the same, but this file has no requires.
local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

-- Gives the next number from 0 up to (not including) 1 each time it's called.
local function randoms(seed: number): () -> number
	local state = math.floor(seed) % LCG_MODULUS
	local function step(): number
		state = (state * LCG_MULTIPLIER + LCG_INCREMENT) % LCG_MODULUS
		return state / LCG_MODULUS
	end
	-- Seeds next to each other (one per player, say) start out alike, so let it run a little first.
	step()
	step()
	return step
end

-- The line the contract list shows: "Mow 3 lawns", "Earn $400", "Pick up 4 pieces of junk", "Get a
-- three-star job" (or "Get 2 three-star jobs").
local function textFor(kind: Kind, need: number): string
	if kind == "Mow" then
		local lawns = if need == 1 then "lawn" else "lawns"
		return `Mow {need} {lawns}`
	elseif kind == "Earn" then
		return `Earn {money(need)}`
	elseif kind == "Junk" then
		local pieces = if need == 1 then "piece" else "pieces"
		return `Pick up {need} {pieces} of junk`
	end
	return if need == 1 then "Get a three-star job" else `Get {need} three-star jobs`
end

-- One contract of this kind for this band. The id is the kind: a day has at most one of each.
local function make(kind: Kind, band: number): Contract
	local need = Contracts.Need[kind][band]
	return { id = kind, kind = kind, need = need, reward = Contracts.Reward[band], text = textFor(kind, need) }
end

-- Which band (1 to 4) a level is in.
function Contracts.bandFor(level: number): number
	for index, band in Contracts.Bands do
		if level <= band.max then
			return index
		end
	end
	return #Contracts.Bands
end

-- The seed for this player on this day: a whole number from 0 up, the same every time for the same
-- `dayKey` ("20261029", from Daily.dayKey) and `userId`. A day key that is not a number counts as 0.
function Contracts.seed(dayKey: string, userId: number): number
	return ((tonumber(dayKey) or 0) * DAY_PRIME + userId) % SEED_MODULUS
end

-- The day's contracts for a player at `level`: a Mow, an Earn and then a Junk or a Stars, which the
-- seed picks. The same seed and level always give the same list, and each call makes new tables, so
-- the caller can save and change them.
function Contracts.generate(seed: number, level: number): { Contract }
	local band = Contracts.bandFor(level)
	local random = randoms(seed)
	local flavour: Kind = if random() < 0.5 then "Junk" else "Stars"
	return { make("Mow", band), make("Earn", band), make(flavour, band) }
end

-- How far along a contract is, 0 up to its need and no further, from the counter of its own kind in
-- `count` (a day's `daily.count`).
function Contracts.have(contract: { kind: Kind, need: number }, count: Count): number
	return math.min(contract.need, count[COUNTER[contract.kind]] or 0)
end

return Contracts
