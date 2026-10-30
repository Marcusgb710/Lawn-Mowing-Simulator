-- The right buttons down the right edge of the screen (UiLayout's RightButtons): glossy squares for the
-- Shop (the Orders window, from anywhere: B on a keyboard), Gifts (claims the day's streak gift,
-- ClaimStreak, with a tilted CLAIM tag and a pulse while one waits; with none, the contracts panel),
-- Top Lawns (the two leaderboards, TopLawnsController: F) and Settings (comma). Faces are 76 px with
-- their names under them on a PC, 56 px and bare on a phone or a short screen. HudController builds the
-- strip (RightStrip.build), hands it the keys it does not use itself (RightStrip.pressKey), tells the
-- CLAIM tag when the day's view changes and pulses it; what a button does can be changed through
-- HudController.setRightAction (SettingsController gives Settings its window that way).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local ShopController = require(script.Parent.Parent.Controllers.ShopController)
local Bits = require(script.Parent.Bits)

type Piece = Bits.Piece

local player = Players.LocalPlayer

local RightStrip = {}

-- The Gifts button's CLAIM tag while the day's gift waits: it hangs this far off the face's top left
-- corner, tilted the other way from a count badge, and the button pulses every few seconds.
local GIFT_TAG_OVERHANG = 8
local GIFT_TAG_TILT = -8
local GIFT_PULSE_EVERY = 2.5
RightStrip.GIFT_PULSE_EVERY = GIFT_PULSE_EVERY
-- The right buttons: the strip's four squares, their face colours, glyphs and keys (Gifts has no key
-- and a present drawn in code, since the Premium glyph is a diamond; the key badge sits on a face's
-- top left corner, with a keyboard only), and where each is placed in UiLayout.luau. What each does
-- is in rightActions, so a later task can change it (HudController.setRightAction).
local RIGHT_BUTTONS = {
	{ id = "Shop", label = "Shop", layout = "ShopButton", color = "Shop", icon = "Orders", key = Enum.KeyCode.B },
	{ id = "Gifts", label = "Gifts", layout = "GiftsButton", color = "Gifts" },
	{
		id = "TopLawns",
		label = "Top Lawns",
		layout = "TopLawnsButton",
		color = "TopLawns",
		icon = "Crown",
		key = Enum.KeyCode.F,
	},
	{
		id = "Settings",
		label = "Settings",
		layout = "SettingsButton",
		color = "Settings",
		icon = "Wrench",
		key = Enum.KeyCode.Comma,
	},
}
-- On a PC a right button's piece is its face and, under it, the label's 12 px gap and 22 px of room
-- (UiLayout's ShopButton and the rest are 34 taller than the face); on a touch or short screen it is
-- the bare face.
local SQUARE_LABEL_ROOM = 34
-- F also sends a decoration you own back to your inventory while you are placing one (DecorController),
-- so the Top Lawns key leaves it be then.
local PLACING_ATTRIBUTE = "PlacingDecor"
local WHITE = Color3.new(1, 1, 1)

-- The right buttons' strip, and each one's pieces (its spec, button, face and label), for fitting them
-- to the screen.
local rightHolder: Frame
local rightPieces: { Piece } = {}
-- What each right button does (by its id), so it can be changed without building the button again.
local rightActions: { [string]: () -> () } = {}
-- The Gifts button's CLAIM tag while a gift waits, and whether a claim is on its way to the server.
local giftTag: Frame? = nil
local claiming = false

-- A present on a face, drawn from frames: a white box with its lid, a yellow ribbon down the middle
-- and a bow of two loops and a knot on top, all in the ink outline. Sized in fractions of the face, so
-- it keeps its shape at any face size.
local GIFT_SIZE = 0.62
local GIFT_STROKE = 1.5
local function drawGift(face: Frame)
	local function piece(name: string, color: Color3, position: Vector2, size: Vector2, order: number, round: number)
		return UI.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(position.X, position.Y),
			Size = UDim2.fromScale(size.X, size.Y),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = order,
		}, {
			UI.new("UICorner", { CornerRadius = UDim.new(round, 0) }),
			UI.new("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Juicy.Palette.Ink,
				Thickness = GIFT_STROKE,
				LineJoinMode = Enum.LineJoinMode.Round,
			}),
		})
	end
	local gift = UI.new("Frame", {
		Name = "Gift",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(GIFT_SIZE, GIFT_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = face,
	})
	local ribbon = Juicy.Palette.Badge
	piece("Box", WHITE, Vector2.new(0.5, 0.75), Vector2.new(0.8, 0.5), 1, 0.1).Parent = gift
	piece("Lid", WHITE, Vector2.new(0.5, 0.42), Vector2.new(1, 0.24), 2, 0.2).Parent = gift
	piece("Ribbon", ribbon, Vector2.new(0.5, 0.7), Vector2.new(0.16, 0.6), 3, 0.1).Parent = gift
	local left = piece("LeftLoop", ribbon, Vector2.new(0.36, 0.2), Vector2.new(0.3, 0.2), 4, 0.5)
	left.Rotation = -28
	left.Parent = gift
	local right = piece("RightLoop", ribbon, Vector2.new(0.64, 0.2), Vector2.new(0.3, 0.2), 4, 0.5)
	right.Rotation = 28
	right.Parent = gift
	piece("Knot", ribbon, Vector2.new(0.5, 0.26), Vector2.new(0.16, 0.16), 5, 0.5).Parent = gift
end

-- Sets a right button's face, label and corner to the size its UiLayout entry gives on this screen: on
-- a PC the entry is the face and the label's room, on a touch or short screen just the face, and the
-- label goes. UI.place has already put the button at that size; the face is Juicy's Body frame, which
-- is as tall as the face was built, so it is set to match.
local function fitRightButton(piece)
	local small = UI.isTouch() or UI.isCompact()
	local height = UI.layout(piece.spec.layout).size.Y.Offset
	local faceHeight = if small then height else height - SQUARE_LABEL_ROOM
	local body = piece.face.Parent
	if body and body:IsA("GuiObject") then
		body.Size = UDim2.new(1, 0, 0, faceHeight)
	end
	local label = piece.label
	if label then
		label.Visible = not small
		label.Position = UDim2.new(0.5, 0, 0, faceHeight + Bits.SQUARE_LABEL_GAP)
	end
	if piece.key and piece.keyText then
		Bits.fitCornerKey(piece.key, piece.keyText, faceHeight)
	end
end

-- Whether the day's view says today's gift (the streak's cash) is waiting to be claimed.
local function giftWaiting(): boolean
	local view = ClientState.contracts
	return view ~= nil and view.streak ~= nil and view.streak.claimable == true
end

-- The Gifts button: claims the waiting gift (the server pays it and the Payday card follows, from
-- StreakAdvanced), or with none waiting opens the contracts panel, whose streak card says what
-- tomorrow's pays. One claim at a time; when one doesn't go through the server says why.
local function pressGifts()
	if not giftWaiting() then
		UI.toggle("Contracts")
		return
	end
	if claiming then
		return
	end
	claiming = true
	task.spawn(function()
		local ok, claimed, message = pcall(function()
			return Net.func("ClaimStreak"):InvokeServer()
		end)
		claiming = false
		if not ok then
			UI.notify("Your gift didn't come through. Try again in a moment.")
		elseif not claimed and typeof(message) == "string" then
			UI.notify(message)
		end
	end)
end

-- The strip down the right edge (UiLayout's RightButtons): Shop, Gifts, Top Lawns and Settings. Built
-- straight at the size this screen asks (a UIScale on the strip would leave the buttons' sizes to the
-- layout's mercy), and fitted again if the screen turns short or tall. Returns the Gifts and Settings
-- buttons and faces, which other controllers build on (a tag on Gifts, the window behind Settings).
local function buildRightButtons(): { [string]: GuiObject }
	rightHolder = UI.new("Frame", {
		Name = "RightButtons",
		BackgroundTransparency = 1,
		Parent = UI.getScreen(),
	})
	UI.keepPlaced(rightHolder, "RightButtons")

	local small = UI.isTouch() or UI.isCompact()
	for _, spec in RIGHT_BUTTONS do
		local size = UI.layout(spec.layout).size
		local face = if small then size.Y.Offset else size.Y.Offset - SQUARE_LABEL_ROOM
		local button, faceFrame = Juicy.button(spec.color, function()
			rightActions[spec.id]()
		end, {
			Name = spec.id .. "Button",
			Icon = spec.icon,
			Label = spec.label,
			Size = UDim2.fromOffset(size.X.Offset, face),
			Parent = rightHolder,
		})
		UI.keepPlaced(button, spec.layout)
		if spec.id == "Gifts" then
			drawGift(faceFrame)
		end
		local piece: Piece = {
			spec = spec,
			button = button,
			face = faceFrame,
			label = button:FindFirstChild("Label", true),
		}
		if spec.key then
			piece.key, piece.keyText = Bits.addCornerKey(faceFrame, spec.key, face)
		end
		table.insert(rightPieces, piece)
		fitRightButton(piece)
	end

	-- Where each button goes: the Shop opens the Orders window (or puts it away when it is up), Gifts
	-- claims the day's gift (or shows the contracts panel's streak card when none waits), Top Lawns the
	-- leaderboards, and Settings the Settings window (SettingsController gives it that when it starts,
	-- through setRightAction). Opening one closes any other menu, since only one is up at a time
	-- (UI.open).
	rightActions.Shop = function()
		-- Puts the Orders window away; with the computer's Business app up it switches to Orders instead.
		if UI.isOpen("Shop") and ShopController.currentApp() == "Orders" then
			UI.close("Shop")
		else
			ShopController.openApp("Orders")
		end
	end
	rightActions.Gifts = pressGifts
	rightActions.TopLawns = function()
		UI.toggle("TopLawns")
	end
	rightActions.Settings = function() end

	UI.CompactChanged:Connect(function()
		for _, piece in rightPieces do
			fitRightButton(piece)
		end
	end)

	return {
		giftsButton = rightPieces[2].button,
		giftsFace = rightPieces[2].face,
		settingsButton = rightPieces[4].button,
		settingsFace = rightPieces[4].face,
	}
end
RightStrip.build = buildRightButtons

-- Changes what a right button does ("Gifts" or "Settings", or any of the four by its id), so the task
-- that wires it up needs no new button.
function RightStrip.setRightAction(id: string, action: () -> ())
	assert(rightActions[id] ~= nil, `HudController has no right button {id}`)
	rightActions[id] = action
end

-- A key for the strip (`keyCode`): does what its button does, and says whether it was one of the
-- strip's keys. F is left to DecorController while a decoration is being placed.
function RightStrip.pressKey(keyCode: Enum.KeyCode): boolean
	for _, button in RIGHT_BUTTONS do
		if button.key and keyCode == button.key then
			if button.id == "TopLawns" and player:GetAttribute(PLACING_ATTRIBUTE) ~= nil then
				return true
			end
			rightActions[button.id]()
			return true
		end
	end
	return false
end

-- A pulse of the Gifts button: its Content frame, which grows from its middle and holds the hover
-- scale (Juicy.pulse works relative to that and gives way to a hover or a press).
local function pulseGifts()
	local button = rightPieces[2] and rightPieces[2].button
	local content = button and button:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		Juicy.pulse(content)
	end
end

-- The Gifts button pulses while its CLAIM tag is up (HudController calls this every GIFT_PULSE_EVERY
-- seconds).
function RightStrip.pulseWaitingGift()
	if giftTag then
		pulseGifts()
	end
end

-- The CLAIM tag on the Gifts button's face, from the day's view: on while a gift waits (with a pulse
-- as it appears, then every GIFT_PULSE_EVERY seconds from HudController's loop), gone once it is
-- claimed.
function RightStrip.updateGiftTag()
	local face = rightPieces[2] and rightPieces[2].face
	if not face then
		return
	end
	local waiting = giftWaiting()
	if waiting and not giftTag then
		local tag = Juicy.badge("CLAIM", {
			Name = "ClaimTag",
			Position = UDim2.fromOffset(-GIFT_TAG_OVERHANG, -GIFT_TAG_OVERHANG),
			Rotation = GIFT_TAG_TILT,
			ZIndex = 8,
			Parent = face,
		})
		giftTag = tag
		pulseGifts()
	elseif not waiting and giftTag then
		giftTag:Destroy()
		giftTag = nil
	end
end

return RightStrip
