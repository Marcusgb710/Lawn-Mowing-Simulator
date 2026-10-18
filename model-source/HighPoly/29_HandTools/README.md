# 29_HandTools

15 model sources following instructions29 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved.

## Import handoff

Import [`ALL/29_HandTools.gltf`](ALL/29_HandTools.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The shared maps include Color, Roughness, Metalness and Normal; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

These are separate new tool sources. Curved blade shells have real thickness; pruning mechanisms, springs and ferrules are geometry. Fine grip and fabric texture uses the shared PBR atlas. Existing grip frames are retained.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [HandTrowel](Models/HandTrowel/HandTrowel.gltf) | 4,808 | 0.29 × 0.58 × 1.06 | [PNG](Previews/HandTrowel_OldVsNew.png) |
| [HandTransplanter](Models/HandTransplanter/HandTransplanter.gltf) | 4,868 | 0.19 × 0.61 × 1.10 | [PNG](Previews/HandTransplanter_OldVsNew.png) |
| [HandCultivator](Models/HandCultivator/HandCultivator.gltf) | 4,468 | 0.37 × 0.50 × 1.06 | [PNG](Previews/HandCultivator_OldVsNew.png) |
| [DandelionWeeder](Models/DandelionWeeder/DandelionWeeder.gltf) | 3,284 | 0.17 × 0.88 × 1.32 | [PNG](Previews/DandelionWeeder_OldVsNew.png) |
| [Dibber](Models/Dibber/Dibber.gltf) | 3,084 | 0.46 × 1.04 × 0.14 | [PNG](Previews/Dibber_OldVsNew.png) |
| [BypassPruners](Models/BypassPruners/BypassPruners.gltf) | 4,200 | 0.28 × 0.10 × 0.80 | [PNG](Previews/BypassPruners_OldVsNew.png) |
| [AnvilPruners](Models/AnvilPruners/AnvilPruners.gltf) | 4,364 | 0.27 × 0.12 × 0.73 | [PNG](Previews/AnvilPruners_OldVsNew.png) |
| [FloralSnips](Models/FloralSnips/FloralSnips.gltf) | 2,204 | 0.35 × 0.05 × 0.66 | [PNG](Previews/FloralSnips_OldVsNew.png) |
| [PruningSaw](Models/PruningSaw/PruningSaw.gltf) | 2,416 | 0.20 × 0.27 × 1.82 | [PNG](Previews/PruningSaw_OldVsNew.png) |
| [Loppers](Models/Loppers/Loppers.gltf) | 4,308 | 0.61 × 0.11 × 2.90 | [PNG](Previews/Loppers_OldVsNew.png) |
| [GardenShears](Models/GardenShears/GardenShears.gltf) | 4,792 | 0.49 × 1.30 × 1.65 | [PNG](Previews/GardenShears_OldVsNew.png) |
| [WateringCan](Models/WateringCan/WateringCan.gltf) | 4,144 | 0.74 × 1.04 × 1.94 | [PNG](Previews/WateringCan_OldVsNew.png) |
| [NitrileGloves](Models/NitrileGloves/NitrileGloves.gltf) | 3,568 | 1.19 × 0.10 × 0.79 | [PNG](Previews/NitrileGloves_OldVsNew.png) |
| [ChemicalGloves](Models/ChemicalGloves/ChemicalGloves.gltf) | 4,624 | 1.19 × 0.09 × 1.24 | [PNG](Previews/ChemicalGloves_OldVsNew.png) |
| [SoilProbe](Models/SoilProbe/SoilProbe.gltf) | 2,964 | 0.90 × 3.25 × 0.17 | [PNG](Previews/SoilProbe_OldVsNew.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
