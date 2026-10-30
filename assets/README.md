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
- `Story/`: `GloriaHouse`, `GloriaYard_Stage1` to `GloriaYard_Stage3`, `PorchDeck` and
  `PorchRockingChair`. Origin on the ground, front toward -Z, a `Root` part. The story's people
  are not here: `CastService` builds them as Roblox rigs when the server starts.

Save models from Studio with right-click → *Save to File* as `.rbxm` into the right folder, or
just drop them into `ServerStorage.Assets` in Studio. Rojo won't delete models added that
way. That is fine for a one-off. A model that should keep fitting the same way when it is
rebuilt goes through the manifest, below.

## Adding or replacing a model

`manifest/models.json` is the way to add or replace a model. It records every model that comes
from the Creator Store or our own Blender work: where it came from and how it is made to fit, so
nothing is fixed by hand in a model file and any model can be rebuilt. A model has one of three
sources, tried in this order for every id:

1. **Creator Store, free.** One object (not a "set"), unbranded or with a logo that can be
   stripped, within its part budget once cleaned, and in step with the kit. Prefer one creator's
   family for a category. The manifest keeps the asset id, name and creator, because the game does
   not own the mesh: if a creator takes it down, that is how you find it and swap it.
2. **Our own, built in Blender** (`source.kind` is `blender`), brought in with File > Import 3D as
   Big Dink Studios. For ids the Store has nothing good for.
3. **Kept** (`source.kind` is `kept`): the current model stays, and the manifest records that it
   was a decision.

The story's people are none of these: `CastService` builds them from the catalog when the server
starts (see "Models" in `docs/GAME_DESIGN.md`).

Wanted next, from the Store or Blender, are `Props/CurbMailbox` (the mailbox at the curb by every
driveway: a post with a box and a flag, front toward -Z, about 1 by 4.3 by 1.4 studs),
`Props/TruckPennant` (the streak's pennant for the truck bed: a thin pole about 3 studs tall with a
small purple flag, origin at the foot of the pole) and `Props/LeaderboardSign` (the two leaderboards
at the town spawn: front toward -Z, origin on the ground, with an invisible `Root` part whose bottom
is on the ground, two boards named `LawnsBoard` (on the left as you face the sign) and `MoneyBoard`,
each about 8 by 16 studs, which fits 25 rows at 40 pixels a stud (the client draws as many rows as
a board's size allows), and a `LeaderboardSign__Header` above the boards, which the server stamps
with the sign's name). Until a
model is in, the game stands in block placeholders for all three, built to the same rules (an
invisible `Root`, front toward -Z).

To run a batch:

1. Add or edit the entries in `manifest/models.json` (the fields are under "The manifest entry").
   To pick between candidates first, `scripts/studio/` stands each current model beside its Store
   candidates in Studio (its README says how).
2. Run `python -I scripts/generate-import.py`. It writes `scripts/ImportStoreModels.luau` from the
   manifest, and `--check` validates the manifest and writes nothing. Edit the manifest or
   `scripts/ImportStoreModels.template.luau`, never the generated file.
   `python -m unittest scripts/test_generate_import.py` runs the validator's tests and checks that
   the committed script is the one the manifest makes.
3. In Studio, in a scratch place (not the Team Create game), paste `scripts/ImportStoreModels.luau`
   into the command bar. A Blender model goes in with File > Import 3D first. The script inserts
   each asset with `GetObjects`, keeps the one child an entry names, cleans it, turns and scales it
   to fit, puts its origin on the ground, adds the contract (Handle and grips, or Root, plus the
   markers) and stages it in `ServerStorage.ModelImport`. It prints `ok <id> parts=... size=...` or
   `FAIL <id> <reason>` per model. A name the manifest gives that isn't in the model (a `keep`, a
   `parts` key, a `strip` item) is a `FAIL`, so nothing ships on a guess.
4. Save the place (Ctrl+S; a scratch place that was never saved needs Save to File) and run
   `lune run scripts/export-models <place.rbxl> --overwrite`. It writes `assets/<Folder>/<Id>.rbxm`.
   Saving `ModelImport` on its own (right-click, Save / Export, Save to File) and passing that
   `.rbxm` works too. Then delete `ModelImport` from the place.
5. Run `lune run scripts/check-models`. For every entry that isn't `kept` it checks a `Handle` with
   `GripLeft` and `GripRight` (tools) or the invisible `Root` at (0, 0.5, 0) (everything else), the
   lowest visible point on the ground, the `fit` side of the box within 10% of `fit.studs`, no
   scripts or sounds, the part budget, and the markers a truck (`BedArea`, `<Id>__Body`,
   `DriverSeat`), a trailer (`BedArea`, and for the equipment trailer `EquipmentTrailer__Ramp` and
   two `BaySpot`) or the house (`Porch`, `Driveway`) needs. It prints `Models OK` or a `FAIL` line
   per problem. `--self-test` checks the gate itself.
6. Play it. A tool is held with its grips on the handles, a truck takes its trailer and its load, the
   house stands with its porch and driveway, and nothing is the wrong size next to the kit.
7. Commit the manifest, `ImportStoreModels.luau` and the `.rbxm` files together. Each batch is
   its own PR.

## The manifest entry

The file is `{ "version": 1, "complete": false, "models": [...] }`. Set `complete` to true after
the last batch is in. Until then `check-models` lists a store entry with no file as `pending <id>`.
From then on a store entry with no file fails, and `check-models` also checks that every tool,
truck, trailer, building and decoration id in the game (`Config/Tools.luau`, `Items.luau`,
`Decorations.luau`) has a model file or a `kept` entry. An entry holds:
- `id`, `folder` (`Tools`, `Trucks`, `Trailers`, `Buildings`, `Props`, `Decorations`, `Story`).
- `source`: `{ "kind": "store", "assetId", "name", "creator" }`, `{ "kind": "blender", "file" }`
  (a GLB brought in with File > Import 3D first, found in Workspace by its file name) or
  `{ "kind": "kept" }`: the current model stays, nothing else is listed and it gets no code.
- `keep`: the child Model to keep from a Store "set"; the rest is deleted.
- `facing` (`+X`, `-X`, `+Z`, `-Z`; default `-Z`): the world axis the inserted model's front points
  along, as you see it in Studio. The importer turns it to -Z. `up` is `+Y` (the only one so far).
- `turn` (degrees, negative allowed; default 0): added to the turn `facing` makes about Y, positive
  counterclockwise seen from above, for a model drawn on a diagonal (`"facing": "-X", "turn": -45`).
- `fit`: `{ "axis": "height" | "width" | "length", "studs": n }`. The model is scaled evenly until
  that side of its box is `studs` long, then its bottom centre goes on the origin. Every position
  below is in that frame: +Y up, front toward -Z.
- Tools only: `handle` (`{ "position", "size" }`, an invisible `Handle` part) or `handlePart` (the
  mesh to rename `Handle`), and `grips` (`{ "left", "right" }`, the `GripLeft`/`GripRight`
  attachments on it). Everything else gets the invisible `Root` part at (0, 0.5, 0). A part or
  Model the mesh already calls `Handle` (or `Root`) is renamed `Handle_mesh` (`Root_mesh`) first,
  and the import says how many it renamed.
- `parts`: `{ "<mesh name>": { "rename", "collide" } }`, by the names the mesh arrives with.
- `body` (`"largest"`, `"all"` or a list of colours, Trucks only): after the `parts` renames, names
  parts `<id>__Body`. `largest` names the largest visible part, for a mesh whose parts are all
  called `Part`. `all` names every visible part except wheels, tires, rims and glass (any name with
  `Wheel`, `Tire`, `Rim`, `Glass` or `Window` in it, whatever the case), so a truck of dozens of
  loose parts takes its livery everywhere. It suits a mesh whose wheels and glass carry names. A
  list of `[r, g, b]` colours (whole numbers from 0 to 255, such as `[[111, 0, 0]]`) is for a mesh
  whose parts are all called `Part`, where no name tells a panel from a tire. It names every fully
  opaque part whose `Material` is neither `Glass` nor `Neon` and whose red, green and blue are each
  within 8 out of 255 of a listed colour's. The import fails if no part matches. With `all` or a
  list, a part already named `<id>__Body`, `__DriverDoor`, `__Tailgate` or `__RearDoor` keeps its
  name, and the import says how many parts it renamed.
- `markers`: `[{ "name", "position", "orientation" (degrees), "attributes" }]`, attachments on the
  `Handle` or `Root`. `boxes`: `[{ "name", "position", "size" }]`, invisible parts that don't
  collide (`BedArea`, `BaySpot`).
- `synth`: `[{ "name", "position", "size", "material", "color": [r, g, b], "hinge" }]`, plain parts
  for what a fused mesh lacks, such as the equipment trailer's ramp. `material` is an
  `Enum.Material` name, and `hinge` (optional) is where the part pivots.
- `collide`: the mesh parts' `CanCollide`. Without it, `Trucks`, `Trailers`, `Buildings` and
  `Props/House` collide and the rest don't. Either way the mesh parts get `CanQuery` on and
  `CanTouch` off, so players can still aim at a part that doesn't collide.
- `strip`: `["Class:Name"]`, instances to delete besides the scripts, sounds, effects, cameras, GUIs,
  humanoids, constraints, motors and body movers every model loses (a baked-in logo decal, say);
  `"*:Name"` deletes every instance with that name whatever its class (a furnished house's `Sofa`).
- `budget`: how many parts the model may have; the import says so when it goes over, and
  `check-models` fails a model over it. Without one, the model gets its folder's default.

## Importing mesh packs

This is the older route, for the packs ChatGPT made (a combined glTF and a `model_manifest.json` in
each `model-source/HighPoly/NN_*` folder). Use it when a pack arrives that way. A model that is
added or replaced from the Store or Blender goes through the manifest above instead.

1. Run `python3 scripts/generate-prepare.py`. It regenerates `scripts/PrepareChatGPTModels.luau`
   from the packs' `model_manifest.json` files.
2. In Studio, File > Import 3D with Creator Big Dink Studios (it resets to "Me" on every file),
   World Forward: Back, Scale Unit: Meter, and Anchored.
3. Paste `scripts/PrepareChatGPTModels.luau` into the command bar. It strips the importer's `_Node`
   suffix, adds the Handle or Root, the markers, each part's collision and the hinge pivots, and
   stages the models in `ServerStorage.ModelImport`.
4. Right-click `ServerStorage.ModelImport`, Save / Export, Save to File, and run
   `lune run scripts/export-models <file>.rbxm --overwrite`. Without `--overwrite`, a model that
   already has a file is skipped.
5. Delete `ModelImport` from Studio.
