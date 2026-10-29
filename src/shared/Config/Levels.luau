-- What each level pays (docs/superpowers/specs/2026-10-29-busy-season-design.md, 1c): cash, a
-- truck paint tint, the gold business sign, a HUD stamp, and the line that names it for the moment
-- card and the Levels panel. The table below is the single source: the screens and
-- scripts/check-season.luau all read it. Level 1 pays nothing; level 2 to 20 are listed;
-- past 20 every level pays `PastTwentyCash`, and every fifth pays `EveryFifthCash` and a stamp.
-- Nothing here pays anything: whoever calls these keeps which levels were claimed.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

export type Reward = { cash: number, paint: string?, sign: boolean?, stamp: boolean?, text: string }
export type Upcoming = { level: number, reward: Reward }

local Levels = {}

local PastTwentyCash = 3000
local EveryFifthCash = 5000

-- The four truck paint tints earned in order, and what the text calls them. The paint names are
-- the shop's (Config/Premium.luau).
local PaintNames = {
	RacingRed = "Racing Red",
	ForestGreen = "Forest Green",
	SkyBlue = "Sky Blue",
	MidnightBlack = "Midnight Black",
}

-- Levels 2 to 20. `cash` is always there (0 when a level pays none); the rest only where it's
-- earned. Levels 3, 8 and 10 also open serious jobs, pro jobs and the Best Yard contest, but
-- those come from their own gates, not from here.
local Listed: { [number]: { cash: number, paint: string?, sign: boolean? } } = {
	[2] = { cash = 100 },
	[3] = { cash = 0, paint = "RacingRed" },
	[4] = { cash = 250 },
	[5] = { cash = 500 },
	[6] = { cash = 400, paint = "ForestGreen" },
	[7] = { cash = 600 },
	[8] = { cash = 800 },
	[9] = { cash = 800, paint = "SkyBlue" },
	[10] = { cash = 1500 },
	[11] = { cash = 800 },
	[12] = { cash = 1000, paint = "MidnightBlack" },
	[13] = { cash = 1000 },
	[14] = { cash = 2500 },
	[15] = { cash = 1500 },
	[16] = { cash = 3000 },
	[17] = { cash = 2000 },
	[18] = { cash = 5000 },
	[19] = { cash = 3000 },
	[20] = { cash = 5000, sign = true },
}

-- 2000 -> "$2,000". Format.money does the same, but this file has no requires.
local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

-- A reward with the line that names it: "$250", "Forest Green tint and $400",
-- "A gold business sign and $5,000", "$5,000 and a HUD stamp".
local function reward(cash: number, paint: string?, sign: boolean?, stamp: boolean?): Reward
	local parts = {}
	if paint then
		table.insert(parts, `{PaintNames[paint]} tint`)
	end
	if sign then
		table.insert(parts, "a gold business sign")
	end
	if cash > 0 then
		table.insert(parts, money(cash))
	end
	if stamp then
		table.insert(parts, "a HUD stamp")
	end
	local text = table.concat(parts, " and ")
	return {
		cash = cash,
		paint = paint,
		sign = sign,
		stamp = stamp,
		text = text:sub(1, 1):upper() .. text:sub(2),
	}
end

-- Built once, when the file loads.
local rewards: { [number]: Reward } = {}
local lastListed = 1
for level, spec in Listed do
	rewards[level] = reward(spec.cash, spec.paint, spec.sign)
	lastListed = math.max(lastListed, level)
end
local pastTwenty = reward(PastTwentyCash)
local everyFifth = reward(EveryFifthCash, nil, nil, true)

-- What reaching `level` pays, or nil for level 1 (and below, which no one is).
function Levels.rewardFor(level: number): Reward?
	if level < 2 or level % 1 ~= 0 then
		return nil
	elseif level <= lastListed then
		return rewards[level]
	end
	return if level % 5 == 0 then everyFifth else pastTwenty
end

-- The next `count` levels above `level`, each with its reward, for the Levels panel.
function Levels.nextRewards(level: number, count: number): { Upcoming }
	local upcoming = {}
	local at = math.max(math.floor(level), 0)
	while #upcoming < count do
		at += 1
		local found = Levels.rewardFor(at)
		if found then
			table.insert(upcoming, { level = at, reward = found })
		end
	end
	return upcoming
end

return Levels
