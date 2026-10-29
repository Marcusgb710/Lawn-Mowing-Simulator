-- The goals rail's milestones (docs/superpowers/specs/2026-10-29-busy-season-design.md, 1b): jobs
-- finished, money earned and three-star jobs, each with what reaching it pays and the line the
-- rail shows. `next` picks the ones the rail shows (the nearest to done); `reachedBy` says which a
-- player's numbers have just met. Nothing here saves or pays anything: whoever calls these keeps
-- the reached ids and pays the cash.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

export type Kind = "Jobs" | "Earned" | "Stars"
export type Milestone = { id: string, kind: Kind, at: number, cash: number, text: string }
export type Stats = { jobs: number, earned: number, stars: number }

local Milestones = {}

-- Jobs finished pay `JobCashPer` for each job, never more than `JobCashMax`. Money earned pays
-- nothing (the rail stamps it instead). Three-star jobs pay `StarCashPer` for each. These are the
-- numbers to change when the first hour needs tuning.
local JobsAt = { 1, 3, 5, 10, 25, 50, 100, 250, 500 }
local JobCashPer = 10
local JobCashMax = 2500
local EarnedAt = { 500, 2000, 10000, 50000, 250000 }
local StarsAt = { 1, 5, 25, 100 }
local StarCashPer = 25

-- 2000 -> "$2,000". Format.money does the same, but this file has no requires.
local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

-- Every milestone, in the order the rail's list is read: jobs, then money earned, then stars.
-- The ids are the kind and the number: "Jobs:3", "Earned:2000", "Stars:5".
Milestones.List = {} :: { Milestone }

for _, at in JobsAt do
	local jobs = if at == 1 then "1 job" else `{at} jobs`
	table.insert(Milestones.List, {
		id = `Jobs:{at}`,
		kind = "Jobs",
		at = at,
		cash = math.min(JobCashPer * at, JobCashMax),
		text = `Finish {jobs}`,
	})
end
for _, at in EarnedAt do
	table.insert(Milestones.List, {
		id = `Earned:{at}`,
		kind = "Earned",
		at = at,
		cash = 0,
		text = `Earn {money(at)}`,
	})
end
for _, at in StarsAt do
	local jobs = if at == 1 then "job" else "jobs"
	table.insert(Milestones.List, {
		id = `Stars:{at}`,
		kind = "Stars",
		at = at,
		cash = StarCashPer * at,
		text = `Get {at} three-star {jobs}`,
	})
end

-- How far along a player is toward a milestone of this kind.
local function have(stats: Stats, kind: Kind): number
	if kind == "Jobs" then
		return stats.jobs or 0
	elseif kind == "Earned" then
		return stats.earned or 0
	end
	return stats.stars or 0
end

-- The `count` milestones nearest to done that are not in `reached` ({ [id] = true }), nearest
-- first. Nearness is the share still to go, (at - have) / at, so $400 of $500 beats 2 jobs of 3.
-- One already met but not yet marked reached has nothing to go (not less than nothing), so those
-- tie like any other. A tie keeps the list's order. `List` is never reordered: this sorts its own
-- copy.
function Milestones.next(stats: Stats, reached: { [string]: boolean }, count: number): { Milestone }
	local open = {}
	for index, milestone in Milestones.List do
		if not reached[milestone.id] then
			table.insert(open, {
				index = index,
				togo = math.max(0, (milestone.at - have(stats, milestone.kind)) / milestone.at),
				milestone = milestone,
			})
		end
	end
	table.sort(open, function(a, b)
		if a.togo ~= b.togo then
			return a.togo < b.togo
		end
		return a.index < b.index
	end)
	local nearest = {}
	for place = 1, math.min(count, #open) do
		table.insert(nearest, open[place].milestone)
	end
	return nearest
end

-- Every milestone not in `reached` that these numbers have met, in list order.
function Milestones.reachedBy(stats: Stats, reached: { [string]: boolean }): { Milestone }
	local met = {}
	for _, milestone in Milestones.List do
		if not reached[milestone.id] and have(stats, milestone.kind) >= milestone.at then
			table.insert(met, milestone)
		end
	end
	return met
end

return Milestones
