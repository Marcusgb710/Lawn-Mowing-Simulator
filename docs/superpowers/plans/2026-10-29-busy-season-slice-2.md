# Busy Season slice 2: Tomorrow, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A second-day player has reasons to open the game that did not exist on day one: three daily contracts in a mailbox at the driveway, a login streak, two leaderboards on a sign at spawn, and judging day every Saturday.

**Architecture:** A pure `Daily` module (UTC day keys and Saturdays) and a server `Clock` (real time plus a Studio-only offset) give every feature one notion of "today". Pure config modules (`Contracts`, `Streak`) hold the tables and rules and are gated by `check-season`; `Contest.luau` gains a calendar state. Two new server services (`DailyService`, `LeaderboardService`) and two client controllers (`ContractsController`, `LeaderboardController`) do the work; the curb mailbox and the leaderboard sign are placeholder props placed by `WorldService`. Save version 14.

**Tech Stack:** Luau (Roblox), Rojo 7.7.1, Lune checks, selene, StyLua, OrderedDataStore.

**Spec:** docs/superpowers/specs/2026-10-29-busy-season-design.md (slice 2, sections 2a to 2d and "Slice 2 data and checks"; the Constraints section binds every task). Slice 1 is on this branch already (branch base `bentenavery/front-page`); its plan is docs/superpowers/plans/2026-10-29-busy-season-slice-1.md.

## Global Constraints

- Phone-first: every new HUD element has a `UiLayout.luau` entry and a `check-gui` assertion; compact height 500, phone reference 844 by 390.
- Saves: new fields go through `Season.upgradeSave` (typeof guards, idempotent), `MIGRATIONS[14]`, and `snapshot()` when the client reads them; DATA_VERSION becomes 14 once in this slice; string keys only.
- Nothing yields at module load; every Roblox call that can fail in a live game (DataStores above all) sits in `pcall` with a fallback that keeps the game playable.
- Repo voice: plain sentences, no em dashes; `selene src` and `stylua --check src` clean (StyLua output redirected to a file, never piped).
- Nothing sold as cash; no timer stops play (the calendar only says when the payoff is).
- Studio-only code is guarded by `RunService:IsStudio()` at the method and at the remote; the `Clock` offset can never apply live.
- Every commit ends with a blank line then `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; nothing under `.superpowers/` or the scratchpad is committed.

## Review Focus

1. A player online across UTC midnight gets new contracts and one streak advance, never two, and a rejoin the same day changes nothing (Task 3's `Streak.advance` assertions; Task 4's refresh is idempotent on `daily.day`).
2. The `Clock` offset is Studio-only: `setOffset` refuses outside Studio and the remote that sets it is the Studio test one (Task 1 code guard; Task 9 wiring).
3. DataStores unavailable (Studio without API access, or an outage): the leaderboards say so and the game plays on with no error and no retry storm (Task 7: one pcall per call, a 120 s refresh, `available = false`).
4. A missed day resets the streak to 1, not 0; day 8 pays day 1's cash and no second pennant (Task 3 assertions).
5. Calendar judging: a player who judged this Saturday cannot judge again until next Saturday, Sunday shows "Judging day in 6 days", and the first in-story judging day still follows the jobs rule (Task 8 assertions with fixed dates).

Fixed dates for assertions (UTC): 2026-10-29 00:00 is `1793232000` (a Thursday); 2026-10-31 00:00 is `1793404800` (a Saturday); 2026-11-07 00:00 is `1794009600`.

---

### Task 1: Daily and the Clock

**Files:**
- Create: `src/shared/Daily.luau`
- Create: `src/server/Clock.luau`
- Modify: `scripts/check-season.luau`

**Interfaces:**
- Produces `Daily.dayKey(unix: number): string` ("YYYYMMDD" in UTC, from `os.date("!*t", unix)`); `Daily.isSaturday(unix): boolean`; `Daily.nextSaturday(unix): number` (the unix time of 00:00 UTC on the next Saturday, or of today if today is Saturday); `Daily.daysUntil(unix, target: number): number` (whole UTC days from `unix`'s day to `target`'s day); `Daily.midnightAfter(unix): number`. Pure, no requires.
- Produces `Clock.now(): number` (`os.time()` plus the offset); `Clock.setOffset(seconds: number)` (only when `RunService:IsStudio()`, else a `warn` and no change); `Clock.offset(): number`. Server only.

- [ ] **Step 1: Assertions first** in `check-season.luau` (plain `require("../src/shared/Daily")`):

```lua
check(Daily.dayKey(1793232000) == "20261029" and Daily.dayKey(1793232000 + 86399) == "20261029", "a day key covers the whole UTC day")
check(Daily.dayKey(1793232000 + 86400) == "20261030", "the next second is the next day")
check(Daily.isSaturday(1793404800) and not Daily.isSaturday(1793232000), "Saturdays")
check(Daily.nextSaturday(1793232000) == 1793404800, "Thursday's next Saturday is in two days")
check(Daily.nextSaturday(1793404800 + 3600) == 1793404800, "a Saturday morning is still judging day")
check(Daily.nextSaturday(1793404800 + 86400) == 1794009600, "Sunday waits a week")
check(Daily.daysUntil(1793232000 + 3600, 1793404800) == 2 and Daily.daysUntil(1793404800, 1793404800) == 0, "days until")
check(Daily.midnightAfter(1793232000 + 100) == 1793232000 + 86400, "midnight after")
```

- [ ] **Step 2: Run** `lune run scripts/check-season`: FAIL (module missing).
- [ ] **Step 3: Write both modules** with headers saying what they are for; `Clock`'s header says the offset exists for Studio's "next day" and "Saturday" shortcuts and can never apply live.
- [ ] **Step 4: Run** `check-season` (pass), `selene src`, `stylua --check src > <scratch>/stylua-t1.txt 2>&1`, `rojo build`.
- [ ] **Step 5: Commit** `Give the server one clock and one notion of today`

---

### Task 2: Save version 14

**Files:**
- Modify: `src/shared/Config/Season.luau`, `src/server/Services/DataService.luau`, `scripts/check-season.luau`

**Interfaces:**
- Produces in `Season.upgradeSave`: `daily = { day = "", contracts = {}, done = {}, count = { jobs = 0, earned = 0, junk = 0, stars = 0 }, bonus = false }`, `streak = { days = 0, last = "" }`, `flags = {}`, and on `contest`: `lastJudged = ""`, `saturdays = 0` (Saturdays judged without a win since the last win). Existing values with the right `typeof` are kept; a `daily` missing `count` gets it.
- Produces `DATA_VERSION = 14`, `MIGRATIONS[14]` calling `Season.upgradeSave`, and in `snapshot()`: `daily`, `streak`, `flags`.

- [ ] **Step 1: Assertions first**: a fresh save has `daily.day == ""`, `streak.days == 0`, `flags` empty, `contest.lastJudged == ""`, `contest.saturdays == 0`; a save with `daily = { day = "20261029", contracts = { {} }, done = {}, bonus = true }` keeps those and gains `count`; `upgradeSave` twice equals once. Run: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the full gate list (`check-season`, `check-story`, `check-gui`, `check-mowing`, `check-models`, `selene`, `stylua`, `rojo build`).
- [ ] **Step 4: Commit** `Save the day: contracts, streak, flags and the judging calendar`

---

### Task 3: Contracts and Streak rules

**Files:**
- Create: `src/shared/Config/Contracts.luau`, `src/shared/Config/Streak.luau`
- Modify: `scripts/check-season.luau`

**Interfaces:**
- Produces `Contracts.Bands = { { min = 1, max = 2 }, { min = 3, max = 7 }, { min = 8, max = 11 }, { min = 12, max = 999 } }` and `Contracts.bandFor(level): number` (1 to 4).
- Produces per band, index 1 to 4: Mow need `{ 2, 3, 4, 5 }`, Earn need `{ 150, 400, 1200, 3000 }`, Junk need `{ 3, 4, 6, 8 }`, Stars need `{ 1, 1, 2, 2 }` (three-star jobs), reward per contract `{ 60, 150, 400, 900 }`, `Contracts.BonusCash = 500`.
- Produces `Contracts.seed(dayKey: string, userId: number): number` (a stable integer from both) and `Contracts.generate(seed: number, level: number): { Contract }` where `Contract = { id: string, kind: "Mow" | "Earn" | "Junk" | "Stars", need: number, reward: number, text: string }`: always one Mow, one Earn, and one flavour (Junk or Stars, picked by the seed with a small LCG like `GrassImages.randoms`), ids `"Mow"`, `"Earn"`, `"Junk"` or `"Stars"`, texts "Mow 3 lawns", "Earn $400", "Pick up 4 pieces of junk", "Get a three-star job". Deterministic: the same seed and level give the same list.
- Produces `Contracts.have(contract, count): number` (`math.min(need, count[kind's counter])` where Mow reads `count.jobs`, Earn `count.earned`, Junk `count.junk`, Stars `count.stars`).
- Produces `Streak.Rewards` (7 entries: cash 100, 150, 200, 300, 400, 600, and day 7 cash 1000 with `flag = "TruckPennant"`), `Streak.rewardFor(days: number): { cash: number, flag: string? }` (days 1 to 7 as listed; 8 and up repeat the cash of `((days - 1) % 7) + 1` with no flag), `Streak.advance(streak, today: string, yesterday: string): (boolean)` (mutates: `last == today` returns false; `last == yesterday` adds a day; else `days = 1`; sets `last = today`; returns true when advanced), `Streak.text(days): string` ("Day 3 of 7").

- [ ] **Step 1: Assertions first** (`check-season`): band edges (2 is band 1, 3 is 2, 11 is 3, 12 is 4); `generate(seed, 5)` has three contracts with ids Mow, Earn and one of Junk or Stars, needs 3 and 400, reward 150 each; the same seed twice gives equal lists; two different seeds over 50 tries give both Junk and Stars at least once; `have({ kind = "Earn", need = 400 }, { earned = 950 }) == 400`; `rewardFor(7).flag == "TruckPennant"`, `rewardFor(14).cash == 1000 and rewardFor(14).flag == nil`, `rewardFor(8).cash == 100`; `advance` on `{ days = 3, last = "20261028" }` with today `"20261029"` and yesterday `"20261028"` gives days 4 and true; again the same day gives false and days 4; `{ days = 3, last = "20261020" }` resets to 1. Run: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gates.**
- [ ] **Step 4: Commit** `Add the day's contracts and the streak rewards`

---

### Task 4: DailyService

**Files:**
- Create: `src/server/Services/DailyService.luau`
- Modify: `src/server/init.server.luau` (LOAD_ORDER after SeasonService), `src/shared/Net.luau` (events `ContractsUpdated`, `ContractDone`, `BonusDay`, `StreakAdvanced`; function `GetContracts`), `src/server/Services/JobService.luau` (`JobFinished` payload gains `junkPicked` from the lawn's debris counts)

**Interfaces:**
- Consumes `Daily`, `Clock`, `Contracts`, `Streak`, `DataService` (`Get`, `WaitForData`, `Changed`, `Earn`, `Earned`), `JobService.JobFinished`.
- Produces `DailyService:Refresh(player)`: with `today = Daily.dayKey(Clock.now())` and `yesterday = Daily.dayKey(Clock.now() - 86400)`: if `daily.day ~= today`, set `day`, `contracts = Contracts.generate(Contracts.seed(today, player.UserId), level)`, `done = {}`, `count` zeroed, `bonus = false`; then `Streak.advance(streak, today, yesterday)` and if it advanced: `Changed`, pay `Streak.rewardFor(days).cash` with `Earn` (above 0), set `flags[flag] = true` when there is one, fire `StreakAdvanced { days, cash, flag, tomorrow = Streak.rewardFor(days + 1).cash }`; then send `ContractsUpdated` with the view. Called on join after `WaitForData` and every 60 s for each online player (one loop).
- Produces counting: on `JobFinished` `count.jobs += 1`, `count.stars += 1` when `info.stars == 3`, `count.junk += info.junkPicked or 0`; on `Earned` `count.earned += amount`; after either, every contract with `have == need` and not `done[id]`: mark done, `Changed`, `Earn(reward)`, fire `ContractDone { id, text, reward }`; when all three are done and not `bonus`: `bonus = true`, `Changed`, `Earn(Contracts.BonusCash)`, fire `BonusDay { cash }`. Marks are saved before pay, as SeasonService does, with the same per-player re-entrancy guard shape (an `Earn` inside counting fires `Earned` again; counting must not recurse).
- Produces the view (also `GetContracts`): `{ day, contracts = { { id, kind, text, need, have, reward, done } }, bonus, streak = { days, last, next = cash } }`.
- Handlers wrapped in `pcall` with `warn`; nothing yields at module load.

- [ ] **Step 1: Write the service** (no Lune test for a service; a scratch Lune harness over stubbed DataService and signals for Refresh idempotency, counting, completion order and re-entrancy, reported but not committed).
- [ ] **Step 2: Gates.**
- [ ] **Step 3: Commit** `Hand out the day's contracts and advance the streak`

---

### Task 5: Contracts panel, HUD chip, streak card, Levels panel line

**Files:**
- Create: `src/client/Controllers/ContractsController.luau`
- Modify: `src/client/Controllers/HudController.luau`, `src/client/Controllers/LevelsController.luau`, `src/client/UiLayout.luau`, `src/client/init.client.luau` (register), `scripts/check-gui.luau`

**Interfaces:**
- Consumes the view from `GetContracts` and `ContractsUpdated`, the `ContractDone`, `BonusDay`, `StreakAdvanced` events, `FloatingText.show`, `Sounds.playUi` (`GoalDone`, `Streak`, `Cash`), `UI.open`/`UI.close`/`UI.moment`, `Streak.text`.
- Produces `UI.open("Contracts")`: a centred `UI.sliced("Panel")` 360 by 400 scaled like the Levels panel (`UiLayout.ContractsPanel` with `margin` 24 and `scale`), titled "Today's contracts", three rows (text left, `have/need` and a 6 px bar, reward right, a text-only DONE stamp when done), a "Bonus Day: $500 for all three" line that reads "Bonus Day collected" when `bonus`, a streak line (`Streak.text(days)` plus "next: $N"), Close and Escape; opens from the HUD chip and from the curb mailbox (Task 6's `OpensPanel = "Contracts"`).
- Produces the HUD chip: `UiLayout.ContractsChip = { parent = "LeftColumn", detach = "LeftColumn", order = 4, size = { 0, 220, 0, 28 } }` placed under Grandma's goal with `placeInColumn`, text "Contracts 1/3" (done count), a button that opens the panel; on `ContractDone`: `GoalDone` sound, `FloatingText.show(chip, "+$150")`, re-render; on `BonusDay`: `UI.moment("Payday", "Bonus Day!", "+$500", 3)` and the Cash sound; on `StreakAdvanced`: `UI.moment("Payday", Streak.text(days), "+$200 today, $300 tomorrow", 4)` (day 7: "and a pennant for the truck") and the Streak sound, plus a cash pop from the money counter.
- Produces in the Levels panel: a streak line under the header ("Streak: Day 3 of 7, next $300"), the panel 360 by 460 (`UiLayout.LevelsPanel` size and the `check-gui` assertion updated from 420 to 460), nothing else moved.

- [ ] **Step 1: Assertions first** (`check-gui`): `ContractsPanel` scaling rule with `margin == 24`; `ContractsChip` in `LeftColumn` with a unique order; `LevelsPanel` size 360 by 460. Run: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gates.**
- [ ] **Step 4: Commit** `Show today's contracts and the streak on screen`

---

### Task 6: The curb mailbox and the truck pennant

**Files:**
- Modify: `src/server/Placeholders.luau` (`PROP_BUILDERS.CurbMailbox`, `PROP_BUILDERS.TruckPennant`), `src/server/Services/WorldService.luau` (buildPlot: the mailbox by the driveway's street end), `src/shared/Assets.luau` (`Assets.addPennant(truck: Model)`), `src/server/Services/JobService.luau` (`buildSite`: pennant on the site truck when the leader has the flag), `assets/README.md` (two wanted props under the manifest section), `TODO.md` (the two models wanted)

**Interfaces:**
- Consumes `Assets.prop`, `interactable`, `flags.TruckPennant` from the leader's save.
- Produces `Props/CurbMailbox` placeholder (a post with a box, like the Mailbox decoration's builder, 1 by 4 by 1 footprint, PrimaryPart at ground) placed in `buildPlot` at the driveway's street end, on the far side from the lawn, facing the street, with `interactable(model, "OpenPanel", "Check the mail", "Mailbox", { OpensPanel = "Contracts" })`; not a decoration (no `DecorId`), not in the decor area.
- Produces `Props/TruckPennant` placeholder (a 0.2 wide pole with a small purple triangle) and `Assets.addPennant(truck)` which parks it on the bed's rear corner (find the bed by the model's `BedArea` attachment or the bed part, like `ServiceSpots.forTruck` finds the tailgate) once per truck (idempotent, child named `Pennant`); `WorldService` adds it to the plot truck when the leader's `flags.TruckPennant` is true (on build and when the flag is set: `DataService.Changed`-driven or a `DailyService` call `WorldService:RefreshPennant(player)`), and `JobService.buildSite` adds it to the site truck the same way.

- [ ] **Step 1: Implement** the two builders, the placement, the pennant.
- [ ] **Step 2: Gates** (`check-models` must still pass; placeholders are not model files).
- [ ] **Step 3: Commit** `Put a mailbox at the curb and a pennant on the truck`

---

### Task 7: Leaderboards and the sign

**Files:**
- Create: `src/server/Services/LeaderboardService.luau`, `src/client/Controllers/LeaderboardController.luau`
- Modify: `src/server/init.server.luau`, `src/shared/Net.luau` (event `LeaderboardUpdated`), `src/server/Placeholders.luau` (`PROP_BUILDERS.LeaderboardSign`: two 8 by 5 boards, `LawnsBoard` and `MoneyBoard`, on posts, a header part), `src/server/Services/WorldService.luau` (the sign 12 studs behind the SpawnLocation, facing it, in both the placeholder town and a `Town` model), `src/client/init.client.luau`, `src/shared/Config/GameConfig.luau` (`LeaderboardStores = { Lawns = "LawnsMowed_v1", Money = "MoneyEarned_v1" }`, `LeaderboardWriteInterval = 60`, `LeaderboardRefreshInterval = 120`, `LeaderboardTop = 25`, `LeaderboardRankPages = 4`)

**Interfaces:**
- Produces `LeaderboardService`: at Init, `GetOrderedDataStore` for both names inside `pcall`; `available` false when either fails. `Record(player)` on `JobFinished`, at most once per `LeaderboardWriteInterval` per player: `SetAsync("u" .. UserId, jobsCompleted)` and `SetAsync("u" .. UserId, math.floor(earned))` in pcall. `Refresh()` every `LeaderboardRefreshInterval` seconds (and once 10 s after Init): `GetSortedAsync(false, LeaderboardTop)` for each board's top list, then up to `LeaderboardRankPages` pages for ranks of online players; names through `Players:GetNameFromUserIdAsync` in pcall with a cache and "Player" as the fallback; sends `LeaderboardUpdated` to every player: `{ available, lawns = { { name, value } }, money = { ... }, you = { lawnsRank = n or nil, moneyRank, lawns = jobsCompleted, money = floor(earned) } }`. Studio without API access: `available = false` after the first failure, no retries until the next refresh tick, no errors.
- Produces the sign: `Props/LeaderboardSign` placeholder placed by `WorldService` behind the spawn; `LeaderboardController` waits for `workspace:WaitForChild("Town"):WaitForChild("LeaderboardSign", 30)`, builds one `SurfaceGui` per board part on the client ("MOST LAWNS MOWED" / "MOST EARNED", 25 rows "12. Name  40", then a line "You: #12 with 40" or "You: not in the top 100 yet, 3 lawns"), and "Leaderboards are off in this place" when `available` is false; re-renders on each event.

- [ ] **Step 1: Implement** the service, the builder, the placement, the controller.
- [ ] **Step 2: Gates.** (No Lune test for DataStores; a scratch harness over a stubbed store for the write throttle and the rank lookup, reported.)
- [ ] **Step 3: Commit** `Put the town's best lawns on a sign at spawn`

---

### Task 8: Judging day on the calendar

**Files:**
- Modify: `src/shared/Config/Contest.luau`, `src/server/Services/ContestService.luau`, `src/client/Goal.luau`, `src/client/Controllers/HudController.luau` (the goal's "Days" kind), `src/shared/Config/Story.luau` (June's porch line with `{days}`), `scripts/check-story.luau`

**Interfaces:**
- Consumes `Daily` (loaded into `check-story` the way `Contest` is, both pure), `Clock.now()` on the server.
- Produces `Contest.calendarState(contest, act: number, jobsCompleted: number, now: number): string`: `"Locked"` and `"Results"` as `Contest.state`; when `contest.judged == 0`, the jobs rule as today (`"Waiting"` below `nextAt`, else `"Open"`); otherwise `"Open"` when `Daily.isSaturday(now)` and `contest.lastJudged ~= Daily.dayKey(now)`, else `"Waiting"`. `Contest.daysUntilJudging(contest, now): number` (0 on an open Saturday; else `Daily.daysUntil(now, Daily.nextSaturday(now))`, and 7 when today is a judged Saturday). `Contest.state` stays for the first-day rule and is what `calendarState` calls.
- Produces in `ContestService`: `stateFor` uses `calendarState` with `Clock.now()`; `StartJudging` sets `contest.lastJudged = Daily.dayKey(Clock.now())`; `Collect` on a loss adds one to `contest.saturdays` when `judged > 1`, and when `saturdays >= 4` sets `summer += 1` and `saturdays = 0` (Gloria's bar rises after four Saturdays without a win); a win sets `saturdays = 0` as well as `summer += 1`; `contest.nextAt` stays only for the first day. The view gains `daysLeft` (`daysUntilJudging`) and `calendar = judged > 0`.
- Produces `Goal.current()`: when `contest.state == "Waiting"` and `contest.calendar`, `{ text = "Judging day in {daysLeft} days" (or "Judging day is today" at 0, "tomorrow" at 1), kind = "Days", need = 7, have = 7 - daysLeft }`; `Goal.progress` for `"Days"` returns `have` and the day text; the jobs form stays for the first day. June's porch line for a waiting calendar contest ("Saturday's the day. {days} to go.") through `Story.juneLine` values.
- Produces `check-story` assertions: with `contest = { judged = 1, lastJudged = "", pending = false }`, act 4: Thursday `1793232000 + 3600` is Waiting with 2 days; Saturday `1793404800 + 3600` is Open; after `lastJudged = "20261031"` the same Saturday is Waiting with 7 days; Sunday `1793404800 + 86400` is Waiting with 6; `judged = 0` keeps the jobs rule (Open with `nextAt = 0`, Waiting with `nextAt = 5` and 2 jobs); Locked below act 4; Results when pending.

- [ ] **Step 1: Assertions first** (`check-story`): FAIL.
- [ ] **Step 2: Implement** the config, the service, the goal, the porch line.
- [ ] **Step 3: Gates.**
- [ ] **Step 4: Commit** `Hold judging day every Saturday once the first one is done`

---

### Task 9: Studio shortcuts and the docs

**Files:**
- Modify: `src/server/Services/StudioTestService.luau` (`NextDay`: `Clock.setOffset(Clock.offset() + 86400)` then `DailyService:Refresh` for every player and `ContestService:OpenForTesting`-style pushes; `Saturday`: offset so that `Clock.now()` is next Saturday 12:00 UTC; `Leaderboard`: `LeaderboardService:Refresh()` now), `src/client/Controllers/StudioTestController.luau` (three wide buttons), `TODO.md` (slice 2 checklist from the spec plus "with API access on" for the sign), `docs/GAME_DESIGN.md` (a "Tomorrow" section: contracts, streak, leaderboards, Saturday judging, each a short paragraph with the numbers), `docs/STORY.md` (judging day on the calendar), `README.md` (layout rows for the new modules; the `Daily` check line)

- [ ] **Step 1: Implement** the shortcuts and buttons.
- [ ] **Step 2: Docs.**
- [ ] **Step 3: Gates.**
- [ ] **Step 4: Commit** `Add Studio shortcuts for the next day and Saturday, and write up Tomorrow`
- [ ] **Step 5 (controller, Studio):** a fresh day's contracts and one completing; the streak card on "Next day"; the sign with API access off (the notice) and on; "Saturday" opening judging after a first judging day.

---

## Self-review notes

- Spec coverage: 2a Tasks 3, 4, 5, 6; 2b Tasks 3, 4, 5, 6 (pennant); 2c Task 7; 2d Task 8; data and checks Tasks 1, 2 and the checks in each task; Studio Task 9.
- Types: `Contract`, the view, `Streak.advance`'s mutate-and-return, `Clock.now` and `Daily` names are defined once (Tasks 1, 3, 4) and reused by name.
- Review Focus: each line names its task and assertion; item 2 is a code guard plus review, since Lune cannot stub `RunService`.
- Proportion: tables' values and assertions, no bodies.
