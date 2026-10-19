-- Where things go in a truck and its trailer (docs/GAME_DESIGN.md, "Immersion"), the same on
-- the server (the real tools) and the client (the ghost preview of where you're aiming):
--   "BedArea" parts   a grid of cells each (BedGrid), sharing their vehicle's space
--   "BaySpot" parts   where a ride-on machine parks, on equipment trailers
-- The server numbers the beds (attribute BedIndex) and writes each one's cell count (Cells)
-- and taken cells (Taken, "1,2,5") on it, so the client can preview without asking.

local Assets = require(script.Parent.Assets)
local BedGrid = require(script.Parent.BedGrid)

local BedLayout = {}

-- How tools lie on their cells: machines and supplies stand, long and power tools lie along the
-- bed, hand tools across it.
local STANDING = { FloorManual = true, FloorEngine = true, Supply = true }
local LENGTHWISE = { Long = true, HangingPower = true }

export type Bed = { part: BasePart, grid: BedGrid.Grid, index: number }

-- The truck's beds (then its trailer's), each with its share of the vehicle's space.
function BedLayout.beds(truck: Model, truckSpace: number, trailerSpace: number): { Bed }
	local trailer = truck:FindFirstChild("Trailer")
	local truckBeds, trailerBeds = {}, {}
	for _, descendant in truck:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "BedArea" then
			table.insert(if trailer and descendant:IsDescendantOf(trailer) then trailerBeds else truckBeds, descendant)
		end
	end
	local beds = {}
	for _, group in { { parts = truckBeds, space = truckSpace }, { parts = trailerBeds, space = trailerSpace } } do
		local count = #group.parts
		for number, part in group.parts do
			-- Split the space as evenly as it goes; the first beds get any left over.
			local share = group.space // count + (if number <= group.space % count then 1 else 0)
			table.insert(beds, { part = part, grid = BedGrid.new(share), index = #beds + 1 })
		end
	end
	return beds
end

-- The beds as the server numbered them (BedIndex and Cells attributes), for the client.
function BedLayout.read(truck: Model): { Bed }
	local beds = {}
	for _, descendant in truck:GetDescendants() do
		local index = descendant:GetAttribute("BedIndex")
		local cells = descendant:GetAttribute("Cells")
		if descendant:IsA("BasePart") and typeof(index) == "number" and typeof(cells) == "number" then
			beds[index] = { part = descendant, grid = BedGrid.new(cells), index = index }
		end
	end
	return beds
end

-- The taken cells of a bed ({ [cell] = true }), from its Taken attribute.
function BedLayout.taken(bed: BasePart): { [number]: boolean }
	local taken = {}
	local text = bed:GetAttribute("Taken")
	if typeof(text) == "string" then
		for number in string.gmatch(text, "%d+") do
			taken[tonumber(number) :: number] = true
		end
	end
	return taken
end

-- Lays a tool's display model on its cells of a bed.
function BedLayout.place(display: Model, bed: Bed, cells: { number }, sizeClass: string)
	local part = bed.part
	local x, z = BedGrid.center(bed.grid, cells, part.Size.X, part.Size.Z)
	local top = part.CFrame * CFrame.new(x, part.Size.Y / 2, z)
	if STANDING[sizeClass] then
		Assets.placeOnGround(display, top)
		-- Its pivot is where the hand holds it (a push mower's handlebar), so centre the model
		-- itself on its cells, or the deck pokes out past them (into the cab, on the front cells).
		local box = display:GetBoundingBox()
		local off = top:PointToObjectSpace(box.Position)
		display:PivotTo(display:GetPivot() - top:VectorToWorldSpace(Vector3.new(off.X, 0, off.Z)))
		return
	end
	local along = if LENGTHWISE[sizeClass] then top.LookVector else top.RightVector
	local _, _, thin = Assets.align(display, top.Position, along, top.UpVector)
	display:PivotTo(display:GetPivot() + top.UpVector * (thin / 2))
end

-- Which cell of a bed a ray (from the camera) points at, if it crosses the bed's top within
-- `reach`: (column, row).
function BedLayout.aim(bed: Bed, origin: Vector3, direction: Vector3, reach: number): (number?, number?)
	local part = bed.part
	local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	local normal = top.UpVector
	local facing = direction:Dot(normal)
	if facing > -1e-3 then
		return nil, nil
	end
	local distance = (top.Position - origin):Dot(normal) / facing
	if distance < 0 or distance > reach then
		return nil, nil
	end
	local hit = top:PointToObjectSpace(origin + direction * distance)
	-- A little margin around the bed, so aiming at its edge still counts.
	if math.abs(hit.X) > part.Size.X / 2 + 0.5 or math.abs(hit.Z) > part.Size.Z / 2 + 0.5 then
		return nil, nil
	end
	return BedGrid.cellAt(bed.grid, hit.X, hit.Z, part.Size.X, part.Size.Z)
end

return BedLayout
