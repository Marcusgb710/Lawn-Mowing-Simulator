-- What a player is allowed to buy. The server enforces these rules, and the shop menu uses the
-- same ones to show why something is locked.

local GameConfig = require(script.Parent.Config.GameConfig)
local Items = require(script.Parent.Config.Items)
local Maintenance = require(script.Parent.Config.Maintenance)
local Storage = require(script.Parent.Config.Storage)
local Tools = require(script.Parent.Config.Tools)

local Shop = {}

-- Whether an owned consumable supply (gas, line, patches...) has room for a restock.
function Shop.canRestock(state, itemId: string): boolean
	local supply = Maintenance.Supplies[itemId]
	local condition = state.condition and state.condition[itemId]
	return supply ~= nil and supply.uses ~= nil and condition ~= nil and (condition.uses or 0) < supply.uses
end

-- `state` is a player's profile: { owned, equipped, level, trailerUnlocked, condition }.
-- Returns whether they may buy the item (money aside) and, if not, why. Buying a consumable
-- you already own restocks it.
function Shop.canBuy(state, category: string, itemId: string): (boolean, string?)
	local item = Items.get(category, itemId)
	if not item then
		return false, "That item doesn't exist."
	end
	local owned = state.owned[category]
	if owned and owned[itemId] then
		if Shop.canRestock(state, itemId) then
			return true, nil
		end
		return false, "You already own that."
	end

	if Items.isToolCategory(category) then
		local unlock = Tools.TierUnlocks[item.tier]
		if state.level < unlock.level then
			return false, `{item.tier} gear unlocks at level {unlock.level}.`
		end
		local business = Items.get("Business", state.equipped.Business) or Items.Catalog.Business[1]
		local needed = Items.get("Business", unlock.business)
		if business.rank < needed.rank then
			return false, `{item.tier} gear needs a {needed.name} or bigger.`
		end
		return Storage.hasRoom(state.owned, business.id, item)
	elseif category == "Trailer" and not state.trailerUnlocked then
		return false, "Fill up your truck to unlock trailers."
	elseif category == "Business" then
		local previous = Items.Catalog.Business[item.rank - 1]
		if previous and not state.owned.Business[previous.id] then
			return false, `Upgrade to the {previous.name} first.`
		end
	end
	return true, nil
end

-- Whether a tool can be sold back to the store. Free starter gear can't be.
function Shop.canSell(item): boolean
	return item.price > 0
end

function Shop.sellPrice(item): number
	return math.floor(item.price * GameConfig.SellRefund)
end

return Shop
