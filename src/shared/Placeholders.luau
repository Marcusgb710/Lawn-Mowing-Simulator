-- Block-model stand-ins used until the real models exist in ReplicatedStorage.Assets.
-- Nothing else in the game depends on what these look like, so feel free to delete them later.

local Items = require(script.Parent.Config.Items)

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

-- With the default grip, a tool handle's +Y axis points forward out of the hand and +Z points up.
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
		local deckSize = if item.tier >= 4 then Vector3.new(4.5, 4.5, 1.4) else Vector3.new(2.6, 2.6, 1)
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

function Placeholders.tool(category: string, itemId: string): Tool
	local item = Items.get(category, itemId)
	local tool = Instance.new("Tool")
	tool.Name = item.name
	TOOL_BUILDERS[category](tool, item)
	return tool
end

-- Trucks ------------------------------------------------------------------------------------

-- Invisible part marking where loaded tools sit. Real models can include their own "BedArea"
-- parts (with a Slots attribute) to control where tools show up.
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

	if itemId == "LandscapingTruck" then
		add({ Name = "Box", Size = Vector3.new(7.4, 6, 8), Position = Vector3.new(0, 5.1, 4), Color = item.color })
	else
		local bedColor = item.color:Lerp(Color3.new(0, 0, 0), 0.2)
		add({ Name = "BedLeft", Size = Vector3.new(0.4, 2, 8), Position = Vector3.new(-3.3, 3.1, 4), Color = bedColor })
		add({ Name = "BedRight", Size = Vector3.new(0.4, 2, 8), Position = Vector3.new(3.3, 3.1, 4), Color = bedColor })
		add({ Name = "Tailgate", Size = Vector3.new(7, 2, 0.4), Position = Vector3.new(0, 3.1, 7.8), Color = bedColor })
	end

	bedArea(model, Vector3.new(6, 0.2, 7.6), Vector3.new(0, 2.2, 4), item.bedSlots)

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
	bedArea(model, Vector3.new(6, 0.2, length - 1), Vector3.new(0, 2, 0), item.extraSlots)

	return model
end

-- Business buildings ------------------------------------------------------------------------

-- Buildings face -Z (front door toward the street), bottom at y = 0.
local BUILDING_SIZES = {
	Shed = Vector3.new(12, 10, 10),
	Garage = Vector3.new(26, 14, 20),
	SmallOffice = Vector3.new(36, 16, 24),
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
	if itemId == "SmallOffice" then
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

local PROP_BUILDERS = {
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
