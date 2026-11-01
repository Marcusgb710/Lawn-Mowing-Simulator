-- Buster, the dog a player gets at level 5 (Config/Levels.luau; SeasonService gives him and tells this
-- service, Refresh). One per owner, built and moved on the server so everyone sees him, with his name
-- (their save's `buster.name`) on a billboard over him. Where he is:
--   at the business   he sits on the ground beside Grandma June's porch, on its far side from the
--                     driveway (WorldService:GetBusterSpot), clear of the doorway, the desk, the finds
--                     shelf and the workbench, which are all on the driveway's other side or left of the
--                     building.
--   in the truck      while the owner rides (JobService:IsBusy with no lawn to be on) he isn't anywhere:
--                     the drive's cutscene shows him in the truck's bed instead (info.buster, from the
--                     driver's save).
--   on a job          while their job is Working and they are on its lawn, he runs between grass cells by
--                     short tweens, one at a time with a rest between. Never to a cell within 6 studs of a
--                     player with a motor mower out, nor by a way that passes closer to one, nor across
--                     ground that isn't grass (DogWalk, Lawn:OpenGround), and he runs off when one comes
--                     near. Once a job, a little after he gets there, if the lawn still hides its Find he
--                     trots over, sits by it, barks (Sounds.Ids.Bark) and marks it BusterFound, which
--                     the lawn map dots in gold. A Find gone before or while he goes (picked up or chewed)
--                     just leaves him to carry on. Once the job is done he sits until they head home.
-- One loop per owner (task.spawn and task.wait steps, never every frame) decides where he should be. It
-- stops, and his model goes, when they leave the game or no longer own him (a Studio reset). Each step
-- is in a pcall: anything going wrong in it is a warning, and the next step starts afresh.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local DogWalk = require(Shared.DogWalk)
local Sounds = require(Shared.Sounds)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local JobService = require(script.Parent.JobService)
local WorldService = require(script.Parent.WorldService)

-- How often the loop looks again while he sits, in seconds, and while he runs or rests on a job.
local HOME_TICK = 1
local JOB_TICK = 0.25
-- How fast he runs between cells, and how fast he trots to the Find, in studs a second.
local RUN_SPEED = 7
local TROT_SPEED = 10
-- One run on a job is this many studs, at least and at most; he rests this long between runs.
local SHORTEST_RUN, LONGEST_RUN = 3, 14
local REST_MIN, REST_MAX = 1.5, 4
-- How many of the lawn's cells he looks at for each run (a random handful, so a big lawn costs no more).
local CELLS_TRIED = 300
-- He goes to the Find this long after he gets to the lawn, sits this far from it, stays this long, and
-- tries again this long after a way there that wasn't clear, up to FIND_TRIES times.
local SNIFF_DELAY = 8
local SNIFF_BESIDE = 1.2
local SNIFF_SIT = 3
local SNIFF_RETRY = 3
local FIND_TRIES = 10
-- Off the lawn for this long (a respawn lands them in town for a moment), he goes home.
local OFF_LAWN_GRACE = 3
-- How far out from the lawn's edges they still count as on it (the sidewalk and the truck at the curb).
local LAWN_MARGIN = 30
-- Sitting, his nose tips up this much.
local SIT_TILT = math.rad(15)
-- His name shows from this far away, this high over his middle.
local NAME_DISTANCE = 40
local NAME_RISE = 2.4

local CompanionService = {}

type Dog = {
	owner: Player,
	model: Model,
	label: TextLabel,
	value: CFrameValue,
	tween: Tween?,
	alive: boolean,
	sitting: boolean,
	-- Where his origin is, on the ground, facing the way he faces.
	ground: CFrame,
	-- The spot at the business he was last put on, the lawn he is on, and when he left it.
	homeSpot: CFrame?,
	lawn: any?,
	offSince: number?,
	-- This lawn's grass cells as a list, the last lawn he got to, whether he has been to its Find, when
	-- he goes, and how often the way there wasn't clear.
	cells: { Vector3 },
	visited: any?,
	sniffed: boolean,
	sniffAt: number,
	findTries: number,
	rng: Random,
}

-- [Player] = their dog.
local dogs: { [Player]: Dog } = {}
local folder: Folder? = nil

-- Workspace's Companions folder, made the first time a dog wants it.
local function companions(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "Companions"
	made.Parent = workspace
	folder = made
	return made
end

local function ownsBuster(player: Player): boolean
	local data = DataService:Get(player)
	return data ~= nil and typeof(data.buster) == "table" and data.buster.owned == true
end

local function nameOf(player: Player): string
	local data = DataService:Get(player)
	local name = data and typeof(data.buster) == "table" and data.buster.name
	return if typeof(name) == "string" and name ~= "" then name else "Buster"
end

-- Where every player holding a motor mower stands (a Mower that is motorized, out in their hands).
local function mowerSpots(): { Vector3 }
	local spots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local tool = character and character:FindFirstChildOfClass("Tool")
		local itemId = tool and tool:GetAttribute("ItemId")
		local item = if typeof(itemId) == "string" then Tools.get(itemId) else nil
		if root and root:IsA("BasePart") and item and item.category == "Mower" and item.motorized == true then
			table.insert(spots, root.Position)
		end
	end
	return spots
end

-- His model --------------------------------------------------------------------------------------

local function build(owner: Player): (Model, TextLabel)
	local model = Assets.prop("Buster")
	Assets.anchor(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model.Name = "Buster"
	model:SetAttribute("OwnerUserId", owner.UserId)
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(160, 26)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, NAME_RISE, 0)
	billboard.MaxDistance = NAME_DISTANCE
	billboard.LightInfluence = 0
	billboard.Adornee = holder
	billboard.Parent = holder or model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = nameOf(owner)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	return model, label
end

-- Puts him where his ground frame says, sitting (nose up) or standing.
local function show(dog: Dog)
	local frame = dog.ground
	Assets.placeAt(dog.model, if dog.sitting then frame * CFrame.Angles(SIT_TILT, 0, 0) else frame)
end

local function stop(dog: Dog)
	local tween = dog.tween
	dog.tween = nil
	if tween then
		tween:Cancel()
	end
end

-- Stands him at `ground` at once.
local function place(dog: Dog, ground: CFrame, sitting: boolean)
	stop(dog)
	dog.sitting = sitting
	dog.ground = ground
	dog.value.Value = ground
	show(dog)
end

-- Turns him toward `to` and starts him running there at `speed`. Returns how long it takes.
local function runTo(dog: Dog, to: Vector3, speed: number): number
	local from = dog.ground.Position
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.05 then
		return 0
	end
	local facing = CFrame.lookAt(from, from + flat)
	place(dog, facing, false)
	local seconds = flat.Magnitude / speed
	local tween = TweenService:Create(
		dog.value,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Value = facing.Rotation + to }
	)
	dog.tween = tween
	tween:Play()
	return seconds
end

-- Where the owner should have him: the lawn of their job while they're on it (and whether it is still
-- being worked), or nil at the business. A job that is Working or Complete counts while they are on or
-- near its lawn, or have no character to tell (respawning), and for OFF_LAWN_GRACE seconds after they
-- were last there.
local function jobLawn(dog: Dog): (any?, boolean)
	local job = JobService:GetJob(dog.owner)
	local lawn = job and job.lawn
	if not (lawn and (job.state == "Working" or job.state == "Complete")) then
		dog.offSince = nil
		return nil, false
	end
	local character = dog.owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local on = true
	if root and root:IsA("BasePart") then
		local offset = root.Position - lawn.origin
		on = offset.X >= -LAWN_MARGIN
			and offset.X <= lawn.width + LAWN_MARGIN
			and offset.Z >= -LAWN_MARGIN
			and offset.Z <= lawn.depth + LAWN_MARGIN
	end
	if on then
		dog.offSince = nil
	elseif not dog.offSince then
		dog.offSince = os.clock()
	end
	if dog.offSince and os.clock() - dog.offSince > OFF_LAWN_GRACE then
		return nil, false
	end
	return lawn, job.state == "Working"
end

-- Waits `seconds` in JOB_TICK steps while he runs or rests on `lawn`. Stops him and returns false as
-- soon as he should be somewhere else, a motor mower comes within reach of him, or `still` (if given)
-- says what he's doing is off. Already in a mower's reach as it starts (he is running off), only a
-- mower that catches him again once he's clear stops him.
local function hold(dog: Dog, seconds: number, lawn: any, still: (() -> boolean)?): boolean
	local deadline = os.clock() + seconds
	local wasClear = DogWalk.clearOf(dog.ground.Position, mowerSpots(), DogWalk.KEEP_AWAY)
	repeat
		task.wait(math.min(JOB_TICK, math.max(deadline - os.clock(), 0)))
		local clear = DogWalk.clearOf(dog.ground.Position, mowerSpots(), DogWalk.KEEP_AWAY)
		if not dog.alive or jobLawn(dog) ~= lawn or (wasClear and not clear) or (still and not still()) then
			stop(dog)
			return false
		end
		wasClear = wasClear or clear
	until os.clock() >= deadline
	return true
end

-- The ground he may walk on, as DogWalk.pick wants it.
local function options(lawn: any): DogWalk.Options
	return {
		keep = DogWalk.KEEP_AWAY,
		shortest = SHORTEST_RUN,
		longest = LONGEST_RUN,
		walkable = function(point)
			return lawn:IsOpenGround(point)
		end,
	}
end

-- A random handful of the lawn's cells, at most CELLS_TRIED.
local function someCells(dog: Dog): { Vector3 }
	local cells = dog.cells
	if #cells <= CELLS_TRIED then
		return cells
	end
	local some = table.create(CELLS_TRIED)
	for index = 1, CELLS_TRIED do
		some[index] = cells[dog.rng:NextInteger(1, #cells)]
	end
	return some
end

-- At home ----------------------------------------------------------------------------------------

-- Sits him on his spot at the business, or puts him away while there's no spot (no business built).
local function sitAtHome(dog: Dog)
	local spot = WorldService:GetBusterSpot(dog.owner)
	if not spot then
		stop(dog)
		dog.homeSpot = nil
		dog.model.Parent = nil
		return
	end
	if dog.homeSpot ~= spot or dog.model.Parent == nil then
		place(dog, spot, true)
		dog.homeSpot = spot
		dog.model.Parent = companions()
	end
end

-- Away while the owner rides in the truck.
local function putAway(dog: Dog)
	stop(dog)
	dog.homeSpot = nil
	dog.model.Parent = nil
end

-- On a job ---------------------------------------------------------------------------------------

-- Just got to `lawn`: he jumps down on the grass cell nearest where the crew gets out (clear of any
-- mower), and goes to the Find a little later.
local function arrive(dog: Dog, lawn: any)
	dog.homeSpot = nil
	dog.cells = {}
	for _, center in lawn:OpenGround() do
		table.insert(dog.cells, center)
	end
	-- Back on the same lawn (after a respawn took them off it for a while), the Find is still done with.
	if dog.visited ~= lawn then
		dog.visited = lawn
		dog.sniffed, dog.sniffAt, dog.findTries = false, os.clock() + SNIFF_DELAY, 0
	end
	local door = lawn.spawnCFrame.Position
	local mowers = mowerSpots()
	local best, bestDistance = nil, math.huge
	for _, cell in dog.cells do
		local distance = (Vector3.new(cell.X, door.Y, cell.Z) - door).Magnitude
		if distance < bestDistance and DogWalk.clearOf(cell, mowers, DogWalk.KEEP_AWAY) then
			best, bestDistance = cell, distance
		end
	end
	if not best then
		-- No grass to run on, or every bit of it near a mower: he waits out of sight until there is.
		putAway(dog)
		dog.lawn = nil
		return
	end
	place(dog, CFrame.lookAt(best, best + (lawn.spawnCFrame.LookVector * Vector3.new(1, 0, 1))), false)
	dog.model.Parent = companions()
end

-- Once a job: trots to the lawn's Find, sits by it, barks and marks it. If it's gone already, or goes
-- while he's on his way, he just carries on.
local function sniff(dog: Dog, lawn: any)
	local find = lawn.find
	if not find then
		dog.sniffed = true
		return
	end
	local from = dog.ground.Position
	local away = Vector3.new(from.X - find.position.X, 0, from.Z - find.position.Z)
	local beside = find.position + (if away.Magnitude > 0.05 then away.Unit else Vector3.zAxis) * SNIFF_BESIDE
	local mowers = mowerSpots()
	local clear = DogWalk.clearOf(beside, mowers, DogWalk.KEEP_AWAY)
		and DogWalk.pathClear(from, beside, mowers, DogWalk.KEEP_AWAY)
		and lawn:IsOpenGround(beside)
	if not clear then
		-- Not now: he runs about some more and tries again in a bit, up to FIND_TRIES times.
		dog.findTries += 1
		dog.sniffed = dog.findTries >= FIND_TRIES
		dog.sniffAt = os.clock() + SNIFF_RETRY
		return
	end
	dog.sniffed = true
	local function stillThere()
		return lawn.find == find and find.model.Parent ~= nil
	end
	if not hold(dog, runTo(dog, beside, TROT_SPEED), lawn, stillThere) then
		return
	end
	-- Sits facing it, nose up, and barks.
	local look = Vector3.new(find.position.X, beside.Y, find.position.Z)
	place(dog, CFrame.lookAt(beside, if (look - beside).Magnitude > 0.05 then look else beside - Vector3.zAxis), true)
	local voice = dog.model.PrimaryPart or dog.model:FindFirstChildWhichIsA("BasePart", true)
	if voice then
		Sounds.play(voice, "Bark")
	end
	find.model:SetAttribute("BusterFound", true)
	hold(dog, SNIFF_SIT, lawn)
end

-- One short run to a cell nearby (or away from a mower that came near), then a rest.
local function wander(dog: Dog, lawn: any)
	local cell = DogWalk.pick(someCells(dog), dog.ground.Position, mowerSpots(), options(lawn), function()
		return dog.rng:NextNumber()
	end)
	if cell and not hold(dog, runTo(dog, cell, RUN_SPEED), lawn) then
		return
	end
	-- Now and then he sits for his rest.
	if dog.rng:NextNumber() < 0.4 then
		place(dog, dog.ground, true)
	end
	hold(dog, dog.rng:NextNumber(REST_MIN, REST_MAX), lawn)
end

-- The loop ---------------------------------------------------------------------------------------

local function step(dog: Dog)
	if not ownsBuster(dog.owner) then
		CompanionService:Remove(dog.owner)
		return
	end
	local name = nameOf(dog.owner)
	if dog.label.Text ~= name then
		dog.label.Text = name
	end
	local lawn, working = jobLawn(dog)
	if lawn ~= dog.lawn then
		stop(dog)
		dog.lawn = lawn
		if lawn then
			arrive(dog, lawn)
			lawn = dog.lawn
		end
	end
	if not lawn then
		if JobService:IsBusy(dog.owner) then
			putAway(dog)
		else
			sitAtHome(dog)
		end
		task.wait(HOME_TICK)
	elseif not working then
		-- The job's done: he sits where he is until they head home.
		if not dog.sitting then
			place(dog, dog.ground, true)
		end
		task.wait(JOB_TICK)
	elseif not dog.sniffed and os.clock() >= dog.sniffAt then
		sniff(dog, lawn)
	else
		wander(dog, lawn)
	end
end

local function live(dog: Dog)
	while dog.alive do
		local ok, err = pcall(step, dog)
		if not ok then
			warn(`CompanionService: Buster's step failed for {dog.owner.Name}: {err}`)
			if dog.alive then
				stop(dog)
				dog.lawn = nil
				dog.homeSpot = nil
			end
			task.wait(HOME_TICK)
		end
	end
end

-- Public API -------------------------------------------------------------------------------------

-- Builds their Buster if they own him and don't have him yet (SeasonService calls this when level 5
-- gives him, and on join), or takes him away if they no longer own him. Safe to call any time.
function CompanionService:Refresh(player: Player)
	if player.Parent ~= Players then
		return
	end
	if not ownsBuster(player) then
		self:Remove(player)
		return
	end
	local dog = dogs[player]
	if dog then
		dog.label.Text = nameOf(player)
		return
	end
	local model, label = build(player)
	local value = Instance.new("CFrameValue")
	local made: Dog = {
		owner = player,
		model = model,
		label = label,
		value = value,
		tween = nil,
		alive = true,
		sitting = true,
		ground = CFrame.identity,
		homeSpot = nil,
		lawn = nil,
		offSince = nil,
		cells = {},
		visited = nil,
		sniffed = true,
		sniffAt = 0,
		findTries = 0,
		rng = Random.new(),
	}
	-- A run tweens the value; he follows it.
	value.Changed:Connect(function(frame)
		if made.alive then
			made.ground = frame
			show(made)
		end
	end)
	dogs[player] = made
	task.spawn(live, made)
end

-- Stops their Buster's loop and takes his model away (they left, or no longer own him).
function CompanionService:Remove(player: Player)
	local dog = dogs[player]
	if not dog then
		return
	end
	dogs[player] = nil
	dog.alive = false
	stop(dog)
	dog.model:Destroy()
	dog.value:Destroy()
end

-- Lifecycle --------------------------------------------------------------------------------------

function CompanionService:Init()
	Players.PlayerRemoving:Connect(function(player)
		self:Remove(player)
	end)
	-- A rebuilt business (an upgrade) can move June's porch: the loop puts him back on his new spot.
	WorldService.PlotBuilt:Connect(function(owner)
		local dog = dogs[owner]
		if dog then
			dog.homeSpot = nil
		end
	end)
end

return CompanionService
