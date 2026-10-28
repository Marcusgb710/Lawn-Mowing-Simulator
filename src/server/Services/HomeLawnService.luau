-- Your business's own front lawn (docs/GAME_DESIGN.md, "Your own lawn"). Every business plot has
-- one, left of the driveway. It has the same kit grass as customers' lawns, mowed on the same
-- LawnGrid, plus an edge along the sidewalk and driveway, a few weeds, the odd pile of leaves and
-- a stick or two hidden in the grass (Config/Debris.luau).
-- You look after it with your own tools, straight out of storage (TruckService hands them to
-- you), and they fit and wear just as they do on a job. Your crew can help with the leader's lawn.
--
-- It grows back while you play: a tidy lawn is overgrown again after
-- GameConfig.HomeLawn.RegrowMinutes in the game, a bit at a time. What's done is saved
-- (data.homeLawn), so the lawn looks the same when you come back. Getting an untidy lawn tidy
-- again earns a small tip from a neighbor, now and then. How the lawn looks and how the yard is
-- decorated (DecorService) make up the business's curb appeal (see HomeLawn.luau), which pays a
-- bonus on every job. Hedge work near the yard's overgrown shrubs goes to DecorService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Debris = require(Shared.Config.Debris)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local HomeLawn = require(Shared.HomeLawn)
local Net = require(Shared.Net)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local DecorService = require(script.Parent.DecorService)
local LawnService = require(script.Parent.LawnService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

-- How far (studs) outside the lawn work still counts, side by side: just past the edge along the
-- front and the driveway, the weeds down the left, and the weeds along the back.
local MARGIN_LEFT, MARGIN_RIGHT, MARGIN_FRONT, MARGIN_BACK = 2, 1.5, 1.5, 3.5
-- Gloves owned are checked again this often (seconds), not every tick.
local PROTECTIONS_REFRESH = 2
-- Nothing grows back this close to someone, so it doesn't spring up right behind the mower.
local GROW_CLEARANCE = 10
-- How often the lawns grow (seconds).
local GROW_TICK = 1
-- Saves from before the grass was cut into one-stud cells keep one flag for each 4 x 4 stud tile
-- of it, so a flag stands for this many cells (written down, as the tiles are gone from the config).
local CELLS_PER_SAVED_TILE = 16
local HURT_MESSAGES = {
	Thorns = "Ouch! Those thorns shred your bare hands.",
	Chemicals = "You can't handle weed killer with your bare hands.",
}

local HomeLawnService = {}

-- [Player] = { lawn, targets, frame, min, max, growth, tidy, done } for each business owner here
local lawns = {}
-- [Player] = os.clock() they were last told their tool won't work here
local warnedAt = {}
-- [Player] = { at = os.clock(), value = their protections }
local protectionCache = {}
local folder: Folder
local rng = Random.new()

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function leaderOf(player: Player): Player
	local party = PartyService:GetParty(player)
	return if party then party.leader else player
end

-- The protection of every pair of gloves they own: at home they just put them on.
local function protectionsOf(player: Player, data): { [string]: boolean }
	local cached = protectionCache[player]
	if cached and os.clock() - cached.at < PROTECTIONS_REFRESH then
		return cached.value
	end
	local protections = {}
	for _, owned in data.owned do
		for toolId in owned do
			local tool = Tools.get(toolId)
			for _, hazard in if tool and tool.protects then tool.protects else {} do
				protections[hazard] = true
			end
		end
	end
	protectionCache[player] = { at = os.clock(), value = protections }
	return protections
end

-- Their saved lawn, made sound if the save holds something odd.
local function savedState(data)
	local state = data.homeLawn
	if typeof(state) ~= "table" then
		state = {}
		data.homeLawn = state
	end
	if typeof(state.done) ~= "table" then
		state.done = {}
	end
	if typeof(state.tippedAt) ~= "number" then
		state.tippedAt = 0
	end
	-- Whether it's grown back enough since the last tip for tidying it to earn another.
	if typeof(state.tipReady) ~= "boolean" then
		state.tipReady = true
	end
	return state
end

local function doneCount(lawn): number
	local done = 0
	for _, task in lawn.tasks do
		done += task.done
	end
	return done
end

-- Saves what's done, and shows the business's curb appeal.
local function refresh(owner: Player, entry)
	entry.done = doneCount(entry.lawn)
	local data = DataService:Get(owner)
	if data then
		local done = {}
		for _, task in entry.lawn.tasks do
			local flags = table.create(#task.targets)
			for index, target in task.targets do
				flags[index] = target.work <= 0
			end
			done[task.id] = HomeLawn.encode(flags)
		end
		local state = savedState(data)
		state.done = done
		if entry.lawn:DoneShare() < GameConfig.HomeLawn.TipAfterBelowShare then
			state.tipReady = true
		end
	end
	owner:SetAttribute("CurbAppeal", HomeLawn.curbAppeal(entry.lawn:DoneShare(), DecorService:DecorShare(owner)))
end

local function destroy(owner: Player)
	local entry = lawns[owner]
	if entry then
		entry.lawn:Destroy()
		lawns[owner] = nil
	end
end

-- Builds the owner's lawn on their plot, the way they left it.
local function build(owner: Player)
	local data = DataService:Get(owner)
	if owner.Parent ~= Players then
		return
	end
	local frame, size = WorldService:GetLawnArea(owner)
	if not (data and frame and size) then
		destroy(owner)
		return
	end
	local existing = lawns[owner]
	if existing and existing.frame == frame then
		return
	end
	destroy(owner)

	-- Lawns are drawn on a grid that runs along the world's axes, so it's laid out that way.
	local tile = GameConfig.TileSize
	local right = frame.RightVector
	local alongX = math.abs(right.X) >= math.abs(right.Z)
	local columns = math.floor((if alongX then size.X else size.Z) / tile)
	local rows = math.floor((if alongX then size.Z else size.X) / tile)
	if columns < 1 or rows < 1 then
		return
	end
	local origin = frame.Position - Vector3.new(columns * tile / 2, 0, rows * tile / 2)
	local lawn = LawnService:Build(
		HomeLawn.template(columns, rows),
		origin,
		`{owner.DisplayName}'s lawn`,
		{ home = true, seed = owner.UserId }
	)
	lawn.folder.Name = "HomeLawn_" .. owner.UserId
	lawn.folder:SetAttribute("OwnerUserId", owner.UserId)
	for _, task in lawn.tasks do
		local saved = savedState(data).done[task.id]
		local done
		if task.type.target == "Grass" then
			done = HomeLawn.decode(saved, #task.targets, CELLS_PER_SAVED_TILE, lawn.cellRows)
		else
			done = HomeLawn.decode(saved, #task.targets)
		end
		for index, target in task.targets do
			if done[index] then
				lawn:Finish(target)
			end
		end
	end
	lawn.folder.Parent = folder

	local entry = {
		lawn = lawn,
		targets = lawn:AllTargets(),
		frame = frame,
		min = origin - Vector3.new(MARGIN_LEFT, 0, MARGIN_FRONT),
		max = origin + Vector3.new(columns * tile + MARGIN_RIGHT, 0, rows * tile + MARGIN_BACK),
		-- [target] = { seconds tidy so far, seconds it stays tidy }, for the tidy ones
		ages = {},
		tidy = lawn:IsComplete(),
		done = 0,
	}
	lawns[owner] = entry
	refresh(owner, entry)
end

-- The lawn of the player's crew (their leader's), if they're standing on it.
local function lawnUnder(player: Player)
	local entry = lawns[leaderOf(player)]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (entry and root and root:IsA("BasePart")) then
		return nil
	end
	local position = root.Position
	local inside = position.X >= entry.min.X
		and position.X <= entry.max.X
		and position.Z >= entry.min.Z
		and position.Z <= entry.max.Z
	return if inside then entry else nil
end

-- Every tidy bit of the lawn ages, and grows back once it's been tidy long enough
-- (HomeLawn.staysTidyFor), unless someone's standing by it.
local function grow(owner: Player, entry, seconds: number)
	local roots = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(roots, root.Position)
		end
	end
	local grew = false
	-- The grass cells that grow back, for the clients drawing the lawn.
	local regrown = {}
	for _, target in entry.targets do
		if target.work > 0 then
			-- Not done: when it is, its time starts from then.
			entry.ages[target] = nil
			continue
		end
		local age = entry.ages[target]
		if not age then
			age = { seconds = 0, lasts = HomeLawn.staysTidyFor(rng:NextNumber()) }
			entry.ages[target] = age
		end
		age.seconds += seconds
		if age.seconds < age.lasts then
			continue
		end
		local clear = true
		for _, position in roots do
			local offset = target.position - position
			if Vector2.new(offset.X, offset.Z).Magnitude < GROW_CLEARANCE then
				clear = false
				break
			end
		end
		if clear and entry.lawn:Regrow(target) then
			entry.ages[target] = nil
			grew = true
			if target.kind == "Grass" then
				table.insert(regrown, target.index)
			end
		end
	end
	if #regrown > 0 then
		entry.lawn:FireNearby("Regrow", regrown)
	end
	if grew then
		entry.tidy = entry.lawn:IsComplete()
		refresh(owner, entry)
	end
end

-- How a bit of work was done, from ToolService (see JobService's WorkOptions).
type WorkOptions = {
	quiet: boolean?,
	moving: boolean?,
	seconds: number?,
	ragged: boolean?,
	snip: boolean?,
	strikes: boolean?,
}

-- Who's working and how, as the lawn wants it (see LawnService's WorkContext).
local function workContext(player: Player, data, options: WorkOptions)
	return {
		protections = protectionsOf(player, data),
		holder = player,
		moving = options.moving,
		seconds = options.seconds,
		ragged = options.ragged,
		closest = options.snip,
		strikes = options.strikes,
	}
end

-- Tells the player what they need to know about a bit of work on their crew's lawn, and saves it
-- when something got finished (with a neighbor's tip when that made the lawn tidy). `snip` is a
-- snip of hand shears, and `trimmed` a shrub the same bit of work trimmed. Returns whether
-- anything got done, and the junk in the grass a mower just chewed up.
local function settle(
	player: Player,
	entry,
	result,
	options: WorkOptions,
	snip: boolean,
	trimmed: boolean
): (boolean, { any }?)
	local owner = leaderOf(player)
	if result.message then
		notify(player, result.message)
	end
	for _, debris in result.struck do
		notify(player, debris.kind.hit)
	end
	local warnedRecently = os.clock() - (warnedAt[player] or 0) <= 4
	if result.hurt and not warnedRecently then
		warnedAt[player] = os.clock()
		notify(player, HURT_MESSAGES[result.hurt] or "You need some protection for that.")
	elseif result.debris and not warnedRecently then
		warnedAt[player] = os.clock()
		notify(player, Debris.blockedMessage(result.debris.kind, snip))
	elseif result.blocked and not (result.changed or trimmed) and not options.quiet and not warnedRecently then
		warnedAt[player] = os.clock()
		notify(player, "That won't work here.")
	end
	if not result.changed or doneCount(entry.lawn) == entry.done then
		return result.changed or trimmed, result.struck
	end

	-- Something got finished: save it, and see whether the lawn's tidy now.
	refresh(owner, entry)
	local tidy = entry.lawn:IsComplete()
	if tidy and not entry.tidy then
		local ownerData = DataService:Get(owner)
		local now = os.time()
		local state = ownerData and savedState(ownerData)
		if state and state.tipReady and HomeLawn.tipDue(state.tippedAt, now) then
			state.tippedAt = now
			state.tipReady = false
			local tip = GameConfig.HomeLawn.TidyTip
			DataService:AddMoney(owner, tip)
			notify(owner, `Your lawn looks great! A neighbor tipped you {Format.money(tip)}.`)
		elseif owner == player then
			notify(player, "Your lawn looks great!")
		end
		if owner ~= player then
			notify(player, `{owner.DisplayName}'s lawn looks great!`)
		end
	end
	entry.tidy = tidy
	return true, result.struck
end

-- Public API ---------------------------------------------------------------------------------

-- True if the player's tool has work here: they're on their crew's home lawn, or it's a hedge
-- tool by one of the yard's overgrown shrubs.
function HomeLawnService:CanWork(player: Player, toolId: string): boolean
	if lawnUnder(player) then
		return true
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and DecorService:HasWorkNear(leaderOf(player), root.Position, toolId)
end

-- The curb appeal (0-100) of this owner's business.
function HomeLawnService:CurbAppeal(owner: Player): number
	local value = owner:GetAttribute("CurbAppeal")
	return if typeof(value) == "number" then value else 0
end

-- What the Best Yard judges look at on the owner's lawn (Config/Contest.luau): how much of its
-- grass, weeds and leaves is done and how much of its edge (each 0-1, every target weighted by
-- Lawn:WeightedProgress), and how many pieces of junk are in the grass. Nil if they have no lawn.
function HomeLawnService:YardMeasures(owner: Player): { lawnShare: number, edgeShare: number, junk: number }?
	local entry = lawns[owner]
	if not entry then
		return nil
	end
	local lawnDone, lawnTotal, edgeDone, edgeTotal = 0, 0, 0, 0
	for _, task in entry.lawn.tasks do
		local done, total = entry.lawn:WeightedProgress(task)
		if task.type.target == "Edge" then
			edgeDone += done
			edgeTotal += total
		else
			lawnDone += done
			lawnTotal += total
		end
	end
	return {
		lawnShare = if lawnTotal > 0 then lawnDone / lawnTotal else 1,
		edgeShare = if edgeTotal > 0 then edgeDone / edgeTotal else 1,
		junk = #entry.lawn.debris,
	}
end

-- Called by ToolService every tick a player uses a tool on their crew's home lawn (and for every
-- snip of hand shears), on everything but the grass, which mowers sweep (Sweep) and shears snip
-- (SnipAt). Takes the same options as JobService:ApplyWork, and says whether anything got done and
-- what junk in the grass a mower just chewed up.
function HomeLawnService:ApplyWork(
	player: Player,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number,
	options: WorkOptions
): (boolean, { any }?)
	local owner = leaderOf(player)
	local entry = lawnUnder(player)
	local data = DataService:Get(player)
	if not data then
		return false, nil
	end
	-- The yard's shrubs first: a hedge tool near one trims it.
	local trimmed, wrongTool = DecorService:Trim(owner, position, radius, toolId, amount)
	if not entry then
		if wrongTool and not trimmed and not options.quiet and os.clock() - (warnedAt[player] or 0) > 4 then
			warnedAt[player] = os.clock()
			notify(player, "That won't work here.")
		end
		return trimmed, nil
	end
	local result = entry.lawn:ApplyWork(position, radius, toolId, amount, workContext(player, data, options))
	return settle(player, entry, result, options, options.snip == true, trimmed)
end

-- Called by ToolService every tick a mower's deck, `halfWidth` studs either side, moves over their
-- crew's home lawn: from where it was last tick to where it is now, in world studs (see
-- Lawn:Sweep). Takes the same options as ApplyWork and returns the same, plus whether junk in the
-- grass stopped the deck short (only a mower that isn't motorized stops at it).
function HomeLawnService:Sweep(
	player: Player,
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	halfWidth: number,
	toolId: string,
	options: WorkOptions
): (boolean, { any }?, boolean)
	local entry = lawnUnder(player)
	local data = DataService:Get(player)
	if not (entry and data) then
		return false, nil, false
	end
	local result = entry.lawn:Sweep(fromX, fromZ, toX, toZ, halfWidth, toolId, workContext(player, data, options))
	local changed, struck = settle(player, entry, result, options, false, false)
	return changed, struck, result.debris ~= nil
end

-- Called by ToolService for every snip of hand shears on their crew's home lawn: the grass within
-- `radius` of (x, z), in world studs (see Lawn:SnipAt). Takes the same options as ApplyWork and
-- returns the same.
function HomeLawnService:SnipAt(
	player: Player,
	x: number,
	z: number,
	radius: number,
	toolId: string,
	options: WorkOptions
): (boolean, { any }?)
	local entry = lawnUnder(player)
	local data = DataService:Get(player)
	if not (entry and data) then
		return false, nil
	end
	local result = entry.lawn:SnipAt(x, z, radius, toolId, workContext(player, data, options))
	return settle(player, entry, result, options, true, false)
end

-- Picks up the junk in their crew's lawn that `thing` is part of, if it's within `reach` studs of
-- `from` (their eyes). It's never saved: a lawn rebuilt later hides its own.
function HomeLawnService:PickUpDebris(player: Player, thing: Instance, from: Vector3, reach: number): (boolean, string?)
	local entry = lawns[leaderOf(player)]
	if not entry then
		return false, nil
	end
	local debris, reason = entry.lawn:PickUpDebris(thing, from, reach)
	if not debris then
		return false, reason
	end
	return true, `Picked up the {debris.kind.name}.`
end

-- For testing in Studio (StudioTestService): the owner's whole lawn done at once, as if they'd
-- mown, edged, weeded and raked it all (and picked up the junk in the grass).
function HomeLawnService:TidyForTesting(owner: Player): boolean
	local entry = lawns[owner]
	if not entry then
		return false
	end
	for _, target in entry.targets do
		entry.lawn:Finish(target)
	end
	entry.tidy = entry.lawn:IsComplete()
	refresh(owner, entry)
	return true
end

-- Lifecycle ----------------------------------------------------------------------------------

function HomeLawnService:Init()
	folder = Instance.new("Folder")
	folder.Name = "HomeLawns"
	folder.Parent = workspace
end

function HomeLawnService:Start()
	-- A plot is (re)built when its owner joins or upgrades. The lawn stays put unless it moved.
	WorldService.PlotBuilt:Connect(function(owner)
		build(owner)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(build, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		destroy(player)
		warnedAt[player] = nil
		protectionCache[player] = nil
	end)
	-- Decorations placed, moved or trimmed change the curb appeal.
	DecorService.Changed:Connect(function(owner)
		local entry = lawns[owner]
		if entry then
			refresh(owner, entry)
		end
	end)

	-- It grows while its owner plays.
	while true do
		task.wait(GROW_TICK)
		for owner, entry in lawns do
			grow(owner, entry, GROW_TICK)
		end
	end
end

return HomeLawnService
