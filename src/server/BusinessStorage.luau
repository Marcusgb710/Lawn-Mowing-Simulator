-- Builds the storage on a business plot: pegboards, wall racks, wall hooks and shelves on two
-- walls, plus floor spots and equipment bays, as many as the building holds (Items.luau).
--
-- Every spot a tool can go in is an Attachment in the plot's Storage.Spots part, with attributes:
--   Spot        the kind of spot (Storage.Spots)
--   Index       its number among spots of that kind
--   Mount       how a tool sits there: "Hang" (flat on a pegboard), "Hook" (hanging off a hook),
--               "Stand" (upright in a wall rack) or "Place" (on a shelf or the floor)
--   Depth       on wall spots: how far out from the wall the spot is
--   ManualOnly  on floor spots that don't take machines with an engine
-- CarryController lays each player's own tools out on them. Tools without a free spot go in a
-- row on the ground, starting at the attachment named "Overflow".
--
-- Layout, in the plot's own space (the street is toward -Z, the building's front at z = 14):
--   right edge, x = 29    pegboards (two high), then wall racks, running toward the street
--   left edge, x = -29    wall hooks, then shelves
--   middle, z = 4         floor spots on the right, equipment bays on the left
--   z = -7, x = 8         tools without a spot

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Items = require(Shared.Config.Items)
local Storage = require(Shared.Config.Storage)

local BusinessStorage = {}

-- How high each fixture's bottom edge is mounted on the wall. Tune these in Studio.
local MOUNT_HEIGHT = { Pegboard = 2, WallRack = 3, WallHooks = 4.5, Shelf = 0 }
local MOUNTS = { Pegboard = "Hang", WallRack = "Stand", WallHooks = "Hook", Shelf = "Place" }
-- Pegboards are stacked this many high.
local PEGBOARD_ROWS = 2
local FIXTURE_GAP = 0.5
local GROUP_GAP = 1.5
local WALL_HEIGHT = 10

-- Each wall runs from near the building toward the street. `frame` stands on the wall's first
-- end and faces into the plot; `run` is which way along the wall (its X) the fixtures go.
local WALLS = {
	{ frame = CFrame.new(29, 0, 13) * CFrame.Angles(0, math.pi / 2, 0), run = 1, spots = { "Pegboard", "WallRack" } },
	{ frame = CFrame.new(-29, 0, 13) * CFrame.Angles(0, -math.pi / 2, 0), run = -1, spots = { "WallHooks", "Shelf" } },
}

local FLOOR_ROW = { start = Vector3.new(25, 0, 4), step = Vector3.new(-3.9, 0, 0), size = Vector3.new(3.6, 0.1, 4.4) }
local BAY_ROW = { start = Vector3.new(-24, 0, 4), step = Vector3.new(6.2, 0, 0), size = Vector3.new(5.6, 0.1, 8) }
local OVERFLOW = CFrame.new(8, 0, -7)

local COLORS = {
	Wall = Color3.fromRGB(150, 120, 85),
	Pad = Color3.fromRGB(175, 175, 170),
	Bay = Color3.fromRGB(205, 175, 60),
}

local function newPart(parent: Instance, props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function label(target: BasePart, text: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Parent = gui
	gui.Parent = target
end

-- Makes sure a fixture model has Slot1..SlotN attachments. A real model without them gets them
-- spread over its front, so it still works. Call before the model is moved: models are built
-- facing -Z, so the bounding box lines up with how they face.
local function ensureSlots(model: Model, count: number)
	local found = 0
	for _, descendant in model:GetDescendants() do
		local index = descendant:IsA("Attachment") and tonumber(string.match(descendant.Name, "^Slot(%d+)$"))
		if index and index <= count then
			found += 1
		end
	end
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if found >= count or not holder then
		return
	end
	local box, size = model:GetBoundingBox()
	local columns = if count > 4 then 3 else count
	local rows = math.ceil(count / columns)
	for index = 1, count do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local slot = Instance.new("Attachment")
		slot.Name = "Slot" .. index
		slot.Parent = holder
		slot.WorldPosition = box
			* Vector3.new(
				((column + 0.5) / columns - 0.5) * size.X,
				(0.5 - (row + 0.5) / rows) * size.Y,
				-size.Z / 2 - 0.2
			)
	end
end

-- World positions of a fixture's slots, Slot1 first.
local function slotPositions(model: Model, count: number): { Vector3 }
	local byIndex = {}
	for _, descendant in model:GetDescendants() do
		local index = descendant:IsA("Attachment") and tonumber(string.match(descendant.Name, "^Slot(%d+)$"))
		if index then
			byIndex[index] = (descendant :: Attachment).WorldPosition
		end
	end
	local list = {}
	for index = 1, count do
		if byIndex[index] then
			table.insert(list, byIndex[index])
		end
	end
	return list
end

-- Builds a business's storage under `parent`, laid out from the plot's `origin`.
function BusinessStorage.build(parent: Instance, origin: CFrame, businessId: string): Folder
	local business = Items.get("Business", businessId) or Items.Catalog.Business[1]
	local folder = Instance.new("Folder")
	folder.Name = "Storage"
	folder:SetAttribute("FloorY", origin.Position.Y)

	local holder = newPart(folder, {
		Name = "Spots",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin,
		Transparency = 1,
		CanQuery = false,
	})
	local function addSpot(spot: string, index: number, frame: CFrame, mount: string)
		local attachment = Instance.new("Attachment")
		attachment.Name = spot .. index
		attachment.Parent = holder
		attachment.WorldCFrame = frame
		attachment:SetAttribute("Spot", spot)
		attachment:SetAttribute("Index", index)
		attachment:SetAttribute("Mount", mount)
		return attachment
	end
	-- Parts players stand near to pick up or put back tools (see WorldService:IsNearStorage).
	local function area(part: BasePart)
		part:SetAttribute("StorageArea", true)
	end

	-- Fixtures on the walls.
	for _, wall in WALLS do
		local frame = origin * wall.frame
		local cursor = 0
		for _, spot in wall.spots do
			local capacity = Storage.capacity(business.id, spot)
			if capacity <= 0 then
				continue
			end
			local info = Storage.Spots[spot]
			local rows = if spot == "Pegboard" then PEGBOARD_ROWS else 1
			local fixtures = math.ceil(capacity / info.perFixture)
			local groupStart = cursor
			local index = 0
			for number = 1, fixtures do
				local model = Assets.prop(info.fixture)
				Assets.anchor(model)
				ensureSlots(model, info.perFixture)
				local _, size = model:GetBoundingBox()
				local row = (number - 1) % rows
				local x = cursor + size.X / 2
				local y = MOUNT_HEIGHT[spot] + row * (size.Y + FIXTURE_GAP)
				Assets.placeAt(model, frame * CFrame.new(wall.run * x, y, 0))
				model.Parent = folder

				for _, position in slotPositions(model, info.perFixture) do
					index += 1
					if index <= capacity then
						local wallSpot = addSpot(spot, index, CFrame.new(position) * frame.Rotation, MOUNTS[spot])
						wallSpot:SetAttribute("Depth", -frame:PointToObjectSpace(position).Z)
					end
				end
				if row == rows - 1 or number == fixtures then
					cursor += size.X + FIXTURE_GAP
				end
			end

			local sign = newPart(folder, {
				Name = "StorageSign",
				Size = Vector3.new(cursor - groupStart, 0.9, 0.1),
				CFrame = frame * CFrame.new(wall.run * (groupStart + cursor) / 2, WALL_HEIGHT - 0.7, -0.1),
				Transparency = 1,
				CanQuery = false,
			})
			label(sign, string.upper(info.holds), Enum.NormalId.Front)
			cursor += GROUP_GAP
		end

		if cursor > 0 then
			area(newPart(folder, {
				Name = "StorageWall",
				Size = Vector3.new(cursor, WALL_HEIGHT, 0.4),
				CFrame = frame * CFrame.new(wall.run * cursor / 2, WALL_HEIGHT / 2, 0.2),
				Color = COLORS.Wall,
				Material = Enum.Material.WoodPlanks,
				CanCollide = true,
			}))
		end
	end

	-- Floor spots and equipment bays, painted on the ground.
	for _, row in { { spot = "Floor", layout = FLOOR_ROW }, { spot = "Bay", layout = BAY_ROW } } do
		for index = 1, Storage.capacity(business.id, row.spot) do
			local ground = origin * CFrame.new(row.layout.start + row.layout.step * (index - 1))
			local pad = newPart(folder, {
				Name = row.spot .. "Pad",
				Size = row.layout.size,
				CFrame = ground * CFrame.new(0, row.layout.size.Y / 2, 0),
				Color = if row.spot == "Bay" then COLORS.Bay else COLORS.Pad,
				Material = Enum.Material.Concrete,
			})
			area(pad)
			local manualOnly = row.spot == "Floor" and business.noEngines == true
			local text = if row.spot == "Bay" then `BAY {index}` elseif manualOnly then "NO ENGINES" else "FLOOR"
			label(pad, text, Enum.NormalId.Top)
			local spot = addSpot(row.spot, index, ground * CFrame.new(0, row.layout.size.Y, 0), "Place")
			if manualOnly then
				spot:SetAttribute("ManualOnly", true)
			end
		end
	end

	-- Tools without a spot are kept on the ground here.
	local overflow = Instance.new("Attachment")
	overflow.Name = "Overflow"
	overflow.Parent = holder
	overflow.WorldCFrame = origin * OVERFLOW
	area(newPart(folder, {
		Name = "OverflowArea",
		Size = Vector3.new(20, 0.1, 9),
		CFrame = origin * OVERFLOW * CFrame.new(9, 0.05, -2),
		Transparency = 1,
		CanQuery = false,
	}))

	folder.Parent = parent
	return folder
end

return BusinessStorage
