#!/usr/bin/env python3
"""Draws the grass tuft sheet: eight little clumps of blades on a clear background.

    python scripts/make-grass-tufts.py [OUT.png] [--check]

Writes art-source/Grass/Grass_Tufts.png (or OUT.png), 256 x 256 RGBA: a 4 x 2 grid of 64 px cells
along the top, one tuft in each, standing on the bottom edge of its cell. The lower half of the
sheet is left clear, so the file is square. A tuft is 5 to 9 tapered blades fanned out from one
base, in two greens. It is seeded, so the same script always draws the same sheet.

--check draws the sheet into a temporary file and tests it instead: the size and mode, that every
cell holds a tuft with some solid pixels and clear corners, that every tuft has 5 to 9 blades, that
only greens were used, that nothing is drawn below the grid, and that drawing it twice gives the
same bytes. Exits with an error if
anything's off. Upload the sheet with scripts/upload-grass-art.py.
"""

import math
import os
import random
import sys
import tempfile

from PIL import Image, ImageDraw

COLUMNS = 4
ROWS = 2
CELL = 64
SIZE = 256  # the sheet is square; the grid fills its top half
SEED = 20261028
SUPERSAMPLE = 4  # each cell is drawn this many times bigger, then shrunk, for smooth edges
DARK = (58, 112, 40)
LIGHT = (98, 160, 60)
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art-source", "Grass", "Grass_Tufts.png")


def blade_outline(base_x, base_y, tip_x, tip_y, bend, width):
    """The polygon of one blade: a curve from its base to its tip, wide at the base and tapering to a point."""
    # A quadratic curve whose middle is pushed sideways by `bend`, so the blade arcs rather than leans.
    control_x = (base_x + tip_x) / 2 + bend
    control_y = (base_y + tip_y) / 2
    left, right = [], []
    steps = 14
    for step in range(steps + 1):
        t = step / steps
        x = (1 - t) ** 2 * base_x + 2 * (1 - t) * t * control_x + t**2 * tip_x
        y = (1 - t) ** 2 * base_y + 2 * (1 - t) * t * control_y + t**2 * tip_y
        # The curve's direction, turned a quarter to find which way is sideways.
        dx = 2 * (1 - t) * (control_x - base_x) + 2 * t * (tip_x - control_x)
        dy = 2 * (1 - t) * (control_y - base_y) + 2 * t * (tip_y - control_y)
        length = math.hypot(dx, dy) or 1
        half = width * (1 - t) ** 0.85 / 2
        left.append((x - dy / length * half, y + dx / length * half))
        right.append((x + dy / length * half, y - dx / length * half))
    return left + right[::-1]


def draw_tuft(rng):
    """One tuft on a cell of its own. Returns the cell and its blade count."""
    count = rng.randint(5, 9)
    # Both greens in every tuft: alternate them across the blades, then shuffle which blade gets which.
    colors = [DARK if index % 2 == 0 else LIGHT for index in range(count)]
    rng.shuffle(colors)
    blades = []
    for index in range(count):
        # Fan the blades across the tuft, spread evenly with a little jitter; the middle ones stand tallest.
        spread = -1 + 2 * index / (count - 1)
        angle = math.radians(32 * spread + rng.uniform(-5, 5))
        height = rng.uniform(30, 52) * (1 - 0.3 * abs(spread))
        base_x = CELL / 2 + rng.uniform(-2.5, 2.5)
        base_y = CELL - 1.5
        tip_x = min(max(base_x + math.sin(angle) * height, 4), CELL - 4)
        tip_y = base_y - math.cos(angle) * height
        bend = rng.uniform(-0.18, 0.18) * height + math.sin(angle) * height * 0.12
        width = rng.uniform(4.0, 6.5)
        blades.append((colors[index], base_x, base_y, tip_x, tip_y, bend, width))
    # Drawn big and shrunk so the edges are soft. The color and the alpha are shrunk apart: shrinking
    # RGBA in one go leaves wrong colors where it is nearly clear. Clear pixels keep the dark green.
    big = CELL * SUPERSAMPLE
    color_layer = Image.new("RGB", (big, big), DARK)
    alpha_layer = Image.new("L", (big, big), 0)
    color_draw = ImageDraw.Draw(color_layer)
    alpha_draw = ImageDraw.Draw(alpha_layer)
    # The dark blades go down first so the light ones stand in front of them.
    blades.sort(key=lambda blade: blade[0] == LIGHT)
    for color, base_x, base_y, tip_x, tip_y, bend, width in blades:
        outline = blade_outline(base_x, base_y, tip_x, tip_y, bend, width)
        points = [(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in outline]
        color_draw.polygon(points, fill=color)
        alpha_draw.polygon(points, fill=255)
    cell = color_layer.resize((CELL, CELL), Image.BOX).convert("RGBA")
    cell.putalpha(alpha_layer.resize((CELL, CELL), Image.BOX))
    return cell, count


def build_sheet(seed=SEED):
    """Returns the sheet and how many blades each of its tufts has."""
    rng = random.Random(seed)
    sheet = Image.new("RGBA", (SIZE, SIZE), DARK + (0,))
    counts = []
    for index in range(COLUMNS * ROWS):
        cell, count = draw_tuft(rng)
        sheet.paste(cell, (index % COLUMNS * CELL, index // COLUMNS * CELL))
        counts.append(count)
    return sheet, counts


def check():
    failures = []

    def expect(ok, message):
        if not ok:
            failures.append(message)

    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "Grass_Tufts.png")
        sheet, counts = build_sheet()
        sheet.save(path)
        again, _ = build_sheet()
        again_path = os.path.join(folder, "again.png")
        again.save(again_path)
        with open(path, "rb") as first, open(again_path, "rb") as second:
            expect(first.read() == second.read(), "drawing the sheet twice gave different files")
        image = Image.open(path)
        image.load()

    expect(image.size == (SIZE, SIZE), f"sheet is {image.size}, not 256 x 256")
    expect(image.mode == "RGBA", f"sheet is {image.mode}, not RGBA")
    expect(len(counts) == COLUMNS * ROWS, f"{len(counts)} tufts, not {COLUMNS * ROWS}")
    for number, count in enumerate(counts):
        expect(5 <= count <= 9, f"tuft {number} has {count} blades, not 5 to 9")

    pixels = image.load()
    for row in range(ROWS):
        for column in range(COLUMNS):
            name = f"cell {column},{row}"
            left, top = column * CELL, row * CELL
            solid = 0
            cell_seen = set()
            for y in range(top, top + CELL):
                for x in range(left, left + CELL):
                    r, g, b, a = pixels[x, y]
                    if a == 255:
                        solid += 1
                        cell_seen.add((r, g, b))
                    if a > 0:
                        expect(g > r and g > b, f"{name}: pixel {x},{y} isn't green")
            expect(solid >= 100, f"{name}: only {solid} solid pixels")
            expect(DARK in cell_seen and LIGHT in cell_seen, f"{name}: doesn't show both greens")
            for x, y in ((left, top), (left + CELL - 1, top), (left, top + CELL - 1), (left + CELL - 1, top + CELL - 1)):
                expect(pixels[x, y][3] == 0, f"{name}: corner {x},{y} isn't clear")

    below = sum(1 for y in range(ROWS * CELL, SIZE) for x in range(SIZE) if pixels[x, y][3] > 0)
    expect(below == 0, f"{below} pixels below the grid aren't clear")

    if failures:
        for failure in failures:
            print("FAIL  " + failure)
        sys.exit(1)
    print("make-grass-tufts: ok")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--check" in sys.argv:
        check()
        return
    out = args[0] if args else DEFAULT_OUT
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet, counts = build_sheet()
    sheet.save(out)
    print(f"wrote {os.path.normpath(out)} ({len(counts)} tufts, {sum(counts)} blades)")


if __name__ == "__main__":
    main()
