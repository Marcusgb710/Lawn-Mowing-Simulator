-- The painting behind GrassController's lawns: the brushes and grass tiles, and what the ledger,
-- each swath and each regrown cell do to a lawn's pictures.
--
-- A drawn lawn has a turf image (the ground's colour and the stripes) and a few shell images of
-- blade dots (see GrassImages). Each shell is tiled from its own grass tile, made once a session and
-- shared by every lawn, and grass grows back from it too. These take GrassController's lawn record
-- and use its turf, shells, pps (pixels per stud), columns, rows and regrows, and keep its `cells`:
-- the lawn's ledger as this client has it (one state per cell, see LawnGrid), so a swath never
-- paints over what the server says a cell is. Everything is in lawn-local studs, which are cells
-- too, and a picture's X and Y are the lawn's X and Z (GrassImages.worldToPixel).
--
-- Given the lawn art (GrassArt) the pictures hold other things. The turf image is painted over a
-- tiling texture on its part: uncut grass is an opaque mottle sampled from the uncut texture, and
-- mown grass a see-through tint of its shade, so the mown texture shows through. A shell's blades
-- are tufts from the tuft sheet, shaded darker the lower the shell. Without the art (an image is
-- missing or won't load) it paints the flat colours and dots it always did. load finds out which, once
-- a session, and says so when it's the flat one.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local GrassArt = require(Shared.Config.GrassArt)
local GrassImages = require(Shared.GrassImages)
local LawnGrid = require(Shared.LawnGrid)
local Swath = require(Shared.Swath)

-- The stamps are this many pixels a side.
local BRUSH_SIZE = 16
-- The grass tiles are this many: a multiple of every pixels-per-stud, so a cell never straddles two.
local TILE = 256
-- A dull blade's torn cut keeps every other square of this many pixels standing.
local RAGGED_BLOCK = 2
-- The uncut mottle is this many pixels a side, repeated across the turf: a multiple of every
-- pixels-per-stud too.
local MOTTLE = 64
-- load waits this many seconds, in all, for the lawn art before painting flat colours instead.
local LOAD_SECONDS = 10

-- What load found: the pixels the textured brushes are made from, as RGBA bytes. The mottle is
-- MOTTLE pixels a side and each tuft GrassArt.TuftSheet.size, in the order GrassImages.tuftFor counts.
type Art = { mottle: buffer, tufts: { buffer } }

-- Said once, when the lawn is painted without the art.
local UNAVAILABLE = "GrassPaint: lawn textures unavailable, painting flat colours"

local OVERWRITE = Enum.ImageCombineType.Overwrite
local BLEND = Enum.ImageCombineType.BlendSourceOver
-- Stamps into a flat turf blend, so a stamp's soft edges don't leave see-through pixels. Over the
-- texture a stamp is see-through on purpose, and writes over what's there (TINT), so one painted
-- twice leaves the same pixels. The eraser writes clear pixels into the shells.
local STAMP = { CombineType = BLEND }
local TINT = { CombineType = OVERWRITE }
local ERASE = { CombineType = OVERWRITE }

local WHITE = Color3.new(1, 1, 1)

local function darken(color: Color3, fraction: number): Color3
	return Color3.new(color.R * (1 - fraction), color.G * (1 - fraction), color.B * (1 - fraction))
end

-- Swath's shade colours, as Color3s.
local SHADES: { [string]: Color3 } = {}
for shade, rgb in Swath.Colors do
	SHADES[shade] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
-- The turf under uncut grass: a deep olive, well apart from every mown shade (Swath.Colors run from
-- 90,168,58 to 134,212,87), so what's still to cut reads at a glance. It was the flat shade a little
-- darker, which players couldn't tell from a mown stripe.
local UNCUT = Color3.fromRGB(80, 122, 44)
-- Cells with no grass (flower patches, tree rings): bare ground.
local GROUND = Color3.fromRGB(92, 68, 46)
-- The turf under each kind of cell the ledger has.
local CELL_COLORS = {
	[LawnGrid.TALL] = UNCUT,
	[LawnGrid.MOWED] = SHADES.Flat,
	[LawnGrid.RAGGED] = SHADES[Swath.RAGGED],
	[LawnGrid.EMPTY] = GROUND,
}
-- The blades' two greens: each dot falls between them by its tone, and higher shells lean lighter.
-- Blades only stand on uncut grass, so both stay darker than the darkest mown stripe.
local BLADE_DARK = Color3.fromRGB(50, 88, 30)
local BLADE_LIGHT = Color3.fromRGB(86, 132, 46)
-- Over the lawn art a shell's finished tile is shaded by its height: the lowest shell shows this much
-- of its brightness and the highest all of it, so the lower shells read darker as BLADE_DARK to
-- BLADE_LIGHT makes the flat dots.
local SHELL_SHADE_LOW = 0.7
-- Wheel tracks are this much darker than the stripe, this many pixels in from its long edges.
local TRACK_DARKEN = 0.1
local TRACK_INSET = 1
-- Over the lawn texture a mown stripe is a tint: this much of its colour shows (1 is solid) for the
-- light shades, and a little more for the dark one. Wheel tracks show this much.
local TINT_LIGHT = 0.35
local TINT_DARK = 0.45
local TRACK_OPACITY = 0.45
-- A cell's corner is this far from its centre (studs).
local HALF_DIAGONAL = math.sqrt(0.5)

-- How much of a shade's colour shows over the lawn texture. A shade that's neither light nor dark
-- counts as light.
local function opacity(shade: string): number
	return if shade == "Dark" then TINT_DARK else TINT_LIGHT
end

local GrassPaint = {}

GrassPaint.UNCUT = UNCUT

-- Made the first time a lawn is drawn (see prepare): a stamp per shade, the eraser and, with the
-- lawn art, the mottle and the tufts, and a grass tile per shell.
local brushes = nil
local tiles = nil
-- The lawn art's pixels, once load has found them: nil until then, and when it can't be had.
local art: Art? = nil
local started, loaded = false, false

-- A blank EditableImage, or nil when one can't be made: the API is off in this game (that throws)
-- or the device's memory budget is spent (that returns nil).
function GrassPaint.newImage(size: Vector2): EditableImage?
	local ok, image = pcall(AssetService.CreateEditableImage, AssetService, { Size = size })
	return if ok and image then image else nil
end

-- Reads the lawn art's pixels, or gives nil, with nothing left behind, when any of it can't be had:
-- an id that isn't uploaded yet (0), an image that won't load or is too small, or the API being off
-- or the memory budget spent. Then it also says why, for the first of those that went wrong, unless
-- it's the ids. The mown texture is only checked here (it's the part's own Texture); the mottle is the
-- corner of the uncut texture, and each tuft a cell of the sheet. It loads the images one after
-- another, and gives up between them once `abandoned` says load has stopped waiting.
local function readArt(abandoned: () -> boolean): (Art?, string?)
	local images: { EditableImage } = {}
	local found: Art? = nil
	local reason: string? = nil
	local ok, problem = pcall(function()
		local ids = { GrassArt.Mown, GrassArt.Uncut, GrassArt.Tufts }
		for _, id in ids do
			if id <= 0 then
				return
			end
		end
		for _, id in ids do
			-- This yields, and throws when the image won't load; it returns nil with no memory to spare.
			local image = AssetService:CreateEditableImageAsync(Content.fromAssetId(id))
			if not image then
				reason = "no EditableImage: is the memory budget spent?"
				return
			end
			table.insert(images, image)
			if abandoned() then
				return
			end
		end
		local uncut, sheet = images[2], images[3]
		local columns, rows, cell = GrassArt.TuftSheet.columns, GrassArt.TuftSheet.rows, GrassArt.TuftSheet.size
		if uncut.Size.X < MOTTLE or uncut.Size.Y < MOTTLE then
			reason = "the uncut texture is smaller than the mottle"
			return
		end
		if sheet.Size.X < columns * cell or sheet.Size.Y < rows * cell then
			reason = "the tuft sheet is smaller than its grid"
			return
		end

		local mottle = uncut:ReadPixelsBuffer(Vector2.zero, Vector2.new(MOTTLE, MOTTLE))
		-- Uncut grass is solid, whatever the texture says: nothing shows through it.
		for offset = 3, buffer.len(mottle) - 1, 4 do
			buffer.writeu8(mottle, offset, 255)
		end
		local tufts = {}
		for index = 1, GrassImages.TUFTS do
			local column, row = (index - 1) % columns, (index - 1) // columns
			tufts[index] = sheet:ReadPixelsBuffer(Vector2.new(column * cell, row * cell), Vector2.new(cell, cell))
		end
		found = { mottle = mottle, tufts = tufts }
	end)
	if not ok then
		reason = tostring(problem)
	end
	for _, image in images do
		image:Destroy()
	end
	return found, reason
end

-- Finds out, once a session, whether the lawns can be painted over the lawn art, and says so (once)
-- when they can't. It waits on the asset loads, so GrassController holds its lawns until it's done,
-- but only for LOAD_SECONDS: then the lawns are flat, and the art, when it does come in, is dropped.
function GrassPaint.load()
	if started then
		return
	end
	started = true
	local finished, gaveUp = false, false
	local found: Art?, why: string? = nil, nil
	task.spawn(function()
		local ok, result, reason = pcall(readArt, function()
			return gaveUp
		end)
		if gaveUp then
			-- Too late: readArt has destroyed what it loaded, and the lawns are already flat.
			return
		end
		if ok then
			found, why = result, reason
		else
			why = tostring(result)
		end
		finished = true
	end)
	local deadline = os.clock() + LOAD_SECONDS
	while not finished and os.clock() < deadline do
		task.wait()
	end
	if finished then
		art = found
		if not art then
			warn(if why then `{UNAVAILABLE} ({why})` else UNAVAILABLE)
		end
	else
		gaveUp = true
		warn(`{UNAVAILABLE} (timed out)`)
	end
	loaded = true
end

-- Whether load has finished.
function GrassPaint.loaded(): boolean
	return loaded
end

-- Whether lawns are painted over the lawn art: settled once prepare has run, and false before.
function GrassPaint.textured(): boolean
	return brushes ~= nil and brushes.mottle ~= nil
end

-- Shades a finished tile by its shell's `lift`, 0 for the lowest shell and 1 for the highest, the
-- same lift that leans the flat dots lighter (see drawTile): red, green and blue are scaled by a
-- factor from SHELL_SHADE_LOW up to 1, and alpha is left alone.
local function shadeTile(tile: EditableImage, lift: number)
	local factor = SHELL_SHADE_LOW + (1 - SHELL_SHADE_LOW) * lift
	local size = tile.Size
	local pixels = tile:ReadPixelsBuffer(Vector2.zero, size)
	for offset = 0, buffer.len(pixels) - 4, 4 do
		for channel = offset, offset + 2 do
			buffer.writeu8(pixels, channel, math.floor(buffer.readu8(pixels, channel) * factor + 0.5))
		end
	end
	tile:WritePixelsBuffer(Vector2.zero, size, pixels)
end

-- A shell's grass tile: its blade dots (the same on every client), with each dot that runs over an
-- edge drawn again past the opposite one, so tiles laid side by side meet without a seam. With
-- `tufts` a dot is the tuft GrassImages.tuftFor picks, a stud across, and not a coloured circle, and
-- the finished tile is shaded by its shell's height (shadeTile).
local WRAPS = { -TILE, 0, TILE }
local function drawTile(tile: EditableImage, plan: { GrassImages.Shell }, index: number, tufts: { EditableImage }?)
	local lift = if #plan > 1 then (index - 1) / (#plan - 1) else 0
	-- A tuft is the sheet's cell shrunk to a stud across, and reaches half that from its dot.
	local tuftScale = Vector2.one * (GameConfig.PixelsPerStud / GrassArt.TuftSheet.size)
	local tuftReach = GameConfig.PixelsPerStud / 2
	for _, dot in GrassImages.bladeDots(TILE, TILE, plan[index].density, index) do
		local color = BLADE_DARK:Lerp(BLADE_LIGHT, (dot.tone + lift) / 2)
		local reach = if tufts then tuftReach else dot.r
		for _, offsetX in WRAPS do
			local x = dot.x + offsetX
			if x + reach > 0 and x - reach < TILE then
				for _, offsetY in WRAPS do
					local y = dot.y + offsetY
					if y + reach > 0 and y - reach < TILE then
						if tufts then
							local tuft = tufts[GrassImages.tuftFor(dot)]
							tile:DrawImageTransformed(Vector2.new(x, y), tuftScale, 0, tuft, STAMP)
						else
							tile:DrawCircle(Vector2.new(x, y), dot.r, color, 0, BLEND)
						end
					end
				end
			end
		end
	end
	if tufts then
		shadeTile(tile, lift)
	end
end

-- Makes the session's brushes and grass tiles (one per shell of `plan`, the shells'
-- GrassImages.shellPlan: a session's shell count never changes) from the lawn art `from`, or as flat
-- colours when that's nil. A stamp per shade paints a stripe into the turf (DrawImageTransformed
-- takes no colour, so each shade gets its own) and the eraser clears a shell. They're kept only when
-- every one is made: otherwise it gives false, and why, with nothing left behind.
local function makeBrushes(plan: { GrassImages.Shell }, from: Art?): (boolean, string?)
	local made, failed = {}, false
	local function create(size: Vector2): EditableImage
		local image = GrassPaint.newImage(size)
		if image then
			table.insert(made, image)
		else
			failed = true
		end
		return image :: EditableImage
	end
	local brushSize = Vector2.new(BRUSH_SIZE, BRUSH_SIZE)
	local mottleSize = Vector2.new(MOTTLE, MOTTLE)
	local tuftSize = Vector2.new(GrassArt.TuftSheet.size, GrassArt.TuftSheet.size)
	local solid = {}
	for shade in SHADES do
		solid[shade] = create(brushSize)
	end
	local eraser = create(brushSize)
	local mottle: EditableImage? = nil
	local tufts: { EditableImage }? = nil
	if from then
		mottle = create(mottleSize)
		tufts = {}
		for _ = 1, GrassImages.TUFTS do
			table.insert(tufts, create(tuftSize))
		end
	end
	local grass = {}
	for index = 1, #plan do
		grass[index] = create(Vector2.new(TILE, TILE))
	end

	local ok, problem = false, "no EditableImage: is the memory budget spent?"
	if not failed then
		ok, problem = pcall(function()
			for shade, brush in solid do
				-- Over the texture a stamp is a tint, with only some of its colour showing.
				local transparency = if from then 1 - opacity(shade) else 0
				brush:DrawRectangle(Vector2.zero, brushSize, SHADES[shade], transparency, OVERWRITE)
			end
			-- Clear white, so the shells' cut edges never filter towards black.
			eraser:DrawRectangle(Vector2.zero, brushSize, WHITE, 1, OVERWRITE)
			if from and mottle and tufts then
				mottle:WritePixelsBuffer(Vector2.zero, mottleSize, from.mottle)
				for index, tuft in tufts do
					tuft:WritePixelsBuffer(Vector2.zero, tuftSize, from.tufts[index])
				end
			end
			for index, tile in grass do
				drawTile(tile, plan, index, tufts)
			end
		end)
	end
	if not ok then
		for _, image in made do
			image:Destroy()
		end
		return false, problem
	end
	brushes = { solid = solid, eraser = eraser, mottle = mottle, tufts = tufts }
	tiles = grass
	return true, nil
end

-- Makes the session's brushes and grass tiles once (see makeBrushes), after load has finished: from
-- the lawn art if there is any. If they can't be made from it they're made as flat colours instead,
-- with the same warning as load's. False when even those can't be made.
function GrassPaint.prepare(plan: { GrassImages.Shell }): boolean
	if brushes then
		return true
	end
	if not loaded then
		error("GrassPaint.prepare ran before GrassPaint.load finished")
	end
	if art then
		local ok, problem = makeBrushes(plan, art)
		if ok then
			return true
		end
		art = nil
		warn(`{UNAVAILABLE} ({problem})`)
	end
	return (makeBrushes(plan, nil))
end

-- Tiles `image` from its corner with `tile`, a square of `size` pixels. DrawImage takes a tile
-- hanging over the canvas's edge and draws the part inside.
local function tileOver(image: EditableImage, tile: EditableImage, size: number)
	local extent = image.Size
	for y = 0, extent.Y - 1, size do
		for x = 0, extent.X - 1, size do
			image:DrawImage(Vector2.new(x, y), tile, OVERWRITE)
		end
	end
end

-- Puts a lawn back to all tall: every cell tall in the ledger, every shell tiled with its grass and
-- the turf uncut (the mottle, tiled, over the texture).
function GrassPaint.reset(lawn)
	for index, shell in lawn.shells do
		tileOver(shell, tiles[index], TILE)
	end
	if brushes.mottle then
		tileOver(lawn.turf, brushes.mottle, MOTTLE)
	else
		lawn.turf:DrawRectangle(Vector2.zero, lawn.turf.Size, UNCUT, 0, OVERWRITE)
	end
	lawn.cells = table.create(lawn.columns * lawn.rows, LawnGrid.TALL)
end

-- A dull blade's torn cut on pixels read from (left, top) of a shell: where every other
-- RAGGED_BLOCK square falls (counted from the image's corner, so cuts that overlap agree) the grass
-- goes, and the rest stands as tufts.
local function tear(pixels: buffer, left: number, top: number, width: number, height: number)
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			if ((left + x) // RAGGED_BLOCK + (top + y) // RAGGED_BLOCK) % 2 == 0 then
				buffer.writeu8(pixels, (y * width + x) * 4 + 3, 0)
			end
		end
	end
end

-- Gives a rectangle of an image its grass back from `tile`, a square of `tileSize` pixels (a shell's
-- grass tile, or the turf's mottle), torn when `torn`. The tile repeats from the image's corner, so
-- a pixel's grass is at (x mod tileSize, y mod tileSize); a run of cells can cross from one tile
-- into the next, so it goes a tile at a time.
local function regrass(
	image: EditableImage,
	tile: EditableImage,
	tileSize: number,
	position: Vector2,
	size: Vector2,
	torn: boolean
)
	local right, bottom = position.X + size.X, position.Y + size.Y
	local y = position.Y
	while y < bottom do
		local height = math.min(tileSize - y % tileSize, bottom - y)
		local x = position.X
		while x < right do
			local width = math.min(tileSize - x % tileSize, right - x)
			local pixels = tile:ReadPixelsBuffer(Vector2.new(x % tileSize, y % tileSize), Vector2.new(width, height))
			if torn then
				tear(pixels, x, y, width, height)
			end
			image:WritePixelsBuffer(Vector2.new(x, y), Vector2.new(width, height), pixels)
			x += width
		end
		y += height
	end
end

-- Paints the turf under a rectangle of cells that are all in one state. Flat, it takes the state's
-- colour. Over the lawn texture, uncut grass is the mottle (solid), bare ground is solid, and a cut
-- cell is a tint of its colour that lets the texture show through.
local function paintTurf(lawn, position: Vector2, size: Vector2, state: string)
	local turf = lawn.turf
	if not brushes.mottle then
		turf:DrawRectangle(position, size, CELL_COLORS[state], 0, OVERWRITE)
	elseif state == LawnGrid.TALL then
		regrass(turf, brushes.mottle, MOTTLE, position, size, false)
	elseif state == LawnGrid.EMPTY then
		turf:DrawRectangle(position, size, GROUND, 0, OVERWRITE)
	else
		-- Mowed or ragged: neither is a dark stripe, so it shows as much as a light one.
		turf:DrawRectangle(position, size, CELL_COLORS[state], 1 - TINT_LIGHT, OVERWRITE)
	end
end

-- Draws a rectangle of cells that are all in one state the way the ledger has it: tall and ragged
-- grass comes back from the tiles (torn when ragged), cut and empty cells have none, and the turf
-- takes the state's colour.
local function drawArea(lawn, position: Vector2, size: Vector2, state: string)
	paintTurf(lawn, position, size, state)
	local grows = state == LawnGrid.TALL or state == LawnGrid.RAGGED
	for index, shell in lawn.shells do
		if grows then
			regrass(shell, tiles[index], TILE, position, size, state == LawnGrid.RAGGED)
		else
			shell:DrawRectangle(position, size, WHITE, 1, OVERWRITE)
		end
	end
end

local function drawCell(lawn, index: number, state: string)
	local column, row = LawnGrid.cell(index, lawn.rows)
	local pps = lawn.pps
	drawArea(lawn, Vector2.new(column * pps, row * pps), Vector2.new(pps, pps), state)
end

-- Draws every cell whose state is in `states` the way the ledger has it. Cells are counted column
-- by column, so it goes a column at a time in runs of one state.
local function drawCells(lawn, states: { [string]: boolean })
	local cells, rows, pps = lawn.cells, lawn.rows, lawn.pps
	for column = 0, lawn.columns - 1 do
		local base = column * rows
		local row = 0
		while row < rows do
			local state = cells[base + row + 1]
			local first = row
			repeat
				row += 1
			until row >= rows or cells[base + row + 1] ~= state
			if states[state] then
				drawArea(lawn, Vector2.new(column * pps, first * pps), Vector2.new(pps, (row - first) * pps), state)
			end
		end
	end
end

-- The cells a swath cut, by the server's own geometry.
local function cutCells(lawn, segment: Swath.Segment): { number }
	if segment.radius then
		return LawnGrid.cellsInCircle(lawn.columns, lawn.rows, segment.fromX, segment.fromZ, segment.radius)
	end
	return LawnGrid.cellsUnderSweep(
		lawn.columns,
		lawn.rows,
		segment.fromX,
		segment.fromZ,
		segment.toX,
		segment.toZ,
		segment.halfWidth
	)
end

-- GrassController tells your own mower's paint from the server's by the cells a segment cuts: the
-- ledger changes those and no others, so they are what the server confirms. A stamp's soft edge
-- on the cells around them is left to stand, as it is for the server's own swaths.
GrassPaint.cutCells = cutCells

-- Where a sweep's stripe lies: its middle, the way it went, and half its length and width (studs).
-- One that barely moved stood still, facing +Z with no length, as the server has it, so it paints
-- the deck's own rectangle along +Z. Either way the cut reaches DeckReach past both ends (see
-- LawnGrid.cellsUnderSweep).
local function stripe(segment: Swath.Segment): (number, number, number, number, number, number)
	local alongX, alongZ, length = LawnGrid.heading(segment.fromX, segment.fromZ, segment.toX, segment.toZ)
	local middleX, middleZ = (segment.fromX + segment.toX) / 2, (segment.fromZ + segment.toZ) / 2
	return middleX, middleZ, alongX, alongZ, length / 2 + LawnGrid.DeckReach, segment.halfWidth
end

-- Every cell a clean swath's stamp may paint on, generously: each whose centre is within half a
-- cell's diagonal (and a pixel of soft edge) of the stripe or the snip.
local function touched(lawn, segment: Swath.Segment): { number }
	local margin = HALF_DIAGONAL + 1 / lawn.pps
	local found = {}
	local function scan(minX: number, maxX: number, minZ: number, maxZ: number, near: (number, number) -> boolean)
		for column = math.max(0, math.floor(minX)), math.min(lawn.columns - 1, math.floor(maxX)) do
			for row = math.max(0, math.floor(minZ)), math.min(lawn.rows - 1, math.floor(maxZ)) do
				if near(column + 0.5, row + 0.5) then
					table.insert(found, LawnGrid.index(column, row, lawn.rows))
				end
			end
		end
	end
	if segment.radius then
		local x, z, reach = segment.fromX, segment.fromZ, segment.radius + margin
		scan(x - reach, x + reach, z - reach, z + reach, function(cellX, cellZ)
			return (cellX - x) ^ 2 + (cellZ - z) ^ 2 < reach * reach
		end)
		return found
	end
	local middleX, middleZ, alongX, alongZ, halfLength, halfWidth = stripe(segment)
	halfLength += margin
	halfWidth += margin
	local extentX = math.abs(alongX) * halfLength + math.abs(alongZ) * halfWidth
	local extentZ = math.abs(alongZ) * halfLength + math.abs(alongX) * halfWidth
	scan(middleX - extentX, middleX + extentX, middleZ - extentZ, middleZ + extentZ, function(cellX, cellZ)
		local dx, dz = cellX - middleX, cellZ - middleZ
		return math.abs(dx * alongX + dz * alongZ) < halfLength and math.abs(dz * alongX - dx * alongZ) < halfWidth
	end)
	return found
end

-- A clean swath's stamp: its stripe into the turf, with wheel tracks, and its shape out of every
-- shell. A snip is a round patch. Over the lawn texture the stripe and tracks are tints written over
-- the turf's pixels, so the texture shows through them (see TINT).
local function stamp(lawn, segment: Swath.Segment)
	local pps = lawn.pps
	local turf = lawn.turf
	local color = SHADES[segment.shade] or SHADES.Flat
	local textured = brushes.mottle ~= nil
	local combine = if textured then OVERWRITE else BLEND
	local transparency = if textured then 1 - opacity(segment.shade) else 0
	local function pixel(x: number, z: number): Vector2
		return Vector2.new(GrassImages.worldToPixel(0, 0, pps, x, z))
	end

	if segment.radius then
		local center, radius = pixel(segment.fromX, segment.fromZ), segment.radius * pps
		turf:DrawCircle(center, radius, color, transparency, combine)
		for _, shell in lawn.shells do
			shell:DrawCircle(center, radius, WHITE, 1, OVERWRITE)
		end
		return
	end
	if segment.halfWidth <= 0 then
		return
	end

	local middleX, middleZ, alongX, alongZ, halfLength, halfWidth = stripe(segment)
	local center = pixel(middleX, middleZ)
	local scale = Vector2.new(2 * halfLength * pps / BRUSH_SIZE, 2 * halfWidth * pps / BRUSH_SIZE)
	-- Image X and Y are lawn X and Z, so the angle on the lawn is the angle in the picture.
	local angle = math.deg(math.atan2(alongZ, alongX))
	local brush = brushes.solid[segment.shade] or brushes.solid.Flat
	turf:DrawImageTransformed(center, scale, angle, brush, if textured then TINT else STAMP)

	local track = darken(color, TRACK_DARKEN)
	local trackTransparency = if textured then 1 - TRACK_OPACITY else 0
	local edge = halfWidth - TRACK_INSET / pps
	-- DrawLine wants both ends inside the picture, and a deck sweeps in from outside the lawn, so each
	-- track is clipped to it first, a pixel in from the far edges so rounding can't push an end out.
	local lastX, lastY = turf.Size.X - 1, turf.Size.Y - 1
	for _, side in { -edge, edge } do
		local offsetX, offsetZ = -alongZ * side, alongX * side
		local startPixel = pixel(middleX - alongX * halfLength + offsetX, middleZ - alongZ * halfLength + offsetZ)
		local endPixel = pixel(middleX + alongX * halfLength + offsetX, middleZ + alongZ * halfLength + offsetZ)
		local fromX, fromY, toX, toY =
			GrassImages.clipLine(startPixel.X, startPixel.Y, endPixel.X, endPixel.Y, lastX, lastY)
		if fromX and fromY and toX and toY then
			turf:DrawLine(Vector2.new(fromX, fromY), Vector2.new(toX, toY), track, trackTransparency, combine)
		end
	end

	for _, shell in lawn.shells do
		shell:DrawImageTransformed(center, scale, angle, brushes.eraser, ERASE)
	end
end

-- Paints a swath, keeping to the ledger. A clean cut stamps its smooth stripe, then puts back the
-- cells under it that the server didn't cut clean: empty ground stays bare and ragged grass stays
-- ragged. A dull blade's cut (a sweep or a snip) tears exactly the cells it cut, cell by cell,
-- since a stretched stamp would blur its tufts and overlapping ones would wear them away; its
-- edges follow the cells. `confirmed` is the server's own swath, which the ledger takes in; your
-- own mower's paint ahead of it (GrassController.paintSweep) leaves the ledger alone.
function GrassPaint.paintSwath(lawn, segment: Swath.Segment, confirmed: boolean)
	local cells = lawn.cells
	if segment.ragged then
		for _, index in cutCells(lawn, segment) do
			local state = cells[index]
			if state == LawnGrid.TALL or state == LawnGrid.RAGGED then
				if confirmed then
					cells[index] = LawnGrid.RAGGED
				end
				drawCell(lawn, index, LawnGrid.RAGGED)
			end
		end
		return
	end

	stamp(lawn, segment)
	if confirmed then
		for _, index in cutCells(lawn, segment) do
			if cells[index] == LawnGrid.TALL then
				cells[index] = LawnGrid.MOWED
			end
		end
	end
	for _, index in touched(lawn, segment) do
		local state = cells[index]
		if state == LawnGrid.EMPTY or state == LawnGrid.RAGGED then
			drawCell(lawn, index, state)
		end
	end
end

-- Draws a lawn afresh from what GetSwaths sent: the ledger (one character per cell) and the swath
-- log. The ledger is the truth for every cell: the mown cells go first, the log's clean cuts are
-- stamped over them for the stripes and smooth edges, and then the cells a stamp mustn't change
-- (empty and ragged) are drawn over those. A home lawn's log keeps swaths over grass that has grown
-- back since, so there every cell the ledger says is tall grows back, a column's run at a time.
function GrassPaint.redraw(lawn, cells: string, log: { { number | string | boolean } })
	GrassPaint.reset(lawn)
	local ledger = lawn.cells
	for index = 1, math.min(#cells, #ledger) do
		ledger[index] = string.sub(cells, index, index)
	end
	drawCells(lawn, { [LawnGrid.MOWED] = true })

	for _, packed in log do
		local segment = Swath.unpack(packed)
		if segment.ragged then
			-- Its cells are ragged in the ledger, or have grown back: the last pass draws them.
			continue
		end
		stamp(lawn, segment)
	end
	if lawn.regrows then
		drawCells(lawn, { [LawnGrid.TALL] = true })
	end
	drawCells(lawn, { [LawnGrid.EMPTY] = true, [LawnGrid.RAGGED] = true })
end

-- Grows cells back (the Regrow event): tall in the ledger, their grass back from the tiles and the
-- turf under them uncut.
function GrassPaint.regrowCells(lawn, indexes: { number })
	for _, index in indexes do
		local state = lawn.cells[index]
		if state ~= nil and state ~= LawnGrid.EMPTY then
			lawn.cells[index] = LawnGrid.TALL
			drawCell(lawn, index, LawnGrid.TALL)
		end
	end
end

-- Grows back the cells of `indexes` that the ledger still says are tall: the grass your own mower
-- painted away (GrassController.paintSweep) that the server never cut. A cell the server did cut is
-- mowed in the ledger by now and is left alone.
function GrassPaint.regrowUncut(lawn, indexes: { number })
	local uncut = {}
	for _, index in indexes do
		if lawn.cells[index] == LawnGrid.TALL then
			table.insert(uncut, index)
		end
	end
	GrassPaint.regrowCells(lawn, uncut)
end

return GrassPaint
