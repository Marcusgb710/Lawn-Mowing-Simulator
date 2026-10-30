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
- Mowing is the exception to "work speed": a mower's sweep cuts everything under its deck, so a
  fit changes the pay and the finish but never how fast it cuts (see "Mowing: cells, swaths and
  shells" in section 4).
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

**A new player starts on a lawn, not at the computer.** A first-timer (`Season.isFirstTimer`: the
save's `firstJob` is false and no job is finished) joins straight onto their first job:
`JobService:StartFirstJob` takes the hidden `FirstMow` job (below), builds the yard with their
truck parked out front, starts the clock and stands them on the sidewalk facing the house with the
shears in their hands. Only then does the title card lift, so the first thing they see is grass
and a coach line: "Click and hold to snip. Clear the lawn." ("Hold Snip to cut." on a phone). The
truck brings them home after the payday like after any job, and the story's intro plays then, as
June's welcome. The second job teaches the computer, the Jobs app, loading the truck and the drive,
and the coach stays up until it's paid. `firstJob` is saved as the opening starts, so someone who
leaves mid-job comes back to their business and the usual flow, and if the opening fails they just
start at their business.

- **Shears cut by hand, a snip at a time** (`snip` in `Tools.luau`, `SnipController`, `ToolService`).
  Each click (or tap, or the **Snip** button on a phone) cuts what's where you aim: the grass
  around that spot or, where there's none left to cut, the one weed nearest. Holding the button
  keeps snipping, two snips a second. A snip lands
  where your aim crosses grass-top height (1 stud up), up to 7.5 studs from your eyes, so you look
  down at the grass and move along as you go. The client only says which way you're looking; the
  server works out where that lands and what's there, and limits snips to the shears' rhythm.
- **A snip clears a patch of grass.** It cuts every tall cell whose center is within **1 stud** of
  where it lands (`GameConfig.SnipRadius`): 1 to 4 cells, about 3 on fresh grass, all at once and
  never in stages. The shears are a Good fit for `MowSmallLawn` (x0.8), which lowers the pay, not
  the cut. A dull pair leaves the patch ragged instead of taking longer. A weed still takes
  several snips (**12**: a snip does 0.225 x 0.8 = 0.18 of the 2 a weed takes). The shears wear
  like any fine edge (a sharpening stone fixes them). They have no Mow verb, so their blade stays
  a fine one, and they can't do any lawn bigger than a small one.
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

A mower's deck is twice its **Width (radius)**, and how fast it clears a lawn is its deck width
and its walk speed. A mower's **Power** does nothing now, and the shop no longer shows it; other
tools still use theirs. See "Mowing: cells, swaths and shells" in section 4.

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
- `lawn`: columns, rows (in 4-stud tiles) and flower patches
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

### Mowing: cells, swaths and shells

The grass isn't a field of tiles. A lawn's grass is a ledger of **1-stud cells**
(`GameConfig.CellSize`, `src/shared/LawnGrid.luau`), a mower's deck cuts the cells it sweeps over,
and the picture is carved to match. Everything that isn't grass (edges, hedges, weeds, leaves,
flowers, the turf-renovation steps) keeps the **4-stud tile** (`GameConfig.TileSize`): a job's
`lawn` is still columns and rows of tiles, each holding 4 x 4 = 16 cells.

- **The ledger.** The server keeps one state per cell: tall, mowed, ragged (a dull blade's cut) or
  no grass (under flower patches and tree rings). Pay, progress, the finish and where the junk lies
  are all counted from it. The cells beside flowers and trees are **optional**: leaving them costs
  nothing, and cutting them counts for nothing towards the job.
- **The sweep.** Every work tick the mower's deck goes from where it was last tick to where it is
  now, and every tall cell whose center it passes strictly inside is cut at once (`Lawn:Sweep`).
  The deck is **twice the mower's `radius`** wide and sits **2** studs ahead of the player
  (`GameConfig.DeckOffset`). Its cut reaches a stud past each end of a sweep (`LawnGrid.DeckReach`),
  so a mower standing still cuts the strip under its deck once. Nothing meters the cut: a mower
  clears a lawn as fast as its deck is wide and it walks, and the tool's fit changes only the pay
  and the finish.
- **The swath log.** A sweep or snip that cut something is logged as a segment (where the deck
  went, how wide, its shade, whether it was ragged; `src/shared/Swath.luau`) and sent to the
  players in range as a `Swath` event. A sweep that carries straight on from that mower's last one
  (same width, shade and ragging, starting within a quarter stud of where it ended and within 2
  degrees of its heading) stretches that entry, so a straight pass is one entry however long it
  takes, and two mowers on one lawn don't break each other's passes. The log keeps the newest
  **1024** entries (`Swath.MAX_LOG`); the ledger is the truth, so a cut older than that only loses
  its stripe on a fresh draw.
- **Shade.** Stripes come from how you drive, against the lawn's local +Z ("away from the
  street"). Travel whose direction has a dot product with +Z above **0.5** cuts a **Light** stripe
  (heading away from the street), below **-0.5** a **Dark** one (coming back), and anything between
  is **Flat**. A tidy back-and-forth makes real stripes and a scribble looks like one. The greens
  are close enough to read as one lawn (`Swath.Colors`), and stripes change no pay.
- **Ragged cuts.** A blade under half sharp (finish below 0.8) tears the grass instead of slowing
  the mower. Those cells are **Ragged**: a duller yellow-green with tufts left standing, torn cell
  by cell. They count as cut, and the dull blade's lower finish weighs on the job as before, scaled
  to cells.
- **Drawn on the client.** The ledger is never sent every tick (at 1-stud cells it's 16 times what
  tiles were). A client that starts drawing a lawn (or respawns) asks for the ledger and the log
  (`GetSwaths`, answered at most once a second per lawn; a refused ask is tried again after 1.5 s),
  then follows `Swath` events, and `Regrow` events on a home lawn. Lawns more
  than **200** studs from the camera aren't drawn (30 studs of slack before one is dropped), and
  their images are destroyed.
- **A turf plate and grass shells.** A drawn lawn is one flat plate of turf plus a few thin
  **shells** stacked above it, each a Decal showing its own EditableImage
  (`GrassController`, `GrassPaint`, `src/shared/GrassImages.luau`). The turf image holds the stripe
  colors and faint wheel tracks. Each shell is a field of blade dots that thins out towards the top
  one, so from the side the stack reads as standing grass and from above as dense turf. A swath
  paints its shade into the turf and erases its own shape from every shell, so the cut follows the
  deck instead of snapping to cells. Pictures are **4 pixels a stud** (`PixelsPerStud`) and never
  above **1024 x 1024**: a lawn too big for that drops to 2, then 1 pixel a stud (the biggest job
  lawn, 112 x 88 studs, is 448 x 352 at 4). Shells: **6** on desktop and console, **4** on phones
  (touch and no keyboard), never fewer than 2.
- **A real texture under the paint.** With the lawn art uploaded (`GrassArt`) the turf plate also
  carries the mown-lawn map as a tiling `Texture` (one tile per 8 studs) under its Decal, so the
  turf image only has to hold what changes: uncut grass is an opaque mottle sampled from the uncut
  map, and mown grass is a translucent tint of its stripe shade (35% light, 45% dark) that lets the
  texture show through. Each shell stamps one of eight tufts from the tuft sheet, about a stud
  across, at every blade dot instead of drawing a circle. A lawn too far away to draw keeps its bare
  turf, which shows the uncut texture when most of the lawn is still tall at the moment it goes
  far and the mown one otherwise, so it still reads as lawn. If the mown, uncut or tuft image is
  missing or won't load, the lawn is painted in flat colours and dots as before, with one warning,
  for the session.
- **Your own mower doesn't wait.** Work ticks are coarser than frames, so a swath that only showed
  up on each tick would appear in chunks behind the deck. The client paints its own mower's strip
  every frame, from where the deck is on screen. The server's swath for it lands on the same
  pixels, and a cell the server hasn't confirmed within **0.5 s** (junk stopped the deck, or the
  cut was refused) grows back from the client's copy of the ledger. Other players' mowers, and a
  dull blade's torn cut, are drawn from the server's swaths only.
- **The fallback.** EditableImage fails in a published game (and in Studio) until the owner turns
  on **Allow Mesh / Image APIs** (Experience Settings → Security), and creating one fails too when
  a device's memory budget is spent. Then the client draws lawns the plain way for the rest of the
  session (`GrassFallback`): one flat plate of mown green with a block of tall grass over every
  2 x 2 patch of cells that still has an uncut one. No stripes, no smooth edges, and no missed-spots
  button, since there's nothing to tint. It follows the same ledger and the same events, so the
  job plays and finishes the same. It's a safety net, and the game never assumes the toggle is on.
- **The counter.** The mowing row on the job tracker shows the percent of the required cells that
  are cut (the lawn's mowable cells less the optional ones), where other tasks count what's done.
  A job's mowing finishes at **99%** of the required cells (`GameConfig.MowCompletionThreshold`);
  every other task keeps **95%** (`CompletionThreshold`), and so does a home lawn's grass, which
  has no percent and no missed-spots button to chase the last cells with.
- **Show what I missed.** From **90%** (`MissedSpotsFrom`) until the job counts as done, a
  **Show what I missed** button under the tracker (key **M** on a keyboard) tints the uncut grass
  red for **3 s** (`MissedSpotsSeconds`), with a soft pulse. It only shows over a job's lawn drawn
  as a surface.
- **Finishing.** The mowing row gets the `LawnDone` chime and the art's Job Complete! stamp, once,
  and the job goes on as before.
- **Feel.** The server sets the tool's `Cutting` attribute when a tick's sweep cut a cell, and
  clears it when it didn't. While it's set: walk speed x**0.85** (`CuttingSlowdown`), camera shake
  x**1.5** while a gas engine runs (`CuttingShake`), and clippings fly from the mower's chute. It
  also sets `Mows` whenever the mower fits the lawn under its deck and nothing holds it (junk, a
  stall, being off the job), cut or not: your own mower's swath is painted locally from the first
  stud while `Mows` is on, and the server's swath confirms it within **0.5 s**.
- **Sound** (`EngineAudioController`, ids in `Sounds.Ids`). A petrol mower idles on `EngineIdle`
  and crossfades to a lower `EngineLoad` while it cuts, with its pitch down to **0.85** (nudged up
  a touch while you move). `PullStart` plays the first time it runs after you equip it. A reel
  mower whirrs (`ReelWhirr`) while you push it. Everyone hears everyone's mower.
- **Pay.** A cell pays 1/16 of what a tile did (`workPerTarget` / 16), so a lawn pays what it
  always has.
- **Growing back.** On a home lawn the server marks cells tall again and sends their indexes in a
  `Regrow` event. Each client grows that grass back in its pictures.
- **Checks.** `lune run scripts/check-mowing` runs the lawn's math outside Roblox: which cells a
  sweep and a snip cut, the shade rule, the swath log, the needed-count arithmetic and the line
  clipping.

### The first job

Every new player's very first job is `FirstMow` (shown as **Front Strip**, Edna's), handed out as
they join (see "Starting out") and never on the board (it's `hidden`, so `Jobs.boardTemplates`
leaves it out). It's 5 x 6 tiles (20 x 24 studs) with no flowers: 480 grass cells, done at 99% =
**476**, about half the Front Lawn's. By the arithmetic below that's ~80 s of snipping, ~15 s
re-aiming, ~15 s walking and ~30 s finding your feet: **about 2 1/3 minutes** (~140 s), par time
150 s. It hides no junk (`junk = 0`): the coach teaches the snip and nothing else, so a new player
can't lose stars, the tip or the first milestone to something they were never told about. Junk
comes with the next job. It pays exactly $60 (no roll), about $51 with the shears' fit and a fine
finish, and 25 xp.

After that, with only the shears, the board's first slot is always `QuickMow` (shown as **Front
Lawn**), the one job the free gear can finish, so it's every new player's second. It's built to
take a new player **about 5 minutes** with the shears:

| | |
| --- | --- |
| Lawn | 9 x 7 tiles (36 x 28 studs), 1 flower patch: 992 grass cells. The 128 around the flowers are optional, so it's done at 99% of the other 864 = **856 cells** |
| Snipping | 856 cells at about 3 a snip x 0.5 s = **~143 s** |
| Re-aiming | about one lost beat (0.5 s) every 6 snips = **~24 s** |
| Walking | a few steps every few tiles (you reach about 6 studs) = **~30 s** |
| Junk | 4 pieces to spot and pick up, ~10 s each = **~40 s** |
| Finding your feet | reading the coach, first snips = **~30 s** |
| Total | **~267 s, about 4 1/2 minutes**; par time 300 s |

That's arithmetic, not a stopwatch time: it takes about 3 cells a snip (the area of a 1-stud
circle) and assumes no snip overlaps another, so time it in Play.

It pays $70 base (offers roll $65-90). With the shears' Good fit (x0.8) and a fine finish, a
new player earns about **$66 a job**, so the $150 reel mower takes 2-3 jobs. The same lawn takes a
reel mower (a 5-stud deck: about 8 passes of 28 studs at 12 studs/s, less 15% while it cuts, after
picking up the junk) a little over a minute, which beats half par for the full speed bonus: about
$94 a job. That's the reward for upgrading;
every later mowing job is sized for real mowers. 15 xp.

### Junk in the grass

The challenge in every lawn that needs mowing: sticks, a dog's ball, a kid's toy truck, a frisbee
and rocks lie hidden in the uncut grass (`src/shared/Config/Debris.luau`, `LawnService`). Players
have to spot them and pick them up (look at one and press **E**, or tap the big button) before
cutting there.

- **How much:** one piece per 16 lawn tiles on homeowner jobs, per 14 on serious ones and per 12
  on pro ones, rounded, 1 to 10 (a job's `junk`, or its lawn's `debris`, sets it outright): 2 on a
  tiny yard, none on the first job's strip, 4 on the Front Lawn, 5 on a suburban lawn, 10 on the
  big ones. Each lies on one cell, never on the
  optional cells beside flowers and trees, and at least 4 cells (4 studs) from the next piece.
  Sticks turn up most often, then rocks and balls, then toys and frisbees.
- **Grass shears can't snip a spot with something in it**: a snip that would cut a cell with junk
  on it does nothing ("There's a stick in the grass there. Pick it up first."). A **reel mower**,
  like any mower that isn't motorized, jams on it ("The mower jams on..."): its sweep ends before
  the junk's cell, so that cell and the grass beyond it in that pass stay tall until it's cleared.
- **A motorized mower runs right over it and chews it up.** Its blade loses a chunk of its edge at
  once (`wear`: a rock 0.3, a stick or a toy 0.15, a ball or frisbee 0.05, through
  `Maintenance.strike`; Diamond Blades still never dull), the engine stalls for 1.5 s, bits fly
  out, and the customer notices: the crew is told, and it costs 4% of the pay (at least $3).
- **Whatever's left at the end** costs the same, and every piece left or chewed up takes 0.04 off
  the finish. The tracker shows "Pick up junk in the grass 1/4" (how many there are, never where),
  and the pay breakdown says how many were left or chewed up.
- **Your own lawn** hides a couple too, and each tile's worth of grass that grows back has a 5%
  chance of something new turning up in it (a cell carries 1/16 of that), up to 3 at a time. There
  they only cost blade wear and stalls.
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
- **Fertilizing** covers every lawn tile (still 4 studs a side: only mowing is cut into cells); a
  pale dusting shows where it landed.
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
| WoodedEstate | a tight lawn with trees in mulch rings (`trees`) to mow around. The `tight` speed scale (`0.4 + 0.6 x maneuverability`) only slowed the old tile work: a sweep isn't metered, so maneuverability no longer slows a mower here |
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
| Blade | mowers, edgers, spades ("heavy"); pruners, shears, hedge trimmers ("fine") | 1200 s of cutting | slower and rougher cut (quality down to 60%); a mower isn't slowed, its cut goes ragged once the blade is under half sharp |
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
- **Facing where you're put.** First person keeps looking wherever the camera was. So whenever the
  server moves you (back to the shop after a respawn or a job, out to a job's house, to a new
  crew's shop), it says which way to face. The camera turns that way, level, as soon as it's back
  in first person: when the title card goes at join, and when the drive cutscene or a dialogue
  scene hands the camera back.
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
    (`LawnGrid.RAGGED`; `GrassPaint` draws it, cell by cell).

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
  3. the desktop opens, with five apps:
     - **Jobs:** today's board, with hints only. Anyone can look; only the crew leader can take
       a job. From the story's act 2, TurfKing now and then takes a job off a leader's board
       ("Taken by TurfKing", docs/STORY.md).
     - **Orders:** tools and supplies, plus a Sell tab for tools in storage.
     - **Business:** building, truck and trailer upgrades.
     - **Crew.**
     - **Messages:** the story's texts from Grandma June, the Bridge Club, Chad, Sam and your
       customers, with unread badges and the goal for the act you're in (docs/STORY.md).

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
  `LawnService` and cut and drawn like customers' lawns (cells, swaths and shells: see "Mowing:
  cells, swaths and shells" in section 4):
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
  (a grass cell, an edge strip, a weed, a leaf pile), never right next to someone. Grass comes back
  a cell at a time, and every client drawing the lawn grows it back in its pictures. It doesn't
  grow while you're offline. What's done is saved (`homeLawn`), so it looks the same when you come
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
- **The Best Yard contest** (`ContestService`, `Config/Contest.luau`; the story's act 4 in
  docs/STORY.md). It judges your own business's yard, using what this section already measures:
  - **Lawn and stripes:** the lawn's done share, less 2 per piece of junk in the grass.
  - **Edges:** its edge targets.
  - **Beds and shrubs:** beds and trimmed shrubs.
  - **Decorations and charm:** the decoration share curb appeal uses, plus how many different
    kinds there are.

  Each category is out of 25, against Gloria's bar (88, then 2 more each new summer, capped at
  96: a win starts one, and so do four lost Saturdays). Calling the judges from the Messages app
  scores the yard there and then. Winning pays $2,500, and the first win also brings the Best Yard
  Trophy (a decoration that's only ever won) and half off the next building from the Small Office
  up. After the first judging day, judging day is every Saturday (UTC) instead of a wait in jobs
  (section 11).

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
  - Each item's `gamePassId` or `productId` is its id on Roblox. `scripts/premium-setup.py`
    creates any item with id 0 on Roblox through Open Cloud, puts everything on sale at its price
    and writes the ids in. Until an item has one, the shop shows "Soon".

## 11. The Busy Season

The pull that brings a player back: a first minute that puts a tool in your hand, a ladder that pays
out every few minutes, and a reason to open the game tomorrow. It adds nothing to sell for Robux and
nothing that stops you playing. The design is
`docs/superpowers/specs/2026-10-29-busy-season-design.md`. The numbers below are the config files'
(`lune run scripts/check-season` checks the tables); this section says what they mean.

### The first minute and the ladder

**First job first.** A first-timer (the save's `firstJob` is false and no job is finished) joins
straight onto the hidden `FirstMow` job: a 5 by 6 tile strip with no junk in the grass, par time
150 s, pay $60 and 25 XP, with the grass shears in hand and the truck parked out front. The flow
and its arithmetic are in "Starting out" and "The first job".

**Stars and tips** (`Config/Stars.luau`). A finished job earns one to three stars from the pay
formula's own performance factor: the quality and speed multipliers blended by what the customer
cares about, where 1.0 is "as expected". Three stars take a factor of 1.1 or more and no penalty
(no flower or gnome hit, no junk left or chewed up), two take 0.9 or more, and one is anything
below. The customer tips 15% of the pay at three stars, 5% at two and nothing at one, and a tip
counts as money earned. The best stars on each kind of job are saved and shown on the job board.

**The goals rail** (`Config/Milestones.luau`). Grandma's note shows three goals: the story's, then
the two milestones nearest to done, where nearest is the share still to go ($400 of $500 beats 2
jobs of 3). A milestone pays the moment it is reached:

- Jobs finished: 1, 3, 5, 10, 25, 50, 100, 250 and 500, paying $10 a job up to $2,500.
- Money earned: $500, $2,000, $10,000, $50,000 and $250,000. They pay nothing, and the rail stamps
  them.
- Three-star jobs: 1, 5, 25 and 100, paying $25 each.

On a phone held sideways the rail is the story goal alone, and the nearest milestone is the Next
chip under curb appeal.

**Levels** (`Config/Levels.luau`). The curve is the old one, `level = floor(sqrt(xp / 50)) + 1`,
but every level from 2 on has a named reward, shown on the level-up card and in the Levels panel
(the XP bar, or L), which lists the next five. Cash runs from $100 at level 2 to $5,000 at levels
18 and 20. Four levels also give a truck tint, in order: Racing Red at 3, Forest Green at 6, Sky
Blue at 9 and Midnight Black at 12 (they stay on sale for 49 Robux as a shortcut). Level 20 gives a
gold business sign. Past 20 every level pays $3,000, and every fifth pays $5,000 and a HUD stamp.
Rewards are claimed by level (`levelRewards`), so each pays once, and a save that is already past a
level is marked, not paid back pay.

Saved as data version 13: `earned`, `stars`, `milestones`, `levelRewards` and `firstJob`
(`Config/Season.luau` says how an older save gets them).

### Tomorrow

**Today's contracts** (`Config/Contracts.luau`). Three contracts a day, new at 00:00 UTC: always
one Mow, one Earn, and one more that is Junk or Stars, which the day's seed picks (the same player
gets the same three all day). What each asks and pays depends on the level band:

| Level | Mow (lawns) | Earn | Junk (pieces) | Stars (three-star jobs) | Pays each |
| --- | --- | --- | --- | --- | --- |
| 1 to 2 | 2 | $150 | 3 | 1 | $60 |
| 3 to 7 | 3 | $400 | 4 | 1 | $150 |
| 8 to 11 | 4 | $1,200 | 6 | 2 | $400 |
| 12 and up | 5 | $3,000 | 8 | 2 | $900 |

A contract pays the moment it is met, once. Finishing all three pays the **Bonus Day**, $500 more.
They count what you do that day: jobs finished, three-star jobs, junk picked up, and money earned
(tips, the streak's cash and the Bonus Day too). The mailbox at the curb (`Props/CurbMailbox`) and
the "Contracts 1/3" chip under the goals rail both open the panel.

**The login streak** (`Config/Streak.luau`). The first time you are in on a UTC day the streak grows
a day (it starts again at day 1 if you missed one) and that day's cash waits as a gift: the HUD's
Gifts button wears a tilted CLAIM tag and pulses until you press it. Claiming your gift pays the
day and shows a card for four seconds: "Day 3 of 7", today's cash and tomorrow's. A gift you never
claim is paid for you when the next day turns, once, with a "Yesterday's gift" toast, so nobody
loses a day's cash. The week pays $100, $150, $200, $300, $400, $600 and, on day 7, $1,000 and a
pennant for the truck, given once with the day 7 turn and flown from the bed
(`flags.TruckPennant`). After day 7 the week repeats with the same cash and no second pennant. The
Levels panel and the contracts panel show the streak, and while a gift waits they say "claim $200
in Gifts". With no gift waiting the Gifts button opens the contracts panel.

**The leaderboards** (`LeaderboardService`). Two OrderedDataStores, `LawnsMowed_v1` (jobs finished)
and `MoneyEarned_v1` (money earned). A player's numbers are written when one of their jobs
finishes, at most once a minute each (a finish inside that minute is written at the next refresh
or when they leave). The server reads both every two minutes and puts the top 25 of each on the
sign at the town spawn (`Props/LeaderboardSign`; each player's own screen draws the boards), with
the viewer's own line under them. It reads four pages deep, so anyone in the first 100 sees their
rank, and anyone further down sees "not in the top 100 yet" with their own number. Without
DataStores (Studio without API access, or no stores) the sign says the leaderboards are off, and
while the boards are on but no read has worked (an outage) it says they are not answering right
now; the game plays on either way. A Studio playtest uses boards of its own, so it never writes to
the live ones.

**Judging day on the calendar** (`Contest.calendarState`). The first judging day is unchanged: it
opens when act 4 begins, so the story lands the first time. After it, judging day is every
Saturday, UTC: the judges can be called once on each, and the goals rail and June's porch count
the days to the next.
A Saturday you miss changes nothing. A win starts the next summer with Gloria's bar up 2 (88 at
first, 96 at most), and so do four lost Saturdays after the first judging day, so the bar rises
even for someone who never wins.

Saved as data version 14: `daily`, `streak`, `flags`, and the contest's `lastJudged`, `saturdays`
and `offeredDay` (`Config/Season.luau`). The streak's `claimed` (the day whose gift was last
claimed) came later without a version bump: a save without it starts it at its `last`, since that
day was paid as it was kept. Everything that depends on the day asks the server's `Clock`
(`src/server/Clock.luau`): `os.time()` plus an offset that only Studio can set, from the test panel's
Next day and Jump to Saturday.

## 12. The HUD

The play screen is built like a front-page Roblox simulator: chunky buttons with a gradient face, a
thick dark outline and a lip under them, white rounded text with a dark edge, and a bounce when you
touch them. All of it is drawn in code (`src/client/Juicy.luau`, with the colours in
`JuicyPalette.luau`), so it adds no art to upload. Where each piece goes is `UiLayout.luau`. The look
was drawn first as the "Lawn HUD Restyle" mock; this section says how it behaves.

**The left.** Your money in a pill with a gold coin, which counts up when cash comes in and gives one
pulse. Under it the level pill (your level and an XP bar; press it for the Levels window) beside the
streak pill (the flame and "DAY 3", once you have a streak). When judging day is on the calendar, a
purple pill counts down to it. Then four colour squares: Truck, Guide, Crew and Contracts. The
Contracts one wears a tilted yellow tag with the contracts left today. On a keyboard each shows its key
(T, G, C). On a phone the four sit in a 2 by 2 grid.

**The top and the right.** Grandma's goal is a cream banner at the top in the middle, with a red flag,
the goal, its reward when it has one and a striped bar. Down the right, curb appeal, then during a job
the job card (dark glass: the job's name, a big timer with the par time, a bar for how much is
mown and a small Call off pill, which asks "Sure?" before it calls the job off), and under it small
pills for the pay bonuses you have (crew, curb appeal, truck, business). Late in the mowing the
"Show what I missed" button appears there. Against the right edge is a strip of four squares.

**The right buttons.** Shop opens the Orders window from anywhere (B on a keyboard): tools, supplies
and decorations can be bought and sold wherever you stand and arrive in a box at your shop door, but
trucks, trailers and business buildings still need the computer in your shop, and so does taking a
job. Gifts (no key) is the daily streak gift. Top Lawns (F) is the two leaderboards from the sign at
the town spawn, in a window: Lawns mowed and Money earned, 25 rows each and your own line under them.
Settings (comma) is the window described below.

**The gift.** The first time you play on a new day, the day turn moves your streak on but does not pay
it. The Gifts button wears a tilted CLAIM tag and pulses until you press it, and pressing it pays the
day's cash and plays the Payday card. If you never press it, the next day turn pays it for you with a
toast, so nobody loses money by forgetting. With no gift waiting the button opens the streak card.

**Settings.** Three choices that are kept with your save: Sound (Off, Low, High) is the volume of the
game's sounds, Camera motion (On, Off) is the head bob and the engine shake in first person (the V key
and the Guide's switch change the same one), and Grass detail (Auto, High, Low) is how many layers of
grass are drawn, which takes effect the next time you join. A player who never opens the window gets
what the game always did: full sound, motion as the camera config says, and Auto grass (4 layers on a
phone, 6 on a PC).

**The hotbar.** Roblox's own hotbar is off. The game's row of tool slots sits along the bottom on a job
site: the held tool's slot is cream, the others dark glass, each with the tool's picture and, with a
keyboard, its key (1 to 9, then 0). Press a key or tap a slot to take that tool out, or to put it away if
you are holding it. Every tool you have gets a slot. If the row would run into the move stick or the
jump button it shrinks, never below a size a thumb can hit, and past that the last slot is a gold "+N"
that opens a tray of the rest.

**Every button feels the same.** Over a button the pointer grows it a little, a press squashes it, it
springs back and a soft click plays (nothing grows under a finger on a phone). This is one helper
(`Juicy.juice`), used by the squares, the pills, the windows' Close buttons, the Top Lawns tabs and the
rest of the HUD's buttons.

**The stripe splash.** Mow a straight pass of 30 studs or more without the blade hitting anything
(and without the mower stalling, running out of fuel or going dull) and, when the pass ends, gold
words pop in a little above the middle of the screen and fade after a second: "NICE STRIPE!", then
"CLEAN CUT!", then "PERFECT LINE!", in turn. It is a pat on the back and nothing more: no XP, no
cash, nothing sent to the server. It shows at most once every 8 seconds, never over a menu, the pay
panel or a scene. A U-turn is two passes, not one long one.

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
| Starting out | Grass shears as the free starting tool (cutting a snip at a time), the reel mower as the first buy, junk hidden in the grass, a 5-minute first job | done |
| Fluid mowing | The lawn as 1-stud cells and swaths, drawn into EditableImage turf and grass shells with a plain-part fallback; a percent counter, a missed-spots button, engine sounds | **this PR** |

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
  per target and task, when the last tidy tip was paid, and whether another is due. Existing
  players' lawns start overgrown.
- **Version 8 (decorations)** adds `decor`: the decorations `placed` in the yard (id, where in
  plot space, and a shrub's trim state) and those still in their `boxes`. Nobody has any yet.
- **`premium`** (Robux purchases) holds `owned`, `passes`, `truckPaint` and `receipts`. It needs
  no new version: loading fills in whatever's missing, so older saves start with nothing bought.
- **Version 9 (starting out with shears)** keeps everyone's reel mower. Until now it was free
  starter gear that every load handed out, so every older save gets `owned.Mower.ReelMower` (it
  stays wherever it was, truck included). Loading gives everyone the free grass shears, as it does
  all starter gear. Junk in the grass isn't saved.
- **Version 10 (the story, docs/STORY.md)** adds `story`: the `act` you're in, the beats you've
  `seen`, the dialogue `scenes` still to play, your inbox of `texts` (at most
  `Story.InboxCap`, 60, the oldest dropped first), the last text you've `read` in each thread,
  and the number the next text gets. Everyone starts in act 1 with nothing seen. Players who
  have already done a job aren't shown the intro: `StoryService` catches them up to their act
  when they join.
- **Version 11 (the Best Yard contest)** adds `contest`:
  - `summer`, which summer it is (a win starts the next one, and so do four lost Saturdays, with
    Gloria's bar higher);
  - `wins` and `judged`, how many times you've won and how many judging days you've had;
  - `last`, the last result (`{ summer, won, you, gloria }`, the totals);
  - `pending`, the result waiting to be collected, with both sides' scores and the rewards. It's
    decided when the judges are called, so leaving before collecting changes nothing;
  - `nextAt`, the jobs done when the first judging day comes round (after it, judging day is every
    Saturday and it gates nothing);
  - `offered`, how many judging days there had been when June last texted that it's open (and, from
    version 14, `offeredDay`, the day of that text, so each open Saturday after the first judging
    day gets one);
  - `discount`, the building a win took half off, until it's bought.

  Everyone starts in summer 1 with nothing judged, and judging day opens as soon as they reach
  act 4.
- **TurfKing** (docs/STORY.md, item 4) needs no new version. It keeps two numbers in `story`:
  `flippedAt` (how many jobs you'd done when it last took one of yours) and `flips` (how many
  it's taken). A customer won back from it is remembered as the beat `QualityWin:<customer>` in
  `seen`. Loading fills in nothing: a save without them has never had a job taken.
- **Version 12 (fluid mowing)** keeps the home lawn's grass flags per 1-stud cell, since a grass
  target is a cell now. Its migration changes nothing: an older save's flags are one per 4 x 4 stud
  tile, and `HomeLawn.decode` spreads each over its tile's cells when the lawn is built, so a tidy
  lawn stays tidy. From then on it saves per cell.

## Models

Every id has a model in `assets/`, named after the id, and the game uses it in place of the block
placeholder. `assets/manifest/models.json` records where each one came from and how it was made to
fit; the design is `docs/superpowers/specs/2026-10-28-model-overhaul-design.md`, and the steps for
adding or replacing a model are in `assets/README.md` ("Adding or replacing a model"). The aim is
real hardware and Roblox people: mowers, trucks and buildings that look like the real thing, in
correct proportion, next to people who look like the avatars every player already is.

**Three sources**, tried in this order for every id:

1. **A free Creator Store model.** One object, not a set; unbranded, or with a logo that can be
   stripped; within its part budget once cleaned; and in step with the kit's look. One creator's
   family is preferred within a category, so a rack of mowers doesn't look like thirty hands made
   it. The game doesn't own a Store mesh. The manifest keeps its asset id, name and creator, so one
   that a creator takes down (the model goes blank in the game) can be found and swapped.
2. **A model built in hosted Blender**, from primitives with PBR materials, exported as GLB and
   brought in with File > Import 3D as Big Dink Studios. It is for the ids the Store has nothing
   good for. No model has been made this way yet.
3. **The current model, kept.** When neither beats it, or it is too small to matter (a blade file,
   a sharpening stone, a patch kit). The manifest lists it as `kept`, so the decision is on record.

**The contract** is what makes the source not matter. Whoever made a model, it ends up the same
shape, and `scripts/check-models.luau` fails one that breaks the parts a file can show (the
per-folder details are in `assets/README.md`). Branding, which way a mesh faces, the openings and
the phone test are judged in Studio and Play. The contract:
- Built at the origin, standing on the ground, front toward -Z, +Y up, at the game's scale: one
  stud is 0.28 m, so a person is about 5.5 studs tall, a push mower is 3.7 studs tall and a pickup
  is 17 to 20 studs long. Each manifest entry has one target size (`fit`), and the importer scales
  the model to it.
- Tools: a part named `Handle`, with `GripLeft` and `GripRight` attachments where the hands go.
  Wheels, rotors and spools named `<Id>__Wheel`, `<Id>__CutterRotor` and `<Id>__Spool` spin. A mesh
  that has them fused in just leaves them still.
- Everything else: an invisible `Root` part as the PrimaryPart, at (0, 0.5, 0).
- Trucks: a `BedArea` part where loaded tools lie, `<Id>__Body` on the body (the part a paint job
  and the TurfKing livery tint) and a `DriverSeat` attachment. When the mesh has them as separate
  parts, `<Id>__DriverDoor`, `<Id>__DriverDoorGlass` and `<Id>__Tailgate` are pivoted on their
  hinges for `Openings`. A pickup that is one fused mesh loses the door and tailgate swing and
  keeps everything else.
- Trailers: a `BedArea` part. The equipment trailer also has `EquipmentTrailer__Ramp` (ride-ons
  need it; its Store mesh has none, so it is a plain slab from the entry's `synth` list) and two
  `BaySpot` parts where they park.
- The customer's house: `Porch` and `Driveway` attachments. The business buildings keep the
  interior markers described under "Walk-in buildings" and "The shop as the hub".
- Nothing branded, and no script or sound in any model.
- A part budget per category, because phones are the reason for it. Triangles can't be counted from
  Luau, so the phone test is frame time: on the Galaxy A06 preset, the shop with every rack full and
  a job with the truck, trailer and house in view must average within 10% of the build before the
  overhaul. A model that misses is trimmed with its entry's `strip` list first, then swapped for
  another candidate, then kept as the old model.

**Batches.** Models are replaced in an order, each batch imported and checked before the next:
mowers and trimmers; blowers, edgers, hedge trimmers, barrows and carts, the spreader and sprayer,
gas cans and the bucket; the trucks and trailers; the customer's house; then the hand and
long-handled tools; the pro machines; and last the four business buildings together (Shed, Garage,
SmallOffice, EquipmentYard). The buildings change in one batch or not at all, because players
upgrade through them in that order and a new shed beside the old garage would mix looks. All four
current ones stay until all four new ones pass `check-models` and a walk-through in Play. The first
four batches are imported; the rest, and the things that are kept on purpose (decorations, storage
fixtures, delivery boxes, the junk in the grass, the trophy, Gloria's house with her yard stages,
porch, rocker and sign), are listed in TODO.md.

**The story's people** are not one of the three sources, and not model files. `Config/Cast.luau`
describes each of the nine as free catalog items (hair, hat, face, shirt, pants, layered clothes, a
T-shirt graphic, and a body scale), and `CastService` builds every one as an R15 rig when the
server starts, with `Players:CreateHumanoidModelFromDescription`. Each rig gets the contract too:
an invisible `Root` PrimaryPart 0.5 studs above the feet, so `Assets.placeAt` stands the person
where a statue used to stand, a `Head` attachment at eye level and a `Talk` attachment at the
chest, for speech bubbles and prompts. The rigs are parked under `ReplicatedStorage.Assets.Story`,
where `Assets.story` finds them on the server and on every client. If a rig can't be built (an item
taken down, Roblox unreachable), that id logs a warning and shows its block placeholder.
`NpcAnimator` plays Roblox's own Idle, Walk, Sit, Wave and Point animations (`Cast.Poses`), so
nothing has to be uploaded: the person's `pose` picks one, June sits in her rocker and the judges
walk the yard and stop. Every id must be free, public and not a limited collectible, and
`scripts/cast-check.py` asks the catalog (it needs the network, so it isn't one of the Lune
checks). Roblox's own items are preferred, but identity wins: Chad and Sam wear TurfKing's purple
with a stand-in top until its T-shirt graphic is made (`tshirt` is 0 for both).

**The lawn** uses real art the same way. `Config/GrassArt.luau` holds the ids of the kit's mown,
uncut and soil textures and of a sheet of grass tufts. With them the lawn is painted over a tiling
texture and its shells stamp tufts (see "Mowing: cells, swaths and shells"). It reads three of the
four ids, mown, uncut and tufts; the soil id is uploaded for later. While the mown, uncut or tuft
id is 0, the lawn is painted in flat colours and dots, as it was before, with one warning.

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
