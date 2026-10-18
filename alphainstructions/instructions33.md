# Instructions 33: Shop computer desks and delivery boxes

The game is first person, and almost everything now happens **inside the player's shop**. They
walk in, sit down at the computer to pick a job or order gear, unbox deliveries by the door, take
tools off the walls, load the truck parked at the door, and drive off from there. This file is the
furniture for that: one computer desk for each business tier, and the boxes that orders arrive in.

## What this is

These are **new models**; there's no current version in the game. Build them at the same high
level of detail as the high-poly pass (instructions 24–32): realistic, accurate and clearly better
than the original Lawn Mowing kit. The quality reference is the original kit: see
`model-source/RevisedLawnModels/OriginalKitPreviews/`. The kit's 21-inch push mower, for example,
is about 7,100 triangles with a real engine, deck, wheels and handle.

## What to deliver

Mesh sources in the same format as `model-source/PhaseA_NewModels/`, in
**`model-source/HighPoly/33_ShopDesksAndDeliveries/`**:

- `Models/<Id>/<Id>.gltf` with its `.bin`, plus `<Id>.fbx`, for every model in this file.
- **One combined library, `ALL/33_ShopDesksAndDeliveries.gltf`**, with every model as a top-level
  node at its own spot in a grid (translation only, no rotation or scale on that node) and its
  meshes as child nodes. This is the file that gets imported into Studio.
- `model_manifest.json` using the same fields as `model-source/PhaseA_NewModels/model_manifest.json`
  for every model: `name`, `folder`, `dimensions_studs`, `bounds_min_studs`, `bounds_max_studs`,
  `primary_part`, `primary_position_studs`, `markers`, `slots`, `triangles` and `mesh_objects`.
  `primary_part` is `Root` at (0, 0.5, 0) for every model here.
- One shared set of PBR textures for the whole file in `Textures/` (Color, Roughness, Metalness,
  and Normal if used), each at most 2048 × 2048.
- Renders in `Previews/`: a three-quarter view of each model, plus a first-person view from where
  the player stands at each desk.

Don't change `assets/`, `src/`, the existing `model-source/` packs, or anything outside your
folder. The local Claude session imports your library into Studio as Big Dink Studios and puts the
models into the game.

## Rules for every model

- **Ids and folders** exactly as listed below (case-sensitive). Every model here goes in `Props`.
- **Axes and units**: Roblox axes, +Y up, **front facing −Z** (the side the player stands at or
  walks up to). Author in metres, with 1 stud = 0.28 m (1 inch = 0.09 stud, 1 foot = 1.09 studs).
  A player is about 5 studs tall.
- **Origin** on the ground at the centre of the footprint, with the lowest point at Y = 0.
- **Overall size** within 10% of the sizes given below.
- **Part names**: the main body is `<Id>__Body`. Every other piece the game moves or uses is its
  own mesh, named as below. A moving piece has its origin on its hinge or fold line.
- **Markers** are named points (empty nodes in the glTF, listed in the manifest's `markers`, with
  position and orientation). The local session turns them into Attachments.
- Glass and transparent pieces are separate meshes.
- No scripts, lights, particles, logos, brand names or readable text. Labels, screens and paper
  are blank shapes or simple lines that don't read as words.

## Raise the detail

- **Model the real thing.** True proportions and real thicknesses: desk tops about 1 in thick,
  steel desk legs, monitor stands with real bases, keyboards with individual keys, cables that run
  to something.
- **Smooth, not faceted.** Round sections get at least 24 segments. Hard edges get 2–3 bevel
  segments with weighted normals so they catch light.
- **Nothing floats.** Monitors sit on stands, cables plug in, papers rest on surfaces, box flaps
  are joined to the box.
- **Lived-in, but tidy**: a coffee mug, a clipboard, a stapler, a desk phone, a sticky-note pad
  (blank), a pen cup, a few work gloves. These are working landscaper desks, not show offices.
- **Materials**: distinct looks for painted steel, laminate, wood, plastic, rubber, fabric,
  cardboard, packing tape and glass, using colour, roughness and metalness. A normal map is fine
  for fine detail such as wood grain, corrugation or fabric weave.
- **Triangle budgets** per model, for phones. Roblox allows at most 20,000 triangles per mesh.
  Spend triangles where the player looks: the screen, the keyboard and the front edge of the desk.

  | Model | Triangles |
  | --- | --- |
  | `JobLaptopTable` | 4,000–8,000 |
  | `JobComputerDesk` | 6,000–12,000 |
  | `JobOfficeDesk` | 10,000–18,000 |
  | Delivery boxes | 800–2,500 each |
  | `DeliveryCrate` | 3,000–6,000 |

## The computer desks

Every business building has a **`Desk`** spot where one of these stands (see the updated
instructions 24). The player walks up to it, the camera eases in to the monitor, and the
monitor's screen becomes the game's menu. The game draws that menu onto the screen mesh itself, so
**the screen mesh matters as much as the looks**.

For every desk:

- **`<Id>__Screen`**: a separate, perfectly flat rectangle exactly covering the display area of
  the monitor or laptop, sitting about 0.01 studs in front of the panel. Its own axes match the
  model's (front facing −Z, toward the player, +Y up), so its −Z face is the display. Make it
  plain dark grey, with no texture.
- The screen is a real **16:9 rectangle** with a thin bezel around it, tilted back no more than
  10°.
- **`UseSpot`** marker: on the floor, about 2.2 studs in front of the desk's front edge and
  centred on the main screen. This is where the player stands or sits. Its LookVector points **+Z,
  toward the desk**.
- **`ScreenView`** marker: about 2.5 studs in front of the main screen's centre at eye height
  (about 4.5 studs for a standing desk, about 3.6 for a seated one), looking straight at the screen.
  The camera moves here when the player uses the computer.
- Any chair is a separate mesh, `<Id>__Chair`, with its origin on the floor under its seat. Model
  it pulled out a little, so the player can step in.
- CanCollide-worthy pieces (desk top, legs, chair, cabinet) are separate from small clutter, so the
  game can turn off collision on the clutter. Put all small desk-top items in one mesh,
  `<Id>__Clutter`.

### `JobLaptopTable` (Props): Shed tier
A just-starting-out setup: a **folding utility table** (white plastic top, grey steel folding legs
with their cross braces visible) with a **rugged laptop** open on it (thick rubber corner bumpers,
a hinge you can see), a wireless mouse, a clipboard of job sheets, a coffee mug and an extension
cord running off the back edge to the floor. Add a **folding camp stool** as `JobLaptopTable__Chair`.
About **4.5 wide × 3.6 tall × 3.0 deep** including the stool. The laptop screen is
`JobLaptopTable__Screen`. Seated, so `ScreenView` is at about 3.6 studs high.

### `JobComputerDesk` (Props): Garage tier
A shop desk: a **grey steel tanker desk** with a laminate top, a drawer stack on one side and a
dented kick panel. On it are a 24-inch monitor on a stand, a keyboard, a mouse on a pad, a desk
phone with a coiled cord, a pen cup and a paper tray. A tower PC sits on the floor beside it, and a
**rolling shop stool** is `JobComputerDesk__Chair`. A shop light clamped to the desk edge leans
over it. About **5.5 wide × 4.4 tall × 3.5 deep**. The monitor screen is `JobComputerDesk__Screen`.
Seated, so `ScreenView` is at about 3.6 studs high.

### `JobOfficeDesk` (Props): SmallOffice and EquipmentYard tiers
A proper small-business office corner: an **L-shaped desk** (wood-look laminate, metal frame, a
cable tray underneath) with **two 27-inch monitors** on a dual arm, a keyboard and mouse, a
printer on the return, a desk lamp, a desk phone, a potted plant, and a **two-drawer filing
cabinet** under the return. Add a **mesh-back office chair** with five caster wheels and armrests,
as `JobOfficeDesk__Chair`. About **6 wide × 4.6 tall × 5.5 deep**. The main (left) monitor is
`JobOfficeDesk__Screen` and the right one is `JobOfficeDesk__Screen2`, both facing −Z and angled
in toward the chair by up to 15°. Centre `UseSpot` and `ScreenView` on the main screen. Seated, so
`ScreenView` is at about 3.6 studs high.

## The delivery boxes

Players order tools, parts and supplies from the shop computer. Orders arrive as boxes at the
**`DeliverySpot`** just inside the shop door. The player looks at a box and opens it, the flaps
swing open, and the item inside is shown at the box's `Contents` marker before they carry it to
the wall. So:

- Every box is modelled **closed and taped**. Each opening piece is its own mesh, with its origin
  on its fold or hinge line, so the game can swing it open.
- **`Contents`** marker: on the inside floor of the box, at the centre, with its LookVector −Z.
- The cardboard has real thickness (about 0.03 studs), corrugated edges at the cut lines, packing
  tape across the seam and down the ends, and a **blank shipping label** (a pale rectangle with a
  few grey lines, no readable text). Add a faint scuff or crushed corner on some boxes.
- Brown kraft cardboard, a little darker at the tape.

### `DeliveryBoxSmall` (Props)
A small box for hand tools, gloves and parts: about **1.8 wide × 1.1 tall × 1.3 deep**. Two top
flaps, `DeliveryBoxSmall__FlapL` and `DeliveryBoxSmall__FlapR`, hinged on the long top edges.

### `DeliveryBoxLong` (Props)
A long, narrow box for rakes, shovels, hoes and other long-handled tools: about **6.2 long (along
X) × 0.8 tall × 0.8 deep**. One lid along the top, `DeliveryBoxLong__Lid`, hinged on the back (+Z)
top edge.

### `DeliveryBoxLarge` (Props)
A large box for push mowers, trimmers, blowers and other walk-behind or handheld machines: about
**3.4 wide × 2.4 tall × 2.4 deep**, with printed-look handholds (cut-out slots) on the sides. Four
top flaps, `DeliveryBoxLarge__FlapL`, `__FlapR`, `__FlapF` and `__FlapB`, hinged on their edges.

### `DeliveryCrate` (Props)
A **wooden shipping crate on a pallet** for ride-on and stand-on machines: about **5.4 wide × 4.4
tall × 7.2 deep**. Make it a slatted pine crate with corner posts and diagonal bracing, nailed or
screwed, on a hardwood pallet with forklift openings. The **front panel**,
`DeliveryCrate__FrontPanel`, is a separate mesh hinged at its bottom edge so it drops down into a
ramp, and the **top**, `DeliveryCrate__Lid`, is a separate mesh hinged at its back edge. Put the
`Contents` marker on the pallet deck in the middle, facing −Z (out through the front panel).

## Done when

- [ ] `JobLaptopTable`, `JobComputerDesk`, `JobOfficeDesk`, `DeliveryBoxSmall`, `DeliveryBoxLong`,
      `DeliveryBoxLarge` and `DeliveryCrate` are built in
      `model-source/HighPoly/33_ShopDesksAndDeliveries/`, with the combined
      `ALL/33_ShopDesksAndDeliveries.gltf`, the manifest, textures and previews.
- [ ] Every desk has a flat 16:9 `__Screen` mesh (and `__Screen2` on `JobOfficeDesk`), a
      `UseSpot` and a `ScreenView` marker, and a separate `__Chair`.
- [ ] Every box has its flaps, lid or panels as separate meshes with origins on their hinge lines,
      and a `Contents` marker.
- [ ] Every mesh is under 20,000 triangles, and every model is inside its budget.
- [ ] Nothing outside your folder changed.
