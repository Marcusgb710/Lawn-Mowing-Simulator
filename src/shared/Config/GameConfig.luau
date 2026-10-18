-- Numbers you'll probably want to tweak while balancing the game.

local GameConfig = {
	StartingMoney = 0,
	MaxCrewSize = 4,

	-- How long the truck "drive" cutscene lasts, in seconds.
	TravelTime = 6,
	-- How long the crew stays at the house after finishing before driving back.
	ReturnDelay = 5,

	JobBoardSize = 6,
	-- The job board always keeps this many homeowner jobs (small yard and garden work) on it.
	HomeownerJobsOnBoard = 4,
	-- Untaken jobs get swapped out this often (seconds).
	JobBoardRefreshTime = 180,

	-- A task counts as finished at this fraction, so nobody has to hunt for the last tile of grass.
	CompletionThreshold = 0.95,
	-- Each extra crew member adds this much to the total payout (before it's split).
	CrewBonusPerMember = 0.15,

	-- Pay goes up for beating a job's par time and down for going over it:
	-- finishing in half the par time gives the full bonus, taking twice as long gives the full penalty.
	MaxSpeedBonus = 0.25,
	MaxSlowPenalty = 0.5,
	-- Running over a flower patch or gnome takes this fraction of the job's pay (at least MinDamagePenalty).
	DamagePenalty = 0.1,
	MinDamagePenalty = 5,

	-- Lawn generation
	TileSize = 4,
	TallGrassHeight = 1.5,
	MowedGrassHeight = 0.3,

	-- Job sites are built far away from town, one slot per active job.
	JobSiteOrigin = Vector3.new(0, 0, 3000),
	JobSiteSpacing = 500,

	-- Selling a tool back to the hardware store returns this fraction of its price.
	SellRefund = 0.5,
	-- Seconds until something you order on the shop computer is delivered to the shop (at once if
	-- you're away on a job when you order).
	DeliveryTime = 15,

	-- How often tools do work, in seconds.
	WorkTickRate = 0.1,
	DefaultWalkSpeed = 16,

	-- First person (see CameraController and ArmsController).
	Camera = {
		FieldOfView = 75,
		-- Camera motion, both on by default. Players can switch it off with the "Motion" button
		-- (or V); set these to false to switch it off for everyone.
		HeadBob = true, -- a gentle bob while walking
		EngineShake = true, -- a slight shake while a gas engine you're using runs
	},

	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120,
}

-- How the finish (0-1) affects pay: 0.75, a decent residential mow, pays 1x.
-- A near-perfect finish pays up to 1.3x and a poor one as little as 0.5x.
function GameConfig.qualityMultiplier(quality: number): number
	return math.clamp(1 + (quality - 0.75) * 1.5, 0.5, 1.3)
end

-- Pay for a finished job, before it's split between the crew:
--   base pay x tool fit x (quality and time, weighted by what the customer wants)
--   x crew/truck/business bonuses, minus damage.
function GameConfig.jobPay(job: {
	basePay: number,
	toolFit: number,
	quality: number,
	elapsed: number,
	parTime: number,
	weights: { quality: number, time: number },
	bonus: number,
	penalty: number,
}): number
	local performance = job.weights.quality * GameConfig.qualityMultiplier(job.quality)
		+ job.weights.time * GameConfig.speedMultiplier(job.elapsed, job.parTime)
	return math.max(0, math.floor(job.basePay * job.toolFit * performance * job.bonus - job.penalty))
end

-- 1.25 when very fast, 1 at exactly par, 0.5 at twice par or slower.
function GameConfig.speedMultiplier(elapsed: number, parTime: number): number
	if elapsed <= parTime then
		local fast = math.clamp((parTime - elapsed) / (parTime * 0.5), 0, 1)
		return 1 + GameConfig.MaxSpeedBonus * fast
	end
	local slow = math.clamp((elapsed - parTime) / parTime, 0, 1)
	return 1 - GameConfig.MaxSlowPenalty * slow
end

function GameConfig.levelFromXp(xp: number): number
	return math.floor(math.sqrt(xp / 50)) + 1
end

function GameConfig.xpForLevel(level: number): number
	return (level - 1) ^ 2 * 50
end

return GameConfig
