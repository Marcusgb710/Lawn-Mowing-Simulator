#!/usr/bin/env python3
"""Uploads the GUI art (art-source/GUI, instructions 38) to Roblox as Big Dink Studios.

    python3 scripts/upload-gui-art.py [GUI folder] [--dry-run]

Every manifest file with role "upload" goes up as an Image asset through Open Cloud, and its id is
written to <GUI folder>/uploaded.json as it lands. Then scripts/gui-art-ids.py turns that into
src/shared/Config/GuiArt.luau. Files already in uploaded.json are skipped, so it can be stopped and
run again.

The key comes from $ROBLOX_API_KEY or ~/.roblox-opencloud-key. It needs Assets read and write for
the group. Never commit the key.
"""

import concurrent.futures
import json
import os
import subprocess
import sys
import threading
import time

GROUP_ID = "1060015801"  # Big Dink Studios
API = "https://apis.roblox.com/assets/v1"
WORKERS = 3
# Seconds to wait before trying again after Roblox says "too many requests", doubling each time.
BACKOFF = 5
TRIES = 6

lock = threading.Lock()


def read_key():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        path = os.path.expanduser("~/.roblox-opencloud-key")
        key = open(path).read() if os.path.exists(path) else ""
    key = key.strip()
    if not key:
        sys.exit("No API key: set ROBLOX_API_KEY or save it to ~/.roblox-opencloud-key.")
    return key


def curl(args):
    result = subprocess.run(["curl", "-s", "-w", "\n%{http_code}"] + args, capture_output=True, text=True)
    body, _, status = result.stdout.rpartition("\n")
    return status, body


def display_name(path):
    # Roblox keeps asset names short; the path without its extension is enough to find it again.
    name = "LMS_GUI_" + path.rsplit(".", 1)[0].replace("/", "_")
    return name[:50]


def upload(key, folder, path):
    request = {
        "assetType": "Image",
        "displayName": display_name(path),
        "description": f"Lawn Mowing Simulator GUI art: {path}",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    wait = BACKOFF
    for _ in range(TRIES):
        status, body = curl([
            "-X", "POST", f"{API}/assets",
            "-H", "x-api-key: " + key,
            "--form-string", "request=" + json.dumps(request),
            "-F", f"fileContent=@{os.path.join(folder, path)};type=image/png",
        ])
        if status == "429" or status.startswith("5"):
            time.sleep(wait)
            wait *= 2
            continue
        if not status.startswith("2"):
            return None, f"HTTP {status} {body[:200]}"
        operation = json.loads(body)["path"]
        for _ in range(60):
            time.sleep(1.5)
            status, body = curl(["-H", "x-api-key: " + key, f"{API}/{operation}"])
            if status == "429":
                time.sleep(wait)
                continue
            if not status.startswith("2"):
                continue
            done = json.loads(body)
            if done.get("done"):
                response = done.get("response") or {}
                moderation = (response.get("moderationResult") or {}).get("moderationState")
                if moderation == "Rejected":
                    return None, "rejected by moderation"
                return response.get("assetId"), None
        return None, "upload never finished"
    return None, "too many requests, gave up"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    folder = args[0] if args else "art-source/GUI"
    manifest = json.load(open(os.path.join(folder, "manifest.json")))
    out_path = os.path.join(folder, "uploaded.json")
    uploaded = json.load(open(out_path)) if os.path.exists(out_path) else {}

    todo = [f["path"] for f in manifest["files"] if f.get("role") == "upload" and not uploaded.get(f["path"])]
    total = sum(1 for f in manifest["files"] if f.get("role") == "upload")
    print(f"{total - len(todo)} of {total} already uploaded, {len(todo)} to go.")
    if dry or not todo:
        return
    key = read_key()

    def save():
        with open(out_path + ".tmp", "w") as file:
            json.dump(dict(sorted(uploaded.items())), file, indent=1)
        os.replace(out_path + ".tmp", out_path)

    failures = []

    def work(path):
        asset_id, problem = upload(key, folder, path)
        with lock:
            if asset_id:
                uploaded[path] = int(asset_id)
                save()
                print(f"[{len(uploaded)}/{total}] {path} -> {asset_id}", flush=True)
            else:
                failures.append((path, problem))
                print(f"FAILED {path}: {problem}", flush=True)

    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        list(pool.map(work, todo))

    print(f"Done: {len(uploaded)} of {total} uploaded, {len(failures)} failed.")
    for path, problem in failures:
        print(f"  {path}: {problem}")


if __name__ == "__main__":
    main()
