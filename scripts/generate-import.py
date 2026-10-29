#!/usr/bin/env python3
"""Writes scripts/ImportStoreModels.luau from assets/manifest/models.json.

    python scripts/generate-import.py [manifest.json] [--check]

The manifest lists where every replaced model came from and how to make it fit (the format is
described under "Store models" in assets/README.md). The generated script is pasted into Studio's
command bar: it inserts each Creator Store asset, cleans and fits it, adds what the game expects of
a model, and stages it in ServerStorage.ModelImport for scripts/export-models.luau. Entries whose
source is "kept" stay as they are and get no code.

--check validates the manifest and writes nothing. Both modes print "N models", the count the
script will stage, and exit 1 with one line per problem when the manifest is wrong.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_MANIFEST = os.path.join(ROOT, "assets", "manifest", "models.json")
TEMPLATE = os.path.join(HERE, "ImportStoreModels.template.luau")
OUT = os.path.join(HERE, "ImportStoreModels.luau")

FOLDERS = ("Tools", "Trucks", "Trailers", "Buildings", "Props", "Decorations", "Story")
# Models that players walk into, drive or park against: their parts collide unless the entry says not to.
SOLID_FOLDERS = ("Trucks", "Trailers", "Buildings")
FACINGS = ("+X", "-X", "+Z", "-Z")
AXES = ("height", "width", "length")
ENTRY_FIELDS = (
    "id", "folder", "source", "keep", "facing", "up", "fit", "handle", "handlePart", "grips",
    "parts", "markers", "boxes", "synth", "collide", "strip", "budget",
)


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
    # Names stay readable as typed: json's \uXXXX escapes for other scripts are not valid Luau.
    return json.dumps(str(value), ensure_ascii=False)


def attributes(values: dict) -> str:
    if not values:
        return "{}"
    return "{ " + ", ".join(f"[{lua_value(key)}] = {lua_value(v)}" for key, v in values.items()) + " }"


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_whole(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def is_vec(value) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(is_number(v) for v in value)


def is_size(value) -> bool:
    return is_vec(value) and all(v > 0 for v in value)


def is_color(value) -> bool:
    return (
        isinstance(value, list)
        and len(value) == 3
        and all(isinstance(v, int) and not isinstance(v, bool) and 0 <= v <= 255 for v in value)
    )


def is_name(value) -> bool:
    return isinstance(value, str) and value != ""


def is_attributes(value) -> bool:
    return isinstance(value, dict) and all(is_name(k) and isinstance(v, (bool, int, float, str)) for k, v in value.items())


def is_strip(value) -> bool:
    return isinstance(value, str) and value.count(":") == 1 and all(value.split(":"))


# What a good value looks like, for the messages: (test, description).
NAME = (is_name, "a name")
BOOL = (lambda v: isinstance(v, bool), "true or false")
VEC = (is_vec, "three numbers")
SIZE = (is_size, "three numbers above zero")

SOURCE_FIELDS = {
    "store": {"assetId": (is_whole, "a whole number above zero"), "name": NAME, "creator": NAME},
    "blender": {"file": NAME},
    "kept": {},
}
SINGLE_FIELDS = {
    "keep": NAME,
    "facing": (lambda v: v in FACINGS, f"one of {', '.join(FACINGS)}"),
    "up": (lambda v: v == "+Y", '"+Y", the only up there is so far'),
    "handlePart": NAME,
    "collide": BOOL,
    "budget": (is_whole, "a whole number above zero"),
    "strip": (lambda v: isinstance(v, list) and all(is_strip(s) for s in v), 'a list of "Class:Name" strings'),
}
# Lists of tables: field -> (required, optional).
LIST_FIELDS = {
    "markers": (
        {"name": NAME, "position": VEC},
        {"orientation": VEC, "attributes": (is_attributes, "a table of numbers, strings and true/false")},
    ),
    "boxes": ({"name": NAME, "position": VEC, "size": SIZE}, {}),
    "synth": (
        {
            "name": NAME,
            "position": VEC,
            "size": SIZE,
            "material": NAME,
            "color": (is_color, "three whole numbers from 0 to 255"),
        },
        {"hinge": VEC},
    ),
}


def record_problems(where: str, record, required: dict, optional: dict) -> list:
    """What is wrong with a table that has to hold exactly these fields, each passing its own test."""
    if not isinstance(record, dict):
        return [f"{where} must be a table"]
    fields = {**required, **optional}
    problems = [f"{where} has an unknown field {key!r}" for key in record if key not in fields]
    for key, (test, hint) in fields.items():
        if key not in record:
            if key in required:
                problems.append(f"{where}.{key} is missing")
        elif not test(record[key]):
            problems.append(f"{where}.{key} must be {hint}")
    return problems


def entry_problems(entry: dict) -> list:
    """What is wrong with one entry, one message per problem, without the id in front."""
    problems = []
    if entry.get("folder") not in FOLDERS:
        problems.append(f"folder must be one of {', '.join(FOLDERS)}")
    source = entry.get("source")
    kind = source.get("kind") if isinstance(source, dict) else None
    if kind not in SOURCE_FIELDS:
        problems.append(f"source.kind must be one of {', '.join(SOURCE_FIELDS)}")
    else:
        problems += record_problems("source", source, {"kind": NAME, **SOURCE_FIELDS[kind]}, {})
    if kind == "kept":
        extra = [key for key in entry if key not in ("id", "folder", "source")]
        if extra:
            problems.append(f"a kept entry holds only id, folder and source, not {', '.join(extra)}")
        return problems

    problems += [f"unknown field {key!r}" for key in entry if key not in ENTRY_FIELDS]
    for field, (test, hint) in SINGLE_FIELDS.items():
        if field in entry and not test(entry[field]):
            problems.append(f"{field} must be {hint}")

    if "fit" not in entry:
        problems.append("fit is missing (axis and studs)")
    else:
        axis = (lambda v: v in AXES, f"one of {', '.join(AXES)}")
        studs = (lambda v: is_number(v) and v > 0, "a number above zero")
        problems += record_problems("fit", entry["fit"], {"axis": axis, "studs": studs}, {})

    holders = [field for field in ("handle", "handlePart") if field in entry]
    if entry.get("folder") == "Tools":
        if not holders:
            problems.append("a Tools entry needs handle or handlePart")
        elif len(holders) == 2:
            problems.append("use handle or handlePart, not both")
    elif holders or "grips" in entry:
        problems.append("handle, handlePart and grips only apply to Tools")
    if "handle" in entry:
        problems += record_problems("handle", entry["handle"], {"position": VEC, "size": SIZE}, {})
    if "grips" in entry:
        problems += record_problems("grips", entry["grips"], {"left": VEC, "right": VEC}, {})

    if "parts" in entry:
        if not isinstance(entry["parts"], dict):
            problems.append("parts must be a table of mesh name to { rename, collide }")
        else:
            for name, info in entry["parts"].items():
                problems += record_problems(f"parts[{name!r}]", info, {}, {"rename": NAME, "collide": BOOL})
    for field, (required, optional) in LIST_FIELDS.items():
        if field not in entry:
            continue
        if not isinstance(entry[field], list):
            problems.append(f"{field} must be a list")
            continue
        for index, item in enumerate(entry[field]):
            problems += record_problems(f"{field}[{index}]", item, required, optional)
    return problems


def validate(manifest: dict) -> list:
    """Every problem in the manifest as a line of text that names the entry it is about."""
    if not isinstance(manifest, dict):
        return ["manifest must be a table"]
    errors = []
    if manifest.get("version") != 1:
        errors.append("manifest: version must be 1")
    if not isinstance(manifest.get("complete"), bool):
        errors.append("manifest: complete must be true or false")
    if not isinstance(manifest.get("models"), list):
        return errors + ["manifest: models must be a list"]
    seen = set()
    for index, entry in enumerate(manifest["models"]):
        if not isinstance(entry, dict):
            errors.append(f"models[{index}]: must be a table")
            continue
        label = entry["id"] if is_name(entry.get("id")) else f"models[{index}]"
        if label != entry.get("id"):
            errors.append(f"{label}: id must be a name")
        where = (str(entry.get("folder")), label)
        if where in seen:
            errors.append(f"{label}: listed twice in {where[0]}")
        seen.add(where)
        errors += [f"{label}: {problem}" for problem in entry_problems(entry)]
    return errors


def staged(manifest: dict) -> list:
    """The entries the importer stages: everything but the models that stay as they are."""
    return [entry for entry in manifest["models"] if entry["source"]["kind"] != "kept"]


def source_lua(source: dict) -> str:
    keys = ("kind", "assetId", "name", "creator") if source["kind"] == "store" else ("kind", "file")
    return "{ " + ", ".join(f"{key} = {lua_value(source[key])}" for key in keys) + " }"


def part_lua(info: dict) -> str:
    fields = [f"{key} = {lua_value(info[key])}" for key in ("rename", "collide") if key in info]
    return "{ " + ", ".join(fields) + " }" if fields else "{}"


def marker_lua(marker: dict) -> str:
    return (
        f"{{ name = {lua_value(marker['name'])}, position = {vec(marker['position'])}, "
        f"orientation = {vec(marker.get('orientation', [0, 0, 0]))}, "
        f"attributes = {attributes(marker.get('attributes', {}))} }}"
    )


def box_lua(box: dict) -> str:
    return f"{{ name = {lua_value(box['name'])}, position = {vec(box['position'])}, size = {vec(box['size'])} }}"


def synth_lua(part: dict) -> str:
    fields = [
        f"name = {lua_value(part['name'])}",
        f"position = {vec(part['position'])}",
        f"size = {vec(part['size'])}",
        f"material = {lua_value(part['material'])}",
        f"color = Color3.fromRGB({', '.join(str(c) for c in part['color'])})",
    ]
    if "hinge" in part:
        fields.append(f"hinge = {vec(part['hinge'])}")
    return "{ " + ", ".join(fields) + " }"


def block(name: str, rows: list) -> str:
    return f"{name} = {{\n" + "".join(f"\t\t\t{row},\n" for row in rows) + "\t\t}"


def render_entry(entry: dict) -> str:
    folder, fit = entry["folder"], entry["fit"]
    fields = [
        f"id = {lua_value(entry['id'])}",
        f"folder = {lua_value(folder)}",
        f"source = {source_lua(entry['source'])}",
    ]
    if "keep" in entry:
        fields.append(f"keep = {lua_value(entry['keep'])}")
    fields += [
        f"facing = {lua_value(entry.get('facing', '-Z'))}",
        f"up = {lua_value(entry.get('up', '+Y'))}",
        f"fit = {{ axis = {lua_value(fit['axis'])}, studs = {lua_value(fit['studs'])} }}",
    ]
    if "handle" in entry:
        handle = entry["handle"]
        fields.append(f"handle = {{ position = {vec(handle['position'])}, size = {vec(handle['size'])} }}")
    if "handlePart" in entry:
        fields.append(f"handlePart = {lua_value(entry['handlePart'])}")
    if "grips" in entry:
        grips = entry["grips"]
        fields.append(f"grips = {{ left = {vec(grips['left'])}, right = {vec(grips['right'])} }}")
    # Always written out, so the generated script holds every rule and the template holds none.
    fields.append(f"collide = {lua_value(entry.get('collide', folder in SOLID_FOLDERS))}")
    if entry.get("parts"):
        fields.append(block("parts", [f"[{lua_value(name)}] = {part_lua(info)}" for name, info in entry["parts"].items()]))
    for field, render in (("markers", marker_lua), ("boxes", box_lua), ("synth", synth_lua)):
        if entry.get(field):
            fields.append(block(field, [render(item) for item in entry[field]]))
    if entry.get("strip"):
        pairs = (item.split(":") for item in entry["strip"])
        fields.append("strip = { " + ", ".join(f"{{ class = {lua_value(c)}, name = {lua_value(n)} }}" for c, n in pairs) + " }")
    if "budget" in entry:
        fields.append(f"budget = {lua_value(entry['budget'])}")
    return "\t{\n" + "".join(f"\t\t{field},\n" for field in fields) + "\t},"


def generate(manifest: dict, template: str) -> str:
    """The importer script: the template with the manifest's staged entries where --@MODELS@ is."""
    if "--@MODELS@" not in template:
        raise ValueError("the template has no --@MODELS@ line to fill")
    return template.replace("--@MODELS@", "\n".join(render_entry(entry) for entry in staged(manifest)))


def main():
    parser = argparse.ArgumentParser(description="Writes scripts/ImportStoreModels.luau from the model manifest.")
    parser.add_argument("manifest", nargs="?", default=DEFAULT_MANIFEST, help="default: assets/manifest/models.json")
    parser.add_argument("--check", action="store_true", help="validate the manifest and write nothing")
    args = parser.parse_args()
    try:
        with open(args.manifest, encoding="utf-8") as f:
            manifest = json.load(f)
    except (OSError, ValueError) as error:
        sys.exit(f"{args.manifest}: {error}")
    errors = validate(manifest)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    if not args.check:
        with open(TEMPLATE, encoding="utf-8") as f:
            script = generate(manifest, f.read())
        with open(OUT, "w", encoding="utf-8", newline="\n") as f:
            f.write(script)
    print(f"{len(staged(manifest))} models")


if __name__ == "__main__":
    main()
