#!/usr/bin/env python3
"""Writes a layout saved in the HUD editor into src/client/UiLayout.luau.

    python3 scripts/apply-hud-layout.py <saved.json> [--dry-run]

<saved.json> is what the editor saved: its `layouts/current` document (Claude reads it from the
artifact's database), or what its "Copy layout for Claude" button copied. Only the placement fields
change (anchor, position, size, touch, compact, order and list); labels, notes, comments and
everything else in the file stay as they are. Pieces the file doesn't have are skipped. It prints every piece that moved, runs
stylua on the file, and checks the result reads back as what was saved.
"""

import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = os.path.join(ROOT, "src", "client", "UiLayout.luau")
FIELDS = ("anchor", "position", "size", "touch", "compact", "order", "list")
# The only field the editor can take away: a piece whose phones go back to the shared spot.
REMOVABLE = ("touch",)


def fail(message):
    print(f"apply-hud-layout: {message}", file=sys.stderr)
    sys.exit(1)


def elements_of(saved):
    for key in ("elements", "hudLayout"):
        if isinstance(saved.get(key), dict):
            return saved[key]
    if isinstance(saved.get("data"), dict):
        return elements_of(saved["data"])
    fail("that file has no saved layout in it (expected an `elements` table)")


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
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        fail(f"expected a number, got {v!r}")
    if float(v).is_integer():
        return str(int(v))
    return f"{v:.4f}".rstrip("0").rstrip(".")


def array(values, count):
    if not isinstance(values, list) or len(values) != count:
        fail(f"expected {count} numbers, got {values!r}")
    return "{ " + ", ".join(number(v) for v in values) + " }"


def override_value(values):
    # touch = { ... } and compact = { ... }: any of anchor, position and size
    parts = []
    for key, count in (("anchor", 2), ("position", 4), ("size", 4)):
        if key in values and values[key] is not None:
            parts.append(f"{key} = {array(values[key], count)}")
    one = "{ " + ", ".join(parts) + " }"
    if len(one) <= 96:
        return one
    return "{\n" + "".join(f"\t\t\t{p},\n" for p in parts) + "\t\t}"


def list_value(values):
    parts = []
    for key in ("direction", "padding", "align"):
        if key in values and values[key] is not None:
            value = values[key]
            parts.append(f"{key} = " + (number(value) if isinstance(value, (int, float)) else json.dumps(str(value))))
    return "{ " + ", ".join(parts) + " }"


def value_for(name, placement):
    if name == "anchor":
        return array(placement["anchor"], 2)
    if name in ("position", "size"):
        return array(placement[name], 4)
    if name == "order":
        return number(placement["order"])
    if name == "list":
        return list_value(placement["list"])
    return override_value(placement[name])


def apply_piece(text, piece, placement):
    span = entry_span(text, piece)
    if not span:
        return text, False
    changed = False
    for name in FIELDS:
        start, end = entry_span(text, piece)
        found = field_span(text, start, end, name)
        wanted = placement.get(name)
        if name in ("touch", "compact", "list") and not wanted:
            wanted = None
        if wanted is None:
            if found and name in REMOVABLE:
                text = text[: found[0]] + text[found[3] :]
                changed = True
            continue
        new_value = value_for(name, placement)
        if found:
            if re.sub(r"\s+", "", text[found[1] : found[2]]) != re.sub(r"\s+", "", new_value):
                text = text[: found[1]] + new_value + text[found[2] :]
                changed = True
        else:
            # A new field goes after the last placement field the entry has, else before "}".
            insert_at = None
            for other in FIELDS:
                s, e = entry_span(text, piece)
                f = field_span(text, s, e, other)
                if f:
                    insert_at = f[3]
            if insert_at is None:
                s, e = entry_span(text, piece)
                insert_at = text.rfind("\n", s, e - 1) + 1
            text = text[:insert_at] + f"\t\t{name} = {new_value},\n" + text[insert_at:]
            changed = True
    return text, changed


def norm(value):
    # Numbers compare by value (JSON may write 12 as 12.0), to 4 decimal places.
    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, (int, float)):
        return round(float(value), 4)
    if isinstance(value, list):
        return [norm(v) for v in value]
    if isinstance(value, dict):
        return {k: norm(v) for k, v in sorted(value.items()) if v is not None}
    return value


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        fail("usage: python3 scripts/apply-hud-layout.py <saved.json> [--dry-run]")
    saved = json.load(open(args[0], encoding="utf-8"))
    elements = elements_of(saved)
    text = open(LAYOUT, encoding="utf-8").read()
    moved, skipped = [], []
    for piece, placement in elements.items():
        if not isinstance(placement, dict):
            skipped.append(piece)
            continue
        text, changed = apply_piece(text, piece, placement)
        if changed:
            moved.append(piece)
        elif not entry_span(text, piece):
            skipped.append(piece)
    if "--dry-run" in sys.argv:
        print(f"Would move {len(moved)}: {', '.join(moved) or 'nothing'}")
        return
    with open(LAYOUT, "w", encoding="utf-8") as file:
        file.write(text)
    stylua = shutil.which("stylua") or os.path.expanduser("~/.rokit/bin/stylua" + (".exe" if os.name == "nt" else ""))
    if os.path.exists(stylua) or shutil.which("stylua"):
        subprocess.run([stylua, LAYOUT], cwd=ROOT)
    # Read it back and make sure every saved value landed.
    result = subprocess.run(["lune", "run", "scripts/ui-layout-json"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        fail("UiLayout.luau no longer reads back:\n" + result.stderr.strip())
    after = json.loads(result.stdout)
    wrong = []
    for piece in moved:
        for name in FIELDS:
            saved_value = elements[piece].get(name)
            if saved_value is None and name not in REMOVABLE:
                continue
            want = norm(saved_value or None)
            got = norm(after.get(piece, {}).get(name) or None)
            if want != got:
                wrong.append(f"{piece}.{name}")
    if wrong:
        fail("these didn't read back as saved: " + ", ".join(wrong))
    print(f"Moved {len(moved)} piece{'s' if len(moved) != 1 else ''}: {', '.join(moved) or 'nothing'}")
    if skipped:
        print(f"Skipped (not in UiLayout.luau): {', '.join(skipped)}")


if __name__ == "__main__":
    main()
