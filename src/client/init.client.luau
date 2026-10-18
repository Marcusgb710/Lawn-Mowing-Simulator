-- Client entry point. Hooks remotes up to ClientState, then starts every controller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local ClientState = require(script.ClientState)
local UI = require(script.UI)

local Controllers = script:WaitForChild("Controllers")
local CONTROLLERS = {
	"CameraController",
	"HudController",
	"JobBoardController",
	"ShopController",
	"TruckController",
	"GuideController",
	"TutorialController",
	"CarryController",
	"ComputerController",
	"InteractController",
	"DecorController",
	"GrassController",
	"ToolFxController",
	"ArmsController",
	"PartyController",
	"CutsceneController",
}

Net.event("ProfileUpdated").OnClientEvent:Connect(function(profile)
	ClientState.set("profile", profile)
end)
Net.event("JobUpdated").OnClientEvent:Connect(function(job)
	ClientState.set("job", job)
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

for _, name in CONTROLLERS do
	local controller = require(Controllers:WaitForChild(name))
	controller:Start()
end

ClientState.set("board", Net.func("GetJobBoard"):InvokeServer())
local profile = Net.func("GetProfile"):InvokeServer()
if profile then
	ClientState.set("profile", profile)
end
