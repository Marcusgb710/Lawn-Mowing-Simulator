-- Block-model stand-ins used until the real models exist in ReplicatedStorage.Assets.
-- Nothing else in the game depends on what these look like, so feel free to delete them later.

local Items = require(script.Parent.Config.Items)
local Tools = require(script.Parent.Config.Tools)

local Placeholders = {}

local function part(props): BasePart
	local className = props.ClassName or "Part"
	props.ClassName = nil
	local newPart = Instance.new(className) :: BasePart
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(newPart :: any)[key] = value
	end
	return newPart
end

-- Tools -------------------------------------------------------------------------------------

-- Placeholder tools are built with the handle's +Y axis pointing forward out of the hand and +Z
-- pointing up. Placeholders.tool turns the grip so they're held that way.
local function attach(tool: Tool, handle: BasePart, offset: CFrame, props)
	props.CanCollide = false
	props.Massless = true
	props.CFrame = handle.CFrame * offset
	local extra = part(props)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = extra
	weld.Parent = extra
	extra.Parent = tool
	return extra
end

local function shaftTool(tool: Tool, item, length: number, head)
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.3, length, 0.3),
		Color = Color3.fromRGB(90, 90, 90),
		CanCollide = false,
	})
	handle.Parent = tool
	-- Hold the shaft near one end and tilt it toward the ground.
	tool.Grip = CFrame.new(0, -length / 2 + 0.6, 0) * CFrame.Angles(math.rad(40), 0, 0)
	head.Color = item.color
	attach(tool, handle, CFrame.new(0, length / 2, 0), head)
	return handle
end

local TOOL_BUILDERS = {
	Mower = function(tool: Tool, item)
		local handle = part({
			Name = "Handle",
			Size = Vector3.new(2, 0.3, 0.3),
			Color = Color3.fromRGB(40, 40, 40),
			CanCollide = false,
		})
		handle.Parent = tool
		local deckSize = if item.sizeClass == "Bay" then Vector3.new(4.5, 4.5, 1.4) else Vector3.new(2.6, 2.6, 1)
		attach(tool, handle, CFrame.new(0, 1.2, -1), {
			Name = "Bar",
			Size = Vector3.new(0.2, 2.6, 0.2),
			Color = Color3.fromRGB(40, 40, 40),
		})
		attach(tool, handle, CFrame.new(0, 1.4 + deckSize.Y / 2, -2.2), {
			Name = "Deck",
			Size = deckSize,
			Color = item.color,
		})
		return handle
	end,

	Trimmer = function(tool: Tool, item)
		return shaftTool(tool, item, 4.5, {
			Name = "Head",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 1.2, 1.2),
		})
	end,

	Rake = function(tool: Tool, item)
		return shaftTool(tool, item, 5, {
			Name = "Head",
			Size = Vector3.new(2.4, 0.3, 0.4),
		})
	end,

	Edger = function(tool: Tool, item)
		return shaftTool(tool, item, 4, {
			Name = "Blade",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1.4, 1.4),
		})
	end,

	HedgeTrimmer = function(tool: Tool, item)
		local handle = part({
			Name = "Handle",
			Size = Vector3.new(0.5, 1.4, 0.5),
			Color = item.color,
			CanCollide = false,
		})
		handle.Parent = tool
		attach(tool, handle, CFrame.new(0, 2.2, 0), {
			Name = "Blade",
			Size = Vector3.new(0.4, 3, 0.15),
			Color = Color3.fromRGB(200, 200, 200),
		})
		return handle
	end,
}

-- Tools in categories without their own builder get a shape by how big they are.
local SIZE_BUILDERS = {
	Hand = function(tool: Tool, item)
		return shaftTool(tool, item, 1.4, { Name = "Head", Size = Vector3.new(0.6, 0.6, 0.2) })
	end,
	Long = function(tool: Tool, item)
		return shaftTool(tool, item, 5, { Name = "Head", Size = Vector3.new(1.2, 0.8, 0.3) })
	end,
	HangingPower = TOOL_BUILDERS.Trimmer,
	FloorManual = TOOL_BUILDERS.Mower,
	FloorEngine = TOOL_BUILDERS.Mower,
	Bay = TOOL_BUILDERS.Mower,
	Supply = function(tool: Tool, item)
		local handle = part({ Name = "Handle", Size = Vector3.new(1, 1, 1), Color = item.color, CanCollide = false })
		handle.Parent = tool
		return handle
	end,
}

function Placeholders.tool(category: string, itemId: string): Tool
	local item = Tools.get(itemId) or Items.get(category, itemId)
	local tool = Instance.new("Tool")
	tool.Name = item.name
	local builder = TOOL_BUILDERS[category] or SIZE_BUILDERS[item.sizeClass] or SIZE_BUILDERS.Hand
	builder(tool, item)
	-- A held handle really has +Y up and -Z forward, so tip the builders' layout forward.
	tool.Grip *= CFrame.Angles(math.pi / 2, 0, 0)
	return tool
end

-- Trucks ------------------------------------------------------------------------------------

-- Invisible part marking where loaded tools sit. Real models can include their own "BedArea"
-- parts to control where tools show up. (Its Slots attribute is only a hint for modelers: how
-- much a vehicle carries comes from `space` in Items.luau.)
local function bedArea(model: Model, size: Vector3, position: Vector3, slots: number)
	local area = part({
		Name = "BedArea",
		Size = size,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Anchored = true,
	})
	area:SetAttribute("Slots", slots)
	area.Parent = model
end

-- Trucks face their PrimaryPart's LookVector (-Z).
function Placeholders.truck(itemId: string): Model
	local item = Items.get("Truck", itemId)
	local model = Instance.new("Model")
	model.Name = item.name

	local function add(props)
		props.Anchored = true
		local newPart = part(props)
		newPart.Parent = model
		return newPart
	end

	local base = add({
		Name = "Base",
		Size = Vector3.new(7, 1, 16),
		Position = Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(50, 50, 50),
	})
	model.PrimaryPart = base

	add({ Name = "Hood", Size = Vector3.new(7, 2.5, 3), Position = Vector3.new(0, 3.35, -6.5), Color = item.color })
	add({ Name = "Cab", Size = Vector3.new(7, 4.5, 5), Position = Vector3.new(0, 4.35, -2.5), Color = item.color })
	add({
		Name = "Windshield",
		Size = Vector3.new(6.2, 2, 0.2),
		Position = Vector3.new(0, 5.3, -5.05),
		Color = Color3.fromRGB(150, 200, 230),
		Transparency = 0.3,
	})
	-- The driver's door on the left, hinged at its front edge like the real models
	-- (alphainstructions/instructions25.md), and where the driver's eyes are.
	local door = add({
		Name = itemId .. "__DriverDoor",
		Size = Vector3.new(0.15, 2.6, 3),
		Position = Vector3.new(-3.6, 3.6, -2.5),
		Color = item.color:Lerp(Color3.new(1, 1, 1), 0.1),
	})
	door.PivotOffset = CFrame.new(0, 0, -1.5)
	local glass = add({
		Name = itemId .. "__DriverDoorGlass",
		Size = Vector3.new(0.1, 1.4, 2.6),
		Position = Vector3.new(-3.6, 5.6, -2.5),
		Color = Color3.fromRGB(150, 200, 230),
		Transparency = 0.4,
	})
	glass.PivotOffset = CFrame.new(0, 0, -1.3)
	local seat = Instance.new("Attachment")
	seat.Name = "DriverSeat"
	seat.Parent = base
	seat.WorldCFrame = CFrame.new(-1.6, 5.2, -2.2)

	if itemId == "LandscapingTruck" then
		add({ Name = "Box", Size = Vector3.new(7.4, 6, 8), Position = Vector3.new(0, 5.1, 4), Color = item.color })
	else
		local bedColor = item.color:Lerp(Color3.new(0, 0, 0), 0.2)
		add({ Name = "BedLeft", Size = Vector3.new(0.4, 2, 8), Position = Vector3.new(-3.3, 3.1, 4), Color = bedColor })
		add({ Name = "BedRight", Size = Vector3.new(0.4, 2, 8), Position = Vector3.new(3.3, 3.1, 4), Color = bedColor })
		local tailgate = add({
			Name = itemId .. "__Tailgate",
			Size = Vector3.new(7, 2, 0.4),
			Position = Vector3.new(0, 3.1, 7.8),
			Color = bedColor,
		})
		-- Hinged at its bottom edge.
		tailgate.PivotOffset = CFrame.new(0, -1, 0)
	end

	bedArea(model, Vector3.new(6, 0.2, 7.6), Vector3.new(0, 2.2, 4), item.space)

	for _, x in { -3.6, 3.6 } do
		for _, z in { -5.5, 5.5 } do
			add({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 2.6, 2.6),
				Position = Vector3.new(x, 1.3, z),
				Color = Color3.fromRGB(25, 25, 25),
			})
		end
	end

	return model
end

-- A low flatbed: a small BedArea for tools up front, then two "BaySpot" parts where ride-on
-- machines park (like the real model, alphainstructions/instructions21.md).
local function equipmentTrailer(model: Model, item, add): Model
	local length = 16
	model.PrimaryPart = add({
		Name = "Deck",
		Size = Vector3.new(7, 0.4, length),
		Position = Vector3.new(0, 1.6, 0),
		Color = item.color,
	})
	add({
		Name = "Tongue",
		Size = Vector3.new(0.6, 0.4, 3),
		Position = Vector3.new(0, 1.5, -length / 2 - 1.5),
		Color = Color3.fromRGB(40, 40, 40),
	})
	add({
		Name = "Ramp",
		Size = Vector3.new(6.4, 2.6, 0.2),
		Position = Vector3.new(0, 3.1, length / 2 - 0.1),
		Color = Color3.fromRGB(80, 80, 85),
		Transparency = 0.3,
	})
	for _, x in { -3.7, 3.7 } do
		for _, z in { -0.2, 1.8 } do
			add({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 1.8, 1.8),
				Position = Vector3.new(x, 0.9, z),
				Color = Color3.fromRGB(25, 25, 25),
			})
		end
	end
	local front = -length / 2
	bedArea(model, Vector3.new(6, 0.2, 3), Vector3.new(0, 1.9, front + 1.7), item.space)
	for index = 1, item.bays do
		add({
			Name = "BaySpot",
			Size = Vector3.new(6, 0.2, 6),
			Position = Vector3.new(0, 1.9, front + 3.4 + (index - 0.5) * 6.2),
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
	end
	return model
end

-- Trailers face -Z too, with the hitch at the front.
function Placeholders.trailer(itemId: string): Model
	local item = Items.get("Trailer", itemId)
	local model = Instance.new("Model")
	model.Name = item.name

	local function add(props)
		props.Anchored = true
		local newPart = part(props)
		newPart.Parent = model
		return newPart
	end

	if itemId == "EquipmentTrailer" then
		return equipmentTrailer(model, item, add)
	end

	local enclosed = itemId == "LandscapeTrailer"
	local length = if enclosed then 11 else 9
	local bed = add({
		Name = "Bed",
		Size = Vector3.new(7, 0.6, length),
		Position = Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(70, 70, 70),
	})
	model.PrimaryPart = bed

	add({
		Name = "Tongue",
		Size = Vector3.new(0.6, 0.4, 3),
		Position = Vector3.new(0, 1.5, -length / 2 - 1.5),
		Color = Color3.fromRGB(40, 40, 40),
	})
	if enclosed then
		add({ Name = "Box", Size = Vector3.new(7.2, 6, length), Position = Vector3.new(0, 4.9, 0), Color = item.color })
	else
		for _, x in { -3.35, 3.35 } do
			add({
				Name = "Rail",
				Size = Vector3.new(0.3, 1.2, length),
				Position = Vector3.new(x, 2.5, 0),
				Color = item.color,
			})
		end
	end
	for _, x in { -3.7, 3.7 } do
		add({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 2, 2),
			Position = Vector3.new(x, 1, 0),
			Color = Color3.fromRGB(25, 25, 25),
		})
	end
	bedArea(model, Vector3.new(6, 0.2, length - 1), Vector3.new(0, 2, 0), item.space)

	return model
end

-- Business buildings ------------------------------------------------------------------------

-- Buildings face -Z (front door toward the street), bottom at y = 0.
local BUILDING_SIZES = {
	Shed = Vector3.new(12, 10, 10),
	Garage = Vector3.new(26, 14, 20),
	SmallOffice = Vector3.new(36, 16, 24),
	EquipmentYard = Vector3.new(44, 18, 30),
}

function Placeholders.building(itemId: string): Model
	local item = Items.get("Business", itemId)
	local model = Instance.new("Model")
	model.Name = item.name
	local size = BUILDING_SIZES[itemId] or BUILDING_SIZES.Shed

	local function add(props)
		props.Anchored = true
		local newPart = part(props)
		newPart.Parent = model
		return newPart
	end

	model.PrimaryPart = add({
		Name = "Walls",
		Size = size,
		Position = Vector3.new(0, size.Y / 2, size.Z / 2),
		Color = item.color,
		Material = if itemId == "Shed" then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic,
	})
	add({
		ClassName = "WedgePart",
		Name = "Roof",
		Size = Vector3.new(size.X + 2, size.Y * 0.3, size.Z + 2),
		CFrame = CFrame.new(0, size.Y + size.Y * 0.15, size.Z / 2) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(90, 50, 40),
	})

	if itemId == "Shed" then
		add({
			Name = "Door",
			Size = Vector3.new(5, 7, 0.3),
			Position = Vector3.new(0, 3.5, -0.15),
			Color = Color3.fromRGB(110, 70, 40),
		})
	else
		add({
			Name = "GarageDoor",
			Size = Vector3.new(12, 9, 0.3),
			Position = Vector3.new(-size.X / 2 + 8, 4.5, -0.15),
			Color = Color3.fromRGB(160, 160, 160),
		})
		add({
			Name = "Door",
			Size = Vector3.new(4, 7, 0.3),
			Position = Vector3.new(size.X / 2 - 5, 3.5, -0.15),
			Color = Color3.fromRGB(110, 70, 40),
		})
	end
	if itemId == "SmallOffice" or itemId == "EquipmentYard" then
		for _, x in { 2, 9 } do
			add({
				Name = "Window",
				Size = Vector3.new(5, 4, 0.3),
				Position = Vector3.new(x, 9, -0.15),
				Color = Color3.fromRGB(150, 200, 230),
			})
		end
	end

	return model
end

-- Props -------------------------------------------------------------------------------------

local function propAdder(model: Model)
	return function(props)
		props.Anchored = true
		local newPart = part(props)
		newPart.Parent = model
		return newPart
	end
end

-- Storage fixtures are built like the real models (alphainstructions/instructions23.md): back flat
-- on Z = 0, front toward -Z, bottom at Y = 0, a "Root" part, and one "Slot" attachment per tool.
local function fixture(model: Model, color: Color3, size: Vector3, slots: { Vector3 }, extras: { any })
	local add = propAdder(model)
	model.PrimaryPart = add({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	local panel = add({
		Name = "Panel",
		Size = size,
		Position = Vector3.new(0, size.Y / 2, -size.Z / 2),
		Color = color,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	for _, props in extras do
		props.Color = props.Color or Color3.fromRGB(70, 70, 75)
		props.CanCollide = false
		add(props)
	end
	for index, position in slots do
		local slot = Instance.new("Attachment")
		slot.Name = "Slot" .. index
		slot.Position = panel.CFrame:PointToObjectSpace(position)
		slot.Parent = panel
	end
end

-- An attachment on the model's Root, at a spot in model space (the model is built at the origin).
local function marker(model: Model, name: string, frame: CFrame)
	local root = model.PrimaryPart :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = root
	attachment.WorldCFrame = frame
	return attachment
end

local function rootPart(model: Model, add)
	model.PrimaryPart = add({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
end

-- A job computer desk like the real ones (alphainstructions/instructions33.md): front toward -Z
-- where the player sits, a flat 16:9 `<Id>__Screen` facing -Z, a `<Id>__Chair`, a UseSpot on
-- the floor in front (facing the desk) and a ScreenView where the camera goes.
local function desk(model: Model, id: string, size: Vector3, color: Color3, screens: number)
	local add = propAdder(model)
	rootPart(model, add)
	local top = 2.5
	add({
		Name = id .. "__Body",
		Size = Vector3.new(size.X, 0.25, size.Z),
		Position = Vector3.new(0, top, 0),
		Color = color,
	})
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			add({
				Name = id .. "__Body",
				Size = Vector3.new(0.2, top, 0.2),
				Position = Vector3.new(x * (size.X / 2 - 0.2), top / 2, z * (size.Z / 2 - 0.2)),
				Color = Color3.fromRGB(80, 80, 85),
			})
		end
	end
	local screenWidth, screenHeight = 1.9, 1.9 * 9 / 16
	local screenZ = size.Z / 2 - 0.6
	local screenY = top + 0.35 + screenHeight / 2
	for index = 1, screens do
		local x = if screens == 1 then 0 else (index - 1.5) * (screenWidth + 0.3)
		add({
			Name = id .. "__Body",
			Size = Vector3.new(screenWidth + 0.15, screenHeight + 0.15, 0.12),
			Position = Vector3.new(x, screenY, screenZ + 0.07),
			Color = Color3.fromRGB(35, 35, 40),
		})
		add({
			Name = id .. "__Screen" .. (if index == 1 then "" else tostring(index)),
			Size = Vector3.new(screenWidth, screenHeight, 0.02),
			Position = Vector3.new(x, screenY, screenZ - 0.01),
			Color = Color3.fromRGB(60, 62, 70),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	add({
		Name = id .. "__Chair",
		Size = Vector3.new(1.4, 1.6, 1.4),
		Position = Vector3.new(0, 0.8, -size.Z / 2 - 1),
		Color = Color3.fromRGB(50, 55, 65),
		CanCollide = false,
	})
	local mainX = if screens == 1 then 0 else -(screenWidth + 0.3) / 2
	local screenCenter = Vector3.new(mainX, screenY, screenZ)
	marker(model, "UseSpot", CFrame.lookAt(Vector3.new(mainX, 0, -size.Z / 2 - 2.2), Vector3.new(mainX, 0, screenZ)))
	marker(model, "ScreenView", CFrame.lookAt(screenCenter + Vector3.new(0, 0.1, -2.5), screenCenter))
end

-- A delivery box: a body open at the top, its lid or flaps as their own parts with their pivot on
-- their hinge, and a Contents attachment on the inside floor.
local function box(model: Model, id: string, size: Vector3, lids: { any }, openFront: boolean?)
	local add = propAdder(model)
	rootPart(model, add)
	local color = Color3.fromRGB(175, 135, 90)
	local wall = 0.05
	local sides = {
		{ Vector3.new(size.X, size.Y, wall), Vector3.new(0, size.Y / 2, -size.Z / 2 + wall / 2) },
		{ Vector3.new(size.X, size.Y, wall), Vector3.new(0, size.Y / 2, size.Z / 2 - wall / 2) },
		{ Vector3.new(wall, size.Y, size.Z), Vector3.new(-size.X / 2 + wall / 2, size.Y / 2, 0) },
		{ Vector3.new(wall, size.Y, size.Z), Vector3.new(size.X / 2 - wall / 2, size.Y / 2, 0) },
		{ Vector3.new(size.X, wall, size.Z), Vector3.new(0, wall / 2, 0) },
	}
	-- A crate's front is its own panel instead.
	for index, side in sides do
		if not (openFront and index == 1) then
			add({ Name = id .. "__Body", Size = side[1], Position = side[2], Color = color })
		end
	end
	for _, lid in lids do
		local piece = add({
			Name = id .. "__" .. lid.name,
			Size = lid.size,
			Position = lid.position,
			Color = Color3.fromRGB(190, 150, 100),
		})
		-- The pivot sits on the hinge line, as on the real models.
		piece.PivotOffset = CFrame.new(lid.hinge - lid.position)
	end
	marker(model, "Contents", CFrame.new(0, wall, 0))
end

local function boxFlaps(size: Vector3, names: { string }): { any }
	local flaps = {}
	local top = size.Y
	for _, name in names do
		if name == "FlapL" or name == "FlapR" then
			-- Hinged on the long top edges (front and back).
			local sign = if name == "FlapL" then -1 else 1
			table.insert(flaps, {
				name = name,
				size = Vector3.new(size.X, 0.04, size.Z / 2),
				position = Vector3.new(0, top, sign * size.Z / 4),
				hinge = Vector3.new(0, top, sign * size.Z / 2),
			})
		elseif name == "FlapF" or name == "FlapB" then
			local sign = if name == "FlapF" then -1 else 1
			table.insert(flaps, {
				name = name,
				size = Vector3.new(size.X / 2, 0.03, size.Z),
				position = Vector3.new(sign * size.X / 4, top + 0.04, 0),
				hinge = Vector3.new(sign * size.X / 2, top + 0.04, 0),
			})
		end
	end
	return flaps
end

local PROP_BUILDERS = {
	-- 3 x 2 hooks for hand tools.
	StoragePegboard = function(model: Model)
		local slots, hooks = {}, {}
		for _, y in { 2.4, 1.1 } do
			for _, x in { -1.5, 0, 1.5 } do
				table.insert(slots, Vector3.new(x, y, -0.6))
				table.insert(
					hooks,
					{ Name = "Hook", Size = Vector3.new(0.1, 0.1, 0.45), Position = Vector3.new(x, y, -0.42) }
				)
			end
		end
		fixture(model, Color3.fromRGB(165, 125, 80), Vector3.new(4.5, 3, 0.2), slots, hooks)
	end,

	-- 4 holders that keep long-handled tools standing upright.
	StorageWallRack = function(model: Model)
		local slots = {}
		for index = 1, 4 do
			table.insert(slots, Vector3.new((index - 2.5) * 1.25, 0.75, -0.5))
		end
		fixture(model, Color3.fromRGB(120, 90, 60), Vector3.new(5, 1.5, 0.15), slots, {
			{ Name = "Holders", Size = Vector3.new(5, 0.25, 0.15), Position = Vector3.new(0, 1.2, -0.72) },
			{
				Name = "Arms",
				Size = Vector3.new(5, 0.25, 0.6),
				Position = Vector3.new(0, 1.2, -0.45),
				Transparency = 0.6,
			},
		})
	end,

	-- 2 big hooks for string trimmers and blowers.
	StorageWallHooks = function(model: Model)
		local slots, hooks = {}, {}
		for _, x in { -0.9, 0.9 } do
			table.insert(slots, Vector3.new(x, 0.5, -0.65))
			table.insert(
				hooks,
				{ Name = "Hook", Size = Vector3.new(0.25, 0.25, 0.6), Position = Vector3.new(x, 0.5, -0.5) }
			)
		end
		fixture(model, Color3.fromRGB(110, 80, 55), Vector3.new(3.5, 1, 0.2), slots, hooks)
	end,

	-- A sturdy bench with a vise and a pegboard back, standing at -Z.
	Workbench = function(model: Model)
		local add = propAdder(model)
		model.PrimaryPart = add({
			Name = "Root",
			Size = Vector3.new(1, 1, 1),
			Position = Vector3.new(0, 0.5, 0),
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
		local wood = Color3.fromRGB(150, 110, 70)
		add({ Name = "Top", Size = Vector3.new(6.5, 0.3, 2.2), Position = Vector3.new(0, 3.15, 0), Color = wood })
		add({ Name = "Shelf", Size = Vector3.new(6.1, 0.2, 1.9), Position = Vector3.new(0, 0.8, 0), Color = wood })
		for _, x in { -3, 3 } do
			for _, z in { -0.9, 0.9 } do
				add({ Name = "Leg", Size = Vector3.new(0.3, 3, 0.3), Position = Vector3.new(x, 1.5, z), Color = wood })
			end
		end
		add({
			Name = "Pegboard",
			Size = Vector3.new(6.5, 2.7, 0.15),
			Position = Vector3.new(0, 4.65, 1.05),
			Color = Color3.fromRGB(175, 135, 90),
		})
		add({
			Name = "Vise",
			Size = Vector3.new(0.7, 0.6, 0.8),
			Position = Vector3.new(-2.8, 3.6, -0.9),
			Color = Color3.fromRGB(60, 70, 90),
		})
	end,

	-- A floor-standing metal shelf: 3 boards with room for 2 supplies each.
	StorageShelf = function(model: Model)
		local slots, extras = {}, {}
		for _, y in { 3.9, 2.1, 0.3 } do
			table.insert(
				extras,
				{ Name = "Board", Size = Vector3.new(4, 0.15, 1.4), Position = Vector3.new(0, y - 0.075, -0.75) }
			)
			for _, x in { -1, 1 } do
				table.insert(slots, Vector3.new(x, y, -0.75))
			end
		end
		for _, x in { -1.95, 1.95 } do
			table.insert(
				extras,
				{ Name = "Post", Size = Vector3.new(0.1, 5, 1.4), Position = Vector3.new(x, 2.5, -0.75) }
			)
		end
		fixture(model, Color3.fromRGB(150, 150, 155), Vector3.new(4, 5, 0.05), slots, extras)
	end,

	-- A ring of mulch with flowers on it. Customers get upset if you mow these.
	FlowerPatch = function(model: Model)
		local add = propAdder(model)
		model.PrimaryPart = add({
			Name = "Mulch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 3.6, 3.6),
			CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Ground,
		})
		local colors = { Color3.fromRGB(240, 80, 120), Color3.fromRGB(250, 220, 60), Color3.fromRGB(150, 90, 230) }
		for index = 1, 5 do
			local angle = index / 5 * math.pi * 2
			add({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				Position = Vector3.new(math.cos(angle) * 1, 1, math.sin(angle) * 1),
				Color = colors[index % #colors + 1],
			})
		end
	end,

	GardenGnome = function(model: Model)
		local add = propAdder(model)
		model.PrimaryPart = add({
			Name = "Body",
			Size = Vector3.new(1, 1.4, 1),
			Position = Vector3.new(0, 0.7, 0),
			Color = Color3.fromRGB(50, 90, 200),
		})
		add({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			Position = Vector3.new(0, 1.8, 0),
			Color = Color3.fromRGB(240, 200, 170),
		})
		add({
			Name = "Beard",
			Size = Vector3.new(0.7, 0.6, 0.3),
			Position = Vector3.new(0, 1.5, -0.45),
			Color = Color3.fromRGB(245, 245, 245),
		})
		add({
			Name = "Hat",
			Size = Vector3.new(0.7, 0.9, 0.7),
			Position = Vector3.new(0, 2.6, 0),
			Color = Color3.fromRGB(210, 40, 40),
		})
	end,

	-- The front of the house faces -Z (toward the street).
	House = function(model: Model)
		local width = 30
		local function add(props)
			props.Anchored = true
			local newPart = part(props)
			newPart.Parent = model
			return newPart
		end

		local walls = add({
			Name = "Walls",
			Size = Vector3.new(width, 12, 18),
			Position = Vector3.new(0, 6, 9),
			Color = Color3.fromRGB(230, 215, 180),
		})
		model.PrimaryPart = walls

		local roofColor = Color3.fromRGB(110, 50, 40)
		add({
			ClassName = "WedgePart",
			Name = "RoofFront",
			Size = Vector3.new(width + 2, 6, 9.5),
			CFrame = CFrame.new(0, 15, 4.25),
			Color = roofColor,
		})
		add({
			ClassName = "WedgePart",
			Name = "RoofBack",
			Size = Vector3.new(width + 2, 6, 9.5),
			CFrame = CFrame.new(0, 15, 13.75) * CFrame.Angles(0, math.pi, 0),
			Color = roofColor,
		})
		add({
			Name = "Door",
			Size = Vector3.new(4, 7, 0.4),
			Position = Vector3.new(0, 3.5, -0.2),
			Color = Color3.fromRGB(110, 70, 40),
		})
		for _, x in { -width / 4, width / 4 } do
			add({
				Name = "Window",
				Size = Vector3.new(5, 3.5, 0.3),
				Position = Vector3.new(x, 7, -0.15),
				Color = Color3.fromRGB(150, 200, 230),
			})
		end
	end,
}

-- Job computer desks, one per business tier.
PROP_BUILDERS.JobLaptopTable = function(model: Model)
	desk(model, "JobLaptopTable", Vector3.new(4.5, 0, 2.6), Color3.fromRGB(230, 230, 225), 1)
end
PROP_BUILDERS.JobComputerDesk = function(model: Model)
	desk(model, "JobComputerDesk", Vector3.new(5.5, 0, 3), Color3.fromRGB(150, 155, 160), 1)
end
PROP_BUILDERS.JobOfficeDesk = function(model: Model)
	desk(model, "JobOfficeDesk", Vector3.new(6, 0, 3.4), Color3.fromRGB(160, 120, 80), 2)
end

-- Delivery boxes, by size.
PROP_BUILDERS.DeliveryBoxSmall = function(model: Model)
	local size = Vector3.new(1.8, 1.1, 1.3)
	box(model, "DeliveryBoxSmall", size, boxFlaps(size, { "FlapL", "FlapR" }))
end
PROP_BUILDERS.DeliveryBoxLong = function(model: Model)
	local size = Vector3.new(6.2, 0.8, 0.8)
	box(model, "DeliveryBoxLong", size, {
		{
			name = "Lid",
			size = Vector3.new(size.X, 0.05, size.Z),
			position = Vector3.new(0, size.Y, 0),
			hinge = Vector3.new(0, size.Y, size.Z / 2),
		},
	})
end
PROP_BUILDERS.DeliveryBoxLarge = function(model: Model)
	local size = Vector3.new(3.4, 2.4, 2.4)
	box(model, "DeliveryBoxLarge", size, boxFlaps(size, { "FlapL", "FlapR", "FlapF", "FlapB" }))
end
PROP_BUILDERS.DeliveryCrate = function(model: Model)
	local size = Vector3.new(5.4, 4.4, 7.2)
	box(model, "DeliveryCrate", size, {
		{
			name = "Lid",
			size = Vector3.new(size.X, 0.15, size.Z),
			position = Vector3.new(0, size.Y, 0),
			hinge = Vector3.new(0, size.Y, size.Z / 2),
		},
		{
			name = "FrontPanel",
			size = Vector3.new(size.X - 0.1, size.Y - 0.1, 0.15),
			position = Vector3.new(0, size.Y / 2, -size.Z / 2 - 0.08),
			hinge = Vector3.new(0, 0.05, -size.Z / 2 - 0.08),
		},
	}, true)
end

function Placeholders.prop(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local builder = PROP_BUILDERS[name]
	if builder then
		builder(model)
	else
		local block = part({ Name = name, Size = Vector3.new(4, 4, 4), Anchored = true })
		block.Parent = model
		model.PrimaryPart = block
	end
	return model
end

return Placeholders
