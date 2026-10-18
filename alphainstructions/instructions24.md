# Instructions 24: High-poly pass, yard props and buildings

> **Updated:** the game is now first person and much more immersive. Read the walk-in building notes below, which changed after this file was first pushed.
>
> **Updated again:** almost everything now happens inside the shop. Each business building also needs a `Desk` spot for the job computer and a `DeliverySpot` for delivered boxes (see the markers and the table below). The desks and boxes themselves are in instructions 33.

The customer's house and yard props appear in every job, and the business buildings are on screen
all the time, so these are the most visible models in the game.

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
**`model-source/HighPoly/24_YardAndBuildings/`**:

- `Models/<Id>/<Id>.gltf` with its `.bin`, plus `<Id>.fbx`, for every model in this file.
- **One combined library, `ALL/24_YardAndBuildings.gltf`**, with every model as a top-level node at its own
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

### `House` (Props)
Now: a flat box with a roof and painted-on windows. Build a real single-story suburban house. Give
it lap siding and corner trim, a roof with overhang, fascia, gutters and downspouts, and real window
frames with sills and glass panes. Add a front door with trim and a step or small porch, a chimney,
foundation skirting, and outdoor lights beside the door. Front faces −Z.

### `FlowerPatch` (Props)
Now: OK, but simple. Give the mulch bed a lumpy organic surface and an edging ring (stone or
steel). Make each flower clump real: leaves, stems and layered petals. Keep **6 separate flower
meshes whose names start with `Flower`**, because the game shrinks them when mowed. Keep it inside
the 3.45-stud circle.

### `GardenGnome` (Props)
Now: chunky and blocky. Sculpt a classic garden gnome: a pointed hat with folds, a full beard,
nose and eyes, coat buttons, a belt with buckle, boots and a small base. Make it read as painted
resin.

### Walk-in buildings (Shed, Garage, SmallOffice, EquipmentYard)

The game is now **first person**, and the business building is where the player keeps their
tools. They **walk inside**, take tools off the walls, and carry them out to the truck parked at
the door. Each business building must therefore be a real, enterable building.

- **Open doorway**: the Shed's door is a separate mesh `<Id>__Door`, shown swung open. Garage
  doors are separate meshes `<Id>__GarageDoor`, shown rolled up. Openings must be big enough to walk
  through with a push mower: at least 4 studs wide and 7 tall for doors, and at least 9 studs wide
  for roll-up doors on buildings that store ride-ons.
- **Real interior**: a floor (concrete or plank) and walls with real thickness (about 0.4 studs)
  that look finished on both sides. Show the underside of the roof with rafters or purlins, a
  light fixture, and windows that let light in. No furniture blocking the walls; the game mounts the
  storage itself.
- **Collision**: walls, roof and floor are **separate meshes** (`<Id>__Walls`, `<Id>__Roof`,
  `<Id>__Floor`, plus separate wall pieces if that keeps them simple). Door and garage-door openings
  must be real holes in the wall mesh, so the game's collision lets players and machines through.
- **Markers** (Attachments, children of the `<Id>__Floor` mesh, Orientation as described):
  - `Mount` on the interior walls, one per fixture, with attributes `Kind` (`"Pegboard"`,
    `"WallRack"`, `"WallHooks"`, `"Shelf"`, `"Workbench"`, `"Compressor"` or `"Grinder"`) and
    `Index` (1, 2, …).
    - The attachment sits on the wall surface at the fixture's bottom-centre, and its front
      (LookVector) points **into the room**.
    - Leave room for each fixture: Pegboard 4.5 wide × 3 tall (mount at about 2 studs high),
      WallRack 5 × 1.5 (about 3 high), WallHooks 3.5 × 1 (about 4.5 high), Shelf 4 × 6 (on the
      floor), Workbench 6.5 × 6 (on the floor), Compressor and Grinder about 2 × 2.
  - `Desk`: on the floor where the job computer desk stands, with its LookVector pointing **out
    from the desk toward where the player stands**. Leave a clear footprint for it: Shed 4.5 × 3,
    Garage 5.5 × 3.5, SmallOffice and EquipmentYard 6 × 5.5, plus about 3 studs of open floor in
    front to stand or sit. Put it near the door but out of the way of carrying tools to the truck.
  - `DeliverySpot`: open floor just inside the main door where delivered boxes appear, about 6 × 4
    studs on the Shed and Garage and 8 × 8 (room for a ride-on crate) on the SmallOffice and
    EquipmentYard, LookVector into the room.
  - `FloorSpot` (attribute `Index`): open floor where a push mower or walk-behind machine stands,
    about 3 × 6 studs each, facing the door.
  - `EquipmentBay` (attribute `Index`): a parking space for a ride-on, about 7 × 9 studs, facing
    out of an opening.
  - `TruckParking`: outside, on the ground about 9–12 studs in front of the main door. Its
    LookVector points **away from the building, toward the street (−Z)**, so the truck's tailgate
    faces the door.
  - `Light`: under the roof, where the game puts a lamp.
- **How many of each.** If the building is too small to fit them, make it bigger (see sizes) rather
  than leaving any out:

  | Building | Pegboard | WallRack | WallHooks | Shelf | FloorSpot | EquipmentBay | Also |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | Shed | 2 | 1 | 1 | 1 | 1 | – | Desk, DeliverySpot |
  | Garage | 3 | 2 | 2 | 2 | 2 | – | Workbench, Desk, DeliverySpot |
  | SmallOffice | 4 | 3 | 3 | 2 | 4 | 2 | Workbench, Compressor, Desk, DeliverySpot |
  | EquipmentYard | 6 | 4 | 5 | 3 | 6 | 5 | Workbench, Compressor, Grinder, Desk, DeliverySpot |

- **Sizes**: these buildings may grow beyond the 5% rule so the interiors fit, up to: Shed
  14 × 12 × 13 (W × H × D), Garage 28 × 16 × 24, SmallOffice 38 × 18 × 30, EquipmentYard
  46 × 22 × 34. They must still fit at the back of a 60 × 60 plot. Origin on the ground at the
  centre, front facing −Z.

### `Shed` (Buildings)
Now: a flat box. Make a wooden tool shed you can walk into: board-and-batten siding, a shingled
gable roof with exposed rafters inside, a plank floor, and a door with Z-bracing and hinges shown
open. Add a small window, a bare-bulb light at the `Light` marker, and the markers above. Keep it
cosy but walkable in first person; aim for an interior of about 12 × 10 studs.

### `Garage` (Buildings)
Now: a flat box. Make a detached work garage with a **sectional roll-up door raised open** and a
side door, siding and trim, and a concrete floor with a drain. Add exposed trusses, shop lights,
gutters, a concrete apron outside, and the markers above. The roll-up door is about 12 wide and
10 tall.

### `SmallOffice` (Buildings)
Now: a flat box. A small landscaping business: a front office (storefront glass door, window row,
awning and blank sign, with the `Desk` spot for the job computer) **plus a shop area behind or beside
it, reached through an open roll-up door**. The shop holds all the markers, including 2 equipment
bays with a 9+ stud opening.

### `EquipmentYard` (Buildings)
Now: plain slab walls. Make a metal shop building with ribbed siding and roof panels, a **big
roll-up door raised open** (about 16 × 12), a regular door, and an insulated interior with steel
frames and shop lights. Add the open-front lean-to, with its **5 equipment bays as
`EquipmentBay` markers**, and a concrete apron. Chain-link sections may run only along the sides. Put a small office corner inside the shop for the `Desk` spot.

## Done when

- [ ] `House`, `FlowerPatch`, `GardenGnome`, `Shed`, `Garage`, `SmallOffice`, `EquipmentYard` are rebuilt in `model-source/HighPoly/24_YardAndBuildings/`, with the combined
      `ALL/24_YardAndBuildings.gltf`, the manifest, textures and previews.
- [ ] Every model's size is within 5% of the current one, and its grip and markers are within 0.1 stud
      (or the manifest says where they moved).
- [ ] Every mesh is under 20,000 triangles, and every model is inside its budget.
- [ ] The old vs. new previews show a clear jump in detail for every model.
- [ ] Every business building can be walked into through its open door, and has every `Mount`,
      `FloorSpot`, `EquipmentBay`, `Desk`, `DeliverySpot`, `TruckParking` and `Light` marker in the table, with a render
      looking in through the door.
- [ ] Nothing outside your folder changed.
