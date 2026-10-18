"""Regression checks for push ranges, renames, deletions, and manual retries."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/prepare-alpha-task.py"
spec = importlib.util.spec_from_file_location("prepare_alpha_task", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InstructionSelectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "Selection Test")
        self.write("alphainstructions/instructions1.md", "original")
        self.write("alphainstructions/remove.md", "delete later")
        self.write("README.md", "unrelated")
        self.commit()
        self.before = self.git("rev-parse", "HEAD").strip()

    def tearDown(self):
        os.chdir(self.previous)
        self.directory.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], text=True)

    def write(self, name, content):
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def commit(self):
        self.git("add", "--all")
        self.git("commit", "-qm", "fixture")

    def test_whole_push_includes_earlier_commit_and_nested_numbered_files(self):
        self.write("alphainstructions/instructions1.md", "updated")
        self.commit()
        self.write("alphainstructions/nested/instructions2.md", "new")
        self.write("alphainstructions/image.png", "not Markdown")
        self.write("README.md", "ignore unrelated changes")
        self.commit()
        self.assertEqual(module.select_instructions(self.before, "push"), [
            "alphainstructions/instructions1.md",
            "alphainstructions/nested/instructions2.md",
        ])

    def test_deletion_does_not_create_a_task(self):
        Path("alphainstructions/remove.md").unlink()
        self.commit()
        self.assertEqual(module.select_instructions(self.before, "push"), [])

    def test_rename_selects_destination(self):
        self.git("mv", "alphainstructions/instructions1.md", "alphainstructions/renamed.md")
        self.commit()
        self.assertEqual(module.select_instructions(self.before, "push"), [
            "alphainstructions/renamed.md",
        ])

    def test_manual_and_initial_push_select_all_current_markdown(self):
        expected = ["alphainstructions/instructions1.md", "alphainstructions/remove.md"]
        self.assertEqual(module.select_instructions("", "workflow_dispatch"), expected)
        self.assertEqual(module.select_instructions("0" * 40, "push"), expected)

    def test_symlinks_cannot_turn_outside_files_into_instructions(self):
        Path("alphainstructions/linked.md").symlink_to("../README.md")
        self.commit()
        self.assertEqual(module.select_instructions(self.before, "push"), [])


if __name__ == "__main__":
    unittest.main()
