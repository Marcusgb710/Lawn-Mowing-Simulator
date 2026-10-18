--!nocheck
-- Run this in the Studio command bar right after importing the Lawn Mowing mobile kit
-- (File > Import 3D > Models/ALL_ASSETS/LawnMowing_AllAssets.gltf).
--
-- It finds the imported kit wherever the importer put it, scales every asset to its real size
-- and builds ServerStorage.LawnKitExport:
--   Kit/<asset name>   every kit asset as an anchored, non-colliding template. Its pivot sits on
--                      the ground under the asset and faces the asset's front (LookVector).
--
-- Then save the place and run `lune run scripts/export-kit` to write them into assets/Kit (synced
-- into ReplicatedStorage.Assets.Kit), then `lune run scripts/build-kit-tools` for the shop tools.

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Longest side of each asset in studs (from the kit's asset_manifest.json, 0.28 m per stud).
local SIZES = {
	Mower_Push_21in = 5.242250221,
	Mower_LawnTractor_42in = 6.752767733,
	Mower_ZeroTurn_52in = 7.287053551,
	Trimmer_Petrol = 5.982142687,
	Trimmer_Battery = 5.760714412,
	Grass_Short_A = 1.374989854,
	Grass_Short_B = 1.085691899,
	Grass_Short_LOD = 0.588587778,
	Grass_Medium_A = 1.207496971,
	Grass_Medium_B = 1.366406466,
	Grass_Medium_LOD = 0.857142838,
	Grass_Tall_A = 1.967784124,
	Grass_Tall_B = 1.961270188,
	Grass_Tall_LOD = 1.642857173,
	Grass_EdgeStrip_1m = 3.579712766,
	Grass_Clippings_Pile = 1.565313659,
	Weed_Dandelion = 1.145637993,
	Weed_Broadleaf = 1.4514012,
	Weed_Clover = 1.17319205,
	Weed_Thistle = 1.608338952,
	Weed_DryTuft = 1.027538521,
	Prop_FuelCan_5L = 1.821799576,
	Prop_YardWasteBag = 1.928571292,
	Prop_WheelieBin = 2.545356963,
	Prop_TrafficCone = 1.76785716,
	Prop_GardenHose_Coil = 2.371428481,
	Prop_Rake = 4.822509629,
	Prop_Shovel = 4.528571452,
	Fence_Cedar_2m = 7.499999659,
	Curb_Concrete_1m = 3.571428571,
	Paver_Concrete_40cm = 1.42857145,
	Rock_Field_A = 1.468840029,
	Rock_Field_B = 1.978394389,
	Shrub_Rounded = 3.0484687,
}

-- Vegetation doesn't cast shadows (cheaper on phones).
local function isVegetation(name: string): boolean
	return name:match("^Grass_") ~= nil or name:match("^Weed_") ~= nil or name == "Shrub_Rounded"
end

local function parts(root: Instance): { BasePart }
	local list = {}
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	return list
end

-- Bounding box of some parts in the space of `frame`.
local function bounds(list: { BasePart }, frame: CFrame): (Vector3, Vector3)
	local low = Vector3.one * math.huge
	local high = -Vector3.one * math.huge
	for _, part in list do
		local half = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = frame:PointToObjectSpace(part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	return low, high
end

-- Find every imported kit asset. Depending on importer settings an asset is a Model holding
-- "<asset>__<component>" MeshParts, a lone MeshPart, or loose MeshParts if the hierarchy was
-- flattened.
local function findKit(): { [string]: Instance }
	local found = {}
	local loose = {}
	for _, root in { workspace, ServerStorage, game:GetService("ReplicatedStorage") } do
		for _, instance in root:GetDescendants() do
			if instance:FindFirstAncestor("LawnKitExport") or instance:FindFirstAncestor("Assets") then
				continue
			end
			local name = instance.Name
			if SIZES[name] and (instance:IsA("Model") or instance:IsA("BasePart")) and not found[name] then
				found[name] = instance
			elseif instance:IsA("BasePart") then
				local asset = name:match("^(.-)__")
				local parent = instance.Parent
				if asset and SIZES[asset] and not (parent and parent.Name == asset) then
					loose[asset] = loose[asset] or {}
					table.insert(loose[asset], instance)
				end
			end
		end
	end
	-- Wrap lone or loose MeshParts in a Model so every asset looks the same.
	for name, instance in found do
		if instance:IsA("BasePart") then
			local model = Instance.new("Model")
			model.Name = name
			model.Parent = instance.Parent
			instance.Parent = model
			found[name] = model
		end
	end
	for name, list in loose do
		if not found[name] then
			local model = Instance.new("Model")
			model.Name = name
			model.Parent = list[1].Parent
			for _, part in list do
				part.Parent = model
			end
			found[name] = model
		end
	end
	return found
end

ChangeHistoryService:SetWaypoint("Before organizing Lawn Mowing kit")

local kit = findKit()
local count = 0
for _ in kit do
	count += 1
end
assert(count > 0, "No Lawn Mowing kit assets found. Import LawnMowing_AllAssets.gltf first.")

local old = ServerStorage:FindFirstChild("LawnKitExport")
if old then
	old:Destroy()
end
local export = Instance.new("Folder")
export.Name = "LawnKitExport"
local kitFolder = Instance.new("Folder")
kitFolder.Name = "Kit"
kitFolder.Parent = export

local importRoots = {}
for name, model in kit do
	local vegetation = isVegetation(name)

	-- The importer wraps each component in its own Model ("<asset>__Body" > MeshPart named after
	-- the Blender mesh). Flatten that so the asset holds MeshParts named "<asset>__<component>".
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child.Name:sub(1, #name + 2) == name .. "__" then
			local meshParts = parts(child)
			if #meshParts == 1 then
				meshParts[1].Name = child.Name
				meshParts[1].Parent = model
				child:Destroy()
			end
		end
	end

	local body = model:FindFirstChild(name .. "__Body") or model:FindFirstChildWhichIsA("BasePart", true)
	model.PrimaryPart = body

	-- Remember where the importer put it so the leftover containers can be cleaned up.
	local root = model.Parent
	while root and root.Parent ~= workspace and root ~= workspace do
		root = root.Parent
	end
	if root and root ~= workspace and root ~= model then
		importRoots[root] = true
	end

	-- Scale to the documented real-world size.
	local size = model:GetExtentsSize()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		model:ScaleTo(model:GetScale() * SIZES[name] / longest)
	end

	for _, part in parts(model) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = not vegetation
		if part:IsA("MeshPart") then
			part.RenderFidelity = Enum.RenderFidelity.Automatic
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end
	end

	-- The importer already turns the kit to face -Z (Roblox's front). Put the pivot on the ground
	-- under the asset, then park it at the origin. A Model with a PrimaryPart ignores WorldPivot,
	-- so the pivot goes in the PrimaryPart's PivotOffset.
	local axes = body.CFrame.Rotation
	local low, high = bounds(parts(model), axes)
	local bottom = axes * Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.new(bottom) * axes)
	model:PivotTo(CFrame.new())

	model:SetAttribute("LawnKitAsset", name)
	model:SetAttribute("LawnKitVegetation", vegetation)
	model.Parent = kitFolder
end

-- Clean up the importer's now-empty containers in Workspace.
for root in importRoots do
	if #parts(root) == 0 then
		root:Destroy()
	end
end

export.Parent = ServerStorage
ChangeHistoryService:SetWaypoint("Organized Lawn Mowing kit")
print(`Lawn kit: {#kitFolder:GetChildren()} assets in ServerStorage.LawnKitExport`)
