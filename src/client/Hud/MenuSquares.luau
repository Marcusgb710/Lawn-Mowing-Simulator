-- The four menu squares in the left column: Truck, Guide, Crew and Contracts, glossy colour squares with
-- their glyphs and names under them, and on a keyboard their keys (T, G, C) on a corner; a column on a
-- PC and a 2x2 grid on a touch or short screen. The Contracts one opens the contracts panel, and a
-- yellow badge on it counts the contracts left today. HudController builds them (MenuSquares.build),
-- opens a menu from its key (MenuSquares.MENUS) and tells the badge when the day's view changes; a paid
-- contract's cash lifts off contractsFace.

local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.Parent.ClientState)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local Bits = require(script.Parent.Bits)
local Columns = require(script.Parent.Columns)

type Piece = Bits.Piece

local MenuSquares = {}

-- The menu buttons down the left, their glyphs, the key that opens each one, and its button's
-- place in UiLayout.luau. Jobs and the Business app are on the computer in your shop (see
-- ComputerController); the Orders window opens from the Shop button too, wherever you stand.
local MENUS = {
	{ name = "Truck", key = Enum.KeyCode.T, layout = "TruckButton", color = "Truck" },
	{ name = "Guide", key = Enum.KeyCode.G, layout = "GuideButton", color = "Guide" },
	{ name = "Crew", key = Enum.KeyCode.C, layout = "CrewButton", color = "Crew" },
}
MenuSquares.MENUS = MENUS
-- The fourth square opens the contracts panel (no key; the mailbox at the curb opens it too).
local CONTRACTS_SQUARE = { name = "Contracts", layout = "ContractsButton", color = "Contracts", icon = "Jobs" }
-- The squares are 76 px faces on a PC (UiLayout's TruckButton and the rest are that and the label under
-- it). On a touch or short screen they sit in a 2x2 grid of GRID_FACE px faces, built at that size
-- (not a smaller drawing of the PC ones: a list is not promised to make room for a child's UIScale),
-- with this much between them across and down; check-gui works out from these that a grid square is
-- 44 px or more on a phone.
local SQUARE_FACE = 76
local GRID_FACE = 64
local SQUARE_GAP_X = 16
local SQUARE_GAP_Y = 8
-- The Contracts square's count badge hangs this far off its top right corner.
local COUNT_BADGE_OVERHANG = 8

-- The menu squares' holder, the mouse hint in it (with a keyboard), the Contracts square's face (cash
-- lifts off it) and the count badge on it, with its number, while there are contracts left today.
local menuHolder: Frame
-- The menu squares' pieces, for fitting them to the screen.
local squarePieces: { Piece } = {}
local mouseHint: TextLabel?
local contractsFace: Frame
local contractsBadge: Frame?
local contractsBadgeText: TextLabel?

-- The face a menu square is built with on this screen: the grid's on a touch or short screen, the
-- PC column's otherwise.
local function squareFace(): number
	return if UI.isTouch() or UI.isCompact() then GRID_FACE else SQUARE_FACE
end

-- Sets a menu square's face (its Body) and the label under it to the face this screen asks for. UI.place
-- has already given the button its UiLayout size, which is that face and the label's room.
local function fitSquare(piece: Piece)
	local faceHeight = squareFace()
	local body = piece.face.Parent
	if body and body:IsA("GuiObject") then
		body.Size = UDim2.new(1, 0, 0, faceHeight)
	end
	local label = piece.label
	if label then
		label.Position = UDim2.new(0.5, 0, 0, faceHeight + Bits.SQUARE_LABEL_GAP)
	end
	if piece.key and piece.keyText then
		Bits.fitCornerKey(piece.key, piece.keyText, faceHeight)
	end
end

-- One menu square: a glossy face in its colour with its glyph and its name under it, placed by its
-- UiLayout entry in the holder, built at the face this screen asks for (squareFace). Returns the piece.
local function buildSquare(spec, onClick: () -> ()): Piece
	local face = squareFace()
	local button, faceFrame = Juicy.button(spec.color, onClick, {
		Name = spec.name .. "Button",
		Icon = spec.icon or spec.name,
		Label = spec.name,
		Size = UDim2.fromOffset(face, face),
		Parent = menuHolder,
	})
	UI.keepPlaced(button, spec.layout)
	local piece: Piece =
		{ spec = spec, button = button, face = faceFrame, label = button:FindFirstChild("Label", true) }
	if spec.key then
		piece.key, piece.keyText = Bits.addCornerKey(faceFrame, spec.key, face)
	end
	table.insert(squarePieces, piece)
	return piece
end

-- The squares are a column on a PC and a 2x2 grid on a touch screen or a short one (the mouse hint
-- goes with the column). UI.place gives the holder its list and its touch and compact size and scale,
-- so this takes the list away for a grid, and gives it back when the screen is tall again.
local function layoutMenu()
	local grid = menuHolder:FindFirstChildOfClass("UIGridLayout")
	local list = menuHolder:FindFirstChildOfClass("UIListLayout")
	local asGrid = UI.isTouch() or UI.isCompact()
	if asGrid then
		if list then
			list:Destroy()
		end
		if not grid then
			UI.new("UIGridLayout", {
				CellSize = UI.layout("TruckButton").size,
				CellPadding = UDim2.fromOffset(SQUARE_GAP_X, SQUARE_GAP_Y),
				FillDirection = Enum.FillDirection.Horizontal,
				FillDirectionMaxCells = 2,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				StartCorner = Enum.StartCorner.TopLeft,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Parent = menuHolder,
			})
		end
	else
		if grid then
			grid:Destroy()
		end
		if not list then
			UI.place(menuHolder, "MenuButtons")
		end
	end
	if mouseHint then
		mouseHint.Visible = not asGrid
	end
	for _, piece in squarePieces do
		fitSquare(piece)
	end
end

function MenuSquares.build()
	menuHolder = UI.new("Frame", { Name = "Menu", BackgroundTransparency = 1 })
	Columns.placeInColumn(menuHolder, "MenuButtons")

	for _, menu in MENUS do
		buildSquare(menu, function()
			UI.toggle(menu.name)
		end)
	end
	local contracts = buildSquare(CONTRACTS_SQUARE, function()
		UI.toggle("Contracts")
	end)
	contractsFace = contracts.face
	if UserInputService.KeyboardEnabled then
		-- The mouse is locked to the middle of the screen in first person.
		mouseHint = UI.label("Hold Alt for the mouse", {
			TextSize = 13,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			TextStrokeTransparency = 0.6,
			Parent = menuHolder,
		})
		UI.keepPlaced(mouseHint, "MouseHint")
	end
	layoutMenu()
	UI.CompactChanged:Connect(layoutMenu)
end

-- What a paid contract's cash lifts off: the Contracts square's face.
function MenuSquares.contractsFace(): Frame
	return contractsFace
end

-- The Contracts square's count badge: how many of today's contracts are left (the day's three less
-- the ones done), a tilted yellow tag on the square's top right corner. It is not there at 0 and
-- before the server has sent the day's contracts. It is built when the count comes from 0 and
-- destroyed when it goes to 0; any other change only sets its number.
function MenuSquares.updateContractsBadge()
	local view = ClientState.contracts
	local left = 0
	if view then
		left = #view.contracts
		for _, contract in view.contracts do
			if contract.done then
				left -= 1
			end
		end
	end
	if left <= 0 then
		if contractsBadge then
			contractsBadge:Destroy()
			contractsBadge = nil
			contractsBadgeText = nil
		end
		return
	end
	local text = tostring(left)
	if contractsBadgeText then
		contractsBadgeText.Text = text
		return
	end
	local badge, _face, label = Juicy.badge(text, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, COUNT_BADGE_OVERHANG, 0, -COUNT_BADGE_OVERHANG),
		ZIndex = 8,
		Parent = contractsFace,
	})
	contractsBadge = badge
	contractsBadgeText = label
end

return MenuSquares
