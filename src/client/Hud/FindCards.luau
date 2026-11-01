-- The cards for the Finds (docs/superpowers/plans/2026-11-01-busy-season-slice-3.md, Ruling 8): when
-- the server says you picked one up (FindPicked: its id, whether you kept it, and a note when you
-- gave it back), the Find chime and a toast with its card words ("Rare find: Silver Dollar" and its
-- story), and for a Rare or Legendary one a big moment too; when a set is complete (SetCompleted: its
-- id, name and perk words), a "Set complete!" moment with the set and its perk. UI.moment puts away
-- any moment already on the screen, so each card waits its turn behind the others: HudController
-- starts this (FindCards.start) with its afterTitleCard queue. It lives here and not in HudController
-- to keep that file's top level (at most 200 locals, see scripts/check-compile) where it was.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Finds = require(Shared.Config.Finds)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local UI = require(script.Parent.Parent.UI)

local FindCards = {}

-- The rarities that get a moment as well as the toast, and how long each moment stays.
local MOMENT_RARITIES = { Rare = true, Legendary = true }
local FIND_SECONDS = 3
local SET_SECONDS = 3.5

type Queue = (play: (info: any) -> (), info: any) -> ()

-- A Find you picked up: { id, kept, note? }.
local function showFind(info: { id: string, kept: boolean, note: string? })
	local find = Finds.get(info.id)
	local title, story = Finds.cardText(info.id)
	if not find or title == "" then
		return
	end
	Sounds.playUi("Find")
	if info.kept then
		UI.notify(`{title}. {story}`)
	else
		UI.notify(`{title}. You gave it back.` .. (if info.note then ` {info.note}` else ""))
	end
	if MOMENT_RARITIES[find.rarity] then
		UI.moment("Find", `{find.rarity} Find!`, find.name, FIND_SECONDS)
	end
end

-- A set you completed: { id, name, text }.
local function showSet(info: { id: string, name: string, text: string })
	UI.moment("SetComplete", "Set complete!", `{info.name}: {info.text}`, SET_SECONDS)
	Sounds.playUi("GoalDone")
end

-- Listens for both, playing each through `queue` (HudController's afterTitleCard).
function FindCards.start(queue: Queue)
	Net.event("FindPicked").OnClientEvent:Connect(function(info)
		if typeof(info) == "table" and typeof(info.id) == "string" then
			queue(showFind, info)
		end
	end)
	Net.event("SetCompleted").OnClientEvent:Connect(function(info)
		if typeof(info) == "table" and typeof(info.name) == "string" and typeof(info.text) == "string" then
			queue(showSet, info)
		end
	end)
end

return FindCards
