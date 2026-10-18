# Instructions 20: Supplies for blades, wrenches and the tool bucket

More maintenance supplies: dull blades leave ragged cuts until they're sharpened or swapped,
and the tool bucket lets a player carry many hand tools in one spot in the truck.

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

For every supply: put the Handle at its natural carry grip (a handle, or the middle of a small
item).

### `WrenchSet` (Wrench Set)

- A gray rgb(170, 170, 175) **folding case** (about 1.5 × 1 × 0.25) shown open, with sockets, a
  ratchet and wrenches in molded slots. Handle: on the case's carry handle.
  Budget: 1,500 triangles.

### `BladeFile` (Blade File)

- A **flat mill file** with a cross-hatched steel face and a wooden handle, about **1.1 studs
  long**. Handle: on the wooden handle. Budget: 400 triangles.

### `SharpeningStone` (Sharpening Stone)

- A **gray whetstone** rgb(90, 90, 100), about **0.55 × 0.2 × 0.1** studs, slightly worn in the
  middle. Budget: 200 triangles.

### `BenchGrinder` (Bench Grinder)

- A blue rgb(60, 120, 180) **bench grinder**: a motor housing in the middle, **two grinding
  wheels** in guards at the ends, clear eye shields and tool rests. About **1.5 wide × 1.1 tall ×
  0.8 deep**. It stays in the building. Handle: on top in the middle. Budget: 2,000 triangles.

### `SpareMowerBlade` (Spare Mower Blade)

- A **flat steel mower blade** about **1.9 studs long** (21 in) and 0.2 wide, with a center
  mounting hole and slightly raised lift wings at both ends. Handle: at the center hole.
  Budget: 300 triangles.

### `ToolBucket` (Tool Bucket)

- An **orange 5-gallon bucket** rgb(230, 120, 30) (about 1.3 tall × 1.1 across) with a wire bail
  handle and a **canvas pocket organizer** wrapped around the rim, with a few hand tool handles
  poking out of the pockets. Handle: at the top of the bail handle. Budget: 2,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "WrenchSet", "BladeFile", "SharpeningStone", "BenchGrinder", "SpareMowerBlade", "ToolBucket" } do
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

- Every supply: size under about 2 studs on its longest side.

Optional, while playtesting (`start_stop_play`): equip an item on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local Tools = require(game.ReplicatedStorage.Shared.Config.Tools)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local id = "WrenchSet" -- swap in each id from this file
local tool = Assets.tool(Tools.get(id).category, id)
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `WrenchSet`, `BladeFile`, `SharpeningStone`, `BenchGrinder`, `SpareMowerBlade`, `ToolBucket` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
