-- Checks the GUI overhaul's data and maths outside Roblox:
--   lune run scripts/check-gui [GUI folder]
-- It checks src/shared/Config/GuiArt.luau (written by scripts/gui-art-ids.py) fits together: ids
-- look like ids, every slice and font atlas is an image in the list, every glyph sits inside its
-- atlas, the numbers font's digits are all the same width and kerning only names glyphs that are
-- there. Every image the client asks for by name (Art.icon("Money"), Art.kit("Panel")...) has to
-- be in it too. Then the maths: setting text in the bitmap fonts (src/shared/GuiLayout.luau), the
-- hold ring and the striped fills, and the pay breakdown's lines adding up to what a job paid
-- (src/shared/PayBreakdown.luau).
-- Given the art's GUI folder (or with art-source/GUI in this repo), it also reads the manifest
-- and the .fnt files again and checks GuiArt matches them exactly. Exits with an error if
-- anything's off.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local GuiArt = require("../src/shared/Config/GuiArt")
local GuiLayout = require("../src/shared/GuiLayout")
local PayBreakdown = require("../src/shared/PayBreakdown")

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL  " .. message)
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- GuiArt fits together -------------------------------------------------------------------------

local imageCount = 0
for path, id in GuiArt.Images do
	imageCount += 1
	check(typeof(path) == "string" and string.match(path, "^%u%w*/[%w_]+%.png$") ~= nil, `odd image path {path}`)
	check(id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil, `{path}: "{id}" isn't an asset id`)
end
check(imageCount == 312, `GuiArt has {imageCount} images, not the 312 in the manifest`)

for name, slice in GuiArt.Slices do
	check(GuiArt.Images[slice.file] ~= nil, `slice {name}: {slice.file} isn't an image`)
	check(#slice.size == 2, `slice {name} has no size`)
	if slice.center then
		local left, top, right, bottom = table.unpack(slice.center)
		check(0 <= left and left < right and right <= slice.size[1], `slice {name}: centre is outside it across`)
		check(0 <= top and top < bottom and bottom <= slice.size[2], `slice {name}: centre is outside it down`)
		check(slice.scale ~= nil and slice.scale > 0, `slice {name} has no scale`)
	end
	if slice.tile then
		check(#slice.tile == 2 and slice.tile[1] > 0 and slice.tile[2] > 0, `slice {name}: odd tile size`)
	end
end

for role, hex in GuiArt.Palette do
	check(string.match(hex, "^#%x%x%x%x%x%x$") ~= nil, `palette {role}: {hex} isn't a colour`)
end
for _, role in { "ink", "panel", "card", "text", "subtext", "accent", "money", "danger", "rival", "gold", "grandma" } do
	check(GuiArt.Palette[role] ~= nil, `the palette has no {role}`)
end

for name, font in GuiArt.Fonts do
	check(GuiArt.Images[font.face] ~= nil, `font {name}: no face atlas {font.face}`)
	check(GuiArt.Images[font.outline] ~= nil, `font {name}: no outline atlas {font.outline}`)
	check(font.base > 0 and font.base < font.lineHeight, `font {name}: the baseline is outside the line`)
	check(font.capHeight > 0 and font.capHeight <= font.base, `font {name}: odd cap height`)
	for code, glyph in font.glyphs do
		local x, y, width, height = glyph[1], glyph[2], glyph[3], glyph[4]
		check(#glyph == 7, `font {name}: glyph {code} isn't 7 numbers`)
		check(
			x >= 0 and y >= 0 and x + width <= font.atlas[1] and y + height <= font.atlas[2],
			`font {name}: glyph {code} runs off the atlas`
		)
		check(glyph[7] > 0, `font {name}: glyph {code} doesn't move the pen`)
	end
	check(font.glyphs[32] ~= nil, `font {name} has no space`)
	for first, seconds in font.kerning do
		check(font.glyphs[first] ~= nil, `font {name}: kerning from a glyph it hasn't got ({first})`)
		for second in seconds do
			check(font.glyphs[second] ~= nil, `font {name}: kerning to a glyph it hasn't got ({second})`)
		end
	end
end
local numbers, headline = GuiArt.Fonts.Display_Numbers, GuiArt.Fonts.Display_Headline
check(numbers ~= nil and headline ~= nil, "GuiArt is missing a bitmap font")
for digit = 48, 57 do
	check(numbers.glyphs[digit][7] == numbers.glyphs[48][7], `the numbers font's {string.char(digit)} isn't tabular`)
end
for _, char in { "$", ",", ".", "+", "/", ":", "%", "R" } do
	check(numbers.glyphs[string.byte(char)] ~= nil, `the numbers font has no {char}`)
end
for code = string.byte("A"), string.byte("z") do
	if code <= string.byte("Z") or code >= string.byte("a") then
		check(headline.glyphs[code] ~= nil, `the headline font has no {string.char(code)}`)
	end
end

-- Every image the client asks for by name is there. Art.icon("X") is Icons/X.png, and so on.
local KINDS = {
	icon = "Icons/%s.png",
	kit = "Kit/%s.png",
	item = "Items/%s.png",
	portrait = "Portraits/%s.png",
	wordmark = "Wordmarks/%s.png",
	computer = "Computer/%s.png",
	moment = "Moments/%s.png",
	store = "Store/%s.png",
}
local function scan(folder: string)
	for _, name in fs.readDir(folder) do
		local path = `{folder}/{name}`
		if fs.isDir(path) then
			scan(path)
		elseif string.match(name, "%.luau$") then
			local source = fs.readFile(path)
			for kind, name in string.gmatch(source, 'Art%.(%a+)%("([%w_]+)"%)') do
				local pattern = KINDS[kind]
				if pattern then
					local image = string.format(pattern, name)
					check(GuiArt.Images[image] ~= nil, `{path} asks for {image}, which isn't in GuiArt`)
				end
			end
			for _, pattern in { 'Art%.slice%("([%w_/]+)"%)', 'UI%.sliced%(%s*"([%w_/]+)"' } do
				for name in string.gmatch(source, pattern) do
					check(GuiArt.Slices[name] ~= nil, `{path} asks for the slice {name}, which isn't in GuiArt`)
				end
			end
		end
	end
end
scan("src/client")

-- Setting text in the bitmap fonts ---------------------------------------------------------------

check(GuiLayout.prepare(numbers, "$12,450") == "$12,450", "the numbers font can't set $12,450")
check(GuiLayout.prepare(numbers, "-$5") == "\u{2212}$5", "a hyphen isn't swapped for the minus sign")
check(GuiLayout.prepare(numbers, "03:24 / 05:00") ~= nil, "the numbers font can't set a timer")
check(GuiLayout.prepare(numbers, "Hello") == nil, "the numbers font says it can set letters")
check(GuiLayout.prepare(headline, "Act 2: TurfKing") == "Act 2: TurfKing", "the headline font can't set an act")
check(GuiLayout.prepare(headline, "June\u{2019}s") ~= nil, "the headline font can't set a curly apostrophe")
check(GuiLayout.prepare(headline, "\u{1F600}") == nil, "the headline font says it can set an emoji")

-- "$12,450" at full size: the pen moves by each glyph's advance (the numbers font has no kerning).
local money = GuiLayout.text(numbers, "$12,450", 1)
local advance = 0
for _, code in utf8.codes("$12,450") do
	advance += numbers.glyphs[code][7]
end
check(#money.quads == 7, `$12,450 has {#money.quads} glyphs`)
check(near(money.width, advance), `$12,450 is {money.width} wide, not {advance}`)
check(near(money.quads[1].x, numbers.glyphs[36][5]), "the first glyph isn't at its x offset")
check(
	near(money.quads[2].x, numbers.glyphs[36][7] + numbers.glyphs[49][5]),
	"the second glyph doesn't start where the first one's advance ends"
)
check(near(money.height, numbers.lineHeight), "the line isn't the font's line height")
-- Scaled, everything scales.
local small = GuiLayout.text(numbers, "$12,450", 0.25)
check(near(small.width, advance * 0.25), "the width doesn't scale")
check(near(small.quads[3].y, numbers.glyphs[50][6] * 0.25), "the y offset doesn't scale")
check(near(small.quads[3].height, numbers.glyphs[50][4] * 0.25), "the glyph height doesn't scale")
check(small.quads[3].atlasWidth == numbers.glyphs[50][3], "the atlas rectangle scaled with the glyph")
-- Spaces move the pen without drawing anything.
local timer = GuiLayout.text(numbers, "1 / 2", 1)
check(#timer.quads == 3, `"1 / 2" has {#timer.quads} glyphs to draw, not 3`)

-- Kerning: a pair pulls the second glyph closer.
local kernFirst, kernSecond, kernAmount = nil, nil, nil
for first, seconds in headline.kerning do
	for second, amount in seconds do
		if amount ~= 0 and first < 128 and second < 128 then
			kernFirst, kernSecond, kernAmount = first, second, amount
			break
		end
	end
	if kernFirst then
		break
	end
end
check(kernFirst ~= nil, "the headline font has no kerning to test")
if kernFirst and kernSecond and kernAmount then
	local pair = string.char(kernFirst, kernSecond)
	local kerned = GuiLayout.text(headline, pair, 1)
	local first, second = headline.glyphs[kernFirst], headline.glyphs[kernSecond]
	check(near(kerned.width, first[7] + kernAmount + second[7]), `{pair}: kerning isn't in the width`)
	check(near(kerned.quads[2].x, first[7] + kernAmount + second[5]), `{pair}: kerning didn't move the second glyph`)
end

-- Fitting a line in a box.
check(near(GuiLayout.scaleFor(numbers, numbers.size / 2), 0.5), "scaleFor isn't text size over font size")
local line = GuiLayout.text(numbers, "8", 0.5)
local shift = GuiLayout.centreCaps(line, 40)
local capTop, capBottom = line.capTop + shift, line.baseline + shift
check(near(capTop, 40 - capBottom), "the capitals aren't in the middle of the box")
check(near(GuiLayout.align(100, 300, "Left"), 0), "left alignment moves the line")
check(near(GuiLayout.align(100, 300, "Center"), 100), "centring is off")
check(near(GuiLayout.align(100, 300, "Right"), 200), "right alignment is off")

-- The hold ring: right half first, then the left.
local function ring(fraction: number, right: number, left: number)
	local gotRight, gotLeft = GuiLayout.ring(fraction)
	check(near(gotRight, right) and near(gotLeft, left), `ring({fraction}) is {gotRight}, {gotLeft}`)
end
ring(0, 0, 180)
ring(0.25, 90, 180)
ring(0.5, 180, 180)
ring(0.75, 180, 270)
ring(1, 180, 360)
ring(1.5, 180, 360)
ring(-1, 0, 180)

-- Striped fills keep their tile shape.
check(GuiLayout.tileWidth({ 64, 12 }, 12) == 64, "a 12 px bar's tile isn't 64 wide")
check(GuiLayout.tileWidth({ 64, 12 }, 6) == 32, "a 6 px bar's tile isn't 32 wide")
check(near(GuiLayout.sliceScale(64, 12, 0.5), 12 / 64), "a thin bar's slice scale isn't shrunk")
check(near(GuiLayout.sliceScale(64, 100, 0.5), 0.5), "a tall bar's slice scale isn't capped")

-- The pay breakdown adds up --------------------------------------------------------------------

-- The same sum as GameConfig.jobPay and JobService's completeJob.
local PREFERENCES = {
	Quality = { quality = 0.75, time = 0.25 },
	Balanced = { quality = 0.5, time = 0.5 },
	Speed = { quality = 0.25, time = 0.75 },
}
local function job(options)
	local weights = PREFERENCES[options.preference]
	local performance = weights.quality * options.qualityMultiplier + weights.time * options.speedMultiplier
	local bonus = options.crewBonus * options.truckBonus * options.businessBonus * options.curbBonus
	local total = math.max(0, math.floor(options.basePay * options.toolFit * performance * bonus - options.penalty))
	total += options.wonBack
	local result = table.clone(options)
	result.total = total
	result.share = math.floor(total / options.crew)
	return result, weights
end
local cases = {
	{ "a plain job", {} },
	{ "a quick sloppy job", { qualityMultiplier = 0.7, speedMultiplier = 1.25, preference = "Speed" } },
	{ "a slow perfect job", { qualityMultiplier = 1.3, speedMultiplier = 0.6, preference = "Quality" } },
	{ "the wrong tools", { toolFit = 0.6 } },
	{ "a crew of three", { crew = 3, crewBonus = 1.3, truckBonus = 1.1, businessBonus = 1.05 } },
	{ "curb appeal and a customer won back", { curbBonus = 1.12, wonBack = 18 } },
	{ "some damage", { penalty = 23 } },
	{ "more damage than pay", { penalty = 900, wonBack = 12 } },
	{ "odd pennies", { basePay = 137, qualityMultiplier = 1.137, speedMultiplier = 0.913, curbBonus = 1.071 } },
}
for _, case in cases do
	local options = {
		basePay = 66,
		toolFit = 1,
		qualityMultiplier = 1,
		speedMultiplier = 1,
		preference = "Balanced",
		crewBonus = 1,
		truckBonus = 1,
		businessBonus = 1,
		curbBonus = 1,
		penalty = 0,
		wonBack = 0,
		crew = 1,
	}
	for key, value in case[2] do
		options[key] = value
	end
	local result, weights = job(options)
	local lines, total = PayBreakdown.lines(result, weights)
	local sum = 0
	for _, payLine in lines do
		sum += payLine.amount
		check(payLine.amount == math.floor(payLine.amount), `{case[1]}: {payLine.label} isn't whole dollars`)
	end
	check(total == result.share, `{case[1]}: the total is {total}, not the share {result.share}`)
	check(sum == result.share, `{case[1]}: the lines add up to {sum}, not {result.share}`)
	check(lines[1].label == "Job pay" and lines[1].amount ~= 0, `{case[1]}: the job pay doesn't come first`)
end

-- The art's own files, when there's a copy to read ------------------------------------------------

local guiFolder = process.args[1] or "art-source/GUI"
if fs.isDir(guiFolder) then
	local manifest = serde.decode("json", fs.readFile(`{guiFolder}/manifest.json`))
	local uploads = 0
	for _, file in manifest.files do
		if file.role == "upload" then
			uploads += 1
			check(GuiArt.Images[file.path] ~= nil, `{file.path} is in the manifest but not in GuiArt`)
		end
	end
	check(uploads == imageCount, `the manifest has {uploads} images and GuiArt {imageCount}: run gui-art-ids.py`)
	for _, entry in manifest.bitmap_font_files do
		local font = GuiArt.Fonts[entry.name]
		check(font ~= nil, `GuiArt has no font {entry.name}`)
		if font then
			for _, layer in { entry.metrics, entry.outline_metrics } do
				local fnt = serde.decode("json", fs.readFile(`{guiFolder}/{layer}`))
				check(fnt.common.lineHeight == font.lineHeight, `{layer}: line height differs`)
				check(fnt.common.base == font.base, `{layer}: baseline differs`)
				check(fnt.info.size == font.size, `{layer}: size differs`)
				local count = 0
				for _, char in fnt.chars do
					count += 1
					local glyph = font.glyphs[char.id]
					check(
						glyph ~= nil
							and glyph[1] == char.x
							and glyph[2] == char.y
							and glyph[3] == char.width
							and glyph[4] == char.height
							and glyph[5] == char.xoffset
							and glyph[6] == char.yoffset
							and glyph[7] == char.xadvance,
						`{layer}: glyph {char.id} differs from GuiArt`
					)
				end
				local known = 0
				for _ in font.glyphs do
					known += 1
				end
				check(count == known, `{layer}: {count} glyphs, GuiArt has {known}`)
				for _, pair in fnt.kernings or {} do
					local kerns = font.kerning[pair.first]
					check(
						kerns ~= nil and kerns[pair.second] == pair.amount,
						`{layer}: kerning {pair.first}-{pair.second}`
					)
				end
			end
		end
	end
	print(`Checked GuiArt against {guiFolder}.`)
else
	print("No art-source/GUI here: pass the art's GUI folder to check GuiArt against its manifest and fonts.")
end

if failures > 0 then
	print(`{failures} check(s) failed.`)
	process.exit(1)
end
print("GUI checks passed.")
