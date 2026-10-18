# Instructions 7: Leaf tools (wide rake, leaf blower, backpack blower)

These clear leaf piles from the lawn. The player holds the tool while pressing to work.

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

## Models

### `WideRake` (Wide Rake)

- A wide, fan-shaped leaf rake with plastic tines (a head about 2.8 studs wide) on a wood or
  fiberglass handle, about 5 studs tall in total.
- Build it **standing upright**, with the tines at the bottom touching the ground and the handle
  straight up, the same way the kit's `OldRake` is built. Put the `Handle` about **3.6 studs above
  the ground** on the handle.
- Main color: green rgb(60, 140, 60) head.
- Budget: 2,500 triangles.

### `LeafBlower` (Leaf Blower)

- A handheld gas leaf blower: an engine body with a top handle and a long straight blower tube
  pointing forward and angled down about 30°. The nozzle ends about 1.5 studs above the ground.
- Size: about **3.5 studs long**. Put the `Handle` on the top handle.
- Main color: orange rgb(230, 120, 30).
- Budget: 4,000 triangles.

### `BackpackBlower` (Backpack Blower, the best leaf tool)

- A backpack leaf blower: the engine and fan on a padded backpack frame, and a flexible hose
  leading to a long tube with a hand grip and throttle.
- The game puts the tube's grip in the right hand. Put the `Handle` on that grip and aim the tube
  forward and down like the `LeafBlower`. Place the backpack about **2.3 studs behind (+Z), 1 stud
  to the left (−X) and 1 stud below** the Handle, so it sits roughly on the player's back.
- Main color: red rgb(200, 30, 30).
- Budget: 6,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "WideRake", "LeafBlower", "BackpackBlower" } do
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

- `WideRake`: "above bottom" about 3.6.
- `LeafBlower`: "above bottom" about 2.5–3.

Optional, while playtesting (`start_stop_play`): equip a tool on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local tool = Assets.tool("Rake", "WideRake") -- swap in each id from this file
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `WideRake`, `LeafBlower`, `BackpackBlower` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
