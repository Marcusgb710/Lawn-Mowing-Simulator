-- Grandma June on her porch rocker, beside the shop on every business plot (docs/STORY.md). Look
-- at her and press E (or tap the button) to talk: StoryService picks what she says, and her
-- speech bubble shows on your screen (DialogueController). WorldService puts her on each plot.
--
-- The chair is Story/PorchRockingChair. June herself is her rig, NPC_June_Sitting: CastService
-- builds the people from Config/Cast.luau when the server starts, and she sits in the chair with
-- the Sit animation (NpcAnimator). Either one falls back to the block placeholders
-- Props/PorchRockingChair and Props/GrandmaJune, both standing on the same spot.
-- Where there's room, they stand on her porch, Story/PorchDeck, at its ChairSpot marker. The deck
-- is a model of its own, so looking at it doesn't offer to talk to her.
-- The scenes' markers are attachments on an invisible Anchor part, worked out from June's size, so
-- a real model needs none of its own:
--   Bubble    over her head, where her speech bubble goes
--   TalkView  where the camera looks at her from in the story's scenes

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Cast = require(Shared:WaitForChild("Config"):WaitForChild("Cast"))
local CastRig = require(Shared:WaitForChild("CastRig"))
local NpcAnimator = require(Shared:WaitForChild("NpcAnimator"))

-- Where the camera looks at her from: this far in front of her, a little to one side, about her
-- eye height.
local VIEW_DISTANCE = 9
local VIEW_SIDE = 2.5

local GrandmaJune = {}

-- Each piece: the real model's id (in Story/, or for June the rig CastService builds), and the
-- block placeholder used until it's in the game. The placeholders and the chair stand with their
-- origin on the rocker's, so they are on the same spot. June's rig goes where her `seat` in
-- Config/Cast.luau says, in the chair's frame (see `seatedAt`).
local PIECES = {
	{ story = "PorchRockingChair", placeholder = "PorchRockingChair", name = "PorchRockingChair" },
	{ story = "NPC_June_Sitting", placeholder = "GrandmaJune", name = "GrandmaJune" },
}

-- The rocker's footprint (studs, across and deep), for when there's no porch.
local ROCKER_FOOTPRINT = Vector2.new(2.4, 3)

-- The frame to give Assets.placeAt so a rig's Root lands on its seat in the chair's frame (the
-- chair's CFrame times Cast.People[id].seat), not the origin that is 0.5 under Root. nil for
-- someone with no seat.
local function seatedAt(chair: CFrame, id: string): CFrame?
	local person = Cast.People[id]
	local offset = person and person.seat
	if not offset then
		return nil
	end
	local root = chair * CFrame.new(Vector3.new(offset.x, offset.y, offset.z))
	return root * CFrame.new(0, -CastRig.ROOT_RISE, 0)
end

-- Whether her porch model is in the game.
function GrandmaJune.hasPorch(): boolean
	return Assets.storyModel("PorchDeck") ~= nil
end

-- How much ground she takes (studs, across and deep): her porch, or just her rocker.
function GrandmaJune.footprint(withPorch: boolean): Vector2
	if withPorch then
		local deck = Assets.storyModel("PorchDeck")
		if deck then
			local _, size = deck:GetBoundingBox()
			deck:Destroy()
			return Vector2.new(size.X, size.Z)
		end
	end
	return ROCKER_FOOTPRINT
end

-- June in her rocker at `ground` (the middle of her porch, or of her rocker without one), facing
-- its LookVector. Returns her model, and her porch when `withPorch` and it's in the game.
function GrandmaJune.build(ground: CFrame, withPorch: boolean?): (Model, Model?)
	local model = Instance.new("Model")
	model.Name = "GrandmaJune"

	local porch = if withPorch then Assets.storyModel("PorchDeck") else nil
	local seat = ground
	if porch then
		porch.Name = "JunePorch"
		Assets.anchor(porch)
		Assets.placeAt(porch, ground)
		-- The rocker stands on the porch's ChairSpot, facing the way it says (the porch's front
		-- without one).
		local spot = porch:FindFirstChild("ChairSpot", true)
		seat = if spot and spot:IsA("Attachment") then spot.WorldCFrame else ground * CFrame.new(0, 1.6, 0)
	end

	for _, piece in PIECES do
		local part = Assets.storyModel(piece.story) or Assets.prop(piece.placeholder)
		part.Name = piece.name
		Assets.anchor(part)
		-- Her rig sits with its Root on her seat, and plays the Sit animation (its Pose attribute).
		-- The block placeholder, like the chair, stands on the chair's origin.
		local seated = if part:FindFirstChildOfClass("Humanoid") then seatedAt(seat, piece.story) else nil
		Assets.placeAt(part, seated or seat)
		part.Parent = model
		if seated then
			NpcAnimator.play(part)
		end
	end

	local june = model:FindFirstChild("GrandmaJune") :: Model
	local box, size = june:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local face = Vector3.new(box.Position.X, top - size.Y * 0.25, box.Position.Z)
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.one
	anchor.CFrame = seat
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = model
	local bubble = Instance.new("Attachment")
	bubble.Name = "Bubble"
	bubble.Parent = anchor
	bubble.WorldPosition = Vector3.new(face.X, top + 0.8, face.Z)
	local view = Instance.new("Attachment")
	view.Name = "TalkView"
	view.Parent = anchor
	local from = face + seat.LookVector * VIEW_DISTANCE + seat.RightVector * VIEW_SIDE + Vector3.new(0, 0.6, 0)
	view.WorldCFrame = CFrame.lookAt(from, face)

	model:SetAttribute("Interact", "Talk")
	model:SetAttribute("InteractText", "Talk")
	model:SetAttribute("InteractName", "Grandma June")
	return model, porch
end

return GrandmaJune
