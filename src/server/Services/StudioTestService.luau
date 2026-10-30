-- Shortcuts for testing the story in a Studio playtest (StudioTestController's panel; press K):
-- jump to an act, replay the intro, start the story over, start as a first-timer again, get some
-- money, set your level, tidy your own lawn, and open Best Yard judging day without the wait. The
-- server only runs them in Studio, so in a live game the remote does nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contest = require(Shared.Config.Contest)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local ContestService = require(script.Parent.ContestService)
local DataService = require(script.Parent.DataService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local StoryService = require(script.Parent.StoryService)

-- The amounts of money the panel can give.
local MONEY = { [1000] = true, [10000] = true }
-- The highest level the Level shortcut sets.
local MAX_LEVEL = 40
-- How long FirstTimer waits for a job to be called off (the truck ride home) before it gives up.
local CALL_OFF_WAIT = GameConfig.TravelTime + 5

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
	-- Their save goes back to a brand-new one and they start on the first lawn with the shears, as
	-- a new player does (JobService:StartFirstJob). Restart's reset isn't enough: it only clears
	-- the story, and queues the intro that now plays after the first payday. A job they're on is
	-- called off first, and the ride home is waited out, because StartFirstJob won't take
	-- someone who's busy.
	FirstTimer = function(player: Player)
		if not DataService:Get(player) then
			return false, "Your save isn't loaded yet."
		end
		local party = PartyService:GetParty(player)
		if party and #party.members > 1 then
			return false, "Leave your crew first."
		end
		JobService:Abandon(player)
		local giveUp = os.clock() + CALL_OFF_WAIT
		while JobService:IsBusy(player) and player.Parent == Players and os.clock() < giveUp do
			task.wait(0.2)
		end
		if JobService:IsBusy(player) then
			return false, "Your job is still being called off. Try again in a moment."
		end
		if not DataService:ResetForStudio(player) then
			return false, "Couldn't reset your save."
		end
		-- What the level rewards set on them goes with the save.
		player:SetAttribute("GoldSign", nil)
		-- The story's reset with the save; sending it no texts tells their screen (no scene is
		-- queued, so the intro waits for the first payday).
		StoryService:SendTexts(player, {})
		-- And the contest view they had (act 4's judging) goes back to Locked, so the goals rail
		-- shows act 1's goal.
		ContestService:OpenForTesting(player, true)
		JobService:StartFirstJob(player)
		local job = JobService:GetJob(player)
		if not (job and job.firstTimer) then
			return false, "The first job didn't start, so you're at your business."
		end
		return true, "You're a first-timer again: on the strip with the shears."
	end,
	-- Sets their XP to a level's, so its reward and the Levels panel can be seen. Going up pays
	-- every level in between that isn't claimed (SeasonService, on LeveledUp), the way a job does.
	Level = function(player: Player, level)
		if typeof(level) ~= "number" or level % 1 ~= 0 or level < 1 or level > MAX_LEVEL then
			return false, `Levels 1 to {MAX_LEVEL}.`
		end
		local data = DataService:Get(player)
		if not data then
			return false, "Your save isn't loaded yet."
		end
		local before = GameConfig.levelFromXp(data.xp)
		data.xp = GameConfig.xpForLevel(level)
		DataService:Changed(player)
		if level > before then
			DataService.LeveledUp:Fire(player, level)
			return true, `Level {level}.`
		end
		return true, `Level {level}, nothing new to claim.`
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
