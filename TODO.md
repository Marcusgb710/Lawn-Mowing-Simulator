# What's left — Lawn Mowing Simulator

Last updated: 2026-10-18

## Done so far

- **Rojo is set up and running.** `rokit install` pulled the project's tool versions (Rojo 7.7.1,
  Selene 0.31.0, StyLua 2.6.0). The Studio plugin was updated from 7.4.4 to 7.7.1 to match the
  server (a 7.4 plugin can't talk to a 7.7 server: "Can't parse JSON"). `rojo serve` is running and
  Studio is connected.
- **The game is published** as "Lawn Mowing Simulator" under **Big Dink Studios** (universe
  10771693515, place 73083404631437). It's private, with Team Create on. The old local copy at
  `~/Documents/LawnMowingSimulator.rbxl` is out of date; open the game from Roblox instead.
- **The mobile kit is uploaded to Roblox.** All 60 meshes and the shared PBR textures went up
  under **Big Dink Studios** through File → Import 3D (scale unit: meters). The importer also
  created a Model asset named `LM_Mobile_Asset_Workshop` in the group's inventory.
- **The kit is in the game, in git and synced by Rojo:**
  - `assets/Kit/*.rbxm` → `ReplicatedStorage.Assets.Kit`: all 34 kit assets, scaled to real size,
    anchored, no collision, pivot on the ground under the asset, facing -Z (the front).
  - `assets/Tools/*.rbxm` → `ReplicatedStorage.Assets.Tools`: the kit equipment now replaces six
    placeholder shop tools.

    | Item id | Kit model |
    | --- | --- |
    | `GasPushMower` | `Mower_Push_21in` |
    | `RidingMower` | `Mower_LawnTractor_42in` |
    | `ZeroTurnMower` | `Mower_ZeroTurn_52in` |
    | `ElectricTrimmer` | `Trimmer_Battery` |
    | `GasTrimmer` | `Trimmer_Petrol` |
    | `OldRake` | `Prop_Rake` |

    Checked in Play mode: the push mower is held by its handlebar, upright, in front of the player.
    The trimmer is held at an angle with the head out front. Rack and truck-bed displays stand
    upright on the ground.
- **Fixed how tools are held, placeholders included.** The code assumed a held handle's +Y points
  forward. It actually points up, with the handle's front (-Z) forward, so every placeholder tool
  was held standing on end above the player's head. `Placeholders.tool` now turns the grip and
  `Assets.toolDisplay` uses the grip as-is, so placeholders look the same on the rack but are held
  correctly. `Assets.toTool` also prefers a part named `Handle` over `PrimaryPart`, because Rojo's
  MeshPart sync drops `PrimaryPart`.
- **Kit pipeline scripts** (in `scripts/`):
  1. `OrganizeLawnKit.luau`: paste into the Studio command bar after a fresh Import 3D of
     `LawnMowing_AllAssets.gltf`. It flattens, scales and grounds the kit into
     `ServerStorage.LawnKitExport`. Save the place afterwards.
  2. `lune run scripts/export-kit` writes `assets/Kit/*.rbxm` from the saved place. Delete
     `ServerStorage.LawnKitExport` in Studio afterwards.
  3. `lune run scripts/build-kit-tools` builds `assets/Tools/*.rbxm` from `assets/Kit`. To tune a
     grip or add a tool, edit `TOOLS` in that file and re-run; Rojo syncs it right away.

  Lune 0.11 is installed globally with Rokit (`~/.rokit/bin/lune`).

## Models

Every item now has a real model. ChatGPT built mesh sources from `alphainstructions/instructions1.md`
to `instructions23.md`, kept in `model-source/`. They were imported into Studio as Big Dink Studios
and exported to `assets/` (85 models: 67 tools, 7 props, 4 buildings, 4 trucks, 3 trailers).

To re-import or add models: in Studio use File → Import 3D with Creator Big Dink Studios, Scale Unit
Meter and **World Forward: Back**, because these packs are authored with their front at −Z. Then
paste `scripts/PrepareChatGPTModels.luau` into the command bar, save
`ServerStorage.ModelImport` with right-click → Save / Export → Save to File, and run
`lune run scripts/export-models <file>.rbxm`.

- [ ] Visual review. These are simpler low-poly models than the original kit; the trucks
      especially are boxy. Check grips, scale and colors in Play and send weak ones back to
      ChatGPT with notes.
- [ ] `RidingMower`-style seat offsets for the new ride-on and stand-on machines (Phase F).

Not uploaded yet: `Textures/Lawn_Uncut_Color.png`, `Textures/Lawn_Mown_Color.png` and
`Textures/Soil_Color.png` from the kit. They're 512×512 tiling lawn and soil color maps, and the
glTF doesn't reference them, so the importer skipped them. Upload them with **Asset Manager → Bulk
Import** (as Big Dink Studios), then use them as MaterialVariants or Textures on the lawn tiles.

## Code work to use the rest of the kit

Yards (`src/server/Services/LawnService.luau`) now use the kit, falling back to blocks if
`Assets.Kit` is missing:

- [x] **Grass**: the server only tracks tile state (a string attribute on each job site's
      `Grass` folder, see `src/shared/LawnGrid.luau`). Each client draws it
      (`src/client/Controllers/GrassController.luau`): one `Grass_Tall_A/B` clump per tile, swapped
      for `Grass_Short_A/B` on a striped turf plate when mowed, `_LOD` clumps beyond 70 studs, and
      nothing at all for lawns more than 200 studs away. Still to do: use the lawn texture for
      distant ground once it's uploaded.
- [x] **Weeds**: random `Weed_*` models, scaled up 1.6–2.2× (life-size weeds are tiny next to a
      player), shrinking toward the ground as they're whacked. `OriginalSize` is set too.
- [x] **Hedges**: `Shrub_Rounded` stretched to the overgrown size and shrunk to the trimmed size.
      Kit shrubs have no collision; block hedges still do.
- [x] **Edges**: `Curb_Concrete_1m` runs along the sidewalk and driveway, with a
      `Grass_EdgeStrip_1m` per tile flopping over it that the edger cuts away.
- [x] **Leaves**: a stretched `Grass_Clippings_Pile` stands in for a leaf pile and leaves a
      `Prop_YardWasteBag` behind when it's raked up.
- [x] **Yard decoration**: a cedar fence down the left side, a wheelie bin and hose by the
      driveway, rocks in the flower bed and cones around the parked truck.
- [ ] **Business plot decoration**: `Paver_Concrete_40cm`, `Prop_FuelCan_5L`, `Prop_Shovel` and
      friends around the shed, tool rack and truck.
- [x] **Moving parts**: `Assets.toTool` gives every `__Wheel*`, `__CutterRotor*` and `__Spool`
      part a Motor6D (with a `Spin` attribute) instead of a rigid weld.
      `src/client/Controllers/ToolFxController.luau` rolls wheels with the player's speed and
      spins blades and spools while the tool's `Working` attribute is on. The steering wheel and
      lap bars stay put.
- [x] **Riding mowers**: `RidingMower` and `ZeroTurnMower` have a `ride` entry in `Items.luau`.
      They aren't held: their handle becomes `RideRoot`, they're welded so the seat is under the
      player, R15 players are lifted (HipHeight) so the wheels touch the ground, and the player's
      own sit animation plays while riding. Still to check in Studio: tune `ride.seat` in
      `Items.luau` until the player sits on the seat, and see how R6 avatars look (they aren't
      lifted).
- [ ] **Grip polish**: push and walk-behind machines are now held so their wheels touch the
      ground, worked out from the player's shoulder height (phase B); check it in Studio. The
      trimmer head still floats about 1.3 studs, because the tool-hold pose keeps the hand at
      shoulder height. Lower the trimmer grips in `scripts/build-kit-tools.luau`, or add a hold
      animation.

## Design phases (docs/GAME_DESIGN.md)

One PR per phase, each stacked on the one before. Every phase still needs a Studio playtest.

- [x] **A: tool fit, hinted jobs, pay by customer preference.** Merged.
- [x] **B: storage per building, truck space, shop gating, selling.** To check in Studio: how tools
      hang and stand on the placeholder fixtures (`MOUNT_HEIGHT` in
      `src/server/BusinessStorage.luau`), push mowers' height in the hand, the truck bed with many
      tools, the plot with an Equipment Yard. New model id: `StorageShelf` (needs a spec).
- [x] **C: homeowner garden jobs, gloves, the Guide and the first-job coach.** To check: the side
      garden plots (`GARDEN` in `LawnService.luau`), dandelions in the lawn, the coach banner on a
      phone.

## Before release

- [ ] Turn on *Game Settings → Security → Enable Studio Access to API Services* so progress saves
      when testing in Studio. The game is already published under Big Dink Studios.
- [ ] Make the experience public when it's ready to play.
- [ ] Set max players to 12 or fewer (Game Settings → Places). The placeholder town has 12 plots.
- [ ] **Test on a real phone.** Prompts and tools already use ProximityPrompts and
      `Tool.Activated`, so touch should work, but hold-to-use tools and the carry/load flow need
      checking. Profile frame rate with grass on screen. The kit makes no device FPS promise.
- [ ] **Sounds**: the kit has none. Mower engine, trimmer, rake and blower, cash register, UI
      clicks.
- [ ] **Animations**: pushing and holding poses for mowers and trimmers.
- [ ] **UI art**: shop and hotbar icons for every item, a game icon and thumbnails.

## Known quirks

- While Rojo is connected, Studio's Output fills with
  `[Rojo-Warn] Ignoring change for instance … as it is unknown to Rojo` every time you change
  something. These come from the MeshPart models Rojo syncs through its fallback path, and they're
  harmless.
- Rojo drops `Model.PrimaryPart` on synced MeshPart models, so code shouldn't rely on it for kit
  assets. Use the pivot, which is set, or find parts by name.

## Daily workflow reminder

```sh
cd ~/Desktop/"Lawn Mower"/Lawn-Mowing-Simulator
rojo serve
```

Then in Studio, open "Lawn Mowing Simulator" from Roblox (Big Dink Studios) and click Plugins →
Rojo → Connect. It's a Team Create place, so changes made directly in Studio save to the cloud.
