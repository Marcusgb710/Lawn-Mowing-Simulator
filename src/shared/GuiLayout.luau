-- The GUI's layout maths, kept apart from Roblox so scripts/check-gui.luau can test it with Lune:
--   * setting a line of text in one of the bitmap fonts (Config/GuiArt.luau's Fonts), with its
--     kerning, at a scale (BitmapText draws it);
--   * the two half-turns that sweep the hold ring round;
--   * the sizes the striped fills tile at.

local GuiLayout = {}

export type Font = {
	size: number,
	lineHeight: number,
	base: number,
	capHeight: number,
	atlas: { number },
	-- [codepoint] = { x, y, width, height, xoffset, yoffset, xadvance }
	glyphs: { [number]: { number } },
	kerning: { [number]: { [number]: number } },
}

-- One glyph placed on the line: where it goes (screen pixels from the line's top left) and where
-- it is in the atlas (atlas pixels).
export type Quad = {
	code: number,
	x: number,
	y: number,
	width: number,
	height: number,
	atlasX: number,
	atlasY: number,
	atlasWidth: number,
	atlasHeight: number,
}

export type Line = {
	quads: { Quad },
	-- From the pen's start to where the next glyph would go.
	width: number,
	-- The font's line box, and where in it the baseline and the top of the capitals are.
	height: number,
	baseline: number,
	capTop: number,
}

-- Characters a font may not have, and the one it has instead (the numbers font has a real minus
-- sign and times sign).
local STAND_INS = {
	[string.byte("-")] = 0x2212,
	[string.byte("x")] = 0xD7,
	[0x2013] = string.byte("-"), -- en dash
	[0x2019] = string.byte("'"), -- curly apostrophe
}

-- `text` as `font` can draw it (stand-ins swapped in), or nil if it has a character the font
-- hasn't got, so the caller can use a live font instead.
function GuiLayout.prepare(font: Font, text: string): string?
	if not utf8.len(text) then
		return nil
	end
	local codes = {}
	for _, code in utf8.codes(text) do
		if not font.glyphs[code] then
			local standIn = STAND_INS[code]
			if standIn and font.glyphs[standIn] then
				code = standIn
			else
				return nil
			end
		end
		table.insert(codes, code)
	end
	return utf8.char(table.unpack(codes))
end

-- Sets `text` (already through GuiLayout.prepare) on one line at `scale` screen pixels per atlas
-- pixel. Glyphs with nothing to draw (spaces) only move the pen.
function GuiLayout.text(font: Font, text: string, scale: number): Line
	local quads = {}
	local pen = 0
	local previous: number? = nil
	for _, code in utf8.codes(text) do
		local glyph = font.glyphs[code]
		if glyph then
			if previous then
				local kerns = font.kerning[previous]
				pen += if kerns then kerns[code] or 0 else 0
			end
			if glyph[3] > 1 and glyph[4] > 1 then
				table.insert(quads, {
					code = code,
					x = (pen + glyph[5]) * scale,
					y = glyph[6] * scale,
					width = glyph[3] * scale,
					height = glyph[4] * scale,
					atlasX = glyph[1],
					atlasY = glyph[2],
					atlasWidth = glyph[3],
					atlasHeight = glyph[4],
				})
			end
			pen += glyph[7]
			previous = code
		end
	end
	return {
		quads = quads,
		width = pen * scale,
		height = font.lineHeight * scale,
		baseline = font.base * scale,
		capTop = (font.base - font.capHeight) * scale,
	}
end

-- The scale that draws `font` as big as a live font at `textSize` (like TextLabel.TextSize).
function GuiLayout.scaleFor(font: Font, textSize: number): number
	return textSize / font.size
end

-- How far down to move a line so its capitals sit in the middle of a box `boxHeight` tall.
function GuiLayout.centreCaps(line: Line, boxHeight: number): number
	local capHeight = line.baseline - line.capTop
	return (boxHeight - capHeight) / 2 - line.capTop
end

-- How far right to move a line `lineWidth` wide in a box `boxWidth` wide: "Left", "Center" or
-- "Right".
function GuiLayout.align(lineWidth: number, boxWidth: number, alignment: string): number
	if alignment == "Center" then
		return (boxWidth - lineWidth) / 2
	elseif alignment == "Right" then
		return boxWidth - lineWidth
	end
	return 0
end

-- The hold ring fills clockwise from the top. It's drawn as two halves, each showing the ring
-- through a hard-edged gradient (half see-through), turned so the edge sits where the fill ends.
-- Returns the right half's and the left half's gradient rotation (degrees) for `fraction` done.
function GuiLayout.ring(fraction: number): (number, number)
	local angle = math.clamp(fraction, 0, 1) * 360
	return math.clamp(angle, 0, 180), math.clamp(angle, 180, 360)
end

-- How wide one tile of a striped fill is drawn on a bar `height` pixels tall, so its stripes keep
-- their shape (`tile` is the manifest's tile size at its own height).
function GuiLayout.tileWidth(tile: { number }, height: number): number
	return math.max(4, math.floor(tile[1] * height / tile[2] + 0.5))
end

-- The slice scale that fits a 9-slice drawn `sourceHeight` tall (at 2x) into `height` pixels, so
-- thin bars keep round ends instead of overlapping corners: never more than `scale`.
function GuiLayout.sliceScale(sourceHeight: number, height: number, scale: number): number
	return math.min(scale, height / sourceHeight)
end

return GuiLayout
