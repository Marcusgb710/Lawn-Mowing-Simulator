# Seated June and surface fixes — instruction 39

This pack contains June's completed pose fix and the three models named in the expanded instruction 39. The original packs, game assets and runtime code are unchanged.

| Model | Folder | Triangles | Meshes | Fix |
| --- | --- | --- | --- | --- |
| `NPC_June_Sitting` | Story | 14,052 | 2 | Completed seated pose, carried forward unchanged |
| `DeliveryCrate` | Props | 5,876 | 4 | Side slats inset behind the corner posts |
| `SmallOffice` | Buildings | 13,468 | 32 | Lintel trim, partition siding and open door glazing separated |
| `GloriaYard_Stage3` | Story | 11,366 | 2 | One checkerboard surface, paving ends separated from lawn edges |

The additional previews are [the crate side](Previews/DeliveryCrate_Side.png), [the office front](Previews/SmallOffice_Front.png) and [the contest lawn](Previews/GloriaYard_Stage3_Lawn.png).

## Surface fixes

The twelve crate side slats move in by 0.031 stud, leaving a small margin above the requested 0.03 separation. Their short ends are recessed 0.02 stud behind the posts to avoid another close face pair. The posts, opening panel pivots, lid and overall size are preserved.

The office's lintel trim moves 0.04 stud forward and 0.04 upward. Moving it forward exposed its top beside a siding-course cap, so the small upward shift clears that pair too, without changing the strip's dimensions. Partition cladding stops at the beam's actual underside, Y 16.85. The glazing centre is at Z −13.884: the extra 0.004 beyond −13.880 gives its front face 0.0315 stud of clearance from the wall. Its thickness, open pose and pivot remain unchanged.

The lawn reuses the existing checker tiles and their HP37 UVs as a single, non-overlapping top at Y 0.129. It keeps the 44 × 30 footprint and the pattern's sixteen columns and ten rows. The driveway and walk remain at Y 0.16 and 0.17, giving 0.031 and 0.041 stud of clearance. Their ends stop at Z −47.96 and −18.04, 0.04 short of the lawn edges. All other Body vertices, including decorations and planting, are unchanged. The lawn drops from 2,124 to 330 triangles; the model stays below 14,000.

Nodes, mesh names, original pivots, attachment data, collision roles and sizes are retained. UVs stay on the original HP24, HP33 and HP37 atlases; the fifteen supplied PNGs are byte-identical copies of those packs' textures.

`python3 scripts/check-coplanar.py model-source/HighPoly/39_Fixes` reports **zero overlaps**. The specified surfaces also clear `--tol 0.03`. The wider command still lists 28 unrelated original surface pairs, including collision meshes; `Source/coplanar_review.json` verifies that all of these were present in the original sources. The full output is retained in `Source/coplanar_003.txt`. No claim is made that the entire wider-tolerance command returns zero.

## June's preserved pose

Replacement mesh source for **`NPC_June_Sitting`**, folder **`Story`**. June now has nearly level thighs, bent knees and nearly vertical shins, with both clogs flat at ground level. Her head, face, hat, hair, glasses, expression, outfit details and coffee mug are preserved from pack 37.

Review the five requested views:

- [Front](Previews/June_Front.png) and [side](Previews/June_Side.png), June alone.
- [Side in the rocker](Previews/June_InRocker_Side.png) and [three-quarter in the rocker](Previews/June_InRocker_ThreeQuarter.png), with both models at their shared origin.
- [On the porch](Previews/June_OnPorch.png), at the existing `PorchDeck.ChairSpot`.

## Import

Import `ALL/39_Fixes.gltf` with `39_Fixes.bin` and the relative `Textures/` folder intact. It contains **four** top-level model nodes, each with translation only. June is at the origin; crate, office and lawn occupy separate grid cells. Individual glTF/bin and binary FBX alternatives are in `Models/<Id>/`.

Remove each combined-library grid offset when creating its model-local definition; `library_translation_meters` records the offsets. Keep each model's original logical `Root` at `(0, 0.5, 0)` in local studs. All SmallOffice markers, including repeated `Mount`/`FloorSpot` names and their attributes and orientations, are preserved. Retain the existing game's between-MeshPart offsets when replacing its SmallOffice meshes; this source delivery preserves the original collision-part transforms, while baking in the named glazing fix.

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

`Source/clearance_review.json` records a bidirectional surface-edge test between June and the unchanged rocker: **zero surface crossings**, at a tolerance of 0.0001 stud. It also checks exact native head geometry/UV identity and body topology/UV identity. `Source/fbx_review.json` records independent reimports of all four FBX files, including bounds and texture paths. `validation.json` checks the actual buffers, markers, original UVs/materials, unchanged geometry, June's pose, non-overlapping library grid, eight previews and change scope. Studio import is not claimed by these source checks.

## Editable source and rebuild

`Source/June_Seated.blend` contains the fixed June and the unchanged chair/porch as preview references. `Source/June_OnPorch.blend` retains the final staged porch view. The scripts read pack 37's native source and procedural component descriptions, deform the existing body vertices, and preserve the original head. No remeshing, decimation, global resizing or UV repainting is applied.

`Source/Surface_Fixes.blend` contains the assembled four-model library. `fix_surfaces.py` edits the original serialized glTF data, and `assemble_library.py` combines the models without re-exporting their geometry. `surface_fixes.json` records the exact adjustments. The June model files and its five preview PNGs are unchanged by the surface-fix build.

With Blender 4.3.2, Python, NumPy and Pillow, rebuild the surface fixes from the repository root:

```sh
python model-source/HighPoly/39_Fixes/Source/fix_surfaces.py
python model-source/HighPoly/39_Fixes/Source/assemble_library.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/39_Fixes/Source/export_surface_fbx_and_previews.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/39_Fixes/Source/audit_fbx.py
python model-source/HighPoly/39_Fixes/Source/review_coplanar.py
python model-source/HighPoly/39_Fixes/Source/validate.py
```

If intentionally editing June's pose, run `repose.py`, `audit_pose.py` and `render_previews.py` first, before the surface-fix sequence above. Her pose exporter initially writes a one-model manifest/library; the surface build then restores the complete four-model delivery.

The pose exporter invokes `preserve_head.py` automatically. `Source/pose_changes.json` records each original body component's before/after bounds and the original source scene's hash. `checksums.sha256` verifies the delivered files; run `sha256sum -c checksums.sha256` from this folder before importing.

Only `39_Fixes/` is changed. The local Claude session imports this replacement into Studio as **Big Dink Studios**. No Roblox upload, replacement of the in-game model or place publication was performed in this cloud delivery.
