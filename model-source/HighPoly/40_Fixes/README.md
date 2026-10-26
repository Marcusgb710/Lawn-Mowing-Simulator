# Instruction 40: five models with separated surfaces

This standalone replacement pack fixes flickering surfaces in DeliveryCrate,
SmallOffice and all three Gloria yard stages. The original HP24, HP33 and HP37
packs and `39_Fixes` are unchanged. The models retain their original design,
colours, UV atlas, names, mesh splits, node transforms, hinge pivots, markers,
attachments and collision geometry. Only the overlapping details are adjusted.

| Model | Folder | Triangles | Budget | Meshes |
| --- | --- | ---: | ---: | ---: |
| DeliveryCrate | Props | 5,876 | 6,000 | 4 |
| SmallOffice | Buildings | 13,468 | 25,000 | 32 |
| GloriaYard_Stage1 | Story | 9,278 | 14,000 | 2 |
| GloriaYard_Stage2 | Story | 9,685 | 14,000 | 2 |
| GloriaYard_Stage3 | Story | 11,366 | 14,000 | 2 |

## Import

Import `ALL/40_Fixes.gltf`. Each named model is a top-level node with translation
only and its original mesh and marker children. The library uses a 28 m grid;
every pair of model bounding boxes has at least 5 m of clear space. The exact
translations are in each manifest entry's `library_translation_meters`:

| Root | Translation, metres (X, Y, Z) |
| --- | --- |
| DeliveryCrate | (0, 0, 0) |
| SmallOffice | (28, 0, 0) |
| GloriaYard_Stage1 | (0, 0, 28) |
| GloriaYard_Stage2 | (28, 0, 28) |
| GloriaYard_Stage3 | (56, 0, 28) |

Remove these library offsets when placing the replacements in the game. The
individual `Models/<Id>/<Id>.gltf` and `.fbx` files are already model-local.
Units remain 1 stud = 0.28 m, +Y up, front facing −Z. Every `Root` stays at
(0, 0.5, 0) studs. Use the original hinge transforms and marker attributes from
the delivered hierarchy and manifest.

**Place every replacement mesh at its new source position. Remove previous
whole-mesh flicker corrections rather than adding them again.** This includes
SmallOffice's glazing and collision-part offsets and any −Z lawn nudge. The new
pack fixes the source geometry itself, so it needs no inherited correction
offsets. Collision mesh geometry and sizes match the original source exactly;
the neighbouring decorative trim now provides the required separation.

The local Claude session imports/uploads these files as Big Dink Studios and
replaces the existing assets. Cloud export and FBX reimport are verified here;
Studio import and live-game publishing have not been performed.

## Changes

- **DeliveryCrate:** inset the twelve horizontal side slats by 0.031 studs,
  leaving the corner posts and overall size unchanged. Shorten each hidden slat
  end by 0.02 studs to clear the post end faces. Preserve the bevels, original
  UVs, FrontPanel and Lid geometry, and their hinge transforms. No added faces.
- **SmallOffice:** move the garage lintel 0.04 studs forward and 0.04 up; stop the
  partition siding at Y 16.85; centre the open door glazing at Z −13.884. Move
  the green sign panel 0.11 studs outward so its back is wholly outside the
  siding. Move the interior corner strips 0.025 studs proud of their previous
  positions, giving 0.035-stud clearance. Separate the garage jambs, window
  sills, floor-joint strips and decorative roof fascia from their neighbouring
  surfaces. All 25 collision meshes retain their exact original vertex arrays,
  dimensions and transforms. Doors stay open, with their original hinges.
- **All three yards:** build the original lawn pattern as one layer at Y 0.129,
  retaining its original swatch UVs. The driveway stays at 0.16 and walk at 0.17,
  with gaps of 0.031 and 0.041 studs. Shorten the paving at both ends to Z −47.96
  and −18.04, leaving 0.04 studs to the lawn edges. Remove redundant underlying
  lawn layers and the buried −Y vegetation/soil faces at Y 0.1 in Stage1 and
  Stage2. All surviving decoration faces retain their positions; beds, hedges,
  planters, lights and sign stand where they did before. Stage1 retains its
  original lawn, Stage2 its diagonal stripes and Stage3 its 16 × 10 checkerboard.

The small margins above 0.03 studs avoid float-rounding ambiguity. Full changes
and original source hashes are in `Source/surface_fixes.json`.

## Validation and previews

The repository's **unchanged** checker reports zero overlaps for all five
serialized glTF models at both required tolerances:

```sh
python3 scripts/check-coplanar.py model-source/HighPoly/40_Fixes
python3 scripts/check-coplanar.py model-source/HighPoly/40_Fixes --tol 0.029
```

Both commands exit successfully. The allowed lawn-underside exception is not
needed. Exact command outputs are in `Source/coplanar_default.txt` and
`Source/coplanar_0.029.txt`.

`validation.json` also records source comparisons, unchanged collision arrays,
mesh names, marker and hinge transforms, UV/material preservation, budgets,
finite attributes, nondegenerate triangles, individual/ALL equivalence, texture
hashes, five FBX reimports and the six 1280 × 1280 previews:

- `DeliveryCrate_Side.png`
- `SmallOffice_Front.png`
- `SmallOffice_Inside.png` (camera and review lights inside the actual building)
- `GloriaYard_Stage1_Lawn.png`
- `GloriaYard_Stage2_Lawn.png`
- `GloriaYard_Stage3_Lawn.png`

All fifteen texture files are byte-identical copies of the original HP24, HP33
and HP37 atlases. Image and buffer references resolve within this pack.
`Source/Surface_Fixes.blend` contains the packed, exported models with their
library positions, before review cameras/lights are added.

## Rebuild

From the repository root, with Python 3, NumPy, Pillow and Blender 4.3.2:

```sh
export PYTHONDONTWRITEBYTECODE=1
python3 model-source/HighPoly/40_Fixes/Source/fix_surfaces.py
python3 model-source/HighPoly/40_Fixes/Source/assemble_library.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/40_Fixes/Source/export_surface_fbx_and_previews.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/40_Fixes/Source/audit_fbx.py
python3 model-source/HighPoly/40_Fixes/Source/validate.py
python3 model-source/HighPoly/40_Fixes/Source/finalize_checksums.py
```

The patch script reads only the original HP24/33/37 exports. It does not read or
rewrite `39_Fixes`. SHA-256 checksums cover every delivery file except the list
itself and ignored Blender backup / Python cache files. Check them from this
directory with `sha256sum -c checksums.sha256`.
