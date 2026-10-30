# Lawn Mowing Simulator

> **Picking this project up?** Start with [HANDOFF.md](HANDOFF.md): what's done, the open PRs and what to do next.

A Roblox lawn care game for crews of 1–4 players. Run your own lawn care business, take jobs on
the computer in your shop, load the right tools into your truck, drive out to the house and get the yard done
fast without wrecking the customer's flowers. Earn money, upgrade your gear, and grow your business
from a tool shed into a small office.

Everything visual is a placeholder made of blocks for now. Real models drop in without code changes
(see [Swapping in real models](#swapping-in-real-models)).

## Setup (Rojo)

You only do this part once.

1. **Install Rokit** (it installs Rojo and the other tools at the versions this project uses):
   - Windows (PowerShell):
     ```powershell
     Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
     ```
   - macOS / Linux:
     ```sh
     curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
     ```
   Close and reopen your terminal afterwards.
2. **Install the project's tools.** In this folder run:
   ```sh
   rokit install
   ```
3. **Install the Rojo plugin in Roblox Studio:**
   ```sh
   rojo plugin install
   ```
   (Or install "Rojo" from the Studio Toolbox / Creator Store.)

## Every time you work on the game

1. Start the Rojo server in this folder:
   ```sh
   rojo serve
   ```
2. Open your place in Roblox Studio, go to the **Plugins** tab, click **Rojo**, then **Connect**
   (it connects to `localhost:34872`).
3. Edit the `.luau` files here. Every save shows up in Studio right away. Press Play to test.

Other useful commands:

| Command | What it does |
| --- | --- |
| `rojo build -o LawnMowingSimulator.rbxlx` | Builds a place file you can open in Studio without the server |
| `rojo sourcemap -o sourcemap.json` | Lets the Luau extension in VS Code understand the game tree |
| `stylua src` | Auto-formats the code |
| `selene src` | Lints the code |
| `lune run scripts/check-mowing` | Checks the lawn's cell maths: which cells a mower's deck cuts, and the cell counts |
| `lune run scripts/check-season` | Checks the season's tables: the goals rail's milestones, what each level pays, and how a job earns its stars and tip |

**Testing saves in Studio:** Game Settings → Security → turn on *Enable Studio Access to API
Services*. Without it the game still runs, it just doesn't save progress.

**Testing crews:** Test tab → Clients and Servers → pick 2–4 players → Start.

**How long joining takes:** joining prints `[Load]` lines in the F9 console. On a phone, type
`/console` in the chat, or open it from the settings in the Roblox menu. On your own screen (the
Client tab), each line says how long one of the title card's steps took, and how long the card
had been up by then:
1. the game loading;
2. getting to your business;
3. the ground loading under you;
4. "Tap to start" showing;
5. you tapping.

Another line says when the client scripts were ready. The Server tab adds how long your save took
to load and your business to build, and when you got there.

## Publishing

Players (and phones) only get what's been published. To publish the latest `main`, no Studio
needed:

```sh
git checkout main && git pull
python3 scripts/publish.py --dry-run   # build, merge and check, but don't publish
python3 scripts/publish.py             # the same, then publish; prints the new version number
```

- It refuses unless the working tree is clean and level with `origin/main` (`--force` skips that).
- It builds the code with `rojo build`, then `scripts/publish-place.luau` (Lune) swaps it into a
  **base place** that has what Studio made and Rojo doesn't manage: Terrain, Baseplate,
  SpawnLocation, the Sky and Lighting effects, `StreamingEnabled` and every service's settings.
  It prints a short check before publishing: what was kept, how many models every client
  downloads when it joins (and how big that is), the Assets.Story models and the GuiArt ids
  filled.
- **The base place** is Studio's newest AutoRecovery copy of the place, or
  [`place/base.rbxl`](place/base.rbxl) when there isn't one. `--base FILE` picks another. After
  changing something in Studio outside the Rojo trees (lighting, terrain, the spawn), remake the
  committed one from the autosave and commit it:
  `lune run scripts/publish-place --make-base <autosave.rbxl> place/base.rbxl`.
- It refuses a base with `ServerStorage.ModelImport` or `Workspace.Scene` in it (left over from
  a 3D import). Delete them in Studio, or pass `--base place/base.rbxl`.
- **API key:** `$ROBLOX_API_KEY` or `~/.roblox-opencloud-key`, an Open Cloud key made under Big
  Dink Studios with **universe-places** write access on this experience. Never commit it.
- **Close Studio first.** While Studio has the place open, Roblox answers 409 "Server is busy".
  The script waits 45 s and tries again, up to 8 times.

## Moving the HUD around (the HUD editor)

Where every piece of the play screen goes is in `src/client/UiLayout.luau`. The HUD editor is a web
page that draws those pieces on a phone, tablet or PC screen, in the game's own colours and fonts,
over a drawing of the game, so they can be dragged into place. It shows the scenes they appear in
(at the shop, mowing a job, a story scene...) and flags pieces that overlap, or sit under Roblox's
own buttons or in a phone's notch.

1. `python3 scripts/build-hud-editor.py` builds the page from `UiLayout.luau` into
   `tools/hud-editor/hud-editor.html` (not committed). It's published as the "Lawn Mowing HUD
   Editor" artifact; rebuild and republish it when pieces are added or taken out.
2. In the editor, pick a screen and a scene, drag the pieces, and press **Save layout**. The layout
   goes into the artifact's own database (`layouts/current`, with the save before it in
   `layouts/previous`).
3. Then `python3 scripts/apply-hud-layout.py <saved.json>`, with that document saved as JSON,
   writes the placement values (screen, parent, order, list, anchor, position, size, scale, touch
   and compact) into `UiLayout.luau`. A field the save leaves out stays as it is, and one that's
   null comes out; inside touch, compact and list it's the same, key by key. It leaves everything
   else alone, runs stylua, and checks the file reads back as the save says (`--dry-run` only
   says what it would change). Then the usual checks, a playtest on a phone and a PC in Studio,
   and a PR.

## How the game plays

1. **Your business.** Everyone gets a business plot in town: the shop is your hub. Inside are
   the job computer, storage for your tools and a spot by the door where deliveries arrive, and
   your crew truck waits out front. It starts as a **Tool Shed** and can be upgraded to
   a **Garage**, a **Small Office** and an **Equipment Yard**. Each upgrade pays more per job and
   stores more: hand tools hang on pegboards, long tools stand in wall racks, power tools hang on
   hooks, supplies sit on shelves, mowers park on floor spots and ride-on machines in equipment
   bays. You can't buy a tool you have nowhere to store (the shed has no room for a gas mower), so
   sell what you don't use (half price back) or upgrade.
2. **Take a job.** At the shop computer (look at it and press E) the crew leader picks a job in
   the **Jobs** app; everyone can look. The **Messages** app has the story's texts (from
   Grandma June, who sits on her porch beside your shop) and your next goal. Customers say what they want done
   and hint at how ("it has to look immaculate" or "just knock it down before noon"), but **no job
   ever says which tool to use**. Every tool's description in the shop, the Truck checklist and
   the **Guide** says what it's for; knowing your tools is the game. New players get a coach for
   their first job.
3. **Load the truck by hand.** Look at a tool in your storage and press **E** (or tap the big
   button on a phone, or **Grab** in the **Truck** menu) to take it, carry it to the truck, look
   at the bed and press **E** to set it down where the ghost shows (red means it won't fit there).
   Mowers are pushed along the ground instead of carried, and ride-ons are driven up the equipment
   trailer's ramp and parked on a bay. Hand tools can go in the **tool bucket** (look at it while
   holding one; **R** takes one back out). Look at a loaded tool to take it back out, and at a free
   spot in storage to put a tool back there. Only tools in the truck come with you, and you only get them in
   your hotbar once you reach the house. Every tool takes truck space: hand and long tools 1, power
   tools 2, mowers 4, and a **tool bucket** packs up to 8 hand tools into 1. The rusty pickup holds
   **6**. Once it's full, **trailers unlock** in the Business app. Riding mowers only travel on
   an **equipment trailer**. The **Truck** menu shows every tool, its space and where it is.
4. **Drive.** The leader looks at the truck's driver door and gets in. Everyone's view moves
   into the cab as the truck pulls out of the driveway, then the drive cutscene plays and the
   crew arrives at the house. Back home, the truck pulls back in at the door.
5. **Do the yard.** Mow the grass, edge the sidewalk and driveway, cut back the long grass along
   the house, clear the leaf piles and shape the hedges. Garden jobs happen in the side garden:
   pot up plants, plant seedlings and bulbs, sow rows, weed and loosen beds, dig out dandelions,
   prune shrubs and roses (bring gloves for the thorns) and water beds and seedlings. Serious
   jobs dig planting holes (some in rocky ground), lift sod, loosen and turn beds, spread mulch,
   cut branches, haul soil, stone and leaves from a delivered pile with a barrow (one wheel can
   tip!), feed the lawn and spot-spray weeds (with chemical gloves). Mowers work while equipped;
   grass shears (what everyone starts with) cut one snip at a time where you aim (click, or hold
   to keep snipping); every other tool works while you hold the mouse button. Sticks, toys and
   rocks hide in the grass: pick them up (E) before you cut there, or a mower chews them up and
   blunts its blade. A tool that can't do a job says "That won't work here"; a tool that can but
   isn't the best fit works slower and pays less.
6. **Get paid.** Pay depends on:
   - **Tool fit:** the right tools pay in full, okay ones 80%, poor ones 55%.
   - **Finish and speed:** how clean the work is (reel mowers cut cleanest) and how it compares
     to the par time, weighted by what the customer cares about.
   - **Accuracy:** each flower patch or garden gnome you run over with a mower, trimmer or edger
     costs 10% of the job's pay, and each bit of junk left in the grass (or chewed up by a mower)
     4% and a little of the finish.
   - **Bonuses:** bigger crews, better trucks, a bigger business and your business's **curb
     appeal** all pay more.
   The money is split evenly across the crew, then the truck drives everyone back to the business.
   Pro jobs mow show lawns, knee-high grass and tight lawns full of trees, and renovate turf in
   order: probe the soil, dethatch, aerate (moist soil!), overseed (50-65 F soil), fertilize and
   water. The probe tells you the soil's temperature and moisture; the customer only hints.
7. **Look after your gear.** Engines burn fuel (regular gas for four-strokes, mix for
   two-strokes: the wrong one wrecks the engine), air tires go soft and puncture, blades go dull
   and trimmers run out of line. The HUD tells you when something's wrong, never how to fix it,
   and the tools show it: sputtering smoke, sagging tires, a bare spool, ragged grass. Fix things
   by hand: set the machine down in front of the workbench (hand tools go in its vise) or behind
   the truck on a job, then hold a supply, look at it and hold E to pour, pump, plug, wind or
   sharpen. A mower's blade comes off with the wrench first.
8. **Upgrade.** Order better tools on the shop computer's **Orders** app (grass shears → reel push
   mower → gas → self propelled → riding → zero-turn, and so on for each tool): they're delivered in a box to
   your shop a few seconds later, and you open it and put the tool away. Trucks, trailers and
   building upgrades are in the **Business** app. Serious gear needs level 3 and a garage; pro
   gear needs level 8 and a small office. Sell what you don't use from the Orders app.
9. **Keep your own lawn.** Your business has a front lawn of its own, left of the driveway. Take
   your tools off the wall and use them on it: they work and wear just like on a job. It grows
   back while you play (all of it in about 40 minutes) and remembers where you left it. A tidy
   lawn gives your business **curb appeal** (shown under your money), worth up to +15% on every
   job, and tidying it up again now and then earns a neighbor's tip.
10. **Decorate.** The Orders app's **Decorations** tab has fences, edging, paths, mulch beds,
    shrubs, a maple, planters, a bird bath, a fountain, an arbor, a bench, a patio set, a fire pit,
    a mailbox, lights, a windmill and the odd flamingo. Each comes in a box: open it and put it
    where you like in first person (R turns it, fences and paths snap together). Decorations add
    to curb appeal, and shrubs need a trim now and then.
11. **Win Best Yard.** At the end of the story Grandma June enters your yard in the Maple Grove
    Best Yard contest against Gloria's, which TurfKing does. Call the judges from the Messages app
    when it's ready: they score your lawn, edges, beds and shrubs, and decorations, out of 25 each.

### Controls

You play in first person. Look around with the mouse (drag on a phone), move with WASD or the
thumbstick and aim with the dot in the middle of the screen: **E** (or the big button on a phone)
uses what you're looking at, and **R** takes a tool out of the tool bucket. Menus: **J** jobs, **T** truck,
**B** shop, **G** guide, **C** crew, or tap the buttons. The mouse is locked to the middle of the
screen; it's freed while a menu is open, or hold **Left Alt**. **V** switches camera motion (head
bob, engine shake) on and off, and so does the switch at the top of the Guide.

### Crews

Open **Crew** to invite players (up to 4). The crew hangs out at the leader's business and rides in
the leader's truck, so everyone carries their own tools to the leader's truck and shares its space.
Each player only sees their own tools in storage, and only you can take your tools back out of the
truck. Only the leader accepts jobs and drives. Leaving the crew in the middle of a job sends you back to your own business.

## Project layout

```
default.project.json         Rojo project: maps the folders below into the game
rokit.toml                   Tool versions (Rojo, Selene, StyLua, Lune)
place/base.rbxl              the Studio-made parts scripts/publish.py publishes the code into
assets/                      -> ServerStorage.Assets       real models go here (see below); copies of
                                the few that client code clones -> ReplicatedStorage.Assets
src/shared/                  -> ReplicatedStorage.Shared   code used by both server and client
  Config/GameConfig.luau        balance numbers: travel time, pay formula, penalties, leveling...
  Config/Tools.luau             every tool: tier, verbs, size class, stats, what it's for
  Config/TaskTypes.luau         every kind of task and which tools fit it (ideal/good/poor)
  Config/Jobs.luau              job types: customers, stories, yard, tasks, par time, pay
  Config/Items.luau             the shop tabs: tools from Tools.luau, trucks, trailers, businesses
  Config/Storage.luau           storage spots at the business and truck space
  Config/Story.luau             the story (docs/STORY.md): every line, beat and act gate
  Config/TurfKing.luau          TurfKing taking jobs off your board, and customers won back from it
  Config/Contest.luau           the Best Yard contest: scoring, Gloria's bar, rewards, when it's on
  Config/Milestones.luau        the goals rail's milestones (jobs, money earned, three-star jobs) and what each pays
  Config/Levels.luau            what each level pays: cash, a truck tint, the gold sign, a HUD stamp
  Config/Stars.luau             how a job's performance earns one to three stars, and the tip they bring
  Config/Season.luau            the Busy Season's part of the save, and who still counts as a first-timer
  Config/GuiArt.luau            GENERATED: the GUI art's image ids, slices, palette and bitmap fonts
                                (scripts/gui-art-ids.py; see HANDOFF.md, "GUI art")
  GuiLayout.luau                the GUI's layout maths: bitmap text, the hold ring, striped fills
  PayBreakdown.luau             a finished job's pay split into dollar lines for the pay breakdown
  Shop.luau                     what a player may buy (shared by the server and the shop menu)
  Assets.luau                   finds a real model or falls back to a placeholder
  Placeholders.luau             the block models used until real ones exist
  Net.luau                      every RemoteEvent / RemoteFunction name
src/server/                  -> ServerScriptService.Server
  init.server.luau              starts every service
  BusinessStorage.luau          lays out the pegboards, racks, hooks, shelves, floor spots and bays
  Services/DataService          saving money, xp, gear and truck loadout (with save migrations)
  Services/WorldService         the town, business plots and buildings
  Services/PartyService         crews, invites, shared truck space
  Services/LawnService          builds each yard and tracks the work done
  Services/JobService           jobs, driving, timing, payouts, damage
  Services/DeliveryService      ordered tools arriving in boxes at the shop
  Services/ToolService          gives tools and applies their work every tick
  Services/TruckService         carrying tools from storage to the truck and back
  Services/ShopService          buying, selling and equipping
  Services/StoryService         the story: acts, beats, scenes to play and texts
  Services/GloriaService        Gloria's house across the street, and her yard for every act
  Services/TurfKingService      TurfKing taking jobs off your board, and the won-back bonus
  Services/ContestService       the Best Yard contest: judging your yard, the result and rewards
  Services/SeasonService        paying each milestone and level reward once, and telling the screen
src/client/                  -> StarterPlayer.StarterPlayerScripts.Client
  init.client.luau              starts every controller
  Controllers/                  HUD, shop computer (jobs, orders, business), truck checklist, carrying tools, crew menu,
                                drive cutscene, first-person camera and arms, the story's dialogue,
                                the Messages app, Gloria's yard as your act has it, and the Best
                                Yard contest's judges and results screen
  Controllers/LevelsController  the Levels panel: your level, and what the next five levels pay
  UI.luau                       the look: colours, fonts, windows, cards, buttons, bars, prompts
  UiLayout.luau                 where everything on the play screen goes, as plain data for the
                                layout editor (lune run scripts/ui-layout-json prints it as JSON)
  Art.luau                      the GUI art by name (plain frames wherever an id is still "")
  BitmapText.luau               money, scores, timers and headlines in the display font's atlases
  Goal.luau                     your story goal, for the Messages app and Grandma's sticky note
  FloatingText.luau             a few words that lift off a piece of the HUD and fade: "+$30", "+40 XP"
  StoryArt.luau                 the story's art: portraits by mood, dialogue box, bubbles, contest
```

Most balancing happens in the files in `src/shared/Config/`, no other code changes needed. The
full design (realistic tools, storage, maintenance, and the phase plan) is in
[`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## Swapping in real models

Models live in `assets/`, sorted into folders, which Rojo puts in `ServerStorage.Assets`. Name
each model after the item's `id` from `src/shared/Config/Items.luau` and the game uses it instead
of the placeholder.

Only the server reads them there, so they don't add to anyone's join time. What it builds into
the world streams to the players near it. Clients get two kinds of copies:
- **Models that client code clones itself.** These are copied to `ReplicatedStorage.Assets`, which
  every client downloads when it joins, so keep that set small. They're listed in
  `default.project.json`: the grass clumps, the decorations, the gnome and the flower patch, and
  the judges. If new client code clones a model, add it there, or that screen gets the
  placeholder.
- **What only one player's screen needs.** That screen gets its own copies (`Assets.shareWith`):
  the tools the player owns, which it lays out in storage, and the crew's truck and trailer, just
  before the drive cutscene.

| Folder | Name it | What it should be |
| --- | --- | --- |
| `Assets/Tools` | e.g. `GasPushMower`, `LeafBlower` | A `Tool` with a `Handle`, or just a Model (it gets wrapped in a Tool for you) |
| `Assets/Trucks` | e.g. `RustyPickup` | A Model facing forward along its pivot's front (LookVector). Add an invisible Part named `BedArea` where loaded tools should lie (how much it holds comes from `Items.luau`) |
| `Assets/Trailers` | `UtilityTrailer`, `LandscapeTrailer`, `EquipmentTrailer` | A Model with the hitch facing forward, plus its own `BedArea` part. The equipment trailer also has two `BaySpot` parts where ride-on machines park |
| `Assets/Buildings` | `Shed`, `Garage`, `SmallOffice`, `EquipmentYard` | A Model with the front door facing forward |
| `Assets/Props` | `House`, `FlowerPatch`, `GardenGnome` | Models for the customer's yard |
| `Assets/Props` | `StoragePegboard`, `StorageWallRack`, `StorageWallHooks`, `StorageShelf` | Storage at the business: back flat on Z = 0, front toward -Z, with `Slot1`, `Slot2`... attachments where tools go |
| `Assets/Story` | e.g. `GloriaHouse`, `GloriaYard_Stage1`, `PorchRockingChair` | The story's places and props (ids in alphainstructions/instructions37.md): origin on the ground, front toward -Z, a `Root` part. The people are not files: `CastService` builds them as Roblox rigs |

There are two ways to add them:

- **In Studio:** drop the model into the right folder under `ServerStorage.Assets`. Rojo leaves
  models added this way alone. Save the place to keep them. `scripts/publish.py` publishes what's
  in `assets/`, though, so save it to a file as well.
- **As files (recommended, so they're in git):** right-click the model → *Save to File* as `.rbxm`
  into the matching `assets/` folder, e.g. `assets/Trucks/RustyPickup.rbxm`. Rojo syncs it into
  the game.

You can also build your own town in Studio: make a Model named `Town` in Workspace with a
`SpawnLocation` and a `Plots` folder with one Part per business plot (front facing the street). The placeholder
town is only built when there's no `Town`.

Set the place's max players to 12 or fewer (Game Settings → Places), since the placeholder town has
12 business plots.
