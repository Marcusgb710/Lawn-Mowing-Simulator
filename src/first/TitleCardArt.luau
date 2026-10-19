-- The title card's art (see LoadingScreen, the script this sits in). Uploaded images as
-- "rbxassetid://..." ids, or "" to draw that piece instead. The art is made from
-- alphainstructions/instructions35.md and uploaded as Big Dink Studios.

return {
	-- The game's logo, on a transparent background (1024 x 512).
	Logo = "",
	-- The key art behind everything, as four 1024 x 576 tiles of one 2048 x 1152 picture, left to
	-- right and top to bottom: { top left, top right, bottom left, bottom right }.
	Background = { "", "", "", "" },
	-- A push mower seen from the side (512 x 512), rolling along the loading bar.
	Mower = "",
	-- A tile of mown stripes (256 x 64) that fills the loading bar.
	Stripes = "",
}
