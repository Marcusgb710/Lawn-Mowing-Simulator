# Model overhaul: real hardware, Roblox people

Design, 2026-10-28. Owner: Avery. Status: draft for approval.

## Why

Avery's words: "make the characters Roblox characters, and redo all the models, especially the
grass and the buildings, as well as vehicles and tools"; the game "should feel like mowing real
grass and progressing like a Steam indie game".

Today every model in `assets/` is a low-poly mesh ChatGPT generated from a text brief (TODO.md,
"Models": "simpler low-poly models than the original kit; the trucks especially are boxy"). The
story's people are statues: two mesh parts each, no rig, no face that moves, no animation. The
grass is already a painted surface since fluid mowing (PR 65), but it is painted with flat colours
and round dots, not grass.

A Steam lawn sim sells the fantasy with hardware that looks like the real thing and a yard that
looks like a real yard. Roblox sells its people as Roblox avatars: that is what every player
already is, and what reads as "a person" on this platform. So the direction, approved from the
lineup Avery saw in Studio: **real hardware, Roblox people.**

## Goals

- **People are Roblox avatars.** Every story character is an R15 rig dressed from the catalog,
  with a face, hair and clothes, playing an idle, sit, wave or walk. No more statues.
- **Hardware looks real.** Mowers, trimmers, blowers, barrows, trucks, trailers, the shed and the
  customer's house are replaced with realistic, correctly proportioned meshes. The player should
  recognise a push mower, a zero-turn, a work pickup at a glance.
- **Grass looks like grass.** The turf shows a real lawn texture, the stripes are tints on it, and
  the shells are blade tufts instead of dots. Far lawns still look like lawns.
- **One pipeline, repeatable.** Replacing a model is: add a manifest entry, run the import in
  Studio, export, run the check. Nothing is hand-fixed in a model file.
- **Nothing costs money.** Creator Store assets that are free, Roblox-made catalog items that are
  free, Roblox's own animations, and the hosted Blender that comes with the plan Avery already
  has. No credits, no Robux, no commissions without Avery saying so.
- **Phones keep up.** A part budget per category, and a phone check in Play before release.
- **Nothing else breaks.** Tools are still held by a Handle with the hands on the grips, trucks
  still have a BedArea and a driver's door, buildings still have their interior markers, story
  scenes still place people on their markers, speech bubbles still hang over heads.

## Non-goals

- The player's own character. First person stays; other players see the usual avatar. The
  first-person arms stay the simple arms (tinting them to the player's avatar is a later idea).
- Held props for the cast (Gloria's teacup, Chad's clipboard, June's mug). Rigs come empty-handed.
- Character voices, lip sync, facial animation beyond Roblox's default face.
- Redoing the kit (weeds, curbs, cones, bins, rocks, shrubs). It already has the target look.
- Redoing the GUI art, the trophy, the delivery boxes, storage fixtures and the junk in the grass.
  They are small or rarely seen; a swap list goes in TODO.md.
- New items, prices or balance. Every id in `Config/Tools.luau`, `Items.luau` and
  `Decorations.luau` keeps its id and its stats.
- Making the yards themselves (the lots, driveways, fences, sidewalks). That is level art, its own
  project after this one.

## Anti-goals (what would make this a failure even if it works)

- A branded game. A mesh with a baked-in "Honda" or "John Deere" logo does not ship. Unbranded or
  strippable only.
- A mixed-up scale. A trimmer taller than the mower, a shed the player cannot walk into, a truck
  the trailer floats behind. Every model is normalised to a real-world size.
- A model zoo. Thirty creators' meshes with thirty looks. Curation prefers one creator's family
  for a category (the push, self-propelled and riding mowers from one hand where possible), and the
  importer flattens materials to the game's palette where a mesh is garish.
- Breaking a job. A new model that loses its grips, bed, door, slot or spot marker, so a tool
  hangs wrong, a truck will not load, a desk will not sit at.
- A phone that stutters at the shop. The 800-part "set" models from the Store never ship as is.

## Constraints

- **Roblox:** Rojo 7.7.1 syncs `assets/<Folder>/<id>.rbxm` into `ServerStorage.Assets`. Models
  come out of Studio, not out of a text pipeline: Creator Store assets can only be inserted inside
  Studio (`game:GetObjects("rbxassetid://id")` in the command bar), and mesh files can only be
  imported with File → Import 3D. Lune (`@lune/roblox`) reads and writes `.rbxm`, so checks and
  exports run from the terminal.
- **Meshes from the Store reference their creators' mesh ids.** The game does not own them. If a
  creator deletes or Roblox moderates an asset, that mesh goes blank in the game. Accepted: the
  manifest records every source id so a lost one is found and swapped, and `check-models` fails
  loudly when a model has no visible parts.
- **Creator Store licence.** Free Store assets are licensed for use in any experience. The manifest
  records the asset id, name and creator for every one.
- **Catalog items for NPCs** are applied through `HumanoidDescription` at runtime and must be
  public. Roblox-made items (creator "Roblox", free) are the safe set; `cast-check.py` verifies
  every id against the catalog before it ships.
- **The Open Cloud key** publishes places only (`scripts/publish.py`). Image uploads need the
  Assets scope: either Avery adds it to the key, or the three lawn images and the tuft sheet go up
  through Studio's Asset Manager by hand (ids pasted into `Config/GrassArt.luau`).
- **Hosted Blender** (the `scene_builder_3d` tools: `bpy` 5.2, no network, five minutes per
  operation, GLB export) is the only modeller available. It builds from primitives by script, so
  "make our own" means a clean, well-proportioned, PBR-shaded low-poly model, not a sculpt. It is
  the fallback for things the Store has no good match for, and its output goes through Import 3D
  exactly like the ChatGPT packs did.
- **Budgets** (parts per model, checked by `check-models`): hand tool 12, long tool 20, machine
  (mower, trimmer, blower, spreader) 120, barrow or cart 40, supply 12, truck 160, trailer 80,
  shed 150, house 300, big building 400, decoration 40, NPC rig: whatever the catalog gives.
- **Contract every model keeps** (`src/shared/Assets.luau`, `assets/README.md`): built at the
  origin, standing on the ground, front toward −Z. Tools: a part named `Handle`, +Y up, front −Z,
  `GripLeft`/`GripRight` attachments where the hands go, wheels and rotors named `<Id>__Wheel` /
  `<Id>__CutterRotor` / `<Id>__Spool` so they spin. Everything else: an invisible `Root` part as
  PrimaryPart at (0, 0.5, 0). Trucks: `BedArea`, the main body mesh named `<Id>__Body` (what
  `Premium.applyPaint` and the TurfKing livery tint), a `DriverSeat` attachment, and when the mesh
  has them as separate parts, `<Id>__DriverDoor` / `__DriverDoorGlass` / `__Tailgate` pivoted on
  their hinges (`Openings.luau` swings them). Trailers: `BedArea`, `<Id>__Ramp` on the equipment
  trailer (synthesised as a flat slab when the mesh has none) with two `BaySpot` parts. Buildings:
  the interior markers from their manifests (`Mount`, `FloorSpot`, `Desk`, `DeliverySpot`,
  `TruckParking`, `UseSpot`, `ScreenView`). The customer's house: `Porch` and `Driveway`
  attachments. Story people: `Head` (eye level) and `Talk` (chest) attachments.
- **Gates:** `lune run scripts/check-models` (new), `scripts/cast-check.py` (new),
  `lune run scripts/check-mowing`, `check-gui`, `check-story`, `selene src`, `stylua --check src`,
  `rojo build`.

## The design

### 1. The look

Two registers, on purpose:

- **Hardware, buildings, yards: grounded.** Real proportions (a push mower's handle at hip height,
  a zero-turn as wide as a door), real materials (painted steel, black plastic, rubber tyres, cedar,
  brick, shingle), muted real colours, no cartoon outlines, no brand marks. The kit (weeds, curbs,
  cones) already sits here; new models have to sit next to it without looking like toys or like
  photographs.
- **People: Roblox.** Standard R15 bodies and faces, catalog clothes, the default smile. Not Rthro,
  not custom heads. The cast reads as "Roblox people in a real yard", which is also what the player
  looks like to everyone else.

Scale: 1 stud = 0.28 m (Roblox's own), so an R15 person is about 5.5 studs, a push mower's handle
about 3.7 studs, a pickup about 19 studs long, a shed 10 × 12 studs. The manifest gives every model
one target size and the importer scales to it, so the whole set sits at one scale regardless of who
made the mesh.

### 2. Where models come from

Three sources, tried in this order for every id:

1. **Creator Store, free.** Searched with the toolbox API, judged from thumbnails and then in
   Studio. A candidate passes when it is unbranded (or its brand is a strippable decal), one object
   (not a "set"), within budget after cleaning, and reads right next to the kit. Preferred: one
   creator's family for a category.
2. **Our own, built in hosted Blender** from primitives with PBR materials, exported as GLB and
   imported with File → Import 3D as Big Dink Studios. For ids the Store has nothing good for.
   Expect the long tail of pro machines (stand-on aerator, slit overseeder, dethatcher, ride-on
   spreader) and odd hand tools (broadfork, dibber, soil probe) here.
3. **Keep the current model.** When neither beats it, or when it is too small to matter (a blade
   file, a sharpening stone, a patch kit). The current model stays, listed as "kept" in the
   manifest so the decision is recorded.

The cast is none of these: people are built from the catalog at runtime (section 4).

### 3. The manifest and the import pipeline

`assets/manifest/models.json` is the single list of where every replaced model came from and how
it was made to fit. One entry per id:

```json
{
  "id": "GasPushMower", "folder": "Tools",
  "source": { "kind": "store", "assetId": 18744991009, "name": "...", "creator": "..." },
  "keep": "Mower_Red",
  "facing": "+X", "up": "+Y",
  "fit": { "axis": "height", "studs": 3.7 },
  "handle": { "position": [0, 3.4, 1.9], "size": [1.6, 0.2, 0.2] },
  "grips": { "left": [-0.8, 3.5, 1.9], "right": [0.8, 3.5, 1.9] },
  "parts": { "wheel_fl": { "rename": "GasPushMower__Wheel" } },
  "markers": [ { "name": "DriverSeat", "position": [0, 0, 0], "orientation": [0, 0, 0], "attributes": {} } ],
  "boxes": [ { "name": "BedArea", "position": [0, 0, 0], "size": [1, 1, 1] } ],
  "collide": false,
  "strip": ["Decal:HondaLogo"],
  "budget": 120
}
```

- `source.kind` is `store`, `blender` (then `file` names the GLB under `model-source/Blender/`) or
  `kept`.
- `keep` names the one child Model to keep from a Store "set"; the rest are deleted.
- `facing` and `up` say which of the mesh's own axes point forward and up; the importer rotates the
  model so its front is −Z and +Y is up. `fit` scales it uniformly so that one axis of its bounding
  box is `studs`. Positions after that are in the normalised frame: origin at the bottom centre.
- `handle`, `grips`, `parts`, `markers`, `boxes` add the contract. For a `Tool` the importer creates
  an invisible `Handle` part at `handle` (or renames `handlePart` if a mesh is the handle) and the
  grip attachments. For everything else it adds the `Root` part at (0, 0.5, 0).
- `synth` lists plain box parts to build (`name`, `position`, `size`, `material`, `color`, and an
  optional `hinge` point for the pivot), for a trailer ramp a fused mesh lacks.
- `strip` lists instances to delete by class and name beyond the defaults.

The importer, `scripts/ImportStoreModels.luau`, is generated from the manifest by
`scripts/generate-import.py` (the same pattern as `generate-prepare.py`), pasted into Studio's
command bar. For each entry it inserts the asset (`game:GetObjects`), keeps one child, deletes
scripts, sounds, particles, GUIs, humanoids, seats and constraints, turns seats and unions into
parts, anchors everything, rotates and scales, moves the origin to the ground centre, adds the
contract pieces, applies `collide`, and stages the result in `ServerStorage.ModelImport.<Folder>`.
It prints one line per model: parts, size, anything it could not find. Then, as today:
Save `ModelImport` to a file, `lune run scripts/export-models <file> --overwrite`, delete
`ModelImport`.

A Blender-made model goes through File → Import 3D first; the manifest entry's `source.kind` is
`blender` and the importer finds it in the imported folder by name instead of inserting it.

`scripts/check-models.luau` (Lune) is the gate. For every `assets/<Folder>/<id>.rbxm` it checks:
a `Handle` (Tools) or `Root` (others) part, the pivot on the ground within 0.1 stud, the bounding
box within 10% of the manifest's `fit`, no scripts or sounds, at least one visible part, part count
within the category budget, the required markers for the category (BedArea on trucks and
trailers, DriverSeat on trucks, BaySpot ×2 on EquipmentTrailer, Porch on the houses), and that every
id in `Config/Tools.luau`, `Items.luau` and `Decorations.luau` has either a model file or a `kept`
manifest entry. It prints `OK` or every failure.

### 4. The cast: Roblox avatars

`src/shared/Config/Cast.luau` describes each story person once:

```lua
NPC_Gloria = {
    name = "Gloria Pemberton",
    body = { skin = Color3.fromRGB(234, 184, 150), heightScale = 1.05, widthScale = 1, headScale = 1 },
    hair = 376526888, hairColor = Color3.fromRGB(205, 205, 205),
    hat = nil, face = nil,
    shirt = 398634295, pants = 398634487, -- classic shirt and pants ids (type 11 and 12)
    layered = {}, -- { { id = ..., type = Enum.AccessoryType.Sweater, order = 1 } }
    pose = "Idle", -- Idle, Sit, Wave, Inspect, Note (looping animations in Cast.Poses)
    seat = nil, -- for NPC_June_Sitting: offset from the chair's origin to the hips
}
```

Every id is a free catalog item, Roblox-made where one fits (the lineup used Straight Blonde Hair
recoloured silver, Pastel Starburst Top, Beautiful You Jeans for Gloria; Blonde Spiked Hair,
Roblox Baseball Cap, Blue Plaid Shirt, Jean Shorts for Chad), and from any creator when identity
needs it (ruling 3). A `tshirt` field names an uploaded image for a T-shirt graphic (the TurfKing
crown on purple). `hairColor` recolours the hair mesh (texture off, colour on) because the free
catalog has no grey hair. `Cast.Poses` maps pose names to Roblox's own animation ids (R15 idle,
sit, wave, point) so nothing has to be uploaded.

`src/server/Services/CastService.luau` builds every rig once at startup, before any yard is built:
`Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)`, then the hair
recolour, then the contract: an invisible `Root` part welded at the feet as PrimaryPart (so
`Assets.placeAt` stands the person exactly where the statue stood), a `Head` attachment at eye
level and a `Talk` attachment at the chest (speech bubbles and the talk prompt), Humanoid name and
health display off, the HumanoidRootPart anchored and the rest free so animations play. The rig is
named `<id>` and parented into `ReplicatedStorage.Assets.Story`, where `Assets.story(id)` already
looks, so GloriaService, GrandmaJune and ContestController get a rig with no change to how they
place it. The statue files `assets/Story/NPC_*.rbxm` are deleted. If a rig cannot be built (an
asset offline), CastService warns and that id falls through to today's placeholder.

`src/shared/NpcAnimator.luau` starts a rig's looping pose: the server for rigs it places, the
client for the judges it clones and walks. The judges' walk plays Roblox's R15 walk while they
move and idle when they stop, instead of the bob. June sits: the sit animation, placed with
`seat` so her hips land on the rocker's seat.

`scripts/cast-check.py` asks the catalog API for every id in `Cast.luau`: it exists, it is free, it
is by Roblox, and its asset type matches its slot. It is part of the gates.

### 5. Grass: a lawn texture and blade tufts

The kit shipped three 512 × 512 tiling colour maps that were never uploaded
(`art-source/GUI/Source/RenderOnly/Textures/Lawn_Uncut_Color.png`, `Lawn_Mown_Color.png`,
`Soil_Color.png`). Add a fourth, made here: `Grass_Tufts.png`, a 256 × 256 sheet of 8 grass-blade
tufts with alpha. All four go up as Images under Big Dink Studios and their ids live in
`src/shared/Config/GrassArt.luau`.

`GrassPaint` and `GrassController` change three things and nothing else (ruling 4):

- **The turf part** gets the mown-lawn map as a tiling `Texture` (one tile per 8 studs) under the
  painted Decal, near and far alike, so fine detail comes from the texture and the painted image
  carries only what changes. Mown pixels in the painted image are translucent tints (light for a
  pass away from the street, dark coming back) over that texture; uncut pixels are an opaque
  mottle sampled from the uncut map (loaded once per session with
  `AssetService:CreateEditableImageAsync`); bare ground is the soil map's colour.
- **A shell** stamps tufts from the sheet at the dot positions `GrassImages` already computes
  (same seed, same count, so the phone budget and the cut hole logic are unchanged), each tuft
  tinted darker on the low shells and lighter on top, instead of drawing circles. A tuft is a
  clump about one stud across.
- **Far lawns** (beyond the 200-stud draw distance, where nothing is drawn today) show the same
  tiling texture on the turf part, so they read as lawn from the truck and match the near look.

If an image asset cannot be loaded (toggle off, moderation, memory), GrassPaint falls back to
today's colours and dots, with one warning, the same way GrassFallback already covers the no-image
case.

### 6. Hardware, vehicles and buildings: the curation order

Curation is Avery's chief of staff's job in Studio, with the lineup script from this round
(now `scripts/lineup.luau`: it stands "now" and "candidate" side by side with labels and walks a
camera past them). It goes in this order, each batch imported and checked before the next:

1. **Mowers and trimmers** (what the player holds most): ReelMower, GasPushMower,
   SelfPropelledMower, RidingMower, ZeroTurnMower, CommercialZeroTurn, StandOnMower,
   CommercialReelMower, ElectricTrimmer, GasTrimmer, Brushcutter, StraightShaftTrimmer.
2. **Blowers, edgers, hedge trimmers, barrows and carts, spreader and sprayer, gas cans and
   bucket:** LeafBlower, BackpackBlower, the four edgers, the four hedge trimmers,
   SingleWheelbarrow, SingleWheelbarrowFlatFree, DualWheelbarrow, PolyCart, BroadcastSpreader,
   BackpackSprayer, GasCan, MixGasCan, ToolBucket.
3. **Vehicles:** RustyPickup, WorkPickup, HeavyDutyPickup, LandscapingTruck, UtilityTrailer,
   LandscapeTrailer, EquipmentTrailer. TurfKingTruck stays the heavy-duty pickup in the purple
   livery `Assets.turfKingTruck` already paints.
4. **The customer's house:** Props/House (exterior only, with `Porch` and `Driveway`). It stands on
   every job lawn, so it is the one building that ships early.
5. **Long-handled and hand tools** (shovel, spade, forks, rakes, hoe, mattock, loppers, saw,
   pruners, snips, trowels, weeder, dibber, cultivator, hose wand, watering can, gloves).
6. **Pro machines:** the aerators, overseeder, dethatcher, ride-on spreader, soil probe.
7. **The business buildings, together:** Shed, Garage, SmallOffice, EquipmentYard. Players
   upgrade through them in that order, so they change in one batch or not at all: a new shed next
   to the old garage is the model zoo. They carry the most markers and the most code depends on
   them, so they go last, and all four current ones stay until all four new ones pass
   `check-models` and a walk-through in Play.

Decorations, storage fixtures, delivery boxes, the junk, the trophy, Gloria's house with her yard
stages, porch, rocker and sign are kept; their swap list is in TODO.md.

### 8. Rulings from the builder check (2026-10-28)

A fresh engineer read this document and asked eight questions before planning. The answers:

1. **Fused Store vehicles are allowed.** A pickup that is one mesh keeps its baked tailgate and
   loses the tailgate swing; `Openings.luau` ignores parts that are not there and loading uses
   `BedArea`, which the manifest always adds. Paint jobs survive through the `<Id>__Body` rename
   (`Premium.applyPaint` tints that part's colour; `check-models` fails a truck without it). The
   equipment trailer's ramp is load-bearing for ride-ons, so the importer can synthesise it: the
   manifest's `synth` list builds plain box parts (name, position, size, material, colour, hinge
   pivot) in the normalised frame, used for ramps and nothing fancier.
2. **Gloria's house, her yard stages, porch, rocker and sign stay this round.** They are a
   matched set built to one footprint. `Story/TurfKingTruck.rbxm` is deleted so the TurfKing truck
   is the new heavy-duty pickup in the purple livery, like every other truck.
3. **Cast identity beats the "Roblox-made only" rule.** When no free Roblox item carries a
   character's identity (TurfKing purple and gold, June's straw hat), the entry may use a free,
   on-sale, non-limited item by any creator, or a T-shirt graphic from an image we upload (free).
   `cast-check.py` verifies free, public and not limited; "by Roblox" is preferred, not required.
   Chad and Sam must read as TurfKing.
4. **Grass is a tiling texture under a translucent painted layer.** At 4 pixels per stud the
   painted image cannot carry blades, so the turf part gets the mown map as a tiling `Texture`
   (one tile per 8 studs) and the EditableImage above it paints only what changes: stripes as
   translucent tints, the uncut state as an opaque mottle from the uncut map, bare ground from the
   soil map. Tufts on the shells are clumps about one stud across, on purpose. The far-lawn
   `Texture` is the same tiling texture, so near and far match. Whether the key can upload the
   images is tested in the first task; if not, Avery's Asset Manager step stands.
5. **Release gate and PRs.** Batches 1 to 4 are the release of this project; 5 to 7 follow on the
   same branch or their own, Avery's call at the time. Each batch is its own PR. "Kept" counts as
   done. The business buildings change together (batch 7) so the upgrade ladder never mixes looks.
6. **Phone line: no worse than today.** On the Galaxy A06 preset, the shop with every rack full
   and a job with the truck, trailer and house in view, average frame time within 10% of the
   current build in the same scenes. On a miss the importer's `strip` list trims the model, then
   the candidate is swapped, then the id is "kept". Triangles are not countable from Luau, so this
   test is the triangle budget.
7. **Static wheels, rotors and spools are acceptable.** Name them when the mesh has them as
   separate parts; `check-models` does not require them. First person rarely sees a mower's wheel.
8. **The Studio steps are driven from this chat** through computer use on Avery's PC (Studio is
   already granted). Avery is not needed at the keyboard for a batch.

### 7. What has to happen outside the code

- **Avery:** add the Assets read/write scope to the Open Cloud key (or upload the four images in
  Studio's Asset Manager and paste the ids), and say when to publish.
- **Studio runs:** every import batch is a Studio session (insert, stage, save, export) driven from
  this chat. Blender-made models add an Import 3D step.
- **A phone check** on the Galaxy A06 preset at the shop with every tool on the racks, and on a
  job with the truck, trailer and house in view.

## Left to the builder

- The exact catalog ids and body scales for each of the nine cast entries, within the brief in
  `alphainstructions/instructions37.md` (June small and sharp, Gloria tall and immaculate, Chad in
  purple and gold, Sam 17 and gender-neutral, Edna warm and round, the two fussy judges).
- Which Roblox animation ids stand in for Inspect and Note (a point or an idle variant).
- The tuft sheet's art: eight tufts, 64 × 64 each, two tones.
- Marker positions for every imported model, measured in Studio.
- Part budgets can move 20% either way if a category needs it, in `check-models` and here.

## Playtest checklist (goes into TODO.md when built)

- Every tool on the shop racks and in the truck bed, held in first person: grips on the handles,
  nothing clipping the camera, wheels spinning on mowers.
- A job start to finish with the new truck and trailer: loading, the drive, the house and shed in
  view, the customer's porch.
- Gloria's porch scene, June on her rocker, Chad by the TurfKing truck, the judges' walk: bubbles
  over heads, prompts at chests, idle and sit playing, nobody floating or sunk.
- Grass: stripes on the texture at a job and at home, tufts from eye level, far lawns from the
  road, and the no-image fallback still playable.
- Galaxy A06 preset: the shop with every rack full, and a job with everything in view, with the
  frame time next to today's.
