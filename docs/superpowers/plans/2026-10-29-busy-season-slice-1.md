# Busy Season slice 1: First Minute and the Ladder, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new player cuts grass within ten seconds of the title card, and from then on the game pays out visibly every few minutes: a goals rail, level rewards, stars and tips, cash that pops and sounds.

**Architecture:** Pure config modules under `src/shared/Config/` (Milestones, Levels, Stars, Season) hold every table and rule and are gated by a new Lune check, `scripts/check-season`. One new server service, `SeasonService`, pays milestones and level rewards and records stars; `JobService` grows a first-timer path and stars at completion; `DataService` gains save version 13. The client gets the goals rail inside the existing sticky note, a Levels panel, floating cash text and six sounds, all through the existing UI builders and `UiLayout`.

**Tech Stack:** Luau (Roblox), Rojo 7.7.1, Lune checks (`check-season`, `check-story`, `check-gui`, `check-mowing`, `check-models`), selene, StyLua.

**Spec:** docs/superpowers/specs/2026-10-29-busy-season-design.md (slice 1 sections 1a to 1e and "Slice 1 data and checks"; the Constraints section binds every task).

## Global Constraints

- Phone-first: every new HUD element has a `UiLayout.luau` entry, fits the existing columns, and `check-gui` passes; compact height is 500 and the phone reference is 844 by 390.
- Saves: new fields go into `defaultData`, `MIGRATIONS[13]` with `typeof` guards, and `snapshot()` when the client reads them; DATA_VERSION becomes 13 once in this slice.
- Nothing yields at module load; Roblox calls that can fail in a live game sit in `pcall` with a fallback that keeps the game playable.
- Repo voice: plain sentences, no em dashes, headers that say what a thing is for; `selene src` and `stylua --check src` clean (StyLua output redirected to a file, never piped).
- The customer preference stays hidden from the player (the story is the only hint).
- Nothing is sold as cash; the four tints stay on sale and are also earned.
- Every commit ends with a blank line then `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; nothing under `.superpowers/` or the scratchpad is committed.

## Review Focus

1. A first-timer who leaves during the first job and rejoins must land at their business with the normal flow, never a second first-timer job and never stranded on a destroyed lawn (Task 8, the `Season.isFirstTimer` assertions and the Studio check).
2. An existing save migrated to version 13 must not be showered with back pay: every level at or below its current one is claimed silently, `earned` starts at its money, and `firstJob` is true (Task 2, the `Season.upgradeSave` assertions).
3. A 3-star job must be impossible with any junk left or chewed or any flower or gnome hit, whatever the pay performance (Task 1, the `Stars.of` assertions).
4. A milestone must pay exactly once across rejoins and across crews (the reached set is saved before the pay is sent), and `Milestones.next` must never return a reached milestone (Task 1 idempotency assertions, Task 3 order of save then pay).
5. On a phone in a job, the Next chip must stay visible when curb appeal hides, and the story goal must still give way to the coach banner as today (Task 5, the `check-gui` layout assertions).

---

### Task 1: The season's tables and rules

**Files:**
- Create: `src/shared/Config/Milestones.luau`
- Create: `src/shared/Config/Levels.luau`
- Create: `src/shared/Config/Stars.luau`
- Create: `scripts/check-season.luau`
- Modify: `README.md` (the checks list, one line) and `HANDOFF.md` (the gates list, one line)

**Interfaces:**
- Produces `Milestones.List: { Milestone }` where `Milestone = { id: string, kind: "Jobs" | "Earned" | "Stars", at: number, cash: number, text: string }`; ids are `"Jobs:3"`, `"Earned:2000"`, `"Stars:5"`. Jobs at 1, 3, 5, 10, 25, 50, 100, 250, 500 with cash `math.min(10 * at, 2500)`; Earned at 500, 2000, 10000, 50000, 250000 with cash 0; Stars at 1, 5, 25, 100 with cash `25 * at`. `text` is what the rail shows ("Finish 3 jobs", "Earn $2,000", "Get 5 three-star jobs").
- Produces `Milestones.next(stats: { jobs: number, earned: number, stars: number }, reached: { [string]: boolean }, count: number): { Milestone }`: the `count` unreached milestones nearest to done, measured as `(at - have) / at`, ties by list order; pure.
- Produces `Milestones.reachedBy(stats, reached): { Milestone }`: every unreached milestone whose `at` the stats meet, in list order.
- Produces `Levels.rewardFor(level: number): Reward?` where `Reward = { cash: number, paint: string?, sign: boolean?, stamp: boolean?, text: string }`, from a table keyed by level for 2 to 20 with the spec's values (paints `RacingRed` 3, `ForestGreen` 6, `SkyBlue` 9, `MidnightBlack` 12; `sign = true` at 20), and for 21 and up `cash = 3000`, plus `cash = 5000, stamp = true` at every multiple of 5. Level 1 and below returns nil. `text` names the reward ("$250", "Forest Green tint and $400").
- Produces `Levels.nextRewards(level: number, count: number): { { level: number, reward: Reward } }`: the next `count` levels above `level` with their rewards.
- Produces `Stars.of(performance: number, penalized: boolean): number` (3 when `performance >= 1.1 and not penalized`, 2 when `performance >= 0.9`, else 1) and `Stars.tipRate(stars: number): number` (0.15, 0.05, 0).

- [ ] **Step 1: Write `scripts/check-season.luau`** in the style of `scripts/check-story.luau` (requires the three modules with `require("../src/shared/Config/...")`, a `check(ok, message)` counter, exits 1 on failures). Assertions:

```lua
check(#Milestones.List == 18, "18 milestones")
check(Milestones.List[2].id == "Jobs:3" and Milestones.List[2].cash == 30, "3 jobs pays $30")
check(Milestones.List[9].cash == 2500, "500 jobs is capped at $2500")
check(Milestones.List[10].kind == "Earned" and Milestones.List[10].cash == 0, "earned milestones pay nothing")
check(Milestones.List[18].id == "Stars:100" and Milestones.List[18].cash == 2500, "100 three-star jobs pays $2500")
local nearest = Milestones.next({ jobs = 2, earned = 400, stars = 0 }, { ["Jobs:1"] = true }, 2)
check(nearest[1].id == "Earned:500" and nearest[2].id == "Jobs:3", "nearest first: $500 at 4/5 (0.2 away), then 3 jobs at 2/3 (0.33 away)")
check(#Milestones.next({ jobs = 2, earned = 400, stars = 0 }, { ["Jobs:1"] = true, ["Jobs:3"] = true }, 1) == 1, "a reached milestone is never offered again")
local reached = Milestones.reachedBy({ jobs = 3, earned = 600, stars = 1 }, { ["Jobs:1"] = true })
check(#reached == 3 and reached[1].id == "Jobs:3" and reached[2].id == "Earned:500" and reached[3].id == "Stars:1", "everything met and unreached, in list order")
check(Levels.rewardFor(1) == nil and Levels.rewardFor(2).cash == 100, "level 2 pays $100")
check(Levels.rewardFor(3).paint == "RacingRed" and Levels.rewardFor(12).paint == "MidnightBlack", "tints at 3 and 12")
check(Levels.rewardFor(20).sign == true and Levels.rewardFor(20).cash == 5000, "the gold sign at 20")
check(Levels.rewardFor(21).cash == 3000 and Levels.rewardFor(25).cash == 5000 and Levels.rewardFor(25).stamp == true, "past 20")
for level = 2, 20 do check(Levels.rewardFor(level) ~= nil, `level {level} has a reward`) end
check(#Levels.nextRewards(3, 5) == 5 and Levels.nextRewards(3, 5)[1].level == 4, "the next five from level 3")
check(Stars.of(1.1, false) == 3 and Stars.of(1.1, true) == 2 and Stars.of(0.9, true) == 2 and Stars.of(0.89, false) == 1, "star thresholds")
check(Stars.tipRate(3) == 0.15 and Stars.tipRate(2) == 0.05 and Stars.tipRate(1) == 0, "tip rates")
```

- [ ] **Step 2: Run it to see it fail**

Run: `lune run scripts/check-season`
Expected: errors that the modules do not exist.

- [ ] **Step 3: Write the three modules** with the interfaces above and a header comment each saying what the file is for and that `check-season` gates it. `Milestones.next` sorts a copy; it never mutates `List`.

- [ ] **Step 4: Run the check**

Run: `lune run scripts/check-season`
Expected: `Season checks passed`, exit 0.

- [ ] **Step 5: Add the check** to the list of checks in `README.md` and the gates in `HANDOFF.md` (one line each, next to `check-story`).

- [ ] **Step 6: Commit** `Add the season's milestones, level rewards and star rules`

---

### Task 2: Save version 13

**Files:**
- Create: `src/shared/Config/Season.luau`
- Modify: `src/server/Services/DataService.luau` (DATA_VERSION, MIGRATIONS[13], defaultData, snapshot, a new `Earn`)
- Modify: `scripts/check-season.luau` (Season assertions)

**Interfaces:**
- Produces `Season.upgradeSave(data): nil`, pure, idempotent: fills `data.earned` (number; when missing, `math.max(0, math.floor(data.money or 0))`), `data.stars` (table), `data.milestones` (table), `data.levelRewards` (table keyed by string, so the save stays a dictionary; when missing, `levelRewards[Season.levelKey(level)] = true` for every level from 2 to `GameConfig.levelFromXp(data.xp or 0)`, where `Season.levelKey(level: number): string` returns `tostring(level)` and every reader and writer of the table uses it), `data.firstJob` (boolean; when missing, `true` if `(data.jobsCompleted or 0) > 0`, else `false`). Existing values with the right `typeof` are kept.
- Produces `Season.isFirstTimer(data, hasJob: boolean): boolean`: `data.firstJob == false and (data.jobsCompleted or 0) == 0 and not hasJob`.
- Produces `DataService:Earn(player, amount: number)`: adds `amount` to `money` and to `earned`, then `Changed`. `AddMoney` stays for sales and refunds and does not touch `earned`.
- Produces in `snapshot()`: `earned`, `stars`, `milestones`, `levelRewards`, `firstJob`.

- [ ] **Step 1: Assertions first** in `check-season.luau`:

```lua
local fresh = { money = 0, xp = 0, jobsCompleted = 0 }
Season.upgradeSave(fresh)
check(fresh.earned == 0 and next(fresh.levelRewards) == nil and fresh.firstJob == false, "a fresh save is a first-timer with nothing claimed")
local old = { money = 1234.5, xp = 1800, jobsCompleted = 30 }  -- level 7
Season.upgradeSave(old)
check(old.earned == 1234 and old.firstJob == true, "an old save keeps its money as earned and is not a first-timer")
for level = 2, 7 do check(old.levelRewards[tostring(level)] == true, `old save has claimed level {level}`) end
check(old.levelRewards["8"] == nil, "nothing above its level is claimed")
local kept = { money = 10, xp = 0, jobsCompleted = 0, earned = 99, stars = { QuickMow = 2 }, milestones = { ["Jobs:1"] = true }, levelRewards = { ["2"] = true }, firstJob = true }
Season.upgradeSave(kept)
check(kept.earned == 99 and kept.stars.QuickMow == 2 and kept.milestones["Jobs:1"] and kept.levelRewards["2"] and kept.firstJob == true, "upgrade keeps what is there")
check(Season.isFirstTimer({ firstJob = false, jobsCompleted = 0 }, false) == true, "fresh and idle is a first-timer")
check(Season.isFirstTimer({ firstJob = false, jobsCompleted = 0 }, true) == false, "with a job accepted it is not")
check(Season.isFirstTimer({ firstJob = true, jobsCompleted = 0 }, false) == false, "once started it is not")
```

`Season.luau` may require `GameConfig` (it is pure); `check-season` requires `Season` the same way.

- [ ] **Step 2: Run** `lune run scripts/check-season`: FAIL (Season missing).

- [ ] **Step 3: Implement `Season.luau`**, then in `DataService.luau`: `DATA_VERSION = 13`; `MIGRATIONS[13] = function(data) Season.upgradeSave(data) end` with a comment in the file's style (12 -> 13, the Busy Season's ladder); call `Season.upgradeSave(data)` in `defaultData` after the table is built (so defaults are one source); add the five fields to `snapshot()`; add `DataService:Earn`.

- [ ] **Step 4: Run** `lune run scripts/check-season` (pass), `lune run scripts/check-story`, `selene src`, `stylua --check src > <scratch>/stylua-t2.txt 2>&1`, `rojo build default.project.json -o <scratch>/t2.rbxl`.

- [ ] **Step 5: Commit** `Save what the ladder needs: earned, stars, milestones, claimed levels`

---

### Task 3: SeasonService pays milestones and level rewards

**Files:**
- Create: `src/server/Services/SeasonService.luau`
- Modify: `src/server/init.server.luau` (LOAD_ORDER, after DataService and before JobService)
- Modify: `src/shared/Net.luau` (events `MilestoneReached`, `LevelReward`)
- Modify: `src/server/Services/PremiumService.luau` (a `GrantPaint(player, paintId)` that marks `premium.owned[paintId] = true` without a receipt)
- Modify: `src/client/Controllers/ShopController.luau` (a Premium tab paint card the player owns shows "Earned" instead of its price when it is not in `premium.receipts`; the card for an owned paint is already a Use button, so this is the tag text only)

**Interfaces:**
- Consumes `Milestones.reachedBy`, `Levels.rewardFor`, `DataService:Earn`, `DataService.LeveledUp`, `JobService.JobFinished` (its payload gains `stars` in Task 4; until then stars count 0).
- Produces `SeasonService:CheckMilestones(player)`: builds `stats` from the save (`jobs = jobsCompleted`, `earned`, `stars = number of templates with best 3`), for each `Milestones.reachedBy` result sets `milestones[id] = true`, saves (`DataService:Changed`), pays `cash` with `Earn` when above 0, then fires `MilestoneReached` to the client with `{ id, text, cash }`. Called after every `JobFinished` and after every `Earn` (through a `DataService.Earned` signal fired by `Earn`, so tips and level cash count too), with a re-entrancy guard per player so a pay inside a check does not recurse.
- Produces `SeasonService:ClaimLevels(player)`: for every level from 2 to the current one not in `levelRewards` (keyed `levelRewards[Season.levelKey(level)]`), in order: mark claimed, save, pay `cash`, grant `paint` through `PremiumService:GrantPaint`, set the `GoldSign` attribute on the player for `sign` (Task 6 reads it for the stamp; the sign model is slice 2's), fire `LevelReward` with `{ level, text, cash }`. Called on `LeveledUp` and once on join after the data is loaded (`DataService:WaitForData`), which is how old saves and later slices claim.

- [ ] **Step 1: Write the service** following `ContestService.luau`'s shape (Init connects signals, Start does nothing yet).
- [ ] **Step 2: Wire the load order and the two events.**
- [ ] **Step 3: Run** `check-season`, `check-story`, `check-gui`, `selene`, `stylua`, `rojo build`.
- [ ] **Step 4: Commit** `Pay the ladder: milestones and level rewards`

---

### Task 4: Stars and tips at the end of a job

**Files:**
- Modify: `src/server/Services/JobService.luau` (`completeJob`)
- Modify: `src/shared/PayBreakdown.luau` (tip line)
- Modify: `src/client/Controllers/HudController.luau` (`showPay`: stars stamping in, the Star sound)
- Modify: `src/client/Controllers/JobBoardController.luau` (best stars on each offer card)
- Modify: `scripts/check-mowing.luau` or `check-season.luau` (PayBreakdown line assertions, whichever already loads PayBreakdown; if neither, `check-season`)

**Interfaces:**
- Consumes `Stars.of`, `Stars.tipRate`, `DataService:Earn`.
- Produces in `completeJob`: `performance = weights.quality * qualityMultiplier(quality) + weights.time * speedMultiplier(elapsed, parTime)`; `penalized = (debris.left + debris.hit) > 0 or job.damageCount > 0`; `stars = Stars.of(performance, penalized)`; `tip = math.floor(share * Stars.tipRate(stars))` per member, paid with `Earn` after the share; `job.result` gains `performance`, `stars`, `tip`; the leader's save gets `stars[templateId] = math.max(old, stars)` (every member's, since every member mowed); `JobFinished` payload gains `stars` and `tip`.
- Produces `PayBreakdown.lines`: when `result.tip` is above 0, a line `{ label = "Tip from {customer}", value = "+" .. money }` after the share line, and the returned total includes it. The customer name comes from `result.customer` (add it to `job.result`).
- Produces on the pay panel: three star slots under the total, filled one by one 0.35 s apart with `UI.sparkle` and the `Star` sound (Task 7 adds the id; before that the sound is silent), the tip line in the breakdown.
- Produces on the job board: a small "★★★" best-stars mark on an offer whose template the player has stars for (`profile.stars[offer.templateId]`), grey stars for the rest.

- [ ] **Step 1: Assertions first**: in the check that loads `PayBreakdown`, a result with `tip = 12` and `customer = "Mrs. Alvarez"` yields a line labelled `Tip from Mrs. Alvarez` and a total 12 higher than without it; with `tip = 0` no tip line. Run: FAIL.
- [ ] **Step 2: Implement** the server side, the breakdown line, the pay panel stars, the board mark.
- [ ] **Step 3: Run** the check (pass) and the full gate list.
- [ ] **Step 4: Commit** `Rate every job with stars and let the customer tip`

---

### Task 5: The goals rail and the Next chip

**Files:**
- Modify: `src/client/Goal.luau` (`Goal.milestones(count)`)
- Modify: `src/client/Controllers/HudController.luau` (`buildGoal`, `updateGoal`, the `MilestoneReached` handler)
- Modify: `src/client/UiLayout.luau` (`NextChip` entry)
- Modify: `scripts/check-gui.luau` (layout assertions)

**Interfaces:**
- Consumes `Milestones.next` and the profile snapshot (`jobsCompleted`, `earned`, `stars`, `milestones`).
- Produces `Goal.milestones(count: number): { Milestone }`: `Milestones.next` over the profile, or `{}` before the profile arrives.
- Produces the rail: under the story goal's bar, two rows (`LayoutOrder` 5 and 6), each a line of 15 px text `"{text}   {have}/{at}"` with a 6 px bar; hidden in compact height (`UI.layout("GrandmaGoal").compact` or the existing `isCompact` helper the HUD uses for curb appeal).
- Produces the Next chip: a 220 by 28 `UI.sliced("Tooltip")` in the right column under curb appeal, `UiLayout.NextChip = { parent = "RightColumn", detach = "RightColumn", order = 2, size = { 0, 220, 0, 28 }, compactOnly = true, hideWhile = {} }` showing `"Next: {text} {have}/{at}"`; visible only in compact height and never hidden during a job (unlike curb appeal).
- Produces on `MilestoneReached`: the rail (or the chip in compact) plays the `GoalDone` sound, `UI.sparkle` on the row, a `UI.stamp` "DONE" for 1.2 s, then re-renders; `FloatingText` (Task 7) shows "+$30" from the row when cash is above 0; before Task 7 a `UI.notify` carries the text.

- [ ] **Step 1: Assertions first** in `check-gui.luau`: `NextChip` exists with `parent == "RightColumn"`, `compactOnly == true`, and is not listed in any `hideWhile`; `GrandmaGoal.touch.hideWhile` still holds `TutorialBanner` and `CrewInvite`. Run: FAIL.
- [ ] **Step 2: Implement** the rail, the chip and the handler.
- [ ] **Step 3: Run** the full gate list.
- [ ] **Step 4: Commit** `Show the next two milestones under Grandma's goal`

---

### Task 6: The Levels panel and the reward moment

**Files:**
- Create: `src/client/Controllers/LevelsController.luau`
- Modify: `src/client/Controllers/HudController.luau` (the XP bar becomes a button that opens the panel; the `LevelReward` handler replaces the plain Level Up moment)
- Modify: `src/client/UiLayout.luau` (`LevelsPanel` entry) and `scripts/check-gui.luau`
- Modify: `src/client/init.client.luau` if controllers are registered there

**Interfaces:**
- Consumes `Levels.nextRewards`, the profile (`level`, `levelRewards`, read through `Season.levelKey`), the `LevelReward` event, `UI.moment`, the `GoldSign` attribute.
- Produces the panel: a centred `UI.sliced("Panel")` 360 by 420 (scaled by `UI.scaler` to fit a phone like the pay panel does), titled "Levels", with the current level and XP to the next, then the next five rewards as rows ("Level 4   $250"), a close button, key L on keyboard, Escape closes; `LevelsPanel` layout entry with `margin` like `PayBreakdown`.
- Produces the moment: on `LevelReward`, `UI.moment("LevelUp", "Level {level}!", reward.text)` with the `LevelUp` sound, and `FloatingText` for the cash (Task 7); the old `moments()` Level Up card is removed so a level is announced once.

- [ ] **Step 1: Assertions first** in `check-gui.luau`: `LevelsPanel` exists with a `margin` and a `scale`. Run: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the full gate list.
- [ ] **Step 4: Commit** `Open a Levels panel from the XP bar and name each level's reward`

---

### Task 7: Cash pop and sounds

**Files:**
- Create: `src/client/FloatingText.luau`
- Modify: `src/shared/Sounds.luau` (six ids), `scripts/check-season.luau` (non-empty assertions)
- Modify: `src/client/Controllers/HudController.luau` (pay panel "+$" pop and tip pop; the rail and chip pops from Task 5; the reward pop from Task 6)

**Interfaces:**
- Produces `FloatingText.show(from: GuiObject, text: string, color: Color3?)`: a `TextLabel` that rises 40 px over 0.9 s while fading, anchored at `from`'s centre, in the HUD screen, destroyed after; at most eight at once (oldest destroyed first).
- Produces `Sounds.Ids.Cash`, `LevelUp`, `GoalDone`, `Star`, `Find`, `Streak`: Roblox-owned public audio found through the toolbox audio search (`https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=<words>&limit=10`, then `/v1/items/details?assetIds=` for the creator; use only items whose creator is Roblox, id 1) and recorded as `"rbxassetid://<id>", -- <name> (Roblox)`. `Find` and `Streak` are for slices 2 and 3 and are set now so the check holds.
- Produces `Sounds.playUi(name)`: plays the sound from `SoundService` (no position) so UI sounds are heard everywhere; `Sounds.play` stays for world sounds.

- [ ] **Step 1: Assertions first** in `check-season.luau`: the six ids are non-empty strings starting with `rbxassetid://`. Run: FAIL.
- [ ] **Step 2: Find the six ids** and fill them; implement `FloatingText` and the pops.
- [ ] **Step 3: Run** the full gate list.
- [ ] **Step 4: Commit** `Make cash pop and the ladder ring`

---

### Task 8: First job first

**Files:**
- Modify: `src/shared/Config/Jobs.luau` (the `FirstMow` template with `hidden = true`; `poolFor` skips hidden templates)
- Modify: `src/server/Services/JobService.luau` (`buildSite(job)` factored out of `startDriving`; `JobService:StartFirstJob(player)`; `goHome` skips a first-timer; the arrival sets `ArrivedAtBusiness`)
- Modify: `src/server/Services/ToolService.luau` only if `GiveHeld` needs a way to hand the starter shears (`GardenShears`) to a player who already owns them in the truck (the tool is taken out of the loadout into the hand)
- Modify: `src/shared/Config/Story.luau` (the Intro beat moves to `on = "JobFinished"`, `when jobsCompleted == 1 and not seen.Intro`, placed before `FirstJob`; its shears card text says the shears are already yours; a `WelcomeBack` guard stays as is)
- Modify: `src/client/Controllers/TutorialController.luau` (first-timer Working text "Hold E to snip. Clear the lawn." on keyboard and "Hold Snip to cut. Clear the lawn." on touch; the banner stays until the second job is paid: `jobsCompleted <= 1 or (jobsCompleted == 2 and job and job.state == "Complete")`; its `not job` text stays the computer lesson)
- Modify: `scripts/check-story.luau` (beat assertions: Intro no longer fires on Joined for a fresh save; fires on JobFinished at one job; FirstJob texts still fire at one job after it; hidden templates never on the board, through a pure `Jobs.boardTemplates()` the service uses)
- Modify: `docs/GAME_DESIGN.md` ("Starting out" and "The first job": the first-timer flow, FirstMow's numbers)

**Interfaces:**
- Consumes `Season.isFirstTimer`, `DataService:Get`, `LawnService:Build`, `Assets.truck`, `ToolService:GiveHeld`, `StoryService` beats.
- Produces `Jobs.Templates` entry: `{ id = "FirstMow", name = "Front Strip", tier = "Homeowner", minLevel = 1, hidden = true, lawn = { columns = 5, rows = 6, flowerPatches = 0 }, tasks = { { type = "MowSmallLawn" } }, notes = { "Just the strip by the walk. Grandma said you'd do it." }, parTime = 150, basePay = 60, xp = 25 }` (about half the Front Lawn's cells; `LawnService` must accept a 5 by 6 lawn, else the smallest it accepts).
- Produces `Jobs.boardTemplates(): { Template }` (every template without `hidden`), used by `poolFor`.
- Produces `JobService:StartFirstJob(player)`: called from the join path when `Season.isFirstTimer(data, false)`: sets `data.firstJob = true` and saves; makes an offer from `FirstMow` with `Story.FirstCustomer`, payout `basePay` exactly, kind `"First"`; builds the job table as `AcceptJob` does and calls `buildSite(job)`; sets `job.members = { player }`, state `Working`, `startedAt`; pivots the character to `job.lawn.spawnCFrame` facing the house (`setArrivedFacing`); `ToolService:GiveHeld(player, "GardenShears")`; sends the update and fires `PlayerStateChanged`; sets the `ArrivedAtBusiness` attribute so the title card lifts. If anything in it fails (pcall), it logs a warning, clears the job and falls back to `goHome` so the player is never stranded.
- Produces: `completeJob` and `sendHome` work unchanged for the first job (the truck heads back as today, with the first-timer in it).

- [ ] **Step 1: Assertions first** in `check-story.luau`: `Jobs.get("FirstMow").hidden == true`; `Jobs.boardTemplates()` has no hidden entry and one fewer than `#Jobs.Templates`; the Intro beat has `on == "JobFinished"` and fires for `{ jobsCompleted = 1, seen = {} }` and not for `{ jobsCompleted = 1, seen = { Intro = true } }`; the `FirstJob` beat still fires at one job; no beat fires on `Joined` for a fresh save. Run: FAIL.
- [ ] **Step 2: Implement** the template, `boardTemplates`, `buildSite`, `StartFirstJob`, the join hook, the beat move, the banner texts, the design doc paragraphs.
- [ ] **Step 3: Run** the full gate list.
- [ ] **Step 4: Commit** `Start a new player on the lawn with the shears in hand`

---

### Task 9: Studio shortcuts and the first-hour tuning

**Files:**
- Modify: `src/server/Services/StudioTestService.luau` (a `FirstTimer` test: resets the player's save to `defaultData()` and runs `StartFirstJob`; a `Level` test that sets xp for a level, so rewards and the panel can be seen)
- Modify: `src/client/Controllers/StudioTestController.luau` (two buttons)
- Modify: `TODO.md` (the slice 1 playtest checklist from the spec, under a "Busy Season" heading)

**Interfaces:**
- Consumes `JobService:StartFirstJob`, `DataService` reset (a `DataService:ResetForStudio(player)` that replaces the profile's data with `defaultData()` and `Changed`; Studio only).

- [ ] **Step 1: Implement** the two tests and buttons.
- [ ] **Step 2: Run** the full gate list.
- [ ] **Step 3: Commit** `Add Studio shortcuts for the first-timer flow and levels`
- [ ] **Step 4 (controller, Studio):** the first-timer flow on PC (tap to first snip under ten seconds), the rail and chip on the phone preset, a level-up with the panel, a 3-star tip, every sound, then the first hour's income; adjust the milestone multipliers in `Milestones.luau` only if the reel mower arrives before the second job's end.

---

## Self-review notes

- Spec coverage: 1a Task 8; 1b Task 5 (with Task 3 paying); 1c Tasks 1, 3, 6; 1d Task 4; 1e Task 7; data and checks Task 2 and the checks in every task; the Studio list Task 9. The "Earned" shop tag is in Task 3.
- Types: `Milestone`, `Reward`, `stats` and `reached` are named once in Task 1 and reused by name; `Earn` is defined in Task 2 and used by Tasks 3 and 4; `FloatingText.show` is defined in Task 7 and used by Tasks 5 and 6 (which say what to do before it exists).
- Review Focus: each line names its task and assertion.
- Proportion: the plan carries tables' shapes and assertions, not bodies.
