-- Carrying tools by hand at your business.
--
-- Your own tools are laid out in front of your crew's tool rack (only on your screen, so crew
-- members each see their own). Walk up and pick one up, carry it to the truck and load it.
-- This also hides truck prompts that don't apply to you right now.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local SLOT_SPACING = 2.8

local CarryController = {}

local shownRack: BasePart? = nil
local rackFolder: Folder? = nil
local carryLabel: TextLabel

local function carrying(): string?
	return player:GetAttribute("Carrying")
end

local function findRack(): BasePart?
	local party = ClientState.party
	local leaderId = if party then party.leader.UserId else player.UserId
	local businesses = workspace:FindFirstChild("Businesses")
	for _, business in if businesses then businesses:GetChildren() else {} do
		if business:GetAttribute("OwnerUserId") == leaderId then
			local rack = business:FindFirstChild("ToolRack")
			return if rack and rack:IsA("BasePart") then rack else nil
		end
	end
	return nil
end

local function addPrompt(parent: BasePart, actionText: string, objectText: string, action: string, category: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LocalAction", action)
	prompt:SetAttribute("Category", category)
	prompt.Parent = parent
end

-- Rebuilds the tools in front of the rack: anything you own that isn't in the truck or your hands.
local function renderRack()
	if rackFolder then
		rackFolder:Destroy()
		rackFolder = nil
	end
	local rack = findRack()
	shownRack = rack
	local profile = ClientState.profile
	if not rack or not profile then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "MyToolRack"
	local held = carrying()
	local count = #Items.ToolCategories
	for index, category in Items.ToolCategories do
		local itemId = profile.equipped[category]
		if not itemId then
			continue
		end
		local x = (index - (count + 1) / 2) * SLOT_SPACING
		local ground = rack.CFrame * CFrame.new(x, -rack.Size.Y / 2, -1.8)
		-- An invisible marker holds the prompt, so "Put Back" shows up in the empty spot.
		local marker = Instance.new("Part")
		marker.Anchored = true
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Size = Vector3.new(1.5, 3, 1.5)
		marker.CFrame = ground * CFrame.new(0, 1.5, 0)
		marker.Parent = folder

		local name = Items.CategoryInfo[category].toolName
		if held == category then
			addPrompt(marker, "Put Back", name, "PutBack", category)
		elseif not profile.loadout[category] then
			local display = Assets.toolDisplay(category, itemId)
			Assets.anchor(display)
			Assets.placeOnGround(display, ground)
			display.Parent = folder
			addPrompt(marker, "Pick Up", name, "PickUp", category)
		end
	end
	folder.Parent = workspace
	rackFolder = folder
end

-- Server prompts: only show "Take Out" on your own tools, "Load Tool" while carrying,
-- and "Drive" while your hands are free.
local function filterPrompt(prompt: ProximityPrompt)
	local onlyFor = prompt:GetAttribute("OnlyFor")
	local action = prompt:GetAttribute("Action")
	local held = carrying() ~= nil
	if onlyFor ~= nil then
		prompt.Enabled = onlyFor == player.UserId and not held
	elseif action == "LoadTool" then
		prompt.Enabled = held
	elseif action == "DriveToJob" then
		prompt.Enabled = not held
	end
end

local function filterAllPrompts()
	local businesses = workspace:FindFirstChild("Businesses")
	for _, descendant in if businesses then businesses:GetDescendants() else {} do
		if descendant:IsA("ProximityPrompt") then
			filterPrompt(descendant)
		end
	end
end

local function updateCarryLabel()
	local held = carrying()
	carryLabel.Visible = held ~= nil
	if held then
		carryLabel.Text =
			`Carrying your {Items.CategoryInfo[held].toolName}. Load it into the truck or put it back on the rack.`
	end
end

function CarryController:Start()
	carryLabel = UI.label("", {
		Name = "CarryHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(460, 34),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = UI.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = 16,
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.corner(8).Parent = carryLabel

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("LocalAction")
		if action == "PickUp" then
			local _, message = Net.func("PickUpTool"):InvokeServer(prompt:GetAttribute("Category"))
			UI.notify(message)
		elseif action == "PutBack" then
			local _, message = Net.func("PutBackTool"):InvokeServer()
			UI.notify(message)
		end
	end)

	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		updateCarryLabel()
		filterAllPrompts()
		renderRack()
	end)
	ClientState.Changed:Connect(function(key)
		if key == "profile" or key == "party" then
			renderRack()
		end
	end)
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			filterPrompt(descendant)
		end
	end)
	filterAllPrompts()

	-- The rack can appear later (streaming in, or the business getting rebuilt after an upgrade).
	task.spawn(function()
		while true do
			task.wait(1)
			if findRack() ~= shownRack then
				renderRack()
			end
		end
	end)
end

return CarryController
