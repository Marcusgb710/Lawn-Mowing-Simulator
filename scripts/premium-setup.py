#!/usr/bin/env python3
"""Sets up the Robux catalog in src/shared/Config/Premium.luau on Roblox, through Open Cloud.

    python3 scripts/premium-setup.py            # do it
    python3 scripts/premium-setup.py --dry-run  # only say what it would do

For every game pass and developer product in Premium.luau:
  * with an id: puts it on sale at its `robux` price if it isn't already;
  * with id 0: creates it (or finds one already made with that name), on sale at its price, and
    writes the new id into Premium.luau.
Managed and regional pricing stay off, so the price is exactly the one in Premium.luau.

It needs an Open Cloud API key made under Big Dink Studios (Creator Dashboard > Open Cloud >
API Keys) with game-pass and developer-product read and write on this experience. It's read
from $ROBLOX_API_KEY or ~/.roblox-opencloud-key. Never commit the key.
"""

import json
import os
import re
import subprocess
import sys
import time

UNIVERSE = "10771693515"
CATALOG = "src/shared/Config/Premium.luau"
API = "https://apis.roblox.com"
PASSES = f"{API}/game-passes/v1/universes/{UNIVERSE}/game-passes"
PRODUCTS = f"{API}/developer-products/v2/universes/{UNIVERSE}/developer-products"
# Open Cloud allows a few writes a second.
WRITE_GAP = 0.6


def read_key():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        path = os.path.expanduser("~/.roblox-opencloud-key")
        if os.path.exists(path):
            key = open(path).read()
    key = (key or "").strip()
    if not key:
        sys.exit("No API key: set ROBLOX_API_KEY or save it to ~/.roblox-opencloud-key.")
    return key


def lua_string(text):
    # The catalog's strings are plain double-quoted, joined with `..`.
    return "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', text))


def read_catalog(source):
    """Every item with an id field: its id, name, price, description and where its id number is."""
    items = []
    starts = [m.start() for m in re.finditer(r'\bid = "', source)]
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(source)
        block = source[start:end]
        item_id = re.match(r'id = "(\w+)"', block).group(1)
        number = re.search(r"\b(gamePassId|productId) = (\d+)", block)
        if not number:
            continue
        name = re.search(r'\bname = "([^"]*)"', block).group(1)
        description = re.search(r'\bdescription = ((?:\s*"(?:[^"\\]|\\.)*"\s*(?:\.\.)?)+)', block)
        items.append({
            "id": item_id,
            "name": name,
            "robux": int(re.search(r"\brobux = (\d+)", block).group(1)),
            "kind": "pass" if number.group(1) == "gamePassId" else "product",
            "number": int(number.group(2)),
            # Where the id number sits in the file, to write a new one in.
            "at": start + number.start(2),
            "length": len(number.group(2)),
            # Paint jobs have no description in the catalog.
            "description": lua_string(description.group(1)) if description else f"A {name} paint job for your truck.",
        })
    return items


def call(key, method, url, fields=None):
    args = ["curl", "-s", "-w", "\n%{http_code}", "-X", method, "-H", "x-api-key: " + key]
    for field, value in (fields or {}).items():
        args += ["--form-string", f"{field}={value}"]
    result = subprocess.run(args + [url], capture_output=True, text=True)
    body, _, status = result.stdout.rpartition("\n")
    if not status.startswith("2"):
        sys.exit(f"{method} {url} failed: HTTP {status} {body[:400]}")
    return json.loads(body) if body.strip() else None


def listed(key, url, field):
    found, token = [], ""
    while True:
        page = call(key, "GET", f"{url}/creator?pageSize=50" + (f"&pageToken={token}" if token else ""))
        found += page.get(field) or []
        token = page.get("nextPageToken")
        if not token:
            return found


def price_of(entry):
    info = entry.get("priceInformation") or {}
    return info.get("defaultPriceInRobux")


def main():
    dry = "--dry-run" in sys.argv
    key = read_key()
    source = open(CATALOG).read()
    items = read_catalog(source)

    passes = {p["gamePassId"]: p for p in listed(key, PASSES, "gamePasses")}
    products = {p["productId"]: p for p in listed(key, PRODUCTS, "developerProducts")}
    by_name = {
        "pass": {p["name"]: p["gamePassId"] for p in passes.values()},
        "product": {p["name"]: p["productId"] for p in products.values()},
    }

    new_ids = {}
    for item in items:
        kind, url = item["kind"], PASSES if item["kind"] == "pass" else PRODUCTS
        existing = passes if kind == "pass" else products
        label = f'{kind:7} {item["name"]} ({item["robux"]} Robux)'
        on_sale = {
            "isForSale": "true",
            "price": str(item["robux"]),
            "isRegionalPricingEnabled": "false",
            "isManagedPricingEnabled": "false",
        }

        number = item["number"] or by_name[kind].get(item["name"], 0)
        if number:
            if item["number"] == 0:
                new_ids[item["id"]] = number
            entry = existing.get(number)
            if entry is None:
                sys.exit(f'{label}: id {number} isn\'t one of this game\'s {kind}s.')
            if entry.get("isForSale") and price_of(entry) == item["robux"]:
                print(f"ok       {label}: on sale, id {number}")
                continue
            print(f"on sale  {label}: id {number}")
            if not dry:
                call(key, "PATCH", f"{url}/{number}", on_sale)
                time.sleep(WRITE_GAP)
            continue

        print(f"create   {label}")
        if dry:
            continue
        made = call(key, "POST", url, {"name": item["name"], "description": item["description"], **on_sale})
        number = made["gamePassId"] if kind == "pass" else made["productId"]
        new_ids[item["id"]] = number
        print(f"         -> id {number}")
        time.sleep(WRITE_GAP)

    if new_ids and not dry:
        # Write from the end of the file back, so earlier positions stay right.
        for item in sorted(items, key=lambda i: i["at"], reverse=True):
            if item["id"] in new_ids:
                source = source[: item["at"]] + str(new_ids[item["id"]]) + source[item["at"] + item["length"] :]
        open(CATALOG, "w").write(source)
        print(f"Wrote {len(new_ids)} new id(s) into {CATALOG}.")
    elif dry:
        print("Dry run: nothing changed.")
    else:
        print("Nothing new to write.")


if __name__ == "__main__":
    main()
