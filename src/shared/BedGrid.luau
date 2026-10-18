-- A truck bed (or trailer bed) as a grid of cells, one per unit of space (docs/GAME_DESIGN.md,
-- "Immersion"): two cells across the bed and as many rows along it as it takes, so the 6-space
-- rusty pickup is 2 x 3 and the 14-space landscaping truck 2 x 7. Cells are numbered from 1,
-- across then along: cell 1 is the front left, cell 2 the front right.
--
-- Each tool covers a block of cells by its size class: hand tools, supplies, the tool bucket and
-- long tools (laid lengthwise) 1 cell, handheld power tools 2 (one behind the other), push and
-- engine machines 4 (2 x 2, standing up). Hand tools in a tool bucket take no cells of their own,
-- and ride-ons park on the trailer's bay spots instead.

local BedGrid = {}

BedGrid.Columns = 2

-- Size class = { columns, rows } covered.
local FOOTPRINTS = {
	Hand = { 1, 1 },
	Supply = { 1, 1 },
	Long = { 1, 1 },
	HangingPower = { 1, 2 },
	FloorManual = { 2, 2 },
	FloorEngine = { 2, 2 },
}

export type Grid = { columns: number, rows: number, cells: number }

-- The grid for a bed with this much space.
function BedGrid.new(space: number): Grid
	local cells = math.max(0, math.floor(space))
	local columns = if cells >= BedGrid.Columns then BedGrid.Columns else math.max(cells, 1)
	return { columns = columns, rows = math.ceil(cells / columns), cells = cells }
end

-- How many columns and rows a tool of this size class covers, or nil if it doesn't go in a bed.
function BedGrid.footprint(sizeClass: string): (number?, number?)
	local footprint = FOOTPRINTS[sizeClass]
	if not footprint then
		return nil, nil
	end
	return footprint[1], footprint[2]
end

function BedGrid.indexOf(grid: Grid, column: number, row: number): number
	return row * grid.columns + column + 1
end

-- 0-based column and row of a cell.
function BedGrid.position(grid: Grid, index: number): (number, number)
	return (index - 1) % grid.columns, (index - 1) // grid.columns
end

-- The cells a tool covers with its front-left corner in cell `anchor`, or nil if it doesn't fit
-- inside the grid there.
function BedGrid.cells(grid: Grid, sizeClass: string, anchor: number): { number }?
	local width, height = BedGrid.footprint(sizeClass)
	if not (width and height) or anchor < 1 or anchor > grid.cells then
		return nil
	end
	local column, row = BedGrid.position(grid, anchor)
	if column + width > grid.columns or row + height > grid.rows then
		return nil
	end
	local list = {}
	for dy = 0, height - 1 do
		for dx = 0, width - 1 do
			local index = BedGrid.indexOf(grid, column + dx, row + dy)
			if index > grid.cells then
				return nil
			end
			table.insert(list, index)
		end
	end
	return list
end

-- Whether none of `cells` is taken. `taken` is { [cell] = anything }.
function BedGrid.free(taken, cells: { number }): boolean
	for _, index in cells do
		if taken[index] ~= nil then
			return false
		end
	end
	return true
end

-- The first anchor where a tool fits, or nil if the bed has no room for it.
function BedGrid.firstFit(grid: Grid, taken, sizeClass: string): number?
	for anchor = 1, grid.cells do
		local cells = BedGrid.cells(grid, sizeClass, anchor)
		if cells and BedGrid.free(taken, cells) then
			return anchor
		end
	end
	return nil
end

-- The anchor that puts a tool's block around the cell at (column, row), kept inside the grid.
function BedGrid.anchorAround(grid: Grid, sizeClass: string, column: number, row: number): number?
	local width, height = BedGrid.footprint(sizeClass)
	if not (width and height) or width > grid.columns or height > grid.rows then
		return nil
	end
	local left = math.clamp(column - (width - 1) // 2, 0, grid.columns - width)
	local front = math.clamp(row - (height - 1) // 2, 0, grid.rows - height)
	return BedGrid.indexOf(grid, left, front)
end

-- Which cell a point on the bed is over. `x` runs across the bed and `z` along it, both from
-- the bed's centre, on a bed `width` by `length`. The front of the bed is -z.
function BedGrid.cellAt(grid: Grid, x: number, z: number, width: number, length: number): (number, number)
	local column = math.clamp(math.floor((x / width + 0.5) * grid.columns), 0, grid.columns - 1)
	local row = math.clamp(math.floor((z / length + 0.5) * grid.rows), 0, grid.rows - 1)
	return column, row
end

-- The middle of a block of cells, as (x, z) from the bed's centre (see cellAt).
function BedGrid.center(grid: Grid, cells: { number }, width: number, length: number): (number, number)
	local x, z = 0, 0
	for _, index in cells do
		local column, row = BedGrid.position(grid, index)
		x += ((column + 0.5) / grid.columns - 0.5) * width
		z += ((row + 0.5) / grid.rows - 0.5) * length
	end
	return x / #cells, z / #cells
end

return BedGrid
