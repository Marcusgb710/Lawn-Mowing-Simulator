# Lawn Mowing Simulator: Game Design

Realistic tools, jobs, storage and maintenance. This is the plan the game is being built toward,
one phase (and one PR) at a time. The config files in `src/shared/Config/` are the source of
truth for numbers; this doc explains the rules behind them.

## Goal

A detailed, accurate gardening and lawn-care game.

- **Jobs never say which tool to use.** The customer's story and to-do list hint at it, and the
  player has to know their tools.
- **Every tool has an accurate "what it's for" description** in the shop and the truck checklist.
  That's how players learn.
- **Wrong-but-capable tools still work, for less pay.** Tools that can't do a task at all just
  get "That won't work here", which never names the right tool.
- **Players can't bring everything.** Storage at the business and space in the truck force
  real choices.

## Constraints

- Never rename or remove an existing item id. Saves and the models being built for them use the
  ids: `House`, `FlowerPatch`, `GardenGnome`, `Shed`, `Garage`, `SmallOffice`, `RustyPickup`,
  `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck`, `UtilityTrailer`, `LandscapeTrailer`,
  `ReelMower`, `GasPushMower`, `SelfPropelledMower`, `RidingMower`, `ZeroTurnMower`,
  `GardenShears`, `ElectricTrimmer`, `GasTrimmer`, `Brushcutter`, `OldRake`, `WideRake`,
  `LeafBlower`, `BackpackBlower`, `HalfMoonEdger`, `ElectricEdger`, `GasStickEdger`,
  `WalkBehindEdger`, `HandHedgeShears`, `ElectricHedgeTrimmer`, `CordlessHedgeTrimmer`,
  `GasHedgeTrimmer`. (Display names may change; ids may not.)
- Don't edit `alphainstructions/`. The local session writes model specs there from the
  [new item list](#new-item-ids-for-modelers) below.
- Every new item works right away with a block placeholder (`src/shared/Placeholders.luau`).
- Saves are migrated in `DataService`: players always keep their money, level and owned items.
- Mobile-friendly, and the game stays playable after every PR.

## 1. Verbs and tool fit

Every tool has one or more **verbs**:

> Dig, Plant, Cultivate (loosen or stir soil), Weed, Prune, Water, Protect (worn, not used), Mow,
> Trim (string trimming), Edge, Shear (hedges), Rake, Blow, Haul, Spread (granular), Spray
> (liquid), Aerate, Seed, Dethatch, Measure.

Every job task has a **task type** with one verb and a **fit table**
(`src/shared/Config/TaskTypes.luau`):

| Fit | Work speed and pay | Which tools |
| --- | --- | --- |
| Ideal | 100% | listed as `ideal` |
| Good | 80% | listed as `good` |
| Poor | 55% | listed as `poor`, **or any tool with the task's verb that isn't listed** |
| Can't | - | a tool without the verb that isn't listed, anything in `exclude`, or a mower whose `maxGrassHeight` is below the task's `grassHeight` |

- A listed tool always counts, even without the verb (a leaf blower is a Good fit for clearing
  leaves, and grass shears are a Good fit for mowing a small lawn by hand; see "Starting out").
- `qualityHits` lower the finish some tools leave on a task (a bow rake tears turf: x0.6;
  anvil pruners crush live stems: x0.7).
- `speedHits` slow some tools down further (a shovel on hard ground: x0.6).
- `protection` (`Thorns`, `Chemicals`) means the task needs gloves that protect against it
  (phase C/D).

When a player uses a tool on targets it can't work, they're told **"That won't work here."**
(at most every few seconds), and never which tool would. Walking over lawn grass doesn't count
while the tool still has work left on the job, and a mower idling while you stand still stays
quiet.

## 2. Tools by tier

The full catalog, with stats and the player-facing descriptions, is
`src/shared/Config/Tools.luau`. Every shop tab progresses Homeowner, then Serious, then Pro.
Buying a tier needs a player level and a business at least this big (`Tools.TierUnlocks`); tools
you already own stay yours either way:

| Tier | Level | Business |
| --- | --- | --- |
| Homeowner | 1 | Shed |
| Serious | 3 | Garage |
| Pro | 8 | Small Office |

**Size classes** decide where a tool is stored and how much truck space it takes:

| Size class | Stored on | Examples |
| --- | --- | --- |
| `Hand` | pegboard | trowels, pruners, snips, gloves, soil probe, pruning saw, hedge shears |
| `Long` | wall rack | shovels, spade, forks, broadfork, rakes, hoe, mattock, loppers, half-moon edger |
| `HangingPower` | wall hooks | string trimmers, stick edgers, hedge trimmers, blowers, backpack sprayer, garden hose |
| `FloorManual` | floor spot | reel mower, wheelbarrows, carts, broadcast spreader |
| `FloorEngine` | floor spot | gas push and self-propelled mowers, walk-behind edger, dethatcher, overseeder, greens reel mower |
| `Bay` | equipment bay | riding, zero-turn, stand-on and ride-on machines, aerators |
| `Supply` | shelf | fuel cans, trimmer line, spare parts, sharpening and tire tools (added: the spec had no class for consumables) |

### Existing items, re-tiered

| Tier | Items |
| --- | --- |
| Homeowner | ReelMower, GasPushMower, GardenShears, ElectricTrimmer, OldRake, HalfMoonEdger, ElectricEdger, HandHedgeShears, ElectricHedgeTrimmer |
| Serious | SelfPropelledMower, RidingMower, ZeroTurnMower (residential), GasTrimmer, WideRake, LeafBlower, WalkBehindEdger, CordlessHedgeTrimmer, GasHedgeTrimmer |
| Pro | Brushcutter, BackpackBlower, GasStickEdger |

`GasStickEdger` moved to Pro, so it swapped price and power with `WalkBehindEdger` ($2,200 /
3.5 Serious, $8,500 / 6 Pro). `GardenShears` is now described as hand grass shears and
`OldRake` as a leaf (fan) rake, matching what they do in the game.

### Starting out

You start from the bottom: a new player's only tool is a free pair of **grass shears**
(`GardenShears`, price 0), and the **reel push mower** (`ReelMower`) is the first thing they buy,
for **$150**: the pay of 2-3 early jobs with the shears.

- **Shears cut by hand, a snip at a time** (`snip` in `Tools.luau`, `SnipController`, `ToolService`).
  Each click (or tap, or the **Snip** button on a phone) cuts the one thing nearest where you aim:
  a grass tile, or a weed. Holding the button keeps snipping, two snips a second. A snip lands
  where your aim crosses grass-top height (1 stud up), up to 7.5 studs from your eyes, so you look
  down at the grass and move along as you go. The client only says which way you're looking; the
  server works out where that lands and what's there, and limits snips to the shears' rhythm.
- **Tall grass takes several snips.** The shears are listed as a Good fit for `MowSmallLawn` (x0.8),
  so a snip does 0.225 x 0.8 = 0.18 of a tile: **6 snips a tile** (7 once they're dull), and 12 for
  a weed. The tile gets shorter every quarter of the way (`LawnGrid.PARTLY_CUT`), and the shears
  wear like any fine edge (a sharpening stone fixes them). They have no Mow verb, so their blade
  stays a fine one, and they can't do any lawn bigger than a small one.
- **In first person** the shears sit low in front of you, tipped down at the grass, following
  your view, and jab forward with every snip (`SNIP_POSE`, `SNIP_JAB` in `ArmsController`). Only
  snips that cut something throw clippings.
- Snips only hurt a flower patch they land right on (0.3 studs), not everything around them.
- **Existing players keep their reel mower** (save version 9, below) and get the shears too.
  Selling the reel mower now gives half its price back, like any bought tool.

### New tools

| Tier | Id | Verbs | Size | What it's for |
| --- | --- | --- | --- | --- |
| Homeowner | HandTrowel | Dig, Plant, Weed | Hand | small planting holes, transplanting, potting up |
| Homeowner | HandTransplanter | Dig, Plant | Hand | bulbs and plugs at an exact depth; not for potting |
| Homeowner | HandCultivator | Cultivate, Weed | Hand | loosening the top few inches, shallow weeds |
| Homeowner | DandelionWeeder | Weed | Hand | taprooted weeds out whole |
| Homeowner | Dibber | Plant | Hand | even holes for seeds, seedlings, small bulbs; can't scoop |
| Homeowner | BypassPruners | Prune | Hand | clean cuts on live stems up to 3/4 in |
| Homeowner | AnvilPruners | Prune | Hand | dead, dry, woody stems; crushes live ones |
| Homeowner | FloralSnips | Prune | Hand | deadheading, herbs, cut flowers; no woody stems |
| Homeowner | GardenHoseWand | Water | HangingPower | beds, shrubs, baskets; too harsh for seedlings |
| Homeowner | WateringCan | Water | Hand | gentle water for seedlings and new seed; slow |
| Homeowner | NitrileGloves | Protect | Hand | wet, rough work and thorns; not chemical-proof |
| Serious | RoundPointShovel | Dig, Haul | Long | digging holes, scooping loose material |
| Serious | GardenSpade | Dig, Edge | Long | clean bed edges, sod, straight trenches |
| Serious | Broadfork | Cultivate | Long | loosening beds 12-16 in deep without flipping layers |
| Serious | DiggingFork | Dig, Cultivate | Long | heavy or stony soil, lifting roots, compost |
| Serious | BowRake | Rake | Long | leveling soil, spreading mulch; tears turf |
| Serious | StirrupHoe | Weed | Long | young weeds between rows; useless on deep roots |
| Serious | Mattock | Dig | Long | hard, rocky ground and roots |
| Serious | Loppers | Prune | Long | branches 1-2 in |
| Serious | PruningSaw | Prune | Hand | branches over 1.5 in |
| Serious | SingleWheelbarrow | Haul | FloorManual | nimble, can tip; air tire |
| Serious | SingleWheelbarrowFlatFree | Haul | FloorManual | never flat, a bit slower |
| Serious | DualWheelbarrow | Haul | FloorManual | stable, heavy loads, less nimble; air tires |
| Serious | PolyCart | Haul | FloorManual | big, light loads (leaves, mulch); flat-free |
| Serious | BroadcastSpreader | Spread, Seed | FloorManual | granular fertilizer, seed or lime on lawns |
| Serious | BackpackSprayer | Spray | HangingPower | spot-spraying liquids |
| Serious | ChemicalGloves | Protect | Hand | required for spraying |
| Pro | CommercialZeroTurn | Mow | Bay | fastest on big open lawns |
| Pro | StandOnMower | Mow | Bay | tight properties, obstacles, slopes |
| Pro | CommercialReelMower | Mow | FloorEngine | finest cut on show lawns; no tall grass |
| Pro | StraightShaftTrimmer | Trim | HangingPower | all-day trimming with long reach |
| Pro | ArticulatingHedgeTrimmer | Shear | HangingPower | tall and wide hedges, tops |
| Pro | StandOnAerator | Aerate | Bay | core aeration; best in moist soil |
| Pro | TowBehindAerator | Aerate | Bay | core aeration, pulled by a ride-on or truck |
| Pro | SlitOverseeder | Seed | FloorEngine | seed into slits; best after aerating |
| Pro | PowerRakeDethatcher | Dethatch | FloorEngine | thatch over 1/2 in |
| Pro | RideOnSpreaderSprayer | Spread, Spray | Bay | products over large lawns |
| Pro | SoilProbe | Measure | Hand | soil temperature and moisture; nothing else measures |

## 3. Mowers and customer preferences

| Mower | Cut quality | Power | Width (radius) | Max grass (in) | Maneuverability |
| --- | --- | --- | --- | --- | --- |
| ReelMower | 0.92 | 3 | 2.5 | 3.5 | 0.8 |
| GasPushMower | 0.70 | 5 | 3.5 | 10 | 0.7 |
| SelfPropelledMower | 0.74 | 6 | 4 | 10 | 0.7 |
| RidingMower | 0.76 | 8 | 6 | 8 | 0.4 |
| ZeroTurnMower | 0.78 | 12 | 8 | 8 | 0.75 |
| CommercialZeroTurn | 0.85 | 16 | 10 | 10 | 0.75 |
| StandOnMower | 0.82 | 13 | 7 | 10 | 0.95 |
| CommercialReelMower | 0.99 | 4 | 3 | 1.5 | 0.6 |

Reel mowers cut cleanest but are slow and can't take tall grass. Rotary mowers handle tall grass
with a medium cut. Blade sharpness (phase E) will multiply cut quality.

Each job offer gets a **customer preference**, hinted only in the story text
(`Jobs.Stories`): "Wedding photos in the backyard Saturday, it has to look immaculate" is
Quality; "Just knock it down before the HOA inspection at noon" is Speed.

| Preference | Quality weight | Time weight | How often |
| --- | --- | --- | --- |
| Quality | 0.75 | 0.25 | 25% |
| Balanced | 0.5 | 0.5 | 50% |
| Speed | 0.25 | 0.75 | 25% |

**Pay** (`GameConfig.jobPay`):

```
pay = base pay
    x tool fit         (fit of every bit of work, averaged by how much work it did)
    x (quality weight x quality multiplier + time weight x time multiplier)
    x crew, truck and business bonuses
    - damage (10% of base pay, at least $5, per flower patch or gnome hit;
              4%, at least $3, per piece of junk left in the grass or chewed up by a mower)
```

- **Quality multiplier**: 1 + (quality - 0.75) x 1.5, clamped to 0.5-1.3. The finish quality is
  the average of each tool's quality (mowers: cut quality) times any `qualityHits`, weighted by
  the work it did, minus 0.04 for every piece of junk left in the grass or chewed up
  (`GameConfig.DebrisQualityHit`).
- **Time multiplier**: 1.25 at half the par time or faster, 1 at par, down to 0.5 at twice par.
- The breakdown after a job shows the customer's preference, finish and speed scores, and how well
  the tools fit (as a percentage, never naming tools).

## 4. Jobs

Templates live in `src/shared/Config/Jobs.luau`:

- `tier`, `minLevel`, `parTime`, `basePay`, `xp`
- `lawn`: columns, rows and flower patches
- `tasks`: `{ type = <task type>, amount = n }`, in the customer's order
- `notes`: extra things this customer might say

Each offer also gets a random customer, a preference and a story. The board and the on-site
tracker show only the customer's note and the to-do lines (`TaskTypes.todo`, e.g. "Plant 12
bulbs, 6 inches deep, along the front walk"), never tools. The preference stays on the server;
players only see the story.

Since nothing checks tools any more, a crew can take a job it can't finish (and call it off).
So the board's first slot always shows a job the free starter gear can finish, and the next
slots are level 1 jobs. `Jobs.luau` also refuses templates that couldn't be finished:
- a task whose yard targets don't exist yet
- two tasks sharing a target kind
- a counted task with no amount Jobs vary: some need one tool, others
several. Later phases add task `protection`, ordering, and soil conditions for pro jobs.

### The first job

With only the shears, the board's first slot is always `QuickMow` (shown as **Front Lawn**), the
one job the free gear can finish. It's built to take a new player **about 5 minutes** with the
shears:

| | |
| --- | --- |
| Lawn | 9 x 7 tiles, 1 flower patch: 62 grass tiles. The 8 around the flowers are optional, so it's done at 95% of the other 54 = **52 tiles** |
| Snipping | 52 tiles x 6 snips x 0.5 s = **156 s** |
| Re-aiming | about one lost beat (0.5 s) per tile = **26 s** |
| Walking | a few steps every few tiles (you reach about 6 studs) = **~30 s** |
| Junk | 4 pieces to spot and pick up, ~10 s each = **~40 s** |
| Finding your feet | reading the coach, first snips = **~30 s** |
| Total | **~282 s, about 4 3/4 minutes**; par time 300 s |

It pays $70 base (offers roll $65-90). With the shears' Good fit (x0.8) and a fine finish, a
new player earns about **$66 a job**, so the $150 reel mower takes 2-3 jobs. The same lawn takes a
reel mower (about 8 studs a pass at 12 studs/s, after picking up the junk) a little over a minute,
which beats half par for the full speed bonus: about $94 a job. That's the reward for upgrading;
every later mowing job is sized for real mowers. 15 xp.

### Junk in the grass

The challenge in every lawn that needs mowing: sticks, a dog's ball, a kid's toy truck, a frisbee
and rocks lie hidden in the uncut grass (`src/shared/Config/Debris.luau`, `LawnService`). Players
have to spot them and pick them up (look at one and press **E**, or tap the big button) before
cutting there.

- **How much:** one piece per 16 lawn tiles on homeowner jobs, per 14 on serious ones and per 12
  on pro ones, rounded, 1 to 10 (a job's `lawn.debris` sets it outright): 2 on a tiny yard, 4 on
  the first job, 5 on a suburban lawn, 10 on the big ones. Never on the tiles by the flowers, and a
  tile or more apart. Sticks turn up most often, then rocks and balls, then toys and frisbees.
- **Grass shears can't cut a spot with something in it** ("There's a stick in the grass there.
  Pick it up first."), and a **reel mower** jams on it ("The mower jams on..."), so that tile stays
  tall until it's cleared.
- **A motorized mower runs right over it and chews it up.** Its blade loses a chunk of its edge at
  once (`wear`: a rock 0.3, a stick or a toy 0.15, a ball or frisbee 0.05, through
  `Maintenance.strike`; Diamond Blades still never dull), the engine stalls for 1.5 s, bits fly
  out, and the customer notices: the crew is told, and it costs 4% of the pay (at least $3).
- **Whatever's left at the end** costs the same, and every piece left or chewed up takes 0.04 off
  the finish. The tracker shows "Pick up junk in the grass 1/4" (how many there are, never where),
  and the pay breakdown says how many were left or chewed up.
- **Your own lawn** hides a couple too, and each bit of grass that grows back has a 5% chance of
  something new turning up in it (up to 3 at a time). There they only cost blade wear and stalls.
  They aren't saved: a rebuilt lawn hides its own again.
- The server checks every pick-up: the piece must still be on your job's lawn (or your crew's own
  lawn) and within 12 studs of your eyes.

### Garden jobs (phase C)

The homeowner tier is small housework: potting up, seedlings, perennials, bulbs, seed rows,
loosening beds, pulling young weeds, dandelions, pruning shrubs and roses, dead wood,
deadheading, and watering beds or seedlings. Twelve jobs (`PottingDay` to `GrandmasGarden`) mix
them with the old mowing jobs.

- **Where:** each garden task gets a plot in a **side garden** left of the yard (the fence is left
  out when there's a garden). Plots stack from the sidewalk toward the house. Dandelions grow in
  the lawn itself. Each kind of target has a look before and after (`GARDEN` in
  `LawnService.luau`): a pot gets its plant, a flag becomes a planted bulb, dry soil darkens, dead
  sticks come off a shrub.
- **Gloves:** a task with `protection` can't be worked bare-handed. Gloves in the truck count as
  worn on site (`NitrileGloves` protect from thorns, `ChemicalGloves` from chemicals). Without
  them: "Ouch! Those thorns shred your bare hands." It never names the gloves.
- **The board:** slot 1 is always a job the free gear can finish, slots 2-4 are homeowner jobs up
  to the best player's level (`HomeownerJobsOnBoard`), and the rest go a little above it.
- **Learning tools:** the **Guide** menu lists every tool in the store with its "what it's for"
  text, by shop tab. Until a player finishes their first job, a coach banner walks them through
  it one step at a time (take the job, load the truck, drive, do the work: snipping with the
  shears and picking up the junk in the grass), and the Jobs app marks the free-gear job as a
  good first job.
- New shop tabs: Planting & Weeding, Pruning, Watering and Gloves.

### Serious gardening (phase D)

Nine serious-tier jobs (`NewShrubBorder` to `FallCleanup`, level 3-5) use the tier-2 tools.

- **Rocky ground:** a job can put some planting holes in rocky ground (`rocky` on the task). The
  task type's `rocky` table changes each tool's speed there: a mattock tears through (x2.4), a
  shovel barely bites (x0.45). Rocky spots show stones around the marker, and the job's note
  warns about rubble.
- **Hauling:** a delivered pile sits on the driveway and an empty bed waits in the side garden.
  Fill your barrow at the pile, push it to the bed and dump it; each player carries one load at a
  time. Barrows, carts and the broadcast spreader are pushed (they work while held, like
  mowers); the spreader only spreads while you walk. Soil and stone (`heavy`) can tip a
  one-wheeled barrow (`tips`) while you walk it: about a 5% chance per second, and the load goes
  back on the pile. The fit tables pick the right barrow for the load: carts for light, bulky
  loads; two wheels for heavy ones.
- **Fertilizing** covers every lawn tile (like mowing); a pale dusting shows where it landed.
- **Spot-spraying** kills weeds in the lawn and the driveway cracks (they wilt). It needs
  chemical-proof gloves; work gloves aren't enough.
- **Branches:** loppers for 1-2 inch branches, a pruning saw for thicker; pruners can't cut either.
- Leaf rakes only level mulch poorly (and leave it lumpy); a bow rake still tears turf when raking
  leaves.
- New shop tabs: Digging, Barrows & Carts and Lawn Care.

### Pro work (phase F)

All the pro equipment is on sale. Five pro jobs join the park and the estate:

| Job | What makes it pro |
| --- | --- |
| ShowLawn | putting-green grass (1.25 in): only reel mowers cut it right, and cut quality (`cutQuality` x blade sharpness) decides the pay on quality-minded jobs |
| OvergrownLot | knee-high grass (9 in): reel mowers can't cut it; the grass is drawn taller (`TallScale` on the Grass folder) |
| WoodedEstate | a tight lawn with trees in mulch rings (`trees`): on `tight` tasks every mower's speed is scaled by `0.4 + 0.6 x maneuverability`, so a stand-on (0.95) beats a lawn tractor (0.4) |
| TurfRenovation | the full renovation, thick thatch (`thatch = 0.8` in) |
| LawnRenewal | renovation without dethatching (thin thatch) |

**Ride-ons.** Stand-on machines (`StandOnMower`, `StandOnAerator`) have `ride.stand`: you stand
on the platform behind the control bars, lifted by the platform height plus your legs, with no
sit animation. The `RideOnSpreaderSprayer` is a seated ride. Ride-ons that `tows`
(lawn tractor, zero-turns, ride-on spreader) pull the `TowBehindAerator` when it's in the truck:
it rides along behind them (`use = "Towed"`, never in the hotbar) and aerates where it goes,
wearing its own tires. While towing, the ride-on's own deck is up (it doesn't mow). It can't be pulled by the truck at the job site, since the truck doesn't
drive there.

**Turf renovation** happens on the lawn's own tiles, in order (`step` on the task types):

1. **Probe the soil** at the flagged spots. The first reading reveals the soil's temperature and
   moisture (`Soil reading: 58°F and moist`), and the HUD keeps showing it. Working before the
   probe: x0.85 on that work.
2. **Dethatch** the tiles where the thatch is thick (0.5 in or more; the job sets how thick it
   runs and each tile varies). Aerating through thatch that should have come out first: x0.85.
3. **Core aerate.** Dry soil: x0.7, unless the tile was watered first (watering an unseeded tile
   only wets it; it doesn't count as the last step).
4. **Overseed.** Best right after aerating or dethatching (otherwise x0.75), and in 50-65 F soil
   (otherwise x0.7). If the probe shows the soil is too cold or hot, seeding and watering become
   optional: a pro would seed another day, and skipping them costs nothing.
5. **Fertilize** after the seed is down (otherwise x0.9).
6. **Water** the new seed in.

Each tile shows its latest step (one overlay per tile). A machine that can do two steps (the
broadcast spreader seeds and feeds) does the earlier one on each tile first. Watering a tile that
isn't seeded yet just wets it. The multipliers lower the finish quality, and with it the pay. The
soil is rolled per job offer and stays on the server; the customer only hints at it, roughly ("The
nights have been on the chilly side. We haven't had much rain."), never naming a tool, so the
probe is the only way to know.

### Task types

| Phase | Task type | Verb | Ideal / Good / Poor |
| --- | --- | --- | --- |
| now | MowSmallLawn | Mow | ReelMower, GasPushMower, SelfPropelledMower / RidingMower, StandOnMower, GardenShears (by hand) |
| now | MowMediumLawn | Mow | SelfPropelledMower, RidingMower, ZeroTurnMower / GasPushMower, StandOnMower, CommercialZeroTurn |
| now | MowLargeLawn | Mow | CommercialZeroTurn / StandOnMower, ZeroTurnMower, RidingMower |
| now | EdgeSidewalk | Edge | HalfMoonEdger, ElectricEdger, WalkBehindEdger, GasStickEdger / GardenSpade / string trimmers (ragged) |
| now | EdgeHardscape | Edge | GasStickEdger / WalkBehindEdger, ElectricEdger / GardenSpade, string trimmers |
| now | TrimAroundObstacles | Trim | StraightShaftTrimmer, GasTrimmer, ElectricTrimmer / GardenShears, Brushcutter (rough) |
| now | RakeLeaves | Rake | OldRake, WideRake / LeafBlower, BackpackBlower / BowRake (tears turf) |
| now | ShearHedges | Shear | electric, cordless and gas hedge trimmers / HandHedgeShears, ArticulatingHedgeTrimmer |
| now | ShearTallHedges | Shear | ArticulatingHedgeTrimmer / GasHedgeTrimmer, CordlessHedgeTrimmer |
| C | PotUpPlants | Plant | HandTrowel / - / HandTransplanter (can't scoop mix); no Dibber |
| C | TransplantSeedlings | Plant | Dibber / HandTrowel, HandTransplanter |
| C | TransplantPerennials | Plant | HandTrowel / HandTransplanter; no Dibber |
| C | PlantBulbsAtDepth | Plant | HandTransplanter / HandTrowel / Dibber (small bulbs only) |
| C | SowSeedRows | Plant | Dibber / HandTrowel |
| C | LoosenBedTopsoil | Cultivate | HandCultivator / HandTrowel |
| C | PullShallowWeeds | Weed | HandCultivator / StirrupHoe, HandTrowel |
| C | RemoveDandelions | Weed | DandelionWeeder / HandTransplanter (leaves a hole) / HandTrowel; no StirrupHoe |
| C | PruneLiveStems | Prune | BypassPruners / AnvilPruners (crushes) / FloralSnips |
| C | PruneRoses | Prune | as above, plus Thorns protection |
| C | CutDeadWood | Prune | AnvilPruners / BypassPruners; no FloralSnips |
| C | DeadheadAndCutFlowers | Prune | FloralSnips / BypassPruners |
| C | WaterBeds | Water | GardenHoseWand / WateringCan (slow) |
| C | WaterSeedlings | Water | WateringCan / GardenHoseWand (washes seed out) |
| D | DigPlantingHole | Dig | RoundPointShovel / GardenSpade / Mattock |
| D | CutBedEdgeOrSod | Dig | GardenSpade / RoundPointShovel, HalfMoonEdger |
| D | DeepLoosenBed | Cultivate | Broadfork / DiggingFork |
| D | TurnHeavySoilOrLiftRoots | Dig | DiggingFork / GardenSpade / RoundPointShovel |
| D | BreakHardGround | Dig | Mattock / - / RoundPointShovel (very slow) |
| D | LevelSoilSpreadMulch | Rake | BowRake / leaf rakes |
| D | HoeRowWeeds | Weed | StirrupHoe / HandCultivator |
| D | CutBranchesMedium | Prune | Loppers / PruningSaw; no hand pruners |
| D | CutBranchesThick | Prune | PruningSaw; no loppers or pruners |
| D | HaulHeavyMaterial | Haul | DualWheelbarrow, SingleWheelbarrow / SingleWheelbarrowFlatFree / PolyCart |
| D | HaulBulkyLight | Haul | PolyCart / wheelbarrows |
| D | FertilizeLawn | Spread | BroadcastSpreader / RideOnSpreaderSprayer |
| D | SpotSprayWeeds | Spray | BackpackSprayer; needs ChemicalGloves |
| F | MowShowLawn | Mow | CommercialReelMower, ReelMower (grass 1.25 in) |
| F | MowTallGrass | Mow | GasPushMower, SelfPropelledMower / CommercialZeroTurn, StandOnMower (grass 9 in) |
| F | MowTightOrSloped | Mow | StandOnMower / SelfPropelledMower, GasPushMower, ZeroTurnMower |
| F | ProbeSoil | Measure | SoilProbe |
| F | DethatchLawn | Dethatch | PowerRakeDethatcher / - / BowRake (very slow) |
| F | CoreAerate | Aerate | StandOnAerator / TowBehindAerator / DiggingFork (spiking, no cores) |
| F | Overseed | Seed | SlitOverseeder / BroadcastSpreader (patchy) |
| F | FertilizeLargeLawn | Spread | RideOnSpreaderSprayer / BroadcastSpreader |
| F | WaterNewSeed | Water | GardenHoseWand / WateringCan (slow) |

Choices made for realism where the original list was loose:

- A transplanter is Poor (not Good) for potting, matching its description.
- A lawn tractor is Good on large lawns.
- String trimmers can edge (turned on their side), Poorly, with a ragged finish.
- A half-moon edger is Good for cutting bed edges and sod.
- A digging fork can spike-aerate (Poor) and a bow rake can dethatch by hand (Poor, slow).
- A broadcast spreader can overseed (Good) but sprouts patchy.

**Pro turf renovation** (phase F) is done in order: soil probe check (first), dethatch if the
thatch is thick, core aerate (moist soil), overseed (soil 50-65 F for cool-season grass),
fertilize, water. Out of order or in bad conditions lowers quality.

## 5. Storage and hauling (phase B)

Players own many tools and pick what to bring to each job. Owned tools live in storage at the
business, shown on the plot, and are carried to the truck by hand. Push and ride-on machines are
rolled along the ground in front of you instead of lifted. The rules are in
`src/shared/Config/Storage.luau` and `src/shared/Shop.luau`; the plot layout is
`src/server/BusinessStorage.luau`.

### Storage

Each building has a number of spots of each kind (`storage` on each business in `Items.luau`):

| Building | Pegboard (Hand) | Wall rack (Long) | Wall hooks (HangingPower) | Shelf (Supply) | Floor spots | Bays | Price |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Shed | 12 | 4 | 1 | 4 | 1, push machines without an engine only | 0 | free |
| Garage | 16 | 8 | 4 | 8 | 2 | 0 | $4,000 |
| SmallOffice | 24 | 12 | 6 | 12 | 4 | 2 | $20,000 |
| EquipmentYard (new) | 32 | 16 | 10 | 16 | 6 | 5 | $75,000 |

- You can't buy a tool without a free spot of its kind. Sell one (half price back; free starter
  gear can't be sold) or upgrade the business.
- Tools you already own are never lost. Anything without a spot (from an older save, or a crew
  member's tools at a smaller business) sits on the ground in front of the storage, and still
  works.
- The shed can't store a gas push mower, so the first engine mower needs a garage. (The spec asked
  for this. It makes the garage the first big goal, so its price may want lowering.)
- Shelves are an addition: the spec had no spot for supplies (`StorageShelf`, below). They only
  hold the tool bucket until phase E.
- Workbenches and the air compressor are phase E.

On the plot (the street is toward -Z): pegboards (two high) and wall racks run along the right
edge, wall hooks and shelves along the left edge, floor spots and equipment bays are painted on the
ground in between, and tools without a spot sit near the front. Fixtures are the
`StoragePegboard` (6 hooks), `StorageWallRack` (4 holders), `StorageWallHooks` (2 hooks) and
`StorageShelf` (6 places) props, tiled until there are enough spots. Each tool goes on a `Slot`
attachment: hand tools hang flat on pegboards, long tools stand upright in wall racks, power tools
hang edge-on from hooks. Real fixture models without `Slot` attachments get them spread over
their front. Mount heights are `MOUNT_HEIGHT` in `BusinessStorage.luau`, to tune in Studio.

### Truck space

| Item | Space |
| --- | --- |
| hand tools | 1 each, or up to 8 of your own in one `ToolBucket` ($30), which takes 1 |
| long tools | 1 |
| handheld power tools | 2 |
| push and walk-behind machines | 4 |
| supplies | 1 |
| ride-on machines | no truck space: 1 bay on an `EquipmentTrailer` each |

| Vehicle | Space | Ride-on bays | Price |
| --- | --- | --- | --- |
| RustyPickup | 6 | 0 | free |
| WorkPickup | 8 | 0 | $5,000 |
| HeavyDutyPickup | 10 | 0 | $20,000 |
| LandscapingTruck | 14 | 0 | $60,000 |
| UtilityTrailer | +6 | 0 | $1,200 |
| LandscapeTrailer | +10 | 0 | $3,000 |
| EquipmentTrailer (new) | +4 | 2 | $6,000 |

- A crew shares the leader's truck and trailer. The truck won't leave overloaded.
- Trailers unlock the first time the truck is full (a load that fills it, or one that won't fit).
- A new player owns the grass shears, and they start in the truck (1 of 6 space).
- In the truck bed every tool gets a stretch of bed as long as its space; push machines stand,
  everything else lies across. Ride-on machines park on the trailer's `BaySpot` parts.
- Push and walk-behind machines are held so their lowest point touches the ground, from the
  player's real shoulder height, whatever height the model's handlebar is.

## 6. Maintenance (phase E)

Simple but real, for tools and machines (not the truck). The rules are in
`src/shared/Config/Maintenance.luau`, the workbench in `src/server/Services/MaintenanceService.luau`.

Every owned tool has a **condition**, saved with the player:

| Part | Which tools | Wears out | When it's gone |
| --- | --- | --- | --- |
| Fuel | `engine` FourStroke (regular gas) or TwoStroke (50:1 mix) | 300 s (four-stroke) or 240 s (two-stroke) of running | won't run |
| Engine | the same | wrong fuel wrecks it at once | won't start until repaired |
| Air tires | `tires = "Air"` (ride-ons, barrows, spreader) | 1800 s of rolling, plus a puncture now and then | slower and harder to push; flat won't roll |
| Blade | mowers, edgers, spades ("heavy"); pruners, shears, hedge trimmers ("fine") | 1200 s of cutting | slower and rougher cut (quality down to 60%) |
| Trimmer line | string trimmers | 240 s of trimming | won't cut |

Electric and battery tools need no fuel; flat-free tires never need air. A motorized mower that
runs over junk hidden in the grass loses a chunk of its blade's edge at once (see "Junk in the
grass").

**Supplies** (Supplies tab) fix things. Consumables have uses and are restocked by buying them
again.

| Supply | Does | Time | Uses |
| --- | --- | --- | --- |
| GasCan / MixGasCan | fills a four-stroke / two-stroke tank (the other kind wrecks the engine) | 2 s | 6 |
| FootPump / ElectricInflator | inflates air tires | 8 s / 2 s | - |
| AirCompressor | inflates air tires; never leaves the building | 1 s | - |
| TirePatchKit | fixes a puncture (then it needs air) | 6 s | 4 |
| SpareTire | swaps a new tire on, with a WrenchSet | 10 s | 1 |
| WrenchSet | repairs a wrecked engine: drains the bad fuel (parts cost 10% of the tool's price, at least $10) | 15 s | - |
| BladeFile / BenchGrinder | sharpens heavy blades (the grinder fast, and only in the building) | 10 s / 3 s | - |
| SharpeningStone | sharpens fine edges | 8 s | - |
| SpareMowerBlade | bolts a new blade on a rotary mower, with a WrenchSet | 6 s | 1 |
| TrimmerLine | reloads a string trimmer | 4 s | 5 |

- **Where:** at the business **workbench** (every building has one; you can use everything you
  own, plus the building's machines: the Small Office has an air compressor, the Equipment Yard
  an air compressor and a bench grinder), or at the **tailgate** of the truck on a job (only what
  you loaded). Supplies take truck space like any tool.
- **How:** by hand (see "Hands-on maintenance" in section 8). The Workbench menu is gone. Each
  job takes a few seconds and you have to stay put. Parts for a repair are paid when it's done. Tools and supplies can't be bought
  mid-job (what you brought is what you've got), and a half-used consumable sells for what's
  left in it. Nothing says which supply fits which tool, and using the wrong one does what
  it really would.
- **What players see:** the HUD shows the held tool's condition ("Running low on fuel", "Tire
  looks soft", "Cut is getting ragged", "Engine is smoking and won't start") and the Truck menu
  shows every tool's. They never name the fix. A tool that stops says so once ("It sputtered
  out.").
- Choices made: the shed gets a workbench too (the spec only listed one from the garage up), so
  new players can look after their tools at home. Reel mowers are sharpened with a file (real
  ones are backlapped) and can't take a spare blade.

## 7. Camera (first person)

The game is played in first person (`StarterPlayer.CameraMode = LockFirstPerson`, field of view
75 in `GameConfig.Camera`). Code: `src/client/Controllers/CameraController.luau` and
`ArmsController.luau`.

- **The drive cutscene** keeps its own scripted camera and hands back to first person when you
  arrive. Riding and standing on ride-on machines stays first person, from the seat or the
  platform: you see the hood or deck ahead and your hands on the controls.
- **Your arms.** Roblox hides your whole character in first person, so a pair of simple arms is
  drawn on your screen only (other players see your avatar as normal). Whenever you hold or use
  anything (a tool, something you're carrying around the business, a pushed machine, a barrow, a
  ride-on's controls) both hands grip it: on either side of a handlebar, up a rake's shaft, on a
  trimmer's front handle. Empty-handed they drop out of view, and they blend up and down over a
  quarter of a second when you take something or put it away. Models can place the hands exactly
  with `GripLeft` / `GripRight` attachments (see `assets/README.md`).
- **Tools in view.** On your screen only, the tool in your hands is posed for first person: push
  machines and barrows stand on their wheels with the handlebar centred ahead of you, string
  trimmers and edgers stand on the ground the way they were modelled, rakes, forks and shovels
  lean out with their head on the ground (just far enough that the shaft stays below your eyes),
  and small hand tools sit low on the right and follow your view part of the way (grass shears
  sit lower and nearer the middle, tipped down at the grass, and jab forward with each snip; see
  "Starting out"). Nothing near
  eye level gets closer than 0.7 studs to the camera. Backpack blowers and sprayers (`onBack`)
  keep their normal hold, since they're modelled as worn. Where the work happens doesn't change:
  just in front of you, whichever way you face.
- **Menus and the mouse.** In first person the mouse is locked to the middle of the screen. While
  any menu is open (the shop computer, truck, crew, guide) it's freed, and locked again when
  you close it. Hold **Left Alt** to free it any time, to click the HUD or answer a crew invite
  (an invite doesn't free it by itself: you might be mowing). Each player can only have one
  invite out to the same person at a time.
  Keys: **J** jobs, **T** truck, **B** shop, **G** guide, **C** crew, shown on the buttons when
  there's a keyboard. Phones keep the touch controls: drag to look, tap buttons and prompts.
- **Aiming.** A small dot marks the middle of the screen. It's hidden while the mouse is free and
  during the cutscene. ProximityPrompts are unchanged: they don't need line of sight and reach 8
  to 12 studs, which is comfortable in first person.
- **Camera motion.** A gentle head bob while walking and a slight shake while a gas engine you're
  using is running. Players switch both off with **V** or the switch at the top of the Guide; set
  `GameConfig.Camera.HeadBob` / `EngineShake` to false to turn them off for everyone. Both only
  move `Humanoid.CameraOffset`, so they cost nothing on phones.

## 8. Immersion

Making the business, loading and maintenance hands-on, built on first person. One PR per part.

### Walk-in buildings

- **Storage inside.** A building model can mark where everything goes inside it with
  Attachments (`src/server/BusinessStorage.luau`):
  - `Mount` with attributes `Kind` (`Pegboard`, `WallRack`, `WallHooks`, `Shelf`, `Workbench`,
    `Compressor`, `Grinder`) and `Index`. Its LookVector points into the room, and the fixture's
    back goes on it.
  - `FloorSpot` and `EquipmentBay` (with `Index`).
  - `TruckParking`: the truck's ground centre, LookVector the way the truck faces (rear toward
    the door).
  - `Light`: a ceiling light (a PointLight without shadows, cheap on phones).

  Fixtures fill the building's spots (`storage` in `Items.luau`) mount by mount, in Index order.
  Planned counts:

  | Building | Pegboard | WallRack | WallHooks | Shelf | FloorSpot | EquipmentBay | Also |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | Shed | 2 | 1 | 1 | 1 | 1 | - | - |
  | Garage | 3 | 2 | 2 | 2 | 2 | - | Workbench |
  | SmallOffice | 4 | 3 | 3 | 2 | 4 | 2 | Workbench, Compressor |
  | EquipmentYard | 6 | 4 | 5 | 3 | 6 | 5 | Workbench, Compressor, Grinder |

  Anything a building has no attachments for (the current models, placeholders) keeps the
  outdoor layout along the plot's edges. Tools without a spot still go in the overflow rows.
- **Doors.** `<Id>__Door` and `<Id>__GarageDoor` are modelled open (swung open, rolled up) and
  stay that way. Choice made: the garage door doesn't roll down and up as the owner walks up,
  because the models only have the open pose.
- **Walls you can't walk through, doors you can.** Building walls are separate meshes with real
  holes for the doors. They collide properly with the Default or `PreciseConvexDecomposition`
  CollisionFidelity, which is set in Studio before saving the model (scripts can't change it).
  A walk-in building's wall mesh left on Box or Hull would block its doorways. It stops colliding
  instead, and invisible walls go up around the building with gaps at its doors: a garage door's
  opening is under it, and a hinged door's opening is taken to be in line with `TruckParking`.
- **Truck at the door.** The plot's truck parks on `TruckParking` (with a trailer, the trailer's
  rear goes there and the truck sits ahead of it), with its `<Id>__Tailgate`,
  `EquipmentTrailer__Ramp` or `LandscapeTrailer__RampDoor` down, or its `<Id>__RearDoor`
  (LandscapingTruck) up. Tailgates and
  ramps are hinged on their pivot and rotate about X; the ramp goes down until it reaches the
  ground. Everything closes as the crew drives off and opens again when they're back. At the job
  site the truck parks with its tailgate down, since that's where you work on your tools.

### Look-at loading

Everything at the business is used by looking at it (the dot in the middle of the screen) and
pressing **E**, or the big button on a phone (`src/client/Controllers/InteractController.luau`).
Things you can use carry an `Interact` attribute. The client only says what you want to do
("put this tool on bed 1 at cell 3"); the server checks you're holding it, you're in reach and
it fits.

- **Taking tools.** Look at one of your tools on a wall, shelf, floor spot or bay and take it.
  One thing at a time. Push machines are rolled in front of you, and ride-ons are driven: you
  get on, drive up the equipment trailer's ramp and park on a free `BaySpot` (E), or park it back
  in an equipment bay.
- **The truck bed is a grid** (`src/shared/BedGrid.luau`): two cells across and one cell per
  unit of the vehicle's `space`, so the rusty pickup is 2 × 3 and the landscaping truck 2 × 7. A
  trailer has its own grid. Tools cover cells by size class:

  | Size class | Cells | Lies |
  | --- | --- | --- |
  | Hand, Supply (and the tool bucket) | 1 | across (supplies stand) |
  | Long | 1 | lengthwise |
  | HangingPower | 2, one behind the other | lengthwise |
  | FloorManual, FloorEngine | 4, a 2 × 2 block | standing |

  Look at the bed and a ghost of what you're holding sits on the cells under the dot: green if
  it fits, red if not. E sets it down, and it settles into place. Look at a loaded tool to take it
  back out. Where each tool lies lasts for the session. Anything loaded before, or that doesn't
  fit where it was, goes in the first free cells.
- **The tool bucket** holds up to 8 hand tools in its one cell. Look at it, in storage or in the
  truck, while holding a hand tool to drop the tool in. With empty hands, E takes the bucket (and
  everything in it) and R takes one tool out.
- **Putting tools back.** Every free spot of the right kind can be looked at to hang, rack,
  shelve, set down or park the tool there, with a ghost showing where. Each tool remembers its
  spot (`spots` in the save). Loaded tools keep theirs, so storage doesn't shuffle.
- **Prompts.** The shop computer, delivery boxes, workbench, tailgate and "Drive to Job" on the
  crew truck work the same way, so no ProximityPrompts are left. A custom town's
  ProximityPrompts with `OpensPanel` still work.
- **Feedback.** Things set down in the bed drop the last stud into place. Sounds are named
  placeholders in `src/shared/Sounds.luau` (Thunk, Pickup, Hang, Bucket) until ids are filled in.

### Hands-on maintenance

Tools are worked on by hand instead of from a menu (`MaintenanceService`; the steps are in
`src/shared/Service.luau`, what each supply does is in `Maintenance.luau`).

- **Set it down.** Hold the machine and look at a service spot, then press E. Hand and long tools
  (pruners, loppers, spades, half-moon edgers) go in the vise instead. Every workbench has both:
  its `ServiceSpot` attachment (on the floor in front of the bench) and `VisePoint` (in the
  vise). On a job, the truck has them too: on the ground beside its back end (the sidewalk side)
  and on its side rail there. One tool per spot. Look at it with empty hands to pick it back up.
  While it's set down it isn't in storage: it can't be grabbed, loaded or sold until it's picked
  up again.
- **Work on it.** Hold a supply and look at the tool. The hint says what it would do ("Pour in
  the fuel", "Pump up the tire", "Plug the puncture", "Wind on new line", "Hone the edge"), or
  what's in the way. **Hold E** (or the button on a phone) while it works: it takes the supply's
  time, and letting go or walking off stops it. Supplies come off your storage at the business.
  On a job, the ones you brought stand in a row by the truck, one row per crew member: take one
  there, and look at the truck to put it back.
- **Steps.**
  - A mower's (or other floor machine's) heavy blade comes off first: the wrench on the machine
    ("Take the blade off"), and it lies on its side.
  - Then sharpen it with the file, or with the building's bench grinder (empty hands, hold R),
    or fit a spare blade.
  - Then the wrench again to bolt it back on. It can't be picked up with the blade off.
  - For a new tire, the wrench on a wheel takes it off, then the spare goes on.
  - A wrecked engine is fixed with the wrench first.
  - The air compressor fills tires with empty hands (hold R), and the bench grinder sharpens a
    loose blade the same way: the building's own, or ones you bought and keep in storage.
- **Condition you can see.** The HUD hints stay, and never name the fix, but tools also show it
  themselves (`ToolFxController`):
  - an engine low on fuel sputters with puffs of smoke while it runs, and a wrecked one smokes;
  - soft tires sag and flat ones squash (parts named `<Id>__Wheel...` or `<Id>__Tire...`, or a
    placeholder's `Wheel`);
  - a spool (`<Id>__Spool...`) shows bare as the line runs out;
  - grass cut with a dull blade is left ragged, duller and with torn tufts sticking up
    (`LawnGrid.RAGGED`; GrassController draws it).

## 9. The shop as the hub

Almost everything happens in your shop. You pick jobs and order gear at the computer inside,
unbox deliveries by the door, take tools off the walls, load the truck parked at the door and
drive off from there. Outside, you look after your own front lawn and decorate the yard,
which earns your business curb appeal and a bonus on every job.

- **The job computer.** A desk stands on the building's `Desk` marker (on older buildings, out
  front facing the street). Which desk goes with which building is `desk` in `Items.luau`:
  `JobLaptopTable` for the Shed, `JobComputerDesk` for the Garage, and `JobOfficeDesk` for the
  SmallOffice and EquipmentYard. Look at the desk and press E (`ComputerController`):
  1. you step up to its `UseSpot`;
  2. the camera eases in to `ScreenView` and the field of view narrows;
  3. the desktop opens, with four apps:
     - **Jobs:** today's board, with hints only. Anyone can look; only the crew leader can take
       a job.
     - **Orders:** tools and supplies, plus a Sell tab for tools in storage.
     - **Business:** building, truck and trailer upgrades.
     - **Crew.**

  The apps are drawn in a ScreenGui framed as the monitor, so they stay readable on phones. Back,
  walking away, or the crew heading out eases the camera back to first person. The server only
  takes jobs, purchases, sales and upgrades from someone standing at their crew's computer.
  There's no town hardware store any more, and no outdoor job board. HUD keys: T truck, G guide,
  C crew.
- **Deliveries** (`DeliveryService`, `src/shared/Deliveries.luau`). A tool or supply is yours as
  soon as it's bought (Shop.luau's tier, storage and money rules are unchanged). It arrives in a
  box at the building's `DeliverySpot` after `GameConfig.DeliveryTime` (15 s), or straight away
  if you were out on a job when you ordered.

  | Size class | Box |
  | --- | --- |
  | Hand, Supply | `DeliveryBoxSmall` |
  | Long | `DeliveryBoxLong` |
  | HangingPower, FloorManual, FloorEngine | `DeliveryBoxLarge` |
  | Bay (ride-ons) | `DeliveryCrate` |

  Look at your box and press E: its flaps (lid, crate front) swing open on their hinges, the
  tool shows at `Contents`, then it comes up into your hands (on a ride-on, you're in the seat)
  and the empty box goes away. Hang it up or load it like any tool. Until it's opened the tool
  is in its box: not in storage, and it can't be loaded. Unopened boxes are saved
  (`deliveries`) and turn up again when you rejoin. Selling a boxed tool sends the box back.
  Restocking a consumable refills it at once, and trucks, trailers and buildings don't come in a
  box. Choice made: opening a box puts the tool straight into your hands, instead of leaving it
  in the open box to pick up, so there's no half-open state to save.
- Boxes stand in rows at the crew's delivery spot, and move with the crew.
- **The plot** is 90 × 90 studs:
  - the building at the back;
  - a concrete driveway from the street to the door, with the truck (and trailer) on it;
  - your own front lawn on the left of the driveway (see "Your own lawn" below);
  - on the right, the outdoor storage for older buildings, the business sign and where you
    spawn.

  The placeholder town spaces its 12 plots to fit. Every plot faces its street to the south
  (-Z), so the front lawns line up with the grid lawns are drawn on. A town built in Studio
  needs the same; the server warns if a plot doesn't. Older buildings without a `DeliverySpot`
  get their boxes on the right of the driveway, clear of the lawn.
- **Leaving from the truck.** The truck parks on `TruckParking` (older buildings: about 10
  studs out from the door) with its tailgate to the door. With a trailer, the trailer's ramp
  faces the door and the truck sits ahead of it. To leave, the crew leader looks at the driver's
  door (`<Id>__DriverDoor`, or the truck if it has none) and gets in. Without an accepted job you
  get "Pick a job at the computer first".
  1. The tailgate shuts.
  2. The driver's door (with `<Id>__DriverDoorGlass`) swings open about its hinge and shuts again.
  3. Every crew member's camera sits in a seat in the cab: the driver at the truck's
     `DriverSeat`, the others beside and behind.
  4. The truck pulls out of the driveway into the street (`GameConfig.PullOutTime`).
  5. The usual trip cutscene plays.

  The crew rides along wherever they were. Each player's screen animates the truck's drive
  itself, so the view from the cab is smooth. Calling the job off before the trip starts puts
  everyone back on their feet with the truck at the door. The truck belongs to the leader who
  drove off: it comes back with them, even if they leave the crew on the way. Coming back, the
  truck pulls back in from the street and drops its tailgate so you can unload into storage.
  Trucks, trailers and buildings can't be swapped while you're out on a job. Placeholder trucks have a driver's door,
  a `DriverSeat` and a hinged tailgate.
- **Your own lawn** (`HomeLawnService`, `src/shared/HomeLawn.luau`). Every plot has a front lawn
  left of the driveway, about 28 × 32 studs (7 × 8 tiles). It's a real lawn, built by
  `LawnService` from the same kit grass and mowed on the same `LawnGrid` as customers' lawns:
  - the grass (`MowSmallLawn`);
  - the edge along the sidewalk and driveway (`EdgeSidewalk`);
  - 5 weeds by the building and along the side (`TrimAroundObstacles`);
  - 3 piles of leaves (`RakeLeaves`).

  You look after it with your own tools, straight out of storage: a tool you take off the wall is
  the real thing in your hands, held as on a job, and it works on the lawn. Tool fit, finish and
  wear (fuel, blades, line, tires) are just as on a job; off the lawn, carrying a tool around
  does no work and no wear. Supplies and gloves are still just carried, and gloves you own count
  as worn at home. Crew members can help with the leader's lawn.

  It grows back while you play: from tidy, it's fully overgrown again after
  `GameConfig.HomeLawn.RegrowMinutes` (40) in the game. Every so often one finished bit comes back
  (a grass tile, an edge strip, a weed, a leaf pile), never right next to someone. It doesn't grow
  while you're offline. What's done is saved (`homeLawn`), so it looks the same when you come
  back; a new lawn starts overgrown. Getting an untidy lawn tidy again earns a neighbor's tip
  (`TidyTip`, $25), at most once every `TidyTipCooldownMinutes` (30), and only after it has grown
  back below `TipAfterBelowShare` (75%) done since the last tip, so a stray weed isn't a tip.
  Work counts on the lawn and just past its edges, not on the driveway.
- **Curb appeal** is 0 to 100: how good your business looks from the street. The HUD shows your
  crew's under your money and level.
  - Up to `CurbAppeal.LawnPoints` (60) come from the lawn, in proportion to how much of it is
    done.
  - Up to `DecorPoints` (40) come from decorations (below). Each extra one of a kind counts
    `DecorRepeat` (0.6) of the one before, an overgrown shrub counts `OvergrownShare` (half), and
    the total levels off: `DecorHalfPoints` (30) appeal points earn half the decoration points.
    A few good pieces beat a yard full of flamingos.

  Every job the crew does pays up to `MaxPayBonus` (+15%) more at 100, less below it, using the
  leader's curb appeal when the crew sets off. The pay breakdown shows it as a "Curb appeal" line.
  Tuning is in `GameConfig.HomeLawn` and `GameConfig.CurbAppeal`.
- **Decorations** (`DecorService`, `DecorController`, `src/shared/Config/Decorations.luau`,
  `src/shared/DecorPlacement.luau`; models in alphainstructions/instructions34.md). 24 of them,
  at real-world prices, from a $12 pink flamingo to a $900 tiered fountain, in the **Decorations**
  tab of the Orders app.
  - **They're for your crew's yard** (the leader's): whoever orders one pays, and it's the
    leader's business that gets it. It comes in a box at the delivery spot like a tool, and
    anyone in the crew can open it. A crewmate can have at most 4 unopened boxes waiting at
    someone else's shop, and can't order for a leader whose progress isn't being saved. At most
    2 decoration boxes stand at the shop at once; the rest wait their turn.
  - **Placing** is in first person. A see-through copy stands where you look: green if it can go
    there, red (with why) if not. R turns it 15° (Shift+R back), E puts it down, Q puts it back;
    phones get Place, Turn and Put back buttons. The business's owner can also send it back for
    half its price (F, or Send back). It can't go on the driveway, in or right next to the
    building, desk, workbench, sign, outdoor storage or delivery spot, or off the plot. It can't
    overlap another decoration either, except in or on ground cover (`holds`: a mulch bed's
    shrubs, a bench on pavers). Only
    small things on a stake or post (`onLawn`: mailbox, lamp post, path light, bird feeder,
    birdhouse, flamingo, gnome) can stand on the grass. The server checks the same rules.
  - **Joining:** fence sections, stone edging, paver paths and mulch beds snap end to end when
    one's `SnapL` comes near another's free `SnapR` (or the other way round).
  - **Moving:** look at a placed decoration and press E to pick it up and place it again (it
    keeps its turn). Where everything stands is saved (`decor`). If a bigger building needs the
    room, what's in the way goes back in its box, shrubs keeping their trim. A truck or trailer
    swap doesn't disturb the yard.
  - **What the markers do:**
    - `Light`: a lamp.
    - `Fire`: flames and a glow.
    - `Spout`: water running.
    - `Seat`, `Seat1`-`Seat4`: seats you can sit on.
    - `Mailbox__Door` and `Mailbox__Flag`: R opens and closes them (for the crew), about each part's pivot X axis
      (door −95°, flag +90°; an `OpenAngle` attribute in degrees changes it).
    - `GardenWindmill__Spinner`: turns about its own Z axis on every screen.
  - **Shrubs** (`BoxwoodShrub`, `HydrangeaBush`) start shaggy, showing `<Id>__Overgrowth`, until
    trimmed with a hedge tool (fit and wear as for hedges on a job). They're shaggy again
    `GameConfig.ShrubRegrowMinutes` (30) of play later.
  - **Limits:** up to 60 per business. With no model they're block placeholders built to the
    same conventions.

## 10. Premium

Things players can buy with Robux. The catalog is `Shared/Config/Premium.luau`, the server side
is `PremiumService` and they're sold in the shop computer's Orders app under **Premium**. Robux
never skips a level or a business requirement, and nothing is sold as plain cash.

- **Pro upgrades** are game passes, and each one works on every tool you own:
  - Diamond Blades (199): blades never dull.
  - Run-Flat Tires (149): tires never lose air or go flat.
  - Endless Spool (99): trimmer line never runs out.
  - Big Tank (99): fuel lasts three times as long.
- **Premium tools** are developer products that upgrade a tool you already own, for good. Each
  one gets a finish (Gold, Chrome or Stealth: the body loses its texture for that colour and
  material, while wheels and glass keep theirs) and a perk on that tool only. They are the
  Golden Push Mower, Chrome Self-Propelled Mower, Stealth String Trimmer, Chrome Leaf Blower,
  Golden Riding Mower and Stealth Zero-Turn, from 149 to 799.
- **Truck paint jobs** are developer products that change looks only. There are four tints at 49
  that keep the truck's texture, plus Stealth Wrap (99), and Chrome Wrap and Gold Wrap (149 each).
  They paint the truck's body, doors, tailgate and rear door, and not the trailer. You can switch
  between the ones you own, or go back to factory paint, from the same tab.
- **Where the looks show.** A finish is on the tool in your hands, in the truck, on the wall, in
  its delivery box, and set down on a service spot or in the vise. A paint job is on the truck
  parked at the business, on the drive cutscene and parked at the job (it's the leader's, so the
  whole crew sees it).
- **Perks** are checked in `Maintenance.wear`, so the vise, service spots and supplies still work
  as before. You just need them less.
- **Purchases:**
  - Game passes are checked when you join and when you buy one.
  - Developer products are granted in `ProcessReceipt`. That saves the player straight away and
    keeps the receipt id, so a purchase is never granted twice or lost. If the save fails, Roblox
    tries again later.
  - Each item's `gamePassId` or `productId` comes from the Creator Dashboard. Until it has one,
    the shop shows "Soon".

## Phases

| Phase | What | Status |
| --- | --- | --- |
| A | This doc; `Tools.luau`, `TaskTypes.luau` and the new `Jobs.luau` format; tool fit, quality and customer preference in pay; no tool names on the board or HUD; save versioning | done |
| B | Storage per building, size-based truck and trailer space, shop gating by tier and storage, selling tools, EquipmentYard, EquipmentTrailer, ToolBucket | done |
| C | Tier-1 jobs and yard targets: pots, planting spots with depths, bulbs, beds, lawn dandelions, rose bushes, dead stems, flowers, watering zones; gloves; tool guide and first-job coach | done |
| D | Tier-2: holes, trenches and sod, deep beds, hauling from a pile to a bed, spreader and sprayer, branch thickness | done |
| E | Maintenance systems and supplies | done |
| F | Tier-3 pro equipment and the turf renovation sequence | done |
| Camera | First person: arms, tools posed for the view, mouse and menus, crosshair, camera motion | done |
| Immersion 1 | Walk-in buildings, truck parked at the door, tailgates and ramps | done |
| Immersion 2 | Look-at loading, bed grid, tool bucket, ride-ons on the trailer | done |
| Hub 1 | Job computer, Orders and Business apps, deliveries in boxes | done |
| Hub 2 | Bigger plots with a driveway, leaving from the truck's driver door, pulling back in | done |
| Hub 3 | Your own lawn (regrowing, saved, worked with your own tools) and curb appeal's pay bonus | done |
| Hub 3b | Decorations: ordering, boxes, first-person placing with snapping, markers, shrubs to trim, curb appeal | done |
| Immersion 3 | Hands-on maintenance at service spots and the vise, steps for blades and wheels, tailgate supplies on a job, visible wear and ragged grass | done |
| Starting out | Grass shears as the free starting tool (cutting a snip at a time), the reel mower as the first buy, junk hidden in the grass, a 5-minute first job | **this PR** |

New tools are already in `Tools.luau` with `available = false`, so they aren't sold until the
phase that gives them work.

## Saves

`DataService` keeps a `version` on every save and runs `MIGRATIONS` in order on load:

- **Version 2 (phase A)** just starts the versioning. Tools kept their ids and categories, so
  nothing moves, and money, level and owned items carry over as-is.
- A save from a newer version of the game is played but never overwritten. Saves go through
  `UpdateAsync`, which also refuses to write over one.
- If a migration fails, that session doesn't save, so the stored data is left alone. The player
  still gets a profile, so nothing waits on them forever.
- There's no session locking yet. A very fast server hop could still lose the last session;
  moving to ProfileStore or a session lock would fix that.
- **Version 3 (phase B)** moves to per-tool storage. A v2 save had one equipped tool per tool
  category and `loadout[category]`; now every owned tool stands alone and `loadout[toolId]` says
  it's in the truck. Each category's equipped tool that was in the truck stays in the truck, and
  `equipped` only holds the truck, trailer and business. Players who own a riding or zero-turn
  mower get the `EquipmentTrailer` free (hitched up if they had no trailer), since ride-ons only
  travel on one now. Money, level and owned items carry over.
- **Version 4 (phase E)** adds `condition` (fuel, tires, blade, line, supply uses) for every owned
  tool. Existing tools start as good as new.
- **Version 5 (Immersion)** adds `spots` (the storage spot each tool goes back to) and `bucket`
  (the hand tools in the tool bucket). A v4 bucket in the truck carried up to 8 of the hand tools
  loaded with it, so those go in the bucket and the load stays the same.
- **Version 6 (the shop as the hub)** adds `deliveries`, the orders still in their box. Everything
  bought before is already unpacked.
- **Version 7 (your own lawn)** adds `homeLawn`: which parts of the lawn are done, one character
  per target and task, when the last tidy tip was paid, and whether another is due. Existing players' lawns start
  overgrown.
- **Version 8 (decorations)** adds `decor`: the decorations `placed` in the yard (id, where in
  plot space, and a shrub's trim state) and those still in their `boxes`. Nobody has any yet.
- **`premium`** (Robux purchases) holds `owned`, `passes`, `truckPaint` and `receipts`. It needs
  no new version: loading fills in whatever's missing, so older saves start with nothing bought.
- **Version 9 (starting out with shears)** keeps everyone's reel mower. Until now it was free
  starter gear that every load handed out, so every older save gets `owned.Mower.ReelMower` (it
  stays wherever it was, truck included). Loading gives everyone the free grass shears, as it does
  all starter gear. Junk in the grass isn't saved.

## New item ids for modelers

Every id below needs a model. Until then each one shows a block placeholder. All models: built at
the origin, standing on the ground, front facing -Z, unbranded, phone-friendly. Tools are held
by a part named `Handle` (see `assets/README.md`).

### Tools (`Assets/Tools/<id>`)

| Id | Size class | Look |
| --- | --- | --- |
| HandTrowel | Hand | Short wooden or rubber handle with a scoop-shaped steel blade, about 12 in long |
| HandTransplanter | Hand | Like a trowel but with a narrow, deep blade and etched depth marks |
| HandCultivator | Hand | Short handle ending in three curved steel claw tines |
| DandelionWeeder | Hand | Long thin shaft ending in a V-forked tip, with a lever bump near the end |
| Dibber | Hand | Wooden T- or D-handle with a pointed, tapered shaft marked with depth rings |
| BypassPruners | Hand | Hand pruners with two curved scissor blades and red grips |
| AnvilPruners | Hand | Hand pruners with one straight blade closing onto a flat anvil, yellow grips |
| FloralSnips | Hand | Small, slim scissors with long fine blades and soft loop handles |
| GardenHoseWand | HangingPower | Coiled green garden hose with a 30 in spray wand and pistol grip |
| WateringCan | Hand | Plastic or galvanized can with a long spout and a round sprinkler rose |
| NitrileGloves | Hand | Pair of knit work gloves with dark nitrile-dipped palms |
| RoundPointShovel | Long | Long wooden handle, dished blade with a pointed tip |
| GardenSpade | Long | D-handle, flat rectangular blade with a straight bottom edge |
| Broadfork | Long | Two tall upright handles joined by a wide crossbar with 5 long steel tines |
| DiggingFork | Long | D-handle with 4 strong, flat steel tines |
| BowRake | Long | Long handle, rigid steel head with short straight tines on bow-shaped arms |
| StirrupHoe | Long | Long handle ending in a hinged, square loop of thin steel blade |
| Mattock | Long | Hickory handle with a heavy steel head: wide adze blade one side, pick the other |
| Loppers | Long | Two long handles (about 28 in) with bypass blades at the end |
| PruningSaw | Hand | Folding saw with a curved, toothy blade and a rubber grip |
| SingleWheelbarrow | FloorManual | Green steel tray, one air-filled tire up front, two wooden handles |
| SingleWheelbarrowFlatFree | FloorManual | Red tray wheelbarrow with one solid black foam tire |
| DualWheelbarrow | FloorManual | Yellow tray wheelbarrow with two air tires side by side and a loop handle |
| PolyCart | FloorManual | Big blue plastic tub cart on two wide solid wheels, with a front pull handle |
| BroadcastSpreader | FloorManual | Push spreader: orange hopper over a spinning plate, two air tires, push handle |
| BackpackSprayer | HangingPower | Yellow plastic tank with shoulder straps, side pump lever and a spray wand |
| ChemicalGloves | Hand | Long-cuffed, fully green nitrile gloves |
| CommercialZeroTurn | Bay | Big red commercial zero-turn: 60 in deck, high-back seat, roll bar, lap bars |
| StandOnMower | Bay | Compact orange stand-on mower: platform at the back, control bars, mid deck |
| CommercialReelMower | FloorEngine | Walk-behind greens mower: reel cutting unit up front, small engine, grass basket |
| StraightShaftTrimmer | HangingPower | Long straight-shaft pro trimmer, engine at the back, bike-style handle, line head |
| ArticulatingHedgeTrimmer | HangingPower | Long pole trimmer with a hinged cutting bar at the end, engine at the back |
| StandOnAerator | Bay | Stand-on machine with a rotating drum of hollow tines and a rear platform |
| TowBehindAerator | Bay | Tow-behind frame with a tine drum, two wheels and a hitch tongue |
| SlitOverseeder | FloorEngine | Walk-behind machine with a seed hopper over vertical slicing blades |
| PowerRakeDethatcher | FloorEngine | Walk-behind machine with a flail reel under a low hood and a grass catcher |
| RideOnSpreaderSprayer | Bay | Three-wheeled ride-on with a granular hopper in front and a liquid tank behind the seat |
| SoilProbe | Hand | T-handle steel probe with a small digital temperature and moisture readout |

### Supplies (`Assets/Tools/<id>`)

| Id | Size class | Look |
| --- | --- | --- |
| ToolBucket | Supply | 5-gallon orange bucket with a canvas pocket organizer around the rim |
| GasCan | Supply | Red 5 L plastic gas can with a spout |
| MixGasCan | Supply | Green or blue 5 L gas can (two-stroke mix) |
| TrimmerLine | Supply | Spool of orange nylon trimmer line |
| FootPump | Supply | Foot pump with a gauge and a hose |
| ElectricInflator | Supply | Handheld cordless inflator with a short hose |
| AirCompressor | Supply | Red pancake air compressor with a coiled hose (stays in the building) |
| TirePatchKit | Supply | Small plastic case of tire plugs and patches |
| SpareTire | Supply | Small mower tire on a rim |
| WrenchSet | Supply | Folding case of sockets and wrenches |
| BladeFile | Supply | Flat mill file with a handle |
| SharpeningStone | Supply | Gray whetstone, about 6 in long |
| BenchGrinder | Supply | Bench grinder with two wheels and eye shields (stays in the building) |
| SpareMowerBlade | Supply | Flat mower blade with a center hole |

### Junk in the grass (`Assets/Props/<id>`)

Small things lying on the lawn, hidden in tall grass (see "Junk in the grass"). Built like the
decorations: origin on the ground at the centre, front toward -Z, an invisible `Root` part at
(0, 0.5, 0) and `<Id>__Body` parts, real size, nothing taller than about 0.6 studs so it hides in
the grass. No collision; players look at it to pick it up.

| Id | Look |
| --- | --- |
| DebrisStick | A dead, bark-brown stick about 2.4 studs long with a short twig, lying flat |
| DebrisRock | A fist-sized grey field stone, about 0.8 x 0.5 x 0.65 |
| DebrisDogBall | A slightly chewed, fuzzy yellow-green tennis ball, 0.55 across |
| DebrisToyTruck | A kid's plastic toy dump truck, red bed and yellow cab, about 1.1 long, facing -Z |
| DebrisFrisbee | A plastic frisbee lying flat, orange, 1 stud across |

### Vehicles, buildings and fixtures

| Id | Folder | Look |
| --- | --- | --- |
| EquipmentTrailer | `Assets/Trailers` | Low tandem-axle flatbed with a fold-down rear ramp and a `BedArea` part |
| StorageShelf | `Assets/Props` | Floor-standing gray metal shelf, about 4 wide x 5 tall x 1.4 deep, 3 boards; `Slot1`-`Slot6` attachments (2 per board) |
| EquipmentYard | `Assets/Buildings` | Business tier 4: fenced yard with a big roll-up-door shop and covered equipment bays |
| Workbench | `Assets/Props` | Sturdy wooden bench with a vise and a pegboard back; a `ServiceSpot` attachment on the floor in front (where a machine is set down) and a `VisePoint` in the vise jaws |
| StoragePegboard | `Assets/Props` | Wall pegboard panel with hooks for hand tools |
| StorageWallRack | `Assets/Props` | Wall rack with slots for long-handled tools |
| StorageWallHooks | `Assets/Props` | Row of heavy wall hooks for trimmers and blowers |
| JobLaptopTable | `Assets/Props` | Shed job computer: folding table, rugged laptop (`__Screen`), stool (`__Chair`), `UseSpot`, `ScreenView` (instructions33) |
| JobComputerDesk | `Assets/Props` | Garage job computer: steel tanker desk, monitor (`__Screen`), shop stool (`__Chair`), `UseSpot`, `ScreenView` |
| JobOfficeDesk | `Assets/Props` | SmallOffice and EquipmentYard job computer: L-desk, two monitors (`__Screen`, `__Screen2`), office chair (`__Chair`), `UseSpot`, `ScreenView` |
| DeliveryBoxSmall | `Assets/Props` | Small taped box, `__FlapL` / `__FlapR` on their hinges, `Contents` |
| DeliveryBoxLong | `Assets/Props` | Long narrow box, `__Lid` hinged at the back, `Contents` |
| DeliveryBoxLarge | `Assets/Props` | Large box, `__FlapL` / `__FlapR` / `__FlapF` / `__FlapB`, `Contents` |
| DeliveryCrate | `Assets/Props` | Wooden crate on a pallet, `__Lid` and `__FrontPanel` (hinged at the bottom into a ramp), `Contents` |
| PicketFenceSection, StoneEdgingSection, PaverPathSection, MulchBedSection | `Assets/Decorations` | Borders and paths that join end to end with `SnapL` / `SnapR` (instructions34) |
| BoxwoodShrub, HydrangeaBush | `Assets/Decorations` | Shrubs, with `<Id>__Overgrowth` shown until trimmed |
| JapaneseMaple, TerracottaPlanter, RaisedGardenBed | `Assets/Decorations` | Plants (`__Canopy`, `__Plants`) |
| BirdBath, TieredFountain, GardenArbor, GardenBench, PatioSet, FirePit | `Assets/Decorations` | Features: `Water` / `Water1`-`3`, `Spout`, `Seat` / `Seat1`-`4`, `Fire` markers |
| Mailbox, LampPost, SolarPathLight, BirdFeeder, Birdhouse, PinkFlamingo, GardenWindmill | `Assets/Decorations` | `Mailbox__Door` / `__Flag` on hinges, `Light` markers, `GardenWindmill__Spinner` |
| GardenGnome, FlowerPatch | `Assets/Decorations` (or `Assets/Props`) | Sold as decorations too; the yard props are used if there's no decoration model |
| All trucks | `Assets/Trucks` | Add `<Id>__DriverDoor` and `<Id>__DriverDoorGlass` (left door, origin on the hinge) and a `DriverSeat` attachment at the driver's eyes (instructions25) |
