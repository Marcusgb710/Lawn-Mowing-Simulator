# 34_YardDecorations

22 model sources following instructions34 at main commit `2377b19`. The original kit, previous source packs, game assets and runtime code are preserved. The integration contracts were also reviewed against main commit `3c40d45`.

## Import handoff

Import [`ALL/34_YardDecorations.gltf`](ALL/34_YardDecorations.gltf) with its adjacent binary and shared Textures folder. Each top-level model root has only a grid translation. Individual `.gltf` + `.bin` and `.fbx` alternatives are under `Models/<Id>/`. Units are metres: **1 stud = 0.28 m**, +Y up, front -Z.

Keep mesh names, local hinge/axle origins, and model origins. Restore the existing Handle/Root and slot metadata from `model_manifest.json`. If Studio discards authoring empties, recreate Attachment instances from the manifest positions, LookVectors, parents and attributes. The glTF node extras and FBX custom properties provide the same authoring metadata.

Use the per-part collision roles and fidelity hints in the manifest. Do not flatten moving pieces or merge transparent pieces into opaque materials. The Color map uses sRGB; `atlas_palette.json` records its checked color swatches. Roughness, Metalness and Normal are data maps; the extra packed Metalness-Roughness PNG is the standard glTF rendering derivative of that same atlas.

**Studio import, asset upload and in-game replacement have not been run in this cloud environment.** These portable sources are the handoff for the local Studio session. No runtime scripts, light instances, brand marks or game publication are included.

## Pack details

SnapL/SnapR face outward. Fence, edging and mulch sections join along X; pavers join along Z. The fence has half-width end posts that combine to a normal post at joined boundaries. The decorated-lawn preview uses the actual exported design geometry and exact 8.6/4.3-stud snapping intervals.

Both shrubs have separate Overgrowth meshes. JapaneseMaple has a Canopy mesh; planter/bed/arbor vegetation uses Plants. Water and transparent lenses are separate meshes. Keep Seat, Light, Water and Spout attachment frames. Windmill Spinner rotates around its own Z axis. Arbor collision posts and roof pieces leave the walk-through opening clear. The previews contain staging lights and lawn geometry that are absent from the exported assets.

## Models

| Id | Triangles | Dimensions (studs) | Preview |
| --- | ---: | --- | --- |
| [PicketFenceSection](Models/PicketFenceSection/PicketFenceSection.gltf) | 1,944 | 8.60 × 3.20 × 0.40 | [PNG](Previews/PicketFenceSection_Preview.png) |
| [StoneEdgingSection](Models/StoneEdgingSection/StoneEdgingSection.gltf) | 972 | 4.30 × 0.55 × 0.90 | [PNG](Previews/StoneEdgingSection_Preview.png) |
| [PaverPathSection](Models/PaverPathSection/PaverPathSection.gltf) | 2,912 | 4.30 × 0.20 × 4.30 | [PNG](Previews/PaverPathSection_Preview.png) |
| [MulchBedSection](Models/MulchBedSection/MulchBedSection.gltf) | 2,340 | 8.60 × 0.40 × 4.30 | [PNG](Previews/MulchBedSection_Preview.png) |
| [BoxwoodShrub](Models/BoxwoodShrub/BoxwoodShrub.gltf) | 6,952 | 2.90 × 2.90 × 2.90 | [PNG](Previews/BoxwoodShrub_Preview.png) |
| [HydrangeaBush](Models/HydrangeaBush/HydrangeaBush.gltf) | 6,936 | 4.00 × 3.60 × 4.00 | [PNG](Previews/HydrangeaBush_Preview.png) |
| [JapaneseMaple](Models/JapaneseMaple/JapaneseMaple.gltf) | 12,832 | 9.00 × 9.00 × 9.00 | [PNG](Previews/JapaneseMaple_Preview.png) |
| [TerracottaPlanter](Models/TerracottaPlanter/TerracottaPlanter.gltf) | 5,220 | 2.00 × 2.80 × 2.00 | [PNG](Previews/TerracottaPlanter_Preview.png) |
| [RaisedGardenBed](Models/RaisedGardenBed/RaisedGardenBed.gltf) | 6,968 | 8.60 × 2.50 × 4.30 | [PNG](Previews/RaisedGardenBed_Preview.png) |
| [BirdBath](Models/BirdBath/BirdBath.gltf) | 2,928 | 2.20 × 2.60 × 2.20 | [PNG](Previews/BirdBath_Preview.png) |
| [TieredFountain](Models/TieredFountain/TieredFountain.gltf) | 7,172 | 6.00 × 5.40 × 6.00 | [PNG](Previews/TieredFountain_Preview.png) |
| [GardenArbor](Models/GardenArbor/GardenArbor.gltf) | 9,324 | 4.60 × 8.20 × 2.20 | [PNG](Previews/GardenArbor_Preview.png) |
| [GardenBench](Models/GardenBench/GardenBench.gltf) | 3,816 | 5.40 × 3.20 × 2.20 | [PNG](Previews/GardenBench_Preview.png) |
| [PatioSet](Models/PatioSet/PatioSet.gltf) | 9,076 | 8.60 × 8.00 × 8.60 | [PNG](Previews/PatioSet_Preview.png) |
| [FirePit](Models/FirePit/FirePit.gltf) | 5,936 | 4.00 × 1.40 × 4.00 | [PNG](Previews/FirePit_Preview.png) |
| [Mailbox](Models/Mailbox/Mailbox.gltf) | 1,072 | 1.20 × 4.00 × 2.20 | [PNG](Previews/Mailbox_Preview.png) |
| [LampPost](Models/LampPost/LampPost.gltf) | 2,704 | 1.30 × 7.60 × 1.30 | [PNG](Previews/LampPost_Preview.png) |
| [SolarPathLight](Models/SolarPathLight/SolarPathLight.gltf) | 992 | 0.50 × 1.40 × 0.50 | [PNG](Previews/SolarPathLight_Preview.png) |
| [BirdFeeder](Models/BirdFeeder/BirdFeeder.gltf) | 2,340 | 1.60 × 7.20 × 0.60 | [PNG](Previews/BirdFeeder_Preview.png) |
| [Birdhouse](Models/Birdhouse/Birdhouse.gltf) | 1,104 | 1.00 × 6.40 × 1.00 | [PNG](Previews/Birdhouse_Preview.png) |
| [PinkFlamingo](Models/PinkFlamingo/PinkFlamingo.gltf) | 2,940 | 1.10 × 3.00 × 1.80 | [PNG](Previews/PinkFlamingo_Preview.png) |
| [GardenWindmill](Models/GardenWindmill/GardenWindmill.gltf) | 3,132 | 2.40 × 5.40 × 2.00 | [PNG](Previews/GardenWindmill_Preview.png) |

Additional views: [DecoratedFrontLawn](Previews/DecoratedFrontLawn.png).

## Verification

`validation.json` records the exported-file checks, geometry checks and FBX re-import results. Bounds are measured from exported vertices. Every individual mesh is below 20,000 triangles; each model meets its total triangle ceiling. Old/new previews use the actual previous source under the same camera and lighting. New models have individual previews.
