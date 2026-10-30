# What's left: Lawn Mowing Simulator

Last updated: 2026-10-29

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
- **Fluid mowing** (cells, swaths, EditableImage shells, fallback, engine audio): PR pending. The
  list of what to check is **Fluid mowing: to check**, below.

## Models

Every item now has a real model. ChatGPT built mesh sources from `alphainstructions/instructions1.md`
to `instructions23.md`, kept in `model-source/`. They were imported into Studio as Big Dink Studios
and exported to `assets/` (85 models: 67 tools, 7 props, 4 buildings, 4 trucks, 3 trailers).

The model overhaul (design: `docs/superpowers/specs/2026-10-28-model-overhaul-design.md`) has
replaced the first four batches with free Creator Store models, fitted by the manifest in
`assets/manifest/models.json`: 18 tools (the mowers, trimmers, blowers, barrows, hedge shears,
spreader, sprayer and gas cans), the 4 trucks, the 3 trailers and the customer's house. Another 13
are recorded as kept. The story's people are Roblox avatars now (`CastService`), and the lawn is
ready for its texture and tufts. What is left is under **Model overhaul: what is left**, below.

To add or replace a model, use the manifest: `assets/README.md` ("Adding or replacing a model")
has the steps, and HANDOFF.md has the short version. The older route for ChatGPT's mesh packs
(File → Import 3D with Creator Big Dink Studios, Scale Unit Meter and **World Forward: Back**, then
`scripts/PrepareChatGPTModels.luau`) is kept under "Importing mesh packs" in `assets/README.md`.

- [x] **High-poly pass (instructions 24–34): imported.** All 115 models are in `assets/` (85 replaced,
      30 new, including the new `Decorations` folder). Still to check in Play: the walk-in buildings,
      truck doors and tailgates (the Store trucks have none), desks, boxes and decorations.
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
      ChatGPT with notes. (The models the manifest lists as Store models are no longer these;
      this is for the rest.)
- [ ] `RidingMower`-style seat offsets for the new ride-on and stand-on machines (Phase F).

The kit's `Textures/Lawn_Uncut_Color.png`, `Textures/Lawn_Mown_Color.png` and
`Textures/Soil_Color.png` are 512×512 tiling lawn and soil color maps. The glTF doesn't reference
them, so the importer skipped them; `scripts/upload-grass-art.py` uploads them with the tuft sheet
and `src/shared/Config/GrassArt.luau` holds their ids (see **Before release**).

## Code work to use the rest of the kit

Yards (`src/server/Services/LawnService.luau`) now use the kit, falling back to blocks if
`Assets.Kit` is missing:

- [x] **Grass** (fluid mowing, PR pending): the server keeps the lawn as a ledger of 1-stud cells
      (`src/shared/LawnGrid.luau`, `LawnService.luau`) and logs every sweep of a mower's deck as a
      swath (`src/shared/Swath.luau`). Each client paints the swaths into EditableImages
      (`GrassController.luau`, `GrassPaint.luau`): a turf plate with 6 grass shells on PC and 4 on
      phones, and nothing at all for lawns more than 200 studs away. Still to do: use the lawn
      texture for distant ground once it's uploaded. Without EditableImages (Allow Mesh / Image
      APIs is off, or a phone's memory is spent) `GrassFallback.luau` draws plain parts instead.
      The kit's `Grass_Tall_*` and `Grass_Short_*` clumps are no longer used for lawns.
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
      - facing the shop after a reset at the business, after a job and after joining or leaving
        a crew, and facing the house on arriving at a job and after a reset there;
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
        hold the Snip button): a patch of grass at a time where the dot is (the cells within a
        stud of it, all cut at once), nothing out past about 6 studs, weeds too (12 snips each);
      - the shears in view (`SNIP_POSE`, `SNIP_JAB` in `ArmsController.luau`) on PC and a phone,
        R15 and R6: not clipping the camera, blades toward the grass, the jab easy to read;
      - the junk on the first job: 4 pieces, hidden but findable; the look-at hint and E / the
        button picking them up; "There's a stick in the grass there" with the shears and the reel
        mower jamming; the tracker's "Pick up junk in the grass" row;
      - a gas mower over a rock: the THUNK message, the 1.5 s stall, "Cut is getting ragged", the
        bits flying; the pay breakdown with junk left behind or chewed up;
      - time the first job as a new player: about 5 minutes (tune `SnipRadius` in `GameConfig.luau`
        and `QuickMow` in `Jobs.luau`; GAME_DESIGN.md's "The first job" works it out at about
        4 1/2), and a little over a minute with the reel mower;
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
      - All 4 passes and 13 products are made and on sale at their catalog prices (2026-10-21).
        `scripts/premium-setup.py` creates or re-prices anything added to `Premium.luau` later.

- [ ] **Story 1: story state (docs/STORY.md).** To check in Studio, with API access on so it
      saves:
      - a brand-new save gets the "Intro" scene queued (it plays once the dialogue box is in),
        and an old save gets "WelcomeBack" instead and lands in act 2 or later;
      - the texts after the first and second jobs ("Grandma June: Saw you finish Edna's lawn...",
        "Bridge Club: Is the grandchild free Thursday?") show as toasts, and June's critiques
        after later act 1 jobs;
      - buying the Reel Push Mower starts act 2 (its scene plays, see Story 2) and Chad texts; a
        gas mower (or a crew job, or level 4) starts act 3 and Sam texts; curb appeal 75 starts
        act 4;
      - the starter job on the board is always Mrs. Alvarez's;
      - all of it is still there after a rejoin, and nothing fires twice;
      - `lune run scripts/check-story` passes after any change to `Story.luau`.
- [ ] **Story 2: the dialogue box, the intro, June and Gloria's house.** To check in Studio, on
      PC and on a phone (Device emulator, landscape):
      - a brand-new save: the intro starts right after the title card lifts, with the camera on
        Gloria's house and her bubble, then on June on her porch; the "New tool" card on the
        shears line; the coach's "Edna's front lawn..." banner only once it's over;
      - Skip ("Skip intro" on PC), clicking anywhere, Space and Enter, tapping on a phone; a line
        typing out finishes on the first click; nothing walks while it's up;
      - the HUD, hotbar, dot and look-at hints hidden during it, all back after, and the camera
        back in first person facing the shop;
      - the box on a short phone screen: portrait, name tag, text and "Tap to continue" not
        overlapping, nothing under the notch, Skip clear of Roblox's own buttons;
      - leaving mid-intro and rejoining plays it again; finishing it doesn't;
      - buying the reel mower, then walking away from the computer, plays act 2's scene;
      - June on her rocker beside every building (Shed to Equipment Yard), clear of the truck,
        driveway, delivery spot and decorations; sitting in the chair; E on her says a line in
        a bubble over her hat, taking turns about the goal and Gloria;
      - Gloria's house across the south street with her on the porch, her bubble readable from
        the intro's shot, and the fence and shrubs standing right (real decoration models);
      - the art (portraits, box, bubbles) once it's uploaded: see **GUI overhaul** below.
- [ ] **Story 3: the Messages app.** To check in Studio, on PC and on a phone:
      - after the first job: toasts for Mrs. Alvarez's and June's texts at the job site, and a
        badge on the computer's Messages buttons back at the shop;
      - opening Messages: threads newest first with faces, last lines and unread counts; the
        open thread's grey and green bubbles wrapping at a sensible width; the Bridge Club's
        texts saying who sent them; opening a thread clears its count, and it stays cleared
        after a rejoin;
      - the goal card: "Buy the Reel Push Mower $66 / $150" filling as money comes in, then the
        Gas Push Mower, then curb appeal toward 75;
      - on a phone (under 560 px): the list, tapping into a thread, the back button, the goal
        card under both, and all five taskbar buttons fitting;
      - the taskbar's open app in green; no toast while at the computer or during a scene;
      - the inbox staying at 60 texts at most after many jobs.
- [ ] **Story 4: TurfKing and Gloria's yard.** To check in Studio, with 2 players in different
      acts (Test → Clients and Servers) so each sees their own:
      - Gloria's yard in act 1 (shaggy patches, dandelions, shaggy shrubs), acts 2-3 (stripes,
        edges along the path, mulch beds, the TurfKing sign by the walk) and act 4 (checks,
        topiary, the fountain running, path lights, the flamingo V), swapping as soon as the act
        changes, and nothing poking through the fence, path, drive or porch;
      - TurfKing's truck from act 2: purple, the gold stripe and crowns on the doors and the
        light bar sitting on the real HeavyDutyPickup model (`Assets.turfKingTruck`), parked in
        her drive facing the street, with Chad beside it;
      - the intro: the truck backing into her drive on the first line, then gone after;
      - Gloria's and Chad's porch remarks from your shop (every 35-55 s within about 130 studs),
        readable, and none while a scene, a job or the computer is up;
      - at the computer in act 2+: a card flipping to "Taken by TurfKing" a few seconds in (the
        stamp landing), "Taken" not accepting, Chad's text and the toast; never the starter job;
        not again for 3 jobs; the other player's board unchanged;
      - a Quality job with a 90%+ finish in act 2+: the customer's text, the "Won from TurfKing"
        line in the pay breakdown, and only once per customer;
      - the real models dropping in (`Assets/Story/<id>`) with no code change once they're
        imported (instructions37): the house, the three yards, the porch deck, the rocker and the
        sign. Gloria and Chad are `CastService` rigs, not files, and the truck is the heavy-duty
        pickup in the purple livery.
- [ ] **Story 5: the Best Yard contest.** To check in Studio, with API access on so it saves (to
      get to act 4 quickly, raise curb appeal to 75 or give yourself level 10's xp), on PC and on
      a phone:
      - June's "Judges are in town" text when act 4 starts, her porch lines about the contest, and
        the goal card's "Beat Gloria's 88 on judging day" with **Call the judges**;
      - pressing it: your text and June's reply, the computer put away, then the judging scene:
        the "Yard" shot over your own lawn with both judges walking it, then Gloria's yard with
        them walking hers, Gloria's bubble, June going quiet, the 1994 line;
      - the results screen after it: the title, both cards (the winner's outline), the trophy and
        "June's 31st win", the four bars filling, the chips, Gloria's line and Collect, scaled to
        fit on a phone held sideways with Collect still easy to tap; confetti on a win;
      - a win: $2,500, the trophy's box at the shop (placing it, its cup shining, Send back
        refused), the Small Office at half price in the Business app (and full price again once
        bought), and the ending (June scratching the name, "Fine. FINE.");
      - a loss: Gloria's gloating, June's "Next summer...", the goal card counting the days to
        the next Saturday, June's text when the judges are back;
      - leaving between calling the judges and collecting, then rejoining: the scene, then the
        same result;
      - the next summer after a win (judging day is the next Saturday), with Gloria at 90, the
        shorter judging scene and `ContestWinAgain`;
      - the Best Yard Trophy isn't in the Decorations tab;
      - tune the scoring (`Config/Contest.luau`) once real yards are judged. The contest's art
        (title, ribbon, trophy, striped bars, confetti) is wired: see **GUI overhaul** below.

## GUI overhaul (instructions 38)

ChatGPT's "Maple Grove Summer" GUI art is wired into the code. Until its 312 images are uploaded
every id in `src/shared/Config/GuiArt.luau` is `""` and each piece is drawn with plain frames in the
new palette and fonts (DenkOne headings, Nunito text). To switch the art on, see HANDOFF.md
("GUI art from ChatGPT"): upload, list the ids in `art-source/GUI/uploaded.json`, run
`python3 scripts/gui-art-ids.py`, then `lune run scripts/check-gui`.

- [ ] **Before the upload: to check in Studio** (PC, and a phone in the Device emulator, landscape):
      - the new fonts everywhere: DenkOne headings and Nunito text; nothing cut off, especially the
        Messages app's names, its goal card and the dialogue box (both measure their text);
      - the HUD: money, level and xp bar top left; the menu buttons with T/G/C badges on the left
        of each; Grandma's sticky note under them once the story's goal arrives ("Buy the Reel Push
        Mower $66 / $150"); curb appeal top right; the job tracker under it (to-dos with bars, the
        timer, damage, Cancel); on a short phone screen both columns shrink to fit, and curb
        appeal hides while a job's on;
      - the pay breakdown after a job: the lines add up to what you earned (crew jobs show your
        share), it stays through the drive home, frees the mouse, and Nice! closes it;
      - Level Up! and New Tool! (buy a tool) popping in the middle, over the shop computer too;
        Payday! after collecting the Best Yard prize; the act title at the start of acts 1 to 4;
      - the look-at prompt under the dot ("[E] Take  Reel Push Mower", red when it won't fit), the
        dot going green on something usable and red when blocked, and the decoration placing
        prompt;
      - buttons in every menu: green (Buy, Take job), red (sell, cancel), grey (locked, owned),
        gold for Robux, with shop prices on yellow plant tags; the shop and Guide tabs, the selected
        one green; the Back and X buttons;
      - toasts, including "New text from Grandma June";
      - the shop computer: the taskbar's money on a wide screen (hidden on a phone), all five
        taskbar buttons fitting on a phone, the open app's button green;
      - dialogue: the straw name tag in capitals, the portrait circle, the round progress dots,
        Skip, Continue, the scenes' faces for each mood (initials until the portraits are up);
      - the Best Yard results screen at its usual size on PC and a phone.
- [ ] **After the upload: to check in Studio**, PC and phone:
      - **9-slices:** windows, cards, buttons, tabs and prompts keep their round corners at every
        size (corners shrink on thin buttons and short cards rather than overlapping); buttons sink
        to their `_Pressed` art while held; nothing draws over a button's words;
      - **bitmap fonts:** the money counter, the job timer, the pay breakdown total, the Jobs app's
        pay and the contest scores drawn from the atlases (outline under a cream/yellow face),
        sharp at their size, kerned and centred; a long amount shrinks to fit; anything the fonts
        can't draw falls back to the live font;
      - **HUD:** HudPanel transparency over bright grass; glyphs (money, level, curb appeal, truck,
        guide, crew, timer, damage, flags and checks) at 16 to 30 px; the sticky note's ink text;
        menu buttons' key badges sitting in the MenuButton's slot;
      - **reticle and hold ring:** the three dots at 26 px; the ring sweeping clockwise from the top
        while you hold E on a tool at the workbench, and gone when it's done or you let go;
      - **phone buttons:** Pick up, Talk, Place and the rest with their glyphs and words under
        them, greyed when they won't work; Snip; the decoration buttons with glyphs;
      - **shop computer:** the wallpaper, the five app icons on the desktop (and their unread
        badge), the taskbar's icons; item pictures on every Orders, Business, Premium and Sell card,
        in the Truck menu and the Guide; the pass circles; the Taken by TurfKing stamp;
      - **story:** portraits in the ring for every mood in the scenes, the dialogue box and name tag,
        the letterbox's soft edges, bubbles and their tails, the Messages bubbles, thread cards,
        unread badges and goal card;
      - **big moments:** the Job Complete, Level Up, New Tool, Payday and act wordmarks at their
        size; the contest's ribbon, title, trophy, Winner / So Close, striped bars and confetti;
      - **performance:** frame rate with the HUD up on a phone (the timer reuses its glyphs).
- [ ] **The last pieces (price tags, stamps, tiers, condition, crown, sparkles): to check in
      Studio**, PC and a phone held sideways:
      - **shop cards:** the price on its plant tag (`PriceTag`, tilted a little) over a green Buy or
        Restock button, shaded when you can't afford it or it's locked; tag and button fitting the
        card's right side on a phone; the tier badge (one, two or three chevrons) under each
        tool's name in Orders, the Guide and the Jobs app;
      - **stamps:** buying stamps `Stamp_Bought` over the card's button with a few sparkles,
        selling stamps `Stamp_Sold`, each gone in about a second and not taken away when the list
        redraws; a Robux purchase stamped once Roblox's prompt closes;
      - **tool condition:** the Truck menu, and owned tools in the shop, show a glyph per part
        (fuel can, tire, sharp or dull blade, spool; the wrench for a wrecked engine) in green,
        yellow or red with the words for what's wrong; the HUD's ToolCondition shows a chip per
        problem (onto a second line on a phone) and, while you hold E at the workbench, the glyph
        for what you're doing;
      - **job tracker:** on the `GoalTracker` card during a job (the goal stays Grandma's sticky
        note);
      - **TurfKing's crown:** a gold crown on a purple badge on Chad's face (Messages threads, his
        text toasts, the dialogue box), on a job card TurfKing took (its title and Taken button),
        and on Gloria's yard card in the Best Yard results;
      - **sparkles:** on Level Up!, New Tool!, Payday!, Job Complete!, the act titles, the
        dialogue's new-tool card and the trophy on a win; the 2 x 2 sheet plays once, not
        looping, and the frame rate holds on a phone.
      The shop cards stay rows (picture on the left) instead of the style frames' 4-across grid,
      so long stats and phones still fit.

## Fluid mowing: to check

The lawn is carved as you mow (see docs/GAME_DESIGN.md, "Mowing: cells, swaths and shells"). Play it
with Allow Mesh / Image APIs on (Studio needs it too), and the tenth item, the toggle-off one, with
it off.

- [ ] Mow a straight pass with the reel mower: one clean strip, deck-wide, crisp edges, no seams.
- [ ] Mow a curve and a figure-eight: the shape follows the deck.
- [ ] Back-and-forth rows: light and dark stripes alternate; a diagonal reads flat.
- [ ] Clippings only in tall grass; none crossing the cut strip; engine dips and recovers.
- [ ] 90%: the missed button lights the strips; 99%: chime and stamp, job completes.
- [ ] Dull blade: ragged tufts remain, quality drops as before.
- [ ] Junk: push mower stops at it, gas mower chews it with the existing bits effect.
- [ ] Home lawn: leave for a job, come back, patches have grown back and mow again.
- [ ] Phone (landscape): the big lawn draws, holds frame rate, and the HUD pieces fit.
- [ ] Toggle off Mesh / Image APIs in a test copy: the fallback draws and the job still completes.
- [ ] Reel mower stops dead at junk hidden in the grass (needs real walking).
- [ ] Phone preset: the 28×22 lawn mows and finishes with the F9 memory panel open.
- [ ] A second player hears the first's mower and sees their swaths.

Later (known, and left for after this PR):

- [ ] One image-budget miss sends every lawn to the fallback for the rest of the session.
- [ ] The fallback builds every block of tall grass before the lawn's ledger arrives.
- [ ] Making the blade dots for the first lawn drawn hitches on phones.
- [ ] Prediction leaves slivers past junk that stopped the deck, until they grow back.
- [ ] `wreckHazards` only checks where a sweep ends, not the strip it covered.
- [ ] A snip that junk in the grass stops goes on to snip the nearest weed.
- [ ] The HUD editor's template doesn't know `MissedButton`.
- [ ] A home lawn grows back in single-cell speckles (2 x 2 blocks instead?).
- [ ] Apply maneuverability to walk speed on tight lawns (`fit.speed`, which sweeps ignore).
- [ ] Stripe shade for ride-on decks.
- [ ] Prediction keeps last frame's deck, so above about 200 fps no frame moves 0.05 studs and your own mower's swath waits for the server.
- [ ] A dead character's tool keeps `Working`, `Cutting` and `Mows` set until it's unequipped (the client guards on health).
- [ ] A respawn within a second of a lawn's first fetch hits the `GetSwaths` limit and shows the lawn tall for 1.5 s until the retry.
- [ ] Prediction stamps over cut and ragged grass whenever `Mows` is on; watch its cost on phones over a ragged patch.

## Busy Season, slice 1: to check

Slice 1 is the first minute and the ladder (design:
`docs/superpowers/specs/2026-10-29-busy-season-design.md`, plan:
`docs/superpowers/plans/2026-10-29-busy-season-slice-1.md`). A Studio pass has seen the
first-timer landing (on the strip with the shears 1.2 s after joining, the coach line and the Next
chip), a jump to level 5 paying levels 2 to 5 ($850), the Levels panel, and the iPhone preset with
the chip above the tracker, with no errors. It has not seen or heard a completed job (the stars,
the tip, the cash and XP pops, the sounds), June's welcome after the first payday, a milestone
moment, the rail on a tall screen, or the chip with the Missed button up. The test panel (K) has
two shortcuts for this: **Start as a first-timer** puts your save
back to a brand-new one and drops you on the first lawn with the shears (it calls off any job
first, and that session stops saving, so a playtest can't wipe a real save), and the **Level** row
sets your level to 2, 5, 10 or 20 and pays any level reward not yet claimed.

The spec's playtest checklist for slice 1:

- [ ] tap to first snip under ten seconds on PC and phone
- [ ] a level-up moment with the panel
- [ ] a 3-star tip
- [ ] the rail on a phone in landscape
- [ ] every sound

The payday half (June's welcome, then her texts) plays once per playtest launch, so a second
**Start as a first-timer** run in the same launch shows no welcome. Restart Studio for a second
look.

What the reviews asked to see in Studio:

- [ ] The star pop on the pay panel: each star should grow out of its middle (the anchor was moved
      there, never seen).
- [ ] The goal chip against the Snip and look-at buttons on an 844 by 390 phone, with the missed
      button and the shears up together: it should clear them, and its 10 px text should read.
- [ ] The Cash and Star sounds together on a paid job (Cash first, then each Star at a lower
      volume): clear, or a smudge. Star and LevelUp are the likeliest to be swapped.
- [ ] The Levels panel at phone scale: row text, the Close button and the star by the level line,
      with and without the gold sign.
- [ ] The total's "+$" pop on the pay panel: it starts in the middle of the big total, so check it
      doesn't read as clutter.
- [ ] The star glyph on the pay panel and the job board: nothing else in the game draws it, so it
      may fall back to a system font and look off.
- [ ] The XP button by thumb on a phone: it is 36 px, about 25 px at the columns' 0.7 scale.
- [ ] The text-only DONE stamp (`UI.stampText`): its width is a guess of 0.6 heights per letter,
      which fits "DONE"; check it on the rail.
- [ ] The "Level n: text" subtitle against the 720 px level-up moment: it may be too long for
      one line.

## Busy Season, slice 2: to check

Slice 2 is Tomorrow (design: `docs/superpowers/specs/2026-10-29-busy-season-design.md`, plan:
`docs/superpowers/plans/2026-10-29-busy-season-slice-2.md`): the daily contracts and the mailbox,
the login streak, the leaderboards and judging day every Saturday. The Lune checks cover the tables
and the rules (`check-season`, `check-story`, `check-gui`). In Studio, on the phone emulator, the
phone layout has been looked at (the contracts panel and the Levels panel, which is how the
Close button under the hotbar was found) and the day 1 Payday card was seen after the tap to start,
but not heard. Not yet seen or heard: the PC shortcuts, the leaderboard sign, the later streak days
and the Bonus Day moment, the pennant, and any of the sounds. The test panel (K) has three
shortcuts for it, all Studio only: **Next day** moves the server's clock a day on and turns every
player's day over (a new three contracts, and the streak with its gift to claim), **Jump to Saturday** moves it to
noon on the next Saturday UTC (never today, so it always moves, and a judging mark saved for that
day is cleared) and **Refresh the boards** reads both leaderboards now instead of in two minutes. A
jump of more than one day breaks the streak and starts it again at day 1; from a Friday it is just
tomorrow, so the streak advances. Press **Next day** one day at a time to walk the streak up. The
streak's cash is a gift now: after a turn the Gifts button (right edge) wears a tilted CLAIM tag and
pulses, and pressing it pays the day and plays the streak card. A gift left unclaimed is paid by the
next turn with a "Yesterday's gift: +$N" toast. The panel's +$ buttons are not earnings for a
contract; a Level jump's cash and a claimed gift are.

The spec's playtest checklist for slice 2, with what to expect:

- [ ] A fresh day's contracts: open them from the mailbox at the curb (E) and from the Contracts
      square on the left, whose yellow badge shows the contracts left today (3 at first). Both show
      "Today's contracts": a Mow, an Earn and a Junk or
      Stars contract for your level band, each with its pay. Claim day 1's gift (Gifts) and finish
      a job: Mow reads 1/2, and the Earn row completes (the claimed $100 counts toward it, and the
      job's $60 and the $10 first-job milestone take it past $150), with the goal chime, a "+$" pop
      off the Contracts square and a DONE stamp on its row; the badge reads 2 (contracts left), or
      1 if the job earned three stars on a Stars day. From day 2 the claimed gift ($150 and up) already meets Earn $150 at
      level 1 or 2, so that row completes as you claim, after the Payday card (its chime and pop
      0.6 s after the card). The test panel's Level 5 jump finishes Earn only on a day whose gift
      falls short or is not claimed yet: day 1 before the first job, or band 2 and up, where Earn
      is $400 or more; its $850 across levels 2 to 5 counts as earned.
- [ ] The Bonus Day: finish all three. Earn completes as above (with the first job on day 1, with
      the claim from day 2, or with the Level 5 jump where the gift falls short), two jobs do
      Mow, and the Junk or Stars one (the pieces picked up on the lawn, or a three-star job) is the
      third. A Payday
      moment whose subtitle reads "Bonus Day: +$500" plays with the cash sound, and the panel's
      line reads "Bonus Day collected".
- [ ] The gift: press **Next day**. No card plays; the Gifts button wears a tilted yellow CLAIM tag
      on its top left and pulses every 2.5 s, the contracts are a new three, and the Levels panel
      (L) reads "Streak: Day 2 of 7, claim $150 in Gifts". Press Gifts: a Payday moment whose
      subtitle reads "Day 2 of 7: +$150 today, $200 tomorrow" shows for four seconds, with the
      streak chime and the cash lifting off the money counter; the tag goes, the pulse stops, and
      the Levels panel reads "Streak: Day 2 of 7, next $200". Press Gifts again: the contracts
      panel opens.
- [ ] A gift left unclaimed: with day 2 claimed, press **Next day** twice without pressing Gifts.
      The first press makes day 3 (its CLAIM tag is up) and the second pays day 3's gift for you
      with a "Yesterday's gift: +$200" toast and the cash register, once (the money goes up by
      $200, not more), and day 4's CLAIM tag is up. The Earn row counts that $200 once.
- [ ] Day 7: claim day 4's gift, then press **Next day** and claim, three more times, one at a
      time (days 5, 6 and 7). The day 7 turn puts a
      purple pennant on the truck's bed at your business (and on the truck in the drive
      cutscene); claiming day 7 shows a Payday moment whose subtitle reads "Day 7: +$1,000 and a
      pennant for the truck".
- [ ] The leaderboard sign at spawn, with API access off: it stands 12 studs from the spawn pad on
      its +Z side. Both boards say "Leaderboards are off in this place" and nothing else, and
      **Refresh the boards** says so too.
- [ ] The same sign with API access on (Game Settings > Security > Enable Studio Access to API
      Services): two boards of up to 25 rows, a "You:" line under each ("You: #12 with 40 lawns",
      or "You: not in the top 100 yet, 3 lawns"), a new row or number after a finished job within
      two minutes, and the same at once from **Refresh the boards** ("Boards refreshed."). Studio
      reads and writes its own boards (the stores' names with "_studio" on the end; the output says
      so at start), so the live boards never see a test row. A read that fails while the boards are
      on says "The boards are not answering right now." until one works.
- [ ] **Jump to Saturday** after a first judging day (act 4: **Open judging day**, call the judges,
      collect). Before it the goals rail says "Judging day in N days" and June's porch line counts
      them ("Saturday's the day. N days to go."). After it the rail asks you to beat Gloria's bar
      on judging day with **Call the judges**, and the judges can be called. A loss shows "Judging
      day comes round again next Saturday." on the results screen. Four lost Saturdays after the
      first judging day (jump, judge, lose, four times) start a new summer, and the bar goes up 2.
      **Open judging day** now answers "Judging day is every Saturday now; use Jump to Saturday."
- [ ] On a phone (the device emulator, landscape, say 844 by 390): the contracts panel from the
      Contracts square (rows, bars and Close all reachable), the Levels panel's streak line, and the sign's 18 px
      text readable from a few steps away.
- [ ] Model wanted: `Props/CurbMailbox`, the mailbox at the curb by every driveway (a block
      placeholder until then).
- [ ] Model wanted: `Props/TruckPennant`, the streak's pennant on the truck bed (a block placeholder
      until then).
- [ ] Pennant on the drive cutscene's truck once a real `Props/TruckPennant` model lands: the trip
      info must `Assets.shareWith` the model so the client can build it.

## Front-page HUD: to check

The play screen was rebuilt as a front-page Roblox simulator HUD (design: `docs/GAME_DESIGN.md`, "12.
The HUD"; plan: `docs/superpowers/plans/2026-10-30-front-page-hud.md`). The Lune checks cover what is
pure (`check-gui` the layout rules at 1280 by 720, 1024 by 768, 844 by 390 and 667 by 375, the palette
and the source rules; `check-season` the gift, the day turn and Settings rules). None of it has been
looked at in Studio or on a phone yet, so every item below is a first look. Studio only: the test panel
(K) has Next day, and Studio does not save without API access (Game Settings > Security > Enable Studio
Access to API Services), so turn that on where an item says so.

Each step reads "do this, expect that".

Layout (look at each piece, then check nothing overlaps):

- [ ] PC, a 1280 by 720 window. Expect, down the left: the money pill with a gold coin, the level pill
      and the streak pill side by side (the streak pill only once you have a streak), the purple
      countdown pill (only when judging day is on the calendar), then four squares (Truck, Guide,
      Crew, Contracts) with their names under them and T, G, C on their corners. At the top in the
      middle: Grandma's cream banner, clear of both columns. Down the right, inside the edge strip:
      curb appeal, and during a job the dark job card with the timer, then the boost pills, then (late
      in the mowing) the missed button. Against the right edge: Shop, Gifts, Top Lawns and Settings
      squares. Also look at 1024 by 768 and 1024 by 600.
- [ ] The phone emulator at 844 by 390, landscape. Expect the four left squares in a 2 by 2 grid, the
      right strip's squares bare (no names, 56 px, Settings smaller), the left column about 0.7
      scale when the countdown pill is up, and every square at least 40 px across (44 px expected).
      Nothing under the move stick (bottom left) or the jump button (bottom right), and the banner not
      touching either column.
- [ ] The phone emulator at 667 by 375. Same checks; the squares are about 42 px. The banner and the
      first-job coach move left to clear the right column.
- [ ] The Next chip (a phone only, in the right column) shows the next milestone on one line. It only
      shows; nothing happens when it is tapped.
- [ ] Touch targets. On a phone, Call off and the missed button each have a hit area 40 px tall or
      more (invisible strips above and below them). Press Call off once: it says "Sure?" for three
      seconds; press it again inside that to call the job off.

The tool hotbar:

- [ ] A job with 10 or more tools (the starter truck with the ToolBucket carries 10 to 13): every tool has
      a slot, keys 1 to 9 and then 0 take out the first ten, and clicking any slot takes that tool out
      (the held one is cream; pressing its slot again puts it away). Roblox's own hotbar never shows.
- [ ] Narrow the window (or use 667 by 375) with 10 tools: the row shrinks first, then stops at 40 px
      slots (48 px on a PC) and the last slot becomes a gold "+N" that opens a tray of the rest just
      above the bar. The held tool is never in the tray. Pressing a slot, or the job ending, closes the
      tray; a tap on the bare screen does not (a known gap). The row stays clear of the move stick and
      the jump button.
- [ ] A gamepad (or the emulator's): L1 and R1 step through every tool. A broken mower mid-job, and a
      respawn: no stale slot, no errors in the output.
- [ ] Studio probe, the hotbar equip: take a tool out with a key, then check on the server (Server view)
      that `Tool.Equipped` fired once and the tool's `Working` attribute follows. The plan assumed
      Roblox's own hotbar did the same; this is the first look.

The money, the squares and the buttons:

- [ ] Finish a job: the money counts up over about 0.4 s and the pill pulses once. Hover a square, a pill
      and a window's Close button with the mouse: each grows a little; press and hold: it squashes;
      let go: it springs back; a soft click plays on each. On a phone nothing grows under a finger,
      but the press and the click still happen. Press and drag off a button with a finger, then lift:
      the button must still spring back (it must not stay squashed).
- [ ] The Heartbeat pulses. Watch the Gifts button (while a gift waits), the money pill and the badges
      for a minute: nothing flickers or ends up a size it was not (a pulse that lands while the
      pointer is over the button should end at the hover size).
- [ ] Studio probe, the font: the new text is FredokaOne. Look at "LVL", "DAY", the squares' names and
      the splash for a face that falls back to a system font (letters too thin or the wrong shape).
- [ ] Studio probe, the face sizes: with the Explorer open, check the Truck, Guide, Crew and
      Contracts squares' `Face` frames are 76 px on a PC and 64 px in the phone grid
      (`AbsoluteSize`), and the right strip's are 76, or 56 and 44 on a phone.
- [ ] Studio probe, the automatic heights: the job card, the banner and the Top Lawns and Settings
      windows grow with their words (`AutomaticSize` Y). Change the goal text length (play to a later
      goal) and look for a banner that clips its bar or leaves a gap under it.

The gift (Busy Season, slice 2 has the full walk):

- [ ] Press the test panel's Next day. Expect no card; the Gifts button wears a tilted yellow CLAIM tag
      and pulses every 2.5 s. Press Gifts: a Payday card for the day, the streak chime, the cash
      lifting off the money counter, the tag gone. Press Gifts again: the contracts panel opens.
- [ ] Next day twice without claiming: the second press pays the first's gift with a "Yesterday's
      gift: +$N" toast, once, and a new CLAIM tag is up.

Shop, Top Lawns and Settings:

- [ ] Shop buying away from the desk. Stand in the yard, away from the computer, and press the Shop button
      (or B): the Orders window opens with tools, supplies and decorations. Buy a tool: it is paid for
      and a box arrives at the shop door. Sell one: it works. The window has no Truck, Trailer or
      Business tabs away from the desk. At the computer's Orders app the truck, trailer and business
      tabs are there and buying one works. A truck bought by hand from the command bar away from the
      desk is refused ("Order it from the computer in your shop."). Taking a job still needs the
      computer. While on a job, buying a tool says "Finish the job first. Your orders can wait."
- [ ] Top Lawns (F or the button), API access on: two tabs, up to 25 rows each, gold ranks for the first
      three, your own line under the list. With API access off: the window says the boards are off. On
      a phone, both tabs and the Close button are reachable, and the tab you press grows and clicks.
- [ ] PlayerList vs the right strip. Test tab > Clients and Servers, 2 players: Roblox's own player list
      sits at the top right. Expect the strip's top square (Shop) not to hide under it; if it does,
      the strip needs to move down on a PC.
- [ ] Settings (comma or the button), API access on: choose Sound Low, Camera motion Off, Grass detail
      Low. Sounds are quieter (Off is silent, including the engine and the UI), the head bob stops,
      and the Grass row says it takes effect when you rejoin. Stop and play again (a rejoin): the three
      choices are still as you left them, the grass is drawn with 4 layers (a flatter lawn). V on a
      keyboard flips Camera motion and the window follows it. A player who never opens it: full
      sound, motion as before, Auto grass.
- [ ] Settings with API access off: the choices work for the session and are not kept after a rejoin.
      Press a choice many times fast: the window keeps up and the server answers the last one.

The stripe splash:

- [ ] On a job, mow one straight pass of 30 studs or more with a gas mower, out to the edge of the lawn
      (a pass ends when the deck leaves the lawn, you put the mower away, or you turn back): gold "NICE
      STRIPE!" tilted a little pops in above the middle, holds about a second, fades, and a soft star
      chime plays. Do three more passes 10 seconds apart: "CLEAN CUT!", then "PERFECT LINE!", then
      "NICE STRIPE!" again. Two passes within 8 seconds: only the first cheers.
- [ ] Turn round after 40 studs and come back: the cheer comes at the turn (the way back is a pass of
      its own), not at the end of the way back.
- [ ] No splash for: a pass under 30 studs (a U-turn after 15 studs and back counts as two short
      passes); a pass that hit junk (the engine stalls for a moment, so the pass ends there); a pass
      with a dull blade or no fuel; any pass finished while a menu or the pay panel is up. Money and XP
      do not change when it shows. On a phone it is smaller (40 px), not under the thumbs.
- [ ] Studio probe, the stall: hit junk mid-pass and watch the tool's `Working` attribute drop to false
      (the splash decides a pass was hit from this, since the blade-hit sound has no id yet). If a
      pass ends clean and still shows no splash, check the pass really covered 30 studs along its
      first two seconds' heading.

Later (known, left for after this PR):

- [ ] A blade-hit sound id (`Sounds.Ids.BladeHit` is empty) and an Effects volume for the engine.
- [ ] The seven-rewards card for the Gifts button when nothing waits.
- [ ] Gamepad focus for the HUD's new squares.

## Model overhaul: what is left

Batches 1 to 4 (the mowers and trimmers; the blowers, barrows and the rest of batch 2; the trucks and
trailers; the customer's house) are imported and `lune run scripts/check-models` passes. The
pipeline is described in `assets/README.md`, HANDOFF.md says how to run a batch, and the design is
`docs/superpowers/specs/2026-10-28-model-overhaul-design.md` (its section 6 gives the batch order).
Two things in **Before release** belong to this work too: the four lawn images and the TurfKing
T-shirt.

### Playtest checklist

- [ ] Every tool on the shop racks and in the truck bed, held in first person: grips on the
      handles, nothing clipping the camera, wheels spinning on mowers (where the mesh has separate
      wheel parts).
- [ ] A job start to finish with the new truck and trailer: loading, the drive, the house and shed
      in view, the customer's porch.
- [ ] Gloria's porch scene, June on her rocker, Chad by the TurfKing truck, the judges' walk:
      bubbles over heads, prompts at chests, idle and sit playing, nobody floating or sunk.
- [ ] Grass: stripes on the texture at a job and at home, tufts from eye level, far lawns from the
      road, and the no-image fallback still playable.
- [ ] Galaxy A06 preset: the shop with every rack full, and a job with everything in view, with the
      frame time next to today's.
- [ ] A paint job on RustyPickup, WorkPickup and LandscapingTruck, whose body is one mesh, so
      `Premium.applyPaint` recolours the whole truck. If the tires or the glass take the paint, the
      remedy is curation (a `parts` rename or a colour-list `body` in the manifest entry), not code.

What to change when one of those fails:
- A tool's grips or hold: `handle` and `grips` in its manifest entry, then a re-import. Seen
  already in a Play check on this branch: the handheld trimmers hang below the camera in hand.
- A truck that won't load, or a door or paint job that is wrong: `markers`, `boxes` and `body` in
  its entry (`<Id>__Body` is what paint and the TurfKing livery tint).
- A person floating, sunk or sitting wrong: their `body` scales in `src/shared/Config/Cast.luau`,
  and for June `seat`, which is an estimate.
- A frame time worse than today's by more than 10%: the entry's `strip` list first, then another
  candidate, then `kept`.

### Kept for now: the swap list

These stay as they are this round (the spec's non-goals, its section 6 and its ruling 2). Each
swap is a manifest entry plus a Studio import, and the new model has to keep what the code looks
for (the tables under "New item ids for modelers" in docs/GAME_DESIGN.md list it).

- [ ] **Decorations:** the yard decorations in `assets/Decorations/` (22, besides the trophy) and
      `GardenGnome` and `FlowerPatch` in `assets/Props/`. Keep the `Root` part, the `SnapL` and
      `SnapR`, `Light`, `Fire`, `Spout`, `Water` and `Seat` markers, and the moving pieces
      (`<Id>__Overgrowth`, `Mailbox__Door`, `Mailbox__Flag`, `GardenWindmill__Spinner`).
- [ ] **Storage:** `StoragePegboard`, `StorageWallRack`, `StorageWallHooks` and `StorageShelf`.
      Keep the `Slot1`, `Slot2`... attachments.
- [ ] **Delivery boxes:** `DeliveryBoxSmall`, `DeliveryBoxLong`, `DeliveryBoxLarge` and
      `DeliveryCrate`. Keep the flaps, lids and front panel on their hinges, and `Contents`.
- [ ] **Junk in the grass:** `DebrisStick`, `DebrisRock`, `DebrisDogBall`, `DebrisToyTruck` and
      `DebrisFrisbee`. Nothing taller than about 0.6 studs, no collision, `<Id>__Body` parts.
- [ ] **The trophy:** `BestYardTrophy`. Keep `BestYardTrophy__Cup`, which `DecorService` looks for.
- [ ] **Gloria's set:** `GloriaHouse`, `GloriaYard_Stage1` to `GloriaYard_Stage3`, `PorchDeck`,
      `PorchRockingChair`, and the `TurfKingSign` that stands in her yard from stage 2 (when a stage
      has no model of its own). They are a matched set built to one footprint, so swap them
      together or not at all.

### Batches 5 to 7

Not started. Each id is a manifest entry (a Store model, a Blender model or `kept`) and a Studio
import, one batch at a time, with `lune run scripts/check-models` and a Play check before the next.

- [ ] **Batch 5, hand and long-handled tools:** `RoundPointShovel`, `GardenSpade`, `DiggingFork`,
      `Broadfork`, `OldRake`, `WideRake`, `BowRake`, `StirrupHoe`, `Mattock`, `Loppers`,
      `PruningSaw`, `BypassPruners`, `AnvilPruners`, `FloralSnips`, `HandTrowel`,
      `HandTransplanter`, `DandelionWeeder`, `Dibber`, `HandCultivator`, `GardenHoseWand`,
      `WateringCan`, `NitrileGloves` and `ChemicalGloves`.
- [ ] **Batch 6, pro machines:** `StandOnAerator`, `TowBehindAerator`, `SlitOverseeder`,
      `PowerRakeDethatcher`, `RideOnSpreaderSprayer` and `SoilProbe`. The design expects this long
      tail to be mostly Blender work.
- [ ] **Batch 7, the business buildings, all four together:** `Shed`, `Garage`, `SmallOffice` and
      `EquipmentYard`. Players upgrade through them in that order, so they change in one batch or
      not at all, and the old four stay until all four new ones pass `check-models` and a
      walk-through in Play. They carry the most markers (see "Walk-in buildings").
- [ ] **Named by no batch:** `GardenShears`, `ArticulatingHedgeTrimmer` and the supplies
      (`AirCompressor`, `BenchGrinder`, `BladeFile`, `ElectricInflator`, `FootPump`,
      `SharpeningStone`, `SpareMowerBlade`, `SpareTire`, `TirePatchKit`, `TrimmerLine`,
      `WrenchSet`) have no manifest entry yet. The small ones can simply be recorded as `kept`.

## Before release

- [ ] Turn on Allow Mesh / Image APIs (Experience Settings → Security) before publishing; without
      it the lawn uses the plain-part fallback.
- [ ] Turn on *Experience Settings → Security → Enable Studio Access to API Services* so progress
      saves when testing in Studio. The game is already published under Big Dink Studios.
- [ ] Make the experience public when it's ready to play.
- [ ] Set max players to 12 or fewer (Game Settings → Places). The placeholder town has 12 plots.
- [ ] **Test on a real phone.** Prompts and tools already use ProximityPrompts and
      `Tool.Activated`, so touch should work, but hold-to-use tools and the carry/load flow need
      checking. Profile frame rate with grass on screen. The kit makes no device FPS promise. Some
      manifest entries carry part budgets above the spec's defaults, pending the Galaxy A06 check:
      GasTrimmer 160, ElectricTrimmer and Brushcutter 200 (the machine default is 120),
      LandscapeTrailer 100 (80) and House 360 (300).
- [ ] **Sounds**: the kit has none. The mowers' engine, pull-start and reel whirr and the lawn-done
      chime use free Creator Store ids in `src/shared/Sounds.luau`. Still empty: trimmer, rake and
      blower, cash register, UI clicks, the shears' snip, a blade hitting junk, and setting a tool
      down, picking it up, hanging it and dropping it in the bucket (`Thunk`, `Pickup`, `Hang`,
      `Bucket`).
- [ ] **Animations**: pushing and holding poses for mowers and trimmers.
- [ ] **The four lawn images, then the textured lawn**: `python scripts/upload-grass-art.py`
      answered HTTP 403, so the Open Cloud key most likely has no Assets scope and the four ids in
      `src/shared/Config/GrassArt.luau` are still 0. Either give the key Assets read and write for
      Big Dink Studios (Creator Hub → Open Cloud → API Keys) and run the script again, or upload by
      hand: in Studio, with the Big Dink Studios game open, **Asset Manager → Images → Bulk Import**
      `Lawn_Mown_Color.png`, `Lawn_Uncut_Color.png` and `Soil_Color.png` (from
      `art-source/GUI/Source/RenderOnly/Textures/`) and `art-source/Grass/Grass_Tufts.png`, copy
      each image's id and write it as a plain number into `Mown`, `Uncut`, `Soil` and `Tufts`.
      The lawn already uses three of them, `Mown`, `Uncut` and `Tufts` (`GrassController` lays the
      mown map as a tiling Texture, one tile per `TileStuds` = 8 studs, and `GrassPaint` paints the
      stripes over it and stamps tufts on the shells). `Soil` is uploaded for later; nothing reads
      it yet. But the textured path has only been seen as flat colours on this branch, because the
      ids are 0. Once they are in, look at a lawn in Studio with Allow Mesh / Image APIs on:
      stripes as tints on the texture, tufts from eye level, a far lawn from the road, and the flat
      colours coming back if the mown, uncut or tuft id is set to 0 again. When the textures are
      first seen, also look for cross lines at the trailing edge of stripes (Overwrite also writes
      the stamp's soft rim), seams in the mottle every 16 studs, and sparkle on the tufts; the
      mitigations are a `Pixelated` `SamplingMode` on the tint brushes, a box-downscaled mottle and
      pre-shrunk tufts.
- [ ] **TurfKing T-shirt**: create the T-shirt from `art-source/Cast/TurfKing_Tee.png` on the Create
      page (Avatar items, T-shirt), as Big Dink Studios (the group). It isn't free: Roblox's
      classic clothing docs list a Robux upload fee (80 at last check), so look at the price before
      paying. Open Cloud can't make one.
      Then put its id in `tshirt` for Chad and Sam_TurfKing in `src/shared/Config/Cast.luau` (both
      0 now) and run `lune run scripts/check-story` and `python -I scripts/cast-check.py`. The cast
      check accepts an item the Big Dink Studios group made whatever its sale state, because the
      group's own items are always usable by its experience. `python scripts/make-turfking-tee.py`
      redraws the image.
- [ ] **Store art**: put `art-source/GUI/Store/` on the Roblox page (game icon, 5 thumbnails, the
      pass and product icons) on the Creator Dashboard. The in-game GUI art is under **GUI
      overhaul** above.

## Known quirks

- While Rojo is connected, Studio's Output fills with
  `[Rojo-Warn] Ignoring change for instance … as it is unknown to Rojo` every time you change
  something. These come from the MeshPart models Rojo syncs through its fallback path, and they're
  harmless.
- Two Output warnings show up in every Studio run on this branch: `ContentId rbxassetid://203785492`
  (asset type does not match) and `rbxassetid://4617908416` (not found). A Lune scan of `assets/`
  found neither id, so which model, kit piece or part of Studio carries them is unknown. To trace
  when someone has Studio time.
- Rojo drops `Model.PrimaryPart` on synced MeshPart models, so code shouldn't rely on it for kit
  assets. Use the pivot, which is set, or find parts by name.

## Daily workflow reminder

```sh
cd ~/Desktop/"Lawn Mower"/Lawn-Mowing-Simulator
rojo serve
```

Then in Studio, open "Lawn Mowing Simulator" from Roblox (Big Dink Studios) and click Plugins →
Rojo → Connect. It's a Team Create place, so changes made directly in Studio save to the cloud.
