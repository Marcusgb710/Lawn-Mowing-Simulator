# Instructions 35: Title card art

When a player joins, the game now shows a **title card** while the world loads, their save is read
and their business is built: the logo, key art behind it, and a loading bar along the bottom
that fills with mown stripes while a little push mower rolls along it. Then it says "Tap to start"
and fades out on the player standing at their shop. The card works today with drawn
placeholders; this file is the real art for it.

## What this is

These are **2D images**, not models. Make them look like the game: realistic, warm and clean,
like the high-poly models you made in instructions 24–34. The best way to get that is to **render
the key art in Blender from those models** (the buildings, trucks, mowers and yard props in
`model-source/HighPoly/`), not to paint it from scratch. Players should recognize the shed,
the pickup and the mower when they walk out into the game.

## What to deliver

Everything in **`art-source/TitleCard/`**:

| File | Size (px) | What it is |
| --- | --- | --- |
| `Logo.png` | 1024 × 512 | The logo, on a transparent background |
| `Background_Master.png` | 2048 × 1152 | The key art (16:9), full size |
| `Background_TL.png`, `Background_TR.png`, `Background_BL.png`, `Background_BR.png` | 1024 × 576 each | The key art cut into four equal tiles, top-left, top-right, bottom-left, bottom-right, with no overlap and no gap |
| `Mower.png` | 512 × 512 | A push mower from the side, on a transparent background |
| `Stripes.png` | 256 × 64 | A seamless tile of mown lawn stripes |
| `Previews/TitleCard_16x9.png` | 1920 × 1080 | Mock-up: everything put together, as on a PC |
| `Previews/TitleCard_Phone.png` | 2340 × 1080 | Mock-up: the same on a wide phone |
| `Previews/TitleCard_Tablet.png` | 2048 × 1536 | Mock-up: the same on a 4:3 tablet |
| `manifest.json` | | Every file with its size and what it's for, the safe zones below, and the logo's visual centre in pixels |
| `Source/` | | The Blender files and logo source, so the art can be changed later |

Don't change `assets/`, `src/`, `model-source/` or anything outside `art-source/TitleCard/`.
The local Claude session uploads the PNGs to Roblox as Big Dink Studios and puts their ids in
`src/first/TitleCardArt.luau`.

**Roblox shrinks any image bigger than 1024 px on its longest side**, which is why every final
image here is at most 1024 px and the background comes as four tiles. The game lays the tiles
back together as one 2048 × 1152 picture.

## How the card is laid out

The background fills the whole screen and is **cropped** to fit, so different screens see
different parts of it:

- **PC (16:9)** sees all of it.
- **Wide phones (19.5:9)** lose the top and bottom: only the middle **2048 × 945** shows.
- **Tablets (4:3)** lose the sides: only the middle **1536 × 1152** shows.

So keep everything that matters inside the **middle 1536 × 945** of the background.

On top of the background:

- The **logo** sits in the upper middle: centred, its top about 10% down the screen, about 62% of
  the screen wide at most.
- The **loading bar** sits low in the middle: centred, about 90% down, half the screen wide. The
  "Tap to start" prompt appears in the same place.

So **keep the upper-middle and lower-middle of the background calm**: sky or soft, out-of-focus
areas where the logo and bar stay readable. Put the interesting things (the shop, the truck, the
mower) on the left and right thirds and in the middle band between them.

## The pieces

### `Logo.png`

- The words **"Lawn Mowing Simulator"**, spelled exactly like that, as the game's wordmark. Put
  "LAWN MOWING" big on top and "SIMULATOR" smaller underneath, or another layout that reads at a
  glance.
- Use the **Fredoka** typeface (SIL Open Font License, free to use). The game's whole UI uses
  Fredoka One, so the logo should match it. Bold, friendly, rounded.
- Make the letters white or cream, with a **thick dark-green outline** and a soft drop shadow, so
  the logo reads on bright sky and dark grass alike.
- Add a small mark that says "lawn care": a push mower, a row of grass blades, or the letters
  sitting on a strip of mown stripes. Keep it simple and in the same style.
- Transparent background. Trim to the logo with about 24 px of padding, centred in the
  1024 × 512 canvas.
- It must still read when shown **300 px wide** on a phone. Check by scaling it down.

### The key art (`Background_*.png`)

A render of a **player's lawn-care business on a sunny morning**:

- The **wooden `Shed`** from `24_YardAndBuildings`, door open, with the pegboard and tools inside
  just visible.
- The **`RustyPickup`** from `25_TrucksAndTrailers`, backed up on the driveway with its tailgate
  down and a mower in the bed.
- A front lawn **half mown**: crisp light and dark stripes on the mown half, the rest still long.
  The **`SelfPropelledMower`** from `26_MowersAndRideOns` stands at the edge of the last stripe,
  as if someone just stepped away.
- A few yard props from `34_YardDecorations` (a mailbox, a picket fence, a flower bed) and a
  little suburban street behind: other houses soft in the distance.
- **Golden-hour light**: low warm sun, long soft shadows, a clear blue sky fading warm near the
  horizon. Slight depth of field, so the middle ground is sharp and the far houses soft.
- **No people, no text, no logos, no brand names.** The game's logo goes on top.
- Camera at about head height, a little above the lawn, looking up the driveway at the shed:
  the view a player gets walking up to their shop.

Render it at 2048 × 1152 as `Background_Master.png`, then cut that exact image into the four
1024 × 576 tiles.

### `Mower.png`

The same `SelfPropelledMower` as in the key art, seen **exactly from the side**, facing right, with no
perspective (an orthographic render). Make it clean and simple, readable at **34 px tall**, which is
how big it shows on the loading bar. Transparent background, mower centred and standing on the
bottom edge of the canvas with about 16 px of padding.

### `Stripes.png`

A 256 × 64 tile of freshly mown lawn: two stripes, light and dark green, each 128 px wide, with
fine grass texture. It must **tile seamlessly left to right**. The game repeats it at 64 × 16 px
to fill the loading bar, so keep the detail soft.

## Done when

- [ ] Every file in the table is in `art-source/TitleCard/` at exactly its size, PNG, and the
      four background tiles put together match `Background_Master.png` pixel for pixel.
- [ ] Nothing important in the background is outside the middle 1536 × 945, and the
      upper-middle (logo) and lower-middle (bar) areas are calm.
- [ ] The logo spells "Lawn Mowing Simulator" correctly, uses Fredoka, and reads at 300 px wide.
- [ ] The three mock-ups show the logo, key art and loading bar together on PC, a wide phone and
      a tablet, and nothing important is cut off on any of them.
- [ ] The key art uses the game's own models, has no people, text or logos, and has the
      half-mown lawn, the shed with its door open and the truck with its tailgate down.
- [ ] `manifest.json` lists every file with its size and purpose, the safe zones and the logo
      centre.
- [ ] Nothing outside `art-source/TitleCard/` changed.
