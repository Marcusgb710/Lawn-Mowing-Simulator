# Instructions 15: Wheelbarrows, cart, spreader and sprayer

Hauling and lawn application. The wheelbarrows are variants with real tradeoffs (one wheel or
two, air tire or flat-free), so the tires must look right: an **air tire** is a pneumatic tire
with tread and a valve stem, and a **flat-free** tire is solid black foam.

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

For the wheelbarrows, cart and spreader: put the Handle **between the grips**, at their real height
(about 2.5–3.5 studs above the ground). Name each wheel with `__Wheel` (e.g.
`SingleWheelbarrow__Wheel_Front`) so it rolls.

### `SingleWheelbarrow` (Wheelbarrow)

- A 6-cubic-foot **green steel tray** rgb(40, 110, 50), **one air-filled tire** (about 1.4 studs
  across, with tread and a valve stem) at the front, two long wooden handles and two rear legs.
- About **5.4 long × 2.4 wide**; grips about 2.6 studs above the ground. Budget: 4,000 triangles.

### `SingleWheelbarrowFlatFree` (Flat-Free Wheelbarrow)

- The same layout with a **red tray** rgb(180, 40, 40) and **one solid black foam tire** (no valve
  stem, smooth chunky sidewall). Budget: 4,000 triangles.

### `DualWheelbarrow` (Two-Wheel Wheelbarrow)

- A **yellow tray** rgb(230, 170, 30) over **two air tires side by side** at the front, with a
  **single loop handle** across the back instead of two handles.
- About **5 long × 2.8 wide**. Handle: at the center of the loop handle. Budget: 4,500 triangles.

### `PolyCart` (Yard Cart)

- A big **blue molded plastic tub** rgb(40, 90, 160) (about 4.5 long × 2.6 wide × 2 tall) on **two
  wide solid wheels** near the back, with a **loop handle** at the back for pushing or pulling.
- Handle: at the center of the loop handle. Budget: 4,000 triangles.

### `BroadcastSpreader` (Broadcast Spreader)

- A walk-behind push spreader: an **orange hopper** rgb(230, 120, 30) on a steel frame, a **flat
  spinning plate** under the hopper outlet, **two air tires**, and a tall push handle with a flow
  lever.
- About **2.5 wide × 3 long**; handle about 3.5 studs above the ground. Handle: at the center of the
  push bar. Name the spinner plate `BroadcastSpreader__CutterRotor` so the game spins it.
- Budget: 4,000 triangles.

### `BackpackSprayer` (Backpack Sprayer)

- A **yellow 4-gallon plastic tank** rgb(240, 200, 40) (about 1.8 tall × 1.3 wide × 0.8 deep) with
  shoulder straps, a **side pump lever**, and a hose leading to a **spray wand with a trigger**.
- The game puts the wand's grip in the right hand. Put the Handle on that grip and aim the wand
  forward and down. Place the tank about **2.3 studs behind (+Z), 1 stud to the left (−X) and
  1 stud below** the Handle, so it sits roughly on the player's back.
- Budget: 3,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Tools
for _, id in { "SingleWheelbarrow", "SingleWheelbarrowFlatFree", "DualWheelbarrow", "PolyCart", "BroadcastSpreader", "BackpackSprayer" } do
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

- Wheelbarrows and cart: "above bottom" about 2.5–3. `BroadcastSpreader`: about 3.5.

Optional, while playtesting (`start_stop_play`): equip an item on the test player to see it held,
then take a `screen_capture`.

```lua
local Assets = require(game.ReplicatedStorage.Shared.Assets)
local Tools = require(game.ReplicatedStorage.Shared.Config.Tools)
local player = game.Players:GetPlayers()[1]
local humanoid = player.Character:WaitForChild("Humanoid")
local id = "SingleWheelbarrow" -- swap in each id from this file
local tool = Assets.tool(Tools.get(id).category, id)
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

## Done when

- [ ] `SingleWheelbarrow`, `SingleWheelbarrowFlatFree`, `DualWheelbarrow`, `PolyCart`, `BroadcastSpreader`, `BackpackSprayer` are in `ReplicatedStorage.Assets.Tools`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
