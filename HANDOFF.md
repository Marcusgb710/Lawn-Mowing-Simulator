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
- **Models:** every item has a model in `assets/`, and they come from two places: the Creator
  Store pipeline and ChatGPT's older high-poly packs.
  - 26 are free Creator Store models fitted by the manifest pipeline: the mowers, trimmers,
    blowers, barrows, hedge shears, spreader, sprayer and gas cans (18 tools), the 4 trucks, the 3
    trailers and the customer's house.
  - 13 are ChatGPT's high-poly models, kept on purpose and recorded as `kept` in the manifest.
  - The rest are still ChatGPT's high-poly models, imported and synced from `assets/`.
  - The story's nine people are not model files. They are Roblox avatars built from the catalog
    when the server starts.
  - The pipeline was built on the branch `bentenavery/model-overhaul`. Until that is merged, the
    files named below exist only there. What's left is step 7.
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
- sounds (the mowers' engine and the lawn-done chime have ids in `src/shared/Sounds.luau`; the
  rest are still empty);
- turning on Allow Mesh / Image APIs, or lawns draw the plain-part fallback (see "Gotchas");
- animations;
- the game icon and thumbnails.

### 7. Finish the model overhaul

The pipeline is built and batches 1 to 4 are in. [TODO.md](TODO.md) has the rest under **Model
overhaul: what is left** and **Before release**. In order:

1. **Upload the four lawn images.** Use Asset Manager under Big Dink Studios, or give the Open
   Cloud key the Assets scope and run `python scripts/upload-grass-art.py` again (TODO.md has the
   steps). The ids go in `src/shared/Config/GrassArt.luau`. Then look at a lawn in Studio with the
   textured path on. It has only been seen in flat colours, because the ids are still 0.
2. **Make the TurfKing T-shirt.** Create it on the Create page from
   `art-source/Cast/TurfKing_Tee.png`, as Big Dink Studios (the group). It carries a Robux upload
   fee, so look at the price first; spending it is the owner's call. Put the id in `tshirt` for
   Chad and Sam_TurfKing in `src/shared/Config/Cast.luau`, then run
   `lune run scripts/check-story` and `python -I scripts/cast-check.py`. The cast check accepts an
   item the Big Dink Studios group made whatever its sale state, because the group's own items are
   always usable by its experience.
3. **Work through the model playtest checklist** in TODO.md (tools in hand, a job with the new
   truck and trailer, the story scenes, the grass, and the Galaxy A06 preset for frame time).
4. **Do batches 5 to 7** (hand and long tools, pro machines, then the four business buildings
   together) and the swap list (decorations, storage, boxes, junk, the trophy, Gloria's set). Each
   is a manifest addition plus a Studio import: see "Models: the manifest pipeline" below.

## How work gets done here

- **Branches and PRs:** never commit straight to `main` for code. Make a branch, open a PR, merge
  with `--merge`. Before PRs, run `lune run scripts/check-mowing`, `lune run scripts/check-gui`,
  `lune run scripts/check-story`, `lune run scripts/check-season`, `lune run scripts/check-models`,
  `selene src`, `stylua --check src` (`stylua src` fixes what it finds) and
  `rojo build -o /tmp/check.rbxl`.
  When `Config/Cast.luau` changes, also run `python scripts/cast-check.py`. It asks Roblox's catalog
  about every item the cast wears, so it needs the network and isn't one of the Lune checks.
- **Models: the manifest pipeline.** New and replaced models go through one list,
  `assets/manifest/models.json`, instead of a spec for ChatGPT. The steps are in
  [assets/README.md](assets/README.md) ("Adding or replacing a model") and the design is in
  `docs/superpowers/specs/2026-10-28-model-overhaul-design.md` (the plan is next to it, in
  `docs/superpowers/plans/`). Where the pieces live:
  - `assets/manifest/models.json`: one entry per model, from the Creator Store, Blender or kept.
  - `scripts/generate-import.py` renders `scripts/ImportStoreModels.luau` from
    `scripts/ImportStoreModels.template.luau` and the manifest. `scripts/test_generate_import.py`
    tests the validator and that the committed script is up to date.
  - `scripts/export-models.luau` writes `assets/<Folder>/<Id>.rbxm` from Studio's staged models, and
    `scripts/check-models.luau` is the gate on the result.
  - `scripts/serve-studio.py` and `scripts/studio/` stand each current model beside its Store
    candidates in Studio, so you can choose (the README there says how).
  - The cast: `src/shared/Config/Cast.luau` (who wears what), `src/server/Services/CastService.luau`
    (builds the rigs), `src/shared/CastRig.luau`, `src/shared/NpcAnimator.luau` (the poses) and
    `scripts/cast-check.py`.
  - The grass art: `src/shared/Config/GrassArt.luau` (the four image ids),
    `scripts/make-grass-tufts.py` (draws the tuft sheet), `scripts/upload-grass-art.py`,
    `src/client/GrassPaint.luau` and `src/client/Controllers/GrassController.luau`. The TurfKing
    T-shirt image comes from `scripts/make-turfking-tee.py`.

  To run a batch:
  1. Pick the ids (the order is in the spec, section 6; TODO.md says which are left) and, if you
     need to choose, run the `scripts/studio/` lineup.
  2. Add or edit their entries in the manifest (the fields are listed under "The manifest entry"
     in `assets/README.md`). Run `python -I scripts/generate-import.py`, then
     `python -m unittest scripts/test_generate_import.py`.
  3. In Studio, open a scratch place (not the Team Create game) and paste
     `scripts/ImportStoreModels.luau` into the command bar. It stages each model in
     `ServerStorage.ModelImport` and prints `ok <id> ...` or `FAIL <id> <reason>`. Fix every `FAIL`
     in the manifest and run it again. The one-liner in `scripts/studio/README.md` fetches only
     `lineup.lua` and `camera.lua` from that folder, so it doesn't run the importer: paste this one.
  4. Save the place with Ctrl+S (a scratch place that was never saved needs Save to File) and run
     `lune run scripts/export-models <place.rbxl> --overwrite`. Or right-click
     `ServerStorage.ModelImport`, Save to File, and pass that `.rbxm` instead. Then delete
     `ModelImport` from the place.
  5. Run `lune run scripts/check-models`, then look at the new models in Play (grips in first
     person, truck loading, the house's porch, scale next to the kit).
  6. Commit the manifest, the generated importer and the `.rbxm` files together. Each batch is
     its own PR.
- **ChatGPT/Codex makes the art, and made the mesh packs the older models came from.**
  - Write a self-contained spec as `alphainstructions/instructionsN.md`; **N is one past the
    highest number already in that folder**.
  - Push it to `main`. A push touching `alphainstructions/` triggers the "Work on Alpha
    instructions" GitHub Action (Codex, with OpenAI billing). You can also point ChatGPT at the
    file yourself.
  - Models come back as glTF plus `model_manifest.json` in `model-source/HighPoly/NN_*`.
- **Importing mesh packs** (the older route, for packs that arrive like that):
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
- **Fluid mowing needs Allow Mesh / Image APIs, in Studio too.** Lawns are drawn into EditableImages
  (a turf image and a few grass shells, see `GrassController.luau` and `GrassPaint.luau`), and creating
  one throws until the toggle is on: Experience Settings → Security, for a published game and for
  Studio alike. Until then, or when a phone's image memory runs out, the client draws the plain-part
  fallback instead (`GrassFallback.luau`: a flat plate with blocks of tall grass, no stripes, no
  "Show what I missed" button) and logs one `[Grass]` warning. The game plays and finishes the same on
  it, but it isn't the look to judge or screenshot, and the game must never assume the toggle is on.
  To force the fallback for a test with the toggle on, set `useFallback = true` in the local near the
  top of `GrassController.luau` (and put it back). `lune run scripts/check-mowing` is the fast check
  for the mowing math (cells, sweeps, snips, shade, the needed-count arithmetic, line clipping): it
  needs no Studio. The design is `docs/superpowers/specs/2026-10-28-fluid-mowing-design.md`.
- **A Store model that goes blank in the game** means its creator deleted the mesh or Roblox
  moderated it: the game doesn't own Store meshes, and `check-models` can't see it, because the
  file still has its parts. Find the entry by id in `assets/manifest/models.json` (it keeps the
  asset id, name and creator), choose another candidate and run a batch for that id.
- **The story's people need the catalog.** `CastService` builds them with
  `Players:CreateHumanoidModelFromDescription` when the server starts, so a catalog item taken down
  (or Roblox being unreachable) leaves that person as a block placeholder and logs a warning.
  `python scripts/cast-check.py` finds the item.
