#!/usr/bin/env python3
"""Writes src/shared/Config/GuiArt.luau from the GUI art's manifest (alphainstructions/instructions38.md).

    python3 scripts/gui-art-ids.py [GUI folder] [--out file]

The GUI folder defaults to art-source/GUI in this repo. Pass another one to read the art from
somewhere else (another worktree, say). It reads:
  * manifest.json: every image the game uses (`role: "upload"`), the 9-slice centres, the
    palette, the fonts and the sprite sheets;
  * Fonts/*.fnt: the two bitmap fonts' metrics (AngelCode BMFont as JSON): each glyph's rectangle
    in its atlas, offsets and advance, the kerning pairs, the line height and the baseline;
  * uploaded.json, if it's there: the Roblox asset id of each uploaded image, by its manifest path:

        {
            "Kit/Panel.png": 123456789,
            "Icons/Money.png": "123456790",
            "Items/ReelMower.png": "rbxassetid://123456791"
        }

    An id can be a number, a string of digits or an "rbxassetid://" string. Images that aren't in
    it (or have an empty id) stay "", and the game draws those pieces with plain frames.

Upload the images as Big Dink Studios, add each id to uploaded.json, then run this again: GuiArt.luau
is the only thing that changes. The output is formatted with StyLua when it can find it.
"""

import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_GUI = os.path.join(ROOT, "art-source", "GUI")
DEFAULT_OUT = os.path.join(ROOT, "src", "shared", "Config", "GuiArt.luau")
FONT_KEYS = ("x", "y", "width", "height", "xoffset", "yoffset", "xadvance")
IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def fail(message: str):
    print(f"gui-art-ids: {message}", file=sys.stderr)
    sys.exit(1)


def read_json(path: str):
    try:
        with open(path, encoding="utf-8") as file:
            return json.load(file)
    except FileNotFoundError:
        fail(f"can't find {path}")
    except json.JSONDecodeError as error:
        fail(f"{path} isn't valid JSON: {error}")


def asset_id(path: str, value) -> str:
    """An uploaded.json id as "rbxassetid://N", or "" for none."""
    if value is None or value == "" or value == 0:
        return ""
    if isinstance(value, bool):
        fail(f"uploaded.json: {path} has {value!r}, not an asset id")
    if isinstance(value, int):
        return f"rbxassetid://{value}"
    if isinstance(value, str):
        text = value.strip()
        match = re.fullmatch(r"(?:rbxassetid://)?(\d+)", text)
        if match:
            return f"rbxassetid://{match.group(1)}"
    fail(f"uploaded.json: {path} has {value!r}, not an asset id")


def lua_string(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def lua_key(key: str) -> str:
    return key if IDENTIFIER.match(key) else f"[{lua_string(key)}]"


def lua(value, indent: int = 0) -> str:
    """A Luau literal for plain JSON-like data."""
    pad = "\t" * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, list):
        return "{ " + ", ".join(lua(item, indent) for item in value) + " }"
    if isinstance(value, dict):
        lines = [f"{pad}\t{lua_key(str(key))} = {lua(item, indent + 1)}," for key, item in value.items()]
        return "{\n" + "\n".join(lines) + f"\n{pad}}}"
    fail(f"can't write {value!r} as Luau")


def read_font(gui: str, entry: dict) -> dict:
    """One bitmap font's metrics, from its face .fnt (the outline's must match it)."""
    face = read_json(os.path.join(gui, entry["metrics"]))
    outline = read_json(os.path.join(gui, entry["outline_metrics"]))
    for key in ("chars", "kernings", "common"):
        if face.get(key) != outline.get(key):
            fail(f"{entry['name']}: the outline .fnt's {key} don't match the face's")
    common = face["common"]
    glyphs = {}
    for char in face["chars"]:
        if char.get("page", 0) != 0:
            fail(f"{entry['name']}: glyph {char['id']} is on page {char['page']}; only one atlas is supported")
        glyphs[int(char["id"])] = [int(char[key]) for key in FONT_KEYS]
    kerning: dict = {}
    for pair in face.get("kernings", []):
        first, second = int(pair["first"]), int(pair["second"])
        if first not in glyphs or second not in glyphs:
            fail(f"{entry['name']}: a kerning pair names a glyph that isn't there ({first}, {second})")
        kerning.setdefault(first, {})[second] = int(pair["amount"])
    return {
        "face": entry["face_atlas"],
        "outline": entry["outline_atlas"],
        "size": int(face["info"]["size"]),
        "lineHeight": int(common["lineHeight"]),
        "base": int(common["base"]),
        "capHeight": int(entry["cap_height_px"]),
        "atlas": [int(common["scaleW"]), int(common["scaleH"])],
        "glyphs": glyphs,
        "kerning": kerning,
    }


def font_block(name: str, font: dict) -> str:
    glyph_lines = []
    for code in sorted(font["glyphs"]):
        char = chr(code)
        shown = "space" if code == 32 else char if char.isprintable() and char != "\\" else f"U+{code:04X}"
        glyph_lines.append(f"\t\t\t\t[{code}] = {lua(font['glyphs'][code])}, -- {shown}")
    kerning_lines = []
    for first in sorted(font["kerning"]):
        pairs = ", ".join(f"[{second}] = {amount}" for second, amount in sorted(font["kerning"][first].items()))
        kerning_lines.append(f"\t\t\t\t[{first}] = {{ {pairs} }},")
    kerning = "{\n" + "\n".join(kerning_lines) + "\n\t\t\t}" if kerning_lines else "{}"
    return "\n".join(
        [
            f"\t\t{name} = {{",
            f"\t\t\tface = {lua_string(font['face'])},",
            f"\t\t\toutline = {lua_string(font['outline'])},",
            f"\t\t\tsize = {font['size']},",
            f"\t\t\tlineHeight = {font['lineHeight']},",
            f"\t\t\tbase = {font['base']},",
            f"\t\t\tcapHeight = {font['capHeight']},",
            f"\t\t\tatlas = {lua(font['atlas'])},",
            "\t\t\t-- [codepoint] = { x, y, width, height, xoffset, yoffset, xadvance } in atlas pixels",
            "\t\t\tglyphs = {",
            *glyph_lines,
            "\t\t\t},",
            "\t\t\t-- [first codepoint] = { [second codepoint] = how much closer (or further) the second goes }",
            f"\t\t\tkerning = {kerning},",
            "\t\t},",
        ]
    )


def slice_entry(info: dict) -> dict:
    entry = {"file": info["file"], "size": info["size_px"]}
    if info.get("slice_center_px"):
        entry["center"] = info["slice_center_px"]
    if info.get("content_inset_px"):
        entry["inset"] = info["content_inset_px"]
    if info.get("draw_scale"):
        entry["scale"] = 1 / info["draw_scale"]
    if info.get("tile_mode") == "horizontal":
        entry["tile"] = info["tile_display_size_px"]
    return entry


def main():
    args = sys.argv[1:]
    out = DEFAULT_OUT
    if "--out" in args:
        at = args.index("--out")
        if at + 1 >= len(args):
            fail("--out needs a file")
        out = os.path.abspath(args[at + 1])
        del args[at : at + 2]
    if len(args) > 1 or any(arg.startswith("-") for arg in args):
        fail("usage: python3 scripts/gui-art-ids.py [GUI folder] [--out file]")
    gui = os.path.abspath(args[0] if args else DEFAULT_GUI)
    manifest = read_json(os.path.join(gui, "manifest.json"))

    uploads = [entry["path"] for entry in manifest["files"] if entry.get("role") == "upload"]
    uploads.sort()
    sizes = {entry["path"]: entry["size_px"] for entry in manifest["files"] if entry.get("role") == "upload"}
    uploaded_path = os.path.join(gui, "uploaded.json")
    uploaded = read_json(uploaded_path) if os.path.exists(uploaded_path) else {}
    if not isinstance(uploaded, dict):
        fail("uploaded.json should be an object of manifest path to asset id")
    known = set(uploads)
    for path in uploaded:
        if path not in known:
            print(f"gui-art-ids: uploaded.json has {path}, which isn't an upload image in the manifest", file=sys.stderr)
    ids = {path: asset_id(path, uploaded.get(path)) for path in uploads}
    for name, info in manifest["slice_centers"].items():
        if info["file"] not in known:
            fail(f"slice {name} is {info['file']}, which isn't an upload image")

    fonts = {entry["name"]: read_font(gui, entry) for entry in manifest["bitmap_font_files"]}
    typography = manifest["typography"]
    sheets = {
        name: {
            "file": sheet["file"],
            "columns": sheet["columns"],
            "rows": sheet["rows"],
            "frames": sheet["frames"],
            "frameSize": sheet["frame_size_px"],
            "fps": sheet["fps"],
            "loop": sheet["loop"],
        }
        for name, sheet in manifest["sprite_sheets"].items()
    }
    mask = manifest["portrait_mask"]

    image_lines = [f"\t\t[{lua_string(path)}] = {lua_string(ids[path])}," for path in uploads]
    size_lines = [f"\t\t[{lua_string(path)}] = {lua(sizes[path])}," for path in uploads if sizes.get(path)]
    slice_lines = [f"\t\t{lua_key(name)} = {lua(slice_entry(info), 2)}," for name, info in manifest["slice_centers"].items()]
    palette_lines = [f"\t\t{lua_key(role)} = {lua_string(hex_)}," for role, hex_ in manifest["palette"].items()]
    filled = sum(1 for value in ids.values() if value)

    text = "\n".join(
        [
            "-- The GUI art (alphainstructions/instructions38.md, \"Maple Grove Summer\"), for the game to use.",
            "-- GENERATED by scripts/gui-art-ids.py from art-source/GUI/manifest.json, its .fnt fonts and",
            "-- uploaded.json. Don't edit it by hand: add the asset ids to uploaded.json and run the script again.",
            "-- An image whose id is \"\" isn't uploaded yet, and the game draws that piece with plain frames.",
            f"-- {filled} of {len(uploads)} images uploaded.",
            "--",
            "-- This file has no Roblox requires or types, so scripts/check-gui.luau can test it with Lune.",
            "",
            "return {",
            "\t-- Every image the game shows, by its path in art-source/GUI: \"rbxassetid://...\", or \"\".",
            "\tImages = {",
            *image_lines,
            "\t},",
            "\t-- Each image's width and height in pixels.",
            "\tSizes = {",
            *size_lines,
            "\t},",
            "\t-- 9-slices and other kit pieces: the source image's size, its slice centre (left, top, right,",
            "\t-- bottom, in source pixels), the content inset, the slice scale (drawn at 2x, so 0.5) and,",
            "\t-- for the striped fills, the size one tile is drawn at. No centre: it scales uniformly.",
            "\tSlices = {",
            *slice_lines,
            "\t},",
            "\t-- The palette by role (UI.luau maps the roles onto UI.Colors).",
            "\tPalette = {",
            *palette_lines,
            "\t},",
            "\t-- The two built-in Roblox font families for live text, and the display face drawn as images.",
            "\tTypography = {",
            f"\t\theading = {lua_string(typography['live_heading']['roblox_family'])},",
            f"\t\tbody = {lua_string(typography['live_body']['roblox_family'])},",
            f"\t\tbodyWeights = {lua(typography['live_body']['weights'])},",
            f"\t\tdisplay = {lua_string(typography['display']['family'])},",
            "\t},",
            "\t-- The display face as bitmap fonts: a white face atlas (tinted in game) over a deep green",
            "\t-- outline-and-shadow atlas, with the same rectangles in both. Sizes are in atlas pixels.",
            "\tFonts = {",
            *[font_block(name, font) for name, font in fonts.items()],
            "\t},",
            "\t-- Sprite sheets, left to right then top to bottom.",
            f"\tSpriteSheets = {lua(sheets, 1)},",
            "\t-- Where a portrait shows inside the portrait ring (in the ring's pixels).",
            f"\tPortraitMask = {{ frame = {lua(mask['frame_size_px'])}, inner = {lua(mask['inner_circle_size_px'])}, offset = {lua(mask['inner_offset_px'])} }},",
            "}",
            "",
        ]
    )
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as file:
        file.write(text)

    stylua = shutil.which("stylua") or os.path.expanduser("~/.rokit/bin/stylua")
    if os.path.exists(stylua):
        result = subprocess.run([stylua, out], cwd=ROOT, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"gui-art-ids: StyLua couldn't format it:\n{result.stderr}", file=sys.stderr)
    else:
        print("gui-art-ids: StyLua isn't installed; run `stylua src` before committing", file=sys.stderr)
    shown = os.path.relpath(out, ROOT) if out.startswith(ROOT + os.sep) else out
    print(f"Wrote {shown}: {filled} of {len(uploads)} images uploaded, {len(fonts)} fonts")


if __name__ == "__main__":
    main()
