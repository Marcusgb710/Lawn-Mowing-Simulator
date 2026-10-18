# Instructions 1: Yard props (house, flower patch, garden gnome)

Every job takes place in a customer's front yard, and these three models appear in every job, so
they matter most.

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a lawn-care game for phones. It's
  owned by the **Big Dink Studios** group and edited in Team Create.
- Every mesh, texture and model you generate or upload must be **owned by Big Dink Studios**.
  Assets owned by anyone else won't load in the game.
- Put each finished model in **`ReplicatedStorage.Assets.Props`**, named **exactly** as listed below. The names are item
  ids and are case-sensitive. The game finds each model by name and uses it in place of the gray
  block placeholder, so no code changes are needed.
- Only add the models in this file. Don't create or edit scripts. Don't change
  `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets.Kit`, `ServerScriptService`,
  `StarterPlayer`, or any model already in `ReplicatedStorage.Assets`. Rojo syncs those from
  GitHub and would overwrite your edits.
- If a model with the same name is already in `ReplicatedStorage.Assets.Props`, leave it alone and report it.
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

## Models

### `House`

The customer's house. It stands behind the lawn with its front door facing the street (−Z).

- A single-story suburban house with a pitched roof. The front door is centered on the front (−Z)
  wall, with 2–4 windows across the front and a small porch step.
- Size: about **30 wide (X) × 18 tall including the roof (Y) × 18 deep (Z)** studs. Keep the width
  between 26 and 32, because the smallest yard is 24 studs wide.
- Colors: light siding (white, beige or pale blue), a dark gray roof and a contrasting door.
- Walls and roof: CanCollide on.
- Budget: 12,000 triangles.

### `FlowerPatch`

A small flower bed on the lawn that players must not mow over.

- A round brown mulch bed with 5–7 bright flower clumps (red, yellow, purple).
- It must fit inside a **3.6-stud-wide circle** and stay under **1.5 studs tall**.
- **Make every flower a part named exactly `Flower`.** One MeshPart per flower clump is fine. When
  a mower hits the patch, the game shrinks the parts named `Flower` and turns everything brown.
- Budget: 1,500 triangles. Several are placed in each yard.

### `GardenGnome`

A classic garden gnome standing on the lawn, another thing players must avoid.

- About **2.4 studs tall and 1 stud wide**: a red pointed hat, a white beard, a blue or green coat
  and brown boots.
- When it's hit, the game tips it over sideways around its base, so keep `Root` at its bottom
  center.
- Budget: 1,500 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Props
for _, id in { "House", "FlowerPatch", "GardenGnome" } do
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
	local flowers = 0
	for _, d in model:GetDescendants() do
		if d.Name == "Flower" then
			flowers += 1
		end
	end
	print("   Flower parts", flowers)
end
```

Expected for every model: class `Model`, PrimaryPart `Root`, front `0, 0, -1`, scripts `0`.

- `House`: size about 30 × 18 × 18.
- `FlowerPatch`: size at most 3.6 × 1.5 × 3.6, with 5–7 `Flower` parts.
- `GardenGnome`: size about 1 × 2.4 × 1.

## Done when

- [ ] `House`, `FlowerPatch`, `GardenGnome` are in `ReplicatedStorage.Assets.Props`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
