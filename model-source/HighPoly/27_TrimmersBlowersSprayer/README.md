# 27_TrimmersBlowersSprayer

7 model sources following instructions27 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/27_TrimmersBlowersSprayer.gltf`](ALL/27_TrimmersBlowersSprayer.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Cutting rotors and spools retain their named moving meshes. Wheels/blades on the edgers rotate around their X axle frames. The grips preserve the existing holding frames; geometry is fitted around the hand position before export. Backpack frames, straps and connected hoses remain behind the hand.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [Brushcutter](Models/Brushcutter/Brushcutter.gltf) | 8,124 | 2.48 × 3.92 × 6.43 | [PNG](Previews/Brushcutter_OldVsNew.png) |
| [StraightShaftTrimmer](Models/StraightShaftTrimmer/StraightShaftTrimmer.gltf) | 6,824 | 1.45 × 4.39 × 5.29 | [PNG](Previews/StraightShaftTrimmer_OldVsNew.png) |
| [LeafBlower](Models/LeafBlower/LeafBlower.gltf) | 8,076 | 1.22 × 3.18 × 4.04 | [PNG](Previews/LeafBlower_OldVsNew.png) |
| [BackpackBlower](Models/BackpackBlower/BackpackBlower.gltf) | 11,700 | 2.51 × 2.92 × 6.19 | [PNG](Previews/BackpackBlower_OldVsNew.png) |
| [ElectricEdger](Models/ElectricEdger/ElectricEdger.gltf) | 7,808 | 1.17 × 4.74 × 5.22 | [PNG](Previews/ElectricEdger_OldVsNew.png) |
| [GasStickEdger](Models/GasStickEdger/GasStickEdger.gltf) | 9,032 | 1.17 × 4.74 × 5.05 | [PNG](Previews/GasStickEdger_OldVsNew.png) |
| [BackpackSprayer](Models/BackpackSprayer/BackpackSprayer.gltf) | 7,076 | 2.21 × 1.96 × 4.51 | [PNG](Previews/BackpackSprayer_OldVsNew.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
