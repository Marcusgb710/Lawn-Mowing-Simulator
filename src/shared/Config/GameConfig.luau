-- Numbers you'll probably want to tweak while balancing the game.

local GameConfig = {
	StartingMoney = 0,
	MaxCrewSize = 4,

	-- How long the truck "drive" cutscene lasts, in seconds.
	TravelTime = 6,
	-- How long the crew stays at the house after finishing before driving back.
	ReturnDelay = 5,

	JobBoardSize = 6,
	-- The job board always keeps at least this many level 1 jobs on it.
	StarterJobsOnBoard = 2,
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

	-- How often tools do work, in seconds.
	WorkTickRate = 0.1,
	DefaultWalkSpeed = 16,

	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120,
}

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
