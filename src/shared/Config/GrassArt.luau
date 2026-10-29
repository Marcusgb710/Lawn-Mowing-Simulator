-- The grass art, for the lawn to use: the kit's lawn and soil textures and a sheet of grass tufts.
-- scripts/upload-grass-art.py uploads the four images as Image assets and writes their ids here.
-- An id of 0 isn't uploaded yet, and the lawn is drawn without that image.
--
-- Mown, Uncut and Soil are the kit's 512 x 512 tiling color maps (art-source/GUI/Source/RenderOnly/
-- Textures). Tufts is art-source/Grass/Grass_Tufts.png, drawn by scripts/make-grass-tufts.py.
--
-- This file has no Roblox requires or types, so scripts can test it with Lune.

return {
	-- Image asset ids as plain numbers: use them as "rbxassetid://" .. id.
	Mown = 0,
	Uncut = 0,
	Soil = 0,
	Tufts = 0,
	-- How many studs one repeat of the lawn and soil textures covers on the ground.
	TileStuds = 8,
	-- Tufts is a grid of square cells, `size` pixels a side, counted left to right then top to
	-- bottom from the top left. The sheet is 256 x 128, exactly the grid.
	TuftSheet = { columns = 4, rows = 2, size = 64 },
}
