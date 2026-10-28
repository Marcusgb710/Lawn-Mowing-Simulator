-- Hands out the tools loaded in the truck once the crew reaches the job site, and does the yard
-- work while players use them: on the job, or on your own lawn at home (see HomeLawnService),
-- where the tool you take out of storage is the real thing (see GiveHeld).
--
-- Mowers work the whole time they're equipped (the reel mower only while you're walking).
-- Every other tool works while you hold down the mouse button / tap and hold, except hand shears
-- (`snip` in Tools.luau), which cut one snip at a time where you aim: the client says which way
-- you're looking, and the server works out what's in reach there and what gets cut.
-- A motorized mower that runs over junk hidden in the grass (Config/Debris.luau) chews it up: its
-- blade loses a chunk of its edge and it stalls for a moment.
-- Riding mowers aren't held at all: they're welded under the player, who sits on them and
-- drives them around like walking. Push mowers and other walk-behind machines are held low
-- enough that their wheels touch the ground. Tools say whether they're working with a "Working"
-- attribute, so ToolFxController can spin blades and spools. A mower cuts grass by sweeping its
-- deck from where it was last tick to where it is now (see Lawn:Sweep), and says whether that
-- cut any with a "Cutting" attribute: its clippings fly, and it slows down, only then.
--
-- Tools wear out as they work (fuel, tires, blades, trimmer line; see Maintenance.luau). Their
-- condition is copied onto the Tool as attributes (Fuel, Pressure, Flat, Sharpness, Line,
-- Broken) for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Debris = require(Shared.Config.Debris)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Premium = require(Shared.Config.Premium)
local Sounds = require(Shared.Sounds)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local JobService = require(script.Parent.JobService)

-- Machines that roll on the ground: held so their lowest point sits on it.
local GROUNDED = { FloorManual = true, FloorEngine = true, Bay = true }
-- How far behind the rider a towed attachment works.
local TOW_DISTANCE = 6

-- Particle color by what the tool does (its first verb).
local FX_COLORS = {
	Mow = Color3.fromRGB(196, 240, 120),
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
-- Where a reel mower's clippings come out of it: just behind. A motorized mower throws them out
-- the right side of its deck instead (see addFx).
local REAR_CHUTE = Vector3.new(0, 0, 0.5)

local ToolService = {}

-- [Tool] = true while the tool is running
local running = {}
local rng = Random.new()
-- [Tool] = its last list of warnings, so the player's profile is refreshed when one appears
local lastWarnings = setmetatable({}, { __mode = "k" })
-- [Player] = { [toolId] = true } for tools set down to be worked on (see MaintenanceService),
-- which stay out of their hotbar on a job until they pick them back up
local withheld = {}
-- A blade cutting below this finish leaves the grass torn and ragged (see GrassController).
local RAGGED_BELOW = 0.8
-- [Tool] = os.clock() a mower that hit something hidden in the grass starts again
local stalledUntil = setmetatable({}, { __mode = "k" })
-- [Tool] = where a mower's deck was at its last tick, for as long as it has run without a break:
-- its next sweep goes from there to where the deck is now.
local lastDeck = setmetatable({}, { __mode = "k" })
-- A deck that moved less than this since the last tick (studs along the ground) is standing still.
-- Sweeping a sliver that short would turn the deck to face wherever the jitter pointed, and flip
-- its orientation every tick.
local STANDING_DECK = 0.05

-- Snips of hand shears land where your aim crosses this high above your feet (about the top of
-- tall grass, which is what you see when you aim at it).
local SNIP_AIM_HEIGHT = 1
-- How many snips can bank up, so one that arrives a little early over the network still counts.
local SNIP_BURST = 2
-- How long the clippings fly after a snip that cut something (seconds).
local SNIP_FX_TIME = 0.15
-- [Player] = { at = os.clock() of their last snip, banked = snips they may make right now }
local snips = {}
local snipRay = RaycastParams.new()
snipRay.FilterType = Enum.RaycastFilterType.Exclude

-- Condition fields copied onto Tool attributes, and their attribute names.
local CONDITION_ATTRIBUTES =
	{ fuel = "Fuel", pressure = "Pressure", flat = "Flat", sharpness = "Sharpness", line = "Line", broken = "Broken" }

-- Copies a tool's condition onto it for the HUD. Numbers only update once they've moved a bit,
-- so a running mower doesn't send an update every tick.
local function syncCondition(tool: Instance, condition)
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

local function isMower(tool: Tool): boolean
	return tool:GetAttribute("Category") == "Mower"
end

-- Turns the tool's clippings (its WorkFx emitter) on or off.
local function setEmitter(tool: Tool, enabled: boolean)
	local base = toolBase(tool)
	-- A mower's hangs off its Chute attachment (see addFx); everything else's is on the base.
	local holder = base and (base:FindFirstChild("Chute") or base)
	local emitter = holder and holder:FindFirstChild("WorkFx")
	if emitter and emitter:IsA("ParticleEmitter") and emitter.Enabled ~= enabled then
		emitter.Enabled = enabled
	end
end

-- Whether a mower's last sweep cut any grass: its clippings fly only then, so it's the mowers'
-- WorkFx that follows "Cutting" instead of "Working". Only mowers have it.
local function setCutting(tool: Tool, cutting: boolean)
	if not isMower(tool) then
		return
	end
	if tool:GetAttribute("Cutting") ~= cutting then
		tool:SetAttribute("Cutting", cutting)
	end
	setEmitter(tool, cutting)
end

local function setFx(tool: Tool, enabled: boolean)
	if not isMower(tool) then
		setEmitter(tool, enabled)
	end
	if tool:GetAttribute("Working") ~= enabled then
		tool:SetAttribute("Working", enabled)
	end
	if not enabled then
		setCutting(tool, false)
	end
end

-- The tool stopped working, or can't right now: its effects go off. A mower forgets where its
-- deck was, so when it starts again it doesn't cut a line across the gap.
local function stopWork(tool: Tool)
	lastDeck[tool] = nil
	setFx(tool, false)
end

local function addFx(tool: Tool, item)
	local handle = toolBase(tool)
	if not handle or handle:FindFirstChild("WorkFx", true) then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WorkFx"
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(item.verbs[1] and FX_COLORS[item.verbs[1]] or DEFAULT_FX_COLOR)
	emitter.Size = NumberSequence.new(0.25)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	if item.category == "Mower" then
		-- The clippings leave where the deck throws them, and only a short way: out the right side of
		-- a motorized mower's deck, just behind a reel mower.
		local behind = item.motorized == false
		local chute = Instance.new("Attachment")
		chute.Name = "Chute"
		chute.Position = if behind then REAR_CHUTE else Vector3.new(item.radius, 0, 0)
		chute.Parent = handle
		emitter.Speed = NumberRange.new(6, 10)
		emitter.SpreadAngle = Vector2.new(20, 20)
		emitter.EmissionDirection = if behind then Enum.NormalId.Back else Enum.NormalId.Right
		emitter.Parent = chute
	else
		emitter.Parent = handle
	end
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
		stopWork(tool)
		if Tools.hasVerb(item, "Haul") then
			JobService:PutAway(player)
		end
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
			restoreHipHeight(humanoid)
		end
	end)

	-- Hand shears cut a snip at a time instead (see snip below).
	if not passive and not item.snip then
		tool.Activated:Connect(function()
			running[tool] = true
		end)
		tool.Deactivated:Connect(function()
			running[tool] = nil
			stopWork(tool)
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
	-- A premium tool's finish (see Premium.luau).
	Premium.applyFinish(tool, Premium.finishFor(data.premium, item.id))
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
	addFx(tool, item)
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
		if not Tools.isHeld(item) or (withheld[player] and withheld[player][itemId]) then
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

-- Copies a tool's condition onto any Instance as attributes (Fuel, Pressure, Flat, Sharpness,
-- Line, Broken), for the HUD and for how it looks (see ToolFxController).
ToolService.showCondition = syncCondition

-- Keeps a loaded tool out of the player's hotbar while it's set down to be worked on, or gives
-- it back (in their hands) once they pick it up.
function ToolService:Withhold(player: Player, toolId: string, keep: boolean)
	withheld[player] = withheld[player] or {}
	withheld[player][toolId] = if keep then true else nil
	if keep then
		for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
			for _, child in container and container:GetChildren() or {} do
				if child:IsA("Tool") and child:GetAttribute("ItemId") == toolId then
					child:Destroy()
				end
			end
		end
		return
	end
	self:GiveTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = getHumanoid(player)
	for _, child in backpack and backpack:GetChildren() or {} do
		if child:IsA("Tool") and child:GetAttribute("ItemId") == toolId and humanoid then
			humanoid:EquipTool(child)
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

-- Work goes to the job they're on, or to their crew's own lawn. Says whether anything got done,
-- and what junk hidden in the grass a mower just chewed up.
local function applyWork(
	player: Player,
	atJob: boolean,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	options
): (boolean, { any }?)
	if atJob then
		return JobService:ApplyWork(player, position, radius, toolId, amount, options)
	end
	return HomeLawnService:ApplyWork(player, position, radius, toolId, amount, options)
end

-- A mower's deck, `halfWidth` studs either side, sweeping from one spot to another this tick (world
-- studs). Says whether it cut any grass, and what junk hidden in it the mower chewed up.
local function sweep(
	player: Player,
	atJob: boolean,
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number,
	toolId: string,
	options
): (boolean, { any }?)
	if atJob then
		return JobService:Sweep(player, fromX, fromZ, toX, toZ, halfWidth, toolId, options)
	end
	return HomeLawnService:Sweep(player, fromX, fromZ, toX, toZ, halfWidth, toolId, options)
end

-- A snip of hand shears on the grass within `radius` of (x, z), in world studs.
local function snipAt(
	player: Player,
	atJob: boolean,
	x: number,
	z: number,
	radius: number,
	toolId: string,
	options
): (boolean, { any }?)
	if atJob then
		return JobService:SnipAt(player, x, z, radius, toolId, options)
	end
	return HomeLawnService:SnipAt(player, x, z, radius, toolId, options)
end

-- The Truck menu reads the profile, so send it when something new goes wrong with a tool.
local function noteWarnings(player: Player, tool: Tool, item, condition, data)
	local warnings = table.concat(Maintenance.warnings(item, condition), ",")
	if lastWarnings[tool] ~= warnings then
		if lastWarnings[tool] ~= nil and data then
			DataService:Changed(player)
		end
		lastWarnings[tool] = warnings
	end
end

-- A mower ran over junk hidden in the grass: each piece takes a chunk out of its blade's edge
-- (Debris.luau `wear`), and the engine stalls for a moment.
local function strike(tool: Tool, condition, hits: { any }?, perks)
	if not (hits and #hits > 0) then
		return
	end
	for _, debris in hits do
		Maintenance.strike(condition, debris.kind.wear, perks)
	end
	stalledUntil[tool] = os.clock() + Debris.StallTime
	local base = toolBase(tool)
	if base then
		Sounds.play(base, "BladeHit")
	end
end

local function isStalled(tool: Tool): boolean
	return (stalledUntil[tool] or 0) > os.clock()
end

-- One snip of hand shears, aimed along `direction`: which way the player's looking, the only thing
-- the client says. The server checks they're holding shears, that it isn't sooner than the shears'
-- rhythm allows, and where the snip lands: where their aim crosses grass-top height, within the
-- shears' reach of their eyes, with nothing solid in the way. Then the grass within a stud of
-- there is snipped (see Lawn:SnipAt) or, where there's none left to cut, the one thing nearest
-- gets cut (see Lawn:ApplyWork), and the shears wear as they cut.
local function snip(player: Player, direction: unknown)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local length = direction.Magnitude
	-- NaN fails every comparison, so this catches it too.
	if not (length > 0.5 and length < 1.5) then
		return
	end
	direction /= length
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local itemId = tool and tool:GetAttribute("ItemId")
	local item = if typeof(itemId) == "string" then Tools.get(itemId) else nil
	local config = item and item.snip
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	local data = DataService:Get(player)
	if
		not (tool and item and config and data and humanoid and humanoid.Health > 0)
		or not (root and root:IsA("BasePart") and head and head:IsA("BasePart"))
	then
		return
	end

	-- No faster than the shears' rhythm, with a snip or two banked for network hiccups.
	local now = os.clock()
	local rhythm = snips[player] or { at = now, banked = SNIP_BURST }
	snips[player] = rhythm
	rhythm.banked = math.min(SNIP_BURST, rhythm.banked + (now - rhythm.at) / config.interval)
	rhythm.at = now
	if rhythm.banked < 1 then
		return
	end
	rhythm.banked -= 1

	-- Off the job, only on your crew's own lawn.
	local atJob = JobService:IsAtJobSite(player)
	local condition = data.condition[item.id] or {}
	if not (atJob or HomeLawnService:CanWork(player, item.id)) or Maintenance.blocker(item, condition) then
		return
	end

	-- Where it lands: you have to look down at the grass, close enough to reach it.
	if direction.Y > -0.05 then
		return
	end
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local grassTop = root.Position.Y - root.Size.Y / 2 - legs + SNIP_AIM_HEIGHT
	local eyes = head.Position
	local distance = (eyes.Y - grassTop) / -direction.Y
	if distance <= 0 or distance > config.reach then
		return
	end
	snipRay.FilterDescendantsInstances = { character }
	if workspace:Raycast(eyes, direction * distance, snipRay) then
		-- Something solid in the way: a wall, the truck, someone else.
		return
	end
	local point = eyes + direction * distance

	local speed, quality = Maintenance.effects(condition)
	local options = {
		damagesHazards = Tools.damagesHazards(item),
		snip = true,
		seconds = config.interval,
		qualityScale = quality,
		ragged = quality < RAGGED_BELOW,
	}
	-- The grass around the snip goes first. Where there's none left to cut, the snip goes to
	-- whatever else the shears reach (a weed, a flower), the one thing nearest.
	local cut = snipAt(player, atJob, point.X, point.Z, GameConfig.SnipRadius, item.id, options)
	if not cut then
		cut = applyWork(player, atJob, point, config.radius, item.id, config.work * speed, options)
	end
	local perks = Premium.perksFor(data.premium, item.id)
	Maintenance.wear(item, condition, config.interval, false, false, cut == true, rng:NextNumber(), perks)
	syncCondition(tool, condition)
	noteWarnings(player, tool, item, condition, data)
	local base = toolBase(tool)
	if base then
		Sounds.play(base, "Snip", 0.4)
	end
	if cut then
		-- A puff of clippings (the shears' WorkFx), on everyone's screen.
		setFx(tool, true)
		task.delay(SNIP_FX_TIME, function()
			if tool.Parent then
				setFx(tool, false)
			end
		end)
	end
end

local function workTick(elapsed: number)
	for tool in running do
		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (player and humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
			running[tool] = nil
			lastDeck[tool] = nil
			continue
		end
		-- Off the job, tools only work on your own lawn: driving a ride-on or carrying a mower
		-- around the business does no work and no wear.
		local atJob = JobService:IsAtJobSite(player)
		if not (atJob or HomeLawnService:CanWork(player, tool:GetAttribute("ItemId"))) then
			stopWork(tool)
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
			stopWork(tool)
			continue
		end
		-- It hit something hidden in the grass: it catches again in a moment.
		if isStalled(tool) then
			stopWork(tool)
			continue
		end
		if item.motorized == false and not moving then
			stopWork(tool)
			continue
		end

		-- Soft tires slow you down, and so does cutting through grass; a dull blade cuts slower and
		-- rougher.
		local speed, quality = Maintenance.effects(condition)
		if item.walkSpeed and tool.Parent == character then
			local cutting = tool:GetAttribute("Cutting") == true
			local walkSpeed = item.walkSpeed
				* Maintenance.tireFactor(condition)
				* (if cutting then GameConfig.CuttingSlowdown else 1)
			if math.abs(humanoid.WalkSpeed - walkSpeed) > 0.1 then
				humanoid.WalkSpeed = walkSpeed
			end
		end

		-- While it tows, a ride-on's own deck is up: the attachment behind does the work.
		local towedId = tool:GetAttribute("Towing")
		local cut, hits = false, nil
		if not towedId then
			local front = root.Position + root.CFrame.LookVector * GameConfig.DeckOffset
			local options = {
				damagesHazards = Tools.damagesHazards(item),
				quiet = item.use == "Passive" and not moving,
				moving = moving,
				seconds = elapsed,
				qualityScale = quality,
				ragged = quality < RAGGED_BELOW,
				-- An engine-driven blade runs over junk in the grass instead of stopping at it.
				strikes = item.motorized == true,
			}
			if item.category == "Mower" then
				-- The deck sweeps from where it was last tick to where it is now, so nothing between
				-- the two is skipped however fast it goes. One that has barely moved stands where it
				-- was (and keeps standing until it has really gone somewhere).
				local previous = lastDeck[tool]
				local from, to = previous or front, front
				if previous and Vector2.new(front.X - previous.X, front.Z - previous.Z).Magnitude < STANDING_DECK then
					to = previous
				else
					lastDeck[tool] = front
				end
				cut, hits = sweep(player, atJob, from.X, from.Z, to.X, to.Z, item.radius, itemId, options)
			else
				cut, hits = applyWork(player, atJob, front, item.radius, itemId, item.power * elapsed * speed, options)
			end
		end
		setCutting(tool, cut == true)
		local premium = data and data.premium
		local perks = Premium.perksFor(premium, itemId)
		Maintenance.wear(item, condition, elapsed, true, moving, cut == true, rng:NextNumber(), perks)
		strike(tool, condition, hits, perks)
		syncCondition(tool, condition)
		noteWarnings(player, tool, item, condition, data)

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
						ragged = towQuality < RAGGED_BELOW,
					})
				Maintenance.wear(
					towed,
					towedCondition,
					elapsed,
					false,
					true,
					towedCut == true,
					rng:NextNumber(),
					Premium.perksFor(premium, towedId)
				)
			end
		end
		setFx(tool, not isStalled(tool))
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
	Players.PlayerRemoving:Connect(function(player)
		withheld[player] = nil
		snips[player] = nil
	end)
	Net.event("Snip").OnServerEvent:Connect(snip)

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
