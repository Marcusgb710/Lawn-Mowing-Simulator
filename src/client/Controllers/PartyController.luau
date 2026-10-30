-- The crew menu (invite, kick, leave) and the popup when someone invites you.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local PartyController = {}

local list: ScrollingFrame
local window: Frame

local function row(text: string, order: number, buttonText: string?, buttonColor: Color3?, onClick: (() -> ())?)
	local frame = UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 44),
		BackgroundColor3 = UI.Colors.Card,
		LayoutOrder = order,
		Parent = list,
	}, { UI.corner(8) })
	UI.label(text, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -140, 1, 0),
		Parent = frame,
	})
	if buttonText and onClick then
		UI.button(buttonText, onClick, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(110, 32),
			BackgroundColor3 = buttonColor or UI.Colors.Accent,
			Parent = frame,
		})
	end
end

local function header(text: string, order: number)
	UI.label(text, {
		TextColor3 = UI.Colors.SubText,
		LayoutOrder = order,
		Parent = list,
	})
end

local function render()
	UI.clearList(list)
	local party = ClientState.party or { leader = player, members = { player } }
	local isLeader = party.leader == player
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	header(`Your crew ({#party.members}/{GameConfig.MaxCrewSize})`, nextOrder())
	for _, member in party.members do
		local name = member.DisplayName .. (if member == party.leader then "  (leader)" else "")
		if isLeader and member ~= player then
			row(name, nextOrder(), "Kick", UI.Colors.Danger, function()
				local _, message = Net.func("KickFromParty"):InvokeServer(member)
				UI.notify(message)
			end)
		else
			row(name, nextOrder())
		end
	end

	if #party.members > 1 then
		row("Leave this crew", nextOrder(), "Leave", UI.Colors.Danger, function()
			Net.event("LeaveParty"):FireServer()
		end)
	end

	if not isLeader then
		return
	end
	header("Invite players", nextOrder())
	local anyone = false
	for _, other in Players:GetPlayers() do
		if not table.find(party.members, other) then
			anyone = true
			row(other.DisplayName, nextOrder(), "Invite", UI.Colors.Accent, function()
				local _, message = Net.func("InviteToParty"):InvokeServer(other)
				UI.notify(message)
			end)
		end
	end
	if not anyone then
		row("Nobody else is here yet.", nextOrder())
	end
end

-- [inviter] = their invite popup on screen
local invitePopups = {}

local function showInvite(from: Player, timeout: number)
	local earlier = invitePopups[from]
	if earlier then
		earlier:Destroy()
	end
	local popup = UI.new("Frame", {
		Name = "Invite",
		BackgroundColor3 = UI.Colors.Background,
		Parent = UI.getScreen(),
	}, { UI.corner(10), UI.padding(10) })
	UI.keepPlaced(popup, "CrewInvite")
	-- At the top of the screen (on a touch screen), the toasts keep below it.
	UI.keepToastsBelow(popup)
	invitePopups[from] = popup
	popup.Destroying:Connect(function()
		if invitePopups[from] == popup then
			invitePopups[from] = nil
		end
	end)

	-- The popup doesn't free the mouse by itself (you might be in the middle of mowing), so on a
	-- keyboard it says how.
	local text = `{from.DisplayName} invited you to their crew!`
	if UserInputService.KeyboardEnabled then
		text ..= "  (hold Alt to click)"
	end
	-- Smaller for a long name, so it stays on its line over the buttons.
	local label = UI.label(text, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextScaled = true,
		Parent = popup,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = label })

	local function respond(accept: boolean)
		popup:Destroy()
		local _, message = Net.func("RespondToInvite"):InvokeServer(from, accept)
		if message then
			UI.notify(message)
		end
	end
	Juicy.juice(UI.button("Join", function()
		respond(true)
	end, { Position = UDim2.new(0.5, -115, 0, 32), Parent = popup }))
	Juicy.juice(UI.button("No thanks", function()
		respond(false)
	end, { Position = UDim2.new(0.5, 5, 0, 32), BackgroundColor3 = UI.Colors.Danger, Parent = popup }))

	task.delay(timeout, function()
		if popup.Parent then
			popup:Destroy()
		end
	end)
end

function PartyController:Start()
	local content
	window, content = UI.panel("Crew", "Your Crew")
	list = UI.scrollingList(content)

	ClientState.Changed:Connect(function(key)
		if key == "party" and window.Visible then
			render()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if window.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if window.Visible then
			task.defer(render)
		end
	end)

	Net.event("PartyInvite").OnClientEvent:Connect(showInvite)
end

return PartyController
