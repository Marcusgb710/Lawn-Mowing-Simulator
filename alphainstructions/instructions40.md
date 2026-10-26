# Instructions 40: Stop five models flickering (z-fighting)

Instructions 39 asked for two things: re-pose Grandma June, and fix the flicker in DeliveryCrate,
SmallOffice and GloriaYard_Stage3. June arrived in `39_Fixes` and is in the game now. **The flicker
fixes never arrived**, so they are this whole task, plus the same fix for GloriaYard_Stage1 and
Stage2 and a few more spots in SmallOffice. Leave `39_Fixes` as it is.

## The problem

On phones, some faces flicker between two colours as the camera moves. That happens when two
overlapping faces face the same way and lie in the same plane, or within a few hundredths of a
stud of it, so the GPU can't tell which one is in front.

**The rule:** two overlapping faces that face the same way and differ in colour must be **at least
0.03 studs apart**.

`python3 scripts/check-coplanar.py <model.gltf or pack folder>` finds them. For each overlapping
pair it lists:
- the meshes;
- the plane and its facing;
- the area, the two colours and the gap.

`--tol T` sets how close two planes count as the same; the default is 0.005. Coordinates below are
model-local studs, as that script prints them: Roblox axes, +Y up, front facing −Z,
1 stud = 0.28 m.

## 1. DeliveryCrate (pack 33, folder `Props`)

In `DeliveryCrate__Body`, on both sides of the crate (X = ±2.594), two sets of outer faces lie in
one plane:
- the six horizontal side slats (light wood);
- the two vertical corner posts (dark wood, at Z ≈ −3.4 and +3.5).

So the 12 spots per side where a slat crosses a post flicker. Set the slats 0.03 studs further in,
with their outer faces at X = ±2.564, so the posts stand proud. Keep the overall size.

The budget is 6,000 triangles and it uses 5,876, so don't add geometry.

## 2. SmallOffice (pack 24, folder `Buildings`)

Players walk inside this building to use the desk, so the inside counts as much as the outside.

**Outside:**
- **Garage-door trim.** In `SmallOffice__Body`, the white trim strip over the garage-door opening
  (X −12.17 to 0.17, Y 10.85 to 11.02) is only 0.005 studs in front of the front wall's siding
  (Z −13.860 against −13.865). Bring it out to Z −13.895 or further.
- **Glass door.** `SmallOffice__Glass_Door` is modelled swung open against the front wall. Its front
  face is 0.0025 studs behind the wall's siding. Move the glass 0.03 out, to Z −13.880 at its
  centre, still inside the door frame. The game's copy already does this, so do the same in the
  source.

**Inside (`SmallOffice__Body`):**
- **Ceiling beam.** The dark beam at X = 7 (X 6.93 to 7.07, Y 16.86 to 17.14, running along Z)
  sits on the office partition. The partition's siding (X 6.935 to 6.995) runs up inside the beam,
  so their −X faces are 0.005 apart. Stop the siding at the beam's underside (Y 16.86).
- **Green panel.** On the office's front wall, the dark green panel (#276c37, X 9.06 to 16.94,
  Y 11.26 to 12.54) has a +Z face 0.015 from the wall's inner face (Z −13.80), so it shows through
  on the inside. Keep the panel wholly outside the wall, or keep that face at least 0.03 from the
  inner face.
- **Corner trim.** The white vertical corner trim strips (#dde2dc, Y 0.30 to 17.18) are 0.01 off the
  siding at four places:
  - the partition at X 7.000, facing +X;
  - the side walls' inner faces at X ±18.45;
  - the front and back walls' inner faces at Z ±13.80.

  Bring each strip 0.03 proud of the siding.

**Where the collision meshes meet the Body.** About 20 small spots are 0.006 to 0.025 apart, where
the `Walls_*`, `Roof` and `Floor` meshes meet the Body's trim:
- the white jambs and sills around the front openings (X −12 and 0, sills at Y 3.285), and the sill
  on `Walls_Right_1`;
- the grey band along the tops of the side walls (X ±18.063, Y 16.47 to 17.2, against
  `Walls_Left_1` and `Walls_Right_4`, 0.025);
- the roof ends against the Body (Z ±14.238, 0.025);
- the floor's edge (Y 0.283, 0.006).

`--tol 0.029` lists them all. Open each to 0.03.

The budget is 25,000 triangles; it uses 13,468.

## 3. GloriaYard_Stage1, Stage2 and Stage3 (pack 37, folder `Story`)

The three stages share one layout: the lawn (`__Lawn`) covers X −22 to 22 and Z −48 to −18; the
driveway and the walk are in `__Body`. Fix all three the same way.

- **Lawn height.** Keep the lawn's top at **Y 0.13 or lower**, with the driveway's top at 0.16 and the
  walk's top at 0.17, so both stand at least 0.03 above the lawn. Today the gaps are 0.017 to 0.027:
  - Stage1's lawn top is 0.133;
  - Stage2's is 0.14;
  - Stage3's checker tiles are at 0.143.

  Keep everything in the Body standing on the lawn: the beds, hedges, planters, path lights and
  sign.
- **Stage3's layers.** `GloriaYard_Stage3__Lawn` is three stacked layers in two greens, 0.010 to
  0.013 apart across the whole 44 × 30 lawn:
  - the turf's top at Y 0.120;
  - the checker stripes' tops at 0.133;
  - the intersection tiles' tops at 0.143.

  From across the street they shimmer. Space the layers at least 0.03 apart, for example turf
  0.06, stripes 0.09 and tiles 0.12, or build the pattern as one layer.
- **Edges.** The lawn's front and back edge faces (Z −48 and −18) line up with the ends of the walk
  and the driveway, so a grey and green strip flickers there. Keep those ends at least 0.03 apart.
  Either move the lawn 0.03 toward the street (−Z), as the game's copy does, or stop the walk and
  the driveway 0.03 short at each end.
- **Budget.** Each stage has a 14,000-triangle budget. Stage3 already uses 13,160.

## Keep the same

Keep everything else about these five models the same:
- ids, folders, mesh names and how the parts are split;
- origins and pivots, and the `Root` at (0, 0.5, 0);
- the hinge pivots of the parts that open (DeliveryCrate's `FrontPanel` and `Lid`, SmallOffice's
  doors, modelled open);
- collision roles and sizes;
- every marker and attachment, with its attributes and LookVector:
  - SmallOffice's 14 `Mount`s, 4 `FloorSpot`s, 2 `EquipmentBay`s, `Desk`, `DeliverySpot`,
    `TruckParking` and 2 `Light`s;
  - DeliveryCrate's `Contents`.

Keep each model's UVs on its original pack's atlas (HP24, HP33, HP37) and its colours as they are.
Change geometry only where it fixes an overlap.

## What to deliver

Put everything in a new pack, **`model-source/HighPoly/40_Fixes/`**, in the same format as
`39_Fixes`:

- **Models:** `Models/<Id>/<Id>.gltf` with its `.bin`, plus `.fbx`, for each of:
  - DeliveryCrate;
  - SmallOffice;
  - GloriaYard_Stage1, GloriaYard_Stage2, GloriaYard_Stage3.
- **`ALL/40_Fixes.gltf`:** each model as its own top-level node, translation only. Give each model
  its own grid cell, at least 5 m apart, so no two bounding boxes overlap. Put each model's meshes
  in as child nodes. This is the file that gets imported.
- **`model_manifest.json`:** copy each entry from its original pack's manifest, then update:
  - `bounds_*`;
  - `triangles`;
  - `instruction: 40`;
  - `library_translation_meters`, which must match the model's translation in `ALL`.
- **`Textures/`:** the texture sets the models use, so the pack stands alone.
- **`README.md`, `validation.json` and `checksums.sha256`**, as in `39_Fixes`.
- **`Previews/`**, one image of each fixed area:
  - `DeliveryCrate_Side.png`;
  - `SmallOffice_Front.png`;
  - `SmallOffice_Inside.png`: the office interior, showing the front wall and the partition;
  - `GloriaYard_Stage1_Lawn.png`, `GloriaYard_Stage2_Lawn.png` and `GloriaYard_Stage3_Lawn.png`.

Don't change anything outside `model-source/HighPoly/40_Fixes/`. The local Claude session imports
the pack into Studio as Big Dink Studios and replaces the old models.

## Done when

- [ ] `python3 scripts/check-coplanar.py model-source/HighPoly/40_Fixes` reports nothing.
- [ ] `python3 scripts/check-coplanar.py model-source/HighPoly/40_Fixes --tol 0.029` reports
      nothing. The one exception is downward-facing (−Y) faces under the yards' lawns, which no
      one can see.
- [ ] All five models are in `40_Fixes`, with the same ids, mesh names, origins, pivots and markers
      as before, and each is within its triangle budget.
- [ ] All six previews are in `Previews/`.
- [ ] Nothing outside `40_Fixes/` changed.
