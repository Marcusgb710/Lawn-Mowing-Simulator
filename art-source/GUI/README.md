# Maple Grove Summer — instruction 38

This is the finished GUI art handoff for instruction 38, which supersedes instruction 36. It contains one visual direction: cream lettering, deep-green outlines, tactile panels, mowing-stripe progress, Grandma's straw notes and TurfKing purple/gold.

Review [the system sheet](StyleFrames/Sheet.png), the eleven full-size screens in `StyleFrames/`, and identical copies plus half-size proofs in `Previews/`. The item and portrait contact sheets show all **127 item pictures** and **19 painted portraits** by id.

## What to upload

| Folder | Contents |
| --- | --- |
| `Kit/` | 55 text-free panels, buttons/states, tracks, prompts and story pieces |
| `Icons/` | 60 white, tintable 128² glyphs; review at 32 px |
| `Items/` | 127 actual-model studio pictures, 512² RGBA |
| `Portraits/` | 19 painted, expression-specific portraits, 512² |
| `Wordmarks/` | 14 fixed headlines, act titles and stamps |
| `Fonts/` | Two layered bitmap fonts and their JSON metrics |
| `Computer/` | Wallpaper, five app icons and the taskbar slice |
| `Moments/` | Trophy hero, 4×4 confetti and 2×2 sparkle sheets |
| `Store/` | Game icon, five 1920×1080 thumbnails, four passes, thirteen products |

Upload images under the ids in `manifest.json`; preserve case. Upload images are at most 1024 px on their longest side, except the explicitly requested store thumbnails. The manifest includes a file inventory, hashes, image dimensions, uses, item/portrait/store ids, palette, type choices and slice centres. `Source/`, `StyleFrames/`, `Previews/` and `Fonts/Specimen.png` are authoring/review material rather than game upload images.

### Slices, live text and bitmap lettering

The kit is drawn at 2×. A 48 px source radius represents a 24 px UI radius. Apply the manifest's `slice_center_px` rectangle to a nine-slice image; use a source scale of **0.5** for the intended corner/border size. Circular controls, reticles and portrait rings scale uniformly. Progress fills tile horizontally; do not stretch their stripes. Pressed button art already lowers the face by 2 source pixels.

Use exactly two built-in Roblox font families for live text: **DenkOne Regular** for headings, and **Nunito Regular/SemiBold/Bold/ExtraBold** for body text. Their role and weight rationale is in the manifest. Keep item names, messages, prices and descriptions live.

The custom display face is **Lilita One**, licensed under SIL OFL 1.1. `Display_Numbers` has 128 px caps and tabular digits; `Display_Headline` has 72 px caps and kerning. Each `.fnt` is AngelCode BMFont JSON, paired with a `_Face.png` and `_Outline.png` atlas. The companion `_Outline.fnt` references the second page using identical rectangles, offsets and advances. Lay out once using those metrics, render the green outline/shadow first, then the white face at the same origin and scale. Tint the face as needed. Apply each pair's kerning and line-height/base metadata; do not independently crop the layers. Font files and OFL licences are in `Fonts/Source/` for provenance; Roblox does not currently accept those TTF files as uploaded fonts.

The portrait ring is 256² with a 208² inner circle at offset `(24,24)`. Scale and circular-mask the portrait to that inner region before placing the ring over it. Phone frames use touch controls and tap copy; desktop frames show keyboard badges. Half-size phone buttons retain at least 44 px target height. Use Roblox's own Robux symbol when integrating; this kit does not draw one.

`Source/sprite_sheets.json` gives the sprite layouts. `Source/frame_layouts.json` records the finished screen composition regions; the style frames demonstrate layouts and are not flattened replacements for interactive UI.

## Editable sources

- `Source/design.py`, `build_icons.py`, `build_fonts.py`, `build_screens.py` and `build_store.py` build the kit, SVG glyphs, layered fonts, screens and purchase art. JSON files preserve tokens, slices, ids and layouts.
- `Source/render_items.py` renders existing high-poly model sources using one orthographic front-left view, warm key, cool rim and soft contact shadow. Premium finishes are render-only overrides, with wheels, tyres and glass preserved. The seven pickup finishes replace the original off-white painted panels while preserving trim.
- `Source/RenderOnly/` holds six copies of the supplied kit tools and their shared textures for rendering; it does not replace or modify any game model. `Source/ItemStudio.blend` preserves the common studio setup. `Source/ItemRenders/` preserves original studio renders before final framing.
- `Source/frame_items.py` uses actual serialized model vertices to frame the silhouette at 80% of the 512² image. Its report records every item's source projection and uniform crop. Shadows are retained but do not determine the subject's framing.
- `Source/PortraitSheets/`, `PortraitEdits/` and `extract_portraits.py` preserve painted portrait sources and extraction. These follow the final story character outfits; Rossi, Nguyen and the bridge-club avatar also follow the written brief.
- `Source/render_marketing.py` and its saved Blender scenes produce the world, rivalry, shears and trophy backgrounds. They reference the unchanged earlier title-card scene and the new instruction 37 scenes. `BusinessDesk.png` is a render of the existing shop desk with this GUI on its monitor.

### Rebuild order

Use Blender 4.3.2 and Python with Pillow, NumPy and fontTools. From the repository root, first rebuild the instruction 37 sources if needed, then:

```sh
python art-source/GUI/Source/build_fonts.py
python art-source/GUI/Source/design.py
python art-source/GUI/Source/build_icons.py
python art-source/GUI/Source/extract_portraits.py
blender -b -t 4 --python-exit-code 1 --python art-source/GUI/Source/render_items.py -- --overwrite
python art-source/GUI/Source/frame_items.py --capture-raw
blender -b -t 4 --python-exit-code 1 --python art-source/GUI/Source/render_items.py -- --hero --only BestYardTrophy --overwrite
blender -b -t 4 --python-exit-code 1 --python art-source/GUI/Source/render_marketing.py
python art-source/GUI/Source/build_screens.py
blender -b -t 4 --python-exit-code 1 --python art-source/GUI/Source/render_items.py -- --business --overwrite
python art-source/GUI/Source/build_store.py
python art-source/GUI/Source/build_screens.py
python art-source/GUI/Source/validate.py
```

For a partial item rerender, pass the same `--only Id1,Id2` list to both the renderer and `frame_items.py --capture-raw`. Capture only newly rendered raw images; applying `--capture-raw` to already framed images would frame them twice. Without that flag, the framing step is reproducible from its saved raw sources.

`validation.json` records count/id checks, sizes, alpha, white glyphs, slice bounds, font metrics, scene layout bounds, paired previews, silhouette framing and text contrast. Sources and original model packs are preserved; no runtime code changed.

**Upload and interactive wiring remain for the local Studio session using Big Dink Studios.** This cloud delivery does not create Roblox asset ids, install the UI in the game or publish the place.
