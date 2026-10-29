"""Tests for scripts/generate-import.py: the manifest checks and the Luau it renders.

    python -m unittest scripts/test_generate_import.py -v
"""

import copy
import importlib.util
import json
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# The generator's file name has a hyphen, so it can't be imported by name.
spec = importlib.util.spec_from_file_location("generate_import", os.path.join(HERE, "generate-import.py"))
generate_import = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generate_import)

TEMPLATE = "-- header\nlocal MODELS = {\n--@MODELS@\n}\n"


def store_entry():
    return {
        "id": "GasPushMower",
        "folder": "Tools",
        "source": {
            "kind": "store",
            "assetId": 18744991009,
            "name": "(MQ) Internal Combustion Push Mower Set",
            "creator": "MinecraftPro97k",
        },
        "keep": "Mower_Red",
        "facing": "+X",
        "up": "+Y",
        "fit": {"axis": "height", "studs": 3.7},
        "handle": {"position": [0, 3.4, 1.9], "size": [1.6, 0.2, 0.2]},
        "grips": {"left": [-0.8, 3.5, 1.9], "right": [0.8, 3.5, 1.9]},
        "parts": {"wheel_fl": {"rename": "GasPushMower__Wheel", "collide": False}},
    }


def truck_entry():
    entry = {**store_entry(), "id": "WorkPickup", "folder": "Trucks"}
    del entry["handle"], entry["grips"]
    return entry


def kept_entry():
    return {"id": "BladeFile", "folder": "Tools", "source": {"kind": "kept"}}


def manifest_of(*entries):
    return {"version": 1, "complete": False, "models": [copy.deepcopy(e) for e in entries]}


class GenerateTest(unittest.TestCase):
    def test_renders_a_store_entry(self):
        lua = generate_import.generate(manifest_of(store_entry(), kept_entry()), TEMPLATE)
        for fragment in (
            'id = "GasPushMower"',
            'folder = "Tools"',
            "assetId = 18744991009",
            'keep = "Mower_Red"',
            'facing = "+X"',
            'fit = { axis = "height", studs = 3.7 }',
            "handle = { position = Vector3.new(0, 3.4, 1.9), size = Vector3.new(1.6, 0.2, 0.2) }",
            "grips = { left = Vector3.new(-0.8, 3.5, 1.9), right = Vector3.new(0.8, 3.5, 1.9) }",
            '["wheel_fl"] = { rename = "GasPushMower__Wheel", collide = false }',
        ):
            self.assertIn(fragment, lua)

    def test_leaves_kept_entries_out(self):
        lua = generate_import.generate(manifest_of(store_entry(), kept_entry()), TEMPLATE)
        self.assertNotIn("BladeFile", lua)

    def test_fills_in_defaults(self):
        entry = store_entry()
        for field in ("facing", "up", "keep"):
            del entry[field]
        lua = generate_import.generate(manifest_of(entry), TEMPLATE)
        self.assertIn('facing = "-Z"', lua)
        self.assertIn('up = "+Y"', lua)
        self.assertNotIn("keep =", lua)

    def test_collision_defaults_to_solid_for_vehicles_and_buildings_only(self):
        tool = store_entry()
        truck = {**store_entry(), "id": "WorkPickup", "folder": "Trucks"}
        del truck["handle"], truck["grips"]
        lua = generate_import.generate(manifest_of(tool, truck), TEMPLATE)
        self.assertEqual(lua.count("collide = false,"), 1)
        self.assertEqual(lua.count("collide = true,"), 1)
        explicit = {**truck, "collide": False}
        self.assertIn("collide = false,", generate_import.generate(manifest_of(explicit), TEMPLATE))

    def test_the_house_collides_by_default_though_it_lives_in_props(self):
        def render(entry_id):
            entry = {**store_entry(), "id": entry_id, "folder": "Props"}
            del entry["handle"], entry["grips"]
            return generate_import.generate(manifest_of(entry), TEMPLATE)

        self.assertIn("collide = true,", render("House"))
        self.assertIn("collide = false,", render("GardenGnome"))

    def test_renders_markers_boxes_and_synth(self):
        entry = {**store_entry(), "id": "EquipmentTrailer", "folder": "Trailers"}
        del entry["handle"], entry["grips"]
        entry["markers"] = [
            {"name": "Mount", "position": [0, 1, 2], "orientation": [0, 90, 0], "attributes": {"Slots": 2, "Kind": "tool"}}
        ]
        entry["boxes"] = [{"name": "BedArea", "position": [0, 1, 0], "size": [4, 0.2, 8]}]
        entry["synth"] = [
            {
                "name": "EquipmentTrailer__Ramp",
                "position": [0, 0.5, 9],
                "size": [3, 0.2, 4],
                "material": "Metal",
                "color": [90, 90, 95],
                "hinge": [0, 0.5, 7],
            }
        ]
        entry["strip"] = ["Decal:Logo"]
        entry["budget"] = 80
        lua = generate_import.generate(manifest_of(entry), TEMPLATE)
        for fragment in (
            'name = "Mount", position = Vector3.new(0, 1, 2), orientation = Vector3.new(0, 90, 0)',
            '["Slots"] = 2, ["Kind"] = "tool"',
            'name = "BedArea", position = Vector3.new(0, 1, 0), size = Vector3.new(4, 0.2, 8)',
            'name = "EquipmentTrailer__Ramp"',
            'material = "Metal"',
            "color = Color3.fromRGB(90, 90, 95)",
            "hinge = Vector3.new(0, 0.5, 7)",
            'strip = { { class = "Decal", name = "Logo" } }',
            "budget = 80",
        ):
            self.assertIn(fragment, lua)

    def test_renders_a_turn_only_when_the_entry_has_one(self):
        diagonal = {**store_entry(), "facing": "-X", "turn": -45}
        lua = generate_import.generate(manifest_of(diagonal), TEMPLATE)
        self.assertIn('facing = "-X",\n\t\tturn = -45,\n', lua)
        self.assertNotIn("turn =", generate_import.generate(manifest_of(store_entry()), TEMPLATE))

    def test_renders_a_fractional_turn_as_typed(self):
        entry = {**store_entry(), "turn": 22.5}
        self.assertIn("turn = 22.5,", generate_import.generate(manifest_of(entry), TEMPLATE))

    def test_renders_the_body_only_when_the_entry_has_one(self):
        lua = generate_import.generate(manifest_of({**truck_entry(), "body": "largest"}), TEMPLATE)
        self.assertIn('body = "largest",', lua)
        self.assertNotIn("body =", generate_import.generate(manifest_of(truck_entry()), TEMPLATE))

    def test_a_strip_by_name_renders_an_empty_class(self):
        entry = {**store_entry(), "strip": ["*:Seat", "Decal:Logo"]}
        lua = generate_import.generate(manifest_of(entry), TEMPLATE)
        self.assertIn('strip = { { class = "", name = "Seat" }, { class = "Decal", name = "Logo" } }', lua)

    def test_replaces_the_placeholder_and_keeps_the_template(self):
        lua = generate_import.generate(manifest_of(store_entry()), TEMPLATE)
        self.assertNotIn("--@MODELS@", lua)
        self.assertTrue(lua.startswith("-- header\nlocal MODELS = {\n"))
        self.assertTrue(lua.endswith("}\n"))

    def test_a_template_without_the_placeholder_is_an_error(self):
        with self.assertRaises(ValueError):
            generate_import.generate(manifest_of(store_entry()), "local MODELS = {}\n")

    def test_keeps_non_ascii_names_readable(self):
        entry = store_entry()
        entry["source"]["creator"] = "Zoë"
        self.assertIn('creator = "Zoë"', generate_import.generate(manifest_of(entry), TEMPLATE))


class ValidateTest(unittest.TestCase):
    def test_accepts_a_good_manifest(self):
        self.assertEqual(generate_import.validate(manifest_of(store_entry(), kept_entry())), [])

    def test_a_bad_facing_is_one_error_naming_the_id(self):
        entry = store_entry()
        entry["facing"] = "+Y"
        errors = generate_import.validate(manifest_of(entry))
        self.assertEqual(len(errors), 1)
        self.assertIn("GasPushMower", errors[0])
        self.assertIn("facing", errors[0])

    def test_a_missing_fit_is_one_error_naming_the_id(self):
        entry = store_entry()
        del entry["fit"]
        errors = generate_import.validate(manifest_of(entry))
        self.assertEqual(len(errors), 1)
        self.assertIn("GasPushMower", errors[0])
        self.assertIn("fit", errors[0])

    def test_two_problems_are_two_errors(self):
        entry = store_entry()
        entry["facing"] = "+Y"
        del entry["fit"]
        self.assertEqual(len(generate_import.validate(manifest_of(entry))), 2)

    def test_a_kept_entry_needs_no_fit(self):
        self.assertEqual(generate_import.validate(manifest_of(kept_entry())), [])

    def test_each_of_these_is_one_error(self):
        def edit(change):
            entry = store_entry()
            change(entry)
            return entry

        cases = {
            "unknown folder": edit(lambda e: (e.update(folder="Garage"), e.pop("handle"), e.pop("grips"))),
            "unknown source kind": edit(lambda e: e["source"].update(kind="scrape")),
            "source kind that is a list": edit(lambda e: e["source"].update(kind=["store"])),
            "store entry without an asset id": edit(lambda e: e["source"].pop("assetId")),
            "store entry without a creator": edit(lambda e: e["source"].pop("creator")),
            "unknown fit axis": edit(lambda e: e["fit"].update(axis="depth")),
            "fit of zero studs": edit(lambda e: e["fit"].update(studs=0)),
            "up that isn't +Y": edit(lambda e: e.update(up="+Z")),
            "handle with two numbers": edit(lambda e: e["handle"].update(position=[0, 1])),
            "tool with no handle": edit(lambda e: (e.pop("handle"), e.pop("grips"))),
            "tool with both handle and handlePart": edit(lambda e: e.update(handlePart="Grip")),
            "grips on a truck": edit(lambda e: (e.update(folder="Trucks"), e.pop("handle"))),
            "parts entry that isn't a table": edit(lambda e: e["parts"].update(wheel_fl="Wheel")),
            "strip without a class": edit(lambda e: e.update(strip=["Logo"])),
            "strip with an empty class": edit(lambda e: e.update(strip=[":Seat"])),
            "strip with an empty name": edit(lambda e: e.update(strip=["*:"])),
            "turn that is text": edit(lambda e: e.update(turn="45")),
            "turn that is true": edit(lambda e: e.update(turn=True)),
            "turn that is a list": edit(lambda e: e.update(turn=[45])),
            "budget that isn't a whole number": edit(lambda e: e.update(budget=12.5)),
            "field the importer doesn't know": edit(lambda e: e.update(facig="+X")),
            "marker attribute that is a list": edit(
                lambda e: e.update(markers=[{"name": "Mount", "position": [0, 0, 0], "attributes": {"Slots": [1]}}])
            ),
            "synth part with a bad colour": edit(
                lambda e: e.update(
                    synth=[{"name": "Ramp", "position": [0, 0, 0], "size": [1, 1, 1], "material": "Metal", "color": [1, 2]}]
                )
            ),
        }
        for label, entry in cases.items():
            with self.subTest(label):
                errors = generate_import.validate(manifest_of(entry))
                self.assertEqual(len(errors), 1, errors)
                self.assertIn("GasPushMower", errors[0])

    def test_a_turn_may_be_any_number_of_degrees(self):
        for turn in (-45, 0, 22.5, 720):
            with self.subTest(turn):
                entry = {**store_entry(), "turn": turn}
                self.assertEqual(generate_import.validate(manifest_of(entry)), [])

    def test_a_strip_may_name_any_class_or_none(self):
        entry = {**store_entry(), "strip": ["*:Seat", "Model:Bed (Queen Size)", "Decal:Logo"]}
        self.assertEqual(generate_import.validate(manifest_of(entry)), [])

    def test_body_is_for_trucks_and_means_largest(self):
        truck = {**truck_entry(), "body": "largest"}
        self.assertEqual(generate_import.validate(manifest_of(truck)), [])
        cases = {
            "a Tools entry": {**store_entry(), "body": "largest"},
            "a Trailers entry": {**truck, "folder": "Trailers"},
            "a Props entry": {**truck, "folder": "Props"},
            "a body that isn't largest": {**truck, "body": "biggest"},
            "a body that is a list": {**truck, "body": ["largest"]},
        }
        for label, entry in cases.items():
            with self.subTest(label):
                errors = generate_import.validate(manifest_of(entry))
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(entry["id"], errors[0])
                self.assertIn("body", errors[0])

    def test_duplicate_ids_in_one_folder_are_an_error(self):
        errors = generate_import.validate(manifest_of(store_entry(), store_entry()))
        self.assertEqual(len(errors), 1)
        self.assertIn("GasPushMower", errors[0])

    def test_the_manifest_itself_is_checked(self):
        for manifest in ({"version": 2, "complete": False, "models": []}, {"version": 1, "models": []}):
            self.assertEqual(len(generate_import.validate(manifest)), 1)


class RepoTest(unittest.TestCase):
    """The committed manifest and the committed script have to agree."""

    def setUp(self):
        with open(os.path.join(ROOT, "assets", "manifest", "models.json"), encoding="utf-8") as f:
            self.manifest = json.load(f)

    def test_the_manifest_is_valid(self):
        self.assertEqual(generate_import.validate(self.manifest), [])

    def test_the_generated_script_is_up_to_date(self):
        with open(os.path.join(HERE, "ImportStoreModels.template.luau"), encoding="utf-8", newline="") as f:
            template = f.read()
        with open(os.path.join(HERE, "ImportStoreModels.luau"), encoding="utf-8", newline="") as f:
            committed = f.read()
        self.assertEqual(
            committed.replace("\r\n", "\n"),
            generate_import.generate(self.manifest, template.replace("\r\n", "\n")),
            "run python scripts/generate-import.py",
        )


if __name__ == "__main__":
    unittest.main()
