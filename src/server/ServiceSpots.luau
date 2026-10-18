-- Where tools are set down to be worked on (see MaintenanceService): a spot on the floor for
-- machines and a vise for hand and long tools. Every workbench has both (its ServiceSpot and
-- VisePoint attachments, or in front of it and on its vise when the model has none), and so does
-- the crew truck on a job: on the ground behind it, and on its open tailgate.

local ServiceSpots = {}

-- The pads you look at to set a tool down there: invisible, and only there to be looked at.
local function pad(parent: Instance, name: string, kind: string, size: Vector3, center: CFrame, frame: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = center
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part:SetAttribute("Interact", "SetDown")
	part:SetAttribute("InteractText", if kind == "Vise" then "Put in the vise" else "Set down")
	part:SetAttribute("InteractName", if kind == "Vise" then "Vise" else "Service spot")
	part:SetAttribute("SpotKind", kind)
	part:SetAttribute("SpotFrame", frame)
	part.Parent = parent
	return part
end

-- Adds both spots to `parent`, with `floor` on the ground and `vise` where the tool's grip goes.
function ServiceSpots.add(parent: Instance, floor: CFrame, vise: CFrame)
	pad(parent, "ServiceSpot", "Floor", Vector3.new(4.5, 0.3, 4.5), floor * CFrame.new(0, 0.15, 0), floor)
	pad(parent, "Vise", "Vise", Vector3.new(1.4, 1.4, 1.4), vise, vise)
end

-- A workbench's spots: its markers, or in front of it and on its vise.
function ServiceSpots.forBench(bench: Model): (CFrame, CFrame)
	local root = bench:FindFirstChild("Root")
	local origin = if root and root:IsA("BasePart") then root.CFrame * CFrame.new(0, -0.5, 0) else bench:GetPivot()
	local spot = bench:FindFirstChild("ServiceSpot", true)
	local vise = bench:FindFirstChild("VisePoint", true)
	local floor = if spot and spot:IsA("Attachment") then spot.WorldCFrame else origin * CFrame.new(0, 0, -3.4)
	local grip = if vise and vise:IsA("Attachment") then vise.WorldCFrame else origin * CFrame.new(-2.8, 3.9, -0.9)
	return floor, grip
end

-- A truck's on a job: on the ground behind it, and on its tailgate.
function ServiceSpots.forTruck(truck: Model): (CFrame, CFrame)
	local box, size = truck:GetBoundingBox()
	local floor = box * CFrame.new(0, -size.Y / 2, size.Z / 2 + 3)
	local vise = box * CFrame.new(0, -size.Y / 2 + 3.4, size.Z / 2 - 0.6)
	return floor, vise
end

-- Where a truck's tailgate supplies stand: a row beside the floor spot.
function ServiceSpots.supplyRow(floor: CFrame, index: number): CFrame
	return floor * CFrame.new(3.4 + (index - 1) * 1.5, 0, 0)
end

return ServiceSpots
