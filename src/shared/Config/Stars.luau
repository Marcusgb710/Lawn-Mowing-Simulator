-- How a finished job earns its stars and its tip (docs/superpowers/specs/2026-10-29-busy-season-design.md,
-- 1d). `performance` is the pay formula's own factor, the blend of the quality and speed
-- multipliers against what the customer wants, where 1.0 means "as expected". Three stars take
-- `ThreeStarAt` or better and no penalty (a flower or gnome hit, junk left or chewed); two take
-- `TwoStarAt`; anything below is one. The customer tips a share of the pay by stars. Nothing here
-- keeps state: the stars a job earned are saved elsewhere.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

local Stars = {}

Stars.ThreeStarAt = 1.1
Stars.TwoStarAt = 0.9

-- The share of a job's pay the customer tips, indexed by stars (one, two, three).
Stars.TipRates = { 0, 0.05, 0.15 }

-- 1 to 3 stars for a job's performance. A penalty keeps it from three, never from two.
function Stars.of(performance: number, penalized: boolean): number
	if performance >= Stars.ThreeStarAt and not penalized then
		return 3
	elseif performance >= Stars.TwoStarAt then
		return 2
	end
	return 1
end

-- The share of the pay tipped for `stars` (0.15, 0.05 or 0).
function Stars.tipRate(stars: number): number
	return Stars.TipRates[math.clamp(math.floor(stars), 1, #Stars.TipRates)]
end

return Stars
