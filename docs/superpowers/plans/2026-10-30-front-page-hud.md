# Front-Page HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the HUD look and feel like a front-page Roblox simulator (the "Lawn HUD Restyle" mock, https://claude.ai/artifact/EAG6bbWkz7dv5nq1Z2CRLU), and add the four HUD features the mock shows: Shop, Gifts, Top Lawns and Settings.

**Architecture:** A new client module `Juicy` draws the new look in code (gradient faces, a 4 px ink stroke, a 6 px lip, a diagonal shine, stroked Fredoka text, hover and press tweens), so no new art is uploaded and the 312-image count holds. HudController's pieces are rebuilt with it; four new buttons sit in a new right-edge strip; a custom hotbar replaces Roblox's Backpack. Shop buying is allowed away from the desk, the daily streak becomes a claimed gift, Top Lawns reads the leaderboard payload, and Settings persist in a new top-level save key.

**Tech Stack:** Luau, Rojo 7.7.1, Lune checks (`check-gui`, `check-season`, `check-story`, `check-mowing`, `check-models`), selene, StyLua.

**Spec:** the mock above (Version 4) is the look. This plan's rulings are the behaviour. Code facts with file:line are in `.superpowers/hud-survey.md` (local, read it before each task).

## Global Constraints

- Phone-first: every piece is checked at the phone size `__screen.phone = {844, 390}` and at a 1280x720 PC; touch targets at least 40 px after scaling; nothing overlaps the move stick (bottom-left) or the jump button (bottom-right).
- No new images: `GuiArt.Images` stays 312 (check-gui line 50). Use existing icons (Truck, Guide, Crew, Jobs, Orders, Crown, Wrench, Money, Level, Goal, Timer, Premium) or inline-drawn frames; existing kit slices (ProgressFill, ProgressFill_Money, KeyBadge) may be reused.
- Saves: a new field goes through `Season.upgradeSave` or `defaultData` plus `reconcile`, and into `snapshot()` if the client needs it. No `DATA_VERSION` bump in this plan (slice 3 owns version 15).
- Nothing yields at module load; every remote validates its arguments on the server and has a per-player rate limit like ShopService's COOLDOWN.
- Lune checks gate everything pure; `check-gui` is updated, never loosened without a replacement rule.
- Repo voice: plain sentences, no em dashes, headers that say what a thing is for.
- Commits: one per task, only the task's listed files, never anything under `.superpowers/` or the scratchpad (that folder is NOT git-ignored in this repo), trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Gates per commit: `lune run scripts/check-gui`, `check-season`, `check-story`, `check-mowing`, `check-models`; `selene src`; `stylua --check src` redirected to a file (never piped); `rojo build default.project.json -o <scratchpad>/hud.rbxl`.

## Rulings (the decisions the mock leaves open)

1. **Colours per piece** (top, bottom of the face gradient): money green #69E25A/#3DAE38; level blue #8FD8FF/#3D9BE8; streak orange #FFB347/#F0661D; countdown purple #B48CFF/#6B4FBF; Truck #74C0FF/#2D7FE0; Guide #FFC85C/#F08A1D; Crew #C9A6FF/#8A5BE8; Contracts #FF9A7A/#E8553A; Shop #5EE0C8/#1FA98F; Gifts #FF9AC9/#E8459A; Top Lawns #FFE066/#E8A61E; Settings #C9D3CC/#8A9A8E; cream banner #FFFFFF/#FFF1C2; dark glass rgba(27,42,30,0.88); ink #1B2A1E; badge yellow #FFE066. Labels are white Fredoka with a 2 px ink stroke (3 px at 26 px and up).
2. **Font:** the new pieces use the built-in `FredokaOne` family (`rbxasset://fonts/families/FredokaOne.json`) for labels and numbers on buttons, pills and banners. Money and the job timer keep `UI.display("Numbers")` (Lilita One) with a white face and ink outline, bigger. Panels and windows keep their current kit and fonts in this plan.
3. **Layout, PC (height 560 and up):** left column: money pill (250x70), then a pill row (level pill 136x36, streak pill 106x36), then the countdown pill (250x34, only when the contest is on the calendar), then four square buttons in a column (76 px face, label under). Grandma's goal becomes a cream banner at top-centre on every screen (330x56, the current milestone rows hang under it in the cream, shown only when the screen is 560 tall or more). Right: a new `RightButtons` strip at {1,-12,0,12} (Shop, Gifts, Top Lawns as 76 px squares, Settings as a 56 px square), and `RightColumn` moves inward by the strip's width plus 12 px. Boost pills sit under the job card.
4. **Layout, touch or short screen:** the four left squares become a 2x2 grid; `RightButtons` squares become 56 px (Settings 44); the column scale rules stay as they are. At 844x390 the 76 px base squares must render at least 44 px; if they would not, the grid wins over the column.
5. **Contracts:** the Contracts chip becomes the fourth left square (coral, Jobs glyph) with a tilted yellow count badge showing contracts left today (hidden at 0); `ContractsChip`'s check-gui rules are replaced by rules for the new square.
6. **Shop anywhere:** the Shop button opens `ShopController.openApp("Orders")`. ShopService Buy, Sell and Equip (and DecorService:Buy) drop the `WorldService:IsAtComputer` check; the busy-at-a-job rules for tools and plot items stay; deliveries still arrive as boxes at the door. `JobService:AcceptJob` and TurfKing keep the desk check (jobs stay a computer thing). The computer's own Orders app is unchanged.
7. **Gifts (the streak becomes a claim):** the day turn still advances the streak and grants the day 7 flag, but no longer pays: it marks the gift `streak.claimed ~= today`. The Gifts button shows a tilted CLAIM tag and pulses while a gift waits; pressing it calls `ClaimStreak`, which pays `Streak.rewardFor(days).cash` through `DataService:Earn` under the existing `paying` guard, sets `streak.claimed = today`, and fires `StreakAdvanced` (the Payday card). A gift not claimed by the next day turn is paid automatically at that turn (no one loses money). With nothing waiting the button opens the streak card (the week's seven rewards, today's and tomorrow's cash).
8. **Top Lawns:** a `UI.panel("TopLawns", "Top Lawns")` window with two tabs (Lawns mowed, Money earned), up to 25 rows (rank, name, value), the player's own line at the bottom, and the boards' notice when leaderboards are off. It reads the same payload as the sign: LeaderboardController stores it in `ClientState.leaderboard`.
9. **Settings:** a `UI.panel("Settings", "Settings")` window with three rows: Sound (Off, Low, High: volume 0, 0.5, 1 on a new `SoundGroup` "Effects" that `Sounds.play`, `playUi` and `loop` parent their sounds to), Camera motion (On, Off: the existing `CameraController.setMotion`), Grass detail (High, Low: 6 or 4 shells, applied at the next join, said in the row). Saved as top-level `settings = { sound = "High", motion = true, grass = "Auto" }` (`Auto` = today's rule: 4 on touch, 6 otherwise) through `defaultData`, `reconcile`, `snapshot`, and a validated `SaveSettings` remote. The Guide's camera switch and the V key write through the same path.
10. **Hotbar:** a custom hotbar replaces Roblox's Backpack whenever the Backpack would show (the same states as `UI.setHotbar`). Five slots minimum, more as tools exist (up to 9), 60 px on PC and 48 on a phone, in the same band ToolCondition and CarryHint already assume (bottom 8 px, above them). A slot shows the item picture (`Art.item(itemId)`, else the category icon), the key number, and the held tool's slot is the cream juicy face. Keys 1-9 and clicks or taps equip and unequip through `Humanoid:EquipTool` / `UnequipTools` on the client (own character tools replicate). Roblox's Backpack stays disabled.
11. **Splash:** when a cutting mower pass ends (the client sees `cuttingMower()` go from a tool to nil) after at least 30 studs of travel in one direction with no blade hit and no Blocked state during it, a centred "NICE STRIPE!" (or "CLEAN CUT!", "PERFECT LINE!" in turn) pops for 1.2 s. Cosmetic only, no XP. At most one every 8 s.
12. **Juice:** every Juicy button grows 6 percent on hover, squashes to 92 percent on press with a Back/Out rebound, and plays a `Click` UI sound (a Roblox-owned id found in the audio catalog, else left empty and silent with a TODO line). Money counts up over 0.4 s on a gain and the money pill pulses once. Badges bob gently.
13. **Countdown pill:** shown only when `ClientState.contest.calendar` is true and the state is Waiting; text "Judging day in Nd Nh" from `Daily.nextSaturday` on the client's clock; "Judging day is today!" when Open.
14. **Key badges** (T, G, C, and new: B for Shop, F for Top Lawns, comma for Settings; Gifts has no key) stay small dark squares on the button's top-left corner, keyboard only.

## Review Focus

1. A phone at 844x390 in landscape: every button reachable, nothing under the move stick or jump button, the 2x2 grid and the right strip not overlapping the job card or the goal banner. (Owner: Tasks 3, 4, 5; a Studio check in Task 9.)
2. A player with a gift waiting at the next day turn: paid automatically, exactly once, and the Contracts Earn contract counts it once. (Task 6, check-season assertions on the pure rule.)
3. Buying from the HUD while on a job: tools and plot items still refused with the existing message; a decoration or premium item behaves as before. (Task 5.)
4. A player who never touches Settings: today's behaviour exactly (sound full, motion as GameConfig says, grass Auto). A tampered `SaveSettings` call is refused. (Task 7.)
5. The hotbar with 0, 1 and 9 tools, a tool removed mid-job (a broken mower), and a respawn: no stale slots, no errors. (Task 8.)

---

### Task 1: The Juicy kit

**Files:** Create `src/client/Juicy.luau`; Modify `src/shared/Sounds.luau` (a `Click` id), `scripts/check-gui.luau` (load Juicy's pure palette and assert it).
**Produces:** `Juicy.Palette` (ruling 1, named colours as `{top, bottom}` Color3 pairs plus `Ink`, `Badge`, `Cream`, `Glass`); `Juicy.Font` (FredokaOne `Font`); `Juicy.text(text, props, strokeThickness?) -> TextLabel` (white, FredokaOne, a contextual UIStroke in ink); `Juicy.face(color: string, props) -> Frame` (UICorner 18, UIGradient top to bottom, UIStroke 4 ink border, a lip frame 6 px below in ink behind it, a shine overlay: a white child frame with a rotated UIGradient transparency band, clipped by its own UICorner); `Juicy.button(color, onClick, props) -> TextButton` (a face plus hover, press and Click sound, `props.Icon` an existing glyph, `props.Label` text under the face, `props.Size` the face size); `Juicy.pill(color, props) -> Frame` (height-rounded face, 3 px stroke, 4 px lip); `Juicy.badge(text, props) -> Frame` (yellow, 3 px stroke, rotated 8 degrees, gentle bob); `Juicy.pulse(gui)`, `Juicy.pop(gui)`; `Juicy.countTo(label, from, to, seconds, format)`.
- [ ] Step 1: In check-gui, require Juicy's palette part under Lune (keep Roblox calls out of module load; Color3 comes from the roblox library like UiLayout's) and assert every entry has a top lighter than its bottom and the ink is darker than every bottom; run, see it fail.
- [ ] Step 2: Write `Juicy.luau`; add `Sounds.Ids.Click`.
- [ ] Step 3: Gates; commit `Add Juicy, the front-page button and pill kit drawn in code`.

### Task 2: Money, level, streak and countdown pills

**Files:** Modify `src/client/Controllers/HudController.luau` (`buildStats`, `updateProfile`, new `buildPills`, `updateCountdown`), `src/client/UiLayout.luau` (`MoneyPanel` 250x70; new `StatPills` LeftColumn order 2, `Countdown` LeftColumn order 3, existing orders after them shift), `scripts/check-gui.luau` (`COLUMN_PIECES`, unique orders).
**Consumes:** Task 1. `ClientState.contracts.streak.days`, `ClientState.contest`, `Daily.nextSaturday`.
- [ ] Step 1: check-gui: `StatPills` and `Countdown` exist with the sizes of ruling 3, in `COLUMN_PIECES`; fail first.
- [ ] Step 2: Money pill: gold coin (a round Frame with a radial-style gradient, ink stroke, "$" in FredokaOne), money via `UI.display("Numbers")` at TextSize 38, white face, ink outline; `Juicy.countTo` and `Juicy.pulse` on a gain; the transparent Levels button now covers the level pill. Level pill: Level icon, "LVL N", an XP bar on the right. Streak pill: a flame drawn from two rotated rounded frames (or the Premium glyph if that reads better in Studio), "DAY N" (hidden when days is 0). Countdown pill per ruling 13.
- [ ] Step 3: Gates; commit `Turn the money and level plate into front-page pills`.

### Task 3: The left square buttons and the Contracts square

**Files:** Modify HudController (`MENUS`, `buildMenuButtons`, `addKeyBadge`, `buildContractsChip` becomes the fourth square, `updateContractsChip`), UiLayout (`MenuButtons` holds four squares: a vertical list on PC, a 2x2 grid on touch or compact; `TruckButton`, `GuideButton`, `CrewButton`, new `ContractsButton` 84x100 with the label; `ContractsChip` removed; `MouseHint` stays order 5), check-gui (ContractsChip rules become ContractsButton rules: in MenuButtons, never hidden, unique order).
- [ ] Step 1: check-gui first, fail.
- [ ] Step 2: Squares per rulings 1, 3, 4, 5, 14; the count badge shows contracts left (hidden at 0) and bobs; the Next chip behaviour on short screens is unchanged.
- [ ] Step 3: Gates; commit `Make the menu and contracts buttons big colour squares`.

### Task 4: The goal banner, the job card and boost pills

**Files:** Modify HudController (`buildGoal`, `updateGoal`, `updateMilestones`, `buildTracker`, `layoutTracker`, `UpdateTimer`, new `buildBoosts`, `updateBoosts`), UiLayout (`GrandmaGoal` top-centre on every screen, 330 wide autoSize Y, hideWhile TutorialBanner and CrewInvite kept; new `BoostPills` RightColumn order after `JobTracker`), check-gui (GrandmaGoal's new place; BoostPills in `COLUMN_PIECES`).
- [ ] Step 1: check-gui first, fail.
- [ ] Step 2: Banner: cream face, red flag circle with the Goal glyph, the goal text in FredokaOne 19 ink, the reward (`+$N · N XP` where the goal has one) on the right in green, a ProgressFill bar with a 2 px ink border; milestone rows under it at 560 and up. Job card: dark glass, 4 px ink, lip; gold stripe name; three stars on the right (filled from `Stars.of(GameConfig.performance(...))` with the job update's quality and elapsed when the client has them, else hidden); timer 30 px white with "par 2:30" beside it; a yellow ProgressFill_Money bar for mowed percent; Call off as a small coral pill. Boost pills: Crew +N% (party size), Curb +N% (`HomeLawn.payBonus(profile.curbAppeal)` when above 0), Truck or Business payout bonus when above 0; hidden when none.
- [ ] Step 3: Gates; commit `Restyle the goal banner and the job card, and show the boosts`.

### Task 5: The right strip, Shop anywhere and Top Lawns

**Files:** Create `src/client/Controllers/TopLawnsController.luau`; Modify HudController (`buildRightButtons`), UiLayout (`RightButtons` at {1,-12,0,12}; `RightColumn` position moves inward by the strip width plus 12, per screen kind), `src/client/init.client.luau` (controller list), `src/client/Controllers/LeaderboardController.luau` (`ClientState.set("leaderboard", payload)`), `src/client/ClientState.luau` (comment), `src/server/Services/ShopService.luau` and `src/server/Services/DecorService.luau` (ruling 6), check-gui.
- [ ] Step 1: check-gui first (RightButtons exists, RightColumn clears it), fail.
- [ ] Step 2: Strip per rulings 1, 3, 4, 14; Shop opens Orders (closing any open menu first, like the other buttons); Gifts wired in Task 6 (here it opens the contracts panel's streak card and has no tag); Top Lawns opens the panel of ruling 8; Settings wired in Task 7 (here it opens nothing).
- [ ] Step 3: ShopService and DecorService per ruling 6; read every caller of `IsAtComputer` and say in the report which stay.
- [ ] Step 4: Gates; commit `Add the Shop and Top Lawns buttons, and let the shop sell anywhere`.

### Task 6: Gifts: the streak as a claimed gift

**Files:** Modify `src/shared/Config/Streak.luau` (pure `Streak.waiting(streak, today) -> boolean` and `Streak.settleUnclaimed(streak, today) -> cash` rules), `src/shared/Config/Season.luau` (`streak.claimed` string, default: the save's `streak.last`, so nobody is paid twice for a day already paid), `src/server/Services/DailyService.luau` (Refresh stops paying; pays an unclaimed earlier day at the turn; `ClaimStreak` handler; `viewOf` gains `claimable` and `cash`), `src/shared/Net.luau` (`ClaimStreak` function), HudController (the Gifts button tag, pulse and press), `scripts/check-season.luau`.
- [ ] Step 1: check-season: the pure rules (waiting today, claimed today, a missed day paid at the next turn exactly once, a save upgraded from `{days, last}` has `claimed = last`), the shape assertions updated; fail first.
- [ ] Step 2: Implement per ruling 7, keeping the `paying`/`recheck` guards so the claim's Earn counts toward the day's contracts once; the claim is rate limited and validates nothing but the player.
- [ ] Step 3: Gates; commit `Make the daily streak a gift you claim`.

### Task 7: Settings

**Files:** Create `src/client/Controllers/SettingsController.luau`; Modify `src/shared/Sounds.luau` (an "Effects" SoundGroup and a `Sounds.setVolume(level)`), `src/server/Services/DataService.luau` (`defaultData`, `snapshot`), a server handler for `SaveSettings` (in DataService or a small `SettingsService` in the load order), `src/shared/Net.luau`, `src/client/Controllers/CameraController.luau` (start from the saved setting; writes go through SettingsController), `src/client/Controllers/GuideController.luau` (its switch writes through the same path), `src/client/Controllers/GrassController.luau` (shell count from the setting at first use), `src/client/init.client.luau`, HudController (the Settings button), `scripts/check-season.luau` (a pure `Settings.clean(table) -> table` rule in `src/shared/Config/Settings.luau`, created here).
- [ ] Step 1: check-season: `Settings.clean` keeps good values, replaces bad or missing ones with the defaults, drops unknown keys; fail first.
- [ ] Step 2: Implement per ruling 9.
- [ ] Step 3: Gates; commit `Add Settings for sound, camera motion and grass detail`.

### Task 8: The custom hotbar

**Files:** Create `src/client/Controllers/HotbarController.luau`; Modify `src/client/UI.luau` (`showHotbar` keeps the core Backpack off and tells the custom one), `src/client/UiLayout.luau` (new `Hotbar` entry in the ToolCondition band), `src/client/init.client.luau`, check-gui (the band rule covers Hotbar).
- [ ] Step 1: check-gui first, fail.
- [ ] Step 2: Implement per ruling 10. Slots rebuild on Backpack ChildAdded/ChildRemoved, the character's ChildAdded/ChildRemoved and CharacterAdded; only tools with an `ItemId` attribute.
- [ ] Step 3: Gates; commit `Replace Roblox's Backpack with a front-page hotbar`.

### Task 9: The splash, the juice pass, docs and the Studio check

**Files:** Modify `src/client/Controllers/GrassController.luau` (pass tracking, a `StripDone` Signal), HudController (the splash per ruling 11; Juicy press and hover on every HUD button), `TODO.md` ("Front-page HUD: to check" checklist), `docs/GAME_DESIGN.md` (a short "HUD" section: the rulings in plain words), `README.md` (rows for the new modules).
- [ ] Step 1: Implement; gates; commit `Cheer a clean stripe and finish the front-page HUD`.
- [ ] Step 2 (controller, Studio): PC 1280x720 and the phone emulator at 844x390: every piece, the 2x2 grid, the strip, a job with the hotbar and a splash, Shop buying away from the desk, a gift claim after Next day, Top Lawns, Settings saved across a rejoin with API access on.
