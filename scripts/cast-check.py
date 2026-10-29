#!/usr/bin/env python3
"""Asks Roblox's catalog about every item the story's cast wears (src/shared/Config/Cast.luau).

    python scripts/cast-check.py [--list] [--cast PATH] [--catalog-only]

CastService dresses each person with HumanoidDescription, which only works for items that are
public. So every id in Cast.luau has to be free, not limited, and the kind of item its slot says.
It reads `hair`, `hat`, `face`, `shirt`, `pants`, `tshirt` and each `id` in a `layered` list, and for
every id above 0 (a `tshirt = 0` is the crown graphic that isn't uploaded yet) it asks
https://economy.roblox.com/v2/assets/<id>/details (no key) and checks:
  * IsForSale or IsPublicDomain is true, so the item can be used;
  * PriceInRobux is 0 or missing;
  * IsLimited and IsLimitedUnique are false, and it isn't a collectible with a limited quantity;
  * AssetTypeId fits the slot: hair 41, hat 8, face 18, shirt 11, pants 12, tshirt 2, and a layered
    garment 64 to 72 (the one its `type` names: TShirt 64, Shirt 65, Pants 66, Jacket 67,
    Sweater 68, Shorts 69, LeftShoe 70, RightShoe 71, DressSkirt 72).
If the economy API is rate limited or refuses (after retries), the same facts for those ids come
from the catalog API instead (one POST to https://catalog.roblox.com/v1/catalog/items/details), and
the line before `Cast OK` says how many ids each one answered. "By Roblox" is preferred for the
cast but not required (the design's ruling 3), so the creator is only printed.

It prints `Cast OK`, or every failure with the person, slot, id, name and creator, and exits with
status 1. Options:
  --list          only print the ids it found in Cast.luau, without asking the catalog
  --cast PATH     read another file than src/shared/Config/Cast.luau (to try the check)
  --catalog-only  skip the economy API and use the catalog API for everything
There is a 0.3 second pause between calls.
"""

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAST = ROOT / "src" / "shared" / "Config" / "Cast.luau"
ECONOMY_URL = "https://economy.roblox.com/v2/assets/{}/details"
CATALOG_URL = "https://catalog.roblox.com/v1/catalog/items/details"
PAUSE = 0.3  # seconds between calls
RETRIES = 4

# AssetTypeId of each slot.
SLOTS = {"hair": 41, "hat": 8, "face": 18, "shirt": 11, "pants": 12, "tshirt": 2}
# A layered garment's Enum.AccessoryType name and its AssetTypeId (64 to 72 are the layered types).
LAYERED = {
    "TShirt": 64,
    "Shirt": 65,
    "Pants": 66,
    "Jacket": 67,
    "Sweater": 68,
    "Shorts": 69,
    "LeftShoe": 70,
    "RightShoe": 71,
    "DressSkirt": 72,
}
TYPE_NAMES = {
    2: "T-shirt",
    8: "hat",
    11: "shirt",
    12: "pants",
    18: "face",
    41: "hair",
    64: "layered T-shirt",
    65: "layered shirt",
    66: "layered pants",
    67: "layered jacket",
    68: "layered sweater",
    69: "layered shorts",
    70: "layered left shoe",
    71: "layered right shoe",
    72: "layered skirt",
}


def type_name(type_id):
    return TYPE_NAMES.get(type_id, f"type {type_id}")


# Reading Cast.luau ------------------------------------------------------------------------------


def strip_comments(text):
    return "\n".join(re.sub(r"--.*$", "", line) for line in text.splitlines())


def matching_brace(text, open_at):
    """Index of the } that closes the { at `open_at`."""
    depth = 0
    for index in range(open_at, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("unbalanced braces in Cast.luau")


def parse_cast(text):
    """Every catalog id a person wears: [(person, slot, id, AssetTypeIds it may be)]."""
    body = strip_comments(text)
    table = re.search(r"^Cast\.People\s*=\s*\{[ \t]*$", body, re.M)
    if not table:
        raise ValueError("no `Cast.People = {` in Cast.luau")
    start = table.end() - 1
    people = body[start + 1 : matching_brace(body, start)]
    # Each person is a table one tab in: `\tNPC_Gloria = {`.
    heads = list(re.finditer(r"^\t(\w+)\s*=\s*\{", people, re.M))
    if not heads:
        raise ValueError("no people in Cast.People")
    uses = []
    for head in heads:
        who = head.group(1)
        open_at = head.end() - 1
        block = people[open_at + 1 : matching_brace(people, open_at)]
        layered = re.search(r"\blayered\s*=\s*\{", block)
        if layered:
            close = matching_brace(block, layered.end() - 1)
            for garment in re.finditer(r"\{([^{}]*)\}", block[layered.end() : close]):
                fields = garment.group(1)
                found_id = re.search(r"\bid\s*=\s*([^,\s}]+)", fields)
                found_type = re.search(r'\btype\s*=\s*"(\w+)"', fields)
                if not found_id:
                    continue
                kind = found_type.group(1) if found_type else "?"
                allowed = {LAYERED[kind]} if kind in LAYERED else set(range(64, 73))
                uses.append((who, f"layered {kind}", plain_id(who, "layered id", found_id.group(1)), allowed))
            block = block[: layered.start()] + block[close + 1 :]
        for slot, type_id in SLOTS.items():
            for found in re.finditer(rf"\b{slot}\s*=\s*([^,\s}}]+)", block):
                value = found.group(1)
                if value != "nil":
                    uses.append((who, slot, plain_id(who, slot, value), {type_id}))
    return uses


def plain_id(who, slot, value):
    """An id written as a plain number. Anything else (a local, a sum) the check couldn't read."""
    if not value.isdigit():
        raise ValueError(f"{who} {slot} is `{value}`: write the id out as a number so it can be checked")
    return int(value)


# Asking the catalog -----------------------------------------------------------------------------


class Refused(Exception):
    """The API turned the request down (rate limited for good, or forbidden)."""


class Missing(Exception):
    """The API has no such item."""


def request(url, body=None, token=None):
    """JSON from `url`, retrying a rate limit or a server hiccup; (data, csrf token header)."""
    headers = {"User-Agent": "LawnMowingSimulator-cast-check", "Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["X-CSRF-TOKEN"] = token
    payload = json.dumps(body).encode() if body is not None else None
    delay = 2.0
    last = None
    for attempt in range(RETRIES):
        req = urllib.request.Request(url, data=payload, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                return json.load(response), token
        except urllib.error.HTTPError as err:
            last = f"HTTP {err.code}"
            if err.code == 404:
                raise Missing(last) from err
            if err.code == 403 and body is not None and err.headers.get("x-csrf-token"):
                # A POST's first answer hands out the token to send it again with.
                token = err.headers["x-csrf-token"]
                headers["X-CSRF-TOKEN"] = token
                continue
            if err.code not in (429, 500, 502, 503, 504):
                raise Refused(last) from err
            wait = err.headers.get("retry-after")
            time.sleep(float(wait) if wait and wait.isdigit() else delay)
        except (urllib.error.URLError, TimeoutError, OSError) as err:
            last = str(err)
            time.sleep(delay)
        delay *= 2
    raise Refused(last or "no answer")


def from_economy(asset_id):
    data, _ = request(ECONOMY_URL.format(asset_id))
    collectible = data.get("CollectiblesItemDetails") or {}
    return {
        "source": "economy",
        "name": data.get("Name") or "?",
        "creator": (data.get("Creator") or {}).get("Name") or "?",
        "type": data.get("AssetTypeId"),
        "usable": bool(data.get("IsForSale") or data.get("IsPublicDomain")),
        "price": data.get("PriceInRobux"),
        "limited": bool(data.get("IsLimited") or data.get("IsLimitedUnique")),
        "limited_quantity": (collectible.get("TotalQuantity") or 0) > 0,
    }


def from_catalog(ids):
    """Facts for many ids at once from the catalog API (one POST for up to 100): {id: facts}."""
    found = {}
    token = None
    for first in range(0, len(ids), 100):
        body = {"items": [{"itemType": "Asset", "id": asset_id} for asset_id in ids[first : first + 100]]}
        data, token = request(CATALOG_URL, body, token)
        for item in data.get("data") or []:
            restrictions = item.get("itemRestrictions") or []
            off_sale = bool(item.get("isOffSale")) or item.get("priceStatus") == "Off Sale"
            found[item["id"]] = {
                "source": "catalog",
                "name": item.get("name") or "?",
                "creator": item.get("creatorName") or "?",
                "type": item.get("assetType"),
                "usable": not off_sale,
                "price": item.get("price", 0 if item.get("priceStatus") == "Free" else None),
                "limited": "Limited" in restrictions or "LimitedUnique" in restrictions,
                "limited_quantity": (item.get("totalQuantity") or 0) > 0,
            }
    return found


def look_up(ids, catalog_only):
    """({id: facts}, {id: why there are none}) for every id: the economy API one by one, then the
    catalog API for whatever it would not answer."""
    facts, why = {}, {}
    todo = []
    for number, asset_id in enumerate(ids):
        if catalog_only:
            todo.append(asset_id)
            continue
        if number:
            time.sleep(PAUSE)
        try:
            facts[asset_id] = from_economy(asset_id)
        except Missing:
            todo.append(asset_id)  # the catalog API has the last word on whether it exists
        except Refused as err:
            print(f"economy API refused {asset_id} ({err}), asking the catalog API")
            todo.append(asset_id)
    if todo:
        if not catalog_only:
            time.sleep(PAUSE)
        try:
            facts.update(from_catalog(todo))
        except Missing as err:
            for asset_id in todo:
                why[asset_id] = f"no such item ({err})"
        except Refused as err:
            for asset_id in todo:
                why[asset_id] = f"neither API would answer ({err})"
        for asset_id in todo:
            if asset_id not in facts and asset_id not in why:
                why[asset_id] = "no such item in the catalog"
    return facts, why


def problems(facts, allowed):
    found = []
    if not facts["usable"]:
        found.append("it is neither for sale nor public domain")
    if facts["price"] not in (0, None):
        found.append(f"it costs {facts['price']} Robux")
    if facts["limited"]:
        found.append("it is a limited item")
    if facts["limited_quantity"]:
        found.append("it is a collectible with a limited quantity")
    if facts["type"] not in allowed:
        wanted = " or ".join(f"{type_name(t)} (type {t})" for t in sorted(allowed))
        found.append(f"it is a {type_name(facts['type'])} (type {facts['type']}) but this slot takes {wanted}")
    return found


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="Checks the cast's catalog ids against Roblox's catalog.")
    parser.add_argument("--list", action="store_true", help="only list the ids found in Cast.luau")
    parser.add_argument("--cast", type=Path, default=CAST, help="the Cast.luau to read")
    parser.add_argument("--catalog-only", action="store_true", help="use the catalog API, not the economy API")
    args = parser.parse_args()

    try:
        uses = parse_cast(args.cast.read_text(encoding="utf-8"))
    except (OSError, ValueError) as err:
        print(f"FAIL  cannot read the cast: {err}")
        return 1

    for who, slot, asset_id, _ in uses:
        if args.list:
            print(f"{who:18} {slot:16} {asset_id}")
    if args.list:
        return 0
    for who, slot, asset_id, _ in uses:
        if asset_id == 0:
            print(f"pending {who} {slot}: id 0 is a placeholder until its graphic is uploaded")

    ids = sorted({asset_id for _, _, asset_id, _ in uses if asset_id > 0})
    facts, why = look_up(ids, args.catalog_only)

    failures = 0
    for who, slot, asset_id, allowed in uses:
        if asset_id == 0:
            continue
        item = facts.get(asset_id)
        if item is None:
            failures += 1
            print(f"FAIL  {who} {slot} {asset_id}: {why[asset_id]}")
            continue
        for reason in problems(item, allowed):
            failures += 1
            print(f'FAIL  {who} {slot} {asset_id} "{item["name"]}" by {item["creator"]}: {reason}')

    if failures:
        print(f"{failures} problem(s) with the cast's items")
        return 1
    via = {}
    for item in facts.values():
        via[item["source"]] = via.get(item["source"], 0) + 1
    print(f"{len(ids)} catalog ids checked (" + ", ".join(f"{n} by the {s} API" for s, n in via.items()) + ")")
    print("Cast OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
