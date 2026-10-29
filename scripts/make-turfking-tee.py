#!/usr/bin/env python3
"""Draws the TurfKing T-shirt graphic: a gold crown over the word TURFKING, on purple.

    python scripts/make-turfking-tee.py [OUT.png] [--check]

Writes art-source/Cast/TurfKing_Tee.png (or OUT.png), 512 x 512 RGBA, the whole square purple. Chad
and Sam_TurfKing wear it over their shirts (src/shared/Config/Cast.luau, `tshirt`). Open Cloud
can't upload a T-shirt graphic as a T-shirt, so it is made on the Create page by hand; see "Before
release" in TODO.md.

--check draws the image into a temporary file and tests it instead: the size and mode, a purple
field with a clear margin around the art, and gold in the crown's band and in the lettering's.
Exits with an error if anything's off.
"""

import os
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

SIZE = 512
SUPERSAMPLE = 4  # drawn this many times bigger, then shrunk, for smooth edges
PURPLE = (88, 52, 150, 255)
GOLD = (230, 185, 60, 255)
DARK_GOLD = (170, 130, 30, 255)
# Rows the art sits in: the crown above, the lettering under it, and purple above and below both.
CROWN_BAND = (90, 310)
TEXT_BAND = (320, 430)
# Bold fonts to letter with, the first one that exists. Pillow's own font is the last resort.
FONTS = (
    "C:/Windows/Fonts/segoeuib.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "/Library/Fonts/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
)
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art-source", "Cast", "TurfKing_Tee.png")


def find_font(size):
    for path in FONTS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def draw_tee():
    k = SUPERSAMPLE
    image = Image.new("RGBA", (SIZE * k, SIZE * k), PURPLE)
    draw = ImageDraw.Draw(image)

    def big(points):
        return [(x * k, y * k) for x, y in points]

    # The crown: a body with three points, a dark band across its foot with three gems in it, and a
    # ball on each point. It is centred, in the upper half.
    cx, top, bottom, half = SIZE // 2, 124, 300, 150
    body = [
        (cx - half, bottom),
        (cx - half, top + 60),
        (cx - half // 2, top + 110),
        (cx, top),
        (cx + half // 2, top + 110),
        (cx + half, top + 60),
        (cx + half, bottom),
    ]
    draw.polygon(big(body), fill=GOLD, outline=DARK_GOLD, width=6 * k)
    draw.rectangle([(cx - half) * k, (bottom - 36) * k, (cx + half) * k, bottom * k], fill=DARK_GOLD)
    for x in (cx - half + 24, cx, cx + half - 24):
        draw.ellipse([(x - 16) * k, (bottom - 34) * k, (x + 16) * k, (bottom - 2) * k], fill=PURPLE)
    for x, y in ((cx - half, top + 60), (cx, top), (cx + half, top + 60)):
        draw.ellipse([(x - 14) * k, (y - 14) * k, (x + 14) * k, (y + 14) * k], fill=GOLD, outline=DARK_GOLD, width=4 * k)

    # The lettering, centred under the crown, as big as will fit.
    text = "TURFKING"
    size = 72
    while True:
        font = find_font(size * k)
        left, up, right, down = draw.textbbox((0, 0), text, font=font)
        if right - left <= 440 * k or size <= 20:
            break
        size -= 4
    x = (SIZE * k - (right - left)) / 2 - left
    y = ((TEXT_BAND[0] + 25) * k) - up
    draw.text((x, y), text, fill=GOLD, font=font)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def near_gold(pixel):
    return all(abs(pixel[channel] - GOLD[channel]) <= 40 for channel in range(3))


def check():
    failures = []

    def expect(ok, message):
        if not ok:
            failures.append(message)

    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "TurfKing_Tee.png")
        draw_tee().save(path)
        image = Image.open(path)
        image.load()

    expect(image.size == (SIZE, SIZE), f"image is {image.size}, not 512 x 512")
    expect(image.mode == "RGBA", f"image is {image.mode}, not RGBA")
    pixels = image.load()
    for x, y in ((0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1), (SIZE // 2, 4), (SIZE // 2, SIZE - 5)):
        expect(pixels[x, y] == PURPLE, f"pixel {x},{y} isn't the purple field")

    def gold_in(top, bottom):
        return sum(1 for y in range(top, bottom) for x in range(SIZE) if near_gold(pixels[x, y]))

    expect(gold_in(*CROWN_BAND) >= 4000, f"only {gold_in(*CROWN_BAND)} gold pixels in the crown band")
    expect(gold_in(*TEXT_BAND) >= 1500, f"only {gold_in(*TEXT_BAND)} gold pixels in the text band")
    expect(gold_in(0, CROWN_BAND[0]) == 0, "gold above the crown")
    expect(gold_in(TEXT_BAND[1], SIZE) == 0, "gold below the lettering")

    if failures:
        for failure in failures:
            print("FAIL  " + failure)
        sys.exit(1)
    print("make-turfking-tee: ok")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--check" in sys.argv:
        check()
        return
    out = args[0] if args else DEFAULT_OUT
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    draw_tee().save(out)
    print(f"wrote {os.path.normpath(out)}")


if __name__ == "__main__":
    main()
