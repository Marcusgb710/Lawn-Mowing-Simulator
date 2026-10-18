# 31_PushMachines

8 model sources following instructions31 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved.

## Import handoff

Import [`ALL/31_PushMachines.gltf`](ALL/31_PushMachines.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The shared maps include Color, Roughness, Metalness and Normal; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

Keep wheel, slicing-disc, flail and spinner assemblies separate. Pneumatic tires include valves; the flat-free wheelbarrow and PolyCart use solid tires without valves. The single-wheel wheelbarrow holding frame intentionally remains midway between its two hand grips, as in the existing pack.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [SingleWheelbarrow](Models/SingleWheelbarrow/SingleWheelbarrow.gltf) | 9,352 | 2.40 × 2.66 × 5.30 | [PNG](Previews/SingleWheelbarrow_OldVsNew.png) |
| [SingleWheelbarrowFlatFree](Models/SingleWheelbarrowFlatFree/SingleWheelbarrowFlatFree.gltf) | 9,260 | 2.40 × 2.66 × 5.30 | [PNG](Previews/SingleWheelbarrowFlatFree_OldVsNew.png) |
| [DualWheelbarrow](Models/DualWheelbarrow/DualWheelbarrow.gltf) | 11,088 | 2.80 × 2.67 × 4.97 | [PNG](Previews/DualWheelbarrow_OldVsNew.png) |
| [PolyCart](Models/PolyCart/PolyCart.gltf) | 8,552 | 2.64 × 2.86 × 4.50 | [PNG](Previews/PolyCart_OldVsNew.png) |
| [BroadcastSpreader](Models/BroadcastSpreader/BroadcastSpreader.gltf) | 9,136 | 2.46 × 3.57 × 3.00 | [PNG](Previews/BroadcastSpreader_OldVsNew.png) |
| [WalkBehindEdger](Models/WalkBehindEdger/WalkBehindEdger.gltf) | 18,048 | 2.21 × 4.34 × 4.11 | [PNG](Previews/WalkBehindEdger_OldVsNew.png) |
| [SlitOverseeder](Models/SlitOverseeder/SlitOverseeder.gltf) | 15,880 | 2.20 × 3.57 × 5.00 | [PNG](Previews/SlitOverseeder_OldVsNew.png) |
| [PowerRakeDethatcher](Models/PowerRakeDethatcher/PowerRakeDethatcher.gltf) | 17,916 | 2.00 × 3.57 × 4.50 | [PNG](Previews/PowerRakeDethatcher_OldVsNew.png) |

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
