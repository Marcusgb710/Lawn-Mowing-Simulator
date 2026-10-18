-- Finds the real model for something, or falls back to a placeholder.
--
-- Where real models go (all inside ReplicatedStorage.Assets):
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
--
-- New models have an invisible "Root" part as their PrimaryPart, 0.5 studs above the model's
-- origin (see Assets.placeAt).
--
-- Item ids are listed in Shared/Config/Items.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Placeholders = require(script.Parent.Placeholders)

local Assets = {}

local function findAsset(folderName: string, name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	return folder and folder:FindFirstChild(name)
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
		local box, size = model:GetBoundingBox()
		known = { box.Position.X, box.Position.Z, size.X, size.Z }
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

-- Moves a model so its origin lands on `frame`. The origin is 0.5 studs below its "Root" part
-- (how the model specs build them: Root at (0, 0.5, 0), never rotated), or its pivot without one.
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

function Assets.anchor(model: Instance)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	if model:IsA("BasePart") then
		model.Anchored = true
	end
end

return Assets
