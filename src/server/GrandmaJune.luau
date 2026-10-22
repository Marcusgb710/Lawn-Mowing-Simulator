-- Grandma June on her porch rocker, beside the shop on every business plot (docs/STORY.md). Look
-- at her and press E (or tap the button) to talk: StoryService picks what she says, and her
-- speech bubble shows on your screen (DialogueController). WorldService puts her on each plot.
--
-- The models are Props/PorchRockingChair and Props/GrandmaJune (block placeholders until the real
-- ones exist), both standing on the same spot. The scenes' markers are attachments on an
-- invisible Anchor part, worked out from June's size, so a real model needs none of its own:
--   Bubble    over her head, where her speech bubble goes
--   TalkView  where the camera looks at her from in the story's scenes

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

-- Where the camera looks at her from: this far in front of her, a little to one side, about her
-- eye height.
local VIEW_DISTANCE = 9
local VIEW_SIDE = 2.5

local GrandmaJune = {}

-- June in her rocker, on the ground at `ground`, facing its LookVector.
function GrandmaJune.build(ground: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "GrandmaJune"
	for _, name in { "PorchRockingChair", "GrandmaJune" } do
		local piece = Assets.prop(name)
		Assets.anchor(piece)
		Assets.placeAt(piece, ground)
		piece.Parent = model
	end

	local june = model:FindFirstChild("GrandmaJune") :: Model
	local box, size = june:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local face = Vector3.new(box.Position.X, top - size.Y * 0.25, box.Position.Z)
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.one
	anchor.CFrame = ground
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
	local from = face + ground.LookVector * VIEW_DISTANCE + ground.RightVector * VIEW_SIDE + Vector3.new(0, 0.6, 0)
	view.WorldCFrame = CFrame.lookAt(from, face)

	model:SetAttribute("Interact", "Talk")
	model:SetAttribute("InteractText", "Talk")
	model:SetAttribute("InteractName", "Grandma June")
	return model
end

return GrandmaJune
