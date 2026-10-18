-- Buying and selling gear and business upgrades. The client only asks; every check happens here
-- (the rules themselves are in Shared/Shop.luau, so the shop menu can show them too).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Shop = require(Shared.Shop)
local Storage = require(Shared.Config.Storage)

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

local function shopState(data)
	return {
		owned = data.owned,
		equipped = data.equipped,
		level = GameConfig.levelFromXp(data.xp),
		trailerUnlocked = data.trailerUnlocked,
	}
end

function ShopService:Buy(player: Player, category: string, itemId: string): (boolean, string)
	local item = findItem(category, itemId)
	local data = DataService:Get(player)
	if not item or not data then
		return false, "That item doesn't exist."
	end
	local allowed, reason = Shop.canBuy(shopState(data), category, itemId)
	if not allowed then
		return false, reason or "You can't buy that."
	end
	if VEHICLE_CATEGORIES[category] and JobService:IsBusy(player) then
		return false, "You can't swap vehicles in the middle of a job."
	end
	if not DataService:TrySpend(player, item.price) then
		return false, `You need {Format.money(item.price - data.money)} more.`
	end

	data.owned[category][itemId] = true
	if not Items.isToolCategory(category) then
		return self:Equip(player, category, itemId)
	end
	DataService:Changed(player)
	TruckService:GearChanged(player)
	local spot = Storage.Spots[Storage.spotOf(item)]
	return true, `Bought the {item.name}! It's waiting in your storage ({string.lower(spot.name)}).`
end

-- Sells a tool back to the hardware store, to free up its storage spot.
function ShopService:Sell(player: Player, category: string, itemId: string): (boolean, string)
	local item = findItem(category, itemId)
	local data = DataService:Get(player)
	if not item or not data or not Items.isToolCategory(category) then
		return false, "You can only sell tools and supplies."
	end
	if not data.owned[category][itemId] then
		return false, "You don't own that."
	end
	if not Shop.canSell(item) then
		return false, "You can't sell your starter gear."
	end
	if data.loadout[itemId] then
		return false, "Take it out of the truck first."
	end
	if TruckService:IsCarrying(player, itemId) then
		return false, "Put it down first."
	end
	if JobService:IsBusy(player) then
		return false, "Not in the middle of a job."
	end

	local refund = Shop.sellPrice(item)
	data.owned[category][itemId] = nil
	DataService:AddMoney(player, refund)
	TruckService:GearChanged(player)
	return true, `Sold the {item.name} for {Format.money(refund)}.`
end

-- Switches to an owned truck, trailer or business. (Tools aren't equipped: you load the ones you
-- want into the truck.)
function ShopService:Equip(player: Player, category: string, itemId: string): (boolean, string)
	local item = findItem(category, itemId)
	local data = DataService:Get(player)
	if not item or not data or Items.isToolCategory(category) or not data.owned[category][itemId] then
		return false, "You don't own that yet."
	end
	if VEHICLE_CATEGORIES[category] and JobService:IsBusy(player) then
		return false, "You can't swap vehicles in the middle of a job."
	end
	if category == "Business" then
		local current = Items.get("Business", data.equipped.Business)
		if current and current.rank > item.rank then
			return false, "Your business is already bigger than that."
		end
	end

	data.equipped[category] = itemId
	-- A smaller truck or trailer might not fit everything anymore.
	DataService.trimLoadout(data)
	DataService:Changed(player)
	ToolService:GiveTools(player)
	if PLOT_CATEGORIES[category] then
		WorldService:RefreshPlot(player)
	end
	TruckService:GearChanged(player)
	PartyService:Refresh(player)
	return true, `Equipped the {item.name}.`
end

function ShopService:Init()
	Net.func("BuyItem").OnServerInvoke = function(player, category, itemId)
		return self:Buy(player, category, itemId)
	end
	Net.func("SellItem").OnServerInvoke = function(player, category, itemId)
		return self:Sell(player, category, itemId)
	end
	Net.func("EquipItem").OnServerInvoke = function(player, category, itemId)
		return self:Equip(player, category, itemId)
	end
end

return ShopService
