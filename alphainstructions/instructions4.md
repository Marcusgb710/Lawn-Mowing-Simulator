# Instructions 4: Trailers

Once a player's truck bed is full, they can buy a trailer for more tool space. The game hitches it
behind the truck automatically by lining up the trailer's front-bottom about 1 stud behind the
truck's rear-bottom. That means **the hitch coupler must be the front-most (−Z) part of the
trailer, and it must sit low** (about 1.5–2 studs up).

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a lawn-care game for phones. It's
  owned by the **Big Dink Studios** group and edited in Team Create.
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

## Bed area

Like the trucks, each trailer needs an invisible Part named exactly **`BedArea`** lying flat on its
floor: Transparency 1, Anchored on, CanCollide, CanTouch and CanQuery off, Orientation (0, 0, 0),
with its top face level with the floor. Give it a **number attribute `Slots`** set to the count
below.

## Models

### `UtilityTrailer` (Small Utility Trailer)

- An open single-axle trailer: a flat 7 × 9 bed, low side rails about 1.2 tall, fenders over the
  wheels (about 2 studs across), and a fold-down rear gate. A tongue with the hitch coupler
  extends about 3 studs forward at the front (−Z).
- Size: about **7 wide × 3 tall × 12 long** (tongue included). Color rgb(110, 110, 110).
- `BedArea`: about 6 × 0.2 × 8, **Slots = 1**.
- Budget: 8,000 triangles.

### `LandscapeTrailer` (Enclosed Landscape Trailer)

- An enclosed cargo trailer with a V-nose front, tandem axles, and a rear ramp door shown open (down)
  so the tools inside are visible. A hitch tongue is at the front.
- Size: about **7.2 wide × 7.5 tall × 14 long** (tongue included). White rgb(240, 240, 240).
- `BedArea` inside, on the floor: about 6 × 0.2 × 10, **Slots = 2**.
- Budget: 10,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Trailers
for _, id in { "UtilityTrailer", "LandscapeTrailer" } do
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

- `UtilityTrailer`: `BedArea` Slots `1`. `LandscapeTrailer`: `BedArea` Slots `2`. Both `BedArea`s
  invisible `true` and collides `false`.

## Done when

- [ ] `UtilityTrailer`, `LandscapeTrailer` are in `ReplicatedStorage.Assets.Trailers`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
