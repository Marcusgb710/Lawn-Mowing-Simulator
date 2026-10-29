-- Gloria Pemberton's house (docs/STORY.md): one fixed house across the street from the plots,
-- where her speech bubble shows in the scenes and from her porch, and where her yard gets fancier
-- as the story goes on: tired before TurfKing, TurfKing's sharp stripes and sign in acts 2 and 3,
-- and over the top for contest week in act 4, with TurfKing's purple truck in her drive and Chad
-- beside it from act 2. GloriaService:GetHouse() gives the house.
--
-- Where it goes: on a part named "GloriasLot" in the Town (front toward the street, like a
-- business plot's pad), or, in the placeholder town, across the south street from the second row
-- of plots, facing them. A Studio-built town without a GloriasLot gets no house (and a warning).
--
-- workspace.GloriasHouse is the same for everyone:
--   Lot       the ground, in the placeholder town (a GloriasLot part is its own ground)
--   House     Story/GloriaHouse (until it's in the game, the block Props/GloriasHouse)
--   Gloria    her rig (CastService builds the people from Config/Cast.luau when the server starts,
--             and the block Props/GloriaPemberton stands in if it couldn't), on the house's "Porch"
--             marker, idling (NpcAnimator)
--   Yard      her driveway (with the block house), and her path, picket fence and mailbox (while
--             her yards are block placeholders). Each screen puts its player's yard in here.
--   Anchor    an invisible part with the scenes' markers: Bubble (over Gloria's head, for her
--             speech bubble) and IntroView (where the camera looks at the house from)
-- It's streamed to every screen all the time (ModelStreamingMode Persistent), so the intro can
-- show it from anywhere in town.
--
-- Each player sees her yard as it is in their own act, so the pieces that change are kept in
-- ReplicatedStorage.GloriasYard, already in place, and each screen shows the ones for its
-- player's act (GloriaController, Story.GloriaYard):
--   Stage1, Stage2, Stage3  her front yard: Story/GloriaYard_Stage<n> at the house's origin, or a
--                           placeholder of decorations and blocks
--   TurfKing                Truck, TurfKing's purple truck in her drive (on the house's "Driveway"
--                           marker, if it has one), with an ArriveFrom attribute: where it backs
--                           in from in the intro. Chad beside it (a rig too; each screen poses its
--                           own copy of him, GloriaController), and a ChadBubble marker over him.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local NpcAnimator = require(Shared:WaitForChild("NpcAnimator"))

local DecorService = require(script.Parent.DecorService)

-- The lot, the size of a business plot. In the placeholder town it sits across the south street
-- (Z = -120) from the second row of plots, facing them.
local LOT_SIZE = Vector3.new(90, 1, 90)
local PLACEHOLDER_LOT = CFrame.lookAt(Vector3.new(0, -0.4, -178), Vector3.new(0, -0.4, -120))
-- In the lot's space (the street toward -Z): how far back the house's middle is, where her
-- driveway runs and how wide it is, and where the fence runs along the front.
local HOUSE_Z = 10
local DRIVEWAY_X, DRIVEWAY_WIDTH = 30, 10
local FENCE_Z = -43.5
-- The intro's shot: from the street, looking up at her porch and the drive.
local VIEW_FROM, VIEW_AT = Vector3.new(-18, 10, -36), Vector3.new(4, 5, 6)
-- Her front lawn, in the lot's space: from the lot's left edge to the driveway, with the path up
-- the middle this wide on each side.
local LAWN_LEFT, LAWN_RIGHT = -43, DRIVEWAY_X - DRIVEWAY_WIDTH / 2 - 0.5
local PATH_HALF = 2
-- How wide TurfKing mows its stripes (and checks).
local STRIPE = 4
local STRIPE_COLORS = { Color3.fromRGB(120, 200, 75), Color3.fromRGB(100, 178, 62) }
-- Where TurfKing's truck parks in the placeholder drive (lot space, facing the street), how far
-- out in the street it backs in from, and where Chad stands (from the truck, on the yard side).
local TRUCK_Z = -16
local ARRIVE_FROM = 40
local CHAD_SPOT = CFrame.new(-2.5, 0, -3) * CFrame.Angles(0, math.rad(-30), 0)
-- A speech bubble's marker sits this far over someone's head.
local BUBBLE_RISE = 0.8

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

-- A flat piece of the yard you walk over (stripes, edges, mulch).
local function flat(parent: Instance, props): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return part(parent, props)
end

-- A decoration from the Orders app's catalog (Config/Decorations.luau), dressed like one in a
-- player's yard (lights, running water). Shrubs are trim unless they're `overgrown`.
local function decoration(parent: Instance, id: string, frame: CFrame, overgrown: boolean?): Model
	local model = Assets.decoration(id)
	Assets.anchor(model)
	Assets.placeDecoration(model, frame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -12) == "__Overgrowth" then
			if not overgrown then
				descendant.Transparency = 1
			end
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	DecorService.dress(model)
	model.Parent = parent
	return model
end

-- A kit piece (grass clumps, weeds) stood on the ground, `scale` times its size; nothing without
-- the kit.
local function kit(parent: Instance, name: string, frame: CFrame, scale: number)
	local piece = Assets.kitPart(name)
	if piece then
		Assets.standOn(piece, frame, piece.Size * scale)
		piece.Parent = parent
	end
	return piece
end

-- Where a speech bubble goes over someone standing in the world: over their rig's "Head" marker
-- (an attachment under Root, since the rig's own Head is the body part), or over the top of them.
local function bubbleSpot(person: Model): Vector3
	local root = person:FindFirstChild("Root")
	local head = root and root:FindFirstChild("Head")
	local box, size = person:GetBoundingBox()
	if head and head:IsA("Attachment") then
		return head.WorldPosition + Vector3.new(0, 1.2 + BUBBLE_RISE, 0)
	end
	return box.Position + Vector3.new(0, size.Y / 2 + BUBBLE_RISE, 0)
end

-- Her yard's three stages ----------------------------------------------------------------------

-- Lays TurfKing's mowing pattern over both halves of her lawn, from the fence to `front` (the
-- house's front): "Stripes" across, or "Checks".
local function mowPattern(parent: Instance, at: (number, number, number) -> CFrame, front: number, pattern: string)
	local back = FENCE_Z + 1
	local rows = math.max(1, math.floor((front - back) / STRIPE))
	for _, half in { { LAWN_LEFT, -PATH_HALF - 0.3 }, { PATH_HALF + 0.3, LAWN_RIGHT } } do
		local from, to = half[1], half[2]
		if pattern == "Stripes" then
			for row = 0, rows - 1 do
				local z = back + (row + 0.5) * STRIPE
				flat(parent, {
					Name = "Stripe",
					Size = Vector3.new(to - from, 0.06, STRIPE),
					CFrame = at((from + to) / 2, 0.03, z),
					Color = STRIPE_COLORS[row % 2 + 1],
					Material = Enum.Material.Grass,
				})
			end
		else
			local columns = math.max(1, math.floor((to - from) / STRIPE))
			local width = (to - from) / columns
			for row = 0, rows - 1 do
				for column = 0, columns - 1 do
					flat(parent, {
						Name = "Check",
						Size = Vector3.new(width, 0.06, STRIPE),
						CFrame = at(from + (column + 0.5) * width, 0.03, back + (row + 0.5) * STRIPE),
						Color = STRIPE_COLORS[(row + column) % 2 + 1],
						Material = Enum.Material.Grass,
					})
				end
			end
		end
	end
end

-- Stage 1, before TurfKing: decent but tired. Shaggy patches, a few dandelions, shrubs that
-- need a trim and a modest flower bed by the porch.
local function stageOne(stage: Model, at: (number, number, number) -> CFrame, front: number)
	local rng = Random.new(1994)
	for _ = 1, 22 do
		local x = rng:NextNumber(LAWN_LEFT + 2, LAWN_RIGHT - 2)
		if math.abs(x) > PATH_HALF + 1.5 then
			kit(
				stage,
				"Grass_Tall_A",
				at(x, 0, rng:NextNumber(FENCE_Z + 3, front - 3)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
				0.8
			)
		end
	end
	for _ = 1, 9 do
		local x = rng:NextNumber(LAWN_LEFT + 2, LAWN_RIGHT - 2)
		local frame = at(x, 0, rng:NextNumber(FENCE_Z + 3, front - 3))
		if math.abs(x) > PATH_HALF + 1 and not kit(stage, "Weed_Dandelion", frame, 1.8) then
			part(stage, {
				Name = "Dandelion",
				Size = Vector3.new(0.6, 0.7, 0.6),
				CFrame = frame * CFrame.new(0, 0.35, 0),
				Color = Color3.fromRGB(230, 200, 40),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CanQuery = false,
			})
		end
	end
	for _, x in { -12, 12 } do
		decoration(stage, "HydrangeaBush", at(x, 0, front - 2.5), true)
	end
	for _, z in { -10, -20, -30 } do
		for _, x in { -4, 4 } do
			decoration(stage, "BoxwoodShrub", at(x, 0, z), true)
		end
	end
	for _, x in { -20, -24 } do
		decoration(stage, "FlowerPatch", at(x, 0, front - 3))
	end
end

-- Stage 2, TurfKing's work: perfect stripes, razor-sharp edges along the path, fresh black mulch
-- under squared shrubs, and a TurfKing sign by the walk.
local function stageTwo(stage: Model, at: (number, number, number) -> CFrame, front: number)
	mowPattern(stage, at, front, "Stripes")
	for _, x in { -PATH_HALF - 0.15, PATH_HALF + 0.15 } do
		flat(stage, {
			Name = "Edge",
			Size = Vector3.new(0.18, 0.1, front - FENCE_Z - 1),
			CFrame = at(x, 0.05, (front + FENCE_Z + 1) / 2),
			Color = Color3.fromRGB(205, 200, 190),
			Material = Enum.Material.Concrete,
		})
	end
	for _, x in { -8.6, -17.2, 8.6, 17.2 } do
		decoration(stage, "MulchBedSection", at(x, 0, front - 3))
	end
	for _, x in { -12, 12 } do
		decoration(stage, "HydrangeaBush", at(x, 0, front - 3))
	end
	for _, x in { -6, -18, 6, 18 } do
		decoration(stage, "BoxwoodShrub", at(x, 0, front - 3))
	end
	for _, z in { -10, -20, -30 } do
		for _, x in { -4, 4 } do
			decoration(stage, "BoxwoodShrub", at(x, 0, z))
		end
	end
end

-- Stage 3, contest week: over the top. Checks instead of stripes, topiary balls in planters, a
-- tiered fountain, rose beds, path lights all the way up the walk and pink flamingos in formation.
local function stageThree(stage: Model, at: (number, number, number) -> CFrame, front: number)
	mowPattern(stage, at, front, "Checks")
	for _, x in { -8.6, -17.2, 8.6, 17.2 } do
		decoration(stage, "MulchBedSection", at(x, 0, front - 3))
	end
	for _, x in { -6, -10, -14, -18, 6, 10, 14, 18 } do
		decoration(stage, "FlowerPatch", at(x, 0, front - 3))
	end
	for _, x in { -3.2, 3.2 } do
		for _, z in { front - 3, front - 22 } do
			local planter = decoration(stage, "TerracottaPlanter", at(x, 0, z))
			local box, size = planter:GetBoundingBox()
			local top = box.Position.Y + size.Y / 2
			part(stage, {
				Name = "TopiaryTrunk",
				Size = Vector3.new(0.25, 1.2, 0.25),
				CFrame = CFrame.new(box.Position.X, top + 0.5, box.Position.Z),
				Color = Color3.fromRGB(100, 70, 45),
				CanCollide = false,
			})
			part(stage, {
				Name = "Topiary",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = CFrame.new(box.Position.X, top + 1.9, box.Position.Z),
				Color = Color3.fromRGB(55, 115, 50),
				Material = Enum.Material.LeafyGrass,
				CanCollide = false,
			})
		end
	end
	decoration(stage, "TieredFountain", at(-24, 0, -22))
	for z = front - 7, FENCE_Z + 3, -6 do
		for _, x in { -PATH_HALF - 0.6, PATH_HALF + 0.6 } do
			decoration(stage, "SolarPathLight", at(x, 0, z))
		end
	end
	-- A V of flamingos, all facing the street.
	for index = 0, 8 do
		local side = if index % 2 == 0 then 1 else -1
		local rank = (index + 1) // 2
		decoration(stage, "PinkFlamingo", at(14 + side * rank * 1.7, 0, -24 - rank * 1.6))
	end
end

local STAGE_BUILDERS = { stageOne, stageTwo, stageThree }

-- Her yard in one stage: the real model at the house's origin, or the placeholder. A placeholder
-- from TurfKing on has its sign by the walk.
local function buildStage(index: number, lot: CFrame, houseOrigin: CFrame, front: number): Model
	local real = Assets.storyModel("GloriaYard_Stage" .. index)
	if real then
		Assets.anchor(real)
		Assets.placeAt(real, houseOrigin)
		real.Name = "Stage" .. index
		return real
	end
	local stage = Instance.new("Model")
	stage.Name = "Stage" .. index
	local function at(x: number, y: number, z: number): CFrame
		return lot * CFrame.new(x, y, z)
	end
	STAGE_BUILDERS[index](stage, at, front)
	if index >= 2 then
		local sign = Assets.story("TurfKingSign")
		Assets.anchor(sign)
		Assets.placeAt(sign, at(PATH_HALF + 2, 0, FENCE_Z + 4))
		sign.Parent = stage
	end
	return stage
end

-- TurfKing's truck parked in her drive, facing the street, and Chad beside it.
local function buildTurfKing(lot: CFrame, building: Model): Model
	local model = Instance.new("Model")
	model.Name = "TurfKing"
	local driveway = building:FindFirstChild("Driveway", true)
	local parked = if driveway and driveway:IsA("Attachment")
		then driveway.WorldCFrame
		else lot * CFrame.new(DRIVEWAY_X, 0, TRUCK_Z)
	local truck = Assets.turfKingTruck()
	Assets.anchor(truck)
	Assets.placeOnGround(truck, parked)
	truck.Name = "Truck"
	-- In the intro it backs in from the street, so it ends up facing out.
	truck:SetAttribute("ArriveFrom", truck:GetPivot() * CFrame.new(0, 0, -ARRIVE_FROM))
	truck.Parent = model

	local chad = Assets.story("NPC_Chad")
	Assets.anchor(chad)
	local _, truckSize = truck:GetBoundingBox()
	Assets.placeAt(chad, parked * CFrame.new(-truckSize.X / 2, 0, 0) * CHAD_SPOT)
	chad.Name = "Chad"
	chad.Parent = model
	local anchor = part(model, {
		Name = "Anchor",
		Size = Vector3.one,
		CFrame = parked,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local bubble = Instance.new("Attachment")
	bubble.Name = "ChadBubble"
	bubble.Parent = anchor
	bubble.WorldPosition = bubbleSpot(chad)
	return model
end

-- Builds the house, Gloria and what's always in her yard on `lot` (on the ground, facing the
-- street), and her changing yard into `stages`. The placeholder town has no pad there, so
-- `withGround` lays one.
local function build(lot: CFrame, withGround: boolean, stages: Folder): Model
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

	local realHouse = Assets.storyModel("GloriaHouse") ~= nil
	local building = Assets.story("GloriaHouse")
	Assets.anchor(building)
	local houseOrigin = at(0, 0, HOUSE_Z)
	Assets.placeAt(building, houseOrigin)
	building.Name = "House"
	building.Parent = model

	local gloria = Assets.story("NPC_Gloria")
	Assets.anchor(gloria)
	local porch = building:FindFirstChild("Porch", true)
	Assets.placeAt(gloria, if porch and porch:IsA("Attachment") then porch.WorldCFrame else at(-7, 1.2, HOUSE_Z - 3.5))
	NpcAnimator.play(gloria)
	gloria.Name = "Gloria"
	gloria.Parent = model

	-- Where the house's front is (the bottom of its steps), in the lot's space.
	local houseBox, houseSize = building:GetBoundingBox()
	local houseFront = lot:PointToObjectSpace(houseBox.Position).Z - houseSize.Z / 2

	-- What's always in her yard: the drive (the real house has its own), and while her yards are
	-- placeholders, a path to the porch steps, a picket fence along the front with gaps for the
	-- path and the drive, and a mailbox.
	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	yard.Parent = model
	if not realHouse then
		local drivewayLength = LOT_SIZE.Z / 2 + HOUSE_Z + 10
		part(yard, {
			Name = "Driveway",
			Size = Vector3.new(DRIVEWAY_WIDTH, 0.1, drivewayLength),
			CFrame = at(DRIVEWAY_X, 0.05, -LOT_SIZE.Z / 2 + drivewayLength / 2),
			Color = Color3.fromRGB(170, 170, 165),
			Material = Enum.Material.Concrete,
			CanCollide = false,
		})
	end
	local placeholderYard = false
	for index = 1, #STAGE_BUILDERS do
		if not Assets.storyModel("GloriaYard_Stage" .. index) then
			placeholderYard = true
		end
	end
	if placeholderYard then
		local pathLength = houseFront + LOT_SIZE.Z / 2
		part(yard, {
			Name = "Path",
			Size = Vector3.new(PATH_HALF * 2, 0.1, pathLength),
			CFrame = at(0, 0.05, houseFront - pathLength / 2),
			Color = Color3.fromRGB(190, 185, 175),
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
		decoration(yard, "Mailbox", at(DRIVEWAY_X - DRIVEWAY_WIDTH / 2 - 2, 0, FENCE_Z + 2.5))
	end

	-- What changes, for each screen to pick from.
	for index = 1, #STAGE_BUILDERS do
		buildStage(index, lot, houseOrigin, houseFront).Parent = stages
	end
	buildTurfKing(lot, building).Parent = stages

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
	local bubble = Instance.new("Attachment")
	bubble.Name = "Bubble"
	bubble.Parent = anchor
	bubble.WorldPosition = bubbleSpot(gloria)
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
	local stages = Instance.new("Folder")
	stages.Name = "GloriasYard"
	-- WorldService builds (or finds) the town first.
	local town = workspace:FindFirstChild("Town")
	local lot = town and town:FindFirstChild("GloriasLot", true)
	if lot and lot:IsA("BasePart") then
		house = build(lot.CFrame * CFrame.new(0, lot.Size.Y / 2, 0), false, stages)
	elseif town and town:GetAttribute("Placeholder") then
		house = build(PLACEHOLDER_LOT * CFrame.new(0, LOT_SIZE.Y / 2, 0), true, stages)
	else
		warn("The Town has no GloriasLot part, so Gloria's house isn't built (see GloriaService)")
	end
	stages.Parent = ReplicatedStorage
end

return GloriaService
