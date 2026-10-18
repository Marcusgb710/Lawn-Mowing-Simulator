# 26_MowersAndRideOns

8 model sources following instructions26 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved.

## Import handoff

Import [`ALL/26_MowersAndRideOns.gltf`](ALL/26_MowersAndRideOns.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The shared maps include Color, Roughness, Metalness and Normal; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Wheel assemblies keep their original names and X axle origins. CutterRotor meshes keep their Y spindle origins. Reel blades, tines, decks, controls, engine mounts and guards are authored geometry. Keep the named assemblies separate during import.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [ReelMower](Models/ReelMower/ReelMower.gltf) | 8,708 | 2.55 × 4.31 × 4.61 | [PNG](Previews/ReelMower_OldVsNew.png) |
| [SelfPropelledMower](Models/SelfPropelledMower/SelfPropelledMower.gltf) | 15,696 | 2.84 × 4.29 × 5.24 | [PNG](Previews/SelfPropelledMower_OldVsNew.png) |
| [CommercialReelMower](Models/CommercialReelMower/CommercialReelMower.gltf) | 9,796 | 2.50 × 3.57 × 4.50 | [PNG](Previews/CommercialReelMower_OldVsNew.png) |
| [CommercialZeroTurn](Models/CommercialZeroTurn/CommercialZeroTurn.gltf) | 19,244 | 6.30 × 6.80 × 7.42 | [PNG](Previews/CommercialZeroTurn_OldVsNew.png) |
| [StandOnMower](Models/StandOnMower/StandOnMower.gltf) | 17,496 | 5.00 × 4.50 × 6.00 | [PNG](Previews/StandOnMower_OldVsNew.png) |
| [StandOnAerator](Models/StandOnAerator/StandOnAerator.gltf) | 21,116 | 3.79 × 4.39 × 5.50 | [PNG](Previews/StandOnAerator_OldVsNew.png) |
| [TowBehindAerator](Models/TowBehindAerator/TowBehindAerator.gltf) | 13,292 | 4.48 × 2.17 × 5.00 | [PNG](Previews/TowBehindAerator_OldVsNew.png) |
| [RideOnSpreaderSprayer](Models/RideOnSpreaderSprayer/RideOnSpreaderSprayer.gltf) | 14,840 | 3.92 × 4.93 × 5.83 | [PNG](Previews/RideOnSpreaderSprayer_OldVsNew.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
