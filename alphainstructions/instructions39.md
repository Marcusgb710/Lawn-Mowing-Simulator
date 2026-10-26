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
