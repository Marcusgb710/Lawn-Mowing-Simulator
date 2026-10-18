# Instructions 31: High-poly pass, push and walk-behind machines

Wheelbarrows, cart, spreader and walk-behind turf machines. The tire type matters in this game:
**air tires** have tread, a rim and a valve stem; **flat-free tires** are solid foam. Make the
difference obvious. Keep wheels as separate `__Wheel_*` meshes.

## What this is

These models are already in the game, as low-poly first versions. The owner wants them **rebuilt
at a much higher level of detail**: realistic, accurate and clearly better than the original
Lawn Mowing kit. Replace each model in this file with a detailed new version, and keep everything
the game depends on (listed below).

The current versions and their measurements are in `model-source/RevisedLawnModels/` and
`model-source/PhaseA_NewModels/` (each has a `model_manifest.json` and `Previews/`). The quality
reference is the original kit: see `model-source/RevisedLawnModels/OriginalKitPreviews/`. The
kit's 21-inch push mower, for example, is about 7,100 triangles with a real engine, deck, wheels
and handle.

## What to deliver

Mesh sources in the same format as `model-source/PhaseA_NewModels/`, in
**`model-source/HighPoly/31_PushMachines/`**:

- `Models/<Id>/<Id>.gltf` with its `.bin`, plus `<Id>.fbx`, for every model in this file.
- **One combined library, `ALL/31_PushMachines.gltf`**, with every model as a top-level node at its own
  spot in a grid (translation only, no rotation or scale on that node) and its meshes as child
  nodes. This is the file that gets imported into Studio.
- `model_manifest.json` using the same fields as `model-source/PhaseA_NewModels/model_manifest.json`
  for every model: `name`, `folder`, `dimensions_studs`, `bounds_min_studs`, `bounds_max_studs`,
  `primary_part`, `primary_position_studs`, `markers`, `slots`, `triangles` and `mesh_objects`.
- One shared set of PBR textures for the whole file in `Textures/` (Color, Roughness, Metalness,
  and Normal if used), each at most 2048 × 2048.
- Renders in `Previews/`, including an **old vs. new** comparison for every model.

Don't change `assets/`, `src/`, the existing `model-source/` packs, or anything outside your
folder. The local Claude session imports your library into Studio as Big Dink Studios and swaps
the models into the game.

## Keep these (the game depends on them)

- **Ids and folders** stay exactly the same.
- **Axes and units**: Roblox axes, +Y up, **front facing −Z**; author in metres, with 1 stud = 0.28 m.
  Each model's origin stays where it is now. For buildings, vehicles, trailers and props that's
  on the ground at the centre; for tools it's the frame the current manifest uses. Compare your
  bounds with the current `bounds_min_studs`/`bounds_max_studs`.
- **Overall size** within 5% of the current `dimensions_studs`, unless a note below says otherwise.
- **Grip and markers**: the `Handle` position (`primary_position_studs`, or `grip_studs` in the
  revised pack) and every `BedArea`, `BaySpot` and `Slot` position stay within 0.1 stud of where
  they are now, so holding, truck loading and storage keep working. If the new geometry makes a
  grip sit slightly wrong, move it a little and record the new position in your manifest.
- **Part names**: the main body is `<Id>__Body`. Moving parts stay separate meshes with their
  current names:
  - `<Id>__Wheel_*` turns around the part's own X axis, so its origin is on the axle.
  - `<Id>__CutterRotor*` and `<Id>__Spool` turn around the part's own Y axis, with the origin at
    the rotation centre.
- Glass and transparent pieces are separate meshes.
- No scripts, lights, particles, logos, brand names or readable text.

## Raise the detail

- **Model the real thing.** Work from real products: true proportions, real thicknesses, and the
  mechanisms you'd see (pivots, springs, hinges, linkages, cables, belts, guards).
- **Smooth, not faceted.** Round sections get at least 24 segments, and wheels and tires 48.
  Blades and trays are actually curved, not flat polygons. Hard edges get 2–3 bevel segments with
  weighted normals so they catch light, and there are no visible facets on curved surfaces.
- **Real thickness.** No paper-thin blades and no stick-thin handles. A long-handle tool shaft is
  about 1.25 in (0.11 studs) across; a hand-tool grip is about 1.1 in (0.1 studs).
- **Nothing floats.** Every part is visibly mounted with brackets, bolts, welds, ferrules, hinges
  or straps. Engines sit on decks or frames, handles go into sockets, hoses connect to fittings.
- **Detail that reads on a phone**: rivets and ferrules, textured grips, bolt heads, tire tread
  with rims and valve stems, engine shrouds with pull starters, fuel caps, air-filter covers,
  vents and cooling fins, and embossed shapes in place of stickers.
- **Materials**: distinct looks for painted metal, bare or galvanized steel, rubber, plastic, wood
  and glass, using colour, roughness and metalness. A normal map is fine for fine detail such as
  tread, knurling, wood grain or knit.
- **Triangle budgets** per model, for phones. Roblox allows at most 20,000 triangles per mesh, so
  split bigger models into a few meshes (body, glass, wheels and so on):

  | Kind | Triangles |
  | --- | --- |
  | Hand tools | 2,000–5,000 |
  | Long-handled tools | 3,000–6,000 |
  | Handheld power tools | 6,000–12,000 |
  | Push and walk-behind machines | 10,000–20,000 |
  | Ride-on and stand-on machines | 20,000–30,000 |
  | Trucks | 20,000–30,000 |
  | Trailers | 8,000–18,000 |
  | Buildings | 12,000–25,000 |
  | Small props and supplies | 1,500–6,000 |

  Spend triangles where they show (silhouettes, wheels, handles, faces the player sees) and fewer
  where they don't.

## Models and what to fix

### `SingleWheelbarrow` (Tools)
A green steel tray with rolled edge, a tubular or wooden frame with handle grips and legs, braces,
and an air tire on a hub with axle brackets.

### `SingleWheelbarrowFlatFree` (Tools)
The same build with a red tray and a solid foam tire (chunky, no valve).

### `DualWheelbarrow` (Tools)
A yellow tray over **two air tires** side by side, with a loop handle and a frame.

### `PolyCart` (Tools)
A moulded blue tub with ribbing, two wide solid wheels, an axle frame and a loop handle.

### `BroadcastSpreader` (Tools)
Now: a box hopper. Make a **rounded conical hopper** with rain cover and flow gate, a gearbox
under it driving a **spinner plate with fins** (`BroadcastSpreader__CutterRotor`), a tubular frame,
two air tires, and a handle with rate dial and lever.

### `WalkBehindEdger` (Tools)
An engine on a wheeled frame, a vertical blade behind a guard, a curb wheel, a depth lever and a
handle with controls.

### `SlitOverseeder` (Tools)
Now: a slab with a floating hopper. Build a frame with an engine, a **seed hopper with lid**
mounted on it, a row of vertical **slicing discs** (`SlitOverseeder__Wheel_Blades`), rear wheels and
a handlebar with controls.

### `PowerRakeDethatcher` (Tools)
Now: a slab with a floating engine. Build a low steel hood over a **flail reel**
(`PowerRakeDethatcher__Wheel_Flails`), the engine mounted on top, a depth knob, wheels and a
handle.

## Done when

- [ ] `SingleWheelbarrow`, `SingleWheelbarrowFlatFree`, `DualWheelbarrow`, `PolyCart`, `BroadcastSpreader`, `WalkBehindEdger`, `SlitOverseeder`, `PowerRakeDethatcher` are rebuilt in `model-source/HighPoly/31_PushMachines/`, with the combined
      `ALL/31_PushMachines.gltf`, the manifest, textures and previews.
- [ ] Every model's size is within 5% of the current one, and its grip and markers are within 0.1 stud
      (or the manifest says where they moved).
- [ ] Every mesh is under 20,000 triangles, and every model is inside its budget.
- [ ] The old vs. new previews show a clear jump in detail for every model.
- [ ] Nothing outside your folder changed.
