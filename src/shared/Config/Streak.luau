-- The daily streak (docs/superpowers/specs/2026-10-29-busy-season-design.md): the days in a row a
-- player has come back, and what each day pays. The week is seven days. Days 1 to 6 pay cash, day 7
-- pays the most and gives a pennant for the truck (a flag, given once), and after that the week
-- repeats with cash only. `advance` is the one place a streak grows or starts again: it is told
-- today's day key and yesterday's, so it never reads the clock. Nothing here saves or pays
-- anything: whoever calls these keeps the streak table and pays the cash.
--
-- Each day's cash is a gift the player claims (the HUD's Gifts button, DailyService's ClaimStreak):
-- the day turn (`turn`) moves the streak on and leaves the new day's gift waiting (`waiting`), and
-- `claim` takes it. A gift still waiting when the next day turns is owed, and `turn` hands its cash
-- back for the caller to pay, once, so nobody loses a day's cash by not pressing the button.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

export type Reward = { cash: number, flag: string? }
-- `days` in a row, the day key it was `last` kept, and the day key whose gift was last `claimed`
-- (paid, by a claim or by the turn after it).
export type State = { days: number, last: string, claimed: string }

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

-- Whether today's gift is waiting to be claimed: the streak was kept today (the turn has run) and
-- today's gift has not been claimed. No streak, no gift.
function Streak.waiting(streak: State, today: string): boolean
	return streak.days >= 1 and streak.last == today and streak.claimed ~= today
end

-- Claims today's gift: marks it claimed and returns what the day pays (its cash, and day 7's flag,
-- which the turn onto day 7 has already given), or nil when nothing is waiting, so a gift is claimed
-- once. The caller pays the cash.
function Streak.claim(streak: State, today: string): Reward?
	if not Streak.waiting(streak, today) then
		return nil
	end
	streak.claimed = today
	return Streak.rewardFor(streak.days)
end

-- The day turn: if the day the streak was last kept had a gift that was never claimed, marks it
-- claimed and owes its cash (the cash only: its flag, on day 7, came with that day's own turn), then
-- moves the streak on to `today` (advance). Returns whether the streak moved, and the cash owed and
-- the streak day it was for, both nil when nothing is owed. The caller pays what is owed and leaves
-- today's gift waiting. On the day the streak already has, nothing changes and nothing is owed, so
-- an owed gift is paid once.
function Streak.turn(streak: State, today: string, yesterday: string): (boolean, number?, number?)
	if streak.last == today then
		return false, nil, nil
	end
	local owed, owedDays = nil, nil
	if streak.days >= 1 and streak.last ~= "" and streak.claimed ~= streak.last then
		owedDays = streak.days
		owed = Streak.rewardFor(owedDays).cash
		streak.claimed = streak.last
	end
	return Streak.advance(streak, today, yesterday), owed, owedDays
end

-- The streak line: "Day 3 of 7". Past day 7 the week starts again, so day 8 reads "Day 1 of 7".
function Streak.text(days: number): string
	return `Day {dayOfWeek(days)} of {#Streak.Rewards}`
end

return Streak
