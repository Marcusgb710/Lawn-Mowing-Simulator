-- All RemoteEvents/RemoteFunctions live here so names are never mistyped.
-- The server creates them, the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- server -> client
	"ProfileUpdated",
	"JobUpdated",
	"JobBoardUpdated",
	"TravelStarted",
	"PullingOut",
	"PullOutCancelled",
	"TruckDrive",
	"PartyUpdated",
	"PartyInvite",
	"Notify",
	"StoryUpdated",
	"ContestUpdated",
	-- client -> server
	"AbandonJob",
	"LeaveParty",
	"StopService",
	"Snip",
	"SceneWatched",
	"ReadThread",
}

local FUNCTIONS = {
	"GetProfile",
	"GetJobBoard",
	"GetStory",
	"TalkToJune",
	"GetContest",
	"StartJudging",
	"CollectContest",
	"AcceptJob",
	"BuyItem",
	"SellItem",
	"EquipItem",
	"PickUpTool",
	"PutBackTool",
	"LoadTool",
	"UnloadTool",
	"PutInBucket",
	"TakeFromBucket",
	"ParkRide",
	"DriveToJob",
	"PickUpDebris",
	"OpenBox",
	"PlaceDecor",
	"MoveDecor",
	"CancelDecor",
	"ReturnDecor",
	"UseMailbox",
	"SetTruckPaint",
	"SetDownTool",
	"PickUpServiced",
	"StartService",
	"TakeSupply",
	"PutBackSupply",
	"InviteToParty",
	"RespondToInvite",
	"KickFromParty",
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Net = {}

function Net.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "Unknown RemoteEvent: " .. name)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), "Unknown RemoteFunction: " .. name)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
