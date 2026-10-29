# Fluid mowing: the lawn as a surface you carve

Design, 2026-10-28. Owner: Avery. Status: draft for approval.

## Why

Mowing is the whole game, and today it's a grid: the lawn is 4-stud tiles, each one a grass clump
that sinks when the mower touches it, and the mown look comes from a striped plate under each tile.
Avery's words: "it's just mowing a grid with grass models that get smaller". The target is the feel of
PowerWash Simulator: a surface you clean, where the tool leaves exactly its own footprint behind it, a
counter climbs, the last few percent are a hunt for what you missed, and finishing lands.

Mowing a real lawn has the same shape. You push through tall grass, a clean strip opens behind the
deck with a crisp edge against the uncut grass next to it, clippings fly out the chute, the engine
bogs in the thick stuff and climbs again on the cut strip, and the stripes you leave show how you
drove.

## Goals

- **No grid.** The cut is per pixel, exactly the width of the deck, with a crisp edge. Mow in a curve
  and you get a curve.
- **Stripes from your route.** Light when you mow away from the street, dark coming back, so a tidy
  back-and-forth makes real stripes and a scribble looks like a scribble.
- **Feedback while cutting:** clippings only while the blade is in tall grass, an engine note that dips
  under load, a little more push and shake in thick grass.
- **A counter and a hunt.** The HUD shows the percent mowed. From 90% you can light up what you
  missed. The last strip gets a chime and a stamp.
- **Phones keep up.** Same draw distance rules as today; a mid-size job lawn must not cost more than the
  current clumps do on a low-end phone.
- **Nothing else breaks.** Shears, dull blades, junk hidden in the grass, flower patches, do-not-mow
  strips, trimming around obstacles, the home lawn growing back, pay and finish quality all keep
  working.

## Non-goals

- Grass physics, bending blades, wind. The shells are flat art.
- Scoring the stripe pattern. Stripes are cosmetic in this round; "pro finish" pay for straight passes
  is a later idea.
- New mowers, prices, or balance changes. Deck widths come from the existing `radius` stats.
- Baggers, mulching, clipping piles. Clippings are particles that vanish.
- Replacing the models. That's its own project.

## Anti-goals (what would make this a failure even if it works)

- A faint grid showing through: visible tile seams, stripes snapping to columns, cuts that look
  quantized to studs. If it reads as cells, it failed.
- Mowing that feels floaty: a swath that lags behind the deck, or appears in chunks.
- A big lawn that stutters on a phone, or fails to draw at all with no fallback.
- Losing a job's progress because the picture and the pay disagree.

## Constraints

- **Engine.** Roblox `EditableImage` is the per-pixel tool. Facts that shape the design (from the
  engine docs, checked 2026-10-28):
  - Max 1024×1024 pixels; fixed size once created; `Content.fromObject(image)` puts one on a `Decal`,
    `Texture`, `MeshPart.TextureContent` or `ImageLabel`, and one image can feed many of them.
  - Drawing: `DrawRectangle` (axis-aligned), `DrawCircle`, `DrawLine`, `DrawImage`, and
    `DrawImageTransformed(position, scale, rotation, image, options)` for a rotated stamp, with
    `Enum.ImageCombineType.Overwrite` to write transparent pixels.
  - It fails by default in a published game. The owner must turn on **Allow Mesh / Image APIs** in
    Experience Settings → Security (or Configure → Settings on the Creator Dashboard) and review
    Roblox's terms first. Studio and the server have no memory limit; clients have a strict,
    device-specific budget, and creation throws when it's spent.
  - Blank images need no asset permissions. Images loaded from assets must be owned by the group.
- **Lawns.** Job lawns are 6×5 to 9×7 tiles (24×20 to 36×28 studs) with two big ones at 22×16 and
  28×22 tiles (112×88 studs). Home lawns are similar. The draw distance is 200 studs.
- **Mowers.** `radius` is 2.5 (reel) to 10 studs (commercial zero-turn); the deck is twice that.
  `walkSpeed` 12 to 36. `WorkTickRate` ticks drive the work.
- **Existing systems** that touch the grass: `LawnGrid` (shared), `GrassController` (client draw),
  `LawnService` (targets, work, debris, flower patches, DoNotMow), `ToolService` (work tick, WorkFx,
  WalkSpeed), `HomeLawnService` (regrowth), `MaintenanceService` (dull blades → ragged),
  `CameraController` (bob and engine shake), `Sounds` (all ids empty today), the HUD task list and
  the HUD layout editor.
- **Workflow.** Branch, PR, `selene`, `stylua`, `rojo build`; Studio play-tests; publish with
  `scripts/publish.py`.

## The design

### 1. The lawn is three things

For each lawn (job site or home lawn) the client builds, inside the lawn's footprint:

1. **A turf plate.** One flat part the size of the mowable area, with a `Decal` on its top face whose
   content is an `EditableImage` (the *turf image*). Uncut, it's the mown-grass green. Every swath
   paints its stripe shade into it, plus faint wheel tracks.
2. **Grass shells.** `N` thin parts stacked above the plate between 0 and the tall-grass height,
   each with a `Decal` whose content is its own `EditableImage` (a *shell image*). Each shell image
   starts as a field of blade dots that thins out toward the top shell, so from the side the stack
   reads as standing grass and from above as dense turf. Uncut areas are opaque, mowed areas are
   transparent. `N` is 6 on desktop and console, 4 on phones; the builder tunes these and may go to 3
   on low-memory devices, never below 2. The dot pattern comes from one procedurally generated
   *blade template* image drawn into each shell with `DrawImage`, so no art assets are needed.
3. **Nothing per tile.** The kit clumps, the striped plates and `LawnGrid.PARTLY_CUT` go.

Resolution: 4 pixels per stud. A 36×28 stud lawn is 144×112 pixels; the biggest lawn is 448×352.
Nothing exceeds 1024. Per lawn that's `N + 1` images, under 5 MB for the biggest lawn on desktop and
about 3 MB on a phone. Lawns outside the draw distance are destroyed (images included), exactly as
clumps are today.

**Edges.** The mowable area is the lawn's grass rectangle minus the cells that aren't grass (flower
patches, DoNotMow strips, obstacle rings, the overgrown edge strip). Those are stamped transparent in
every shell at build time and painted in the turf image with the ground color, so the first cut
already meets them cleanly.

### 2. Cutting is a sweep, decided by the server

The server stays the authority on what's cut, for pay and progress.

- **The ledger.** `LawnGrid` keeps its string-of-cells shape, but a cell is **1 stud**, not 4. States
  stay: tall `0`, mowed `1`, ragged `2`, not grass `-`. The quarters (`3`, `4`, `5`) are removed. The
  server keeps the string per lawn; it is what pay, finish quality, progress and junk positions are
  counted from.
- **The sweep.** Each work tick, for each working mower on a lawn, the server takes the deck's center
  now and last tick and sweeps the deck rectangle (width `2 × radius`, oriented along the movement)
  between them. Every tall cell whose center the sweep covers becomes mowed (or ragged, with a dull
  blade). A mower standing still cuts the cells under its deck once. `power` no longer meters mowing;
  deck width and `walkSpeed` already make bigger mowers faster. `power` still meters every other
  task.
- **The swath log.** Each sweep that changed at least one cell is appended to the lawn's swath log as
  `{ fromX, fromZ, toX, toZ, width, shade, ragged }` in lawn-local studs. Consecutive collinear
  sweeps with the same shade and raggedness merge into one segment, so a straight pass is one entry
  and a job's log stays in the low hundreds.
- **Shade.** From the direction of travel against the lawn's "away" axis (its local +Z, pointing from
  the street into the yard): `Light` when moving away, `Dark` coming back, `Flat` across. Ragged cuts
  get their own shade.
- **Broadcast.** The picture is driven by a `Swath` remote event carrying the new or extended
  segment, fired to the players within draw distance. A client that starts drawing a lawn (join, or
  walking into range) asks for the whole log once with a remote function and replays it. The ledger
  itself is **not** replicated every tick: at 1-stud cells the big lawn's string is 16× today's, and
  sending it each tick would cost phones more bandwidth than the game can spare. Progress reaches
  the HUD through the task update it already gets (cells cut over mowable cells); the fallback
  renderer gets the ledger with the log, once, and then follows the same `Swath` events.
- **Your own mower doesn't wait for the server.** Work ticks are coarser than frames, so a swath
  that only appeared on each tick would show up in chunks behind the deck, which is the floaty feel
  this design exists to avoid. The local client paints its own mower's sweep every frame, from the
  deck's position on screen, into its own images. The server's swaths for that mower land on the same
  pixels and are drawn too; where they disagree (a dull blade the client didn't know about, a cell
  the server refused) the server's version wins because it's drawn last. Other players' mowers are
  painted from server swaths only.
- **Where the deck is.** The sweep uses the work position `ToolService` already computes (the
  character's root plus `REACH_OFFSET` ahead, or the ride-on's `RideRoot`), so the cut lands where
  the game already thinks the blade is. `maxGrassHeight` still gates which mowers can sweep a
  tall-grass job at all.
- **Shears and other cutters.** A snip is a small circular brush (radius 1 stud) at the snip point;
  it goes through the same path: cells, log entry with `width = 0` and a `radius`, broadcast. Edgers
  and trimmers keep their own targets; they don't touch the lawn surface.
- **Junk in the grass** keeps its cell index, now at 1-stud resolution, with the same rules (a push
  mower stops, a motorized one chews it up).

### 3. The client paints the swath

On `Swath`, the client draws the segment into the lawn's images:

- A **brush** is a small `EditableImage` (16×16, white, fully opaque) kept once per client. The
  segment becomes `DrawImageTransformed` calls: pivot at the segment's center, scale `(length,
  width)` in pixels divided by 16, rotation from the segment's direction.
- Into the **turf image** with the shade color (`Overwrite`): `Light`, `Dark` and `Flat` are three
  greens close enough to read as one lawn; ragged is a duller yellow-green. Two thin `DrawLine`s
  along the segment's edges, slightly darker, are the wheel tracks.
- Into **each shell image** with a transparent color (`Overwrite`), so the grass above disappears
  in that exact shape. Ragged cuts use a second brush with holes in it, so tufts stay standing.
- **Snips** use `DrawCircle` instead.

Draw cost per tick per mower: `N + 3` small draws. Fine.

**Growing back** (home lawn): when the server marks cells tall again, it sends a `Regrow` event with
the cells' bounding rectangles; the client re-stamps those areas from the blade template into each
shell (`DrawImage` clipped to the rectangle) and repaints the turf there. It pops back in patches,
which is acceptable: regrowth happens while you're away on jobs, and the server already only regrows
a little at a time.

**Fallback.** If the Mesh / Image API toggle is off or `CreateEditableImage` throws for budget, the
client falls back to a coarse renderer that draws the `Cells` ledger as flat 2-stud squares on one
plate (no shells, no stripes), logs a warning once, and keeps the game playable. It's a safety net,
not a mode to tune.

### 4. Feedback

- **Clippings.** The existing `WorkFx` emitter moves to the deck's discharge side (the right side,
  halfway along the deck; reel mowers discharge behind). It runs only while the tool's `Cutting`
  attribute is true, which the server sets when the tick's sweep changed at least one cell, and
  clears when it didn't. Particles are light green flecks, 0.3 to 0.6 s, fired sideways and down.
- **Engine.** Motorized mowers carry two looping `Sound`s on the handle: `EngineIdle` and
  `EngineLoad`. The client crossfades toward `EngineLoad` and drops pitch about 15% while `Cutting`,
  and nudges pitch up with `MoveDirection`. Equipping a motorized mower plays `PullStart` once. The
  reel mower plays a `ReelWhirr` loop while moving. Ids go in `Sounds.Ids`, sourced from the Creator
  Store's free library first and generated only if nothing fits; uploads are owned by the group.
- **Push and shake.** While `Cutting`, `WalkSpeed` is scaled by 0.85 and `CameraController`'s engine
  shake by 1.5. Both snap back when the cut strip is reached.
- **The counter.** The HUD's mowing task shows a percent (cut cells over mowable cells) instead of
  tiles done. It's a HUD piece like any other, so the layout editor can place it.
- **Show what I missed.** From 90%, a HUD button (and a key on PC) tints the remaining tall grass red
  for 3 seconds by setting the shells' `Decal.Color3`, with a soft pulse, then restores it.
- **Done.** The mowing task completes at 99% of mowable cells. On completion: a chime (`LawnDone`), the
  GUI art's stamp on the task, and the existing job flow continues. The last 1% exists so a cell
  half under a hedge never blocks a job.

### 5. Ragged cuts, quality and pay

- A dull blade (`MaintenanceService` → `ragged`) marks cells `2` and paints with the holed brush and
  the ragged shade. Finish quality counts ragged cells exactly as ragged tiles count today, scaled to
  cells.
- Pay for mowing is per cell cut, scaled so a lawn pays what it pays today (`fitWork` per cell equals
  the old per-tile amount divided by 16).

### 6. What has to happen outside the code

- Avery turns on **Allow Mesh / Image APIs** for the experience (Studio: Experience Settings →
  Security) after reviewing Roblox's terms. Without it the game runs on the fallback renderer.
- Sound ids for `EngineIdle`, `EngineLoad`, `PullStart`, `ReelWhirr`, `LawnDone` and the existing
  `BladeHit` and `Snip`.

## Left to the builder

- Shell count per device class, the blade template's look (dot size, density falloff, color per
  shell), the three stripe greens and the ragged shade. Tune in Play with a reel mower and a zero-turn.
- The brush images, `Light`/`Dark` threshold angle, and how far a standing mower's single cut extends.
- The exact remote shapes, how swaths are batched when several mowers work one lawn, and the log's
  merge rule.
- Where the percent and the missed-spots button sit on each screen (through the HUD editor).
- How `LawnService` builds the mowable mask for odd shapes (obstacle rings, the curb strip), reusing
  its current tile exclusions at cell resolution.
- Phone validation: a 9×7 lawn and the 28×22 lawn on the lowest device you have, with the F9
  memory panel open.

## Playtest checklist (goes into TODO.md when built)

- Mow a straight pass with the reel mower: one clean strip, deck-wide, crisp edges, no seams.
- Mow a curve and a figure-eight: the shape follows the deck.
- Back-and-forth rows: light and dark stripes alternate; a diagonal reads flat.
- Clippings only in tall grass; none crossing the cut strip; engine dips and recovers.
- 90%: the missed button lights the strips; 99%: chime and stamp, job completes.
- Dull blade: ragged tufts remain, quality drops as before.
- Junk: push mower stops at it, gas mower chews it with the existing bits effect.
- Home lawn: leave for a job, come back, patches have grown back and mow again.
- Phone (landscape): the big lawn draws, holds frame rate, and the HUD pieces fit.
- Toggle off Mesh / Image APIs in a test copy: the fallback draws and the job still completes.
