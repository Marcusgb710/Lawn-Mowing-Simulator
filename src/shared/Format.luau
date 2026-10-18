local Format = {}

-- 12500 -> "$12,500"
function Format.money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

-- 75 -> "1:15"
function Format.time(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(math.clamp(fraction, 0, 1) * 100))
end

return Format
