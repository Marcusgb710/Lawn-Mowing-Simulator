#!/usr/bin/env python3
"""Uploads the lawn textures and the grass tuft sheet to Roblox as Big Dink Studios.

    python scripts/upload-grass-art.py [--dry-run]

The four images go up as Image assets through Open Cloud, and each id is written into
src/shared/Config/GrassArt.luau as it lands. It uses scripts/upload-gui-art.py for the key, the
request and the retries, so the key comes from $ROBLOX_API_KEY or ~/.roblox-opencloud-key and needs
Assets read and write for the group. Never commit the key.

An image whose id in GrassArt.luau isn't 0 is skipped, so it can be stopped and run again. To
upload a changed image again, set its id back to 0 first. --dry-run lists what it would send and
sends nothing.

If Roblox answers 401 or 403 the key can't upload assets. Then it prints how to do the same thing
by hand in Studio's Asset Manager, leaves the ids alone and exits with status 2.
"""

import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "shared", "Config", "GrassArt.luau")
TEXTURES = "art-source/GUI/Source/RenderOnly/Textures"

# The field in GrassArt.luau, the image's path from the repo root, and the name Roblox shows for it.
IMAGES = [
    ("Mown", TEXTURES + "/Lawn_Mown_Color.png", "LMS_Grass_Mown"),
    ("Uncut", TEXTURES + "/Lawn_Uncut_Color.png", "LMS_Grass_Uncut"),
    ("Soil", TEXTURES + "/Soil_Color.png", "LMS_Grass_Soil"),
    ("Tufts", "art-source/Grass/Grass_Tufts.png", "LMS_Grass_Tufts"),
]


def load_gui_uploader():
    # The file name has a hyphen, so it can't be imported by name.
    spec = importlib.util.spec_from_file_location("upload_gui_art", os.path.join(ROOT, "scripts", "upload-gui-art.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_ids():
    text = open(CONFIG, encoding="utf-8").read()
    ids = {}
    for field, _, _ in IMAGES:
        found = re.search(rf"^\t{field} = (\d+),", text, re.MULTILINE)
        if not found:
            sys.exit(f"{CONFIG} has no line '{field} = <id>,'.")
        ids[field] = int(found.group(1))
    return ids


def write_id(field, asset_id):
    text = open(CONFIG, encoding="utf-8").read()
    text, count = re.subn(rf"^(\t{field} = )\d+,", rf"\g<1>{int(asset_id)},", text, flags=re.MULTILINE)
    if count != 1:
        sys.exit(f"{CONFIG} has no single line '{field} = <id>,' to write the id to.")
    with open(CONFIG + ".tmp", "w", encoding="utf-8", newline="\n") as file:
        file.write(text)
    os.replace(CONFIG + ".tmp", CONFIG)


def print_manual_steps(todo):
    print()
    print("The Open Cloud key can't upload assets (it needs the Assets scope with read and write for")
    print("Big Dink Studios, set in Creator Hub under Open Cloud, API Keys). To do it by hand instead:")
    print("  1. Open the game in Studio (it is published under Big Dink Studios).")
    print("  2. View > Asset Manager > Images > Bulk Import, and pick these files:")
    for _, path, _ in todo:
        print(f"       {path}")
    print("  3. In Asset Manager, right-click each image > Copy ID to Clipboard.")
    print("  4. Paste each id, as a plain number, into src/shared/Config/GrassArt.luau:")
    for field, path, _ in todo:
        print(f"       {field:<6} {os.path.basename(path)}")


def main():
    dry = "--dry-run" in sys.argv
    gui = load_gui_uploader()
    ids = read_ids()
    todo = [image for image in IMAGES if not ids[image[0]]]
    for field, path, name in IMAGES:
        full = os.path.join(ROOT, path)
        if not os.path.exists(full):
            hint = " Draw it with scripts/make-grass-tufts.py first." if field == "Tufts" else ""
            sys.exit(f"Missing {path}.{hint}")
        state = f"already uploaded as {ids[field]}, skipped" if ids[field] else f"will be named {name}"
        print(f"  {field:<6} {path} ({os.path.getsize(full)} bytes): {state}")
    print(f"{len(IMAGES) - len(todo)} of {len(IMAGES)} already uploaded, {len(todo)} to go, as Image assets under group {gui.GROUP_ID} (Big Dink Studios).")
    if dry or not todo:
        return
    key = gui.read_key()

    failures = []
    for field, path, name in todo:
        asset_id, problem = gui.upload(key, ROOT, path, name=name, description=f"Lawn Mowing Simulator lawn art: {path}")
        if asset_id:
            write_id(field, asset_id)
            print(f"{field} -> {asset_id}", flush=True)
        elif (problem or "").startswith(("HTTP 401", "HTTP 403")):
            print(f"FAILED {path}: {' '.join(problem.split()[:2])}")
            left = read_ids()
            print_manual_steps([image for image in IMAGES if not left[image[0]]])
            sys.exit(2)
        else:
            problem = problem or "Roblox finished but sent no asset id"
            failures.append((path, problem))
            print(f"FAILED {path}: {problem}", flush=True)

    print(f"Done: {len(todo) - len(failures)} uploaded, {len(failures)} failed.")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
