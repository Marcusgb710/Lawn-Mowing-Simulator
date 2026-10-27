-- Coaches a brand-new player through their first job, one step at a time, then goes away for
-- good: the grass shears they start with, and picking up the junk hidden in the grass. Past the
-- shears it never says which tool to use, only where to look (the Guide).
-- It takes over from the story's intro (DialogueController): Grandma June hands you her shears
-- and sends you to Edna's front lawn, and the coach waits until she's done talking.

local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local DialogueController = require(script.Parent.DialogueController)

local TutorialController = {}

local banner: TextLabel

-- What to tell a player who hasn't finished a job yet, given where they are. A phone's is shorter,
-- so it fits at the top of a small screen between the HUD's columns, over the dot.
local function step(job): string
	local touch = UI.isTouch() and not UserInputService.KeyboardEnabled
	if not job then
		if touch then
			return "Edna's front lawn is your first job, with Grandma's grass shears from the truck. Look at "
				.. "the computer in your shop, tap the button, then take the Front Lawn job in Jobs."
		end
		return "Edna's front lawn is your first job. You're starting from the bottom: Grandma's grass "
			.. "shears, already in the truck. Look at the computer in your shop and press E (or tap the "
			.. "button), then take the Front Lawn job in Jobs."
	elseif job.state == "Ready" then
		if touch then
			return "Read what the customer wants (Guide says what each tool is for). Take a tool from "
				.. "storage, put it in the truck bed, then look at the driver door and get in."
		end
		return "Read what the customer wants. Not sure what a tool is for? Tap Guide. Look at a tool in "
			.. "storage and press E (or tap the button) to take it, put it in the truck bed, then look "
			.. "at the truck's driver door and get in."
	elseif job.state == "Traveling" then
		return "On the way to the customer's house..."
	elseif job.state == "Working" then
		if touch then
			return "Aim the dot at the grass and tap Snip, or hold it to keep snipping. Junk hides in the "
				.. "grass: look at it and tap the button to pick it up first. Stay off the flowers!"
		end
		return "Shears cut a snip at a time: aim the dot at the grass and click (or tap Snip), or hold "
			.. "it to keep snipping. Long grass takes a few snips. Sticks, toys and rocks hide in the "
			.. "grass: look at one and press E (or tap the button) to pick it up before you cut there. "
			.. "Stay off the flowers!"
	end
	return "Nice work, you got paid! A couple more jobs like that buys a push mower in Orders, on the "
		.. "shop computer, and cheap hand tools open up garden jobs."
end

local function update()
	local profile = ClientState.profile
	local job = ClientState.job
	-- Stay up through the payout of the first job, then never again.
	local firstJob = profile
		and (profile.jobsCompleted == 0 or (profile.jobsCompleted == 1 and job ~= nil and job.state == "Complete"))
	-- Not until the intro's over: June has the first word. Where it gives way to something that
	-- takes its spot (a crew invite, on a touch screen), it waits for that to go.
	banner.Visible = firstJob == true
		and not DialogueController.isPending("Intro")
		and not UI.givesWay("TutorialBanner")
	if firstJob then
		banner.Text = step(job)
	end
end

function TutorialController:Start()
	banner = UI.label("", {
		Name = "Coach",
		BackgroundTransparency = 0.15,
		BackgroundColor3 = UI.Colors.Background,
		TextColor3 = UI.Colors.Money,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = 16,
		Visible = false,
		Parent = UI.getScreen(),
	})
	UI.keepPlaced(banner, "TutorialBanner")
	UI.corner(10).Parent = banner
	UI.padding(10).Parent = banner
	UI.keepToastsBelow(banner)

	ClientState.Changed:Connect(function(key)
		if key == "profile" or key == "job" or key == "story" then
			update()
		end
	end)
	DialogueController.Closed:Connect(update)
	UI.onGiveWay("TutorialBanner", update)
	update()
end

return TutorialController
