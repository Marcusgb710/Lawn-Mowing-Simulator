# June's seated pose — instruction 39

Replacement mesh source for **`NPC_June_Sitting`**, folder **`Story`**. June now has nearly level thighs, bent knees and nearly vertical shins, with both clogs flat at ground level. Her head, face, hat, hair, glasses, expression, outfit details and coffee mug are preserved from pack 37.

Review the five requested views:

- [Front](Previews/June_Front.png) and [side](Previews/June_Side.png), June alone.
- [Side in the rocker](Previews/June_InRocker_Side.png) and [three-quarter in the rocker](Previews/June_InRocker_ThreeQuarter.png), with both models at their shared origin.
- [On the porch](Previews/June_OnPorch.png), at the existing `PorchDeck.ChairSpot`.

## Import

Import `ALL/39_Fixes.gltf` with `39_Fixes.bin` and the relative `Textures/` folder intact. It contains **one** top-level `NPC_June_Sitting` node at the origin, with no rotation or scale. Individual glTF/bin and binary FBX alternatives are in `Models/NPC_June_Sitting/`.

Use the existing pack 37 import convention: +Y up, front facing −Z, authored in metres with **1 stud = 0.28 m**. The manifest's dimensions and marker positions are in studs.

The model uses two meshes and **14,052 triangles**, preserving the original topology and UVs. `NPC_June_Sitting__Head` keeps its neck pivot at `(0, 3.01, 0)`. Its glTF positions, normals, UVs and index data are copied directly from the original export. All five shared texture files are byte-identical copies of pack 37's textures. Color is sRGB; the other maps are data textures.

Set the logical `Root` PrimaryPart at `(0, 0.5, 0)` as before. Convert the `Head` and `Talk` empties to Attachments using their manifest parent meshes and model-local positions. Head remains at eye level `(0, 3.57, -0.46)`; Talk remains at `(0, 2.6, -1)`. Both look toward −Z.

**Keep the existing placement:** June and `PorchRockingChair` use the same ground origin. On the porch, put both origins at `ChairSpot`, `(-1, 1.6, 1)` in deck-local studs. Do not position June's origin at the chair's cushion `Seat` marker. The chair and porch have not been changed and are not included in the exchange exports.

## Measurements and checks

| Measurement | Studs |
| --- | --- |
| Overall X bounds | −1.19246 … 1.11500 |
| Overall Y bounds | 0 … 4.29022 |
| Overall Z bounds | −1.59128 … 0.74116 |
| Clog centre Z, each | −1.20 |
| Sole bottom / top Y | 0 / 0.13 |
| Hip pose controls | X ±0.30, Y 2.12, Z 0.20 |
| Knee pose controls | X ±0.31, Y 2.05, Z −1.05 |

The lower trouser legs clear the rocker's projecting front rail. The forearms and fingers are placed above its armrests, and the mug hand is moved slightly inwards. The blouse hem is lifted above the cushion as part of the seated pose.

`Source/clearance_review.json` records a bidirectional surface-edge test between June and the unchanged rocker: **zero surface crossings**, at a tolerance of 0.0001 stud. It also checks exact native head geometry/UV identity and body topology/UV identity. `Source/fbx_review.json` records an independent FBX reimport, including bounds and texture paths. `validation.json` checks the actual glTF buffers, markers, footprint, flat soles, shared textures, original head data, five previews and change scope. Studio import is not claimed by these source checks.

## Editable source and rebuild

`Source/June_Seated.blend` contains the fixed June and the unchanged chair/porch as preview references. `Source/June_OnPorch.blend` retains the final staged porch view. The scripts read pack 37's native source and procedural component descriptions, deform the existing body vertices, and preserve the original head. No remeshing, decimation, global resizing or UV repainting is applied.

With Blender 4.3.2, Python, NumPy and Pillow, run these commands from the repository root:

```sh
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/39_Fixes/Source/repose.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/39_Fixes/Source/audit_pose.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/39_Fixes/Source/audit_fbx.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/39_Fixes/Source/render_previews.py
python model-source/HighPoly/39_Fixes/Source/validate.py
```

The pose exporter invokes `preserve_head.py` automatically. `Source/pose_changes.json` records each original body component's before/after bounds and the original source scene's hash. `checksums.sha256` verifies the delivered files; run `sha256sum -c checksums.sha256` from this folder before importing.

Only `39_Fixes/` is changed. The local Claude session imports this replacement into Studio as **Big Dink Studios**. No Roblox upload, replacement of the in-game model or place publication was performed in this cloud delivery.
