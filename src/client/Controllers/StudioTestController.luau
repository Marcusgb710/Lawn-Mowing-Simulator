-- A panel of shortcuts for testing the story in a Studio playtest (StudioTestService does them):
-- jump to an act, replay the intro, start over, get money, tidy your lawn, open judging day.
-- Press K to show or hide it; the mouse is freed while it's up. It's never built outside Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local TOGGLE_KEY = Enum.KeyCode.K
-- The panel's width (UiLayout.luau), which its buttons are laid out for.
local WIDTH = (UI.layout("StudioTestPanel").size :: UDim2).X.Offset

local StudioTestController = {}

local panel: Frame = nil
local status: TextLabel = nil
local actLabel: TextLabel = nil
local busy = false

local function setStatus(text: string, ok: boolean)
	status.Text = text
	status.TextColor3 = if ok then UI.Colors.SubText else UI.Colors.Danger
end

-- Asks the server to run a test, one at a time.
local function run(test: string, value: any?)
	if busy then
		return
	end
	busy = true
	setStatus("…", true)
	local called, ok, message = pcall(function()
		return Net.func("StudioTest"):InvokeServer(test, value)
	end)
	busy = false
	if not called then
		setStatus("Couldn't reach the server.", false)
	else
		setStatus(message or (if ok then "Done." else "Didn't work."), ok == true)
	end
end

local function show(visible: boolean)
	panel.Visible = visible
	UI.holdCursor("StudioTest", visible)
end

local function heading(text: string, order: number)
	return UI.label(text, {
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = UI.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
end

local function wideButton(text: string, order: number, onClick: () -> ())
	return UI.button(text, onClick, {
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 16,
		BackgroundColor3 = UI.Colors.Card,
		LayoutOrder = order,
	})
end

local function build()
	local screen = UI.new("ScreenGui", {
		Name = "StudioTest",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	-- A small hint in the corner, so it's clear the panel's there.
	local hint = UI.label("Studio test panel: K", {
		TextSize = 13,
		TextColor3 = UI.Colors.SubText,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = screen,
	})
	UI.place(hint, "StudioTestHint")

	panel = UI.new("Frame", {
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(10), UI.padding(10), UI.list(6) })
	UI.place(panel, "StudioTestPanel")

	UI.label("Studio test", {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = panel,
	})
	actLabel = heading("Act", 2)
	actLabel.Parent = panel

	local acts = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = panel,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	local actWidth = math.floor((WIDTH - 20 - 6 * (#Story.Acts - 1)) / #Story.Acts)
	for act in Story.Acts do
		UI.button(tostring(act), function()
			run("Act", act)
		end, {
			Size = UDim2.fromOffset(actWidth, 34),
			LayoutOrder = act,
			Parent = acts,
		})
	end

	heading("Story", 4).Parent = panel
	wideButton("Replay the intro", 5, function()
		run("Intro")
	end).Parent = panel
	wideButton("Start the story over", 6, function()
		run("Restart")
	end).Parent = panel

	heading("Shortcuts", 7).Parent = panel
	local money = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 8,
		Parent = panel,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	for index, amount in { 1000, 10000 } do
		UI.button(if amount >= 10000 then "+$10,000" else "+$1,000", function()
			run("Money", amount)
		end, {
			Size = UDim2.fromOffset(math.floor((WIDTH - 26) / 2), 34),
			BackgroundColor3 = UI.Colors.Money,
			TextColor3 = UI.Colors.Background,
			LayoutOrder = index,
			Parent = money,
		})
	end
	wideButton("Tidy my lawn", 9, function()
		run("Tidy")
	end).Parent = panel
	wideButton("Open judging day", 10, function()
		run("Judging")
	end).Parent = panel

	status = UI.label("", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 11,
		Parent = panel,
	})
	setStatus("Jumping back an act: the story moves on again as soon as your progress passes its gate.", true)
end

-- The act the player's in, from the story the server sent.
local function showAct()
	local story = ClientState.story
	actLabel.Text = if story then `Act: {story.act} ({story.actName})` else "Act"
end

function StudioTestController:Start()
	if not RunService:IsStudio() then
		return
	end
	build()
	showAct()
	ClientState.Changed:Connect(function(key)
		if key == "story" then
			showAct()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == TOGGLE_KEY then
			show(not panel.Visible)
		end
	end)
end

return StudioTestController
