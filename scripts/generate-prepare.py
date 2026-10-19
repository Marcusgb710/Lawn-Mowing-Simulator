#!/usr/bin/env python3
"""Writes scripts/PrepareChatGPTModels.luau from ChatGPT's model manifests.

    python3 scripts/generate-prepare.py [manifest.json ...]

With no arguments it reads model-source/HighPoly/*/model_manifest.json. Each manifest is one pack
(one combined .gltf to import). The generated script is pasted into Studio's command bar after
File > Import 3D; see its header for the steps.
"""

import glob
import json
import os
import sys

OUT = "scripts/PrepareChatGPTModels.luau"
# Parts whose pivot has to sit on their hinge or axis, because the game turns them about it
# (Openings, DeliveryService, DecorService). Wheels and tool rotors turn about their centre.
CENTRED_ROLES = {"wheel", "rotor"}


def num(value: float) -> str:
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def vec(values) -> str:
    return f"Vector3.new({', '.join(num(v) for v in values)})"


def lua_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return num(value)
    return json.dumps(str(value))


def attributes(values: dict) -> str:
    return "{ " + ", ".join(f"{key} = {lua_value(v)}" for key, v in values.items()) + " }"


def model_entry(asset: dict, pack: str, meters_per_stud: float) -> str:
    layout = [v / meters_per_stud for v in asset["library_translation_meters"]]
    parts, boxes, attachments = [], [], []
    for part in asset.get("parts", []):
        fields = [f"collide = {lua_value(bool(part['can_collide']))}", f"fidelity = {json.dumps(part['collision_fidelity'])}"]
        if part.get("motion_mode") and part.get("role") not in CENTRED_ROLES:
            fields.append(f"pivot = {vec(part['origin_studs'])}")
        parts.append(f"[{json.dumps(part['name'])}] = {{ {', '.join(fields)} }}")
    for marker in asset.get("markers", []):
        if marker.get("instance_type") == "Attachment":
            attrs = dict(marker.get("attributes") or {})
            attachments.append(
                f"{{ name = {json.dumps(marker['name'])}, parent = {json.dumps(marker.get('parent_mesh') or '')}, "
                f"position = {vec(marker['position_studs'])}, orientation = {vec(marker.get('orientation_degrees') or [0, 0, 0])}, "
                f"attributes = {attributes(attrs)} }}"
            )
        else:
            slots = f", slots = {marker['Slots']}" if "Slots" in marker else ""
            boxes.append(
                f"{{ name = {json.dumps(marker['name'])}, position = {vec(marker['position_studs'])}, "
                f"size = {vec(marker['size_studs'])}{slots} }}"
            )
    slots = [vec(position) for position in asset.get("slots", []) if isinstance(position, list)]
    return (
        f"\t{asset['name']} = {{ pack = {json.dumps(pack)}, folder = {json.dumps(asset['folder'])}, "
        f"low = {vec(asset['bounds_min_studs'])}, high = {vec(asset['bounds_max_studs'])}, layout = {vec(layout)}, "
        f"primary = {json.dumps(asset['primary_part'])}, primaryAt = {vec(asset['primary_position_studs'])}, "
        f"markers = {{ {', '.join(boxes)} }}, attachments = {{ {', '.join(attachments)} }}, "
        f"slots = {{ {', '.join(slots)} }}, parts = {{ {', '.join(parts)} }} }},"
    )


def main():
    paths = sys.argv[1:] or sorted(glob.glob("model-source/HighPoly/*/model_manifest.json"))
    if not paths:
        sys.exit("No manifests found. Check out model-source/HighPoly first.")
    entries, packs = [], []
    for path in paths:
        # A pack's name is its folder (model-source/HighPoly/<pack>/model_manifest.json), or the
        # file's own name for a manifest saved somewhere else as <pack>.json.
        stem = os.path.splitext(os.path.basename(path))[0]
        pack = os.path.basename(os.path.dirname(path)) if stem == "model_manifest" else stem
        manifest = json.load(open(path))
        meters = manifest.get("meters_per_stud", 0.28)
        packs.append(pack)
        for asset in manifest["assets"]:
            entries.append(model_entry(asset, pack, meters))
    template = open(os.path.join(os.path.dirname(__file__), "PrepareChatGPTModels.template.luau")).read()
    script = template.replace("--@MODELS@", "\n".join(sorted(entries))).replace(
        "--@PACKS@", ", ".join(json.dumps(p) for p in packs)
    )
    open(OUT, "w").write(script)
    print(f"wrote {OUT}: {len(entries)} models from {len(packs)} packs")


if __name__ == "__main__":
    main()
