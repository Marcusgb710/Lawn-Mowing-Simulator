#!/usr/bin/env python3
"""Finds faces in ChatGPT's models that would z-fight: two surfaces in the same plane, facing the
same way and overlapping, so the GPU can't tell which one is in front and they flicker as the
camera moves (worst on phones, which have less depth precision).

    python3 scripts/check-coplanar.py [model.gltf | pack folder ...] [options]

With no paths it reads every model in model-source/HighPoly/*/Models/<Id>/<Id>.gltf. It reads the
exported glTF geometry itself (not the build scripts, which only some packs ship), converts it to
studs (1 stud = 0.28 m), and for every pair of same-facing triangles that lie within --tol studs
of the same plane it measures how much of them overlaps.

With --assets it checks the models as they are in the game instead: it reads where
assets/<folder>/<Id>.rbxm puts each MeshPart (with Lune, so `lune` has to be on the PATH) and moves
the source meshes there first. Use that after nudging a MeshPart in an asset, since the sources
still have the old positions.

It reports two kinds of overlap:
  * between two different meshes (MeshParts), e.g. a collision floor under visible boards. Fix
    these by nudging the hidden or underlying MeshPart 0.02-0.05 studs off the plane;
  * inside one mesh, e.g. boards laid exactly on a slab. Moving a MeshPart can't separate those,
    so they have to be fixed in the model source.

Options:
  --tol T        how close two planes count as the same, in studs (default 0.005)
  --min-area A   smallest overlap between two meshes to report, in square studs (default 0.25)
  --min-self A   smallest overlap inside one mesh to report, in square studs (default 0.5)
  --all          also list the overlaps under those thresholds
  --move M=x,y,z try nudging mesh M by (x, y, z) studs first, to check a fix before making it in
                 the asset (can be repeated)
  --assets       check the meshes where assets/ has them (see above)
Faces underneath, flat on the model's lowest plane, are skipped: nothing sees them. Overlaps whose
faces are the same colour are listed as minor (they can't flicker between colours). Faces buried
inside another solid can't be seen either, but the checker can't tell, so look before fixing.
Exits with status 1 if anything is reported.
"""

import glob
import json
import math
import os
import struct
import subprocess
import sys
from collections import defaultdict

STUD = 0.28  # metres per stud, as in every high-poly pack
COMPONENTS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
AXES = "XYZ"


def read_accessor(gltf, buffers, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    data = buffers[view.get("buffer", 0)]
    fmt = COMPONENTS[acc["componentType"]]
    width = WIDTH[acc["type"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride") or size * width
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        values = struct.unpack_from("<" + fmt * width, data, start + i * stride)
        out.append(values if width > 1 else values[0])
    return out


def quat_matrix(q):
    x, y, z, w = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]


def node_matrix(node):
    """The node's local transform as a 3x4 [rotation*scale | translation] matrix."""
    if "matrix" in node:
        m = node["matrix"]  # column-major 4x4
        return [[m[0], m[4], m[8], m[12]], [m[1], m[5], m[9], m[13]], [m[2], m[6], m[10], m[14]]]
    r = quat_matrix(node.get("rotation", (0, 0, 0, 1)))
    s = node.get("scale", (1, 1, 1))
    t = node.get("translation", (0, 0, 0))
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]] for i in range(3)]


def compose(a, b):
    return [
        [sum(a[i][k] * b[k][j] for k in range(3)) + (a[i][3] if j == 3 else 0) for j in range(4)]
        for i in range(3)
    ]


def apply(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


class Colours:
    """Looks up the colour a face shows: its material's base colour times the colour map at the
    middle of its UVs (the packs use colour atlases, so that's the face's swatch). Needs Pillow for
    the texture; without it every face just gets its material's base colour."""

    def __init__(self):
        self.images = {}
        try:
            from PIL import Image

            self.Image = Image
        except ImportError:
            self.Image = None

    def sample(self, image_path, factor, uv):
        rgb = [factor[0], factor[1], factor[2]]
        if image_path and uv and self.Image:
            if image_path not in self.images:
                try:
                    self.images[image_path] = self.Image.open(image_path).convert("RGB")
                except OSError:
                    self.images[image_path] = None
            img = self.images[image_path]
            if img:
                u, v = uv[0] % 1.0, uv[1] % 1.0
                px = img.getpixel((min(int(u * img.width), img.width - 1), min(int(v * img.height), img.height - 1)))
                rgb = [rgb[i] * px[i] / 255 for i in range(3)]
        return tuple(round(c * 255) for c in rgb)


COLOURS = Colours()


def load_model(path):
    """Returns ({mesh name: [(a, b, c, colour), ...]}, {mesh name: node extras}): every triangle in
    model-local studs with the colour it shows."""
    with open(path) as f:
        gltf = json.load(f)
    folder = os.path.dirname(path)
    buffers = []
    for buf in gltf["buffers"]:
        with open(os.path.join(folder, buf["uri"]), "rb") as f:
            buffers.append(f.read())
    meshes, extras = {}, {}
    identity = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0]]
    scene = gltf["scenes"][gltf.get("scene", 0)]

    def material(index):
        if index is None:
            return None, (1, 1, 1)
        pbr = gltf["materials"][index].get("pbrMetallicRoughness", {})
        factor = pbr.get("baseColorFactor", (1, 1, 1, 1))
        image = None
        if "baseColorTexture" in pbr:
            source = gltf["textures"][pbr["baseColorTexture"]["index"]].get("source")
            uri = gltf["images"][source].get("uri") if source is not None else None
            image = os.path.normpath(os.path.join(folder, uri.replace("%20", " "))) if uri else None
        return image, factor

    def visit(index, parent, depth):
        node = gltf["nodes"][index]
        # The model root's own transform is only its slot in a combined library; skip it.
        world = compose(parent, node_matrix(node)) if depth > 0 else parent
        if "mesh" in node:
            name = node.get("name", f"mesh{node['mesh']}")
            tris = meshes.setdefault(name, [])
            extras[name] = node.get("extras", {})
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                pos = [
                    tuple(c / STUD for c in apply(world, p))
                    for p in read_accessor(gltf, buffers, prim["attributes"]["POSITION"])
                ]
                uvs = None
                if "TEXCOORD_0" in prim["attributes"]:
                    uvs = read_accessor(gltf, buffers, prim["attributes"]["TEXCOORD_0"])
                image, factor = material(prim.get("material"))
                idx = read_accessor(gltf, buffers, prim["indices"]) if "indices" in prim else range(len(pos))
                for i in range(0, len(idx) - 2, 3):
                    a, b, c = idx[i], idx[i + 1], idx[i + 2]
                    uv = None
                    if uvs:
                        uv = ((uvs[a][0] + uvs[b][0] + uvs[c][0]) / 3, (uvs[a][1] + uvs[b][1] + uvs[c][1]) / 3)
                    tris.append((pos[a], pos[b], pos[c], (image, factor, uv)))
        for child in node.get("children", []):
            visit(child, world, depth + 1)

    for root in scene["nodes"]:
        visit(root, identity, 0)
    return meshes, extras


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def area2d(poly):
    s = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        s += x1 * y2 - x2 * y1
    return s / 2


def clip(subject, clipper):
    """Sutherland-Hodgman: subject polygon clipped by a convex, counter-clockwise clipper."""
    out = subject
    for i in range(len(clipper)):
        if not out:
            break
        ax, ay = clipper[i]
        bx, by = clipper[(i + 1) % len(clipper)]
        inp, out = out, []

        def inside(p):
            return (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax) >= -1e-12

        def cut(p, q):
            dx1, dy1 = q[0] - p[0], q[1] - p[1]
            dx2, dy2 = bx - ax, by - ay
            den = dx1 * dy2 - dy1 * dx2
            if abs(den) < 1e-18:
                return q
            t = ((ax - p[0]) * dy2 - (ay - p[1]) * dx2) / den
            return (p[0] + dx1 * t, p[1] + dy1 * t)

        for j in range(len(inp)):
            p, q = inp[j - 1], inp[j]
            if inside(q):
                if not inside(p):
                    out.append(cut(p, q))
                out.append(q)
            elif inside(p):
                out.append(cut(p, q))
    return out


def check_model(path, tol, moves=None, asset_parts=None):
    meshes, extras = load_model(path)
    moves = dict(moves or {})
    if asset_parts:
        moves.update(asset_offsets(meshes, asset_parts))
    for name, (dx, dy, dz) in moves.items():
        if name in meshes:
            meshes[name] = [
                tuple((p[0] + dx, p[1] + dy, p[2] + dz) for p in t[:3]) + (t[3],) for t in meshes[name]
            ]
    # Group triangles by facing (normal rounded to 0.002) so only same-facing faces are compared.
    # Faces that touch back to back (a top on a bottom) can't be seen at once, so they don't fight.
    buckets = defaultdict(list)
    ground = min((p[1] for tris in meshes.values() for t in tris for p in t[:3]), default=0)
    for mesh, tris in meshes.items():
        for a, b, c, look in tris:
            n = cross(sub(b, a), sub(c, a))
            length = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
            if length < 1e-7:
                continue
            n = (n[0] / length, n[1] / length, n[2] / length)
            if n[1] < -0.99 and max(a[1], b[1], c[1]) <= ground + tol:
                continue  # the underside, flat on the ground: never seen
            key = tuple(round(v * 500) for v in n)
            d = n[0] * a[0] + n[1] * a[1] + n[2] * a[2]
            buckets[key].append((d, mesh, (a, b, c), n, look))

    found = defaultdict(lambda: {"area": 0.0, "gap": 0.0, "lo": None, "hi": None, "colours": defaultdict(float)})
    for key, items in buckets.items():
        if len(items) < 2:
            continue
        items.sort(key=lambda t: t[0])
        start = 0
        while start < len(items):
            end = start + 1
            while end < len(items) and items[end][0] - items[end - 1][0] <= tol:
                end += 1
            if end - start > 1:
                compare(items[start:end], tol, found)
            start = end
    return found, extras, moves


def compare(cluster, tol, found):
    n = cluster[0][3]
    drop = max(range(3), key=lambda i: abs(n[i]))
    keep = [i for i in range(3) if i != drop]
    flat = []
    for d, mesh, tri, _, look in cluster:
        poly = [(p[keep[0]], p[keep[1]]) for p in tri]
        if area2d(poly) < 0:
            poly.reverse()
        xs, ys = [p[0] for p in poly], [p[1] for p in poly]
        flat.append((d, mesh, tri, poly, (min(xs), min(ys), max(xs), max(ys)), look))
    sizes = sorted(max(f[4][2] - f[4][0], f[4][3] - f[4][1]) for f in flat)
    cell = max(sizes[len(sizes) // 2], 0.05)
    grid = defaultdict(list)
    for i, (*_, box, _) in enumerate(flat):
        x0, y0 = int(math.floor(box[0] / cell)), int(math.floor(box[1] / cell))
        x1, y1 = int(math.floor(box[2] / cell)), int(math.floor(box[3] / cell))
        if (x1 - x0 + 1) * (y1 - y0 + 1) > 4096:
            grid["big"].append(i)  # a huge face: compare it with everything in the plane
            continue
        for gx in range(x0, x1 + 1):
            for gy in range(y0, y1 + 1):
                grid[(gx, gy)].append(i)
    big = grid.pop("big", [])
    seen = set()
    pairs = []
    for members in grid.values():
        for ii in range(len(members)):
            for jj in range(ii + 1, len(members)):
                pairs.append((members[ii], members[jj]))
    for i in big:
        for j in range(len(flat)):
            if j != i:
                pairs.append((min(i, j), max(i, j)))
    for i, j in pairs:
        if (i, j) in seen or i == j:
            continue
        seen.add((i, j))
        di, mi, ti, pi, bi, li = flat[i]
        dj, mj, tj, pj, bj, lj = flat[j]
        if abs(di - dj) > tol:
            continue
        if bi[2] <= bj[0] or bj[2] <= bi[0] or bi[3] <= bj[1] or bj[3] <= bi[1]:
            continue
        overlap = clip(pi, pj)
        if len(overlap) < 3:
            continue
        area = abs(area2d(overlap))
        if area < 1e-5:
            continue
        a, b = sorted((mi, mj))
        ca, cb = COLOURS.sample(*li), COLOURS.sample(*lj)
        if mi != a:
            ca, cb = cb, ca
        # Name the plane by the way it faces and where it is, e.g. "+Y 1.600" for an upward face
        # at Y = 1.6; a tilted one by its normal and its distance along it.
        if max(abs(n[k]) for k in keep) > 0.002:
            plane = f"normal ({n[0]:.3f}, {n[1]:.3f}, {n[2]:.3f}) at {(di + dj) / 2:.3f}"
        else:
            sign = "+" if n[drop] > 0 else "-"
            plane = f"{sign}{AXES[drop]} {(di + dj) / 2 * (1 if n[drop] > 0 else -1):.3f}"
        entry = found[(a, b, plane)]
        entry["area"] += area
        entry["gap"] = max(entry["gap"], abs(di - dj))
        entry["colours"][tuple(sorted((ca, cb))) if a == b else (ca, cb)] += area
        # Where it is: the overlap of the two triangles' bounding boxes.
        lo = tuple(max(min(p[k] for p in ti), min(p[k] for p in tj)) for k in range(3))
        hi = tuple(min(max(p[k] for p in ti), max(p[k] for p in tj)) for k in range(3))
        entry["lo"] = lo if entry["lo"] is None else tuple(map(min, entry["lo"], lo))
        entry["hi"] = hi if entry["hi"] is None else tuple(map(max, entry["hi"], hi))


# Prints {rbxm path: {part name: CFrame components}} for the files it's given (false for a name
# used twice, which can't be matched to one mesh).
ASSET_READER = """
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local out = {}
for _, path in process.args do
    local parts = {}
    if fs.isFile(path) then
        for _, root in roblox.deserializeModel(fs.readFile(path)) do
            for _, d in root:GetDescendants() do
                if d:IsA("BasePart") then
                    parts[d.Name] = if parts[d.Name] == nil then { d.CFrame:GetComponents() } else false
                end
            end
        end
    end
    out[path] = parts
end
print(serde.encode("json", out))
"""


def asset_path(gltf_path):
    with open(gltf_path) as f:
        gltf = json.load(f)
    root = gltf["nodes"][gltf["scenes"][gltf.get("scene", 0)]["nodes"][0]]
    model = os.path.splitext(os.path.basename(gltf_path))[0]
    return os.path.join("assets", root.get("extras", {}).get("folder", ""), model + ".rbxm")


def read_assets(files):
    """{gltf path: {part name: CFrame components}} from each model's asset, read with Lune."""
    rbxm = {path: asset_path(path) for path in files}
    result = subprocess.run(
        ["lune", "run", "-", *rbxm.values()], input=ASSET_READER, capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.exit(f"couldn't read the assets with lune:\n{result.stderr}")
    parts = json.loads(result.stdout)
    return {path: parts.get(asset) or {} for path, asset in rbxm.items()}


def asset_offsets(meshes, parts):
    """How far the asset has moved each mesh from the source. A MeshPart imported from glTF sits at
    the centre of its mesh's bounding box, unrotated."""
    out = {}
    for name, tris in meshes.items():
        c = parts.get(name)
        if not c:
            continue
        if max(abs(c[3 + i] - (1 if i in (0, 4, 8) else 0)) for i in range(9)) > 1e-4:
            print(f"  ({name} is rotated in its asset; checked where the source has it)")
            continue
        pts = [p for t in tris for p in t[:3]]
        centre = [(min(p[i] for p in pts) + max(p[i] for p in pts)) / 2 for i in range(3)]
        offset = tuple(c[i] - centre[i] for i in range(3))
        if max(abs(v) for v in offset) > 5e-4:
            out[name] = offset
    return out


def alike(a, b):
    return sum((a[i] - b[i]) ** 2 for i in range(3)) < 16**2


def hexrgb(c):
    return "#%02x%02x%02x" % c


def fmt_vec(v):
    return "(" + ", ".join(f"{x:.2f}" for x in v) + ")"


def main(argv):
    tol, min_area, min_self, show_all, paths, moves, assets = 0.005, 0.25, 0.5, False, [], {}, False
    args = iter(argv)
    for arg in args:
        if arg == "--tol":
            tol = float(next(args))
        elif arg == "--min-area":
            min_area = float(next(args))
        elif arg == "--min-self":
            min_self = float(next(args))
        elif arg == "--all":
            show_all = True
        elif arg == "--move":
            name, _, offset = next(args).partition("=")
            moves[name] = tuple(float(v) for v in offset.split(","))
        elif arg == "--assets":
            assets = True
        elif arg in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            paths.append(arg)
    if not paths:
        paths = ["model-source/HighPoly"]
    files = []
    for path in paths:
        if os.path.isdir(path):
            files += sorted(glob.glob(os.path.join(path, "**", "Models", "*", "*.gltf"), recursive=True))
            files += sorted(glob.glob(os.path.join(path, "Models", "*", "*.gltf")))
        else:
            files.append(path)
    files = sorted(set(files))
    if not files:
        print("no models found", file=sys.stderr)
        return 2

    in_game = read_assets(files) if assets else {}
    reported = 0
    for path in files:
        found, extras, moved = check_model(path, tol, moves, in_game.get(path))
        model = os.path.splitext(os.path.basename(path))[0]
        lines = [f"  ({name} moved by {fmt_vec(offset)})" for name, offset in sorted(moved.items())]
        for (a, b, plane), e in sorted(found.items(), key=lambda kv: -kv[1]["area"]):
            same = a == b
            # Faces of the same colour don't visibly flicker, so they're only minor.
            pairs = sorted(e["colours"].items(), key=lambda kv: -kv[1])
            differs = sum(area for (ca, cb), area in pairs if not alike(ca, cb))
            real = e["area"] >= (min_self if same else min_area) and differs >= 0.5 * e["area"]
            if not real and not show_all:
                continue
            if same:
                what = f"inside {a} [{extras.get(a, {}).get('role', '?')}]"
            else:
                what = f"{a} [{extras.get(a, {}).get('role', '?')}] / {b} [{extras.get(b, {}).get('role', '?')}]"
            (ca, cb), _ = pairs[0]
            if differs >= 0.5 * e["area"]:
                ca, cb = next(pair for pair, _ in pairs if not alike(*pair))
                colour = f"{hexrgb(ca)} vs {hexrgb(cb)}"
            else:
                colour = f"same colour {hexrgb(ca)}"
            mark = "  " if real else "  (minor) "
            lines.append(
                f"{mark}{what}: plane {plane}, {e['area']:.2f} sq studs, {colour}, "
                f"gap {e['gap']:.4f}, around {fmt_vec(e['lo'])}..{fmt_vec(e['hi'])}"
            )
            if real:
                reported += 1
        if lines:
            print(f"{model}  ({os.path.relpath(path)})")
            print("\n".join(lines))
    print(f"checked {len(files)} models: {reported} coplanar overlaps over the thresholds")
    return 1 if reported else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
