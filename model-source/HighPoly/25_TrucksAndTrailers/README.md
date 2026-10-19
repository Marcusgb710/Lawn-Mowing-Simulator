# 25_TrucksAndTrailers

7 model sources following instructions25 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/25_TrucksAndTrailers.gltf`](ALL/25_TrucksAndTrailers.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Driver doors are closed, with their own Y hinge axes. DriverDoorGlass contains both the side-window pane and the left mirror glass, so the current Openings module animates all of that glass with the driver door. It carries `moves_with=<Id>__DriverDoor`; preserve the shared hinge frame. The right mirror glass remains a separate stationary mesh.

Pickup tailgates and trailer ramps have X hinge axes at the bottom edge. LandscapingTruck has a rear door that translates upward instead of a tailgate. The closed LandscapeTrailer ramp door and the upright EquipmentTrailer ramp retain the correct hinge frames. Each truck has a DriverSeat eye attachment facing -Z, with first-person views in Previews. Do not convert cargo bodies to one convex hull: preserve the usable interior/bed opening with suitable decomposition or simple colliders.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [RustyPickup](Models/RustyPickup/RustyPickup.gltf) | 25,412 | 7.09 × 6.63 × 16.18 | [PNG](Previews/RustyPickup_OldVsNew.png) |
| [WorkPickup](Models/WorkPickup/WorkPickup.gltf) | 24,756 | 7.09 × 6.83 × 16.65 | [PNG](Previews/WorkPickup_OldVsNew.png) |
| [HeavyDutyPickup](Models/HeavyDutyPickup/HeavyDutyPickup.gltf) | 29,964 | 8.09 × 7.53 × 18.15 | [PNG](Previews/HeavyDutyPickup_OldVsNew.png) |
| [LandscapingTruck](Models/LandscapingTruck/LandscapingTruck.gltf) | 26,576 | 7.50 × 9.04 × 18.15 | [PNG](Previews/LandscapingTruck_OldVsNew.png) |
| [UtilityTrailer](Models/UtilityTrailer/UtilityTrailer.gltf) | 13,148 | 7.10 × 3.02 × 12.41 | [PNG](Previews/UtilityTrailer_OldVsNew.png) |
| [LandscapeTrailer](Models/LandscapeTrailer/LandscapeTrailer.gltf) | 17,644 | 7.30 × 7.50 × 15.14 | [PNG](Previews/LandscapeTrailer_OldVsNew.png) |
| [EquipmentTrailer](Models/EquipmentTrailer/EquipmentTrailer.gltf) | 17,940 | 7.50 × 3.07 × 17.99 | [PNG](Previews/EquipmentTrailer_OldVsNew.png) |

Additional views: [RustyPickup DriverView](Previews/RustyPickup_DriverView.png), [WorkPickup DriverView](Previews/WorkPickup_DriverView.png), [HeavyDutyPickup DriverView](Previews/HeavyDutyPickup_DriverView.png), [LandscapingTruck DriverView](Previews/LandscapingTruck_DriverView.png).

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
