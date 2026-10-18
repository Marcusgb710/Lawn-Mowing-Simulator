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
  leaves).
- `qualityHits` lower the finish some tools leave on a task (a bow rake tears turf: x0.6;
  anvil pruners crush live stems: x0.7).
- `speedHits` slow some tools down further (a shovel on hard ground: x0.6).
- `protection` (`Thorns`, `Chemicals`) means the task needs gloves that protect against it
  (phase C/D).

When a player uses a tool on targets it can't work, they're told **"That won't work here."**
(at most every few seconds), and never which tool would.

## 2. Tools by tier

The full catalog, with stats and the player-facing descriptions, is
`src/shared/Config/Tools.luau`. Every shop tab progresses Homeowner, then Serious, then Pro;
gating by player level and business building comes in phase B.

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
    - damage (10% of base pay, at least $5, per flower patch or gnome hit)
```

- **Quality multiplier**: 1 + (quality - 0.75) x 1.5, clamped to 0.5-1.3. The finish quality is
  the average of each tool's quality (mowers: cut quality) times any `qualityHits`, weighted by
  the work it did.
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
bulbs, 6 inches deep, along the front walk"), never tools. Jobs vary: some need one tool, others
several. Later phases add task `protection`, ordering, and soil conditions for pro jobs.

### Task types

| Phase | Task type | Verb | Ideal / Good / Poor |
| --- | --- | --- | --- |
| now | MowSmallLawn | Mow | ReelMower, GasPushMower, SelfPropelledMower / RidingMower, StandOnMower |
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

Replaces "one tool per category": players own many tools and pick what to bring to each job.
Owned items live in storage spots in the business building, shown visually, and are carried to
the truck with today's carry flow. You can't buy an item without a free spot of its class.

Proposed capacities (to tune):

| Building | Pegboard (Hand) | Wall rack (Long) | Wall hooks (HangingPower) | Floor spots | Bays | Fixtures |
| --- | --- | --- | --- | --- | --- | --- |
| Shed | 12 | 4 | 1 | 1, manual only (no engine) | 0 | - |
| Garage | 16 | 8 | 4 | 2 | 0 | workbench |
| SmallOffice | 24 | 12 | 6 | 4 | 2 | workbench, air compressor |
| EquipmentYard (new) | 32 | 16 | 10 | 6 | 5 | workbench, air compressor, bench grinder |

Proposed truck space, in units:

| Item | Space |
| --- | --- |
| hand tools | 1 each, or up to 8 in one `ToolBucket` (which takes 1) |
| long tools | 1 |
| handheld power tools | 2 |
| floor machines | 4 |
| supplies | 1 |
| bay machines | only on an `EquipmentTrailer` (ramp), 2 per trailer |

| Vehicle | Space |
| --- | --- |
| RustyPickup | 6 |
| WorkPickup | 8 |
| HeavyDutyPickup | 10 |
| LandscapingTruck | 14 |
| UtilityTrailer | +6 |
| LandscapeTrailer | +10 |
| EquipmentTrailer | +4, plus 2 bay machines |

## 6. Maintenance (phase E)

Simple but real, for mowers and equipment (not the truck):

- **Fuel.**
  - Four-stroke engines (mowers, aerators, dethatcher, overseeder, ride-ons) burn regular gas
    (`GasCan`).
  - Two-stroke handhelds (string trimmers, gas edgers, gas hedge trimmers, blowers) need 50:1 mix
    (`MixGasCan`).
  - Tanks drain with use; an empty tool stops. Wrong fuel damages the engine.
  - Tools carry an `engine` field already: None, Electric, Battery, FourStroke or TwoStroke.
- **Tires.**
  - Air tires slowly lose pressure and can puncture. Low pressure is slower and harder to push; a
    flat stops the machine.
  - Inflate with `FootPump` (slow), `ElectricInflator` (fast) or an `AirCompressor` at bigger
    buildings.
  - Fix with `TirePatchKit`, or swap a `SpareTire` using the `WrenchSet`.
  - Flat-free tires never need any of this. Tools carry a `tires` field already.
- **Blades.**
  - Mower blades, pruners and loppers dull with use, lowering cut quality (ragged tears).
  - Sharpen with `BladeFile` or `SharpeningStone` (slow) or a `BenchGrinder` (fast), or swap a
    `SpareMowerBlade` using the `WrenchSet`.
- **Trimmer line** runs out; reload with `TrimmerLine`.
- Do maintenance at the business workbench, or in the field if you brought the supplies (they
  take truck space).

## Phases

| Phase | What | Status |
| --- | --- | --- |
| A | This doc; `Tools.luau`, `TaskTypes.luau` and the new `Jobs.luau` format; tool fit, quality and customer preference in pay; no tool names on the board or HUD; save versioning | **this PR** |
| B | Storage per building, size-based truck and trailer space, shop gating by tier and storage, EquipmentYard, EquipmentTrailer, ToolBucket | next |
| C | Tier-1 jobs and yard targets: pots, planting spots with depths, bulbs, beds, lawn dandelions, rose bushes, dead stems, flowers, watering zones; gloves | |
| D | Tier-2: holes, trenches and sod, deep beds, hauling from a pile to a bed, spreader and sprayer, branch thickness | |
| E | Maintenance systems and supplies | |
| F | Tier-3 pro equipment and the turf renovation sequence | |

New tools are already in `Tools.luau` with `available = false`, so they aren't sold until the
phase that gives them work.

## Saves

`DataService` keeps a `version` on every save and runs `MIGRATIONS` in order on load:

- **Version 2 (phase A)** just starts the versioning. Tools kept their ids and categories, so
  nothing moves, and money, level and owned items carry over as-is.
- A save from a newer version of the game is played but never overwritten.
- If a migration fails, that session doesn't save, so the stored data is left alone.
- **Phase B** will add version 3, moving owned tools into per-tool storage.

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

### Vehicles, buildings and fixtures

| Id | Folder | Look |
| --- | --- | --- |
| EquipmentTrailer | `Assets/Trailers` | Low tandem-axle flatbed with a fold-down rear ramp and a `BedArea` part |
| EquipmentYard | `Assets/Buildings` | Business tier 4: fenced yard with a big roll-up-door shop and covered equipment bays |
| Workbench | `Assets/Props` | Sturdy wooden bench with a vise and a pegboard back |
| StoragePegboard | `Assets/Props` | Wall pegboard panel with hooks for hand tools |
| StorageWallRack | `Assets/Props` | Wall rack with slots for long-handled tools |
| StorageWallHooks | `Assets/Props` | Row of heavy wall hooks for trimmers and blowers |
