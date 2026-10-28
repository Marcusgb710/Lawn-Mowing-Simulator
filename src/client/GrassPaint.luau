-- The painting behind GrassController's lawns: the brushes, and what each swath, ledger cell and
-- regrown cell does to a lawn's pictures.
--
-- A drawn lawn has a turf image (the ground's colour and the stripes) and a few shell images (blade
-- dots, see GrassImages), each shell with a template: a copy of its dots as first drawn, to grow
-- grass back from. These take GrassController's lawn record and use its turf, shells, templates,
-- pps (pixels per stud), columns and rows. Everything is in lawn-local studs, which are cells too
-- (see LawnGrid), and a picture's X and Y are the lawn's X and Z (GrassImages.worldToPixel).

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrassImages = require(Shared.GrassImages)
local LawnGrid = require(Shared.LawnGrid)
local Swath = require(Shared.Swath)

-- The brushes are this many pixels a side, and the ragged pattern's blocks this many.
local BRUSH_SIZE = 16
local RAGGED_BLOCK = 2

local OVERWRITE = Enum.ImageCombineType.Overwrite
local BLEND = Enum.ImageCombineType.BlendSourceOver
-- Stamps into the turf blend, so a ragged brush's holes leave the turf as it was and a stamp's soft
-- edges don't leave see-through pixels.
local STAMP = { CombineType = BLEND }
-- The plain eraser writes clear pixels. The ragged eraser multiplies: opaque white keeps a shell's
-- grass as it is (the tufts) and clear takes it out.
local ERASE = { CombineType = OVERWRITE }
local ERASE_RAGGED = { CombineType = Enum.ImageCombineType.Multiply }

local WHITE = Color3.new(1, 1, 1)

local function darken(color: Color3, fraction: number): Color3
	return Color3.new(color.R * (1 - fraction), color.G * (1 - fraction), color.B * (1 - fraction))
end

-- Swath's shade colours, as Color3s.
local SHADES: { [string]: Color3 } = {}
for shade, rgb in Swath.Colors do
	SHADES[shade] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
-- Cells with no grass (flower patches, tree rings): bare ground.
local GROUND = Color3.fromRGB(92, 68, 46)
-- The turf under each kind of cell the ledger has (tall cells keep the uncut turf).
local CELL_COLORS = {
	[LawnGrid.MOWED] = SHADES.Flat,
	[LawnGrid.RAGGED] = SHADES[Swath.RAGGED],
	[LawnGrid.EMPTY] = GROUND,
}
-- The blades' two greens: each dot falls between them by its tone, and higher shells lean lighter.
local BLADE_DARK = Color3.fromRGB(58, 112, 40)
local BLADE_LIGHT = Color3.fromRGB(98, 160, 60)
-- Wheel tracks are this much darker than the stripe, this many pixels in from its long edges.
local TRACK_DARKEN = 0.1
local TRACK_INSET = 1

local GrassPaint = {}

-- The turf under uncut grass.
GrassPaint.UNCUT = darken(SHADES.Flat, 0.15)

-- The 16 x 16 stamps (see makeBrushes), made the first time a lawn is drawn.
local brushes = nil

-- A blank EditableImage, or nil when one can't be made: the API is off in this game (that throws)
-- or the device's memory budget is spent (that returns nil).
function GrassPaint.newImage(size: Vector2): EditableImage?
	local ok, image = pcall(AssetService.CreateEditableImage, AssetService, { Size = size })
	return if ok and image then image else nil
end

-- Paints every other RAGGED_BLOCK square of a brush: those whose block column plus block row is
-- even when `parity` is 0, and the rest when it's 1.
local function checker(image: EditableImage, color: Color3, parity: number)
	local blocks = BRUSH_SIZE // RAGGED_BLOCK
	local size = Vector2.new(RAGGED_BLOCK, RAGGED_BLOCK)
	for blockX = 0, blocks - 1 do
		for blockY = 0, blocks - 1 do
			if (blockX + blockY) % 2 == parity then
				image:DrawRectangle(Vector2.new(blockX, blockY) * RAGGED_BLOCK, size, color, 0, OVERWRITE)
			end
		end
	end
end

-- Makes the brushes, once: a solid stamp per shade for the turf (DrawImageTransformed takes no
-- colour, so each shade gets its own), the ragged stamp (the Ragged colour with every other block
-- left out), a clear eraser for the shells, and a ragged eraser that clears only where the ragged
-- stamp paints. False when they can't be made.
function GrassPaint.makeBrushes(): boolean
	if brushes then
		return true
	end
	local made, failed = {}, false
	local function brush(): EditableImage
		local image = GrassPaint.newImage(Vector2.new(BRUSH_SIZE, BRUSH_SIZE))
		if image then
			table.insert(made, image)
		else
			failed = true
		end
		return image :: EditableImage
	end
	local solid = {}
	for shade in SHADES do
		solid[shade] = brush()
	end
	local ragged, eraser, raggedEraser = brush(), brush(), brush()
	if failed then
		for _, image in made do
			image:Destroy()
		end
		return false
	end

	for shade, image in solid do
		image:DrawRectangle(Vector2.zero, image.Size, SHADES[shade], 0, OVERWRITE)
	end
	-- Clear pixels are white, so blending and multiplying never pull in black at the edges.
	for _, image in { ragged, eraser, raggedEraser } do
		image:DrawRectangle(Vector2.zero, image.Size, WHITE, 1, OVERWRITE)
	end
	checker(ragged, SHADES[Swath.RAGGED], 0)
	checker(raggedEraser, WHITE, 1)
	brushes = { solid = solid, ragged = ragged, eraser = eraser, raggedEraser = raggedEraser }
	return true
end

-- Puts a lawn back to all tall: every shell from its template, and the turf uncut.
function GrassPaint.reset(lawn)
	for index, shell in lawn.shells do
		shell:DrawImage(Vector2.zero, lawn.templates[index], OVERWRITE)
	end
	lawn.turf:DrawRectangle(Vector2.zero, lawn.turf.Size, GrassPaint.UNCUT, 0, OVERWRITE)
end

-- Paints a newly made lawn: each template's blade dots (the same on every client), then reset.
-- `plan` is the shells' GrassImages.shellPlan.
function GrassPaint.fill(lawn, plan: { GrassImages.Shell })
	for index, template in lawn.templates do
		local lift = if #plan > 1 then (index - 1) / (#plan - 1) else 0
		for _, dot in GrassImages.bladeDots(template.Size.X, template.Size.Y, plan[index].density, index) do
			local color = BLADE_DARK:Lerp(BLADE_LIGHT, (dot.tone + lift) / 2)
			template:DrawCircle(Vector2.new(dot.x, dot.y), dot.r, color, 0, BLEND)
		end
	end
	GrassPaint.reset(lawn)
end

-- Paints one swath: its stripe into the turf and its shape out of every shell.
function GrassPaint.paintSegment(lawn, segment: Swath.Segment)
	local pps = lawn.pps
	local turf = lawn.turf
	-- A dull blade's cut always takes the Ragged colour, whatever shade it was heading.
	local shade = if segment.ragged then Swath.RAGGED else segment.shade
	local color = SHADES[shade] or SHADES.Flat
	local function pixel(x: number, z: number): Vector2
		return Vector2.new(GrassImages.worldToPixel(0, 0, pps, x, z))
	end

	if segment.radius then
		-- A snip: a round patch.
		local center, radius = pixel(segment.fromX, segment.fromZ), segment.radius * pps
		turf:DrawCircle(center, radius, color, 0, BLEND)
		for _, shell in lawn.shells do
			shell:DrawCircle(center, radius, WHITE, 1, OVERWRITE)
		end
		return
	end

	local halfWidth = segment.halfWidth
	if halfWidth <= 0 then
		return
	end
	-- Which way it went, as the server has it: one that barely moved stood still, facing +Z with no
	-- length, so it paints the deck's own rectangle along +Z. Either way the cut reaches DeckReach
	-- past both ends (see LawnGrid.cellsUnderSweep).
	local alongX, alongZ, length = LawnGrid.heading(segment.fromX, segment.fromZ, segment.toX, segment.toZ)
	local halfLength = length / 2 + LawnGrid.DeckReach
	local middleX, middleZ = (segment.fromX + segment.toX) / 2, (segment.fromZ + segment.toZ) / 2
	local center = pixel(middleX, middleZ)
	local scale = Vector2.new(2 * halfLength * pps / BRUSH_SIZE, 2 * halfWidth * pps / BRUSH_SIZE)
	-- Image X and Y are lawn X and Z, so the angle on the lawn is the angle in the picture.
	local angle = math.deg(math.atan2(alongZ, alongX))
	local brush = if segment.ragged then brushes.ragged else brushes.solid[shade] or brushes.solid.Flat
	turf:DrawImageTransformed(center, scale, angle, brush, STAMP)

	-- The wheel tracks, just inside the two long edges.
	local track = darken(color, TRACK_DARKEN)
	local edge = halfWidth - TRACK_INSET / pps
	for _, side in { -edge, edge } do
		local offsetX, offsetZ = -alongZ * side, alongX * side
		local startPixel = pixel(middleX - alongX * halfLength + offsetX, middleZ - alongZ * halfLength + offsetZ)
		local endPixel = pixel(middleX + alongX * halfLength + offsetX, middleZ + alongZ * halfLength + offsetZ)
		turf:DrawLine(startPixel, endPixel, track, 0, BLEND)
	end

	local eraser = if segment.ragged then brushes.raggedEraser else brushes.eraser
	local erase = if segment.ragged then ERASE_RAGGED else ERASE
	for _, shell in lawn.shells do
		shell:DrawImageTransformed(center, scale, angle, eraser, erase)
	end
end

-- A dull blade's torn cut over a rectangle of a shell, a pixel at a time: where the ragged brush
-- would paint (every other RAGGED_BLOCK square, counted from the image's corner) the grass goes,
-- and the rest stays standing as tufts. (A brush shrunk to one cell would blur its pattern away.)
local function tear(image: EditableImage, position: Vector2, size: Vector2)
	local pixels = image:ReadPixelsBuffer(position, size)
	for y = 0, size.Y - 1 do
		for x = 0, size.X - 1 do
			if ((position.X + x) // RAGGED_BLOCK + (position.Y + y) // RAGGED_BLOCK) % 2 == 0 then
				buffer.writeu8(pixels, (y * size.X + x) * 4 + 3, 0)
			end
		end
	end
	image:WritePixelsBuffer(position, size, pixels)
end

-- Draws every cell the way the ledger has it (one character per cell, see LawnGrid): cut and empty
-- cells come out of every shell, raggedly for a ragged cut, and the turf under them takes their
-- colour. Cells are counted column by column, so it goes a column at a time in runs of one state.
function GrassPaint.applyCells(lawn, cells: string)
	local cellPixels = lawn.pps
	local rows = lawn.rows
	for column = 0, lawn.columns - 1 do
		local base = column * rows
		local row = 0
		while row < rows do
			local state = string.sub(cells, base + row + 1, base + row + 1)
			local first = row
			repeat
				row += 1
			until row >= rows or string.sub(cells, base + row + 1, base + row + 1) ~= state
			local color = CELL_COLORS[state]
			if color then
				local position = Vector2.new(column * cellPixels, first * cellPixels)
				local size = Vector2.new(cellPixels, (row - first) * cellPixels)
				lawn.turf:DrawRectangle(position, size, color, 0, OVERWRITE)
				for _, shell in lawn.shells do
					if state == LawnGrid.RAGGED then
						tear(shell, position, size)
					else
						shell:DrawRectangle(position, size, WHITE, 1, OVERWRITE)
					end
				end
			end
		end
	end
end

-- Grows cells back: each shell gets the cell's square back from its template (DrawImage can't
-- take part of an image, so the pixels are copied), and the turf under them goes flat.
function GrassPaint.regrowCells(lawn, indexes: { number })
	local cellPixels = lawn.pps
	local size = Vector2.new(cellPixels, cellPixels)
	for _, index in indexes do
		if index < 1 or index > lawn.columns * lawn.rows then
			continue
		end
		local column, row = LawnGrid.cell(index, lawn.rows)
		local position = Vector2.new(column * cellPixels, row * cellPixels)
		for shellIndex, shell in lawn.shells do
			shell:WritePixelsBuffer(position, size, lawn.templates[shellIndex]:ReadPixelsBuffer(position, size))
		end
		lawn.turf:DrawRectangle(position, size, SHADES.Flat, 0, OVERWRITE)
	end
end

return GrassPaint
