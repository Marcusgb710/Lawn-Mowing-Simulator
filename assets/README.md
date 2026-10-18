# Assets (for the modeler)

This folder becomes `ReplicatedStorage.Assets` in the game. Anything in here replaces a
placeholder, as long as it's named after the item's `id` in `src/shared/Config/Items.luau`.

- `Tools/`: one per tool tier, e.g. `ReelMower.rbxm`, `GasPushMower.rbxm`, `LeafBlower.rbxm`.
  A `Tool` with a part named `Handle` works best. A plain Model also works, and its PrimaryPart
  becomes the handle.
- `Trucks/`: `RustyPickup`, `WorkPickup`, `HeavyDutyPickup`, `LandscapingTruck`. Face the
  front of the truck along the model's pivot front (LookVector).
- `Trailers/`: `UtilityTrailer`, `LandscapeTrailer`, hitch facing forward. It gets attached
  behind the truck automatically.
- `Buildings/`: `Shed`, `Garage`, `SmallOffice`, the business upgrades, front door facing
  forward.
- `Props/`: `House` (the customer's house), `FlowerPatch` and `GardenGnome` (things players
  must not mow over). If a part in `FlowerPatch` is named `Flower`, it wilts when hit.

Save models from Studio with right-click → *Save to File* as `.rbxm` into the right folder, or
just drop them into `ReplicatedStorage.Assets` in Studio. Rojo won't delete models added that
way.
