# Instructions 8: Edgers

Edgers cut a clean line where the lawn meets the sidewalk and driveway curbs. The cutting blade
works vertically, close to the ground.

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a lawn-care game for phones. It's
  owned by the **Big Dink Studios** group and edited in Team Create.
- Every mesh, texture and model you generate or upload must be **owned by Big Dink Studios**.
  Assets owned by anyone else won't load in the game.
- Put each finished model in **`ReplicatedStorage.Assets.Tools`**, named **exactly** as listed below. The names are item
  ids and are case-sensitive. The game finds each model by name and uses it in place of the gray
  block placeholder, so no code changes are needed.
- Only add the models in this file. Don't create or edit scripts. Don't change
  `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets.Kit`, `ServerScriptService`,
  `StarterPlayer`, or any model already in `ReplicatedStorage.Assets`. Rojo syncs those from
  GitHub and would overwrite your edits.
- If a model with the same name is already in `ReplicatedStorage.Assets.Tools`, leave it alone and report it.
- Don't publish the game. The user publishes.

## Style

- Match the Lawn Mowing kit already in `ReplicatedStorage.Assets.Kit` (for example
  `Mower_Push_21in` and `Prop_WheelieBin`): realistic proportions, clean simple shapes, slightly
  worn but tidy, and easy to read on a phone screen.
- Unbranded: no logos, brand names or readable text anywhere. Blank license plates and signs are
  fine.
- Scale: 1 stud = 0.28 m. A player is about 5 studs tall.
- Phone performance: stay under each model's triangle budget. Use a few MeshParts rather than many
  tiny parts, and reuse one mesh for repeated pieces such as wheels. Don't add scripts, sounds,
  lights, particles or decals.

## How tools are held (every tool in this file)

The game turns your Model into a Tool and puts the part named `Handle` in the player's right hand.

- Make each tool a **Model** (not a Tool) that holds the visible parts plus one extra Part named
  exactly **`Handle`**: Size 0.4 × 0.4 × 0.4, Transparency 1, Orientation (0, 0, 0), and
  CanCollide, CanTouch and CanQuery off.
- The Handle's center is the player's palm. Its up (+Y) is up, and its front (LookVector, −Z)
  points the way the player faces. So **build the tool upright with its working end toward −Z**,
  and put the Handle where a hand would grip it. The player's right is +X.
- In the holding pose the hand is about **4.3 studs above the ground**, about 1.5 studs in front
  of the player's body.
- Set every part to Anchored on, with CanCollide, CanTouch and CanQuery off. The game unanchors
  and welds them itself. Leave the Model's pivot unrotated.
- The game animates moving parts automatically when you name them like this. This is optional,
  but it makes tools feel alive:
  - `<ItemId>__Wheel_<Name>` (two underscores) rolls as the player walks. It turns around **the
    part's own X axis**, so make the axle run along the part's X axis and center the part on the
    axle.
  - `<ItemId>__CutterRotor` and `<ItemId>__Spool` spin while the tool is working. They turn around
    **the part's own Y axis**, so center the part on its rotation point.
- For scale and Handle placement, look at the finished kit tools in
  `ReplicatedStorage.Assets.Tools` (`GasPushMower`, `GasTrimmer`, `ElectricTrimmer`, `OldRake`).
  Don't edit them.

A vertical edger blade can optionally be named `<ItemId>__Wheel_Blade` if its axle runs along the
part's X axis. It then turns as the player walks.

## Models

### `HalfMoonEdger` (Half-Moon Edger, the cheapest edger)

- A manual edger: a flat, half-circle steel blade with a foot step at the bottom of a straight
  shaft, and a T-grip on top. About 4.5 studs tall.
- Build it **standing upright**, with the blade at the bottom touching the ground. Put the `Handle`
  at the T-grip, about **4.3 studs above the bottom of the blade**.
- Colors: gray rgb(130, 130, 130) blade, wooden shaft.
- Budget: 2,000 triangles.

### `ElectricEdger` (Electric Edger)

- An electric stick edger: a motor housing at the bottom with a vertical blade and a small guide
  wheel, a straight shaft with a D-shaped front handle and a rear grip, and a short stub of power
  cord.
- Hold it like the kit trimmers: put the `Handle` on the rear grip, with the blade housing about
  **3.5–4 studs below and 3–4 studs ahead of** it.
- Main color: blue rgb(60, 160, 220).
- Budget: 4,000 triangles.

### `GasStickEdger` (Pro Stick Edger, the best edger)

- A gas stick edger: a small engine at the top rear, a straight shaft, and an angled gear head at
  the bottom with a vertical blade, a blade guard and a guide wheel.
- Same hold as `ElectricEdger`.
- Main color: red rgb(200, 30, 30).
- Budget: 5,000 triangles.

### `WalkBehindEdger` (Walk-Behind Edger)

- A walk-behind edger: a small wheeled frame with an engine, a vertical blade with a guard at the
  front right, and a push handle. About 2.5 wide × 4.5 long.
- This one is pushed along the ground like a mower: its wheels touch the ground, and the `Handle` is
  at the handlebar, **4.0–4.3 studs above the bottom of the wheels**.
- Main color: orange rgb(230, 120, 30).
- Moving parts: `WalkBehindEdger__Wheel_*` for each wheel.
- Budget: 8,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "HalfMoonEdger", "ElectricEdger", "GasStickEdger", "WalkBehindEdger" } do
	local model = folder:FindFirstChild(id)
	if not model then
		warn(id, "is missing")
		continue
	end
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	local front = box.Position.Z - size.Z / 2
	local scripts, colliding = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
		end
		if d:IsA("BasePart") and d.CanCollide then
			colliding += 1
		end
	end
	print(id, model.ClassName, "size", size, "scripts", scripts, "colliding parts", colliding)
	local handle = model:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		print("   Handle invisible", handle.Transparency == 1, "facing", handle.CFrame.LookVector,
			"above bottom", handle.Position.Y - bottom, "reaches ahead", handle.Position.Z - front)
	else
		warn("   no Handle part")
	end
end
```

Expected for every tool: class `Model`, scripts `0`, colliding parts `0`, Handle invisible `true`,
facing `0, 0, -1`.

- `HalfMoonEdger`: "above bottom" about 4.3.
- `ElectricEdger` and `GasStickEdger`: "above bottom" about 3.5–4, and "reaches ahead" about 3–4.
- `WalkBehindEdger`: "above bottom" 4.0–4.3.

Optional, while playtesting (`start_stop_play`): equip a tool on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local tool = Assets.tool("Edger", "HalfMoonEdger") -- swap in each id from this file
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `HalfMoonEdger`, `ElectricEdger`, `GasStickEdger`, `WalkBehindEdger` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
