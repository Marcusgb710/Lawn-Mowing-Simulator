-- Strip: the maths of a clean stripe, the pass your mower makes that the HUD cheers (GrassController
-- follows the mower and fires StripDone, HudController's Splash shows it). Pure numbers with no
-- requires, so scripts/check-mowing can run it by behaviour.
--
-- A pass is the stretch from the moment the mower starts mowing until it stops (or turns back). Its
-- heading is the way its first HEADING_SECONDS went, once the mower has moved HEADING_MIN_MOVE studs
-- (so one that sat still at first waits). How far it has gone is measured along that heading, not along
-- its path, so a U-turn is two passes and not one long one: once the mower comes back more than
-- TURN_BACK studs from its furthest point along the heading, `move` says the pass is over.
--
-- A stripe is a pass of at least LENGTH studs along its heading that was clean. Clean is judged from
-- a few facts the client can read about the mower when the pass ends (`Facts`): the mower stalled
-- (the server clears "Working" for a moment when its blade hits junk; the client sees nothing else of
-- a hit), is blocked, torn or you fell, and it was not just put away or a push mower stopping (a push
-- mower runs over nothing).

local Strip = {}

-- Studs along the heading for a pass to be a stripe.
Strip.LENGTH = 30
-- Seconds of the pass whose direction is its heading.
Strip.HEADING_SECONDS = 2
-- Studs the mower must have moved from its start before its way counts as a heading.
Strip.HEADING_MIN_MOVE = 4
-- Studs back from its furthest point along the heading that mean the mower has turned back.
Strip.TURN_BACK = 8

export type Pass = {
	startX: number,
	startZ: number,
	startedAt: number,
	headingX: number?,
	headingZ: number?,
	furthest: number,
	lastX: number,
	lastZ: number,
}

-- What the client can read about the mower when its pass ends.
export type Facts = {
	-- The tool is still in your character's hands (false when it was put away or you respawned).
	held: boolean,
	-- Your character fell.
	dead: boolean,
	-- The tool's "Blocked" is set (no fuel, a flat, no line, a wrecked engine).
	blocked: boolean,
	-- The tool's blade has torn ("Ragged").
	ragged: boolean,
	-- It is an engine mower (anything but a push mower).
	motorized: boolean,
	-- The tool's "Working" is on.
	working: boolean,
}

-- A new pass that starts at (x, z) at `now`.
function Strip.start(x: number, z: number, now: number): Pass
	return { startX = x, startZ = z, startedAt = now, furthest = 0, lastX = x, lastZ = z }
end

-- The mower is at (x, z) at `now`. Returns true when it has turned back, which ends the pass at this
-- point (the caller finishes it and starts another here).
function Strip.move(pass: Pass, x: number, z: number, now: number): boolean
	pass.lastX, pass.lastZ = x, z
	local dx, dz = x - pass.startX, z - pass.startZ
	local headingX, headingZ = pass.headingX, pass.headingZ
	if not (headingX and headingZ) then
		local distance = math.sqrt(dx * dx + dz * dz)
		if now - pass.startedAt < Strip.HEADING_SECONDS or distance < Strip.HEADING_MIN_MOVE then
			return false
		end
		headingX, headingZ = dx / distance, dz / distance
		pass.headingX, pass.headingZ = headingX, headingZ
	end
	local along = dx * headingX + dz * headingZ
	if pass.furthest - along > Strip.TURN_BACK then
		return true
	end
	pass.furthest = math.max(pass.furthest, along)
	return false
end

-- How far the pass went: along its heading, or in a straight line from its start while it has none.
function Strip.length(pass: Pass): number
	if pass.headingX then
		return pass.furthest
	end
	local dx, dz = pass.lastX - pass.startX, pass.lastZ - pass.startZ
	return math.sqrt(dx * dx + dz * dz)
end

-- Whether the pass that just ended had nothing bad in it.
function Strip.clean(facts: Facts): boolean
	if not facts.held then
		return true
	end
	if facts.dead or facts.blocked or facts.ragged then
		return false
	end
	-- Still in your hands but not working, and not a push mower: its blade hit something.
	if facts.motorized and not facts.working then
		return false
	end
	return true
end

-- Whether the pass that just ended is a stripe to cheer.
function Strip.cheers(pass: Pass, facts: Facts): boolean
	return Strip.length(pass) >= Strip.LENGTH and Strip.clean(facts)
end

return Strip
