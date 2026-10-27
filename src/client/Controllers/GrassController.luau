-- Draws the grass on job sites, and on every business's own lawn (see HomeLawnService).
--
-- The server only says which tiles are mowed (the "State" attribute on each job site's Grass
-- folder, see LawnGrid). This turns that into one kit grass clump per tile: tall clumps until a
-- tile is mowed, then short clumps on a striped turf plate. Lawns far away aren't drawn at all,
-- to keep phones happy. Nothing here swaps clumps by distance: the kit's clumps have Automatic
-- RenderFidelity, so Roblox lowers their detail with distance itself, smoothly, and swapping in
-- the kit's thin _LOD clumps made the grass pop as you walked.
-- Grass cut with a dull blade is ragged: short, but duller, with torn tufts sticking up.
-- Grass being cut gets shorter a quarter at a time (LawnGrid.PARTLY_CUT), under a mower or with
-- every few snips of the shears. Each step sinks smoothly to the new height, and the last one
-- sinks the tall grass down into the short, so mowing a square looks like cutting it down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local LawnGrid = require(Shared.LawnGrid)

-- Lawns further than this from the camera (studs, from the lawn's edge) aren't drawn.
local DRAW_DISTANCE = 200
-- A drawn lawn goes when it's this much further than that, so a lawn right at the edge doesn't
-- flicker in and out as you move.
local DRAW_SLACK = 30
local UPDATE_INTERVAL = 0.5

local CLUMPS = {
	Tall = { "Grass_Tall_A", "Grass_Tall_B" },
	Short = { "Grass_Short_A", "Grass_Short_B" },
}
local STRIPES = { Color3.fromRGB(120, 200, 75), Color3.fromRGB(100, 178, 62) }
local RAGGED_STRIPE = Color3.fromRGB(150, 170, 80)
-- Torn tufts on a ragged tile: how many, and how tall next to a tall clump.
local RAGGED_TUFTS = 1
local TUFT_SCALE = 0.45
local BLOCK_TALL_COLOR = Color3.fromRGB(70, 125, 45)
-- How tall partly cut grass stands, next to uncut: this much at least, plus the rest by how much
-- of it is still standing.
local PARTLY_CUT_MIN = 0.3
-- How long grass takes to sink to its new height as it's cut (or grow back up as it regrows),
-- instead of popping.
local SINK = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local GrassController = {}

-- [kit name] = template part to clone, or false if the kit doesn't have it
local templates = {}
-- [Grass folder] = everything we know about that lawn
local lawns = {}

local function template(name: string): BasePart?
	if templates[name] == nil then
		templates[name] = Assets.kitPart(name) or false
	end
	return templates[name] or nil
end

-- Same "random" number for a tile every time, so redrawing doesn't reshuffle the lawn.
local function noise(index: number, salt: number): number
	local value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
	return value - math.floor(value)
end

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- Where a tile's grass stands: its centre on the ground, turned a random quarter.
local function tileGround(lawn, index: number): CFrame
	local column, row = LawnGrid.cell(index, lawn.rows)
	local turn = math.floor(noise(index, 1) * 4) * (math.pi / 2)
	return CFrame.new(LawnGrid.center(lawn.origin, lawn.tileSize, column, row)) * CFrame.Angles(0, turn, 0)
end

-- How tall a tile's tall grass stands with `standing` (0-1) of it left: partly cut grass is
-- shorter.
local function tallHeight(lawn, index: number, standing: number): number
	local source = template(CLUMPS.Tall[if noise(index, 2) < 0.5 then 1 else 2])
	local cut = PARTLY_CUT_MIN + (1 - PARTLY_CUT_MIN) * standing
	local full = if source then source.Size.Y else GameConfig.TallGrassHeight
	return full * (0.85 + noise(index, 3) * 0.3) * lawn.tallScale * cut
end

-- Sinks (or grows) a part to `height`, still standing on `ground`. A newer sink of the same part
-- takes over from this one.
local function sink(part: BasePart, ground: CFrame, height: number): Tween
	local tween = TweenService:Create(part, SINK, {
		Size = Vector3.new(part.Size.X, height, part.Size.Z),
		CFrame = ground * CFrame.new(0, height / 2, 0),
	})
	tween:Play()
	return tween
end

-- Builds the part(s) for one tile in a given state. `standing` (0-1) is how much of tall grass
-- is still standing (see LawnGrid.standing). For tall grass, the first part is the grass itself.
local function buildTile(lawn, index: number, kind: string, standing: number): { BasePart }
	local column = LawnGrid.cell(index, lawn.rows)
	local tileSize = lawn.tileSize
	local ground = tileGround(lawn, index)
	local stripe = STRIPES[column % 2 + 1]
	local parts = {}

	local ragged = kind == "Ragged"
	if ragged then
		kind = "Short"
		stripe = RAGGED_STRIPE
	end
	local clumps = CLUMPS[kind]
	local source = template(clumps[if noise(index, 2) < 0.5 then 1 else 2])
	if source then
		local clump = source:Clone()
		local height = if kind == "Tall"
			then tallHeight(lawn, index, standing)
			else source.Size.Y * (0.85 + noise(index, 3) * 0.3)
		Assets.standOn(clump, ground, Vector3.new(tileSize * 0.95, height, tileSize * 0.95))
		table.insert(parts, clump)
		if kind == "Short" then
			-- The mown stripes come from a thin plate under the short grass.
			local plate = Instance.new("Part")
			plate.Material = Enum.Material.Grass
			plate.Color = stripe
			Assets.standOn(plate, ground, Vector3.new(tileSize, 0.06, tileSize))
			table.insert(parts, plate)
		end
	else
		-- No kit: a block that's tall and dark, or short and striped once mowed.
		local block = Instance.new("Part")
		block.Material = Enum.Material.Grass
		local tall = kind == "Tall"
		block.Color = if tall then BLOCK_TALL_COLOR else stripe
		local height = if tall then tallHeight(lawn, index, standing) else GameConfig.MowedGrassHeight
		Assets.standOn(block, ground, Vector3.new(tileSize, height, tileSize))
		table.insert(parts, block)
	end

	-- Torn tufts the dull blade missed.
	if ragged then
		local tuft = template(CLUMPS.Tall[1])
		for tuftIndex = 1, RAGGED_TUFTS do
			local offset = Vector3.new(noise(index, 10 + tuftIndex) - 0.5, 0, noise(index, 20 + tuftIndex) - 0.5)
				* tileSize
				* 0.8
			local at = CFrame.new(ground.Position + offset) * CFrame.Angles(0, noise(index, 30 + tuftIndex) * 6, 0)
			local part = if tuft then tuft:Clone() else Instance.new("Part")
			if tuft then
				Assets.standOn(part, at, Vector3.new(tileSize * 0.3, tuft.Size.Y * TUFT_SCALE, tileSize * 0.3))
			else
				part.Material = Enum.Material.Grass
				part.Color = BLOCK_TALL_COLOR
				Assets.standOn(part, at, Vector3.new(0.5, GameConfig.TallGrassHeight * TUFT_SCALE, 0.5))
			end
			table.insert(parts, part)
		end
	end

	for _, part in parts do
		ghost(part)
		part.Parent = lawn.container
	end
	return parts
end

local function clearTile(lawn, index: number)
	local tile = lawn.tiles[index]
	if tile then
		for _, part in tile.parts do
			part:Destroy()
		end
		lawn.tiles[index] = nil
	end
end

-- Makes one tile match the lawn's state. `animate` (grass being cut or growing back in front of
-- you) sinks or grows the tall grass to its new height instead of swapping it.
local function updateTile(lawn, index: number, animate: boolean?)
	local state = string.sub(lawn.state, index, index)
	local standing = LawnGrid.standing(state)
	local kind = if standing
		then "Tall"
		elseif state == LawnGrid.MOWED then "Short"
		elseif state == LawnGrid.RAGGED then "Ragged"
		else nil
	local tile = lawn.tiles[index]
	if not kind then
		clearTile(lawn, index)
		return
	end

	if tile and tile.kind == kind and tile.standing == standing then
		return
	end
	local wasTall = tile ~= nil and tile.kind == "Tall"
	if animate and wasTall and standing then
		-- Cut a bit further: the same grass sinks lower.
		tile.standing = standing
		sink(tile.parts[1], tileGround(lawn, index), tallHeight(lawn, index, standing))
		return
	end

	-- Cut all the way: the short grass appears under the tall grass, which sinks into it.
	local cutDown = if animate and wasTall then table.remove(tile.parts, 1) else nil
	clearTile(lawn, index)
	local parts = buildTile(lawn, index, kind, standing or 1)
	lawn.tiles[index] = { kind = kind, standing = standing, parts = parts }
	if cutDown then
		sink(cutDown, tileGround(lawn, index), GameConfig.MowedGrassHeight).Completed:Connect(function()
			cutDown:Destroy()
		end)
	elseif animate and tile and standing then
		-- Grown back: it rises out of the short grass.
		local grass = parts[1]
		local ground = tileGround(lawn, index)
		local height = grass.Size.Y
		Assets.standOn(grass, ground, Vector3.new(grass.Size.X, GameConfig.MowedGrassHeight, grass.Size.Z))
		sink(grass, ground, height)
	end
end

local function show(lawn)
	if not lawn.container then
		lawn.container = Instance.new("Folder")
		lawn.container.Name = "LocalGrass"
		lawn.container.Parent = workspace
	end
	for index = 1, #lawn.state do
		updateTile(lawn, index)
	end
end

local function hide(lawn)
	if lawn.container then
		lawn.container:Destroy()
		lawn.container = nil
	end
	table.clear(lawn.tiles)
end

-- Distance from the camera to the nearest point of the lawn, ignoring height.
local function distanceToLawn(lawn, cameraPosition: Vector3): number
	local origin = lawn.origin
	local x = math.clamp(cameraPosition.X, origin.X, origin.X + lawn.columns * lawn.tileSize)
	local z = math.clamp(cameraPosition.Z, origin.Z, origin.Z + lawn.rows * lawn.tileSize)
	return Vector2.new(cameraPosition.X - x, cameraPosition.Z - z).Magnitude
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for _, lawn in lawns do
		local reach = if lawn.container then DRAW_DISTANCE + DRAW_SLACK else DRAW_DISTANCE
		if distanceToLawn(lawn, cameraPosition) <= reach then
			-- Already drawn: only new or changed tiles are built (see updateTile).
			show(lawn)
		else
			hide(lawn)
		end
	end
end

local function track(folder: Instance)
	if lawns[folder] or not folder:IsA("Folder") or folder.Name ~= "Grass" then
		return
	end
	local origin = folder:GetAttribute("Origin")
	local state = folder:GetAttribute("State")
	if typeof(origin) ~= "Vector3" or typeof(state) ~= "string" then
		return
	end

	local lawn = {
		origin = origin,
		tileSize = folder:GetAttribute("TileSize") or GameConfig.TileSize,
		columns = folder:GetAttribute("Columns") or 0,
		rows = folder:GetAttribute("Rows") or 1,
		-- Overgrown lawns grow taller clumps.
		tallScale = folder:GetAttribute("TallScale") or 1,
		state = state,
		tiles = {},
		container = nil,
	}
	lawns[folder] = lawn

	-- Only redraw the tiles that changed.
	folder:GetAttributeChangedSignal("State"):Connect(function()
		local newState = folder:GetAttribute("State")
		if typeof(newState) ~= "string" then
			return
		end
		local oldState = lawn.state
		lawn.state = newState
		if lawn.container then
			for index = 1, #newState do
				if string.sub(newState, index, index) ~= string.sub(oldState, index, index) then
					updateTile(lawn, index, true)
				end
			end
		end
	end)
	folder.AncestryChanged:Connect(function()
		if not folder:IsDescendantOf(workspace) then
			hide(lawn)
			lawns[folder] = nil
		end
	end)
	update()
end

function GrassController:Start()
	for _, name in { "JobSites", "HomeLawns" } do
		task.spawn(function()
			local lawnFolder = workspace:WaitForChild(name)
			lawnFolder.DescendantAdded:Connect(track)
			for _, descendant in lawnFolder:GetDescendants() do
				track(descendant)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			update()
		end
	end)
end

return GrassController
