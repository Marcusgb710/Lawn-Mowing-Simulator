-- Coaches a brand-new player through their first job, one step at a time, then goes away for
-- good. It never says which tool to use, only where to look (the Guide).

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local TutorialController = {}

local banner: TextLabel

-- What to tell a player who hasn't finished a job yet, given where they are.
local function step(job): string
	if not job then
		return "Welcome to your lawn care business! Look at the computer in your shop and press E (or "
			.. "tap the button), then take the first job in Jobs. Your reel mower is already in the truck."
	elseif job.state == "Ready" then
		return "Read what the customer wants. Not sure what a tool is for? Tap Guide. Look at a tool in "
			.. "storage and press E (or tap the button) to take it, put it in the truck bed, then look "
			.. "at the truck's driver door and get in."
	elseif job.state == "Traveling" then
		return "On the way to the customer's house..."
	elseif job.state == "Working" then
		return "Work through the to-do list. Mowers cut while you hold them and walk; other tools "
			.. "work while you hold the button. Stay off the flowers and gnomes!"
	end
	return "Nice work, you got paid! Spend it in Orders, on the shop computer: cheap hand tools open up garden jobs."
end

local function update()
	local profile = ClientState.profile
	local job = ClientState.job
	-- Stay up through the payout of the first job, then never again.
	local firstJob = profile
		and (profile.jobsCompleted == 0 or (profile.jobsCompleted == 1 and job ~= nil and job.state == "Complete"))
	banner.Visible = firstJob == true
	if firstJob then
		banner.Text = step(job)
	end
end

function TutorialController:Start()
	banner = UI.label("", {
		Name = "Coach",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromScale(0.6, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = UI.Colors.Background,
		TextColor3 = UI.Colors.Money,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = 16,
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.corner(10).Parent = banner
	UI.padding(10).Parent = banner
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge), Parent = banner })

	ClientState.Changed:Connect(function(key)
		if key == "profile" or key == "job" then
			update()
		end
	end)
	update()
end

return TutorialController
