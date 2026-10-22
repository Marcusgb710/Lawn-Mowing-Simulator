# Instructions 38: The full GUI overhaul, with custom fonts

**This replaces instructions 36. Do this one instead of 36.** It has everything 36 asked for,
plus custom fonts, the story screens, the Robux shop, and the art for the game's Roblox page.

The game's GUI is still placeholder: plain rounded boxes in flat greens, drawn in code, all in one
built-in font. This file is a complete overhaul: one finished art direction, custom display
fonts, and every frame, button, icon, portrait and picture the GUI needs, ready to drop in.

## The game, for context

Lawn Mowing Simulator is a realistic first-person lawn-care game for **phones held sideways** and
PCs. Players run their own business from a walk-in shop:
- they pick jobs on a **computer in the shop**;
- they order tools and supplies there, then load the truck parked at the door;
- they drive to customers' houses and mow, trim, edge, rake, prune and plant;
- new players start with nothing but **grass shears**, and junk hides in the grass.

The story is **Grandma's Rival** (`docs/STORY.md`, read it first). Grandma June has won the Maple
Grove Best Yard trophy 30 years running, and her rival next door, Gloria, hired the slick franchise
TurfKing to beat her. It's funny and warm. The world is realistic and sunny: see the renders in
`model-source/HighPoly/*/Previews/` and the title card in `art-source/TitleCard/` (its logo is
cream Fredoka lettering with a deep green outline and a grass tuft). **The GUI must feel like the
same game as that title card.**

## Every screen the GUI has to cover

All of these are in the game today as placeholders, or are being built now:

- **HUD**, always on:
  - money, level with an XP bar, "N jobs done", and curb appeal (0–100);
  - menu buttons on the left (Truck, Guide, Crew) with their keys (T, G, C);
  - the aiming dot in the middle, and "Hold Alt for the mouse";
  - a story **goal tracker** ("Buy the Reel Push Mower $66 / $150").
- **Look-at prompts** under the dot, like "[E] Take Reel Push Mower", or red with the reason
  when you can't. On phones, a big round button replaces E.
  - **Phone action buttons:** Snip (shears), Pick up (junk), Place / Turn / Put back
    (decorations), Talk.
  - A **hold ring** (circular progress) for hold-E jobs like pouring fuel or filing a blade.
- **The shop computer:** the camera eases in to the monitor, which shows a desktop with five
  apps (Jobs, Orders, Business, Crew, **Messages**), a taskbar and Back.
  - **Jobs:** job cards with the customer's address, what they want, the pay and a Take button.
    A card can be stamped **"Taken by TurfKing"**.
  - **Orders and Business:** category tabs, and item cards with a picture, name, description,
    tier and storage line. Each card has a button: a price, Bought, Sell $7, Locked, Equip, Owned
    or Current.
  - **Orders → Premium tab:** Robux items in three sections: Pro upgrades (4 game passes),
    Premium tools (6 gold/chrome/stealth versions of tools) and Truck paint (7 paint jobs, plus
    "Factory paint"). Buttons show "R$ 199", Owned, Use or In use.
  - **Crew:** invite, kick, leave.
  - **Messages:** threads on the left (June, the Bridge Club, Chad from TurfKing, customers,
    Sam) with avatars and unread badges. The open thread on the right has their bubbles and
    yours, and a goal card at the bottom.
- **Dialogue** (the story intro and act scenes):
  - letterbox bars;
  - a box along the bottom with a round portrait poking out of its top edge, a name tag, the
    line, progress dots, and "Click / Tap to continue";
  - a Skip button;
  - **speech bubbles** over characters in the world.
- **Truck menu:** your tools as a checklist next to the customer's to-do list.
- **Guide:** what every tool is for, by category.
- **Job tracker** during a job: the to-do list (including "Pick up junk in the grass 1/4"), a
  timer against par, and damage.
- **Pay breakdown** after a job: job pay, finish, speed, crew, curb appeal, junk and damage lines
  adding up to the total.
- **Toasts:** short messages that slide in, including "New text from Grandma June".
- **Big moments:** Job complete, Level up, New tool, an act title card ("Act 2: TurfKing").
- **Best Yard results** (the finale): two yards' scores by category, a trophy and rewards.

A mock-up of the dialogue, Messages and contest screens in today's placeholder style is at
https://claude.ai/artifact/FQbzu9rR7bMz64MQ8t2o7K. Use it for layout only; your art replaces its
look.

## The art direction: "Maple Grove Summer"

One direction, finished. Don't make alternatives.

- **The feel:** a sunny suburban summer. It's friendly, chunky and tactile, as clear as a good
  phone game, with small handmade touches that come from the story.
- **Shapes:**
  - Soft rounded panels with a **thick deep-green outline**, like the title logo's lettering, and
    a soft drop shadow.
  - A gentle top highlight, and a very faint paper grain.
  - Buttons look **pressable**: a raised face over a darker base that "sinks" when pressed.
- **Signature details:**
  - Progress bars fill with **mowing stripes** (alternating light and dark green bands).
  - Price tags are shaped like **garden plant tags**.
  - Grandma's goal card looks like a **sticky note in her handwriting style**, drawn as shapes
    with no text.
  - TurfKing's things are **purple and gold, too slick**: glossy, with a crown.
- **Palette:** start from these roles and values, and adjust for contrast if needed. Keep the
  roles.

  | Role | Hex |
  | --- | --- |
  | Outline / ink | `#17301C` |
  | Panel | `#24442B` |
  | Card | `#315A39` |
  | Text (cream) | `#FFF7E0` |
  | Subtext | `#CFE3C6` |
  | Accent (grass) | `#7BC74D`, dark `#4E9A2E` |
  | Money (sunflower) | `#FFD24A` |
  | Danger (tomato) | `#E0553F` |
  | Info (sky) | `#6FB7E8` |
  | TurfKing | purple `#6B4FBF`, gold `#E8B931` |
  | Grandma | straw `#E3C27A`, hat band `#C8463C` |

- **Contrast:** text on panels must reach 4.5:1. Colours that have to be told apart also differ in
  lightness, not only hue.

## Part 1: Style frames

Finished mock-ups that prove the look, built from the kit in Part 3 and written in the fonts from
Part 2, in `art-source/GUI/StyleFrames/`. They use the real words from the game (the screen list
above, tool names from the item list, lines from `docs/STORY.md`).

| File | Size | What it shows |
| --- | --- | --- |
| `HUD_PC.png` | 1920 × 1080 | In play over a front-lawn render: HUD, a prompt, the dot, the job tracker and the goal tracker |
| `HUD_Phone.png` | 2340 × 1080 | The same on a phone, sideways, with the Snip and Pick up buttons |
| `Computer_Jobs.png` | 1920 × 1080 | The Jobs app with three cards, one stamped "Taken by TurfKing" |
| `Computer_Orders.png` | 1920 × 1080 | The Orders app on the Mowers tab, with four item cards in different states |
| `Computer_Premium.png` | 1920 × 1080 | The Premium tab with passes, tools and paint |
| `Computer_Messages.png` | 1920 × 1080 | A thread with Grandma June |
| `Dialogue_PC.png` | 1920 × 1080 | The intro: June on her porch, Gloria's bubble next door |
| `Dialogue_Phone.png` | 2340 × 1080 | The same beat on a phone |
| `PayBreakdown.png` | 1920 × 1080 | The pay breakdown |
| `BestYard.png` | 1920 × 1080 | The finale results |
| `Sheet.png` | 2048 × 2048 | The system at a glance: palette with hex values, the type scale, button states, a panel, a card, tabs, a toast, both prompt states, bubbles, and a few icons |

## Part 2: Custom fonts

**Roblox can't load a .ttf or .otf file.** Games can only use Roblox's built-in font families, so
custom lettering is done with **images**. Deliver three layers:

### 2a. Live text: two of Roblox's built-in fonts

Most text in the game is live: item names, descriptions, chat lines, numbers that change. Pick
the two built-in fonts that best match your direction and say why in the manifest:

- **Headings:** from `FredokaOne` (it matches the logo), `LuckiestGuy`, `Bangers`,
  `PermanentMarker` or `DenkOne`.
- **Body:** from `Nunito` (rounded, very readable; Regular, SemiBold, Bold, ExtraBold), `BuilderSans`
  (Roblox's UI face) or `Ubuntu`.

Use exactly those two in every style frame for live text, so the frames show what the game will
really look like.

### 2b. The display font: bitmap glyph atlases

For the big, characterful text (money counters, scores, timers, headlines, act titles), pick an
**OFL-licensed display typeface** that's chunky, rounded and friendly. It must pair with the
logo's Fredoka, read at small sizes, and look great with a thick outline. Lilita One, Baloo 2
ExtraBold or Chewy are good starting points; you choose. You may customise it, for example a
grass-tuft dot on the i.

Deliver it as **bitmap fonts in AngelCode BMFont format** (`.fnt` as JSON, plus the atlas PNGs),
in `art-source/GUI/Fonts/`. Every atlas is at most 1024 × 1024, and each glyph comes as **two
layers in two matching atlases**: the face (pure white, so the game can tint it) and the outline
plus drop shadow (deep green `#17301C`, so it can be recoloured too). The game stacks them.

- `Display_Numbers`: `0–9 $ , . + − % / : × R` at about **128 px cap height**. Used for money,
  scores and timers. The digits are tabular (all the same width).
- `Display_Headline`: `A–Z a–z 0–9` and `. , ! ? ' ’ " - – : ; & ( ) # / $ %` at about **72 px
  cap height**, for headlines.
- Each `.fnt` gives every glyph's rectangle, offsets, advance, the line height and baseline, and
  kerning pairs.
- `Fonts/Source/`: the original font files (.ttf/.otf) and their **OFL licence**, in case Roblox
  adds font uploads later.
- `Fonts/Specimen.png` (2048 × 1024): both atlases set as real text (a money counter "$12,450",
  "Act 2: TurfKing", "Best Yard"), over a panel.

### 2c. Pre-rendered wordmarks

Fixed big words, finished as images in the display font, with the outline and shadow, a little
grass-tuft or sparkle flourish where it fits, and a transparent background. They go in
`art-source/GUI/Wordmarks/`, each at most 1024 px wide:

- the moments: `JobComplete` ("Job Complete!"), `Payday` ("Payday!"), `NewTool` ("New Tool!"),
  `LevelUp` ("Level Up!"), `Winner` ("Winner!"), `SoClose` ("So Close!");
- the contest title: `BestYard` ("Maple Grove Best Yard");
- the acts: `Act1` ("Act 1: The Shears"), `Act2` ("Act 2: TurfKing"), `Act3` ("Act 3: The Crew"),
  `Act4` ("Act 4: The Contest");
- `Stamp_TakenByTurfKing`: a purple-and-gold rubber stamp, slightly rotated, reading "Taken by
  TurfKing";
- `Stamp_Sold` and `Stamp_Bought`: rubber stamps.

## Part 3: The kit

Everything is PNG, **at most 1024 px on its longest side** (Roblox shrinks anything bigger), on a
transparent background unless a piece says otherwise. Finished kit pieces have **no text** (only
the wordmarks, the style frames and the store art in Part 4 have text).

### Frames and buttons (`Kit/`): 9-slice pieces

Draw them at 2× (a 24 px corner radius drawn as 48 px), and list each piece's **slice centre**
(left, top, right, bottom, in pixels) in `manifest.json`.

- **Panels and cards:** `Panel` (a window with a darker title band), `Card`, `Card_Selected`,
  `Card_Locked`.
- **Buttons:** `Button_Primary`, `Button_Money`, `Button_Danger`, `Button_Neutral`,
  `Button_Disabled` and `Button_Robux` (a premium gold). Each has a `_Pressed`
  version, a little darker and 2 px lower.
- **Tabs:** `Tab`, `Tab_Active`.
- **Progress:** `ProgressTrack`, and `ProgressFill`, which tiles its mowing stripes
  horizontally (also give `ProgressFill_Money` and `ProgressFill_TurfKing`).
- **Small pieces:** `PriceTag` (a plant-tag shape), `Toast`, `Tooltip`, `Badge_Unread` (a small
  round badge).
- **Prompts:** `Prompt`, `Prompt_Blocked`.
- **HUD:** `HudPanel` (a little see-through), `MenuButton` (with room for the key badge),
  `KeyBadge`, `GoalTracker`.
- **Phone buttons:** `TouchButton` (256 × 256, round), `TouchButton_Small` (192 × 192), and
  `HoldRing` and `HoldRing_Fill` (256 × 256, a circular track and a fill the game sweeps).
- **Reticle:** `Reticle`, `Reticle_Active`, `Reticle_Blocked` (64 × 64).
- **Story:**
  - `DialogueBox`;
  - `NameTag`;
  - `PortraitRing` (256 × 256, the round frame portraits sit in);
  - `Bubble` with `BubbleTail` (world speech bubbles);
  - `Letterbox` (a 1 × 64 strip with a soft inner edge);
  - `StickyNote` (Grandma's goal card).
- **Messages:** `Bubble_Theirs`, `Bubble_Mine`, `ThreadCard`, `ThreadCard_Active`, `GoalCard`.
- **The contest:** `ScoreTrack`, `ScoreFill_You` (green), `ScoreFill_Rival` (purple), `Ribbon`
  (the banner behind the title wordmark).

### Glyphs (`Icons/`): 128 × 128, one colour

Plain **white** glyphs on transparent backgrounds (the game tints them), all with the same stroke
weight and corner style, readable at 32 px:

- **HUD and menus:** `Money`, `Level`, `CurbAppeal`, `Truck`, `Guide`, `Crew`, `Close`, `Back`,
  `Check`, `Lock`, `Timer`, `Damage`, `Info`, `Goal` (a flag).
- **Apps:** `Jobs`, `Orders`, `Business`, `Messages` (a speech bubble), `Sell`, `Premium` (a
  sparkle gem).
- **Shop tabs:** `Cat_Mower`, `Cat_Trimmer`, `Cat_Rake`, `Cat_Edger`, `Cat_HedgeTrimmer`,
  `Cat_HandTool`, `Cat_Pruning`, `Cat_Watering`, `Cat_Digging`, `Cat_Hauling`, `Cat_LawnCare`,
  `Cat_Protection`, `Cat_Supplies`, `Cat_Decorations`, `Cat_Truck`, `Cat_Trailer`,
  `Cat_Business`.
- **Tool condition:** `Fuel`, `Tire`, `Blade`, `Spool`, `Wrench`, `Sharp`.
- **Actions:** `Snip`, `PickUp`, `Place`, `Turn`, `PutBack`, `Talk`, `Continue` (a chevron),
  `Skip`.
- **Tiers:** `Tier_Homeowner`, `Tier_Serious`, `Tier_Pro`.
- **Contest categories:** `Score_Lawn`, `Score_Edges`, `Score_Beds`, `Score_Decor`.
- **TurfKing:** `Crown`.
- **Junk:** `Junk` (a stick and a ball).

Don't draw the Robux symbol. The game uses Roblox's own.

### Item pictures (`Items/`): 512 × 512, full colour

One picture per item, named **exactly** with its id (`Items/ReelMower.png`), used on shop cards
and in the Truck menu.

- **Render them in Blender from your own models** in `model-source/HighPoly/`:
  - the same three-quarter view from the front-left and a little above;
  - the same soft studio light (a warm key and a cool rim), a soft contact shadow, and a
    transparent background;
  - every item framed to fill about 80% of the canvas.
- **Third-party kit tools:** six tools aren't in your packs: `GasPushMower`, `RidingMower`,
  `ZeroTurnMower`, `ElectricTrimmer`, `GasTrimmer` and `OldRake`. Their look is in
  `model-source/RevisedLawnModels/OriginalKitPreviews/01_Equipment.png` and `02_Trimmers.png`.
  Make quick render-only models that match, and don't add those models anywhere else.
- **The items:** all **108 ids listed under "Item icons" in `alphainstructions/instructions36.md`**,
  plus:
  - `BestYardTrophy` and the five junk pieces (`DebrisStick`, `DebrisRock`, `DebrisDogBall`,
    `DebrisToyTruck`, `DebrisFrisbee`), from the instructions 37 models;
  - **the six premium tools**, each rendered from its base tool with the finish applied:
    `GoldenGasPushMower` (gold, from `GasPushMower`), `ChromeSelfPropelledMower` (chrome),
    `StealthGasTrimmer` (matte black, from `GasTrimmer`), `ChromeLeafBlower`,
    `GoldenRidingMower` and `StealthZeroTurn` (from `ZeroTurnMower`).
    - Gold is a rich polished gold, chrome a mirror chrome, and Stealth a matte near-black with
      satin details.
    - Wheels, tires and glass keep their own look.
  - **The seven truck paint jobs**, each the `WorkPickup` truck in that paint:
    - `RacingRed` (196, 40, 36), `MidnightBlack` (40, 42, 48), `ForestGreen` (46, 110, 58) and
      `SkyBlue` (90, 160, 220): the factory finish tinted that colour;
    - `StealthWrap`, `ChromeWrap` and `GoldWrap`: the body, doors and tailgate in that finish.
- `Items/` totals **127 pictures**.

### Portraits (`Portraits/`): 512 × 512

Painted portraits for the dialogue box, the Messages avatars and the bubbles, **matching the
characters in `model-source/HighPoly/37_Story/Previews/CharacterSheet.png`**. If that isn't there
yet, follow the character descriptions in `alphainstructions/instructions37.md`, and keep them
consistent with each other.

- **Framing:** head and shoulders, centred with room above the head, so a **round crop** (the
  portrait ring) shows the whole face.
- **Style:** painted, warm and soft, in the same light as the world, with a plain soft background
  in that character's colour.
- **The portraits:**
  - `June_Neutral`, `June_Smug`, `June_Annoyed`, `June_Proud`, `June_Laughing`;
  - `Gloria_Smug`, `Gloria_FakeSmile`, `Gloria_Furious`, `Gloria_Defeated`;
  - `Chad_Cocky`, `Chad_Panicked`;
  - `Sam_FedUp`, `Sam_Happy`;
  - `Edna_Happy`;
  - `Rossi_Gossip` (Mrs. Rossi, bridge club, leaning in to share a secret);
  - `Nguyen_Picky` (Ms. Nguyen, bridge club, sharp bob, inspecting a leaf);
  - `Judge1`, `Judge2`;
  - `BridgeClub` (a group avatar: Edna, Mrs. Rossi and Ms. Nguyen around a card table).

That's **19 portraits**.

### The shop computer (`Computer/`)

- `Wallpaper.png` (1024 × 576): the desktop background, a calm, slightly blurred render of a
  freshly striped lawn with Grandma's porch at the edge.
- `App_Jobs`, `App_Orders`, `App_Business`, `App_Crew`, `App_Messages` (256 × 256): full-colour
  rounded-square app icons matching the glyphs.
- `Taskbar.png`: a 9-slice.

### Big moments (`Moments/`)

- `Trophy.png` (1024 × 1024): the Best Yard trophy, a hero render with light rays behind it.
- `Confetti.png` (1024 × 1024): a sprite sheet of 4 × 4 frames of falling confetti in the palette,
  plus a few grass clippings.
- `Sparkle.png` (256 × 256): a sprite sheet of 2 × 2 frames.

## Part 4: The game's Roblox page and store icons (`Store/`)

These are what players see on Roblox before they join, and in Roblox's purchase prompts. Text is
allowed here.

- `GameIcon.png` (512 × 512): the game's icon. The logo's grass-tuft "LM" mark or the mower over
  stripes, bold and readable at 64 px. Make it **square-safe**, since Roblox rounds the corners.
- `Thumbnail_1.png` to `Thumbnail_5.png` (1920 × 1080):
  1. the title card scene with the logo;
  2. shears in first person on an overgrown lawn ("Start from the bottom");
  3. June and Gloria glaring over the fence ("Beat Grandma's rival");
  4. the shop computer and a loaded truck ("Run your own business");
  5. the trophy in a gorgeous front yard ("Win Best Yard").
  Each has a short headline in the display font.
- **Pass icons** (512 × 512, **circle-safe**: Roblox shows passes in a circle): `Pass_DiamondBlades`
  (a gleaming diamond-edged blade), `Pass_RunFlatTires` (a tough tyre), `Pass_EndlessSpool` (a
  spool of trimmer line with an infinity loop), `Pass_BigTank` (a big jerry can).
- **Product icons** (512 × 512, circle-safe), one per developer product, named by id: the six
  premium tools and the seven paint jobs, from your item renders on a rich backdrop.

## Previews and manifest

- `art-source/GUI/Previews/`: the same screens as the style frames, built **only from the
  finished kit, fonts and pictures**, at the same sizes. They prove the pieces fit.
- `Previews/Items_ContactSheet.png` and `Previews/Portraits_ContactSheet.png`: every item picture
  and portrait in a grid, with their names under them.
- `art-source/GUI/manifest.json`:
  - every file with its size and what it's for;
  - the 9-slice centres;
  - the palette with each colour's role;
  - the two built-in fonts you chose, the weights to use, and why;
  - the bitmap fonts' files;
  - for item pictures, portraits and store icons, the id each file is for.
- `art-source/GUI/Source/`: the Blender scenes and design files, so anything can be changed later.

## Rules

- Write everything in `art-source/GUI/`. If anything from instructions 36 is already there, replace
  it. Don't change `assets/`, `src/`, `model-source/` or anything else. The local Claude session
  uploads the art to Roblox as Big Dink Studios and wires it into the game.
- No real brand names, logos or trademarks. TurfKing is made up, and its mark is just the crown.
- Everything must read on a **phone held sideways**: check every style frame at 50% size.
  Buttons must look tappable at 44 px tall, and glyphs must be clear at 32 px.

## Done when

- [ ] The 11 style frames are in `StyleFrames/`.
- [ ] Fonts:
  - [ ] the two built-in fonts are chosen;
  - [ ] both bitmap fonts are done (face and outline atlases, with `.fnt` metrics, source and
        licence);
  - [ ] the specimen sheet is done;
  - [ ] all the wordmarks and stamps are done.
- [ ] The kit is complete: every frame and button with pressed versions and slice centres, and
      every glyph.
- [ ] 127 item pictures, named exactly by id, rendered the same way, with the contact sheet.
- [ ] 19 portraits matching the instructions 37 characters, with the contact sheet.
- [ ] The computer wallpaper, five app icons and taskbar.
- [ ] The trophy, confetti and sparkle.
- [ ] Store art: the game icon, 5 thumbnails, 4 pass icons and 13 product icons.
- [ ] Every image is at most 1024 px on its longest side, except the style frames, previews,
      sheets and thumbnails.
- [ ] `manifest.json` lists everything.
- [ ] Nothing outside `art-source/GUI/` changed.
