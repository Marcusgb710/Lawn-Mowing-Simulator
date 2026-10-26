-- The story's art (docs/STORY.md): portraits, the dialogue box, speech bubbles and their bits,
-- the Messages app's texts and the Best Yard results, all from the GUI art (Config/GuiArt.luau,
-- through Art). An image is "" (and a kit piece nil) until it's uploaded: then that piece is drawn
-- with plain frames instead (colors from UI.Colors, the fonts from UI.Fonts). Uploading the art
-- and filling in GuiArt's ids changes only GuiArt.
--
-- Kit pieces are Art.Slice: the image, its 9-slice centre and scale (drawn at 2x, so 0.5). Use
-- them with UI.applySlice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Story"))
local Art = require(script.Parent.Art)

local StoryArt = {}

-- Round portraits (512 x 512, the face in the middle), by Config/Story.luau's Cast key and mood:
-- Portraits.June.Smug is Portraits/June_Smug.png. Someone with one portrait (the Bridge Club, the
-- judges) has it as `default`; everyone's `default` is the mood they usually wear.
StoryArt.Portraits = {}
for key, cast in Story.Cast do
	local portraits = {}
	if cast.moods then
		for _, mood in cast.moods do
			portraits[mood] = Art.portrait(`{key}_{mood}`)
		end
		portraits.default = portraits[cast.moods[1]]
	elseif key ~= "Customer" then
		portraits.default = Art.portrait(key)
	else
		portraits.default = ""
	end
	StoryArt.Portraits[key] = portraits
end

-- Someone's portrait wearing `mood` (their usual one if they haven't got it), or "".
function StoryArt.portrait(castKey: string, mood: string?): string
	local portraits = StoryArt.Portraits[castKey]
	if not portraits then
		return ""
	end
	local image = mood and portraits[mood] or ""
	return if image ~= "" then image else portraits.default or ""
end

-- The round frame portraits sit in (256 x 256, the portrait inside its 208 x 208 circle).
StoryArt.PortraitRing = Art.kit("PortraitRing")
-- The dialogue box along the bottom of the screen, with its dark outline (9-slice).
StoryArt.DialogueBox = Art.slice("DialogueBox")
-- The straw name tag on the box's top edge (9-slice).
StoryArt.NameTag = Art.slice("NameTag")
-- A speech bubble over someone in the world, cream with a dark outline (9-slice), and the little
-- tail under it, pointing down (192 x 96).
StoryArt.Bubble = Art.slice("Bubble")
StoryArt.BubbleTail = Art.kit("BubbleTail")
-- The letterbox bars' soft inner edge (a 1 x 64 strip, stretched across; turned over for the
-- bottom bar).
StoryArt.Letterbox = Art.kit("Letterbox")
-- Glyphs (white, tinted in game): after "Click to continue" (a chevron) and after "Skip".
StoryArt.ContinueChevron = Art.icon("Continue")
StoryArt.SkipChevron = Art.icon("Skip")
-- Pictures on the card that pops up in a scene, by the card's `icon` in Story.luau.
StoryArt.CardIcons = {
	Shears = Art.item("GardenShears"),
}
-- The "New Tool!" wordmark the card shows in place of its label.
StoryArt.NewTool = Art.wordmark("NewTool")
-- The Messages app on the shop computer (MessagesController): a text from someone else and one
-- from you, a thread in the list and the open one, the goal card, the unread badge, and the toast
-- a new text pops up in (9-slices, the badge round).
StoryArt.TheirText = Art.slice("Bubble_Theirs")
StoryArt.MyText = Art.slice("Bubble_Mine")
StoryArt.ThreadCard = Art.slice("ThreadCard")
StoryArt.ThreadCardActive = Art.slice("ThreadCard_Active")
StoryArt.GoalCard = Art.slice("GoalCard")
StoryArt.Unread = Art.kit("Badge_Unread")
StoryArt.TextToast = Art.slice("Toast")
-- TurfKing: its gold `Crown` glyph and the purple-and-gold "Taken by TurfKing" rubber stamp that
-- lands on a job card it takes. The crown also sits on the faces of TurfKing's people (by Cast
-- key): in the Messages app, its toasts and the dialogue box.
StoryArt.Crown = Art.icon("Crown")
StoryArt.Crowned = { Chad = true }
StoryArt.StampTakenByTurfKing = Art.wordmark("Stamp_TakenByTurfKing")
-- The Best Yard results screen (ContestController).
StoryArt.Contest = {
	-- The "Maple Grove Best Yard" title wordmark, and the ribbon banner behind it (9-slice).
	Title = Art.wordmark("BestYard"),
	Ribbon = Art.slice("Ribbon"),
	-- The `Winner` and `SoClose` wordmarks under the trophy.
	Winner = Art.wordmark("Winner"),
	SoClose = Art.wordmark("SoClose"),
	-- The trophy (1024 x 1024, light rays and all).
	Trophy = Art.moment("Trophy"),
	-- The score bars: the track (9-slice) and each side's striped fill, by UI.bar's fill kinds.
	ScoreTrack = "ScoreTrack",
	ScoreFillYou = "You",
	ScoreFillRival = "Rival",
	-- An icon for each category (white, tinted in game), by Config/Contest.luau's ids.
	Categories = {
		Lawn = Art.icon("Score_Lawn"),
		Edges = Art.icon("Score_Edges"),
		Beds = Art.icon("Score_Beds"),
		Charm = Art.icon("Score_Decor"),
	},
}
-- Confetti over a win: a sprite sheet of `columns` x `rows` frames, each `frameSize` pixels.
local confetti, confettiImage = Art.sheet("Confetti")
StoryArt.Contest.Confetti = {
	image = confettiImage,
	columns = confetti and confetti.columns or 4,
	rows = confetti and confetti.rows or 4,
	frameSize = if confetti then Vector2.new(confetti.frameSize[1], confetti.frameSize[2]) else Vector2.new(256, 256),
}

return StoryArt
