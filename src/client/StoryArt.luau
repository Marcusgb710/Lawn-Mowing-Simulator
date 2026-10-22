-- The story's art (docs/STORY.md): portraits, the dialogue box, speech bubbles and their bits,
-- and the Messages app's texts.
-- Uploaded images as "rbxassetid://..." ids, or "" to draw that piece with plain frames instead
-- (colors from UI.Colors, the font from UI.Font). Upload as Big Dink Studios, like the title
-- card's art (src/first/TitleCardArt.luau), and only this file changes.
--
-- A 9-slice image keeps its corners and stretches its middle: `slice` is that middle as a Rect
-- in the image's pixels (Roblox's SliceCenter). Draw them at 2x and keep the corners round.

return {
	-- Round portraits: square images (256 x 256) with the face in the middle, shown in a circle.
	-- The keys are Config/Story.luau's Cast.
	Portraits = {
		June = "",
		Gloria = "",
		Chad = "",
		Sam = "",
		Edna = "",
		BridgeClub = "",
		Customer = "",
		Judge1 = "",
		Judge2 = "",
	},
	-- The dialogue box along the bottom of the screen, with its dark outline (9-slice, 128 x 128).
	DialogueBox = { image = "", slice = Rect.new(40, 40, 88, 88) },
	-- The green name tag on the box's top edge (9-slice, 64 x 64).
	NameTag = { image = "", slice = Rect.new(24, 24, 40, 40) },
	-- A speech bubble over someone in the world, white with a dark outline (9-slice, 96 x 96),
	-- and the little tail under it, pointing down (32 x 20).
	Bubble = { image = "", slice = Rect.new(32, 32, 64, 64) },
	BubbleTail = "",
	-- Chevrons (32 x 32, white, tinted in game): after "Click to continue" (pointing down) and
	-- after "Skip" (pointing right).
	ContinueChevron = "",
	SkipChevron = "",
	-- Icons on the card that pops up in a scene (64 x 64), by the card's `icon` in Story.luau.
	CardIcons = {
		Shears = "",
	},
	-- The Messages app on the shop computer (MessagesController): a text from someone else
	-- (grey) and one from you (green), as 9-slices (64 x 64), and the toast a new text pops up
	-- in (9-slice, 128 x 64).
	TheirText = { image = "", slice = Rect.new(24, 24, 40, 40) },
	MyText = { image = "", slice = Rect.new(24, 24, 40, 40) },
	TextToast = { image = "", slice = Rect.new(32, 24, 96, 40) },
	-- TurfKing (alphainstructions/instructions38.md): its gold `Crown` glyph (128 x 128, white,
	-- tinted in game) and the purple-and-gold "Taken by TurfKing" rubber stamp that lands on a job
	-- card it takes (`Stamp_TakenByTurfKing`, a wordmark, up to 1024 wide, about 3:1).
	Crown = "",
	StampTakenByTurfKing = "",
	-- The Best Yard results screen (ContestController), named as in instructions38.
	Contest = {
		-- The "Maple Grove Best Yard" title wordmark (`BestYard`, up to 1024 wide, about 10:1), and
		-- the ribbon banner behind it (`Ribbon`, a 9-slice, 256 x 64).
		Title = "",
		Ribbon = { image = "", slice = Rect.new(48, 16, 208, 48) },
		-- The `Winner` and `SoClose` wordmarks under the trophy (about 6:1).
		Winner = "",
		SoClose = "",
		-- The trophy (`Moments/Trophy.png`, 1024 x 1024, light rays and all).
		Trophy = "",
		-- The score bars: the track and each side's fill (9-slices, 64 x 32): `ScoreTrack`,
		-- `ScoreFill_You` (green) and `ScoreFill_Rival` (purple).
		ScoreTrack = { image = "", slice = Rect.new(16, 8, 48, 24) },
		ScoreFillYou = { image = "", slice = Rect.new(16, 8, 48, 24) },
		ScoreFillRival = { image = "", slice = Rect.new(16, 8, 48, 24) },
		-- An icon for each category (128 x 128, white, tinted in game), by Config/Contest.luau's
		-- ids: `Score_Lawn`, `Score_Edges`, `Score_Beds` and `Score_Decor`.
		Categories = { Lawn = "", Edges = "", Beds = "", Charm = "" },
		-- Confetti over a win: a sprite sheet of `columns` x `rows` frames (`Moments/Confetti.png`,
		-- 1024 x 1024).
		Confetti = { image = "", columns = 4, rows = 4 },
	},
}
