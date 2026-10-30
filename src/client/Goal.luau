-- Your story goal right now (docs/STORY.md), for the Messages app's goal card and Grandma's sticky
-- note on the HUD: the act's goal from the server (StoryService), or in act 4 the Best Yard
-- contest's (ContestService): calling the judges, the jobs until they come round again, or the
-- results. The goals rail under the goal on the note has its milestones from here too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local Milestones = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Milestones"))

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

-- The number in Milestones.Stats that each kind of milestone counts.
local STAT = { Jobs = "jobs", Earned = "earned", Stars = "stars" }

local Goal = {}

-- The goal: { text, kind = "Money" | "CurbAppeal" | "Jobs", need, have? }, or one with a `button`
-- (and its `action`, "Start" or "Results") instead of a bar. Nil before the story's arrived.
function Goal.current()
	local story = ClientState.story
	local goal = story and story.goal
	local contest = ClientState.contest
	if not (goal and contest) or contest.state == "Locked" then
		return goal
	elseif contest.state == "Open" then
		return { text = `Beat Gloria's {contest.bar} on judging day`, button = "Call the judges", action = "Start" }
	elseif contest.state == "Results" then
		return { text = "The judges have been", button = "See the results", action = "Results" }
	end
	local length = math.max(1, contest.jobsWait or 1)
	return { text = "Best Yard comes round again", kind = "Jobs", need = length, have = length - contest.jobsLeft }
end

-- How far along a goal is: your money toward a price, your curb appeal, or the jobs done toward
-- the judges coming back, and that in words ("$66 / $150").
function Goal.progress(goal): (number, string)
	if goal.kind == "Jobs" then
		local left = goal.need - goal.have
		return goal.have, `{left} {if left == 1 then "job" else "jobs"} to go`
	elseif goal.kind == "Money" then
		local money = if ClientState.profile then ClientState.profile.money else 0
		return money, `{Format.money(money)} / {Format.money(goal.need)}`
	end
	local appeal = player:GetAttribute("CurbAppeal")
	local have = if typeof(appeal) == "number" then appeal else 0
	return have, `{have} / {goal.need}`
end

-- Your numbers for the goals rail, from the profile: jobs finished, money earned and three-star
-- jobs (the jobs you've got three stars on, whatever your best on the rest). Nil before the
-- profile arrives.
local function stats(): Milestones.Stats?
	local profile = ClientState.profile
	if not profile then
		return nil
	end
	local stars = 0
	for _, best in profile.stars or {} do
		if best == 3 then
			stars += 1
		end
	end
	return { jobs = profile.jobsCompleted or 0, earned = profile.earned or 0, stars = stars }
end

-- The `count` milestones nearest to done that you haven't reached, nearest first (the rail shows
-- two, the Next chip one): Milestones.next over the profile. Empty before the profile arrives.
function Goal.milestones(count: number): { Milestones.Milestone }
	local profile = ClientState.profile
	local mine = stats()
	if not (profile and mine) then
		return {}
	end
	return Milestones.next(mine, profile.milestones or {}, count)
end

-- How far along you are toward a milestone (or `have`, for a caller drawing it as done): the
-- number its kind counts, and that over the number it wants in words ("1/3", "$400/$500").
function Goal.milestoneProgress(milestone: Milestones.Milestone, have: number?): (number, string)
	local mine = stats()
	local now = have or (if mine then mine[STAT[milestone.kind]] else 0)
	if milestone.kind == "Earned" then
		return now, `{Format.money(now)}/{Format.money(milestone.at)}`
	end
	return now, `{now}/{milestone.at}`
end

return Goal
