-- The Maple Grove Best Yard contest (docs/STORY.md, act 4): how your yard is scored, Gloria's bar,
-- when judging day comes round and what winning pays. ContestService (on the server) runs it,
-- the results screen (ContestController) only shows what it decided. The lines are in
-- Config/Story.luau (the Contest scenes, and June's porch talk).
--
-- After the first judging day the contest goes by the calendar: judging day is every Saturday (UTC),
-- worked out with Daily (the one pure require here, which has no requires of its own), so
-- scripts/check-story.luau can test this file with Lune by handing Daily in.

local Daily = require(script.Parent.Parent.Daily)

local Contest = {}

-- June offers to enter you from this act (act 4, "The Contest").
Contest.FromAct = 4

-- Four categories, each out of `CategoryPoints`, in the order the results screen lists them.
-- Everything comes from what the game already measures about your business's yard:
--   Lawn   how much of your own lawn's grass, weeds and leaves is done, less `JunkPoints` for
--          each piece of junk still in the grass
--   Edges  how much of its edge along the sidewalk and driveway is done
--   Beds   half for beds (`BedIds`, up to `BedsWanted` of them), half for trimmed shrubs (up to
--          `ShrubsWanted`; a shaggy one counts `ShaggyShrub` of one)
--   Charm  mostly how well decorated the yard is (HomeLawn.decorShare, the same as curb appeal's
--          decoration points; `CharmShare` and up is full marks), the rest for how many different
--          kinds of decoration there are (`KindsWanted` and up)
Contest.Categories = {
	{ id = "Lawn", name = "Lawn and stripes" },
	{ id = "Edges", name = "Edges" },
	{ id = "Beds", name = "Beds and shrubs" },
	{ id = "Charm", name = "Decorations and charm" },
}
Contest.CategoryPoints = 25
Contest.JunkPoints = 2
Contest.BedIds = { "MulchBedSection", "RaisedGardenBed", "TerracottaPlanter", "FlowerPatch" }
Contest.BedsWanted = 3
Contest.ShrubsWanted = 4
Contest.ShaggyShrub = 0.25
Contest.CharmShare = 0.6
Contest.CharmWeight = 0.7
Contest.KindsWanted = 8

-- Gloria's bar: her yard's score (TurfKing does it). `First` the first summer, `PerSummer` more
-- every summer after (each new summer), never more than `Max`. `Shares` is how her score splits
-- over the categories: TurfKing's edges are the sharpest thing on the street.
Contest.GloriaBar = {
	First = 88,
	PerSummer = 2,
	Max = 96,
	Shares = { Lawn = 0.26, Edges = 0.28, Beds = 0.24, Charm = 0.22 },
}

-- What winning pays: `Prize` every time; the first win also brings the Best Yard Trophy for
-- your yard (a decoration that's never sold, delivered in a box) and `BuildingDiscount` off the
-- first of `DiscountOn` you don't own yet (the Small Office, or the Equipment Yard if you've
-- got the office).
Contest.Prize = 2500
Contest.Trophy = "BestYardTrophy"
Contest.BuildingDiscount = 0.5
Contest.DiscountOn = { "SmallOffice", "EquipmentYard" }

-- When judging day comes round again, in jobs finished: after a loss you can try again after
-- `RetryJobs`; after a win, next summer's contest (with Gloria's bar higher) after `SummerJobs`.
-- That is for the first judging day only; from the second on it is every Saturday (calendarState).
Contest.RetryJobs = 4
Contest.SummerJobs = 12

-- How many Saturdays judged without a win it takes to start a new summer anyway (Gloria's bar goes
-- up a step): the fourth loss does it. A Saturday you miss isn't counted (Contest.afterLoss).
Contest.SaturdaysPerSummer = 4

-- June has won Best Yard this many times before you start.
Contest.JuneWins = 30

local function points(fraction: number): number
	return math.floor(Contest.CategoryPoints * math.clamp(fraction, 0, 1) + 0.5)
end

-- Your yard's scores, from what it measures: { lawnShare, edgeShare (0-1), junk (pieces left in
-- the grass), beds, tidyShrubs, shaggyShrubs (how many), decorShare (0-1), kinds (different
-- decorations) }. Returns { Lawn, Edges, Beds, Charm, total }.
function Contest.score(measures): { [string]: number }
	local lawn = points(measures.lawnShare or 0)
	lawn = math.max(0, lawn - (measures.junk or 0) * Contest.JunkPoints)
	local shrubs = (measures.tidyShrubs or 0) + (measures.shaggyShrubs or 0) * Contest.ShaggyShrub
	local beds = 0.5 * math.min(1, (measures.beds or 0) / Contest.BedsWanted)
		+ 0.5 * math.min(1, shrubs / Contest.ShrubsWanted)
	local charm = Contest.CharmWeight * math.min(1, (measures.decorShare or 0) / Contest.CharmShare)
		+ (1 - Contest.CharmWeight) * math.min(1, (measures.kinds or 0) / Contest.KindsWanted)
	local scores = {
		Lawn = lawn,
		Edges = points(measures.edgeShare or 0),
		Beds = points(beds),
		Charm = points(charm),
	}
	scores.total = scores.Lawn + scores.Edges + scores.Beds + scores.Charm
	return scores
end

-- Gloria's total in summer `summer` (1, 2, 3...).
function Contest.bar(summer: number): number
	local bar = Contest.GloriaBar
	return math.min(bar.First + bar.PerSummer * (math.max(1, summer) - 1), bar.Max)
end

-- Gloria's scores in summer `summer`: her bar split over the categories by her shares, in whole
-- points, none over the category's points. Returns { Lawn, Edges, Beds, Charm, total }.
function Contest.gloriaScores(summer: number): { [string]: number }
	local total = math.min(Contest.bar(summer), Contest.CategoryPoints * #Contest.Categories)
	local shares = Contest.GloriaBar.Shares
	local scores, sum = { total = total }, 0
	for _, category in Contest.Categories do
		scores[category.id] = math.min(Contest.CategoryPoints, math.floor(total * shares[category.id]))
		sum += scores[category.id]
	end
	-- What rounding down left over goes a point at a time to whichever is furthest under its share.
	while sum < total do
		local best, gap = nil, -math.huge
		for _, category in Contest.Categories do
			local short = total * shares[category.id] - scores[category.id]
			if scores[category.id] < Contest.CategoryPoints and short > gap then
				best, gap = category.id, short
			end
		end
		if not best then
			break
		end
		scores[best] += 1
		sum += 1
	end
	return scores
end

-- Whether your scores beat Gloria's. A tie goes to June: she's the champion.
function Contest.won(yours, hers): boolean
	return yours.total >= hers.total
end

-- Where the contest is for a player by the jobs rule, which is how the first judging day works:
-- "Locked" (before act 4), "Results" (judged, and the results are waiting to be collected),
-- "Waiting" (judging day comes round in a few jobs) or "Open" (ready when you are). `contest` is
-- their saved contest ({ pending, nextAt }). Once a judging day has been played, calendarState
-- takes over.
function Contest.state(contest, act: number, jobsCompleted: number): string
	if act < Contest.FromAct then
		return "Locked"
	elseif contest.pending then
		return "Results"
	elseif jobsCompleted < (contest.nextAt or 0) then
		return "Waiting"
	end
	return "Open"
end

-- Whether judging day is open on the day `now` is in, for someone who has been through the first
-- one: it is a Saturday (UTC) and they haven't judged on it yet. `contest.lastJudged` is the day
-- key of their last judging ("" for none).
local function openToday(contest, now: number): boolean
	return Daily.isSaturday(now) and (contest.lastJudged or "") ~= Daily.dayKey(now)
end

-- Where the contest is for a player at the moment `now` (unix seconds): the same four words as
-- state. Until the first judging day has been played (`contest.judged` is 0) it is state, the jobs
-- rule, so the story lands the first time. After that, judging day is every Saturday: "Open" on
-- one they haven't judged on, "Waiting" every other day. "Locked" and "Results" are as in state.
-- `contest` is their saved contest ({ judged, pending, nextAt, lastJudged }).
function Contest.calendarState(contest, act: number, jobsCompleted: number, now: number): string
	local state = Contest.state(contest, act, jobsCompleted)
	if state == "Locked" or state == "Results" or (contest.judged or 0) == 0 then
		return state
	end
	return if openToday(contest, now) then "Open" else "Waiting"
end

-- How many days from the day `now` is in to their next judging day: 0 when it is open today, 7 when
-- today is a Saturday they have already judged on, else the days to the coming Saturday (2 from a
-- Thursday, 6 from a Sunday). Only meant for someone on the calendar (`contest.judged` above 0).
function Contest.daysUntilJudging(contest, now: number): number
	if openToday(contest, now) then
		return 0
	elseif Daily.isSaturday(now) then
		return 7
	end
	return Daily.daysUntil(now, Daily.nextSaturday(now))
end

-- What a lost judging day does to the Saturdays counted toward a new summer. `judged` is how many
-- judging days there have been, this one included, and `saturdays` how many lost Saturdays this
-- summer had before it. The first judging day (`judged` 1) goes by the jobs rule and isn't a
-- Saturday, so it changes nothing. After that each loss adds one, and the one that reaches
-- SaturdaysPerSummer starts a new summer and the count again from 0. Returns the new count and
-- whether a new summer starts.
function Contest.afterLoss(judged: number, saturdays: number): (number, boolean)
	if judged <= 1 then
		return saturdays, false
	end
	local counted = saturdays + 1
	if counted >= Contest.SaturdaysPerSummer then
		return 0, true
	end
	return counted, false
end

-- When judging day comes round again (in jobs finished) after one ends.
function Contest.nextAt(won: boolean, jobsCompleted: number): number
	return jobsCompleted + (if won then Contest.SummerJobs else Contest.RetryJobs)
end

-- The building a first win takes `BuildingDiscount` off: the first of `DiscountOn` they don't
-- own (`owned` is { [business id] = true }), or nil if they own them all.
function Contest.discountFor(owned: { [string]: boolean }?): string?
	for _, id in Contest.DiscountOn do
		if not (owned and owned[id]) then
			return id
		end
	end
	return nil
end

-- A building's price with the Best Yard discount.
function Contest.discounted(price: number): number
	return math.floor(price * (1 - Contest.BuildingDiscount))
end

-- What winning brings someone who's won `wins` times before and owns these businesses (`owned`,
-- { [business id] = true }): { money, trophy (the decoration id, the first time), discount (a
-- business id, the first time) }.
function Contest.rewards(wins: number, owned: { [string]: boolean }?)
	local first = wins == 0
	return {
		money = Contest.Prize,
		trophy = if first then Contest.Trophy else nil,
		discount = if first then Contest.discountFor(owned) else nil,
	}
end

return Contest
