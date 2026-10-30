-- The daily streak (docs/superpowers/specs/2026-10-29-busy-season-design.md): the days in a row a
-- player has come back, and what each day pays. The week is seven days. Days 1 to 6 pay cash, day 7
-- pays the most and gives a pennant for the truck (a flag, given once), and after that the week
-- repeats with cash only. `advance` is the one place a streak grows or starts again: it is told
-- today's day key and yesterday's, so it never reads the clock. Nothing here saves or pays
-- anything: whoever calls these keeps the streak table and pays the cash.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

export type Reward = { cash: number, flag: string? }
export type State = { days: number, last: string }

local Streak = {}

-- What each day of the week pays, in order. Day 7 also gives a flag, which DailyService records in
-- the save's `flags`.
Streak.Rewards = {
	{ cash = 100 },
	{ cash = 150 },
	{ cash = 200 },
	{ cash = 300 },
	{ cash = 400 },
	{ cash = 600 },
	{ cash = 1000, flag = "TruckPennant" },
} :: { Reward }

-- Which day of the week (1 to 7) a streak of `days` is on. A streak below 1 is held to day 1.
local function dayOfWeek(days: number): number
	return ((math.max(1, math.floor(days)) - 1) % #Streak.Rewards) + 1
end

-- What day `days` of the streak pays. Days 1 to 7 are the week as listed; past that the week
-- repeats with the same cash and no flag (day 14 pays like day 7, without a second pennant).
function Streak.rewardFor(days: number): Reward
	local day = math.max(1, math.floor(days))
	local reward = Streak.Rewards[day]
	if reward then
		return { cash = reward.cash, flag = reward.flag }
	end
	return { cash = Streak.Rewards[dayOfWeek(day)].cash }
end

-- Moves `streak` on to `today`, and says whether it moved. Coming back the day after `last` adds a
-- day; any longer gap starts again at day 1; coming back the same day changes nothing and returns
-- false. Both keys are day keys ("20261029", from Daily.dayKey).
function Streak.advance(streak: State, today: string, yesterday: string): boolean
	if streak.last == today then
		return false
	end
	if streak.last == yesterday then
		streak.days += 1
	else
		streak.days = 1
	end
	streak.last = today
	return true
end

-- The streak line: "Day 3 of 7". Past day 7 the week starts again, so day 8 reads "Day 1 of 7".
function Streak.text(days: number): string
	return `Day {dayOfWeek(days)} of {#Streak.Rewards}`
end

return Streak
