-- The GUI art (Config/GuiArt.luau) by name, for UI.luau, BitmapText and the controllers. Each
-- lookup gives an "rbxassetid://..." id, or "" while that image isn't uploaded: then whoever asked
-- draws that piece with plain frames instead, as the game always has. Filling in GuiArt's ids
-- (scripts/gui-art-ids.py) is all it takes to switch a piece over.
--
-- The names are the files' names in art-source/GUI: Art.icon("Money") is Icons/Money.png.
-- scripts/check-gui.luau checks every name asked for like that is a real image.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GuiArt"))

local Art = {}

-- The built-in font families picked for live text ("DenkOne", "Nunito") and the display face.
Art.typography = GuiArt.Typography

export type Slice = {
	image: string,
	-- The middle that stretches (Roblox's SliceCenter), and how big the corners draw (SliceScale):
	-- the kit is drawn at 2x, so 0.5.
	center: Rect?,
	scale: number,
	-- The source image's size, in pixels.
	size: Vector2,
	-- Striped fills: one tile's size at its own height, in screen pixels.
	tile: { number }?,
	-- Room to leave inside it for its content (left, top, right, bottom), in screen pixels.
	inset: { number },
}

local function image(path: string): string
	return GuiArt.Images[path] or ""
end

-- Any image by its path in art-source/GUI.
Art.image = image

-- Whether an image is uploaded (its id isn't "").
function Art.has(id: string?): boolean
	return id ~= nil and id ~= ""
end

-- A white glyph (128 x 128) to tint: Icons/<name>.png.
function Art.icon(name: string): string
	return image(`Icons/{name}.png`)
end

-- A kit piece: Kit/<name>.png.
function Art.kit(name: string): string
	return image(`Kit/{name}.png`)
end

-- An item's picture (512 x 512), named by its id: Items/<id>.png. Premium tools and truck paints
-- have their own.
function Art.item(id: string): string
	return image(`Items/{id}.png`)
end

-- A painted portrait (512 x 512): Portraits/<name>.png, e.g. "June_Smug".
function Art.portrait(name: string): string
	return image(`Portraits/{name}.png`)
end

-- A finished word in the display font: Wordmarks/<name>.png, e.g. "JobComplete".
function Art.wordmark(name: string): string
	return image(`Wordmarks/{name}.png`)
end

-- The shop computer's wallpaper, app icons and taskbar: Computer/<name>.png.
function Art.computer(name: string): string
	return image(`Computer/{name}.png`)
end

-- The trophy, confetti and sparkle: Moments/<name>.png.
function Art.moment(name: string): string
	return image(`Moments/{name}.png`)
end

-- Store art: game pass circles (Store/Pass_<id>.png) and product pictures.
function Art.store(name: string): string
	return image(`Store/{name}.png`)
end

-- An image's width over its height, to size it without stretching.
function Art.aspect(path: string): number
	local size = GuiArt.Sizes[path]
	return if size and size[2] > 0 then size[1] / size[2] else 1
end

local slices: { [string]: Slice } = {}
-- A kit piece with how to draw it (Config/GuiArt.luau's Slices): its 9-slice centre and scale, or
-- nil while it isn't uploaded.
function Art.slice(name: string): Slice?
	local info = GuiArt.Slices[name]
	local id = info and image(info.file) or ""
	if id == "" then
		return nil
	end
	local cached = slices[name]
	if cached then
		return cached
	end
	local scale = info.scale or 1
	local inset = info.inset or { 0, 0, 0, 0 }
	local slice: Slice = {
		image = id,
		center = if info.center then Rect.new(info.center[1], info.center[2], info.center[3], info.center[4]) else nil,
		scale = scale,
		size = Vector2.new(info.size[1], info.size[2]),
		tile = info.tile,
		inset = { inset[1] * scale, inset[2] * scale, inset[3] * scale, inset[4] * scale },
	}
	slices[name] = slice
	return slice
end

-- A palette colour by its role in the manifest ("ink", "money"...).
function Art.color(role: string): Color3
	local hex = GuiArt.Palette[role]
	return if hex then Color3.fromHex(hex) else Color3.new(1, 0, 1)
end

-- A bitmap font's metrics (GuiArt.Fonts), and whether both its atlases are uploaded.
function Art.font(name: string)
	local font = GuiArt.Fonts[name]
	if not font then
		return nil, false
	end
	return font, image(font.face) ~= "" and image(font.outline) ~= ""
end

-- A sprite sheet's layout and image ("Confetti", "Sparkle").
function Art.sheet(name: string)
	local sheet = GuiArt.SpriteSheets[name]
	return sheet, if sheet then image(sheet.file) else ""
end

-- Where a portrait sits inside the portrait ring, as fractions of the ring's size.
function Art.portraitInset(): (number, number)
	local mask = GuiArt.PortraitMask
	return mask.offset[1] / mask.frame[1], mask.inner[1] / mask.frame[1]
end

return Art
