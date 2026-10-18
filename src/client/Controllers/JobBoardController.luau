-- The job board menu: lists open jobs and lets the crew leader accept one.
-- Each job shows what the customer says and wants done, never which tools to use.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
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
		status.Text = "Read what the customer wants, load the right tools, then hop in the truck."
	end

	for index, offer in ClientState.board do
		local locked = level < offer.minLevel

		local card = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(8) })

		-- Text down the left; pay and the button sit on the right.
		local text = UI.new("Frame", {
			Size = UDim2.new(1, -140, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(4), UI.padding(10) })
		local function line(content: string, props)
			props.Text = content
			props.Size = UDim2.fromScale(1, 0)
			props.AutomaticSize = Enum.AutomaticSize.Y
			props.TextWrapped = true
			props.Parent = text
			return UI.label(content, props)
		end

		line(`{offer.name}  ·  {offer.address}`, { TextSize = 20, LayoutOrder = 1 })
		-- Point brand-new players at the job their free gear can do.
		local newPlayer = ClientState.profile and ClientState.profile.jobsCompleted == 0
		if newPlayer and offer.kind == "StarterGear" then
			line("Good first job: you already have what it takes.", {
				TextSize = 15,
				TextColor3 = UI.Colors.Money,
				LayoutOrder = 0,
			})
		end
		line(`"{offer.story}"  - {offer.customer}`, {
			TextSize = 15,
			TextColor3 = UI.Colors.Text,
			Font = Enum.Font.Gotham,
			LayoutOrder = 2,
		})
		line(table.concat(offer.todo, "  •  "), {
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 3,
		})
		local details = `{offer.tier} job  ·  Par time {Format.time(offer.parTime)}  ·  +{offer.xp} xp`
		line(if locked then `Needs level {offer.minLevel}` else details, {
			TextSize = 14,
			TextColor3 = if locked then UI.Colors.Danger else UI.Colors.SubText,
			LayoutOrder = 4,
		})

		UI.label(Format.money(offer.payout), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 8),
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
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 40),
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
