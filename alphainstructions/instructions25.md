# Instructions 25: High-poly pass, trucks and trailers

The crew truck sits at every player's business and drives to every job. Right now the pickups
look like boxy toy cab-overs; they need to look like real pickups.

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
**`model-source/HighPoly/25_TrucksAndTrailers/`**:

- `Models/<Id>/<Id>.gltf` with its `.bin`, plus `<Id>.fbx`, for every model in this file.
- **One combined library, `ALL/25_TrucksAndTrailers.gltf`**, with every model as a top-level node at its own
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

For all trucks:
- Real pickup proportions: a **long hood in front of the cab**, a raked windshield, and A/B/C
  pillars.
- Doors with seams and handles, mirrors, wheel arches with flares, bumpers, a grille with
  headlights and turn signals, tail lights, and a tailgate with its latch.
- A bed with wheel-well humps and stake pockets, a tow hitch at the rear, and a basic interior
  visible through the glass (seats, dash, steering wheel).
- Keep the four `__Wheel_*` meshes separate: real tires with tread and sidewall, and rims with lug
  nuts.
- Keep the bed floor at the current height, because `BedArea` stays where it is.

### `RustyPickup` (Trucks)
An older compact pickup, gray with rust: dents, rust patches around the wheel arches, one door in a
mismatched colour, a cracked tailgate and steel wheels.

### `WorkPickup` (Trucks)
A clean modern full-size work truck in white, with a toolbox across the front of the bed and a
ladder rack.

### `HeavyDutyPickup` (Trucks)
A blue heavy-duty crew-cab with dual rear wheels and fender flares, a tall grille, running boards
and tow mirrors.

### `LandscapingTruck` (Trucks)
A cab-forward box truck: a green box with ribbed panels and a rear roll-up door shown open, a
white cab, and dual rear wheels.

### `UtilityTrailer` (Trailers)
Now: OK, but thin. Build a steel channel frame, a mesh or wood floor, rails with uprights, fenders,
lights, a fold-down gate, an A-frame tongue with coupler, safety chains and a jack.

### `LandscapeTrailer` (Trailers)
An enclosed trailer: V-nose, ribbed aluminium skin with corner trim, rear ramp door down, tandem
axles, fenders, lights, coupler and jack.

### `EquipmentTrailer` (Trailers)
Now: a flat brown slab deck. Build a wood plank deck on a steel frame with D-rings, stake pockets
and fenders. Add tandem axles with leaf springs, an upright mesh ramp gate, lights, an A-frame
tongue with coupler, chains and a jack. Keep the `BedArea` and two `BaySpot` markers where they
are.

## Done when

- [ ] `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck`, `UtilityTrailer`, `LandscapeTrailer`, `EquipmentTrailer` are rebuilt in `model-source/HighPoly/25_TrucksAndTrailers/`, with the combined
      `ALL/25_TrucksAndTrailers.gltf`, the manifest, textures and previews.
- [ ] Every model's size is within 5% of the current one, and its grip and markers are within 0.1 stud
      (or the manifest says where they moved).
- [ ] Every mesh is under 20,000 triangles, and every model is inside its budget.
- [ ] The old vs. new previews show a clear jump in detail for every model.
- [ ] Nothing outside your folder changed.
