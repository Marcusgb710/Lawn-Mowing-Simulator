-- The hotbar: the game's own row of tool slots along the bottom of the screen, in place of Roblox's
-- (the Backpack, which UI.luau keeps off for good). Front-page HUD, ruling 10.
--
-- It shows exactly when Roblox's used to: on a job site, while nothing hides the game's screen
-- (UI.setHotbar and UI.hideGame decide, and UI.HotbarChanged says). A slot for each of your tools
-- (a Tool with an ItemId, in your Backpack or in your hands), at least five drawn and at most nine,
-- in the order you first got them this session: a tool keeps its place when it goes into your hands
-- and back, or is handed out again (a new loadout, a tool picked up from a service spot), and one
-- taken away (set down to be worked on, sold) leaves, the rest closing up. The held tool's slot is
-- a cream face; the others are dark glass, the empty ones dimmer. Each shows the item's picture, or
-- its category's glyph while that isn't uploaded, or its name; with a keyboard, its key on its top
-- left corner. The tool condition chips above it already say what's wrong with the held tool, so
-- the slots don't repeat it.
--
-- Keys 1 to 9 and a click or tap on a slot take that tool out (or put it away, if it's the one in
-- your hands), as Roblox's did; a gamepad's L1 and R1 step to the tool before or after. It equips
-- through your own Humanoid (EquipTool, UnequipTools), which Roblox replicates to the server for
-- your own character's tools, exactly as Roblox's Backpack did: the server's Tool.Equipped and
-- Tool.Unequipped handlers (ToolService, TruckService) see the same thing either way. It never
-- fights the game holding something on purpose: it does nothing off a job (where a tool from
-- storage is in your hands by the server's say) or while the screen is taken (a scene, the drive, a
-- dialogue), while a menu, the shop computer or Roblox's own menu is up, while you type, while you
-- place a decoration, for the few seconds you're working on a tool, or while your character is
-- dead. Carrying a supply off the tailgate on a job doesn't stop it, as it never stopped Roblox's:
-- taking a tool out puts the supply back (MaintenanceService).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))

local Art = require(script.Parent.Parent.Art)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local HotbarController = {}

-- How many slots are drawn: as many as there are tools, but at least this many and at most that.
local MIN_SLOTS = 5
local MAX_SLOTS = 9
-- Round a slot's face: its ink outline (each side) and, under the held one, its lip. UiLayout's
-- Hotbar is a face tall plus ROOM, so the face is worked out from it.
local STROKE = 4
local LIP = 6
local ROOM = STROKE * 2 + LIP
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
-- A tool shown by its name (no picture or glyph uploaded).
local NAME_TEXT_SIZE = 11
local CLICK_VOLUME = 0.4

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
}

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
}

local bar: Frame
local face = 60
local slots: { Slot } = {}
-- The tools in the slots as last drawn, by slot.
local shown: { Tool } = {}
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

-- Your game tools (Backpack, then hands), in the order.
local function gather(): { Tool }
	local tools: { Tool } = {}
	local ids: { [Tool]: string } = {}
	for _, container in { backpack, character } do
		if container and container.Parent then
			for _, child in container:GetChildren() do
				local id = itemIdOf(child)
				if id then
					remember(child)
					table.insert(tools, child :: Tool)
					ids[child :: Tool] = id
				end
			end
		end
	end
	local found: { [Tool]: number } = {}
	for index, tool in tools do
		found[tool] = index
	end
	table.sort(tools, function(a: Tool, b: Tool): boolean
		local rankA, rankB = rankOf[ids[a]], rankOf[ids[b]]
		if rankA ~= rankB then
			return rankA < rankB
		end
		return found[a] < found[b]
	end)
	return tools
end

-- Slots -------------------------------------------------------------------------------------------

-- Takes out the tool in slot `index`, or puts it away (under Equipping, below).
local press: (index: number) -> ()

local function makeSlot(index: number): Slot
	local radius = math.floor(face * RADIUS_SHARE + 0.5)
	local button = UI.new("TextButton", {
		Name = `Slot{index}`,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.fromOffset(face + STROKE * 2, face + ROOM),
		LayoutOrder = index,
		Parent = bar,
	})
	-- A click or a tap. The slot is pressed by its place, so whatever tool is in it then.
	button.Activated:Connect(function()
		press(index)
	end)
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
	local name = Juicy.text("", {
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
		UI.heading(tostring(index), {
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
		name = name,
		key = key,
	}
	return slot
end

-- Draws `tool` (or nothing) in a slot, held or not.
local function drawSlot(slot: Slot, tool: Tool?, isHeld: boolean)
	slot.held.Visible = isHeld
	slot.glass.Visible = not isHeld
	slot.glass.BackgroundTransparency = if tool then GLASS_FULL else GLASS_EMPTY
	slot.glassOutline.Transparency = if tool then 0 else GLASS_EMPTY_OUTLINE
	if slot.key then
		slot.key.Visible = tool ~= nil
	end

	local id = tool and itemIdOf(tool)
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

local function render()
	queued = false
	bar.Visible = UI.hotbarShown()
	local tools = gather()
	local count = math.clamp(#tools, MIN_SLOTS, MAX_SLOTS)
	shown = {}
	for index = 1, MAX_SLOTS do
		local tool = tools[index]
		if index <= count then
			local slot = slots[index]
			if not slot then
				slot = makeSlot(index)
				slots[index] = slot
			end
			slot.button.Visible = true
			drawSlot(slot, tool, tool ~= nil and character ~= nil and tool.Parent == character)
			if tool then
				shown[index] = tool
			end
		elseif slots[index] then
			slots[index].button.Visible = false
		end
	end
end

-- Several changes come together (a new loadout is a tool at a time, an equip is a remove and an
-- add), so they draw once.
local function queueRender()
	if not queued then
		queued = true
		task.defer(render)
	end
end

-- Lays the bar out for the screen: its place, and the face size its height gives. The slots are
-- made again when that changes (a window turning short or tall).
local function layOut()
	UI.place(bar, "Hotbar")
	local height = (UI.layout("Hotbar").size :: UDim2).Y.Offset
	local newFace = math.max(height - ROOM, 1)
	if newFace ~= face then
		face = newFace
		for _, slot in slots do
			slot.button:Destroy()
		end
		slots = {}
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

-- Takes out the tool in slot `index`, or puts it away if it's the one in your hands.
press = function(index: number)
	if blocked() then
		return
	end
	local tool = shown[index]
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
	local slot = slots[index]
	if slot then
		Juicy.pop(slot.content)
	end
	queueRender()
end

-- A gamepad's L1 and R1: the tool before or after the one in your hands (the first or last when
-- your hands are empty).
local function step(by: number)
	-- The slots with tools are the first ones, with no gaps.
	local count = #shown
	if count == 0 then
		return
	end
	local current = 0
	for index = 1, count do
		if character and shown[index].Parent == character then
			current = index
		end
	end
	local target = if current == 0 then (if by > 0 then 1 else count) else (current - 1 + by) % count + 1
	if target ~= current then
		press(target)
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
		Parent = UI.getScreen(),
	})
	layOut()

	UI.HotbarChanged:Connect(queueRender)
	UI.CompactChanged:Connect(function()
		layOut()
		queueRender()
	end)

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
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local index = KEYS[input.KeyCode]
			if index then
				press(index)
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
