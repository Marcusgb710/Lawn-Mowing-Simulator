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

-- Snips -----------------------------------------------------------------------------------------

check(#LawnGrid.cellsInCircle(10, 10, 5, 5, 1) == 4, "a 1-stud snip touches the 4 cells round its point")
check(#LawnGrid.cellsInCircle(10, 10, -5, -5, 1) == 0, "a snip off the lawn cuts nothing")

-- Counts ----------------------------------------------------------------------------------------

check(LawnGrid.mowableCount("0011--2") == 5 and LawnGrid.cutCount("0011--2") == 3, "counts")

if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
print("OK")
