-- What players can buy with Robux (docs/GAME_DESIGN.md, "Premium"): the server (PremiumService)
-- handles the purchases, and the shop computer's Premium tab (ShopController) sells them.
--
--   Passes    Pro upgrades: game passes that help every tool you own (blades that never dull...)
--   Variants  premium versions of tools you own: a special finish, and a perk for that tool
--   Paints    paint jobs for your truck: looks only
--
-- Prices are in Robux and only shown in the game: what a player actually pays is what the game
-- pass or developer product is set to on Roblox. To add one, put it here with id 0 and run
-- `python3 scripts/premium-setup.py`: it creates it on Roblox at this price, puts it on sale and
-- writes its id in. Until it has an id, the shop shows "Soon" and can't sell it.
--
-- What a player owns is saved in their data as `premium`:
--   { owned = { [variant or paint id] = true }, passes = { [pass id] = true },
--     truckPaint = paint id or false, receipts = { [purchase id] = true },
--     earnedPaints = { [paint id] = true } }
-- and sent to their screen in their profile. `earnedPaints` are the paints in `owned` that were
-- given as level rewards, not bought (they have no receipt). The helpers below read that table.

local Premium = {}

-- The perks: what each one does is in Maintenance.wear.
--   neverDull    blades never dull
--   neverFlat    tires never lose air or go flat
--   endlessLine  trimmer line never runs out
--   bigTank      fuel lasts three times as long
export type Perks = { neverDull: boolean?, neverFlat: boolean?, endlessLine: boolean?, bigTank: boolean? }

Premium.Passes = {
	{
		id = "DiamondBlades",
		name = "Diamond Blades",
		description = "Every blade you own stays factory sharp, forever: mowers, edgers, hedge trimmers and "
			.. "pruners never need filing or swapping.",
		robux = 199,
		gamePassId = 2041838797,
		perk = "neverDull",
	},
	{
		id = "RunFlatTires",
		name = "Run-Flat Tires",
		description = "Every tire you own stays firm and can't go flat: no more pumping, patching or "
			.. "swapping wheels.",
		robux = 149,
		gamePassId = 2040328879,
		perk = "neverFlat",
	},
	{
		id = "EndlessSpool",
		name = "Endless Spool",
		description = "Your string trimmers and brush cutters never run out of line.",
		robux = 99,
		gamePassId = 2036381430,
		perk = "endlessLine",
	},
	{
		id = "BigTank",
		name = "Big Tank",
		description = "Every gas engine you own runs three times as long on a tank.",
		robux = 99,
		gamePassId = 2037311420,
		perk = "bigTank",
	},
}

-- How a premium finish looks, on the body of a tool (its wheels and glass keep their own look).
Premium.Finishes = {
	Gold = { color = Color3.fromRGB(214, 172, 52), material = Enum.Material.Foil },
	Chrome = { color = Color3.fromRGB(210, 214, 220), material = Enum.Material.Foil },
	Stealth = { color = Color3.fromRGB(32, 33, 37), material = Enum.Material.SmoothPlastic },
}

-- Premium versions of tools. You need the tool first; buying the premium version upgrades the
-- one you have, for good, so Robux never skips a tool's level or business requirement.
Premium.Variants = {
	{
		id = "GoldenGasPushMower",
		baseId = "GasPushMower",
		name = "Golden Push Mower",
		description = "Your gas push mower in solid gold, with a blade that never dulls.",
		robux = 249,
		productId = 3720356541,
		finish = "Gold",
		perks = { neverDull = true },
	},
	{
		id = "ChromeSelfPropelledMower",
		baseId = "SelfPropelledMower",
		name = "Chrome Self-Propelled Mower",
		description = "Your self-propelled mower in mirror chrome. Its blade never dulls and its tires never go flat.",
		robux = 299,
		productId = 3720356835,
		finish = "Chrome",
		perks = { neverDull = true, neverFlat = true },
	},
	{
		id = "StealthGasTrimmer",
		baseId = "GasTrimmer",
		name = "Stealth String Trimmer",
		description = "Your gas string trimmer in matte black, with a spool that never runs out.",
		robux = 199,
		productId = 3720356857,
		finish = "Stealth",
		perks = { endlessLine = true },
	},
	{
		id = "ChromeLeafBlower",
		baseId = "LeafBlower",
		name = "Chrome Leaf Blower",
		description = "Your leaf blower in mirror chrome, with a tank that lasts three times as long.",
		robux = 149,
		productId = 3720660280,
		finish = "Chrome",
		perks = { bigTank = true },
	},
	{
		id = "GoldenRidingMower",
		baseId = "RidingMower",
		name = "Golden Riding Mower",
		description = "Your riding mower in solid gold. Its blades never dull and its tires never go flat.",
		robux = 499,
		productId = 3720357006,
		finish = "Gold",
		perks = { neverDull = true, neverFlat = true },
	},
	{
		id = "StealthZeroTurn",
		baseId = "ZeroTurnMower",
		name = "Stealth Zero-Turn",
		description = "Your zero-turn in matte black. Its blades never dull, its tires never go flat and its "
			.. "tank lasts three times as long.",
		robux = 799,
		productId = 3720660282,
		finish = "Stealth",
		perks = { neverDull = true, neverFlat = true, bigTank = true },
	},
}

-- Paint jobs for whichever truck you drive. `tint` colours the truck's own paint; `finish` swaps
-- it for one of the finishes above.
Premium.Paints = {
	{ id = "RacingRed", name = "Racing Red", robux = 49, productId = 3720356546, tint = Color3.fromRGB(196, 40, 36) },
	{
		id = "MidnightBlack",
		name = "Midnight Black",
		robux = 49,
		productId = 3720660284,
		tint = Color3.fromRGB(40, 42, 48),
	},
	{
		id = "ForestGreen",
		name = "Forest Green",
		robux = 49,
		productId = 3720660287,
		tint = Color3.fromRGB(46, 110, 58),
	},
	{ id = "SkyBlue", name = "Sky Blue", robux = 49, productId = 3720660293, tint = Color3.fromRGB(90, 160, 220) },
	{ id = "StealthWrap", name = "Stealth Wrap", robux = 99, productId = 3720660297, finish = "Stealth" },
	{ id = "ChromeWrap", name = "Chrome Wrap", robux = 149, productId = 3720660305, finish = "Chrome" },
	{ id = "GoldWrap", name = "Gold Wrap", robux = 149, productId = 3720660307, finish = "Gold" },
}

local byId = {}
local byProductId = {}
local byPassId = {}
for _, pass in Premium.Passes do
	byId[pass.id] = pass
	if pass.gamePassId ~= 0 then
		byPassId[pass.gamePassId] = pass
	end
end
for _, list in { Premium.Variants, Premium.Paints } do
	for _, item in list do
		byId[item.id] = item
		if item.productId ~= 0 then
			byProductId[item.productId] = item
		end
	end
end

function Premium.get(id: string)
	return byId[id]
end

-- The variant or paint a developer product sells, if it's one of ours.
function Premium.forProduct(productId: number)
	return byProductId[productId]
end

-- The pass a game pass id is for, if it's one of ours.
function Premium.forPass(gamePassId: number)
	return byPassId[gamePassId]
end

-- Whether it's a paint job (as opposed to a premium tool).
function Premium.isPaint(item): boolean
	return item.tint ~= nil or (item.finish ~= nil and item.baseId == nil)
end

-- A fresh `premium` table for a player's data.
function Premium.empty()
	return { owned = {}, passes = {}, truckPaint = false, receipts = {}, earnedPaints = {} }
end

-- The perks working on one of a player's tools: their passes, and the premium version of that
-- tool if they own it. `premium` is the player's premium table (nil counts as nothing).
function Premium.perksFor(premium, toolId: string): Perks
	local perks = {}
	if not premium then
		return perks
	end
	for _, pass in Premium.Passes do
		if premium.passes and premium.passes[pass.id] then
			perks[pass.perk] = true
		end
	end
	for _, variant in Premium.Variants do
		if variant.baseId == toolId and premium.owned and premium.owned[variant.id] then
			for perk in variant.perks do
				perks[perk] = true
			end
		end
	end
	return perks
end

-- The finish a player's tool has, if they own its premium version.
function Premium.finishFor(premium, toolId: string): string?
	if not (premium and premium.owned) then
		return nil
	end
	for _, variant in Premium.Variants do
		if variant.baseId == toolId and premium.owned[variant.id] then
			return variant.finish
		end
	end
	return nil
end

-- The paint job on a player's truck, if any.
function Premium.paintFor(premium)
	local id = premium and premium.truckPaint
	return if typeof(id) == "string" and premium.owned and premium.owned[id] then byId[id] else nil
end

-- Parts that keep their own look under a finish or paint: glass, wheels and tires, and anything
-- invisible.
local function keepsLook(part: BasePart): boolean
	local name = part.Name
	return part.Transparency >= 1
		or string.find(name, "Glass", 1, true) ~= nil
		or string.find(name, "Wheel", 1, true) ~= nil
		or string.find(name, "Tire", 1, true) ~= nil
end

-- Gives a part a finish: its texture goes, for the finish's colour and material.
local function finishPart(part: BasePart, finish)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	part.Color = finish.color
	part.Material = finish.material
end

-- Puts a finish ("Gold", "Chrome", "Stealth") on a tool model or Tool.
function Premium.applyFinish(model: Instance, finishName: string?)
	local finish = finishName and Premium.Finishes[finishName]
	if not finish then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not keepsLook(part) then
			finishPart(part, finish)
		end
	end
end

-- The parts of a truck that are painted: its body, doors, tailgate and rear door.
local PAINTED = { "__Body", "__DriverDoor", "__Tailgate", "__RearDoor" }

-- Paints a truck (not its trailer).
function Premium.applyPaint(truck: Model, paint)
	if not paint then
		return
	end
	local finish = paint.finish and Premium.Finishes[paint.finish]
	for _, part in truck:GetDescendants() do
		if not part:IsA("BasePart") or keepsLook(part) or part:FindFirstAncestor("Trailer") then
			continue
		end
		local painted = false
		for _, suffix in PAINTED do
			if string.sub(part.Name, -#suffix) == suffix then
				painted = true
			end
		end
		if not painted then
			continue
		end
		if finish then
			finishPart(part, finish)
		else
			-- Tint the truck's own paint, keeping its texture; without tinting, paint it flat.
			local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
			local tinted = appearance ~= nil and pcall(function()
				(appearance :: any).Color = paint.tint
			end)
			if not tinted then
				finishPart(part, { color = paint.tint, material = Enum.Material.SmoothPlastic })
			end
		end
	end
end

return Premium
