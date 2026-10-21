# What's left — Lawn Mowing Simulator

Last updated: 2026-10-21

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
`lune run scripts/export-models <file>.rbxm` (add `--overwrite` to replace existing models).

- [x] **High-poly pass (instructions 24–34): imported.** All 115 models are in `assets/` (85 replaced,
      30 new, including the new `Decorations` folder). Still to check in Play: the walk-in buildings,
      truck doors and tailgates, desks, boxes and decorations.
      How it was done: ChatGPT's 115 models are on the
      `codex/high-detail-models` branch. The 11 combined files are copied to
      `~/Desktop/LawnModelsImport/HighPoly/ALL` (textures in `../Textures`), and
      `scripts/PrepareChatGPTModels.luau` is generated for them by `scripts/generate-prepare.py`.
      Besides the Handle/Root and bed markers, it now adds the manifests' marker Attachments with
      their attributes, each part's collision, and hinge pivots for doors, tailgates, ramps and
      flaps. Import all 11 at once, run the script, save ModelImport, then
      `lune run scripts/export-models <file>.rbxm --overwrite`.

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
      ground, worked out from the player's shoulder height (phase B); check it in Studio. In
      first person every tool is posed for the view (trimmer heads on the ground), but other
      players still see the trimmer head float about 1.3 studs, because the tool-hold pose keeps
      the hand at shoulder height. Lower the trimmer grips in `scripts/build-kit-tools.luau`, or
      add a hold animation.

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
- [x] **D: serious gardening (digging, hauling, feeding, spraying).** To check: hauling from the
      driveway pile to the bed, how often one-wheeled barrows tip (`TIP_CHANCE` in
      `LawnService.luau`), the fertilizer dusting on big lawns.
- [x] **E: maintenance (fuel, tires, blades, line).** To check: wear rates (`Maintenance.Wear`),
      the workbench prop on each building (the menu is now hands-on, see Immersion 3).
- [x] **F: pro equipment and turf renovation.** To check: standing on stand-on machines
      (`ride.seat` in `Tools.luau`), the tow-behind aerator hitched behind a ride-on, tight lawns
      with trees, the renovation overlays and the soil reading in the HUD.
- [ ] **Camera: first person.** To check in Studio, R15 and R6:
      - the arms (`ArmsController.luau`): sizes and colors, elbows bending the right way, hands
        on the handlebar and up the rake's shaft, the blend up and down;
      - each kind of tool in view (`MACHINE_AHEAD`, `LONG_*`, `REACH_*`, `HAND_POSE`): nothing
        clipping the camera, rake and trimmer heads on the ground, backpack tools;
      - the view from each ride-on seat and stand-on platform, and where the hands sit on the
        controls (`RIDE_RIGHT`, or add `GripLeft` / `GripRight` attachments to the models);
      - carried tools in view at the business;
      - the mouse freeing while menus are open, Left Alt, the keys, and the dot;
      - head bob and engine shake strength, and motion sickness on a phone.
- [ ] **Immersion 1: walk-in buildings, truck at the door.** Waiting on the new building, truck
      and trailer models (instructions24). When they're in, check in Studio:
      - fixtures on every `Mount`, tools on their slots, floor spots and bays inside;
      - walking (and pushing a mower) in through every door, and no walking through walls (keep
        wall meshes on Default or PreciseConvexDecomposition collision, set before saving);
      - the truck on `TruckParking` with its rear at the door, the tailgate, ramp and rear door
        opening and closing (hinge pivots), the ramp reaching the ground;
      - interior lights on phones.
- [ ] **Immersion 2: look-at loading.** To check in Studio:
      - aiming at tools on every fixture, at the bed (the ghost on the right cells, green or red),
        and at free spots;
      - the E key and the phone button, and R on the bucket;
      - tools lying well on their cells, and the settle;
      - driving a ride-on up a ramp and parking it on a bay;
      - two players loading one truck;
      - fill in the sound ids in `src/shared/Sounds.luau`.
- [ ] **Hub 1: job computer and deliveries.** Waiting on the desk and box models (instructions33).
      To check in Studio:
      - stepping up to each desk and the camera easing in to `ScreenView`, then back;
      - the apps inside the monitor on PC and on a phone;
      - leaving by walking away;
      - boxes standing at `DeliverySpot`, their flaps and crate front swinging the right way, and
        the tool coming up into your hands;
      - boxes coming back after a rejoin.
- [ ] **Hub 2: driveway and leaving from the truck.** To check in Studio:
      - the 90 × 90 plots and the town's spacing;
      - the driveway and where the truck parks;
      - the driver's door swinging out and back;
      - the view from `DriverSeat` and the other seats;
      - the pull-out into the street and the pull-in;
      - nothing standing on the driveway or the front lawn.
- [ ] **Immersion 3: hands-on maintenance.** To check in Studio:
      - setting a mower down at the workbench's `ServiceSpot` and a pair of pruners in the vise;
      - holding E to pour, pump, plug, wind and file, on PC and phone (hold the button);
      - the blade off (the mower on its side), the grinder's sparks, the blade back on;
      - a wheel off for the spare;
      - the tailgate on a job: supplies by the truck, taking one and putting it back;
      - sputtering smoke, sagging and flat tires and a bare spool on the kit tools;
      - ragged grass after mowing with a dull blade.
- [ ] **Hub 3: your own lawn and curb appeal.** To check in Studio:
      - the lawn on each plot, its grass drawn like a job's, and the edge along the right sides;
      - mowing, edging, trimming and raking it with tools straight off the wall, on PC and phone;
      - tools held at the shop looking right (push mowers on the ground, arms on the handles);
      - regrowth over a long session, and the lawn coming back the same after a rejoin;
      - the neighbor's tip, the HUD's curb appeal and the "Curb appeal" pay line;
      - frame rate with your lawn and a neighbor's in view.
- [ ] **Hub 3b: decorations.** Waiting on the decoration models (instructions34). To check in
      Studio:
      - ordering from the Decorations tab, solo and in a crew (it's the leader's);
      - opening a decoration box and placing it: the ghost, turning, red where it can't go;
      - fence sections, edging, paths and beds snapping end to end;
      - picking one up and moving it, and a building upgrade boxing what's in the way;
      - lamps, the fire pit, the fountain's water, sitting on the bench and patio chairs, the
        mailbox door and flag, the windmill's sails;
      - trimming a shaggy shrub with a hedge tool, and it growing back;
      - curb appeal going up as the yard fills (and leveling off);
      - everything with block placeholders, and on a phone.
- [ ] **Starting out: grass shears, junk in the grass, a 5-minute first job.** To check in Studio:
      - a brand-new save starts with only the grass shears, already in the truck, and the coach
        talks about snipping and picking up junk; an old save keeps its reel mower and gets the
        shears too;
      - snipping on PC (click, and hold for a steady rhythm) and on a phone (tap the world, and
        hold the Snip button): one tile at a time where the dot is, 6 snips a tile, the grass
        getting shorter every couple of snips, nothing out past about 6 studs, weeds too;
      - the shears in view (`SNIP_POSE`, `SNIP_JAB` in `ArmsController.luau`) on PC and a phone,
        R15 and R6: not clipping the camera, blades toward the grass, the jab easy to read;
      - the junk on the first job: 4 pieces, hidden but findable; the look-at hint and E / the
        button picking them up; "There's a stick in the grass there" with the shears and the reel
        mower jamming; the tracker's "Pick up junk in the grass" row;
      - a gas mower over a rock: the THUNK message, the 1.5 s stall, "Cut is getting ragged", the
        bits flying; the pay breakdown with junk left behind or chewed up;
      - time the first job as a new player: about 5 minutes (tune `snip` in `Tools.luau` and
        `QuickMow` in `Jobs.luau`), and a little over a minute with the reel mower;
      - a couple of pieces on your own lawn, and more turning up as it grows back;
      - the junk placeholders (`Placeholders.luau`) look like what they are, and ids for the new
        `Snip` and `BladeHit` sounds in `Sounds.luau`.
- [ ] **Premium: Robux purchases.** Needs each game pass and developer product made on the
      Creator Dashboard and its id put in `src/shared/Config/Premium.luau` (until then the shop
      shows "Soon"). To check in Studio, where purchases are free test purchases:
      - a pass turns its perk on (Diamond Blades: blades stop dulling);
      - a premium tool needs the base tool owned first, then shows its finish in hand, in the
        truck, on the wall, in its delivery box, and set down at the workbench or in the vise;
      - a paint job repaints the parked truck, the drive cutscene truck and the truck at the
        job, and "Factory paint" puts it back;
      - buying the same product twice doesn't break anything, and purchases survive a rejoin.
      - Still to do on the Creator Dashboard (as of 2026-10-20): put the four passes on sale at
        199 / 149 / 99 / 99 (they exist but are offsale), and create the eight products that
        still have `productId = 0`: Chrome Leaf Blower (149), Stealth Zero-Turn (799), Midnight
        Black, Forest Green and Sky Blue (49 each), Stealth Wrap (99), Chrome Wrap and Gold Wrap
        (149 each), with Managed pricing off like the others.

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
