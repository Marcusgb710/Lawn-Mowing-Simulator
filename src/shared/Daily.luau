-- What day it is, for the features that turn over with the day: the daily contracts, the streak and
-- Saturday's judging (docs/superpowers/specs/2026-10-29-busy-season-design.md). A day here is a UTC
-- day, the same for every player and every server wherever they are: it runs from 00:00 UTC to the
-- next 00:00 UTC, 86400 seconds later (unix time has no leap seconds). A moment is a unix time in
-- seconds at or after 1970, which is what the server's Clock hands out (os.date can fail or misread
-- before that on some runtimes). Nothing here keeps state or reads the clock; each function is told
-- the moment.
--
-- The calendar parts come from os.date("!*t", unix), the UTC form, whose `wday` counts from 1 on
-- Sunday, so Saturday is 7. It reads the same under Roblox and under Lune. The midnights are plain
-- arithmetic on the unix number.
--
-- scripts/check-season.luau gates this file. It has no requires, so Lune can load it.

local Daily = {}

local SECONDS_PER_DAY = 86400
local SATURDAY = 7

-- The whole UTC days since 00:00 UTC on 1 January 1970 that `unix` falls in.
local function dayNumber(unix: number): number
	return math.floor(unix / SECONDS_PER_DAY)
end

-- The UTC date of `unix` as "YYYYMMDD" ("20261029"). The key is the same for every second of the day,
-- and it sorts in date order.
function Daily.dayKey(unix: number): string
	local date = os.date("!*t", unix)
	return string.format("%04d%02d%02d", date.year, date.month, date.day)
end

-- Whether `unix` is on a Saturday in UTC.
function Daily.isSaturday(unix: number): boolean
	return os.date("!*t", unix).wday == SATURDAY
end

-- 00:00 UTC at the start of the next Saturday, or of today when today is one (judging day is a whole
-- day, so a Saturday morning still counts). A Sunday looks six days ahead.
function Daily.nextSaturday(unix: number): number
	local daysAhead = (SATURDAY - os.date("!*t", unix).wday) % 7
	return (dayNumber(unix) + daysAhead) * SECONDS_PER_DAY
end

-- The whole UTC days from the day `unix` is in to the day `target` is in: 0 for the same day, 2 from
-- Thursday to Saturday, negative when `target` is on an earlier day.
function Daily.daysUntil(unix: number, target: number): number
	return dayNumber(target) - dayNumber(unix)
end

-- 00:00 UTC when the day `unix` is in ends: the first moment of tomorrow.
function Daily.midnightAfter(unix: number): number
	return (dayNumber(unix) + 1) * SECONDS_PER_DAY
end

-- The words on the judging day countdown pill, or nil when there is no pill: from the contest view the
-- server sent (`state`, and `daysLeft`: 0 when judging day is open, 7 on a Saturday already judged, 1 to
-- 6 on the other days) and this computer's clock `now`. "Judging day is today!" while it is open, "Judging
-- day in 2d 5h" while it is coming. The server only sends the view when someone joins, an act starts or a
-- job ends, so one held across Saturday's midnight is out of date, and two things are told from the clock:
--   * a Waiting view from before today's Saturday (`daysLeft` under 7: it was sent on another day) says
--     today is judging day, as the server would once it sent the view again;
--   * an Open view held past Saturday is not open any more, so it reads as the countdown.
-- A Saturday already judged (`daysLeft` 7, or none) counts to the next one.
function Daily.judgingText(state: string, daysLeft: number?, now: number): string?
	if state == "Open" then
		if Daily.isSaturday(now) then
			return "Judging day is today!"
		end
	elseif state ~= "Waiting" then
		return nil
	end
	local target = Daily.nextSaturday(now)
	if target <= now then
		if (daysLeft or 7) < 7 then
			return "Judging day is today!"
		end
		target = Daily.nextSaturday(Daily.midnightAfter(now))
	end
	local left = target - now
	local days = left // SECONDS_PER_DAY
	local hours = (left % SECONDS_PER_DAY) // 3600
	if days > 0 then
		return `Judging day in {days}d {hours}h`
	elseif hours > 0 then
		return `Judging day in {hours}h`
	end
	return "Judging day in under 1h"
end

return Daily
