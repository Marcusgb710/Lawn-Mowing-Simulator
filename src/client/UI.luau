-- Small helpers for building placeholder UI in code.
-- When you design real UI in Studio, the controllers are the only things that need to change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local UI = {}

-- Fired when a menu opens or closes. In first person the mouse is locked to the middle of the
-- screen, so CameraController frees it while a menu is open (see UI.needsCursor).
UI.CursorChanged = Signal.new()

UI.Colors = {
	Background = Color3.fromRGB(30, 40, 30),
	Panel = Color3.fromRGB(45, 60, 45),
	Card = Color3.fromRGB(60, 80, 60),
	Accent = Color3.fromRGB(120, 200, 75),
	Money = Color3.fromRGB(255, 220, 90),
	Danger = Color3.fromRGB(200, 70, 60),
	Disabled = Color3.fromRGB(90, 90, 90),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(200, 215, 200),
	-- The story's dialogue box, speech bubbles and texts (DialogueController, the Messages app).
	Outline = Color3.fromRGB(30, 40, 30), -- the dark edge around boxes, bubbles and name tags
	Letterbox = Color3.fromRGB(14, 19, 14),
	Track = Color3.fromRGB(78, 100, 78), -- a line dot still to come, an empty progress bar
	Bubble = Color3.fromRGB(255, 255, 255),
	BubbleText = Color3.fromRGB(30, 40, 30),
	-- TurfKing and Gloria's side: the "Taken by TurfKing" job card, and her side of the contest.
	TurfKing = Color3.fromRGB(88, 52, 150), -- TurfKing's purple
	Rival = Color3.fromRGB(185, 166, 238), -- light purple writing on a dark panel
	RivalFill = Color3.fromRGB(138, 112, 214), -- her score bars
	-- Each character's color (by their key in Config/Story.luau's Cast): the caption on their
	-- speech bubbles, and their circle where there's no portrait yet.
	Cast = {
		June = Color3.fromRGB(227, 194, 122),
		Gloria = Color3.fromRGB(107, 79, 191),
		Chad = Color3.fromRGB(107, 79, 191),
		Sam = Color3.fromRGB(110, 190, 180),
		Edna = Color3.fromRGB(232, 160, 184),
		BridgeClub = Color3.fromRGB(168, 200, 232),
		Customer = Color3.fromRGB(232, 160, 184),
	},
}

local FONT = Enum.Font.FredokaOne
-- The game's font, for anything not made with UI.label or UI.button.
UI.Font = FONT

local screen: ScreenGui = nil
local panels = {}
-- While set, menus open inside this frame (the shop computer's screen) instead of on their own.
local host: Frame? = nil
local PANEL_SIZE = UDim2.fromScale(0.9, 0.75)
local PANEL_MAX = Vector2.new(720, 520)

-- UI.new("Frame", { Size = ... }, { children })
function UI.new(className: string, props, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UI.padding(pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return UI.new(
		"UIPadding",
		{ PaddingTop = amount, PaddingBottom = amount, PaddingLeft = amount, PaddingRight = amount }
	)
end

function UI.list(padding: number?, direction: Enum.FillDirection?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.label(text: string, props): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
	})
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

function UI.button(text: string, onClick: () -> (), props): TextButton
	local button = UI.new("TextButton", {
		BackgroundColor3 = UI.Colors.Accent,
		Font = FONT,
		Text = text,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(110, 36),
	}, { UI.corner(8) })
	for key, value in props or {} do
		button[key] = value
	end
	button.Activated:Connect(onClick)
	return button
end

function UI.getScreen(): ScreenGui
	if not screen then
		screen = UI.new("ScreenGui", {
			Name = "LawnUI",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
	end
	return screen
end

-- A centered window with a title and close button. Returns the window and its content frame.
function UI.panel(name: string, title: string)
	local window = UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = PANEL_SIZE,
		BackgroundColor3 = UI.Colors.Background,
		Visible = false,
		Parent = host or UI.getScreen(),
	}, {
		UI.corner(12),
		UI.new("UISizeConstraint", { MaxSize = PANEL_MAX }),
		UI.label(title, {
			Name = "Title",
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -80, 0, 32),
			TextSize = 28,
		}),
	})

	UI.button("X", function()
		UI.close(name)
	end, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = UI.Colors.Danger,
		Parent = window,
	})

	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 1, -68),
		Parent = window,
	})

	panels[name] = window
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		UI.CursorChanged:Fire()
	end)
	return window, content
end

function UI.scrollingList(parent: Instance, props): ScrollingFrame
	local frame = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = parent,
	}, { UI.list(8) })
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function UI.clearList(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Puts a menu inside the host frame (filling it, with a slimmer title so a phone's small screen
-- has room for the list), or back on the screen on its own.
local function dock(panel: Frame)
	local docked = host ~= nil
	local constraint = panel:FindFirstChildOfClass("UISizeConstraint")
	panel.Parent = host or UI.getScreen()
	panel.Size = if docked then UDim2.fromScale(1, 1) else PANEL_SIZE
	if constraint then
		constraint.MaxSize = if docked then Vector2.new(math.huge, math.huge) else PANEL_MAX
	end
	local edge, top = if docked then 10 else 16, if docked then 40 else 52
	local title = panel:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Position = UDim2.fromOffset(edge, if docked then 6 else 10)
		title.Size = UDim2.new(1, -80, 0, if docked then 28 else 32)
		title.TextSize = if docked then 22 else 28
	end
	local close = panel:FindFirstChild("Close")
	if close and close:IsA("GuiObject") then
		close.Position = if docked then UDim2.new(1, -6, 0, 4) else UDim2.new(1, -10, 0, 10)
		close.Size = if docked then UDim2.fromOffset(32, 32) else UDim2.fromOffset(36, 36)
	end
	local content = panel:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		content.Position = UDim2.fromOffset(edge, top)
		content.Size = UDim2.new(1, -edge * 2, 1, -(top + edge))
	end
end

-- Whether menus are showing inside the shop computer's screen: someone's at the computer.
function UI.hosted(): boolean
	return host ~= nil
end

-- Shows menus inside `frame` (the shop computer's screen) until it's set back to nil.
function UI.setHost(frame: Frame?)
	host = frame
	for _, panel in panels do
		dock(panel)
	end
	UI.CursorChanged:Fire()
end

-- Only one panel is open at a time.
function UI.open(name: string)
	for otherName, panel in panels do
		panel.Visible = otherName == name
	end
end

function UI.close(name: string)
	if panels[name] then
		panels[name].Visible = false
	end
end

function UI.toggle(name: string)
	if panels[name] and panels[name].Visible then
		UI.close(name)
	else
		UI.open(name)
	end
end

function UI.isOpen(name: string): boolean
	return panels[name] ~= nil and panels[name].Visible
end

function UI.anyOpen(): boolean
	for _, panel in panels do
		if panel.Visible then
			return true
		end
	end
	return false
end

function UI.closeAll()
	for _, panel in panels do
		panel.Visible = false
	end
end

-- A menu's window, to change its title.
function UI.panelWindow(name: string): Frame?
	return panels[name]
end

-- Things besides menus that need the mouse free while they're up (the dialogue box), by name.
local cursorHolders: { [string]: boolean } = {}
function UI.holdCursor(reason: string, held: boolean)
	cursorHolders[reason] = if held then true else nil
	UI.CursorChanged:Fire()
end

-- Whether a menu (or the shop computer, or the dialogue box) is open, which needs the mouse to
-- click on.
function UI.needsCursor(): boolean
	return host ~= nil or UI.anyOpen() or next(cursorHolders) ~= nil
end

-- Hides the game's own screen (the HUD, menus, the dot) and the hotbar while something else
-- takes over the screen: the drive cutscene, or a dialogue. Each says why, so one ending doesn't
-- bring them back while the other's still up.
local hiders: { [string]: boolean } = {}
function UI.hideGame(reason: string, hidden: boolean)
	hiders[reason] = if hidden then true else nil
	local visible = next(hiders) == nil
	UI.getScreen().Enabled = visible
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible)
end

-- A story line (Config/Story.luau) for a RichText label: its `*highlights*` in the highlight
-- color, and anything RichText would read as a tag escaped.
function UI.highlight(text: string, color: Color3?): string
	local escaped = string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" })
	local hex = (color or UI.Colors.Money):ToHex()
	return (string.gsub(escaped, "%*(.-)%*", `<font color="#{hex}">%1</font>`))
end

-- Little messages pop up in a stack at the top of the screen. Toasts have a screen of their own,
-- above the shop computer's monitor (so its replies show) but under the drive cutscene.
local toastHolder: Frame = nil
local function toastStack(): Frame
	if not toastHolder then
		local toasts = UI.new("ScreenGui", {
			Name = "Toasts",
			ResetOnSpawn = false,
			DisplayOrder = 5,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		toastHolder = UI.new("Frame", {
			Name = "Toasts",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 60),
			Size = UDim2.new(1, -32, 0, 200),
			BackgroundTransparency = 1,
			Parent = toasts,
		}, { UI.list(6), UI.new("UISizeConstraint", { MaxSize = Vector2.new(420, 200) }) })
	end
	return toastHolder
end

-- Puts a toast of your own (a CanvasGroup, as wide as the stack) in the stack for `seconds`, then
-- fades it out: a new text in the Messages app, say.
function UI.toast(toast: CanvasGroup, seconds: number)
	toast.Parent = toastStack()
	task.delay(seconds, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.4), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		toast:Destroy()
	end)
end

function UI.notify(message: string)
	local toast = UI.label(message, {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = UI.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Parent = toastStack(),
	})
	UI.corner(8).Parent = toast

	task.delay(3.5, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

return UI
