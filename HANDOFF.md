# Handoff: picking up Lawn Mowing Simulator

Written 2026-10-19 for whoever takes over from here. Read this first. Then use
[README.md](README.md) for setup, [TODO.md](TODO.md) for the full checklist and
[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for how every system is meant to work, and
[docs/STORY.md](docs/STORY.md) for the story (Grandma's Rival) and what it needs built.

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

1. Run `rokit install`. It installs Rojo 7.7.1, Selene, StyLua and Lune (for the asset and
   publish scripts).
2. Install the Rojo plugin. It must be **7.7.x** to talk to the 7.7.1 server.
3. Start `rojo serve` and connect from Studio.

Keep **two-way sync OFF** in the Rojo plugin. It once wrote stale Studio copies back over freshly
merged files.

### 2. Robux sales

**Done on 2026-10-21.** Everything below exists on Roblox, is on sale at its price, and has its
id in `Premium.luau`. To add or re-price an item, edit `Premium.luau` (a new item gets id 0) and
run `python3 scripts/premium-setup.py`. It needs an Open Cloud API key, and its header says how
to make one. What's still left is the Studio purchase test in step 2 below.

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

Phones only get what's been published. Publishing is one command and doesn't need Studio
([README.md → Publishing](README.md#publishing) has the details):

```sh
git checkout main && git pull
python3 scripts/publish.py --dry-run   # build, merge and check only
python3 scripts/publish.py             # publish; prints the new version number
```

It needs an Open Cloud key with universe-places write access (`$ROBLOX_API_KEY` or
`~/.roblox-opencloud-key`). Close Studio first: while it has the place open Roblox answers
409 "Server is busy", and the script keeps retrying for about 6 minutes. Then test on a real
phone:
- the left HUD panel doesn't overlap;
- the title card fits the screen;
- the shop computer's apps are usable.

### 5. GUI art from ChatGPT

ChatGPT delivered the full GUI overhaul from
[alphainstructions/instructions38.md](alphainstructions/instructions38.md) in `art-source/GUI/`
(`manifest.json` lists every file). The game's code already uses all of it: the theme in
`src/client/UI.luau`, the bitmap fonts in `src/client/BitmapText.luau`, and the image ids in one
generated module, [src/shared/Config/GuiArt.luau](src/shared/Config/GuiArt.luau). Every id there is
`""` until the images are uploaded, and any piece whose id is `""` is drawn with plain frames, so
the game works the same before, during and after the upload.

To switch the art on:

1. **Upload** the 312 images marked `"role": "upload"` in `manifest.json` (Asset Manager →
   Import, creator **Big Dink Studios**). Keep the names.
2. **Record the ids** in `art-source/GUI/uploaded.json`, by the image's path in the manifest. An
   id can be a number, a string of digits or an `rbxassetid://` string:

   ```json
   {
     "Kit/Panel.png": 123456789,
     "Icons/Money.png": "123456790",
     "Items/ReelMower.png": "rbxassetid://123456791"
   }
   ```

3. **Regenerate** with `python3 scripts/gui-art-ids.py` (pass the GUI folder if it's somewhere
   else, like another worktree). Only `GuiArt.luau` changes. Then run
   `lune run scripts/check-gui` and commit.

You can upload in batches: whatever has an id shows, and the rest stays plain.

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
- **First person keeps the look direction across teleports.** When the server moves a player (back
  to the shop, out to a job's house, after a respawn), `setArrivedFacing` in `JobService` sets the
  `ArrivedFacing` attribute and counts up `Arrivals`. `CameraController` then turns the camera once
  it's back in first person; at join the title card does it. New code that moves a player should
  do the same.
- **Rojo drops `PrimaryPart`** on synced MeshPart models. Use pivots, or find parts by name.
- **Walls and doors:** building walls collide, but doorways must stay open. `makeWalkable` in
  `WorldService` handles this; check walking in through every door after a building model changes.
- **Rojo-Warn spam** ("Ignoring change for instance … unknown to Rojo") in Output is harmless.
- **Models are in `ServerStorage.Assets`**, from `assets/`, so joining doesn't download all of them.
  - `ReplicatedStorage.Assets` only has copies of the few that client code clones, listed in
    `default.project.json`.
  - Each player's screen gets its own copies of the tools they own, and of the crew's truck and
    trailer just before the drive cutscene (`Assets.shareWith`).
  - New client code that clones a model needs the model added to that list.
  - A Studio place synced before this still has the old, full `ReplicatedStorage.Assets`, because
    Rojo leaves unknown models alone. Delete that folder once, then reconnect Rojo, which puts
    back the small one.
- **Join time:** joining prints `[Load]` lines in the F9 console. The Client tab has the title
  card's steps and the Server tab has the save, the business build and arriving there (see
  README.md, "How long joining takes").
