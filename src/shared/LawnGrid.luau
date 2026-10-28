-- How a lawn's grass cells are laid out and shared between server and client.
--
-- A lawn is a grid of square cells, one stud on a side, kept in a "Grass" folder inside each job
-- site. Its Origin (Vector3), CellSize, Columns and Rows attributes place the grid in the world, and
-- TallScale says how tall the uncut grass stands. The cells' states stay on the server (see
-- LawnService): clients draw the grass themselves (see GrassController) from the swaths the server
-- sends, so the server never makes grass parts.
--
-- Cells are counted column by column. In lawn-local studs (the origin is the lawn's front-left
-- corner), the cell at (column, row) covers x from column to column + 1 and z from row to row + 1,
-- so its center is (column + 0.5, row + 0.5). A cell is cut when its center is under the mower.
--
-- Each cell is one of the states below, written as a single character.

local LawnGrid = {}

LawnGrid.TALL = "0"
LawnGrid.MOWED = "1"
-- Mowed with a dull blade: short, but torn and ragged.
LawnGrid.RAGGED = "2"
-- No grass here (a flower patch or gnome sits on this cell).
LawnGrid.EMPTY = "-"

-- A deck that has barely moved has no direction to speak of: treat it as standing still.
local BARELY_MOVED = 1e-6
-- The deck's cut reaches this far past where it started and where it ended, so a mower standing
-- still cuts a deck-wide strip two studs long, along the way it faces (+Z).
-- Clients extend the swaths they paint by the same amount at each end.
LawnGrid.DeckReach = 1

function LawnGrid.index(column: number, row: number, rows: number): number
	return column * rows + row + 1
end

function LawnGrid.cell(index: number, rows: number): (number, number)
	return (index - 1) // rows, (index - 1) % rows
end

-- Center of a cell, on the ground.
function LawnGrid.center(origin: Vector3, cellSize: number, column: number, row: number): Vector3
	return origin + Vector3.new(column * cellSize + cellSize / 2, 0, row * cellSize + cellSize / 2)
end

-- Which way a deck moving from one spot to another is going, as a unit vector, and how far it
-- went. One that has barely moved is standing still: it faces +Z and went nowhere.
function LawnGrid.heading(fromX: number, fromZ: number, toX: number, toZ: number): (number, number, number)
	local moveX, moveZ = toX - fromX, toZ - fromZ
	local length = math.sqrt(moveX * moveX + moveZ * moveZ)
	if length > BARELY_MOVED then
		return moveX / length, moveZ / length, length
	end
	return 0, 1, 0
end

-- The cells a mower's deck cuts moving in a straight line from one spot to another in a tick, as
-- indexes in ascending order. The deck is 2 x halfWidth wide, across the way it moves, and a cell
-- is cut when its center is strictly inside the strip it sweeps. Spots off the lawn are fine: only
-- cells on the lawn come back.
function LawnGrid.cellsUnderSweep(
	columns: number,
	rows: number,
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number
): { number }
	-- The way the deck is going (a unit vector), and the one across it.
	local alongX, alongZ, length = LawnGrid.heading(fromX, fromZ, toX, toZ)
	local acrossX, acrossZ = -alongZ, alongX

	-- The strip's four corners, only to find which cells are worth testing.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, distance in { -LawnGrid.DeckReach, length + LawnGrid.DeckReach } do
		for _, side in { -halfWidth, halfWidth } do
			local x = fromX + alongX * distance + acrossX * side
			local z = fromZ + alongZ * distance + acrossZ * side
			minX, maxX = math.min(minX, x), math.max(maxX, x)
			minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
		end
	end

	local found = {}
	for column = math.max(0, math.floor(minX)), math.min(columns - 1, math.floor(maxX)) do
		local x = column + 0.5 - fromX
		for row = math.max(0, math.floor(minZ)), math.min(rows - 1, math.floor(maxZ)) do
			local z = row + 0.5 - fromZ
			local along = x * alongX + z * alongZ
			local across = x * acrossX + z * acrossZ
			if along > -LawnGrid.DeckReach and along < length + LawnGrid.DeckReach and math.abs(across) < halfWidth then
				table.insert(found, LawnGrid.index(column, row, rows))
			end
		end
	end
	return found
end

-- The cells a round snip (a pair of shears) cuts: those whose center is within radius of the spot,
-- as indexes in ascending order.
function LawnGrid.cellsInCircle(columns: number, rows: number, x: number, z: number, radius: number): { number }
	local found = {}
	for column = math.max(0, math.floor(x - radius)), math.min(columns - 1, math.floor(x + radius)) do
		local dx = column + 0.5 - x
		for row = math.max(0, math.floor(z - radius)), math.min(rows - 1, math.floor(z + radius)) do
			local dz = row + 0.5 - z
			if dx * dx + dz * dz < radius * radius then
				table.insert(found, LawnGrid.index(column, row, rows))
			end
		end
	end
	return found
end

-- A new lawn's cells, all tall except the `blocked` ones (by index), where nothing grows.
function LawnGrid.mowableMask(columns: number, rows: number, blocked: { [number]: boolean }): { string }
	local cells = table.create(columns * rows, LawnGrid.TALL)
	for index, isBlocked in blocked do
		if isBlocked then
			cells[index] = LawnGrid.EMPTY
		end
	end
	return cells
end

-- How many cells of the string have a character that passes `counts`.
local function countCells(cells: string, counts: (string) -> boolean): number
	local total = 0
	for position = 1, #cells do
		if counts(string.sub(cells, position, position)) then
			total += 1
		end
	end
	return total
end

-- How many cells have grass on them, cut or not.
function LawnGrid.mowableCount(cells: string): number
	return countCells(cells, function(state)
		return state ~= LawnGrid.EMPTY
	end)
end

-- How many cells have been cut, cleanly or raggedly.
function LawnGrid.cutCount(cells: string): number
	return countCells(cells, function(state)
		return state == LawnGrid.MOWED or state == LawnGrid.RAGGED
	end)
end

return LawnGrid
