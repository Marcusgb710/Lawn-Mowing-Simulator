# Story: Grandma's Rival

The story that wraps the game loop. It's a first pass to build the storyboard from. Names,
lines and beats can all change.

The mock-up of the intro, the Messages app and the contest results is at
https://claude.ai/artifact/FQbzu9rR7bMz64MQ8t2o7K. It's private until it's shared from its Share
menu.

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

## The intro (first join, about 60 seconds, skippable)

It plays after the title card lifts, in letterbox, with dialogue at the bottom. It's the
"Intro: Grandma's porch" board in the mock-up.

1. Sunrise over Maple Grove. A purple TurfKing truck pulls into the drive next door.
2. **Gloria** (a speech bubble over her house): *"Morning, June! Lovely… dandelions."*
3. **June**, from the porch: *"Thirty years. Thirty years I've won Best Yard on this street… and
   Gloria Pemberton goes and hires somebody."*
4. **June** hands you the shears, and a "New tool: Grandma's Grass Shears" card pops up: *"My
   mower died in '09. These never did. They won me the trophy in '94, so don't you lose 'em."*
5. **June:** *"Contest's end of summer. Make our yard the best on the street, and make some money
   doing it."*
6. **June:** *"Edna from bridge club needs her front lawn done. Computer's in the shed. Go."*

Control is yours. The first-job coach takes over from here: the shed computer, the "Front Lawn"
job, snipping, and picking up junk. That's the 5-minute shears job from PR #36.

## The four acts

Each act lines up with progress the game already tracks, so the story moves as you play and never
blocks you.

| Act | Starts when | Ends when | What happens |
| --- | --- | --- | --- |
| **1. The Shears** | Intro done | You buy the Reel Push Mower | Bridge club lawns. June critiques every job by text. Goal card: "Buy the Reel Push Mower". |
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
  - *"$66?? I got $4 a lawn in 1971. Put it toward a mower. A REAL one."*
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
  - The contest comes back after more play, so you can try again.

### After the story

- Best Yard comes back every "summer" (a play-time cycle), and Gloria raises the stakes each
  time: a bigger crew, a fountain, flamingos.
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
     (Edna), so the intro's "Edna needs her front lawn done" is true.
   - **Lines that are new** (not on this page before), all easy to change in `Story.luau`:
     - June's job critiques in act 1 (`Story.Critiques`), picked by the finish;
     - what June says when you talk to her on her porch (`Story.JuneTalk`);
     - act 4's opening: *"Hmph. It doesn't look like a vacant lot any more."* and *"Judges walk
       the street at the end of summer. Keep it sharp till then."*;
     - from the mock-up's Messages board: Mrs. Alvarez's *"Thank you, dear! Same time next
       week?"*, your *"Saving for the reel mower."* and June's *"Good. Gloria's TurfKing boys
       scalped her front lawn this morning. I took pictures."*, after the first job.
   - Not done: the small bonus from a customer won over from TurfKing.
2. **`DialogueController`.** The dialogue box from the mock-up. It handles skip, works on phones
   (44 px+ targets) and hides the HUD while it's up. It plays after the title card on first
   join. *Built.*
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
     is queued or playing, then shows its first step, now "Edna's front lawn is your first
     job...".
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
   - Not built: the TurfKing truck pulling up in the intro (it needs item 4's livery); the
     first line says it, over a shot of Gloria's house.
3. **The Messages app** in `ComputerController`: threads, unread badge, goal card, and a
   notification when a text arrives outside the shop.
4. **NPCs and the world:**
   - June on a porch chair at each player's plot (*built*, with item 2);
   - Gloria's house and yard in three stages (*a fixed house is built*, with item 2; the stages
     aren't);
   - TurfKing's livery (a purple truck with a crown) for the cutscene and job sites;
   - the "Taken by TurfKing" job flip.
5. **The contest:** `ContestService` (scoring from home lawn, edges and decorations against
   Gloria's bar for the act), the judging cutscene, the results screen, rewards and the trophy
   decoration.
6. **Models for ChatGPT** (the next instructions file is `instructions37.md`):
   - Grandma June, Gloria, Chad and Sam (simple stylized NPCs, R15-compatible or static);
   - a porch rocking chair;
   - The block placeholders are `Props/GrandmaJune` (sitting, on a seat 1.8 studs up),
     `Props/PorchRockingChair`, `Props/GloriaPemberton` and `Props/GloriasHouse` (front wall at
     Z = 0, porch in front, a `Porch` attachment where she stands). Real models with those names
     drop in; the markers the scenes need are worked out from their size.
   - TurfKing truck livery;
   - the Best Yard Trophy;
   - Gloria's house (three tidiness stages).
7. **Sounds:** a dialogue blip, a text-message ping and a trophy fanfare.
