-- What the client knows about the game right now. Controllers read from here and
-- listen to `Changed` instead of each one listening to remotes.

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

return ClientState
