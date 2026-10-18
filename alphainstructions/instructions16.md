# Instructions 16: Professional mowers

Top-tier commercial mowers, each built for a different kind of job: the zero-turn for big open
lawns, the stand-on for tight properties and slopes, the greens reel mower for the finest cut.

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

### `CommercialZeroTurn` (Commercial Zero-Turn)

- A big **red** rgb(200, 40, 40) commercial zero-turn: a **60-inch fabricated deck** (about 5.4
  studs wide), a **high-back suspension seat**, a **fold-up roll bar (ROPS)**, **two lap bars**,
  large rear drive tires and small front caster wheels.
- About **7.5 long × 6.3 wide × 6.8 tall** (to the top of the roll bar).
- Handle: at the middle between the two lap bar grips. The game seats the player about 0.6 studs
  below and 1 stud behind the Handle, so put the lap bar grips just in front of and above the seat
  cushion (look at the kit's `ZeroTurnMower` in `ReplicatedStorage.Assets.Tools`).
- Moving parts: each wheel `CommercialZeroTurn__Wheel_*`, and the three blades under the deck
  `CommercialZeroTurn__CutterRotor_L`, `_C` and `_R`.
- Budget: 12,000 triangles.

### `StandOnMower` (Stand-On Mower)

- A compact **orange** rgb(240, 160, 20) stand-on mower: a **52-inch deck** (about 4.7 studs wide)
  in the middle, the engine behind it, a **standing platform with a thigh pad** at the back, and
  **twin control bars** in front of the operator at chest height.
- About **6 long × 5 wide × 4.5 tall**. Handle: at the middle of the control bars. The player stands
  on the platform.
- Moving parts: wheels `StandOnMower__Wheel_*` and blades `StandOnMower__CutterRotor_*`.
- Budget: 10,000 triangles.

### `CommercialReelMower` (Greens Reel Mower)

- A walk-behind **greens reel mower** in green rgb(60, 120, 60): a **22-inch reel cutting unit**
  (a cylinder of spiral blades, about 2 studs wide) at the front, a **grass basket** in front of
  the reel, a **drum roller**, a small engine, and a handlebar about 3.5 studs above the ground.
- About **2.5 wide × 4.5 long**. Handle: at the center of the handlebar.
- Moving parts: the reel `CommercialReelMower__Wheel_Reel` and the roller
  `CommercialReelMower__Wheel_Drum` (both turn around X).
- Budget: 8,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "CommercialZeroTurn", "StandOnMower", "CommercialReelMower" } do
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

- `CommercialZeroTurn`: size about 6.3 × 6.8 × 7.5. `StandOnMower`: about 5 × 4.5 × 6.
- `CommercialReelMower`: "above bottom" about 3.5.

Optional, while playtesting (`start_stop_play`): equip an item on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local Tools = require(game.ReplicatedStorage.Shared.Config.Tools)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local id = "CommercialZeroTurn" -- swap in each id from this file
local tool = Assets.tool(Tools.get(id).category, id)
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `CommercialZeroTurn`, `StandOnMower`, `CommercialReelMower` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
