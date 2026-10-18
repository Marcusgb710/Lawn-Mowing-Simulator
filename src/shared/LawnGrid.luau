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
-- No grass here (a flower patch or gnome sits on this tile).
LawnGrid.EMPTY = "-"

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
