-- The pay breakdown after a job, in dollars: what the job paid, then what the finish, speed, crew,
-- curb appeal, a customer won back from TurfKing and the damage each added or took off, then the
-- customer's tip, adding up to what you earned. JobService works the pay out as one sum
-- (GameConfig.jobPay); this splits its result back into lines for the screen (HudController).
-- No Roblox requires, so scripts/check-gui.luau can test it with Lune.

local PayBreakdown = {}

export type Line = { label: string, amount: number }

local function round(value: number): number
	return math.floor(value + 0.5)
end

-- `result` is a finished job's result (JobService), `weights` how much that customer cared about
-- the finish and about speed (Jobs.Preferences). Returns the lines and the total they add up to:
-- your share, which is what you were paid, and the tip the customer left on top of it, if any.
function PayBreakdown.lines(result, weights: { quality: number, time: number }): ({ Line }, number)
	local base = result.basePay
	local fit = base * result.toolFit
	local quality, speed = result.qualityMultiplier, result.speedMultiplier
	local performance = fit * (weights.quality * quality + weights.time * speed)
	local speedPart = fit * weights.time * (speed - 1)
	-- The finish takes whatever else the customer's weights make of it.
	local finishPart = performance - fit - speedPart
	local business = result.crewBonus * result.truckBonus * result.businessBonus
	local curb = result.curbBonus or 1
	local crewPart = performance * (business - 1)
	local curbPart = performance * business * (curb - 1)
	local earned = performance * business * curb
	-- Pay never goes below nothing, so damage only takes what there was.
	local damage = math.min(result.penalty or 0, earned)
	local wonBack = result.wonBack or 0

	local lines: { Line } = {
		{ label = "Job pay", amount = base },
		{ label = "Tools for the job", amount = round(fit - base) },
		{ label = "Finish quality", amount = round(finishPart) },
		{ label = "Speed bonus", amount = round(speedPart) },
		{ label = "Crew, truck and business", amount = round(crewPart) },
		{ label = "Curb appeal", amount = round(curbPart) },
		{ label = "Won from TurfKing", amount = wonBack },
		{ label = "Damage and junk", amount = -round(damage) },
	}
	-- Rounding each line can leave a dollar or two over or under: the finish takes it (or the job
	-- pay, when there's no finish line), so the lines add up to exactly what was paid.
	local sum = 0
	for _, line in lines do
		sum += line.amount
	end
	local over = (result.total or sum) - sum
	if over ~= 0 then
		local into = if lines[3].amount ~= 0 then lines[3] else lines[1]
		into.amount += over
	end
	local share = result.share or result.total or sum
	if share ~= (result.total or sum) then
		table.insert(lines, { label = "Split with your crew", amount = share - (result.total or sum) })
	end

	-- Only the lines that did something (the job pay always shows).
	local shown = {}
	for index, line in lines do
		if index == 1 or line.amount ~= 0 then
			table.insert(shown, line)
		end
	end
	-- The customer's tip, on top of the share (the stars set it, JobService pays it separately), and
	-- in the total: it's money you earned too.
	local tip = result.tip or 0
	if tip > 0 then
		table.insert(shown, { label = `Tip from {result.customer or "the customer"}`, amount = tip })
		share += tip
	end
	return shown, share
end

return PayBreakdown
