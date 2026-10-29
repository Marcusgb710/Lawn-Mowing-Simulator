-- Robux purchases (docs/GAME_DESIGN.md, "Premium"; the catalog is Shared/Config/Premium.luau).
-- The client opens Roblox's purchase prompt itself; everything that's granted happens here:
--   * game passes: checked when a player joins, and again when they buy one in the game
--   * developer products (premium tools and paint jobs): granted in ProcessReceipt, which saves
--     the player straight away and remembers the receipt, so a purchase is never given twice
--     and never lost
--   * paint jobs earned as level rewards (SeasonService): GrantPaint, with no receipt
-- It also switches the paint job on your truck.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Premium = require(Shared.Config.Premium)

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

-- Receipts kept per player, so the list can't grow forever. Roblox stops retrying a receipt
-- long before this many newer purchases.
local MAX_RECEIPTS = 200

local PremiumService = {}

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

-- The perks working on one of a player's tools (see Premium.perksFor).
function PremiumService:PerksFor(player: Player, toolId: string): Premium.Perks
	local data = DataService:Get(player)
	return Premium.perksFor(data and data.premium, toolId)
end

-- The finish on one of a player's tools, if it's a premium one.
function PremiumService:FinishFor(player: Player, toolId: string): string?
	local data = DataService:Get(player)
	return Premium.finishFor(data and data.premium, toolId)
end

-- The paint job on a player's truck, if any.
function PremiumService:PaintFor(player: Player)
	local data = DataService:Get(player)
	return Premium.paintFor(data and data.premium)
end

-- Checks which of our game passes a player owns.
local function checkPasses(player: Player)
	local data = DataService:WaitForData(player)
	if not data then
		return
	end
	local changed = false
	for _, pass in Premium.Passes do
		if pass.gamePassId ~= 0 and not data.premium.passes[pass.id] then
			local ok, owns =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.gamePassId)
			if ok and owns then
				data.premium.passes[pass.id] = true
				changed = true
			end
		end
	end
	if changed then
		DataService:Changed(player)
	end
end

local function rememberReceipt(premium, purchaseId: string)
	premium.receipts[purchaseId] = os.time()
	local count, oldestId, oldest = 0, nil, math.huge
	for id, at in premium.receipts do
		count += 1
		local time = if typeof(at) == "number" then at else 0
		if time < oldest then
			oldestId, oldest = id, time
		end
	end
	if count > MAX_RECEIPTS and oldestId then
		premium.receipts[oldestId] = nil
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local item = Premium.forProduct(receipt.ProductId)
	local data = player and DataService:Get(player)
	if not (player and item and data) then
		-- They left, or their save isn't loaded yet: Roblox tries again later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local premium = data.premium
	if premium.receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	premium.owned[item.id] = true
	if Premium.isPaint(item) then
		premium.truckPaint = item.id
	end
	rememberReceipt(premium, receipt.PurchaseId)
	if not DataService:Save(player) then
		-- Not saved: take it back so it's granted again on the retry.
		premium.owned[item.id] = nil
		premium.receipts[receipt.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService:Changed(player)
	if Premium.isPaint(item) then
		WorldService:RefreshPlot(player)
		notify(player, `Your truck's got its {item.name} paint job!`)
	else
		-- Their tools pick up the new look next time they're taken out.
		notify(player, `You own the {item.name}!`)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Switches the paint job on their truck to one they own ("" for none).
function PremiumService:SetPaint(player: Player, paintId: string): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Your save isn't loaded yet."
	end
	if paintId == "" then
		data.premium.truckPaint = false
	else
		local paint = Premium.get(paintId)
		if not (paint and Premium.isPaint(paint) and data.premium.owned[paintId]) then
			return false, "You don't own that paint job."
		end
		data.premium.truckPaint = paintId
	end
	DataService:Changed(player)
	WorldService:RefreshPlot(player)
	return true, if paintId == "" then "Back to the truck's own paint." else "Paint job on!"
end

-- Gives them a paint job they earned (a level reward, see SeasonService). It's theirs the way a
-- bought one is, in `owned`, but no receipt goes with it: it's listed in `earnedPaints` instead,
-- so the shop can say "Earned" where a bought one has its price. It isn't put on their truck, and
-- one they already own, bought or earned, is left as it is. Returns whether it was new.
function PremiumService:GrantPaint(player: Player, paintId: string): boolean
	local data = DataService:Get(player)
	local paint = Premium.get(paintId)
	if not (data and paint and Premium.isPaint(paint)) then
		return false
	end
	local premium = data.premium
	if premium.owned[paintId] then
		return false
	end
	premium.owned[paintId] = true
	premium.earnedPaints = premium.earnedPaints or {}
	premium.earnedPaints[paintId] = true
	DataService:Changed(player)
	return true
end

function PremiumService:Init()
	Net.func("SetTruckPaint").OnServerInvoke = function(player, paintId)
		if typeof(paintId) ~= "string" then
			return false, "Pick a paint job."
		end
		return self:SetPaint(player, paintId)
	end
end

function PremiumService:Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local pass = Premium.forPass(gamePassId)
		local data = DataService:Get(player)
		if purchased and pass and data then
			data.premium.passes[pass.id] = true
			DataService:Changed(player)
			notify(player, `{pass.name} is on for all your tools!`)
		end
	end)
	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
end

return PremiumService
