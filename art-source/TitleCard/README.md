# Title card art — instruction 35

The key art uses the unchanged HighPoly Shed, RustyPickup, SelfPropelledMower and yard props. It shows an open shop, visible pegboard and tools, a lowered pickup tailgate with a mower in the bed, and a mower at the edge of the last cut lawn stripe. Warm morning light, a clear sky and distant houses leave room for the interface.

## Preview

- [PC, 16:9](Previews/TitleCard_16x9.png)
- [Wide phone, 19.5:9](Previews/TitleCard_Phone.png)
- [Tablet, 4:3](Previews/TitleCard_Tablet.png)
- [Logo at 300 pixels wide](Previews/Logo_300px.png)
- [Background safe zone](Previews/Background_SafeZone.png)

Mock-ups follow the current loading screen's crop-to-fill background, logo fit and maximum-size constraints, and 68% loading state. They are reference images; upload the seven images below.

## Local Studio handoff

Upload as **Big Dink Studios**, then enter the returned IDs in `src/first/TitleCardArt.luau` in the local Studio session:

| Configuration | PNG |
| --- | --- |
| `Logo` | `Logo.png` |
| `Background[1]` | `Background_TL.png` |
| `Background[2]` | `Background_TR.png` |
| `Background[3]` | `Background_BL.png` |
| `Background[4]` | `Background_BR.png` |
| `Mower` | `Mower.png` |
| `Stripes` | `Stripes.png` |

Every upload image is at most 1024 pixels on its longest side. **Do not upload Background_Master.png as the in-game image**: it is the 2048 × 1152 source from which the four exact tiles were cut. Keep the tile order TL, TR, BL, BR. Do not trim or rescale individual tiles. Logo and mower use straight RGBA transparency; backgrounds and stripes are opaque RGB PNGs.

This handoff does not upload images, edit runtime configuration, replace game models, or publish the game.

## Composition and safe zones

The master is 2048 × 1152. PC shows the whole master. A 19.5:9 phone shows the central 2048 × 945, starting at y = 103.5. A 4:3 tablet shows the central 1536 × 1152, starting at x = 256. Their common safe rectangle is **[256, 103.5, 1792, 1048.5]**, using exclusive right/bottom coordinates.

The full shed, truck, both mowers, mailbox, inner fence sections and flower beds fit in that common rectangle. Outer fence extensions and far houses are decorative. The upper middle is open sky. The loading track remains over a quiet section of the driveway/lawn. `manifest.json` gives the logo's alpha-weighted visual centre, ink bounds and frame centre; the current UI fits the full 1024 × 512 canvas.

## Editable sources and reproduction

- `Source/TitleCard.blend`: full key-art scene, packed textures, camera, lighting and staging. Rendering the saved scene produces `Background_Master.png`.
- `Source/Mower.blend`: orthographic right-facing mower, packed textures and transparent world.
- `Source/Logo.svg`: portable vector outlines and editable lawn mark, with no installed-font dependency.
- `Source/Fonts/`: Fredoka variable font, its 650-weight static instance, and the SIL Open Font License. Original font source: [Google Fonts / Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka).
- `Source/build_scene.py`: rebuild the scene from the repository's original individual glTF sources, with render-only staging and the authored tailgate hinge pose.
- `Source/build_mower.py`: rebuild the icon scene from the same mower source.
- `Source/build_graphics.py`: reproduce the logo, stripe tile, pixel-exact background tiles and screen mock-ups.
- `Source/validate.py`: validate image dimensions, transparency, tile assembly, seamless stripe boundaries, safe bounds, font and file scope; regenerate the manifest and validation report.

From the repository root, with Blender 4.3 and Python 3 plus Pillow, NumPy and fontTools:

```sh
blender -b -t 4 --python art-source/TitleCard/Source/build_scene.py
blender -b -t 4 --python art-source/TitleCard/Source/build_mower.py
python art-source/TitleCard/Source/build_graphics.py
blender -b -t 1 --python art-source/TitleCard/Source/prepare_sources.py
python art-source/TitleCard/Source/validate.py
```

For an already saved scene, set the output path when rendering on another machine, for example:

```sh
blender -b art-source/TitleCard/Source/TitleCard.blend -t 4 -o //../Background_Master -F PNG -f 1
```

Blender appends the frame number with that command; rename `Background_Master0001.png` to `Background_Master.png` before slicing. The construction scripts set the exact output filenames automatically. All render-only staging lives in these scenes; every source-model file remains unchanged.
