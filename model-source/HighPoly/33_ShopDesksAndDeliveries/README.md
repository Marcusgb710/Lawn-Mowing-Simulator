# 33_ShopDesksAndDeliveries

7 model sources following instructions33 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/33_ShopDesksAndDeliveries.gltf`](ALL/33_ShopDesksAndDeliveries.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Screen and Screen2 are flat, untextured 16:9 rectangles with local +Y up and display face -Z. Preserve their names and frames for SurfaceGui placement. UseSpot faces the desk; ScreenView looks at the main display. Chairs face the desk and have floor-level origins. Tops, legs, cabinets and chairs have separate collision roles; small desktop items are grouped in Clutter.

Boxes are closed. Each flap, lid and front panel has its own fold-line origin and recorded animation axis. Contents lies on the interior floor or pallet deck. Suggested opening directions are +Z rotation for FlapL, -Z for FlapR, -X for FlapF, +X for FlapB/Lid, and -X for the crate's FrontPanel. Those describe rotation direction about each recorded local axis, not world translations.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [JobLaptopTable](Models/JobLaptopTable/JobLaptopTable.gltf) | 5,804 | 4.50 × 3.71 × 3.00 | [PNG](Previews/JobLaptopTable_Preview.png) |
| [JobComputerDesk](Models/JobComputerDesk/JobComputerDesk.gltf) | 9,808 | 5.58 × 4.25 × 3.51 | [PNG](Previews/JobComputerDesk_Preview.png) |
| [JobOfficeDesk](Models/JobOfficeDesk/JobOfficeDesk.gltf) | 10,644 | 6.00 × 4.40 × 5.40 | [PNG](Previews/JobOfficeDesk_Preview.png) |
| [DeliveryBoxSmall](Models/DeliveryBoxSmall/DeliveryBoxSmall.gltf) | 1,128 | 1.80 × 1.10 × 1.30 | [PNG](Previews/DeliveryBoxSmall_Preview.png) |
| [DeliveryBoxLong](Models/DeliveryBoxLong/DeliveryBoxLong.gltf) | 900 | 6.20 × 0.80 × 0.80 | [PNG](Previews/DeliveryBoxLong_Preview.png) |
| [DeliveryBoxLarge](Models/DeliveryBoxLarge/DeliveryBoxLarge.gltf) | 2,232 | 3.40 × 2.40 × 2.40 | [PNG](Previews/DeliveryBoxLarge_Preview.png) |
| [DeliveryCrate](Models/DeliveryCrate/DeliveryCrate.gltf) | 5,876 | 5.40 × 4.40 × 7.20 | [PNG](Previews/DeliveryCrate_Preview.png) |

Additional views: [JobLaptopTable ScreenView](Previews/JobLaptopTable_ScreenView.png), [JobComputerDesk ScreenView](Previews/JobComputerDesk_ScreenView.png), [JobOfficeDesk ScreenView](Previews/JobOfficeDesk_ScreenView.png).

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
