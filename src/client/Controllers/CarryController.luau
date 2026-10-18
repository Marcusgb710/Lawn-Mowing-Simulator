-- Carrying tools by hand at your business.
--
-- Your own tools are laid out in your crew's business storage (only on your screen, so crew
-- members each see their own): hand tools hang on pegboards, long tools stand in wall racks,
-- power tools hang on hooks, supplies sit on shelves and machines park on floor spots and in
-- equipment bays (see BusinessStorage on the server). Anything without a free spot sits on the
-- ground nearby. Walk up and pick one up, carry it to the truck and load it.
-- This also hides truck prompts that don't apply to you right now.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Storage = require(Shared.Config.Storage)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

-- Tools without a storage spot go in rows on the ground this wide.
local OVERFLOW_ROW_LENGTH = 18
local OVERFLOW_ROW_GAP = 4

local CarryController = {}

local shownStorage: Instance? = nil
local storageFolder: Folder? = nil
local carryLabel: TextLabel

local function carrying(): string?
	return player:GetAttribute("Carrying")
end

-- The Storage folder at your crew leader's business.
function CarryController.findStorage(): Folder?
	local party = ClientState.party
	local leaderId = if party then party.leader.UserId else player.UserId
	local businesses = workspace:FindFirstChild("Businesses")
	for _, business in if businesses then businesses:GetChildren() else {} do
		if business:GetAttribute("OwnerUserId") == leaderId then
			local storage = business:FindFirstChild("Storage")
			return if storage and storage:IsA("Folder") then storage else nil
		end
	end
	return nil
end

local function addPrompt(parent: BasePart, actionText: string, objectText: string, action: string, toolId: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LocalAction", action)
	prompt:SetAttribute("ToolId", toolId)
	prompt.Parent = parent
end

-- Every storage spot, by kind, in order.
local function spotsByKind(storage: Folder)
	local byKind = {}
	local holder = storage:FindFirstChild("Spots")
	for _, attachment in if holder then holder:GetChildren() else {} do
		local kind = attachment:GetAttribute("Spot")
		if attachment:IsA("Attachment") and kind then
			byKind[kind] = byKind[kind] or {}
			table.insert(byKind[kind], attachment)
		end
	end
	for _, list in byKind do
		table.sort(list, function(a, b)
			return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
		end)
	end
	return byKind
end

-- Puts a tool in its spot: hung on a pegboard or hook, stood up in a wall rack, or placed on a
-- shelf or the floor.
local function placeInSpot(display: Model, spot: Attachment, floorY: number)
	local frame = spot.WorldCFrame
	local mount = spot:GetAttribute("Mount")
	if mount == "Place" then
		Assets.placeOnGround(display, frame)
		return
	end
	-- On the wall: longest side straight up. A tool hung on a pegboard lies flat against it;
	-- in a rack or on a hook it hangs edge-on, so the tools next to it have room.
	local flat = mount == "Hang"
	local long, middle, thin =
		Assets.align(display, frame.Position, frame.UpVector, if flat then frame.LookVector else frame.RightVector)
	local sticksOut = if flat then thin else middle
	local depth = spot:GetAttribute("Depth") or 0
	-- Keep it clear of the wall, and never below the floor.
	local out = math.max(depth, sticksOut / 2 + 0.05) - depth
	local y = if mount == "Stand" then floorY + long / 2 else frame.Position.Y - long / 2
	y = math.max(y, floorY + long / 2)
	local center = Vector3.new(frame.Position.X, y, frame.Position.Z) + frame.LookVector * out
	display:PivotTo(display:GetPivot() + (center - frame.Position))
end

-- An invisible part to hold a tool's prompt, so "Put Back" shows up in the empty spot.
local function marker(folder: Folder, at: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(1.5, 2, 1.5)
	part.CFrame = CFrame.new(at)
	part.Parent = folder
	return part
end

-- Rebuilds your tools in storage: everything you own that isn't in the truck or your hands.
local function renderStorage()
	if storageFolder then
		storageFolder:Destroy()
		storageFolder = nil
	end
	local storage = CarryController.findStorage()
	shownStorage = storage
	local profile = ClientState.profile
	if not storage or not profile then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "MyStorage"
	local floorY = storage:GetAttribute("FloorY") or 0
	local spots = spotsByKind(storage)
	local taken = {}
	local overflowAttachment = storage:FindFirstChild("Overflow", true)
	local overflowFrame = if overflowAttachment and overflowAttachment:IsA("Attachment")
		then overflowAttachment.WorldCFrame
		else nil
	local overflowX, overflowRow = 0, 0
	local held = carrying()

	for _, item in Items.ownedTools(profile.owned) do
		-- Find this tool's spot: the first free one of its kind that takes it.
		local spot: Attachment? = nil
		for _, candidate in spots[Storage.spotOf(item)] or {} do
			if
				not taken[candidate] and not (candidate:GetAttribute("ManualOnly") and item.sizeClass == "FloorEngine")
			then
				spot = candidate
				taken[candidate] = true
				break
			end
		end
		if profile.loadout[item.id] then
			continue
		end

		local display = Assets.toolDisplay(item.category, item.id)
		Assets.anchor(display)
		if spot then
			placeInSpot(display, spot, floorY)
		elseif overflowFrame then
			-- No spot for it here: keep it on the ground, in rows.
			local _, size = display:GetBoundingBox()
			local width = math.max(size.X, size.Z)
			if overflowX > 0 and overflowX + width > OVERFLOW_ROW_LENGTH then
				overflowX, overflowRow = 0, overflowRow + 1
			end
			Assets.placeOnGround(
				display,
				overflowFrame * CFrame.new(overflowX + width / 2, 0, -overflowRow * OVERFLOW_ROW_GAP)
			)
			overflowX += width + 0.6
		else
			display:Destroy()
			continue
		end

		local center = display:GetBoundingBox().Position
		if held == item.id then
			display:Destroy()
			addPrompt(marker(folder, center), "Put Back", item.name, "PutBack", item.id)
		else
			display.Parent = folder
			addPrompt(marker(folder, center), "Pick Up", item.name, "PickUp", item.id)
		end
	end
	folder.Parent = workspace
	storageFolder = folder
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
	local tool = held and Tools.get(held)
	carryLabel.Visible = tool ~= nil
	if tool then
		carryLabel.Text = `Carrying your {tool.name}. Load it into the truck or put it back.`
	end
end

function CarryController.pickUp(toolId: string)
	local _, message = Net.func("PickUpTool"):InvokeServer(toolId)
	UI.notify(message)
end

function CarryController.putBack()
	local _, message = Net.func("PutBackTool"):InvokeServer()
	UI.notify(message)
end

function CarryController:Start()
	carryLabel = UI.label("", {
		Name = "CarryHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.new(0.9, 0, 0, 34),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = UI.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = 16,
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.corner(8).Parent = carryLabel
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge), Parent = carryLabel })

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("LocalAction")
		if action == "PickUp" then
			CarryController.pickUp(prompt:GetAttribute("ToolId"))
		elseif action == "PutBack" then
			CarryController.putBack()
		end
	end)

	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		updateCarryLabel()
		filterAllPrompts()
		renderStorage()
	end)
	ClientState.Changed:Connect(function(key)
		if key == "profile" or key == "party" then
			renderStorage()
		end
	end)
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			filterPrompt(descendant)
		end
	end)
	filterAllPrompts()

	-- Storage can appear later (streaming in, or the business getting rebuilt after an upgrade).
	task.spawn(function()
		while true do
			task.wait(1)
			if CarryController.findStorage() ~= shownStorage then
				renderStorage()
			end
		end
	end)
end

return CarryController
