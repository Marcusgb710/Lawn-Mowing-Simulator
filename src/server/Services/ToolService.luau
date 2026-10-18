-- Hands out the tools loaded in the truck once the crew reaches the job site, and does the yard
-- work while players use them. At the business your hands are free for carrying tools around.
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
local JobService = require(script.Parent.JobService)

-- How far in front of the player a tool does its work.
local REACH_OFFSET = 2
-- Machines that roll on the ground: held so their lowest point sits on it.
local GROUNDED = { FloorManual = true, FloorEngine = true, Bay = true }
-- Tools that never go in the hotbar: supplies, and gloves (worn, not used).
local NOT_HELD = { Supply = true, Worn = true }

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

	-- The weld only does anything once the tool is equipped and in the character.
	local seat: Vector3 = item.ride.seat
	local weld = Instance.new("Weld")
	weld.Name = "RideWeld"
	weld.Part0 = root
	weld.Part1 = base
	weld.C0 = CFrame.new(0, -root.Size.Y / 2, 0) * CFrame.new(-seat)
	weld.C1 = tool.Grip
	weld.Parent = base
	-- How high the seat is off the ground, which is how high the player needs to float.
	tool:SetAttribute("SeatHeight", depthBelow(tool, base.CFrame * tool.Grip) + seat.Y)
end

local function hookTool(player: Player, tool: Tool, item)
	-- Mowers work the whole time they're equipped; everything else while the button is held.
	local passive = item.use == "Passive"

	tool.Equipped:Connect(function()
		local humanoid = getHumanoid(player)
		if humanoid and item.walkSpeed then
			humanoid.WalkSpeed = item.walkSpeed
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
	for _, itemId in Storage.loadedIds(data.loadout) do
		local item = Tools.get(itemId)
		if NOT_HELD[item.use] then
			continue
		end
		local tool = Assets.tool(item.category, itemId)
		tool.Name = item.name
		tool.ToolTip = Items.CategoryInfo[item.category].displayName
		tool.CanBeDropped = false
		tool:SetAttribute("Category", item.category)
		tool:SetAttribute("ItemId", itemId)
		syncCondition(tool, data.condition[itemId] or {})
		if item.ride then
			setUpRide(player, tool, item)
		elseif height and GROUNDED[item.sizeClass] then
			groundGrip(tool, height)
		end
		addFx(tool, item.verbs[1])
		hookTool(player, tool, item)
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

		local position = root.Position + root.CFrame.LookVector * REACH_OFFSET
		local cut = JobService:ApplyWork(player, position, item.radius, itemId, item.power * elapsed * speed, {
			damagesHazards = Tools.damagesHazards(item),
			quiet = item.use == "Passive" and not moving,
			moving = moving,
			seconds = elapsed,
			qualityScale = quality,
		})
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
