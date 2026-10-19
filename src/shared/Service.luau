-- Hands-on maintenance (docs/GAME_DESIGN.md, "Immersion", "Hands-on maintenance"): what doing
-- something to a tool you've set down to work on does, with what's in your hands. The rules for
-- what each supply does to a tool's condition are in Maintenance.luau; this adds the steps
-- around them (a mower's blade has to come off before it can be sharpened, a wheel before the
-- spare goes on) and says what each one is called. Like the HUD, nothing here says which supply
-- fixes what: the reasons only say what's in the way.

local Maintenance = require(script.Parent.Config.Maintenance)

local Service = {}

-- How long the wrench steps take (a blade or wheel off or back on), in seconds.
Service.StepSeconds = 3

export type Spot = "Floor" | "Vise"
export type State = { bladeOff: boolean?, wheelOff: boolean? }
export type Step = {
	-- "Apply" uses the supply (Maintenance.apply); the others take a blade or wheel off or put it on.
	kind: string,
	text: string,
	seconds: number,
}

-- Where a tool goes to be worked on: hand and long tools in the vise, machines on the floor.
function Service.spotFor(tool): Spot
	return if tool.sizeClass == "Hand" or tool.sizeClass == "Long" then "Vise" else "Floor"
end

-- Whether its blade has to come off before it can be sharpened or swapped: a machine's heavy
-- blade, on the floor. Edges in the vise are worked on where they are.
function Service.bladeComesOff(tool, spot: Spot): boolean
	return spot == "Floor" and Maintenance.bladeOf(tool) == "Heavy" and not Maintenance.isReelMower(tool)
end

-- Whether it can be picked back up as it is.
function Service.canPickUp(state: State): (boolean, string?)
	if state.bladeOff then
		return false, "Bolt the blade back on first."
	elseif state.wheelOff then
		return false, "Put a wheel back on first."
	end
	return true, nil
end

local SUPPLY_TEXT = {
	GasCan = "Pour in the fuel",
	MixGasCan = "Pour in the fuel",
	FootPump = "Pump up the tire",
	ElectricInflator = "Pump up the tire",
	AirCompressor = "Fill the tire with shop air",
	TirePatchKit = "Plug the puncture",
	SpareTire = "Put the spare on",
	BladeFile = "File the edge",
	SharpeningStone = "Hone the edge",
	BenchGrinder = "Sharpen it on the grinder",
	SpareMowerBlade = "Fit the new blade",
	TrimmerLine = "Wind on new line",
}

local function apply(supplyId: string, text: string?): Step
	local supply = Maintenance.Supplies[supplyId]
	return { kind = "Apply", text = text or SUPPLY_TEXT[supplyId] or "Use it", seconds = supply.seconds }
end

local function wrench(kind: string, text: string): Step
	return { kind = kind, text = text, seconds = Service.StepSeconds }
end

-- What a supply tops up, and what to say when it's already full (a sharp blade, a full tank).
local TOPS_UP = {
	Fuel = { field = "fuel", reason = "The tank's already full." },
	Inflate = { field = "pressure", reason = "Its tires are already firm." },
	Sharpen = { field = "sharpness", reason = "It's already sharp." },
	Reload = { field = "line", reason = "The spool's already full." },
}

local function alreadyFull(action: string, condition): string?
	local tops = TOPS_UP[action]
	local value = tops and condition[tops.field]
	if typeof(value) == "number" and value >= 1 then
		return tops.reason
	end
	return nil
end

-- Uses a supply that tops something up, unless there's nothing to top up.
local function topUp(supplyId: string, condition): (Step?, string?)
	local full = alreadyFull(Maintenance.Supplies[supplyId].action, condition)
	if full then
		return nil, full
	end
	return apply(supplyId), nil
end

-- What using `supplyId` on `tool` does right now. `spot` is where it's set down, `state` what's
-- off it, and `part` what you're looking at ("Wheel", "Spool" or nil). Returns the step, or nil
-- and what's in the way.
function Service.step(tool, condition, supplyId: string, state: State, spot: Spot, part: string?): (Step?, string?)
	local supply = Maintenance.Supplies[supplyId]
	if not supply then
		return nil, "That won't help here."
	end
	local action = supply.action
	local airTires = tool.tires == "Air"

	-- Halfway through a job, only what finishes it (or undoes it) works.
	if state.bladeOff then
		if supplyId == "WrenchSet" then
			return wrench("BladeOn", "Bolt the blade back on"), nil
		elseif action == "Sharpen" and Maintenance.bladeOf(tool) == supply.blade then
			return topUp(supplyId, condition)
		elseif action == "SwapBlade" and Maintenance.takesSpareBlade(tool) then
			return apply(supplyId), nil
		elseif action == "Sharpen" or action == "SwapBlade" then
			return nil, "That won't help here."
		end
		return nil, "Bolt the blade back on first."
	elseif state.wheelOff then
		if supplyId == "WrenchSet" then
			return wrench("WheelOn", "Put the wheel back on"), nil
		elseif action == "SwapTire" then
			return apply(supplyId), nil
		end
		return nil, "Put a wheel back on first."
	end

	if action == "Fuel" then
		if not Maintenance.burnsFuel(tool) then
			return nil, "There's no tank on it."
		end
		return topUp(supplyId, condition)
	elseif action == "Inflate" or action == "Patch" then
		if not airTires then
			return nil, "Its tires don't take air."
		end
		return topUp(supplyId, condition)
	elseif action == "SwapTire" then
		if not airTires then
			return nil, "Its tires don't take air."
		end
		return nil, "Get the wheel off first."
	elseif action == "Repair" then
		if condition.broken then
			return apply(supplyId, "Fix the engine"), nil
		elseif airTires and part == "Wheel" then
			return wrench("WheelOff", "Take the wheel off"), nil
		elseif Service.bladeComesOff(tool, spot) then
			return wrench("BladeOff", "Take the blade off"), nil
		elseif airTires then
			return wrench("WheelOff", "Take the wheel off"), nil
		end
		return nil, "There's nothing to unbolt on it."
	elseif action == "Sharpen" then
		if not Maintenance.bladeOf(tool) then
			return nil, "There's no edge on it to sharpen."
		elseif Maintenance.bladeOf(tool) ~= supply.blade then
			-- Like the HUD, this doesn't say what would work.
			return nil, "That won't help here."
		elseif alreadyFull(action, condition) then
			return nil, alreadyFull(action, condition)
		elseif Service.bladeComesOff(tool, spot) then
			return nil, "Get the blade off first."
		end
		return apply(supplyId), nil
	elseif action == "SwapBlade" then
		if not (Maintenance.takesSpareBlade(tool) and Service.bladeComesOff(tool, spot)) then
			return nil, "That won't go on it."
		end
		return nil, "Get the blade off first."
	elseif action == "Reload" then
		if not Maintenance.usesLine(tool) then
			return nil, "There's no spool on it."
		end
		return topUp(supplyId, condition)
	end
	return nil, "That won't help here."
end

-- What a tool's part is, for the steps that care: "Wheel" for wheels and tires, "Spool" for a
-- trimmer head, nil for the rest.
-- Kit parts are named `<Asset>__Wheel...`, `__Tire...` and `__Spool...` (the same names that make
-- them spin, see Assets); a placeholder's are just "Wheel" and "Spool".
function Service.partKind(name: string): string?
	if string.find(name, "__Wheel", 1, true) or string.find(name, "__Tire", 1, true) or name == "Wheel" then
		return "Wheel"
	elseif string.find(name, "__Spool", 1, true) or name == "Spool" then
		return "Spool"
	end
	return nil
end

-- The supplies a crew can use that aren't carried: the building's own machines.
function Service.isFixture(supplyId: string): boolean
	return Maintenance.isStationary(supplyId)
end

return Service
