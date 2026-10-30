-- The job board, and a crew's trip through a job:
--   Ready      the leader accepted a job; the crew loads the tools it needs and hops in the truck
--   Traveling  truck cutscene on the way there
--   Working    the crew is at the house doing yard work (the clock is running)
--   Complete   everyone got paid, the truck heads back to the business in a few seconds
-- A brand-new player's very first job starts at Working, with them already on the lawn (see
-- StartFirstJob), and its clock starts at their first snip (SnipAt).
--
-- Nothing here tells players which tools to bring: offers carry the customer's story and to-do
-- list, and a tool that can't do a task just gets "That won't work here".
--
-- Pay (GameConfig.jobPay) = job pay x how well the tools fit the tasks x a blend of finish
-- quality and speed (weighted by what the customer wants) x crew/truck/business bonuses, minus
-- damage for every flower patch or gnome the crew ran over. Then it's split evenly. Junk hidden
-- in the grass (Config/Debris.luau) that's still there at the end, or that a mower chewed up,
-- takes some off the finish and the pay too.
--
-- TurfKing (TurfKingService) can take a job off one player's board: they see it as "Taken by
-- TurfKing" and can't accept it, while everyone else's board is the same as before. A customer
-- won back from TurfKing pays a bonus on top (see SetWinBackBonus).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Debris = require(Shared.Config.Debris)
local Format = require(Shared.Format)
local HomeLawn = require(Shared.HomeLawn)
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Jobs = require(Shared.Config.Jobs)
local Net = require(Shared.Net)
local Premium = require(Shared.Config.Premium)
local Season = require(Shared.Config.Season)
local Stars = require(Shared.Config.Stars)
local Story = require(Shared.Config.Story)
local TaskTypes = require(Shared.Config.TaskTypes)
local Tools = require(Shared.Config.Tools)
local Signal = require(Shared.Signal)

local Openings = require(script.Parent.Parent.Openings)
local ServiceSpots = require(script.Parent.Parent.ServiceSpots)
local DataService = require(script.Parent.DataService)
local HomeLawnService = require(script.Parent.HomeLawnService)
local LawnService = require(script.Parent.LawnService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

-- How close to the truck (its bounding box) you have to be to drive off.
local TRUCK_REACH = 10
-- How far from your eyes you can pick up junk in the grass (the look-at reach is 10 from the camera).
local PICK_UP_REACH = 12
-- A snip of hand shears only hurts flowers right where it lands.
local SNIP_HAZARD_REACH = 0.3

local JobService = {}
-- Fired with (player) when they head out on a job, arrive at the house, or leave the job.
JobService.PlayerStateChanged = Signal.new()
-- Fired with (player, info) for each of the crew once a job's been paid: info is { customer,
-- pay (their share), quality (the finish, 0-1), preference, crew (how many of them), wonBack
-- (the customer was won back from TurfKing and paid a bonus), stars (1-3), tip (what the customer
-- tipped them on top of their share, 0 for none), junkPicked (pieces of junk picked up on the
-- lawn) }. Their best stars for the job are in their save by then (SeasonService counts the
-- three-star jobs from it).
JobService.JobFinished = Signal.new()

local rng = Random.new()
local board = {}
local nextOfferId = 0
local sitesFolder: Folder
-- [Player] = { [offer id] = true } for the jobs TurfKing took off their board
local takenFor = {}
-- Set by TurfKingService: (leader, { customer, preference, quality, payout }) -> the bonus a
-- customer won back from TurfKing pays, or 0.
local winBackBonus: ((Player, any) -> number)? = nil

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
-- Only templates the board can offer (not the first-timer's hidden one) are in any of them.
local function poolFor(kind: string)
	local maxLevel = if kind == "StarterGear" then 1 else highestLevel() + (if kind == "Open" then 2 else 0)
	local templates = Jobs.boardTemplates()
	local pool = {}
	for _, template in templates do
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
	return if kind == "StarterGear" then templates else poolFor("StarterGear")
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
-- [offer id] = the soil under a renovation job (only the soil probe reads it exactly).
local offerSoil = {}

local function makeOffer(kind: string)
	local pool = poolFor(kind)
	local template = pool[rng:NextInteger(1, #pool)]

	nextOfferId += 1
	local preference = Jobs.pickPreference(rng)
	offerPreferences[tostring(nextOfferId)] = preference
	local story = Jobs.story(rng, template, preference)
	if Jobs.isRenovation(template) then
		local soil, hint = Jobs.soil(rng)
		offerSoil[tostring(nextOfferId)] = soil
		story ..= " " .. hint
	end
	return {
		id = tostring(nextOfferId),
		templateId = template.id,
		name = template.name,
		tier = template.tier,
		address = Jobs.randomAddress(rng),
		-- A new player's first job is Edna's front lawn (docs/STORY.md, the intro), so the starter
		-- job is always hers.
		customer = if kind == "StarterGear"
			then Story.FirstCustomer
			else Jobs.Customers[rng:NextInteger(1, #Jobs.Customers)],
		story = story,
		todo = Jobs.todoList(template),
		payout = math.floor(template.basePay * rng:NextNumber(0.9, 1.25) / 5 + 0.5) * 5,
		xp = template.xp,
		minLevel = template.minLevel,
		parTime = template.parTime,
		kind = kind,
	}
end

-- The first-timer's job (Jobs FirstMow, never on the board, see JobService:StartFirstJob):
-- Edna's, like the starter job, at exactly its pay, so every new player's first payday is the
-- same. Her preference is Balanced, and that's in the story she tells.
local function firstOffer()
	local template = Jobs.get("FirstMow")
	nextOfferId += 1
	return {
		id = tostring(nextOfferId),
		templateId = template.id,
		name = template.name,
		tier = template.tier,
		address = Jobs.randomAddress(rng),
		customer = Story.FirstCustomer,
		story = Jobs.story(rng, template, "Balanced"),
		todo = Jobs.todoList(template),
		payout = template.basePay,
		xp = template.xp,
		minLevel = template.minLevel,
		parTime = template.parTime,
		kind = "First",
	}
end

local function damagePenalty(job): number
	return math.max(GameConfig.MinDamagePenalty, math.floor(job.offer.payout * GameConfig.DamagePenalty + 0.5))
end

-- What each piece of junk left in the grass, or chewed up by a mower, costs.
local function debrisPenalty(job): number
	return math.max(GameConfig.MinDebrisPenalty, math.floor(job.offer.payout * GameConfig.DebrisPenalty + 0.5))
end

-- The board as this player sees it: the jobs TurfKing took from them are marked `takenBy`.
local function boardFor(player: Player)
	local taken = takenFor[player]
	if not taken or next(taken) == nil then
		return board
	end
	local view = table.create(#board)
	for index, offer in board do
		if taken[offer.id] then
			local copy = table.clone(offer)
			copy.takenBy = "TurfKing"
			view[index] = copy
		else
			view[index] = offer
		end
	end
	return view
end

-- Sends everyone (or one player) the board, as each of them sees it. Jobs no longer on the board
-- are forgotten from what TurfKing took.
local function sendBoard(only: Player?)
	local onBoard = {}
	for _, offer in board do
		onBoard[offer.id] = true
	end
	for player, taken in takenFor do
		for id in taken do
			if not onBoard[id] then
				taken[id] = nil
			end
		end
		if next(taken) == nil then
			takenFor[player] = nil
		end
	end
	for _, player in if only then { only } else Players:GetPlayers() do
		Net.event("JobBoardUpdated"):FireClient(player, boardFor(player))
	end
end

local function refreshBoard()
	table.clear(board)
	table.clear(offerPreferences)
	table.clear(offerSoil)
	for index = 1, GameConfig.JobBoardSize do
		table.insert(board, makeOffer(slotKind(index)))
	end
	sendBoard()
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
		-- Which kind of offer this is ("First" for the first-timer's opening lawn), for the tutorial.
		kind = job.offer.kind,
		-- Server clock time the crew started working, for the HUD timer.
		startedAt = job.startedServerTime,
		penalty = job.penalty,
		damageCount = job.damageCount,
		result = job.result,
		-- What the soil probe read, once someone has used it.
		soil = if job.lawn and job.lawn.probed then job.lawn:SoilReading() else nil,
		-- How many bits of junk hide in the grass, and how many have been picked up or chewed up.
		debris = if job.lawn then job.lawn:DebrisCounts() else nil,
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

-- Call right after moving someone's character to `target`. First person keeps the camera looking
-- the way it was, and turns the character to match, so this says which way they should face now:
-- ArrivedFacing, and Arrivals counts the moves. The count is what the client watches, because
-- setting ArrivedFacing to the same value as last time wouldn't show up there as a change. The
-- title card turns the camera for the move at join, and CameraController for every move after it.
local function setArrivedFacing(player: Player, target: CFrame)
	player:SetAttribute("ArrivedFacing", target.LookVector)
	local arrivals = player:GetAttribute("Arrivals")
	player:SetAttribute("Arrivals", (if typeof(arrivals) == "number" then arrivals else 0) + 1)
end

-- Plays the truck cutscene for `players`, then moves each to destination(index, player).
-- If destination returns nil the player just stays where they are.
local function travel(players: { Player }, info, destination: (number, Player) -> CFrame?, onArrive: (() -> ())?)
	local token = {}
	info.duration = GameConfig.TravelTime

	for index, player in players do
		traveling[player] = token
		setFrozen(player, true)
		-- The cutscene builds the crew's truck on their screen (CutsceneController), from copies of
		-- its models that only their screen gets (Assets.shareWith). They go out first, so they've
		-- arrived by the time this has.
		Assets.shareWith(player, "Trucks", { info.truckId })
		Assets.shareWith(player, "Trailers", { info.trailerId })
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
						setArrivedFacing(player, target)
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

-- [Player] = os.clock() when they joined, until they're first where the game starts for them.
local joinedAt = {}

-- They're where the game starts for them: their business, or a first-timer's first lawn (see
-- JobService:StartFirstJob). `streamStarted` is when loading it on their device began.
local function markArrived(player: Player, place: string, streamStarted: number)
	local joined = joinedAt[player]
	if joined then
		joinedAt[player] = nil
		-- The title card logs its side of this in their own F9 console.
		print(
			string.format(
				"[Load] %s is at %s %.1f s after joining (%.1f s of that loading it on their device)",
				player.Name,
				place,
				os.clock() - joined,
				os.clock() - streamStarted
			)
		)
	end
	-- The title card waits for this (see ReplicatedFirst). The name is from when everyone started at
	-- their business: it means "arrived where the game starts", the first lawn for a first-timer.
	player:SetAttribute("ArrivedAtBusiness", true)
end

-- Puts a player who isn't on a job at their crew's business, facing the shop.
local function goHome(player: Player)
	local streamStarted = os.clock()
	if player.Parent == Players and player.Character and not JobService:IsBusy(player) then
		local home = WorldService:GetHomeCFrame(player)
		-- Load the business on their device first, so they don't land in an empty world.
		pcall(player.RequestStreamAroundAsync, player, home.Position, 5)
		if player.Parent == Players and player.Character and not JobService:IsBusy(player) then
			player.Character:PivotTo(home)
			setArrivedFacing(player, home)
		end
	end
	markArrived(player, "their business", streamStarted)
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
	-- The truck that pulled out comes back with its owner (or, if they're gone, with nobody).
	local owner = job.truckOwner
	local ownerGoing = owner ~= nil and table.find(going, owner) ~= nil
	if not job.tripStarted then
		-- Called off while the truck was still pulling out: everyone just gets back out, and the
		-- truck's back at the door.
		for _, player in going do
			setFrozen(player, false)
			Net.event("PullOutCancelled"):FireClient(player)
		end
		if owner and (ownerGoing or #job.members == 0) then
			WorldService:ReturnTruck(owner, true)
		end
		return
	end
	travel(going, {
		direction = "ToBusiness",
		title = "Heading back to the shop",
		subtitle = job.offer.address,
		truckId = job.truckId,
		trailerId = job.trailerId,
		paintId = job.paintId,
	}, function(index, player)
		return WorldService:GetHomeCFrame(player, index)
	end, function()
		-- Back at the business: the truck pulls back in and drops its tailgate for unloading.
		if owner and ownerGoing then
			WorldService:ReturnTruck(owner)
		end
	end)
end

-- Job lifecycle ------------------------------------------------------------------------------

-- Builds the job's yard at a free site, with the crew's truck (job.truckId, trailerId and paintId)
-- parked out front.
local function buildSite(job)
	job.slot = claimSlot()
	local origin = GameConfig.JobSiteOrigin + Vector3.new(job.slot * GameConfig.JobSiteSpacing, 0, 0)
	job.lawn = LawnService:Build(Jobs.get(job.offer.templateId), origin, job.offer.address, { soil = job.soil })

	local truck = Assets.truck(job.truckId, job.trailerId)
	Premium.applyPaint(truck, if job.paintId then Premium.get(job.paintId) else nil)
	Assets.anchor(truck)
	Assets.placeOnGround(truck, job.lawn.truckCFrame)
	-- Parked at the house with the tailgate down: it's where you work on your tools.
	Openings.set(truck, true)
	truck.Parent = job.lawn.folder
	-- Tools are worked on at the tailgate, with the supplies you brought (see MaintenanceService):
	-- a spot on the ground behind it and a vise on the tailgate. A supply you took goes back by
	-- looking at the truck.
	ServiceSpots.add(job.lawn.folder, ServiceSpots.forTruck(truck))
	-- The streak's pennant flies on it too, if the leader has earned it (see WorldService). After the
	-- spots above, which are measured from the bare truck.
	if WorldService:HasPennant(job.truckOwner) then
		Assets.addPennant(truck)
	end
	truck:SetAttribute("Interact", "Tailgate")
	truck:SetAttribute("InteractText", "Put it back")
	truck:SetAttribute("InteractName", "Tailgate")
	job.lawn.folder.Name = "JobSite_" .. job.id
	job.lawn.folder.Parent = sitesFolder
end

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
	-- The leader is always first, so they're in the driver's seat.
	job.members = table.clone(party.members)
	for _, member in job.members do
		playerJobs[member] = job
		JobService.PlayerStateChanged:Fire(member)
	end
	-- Everyone gets in: the tailgate shuts, the driver's door opens and closes, and the truck
	-- pulls out of the driveway (each crew member watches from their seat) before the trip. It's
	-- the leader's truck, and it comes back with them (see sendHome).
	local plotTruck = WorldService:GetPlotTruck(party.leader)
	job.truckOwner = party.leader
	WorldService:SetTruckOpen(party.leader, false)
	WorldService:PullOut(party.leader)
	for seat, member in job.members do
		setFrozen(member, true)
		Net.event("PullingOut"):FireClient(member, {
			truck = plotTruck,
			seat = seat,
			duration = GameConfig.PullOutTime,
		})
	end

	local leaderData = DataService:Get(party.leader)
	job.truckId = if leaderData then leaderData.equipped.Truck else Items.starter("Truck").id
	job.trailerId = if leaderData then leaderData.equipped.Trailer else nil
	job.businessId = if leaderData then leaderData.equipped.Business else nil
	-- The leader's Robux paint job (see Premium.luau): on the truck at the job and in the trip.
	local paint = Premium.paintFor(leaderData and leaderData.premium)
	job.paintId = if paint then paint.id else nil
	-- How good the business looked as the crew left: customers pay a little more for that.
	job.curbAppeal = HomeLawnService:CurbAppeal(party.leader)

	buildSite(job)

	sendUpdate(job)
	task.wait(GameConfig.PullOutTime)
	if not (activeJobs[job] and job.state == "Traveling") then
		-- Everyone already got back out (see sendHome).
		return
	end
	job.tripStarted = true
	travel(job.members, {
		direction = "ToJob",
		title = job.offer.name,
		subtitle = job.offer.address,
		truckId = job.truckId,
		trailerId = job.trailerId,
		paintId = job.paintId,
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
	local curbBonus = HomeLawn.payBonus(job.curbAppeal or 0)
	-- Averages over all the work done, so the tool used most counts most.
	local toolFit = if job.work > 0 then job.fitWork / job.work else 1
	local quality = if job.work > 0 then job.qualityWork / job.work else 0.75
	-- Junk still in the grass, or chewed up by a mower, spoils the finish. Each piece left costs
	-- some pay now (chewed-up ones already did, when they were hit).
	local debris = job.lawn:DebrisCounts()
	quality = math.max(0, quality - (debris.left + debris.hit) * GameConfig.DebrisQualityHit)
	job.penalty += debris.left * debrisPenalty(job)
	local weights = Jobs.Preferences[job.preference]
	local total = GameConfig.jobPay({
		basePay = job.offer.payout,
		toolFit = toolFit,
		quality = quality,
		elapsed = elapsed,
		parTime = job.offer.parTime,
		weights = weights,
		bonus = crewBonus * truckBonus * businessBonus * curbBonus,
		penalty = job.penalty,
	})
	-- A customer won back from TurfKing pays a little extra, the first time (it's the business of
	-- the leader who drove out to them that wins them).
	local wonBack = 0
	local leader = job.truckOwner
	if winBackBonus and leader and leader.Parent == Players then
		local ok, amount = pcall(winBackBonus, leader, {
			customer = job.offer.customer,
			preference = job.preference,
			quality = quality,
			payout = job.offer.payout,
		})
		if ok and typeof(amount) == "number" and amount > 0 then
			wonBack = math.floor(amount)
			total += wonBack
		elseif not ok then
			warn(`The TurfKing bonus failed: {amount}`)
		end
	end
	local share = math.floor(total / #members)

	-- Stars: how the job did against what the customer wanted, by GameConfig.performance, the same
	-- blend GameConfig.jobPay pays by. A flower or gnome wrecked (damageCount), or junk left or
	-- chewed up, keeps it from three. The customer tips each of the crew a share of their share by
	-- the stars.
	local qualityMultiplier = GameConfig.qualityMultiplier(quality)
	local speedMultiplier = GameConfig.speedMultiplier(elapsed, job.offer.parTime)
	local performance = Stars.round(GameConfig.performance(quality, elapsed, job.offer.parTime, weights))
	local penalized = (debris.left + debris.hit) > 0 or job.damageCount > 0
	local stars = Stars.of(performance, penalized)
	local tip = math.floor(share * Stars.tipRate(stars))

	job.result = {
		basePay = job.offer.payout,
		time = elapsed,
		preference = job.preference,
		toolFit = toolFit,
		quality = quality,
		qualityMultiplier = qualityMultiplier,
		speedMultiplier = speedMultiplier,
		crewBonus = crewBonus,
		truckBonus = truckBonus,
		businessBonus = businessBonus,
		curbAppeal = job.curbAppeal or 0,
		curbBonus = curbBonus,
		penalty = job.penalty,
		-- Junk left in the grass, and chewed up by a mower (both are in the penalty).
		debrisLeft = debris.left,
		debrisHit = debris.hit,
		-- What a customer won back from TurfKing paid on top (it's in the total).
		wonBack = wonBack,
		total = total,
		share = share,
		-- What the job's stars came from, the stars, and what the customer tipped each of the crew
		-- on top of the share (PayBreakdown shows it).
		performance = performance,
		stars = stars,
		tip = tip,
		customer = job.offer.customer,
	}

	for _, member in members do
		-- Their best stars on this kind of job, in the save before anything else hears the job is done.
		local data = DataService:Get(member)
		if data then
			local templateId = job.offer.templateId
			data.stars[templateId] = math.max(data.stars[templateId] or 0, stars)
		end
		-- Job pay and the tip are money they earned (it counts toward the Earned milestones), each paid
		-- only when there's something to pay.
		if share > 0 then
			DataService:Earn(member, share)
		end
		if tip > 0 then
			DataService:Earn(member, tip)
		end
		DataService:RecordJob(member, job.offer.xp)
		local message = `Job done! You earned {Format.money(share)}.`
		if tip > 0 then
			message ..= ` {job.offer.customer} tipped you {Format.money(tip)}.`
		end
		notify(member, message)
	end
	sendUpdate(job)
	for _, member in members do
		JobService.JobFinished:Fire(member, {
			customer = job.offer.customer,
			pay = share,
			quality = quality,
			preference = job.preference,
			crew = #members,
			wonBack = wonBack > 0,
			stars = stars,
			tip = tip,
			-- Pieces of junk picked up on the lawn, for the day's contracts (DailyService).
			junkPicked = debris.picked,
		})
	end

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
--   qualityScale    how the tool's condition changes its finish (a dull blade tears instead of cutting)
--   ragged          the cut is torn enough to see in the grass
--   snip            a snip of hand shears: it only cuts the one thing nearest `position`, and only
--                   hurts flowers right there
--   strikes         a motorized mower: it runs over junk hidden in the grass instead of stopping
export type WorkOptions = {
	damagesHazards: boolean?,
	quiet: boolean?,
	moving: boolean?,
	seconds: number?,
	qualityScale: number?,
	ragged: boolean?,
	snip: boolean?,
	strikes: boolean?,
}

-- Wrecks any flower patch or gnome within `reach` of `position` (only X and Z count), and takes
-- it off the job's pay.
local function wreckHazards(job, player: Player, position: Vector3, reach: number)
	for _, hazard in job.lawn:CheckHazards(position, reach) do
		local penalty = damagePenalty(job)
		job.penalty += penalty
		job.damageCount += 1
		job.dirty = true
		for _, member in job.members do
			notify(member, `{player.DisplayName} wrecked a {hazard.name}! -{Format.money(penalty)}`)
		end
	end
end

-- Who's working and how, as the lawn wants it (see LawnService's WorkContext).
local function workContext(player: Player, options: WorkOptions)
	return {
		protections = protectionsOf(player),
		holder = player,
		moving = options.moving,
		seconds = options.seconds,
		ragged = options.ragged,
		closest = options.snip,
		strikes = options.strikes,
	}
end

-- Adds what a bit of work did to the job (pay, finish, junk a mower chewed up), tells the player
-- what they need to know, and finishes the job when that was the last of it. `snip` is a snip of
-- hand shears. Returns whether anything got done, and the junk chewed up.
local function settle(job, player: Player, result, options: WorkOptions, snip: boolean): (boolean, { any }?)
	if result.message then
		notify(player, result.message)
	end
	-- A mower chewed something up: the customer's going to notice.
	for _, debris in result.struck do
		local penalty = debrisPenalty(job)
		job.penalty += penalty
		job.dirty = true
		local cost = Format.money(penalty)
		for _, member in job.members do
			notify(
				member,
				if member == player
					then `{debris.kind.hit} -{cost}`
					else `{player.DisplayName}'s mower chewed up a {debris.kind.name} in the grass! -{cost}`
			)
		end
	end
	job.work += result.work
	job.fitWork += result.fitWork
	job.qualityWork += result.qualityWork * (options.qualityScale or 1)
	local warnedRecently = os.clock() - (wrongToolWarnings[player] or 0) <= 4
	if result.hurt and not warnedRecently then
		wrongToolWarnings[player] = os.clock()
		notify(player, HURT_MESSAGES[result.hurt] or "You need some protection for that.")
	elseif result.debris and not warnedRecently then
		-- Something hidden in the grass is in the way (it never says which tool would cut through).
		wrongToolWarnings[player] = os.clock()
		notify(player, Debris.blockedMessage(result.debris.kind, snip))
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
	return result.changed, result.struck
end

-- Called by ToolService every tick a player is using a tool (and for every snip of hand shears)
-- on everything but the grass, which mowers sweep (Sweep) and shears snip (SnipAt). Returns
-- whether anything got done, and the junk in the grass a mower just chewed up (for the blade's
-- wear).
function JobService:ApplyWork(
	player: Player,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	options: WorkOptions
): (boolean, { any }?)
	local job = playerJobs[player]
	if not job or job.state ~= "Working" then
		return false, nil
	end
	if options.damagesHazards then
		wreckHazards(job, player, position, if options.snip then SNIP_HAZARD_REACH else radius)
	end
	local result = job.lawn:ApplyWork(position, radius, toolId, amount, workContext(player, options))
	return settle(job, player, result, options, options.snip == true)
end

-- Called by ToolService every tick a mower's deck, `halfWidth` studs either side, moves over the
-- job's lawn: from where it was last tick to where it is now, in world studs (see Lawn:Sweep).
-- Takes the same options as ApplyWork and returns the same, plus whether junk in the grass stopped
-- the deck short (only a mower that isn't motorized stops at it) and whether the mower can mow
-- the lawn at all (it fits the mowing), cut or not.
function JobService:Sweep(
	player: Player,
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number,
	toolId: string,
	options: WorkOptions
): (boolean, { any }?, boolean, boolean)
	local job = playerJobs[player]
	if not job or job.state ~= "Working" then
		return false, nil, false, false
	end
	if options.damagesHazards then
		wreckHazards(job, player, Vector3.new(toX, 0, toZ), halfWidth)
	end
	local result = job.lawn:Sweep(fromX, fromZ, toX, toZ, halfWidth, toolId, workContext(player, options))
	local changed, struck = settle(job, player, result, options, false)
	return changed, struck, result.debris ~= nil, result.fits == true
end

-- Called by ToolService for every snip of hand shears: the grass within `radius` of (x, z), in
-- world studs (see Lawn:SnipAt). Takes the same options as ApplyWork and returns the same.
function JobService:SnipAt(
	player: Player,
	x: number,
	z: number,
	radius: number,
	toolId: string,
	options: WorkOptions
): (boolean, { any }?)
	local job = playerJobs[player]
	if not job or job.state ~= "Working" then
		return false, nil
	end
	if job.firstTimer and not job.snipped then
		-- The first-timer's job starts at the title card, so the par clock starts again here, at
		-- their first snip: the time it took to tap past the card doesn't count against par.
		job.snipped = true
		job.startedAt = os.clock()
		job.startedServerTime = workspace:GetServerTimeNow()
		sendUpdate(job)
	end
	if options.damagesHazards then
		wreckHazards(job, player, Vector3.new(x, 0, z), SNIP_HAZARD_REACH)
	end
	local result = job.lawn:SnipAt(x, z, radius, toolId, workContext(player, options))
	return settle(job, player, result, options, true)
end

-- Picks up the piece of junk in the grass that `thing` is part of (the client says what the
-- player's looking at; the server checks it's on their job's lawn and within reach). Off a job,
-- it's their crew's own lawn.
function JobService:PickUpDebris(player: Player, thing: Instance): (boolean, string?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return false, nil
	end
	local job = playerJobs[player]
	if not job then
		return HomeLawnService:PickUpDebris(player, thing, head.Position, PICK_UP_REACH)
	end
	if job.state ~= "Working" or not job.lawn then
		return false, nil
	end
	local debris, reason = job.lawn:PickUpDebris(thing, head.Position, PICK_UP_REACH)
	if not debris then
		return false, reason
	end
	job.dirty = true
	local left = #job.lawn.debris
	return true,
		if left == 0
			then `Picked up the {debris.kind.name}. That's everything out of the grass.`
			else `Picked up the {debris.kind.name}. {left} more hidden in the grass.`
end

-- The player put a tool away: a barrow load they were pushing spills.
function JobService:PutAway(player: Player)
	local job = playerJobs[player]
	if job and job.lawn and job.lawn:DropLoad(player) then
		notify(player, "You let go of the barrow and the load spilled.")
	end
end

function JobService:AcceptJob(player: Player, offerId: string): (boolean, string)
	local party = PartyService:GetParty(player)
	if not party or party.leader ~= player then
		return false, "Only your crew leader can accept jobs."
	end
	if not WorldService:IsAtComputer(player) then
		return false, "Take jobs at the computer in your shop."
	end
	if readyJobs[party] then
		return false, "You already have a job. Get in at the truck's driver door!"
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
	if takenFor[player] and takenFor[player][offer.id] then
		return false, "TurfKing got there first. Pick another job."
	end
	if DataService:GetLevel(player) < offer.minLevel then
		return false, `You need to be level {offer.minLevel} for this job.`
	end

	board[index] = makeOffer(offer.kind)
	sendBoard()
	local preference = offerPreferences[offer.id] or "Balanced"
	offerPreferences[offer.id] = nil
	local soil = offerSoil[offer.id]
	offerSoil[offer.id] = nil

	local job = {
		id = offer.id,
		offer = offer,
		preference = preference,
		soil = soil,
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
	return true, "Job accepted! Load the tools you think you'll need, then get in at the truck's driver door."
end

-- A brand-new player (Season.isFirstTimer) starts on a lawn, not at the computer: as they join,
-- this gives them the first-timer's job (Jobs FirstMow), already Working, and stands them on it
-- with Grandma's shears in their hands and their truck parked out front. No board, no loading, no
-- drive: the title card lifts on the grass. From there it's a job like any other (but its par
-- clock starts again at their first snip, in SnipAt), and the truck brings them home after the
-- payday (completeJob, sendHome), where the story's intro plays.
-- Their save's firstJob is set before anything else, so a crash or a rejoin never runs this
-- twice: they start at their business after that. If any of it fails, it's cleared away and they
-- start at their business now, so nobody is left stranded.
function JobService:StartFirstJob(player: Player)
	local data = DataService:Get(player)
	if not data then
		goHome(player)
		return
	end
	data.firstJob = true
	DataService:Changed(player)
	task.spawn(DataService.Save, DataService, player)

	-- On their own only: someone already in a crew (an invite taken behind the title card) goes
	-- with their crew.
	local party = PartyService:GetParty(player)
	if not (party and party.leader == player and #party.members == 1) or self:IsBusy(player) then
		goHome(player)
		return
	end

	local streamStarted = os.clock()
	local job = nil
	local ok, err = pcall(function()
		local offer = firstOffer()
		job = {
			id = offer.id,
			offer = offer,
			preference = "Balanced",
			party = party,
			members = { player },
			penalty = 0,
			damageCount = 0,
			work = 0,
			fitWork = 0,
			qualityWork = 0,
			-- No pull-out to call off: they're there already (sendHome and a respawn read this).
			tripStarted = true,
			-- SnipAt starts their par clock again at the first snip (see there).
			firstTimer = true,
		}
		activeJobs[job] = true
		playerJobs[player] = job
		-- Their own truck, as startDriving fills it in. It never leaves the business: sendHome's
		-- ReturnTruck does nothing for a truck that's still at home.
		job.truckOwner = player
		job.truckId = data.equipped.Truck
		job.trailerId = data.equipped.Trailer
		job.businessId = data.equipped.Business
		local paint = Premium.paintFor(data.premium)
		job.paintId = if paint then paint.id else nil
		job.curbAppeal = HomeLawnService:CurbAppeal(player)
		buildSite(job)
		job.state = "Working"
		job.startedAt = os.clock()
		job.startedServerTime = workspace:GetServerTimeNow()

		-- Load the lawn on their device first, the way goHome loads the business.
		local standAt = job.lawn.spawnCFrame
		streamStarted = os.clock()
		pcall(player.RequestStreamAroundAsync, player, standAt.Position, 5)
		if playerJobs[player] ~= job then
			-- They left while it loaded, and leaving cleared the job away.
			return
		end
		local character = player.Character
		assert(character, "they have no character")
		character:PivotTo(standAt)
		setArrivedFacing(player, standAt)
		sendUpdate(job)
		-- At the job site, the tools in the truck go in their backpack (ToolService:GiveTools)...
		JobService.PlayerStateChanged:Fire(player)
		-- ...and the shears from there into their hands. ToolService requires this module, so it's
		-- looked up now rather than at the top (every service has loaded long before anyone joins).
		local ToolService = require(script.Parent.ToolService)
		-- GiveTools runs here directly as well: the signal's handler only runs to its first yield,
		-- and GiveHeld builds a second pair if the backpack has none yet. Running it twice is safe.
		ToolService:GiveTools(player)
		ToolService:GiveHeld(player, "GardenShears")
	end)
	if not ok then
		warn(`Couldn't start {player.Name}'s first job, so they start at their business: {err}`)
		if job then
			job.members = {}
			if playerJobs[player] == job then
				playerJobs[player] = nil
			end
			if activeJobs[job] then
				endJob(job)
			end
			clearJobFor(player)
			JobService.PlayerStateChanged:Fire(player)
		end
		goHome(player)
		return
	end
	markArrived(player, "their first job", streamStarted)
end

-- The offers on the board right now (read them, don't change them).
function JobService:GetBoard(): { any }
	return board
end

-- The jobs TurfKing took off this player's board, by offer id.
function JobService:GetTaken(player: Player): { [string]: boolean }
	return takenFor[player] or {}
end

-- The offers some crew has accepted and not finished, by id. (They're off the board already;
-- TurfKing never takes one.)
function JobService:GetAccepted(): { [string]: boolean }
	local accepted = {}
	for _, job in readyJobs do
		accepted[job.id] = true
	end
	for job in activeJobs do
		accepted[job.id] = true
	end
	return accepted
end

-- TurfKing takes an offer off this player's board (TurfKingService picks which): they see it as
-- taken and can't accept it. Only an offer still on the board, and never the starter job.
function JobService:TakeOffer(player: Player, offerId: string): boolean
	for _, offer in board do
		if offer.id == offerId then
			if offer.kind == "StarterGear" or self:GetAccepted()[offerId] then
				return false
			end
			takenFor[player] = takenFor[player] or {}
			takenFor[player][offerId] = true
			sendBoard(player)
			return true
		end
	end
	return false
end

-- TurfKingService says what a customer won back from TurfKing pays on top of a finished job:
-- `bonus(leader, { customer, preference, quality, payout })` returns the amount (0 for none).
function JobService:SetWinBackBonus(bonus: (Player, any) -> number)
	winBackBonus = bonus
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

	Net.func("GetJobBoard").OnServerInvoke = function(player)
		return boardFor(player)
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
	-- Looking at junk in the grass and pressing E (see InteractController) picks it up.
	local lastPickUp = {}
	Players.PlayerRemoving:Connect(function(player)
		lastPickUp[player] = nil
	end)
	Net.func("PickUpDebris").OnServerInvoke = function(player, thing)
		if typeof(thing) ~= "Instance" or os.clock() - (lastPickUp[player] or 0) < 0.2 then
			return false, nil
		end
		lastPickUp[player] = os.clock()
		return self:PickUpDebris(player, thing)
	end
end

function JobService:Start()
	refreshBoard()

	-- Looking at the crew truck and pressing E (see InteractController) heads out.
	local lastDrive = {}
	Players.PlayerRemoving:Connect(function(player)
		lastDrive[player] = nil
	end)
	Net.func("DriveToJob").OnServerInvoke = function(player)
		if os.clock() - (lastDrive[player] or 0) < 1 then
			return false, nil
		end
		lastDrive[player] = os.clock()
		local party = PartyService:GetParty(player)
		local leader = if party then party.leader else player
		local job = party and readyJobs[party]
		local truck = WorldService:GetPlotTruck(leader)
		if not (truck and WorldService:IsNear(player, truck, TRUCK_REACH)) then
			return false, "Get closer to your crew's truck."
		elseif not job then
			return false, if playerJobs[player] then nil else "Pick a job at the computer first."
		elseif leader ~= player then
			return false, `Waiting for {leader.DisplayName} to start the truck.`
		end
		-- The pull-out takes a few seconds; don't keep the client waiting.
		task.spawn(startDriving, job)
		return true, nil
	end

	PartyService.Changed:Connect(function(party)
		local ready = readyJobs[party]
		if ready then
			sendUpdate(ready)
		end
	end)

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
		joinedAt[player] = os.clock()
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			local job = playerJobs[player]
			if traveling[player] then
				return
			elseif job and not job.tripStarted then
				-- Respawned in the truck as it pulls out: still in their seat.
				task.wait()
				setFrozen(player, true)
			elseif job and job.lawn then
				-- Respawned mid-job: put them back at the house.
				task.wait()
				if playerJobs[player] == job then
					character:PivotTo(job.lawn.spawnCFrame)
					setArrivedFacing(player, job.lawn.spawnCFrame)
				end
			else
				-- Everyone else spawns at their crew's business, as soon as it's been built (and a
				-- frame on, so the spawn doesn't put them back).
				local data = DataService:WaitForData(player)
				WorldService:WaitForPlot(player, 5)
				task.wait()
				if player.Character == character then
					-- A brand-new player starts on their first job's lawn instead.
					if data and Season.isFirstTimer(data, false) then
						self:StartFirstJob(player)
					else
						goHome(player)
					end
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
		traveling[player] = nil
		wrongToolWarnings[player] = nil
		takenFor[player] = nil
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
