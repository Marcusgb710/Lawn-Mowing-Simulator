# Busy Season: the pull that makes Lawn Mowing Simulator a front-page game

## Intent

The game has a deep spine: six design phases of tools, hauling, gardening, maintenance and pro work, a first-person camera, a rival story, a contest, premium finishes. What it does not have is pull. Nothing pays out every few minutes, nothing is collected or shown off, nothing changes tomorrow, and there is nowhere to go. A player's first minute is a title card, a seven-line cutscene, a text hint and a walk to a computer. Avery's words: it feels empty and incomplete, like there could be more to the core loop and extras to do and explore.

Front-page simulators win on four pulls, and this document adds all four to the game that exists, without turning it into something else:

1. **The first minute puts a tool in your hand.** You cut grass within ten seconds of the title card.
2. **The ladder pays out.** Levels, goals and stars reward you every few minutes, visibly, with sound.
3. **Something to find and show.** Every lawn might hide a Find. Finds fill a book and a shelf, and complete sets give perks. A dog helps you look.
4. **Tomorrow is different, and the town is bigger than your street.** Daily contracts in your mailbox, a login streak, leaderboards, a judging day every week, and new districts that open as you level.

The feel stays "a real mowing business, Steam indie progression". Nothing is sold as cash, there are no timers that stop you playing, and nothing in this document is pay-to-win.

## Goals, non-goals, anti-goals

Goals:
- A new player cuts grass within ten seconds of the title card, and finishes their first job inside three minutes.
- A player always sees three things they are about to get, and gets one every three to six minutes in the first hour.
- A second-day player has a reason to open the game that did not exist on day one (contracts, streak, a judging day coming).
- Every job can surprise you (a Find), and the surprise accumulates somewhere you can look at.
- The world has places and names beyond your plot: districts with their own customers and looks.

Non-goals (this round):
- Free-roam driving through a connected town. Job lawns stay where they are built, reached by the drive cutscene. The districts change what you drive to, not how.
- Trading, gifting or chat between players.
- Pets beyond Buster. Buster is a helper, not a pet system.
- Rebirth or prestige. The level ladder has no cap and districts keep it going.

Anti-goals (a failure even if it works):
- Anything that makes mowing feel like a tap game: no energy, no cooldowns on jobs, no loot boxes.
- Selling progress for Robux. Premium stays finishes, passes and paints.
- A HUD that covers the lawn. Everything new fits the existing column layout and the phone rules (see Constraints).

## Constraints (from the existing game, binding)

- Phone-first: UiLayout columns, compactHeight 500, the shared top-centre slot on touch, no element wider than the existing panels. Grass stays at 4 shells on phones.
- Saves: every new field goes into `DataService.defaultData`, with a `MIGRATIONS` entry and a `typeof` guard, and into `snapshot()` if the client needs it. The data version is bumped once per slice.
- Nothing yields at module load; every Roblox API call that can fail in a live game is in a pcall with a fallback that keeps the game playable (the way GrassPaint falls back).
- Lune checks gate everything pure: `check-story` for story and goal text, `check-gui` for layout, a new `check-season` for the tables this document adds (goals, level rewards, finds, contracts, districts).
- Repo voice: plain sentences, no em dashes, headers that say what a thing is for.
- Models: new props (mailbox, leaderboard sign, finds shelf, the Finds themselves, Buster, district houses) come through the manifest pipeline (`assets/manifest/models.json`, Creator Store first) and have block or billboard placeholders until they land, the way `Assets.prop` already does.

## The four slices

Each slice is its own plan and its own PR, stacked in this order. Each leaves the game better on its own.

| Slice | Name | What it adds | Depends on |
|---|---|---|---|
| 1 | First Minute and the Ladder | first job first, goals rail, level rewards, stars and tips, cash pop and sounds | nothing |
| 2 | Tomorrow | daily contracts and the mailbox, login streak, leaderboards, judging day on the calendar | slice 1 (goals rail, sounds) |
| 3 | Finds | 30 Finds with rarity, the Finds Book and shelf, sets with perks, Buster | slice 1 (level rewards), slice 2 (contracts can ask for Finds) |
| 4 | Districts | Oak Hills, Lakefront and The Club, unlocked by level, with their own templates, looks, customers and Finds; the map in the Jobs app | slices 1 and 3 |

## Slice 1: First Minute and the Ladder

### 1a. First job first

Today: title card, Intro scene (seven lines), coach banner, walk to the desk, Jobs app, accept, load a tool into the truck, E on the door, pull-out and drive cutscenes, then cut. That is three to five minutes before grass moves.

New: a player whose save has `jobsCompleted == 0` and no accepted job is a **first-timer**. For a first-timer:
- The server accepts a **first-timer job** on join: a new template `FirstMow` ("Mrs. Alvarez's front strip"), half the cells of the QuickMow Front Lawn, the same tasks, par time 150 s, pay $60, xp 25, used only for this flow and never on the board. The full Front Lawn stays the board's starter job for the second job. (The Front Lawn takes about 4.5 minutes with the shears, which is too long for a first minute; shears speed and the reel mower's value stay as they are.)
- It sets the job state to Working and arrives the crew at the job site the way `DriveToJob` would at the end of the drive, with the truck parked there and Grandma's shears in the player's hands (owned and equipped already). No pull-out or drive cutscene.
- The title card waits for `ArrivedAtJob` instead of `ArrivedAtBusiness` for a first-timer, so the first thing after the tap is the lawn, the shears, and the coach banner: "Hold E to snip. Clear the lawn."
- The Intro scene does not play on join. It plays as **June's welcome** when the truck brings the first-timer home after the first payday: same seven lines, same shears card (which now reads "Grandma's Grass Shears, already yours"), then the existing FirstJob texts. The second job is where the desk, the Jobs app and the truck door are taught; the coach banner stays until the second job is paid instead of the first.
- A first-timer who leaves mid-job and comes back is no longer a first-timer (the job is accepted); the normal flow resumes.

Why not shorten the intro: the intro is good writing and sets the rival up. It just cannot be the first minute.

### 1b. The goals rail

Today: one sticky note, "Grandma's Goal", with the story's next step.

New: the note becomes a **rail of three goals**, top to bottom:
1. The story goal (unchanged, from `Goal.luau` and `StoryService`).
2. and 3. The two nearest **milestones** from a generated list, nearest first.

Milestones (`src/shared/Config/Milestones.luau`, pure, Lune-checked):
- Jobs done: 1, 3, 5, 10, 25, 50, 100, 250, 500. Reward: cash equal to 10 times the milestone, capped at $2500, and a toast.
- Money earned (lifetime, a new `earned` stat): $500, $2000, $10000, $50000, $250000. Reward: a toast and a HUD stamp.
- Level: the next level (reward from 1c).
- Stars: 3-star jobs: 1, 5, 25, 100 (from 1d). Reward: cash 25 times the milestone.
- Finds (slice 3): 1, 10, 30; sets completed.

A milestone completes on the server, pays, fires a `MilestoneReached` event to the client, and the rail plays a chime, a stamp and a cash pop before the next milestone slides in. The rail never shows more than three lines. In compact height (every phone held sideways) the rail collapses to the story goal as today, and the nearest milestone shows as a one-line **Next chip** in the right column under curb appeal ("Next: 3 jobs, $30"); the chime, stamp and cash pop anchor to the chip there. `check-gui` covers the chip's slot.

Pacing, decided: the new cash (milestones, level rewards, tips) raises first-hour income by about a third, so the reel mower arrives after two jobs instead of three and act 2 comes sooner. That is the front-page pace on purpose: the first ten minutes should show two upgrades. Prices and job pay are not retuned in slice 1; the plan's tuning task measures the first hour and adjusts the milestone multipliers only.

### 1c. Level rewards

Today: level gates jobs, tool tiers and story acts; a level-up is a toast and a moment card. The curve `level = floor(sqrt(xp / 50)) + 1` stays.

New: every level has a named reward in `src/shared/Config/Levels.luau`, shown on the moment card and in a **Levels panel** (the XP bar is a button; key L on PC): the next five rewards, with the current level at the top.

| Level | Reward |
|---|---|
| 2 | $100 |
| 3 | Serious jobs (today) and a truck paint tint of your choice (the four 49-Robux tints are also earned at 3, 6, 9 and 12; they stay on sale as a shortcut, and the shop shows "Earned" instead of the price once owned; the wraps stay premium only) |
| 4 | $250 |
| 5 | $500 (slice 3 adds Buster here) |
| 6 | second tint and $400 |
| 7 | $600 |
| 8 | Pro jobs (today) and $800 (slice 4 adds Oak Hills) |
| 9 | third tint and $800 |
| 10 | Best Yard contest (today) and $1500 |
| 11 | $800 |
| 12 | fourth tint and $1000 (slice 4 adds Lakefront) |
| 13 | $1000 |
| 14 | $2500 |
| 15 | $1500 |
| 16 | $3000 (slice 4 adds The Club) |
| 17 | $2000 |
| 18 | $5000 |
| 19 | $3000 |
| 20 | a gold business sign and $5000 |
| 21 and up | $3000, and $5000 with a HUD stamp at every multiple of 5 |

The table is the single source; the moment card, the panel and `check-season` all read it. Cash rewards are paid by the server on `LeveledUp`. Rewards are claimed by level in the save (`levelRewards = { [level] = true }`): on join, any level at or below the player's with an unclaimed reward pays out, which is how a player already past level 5 gets Buster when slice 3 lands, and how an existing level 7 save gets its slice 1 cash once. Nothing in the table says "coming soon"; a slice adds its rows when it ships. The customer preference stays hidden (the story is the only hint, as today).

### 1d. Stars and tips

Today: finish quality 0 to 1 shows in the pay panel; no rating, no tip.

New: every completed job gets **stars** from the pay formula's own performance factor, the weighted blend of the quality and speed multipliers against the customer's preference that already scales pay (`qualityWeight * qualityMult + timeWeight * speedMult`, where 1.0 means "as expected"): 3 stars at 1.1 and above with no penalty (no flower or gnome hit, no junk left or chewed), 2 at 0.9 and above, 1 below. Finish quality alone is set by the tool, so it cannot be the measure; this one rewards picking the right tool for the customer, taking care, and pace. The customer **tips**: 15 percent of pay at 3 stars, 5 percent at 2, nothing at 1, named ("Mrs. Alvarez tipped $12") on the pay panel under the pay lines, with the stars stamping in one by one and a chime per star. The best stars per job template are saved (`stars = { [templateId] = best }`) and the Jobs app shows them on each offer, so "3-star every job" is a thing to chase. Tips count as earned money for milestones and leaderboards.

### 1e. Cash pop and sound

Today: five sounds, no floating numbers.

New: a small `src/client/FloatingText.luau` draws "+$12" and "+40 XP" rising from the pay panel and from pickups; `UI.moment` gains a Stars variant. `src/shared/Sounds.luau` gains six ids: Cash, LevelUp, GoalDone, Star, Find, Streak. They come from Roblox-owned public audio (the builder searches the audio catalog for Roblox-created cash register, chime, stamp and pickup sounds and records the ids and names in the file; `check-story` asserts the six are non-empty). Levels of the existing LawnDone chime stay.

### Slice 1 data and checks

- Data version 13: `earned` (number, backfilled from `money` as a floor), `stars` (table), `milestones` (table of reached ids), `levelRewards` (table of claimed levels; an existing save claims every level at or below its current one on first load after the migration, without paying, so old players are not showered with back pay), `firstJob` (boolean, true once the first-timer flow has run; existing saves get true).
- `check-season`: Milestones and Levels tables well-formed (ascending, unique, rewards non-negative, every slice-1 level present), `Milestones.next(stats)` pure and deterministic, star thresholds, tip percentages.
- Studio: the first-timer flow on PC and phone (time from tap to first snip under ten seconds), the rail on a phone, a level-up with the panel, a 3-star job's tip, every sound audible.

## Slice 2: Tomorrow

### 2a. Daily contracts and the mailbox

A **mailbox** stands at every plot's driveway (`Props/Mailbox`; a block with a billboard until the model lands). Interacting opens **Today's contracts**: three contracts that reset at UTC midnight, generated from the player's level:
- one count contract ("Mow 3 lawns"), one money contract ("Earn $400"), one flavour contract ("Pick up 4 pieces of junk", or from slice 3 "Find something", or "Get a 3-star job").
- Rewards: cash (about one job's pay each), and finishing all three gives a **Bonus Day** pack: $500 and, once slice 3 lands, a guaranteed Find on the next job.

The HUD shows a small chip under the goals rail with "Contracts 1/3" that opens the same panel. Contracts are generated server-side from `src/shared/Config/Contracts.luau` (pure templates by level band), saved as `daily = { day = yyyymmdd, contracts = {...}, done = {...} }`, and regenerated on the first join of a new UTC day.

### 2b. Login streak

On the first join of a UTC day the server advances `streak = { days, last }` (reset to 1 if a day was missed) and the client shows a **streak card** for four seconds: day N of 7, today's reward, tomorrow's reward. Rewards (`Config/Streak.luau`): $100, $150, $200, $300, $400, $600, day 7: a **flag** for the truck (a cosmetic pennant on the bed, the first of a set) and $1000, then the week repeats with cash. The streak is visible in the Levels panel.

### 2c. Leaderboards

Two OrderedDataStores, `LawnsMowed_v1` and `MoneyEarned_v1`, written for a player at most once a minute on job completion. A **leaderboard sign** stands at the town spawn (`Props/LeaderboardSign`; two SurfaceGui boards on a block until the model lands) and shows the top 25 of each with the viewing player's own line under them: their rank if they are in the top 100 (the server pages the first 100), else "not in the top 100 yet" with their own number. The server refreshes the boards every two minutes and sends them to clients; if DataStores are unavailable (Studio without API access) the sign says so and the game plays on. The HUD leaderstats Money and Level stay.

### 2d. Judging day on the calendar

Today: the Best Yard contest is act 4 of the story and loops per "summer" counted in jobs.

New: once act 4 is open and its first in-story judging day has been played (unchanged, so the story still lands the first time), **judging day is every Saturday (UTC)**. The contest keeps its scoring, Gloria's rising bar and the trophy. The goals rail shows "Judging day in 3 days" as the story goal while act 4 is open, June's porch text mentions it, and on Saturday the judges can be called once (the existing StartJudging). A player who misses a Saturday keeps their curb appeal for the next. A new summer (Gloria's bar rises) starts after a win, or after four Saturdays without one, whichever comes first; the jobs-counted wait goes away once the calendar takes over. This is not a timer that stops play: the whole week is for mowing and curb appeal, and Saturday is the payoff.

### Slice 2 data and checks

- Data version 14: `daily`, `streak`, `flags` (cosmetics owned), `contest.nextSaturday`.
- `check-season`: contract templates by level band (every band has one of each kind), streak table, a pure `Daily.dayKey(unixTime)` and `Daily.nextSaturday(unixTime)` with fixed-date assertions.
- Studio: contracts generate and complete, a streak card, the sign with DataStores off and on (API access enabled), a Saturday simulated by a StudioTest shortcut.

## Slice 3: Finds

### 3a. Thirty Finds

Today: five pieces of junk, penalty-only, forgotten.

New: junk becomes **Finds**: things in the grass worth picking up. `Config/Debris.luau` keeps the five junk kinds (they still dull blades and cost the penalty if left) and gains 30 Finds in four rarities, each with a name, a one-line story, a value and a set:

- Common (12): bottle cap, lost tennis ball, broken sprinkler head, old key, dog tag, marble, golf ball, toy soldier, seashell, birthday candle, screwdriver, bent spoon.
- Uncommon (10): class ring, pocket knife, old phone, arrowhead, lucky horseshoe, 1980s cassette, a wedding band (returned to the customer for a big tip), jar of coins, vintage lighter, compass.
- Rare (6): silver dollar, fossil shell, meteorite chip, antique watch, a message in a bottle, a 1994 Best Yard medal.
- Legendary (2): the golden gnome, Grandma June's lost locket (returning it plays a scene and ends with her porch getting her rocking chair cushion, a small story cap).

Odds per lawn: one Find roll per job, chance by tier (Homeowner 35 percent, Serious 50, Pro 65), rarity weights 70/22/7/1, nudged up by 3-star streaks and by Buster. The Find is placed like junk, visible as its model (block with a billboard until models land), picked up with E, and goes into the save (`finds = { [id] = count }`) with a Find sound and a card ("Rare find: silver dollar"). A Find a motor mower runs over is chewed up and lost ("You chewed up a class ring. Buster would have found it."), with no penalty beyond junk's; a Find left on the lawn when the job ends is lost. The wedding band and the locket offer a choice on pickup (Keep or Return): returning the band pays a large tip from the customer, returning the locket plays June's scene. Sets count a Find as found whether it was kept, sold or returned, so the Maple Grove set can still complete. Selling is optional (the Finds Book has a Sell button, value by rarity); keeping completes nothing extra beyond the shelf display.

### 3b. The Finds Book and the shelf

The computer gets a **Finds** app: a grid of 30 silhouettes that fill in, with rarity colour, count and story, and the five **sets** (Playground, Pocket, Garden, Treasure, Maple Grove) with their perks: Playground +1 junk cell of reach, Pocket +3 percent pay, Garden flower penalty halved, Treasure +5 percent pay, Maple Grove (the two legendaries and the medal) the gold business sign early. Perks are small and permanent, applied in the pay formula where bonuses already stack.

The building gets a **shelf** fixture (`Props/FindsShelf`, a Mount like the tool fixtures) that shows the player's rarest twelve Finds as models, for walking past and for showing a crew.

### 3c. Buster

At level 5 the player gets **Buster**, a dog: a free Creator Store dog model, animated with Roblox's own quadruped animations if the rig allows, else a two-pose bob. He rides in the truck bed on drives, runs the lawn while you work, and once per job trots to the Find (if there is one) and barks, with a marker, so a player who wants the Find can go get it. At the business he sits on the porch or follows. He has no needs and never blocks a mower. He is a server-side NPC like the cast (CastService builds people; a `CompanionService` builds Buster), replicated and simple.

### Slice 3 data and checks

- Data version 15: `finds`, `sets` (completed), `buster` (named, owned).
- `check-season`: 30 Finds with unique ids, rarity weights sum, every set's members exist, perk values bounded; `Finds.roll(seed, tier, bonuses)` pure.
- Studio: a Find on a lawn, pickup, the book, a set completing, the shelf, Buster riding and barking.

## Slice 4: Districts

Today: 36 job templates, 12 customer names, 10 streets, all "Maple Grove".

New: four **districts** with their own look, customers, pay and Finds, opened by level and shown as a **map** in the Jobs app with locked districts greyed and their unlock level on them:

| District | Opens | Look | Pay | Templates |
|---|---|---|---|---|
| Maple Grove | start | today's houses and lots | today | today's 36 |
| Oak Hills | 8 | big two-storey houses, long drives, hedges | +30 percent | 10 new: large Serious lawns, hedge lines, leaf piles |
| Lakefront | 12 | cottages, docks, sand edges, reeds | +60 percent | 8 new: tricky edges, sandy soil renovation, boat ramps to blow |
| The Club | 16 | the golf and country club: fairway strips, a clubhouse lawn | +100 percent | 6 new: Pro turf, stripes graded, the clubhouse championship lawn |

A district changes the job site that is built (a backdrop set per district: house style, fence, props; placeholder blocks until the batch lands), the customer name pool, the drive cutscene's sign, the Find pool (district exclusives: a golf ball tee set at The Club, a fishing lure at Lakefront), and the job board. The board stays one table per server, filled from the best online player's level as today; two slots are pinned to the highest district that player has open, and a player below the district's level sees those offers greyed with the unlock level on them (the ladder, visible). Pay multipliers apply in the formula where the truck bonus does.

### Slice 4 data and checks

- Data version 16: `districts` (opened), per-district stars.
- `check-season`: district table, every template's district exists, unlock levels ascending, pay multipliers, the map's slot layout for phones (`check-gui`).
- Studio: a job in each district, the map on a phone, the cutscene sign.

## How it gets made (calls I made)

- Luau, Rojo, Lune checks, the existing SDD workflow: one design (this), one plan per slice, one PR per slice.
- Milestones, Levels, Contracts, Streak, Finds and Districts are pure config modules under `src/shared/Config/`, each with a Lune check, so the tables are testable without Studio.
- New world objects use the model pipeline and `Assets.prop` placeholders; nothing waits on art.
- Sounds come from Roblox-owned public audio found through the audio catalog, recorded by id and name in `Sounds.luau`.
- Leaderboards use OrderedDataStore and degrade to a notice when unavailable.
- Buster and districts are the largest unknowns; both are last in their slices and each has a cheaper fallback named above (a two-pose dog; placeholder backdrops).

## What is left to the builder

- Exact copy for toasts, cards and contract text (plain, short, in the game's voice; June speaks like June).
- Layout of the Levels panel, the Finds app grid and the district map inside the existing UI builders and the phone rules.
- The six sound ids and the Find and district placeholder looks.
- Where exactly a first-timer stands and faces at the job site (the lawn's Origin corner facing the house, like a reset at a job).
- The job-site backdrop sets per district (a list of props per set in a config, placeholders first).

## Playtest checklist (per slice, before its PR)

- Slice 1: tap to first snip under ten seconds on PC and phone; a level-up moment with the panel; a 3-star tip; the rail on a phone in landscape; every sound.
- Slice 2: a fresh day's contracts; a streak card on day 2; the sign with and without DataStores; a simulated Saturday.
- Slice 3: a Find on a lawn and in the book; a set completing; Buster on a drive and on a lawn.
- Slice 4: one job in each district; the map on a phone.
