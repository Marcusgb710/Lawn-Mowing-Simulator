-- How a lawn's grass tiles are laid out and shared between server and client.
--
-- The server decides which tiles are mowed and keeps that in a "Grass" folder inside each job
-- site, as attributes:
--   Origin    Vector3  front-left corner of the lawn
--   TileSize  number   studs per tile
--   Columns   number
--   Rows      number
--   State     string   one character per tile (see below), column by column
-- Each client draws the grass itself (see GrassController), so the server never makes grass parts.

local LawnGrid = {}

LawnGrid.TALL = "0"
LawnGrid.MOWED = "1"
-- Mowed with a dull blade: short, but torn and ragged.
LawnGrid.RAGGED = "2"
-- No grass here (a flower patch or gnome sits on this tile).
LawnGrid.EMPTY = "-"
-- Tall grass partly cut by hand (grass shears snip a tile down a bit at a time): a quarter, half
-- and three quarters of the way down.
LawnGrid.PARTLY_CUT = { "3", "4", "5" }

-- The state for tall grass `fraction` (0-1) of the way cut by hand, in quarters: tall until the
-- first quarter's done.
function LawnGrid.partlyCut(fraction: number): string
	local quarters = math.clamp(math.floor(fraction * 4), 0, 3)
	return if quarters == 0 then LawnGrid.TALL else LawnGrid.PARTLY_CUT[quarters]
end

-- How much of a tile's tall grass is still standing: 1 when it's uncut, down to 0.25 when it's
-- three quarters cut by hand. Nil when it isn't tall grass.
function LawnGrid.standing(state: string): number?
	if state == LawnGrid.TALL then
		return 1
	end
	local quarters = table.find(LawnGrid.PARTLY_CUT, state)
	return if quarters then 1 - quarters / 4 else nil
end

function LawnGrid.index(column: number, row: number, rows: number): number
	return column * rows + row + 1
end

function LawnGrid.cell(index: number, rows: number): (number, number)
	return (index - 1) // rows, (index - 1) % rows
end

-- Center of a tile, on the ground.
function LawnGrid.center(origin: Vector3, tileSize: number, column: number, row: number): Vector3
	return origin + Vector3.new(column * tileSize + tileSize / 2, 0, row * tileSize + tileSize / 2)
end

return LawnGrid
