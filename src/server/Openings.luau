-- Parts of a vehicle that open (docs/GAME_DESIGN.md, "Immersion"). Each is its own part, named
-- after its model and built closed:
--   <Id>__Tailgate          a pickup's tailgate: swings down about its pivot (on the bottom
--                           hinge), rotating about its X axis
--   EquipmentTrailer__Ramp  swings down the same way until its end reaches the ground (also
--   LandscapeTrailer__RampDoor)
--   <Id>__RearDoor          a box truck's back door: rolls up
--   <Id>__DriverDoor        the driver's door (on the left): swings open about its own Y axis,
--                           its pivot on the hinge; <Id>__DriverDoorGlass swings with it
-- Openings.set(model, true) opens the tailgates, ramps and rear doors in a model,
-- Openings.set(model, false) closes them again; pass a kind ("DriverDoor") for just that.
-- Building doors (<Id>__Door, <Id>__GarageDoor) are modelled open and stay as they are.

local TweenService = game:GetService("TweenService")

local Openings = {}

local SUFFIXES = {
	__Tailgate = "Tailgate",
	__Ramp = "Ramp",
	__RampDoor = "Ramp",
	__RearDoor = "RollUp",
	__DriverDoor = "DriverDoor",
	__DriverDoorGlass = "DriverDoor",
}
local TAILGATE_ANGLE = math.rad(90)
-- The driver's door swings out this far (it's on the left, so its back edge goes to -X).
local DRIVER_DOOR_ANGLE = math.rad(-70)
-- A ramp swings at least this far and at most this far (it stops on the ground in between).
local RAMP_MIN, RAMP_MAX = math.rad(90), math.rad(165)
-- How much of its height a roll-up door rises.
local ROLL_UP = 0.92

type Opening = {
	part: BasePart,
	kind: string,
	closed: CFrame, -- the part's pivot when closed, relative to the model's pivot
	hinge: CFrame, -- what it turns about, relative to the model's pivot
	angle: number, -- how far it swings (tailgates and ramps about X, doors about Y)
	rise: number, -- how far it rolls up (roll-up doors)
	amount: number, -- how open it is now, 0-1
	tween: Tween?,
}

-- [Model] = its openings
local byModel = setmetatable({}, { __mode = "k" })

function Openings.kindOf(name: string): string?
	for suffix, kind in SUFFIXES do
		if string.sub(name, -#suffix) == suffix then
			return kind
		end
	end
	return nil
end

-- The part's corners, relative to `frame`: (min, max).
local function extents(part: BasePart, frame: CFrame): (Vector3, Vector3)
	local low = Vector3.one * math.huge
	local high = -Vector3.one * math.huge
	local half = part.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return low, high
end

local function describe(model: Model, part: BasePart, kind: string, hinge: CFrame?): Opening
	local pivot = part:GetPivot()
	local low, high = extents(part, pivot)
	local opening: Opening = {
		part = part,
		kind = kind,
		closed = model:GetPivot():ToObjectSpace(pivot),
		hinge = model:GetPivot():ToObjectSpace(hinge or pivot),
		angle = 0,
		rise = 0,
		amount = 0,
		tween = nil,
	}
	if kind == "Tailgate" then
		opening.angle = TAILGATE_ANGLE
	elseif kind == "Ramp" then
		-- Down until the far end touches the ground under the model.
		local boxCFrame, boxSize = model:GetBoundingBox()
		local height = pivot.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
		local length = math.max(high.Y, 0.1)
		opening.angle = math.clamp(math.acos(math.clamp(-height / length, -1, 1)), RAMP_MIN, RAMP_MAX)
	elseif kind == "RollUp" then
		opening.rise = (high.Y - low.Y) * ROLL_UP
	elseif kind == "DriverDoor" then
		opening.angle = DRIVER_DOOR_ANGLE
	end
	return opening
end

local function openingsOf(model: Model): { Opening }
	local cached = byModel[model]
	if cached then
		return cached
	end
	local list = {}
	-- A door's glass turns about the door's hinge, so they stay together.
	local doorHinge = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -12) == "__DriverDoor" then
			doorHinge[string.sub(descendant.Name, 1, -13)] = descendant:GetPivot()
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local kind = Openings.kindOf(descendant.Name)
			if kind then
				local hinge = nil
				if string.sub(descendant.Name, -17) == "__DriverDoorGlass" then
					hinge = doorHinge[string.sub(descendant.Name, 1, -18)]
				end
				table.insert(list, describe(model, descendant, kind, hinge))
			end
		end
	end
	byModel[model] = list
	return list
end

local function pose(model: Model, opening: Opening, amount: number)
	opening.amount = amount
	local closed = model:GetPivot() * opening.closed
	local target
	if opening.kind == "RollUp" then
		target = closed + closed.UpVector * (opening.rise * amount)
	else
		local hinge = model:GetPivot() * opening.hinge
		local turn = if opening.kind == "DriverDoor"
			then CFrame.Angles(0, opening.angle * amount, 0)
			else CFrame.Angles(opening.angle * amount, 0, 0)
		target = hinge * turn * hinge:ToObjectSpace(closed)
	end
	opening.part:PivotTo(target)
end

-- Whether the model has anything that opens.
function Openings.has(model: Model): boolean
	return #openingsOf(model) > 0
end

-- Opens (or closes) the tailgates, ramps and rear doors in `model` (or only the openings of
-- `kind`), over `seconds` (at once if 0 or nil).
function Openings.set(model: Model, open: boolean, seconds: number?, kind: string?)
	local goal = if open then 1 else 0
	for _, opening in openingsOf(model) do
		if (kind and opening.kind ~= kind) or (not kind and opening.kind == "DriverDoor") then
			continue
		end
		if opening.tween then
			opening.tween:Cancel()
			opening.tween = nil
		end
		if opening.amount == goal then
			continue
		end
		if not seconds or seconds <= 0 then
			pose(model, opening, goal)
			continue
		end
		local value = Instance.new("NumberValue")
		value.Value = opening.amount
		local connection = value.Changed:Connect(function(amount)
			if opening.part.Parent then
				pose(model, opening, amount)
			end
		end)
		local tween = TweenService:Create(
			value,
			TweenInfo.new(seconds * math.abs(goal - opening.amount), Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Value = goal }
		)
		opening.tween = tween
		tween.Completed:Once(function()
			connection:Disconnect()
			value:Destroy()
			if opening.tween == tween then
				opening.tween = nil
			end
		end)
		tween:Play()
	end
end

return Openings
