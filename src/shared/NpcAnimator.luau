-- Poses the story's people with Roblox's own animations (Cast.Poses). Gloria and Chad idle, June
-- sits, and the judges walk and stop (GloriaService, GrandmaJune, GloriaController and
-- ContestController call it; the server and the screens use it alike).
--
--   NpcAnimator.play(model, pose?, speed?)
--                                  plays `pose` on the model's Humanoid, looped, in place of
--                                  whatever this module played on it before. Without `pose` it
--                                  plays the model's own Pose attribute (CastService sets one on
--                                  every rig). `speed` is how fast the track runs, 1 when left
--                                  out (the animation as it was made). A model with no Humanoid
--                                  (a block placeholder) or a pose that isn't in Cast.Poses does
--                                  nothing.
--   NpcAnimator.stop(model)        stops what it played on the model.
--   NpcAnimator.resolve(attr, requested)  which pose that is (the pure part, for check-story).
--   NpcAnimator.walkSpeed(studsPerSecond)  the `speed` that keeps the Walk pose in step with a walk
--                                  at that pace (the other pure part, for check-story).
--
-- A model that isn't in the game yet (the server builds June and Gloria before it parents them)
-- starts when it gets there, since an Animator can't play outside the DataModel. It plays the
-- pose and speed of the latest call.
--
-- Only Cast is required, and every call into Roblox is inside a function, so scripts/check-story.luau
-- can load this with Lune and test `resolve` and `walkSpeed`.

local Cast = require(script.Parent.Config.Cast)

local NpcAnimator = {}

-- How long a pose takes to blend in, and the one before it to blend out (seconds).
local FADE = 0.2

-- The pace (studs a second) Roblox's R15 walk (Cast.Poses.Walk) is made for. The default Animate
-- script plays it at the walk speed over this number, so the legs keep step with the ground.
NpcAnimator.WALK_STUDS_PER_SECOND = 14.5

-- What each model is playing from here, and the models waiting to get into the game before they
-- play. Weak, so a model that is gone takes its entry with it.
local playing: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Model]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

-- The pose to play: `requested` if there is one, else the model's Pose attribute. nil when that
-- isn't a pose in Cast.Poses. A requested pose that doesn't exist is not swapped for the attribute,
-- because asking for a pose that isn't there is a mistake worth seeing.
function NpcAnimator.resolve(poseAttribute: string?, requested: string?): string?
	local name = if requested ~= nil then requested else poseAttribute
	if typeof(name) == "string" and Cast.Poses[name] ~= nil then
		return name
	end
	return nil
end

local function stopTrack(model: Model)
	local track = playing[model]
	if track then
		playing[model] = nil
		track:Stop(FADE)
	end
end

-- Stops waiting for the model to get into the game.
local function stopWaiting(model: Model)
	local connection = waiting[model]
	if connection then
		waiting[model] = nil
		connection:Disconnect()
	end
end

-- The track speed that keeps the Walk pose in step with a walk of `studsPerSecond` (1 at the pace
-- the animation is made for, slower below it).
function NpcAnimator.walkSpeed(studsPerSecond: number): number
	return studsPerSecond / NpcAnimator.WALK_STUDS_PER_SECOND
end

local function start(model: Model, humanoid: Humanoid, pose: string, speed: number)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local entry = Cast.Poses[pose]
	local animation = Instance.new("Animation")
	animation.AnimationId = entry.id
	local track = (animator :: Animator):LoadAnimation(animation)
	track.Looped = entry.looped
	stopTrack(model)
	playing[model] = track
	track:Play(FADE, 1, speed)
end

function NpcAnimator.play(model: Model, pose: string?, speed: number?)
	local name = NpcAnimator.resolve(model:GetAttribute("Pose") :: any, pose)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (name and humanoid) then
		return
	end
	-- The latest call is the one that counts, even while waiting.
	stopWaiting(model)
	local trackSpeed = speed or 1
	if model:IsDescendantOf(game) then
		start(model, humanoid, name, trackSpeed)
		return
	end
	-- The callback ends the wait through `waiting`, so it needs no name for its own connection.
	local connection = model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(game) then
			stopWaiting(model)
			start(model, humanoid, name, trackSpeed)
		end
	end)
	waiting[model] = connection
end

function NpcAnimator.stop(model: Model)
	stopWaiting(model)
	stopTrack(model)
end

return NpcAnimator
