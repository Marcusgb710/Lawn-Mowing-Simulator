#!/usr/bin/env python3
"""Writes a layout saved in the HUD editor into src/client/UiLayout.luau.

    python3 scripts/apply-hud-layout.py <saved.json> [--dry-run]

<saved.json> is what the editor saved: its `layouts/current` document (Claude reads it from the
artifact's database), or what its "Copy layout for Claude" button copied. Only the placement fields
change: screen, parent, order, list, anchor, position, size, scale, touch and compact. Labels,
notes, comments and everything else in the file stay as they are. Pieces the file doesn't have are
skipped.

Each saved piece says what to change in its entry, the way a JSON merge patch does (RFC 7396):
  * a field the save leaves out stays as it is in the file;
  * a field that's null comes out of the entry;
  * any other value replaces the field's, so a field the entry hasn't got yet goes in, next to the
    placement fields around it (screen and parent by group).
touch, compact and list are tables, and what's in them goes the same way: a key left out stays, one
that's null comes out, and one that's left empty comes out altogether. So `"touch": null` drops a
piece's phone places, `"touch": {"scale": null}` drops only its phone scale, and touch's and
compact's `typical` (the editor's guess at the size there) stays unless the save names it. A HUD
column's piece can be out of its column on a touch screen only (`"touch": {"parent": false}`), or in
it there (the column's name), and touch's and compact's `hideWhile` (what a piece gives way to)
stays as the save has it.

It prints what changed in each piece, runs stylua on the file, and reads it back (lune run
scripts/ui-layout-json): every piece has to come out as the file was with the save's changes, and
nothing else may have changed.
"""

import copy
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = os.path.join(ROOT, "src", "client", "UiLayout.luau")
# The fields a save can change.
FIELDS = ("screen", "parent", "order", "list", "anchor", "position", "size", "scale", "touch", "compact")
# Every field an entry can have, in the order the file writes them: a field that's new to an entry
# goes after the nearest one before it here that the entry has.
ORDER = (
    "label",
    "group",
    "screen",
    "parent",
    "detach",
    "order",
    "list",
    "anchor",
    "position",
    "size",
    "autoSize",
    "min",
    "max",
    "scale",
    "typical",
    "touch",
    "compact",
    "device",
    "fixed",
    "note",
)
# What can be in touch and compact, and in a list, in the order they're written.
PLACES = ("anchor", "position", "size", "scale", "typical", "hideWhile")
LIST_KEYS = ("direction", "padding", "align")
TABLES = {"touch": ("parent",) + PLACES, "compact": PLACES, "list": LIST_KEYS}
# How many numbers each kind of place is.
COUNTS = {"anchor": 2, "position": 4, "size": 4, "typical": 2}
# How big or small a scale can be (as scripts/check-gui.luau checks).
SMALLEST_SCALE, BIGGEST_SCALE = 0.25, 3


def fail(message):
    print(f"apply-hud-layout: {message}", file=sys.stderr)
    sys.exit(1)


def tool(name):
    found = shutil.which(name)
    if found:
        return found
    rokit = os.path.expanduser(f"~/.rokit/bin/{name}" + (".exe" if os.name == "nt" else ""))
    return rokit if os.path.exists(rokit) else None


def read_layout():
    """UiLayout.luau as the game reads it: every entry, by its name."""
    lune = tool("lune")
    if not lune:
        fail("can't find lune (rokit install puts it in ~/.rokit/bin)")
    result = subprocess.run([lune, "run", "scripts/ui-layout-json"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        fail("UiLayout.luau doesn't read:\n" + result.stderr.strip())
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        fail(f"scripts/ui-layout-json didn't print JSON ({error})")


def elements_of(saved):
    for key in ("elements", "hudLayout"):
        if isinstance(saved.get(key), dict):
            return saved[key]
    if isinstance(saved.get("data"), dict):
        return elements_of(saved["data"])
    fail("that file has no saved layout in it (expected an `elements` table)")


# ---------------------------------------------------------------- what the save says
def checked(where, key, value):
    """`value` for `key` if it's the right shape for it (failing if not)."""
    if key in COUNTS:
        count = COUNTS[key]
        if not (isinstance(value, list) and len(value) == count and all(is_number(v) for v in value)):
            fail(f"{where} should be {count} numbers, not {value!r}")
    elif key in ("scale", "order", "padding"):
        if not is_number(value):
            fail(f"{where} should be a number, not {value!r}")
        if key == "scale" and not SMALLEST_SCALE <= value <= BIGGEST_SCALE:
            fail(f"{where} is {value}: a scale goes from {SMALLEST_SCALE} to {BIGGEST_SCALE}")
    elif key == "parent" and where.endswith(".touch.parent"):
        # on a touch screen: false is out of its column
        if value is not False and not (isinstance(value, str) and value):
            fail(f"{where} should be false or a column's name, not {value!r}")
    elif key in ("screen", "parent", "direction", "align"):
        if not isinstance(value, str) or not value:
            fail(f"{where} should be a name, not {value!r}")
    elif key == "hideWhile":
        if not (isinstance(value, list) and value and all(isinstance(v, str) and v for v in value)):
            fail(f"{where} should be a list of pieces' names, not {value!r}")
    return value


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def patched(piece, entry, patch, notes):
    """The entry's placement fields once `patch` (what was saved for it) is applied."""
    after = {name: copy.deepcopy(entry[name]) for name in FIELDS if name in entry}
    for name in FIELDS:
        if name not in patch:
            continue
        value = patch[name]
        if value is None:
            after.pop(name, None)
        elif name in TABLES:
            if not isinstance(value, dict):
                fail(f"{piece}.{name} should be a table, not {value!r}")
            table = after.get(name) if isinstance(after.get(name), dict) else {}
            for key, inner in value.items():
                if key not in TABLES[name]:
                    notes.append(f"left out {piece}.{name}.{key}: the game doesn't read it")
                elif inner is None:
                    table.pop(key, None)
                else:
                    table[key] = checked(f"{piece}.{name}.{key}", key, inner)
            if table:
                after[name] = table
            else:
                after.pop(name, None)
        else:
            after[name] = checked(f"{piece}.{name}", name, value)
    return after


# ---------------------------------------------------------------- reading Luau, just enough
def skip_string(text, i):
    quote = text[i]
    i += 1
    while i < len(text) and text[i] != quote:
        i += 2 if text[i] == "\\" else 1
    return i + 1


def skip_long(text, i):
    # [[ ... ]] or [==[ ... ]==] starting at i (the first "[")
    m = re.match(r"\[(=*)\[", text[i:])
    if not m:
        return None
    close = "]" + m.group(1) + "]"
    end = text.find(close, i + len(m.group(0)))
    return len(text) if end < 0 else end + len(close)


def skip_comment(text, i):
    # i is at "--"
    if text.startswith("[", i + 2):
        end = skip_long(text, i + 2)
        if end is not None:
            return end
    end = text.find("\n", i)
    return len(text) if end < 0 else end


def matching(text, i):
    """Index just past the "}" that closes the "{" at i."""
    depth = 0
    while i < len(text):
        c = text[i]
        if c in "\"'":
            i = skip_string(text, i)
            continue
        if text.startswith("--", i):
            i = skip_comment(text, i)
            continue
        if c == "[":
            end = skip_long(text, i)
            if end is not None:
                i = end
                continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    fail("unbalanced braces in UiLayout.luau")


def entry_span(text, piece):
    key = re.escape(piece)
    m = re.search(rf'^\t(?:{key}|\["{key}"\])\s*=\s*\{{', text, re.M)
    if not m:
        return None
    open_at = m.end() - 1
    return open_at, matching(text, open_at)


def field_span(text, start, end, name):
    """(line start, value start, value end, line end) of `name = value` directly inside the entry."""
    pattern = re.compile(rf"^(\t\t){name}\s*=\s*", re.M)
    i = start + 1
    while True:
        m = pattern.search(text, i, end)
        if not m:
            return None
        # make sure it's at the entry's own level (not inside a nested table like touch)
        depth = 0
        j = start + 1
        while j < m.start():
            c = text[j]
            if c in "\"'":
                j = skip_string(text, j)
                continue
            if text.startswith("--", j):
                j = skip_comment(text, j)
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            j += 1
        if depth == 0:
            value_start = m.end()
            if text[value_start] == "{":
                value_end = matching(text, value_start)
            elif text[value_start] in "\"'":
                value_end = skip_string(text, value_start)
            else:
                value_end = value_start
                while value_end < end and text[value_end] not in ",\n":
                    value_end += 1
            line_end = text.find("\n", value_end)
            line_end = end if line_end < 0 else line_end + 1
            return m.start(), value_start, value_end, line_end
        i = m.end()


# ---------------------------------------------------------------- writing Luau values
def number(v):
    if float(v).is_integer():
        return str(int(v))
    return f"{v:.4f}".rstrip("0").rstrip(".")


def luau_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def luau_value(key, value):
    if key in COUNTS:
        return "{ " + ", ".join(number(v) for v in value) + " }"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return "{ " + ", ".join(luau_string(v) for v in value) + " }"
    if is_number(value):
        return number(value)
    if isinstance(value, str):
        return luau_string(value)
    if isinstance(value, dict):
        # touch, compact and list: their keys in a steady order, on one line if it's short
        parts = [f"{k} = {luau_value(k, value[k])}" for k in TABLES[key] if k in value]
        one = "{ " + ", ".join(parts) + " }"
        if len(one) <= 96:
            return one
        return "{\n" + "".join(f"\t\t\t{p},\n" for p in parts) + "\t\t}"
    fail(f"can't write {value!r} as Luau")


def set_field(text, piece, name, value):
    """`text` with the entry's `name` set to `value` (None takes it out)."""
    start, end = entry_span(text, piece)
    found = field_span(text, start, end, name)
    if value is None:
        return text[: found[0]] + text[found[3] :] if found else text
    written = luau_value(name, value)
    if found:
        return text[: found[1]] + written + text[found[2] :]
    # Goes after the nearest field before it in ORDER that the entry has, else at the top.
    insert_at = None
    for other in reversed(ORDER[: ORDER.index(name)]):
        spot = field_span(text, start, end, other)
        if spot:
            insert_at = spot[3]
            break
    if insert_at is None:
        insert_at = text.find("\n", start) + 1
    return text[:insert_at] + f"\t\t{name} = {written},\n" + text[insert_at:]


# ---------------------------------------------------------------- comparing
def norm(value):
    # Numbers compare by value (JSON may write 12 as 12.0), to 4 decimal places; nulls and empty
    # tables are the same as not being there.
    if isinstance(value, bool) or value is None:
        return value
    if is_number(value):
        return round(float(value), 4)
    if isinstance(value, list):
        return [norm(v) for v in value] if value else None
    if isinstance(value, dict):
        kept = {k: norm(v) for k, v in sorted(value.items())}
        kept = {k: v for k, v in kept.items() if v is not None}
        return kept or None
    return value


def describe(before, after):
    added = [n for n in FIELDS if n in after and n not in before]
    removed = [n for n in FIELDS if n in before and n not in after]
    changed = [n for n in FIELDS if n in after and n in before and norm(after[n]) != norm(before[n])]
    parts = []
    if changed:
        parts.append("changed " + ", ".join(changed))
    if added:
        parts.append("added " + ", ".join(added))
    if removed:
        parts.append("took out " + ", ".join(removed))
    return "; ".join(parts)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        fail("usage: python3 scripts/apply-hud-layout.py <saved.json> [--dry-run]")
    saved = json.load(open(args[0], encoding="utf-8"))
    elements = elements_of(saved)
    current = read_layout()
    text = open(LAYOUT, encoding="utf-8").read()

    # Work out every piece's new fields first, so a bad value stops it before anything's written.
    plans, skipped, notes = [], [], []
    for piece, patch in elements.items():
        if piece == "__screen" or not isinstance(patch, dict) or piece not in current or not entry_span(text, piece):
            skipped.append(piece)
            continue
        before = {name: current[piece][name] for name in FIELDS if name in current[piece]}
        after = patched(piece, current[piece], patch, notes)
        if any(norm(before.get(name)) != norm(after.get(name)) for name in FIELDS):
            plans.append((piece, before, after))

    for piece, before, after in plans:
        for name in FIELDS:
            if norm(before.get(name)) != norm(after.get(name)):
                text = set_field(text, piece, name, after.get(name))

    for note in notes:
        print(f"Note: {note}")
    if "--dry-run" in sys.argv:
        print(f"Would change {len(plans)}: {', '.join(piece for piece, _, _ in plans) or 'nothing'}")
        for piece, before, after in plans:
            print(f"  {piece}: {describe(before, after)}")
        return
    with open(LAYOUT, "w", encoding="utf-8") as file:
        file.write(text)
    stylua = tool("stylua")
    if stylua:
        subprocess.run([stylua, LAYOUT], cwd=ROOT)

    # Read it back: each changed piece is what was planned, and nothing else moved.
    expected = copy.deepcopy(current)
    for piece, _, after in plans:
        for name in FIELDS:
            expected[piece].pop(name, None)
        expected[piece].update(copy.deepcopy(after))
    got = read_layout()
    wrong = []
    for piece in sorted(set(expected) | set(got)):
        want, have = expected.get(piece, {}), got.get(piece, {})
        for name in sorted(set(want) | set(have)):
            if norm(want.get(name)) != norm(have.get(name)):
                wrong.append(f"{piece}.{name}")
    if wrong:
        fail("these didn't read back as they should: " + ", ".join(wrong))
    print(f"Changed {len(plans)} piece{'s' if len(plans) != 1 else ''}: {', '.join(p for p, _, _ in plans) or 'nothing'}")
    for piece, before, after in plans:
        print(f"  {piece}: {describe(before, after)}")
    if skipped:
        print(f"Skipped (not in UiLayout.luau): {', '.join(skipped)}")


if __name__ == "__main__":
    main()
