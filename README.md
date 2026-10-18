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

1. **Your business.** Everyone gets a business plot in town. It has a job board, a tool rack and
   your crew truck parked out front. It starts as a **Tool Shed** and can be upgraded to a
   **Garage** and then a **Small Office** (each upgrade pays more per job).
2. **Take a job.** At the job board the crew leader picks a job. Each job lists the tools it needs
   (mower, edger, weed whacker, rake, hedge trimmer).
3. **Load the truck.** At the tool rack, load the tools the job needs. Only tools in the truck come
   with you. The truck bed holds **3 tools**. Once your bed is full, **trailers unlock** at the
   hardware store and give you more room.
4. **Drive.** The leader hops in the truck. Everyone watches the drive cutscene and arrives at the
   house.
5. **Do the yard.** Mow the grass, edge the sidewalk and driveway, whack the weeds, rake the leaf
   piles and trim the hedges. Mowers work while equipped; every other tool works while you hold the
   mouse button.
6. **Get paid.** Pay depends on:
   - **Speed:** beat the job's par time for up to +25%, go slow and lose up to 50%.
   - **Accuracy:** each flower patch or garden gnome you run over with a mower, weed whacker or
     edger costs 10% of the job's pay.
   - **Bonuses:** bigger crews, better trucks and a bigger business all pay more.
   The money is split evenly across the crew, then the truck drives everyone back to the business.
7. **Upgrade.** Spend money at the hardware store on better tools (reel push mower → gas → self
   propelled → riding → zero-turn, and so on for each tool), trucks, trailers and business
   upgrades.

### Crews

Open **Crew** to invite players (up to 4). The crew hangs out at the leader's business and rides in
the leader's truck, so everyone's loaded tools share the leader's truck bed. Only the leader accepts
jobs and drives. Leaving the crew in the middle of a job sends you back to your own business.

## Project layout

```
default.project.json         Rojo project: maps the folders below into the game
rokit.toml                   Tool versions (Rojo, Selene, StyLua)
assets/                      -> ReplicatedStorage.Assets   real models go here (see below)
src/shared/                  -> ReplicatedStorage.Shared   code used by both server and client
  Config/GameConfig.luau        balance numbers: travel time, payouts, penalties, leveling...
  Config/Items.luau             every shop item: tools, trucks, trailers, business upgrades
  Config/Jobs.luau              job types: lawn size, tasks, flower patches, par time, pay
  Assets.luau                   finds a real model or falls back to a placeholder
  Placeholders.luau             the block models used until real ones exist
  Net.luau                      every RemoteEvent / RemoteFunction name
src/server/                  -> ServerScriptService.Server
  init.server.luau              starts every service
  Services/DataService          saving money, xp, gear and truck loadout
  Services/WorldService         the town, business plots and buildings
  Services/PartyService         crews, invites, shared truck space
  Services/LawnService          builds each yard and tracks the work done
  Services/JobService           job board, driving, timing, payouts, damage
  Services/ToolService          gives tools and applies their work every tick
  Services/ShopService          buying, equipping, loading the truck
src/client/                  -> StarterPlayer.StarterPlayerScripts.Client
  init.client.luau              starts every controller
  Controllers/                  HUD, job board, shop, truck loading, crew menu, drive cutscene
```

Most balancing happens in the three files in `src/shared/Config/`, no other code changes needed.

## Swapping in real models

Models live in `ReplicatedStorage.Assets`, sorted into folders. Name each model after the item's
`id` from `src/shared/Config/Items.luau` and the game uses it instead of the placeholder:

| Folder | Name it | What it should be |
| --- | --- | --- |
| `Assets/Tools` | e.g. `GasPushMower`, `LeafBlower` | A `Tool` with a `Handle`, or just a Model (it gets wrapped in a Tool for you) |
| `Assets/Trucks` | e.g. `RustyPickup` | A Model facing forward along its pivot's front (LookVector) |
| `Assets/Trailers` | `UtilityTrailer`, `LandscapeTrailer` | A Model with the hitch facing forward |
| `Assets/Buildings` | `Shed`, `Garage`, `SmallOffice` | A Model with the front door facing forward |
| `Assets/Props` | `House`, `FlowerPatch`, `GardenGnome` | Models for the customer's yard |

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
