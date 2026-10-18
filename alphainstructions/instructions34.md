# Instructions 34: Yard decorations for the player's own lawn

Players have their own front lawn at their business. The only things they do outside the shop at
home are **decorating that yard and keeping it mowed and trimmed**, which earns them bonus money
(curb appeal). This file is the catalogue of decorations they buy from the shop computer and place
on their lawn in first person. Some are also things they have to keep tidy, like shrubs to trim.

## What this is

These are **new models**; there's no current version in the game. Build them at the same high
level of detail as the high-poly pass (instructions 24–32): realistic, accurate and clearly better
than the original Lawn Mowing kit. The quality reference is the original kit: see
`model-source/RevisedLawnModels/OriginalKitPreviews/`. The kit's 21-inch push mower, for example,
is about 7,100 triangles with a real engine, deck, wheels and handle.

## What to deliver

Mesh sources in the same format as `model-source/PhaseA_NewModels/`, in
**`model-source/HighPoly/34_YardDecorations/`**:

- `Models/<Id>/<Id>.gltf` with its `.bin`, plus `<Id>.fbx`, for every model in this file.
- **One combined library, `ALL/34_YardDecorations.gltf`**, with every model as a top-level node at
  its own spot in a grid (translation only, no rotation or scale on that node) and its meshes as
  child nodes. This is the file that gets imported into Studio.
- `model_manifest.json` using the same fields as `model-source/PhaseA_NewModels/model_manifest.json`
  for every model: `name`, `folder`, `dimensions_studs`, `bounds_min_studs`, `bounds_max_studs`,
  `primary_part`, `primary_position_studs`, `markers`, `slots`, `triangles` and `mesh_objects`.
  `primary_part` is `Root` at (0, 0.5, 0) for every model here.
- One shared set of PBR textures for the whole file in `Textures/` (Color, Roughness, Metalness,
  and Normal if used), each at most 2048 × 2048.
- Renders in `Previews/`: each model on its own, plus **one render of a decorated front lawn**
  using a mix of them (fence along the front, a paver path to the door, edging around a mulch bed
  with shrubs, a bench and a lamp post).

Don't change `assets/`, `src/`, the existing `model-source/` packs, or anything outside your
folder. The local Claude session imports your library into Studio as Big Dink Studios and puts the
models into the game.

## Rules for every model

- **Ids** exactly as listed below (case-sensitive). Every model here goes in the new
  **`Decorations`** folder.
- **Axes and units**: Roblox axes, +Y up, **front facing −Z** (the side that faces the street).
  Author in metres, with 1 stud = 0.28 m (1 inch = 0.09 stud, 1 foot = 1.09 studs). A player is
  about 5 studs tall.
- **Origin** on the ground at the centre of the footprint, with the lowest point at Y = 0. Things
  that sit in the ground (stakes, posts, edging) go no deeper than Y = −0.3, and their visible base
  meets the ground cleanly, so they look planted on a flat lawn.
- **Overall size** within 10% of the sizes given below (W × H × D, in studs).
- **Part names**: the main body is `<Id>__Body`. Every other piece the game moves, hides or lights
  is its own mesh, named as below.
- **Markers** are named points (empty nodes in the glTF, listed in the manifest's `markers`, with
  position and orientation). The local session turns them into Attachments:
  - `Light`: where the game puts a lamp (inside the lantern or bulb).
  - `SnapL` and `SnapR` on pieces that join end to end (fences, edging, paths, beds): at the
    centre of each joining end, on the ground, LookVector pointing **outward** along the run. Two
    pieces placed with one's `SnapR` on the next one's `SnapL` must meet with no gap and no overlap.
  - `Water`: the centre of the water surface, for ripples and splashes.
- Glass, water and other transparent pieces are separate meshes.
- No scripts, lights, particles, logos, brand names or readable text. Flags and signs are plain.

## Raise the detail

- **Model the real thing.** True proportions and real thicknesses: fence pickets about 0.75 in
  thick, cast stone with soft worn edges, real hinges, bolts and post caps.
- **Smooth, not faceted.** Round sections get at least 24 segments. Hard edges get 2–3 bevel
  segments with weighted normals.
- **Nothing floats.** Lanterns screw onto posts, feeders hang from hooks, planters sit on the
  ground with soil inside.
- **Plants read as real plants**: layered leaves and petals with alpha-free geometry or clean
  cards with backfaces, varied colour, and no flat green blobs. Keep each plant model's leaves in
  one or two meshes.
- **Materials**: distinct looks for painted wood, weathered cedar, cast stone, concrete, terracotta,
  black powder-coated metal, galvanized steel, plastic, glass, water, mulch and foliage, using
  colour, roughness and metalness.
- **Triangle budgets** per model, for phones. Roblox allows at most 20,000 triangles per mesh.

  | Kind | Triangles |
  | --- | --- |
  | Small decorations (path light, flamingo, edging, pavers) | 800–3,000 |
  | Medium decorations (bench, bird bath, mailbox, planters, shrubs) | 2,500–7,000 |
  | Large decorations (arbor, fountain, tree, patio set) | 6,000–14,000 |

## Models

### Borders and paths (they snap end to end)

#### `PicketFenceSection` (Decorations)
A white painted wooden picket fence panel: pointed pickets with gaps, two rails behind, and a post
at each end with a cap. About **8.6 × 3.2 × 0.4**, running along X. `SnapL` and `SnapR` at the
centre of the end posts' outer faces, so the next panel shares the post line without doubling it.

#### `StoneEdgingSection` (Decorations)
A run of tumbled natural-stone edging blocks, slightly uneven, set into the turf. About **4.3 ×
0.55 × 0.9**, running along X, with `SnapL` and `SnapR`.

#### `PaverPathSection` (Decorations)
A square of interlocking concrete pavers in a herringbone pattern with a soldier-course border,
almost flush with the lawn (top at about 0.15). About **4.3 × 0.2 × 4.3**. `SnapL` and `SnapR` on
the **−Z and +Z** ends (the path runs from the street toward the door), each pointing outward.

#### `MulchBedSection` (Decorations)
A rectangular mulch bed with a black steel landscape-edging border, lumpy shredded-bark mulch,
and nothing planted (players put shrubs and flowers in it). About **8.6 × 0.4 × 4.3**, running
along X, with `SnapL` and `SnapR`.

### Plants (players have to keep these tidy)

The game shows a shrub **overgrown** until the player trims it with a hedge tool. For the two
shrubs, make the tidy plant `<Id>__Body` and add `<Id>__Overgrowth`: a separate, slightly larger,
shaggy shell of stray shoots and leaves around it, which the game hides once the shrub is trimmed.

#### `BoxwoodShrub` (Decorations)
A clipped rounded boxwood, dense small leaves, with a ring of mulch at its base. About **2.9 ×
2.9 × 2.9**. Add `BoxwoodShrub__Overgrowth`.

#### `HydrangeaBush` (Decorations)
A mophead hydrangea with big leaves and blue-to-pink flower heads. About **4 × 3.6 × 4**. Add
`HydrangeaBush__Overgrowth`.

#### `JapaneseMaple` (Decorations)
A small ornamental tree: a low, branching trunk (`JapaneseMaple__Body`) and a layered red canopy of
fine-lobed leaves (`JapaneseMaple__Canopy`). About **9 × 9 × 9**, with a mulch ring at the base.

#### `TerracottaPlanter` (Decorations)
A large rolled-rim terracotta pot with soil and trailing flowers (petunias and ivy spilling over
the rim). About **2 × 2.8 × 2**. Flowers in `TerracottaPlanter__Plants`.

#### `RaisedGardenBed` (Decorations)
A cedar raised bed (corner posts, two stacked boards with screws showing) with vegetable plants:
tomato cages, lettuce, peppers. About **8.6 × 2.5 × 4.3**, with plants in `RaisedGardenBed__Plants`.

### Features

#### `BirdBath` (Decorations)
A cast-concrete bird bath: a fluted pedestal on a square base and a shallow scalloped bowl. About
**2.2 × 2.6 × 2.2**. The water surface is `BirdBath__Water`, with a `Water` marker.

#### `TieredFountain` (Decorations)
A three-tier cast-stone fountain in a round basin with a lip you could sit on. About **6 × 5.4 ×
6**. Each water surface is its own mesh (`TieredFountain__Water1` to `__Water3`, top to bottom),
with `Water1` to `Water3` markers and a `Spout` marker at the top outlet.

#### `GardenArbor` (Decorations)
A white wooden arched arbor with lattice sides and climbing roses, wide enough to walk through
(inner opening at least 3.6 wide and 7 tall). About **4.6 × 8.2 × 2.2**. Roses in
`GardenArbor__Plants`. Keep the walk-through opening clear of collision geometry.

#### `GardenBench` (Decorations)
A three-seat teak garden bench with slatted seat and back, curved armrests and visible joinery.
About **5.4 × 3.2 × 2.2**. Add a `Seat` marker on the middle of the seat, LookVector −Z.

#### `PatioSet` (Decorations)
A round black-metal patio table with four matching chairs and a **market umbrella open** through
the centre. About **8.6 × 8 × 8.6**. The umbrella canopy is `PatioSet__Umbrella`. Add `Seat1` to
`Seat4` markers on the chairs, each facing the table.

#### `FirePit` (Decorations)
A round fire pit of stacked stone blocks with a steel ring liner and a few charred logs. About
**4 × 1.4 × 4**, with a `Fire` marker just above the logs.

#### `Mailbox` (Decorations)
A rural mailbox on a wooden 4 × 4 post with a mounting board. The door is `Mailbox__Door` (hinged
at its bottom edge) and the red flag is `Mailbox__Flag` (pivot at its bolt). About **1.2 × 4 ×
2.2**.

#### `LampPost` (Decorations)
A black cast-aluminium lamp post with a fluted base and a four-sided lantern. About **1.3 × 7.6 ×
1.3**. The lantern glass is `LampPost__Glass`, with a `Light` marker inside.

#### `SolarPathLight` (Decorations)
A small stake light: a stainless cap with a solar panel, a frosted lens and a spike. About **0.5
× 1.4 × 0.5**. The lens is `SolarPathLight__Glass`, with a `Light` marker inside.

#### `BirdFeeder` (Decorations)
A black shepherd's hook with a hanging wooden bird feeder (a little roof, seed tray and perch).
About **1.6 × 7.2 × 0.6**.

#### `Birdhouse` (Decorations)
A wooden birdhouse with a pitched roof, an entry hole and a perch, on a 4 × 4 post. About **1 ×
6.4 × 1**.

#### `PinkFlamingo` (Decorations)
The classic pink plastic lawn flamingo on two wire legs, slightly glossy. About **1.1 × 3 × 1.8**.

#### `GardenWindmill` (Decorations)
A decorative wooden garden windmill on a four-legged tower. The sail wheel is
`GardenWindmill__Spinner`, with its origin at the hub so the game can turn it around its own Z
axis. About **2.4 × 5.4 × 2**.

## Done when

- [ ] `PicketFenceSection`, `StoneEdgingSection`, `PaverPathSection`, `MulchBedSection`,
      `BoxwoodShrub`, `HydrangeaBush`, `JapaneseMaple`, `TerracottaPlanter`, `RaisedGardenBed`,
      `BirdBath`, `TieredFountain`, `GardenArbor`, `GardenBench`, `PatioSet`, `FirePit`, `Mailbox`,
      `LampPost`, `SolarPathLight`, `BirdFeeder`, `Birdhouse`, `PinkFlamingo` and
      `GardenWindmill` are built in `model-source/HighPoly/34_YardDecorations/`, with the combined
      `ALL/34_YardDecorations.gltf`, the manifest, textures and previews.
- [ ] Snapping pieces line up end to end with no gaps, and the decorated-lawn render shows it.
- [ ] Both shrubs have a separate `__Overgrowth` mesh.
- [ ] Every mesh is under 20,000 triangles, and every model is inside its budget.
- [ ] Nothing outside your folder changed.
