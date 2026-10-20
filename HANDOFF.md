# Handoff: picking up Lawn Mowing Simulator

Written 2026-10-19 for whoever takes over from here. Read this first. Then use
[README.md](README.md) for setup, [TODO.md](TODO.md) for the full checklist and
[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for how every system is meant to work.

## Where things stand

- **The game:** "Lawn Mowing Simulator" is owned by the **Big Dink Studios** group.
  - Universe 10771693515, place 73083404631437.
  - It's private, with Team Create on.
  - Open it in Studio from Roblox, not from a local file.
- **Done:** every phase in the design doc (A–F, Camera, Immersion 1–3, Hub 1–3b) is merged. That
  covers:
  - the shop as the hub (job computer, Orders app, deliveries in boxes);
  - first person;
  - walk-in buildings;
  - loading the truck;
  - hands-on maintenance;
  - your own lawn;
  - decorations;
  - the title card.
- **Models:** all 115 items have ChatGPT-made high-poly models, imported and synced from
  `assets/`.
- **The last publish to Roblox** came before the three open PRs below, so phones don't have them
  yet.

### Open PRs: merge these first

| PR | What | Files |
| --- | --- | --- |
| [#30](https://github.com/Marcusgb710/Lawn-Mowing-Simulator/pull/30) | ChatGPT's title card art (logo, key art tiles, mower, stripes) | `src/first/`, `art-source/TitleCard/` |
| [#31](https://github.com/Marcusgb710/Lawn-Mowing-Simulator/pull/31) | The money/Truck/Guide/Crew panel on the left no longer overlaps on phones (it scales down to fit) | `HudController.luau` |
| [#32](https://github.com/Marcusgb710/Lawn-Mowing-Simulator/pull/32) | Robux purchases: pro upgrades, premium tools, truck paint (see below) | `Premium.luau`, `PremiumService.luau` and others |

They touch different files, so merge them in any order:

```sh
gh pr merge 30 --merge --repo Marcusgb710/Lawn-Mowing-Simulator
gh pr merge 31 --merge --repo Marcusgb710/Lawn-Mowing-Simulator
gh pr merge 32 --merge --repo Marcusgb710/Lawn-Mowing-Simulator
```

## What to do next, in order

### 0. Access (the owner does this)

- Add the new person to the **Big Dink Studios** group with a role that can edit the experience,
  use Team Create, upload assets and manage monetization.
- Add them as a collaborator on the GitHub repo.
- Everything uploaded must be **owned by the group**, not a personal account.

### 1. Set up

Follow [README.md → Setup](README.md#setup-rojo):

1. Run `rokit install`. It installs Rojo 7.7.1, Selene and StyLua, and Lune if you want the asset
   scripts.
2. Install the Rojo plugin. It must be **7.7.x** to talk to the 7.7.1 server.
3. Start `rojo serve` and connect from Studio.

Keep **two-way sync OFF** in the Rojo plugin. It once wrote stale Studio copies back over freshly
merged files.

### 2. Turn on Robux sales (PR #32)

Everything is built and tested in Studio. What's missing is the Roblox-side ids, so every item
shows **"Soon"** in the shop until it has one. On the [Creator
Dashboard](https://create.roblox.com/dashboard/creations/experiences/10771693515/overview),
create these at these prices.

**Monetization → Passes:**

| Pass | Robux | Perk |
| --- | --- | --- |
| Diamond Blades | 199 | Every blade never dulls |
| Run-Flat Tires | 149 | Tires never lose air or go flat |
| Endless Spool | 99 | Trimmer line never runs out |
| Big Tank | 99 | Fuel lasts 3× as long |

**Monetization → Developer Products:**

| Product | Robux | | Product | Robux |
| --- | --- | --- | --- | --- |
| Golden Push Mower | 249 | | Racing Red | 49 |
| Chrome Self-Propelled Mower | 299 | | Midnight Black | 49 |
| Stealth String Trimmer | 199 | | Forest Green | 49 |
| Chrome Leaf Blower | 149 | | Sky Blue | 49 |
| Golden Riding Mower | 499 | | Stealth Wrap | 99 |
| Stealth Zero-Turn | 799 | | Chrome Wrap | 149 |
| | | | Gold Wrap | 149 |

Then:

1. Put each pass's id in its `gamePassId` and each product's id in its `productId` in
   [src/shared/Config/Premium.luau](src/shared/Config/Premium.luau).
2. Test in Studio by pressing Play and buying from the shop computer → Orders → **Premium** tab.
   Studio purchases are free test purchases. Check:
   - a pass turns its perk on (for example, Diamond Blades: blades stop dulling);
   - a premium tool needs the base tool owned first, then shows its finish in hand, in the truck
     and on the wall;
   - a paint job repaints the parked truck, and "Factory paint" puts it back;
   - buying the same product twice doesn't break anything, and purchases survive a rejoin.
3. Commit, PR, merge, then publish (step 4).

How it works: [GAME_DESIGN.md §10 Premium](docs/GAME_DESIGN.md#10-premium). Receipts are saved
straight away and remembered, so nothing is granted twice or lost.

### 3. Small gaps left from the Premium work (code)

These are not done yet:
- Premium paint isn't shown on the truck in the travel cutscene (`CutsceneController`).
- Finishes aren't shown on tools inside delivery boxes, or on a tool set down at a workbench
  service spot.

Use `Premium.paintFor` / `Premium.finishFor` with `Premium.applyPaint` / `Premium.applyFinish`.
Each player's `premium` table is in their profile on the client.

### 4. Publish to Roblox

Phones only get what's been published. With main pulled, Rojo connected and the place showing
the latest code, use **File → Publish to Roblox**. Then test on a real phone:
- the left HUD panel doesn't overlap;
- the title card fits the screen;
- the shop computer's apps are usable.

### 5. GUI art from ChatGPT

[alphainstructions/instructions36.md](alphainstructions/instructions36.md) asked ChatGPT for
concept art and a full GUI kit in `art-source/GUI/`:
- 9-slice panels and buttons;
- glyphs;
- the computer's wallpaper and app icons;
- **108 item icons named by item id**.

When it's delivered (usually on a `codex/*` branch):

1. **Upload:** in Studio, use Asset Manager → Import, with **Big Dink Studios** as creator. Roblox
   shrinks anything over 1024 px, so split big images into tiles (the title card's key art is 4
   tiles for that reason).
2. **Wire it in (code):** put the ids in a table module, the way
   [src/first/TitleCardArt.luau](src/first/TitleCardArt.luau) does. Then use them in the shop
   cards (`ShopController`), the HUD (`HudController`), the computer screen and the hotbar.
   Today the UI is drawn with plain frames from `src/client/UI.luau`.

### 6. Playtest checklist

[TODO.md](TODO.md) has a "To check in Studio" list for every phase, for example:
- grips and first-person poses;
- ride-on seats;
- doors and tailgates;
- desks and boxes;
- decorations.

Work through it in Play mode, and with 2–4 players (Test → Clients and Servers) for crews. Its
**Before release** section covers the rest:
- making the game public;
- max players;
- sounds (`src/shared/Sounds.luau` has empty ids);
- animations;
- the game icon and thumbnails.

## How work gets done here

- **Branches and PRs:** never commit straight to `main` for code. Make a branch, open a PR, merge
  with `--merge`. Before PRs, run `selene src`, `stylua src` and
  `rojo build -o /tmp/check.rbxl`.
- **ChatGPT/Codex makes the models and art.**
  - Write a self-contained spec as `alphainstructions/instructionsN.md`; **the next one is
    `instructions37.md`**.
  - Push it to `main`. A push touching `alphainstructions/` triggers the "Work on Alpha
    instructions" GitHub Action (Codex, with OpenAI billing). You can also point ChatGPT at the
    file yourself.
  - Models come back as glTF plus `model_manifest.json` in `model-source/HighPoly/NN_*`.
- **Importing models:**
  1. Run `python3 scripts/generate-prepare.py` to regenerate `scripts/PrepareChatGPTModels.luau`
     from the manifests.
  2. In Studio, use File → Import 3D with:
     - Creator **Big Dink Studios**. It resets to "Me" on every file, and the "Last Imported"
       preset resets it too.
     - **World Forward: Back**.
     - **Scale Unit: Meter**.
     - Anchored.
  3. Paste the Prepare script into the command bar. It strips the importer's `_Node` suffix and
     adds markers, collision and hinge pivots.
  4. Right-click `ServerStorage.ModelImport` → Save to File.
  5. Run `lune run scripts/export-models <file>.rbxm --overwrite`.
  6. Delete `ModelImport` from Studio.
- **Code layout:** see [README.md → Project layout](README.md#project-layout). `ReplicatedFirst` is
  `src/first/`, which holds the title card.

## Gotchas that cost time before

- **Rojo crashes** when a synced folder disappears, for example when switching to a branch without
  it. Restart `rojo serve` and reconnect in Studio.
- **The Studio command bar** gets its own copy of every module. It can't see the live server's
  state, such as `DataService` profiles, so test gameplay in Play mode, not by poking modules
  from the command bar.
- **Saves in Studio** need Game Settings → Security → *Enable Studio Access to API Services*.
  Without it the game runs but doesn't save. `DataService` skips its retries in Studio so joining
  stays fast.
- **First person keeps the look direction across teleports.** When the server moves a player (for
  example back to the shop), it sets the `ArrivedFacing` attribute so the client can turn the
  camera.
- **Rojo drops `PrimaryPart`** on synced MeshPart models. Use pivots, or find parts by name.
- **Walls and doors:** building walls collide, but doorways must stay open. `makeWalkable` in
  `WorldService` handles this; check walking in through every door after a building model changes.
- **Rojo-Warn spam** ("Ignoring change for instance … unknown to Rojo") in Output is harmless.
