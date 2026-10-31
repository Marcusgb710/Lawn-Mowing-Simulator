-- Buying and selling gear and business upgrades, from the HUD's Shop button or the computer in your
-- shop (the Orders and Business apps): the client only asks, and every check happens here (the
-- rules themselves are in Shared/Shop.luau, so the menus can show them too). Tools and supplies
-- (and selling them) work wherever you stand, and arrive in a box at the shop (DeliveryService).
-- Trucks, trailers and business buildings (PLOT_CATEGORIES) change what is built on your plot, are
-- there straight away, and are still bought and switched to at the computer in your shop. Taking a
-- job is a computer thing too (JobService:AcceptJob).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Shop = require(Shared.Shop)
local Signal = require(Shared.Signal)
local Storage = require(Shared.Config.Storage)

local DataService = require(script.Parent.DataService)
local DecorService = require(script.Parent.DecorService)
local DeliveryService = require(script.Parent.DeliveryService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local ToolService = require(script.Parent.ToolService)
local TruckService = require(script.Parent.TruckService)
local WorldService = require(script.Parent.WorldService)

-- Things you can't swap in the middle of a job.
local VEHICLE_CATEGORIES = { Truck = true, Trailer = true }
-- Things that change what's built on your business plot.
local PLOT_CATEGORIES = { Truck = true, Trailer = true, Business = true }
-- Seconds between shop requests from one player, so they can't be spammed.
local COOLDOWN = 0.25

local ShopService = {}
-- Fired with (player, category, item id) when they buy something they didn't own (not a
-- restock or a decoration).
ShopService.Bought = Signal.new()

-- [Player] = when they last used the shop
local lastRequest = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function findItem(category, itemId)
	if typeof(category) ~= "string" or typeof(itemId) ~= "string" then
		return nil
	end
	return Items.get(category, itemId)
end

local function shopState(data)
	local contest = data.contest
	return {
		owned = data.owned,
		equipped = data.equipped,
		level = GameConfig.levelFromXp(data.xp),
		trailerUnlocked = data.trailerUnlocked,
		condition = data.condition,
		-- The building a Best Yard win took half off (see ContestService).
		discount = if typeof(contest) == "table" and typeof(contest.discount) == "string"
			then contest.discount
			else nil,
	}
end

function ShopService:Buy(player: Player, category: string, itemId: string): (boolean, string)
	-- Decorations are for the crew's yard, and you can have several of each (see DecorService).
	if category == "Decorations" then
		return DecorService:Buy(player, itemId)
	end
	local item = findItem(category, itemId)
	local data = DataService:Get(player)
	if not item or not data then
		return false, "That item doesn't exist."
	end
	local allowed, reason = Shop.canBuy(shopState(data), category, itemId)
	if not allowed then
		return false, reason or "You can't buy that."
	end
	if PLOT_CATEGORIES[category] and not WorldService:IsAtComputer(player) then
		return false, "Order it from the computer in your shop."
	end
	if PLOT_CATEGORIES[category] and JobService:IsBusy(player) then
		return false, "You can't swap vehicles or buildings in the middle of a job."
	end
	if Items.isToolCategory(category) and JobService:IsBusy(player) then
		-- What you brought is what you've got until you're back.
		return false, "Finish the job first. Your orders can wait."
	end
	local state = shopState(data)
	local price = Shop.price(state, category, itemId)
	if not DataService:TrySpend(player, price) then
		return false, `You need {Format.money(price - data.money)} more.`
	end
	-- The Best Yard discount is used up.
	if state.discount == itemId and category == "Business" then
		data.contest.discount = false
	end

	if data.owned[category][itemId] then
		-- Buying a consumable you already have refills it.
		data.condition[itemId] = Maintenance.fresh(item)
		DataService:Changed(player)
		return true, `Restocked the {item.name}.`
	end
	data.owned[category][itemId] = true
	if Items.isToolCategory(category) then
		data.condition[itemId] = Maintenance.fresh(item)
	end
	ShopService.Bought:Fire(player, category, itemId)
	if not Items.isToolCategory(category) then
		return self:Equip(player, category, itemId)
	end
	DeliveryService:Order(player, itemId)
	TruckService:GearChanged(player)
	local spot = Storage.Spots[Storage.spotOf(item)]
	return true,
		`Ordered the {item.name}! It'll be delivered to your shop. Unbox it and put it on the {string.lower(spot.name)}.`
end

-- Sells a tool back (Orders), to free up its storage spot.
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
	if player:GetAttribute("Servicing") == itemId then
		return false, "Pick it up off the workbench first."
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

	local refund = Shop.sellPrice(item, data.condition[itemId])
	data.owned[category][itemId] = nil
	data.condition[itemId] = nil
	-- Out of its spot, the bucket and any box it was still in.
	DataService.reconcileStorage(data)
	DataService:AddMoney(player, refund)
	TruckService:GearChanged(player)
	DeliveryService:Refresh(player)
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
	if PLOT_CATEGORIES[category] and not WorldService:IsAtComputer(player) then
		return false, "Switch it over on the computer in your shop."
	end
	if PLOT_CATEGORIES[category] and JobService:IsBusy(player) then
		return false, "You can't swap vehicles or buildings in the middle of a job."
	end
	if data.equipped[category] == itemId then
		return true, `The {item.name} is already yours.`
	end
	if category == "Business" then
		local current = Items.get("Business", data.equipped.Business)
		if current and current.rank > item.rank then
			return false, "Your business is already bigger than that."
		end
	end

	data.equipped[category] = itemId
	-- A smaller truck or trailer might not fit everything anymore. Crew members' tools ride in
	-- the leader's truck, so only the leader's (or a solo player's) loadout depends on their own.
	local party = PartyService:GetParty(player)
	if VEHICLE_CATEGORIES[category] and (not party or party.leader == player) then
		DataService.trimLoadout(data)
	end
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
	local function handle(method)
		return function(player, category, itemId)
			if tooSoon(player) then
				return false, "One thing at a time."
			end
			return method(self, player, category, itemId)
		end
	end
	Net.func("BuyItem").OnServerInvoke = handle(self.Buy)
	Net.func("SellItem").OnServerInvoke = handle(self.Sell)
	Net.func("EquipItem").OnServerInvoke = handle(self.Equip)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
