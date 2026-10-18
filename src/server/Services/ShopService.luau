-- Buying gear and business upgrades, and loading tools into the crew truck.
-- The client only asks; every check happens here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local ToolService = require(script.Parent.ToolService)
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

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

-- Trailers unlock for the truck's owner (the crew leader) the first time its bed fills up.
local function checkTrailerUnlock(player: Player)
	local used, capacity = PartyService:GetTruckLoad(player)
	local party = PartyService:GetParty(player)
	local owner = if party then party.leader else player
	local ownerData = DataService:Get(owner)
	if ownerData and not ownerData.trailerUnlocked and used >= capacity then
		ownerData.trailerUnlocked = true
		DataService:Changed(owner)
		notify(owner, "Your truck bed is full! Trailers are now unlocked at the hardware store.")
	end
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
		message = `Bought {item.name}! Load it into your truck at your business's tool rack.`
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
	PartyService:Refresh(player)
	return true, `Equipped {item.name}.`
end

-- Loads a tool from the tool rack into the crew truck, or takes it back out.
-- Only loaded tools come along on jobs.
function ShopService:SetLoaded(player: Player, category: string, loaded: boolean): (boolean, string)
	local data = DataService:Get(player)
	if not data or typeof(category) ~= "string" or not isTool(category) then
		return false, "That isn't a tool."
	end
	if not data.equipped[category] then
		return false, "You don't own one of those yet."
	end
	if JobService:IsBusy(player) then
		return false, "You can't repack the truck in the middle of a job."
	end
	if not WorldService:IsAtBusiness(player) then
		return false, "Head back to your business to load the truck."
	end

	local name = Items.CategoryInfo[category].toolName
	if loaded and not data.loadout[category] then
		local used, capacity = PartyService:GetTruckLoad(player)
		if used >= capacity then
			return false, "The truck bed is full. Unload something or hitch up a trailer."
		end
		data.loadout[category] = true
	elseif not loaded then
		data.loadout[category] = nil
	end

	checkTrailerUnlock(player)
	DataService:Changed(player)
	ToolService:GiveTools(player)
	PartyService:Refresh(player)
	return true, if loaded then `{name} loaded into the truck.` else `{name} put back on the rack.`
end

function ShopService:Init()
	Net.func("BuyItem").OnServerInvoke = function(player, category, itemId)
		return self:Buy(player, category, itemId)
	end
	Net.func("EquipItem").OnServerInvoke = function(player, category, itemId)
		return self:Equip(player, category, itemId)
	end
	Net.func("SetToolLoaded").OnServerInvoke = function(player, category, loaded)
		return self:SetLoaded(player, category, loaded == true)
	end
end

return ShopService
