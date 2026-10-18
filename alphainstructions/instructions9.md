# Instructions 9: Hedge trimmers

Hedges in the yards are boxy shrubs 4–6.5 studs tall, and players trim them while standing next to
them. Every hedge tool is held with its blade pointing **forward (−Z) and roughly level** at hand
height. Never put the `Handle` in the middle of the blade.

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

### `HandHedgeShears` (Hand Hedge Shears, the cheapest hedge tool)

- Big two-handed hedge shears: two long wooden or rubber-gripped handles and straight steel
  blades, about 3 studs long in total.
- Put the `Handle` on one handle, with the blades pointing forward and tilted slightly up.
- Colors: steel gray rgb(150, 150, 150) blades.
- Budget: 1,500 triangles.

### `ElectricHedgeTrimmer` (Electric Hedge Trimmer)

- A corded electric hedge trimmer: a body with a D-shaped front handle and a rear grip, a straight
  double-sided toothed bar about 2.5 studs long pointing forward, and a short stub of cord at the
  back.
- Put the `Handle` on the rear grip.
- Main color: blue rgb(60, 160, 220).
- Budget: 4,000 triangles.

### `CordlessHedgeTrimmer` (Cordless Hedge Trimmer)

- Like the electric one, but with a battery pack on the back and a longer bar of about 3.2 studs.
- Main color: orange rgb(230, 120, 30).
- Budget: 4,000 triangles.

### `GasHedgeTrimmer` (Gas Hedge Trimmer, the best hedge tool)

- A gas hedge trimmer: a small engine with a pull starter, a wrap-around front handle, and the
  longest bar, about 3.8 studs.
- Main color: red rgb(200, 30, 30).
- Budget: 5,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "HandHedgeShears", "ElectricHedgeTrimmer", "CordlessHedgeTrimmer", "GasHedgeTrimmer" } do
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

- Every hedge tool: "above bottom" under 1 (the blade is level with the hand, not hanging below
  it), and "reaches ahead" about 2.5–4.5.

Optional, while playtesting (`start_stop_play`): equip a tool on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local tool = Assets.tool("HedgeTrimmer", "HandHedgeShears") -- swap in each id from this file
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `HandHedgeShears`, `ElectricHedgeTrimmer`, `CordlessHedgeTrimmer`, `GasHedgeTrimmer` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
