-- Orders from the shop computer (docs/GAME_DESIGN.md, "The shop as the hub"). Tools and supplies
-- arrive in a box at the shop; trucks, trailers and buildings don't need one. The list of what's
-- still on its way or unopened is saved with the player (`deliveries`).

local Deliveries = {}

-- The box each size class comes in (Props/<box>).
Deliveries.Boxes = {
	Hand = "DeliveryBoxSmall",
	Supply = "DeliveryBoxSmall",
	Long = "DeliveryBoxLong",
	HangingPower = "DeliveryBoxLarge",
	FloorManual = "DeliveryBoxLarge",
	FloorEngine = "DeliveryBoxLarge",
	Bay = "DeliveryCrate",
}

export type Delivery = { key: number, id: string, arrives: number }

function Deliveries.boxFor(sizeClass: string): string
	return Deliveries.Boxes[sizeClass] or "DeliveryBoxLarge"
end

-- Whether `itemId` is still in a box (on its way or unopened).
function Deliveries.pending(list: { Delivery }?, itemId: string): boolean
	if list then
		for _, delivery in list do
			if delivery.id == itemId then
				return true
			end
		end
	end
	return false
end

-- A key for a new delivery: one more than any in the list.
function Deliveries.nextKey(list: { Delivery }): number
	local highest = 0
	for _, delivery in list do
		highest = math.max(highest, delivery.key)
	end
	return highest + 1
end

return Deliveries
