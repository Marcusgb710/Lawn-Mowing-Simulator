-- The job board menu: lists open jobs and lets the crew leader accept one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local JobBoardController = {}

local status: TextLabel
local list: ScrollingFrame

local function isLeader(): boolean
	local party = ClientState.party
	return party == nil or party.leader == player
end

local function accept(offerId: string)
	local ok, message = Net.func("AcceptJob"):InvokeServer(offerId)
	UI.notify(message)
	if ok then
		UI.close("Jobs")
	end
end

local function render()
	UI.clearList(list)

	local level = if ClientState.profile then ClientState.profile.level else 1
	local leader = isLeader()
	if ClientState.job then
		status.Text = "You already have a job. Finish it first!"
	elseif not leader then
		status.Text = `Only your crew leader ({ClientState.party.leader.DisplayName}) can accept jobs.`
	else
		status.Text = "Pick a job, load the tools it needs, then hop in the truck."
	end

	for index, offer in ClientState.board do
		local locked = level < offer.minLevel
		local toolNames = {}
		for _, category in offer.tools do
			table.insert(toolNames, Items.CategoryInfo[category].toolName)
		end

		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 96),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })

		UI.label(`{offer.name}  ·  {offer.address}`, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -150, 0, 22),
			TextSize = 20,
			Parent = card,
		})
		UI.label(table.concat(offer.tasks, "  •  "), {
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -150, 0, 18),
			TextSize = 15,
			TextColor3 = UI.Colors.SubText,
			Parent = card,
		})
		UI.label(`Bring: {table.concat(toolNames, ", ")}`, {
			Position = UDim2.fromOffset(12, 52),
			Size = UDim2.new(1, -150, 0, 16),
			TextSize = 14,
			TextColor3 = UI.Colors.Accent,
			Parent = card,
		})
		local details = `Par time {Format.time(offer.parTime)}  ·  +{offer.xp} xp`
		UI.label(if locked then `Needs level {offer.minLevel}` else details, {
			Position = UDim2.fromOffset(12, 72),
			Size = UDim2.new(1, -150, 0, 16),
			TextSize = 14,
			TextColor3 = if locked then UI.Colors.Danger else UI.Colors.SubText,
			Parent = card,
		})
		UI.label(Format.money(offer.payout), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(120, 24),
			TextSize = 22,
			TextColor3 = UI.Colors.Money,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})

		local canAccept = leader and not locked and ClientState.job == nil
		UI.button(if locked then "Locked" else "Accept", function()
			if canAccept then
				accept(offer.id)
			end
		end, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -8),
			Size = UDim2.fromOffset(110, 32),
			BackgroundColor3 = if canAccept then UI.Colors.Accent else UI.Colors.Disabled,
			AutoButtonColor = canAccept,
			Parent = card,
		})
	end
end

function JobBoardController:Start()
	local window, content = UI.panel("Jobs", "Job Board")
	status = UI.label("", { TextColor3 = UI.Colors.SubText, Parent = content })
	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
	})

	ClientState.Changed:Connect(function(key)
		if key == "board" or key == "party" or key == "job" or key == "profile" then
			if window.Visible then
				render()
			end
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			render()
		end
	end)
end

return JobBoardController
