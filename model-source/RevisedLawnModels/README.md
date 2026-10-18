# Revised lawn models

This handoff supersedes the 27 primitive `.rbxmx` drafts on `codex/requested-models`.
It contains 27 revised mesh assets, their editable Blender library, shared textures,
comparison renders, and measured export validation. It has not been uploaded,
published, or tested in Roblox Studio.

## Keep the original kit

Keep the existing game assets `GasPushMower`, `RidingMower`, `ZeroTurnMower`,
`ElectricTrimmer`, `GasTrimmer`, and `OldRake`. They already use the original kit.
Do not replace them with primitive drafts. Keep the original kit's 34 assets intact.

The new `SelfPropelledMower`, `Brushcutter`, and `WideRake` reuse and adapt the
original push mower, petrol trimmer, and rake geometry. Other missing assets have
beveled mesh geometry, kit-atlas finishes, and separate animated components.
This is a revised art pass for review; comparable final quality still requires
an artist's visual review in Studio, including grip and equipment-detail polish.

## Import into the game

1. Extract this entire folder. Keep `Models` and `Textures` together.
2. In the Big Dink Studios Lawn Mowing game, import
   `Models/ALL_REVISED/AllRevisedModels.gltf` using File → Import 3D. Select
   **Big Dink Studios** as Creator. These new meshes and any new textures must be
   owned by the group. Keep hierarchy, separate moving parts, and PBR materials.
   Individual glTF and FBX files are also supplied in each model folder.
3. Select only the newly imported library. Run `PrepareRevisedModels.luau` in
   Studio's Command Bar. It normalizes scale and position, creates Root/Handle and
   BedArea markers, sets Slots, and moves new models to the appropriate Assets
   folders. It leaves any existing asset of the same name untouched and reports
   skipped items. It creates no runtime scripts and does not publish the game.
4. Check dimensions and orientation, six Flower parts, tool holds, moving-component
   axes, bed loading, trailers, collisions, and appearance beside the original kit.
   Importer material splitting and pivots can differ; the helper reports obvious
   orientation mismatches rather than guessing.
5. Save each prepared model to `.rbxm` in the corresponding repository asset
   folder, then verify `rojo build` and a Studio playtest. Saving the mesh source
   alone does not update the Roblox game or its uploaded asset IDs.

Do not merge the old primitive asset drafts over these Studio models. The source
handoff belongs outside `assets/`; only prepared `.rbxm` models belong there.

## Validation and limits

`model_manifest.json` records actual triangle counts, budgets, dimensions, moving
components, and grip/BedArea coordinates. `export_validation.json` checks actual
glTF binary buffers, indices, normals, UVs, texture references, and triangle counts.
`geometry_validation.json` records mesh topology checks. The material primitive
count is included because Studio may split a mesh by material on import.

All 27 assets fit the written triangle budgets. The comparison images are actual
Blender renders of the meshes, not Roblox screenshots. Studio import, group asset
ownership, moderation, runtime animation, gameplay, and phone performance remain
unverified. API permissions in this cloud do not provide a desktop Studio session.

The uploaded original kit was used as asset/reference data. No scripts from the
archive were executed and its original models were not modified.
