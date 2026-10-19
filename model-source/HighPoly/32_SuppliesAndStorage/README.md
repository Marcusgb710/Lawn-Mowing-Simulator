# 32_SuppliesAndStorage

19 model sources following instructions32 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/32_SuppliesAndStorage.gltf`](ALL/32_SuppliesAndStorage.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Workbench has separate worktop and leg meshes. ServiceSpot and VisePoint are actual Attachment-tagged authoring nodes parented to Workbench__worktop. ServiceSpot faces into the bench. The existing storage slot coordinates are unchanged.

StorageShelf is new: its back is Z=0, its front faces -Z, and its six Slot1–Slot6 attachments sit on the three shelf surfaces. The red GasCan and green MixGasCan are separate new models. The original supplied kit remains unchanged.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [GasCan](Models/GasCan/GasCan.gltf) | 2,320 | 0.63 × 1.09 × 1.21 | [PNG](Previews/GasCan_OldVsNew.png) |
| [MixGasCan](Models/MixGasCan/MixGasCan.gltf) | 2,320 | 0.63 × 1.09 × 1.21 | [PNG](Previews/MixGasCan_OldVsNew.png) |
| [TrimmerLine](Models/TrimmerLine/TrimmerLine.gltf) | 2,260 | 0.60 × 0.42 × 0.60 | [PNG](Previews/TrimmerLine_OldVsNew.png) |
| [FootPump](Models/FootPump/FootPump.gltf) | 3,152 | 0.68 × 0.35 × 1.03 | [PNG](Previews/FootPump_OldVsNew.png) |
| [ElectricInflator](Models/ElectricInflator/ElectricInflator.gltf) | 1,872 | 0.36 × 0.80 × 0.77 | [PNG](Previews/ElectricInflator_OldVsNew.png) |
| [AirCompressor](Models/AirCompressor/AirCompressor.gltf) | 5,352 | 1.50 × 1.37 × 1.50 | [PNG](Previews/AirCompressor_OldVsNew.png) |
| [TirePatchKit](Models/TirePatchKit/TirePatchKit.gltf) | 2,444 | 0.60 × 0.39 × 0.55 | [PNG](Previews/TirePatchKit_OldVsNew.png) |
| [SpareTire](Models/SpareTire/SpareTire.gltf) | 2,224 | 0.69 × 1.20 × 1.20 | [PNG](Previews/SpareTire_OldVsNew.png) |
| [WrenchSet](Models/WrenchSet/WrenchSet.gltf) | 5,584 | 1.50 × 0.73 × 1.43 | [PNG](Previews/WrenchSet_OldVsNew.png) |
| [BladeFile](Models/BladeFile/BladeFile.gltf) | 1,476 | 0.11 × 0.11 × 1.09 | [PNG](Previews/BladeFile_OldVsNew.png) |
| [SharpeningStone](Models/SharpeningStone/SharpeningStone.gltf) | 376 | 0.55 × 0.10 × 0.20 | [PNG](Previews/SharpeningStone_OldVsNew.png) |
| [SpareMowerBlade](Models/SpareMowerBlade/SpareMowerBlade.gltf) | 496 | 1.90 × 0.18 × 0.23 | [PNG](Previews/SpareMowerBlade_OldVsNew.png) |
| [BenchGrinder](Models/BenchGrinder/BenchGrinder.gltf) | 3,996 | 1.50 × 1.03 × 0.95 | [PNG](Previews/BenchGrinder_OldVsNew.png) |
| [ToolBucket](Models/ToolBucket/ToolBucket.gltf) | 4,508 | 1.19 × 1.73 × 1.19 | [PNG](Previews/ToolBucket_OldVsNew.png) |
| [Workbench](Models/Workbench/Workbench.gltf) | 3,828 | 6.50 × 6.00 × 2.44 | [PNG](Previews/Workbench_OldVsNew.png) |
| [StoragePegboard](Models/StoragePegboard/StoragePegboard.gltf) | 3,500 | 4.50 × 3.00 × 0.39 | [PNG](Previews/StoragePegboard_OldVsNew.png) |
| [StorageWallRack](Models/StorageWallRack/StorageWallRack.gltf) | 4,388 | 5.00 × 1.50 × 0.79 | [PNG](Previews/StorageWallRack_OldVsNew.png) |
| [StorageWallHooks](Models/StorageWallHooks/StorageWallHooks.gltf) | 2,012 | 3.50 × 1.00 × 0.79 | [PNG](Previews/StorageWallHooks_OldVsNew.png) |
| [StorageShelf](Models/StorageShelf/StorageShelf.gltf) | 2,164 | 4.00 × 6.00 × 1.50 | [PNG](Previews/StorageShelf_Preview.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
