-- The hotbar: the game's own row of tool slots along the bottom of the screen, in place of Roblox's
-- (the Backpack, which UI.luau keeps off for good). Front-page HUD, ruling 10.
--
-- It shows exactly when Roblox's used to: on a job site, while nothing hides the game's screen
-- (UI.setHotbar and UI.hideGame decide, and UI.HotbarChanged says). Every tool you have gets a slot
-- (a Tool with an ItemId, in your Backpack or in your hands), and at least five are drawn, in the
-- order you first got them this session: a tool keeps its place when it goes into your hands and
-- back, or is handed out again (a new loadout, a tool picked up from a service spot). A tool set
-- down on a service spot to be worked on (your Servicing attribute) keeps an empty slot at its place,
-- so the keys after it don't shift; one taken away for good (sold) leaves, the rest closing up. The
-- held tool's slot is a cream face; the others are dark glass, the empty ones dimmer. Each shows the
-- item's picture, or its category's glyph while that isn't uploaded, or its name; with a keyboard,
-- its key on its top left corner. The tool condition chips above it already say what's wrong with the
-- held tool, so the slots don't repeat it.
--
-- It fits the screen's width: the row is drawn smaller (a UIScale on the Row frame inside the placed
-- bar) when it would reach the move stick or the jump button (120 px in from each side on a touch
-- screen, 24 on a PC), but never so small that a slot's face is under 40 px on a touch screen (48 on
-- a PC). When even that doesn't fit, it shows as many slots as fit with the last one a gold "+N" (the
-- tools that didn't fit), which opens a tray of them just above the bar; the held tool is never one
-- of them. The tray closes on any other press (a slot, a key, L1 or R1, or a click or tap anywhere
-- that isn't on a button), when a tool comes out or goes away, and when the bar hides. While it's
-- open it can cover the tool condition chips. The numbers and the fitting are HotbarFit's
-- (src/shared), which scripts/check-gui checks.
--
-- Keys 1 to 9 and 0 take out the first ten tools (or put one away, if it's the one in your hands),
-- and Backspace puts away the tool in your hands, as Roblox's did; a click or tap on any slot does the same for its tool, and a gamepad's L1 and R1
-- step through every tool. It equips through your own Humanoid (EquipTool, UnequipTools), which
-- Roblox replicates to the server for your own character's tools, exactly as Roblox's Backpack did:
-- the server's Tool.Equipped and Tool.Unequipped handlers (ToolService, TruckService) see the same
-- thing either way. It never fights the game holding something on purpose: it does nothing off a job
-- (where a tool from storage is in your hands by the server's say) or while the screen is taken (a
-- scene, the drive, a dialogue), while a menu, the shop computer or Roblox's own menu is up, while you
-- type, while you place a decoration, for the few seconds you're working on a tool, or while your
-- character is dead. Carrying a supply off the tailgate on a job doesn't stop it, as it never stopped
-- Roblox's: taking a tool out puts the supply back (MaintenanceService).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local HotbarFit = require(Shared:WaitForChild("HotbarFit"))

local Art = require(script.Parent.Parent.Art)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local HotbarController = {}

-- Round a slot's face: its ink outline (each side) and, under the held one, its lip. Slots are GAP
-- apart. (HotbarFit has these and the rest of the hotbar's numbers.)
local STROKE = HotbarFit.STROKE
local LIP = HotbarFit.LIP
local GAP = HotbarFit.GAP
-- A face's corners, as a share of its size (14 px on a 60 px face, 12 on 48).
local RADIUS_SHARE = 0.24
-- The item's picture fills this much of the face, a category glyph this much.
local PICTURE_SHARE = 0.8
local GLYPH_SHARE = 0.6
-- The glass of a slot that isn't held: with a tool in it, and empty (dimmer, its outline fainter).
local GLASS_OUTLINE = 3
local GLASS_FULL = Juicy.Palette.GlassTransparency
local GLASS_EMPTY = 0.55
local GLASS_EMPTY_OUTLINE = 0.3
-- The key badge on a slot's top left corner, inside the outline: its size and where its middle is
-- (from the face's corner), and its text.
local KEY_SIZE = 20
local KEY_INSET = 6
local KEY_TEXT_SIZE = 14
-- A tool shown by its name (no picture or glyph uploaded), and the "+N" slot's count.
local NAME_TEXT_SIZE = 11
local MORE_TEXT_SIZE = 22
local CLICK_VOLUME = 0.4

-- The keys, by the place in the order they take out: 1 to 9, then 0 for the tenth.
local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

-- One place in the order: a tool, or (tool nil) the empty place of one set down to be worked on.
type Entry = { id: string, tool: Tool? }

type Slot = {
	button: TextButton,
	content: Frame,
	glass: Frame,
	glassOutline: UIStroke,
	held: Frame,
	picture: ImageLabel,
	glyph: ImageLabel,
	name: TextLabel,
	key: GuiObject?,
	keyLabel: TextLabel?,
	-- The place in the order it shows, as last drawn (nil for an empty filler slot).
	place: number?,
}

-- The placed bar (UiLayout's Hotbar), the Row inside it that is scaled to fit, and the tray.
local bar: Frame
local row: Frame
local rowScale: UIScale
local tray: Frame
local more: TextButton
local moreLabel: TextLabel
local face = 60
local rowSlots: { Slot } = {}
local traySlots: { Slot } = {}
-- The order as last drawn: every place, by its number (keys and L1/R1 go by these).
local entries: { Entry } = {}
local trayOpen = false
local lastHeld: Tool? = nil
-- Each tool's place in the order, by its ItemId: the order they were first seen in this session.
local rankOf: { [string]: number } = {}
local lastRank = 0
-- This life's character and Backpack, and what watches each (dropped when it goes, so a respawn
-- never leaves a second set listening).
local character: Model? = nil
local backpack: Backpack? = nil
local characterWatch: { RBXScriptConnection } = {}
local backpackWatch: { RBXScriptConnection } = {}
local queued = false

local function itemIdOf(tool: Instance): string?
	if not tool:IsA("Tool") then
		return nil
	end
	local id = tool:GetAttribute("ItemId")
	return if typeof(id) == "string" and id ~= "" then id else nil
end

-- Gives a tool's item a place at the end of the order, the first time it's seen.
local function remember(tool: Instance)
	local id = itemIdOf(tool)
	if id and rankOf[id] == nil then
		lastRank += 1
		rankOf[id] = lastRank
	end
end

-- Your game tools (Backpack, then hands) and the place of one set down to be worked on, in the order.
local function gather(): { Entry }
	local list: { Entry } = {}
	for _, container in { backpack, character } do
		if container and container.Parent then
			for _, child in container:GetChildren() do
				local id = itemIdOf(child)
				if id then
					remember(child)
					table.insert(list, { id = id, tool = child :: Tool })
				end
			end
		end
	end
	-- A tool on a service spot (MaintenanceService sets Servicing to its id) keeps its place, empty,
	-- if it had one.
	local servicing = player:GetAttribute("Servicing")
	if typeof(servicing) == "string" and rankOf[servicing] then
		local present = false
		for _, entry in list do
			present = present or entry.id == servicing
		end
		if not present then
			table.insert(list, { id = servicing, tool = nil })
		end
	end
	local found: { [Entry]: number } = {}
	for index, entry in list do
		found[entry] = index
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		local rankA, rankB = rankOf[a.id], rankOf[b.id]
		if rankA ~= rankB then
			return rankA < rankB
		end
		return found[a] < found[b]
	end)
	return list
end

-- Slots -------------------------------------------------------------------------------------------

-- Takes out the tool at place `place` in the order, or puts it away (under Equipping, below).
local press: (place: number) -> ()
local toggleTray: () -> ()

-- A slot's size, and how wide `count` are side by side, for this screen's face, before any scale.
local function cellWidth(): number
	return HotbarFit.cellWidth(face)
end
local function cellHeight(): number
	return HotbarFit.cellHeight(face)
end
local function rowWidth(count: number): number
	return HotbarFit.rowWidth(count, face)
end

local function makeSlot(parent: Instance, name: string): Slot
	local radius = math.floor(face * RADIUS_SHARE + 0.5)
	local button = UI.new("TextButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Selectable = false,
		Text = "",
		Size = UDim2.fromOffset(cellWidth(), cellHeight()),
		Parent = parent,
	})
	-- What pops when it's pressed, so the button keeps one hit area.
	local content = UI.new("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	})
	local outline = UI.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Juicy.Palette.Ink,
		Thickness = GLASS_OUTLINE,
	})
	local glass = UI.new("Frame", {
		Name = "Glass",
		BackgroundColor3 = Juicy.Palette.Glass,
		BackgroundTransparency = GLASS_EMPTY,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(STROKE, STROKE),
		Size = UDim2.fromOffset(face, face),
		ZIndex = 1,
		Parent = content,
	}, { UI.corner(radius), outline })
	local held = Juicy.face("Cream", {
		Name = "Held",
		Position = UDim2.fromOffset(STROKE, STROKE),
		Size = UDim2.fromOffset(face, face),
		Radius = radius,
		Stroke = STROKE,
		Lip = LIP,
		Visible = false,
		ZIndex = 1,
		Parent = content,
	})
	local middle = UDim2.fromOffset(STROKE + face / 2, STROKE + face / 2)
	local picture = UI.new("ImageLabel", {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = middle,
		Size = UDim2.fromOffset(face * PICTURE_SHARE, face * PICTURE_SHARE),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 6,
		Parent = content,
	})
	local glyph = UI.new("ImageLabel", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = middle,
		Size = UDim2.fromOffset(face * GLYPH_SHARE, face * GLYPH_SHARE),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 6,
		Parent = content,
	})
	local toolName = Juicy.text("", {
		Name = "ToolName",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = middle,
		Size = UDim2.fromOffset(face - 6, face - 6),
		TextSize = NAME_TEXT_SIZE,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 6,
		Parent = content,
	})
	-- The key, with a keyboard (like the HUD squares' keys).
	local key: GuiObject? = nil
	local keyLabel: TextLabel? = nil
	if UserInputService.KeyboardEnabled then
		key = UI.sliced("KeyBadge", {
			Name = "Key",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(STROKE + KEY_INSET, STROKE + KEY_INSET),
			Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
			Visible = false,
			ZIndex = 8,
			Parent = content,
		}, { color = Juicy.Palette.Ink, transparency = 0.3, radius = 6 })
		keyLabel = UI.heading("", {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = KEY_TEXT_SIZE,
			ZIndex = 9,
			Parent = key,
		})
	end
	local slot: Slot = {
		button = button,
		content = content,
		glass = glass,
		glassOutline = outline,
		held = held,
		picture = picture,
		glyph = glyph,
		name = toolName,
		key = key,
		keyLabel = keyLabel,
		place = nil,
	}
	-- A click or a tap: the tool at the place it shows now.
	button.Activated:Connect(function()
		if slot.place then
			press(slot.place)
		end
	end)
	return slot
end

-- Draws the place `place` (or an empty filler slot, place nil) in a slot.
local function drawSlot(slot: Slot, place: number?)
	local entry = if place then entries[place] else nil
	local tool = entry and entry.tool
	local isHeld = tool ~= nil and character ~= nil and tool.Parent == character
	slot.place = place
	slot.held.Visible = isHeld
	slot.glass.Visible = not isHeld
	slot.glass.BackgroundTransparency = if tool then GLASS_FULL else GLASS_EMPTY
	slot.glassOutline.Transparency = if tool then 0 else GLASS_EMPTY_OUTLINE
	if slot.key and slot.keyLabel then
		local key = if tool and place then HotbarFit.keyFor(place) else nil
		slot.key.Visible = key ~= nil
		slot.keyLabel.Text = key or ""
	end

	local id = tool and entry.id
	local picture = if id then Art.item(id) else ""
	local category = tool and tool:GetAttribute("Category")
	local glyph = if picture == "" and typeof(category) == "string" then Art.icon(`Cat_{category}`) else ""
	slot.picture.Visible = picture ~= ""
	slot.picture.Image = picture
	slot.glyph.Visible = glyph ~= ""
	slot.glyph.Image = glyph
	slot.glyph.ImageColor3 = if isHeld then Juicy.Palette.Ink else Color3.new(1, 1, 1)
	slot.name.Visible = tool ~= nil and picture == "" and glyph == ""
	slot.name.Text = if tool then tool.Name else ""
end

-- The slot at `index` (1 up) of a pool, made the first time, at its spot in its frame.
local function slotAt(pool: { Slot }, parent: Instance, index: number, name: string): Slot
	local slot = pool[index]
	if not slot then
		slot = makeSlot(parent, `{name}{index}`)
		pool[index] = slot
	end
	slot.button.Visible = true
	return slot
end

local function hideFrom(pool: { Slot }, first: number)
	for index = first, #pool do
		pool[index].button.Visible = false
		pool[index].place = nil
	end
end

-- Drawing -------------------------------------------------------------------------------------------

local function closeTray()
	trayOpen = false
	if tray then
		tray.Visible = false
	end
end

local function render()
	queued = false
	local showing = UI.hotbarShown()
	bar.Visible = showing
	entries = gather()

	local held: Tool? = nil
	for _, entry in entries do
		if entry.tool and character and entry.tool.Parent == character then
			held = entry.tool
		end
	end
	-- A tool coming out or going away closes the tray, as does the bar hiding.
	if held ~= lastHeld or not showing then
		closeTray()
	end
	lastHeld = held

	-- A slot for every place, fitted to the screen's width (HotbarFit).
	local drawn = HotbarFit.drawnCount(#entries)
	local scale, showCount, overflow = HotbarFit.fit(UI.getScreen().AbsoluteSize.X, drawn, UI.isTouch(), face)
	-- The places in the row, in order: all of them, or the first ones and then (behind "+N") the rest.
	local inRow: { number } = {}
	local hidden: { number } = {}
	local rowPlaces = if overflow then showCount - 1 else drawn
	for place = 1, #entries do
		if place <= rowPlaces then
			table.insert(inRow, place)
		else
			table.insert(hidden, place)
		end
	end
	-- The held tool never hides behind "+N": it takes the row's last place, which goes in the tray.
	if overflow then
		for index, place in hidden do
			if entries[place].tool == held and held ~= nil then
				local swapped = inRow[#inRow]
				inRow[#inRow] = place
				hidden[index] = swapped
				table.sort(hidden)
				break
			end
		end
	end
	-- Only tools go in the tray (an empty place of a tool set down stays out of it).
	local trayPlaces: { number } = {}
	for _, place in hidden do
		if entries[place].tool then
			table.insert(trayPlaces, place)
		end
	end

	-- The row.
	local count = showCount
	local width = rowWidth(count)
	row.Size = UDim2.fromOffset(width, cellHeight())
	rowScale.Scale = scale
	bar.Size = UDim2.new(0, math.ceil(width * scale), bar.Size.Y.Scale, bar.Size.Y.Offset)
	local slotCount = if overflow then count - 1 else count
	for index = 1, slotCount do
		local slot = slotAt(rowSlots, row, index, "Slot")
		slot.button.Position = UDim2.fromOffset((index - 1) * (cellWidth() + GAP), 0)
		drawSlot(slot, inRow[index])
	end
	hideFrom(rowSlots, slotCount + 1)

	-- The "+N" slot and its tray.
	more.Visible = overflow and #trayPlaces > 0
	if overflow then
		more.Position = UDim2.fromOffset((count - 1) * (cellWidth() + GAP), 0)
		moreLabel.Text = `+{#trayPlaces}`
	end
	if #trayPlaces == 0 then
		closeTray()
	end
	local perRow = math.max(count, 1)
	local trayRows = math.ceil(#trayPlaces / perRow)
	local trayWidth = rowWidth(math.min(#trayPlaces, perRow))
	local trayHeight = trayRows * cellHeight() + math.max(trayRows - 1, 0) * GAP
	tray.Size = UDim2.fromOffset(trayWidth, trayHeight)
	for index, place in trayPlaces do
		local slot = slotAt(traySlots, tray, index, "TraySlot")
		local column = (index - 1) % perRow
		local line = (index - 1) // perRow
		-- The first line sits at the tray's bottom, nearest the bar.
		slot.button.Position =
			UDim2.fromOffset(column * (cellWidth() + GAP), trayHeight - (line + 1) * cellHeight() - line * GAP)
		drawSlot(slot, place)
	end
	hideFrom(traySlots, #trayPlaces + 1)
	tray.Visible = trayOpen and showing
end

-- Several changes come together (a new loadout is a tool at a time, an equip is a remove and an
-- add), so they draw once.
local function queueRender()
	if not queued then
		queued = true
		task.defer(render)
	end
end

-- The "+N" slot: a gold face with the count of the tools that didn't fit.
local function makeMore()
	local radius = math.floor(face * RADIUS_SHARE + 0.5)
	more = UI.new("TextButton", {
		Name = "More",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Selectable = false,
		Text = "",
		Size = UDim2.fromOffset(cellWidth(), cellHeight()),
		Visible = false,
		Parent = row,
	})
	local content = UI.new("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = more,
	})
	local _holder, goldFace = Juicy.face("Gold", {
		Name = "Gold",
		Position = UDim2.fromOffset(STROKE, STROKE),
		Size = UDim2.fromOffset(face, face),
		Radius = radius,
		Stroke = STROKE,
		Lip = LIP,
		Parent = content,
	})
	moreLabel = Juicy.text("+0", {
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		TextSize = MORE_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
		Parent = goldFace,
	})
	more.Activated:Connect(function()
		toggleTray()
		Juicy.pop(content)
	end)
end

-- Lays the bar out for the screen: its place, and the face size its height gives. The slots are
-- made again when that changes (a window turning short or tall).
local function layOut()
	UI.place(bar, "Hotbar")
	local height = (UI.layout("Hotbar").size :: UDim2).Y.Offset
	local newFace = HotbarFit.faceFor(height)
	if newFace ~= face or not more then
		face = newFace
		for _, pool in { rowSlots, traySlots } do
			for _, slot in pool do
				slot.button:Destroy()
			end
			table.clear(pool)
		end
		if more then
			more:Destroy()
		end
		makeMore()
	end
end

-- Equipping ----------------------------------------------------------------------------------------

local function humanoidOf(): Humanoid?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

-- Whether the hotbar does nothing right now: see the header for each.
local function blocked(): boolean
	-- Off a job site, or a scene, the drive or a dialogue has the screen.
	if not UI.hotbarShown() then
		return true
	end
	-- A menu, the shop computer or the dialogue box has the mouse, or Roblox's menu is open.
	if UI.needsCursor() or GuiService.MenuIsOpen then
		return true
	end
	-- A decoration being placed: the server put it in your hands on purpose. (Carrying is not here.
	-- At your business, where you carry tools from storage, the hotbar is off anyway; on a job the
	-- one thing you carry is a supply off the tailgate, and taking a tool out then is how Roblox's
	-- hotbar always worked: MaintenanceService puts the supply back on the tailgate when a Tool
	-- arrives in your hands.)
	if player:GetAttribute("PlacingDecor") ~= nil then
		return true
	end
	-- Working on a tool, for a few seconds (MaintenanceService). A time long past never blocks.
	local working = player:GetAttribute("MaintainingUntil")
	if typeof(working) == "number" and working > workspace:GetServerTimeNow() then
		return true
	end
	return humanoidOf() == nil
end

-- The slot showing place `place` (in the row or the tray), to pop.
local function slotShowing(place: number): Slot?
	for _, pool in { rowSlots, traySlots } do
		for _, slot in pool do
			if slot.place == place and slot.button.Visible then
				return slot
			end
		end
	end
	return nil
end

press = function(place: number)
	-- Any press closes the tray (pressing a tool in it too: it comes out).
	closeTray()
	if blocked() then
		return
	end
	local entry = entries[place]
	local tool = entry and entry.tool
	local humanoid = humanoidOf()
	if not (tool and humanoid and character) then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	elseif backpack and tool.Parent == backpack then
		humanoid:EquipTool(tool)
	else
		return
	end
	Sounds.playUi("Click", CLICK_VOLUME)
	local slot = slotShowing(place)
	if slot then
		Juicy.pop(slot.content)
	end
	queueRender()
end

toggleTray = function()
	if trayOpen then
		closeTray()
		return
	end
	if blocked() then
		return
	end
	trayOpen = true
	Sounds.playUi("Click", CLICK_VOLUME)
	queueRender()
end

-- Backspace puts away the tool in your hands, as Roblox's Backpack did (nothing happens with empty hands).
local function putAway()
	closeTray()
	if blocked() then
		return
	end
	local humanoid = humanoidOf()
	if humanoid and character and character:FindFirstChildOfClass("Tool") then
		humanoid:UnequipTools()
		Sounds.playUi("Click", CLICK_VOLUME)
		queueRender()
	end
end

-- A gamepad's L1 and R1: the tool before or after the one in your hands, through every tool (the
-- first or last when your hands are empty).
local function step(by: number)
	local places: { number } = {}
	local current = 0
	for place, entry in entries do
		if entry.tool then
			table.insert(places, place)
			if character and entry.tool.Parent == character then
				current = #places
			end
		end
	end
	local count = #places
	if count == 0 then
		return
	end
	local target = if current == 0 then (if by > 0 then 1 else count) else (current - 1 + by) % count + 1
	if target ~= current then
		press(places[target])
	end
end

-- Watching your tools ------------------------------------------------------------------------------

local function drop(connections: { RBXScriptConnection })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function watch(container: Instance, into: { RBXScriptConnection })
	table.insert(
		into,
		container.ChildAdded:Connect(function(child: Instance)
			remember(child)
			queueRender()
		end)
	)
	table.insert(into, container.ChildRemoved:Connect(queueRender))
end

local function useBackpack(newBackpack: Backpack?)
	if newBackpack == backpack then
		return
	end
	drop(backpackWatch)
	backpack = newBackpack
	if newBackpack then
		watch(newBackpack, backpackWatch)
	end
	queueRender()
end

local function useCharacter(newCharacter: Model?)
	if newCharacter == character then
		return
	end
	drop(characterWatch)
	character = newCharacter
	if newCharacter then
		watch(newCharacter, characterWatch)
	end
	-- A new character comes with a new Backpack, which may already be here.
	useBackpack(player:FindFirstChildOfClass("Backpack"))
	queueRender()
end

function HotbarController:Start()
	bar = UI.new("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		-- Over the tool condition chips, which an open tray may cover.
		ZIndex = 2,
		Parent = UI.getScreen(),
	})
	-- The Row holds the slots and is what's scaled to fit (not the placed bar), from its bottom middle,
	-- so the bar's bottom edge stays where UiLayout puts it.
	row = UI.new("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 1),
		Parent = bar,
	})
	rowScale = UI.new("UIScale", { Name = "FitScale", Scale = 1, Parent = row })
	-- The tray, just above the row (and scaled with it), for the tools behind "+N".
	tray = UI.new("Frame", {
		Name = "Tray",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, -GAP),
		Visible = false,
		Parent = row,
	})
	layOut()

	UI.HotbarChanged:Connect(queueRender)
	UI.CompactChanged:Connect(function()
		layOut()
		queueRender()
	end)
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(queueRender)
	player:GetAttributeChangedSignal("Servicing"):Connect(queueRender)

	player.CharacterAdded:Connect(useCharacter)
	player.CharacterRemoving:Connect(function(old: Model)
		if old == character then
			useCharacter(nil)
		end
	end)
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			useBackpack(child)
		end
	end)
	player.ChildRemoved:Connect(function(child: Instance)
		if child == backpack then
			useBackpack(player:FindFirstChildOfClass("Backpack"))
		end
	end)
	useCharacter(player.Character)
	useBackpack(player:FindFirstChildOfClass("Backpack"))

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- A click or a tap that no button took (the world, a gap in the tray) closes an open tray. One
		-- on a slot, the tray or "+N" comes in processed, and that button's own press handles it.
		local kind = input.UserInputType
		if
			trayOpen
			and not processed
			and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
		then
			closeTray()
		end
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local place = KEYS[input.KeyCode]
			if place then
				press(place)
			elseif input.KeyCode == Enum.KeyCode.Backspace then
				putAway()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			step(-1)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			step(1)
		end
	end)

	render()
end

return HotbarController
