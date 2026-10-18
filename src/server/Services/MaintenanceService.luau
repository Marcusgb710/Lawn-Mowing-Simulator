-- Working on tools by hand (docs/GAME_DESIGN.md, "Immersion", "Hands-on maintenance"). What each
-- supply does is in Maintenance.luau, and the steps around it in Service.luau.
--
-- Set a machine down on a service spot (look at the spot while holding it), or a hand or long
-- tool in the vise. Every workbench has both, and on a job so does the truck: behind it on the
-- ground, and on its open tailgate. Then hold a supply and look at the tool, and hold E (or the
-- button) to pour, pump, plug, wind, file or unbolt. It takes the supply's time; let go or walk
-- off and it stops. A mower's blade comes off with the wrench before it's sharpened or swapped,
-- then goes back on, and a wheel comes off for the spare. The building's own air compressor and
-- bench grinder are used with empty hands (R). Supplies come off your storage shelves at the
-- business; on a job, the ones you brought stand by the tailgate.
--
-- Using the wrong supply does what it would really do: regular gas in a two-stroke wrecks it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Service = require(Shared.Service)
local Sounds = require(Shared.Sounds)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local ServiceSpots = require(script.Parent.Parent.ServiceSpots)
local ToolService = require(script.Parent.ToolService)
local TruckService = require(script.Parent.TruckService)
local WorldService = require(script.Parent.WorldService)

-- How close to a service spot, or the tool on it, you need to be.
local REACH = 10
-- How far you can wander while working before the job is spoiled.
local STAY_RADIUS = 6
-- Seconds between requests from one player.
local COOLDOWN = 0.2
-- What shows on the tool while it's being worked on, by step.
local EFFECTS = {
	Sharpen = { color = Color3.fromRGB(255, 200, 90), speed = 12, light = true },
	Fuel = { color = Color3.fromRGB(200, 170, 90), speed = 2 },
	Reload = { color = Color3.fromRGB(240, 120, 40), speed = 1 },
}

local MaintenanceService = {}

-- [spot pad] = { owner, toolId, item, model, spot = "Floor" | "Vise", field = boolean,
--   state = { bladeOff?, wheelOff? }, fixtures = { [id] = true } } for each tool set down
local serviced = {}
-- [Player] = the spot pad their tool is on
local spotOf = {}
-- [Player] = { token, position, effect } while they're working on it
local working = {}
-- [Player] = { [supplyId] = Model } standing by the tailgate on a job
local tailgate = {}
-- [Player] = the supply they took off the tailgate
local takenOff = {}
-- [Player] = os.clock() of their last request
local lastRequest = {}
local folder: Folder

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function within(player: Player, position: Vector3, reach: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= reach
end

local function ownedTool(data, toolId)
	local tool = typeof(toolId) == "string" and Tools.get(toolId)
	local item = tool and Items.get(tool.category, toolId)
	return if item and data.owned[item.category] and data.owned[item.category][toolId] then item else nil
end

-- What the player has with them where they are, for supplies that need another one
-- (Maintenance.apply): everything they own at the business (and its machines), or what they
-- brought on a job. Nil if they're at neither.
local function suppliesHere(player: Player, data, field: boolean): { [string]: boolean }?
	local supplies = {}
	if field then
		for id in data.loadout do
			if Maintenance.Supplies[id] and not Maintenance.isStationary(id) then
				supplies[id] = true
			end
		end
		return supplies
	end
	local businessId = WorldService:GetWorkbenchBusiness(player)
	if not businessId then
		return nil
	end
	for _, item in Items.ownedTools(data.owned) do
		if Maintenance.Supplies[item.id] then
			supplies[item.id] = true
		end
	end
	local business = Items.get("Business", businessId)
	for _, fixture in business and business.fixtures or {} do
		supplies[fixture] = true
	end
	return supplies
end

local function usesLeft(data, supplyId: string): number?
	local supply = Maintenance.Supplies[supplyId]
	if not supply or not supply.uses then
		return nil
	end
	local condition = data.condition[supplyId]
	return if condition then condition.uses or 0 else 0
end

-- Which spot pad this is, and whether the player may use it: one at their crew's workbench, or
-- at their job's truck.
local function checkSpot(player: Player, pad: Instance): (boolean, boolean)
	if not (pad:IsA("BasePart") and pad:GetAttribute("Interact") == "SetDown") then
		return false, false
	end
	local business = WorldService:GetCrewBusiness(player)
	if business and pad:IsDescendantOf(business) then
		return true, false
	end
	local job = JobService:GetJob(player)
	if JobService:IsAtJobSite(player) and job and job.lawn and pad:IsDescendantOf(job.lawn.folder) then
		return true, true
	end
	return false, false
end

local function stopWork(player: Player)
	local current = working[player]
	working[player] = nil
	if current and current.effect then
		current.effect:Destroy()
	end
	if player.Parent == Players then
		player:SetAttribute("MaintainingUntil", nil)
	end
end

-- Shows a tool on its spot the way it is: tipped on its side with the blade off, a wheel missing.
local function pose(entry)
	local frame: CFrame = entry.pad:GetAttribute("SpotFrame")
	local model = entry.model
	if entry.spot == "Vise" then
		model:PivotTo(frame)
	elseif entry.state.bladeOff then
		Assets.placeOnGround(model, frame * CFrame.Angles(0, 0, math.rad(90)))
	else
		Assets.placeOnGround(model, frame)
	end
	local wheelHidden = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and Service.partKind(part.Name) == "Wheel" then
			-- One wheel comes off for the spare.
			local hide = entry.state.wheelOff and not wheelHidden
			wheelHidden = wheelHidden or hide
			part.Transparency = if hide then 1 else (part:GetAttribute("ShownTransparency") or part.Transparency)
			if part:GetAttribute("ShownTransparency") == nil then
				part:SetAttribute("ShownTransparency", part.Transparency)
			end
		end
	end
	model:SetAttribute("BladeOff", entry.state.bladeOff == true)
	model:SetAttribute("WheelOff", entry.state.wheelOff == true)
end

-- Takes a tool off its spot: back in storage at the business, back in the hotbar on a job.
local function clearSpot(player: Player, giveBack: boolean)
	local pad = spotOf[player]
	local entry = pad and serviced[pad]
	spotOf[player] = nil
	if not entry then
		return
	end
	serviced[pad] = nil
	stopWork(player)
	entry.model:Destroy()
	if pad.Parent then
		pad:SetAttribute("Occupied", nil)
	end
	if player.Parent == Players then
		player:SetAttribute("Servicing", nil)
		if entry.field then
			ToolService:Withhold(player, entry.toolId, false)
			if not giveBack then
				-- Out of their hands again: it was only for picking it up.
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:UnequipTools()
				end
			end
		end
	end
end

local function clearTailgate(player: Player)
	if takenOff[player] then
		takenOff[player] = nil
		TruckService:Release(player)
	end
	for _, model in tailgate[player] or {} do
		model:Destroy()
	end
	tailgate[player] = nil
end

-- Stands the supplies a player brought by the truck's tailgate on a job.
local function layOutTailgate(player: Player)
	clearTailgate(player)
	local data = DataService:Get(player)
	local job = JobService:GetJob(player)
	local pad = job and job.lawn and job.lawn.folder:FindFirstChild("ServiceSpot", true)
	if not (data and pad and JobService:IsAtJobSite(player)) then
		return
	end
	local frame: CFrame = pad:GetAttribute("SpotFrame")
	-- Room for six each, crew member by crew member.
	local index = (table.find(job.members, player) or 1) * 6 - 5
	tailgate[player] = {}
	for _, id in Maintenance.SupplyOrder do
		if data.loadout[id] and not Maintenance.isStationary(id) then
			local tool = Tools.get(id)
			local model = Assets.toolDisplay(tool.category, id)
			Assets.anchor(model)
			Assets.placeOnGround(model, ServiceSpots.supplyRow(frame, index))
			index += 1
			model.Name = "Tailgate_" .. id
			model:SetAttribute("Interact", "TakeSupply")
			model:SetAttribute("InteractText", "Take")
			model:SetAttribute("InteractName", tool.name)
			model:SetAttribute("OnlyFor", player.UserId)
			model:SetAttribute("ToolId", id)
			model.Parent = folder
			tailgate[player][id] = model
		end
	end
end

-- Public API ---------------------------------------------------------------------------------

-- Sets down the tool the player is holding on a service spot (or in the vise).
function MaintenanceService:SetDown(player: Player, pad: Instance): (boolean, string)
	local allowed, field = checkSpot(player, pad)
	local data = DataService:Get(player)
	if not (allowed and data and pad:IsA("BasePart")) then
		return false, "You can't work on tools there."
	end
	if spotOf[player] then
		return false, "You're already working on something. Pick it up first."
	end
	if serviced[pad] then
		return false, "Someone's working there."
	end
	if not within(player, pad.Position, REACH) then
		return false, "Get closer."
	end

	-- What's in their hands: carried at the business, equipped on a job.
	local toolId
	if field then
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		toolId = tool and tool:GetAttribute("ItemId")
		if not (typeof(toolId) == "string" and data.loadout[toolId]) then
			return false, "Hold the tool you want to work on."
		end
	else
		toolId = player:GetAttribute("Carrying")
	end
	local item = data and ownedTool(data, toolId)
	if not item or Maintenance.Supplies[item.id] then
		return false, "Hold the tool you want to work on."
	end
	local spot = Service.spotFor(item)
	if spot ~= pad:GetAttribute("SpotKind") then
		return false, if spot == "Vise" then "That goes in the vise." else "That goes on the floor."
	end

	if field then
		ToolService:Withhold(player, item.id, true)
	else
		TruckService:Release(player)
	end
	local model = Assets.toolDisplay(item.category, item.id)
	Assets.anchor(model)
	model.Name = "Servicing_" .. player.UserId
	model:SetAttribute("Interact", "ServiceTool")
	model:SetAttribute("InteractText", "Pick up")
	model:SetAttribute("InteractName", item.name)
	model:SetAttribute("OnlyFor", player.UserId)
	model:SetAttribute("ToolId", item.id)
	model:SetAttribute("SpotKind", spot)
	-- The building's own machines, used with empty hands.
	local fixtures = {}
	if not field then
		local business = Items.get("Business", WorldService:GetWorkbenchBusiness(player) or "")
		for _, fixture in business and business.fixtures or {} do
			fixtures[fixture] = true
			model:SetAttribute("Has" .. fixture, true)
		end
	end
	local entry = {
		owner = player,
		toolId = item.id,
		item = item,
		model = model,
		pad = pad,
		spot = spot,
		field = field,
		state = {},
		fixtures = fixtures,
	}
	pose(entry)
	ToolService.showCondition(model, data.condition[item.id] or {})
	model.Parent = folder
	serviced[pad] = entry
	spotOf[player] = pad
	pad:SetAttribute("Occupied", true)
	player:SetAttribute("Servicing", item.id)
	local soundAt = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if soundAt then
		Sounds.play(soundAt, "Thunk")
	end
	return true, `Set down the {item.name}. Hold what you want to use on it and look at it.`
end

-- Picks the player's tool back up off its spot.
function MaintenanceService:PickUp(player: Player): (boolean, string)
	local pad = spotOf[player]
	local entry = pad and serviced[pad]
	if not entry then
		return false, "You haven't set anything down."
	end
	if working[player] then
		return false, "Finish what you're doing first."
	end
	local ready, reason = Service.canPickUp(entry.state)
	if not ready then
		return false, reason or "Not like that."
	end
	if player:GetAttribute("Carrying") ~= nil then
		return false, "Your hands are full."
	end
	if not within(player, entry.model:GetPivot().Position, REACH) then
		return false, "Get closer."
	end
	local toolId, field = entry.toolId, entry.field
	clearSpot(player, true)
	if not field and not TruckService:Hand(player, toolId) then
		return false, "You can't pick that up right now."
	end
	return true, `Picked up the {entry.item.name}.`
end

-- Starts working on the player's tool with what's in their hands, or with one of the building's
-- machines (`fixture`, empty-handed). `partName` is the part of it they're looking at.
function MaintenanceService:Work(player: Player, fixture: string?, partName: string?): (boolean, string)
	local pad = spotOf[player]
	local entry = pad and serviced[pad]
	local data = DataService:Get(player)
	if not (entry and data) then
		return false, "Set a tool down to work on it first."
	end
	if working[player] then
		return false, "You're already at it."
	end
	if not within(player, entry.model:GetPivot().Position, REACH) then
		return false, "Get closer."
	end
	local supplyId
	if fixture then
		if not entry.fixtures[fixture] or player:GetAttribute("Carrying") ~= nil then
			return false, "That won't help here."
		end
		supplyId = fixture
	else
		supplyId = player:GetAttribute("Carrying")
		if not (typeof(supplyId) == "string" and Maintenance.Supplies[supplyId]) then
			return false, "Hold what you want to use on it."
		end
	end
	local supplyTool = Tools.get(supplyId)
	local item, condition = entry.item, data.condition[entry.toolId] or {}
	local step, reason =
		Service.step(item, condition, supplyId, entry.state, entry.spot, Service.partKind(partName or ""))
	if not step then
		return false, reason or "That won't help here."
	end
	local supplies = suppliesHere(player, data, entry.field)
	if not supplies then
		return false, "Get back to the workbench."
	end
	if step.kind == "Apply" then
		local left = usesLeft(data, supplyId)
		if left and left <= 0 then
			return false, `The {supplyTool.name} is used up. Order more on the shop computer.`
		end
		-- Try it on a copy first, so nobody waits around just to hear it won't work.
		local preview = table.clone(condition)
		local ok, message, cost = Maintenance.apply(item, preview, supplyId, function(id)
			local need = usesLeft(data, id)
			return supplies[id] == true and (need == nil or need > 0)
		end)
		if not ok then
			return false, message
		end
		if cost > data.money then
			return false, `The parts cost {Format.money(cost)}.`
		end
	end

	local token = {}
	local root = rootOf(player)
	local look = EFFECTS[Maintenance.Supplies[supplyId].action]
	local effect = nil
	local anchor = entry.model.PrimaryPart or entry.model:FindFirstChildWhichIsA("BasePart", true)
	if look and anchor and step.kind == "Apply" then
		effect = Instance.new("ParticleEmitter")
		effect.Color = ColorSequence.new(look.color)
		effect.LightEmission = if look.light then 1 else 0
		effect.Size = NumberSequence.new(0.12, 0)
		effect.Lifetime = NumberRange.new(0.2, 0.5)
		effect.Rate = 40
		effect.Speed = NumberRange.new(look.speed * 0.5, look.speed)
		effect.SpreadAngle = Vector2.new(40, 40)
		effect.Parent = anchor
	end
	working[player] = { token = token, position = root and root.Position, effect = effect }
	player:SetAttribute("MaintainingUntil", workspace:GetServerTimeNow() + step.seconds)

	task.delay(step.seconds, function()
		local current = working[player]
		if not current or current.token ~= token then
			return
		end
		stopWork(player)
		local now = rootOf(player)
		local moved = if now and current.position then now.Position - current.position else nil
		-- Sideways only: hopping on the spot is fine.
		if not (moved and Vector2.new(moved.X, moved.Z).Magnitude <= STAY_RADIUS) then
			notify(player, "You walked off before you finished.")
			return
		end
		-- Things may have changed while they worked (a sale, a job ending, the supply put down).
		local fresh = DataService:Get(player)
		local stillHolding = fixture ~= nil or player:GetAttribute("Carrying") == supplyId
		if not (fresh and serviced[pad] == entry and stillHolding and ownedTool(fresh, entry.toolId)) then
			notify(player, "You couldn't finish the job.")
			return
		end
		local message = `Done: {string.lower(step.text)}.`
		if step.kind == "BladeOff" then
			entry.state.bladeOff = true
		elseif step.kind == "BladeOn" then
			entry.state.bladeOff = nil
		elseif step.kind == "WheelOff" then
			entry.state.wheelOff = true
		elseif step.kind == "WheelOn" then
			entry.state.wheelOff = nil
		else
			local real = fresh.condition[entry.toolId]
			local stillSupplies = suppliesHere(player, fresh, entry.field)
			local stillLeft = usesLeft(fresh, supplyId)
			if not (real and stillSupplies) or (stillLeft and stillLeft <= 0) then
				notify(player, "You couldn't finish the job.")
				return
			end
			-- Work on a copy, and only keep it once any parts are paid for.
			local worked = table.clone(real)
			local done, result, price = Maintenance.apply(item, worked, supplyId, function(id)
				local need = usesLeft(fresh, id)
				return stillSupplies[id] == true and (need == nil or need > 0)
			end)
			message = result
			if done then
				if price > 0 and not DataService:TrySpend(player, price) then
					notify(player, `The parts cost {Format.money(price)}.`)
					return
				end
				for key, value in worked do
					real[key] = value
				end
				local supplyCondition = fresh.condition[supplyId]
				if Maintenance.Supplies[supplyId].uses and supplyCondition and supplyCondition.uses then
					supplyCondition.uses = math.max(0, supplyCondition.uses - 1)
				end
				if Maintenance.Supplies[supplyId].action == "SwapTire" then
					entry.state.wheelOff = nil
				end
				if price > 0 then
					message ..= ` Parts: {Format.money(price)}.`
				end
			end
			ToolService.showCondition(entry.model, real)
		end
		pose(entry)
		notify(player, message)
		DataService:Changed(player)
		ToolService:RefreshCondition(player)
	end)
	return true, `{step.text}...`
end

-- Lets go of what they're doing.
function MaintenanceService:Stop(player: Player)
	if working[player] then
		stopWork(player)
	end
end

-- Takes one of the supplies standing by the tailgate on a job into the player's hands.
function MaintenanceService:TakeSupply(player: Player, supplyId: string): (boolean, string)
	local model = tailgate[player] and tailgate[player][supplyId]
	if not (model and model.Parent) then
		return false, "That's not yours."
	end
	if takenOff[player] or player:GetAttribute("Carrying") ~= nil then
		return false, "Your hands are full."
	end
	if not within(player, model:GetPivot().Position, REACH) then
		return false, "Get closer."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	if not TruckService:Carry(player, supplyId) then
		return false, "You can't take that right now."
	end
	takenOff[player] = supplyId
	model.Parent = nil
	return true, `Took the {Tools.get(supplyId).name}.`
end

-- Puts the supply they took off the tailgate back.
function MaintenanceService:PutBackSupply(player: Player): (boolean, string)
	local supplyId = takenOff[player]
	if not supplyId then
		return false, "You're not holding anything from the tailgate."
	end
	takenOff[player] = nil
	stopWork(player)
	TruckService:Release(player)
	local model = tailgate[player] and tailgate[player][supplyId]
	if model then
		model.Parent = folder
	end
	return true, "Put it back."
end

-- Lifecycle ----------------------------------------------------------------------------------

function MaintenanceService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Servicing"
	folder.Parent = workspace

	local function guarded(method)
		return function(player, ...)
			if tooSoon(player) then
				return false, nil
			end
			return method(self, player, ...)
		end
	end
	Net.func("SetDownTool").OnServerInvoke = guarded(function(_, player, pad)
		if typeof(pad) ~= "Instance" then
			return false, "You can't work on tools there."
		end
		return self:SetDown(player, pad)
	end)
	Net.func("PickUpServiced").OnServerInvoke = guarded(self.PickUp)
	Net.func("StartService").OnServerInvoke = guarded(function(_, player, fixture, partName)
		if fixture ~= nil and typeof(fixture) ~= "string" then
			return false, nil
		end
		return self:Work(player, fixture, if typeof(partName) == "string" then partName else nil)
	end)
	Net.event("StopService").OnServerEvent:Connect(function(player)
		self:Stop(player)
	end)
	Net.func("TakeSupply").OnServerInvoke = guarded(function(_, player, supplyId)
		if typeof(supplyId) ~= "string" then
			return false, "That's not yours."
		end
		return self:TakeSupply(player, supplyId)
	end)
	Net.func("PutBackSupply").OnServerInvoke = guarded(self.PutBackSupply)
end

function MaintenanceService:Start()
	-- Heading out on a job, arriving or coming back: what's set down goes back, and on a job the
	-- supplies you brought come out by the tailgate.
	JobService.PlayerStateChanged:Connect(function(player)
		clearSpot(player, false)
		if JobService:IsAtJobSite(player) then
			layOutTailgate(player)
		else
			clearTailgate(player)
		end
	end)
	-- A plot rebuilt (a new building or truck) takes its workbench with it.
	WorldService.PlotBuilt:Connect(function()
		for pad, entry in serviced do
			if not pad.Parent then
				clearSpot(entry.owner, false)
			end
		end
	end)
	-- Taking a tool out on a job puts the tailgate supply back.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			clearSpot(player, false)
			-- A supply taken off the tailgate went with the old character: it's back there.
			local supplyId = takenOff[player]
			takenOff[player] = nil
			local model = supplyId and tailgate[player] and tailgate[player][supplyId]
			if model then
				model.Parent = folder
			end
			character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and takenOff[player] then
					MaintenanceService:PutBackSupply(player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		clearSpot(player, false)
		clearTailgate(player)
		working[player] = nil
		lastRequest[player] = nil
	end)
end

return MaintenanceService
