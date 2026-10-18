# Instructions 3: Crew trucks

The crew's truck is parked at the player's business and drives the crew to every job. Players
carry their tools to the truck and load them into the bed, where the loaded tools are shown lying
down. Better trucks pay more per job.

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a lawn-care game for phones. It's
  owned by the **Big Dink Studios** group and edited in Team Create.
- Every mesh, texture and model you generate or upload must be **owned by Big Dink Studios**.
  Assets owned by anyone else won't load in the game.
- Put each finished model in **`ReplicatedStorage.Assets.Trucks`**, named **exactly** as listed below. The names are item
  ids and are case-sensitive. The game finds each model by name and uses it in place of the gray
  block placeholder, so no code changes are needed.
- Only add the models in this file. Don't create or edit scripts. Don't change
  `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets.Kit`, `ServerScriptService`,
  `StarterPlayer`, or any model already in `ReplicatedStorage.Assets`. Rojo syncs those from
  GitHub and would overwrite your edits.
- If a model with the same name is already in `ReplicatedStorage.Assets.Trucks`, leave it alone and report it.
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

## Setting up each model

- Make each one a **Model** built at the origin, standing on the ground (its lowest point at
  Y = 0), with its **front facing −Z**.
- Add an invisible Part named **`Root`** as the **first child** of the Model: Size 1 × 1 × 1,
  Transparency 1, Orientation (0, 0, 0), Position (0, 0.5, 0), Anchored on, and CanCollide,
  CanTouch and CanQuery off. Set the Model's **PrimaryPart** to `Root`. The game reads which way
  the model faces from `Root`, so never rotate it.
- Anchor every part.

## Every truck needs a bed area and a hitch

- Add an invisible Part named exactly **`BedArea`** lying flat on the floor of the cargo bed:
  Transparency 1, Anchored on, CanCollide, CanTouch and CanQuery off, Orientation (0, 0, 0), and
  Size about **6 × 0.2 × 7.6** (X across the truck, Z along it). Its top face must be level with
  the bed floor.
- Give `BedArea` a **number attribute named `Slots` set to 3**. The game lays up to 3 tools across
  the bed, spread along its length.
- Put a trailer hitch (a ball or receiver) at the bottom center of the rear, because the game
  attaches a trailer behind the truck automatically.

Specs for every truck: the front faces −Z, the wheels are about 2.6 studs across, and the body
parts are CanCollide on while small details are off. No logos, and leave license plates blank. You
can name the wheels `<ItemId>__Wheel_FL`, `_FR`, `_RL` and `_RR`. Budget: 15,000 triangles
(18,000 for the box truck).

## Models

### `RustyPickup` (the starter truck)

- An old, beat-up compact pickup: faded paint with rust patches, a dented fender, one door in a
  mismatched color, and a cracked tailgate.
- Size: about **7 wide × 6.6 tall × 16 long**. Main color rgb(150, 90, 60).

### `WorkPickup` (Work Pickup)

- A clean, modern full-size work pickup with a toolbox across the front of the bed and a ladder
  rack.
- Size: about **7 × 6.8 × 16.5**. Main color white rgb(240, 240, 240).

### `HeavyDutyPickup` (Heavy Duty Pickup)

- A heavy-duty crew-cab pickup with dual rear wheels, a tall grille, running boards and tow
  mirrors.
- Size: about **8 × 7.5 × 18**. Keep `BedArea` at about 6 × 0.2 × 7.6. Main color blue
  rgb(30, 90, 170).

### `LandscapingTruck` (Landscaping Box Truck)

- A box truck with the cab at the front and a cargo box at the back. Show the box's rear roll-up
  door open so the tools inside are visible.
- Size: about **7.4 wide × 9 tall × 18 long**. Green rgb(40, 140, 60) box with a white cab.
- Put `BedArea` on the floor inside the box, near the open rear.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Trucks
for _, id in { "RustyPickup", "WorkPickup", "HeavyDutyPickup", "LandscapingTruck" } do
	local model = folder:FindFirstChild(id)
	if not model then
		warn(id, "is missing")
		continue
	end
	local _, size = model:GetBoundingBox()
	local scripts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	print(id, model.ClassName, "size", size, "PrimaryPart", model.PrimaryPart and model.PrimaryPart.Name,
		"front", model:GetPivot().LookVector, "scripts", scripts)
	local bed = model:FindFirstChild("BedArea", true)
	print("   BedArea size", bed and bed.Size, "Slots", bed and bed:GetAttribute("Slots"),
		"invisible", bed and bed.Transparency == 1, "collides", bed and bed.CanCollide)
end
```

Expected for every model: class `Model`, PrimaryPart `Root`, front `0, 0, -1`, scripts `0`.

- Every truck: `BedArea` size about 6 × 0.2 × 7.6, Slots `3`, invisible `true`, collides `false`.
- Sizes about: `RustyPickup` 7 × 6.6 × 16, `WorkPickup` 7 × 6.8 × 16.5, `HeavyDutyPickup`
  8 × 7.5 × 18, `LandscapingTruck` 7.4 × 9 × 18.

To see it in the game, start a playtest (`start_stop_play`). `RustyPickup` is parked at the test
player's business plot, so take a `screen_capture` to check it sits on the ground with its front
toward the street, then stop the playtest.

## Done when

- [ ] `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck` are in `ReplicatedStorage.Assets.Trucks`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
