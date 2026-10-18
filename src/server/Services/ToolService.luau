-- Hands out the tools loaded in the truck once the crew reaches the job site, and does the yard
-- work while players use them. At the business your hands are free for carrying tools around.
--
-- Mowers work the whole time they're equipped (the reel mower only while you're walking).
-- Every other tool works while you hold down the mouse button / tap and hold.
-- Riding mowers aren't held at all: they're welded under the player, who sits on them and
-- drives them around like walking. Tools say whether they're working with a "Working"
-- attribute, so ToolFxController can spin blades and spools.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)

-- How far in front of the player a tool does its work.
local REACH_OFFSET = 2

-- Particle color by what the tool does (its first verb).
local FX_COLORS = {
	Mow = Color3.fromRGB(110, 190, 70),
	Trim = Color3.fromRGB(150, 170, 50),
	Edge = Color3.fromRGB(110, 80, 50),
	Rake = Color3.fromRGB(210, 120, 40),
	Blow = Color3.fromRGB(210, 120, 40),
	Shear = Color3.fromRGB(60, 130, 50),
}
local DEFAULT_FX_COLOR = Color3.fromRGB(120, 90, 60)

local ToolService = {}

-- [Tool] = true while the tool is running
local running = {}

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

local function clearTools(player: Player): string?
	local equippedCategory = nil
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in container and container:GetChildren() or {} do
			if child:IsA("Tool") and child:GetAttribute("Category") then
				if child.Parent == player.Character then
					equippedCategory = child:GetAttribute("Category")
				end
				child:Destroy()
			end
		end
	end
	return equippedCategory
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

	for _, category in Items.ToolCategories do
		local itemId = data.equipped[category]
		if not (itemId and data.loadout[category]) then
			continue
		end
		local item = Tools.get(itemId)
		local tool = Assets.tool(category, itemId)
		tool.Name = item.name
		tool.ToolTip = Items.CategoryInfo[category].displayName
		tool.CanBeDropped = false
		tool:SetAttribute("Category", category)
		tool:SetAttribute("ItemId", itemId)
		if item.ride then
			setUpRide(player, tool, item)
		end
		addFx(tool, item.verbs[1])
		hookTool(player, tool, item)
		tool.Parent = backpack

		-- Swapping gear shouldn't make you put your tool away.
		if category == wasHolding and humanoid then
			humanoid:EquipTool(tool)
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
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		if item.motorized == false and not moving then
			setFx(tool, false)
			continue
		end

		local position = root.Position + root.CFrame.LookVector * REACH_OFFSET
		local idling = item.use == "Passive" and not moving
		JobService:ApplyWork(
			player,
			position,
			item.radius,
			itemId,
			item.power * elapsed,
			Tools.damagesHazards(item),
			idling
		)
		setFx(tool, true)
	end
end

function ToolService:Start()
	JobService.PlayerStateChanged:Connect(function(player)
		self:GiveTools(player)
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
