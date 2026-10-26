#!/usr/bin/env python3
"""Publishes the latest main to Roblox in one command, without Studio.

    python3 scripts/publish.py              # check, build, merge, publish
    python3 scripts/publish.py --dry-run    # everything but the publish; keeps the place file
    python3 scripts/publish.py --base FILE  # merge into FILE instead of the default base place
    python3 scripts/publish.py --force      # skip the clean, up-to-date main check

1. Checks the working tree is clean and on main, level with origin/main (it fetches first).
2. Builds the code with `rojo build`.
3. Merges it into a base place with scripts/publish-place.luau (Lune), which prints a check.
4. Publishes the result as a new Published version through Open Cloud and prints its number.

The base place holds what Studio made and Rojo doesn't manage: Terrain, Baseplate, SpawnLocation,
the Sky and Lighting effects, StreamingEnabled and every service's settings. By default it's
Studio's newest AutoRecovery copy of the place; without one it's place/base.rbxl, which is that
copy with the Rojo trees taken out (remake it with
`lune run scripts/publish-place --make-base <autosave> place/base.rbxl`).

Roblox answers 409 "Server is busy" while Studio has the place open, so this waits and tries again.
Closing Studio first lets it go straight through.

The key comes from $ROBLOX_API_KEY or ~/.roblox-opencloud-key. It needs the universe-places API
with write access on the experience. It's never printed. Never commit the key.
"""

import argparse
import datetime
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNIVERSE = "10771693515"
PLACE = "73083404631437"
URL = f"https://apis.roblox.com/universes/v1/{UNIVERSE}/places/{PLACE}/versions?versionType=Published"
COMMITTED_BASE = os.path.join(ROOT, "place", "base.rbxl")
# Where Studio keeps its AutoRecovery copies (macOS, then Windows).
AUTOSAVE_DIRS = [
    os.path.expanduser("~/Library/Application Support/Roblox/RobloxStudio/AutoSaves"),
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "RobloxStudio", "AutoSaves"),
    os.path.expanduser("~/Documents/ROBLOX/AutoSaves"),
]
# Seconds between tries while Roblox says the server is busy, and how many tries in all.
BUSY_WAIT = 45
TRIES = 8


def fail(message):
    print(f"publish: {message}", file=sys.stderr)
    sys.exit(1)


def run(args, what):
    print(f"$ {' '.join(args)}", flush=True)
    if subprocess.run(args, cwd=ROOT).returncode != 0:
        fail(f"{what} failed")


def git(*args):
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    return result.returncode, result.stdout.rstrip(), result.stderr.strip()


def check_git(force):
    """Refuses (unless --force) anything but a clean main level with origin/main."""
    problems = []
    _, branch, _ = git("rev-parse", "--abbrev-ref", "HEAD")
    _, commit, _ = git("log", "-1", "--format=%h %s")
    print(f"Code: {branch} at {commit}", flush=True)
    code, status, error = git("status", "--porcelain")
    if code != 0:
        fail(f"git status failed: {error}")
    if status:
        changed = "\n".join("      " + line for line in status.splitlines())
        problems.append("the working tree has changes (commit or stash them):\n" + changed)
    if branch != "main":
        problems.append(f"it's on {branch}, not main")
    code, _, error = git("fetch", "--quiet", "origin", "main")
    if code != 0:
        problems.append(f"couldn't fetch origin/main: {error}")
    else:
        _, head, _ = git("rev-parse", "HEAD")
        _, remote, _ = git("rev-parse", "origin/main")
        if head != remote:
            _, behind, _ = git("rev-list", "--count", "HEAD..origin/main")
            _, ahead, _ = git("rev-list", "--count", "origin/main..HEAD")
            problems.append(f"it's {behind} commits behind and {ahead} ahead of origin/main (git pull)")
    if problems:
        listed = "\n".join(f"  - {problem}" for problem in problems)
        if not force:
            fail(f"refusing to publish:\n{listed}\nPass --force to publish anyway.")
        print(f"--force, so ignoring:\n{listed}")


def newest_autosave():
    found = []
    for folder in AUTOSAVE_DIRS:
        found += glob.glob(os.path.join(folder, f"{PLACE}_AutoRecovery_*.rbxl"))
    return max(found, key=os.path.getmtime) if found else None


def describe_age(path):
    saved = datetime.datetime.fromtimestamp(os.path.getmtime(path))
    hours = (datetime.datetime.now() - saved).total_seconds() / 3600
    ago = f"{hours * 60:.0f} minutes" if hours < 1 else f"{hours:.0f} hours" if hours < 48 else f"{hours / 24:.0f} days"
    return f"saved {saved:%Y-%m-%d %H:%M}, {ago} ago"


def pick_base(chosen):
    if chosen:
        path = os.path.abspath(chosen)
        if not os.path.isfile(path):
            fail(f"can't find {chosen}")
        return path, "--base"
    autosave = newest_autosave()
    if autosave:
        return autosave, "Studio's newest AutoRecovery copy"
    if os.path.isfile(COMMITTED_BASE):
        return COMMITTED_BASE, "the committed base (no Studio autosave found)"
    fail("no base place: no Studio autosave and no place/base.rbxl. Pass one with --base.")


def find_key():
    """The API key and where it came from, or (None, None)."""
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if key:
        return key, "$ROBLOX_API_KEY"
    path = os.path.expanduser("~/.roblox-opencloud-key")
    if os.path.isfile(path):
        with open(path) as file:
            key = file.read().strip()
        if key:
            return key, "~/.roblox-opencloud-key"
    return None, None


def post_place(url, key, path):
    """POSTs the place file; returns (HTTP status, body). The key goes to curl on stdin, so it's
    never on a command line."""
    escaped = key.replace("\\", "\\\\").replace('"', '\\"')
    result = subprocess.run(
        [
            "curl", "-sS", "-K", "-",
            "--connect-timeout", "30", "--max-time", "600",
            "-X", "POST", url,
            "-H", "Content-Type: application/octet-stream",
            "--data-binary", "@" + path,
            "-w", "\n%{http_code}",
        ],
        input=f'header = "x-api-key: {escaped}"\n',
        capture_output=True,
        text=True,
    )
    body, _, status = result.stdout.rpartition("\n")
    if result.returncode != 0 and not body:
        body = result.stderr.strip()
    return status or "000", body


def publish(key, path, url=URL, tries=TRIES, wait=BUSY_WAIT):
    """Publishes with retries while Roblox is busy; returns the new version number."""
    for attempt in range(1, tries + 1):
        status, body = post_place(url, key, path)
        if status == "200":
            try:
                return json.loads(body)["versionNumber"]
            except (ValueError, KeyError, TypeError):
                fail(f"Roblox said 200 but sent back something odd: {body[:300]}")
        if status == "409":
            reason = "409 Server is busy: Studio probably has the place open (closing Studio helps)"
        elif status == "429" or status.startswith("5") or status == "000":
            reason = f"HTTP {status} {body[:200]}".strip()
        else:
            fail(f"Roblox said HTTP {status}: {body[:500]}")
        if attempt == tries:
            fail(f"gave up after {tries} tries. Last answer: {reason}")
        print(f"Try {attempt} of {tries}: {reason}. Trying again in {wait} s.", flush=True)
        time.sleep(wait)


def main():
    parser = argparse.ArgumentParser(description="Publish the latest main to Roblox without Studio.")
    parser.add_argument("--dry-run", action="store_true", help="stop before publishing and keep the place file")
    parser.add_argument("--base", metavar="FILE", help="base place to merge the code into")
    parser.add_argument("--force", action="store_true", help="skip the clean, up-to-date main check")
    args = parser.parse_args()

    for tool in ("git", "rojo", "lune", "curl"):
        if not shutil.which(tool):
            fail(f"can't find {tool}" + (": run `rokit install` in the repo" if tool in ("rojo", "lune") else ""))

    check_git(args.force)
    key, key_source = find_key()
    if not key and not args.dry_run:
        fail("no API key: set ROBLOX_API_KEY or save it to ~/.roblox-opencloud-key.")

    base, why = pick_base(args.base)
    print(f"Base: {base}\n      {why}" + ("" if base == COMMITTED_BASE else f", {describe_age(base)}"))

    work = tempfile.mkdtemp(prefix="lms-publish-")
    # Studio rewrites its autosave every few minutes, so merge a copy of it.
    base_copy = os.path.join(work, "base.rbxl")
    shutil.copyfile(base, base_copy)
    code = os.path.join(work, "code.rbxl")
    place = os.path.join(work, "LawnMowingSimulator.rbxl")
    run(["rojo", "build", "default.project.json", "-o", code], "rojo build")
    print("$ lune run scripts/publish-place.luau <base> <code> <out>", flush=True)
    if subprocess.run(["lune", "run", "scripts/publish-place.luau", base_copy, code, place], cwd=ROOT).returncode != 0:
        hint = "" if base == COMMITTED_BASE else " To use the committed base instead, pass --base place/base.rbxl."
        fail(f"merging into the base place failed.{hint}")

    if args.dry_run:
        print(f"Dry run, so not publishing. The place file is {place}")
        print(f"API key: {'found in ' + key_source if key else 'none yet (set ROBLOX_API_KEY or ~/.roblox-opencloud-key)'}")
        return

    print(f"Publishing {place} to place {PLACE} (universe {UNIVERSE})...", flush=True)
    version = publish(key, place)
    shutil.rmtree(work, ignore_errors=True)
    print(f"Published version {version}.")


if __name__ == "__main__":
    main()
