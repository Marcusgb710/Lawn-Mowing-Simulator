-- The simple way to draw a lawn, for when GrassController can't make EditableImages (the Mesh /
-- Image API toggle is off in a published game, or the device's memory budget is spent).
--
-- One flat plate in mowed green, with a block of tall grass standing on every 2 x 2-cell patch that
-- still has uncut grass in it. No stripes and no smooth edges: it's the safety net, there so the
-- game stays playable, not a look to tune. A block stays up while any of its cells is tall, so
-- grass left to mow is never hidden. This is a plain module, not a controller: GrassController
-- owns the lawn record (origin, columns, rows, tallScale, turfHeight, container) and calls these,
-- and what they draw is kept in lawn.fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local LawnGrid = require(Shared.LawnGrid)
local Swath = require(Shared.Swath)

-- A block of tall grass covers this many cells a side.
local BLOCK = 2
local PLATE_THICKNESS = 0.1
local MOWED_COLOR = Color3.fromRGB(Swath.Colors.Flat[1], Swath.Colors.Flat[2], Swath.Colors.Flat[3])
-- The tall grass: the old tile renderer's block green, darker than any mown stripe.
local TALL_COLOR = Color3.fromRGB(70, 125, 45)

local GrassFallback = {}

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
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

-- Puts up or takes down the block at (blockColumn, blockRow), whichever its cells call for. Blocks
-- on the lawn's far edges are a cell narrower when it has an odd number of columns or rows.
local function refreshBlock(lawn, blockColumn: number, blockRow: number)
	local state = lawn.fallback
	local key = blockColumn * state.blockRows + blockRow + 1
	local firstColumn, firstRow = blockColumn * BLOCK, blockRow * BLOCK
	local width = math.min(BLOCK, lawn.columns - firstColumn)
	local depth = math.min(BLOCK, lawn.rows - firstRow)
	local tall = false
	for column = firstColumn, firstColumn + width - 1 do
		for row = firstRow, firstRow + depth - 1 do
			if state.cells[LawnGrid.index(column, row, lawn.rows)] == LawnGrid.TALL then
				tall = true
			end
		end
	end

	local block = state.blocks[key]
	if tall and not block then
		local height = GameConfig.TallGrassHeight * lawn.tallScale
		block = Instance.new("Part")
		block.Name = "Tall"
		ghost(block)
		block.Material = Enum.Material.Grass
		block.Color = TALL_COLOR
		block.Size = Vector3.new(width, height, depth)
		block.CFrame = CFrame.new(lawn.origin + Vector3.new(firstColumn + width / 2, height / 2, firstRow + depth / 2))
		block.Parent = lawn.container
		state.blocks[key] = block
	elseif block and not tall then
		block:Destroy()
		state.blocks[key] = nil
	end
end

local function refreshAll(lawn)
	for blockColumn = 0, math.ceil(lawn.columns / BLOCK) - 1 do
		for blockRow = 0, lawn.fallback.blockRows - 1 do
			refreshBlock(lawn, blockColumn, blockRow)
		end
	end
end

-- Refreshes the blocks these cells are in, each once.
local function refreshCells(lawn, indexes: { number })
	local done = {}
	for _, index in indexes do
		local column, row = LawnGrid.cell(index, lawn.rows)
		local blockColumn, blockRow = column // BLOCK, row // BLOCK
		local key = blockColumn * lawn.fallback.blockRows + blockRow + 1
		if not done[key] then
			done[key] = true
			refreshBlock(lawn, blockColumn, blockRow)
		end
	end
end

-- Draws the lawn all tall, until the ledger comes (applyCells).
function GrassFallback.show(lawn)
	local plate = Instance.new("Part")
	plate.Name = "Turf"
	ghost(plate)
	plate.Material = Enum.Material.Grass
	plate.Color = MOWED_COLOR
	plate.Size = Vector3.new(lawn.columns, PLATE_THICKNESS, lawn.rows)
	plate.CFrame =
		CFrame.new(lawn.origin + Vector3.new(lawn.columns / 2, lawn.turfHeight - PLATE_THICKNESS / 2, lawn.rows / 2))
	plate.Parent = lawn.container
	lawn.fallback = {
		plate = plate,
		-- Each cell's state, as LawnGrid writes them.
		cells = table.create(lawn.columns * lawn.rows, LawnGrid.TALL),
		-- [block key] = its part, for the blocks standing
		blocks = {},
		blockRows = math.ceil(lawn.rows / BLOCK),
	}
	refreshAll(lawn)
end

function GrassFallback.hide(lawn)
	local state = lawn.fallback
	if not state then
		return
	end
	state.plate:Destroy()
	for _, block in state.blocks do
		block:Destroy()
	end
	lawn.fallback = nil
end

-- Takes every cell's state from the ledger (one character per cell, see LawnGrid).
function GrassFallback.applyCells(lawn, cells: string)
	local state = lawn.fallback
	if not state then
		return
	end
	for index = 1, math.min(#cells, #state.cells) do
		state.cells[index] = string.sub(cells, index, index)
	end
	refreshAll(lawn)
end

function GrassFallback.applySegment(lawn, segment: Swath.Segment)
	local state = lawn.fallback
	if not state then
		return
	end
	local cut = cutCells(lawn, segment)
	for _, index in cut do
		if state.cells[index] == LawnGrid.TALL then
			state.cells[index] = if segment.ragged then LawnGrid.RAGGED else LawnGrid.MOWED
		end
	end
	refreshCells(lawn, cut)
end

function GrassFallback.applyRegrow(lawn, indexes: { number })
	local state = lawn.fallback
	if not state then
		return
	end
	local grown = {}
	for _, index in indexes do
		if state.cells[index] ~= nil and state.cells[index] ~= LawnGrid.EMPTY then
			state.cells[index] = LawnGrid.TALL
			table.insert(grown, index)
		end
	end
	refreshCells(lawn, grown)
end

return GrassFallback
