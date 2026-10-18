# Instructions 17: Pro trimmer, articulating hedge trimmer and soil probe

Professional handheld equipment. Turf renovation jobs depend on the soil probe: players check
soil temperature and moisture with it before aerating or seeding.

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a realistic lawn-care and gardening
  game for phones. It's owned by the **Big Dink Studios** group and edited in Team Create.
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

- The game aims to be **accurate**: model each item like the real thing, with true proportions
  and the details that tell one tool from another (a narrow blade vs. a scoop, bypass blades vs.
  an anvil, an air tire vs. a solid one). Players are meant to recognize tools by their looks.
- Match the Lawn Mowing kit already in `ReplicatedStorage.Assets.Kit` (for example
  `Mower_Push_21in` and `Prop_WheelieBin`): realistic, clean simple shapes, slightly worn but tidy,
  and easy to read on a phone screen.
- Unbranded: no logos, brand names or readable text anywhere.
- Scale: 1 stud = 0.28 m (1 inch = 0.09 stud, 1 foot = 1.09 studs). A player is about 5 studs tall.
- Phone performance: stay under each model's triangle budget. Use a few MeshParts rather than many
  tiny parts, and reuse one mesh for repeated pieces such as wheels. Don't add scripts, sounds,
  lights, particles or decals.

## How tools are held (every item in this file)

The game turns your Model into a Tool and puts the part named `Handle` in the player's right hand.
It also shows the item on storage racks and in the truck.

- Make each item a **Model** (not a Tool) that holds the visible parts plus one extra Part named
  exactly **`Handle`**: Size 0.4 × 0.4 × 0.4, Transparency 1, Orientation (0, 0, 0), and
  CanCollide, CanTouch and CanQuery off.
- The Handle's center is the player's palm. Its up (+Y) is up, and its front (LookVector, −Z)
  points the way the player faces. So **pose the item the way it's used, with its working end
  toward −Z**, and put the Handle where a right hand grips it. The player's right is +X.
- Keep **real proportions**. In the holding pose the hand is about 4.3 studs above the ground and
  about 1.5 studs in front of the body. Pushed machines and ride-ons get their Handle at their real
  handlebar or controls; the game sets how high they sit so their wheels touch the ground.
- Set every part to Anchored on, with CanCollide, CanTouch and CanQuery off. The game unanchors
  and welds them itself. Leave the Model's pivot unrotated.
- The game animates moving parts automatically when you name them like this. This is optional,
  but it makes items feel alive:
  - A name containing `__Wheel` (two underscores, e.g. `<ItemId>__Wheel_FrontL`) rolls as the
    player moves, turning around **the part's own X axis**. Make the axle run along the part's X
    axis and center the part on the axle. Use it for wheels, reels, rollers and tine drums.
  - A name containing `__CutterRotor` or `__Spool` (e.g. `<ItemId>__CutterRotor_L`) spins while the
    item works, turning around **the part's own Y axis**. Center the part on its rotation point.
- For scale and Handle placement, look at the finished kit tools in
  `ReplicatedStorage.Assets.Tools` (`GasPushMower`, `RidingMower`, `GasTrimmer`, `OldRake`). Don't
  edit them.

## Models

### `StraightShaftTrimmer` (Pro Straight-Shaft Trimmer)

- A professional string trimmer: a **long straight shaft** (about 6.5 studs), the **engine at the
  rear top**, a **bike-style or loop handle** partway along the shaft, and a **string line head**
  with a guard at the front end. Orange rgb(230, 120, 30) with black and silver.
- Handle: on the right handlebar grip. The line head should end up about **3.5–4 studs below and
  4–5 studs ahead of** the Handle.
- Moving parts: the line head `StraightShaftTrimmer__Spool`.
- Budget: 4,000 triangles. For posture, see the kit's `GasTrimmer`.

### `ArticulatingHedgeTrimmer` (Articulating Hedge Trimmer)

- A long pole hedge trimmer: the **engine at the rear**, a **long pole** (about 8 studs in total),
  and a **double-sided cutter bar** (about 1.8 studs, 20 in) on a **hinged gearbox** at the far end,
  angled about 45° down. Red-orange rgb(200, 60, 30).
- Hold it angled **up about 25°**, so the cutter bar reaches about 6–7 studs high, over the top of
  a hedge. Handle: on the rear grip near the engine.
- Budget: 4,500 triangles.

### `SoilProbe` (Soil Probe)

- A **T-handle** (about 0.9 studs wide) on a **thin steel rod** (about 3.2 studs) with a pointed
  tip, and a **small digital readout** (a blank screen, no numbers) at the top of the rod. Silver
  rgb(220, 220, 225).
- Hold: Handle on the T-handle, rod pointing **straight down**. Budget: 800 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "StraightShaftTrimmer", "ArticulatingHedgeTrimmer", "SoilProbe" } do
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

Expected for every item: class `Model`, scripts `0`, colliding parts `0`, Handle invisible `true`,
facing `0, 0, -1`.

- `StraightShaftTrimmer`: "above bottom" about 3.5–4, and "reaches ahead" about 4–5.
- `ArticulatingHedgeTrimmer`: about 8 studs long. `SoilProbe`: "above bottom" about 3.2.

Optional, while playtesting (`start_stop_play`): equip an item on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local Tools = require(game.ReplicatedStorage.Shared.Config.Tools)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local id = "StraightShaftTrimmer" -- swap in each id from this file
local tool = Assets.tool(Tools.get(id).category, id)
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `StraightShaftTrimmer`, `ArticulatingHedgeTrimmer`, `SoilProbe` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
