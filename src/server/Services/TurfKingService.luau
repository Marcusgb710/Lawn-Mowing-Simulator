-- TurfKing, Gloria's slick lawn franchise and your business rival (docs/STORY.md, act 2). From
-- act 2:
--   * It takes jobs off your board. Now and then, a few seconds after you walk up to your shop's
--     computer, one of the job cards flips to "Taken by TurfKing" (JobService:TakeOffer) and you
--     can't accept it, and Chad texts you about it. At most once every few jobs, never the
--     starter job and never one someone's accepted (the rules are in Config/TurfKing.luau). Only
--     a crew's leader (or someone on their own) gets jobs taken: they're the one who accepts.
--   * Customers who wanted it perfect, and got a 90%+ finish, are won back: the first time for
--     each customer, they pay a bonus on top (a "Won from TurfKing" line in the pay breakdown)
--     and text "TurfKing scalped my lawn last month..." (the QualityWin beat in Story.luau, once
--     per customer).
-- Saved in the player's story: `flippedAt`, how many jobs they'd done at TurfKing's last take,
-- and `flips`, how many it's taken (so Chad's texts take turns).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)
local TurfKing = require(Shared.Config.TurfKing)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local PartyService = require(script.Parent.PartyService)
local StoryService = require(script.Parent.StoryService)
local WorldService = require(script.Parent.WorldService)

-- How often (seconds) to look at who's at their computer.
local CHECK_EVERY = 1

local TurfKingService = {}

local rng = Random.new()
-- [Player] = { rolled = whether this visit to the computer has had its chance, at = when the take
-- happens (os.clock), nil if it won't } while they're at the computer
local visits = {}

-- Whether TurfKing may take one of this player's jobs now.
local function canFlip(player: Player): boolean
	local data = DataService:Get(player)
	local story = StoryService:GetStory(player)
	if not (data and story) then
		return false
	end
	local party = PartyService:GetParty(player)
	if party and party.leader ~= player then
		return false
	end
	local flippedAt = if typeof(story.flippedAt) == "number" then story.flippedAt else nil
	return TurfKing.canFlip(story.act, data.jobsCompleted or 0, flippedAt)
end

-- Takes one of the jobs on this player's board, if there's one it can take.
local function flip(player: Player)
	local data = DataService:Get(player)
	local story = StoryService:GetStory(player)
	if not (data and story) or JobService:IsBusy(player) then
		return
	end
	local candidates = TurfKing.candidates(
		JobService:GetBoard(),
		JobService:GetTaken(player),
		JobService:GetAccepted(),
		DataService:GetLevel(player)
	)
	if #candidates == 0 then
		return
	end
	local offer = candidates[rng:NextInteger(1, #candidates)]
	if not JobService:TakeOffer(player, offer.id) then
		return
	end
	story.flippedAt = data.jobsCompleted or 0
	story.flips = (if typeof(story.flips) == "number" then story.flips else 0) + 1
	StoryService:SendText(player, "Chad", Story.turfKingText(story.flips, offer.customer))
	Net.event("Notify"):FireClient(player, `TurfKing took the job at {offer.address}.`)
end

local function check(player: Player)
	if not WorldService:IsAtComputer(player) then
		visits[player] = nil
		return
	end
	local visit = visits[player]
	if not visit then
		visit = { rolled = false, at = nil }
		visits[player] = visit
	end
	if not visit.rolled then
		visit.rolled = true
		if canFlip(player) and rng:NextNumber() < TurfKing.FlipChance then
			visit.at = os.clock() + rng:NextNumber(TurfKing.FlipDelay[1], TurfKing.FlipDelay[2])
		end
	elseif visit.at and os.clock() >= visit.at then
		visit.at = nil
		if canFlip(player) then
			flip(player)
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------------------

function TurfKingService:Init()
	-- The first time each Quality customer gets a 90%+ finish from someone in TurfKing's acts.
	-- It's the same check as the QualityWin beat, which then remembers them (once per customer).
	JobService:SetWinBackBonus(function(leader, info)
		local beat = Story.beat("QualityWin")
		local act = StoryService:GetAct(leader)
		if
			not beat
			or not TurfKing.winsBack(act, info.preference, info.quality)
			or StoryService:HasSeen(leader, Story.beatKey(beat, { customer = info.customer }))
		then
			return 0
		end
		return TurfKing.bonus(info.payout)
	end)
end

function TurfKingService:Start()
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)
	while true do
		task.wait(CHECK_EVERY)
		for _, player in Players:GetPlayers() do
			check(player)
		end
	end
end

return TurfKingService
