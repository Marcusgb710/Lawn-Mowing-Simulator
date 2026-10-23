-- Gloria's house across the street, as this player's story has it (docs/STORY.md). The server
-- builds the house and everything her yard can look like (GloriaService); this screen shows the
-- yard for your own act, so everyone sees Gloria's yard where their story is:
--   * her yard: tired in act 1, TurfKing's stripes and sign in acts 2 and 3, over the top in act
--     4 (Story.GloriaYard), swapped as soon as your act changes;
--   * TurfKing's purple truck in her drive with Chad beside it, from act 2;
--   * in the intro, TurfKing's truck backing into her drive as the first line says;
--   * now and then, when you're in sight of her porch, a remark from Gloria (and from act 2, from
--     Chad) in a speech bubble (Story.porchRemark).
-- The yard shown here is this screen's own copy, put in the house's Yard folder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Story = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Story"))

local ClientState = require(script.Parent.Parent.ClientState)
local ComputerController = require(script.Parent.ComputerController)
local DialogueController = require(script.Parent.DialogueController)

local player = Players.LocalPlayer

-- How long to wait for the house and the yards (they're only there if the town has a lot).
local FIND_WAIT = 30
-- Remarks come when you're within this many studs of Gloria, the first a little after you come
-- into range and then every so often (seconds, a random time between the two).
local REMARK_RANGE = 130
local FIRST_REMARK = 6
local REMARK_EVERY = { 35, 55 }
-- How long TurfKing's truck takes to back into her drive in the intro.
local ARRIVE_TIME = 5

local GloriaController = {}

local house: Model? = nil
local templates: Folder? = nil
-- What's shown: the stage's number and its copy, and the copy of TurfKing's truck and Chad.
local shownStage: number? = nil
local stageCopy: Model? = nil
local turfKingCopy: Model? = nil
-- The truck backing in during the intro, while it's up.
local arrival: Model? = nil
-- Remarks: how many so far, and when the next one's due (nil until you're in range).
local remarks = 0
local nextRemark: number? = nil

local function yardFolder(): Instance?
	return house and house:FindFirstChild("Yard")
end

-- Shows the yard for this act (and TurfKing's truck and Chad from act 2).
local function show(act: number)
	local yard = yardFolder()
	if not (yard and templates) then
		return
	end
	local stage, turfKing = Story.gloriaStage(act)
	if stage ~= shownStage then
		if stageCopy then
			stageCopy:Destroy()
			stageCopy = nil
		end
		local template = templates:FindFirstChild("Stage" .. stage)
		if template then
			stageCopy = template:Clone()
			stageCopy.Parent = yard
		end
		shownStage = stage
	end
	if turfKing and not turfKingCopy then
		local template = templates:FindFirstChild("TurfKing")
		if template then
			turfKingCopy = template:Clone()
			turfKingCopy.Parent = yard
		end
	elseif not turfKing and turfKingCopy then
		turfKingCopy:Destroy()
		turfKingCopy = nil
	end
end

local function currentAct(): number
	local story = ClientState.story
	return if story then story.act else 1
end

-- The intro: "A purple TurfKing truck pulls into the drive next door." It backs in from the street
-- while the scene's up (in act 1 it isn't parked there yet), and goes when the scene's over.
local function arrive()
	local truckTemplate = templates and templates:FindFirstChild("TurfKing")
	truckTemplate = truckTemplate and truckTemplate:FindFirstChild("Truck")
	local yard = yardFolder()
	if turfKingCopy or arrival or not (truckTemplate and truckTemplate:IsA("Model") and yard) then
		return
	end
	local from = truckTemplate:GetAttribute("ArriveFrom")
	local truck = truckTemplate:Clone()
	local parked = truck:GetPivot()
	if typeof(from) == "CFrame" then
		truck:PivotTo(from)
		local progress = Instance.new("NumberValue")
		progress.Changed:Connect(function(value)
			if truck.Parent then
				truck:PivotTo(from:Lerp(parked, value))
			end
		end)
		local tween = TweenService:Create(
			progress,
			TweenInfo.new(ARRIVE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = 1 }
		)
		tween.Completed:Once(function()
			progress:Destroy()
		end)
		tween:Play()
	end
	truck.Parent = yard
	arrival = truck
end

-- A remark from her porch, when you're in sight of it and nothing else is going on.
local function remark()
	local markers = house and house:FindFirstChild("Anchor")
	local anchor = markers and markers:FindFirstChild("Bubble")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (anchor and anchor:IsA("Attachment") and root and root:IsA("BasePart")) then
		return
	end
	local inRange = (root.Position - anchor.WorldPosition).Magnitude <= REMARK_RANGE
	if not inRange then
		nextRemark = nil
		return
	end
	local now = os.clock()
	if not nextRemark then
		nextRemark = now + FIRST_REMARK
		return
	end
	local busy = DialogueController.isOpen() or ClientState.job ~= nil or ComputerController.isUsing()
	if busy or now < nextRemark then
		return
	end
	remarks += 1
	nextRemark = now + REMARK_EVERY[1] + math.random() * (REMARK_EVERY[2] - REMARK_EVERY[1])
	local speaker, line = Story.porchRemark(currentAct(), remarks)
	local adornee: Instance = anchor
	if speaker == "Chad" then
		local chadBubble = turfKingCopy and turfKingCopy:FindFirstChild("ChadBubble", true)
		if not chadBubble then
			return
		end
		adornee = chadBubble
	end
	DialogueController.bubble(adornee, speaker, line)
end

function GloriaController:Start()
	task.spawn(function()
		local found = workspace:WaitForChild("GloriasHouse", FIND_WAIT)
		local folder = ReplicatedStorage:WaitForChild("GloriasYard", FIND_WAIT)
		if not (found and found:IsA("Model") and folder and folder:IsA("Folder")) then
			return
		end
		house = found
		templates = folder
		show(currentAct())
		ClientState.Changed:Connect(function(key)
			if key == "story" then
				show(currentAct())
			end
		end)
		DialogueController.Opened:Connect(function()
			if DialogueController.current() == "Intro" then
				arrive()
			end
		end)
		DialogueController.Closed:Connect(function()
			if arrival then
				arrival:Destroy()
				arrival = nil
			end
		end)
		while true do
			task.wait(1)
			remark()
		end
	end)
end

return GloriaController
