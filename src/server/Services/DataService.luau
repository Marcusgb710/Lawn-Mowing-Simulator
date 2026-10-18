-- Loads and saves each player's money, xp and equipment.
--
-- To test saving in Studio: Game Settings > Security > "Enable Studio Access to API Services".
-- Without that, the game still runs but nothing is saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Storage = require(Shared.Config.Storage)

local DataService = {}

-- Bump this whenever the save format changes, and add a step to MIGRATIONS that turns the
-- previous version into the new one. Never delete a step: old saves still need it.
local DATA_VERSION = 8

-- MIGRATIONS[n] turns a version n - 1 save into version n. Steps must keep money, xp and every
-- owned item. Don't use the live config to read an old save: write down what it looked like.
local MIGRATIONS = {
	-- 1 -> 2, realistic tools (design phase A). Saves from before versioning have no `version`.
	-- Tools kept their ids and shop categories, so nothing moves; reconcile() below fills in any
	-- fields older saves are missing.
	[2] = function(_data) end,

	-- 2 -> 3, storage and truck space (design phase B). Every tool is now owned and carried on
	-- its own. A v2 save had one `equipped` tool per tool category, and `loadout[category]` was
	-- true if that tool was in the truck. Now `loadout[toolId]` is.
	[3] = function(data)
		data.owned = data.owned or {}
		data.equipped = data.equipped or {}
		local oldLoadout = data.loadout or {}
		local loadout = {}
		for _, category in { "Mower", "Trimmer", "Rake", "Edger", "HedgeTrimmer" } do
			local toolId = data.equipped[category]
			if toolId and oldLoadout[category] then
				loadout[toolId] = true
			end
			data.equipped[category] = nil
		end
		data.loadout = loadout

		-- Ride-on mowers only travel on an equipment trailer now. Anyone who already bought one gets
		-- the trailer free (hitched up if they had no trailer), so their mower still comes along.
		local mowers = data.owned.Mower or {}
		if mowers.RidingMower or mowers.ZeroTurnMower then
			data.owned.Trailer = data.owned.Trailer or {}
			data.owned.Trailer.EquipmentTrailer = true
			data.trailerUnlocked = true
			if not data.equipped.Trailer then
				data.equipped.Trailer = "EquipmentTrailer"
			end
		end
	end,

	-- 3 -> 4, maintenance (design phase E). Every owned tool gets a condition (fuel, tires, blade,
	-- line). reconcile() fills it in as good as new, so nobody's gear starts out worn.
	[4] = function(data)
		data.condition = if typeof(data.condition) == "table" then data.condition else {}
	end,

	-- 4 -> 5, loading by hand (Immersion). Tools now go in a storage spot you pick (`spots`), and
	-- hand tools go in the tool bucket one by one (`bucket`). A v4 bucket in the truck carried up
	-- to 8 of the hand tools in the truck, so those go in the bucket now and the load stays the same.
	[5] = function(data)
		data.spots = if typeof(data.spots) == "table" then data.spots else {}
		data.bucket = if typeof(data.bucket) == "table" then data.bucket else {}
		local loadout = if typeof(data.loadout) == "table" then data.loadout else {}
		if not loadout.ToolBucket then
			return
		end
		local count = 0
		-- The hand tools of the v4 catalog.
		for _, toolId in
			{
				"GardenShears",
				"HandHedgeShears",
				"HandTrowel",
				"HandTransplanter",
				"HandCultivator",
				"DandelionWeeder",
				"Dibber",
				"BypassPruners",
				"AnvilPruners",
				"FloralSnips",
				"WateringCan",
				"NitrileGloves",
				"PruningSaw",
				"ChemicalGloves",
				"SoilProbe",
			}
		do
			if loadout[toolId] and count < 8 then
				data.bucket[toolId] = true
				count += 1
			end
		end
	end,

	-- 5 -> 6, the shop as the hub. Orders arrive in a box (`deliveries`); everything bought before
	-- is already unpacked.
	[6] = function(data)
		data.deliveries = if typeof(data.deliveries) == "table" then data.deliveries else {}
	end,

	-- 6 -> 7, your business's own lawn (`homeLawn`, see HomeLawnService). It starts out
	-- overgrown, ready for its first mow.
	[7] = function(data)
		local saved = if typeof(data.homeLawn) == "table" then data.homeLawn else {}
		data.homeLawn = {
			done = if typeof(saved.done) == "table" then saved.done else {},
			tippedAt = if typeof(saved.tippedAt) == "number" then saved.tippedAt else 0,
			tipReady = if typeof(saved.tipReady) == "boolean" then saved.tipReady else true,
		}
	end,

	-- 7 -> 8, yard decorations (`decor`, see DecorService): none yet.
	[8] = function(data)
		local saved = if typeof(data.decor) == "table" then data.decor else {}
		data.decor = {
			placed = if typeof(saved.placed) == "table" then saved.placed else {},
			boxes = if typeof(saved.boxes) == "table" then saved.boxes else {},
		}
	end,
}

local store: DataStore? = nil
-- [Player] = { data = {...}, canSave = boolean }
local profiles = {}

local function defaultData()
	local data = {
		version = DATA_VERSION,
		money = GameConfig.StartingMoney,
		xp = 0,
		jobsCompleted = 0,
		-- [category] = { [itemId] = true } for every item they own, tools included
		owned = {},
		-- [category] = itemId for the truck, trailer and business they're using (not for tools)
		equipped = {},
		-- [toolId] = true for the tools sitting in their truck
		loadout = {},
		-- [toolId] = fuel, tires, blade and line of every owned tool (see Maintenance.luau)
		condition = {},
		-- [toolId] = which storage spot of its kind it goes back to (otherwise the first free one)
		spots = {},
		-- [toolId] = true for hand tools in their tool bucket (they go wherever the bucket goes)
		bucket = {},
		-- { key, id, arrives (os.time) } for every order still in its box (see DeliveryService)
		deliveries = {},
		-- Your own lawn: { done = { [task type] = "0110..." per target }, tippedAt = os.time() of
		-- the last tip for tidying it, tipReady = it's grown back enough since then for another }
		-- (see HomeLawnService)
		homeLawn = { done = {}, tippedAt = 0, tipReady = true },
		-- Decorations for your business's yard: `placed` ones ({ key, id, x, z, turn, overgrown,
		-- grown }) and ones still in their `boxes` ({ key, id, arrives }) (see DecorService)
		decor = { placed = {}, boxes = {} },
		trailerUnlocked = false,
	}
	for _, category in Items.Categories do
		data.owned[category] = {}
		local starter = Items.starter(category)
		if starter and not Items.isToolCategory(category) then
			data.owned[category][starter.id] = true
			data.equipped[category] = starter.id
		end
	end
	-- New players start with their free tools, and as many of them in the truck as fit.
	for _, tool in Items.starterTools() do
		data.owned[tool.category][tool.id] = true
		data.loadout[tool.id] = true
	end
	DataService.trimLoadout(data)
	DataService.reconcileCondition(data)
	return data
end

local function versionOf(saved): number
	return if typeof(saved) == "table" then tonumber(saved.version) or 1 else 1
end

-- Runs every migration step a save hasn't had yet.
local function migrate(data)
	local version = versionOf(data)
	while version < DATA_VERSION do
		version += 1
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		data.version = version
	end
	return data
end

-- Fills in anything missing from older saves, so adding new fields or categories never breaks old players.
local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	for _, category in Items.Categories do
		data.owned[category] = data.owned[category] or {}
	end
	for _, tool in Items.starterTools() do
		data.owned[tool.category][tool.id] = true
	end
	for _, category in Items.Categories do
		local owned = data.owned[category]
		if Items.isToolCategory(category) then
			-- Tools are never "equipped"; you pick which ones to load into the truck.
			data.equipped[category] = nil
			continue
		end
		local starter = Items.starter(category)
		if starter then
			owned[starter.id] = true
		end
		local equipped = data.equipped[category]
		if not (equipped and owned[equipped] and Items.get(category, equipped)) then
			-- Fall back to the best item they own in this category, if any.
			data.equipped[category] = nil
			for _, item in Items.Catalog[category] do
				if owned[item.id] then
					data.equipped[category] = item.id
				end
			end
		end
	end
	DataService.trimLoadout(data)
	DataService.reconcileCondition(data)
	return data
end

-- Gives every owned tool a condition (new ones start as good as new) and forgets sold ones.
function DataService.reconcileCondition(data)
	local condition = {}
	for _, tool in Items.ownedTools(data.owned) do
		condition[tool.id] = Maintenance.reconcile(tool, data.condition[tool.id])
	end
	data.condition = condition
end

-- Unloads tools that aren't owned anymore or don't fit in their own truck and trailer.
function DataService.trimLoadout(data)
	local owned = {}
	for _, tool in Items.ownedTools(data.owned) do
		owned[tool.id] = true
	end
	local ids = Storage.loadedIds(data.loadout)
	-- Load the bucket first, so the hand tools it carries don't count.
	local bucket = table.find(ids, Storage.BucketId)
	if bucket then
		table.insert(ids, 1, table.remove(ids, bucket))
	end

	local space, bays = Items.vehicleSpace(data.equipped)
	local kept = {}
	for _, id in ids do
		if owned[id] then
			table.insert(kept, id)
			local usedSpace, usedBays = Storage.load(kept, data.bucket)
			if usedSpace > space or usedBays > bays then
				table.remove(kept)
			end
		end
	end
	data.loadout = {}
	for _, id in kept do
		data.loadout[id] = true
	end
	DataService.reconcileStorage(data)
end

-- Forgets storage spots and bucket places of tools they don't own anymore, and keeps the tools
-- in the bucket wherever the bucket is: in the truck exactly when it is.
function DataService.reconcileStorage(data)
	local owned = {}
	for _, tool in Items.ownedTools(data.owned) do
		owned[tool.id] = tool
	end
	data.spots = if typeof(data.spots) == "table" then data.spots else {}
	data.bucket = if typeof(data.bucket) == "table" then data.bucket else {}
	-- Boxes for things they don't own anymore (or broken entries) go away.
	local deliveries = {}
	local saved = if typeof(data.deliveries) == "table" then data.deliveries else {}
	for _, delivery in saved do
		if
			typeof(delivery) == "table"
			and typeof(delivery.id) == "string"
			and owned[delivery.id]
			and typeof(delivery.key) == "number"
			and typeof(delivery.arrives) == "number"
		then
			table.insert(deliveries, delivery)
		end
	end
	data.deliveries = deliveries
	for id in data.spots do
		if not owned[id] then
			data.spots[id] = nil
		end
	end
	local hasBucket = owned[Storage.BucketId] ~= nil
	local count = 0
	for id in data.bucket do
		local tool = owned[id]
		if not (hasBucket and tool and tool.sizeClass == "Hand") or count >= Storage.BucketHolds then
			data.bucket[id] = nil
		else
			count += 1
		end
	end
	local bucketLoaded = data.loadout[Storage.BucketId] ~= nil
	for id in data.bucket do
		data.loadout[id] = if bucketLoaded then true else nil
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function load(player: Player)
	if not store then
		return defaultData(), false
	end

	for attempt = 1, 3 do
		local ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			-- A save from a newer version of the game (say, during a rollback) is played as-is,
			-- but never overwritten with the older format.
			local newer = versionOf(result) > DATA_VERSION
			local migrated, data = pcall(function()
				if result ~= nil and typeof(result) ~= "table" then
					error("the save isn't a table")
				end
				return reconcile(if newer then result else migrate(result or defaultData()))
			end)
			if migrated then
				if newer then
					warn(`{player.Name}'s save is from a newer version; not saving it this session`)
				end
				return data, not newer
			end
			-- Something in their save didn't fit; leave it untouched rather than risk losing it.
			warn(`Couldn't migrate data for {player.Name}: {data}`)
			break
		end
		warn(`Couldn't load data for {player.Name} (attempt {attempt}): {result}`)
		if string.find(tostring(result), "StudioAccessToApisNotAllowed") then
			break
		end
		task.wait(attempt * 2)
	end

	-- We couldn't read their save, so never write over it this session.
	return defaultData(), false
end

local function save(player: Player)
	local profile = profiles[player]
	if not (profile and profile.canSave and store) then
		return
	end
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function(stored)
		-- Never write the older format over a save from a newer version of the game.
		if versionOf(stored) > DATA_VERSION then
			return nil
		end
		return profile.data, { player.UserId }
	end)
	if not ok then
		warn(`Couldn't save data for {player.Name}: {err}`)
	end
end

local function snapshot(data)
	local space, bays = Items.vehicleSpace(data.equipped)
	local usedSpace, usedBays = Storage.load(Storage.loadedIds(data.loadout), data.bucket)
	return {
		money = data.money,
		xp = data.xp,
		level = GameConfig.levelFromXp(data.xp),
		jobsCompleted = data.jobsCompleted,
		owned = data.owned,
		equipped = data.equipped,
		loadout = data.loadout,
		condition = data.condition,
		spots = data.spots,
		bucket = data.bucket,
		deliveries = data.deliveries,
		-- Their own truck and trailer (in a crew, PartyUpdated has the leader's truck instead).
		truck = { used = usedSpace, space = space, baysUsed = usedBays, bays = bays },
		trailerUnlocked = data.trailerUnlocked,
	}
end

local function createLeaderstats(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = data.money
	money.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = GameConfig.levelFromXp(data.xp)
	level.Parent = leaderstats

	leaderstats.Parent = player
end

local function onPlayerAdded(player: Player)
	local loaded, data, canSave = pcall(load, player)
	if not loaded then
		-- Always give them a profile so nothing waits on it forever, but don't save it.
		warn(`Couldn't load data for {player.Name}: {data}`)
		data, canSave = defaultData(), false
	end
	if player.Parent ~= Players then
		return
	end
	profiles[player] = { data = data, canSave = canSave }
	createLeaderstats(player, data)
	DataService:Changed(player)
end

-- Public API ---------------------------------------------------------------------------------

function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService:WaitForData(player: Player)
	while not profiles[player] and player.Parent == Players do
		task.wait(0.1)
	end
	return self:Get(player)
end

-- Call after changing a player's data so leaderstats and their UI update.
function DataService:Changed(player: Player)
	local data = self:Get(player)
	if not data then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Money.Value = data.money
		leaderstats.Level.Value = GameConfig.levelFromXp(data.xp)
	end
	Net.event("ProfileUpdated"):FireClient(player, snapshot(data))
end

function DataService:GetLevel(player: Player): number
	local data = self:Get(player)
	return data and GameConfig.levelFromXp(data.xp) or 1
end

function DataService:AddMoney(player: Player, amount: number)
	local data = self:Get(player)
	if data then
		data.money += amount
		self:Changed(player)
	end
end

function DataService:TrySpend(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or data.money < amount then
		return false
	end
	data.money -= amount
	self:Changed(player)
	return true
end

function DataService:RecordJob(player: Player, xp: number)
	local data = self:Get(player)
	if not data then
		return
	end
	local oldLevel = GameConfig.levelFromXp(data.xp)
	data.xp += xp
	data.jobsCompleted += 1
	self:Changed(player)

	local newLevel = GameConfig.levelFromXp(data.xp)
	if newLevel > oldLevel then
		Net.event("Notify"):FireClient(player, `Level up! You're now level {newLevel}.`)
	end
end

-- Lifecycle ----------------------------------------------------------------------------------

function DataService:Init()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, GameConfig.DataStoreName)
	if ok then
		store = result
	else
		warn("DataStores unavailable, progress won't save: " .. tostring(result))
	end

	Net.func("GetProfile").OnServerInvoke = function(player)
		local data = self:WaitForData(player)
		return data and snapshot(data)
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(GameConfig.AutosaveInterval)
		for player in profiles do
			task.spawn(save, player)
		end
	end
end

return DataService
