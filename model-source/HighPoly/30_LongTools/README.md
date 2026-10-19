# 30_LongTools

9 model sources following instructions30 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/30_LongTools.gltf`](ALL/30_LongTools.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Long handles have tapered shafts, sockets and rivets. Blades are dished or forged with real thickness. The existing grip positions and overall dimensions are retained, including the distinct fork, rake, hoe and edging heads.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [RoundPointShovel](Models/RoundPointShovel/RoundPointShovel.gltf) | 4,292 | 0.68 × 5.15 × 0.18 | [PNG](Previews/RoundPointShovel_OldVsNew.png) |
| [GardenSpade](Models/GardenSpade/GardenSpade.gltf) | 5,628 | 0.66 × 3.62 × 0.12 | [PNG](Previews/GardenSpade_OldVsNew.png) |
| [Broadfork](Models/Broadfork/Broadfork.gltf) | 5,700 | 1.80 × 5.40 × 0.30 | [PNG](Previews/Broadfork_OldVsNew.png) |
| [DiggingFork](Models/DiggingFork/DiggingFork.gltf) | 4,492 | 0.66 × 3.61 × 0.13 | [PNG](Previews/DiggingFork_OldVsNew.png) |
| [Mattock](Models/Mattock/Mattock.gltf) | 2,620 | 0.60 × 3.21 × 1.44 | [PNG](Previews/Mattock_OldVsNew.png) |
| [BowRake](Models/BowRake/BowRake.gltf) | 4,564 | 1.45 × 5.94 × 0.20 | [PNG](Previews/BowRake_OldVsNew.png) |
| [StirrupHoe](Models/StirrupHoe/StirrupHoe.gltf) | 2,748 | 0.56 × 5.32 × 0.21 | [PNG](Previews/StirrupHoe_OldVsNew.png) |
| [WideRake](Models/WideRake/WideRake.gltf) | 5,264 | 2.63 × 4.82 × 0.68 | [PNG](Previews/WideRake_OldVsNew.png) |
| [HalfMoonEdger](Models/HalfMoonEdger/HalfMoonEdger.gltf) | 2,324 | 1.19 × 4.40 × 0.30 | [PNG](Previews/HalfMoonEdger_OldVsNew.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
