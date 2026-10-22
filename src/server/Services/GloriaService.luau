-- Gloria Pemberton's house (docs/STORY.md): one fixed house across the street from the plots,
-- where her speech bubble shows in the intro. It's built here on its own so the rest of her part
-- of the story can grow from it (her yard getting tidier by act, TurfKing's trucks in her drive,
-- judging day): GloriaService:GetHouse() gives the model.
--
-- Where it goes: on a part named "GloriasLot" in the Town (front toward the street, like a
-- business plot's pad), or, in the placeholder town, across the south street from the second row
-- of plots, facing them. A Studio-built town without a GloriasLot gets no house (and a warning).
--
-- workspace.GloriasHouse holds:
--   Lot       the ground, in the placeholder town (a GloriasLot part is its own ground)
--   House     Props/GloriasHouse (a block placeholder until the real model exists)
--   Gloria    Props/GloriaPemberton, standing on the house's "Porch" marker
--   Yard      her path, driveway, picket fence and shrubs: the pieces to swap for tidier ones
--   Anchor    an invisible part with the scenes' markers: Bubble (over Gloria's head, for her
--             speech bubble) and IntroView (where the camera looks at the house from)
-- It's streamed to every screen all the time (ModelStreamingMode Persistent), so the intro can
-- show it from anywhere in town.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

-- The lot, the size of a business plot. In the placeholder town it sits across the south street
-- (Z = -120) from the second row of plots, facing them.
local LOT_SIZE = Vector3.new(90, 1, 90)
local PLACEHOLDER_LOT = CFrame.lookAt(Vector3.new(0, -0.4, -178), Vector3.new(0, -0.4, -120))
-- In the lot's space (the street toward -Z): how far back the house's front wall is, where her
-- driveway runs and how wide it is, and where the fence runs along the front.
local HOUSE_Z = 10
local DRIVEWAY_X, DRIVEWAY_WIDTH = 30, 10
local FENCE_Z = -43.5
-- The intro's shot: from the street, looking up at her porch and the drive.
local VIEW_FROM, VIEW_AT = Vector3.new(-18, 10, -36), Vector3.new(4, 5, 6)

local GloriaService = {}

local house: Model? = nil

local function part(parent: Instance, props): Part
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(newPart :: any)[key] = value
	end
	newPart.Parent = parent
	return newPart
end

-- A decoration from the Orders app's catalog (Config/Decorations.luau), kept trim: TurfKing
-- looks after her shrubs.
local function decoration(parent: Instance, id: string, frame: CFrame)
	local model = Assets.decoration(id)
	Assets.anchor(model)
	Assets.placeDecoration(model, frame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -12) == "__Overgrowth" then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	model.Parent = parent
end

-- Builds the house, yard and Gloria on `lot` (on the ground, facing the street). The placeholder
-- town has no pad there, so `withGround` lays one.
local function build(lot: CFrame, withGround: boolean): Model
	local model = Instance.new("Model")
	model.Name = "GloriasHouse"
	local function at(x: number, y: number, z: number): CFrame
		return lot * CFrame.new(x, y, z)
	end

	if withGround then
		part(model, {
			Name = "Lot",
			Size = LOT_SIZE,
			CFrame = at(0, -LOT_SIZE.Y / 2, 0),
			Color = Color3.fromRGB(110, 165, 80),
			Material = Enum.Material.Grass,
		})
	end

	local building = Assets.prop("GloriasHouse")
	Assets.anchor(building)
	Assets.placeAt(building, at(0, 0, HOUSE_Z))
	building.Name = "House"
	building.Parent = model

	local gloria = Assets.prop("GloriaPemberton")
	Assets.anchor(gloria)
	local porch = building:FindFirstChild("Porch", true)
	Assets.placeAt(gloria, if porch and porch:IsA("Attachment") then porch.WorldCFrame else at(-7, 1.2, HOUSE_Z - 3.5))
	gloria.Name = "Gloria"
	gloria.Parent = model

	-- Her yard: a path to the porch steps, the drive, a picket fence along the front with gaps for
	-- both, hydrangeas by the porch and boxwoods along the path.
	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	yard.Parent = model
	-- The path runs from the street up to the front of the house (the bottom of its steps).
	local houseBox, houseSize = building:GetBoundingBox()
	local houseFront = lot:PointToObjectSpace(houseBox.Position).Z - houseSize.Z / 2
	local pathLength = houseFront + LOT_SIZE.Z / 2
	part(yard, {
		Name = "Path",
		Size = Vector3.new(4, 0.1, pathLength),
		CFrame = at(0, 0.05, houseFront - pathLength / 2),
		Color = Color3.fromRGB(190, 185, 175),
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	local drivewayLength = LOT_SIZE.Z / 2 + HOUSE_Z + 10
	part(yard, {
		Name = "Driveway",
		Size = Vector3.new(DRIVEWAY_WIDTH, 0.1, drivewayLength),
		CFrame = at(DRIVEWAY_X, 0.05, -LOT_SIZE.Z / 2 + drivewayLength / 2),
		Color = Color3.fromRGB(170, 170, 165),
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	local _, _, footprint = Assets.decorFootprint("PicketFenceSection")
	local fenceWidth = math.max(footprint, 1)
	local half = LOT_SIZE.X / 2 - 1
	local runs = {
		{ -half, -3 },
		{ 3, DRIVEWAY_X - DRIVEWAY_WIDTH / 2 - 1 },
		{ DRIVEWAY_X + DRIVEWAY_WIDTH / 2 + 1, half },
	}
	for _, run in runs do
		local from, to = run[1], run[2]
		local count = math.floor((to - from) / fenceWidth)
		local start = (from + to) / 2 - (count - 1) * fenceWidth / 2
		for index = 0, count - 1 do
			decoration(yard, "PicketFenceSection", at(start + index * fenceWidth, 0, FENCE_Z))
		end
	end
	for _, x in { -12, 12 } do
		decoration(yard, "HydrangeaBush", at(x, 0, HOUSE_Z - 8.5))
	end
	for _, z in { -10, -20, -30 } do
		for _, x in { -4, 4 } do
			decoration(yard, "BoxwoodShrub", at(x, 0, z))
		end
	end
	decoration(yard, "Mailbox", at(DRIVEWAY_X - DRIVEWAY_WIDTH / 2 - 2, 0, FENCE_Z + 2.5))

	-- The scenes' markers.
	local anchor = part(model, {
		Name = "Anchor",
		Size = Vector3.one,
		CFrame = lot,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local gloriaBox, gloriaSize = gloria:GetBoundingBox()
	local bubble = Instance.new("Attachment")
	bubble.Name = "Bubble"
	bubble.Parent = anchor
	bubble.WorldPosition = gloriaBox.Position + Vector3.new(0, gloriaSize.Y / 2 + 0.8, 0)
	local view = Instance.new("Attachment")
	view.Name = "IntroView"
	view.Parent = anchor
	view.WorldCFrame = CFrame.lookAt(lot:PointToWorldSpace(VIEW_FROM), lot:PointToWorldSpace(VIEW_AT))

	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = workspace
	return model
end

-- Public API ---------------------------------------------------------------------------------

-- Gloria's house (see the top of this file), or nil if the town has nowhere for it.
function GloriaService:GetHouse(): Model?
	return house
end

-- Lifecycle ----------------------------------------------------------------------------------

function GloriaService:Init()
	-- WorldService builds (or finds) the town first.
	local town = workspace:FindFirstChild("Town")
	local lot = town and town:FindFirstChild("GloriasLot", true)
	if lot and lot:IsA("BasePart") then
		house = build(lot.CFrame * CFrame.new(0, lot.Size.Y / 2, 0), false)
	elseif town and town:GetAttribute("Placeholder") then
		house = build(PLACEHOLDER_LOT * CFrame.new(0, LOT_SIZE.Y / 2, 0), true)
	else
		warn("The Town has no GloriasLot part, so Gloria's house isn't built (see GloriaService)")
	end
end

return GloriaService
