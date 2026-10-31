-- Checks the mowing maths outside Roblox:
--   lune run scripts/check-mowing
-- It checks which cells a mower's deck sweeps over and a snip cuts, and how many cells finish a
-- task (src/shared/LawnGrid.luau); the swath log's shades, merging, cap and packing
-- (src/shared/Swath.luau); the grass pictures' sums, tuft picks and line clipping (src/shared/GrassImages.luau);
-- and how home lawn saves from before cells are read (src/shared/HomeLawn.luau). Exits with an
-- error if anything's off.

local fs = require("@lune/fs")
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
check(
	#LawnGrid.cellsUnderSweep(10, 10, -1, 5.5, 11, 5.5, 2.5) == 50,
	"the same pass across the lawn (+X), at z=5.5, cuts 50 cells too"
)
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
check(#diagonal == 28, "a 2-wide diagonal corner to corner cuts a band of 28 cells")
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

-- The lawn as it's built ------------------------------------------------------------------------

local mask = LawnGrid.mowableMask(4, 4, { [LawnGrid.index(1, 1, 4)] = true })
check(#mask == 16 and mask[LawnGrid.index(1, 1, 4)] == "-" and mask[1] == "0", "mowable mask marks blocked cells")

-- The swath log ---------------------------------------------------------------------------------

local Swath = require("../src/shared/Swath")

check(Swath.shade(0, 1) == "Light" and Swath.shade(0, -1) == "Dark" and Swath.shade(1, 0) == "Flat", "shade by travel")
check(Swath.shade(0.7, 0.71) == "Light", "45 degrees away is still light: it holds to 60 degrees")
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

-- Each append says which entry the segment ended up in, and the next of the same mower's is
-- offered that one to stretch.
local log: { Swath.Segment } = {}
check(Swath.append(log, seg(0, 0, 0, 2)) == 1 and #log == 1, "first segment is added")
check(
	Swath.append(log, seg(0, 2, 0, 4), 1) == 1 and #log == 1 and log[1].toZ == 4,
	"collinear same-shade segments merge"
)
check(log[1].fromX == 0 and log[1].fromZ == 0 and log[1].toX == 0, "a merge only moves the end")
check(Swath.append(log, seg(0, 4, 0, 2), 1) == 2 and #log == 2, "a turn starts a new segment")
check(
	Swath.append(
		log,
		{ fromX = 1, fromZ = 1, toX = 1, toZ = 1, halfWidth = 0, radius = 1, shade = "Flat", ragged = false },
		2
	)
			== 3
		and #log == 3,
	"snips never merge"
)
check(
	Swath.append(log, seg(5, 5, 5, 5), 3) == 4 and #log == 4,
	"an empty sweep (a mower standing still) is its own entry"
)
check(
	Swath.append(log, seg(5, 5, 5, 7), 4) == 5 and #log == 5,
	"a sweep carrying on from a standing one doesn't merge into it"
)
check(Swath.append({}, seg(0, 0, 0, 2), 7) == 1, "with no entry at the index given, the segment is added")

-- What does and doesn't carry on from the sweep before it, each against a fresh log.
local function continuesOn(first: Swath.Segment, second: Swath.Segment): boolean
	local pass: { Swath.Segment } = {}
	local index = Swath.append(pass, first)
	return Swath.append(pass, second, index) == index and #pass == 1
end
local function startsAnew(first: Swath.Segment, second: Swath.Segment): boolean
	local pass: { Swath.Segment } = {}
	local index = Swath.append(pass, first)
	return Swath.append(pass, second, index) == 2 and #pass == 2
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
local function raggedSeg(fromX: number, fromZ: number, toX: number, toZ: number): Swath.Segment
	local sweep = seg(fromX, fromZ, toX, toZ)
	sweep.shade, sweep.ragged = Swath.RAGGED, true
	return sweep
end
check(continuesOn(raggedSeg(0, 0, 0, 2), raggedSeg(0, 2, 0, 4)), "two ragged sweeps the same way merge")

local drive: { Swath.Segment } = {}
local driving = nil
for step = 0, 9 do
	driving = Swath.append(drive, seg(0, step, 0, step + 1), driving)
end
check(#drive == 1 and drive[1].toZ == 10, "a long straight run, tick by tick, stays one segment")

-- Two mowers side by side, their ticks taking turns in the log: each stretches its own entry.
local pair: { Swath.Segment } = {}
local mowerA, mowerB = nil, nil
for step = 0, 1 do
	mowerA = Swath.append(pair, seg(0, step, 0, step + 1), mowerA)
	mowerB = Swath.append(pair, seg(10, step, 10, step + 1), mowerB)
end
check(
	#pair == 2 and pair[mowerA].toZ == 2 and pair[mowerB].toZ == 2 and pair[mowerA].toX == 0,
	"two mowers taking turns stay two entries, each still growing"
)

-- A slow curve, half a degree more each tick: the pass's heading drifts away from its first
-- stretch, so by 5 degrees it has started a second entry.
local curve: { Swath.Segment } = {}
local curving = nil
local atX, atZ = 0, 0
local atOneDegree = 0
for tick = 0, 10 do
	local stepX, stepZ = heading(tick * 0.5, 1)
	curving = Swath.append(curve, seg(atX, atZ, atX + stepX, atZ + stepZ), curving)
	atX, atZ = atX + stepX, atZ + stepZ
	if tick == 2 then
		atOneDegree = #curve
	end
end
check(
	atOneDegree == 1 and #curve == 2,
	"a slow curve is one pass at first, and two by the time it has turned 5 degrees"
)

-- The cap: past MAX_LOG entries, the oldest go, and trim says how many.
local long: { Swath.Segment } = {}
local longIndex = nil
local trimmed = 0
for count = 1, Swath.MAX_LOG + 5 do
	-- Each heads its own way (a new entry every time); its fromX says which one it was.
	local toX, toZ = heading(count * 7 % 360, 2)
	longIndex = Swath.append(long, seg(count, 0, count + toX, toZ), longIndex)
	trimmed += Swath.trim(long)
end
check(Swath.MAX_LOG == 1024 and #long == 1024 and trimmed == 5, "the log keeps 1024 entries")
check(long[1].fromX == 6 and long[#long].fromX == Swath.MAX_LOG + 5, "the first five appended are the ones gone")

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

-- The grass images ------------------------------------------------------------------------------

local GrassImages = require("../src/shared/GrassImages")

check(GrassImages.pixelsPerStud(36, 28) == 4, "a small lawn gets 4 px per stud")
check(GrassImages.pixelsPerStud(112, 88) == 4, "the biggest lawn still fits at 4")
check(GrassImages.pixelsPerStud(300, 40) == 2, "pixelsPerStud caps at 1024")
check(GrassImages.pixelsPerStud(40, 300) == 2, "the long side can be either one")
check(GrassImages.pixelsPerStud(256, 256) == 4, "a lawn exactly 1024 px across at 4 still gets 4")
check(GrassImages.pixelsPerStud(256.25, 40) == 2, "a quarter stud more needs a 1025th pixel, so it halves")
check(GrassImages.pixelsPerStud(512, 10) == 2 and GrassImages.pixelsPerStud(513, 10) == 1, "it halves again past 512")
check(GrassImages.pixelsPerStud(5000, 40) == 1, "a huge lawn never drops below 1 px per stud")

check(GrassImages.shellCount(false) == 6 and GrassImages.shellCount(true) == 4, "shell counts")
local plan = GrassImages.shellPlan(6, 1.5)
check(#plan == 6 and plan[6].height == 1.5 and plan[1].density == 1 and plan[6].density < 0.4, "shell plan")
check(plan[1].height == 0.25 and plan[3].height == 0.75, "shells rise in even steps")
local fading = math.abs(plan[6].density - 0.35) < 1e-9
for shell = 2, #plan do
	fading = fading and plan[shell].density < plan[shell - 1].density
end
check(fading, "density falls shell by shell down to 0.35")
local touchPlan = GrassImages.shellPlan(GrassImages.shellCount(true), 1.5)
check(#touchPlan == 4 and touchPlan[4].height == 1.5 and math.abs(touchPlan[4].density - 0.35) < 1e-9, "touch plan")
local lone = GrassImages.shellPlan(1, 1.5)
check(#lone == 1 and lone[1].height == 1.5 and lone[1].density == 1, "a single shell is full height and full density")
check(#GrassImages.shellPlan(0, 1.5) == 0, "no shells, no plan")

-- Uncut grass stands GameConfig.TallGrassHeight (2 studs) tall, but on a lawn of normal height (TallScale 1)
-- no stack of shells is spaced wider than GrassImages.MAX_SHELL_GAP (0.375, a phone's 4 shells under 1.5
-- studs, as phones have always had): each shell is a flat sheet, so wider gaps show as separate sheets at a
-- cut edge. So 6 shells stand 2 studs (a third of a stud apart) and a phone's 4 stay at 1.5. These checks
-- run at TallScale 1: a taller lawn's TallScale (up to 3) multiplies the height and the gaps past the cap,
-- as it always has. GrassController builds its plan from tallHeight times TallScale; the simple renderer's
-- solid blocks have no gaps and stand the full height.
local tallGrass =
	tonumber(string.match(fs.readFile("src/shared/Config/GameConfig.luau"), "%sTallGrassHeight = ([%d%.]+),"))
check(tallGrass == 2, `GameConfig's TallGrassHeight is {tallGrass}, not 2 studs`)
check(GrassImages.MAX_SHELL_GAP == 0.375, "the widest shell gap is a phone's 4 shells under 1.5 studs")
check(GrassImages.tallHeight(6, 2) == 2, "6 shells stand the full 2 studs")
check(GrassImages.tallHeight(4, 2) == 1.5, "a phone's 4 shells stay at 1.5 studs")
check(
	GrassImages.tallHeight(4, 1) == 1 and GrassImages.tallHeight(0, 2) == 2,
	"a short lawn or no shells keep the height"
)
for _, touch in { false, true } do
	local count = GrassImages.shellCount(touch)
	local stack = GrassImages.shellPlan(count, GrassImages.tallHeight(count, tallGrass or 2))
	local widest = stack[1].height
	for shell = 2, #stack do
		widest = math.max(widest, stack[shell].height - stack[shell - 1].height)
	end
	check(
		widest <= GrassImages.MAX_SHELL_GAP + 1e-9,
		`{count} shells under {tallGrass} studs of grass (TallScale 1) are {widest} studs apart, over {GrassImages.MAX_SHELL_GAP}`
	)
end
check(
	string.find(
		fs.readFile("src/client/Controllers/GrassController.luau"),
		"GrassImages.shellPlan(count, GrassImages.tallHeight(count, GameConfig.TallGrassHeight) * lawn.tallScale)",
		1,
		true
	) ~= nil,
	"GrassController doesn't stack its shells to GrassImages.tallHeight"
)

local dots = GrassImages.bladeDots(40, 40, 1, 7)
check(#dots > 40 and #dots == #GrassImages.bladeDots(40, 40, 1, 7), "dots are plentiful and deterministic")
check(#GrassImages.bladeDots(50, 30, 1, 3) == 56, "0.6 dots per 4 x 4 px at full density")
check(#GrassImages.bladeDots(50, 30, 0.5, 3) == 28, "half the density, half the dots")
check(#GrassImages.bladeDots(40, 40, 0, 7) == 0, "no density, no dots")
local again = GrassImages.bladeDots(40, 40, 1, 7)
local identical = #again == #dots
for index, dot in dots do
	local other = again[index]
	identical = identical
		and other ~= nil
		and dot.x == other.x
		and dot.y == other.y
		and dot.r == other.r
		and dot.tone == other.tone
end
check(identical, "the same arguments give the very same dots")
local inRange = true
local quadrants = {}
for _, dot in GrassImages.bladeDots(50, 30, 1, 3) do
	inRange = inRange and dot.x >= 0 and dot.x < 50 and dot.y >= 0 and dot.y < 30
	inRange = inRange and dot.r >= 1 and dot.r <= 2 and dot.tone >= 0 and dot.tone <= 1
	quadrants[(if dot.x < 25 then 0 else 1) + (if dot.y < 15 then 0 else 2)] = true
end
check(inRange, "every dot sits inside the image, 1 to 2 px across, with a tone from 0 to 1")
check(quadrants[0] and quadrants[1] and quadrants[2] and quadrants[3], "dots reach every quarter of the image")
local nearby = GrassImages.bladeDots(40, 40, 1, 8)
check(math.abs(nearby[1].x - dots[1].x) > 1 or math.abs(nearby[1].y - dots[1].y) > 1, "neighbouring seeds start apart")

-- A tuft is picked from the dot alone: the same dot always draws the same one of the sheet's eight.
local GrassArt = require("../src/shared/Config/GrassArt")
check(
	GrassImages.TUFTS == GrassArt.TuftSheet.columns * GrassArt.TuftSheet.rows,
	"there is one tuft kind for each cell of the sheet"
)
local tuftDots = GrassImages.bladeDots(256, 256, 1, 11)
local tuftDotsAgain = GrassImages.bladeDots(256, 256, 1, 11)
check(#tuftDots >= 1000 and #tuftDotsAgain == #tuftDots, "a tile has the 1000 dots tuftFor is tried on")
local tuftsInRange, tuftsAgree = true, true
local tuftCounts = {}
for index = 1, 1000 do
	local tuft = GrassImages.tuftFor(tuftDots[index])
	tuftsInRange = tuftsInRange and tuft == math.floor(tuft) and tuft >= 1 and tuft <= 8
	tuftsAgree = tuftsAgree and tuft == GrassImages.tuftFor(tuftDotsAgain[index])
	tuftCounts[tuft] = (tuftCounts[tuft] or 0) + 1
end
check(tuftsInRange, "tuftFor gives a whole number from 1 to 8 for 1000 dots")
check(tuftsAgree, "tuftFor gives the same tuft for the same dot on every call")
local everyTuft = true
for tuft = 1, 8 do
	everyTuft = everyTuft and (tuftCounts[tuft] or 0) >= 60
end
check(everyTuft, "every one of the eight tufts turns up, none rare")

local px, py = GrassImages.worldToPixel(100, 200, 4, 110, 205)
check(px == 40 and py == 20, "world to pixel")
local originX, originY = GrassImages.worldToPixel(100, 200, 4, 100, 200)
check(originX == 0 and originY == 0, "the lawn's origin is the image's top-left pixel")
local fractX, fractY = GrassImages.worldToPixel(0, 0, 2, 0.3, 0.75)
check(fractX == 0.6 and fractY == 1.5, "pixels are not rounded")
local beforeX, beforeY = GrassImages.worldToPixel(100, 200, 4, 99, 198)
check(beforeX == -4 and beforeY == -8, "a point before the origin is a negative pixel, not clamped")

-- clipLine keeps a segment inside the picture. The box is 143 x 111; the numbers are the clipped
-- endpoints, which can be a hair off from rounding.
local function clipsTo(x1: number, y1: number, x2: number, y2: number, ...: number): boolean
	local expected = { ... }
	local got = { GrassImages.clipLine(x1, y1, x2, y2, 143, 111) }
	if #got ~= #expected then
		return false
	end
	for index, value in expected do
		if math.abs(got[index] - value) > 1e-6 then
			return false
		end
	end
	return true
end
check(clipsTo(10, 20, 30, 40, 10, 20, 30, 40), "a segment inside the box stays put")
check(clipsTo(-8, 10, 20, 10, 0, 10, 20, 10), "an end past the left edge is cut back to it")
check(clipsTo(50, 100, 50, 130, 50, 100, 50, 111), "an end past the bottom is cut back to it")
-- This one is steeper than the box's diagonal, so it comes in through the top edge and goes out through the bottom.
check(
	clipsTo(-10, -10, 153, 121, -10 + 163 * 10 / 131, 0, -10 + 163 * 121 / 131, 111),
	"a segment crossing the box with both ends out is cut at both"
)
check(clipsTo(-14.3, -11.1, 157.3, 122.1, 0, 0, 143, 111), "a diagonal through two corners is cut back to them")
check(clipsTo(-5, 0, -5, 111), "a segment running alongside the box has nothing inside")
check(clipsTo(200, 200, 300, 250), "a segment far away has nothing inside")
check(clipsTo(7, 7, 7, 7, 7, 7, 7, 7), "a point inside stays")
check(clipsTo(-1, 7, -1, 7), "a point outside is gone")
check(clipsTo(0, 5, 143, 5, 0, 5, 143, 5), "a segment exactly on the box's edges stays")
check(clipsTo(400, 40, -50, 40, 143, 40, 0, 40), "a segment going the other way is cut at both ends, its way round")

-- GrassImages can't load GameConfig, so it keeps its own copy of the pixels per stud: they must agree.
local imagesPixels = string.match(fs.readFile("src/shared/GrassImages.luau"), "local PIXELS_PER_STUD = (%d+)")
local configPixels = string.match(fs.readFile("src/shared/Config/GameConfig.luau"), "PixelsPerStud = (%d+)")
check(imagesPixels ~= nil and imagesPixels == configPixels, "GrassImages' PIXELS_PER_STUD is GameConfig.PixelsPerStud")

-- Home lawn saves from before cells ---------------------------------------------------------------

local luau = require("@lune/luau")

-- HomeLawn reaches its sibling configs through `script`, which Lune doesn't have (and GameConfig
-- builds Vector3s as it loads), so it's loaded with those stood in for. The save format below
-- never touches them. Run from the repo root, like the command at the top.
local stub = {}
setmetatable(stub, {
	__index = function()
		return stub
	end,
})
local HomeLawn = luau.load(fs.readFile("src/shared/HomeLawn.luau"), {
	debugName = "HomeLawn",
	environment = {
		script = stub,
		require = function()
			return stub
		end,
	},
})()

-- A 2x1-tile lawn saved per tile: left tile done, right not. Its cells are 8 across and 4 deep.
local spread = HomeLawn.decode("10", 32, 16, 4)
check(#spread == 32 and spread[1] == true and spread[32] == false, "tile flags spread to cells")
local leftBlock = true
for index = 1, 16 do
	leftBlock = leftBlock and spread[index] == true and spread[index + 16] == false
end
check(leftBlock, "the done tile fills its 16 cells and the other tile's cells stay not done")
check(HomeLawn.decode("10", 32)[1] == false, "mismatched saves without a spread are all not done")
check(#HomeLawn.decode("10", 32) == 32, "an unspread mismatch still gives one flag per target")

-- A 2x2-tile lawn (8x8 cells), tiles counted column by column like cells: with only the second
-- tile, (column 0, row 1), done, the cells that come on are columns 0-3 of rows 4-7.
local second = HomeLawn.decode("0100", 64, 16, 8)
local only = true
local doneCells = 0
for column = 0, 7 do
	for row = 0, 7 do
		local isDone = second[LawnGrid.index(column, row, 8)]
		doneCells += if isDone then 1 else 0
		only = only and isDone == (column < 4 and row >= 4)
	end
end
check(only and doneCells == 16, "a tile's block of cells follows the tile's column and row")
local third = HomeLawn.decode("0010", 64, 16, 8)
check(
	third[LawnGrid.index(4, 0, 8)] == true and third[LawnGrid.index(7, 3, 8)] == true,
	"the third tile is the one across, in the first row"
)
check(third[LawnGrid.index(3, 0, 8)] == false and third[LawnGrid.index(4, 4, 8)] == false, "and only its block")

-- Saves that already have a flag per cell, and saves that fit neither, are read as they were.
local perCell = string.rep("1", 31) .. "0"
local cellsBack = HomeLawn.decode(perCell, 32, 16, 4)
check(
	cellsBack[1] == true and cellsBack[31] == true and cellsBack[32] == false,
	"a save with a flag per cell is read as is"
)
check(HomeLawn.decode(nil, 32, 16, 4)[1] == false, "a missing save is all not done")
check(HomeLawn.decode(12, 32, 16, 4)[1] == false, "a save that isn't a string is all not done")
local resized = HomeLawn.decode("101", 32, 16, 4)
check(#resized == 32 and not table.find(resized, true), "a lawn resized since is all not done")
check(not table.find(HomeLawn.decode("10", 32, 16), true), "tile flags without the lawn's rows are all not done")
check(not table.find(HomeLawn.decode("10", 32, 16, 6), true), "rows that don't divide into tiles are all not done")
check(HomeLawn.encode(spread) == string.rep("1", 16) .. string.rep("0", 16), "what was spread saves back per cell")

-- How many cells finish a task ---------------------------------------------------------------------

check(LawnGrid.needed(1000, 0, 0.99) == 990 and LawnGrid.needed(1000, 100, 0.99) == 891, "needed rounds up")
check(LawnGrid.needed(30, 0, 0.95) == 29, "a share of a count that isn't whole needs the next whole one")
check(LawnGrid.needed(0, 0, 0.99) == 0 and LawnGrid.needed(40, 40, 0.99) == 0, "no cells that count, none needed")
-- The HUD's mowing percent is the required cells cut (LawnService's `requiredDone`: cutting an
-- optional cell beside flowers or trees doesn't add to it) over the ones the job requires (total less
-- optional), so it's at the threshold or more exactly when `needed` of them are cut, on a lawn with
-- no optional cells and on ones where a tenth, over a quarter or half of them are. Which cells are
-- required lives in LawnService, which Lune can't load, so the counting itself isn't checked here.
-- A 6 x 5 tile lawn with one flower patch (464 cells, 128 of them optional) needs 333 of its 336.
check(LawnGrid.needed(464, 128, 0.99) == 333, "a lawn with a flower patch needs 333 of its 336 required cells")
check(332 / 336 < 0.99 and 333 / 336 >= 0.99, "and 333 is where its percent gets to 99%")
local agree = true
for total = 1, 400 do
	for _, optional in { 0, total // 10, total * 28 // 100, total // 2 } do
		local needed = LawnGrid.needed(total, optional, 0.99)
		for done = math.max(0, needed - 2), math.min(total, needed + 2) do
			agree = agree and (done / (total - optional) >= 0.99) == (done >= needed)
		end
	end
end
check(agree, "the percent reaches the threshold exactly when the task has what it needs")

-- A clean stripe (src/shared/Strip.luau) --------------------------------------------------------
-- The pass maths behind the HUD's NICE STRIPE! splash, run by behaviour the way GrassController runs it:
-- a mower sampled at 60 frames a second, the pass ended when the mower stops or turns back.
local Strip = require("../src/shared/Strip")

local goodFacts = { held = true, dead = false, blocked = false, ragged = false, motorized = true, working = true }
local function facts(changes)
	local made = table.clone(goodFacts)
	for key, value in changes or {} do
		made[key] = value
	end
	return made
end

-- Walks `legs` ({ { dx, dz, studs } ...}) at `speed` studs a second after waiting `wait` seconds at the start,
-- then ends the pass with `ending` facts. Returns the studs of each pass cheered and where along the walk
-- (in studs walked) each cheer came.
local function walk(legs, speed, wait, ending)
	local cheers, at = {}, {}
	local x, z, now = 0, 0, 0
	local pass = Strip.start(x, z, now)
	local walked = 0
	local function finish()
		if Strip.cheers(pass, ending) then
			table.insert(cheers, Strip.length(pass))
			table.insert(at, walked)
		end
	end
	while now < wait do
		now += 1 / 60
		if Strip.move(pass, x, z, now) then
			finish()
			pass = Strip.start(x, z, now)
		end
	end
	for _, leg in legs do
		local length = math.sqrt(leg[1] * leg[1] + leg[2] * leg[2])
		local steps = math.ceil(leg[3] / speed * 60)
		for _ = 1, steps do
			now += 1 / 60
			local step = speed / 60
			x += leg[1] / length * step
			z += leg[2] / length * step
			walked += step
			if Strip.move(pass, x, z, now) then
				finish()
				pass = Strip.start(x, z, now)
			end
		end
	end
	finish()
	return cheers, at
end

local cheers = walk({ { 1, 0, 40 } }, 12, 0, facts())
check(#cheers == 1 and cheers[1] > 39 and cheers[1] < 41, "a straight 40 stud pass is a stripe of about 40 studs")
cheers = walk({ { 1, 0, 25 } }, 12, 0, facts())
check(#cheers == 0, "a straight 25 stud pass is no stripe")
cheers = walk({ { 0.6, 0.8, 40 } }, 12, 0, facts())
check(#cheers == 1, "a stripe in any direction counts the same")
cheers = walk({ { 1, 0, 35 } }, 20, 0, facts())
check(#cheers == 1, "a fast pass that ends before the heading is known goes by its distance")
cheers = walk({ { 1, 0, 40 } }, 12, 3, facts())
check(#cheers == 1, "a mower that sat still first still gets its heading from where it went")
cheers = walk({ { 1, 0, 40 } }, 12, 0, facts({ working = false }))
check(#cheers == 0, "a pass whose engine stalled (Working off on a held motorized mower) is no stripe")
cheers = walk({ { 1, 0, 40 } }, 12, 0, facts({ blocked = true }))
check(#cheers == 0, "a blocked mower's pass is no stripe")
cheers = walk({ { 1, 0, 40 } }, 12, 0, facts({ ragged = true }))
check(#cheers == 0, "a torn blade's pass is no stripe")
cheers = walk({ { 1, 0, 40 } }, 12, 0, facts({ dead = true }))
check(#cheers == 0, "a pass you fell in is no stripe")
cheers = walk({ { 1, 0, 40 } }, 12, 0, facts({ held = false, working = false }))
check(#cheers == 1, "a pass ended by putting the mower away is a stripe")
cheers = walk({ { 1, 0, 40 } }, 12, 0, facts({ motorized = false, working = false }))
check(#cheers == 1, "a push mower that stops being pushed ends a clean pass")

-- A U-turn is two passes. The first is over at the turn (8 studs back from the furthest point), where it
-- cheers, and the way back cheers at its own end.
local at
cheers, at = walk({ { 1, 0, 40 }, { -1, 0, 40 } }, 12, 0, facts())
check(#cheers == 2, "a 40 stud pass and 40 back are two stripes")
check(at[1] > 47 and at[1] < 49.5, "and the first cheers at the turn, 8 studs back from its furthest point")
cheers = walk({ { 1, 0, 15 }, { -1, 0, 15 } }, 12, 0, facts())
check(#cheers == 0, "15 studs out and back are two short passes, not one long one")
cheers = walk({ { 1, 0, 20 }, { 0, 1, 20 } }, 12, 0, facts())
check(#cheers == 0, "a corner is not a longer stripe: only the way of the first seconds counts")
cheers = walk({ { 1, 0, 40 }, { 0, 1, 40 } }, 12, 0, facts())
check(#cheers == 1 and cheers[1] > 39 and cheers[1] < 41, "a stripe with a corner after it is still the stripe's 40")
check(Strip.LENGTH >= 30, "a stripe is 30 studs or more")

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("OK")
