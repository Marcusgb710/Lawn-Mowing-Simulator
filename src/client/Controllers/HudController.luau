-- Always-on screen stuff: money and level, menu buttons, and the job tracker (tasks, timer, damage).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local HudController = {}

local moneyLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame

local tracker: Frame
local trackerTitle: TextLabel
local trackerHint: TextLabel
local timerLabel: TextLabel
local taskList: Frame
local trackerButton: TextButton
local taskRows = {}
local shownJobId = nil

local function buildStats()
	local frame = UI.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(220, 84),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.2,
		Parent = UI.getScreen(),
	}, { UI.corner(10), UI.padding(10) })

	moneyLabel = UI.label("$0", {
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 28,
		TextColor3 = UI.Colors.Money,
		Parent = frame,
	})
	levelLabel = UI.label("Level 1", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 16,
		TextColor3 = UI.Colors.SubText,
		Parent = frame,
	})
	local xpBar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = UI.Colors.Card,
		Parent = frame,
	}, { UI.corner(4) })
	xpFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Accent,
		Parent = xpBar,
	}, { UI.corner(4) })
end

local function buildMenuButtons()
	local frame = UI.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(110, 220),
		BackgroundTransparency = 1,
		Parent = UI.getScreen(),
	}, { UI.list(8) })

	for index, name in { "Jobs", "Truck", "Shop", "Guide", "Crew" } do
		UI.button(name, function()
			UI.toggle(name)
		end, { LayoutOrder = index, Parent = frame })
	end
end

local function buildTracker()
	tracker = UI.new("Frame", {
		Name = "JobTracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = UI.getScreen(),
	}, { UI.corner(10), UI.padding(10), UI.list(6) })

	trackerTitle = UI.label("", { TextSize = 22, LayoutOrder = 1, Parent = tracker })
	trackerHint = UI.label("", {
		TextSize = 15,
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = tracker,
	})
	timerLabel = UI.label("", {
		TextSize = 16,
		TextColor3 = UI.Colors.Money,
		LayoutOrder = 3,
		Visible = false,
		Parent = tracker,
	})
	taskList = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = tracker,
	}, { UI.list(6) })
	trackerButton = UI.button("", function()
		Net.event("AbandonJob"):FireServer()
	end, {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = UI.Colors.Danger,
		LayoutOrder = 5,
		Parent = tracker,
	})
end

-- "Time 0:42 / par 1:30   Damage -$20"
local function updateTimer()
	local job = ClientState.job
	if not (job and job.state == "Working" and job.startedAt) then
		timerLabel.Visible = false
		return
	end
	local elapsed = workspace:GetServerTimeNow() - job.startedAt
	local text = `Time {Format.time(elapsed)} / par {Format.time(job.parTime)}`
	if job.penalty > 0 then
		text ..= `   Damage -{Format.money(job.penalty)}`
	end
	timerLabel.Text = text
	timerLabel.TextColor3 = if elapsed <= job.parTime then UI.Colors.Money else UI.Colors.Danger
	timerLabel.Visible = true
end

local WANTED = {
	Quality = "a perfect finish",
	Speed = "it done fast",
	Balanced = "a good job in good time",
}

local function multiplier(value: number): string
	return "x" .. string.format("%.2f", value)
end

local function resultText(result): string
	local lines = {
		`Job pay {Format.money(result.basePay)} in {Format.time(result.time)}`,
		`The customer wanted {WANTED[result.preference] or WANTED.Balanced}`,
		`Finish {Format.percent(result.quality)} ({multiplier(result.qualityMultiplier)})`
			.. `  ·  Speed {multiplier(result.speedMultiplier)}`,
	}
	if result.toolFit < 0.995 then
		-- Says the tools weren't the best for the job, but never which ones would have been.
		table.insert(lines, `Right tools for the job: {Format.percent(result.toolFit)}`)
	end
	local bonus = result.crewBonus * result.truckBonus * result.businessBonus
	if bonus > 1 then
		table.insert(lines, `Crew/truck/business x{string.format("%.2f", bonus)}`)
	end
	if result.penalty > 0 then
		table.insert(lines, `Damage -{Format.money(result.penalty)}`)
	end
	table.insert(lines, `You earned {Format.money(result.share)}! Heading back soon...`)
	return table.concat(lines, "\n")
end

local function getTaskRow(taskName: string, order: number)
	local row = taskRows[taskName]
	if row then
		return row
	end

	local frame = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = taskList,
	})
	local label = UI.label("", { Size = UDim2.new(1, 0, 0, 18), TextSize = 15, Parent = frame })
	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = UI.Colors.Card,
		Parent = frame,
	}, { UI.corner(6) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Accent,
		Parent = bar,
	}, { UI.corner(6) })

	row = { frame = frame, label = label, fill = fill }
	taskRows[taskName] = row
	return row
end

local function clearTaskRows()
	for _, row in taskRows do
		row.frame:Destroy()
	end
	table.clear(taskRows)
end

local function updateProfile()
	local profile = ClientState.profile
	if not profile then
		return
	end
	moneyLabel.Text = Format.money(profile.money)
	levelLabel.Text = `Level {profile.level}  ·  {profile.jobsCompleted} jobs done`
	local from = GameConfig.xpForLevel(profile.level)
	local to = GameConfig.xpForLevel(profile.level + 1)
	xpFill.Size = UDim2.fromScale(math.clamp((profile.xp - from) / (to - from), 0, 1), 1)
end

local function updateJob()
	local job = ClientState.job
	if not job then
		tracker.Visible = false
		clearTaskRows()
		return
	end

	if job.id ~= shownJobId then
		shownJobId = job.id
		clearTaskRows()
	end
	tracker.Visible = true
	trackerTitle.Text = job.name
	local isLeader = job.leader == player
	trackerButton.Visible = true

	if job.state == "Ready" then
		trackerHint.Text = if isLeader
			then `{job.address} · {Format.money(job.payout)}\nLoad the tools you think you'll need, then hop in!`
			else `{job.address} · {Format.money(job.payout)}\nWaiting for {job.leader.DisplayName} to start the truck.`
		trackerButton.Text = "Cancel job"
		trackerButton.Visible = isLeader
	elseif job.state == "Traveling" then
		trackerHint.Text = `Driving to {job.address}...`
		trackerButton.Visible = false
	elseif job.state == "Working" then
		trackerHint.Text = if job.story then `"{job.story}"  - {job.customer}` else "Don't hit the flowers or gnomes!"
		trackerButton.Text = if isLeader then "Call off job" else "Leave job"
	elseif job.state == "Complete" then
		trackerHint.Text = if job.result then resultText(job.result) else "Job done!"
		trackerButton.Visible = false
	end
	updateTimer()

	if not job.tasks then
		clearTaskRows()
		return
	end
	for order, info in job.tasks do
		local row = getTaskRow(info.task, order)
		row.label.Text = `{info.label}  {info.done}/{info.needed}`
		local fraction = if info.needed > 0 then info.done / info.needed else 1
		row.fill.Size = UDim2.fromScale(fraction, 1)
		row.fill.BackgroundColor3 = if fraction >= 1 then UI.Colors.Money else UI.Colors.Accent
	end
end

function HudController:Start()
	buildStats()
	buildMenuButtons()
	buildTracker()

	ClientState.Changed:Connect(function(key)
		if key == "profile" then
			updateProfile()
		elseif key == "job" then
			updateJob()
		end
	end)

	-- Any ProximityPrompt with an OpensPanel attribute opens that menu (job board, shop...).
	task.spawn(function()
		while true do
			task.wait(0.25)
			updateTimer()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("OpensPanel")
		if typeof(panel) == "string" then
			UI.open(panel)
		end
	end)
end

return HudController
