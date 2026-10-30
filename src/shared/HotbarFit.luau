-- The hotbar's numbers and how it fits the screen (HotbarController draws it; scripts/check-gui
-- checks these very functions, so the game and its check can't drift apart). Plain arithmetic: no
-- services, no Instances, so Lune can load it.
--
-- A slot is a face (60 px on a PC, 48 on a touch or short screen) with its ink outline round it
-- (STROKE a side) and, under the held one, a lip (LIP): UiLayout's Hotbar is a face tall plus ROOM,
-- and the face is worked out from that height (faceFor). Slots are GAP apart. Every tool gets a slot
-- and at least MIN_SLOTS are drawn. The row is drawn smaller to stay TOUCH_SIDE px in from a touch
-- screen's sides (the move stick and the jump button) or PC_SIDE from a PC's, but never so a face is
-- under TOUCH_FLOOR px on a touch screen (PC_FLOOR elsewhere); past that floor it shows as many
-- slots as fit, the last of them a "+N" for the rest. Keys 1 to 9 and then 0 take out the first
-- KEY_COUNT tools.

local HotbarFit = {}

HotbarFit.PC_FACE = 60
HotbarFit.SMALL_FACE = 48
HotbarFit.STROKE = 4
HotbarFit.LIP = 6
HotbarFit.ROOM = HotbarFit.STROKE * 2 + HotbarFit.LIP
HotbarFit.GAP = 8
HotbarFit.MIN_SLOTS = 5
HotbarFit.KEY_COUNT = 10
HotbarFit.TOUCH_SIDE = 120
HotbarFit.PC_SIDE = 24
HotbarFit.TOUCH_FLOOR = 40
HotbarFit.PC_FLOOR = 48

-- The face a hotbar `height` px tall has room for.
function HotbarFit.faceFor(height: number): number
	return math.max(height - HotbarFit.ROOM, 1)
end

-- A slot's width and height, outline and lip included, for a face `face` px square.
function HotbarFit.cellWidth(face: number): number
	return face + HotbarFit.STROKE * 2
end
function HotbarFit.cellHeight(face: number): number
	return face + HotbarFit.ROOM
end

-- How wide `count` slots of a `face` px face are, side by side, before any scale.
function HotbarFit.rowWidth(count: number, face: number): number
	return count * HotbarFit.cellWidth(face) + math.max(count - 1, 0) * HotbarFit.GAP
end

-- How many slots are drawn for `places` places in the order (tools, and the empty place of one set
-- down to be worked on): one each, never fewer than MIN_SLOTS, never capped.
function HotbarFit.drawnCount(places: number): number
	return math.max(HotbarFit.MIN_SLOTS, places)
end

-- How a row of `count` slots of a `face` px face fits a screen `screenWidth` px wide: the scale to
-- draw it at (at most 1), how many slots show, and whether the last of those is the "+N" (the rest
-- didn't fit even at the smallest scale). A screen whose width isn't known yet (0) draws it whole.
function HotbarFit.fit(screenWidth: number, count: number, touch: boolean, face: number): (number, number, boolean)
	if screenWidth <= 0 then
		return 1, count, false
	end
	local room = screenWidth - 2 * (if touch then HotbarFit.TOUCH_SIDE else HotbarFit.PC_SIDE)
	local smallest = math.min(1, (if touch then HotbarFit.TOUCH_FLOOR else HotbarFit.PC_FLOOR) / face)
	local scale = math.min(1, room / HotbarFit.rowWidth(count, face))
	if scale >= smallest then
		return scale, count, false
	end
	-- As many as fit at the smallest scale (two at least: one tool and the "+N").
	local fits = math.floor((room / smallest + HotbarFit.GAP) / (HotbarFit.cellWidth(face) + HotbarFit.GAP))
	local shown = math.clamp(fits, 2, count)
	return smallest, shown, shown < count
end

-- The key that takes out the tool at `place` in the order: "1" to "9", then "0", none past that.
function HotbarFit.keyFor(place: number): string?
	if place < 1 or place > HotbarFit.KEY_COUNT or place ~= math.floor(place) then
		return nil
	end
	return if place == 10 then "0" else tostring(place)
end

return HotbarFit
