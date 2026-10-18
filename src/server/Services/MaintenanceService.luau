-- Working on tools: fuel, air, patches, sharpening, new blades and tires, trimmer line and
-- engine repairs (the rules are in Maintenance.luau).
--
-- There are two places to do it:
--   at a business workbench   every tool and supply you own (they're in your storage), plus the
--                             building's own air compressor and bench grinder
--   at the truck on a job     only the tools and supplies you loaded (the tailgate)
-- Each job takes a few seconds; you have to stay put until it's done. Using the wrong supply
-- does what it would really do: regular gas in a two-stroke wrecks the engine.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local ToolService = require(script.Parent.ToolService)
local WorldService = require(script.Parent.WorldService)

-- How close to the truck you need to be to use the tailgate on a job.
local TAILGATE_REACH = 16
-- How far you can wander while working before the job is spoiled.
local STAY_RADIUS = 6

local MaintenanceService = {}

-- [Player] = { token, toolId, supplyId, place, position } while they're working on something
local working = {}

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function ownedTool(data, toolId)
	local tool = typeof(toolId) == "string" and Tools.get(toolId)
	local item = tool and Items.get(tool.category, toolId)
	return if item and data.owned[item.category] and data.owned[item.category][toolId] then item else nil
end

-- Where the player can work on tools right now, and with what:
-- { kind = "Bench" | "Field", tools = { [id] = true }, supplies = { [id] = true } }, or nil.
local function placeFor(player: Player)
	local data = DataService:Get(player)
	local root = rootOf(player)
	if not (data and root) then
		return nil
	end
	local tools, supplies = {}, {}
	if JobService:IsAtJobSite(player) then
		local job = JobService:GetJob(player)
		local truck = job and job.lawn and job.lawn.truckCFrame
		if not truck or (root.Position - truck.Position).Magnitude > TAILGATE_REACH then
			return nil
		end
		for id in data.loadout do
			if Maintenance.isStationary(id) then
				continue
			elseif Maintenance.Supplies[id] then
				supplies[id] = true
			else
				tools[id] = true
			end
		end
		return { kind = "Field", tools = tools, supplies = supplies }
	end

	local businessId = not JobService:IsBusy(player) and WorldService:GetWorkbenchBusiness(player)
	if not businessId then
		return nil
	end
	for _, item in Items.ownedTools(data.owned) do
		if Maintenance.Supplies[item.id] then
			supplies[item.id] = true
		else
			tools[item.id] = true
		end
	end
	local business = Items.get("Business", businessId)
	for _, fixture in business and business.fixtures or {} do
		supplies[fixture] = true
	end
	return { kind = "Bench", tools = tools, supplies = supplies }
end

-- A consumable with nothing left can't be used. Built-in fixtures are never used up.
local function usesLeft(data, supplyId: string): number?
	local supply = Maintenance.Supplies[supplyId]
	if not supply or not supply.uses then
		return nil
	end
	local condition = data.condition[supplyId]
	return if condition then condition.uses or 0 else 0
end

-- Whether a supply is here and has something left, for supplies another one `needs`.
local function availableIn(place, data)
	return function(id: string): boolean
		local left = usesLeft(data, id)
		return place.supplies[id] == true and (left == nil or left > 0)
	end
end

local function stop(player: Player)
	working[player] = nil
	if player.Parent == Players then
		player:SetAttribute("MaintainingUntil", nil)
	end
end

-- Public API ---------------------------------------------------------------------------------

-- What the Workbench menu shows: where you are and what you can use.
function MaintenanceService:Describe(player: Player)
	local data = DataService:Get(player)
	local place = placeFor(player)
	if not (data and place) then
		return { kind = nil }
	end
	local tools, supplies = {}, {}
	-- [tool id] = what's wrong with it right now (the profile can lag behind mid-job)
	local warnings = {}
	for _, item in Items.ownedTools(data.owned) do
		if place.tools[item.id] then
			table.insert(tools, item.id)
			warnings[item.id] = Maintenance.warnings(item, data.condition[item.id] or {})
		end
	end
	for _, id in Maintenance.SupplyOrder do
		if place.supplies[id] then
			table.insert(supplies, { id = id, uses = usesLeft(data, id), owned = ownedTool(data, id) ~= nil })
		end
	end
	return { kind = place.kind, tools = tools, supplies = supplies, warnings = warnings }
end

-- Starts using a supply on one of the player's tools. It takes effect when the time is up.
function MaintenanceService:Work(player: Player, toolId: string, supplyId: string): (boolean, string)
	local data = DataService:Get(player)
	local item = data and ownedTool(data, toolId)
	local supplyTool = typeof(supplyId) == "string" and Tools.get(supplyId)
	if not (item and supplyTool and Maintenance.Supplies[supplyId]) then
		return false, "That won't work here."
	end
	if working[player] then
		return false, "Finish what you're working on first."
	end
	if player:GetAttribute("Carrying") then
		return false, "Put down what you're carrying first."
	end
	local place = placeFor(player)
	if not place then
		return false, "Find a workbench, or your truck on a job."
	end
	if not place.tools[toolId] then
		return false, `Your {item.name} isn't here.`
	end
	if not place.supplies[supplyId] then
		return false, `You don't have a {supplyTool.name} here.`
	end
	local left = usesLeft(data, supplyId)
	if left and left <= 0 then
		return false, `The {supplyTool.name} is used up. Restock it at the hardware store.`
	end

	-- Try it on a copy first, so nobody waits around just to hear it won't work.
	local preview = table.clone(data.condition[toolId] or {})
	local ok, message, cost = Maintenance.apply(item, preview, supplyId, availableIn(place, data))
	if not ok then
		return false, message
	end
	if cost > data.money then
		return false, `The parts cost {Format.money(cost)}.`
	end

	local seconds = Maintenance.Supplies[supplyId].seconds
	local token = {}
	local root = rootOf(player)
	working[player] = { token = token, position = root and root.Position }
	player:SetAttribute("MaintainingUntil", workspace:GetServerTimeNow() + seconds)

	task.delay(seconds, function()
		local job = working[player]
		if not job or job.token ~= token then
			return
		end
		stop(player)
		local now = rootOf(player)
		local moved = if now and job.position then now.Position - job.position else nil
		-- Sideways only: hopping on the spot is fine.
		if not (moved and Vector2.new(moved.X, moved.Z).Magnitude <= STAY_RADIUS) then
			notify(player, "You walked off before you finished.")
			return
		end
		-- Things may have changed while they worked (a crew job starting, a sale...).
		local stillPlace = placeFor(player)
		local fresh = DataService:Get(player)
		if
			not (
				fresh
				and stillPlace
				and stillPlace.tools[toolId]
				and stillPlace.supplies[supplyId]
				and ownedTool(fresh, toolId)
			)
		then
			notify(player, "You couldn't finish the job.")
			return
		end
		local condition = fresh.condition[toolId]
		local stillLeft = usesLeft(fresh, supplyId)
		if not condition or (stillLeft and stillLeft <= 0) then
			notify(player, "You couldn't finish the job.")
			return
		end
		-- Work on a copy, and only keep it once any parts are paid for.
		local worked = table.clone(condition)
		local done, result, price = Maintenance.apply(item, worked, supplyId, availableIn(stillPlace, fresh))
		if done then
			if price > 0 and not DataService:TrySpend(player, price) then
				notify(player, `The parts cost {Format.money(price)}.`)
				return
			end
			for key, value in worked do
				condition[key] = value
			end
			local supplyCondition = fresh.condition[supplyId]
			if Maintenance.Supplies[supplyId].uses and supplyCondition and supplyCondition.uses then
				supplyCondition.uses = math.max(0, supplyCondition.uses - 1)
			end
			if price > 0 then
				result ..= ` Parts: {Format.money(price)}.`
			end
		end
		notify(player, result)
		DataService:Changed(player)
		ToolService:RefreshCondition(player)
	end)
	return true, `Working on the {item.name}...`
end

-- Lifecycle ----------------------------------------------------------------------------------

function MaintenanceService:Init()
	Net.func("GetWorkbench").OnServerInvoke = function(player)
		return self:Describe(player)
	end
	Net.func("Maintain").OnServerInvoke = function(player, toolId, supplyId)
		return self:Work(player, toolId, supplyId)
	end
end

function MaintenanceService:Start()
	-- Heading out on a job (or coming back) means putting the work down.
	JobService.PlayerStateChanged:Connect(stop)
	Players.PlayerRemoving:Connect(function(player)
		working[player] = nil
	end)
end

return MaintenanceService
