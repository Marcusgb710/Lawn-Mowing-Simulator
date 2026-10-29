-- Checks the GUI overhaul's data and maths outside Roblox:
--   lune run scripts/check-gui [GUI folder]
-- It checks src/shared/Config/GuiArt.luau (written by scripts/gui-art-ids.py) fits together: ids
-- look like ids, every slice and font atlas is an image in the list, every glyph sits inside its
-- atlas, the numbers font's digits are all the same width and kerning only names glyphs that are
-- there. Every image the client asks for by name (Art.icon("Money"), Art.kit("Panel"),
-- UI.icon("Goal"), a button's Icon = "Lock", UI.wordmark, UI.stamp, Art.sheet...) has to be in it
-- too, and UI.luau's tables have a glyph for every tool tier, condition part and supply action.
-- Then the maths: setting text in the bitmap fonts (src/shared/GuiLayout.luau), the hold ring and
-- the striped fills, and the pay breakdown's lines adding up to what a job paid
-- (src/shared/PayBreakdown.luau). And src/client/UiLayout.luau, where everything on the play
-- screen goes (the layout editor rewrites it): every entry is the right shape (its scales sensible,
-- its touch and compact places only places, and nothing giving way to what gives way to it), only
-- the pieces HudController builds straight into a HUD column can leave it, and those are in their
-- column or have a place of their own on the screen (a touch screen's too), every element the
-- client places by name is in it, and every one in it is placed somewhere.
-- Given the art's GUI folder (or with art-source/GUI in this repo), it also reads the manifest
-- and the .fnt files again and checks GuiArt matches them exactly. Exits with an error if
-- anything's off.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local GuiArt = require("../src/shared/Config/GuiArt")
local GuiLayout = require("../src/shared/GuiLayout")
local PayBreakdown = require("../src/shared/PayBreakdown")
local UiLayout = require("../src/client/UiLayout")

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
			-- Glyphs asked for through UI: UI.icon("Goal"), a button's Icon = "Lock", a phone
			-- button's glyph.
			for _, pattern in
				{
					'UI%.icon%(%s*"([%w_]+)"',
					'%f[%w]Icon%s*=%s*"([%w_]+)"',
					'UI%.touchButton%(%s*"[^"]*"%s*,%s*"([%w_]+)"',
					'UI%.setTouchIcon%([^,]+,%s*"([%w_]+)"',
				}
			do
				for name in string.gmatch(source, pattern) do
					local image = `Icons/{name}.png`
					check(GuiArt.Images[image] ~= nil, `{path} asks for {image}, which isn't in GuiArt`)
				end
			end
			-- Wordmarks: UI.wordmark("JobComplete", ...), and the stamps in UI.stamp(parent, { ... }).
			local wordmarks = {}
			for name in string.gmatch(source, 'UI%.wordmark%(%s*"([%w_]+)"') do
				table.insert(wordmarks, name)
			end
			for stamps in string.gmatch(source, "UI%.stamp%([^{]*(%b{})") do
				for name in string.gmatch(stamps, '([%w_]+)%s*=%s*"') do
					table.insert(wordmarks, name)
				end
			end
			for _, name in wordmarks do
				local image = `Wordmarks/{name}.png`
				check(GuiArt.Images[image] ~= nil, `{path} asks for {image}, which isn't in GuiArt`)
			end
			for name in string.gmatch(source, 'Art%.sheet%("([%w_]+)"%)') do
				check(
					GuiArt.SpriteSheets[name] ~= nil,
					`{path} asks for the sprite sheet {name}, which isn't in GuiArt`
				)
			end
		end
	end
end
scan("src/client")

-- Glyphs the client picks from a table: a badge for every tool tier (Config/Tools.luau's Tiers),
-- a glyph for every part of a tool's condition (Maintenance.parts, but a supply's uses) and for
-- every supply's action (Maintenance.Supplies), in UI.luau's tables.
local uiSource = fs.readFile("src/client/UI.luau")
local function tableKeys(name: string): { [string]: boolean }
	local keys = {}
	local body = string.match(uiSource, `local {name} = (%b\{\})`)
	check(body ~= nil, `UI.luau has no {name} table`)
	for key in string.gmatch(body or "", "([%w_]+)%s*=") do
		keys[key] = true
	end
	return keys
end
local tiers = string.match(fs.readFile("src/shared/Config/Tools.luau"), "Tools%.Tiers%s*=%s*(%b{})")
check(tiers ~= nil, "Config/Tools.luau has no Tiers")
local tierGlyphs = tableKeys("TIERS")
for tier in string.gmatch(tiers or "", '"(%w+)"') do
	check(tierGlyphs[tier] == true, `UI.luau's TIERS has no badge for the {tier} tier`)
	check(GuiArt.Images[`Icons/Tier_{tier}.png`] ~= nil, `there's no Icons/Tier_{tier}.png for the {tier} tier`)
end
local maintenance = fs.readFile("src/shared/Config/Maintenance.luau")
local function each(pattern: string): { [string]: boolean }
	local found = {}
	for name in string.gmatch(maintenance, pattern) do
		found[name] = true
	end
	return found
end
local partGlyphs = tableKeys("PART_GLYPHS")
for part in each('add%("(%w+)"') do
	check(part == "Uses" or partGlyphs[part] == true, `UI.luau's PART_GLYPHS has no glyph for {part}`)
end
local actionGlyphs = tableKeys("ACTION_GLYPHS")
for action in each('action%s*=%s*"(%w+)"') do
	check(actionGlyphs[action] == true, `UI.luau's ACTION_GLYPHS has no glyph for {action}`)
end

-- UiLayout fits together -------------------------------------------------------------------------

-- What an entry can have, and what each one is (see UiLayout.luau's header).
local LAYOUT_FIELDS = {
	label = "string",
	group = "string",
	screen = "string",
	parent = "string",
	detach = "string",
	order = "number",
	list = "table",
	anchor = "table",
	position = "table",
	size = "table",
	autoSize = "string",
	min = "table",
	max = "table",
	scale = "number",
	typical = "table",
	touch = "table",
	compact = "table",
	hideWhile = "table",
	device = "string",
	fixed = "boolean",
	note = "string",
}
-- The pieces HudController builds straight into one of the HUD columns (placeInColumn), and the
-- column each one belongs in: only these can be taken out of a column (their `detach`). The menu
-- buttons and the rest are built inside these, so they stay where they are.
local COLUMN_PIECES = {
	MoneyPanel = "LeftColumn",
	MenuButtons = "LeftColumn",
	GrandmaGoal = "LeftColumn",
	CurbAppeal = "RightColumn",
	JobTracker = "RightColumn",
	MissedButton = "RightColumn",
}
-- How big or small a `scale` can be.
local SMALLEST_SCALE, BIGGEST_SCALE = 0.25, 3
-- Whether `value` is a list of `count` numbers.
local function isNumbers(value: any, count: number): boolean
	if typeof(value) ~= "table" or #value ~= count then
		return false
	end
	for _, number in value do
		if typeof(number) ~= "number" then
			return false
		end
	end
	return true
end
-- Whether `value` names other pieces in UiLayout, for a hideWhile.
local function isPieces(value: any, own: string): boolean
	if typeof(value) ~= "table" or #value == 0 then
		return false
	end
	for _, id in value do
		if typeof(id) ~= "string" or UiLayout[id] == nil or id == own or id == "__screen" then
			return false
		end
	end
	return true
end
-- An anchor, a position, a size and a scale, any of them left out, and (for the editor) a typical
-- size in a piece's touch and compact places, and what it gives way to there. A touch place can
-- also take a HUD column's piece out of its column or put it in (its parent).
local function checkPlaces(where: string, places: { [string]: any }, typical: boolean?, id: string?, touch: boolean?)
	for key, place in places do
		if key == "hideWhile" and id then
			check(isPieces(place, id), `{where}: its hideWhile isn't a list of other pieces in UiLayout`)
		elseif key == "parent" and touch then
			check(place == false or typeof(place) == "string", `{where}: its parent isn't false or a column`)
		elseif key == "anchor" then
			check(isNumbers(place, 2), `{where}: its anchor isn't two numbers`)
		elseif key == "position" or key == "size" then
			check(isNumbers(place, 4), `{where}: its {key} isn't a UDim2's four numbers`)
		elseif key == "scale" then
			check(
				typeof(place) == "number" and place >= SMALLEST_SCALE and place <= BIGGEST_SCALE,
				`{where}: its scale isn't a number from {SMALLEST_SCALE} to {BIGGEST_SCALE}`
			)
		elseif key == "typical" and typical then
			check(isNumbers(place, 2), `{where}: its typical isn't a width and a height`)
		else
			check(false, `{where} has {key}, which isn't an anchor, position, size or scale`)
		end
	end
end
local screens = UiLayout.__screen.screens
for id, entry in UiLayout do
	if id == "__screen" then
		continue
	end
	local where = `UiLayout's {id}`
	for field, value in entry do
		local kind = LAYOUT_FIELDS[field]
		check(kind ~= nil, `{where} has {field}, which the layout editor doesn't know`)
		check(kind == nil or typeof(value) == kind, `{where}: its {field} isn't a {kind}`)
	end
	for _, field in { "label", "group", "note" } do
		check(entry[field] ~= nil and entry[field] ~= "", `{where} has no {field}`)
	end
	check(entry.size ~= nil, `{where} has no size`)
	checkPlaces(where, { anchor = entry.anchor, position = entry.position, size = entry.size, scale = entry.scale })
	local touch = if typeof(entry.touch) == "table" then entry.touch else {}
	checkPlaces(`{where}'s touch places`, touch, true, id, true)
	checkPlaces(`{where}'s compact places`, if typeof(entry.compact) == "table" then entry.compact else {}, true, id)
	if entry.hideWhile ~= nil then
		check(isPieces(entry.hideWhile, id), `{where}: its hideWhile isn't a list of other pieces in UiLayout`)
	end
	local parent = entry.parent and UiLayout[entry.parent]
	if entry.parent then
		check(parent ~= nil, `{where} is in {entry.parent}, which isn't in UiLayout`)
		check(entry.screen == nil, `{where} is in {entry.parent}, so it has no screen of its own`)
		if parent and parent.list then
			check(entry.order ~= nil, `{where} has no order in {entry.parent}'s list`)
			check(entry.position == nil, `{where} has a position, but {entry.parent}'s list places it`)
		end
	else
		check(screens[entry.screen or ""] ~= nil, `{where} isn't on one of __screen.screens`)
	end
	-- A piece that can leave its column: it's one HudController builds into that column, and it's
	-- either in it or out on the game's own screen with a place of its own there.
	local home = COLUMN_PIECES[id]
	if entry.detach ~= nil then
		check(
			entry.detach == "LeftColumn" or entry.detach == "RightColumn",
			`{where}: its detach is {entry.detach}, not LeftColumn or RightColumn`
		)
		check(home ~= nil, `{where} has a detach, but HudController doesn't build it straight into a HUD column`)
		check(home == nil or entry.detach == home, `{where}: its detach is {entry.detach}, but it's built into {home}`)
		check(entry.order ~= nil, `{where} has no order to go back into {entry.detach} at`)
		if entry.parent then
			check(entry.parent == entry.detach, `{where} is in {entry.parent}, but its column is {entry.detach}`)
		else
			check(entry.screen == "LawnUI", `{where} is out of its column, so it goes on LawnUI, the game's own screen`)
			check(
				entry.anchor ~= nil and entry.position ~= nil,
				`{where} is out of its column, so it needs an anchor and a position on the screen`
			)
		end
	elseif home then
		check(false, `{where} has no detach: the editor needs to know it belongs in {home}`)
	end
	-- Its own place on a touch screen: in its column or out of it, with a place on the screen then.
	if touch.parent ~= nil then
		check(entry.detach ~= nil, `{where} has a touch parent, but it isn't a HUD column's piece (no detach)`)
		check(
			touch.parent == false or touch.parent == entry.detach,
			`{where}: its touch parent is {touch.parent}, not false or its column {entry.detach}`
		)
		if touch.parent == false and entry.parent then
			check(
				touch.anchor ~= nil and touch.position ~= nil,
				`{where} is out of its column on a touch screen, so it needs a touch anchor and position`
			)
		end
	end
	-- A BillboardGui in the world only has its size placed, so it can't be scaled.
	if entry.screen == "World" then
		local scaled = entry.scale ~= nil
			or (typeof(entry.touch) == "table" and entry.touch.scale ~= nil)
			or (typeof(entry.compact) == "table" and entry.compact.scale ~= nil)
		check(not scaled, `{where} is in the world, where only its size is placed: it can't have a scale`)
	end
	check(entry.autoSize == nil or table.find({ "X", "Y", "XY" }, entry.autoSize) ~= nil, `{where}: odd autoSize`)
	check(entry.device == nil or entry.device == "touch" or entry.device == "keyboard", `{where}: odd device`)
	check(entry.typical == nil or isNumbers(entry.typical, 2), `{where}: typical isn't a width and a height`)
	for _, side in { "min", "max" } do
		for key, value in entry[side] or {} do
			check(
				(key == "width" or key == "height") and typeof(value) == "number",
				`{where}: its {side} has {key}, not a width or height in pixels`
			)
		end
	end
	local list = entry.list
	if list then
		check(list.direction == "Vertical" or list.direction == "Horizontal", `{where}: odd list direction`)
		check(typeof(list.padding) == "number", `{where}'s list has no padding`)
		check(table.find({ "Left", "Center", "Right" }, list.align) ~= nil, `{where}: odd list align`)
	end
end
-- Nothing gives way to something that gives way to it (one of them would never show).
local function givesWayTo(id: string): { [string]: boolean }
	local entry = UiLayout[id]
	local out = {}
	for _, places in { entry, entry.touch or {}, entry.compact or {} } do
		for _, other in (places :: any).hideWhile or {} do
			out[other] = true
		end
	end
	return out
end
for id in UiLayout do
	if id ~= "__screen" then
		for other in givesWayTo(id) do
			check(
				UiLayout[other] == nil or not givesWayTo(other)[id],
				`UiLayout's {id} and {other} each give way to the other (hideWhile)`
			)
		end
	end
end

for name, rule in UiLayout.__screen.scaling do
	for _, id in rule.elements do
		check(UiLayout[id] ~= nil, `__screen.scaling.{name} scales {id}, which isn't in UiLayout`)
	end
end
for _, key in { "fullHeight", "minScale", "tightScale", "margin", "touchMargin" } do
	local value = UiLayout.__screen.scaling.Columns[key]
	check(typeof(value) == "number" and value >= 0, `__screen.scaling.Columns has no {key}`)
end
check(typeof(UiLayout.__screen.compactHeight) == "number", "__screen has no compactHeight")

-- COLUMN_PIECES is what HudController builds into a column: every piece it puts in one with
-- placeInColumn, and nothing else.
local hudSource = fs.readFile("src/client/Controllers/HudController.luau")
local inColumns: { [string]: boolean } = {}
for id in string.gmatch(hudSource, 'placeInColumn%(%s*[%w_]+%s*,%s*"([%w_]+)"%s*%)') do
	inColumns[id] = true
	check(COLUMN_PIECES[id] ~= nil, `HudController puts {id} in a column, but check-gui's COLUMN_PIECES hasn't got it`)
end
for id in COLUMN_PIECES do
	check(inColumns[id] == true, `HudController doesn't build {id} into a column (with placeInColumn)`)
end

-- Every element the client places by name (UI.place, UI.keepPlaced, UI.layout) is in UiLayout,
-- and every one in it is named somewhere in the client, so none are left over.
local named: { [string]: boolean } = {}
local function scanPlaces(folder: string)
	for _, name in fs.readDir(folder) do
		local path = `{folder}/{name}`
		if fs.isDir(path) then
			scanPlaces(path)
		elseif string.match(name, "%.luau$") and name ~= "UiLayout.luau" then
			local source = fs.readFile(path)
			for _, pattern in
				{
					'UI%.place%([^,]+,%s*"([%w_]+)"',
					'UI%.keepPlaced%([^,]+,%s*"([%w_]+)"',
					'placeInColumn%([^,]+,%s*"([%w_]+)"',
					'UI%.layout%(%s*"([%w_]+)"',
				}
			do
				for id in string.gmatch(source, pattern) do
					check(UiLayout[id] ~= nil, `{path} places {id}, which isn't in UiLayout`)
				end
			end
			for word in string.gmatch(source, '"([%w_]+)"') do
				named[word] = true
			end
		end
	end
end
scanPlaces("src/client")
for id in UiLayout do
	check(id == "__screen" or named[id] == true, `UiLayout's {id} isn't placed anywhere in src/client`)
end

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
