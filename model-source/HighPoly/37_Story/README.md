# Grandma's Rival — instruction 37

23 new story models: nine character poses, nine story props/places and five pieces of lawn junk. The existing model packs and supplied kit are unchanged.

Start with [CharacterSheet](Previews/CharacterSheet.png), [the porch scene](Previews/Scene_Porch.png) and [judging day](Previews/Scene_Contest.png). `Previews/` also contains one image per model. Preview lighting, cameras, fences and staging are authoring aids and are not part of the exported library.

## Import handoff

- Import `ALL/37_Story.gltf` with its `.bin` and relative `Textures/` paths intact. Each of its 23 top-level model nodes has a translation only and occupies a separate grid cell. Individual glTF/bin and binary FBX alternatives are in `Models/<Id>/`.
- Use `model_manifest.json` as the authoritative list of ids, destination folders (`Story`, `Props`, `Decorations`), dimensions, part names, bounds, markers and slots. Its schema follows pack 34. Add the logical `Root` PrimaryPart at `(0, 0.5, 0)` in each model's local stud space; it is metadata, not visible geometry.
- Authoring uses metres, with **1 stud = 0.28 m**, Roblox +Y up and front facing −Z. glTF retains these units; apply the same unit conversion used for the earlier high-poly packs. Do not bake the combined library's grid translations into model-local coordinates.
- Convert named empty marker nodes to Attachments on each manifest `parent_mesh`. Marker positions are in model-local stud space: transform them into their parent's local space when creating the Attachment. Their look direction is −Z. Preserve the neck pivot of each separate `__Head` mesh and the axle pivots of the truck's four wheel meshes.
- Characters are static poses, not rigs. Hats, hair and glasses are included in the movable head mesh. The trophy's `__Cup` and the truck's `__LightBar` remain separate.
- The Color atlas is sRGB; Roughness, Metalness and Normal are data maps. All shared maps are 2048². The additional packed Metalness-Roughness image supports standard glTF materials. Preserve transparent glass separately from opaque surfaces.

## Placement and collision

`NPC_June_Sitting` and `PorchRockingChair` share the **same ground origin**. Place both origins at `PorchDeck.ChairSpot`, whose height is 1.6 studs. The rocker's `Seat` marker is a reference on the cushion, not June's placement origin. The authored mug hand and armrest hand match this placement.

All three `GloriaYard_Stage*` roots go at the `GloriaHouse` ground origin. Swap them without an extra offset. They share X = −22…22 and Z = −48…−18; their walk and driveway align with the house's fitted porch and drive. This shared house origin is intentionally outside the yard footprint centre. `GloriaHouse.Driveway` positions the truck on the paved drive in front of the garage. `GloriaHouse.Porch` positions Gloria at her entrance.

Use the porch's clean floor and three step collision meshes for walking. Keep the decorative railings and character/junk geometry from becoming obstructive collision. Junk is a single mesh per id, no taller than 0.6 studs, and should have collision disabled. Manifest part hints identify the porch's collision pieces.

## Sources and verification

`Source/Story.blend` contains the native authored models and shared materials. The two `Source/Scene_*.blend` files retain the staged preview scenes. `Source/build37.py`, `core.py` and `specifications.json` contain the procedural source and dimensions. Blender 4.3.2, Python, NumPy and Pillow were used.

From the repository root:

```sh
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/37_Story/Source/export_story.py
blender -b -t 4 --python-exit-code 1 --python model-source/HighPoly/37_Story/Source/audit_fbx.py
blender -b model-source/HighPoly/37_Story/Source/Story.blend -t 4 --python-exit-code 1 --python model-source/HighPoly/37_Story/Source/render_story.py
python model-source/HighPoly/37_Story/Source/character_sheet.py
blender -b model-source/HighPoly/37_Story/Source/Story.blend -t 4 --python-exit-code 1 --python model-source/HighPoly/37_Story/Source/render_scenes.py
python model-source/HighPoly/37_Story/Source/validate.py
```

The character sheet uses the licensed Nunito font delivered with instruction 38 at `art-source/GUI/Fonts/Source/Nunito-800.ttf`.

`validation.json` audits the serialized glTF buffers, triangle budgets, normals, UVs, actual transformed bounds, sizes, markers and translation-only library roots. `Source/fbx_review.json` records independent reimports of all 23 FBX files. `checksums.sha256` covers the delivered source/export files for transfer verification.

These are portable mesh sources. **Studio import, attachment creation and in-game placement remain for the local session using Big Dink Studios.** No assets were uploaded or published from this environment.
