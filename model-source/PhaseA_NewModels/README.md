# Phase A: 58 new models, instructions 10–23

These are **new additions**, made separately from the supplied Lawn Mowing Mobile Kit. The red `GasCan` and green `MixGasCan` are both new designs, as requested. No supplied mesh or texture was edited, replaced, recolored, or copied into these models.

[Browse the previews](Previews/README.md) · [Asset catalog](CATALOG.md)

## Files

- `Models/<id>/<id>.fbx`: individual import sources; shared textures are in `Textures`.
- `Models/<id>/<id>.gltf` and `.bin`: portable alternative sources, with the same geometry.
- `PhaseA_NewModels.blend`: editable Blender 4.3 source with packed shared PBR textures; all 58 arranged in a library.
- `ALL_ASSETS/PhaseA_All58.gltf`: arranged library, useful for browsing. Use individual models for import at the origin.
- `Previews/10_Models.png` through `23_Models.png`: rendered family previews. Items are individually scaled for readability; consult the manifest for actual dimensions.
- `model_manifest.json`: precise dimensions, triangle counts, target folders, grip positions, trailer markers and storage slots, in Roblox studs (1 stud = 0.28 m).
- `export_validation.json`, `geometry_validation.json`: checks on the actual output files. These do not substitute for a Studio test.

## Studio handoff: still required

This cloud machine cannot connect to Roblox Studio or upload to Big Dink Studios. These are mesh sources, **not installed Roblox assets**. Upload ownership, 3D Importer behavior, MeshPart pivots, texture appearance and the instruction-file checks must be verified in Studio. Do not publish the game as part of import.

Import individual FBX files into a staging area. Set the importer creator to **Big Dink Studios** for every mesh and texture. Keep each item a Model, preserve its posed geometry and front direction (−Z), and compare its dimensions to `model_manifest.json` before moving it into `ReplicatedStorage.Assets.<folder>`. Import at the origin with no automatic recentering; the authoring unit is metres and one stud corresponds to 0.28 m. If the importer uses a different scale, correct it to the listed bounds first.

The source files retain separately named wheels/cutters/spools. Wheel axles are local X; cutter and spool axes are local Y in Roblox coordinates. Verify these axes and origins after import. Repeated tires share source mesh data. Studio may choose to create independent uploaded mesh IDs; reuse the same owned MeshId for identical tires when practical.

If the importer does not restore the PBR finish automatically, upload `PhaseA_Color.png`, `PhaseA_Roughness.png`, and `PhaseA_Metalness.png` as Big Dink Studios assets and assign them to each opaque MeshPart’s SurfaceAppearance ColorMap, RoughnessMap, and MetalnessMap. The combined metalness/roughness image is for glTF, rather than Roblox’s separate map slots. Preserve the blank display and bench-grinder eye shields as separate transparent parts.

After upload and scale/orientation verification, the command-bar snippet in `StudioPlacement.md` applies the manifest's invisible primary parts, trailer regions, storage attachments, anchoring and collision flags to selected imported Models. It inserts no scripts into the game and skips every already existing destination name. It cannot verify group ownership.

Existing supplied `Kit` assets and earlier `Tools` assets must remain unchanged. Do not import any original/earlier item from this package; none are included. If the destination already has one of these new names, leave it and report the collision rather than replacing it.

## Inventory

| Instruction | Destination | New models |
| --- | --- | --- |
| 10 | Tools | HandTrowel, HandTransplanter, HandCultivator, DandelionWeeder, Dibber |
| 11 | Tools | BypassPruners, AnvilPruners, FloralSnips, Loppers, PruningSaw |
| 12 | Tools | GardenHoseWand, WateringCan, NitrileGloves, ChemicalGloves |
| 13 | Tools | RoundPointShovel, GardenSpade, Broadfork, DiggingFork, Mattock |
| 14 | Tools | BowRake, StirrupHoe |
| 15 | Tools | SingleWheelbarrow, SingleWheelbarrowFlatFree, DualWheelbarrow, PolyCart, BroadcastSpreader, BackpackSprayer |
| 16 | Tools | CommercialZeroTurn, StandOnMower, CommercialReelMower |
| 17 | Tools | StraightShaftTrimmer, ArticulatingHedgeTrimmer, SoilProbe |
| 18 | Tools | StandOnAerator, TowBehindAerator, SlitOverseeder, PowerRakeDethatcher, RideOnSpreaderSprayer |
| 19 | Tools | GasCan, MixGasCan, TrimmerLine, FootPump, ElectricInflator, AirCompressor, TirePatchKit, SpareTire |
| 20 | Tools | WrenchSet, BladeFile, SharpeningStone, BenchGrinder, SpareMowerBlade, ToolBucket |
| 21 | Trailers | EquipmentTrailer |
| 22 | Buildings | EquipmentYard |
| 23 | Props | Workbench, StoragePegboard, StorageWallRack, StorageWallHooks |
