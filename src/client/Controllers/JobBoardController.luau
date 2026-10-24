-- The Jobs app on the shop computer: lists open jobs and lets the crew leader accept one.
-- Each job shows what the customer says and wants done, never which tools to use. From act 2,
-- TurfKing now and then takes a job off your board (TurfKingService): its card gets the "Taken by
-- TurfKing" stamp (landing with a thump if you're looking) and can't be accepted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local StoryArt = require(script.Parent.Parent.StoryArt)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

-- How long the stamp takes to land on a card TurfKing just took.
local STAMP_TIME = 0.35

local JobBoardController = {}

local status: TextLabel
local list: ScrollingFrame
-- [offer id] = true for the cards shown open (not taken) since the app was opened, so a card
-- that's taken while you watch gets its stamp landing.
local shownOpen: { [string]: boolean } = {}

-- The "Taken by TurfKing" stamp over a card: its image, or the words in gold on purple.
local function stamp(card: GuiObject, landing: boolean)
	local holder: GuiObject
	if StoryArt.StampTakenByTurfKing ~= "" then
		holder = UI.new("ImageLabel", {
			Image = StoryArt.StampTakenByTurfKing,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(254, 80),
			BackgroundTransparency = 1,
		})
	else
		holder = UI.heading("TAKEN BY TURFKING", {
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 22,
			TextColor3 = UI.Colors.Money,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.Colors.TurfKing,
		})
		UI.corner(8).Parent = holder
		UI.new("UIStroke", {
			Color = UI.Colors.Money,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = holder,
		})
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = holder })
	end
	holder.Name = "Taken"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Rotation = -8
	holder.ZIndex = 3
	holder.Parent = card
	if landing then
		local scale = UI.new("UIScale", { Scale = 1.8, Parent = holder })
		TweenService:Create(scale, TweenInfo.new(STAMP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
end

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
		local taken = offer.takenBy ~= nil

		local card = if taken
			then UI.sliced("Card_Locked", {
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = index,
				Parent = list,
			}, { color = UI.Colors.Card:Lerp(UI.Colors.TurfKing, 0.45), radius = 8 })
			else UI.card({
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = index,
				Parent = list,
			})

		-- Text down the left; pay and the button sit on the right.
		local text = UI.new("Frame", {
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.list(4), UI.padding(12) })
		local function line(content: string, props)
			props.Text = content
			props.Size = UDim2.fromScale(1, 0)
			props.AutomaticSize = Enum.AutomaticSize.Y
			props.TextWrapped = true
			props.Parent = text
			return UI.label(content, props)
		end

		-- The job and where, with the Jobs glyph (a clipboard) before it.
		local title = UI.new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = text,
		})
		local clipboard = UI.icon("Jobs", { Size = UDim2.fromOffset(24, 24), Parent = title })
		local titleX = if clipboard then 32 else 0
		UI.heading(`{offer.name}  ·  {offer.address}`, {
			Position = UDim2.fromOffset(titleX, 0),
			Size = UDim2.new(1, -titleX, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 21,
			Parent = title,
		})
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
			FontFace = UI.Fonts.Body,
			LayoutOrder = 2,
		})
		line(table.concat(offer.todo, "  •  "), {
			TextSize = 14,
			FontFace = UI.Fonts.Medium,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 3,
		})
		local details = `{offer.tier} job  ·  Par time {Format.time(offer.parTime)}  ·  +{offer.xp} xp`
		line(if locked then `Needs level {offer.minLevel}` else details, {
			TextSize = 14,
			TextColor3 = if locked then UI.Colors.Danger else UI.Colors.SubText,
			LayoutOrder = 4,
		})

		UI.display(
			"Numbers",
			Format.money(offer.payout),
			{ TextSize = 40, Color = UI.Colors.Money, XAlignment = "Right", Fit = true },
			{
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 8),
				Size = UDim2.fromOffset(126, 40),
				Parent = card,
			}
		)

		local canAccept = leader and not locked and not taken and ClientState.job == nil
		UI.button(if taken then "Taken" elseif locked then "Locked" else "Take job", function()
			if canAccept then
				accept(offer.id)
			end
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 54),
			Size = UDim2.fromOffset(126, 40),
			Style = if canAccept then "Primary" else "Disabled",
			Icon = if locked and not taken then "Lock" else nil,
			IconSize = 16,
			AutoButtonColor = canAccept,
			Parent = card,
		})
		-- The card's at least as tall as the pay and the button.
		UI.new("Frame", { Size = UDim2.fromOffset(1, 106), BackgroundTransparency = 1, Parent = card })
		if taken then
			stamp(card, shownOpen[offer.id] == true)
			shownOpen[offer.id] = nil
		else
			shownOpen[offer.id] = true
		end
	end
end

function JobBoardController:Start()
	local window, content = UI.panel("Jobs", "Jobs")
	status = UI.label("", { FontFace = UI.Fonts.Medium, TextColor3 = UI.Colors.SubText, Parent = content })
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
		table.clear(shownOpen)
		if window.Visible then
			render()
		end
	end)
end

return JobBoardController
