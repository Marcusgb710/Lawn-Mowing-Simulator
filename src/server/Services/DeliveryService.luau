-- Orders arriving at the shop (docs/GAME_DESIGN.md, "The shop as the hub"). Anything bought on
-- the shop computer is yours straight away, but tools and supplies come in a box. It turns up at
-- your crew's business (its DeliverySpot, just inside the door) GameConfig.DeliveryTime seconds
-- later, or at once if you were away on a job. Look at your box and open it: the flaps swing
-- open, the tool shows inside, then it comes up into your hands and the empty box goes away.
-- Until then it's still in its box, not in storage. Unopened boxes are saved (data.deliveries)
-- and turn up again when you rejoin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Deliveries = require(Shared.Deliveries)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local TruckService = require(script.Parent.TruckService)
local WorldService = require(script.Parent.WorldService)

-- How close to a box you need to be to open it.
local OPEN_REACH = 8
-- Flaps take this long to swing open, then the tool shows in the box for a moment before it's in
-- your hands, and the empty box goes away a little after.
local OPEN_TIME = 0.5
local SHOW_TIME = 0.6
local GONE_TIME = 1.5
-- How far the flaps, lids and crate panels swing open.
local SWING = { Flap = math.rad(120), Lid = math.rad(105), FrontPanel = math.rad(95) }
-- Boxes stand in rows across the delivery spot, this wide, with this gap between them.
local ROW_WIDTH = 9
local GAP = 0.6
-- How often to look for boxes that have arrived.
local CHECK_EVERY = 1

local DeliveryService = {}

-- [Player] = { [key] = Model }: their boxes standing at the shop
local boxes = {}
-- [Player] = true while one of their boxes is opening
local opening = {}

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function folderFor(player: Player): Folder?
	local business = WorldService:GetCrewBusiness(player)
	if not business then
		return nil
	end
	local folder = business:FindFirstChild("Deliveries")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Deliveries"
		folder.Parent = business
	end
	return folder :: Folder
end

local function clear(player: Player)
	local shown = boxes[player]
	if shown then
		for _, model in shown do
			model:Destroy()
		end
	end
	boxes[player] = {}
end

-- Shows every box of theirs that has arrived, in rows at their crew's delivery spot.
local function render(player: Player)
	clear(player)
	local data = DataService:Get(player)
	local frame = WorldService:GetDeliveryFrame(player)
	local folder = folderFor(player)
	if not (data and frame and folder) then
		return
	end
	local now = os.time()
	local x, z, rowDepth = 0, 0, 0
	for _, delivery in data.deliveries do
		local tool = Tools.get(delivery.id)
		local item = tool and Items.get(tool.category, delivery.id)
		if not item or delivery.arrives > now then
			continue
		end
		local model = Assets.prop(Deliveries.boxFor(item.sizeClass))
		Assets.anchor(model)
		local _, size = model:GetBoundingBox()
		if x > 0 and x + size.X > ROW_WIDTH then
			x, z, rowDepth = 0, z + rowDepth + GAP, 0
		end
		Assets.placeAt(model, frame * CFrame.new(x + size.X / 2 - ROW_WIDTH / 2, 0, -z - size.Z / 2))
		x += size.X + GAP
		rowDepth = math.max(rowDepth, size.Z)
		model.Name = "Box_" .. player.UserId .. "_" .. delivery.key
		model:SetAttribute("Interact", "OpenBox")
		model:SetAttribute("InteractText", "Open")
		model:SetAttribute("InteractName", `Delivery: {item.name}`)
		model:SetAttribute("OnlyFor", player.UserId)
		model:SetAttribute("BoxKey", delivery.key)
		model.Parent = folder
		boxes[player][delivery.key] = model
	end
end

-- Swings a box's flaps, lid and crate front open about their hinges (each part's pivot).
local function swingOpen(model: Model)
	local center = model:GetBoundingBox().Position
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local suffix = string.match(part.Name, "__(%a+)$")
		local kind = if suffix and string.sub(suffix, 1, 4) == "Flap" then "Flap" else suffix
		local angle = kind and SWING[kind]
		if not angle then
			continue
		end
		local pivot = part:GetPivot()
		local hinge = pivot.Position
		local away = part.Position - hinge
		local axis
		if kind == "FrontPanel" then
			-- It drops forward, away from the box, into a ramp.
			local out = hinge - center
			axis = away:Cross(Vector3.new(out.X, 0, out.Z))
		else
			-- Up and over the hinge.
			axis = Vector3.new(away.X, 0, away.Z):Cross(Vector3.yAxis)
		end
		if axis.Magnitude < 1e-3 then
			continue
		end
		axis = axis.Unit
		local value = Instance.new("NumberValue")
		local connection = value.Changed:Connect(function(amount)
			if part.Parent then
				part:PivotTo(
					CFrame.new(hinge) * CFrame.fromAxisAngle(axis, angle * amount) * CFrame.new(-hinge) * pivot
				)
			end
		end)
		local tween = TweenService:Create(value, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Back), { Value = 1 })
		tween.Completed:Once(function()
			connection:Disconnect()
			value:Destroy()
		end)
		tween:Play()
	end
end

-- Public API ---------------------------------------------------------------------------------

-- Sends what the player just bought to their shop.
function DeliveryService:Order(player: Player, itemId: string)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local delay = if JobService:IsBusy(player) then 0 else GameConfig.DeliveryTime
	table.insert(data.deliveries, {
		key = Deliveries.nextKey(data.deliveries),
		id = itemId,
		arrives = os.time() + delay,
	})
	DataService:Changed(player)
	if delay <= 0 then
		render(player)
	end
end

-- Opens one of the player's boxes, and puts what's in it into their hands.
function DeliveryService:Open(player: Player, key: number): (boolean, string)
	local data = DataService:Get(player)
	local model = boxes[player] and boxes[player][key]
	if not (data and model) then
		return false, "That's not your box."
	end
	local index, delivery
	for position, entry in data.deliveries do
		if entry.key == key then
			index, delivery = position, entry
			break
		end
	end
	if not delivery then
		return false, "That's not your box."
	end
	if opening[player] then
		return false, "One box at a time."
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end
	if TruckService:IsCarryingAnything(player) then
		return false, "Your hands are full."
	end
	if not WorldService:IsNear(player, model, OPEN_REACH) then
		return false, "Get closer to the box."
	end
	local tool = Tools.get(delivery.id)
	if not tool then
		return false, "That box is empty."
	end

	-- It's unpacked now: from here on it's a tool like any other.
	table.remove(data.deliveries, index)
	boxes[player][key] = nil
	opening[player] = true
	model:SetAttribute("Interact", nil)
	swingOpen(model)
	local soundAt = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if soundAt then
		Sounds.play(soundAt, "Pickup")
	end

	local contents = model:FindFirstChild("Contents", true)
	local shown = Assets.toolDisplay(tool.category, tool.id)
	Assets.anchor(shown)
	Assets.placeOnGround(
		shown,
		if contents and contents:IsA("Attachment") then contents.WorldCFrame else model:GetPivot()
	)
	shown.Parent = model

	task.delay(OPEN_TIME + SHOW_TIME, function()
		shown:Destroy()
		opening[player] = nil
		if player.Parent == Players then
			if not (JobService:IsBusy(player) or TruckService:Hand(player, tool.id)) then
				notify(player, `The {tool.name} is in your storage.`)
			end
			DataService:Changed(player)
			TruckService:GearChanged(player)
		end
		task.delay(GONE_TIME, function()
			model:Destroy()
		end)
	end)
	return true, `Unboxed your {tool.name}!`
end

-- Call after a player sold something or their crew changed: shows their boxes again.
function DeliveryService:Refresh(player: Player)
	render(player)
end

-- Lifecycle ----------------------------------------------------------------------------------

function DeliveryService:Init()
	Net.func("OpenBox").OnServerInvoke = function(player, key)
		if typeof(key) ~= "number" then
			return false, "That's not your box."
		end
		return self:Open(player, key)
	end
end

function DeliveryService:Start()
	-- Boxes go wherever the crew hangs out, and come back when a plot is rebuilt.
	PartyService.Changed:Connect(function(party)
		for _, member in party.members do
			render(member)
		end
	end)
	WorldService.PlotBuilt:Connect(function()
		for _, player in Players:GetPlayers() do
			render(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		boxes[player] = nil
		opening[player] = nil
	end)

	-- Boxes that have arrived but aren't standing at the shop yet (just delivered, or the player
	-- just joined).
	while true do
		task.wait(CHECK_EVERY)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local data = DataService:Get(player)
			if not data or opening[player] then
				continue
			end
			for _, delivery in data.deliveries do
				local shown = boxes[player] and boxes[player][delivery.key]
				if delivery.arrives <= now and not (shown and shown.Parent) then
					render(player)
					break
				end
			end
		end
	end
end

return DeliveryService
