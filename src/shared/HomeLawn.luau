-- Your business's own front lawn and its curb appeal (docs/GAME_DESIGN.md, "Your own lawn"): the
-- rules HomeLawnService, JobService and the HUD share.

local Decorations = require(script.Parent.Config.Decorations)
local GameConfig = require(script.Parent.Config.GameConfig)

local HomeLawn = {}

-- What's on it, besides the grass: the edge along the sidewalk and driveway, a few weeds and the
-- odd pile of leaves. The same task types as customers' lawns, so the same tools fit.
local TASKS = {
	{ type = "MowSmallLawn" },
	{ type = "EdgeSidewalk" },
	{ type = "TrimAroundObstacles", amount = 5 },
	{ type = "RakeLeaves", amount = 3 },
}

-- The lawn to build (see LawnService:Build), this many tiles across and deep.
function HomeLawn.template(columns: number, rows: number)
	return {
		lawn = { columns = columns, rows = rows, flowerPatches = 0 },
		tasks = table.clone(TASKS),
	}
end

-- Which of a task's targets are done, saved as one character each ("1" done, "0" not), in the
-- order the lawn builds them.
function HomeLawn.encode(done: { boolean }): string
	local characters = table.create(#done)
	for index, isDone in done do
		characters[index] = if isDone then "1" else "0"
	end
	return table.concat(characters)
end

-- The other way. Anything that doesn't fit `count` targets (a missing save, or a lawn that's been
-- resized since) is all not done.
function HomeLawn.decode(saved: unknown, count: number): { boolean }
	local done = table.create(count, false)
	if typeof(saved) ~= "string" or #saved ~= count then
		return done
	end
	for index = 1, count do
		done[index] = string.sub(saved, index, index) == "1"
	end
	return done
end

-- Curb appeal, 0-100, from how much of the lawn is done (0-1) and how well it's decorated (0-1).
function HomeLawn.curbAppeal(lawnShare: number, decorShare: number?): number
	local config = GameConfig.CurbAppeal
	local points = math.clamp(lawnShare, 0, 1) * config.LawnPoints
		+ math.clamp(decorShare or 0, 0, 1) * config.DecorPoints
	return math.clamp(math.floor(points + 0.5), 0, 100)
end

-- How well decorated the yard is, 0-1, from what's placed there ({ id, overgrown? } each). Every
-- extra one of a kind is worth less (DecorRepeat), an overgrown shrub counts for less
-- (OvergrownShare), and the total levels off, so a few good pieces beat a yard full of flamingos.
function HomeLawn.decorShare(placed: { { id: string, overgrown: boolean? } }): number
	local config = GameConfig.CurbAppeal
	local byKind = {}
	for _, entry in placed do
		local decoration = Decorations.get(entry.id)
		if decoration then
			byKind[decoration.id] = byKind[decoration.id] or {}
			table.insert(byKind[decoration.id], if entry.overgrown then config.OvergrownShare else 1)
		end
	end
	local points = 0
	for id, shares in byKind do
		-- The tidy ones count first, so it's the overgrown ones that lose out.
		table.sort(shares, function(a, b)
			return a > b
		end)
		local appeal = Decorations.get(id).appeal
		for index, share in shares do
			points += appeal * share * config.DecorRepeat ^ (index - 1)
		end
	end
	return points / (points + config.DecorHalfPoints)
end

-- Job pay multiplier for a crew whose business has this curb appeal.
function HomeLawn.payBonus(curbAppeal: number): number
	return 1 + GameConfig.CurbAppeal.MaxPayBonus * math.clamp(curbAppeal, 0, 100) / 100
end

-- Seconds of play a bit of the lawn stays tidy once it's done, for a random 0-1: between
-- RegrowStart and all of RegrowMinutes, so a tidy lawn grows back a bit at a time. Each bit keeps
-- its own time, so mowing just a strip doesn't make that strip grow back any sooner.
function HomeLawn.staysTidyFor(random: number): number
	local config = GameConfig.HomeLawn
	local start = config.RegrowStart
	return config.RegrowMinutes * 60 * (start + (1 - start) * math.clamp(random, 0, 1))
end

-- Whether tidying the lawn at `now` (os.time) earns the neighbor's tip, given the last one.
function HomeLawn.tipDue(lastTip: number?, now: number): boolean
	return now - (lastTip or 0) >= GameConfig.HomeLawn.TidyTipCooldownMinutes * 60
end

return HomeLawn
