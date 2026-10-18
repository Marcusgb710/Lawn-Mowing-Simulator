-- The job board, and a crew's trip through a job:
--   Ready      the leader accepted a job; the crew loads the tools it needs and hops in the truck
--   Traveling  truck cutscene on the way there
--   Working    the crew is at the house doing yard work (the clock is running)
--   Complete   everyone got paid, the truck heads back to the business in a few seconds
--
-- Nothing here tells players which tools to bring: offers carry the customer's story and to-do
-- list, and a tool that can't do a task just gets "That won't work here".
--
-- Pay (GameConfig.jobPay) = job pay x how well the tools fit the tasks x a blend of finish
-- quality and speed (weighted by what the customer wants) x crew/truck/business bonuses, minus
-- damage for every flower patch or gnome the crew ran over. Then it's split evenly.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Jobs = require(Shared.Config.Jobs)
local Net = require(Shared.Net)
local TaskTypes = require(Shared.Config.TaskTypes)
local Tools = require(Shared.Config.Tools)
local Signal = require(Shared.Signal)

local DataService = require(script.Parent.DataService)
local LawnService = require(script.Parent.LawnService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

local JobService = {}
-- Fired with (player) when they head out on a job, arrive at the house, or leave the job.
JobService.PlayerStateChanged = Signal.new()

local rng = Random.new()
local board = {}
local nextOfferId = 0
local sitesFolder: Folder

-- [party] = job that's been accepted but the crew hasn't driven to yet
local readyJobs = {}
-- [job] = true for jobs whose crew has left the business
local activeJobs = {}
-- [Player] = the job they're on
local playerJobs = {}
-- [Player] = token for the trip they're on, so overlapping trips don't trip over each other
local traveling = {}
local usedSlots = {}
-- [Player] = when they were last told their tool won't work, so it isn't spammed
local wrongToolWarnings = {}
-- What happens to bare hands on work that needs gloves (never says which gloves).
local HURT_MESSAGES = {
	Thorns = "Ouch! Those thorns shred your bare hands.",
	Chemicals = "You can't handle weed killer with your bare hands.",
}

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

-- The hazards the gloves a player brought protect them from. Gloves in the truck get worn.
local function protectionsOf(player: Player): { [string]: boolean }
	local data = DataService:Get(player)
	local protections = {}
	if data then
		for toolId in data.loadout do
			local tool = Tools.get(toolId)
			for _, hazard in if tool and tool.protects then tool.protects else {} do
				protections[hazard] = true
			end
		end
	end
	return protections
end

-- Job board ----------------------------------------------------------------------------------

local function highestLevel(): number
	local best = 1
	for _, player in Players:GetPlayers() do
		best = math.max(best, DataService:GetLevel(player))
	end
	return best
end

-- True if a brand-new player's free gear can finish every task in the job (gloves included).
local function doableWithStarterGear(template): boolean
	local protected = {}
	for _, tool in Tools.List do
		if tool.available and tool.price == 0 then
			for _, hazard in tool.protects or {} do
				protected[hazard] = true
			end
		end
	end
	for _, task in template.tasks do
		local needs = TaskTypes.get(task.type).protection
		if needs and not protected[needs] then
			return false
		end
		local doable = false
		for _, tool in Tools.List do
			if tool.available and tool.price == 0 and TaskTypes.fit(task.type, tool.id) then
				doable = true
				break
			end
		end
		if not doable then
			return false
		end
	end
	return true
end

-- What kind of job a board slot shows:
--   "StarterGear"  a job new players can finish with the gear they start with (always one)
--   "Homeowner"    small yard and garden housework, up to the best player's level
--   "Open"         anything up to a little above the best player's level
local function poolFor(kind: string)
	local maxLevel = if kind == "StarterGear" then 1 else highestLevel() + (if kind == "Open" then 2 else 0)
	local pool = {}
	for _, template in Jobs.Templates do
		local fits = if kind == "StarterGear"
			then doableWithStarterGear(template)
			elseif kind == "Homeowner" then template.tier == "Homeowner"
			else true
		if template.minLevel <= maxLevel and fits then
			table.insert(pool, template)
		end
	end
	if #pool > 0 then
		return pool
	end
	-- Config can't be allowed to leave the board empty.
	return if kind == "StarterGear" then Jobs.Templates else poolFor("StarterGear")
end

local function slotKind(index: number): string
	if index == 1 then
		return "StarterGear"
	end
	return if index <= GameConfig.HomeownerJobsOnBoard then "Homeowner" else "Open"
end

-- [offer id] = the customer's preference. Kept off the offers players can see: the story is
-- the only hint.
local offerPreferences = {}

local function makeOffer(kind: string)
	local pool = poolFor(kind)
	local template = pool[rng:NextInteger(1, #pool)]

	nextOfferId += 1
	local preference = Jobs.pickPreference(rng)
	offerPreferences[tostring(nextOfferId)] = preference
	return {
		id = tostring(nextOfferId),
		templateId = template.id,
		name = template.name,
		tier = template.tier,
		address = Jobs.randomAddress(rng),
		customer = Jobs.Customers[rng:NextInteger(1, #Jobs.Customers)],
		story = Jobs.story(rng, template, preference),
		todo = Jobs.todoList(template),
		payout = math.floor(template.basePay * rng:NextNumber(0.9, 1.25) / 5 + 0.5) * 5,
		xp = template.xp,
		minLevel = template.minLevel,
		parTime = template.parTime,
		kind = kind,
	}
end

local function damagePenalty(job): number
	return math.max(GameConfig.MinDamagePenalty, math.floor(job.offer.payout * GameConfig.DamagePenalty + 0.5))
end

local function refreshBoard()
	table.clear(board)
	table.clear(offerPreferences)
	for index = 1, GameConfig.JobBoardSize do
		table.insert(board, makeOffer(slotKind(index)))
	end
	Net.event("JobBoardUpdated"):FireAllClients(board)
end

-- Sending job state to players ---------------------------------------------------------------

local function recipients(job)
	return if job.state == "Ready" then job.party.members else job.members
end

local function sendUpdate(job)
	local payload = {
		id = job.id,
		name = job.offer.name,
		address = job.offer.address,
		payout = job.offer.payout,
		state = job.state,
		leader = job.party.leader,
		tasks = if job.lawn then job.lawn:GetProgress() else nil,
		todo = job.offer.todo,
		customer = job.offer.customer,
		story = job.offer.story,
		parTime = job.offer.parTime,
		-- Server clock time the crew started working, for the HUD timer.
		startedAt = job.startedServerTime,
		penalty = job.penalty,
		damageCount = job.damageCount,
		result = job.result,
	}
	for _, player in recipients(job) do
		Net.event("JobUpdated"):FireClient(player, payload)
	end
end

local function clearJobFor(player: Player)
	if player.Parent == Players then
		Net.event("JobUpdated"):FireClient(player, nil)
	end
end

-- Moving players around ----------------------------------------------------------------------

local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
	end
end

-- Plays the truck cutscene for `players`, then moves each to destination(index, player).
-- If destination returns nil the player just stays where they are.
local function travel(players: { Player }, info, destination: (number, Player) -> CFrame?, onArrive: (() -> ())?)
	local token = {}
	info.duration = GameConfig.TravelTime

	for index, player in players do
		traveling[player] = token
		setFrozen(player, true)
		Net.event("TravelStarted"):FireClient(player, info)

		local target = destination(index, player)
		if target then
			-- Make sure the destination is loaded on their device before they get there.
			task.spawn(pcall, player.RequestStreamAroundAsync, player, target.Position)
		end
	end

	task.delay(GameConfig.TravelTime, function()
		for index, player in players do
			if traveling[player] == token then
				traveling[player] = nil
				if player.Parent == Players then
					local target = destination(index, player)
					if target and player.Character then
						player.Character:PivotTo(target)
					end
					setFrozen(player, false)
				end
			end
		end
		if onArrive then
			onArrive()
		end
	end)
end

local function claimSlot(): number
	local slot = 0
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	return slot
end

local function endJob(job)
	activeJobs[job] = nil
	-- Wait until everyone has left before tearing the yard down.
	task.delay(GameConfig.TravelTime + 1, function()
		if job.lawn then
			job.lawn:Destroy()
		end
		if job.slot then
			usedSlots[job.slot] = nil
		end
	end)
end

-- Takes a player off a job without moving them (used when they leave the game).
local function detach(job, player: Player)
	playerJobs[player] = nil
	JobService.PlayerStateChanged:Fire(player)
	local index = table.find(job.members, player)
	if index then
		table.remove(job.members, index)
	end
	if #job.members == 0 then
		endJob(job)
	else
		job.dirty = true
	end
end

local function sendHome(job, players: { Player })
	local going = {}
	for _, player in players do
		detach(job, player)
		clearJobFor(player)
		if player.Parent == Players then
			table.insert(going, player)
		end
	end
	travel(going, {
		direction = "ToBusiness",
		title = "Heading back to the shop",
		subtitle = job.offer.address,
		truckId = job.truckId,
		trailerId = job.trailerId,
	}, function(index, player)
		return WorldService:GetHomeCFrame(player, index)
	end)
end

-- Job lifecycle ------------------------------------------------------------------------------

local function startDriving(job)
	local party = job.party
	-- Which tools to bring is the crew's call; only an overloaded truck stops them.
	local used, capacity, baysUsed, bays = PartyService:GetTruckLoad(party.leader)
	if used > capacity or baysUsed > bays then
		local message = if used > capacity
			then `The truck is overloaded ({used}/{capacity} space). Take something out or hitch up a trailer.`
			else `There's no trailer bay for every ride-on machine ({baysUsed}/{bays}).`
		for _, member in party.members do
			notify(member, message)
		end
		return
	end

	readyJobs[party] = nil
	activeJobs[job] = true
	job.state = "Traveling"
	job.members = table.clone(party.members)
	for _, member in job.members do
		playerJobs[member] = job
		JobService.PlayerStateChanged:Fire(member)
	end

	local leaderData = DataService:Get(party.leader)
	job.truckId = if leaderData then leaderData.equipped.Truck else Items.starter("Truck").id
	job.trailerId = if leaderData then leaderData.equipped.Trailer else nil
	job.businessId = if leaderData then leaderData.equipped.Business else nil

	job.slot = claimSlot()
	local origin = GameConfig.JobSiteOrigin + Vector3.new(job.slot * GameConfig.JobSiteSpacing, 0, 0)
	job.lawn = LawnService:Build(Jobs.get(job.offer.templateId), origin, job.offer.address)

	local truck = Assets.truck(job.truckId, job.trailerId)
	Assets.anchor(truck)
	Assets.placeOnGround(truck, job.lawn.truckCFrame)
	truck.Parent = job.lawn.folder
	job.lawn.folder.Name = "JobSite_" .. job.id
	job.lawn.folder.Parent = sitesFolder

	sendUpdate(job)
	travel(job.members, {
		direction = "ToJob",
		title = job.offer.name,
		subtitle = job.offer.address,
		truckId = job.truckId,
		trailerId = job.trailerId,
	}, function(index, player)
		if playerJobs[player] ~= job then
			return nil
		end
		return job.lawn.spawnCFrame * CFrame.new((index - 1) * 3 - 4.5, 0, 0)
	end, function()
		if activeJobs[job] and job.state == "Traveling" then
			job.state = "Working"
			job.startedAt = os.clock()
			job.startedServerTime = workspace:GetServerTimeNow()
			sendUpdate(job)
			for _, member in job.members do
				JobService.PlayerStateChanged:Fire(member)
			end
		end
	end)
end

local function completeJob(job)
	job.state = "Complete"

	local members = job.members
	local truck = Items.get("Truck", job.truckId)
	local elapsed = os.clock() - job.startedAt
	local crewBonus = 1 + GameConfig.CrewBonusPerMember * (#members - 1)
	local truckBonus = 1 + (if truck then truck.payoutBonus else 0)
	local business = job.businessId and Items.get("Business", job.businessId)
	local businessBonus = 1 + (if business then business.payoutBonus else 0)
	-- Averages over all the work done, so the tool used most counts most.
	local toolFit = if job.work > 0 then job.fitWork / job.work else 1
	local quality = if job.work > 0 then job.qualityWork / job.work else 0.75
	local weights = Jobs.Preferences[job.preference]
	local total = GameConfig.jobPay({
		basePay = job.offer.payout,
		toolFit = toolFit,
		quality = quality,
		elapsed = elapsed,
		parTime = job.offer.parTime,
		weights = weights,
		bonus = crewBonus * truckBonus * businessBonus,
		penalty = job.penalty,
	})
	local share = math.floor(total / #members)

	job.result = {
		basePay = job.offer.payout,
		time = elapsed,
		preference = job.preference,
		toolFit = toolFit,
		quality = quality,
		qualityMultiplier = GameConfig.qualityMultiplier(quality),
		speedMultiplier = GameConfig.speedMultiplier(elapsed, job.offer.parTime),
		crewBonus = crewBonus,
		truckBonus = truckBonus,
		businessBonus = businessBonus,
		penalty = job.penalty,
		total = total,
		share = share,
	}

	for _, member in members do
		DataService:AddMoney(member, share)
		DataService:RecordJob(member, job.offer.xp)
		notify(member, `Job done! You earned {Format.money(share)}.`)
	end
	sendUpdate(job)

	task.delay(GameConfig.ReturnDelay, function()
		if activeJobs[job] then
			sendHome(job, table.clone(job.members))
		end
	end)
end

-- Public API ---------------------------------------------------------------------------------

function JobService:GetJob(player: Player)
	return playerJobs[player]
end

-- True once the crew has arrived at the house, until they leave. Tools only come out of the truck then.
function JobService:IsAtJobSite(player: Player): boolean
	local job = playerJobs[player]
	return job ~= nil and (job.state == "Working" or job.state == "Complete")
end

-- True while a player is on a job or riding in the truck.
function JobService:IsBusy(player: Player): boolean
	return playerJobs[player] ~= nil or traveling[player] ~= nil
end

-- How a bit of work was done, from ToolService:
--   damagesHazards  the tool cuts (and wrecks flowers and gnomes)
--   quiet           don't tell them their tool won't work (a mower idling while they stand still)
--   moving          they're walking
--   seconds         how long this bit of work took
export type WorkOptions = { damagesHazards: boolean?, quiet: boolean?, moving: boolean?, seconds: number? }

-- Called by ToolService every tick a player is using a tool.
function JobService:ApplyWork(
	player: Player,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	options: WorkOptions
)
	local job = playerJobs[player]
	if not job or job.state ~= "Working" then
		return false
	end

	if options.damagesHazards then
		for _, hazard in job.lawn:CheckHazards(position, radius) do
			local penalty = damagePenalty(job)
			job.penalty += penalty
			job.damageCount += 1
			job.dirty = true
			for _, member in job.members do
				notify(member, `{player.DisplayName} wrecked a {hazard.name}! -{Format.money(penalty)}`)
			end
		end
	end

	local result = job.lawn:ApplyWork(position, radius, toolId, amount, {
		protections = protectionsOf(player),
		holder = player,
		moving = options.moving,
		seconds = options.seconds,
	})
	if result.message then
		notify(player, result.message)
	end
	job.work += result.work
	job.fitWork += result.fitWork
	job.qualityWork += result.qualityWork
	local warnedRecently = os.clock() - (wrongToolWarnings[player] or 0) <= 4
	if result.hurt and not warnedRecently then
		wrongToolWarnings[player] = os.clock()
		notify(player, HURT_MESSAGES[result.hurt] or "You need some protection for that.")
	elseif result.blocked and not result.changed and not options.quiet and not warnedRecently then
		-- Never say which tool would work: knowing your tools is the game.
		wrongToolWarnings[player] = os.clock()
		notify(player, "That won't work here.")
	end
	if result.changed then
		job.dirty = true
		if job.lawn:IsComplete() then
			completeJob(job)
		end
	end
	return result.changed
end

function JobService:AcceptJob(player: Player, offerId: string): (boolean, string)
	local party = PartyService:GetParty(player)
	if not party or party.leader ~= player then
		return false, "Only your crew leader can accept jobs."
	end
	if readyJobs[party] then
		return false, "You already have a job. Hop in the truck!"
	end
	for _, member in party.members do
		if playerJobs[member] or traveling[member] then
			return false, "Your crew is already on a job."
		end
	end

	local index
	for i, offer in board do
		if offer.id == offerId then
			index = i
			break
		end
	end
	if not index then
		return false, "Another crew already took that job."
	end
	local offer = board[index]
	if DataService:GetLevel(player) < offer.minLevel then
		return false, `You need to be level {offer.minLevel} for this job.`
	end

	board[index] = makeOffer(offer.kind)
	Net.event("JobBoardUpdated"):FireAllClients(board)
	local preference = offerPreferences[offer.id] or "Balanced"
	offerPreferences[offer.id] = nil

	local job = {
		id = offer.id,
		offer = offer,
		preference = preference,
		party = party,
		state = "Ready",
		members = {},
		penalty = 0,
		damageCount = 0,
		-- Work done, and the same work weighted by tool fit and finish quality.
		work = 0,
		fitWork = 0,
		qualityWork = 0,
	}
	readyJobs[party] = job
	sendUpdate(job)
	return true, "Job accepted! Load the tools you think you'll need, then hop in the truck."
end

function JobService:Abandon(player: Player)
	local party = PartyService:GetParty(player)
	local ready = party and readyJobs[party]
	if ready then
		if party.leader == player then
			readyJobs[party] = nil
			for _, member in party.members do
				clearJobFor(member)
				notify(member, "The job was cancelled.")
			end
		end
		return
	end

	local job = playerJobs[player]
	if not job then
		return
	end
	if job.party.leader == player then
		for _, member in job.members do
			if member ~= player then
				notify(member, "Your crew leader called off the job.")
			end
		end
		sendHome(job, table.clone(job.members))
	else
		-- Leaving a job mid-way means leaving the crew too; MemberLeft sends them home.
		PartyService:Leave(player)
	end
end

-- Lifecycle ----------------------------------------------------------------------------------

function JobService:Init()
	sitesFolder = Instance.new("Folder")
	sitesFolder.Name = "JobSites"
	sitesFolder.Parent = workspace

	PartyService:SetBusyCheck(function(player)
		return self:IsBusy(player)
	end)

	Net.func("GetJobBoard").OnServerInvoke = function()
		return board
	end
	Net.func("AcceptJob").OnServerInvoke = function(player, offerId)
		if typeof(offerId) ~= "string" then
			return false, "That job doesn't exist."
		end
		return self:AcceptJob(player, offerId)
	end
	Net.event("AbandonJob").OnServerEvent:Connect(function(player)
		self:Abandon(player)
	end)
end

function JobService:Start()
	refreshBoard()

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") ~= "DriveToJob" then
			return
		end
		local party = PartyService:GetParty(player)
		local job = party and readyJobs[party]
		if party and prompt:GetAttribute("OwnerUserId") ~= party.leader.UserId then
			notify(player, "That's not your crew's truck.")
		elseif not job then
			if not playerJobs[player] then
				notify(player, "Pick a job from the Job Board first.")
			end
		elseif party.leader ~= player then
			notify(player, `Waiting for {party.leader.DisplayName} to start the truck.`)
		else
			startDriving(job)
		end
	end)

	PartyService.Changed:Connect(function(party)
		local ready = readyJobs[party]
		if ready then
			sendUpdate(ready)
		end
	end)

	local function goHome(player: Player)
		if player.Parent == Players and player.Character and not self:IsBusy(player) then
			player.Character:PivotTo(WorldService:GetHomeCFrame(player))
		end
	end

	-- Joining a crew takes you to the leader's business.
	PartyService.MemberJoined:Connect(function(_party, player)
		goHome(player)
	end)

	PartyService.MemberLeft:Connect(function(party, player, wasLeader)
		local ready = readyJobs[party]
		if ready then
			if #party.members == 0 then
				readyJobs[party] = nil
			end
			clearJobFor(player)
		end

		local job = playerJobs[player]
		if job and job.party == party and player.Parent == Players then
			notify(player, "You left the crew, so you're heading back to your business.")
			sendHome(job, { player })
		else
			goHome(player)
		end
		-- The crew follows the new leader to their business.
		if wasLeader then
			for _, member in party.members do
				goHome(member)
			end
		end
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			local job = playerJobs[player]
			if traveling[player] then
				return
			elseif job and job.lawn then
				-- Respawned mid-job: put them back at the house.
				task.wait()
				if playerJobs[player] == job then
					character:PivotTo(job.lawn.spawnCFrame)
				end
			else
				-- Everyone else spawns at their crew's business (once it's been built).
				DataService:WaitForData(player)
				task.wait(0.2)
				if player.Character == character then
					goHome(player)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		traveling[player] = nil
		wrongToolWarnings[player] = nil
		local job = playerJobs[player]
		if job then
			detach(job, player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.JobBoardRefreshTime)
			refreshBoard()
		end
	end)

	-- Progress updates are batched so a fast mower doesn't flood the network.
	while true do
		task.wait(0.25)
		for job in activeJobs do
			if job.dirty then
				job.dirty = false
				sendUpdate(job)
			end
		end
	end
end

return JobService
