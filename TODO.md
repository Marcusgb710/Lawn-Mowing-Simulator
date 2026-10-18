# What's left — Lawn Mowing Simulator

Last updated: 2026-10-18

## Done so far

- **Rojo is set up and running.** `rokit install` pulled the project's tool versions (Rojo 7.7.1,
  Selene 0.31.0, StyLua 2.6.0). The Studio plugin was updated from 7.4.4 to 7.7.1 to match the
  server (a 7.4 plugin can't talk to a 7.7 server: "Can't parse JSON"). `rojo serve` is running and
  Studio is connected.
- **The game is published** as "Lawn Mowing Simulator" under **Big Dink Studios** (universe
  10771693515, place 73083404631437). It's private, with Team Create on. The old local copy at
  `~/Documents/LawnMowingSimulator.rbxl` is out of date; open the game from Roblox instead.
- **The mobile kit is uploaded to Roblox.** All 60 meshes and the shared PBR textures went up
  under **Big Dink Studios** through File → Import 3D (scale unit: meters). The importer also
  created a Model asset named `LM_Mobile_Asset_Workshop` in the group's inventory.
- **The kit is in the game, in git and synced by Rojo:**
  - `assets/Kit/*.rbxm` → `ReplicatedStorage.Assets.Kit`: all 34 kit assets, scaled to real size,
    anchored, no collision, pivot on the ground under the asset, facing -Z (the front).
  - `assets/Tools/*.rbxm` → `ReplicatedStorage.Assets.Tools`: the kit equipment now replaces six
    placeholder shop tools.

    | Item id | Kit model |
    | --- | --- |
    | `GasPushMower` | `Mower_Push_21in` |
    | `RidingMower` | `Mower_LawnTractor_42in` |
    | `ZeroTurnMower` | `Mower_ZeroTurn_52in` |
    | `ElectricTrimmer` | `Trimmer_Battery` |
    | `GasTrimmer` | `Trimmer_Petrol` |
    | `OldRake` | `Prop_Rake` |

    Checked in Play mode: the push mower is held by its handlebar, upright, in front of the player.
    The trimmer is held at an angle with the head out front. Rack and truck-bed displays stand
    upright on the ground.
- **Fixed how tools are held, placeholders included.** The code assumed a held handle's +Y points
  forward. It actually points up, with the handle's front (-Z) forward, so every placeholder tool
  was held standing on end above the player's head. `Placeholders.tool` now turns the grip and
  `Assets.toolDisplay` uses the grip as-is, so placeholders look the same on the rack but are held
  correctly. `Assets.toTool` also prefers a part named `Handle` over `PrimaryPart`, because Rojo's
  MeshPart sync drops `PrimaryPart`.
- **Kit pipeline scripts** (in `scripts/`):
  1. `OrganizeLawnKit.luau`: paste into the Studio command bar after a fresh Import 3D of
     `LawnMowing_AllAssets.gltf`. It flattens, scales and grounds the kit into
     `ServerStorage.LawnKitExport`. Save the place afterwards.
  2. `lune run scripts/export-kit` writes `assets/Kit/*.rbxm` from the saved place. Delete
     `ServerStorage.LawnKitExport` in Studio afterwards.
  3. `lune run scripts/build-kit-tools` builds `assets/Tools/*.rbxm` from `assets/Kit`. To tune a
     grip or add a tool, edit `TOOLS` in that file and re-run; Rojo syncs it right away.

  Lune 0.11 is installed globally with Rokit (`~/.rokit/bin/lune`).

## Models still needed

Everything below still uses a block placeholder. Name each model after its id and drop it in the
matching `assets/` folder (see the README section *Swapping in real models*).

| Folder | Still a placeholder | Kit stand-in you could use |
| --- | --- | --- |
| `Tools` (Mower) | `ReelMower` (the starter tool), `SelfPropelledMower` | Push mower for `SelfPropelledMower` |
| `Tools` (Trimmer) | `GardenShears`, `Brushcutter` | Petrol trimmer for `Brushcutter` |
| `Tools` (Rake) | `WideRake`, `LeafBlower`, `BackpackBlower` | Rake for `WideRake` |
| `Tools` (Edger) | `HalfMoonEdger`, `ElectricEdger`, `GasStickEdger`, `WalkBehindEdger` | Shovel for `HalfMoonEdger` |
| `Tools` (HedgeTrimmer) | `HandHedgeShears`, `ElectricHedgeTrimmer`, `CordlessHedgeTrimmer`, `GasHedgeTrimmer` | none |
| `Trucks` | `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck` | none. Each needs a `BedArea` part with a `Slots` attribute |
| `Trailers` | `UtilityTrailer`, `LandscapeTrailer` | none. Each needs a `BedArea` part |
| `Buildings` | `Shed`, `Garage`, `SmallOffice` | none |
| `Props` | `House`, `FlowerPatch` (parts named `Flower` wilt), `GardenGnome` | none |

To use a stand-in, add a line to `TOOLS` in `scripts/build-kit-tools.luau` and re-run it. Reusing
a model for two tiers makes them look identical, so consider recoloring the SurfaceAppearance or
scaling it.

Not uploaded yet: `Textures/Lawn_Uncut_Color.png`, `Textures/Lawn_Mown_Color.png` and
`Textures/Soil_Color.png` from the kit. They're 512×512 tiling lawn and soil color maps, and the
glTF doesn't reference them, so the importer skipped them. Upload them with **Asset Manager → Bulk
Import** (as Big Dink Studios), then use them as MaterialVariants or Textures on the lawn tiles.

## Code work to use the rest of the kit

The rest of the kit is in `ReplicatedStorage.Assets.Kit`, but nothing uses it yet. These need
changes in `src/server/Services/LawnService.luau`:

- [ ] **Grass** (`_buildGrass`): each 4×4 tile is one tall green block that shrinks when mowed.
      Swap in `Grass_Tall_A/B` clumps that switch to `Grass_Short_A/B` when mowed, and use the
      `_LOD` versions away from the player. Mowing state is already per tile; ideally spawn the
      clumps on the client so the server only sends tile state. Keep mesh grass to the visible
      yard and use the lawn texture for distant ground.
- [ ] **Weeds** (`_buildWeeds`): 3 green blocks plus a ball. Swap in `Weed_Dandelion`,
      `Weed_Broadleaf`, `Weed_Clover`, `Weed_Thistle` and `Weed_DryTuft`. The whacking code shrinks
      parts using their `OriginalSize` attribute, so set it on the mesh parts too.
- [ ] **Hedges** (`_buildHedges`): one block trimmed from about 5×6×4 down to 4×3.5×2.5. Use
      `Shrub_Rounded` scaled to the start size and scale it down as it's trimmed.
- [ ] **Edges** (`_buildEdges`): place `Curb_Concrete_1m` along the sidewalk and driveway and
      `Grass_EdgeStrip_1m` as the overgrowth that gets edged away.
- [ ] **Leaves** (`_buildLeaves`): the kit has no leaf pile. `Grass_Clippings_Pile` could stand in;
      drop a `Prop_YardWasteBag` when a pile is cleared.
- [ ] **Decoration**: `Fence_Cedar_2m`, `Paver_Concrete_40cm`, `Rock_Field_A/B`, `Prop_WheelieBin`,
      `Prop_TrafficCone`, `Prop_FuelCan_5L`, `Prop_GardenHose_Coil` and `Prop_Shovel` for yards
      and business plots.
- [ ] **Moving parts**: wheels, cutter rotors, trimmer spools, the tractor steering wheel and the
      zero-turn lap bars are separate meshes but welded rigid right now. Weld them with Motor6Ds or
      HingeConstraints and spin them on the client while mowing.
- [ ] **Riding mowers**: `RidingMower` and `ZeroTurnMower` are held by the steering wheel or lap
      bars like a hand tool, the same as the placeholders. To look right they need a ride setup:
      a seat, a sit animation, and the player moving the mower.
- [ ] **Grip polish**: the push mower floats about 0.6 studs and the trimmer head about 1.3 studs
      above the ground, because the tool-hold pose keeps the hand at shoulder height. Lower the
      grips in `scripts/build-kit-tools.luau`, or add a push/hold animation.

## Before release

- [ ] Turn on *Game Settings → Security → Enable Studio Access to API Services* so progress saves
      when testing in Studio. The game is already published under Big Dink Studios.
- [ ] Make the experience public when it's ready to play.
- [ ] Set max players to 12 or fewer (Game Settings → Places). The placeholder town has 12 plots.
- [ ] **Test on a real phone.** Prompts and tools already use ProximityPrompts and
      `Tool.Activated`, so touch should work, but hold-to-use tools and the carry/load flow need
      checking. Profile frame rate with grass on screen. The kit makes no device FPS promise.
- [ ] **Sounds**: the kit has none. Mower engine, trimmer, rake and blower, cash register, UI
      clicks.
- [ ] **Animations**: pushing and holding poses for mowers and trimmers.
- [ ] **UI art**: shop and hotbar icons for every item, a game icon and thumbnails.

## Known quirks

- While Rojo is connected, Studio's Output fills with
  `[Rojo-Warn] Ignoring change for instance … as it is unknown to Rojo` every time you change
  something. These come from the MeshPart models Rojo syncs through its fallback path, and they're
  harmless.
- Rojo drops `Model.PrimaryPart` on synced MeshPart models, so code shouldn't rely on it for kit
  assets. Use the pivot, which is set, or find parts by name.

## Daily workflow reminder

```sh
cd ~/Desktop/"Lawn Mower"/Lawn-Mowing-Simulator
rojo serve
```

Then in Studio, open "Lawn Mowing Simulator" from Roblox (Big Dink Studios) and click Plugins →
Rojo → Connect. It's a Team Create place, so changes made directly in Studio save to the cloud.
