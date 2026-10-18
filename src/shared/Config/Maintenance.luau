-- Keeping tools running (design phase E, docs/GAME_DESIGN.md section 6).
--
-- Every owned tool has a condition, saved with the player:
--   fuel       0-1, engines only. Four-strokes burn regular gas, two-strokes need 50:1 mix.
--   broken     the wrong fuel went in; the engine won't start until it's repaired
--   pressure   0-1, air tires only. Low pressure is slower and harder to push.
--   flat       a puncture; the machine won't roll until it's patched or the tire is swapped
--   sharpness  0-1, blades only. A dull blade tears instead of cutting (lower quality, slower).
--   line       0-1, string trimmers only. No line, no cutting.
--   uses       consumable supplies only: how many fills, reloads or patches are left
--
-- Players see conditions ("Running low on fuel", "Tire looks soft"), never which supply fixes
-- them: knowing that a two-stroke takes mix is part of knowing your tools.

local Tools = require(script.Parent.Tools)

local Maintenance = {}

-- How fast things wear out, in seconds of use from full to empty.
Maintenance.Wear = {
	FourStrokeFuel = 300, -- running time on a full tank
	TwoStrokeFuel = 240,
	Pressure = 1800, -- rolling time before air tires are flat out
	Blade = 1200, -- cutting time from sharp to dull
	Line = 240, -- trimming time on one load of line
}
-- Chance per second of rolling that an air tire picks up a puncture.
Maintenance.PunctureChance = 1 / 2400
-- Below these a warning shows.
Maintenance.LowFuel = 0.25
Maintenance.LowPressure = 0.5
Maintenance.DullBlade = 0.5
Maintenance.LowLine = 0.25
-- Fixing a wrecked engine costs this fraction of the tool's price in parts (at least MinRepairCost).
Maintenance.RepairCost = 0.1
Maintenance.MinRepairCost = 10

-- What each supply does. `seconds` is how long the job takes, `uses` how many times a
-- consumable works before it needs restocking (buy it again), `needs` another supply that has
-- to be there too, and `stationary` ones never leave the building.
Maintenance.Supplies = {
	GasCan = { action = "Fuel", fuel = "FourStroke", seconds = 2, uses = 6 },
	MixGasCan = { action = "Fuel", fuel = "TwoStroke", seconds = 2, uses = 6 },
	FootPump = { action = "Inflate", seconds = 8 },
	ElectricInflator = { action = "Inflate", seconds = 2 },
	AirCompressor = { action = "Inflate", seconds = 1, stationary = true },
	TirePatchKit = { action = "Patch", seconds = 6, uses = 4 },
	SpareTire = { action = "SwapTire", seconds = 10, uses = 1, needs = "WrenchSet" },
	WrenchSet = { action = "Repair", seconds = 15 },
	BladeFile = { action = "Sharpen", blade = "Heavy", seconds = 10 },
	SharpeningStone = { action = "Sharpen", blade = "Fine", seconds = 8 },
	BenchGrinder = { action = "Sharpen", blade = "Heavy", seconds = 3, stationary = true },
	SpareMowerBlade = { action = "SwapBlade", seconds = 6, uses = 1, needs = "WrenchSet" },
	TrimmerLine = { action = "Reload", seconds = 4, uses = 5 },
}

-- The order supplies are listed in at the workbench.
Maintenance.SupplyOrder = {
	"GasCan",
	"MixGasCan",
	"FootPump",
	"ElectricInflator",
	"AirCompressor",
	"TirePatchKit",
	"SpareTire",
	"WrenchSet",
	"BladeFile",
	"SharpeningStone",
	"BenchGrinder",
	"SpareMowerBlade",
	"TrimmerLine",
}

-- Reel mowers have a cutting cylinder, not a blade you can bolt on.
local REEL_MOWERS = { ReelMower = true, CommercialReelMower = true }

local function hasAnyVerb(tool, verbs: { string }): boolean
	for _, verb in verbs do
		if Tools.hasVerb(tool, verb) then
			return true
		end
	end
	return false
end

-- "Heavy" blades (mowers, edgers, spades) take a file or grinder; "Fine" edges (pruners,
-- shears, hedge trimmers) take a stone. Nil if the tool has no blade.
function Maintenance.bladeOf(tool): string?
	if hasAnyVerb(tool, { "Mow", "Edge" }) then
		return "Heavy"
	elseif hasAnyVerb(tool, { "Prune", "Shear" }) or (Tools.hasVerb(tool, "Trim") and tool.engine == "None") then
		return "Fine"
	end
	return nil
end

-- Rotary mowers take a spare blade; reel mowers' cylinders don't come off.
function Maintenance.takesSpareBlade(tool): boolean
	return Tools.hasVerb(tool, "Mow") and not REEL_MOWERS[tool.id]
end

function Maintenance.isReelMower(tool): boolean
	return REEL_MOWERS[tool.id] == true
end

function Maintenance.burnsFuel(tool): boolean
	return tool.engine == "FourStroke" or tool.engine == "TwoStroke"
end

function Maintenance.usesLine(tool): boolean
	return Tools.hasVerb(tool, "Trim") and tool.engine ~= nil and tool.engine ~= "None"
end

function Maintenance.isStationary(toolId: string): boolean
	local supply = Maintenance.Supplies[toolId]
	return supply ~= nil and supply.stationary == true
end

-- A brand-new tool's condition.
function Maintenance.fresh(tool)
	local condition = {}
	if Maintenance.burnsFuel(tool) then
		condition.fuel = 1
		condition.broken = false
	end
	if tool.tires == "Air" then
		condition.pressure = 1
		condition.flat = false
	end
	if Maintenance.bladeOf(tool) then
		condition.sharpness = 1
	end
	if Maintenance.usesLine(tool) then
		condition.line = 1
	end
	local supply = Maintenance.Supplies[tool.id]
	if supply and supply.uses then
		condition.uses = supply.uses
	end
	return condition
end

-- Fills in anything missing from a saved condition (as new), and drops what doesn't apply.
function Maintenance.reconcile(tool, saved)
	local condition = Maintenance.fresh(tool)
	if typeof(saved) == "table" then
		for key, value in condition do
			if typeof(saved[key]) == typeof(value) then
				condition[key] = saved[key]
			end
		end
	end
	return condition
end

-- Why a tool won't work right now, or nil if it will.
function Maintenance.blocker(_tool, condition): string?
	if condition.broken then
		return "The engine is smoking and won't start."
	elseif condition.fuel and condition.fuel <= 0 then
		return "It sputtered out."
	elseif condition.flat then
		return "A tire is flat. It won't roll."
	elseif condition.line and condition.line <= 0 then
		return "The trimmer line is used up."
	end
	return nil
end

-- Soft tires drag: 1 when firm, down to 0.6 when nearly flat.
function Maintenance.tireFactor(condition): number
	if not condition.pressure then
		return 1
	end
	return 0.6 + 0.4 * math.clamp(condition.pressure / Maintenance.LowPressure, 0, 1)
end

-- How a tool's condition changes its work: (speed multiplier, finish quality multiplier).
function Maintenance.effects(condition): (number, number)
	local speed, quality = Maintenance.tireFactor(condition), 1
	if condition.sharpness then
		speed *= 0.8 + 0.2 * condition.sharpness
		quality *= 0.6 + 0.4 * condition.sharpness
	end
	return speed, quality
end

-- Things worth telling the player about a tool, without saying how to fix them.
function Maintenance.warnings(_tool, condition): { string }
	local list = {}
	if condition.broken then
		table.insert(list, "Engine is smoking and won't start")
	elseif condition.fuel then
		if condition.fuel <= 0 then
			table.insert(list, "Out of fuel")
		elseif condition.fuel < Maintenance.LowFuel then
			table.insert(list, "Running low on fuel")
		end
	end
	if condition.flat then
		table.insert(list, "Flat tire")
	elseif condition.pressure and condition.pressure < Maintenance.LowPressure then
		table.insert(list, "Tire looks soft")
	end
	if condition.sharpness and condition.sharpness < Maintenance.DullBlade then
		table.insert(list, "Cut is getting ragged")
	end
	if condition.line then
		if condition.line <= 0 then
			table.insert(list, "Out of trimmer line")
		elseif condition.line < Maintenance.LowLine then
			table.insert(list, "Trimmer line is running short")
		end
	end
	if condition.uses and condition.uses <= 0 then
		table.insert(list, "Used up")
	end
	return list
end

-- Wears a tool for `seconds` of use. `running` = engine on, `rolling` = moving on its wheels,
-- `cutting` = it did work this tick. `random` is a 0-1 number for the puncture roll.
function Maintenance.wear(
	tool,
	condition,
	seconds: number,
	running: boolean,
	rolling: boolean,
	cutting: boolean,
	random: number
)
	local wear = Maintenance.Wear
	if running and condition.fuel then
		local tank = if tool.engine == "TwoStroke" then wear.TwoStrokeFuel else wear.FourStrokeFuel
		condition.fuel = math.max(0, condition.fuel - seconds / tank)
	end
	if rolling and condition.pressure then
		condition.pressure = math.max(0, condition.pressure - seconds / wear.Pressure)
		if not condition.flat and random < Maintenance.PunctureChance * seconds then
			condition.flat = true
			condition.pressure = 0
		end
	end
	if cutting and condition.sharpness then
		condition.sharpness = math.max(0, condition.sharpness - seconds / wear.Blade)
	end
	if cutting and condition.line then
		condition.line = math.max(0, condition.line - seconds / wear.Line)
	end
end

-- Uses a supply on a tool. `has(id)` says whether another supply is available here.
-- Changes `condition` and returns whether it worked, what to tell the player, and the repair
-- cost (when a wrecked engine got fixed). Using up a consumable is the caller's job.
function Maintenance.apply(tool, condition, supplyId: string, has: (string) -> boolean): (boolean, string, number)
	local supply = Maintenance.Supplies[supplyId]
	local name = Tools.get(supplyId) and Tools.get(supplyId).name or supplyId
	if not supply then
		return false, "That won't work here.", 0
	end
	if supply.needs and not has(supply.needs) then
		return false, "You can't get the old one off with your bare hands.", 0
	end

	local action = supply.action
	if action == "Fuel" then
		if not Maintenance.burnsFuel(tool) then
			return false, "That won't work here.", 0
		end
		condition.fuel = 1
		if tool.engine ~= supply.fuel then
			condition.broken = true
			return true, `The {tool.name} coughs, smokes and dies.`, 0
		end
		return true, `Topped up the {tool.name}.`, 0
	elseif action == "Inflate" then
		if tool.tires ~= "Air" then
			return false, "That won't work here.", 0
		elseif condition.flat then
			return false, "The air hisses straight back out.", 0
		end
		condition.pressure = 1
		return true, `The {tool.name}'s tires are firm again.`, 0
	elseif action == "Patch" then
		if tool.tires ~= "Air" then
			return false, "That won't work here.", 0
		elseif not condition.flat then
			return false, "There's no puncture to fix.", 0
		end
		condition.flat = false
		return true, "Patched the puncture. The tire is still empty, though.", 0
	elseif action == "SwapTire" then
		if tool.tires ~= "Air" then
			return false, "That won't work here.", 0
		end
		condition.flat = false
		condition.pressure = 1
		return true, `Put a new tire on the {tool.name}.`, 0
	elseif action == "Repair" then
		if not condition.broken then
			return false, "Nothing needs fixing.", 0
		end
		condition.broken = false
		condition.fuel = 0
		local cost = math.max(Maintenance.MinRepairCost, math.floor(tool.price * Maintenance.RepairCost))
		return true, `Drained the bad fuel and cleaned out the {tool.name}'s engine.`, cost
	elseif action == "Sharpen" then
		if Maintenance.bladeOf(tool) ~= supply.blade then
			return false, "That won't work here.", 0
		end
		condition.sharpness = 1
		return true, `The {tool.name} is sharp again.`, 0
	elseif action == "SwapBlade" then
		if not Tools.hasVerb(tool, "Mow") or REEL_MOWERS[tool.id] then
			return false, "That won't work here.", 0
		end
		condition.sharpness = 1
		return true, `Bolted a new blade onto the {tool.name}.`, 0
	elseif action == "Reload" then
		if not Maintenance.usesLine(tool) then
			return false, "That won't work here.", 0
		end
		condition.line = 1
		return true, `Reloaded the {tool.name}.`, 0
	end
	return false, `You can't use the {name} like that.`, 0
end

return Maintenance
