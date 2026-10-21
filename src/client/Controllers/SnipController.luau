-- Grass shears (docs/GAME_DESIGN.md, "Starting out"). They don't work while the button is held
-- like other hand tools: each click (or tap) is one snip at the grass you're aiming at, and
-- holding it down keeps snipping at the shears' own rhythm (`snip.interval` in Tools.luau). Phones
-- also get a Snip button to tap or hold. The client only says which way you're looking; the
-- server works out what's in reach there and what gets cut (see ToolService). The shears in your
-- hands jab forward with every snip (see ArmsController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Tools = require(Shared.Config.Tools)

local UI = require(script.Parent.Parent.UI)
local ArmsController = require(script.Parent.ArmsController)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

local SnipController = {}

-- The shears in your hands (their Tools.luau entry), while you're holding a pair.
local heldItem = nil
-- Held down: the mouse (or a tap on the world) through the tool, or the Snip button on a phone.
local toolDown = false
local buttonDown = false
local nextSnip = 0
local connections: { RBXScriptConnection } = {}
local button: TextButton

local function release()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	heldItem = nil
	toolDown = false
end

-- Not while a menu's open, or out of first person (the drive cutscene).
local function canSnip(): boolean
	return CameraController.isFirstPerson() and not UI.needsCursor() and UI.getScreen().Enabled
end

local function snip()
	local camera = workspace.CurrentCamera
	if not (heldItem and camera and canSnip()) then
		return
	end
	nextSnip = os.clock() + heldItem.snip.interval
	Net.event("Snip"):FireServer(camera.CFrame.LookVector)
	ArmsController.snip()
end

-- A tool came into your hands: shears get their clicks turned into snips.
local function watch(tool: Tool)
	local itemId = tool:GetAttribute("ItemId")
	local item = if typeof(itemId) == "string" then Tools.get(itemId) else nil
	if not (item and item.snip) then
		return
	end
	release()
	heldItem = item
	table.insert(
		connections,
		tool.Activated:Connect(function()
			toolDown = true
			if os.clock() >= nextSnip then
				snip()
			end
		end)
	)
	table.insert(
		connections,
		tool.Deactivated:Connect(function()
			toolDown = false
		end)
	)
	table.insert(
		connections,
		tool.AncestryChanged:Connect(function()
			if tool.Parent ~= player.Character then
				release()
			end
		end)
	)
end

local function onCharacter(character: Model)
	release()
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			watch(child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			watch(child)
		end
	end
end

function SnipController:Start()
	button = UI.button("Snip", function() end, {
		Name = "Snip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -146, 0.55, 0),
		Size = UDim2.fromOffset(96, 96),
		TextSize = 22,
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.corner(48).Parent = button
	-- Held down for a steady snip, snip, snip, until that touch ends wherever the finger slid to.
	button.InputBegan:Connect(function(input)
		local pressing = input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		if not pressing or buttonDown then
			return
		end
		buttonDown = true
		if os.clock() >= nextSnip then
			snip()
		end
		local connection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				buttonDown = false
			end
		end)
	end)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	RunService.Heartbeat:Connect(function()
		local show = heldItem ~= nil and UserInputService.TouchEnabled and canSnip()
		if button.Visible ~= show then
			button.Visible = show
			buttonDown = false
		end
		if heldItem and (toolDown or buttonDown) and os.clock() >= nextSnip then
			snip()
		end
	end)
end

return SnipController
