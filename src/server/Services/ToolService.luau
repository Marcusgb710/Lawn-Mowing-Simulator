-- Gives each player the tools loaded in their truck bed and does the yard work while they use them.
--
-- Mowers work the whole time they're equipped (the reel mower only while you're walking).
-- Every other tool works while you hold down the mouse button / tap and hold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)

-- How far in front of the player a tool does its work.
local REACH_OFFSET = 2

local FX_COLORS = {
	Mow = Color3.fromRGB(110, 190, 70),
	Edge = Color3.fromRGB(110, 80, 50),
	Weeds = Color3.fromRGB(150, 170, 50),
	Leaves = Color3.fromRGB(210, 120, 40),
	Hedge = Color3.fromRGB(60, 130, 50),
}

local ToolService = {}

-- [Tool] = true while the tool is running
local running = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setFx(tool: Tool, enabled: boolean)
	local handle = tool:FindFirstChild("Handle")
	local emitter = handle and handle:FindFirstChild("WorkFx")
	if emitter and emitter:IsA("ParticleEmitter") and emitter.Enabled ~= enabled then
		emitter.Enabled = enabled
	end
end

local function addFx(tool: Tool, taskName: string)
	local handle = tool:FindFirstChild("Handle")
	if not handle or handle:FindFirstChild("WorkFx") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WorkFx"
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(FX_COLORS[taskName])
	emitter.Size = NumberSequence.new(0.25)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 40
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Parent = handle
end

local function hookTool(player: Player, tool: Tool, category: string, item)
	local isMower = category == "Mower"

	tool.Equipped:Connect(function()
		local humanoid = getHumanoid(player)
		if humanoid and item.walkSpeed then
			humanoid.WalkSpeed = item.walkSpeed
		end
		if isMower then
			running[tool] = true
		end
	end)

	tool.Unequipped:Connect(function()
		running[tool] = nil
		setFx(tool, false)
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		end
	end)

	if not isMower then
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

-- Replaces the player's tools with what's loaded in their truck bed. Call after buying/equipping/loading.
function ToolService:GiveTools(player: Player)
	local data = DataService:Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end

	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
	end
	local wasHolding = clearTools(player)

	for _, category in Items.ToolCategories do
		local itemId = data.equipped[category]
		if not (itemId and data.loadout[category]) then
			continue
		end
		local item = Items.get(category, itemId)
		local tool = Assets.tool(category, itemId)
		tool.Name = item.name
		tool.ToolTip = Items.CategoryInfo[category].displayName
		tool.CanBeDropped = false
		tool:SetAttribute("Category", category)
		tool:SetAttribute("ItemId", itemId)
		addFx(tool, Items.CategoryInfo[category].task)
		hookTool(player, tool, category, item)
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

		local category = tool:GetAttribute("Category")
		local item = Items.get(category, tool:GetAttribute("ItemId"))
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		if item.motorized == false and not moving then
			setFx(tool, false)
			continue
		end

		local position = root.Position + root.CFrame.LookVector * REACH_OFFSET
		local info = Items.CategoryInfo[category]
		JobService:ApplyWork(
			player,
			position,
			item.radius,
			info.task,
			item.power * elapsed,
			info.damagesHazards == true
		)
		setFx(tool, true)
	end
end

function ToolService:Start()
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
