-- Where tools live at the business, and how much room they take in the truck.
-- See docs/GAME_DESIGN.md, "Storage and hauling".
--
-- Every tool's size class (Tools.SizeClasses) gives it a kind of storage spot and a truck space.
-- Each business building (Items.Catalog.Business) has a number of spots of each kind. You can't
-- buy a tool without a free spot for it, but you never lose tools you already own: anything
-- without a spot (say, after a save from before storage existed) is kept next to the others.

local Items = require(script.Parent.Items)
local Tools = require(script.Parent.Tools)

local Storage = {}

-- The kinds of storage spot. `fixture` is the model in Assets.Props that holds them, `perFixture`
-- how many spots one of those has.
Storage.Spots = {
	Pegboard = { name = "Pegboard", holds = "hand tools", fixture = "StoragePegboard", perFixture = 6 },
	WallRack = { name = "Wall rack", holds = "long-handled tools", fixture = "StorageWallRack", perFixture = 4 },
	WallHooks = { name = "Wall hooks", holds = "handheld power tools", fixture = "StorageWallHooks", perFixture = 2 },
	Shelf = { name = "Shelf", holds = "supplies", fixture = "StorageShelf", perFixture = 6 },
	Floor = { name = "Floor spot", holds = "push mowers and walk-behind machines" },
	Bay = { name = "Equipment bay", holds = "ride-on machines" },
}
Storage.SpotOrder = { "Pegboard", "WallRack", "WallHooks", "Shelf", "Floor", "Bay" }

-- A tool bucket in the truck holds this many of its owner's hand tools in its own one space.
Storage.BucketId = "ToolBucket"
Storage.BucketHolds = 8

function Storage.spotOf(tool): string
	return Tools.SizeClasses[tool.sizeClass].spot
end

function Storage.spaceOf(tool): number
	return Tools.SizeClasses[tool.sizeClass].space
end

function Storage.capacity(businessId: string?, spot: string): number
	local business = Items.get("Business", businessId or "Shed") or Items.Catalog.Business[1]
	return business.storage[spot] or 0
end

-- How many of `owned`'s tools use this kind of spot.
function Storage.used(owned, spot: string): number
	local count = 0
	for _, tool in Items.ownedTools(owned) do
		if Storage.spotOf(tool) == spot then
			count += 1
		end
	end
	return count
end

-- Whether a business with these tools has a free spot for one more `tool`, and if not, why.
function Storage.hasRoom(owned, businessId: string?, tool): (boolean, string?)
	local business = Items.get("Business", businessId or "Shed") or Items.Catalog.Business[1]
	local spot = Storage.spotOf(tool)
	local info = Storage.Spots[spot]
	if tool.sizeClass == "FloorEngine" and business.noEngines then
		return false, `The {business.name} has no floor room for machines with an engine.`
	end
	local capacity = Storage.capacity(business.id, spot)
	if capacity == 0 then
		return false, `The {business.name} has no room for {info.holds}.`
	end
	local used = Storage.used(owned, spot)
	if used >= capacity then
		return false, `No free spot for {info.holds} ({used}/{capacity}). Sell one or upgrade your business.`
	end
	return true, nil
end

-- Truck space and ride-on bays one player's loaded tools take, given as tool ids.
-- Hand tools in their tool bucket (`inBucket`, { [toolId] = true }) ride free while the bucket is
-- loaded too. Without `inBucket`, a loaded bucket carries up to BucketHolds of the hand tools.
function Storage.load(toolIds: { string }, inBucket: { [string]: boolean }?): (number, number)
	local space, bays, hand = 0, 0, 0
	local bucket = table.find(toolIds, Storage.BucketId) ~= nil
	for _, id in toolIds do
		local tool = Tools.get(id)
		if not tool then
			continue
		end
		if tool.sizeClass == "Bay" then
			bays += 1
		elseif tool.sizeClass == "Hand" then
			if not (inBucket and bucket and inBucket[id]) then
				hand += 1
			end
		else
			space += Storage.spaceOf(tool)
		end
	end
	local handSpace = Tools.SizeClasses.Hand.space
	local looseHand = if bucket and not inBucket then math.max(0, hand - Storage.BucketHolds) else hand
	return space + looseHand * handSpace, bays
end

-- How many tools are in this bucket list ({ [toolId] = true }).
function Storage.bucketCount(inBucket: { [string]: boolean }?): number
	local count = 0
	if inBucket then
		for _ in inBucket do
			count += 1
		end
	end
	return count
end

-- The tool ids in a loadout ({ [id] = true }), in shop order.
function Storage.loadedIds(loadout): { string }
	local ids = {}
	for _, category in Items.ToolCategories do
		for _, item in Items.Catalog[category] do
			if loadout[item.id] then
				table.insert(ids, item.id)
			end
		end
	end
	return ids
end

return Storage
