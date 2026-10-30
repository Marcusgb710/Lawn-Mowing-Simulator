-- Block-model stand-ins used until the real models exist in assets/ (see Assets.luau).
-- Nothing else in the game depends on what these look like, so feel free to delete them later.

local Decorations = require(script.Parent.Config.Decorations)
local Items = require(script.Parent.Config.Items)
local Tools = require(script.Parent.Config.Tools)

local Placeholders = {}

-- The story's people (see PROP_BUILDERS) share a skin tone until they have real models.
local SKIN = Color3.fromRGB(240, 200, 160)

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
		-- Where a machine is set down to be worked on (on the floor in front), and where a hand
		-- tool's grip goes in the vise (see MaintenanceService).
		marker(model, "ServiceSpot", CFrame.new(0, 0, -3.4))
		marker(model, "VisePoint", CFrame.new(-2.8, 4.1, -0.9))
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

	-- The story's people and places (docs/STORY.md). People are built like the decorations: origin
	-- on the ground under them, front toward -Z, a "Root" part. They don't collide.

	-- Grandma June's white porch rocker. Its seat's top is 1.8 studs up, where June sits.
	PorchRockingChair = function(model: Model)
		local add = propAdder(model)
		rootPart(model, add)
		local paint = Color3.fromRGB(236, 232, 222)
		for _, x in { -1, 1 } do
			add({
				Name = "Rocker",
				Size = Vector3.new(0.2, 0.25, 3.2),
				Position = Vector3.new(x, 0.125, 0.1),
				Color = paint,
			})
			for _, z in { -0.8, 0.8 } do
				add({
					Name = "Leg",
					Size = Vector3.new(0.2, 1.35, 0.2),
					Position = Vector3.new(x, 0.925, z),
					Color = paint,
				})
			end
			add({
				Name = "Arm",
				Size = Vector3.new(0.2, 0.15, 1.8),
				Position = Vector3.new(x * 1.15, 2.5, 0.05),
				Color = paint,
			})
			add({
				Name = "ArmPost",
				Size = Vector3.new(0.15, 0.7, 0.15),
				Position = Vector3.new(x * 1.15, 2.1, -0.75),
				Color = paint,
			})
		end
		add({ Name = "Seat", Size = Vector3.new(2.3, 0.2, 1.9), Position = Vector3.new(0, 1.7, 0), Color = paint })
		add({
			Name = "Back",
			Size = Vector3.new(2.3, 2.6, 0.15),
			CFrame = CFrame.new(0, 3.1, 1) * CFrame.Angles(math.rad(10), 0, 0),
			Color = paint,
		})
	end,

	-- Grandma June, sitting (on a seat 1.8 studs up): green dress, white hair, glasses, and her
	-- straw sun hat with the red band.
	GrandmaJune = function(model: Model)
		local add = propAdder(model)
		rootPart(model, add)
		local dress = Color3.fromRGB(94, 140, 74)
		local function person(props)
			props.CanCollide = false
			return add(props)
		end
		person({
			Name = "Lap",
			Size = Vector3.new(1.8, 0.55, 1.6),
			Position = Vector3.new(0, 2.05, -0.35),
			Color = dress,
		})
		person({ Name = "Body", Size = Vector3.new(1.8, 2, 1), Position = Vector3.new(0, 3.3, 0.3), Color = dress })
		person({
			Name = "Collar",
			Size = Vector3.new(1, 0.25, 0.1),
			Position = Vector3.new(0, 4.15, -0.22),
			Color = Color3.fromRGB(244, 235, 208),
		})
		for _, x in { -1, 1 } do
			person({
				Name = "Leg",
				Size = Vector3.new(0.5, 1.55, 0.5),
				Position = Vector3.new(x * 0.4, 1, -1.05),
				Color = SKIN,
			})
			person({
				Name = "Shoe",
				Size = Vector3.new(0.6, 0.35, 0.85),
				Position = Vector3.new(x * 0.4, 0.175, -1.2),
				Color = Color3.fromRGB(90, 60, 45),
			})
			person({
				Name = "Arm",
				Size = Vector3.new(0.5, 1.6, 0.55),
				Position = Vector3.new(x * 1.15, 3.25, 0.1),
				Color = dress,
			})
			person({
				Name = "Hand",
				Size = Vector3.new(0.45, 0.45, 0.45),
				Position = Vector3.new(x * 0.95, 2.45, -0.6),
				Color = SKIN,
			})
			person({
				Name = "Glasses",
				Size = Vector3.new(0.42, 0.32, 0.05),
				Position = Vector3.new(x * 0.28, 5.3, -0.56),
				Color = Color3.fromRGB(30, 40, 30),
				Transparency = 0.3,
			})
		end
		person({ Name = "Neck", Size = Vector3.new(0.5, 0.3, 0.5), Position = Vector3.new(0, 4.4, 0.25), Color = SKIN })
		person({
			Name = "Hair",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = Vector3.new(0, 5.4, 0.4),
			Color = Color3.fromRGB(232, 232, 232),
		})
		person({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 1.5, 1.5),
			Position = Vector3.new(0, 5.25, 0.2),
			Color = SKIN,
		})
		-- Cylinders lie along X, so they're stood on end to make the hat.
		local upright = CFrame.Angles(0, 0, math.rad(90))
		local straw = Color3.fromRGB(227, 194, 122)
		person({
			Name = "Hat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 3.2, 3.2),
			CFrame = CFrame.new(0, 5.95, 0.2) * upright,
			Color = straw,
		})
		person({
			Name = "Hat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 1.55, 1.55),
			CFrame = CFrame.new(0, 6.45, 0.2) * upright,
			Color = straw,
		})
		person({
			Name = "HatBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.28, 1.6, 1.6),
			CFrame = CFrame.new(0, 6.15, 0.2) * upright,
			Color = Color3.fromRGB(200, 70, 60),
		})
	end,

	-- Gloria Pemberton, standing: pink cardigan, pearls, and a lot of auburn hair.
	GloriaPemberton = function(model: Model)
		local add = propAdder(model)
		rootPart(model, add)
		local cardigan = Color3.fromRGB(230, 140, 170)
		local function person(props)
			props.CanCollide = false
			return add(props)
		end
		for _, x in { -1, 1 } do
			person({
				Name = "Shoe",
				Size = Vector3.new(0.6, 0.3, 0.9),
				Position = Vector3.new(x * 0.45, 0.15, -0.1),
				Color = Color3.fromRGB(245, 245, 240),
			})
			person({
				Name = "Leg",
				Size = Vector3.new(0.55, 1.9, 0.55),
				Position = Vector3.new(x * 0.45, 1.25, 0),
				Color = SKIN,
			})
			person({
				Name = "Arm",
				Size = Vector3.new(0.5, 1.9, 0.55),
				Position = Vector3.new(x * 1.2, 4.05, 0),
				Color = cardigan,
			})
			person({
				Name = "Hand",
				Size = Vector3.new(0.45, 0.45, 0.45),
				Position = Vector3.new(x * 1.2, 2.9, 0),
				Color = SKIN,
			})
		end
		person({
			Name = "Skirt",
			Size = Vector3.new(1.9, 1.3, 1.1),
			Position = Vector3.new(0, 2.6, 0),
			Color = Color3.fromRGB(240, 230, 210),
		})
		person({ Name = "Body", Size = Vector3.new(1.9, 1.9, 1), Position = Vector3.new(0, 4.15, 0), Color = cardigan })
		person({
			Name = "Pearls",
			Size = Vector3.new(1, 0.18, 0.12),
			Position = Vector3.new(0, 4.95, -0.52),
			Color = Color3.fromRGB(250, 248, 240),
		})
		person({ Name = "Neck", Size = Vector3.new(0.5, 0.3, 0.5), Position = Vector3.new(0, 5.25, 0), Color = SKIN })
		person({
			Name = "Hair",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 1.8),
			Position = Vector3.new(0, 6.3, 0.18),
			Color = Color3.fromRGB(150, 75, 50),
		})
		person({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 1.5, 1.5),
			Position = Vector3.new(0, 6.05, 0),
			Color = SKIN,
		})
	end,

	-- Gloria's house across the street: two storeys in lavender with a white front porch. Front
	-- toward -Z: the house's front wall is at Z = 0, the porch in front of it. A "Porch" marker is
	-- where Gloria stands.
	GloriasHouse = function(model: Model)
		local add = propAdder(model)
		rootPart(model, add)
		local width, depth, height = 34, 22, 14
		local white = Color3.fromRGB(240, 238, 232)
		add({
			Name = "Walls",
			Size = Vector3.new(width, height, depth),
			Position = Vector3.new(0, height / 2, depth / 2),
			Color = Color3.fromRGB(200, 185, 225),
		})
		add({
			Name = "Trim",
			Size = Vector3.new(width + 0.4, 0.6, depth + 0.4),
			Position = Vector3.new(0, height / 2, depth / 2),
			Color = white,
		})
		local roof = Color3.fromRGB(85, 70, 100)
		add({
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(width + 2, 7, depth / 2 + 1),
			CFrame = CFrame.new(0, height + 3.5, depth / 4 - 0.5),
			Color = roof,
		})
		add({
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(width + 2, 7, depth / 2 + 1),
			CFrame = CFrame.new(0, height + 3.5, depth * 3 / 4 + 0.5) * CFrame.Angles(0, math.pi, 0),
			Color = roof,
		})
		add({
			Name = "Chimney",
			Size = Vector3.new(2.5, 6, 2.5),
			Position = Vector3.new(11, height + 4, depth * 0.7),
			Color = Color3.fromRGB(150, 80, 70),
		})
		local porchHeight, porchDepth = 1.2, 7
		add({
			Name = "Porch",
			Size = Vector3.new(width, porchHeight, porchDepth),
			Position = Vector3.new(0, porchHeight / 2, -porchDepth / 2),
			Color = white,
		})
		add({
			Name = "PorchRoof",
			Size = Vector3.new(width, 0.6, porchDepth + 0.6),
			Position = Vector3.new(0, 9.3, -porchDepth / 2 - 0.3),
			Color = white,
		})
		for _, x in { -16, -8, 8, 16 } do
			add({
				Name = "Column",
				Size = Vector3.new(0.8, 9 - porchHeight, 0.8),
				Position = Vector3.new(x, (9 + porchHeight) / 2, -porchDepth + 0.4),
				Color = white,
			})
		end
		add({
			Name = "Step",
			Size = Vector3.new(8, 0.6, 2.4),
			Position = Vector3.new(0, 0.3, -porchDepth - 1.2),
			Color = white,
		})
		add({
			Name = "Step",
			Size = Vector3.new(8, 0.6, 1.2),
			Position = Vector3.new(0, 0.9, -porchDepth - 0.6),
			Color = white,
		})
		add({
			Name = "Door",
			Size = Vector3.new(4, 7, 0.3),
			Position = Vector3.new(0, porchHeight + 3.5, -0.15),
			Color = Color3.fromRGB(110, 60, 120),
		})
		for _, x in { -11, -5.5, 5.5, 11 } do
			for _, y in { porchHeight + 4, height - 3.2 } do
				add({
					Name = "Window",
					Size = Vector3.new(4, 3.5, 0.3),
					Position = Vector3.new(x, y, -0.15),
					Color = Color3.fromRGB(165, 205, 230),
				})
			end
		end
		marker(model, "Porch", CFrame.new(-7, porchHeight, -porchDepth / 2))
	end,
}

-- The story's people and props (alphainstructions/instructions37.md: Story/<id>) -------------

local TURFKING_PURPLE = Color3.fromRGB(88, 52, 150)
local TURFKING_GOLD = Color3.fromRGB(230, 185, 60)

-- TurfKing's mark: a gold crown, as flat blocks (a band and three points) standing in `frame`'s
-- XY plane, `width` studs across, `depth` thick. Returns the parts, unparented.
function Placeholders.crown(frame: CFrame, width: number, depth: number, color: Color3?): { BasePart }
	local parts = {}
	local gold = color or TURFKING_GOLD
	local band = width * 0.32
	local function add(name: string, size: Vector3, offset: CFrame)
		local piece = part({
			Name = name,
			Size = size,
			CFrame = frame * offset,
			Color = gold,
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		table.insert(parts, piece)
	end
	add("CrownBand", Vector3.new(width, band, depth), CFrame.new(0, -width * 0.2, 0))
	for _, x in { -1, 0, 1 } do
		local point = width * (if x == 0 then 0.36 else 0.28)
		add(
			"CrownPoint",
			Vector3.new(point * 0.7, point * 0.7, depth),
			CFrame.new(x * width * 0.36, -width * 0.2 + band / 2 + point * 0.2, 0) * CFrame.Angles(0, 0, math.pi / 4)
		)
	end
	return parts
end

-- Chad, TurfKing's local boss: a purple TurfKing polo with the crown on the chest, a gold visor
-- with sunglasses pushed up on it, khaki shorts, white sneakers, a clipboard and a thumbs-up.
PROP_BUILDERS.NPC_Chad = function(model: Model)
	local add = propAdder(model)
	rootPart(model, add)
	local function person(props)
		props.CanCollide = false
		return add(props)
	end
	local khaki = Color3.fromRGB(200, 180, 130)
	for _, x in { -1, 1 } do
		person({
			Name = "Shoe",
			Size = Vector3.new(0.65, 0.35, 1),
			Position = Vector3.new(x * 0.45, 0.175, -0.1),
			Color = Color3.fromRGB(250, 250, 250),
		})
		person({
			Name = "Leg",
			Size = Vector3.new(0.6, 1.6, 0.6),
			Position = Vector3.new(x * 0.45, 1.15, 0),
			Color = SKIN,
		})
	end
	person({ Name = "Shorts", Size = Vector3.new(1.9, 1.1, 1.05), Position = Vector3.new(0, 2.45, 0), Color = khaki })
	person({
		Name = "Body",
		Size = Vector3.new(2, 2.1, 1.1),
		Position = Vector3.new(0, 4.05, 0),
		Color = TURFKING_PURPLE,
	})
	for _, crownPart in Placeholders.crown(CFrame.new(-0.5, 4.6, -0.58), 0.45, 0.06) do
		crownPart.Parent = model
	end
	-- His right arm up in a thumbs-up, his left holding the clipboard against his side.
	person({
		Name = "Sleeve",
		Size = Vector3.new(0.6, 0.8, 0.65),
		Position = Vector3.new(1.3, 4.6, 0),
		Color = TURFKING_PURPLE,
	})
	person({
		Name = "Arm",
		Size = Vector3.new(0.5, 1.3, 0.5),
		CFrame = CFrame.new(1.45, 4.85, -0.35) * CFrame.Angles(math.rad(60), 0, 0),
		Color = SKIN,
	})
	person({ Name = "Hand", Size = Vector3.new(0.5, 0.5, 0.5), Position = Vector3.new(1.45, 5.3, -0.85), Color = SKIN })
	person({
		Name = "Thumb",
		Size = Vector3.new(0.18, 0.4, 0.18),
		Position = Vector3.new(1.45, 5.7, -0.85),
		Color = SKIN,
	})
	person({
		Name = "Sleeve",
		Size = Vector3.new(0.6, 0.8, 0.65),
		Position = Vector3.new(-1.3, 4.6, 0),
		Color = TURFKING_PURPLE,
	})
	person({ Name = "Arm", Size = Vector3.new(0.5, 1.4, 0.5), Position = Vector3.new(-1.3, 3.6, 0), Color = SKIN })
	person({
		Name = "Clipboard",
		Size = Vector3.new(0.12, 1.6, 1.2),
		Position = Vector3.new(-1.62, 3.7, 0),
		Color = Color3.fromRGB(150, 110, 70),
	})
	person({
		Name = "Paper",
		Size = Vector3.new(0.04, 1.3, 1),
		Position = Vector3.new(-1.7, 3.7, 0),
		Color = Color3.fromRGB(250, 250, 245),
	})
	person({ Name = "Neck", Size = Vector3.new(0.55, 0.35, 0.55), Position = Vector3.new(0, 5.25, 0), Color = SKIN })
	person({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.5, 1.5),
		Position = Vector3.new(0, 6.0, 0),
		Color = SKIN,
	})
	person({
		Name = "Hair",
		Size = Vector3.new(1.4, 0.4, 1.3),
		Position = Vector3.new(0, 6.65, 0.1),
		Color = Color3.fromRGB(205, 165, 90),
	})
	-- The gold visor and its brim, with the sunglasses pushed up on it.
	person({
		Name = "Visor",
		Size = Vector3.new(1.6, 0.3, 1.5),
		Position = Vector3.new(0, 6.45, 0),
		Color = TURFKING_GOLD,
	})
	person({
		Name = "Brim",
		Size = Vector3.new(1.4, 0.1, 0.8),
		Position = Vector3.new(0, 6.35, -1),
		Color = TURFKING_GOLD,
	})
	person({
		Name = "Sunglasses",
		Size = Vector3.new(1.2, 0.25, 0.1),
		Position = Vector3.new(0, 6.7, -0.7),
		Color = Color3.fromRGB(30, 30, 35),
	})
end

-- A TurfKing yard sign: a purple panel with the gold crown, on two wire stakes.
PROP_BUILDERS.TurfKingSign = function(model: Model)
	local add = propAdder(model)
	rootPart(model, add)
	for _, x in { -0.55, 0.55 } do
		add({
			Name = "TurfKingSign__Stake",
			Size = Vector3.new(0.06, 1.3, 0.06),
			Position = Vector3.new(x, 0.35, 0),
			Color = Color3.fromRGB(90, 90, 95),
			CanCollide = false,
		})
	end
	add({
		Name = "TurfKingSign__Body",
		Size = Vector3.new(1.6, 1.1, 0.08),
		Position = Vector3.new(0, 1.4, 0),
		Color = TURFKING_PURPLE,
		CanCollide = false,
	})
	for _, crownPart in Placeholders.crown(CFrame.new(0, 1.45, -0.06), 0.8, 0.04) do
		crownPart.Parent = model
	end
end

-- The curb mailbox at the end of every driveway, where the day's contracts are (see WorldService):
-- a dark wood post with a green box on top and a small red flag on its right, the box's front
-- toward -Z, the street. Its Root lies on the ground under the box, so it is stood with
-- Assets.placeOnGround. It has no DecorId: nobody buys, moves or loses it.
PROP_BUILDERS.CurbMailbox = function(model: Model)
	local add = propAdder(model)
	model.PrimaryPart = add({
		Name = "Root",
		Size = Vector3.new(1, 0.1, 1.4),
		Position = Vector3.new(0, 0.05, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	add({
		Name = "CurbMailbox__Post",
		Size = Vector3.new(0.3, 3.5, 0.3),
		Position = Vector3.new(0, 1.75, 0),
		Color = Color3.fromRGB(85, 60, 40),
		Material = Enum.Material.Wood,
	})
	add({
		Name = "CurbMailbox__Box",
		Size = Vector3.new(1, 0.8, 1.4),
		Position = Vector3.new(0, 3.9, 0),
		Color = Color3.fromRGB(40, 90, 60),
	})
	add({
		Name = "CurbMailbox__Flag",
		Size = Vector3.new(0.06, 0.55, 0.3),
		Position = Vector3.new(0.53, 4.2, 0.45),
		Color = Color3.fromRGB(200, 40, 40),
		CanCollide = false,
	})
end

-- The streak's pennant for the truck's bed (Assets.addPennant): a thin pole with a purple flag
-- streaming back from its top. Built like the real models: origin at the pole's foot, a Root part.
local PENNANT_PURPLE = Color3.fromRGB(140, 80, 200)

PROP_BUILDERS.TruckPennant = function(model: Model)
	local add = propAdder(model)
	rootPart(model, add)
	add({
		Name = "TruckPennant__Pole",
		Size = Vector3.new(0.15, 3, 0.15),
		Position = Vector3.new(0, 1.5, 0),
		Color = Color3.fromRGB(190, 190, 195),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	-- A wedge's tall edge is at +Z. Turned half way round, that edge is on the pole and the point
	-- streams back along +Z, the way a truck's flag does as it drives off.
	add({
		ClassName = "WedgePart",
		Name = "TruckPennant__Flag",
		Size = Vector3.new(0.1, 0.7, 1),
		CFrame = CFrame.new(0, 2.65, 0.575) * CFrame.Angles(0, math.pi, 0),
		Color = PENNANT_PURPLE,
		CanCollide = false,
	})
end

-- A Best Yard judge standing: legs, a jacket, a head and whatever they're carrying (`extras`).
local function judge(model: Model, jacket: Color3, trousers: Color3, hair: Color3, extras: (any) -> ())
	local add = propAdder(model)
	rootPart(model, add)
	local function person(props)
		props.CanCollide = false
		return add(props)
	end
	for _, x in { -1, 1 } do
		person({
			Name = "Shoe",
			Size = Vector3.new(0.6, 0.3, 0.9),
			Position = Vector3.new(x * 0.42, 0.15, -0.1),
			Color = Color3.fromRGB(70, 50, 40),
		})
		person({
			Name = "Leg",
			Size = Vector3.new(0.55, 2.1, 0.55),
			Position = Vector3.new(x * 0.42, 1.35, 0),
			Color = trousers,
		})
		person({
			Name = "Arm",
			Size = Vector3.new(0.5, 1.8, 0.55),
			Position = Vector3.new(x * 1.12, 3.65, 0),
			Color = jacket,
		})
	end
	person({ Name = "Body", Size = Vector3.new(1.8, 2.1, 1), Position = Vector3.new(0, 3.45, 0), Color = jacket })
	person({ Name = "Neck", Size = Vector3.new(0.5, 0.3, 0.5), Position = Vector3.new(0, 4.65, 0), Color = SKIN })
	person({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		Position = Vector3.new(0, 5.3, 0),
		Color = SKIN,
	})
	person({
		Name = "Hair",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.45, 1.1, 1.45),
		Position = Vector3.new(0, 5.6, 0.1),
		Color = hair,
	})
	extras(person)
end

-- Judge Pruitt: an older man in a seersucker jacket and a bow tie, with a magnifying glass.
PROP_BUILDERS.NPC_Judge1 = function(model: Model)
	judge(
		model,
		Color3.fromRGB(190, 210, 230),
		Color3.fromRGB(235, 230, 215),
		Color3.fromRGB(225, 225, 225),
		function(person)
			person({
				Name = "BowTie",
				Size = Vector3.new(0.6, 0.25, 0.1),
				Position = Vector3.new(0, 4.35, -0.55),
				Color = Color3.fromRGB(170, 40, 50),
			})
			person({
				Name = "Hand",
				Size = Vector3.new(0.45, 0.45, 0.45),
				Position = Vector3.new(1.12, 2.65, -0.3),
				Color = SKIN,
			})
			person({
				Name = "MagnifyingGlass",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.08, 0.8, 0.8),
				CFrame = CFrame.new(1.12, 2.5, -0.85) * CFrame.Angles(0, math.pi / 2, 0),
				Color = Color3.fromRGB(190, 220, 235),
				Transparency = 0.3,
			})
		end
	)
end

-- Judge Marigold: a sun hat with a big flower, a lanyard and a clipboard with a pencil.
PROP_BUILDERS.NPC_Judge2 = function(model: Model)
	judge(
		model,
		Color3.fromRGB(240, 170, 120),
		Color3.fromRGB(110, 120, 140),
		Color3.fromRGB(120, 80, 60),
		function(person)
			local upright = CFrame.Angles(0, 0, math.pi / 2)
			person({
				Name = "Hat",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, 2.6, 2.6),
				CFrame = CFrame.new(0, 5.85, 0.05) * upright,
				Color = Color3.fromRGB(235, 215, 160),
			})
			person({
				Name = "Hat",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 1.4, 1.4),
				CFrame = CFrame.new(0, 6.1, 0.05) * upright,
				Color = Color3.fromRGB(235, 215, 160),
			})
			person({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				Position = Vector3.new(0.6, 6.2, -0.4),
				Color = Color3.fromRGB(230, 90, 140),
			})
			person({
				Name = "Lanyard",
				Size = Vector3.new(0.35, 0.5, 0.05),
				Position = Vector3.new(0, 3.8, -0.53),
				Color = Color3.fromRGB(250, 250, 245),
			})
			person({
				Name = "Clipboard",
				Size = Vector3.new(1, 1.3, 0.1),
				CFrame = CFrame.new(-0.6, 3.2, -0.75) * CFrame.Angles(math.rad(-25), 0, 0),
				Color = Color3.fromRGB(150, 110, 70),
			})
		end
	)
end

-- The rest of the cast (Config/Cast.luau), for when CastService can't build a rig and warns. Each
-- is a plain standing figure like the judges, in the colors of what they wear and with nothing in
-- their hands, except June in her rocker, who is the sitting one above.
local function standing(top: Color3, trousers: Color3, hair: Color3)
	return function(model: Model)
		judge(model, top, trousers, hair, function() end)
	end
end

PROP_BUILDERS.NPC_Edna =
	standing(Color3.fromRGB(80, 120, 190), Color3.fromRGB(240, 238, 230), Color3.fromRGB(178, 178, 184))
PROP_BUILDERS.NPC_June_Sitting = PROP_BUILDERS.GrandmaJune
PROP_BUILDERS.NPC_June_Standing =
	standing(Color3.fromRGB(215, 195, 160), Color3.fromRGB(50, 80, 55), Color3.fromRGB(200, 200, 205))
PROP_BUILDERS.NPC_Sam_Casual =
	standing(Color3.fromRGB(60, 140, 80), Color3.fromRGB(35, 35, 40), Color3.fromRGB(110, 80, 55))
PROP_BUILDERS.NPC_Sam_TurfKing = standing(TURFKING_PURPLE, Color3.fromRGB(35, 35, 40), Color3.fromRGB(110, 80, 55))

-- Junk hidden in the grass (Config/Debris.luau), built like the decorations: origin on the ground
-- at the centre, front toward -Z, a "Root" part and `<Id>__Body` parts. All of it lies low, so it
-- hides in tall grass.
local function debrisAdder(model: Model, id: string)
	local add = propAdder(model)
	rootPart(model, add)
	return function(props)
		props.Name = id .. "__Body"
		props.CanCollide = false
		return add(props)
	end
end

-- A dead stick with a short twig off one side.
PROP_BUILDERS.DebrisStick = function(model: Model)
	local add = debrisAdder(model, "DebrisStick")
	local bark = Color3.fromRGB(110, 80, 50)
	add({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 0.2, 0.2),
		CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.rad(15), 0),
		Color = bark,
		Material = Enum.Material.Wood,
	})
	add({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 0.12, 0.12),
		CFrame = CFrame.new(0.35, 0.08, -0.25) * CFrame.Angles(0, math.rad(55), 0),
		Color = bark,
		Material = Enum.Material.Wood,
	})
end

-- A fist-sized field stone.
PROP_BUILDERS.DebrisRock = function(model: Model)
	local add = debrisAdder(model, "DebrisRock")
	add({
		Size = Vector3.new(0.8, 0.5, 0.65),
		CFrame = CFrame.new(0, 0.22, 0) * CFrame.Angles(math.rad(8), math.rad(25), math.rad(-6)),
		Color = Color3.fromRGB(130, 130, 125),
		Material = Enum.Material.Slate,
	})
end

-- A dog's tennis ball.
PROP_BUILDERS.DebrisDogBall = function(model: Model)
	local add = debrisAdder(model, "DebrisDogBall")
	add({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.55, 0.55, 0.55),
		Position = Vector3.new(0, 0.275, 0),
		Color = Color3.fromRGB(200, 230, 60),
		Material = Enum.Material.Fabric,
	})
end

-- A kid's plastic toy dump truck, facing -Z.
PROP_BUILDERS.DebrisToyTruck = function(model: Model)
	local add = debrisAdder(model, "DebrisToyTruck")
	add({ Size = Vector3.new(0.55, 0.3, 1.1), Position = Vector3.new(0, 0.3, 0), Color = Color3.fromRGB(220, 50, 40) })
	add({
		Size = Vector3.new(0.5, 0.3, 0.35),
		Position = Vector3.new(0, 0.6, -0.35),
		Color = Color3.fromRGB(250, 210, 40),
	})
	for _, x in { -0.3, 0.3 } do
		for _, z in { -0.35, 0.35 } do
			add({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, 0.3, 0.3),
				Position = Vector3.new(x, 0.15, z),
				Color = Color3.fromRGB(30, 30, 30),
			})
		end
	end
end

-- A plastic frisbee lying flat.
PROP_BUILDERS.DebrisFrisbee = function(model: Model)
	local add = debrisAdder(model, "DebrisFrisbee")
	add({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 1, 1),
		CFrame = CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(240, 130, 30),
	})
end

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

-- Decorations -------------------------------------------------------------------------------
-- Built like the real ones (alphainstructions/instructions34.md): origin on the ground at the
-- centre, front toward -Z, a "Root" part, the main body `<Id>__Body`, and named markers.

local function decorationAdder(model: Model, id: string, color: Color3)
	local add = propAdder(model)
	rootPart(model, add)
	return function(props)
		props.Name = id .. "__" .. (props.Name or "Body")
		props.Color = props.Color or color
		return add(props)
	end
end

local WHITE = Color3.fromRGB(245, 245, 240)
local LEAVES = Color3.fromRGB(70, 125, 60)
local MULCH = Color3.fromRGB(105, 70, 45)
local STONE = Color3.fromRGB(185, 180, 170)
local METAL = Color3.fromRGB(35, 35, 40)
local WATER = Color3.fromRGB(110, 170, 220)

-- A ring of mulch at a plant's base.
local function mulchRing(add, diameter: number)
	add({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, diameter, diameter),
		CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = MULCH,
		Material = Enum.Material.Ground,
	})
end

-- SnapL and SnapR on the ground at each end of a piece that runs along `axis`, pointing outward.
local function snaps(model: Model, axis: Vector3, halfLength: number)
	marker(model, "SnapL", CFrame.lookAt(-axis * halfLength, -axis * (halfLength + 1)))
	marker(model, "SnapR", CFrame.lookAt(axis * halfLength, axis * (halfLength + 1)))
end

local DECORATION_BUILDERS = {
	PicketFenceSection = function(model: Model, add)
		for _, x in { -4.1, 4.1 } do
			add({ Size = Vector3.new(0.4, 3.4, 0.4), Position = Vector3.new(x, 1.6, 0) })
		end
		for _, y in { 0.9, 2.3 } do
			add({ Size = Vector3.new(7.8, 0.25, 0.1), Position = Vector3.new(0, y, 0.12) })
		end
		for index = 0, 12 do
			add({ Size = Vector3.new(0.32, 2.9, 0.08), Position = Vector3.new(-3.6 + index * 0.6, 1.5, 0.02) })
		end
		snaps(model, Vector3.xAxis, 4.3)
	end,
	StoneEdgingSection = function(model: Model, add)
		for index = 0, 3 do
			local height = 0.45 + (index % 2) * 0.1
			add({
				Size = Vector3.new(1.02, height, 0.85),
				Position = Vector3.new(-1.6 + index * 1.07, height / 2 - 0.05, 0),
				Material = Enum.Material.Slate,
			})
		end
		snaps(model, Vector3.xAxis, 2.15)
	end,
	PaverPathSection = function(model: Model, add)
		add({ Size = Vector3.new(4.3, 0.15, 4.3), Position = Vector3.new(0, 0.075, 0), Material = Enum.Material.Brick })
		for _, x in { -2.05, 2.05 } do
			add({
				Size = Vector3.new(0.2, 0.17, 4.3),
				Position = Vector3.new(x, 0.085, 0),
				Color = Color3.fromRGB(140, 125, 115),
			})
		end
		snaps(model, Vector3.zAxis, 2.15)
	end,
	MulchBedSection = function(model: Model, add)
		add({ Size = Vector3.new(8.4, 0.3, 4.1), Position = Vector3.new(0, 0.15, 0), Material = Enum.Material.Ground })
		for _, side in
			{ { 8.6, 0.06, 0, 2.12 }, { 8.6, 0.06, 0, -2.12 }, { 0.06, 4.3, 4.27, 0 }, { 0.06, 4.3, -4.27, 0 } }
		do
			add({
				Size = Vector3.new(side[1], 0.4, side[2]),
				Position = Vector3.new(side[3], 0.2, side[4]),
				Color = METAL,
			})
		end
		snaps(model, Vector3.xAxis, 4.3)
	end,
	BoxwoodShrub = function(_model: Model, add)
		mulchRing(add, 2.9)
		add({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.5,
			Position = Vector3.new(0, 1.35, 0),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
		add({
			Name = "Overgrowth",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.1,
			Position = Vector3.new(0, 1.5, 0),
			Color = Color3.fromRGB(85, 130, 55),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end,
	HydrangeaBush = function(_model: Model, add)
		mulchRing(add, 3.6)
		add({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.4, 3, 3.4),
			Position = Vector3.new(0, 1.6, 0),
			Color = LEAVES,
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
		for _, offset in { Vector3.new(-0.9, 2.7, -0.6), Vector3.new(0.8, 2.9, -0.4), Vector3.new(0.1, 2.6, 0.9) } do
			add({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.1,
				Position = offset,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
		add({
			Name = "Overgrowth",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 3.6, 4),
			Position = Vector3.new(0, 1.8, 0),
			Color = Color3.fromRGB(80, 125, 60),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end,
	JapaneseMaple = function(_model: Model, add)
		mulchRing(add, 3)
		add({
			Size = Vector3.new(0.6, 4.6, 0.6),
			Position = Vector3.new(0, 2.3, 0),
			Color = Color3.fromRGB(90, 65, 50),
			Material = Enum.Material.Wood,
		})
		add({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 4.4, 9),
			Position = Vector3.new(0, 6.6, 0),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
	end,
	TerracottaPlanter = function(_model: Model, add)
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.1, 2, 2),
			CFrame = CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		})
		add({
			Name = "Plants",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 1.2, 2),
			Position = Vector3.new(0, 2.3, 0),
			Color = Color3.fromRGB(200, 90, 150),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
	end,
	RaisedGardenBed = function(_model: Model, add)
		for _, side in { { 8.6, 0.3, 0, 2 }, { 8.6, 0.3, 0, -2 }, { 0.3, 3.7, 4.15, 0 }, { 0.3, 3.7, -4.15, 0 } } do
			add({
				Size = Vector3.new(side[1], 1.8, side[2]),
				Position = Vector3.new(side[3], 0.9, side[4]),
				Material = Enum.Material.Wood,
			})
		end
		add({
			Size = Vector3.new(8, 1.5, 3.7),
			Position = Vector3.new(0, 0.75, 0),
			Color = Color3.fromRGB(80, 60, 45),
			Material = Enum.Material.Ground,
		})
		for _, x in { -2.8, 0, 2.8 } do
			add({
				Name = "Plants",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.6, 1.4, 1.6),
				Position = Vector3.new(x, 2, 0),
				Color = LEAVES,
				Material = Enum.Material.LeafyGrass,
				CanCollide = false,
			})
		end
	end,
	BirdBath = function(model: Model, add)
		add({ Size = Vector3.new(1.4, 0.3, 1.4), Position = Vector3.new(0, 0.15, 0), Material = Enum.Material.Concrete })
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.9, 0.6, 0.6),
			CFrame = CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Concrete,
		})
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 2.2, 2.2),
			CFrame = CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Concrete,
		})
		add({
			Name = "Water",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, 1.8, 1.8),
			CFrame = CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = WATER,
			Transparency = 0.3,
			CanCollide = false,
		})
		marker(model, "Water", CFrame.new(0, 2.62, 0))
	end,
	TieredFountain = function(model: Model, add)
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 6, 6),
			CFrame = CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Concrete,
		})
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4.6, 0.7, 0.7),
			CFrame = CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Concrete,
		})
		-- Three bowls, top to bottom, each with its water.
		local tiers = { { 1.4, 5 }, { 2.4, 3.8 }, { 5.6, 1.05 } }
		for index, tier in tiers do
			local diameter, height = tier[1], tier[2]
			if index < 3 then
				add({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.35, diameter, diameter),
					CFrame = CFrame.new(0, height - 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
					Material = Enum.Material.Concrete,
				})
			end
			add({
				Name = "Water" .. index,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, diameter - 0.3, diameter - 0.3),
				CFrame = CFrame.new(0, height + 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = WATER,
				Transparency = 0.3,
				CanCollide = false,
			})
			marker(model, "Water" .. index, CFrame.new(0, height + 0.05, 0))
		end
		marker(model, "Spout", CFrame.new(0, 5.35, 0))
	end,
	GardenArbor = function(_model: Model, add)
		for _, x in { -2.1, 2.1 } do
			add({ Size = Vector3.new(0.35, 7.6, 2.2), Position = Vector3.new(x, 3.8, 0), Material = Enum.Material.Wood })
		end
		add({ Size = Vector3.new(4.6, 0.5, 2.2), Position = Vector3.new(0, 7.95, 0), Material = Enum.Material.Wood })
		add({
			Name = "Plants",
			Size = Vector3.new(4.8, 0.8, 1.6),
			Position = Vector3.new(0, 7.4, 0),
			Color = Color3.fromRGB(190, 60, 80),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
	end,
	GardenBench = function(model: Model, add)
		add({ Size = Vector3.new(5.4, 0.25, 1.7), Position = Vector3.new(0, 1.45, 0.05), Material = Enum.Material.Wood })
		add({ Size = Vector3.new(5.4, 1.3, 0.2), Position = Vector3.new(0, 2.5, 0.85), Material = Enum.Material.Wood })
		for _, x in { -2.5, 2.5 } do
			for _, z in { -0.7, 0.8 } do
				add({
					Size = Vector3.new(0.25, 1.4, 0.25),
					Position = Vector3.new(x, 0.7, z),
					Material = Enum.Material.Wood,
				})
			end
			add({ Size = Vector3.new(0.25, 0.2, 1.9), Position = Vector3.new(x, 2.1, 0), Material = Enum.Material.Wood })
		end
		marker(model, "Seat", CFrame.new(0, 1.6, 0))
	end,
	PatioSet = function(model: Model, add)
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 3.2, 3.2),
			CFrame = CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
		})
		add({ Size = Vector3.new(0.2, 7.4, 0.2), Position = Vector3.new(0, 3.7, 0) })
		add({
			Name = "Umbrella",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 8.6, 8.6),
			CFrame = CFrame.new(0, 7.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(200, 190, 160),
			CanCollide = false,
		})
		for index, direction in { -Vector3.zAxis, Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis } do
			local center = direction * 3.3
			local facing = CFrame.lookAt(center, Vector3.zero)
			add({ Size = Vector3.new(1.6, 0.2, 1.6), CFrame = facing * CFrame.new(0, 1.5, 0) })
			add({ Size = Vector3.new(1.6, 1.6, 0.15), CFrame = facing * CFrame.new(0, 2.3, 0.75) })
			add({ Size = Vector3.new(1.2, 1.4, 1.2), CFrame = facing * CFrame.new(0, 0.7, 0), Transparency = 0.6 })
			marker(model, "Seat" .. index, facing * CFrame.new(0, 1.65, 0))
		end
	end,
	FirePit = function(model: Model, add)
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 4, 4),
			CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Slate,
		})
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 3, 3),
			CFrame = CFrame.new(0, 1.22, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(25, 22, 20),
		})
		for _, turn in { 0, 2.1, 4.2 } do
			add({
				Size = Vector3.new(0.35, 0.35, 2),
				CFrame = CFrame.new(0, 1.4, 0) * CFrame.Angles(0, turn, 0),
				Color = Color3.fromRGB(60, 40, 30),
			})
		end
		marker(model, "Fire", CFrame.new(0, 1.6, 0))
	end,
	Mailbox = function(_model: Model, add)
		add({
			Size = Vector3.new(0.4, 3.3, 0.4),
			Position = Vector3.new(0, 1.65, 0.3),
			Color = Color3.fromRGB(120, 90, 60),
		})
		add({ Size = Vector3.new(1, 1, 2), Position = Vector3.new(0, 3.5, 0) })
		local door = add({
			Name = "Door",
			Size = Vector3.new(1, 1, 0.08),
			Position = Vector3.new(0, 3.5, -1.04),
			Color = Color3.fromRGB(80, 80, 85),
		})
		-- Hinged along its bottom edge.
		door.PivotOffset = CFrame.new(0, -0.5, 0)
		local flag = add({
			Name = "Flag",
			Size = Vector3.new(0.06, 0.25, 0.9),
			Position = Vector3.new(0.55, 3.3, 0.2),
			Color = Color3.fromRGB(200, 40, 40),
		})
		-- Bolted to the box at its back end.
		flag.PivotOffset = CFrame.new(0, 0, 0.4)
	end,
	LampPost = function(model: Model, add)
		add({ Size = Vector3.new(1.3, 0.6, 1.3), Position = Vector3.new(0, 0.3, 0) })
		add({ Size = Vector3.new(0.35, 5.9, 0.35), Position = Vector3.new(0, 3.55, 0) })
		add({
			Name = "Glass",
			Size = Vector3.new(1, 1.2, 1),
			Position = Vector3.new(0, 7, 0),
			Color = Color3.fromRGB(255, 230, 160),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
		add({ Size = Vector3.new(1.2, 0.2, 1.2), Position = Vector3.new(0, 7.7, 0) })
		marker(model, "Light", CFrame.new(0, 7, 0))
	end,
	SolarPathLight = function(model: Model, add)
		add({ Size = Vector3.new(0.12, 1, 0.12), Position = Vector3.new(0, 0.5, 0) })
		add({
			Name = "Glass",
			Size = Vector3.new(0.35, 0.35, 0.35),
			Position = Vector3.new(0, 1.12, 0),
			Color = Color3.fromRGB(255, 240, 200),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
		add({ Size = Vector3.new(0.5, 0.12, 0.5), Position = Vector3.new(0, 1.35, 0) })
		marker(model, "Light", CFrame.new(0, 1.12, 0))
	end,
	BirdFeeder = function(_model: Model, add)
		add({ Size = Vector3.new(0.15, 7, 0.15), Position = Vector3.new(-0.6, 3.5, 0), Color = METAL })
		add({ Size = Vector3.new(0.9, 0.12, 0.12), Position = Vector3.new(-0.15, 6.9, 0), Color = METAL })
		add({ Size = Vector3.new(0.7, 0.8, 0.55), Position = Vector3.new(0.3, 5.9, 0), Material = Enum.Material.Wood })
		add({
			Size = Vector3.new(0.9, 0.12, 0.6),
			Position = Vector3.new(0.3, 6.35, 0),
			Color = Color3.fromRGB(110, 75, 50),
		})
	end,
	Birdhouse = function(_model: Model, add)
		add({
			Size = Vector3.new(0.4, 4.7, 0.4),
			Position = Vector3.new(0, 2.35, 0),
			Color = Color3.fromRGB(120, 90, 60),
		})
		add({ Size = Vector3.new(1, 1.2, 1), Position = Vector3.new(0, 5.3, 0), Material = Enum.Material.Wood })
		add({
			ClassName = "WedgePart",
			Size = Vector3.new(1.1, 0.5, 0.6),
			CFrame = CFrame.new(0, 6.15, -0.28),
			Color = Color3.fromRGB(110, 60, 45),
		})
		add({
			ClassName = "WedgePart",
			Size = Vector3.new(1.1, 0.5, 0.6),
			CFrame = CFrame.new(0, 6.15, 0.28) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(110, 60, 45),
		})
	end,
	PinkFlamingo = function(_model: Model, add)
		for _, x in { -0.12, 0.12 } do
			add({ Size = Vector3.new(0.05, 1.5, 0.05), Position = Vector3.new(x, 0.75, 0), Color = METAL })
		end
		add({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.7, 1.4),
			Position = Vector3.new(0, 1.8, 0.1),
			Material = Enum.Material.SmoothPlastic,
		})
		add({ Size = Vector3.new(0.12, 0.9, 0.12), Position = Vector3.new(0, 2.4, -0.5) })
		add({ Size = Vector3.new(0.25, 0.25, 0.45), Position = Vector3.new(0, 2.9, -0.65) })
	end,
	GardenWindmill = function(_model: Model, add)
		add({ Size = Vector3.new(1.6, 4, 1.6), Position = Vector3.new(0, 2, 0.1), Material = Enum.Material.Wood })
		add({
			ClassName = "WedgePart",
			Size = Vector3.new(1.8, 0.8, 1.8),
			CFrame = CFrame.new(0, 4.4, 0.1),
			Color = Color3.fromRGB(120, 60, 45),
		})
		-- Two sail bars sharing a hub: the game turns them about their own Z axis.
		for _, turn in { 0, math.pi / 2 } do
			add({
				Name = "Spinner",
				Size = Vector3.new(2.4, 0.35, 0.08),
				CFrame = CFrame.new(0, 3.9, -0.85) * CFrame.Angles(0, 0, turn),
				Color = WHITE,
				CanCollide = false,
			})
		end
	end,
	-- The Best Yard Trophy (won, never sold): a gold loving cup on a green-marble and walnut
	-- plinth, on a white display stand with a skirt of turf round its foot. The cup is its own
	-- part (`BestYardTrophy__Cup`) so the game can make it shine.
	BestYardTrophy = function(_model: Model, add)
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		add({
			Name = "Body",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 2.8, 2.8),
			CFrame = CFrame.new(0, 0.125, 0) * upright,
			Color = Color3.fromRGB(90, 160, 70),
			Material = Enum.Material.Grass,
		})
		add({
			Name = "Body",
			Size = Vector3.new(2, 2.2, 2),
			Position = Vector3.new(0, 1.35, 0),
			Color = WHITE,
			Material = Enum.Material.Wood,
		})
		add({
			Name = "Body",
			Size = Vector3.new(1.6, 0.4, 1.6),
			Position = Vector3.new(0, 2.65, 0),
			Color = Color3.fromRGB(70, 110, 85),
			Material = Enum.Material.Marble,
		})
		add({
			Name = "Body",
			Size = Vector3.new(1.2, 0.35, 1.2),
			Position = Vector3.new(0, 3.02, 0),
			Color = Color3.fromRGB(95, 60, 40),
			Material = Enum.Material.Wood,
		})
		local gold = Color3.fromRGB(214, 172, 52)
		add({
			Name = "Body",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 0.3, 0.3),
			CFrame = CFrame.new(0, 3.45, 0) * upright,
			Color = gold,
			Material = Enum.Material.Foil,
		})
		add({
			Name = "Cup",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 1.3, 1.3),
			CFrame = CFrame.new(0, 4.3, 0) * upright,
			Color = gold,
			Material = Enum.Material.Foil,
		})
		for _, x in { -0.85, 0.85 } do
			add({
				Name = "CupHandle",
				Size = Vector3.new(0.18, 0.75, 0.18),
				CFrame = CFrame.new(x, 4.35, 0) * CFrame.Angles(0, 0, x * 0.5),
				Color = gold,
				Material = Enum.Material.Foil,
			})
		end
		-- A little gold mower on the lid.
		add({ Name = "Body", Size = Vector3.new(0.5, 0.2, 0.7), Position = Vector3.new(0, 5.05, 0), Color = gold })
		add({
			Name = "Body",
			Size = Vector3.new(0.06, 0.4, 0.06),
			CFrame = CFrame.new(0, 5.3, 0.4) * CFrame.Angles(math.rad(-30), 0, 0),
			Color = gold,
		})
	end,
}

-- A decoration's stand-in: its real model's conventions with blocks, balls and cylinders.
-- GardenGnome and FlowerPatch use the yard props of the same name.
function Placeholders.decoration(id: string): Model
	local builder = DECORATION_BUILDERS[id]
	if not builder then
		return Placeholders.prop(id)
	end
	local model = Instance.new("Model")
	model.Name = id
	local decoration = Decorations.get(id)
	builder(model, decorationAdder(model, id, if decoration then decoration.color else STONE))
	return model
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
