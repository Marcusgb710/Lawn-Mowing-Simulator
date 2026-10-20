# Instructions 36: Concept art and GUI art

The game's GUI is still placeholder: plain rounded boxes in flat greens, drawn in code. This file
is the art to replace it. It comes in two parts:

1. **Concept art**: three directions for how the whole GUI could look, shown as finished mock-ups.
2. **The GUI art kit**: every piece the game needs (panel frames, buttons, icons and an icon for
   every item), finished in **direction 1**, so it can go in straight away. The owner may pick
   another direction later and ask for the kit again in that style.

## The game, for context

Lawn Mowing Simulator is a realistic first-person lawn-care game for phones and PCs. Players run
their own business from a walk-in shop: they pick jobs on a **computer in the shop**, order tools
and supplies there, load the truck parked at the door, drive to customers' houses, and mow, trim,
edge, rake, prune and plant. There are 73 tools in three tiers (Homeowner, Serious, Pro), 24 yard
decorations, 4 trucks, 3 trailers and 4 shop buildings. The look of the world is realistic, warm
and clean: see your own renders in `model-source/HighPoly/*/Previews/`.

What the GUI has to show, screen by screen (all in the game today, as placeholders):

- **HUD**, always on: money, level with an XP bar and "N jobs done", curb appeal (0–100), menu
  buttons on the left (Truck, Guide, Crew) with their keyboard keys (T, G, C), a small dot in the
  middle of the screen to aim with, and "Hold Alt for the mouse".
- **Look-at prompts**: aim at something and a prompt appears under the dot, like "[E] Take Reel
  Push Mower". It's red with the reason when you can't ("That won't fit there."). On phones,
  there's a big round button to tap in place of E.
- **The shop computer**: the camera eases in to the monitor, and its screen shows a desktop with
  four apps (Jobs, Orders, Business, Crew), a taskbar along the bottom, and Back.
  - **Jobs**: job cards with the customer's address, what they want, the pay and a Take button.
  - **Orders** and **Business**: a row of category tabs, and item cards with a name, a
    description, a tier and storage line, and a button showing a price, Bought, Sell $7, Locked,
    Equip, Owned or Current.
  - **Crew**: invite, kick, leave.
- **Truck menu**: your tools as a checklist (in the truck, in your hands, in storage), next to the
  customer's to-do list.
- **Guide**: what every tool is for, by category.
- **Job tracker** during a job: the to-do list, a timer against par, and damage.
- **Pay breakdown** after a job: job pay, finish quality, speed, crew, curb appeal and damage
  lines adding up to the total.
- **Toasts**: short messages that slide in ("Sold the Blade File for $6.").
- **Title card**: done separately in instructions 35. Keep the GUI in the same family as that logo.

The game draws all text itself in **Fredoka One** (it's built into Roblox), so the art has **no
text in it**, except in the concept mock-ups, where you use Fredoka to show how it will look.

## Part 1: Concept art

Three directions, each shown as finished mock-ups. Make the directions really different from
each other:

1. **"Field tablet"**: clean, modern and flat. Rounded panels in deep green with a warm
   off-white, grass-green accents and a golden yellow for money, soft shadows, and generous
   spacing. It reads like the business app a real landscaper uses on a rugged tablet.
2. **"Workshop"**: tactile and hand-made. Clipboard paper, a pegboard and plywood texture, masking
   tape labels, stamped metal buttons and a red "approved" stamp feel, kept clean enough to read
   on a phone.
3. **Your own idea**: anything else that fits a warm, realistic lawn-care game.

For **each** direction, in `art-source/GUI/Concepts/<Direction>/`:

- `HUD_PC.png` (1920 × 1080) and `HUD_Phone.png` (2340 × 1080): in play, over one of your renders
  of a front lawn, with the HUD, a look-at prompt, the dot and the job tracker.
- `Computer_Jobs.png` and `Computer_Orders.png` (1920 × 1080): the shop computer's screen, with
  the Jobs app showing three job cards, and the Orders app on the Mowers tab with four item cards
  in different states (a price, Bought, Sell, Locked).
- `PayBreakdown.png` (1920 × 1080): the after-job pay breakdown.
- `Sheet.png` (2048 × 2048): the direction at a glance, with the palette (hex values), button
  states, a panel, a card, tabs, a toast, the prompt in its normal and red states, and a few
  icons.

Use the real words from the game in the mock-ups: the screen list above, with tool names from
the item list below.

## Part 2: The GUI art kit (direction 1, "Field tablet")

Everything in `art-source/GUI/Kit/`, `art-source/GUI/Icons/`, `art-source/GUI/Items/` and
`art-source/GUI/Computer/`. **Every image is at most 1024 px on its longest side**: Roblox shrinks
anything bigger. All PNG, transparent background unless a piece says otherwise.

### Frames and buttons (`Kit/`): 9-slice pieces

These stretch to any size, so each one needs corners that don't stretch. Draw them at 2× (for
example, a 24 px corner radius drawn as 48 px), and list each piece's **slice centre** (the
rectangle that stretches, in pixels: left, top, right, bottom) in `manifest.json`.

- `Panel.png`: a window, with a slightly darker title band along the top.
- `Card.png`: an item or job card inside a panel.
- `Button_Primary.png`, `Button_Money.png`, `Button_Danger.png`, `Button_Neutral.png`,
  `Button_Disabled.png`: green, golden yellow, red, grey-green and flat grey. Each comes with a
  `_Pressed` version that is a little darker and set 2 px lower.
- `Tab.png` and `Tab_Active.png`.
- `ProgressTrack.png` and `ProgressFill.png`: the XP bar, the job timer and curb appeal.
- `Toast.png`: the background for the short messages.
- `Prompt.png` and `Prompt_Blocked.png`: the look-at prompt under the dot, normal and red.
- `Tooltip.png`.
- `HudPanel.png`: the background behind the money and level in the corner, a little
  see-through.
- `MenuButton.png`: the Truck, Guide and Crew buttons on the left, with room for the key badge.
- `KeyBadge.png`: the small square that shows a key ("T", "E"; the game writes the letter).
- `TouchButton.png` (256 × 256): the big round button phones tap in place of E.
- `Reticle.png`, `Reticle_Active.png` and `Reticle_Blocked.png` (64 × 64): the dot in the middle
  of the screen, its state when it's on something usable, and its state when the thing can't be
  used.

### Icons (`Icons/`): 128 × 128, one colour

Plain **white** glyphs on transparent backgrounds (the game tints them). Use the same stroke
weight and corner style throughout, with no text, readable at 32 px:

- **HUD and menus**: `Money` (a coin or dollar bill), `Level` (a star), `CurbAppeal` (a house
  front with a sparkle), `Truck`, `Guide` (an open book), `Crew` (two people), `Close` (×),
  `Back` (an arrow), `Check`, `Lock`, `Timer`, `Damage` (a warning triangle), `Info`.
- **The computer apps**: `Jobs` (a clipboard), `Orders` (a box), `Business` (a storefront),
  `Sell` (a price tag).
- **Shop tabs**, one per category: `Cat_Mower`, `Cat_Trimmer`, `Cat_Rake` (rakes and blowers),
  `Cat_Edger`, `Cat_HedgeTrimmer`, `Cat_HandTool` (planting and weeding), `Cat_Pruning`,
  `Cat_Watering`, `Cat_Digging`, `Cat_Hauling` (barrows and carts), `Cat_LawnCare`,
  `Cat_Protection` (gloves), `Cat_Supplies`, `Cat_Decorations`, `Cat_Truck`, `Cat_Trailer`,
  `Cat_Business`.
- **Tool condition**: `Fuel` (a jerry can), `Tire`, `Blade`, `Spool` (trimmer line), `Wrench`
  (broken), `Sharp`.
- **Tiers**: `Tier_Homeowner`, `Tier_Serious` and `Tier_Pro` (small badges: one, two and three
  chevrons or leaves).

### Item icons (`Items/`): 512 × 512, full colour

One icon per item, named **exactly** with the item's id (`Items/ReelMower.png`). These are the
pictures on the shop cards and in the Truck menu.

- **Render them in Blender from your own models** in `model-source/HighPoly/`: the same
  three-quarter view from the front-left and a little above, the same soft studio light (a warm
  key and a cool rim), a soft contact shadow, and a transparent background. Every item is framed
  to fill about 80% of the canvas, so small tools and big machines read at the same size.
- Six tools come from a third-party kit and aren't in your packs: `GasPushMower`, `RidingMower`,
  `ZeroTurnMower`, `ElectricTrimmer`, `GasTrimmer` and `OldRake`. Their look is shown in
  `model-source/RevisedLawnModels/OriginalKitPreviews/01_Equipment.png` and `02_Trimmers.png`.
  Make quick render-only models that match those, and render them the same way. Don't add those
  models anywhere else.
- **Tools** (73), by shop tab:
  - **Mowers**: `ReelMower` (Reel Push Mower), `GasPushMower` (Gas Push Mower), `SelfPropelledMower`
    (Self-Propelled Mower), `RidingMower` (Riding Mower), `ZeroTurnMower` (Zero-Turn Mower),
    `CommercialZeroTurn` (Commercial Zero-Turn), `StandOnMower` (Stand-On Mower),
    `CommercialReelMower` (Greens Reel Mower)
  - **Trimmers**: `GardenShears` (Grass Shears), `ElectricTrimmer` (Electric String Trimmer),
    `GasTrimmer` (Gas String Trimmer), `Brushcutter` (Brush Cutter), `StraightShaftTrimmer` (Pro
    Straight-Shaft Trimmer)
  - **Rakes & Blowers**: `OldRake` (Leaf Rake), `WideRake` (Wide Leaf Rake), `LeafBlower` (Leaf
    Blower), `BackpackBlower` (Backpack Blower)
  - **Edgers**: `HalfMoonEdger` (Half-Moon Edger), `ElectricEdger` (Electric Edger),
    `WalkBehindEdger` (Walk-Behind Edger), `GasStickEdger` (Pro Stick Edger)
  - **Hedge Tools**: `HandHedgeShears` (Hedge Shears), `ElectricHedgeTrimmer` (Electric Hedge
    Trimmer), `CordlessHedgeTrimmer` (Cordless Hedge Trimmer), `GasHedgeTrimmer` (Gas Hedge
    Trimmer), `ArticulatingHedgeTrimmer` (Articulating Hedge Trimmer)
  - **Planting & Weeding**: `HandTrowel` (Hand Trowel), `HandTransplanter` (Hand Transplanter),
    `HandCultivator` (Hand Cultivator), `DandelionWeeder` (Dandelion Weeder), `Dibber` (Dibber),
    `StirrupHoe` (Stirrup Hoe)
  - **Pruning**: `BypassPruners` (Bypass Pruners), `AnvilPruners` (Anvil Pruners), `FloralSnips`
    (Floral Snips), `Loppers` (Loppers), `PruningSaw` (Pruning Saw)
  - **Watering**: `GardenHoseWand` (Garden Hose & Wand), `WateringCan` (Watering Can)
  - **Gloves**: `NitrileGloves` (Work Gloves), `ChemicalGloves` (Chemical-Resistant Gloves)
  - **Digging**: `RoundPointShovel` (Round-Point Shovel), `GardenSpade` (Garden Spade), `Broadfork`
    (Broadfork), `DiggingFork` (Digging Fork), `BowRake` (Bow Rake), `Mattock` (Mattock)
  - **Barrows & Carts**: `SingleWheelbarrow` (Wheelbarrow), `SingleWheelbarrowFlatFree` (Flat-Free
    Wheelbarrow), `DualWheelbarrow` (Two-Wheel Wheelbarrow), `PolyCart` (Yard Cart)
  - **Lawn Care**: `BroadcastSpreader` (Broadcast Spreader), `BackpackSprayer` (Backpack Sprayer),
    `StandOnAerator` (Stand-On Aerator), `TowBehindAerator` (Tow-Behind Aerator), `SlitOverseeder`
    (Slit Overseeder), `PowerRakeDethatcher` (Power Rake), `RideOnSpreaderSprayer` (Ride-On
    Spreader Sprayer), `SoilProbe` (Soil Probe)
  - **Supplies**: `ToolBucket` (Tool Bucket), `GasCan` (Gas Can), `MixGasCan` (Mix Gas Can),
    `TrimmerLine` (Trimmer Line), `FootPump` (Foot Pump), `ElectricInflator` (Electric Inflator),
    `AirCompressor` (Air Compressor), `TirePatchKit` (Tire Patch Kit), `SpareTire` (Spare Tire),
    `WrenchSet` (Wrench Set), `BladeFile` (Blade File), `SharpeningStone` (Sharpening Stone),
    `BenchGrinder` (Bench Grinder), `SpareMowerBlade` (Spare Mower Blade)
- **Decorations** (24): `PicketFenceSection`, `StoneEdgingSection`, `PaverPathSection`,
  `MulchBedSection`, `BoxwoodShrub`, `HydrangeaBush`, `JapaneseMaple`, `TerracottaPlanter`,
  `RaisedGardenBed`, `BirdBath`, `TieredFountain`, `GardenArbor`, `GardenBench`, `PatioSet`,
  `FirePit`, `Mailbox`, `LampPost`, `SolarPathLight`, `BirdFeeder`, `Birdhouse`, `PinkFlamingo`,
  `GardenWindmill`, `GardenGnome`, `FlowerPatch`.
- **Trucks**: `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck`. **Trailers**:
  `UtilityTrailer`, `LandscapeTrailer`, `EquipmentTrailer`. **Buildings**: `Shed`, `Garage`,
  `SmallOffice`, `EquipmentYard`. Render vehicles and buildings from the same angle, further
  back, with tailgates and doors closed.

That's **108 item icons**.

### The shop computer (`Computer/`)

- `Wallpaper.png` (1024 × 576): the desktop background, a calm, slightly blurred render of a
  freshly striped lawn, so the app windows and icons read on top of it.
- `App_Jobs.png`, `App_Orders.png`, `App_Business.png`, `App_Crew.png` (256 × 256): full-colour
  app icons like a phone's (a rounded square with a picture), matching the one-colour `Jobs`,
  `Orders`, `Business` and `Crew` glyphs.
- `Taskbar.png`: a 9-slice for the strip along the bottom of the screen.

### Previews and manifest

- `art-source/GUI/Previews/`: the same five screens as the concepts (`HUD_PC`, `HUD_Phone`,
  `Computer_Jobs`, `Computer_Orders`, `PayBreakdown`), built only from the finished kit, icons and
  item icons, at the same sizes. They prove the pieces fit together.
- `art-source/GUI/Previews/ItemIcons_ContactSheet.png`: all 108 item icons in a grid with their
  ids under them.
- `art-source/GUI/manifest.json`:
  - every file with its size and what it's for;
  - the 9-slice centres;
  - the palette as hex values, with the role of each colour (panel, card, accent, money, danger,
    disabled, text, subtext), so the game's code can switch to it;
  - for the item icons, the id each file is for.
- `art-source/GUI/Source/`: the Blender scenes and design source files, so the art can be changed
  later.

## Rules

- Don't change `assets/`, `src/`, `model-source/` or anything outside `art-source/GUI/`. The local
  Claude session uploads the art to Roblox as Big Dink Studios and wires it into the game.
- No brand names, real logos or trademarks. Finished assets have no text in them at all; the
  concept mock-ups use Fredoka for theirs.
- Everything must read on a **phone held sideways**: test every mock-up by viewing it at 50%.
  Buttons must look tappable at 44 px tall, and icons must be clear at 32 px.

## Done when

- [ ] Three concept directions, each with the five mock-ups and a sheet, in
      `art-source/GUI/Concepts/`.
- [ ] The full kit in direction 1: every frame and button (with pressed versions and slice
      centres), every glyph, the computer wallpaper, app icons and taskbar.
- [ ] 108 item icons named exactly by id, rendered the same way, with the contact sheet.
- [ ] Every final image is at most 1024 px on its longest side, with no text in it.
- [ ] The previews show the five screens built from the finished kit.
- [ ] `manifest.json` lists every file, the slice centres, the palette with roles, and the item
      ids.
- [ ] Nothing outside `art-source/GUI/` changed.
