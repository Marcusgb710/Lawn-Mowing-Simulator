# Fluid Mowing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 4-stud grass tiles with a per-pixel lawn surface that the mower carves in its own footprint, with stripes, clippings, engine sound, a percent counter and a missed-spot highlight.

**Architecture:** The server keeps a 1-stud cell ledger per lawn and turns each mower's movement per work tick into a swept rectangle that cuts cells and appends a swath segment to a log; swaths replicate to nearby clients. Each client draws a lawn as a turf plate plus stacked grass shells, all `EditableImage`s, stamping every swath into them, and paints its own mower's sweep every frame ahead of the server. A coarse fallback renderer draws the ledger when `EditableImage` is unavailable.

**Tech Stack:** Roblox Luau (Rojo project), `EditableImage` / `Content.fromObject`, RemoteEvents via `src/shared/Net.luau`, Lune 0.11 for `scripts/check-*.luau` tests, selene and StyLua.

**Spec:** `docs/superpowers/specs/2026-10-28-fluid-mowing-design.md`

## Global Constraints

- Cells are **1 stud**; `GameConfig.TileSize` stays 4 for everything that is not grass. Pixels per stud: **4**, so the biggest lawn (112×88 studs) is 448×352 px; images never exceed **1024×1024**.
- Shell count `N`: **6** on desktop and console, **4** on phones (`UserInputService.TouchEnabled` and no keyboard), never below **2**.
- Shade rule: travel direction against the lawn's local **+Z** ("away from the street"): `Light` when the dot is > 0.5, `Dark` when < -0.5, else `Flat`. Ragged cuts use the `Ragged` shade.
- Mowing completes at **99%** of mowable cells (`GameConfig.MowCompletionThreshold = 0.99`); every other task keeps `CompletionThreshold = 0.95`.
- Missed-spot highlight: available from **90%**, lasts **3 s**, tints the shells red with a soft pulse.
- While `Cutting`: `WalkSpeed × 0.85`, engine shake `× 1.5`, engine pitch about **15%** lower.
- Pay per cell = the old per-tile pay ÷ 16, so a lawn pays what it pays today.
- The ledger is never replicated as a per-tick attribute. Swaths and `Regrow` events carry the picture; `GetSwaths` returns the ledger and the log once.
- All code passes `selene src` and `stylua --check src`, and `rojo build` succeeds, before each PR. Never commit to `main`.
- `EditableImage` fails in a published game until the owner enables **Allow Mesh / Image APIs** (Experience Settings → Security). The code must not assume it is on.

## Review Focus

- A sweep whose endpoints lie outside the lawn (the mower drives off the edge or turns around on the curb) must cut only the cells inside and never index past the ledger. Test: Task 1, `sweep clamps to the lawn`.
- A tick with no movement (the player stands still with the engine running) must cut the cells under the deck once and must not produce a NaN direction or a zero-length segment that repeats every tick. Tests: Task 1, `standing still cuts once`; Task 2, `no segment for an empty sweep`.
- An old home-lawn save whose grass bitmask is per tile (one flag per 4×4 cells) must come back as the same tidy lawn, not fully overgrown. Test: Task 8, `tile flags spread to cells`.
- A lawn whose footprint would exceed 1024 px at 4 px/stud must drop to fewer pixels per stud rather than fail to create its images. Test: Task 5, `pixelsPerStud caps at 1024`.
- `EditableImage` creation throwing (API toggle off, or the client's memory budget spent) must leave a playable lawn drawn by the fallback and must not spam errors. Check: Task 6, Studio step with the toggle off.

---

### Task 1: One-stud cells and the sweep geometry in `LawnGrid`

**Files:**
- Modify: `src/shared/LawnGrid.luau`
- Modify: `src/shared/Config/GameConfig.luau` (after `TileSize = 4`)
- Create: `scripts/check-mowing.luau`
- Modify: `README.md` (the pre-PR checks list: add `lune run scripts/check-mowing`)

**Interfaces:**
- Produces: `GameConfig.CellSize = 1`, `GameConfig.PixelsPerStud = 4`, `GameConfig.MowCompletionThreshold = 0.99`, `GameConfig.DeckOffset = 2` (moved from `ToolService`'s `REACH_OFFSET`), `GameConfig.CuttingSlowdown = 0.85`, `GameConfig.CuttingShake = 1.5`, `GameConfig.MissedSpotsFrom = 0.9`, `GameConfig.MissedSpotsSeconds = 3`.
- Produces: `LawnGrid.TALL/MOWED/RAGGED/EMPTY` unchanged; `LawnGrid.PARTLY_CUT`, `LawnGrid.partlyCut`, `LawnGrid.standing` removed.
- Produces: `LawnGrid.index(column, row, rows)`, `LawnGrid.cell(index, rows)` unchanged; `LawnGrid.center(origin, cellSize, column, row)` unchanged in shape.
- Produces: `LawnGrid.cellsUnderSweep(columns: number, rows: number, fromX: number, fromZ: number, toX: number, toZ: number, halfWidth: number): { number }` — indexes of cells whose centers lie inside the rectangle swept by a deck `2 × halfWidth` wide moving from `from` to `to` (lawn-local studs, origin at the lawn's front-left corner); when `from == to`, the deck's own rectangle oriented along +Z. Capped to the lawn; no duplicates.
- Produces: `LawnGrid.cellsInCircle(columns, rows, x, z, radius): { number }`.
- Produces: `LawnGrid.mowableCount(cells: string): number` (cells not `-`) and `LawnGrid.cutCount(cells: string): number` (cells `1` or `2`).

- [ ] **Step 1: Write the failing checks**

`scripts/check-mowing.luau` follows `scripts/check-story.luau`'s shape (a `check(ok, message)` counter, `process.exit(1)` on failures). Guard Roblox datatypes: `LawnGrid.center` uses `Vector3`; the check never calls it. Add these checks:

```luau
local LawnGrid = require("../src/shared/LawnGrid")
-- 10x10 lawn, deck 5 wide centred on x=5.5 (a cell centre, so no cell sits on the deck's edge),
-- straight pass from z=-1 to z=11
local cells = LawnGrid.cellsUnderSweep(10, 10, 5.5, -1, 5.5, 11, 2.5)
check(#cells == 50, "a straight 5-wide pass over a 10-deep lawn cuts 50 cells")
check(table.find(cells, LawnGrid.index(2, 0, 10)) == nil, "cells left of the deck stay tall")
check(table.find(cells, LawnGrid.index(3, 0, 10)) ~= nil, "the deck's left edge cuts column 3")
check(#LawnGrid.cellsUnderSweep(10, 10, 50, 50, 60, 60, 2.5) == 0, "sweep clamps to the lawn")
local standing = #LawnGrid.cellsUnderSweep(10, 10, 5.5, 5.5, 5.5, 5.5, 2.5)
check(standing >= 10 and standing <= 25, "standing still cuts once, the cells under the deck")
local diagonal = LawnGrid.cellsUnderSweep(10, 10, 0, 0, 10, 10, 1)
check(#diagonal > 10 and #diagonal < 40, "a diagonal cuts a band, not a column")
check(#LawnGrid.cellsInCircle(10, 10, 5, 5, 1) == 4, "a 1-stud snip touches the 4 cells round its point")
check(LawnGrid.mowableCount("0011--2") == 5 and LawnGrid.cutCount("0011--2") == 3, "counts")
```

- [ ] **Step 2: Run it and see it fail**

Run: `lune run scripts/check-mowing`
Expected: FAIL lines for every check (`cellsUnderSweep` is nil).

- [ ] **Step 3: Add the constants to `GameConfig` and implement the functions in `LawnGrid`**

Sweep: compute the four corners of the rectangle (deck width across, from/to along, extended by 1 stud beyond each end so a standing deck is 2 studs long), then test each candidate cell center with a point-in-convex-polygon check using strict inequalities; candidates come from the corners' bounding box clamped to the lawn. Remove the partly-cut API.

- [ ] **Step 4: Run the checks**

Run: `lune run scripts/check-mowing`
Expected: `OK` with no FAIL lines. Then `selene src` and `stylua --check src` clean.

- [ ] **Step 5: Commit**

```bash
git add src/shared/LawnGrid.luau src/shared/Config/GameConfig.luau scripts/check-mowing.luau README.md
git commit -m "Lawn cells are one stud, with the sweep geometry a mower cuts"
```

### Task 2: The swath log in `src/shared/Swath.luau`

**Files:**
- Create: `src/shared/Swath.luau`
- Modify: `scripts/check-mowing.luau`

**Interfaces:**
- Produces: `export type Segment = { fromX: number, fromZ: number, toX: number, toZ: number, halfWidth: number, radius: number?, shade: string, ragged: boolean }` (lawn-local studs; `radius` set and `halfWidth = 0` for a snip).
- Produces: `Swath.shade(dx: number, dz: number): string` → `"Light" | "Dark" | "Flat"` per the global rule; `Swath.RAGGED = "Ragged"`.
- Produces: `Swath.Colors: { [shade]: { number, number, number } }` RGB 0-255: `Light = {134, 212, 87}`, `Flat = {114, 191, 74}`, `Dark = {90, 168, 58}`, `Ragged = {150, 170, 80}` (builder may tune; these are the mock's).
- Produces: `Swath.append(log: { Segment }, segment: Segment): boolean` — merges into `log[#log]` when both are sweeps, same `shade` and `ragged`, same `halfWidth`, the new `from` is within 0.25 studs of the last `to`, and the directions agree within 2°; returns true when it merged.
- Produces: `Swath.pack(segment): { number | string | boolean }` and `Swath.unpack(packed): Segment` for the remote (an array, not a dictionary, to keep the payload small).

- [ ] **Step 1: Write the failing checks** (append to `scripts/check-mowing.luau`)

```luau
local Swath = require("../src/shared/Swath")
check(Swath.shade(0, 1) == "Light" and Swath.shade(0, -1) == "Dark" and Swath.shade(1, 0) == "Flat", "shade by travel")
check(Swath.shade(0.7, 0.71) == "Light", "just past 45 degrees away is still light")
local log = {}
local function seg(fx, fz, tx, tz) return { fromX = fx, fromZ = fz, toX = tx, toZ = tz, halfWidth = 2.5, shade = Swath.shade(tx - fx, tz - fz), ragged = false } end
check(Swath.append(log, seg(0, 0, 0, 2)) == false and #log == 1, "first segment is added")
check(Swath.append(log, seg(0, 2, 0, 4)) == true and #log == 1 and log[1].toZ == 4, "collinear same-shade segments merge")
check(Swath.append(log, seg(0, 4, 0, 2)) == false and #log == 2, "a turn starts a new segment")
check(Swath.append(log, { fromX = 1, fromZ = 1, toX = 1, toZ = 1, halfWidth = 0, radius = 1, shade = "Flat", ragged = false }) == false and #log == 3, "snips never merge")
check(Swath.append(log, seg(5, 5, 5, 5)) == false and #log == 3, "no segment for an empty sweep")
local packed = Swath.pack(log[1])
check(Swath.unpack(packed).toZ == 4 and Swath.unpack(packed).shade == "Light", "pack round-trips")
```

- [ ] **Step 2: Run it and see it fail**

Run: `lune run scripts/check-mowing` — Expected: FAIL for the Swath lines.

- [ ] **Step 3: Implement `Swath.luau`**

`append` returns false and does not add when `from == to` and there is no `radius`.

- [ ] **Step 4: Run the checks, selene and stylua** — Expected: all clean.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Swath.luau scripts/check-mowing.luau
git commit -m "Add the swath log: segments a mower leaves, merged when collinear"
```

### Task 3: The server cuts by sweeping (`LawnService`)

**Files:**
- Modify: `src/server/Services/LawnService.luau` (`_buildGrass` ~394-437, `_setGrass` ~484, `VISUALS.Grass` ~132-146, `_placeDebris`/`_debrisOn` ~1841-1930, `ApplyWork` ~2213-2330, `needed` ~2432, `GetProgress` ~2446, `Finish`/`Regrow` ~2480+)
- Modify: `src/server/Services/JobService.luau` (where `ApplyWork` is forwarded to the lawn)
- Modify: `src/server/Services/HomeLawnService.luau` (same forwarding, plus `Regrow`)
- Modify: `src/shared/Net.luau` (events `Swath`, `Regrow`; function `GetSwaths`)

**Interfaces:**
- Consumes: Task 1's `LawnGrid` functions and constants; Task 2's `Swath`.
- Produces: `Lawn:Sweep(fromX, fromZ, toX, toZ, halfWidth: number, toolId: string, context: WorkContext): WorkResult` — world X/Z in, converted to lawn-local by subtracting `self.origin`; cuts every tall cell under the sweep that the tool fits (`TaskTypes.fit`), credits `result` the way `_work` does for a finished target, handles junk exactly as `ApplyWork` does (`strikes` vs stop), sets `result.changed`, appends to `self.swaths` via `Swath.append`, fires `Net.event("Swath")` to players within `GameConfig.GrassDrawDistance` (new constant, 230, matching the client's draw distance plus slack) with `(self.grassFolder, Swath.pack(segment), merged: boolean)`.
- Produces: `Lawn:SnipAt(x, z, radius, toolId, context): WorkResult` for shears: `cellsInCircle`, same crediting, a `radius` segment.
- Produces: `Lawn:GetSwaths(): (string, { packed })` — the ledger string and the packed log.
- Produces: `Lawn:GetProgress()` entries for Grass tasks gain `percent: number` (cut over mowable, 0-1).
- Produces: `JobService:Sweep(player, fromX, fromZ, toX, toZ, halfWidth, toolId, options)` and `HomeLawnService:Sweep(...)` mirroring their `ApplyWork` wrappers; `JobService`/`HomeLawnService` `:SnipAt(...)` likewise.
- Produces: the `Grass` folder keeps attributes `Origin`, `Columns`, `Rows`, `TallScale`, and gains `CellSize = 1`; the `State`/`TileSize` attributes are gone.
- Produces: `Net.func("GetSwaths").OnServerInvoke = function(player, grassFolder)` → `Lawn:GetSwaths()` for a lawn the player may see.
- Produces: `Regrow` event `(grassFolder, { cellIndex })` fired once per regrow pass by `HomeLawnService`.

- [ ] **Step 1: Write the failing check** (append to `scripts/check-mowing.luau`; the lawn's cell loop is pure enough to lift into `LawnGrid`)

Add `LawnGrid.mowableMask(columns, rows, blocked: { [number]: boolean }): { string }` to `LawnGrid` (Task 1's module), returning the initial cell array with `-` where `blocked[index]`, `0` elsewhere, and check:

```luau
local mask = LawnGrid.mowableMask(4, 4, { [LawnGrid.index(1, 1, 4)] = true })
check(#mask == 16 and mask[LawnGrid.index(1, 1, 4)] == "-" and mask[1] == "0", "mowable mask marks blocked cells")
```

- [ ] **Step 2: Run it and see it fail** — `lune run scripts/check-mowing`.

- [ ] **Step 3: Rebuild `_buildGrass` on cells**

Cells are `GameConfig.CellSize`; `hazardTiles`/`obstacleTiles` stay tile-indexed, so a cell is blocked when its tile is, via `tile = LawnGrid.cell(index, rows)` → tile column `math.floor(column / 4)`. One target per mowable cell with `maxWork = oldTileWork / 16`, `reach = 0.5`, `byIndex` filled. Remove `grass:SetAttribute("State", …)` and `TileSize`; set `CellSize`. `_setGrass` keeps updating `grassState`, drops `grassDirty`/the `State` flush. `VISUALS.Grass` only sets `MOWED`/`RAGGED` at `fraction >= 1`.

- [ ] **Step 4: Implement `Sweep`, `SnipAt`, `GetSwaths`; route `ApplyWork` away from grass**

`ApplyWork` skips `Grass` targets entirely (they are cut only by sweeps and snips). Debris keeps a cell index: `_placeDebris` picks a tall cell at least 4 cells from other pieces and from flower cells. In `Sweep`, when a non-`strikes` tool meets debris in a cell, that cell and the ones beyond it in the sweep are not cut and `result.debris` is set (the push mower stops at it, as today).

- [ ] **Step 5: Wire `JobService`, `HomeLawnService`, `Net`**

`HomeLawnService`'s regrow pass collects the cell indexes it regrows and fires `Regrow` once per pass. `HomeLawn` saving stays per target (now per cell); Task 8 handles old saves.

- [ ] **Step 6: Checks, lint, build**

Run: `lune run scripts/check-mowing && selene src && stylua --check src && rojo build -o <scratch>/check.rbxl` — Expected: all clean.

- [ ] **Step 7: Studio check (Play)**

Connect Rojo, Play, take a job with a mowing task, walk the reel mower over the lawn: the Output shows no errors; `Grass:GetAttribute("CellSize") == 1`; the HUD task row's done count climbs (the client still draws nothing new until Task 5). Shears still snip.

- [ ] **Step 8: Commit**

```bash
git add src/server/Services/LawnService.luau src/server/Services/JobService.luau src/server/Services/HomeLawnService.luau src/shared/Net.luau src/shared/LawnGrid.luau scripts/check-mowing.luau
git commit -m "Mowers cut the lawn by sweeping one-stud cells, logged as swaths"
```

### Task 4: `ToolService` sweeps per tick and marks `Cutting`

**Files:**
- Modify: `src/server/Services/ToolService.luau` (`REACH_OFFSET` ~41, `setFx`/`addFx` ~121-150, `snip` ~556-648, `workTick` ~649-765)

**Interfaces:**
- Consumes: Task 3's `JobService:Sweep` / `HomeLawnService:Sweep` / `:SnipAt`.
- Produces: tool attributes `Cutting: boolean` (true when this tick's sweep changed at least one cell) alongside the existing `Working`; `WorkFx` on mowers is enabled by `Cutting`, on everything else by `Working` as before.
- Produces: `GameConfig.DeckOffset` replaces `REACH_OFFSET`; `lastDeck[tool] = Vector3` remembers the previous tick's deck position, cleared when the tool stops running.
- Produces: while `Cutting`, `humanoid.WalkSpeed = item.walkSpeed × tireFactor × GameConfig.CuttingSlowdown`.
- Produces: `addFx` places the emitter on the deck's discharge side: `Attachment "Chute"` at `(+radius, 0, 0)` of the base for motorized mowers, `(0, 0, +0.5)` behind for reel mowers, with `EmissionDirection` away from the deck, `Speed 6-10`, `Lifetime 0.3-0.6`, `Color` light green `(196, 240, 120)`.

- [ ] **Step 1: Implement the tick change**

In `workTick`, for `item.category == "Mower"` (and not towing): `deck = root.Position + LookVector * GameConfig.DeckOffset`; `from = lastDeck[tool] or deck`; call `Sweep(player, atJob, from.X, from.Z, deck.X, deck.Z, item.radius, itemId, context)` with the existing context fields (`ragged`, `strikes`, `moving`, `seconds`, `qualityScale`); then `lastDeck[tool] = deck`. Other tools keep `applyWork`. Set `Cutting` from `result.changed`. Shears' `snip` calls `SnipAt` with `config.radius`.

- [ ] **Step 2: Lint and build** — `selene src && stylua --check src && rojo build …` clean.

- [ ] **Step 3: Studio check (Play)**

With the gas push mower: `Cutting` flips true over tall grass and false on cut grass (watch it in the Properties window); clippings fly from the right side only over tall grass; walking speed visibly drops in tall grass; a push mower stops at a stick, the gas mower chews it (bits effect and `BladeHit`).

- [ ] **Step 4: Commit**

```bash
git add src/server/Services/ToolService.luau
git commit -m "Mowers sweep from last tick's deck to this one, and say when they're cutting"
```

### Task 5: Image sizing and the blade template (`src/shared/GrassImages.luau`)

**Files:**
- Create: `src/shared/GrassImages.luau` (pure maths, no Roblox calls, so Lune can check it)
- Modify: `scripts/check-mowing.luau`

**Interfaces:**
- Produces: `GrassImages.pixelsPerStud(widthStuds: number, heightStuds: number): number` — `GameConfig.PixelsPerStud`, halved until both `width × pps` and `height × pps` are ≤ 1024.
- Produces: `GrassImages.shellCount(touch: boolean): number` — 6, or 4 on touch devices.
- Produces: `GrassImages.shellPlan(count: number, tallHeight: number): { { height: number, density: number } }` — shell `k` sits at `tallHeight × k / count`, density falls from 1.0 to 0.35 linearly.
- Produces: `GrassImages.bladeDots(widthPx: number, heightPx: number, density: number, seed: number): { { x: number, y: number, r: number, tone: number } }` — deterministic dot positions for one shell (about `density × 0.6` dots per 4×4 px), radius 1-2 px, tone 0-1 for the color mix.
- Produces: `GrassImages.worldToPixel(originX, originZ, pps, x, z): (number, number)`.

- [ ] **Step 1: Write the failing checks**

```luau
local GrassImages = require("../src/shared/GrassImages")
check(GrassImages.pixelsPerStud(36, 28) == 4, "a small lawn gets 4 px per stud")
check(GrassImages.pixelsPerStud(112, 88) == 4, "the biggest lawn still fits at 4")
check(GrassImages.pixelsPerStud(300, 40) == 2, "pixelsPerStud caps at 1024")
check(GrassImages.shellCount(false) == 6 and GrassImages.shellCount(true) == 4, "shell counts")
local plan = GrassImages.shellPlan(6, 1.5)
check(#plan == 6 and plan[6].height == 1.5 and plan[1].density == 1 and plan[6].density < 0.4, "shell plan")
local dots = GrassImages.bladeDots(40, 40, 1, 7)
check(#dots > 40 and #dots == #GrassImages.bladeDots(40, 40, 1, 7), "dots are plentiful and deterministic")
local px, py = GrassImages.worldToPixel(100, 200, 4, 110, 205)
check(px == 40 and py == 20, "world to pixel")
```

- [ ] **Step 2: Run, see it fail** — `lune run scripts/check-mowing`.

- [ ] **Step 3: Implement `GrassImages.luau`** (use `Random.new(seed)` only if Lune's Luau has it; otherwise a small LCG as in the check script).

- [ ] **Step 4: Run the checks, selene, stylua** — clean.

- [ ] **Step 5: Commit**

```bash
git add src/shared/GrassImages.luau scripts/check-mowing.luau
git commit -m "Add the grass image maths: sizes, shell plan and blade dots"
```

### Task 6: The client draws the surface (`GrassController` rewrite)

**Files:**
- Modify: `src/client/Controllers/GrassController.luau` (replace the tile renderer)
- Create: `src/client/Controllers/GrassFallback.luau` (the coarse renderer; a plain module, not a controller)

**Interfaces:**
- Consumes: `Net.event("Swath")`, `Net.event("Regrow")`, `Net.func("GetSwaths")` (Task 3); `Swath.unpack`, `Swath.Colors` (Task 2); `GrassImages` (Task 5); the `Grass` folder attributes `Origin`, `Columns`, `Rows`, `CellSize`, `TallScale`.
- Produces: `GrassController.paintSweep(grassFolder: Folder, fromX, fromZ, toX, toZ, halfWidth, shade: string, ragged: boolean)` — used by Task 7 for the local mower; a no-op when the lawn isn't drawn.
- Produces: `GrassController.highlightUncut(grassFolder: Folder, seconds: number)` — used by Task 9.
- Produces: `GrassController.isSurface(): boolean` — false when running on the fallback (for the HUD to word things).
- Produces per drawn lawn: `workspace.LocalGrass/<lawn>` holding `Turf` (Part, size `columns × 0.1 × rows` studs, top `Decal` with the turf image, `Material = Grass`) and `Shell1..N` (Parts, `Transparency = 1`, `CanCollide = false`, `CanQuery = false`, top `Decal` each with its shell image, stacked by `GrassImages.shellPlan(N, GameConfig.TallGrassHeight × TallScale)`).
- Brushes: one `EditableImage` 16×16 opaque white (`Brush`), one 16×16 with a 50% hole pattern (`RaggedBrush`), one 16×16 fully transparent (`Eraser`), one `RaggedEraser`.

- [ ] **Step 1: Build the surface**

`track(folder)` reads the attributes, computes `pps = GrassImages.pixelsPerStud(columns, rows)`, and on `show(lawn)`: `pcall(AssetService.CreateEditableImage, …)` for `N + 1` images; on any failure call `GrassFallback.show(lawn)` and `warn` once per session. Fill each shell with its blade dots (`DrawCircle` per dot; two greens by `tone`) and the turf with `Swath.Colors.Flat` darkened 15%. Then `Net.func("GetSwaths"):InvokeServer(folder)` and replay every segment through `applySegment`. Cells that are `-` in the ledger are erased from every shell (`DrawRectangle` per cell, transparent, `Overwrite`) and painted ground-brown on the turf.

- [ ] **Step 2: Implement `applySegment(lawn, segment)`**

For a sweep: length `L` and width `2 × halfWidth` in pixels; `DrawImageTransformed(centerPx, Vector2.new(L / 16, W / 16), angleDeg, Brush or RaggedBrush, { CombineType = Overwrite })` into the turf with the brush recolored by `Swath.Colors[shade]` (`DrawImageTransformed` has no color: keep one pre-colored 16×16 brush per shade, made once), and the eraser into every shell. Two `DrawLine`s 1 px, 10% darker, along the two long edges, as the tracks. For a snip (`radius`): `DrawCircle` with the shade color into the turf and transparent into the shells.

- [ ] **Step 3: Events**

`Swath` → `applySegment` (when the lawn is drawn; otherwise ignore, the replay will catch up). `Regrow` → for each cell, `DrawRectangle` the cell's blade dots back into every shell (`DrawImage` from a per-shell `Template` image kept from the fill) and repaint the turf cell flat. `hide(lawn)` destroys the parts and calls `Destroy()` on every image.

- [ ] **Step 4: `GrassFallback.show/hide/apply`**

One `Turf` part per lawn with a `SurfaceGui`-free look: 2-stud `Part`s on a flat plate would be a grid again, so instead a single plate coloured mowed-green plus one flat `Part` per *uncut 2×2-cell block* (`Grass` material, `TallGrassHeight` tall), removed as swaths cover them. Good enough to play; it is the safety net.

- [ ] **Step 5: Lint and build** — `selene src && stylua --check src && rojo build …` clean.

- [ ] **Step 6: Studio check (Play, Mesh / Image APIs on in Studio)**

Reel mower, straight pass: one strip, deck-wide, crisp edge, no seams; a curve follows the deck; back-and-forth rows show light and dark; snips with the shears make small round holes; leave the job (the lawn is destroyed; F9 memory drops back). Join a second client (Test → 2 players): the second client's lawn matches after `GetSwaths`. Then Game Settings → Security → turn **off** Allow Mesh / Image APIs → the fallback draws and the job still completes; turn it back on.

- [ ] **Step 7: Commit**

```bash
git add src/client/Controllers/GrassController.luau src/client/Controllers/GrassFallback.luau
git commit -m "Draw the lawn as a turf plate and grass shells that swaths carve"
```

### Task 7: Your own mower paints ahead of the server

**Files:**
- Modify: `src/client/Controllers/GrassController.luau` (a `RenderStepped` loop)

**Interfaces:**
- Consumes: `GrassController.paintSweep` (Task 6); tool attributes `Working`, `Blocked`, `ItemId`, `Ride`; `Tools.get(id).radius`; `GameConfig.DeckOffset`; `Swath.shade`.
- Produces: `local lastLocalDeck: Vector3?`, reset when the tool changes or `Working` goes false.

- [ ] **Step 1: Implement**

Every frame, if the local character holds a `Tool` with `Category == "Mower"`, `Working == true` and `Blocked == nil`: `deck = root.Position + LookVector × DeckOffset`; find the drawn lawn whose footprint contains `deck` (or `lastLocalDeck`); if there is one and `lastLocalDeck` exists and moved ≥ 0.05 studs, `paintSweep(folder, last.X, last.Z, deck.X, deck.Z, radius, Swath.shade(dx, dz), tool:GetAttribute("Ragged") == true)`. The server's `syncCondition` already copies `Sharpness`; add a `Ragged` attribute set by `ToolService` from `quality < RAGGED_BELOW` so the local brush matches.

- [ ] **Step 2: Lint, build** — clean.

- [ ] **Step 3: Studio check (Play)**

The strip appears under the deck with no visible lag at full walk speed; stopping mid-lawn leaves a clean deck-shaped end; with the reel mower, standing still cuts nothing new locally (the server's one-time cut arrives on the next tick).

- [ ] **Step 4: Commit**

```bash
git add src/client/Controllers/GrassController.luau src/server/Services/ToolService.luau
git commit -m "Paint your own mower's swath every frame, ahead of the server"
```

### Task 8: Home lawn saves survive the cell change

**Files:**
- Modify: `src/shared/HomeLawn.luau` (`decode` ~40)
- Modify: `src/server/Services/HomeLawnService.luau` (where `HomeLawn.decode` is called, ~179)
- Modify: `src/server/Services/DataService.luau` (`DATA_VERSION` 11 → 12, a no-op migration step with a comment: grass flags are re-read per cell by `HomeLawnService`)
- Modify: `scripts/check-mowing.luau`

**Interfaces:**
- Produces: `HomeLawn.decode(saved: unknown, count: number, spread: number?, rows: number?): { boolean }` — when `saved` has exactly `count / spread` flags (`spread = 16` for grass) and `rows` (the lawn's cell rows) is given, each tile flag fills its block of 16 cells (tile `(c, r)` → cells `(4c..4c+3, 4r..4r+3)`, tile rows being `rows / 4`); otherwise as today.

- [ ] **Step 1: Write the failing check**

```luau
local HomeLawn = require("../src/shared/HomeLawn")
-- a 2x1-tile lawn saved per tile: left tile done, right not; cells are 8x4
local cells = HomeLawn.decode("10", 32, 16, 4)
check(#cells == 32 and cells[1] == true and cells[32] == false, "tile flags spread to cells")
check(HomeLawn.decode("10", 32)[1] == false, "mismatched saves without a spread are all not done")
```

- [ ] **Step 2: Run, see it fail.**

- [ ] **Step 3: Implement `decode`'s spread; call it with `16, lawn.rows` for the Grass task in `HomeLawnService`; bump `DATA_VERSION`.**

- [ ] **Step 4: Checks, lint, build** — clean.

- [ ] **Step 5: Studio check**

With API services on and a save from before this branch (keep one from `main`): the home lawn comes back tidy where it was tidy, mow it, rejoin, it stays mown.

- [ ] **Step 6: Commit**

```bash
git add src/shared/HomeLawn.luau src/server/Services/HomeLawnService.luau src/server/Services/DataService.luau scripts/check-mowing.luau
git commit -m "Spread old per-tile home lawn saves over the new cells"
```

### Task 9: The counter, the missed spots and the finish

**Files:**
- Modify: `src/client/Controllers/HudController.luau` (task rows ~1030-1035)
- Modify: `src/client/UiLayout.luau` (new piece `MissedButton`)
- Modify: `src/server/Services/LawnService.luau` (`needed` ~2432)
- Modify: `src/shared/Sounds.luau` (`LawnDone` id slot)
- Modify: `scripts/check-mowing.luau`

**Interfaces:**
- Consumes: `GetProgress` `percent` (Task 3); `GrassController.highlightUncut` (Task 6); `UI.stamp` (exists, `UI.luau` ~1872).
- Produces: `LawnGrid.needed(total: number, optional: number, threshold: number): number` (pure; `needed` in `LawnService` calls it with `GameConfig.MowCompletionThreshold` for Grass tasks, `CompletionThreshold` otherwise).
- Produces: the mowing task row reads `Mow the lawn  87%`; from 90% a `MissedButton` HUD piece ("Show what I missed", key `F` on keyboards) calls `highlightUncut(folder, GameConfig.MissedSpotsSeconds)` for the job's lawn; when the row's fraction crosses 1 the client plays `Sounds.play(camera, "LawnDone")` and stamps the row with `UI.stamp`.

- [ ] **Step 1: Write the failing check**

```luau
check(LawnGrid.needed(1000, 0, 0.99) == 990 and LawnGrid.needed(1000, 100, 0.99) == 891, "needed rounds up")
```

- [ ] **Step 2: Run, see it fail.**

- [ ] **Step 3: Implement** (`needed` in `LawnGrid`; the HUD row; `MissedButton` registered in `UiLayout` with a phone place and a desktop place next to the task list; `LawnDone` slot).

- [ ] **Step 4: `lune run scripts/check-gui`** must still pass (it checks every `UiLayout` entry is placed and every placed element exists), plus `check-mowing`, selene, stylua, build.

- [ ] **Step 5: Studio check (Play, PC and phone emulator)**

The percent climbs; at 90% the button appears; pressing it (or `F`) pulses the uncut grass red for 3 s; at 99% the chime (silent until an id is set) and the stamp land and the job completes; the button is placeable in the HUD editor.

- [ ] **Step 6: Commit**

```bash
git add src/client/Controllers/HudController.luau src/client/UiLayout.luau src/server/Services/LawnService.luau src/shared/LawnGrid.luau src/shared/Sounds.luau scripts/check-mowing.luau
git commit -m "Show mowing as a percent, light up missed spots, and stamp the finish"
```

### Task 10: Engine sound and shake under load

**Files:**
- Create: `src/client/Controllers/EngineAudioController.luau` (register it where the other controllers start, `src/client/init.client.luau`)
- Modify: `src/client/Controllers/CameraController.luau` (~206-216)
- Modify: `src/shared/Sounds.luau` (ids `EngineIdle`, `EngineLoad`, `PullStart`, `ReelWhirr`)

**Interfaces:**
- Consumes: tool attributes `Working`, `Cutting`, `ItemId`; `Maintenance.burnsFuel(item)`; `Sounds.Ids`.
- Produces: for every character's mower with `Working`, two looping `Sound`s parented to the tool's base, `Volume` crossfaded over 0.15 s toward `EngineLoad` while `Cutting`, `PlaybackSpeed` 0.85 while `Cutting` else 1.0, nudged +0.05 while moving; `PullStart` once on equip of a motorized mower; `ReelWhirr` looping while a non-motorized mower moves. Empty ids stay silent (`Sounds.Ids` convention).
- Produces: `CameraController` multiplies `strength` by `GameConfig.CuttingShake` when `tool:GetAttribute("Cutting") == true`.

- [ ] **Step 1: Implement the controller and the shake change.**

- [ ] **Step 2: Put placeholder ids in `Sounds.Ids` from the Creator Store's free audio** (search "lawn mower idle", "lawn mower cutting", "pull start", "push mower", "success chime"; group-owned uploads only if nothing fits; note each id's source in a comment).

- [ ] **Step 3: Lint, build** — clean.

- [ ] **Step 4: Studio check (Play)** — idle on cut grass, bog in tall grass, pull-start on equip, stronger shake while cutting, silence after unequip; a second client hears the first's mower.

- [ ] **Step 5: Commit**

```bash
git add src/client/Controllers/EngineAudioController.luau src/client/init.client.luau src/client/Controllers/CameraController.luau src/shared/Sounds.luau
git commit -m "Give mowers an engine that bogs in thick grass"
```

### Task 11: Docs, checklist and the PR

**Files:**
- Modify: `docs/GAME_DESIGN.md` (the grass/lawn section: tiles → cells, swaths, shells, fallback; the Premium "where looks show" style)
- Modify: `TODO.md` (a "Fluid mowing" to-check list copied from the spec's playtest checklist; "Before release" gains "Turn on Allow Mesh / Image APIs")
- Modify: `HANDOFF.md` (one paragraph under gotchas: the API toggle, the fallback, `check-mowing`)

- [ ] **Step 1: Write the docs.**

- [ ] **Step 2: Full check run** — `lune run scripts/check-mowing && lune run scripts/check-gui && lune run scripts/check-story && selene src && stylua --check src && rojo build …` all clean.

- [ ] **Step 3: Phone validation** (the spec's constraint): in Studio's Device emulator (a low-end phone preset, landscape), the 9×7 lawn and the 28×22 lawn draw, mow and finish with the F9 memory panel open; note the peak in the PR.

- [ ] **Step 4: Commit and open the PR**

```bash
git add docs/GAME_DESIGN.md TODO.md HANDOFF.md
git commit -m "Document fluid mowing: cells, swaths, shells and the API toggle"
gh pr create --repo Marcusgb710/Lawn-Mowing-Simulator --base main --title "Fluid mowing: the lawn as a surface you carve" --body-file <body>
```

The PR body lists the checks run, the phone numbers, and reminds the owner to enable Allow Mesh / Image APIs before publishing.
