-- Client entry point. Hooks remotes up to ClientState, then starts every controller.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local started = os.clock()

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local ClientState = require(script.ClientState)
local UI = require(script.UI)

local Controllers = script:WaitForChild("Controllers")
local CONTROLLERS = {
	"CameraController",
	"HudController",
	"LevelsController",
	"ContractsController",
	"JobBoardController",
	"ShopController",
	"TruckController",
	"GuideController",
	"DialogueController",
	"MessagesController",
	"GloriaController",
	"ContestController",
	"LeaderboardController",
	"TopLawnsController",
	"SettingsController",
	"TutorialController",
	"CarryController",
	"ComputerController",
	"InteractController",
	"DecorController",
	"GrassController",
	"ToolFxController",
	"EngineAudioController",
	"ArmsController",
	"SnipController",
	"PartyController",
	"CutsceneController",
	"StudioTestController",
}

Net.event("ProfileUpdated").OnClientEvent:Connect(function(profile)
	ClientState.set("profile", profile)
end)
-- Roblox's hotbar is how you switch between your loaded tools on a job site, and only there.
local function updateHotbar(job)
	UI.setHotbar(job ~= nil and (job.state == "Working" or job.state == "Complete"))
end
updateHotbar(nil)
Net.event("JobUpdated").OnClientEvent:Connect(function(job)
	ClientState.set("job", job)
	updateHotbar(job)
end)
Net.event("JobBoardUpdated").OnClientEvent:Connect(function(board)
	ClientState.set("board", board)
end)
Net.event("PartyUpdated").OnClientEvent:Connect(function(party)
	ClientState.set("party", party)
end)
Net.event("Notify").OnClientEvent:Connect(function(message)
	UI.notify(message)
end)
Net.event("StoryUpdated").OnClientEvent:Connect(function(story)
	ClientState.set("story", story)
end)
Net.event("ContestUpdated").OnClientEvent:Connect(function(contest)
	ClientState.set("contest", contest)
end)
Net.event("ContractsUpdated").OnClientEvent:Connect(function(view)
	ClientState.set("contracts", view)
end)

for _, name in CONTROLLERS do
	local controller = require(Controllers:WaitForChild(name))
	controller:Start()
end
local controllersTook = os.clock() - started

-- Fetch the GUI's frames and glyphs, so buttons that only show up later (the phone buttons,
-- prompts, menus) have their art ready instead of downloading it as they appear. Not until the
-- player's at their business, though: before that, a phone's connection is busy loading the world
-- around it, which the title card is waiting on. What's on screen loads its own art anyway.
task.spawn(function()
	local player = Players.LocalPlayer
	local giveUp = os.clock() + 30
	while player:GetAttribute("ArrivedAtBusiness") ~= true and os.clock() < giveUp do
		task.wait(0.25)
	end
	local GuiArt = require(ReplicatedStorage.Shared.Config.GuiArt)
	local ids = {}
	for path, id in GuiArt.Images do
		local folder = string.match(path, "^(%a+)/")
		if id ~= "" and (folder == "Kit" or folder == "Icons" or folder == "Computer") then
			table.insert(ids, id)
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
end)

ClientState.set("board", Net.func("GetJobBoard"):InvokeServer())
local profile = Net.func("GetProfile"):InvokeServer()
if profile then
	ClientState.set("profile", profile)
end
local story = Net.func("GetStory"):InvokeServer()
-- An update may have come in while it was on its way, and that's newer.
if story and not ClientState.story then
	ClientState.set("story", story)
end
local contest = Net.func("GetContest"):InvokeServer()
if contest and not ClientState.contest then
	ClientState.set("contest", contest)
end
-- The day's contracts are pushed when the save loads, which can come before this script was
-- listening, so ask for them too (nil while the save is still loading: the push will follow).
local contracts = Net.func("GetContracts"):InvokeServer()
if contracts and not ClientState.contracts then
	ClientState.set("contracts", contracts)
end
-- For the F9 console, next to the title card's steps.
print(
	string.format(
		"[Load] Client scripts ready after %.1f s (starting the controllers took %.1f s)",
		os.clock() - started,
		controllersTook
	)
)
