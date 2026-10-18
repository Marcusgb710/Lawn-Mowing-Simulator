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
local Net = require(Shared.Net)

local DataService = {}

-- Bump this whenever the save format changes, and add a step to MIGRATIONS that turns the
-- previous version into the new one. Never delete a step: old saves still need it.
local DATA_VERSION = 2

-- MIGRATIONS[n] turns a version n - 1 save into version n. Steps must keep money, xp and every
-- owned item.
local MIGRATIONS = {
	-- 1 -> 2, realistic tools (design phase A). Saves from before versioning have no `version`.
	-- Tools kept their ids and shop categories, so nothing moves; reconcile() below fills in any
	-- fields older saves are missing. Phase B (per-tool storage) will be step 3.
	[2] = function(_data) end,
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
		-- [category] = { [itemId] = true }
		owned = {},
		-- [category] = itemId, or nil if they own nothing in that category yet
		equipped = {},
		-- [tool category] = true for the tools sitting in their truck bed
		loadout = {},
		trailerUnlocked = false,
	}
	for _, category in Items.Categories do
		local starter = Items.starter(category)
		data.owned[category] = {}
		if starter then
			data.owned[category][starter.id] = true
			data.equipped[category] = starter.id
		end
	end
	for _, category in Items.ToolCategories do
		if data.equipped[category] then
			data.loadout[category] = true
		end
	end
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
		local owned = data.owned[category] or {}
		data.owned[category] = owned
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
	return data
end

-- Unloads tools that aren't owned or don't fit in the truck bed anymore.
function DataService.trimLoadout(data)
	local capacity = Items.bedCapacity(data.equipped)
	local kept = 0
	for _, category in Items.ToolCategories do
		if data.loadout[category] then
			if data.equipped[category] and kept < capacity then
				kept += 1
			else
				data.loadout[category] = nil
			end
		end
	end
	for category in data.loadout do
		if not table.find(Items.ToolCategories, category) then
			data.loadout[category] = nil
		end
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
	return {
		money = data.money,
		xp = data.xp,
		level = GameConfig.levelFromXp(data.xp),
		jobsCompleted = data.jobsCompleted,
		owned = data.owned,
		equipped = data.equipped,
		loadout = data.loadout,
		bedCapacity = Items.bedCapacity(data.equipped),
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
