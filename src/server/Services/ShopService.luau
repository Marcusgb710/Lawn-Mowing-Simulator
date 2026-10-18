-- Buying gear and business upgrades. The client only asks; every check happens here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local ToolService = require(script.Parent.ToolService)
local TruckService = require(script.Parent.TruckService)
local WorldService = require(script.Parent.WorldService)

-- Things you can't swap in the middle of a job.
local VEHICLE_CATEGORIES = { Truck = true, Trailer = true }
-- Things that change what's built on your business plot.
local PLOT_CATEGORIES = { Truck = true, Trailer = true, Business = true }

local ShopService = {}

local function findItem(category, itemId)
	if typeof(category) ~= "string" or typeof(itemId) ~= "string" then
		return nil
	end
	return Items.get(category, itemId)
end

local function isTool(category: string): boolean
	return table.find(Items.ToolCategories, category) ~= nil
end

function ShopService:Buy(player: Player, category: string, itemId: string): (boolean, string)
	local item = findItem(category, itemId)
	local data = DataService:Get(player)
	if not item or not data then
		return false, "That item doesn't exist."
	end
	if data.owned[category][itemId] then
		return false, "You already own that."
	end
	if category == "Trailer" and not data.trailerUnlocked then
		return false, "Fill up your truck bed to unlock trailers."
	end
	if category == "Business" then
		local previous = Items.Catalog.Business[item.tier - 1]
		if previous and not data.owned.Business[previous.id] then
			return false, `Upgrade to the {previous.name} first.`
		end
	end
	if VEHICLE_CATEGORIES[category] and JobService:IsBusy(player) then
		return false, "You can't swap vehicles in the middle of a job."
	end
	if not DataService:TrySpend(player, item.price) then
		return false, `You need {Format.money(item.price - data.money)} more.`
	end

	local isNewTool = isTool(category) and data.equipped[category] == nil
	data.owned[category][itemId] = true
	local ok, message = self:Equip(player, category, itemId)
	if isNewTool then
		message = `Bought {item.name}! Grab it from your tool rack and carry it to the truck.`
	end
	return ok, message
end

function ShopService:Equip(player: Player, category: string, itemId: string): (boolean, string)
	local item = findItem(category, itemId)
	local data = DataService:Get(player)
	if not item or not data or not data.owned[category][itemId] then
		return false, "You don't own that yet."
	end
	if VEHICLE_CATEGORIES[category] and JobService:IsBusy(player) then
		return false, "You can't swap vehicles in the middle of a job."
	end
	if category == "Business" then
		local current = Items.get("Business", data.equipped.Business)
		if current and current.tier > item.tier then
			return false, "Your business is already bigger than that."
		end
	end

	data.equipped[category] = itemId
	-- A smaller truck bed might not fit everything anymore.
	DataService.trimLoadout(data)
	DataService:Changed(player)
	ToolService:GiveTools(player)
	if PLOT_CATEGORIES[category] then
		WorldService:RefreshPlot(player)
	end
	TruckService:GearChanged(player, category)
	PartyService:Refresh(player)
	return true, `Equipped {item.name}.`
end

function ShopService:Init()
	Net.func("BuyItem").OnServerInvoke = function(player, category, itemId)
		return self:Buy(player, category, itemId)
	end
	Net.func("EquipItem").OnServerInvoke = function(player, category, itemId)
		return self:Equip(player, category, itemId)
	end
end

return ShopService
