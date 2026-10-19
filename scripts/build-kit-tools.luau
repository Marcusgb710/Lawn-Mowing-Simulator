-- Builds hand-held tools from the Lawn Mowing kit templates in assets/Kit.
--
--   lune run scripts/build-kit-tools
--
-- Writes assets/Tools/<item id>.rbxm for every entry in TOOLS below. Each one is the kit asset
-- plus an invisible part named "Handle" where the hand holds it. Assets.tool turns it into a Tool
-- at runtime and welds everything to the handle. A held handle has +Y up and its front (-Z,
-- LookVector) pointing forward, so the handle is upright and faces the asset's front.
--
-- Tweak a grip, re-run this, and Rojo syncs the change into Studio.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local CFrame = roblox.CFrame
local Instance = roblox.Instance
local Vector3 = roblox.Vector3

-- item id (from Shared/Config/Items.luau) -> kit asset and where the hand holds it:
--   fraction  position inside the asset's bounding box: X 0 = left .. 1 = right,
--             Y 0 = bottom .. 1 = top, Z 0 = back .. 1 = front
--   parts     the middle of these components, at their top (e.g. a steering wheel)
local TOOLS = {
	GasPushMower = { asset = "Mower_Push_21in", fraction = Vector3.new(0.5, 0.95, 0.04) },
	RidingMower = { asset = "Mower_LawnTractor_42in", parts = { "SteeringWheel" } },
	ZeroTurnMower = { asset = "Mower_ZeroTurn_52in", parts = { "LapBar_L", "LapBar_R" } },
	ElectricTrimmer = { asset = "Trimmer_Battery", fraction = Vector3.new(0.5, 0.8, 0.2) },
	GasTrimmer = { asset = "Trimmer_Petrol", fraction = Vector3.new(0.5, 0.8, 0.2) },
	OldRake = { asset = "Prop_Rake", fraction = Vector3.new(0.5, 0.75, 0.5) },
}

local function meshParts(root)
	local list = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	return list
end

-- World-space bounding box of some parts.
local function bounds(list)
	local lowX, lowY, lowZ = math.huge, math.huge, math.huge
	local highX, highY, highZ = -math.huge, -math.huge, -math.huge
	for _, part in list do
		local half = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					lowX, lowY, lowZ = math.min(lowX, corner.X), math.min(lowY, corner.Y), math.min(lowZ, corner.Z)
					highX, highY, highZ = math.max(highX, corner.X), math.max(highY, corner.Y), math.max(highZ, corner.Z)
				end
			end
		end
	end
	return Vector3.new(lowX, lowY, lowZ), Vector3.new(highX, highY, highZ)
end

for itemId, spec in TOOLS do
	local source = `assets/Kit/{spec.asset}.rbxm`
	local model = roblox.deserializeModel(fs.readFile(source))[1]
	assert(model, `{source} is empty`)
	model.Name = itemId

	-- Kit templates sit at the origin facing -Z (their pivot's LookVector), so the grip only
	-- needs a position.
	local grip
	if spec.parts then
		local picked = {}
		local sum = Vector3.new(0, 0, 0)
		for _, component in spec.parts do
			local part = model:FindFirstChild(`{spec.asset}__{component}`, true)
			assert(part, `{spec.asset} has no {component}`)
			table.insert(picked, part)
			sum += part.CFrame.Position
		end
		local _, high = bounds(picked)
		local middle = sum / #picked
		grip = Vector3.new(middle.X, high.Y - 0.1, middle.Z)
	else
		local low, high = bounds(meshParts(model))
		local f = spec.fraction
		-- Front is -Z, so Z fraction 1 (front) is the low end.
		grip = Vector3.new(
			low.X + (high.X - low.X) * f.X,
			low.Y + (high.Y - low.Y) * f.Y,
			high.Z + (low.Z - high.Z) * f.Z
		)
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.CFrame = CFrame.new(grip)
	handle.Transparency = 1
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Parent = model
	model.PrimaryPart = handle
	model:SetAttribute("LawnKitAsset", spec.asset)
	-- The kit turns CanQuery off for yard pieces, but players aim at tools to pick them up.
	for _, part in meshParts(model) do
		part.CanQuery = part.Transparency < 1
	end

	fs.writeFile(`assets/Tools/{itemId}.rbxm`, roblox.serializeModel({ model }))
	print(`wrote assets/Tools/{itemId}.rbxm (grip at {grip})`)
end
