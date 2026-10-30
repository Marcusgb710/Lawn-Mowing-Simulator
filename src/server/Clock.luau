-- The server's one clock: what every service asks for "now" when the day matters (the daily
-- contracts, the streak, Saturday's judging), so there is a single notion of today to ask and to
-- test. It is os.time(), UTC seconds as unix time (the same on every server), plus an offset that
-- starts at zero. Daily turns that moment into a day key or a Saturday.
--
-- The offset exists for Studio's "next day" and "Saturday" shortcuts, which move the clock forward
-- so a test can reach tomorrow or judging day without waiting for either. It can never apply live:
-- setOffset only takes a value when RunService:IsStudio() is true, and anywhere else it warns and
-- leaves the clock alone. Server only: it sits under src/server and the client has no copy.
--
-- Nothing runs when this loads but the table (RunService is only looked up inside setOffset), so
-- scripts/check-season can require it under Lune and check now() and offset().

local Clock = {}

local offsetSeconds = 0

-- The server's time now, in unix seconds, with the Studio offset added (zero live).
function Clock.now(): number
	return os.time() + offsetSeconds
end

-- Moves the clock `seconds` from the real time (negative is the past). Studio only: live it warns
-- and changes nothing. The check is made here, when it is called, so no caller can skip it.
function Clock.setOffset(seconds: number)
	if not game:GetService("RunService"):IsStudio() then
		warn("Clock.setOffset is for Studio testing only; the clock was left alone")
		return
	end
	assert(
		typeof(seconds) == "number" and math.abs(seconds) < math.huge,
		"Clock.setOffset needs a finite number of seconds"
	)
	offsetSeconds = seconds
end

-- The offset in seconds now (0 unless Studio set it).
function Clock.offset(): number
	return offsetSeconds
end

return Clock
