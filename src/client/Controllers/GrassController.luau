-- Draws the grass on job sites, and on every business's own lawn (see HomeLawnService).
--
-- The server only says which tiles are mowed (the "State" attribute on each job site's Grass
-- folder, see LawnGrid). This turns that into one kit grass clump per tile: tall clumps until a
-- tile is mowed, then short clumps on a striped turf plate. Tiles far from the camera use the
-- kit's cheaper _LOD clumps, and lawns out of sight aren't drawn at all, to keep phones happy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local LawnGrid = require(Shared.LawnGrid)

-- Lawns further than this from the camera (studs, from the lawn's edge) aren't drawn.
local DRAW_DISTANCE = 200
-- Tiles further than this from the camera use the low-detail clumps.
local LOD_DISTANCE = 70
-- How far past LOD_DISTANCE a tile has to move before switching back, so it doesn't flicker.
local LOD_SLACK = 8
local UPDATE_INTERVAL = 0.5

local CLUMPS = {
	Tall = { near = { "Grass_Tall_A", "Grass_Tall_B" }, far = "Grass_Tall_LOD" },
	Short = { near = { "Grass_Short_A", "Grass_Short_B" }, far = "Grass_Short_LOD" },
}
local STRIPES = { Color3.fromRGB(120, 200, 75), Color3.fromRGB(100, 178, 62) }
local BLOCK_TALL_COLOR = Color3.fromRGB(70, 125, 45)

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

-- Builds the part(s) for one tile in a given state and level of detail.
local function buildTile(lawn, index: number, kind: string, far: boolean): { BasePart }
	local column, row = LawnGrid.cell(index, lawn.rows)
	local tileSize = lawn.tileSize
	local turn = math.floor(noise(index, 1) * 4) * (math.pi / 2)
	local ground = CFrame.new(LawnGrid.center(lawn.origin, tileSize, column, row)) * CFrame.Angles(0, turn, 0)
	local stripe = STRIPES[column % 2 + 1]
	local parts = {}

	local clumps = CLUMPS[kind]
	local name = if far then clumps.far else clumps.near[if noise(index, 2) < 0.5 then 1 else 2]
	local source = template(name)
	if source then
		local clump = source:Clone()
		local height = source.Size.Y * (0.85 + noise(index, 3) * 0.3) * (if kind == "Tall" then lawn.tallScale else 1)
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
		local height = if tall
			then GameConfig.TallGrassHeight * (0.85 + noise(index, 3) * 0.3) * lawn.tallScale
			else GameConfig.MowedGrassHeight
		Assets.standOn(block, ground, Vector3.new(tileSize, height, tileSize))
		table.insert(parts, block)
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

-- Makes one tile match the lawn's state and the camera's distance.
local function updateTile(lawn, index: number, cameraPosition: Vector3)
	local state = string.sub(lawn.state, index, index)
	local kind = if state == LawnGrid.TALL then "Tall" elseif state == LawnGrid.MOWED then "Short" else nil
	local tile = lawn.tiles[index]
	if not kind then
		clearTile(lawn, index)
		return
	end

	local column, row = LawnGrid.cell(index, lawn.rows)
	local distance = (LawnGrid.center(lawn.origin, lawn.tileSize, column, row) - cameraPosition).Magnitude
	local far = if tile and tile.far then distance > LOD_DISTANCE - LOD_SLACK else distance > LOD_DISTANCE

	if tile and tile.kind == kind and tile.far == far then
		return
	end
	clearTile(lawn, index)
	lawn.tiles[index] = { kind = kind, far = far, parts = buildTile(lawn, index, kind, far) }
end

local function show(lawn, cameraPosition: Vector3)
	if not lawn.container then
		lawn.container = Instance.new("Folder")
		lawn.container.Name = "LocalGrass"
		lawn.container.Parent = workspace
	end
	for index = 1, #lawn.state do
		updateTile(lawn, index, cameraPosition)
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
		if distanceToLawn(lawn, cameraPosition) <= DRAW_DISTANCE then
			show(lawn, cameraPosition)
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
		local camera = workspace.CurrentCamera
		if lawn.container and camera then
			for index = 1, #newState do
				if string.sub(newState, index, index) ~= string.sub(oldState, index, index) then
					updateTile(lawn, index, camera.CFrame.Position)
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
