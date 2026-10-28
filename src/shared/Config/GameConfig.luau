-- Numbers you'll probably want to tweak while balancing the game.

local GameConfig = {
	StartingMoney = 0,
	MaxCrewSize = 4,

	-- How long the truck "drive" cutscene lasts, in seconds.
	TravelTime = 6,
	-- Before it, the crew gets in and the truck pulls out of the driveway, for this many seconds.
	PullOutTime = 3.5,
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
	-- Junk hidden in the grass (sticks, toys, rocks: see Config/Debris.luau). Each piece still on the
	-- lawn when the job's done, or chewed up by a mower, takes this much off the finish (0-1) and
	-- this fraction of the job's pay (at least MinDebrisPenalty).
	DebrisQualityHit = 0.04,
	DebrisPenalty = 0.04,
	MinDebrisPenalty = 3,

	-- Lawn generation
	TileSize = 4,
	-- A lawn's grass is kept in cells this many studs wide.
	CellSize = 1,
	-- Pixels per stud in the mowed picture (halved for a lawn too big to fit one image).
	PixelsPerStud = 4,
	-- Mowing counts as done at this share of a lawn's mowable cells (other tasks use CompletionThreshold).
	MowCompletionThreshold = 0.99,
	-- How far in front of the player a mower's deck sits, in studs.
	DeckOffset = 2,
	-- A snip of the shears clears a circle of grass this many studs round (their own snip.radius
	-- still covers everything else they cut).
	SnipRadius = 1,
	-- Players this close to a lawn (studs) hear about every cut on it: clients draw lawns within
	-- 200 studs, plus 30 of slack before they stop.
	GrassDrawDistance = 230,
	-- Walk speed is multiplied by this while a mower is cutting.
	CuttingSlowdown = 0.85,
	-- Camera shake is multiplied by this while a mower is cutting.
	CuttingShake = 1.5,
	-- From this share of the lawn mowed, the "Show what I missed" button appears...
	MissedSpotsFrom = 0.9,
	-- ...and the uncut spots stay lit for this many seconds.
	MissedSpotsSeconds = 3,
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

	-- Your business's own front lawn (see HomeLawnService).
	HomeLawn = {
		-- Minutes of play for a tidy lawn to grow all the way back (grass, edges, weeds, leaves).
		-- It only grows while you're in the game. Each bit you tidy stays tidy for between
		-- RegrowStart of that (0.5 = half) and all of it.
		RegrowMinutes = 40,
		RegrowStart = 0.5,
		-- What a neighbor tips you for tidying it up after it got untidy, and how often at most.
		-- It only counts once the lawn has grown back to below this share done since the last tip,
		-- so cutting back one stray weed isn't worth a tip.
		TidyTip = 25,
		TidyTipCooldownMinutes = 30,
		TipAfterBelowShare = 0.75,
	},
	-- Curb appeal, 0-100: how good your business looks from the street (see HomeLawn.luau).
	CurbAppeal = {
		-- Points for a perfectly kept lawn, and for decorations.
		LawnPoints = 60,
		DecorPoints = 40,
		-- Job pay bonus at 100 curb appeal (less below it), for every job your crew does.
		MaxPayBonus = 0.15,
		-- Decorations: each extra one of the same kind is worth this much of the one before, an
		-- overgrown shrub this share of a trimmed one, and a yard with this many appeal points gets
		-- half the decoration points (more points level off toward all of them).
		DecorRepeat = 0.6,
		OvergrownShare = 0.5,
		DecorHalfPoints = 30,
	},
	-- Shrubs you've placed (see DecorService) are overgrown again this many minutes of play after
	-- you trim them.
	ShrubRegrowMinutes = 30,

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
