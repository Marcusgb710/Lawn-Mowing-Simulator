-- Shortcuts for testing the story in a Studio playtest (StudioTestController's panel; press K):
-- jump to an act, replay the intro, start the story over, get some money, tidy your own lawn, and
-- open Best Yard judging day without the wait. The server only runs them in Studio, so in a live
-- game the remote does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contest = require(Shared.Config.Contest)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local ContestService = require(script.Parent.ContestService)
local DataService = require(script.Parent.DataService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local StoryService = require(script.Parent.StoryService)

-- The amounts of money the panel can give.
local MONEY = { [1000] = true, [10000] = true }

local StudioTestService = {}

-- Each test: (player, value) -> (whether it worked, what to tell them).
local TESTS = {
	Act = function(player: Player, act)
		if typeof(act) ~= "number" or not Story.Acts[act] then
			return false, "No such act."
		end
		if not StoryService:JumpToAct(player, act) then
			return false, "Your story isn't loaded yet."
		end
		return true, `Act {act}: {Story.Acts[act].name}.`
	end,
	Intro = function(player: Player)
		StoryService:PlayScene(player, "Intro")
		return true, "Playing the intro."
	end,
	Restart = function(player: Player)
		if not StoryService:RestartStory(player) then
			return false, "Your story isn't loaded yet."
		end
		ContestService:OpenForTesting(player, true)
		return true, "Story started over."
	end,
	Money = function(player: Player, amount)
		if not MONEY[amount] then
			return false, "Not that much."
		end
		DataService:AddMoney(player, amount)
		return true, `+{Format.money(amount)}.`
	end,
	Tidy = function(player: Player)
		if not HomeLawnService:TidyForTesting(player) then
			return false, "Your lawn isn't built yet."
		end
		return true, "Your lawn is all done."
	end,
	Judging = function(player: Player)
		if StoryService:GetAct(player) < Contest.FromAct then
			return false, `Judging day is in act {Contest.FromAct}.`
		end
		ContestService:OpenForTesting(player)
		return true, "Judging day is open: call the judges from Messages."
	end,
}

function StudioTestService:Init()
	Net.func("StudioTest").OnServerInvoke = function(player, test, value)
		if not RunService:IsStudio() then
			return false, "Only in Studio."
		end
		local run = typeof(test) == "string" and TESTS[test]
		if not run then
			return false, "No such test."
		end
		return run(player, value)
	end
end

return StudioTestService
