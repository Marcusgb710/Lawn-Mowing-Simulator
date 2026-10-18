# Lawn Mowing Simulator

A Roblox lawn care game for crews of 1–4 players. Run your own lawn care business, take jobs from
the job board, load the right tools into your truck, drive out to the house and get the yard done
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

1. **Your business.** Everyone gets a business plot in town. It has a job board, storage for your
   tools and your crew truck parked out front. It starts as a **Tool Shed** and can be upgraded to
   a **Garage**, a **Small Office** and an **Equipment Yard**. Each upgrade pays more per job and
   stores more: hand tools hang on pegboards, long tools stand in wall racks, power tools hang on
   hooks, supplies sit on shelves, mowers park on floor spots and ride-on machines in equipment
   bays. You can't buy a tool you have nowhere to store (the shed has no room for a gas mower), so
   sell what you don't use (half price back) or upgrade.
2. **Take a job.** At the job board the crew leader picks a job. Customers say what they want done
   and hint at how ("it has to look immaculate" or "just knock it down before noon"), but **no job
   ever says which tool to use**. Every tool's description in the shop, the Truck checklist and
   the **Guide** says what it's for; knowing your tools is the game. New players get a coach for
   their first job.
3. **Load the truck by hand.** Walk up to a tool in your storage and press **E** to pick it up (or
   tap **Grab** in the **Truck** menu), carry it to the truck and press **E** again to load it.
   Mowers are pushed along the ground instead of carried. To take a tool back out, press **R** on
   it in the truck and put it back. Only tools in the truck come with you, and you only get them in
   your hotbar once you reach the house. Every tool takes truck space: hand and long tools 1, power
   tools 2, mowers 4, and a **tool bucket** packs up to 8 hand tools into 1. The rusty pickup holds
   **6**. Once it's full, **trailers unlock** at the hardware store. Riding mowers only travel on
   an **equipment trailer**. The **Truck** menu shows every tool, its space and where it is.
4. **Drive.** The leader hops in the truck. Everyone watches the drive cutscene and arrives at the
   house.
5. **Do the yard.** Mow the grass, edge the sidewalk and driveway, cut back the long grass along
   the house, clear the leaf piles and shape the hedges. Garden jobs happen in the side garden:
   pot up plants, plant seedlings and bulbs, sow rows, weed and loosen beds, dig out dandelions,
   prune shrubs and roses (bring gloves for the thorns) and water beds and seedlings. Serious
   jobs dig planting holes (some in rocky ground), lift sod, loosen and turn beds, spread mulch,
   cut branches, haul soil, stone and leaves from a delivered pile with a barrow (one wheel can
   tip!), feed the lawn and spot-spray weeds (with chemical gloves). Mowers work while equipped; every other
   tool works while you hold the mouse button. A tool that can't do a job says "That won't work
   here"; a tool that can but isn't the best fit works slower and pays less.
6. **Get paid.** Pay depends on:
   - **Tool fit:** the right tools pay in full, okay ones 80%, poor ones 55%.
   - **Finish and speed:** how clean the work is (reel mowers cut cleanest) and how it compares
     to the par time, weighted by what the customer cares about.
   - **Accuracy:** each flower patch or garden gnome you run over with a mower, trimmer or edger
     costs 10% of the job's pay.
   - **Bonuses:** bigger crews, better trucks and a bigger business all pay more.
   The money is split evenly across the crew, then the truck drives everyone back to the business.
7. **Look after your gear.** Engines burn fuel (regular gas for four-strokes, mix for
   two-strokes: the wrong one wrecks the engine), air tires go soft and puncture, blades go dull
   and trimmers run out of line. The HUD tells you when something's wrong, never how to fix it.
   Fix things at the workbench at your business, or at the truck's tailgate on a job with the
   supplies you brought.
8. **Upgrade.** Spend money at the hardware store on better tools (reel push mower → gas → self
   propelled → riding → zero-turn, and so on for each tool), trucks, trailers and business
   upgrades. Serious gear needs level 3 and a garage; pro gear needs level 8 and a small office.

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
  Services/JobService           job board, driving, timing, payouts, damage
  Services/ToolService          gives tools and applies their work every tick
  Services/TruckService         carrying tools from storage to the truck and back
  Services/ShopService          buying, selling and equipping
src/client/                  -> StarterPlayer.StarterPlayerScripts.Client
  init.client.luau              starts every controller
  Controllers/                  HUD, job board, shop, truck checklist, carrying tools, crew menu,
                                drive cutscene
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
`SpawnLocation`, a ProximityPrompt with the attribute `OpensPanel = "Shop"` for the hardware store,
and a `Plots` folder with one Part per business plot (front facing the street). The placeholder
town is only built when there's no `Town`.

Set the place's max players to 12 or fewer (Game Settings → Places), since the placeholder town has
12 business plots.
