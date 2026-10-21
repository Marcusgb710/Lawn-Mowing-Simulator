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

1. **Story state in the save.**
   - `story = { act, seen = { [beatId] = true } }`, with a save version bump.
   - A `StoryService` on the server that listens for what's already happening (job done, item
     bought, level up, curb appeal) and fires beats once.
   - Beats live in a config file, `Shared/Config/Story.luau`, so lines are easy to edit.
2. **`DialogueController`.** The dialogue box from the mock-up. It handles skip, works on phones
   (44 px+ targets) and hides the HUD while it's up. It plays after the title card on first
   join.
3. **The Messages app** in `ComputerController`: threads, unread badge, goal card, and a
   notification when a text arrives outside the shop.
4. **NPCs and the world:**
   - June on a porch chair at each player's plot;
   - Gloria's house and yard in three stages;
   - TurfKing's livery (a purple truck with a crown) for the cutscene and job sites;
   - the "Taken by TurfKing" job flip.
5. **The contest:** `ContestService` (scoring from home lawn, edges and decorations against
   Gloria's bar for the act), the judging cutscene, the results screen, rewards and the trophy
   decoration.
6. **Models for ChatGPT** (the next instructions file is `instructions37.md`):
   - Grandma June, Gloria, Chad and Sam (simple stylized NPCs, R15-compatible or static);
   - a porch rocking chair;
   - TurfKing truck livery;
   - the Best Yard Trophy;
   - Gloria's house (three tidiness stages).
7. **Sounds:** a dialogue blip, a text-message ping and a trophy fanfare.
