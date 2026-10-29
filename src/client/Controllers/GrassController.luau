-- Draws the grass on job sites, and on every business's own lawn (see HomeLawnService).
--
-- A lawn is a turf plate with a few "shells" of grass stacked above it, each a Decal showing an
-- EditableImage: the turf is the ground's colour and the stripes, and each shell a field of blade
-- dots (see GrassImages), thinner towards the top, so the stack reads as standing grass. With the
-- lawn art (GrassArt) the turf plate also carries the mown lawn as a tiling Texture under its Decal,
-- which then holds only the stripes and the uncut mottle, and the shells' blades are tufts. The server
-- keeps which cells are cut (see LawnGrid) and sends what every mower and pair of shears cuts as a
-- swath (see Swath). Each swath is painted into the pictures (see GrassPaint): its stripe shade into
-- the turf and a hole of the same shape through every shell, so a cut follows the deck instead of
-- snapping to cells. A lawn that starts being drawn asks for everything cut on it so far
-- (GetSwaths). Your own mower doesn't wait for its swaths: it paints its strip every frame, and
-- whatever the server never confirms grows back. Lawns far away have no images, to keep phones
-- happy: they aren't drawn at all, or with the lawn art they're left as a bare turf plate and its
-- texture (the uncut one when the lawn was mostly uncut as it was let go), so they still read as lawn.
-- Without EditableImages (the Mesh / Image API toggle is off in a published game, or the device's
-- memory budget is spent) lawns are drawn the simple way instead, for the rest of the session (see
-- GrassFallback).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local GrassArt = require(Shared.Config.GrassArt)
local GrassImages = require(Shared.GrassImages)
local LawnGrid = require(Shared.LawnGrid)
local Net = require(Shared.Net)
local Swath = require(Shared.Swath)
local Tools = require(Shared.Config.Tools)

local GrassPaint = require(script.Parent.Parent.GrassPaint)
local GrassFallback = require(script.Parent.GrassFallback)

-- A drawn lawn goes when it's this much further from the camera than where it starts being drawn,
-- so a lawn right at the edge doesn't flicker in and out as you move.
local DRAW_SLACK = 30
-- Lawns further than this from the camera (studs, from the lawn's edge) aren't drawn. The server
-- sends swaths out to GrassDrawDistance, the furthest a drawn lawn can be.
local DRAW_DISTANCE = GameConfig.GrassDrawDistance - DRAW_SLACK
local UPDATE_INTERVAL = 0.5
-- The server sends a lawn's swaths at most once a second to each player, and nil when asked again
-- sooner: then we ask again after this many seconds.
local REFETCH_DELAY = 1.5

-- How high the turf plate's top face sits above the ground (studs). The server lays its own plain
-- Turf plate on every lawn, topping out 0.02 above the ground (LawnService's _buildGround), so ours
-- sits clear of it or it would be hidden.
local TURF_HEIGHT = 0.1
local PLATE_THICKNESS = 0.1

-- A phone (touch and no keyboard) gets fewer shells. Decided once: GrassPaint makes the session's
-- grass tiles for one shell count, so a keyboard plugged in later mustn't ask for more.
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local WHITE = Color3.new(1, 1, 1)
-- "Show what I missed": the shells' tint. A Decal's tint multiplies the picture, so red goes past 1
-- to turn green blades red rather than just dark (selene's 0-1 rule is for ordinary colours).
-- selene: allow(roblox_incorrect_color3_new_bounds)
local HIGHLIGHT_TINT = Color3.new(2.5, 0.35, 0.35)
-- It eases in and out over this many seconds, and breathes once every this many in between.
local HIGHLIGHT_FADE = 0.25
local HIGHLIGHT_PULSE = 0.8

-- Studs a deck must move in a frame to paint ahead; less is standing still, which the server cuts within a tick.
local PREDICT_MIN_MOVE = 0.05
-- A mower that starts mowing paints as if it had just come this far the way you face, as the
-- server cuts it (ToolService's START_SLIVER), so the first stamp faces that way and not +Z.
local START_SLIVER = 0.1
-- Seconds a painted cell waits for the server's swath: the client can't know about junk stops or refused cuts.
local CONFIRM_SECONDS = 0.5
-- Seconds between looks for cells that waited too long: the ledger copy is the server's truth, and decides.
local RECONCILE_INTERVAL = 0.1

local GrassController = {}

-- [Grass folder] = everything we know about that lawn
local lawns = {}
-- Set for the rest of the session once an EditableImage couldn't be made (see show).
local useFallback = false
-- Whether the turf's texture has failed to set and been warned about (see addTexture).
local textureWarned = false
-- [lawn] = { [cell index] = os.clock() your own mower last painted it }, for the cells no swath from
-- the server has vouched for yet (see paintOwnMower and reconcile).
local unconfirmed = {}
-- Where your mower's deck was last frame while it's been mowing, and which mower that was.
local lastLocalDeck: Vector3? = nil
local lastLocalTool: Tool? = nil
local lastReconcile = 0

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

-- Lays the mown lawn texture over a turf plate's top face, tiling every GrassArt.TileStuds studs, under
-- its Decal if it has one (a lower ZIndex is drawn first, and the Decal's picture is see-through where
-- the lawn is mown). The part keeps its plain colour, and the warning is said once, if the texture
-- can't be set. It gives the Texture, or nil when that happened.
local function addTexture(part: Part, decal: Decal?): Texture?
	local texture = Instance.new("Texture")
	local ok, problem = pcall(function()
		texture.Face = Enum.NormalId.Top
		texture.ColorMapContent = Content.fromAssetId(GrassArt.Mown)
		texture.StudsPerTileU = GrassArt.TileStuds
		texture.StudsPerTileV = GrassArt.TileStuds
		texture.ZIndex = 0
		if decal then
			decal.ZIndex = 1
		end
	end)
	if ok then
		texture.Parent = part
		return texture
	end
	texture:Destroy()
	if not textureWarned then
		textureWarned = true
		warn(`[Grass] Couldn't lay the lawn texture on the turf: {problem}`)
	end
	return nil
end

-- Sets the texture a far lawn's bare turf keeps, from the ledger as it stands when the lawn is let go
-- (a snapshot: a far lawn gets no swaths): the uncut texture when more than half of the cells that
-- have grass are still tall, and the mown one it was drawn with otherwise.
local function showFarLawn(lawn)
	local texture, cells = lawn.turfTexture, lawn.cells
	if not texture or not cells then
		return
	end
	local grass, tall = 0, 0
	for _, state in cells do
		if state ~= LawnGrid.EMPTY then
			grass += 1
			if state == LawnGrid.TALL then
				tall += 1
			end
		end
	end
	if tall * 2 > grass then
		texture.ColorMapContent = Content.fromAssetId(GrassArt.Uncut)
	end
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

-- Takes down what a lawn has in the world: its parts, or a far lawn's bare turf.
local function clearContainer(lawn)
	if lawn.container then
		lawn.container:Destroy()
		lawn.container = nil
	end
	lawn.turfPart, lawn.turfDecal, lawn.turfTexture = nil, nil, nil
end

-- Makes a lawn's images and parts, all tall: the turf plate, and the shells stacked by
-- GrassImages.shellPlan. False, with whatever was made left for show to clear away, when an image
-- can't be made.
local function buildSurface(lawn): boolean
	local plan = GrassImages.shellPlan(GrassImages.shellCount(TOUCH), GameConfig.TallGrassHeight * lawn.tallScale)
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
	local turf, turfDecal = surfacePart(lawn, "Turf", TURF_HEIGHT, lawn.turf)
	turf.Material = Enum.Material.Grass
	turf.Color = GrassPaint.UNCUT
	lawn.turfPart, lawn.turfDecal = turf, turfDecal
	if GrassPaint.textured() then
		lawn.turfTexture = addTexture(turf, turfDecal)
	end
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
	-- Everything is the server's now, your own mower's paint included.
	unconfirmed[lawn] = nil
	if lawn.mode == "Fallback" then
		-- No stripes there: the ledger is all it draws.
		GrassFallback.applyCells(lawn, cells)
	else
		GrassPaint.redraw(lawn, cells, log)
	end
end

-- Asks the server for everything cut on a drawn lawn and redraws it, unless it's been hidden or
-- asked again since. A nil answer (we asked for it too soon after the last) is asked again shortly.
local function fetch(lawn)
	lawn.fetches += 1
	local ticket = lawn.fetches
	task.spawn(function()
		local getSwaths = Net.func("GetSwaths")
		while true do
			local ok, cells, log = pcall(getSwaths.InvokeServer, getSwaths, lawn.folder)
			if not (ok and lawn.mode and lawn.fetches == ticket) then
				return
			end
			if typeof(cells) == "string" then
				redraw(lawn, cells, if typeof(log) == "table" then log else {})
				return
			end
			if cells ~= nil then
				return
			end
			task.wait(REFETCH_DELAY)
			if not (lawn.mode and lawn.fetches == ticket) then
				return
			end
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
	-- A far lawn's bare turf makes way for the drawn one.
	clearContainer(lawn)
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
	-- Over the lawn art, a lawn drawn as a surface leaves its turf behind, bare but for the texture,
	-- so a far lawn reads as lawn and not as nothing. Anything else goes entirely.
	local keepsTurf = lawn.mode == "Surface" and GrassPaint.textured()
	if lawn.mode == "Fallback" then
		GrassFallback.hide(lawn)
	end
	stopHighlight(lawn)
	unconfirmed[lawn] = nil
	if keepsTurf then
		-- Before destroyImages clears the ledger: the bare turf shows the lawn as it stands.
		showFarLawn(lawn)
	end
	destroyImages(lawn)
	if keepsTurf then
		for _, child in lawn.container:GetChildren() do
			if child ~= lawn.turfPart then
				child:Destroy()
			end
		end
		lawn.turfDecal:Destroy()
		lawn.turfDecal = nil
	else
		clearContainer(lawn)
	end
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
	-- No lawn is drawn until GrassPaint knows whether it has the lawn art: it waits on the asset
	-- loads, and drawing a lawn in the meantime would settle the session on flat colours.
	if not camera or not GrassPaint.loaded() then
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
		-- The turf's image, then the turf plate's part, its Decal and its lawn Texture (when it has
		-- one), which are all a far lawn keeps.
		turf = nil,
		turfPart = nil,
		turfDecal = nil,
		turfTexture = nil,
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
			clearContainer(lawn)
			lawns[folder] = nil
		end
	end)
	update()
end

-- A sweep of the deck as GrassPaint takes it, in lawn-local studs.
local function sweepSegment(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number,
	shade: string,
	ragged: boolean
): Swath.Segment
	return {
		fromX = fromX,
		fromZ = fromZ,
		toX = toX,
		toZ = toZ,
		halfWidth = halfWidth,
		shade = shade,
		ragged = ragged,
	}
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
	GrassPaint.paintSwath(lawn, sweepSegment(fromX, fromZ, toX, toZ, halfWidth, shade, ragged), false)
end

-- The Grass folder of the lawn drawn as a surface that a spot in the world (studs) is over, if any.
function GrassController.lawnFolderAt(worldX: number, worldZ: number): Folder?
	for folder, lawn in lawns do
		if lawn.mode == "Surface" then
			local x, z = worldX - lawn.origin.X, worldZ - lawn.origin.Z
			if x >= 0 and x < lawn.columns and z >= 0 and z < lawn.rows then
				return folder
			end
		end
	end
	return nil
end

-- The Grass folder of the job site's lawn you're at: the nearest one drawn as a surface to your
-- character, if any. Job sites are far apart, so that's the one you're working. The simple
-- renderer's lawns don't count (there's nothing to light up on them).
function GrassController.jobLawnFolder(): Folder?
	local jobSites = workspace:FindFirstChild("JobSites")
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (jobSites and root and root:IsA("BasePart")) then
		return nil
	end
	local nearest: Folder? = nil
	local nearestDistance = math.huge
	for folder, lawn in lawns do
		if lawn.mode == "Surface" and folder:IsDescendantOf(jobSites) then
			local distance = distanceToLawn(lawn, root.Position)
			if distance < nearestDistance then
				nearest, nearestDistance = folder, distance
			end
		end
	end
	return nearest
end

-- Your own mower paints its strip every frame instead of waiting for the server's swaths, which
-- come ten times a second and a little late, so the cut shows under the deck and not in chunks
-- behind it. The server stays the judge: the swaths it sends confirm what we painted, and a cell it
-- never cut (junk stopped the deck, or the cut was refused) grows back from the ledger's say-so.

-- The mower your character holds, with the part it's driven from, when it's mowing right now (the
-- server's "Mows": its deck is on a lawn it can cut, whether or not the last tick cut any, so a
-- pass paints from its first stud) and its blade is sharp. A dull blade's torn cut is the server's
-- alone: painting it every frame would tear the same cells again and again, and a guess at it would
-- stay wrong. "Cutting" is for the clippings, the slowdown and the shake, not for this.
local function cuttingMower(): (Tool?, BasePart?)
	local character = Players.LocalPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- The server stops working a fallen character's tool without clearing what it set.
	if not (tool and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return nil, nil
	end
	if
		tool:GetAttribute("Category") ~= "Mower"
		or tool:GetAttribute("Working") ~= true
		or tool:GetAttribute("Mows") ~= true
		or tool:GetAttribute("Blocked") ~= nil
		or tool:GetAttribute("Ragged") == true
	then
		return nil, nil
	end
	return tool, root
end

-- Notes the cells a segment of your own mower's paint cuts, for reconcile to look at.
local function remember(lawn, segment: Swath.Segment, now: number)
	local painted = unconfirmed[lawn]
	if not painted then
		painted = {}
		unconfirmed[lawn] = painted
	end
	for _, index in GrassPaint.cutCells(lawn, segment) do
		painted[index] = now
	end
end

-- A swath from the server vouches for the cells it cut: the ledger has them mowed now. Nothing to
-- do for cells we never painted.
local function confirm(lawn, segment: Swath.Segment)
	local painted = unconfirmed[lawn]
	if painted then
		for _, index in GrassPaint.cutCells(lawn, segment) do
			painted[index] = nil
		end
	end
end

-- Paints the strip your mower's deck made this frame: from where it was last frame to where it is
-- now, on the lawn under it. The deck is where the server puts it (see ToolService's workTick). A
-- frame with no previous deck (the mower just started mowing, or was swapped) paints the deck's
-- own rectangle, the way you face, as the server's fresh start does.
local function paintOwnMower(now: number)
	local tool, root = cuttingMower()
	local itemId = if tool then tool:GetAttribute("ItemId") else nil
	local item = if typeof(itemId) == "string" then Tools.get(itemId) else nil
	if not (tool and root and item) then
		lastLocalDeck, lastLocalTool = nil, nil
		return
	end

	local look = root.CFrame.LookVector
	local deck = root.Position + look * GameConfig.DeckOffset
	local last = if tool == lastLocalTool then lastLocalDeck else nil
	lastLocalDeck, lastLocalTool = deck, tool
	if not last then
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude <= 1e-3 then
			return
		end
		last = deck - flat.Unit * START_SLIVER
	end
	local dx, dz = deck.X - last.X, deck.Z - last.Z
	if dx * dx + dz * dz < PREDICT_MIN_MOVE * PREDICT_MIN_MOVE then
		return
	end
	local folder = GrassController.lawnFolderAt(deck.X, deck.Z)
	local lawn = folder and lawns[folder]
	if not (folder and lawn) then
		return
	end

	local origin = lawn.origin
	local fromX, fromZ, toX, toZ = last.X - origin.X, last.Z - origin.Z, deck.X - origin.X, deck.Z - origin.Z
	local shade = Swath.shade(dx, dz)
	GrassController.paintSweep(folder, fromX, fromZ, toX, toZ, item.radius, shade, false)
	remember(lawn, sweepSegment(fromX, fromZ, toX, toZ, item.radius, shade, false), now)
end

-- Grows back what your own mower painted away that the server hasn't confirmed in CONFIRM_SECONDS
-- and still has tall: the cells are the server's to cut, and it didn't.
local function reconcile(now: number)
	for lawn, painted in unconfirmed do
		local waited = {}
		for index, paintedAt in painted do
			if now - paintedAt >= CONFIRM_SECONDS then
				table.insert(waited, index)
				painted[index] = nil
			end
		end
		if lawn.mode == "Surface" then
			GrassPaint.regrowUncut(lawn, waited)
		end
		if next(painted) == nil then
			unconfirmed[lawn] = nil
		end
	end
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
			confirm(lawn, segment)
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

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		paintOwnMower(now)
		if now - lastReconcile >= RECONCILE_INTERVAL then
			lastReconcile = now
			reconcile(now)
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
		GrassPaint.load()
		update()
		while true do
			task.wait(UPDATE_INTERVAL)
			update()
		end
	end)
end

return GrassController
