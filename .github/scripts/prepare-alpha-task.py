"""Select instruction changes from the complete push, and prepare a Codex prompt."""

import argparse
import json
from pathlib import Path, PurePosixPath
import subprocess


def select_instructions(before, event):
    if event == "workflow_dispatch" or not before or set(before) == {"0"}:
        command = ["git", "ls-files", "-z", "--", "alphainstructions/"]
    else:
        # Use the entire push range, including merges and multiple commits.
        command = [
            "git", "diff", "--name-only", "--no-renames", "--diff-filter=AM",
            "-z", before, "HEAD", "--", "alphainstructions/",
        ]
    paths = subprocess.check_output(command).decode().split("\0")
    return sorted(
        path for path in paths if path
        and PurePosixPath(path).suffix.lower() == ".md"
        and Path(path).is_file() and not Path(path).is_symlink()
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", default="")
    parser.add_argument("--event", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    selected = select_instructions(args.before, args.event)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "instructions.json").write_text(json.dumps(selected, indent=2))
    prompt = """Work on the owner's new instructions automatically.

You are in a checkout of the main-branch push that triggered this task. Read
repository AGENTS.md guidance, README.md, TODO.md, and the selected instruction
files listed below before working. Read related files in alphainstructions for
context, but only execute tasks from the selected files. A manual run selects all
current instructions; leave work that is already complete alone.

Carry out the requested work and run relevant validation. Preserve unrelated work
and obey each instruction's scope. Do not edit the instruction files, .github/,
or repository automation. Do not commit, push, merge, publish the Roblox game, or
contact other people. A separate job will open a PR for repository changes.

This is a disposable Linux GitHub runner, not the user's desktop or Codex cloud
environment. Roblox Studio and a Studio MCP connection are unavailable. Never
claim Studio actions, asset ownership, uploads, or gameplay tests occurred unless
you actually verified them. If instructions require Studio or other unavailable
tools, finish any useful authorized independent work and report the precise
blocker. Do not replace requested Studio work with unrelated code changes.

Rojo, Selene, and StyLua are on PATH at the versions in rokit.toml. Build outputs
belong in /tmp, not in the repository. Use rojo build -o /tmp/alpha-task.rbxlx
when changes affect the place. Do not reformat unrelated source or regenerate
existing assets without an instruction requiring it.

Your final response must describe completed work, validation, and any remaining
blockers. If no repository files changed, explain why. Never include credentials.

Selected instruction paths (JSON; read these files from the checkout):
""" + json.dumps(selected, indent=2) + "\n"
    (args.output_dir / "prompt.md").write_text(prompt)
    print(f"Selected {len(selected)} instruction file(s)")


if __name__ == "__main__":
    main()
