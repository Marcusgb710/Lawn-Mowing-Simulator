-- TurfKing, Gloria's lawn franchise and your business rival (docs/STORY.md, act 2): the rules for
-- it taking jobs off your board and for customers you win back from it. TurfKingService (on the
-- server) uses them; the lines it says are in Config/Story.luau.
--
-- This file has no requires, so scripts/check-story.luau can test it with Lune.

local TurfKing = {}

-- It starts taking jobs in this act (act 2, "TurfKing").
TurfKing.FromAct = 2

-- "Taken by TurfKing": while you're at your shop's computer, a job card on your board can flip
-- to taken, and you can't accept it. It happens at most once every `FlipEveryJobs` jobs you
-- finish, with a `FlipChance` each time you walk up to the computer, `FlipDelay` seconds (a
-- random number between the two) after you get there, so you see it happen. Never the starter
-- job, never a job someone's accepted, and only a job you could take.
TurfKing.FlipEveryJobs = 3
TurfKing.FlipChance = 0.5
TurfKing.FlipDelay = { 4, 9 }

-- Beating TurfKing on quality: a customer who wanted a perfect finish (preference "Quality")
-- and got at least `WinFinish` is yours for good. The first time each customer is won back they
-- text you and pay a bonus: `WinBonusShare` of the job's pay, between `WinBonusMin` and
-- `WinBonusMax`, rounded to $5. It's split with the crew like the rest of the pay.
TurfKing.WinFinish = 0.9
TurfKing.WinBonusShare = 0.2
TurfKing.WinBonusMin = 10
TurfKing.WinBonusMax = 100

-- Whether TurfKing may take a job off the board of someone in act `act` who's finished
-- `jobsCompleted` jobs, `flippedAt` being how many they'd finished at its last take (nil: never).
function TurfKing.canFlip(act: number, jobsCompleted: number, flippedAt: number?): boolean
	if act < TurfKing.FromAct then
		return false
	end
	return flippedAt == nil or jobsCompleted - flippedAt >= TurfKing.FlipEveryJobs
end

-- The offers on `board` TurfKing could take from this player: not the starter job (kind
-- "StarterGear"), not already taken from them (`taken`, by offer id), not accepted (`accepted`,
-- by offer id) and not above their `level`.
function TurfKing.candidates(
	board: { any },
	taken: { [string]: boolean }?,
	accepted: { [string]: boolean }?,
	level: number
): { any }
	local list = {}
	for _, offer in board do
		if
			offer.kind ~= "StarterGear"
			and not (taken and taken[offer.id])
			and not (accepted and accepted[offer.id])
			and (offer.minLevel or 1) <= level
		then
			table.insert(list, offer)
		end
	end
	return list
end

-- Whether a finished job wins its customer back from TurfKing (in TurfKing's acts).
function TurfKing.winsBack(act: number, preference: string?, quality: number?): boolean
	return act >= TurfKing.FromAct and preference == "Quality" and (quality or 0) >= TurfKing.WinFinish
end

-- The bonus a won-back customer pays on a job that paid `payout`.
function TurfKing.bonus(payout: number): number
	local amount = math.clamp(payout * TurfKing.WinBonusShare, TurfKing.WinBonusMin, TurfKing.WinBonusMax)
	return math.floor(amount / 5 + 0.5) * 5
end

return TurfKing
