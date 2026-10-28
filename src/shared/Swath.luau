-- What a mower has cut on a lawn, as a log of segments that server and client share.
--
-- Every sweep of a mower's deck and every snip of the shears is a Segment, in lawn-local studs (the
-- same space as LawnGrid: the origin is the lawn's front-left corner, X runs across and Z along).
-- The server keeps a log per lawn and sends new segments to the clients, which paint them onto the
-- lawn. Sweeps that carry straight on from the one before are merged, so a long pass is one entry
-- however many ticks it took.
--
-- This needs nothing from Roblox, so it loads in Lune too: colours are plain { r, g, b } tables
-- for the client to turn into Color3.

-- A sweep runs from (fromX, fromZ) to (toX, toZ), where the deck's center was at each end, with the
-- deck halfWidth studs either side; what it cut reaches LawnGrid.DeckReach further at each end. One
-- that went nowhere is a mower standing still, which cut the deck's own rectangle, lying along +Z.
-- A snip sets radius instead (and halfWidth is 0), and is a round patch at its from spot. shade is
-- one of "Light", "Dark" and "Flat" (see Swath.shade), and ragged is a dull blade's torn cut.
export type Segment = {
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number,
	radius: number?,
	shade: string,
	ragged: boolean,
}

local Swath = {}

-- The colour key for torn grass (a dull blade's cut): it has a look of its own, beside the three shades.
Swath.RAGGED = "Ragged"

-- RGB, 0 to 255. These are the mock's colours and may be tuned.
Swath.Colors = {
	Light = { 134, 212, 87 },
	Flat = { 114, 191, 74 },
	Dark = { 90, 168, 58 },
	[Swath.RAGGED] = { 150, 170, 80 },
}

-- A mower heading more along +Z than this (the dot product with it, 0.5 being 60 degrees off) cuts
-- a light stripe, and one heading more against +Z cuts a dark stripe.
local STRIPE_DOT = 0.5
-- A sweep carries on from the one before when it starts within this many studs of where that one
-- ended and is heading within this many degrees of it, so the wobble from one tick to the next
-- still counts as one pass.
local JOIN_DISTANCE = 0.25
local JOIN_COS = math.cos(math.rad(2))

-- The stripe a mower leaves going this way: light going up the lawn (+Z), dark coming back down,
-- flat across it, like the stripes a real mower rolls into the grass. A mower not going anywhere
-- leaves flat grass.
function Swath.shade(dx: number, dz: number): string
	local length = math.sqrt(dx * dx + dz * dz)
	if length == 0 then
		return "Flat"
	end
	local alongZ = dz / length
	if alongZ > STRIPE_DOT then
		return "Light"
	elseif alongZ < -STRIPE_DOT then
		return "Dark"
	end
	return "Flat"
end

-- Whether `segment` carries straight on from `last`, the end of the log, so they can be one.
local function carriesOn(last: Segment, segment: Segment): boolean
	if last.radius ~= nil or segment.radius ~= nil then
		return false
	end
	if last.shade ~= segment.shade or last.ragged ~= segment.ragged or last.halfWidth ~= segment.halfWidth then
		return false
	end

	local gapX, gapZ = segment.fromX - last.toX, segment.fromZ - last.toZ
	if gapX * gapX + gapZ * gapZ > JOIN_DISTANCE * JOIN_DISTANCE then
		return false
	end

	local lastX, lastZ = last.toX - last.fromX, last.toZ - last.fromZ
	local newX, newZ = segment.toX - segment.fromX, segment.toZ - segment.fromZ
	local lastLength = math.sqrt(lastX * lastX + lastZ * lastZ)
	local newLength = math.sqrt(newX * newX + newZ * newZ)
	-- A segment with no length has no direction to agree with.
	if lastLength == 0 or newLength == 0 then
		return false
	end
	return (lastX * newX + lastZ * newZ) / (lastLength * newLength) >= JOIN_COS
end

-- Adds a segment to the end of the log, or stretches the last one when this carries straight on
-- from it. Returns whether it stretched the last one. A snip, and a sweep that went nowhere (a
-- mower standing still cuts once, under its deck), always stand alone: they never stretch the last
-- one and nothing stretches them. The log keeps its own copy, so the caller may reuse the table.
function Swath.append(log: { Segment }, segment: Segment): boolean
	local last = log[#log]
	if last ~= nil and carriesOn(last, segment) then
		last.toX, last.toZ = segment.toX, segment.toZ
		return true
	end
	table.insert(log, table.clone(segment))
	return false
end

-- A segment as a flat array, for sending to clients: from, to, half width, radius (0 for a sweep),
-- shade, ragged. An array rather than a dictionary, so the field names do not go out with every
-- segment.
function Swath.pack(segment: Segment): { number | string | boolean }
	return {
		segment.fromX,
		segment.fromZ,
		segment.toX,
		segment.toZ,
		segment.halfWidth,
		segment.radius or 0,
		segment.shade,
		segment.ragged,
	}
end

function Swath.unpack(packed: { number | string | boolean }): Segment
	local radius = packed[6] :: number
	return {
		fromX = packed[1] :: number,
		fromZ = packed[2] :: number,
		toX = packed[3] :: number,
		toZ = packed[4] :: number,
		halfWidth = packed[5] :: number,
		radius = if radius ~= 0 then radius else nil,
		shade = packed[7] :: string,
		ragged = packed[8] :: boolean,
	}
end

return Swath
