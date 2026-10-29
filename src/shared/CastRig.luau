-- The sums behind standing a person's rig where a statue stood (CastService, on the server, builds
-- the rigs). Every model in this game has an invisible Root part 0.5 studs above its origin, and
-- Assets.placeAt puts that origin on the spot it is given, so a rig's origin has to be its feet.
-- A Humanoid holds its HumanoidRootPart HipHeight studs above the floor, measured from the bottom
-- of the HumanoidRootPart. So the feet are half the HumanoidRootPart's height plus HipHeight below
-- its middle, and Root goes 0.5 above them.
--
-- This has no Roblox requires, so scripts/check-story.luau can test it with Lune.

local CastRig = {}

-- How far Root sits above the feet, like every other model's Root.
CastRig.ROOT_RISE = 0.5

-- How far below the HumanoidRootPart's middle the feet are (`rootSize` is the HumanoidRootPart's
-- height).
function CastRig.feetOffset(hipHeight: number, rootSize: number): number
	return rootSize / 2 + hipHeight
end

-- How far below the HumanoidRootPart's middle Root's middle goes, so that it is 0.5 above the feet.
function CastRig.rootPlacement(hipHeight: number, rootSize: number): number
	return CastRig.feetOffset(hipHeight, rootSize) - CastRig.ROOT_RISE
end

return CastRig
