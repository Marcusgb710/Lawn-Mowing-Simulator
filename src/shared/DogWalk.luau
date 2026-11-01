-- Where Buster runs next on a job lawn (CompanionService): a grass cell clear of every player with a
-- motor mower out, by a straight way that never takes him closer to one of them than KEEP_AWAY studs,
-- over ground he may walk on. Only the ground counts (X and Z), never the height.
--
-- It has no requires and touches no Roblox service, so scripts/check-season can load it under Lune.
-- Points are anything with X and Z (a Vector3 does).

export type Point = { X: number, Z: number }
export type Options = {
	-- How close he may come to a mower, in studs.
	keep: number,
	-- How short and how long one run may be, in studs, while he is clear of every mower.
	shortest: number,
	longest: number,
	-- Whether he may stand at a point: the grass, never a flower bed, a tree or a doorway. The way to a
	-- cell is tried every WALK_STEP studs along it. Without it, anywhere goes.
	walkable: ((Point) -> boolean)?,
	-- Caught near a mower, how long his run away may be (studs; no limit without it), and how many of
	-- the nearest cells that will do he picks among (all of them without it).
	escape: number?,
	nearest: number?,
}

local DogWalk = {}

-- Buster never comes within this many studs of a player holding a motor mower (Ruling 12).
DogWalk.KEEP_AWAY = 6

-- How often the way to a cell is tried against `walkable`, in studs.
local WALK_STEP = 1

-- How far `point` is from the way between `from` and `to`, across the ground.
function DogWalk.distanceToSegment(point: Point, from: Point, to: Point): number
	local wayX, wayZ = to.X - from.X, to.Z - from.Z
	local length = wayX * wayX + wayZ * wayZ
	local along = 0
	if length > 0 then
		along = math.clamp(((point.X - from.X) * wayX + (point.Z - from.Z) * wayZ) / length, 0, 1)
	end
	local offX, offZ = point.X - (from.X + wayX * along), point.Z - (from.Z + wayZ * along)
	return math.sqrt(offX * offX + offZ * offZ)
end

local function apart(a: Point, b: Point): number
	local x, z = a.X - b.X, a.Z - b.Z
	return math.sqrt(x * x + z * z)
end

-- Whether `point` is at least `keep` studs from every mower.
function DogWalk.clearOf(point: Point, mowers: { Point }, keep: number): boolean
	for _, mower in mowers do
		if apart(point, mower) < keep then
			return false
		end
	end
	return true
end

-- Whether the way from `from` to `to` keeps `keep` studs from every mower. Where he already stands
-- closer than that, the way only has to take him no closer than he is, so he can always run off.
function DogWalk.pathClear(from: Point, to: Point, mowers: { Point }, keep: number): boolean
	for _, mower in mowers do
		local allowed = math.min(keep, apart(from, mower)) - 1e-6
		if DogWalk.distanceToSegment(mower, from, to) < allowed then
			return false
		end
	end
	return true
end

-- Whether every point along the way, every WALK_STEP studs and its end, is ground he may walk on.
function DogWalk.walkableWay(from: Point, to: Point, walkable: (Point) -> boolean): boolean
	local length = apart(from, to)
	local steps = math.max(1, math.ceil(length / WALK_STEP))
	for step = 1, steps do
		local along = step / steps
		local point = { X = from.X + (to.X - from.X) * along, Z = from.Z + (to.Z - from.Z) * along }
		if not walkable(point) then
			return false
		end
	end
	return true
end

-- One of `cells` for Buster at `from` to run to, chosen by `random01` (a number from 0 up to 1), or
-- nil when none will do and he should stay where he is. A cell will do when it is clear of every mower
-- and the way there is clear too (pathClear) and walkable. While he is clear of the mowers it is also
-- `shortest` to `longest` studs away, a short run. Caught near one, it may be any distance up to
-- `escape`, and he takes one of the `nearest` such cells, so he gets away without running off far.
function DogWalk.pick<T>(cells: { T }, from: Point, mowers: { Point }, options: Options, random01: () -> number): T?
	local caught = not DogWalk.clearOf(from, mowers, options.keep)
	local escape = options.escape or math.huge
	local fits = {}
	local lengths = {}
	for _, cell in cells do
		local point = cell :: any
		local length = apart(from, point)
		local inRange = if caught then length <= escape else length >= options.shortest and length <= options.longest
		if
			inRange
			and DogWalk.clearOf(point, mowers, options.keep)
			and DogWalk.pathClear(from, point, mowers, options.keep)
			and (options.walkable == nil or DogWalk.walkableWay(from, point, options.walkable))
		then
			table.insert(fits, cell)
			lengths[cell] = length
		end
	end
	if caught and options.nearest and #fits > options.nearest then
		table.sort(fits, function(a, b)
			return lengths[a] < lengths[b]
		end)
		for index = #fits, options.nearest + 1, -1 do
			fits[index] = nil
		end
	end
	if #fits == 0 then
		return nil
	end
	return fits[math.clamp(math.floor(random01() * #fits) + 1, 1, #fits)]
end

-- A way to the Find that wasn't clear, or a trot there a mower cut short with the Find still on the
-- lawn: one more try spent. Returns the tries spent now and whether he gives up on it for this job
-- (after `most` of them).
function DogWalk.findRetry(tries: number, most: number): (number, boolean)
	local spent = tries + 1
	return spent, spent >= most
end

return DogWalk
