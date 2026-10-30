# Story: Grandma's Rival

The story that wraps the game loop. It's a first pass to build the storyboard from. Names,
lines and beats can all change.

The mock-up of the intro, the Messages app and the contest results is at
https://claude.ai/artifact/FQbzu9rR7bMz64MQ8t2o7K. It's private until it's shared from its Share
menu.

**Next:** [The Owed List](STORY_OWED_LIST.md) builds on this story. You inherit June's old lawn
business, and free yards for neighbors in need become the biggest, most satisfying job of each
act. It isn't built yet.

## The pitch

Grandma June has won the Maple Grove Best Yard trophy 30 years running. This summer, her
next-door rival Gloria Pemberton hired a pro crew, TurfKing, to finally beat her. June's knees are
shot and her mower died in 2009. So she hands you, her grandkid, the rusty grass shears she won with
in '94: *make our yard the best on the street, and make some money doing it.*

You start at the very bottom with a pair of shears. You win over Grandma's bridge club one lawn at
a time, save up for real gear, outwork TurfKing for customers, and build a crew. By the end of
summer you've made Grandma's yard good enough to win her 31st trophy.

Tone: **funny and warm**. It's a family feud over lawns, not drama. Nobody gets kicked out and
nobody is broke; you're doing this for Grandma, and because Gloria is insufferable.

## The cast

- **You.** June's grandkid, staying with her for the summer. You're never named or gendered:
  "kid", "the grandchild", "dear".
- **Grandma June Hollis.** Her straw sun hat has a red band. She's competitive, blunt and proud,
  watches everything from her porch, and texts in capitals when she's excited. Her shed is your
  first shop, and her yard is your own lawn. Underneath it all she's proud of you, but she'll
  never say it plainly.
  - *"You missed a spot. I could see it from the porch."*
- **Gloria Pemberton.** June's neighbor and nemesis. She's rich, petty and always polite on the
  surface. She has lost Best Yard 30 times, and this year she isn't doing her own yard: TurfKing
  is.
  - *"Morning, June! Lovely… dandelions."*
- **TurfKing.** A slick lawn franchise with purple trucks, gold crowns and matching polos. It's
  your business rival: it takes jobs across town and undercuts you.
- **Chad.** TurfKing's local boss. He calls everyone "bud", is all confidence, and is secretly
  bad at mowing; his crew does the real work.
  - *"Cute scissors, bud."*
- **The Bridge Club.** Grandma's friends, who are your first customers and your word of mouth.
  - **Edna Alvarez** is the very first job.
  - **Mrs. Rossi** gossips.
  - **Ms. Nguyen** is picky, and pays well for perfect.
  - They're already in `Jobs.Customers`.
- **Sam Pemberton.** Gloria's grandkid. They work a summer job at TurfKing, hate it, and
  quietly root for you. They quit and join your side in Act 3.

**Backstory:** June and Gloria won the very first Best Yard in 1994 *together*, as a team. Only
June's name went on the trophy. They haven't really spoken since. Nobody brings it up until the
finale.

## The intro (June's welcome after the first payday, about 60 seconds, skippable)

A new player starts on their first lawn with her shears already in hand, so the intro isn't the
first thing they see: it plays when the truck brings them home from that first payday, in
letterbox, with dialogue at the bottom. It's the "Intro: Grandma's porch" board in the mock-up.

1. Sunrise over Maple Grove. A purple TurfKing truck pulls into the drive next door.
2. **Gloria** (a speech bubble over her house): *"Morning, June! Lovely… dandelions."*
3. **June**, from the porch: *"Thirty years. Thirty years I've won Best Yard on this street… and
   Gloria Pemberton goes and hires somebody."*
4. **June** talks about the shears you've been using, and an "Already yours: Grandma's Grass
   Shears" card pops up: *"My mower died in '09. These never did. They won me the trophy in '94,
   so don't you lose 'em."*
5. **June:** *"Contest's end of summer. Make our yard the best on the street, and make some money
   doing it."*
6. **June:** *"Edna's front lawn is next. Computer's in the shed. Go."*

Control is yours. The first lesson, "Click and hold to snip. Clear the lawn.", came on the first
lawn, so the first-job coach picks up from here with the second job: the shed computer, the "Front
Lawn" job, the truck, and picking up junk. It stays up until that second job is paid.

## The four acts

Each act lines up with progress the game already tracks, so the story moves as you play and never
blocks you.

| Act | Starts when | Ends when | What happens |
| --- | --- | --- | --- |
| **1. The Shears** | The first strip (the act you start in) | You buy the Reel Push Mower | Bridge club lawns. June critiques every job by text. Goal card: "Buy the Reel Push Mower". |
| **2. TurfKing** | Reel mower bought | First motorized mower bought, or level 5 | Chad shows up. TurfKing takes a job off your board now and then ("Taken by TurfKing"). Gloria gloats. |
| **3. The Crew** | First crew job, or level 8 | Curb appeal reaches the contest bar | Sam quits TurfKing and texts you. June pushes you to fix up *her* yard: decorations, edging, shrubs. |
| **4. The Contest** | Curb appeal over the bar, or level 12 | Judging day | Judging: your home yard against Gloria's. The 1994 secret comes out. You win (or try again). |

The level numbers are placeholders. Tune them to the real progression in GAME_DESIGN.md.

**Built (act gates in `Config/Story.luau`).** An act starts as soon as any of its gates is true,
and only once the act before it has started. The levels are tuned to the real progression
(`GameConfig.levelFromXp` and the xp in `Jobs.luau`). They only catch players who skip the
purchase that normally moves the story on:

| Act | Starts when (any of) | Goal card |
| --- | --- | --- |
| 1 | A new save | Buy the Reel Push Mower |
| 2 | You own the Reel Push Mower, any motorized mower, or level 3 (about 10 early jobs) | Buy the Gas Push Mower |
| 3 | You own a motorized mower, finish a crew job in act 2, or level 4 (about 18 jobs) | Raise curb appeal to 75 |
| 4 | Curb appeal 75 (`Story.ContestBar`: a tidy lawn is 60, so it takes a few decorations), or level 10 | Keep the yard sharp for judging day |

Changes from the table above: act 2 → 3 and the start of act 3 were two different gates (level 5
and level 8), so they're one now. Act 1 gets a level fallback too, so the story never stalls.

### Act 1: The Shears

- **After the first job, June:**
  - *"Saw you finish Edna's lawn from my porch. You missed a spot by the birdbath."*
  - *"$60?? I got $4 a lawn in 1971. Put it toward a mower. A REAL one."*
- **After the second job:**
  - **Mrs. Rossi** (bridge club group): *"Is the grandchild free Thursday?"*
- **Reel mower bought, June:** *"Now THAT's a mower. Your grandfather had one just like it. He
  was terrible with it."*

### Act 2: TurfKing

- **Chad's first text:** *"Cute scissors, bud. Heard you're doing lawns. Stay in your lane."*
- **TurfKing takes a job.** A job card on the board flips to "Taken by TurfKing" before you
  accept it. This happens at most once every few jobs. It's flavor; it never takes a job you
  already accepted.
- **When you beat TurfKing on quality** (a Quality customer, 90%+ finish), the customer texts:
  *"TurfKing scalped my lawn last month. You're hired for good."* That customer could pay a
  small bonus.
- **Gloria, from her porch:** *"Isn't it sweet, June's little helper."*
- **The act ends when you buy your first motorized mower.** June: *"Well. Look at you. Gloria's
  boys have three of those, so don't get cocky."*

### Act 3: The Crew

- **Sam texts:** *"hey it's Sam. Gloria's grandkid. I quit TurfKing today. Chad tried to mow a
  rock garden. if you ever need help lmk."*
  - With friends in your crew, Sam is just flavor.
  - Playing solo, Sam could become a hired NPC helper later. It's an optional system.
- **June turns to her own yard:** *"Contest's coming. Our yard looks like a vacant lot. Fix it."*
  - Goal card: "Raise curb appeal to [contest bar]".
  - This leans on Hub 3 (your own lawn) and Hub 3b (decorations), which already exist.
- **Gloria's yard visibly improves** over the act, since TurfKing is good at edges. It sets the
  bar.

### Act 4: The Contest

- **Judging day.** Judges walk both yards in a short cutscene, then the results screen (the "Best
  Yard results" board):
  - Scores for lawn and stripes, edges, beds and shrubs, and decorations and charm.
  - The categories come from what the game already measures: the home lawn's done share, edge
    tasks and `DecorService:DecorShare`.
- **The secret comes out before the result.** Gloria: *"Half that trophy's always been mine,
  June. You know it."* June goes quiet for the first time all game.
- **If you win:**
  - June's 31st trophy, $2,500, a **Best Yard Trophy** decoration for your yard, and the Office
    unlocked or discounted.
  - In the last scene, June scratches Gloria's name onto the new trophy next to hers.
  - Gloria: *"Fine. FINE. Same time next year, June."*
- **If you lose:**
  - Gloria wins, insufferably.
  - June: *"Next summer. And you're mowing every Tuesday."*
  - The judges come back on Saturday, so you can try again.

**After the first judging day it is every Saturday (UTC).** The judges can be called once on each,
the goals rail counts the days to the next, and June's porch line counts them too: "Saturday's the
day. 2 days to go." The results screen says so after a loss: "Judging day comes round again next
Saturday." A Saturday you miss changes nothing. Four lost Saturdays start a new summer anyway, with
Gloria's bar 2 higher.

### After the story

- Best Yard comes back every "summer" (a win, or four lost Saturdays), and Gloria raises the
  stakes each time: a bigger crew, a fountain, flamingos.
- Customers keep their personalities, and June keeps texting.
- Room for more later: other neighborhoods, a regional contest, and TurfKing's head office.

## How the story is told in game

- **The dialogue box.** It's a bottom-of-screen box with a portrait, a name tag, line dots, and
  "Click/Tap to continue" plus Skip. It's used for the intro and act changes. The mock-up shows
  PC and phone.
- **Speech bubbles over NPCs:** BillboardGuis, for Gloria's porch remarks and customer
  reactions.
- **A Messages app on the shop computer**, next to Jobs, Orders, Business and Crew:
  - threads from June, the bridge club, Chad and customers;
  - unread badges;
  - a goal card with progress (the mock-up's "Shop computer: Messages" board).
  - Most story beats are texts, so they never interrupt play.
- **Grandma on her porch.** She's an NPC at your plot, beside the shop. E to talk gets a
  rotating line about your progress or Gloria.
- **Gloria's house** is a fixed NPC house in sight of the plots. Her yard improves by act.

## What needs building

This is in rough order, as separate PRs.

1. **Story state in the save.** *Built.*
   - `story = { act, seen = { [beatId] = true } }`, with a save version bump.
   - A `StoryService` on the server that listens for what's already happening (job done, item
     bought, level up, curb appeal) and fires beats once.
   - Beats live in a config file, `Shared/Config/Story.luau`, so lines are easy to edit.

   What was built:
   - **The save** (version 10, see GAME_DESIGN.md "Saves"): `story = { act, seen, scenes, texts,
     read, nextText }`. Besides the act and the beats seen, it holds the scenes still to play
     and the inbox of texts (capped at 60).
   - **`StoryService`** hooks into signals that were added where things already happen:
     `JobService.JobFinished` (each crew member, with the customer, their pay, the finish and
     the crew size), `ShopService.Bought`, `DataService.LeveledUp` and the player's
     `CurbAppeal` attribute. It keeps no counts of its own: the gates read the save (owned
     tools, xp, jobs done) and the curb appeal.
   - **`Config/Story.luau`** has every line on this page: the intro, the acts' scenes and texts,
     the act 1-3 beats and the contest's lines (for item 5). `lune run scripts/check-story`
     checks it.
   - **Players who were already playing** get a short "welcome back" scene instead of the intro
     (the set-up lines, without the shears), and are caught up to their act on joining. Their
     acts' texts arrive, but no act scenes play.
   - **Edna's lawn.** The job board's starter job (the Front Lawn) is now always Mrs. Alvarez's
     (Edna), so the intro's "Edna's front lawn is next" is true.
   - **Lines that are new** (not on this page before), all easy to change in `Story.luau`:
     - June's job critiques in act 1 (`Story.Critiques`), picked by the finish;
     - what June says when you talk to her on her porch (`Story.JuneTalk`);
     - act 4's opening: *"Hmph. It doesn't look like a vacant lot any more."* and *"Judges walk
       the street at the end of summer. Keep it sharp till then."*;
     - from the mock-up's Messages board: Mrs. Alvarez's *"Thank you, dear! Same time next
       week?"*, your *"Saving for the reel mower."* and June's *"Good. Gloria's TurfKing boys
       scalped her front lawn this morning. I took pictures."*, after the first job.
   - The small bonus from a customer won over from TurfKing came with item 4.
2. **`DialogueController`.** The dialogue box from the mock-up. It handles skip, works on phones
   (44 px+ targets) and hides the HUD while it's up. It plays as June's welcome after the first
   payday. *Built.*
   - **The box:** letterbox bars, the round portrait poking above the box, the green name tag,
     line dots, "Click to continue" ("Tap" on a phone, Space or Enter on a keyboard, A on a
     gamepad), and Skip (44 px tall) in the top bar, with the scene's caption in the middle. A
     line types out; going on finishes it first. Walking is off, the HUD and hotbar hide
     (`UI.hideGame`) and the mouse is free (`UI.holdCursor`) while it's up. Phones held sideways
     (under 500 px tall) get the smaller sizes from the phone mock-up.
   - **When scenes play:** StoryService queues them, and they play once the title card is gone
     (`TitleCardDone`) and you're not on a job, at the computer, in a menu or placing a
     decoration. Skipping counts as watched. A crew heading off to a job stops a scene, and it
     plays again later.
   - **Camera shots:** a line's `shot` points the camera at June (her `TalkView`) or Gloria's
     house (`IntroView`); far apart shots cut behind a quick fade. It goes back to first person,
     facing the same way, at the end.
   - **Speech bubbles:** `DialogueController.bubble(adornee, speaker, text)`, white with a dark
     outline and the speaker's name in their color. Gloria's lines in scenes and June's porch
     talk use them; customer reactions can later.
   - **The intro hands off to the first-job coach:** `TutorialController` waits while the intro
     is queued or playing (it comes after the first payday), then shows its next step, now
     "Edna's front lawn is next...". Its first step, "Click and hold to snip. Clear the lawn.",
     already showed on the first lawn.
   - **Grandma June** (`src/server/GrandmaJune.luau`) sits on her porch rocker beside the shop on
     every plot, turned toward the driveway. E (or the phone button) on her says a line from
     `Story.JuneTalk`, taking turns between your act's goal and Gloria.
   - **Gloria's house** (`GloriaService`) is one fixed house across the south street from the
     second row of plots, with her standing on the porch. In a Studio-built town it goes on a
     part named `GloriasLot`. Its stages, TurfKing trucks and judging day are still to do (item
     4 and 5); its `Yard` folder holds what they'd swap.
   - **The art** is all in `src/client/StoryArt.luau`, empty for now: portraits for June,
     Gloria, Chad, Sam, Edna, the Bridge Club and customers, the dialogue box and name tag
     9-slices, the bubble 9-slice and tail, the two chevrons and the "New tool" card icon.
     Colors are `UI.Colors` (new: `Outline`, `Letterbox`, `Track`, `Bubble`, `BubbleText`,
     and `Cast` for each character) and the font is `UI.Font`.
   - The TurfKing truck backing into Gloria's drive on the intro's first line came with item 4.
3. **The Messages app** in `ComputerController`: threads, unread badge, goal card, and a
   notification when a text arrives outside the shop. *Built* (`MessagesController`).
   - **Threads:** Grandma June, the Bridge Club (each text says who in the club sent it), Chad
     from TurfKing, Sam (from act 3) and one per customer, newest first. Each card has a face
     (portrait, or initials on the person's color), the name, the last line and a yellow unread
     count. The open thread has their texts in grey on the left and yours in green on the right.
   - **Unread:** opening a thread reads it (`ReadThread`, saved as the last text read in each
     thread). The Messages buttons on the desktop and the taskbar show the total, and the open
     app's taskbar button is green, as in the mock-up.
   - **Toasts:** a new text pops up with the game's other toasts (face, name, the line) when
     you're away from the computer, and waits until a scene is over. At the computer the badge
     goes up instead.
   - **The goal card** at the bottom of the thread: the act's goal with its progress bar, money
     toward the price ("Buy the Reel Push Mower $66 / $150") or curb appeal toward its number.
     It wraps the bar under the goal where one row doesn't fit.
   - **Phones:** under 560 px wide the thread list and the open thread take turns (a back
     button returns to the list), and the goal card sits under both.
   - **Saving:** the inbox is in the save (`story.texts`, at most 60, the oldest dropped) with
     what's been read.
   - Art slots in `StoryArt`: `TheirText` and `MyText` (9-slices) and `TextToast`.
4. **NPCs and the world:**
   - June on a porch chair at each player's plot (*built*, with item 2);
   - Gloria's house and yard in three stages;
   - TurfKing's livery (a purple truck with a crown) for the cutscene and job sites;
   - the "Taken by TurfKing" job flip.

   *Built.*
   - **Gloria's yard by act.** Each player sees her yard as it is in their own act, so the
     house is the server's (`GloriaService`) and the yard is each screen's own
     (`GloriaController`). The server builds all three yards and TurfKing's truck into
     `ReplicatedStorage.GloriasYard`, already in place, and each screen puts a copy of the ones
     for its act in the house's `Yard` folder (`Story.GloriaYard`):
     - act 1, stage 1: tired. Shaggy patches, dandelions, shrubs that need a trim and a small
       flower bed;
     - acts 2 and 3, stage 2: TurfKing's mowing stripes, crisp edges down the path, black mulch
       beds under squared shrubs, and a TurfKing sign by the walk;
     - act 4, stage 3: over the top. Checks instead of stripes, topiary balls in planters, a
       tiered fountain, rose beds, solar lights all the way up the path and nine pink flamingos
       in a V.
     With real models, `Story/GloriaYard_Stage1..3` replace them, placed at the house's origin;
     the placeholder path, fence and mailbox are only built while the yards are placeholders.
   - **Gloria on her porch** says something now and then when you're within about 130 studs
     (a speech bubble, every 35-55 s): `Story.GloriaRemarks`, three lines an act. From act 2,
     Chad takes turns with her from beside his truck (`Story.ChadRemarks`, starting with "Cute
     scissors, bud."). New lines, in the same voice:
     - act 1: *"Are those scissors? How quaint."*, *"June, dear, your grass is waving at me."*;
     - act 2: *"TurfKing does my edges with a laser, you know."*, *"Chad says your mower is
       vintage. That's one word for it."*;
     - act 3: *"Oh, a crew! How ambitious."*, *"My hedges are squared, June. Squared."*, *"I saw
       you bought a shrub. Just the one?"*;
     - act 4: *"Flamingos, June. In formation."*, *"The judges adore a fountain. Or so I've
       heard."*, *"Thirty years. This is my year, June. I can feel it."*;
     - Chad: *"Stay in your lane, bud."*, *"TurfKing, bud. Look it up."*, *"That's a lot of grass
       for one kid, bud."*
   - **TurfKing's truck** (`Assets.turfKingTruck`): `Story/TurfKingTruck`, or until it's in, the
     heavy-duty pickup painted TurfKing purple the way a Robux paint job is (`Premium.applyPaint`),
     with a gold stripe down each side at door height, the gold crown on both doors and an amber
     light bar. From act 2 it's parked in Gloria's drive (on the house's `Driveway` marker, if it
     has one) with Chad beside it. In the intro it backs into her drive from the street on the
     first line, and goes again after.
   - **"Taken by TurfKing"** (`TurfKingService`, rules in `Config/TurfKing.luau`). From act 2, a
     few seconds after you walk up to your shop's computer (a random 4-9 s), one of the job
     cards can flip to "Taken by TurfKing": a purple card with the stamp, which lands with a
     thump if you're looking, and a "Taken" button. The server won't accept it. Chad texts you
     about it (`Story.TurfKingTexts`), and a toast says which address it was.
     - At most once every 3 jobs you finish, with a 50% chance each time you walk up to the
       computer.
     - Never the starter job, never one someone's accepted, never one above your level.
     - Only a crew's leader (or someone on their own) has jobs taken, since they're the one who
       accepts. Everyone else's board is the same as before: the board is shared, and the
       "taken" mark is only on your view of it.
     - A new board (every 3 minutes) brings the jobs back.
   - **Beating TurfKing:** the first time each Quality customer gets a 90%+ finish from someone
     in act 2 or later, they're won back. They text *"TurfKing scalped my lawn last month. You're
     hired for good."* (the `QualityWin` beat, now once per customer) and pay a bonus: 20% of the
     job's pay, from $10 to $100, rounded to $5. It's split with the crew like the rest of the
     pay, and shows as a "Won from TurfKing" line in the pay breakdown. It's the business of the
     leader who drove out that wins the customer.
   - **Models:** `GloriaHouse` and `GloriaYard_Stage1..3` are files in `Assets/Story`,
     `TurfKingSign` is one in `Props`, and Gloria and Chad are rigs that `CastService` builds, like
     every other person in the story. A block placeholder from `Placeholders.luau` stands in only
     when one is missing, and the `Head` marker on a model or rig places the speech bubbles.
   - Not built: TurfKing's truck at the job sites it's taken (the taken job never happens
     anywhere you can go).
5. **The contest:** `ContestService` (scoring from home lawn, edges and decorations against
   Gloria's bar for the act), the judging cutscene, the results screen, rewards and the trophy
   decoration. *Built.*
   - **Entering.** Once you're in act 4, June texts that the judges are in town and what
     Gloria's yard would score. On her porch she talks about it (`Story.JuneTalk.Contest`), and the
     Messages app's goal card becomes "Beat Gloria's 88 on judging day" with a **Call the judges**
     button. Pressing it texts June ("Call the judges. We're ready.") and puts the computer away,
     so judging day plays when you're ready.
   - **Scoring** (`Config/Contest.luau`, all tunable). There are four categories of 25 points
     each, from what the game already measures about your own business's yard. The yard is scored
     the moment you call the judges, so the result can't change after that.
     - **Lawn and stripes:** the share of your lawn's grass, weeds and leaves that's done, less 2
       for each piece of junk still in the grass.
     - **Edges:** the share of the lawn's edge targets done.
     - **Beds and shrubs:** half for beds (mulch beds, raised beds, planters and flower patches,
       full marks at 3), half for trimmed shrubs (full marks at 4; a shaggy one counts a quarter).
     - **Decorations and charm:** 70% for how well decorated the yard is (`DecorService` share, as
       for curb appeal, full marks at 0.6), and 30% for variety (full marks at 8 different kinds).
     - A yard fresh past act 3's curb appeal of 75 (a tidy lawn and a few decorations) scores about
       75. Beating 88 takes a fresh mow and edge, three beds, four trimmed shrubs and a
       well-decorated yard.
   - **Gloria's bar** is 88 the first summer and 2 more each summer after (each one you win),
     capped at 96. Her score splits over the categories with TurfKing's edges the strongest. A tie
     goes to June, the champion. (Not the same as `Story.ContestBar`, the curb appeal of 75 that
     starts act 4.)
   - **Judging day** (`ContestJudging`): a "Yard" shot of your front lawn with the two judges
     (`NPC_Judge1` Judge Pruitt and `NPC_Judge2` Judge Marigold, rigs that `CastService` builds)
     walking it, then the same across the street at Gloria's. Gloria says *"Half
     that trophy's always been mine, June. You know it."*, June goes quiet, and the narrator tells
     the 1994 secret. Later summers play a shorter `ContestJudgingAgain` without the secret.
     `DialogueController` gained `addShot` (named camera shots from other controllers) and
     `LineShown` (a line's `judges` walks them).
   - **The results screen** (`ContestController`) follows the mock-up's "Best Yard results" board:
     "END OF SUMMER" and "Maple Grove Best Yard" in yellow; your yard's card (green outline when
     you win, a big score), the trophy with "June's 31st win", and Gloria's card in purple ("Done
     by TurfKing"); the category table with your bars in green and hers in purple; the reward
     chips; Gloria's closing line; and **Collect**. It's laid out at 1100 × 640 and scaled to fit,
     so Collect is still about 44 px tall on a phone held sideways. Confetti falls on a win.
   - **Winning** pays $2,500 every time. The first win also brings:
     - the **Best Yard Trophy**, a decoration delivered in a box like an order (in the catalog with
       `won = true`: never sold, can't be sent back; appeal 8; its cup shines);
     - **half off the Small Office** (or the Equipment Yard, if you already have the office). The
       buildings are only gated by buying them in order, so the office is always reachable, and a
       discount fits better than an unlock. It's shown in the Business app and used up when you
       buy it (`Shop.price`).

     Then the ending plays (`ContestWin`). June scratches Gloria's name onto the trophy and says
     *"There. Should've done that in '94."* (a new line), and Gloria answers *"Fine. FINE. Same
     time next year, June."* Later wins play `ContestWinAgain`.
   - **Losing:** Gloria wins, insufferably (`ContestLose`: *"Oh, June. Thirty years, and all it
     took was a franchise."*, *"I'll keep it polished for you. You can visit."*, both new). Then
     June: *"Next summer. And you're mowing every Tuesday."* You can try again the next
     Saturday: after the first judging day the calendar takes over (Act 4, above), and the goal
     card counts the days.
   - **Every summer after:** a win starts the next summer, with Gloria's bar 2 higher, and so do
     four lost Saturdays. June texts when the judges are back.
   - **Saving:** save version 11 adds `contest` (see GAME_DESIGN.md "Saves").
   - **Remotes:** `GetContest`, `StartJudging` and `CollectContest` take nothing from the client,
     are rate-limited to one a second, and the server checks the act, the state, that you're not on
     a job and that your yard exists. `ContestUpdated` sends the state, the bar and the result.
   - **Art slots** in `StoryArt.Contest`: the title wordmark and ribbon, the Winner and So Close
     wordmarks, the trophy, the score track and both fills, the four category icons and the
     confetti sheet. Plus `Judge1` and `Judge2` portraits.
6. **Models.** Gloria's house and its three yards, the porch deck and rocking chair, the TurfKing
   sign and the Best Yard Trophy are model files, and the story's people are rigs that `CastService`
   builds. The block placeholders (`Props/GrandmaJune`, `Props/PorchRockingChair`,
   `Props/GloriaPemberton`, `Props/GloriasHouse` and the `NPC_*` blocks) show only when a model or
   rig is missing.
7. **Sounds:** a dialogue blip, a text-message ping and a trophy fanfare.
