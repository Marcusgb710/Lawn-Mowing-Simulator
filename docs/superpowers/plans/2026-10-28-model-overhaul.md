# Model Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the story's statues with Roblox avatar rigs, give the lawn a real texture and tufts, and build the repeatable pipeline that swaps the game's hardware, vehicles and buildings for curated Creator Store meshes.

**Architecture:** A JSON manifest (`assets/manifest/models.json`) records every replaced model's source and fit; a generated Studio command-bar script inserts, cleans, normalises and stages them; `export-models` writes the `.rbxm` files as today; a Lune gate (`check-models`) enforces the model contract. People are built at startup by a server service from a cast config and parented where `Assets.story` already looks. Grass gains a tiling texture on the turf part, translucent painted stripes, and tuft stamps on the shells.

**Tech Stack:** Roblox/Luau (Rojo 7.7.1, rokit: lune 0.11.0, selene 0.31.0, StyLua 2.6.0), Python 3 (scripts), Roblox Studio driven from the chat.

**Spec:** `docs/superpowers/specs/2026-10-28-model-overhaul-design.md`

## Global Constraints

- Every id in `Config/Tools.luau`, `Items.luau`, `Decorations.luau` and the Story folder keeps its id; nothing is renamed.
- Models keep the contract in the spec's Constraints: origin at the ground centre, front toward −Z, `Handle` + grips for tools, `Root` at (0, 0.5, 0) for everything else, `BedArea` on trucks and trailers, `<Id>__Body` on trucks, `<Id>__Ramp` + two `BaySpot` on EquipmentTrailer, `Porch` + `Driveway` on the house.
- No spend: free Store assets, free catalog items, Roblox-owned animation ids, no uploads that cost Robux.
- Part budgets (`check-models`): hand tool 12, long tool 20, machine 120, barrow or cart 40, supply 12, truck 160, trailer 80, shed 150, house 300, big building 400, decoration 40.
- Gates after every task: `lune run scripts/check-models`, `lune run scripts/check-mowing`, `lune run scripts/check-gui`, `lune run scripts/check-story`, `selene src`, `stylua --check src` (redirect its output to a file; piping it crashes in Git Bash), `rojo build default.project.json -o <scratch>.rbxl`. Python scripts run with `python` (Windows).
- Comments and docs in the repo's voice: plain sentences, no em dashes, no `##` headers in chat.
- Never commit anything under `.superpowers/`, a test driver, or a Studio place file.

## Review Focus

- A Store asset that is a "set" (several child Models): the importer must keep exactly the child the manifest names and nothing else, and fail loudly when the name is wrong (Task 1 tests this).
- A truck whose `__Body` is a textured MeshPart: `Premium.applyPaint` tints through `SurfaceAppearance.Color`; `check-models` must require `__Body` on every truck entry (Task 2).
- A cast entry whose catalog item goes off-sale: `CreateHumanoidModelFromDescription` throws; CastService must catch per entry and leave that id to the placeholder (Task 4).
- No image assets uploaded yet (`GrassArt` ids are 0): GrassPaint must draw exactly as today, with one warning, not a blank lawn (Task 7).
- A lawn wider than 256 studs (pixels per stud halved): tuft stamps and texture tiling must scale with the image, not with the stud count (Task 7).

---

### Task 1: The manifest and the generated importer

**Files:**
- Create: `assets/manifest/models.json`
- Create: `scripts/generate-import.py`
- Create: `scripts/ImportStoreModels.template.luau`
- Create (generated, committed): `scripts/ImportStoreModels.luau`
- Create: `scripts/test_generate_import.py`
- Modify: `assets/README.md` (a "Store models" section)

**Interfaces:**
- Produces: `assets/manifest/models.json` = `{ "version": 1, "complete": false, "models": [Entry...] }`. Entry fields exactly as the spec's section 3: `id`, `folder` (`Tools`, `Trucks`, `Trailers`, `Buildings`, `Props`, `Decorations`, `Story`), `source` (`{kind: "store", assetId, name, creator}` | `{kind: "blender", file}` | `{kind: "kept"}`), optional `keep`, `facing` (`"+X"|"-X"|"+Z"|"-Z"`, default `"-Z"`), `up` (`"+Y"` only for now), `fit` (`{axis: "height"|"width"|"length", studs}`), `handle` (`{position, size}`) or `handlePart` (mesh name), `grips` (`{left, right}`), `parts` (`{meshName: {rename, collide}}`), `markers` (`[{name, position, orientation, attributes}]`), `boxes` (`[{name, position, size}]`), `synth` (`[{name, position, size, material, color, hinge}]`), `collide` (bool), `strip` (`["Class:Name"]`), `budget` (int).
- Produces: `python scripts/generate-import.py [manifest]` writes `scripts/ImportStoreModels.luau` and prints `N models`. `--check` validates the manifest and writes nothing.
- Produces: the generated script, pasted into Studio, stages every non-kept entry under `ServerStorage.ModelImport.<folder>.<id>` and prints one line per entry: `ok <id> parts=<n> size=<x>x<y>x<z>` or `FAIL <id> <reason>`.

- [ ] **Step 1: Write the failing generator test**

`scripts/test_generate_import.py` (unittest): a manifest with one store entry (GasPushMower, keep "Mower_Red", facing "+X", fit height 3.7, handle, grips, parts rename) and one kept entry. Assert: `generate(manifest)` returns Lua text containing `id = "GasPushMower"`, `keep = "Mower_Red"`, `facing = "+X"`, `fit = { axis = "height", studs = 3.7 }`, the rename, and no entry for the kept id; `validate(manifest)` returns `[]`; a manifest with `facing = "+Y"` or a missing `fit` returns one error per problem naming the id.

- [ ] **Step 2: Run it to see it fail**

Run: `python -m unittest scripts/test_generate_import.py -v`  Expected: ImportError / failures.

- [ ] **Step 3: Implement `generate-import.py`**

`validate(manifest: dict) -> list[str]`, `generate(manifest: dict, template: str) -> str`, `main()`. Mirror `generate-prepare.py`'s `num`, `vec`, `lua_value`, `attributes` helpers (copy them, do not import that script). The template holds `--@MODELS@`.

- [ ] **Step 4: Write the importer template**

`scripts/ImportStoreModels.template.luau`, for the Studio command bar, `--!nocheck`. One `MODELS` table. For each entry, in order: `insert` (`game:GetObjects("rbxassetid://" .. id)`, wrap several objects in a Model), `keepOne` (when `keep` is set: keep the child Model with that name, destroy siblings; FAIL when it is not there), `clean` (destroy `BaseScript`, `ModuleScript`, `Sound`, `ParticleEmitter`, `Fire`, `Smoke`, `Sparkles`, `LayerCollector`, `Humanoid`, `Constraint`, `Motor6D`, `WeldConstraint`, `BodyMover` descendants; turn `Seat`/`VehicleSeat` into `Part` by cloning size, cframe, colour and material; apply `strip` by `Class:Name`), `normalise` (anchor everything; rotate about Y so `facing` becomes −Z; uniform `Model:ScaleTo` so the bounding box's `fit.axis` is `fit.studs`; `PivotTo` so the bounding box's bottom centre is the origin), `contract` (Tools: an invisible `Handle` part (`Transparency 1`, `CanCollide false`, size from `handle.size`) at `handle.position`, or rename `handlePart`; `GripLeft`/`GripRight` attachments on the Handle from `grips`. Others: an invisible `Root` part at (0, 0.5, 0) as PrimaryPart. Then `parts` renames and per-part `collide`, `markers` as Attachments on the Handle/Root with `orientation` and attributes, `boxes` as invisible non-colliding Parts, `synth` as plain Parts with `PivotOffset` at `hinge`, model-wide `collide`), `stage` (`ServerStorage.ModelImport.<folder>.<id>`, replacing an older copy). Wrap each entry in `pcall` and print the ok/FAIL line. End with a summary line `staged N, failed M`.

- [ ] **Step 5: Generate, and make sure the generated script compiles**

Run: `python scripts/generate-import.py` then `lune run scripts/check-models` (Task 2 adds the compile check; until then: `lune -e "require('@lune/luau').compile(require('@lune/fs').readFile('scripts/ImportStoreModels.luau'))"`). Expected: compiles.

- [ ] **Step 6: Seed the manifest**

`assets/manifest/models.json` with `version 1`, `complete false`, and `models` holding one `kept` entry per id that the overhaul will not touch yet is not needed; seed with an empty `models` list plus the GasPushMower example from the spec marked `"source": {"kind": "store", "assetId": 18744991009, "name": "(MQ) Internal Combustion Push Mower Set", "creator": "MinecraftPro97k"}` so the generator has one real entry to render. Document the format in `assets/README.md`.

- [ ] **Step 7: Run the tests and gates, commit**

`python -m unittest scripts/test_generate_import.py -v`, then the gates. Commit: `Add the Store model manifest and its generated importer`.

### Task 2: The model gate

**Files:**
- Create: `scripts/check-models.luau`
- Create: `scripts/check-models-fixtures.luau` (writes fixtures into a temp dir, used by the self-test)

**Interfaces:**
- Consumes: `assets/manifest/models.json` (Task 1), `scripts/ImportStoreModels.luau`.
- Produces: `lune run scripts/check-models [--assets DIR] [--manifest FILE]` prints `Models OK` and exits 0, or `FAIL <id>: <reason>` lines and exits 1. `lune run scripts/check-models --self-test` writes fixtures and asserts the expected failures.

- [ ] **Step 1: Write the self-test first**

`--self-test` builds, with `@lune/roblox`, in a temp dir: (a) `Tools/GoodTool.rbxm`: a Model with a `Handle` part at (0, 1.5, 0), one visible part, bottom at y = 0; (b) `Tools/NoHandle.rbxm`: same without `Handle`; (c) `Trucks/NoBody.rbxm`: a Model with `Root` at (0, 0.5, 0) and `BedArea`, no `__Body`; (d) `Props/Scripted.rbxm`: a Model with a `Script` inside; (e) `Tools/Floating.rbxm`: bottom at y = 2. A matching manifest lists them (GoodTool fit height 3 with a 3-tall part; the others arbitrary). Assert the check reports exactly: NoHandle "no Handle", NoBody "no NoBody__Body", Scripted "has a Script", Floating "pivot is 2.0 above the ground", and nothing for GoodTool. Run: `lune run scripts/check-models --self-test`  Expected: fails until Step 2.

- [ ] **Step 2: Implement the checks**

For every manifest entry whose `source.kind` is not `kept`: the file exists; `Handle` (Tools) or `Root` (others) exists; bottom of the bounding box within 0.1 of y = 0 (compute from parts' CFrames and sizes, excluding `Transparency == 1` parts for the visible test only); when `fit` is set, that axis within 10% of `fit.studs`; no `BaseScript`/`ModuleScript`/`Sound`; at least one part with `Transparency < 1`; parts ≤ `budget` (default per folder: Tools 120, Trucks 160, Trailers 80, Buildings 400, Props 300, Decorations 40, Story 300); Trucks: `BedArea` and `<id>__Body`; Trailers: `BedArea`; `EquipmentTrailer`: `EquipmentTrailer__Ramp` and two `BaySpot`; `Props/House`: `Porch` and `Driveway`. For every `.rbxm` under `assets/` (manifest or not): no scripts, no sounds. Then: `scripts/ImportStoreModels.luau` compiles (`@lune/luau`). When `complete` is true: every id in `Config/Tools.luau`, `Items.luau` (trucks, trailers, buildings) and `Decorations.luau` has a file or a kept entry; read the ids with the same regex `cast-check.py` style (`id = "..."`), from the Luau source as text.

- [ ] **Step 3: Run on the real repo**

`lune run scripts/check-models`  Expected: `Models OK` (the manifest's one store entry has no file yet: a store entry with no file is reported as `pending <id>` and does not fail until `complete` is true).

- [ ] **Step 4: Commit**

`Gate the model contract with check-models`.

### Task 3: The cast config and its catalog check

**Files:**
- Create: `src/shared/Config/Cast.luau`
- Create: `scripts/cast-check.py`
- Modify: `scripts/check-story.luau` (require Cast, assert every story NPC id has an entry and every entry has `pose` in `Cast.Poses`)

**Interfaces:**
- Produces: `Cast.People: { [id]: Person }` for `NPC_Gloria`, `NPC_Chad`, `NPC_Edna`, `NPC_June_Sitting`, `NPC_June_Standing`, `NPC_Sam_Casual`, `NPC_Sam_TurfKing`, `NPC_Judge1`, `NPC_Judge2`. `Person = { name: string, body: { skin: Color3, heightScale: number, widthScale: number, headScale: number, proportion: number }, hair: number?, hairColor: Color3?, hat: number?, face: number?, shirt: number?, pants: number?, tshirt: number?, layered: { { id: number, type: string, order: number } }, pose: string, seat: Vector3? }`. `Cast.Poses: { [name]: { id: string, looped: boolean } }` with `Idle = "rbxassetid://507766666"`, `Walk = "rbxassetid://507777826"`, `Sit = "rbxassetid://2506281703"`, `Wave = "rbxassetid://507770239"`, `Point = "rbxassetid://507770453"`, `Inspect = Point`, `Note = Idle`. `Cast.describe(person): { [string]: any }` returns the HumanoidDescription property table (`HairAccessory`, `HatAccessory`, `Shirt`, `Pants`, `Face`, `GraphicTShirt`, `HeightScale`...) as strings and numbers, no Instances (Lune-testable).
- Consumes: the catalog items found during design (Gloria: hair 376526888 recoloured (205, 205, 205), shirt 398634295, pants 398634487; Chad: hair 376524487, hat 607702162, shirt 398635081, pants 382537950) as starting points; the brief in `alphainstructions/instructions37.md` for the rest.

- [ ] **Step 1: Write the check-story assertions**

Extend `scripts/check-story.luau`: every id in `{ NPC_Gloria, NPC_Chad, NPC_Edna, NPC_June_Sitting, NPC_June_Standing, NPC_Sam_Casual, NPC_Sam_TurfKing, NPC_Judge1, NPC_Judge2 }` has a `Cast.People` entry; each entry's `pose` is a key of `Cast.Poses`; `Cast.describe(Cast.People.NPC_Chad).HatAccessory == "607702162"`; `NPC_June_Sitting.seat` is a Vector3-like table `{ x, y, z }` (Lune has no Vector3: store seats as `{ 0, 1.6, 0 }` tables and convert in CastService). Run: `lune run scripts/check-story`  Expected: FAIL (no Cast yet).

- [ ] **Step 2: Write `Cast.luau`**

Nine entries from the brief. Free items only; Roblox-made where they fit; any creator when identity needs it (spec ruling 3). Find ids with `https://catalog.roblox.com/v1/search/items/details?Keyword=<words>&MaxPrice=0&Limit=10` (add `&CreatorTargetId=1&CreatorType=User` for Roblox-made). Chad and Sam_TurfKing: a purple shirt (or `tshirt` reserved for the uploaded crown graphic, id 0 until uploaded) and a visor or cap; June: a sun hat if one is free, grey hair by `hairColor`; Edna: short curly hair recoloured grey, a floral or bright top; Judge1: a jacket-and-tie classic shirt; Judge2: a hat with a flower if free, else a sun hat. Body scales within 0.9 to 1.1.

- [ ] **Step 3: Write `cast-check.py`**

Parses `Cast.luau` with regexes for `hair = N`, `hat = N`, `shirt = N`, `pants = N`, `face = N`, `tshirt = N`, `id = N` inside `layered`. For each id > 0: GET `https://economy.roblox.com/v2/assets/<id>/details` (no key). Assert `IsForSale` or `IsPublicDomain` true, `PriceInRobux` is 0 or null, `IsLimited`/`IsLimitedUnique` false, `AssetTypeId` matches the slot (hair 41, hat 8, shirt 11, pants 12, face 18, tshirt 2, layered 64 to 72). Print `Cast OK` or every failure with the id, name and creator; exit 1 on failure. Rate limit: 0.3 s between calls.

- [ ] **Step 4: Run both checks, commit**

`lune run scripts/check-story`, `python scripts/cast-check.py`, gates. Commit: `Describe the story's cast as catalog outfits`.

### Task 4: CastService builds the rigs

**Files:**
- Create: `src/server/Services/CastService.luau`
- Modify: `src/shared/Assets.luau` (`Assets.story` comment: rigs come from CastService; `STORY_STAND_INS` unchanged)
- Modify: `src/server/init.server.luau` (or wherever services start: start CastService before GloriaService, WorldService and GrandmaJune)
- Delete: `assets/Story/NPC_Gloria.rbxm`, `NPC_Chad.rbxm`, `NPC_Edna.rbxm`, `NPC_June_Sitting.rbxm`, `NPC_June_Standing.rbxm`, `NPC_Sam_Casual.rbxm`, `NPC_Sam_TurfKing.rbxm`, `NPC_Judge1.rbxm`, `NPC_Judge2.rbxm`, `TurfKingTruck.rbxm`
- Modify: `default.project.json` (`ReplicatedStorage.Assets.Story` keeps its `$path` entries for the judges only if they still exist as files; otherwise drop those two lines, since CastService parents rigs there at runtime)
- Modify: `src/shared/Placeholders.luau` only if a deleted statue leaves a story id with no PROP_BUILDER (there is one for NPC_Chad, NPC_Judge1, NPC_Judge2 and Gloria through STORY_STAND_INS; add simple block builders for NPC_Edna, NPC_June_Sitting, NPC_June_Standing, NPC_Sam_Casual, NPC_Sam_TurfKing if missing, so the fallback never errors)

**Interfaces:**
- Consumes: `Cast.People`, `Cast.describe`, `Cast.Poses` (Task 3).
- Produces: `CastService:Init()` builds every rig synchronously at startup (`Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)` inside `pcall` per id; on failure `warn("CastService: <id> ...")` and skip), applies `hairColor` (hair accessory `Handle.TextureID = ""`, `Color`), adds `Root` (invisible, `CanCollide false`, size 1, welded to `HumanoidRootPart`, placed so that `Root` is 0.5 above the feet: feet = `HumanoidRootPart.Position.Y - HumanoidRootPart.Size.Y/2 - Humanoid.HipHeight`), sets `PrimaryPart = Root`, adds `Head` (eye level: the Head part's position) and `Talk` (chest: `UpperTorso` position, 0.5 forward) attachments on `Root`, sets `Humanoid.DisplayDistanceType = None`, `HealthDisplayType = AlwaysOff`, `Humanoid.EvaluateStateMachine = false`, anchors `HumanoidRootPart` only, names the model `<id>`, sets attribute `Pose = person.pose`, parents it under `ReplicatedStorage.Assets.Story` (creating the folder if missing, replacing a same-named child). `CastService.rig(id): Model?` returns the built template. Also `CastService:Init()` is idempotent.
- Note for callers: nothing else changes. `Assets.story(id)` finds the rig; `Assets.anchor` anchors all its parts (the Humanoid still animates anchored limbs? No: anchored parts do not animate). So `Assets.anchor` must skip rigs: in `Assets.anchor`, when the model has a Humanoid, anchor only `HumanoidRootPart` and `Root`.

- [ ] **Step 1: Write the Lune-testable piece first**

`CastService.feetOffset(hipHeight: number, rootSize: number): number` returns the Y distance from the HumanoidRootPart centre down to the feet (`rootSize/2 + hipHeight`), and `CastService.rootPlacement(hipHeight, rootSize)` returns the Root part's offset below the HumanoidRootPart centre (`feetOffset - 0.5`). Put them in `src/shared/CastRig.luau` (pure) so `check-story` can assert `CastRig.feetOffset(2, 2) == 3` and `CastRig.rootPlacement(2, 2) == 2.5`. Run `lune run scripts/check-story`  Expected: FAIL.

- [ ] **Step 2: Implement `CastRig.luau` and `CastService.luau`**

As in Interfaces. `Assets.anchor` learns about rigs (anchor `HumanoidRootPart` and `Root` only when a `Humanoid` is present).

- [ ] **Step 3: Delete the statues and the TurfKing truck file; fix the project tree**

Remove the ten `.rbxm` files; update `default.project.json` so `ReplicatedStorage.Assets.Story` no longer points at `NPC_Judge1.rbxm`/`NPC_Judge2.rbxm` (keep the folder entry so the server can parent rigs into it: an empty folder entry `"Story": {"$className": "Folder"}`). `rojo build` must succeed.

- [ ] **Step 4: Verify in Studio (the controller does this)**

Play: Gloria on her porch, Chad by the TurfKing truck (now the purple heavy-duty pickup), June on her rocker, the judges' walk, all as rigs standing where the statues stood, bubbles over heads. Report any offset.

- [ ] **Step 5: Gates, commit**

`Build the story's people as Roblox rigs at startup`.

### Task 5: Poses and walks

**Files:**
- Create: `src/shared/NpcAnimator.luau`
- Modify: `src/server/Services/CastService.luau` (not needed: posing happens where rigs are placed)
- Modify: `src/server/Services/GloriaService.luau` (after placing Gloria and Chad: `NpcAnimator.play(model)`)
- Modify: `src/server/GrandmaJune.luau` (June: place with `seat` then `NpcAnimator.play`)
- Modify: `src/client/Controllers/ContestController.luau` (judges: `NpcAnimator.play(model, "Walk")` while moving, `NpcAnimator.play(model, "Idle")` when stopped; drop the bob)

**Interfaces:**
- Produces: `NpcAnimator.play(model: Model, pose: string?)`: pose defaults to the model's `Pose` attribute; loads `Cast.Poses[pose]` through the Humanoid's `Animator` (create one if missing), stops any track it started before on that model, plays looped. `NpcAnimator.stop(model)`. Safe on a non-rig (placeholder): does nothing.
- June: `GrandmaJune` places her rig so that `Root` lands at `seat` (the chair's seat in the chair's frame, from `Cast.People.NPC_June_Sitting.seat`, converted to Vector3) and plays `Sit`.

- [ ] **Step 1: Write the pure test** in `check-story`: `NpcAnimator.resolve(poseAttribute: string?, requested: string?): string?` returns requested, else the attribute, else nil; and returns nil for a pose not in `Cast.Poses`. Run: FAIL.
- [ ] **Step 2: Implement `NpcAnimator`** and wire the three call sites.
- [ ] **Step 3: Studio check (controller):** idle visible on Gloria and Chad, sit on June, walk on the judges.
- [ ] **Step 4: Gates, commit** `Pose and walk the cast with Roblox's own animations`.

### Task 6: Grass art and its upload

**Files:**
- Create: `scripts/make-grass-tufts.py` (PIL) → `art-source/Grass/Grass_Tufts.png`
- Create: `scripts/upload-grass-art.py` (reuses `upload()` from `upload-gui-art.py` by import of that module's functions; if its `read_key` is not importable cleanly, copy the three helpers)
- Create: `src/shared/Config/GrassArt.luau`
- Modify: `TODO.md` (replace the "Not uploaded yet" paragraph with the new step)

**Interfaces:**
- Produces: `GrassArt = { Mown = 0, Uncut = 0, Soil = 0, Tufts = 0, TileStuds = 8, TuftSheet = { columns = 4, rows = 2, size = 64 } }` (ids 0 until uploaded; the upload script rewrites the four ids).
- Produces: `Grass_Tufts.png`, 256 × 256 RGBA: eight tufts in a 4 × 2 grid of 64 px cells, each 5 to 9 tapered blades from a common base with alpha, two greens (`(58, 112, 40)` and `(98, 160, 60)`), seeded so the file is reproducible.
- `python scripts/upload-grass-art.py [--dry-run]` uploads `art-source/GUI/Source/RenderOnly/Textures/Lawn_Mown_Color.png`, `Lawn_Uncut_Color.png`, `Soil_Color.png` and `art-source/Grass/Grass_Tufts.png` as Image assets under group 1060015801 and writes the ids into `GrassArt.luau`. On HTTP 401/403 it prints the exact Asset Manager steps and the file paths, and exits 2.

- [ ] **Step 1: Write the tuft generator test**: `python scripts/make-grass-tufts.py --check` regenerates into a temp path and asserts 256 × 256, RGBA, eight cells each with some opaque pixels and transparent corners. Run: FAIL.
- [ ] **Step 2: Implement the generator**, run it, commit the PNG.
- [ ] **Step 3: Write the upload script** and run `--dry-run` (lists the four files and the target). Then run it for real once; if the key lacks the scope, leave ids 0 and record the Asset Manager step in `TODO.md` under "Before release".
- [ ] **Step 4: Gates, commit** `Add the lawn textures and tuft sheet to GrassArt`.

### Task 7: GrassPaint draws with the textures

**Files:**
- Modify: `src/client/GrassPaint.luau`
- Modify: `src/client/Controllers/GrassController.luau` (turf part `Texture`; pass `GrassArt` ids; one warning on load failure)
- Modify: `src/shared/GrassImages.luau` (`GrassImages.tuftFor(dot): number` 1 to 8 from the dot's seed-derived fields, pure)
- Modify: `scripts/check-mowing.luau` (tuftFor is deterministic and in range)
- Modify: `docs/GAME_DESIGN.md` ("Mowing: cells, swaths and shells": the texture-plus-tint description)

**Interfaces:**
- Consumes: `GrassArt` (Task 6). When any id is 0 or `AssetService:CreateEditableImageAsync(Content.fromAssetId(id))` fails, `GrassPaint.prepare` falls back to today's brushes and warns once (`GrassPaint: lawn textures unavailable, painting flat colours`).
- Produces: in `GrassPaint.prepare(plan)`: the uncut mottle brush (a 64 × 64 tile sampled from the uncut image) and the eight tuft brushes (from the sheet); `stamp` paints mown pixels as a translucent shade tint (alpha 0.35 light / 0.45 dark over the texture) and uncut pixels opaque from the mottle; shells draw tufts with `DrawImageTransformed` at `GrassImages` dot positions, scaled so a tuft is about one stud (`PIXELS_PER_STUD` wide), tinted by shell height. In `GrassController.surfacePart` for the turf only: a `Texture` on the top face, `ColorMapContent`/`TextureContent` = the mown asset, `StudsPerTileU/V = GrassArt.TileStuds`, under the Decal (Decal `ZIndex` above). The far-lawn case (`hide`) keeps a bare turf part with the same `Texture` instead of nothing.

- [ ] **Step 1: Write the check-mowing test** for `GrassImages.tuftFor`: for 1000 generated dots every value is in 1..8 and the sequence is identical across two calls. Run: FAIL.
- [ ] **Step 2: Implement `tuftFor`**, then the painter and controller changes.
- [ ] **Step 3: Studio check (controller):** a job lawn and the home lawn at eye level and from the road, with ids present and with ids forced to 0.
- [ ] **Step 4: Gates, commit** `Paint the lawn over a real texture with tuft shells`.

### Task 8: Studio tools for curation, in the repo

**Files:**
- Create: `scripts/serve-studio.py` (serves `scripts/studio/` on 127.0.0.1:8765, appends POST bodies to `scripts/studio/log.txt`, which is git-ignored)
- Create: `scripts/studio/lineup.lua`, `scripts/studio/camera.lua`, `scripts/studio/pairs.example.json`, `scripts/studio/README.md`
- Modify: `.gitignore` (`scripts/studio/log.txt`, `scripts/studio/pairs.json`, `scripts/studio/mode.txt`)

**Interfaces:**
- Produces: the command-bar one-liner documented in the README: `local H=game:GetService("HttpService");local n=(H:GetAsync("http://127.0.0.1:8765/mode.txt"):gsub("%s",""));local f,e=loadstring(H:GetAsync("http://127.0.0.1:8765/"..n..".lua"));if f then f() else warn(e) end`, with `mode.txt` naming `lineup` or `camera`. `lineup.lua` reads `pairs.json` (`[{ name, now: "Folder/Id", store: [assetId...], gap, step }]`), stands each row (now, then candidates) on a slab 600 studs up, labels them, writes camera stops to the `Lineup` folder's `Stops` attribute, and POSTs a report. `camera.lua` walks the stops six seconds apart. These are the scripts used in this project's curation, moved into the repo as they are, with the deleted-giants line removed from `camera.lua`.

- [ ] **Step 1: Copy the two scripts from the chat's scratchpad** (`C:\Users\Avery\AppData\Local\Temp\claude\C--\1f495a49-4ed6-4ade-ae62-edaaa6c3eb45\scratchpad\lua\`), write the server and README, ignore the runtime files.
- [ ] **Step 2: `python scripts/serve-studio.py` starts and serves `lineup.lua` (curl 200).** Commit `Add the Studio lineup tools used for model curation`.

### Task 9: Batch 1, mowers and trimmers (controller)

For ReelMower, GasPushMower, SelfPropelledMower, RidingMower, ZeroTurnMower, CommercialZeroTurn, StandOnMower, CommercialReelMower, ElectricTrimmer, GasTrimmer, Brushcutter, StraightShaftTrimmer: pick a candidate (or `kept`, or a Blender build), write the manifest entries with measured `fit`, `handle`, `grips` and renames, `python scripts/generate-import.py`, paste into Studio, stage, Save to File, `lune run scripts/export-models <file> --overwrite`, `lune run scripts/check-models`, Play: hold each in first person and on the rack. Commit `Replace the mowers and trimmers with curated Store meshes`.

### Task 10: Batch 2, handheld, barrows, spreader, sprayer, cans (controller)

Same loop for LeafBlower, BackpackBlower, the four edgers, the four hedge trimmers, SingleWheelbarrow, SingleWheelbarrowFlatFree, DualWheelbarrow, PolyCart, BroadcastSpreader, BackpackSprayer, GasCan, MixGasCan, ToolBucket.

### Task 11: Batch 3, vehicles (controller)

RustyPickup, WorkPickup, HeavyDutyPickup, LandscapingTruck, UtilityTrailer, LandscapeTrailer, EquipmentTrailer: `__Body` renames, `BedArea` boxes, `DriverSeat` markers, synthesised `EquipmentTrailer__Ramp` and two `BaySpot` parts; Play: load a mower, drive a job, paint job preview on the new truck, the TurfKing truck in purple.

### Task 12: Batch 4, the customer's house (controller)

Props/House with `Porch` and `Driveway`; Play: a job lawn with the house, the porch bubble position.

### Task 13: Docs and handoff

- Modify: `assets/README.md` (the manifest workflow replaces the ChatGPT one as the way to add models; keep the old section under "Importing mesh packs"), `docs/GAME_DESIGN.md` ("Models" paragraph: the three sources and the contract), `TODO.md` (the playtest checklist from the spec, the swap list: decorations, storage, boxes, junk, trophy, Gloria's set, batches 5 to 7), `HANDOFF.md` (where the pipeline lives, how to run a batch).
- Commit `Document the model pipeline and what is left`.
