# Assets (for the modeler)

This folder becomes `ReplicatedStorage.Assets` in the game. Anything in here replaces a
placeholder, as long as it's named after the item's `id` in `src/shared/Config/Items.luau`.

- `Tools/`: one per tool tier, e.g. `ReelMower.rbxm`, `GasPushMower.rbxm`, `LeafBlower.rbxm`.
  A `Tool` with a part named `Handle` works best. A plain Model also works, and its PrimaryPart
  becomes the handle. The hand holds the handle's center with the handle's +Y pointing up and its
  front (LookVector) pointing forward. The kit tools are built by `scripts/build-kit-tools.luau`.
  In first person the player's hands grip the tool where that kind of tool is usually held (both
  sides of a handlebar, up a shaft, on a trimmer's front handle). To place them exactly, add
  `Attachment`s named `GripRight` and `GripLeft` where each hand goes (for ride-ons, on the
  steering wheel or lap bars).
- `Kit/`: the Lawn Mowing mobile kit (grass, weeds, mowers, trimmers, props) as static templates.
  Each pivot sits on the ground under the asset and faces its front. Made by
  `scripts/OrganizeLawnKit.luau` + `scripts/export-kit.luau`.
- `Trucks/`: `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck`. Face the
  front of the truck along the model's pivot front (LookVector). Add an invisible, non-colliding
  Part named `BedArea` lying on the truck bed, so loaded tools have somewhere to lie. Its `Slots`
  attribute is only a hint: how much a truck carries is `space` in `Items.luau`.
- `Trailers/`: `UtilityTrailer`, `LandscapeTrailer`, `EquipmentTrailer`, hitch facing forward,
  with its own `BedArea` part. It gets attached behind the truck automatically. The equipment
  trailer also has two invisible `BaySpot` parts where ride-on machines park.
- `Buildings/`: `Shed`, `Garage`, `SmallOffice`, `EquipmentYard`, the business upgrades, front
  door facing forward.
- `Props/`: `House` (the customer's house), `FlowerPatch` and `GardenGnome` (things players
  must not mow over). If a part in `FlowerPatch` is named `Flower`, it wilts when hit.
- `Props/`: `StoragePegboard`, `StorageWallRack`, `StorageWallHooks`, `StorageShelf`, the storage
  fixtures at the business. Back flat on Z = 0, front toward -Z, bottom at Y = 0, an invisible
  `Root` part as the PrimaryPart at (0, 0.5, 0), and `Slot1`, `Slot2`... attachments where tools
  go. Without slots they get spread over the front.

Save models from Studio with right-click → *Save to File* as `.rbxm` into the right folder, or
just drop them into `ReplicatedStorage.Assets` in Studio. Rojo won't delete models added that
way.
