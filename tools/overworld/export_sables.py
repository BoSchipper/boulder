"""Writes Les Sables d'Or, the first area of the game, for the 3D overworld: the same
layout as the 2D original (scripts/world.gd), with sand clearings and paths through the
forest, your tent and camp fire, the people you meet there, the seven blocks of the yellow
circuit. Each block in 3D has the outline of its own climbing wall (tools/rots), so you
see from the path what you will climb.

    python3 tools/overworld/export_sables.py assets/overworld/sables

Shared textures and sprites are copied from Bas Cuvier (export_area.py writes those).
"""
import json
import os
import shutil
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, zoom, distance_transform_edt

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "rots"))
import rock_forms as rf
sys.path.insert(0, os.path.dirname(__file__))
import sprites_hd

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/overworld/sables"
SHARED = os.path.join(os.path.dirname(OUT), "bas_cuvier")
os.makedirs(OUT, exist_ok=True)
T = 0.9          # metres per tile of the 2D original
TW, TH = 60, 36  # the original's size in tiles
CELL = 0.1       # metres per height sample
PX = 0.02        # metres per pixel of a climbing wall
GX, GZ = int(TW * T / CELL), int(TH * T / CELL)
X, Z = np.mgrid[0:GX, 0:GZ] * CELL
rng = np.random.default_rng(31)


def vnoise2(shape, cell, seed):
    g = np.random.default_rng(seed).random((shape[0] // cell + 3, shape[1] // cell + 3))
    return zoom(g, cell, order=3)[: shape[0], : shape[1]]


def tiles(x, z):
    return x * T, z * T


# ---------------------------------------------------------------- ground
SAND = [  # from world.gd, in tiles: clearings, then the paths between them
    (3, 23, 10, 7), (4, 29, 10, 4), (21, 21, 11, 8), (14, 5, 11, 8), (33, 4, 13, 8), (43, 19, 11, 9),
    (13, 25, 8, 2), (22, 13, 2, 8), (25, 7, 8, 2), (44, 12, 2, 7), (32, 23, 11, 2), (54, 22, 6, 2),
    (26, 29, 2, 2), (24, 31, 6, 2),
]
PATHS = SAND[6:]
# Clearings become soft round shapes, paths wander: nothing square, like a real forest.
warp_x = (vnoise2((GX, GZ), 60, 5) - 0.5) * 2.0
warp_z = (vnoise2((GX, GZ), 60, 6) - 0.5) * 2.0
edge = (vnoise2((GX, GZ), 26, 3) - 0.5) * 0.35
WX, WZ = X + warp_x, Z + warp_z
sand = np.zeros((GX, GZ), bool)
path = np.zeros((GX, GZ), bool)
for k, (x, z, w, h) in enumerate(SAND):
    x0, z0 = tiles(x, z)
    x1, z1 = tiles(x + w, z + h)
    cx, cz, ax, az = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2, (z1 - z0) / 2
    if k < 6:
        # a clearing: a rounded blob, a little bigger than the original rectangle
        d = ((np.abs(WX - cx) / (ax + 0.6)) ** 2.6 + (np.abs(WZ - cz) / (az + 0.6)) ** 2.6) ** (1 / 2.6)
        sand |= d < 1 + edge
    else:
        # a path: a winding band along the long side of its rectangle, varying in width
        if ax >= az:
            t = np.clip((WX - x0) / max(x1 - x0, 0.1), 0, 1)
            mid = cz + 0.5 * np.sin(t * 5 + k)
            d = np.abs(WZ - mid)
            span = (WX > x0 - 1.0) & (WX < x1 + 1.0)
        else:
            t = np.clip((WZ - z0) / max(z1 - z0, 0.1), 0, 1)
            mid = cx + 0.5 * np.sin(t * 5 + k)
            d = np.abs(WX - mid)
            span = (WZ > z0 - 1.0) & (WZ < z1 + 1.0)
        width = 0.75 + 0.25 * np.sin(t * 7 + k * 2) + edge * 0.6
        inside = span & (d < width)
        sand |= inside
        path |= inside
hgt = 0.35 + 0.35 * vnoise2((GX, GZ), 60, 1) + 0.08 * vnoise2((GX, GZ), 8, 2)
# The forest floor rises a little away from the sand, so the clearings feel like hollows.
away = distance_transform_edt(~sand) * CELL
hgt += 0.5 * np.clip(away / 4.0, 0, 1)
surf = np.full((GX, GZ), 3)                                   # moss
surf[vnoise2((GX, GZ), 30, 41) > 0.58] = 2                    # needles
surf[(vnoise2((GX, GZ), 22, 42) > 0.74) & (away > 1.5)] = 6   # heather
surf[sand] = 1
surf[path] = 4

# ---------------------------------------------------------------- the blocks
# The circuit teaches the holds one by one: rims and climbing out (1), slopers (2),
# underclings (3), side pulls (4), all three on La Lame (5), then a jump (6) and a roof (7).
BLOCKS = [  # route (climbing wall), circuit number, where in tiles, seed of its surface bumps
    ("premiere", 1, 9.0, 25.6, 1),
    ("toboggan", 2, 23.4, 23.6, 2),
    ("dalle", 3, 29.6, 26.2, 3),
    ("potdechalk", 4, 19.5, 9.0, 4),
    ("saut", 6, 38.5, 7.6, 5),
    ("toit", 7, 48.0, 23.2, 6),
]
LATE = [  # blocks raised after the forest was planted, so the trees kept their places
    ("lame", 5, 45.1, 6.0, 0),  # beside Le Saut
]
boulders = []
rock = np.zeros((GX, GZ), bool)
which = np.zeros((GX, GZ), np.uint8)  # which block a rock cell belongs to, 1-based


def place_block(route, n, tx, tz, idx, bid, seed):
    """Raises one block out of the ground, in the outline of its climbing wall."""
    global hgt
    rf.configure(route)
    mask = rf.INSIDE
    cols = np.nonzero(mask.any(axis=0))[0]
    top_row = np.where(mask.any(axis=0), mask.argmax(axis=0), rf.FLOOR)
    col_h = (rf.FLOOR - top_row) * PX                         # how high the block stands, per column
    width = (cols.max() - cols.min()) * PX
    cx, cz = tiles(tx, tz)
    rz = max(1.3, width * 0.32)
    u = rf.CX + (X - cx) / PX
    ui = np.clip(u.astype(int), 0, rf.W - 1)
    within = (u >= cols.min()) & (u <= cols.max()) & (np.abs(Z - cz) < rz)
    dz = (Z - cz) / rz
    bump = 0.08 * (vnoise2((GX, GZ), 6, 50 + seed) - 0.5)
    side = np.clip(1 - np.abs((X - cx) / (width / 2 + 0.2)) ** 5, 0, 1) ** 0.25  # rounded at the sides
    tilt = 1 + 0.12 * (X - cx) / (width / 2) - 0.1 * dz                       # Font blocks lean a little
    hh = np.where(within, col_h[ui] * np.clip(1 - np.abs(dz) ** 2.6, 0, 1) ** 0.42 * side * tilt + bump, 0)
    base = hgt.copy()
    base_y = float(base[within].min()) if within.any() else 0.4
    hgt = np.maximum(hgt, base + hh)
    S = rf.SPEC
    return within & (hh > 0.15), {"id": bid, "route": route, "n": n, "name": S["title"], "grade": S["grade"],
                                  "x": cx, "z": cz, "rx": width / 2, "rz": rz, "front": cz + rz, "base_y": base_y, "idx": idx}


for idx, (route, n, tx, tz, seed) in enumerate(BLOCKS):
    m, b = place_block(route, n, tx, tz, idx, "geel%d" % n, seed)
    rock |= m
    which[m] = idx + 1
    boulders.append(b)
# Late blocks stand in the ground now, but count as rock only once the forest and the plants
# are placed: those keep their places, only what stands on the block goes.
extra = [place_block(route, n, tx, tz, len(BLOCKS) + k, "geel%d" % n, seed) for k, (route, n, tx, tz, seed) in enumerate(LATE)]
hgt = gaussian_filter(hgt, 0.7)
surf[rock] = 5

# ---------------------------------------------------------------- the forest
# Trees fill everything that is not sand, not too close to the clearings: like the 2D
# map, where the forest is the wall. A ring outside the map hides the edge.
near_block = np.zeros((GX, GZ), bool)
for b in boulders:
    near_block |= np.hypot((X - b["x"]) / (b["rx"] + 1.5), (Z - b["z"]) / (b["rz"] + 1.5)) < 1
trees = []
kinds = ["spruce", "pine", "broadleaf", "birch"]
for gz in np.arange(0.6, TH * T, 2.4):
    for gx in np.arange(0.6, TW * T, 2.4):
        x, z = gx + rng.uniform(-0.9, 0.9), gz + rng.uniform(-0.9, 0.9)
        i, j = int(x / CELL), int(z / CELL)
        if not (0 <= i < GX and 0 <= j < GZ) or away[i, j] < 1.1 or near_block[i, j]:
            continue
        k = rng.choice(kinds, p=[0.38, 0.27, 0.2, 0.15])
        h = {"spruce": rng.uniform(4.5, 6.5), "pine": rng.uniform(7, 10), "broadleaf": rng.uniform(3.5, 4.6), "birch": rng.uniform(4.2, 5.4)}[k]
        # The camera looks from the south: on that side of a clearing only low bushes, so
        # the forest never stands between you and the camera.
        j0 = max(int((z - 8.0) / CELL), 0)
        i0, i1 = max(int((x - 2.5) / CELL), 0), min(int((x + 2.5) / CELL), GX)
        if sand[i0:i1, j0:j].any():
            k, h = "broadleaf", rng.uniform(1.4, 2.0)
        trees.append([str(k), round(x, 2), round(z, 2), round(h, 2), int(rng.integers(1, 9999))])
for k in range(170):
    a = rng.uniform(0, 2 * np.pi)
    x = TW * T / 2 + np.cos(a) * TW * T * rng.uniform(0.55, 0.8)
    z = TH * T / 2 + np.sin(a) * TH * T * rng.uniform(0.6, 0.95)
    if (0 < x < TW * T and 0 < z < TH * T) or z > TH * T - 2:
        continue  # not inside, and not on the camera side
    kk = "spruce" if rng.random() < 0.5 else "pine"
    trees.append([kk, round(x, 2), round(z, 2), round(rng.uniform(5, 10), 2), int(rng.integers(1, 9999))])

for k in range(160):  # the forest goes on behind the area
    x, z = rng.uniform(-12, TW * T + 12), rng.uniform(-28, -1)
    kk = "spruce" if rng.random() < 0.45 else ("pine" if rng.random() < 0.8 else "birch")
    trees.append([kk, round(x, 2), round(z, 2), round(rng.uniform(5, 10), 2), int(rng.integers(1, 9999))])

plants = []
noise_t = vnoise2((GX, GZ), 18, 55)
for k in range(16000):
    x, z = rng.uniform(0, TW * T - 0.2), rng.uniform(0, TH * T - 0.2)
    i, j = min(int(x / CELL), GX - 1), min(int(z / CELL), GZ - 1)
    m = surf[i, j]
    if m in (4, 5) or (m == 1 and rng.random() < 0.95) or (m == 2 and rng.random() < 0.55):
        continue
    if m == 3 and noise_t[i, j] < 0.38:
        continue
    kind = 2 if m == 6 else (1 if m == 2 else 0)
    plants.append([round(x, 3), round(z, 3), int(kind * 6 + rng.integers(6))])

for m, b in extra:
    rock |= m
    surf[m] = 5
    which[m] = b["idx"] + 1
    boulders.append(b)
    trees = [t for t in trees if ((t[1] - b["x"]) / (b["rx"] + 1.0)) ** 2 + ((t[2] - b["z"]) / (b["rz"] + 1.0)) ** 2 >= 1]
    plants = [p for p in plants if not m[min(int(p[0] / CELL), GX - 1), min(int(p[1] / CELL), GZ - 1)]]
(hgt.astype(np.float32)).T.tofile(f"{OUT}/height.bin")
Image.fromarray(np.stack([surf.T, which.T, np.zeros_like(which.T)], -1).astype(np.uint8), "RGB").save(f"{OUT}/ground.png")

# ---------------------------------------------------------------- people and things
ACTORS = "assets/ninja_adventure/Actor/"


def npc_sprite(name, sheet):
    """The first frame (facing you) of a sprite sheet of the original, and its normal map."""
    im = np.array(Image.open(ACTORS + sheet).convert("RGBA")).astype(float) / 255.0
    frame = im[:16, :16]
    Image.fromarray((frame * 255).astype(np.uint8), "RGBA").save(f"{OUT}/npc_{name}.png")
    a = frame[..., 3] > 0
    dist = distance_transform_edt(np.pad(a, 1))[1:-1, 1:-1]
    height = gaussian_filter(np.sqrt(dist) * 1.15 + frame[..., :3].mean(-1) * 0.6, 0.6)
    gy, gx = np.gradient(height)
    nm = np.stack([-gx, gy, np.ones_like(height)], -1)
    nm /= np.linalg.norm(nm, axis=-1, keepdims=True)
    out = np.concatenate([nm * 0.5 + 0.5, frame[..., 3:]], -1)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(f"{OUT}/npc_{name}_n.png")


people = [  # from world.gd
    ("pepe", "Pepe Bleau", "Character/OldMan/SpriteSheet.png", 16, 11, [
        "Ah, a new face!\nWelcome to Les Sables d'Or.",
        "See the yellow numbers on the blocks?\nThat's the yellow circuit.",
        "Start with number 1, La Premiere.\nIt's right by your tent.",
        "Read the rock: where there's chalk,\nothers found something to hold."]),
    ("sanne", "Sanne", "Character/Woman/SpriteSheet.png", 5, 24, [
        "I've lost my crash pad!\nI had it a minute ago.",
        "It must be somewhere between the blocks.\nTell me if you see it."]),
    ("mat", "Mat", "Character/Hunter/SpriteSheet.png", 40, 12, [
        "Behind those trees stands Le Grand Saut,\n4c, a proper highball.",
        "It's not in any circuit.\nBring two pads, though!"]),
    ("tim", "Tim", "Character/Inspector/SpriteSheet.png", 24.7, 27.1, [  # in front of La Dalle, in sight
        "Psst, behind La Dalle aux Fourmis\nthere's a hidden block.",
        "La Cachette, a 4a. It's in no guide,\nonly in your own topo."]),
    ("biscuit", "Biscuit", "Animal/Dog/SpriteSheet.png", 6, 25.5, ["Woof!", "(Biscuit sniffs at\nyour chalk bag.)"]),
    ("boswachter", "Ranger", "Character/Villager/SpriteSheet.png", 55.1, 23.2, [  # in front of the gate, not in a spruce
        "Here starts the path to\nthe next sector, Cul de Chien.",
        "I only let seasoned climbers through.\nClimb the yellow circuit first!"]),
]
npcs = []
for pid, name, sheet, tx, tz, lines in people:
    x, z = tiles(tx, tz)
    npcs.append({"sprite": "npc_" + pid, "name": name, "x": x, "z": z, "lift": 0, "lines": lines,
                 "texel": 0.055, "frames": 2 if pid == "biscuit" else 3})

for f in ["ground_atlas.png", "tree_atlas.png", "tufts.png", "tufts_n.png"]:
    shutil.copy(os.path.join(SHARED, f), os.path.join(OUT, f))
sprites_hd.main(OUT)  # people and props in one pixel style

px, pz = tiles(8.2, 29.2)
meta = {
    "title": "LES SABLES D'OR", "subtitle": "Fontainebleau",
    "size": [TW * T, TH * T], "grid": [GX, GZ], "cell": CELL, "texel": 0.055, "tile": 64,
    "boulders": boulders, "trees": trees, "plants": plants,
    "player": {"x": px, "z": pz, "frame": [24, 36], "frames_per_view": 4, "texel": 0.055},
    "npcs": npcs + [{"sprite": "npc_yara", "name": "Yara", "x": tiles(17, 12.6)[0], "z": tiles(17, 12.6)[1], "lift": 0,
                     "texel": 0.055, "frames": 3, "lines": ["Le Pot de Chalk has a big pocket\nhalfway up. You can rest there.",
                                               "Look where your feet can go first,\nthen your hands.",
                                               "Le Saut, at the back: that hold you only\nreach with a jump. Sink low, and grab\nat the moment you hang still."]}],
    "pads": [[tiles(7.2, 28.2)[0], tiles(7.2, 28.2)[1], 0], [tiles(16.2, 12.8)[0], tiles(16.2, 12.8)[1], 1]],  # the red pad clear of La Premiere's foot
    "camp": {"tent": list(tiles(6.0, 31.2)), "fire": list(tiles(9.2, 31.4)), "blanket": list(tiles(7.2, 32.5))},  # the blanket in front of the tent door
    "gate": {"x": tiles(56.4, 23)[0], "z": tiles(56.4, 23)[1], "w": 0.4, "d": 2.2 * T,
             "text": "The path to Cul de Chien is still closed."},
}
with open(f"{OUT}/area.json", "w") as f:
    json.dump(meta, f)
print("wrote", OUT, len(trees), "trees", len(plants), "plants", [b["name"] for b in boulders])
