-- Builds the story's nine people as Roblox rigs, once, when the server starts (the design is
-- docs/superpowers/specs/2026-10-28-model-overhaul-design.md, section 4). What each person wears
-- is in Config/Cast.luau. Every rig is an R15 avatar made with
-- Players:CreateHumanoidModelFromDescription, then given what every model in Assets has so the
-- places that put the statues down can put a rig down the same way:
--   Root      an invisible part welded to the HumanoidRootPart, the PrimaryPart, 0.5 above the
--             feet (CastRig), so Assets.placeAt stands the person where the statue stood
--   Head      an attachment on Root at the middle of the head, for the speech bubbles
--   Talk      an attachment on Root at the chest, half a stud forward
-- The name and the health bar are off, the Humanoid doesn't run its state machine, and only the
-- HumanoidRootPart (and, once placed, Root) is anchored: the rest stays free so animations can move
-- it (Assets.anchor knows to leave a rig's limbs alone). The rig is named after its id (NPC_Gloria
-- and so on), has a Pose attribute (a key of Cast.Poses, for NpcAnimator), and goes in
-- ReplicatedStorage.Assets.Story, where Assets.story finds it on the server and on every client (the
-- judges are cloned there).
--
-- Building one needs the catalog, so it can fail (an item taken down, Roblox unreachable): that id
-- gets a warning and no rig, and Assets.story gives its block placeholder instead. The nine are built
-- at the same time, since each is a wait on the catalog.
-- CastService.rig(id) is the finished rig, to clone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cast = require(Shared.Config.Cast)
local CastRig = require(Shared.CastRig)

-- The body parts of a HumanoidDescription that take the skin color.
local SKIN_PROPERTIES = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
-- How far in front of the chest the Talk attachment is.
local TALK_FORWARD = 0.5

local CastService = {}

-- [id] = the finished rig, in ReplicatedStorage.Assets.Story
local rigs: { [string]: Model } = {}

local function color(rgb: Cast.Rgb): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

-- A folder in `parent` with this name, made if it isn't there.
local function folderIn(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- What to dress the rig in: Cast.describe's plain properties, the skin color on every body part,
-- and the layered clothing, which a description takes as a list.
local function describe(person: Cast.Person): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	for property, value in Cast.describe(person) do
		(description :: any)[property] = value
	end
	local skin = color(person.body.skin)
	for _, property in SKIN_PROPERTIES do
		(description :: any)[property] = skin
	end
	local garments = {}
	for _, garment in person.layered do
		table.insert(garments, {
			AssetId = garment.id,
			AccessoryType = Enum.AccessoryType[garment.type],
			Order = garment.order,
			IsLayered = true,
		})
	end
	-- `false`: this list is only the layered clothing. The hair and hat come from the description.
	description:SetAccessories(garments, false)
	return description
end

-- A rig made by CreateHumanoidModelFromDescription is built in ReplicatedStorage, so it never gets a
-- physics step, and each Accessory's Handle (the hair and the layered garments) stays where its asset
-- was authored, up to 20 studs from the body, until the rig has spent a frame in workspace. A bounding
-- box taken before then would measure the yard, not the person. So each Handle is put where its Weld
-- wants it, in place. Nothing else moves: the API already placed the body parts.
local function settleAccessories(rig: Model)
	for _, accessory in rig:GetChildren() do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			local weld = if handle then handle:FindFirstChildOfClass("Weld") else nil
			if handle and handle:IsA("BasePart") and weld then
				local part0, part1 = weld.Part0, weld.Part1
				if part1 == handle and part0 then
					handle.CFrame = part0.CFrame * weld.C0 * weld.C1:Inverse()
				elseif part0 == handle and part1 then
					handle.CFrame = part1.CFrame * weld.C1 * weld.C0:Inverse()
				end
			end
		end
	end
end

-- The free catalog has no grey hair, so the hair's own texture comes off and the color goes on.
-- Returns whether there was any hair to color.
local function recolorHair(rig: Model, hairColor: Color3): boolean
	local found = false
	for _, accessory in rig:GetChildren() do
		if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hair then
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				found = true
				if handle:IsA("MeshPart") then
					handle.TextureID = ""
				end
				-- Older hair is a SpecialMesh with a texture, newer hair can carry a SurfaceAppearance.
				for _, child in handle:GetChildren() do
					if child:IsA("SpecialMesh") then
						child.TextureId = ""
					elseif child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				handle.Color = hairColor
			end
		end
	end
	return found
end

-- Root, set as the PrimaryPart and welded to the HumanoidRootPart, with the Head and Talk
-- attachments on it. The rig is still where it was built, so all of this is worked out in place.
local function addRoot(rig: Model, humanoid: Humanoid, rootPart: BasePart, head: BasePart, chest: BasePart)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = rootPart.CFrame * CFrame.new(0, -CastRig.rootPlacement(humanoid.HipHeight, rootPart.Size.Y), 0)
	root.Parent = rig
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = root
	weld.Parent = root
	rig.PrimaryPart = root

	local function attach(name: string, position: Vector3)
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = root.CFrame:PointToObjectSpace(position)
		attachment.Parent = root
	end
	attach("Head", head.Position)
	attach("Talk", chest.Position + rootPart.CFrame.LookVector * TALK_FORWARD)
end

-- One person's finished rig, in ReplicatedStorage.Assets.Story. Errors if anything about it can't
-- be done, so the caller can leave that person to the placeholder.
local function build(id: string, person: Cast.Person): Model
	local rig = Players:CreateHumanoidModelFromDescription(describe(person), Enum.HumanoidRigType.R15)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local rootPart = rig:FindFirstChild("HumanoidRootPart")
	local head = rig:FindFirstChild("Head")
	local chest = rig:FindFirstChild("UpperTorso")
	assert(humanoid and rootPart and head and chest, "the rig has no Humanoid, HumanoidRootPart, Head or UpperTorso")

	settleAccessories(rig)
	if person.hairColor and not recolorHair(rig, color(person.hairColor)) then
		warn(`CastService: {id} has a hair color but no hair to color`)
	end
	addRoot(rig, humanoid, rootPart :: BasePart, head :: BasePart, chest :: BasePart)

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.EvaluateStateMachine = false
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- A person standing in the yard is not something to walk into (the placeholders weren't
			-- either), and limbs that animate shouldn't shove whoever is next to them.
			descendant.CanCollide = false
			descendant.Anchored = descendant == rootPart
		end
	end

	rig.Name = id
	rig:SetAttribute("Pose", person.pose)
	local story = folderIn(folderIn(ReplicatedStorage, "Assets"), "Story")
	local older = story:FindFirstChild(id)
	if older then
		older:Destroy()
	end
	rig.Parent = story
	return rig
end

-- Builds every person's rig, all nine at once, before anything that places them runs. Each one
-- waits on the catalog, so they are started together and Init returns when the last is done: the
-- wait is one round trip, not nine. Calling it again builds only the ones that don't have a rig yet.
function CastService:Init()
	local ids = {}
	for id in Cast.People do
		table.insert(ids, id)
	end
	table.sort(ids)

	-- Made here, before any build starts. A build yields only inside CreateHumanoidModelFromDescription,
	-- and nothing between that call's return and the rig going into this folder yields, so no two
	-- builds can be in the folder at the same moment.
	folderIn(folderIn(ReplicatedStorage, "Assets"), "Story")

	local pending = 0
	for _, id in ids do
		if not rigs[id] then
			pending += 1
			task.spawn(function()
				local ok, result = pcall(build, id, Cast.People[id])
				if ok then
					rigs[id] = result
				else
					warn(`CastService: {id} could not be built ({result}), so it stays a placeholder`)
				end
				pending -= 1
			end)
		end
	end
	while pending > 0 do
		task.wait()
	end
end

-- The finished rig for a story person's id, or nil when it could not be built.
function CastService.rig(id: string): Model?
	return rigs[id]
end

return CastService
