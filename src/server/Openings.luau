-- Parts of a vehicle that open (docs/GAME_DESIGN.md, "Immersion"). Each is its own part, named
-- after its model and built closed:
--   <Id>__Tailgate          a pickup's tailgate: swings down about its pivot (on the bottom
--                           hinge), rotating about its X axis
--   EquipmentTrailer__Ramp  swings down the same way until its end reaches the ground (also
--   LandscapeTrailer__RampDoor)
--   <Id>__RearDoor          a box truck's back door: rolls up
-- Openings.set(model, true) opens every one of them in a model, Openings.set(model, false)
-- closes them again. Building doors (<Id>__Door, <Id>__GarageDoor) are modelled open and stay
-- as they are.

local TweenService = game:GetService("TweenService")

local Openings = {}

local SUFFIXES = {
	__Tailgate = "Tailgate",
	__Ramp = "Ramp",
	__RampDoor = "Ramp",
	__RearDoor = "RollUp",
}
local TAILGATE_ANGLE = math.rad(90)
-- A ramp swings at least this far and at most this far (it stops on the ground in between).
local RAMP_MIN, RAMP_MAX = math.rad(90), math.rad(165)
-- How much of its height a roll-up door rises.
local ROLL_UP = 0.92

type Opening = {
	part: BasePart,
	kind: string,
	closed: CFrame, -- the part's pivot when closed, relative to the model's pivot
	angle: number, -- how far it swings down (tailgates and ramps)
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

local function describe(model: Model, part: BasePart, kind: string): Opening
	local pivot = part:GetPivot()
	local low, high = extents(part, pivot)
	local opening: Opening = {
		part = part,
		kind = kind,
		closed = model:GetPivot():ToObjectSpace(pivot),
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
	end
	return opening
end

local function openingsOf(model: Model): { Opening }
	local cached = byModel[model]
	if cached then
		return cached
	end
	local list = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local kind = Openings.kindOf(descendant.Name)
			if kind then
				table.insert(list, describe(model, descendant, kind))
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
		target = closed * CFrame.Angles(opening.angle * amount, 0, 0)
	end
	opening.part:PivotTo(target)
end

-- Whether the model has anything that opens.
function Openings.has(model: Model): boolean
	return #openingsOf(model) > 0
end

-- Opens (or closes) everything in `model` that opens, over `seconds` (at once if 0 or nil).
function Openings.set(model: Model, open: boolean, seconds: number?)
	local goal = if open then 1 else 0
	for _, opening in openingsOf(model) do
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
