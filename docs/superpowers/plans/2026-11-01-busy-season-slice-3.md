# Busy Season, Slice 3: Finds and Buster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Junk in the grass becomes Finds worth picking up (30 of them, four rarities, five sets with small permanent perks), collected in a Finds Book on the shop computer and shown on a shelf, and at level 5 the player gets Buster, a dog who rides along and sniffs out the job's Find.

**Architecture:** A pure `Config/Finds.luau` holds the 30 Finds, the sets, the roll and the save cleaner (Lune-tested). The server places one Find per job lawn in its own list (never in the junk list), handles pickup, chewing and Keep or Return, and pays set perks through `payBonuses`. The client gets a Find card, a Finds Book app and a shelf. A `CompanionService` builds Buster per owner.

**Tech Stack:** Luau, Rojo 7.7.1, Lune checks (`check-compile`, `check-season`, `check-story`, `check-gui`, `check-mowing`, `check-models`), selene, StyLua.

**Spec:** `docs/superpowers/specs/2026-10-29-busy-season-design.md`, section "Slice 3: Finds" (3a, 3b, 3c and "Slice 3 data and checks"). Code facts: `.superpowers/slice3-survey.md` (at 8a15e0d) and `.superpowers/slice3-delta.md` (what moved by 35ca6bf). Read both before each task; they are local files.

## Global Constraints

- Phone-first: UiLayout columns, compactHeight 500, the shared top-centre slot on touch, no element wider than the existing panels. Grass stays at 4 shells on phones. Every acting control is at least 40 px after scaling, with Roblox's 58 px top bar counted (check-gui's `GUI_INSET`).
- Saves: every new field goes into `DataService.defaultData`, with a `MIGRATIONS` entry and a `typeof` guard, and into `snapshot()` if the client needs it. The data version is bumped once per slice: this slice takes 15.
- Nothing yields at module load; every Roblox API call that can fail in a live game is in a pcall with a fallback that keeps the game playable.
- Lune checks gate everything pure: `check-season` for the Finds tables and the save, `check-story` for story text, `check-gui` for layout, `check-compile` for every script (HudController must stay well under 200 registers).
- Repo voice: plain sentences, no em dashes, headers that say what a thing is for.
- Models: new props (the Finds, the finds shelf, Buster) come through the manifest pipeline later; until then they have block placeholders with a billboard label, the way `Assets.prop` already falls back.
- No new GUI images (the 312 pin holds): Finds use existing icons and code-drawn rarity frames.
- Commits: one per task, files staged by name, never `.superpowers/` (it is not git-ignored here), trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, commit messages written to a file under `.superpowers/` and passed with `git commit -F`.

## Rulings (decisions the spec leaves open)

1. **Save shape** (v15): `finds = { [findId] = { found = n, held = n } }` (found counts ever found, so sold or returned Finds still count toward the book and sets), `sets = { [setId] = true }`, `buster = { owned = false, name = "Buster" }`, `findLuck = { run = 0, owed = false }` (run = consecutive three-star jobs, owed = a sure Find on the next job after a Bonus Day). Filled and cleaned by a pure `Finds.cleanSave(data)` (no requires, the Settings pattern), called from `defaultData`, from `MIGRATIONS[15]` and from `reconcile` on every load. Not through `Season.upgradeSave` (Season loads under Lune without Finds).
2. **The 30 Finds**, in this order with these ids: Common: BottleCap, TennisBall, SprinklerHead, OldKey, DogTag, Marble, GolfBall, ToySoldier, Seashell, BirthdayCandle, Screwdriver, BentSpoon. Uncommon: ClassRing, PocketKnife, OldPhone, Arrowhead, Horseshoe, Cassette, WeddingBand, CoinJar, Lighter, Compass. Rare: SilverDollar, FossilShell, MeteoriteChip, AntiqueWatch, BottleMessage, BestYardMedal. Legendary: GoldenGnome, JuneLocket. Each has a display name, a one-line story in the game's voice, a rarity and a colour `{r,g,b}` for its placeholder.
3. **Rarity:** weights 70/22/7/1; sell values $10/$40/$200/$1,000; frame colours Common grey #B9C2BB, Uncommon green #69E25A, Rare blue #3D9BE8, Legendary gold #FFD24A (code-drawn UIStroke and text colour, no new palette faces).
4. **Roll:** one roll per job lawn. Chance by tier: Homeowner 0.35, Serious 0.50, Pro 0.65. Plus 0.05 per three-star job in a row (capped at 3), plus 0.10 with Buster; Buster also rerolls a Common once and keeps the better. `findLuck.owed` makes it 1.0 once. `Finds.roll(seed, tier, bonuses) -> findId?` is pure (the LCG pattern from Contracts.luau) and Lune-tested. No Find on a template with `junk = 0` (the first-timer's FirstMow) and none on the home lawn.
5. **Sets** and perks: Playground {TennisBall, Marble, GolfBall, ToySoldier, BirthdayCandle, Cassette}: pick-up reach +2 studs (server `PICK_UP_REACH` and the client look-at `REACH`). Pocket {BottleCap, OldKey, DogTag, BentSpoon, Screwdriver, PocketKnife, OldPhone, Lighter}: pay +3 percent. Garden {SprinklerHead, Seashell, Arrowhead, Horseshoe, Compass, FossilShell}: the flower-bed damage penalty halved (FlowerPatch only, not gnomes). Treasure {ClassRing, WeddingBand, CoinJar, SilverDollar, MeteoriteChip, AntiqueWatch, BottleMessage}: pay +5 percent. Maple Grove {BestYardMedal, GoldenGnome, JuneLocket}: the gold business sign early (`flags.GoldSign`, as level 20 grants). Pay perks add: both give 1.08. A set completes when every member has `found >= 1`, once, with a "Set complete!" card.
6. **On the lawn:** a Find is a separate entry on the Lawn (`lawn.find`), never in `lawn.debris`, so it does not count as junk, does not cost quality or the penalty if left, and is not a junk dot on the lawn map. Its model has `Interact = "PickUpFind"`, `InteractText = "Pick up"`, `InteractName = <its name>`, a small sparkle so a player can spot it, and sits on a non-optional Grass cell at least 4 cells from junk. A motor mower that sweeps its cell chews it up: "You chewed up a <name>. Buster would have found it." (the same blade wear and stall as junk, no pay penalty), and it is gone. A Find left on the lawn when the job ends is lost (a pay-panel note). A crew: whoever picks it up gets it.
7. **Keep or Return:** WeddingBand and JuneLocket offer E "Keep" and R "Return it" (InteractController's `Target.second`). Returning the band adds $250 to that job's tip from the customer (the pay panel's tip line). Returning the locket plays the scene `LocketReturn` and sets `flags.RockerCushion` (a cushion on June's porch rocker). Either way it counts as found; only Keep adds to `held`.
8. **Cards:** picking up a Find plays `Sounds.playUi("Find")` and a toast ("Rare find: Silver Dollar"); Rare and Legendary also get a `UI.moment` card. A set completing gets a moment ("Set complete!", "<set>: <perk>"). All queued through HudController's `afterTitleCard` and `inTurn`.
9. **Finds Book:** a sixth computer app, "Finds" (`UI.panel("Finds", "Finds Book")`, docked like Jobs): a scrolling grid of 30 cells (silhouette until found, then name, rarity frame, held count, story on tap), the five sets with progress and perk underneath, and a Sell button on a held Find (two-tap confirm like the shop's sell; `SellFind` remote, `DataService:AddMoney`, not Earn, rate limited, only held Finds).
10. **Shelf:** a `Props/FindsShelf` fixture (placeholder: a 6x6x1.5 wooden shelf with three rows of four spots) at the business, placed like the Workbench (a `Mount` named FindsShelf if the building has one, else the fallback spot beside the desk), showing the player's rarest 12 held Finds as their placeholder models. `WorldService:RefreshShelf(player)` refreshes it without a plot rebuild (the `RefreshPennant` pattern).
11. **Contracts and milestones:** a "Finds" contract flavour (find 1 thing) joins Junk and Stars as the third flavour (a third each). Milestones gain four Finds goals: first Find $50, ten Finds $250, all thirty $1,500, first set $300 (the milestones' counting order and check-season's positional checks updated).
12. **Buster:** level 5's reward gains Buster ("Buster the dog and $500"), granted by `payLevels` and re-derived for saves already past level 5 (the GoldSign pattern). A `CompanionService` builds a placeholder dog per owner (a block body, head, ears and tail, anchored, CanCollide, CanQuery and CanTouch false) with a name billboard. At the business he sits by the porch. On a job he moves between random grass cells by short server tweens (never through the mower's path: he keeps 6 studs from any player holding a motor mower), and once per job, if there is a Find, he trots to it, sits, plays a bark (a `Bark` sound id: a Roblox-owned one if found, else empty with a TODO), and the Find gets `BusterFound = true` (the lawn map then dots it in gold). He rides in the truck bed in the drive cutscene (`info.buster` like `info.pennant`, the model shared with `Assets.shareWith`).
13. **Studio shortcuts:** "Give a Find" (a random one, or cycling rarities), "Find on this lawn" (forces a Find on the current job lawn), and Buster through the existing Level 5 button. Status label moves down; the panel's `typical` grows.

## Review Focus

1. A Find on a crew job: two players reach it at once; exactly one gets it, the other is told it's gone. (Task 3.)
2. A save from before this slice (v14, no finds keys) and a scrambled one (finds as a string, a count as NaN, an unknown id): loads, cleans, keeps good entries. (Task 2, check-season.)
3. Selling the last held copy of a Find: the book still shows it found and its set still counts. (Tasks 2 and 5.)
4. The Find chewed by a crewmate's mower: nobody gets it, nobody is penalised beyond the junk rule. (Task 3.)
5. Buster with no Find on the lawn, a player standing still, and a respawn: he never blocks a mower or a doorway and never errors. (Task 8.)

---

### Task 1: The Finds tables

**Files:** Create `src/shared/Config/Finds.luau`; Modify `scripts/check-season.luau`.
**Produces:** `Finds.List` (30 entries `{ id, name, story, rarity, color }`, Ruling 2), `Finds.get(id)`, `Finds.Rarities` (`Common`, `Uncommon`, `Rare`, `Legendary` with `weight`, `value`, `frame`), `Finds.TierChance`, `Finds.Sets` (Ruling 5: `{ id, name, members, perk = { kind, amount }, text }`), `Finds.roll(seed: number, tier: string, bonuses: { run: number?, buster: boolean?, owed: boolean? }) -> string?`, `Finds.seed(dayKey, userId, jobIndex)`, `Finds.payBonus(sets) -> number` (1 + sum of pay perks), `Finds.reachBonus(sets) -> number`, `Finds.flowerFactor(sets) -> number`, `Finds.newlyComplete(finds, sets) -> { string }`, `Finds.rarest(finds, count) -> { string }` (held ones, rarest first, then list order), `Finds.cardText(id) -> (title, subtitle)`, `Finds.cleanSave(data)` (Ruling 1, idempotent, no requires).
- [ ] Step 1: check-season assertions first: 30 unique ids in the four rarity groups in order; weights sum 100; every set member exists and no Find is in two sets; perk amounts bounded (pay at most 0.05, reach at most 2); `roll` deterministic for a seed, never a Find on chance 0, always one when owed, the rarity spread over 10,000 seeds within 2 points of 70/22/7/1, Buster's reroll never makes it worse; `payBonus` 1.08 with Pocket and Treasure; `newlyComplete` once; `rarest` order; `cleanSave` on nil, a v14 save, a scrambled save (strings, NaN, unknown ids) and twice in a row (a fixed point). See it fail.
- [ ] Step 2: Write `Finds.luau`. Stories: one plain line each, in the game's voice (June's world, Maple Grove).
- [ ] Step 3: Gates; commit `Add the thirty Finds, their sets and the roll`.

### Task 2: Save version 15

**Files:** Modify `src/server/Services/DataService.luau` (`DATA_VERSION = 15`, `MIGRATIONS[15]`, `defaultData`, `reconcile`, `snapshot()` gains `finds`, `sets`, `buster`, `findLuck`), `scripts/check-season.luau` (the DATA_VERSION rule to 15, a stored v14 save upgraded, text pins for the four keys in defaultData, reconcile and snapshot).
- [ ] Step 1: check-season first; fail.
- [ ] Step 2: Implement; gates; commit `Save the Finds, the sets and Buster (data version 15)`.

### Task 3: Finds on the lawn

**Files:** Modify `src/server/Services/LawnService.luau` (`Lawn:PlaceFind(id, rng)`, `Lawn:PickUpFind(thing, from, reach) -> id?`, chewing in `Sweep`, `Lawn:FindState()`, cleanup in `Finish`), `src/server/Services/JobService.luau` (roll at build from the leader's data and `job.offer.tier`; `PickUpFind` remote with the debris remote's limiter; Keep and Return; lost-at-end note; `findPicked` in the `JobFinished` payload; the band's $250 on the job's tip; `findLuck.run` and `owed` updates), `src/server/Services/ToolService.luau` (chewing a Find stalls and wears like junk, no penalty), `src/client/Controllers/InteractController.luau` (`PickUpFind` targets with E Keep and R Return for the two), `src/shared/Net.luau` (`PickUpFind`, `FindPicked`, `SetCompleted`), `src/client/Controllers/HudController.luau` (Find and set cards per Ruling 8, keep its registers in check: a small `src/client/Hud/FindCards.luau` if needed), `src/shared/Placeholders.luau` (a block per Find with a billboard label and a sparkle), `src/shared/Config/Story.luau` (scene `LocketReturn`: June, Proud then Laughing, three or four lines, the locket was her mother's, lost the summer of the 1994 contest), `scripts/check-story.luau`, `src/server/Services/WorldService.luau` + `src/server/GrandmaJune.luau` (the rocker cushion when `flags.RockerCushion`).
- [ ] Step 1: Lune checks first where pure (story scene in check-story; any pure placement or chew rule); fail.
- [ ] Step 2: Implement per Rulings 4, 6, 7, 8 and Review Focus 1 and 4.
- [ ] Step 3: Gates; commit `Put a Find in the grass and let players pick it up`.

### Task 4: Perks, milestones and the Finds contract

**Files:** Modify `src/server/Services/JobService.luau` (`payBonuses` fifth factor `setBonus`, frozen at pull-out and in the first-timer path, sent and paid; `damagePenalty` flower factor; `PICK_UP_REACH` + reach bonus), `src/client/Controllers/InteractController.luau` (client `REACH` + the profile's reach bonus), `src/shared/PayBreakdown.luau` (a "Finds sets" line), `src/client/Hud/JobCard.luau` (a Set boost pill: label "Sets", icon `Level` or `Premium`, tint `Gold`), `src/server/Services/SeasonService.luau` and `src/shared/Config/Milestones.luau` (four Finds milestones), `src/shared/Config/Contracts.luau` and `src/server/Services/DailyService.luau` and `src/shared/Config/Season.luau` (the Finds contract and its counter), the GoldSign grant for Maple Grove, `scripts/check-gui.luau` (`setBonus` in the field list; `job()` gains `setBonus`), `scripts/check-season.luau` (milestones, contracts).
- [ ] Step 1: Checks first; fail.
- [ ] Step 2: Implement per Rulings 5 and 11.
- [ ] Step 3: Gates; commit `Pay the set perks and count Finds in goals and contracts`.

### Task 5: The Finds Book

**Files:** Create `src/client/Controllers/FindsController.luau`; Modify `src/client/Controllers/ComputerController.luau` (sixth app), `src/server/Services/ShopService.luau` (`SellFind`: works anywhere, like the shop since PR 69; rate limited; only held Finds), `src/shared/Net.luau`, `src/client/init.client.luau`, `src/client/UiLayout.luau` (MenuWindow note), `scripts/check-gui.luau`.
- [ ] Step 1: check-gui first (the app is registered; the panel scrolls; cell sizes fit 844x390 with the inset); fail.
- [ ] Step 2: Implement per Ruling 9 and Review Focus 3.
- [ ] Step 3: Gates; commit `Add the Finds Book to the shop computer`.

### Task 6: The shelf

**Files:** Modify `src/shared/Placeholders.luau` (`FindsShelf`), `src/shared/Assets.luau` (header list), `src/server/Services/WorldService.luau` (placement and `RefreshShelf`), the server paths that change `held` (pickup, sell) call `RefreshShelf`, `assets/README.md` (wanted: `Props/FindsShelf` and the 30 Finds), `scripts/check-models.luau` if it lists props.
- [ ] Step 1: Implement per Ruling 10; gates; commit `Show the rarest Finds on a shelf at the business`.

### Task 7: Buster

**Files:** Create `src/server/Services/CompanionService.luau`; Modify `src/server/init.server.luau` (load order after JobService and WorldService), `src/shared/Config/Levels.luau` (level 5 `buster = true` and its text), `src/server/Services/SeasonService.luau` (grant and re-derive), `src/shared/Placeholders.luau` (`Buster`), `src/server/Services/JobService.luau` (`info.buster` in `travel`, `Assets.shareWith`), `src/client/Controllers/CutsceneController.luau` (Buster in the truck bed), `src/client/Hud/LawnMap.luau` (a gold dot for a Find with `BusterFound`), `src/shared/Sounds.luau` (`Bark`), `scripts/check-season.luau` (level 5 text and reward).
- [ ] Step 1: Checks first (Levels row 5); fail.
- [ ] Step 2: Implement per Ruling 12 and Review Focus 5.
- [ ] Step 3: Gates; commit `Give the player Buster at level 5`.

### Task 8: Studio shortcuts and docs

**Files:** Modify `src/server/Services/StudioTestService.luau`, `src/client/Controllers/StudioTestController.luau`, `src/client/UiLayout.luau` (StudioTestPanel typical), `TODO.md` ("Busy Season, slice 3: to check": a Find on a lawn and its card, Keep and Return, chewing one, the Finds Book and Sell, a set completing and its perk on the pay panel, the shelf, Buster at level 5 on the porch, on a drive and on a lawn finding the Find, the lawn map's gold dot, a crew pickup race), `docs/GAME_DESIGN.md` (section 11 gains "Finds" and "Buster"), `docs/STORY.md` (the locket scene), `README.md` (rows for the new modules).
- [ ] Step 1: Implement per Ruling 13; gates; commit `Add Studio shortcuts for Finds and write up slice 3`.
- [ ] Step 2 (controller, Studio): a Find on a lawn and its pickup card, the Finds Book, Buster on the porch and on a lawn.
