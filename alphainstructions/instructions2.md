# Instructions 2: Business buildings (tool shed, garage, small office)

Each player owns a business plot in town. The building on it upgrades from a tool shed to a garage
to a small office as the player earns money, and players see their own building all the time. The
front door faces the street (−Z).

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a lawn-care game for phones. It's
  owned by the **Big Dink Studios** group and edited in Team Create.
- Every mesh, texture and model you generate or upload must be **owned by Big Dink Studios**.
  Assets owned by anyone else won't load in the game.
- Put each finished model in **`ReplicatedStorage.Assets.Buildings`**, named **exactly** as listed below. The names are item
  ids and are case-sensitive. The game finds each model by name and uses it in place of the gray
  block placeholder, so no code changes are needed.
- Only add the models in this file. Don't create or edit scripts. Don't change
  `ReplicatedStorage.Shared`, `ReplicatedStorage.Assets.Kit`, `ServerScriptService`,
  `StarterPlayer`, or any model already in `ReplicatedStorage.Assets`. Rojo syncs those from
  GitHub and would overwrite your edits.
- If a model with the same name is already in `ReplicatedStorage.Assets.Buildings`, leave it alone and report it.
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

For all three buildings: stay within about 10% of the sizes below, because the plot has a job board
and a tool rack in front of the building. Walls are CanCollide on. Doors don't need to open, and no
interior is needed.

## Models

### `Shed` (Tool Shed, the starter building)

- A wooden backyard tool shed with a single door centered on the front (−Z) and a small window on
  one side.
- Size: about **12 wide × 10 tall (walls) × 10 deep**. The roof adds about 3 more.
- Main color: wood brown rgb(150, 105, 65).
- Budget: 8,000 triangles.

### `Garage`

- A detached work garage with a large roll-up door (about 12 wide × 9 tall) on the left half of
  the front, a regular door (4 × 7) on the right, and a pitched or flat roof.
- Size: about **26 wide × 14 tall × 20 deep**.
- Main color: light gray-beige rgb(200, 200, 190).
- Budget: 12,000 triangles.

### `SmallOffice` (Small Office)

- A small landscaping business office with a glass front door, a row of windows across the front,
  a small awning, a blank sign board above the door (no text) and a couple of planters.
- Size: about **36 wide × 16 tall × 24 deep**.
- Light walls, with green rgb(70, 120, 60) for the trim, awning and sign.
- Budget: 15,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Buildings
for _, id in { "Shed", "Garage", "SmallOffice" } do
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
end
```

Expected for every model: class `Model`, PrimaryPart `Root`, front `0, 0, -1`, scripts `0`.

- `Shed`: size about 12 × 13 × 10 (roof included).
- `Garage`: size about 26 × 14–18 × 20.
- `SmallOffice`: size about 36 × 16–20 × 24.

## Done when

- [ ] `Shed`, `Garage`, `SmallOffice` are in `ReplicatedStorage.Assets.Buildings`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
