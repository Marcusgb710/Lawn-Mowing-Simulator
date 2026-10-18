# Instructions 23: Workbench and storage racks

Players store their tools in their business building: hand tools on pegboards, long tools in
wall racks, power tools on heavy hooks. The game hangs each owned tool at a **`Slot`**
attachment on these fixtures, so the attachments matter as much as the looks.

## Where this goes

- You're working in Roblox Studio on **Lawn Mowing Simulator**, a realistic lawn-care and gardening
  game for phones. It's owned by the **Big Dink Studios** group and edited in Team Create.
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

### `Workbench` (Workbench)

- A sturdy wooden workbench: a thick top about **6.5 wide × 2.2 deep** at about **3.3 studs**
  high, a lower shelf, a **bench vise** on the front-left corner, and a **pegboard back panel**
  rising to about 6 studs with a few hanging hand tools. The side you stand at faces −Z.
- CanCollide on for the top and legs. Budget: 4,000 triangles.

### `StoragePegboard` (Storage Pegboard)

- A **wall pegboard panel** (about 4.5 wide × 3 tall × 0.2 deep) with **6 metal hooks** in a 3 × 2
  grid. Build it with its **back flat against the Z = 0 plane** (the wall), hooks sticking out
  toward −Z, and its bottom edge at Y = 0.
- Add **6 Attachments** to the panel named **`Slot1`** to **`Slot6`**, one at each hook tip,
  Orientation (0, 0, 0). A tool hangs at each one. Budget: 1,500 triangles.

### `StorageWallRack` (Storage Wall Rack)

- A **wall rack for long-handled tools** (about 5 wide × 1.5 tall × 0.8 deep) with **4 U-shaped
  holders** that hold shovels and rakes upright. Back flat against Z = 0, bottom edge at Y = 0.
- Add **4 Attachments** named **`Slot1`** to **`Slot4`**, one in each holder, Orientation (0, 0, 0).
  Budget: 1,500 triangles.

### `StorageWallHooks` (Storage Wall Hooks)

- A wooden backing board (about 3.5 wide × 1 tall) with **2 big padded utility hooks** for string
  trimmers and blowers. Back flat against Z = 0, bottom edge at Y = 0.
- Add **2 Attachments** named **`Slot1`** and **`Slot2`**, one at each hook, Orientation (0, 0, 0).
  Budget: 1,000 triangles.

## Check your work

Run this with `execute_luau`, then compare the output with the expected values below.

```lua
local folder = game.ReplicatedStorage.Assets.Props
for _, id in { "Workbench", "StoragePegboard", "StorageWallRack", "StorageWallHooks" } do
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
	local slots = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name:match("^Slot%d+$") then
			slots += 1
		end
	end
	print("   Slot attachments", slots)
end
```

Expected for every model: class `Model`, PrimaryPart `Root`, front `0, 0, -1`, scripts `0`.

- Slot attachments: `StoragePegboard` 6, `StorageWallRack` 4, `StorageWallHooks` 2, `Workbench` 0.
- `Workbench`: size about 6.5 × 6 × 2.2. The storage pieces stay under 1 stud deep.

## Done when

- [ ] `Workbench`, `StoragePegboard`, `StorageWallRack`, `StorageWallHooks` are in `ReplicatedStorage.Assets.Props`.
- [ ] The check above matches the expected values.
- [ ] Every mesh and texture used is owned by Big Dink Studios.
- [ ] Nothing else in the place was changed.
