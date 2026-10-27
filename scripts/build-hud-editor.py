#!/usr/bin/env python3
"""Builds the HUD editor page (tools/hud-editor) from the game's own layout.

    python3 scripts/build-hud-editor.py [out.html]

Reads src/client/UiLayout.luau as JSON (`lune run scripts/ui-layout-json`) and fills it into
tools/hud-editor/editor.template.html, along with the file's header comment and the order its
pieces are listed in. The result is the page published as the HUD editor artifact: the owner drags
the pieces around and saves, and scripts/apply-hud-layout.py writes what they saved back into
UiLayout.luau. Rebuild and republish it whenever UiLayout.luau gains or loses a piece.
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, "tools", "hud-editor", "editor.template.html")
LAYOUT = os.path.join(ROOT, "src", "client", "UiLayout.luau")
DEFAULT_OUT = os.path.join(ROOT, "tools", "hud-editor", "hud-editor.html")


def fail(message):
    print(f"build-hud-editor: {message}", file=sys.stderr)
    sys.exit(1)


def layout_json():
    result = subprocess.run(["lune", "run", "scripts/ui-layout-json"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        fail("lune run scripts/ui-layout-json failed:\n" + result.stderr.strip())
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        fail(f"scripts/ui-layout-json didn't print JSON ({error})")


def header_of(source):
    # The comment block at the top of the file, up to the first line that isn't a comment.
    lines = []
    for line in source.splitlines():
        if line.startswith("--") or (lines and line.strip() == ""):
            lines.append(line)
        else:
            break
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def order_of(source, ids):
    # The pieces in the order the file lists them (JSON objects don't keep it).
    found = re.findall(r'^\t(?:([A-Za-z_][A-Za-z0-9_]*)|\["([^"]+)"\])\s*=\s*\{', source, re.M)
    order = [a or b for a, b in found]
    return [i for i in order if i in ids] + [i for i in ids if i not in order]


def git_head():
    result = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    return result.stdout.strip() or None


def for_script(value):
    # JSON inside <script type="application/json">: "</" must not end the tag early.
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    data = layout_json()
    screen = data.pop("__screen", None) or {}
    source = open(LAYOUT, encoding="utf-8").read()
    meta = {
        # Roblox's top bar is 58 px tall today (GuiService:GetGuiInset()).
        "topbar": screen.get("topbar", 58),
        "screen": screen,
        "header": header_of(source),
        "order": order_of(source, list(data)),
        "version": git_head(),
    }
    template = open(TEMPLATE, encoding="utf-8").read()
    if "__DEFAULTS__" not in template or "__META__" not in template:
        fail("the template is missing its __DEFAULTS__ or __META__ slot")
    html = template.replace("__DEFAULTS__", for_script(data)).replace("__META__", for_script(meta))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as file:
        file.write(html)
    print(f"Wrote {os.path.relpath(out, ROOT)}: {len(data)} pieces, layout from {meta['version']}.")


if __name__ == "__main__":
    main()
