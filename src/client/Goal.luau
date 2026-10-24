-- Your story goal right now (docs/STORY.md), for the Messages app's goal card and Grandma's sticky
-- note on the HUD: the act's goal from the server (StoryService), or in act 4 the Best Yard
-- contest's (ContestService): calling the judges, the jobs until they come round again, or the
-- results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

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

return Goal
