# 24_YardAndBuildings

7 model sources following instructions24 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/24_YardAndBuildings.gltf`](ALL/24_YardAndBuildings.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

The four business buildings are hollow. Their floors, roofs and convex wall pieces are separate collision meshes. The Shed door is open; sectional doors are raised. `Mount`, `FloorSpot`, `EquipmentBay`, `Desk`, `DeliverySpot`, `TruckParking` and `Light` nodes are authoring empties marked as Roblox Attachments. Every new building attachment belongs to `<Id>__Floor`; retain its Kind/Index attributes and LookVector. The manifest also retains every original BaySpot. Name the six flower-clump BaseParts `Flower` during Studio import (duplicate sibling names are valid): the current LawnService shrinks that exact name. The authoring sources keep the original `Flower`, `Flower.001` and subsequent names so their meshes remain distinct.

Mounts describe the fixture's back-bottom centre on a wall. When placing a fixture whose preserved model origin is at its centre (for example Workbench), offset its rear bound onto that plane; do not put half the fixture through the wall. Desk markers describe footprint centres. Dashed areas in the layout SVGs reserve player access. The delivery, desk, player and equipment footprints have no overlaps. The enlarged buildings use the explicit size exceptions in instructions24.

EquipmentYard has five independent front lean-to bays, a 9.07-stud clear loading aisle, and a low partition defining the office corner. SmallOffice has an internal office/shop partition and two shop equipment bays. The truck parking marker faces the street. Render-only illumination is absent from the source files.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [House](Models/House/House.gltf) | 17,004 | 30.30 × 17.78 × 18.44 | [PNG](Previews/House_OldVsNew.png) |
| [FlowerPatch](Models/FlowerPatch/FlowerPatch.gltf) | 5,230 | 3.45 × 0.87 × 3.45 | [PNG](Previews/FlowerPatch_OldVsNew.png) |
| [GardenGnome](Models/GardenGnome/GardenGnome.gltf) | 5,452 | 0.86 × 2.40 × 0.83 | [PNG](Previews/GardenGnome_OldVsNew.png) |
| [Shed](Models/Shed/Shed.gltf) | 19,588 | 13.50 × 11.78 × 12.80 | [PNG](Previews/Shed_OldVsNew.png) |
| [Garage](Models/Garage/Garage.gltf) | 17,336 | 27.70 × 15.83 × 23.70 | [PNG](Previews/Garage_OldVsNew.png) |
| [SmallOffice](Models/SmallOffice/SmallOffice.gltf) | 13,468 | 37.70 × 17.55 × 29.73 | [PNG](Previews/SmallOffice_OldVsNew.png) |
| [EquipmentYard](Models/EquipmentYard/EquipmentYard.gltf) | 20,476 | 45.70 × 21.79 × 33.70 | [PNG](Previews/EquipmentYard_OldVsNew.png) |

Additional views: [Shed Interior](Previews/Shed_Interior.png), [Garage Interior](Previews/Garage_Interior.png), [SmallOffice Interior](Previews/SmallOffice_Interior.png), [EquipmentYard Interior](Previews/EquipmentYard_Interior.png).

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
