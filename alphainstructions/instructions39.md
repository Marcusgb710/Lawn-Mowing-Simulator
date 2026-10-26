# Instructions 39: Re-pose Grandma June in her rocker

`NPC_June_Sitting` from instructions 37 is in the game now, sitting in `PorchRockingChair` on
`PorchDeck`. She looks great, but **her legs stick out straight**: from her hips they run down in
one straight diagonal to her feet, which land on the floor about 2.4 studs in front of the
chair, past its runners. In the game she looks like she's sliding off the rocker. The side view
in `model-source/HighPoly/37_Story/Previews/CharacterSheet.png` shows the same thing.

**Re-pose her so she sits properly in the rocker.** Change nothing else: the same character,
outfit, hat, glasses, face, mug and expression.

## Measurements (studs, Roblox axes, +Y up, front facing −Z)

Both models share the same origin: the rocker and June stand on the same spot.

- **PorchRockingChair:**
  - footprint X −1.2 to 1.2, Z −1.5 to 1.5, height 4;
  - its `Seat` marker (top of the cushion) is at **(0, 1.83, 0)**, facing −Z;
  - the runners rest on Y = 0.
- **NPC_June_Sitting now:** X −1.29 to 1.11, Y 0 to 4.29, **Z −2.39 to 0.72**. The −2.39 is her
  straight legs reaching too far forward.

## The new pose

- **Hips** on the cushion: the underside of her seat at Y ≈ 1.85, her hips centred around
  Z ≈ +0.2, and her back resting against the rocker's spindles at its slight backward lean.
- **Thighs** run forward, close to level, to the front edge of the cushion, with her knees at
  about **Y 2.0, Z −0.9**.
- **Knees bent** about 90°, so the shins drop nearly straight down.
- **Feet** are flat on the floor at **Y = 0**, about **Z −1.2 to −1.4**, a little apart. They sit just
  in front of the runners' front tips and never past Z −1.6. The clogs are flat on the ground.
- **Arms:** one forearm on the armrest, and the mug hand resting on the other armrest or her lap.
  No part of her passes through the chair: no legs through the front rail or runners, no arms
  through the armrests, no back through the spindles.
- **Overall:** the whole model fits in **X −1.25 to 1.25, Z −1.6 to 0.8**, height about 4.2.

## Keep the same

- **Id and folder:** `NPC_June_Sitting`, folder `Story`. `primary_part` is `Root` at
  (0, 0.5, 0).
- **Head:** a separate mesh, `NPC_June_Sitting__Head`, with its pivot at the neck. Hat, hair and
  glasses go in the head mesh.
- **Markers:**
  - `Head` at eye level, LookVector −Z (move it to her new eye position);
  - `Talk` at chest height in front, at about (0, 2.6, −1).
- **Size:** 8,000–15,000 triangles, in at most 4 meshes, using the same shared textures and
  materials as the 37 pack. Reuse its texture set, or deliver an identical copy.

## What to deliver

In **`model-source/HighPoly/39_Fixes/`**, in the same format as `37_Story`:

- `Models/NPC_June_Sitting/NPC_June_Sitting.gltf` with its `.bin`, plus `.fbx`.
- `ALL/39_Fixes.gltf`: the one model as a top-level node at the origin (translation only), with
  its meshes as child nodes. This is the file that gets imported.
- `model_manifest.json` with her entry, in the same fields as the 37 manifest.
- `Textures/` if the model needs its own copy.
- `Previews/`:
  - `June_Front.png` and `June_Side.png`: her alone, from the front and the side;
  - `June_InRocker_Side.png` and `June_InRocker_ThreeQuarter.png`: seated in
    `PorchRockingChair`, with both models at the origin;
  - `June_OnPorch.png`: in the rocker on `PorchDeck` at its `ChairSpot`.
  The side views must clearly show her knees bent and her feet flat on the floor, with nothing
  passing through the chair.

Don't change anything outside `model-source/HighPoly/39_Fixes/`. The local Claude session
imports it into Studio as Big Dink Studios and replaces the old model.

## Done when

- [ ] She sits in the rocker with bent knees and her feet flat on the floor between Z −1.2 and
      −1.4, inside X ±1.25 and Z −1.6 to 0.8.
- [ ] Nothing passes through the chair.
- [ ] The id, folder, Root, head mesh and the `Head` and `Talk` markers are as above, with the
      same look as before.
- [ ] All five previews are in `Previews/`.
- [ ] Nothing outside `39_Fixes/` changed.

## Also: stop three models flickering (z-fighting)

On phones some faces flicker between two colours as the camera moves. Two overlapping faces lie in
the same plane (or within a few thousandths of a stud of it), facing the same way, so the GPU can't
tell which is in front. Where the two faces were in different meshes, the game's copy has already
been fixed by nudging one mesh. The cases below have both faces in the **same mesh**, so they need
fixing in the source. Rule of thumb: two overlapping faces that face the same way and differ in
colour must be **at least 0.03 studs apart**.

`python3 scripts/check-coplanar.py <model.gltf or pack folder>` finds these: it lists each pair of
overlapping faces with the meshes, the plane, the area and the two colours. Coordinates below are
model-local studs, as that script prints them.

1. **`DeliveryCrate`** (pack 33, folder `Props`), in `DeliveryCrate__Body`. On both sides of the
   crate (X = ±2.594) the outer faces of the six horizontal side slats (light wood) and of the two
   vertical corner posts (dark wood, at Z ≈ −3.4 and +3.5) are in one plane, so the 12 spots per
   side where a slat crosses a post flicker. Set the slats 0.03 studs further in (outer faces at
   X = ±2.564) so the posts stand proud. Keep the overall size.

2. **`SmallOffice`** (pack 24, folder `Buildings`):
   - In `SmallOffice__Body`, the white trim strip over the garage-door opening (X −12.17 to 0.17,
     Y 10.85 to 11.02) is only 0.005 studs in front of the front wall's siding (Z −13.860 against
     −13.865). Bring it out to Z −13.895 or further.
   - In `SmallOffice__Body`, the dark ceiling beam at X = 7 (X 6.93 to 7.07, Y 16.86 to 17.14,
     along Z) sits on the office partition, and the partition's siding (X 6.935 to 6.995) runs up
     inside the beam. Their −X faces are 0.005 studs apart. Stop the siding at the underside of the
     beam (Y 16.86).
   - `SmallOffice__Glass_Door` (the door is modelled swung open against the front wall) had its
     front face 0.0025 studs behind the wall's siding. The game's copy moves the glass 0.03 studs
     out, to Z −13.880 at its centre, still inside the door frame. Do the same in the source.

3. **`GloriaYard_Stage3`** (pack 37, folder `Story`):
   - `GloriaYard_Stage3__Lawn` is three stacked layers in two greens, 0.010 to 0.013 studs apart
     across the whole 44 × 30 lawn: the turf's top at Y 0.120, the checker stripes' tops at 0.133
     and the intersection tiles' tops at 0.143. From across the street they shimmer. Space the
     layers at least 0.03 apart, for example turf 0.06, stripes 0.09, tiles 0.12, or build the
     pattern as one layer. Keep the lawn's top at Y 0.13 or lower, so the driveway (top 0.16) and
     the walk (top 0.17) in `GloriaYard_Stage3__Body` stay at least 0.03 above it. Keep everything
     in the Body standing on the lawn: the beds, hedges, planters, path lights and sign.
   - The lawn's front and back edge faces (Z −48 and −18) are in line with the ends of the walk and
     the driveway. The game's copy moves the whole lawn 0.03 studs toward the street. In the source,
     keep those ends at least 0.03 apart, either by moving the lawn the same way or by stopping the
     walk and driveway 0.03 short at each end.
   - Stay inside the model's 14,000-triangle budget.

Keep everything else about these three the same: ids, folders, mesh names and how the parts are
split, origins and pivots, the `Root` at (0, 0.5, 0), every marker and attachment (SmallOffice's
`Mount`, `FloorSpot`, `EquipmentBay`, `Desk`, `DeliverySpot`, `TruckParking` and `Light` with their
attributes and LookVectors), the doors modelled open, collision roles and sizes. Keep each model's
UVs on the atlas of its original pack (HP24, HP33, HP37).

**Deliver them in the same `39_Fixes` pack** as June: `Models/<Id>/<Id>.gltf` with `.bin` and
`.fbx` for each one. Add each as its own top-level node in `ALL/39_Fixes.gltf` (translation only,
each in its own grid cell, June at the origin). Copy each entry into `model_manifest.json` from its
original pack's manifest and update it. Put the textures each model uses in `Textures/`. Add one
preview of each fixed area to `Previews/`: `DeliveryCrate_Side.png`, `SmallOffice_Front.png` and
`GloriaYard_Stage3_Lawn.png`.

- [ ] `python3 scripts/check-coplanar.py model-source/HighPoly/39_Fixes` reports nothing, and with
      `--tol 0.03` it lists none of the faces named above.
- [ ] DeliveryCrate, SmallOffice and GloriaYard_Stage3 are in `39_Fixes` with the same ids, mesh
      names, origins and markers as before.
