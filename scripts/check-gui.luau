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
-- client places by name is in it, and every one in it is placed somewhere; what stands along the
-- bottom keeps clear of the game's own hotbar, and nothing in the client turns Roblox's Backpack
-- back on. And src/client/
-- JuicyPalette.luau, the front-page HUD's colours: each face lighter at the top, the ink darker
-- than all of them.
-- Given the art's GUI folder (or with art-source/GUI in this repo), it also reads the manifest
-- and the .fnt files again and checks GuiArt matches them exactly. Exits with an error if
-- anything's off.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local GuiArt = require("../src/shared/Config/GuiArt")
local GuiLayout = require("../src/shared/GuiLayout")
local HotbarFit = require("../src/shared/HotbarFit")
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
			-- Wordmarks: UI.wordmark("JobComplete", ...), and the stamps in UI.stamp(parent, { ... }), not
			-- UI.stampText(parent, text, height), which is words only and asks for no art.
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
	compactOnly = "boolean",
	note = "string",
}
-- The pieces HudController builds straight into one of the HUD columns (placeInColumn), and the
-- column each one belongs in: only these can be taken out of a column (their `detach`). The menu
-- buttons and the rest are built inside these, so they stay where they are.
local COLUMN_PIECES = {
	MoneyPanel = "LeftColumn",
	StatPills = "LeftColumn",
	Countdown = "LeftColumn",
	MenuButtons = "LeftColumn",
	GrandmaGoal = "LeftColumn",
	CurbAppeal = "RightColumn",
	NextChip = "RightColumn",
	JobTracker = "RightColumn",
	BoostPills = "RightColumn",
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
-- No two pieces of a HUD column have the same order: the column's list sorts by LayoutOrder, and a
-- tie falls to the order the pieces were made in, which nothing here says.
for _, column in { "LeftColumn", "RightColumn" } do
	local taken: { [number]: string } = {}
	for id, entry in UiLayout do
		if id ~= "__screen" and entry.parent == column and typeof(entry.order) == "number" then
			local other = taken[entry.order]
			check(other == nil, `UiLayout's {id} and {other} are both order {entry.order} in {column}`)
			taken[entry.order] = id
		end
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

-- The goals rail's Next chip (Busy Season, slice 1): the rail's next milestone on one line, in the
-- right column, for the short screens where the rail itself is hidden. Curb appeal hides during a
-- job on a short screen, but the chip is its own piece and nothing hides it, so no entry's
-- hideWhile (in its place, its touch ones or its compact ones) names it. Grandma's goal, which
-- carries the rail on a tall screen, still gives way to the first-job coach and a crew invite on a
-- touch screen.
local nextChip = UiLayout.NextChip
check(nextChip ~= nil, "UiLayout has no NextChip")
if nextChip then
	check(nextChip.parent == "RightColumn", `UiLayout's NextChip is in {nextChip.parent}, not the RightColumn`)
	check(nextChip.detach == "RightColumn", "UiLayout's NextChip can't be taken out of and put back in the RightColumn")
	check(nextChip.compactOnly == true, "UiLayout's NextChip isn't compactOnly: it would show on a tall screen too")
	check(nextChip.hideWhile == nil, "UiLayout's NextChip gives way to something: it has to show during a job")
	-- Not in its touch or compact places either: the editor reads those too (the game would never
	-- honour them, since the HUD doesn't call UI.givesWay("NextChip")).
	for place, places in { touch = nextChip.touch or {}, compact = nextChip.compact or {} } do
		check(
			(places :: any).hideWhile == nil,
			`UiLayout's NextChip gives way to something on {place} screens: it has to show during a job`
		)
	end
end
for id, entry in UiLayout do
	if id ~= "__screen" then
		for place, places in { whole = entry, touch = entry.touch or {}, compact = entry.compact or {} } do
			check(
				table.find((places :: any).hideWhile or {}, "NextChip") == nil,
				`UiLayout's {id} ({place}) hides while NextChip shows, which would hide it during a job`
			)
		end
	end
end

-- Grandma's goal (front-page HUD, ruling 3): a cream banner at the top in the middle on every screen,
-- up to 330 wide and as tall as its words, out of the left column (it is still a piece the editor can put
-- back there: its detach). It shares the top with the first-job coach and a crew invite, one at a
-- time, so it waits for both on every screen, not only a touch one.
local BANNER_GAP = 12
local grandma = UiLayout.GrandmaGoal
check(grandma ~= nil, "UiLayout has no GrandmaGoal")
if grandma then
	check(grandma.parent == nil, `UiLayout's GrandmaGoal is in {grandma.parent}: the banner is out of the columns`)
	check(grandma.detach == "LeftColumn", "UiLayout's GrandmaGoal can't be put back in the LeftColumn")
	check(grandma.screen == "LawnUI", "UiLayout's GrandmaGoal isn't on LawnUI, the game's own screen")
	check(
		grandma.anchor ~= nil and grandma.anchor[1] == 0.5 and grandma.anchor[2] == 0,
		"UiLayout's GrandmaGoal isn't anchored at the top in the middle"
	)
	check(
		grandma.position ~= nil
			and grandma.position[1] == 0.5
			and grandma.position[2] == 0
			and grandma.position[3] == 0
			and grandma.position[4] == 12,
		"UiLayout's GrandmaGoal isn't 12 px down from the top, in the middle"
	)
	-- Its width is what is left between the columns: the screen less twice the right column's reach from
	-- the edge (the strip, the gaps and the column itself) and a gap to keep from it, never wider than
	-- 330 nor narrower than 240. That is the piece's base size, which is a PC's and a tall touch screen's;
	-- the short screens have their own (see the screens check below).
	local rightColumn = UiLayout.RightColumn
	local bannerReach = -rightColumn.position[2] + rightColumn.size[2] + BANNER_GAP
	check(
		grandma.size ~= nil and grandma.size[1] == 1 and grandma.size[2] == -2 * bannerReach,
		`UiLayout's GrandmaGoal isn't the screen's width less {2 * bannerReach} px (twice the right column's reach from the edge, {-rightColumn.position[2] + rightColumn.size[2]}, and a {BANNER_GAP} px gap)`
	)
	check(
		grandma.max ~= nil and grandma.max.width == 330 and grandma.min ~= nil and grandma.min.width == 240,
		"UiLayout's GrandmaGoal isn't between 240 and 330 px wide"
	)
	check(grandma.autoSize == "Y", "UiLayout's GrandmaGoal doesn't grow with its words")
	check(
		grandma.touch == nil or grandma.touch.parent == nil,
		"UiLayout's GrandmaGoal has a touch parent: its place is the same on every screen"
	)
	local grandmaWaits = grandma.hideWhile
	check(
		grandmaWaits ~= nil and table.find(grandmaWaits, "TutorialBanner") ~= nil,
		"UiLayout's GrandmaGoal doesn't wait for the TutorialBanner"
	)
	check(
		grandmaWaits ~= nil and table.find(grandmaWaits, "CrewInvite") ~= nil,
		"UiLayout's GrandmaGoal doesn't wait for the CrewInvite"
	)
end

-- The boost pills (front-page HUD, ruling 3): the crew, curb appeal, truck and business pay bonuses as
-- pills in the right column, straight under the job tracker (the Show what I missed button goes under
-- them). They show during a job and hide when no bonus applies, which HudController decides, so
-- nothing in UiLayout hides them.
local boosts = UiLayout.BoostPills
check(boosts ~= nil, "UiLayout has no BoostPills")
if boosts then
	check(boosts.parent == "RightColumn", `UiLayout's BoostPills is in {boosts.parent}, not the RightColumn`)
	check(boosts.detach == "RightColumn", "UiLayout's BoostPills can't be taken out of and put back in the RightColumn")
	check(
		typeof(boosts.order) == "number" and boosts.order == UiLayout.JobTracker.order + 1,
		"UiLayout's BoostPills isn't the piece right after the JobTracker"
	)
	check(
		typeof(boosts.order) == "number" and UiLayout.MissedButton.order > boosts.order,
		"UiLayout's MissedButton isn't after the BoostPills"
	)
	check(boosts.hideWhile == nil, "UiLayout's BoostPills gives way to something: HudController hides it")
	check(
		boosts.list ~= nil and boosts.list.direction == "Horizontal" and boosts.list.align == "Right",
		"UiLayout's BoostPills isn't a right-aligned row of pills"
	)
	check(boosts.autoSize == "Y", "UiLayout's BoostPills doesn't grow when its pills wrap to a second row")
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

-- The Levels panel (Busy Season, slice 1): a centred window of its own on the game's screen, opened
-- from the XP bar, that shrinks to fit like the pay breakdown does. Centred, it's already clear of
-- Roblox's move stick and jump button, so a touch screen has the same top margin, and `scale` is the
-- most it's drawn at. (On a touch or short screen it also stands above the hotbar: see the hotbar rules below.)
local levelsPanel = UiLayout.LevelsPanel
check(levelsPanel ~= nil, "UiLayout has no LevelsPanel")
if levelsPanel then
	check(levelsPanel.screen == "LawnUI", `UiLayout's LevelsPanel is on {levelsPanel.screen}, not LawnUI`)
	check(levelsPanel.parent == nil, "UiLayout's LevelsPanel is in another element: it's a window of its own")
	check(
		levelsPanel.size ~= nil and levelsPanel.size[2] == 360 and levelsPanel.size[4] == 460,
		"UiLayout's LevelsPanel isn't 360 by 460"
	)
	check(levelsPanel.autoSize == nil, "UiLayout's LevelsPanel grows with what's in it: it's 460 tall")
end
local levelsRule = UiLayout.__screen.scaling.LevelsPanel
check(levelsRule ~= nil, "__screen.scaling has no LevelsPanel")
if levelsRule then
	check(
		table.find(levelsRule.elements, "LevelsPanel") ~= nil,
		"__screen.scaling.LevelsPanel doesn't scale the LevelsPanel"
	)
	check(
		typeof(levelsRule.margin) == "number" and levelsRule.margin >= 0,
		"__screen.scaling.LevelsPanel has no margin"
	)
	check(
		typeof(levelsRule.touchMargin) == "number" and levelsRule.touchMargin == levelsRule.margin,
		"__screen.scaling.LevelsPanel's touchMargin isn't its margin: the top margin is the same on a touch screen"
	)
	check(
		typeof(levelsRule.scale) == "number" and levelsRule.scale > 0 and levelsRule.scale <= 1,
		"__screen.scaling.LevelsPanel has no scale from above 0 to 1"
	)
end

-- The contracts panel and its chip (Busy Season, slice 2). The panel is the Levels panel's twin: a
-- centred window of its own that shrinks to fit by the same rule (the same margins, a touch screen's
-- top margin the same as any other's, and the same place above the hotbar there). The chip is the
-- left column's last piece, under Grandma's goal, and it shows on every screen, through a job too:
-- nothing hides it and it isn't compactOnly, so no entry's hideWhile (in its place, its touch ones
-- or its compact ones) names it, and it has an order of its own in the column.
do
	local panel = UiLayout.ContractsPanel
	check(panel ~= nil, "UiLayout has no ContractsPanel")
	if panel then
		check(panel.screen == "LawnUI", `UiLayout's ContractsPanel is on {panel.screen}, not LawnUI`)
		check(panel.parent == nil, "UiLayout's ContractsPanel is in another element: it's a window of its own")
		check(
			panel.size ~= nil and panel.size[2] == 360 and panel.size[4] == 400,
			"UiLayout's ContractsPanel isn't 360 by 400"
		)
		check(panel.autoSize == nil, "UiLayout's ContractsPanel grows with what's in it: it's 400 tall")
	end
	local rule = UiLayout.__screen.scaling.ContractsPanel
	check(rule ~= nil, "__screen.scaling has no ContractsPanel")
	if rule then
		check(
			table.find(rule.elements, "ContractsPanel") ~= nil,
			"__screen.scaling.ContractsPanel doesn't scale the ContractsPanel"
		)
		check(rule.margin == 24, "__screen.scaling.ContractsPanel's margin isn't 24, the Levels panel's")
		check(
			typeof(rule.touchMargin) == "number" and rule.touchMargin == rule.margin,
			"__screen.scaling.ContractsPanel's touchMargin isn't its margin: the top margin is the same on a touch screen"
		)
		check(
			typeof(rule.scale) == "number" and rule.scale > 0 and rule.scale <= 1,
			"__screen.scaling.ContractsPanel has no scale from above 0 to 1"
		)
	end

	-- The Contracts square (front-page HUD, ruling 5) replaced the Contracts chip: it is the fourth menu
	-- square, inside MenuButtons, and like the chip it shows on every screen and nothing takes its spot,
	-- a job included. Its order is its own in the MenuButtons list.
	check(UiLayout.ContractsChip == nil, "UiLayout still has the ContractsChip: the Contracts square replaced it")
	local contractsButton = UiLayout.ContractsButton
	check(contractsButton ~= nil, "UiLayout has no ContractsButton")
	if contractsButton then
		check(
			contractsButton.parent == "MenuButtons",
			`UiLayout's ContractsButton is in {contractsButton.parent}, not MenuButtons`
		)
		check(
			contractsButton.detach == nil,
			"UiLayout's ContractsButton has a detach: it is one of MenuButtons' squares"
		)
		check(contractsButton.compactOnly == nil, "UiLayout's ContractsButton is compactOnly: it shows on every screen")
		check(typeof(contractsButton.order) == "number", "UiLayout's ContractsButton has no order in MenuButtons")
		for other, entry in UiLayout do
			if other ~= "__screen" and other ~= "ContractsButton" and entry.parent == "MenuButtons" then
				check(
					entry.order ~= contractsButton.order,
					`UiLayout's ContractsButton and {other} are both order {contractsButton.order} in MenuButtons`
				)
			end
		end
	end
	for id, entry in UiLayout do
		if id ~= "__screen" then
			for place, places in { whole = entry, touch = entry.touch or {}, compact = entry.compact or {} } do
				if id == "ContractsButton" then
					check(
						(places :: any).hideWhile == nil,
						`UiLayout's ContractsButton ({place}) gives way to something: it shows on every screen`
					)
				end
				check(
					table.find((places :: any).hideWhile or {}, "ContractsButton") == nil,
					`UiLayout's {id} ({place}) hides while ContractsButton shows, which would hide it during a job`
				)
			end
		end
	end
end

-- The money pill and the pills under it (front-page HUD, ruling 3): the money pill is 250 by 70, the
-- level pill 136 by 36 and the streak pill 106 by 36 side by side (with the 8 px gap that makes the
-- column's 250), the countdown pill 250 by 34. Each piece's entry is its face plus the 6 px its lip and
-- outline hang below it, and they come first in the left column, in that order, ahead of the menu
-- buttons and Grandma's goal.
do
	local LIP_ROOM = 6
	local PILL_PIECES = {
		{ id = "MoneyPanel", order = 1, face = 70 },
		{ id = "StatPills", order = 2, face = 36 },
		{ id = "Countdown", order = 3, face = 34 },
	}
	local LEVEL_PILL, STREAK_PILL, PILL_GAP = 136, 106, 8
	local lastPill = 0
	for _, want in PILL_PIECES do
		local entry = UiLayout[want.id]
		check(entry ~= nil, `UiLayout has no {want.id}`)
		if entry then
			check(entry.parent == "LeftColumn", `UiLayout's {want.id} is in {entry.parent}, not the LeftColumn`)
			check(
				entry.detach == "LeftColumn",
				`UiLayout's {want.id} can't be taken out of and put back in the LeftColumn`
			)
			check(entry.order == want.order, `UiLayout's {want.id} is order {entry.order}, not {want.order}`)
			check(
				entry.size ~= nil
					and entry.size[1] == 0
					and entry.size[2] == 250
					and entry.size[3] == 0
					and entry.size[4] == want.face + LIP_ROOM,
				`UiLayout's {want.id} isn't 250 by {want.face + LIP_ROOM} (a {want.face} px face and {LIP_ROOM} px for its lip)`
			)
			check(entry.autoSize == nil, `UiLayout's {want.id} grows with what's in it: its height is the pill's`)
			lastPill = math.max(lastPill, entry.order or 0)
		end
	end
	local row = UiLayout.StatPills
	if row then
		check(
			row.list ~= nil and row.list.direction == "Horizontal" and row.list.padding == PILL_GAP,
			`UiLayout's StatPills isn't a row with {PILL_GAP} px between the pills`
		)
		check(
			LEVEL_PILL + PILL_GAP + STREAK_PILL == 250,
			"the level and streak pills with their gap aren't the column's 250"
		)
	end
	for id, entry in UiLayout do
		if
			id ~= "__screen"
			and entry.parent == "LeftColumn"
			and not table.find({ "MoneyPanel", "StatPills", "Countdown" }, id)
		then
			check(
				typeof(entry.order) == "number" and entry.order > lastPill,
				`UiLayout's {id} comes before the pills in the LeftColumn`
			)
		end
	end
end

-- The hotbar (front-page HUD, ruling 10): the game's own (HotbarController), in place of Roblox's
-- Backpack, which stays off. It stands along the bottom middle of the game's screen, its bottom
-- edge 8 px up: a row of slots 60 px square on a PC and 48 on a touch or short screen, 8 px apart,
-- each with room round it for its ink outline (4 px a side) and the held slot's lip (6 px under it),
-- so 74 or 62 px tall in all. That is its tallest: HotbarController only ever draws the row smaller,
-- to fit the screen's width (the tray of tools that didn't fit, open above it, isn't part of the
-- band and may cover the tool condition chips while it's open). A slot for every tool, at least five,
-- so its width is the controller's to set: its entry has no list or autoSize, which would fight the
-- slots the controller places itself. What stands along the bottom keeps clear of it on every kind of screen
-- (a PC, a touch screen, a short one, a short touch one): the tool condition chips stand above its
-- top edge with a gap (a wider one on a touch screen, so a tap on a chip never lands on a slot), the
-- Levels and contracts windows' bottom edges stand above it on a touch or short screen (bottom edge
-- anchored, so a tap on their Close button never lands on a slot: it did, on Roblox's Grass Shears
-- slot), and the carry hint, which sits lower down, gives way to it. A short screen's place carries
-- its own anchor, since a short screen that isn't a touch screen has no touch place to give it one.
-- The faces, the gap and the room round a face are HotbarFit's (checked below to be 60, 48, 8 and 14).
local HOTBAR_BOTTOM = 8
local HOTBAR_GAP_BETWEEN = 8
local HOTBAR_ROOM = HotbarFit.ROOM
local HOTBAR_FACE = {
	pc = HotbarFit.PC_FACE,
	touch = HotbarFit.SMALL_FACE,
	compact = HotbarFit.SMALL_FACE,
	touchCompact = HotbarFit.SMALL_FACE,
}
local HOTBAR_CLEARANCE = { pc = 6, touch = 16, compact = 6, touchCompact = 6 }
local SCREEN_KINDS = { "pc", "touch", "compact", "touchCompact" }
-- An entry's `field` on a kind of screen: its own, its touch one over it on a touch screen, and its
-- compact one over those on a short screen, the way UI.layout and the editor pick them.
local function placedOn(entry, kind: string, field: string): any
	local value = entry[field]
	local touch = entry.touch
	if (kind == "touch" or kind == "touchCompact") and typeof(touch) == "table" and touch[field] ~= nil then
		value = touch[field]
	end
	local compact = entry.compact
	if (kind == "compact" or kind == "touchCompact") and typeof(compact) == "table" and compact[field] ~= nil then
		value = compact[field]
	end
	return value
end
-- How far up from the screen's bottom the hotbar's top edge is on each kind of screen (left out where
-- its place there isn't the shape these rules need: a fail says which).
local hotbarTop: { [string]: number } = {}
do
	local bar = UiLayout.Hotbar
	check(bar ~= nil, "UiLayout has no Hotbar: the game's own hotbar needs a place")
	if bar then
		check(bar.screen == "LawnUI", `UiLayout's Hotbar is on {bar.screen}, not LawnUI, the game's own screen`)
		check(bar.parent == nil, "UiLayout's Hotbar is in another element: it stands on the screen")
		check(
			bar.autoSize == nil and bar.list == nil,
			"UiLayout's Hotbar has a list or an autoSize: HotbarController places its slots and sets its width"
		)
		for _, kind in SCREEN_KINDS do
			local anchor = placedOn(bar, kind, "anchor")
			local position = placedOn(bar, kind, "position")
			local size = placedOn(bar, kind, "size")
			local height = HOTBAR_FACE[kind] + HOTBAR_ROOM
			local centred = isNumbers(anchor, 2)
				and anchor[1] == 0.5
				and anchor[2] == 1
				and isNumbers(position, 4)
				and position[1] == 0.5
				and position[2] == 0
				and position[3] == 1
				and position[4] == -HOTBAR_BOTTOM
			check(
				centred,
				`UiLayout's Hotbar isn't centred at the bottom, its bottom edge {HOTBAR_BOTTOM} px up, on a {kind} screen`
			)
			local sized = isNumbers(size, 4) and size[1] == 0 and size[2] == 0 and size[3] == 0 and size[4] == height
			check(
				sized,
				`UiLayout's Hotbar isn't {height} px tall on a {kind} screen ({HOTBAR_FACE[kind]} px slots, {HOTBAR_ROOM} px round them)`
			)
			if centred and sized then
				hotbarTop[kind] = HOTBAR_BOTTOM + height
			end
		end
	end

	-- The tool condition chips: placed by their bottom edge, above the hotbar's top with the gap.
	local chips = UiLayout.ToolCondition
	for _, kind in SCREEN_KINDS do
		local top = hotbarTop[kind]
		local anchor = placedOn(chips, kind, "anchor")
		local position = placedOn(chips, kind, "position")
		check(
			isNumbers(anchor, 2) and anchor[2] == 1 and isNumbers(position, 4) and position[3] == 1,
			`UiLayout's ToolCondition isn't placed by its bottom edge from the screen's bottom on a {kind} screen`
		)
		if top and isNumbers(position, 4) then
			local clearance = HOTBAR_CLEARANCE[kind]
			check(
				-position[4] >= top + clearance,
				`UiLayout's ToolCondition is {-position[4]} px up on a {kind} screen, but the hotbar's top is {top} px up and the chips stand {clearance} px above it`
			)
		end
	end

	-- The Levels and contracts windows: centred on a PC, their bottom edge above the hotbar elsewhere.
	for _, id in { "LevelsPanel", "ContractsPanel" } do
		local entry = UiLayout[id]
		for _, kind in { "touch", "compact", "touchCompact" } do
			local anchor = placedOn(entry, kind, "anchor")
			local position = placedOn(entry, kind, "position")
			check(
				isNumbers(anchor, 2) and anchor[1] == 0.5 and anchor[2] == 1,
				`UiLayout's {id} isn't anchored at its bottom edge on a {kind} screen`
			)
			local top = hotbarTop[kind]
			check(
				top ~= nil
					and isNumbers(position, 4)
					and position[1] == 0.5
					and position[2] == 0
					and position[3] == 1
					and -position[4] >= top,
				`UiLayout's {id} isn't above the hotbar on a {kind} screen: Close is over a slot`
			)
		end
		check(
			entry.anchor[1] == 0.5
				and entry.anchor[2] == 0.5
				and entry.position[1] == 0.5
				and entry.position[3] == 0.5
				and entry.position[2] == 0
				and entry.position[4] == 0,
			`UiLayout's {id} isn't centred on a screen that is neither touch nor short`
		)
	end

	-- The carry hint sits lower than the hotbar's top, so it gives way to it on every kind of screen
	-- (carrying a supply on a job is the only time both are wanted at once).
	for _, kind in SCREEN_KINDS do
		local gives = placedOn(UiLayout.CarryHint, kind, "hideWhile")
		check(
			typeof(gives) == "table" and table.find(gives, "Hotbar") ~= nil,
			`UiLayout's CarryHint doesn't give way to the Hotbar on a {kind} screen (its hideWhile)`
		)
	end
end

-- The hotbar's numbers and its fit to the screen (src/shared/HotbarFit.luau, front-page HUD Task 8),
-- the very functions HotbarController draws with. Every tool gets a slot: at least five are drawn
-- and nothing caps them. Keys 1 to 9 and 0 take out the first ten. A slot is the band's sizes (the
-- gap, and the outline and lip round a face). The row is fitted to the screen's width, never drawn
-- bigger than its entry, never with a face under 40 px on a touch screen or 48 on a PC, kept 120 px
-- in from a touch screen's sides (the move stick and the jump button) and 24 from a PC's; past that
-- floor the last slot is a "+N" for the rest. Each worked case's numbers are written out here, so a
-- change to the arithmetic shows. Then what HotbarController must do with it: use these functions
-- for every number (no fit, cap or key of its own), draw the gold "+N" and its tray, keep the place
-- of a tool set down to be worked on (Servicing), close an open tray on a click or tap that no button
-- took, and keep its buttons out of gamepad selection (L1 and R1 are the gamepad's way through).
do
	local expected = {
		PC_FACE = 60,
		SMALL_FACE = 48,
		STROKE = 4,
		LIP = 6,
		ROOM = 14,
		GAP = 8,
		MIN_SLOTS = 5,
		KEY_COUNT = 10,
		TOUCH_SIDE = 120,
		PC_SIDE = 24,
		TOUCH_FLOOR = 40,
		PC_FLOOR = 48,
	}
	for name, value in expected do
		check(HotbarFit[name] == value, `HotbarFit.{name} is {HotbarFit[name]}, not {value}`)
	end
	check(HotbarFit.ROOM == HotbarFit.STROKE * 2 + HotbarFit.LIP, "HotbarFit.ROOM isn't two outlines and the lip")
	check(HotbarFit.GAP == HOTBAR_GAP_BETWEEN, `HotbarFit.GAP isn't the band's {HOTBAR_GAP_BETWEEN} px`)

	check(HotbarFit.faceFor(74) == 60 and HotbarFit.faceFor(62) == 48, "HotbarFit.faceFor isn't the height less 14")
	check(
		HotbarFit.cellWidth(60) == 68 and HotbarFit.cellWidth(48) == 56,
		"HotbarFit.cellWidth isn't a face and two outlines"
	)
	check(
		HotbarFit.cellHeight(60) == 74 and HotbarFit.cellHeight(48) == 62,
		"HotbarFit.cellHeight isn't a face and ROOM"
	)
	check(
		HotbarFit.rowWidth(5, 48) == 312 and HotbarFit.rowWidth(1, 60) == 68 and HotbarFit.rowWidth(0, 60) == 0,
		"HotbarFit.rowWidth isn't the slots and the gaps between them"
	)
	for places, drawn in { [0] = 5, [3] = 5, [5] = 5, [14] = 14, [30] = 30 } do
		check(
			HotbarFit.drawnCount(places) == drawn,
			`HotbarFit.drawnCount({places}) is {HotbarFit.drawnCount(places)}, not {drawn}: at least five, and a slot for every place`
		)
	end
	for place, key in { [1] = "1", [5] = "5", [9] = "9", [10] = "0" } do
		check(HotbarFit.keyFor(place) == key, `HotbarFit.keyFor({place}) isn't "{key}"`)
	end
	for _, place in { 0, 11, 14 } do
		check(HotbarFit.keyFor(place) == nil, `HotbarFit.keyFor({place}) is a key: only the first ten have one`)
	end

	-- { screen width, tools, touch, face, scale, slots shown, "+N" }. 0 wide is a screen not measured
	-- yet. 844, 740, 667 and 663 are phones held sideways (663: one slot fits only with the gap after
	-- the last one counted); 300 is narrower than any, still a tool and the "+N"; 1280 is a PC.
	local small = HotbarFit.TOUCH_FLOOR / HotbarFit.SMALL_FACE
	local cases = {
		{ 0, 14, true, 48, 1, 14, false },
		{ 844, 5, true, 48, 1, 5, false },
		{ 844, 10, true, 48, 604 / 632, 10, false },
		{ 844, 14, true, 48, small, 11, true },
		{ 740, 14, true, 48, small, 9, true },
		{ 667, 14, true, 48, small, 8, true },
		{ 663, 14, true, 48, small, 8, true },
		{ 300, 14, true, 48, small, 2, true },
		{ 1280, 14, false, 60, 1, 14, false },
		{ 1280, 24, false, 60, 0.8, 20, true },
	}
	for _, case in cases do
		local width, count, touch, faceSize = case[1], case[2], case[3], case[4]
		local scale, shown, overflow = HotbarFit.fit(width, count, touch, faceSize)
		local where = `HotbarFit.fit on a {width} px {if touch then "touch" else "PC"} screen with {count} slots`
		check(near(scale, case[5]), `{where} draws it at {scale}, not {case[5]}`)
		check(shown == case[6], `{where} shows {shown}, not {case[6]}`)
		check(overflow == case[7], `{where} {if case[7] then "has no" else "has a"} "+N"`)
		check(scale <= 1, `{where} draws it bigger than its entry`)
		if width > 0 then
			local floor = if touch then HotbarFit.TOUCH_FLOOR else HotbarFit.PC_FLOOR
			local side = if touch then HotbarFit.TOUCH_SIDE else HotbarFit.PC_SIDE
			check(faceSize * scale >= floor - 1e-6, `{where} draws a face under {floor} px`)
			if shown > 2 then
				local drawn = HotbarFit.rowWidth(shown, faceSize) * scale
				check(drawn <= width - 2 * side + 1e-6, `{where} is {drawn} px wide: within {side} px of a side`)
			end
		end
	end

	local path = "src/client/Controllers/HotbarController.luau"
	local source = fs.readFile(path)
	local function has(text: string): boolean
		return string.find(source, text, 1, true) ~= nil
	end
	local fitSource = fs.readFile("src/shared/HotbarFit.luau")
	check(
		not has("MAX_SLOTS") and string.find(fitSource, "MAX_SLOTS", 1, true) == nil,
		"The hotbar caps its slots (MAX_SLOTS): every tool gets one"
	)
	-- Its numbers are HotbarFit's: the lines that take them, word for word.
	for _, line in
		{
			"local STROKE = HotbarFit.STROKE",
			"local LIP = HotbarFit.LIP",
			"local GAP = HotbarFit.GAP",
			"return HotbarFit.cellWidth(face)",
			"return HotbarFit.cellHeight(face)",
			"return HotbarFit.rowWidth(count, face)",
			"local newFace = HotbarFit.faceFor(height)",
			"local drawn = HotbarFit.drawnCount(#entries)\n",
			"HotbarFit.fit(UI.getScreen().AbsoluteSize.X, drawn, UI.isTouch(), face)\n",
			"HotbarFit.keyFor(place)",
		}
	do
		check(has(line), `{path} doesn't take its numbers from HotbarFit: no "{string.gsub(line, "\n", "")}"`)
	end
	-- Nothing of its own that HotbarFit has.
	for _, name in { "MIN_SLOTS", "ROOM", "KEY_COUNT", "TOUCH_SIDE", "PC_SIDE", "TOUCH_FLOOR", "PC_FLOOR" } do
		check(
			string.find(source, `local {name} =`, 1, true) == nil,
			`{path} has a {name} of its own: HotbarFit's is the one`
		)
	end
	local keyNames = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
	for index, name in keyNames do
		check(has(`[Enum.KeyCode.{name}] = {index},`), `{path} doesn't bind the {index} key to the slot {index}`)
	end
	check(has("[Enum.KeyCode.Zero] = 10,"), `{path} doesn't bind the 0 key to the tenth slot`)
	check(
		has('Juicy.face("Gold"') and has("`+{#trayPlaces}`"),
		`{path} has no gold "+N" slot for the tools that don't fit`
	)
	check(has('Name = "Tray"'), `{path} has no tray for the tools behind "+N"`)
	check(
		has("and not processed\n")
			and has("(kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)"),
		`{path} doesn't close an open tray on a click or tap that no button took`
	)
	check(has('GetAttribute("Servicing")'), `{path} doesn't keep the place of a tool set down to be worked on`)
	local _, selectable = string.gsub(source, "Selectable = false", "")
	check(selectable >= 2, `{path}: its slot and "+N" buttons aren't Selectable = false`)
end

-- Roblox's Backpack (its own hotbar) stays off for good: every SetCoreGuiEnabled in the client that
-- names the Backpack, or All, passes false, and one does turn the Backpack off. Otherwise Roblox's
-- hotbar would show under the game's, and its number keys would equip tools behind the game's back.
do
	local switchesItOff = false
	local function scanCore(folder: string)
		for _, name in fs.readDir(folder) do
			local path = `{folder}/{name}`
			if fs.isDir(path) then
				scanCore(path)
			elseif string.match(name, "%.luau$") then
				local source = fs.readFile(path)
				local from = 1
				while true do
					local start, finish = string.find(source, "SetCoreGuiEnabled", from, true)
					if not start then
						break
					end
					from = finish + 1
					-- The call's arguments, up to its closing bracket (they have no brackets of their own).
					local call = string.match(source, "^[^%)]*%)", finish + 1) or ""
					local backpack = string.find(call, "CoreGuiType%.Backpack") ~= nil
					if backpack or string.find(call, "CoreGuiType%.All") then
						local last = string.match(call, ",%s*([%w_%.]+)%s*%)$")
						check(
							last == "false",
							`{path} calls SetCoreGuiEnabled on the Backpack with {last or "a value worked out"}, not false: Roblox's Backpack stays off`
						)
						switchesItOff = switchesItOff or (backpack and last == "false")
					end
				end
			end
		end
	end
	scanCore("src/client")
	scanCore("src/first")
	check(switchesItOff, "Nothing in the client turns Roblox's Backpack off (SetCoreGuiEnabled, Backpack, false)")
end

-- The HUD's code: HudController and the modules it draws the front-page pieces with (src/client/Hud:
-- the columns, the pills, the squares, the right strip, the job card, the splash and the bits they
-- share), read as one text, so each rule below about a HUD piece holds wherever in those files the
-- piece is drawn. "HudController" in a rule's words means this set.
local HUD_FILES = { "src/client/Controllers/HudController.luau" }
do
	local names = fs.readDir("src/client/Hud")
	table.sort(names)
	for _, name in names do
		if string.match(name, "%.luau$") then
			table.insert(HUD_FILES, `src/client/Hud/{name}`)
		end
	end
end
check(#HUD_FILES > 1, "src/client/Hud has no modules: HudController draws the front-page pieces with them")
local hudSources: { string } = {}
for _, path in HUD_FILES do
	table.insert(hudSources, fs.readFile(path))
end
local hudSource = table.concat(hudSources, "\n")

-- COLUMN_PIECES is what HudController builds into a column: every piece it puts in one with
-- placeInColumn, and nothing else.
local inColumns: { [string]: boolean } = {}
for id in string.gmatch(hudSource, 'placeInColumn%(%s*[%w_]+%s*,%s*"([%w_]+)"%s*%)') do
	inColumns[id] = true
	check(COLUMN_PIECES[id] ~= nil, `HudController puts {id} in a column, but check-gui's COLUMN_PIECES hasn't got it`)
end
for id in COLUMN_PIECES do
	check(inColumns[id] == true, `HudController doesn't build {id} into a column (with placeInColumn)`)
end
-- The four menu squares (front-page HUD, rulings 3, 4, 5 and 14): Truck, Guide, Crew and Contracts are
-- faces with a label under them (the face, a 12 px gap and a 22 px label), in MenuButtons in that order
-- and then the mouse hint. On a PC MenuButtons is a column of 76 px faces (HudController's SQUARE_FACE);
-- on a touch or short screen it is a 2x2 grid of smaller faces (its GRID_FACE), wide enough for two
-- squares and the gap HudController puts between them. The grid squares are BUILT at that face size,
-- not shrunk by a UIScale on the grid (nothing here can promise a list honours a child's UIScale), and
-- their layout entries are that size and the label's room, so the left column's list and the grid agree
-- on what they take. HudController draws each with Juicy.button, in the face colour of its name. On the
-- phone the left column's scale, worked out the way HudController's fitColumn does with everything
-- that can show in the column at once, leaves a grid face at least 44 px.
do
	local MIN_PHONE_FACE = 44
	-- The faces come from HudController, so changing one there fails here until the layout follows.
	local FACE = tonumber(string.match(hudSource, "SQUARE_FACE%s*=%s*(%d+)"))
	local GRID_FACE = tonumber(string.match(hudSource, "GRID_FACE%s*=%s*(%d+)"))
	local LABEL_ROOM = tonumber(string.match(hudSource, "SQUARE_LABEL_ROOM%s*=%s*(%d+)"))
	check(FACE ~= nil, "HudController has no SQUARE_FACE")
	check(GRID_FACE ~= nil, "HudController has no GRID_FACE, the grid squares' face on a touch or short screen")
	check(LABEL_ROOM ~= nil, "HudController has no SQUARE_LABEL_ROOM")
	if not (FACE and GRID_FACE and LABEL_ROOM) then
		FACE, GRID_FACE, LABEL_ROOM = 76, 64, 34
	end
	local SQUARE_HEIGHT, GRID_HEIGHT = FACE + LABEL_ROOM, GRID_FACE + LABEL_ROOM
	-- A key badge on a face under 60 px is the small 16 px one (the right strip on a phone, Settings
	-- anywhere), so it does not cover the glyph; on a bigger face it is 22.
	check(
		string.find(hudSource, "SQUARE_KEY_SIZE = 22", 1, true) ~= nil
			and string.find(hudSource, "SQUARE_KEY_SMALL = 16", 1, true) ~= nil
			and string.find(hudSource, "KEY_SMALL_FACE = 60", 1, true) ~= nil
			and string.find(hudSource, "faceHeight < KEY_SMALL_FACE", 1, true) ~= nil,
		"HudController's key badge isn't 16 px on a face under 60 px and 22 px on a bigger one"
	)
	check(GRID_FACE < FACE, "HudController's GRID_FACE isn't smaller than SQUARE_FACE")
	check(
		string.find(hudSource, "then GRID_FACE else SQUARE_FACE", 1, true) ~= nil,
		"HudController doesn't build a square at GRID_FACE on a touch or short screen and SQUARE_FACE otherwise"
	)
	local SQUARES = {
		{ id = "TruckButton", order = 1, color = "Truck" },
		{ id = "GuideButton", order = 2, color = "Guide" },
		{ id = "CrewButton", order = 3, color = "Crew" },
		{ id = "ContractsButton", order = 4, color = "Contracts" },
	}
	local menu = UiLayout.MenuButtons
	check(menu ~= nil, "UiLayout has no MenuButtons")
	if menu then
		check(menu.parent == "LeftColumn", `UiLayout's MenuButtons is in {menu.parent}, not the LeftColumn`)
		check(
			menu.list ~= nil and menu.list.direction == "Vertical",
			"UiLayout's MenuButtons isn't a vertical list of squares (a PC's column)"
		)
		check(menu.autoSize == "Y", "UiLayout's MenuButtons doesn't grow with its squares")
	end
	for _, want in SQUARES do
		local entry = UiLayout[want.id]
		check(entry ~= nil, `UiLayout has no {want.id}`)
		if entry then
			check(entry.parent == "MenuButtons", `UiLayout's {want.id} is in {entry.parent}, not MenuButtons`)
			check(entry.order == want.order, `UiLayout's {want.id} is order {entry.order}, not {want.order}`)
			check(
				entry.size ~= nil
					and entry.size[1] == 0
					and entry.size[2] == FACE
					and entry.size[3] == 0
					and entry.size[4] == SQUARE_HEIGHT,
				`UiLayout's {want.id} isn't {FACE} by {SQUARE_HEIGHT} (a {FACE} px face and its label)`
			)
			for _, kind in { "touch", "compact" } do
				local places = entry[kind] or {}
				check(
					places.size ~= nil
						and places.size[1] == 0
						and places.size[2] == GRID_FACE
						and places.size[3] == 0
						and places.size[4] == GRID_HEIGHT,
					`UiLayout's {want.id} isn't {GRID_FACE} by {GRID_HEIGHT} on a {kind} screen (a {GRID_FACE} px face and its label, built at that size)`
				)
				check(places.scale == nil, `UiLayout's {want.id} is scaled on a {kind} screen: it is built at its size`)
			end
		end
		check(
			string.find(hudSource, `color%s*=%s*"{want.color}"`) ~= nil,
			`HudController doesn't draw {want.id} in the {want.color} face colour`
		)
	end
	local hint = UiLayout.MouseHint
	check(
		hint ~= nil and hint.parent == "MenuButtons" and hint.order == 5 and hint.device == "keyboard",
		"UiLayout's MouseHint isn't the keyboard-only fifth piece of MenuButtons, after the squares"
	)
	check(
		string.find(hudSource, "Juicy%.button%(") ~= nil,
		"HudController doesn't draw the menu squares with Juicy.button"
	)
	check(
		string.find(hudSource, "UIGridLayout") ~= nil,
		"HudController has no UIGridLayout: the squares are no 2x2 grid on a touch or short screen"
	)
	check(string.find(hudSource, "ContractsChip") == nil, "HudController still mentions the ContractsChip")
	check(
		string.find(hudSource, 'UI%.toggle%("Contracts"%)') ~= nil,
		"HudController's Contracts square doesn't open the contracts panel with UI.toggle"
	)

	-- The grid: two squares and the gap across, two rows and the gap down, with no scale of its own (a
	-- short window on a PC is a grid too).
	local gapX = tonumber(string.match(hudSource, "SQUARE_GAP_X%s*=%s*(%d+)"))
	local gapY = tonumber(string.match(hudSource, "SQUARE_GAP_Y%s*=%s*(%d+)"))
	check(gapX ~= nil and gapY ~= nil, "HudController has no SQUARE_GAP_X and SQUARE_GAP_Y for the squares' grid")
	local gridHeight = 0
	if menu and gapX and gapY then
		gridHeight = 2 * GRID_HEIGHT + gapY
		for _, which in { "touch", "compact" } do
			local place = (menu :: any)[which]
			check(
				place ~= nil and place.size ~= nil and place.size[2] == 2 * GRID_FACE + gapX and place.size[4] == 0,
				`UiLayout's MenuButtons has no {which} place {2 * GRID_FACE + gapX} wide: two squares and the gap`
			)
			check(
				place ~= nil
					and place.typical ~= nil
					and place.typical[1] == 2 * GRID_FACE + gapX
					and place.typical[2] == gridHeight,
				`UiLayout's MenuButtons {which} place isn't typically {2 * GRID_FACE + gapX} by {gridHeight}, the 2x2 grid`
			)
			check(
				place ~= nil and place.scale == nil,
				`UiLayout's MenuButtons {which} place has a scale: the grid squares are built at their size instead, since nothing promises a list honours a child's UIScale`
			)
		end
	end

	-- The phone: everything that can show in the left column on a touch screen at once (Grandma's goal
	-- is out of it there, the mouse hint is keyboard only), stacked with the column's gaps, once with
	-- the judging day countdown showing (the worst case: it shows for any player with judging day on the
	-- calendar) and once without. The grid squares are built at GRID_FACE and sit in the column at its
	-- scale, so a square is GRID_FACE times the column's scale, at least 44 px. With the countdown the
	-- column's content asks for a little under the 0.7 the height rule gives (the fit rule goes down to
	-- tightScale for that), which is the price of the names under the squares.
	local columns = UiLayout.__screen.scaling.Columns
	local phone = UiLayout.__screen.phone
	for _, withCountdown in { true, false } do
		local content, pieces = 0, 0
		for id, entry in UiLayout do
			if id ~= "__screen" and entry.parent == "LeftColumn" then
				local touchPlace = entry.touch
				local shows = not (touchPlace and touchPlace.parent == false)
					and entry.device ~= "keyboard"
					and (withCountdown or id ~= "Countdown")
				if shows then
					content += if id == "MenuButtons" then gridHeight else entry.size[4]
					pieces += 1
				end
			end
		end
		content += (pieces - 1) * UiLayout.LeftColumn.list.padding
		local scale = math.min(
			math.clamp(phone.height / columns.fullHeight, columns.minScale, 1),
			math.max(columns.tightScale, (phone.height - columns.touchMargin) / content)
		)
		local which = if withCountdown then "with the countdown" else "without the countdown"
		check(
			scale >= columns.tightScale,
			`the left column is scaled to {scale} {which} on the {phone.width} by {phone.height} phone ({content} px of column), under its {columns.tightScale} tight floor`
		)
		check(
			GRID_FACE * scale >= MIN_PHONE_FACE,
			`a menu square is {GRID_FACE * scale} px {which} on the {phone.width} by {phone.height} phone (column scale {scale} for {content} px of column), under {MIN_PHONE_FACE}`
		)
	end
end
-- The goal banner, the job card and the boosts (front-page HUD, rulings 1, 2 and 3), as HudController
-- draws them: the banner is a cream Juicy face with the red flag (no "GRANDMA'S GOAL" header), the job
-- card is dark glass in the palette's Glass at its GlassTransparency, its call-off button is a Juicy
-- Danger one, and the boost pills are BoostPills. A star is filled only from the stars the server
-- sent with the result: the client does not know the quality or what the customer wants while a job
-- runs, so HudController must not work stars out for itself.
do
	check(
		string.find(hudSource, 'Juicy%.face%(%s*"Cream"') ~= nil,
		"HudController doesn't draw Grandma's goal on a cream Juicy face"
	)
	check(
		string.find(hudSource, "GRANDMA'S GOAL", 1, true) == nil,
		"HudController still headlines Grandma's goal with GRANDMA'S GOAL: the red flag stands in for it"
	)
	check(
		string.find(hudSource, "Palette%.Glass%f[%A]") ~= nil
			and string.find(hudSource, "Palette%.GlassTransparency") ~= nil,
		"HudController doesn't draw the job card in Juicy's Glass at its GlassTransparency"
	)
	check(
		string.find(hudSource, 'Juicy%.button%(%s*"Danger"') ~= nil,
		"HudController doesn't draw the call-off button as a Juicy Danger button"
	)
	check(
		string.find(hudSource, "Stars%.of%(") == nil and string.find(hudSource, "GameConfig%.performance%(") == nil,
		"HudController works out stars itself: the client can't know the quality, so it must show result.stars"
	)

	-- The job card on a short screen is 150 px tall (its padding, the header, two to-do lines and the 32 px
	-- footer: the right column's phone fit reads this), and the damage words in the full card are cut off
	-- at the end rather than running under the Call off pill.
	local tracker = UiLayout.JobTracker
	check(
		tracker.compact ~= nil and tracker.compact.typical ~= nil and tracker.compact.typical[2] == 150,
		"UiLayout's JobTracker isn't typically 150 px tall on a short screen"
	)
	local damageAt = string.find(hudSource, "damageLabel = UI.label(", 1, true)
	local damageEnd = if damageAt then string.find(hudSource, "})", damageAt, true) else nil
	check(
		damageAt ~= nil
			and damageEnd ~= nil
			and string.find(
					string.sub(hudSource, damageAt, damageEnd),
					"TextTruncate = Enum.TextTruncate.AtEnd",
					1,
					true
				)
				~= nil,
		"HudController's damage words aren't cut off at the end (TextTruncate AtEnd)"
	)

	-- The Shop button (and B) puts the Shop window away only when the Orders app is what is open; with the
	-- Business app up at the computer it switches to Orders instead. F is left to DecorController while a
	-- decoration is being placed (it sends the decoration back), so Top Lawns does not open then. Running
	-- low of a supply says to order more from the Shop, which is where the Shop button goes.
	check(
		string.find(hudSource, 'UI.isOpen("Shop") and ShopController.currentApp() == "Orders"', 1, true) ~= nil
			and string.find(
					fs.readFile("src/client/Controllers/ShopController.luau"),
					"function ShopController.currentApp",
					1,
					true
				)
				~= nil,
		"HudController's Shop button doesn't switch the Business app to Orders instead of closing"
	)
	check(
		string.find(hudSource, 'PLACING_ATTRIBUTE = "PlacingDecor"', 1, true) ~= nil
			and string.find(
					hudSource,
					'button.id == "TopLawns" and player:GetAttribute(PLACING_ATTRIBUTE) ~= nil',
					1,
					true
				)
				~= nil,
		"HudController's F key isn't left alone while a decoration is being placed (PlacingDecor)"
	)
	local maintenanceSource = fs.readFile("src/server/Services/MaintenanceService.luau")
	check(
		string.find(maintenanceSource, "Order more from the Shop.", 1, true) ~= nil
			and string.find(maintenanceSource, "Order more on the shop computer.", 1, true) == nil,
		'MaintenanceService doesn\'t say "Order more from the Shop."'
	)

	-- Juicy's pulse and pop start from the scale the element has when they start: a running animation's
	-- remembered base is reused only while the scale still holds the value that animation wrote last (within
	-- 1e-4), so a re-place by the layout between two frames is not written over.
	local juicySource = fs.readFile("src/client/Juicy.luau")
	check(
		string.find(juicySource, "math.abs(scale.Scale - running.written) <= 1e-4", 1, true) ~= nil,
		"Juicy's animate reuses a running animation's base without checking the scale is still what it wrote"
	)

	-- Juicy.badge hands back its text label (a third value), so HudController changes a badge's number
	-- through it and never digs for a child called "Text".
	check(
		string.find(juicySource, "return outer, face, label", 1, true) ~= nil
			and string.find(hudSource, 'FindFirstChild("Text")', 1, true) == nil,
		"Juicy.badge doesn't return its label, or HudController still looks for the badge's Text by name"
	)

	-- The money counts up from the number the label shows now (shownMoney, written by the count's own
	-- formatter), not from the previous profile's money, so a second gain mid-count never jumps. The
	-- Levels button juices the level pill when pressed, on the pill itself inside a slot of the row, so the
	-- row's list is not laid out again every frame.
	check(
		string.find(hudSource, "shownMoney", 1, true) ~= nil
			and string.find(hudSource, "countTo(money, shownMoney", 1, true) ~= nil
			and string.find(hudSource, "countTo(money, lastMoney", 1, true) == nil,
		"HudController's money count doesn't start from the number on screen (shownMoney)"
	)
	check(
		string.find(hudSource, "Juicy.juice(levelsButton, levelHolder)", 1, true) ~= nil
			and string.find(hudSource, "LevelSlot", 1, true) ~= nil,
		"HudController's Levels button doesn't juice the level pill (inside a LevelSlot of the row)"
	)

	-- The boost pills show the numbers the server sends with every job update (crewBonus, truckBonus,
	-- businessBonus and curbBonus: the same factors completeJob multiplies, through the one payBonuses,
	-- with the curb appeal frozen at pull-out), so they are exact for every crew member; the client
	-- has no formula of its own for them.
	local jobSource = fs.readFile("src/server/Services/JobService.luau")
	local updateFrom = string.find(jobSource, "local function sendUpdate(job)", 1, true)
	local updateTo = if updateFrom then string.find(jobSource, "\nend\n", updateFrom, true) else nil
	local completeFrom = string.find(jobSource, "local function completeJob(job)", 1, true)
	local completeTo = if completeFrom then string.find(jobSource, "\nend\n", completeFrom, true) else nil
	check(
		updateFrom ~= nil and updateTo ~= nil and completeFrom ~= nil and completeTo ~= nil,
		"check-gui can't find JobService's sendUpdate and completeJob"
	)
	if updateFrom and updateTo and completeFrom and completeTo then
		local updateBody = string.sub(jobSource, updateFrom, updateTo)
		for _, field in { "crewBonus", "truckBonus", "businessBonus", "curbBonus" } do
			check(
				string.find(updateBody, `{field} = `, 1, true) ~= nil,
				`JobService's sendUpdate doesn't send {field} to the job card's boost pills`
			)
			check(
				string.find(hudSource, `job.{field}`, 1, true) ~= nil,
				`HudController's boost pills don't read job.{field} from the server`
			)
		end
		check(
			string.find(updateBody, "payBonuses(job)", 1, true) ~= nil
				and string.find(string.sub(jobSource, completeFrom, completeTo), "payBonuses(job)", 1, true) ~= nil,
			"JobService's sendUpdate and completeJob don't both take the pay bonuses from payBonuses"
		)
	end
	for _, formula in { "HomeLawn.payBonus(", "CrewBonusPerMember", "payoutBonus" } do
		check(
			string.find(hudSource, formula, 1, true) == nil,
			`HudController works the boost pills out itself ({formula}): the server sends the numbers`
		)
	end

	-- The countdown pill's words come from Daily.judgingText (check-season runs its cases, including a
	-- view held across Saturday's midnight), with the contest view's daysLeft and this computer's clock;
	-- HudController does not work the days out itself.
	check(
		string.find(hudSource, "Daily.judgingText(contest.state, contest.daysLeft, os.time())", 1, true) ~= nil
			and string.find(hudSource, "Daily.nextSaturday", 1, true) == nil,
		"HudController's countdown pill isn't Daily.judgingText of the view's state and daysLeft"
	)

	-- Call off sends the whole crew home when you lead, so it takes two taps: the first turns the pill
	-- into "Sure?" for 3 seconds (the Shop's sell confirm does the same) and only the second sends
	-- AbandonJob. Every control that acts has a hit area of at least 40 px once its column's scale is
	-- applied (addHitStrips adds invisible strips above and below it on a touch screen): the two Call off
	-- pills and the Show what I missed button. A chip that only shows is exempt.
	check(
		string.find(hudSource, "CALL_OFF_SURE = 3", 1, true) ~= nil
			and string.find(hudSource, '"Sure?"', 1, true) ~= nil,
		'HudController\'s Call off has no two-tap confirm ("Sure?" for CALL_OFF_SURE = 3 seconds)'
	)
	check(
		string.find(hudSource, 'Juicy.button("Danger", pressCallOff', 1, true) ~= nil
			and select(2, string.gsub(hudSource, "callOffJob%(%)", "")) == 2,
		"HudController's Call off pills don't go through pressCallOff: callOffJob should be called only there"
	)
	local hitMin = tonumber(string.match(hudSource, "HIT_MIN%s*=%s*(%d+)"))
	check(hitMin ~= nil and hitMin >= 40, "HudController's HIT_MIN isn't at least 40 px")
	for _, wanted in { "addHitStrips(trackerButton", "addHitStrips(compactButton", "addHitStrips(missedButton" } do
		check(string.find(hudSource, wanted, 1, true) ~= nil, `HudController doesn't have {wanted}`)
	end

	-- The phone: the right column's pieces that can show during a job there (curb appeal hides on a
	-- short screen; the job card is its compact one; the pills may wrap to two rows) fit in the
	-- column's height at its floor scale. (That the banner sits between the columns is the screens
	-- check, further down.)
	local columns = UiLayout.__screen.scaling.Columns
	local phone = UiLayout.__screen.phone
	local widest = math.clamp(phone.height / columns.fullHeight, columns.minScale, 1)
	local right = UiLayout.RightColumn
	local content, pieces = 0, 0
	for id, entry in UiLayout do
		if id ~= "__screen" and entry.parent == "RightColumn" and id ~= "CurbAppeal" then
			local height = entry.size[4]
			if id == "JobTracker" then
				height = entry.compact.typical[2]
			elseif id == "BoostPills" then
				height = 2 * entry.size[4] + entry.list.padding
			elseif entry.touch and entry.touch.size then
				height = entry.touch.size[4]
			end
			content += height
			pieces += 1
		end
	end
	content += (pieces - 1) * right.list.padding
	local scale = math.min(widest, math.max(columns.tightScale, (phone.height - columns.touchMargin) / content))
	check(
		scale >= columns.minScale - 1e-9,
		`the right column is scaled to {scale} on the {phone.width} by {phone.height} phone ({content} px of column during a job), under its {columns.minScale} floor`
	)
end
-- The right-edge strip and what its buttons open (front-page HUD, rulings 3, 4, 6, 8 and 14). RightButtons
-- is Shop, Gifts, Top Lawns and Settings down the right edge at {1, -12, 0, 12}: 76 px faces with a label
-- under them (Settings 56) on a PC, and on a touch or short screen 56 px faces (Settings 44) with no
-- labels, built at that size and not scaled, so the strip ends above Roblox's jump button on the phone.
-- RightColumn sits inside it by its width and 12 px, on every kind of screen, so nothing overlaps.
-- The Shop button opens the Orders window and the shop sells away from the desk; Top Lawns is a panel of
-- the two leaderboards.
do
	local LABEL_ROOM = 34
	local BIG, BIG_SETTINGS, SMALL, SMALL_SETTINGS = 76, 56, 56, 44
	local MIN_TOUCH_FACE = 40
	local EDGE, GAP = 12, 12
	local BUTTONS = {
		{ id = "ShopButton", order = 1, color = "Shop", settings = false },
		{ id = "GiftsButton", order = 2, color = "Gifts", settings = false },
		{ id = "TopLawnsButton", order = 3, color = "TopLawns", settings = false },
		{ id = "SettingsButton", order = 4, color = "Settings", settings = true },
	}
	local strip = UiLayout.RightButtons
	check(strip ~= nil, "UiLayout has no RightButtons")
	if strip then
		check(
			strip.parent == nil and strip.screen == "LawnUI",
			"UiLayout's RightButtons isn't on LawnUI, out of the columns"
		)
		check(strip.detach == nil, "UiLayout's RightButtons can leave a column: it isn't in one")
		check(
			strip.anchor ~= nil and strip.anchor[1] == 1 and strip.anchor[2] == 0,
			"UiLayout's RightButtons isn't anchored at its top right corner"
		)
		check(
			strip.position ~= nil
				and strip.position[1] == 1
				and strip.position[2] == -EDGE
				and strip.position[3] == 0
				and strip.position[4] == EDGE,
			`UiLayout's RightButtons isn't at \{1, -{EDGE}, 0, {EDGE}}`
		)
		check(
			strip.list ~= nil and strip.list.direction == "Vertical",
			"UiLayout's RightButtons isn't a vertical list of buttons"
		)
		check(strip.autoSize == "Y", "UiLayout's RightButtons doesn't grow with its buttons")
	end
	for _, want in BUTTONS do
		local entry = UiLayout[want.id]
		check(entry ~= nil, `UiLayout has no {want.id}`)
		if entry then
			local big = if want.settings then BIG_SETTINGS else BIG
			local small = if want.settings then SMALL_SETTINGS else SMALL
			check(entry.parent == "RightButtons", `UiLayout's {want.id} is in {entry.parent}, not RightButtons`)
			check(entry.order == want.order, `UiLayout's {want.id} is order {entry.order}, not {want.order}`)
			check(
				entry.size ~= nil and entry.size[2] == big and entry.size[4] == big + LABEL_ROOM,
				`UiLayout's {want.id} isn't {big} by {big + LABEL_ROOM} on a PC (a {big} px face and its label)`
			)
			for _, kind in { "touch", "compact" } do
				local places = entry[kind] or {}
				check(
					places.size ~= nil and places.size[2] == small and places.size[4] == small,
					`UiLayout's {want.id} isn't a bare {small} px square on a {kind} screen (no label)`
				)
				check(places.scale == nil, `UiLayout's {want.id} is scaled on a {kind} screen: it is built at its size`)
				check(
					places.size == nil or places.size[4] >= MIN_TOUCH_FACE,
					`UiLayout's {want.id} is under {MIN_TOUCH_FACE} px`
				)
			end
			check(
				entry.hideWhile == nil
					and (entry.touch or {}).hideWhile == nil
					and (entry.compact or {}).hideWhile == nil,
				`UiLayout's {want.id} gives way to something: the strip shows on every screen`
			)
		end
	end
	for id, entry in UiLayout do
		if id ~= "__screen" and entry.parent == "RightButtons" then
			local known = false
			for _, want in BUTTONS do
				known = known or want.id == id
			end
			check(known, `UiLayout's {id} is in RightButtons, which check-gui doesn't know`)
		end
	end

	-- RightColumn clears the strip on each kind of screen: its right edge is further in than the
	-- strip's left edge by GAP. (UI.layout picks compact over touch over the base, a field at a time.)
	local function pick(entry, key: string, kind: string)
		local compact, touch = entry.compact or {}, entry.touch or {}
		if kind == "compact" and compact[key] ~= nil then
			return compact[key]
		elseif (kind == "compact" or kind == "touch") and touch[key] ~= nil then
			return touch[key]
		end
		return entry[key]
	end
	local column = UiLayout.RightColumn
	local widths: { [string]: number } = {}
	if strip then
		for _, kind in { "base", "touch", "compact" } do
			local stripWidth = pick(strip, "size", kind)[2]
			local stripRight = pick(strip, "position", kind)[2]
			local columnRight = pick(column, "position", kind)[2]
			widths[kind] = stripWidth
			check(
				columnRight <= stripRight - stripWidth - GAP,
				`UiLayout's RightColumn ({kind}) is at x {columnRight}, which doesn't clear the strip ({stripWidth} px wide at {stripRight}) by {GAP} px`
			)
			check(
				pick(column, "anchor", kind)[1] == 1,
				`UiLayout's RightColumn ({kind}) isn't anchored at its right edge, so its x doesn't mean what the strip check reads`
			)
		end
		check(widths.base == BIG, `UiLayout's RightButtons is {widths.base} wide on a PC, not the {BIG} px faces`)
		check(
			widths.touch == SMALL and widths.compact == SMALL,
			`UiLayout's RightButtons isn't {SMALL} wide on a touch or short screen`
		)

		-- A PC: the strip's own height, its buttons and the gaps, and the 6 px lip under the last, stays
		-- above the height where the screen turns short.
		local listPad = strip.list.padding
		local pcHeight = EDGE + 3 * (BIG + LABEL_ROOM) + (BIG_SETTINGS + LABEL_ROOM) + 3 * listPad + 6
		check(
			pcHeight < UiLayout.__screen.compactHeight,
			`the right strip is {pcHeight} px down on a PC, past the {UiLayout.__screen.compactHeight} px where the screen turns short (it has no scale)`
		)
		-- The phone: the strip ends above Roblox's jump button (the columns' touchMargin), and its left
		-- edge is clear of the look-at button, which is the nearest phone button.
		local phone = UiLayout.__screen.phone
		local columns = UiLayout.__screen.scaling.Columns
		local touchHeight = EDGE + 3 * SMALL + SMALL_SETTINGS + 3 * listPad + 6
		check(
			touchHeight <= phone.height - columns.touchMargin,
			`the right strip ends {touchHeight} px down on the {phone.width} by {phone.height} phone, past {phone.height - columns.touchMargin}, where the jump button's room starts`
		)
		local stripLeft = phone.width + strip.position[2] - SMALL
		local lookAt = UiLayout.InteractButton
		local lookAtRight = phone.width + lookAt.touch.position[2]
		check(
			stripLeft >= lookAtRight,
			`the right strip starts at x {stripLeft} on the phone, over the look-at button, which ends at {lookAtRight}`
		)
		-- Grandma's goal and the first-job coach share the top in the middle, and each must clear both
		-- columns and the strip on the screens people play on: the two phones (an iPhone SE's 667 by 375
		-- and the 844 by 390 the HUD is verified at), a 1024 by 600 and a 1024 by 768 window or tablet and a
		-- 1280 by 720 one, each with and without a touch screen (a touch screen has its own places). Where a
		-- column sits is worked out at its widest (the height rule's scale; the fit rule only shrinks it
		-- further), the pieces shrink by the same rule (the banner by the columns' rule, the coach by its own
		-- scale), and 8 px is the least that must be left. A short screen's banner and coach are narrower
		-- and shifted left, toward the roomier side (the left column is narrower than the right one with its
		-- job card), instead of centred: the room between the columns on a 667 px wide phone is 180 px wide
		-- and 45 px left of its middle. A PC window narrower than 1024 px is not covered: there the banner
		-- stays at its 240 px minimum and the right column's job card can reach it.
		local CLEAR = 8
		local function placedOn(entry, key: string, touch: boolean, short: boolean): any
			local value = entry[key]
			if touch and entry.touch and entry.touch[key] ~= nil then
				value = entry.touch[key]
			end
			if short and entry.compact and entry.compact[key] ~= nil then
				value = entry.compact[key]
			end
			return value
		end
		local SCREENS = {
			{ width = 667, height = 375, touch = true },
			{ width = 844, height = 390, touch = true },
			{ width = 1024, height = 600, touch = false },
			{ width = 1024, height = 600, touch = true },
			{ width = 1024, height = 768, touch = false },
			{ width = 1024, height = 768, touch = true },
			{ width = 1280, height = 720, touch = false },
			{ width = 1280, height = 720, touch = true },
		}
		local left = UiLayout.LeftColumn
		for _, screen in SCREENS do
			local short = screen.height < UiLayout.__screen.compactHeight
			local rule = math.clamp(screen.height / columns.fullHeight, columns.minScale, 1)
			local where = `{screen.width} by {screen.height}{if screen.touch then " touch" else ""}`
			local leftEdge = left.position[2] + left.size[2] * rule
			local columnLeft = screen.width
				+ placedOn(column, "position", screen.touch, short)[2]
				- column.size[2] * rule
			local stripWidth = placedOn(strip, "size", screen.touch, short)[2]
			local stripLeft = screen.width + placedOn(strip, "position", screen.touch, short)[2] - stripWidth
			for _, id in { "GrandmaGoal", "TutorialBanner" } do
				local piece = UiLayout[id]
				local size = placedOn(piece, "size", screen.touch, short)
				local width = size[1] * screen.width + size[2]
				if piece.min and piece.min.width then
					width = math.max(width, piece.min.width)
				end
				if piece.max and piece.max.width then
					width = math.min(width, piece.max.width)
				end
				-- The banner is scaled by the columns' rule (it is a column piece out on the screen), the coach
				-- by its own scale.
				local own = placedOn(piece, "scale", screen.touch, short) or 1
				width *= if id == "GrandmaGoal" then rule * own else own
				local position = placedOn(piece, "position", screen.touch, short)
				local anchor = placedOn(piece, "anchor", screen.touch, short)
				local from = position[1] * screen.width + position[2] - anchor[1] * width
				check(
					from >= leftEdge + CLEAR,
					`{id} starts at {from} on {where}, within {CLEAR} px of the left column, which ends at {leftEdge}`
				)
				check(
					from + width <= columnLeft - CLEAR,
					`{id} ends at {from + width} on {where}, within {CLEAR} px of the right column, which starts at {columnLeft}`
				)
				check(
					from + width <= stripLeft - CLEAR,
					`{id} ends at {from + width} on {where}, within {CLEAR} px of the right strip, which starts at {stripLeft}`
				)
			end
		end
		-- The coach follows the banner's rule.
		local coach = UiLayout.TutorialBanner
		local coachReach = -column.position[2] + column.size[2] + BANNER_GAP
		check(
			coach.size[1] == 1 and coach.size[2] == -2 * coachReach,
			`UiLayout's TutorialBanner isn't the screen's width less {2 * coachReach} px, the same as Grandma's goal`
		)
		check(
			coach.max ~= nil and coach.max.width == 480 and coach.min ~= nil and coach.min.width == 240,
			"UiLayout's TutorialBanner isn't between 240 and 480 px wide"
		)
	end

	-- HudController builds the four buttons with Juicy.button from the glyphs the art has, puts the strip
	-- where UiLayout says, and wires them as the plan says. The Gifts glyph is drawn (the Premium
	-- diamond reads as a shop, not a present).
	check(
		string.find(hudSource, "buildRightButtons", 1, true) ~= nil
			and string.find(hudSource, 'UI.keepPlaced(rightHolder, "RightButtons")', 1, true) ~= nil,
		"HudController doesn't build RightButtons"
	)
	for _, glyph in { "Orders", "Crown", "Wrench" } do
		check(GuiArt.Images[`Icons/{glyph}.png`] ~= nil, `the right strip's glyph {glyph} isn't in GuiArt`)
		check(
			string.find(hudSource, `icon = "{glyph}"`, 1, true) ~= nil,
			`HudController's right strip doesn't use the {glyph} glyph`
		)
	end
	check(string.find(hudSource, "drawGift", 1, true) ~= nil, "HudController doesn't draw the Gifts button's present")
	local hudWants = {
		'ShopController.openApp("Orders")',
		'UI.toggle("TopLawns")',
		'UI.toggle("Contracts")',
		"Enum.KeyCode.B",
		"Enum.KeyCode.F",
		"Enum.KeyCode.Comma",
		"HudController.giftsButton",
		"HudController.settingsButton",
	}
	for _, wanted in hudWants do
		check(string.find(hudSource, wanted, 1, true) ~= nil, `HudController doesn't have {wanted}`)
	end
	-- Gifts (ruling 7): the button claims the day's gift while the view says one waits, wears a CLAIM
	-- tag tilted -8 degrees and pulses meanwhile, and a gift the day turn paid is told after the title
	-- card. The server pays the gift on a claim, not at the turn.
	local giftWants = {
		'Net.func("ClaimStreak"):InvokeServer()',
		"streak.claimable",
		'Juicy.badge("CLAIM"',
		"GIFT_TAG_TILT = -8",
		"GIFT_PULSE_EVERY = 2.5",
		"rightActions.Gifts = pressGifts",
		'Net.event("StreakGiftPaid")',
		"afterTitleCard(showGiftPaid",
	}
	for _, wanted in giftWants do
		check(string.find(hudSource, wanted, 1, true) ~= nil, `HudController's Gifts button doesn't have {wanted}`)
	end
	local dailySource = fs.readFile("src/server/Services/DailyService.luau")
	local refreshStart = string.find(dailySource, "function DailyService:Refresh", 1, true)
	local claimStart = string.find(dailySource, "function DailyService:Claim", 1, true)
	check(refreshStart ~= nil and claimStart ~= nil, "DailyService has no Refresh or no Claim")
	if refreshStart and claimStart then
		local refreshBody = string.sub(dailySource, refreshStart, claimStart - 1)
		local claimBody = string.sub(dailySource, claimStart)
		check(
			string.find(refreshBody, '"StreakAdvanced"', 1, true) == nil,
			"DailyService:Refresh still plays the streak card at the day turn: the card is the claim's"
		)
		-- What the turn owes is paid (and told) in Refresh: it asks Streak.turn what is owed, pays that with
		-- payGift (the pcall passes it the player and `owed`) and plays StreakGiftPaid. Without this wiring a
		-- missed day's gift would never be paid, and nothing else here would notice.
		check(
			string.find(refreshBody, "Streak.turn(", 1, true) ~= nil
				and string.find(refreshBody, "pcall(payGift, player, owed", 1, true) ~= nil
				and string.find(refreshBody, '"StreakGiftPaid"', 1, true) ~= nil,
			"DailyService:Refresh doesn't pay what Streak.turn says is owed (payGift, then StreakGiftPaid)"
		)
		check(
			string.find(claimBody, '"StreakAdvanced"', 1, true) ~= nil
				and string.find(claimBody, "Streak.claim(", 1, true) ~= nil,
			"DailyService:Claim doesn't claim through Streak.claim and play the streak card"
		)
		check(
			string.find(dailySource, 'Net.func("ClaimStreak").OnServerInvoke', 1, true) ~= nil
				and string.find(dailySource, "CLAIM_COOLDOWN", 1, true) ~= nil,
			"DailyService doesn't answer ClaimStreak with a cooldown"
		)
	end

	-- Settings (ruling 9): SettingsController is the window and the one writer of the three choices;
	-- the Settings button opens it (setRightAction), the V key and the Guide's switch choose camera
	-- motion through it, the camera starts from the saved setting, sounds go through the Effects
	-- group, and the grass takes its shell count from the setting once. Config/Settings.luau and the
	-- server's side are checked in check-season.
	local settingsSource = if fs.isFile("src/client/Controllers/SettingsController.luau")
		then fs.readFile("src/client/Controllers/SettingsController.luau")
		else ""
	check(settingsSource ~= "", "there is no SettingsController")
	local settingsWants = {
		'UI.panel("Settings", "Settings")',
		'setRightAction("Settings"',
		'Net.func("SaveSettings"):InvokeServer(',
		"SAVE_DELAY = 0.3",
		"Settings.clean(profile.settings)",
		"Sounds.setVolume(Settings.volume(",
		"CameraController.setMotion(current.motion)",
		"Takes effect when you rejoin.",
		"function SettingsController.setMotion",
		"Juicy.button(",
	}
	for _, wanted in settingsWants do
		check(string.find(settingsSource, wanted, 1, true) ~= nil, `SettingsController doesn't have {wanted}`)
	end
	check(
		string.find(hudSource, "Settings are coming", 1, true) == nil,
		"HudController still says Settings are coming: the button opens the window"
	)
	check(
		string.find(hudSource, "SettingsController.setMotion(on)", 1, true) ~= nil
			and string.find(hudSource, "CameraController.setMotion(", 1, true) == nil,
		"the V key doesn't choose camera motion through SettingsController"
	)
	local guideSource = fs.readFile("src/client/Controllers/GuideController.luau")
	check(
		string.find(guideSource, "SettingsController.setMotion(", 1, true) ~= nil
			and string.find(guideSource, "CameraController.setMotion(", 1, true) == nil,
		"the Guide's camera switch doesn't choose camera motion through SettingsController"
	)
	local cameraSource = fs.readFile("src/client/Controllers/CameraController.luau")
	-- SettingsController's adopt is the one reader of the saved motion (it applies it at Start and on
	-- every profile push, and holds off while a choice of the player's is still on its way); the camera
	-- has no reader of its own, which could race it.
	check(
		string.find(cameraSource, "readSetting", 1, true) == nil
			and string.find(cameraSource, "Settings.clean", 1, true) == nil
			and string.find(cameraSource, "ClientState", 1, true) == nil,
		"CameraController reads the saved camera motion itself: SettingsController.adopt is the one reader"
	)
	-- The window sends no faster than 0.9 s apart (the server's cooldown is Settings.Cooldown, 0.5, measured
	-- between arrivals), asks again once on a refusal before it puts the profile's choice back, and draws
	-- its choices only while the window is up.
	check(
		string.find(settingsSource, "MIN_GAP = 0.9", 1, true) ~= nil,
		"SettingsController's MIN_GAP isn't 0.9 s, which leaves the server's half second some network jitter"
	)
	check(
		select(2, string.gsub(settingsSource, "= ask%(sent%)", "")) == 2,
		"SettingsController doesn't ask the server a second time before it gives a nil answer up"
	)
	check(
		string.find(settingsSource, "local function renderIfShown", 1, true) ~= nil
			and select(2, string.gsub(settingsSource, "\n\t*render%(%)", "")) == 2,
		"SettingsController draws its choices while the window is away (only renderIfShown and the window opening should)"
	)
	local grassSource = fs.readFile("src/client/Controllers/GrassController.luau")
	check(
		string.find(grassSource, "Settings.shells(", 1, true) ~= nil
			and string.find(grassSource, "GrassImages.shellCount(TOUCH), GameConfig", 1, true) == nil,
		"GrassController doesn't take its shell count from the Grass detail setting"
	)
	check(
		string.find(fs.readFile("src/client/init.client.luau"), '"SettingsController"', 1, true) ~= nil,
		"init.client doesn't start SettingsController"
	)
	local soundsSource = fs.readFile("src/shared/Sounds.luau")
	check(
		select(2, string.gsub(soundsSource, "route%(sound%)", "")) == 3,
		"Sounds.play, playUi and loop don't all send their sound through the Effects group"
	)
	-- The line that really groups a sound (route's `sound.SoundGroup = effectsGroup()`, and watch's for the
	-- server's sounds and the characters') has to be there, and each maker must route its sound BEFORE it
	-- parents it, so a sound never plays for a moment outside the group (Sound set to Off would leak).
	check(
		string.find(soundsSource, "sound.SoundGroup = effectsGroup()", 1, true) ~= nil
			and string.find(soundsSource, "instance.SoundGroup = effectsGroup()", 1, true) ~= nil,
		"Sounds doesn't put sounds in the Effects group with `SoundGroup = effectsGroup()`"
	)
	for _, name in { "play", "playUi", "loop" } do
		local from = string.find(soundsSource, `function Sounds.{name}(`, 1, true)
		local to = if from then string.find(soundsSource, "\nend\n", from, true) else nil
		check(from ~= nil and to ~= nil, `check-gui can't find Sounds.{name}`)
		if from and to then
			local body = string.sub(soundsSource, from, to)
			local routed = string.find(body, "route(sound)", 1, true)
			local parented = string.find(body, "sound.Parent =", 1, true)
			check(
				routed ~= nil and parented ~= nil and routed < parented,
				`Sounds.{name} doesn't route its sound into the Effects group before it parents it`
			)
		end
	end
	check(
		string.find(soundsSource, "if watching then", 1, true) ~= nil
			and string.find(soundsSource, "watching = true", 1, true) ~= nil,
		"Sounds.watch has no once-guard: a second call would connect everything again"
	)
	check(
		string.find(soundsSource, "CharacterAdded:Connect(watchCharacter)", 1, true) ~= nil,
		"Sounds.watch doesn't put the characters' own sounds (footsteps, jump) in the Effects group"
	)

	-- Shop anywhere (ruling 6, narrowed): tools, supplies, decorations and selling don't ask where the
	-- player stands, but the things built on the business plot (PLOT_CATEGORIES: the truck, the trailer
	-- and the business buildings) are still bought and switched to at the computer: ShopService's Buy and
	-- Equip ask WorldService:IsAtComputer for them and nothing else there does. The Shop button never
	-- offers them, so the server stays as strict as before. Taking a job and TurfKing's visit stay at the
	-- desk too.
	check(
		string.find(fs.readFile("src/server/Services/DecorService.luau"), "IsAtComputer", 1, true) == nil,
		"DecorService still asks WorldService:IsAtComputer: decorations are bought away from the desk"
	)
	local shopSource = fs.readFile("src/server/Services/ShopService.luau")
	local plotAtDesk = "PLOT_CATEGORIES[category] and not WorldService:IsAtComputer(player)"
	check(
		select(2, string.gsub(shopSource, "IsAtComputer", "")) == 2,
		"ShopService doesn't ask WorldService:IsAtComputer exactly twice (for plot items, in Buy and Equip)"
	)
	for _, name in { "Buy", "Equip", "Sell" } do
		local from = string.find(shopSource, `function ShopService:{name}(`, 1, true)
		local to = if from then string.find(shopSource, "\nend\n", from, true) else nil
		check(from ~= nil and to ~= nil, `check-gui can't find ShopService:{name}`)
		if from and to then
			local body = string.sub(shopSource, from, to)
			local asksAtDesk = string.find(body, plotAtDesk, 1, true) ~= nil
			check(
				asksAtDesk == (name ~= "Sell"),
				if name == "Sell"
					then "ShopService:Sell asks WorldService:IsAtComputer: selling is allowed anywhere"
					else `ShopService:{name} doesn't send plot items to the computer`
			)
		end
	end
	for _, path in { "src/server/Services/JobService.luau", "src/server/Services/TurfKingService.luau" } do
		check(
			string.find(fs.readFile(path), "IsAtComputer", 1, true) ~= nil,
			`{path} lost its IsAtComputer check: jobs stay a computer thing`
		)
	end
	check(
		string.find(fs.readFile("src/server/Services/ShopService.luau"), "JobService:IsBusy(player)", 1, true) ~= nil,
		"ShopService no longer refuses tools and plot items in the middle of a job"
	)

	-- Top Lawns (ruling 8): the leaderboard payload is kept in ClientState, TopLawnsController draws it
	-- in a panel with two tabs, and init.client starts it.
	local topLawns = if fs.isFile("src/client/Controllers/TopLawnsController.luau")
		then fs.readFile("src/client/Controllers/TopLawnsController.luau")
		else ""
	check(topLawns ~= "", "there is no TopLawnsController")
	local topLawnsWants = {
		'UI.panel("TopLawns", "Top Lawns")',
		"UI.scrollingList",
		"UI.tab(",
		"ClientState.Changed",
		'"leaderboard"',
		"LeaderboardController.rowText",
		"LeaderboardController.youLine",
	}
	for _, wanted in topLawnsWants do
		check(string.find(topLawns, wanted, 1, true) ~= nil, `TopLawnsController doesn't have {wanted}`)
	end
	check(
		string.find(
			fs.readFile("src/client/Controllers/LeaderboardController.luau"),
			'ClientState.set("leaderboard"',
			1,
			true
		) ~= nil,
		"LeaderboardController doesn't keep its payload in ClientState.leaderboard"
	)
	check(
		string.find(fs.readFile("src/client/ClientState.luau"), "leaderboard", 1, true) ~= nil,
		"ClientState's comment doesn't know the leaderboard key"
	)
	check(
		string.find(fs.readFile("src/client/init.client.luau"), '"TopLawnsController"', 1, true) ~= nil,
		"init.client doesn't start TopLawnsController"
	)

	-- The clean-stripe splash (ruling 11): GrassController follows each mower pass and fires StripDone
	-- (a Signal) once, when the pass ends, if it went Strip.LENGTH studs or more along the way its first
	-- seconds went and nothing bad happened in it (a stalled blade, Blocked, Ragged, a fall); the pass
	-- maths is src/shared/Strip.luau, run by behaviour in check-mowing; HudController
	-- connects StripDone and shows it, at most once every SPLASH_COOLDOWN seconds, never over a menu, the
	-- pay panel or a scene, and tells the server nothing (it is cosmetic: no XP).
	check(
		string.find(grassSource, "GrassController.StripDone = Signal.new()", 1, true) ~= nil
			and select(2, string.gsub(grassSource, "StripDone:Fire%(", "")) == 1
			and string.find(grassSource, "local function trackPass", 1, true) ~= nil
			and string.find(grassSource, "trackPass(now, tool, root)", 1, true) ~= nil
			and string.find(grassSource, "Strip.cheers(finished, factsOf(tool))", 1, true) ~= nil,
		"GrassController doesn't follow mower passes and fire StripDone once, from endPass"
	)
	-- cuttingMower is asked once a frame and handed to the pass tracker and the painter.
	check(
		select(2, string.gsub(grassSource, "= cuttingMower%(%)", "")) == 1
			and string.find(grassSource, "paintOwnMower(now, tool, root)", 1, true) ~= nil,
		"GrassController asks cuttingMower() more than once a frame"
	)
	local stripSource = fs.readFile("src/shared/Strip.luau")
	local stripLength = tonumber(string.match(stripSource, "Strip%.LENGTH = (%d+)"))
	check(stripLength ~= nil and stripLength >= 30, "Strip.LENGTH is under 30 studs")
	local factsBody = string.match(grassSource, "local function factsOf.-\nend\n") or ""
	for _, bad in { '"Blocked"', '"Ragged"', '"Working"', "Health" } do
		check(string.find(factsBody, bad, 1, true) ~= nil, `GrassController's pass facts don't read {bad}`)
	end
	check(
		string.find(hudSource, "GrassController.StripDone:Connect(showSplash)", 1, true) ~= nil,
		"HudController doesn't connect GrassController.StripDone to the splash"
	)
	local splashCooldown = tonumber(string.match(hudSource, "local SPLASH_COOLDOWN = (%d+)"))
	check(
		splashCooldown ~= nil and splashCooldown >= 8,
		"HudController's SPLASH_COOLDOWN is under 8 seconds (at most one splash every 8)"
	)
	check(
		string.find(hudSource, "now - splashAt < SPLASH_COOLDOWN", 1, true) ~= nil,
		"HudController's splash doesn't hold to its cooldown"
	)
	local splashBody = string.match(hudSource, "local function splashFree.-\nlocal function showSplash.-\nend\n") or ""
	check(splashBody ~= "", "HudController has no splash (splashFree and showSplash)")
	for _, wanted in
		{
			"UI.needsCursor()",
			"not payShown()",
			"UI.getScreen().Enabled",
			"UI.titleCardDone()",
			"Juicy.pop(inner)",
			'Sounds.playUi("Star", SPLASH_VOLUME)',
			"Rotation = SPLASH_TILT",
		}
	do
		check(string.find(splashBody, wanted, 1, true) ~= nil, `HudController's splash doesn't have {wanted}`)
	end
	for _, never in { "FireServer", "InvokeServer", "Net.", "DataService" } do
		check(string.find(splashBody, never, 1, true) == nil, `HudController's splash reaches the server ({never})`)
	end
	-- The splash lives in its own module (Hud/Splash), so what it asks of the pay panel (payShown) is what
	-- HudController hands it when it starts it: whether its pay panel is up.
	check(
		string.find(hudSource, "payShown = isPayShown", 1, true) ~= nil
			and string.find(hudSource, "Splash%.start%(function%(%)%s*return payPanel ~= nil%s*end%)") ~= nil,
		"HudController doesn't start the splash with its pay panel (Splash.start, payPanel ~= nil, payShown)"
	)
	check(
		string.find(hudSource, 'SPLASH_WORDS = { "NICE STRIPE!", "CLEAN CUT!", "PERFECT LINE!" }', 1, true) ~= nil
			and string.find(hudSource, "local SPLASH_TEXT_SIZE = 54", 1, true) ~= nil
			and string.find(hudSource, "local SPLASH_TEXT_SIZE_SMALL = 40", 1, true) ~= nil
			and string.find(hudSource, "local SPLASH_STROKE = 4", 1, true) ~= nil
			and string.find(hudSource, "local SPLASH_TILT = -4", 1, true) ~= nil
			and string.find(hudSource, "local SPLASH_SHOWN = 1.2", 1, true) ~= nil,
		"HudController's splash words, 54/40 px size, 4 px stroke, -4 degree tilt or 1.2 s aren't the plan's"
	)
	local splashPlace = UiLayout.Splash
	check(splashPlace ~= nil, "UiLayout has no Splash")
	if splashPlace then
		check(
			splashPlace.screen == "LawnUI" and splashPlace.position[3] == 0.42 and splashPlace.anchor[1] == 0.5,
			"UiLayout's Splash isn't centred at 0.42 of the screen height"
		)
	end

	-- The juice pass (ruling 12): every HUD control that acts gets the hover, press squash and Click of a
	-- Juicy button, through the one helper Juicy.juice (a GuiButton, and the GuiObject that moves when it
	-- is not itself). A Juicy button runs the same helper, and plays no Click of its own.
	local juiceSource = fs.readFile("src/client/Juicy.luau")
	check(
		string.find(
			juiceSource,
			"function Juicy.juice(button: GuiButton, target: GuiObject?, silent: boolean?)",
			1,
			true
		)
				~= nil
			and string.find(juiceSource, "Juicy.juice(button, content)", 1, true) ~= nil
			and select(2, string.gsub(juiceSource, 'Sounds.playUi%("Click"', "")) == 1,
		"Juicy.button doesn't get its feel from Juicy.juice (or plays Click more than once)"
	)
	-- A button given no target is never scaled itself (its hit area would shrink and a list would shift
	-- its neighbours): its looks move into a JuiceFace and that is scaled. A button hidden by its own
	-- click (a window closing) lets go of hover afterwards, and one that destroys itself plays Juicy.click()
	-- in its handler and is juiced silent.
	check(
		string.find(juiceSource, "scaleOf(target or faceOf(button))", 1, true) ~= nil
			and string.find(juiceSource, "scaleOf(target or button)", 1, true) == nil
			and string.find(juiceSource, 'FACE_NAME = "JuiceFace"', 1, true) ~= nil,
		"Juicy.juice scales the button itself instead of an inner JuiceFace"
	)
	check(
		string.find(juiceSource, "task.defer(function()", 1, true) ~= nil
			and string.find(juiceSource, "if not isShown(button) then", 1, true) ~= nil,
		"Juicy.juice doesn't let go of hover when the button is hidden by its own click"
	)
	for _, silentUser in
		{
			{ "src/client/Controllers/HudController.luau", "Juicy.juice(niceButton, nil, true)" },
			{ "src/client/Controllers/PartyController.luau", "Juicy.juice(join, nil, true)" },
			{ "src/client/Controllers/PartyController.luau", "Juicy.juice(decline, nil, true)" },
		}
	do
		check(
			string.find(fs.readFile(silentUser[1]), silentUser[2], 1, true) ~= nil,
			`{silentUser[1]} doesn't have {silentUser[2]}: a button that destroys itself clicks in its handler`
		)
	end
	check(
		string.find(uiSource, "require(script.Parent.Juicy).juice(closeButton)", 1, true) ~= nil,
		"UI.panel doesn't give every window's X the Juicy feel"
	)
	local juiceUsers = {
		{
			"src/client/Controllers/HudController.luau",
			{ "Juicy.juice(missedButton)", "Juicy.juice(niceButton, nil, true)" },
		},
		{ "src/client/Hud/StatPills.luau", { "Juicy.juice(levelsButton, levelHolder)" } },
		{
			"src/client/Controllers/TopLawnsController.luau",
			{ "Juicy.juice(tab)" },
		},
		{
			"src/client/Controllers/ContractsController.luau",
			{ 'Juicy.juice(UI.button("Close"' },
		},
		{
			"src/client/Controllers/LevelsController.luau",
			{ 'Juicy.juice(UI.button(if Art.icon("Close")', 'Juicy.juice(UI.button("Close"' },
		},
		{
			"src/client/Controllers/PartyController.luau",
			{ "Juicy.juice(join, nil, true)", "Juicy.juice(decline, nil, true)" },
		},
	}
	for _, user in juiceUsers do
		local source = fs.readFile(user[1])
		for _, wanted in user[2] do
			check(string.find(source, wanted, 1, true) ~= nil, `{user[1]} doesn't have {wanted}`)
		end
	end
	check(
		string.find(hudSource, 'Sounds.playUi("Click", 0.4)', 1, true) == nil
			and string.find(hudSource, "Juicy.pop(levelHolder)", 1, true) == nil,
		"HudController's Levels button still plays its own Click or pops the pill (Juicy.juice does both)"
	)
end
-- The goals rail's DONE stamp is words only (UI.stampText): asked of UI.stamp it would be the art's
-- "Job Complete!" once that's uploaded. The stamp scan above doesn't read UI.stampText, which asks
-- for no art.
check(
	string.find(hudSource, 'JobComplete%s*=%s*"DONE"') == nil,
	'HudController stamps "DONE" with UI.stamp, which draws the JobComplete art: use UI.stampText'
)

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

-- A customer's tip comes after the share and the total counts it: a line "Tip from <customer>"
-- worth the tip, and no line at all when there's no tip.
do
	local base, weights = job({
		basePay = 66,
		toolFit = 1,
		qualityMultiplier = 1.2,
		speedMultiplier = 1,
		preference = "Balanced",
		crewBonus = 1,
		truckBonus = 1,
		businessBonus = 1,
		curbBonus = 1,
		penalty = 0,
		wonBack = 0,
		crew = 2,
	})
	local baseLines, baseTotal = PayBreakdown.lines(base, weights)

	local tipped = table.clone(base)
	tipped.tip = 12
	tipped.customer = "Mrs. Alvarez"
	local lines, total = PayBreakdown.lines(tipped, weights)
	local last = lines[#lines]
	check(last.label == "Tip from Mrs. Alvarez", `the last line is "{last.label}", not the tip`)
	check(last.amount == 12, `the tip line is worth {last.amount}, not 12`)
	check(#lines == #baseLines + 1, "a tip adds exactly one line")
	check(total == baseTotal + 12, `a $12 tip makes the total {baseTotal + 12}, not {total}`)
	local sum = 0
	for _, payLine in lines do
		sum += payLine.amount
	end
	check(sum == total, `with a tip the lines add up to {sum}, not the total {total}`)

	-- No customer on the result: the tip's line names "the customer", with the same amount.
	local nameless = table.clone(tipped)
	nameless.customer = nil
	local namelessLines, namelessTotal = PayBreakdown.lines(nameless, weights)
	local namelessLast = namelessLines[#namelessLines]
	check(namelessLast.label == "Tip from the customer", `a tip with no customer reads "{namelessLast.label}"`)
	check(namelessLast.amount == 12 and namelessTotal == total, "a tip with no customer is still $12 in the total")

	local noTips = { { "a tip of 0", 0 }, { "no tip", false } }
	for _, case in noTips do
		local quiet = table.clone(base)
		quiet.tip = if case[2] then case[2] else nil
		quiet.customer = "Mrs. Alvarez"
		local quietLines, quietTotal = PayBreakdown.lines(quiet, weights)
		check(#quietLines == #baseLines, `{case[1]} still adds a line`)
		check(quietTotal == baseTotal, `{case[1]} changes the total to {quietTotal}`)
		for _, payLine in quietLines do
			check(string.find(payLine.label, "Tip", 1, true) == nil, `{case[1]} still shows "{payLine.label}"`)
		end
	end
end

-- Juicy's palette ---------------------------------------------------------------------------------

-- src/client/JuicyPalette.luau is the front-page HUD's colours with nothing else in it, so it loads
-- here with Lune's Color3 (Juicy itself builds Instances and stays out of Lune). Each face is a
-- gradient from a lighter top to a darker bottom, the ink outline is darker than every bottom, and
-- the colours are the ones the plan's first ruling names (plus Danger and Gold, which the HUD adds, and
-- Muted, the Settings window's choices not taken).
local juicyPalette = luau.load(fs.readFile("src/client/JuicyPalette.luau"), {
	chunkName = "JuicyPalette",
	environment = { Color3 = roblox.Color3 },
})()

-- How bright a colour looks: the standard sRGB relative luminance.
local function luminance(color: any): number
	local function linear(channel: number): number
		if channel <= 0.04045 then
			return channel / 12.92
		end
		return ((channel + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
end

local function hex(color: any): string
	local function byte(channel: number): number
		return math.floor(channel * 255 + 0.5)
	end
	return string.format("#%02X%02X%02X", byte(color.R), byte(color.G), byte(color.B))
end

local JUICY_FACES = {
	Money = { "#69E25A", "#3DAE38" },
	Level = { "#8FD8FF", "#3D9BE8" },
	Streak = { "#FFB347", "#F0661D" },
	Countdown = { "#B48CFF", "#6B4FBF" },
	Truck = { "#74C0FF", "#2D7FE0" },
	Guide = { "#FFC85C", "#F08A1D" },
	Crew = { "#C9A6FF", "#8A5BE8" },
	Contracts = { "#FF9A7A", "#E8553A" },
	Shop = { "#5EE0C8", "#1FA98F" },
	Gifts = { "#FF9AC9", "#E8459A" },
	TopLawns = { "#FFE066", "#E8A61E" },
	Settings = { "#C9D3CC", "#8A9A8E" },
	Cream = { "#FFFFFF", "#FFF1C2" },
	Danger = { "#FF7A6B", "#E0553F" },
	Gold = { "#FFE066", "#F2B92F" },
	Muted = { "#5C6B61", "#3F4C43" },
}

local ink = juicyPalette.Ink
check(typeof(ink) == "Color3", "JuicyPalette.Ink is a Color3")
check(typeof(ink) == "Color3" and hex(ink) == "#1B2A1E", "JuicyPalette.Ink is #1B2A1E")
check(typeof(juicyPalette.Badge) == "Color3" and hex(juicyPalette.Badge) == "#FFE066", "JuicyPalette.Badge is #FFE066")
check(typeof(juicyPalette.Glass) == "Color3" and hex(juicyPalette.Glass) == "#1B2A1E", "JuicyPalette.Glass is #1B2A1E")
check(juicyPalette.GlassTransparency == 0.12, "JuicyPalette.GlassTransparency is 0.12 (rgba .88)")

for name, hexes in JUICY_FACES do
	local face = juicyPalette[name]
	check(typeof(face) == "table", `JuicyPalette has no {name} face`)
	if typeof(face) == "table" then
		check(
			typeof(face.top) == "Color3" and typeof(face.bottom) == "Color3",
			`JuicyPalette.{name} needs a top and a bottom Color3`
		)
		if typeof(face.top) == "Color3" and typeof(face.bottom) == "Color3" then
			check(hex(face.top) == hexes[1], `JuicyPalette.{name}.top is {hex(face.top)}, not {hexes[1]}`)
			check(hex(face.bottom) == hexes[2], `JuicyPalette.{name}.bottom is {hex(face.bottom)}, not {hexes[2]}`)
			check(
				luminance(face.top) > luminance(face.bottom),
				`JuicyPalette.{name}: the top isn't lighter than the bottom`
			)
			if typeof(ink) == "Color3" then
				check(
					luminance(ink) < luminance(face.bottom),
					`JuicyPalette.{name}: the ink isn't darker than the bottom`
				)
			end
		end
	end
end
-- The badge yellow is Gold's top, so a badge (Badge on top, Gold's bottom below) is one yellow.
if typeof(juicyPalette.Badge) == "Color3" and typeof(juicyPalette.Gold) == "table" then
	check(juicyPalette.Badge == juicyPalette.Gold.top, "JuicyPalette.Badge isn't the top of JuicyPalette.Gold")
end
-- No face outside the list: the faces are the first ruling's plus Danger and Gold, and a new one is
-- added to the plan and to JUICY_FACES together.
for name, value in juicyPalette do
	if typeof(value) == "table" then
		check(
			JUICY_FACES[name] ~= nil,
			`JuicyPalette.{name} isn't one of the first ruling's faces, nor Danger, Gold or Muted`
		)
	end
end

-- Every face HudController asks Juicy for is in the palette, and the money plate draws its four pills.
local pillsDrawn: { [string]: boolean } = {}
for name in string.gmatch(hudSource, 'Juicy%.pill%(%s*"([%w_]+)"') do
	pillsDrawn[name] = true
	check(
		typeof(juicyPalette[name]) == "table",
		`HudController draws a Juicy pill in {name}, which isn't a palette face`
	)
end
for _, name in { "Money", "Level", "Streak", "Countdown" } do
	check(pillsDrawn[name] == true, `HudController doesn't draw the {name} pill with Juicy.pill`)
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
