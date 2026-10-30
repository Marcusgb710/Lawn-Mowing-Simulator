-- Finds the real model for something, or falls back to a placeholder.
--
-- Where the models are: every one is in ServerStorage.Assets (assets/ in the repo), which the
-- server builds the world from and clients never download, so joining doesn't wait on them.
-- What the server puts in Workspace streams to the screens near it as usual. Client code that
-- clones models itself finds them in ReplicatedStorage.Assets, which holds copies of just those
-- (listed in default.project.json): the decorations and the gnome and flower patch
-- (DecorController), and Story, where CastService puts the people's rigs when the server starts
-- (the judges, for ContestController). New client code that clones a model needs it added to that
-- list, or it gets the placeholder. Each screen also gets its own copies of what
-- only it needs (see Assets.shareWith): its player's tools, for laying them out in storage
-- (CarryController, from DataService), and the crew's truck and trailer, for the drive
-- (CutsceneController, from JobService).
--
-- Where real models go (in assets/, so in ServerStorage.Assets):
--   Tools/<item id>     e.g. Tools/GasPushMower       a Tool with a Handle, or a Model/Part (we wrap it in a Tool).
--                                                     The hand holds the handle (or the Model's PrimaryPart)
--                                                     with its +Y up and its LookVector pointing forward.
--   Kit/<asset>                                       the Lawn Mowing mobile kit templates (grass, weeds, props...)
--   Trucks/<item id>    e.g. Trucks/RustyPickup       a Model whose front faces its pivot's LookVector
--   Trailers/<item id>  e.g. Trailers/UtilityTrailer  a Model whose hitch faces its pivot's LookVector
--                                                     (EquipmentTrailer also has "BaySpot" parts)
--   Buildings/<item id> e.g. Buildings/Shed           a Model whose front door faces its pivot's LookVector
--   Props/House                                       a Model whose front door faces its pivot's LookVector
--   Props/FlowerPatch, Props/GardenGnome              things on the lawn players shouldn't hit
--   Decorations/<id>    e.g. Decorations/BirdBath     yard decorations (Config/Decorations.luau), front
--                                                     toward -Z, with their markers on "Root"
--   Props/StoragePegboard, StorageWallRack,           storage at the business, back flat on Z = 0 with
--         StorageWallHooks, StorageShelf              "Slot1", "Slot2"... attachments where tools go
--   Props/CurbMailbox                                 the mailbox at the curb by every driveway (opens the
--                                                     contracts), front toward -Z, a Root part
--   Props/TruckPennant                                the streak's pennant (Assets.addPennant): origin at the
--                                                     pole's foot, a Root part
--   Story/<id>          e.g. Story/GloriaHouse        the story's places and props
--                                                     (alphainstructions/instructions37.md). Its
--                                                     people (NPC_<name>) aren't files: they are
--                                                     rigs CastService builds at startup.
--
-- New models have an invisible "Root" part as their PrimaryPart, 0.5 studs above the model's
-- origin (see Assets.placeAt).
--
-- Item ids are listed in Shared/Config/Items.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Placeholders = require(script.Parent.Placeholders)
local Premium = require(script.Parent.Config.Premium)

local Assets = {}

-- The hidden ScreenGui in a player's PlayerGui with the copies only their screen gets.
local OWN_COPIES = "MyAssets"

local onServer = RunService:IsServer()

local function findIn(root: Instance?, folderName: string, name: string): Instance?
	local folder = root and root:FindFirstChild(folderName)
	return folder and folder:FindFirstChild(name)
end

local function findAsset(folderName: string, name: string): Instance?
	if onServer then
		-- ReplicatedStorage too, for a model dropped in there in Studio.
		return findIn(ServerStorage:FindFirstChild("Assets"), folderName, name)
			or findIn(ReplicatedStorage:FindFirstChild("Assets"), folderName, name)
	end
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	return findIn(ReplicatedStorage:FindFirstChild("Assets"), folderName, name)
		or findIn(playerGui and playerGui:FindFirstChild(OWN_COPIES), folderName, name)
		-- Empty on a player's device; Studio's command bar in Team Create counts as a client.
		or findIn(ServerStorage:FindFirstChild("Assets"), folderName, name)
end

-- Server only. Copies these models (by name, from `folderName`) to one player's screen, for client
-- code there that builds things from them: into a hidden ScreenGui in their PlayerGui, which no
-- other screen downloads, so nobody waits on models only someone else needs. Each is copied once;
-- one without a real model is skipped (that screen uses the placeholder, as it would anyway).
-- Returns false if their PlayerGui isn't there yet.
function Assets.shareWith(player: Player, folderName: string, names: { string }): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local copies = playerGui:FindFirstChild(OWN_COPIES)
	if not copies then
		local holder = Instance.new("ScreenGui")
		holder.Name = OWN_COPIES
		-- It never shows anything, and it stays through respawns.
		holder.Enabled = false
		holder.ResetOnSpawn = false
		holder.Parent = playerGui
		copies = holder
	end
	local folder = copies:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = copies
	end
	for _, name in names do
		local found = not folder:FindFirstChild(name) and findAsset(folderName, name)
		if found then
			local copy = found:Clone()
			-- A LocalScript would run in a PlayerGui, and these are only ever copied from.
			for _, descendant in copy:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy()
				end
			end
			copy.Parent = folder
		end
	end
	return true
end

local function prepareModel(model: Model): Model
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model
end

-- Kit parts that spin, found by their "<Asset>__<Component>" names. They get a Motor6D instead of
-- a rigid weld, and ToolFxController turns them.
local SPINNING_PARTS = {
	{ match = "__Wheel", spin = "Wheel" },
	{ match = "__CutterRotor", spin = "Rotor" },
	{ match = "__Spool", spin = "Spool" },
}

local function spinKind(name: string): string?
	for _, entry in SPINNING_PARTS do
		if string.find(name, entry.match, 1, true) then
			return entry.spin
		end
	end
	return nil
end

-- Turns whatever the modeler made into a working Tool.
local function toTool(instance: Instance): Tool?
	if instance:IsA("Tool") then
		return instance
	end

	local handle: BasePart?
	if instance:IsA("BasePart") then
		handle = instance
	elseif instance:IsA("Model") then
		-- A part named Handle wins: PrimaryPart doesn't always survive a Rojo sync.
		local named = instance:FindFirstChild("Handle")
		handle = if named and named:IsA("BasePart")
			then named
			else instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	if not handle then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = instance.Name
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			local spin = spinKind(descendant.Name)
			if spin then
				local motor = Instance.new("Motor6D")
				motor.Name = "Spin"
				motor.Part0 = handle
				motor.Part1 = descendant
				motor.C0 = handle.CFrame:ToObjectSpace(descendant.CFrame)
				motor:SetAttribute("Spin", spin)
				motor.Parent = descendant
			else
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true

	if instance ~= handle then
		instance.Parent = tool
	end
	handle.Name = "Handle"
	handle.Parent = tool
	return tool
end

function Assets.tool(category: string, itemId: string): Tool
	local found = findAsset("Tools", itemId)
	local tool = found and toTool(found:Clone())
	if not tool and found then
		warn(`Assets.Tools.{itemId} has no parts to hold, using a placeholder`)
	end
	return tool or Placeholders.tool(category, itemId)
end

-- The same tool as a plain Model (not a Tool), for carrying around and showing on racks and in
-- truck beds. It's posed the way it looks when held, and its pivot is where the hand grabs it.
function Assets.toolDisplay(category: string, itemId: string): Model
	local tool = Assets.tool(category, itemId)
	local model = Instance.new("Model")
	model.Name = tool.Name
	for _, child in tool:GetChildren() do
		child.Parent = model
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			-- Players pick these up by looking at them (InteractController's aim ray), and the
			-- imported models come with CanQuery off, which a non-colliding part honors.
			descendant.CanQuery = descendant.Transparency < 1
			descendant.Massless = true
		end
	end

	local handle = model:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		model.PrimaryPart = handle
		-- In the hand, the grip frame is upright with its front (-Z) pointing forward, so it's
		-- already the right pivot for standing the tool on the ground.
		handle.PivotOffset = tool.Grip
	end
	tool:Destroy()
	return model
end

function Assets.trailer(itemId: string): Model
	local found = findAsset("Trailers", itemId)
	if found and found:IsA("Model") then
		return prepareModel(found:Clone())
	end
	return Placeholders.trailer(itemId)
end

-- A truck, with its trailer hitched behind it if it has one. Pivot it like a single truck.
function Assets.truck(itemId: string, trailerId: string?): Model
	local found = findAsset("Trucks", itemId)
	local truck = if found and found:IsA("Model") then prepareModel(found:Clone()) else Placeholders.truck(itemId)
	if not trailerId then
		return truck
	end

	local trailer = Assets.trailer(trailerId)
	trailer:PivotTo(truck:GetPivot())
	local truckBox, truckSize = truck:GetBoundingBox()
	local trailerBox, trailerSize = trailer:GetBoundingBox()
	-- Line the front-bottom of the trailer up just behind the back-bottom of the truck.
	local truckRear = truckBox * Vector3.new(0, -truckSize.Y / 2, truckSize.Z / 2 + 1)
	local trailerFront = trailerBox * Vector3.new(0, -trailerSize.Y / 2, -trailerSize.Z / 2)
	trailer:PivotTo(trailer:GetPivot() + (truckRear - trailerFront))
	trailer.Name = "Trailer"
	trailer.Parent = truck
	return truck
end

function Assets.building(itemId: string): Model
	local found = findAsset("Buildings", itemId)
	if found and found:IsA("Model") then
		return prepareModel(found:Clone())
	end
	return Placeholders.building(itemId)
end

-- One piece of the Lawn Mowing kit (Assets.Kit) as a loose, anchored part you can size and place.
-- Every yard piece in the kit (grass, weeds, shrubs, curbs, props) is a single MeshPart.
-- Returns nil if the kit isn't in the game, so callers can fall back to a block.
function Assets.kitPart(name: string): BasePart?
	local model = findAsset("Kit", name)
	local part = model and model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return nil
	end
	local copy = part:Clone()
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanTouch = false
	copy.CanQuery = false
	copy.CastShadow = false
	return copy
end

-- Sizes a part and stands it on `ground` (a CFrame on the ground, facing the way it should face).
function Assets.standOn(part: BasePart, ground: CFrame, size: Vector3)
	part.Size = size
	part.CFrame = ground * CFrame.new(0, size.Y / 2, 0)
end

-- A yard decoration (Config/Decorations.luau): Decorations/<id>, else a yard prop of that name
-- (the gnome and the flower patch), else a placeholder.
function Assets.decoration(id: string): Model
	local found = findAsset("Decorations", id) or findAsset("Props", id)
	if found and found:IsA("Model") then
		return prepareModel(found:Clone())
	end
	return Placeholders.decoration(id)
end

-- Stands a decoration at `frame` (on the ground, facing its way). Decoration models have a Root
-- 0.5 above their origin; the gnome and flower patch yard props don't, so those stand on their
-- lowest point instead.
function Assets.placeDecoration(model: Model, frame: CFrame)
	local root = model:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		Assets.placeAt(model, frame)
	else
		Assets.placeOnGround(model, frame)
	end
end

-- A decoration's footprint on the ground when it stands at the origin, unturned: the centre of
-- its box (x, z) and its size (width along X, depth along Z). Worked out once per id.
local footprints = {}
function Assets.decorFootprint(id: string): (number, number, number, number)
	local known = footprints[id]
	if not known then
		local model = Assets.decoration(id)
		Assets.placeDecoration(model, CFrame.identity)
		-- Every part's corners but the invisible Root's.
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "Root" then
				local half = part.Size / 2
				for _, sign in
					{
						Vector3.new(-1, -1, -1),
						Vector3.new(1, 1, 1),
						Vector3.new(-1, 1, 1),
						Vector3.new(1, -1, -1),
						Vector3.new(1, -1, 1),
						Vector3.new(-1, 1, -1),
						Vector3.new(1, 1, -1),
						Vector3.new(-1, -1, 1),
					}
				do
					local corner = part.CFrame:PointToWorldSpace(half * sign)
					low, high = low:Min(corner), high:Max(corner)
				end
			end
		end
		if low.X > high.X then
			low, high = Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 1, 0.5)
		end
		local center, size = (low + high) / 2, high - low
		known = { center.X, center.Z, size.X, size.Z }
		footprints[id] = known
		model:Destroy()
	end
	return known[1], known[2], known[3], known[4]
end

function Assets.prop(name: string): Model
	local found = findAsset("Props", name)
	if found and found:IsA("Model") then
		return prepareModel(found:Clone())
	end
	return Placeholders.prop(name)
end

-- The story's models (alphainstructions/instructions37.md): Story/<id>, or Props/<id> (where
-- the TurfKing sign is filed), or nil while it isn't in the game yet.
function Assets.storyModel(id: string): Model?
	local found = findAsset("Story", id) or findAsset("Props", id)
	if found and found:IsA("Model") then
		return prepareModel(found:Clone())
	end
	return nil
end

-- The block stand-ins some of the story's models had before their ids were set, by id.
local STORY_STAND_INS = {
	GloriaHouse = "GloriasHouse",
	NPC_Gloria = "GloriaPemberton",
}

-- A story model, or its block placeholder: one built like the real model (front toward -Z, a
-- Root 0.5 above the origin), so the real one drops in with no code change. The people (NPC_<name>)
-- are rigs CastService builds from Config/Cast.luau at startup, in ReplicatedStorage.Assets.Story;
-- one it couldn't build (it warns) is a placeholder here.
function Assets.story(id: string): Model
	local found = Assets.storyModel(id)
	if found then
		return found
	end
	local older = STORY_STAND_INS[id]
	local model = if older then Assets.prop(older) else Placeholders.prop(id)
	model.Name = id
	return model
end

-- TurfKing's livery, for the stand-in truck below.
local TURFKING_TRUCK = "HeavyDutyPickup"
local TURFKING_PURPLE = Color3.fromRGB(88, 52, 150)
local TURFKING_GOLD = Color3.fromRGB(230, 185, 60)
local TURFKING_AMBER = Color3.fromRGB(255, 170, 40)

-- Where a part's corners reach in `frame`'s space: its lowest and highest corner.
local function extentIn(part: BasePart, frame: CFrame): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local half = part.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
				low, high = low:Min(corner), high:Max(corner)
			end
		end
	end
	return low, high
end

-- TurfKing's purple truck: Story/TurfKingTruck, or until that's in the game, the heavy-duty
-- pickup in TurfKing's livery: purple paint (as a Robux paint job does it, Premium.applyPaint), a
-- gold stripe down each side at door height, the gold crown on both doors and an amber light bar
-- on the roof. It isn't anchored; its front faces its pivot's LookVector, like any truck.
function Assets.turfKingTruck(): Model
	local found = Assets.storyModel("TurfKingTruck")
	if found then
		return found
	end
	local truck = Assets.truck(TURFKING_TRUCK)
	truck.Name = "TurfKingTruck"
	Premium.applyPaint(truck, { tint = TURFKING_PURPLE })
	-- A placeholder truck's body is plain blocks the paint job doesn't know.
	for _, piece in truck:GetDescendants() do
		if piece:IsA("BasePart") and (piece.Name == "Hood" or piece.Name == "Cab" or piece.Name == "Box") then
			piece.Color = TURFKING_PURPLE
		elseif piece:IsA("BasePart") and (piece.Name == "BedLeft" or piece.Name == "BedRight") then
			piece.Color = TURFKING_PURPLE:Lerp(Color3.new(0, 0, 0), 0.2)
		end
	end

	-- Worked out in the truck's own space (X across, Y up, -Z forward).
	local pivot = truck:GetPivot()
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local door: BasePart? = nil
	for _, piece in truck:GetDescendants() do
		if piece:IsA("BasePart") and piece.Transparency < 1 and not piece:FindFirstAncestor("Trailer") then
			local partLow, partHigh = extentIn(piece, pivot)
			low, high = low:Min(partLow), high:Max(partHigh)
			if string.sub(piece.Name, -12) == "__DriverDoor" then
				door = piece
			end
		end
	end
	if low.X > high.X then
		return truck
	end
	-- The stripe and crowns sit on the doors' outside, so mirrors sticking out don't count.
	local side, stripeY, doorZ = high.X, low.Y + (high.Y - low.Y) * 0.45, (low.Z + high.Z) / 2
	local doorHeight = (high.Y - low.Y) * 0.3
	if door then
		local doorLow, doorHigh = extentIn(door, pivot)
		side = math.max(math.abs(doorLow.X), math.abs(doorHigh.X))
		stripeY = doorLow.Y + (doorHigh.Y - doorLow.Y) * 0.3
		doorZ = (doorLow.Z + doorHigh.Z) / 2
		doorHeight = doorHigh.Y - doorLow.Y
	end
	local length = (high.Z - low.Z) * 0.78
	local function livery(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.CFrame = pivot * offset
		piece.Color = color
		piece.Material = material or Enum.Material.SmoothPlastic
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.Parent = truck
		return piece
	end
	for _, sign in { -1, 1 } do
		local x = sign * (side + 0.04)
		livery("Stripe", Vector3.new(0.06, 0.3, length), CFrame.new(x, stripeY, (low.Z + high.Z) / 2), TURFKING_GOLD)
		-- The crown faces out from the door.
		local crownFrame = CFrame.new(x + sign * 0.02, stripeY + doorHeight * 0.32, doorZ)
			* CFrame.Angles(0, sign * math.pi / 2, 0)
		for _, crownPart in Placeholders.crown(crownFrame, math.min(1.4, doorHeight * 0.4), 0.06) do
			crownPart.Parent = truck
		end
	end
	local bar = livery(
		"LightBar",
		Vector3.new((high.X - low.X) * 0.55, 0.35, 0.7),
		CFrame.new(0, high.Y + 0.17, doorZ + 0.4),
		TURFKING_AMBER,
		Enum.Material.Neon
	)
	local light = Instance.new("Attachment")
	light.Name = "Light"
	light.Parent = bar
	return truck
end

-- Moves a model so its origin lands on `frame`. The origin is 0.5 studs below its "Root" part
-- (how the model specs build them: Root at (0, 0.5, 0), never rotated), or its pivot without one.
-- The 0.5 must match CastRig.ROOT_RISE, which GrandmaJune.seatedAt cancels to seat a rig.
function Assets.placeAt(model: Model, frame: CFrame)
	local root = model:FindFirstChild("Root")
	local origin = if root and root:IsA("BasePart") then root.CFrame * CFrame.new(0, -0.5, 0) else model:GetPivot()
	model:PivotTo(frame * origin:ToObjectSpace(model:GetPivot()))
end

-- Turns a model so its longest side points along `long` and its thinnest side along `thin`
-- (unit vectors at right angles), centered on `position`. Works on any model, whichever way it
-- was built. Returns its longest, middle and thinnest sizes.
function Assets.align(model: Model, position: Vector3, long: Vector3, thin: Vector3): (number, number, number)
	local box, size = model:GetBoundingBox()
	local sides = {
		{ axis = box.RightVector, length = size.X },
		{ axis = box.UpVector, length = size.Y },
		{ axis = box.LookVector, length = size.Z },
	}
	table.sort(sides, function(a, b)
		return a.length > b.length
	end)
	local from = CFrame.fromMatrix(box.Position, sides[1].axis, sides[3].axis)
	local to = CFrame.fromMatrix(position, long, thin)
	model:PivotTo(to * from:ToObjectSpace(model:GetPivot()))
	return sides[1].length, sides[2].length, sides[3].length
end

-- Moves a model so its lowest point rests on `ground`, facing the same way as `ground`.
function Assets.placeOnGround(model: Model, ground: CFrame)
	model:PivotTo(ground)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	model:PivotTo(ground + Vector3.new(0, ground.Position.Y - bottom, 0))
end

-- Anchors a model so it stays where it is put. A person (a rig with a Humanoid, from CastService)
-- is the exception: only its HumanoidRootPart and Root are anchored, since anchored limbs would
-- not move for its animations.
function Assets.anchor(model: Instance)
	if model:FindFirstChildOfClass("Humanoid") then
		for _, name in { "HumanoidRootPart", "Root" } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	if model:IsA("BasePart") then
		model.Anchored = true
	end
end

-- How far in from the bed's rear and right edges the pennant's pole stands.
local PENNANT_INSET = 0.25

-- Flies the streak's pennant (Props/TruckPennant) on a truck: on its bed's rear right corner, so it
-- shows from behind and from the side. The corner is the truck's own `BedArea` (a hitched trailer's
-- doesn't count), or for a truck without one the same corner halfway up the truck. Trucks face
-- -Z, so the rear is +Z and the right +X. The pennant is parented to the truck and goes wherever
-- the truck does. A truck that has one already gets no second, so this can be called any time.
function Assets.addPennant(truck: Model)
	if truck:FindFirstChild("Pennant") then
		return
	end
	local pivot = truck:GetPivot()
	local trailer = truck:FindFirstChild("Trailer")
	local pieces: { BasePart } = {}
	local bed: BasePart? = nil
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") and not (trailer and descendant:IsDescendantOf(trailer)) then
			table.insert(pieces, descendant)
			if descendant.Name == "BedArea" and not bed then
				bed = descendant
			end
		end
	end

	local corner: Vector3
	if bed then
		local _, top = extentIn(bed, pivot)
		corner = top
	else
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, piece in pieces do
			if piece.Transparency < 1 then
				local pieceLow, pieceHigh = extentIn(piece, pivot)
				low, high = low:Min(pieceLow), high:Max(pieceHigh)
			end
		end
		if low.X > high.X then
			return
		end
		corner = Vector3.new(high.X, (low.Y + high.Y) / 2, high.Z)
	end

	local pennant = Assets.prop("TruckPennant")
	Assets.anchor(pennant)
	-- Only there to look at: it never blocks anyone, or the aim at the bed's tools.
	for _, descendant in pennant:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	Assets.placeAt(pennant, pivot * CFrame.new(corner - Vector3.new(PENNANT_INSET, 0, PENNANT_INSET)))
	pennant.Name = "Pennant"
	pennant.Parent = truck
end

return Assets
