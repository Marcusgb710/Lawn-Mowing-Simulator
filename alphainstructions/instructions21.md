# Instructions 21: Equipment trailer

Ride-on and stand-on machines can only travel on an equipment trailer with a ramp. The game
hitches it behind the truck by lining up the trailer's front-bottom about 1 stud behind the
truck's rear-bottom, so **the hitch coupler must be the front-most (−Z) part and sit low**
(about 1.5–2 studs up).

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a realistic lawn-care and gardening
  game for phones. It's owned by the **Big Dink Studios** group and edited in Team Create.
- Every mesh, texture and model you generate or upload must be **owned by Big Dink Studios**.
  Assets owned by anyone else won't load in the game.
- Put each finished model in **`ReplicatedStorage.Assets.Trailers`**, named **exactly** as listed below. The names are item
  ids and are case-sensitive. The game finds each model by name and uses it in place of the gray
  block placeholder, so no code changes are needed.
- Only add the models in this file. Don't create or edit scripts. Don't change
  `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets.Kit`, `ServerScriptService`,
  `StarterPlayer`, or any model already in `ReplicatedStorage.Assets`. Rojo syncs those from
  GitHub and would overwrite your edits.
- If a model with the same name is already in `ReplicatedStorage.Assets.Trailers`, leave it alone and report it.
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

## Setting up each model

- Make each one a **Model** built at the origin, standing on the ground (its lowest point at
  Y = 0), with its **front facing −Z**.
- Add an invisible Part named **`Root`** as the **first child** of the Model: Size 1 × 1 × 1,
  Transparency 1, Orientation (0, 0, 0), Position (0, 0.5, 0), Anchored on, and CanCollide,
  CanTouch and CanQuery off. Set the Model's **PrimaryPart** to `Root`. The game reads which way
  the model faces from `Root`, so never rotate it.
- Anchor every part.

## Models

### `EquipmentTrailer` (Equipment Trailer)

- A **low tandem-axle flatbed** in black or dark gray: a wood or steel deck about 1.8 studs off the
  ground, four tires on two axles, fenders, a hitch tongue with a coupler and safety chains at the
  front, and a **fold-down mesh ramp gate** at the rear, shown folded up for travel.
- Size: about **7.5 wide × 3 tall × 18 long** (tongue included). Budget: 10,000 triangles.
- Add an invisible Part named exactly **`BedArea`** lying flat on the **front** part of the deck
  (about 6 × 0.2 × 3, its top face level with the deck), with a **number attribute `Slots` = 4**,
  for small tools.
- Add **two** invisible Parts named exactly **`BaySpot`**, lying flat on the deck behind the
  `BedArea`, one behind the other (each about 6 × 0.2 × 6). Each marks where one ride-on machine
  parks.
- `BedArea` and both `BaySpot`s: Transparency 1, Anchored on, CanCollide, CanTouch and CanQuery
  off, Orientation (0, 0, 0).

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Trailers
for _, id in { "EquipmentTrailer" } do
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
	local spots, bed = 0, model:FindFirstChild("BedArea", true)
	for _, d in model:GetDescendants() do
		if d.Name == "BaySpot" then
			spots += 1
		end
	end
	print("   BedArea Slots", bed and bed:GetAttribute("Slots"), "BaySpot parts", spots)
end
```

Expected for every model: class `Model`, PrimaryPart `Root`, front `0, 0, -1`, scripts `0`.

- `EquipmentTrailer`: size about 7.5 × 3 × 18, `BedArea` Slots `4`, BaySpot parts `2`.

## Done when

- [ ] `EquipmentTrailer` are in `ReplicatedStorage.Assets.Trailers`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
