-- Where a decoration may go on a business plot (docs/GAME_DESIGN.md, "Decorations"). Everything
-- here is in plot space: X across the plot, Z from the street (-Z) to the back, turns about +Y
-- the way CFrame.Angles(0, turn, 0) turns. The server checks every placement with it, and the
-- client uses it to colour the ghost.

local DecorPlacement = {}

-- A rectangle on the ground: its centre, how far it's turned, and its full size along its own X
-- (width) and Z (depth).
export type Rect = { x: number, z: number, turn: number, width: number, depth: number }

-- How far inside the plot's edge a decoration has to stay.
DecorPlacement.EdgeMargin = 0.5
-- Edges that only touch (fence sections end to end) don't count as overlapping.
local TOUCH = 0.05

-- Where local (x, z) ends up after turning by `turn`.
local function turned(x: number, z: number, turn: number): (number, number)
	local c, s = math.cos(turn), math.sin(turn)
	return x * c + z * s, -x * s + z * c
end

-- The four corners of a rectangle.
function DecorPlacement.corners(rect: Rect): { { number } }
	local corners = {}
	for _, sign in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local dx, dz = turned(sign[1] * rect.width / 2, sign[2] * rect.depth / 2, rect.turn)
		table.insert(corners, { rect.x + dx, rect.z + dz })
	end
	return corners
end

-- The footprint of something whose box (at no turn) is centred at (offsetX, offsetZ) from its
-- origin and is width x depth, with its origin at (x, z) turned by `turn`.
function DecorPlacement.footprint(
	x: number,
	z: number,
	turn: number,
	offsetX: number,
	offsetZ: number,
	width: number,
	depth: number
): Rect
	local dx, dz = turned(offsetX, offsetZ, turn)
	return { x = x + dx, z = z + dz, turn = turn, width = width, depth = depth }
end

-- Whether two rectangles overlap (more than just touching), by separating axes.
function DecorPlacement.overlaps(a: Rect, b: Rect): boolean
	local cornersA, cornersB = DecorPlacement.corners(a), DecorPlacement.corners(b)
	for _, rect in { a, b } do
		for _, axisTurn in { 0, math.pi / 2 } do
			local ax, az = turned(1, 0, rect.turn + axisTurn)
			local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
			for _, corner in cornersA do
				local along = corner[1] * ax + corner[2] * az
				minA, maxA = math.min(minA, along), math.max(maxA, along)
			end
			for _, corner in cornersB do
				local along = corner[1] * ax + corner[2] * az
				minB, maxB = math.min(minB, along), math.max(maxB, along)
			end
			if maxA <= minB + TOUCH or maxB <= minA + TOUCH then
				return false
			end
		end
	end
	return true
end

-- Whether a rectangle lies inside a plot this wide and deep (centred on the plot's origin).
function DecorPlacement.inside(rect: Rect, plotWidth: number, plotDepth: number): boolean
	local halfWidth = plotWidth / 2 - DecorPlacement.EdgeMargin
	local halfDepth = plotDepth / 2 - DecorPlacement.EdgeMargin
	for _, corner in DecorPlacement.corners(rect) do
		if math.abs(corner[1]) > halfWidth or math.abs(corner[2]) > halfDepth then
			return false
		end
	end
	return true
end

-- Another decoration already in the yard: where it stands, and whether it's ground cover that
-- things stand in or on (a mulch bed, a paver path).
export type Placed = { rect: Rect, holds: boolean? }

-- Whether a decoration with this footprint can go there:
--   plotWidth, plotDepth  the plot
--   blocked               the driveway, the building and what stands around it
--   lawn                  the front lawn's grass, which only `onLawn` decorations may stand on
--   others                the yard's other decorations: it can't overlap one, unless one of the
--                         two is ground cover (`holds`) and the other isn't
-- Returns false and why if it can't.
function DecorPlacement.check(
	rect: Rect,
	plotWidth: number,
	plotDepth: number,
	blocked: { Rect },
	lawn: Rect?,
	onLawn: boolean?,
	others: { Placed }?,
	holds: boolean?
): (boolean, string?)
	if not DecorPlacement.inside(rect, plotWidth, plotDepth) then
		return false, "Keep it on your plot."
	end
	for _, other in blocked do
		if DecorPlacement.overlaps(rect, other) then
			return false, "Not on the driveway, the building or what's around it."
		end
	end
	if lawn and not onLawn and DecorPlacement.overlaps(rect, lawn) then
		return false, "That's too big for the lawn. Put it beside the grass."
	end
	if others then
		for _, other in others do
			if (holds == true) == (other.holds == true) and DecorPlacement.overlaps(rect, other.rect) then
				return false, "Something's already there."
			end
		end
	end
	return true, nil
end

-- A turn made tidy: between -pi and pi.
function DecorPlacement.wrap(turn: number): number
	return (turn + math.pi) % (2 * math.pi) - math.pi
end

-- Whether a number from the network is a real, usable one.
function DecorPlacement.finite(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < 1e6
end

return DecorPlacement
