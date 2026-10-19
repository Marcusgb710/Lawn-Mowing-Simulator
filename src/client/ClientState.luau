-- What the client knows about the game right now. Controllers read from here and
-- listen to `Changed` instead of each one listening to remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local ClientState = {
	profile = nil, -- money, xp, level, owned, equipped
	job = nil, -- the job you're on, or nil
	party = nil, -- { leader = Player, members = { Player } }
	board = {}, -- job board offers
	-- Fired with the name of what changed: "profile", "job", "party" or "board"
	Changed = Signal.new(),
}

function ClientState.set(key: string, value)
	ClientState[key] = value
	ClientState.Changed:Fire(key)
end

-- Your crew's business (the crew leader's, or yours when you're on your own), once it's built.
function ClientState.crewBusiness(): Model?
	local party = ClientState.party
	local leaderId = if party then party.leader.UserId else Players.LocalPlayer.UserId
	local businesses = workspace:FindFirstChild("Businesses")
	if not businesses then
		return nil
	end
	for _, business in businesses:GetChildren() do
		if business:IsA("Model") and business:GetAttribute("OwnerUserId") == leaderId then
			return business
		end
	end
	return nil
end

return ClientState
