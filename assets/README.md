# Assets (for the modeler)

This folder becomes `ServerStorage.Assets` in the game. Anything in here replaces a
placeholder, as long as it's named after the item's `id` in `src/shared/Config/Items.luau`.
Only the server reads it, so players don't download every model when they join. The few that
client code clones are copied to `ReplicatedStorage.Assets` too, and that list is in
`default.project.json`.

- `Tools/`: one per tool tier, e.g. `ReelMower.rbxm`, `GasPushMower.rbxm`, `LeafBlower.rbxm`.
  A `Tool` with a part named `Handle` works best. A plain Model also works, and its PrimaryPart
  becomes the handle. The hand holds the handle's center with the handle's +Y pointing up and its
  front (LookVector) pointing forward. The kit tools are built by `scripts/build-kit-tools.luau`.
  In first person the player's hands grip the tool where that kind of tool is usually held (both
  sides of a handlebar, up a shaft, on a trimmer's front handle). To place them exactly, add
  `Attachment`s named `GripRight` and `GripLeft` where each hand goes (for ride-ons, on the
  steering wheel or lap bars).
- `Kit/`: the Lawn Mowing mobile kit (grass, weeds, mowers, trimmers, props) as static templates.
  Each pivot sits on the ground under the asset and faces its front. Made by
  `scripts/OrganizeLawnKit.luau` + `scripts/export-kit.luau`.
- `Trucks/`: `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck`. Face the
  front of the truck along the model's pivot front (LookVector). Add an invisible, non-colliding
  Part named `BedArea` lying on the truck bed, so loaded tools have somewhere to lie. Its `Slots`
  attribute is only a hint: how much a truck carries is `space` in `Items.luau`.
- `Trailers/`: `UtilityTrailer`, `LandscapeTrailer`, `EquipmentTrailer`, hitch facing forward,
  with its own `BedArea` part. It gets attached behind the truck automatically. The equipment
  trailer also has two invisible `BaySpot` parts where ride-on machines park.
- `Buildings/`: `Shed`, `Garage`, `SmallOffice`, `EquipmentYard`, the business upgrades, front
  door facing forward.
- `Props/`: `House` (the customer's house), `FlowerPatch` and `GardenGnome` (things players
  must not mow over). If a part in `FlowerPatch` is named `Flower`, it wilts when hit.
- `Decorations/`: the yard decorations players buy for their business (ids in
  `src/shared/Config/Decorations.luau`, specs in alphainstructions/instructions34.md). Origin on
  the ground at the centre, front toward -Z, a `Root` part, markers as attachments on it
  (`SnapL`/`SnapR`, `Light`, `Fire`, `Spout`, `Water`, `Seat`), and the moving pieces named
  `<Id>__Overgrowth`, `Mailbox__Door`, `Mailbox__Flag` and `GardenWindmill__Spinner`.
- `Props/`: `StoragePegboard`, `StorageWallRack`, `StorageWallHooks`, `StorageShelf`, the storage
  fixtures at the business. Back flat on Z = 0, front toward -Z, bottom at Y = 0, an invisible
  `Root` part as the PrimaryPart at (0, 0.5, 0), and `Slot1`, `Slot2`... attachments where tools
  go. Without slots they get spread over the front.

Save models from Studio with right-click → *Save to File* as `.rbxm` into the right folder, or
just drop them into `ServerStorage.Assets` in Studio. Rojo won't delete models added that
way.

Store models: `manifest/models.json` records every model that comes from the Creator Store (or our
own Blender work) instead of the ChatGPT packs: where it came from and how it is made to fit.
`python scripts/generate-import.py` turns it into `scripts/ImportStoreModels.luau` (`--check`
validates the manifest and writes nothing). Paste that into Studio's command bar: it inserts each
asset, cleans it, fits it and stages it in `ServerStorage.ModelImport`, printing `ok <id> ...` or
`FAIL <id> <reason>` per model. Then save `ModelImport` to a file and run
`lune run scripts/export-models <file> --overwrite` to write the `.rbxm` files in this folder. A
name the manifest gives that isn't in the model (a `keep`, a `parts` key, a `strip` item) is a
`FAIL`, so nothing ships on a guess. The file is `{ "version": 1, "complete": false, "models": [...] }`
(`complete` stays false until every id in the game has a model file or a `kept` entry), and an entry
holds:
- `id`, `folder` (`Tools`, `Trucks`, `Trailers`, `Buildings`, `Props`, `Decorations`, `Story`).
- `source`: `{ "kind": "store", "assetId", "name", "creator" }`, `{ "kind": "blender", "file" }`
  (a GLB brought in with File > Import 3D first, found in Workspace by its file name) or
  `{ "kind": "kept" }`: the current model stays, nothing else is listed and it gets no code.
- `keep`: the child Model to keep from a Store "set"; the rest is deleted.
- `facing` (`+X`, `-X`, `+Z`, `-Z`; default `-Z`): the world axis the inserted model's front points
  along, as you see it in Studio. The importer turns it to -Z. `up` is `+Y` (the only one so far).
- `fit`: `{ "axis": "height" | "width" | "length", "studs": n }`. The model is scaled evenly until
  that side of its box is `studs` long, then its bottom centre goes on the origin. Every position
  below is in that frame: +Y up, front toward -Z.
- Tools only: `handle` (`{ "position", "size" }`, an invisible `Handle` part) or `handlePart` (the
  mesh to rename `Handle`), and `grips` (`{ "left", "right" }`, the `GripLeft`/`GripRight`
  attachments on it). Everything else gets the invisible `Root` part at (0, 0.5, 0). A part or
  Model the mesh already calls `Handle` (or `Root`) is renamed `Handle_mesh` (`Root_mesh`) first,
  and the import says how many it renamed.
- `parts`: `{ "<mesh name>": { "rename", "collide" } }`, by the names the mesh arrives with.
- `markers`: `[{ "name", "position", "orientation" (degrees), "attributes" }]`, attachments on the
  `Handle` or `Root`. `boxes`: `[{ "name", "position", "size" }]`, invisible parts that don't
  collide (`BedArea`, `BaySpot`).
- `synth`: `[{ "name", "position", "size", "material", "color": [r, g, b], "hinge" }]`, plain parts
  for what a fused mesh lacks, such as the equipment trailer's ramp. `material` is an
  `Enum.Material` name, and `hinge` (optional) is where the part pivots.
- `collide`: the mesh parts' `CanCollide`. Without it, `Trucks`, `Trailers`, `Buildings` and
  `Props/House` collide and the rest don't. Either way the mesh parts get `CanQuery` on and
  `CanTouch` off, so players can still aim at a part that doesn't collide.
- `strip`: `["Class:Name"]`, instances to delete besides the scripts, sounds, effects, GUIs,
  humanoids, constraints, motors and body movers every model loses (a baked-in logo decal, say).
- `budget`: how many parts the model may have; the import says so when it goes over.
