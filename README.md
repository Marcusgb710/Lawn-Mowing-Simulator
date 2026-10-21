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

**Testing saves in Studio:** Game Settings → Security → turn on *Enable Studio Access to API
Services*. Without it the game still runs, it just doesn't save progress.

**Testing crews:** Test tab → Clients and Servers → pick 2–4 players → Start.

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
   the **Jobs** app; everyone can look. Customers say what they want done
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
rokit.toml                   Tool versions (Rojo, Selene, StyLua)
assets/                      -> ReplicatedStorage.Assets   real models go here (see below)
src/shared/                  -> ReplicatedStorage.Shared   code used by both server and client
  Config/GameConfig.luau        balance numbers: travel time, pay formula, penalties, leveling...
  Config/Tools.luau             every tool: tier, verbs, size class, stats, what it's for
  Config/TaskTypes.luau         every kind of task and which tools fit it (ideal/good/poor)
  Config/Jobs.luau              job types: customers, stories, yard, tasks, par time, pay
  Config/Items.luau             the shop tabs: tools from Tools.luau, trucks, trailers, businesses
  Config/Storage.luau           storage spots at the business and truck space
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
src/client/                  -> StarterPlayer.StarterPlayerScripts.Client
  init.client.luau              starts every controller
  Controllers/                  HUD, shop computer (jobs, orders, business), truck checklist, carrying tools, crew menu,
                                drive cutscene, first-person camera and arms
```

Most balancing happens in the files in `src/shared/Config/`, no other code changes needed. The
full design (realistic tools, storage, maintenance, and the phase plan) is in
[`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## Swapping in real models

Models live in `ReplicatedStorage.Assets`, sorted into folders. Name each model after the item's
`id` from `src/shared/Config/Items.luau` and the game uses it instead of the placeholder:

| Folder | Name it | What it should be |
| --- | --- | --- |
| `Assets/Tools` | e.g. `GasPushMower`, `LeafBlower` | A `Tool` with a `Handle`, or just a Model (it gets wrapped in a Tool for you) |
| `Assets/Trucks` | e.g. `RustyPickup` | A Model facing forward along its pivot's front (LookVector). Add an invisible Part named `BedArea` where loaded tools should lie (how much it holds comes from `Items.luau`) |
| `Assets/Trailers` | `UtilityTrailer`, `LandscapeTrailer`, `EquipmentTrailer` | A Model with the hitch facing forward, plus its own `BedArea` part. The equipment trailer also has two `BaySpot` parts where ride-on machines park |
| `Assets/Buildings` | `Shed`, `Garage`, `SmallOffice`, `EquipmentYard` | A Model with the front door facing forward |
| `Assets/Props` | `House`, `FlowerPatch`, `GardenGnome` | Models for the customer's yard |
| `Assets/Props` | `StoragePegboard`, `StorageWallRack`, `StorageWallHooks`, `StorageShelf` | Storage at the business: back flat on Z = 0, front toward -Z, with `Slot1`, `Slot2`... attachments where tools go |

There are two ways to add them:

- **In Studio:** drop the model into the right folder under `ReplicatedStorage.Assets`. Rojo leaves
  models added this way alone. Save the place to keep them.
- **As files (recommended, so they're in git):** right-click the model → *Save to File* as `.rbxm`
  into the matching `assets/` folder, e.g. `assets/Trucks/RustyPickup.rbxm`. Rojo syncs it into
  the game.

You can also build your own town in Studio: make a Model named `Town` in Workspace with a
`SpawnLocation` and a `Plots` folder with one Part per business plot (front facing the street). The placeholder
town is only built when there's no `Town`.

Set the place's max players to 12 or fewer (Game Settings → Places), since the placeholder town has
12 business plots.
