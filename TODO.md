# What's left — Lawn Mowing Simulator

Last updated: 2026-10-28

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
Import** (as Big Dink Studios), then use them as MaterialVariants or Textures on the lawn's turf.

## Code work to use the rest of the kit

Yards (`src/server/Services/LawnService.luau`) now use the kit, falling back to blocks if
`Assets.Kit` is missing:

- [x] **Grass** (fluid mowing, PR pending): the server keeps the lawn as a ledger of 1-stud cells
      (`src/shared/LawnGrid.luau`, `LawnService.luau`) and logs every sweep of a mower's deck as a
      swath (`src/shared/Swath.luau`). Each client paints the swaths into EditableImages
      (`GrassController.luau`, `GrassPaint.luau`): a turf plate with 6 grass shells on PC and 4 on
      phones, and nothing at all for lawns more than 200 studs away. Without EditableImages (Allow
      Mesh / Image APIs is off, or a phone's memory is spent) `GrassFallback.luau` draws plain parts
      instead. The kit's `Grass_Tall_*` and `Grass_Short_*` clumps are no longer used for lawns.
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
        imported (instructions37): the house, the three yards, the truck, the sign, Gloria, Chad.
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
      - a loss: Gloria's gloating, June's "Next summer...", the goal card counting 4 jobs down,
        June's text when the judges are back;
      - leaving between calling the judges and collecting, then rejoining: the scene, then the
        same result;
      - the next summer after 12 jobs, with Gloria at 90, the shorter judging scene and
        `ContestWinAgain`;
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
with Allow Mesh / Image APIs on (Studio needs it too), and the last item with it off.

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
- [ ] Reel mower stops dead at junk hidden in the grass (needs real walking)
- [ ] Phone preset: the 28×22 lawn mows and finishes with the F9 memory panel open
- [ ] A second player hears the first's mower and sees their swaths

## Before release

- [ ] Turn on Allow Mesh / Image APIs (Experience Settings → Security) before publishing; without
      it the lawn uses the plain-part fallback.
- [ ] Turn on *Game Settings → Security → Enable Studio Access to API Services* so progress saves
      when testing in Studio. The game is already published under Big Dink Studios.
- [ ] Make the experience public when it's ready to play.
- [ ] Set max players to 12 or fewer (Game Settings → Places). The placeholder town has 12 plots.
- [ ] **Test on a real phone.** Prompts and tools already use ProximityPrompts and
      `Tool.Activated`, so touch should work, but hold-to-use tools and the carry/load flow need
      checking. Profile frame rate with grass on screen. The kit makes no device FPS promise.
- [ ] **Sounds**: the kit has none. The mowers' engine, pull-start and reel whirr and the lawn-done
      chime use free Creator Store ids in `src/shared/Sounds.luau`. Still empty: trimmer, rake and
      blower, cash register, UI clicks, the shears' snip and a blade hitting junk.
- [ ] **Animations**: pushing and holding poses for mowers and trimmers.
- [ ] **Store art**: put `art-source/GUI/Store/` on the Roblox page (game icon, 5 thumbnails, the
      pass and product icons) on the Creator Dashboard. The in-game GUI art is under **GUI
      overhaul** above.

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
