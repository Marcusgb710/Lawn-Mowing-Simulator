-- Crews of 1 to 4 players. Everyone is always in a crew; playing solo is just a crew of one.
-- The crew hangs out at the leader's business and rides in the leader's truck, so everyone's
-- loaded tools share that one truck (and its trailer). The leader accepts jobs and drives.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Storage = require(Shared.Config.Storage)

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local INVITE_TIMEOUT = 30

local PartyService = {}
-- Fired with (party, player, wasLeader) after a player leaves a crew.
PartyService.MemberLeft = Signal.new()
-- Fired with (party, player) after a player joins someone else's crew.
PartyService.MemberJoined = Signal.new()
-- Fired with (party) whenever a crew's members or leader change.
PartyService.Changed = Signal.new()

-- [Player] = party, where party = { leader = Player, members = { Player } }
local parties = {}
-- [invitee] = { [inviter] = expiry time }
local invites = {}

local isBusy = function(_player: Player): boolean
	return false
end

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

-- How much space the crew's tools take in the leader's truck and how much it has, then the same
-- for ride-on bays on the leader's trailer.
local function truckLoad(party): (number, number, number, number)
	local used, baysUsed = 0, 0
	for _, member in party.members do
		local data = DataService:Get(member)
		if data then
			local space, bays = Storage.load(Storage.loadedIds(data.loadout))
			used += space
			baysUsed += bays
		end
	end
	local leaderData = DataService:Get(party.leader)
	if not leaderData then
		return used, 0, baysUsed, 0
	end
	local capacity, bays = Items.vehicleSpace(leaderData.equipped)
	return used, capacity, baysUsed, bays
end

local function broadcast(party)
	local used, capacity, baysUsed, bays = truckLoad(party)
	local payload = {
		leader = party.leader,
		members = party.members,
		truck = { used = used, space = capacity, baysUsed = baysUsed, bays = bays },
	}
	for _, member in party.members do
		Net.event("PartyUpdated"):FireClient(member, payload)
	end
	PartyService.Changed:Fire(party)
end

local function newParty(player: Player)
	local party = { leader = player, members = { player } }
	parties[player] = party
	return party
end

local function removeFromParty(player: Player)
	local party = parties[player]
	if not party then
		return
	end
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	parties[player] = nil
	local wasLeader = party.leader == player
	if wasLeader and #party.members > 0 then
		party.leader = party.members[1]
		notify(party.leader, "You're the crew leader now. The crew moved to your business.")
	end
	PartyService.MemberLeft:Fire(party, player, wasLeader)
	if #party.members > 0 then
		broadcast(party)
	end
end

local function isPlayer(value): boolean
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

-- Public API ---------------------------------------------------------------------------------

function PartyService:GetParty(player: Player)
	return parties[player]
end

-- Space used, space, bays used and bays in the truck this player's crew rides in.
function PartyService:GetTruckLoad(player: Player): (number, number, number, number)
	return truckLoad(parties[player] or { leader = player, members = { player } })
end

-- Re-sends crew info (like truck space) after something about a member changed.
function PartyService:Refresh(player: Player)
	local party = parties[player]
	if party then
		broadcast(party)
	end
end

-- JobService uses this to stop crews changing mid-job.
function PartyService:SetBusyCheck(check: (Player) -> boolean)
	isBusy = check
end

function PartyService:Leave(player: Player)
	local party = parties[player]
	if not party or #party.members <= 1 then
		return
	end
	removeFromParty(player)
	broadcast(newParty(player))
end

function PartyService:Invite(from: Player, target: Player): (boolean, string)
	if not isPlayer(target) or target == from then
		return false, "You can't invite that player."
	end
	local party = parties[from]
	if not party or party.leader ~= from then
		return false, "Only the crew leader can invite people."
	end
	if #party.members >= GameConfig.MaxCrewSize then
		return false, "Your crew is full."
	end
	if isBusy(from) then
		return false, "Finish your current job first."
	end
	local targetParty = parties[target]
	if targetParty and #targetParty.members > 1 then
		return false, `{target.DisplayName} is already in a crew.`
	end

	invites[target] = invites[target] or {}
	local pending = invites[target][from]
	if pending and os.clock() < pending then
		return false, `You already invited {target.DisplayName}.`
	end
	invites[target][from] = os.clock() + INVITE_TIMEOUT
	Net.event("PartyInvite"):FireClient(target, from, INVITE_TIMEOUT)
	return true, `Invite sent to {target.DisplayName}.`
end

function PartyService:Respond(target: Player, from: Player, accept: boolean): (boolean, string)
	local pending = invites[target]
	local expires = pending and pending[from]
	if pending then
		pending[from] = nil
	end
	if not expires or os.clock() > expires or not isPlayer(from) then
		return false, "That invite expired."
	end
	if not accept then
		notify(from, `{target.DisplayName} said no to your invite.`)
		return true, "Invite declined."
	end

	local party = parties[from]
	if not party or party.leader ~= from then
		return false, "That crew doesn't exist anymore."
	end
	if #party.members >= GameConfig.MaxCrewSize then
		return false, "That crew is full."
	end
	if isBusy(from) or isBusy(target) then
		return false, "You can't join while a job is in progress."
	end

	local current = parties[target]
	if current == party then
		return true, "You're already in that crew."
	end
	if current then
		removeFromParty(target)
	end
	invites[target] = nil
	table.insert(party.members, target)
	parties[target] = party
	broadcast(party)
	PartyService.MemberJoined:Fire(party, target)
	return true, `You joined {from.DisplayName}'s crew!`
end

function PartyService:Kick(leader: Player, target: Player): (boolean, string)
	local party = parties[leader]
	if not party or party.leader ~= leader then
		return false, "Only the crew leader can kick people."
	end
	if target == leader or parties[target] ~= party then
		return false, "That player isn't in your crew."
	end
	self:Leave(target)
	notify(target, "You were removed from the crew.")
	return true, `{target.DisplayName} was removed from the crew.`
end

-- Lifecycle ----------------------------------------------------------------------------------

function PartyService:Init()
	WorldService:SetLeaderLookup(function(player)
		local party = parties[player]
		return if party then party.leader else player
	end)

	Net.func("InviteToParty").OnServerInvoke = function(player, target)
		return self:Invite(player, target)
	end
	Net.func("RespondToInvite").OnServerInvoke = function(player, from, accept)
		return self:Respond(player, from, accept == true)
	end
	Net.func("KickFromParty").OnServerInvoke = function(player, target)
		return self:Kick(player, target)
	end
	Net.event("LeaveParty").OnServerEvent:Connect(function(player)
		self:Leave(player)
	end)
end

function PartyService:Start()
	local function onPlayerAdded(player: Player)
		if not parties[player] then
			broadcast(newParty(player))
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		removeFromParty(player)
		invites[player] = nil
		for _, pending in invites do
			pending[player] = nil
		end
	end)
end

return PartyService
