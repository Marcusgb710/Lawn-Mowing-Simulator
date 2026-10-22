# Instructions 37: Story characters, story props and junk in the grass

The game now has a story, **Grandma's Rival** (read `docs/STORY.md` first, it's short). Grandma
June has won the Maple Grove Best Yard trophy 30 years running. This summer her next-door rival
Gloria Pemberton hired a slick lawn franchise, **TurfKing**, to beat her. June hands you, her
grandkid, her old grass shears. This file is every model the story needs, plus the five pieces of
junk that now hide in the grass on every job.

The tone is **funny and warm**: a family feud over lawns. The characters should read at a glance,
like a good animated film's cast, but sit naturally in the game's realistic, warm world. They're
**stylized-realistic**: real proportions with slightly bigger heads and hands, clear silhouettes,
and no cartoon outlines.

## What this is

These are **new models**. Build them at the same level of detail as the high-poly pass
(instructions 24–34). See your own renders in `model-source/HighPoly/*/Previews/` for the look of
the world they stand in.

## What to deliver

Mesh sources in the same format as `model-source/HighPoly/34_YardDecorations/`, in
**`model-source/HighPoly/37_Story/`**:

- `Models/<Id>/<Id>.gltf` with its `.bin`, plus `<Id>.fbx`, for every model in this file.
- **One combined library, `ALL/37_Story.gltf`**, with every model as a top-level node at its own
  spot in a grid (translation only, no rotation or scale on that node) and its meshes as child
  nodes. This is the file that gets imported into Studio.
- `model_manifest.json`, with the same fields as `34_YardDecorations/model_manifest.json` for
  every model: `name`, `folder`, `dimensions_studs`, `bounds_min_studs`, `bounds_max_studs`,
  `primary_part`, `primary_position_studs`, `markers`, `slots`, `triangles` and
  `mesh_objects`. `primary_part` is `Root` at (0, 0.5, 0) for every model here.
- One shared set of PBR textures in `Textures/` (Color, Roughness, Metalness, and Normal if used),
  each at most 2048 × 2048.
- Renders in `Previews/`:
  - each model on its own;
  - **`CharacterSheet.png`** (2048 × 2048): every character from the front and the side, with
    their palette as hex values. The GUI art in instructions 38 paints the dialogue portraits
    from this sheet, so make it clear and final.
  - **`Scene_Porch.png`**: June in her rocking chair on the porch deck, Gloria's house next door
    behind the fence, and a TurfKing truck in her drive.
  - **`Scene_Contest.png`**: judging day, with the two judges, the trophy on its stand, June and
    Gloria glaring at each other.

Don't change `assets/`, `src/`, the existing `model-source/` packs, or anything outside your
folder. The local Claude session imports your library into Studio as Big Dink Studios and puts the
models into the game.

## Rules for every model

- **Ids** exactly as listed (case-sensitive), each in the folder named next to it: `Story` (new),
  `Props` or `Decorations`.
- **Axes and units:** Roblox axes, +Y up, **front facing −Z**. Author in metres, with 1 stud =
  0.28 m (1 foot = 1.09 studs). A player is about 5 studs tall.
- **Origin:** on the ground at the centre of the footprint, with the lowest point at Y = 0.
- **Overall size:** within 10% of the sizes given (W × H × D, in studs).
- **Part names:** the main body is `<Id>__Body`. Every other piece the game moves, hides or swaps
  is its own mesh, named as below.
- **Markers** are named empty nodes, listed in the manifest's `markers` with position and
  orientation. The local session turns them into Attachments. They're named under each model.
- No scripts, lights, particles, real logos, brand names or readable text. TurfKing's mark is a
  simple **gold crown** emblem only, never letters.

### Characters

- **Static poses**, not rigs. Each pose is its own model. Model them dressed and posed as
  described.
- **The head is its own mesh**, `<Id>__Head`, with its pivot at the neck, so the game can turn it
  a little toward the player. Hats, hair and glasses go in the head mesh.
- Real cloth folds, visible hands with fingers, shoes with soles, and faces with clear,
  readable expressions (eyes, brows, mouth), set to each pose's mood.
- Add a `Head` marker at eye level, LookVector −Z (speech bubbles hang above it) and a `Talk`
  marker at chest height in front (where the "talk" prompt shows).
- **About 8,000–15,000 triangles** each, in at most 4 meshes: `__Body`, `__Head`, and up to two
  more if needed (for example `__Hat`).

## Models

### The cast (`Story`)

#### `NPC_June_Sitting` (Story)
**Grandma June Hollis**, 70s, sitting in her rocking chair (the chair is a separate model, below).
She's small, sharp-eyed and proud:
- a wide **straw sun hat with a red band**, silver hair in a low bun, round wire glasses;
- a sage-green cardigan over a cream blouse, khaki gardening trousers, well-worn garden clogs;
- a coffee mug in one hand, the other resting on the armrest;
- an expression of **unimpressed, watching Gloria's yard**: one eyebrow up.

About **2.6 × 4.2 × 3.2**. She sits so that her `NPC_June_Sitting` origin goes at the same point as
the `PorchRockingChair` origin.

#### `NPC_June_Standing` (Story)
June standing, the same outfit, holding her **rusty old grass shears** out in front of her in both
hands, presenting them, with a proud, stern half-smile. About **2 × 5 × 1.6**.

#### `NPC_Gloria` (Story)
**Gloria Pemberton**, 70s, June's neighbour and rival:
- tall and immaculate, with a coiffed silver-blonde bob and pearl earrings;
- a lavender cardigan set, pressed white trousers, kitten-heel loafers;
- holding a china teacup and saucer;
- a polite, **smug** smile with her chin up.
About **1.8 × 5.6 × 1.4**.

#### `NPC_Chad` (Story)
**Chad**, TurfKing's local boss, 30s:
- a purple TurfKing polo with the small gold crown on the chest, a gold visor and wraparound
  sunglasses pushed up on the visor;
- crisp khaki shorts, spotless white sneakers, and a clipboard under one arm;
- a big confident grin, giving a thumbs-up.
About **2 × 6 × 1.4**.

#### `NPC_Sam_TurfKing` and `NPC_Sam_Casual` (Story)
**Sam Pemberton**, Gloria's grandkid, about 17, gender-neutral, with messy short hair.
- `NPC_Sam_TurfKing`: in the TurfKing polo that's too big for them, a visor and work shorts,
  looking **fed up**, hands in pockets.
- `NPC_Sam_Casual`: after quitting, in a faded green T-shirt, jeans with grass-stained knees and
  sneakers, holding work gloves, with an easy grin.
Each is about **1.8 × 5.4 × 1.2**.

#### `NPC_Edna` (Story)
**Edna Alvarez**, June's friend from bridge club and your very first customer:
- warm and round, with short curly grey hair;
- a flowered sundress, a cardigan over her shoulders, and comfortable sandals;
- one hand waving, the other holding a lemonade glass;
- a delighted smile.
About **1.8 × 5 × 1.4**.

#### `NPC_Judge1` and `NPC_Judge2` (Story)
The Best Yard judges.
- `NPC_Judge1`: an older man in a seersucker jacket and bow tie, with a magnifying glass, crouching
  slightly to inspect the grass.
- `NPC_Judge2`: a woman in a sun hat with a big flower, a lanyard and a clipboard and pencil,
  making a note.
Both look serious and fussy. Each is about **2 × 5.4 × 1.6**.

### Story props and places

#### `PorchRockingChair` (Story)
A white-painted wooden porch rocker with curved runners, spindle back and a faded floral cushion.
About **2.4 × 4 × 3**. Add a `Seat` marker on the cushion, LookVector −Z. The runners rest on
Y = 0.

#### `PorchDeck` (Story)
June's little porch: a raised wooden deck with three steps at the front (−Z), white railings on
the sides and back, and a potted geranium in one corner. It goes beside the player's shop. About
**10 × 4.4 × 8**. The deck top is at Y = 1.6. The steps take players up, so give the deck and
steps clean collision, and keep the railings low-poly. Add a `ChairSpot` marker on the deck where
the rocker goes, facing −Z.

#### `GloriaHouse` (Story)
Gloria's house: a **handsome two-storey suburban colonial**, nicer than every other house on the
street:
- pale blue siding, white trim and black shutters;
- a covered front porch with columns, and a lavender front door;
- a bay window and a two-car garage;
- a paved driveway out to the street on the left (−X side).
It's a backdrop, so model the outside fully but no interior. About **44 × 30 × 36** including the
porch, with the front yard **not** included (see the next three). Add a `Porch` marker on the
porch where Gloria stands, facing −Z, and a `Driveway` marker in the middle of the drive, facing
the street, where a TurfKing truck parks.

#### `GloriaYard_Stage1`, `GloriaYard_Stage2`, `GloriaYard_Stage3` (Story)
Gloria's **front yard** in three stages, each placed with its origin at the `GloriaHouse` origin
(the yard runs from the house's front out to the sidewalk, **about 44 × 30**). The game shows one
at a time as the story goes on, so they share the same footprint and edges:
1. **Before TurfKing:** decent but tired. Slightly shaggy grass, uneven hedges, a few dandelions,
   a modest flower bed.
2. **TurfKing's work:** perfect diagonal mowing stripes, razor-sharp edges, fresh black mulch,
   squared hedges, and a **TurfKing yard sign** (`TurfKingSign`, below) by the walk.
3. **Contest week:** over the top. Checkerboard stripes, topiary balls in planters, a small
   tiered fountain, rose beds, solar path lights, and a row of pink flamingos standing in
   formation.

Each stage is about **6,000–14,000 triangles**. Its lawn is one mesh (`__Lawn`) and the rest goes
in `__Body`.

#### `TurfKingTruck` (Story)
TurfKing's crew truck, which parks in Gloria's drive and at jobs they've taken:
- a modern full-size crew-cab pickup in **deep purple** with a **gold** stripe;
- the gold crown emblem on both front doors and the tailgate, and chrome wheels;
- a ladder rack, and an amber light bar on the roof;
- an open bed carrying a **zero-turn mower** strapped down, with a ramp folded up.
It's spotless. About **9 × 8.5 × 22**. Wheels are their own meshes (`__WheelFL`, `__WheelFR`,
`__WheelRL`, `__WheelRR`) for turning. The light bar is `__LightBar`, with a `Light` marker.

#### `TurfKingSign` (Props)
A small lawn sign on two wire stakes: a purple panel with the gold crown (no text). About **1.6 ×
2 × 0.1**. Stakes go no deeper than Y = −0.3.

#### `BestYardTrophy` (Decorations)
The **Maple Grove Best Yard** trophy, which players win and place in their yard:
- a big gold loving cup with two handles, a **grass tuft and lawn stripes** engraved around the
  cup, and a small gold lawn mower on the lid;
- it stands on a stepped green-marble and walnut plinth, with blank brass plaques (no text);
- the whole thing stands on a **white wooden display stand**, with a short skirt of real
  turf around its base, so it looks proud in a front yard.
About **2.6 × 5.4 × 2.6**. The cup is `BestYardTrophy__Cup`, so the game can make it shine.

### Junk in the grass (`Props`)

These five already exist in the game as block placeholders. They lie in tall grass and players
pick them up before mowing, so they must be **small** (nothing taller than about 0.6 studs) and
**read clearly at a glance** among blades of grass. They have no collision.

| Id | Look | Size (studs) |
| --- | --- | --- |
| `DebrisStick` | A dead, bark-brown stick with a short side twig, lying flat | about 2.4 long |
| `DebrisRock` | A fist-sized grey field stone, a little mossy on one side | about 0.8 × 0.5 × 0.65 |
| `DebrisDogBall` | A slightly chewed, fuzzy yellow-green tennis ball, a bit muddy | 0.55 across |
| `DebrisToyTruck` | A kid's plastic toy dump truck, red bed, yellow cab, black wheels, facing −Z | about 1.1 long |
| `DebrisFrisbee` | A plastic frisbee lying flat, bright orange, scuffed | 1 across |

These are about **300–1,500 triangles** each, in one mesh (`<Id>__Body`).

## Triangle budgets

| Kind | Triangles |
| --- | --- |
| Characters (each pose) | 8,000–15,000 |
| Junk in the grass | 300–1,500 |
| Small props (sign, rocker) | 1,500–6,000 |
| Trophy, porch deck | 4,000–10,000 |
| Gloria's yard stages | 6,000–14,000 |
| TurfKing truck | 15,000–30,000 |
| Gloria's house | 15,000–35,000 |

No single mesh may go over 20,000 triangles; split bigger models into named meshes.

## Done when

- [ ] All 23 models are in `Models/` and in `ALL/37_Story.gltf`, with the ids, folders, sizes,
      part names and markers above:
      - the cast: `NPC_June_Sitting`, `NPC_June_Standing`, `NPC_Gloria`, `NPC_Chad`,
        `NPC_Sam_TurfKing`, `NPC_Sam_Casual`, `NPC_Edna`, `NPC_Judge1`, `NPC_Judge2`;
      - story props and places: `PorchRockingChair`, `PorchDeck`, `GloriaHouse`, the three
        `GloriaYard_Stage` models, `TurfKingTruck`, `TurfKingSign` and `BestYardTrophy`;
      - the five junk pieces.
- [ ] `model_manifest.json` lists every model, with each of the 23 in the folder named above.
- [ ] `Previews/` has every model, `CharacterSheet.png`, `Scene_Porch.png` and
      `Scene_Contest.png`.
- [ ] Nothing outside `model-source/HighPoly/37_Story/` changed.
