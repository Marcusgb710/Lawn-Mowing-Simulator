-- The sums behind a lawn's grass pictures: how sharp to draw it, how many layers of grass to stack,
-- where each layer's dots go, which tuft each dot is, and where a spot on the lawn lands in the picture.
--
-- The client draws a lawn as a flat turf plate with a few "shells" of grass stacked above it, each
-- one an EditableImage. This only does the maths, so it needs nothing from Roblox and loads in Lune
-- too: it can't require GameConfig (that builds Vector3s as it loads) and it uses no Vector2, Color3
-- or Random.

-- Pixels per stud before a big lawn is halved to fit. This is GameConfig.PixelsPerStud, copied here
-- because of the above, so change them together.
local PIXELS_PER_STUD = 4
-- The most pixels an EditableImage can have along a side.
local MAX_IMAGE = 1024

-- Shells of grass above the turf. A touch device has less to spare, so it gets fewer.
local SHELLS = 6
local TOUCH_SHELLS = 4
-- How much thinner the top shell's grass is than the bottom one's: density runs from 1 down to 0.35.
local DENSITY_DROP = 0.65

-- A shell carries this many dots per 4 x 4 px block at full density.
local BLOCK_AREA = 16
local DOTS_PER_BLOCK = 0.6

-- A small LCG (the Numerical Recipes one) so a shell's dots come out the same on every client and
-- every run. The modulus is 2^32, so state * multiplier stays under 2^53 and the maths stays exact.
local LCG_MULTIPLIER = 1664525
local LCG_INCREMENT = 1013904223
local LCG_MODULUS = 4294967296

-- One shell: how high above the turf it sits (studs), and how thick its grass is (1 is full).
export type Shell = { height: number, density: number }
-- One blade of grass in a shell's image: its spot and radius in pixels, and where it falls between
-- the two grass colours (0 to 1).
export type Dot = { x: number, y: number, r: number, tone: number }

local GrassImages = {}

-- How many tufts the grass sheet has, one for each cell of GrassArt.TuftSheet. This file loads
-- nothing, so scripts/check-mowing is what keeps the two agreeing.
GrassImages.TUFTS = 8

-- Gives the next number from 0 up to (not including) 1 each time it's called.
local function randoms(seed: number): () -> number
	local state = math.floor(seed) % LCG_MODULUS
	local function step(): number
		state = (state * LCG_MULTIPLIER + LCG_INCREMENT) % LCG_MODULUS
		return state / LCG_MODULUS
	end
	-- Seeds next to each other (one per shell, say) start out alike, so let it run a little first.
	step()
	step()
	return step
end

-- Pixels per stud for a lawn this many studs across and deep: the usual amount, halved (never below
-- 1) until neither side is more than MAX_IMAGE pixels.
function GrassImages.pixelsPerStud(widthStuds: number, heightStuds: number): number
	local pixels = PIXELS_PER_STUD
	while pixels > 1 and (math.ceil(widthStuds * pixels) > MAX_IMAGE or math.ceil(heightStuds * pixels) > MAX_IMAGE) do
		pixels = math.max(pixels / 2, 1)
	end
	return pixels
end

function GrassImages.shellCount(touch: boolean): number
	return if touch then TOUCH_SHELLS else SHELLS
end

-- The `count` shells, bottom to top: they climb evenly to tallHeight, and their grass thins out as
-- they go, from full at the bottom to 1 - DENSITY_DROP at the top (a lone shell stays full).
function GrassImages.shellPlan(count: number, tallHeight: number): { Shell }
	local plan: { Shell } = {}
	for shell = 1, count do
		plan[shell] = {
			height = tallHeight * shell / count,
			density = if count == 1 then 1 else 1 - DENSITY_DROP * (shell - 1) / (count - 1),
		}
	end
	return plan
end

-- The dots for one shell's image, widthPx by heightPx, thinner as density drops. The same arguments
-- always give the same dots.
function GrassImages.bladeDots(widthPx: number, heightPx: number, density: number, seed: number): { Dot }
	local random = randoms(seed)
	local dots: { Dot } = {}
	for index = 1, math.floor(widthPx * heightPx / BLOCK_AREA * density * DOTS_PER_BLOCK) do
		-- Drawn one at a time, so the order they come in never depends on how a table is built.
		local x = random() * widthPx
		local y = random() * heightPx
		local r = 1 + random()
		local tone = random()
		dots[index] = { x = x, y = y, r = r, tone = tone }
	end
	return dots
end

-- Which of the sheet's tufts (1 to TUFTS) a dot is drawn as. It comes from the dot's own numbers, so
-- the same dot is the same tuft on every client, however often it's drawn.
function GrassImages.tuftFor(dot: Dot): number
	return 1 + math.floor(dot.x * 7 + dot.y * 13 + dot.r * 101 + dot.tone * 1009) % GrassImages.TUFTS
end

-- Where a spot on the lawn falls in its picture, not rounded: lawn X runs along the image's X and
-- lawn Z down its Y, from the top-left corner at (originX, originZ).
function GrassImages.worldToPixel(originX: number, originZ: number, pps: number, x: number, z: number): (number, number)
	return (x - originX) * pps, (z - originZ) * pps
end

-- One side of the box, for clipLine. The segment is walked as t from 0 (its start) to 1 (its end),
-- and it's on this side's inside while room + gain * t is 0 or more: `room` is how far inside the
-- start sits, `gain` how fast that grows. Narrows enter..leave, the stretch of t still inside, to
-- what this side allows. When none is left, enter ends up above leave and stays there.
local function clipSide(room: number, gain: number, enter: number, leave: number): (number, number)
	if gain == 0 then
		-- Running alongside this side: all of the segment is inside it, or none.
		if room < 0 then
			return 1, 0
		end
		return enter, leave
	end
	local crossing = -room / gain
	if gain > 0 then
		return math.max(enter, crossing), leave
	end
	return enter, math.min(leave, crossing)
end

-- The spot t of the way from `from` along `delta`, held to 0..limit so rounding can't leave it a
-- hair outside.
local function pointAlong(from: number, delta: number, t: number, limit: number): number
	return math.clamp(from + delta * t, 0, limit)
end

-- Clips the segment (x1, y1)-(x2, y2) to the box from (0, 0) to (width, height), edges included
-- (Liang-Barsky), and gives the clipped endpoints, or nil when none of the segment is inside. An
-- EditableImage won't draw a line with either end outside it, so a swath that runs off the lawn is
-- cut back to the picture with this first.
function GrassImages.clipLine(
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	width: number,
	height: number
): (number?, number?, number?, number?)
	local dx, dy = x2 - x1, y2 - y1
	local enter, leave = clipSide(x1, dx, 0, 1)
	enter, leave = clipSide(width - x1, -dx, enter, leave)
	enter, leave = clipSide(y1, dy, enter, leave)
	enter, leave = clipSide(height - y1, -dy, enter, leave)
	if enter > leave then
		return nil
	end
	-- An end that was already inside comes back as it went in, not as a sum that may be off a hair.
	local startX, startY, endX, endY = x1, y1, x2, y2
	if enter > 0 then
		startX, startY = pointAlong(x1, dx, enter, width), pointAlong(y1, dy, enter, height)
	end
	if leave < 1 then
		endX, endY = pointAlong(x1, dx, leave, width), pointAlong(y1, dy, leave, height)
	end
	return startX, startY, endX, endY
end

return GrassImages
