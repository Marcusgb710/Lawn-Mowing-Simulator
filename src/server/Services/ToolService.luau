-- Hands out the tools loaded in the truck once the crew reaches the job site, and does the yard
-- work while players use them: on the job, or on your own lawn at home (see HomeLawnService),
-- where the tool you take out of storage is the real thing (see GiveHeld).
--
-- Mowers work the whole time they're equipped (the reel mower only while you're walking).
-- Every other tool works while you hold down the mouse button / tap and hold.
-- Riding mowers aren't held at all: they're welded under the player, who sits on them and
-- drives them around like walking. Push mowers and other walk-behind machines are held low
-- enough that their wheels touch the ground. Tools say whether they're working with a "Working"
-- attribute, so ToolFxController can spin blades and spools.
--
-- Tools wear out as they work (fuel, tires, blades, trimmer line; see Maintenance.luau). Their
-- condition is copied onto the Tool as attributes (Fuel, Pressure, Flat, Sharpness, Line,
-- Broken) for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local JobService = require(script.Parent.JobService)

-- How far in front of the player a tool does its work.
local REACH_OFFSET = 2
-- Machines that roll on the ground: held so their lowest point sits on it.
local GROUNDED = { FloorManual = true, FloorEngine = true, Bay = true }
-- How far behind the rider a towed attachment works.
local TOW_DISTANCE = 6

-- Particle color by what the tool does (its first verb).
local FX_COLORS = {
	Mow = Color3.fromRGB(110, 190, 70),
	Trim = Color3.fromRGB(150, 170, 50),
	Edge = Color3.fromRGB(110, 80, 50),
	Rake = Color3.fromRGB(210, 120, 40),
	Blow = Color3.fromRGB(210, 120, 40),
	Shear = Color3.fromRGB(60, 130, 50),
	Prune = Color3.fromRGB(60, 130, 50),
	Weed = Color3.fromRGB(110, 150, 50),
	Water = Color3.fromRGB(110, 170, 230),
	Dig = Color3.fromRGB(110, 80, 50),
	Cultivate = Color3.fromRGB(90, 65, 45),
	Spread = Color3.fromRGB(235, 235, 220),
	Spray = Color3.fromRGB(170, 210, 150),
	Seed = Color3.fromRGB(200, 180, 120),
}
local DEFAULT_FX_COLOR = Color3.fromRGB(120, 90, 60)

local ToolService = {}

-- [Tool] = true while the tool is running
local running = {}
local rng = Random.new()
-- [Tool] = its last list of warnings, so the player's profile is refreshed when one appears
local lastWarnings = setmetatable({}, { __mode = "k" })

-- Condition fields copied onto Tool attributes, and their attribute names.
local CONDITION_ATTRIBUTES =
	{ fuel = "Fuel", pressure = "Pressure", flat = "Flat", sharpness = "Sharpness", line = "Line", broken = "Broken" }

-- Copies a tool's condition onto it for the HUD. Numbers only update once they've moved a bit,
-- so a running mower doesn't send an update every tick.
local function syncCondition(tool: Tool, condition)
	for key, attribute in CONDITION_ATTRIBUTES do
		local value = condition[key]
		local current = tool:GetAttribute(attribute)
		local changed = if typeof(value) == "number" and typeof(current) == "number"
			then math.abs(value - current) >= 0.01 or (value <= 0) ~= (current <= 0)
			else value ~= current
		if changed then
			tool:SetAttribute(attribute, value)
		end
	end
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- The part everything in a tool is welded to: "Handle", or "RideRoot" on riding mowers.
local function toolBase(tool: Tool): BasePart?
	local base = tool:FindFirstChild("Handle") or tool:FindFirstChild("RideRoot")
	return if base and base:IsA("BasePart") then base else nil
end

local function setFx(tool: Tool, enabled: boolean)
	local base = toolBase(tool)
	local emitter = base and base:FindFirstChild("WorkFx")
	if emitter and emitter:IsA("ParticleEmitter") and emitter.Enabled ~= enabled then
		emitter.Enabled = enabled
	end
	if tool:GetAttribute("Working") ~= enabled then
		tool:SetAttribute("Working", enabled)
	end
end

local function addFx(tool: Tool, verb: string?)
	local handle = toolBase(tool)
	if not handle or handle:FindFirstChild("WorkFx") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WorkFx"
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(verb and FX_COLORS[verb] or DEFAULT_FX_COLOR)
	emitter.Size = NumberSequence.new(0.25)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Parent = handle
end

-- Lowest point of a tool, in studs below `frame`.
local function depthBelow(tool: Tool, frame: CFrame): number
	local lowest = 0
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
						lowest = math.min(lowest, frame:PointToObjectSpace(corner).Y)
					end
				end
			end
		end
	end
	return -lowest
end

-- How high above the ground the hand holding a tool is. While holding a tool the arm points
-- forward, so the hand is at about shoulder height.
local function holdHeight(character: Model): number?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local shoulder = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
	if not (humanoid and root and root:IsA("BasePart") and shoulder and shoulder:IsA("Motor6D") and shoulder.Part0) then
		return nil
	end
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local floor = root.Position.Y - root.Size.Y / 2 - legs
	return (shoulder.Part0.CFrame * shoulder.C0).Position.Y - floor
end

-- Moves a machine's grip so that, held at `height`, its lowest point (its wheels) touches the
-- ground, whether the model's handlebar is 2.6 or 4.3 studs up.
local function groundGrip(tool: Tool, height: number)
	local base = toolBase(tool)
	if not base then
		return
	end
	local depth = depthBelow(tool, base.CFrame * tool.Grip)
	tool.Grip *= CFrame.new(0, height - depth, 0)
end

local function restoreHipHeight(humanoid: Humanoid?)
	local base = humanoid and humanoid:GetAttribute("BaseHipHeight")
	if humanoid and typeof(base) == "number" then
		humanoid.HipHeight = base
		humanoid:SetAttribute("BaseHipHeight", nil)
	end
end

-- Turns a riding mower into something you sit on. Without a part named "Handle" Roblox doesn't
-- put it in your hand; instead it's welded so the seat sits under the HumanoidRootPart.
local function setUpRide(player: Player, tool: Tool, item)
	local base = tool:FindFirstChild("Handle")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (base and base:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	base.Name = "RideRoot"
	tool.RequiresHandle = false
	tool:SetAttribute("Ride", true)
	-- On stand-on machines your feet are on the platform, so your legs sit above it.
	local standing = item.ride.stand == true
	local humanoid = getHumanoid(player)
	local legs = 0
	if standing then
		tool:SetAttribute("Stand", true)
		legs = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	end

	-- The weld only does anything once the tool is equipped and in the character.
	local seat: Vector3 = item.ride.seat
	local weld = Instance.new("Weld")
	weld.Name = "RideWeld"
	weld.Part0 = root
	weld.Part1 = base
	weld.C0 = CFrame.new(0, -root.Size.Y / 2 - legs, 0) * CFrame.new(-seat)
	weld.C1 = tool.Grip
	weld.Parent = base
	-- How high the seat (or platform plus legs) is off the ground: how high the player floats.
	tool:SetAttribute("SeatHeight", depthBelow(tool, base.CFrame * tool.Grip) + seat.Y + legs)
end

-- Hitches a tow-behind attachment (the aerator) to a ride-on, as a model a little behind it.
local function hitch(tool: Tool, towedId: string)
	local base = toolBase(tool)
	local towed = Tools.get(towedId)
	if not (base and towed) then
		return
	end
	local model = Assets.toolDisplay(towed.category, towedId)
	model.Name = "Towed"
	-- Measure in the way the ride-on is held (upright, front -Z), whichever way its handle points.
	local frame = base.CFrame * tool.Grip
	local behind = 0
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
						behind = math.max(behind, frame:PointToObjectSpace(corner).Z)
					end
				end
			end
		end
	end
	local _, towedSize = model:GetBoundingBox()
	local ground = frame * CFrame.new(0, -depthBelow(tool, frame), behind + towedSize.Z / 2 + 0.8)
	Assets.placeOnGround(model, ground)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = base
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = tool
	tool:SetAttribute("Towing", towedId)
end

local function hookTool(player: Player, tool: Tool, item)
	-- Mowers work the whole time they're equipped; everything else while the button is held.
	local passive = item.use == "Passive"

	tool.Equipped:Connect(function()
		local humanoid = getHumanoid(player)
		if humanoid and item.walkSpeed then
			-- Soft tires slow you down wherever you push it.
			local data = DataService:Get(player)
			humanoid.WalkSpeed = item.walkSpeed * Maintenance.tireFactor(data and data.condition[item.id] or {})
		end
		-- Lift R15 characters so the riding mower's wheels touch the ground under them.
		local seatHeight = tool:GetAttribute("SeatHeight")
		if humanoid and typeof(seatHeight) == "number" and humanoid.RigType == Enum.HumanoidRigType.R15 then
			if humanoid:GetAttribute("BaseHipHeight") == nil then
				humanoid:SetAttribute("BaseHipHeight", humanoid.HipHeight)
			end
			humanoid.HipHeight = seatHeight
		end
		if passive then
			running[tool] = true
		end
	end)

	tool.Unequipped:Connect(function()
		running[tool] = nil
		setFx(tool, false)
		if Tools.hasVerb(item, "Haul") then
			JobService:PutAway(player)
		end
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
			restoreHipHeight(humanoid)
		end
	end)

	if not passive then
		tool.Activated:Connect(function()
			running[tool] = true
		end)
		tool.Deactivated:Connect(function()
			running[tool] = nil
			setFx(tool, false)
		end)
	end

	tool.Destroying:Connect(function()
		running[tool] = nil
	end)
end

-- Takes away every game tool, and returns the id of the one they were holding.
local function clearTools(player: Player): string?
	local holding = nil
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in container and container:GetChildren() or {} do
			if child:IsA("Tool") and child:GetAttribute("ItemId") then
				if child.Parent == player.Character then
					holding = child:GetAttribute("ItemId")
				end
				child:Destroy()
			end
		end
	end
	return holding
end

-- Public API ---------------------------------------------------------------------------------

-- Gives the player the tools they loaded in the truck if they're at a job site, otherwise takes
-- them away. Call after anything that could change that.
-- Builds the Tool for one of the player's tools, ready to put in their backpack. Only on a job
-- does a ride-on that can tow pull the tow-behind aerator.
local function makeTool(player: Player, data, item, height: number?, atJob: boolean): Tool
	local tool = Assets.tool(item.category, item.id)
	tool.Name = item.name
	tool.ToolTip = Items.CategoryInfo[item.category].displayName
	tool.CanBeDropped = false
	tool:SetAttribute("Category", item.category)
	tool:SetAttribute("ItemId", item.id)
	syncCondition(tool, data.condition[item.id] or {})
	if item.ride then
		setUpRide(player, tool, item)
		-- A ride-on that can tow pulls the tow-behind aerator, if it came along.
		if atJob and item.tows and data.loadout.TowBehindAerator then
			hitch(tool, "TowBehindAerator")
		end
	elseif height and GROUNDED[item.sizeClass] then
		groundGrip(tool, height)
	end
	addFx(tool, item.verbs[1])
	hookTool(player, tool, item)
	return tool
end

-- Whether this tool goes in your hands as a Tool you use (not supplies, gloves or a towed
-- attachment, which are just carried).
function ToolService.isHeld(item): boolean
	return Tools.isHeld(item)
end

-- A tool taken out of storage at the business, equipped straight away: a ride-on to drive (up
-- the trailer's ramp, back to its bay) or one in your hands, which works on your own lawn.
-- TruckService takes it away again when it's put down.
function ToolService:GiveHeld(player: Player, itemId: string): Tool?
	local data = DataService:Get(player)
	local item = Tools.get(itemId)
	local humanoid = getHumanoid(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (data and item and ToolService.isHeld(item) and humanoid and backpack and humanoid.Health > 0) then
		return nil
	end
	local height = player.Character and holdHeight(player.Character)
	local tool = makeTool(player, data, item, height, false)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	return tool
end

-- Puts a player back on their feet at normal speed after a ride-on goes away.
function ToolService:ResetRider(player: Player)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		restoreHipHeight(humanoid)
	end
end

function ToolService:GiveTools(player: Player)
	local data = DataService:Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end

	local wasHolding = clearTools(player)
	local humanoid = getHumanoid(player)
	if humanoid and wasHolding then
		-- Mowers change your speed and riding mowers your height, so undo that when they go away.
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		restoreHipHeight(humanoid)
	end
	if not JobService:IsAtJobSite(player) then
		return
	end

	local height = player.Character and holdHeight(player.Character)
	-- A tow-behind attachment does nothing without a ride-on that can pull it.
	if data.loadout.TowBehindAerator then
		local puller = false
		for id in data.loadout do
			local tool = Tools.get(id)
			puller = puller or (tool ~= nil and tool.tows == true)
		end
		if not puller then
			Net.event("Notify"):FireClient(player, "The tow-behind aerator needs a ride-on that can pull it.")
		end
	end
	for _, itemId in Storage.loadedIds(data.loadout) do
		local item = Tools.get(itemId)
		if not Tools.isHeld(item) then
			continue
		end
		local tool = makeTool(player, data, item, height, true)
		tool.Parent = backpack

		-- Swapping gear shouldn't make you put your tool away.
		if itemId == wasHolding and humanoid then
			humanoid:EquipTool(tool)
		end
	end
end

-- Call after a player's tools were worked on, so the HUD shows their new condition.
function ToolService:RefreshCondition(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in container and container:GetChildren() or {} do
			local itemId = child:IsA("Tool") and child:GetAttribute("ItemId")
			if itemId and data.condition[itemId] then
				syncCondition(child, data.condition[itemId])
				-- Fixed tools can warn again later; ones that are still stuck don't repeat themselves.
				if not Maintenance.blocker(Tools.get(itemId), data.condition[itemId]) then
					child:SetAttribute("Blocked", nil)
				end
			end
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------------------

-- Work goes to the job they're on, or to their crew's own lawn.
local function applyWork(
	player: Player,
	atJob: boolean,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	options
): boolean
	if atJob then
		return JobService:ApplyWork(player, position, radius, toolId, amount, options)
	end
	return HomeLawnService:ApplyWork(player, position, radius, toolId, amount, options)
end

local function workTick(elapsed: number)
	for tool in running do
		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (player and humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
			running[tool] = nil
			continue
		end
		-- Off the job, tools only work on your own lawn: driving a ride-on or carrying a mower
		-- around the business does no work and no wear.
		local atJob = JobService:IsAtJobSite(player)
		if not (atJob or HomeLawnService:IsOnLawn(player)) then
			setFx(tool, false)
			continue
		end

		local itemId = tool:GetAttribute("ItemId")
		local item = Tools.get(itemId)
		local data = DataService:Get(player)
		local condition = data and data.condition[itemId] or {}
		local moving = humanoid.MoveDirection.Magnitude > 0.1

		-- Out of fuel, a flat, no line or a wrecked engine: it just won't go. Say so once.
		local blocker = Maintenance.blocker(item, condition)
		if tool:GetAttribute("Blocked") ~= blocker then
			tool:SetAttribute("Blocked", blocker)
			if blocker then
				Net.event("Notify"):FireClient(player, blocker)
			end
		end
		if blocker then
			setFx(tool, false)
			continue
		end
		if item.motorized == false and not moving then
			setFx(tool, false)
			continue
		end

		-- Soft tires slow you down; a dull blade cuts slower and rougher.
		local speed, quality = Maintenance.effects(condition)
		if item.walkSpeed and tool.Parent == character then
			local walkSpeed = item.walkSpeed * Maintenance.tireFactor(condition)
			if math.abs(humanoid.WalkSpeed - walkSpeed) > 0.1 then
				humanoid.WalkSpeed = walkSpeed
			end
		end

		-- While it tows, a ride-on's own deck is up: the attachment behind does the work.
		local towedId = tool:GetAttribute("Towing")
		local cut = false
		if not towedId then
			local position = root.Position + root.CFrame.LookVector * REACH_OFFSET
			cut = applyWork(player, atJob, position, item.radius, itemId, item.power * elapsed * speed, {
				damagesHazards = Tools.damagesHazards(item),
				quiet = item.use == "Passive" and not moving,
				moving = moving,
				seconds = elapsed,
				qualityScale = quality,
			})
		end
		Maintenance.wear(item, condition, elapsed, true, moving, cut == true, rng:NextNumber())
		syncCondition(tool, condition)
		-- The Truck menu reads the profile, so send it when something new goes wrong.
		local warnings = table.concat(Maintenance.warnings(item, condition), ",")
		if lastWarnings[tool] ~= warnings then
			if lastWarnings[tool] ~= nil and data then
				DataService:Changed(player)
			end
			lastWarnings[tool] = warnings
		end

		-- Whatever it's towing works behind it, wearing its own tires.
		local towed = towedId and Tools.get(towedId)
		if towed and moving then
			local towedCondition = data and data.condition[towedId] or {}
			local towBlocker = Maintenance.blocker(towed, towedCondition)
			if tool:GetAttribute("TowBlocked") ~= towBlocker then
				tool:SetAttribute("TowBlocked", towBlocker)
				if towBlocker then
					Net.event("Notify"):FireClient(player, `The {towed.name}: {towBlocker}`)
				end
			end
			if not towBlocker then
				local towSpeed, towQuality = Maintenance.effects(towedCondition)
				local behind = root.Position - root.CFrame.LookVector * TOW_DISTANCE
				local towedCut =
					applyWork(player, atJob, behind, towed.radius, towedId, towed.power * elapsed * towSpeed, {
						quiet = true,
						moving = true,
						seconds = elapsed,
						qualityScale = towQuality,
					})
				Maintenance.wear(towed, towedCondition, elapsed, false, true, towedCut == true, rng:NextNumber())
			end
		end
		setFx(tool, true)
	end
end

function ToolService:Start()
	JobService.PlayerStateChanged:Connect(function(player)
		self:GiveTools(player)
		-- Tools wore out on the job; let the menus catch up.
		DataService:Changed(player)
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			if DataService:WaitForData(player) then
				-- Backpack gets recreated with the character, so wait for it.
				player:WaitForChild("Backpack")
				self:GiveTools(player)
			end
		end)
		if player.Character and DataService:WaitForData(player) then
			self:GiveTools(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local accumulated = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulated += deltaTime
		if accumulated >= GameConfig.WorkTickRate then
			workTick(accumulated)
			accumulated = 0
		end
	end)
end

return ToolService
