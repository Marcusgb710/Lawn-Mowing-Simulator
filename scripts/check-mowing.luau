-- Checks the lawn's cell maths outside Roblox:
--   lune run scripts/check-mowing
-- It checks which cells a mower's deck sweeps over (src/shared/LawnGrid.luau) and the counts the
-- job's progress is built from. Exits with an error if anything's off.

local process = require("@lune/process")

local LawnGrid = require("../src/shared/LawnGrid")

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL  " .. message)
	end
end

local function same(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

-- The sweep -----------------------------------------------------------------------------------

-- 10x10 lawn, deck 5 wide centred on x=5.5 (a cell centre, so no cell sits on the deck's edge),
-- straight pass from z=-1 to z=11
local cells = LawnGrid.cellsUnderSweep(10, 10, 5.5, -1, 5.5, 11, 2.5)
check(#cells == 50, "a straight 5-wide pass over a 10-deep lawn cuts 50 cells")
check(table.find(cells, LawnGrid.index(2, 0, 10)) == nil, "cells left of the deck stay tall")
check(table.find(cells, LawnGrid.index(3, 0, 10)) ~= nil, "the deck's left edge cuts column 3")
check(#LawnGrid.cellsUnderSweep(10, 10, 50, 50, 60, 60, 2.5) == 0, "sweep clamps to the lawn")
-- A standing deck is 5 wide and 2 studs long, along +Z. At z=5.0 that's rows 4 and 5.
local standing = LawnGrid.cellsUnderSweep(10, 10, 5.5, 5.0, 5.5, 5.0, 2.5)
check(#standing == 10, "standing still cuts once, the 5 x 2 cells under the deck")
check(
	standing[1] == LawnGrid.index(3, 4, 10) and standing[#standing] == LawnGrid.index(7, 5, 10),
	"a standing deck lies along +Z: columns 3 to 7, rows 4 and 5"
)
-- At z=5.5 the deck's ends land exactly on cell centres, and a center on the edge isn't under it.
check(#LawnGrid.cellsUnderSweep(10, 10, 5.5, 5.5, 5.5, 5.5, 2.5) == 5, "a cell center on the deck's edge isn't cut")
local diagonal = LawnGrid.cellsUnderSweep(10, 10, 0, 0, 10, 10, 1)
check(#diagonal > 10 and #diagonal < 40, "a diagonal cuts a band, not a column")
local ascending = true
for position = 2, #diagonal do
	ascending = ascending and diagonal[position] > diagonal[position - 1]
end
check(ascending, "the cells come back in ascending order, none twice")
check(same(LawnGrid.cellsUnderSweep(10, 10, 5.5, 11, 5.5, -1, 2.5), cells), "a pass the other way cuts the same cells")

-- A deck stopped by junk ------------------------------------------------------------------------

-- Pushing up x=5.5 from z=0, 5 wide, with junk in cell (5, 6): its center is 6.5 studs along.
local junkCell = LawnGrid.index(5, 6, 10)
check(LawnGrid.along(10, 5.5, 0, 5.5, 9, junkCell) == 6.5, "how far along a sweep a cell's center lies")
local stopX, stopZ = LawnGrid.stopBefore(5.5, 0, 5.5, 9, 6.5)
check(stopX == 5.5 and stopZ == 5, "the swath ends the deck's reach and half a cell short of the junk's center")
local upToJunk = LawnGrid.cellsUnderSweep(10, 10, 5.5, 0, stopX :: number, stopZ :: number, 2.5)
local shortOfJunk = true
for _, index in upToJunk do
	local _, row = LawnGrid.cell(index, 10)
	shortOfJunk = shortOfJunk and row < 6
end
check(#upToJunk == 30 and shortOfJunk, "so it covers the 6 rows before the junk's row and nothing from it on")
check(LawnGrid.stopBefore(5.5, 5, 5.5, 9, 1.5) == nil, "junk 1.5 studs ahead stops the deck before it cuts anything")
check(LawnGrid.stopBefore(5.5, 5, 5.5, 5, 0.5) == nil, "junk under a standing deck stops it before it cuts anything")
-- On a diagonal, cells beside the line can sit closer to the junk's center than the cells on it.
local stopAt = LawnGrid.along(10, 0, 0, 9, 9, LawnGrid.index(5, 5, 10))
local diagonalX, diagonalZ = LawnGrid.stopBefore(0, 0, 9, 9, stopAt)
local diagonalCells = if diagonalX
	then LawnGrid.cellsUnderSweep(10, 10, 0, 0, diagonalX, diagonalZ :: number, 1.5)
	else {}
local diagonalShort = #diagonalCells > 0
for _, index in diagonalCells do
	diagonalShort = diagonalShort and LawnGrid.along(10, 0, 0, 9, 9, index) < stopAt - 0.5
end
check(diagonalShort, "on a diagonal, every cell the swath covers is over half a cell short of the junk's center")

-- Snips -----------------------------------------------------------------------------------------

check(#LawnGrid.cellsInCircle(10, 10, 5, 5, 1) == 4, "a 1-stud snip touches the 4 cells round its point")
check(#LawnGrid.cellsInCircle(10, 10, -5, -5, 1) == 0, "a snip off the lawn cuts nothing")

-- Counts ----------------------------------------------------------------------------------------

check(LawnGrid.mowableCount("0011--2") == 5 and LawnGrid.cutCount("0011--2") == 3, "counts")

-- The lawn as it's built ------------------------------------------------------------------------

local mask = LawnGrid.mowableMask(4, 4, { [LawnGrid.index(1, 1, 4)] = true })
check(#mask == 16 and mask[LawnGrid.index(1, 1, 4)] == "-" and mask[1] == "0", "mowable mask marks blocked cells")

-- The swath log ---------------------------------------------------------------------------------

local Swath = require("../src/shared/Swath")

check(Swath.shade(0, 1) == "Light" and Swath.shade(0, -1) == "Dark" and Swath.shade(1, 0) == "Flat", "shade by travel")
check(Swath.shade(0.7, 0.71) == "Light", "just past 45 degrees away is still light")
-- A direction `degreesFromZ` off +Z, `scale` long (negative scale points it along -Z instead). The
-- stripe turns from light or dark to flat 60 degrees off, which the checks below sit either side of.
local function heading(degreesFromZ: number, scale: number): (number, number)
	return scale * math.sin(math.rad(degreesFromZ)), scale * math.cos(math.rad(degreesFromZ))
end
check(Swath.shade(heading(59, 1)) == "Light", "59 degrees off +Z is light")
check(Swath.shade(heading(61, 1)) == "Flat", "61 degrees off +Z is flat")
check(Swath.shade(heading(59, -1)) == "Dark", "59 degrees off -Z is dark")
check(Swath.shade(heading(61, -1)) == "Flat", "61 degrees off -Z is flat")
check(Swath.shade(0, 40) == "Light" and Swath.shade(0, 0.001) == "Light", "only the way it goes counts, not how far")
check(Swath.shade(0, 0) == "Flat", "no direction is flat")

local colorsOk = Swath.RAGGED == "Ragged"
for _, name in { "Light", "Flat", "Dark", Swath.RAGGED } do
	local color = Swath.Colors[name]
	colorsOk = colorsOk and color ~= nil and #color == 3
	for _, channel in color or {} do
		colorsOk = colorsOk and channel >= 0 and channel <= 255
	end
end
check(colorsOk, "every shade, and ragged, has an RGB colour from 0 to 255")

local function seg(fromX: number, fromZ: number, toX: number, toZ: number): Swath.Segment
	return {
		fromX = fromX,
		fromZ = fromZ,
		toX = toX,
		toZ = toZ,
		halfWidth = 2.5,
		shade = Swath.shade(toX - fromX, toZ - fromZ),
		ragged = false,
	}
end

local log: { Swath.Segment } = {}
check(Swath.append(log, seg(0, 0, 0, 2)) == false and #log == 1, "first segment is added")
check(
	Swath.append(log, seg(0, 2, 0, 4)) == true and #log == 1 and log[1].toZ == 4,
	"collinear same-shade segments merge"
)
check(log[1].fromX == 0 and log[1].fromZ == 0 and log[1].toX == 0, "a merge only moves the end")
check(Swath.append(log, seg(0, 4, 0, 2)) == false and #log == 2, "a turn starts a new segment")
check(
	Swath.append(
		log,
		{ fromX = 1, fromZ = 1, toX = 1, toZ = 1, halfWidth = 0, radius = 1, shade = "Flat", ragged = false }
	)
			== false
		and #log == 3,
	"snips never merge"
)
check(
	Swath.append(log, seg(5, 5, 5, 5)) == false and #log == 4,
	"an empty sweep (a mower standing still) is its own entry"
)
check(
	Swath.append(log, seg(5, 5, 5, 7)) == false and #log == 5,
	"a sweep carrying on from a standing one doesn't merge into it"
)

-- What does and doesn't carry on from the sweep before it, each against a fresh log.
local function continuesOn(first: Swath.Segment, second: Swath.Segment): boolean
	local pass: { Swath.Segment } = {}
	Swath.append(pass, first)
	return Swath.append(pass, second) == true and #pass == 1
end
local function startsAnew(first: Swath.Segment, second: Swath.Segment): boolean
	local pass: { Swath.Segment } = {}
	Swath.append(pass, first)
	return Swath.append(pass, second) == false and #pass == 2
end
-- A 2 stud sweep from where seg(0, 0, 0, 2) ends, bent `degrees` off its heading.
local function bent(degrees: number): Swath.Segment
	local toX, toZ = heading(degrees, 2)
	return seg(0, 2, toX, 2 + toZ)
end
check(
	continuesOn(seg(0, 0, 0, 2), bent(1)) and continuesOn(seg(0, 0, 0, 2), bent(-1)),
	"a bend of 1 degree is the same pass"
)
check(
	startsAnew(seg(0, 0, 0, 2), bent(3)) and startsAnew(seg(0, 0, 0, 2), bent(-3)),
	"a bend of 3 degrees is a new segment"
)
check(continuesOn(seg(0, 0, 0, 2), seg(0.2, 2, 0.2, 4)), "a restart within a quarter stud still merges")
check(startsAnew(seg(0, 0, 0, 2), seg(0.3, 2, 0.3, 4)), "a restart over a quarter stud to the side is a new segment")
check(startsAnew(seg(0, 0, 0, 2), seg(0, 2.3, 0, 4.3)), "a restart over a quarter stud on is a new segment")
local narrower = seg(0, 2, 0, 4)
narrower.halfWidth = 1
check(startsAnew(seg(0, 0, 0, 2), narrower), "a different deck width is a new segment")
local torn = seg(0, 2, 0, 4)
torn.ragged = true
check(startsAnew(seg(0, 0, 0, 2), torn), "ragged cutting doesn't merge into clean cutting")
local otherShade = seg(0, 2, 0, 4)
otherShade.shade = "Flat"
check(startsAnew(seg(0, 0, 0, 2), otherShade), "a different shade is a new segment")
local snip: Swath.Segment =
	{ fromX = 1, fromZ = 1, toX = 1, toZ = 1, halfWidth = 0, radius = 1, shade = "Light", ragged = false }
check(startsAnew(snip, snip), "two snips on one spot are two snips")
-- A snip that lines up with a sweep in every other way still stands alone, whichever comes first.
local lined: Swath.Segment =
	{ fromX = 0, fromZ = 2, toX = 0, toZ = 4, halfWidth = 2.5, radius = 1, shade = "Light", ragged = false }
check(startsAnew(seg(0, 0, 0, 2), lined), "a snip never merges into a sweep")
check(startsAnew(seg(0, 0, 0, 2), seg(0, 2, 0, 2)), "a mower stopping at the end of a pass is its own entry")
check(startsAnew(lined, seg(0, 4, 0, 6)), "a sweep never merges into a snip")

local drive: { Swath.Segment } = {}
for step = 0, 9 do
	Swath.append(drive, seg(0, step, 0, step + 1))
end
check(#drive == 1 and drive[1].toZ == 10, "a long straight run, tick by tick, stays one segment")

local reused = seg(0, 0, 0, 2)
local copies: { Swath.Segment } = {}
Swath.append(copies, reused)
reused.toZ = 99
check(copies[1].toZ == 2, "the log keeps its own copy of a segment")

local packed = Swath.pack(log[1])
check(Swath.unpack(packed).toZ == 4 and Swath.unpack(packed).shade == "Light", "pack round-trips")
local expected = { 0, 0, 0, 4, 2.5, 0, "Light", false }
local layoutOk = #packed == #expected
for position, value in expected do
	layoutOk = layoutOk and packed[position] == value
end
check(layoutOk, "a segment packs flat: from, to, half width, radius (0 for none), shade, ragged")

local function sameSegment(a: Swath.Segment, b: Swath.Segment): boolean
	return a.fromX == b.fromX
		and a.fromZ == b.fromZ
		and a.toX == b.toX
		and a.toZ == b.toZ
		and a.halfWidth == b.halfWidth
		and a.radius == b.radius
		and a.shade == b.shade
		and a.ragged == b.ragged
end
local odd: Swath.Segment = {
	fromX = 0.1234567,
	fromZ = 8.7654321,
	toX = -3.3333333,
	toZ = 12.5,
	halfWidth = 2.5,
	shade = "Dark",
	ragged = true,
}
check(sameSegment(Swath.unpack(Swath.pack(odd)), odd), "a sweep round-trips with its numbers untouched and no radius")
check(sameSegment(Swath.unpack(Swath.pack(snip)), snip), "a snip round-trips with its radius")

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("OK")
