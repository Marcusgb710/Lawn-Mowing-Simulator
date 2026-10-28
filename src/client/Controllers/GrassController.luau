-- Draws the grass on job sites, and on every business's own lawn (see HomeLawnService).
--
-- A lawn is a turf plate with a few "shells" of grass stacked above it, each a Decal showing an
-- EditableImage: the turf is the ground's colour and the stripes, and each shell a field of blade
-- dots (see GrassImages), thinner towards the top, so the stack reads as standing grass. The server
-- keeps which cells are cut (see LawnGrid) and sends what every mower and pair of shears cuts as a
-- swath (see Swath). Each swath is painted into the pictures (see GrassPaint): its stripe shade into
-- the turf and a hole of the same shape through every shell, so a cut follows the deck instead of
-- snapping to cells. A lawn that starts being drawn asks for everything cut on it so far
-- (GetSwaths). Lawns far away aren't drawn at all, images included, to keep phones happy.
-- Without EditableImages (the Mesh / Image API toggle is off in a published game, or the device's
-- memory budget is spent) lawns are drawn the simple way instead, for the rest of the session (see
-- GrassFallback).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local GrassImages = require(Shared.GrassImages)
local Net = require(Shared.Net)
local Swath = require(Shared.Swath)

local GrassPaint = require(script.Parent.Parent.GrassPaint)
local GrassFallback = require(script.Parent.GrassFallback)

-- A drawn lawn goes when it's this much further from the camera than where it starts being drawn,
-- so a lawn right at the edge doesn't flicker in and out as you move.
local DRAW_SLACK = 30
-- Lawns further than this from the camera (studs, from the lawn's edge) aren't drawn. The server
-- sends swaths out to GrassDrawDistance, the furthest a drawn lawn can be.
local DRAW_DISTANCE = GameConfig.GrassDrawDistance - DRAW_SLACK
local UPDATE_INTERVAL = 0.5

-- How high the turf plate's top face sits above the ground (studs). The server lays its own plain
-- Turf plate on every lawn, topping out 0.02 above the ground (LawnService's _buildGround), so ours
-- sits clear of it or it would be hidden.
local TURF_HEIGHT = 0.1
local PLATE_THICKNESS = 0.1

local WHITE = Color3.new(1, 1, 1)
-- "Show what I missed": the shells' tint. A Decal's tint multiplies the picture, so red goes past 1
-- to turn green blades red rather than just dark (selene's 0-1 rule is for ordinary colours).
-- selene: allow(roblox_incorrect_color3_new_bounds)
local HIGHLIGHT_TINT = Color3.new(2.5, 0.35, 0.35)
-- It eases in and out over this many seconds, and breathes once every this many in between.
local HIGHLIGHT_FADE = 0.25
local HIGHLIGHT_PULSE = 0.8

local GrassController = {}

-- [Grass folder] = everything we know about that lawn
local lawns = {}
-- Set for the rest of the session once an EditableImage couldn't be made (see show).
local useFallback = false

local function localGrass(): Folder
	local folder = workspace:FindFirstChild("LocalGrass")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LocalGrass"
		folder.Parent = workspace
	end
	return folder
end

-- One of the lawn's flat parts, its top face `height` studs above the ground showing `image`.
-- A Decal on the Top face of an unrotated part shows image X along the part's +X and image Y along
-- its +Z, so the picture's (0, 0) pixel lands on the lawn's Origin corner (front-left) and lawn X
-- and Z run along image X and Y, as GrassImages.worldToPixel has them. A mark painted at pixel
-- (0, 0) should show at Origin; were the picture ever half a turn out, turning these parts 180
-- degrees about Y fixes it (they're centred on the lawn, so nothing else moves).
local function surfacePart(lawn, name: string, height: number, image: EditableImage): (Part, Decal)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(lawn.columns, PLATE_THICKNESS, lawn.rows)
	part.CFrame = CFrame.new(lawn.origin + Vector3.new(lawn.columns / 2, height - PLATE_THICKNESS / 2, lawn.rows / 2))
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.ColorMapContent = Content.fromObject(image)
	decal.Parent = part
	part.Parent = lawn.container
	return part, decal
end

local function destroyImages(lawn)
	if lawn.turf then
		lawn.turf:Destroy()
		lawn.turf = nil
	end
	for _, image in lawn.shells do
		image:Destroy()
	end
	table.clear(lawn.shells)
	table.clear(lawn.decals)
	lawn.cells = nil
end

-- Makes a lawn's images and parts, all tall: the turf plate, and the shells stacked by
-- GrassImages.shellPlan. False, with whatever was made left for show to clear away, when an image
-- can't be made.
local function buildSurface(lawn): boolean
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local plan = GrassImages.shellPlan(GrassImages.shellCount(touch), GameConfig.TallGrassHeight * lawn.tallScale)
	if not GrassPaint.prepare(plan) then
		return false
	end
	local size = Vector2.new(lawn.columns * lawn.pps, lawn.rows * lawn.pps)
	lawn.turf = GrassPaint.newImage(size)
	if not lawn.turf then
		return false
	end
	for _ = 1, #plan do
		local shell = GrassPaint.newImage(size)
		if not shell then
			return false
		end
		table.insert(lawn.shells, shell)
	end

	GrassPaint.reset(lawn)
	local turf = surfacePart(lawn, "Turf", TURF_HEIGHT, lawn.turf)
	turf.Material = Enum.Material.Grass
	turf.Color = GrassPaint.UNCUT
	for index, shell in plan do
		local part, decal = surfacePart(lawn, "Shell" .. index, shell.height, lawn.shells[index])
		part.Transparency = 1
		table.insert(lawn.decals, decal)
	end
	return true
end

-- Draws a lawn afresh from what GetSwaths sent: the ledger (the truth for every cell) and the swath
-- log (for the stripes; see GrassPaint.redraw).
local function redraw(lawn, cells: string, log: { { number | string | boolean } })
	if lawn.mode == "Fallback" then
		-- No stripes there: the ledger is all it draws.
		GrassFallback.applyCells(lawn, cells)
	else
		GrassPaint.redraw(lawn, cells, log)
	end
end

-- Asks the server for everything cut on a drawn lawn and redraws it, unless it's been hidden or
-- asked again since.
local function fetch(lawn)
	lawn.fetches += 1
	local ticket = lawn.fetches
	task.spawn(function()
		local getSwaths = Net.func("GetSwaths")
		local ok, cells, log = pcall(getSwaths.InvokeServer, getSwaths, lawn.folder)
		if ok and typeof(cells) == "string" and lawn.mode and lawn.fetches == ticket then
			redraw(lawn, cells, if typeof(log) == "table" then log else {})
		end
	end)
end

local function stopHighlight(lawn)
	if lawn.highlight then
		lawn.highlight:Disconnect()
		lawn.highlight = nil
	end
end

local function show(lawn)
	if lawn.mode then
		return
	end
	lawn.container = Instance.new("Folder")
	lawn.container.Name = lawn.name
	lawn.container.Parent = localGrass()
	-- An image that can't be made comes back nil; anything else that goes wrong building it throws.
	-- Either way the lawn, and every one after it, is drawn the simple way.
	local built, problem = false, nil
	if not useFallback then
		local ok, result = pcall(buildSurface, lawn)
		built, problem = ok and result, if ok then nil else tostring(result)
	end
	if built then
		lawn.mode = "Surface"
	else
		destroyImages(lawn)
		lawn.container:ClearAllChildren()
		if not useFallback then
			useFallback = true
			warn(
				"[Grass] Couldn't draw lawns as surfaces ("
					.. (problem or "no EditableImage: is Allow Mesh / Image APIs on, or is the memory budget spent?")
					.. "): drawing them the simple way for the rest of the session"
			)
		end
		lawn.mode = "Fallback"
		GrassFallback.show(lawn)
	end
	fetch(lawn)
end

local function hide(lawn)
	if not lawn.mode then
		return
	end
	if lawn.mode == "Fallback" then
		GrassFallback.hide(lawn)
	end
	stopHighlight(lawn)
	destroyImages(lawn)
	lawn.container:Destroy()
	lawn.container = nil
	lawn.mode = nil
end

-- Distance from the camera to the nearest point of the lawn, ignoring height.
local function distanceToLawn(lawn, cameraPosition: Vector3): number
	local origin = lawn.origin
	local x = math.clamp(cameraPosition.X, origin.X, origin.X + lawn.columns)
	local z = math.clamp(cameraPosition.Z, origin.Z, origin.Z + lawn.rows)
	return Vector2.new(cameraPosition.X - x, cameraPosition.Z - z).Magnitude
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for _, lawn in lawns do
		local reach = if lawn.mode then DRAW_DISTANCE + DRAW_SLACK else DRAW_DISTANCE
		-- One lawn going wrong mustn't stop the rest showing and hiding (or kill the update loop).
		local ok, problem = pcall(if distanceToLawn(lawn, cameraPosition) <= reach then show else hide, lawn)
		if not ok and not lawn.warned then
			lawn.warned = true
			warn(`[Grass] Couldn't update the lawn {lawn.name}: {problem}`)
		end
	end
end

-- `regrows`: a home lawn, whose grass grows back (see HomeLawnService).
local function track(folder: Instance, regrows: boolean)
	if lawns[folder] or not folder:IsA("Folder") or folder.Name ~= "Grass" then
		return
	end
	local origin = folder:GetAttribute("Origin")
	local columns, rows = folder:GetAttribute("Columns"), folder:GetAttribute("Rows")
	if typeof(origin) ~= "Vector3" or typeof(columns) ~= "number" or typeof(rows) ~= "number" then
		return
	end

	-- Cells are one stud (see LawnGrid), so a lawn is Columns x Rows studs and a swath's studs are
	-- its cells too.
	local lawn = {
		folder = folder,
		name = if folder.Parent then folder.Parent.Name else "Lawn",
		origin = origin,
		columns = columns,
		rows = rows,
		-- Overgrown lawns stand taller.
		tallScale = folder:GetAttribute("TallScale") or 1,
		regrows = regrows,
		pps = GrassImages.pixelsPerStud(columns, rows),
		-- For GrassFallback's plate, which sits where the turf does.
		turfHeight = TURF_HEIGHT,
		-- "Surface" or "Fallback" while drawn, nil while not.
		mode = nil,
		container = nil,
		turf = nil,
		shells = {},
		-- The ledger as this client has it, while drawn as a surface (see GrassPaint).
		cells = nil,
		-- The shells' Decals, for highlightUncut.
		decals = {},
		highlight = nil,
		-- Counts GetSwaths requests, so only the latest one's answer is drawn.
		fetches = 0,
		-- Whether a failed update has been warned about, so it's said once.
		warned = false,
	}
	lawns[folder] = lawn

	folder.AncestryChanged:Connect(function()
		if not folder:IsDescendantOf(workspace) then
			hide(lawn)
			lawns[folder] = nil
		end
	end)
	update()
end

-- Paints a sweep on a drawn lawn ahead of the server's swath (your own mower, so the cut keeps up
-- with the deck), in lawn-local studs. Nothing when the lawn isn't drawn, or is drawn the simple
-- way, which only shows what the server has cut.
function GrassController.paintSweep(
	grassFolder: Folder,
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number,
	shade: string,
	ragged: boolean
)
	local lawn = lawns[grassFolder]
	if not (lawn and lawn.mode == "Surface") then
		return
	end
	GrassPaint.paintSwath(lawn, {
		fromX = fromX,
		fromZ = fromZ,
		toX = toX,
		toZ = toZ,
		halfWidth = halfWidth,
		shade = shade,
		ragged = ragged,
	}, false)
end

-- Tints a drawn lawn's uncut grass red for `seconds`, with a soft pulse, then puts it back. Calling
-- it again starts it over. The simple renderer has nothing to tint.
function GrassController.highlightUncut(grassFolder: Folder, seconds: number)
	local lawn = lawns[grassFolder]
	if not (lawn and lawn.mode == "Surface") then
		return
	end
	stopHighlight(lawn)
	local started = os.clock()
	lawn.highlight = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		local tint = WHITE
		if elapsed < seconds then
			local ends = math.clamp(math.min(elapsed, seconds - elapsed) / HIGHLIGHT_FADE, 0, 1)
			local breath = 0.8 + 0.2 * math.cos(elapsed * 2 * math.pi / HIGHLIGHT_PULSE)
			tint = WHITE:Lerp(HIGHLIGHT_TINT, ends * breath)
		else
			stopHighlight(lawn)
		end
		for _, decal in lawn.decals do
			decal.Color3 = tint
		end
	end)
end

-- Whether lawns are drawn as surfaces: false once the simple renderer has taken over.
function GrassController.isSurface(): boolean
	return not useFallback
end

function GrassController:Start()
	Net.event("Swath").OnClientEvent:Connect(function(grassFolder, packed)
		local lawn = lawns[grassFolder]
		-- A lawn that isn't drawn catches up from GetSwaths when it is.
		if not (lawn and lawn.mode) then
			return
		end
		local segment = Swath.unpack(packed)
		if lawn.mode == "Surface" then
			GrassPaint.paintSwath(lawn, segment, true)
		else
			GrassFallback.applySegment(lawn, segment)
		end
	end)
	Net.event("Regrow").OnClientEvent:Connect(function(grassFolder, indexes)
		local lawn = lawns[grassFolder]
		if not (lawn and lawn.mode) then
			return
		end
		if lawn.mode == "Surface" then
			GrassPaint.regrowCells(lawn, indexes)
		else
			GrassFallback.applyRegrow(lawn, indexes)
		end
	end)
	-- The server may have left us out while we had no character to measure from, so a respawn
	-- redraws every drawn lawn from scratch.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		for _, lawn in lawns do
			if lawn.mode then
				fetch(lawn)
			end
		end
	end)

	for name, regrows in { JobSites = false, HomeLawns = true } do
		task.spawn(function()
			local lawnFolder = workspace:WaitForChild(name)
			lawnFolder.DescendantAdded:Connect(function(descendant)
				track(descendant, regrows)
			end)
			for _, descendant in lawnFolder:GetDescendants() do
				track(descendant, regrows)
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
