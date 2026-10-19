# 28_HedgeAndHose

6 model sources following instructions28 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/28_HedgeAndHose.gltf`](ALL/28_HedgeAndHose.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Transparent hand guards are separate meshes. The cutting bars have real double-sided teeth and fasteners; do not merge transparent guards into opaque bodies. All holding-frame metadata is retained.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [HandHedgeShears](Models/HandHedgeShears/HandHedgeShears.gltf) | 4,868 | 0.76 × 0.42 × 2.85 | [PNG](Previews/HandHedgeShears_OldVsNew.png) |
| [ElectricHedgeTrimmer](Models/ElectricHedgeTrimmer/ElectricHedgeTrimmer.gltf) | 8,440 | 1.10 × 1.00 × 3.72 | [PNG](Previews/ElectricHedgeTrimmer_OldVsNew.png) |
| [CordlessHedgeTrimmer](Models/CordlessHedgeTrimmer/CordlessHedgeTrimmer.gltf) | 8,336 | 1.10 × 1.10 × 4.42 | [PNG](Previews/CordlessHedgeTrimmer_OldVsNew.png) |
| [GasHedgeTrimmer](Models/GasHedgeTrimmer/GasHedgeTrimmer.gltf) | 10,108 | 1.10 × 1.00 × 4.70 | [PNG](Previews/GasHedgeTrimmer_OldVsNew.png) |
| [ArticulatingHedgeTrimmer](Models/ArticulatingHedgeTrimmer/ArticulatingHedgeTrimmer.gltf) | 7,448 | 0.78 × 3.12 × 7.76 | [PNG](Previews/ArticulatingHedgeTrimmer_OldVsNew.png) |
| [GardenHoseWand](Models/GardenHoseWand/GardenHoseWand.gltf) | 4,872 | 0.71 × 1.23 × 2.98 | [PNG](Previews/GardenHoseWand_OldVsNew.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
