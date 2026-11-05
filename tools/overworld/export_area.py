"""Writes the first walking area, Bas Cuvier, for the 3D overworld in Godot: the height field
(ground and blocks in one), which ground lies where, the pixel textures, the tree list and
the sprites. The same world as the mockups (tools/overworld/light.py).

    python3 tools/overworld/export_area.py assets/overworld/bas_cuvier

World units of the mockups are 13 cm; everything here is written in metres.
"""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, zoom, distance_transform_edt

sys.path.insert(0, os.path.dirname(__file__))
import sprites_lib as sl

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/overworld/bas_cuvier"
os.makedirs(OUT, exist_ok=True)
U = 0.13           # metres per mockup unit
NX, NZ, RES = 240, 210, 2
TEXEL = 0.055      # metres per pixel of everything: ground, rock, trees, people and props alike
TILE = 64          # texels per ground texture tile: big, so the ground does not repeat visibly


def vnoise2(shape, cell, seed, wrap=False):
    r = np.random.default_rng(seed)
    if wrap:  # tileable: noise on a torus
        g = r.random((shape[0] // cell, shape[1] // cell))
        g = np.tile(g, (3, 3))
        z = zoom(g, cell, order=3)
        return z[shape[0]:2 * shape[0], shape[1]:2 * shape[1]]
    g = r.random((shape[0] // cell + 3, shape[1] // cell + 3))
    return zoom(g, cell, order=3)[: shape[0], : shape[1]]


# ---------------------------------------------------------------- height and ground
GX, GZ = NX * RES, NZ * RES
X, Z = np.mgrid[0:GX, 0:GZ] / RES
hgt = 6 + 2.5 * vnoise2((GX, GZ), 60, 1) + 16 * np.clip(1 - Z / 70, 0, 1) ** 1.5
BOULDERS = [  # x, z, rx, rz, height, seed, name, grade
    (122, 112, 26, 16, 28, 1, "La Marie-Rose", "6a"),
    (42, 84, 20, 13, 22, 2, "", ""),
    (196, 132, 18, 12, 18, 3, "", ""),
    (88, 150, 6, 4, 5, 4, "", ""),
    (164, 76, 10, 7, 9, 5, "", ""),
]
rockmask = np.zeros((GX, GZ), bool)
for bx, bz, rx, rz, bh, seed, *_ in BOULDERS:
    wob = 1 + 0.12 * (vnoise2((GX, GZ), 18, seed) - 0.5)
    ang = np.arctan2(Z - bz, X - bx)
    lobes = 1 + 0.1 * np.sin(3 * ang + seed) + 0.07 * np.sin(5 * ang + 2 * seed)
    r = np.sqrt(((X - bx) / (rx * wob * lobes)) ** 2 + ((Z - bz) / (rz * wob * lobes)) ** 2)
    tilt = 1 + 0.18 * (X - bx) / rx
    bumps = bh * 0.06 * (vnoise2((GX, GZ), 10, seed + 9) - 0.5) + bh * 0.03 * (vnoise2((GX, GZ), 4, seed + 19) - 0.5)
    hh = bh * tilt * np.clip(1 - r ** 5, 0, 1) ** 0.3 + (r < 1) * bumps
    rockmask |= (r < 1) & (hh > 0.6)
    hgt = np.maximum(hgt, np.where(r < 1, hgt + hh, hgt))
hgt = gaussian_filter(hgt, 0.8)

n1, n2 = vnoise2((GX, GZ), 36, 41), vnoise2((GX, GZ), 22, 42)
surf = np.full((GX, GZ), 3)                         # 3 moss
surf[n1 > 0.6] = 2                                  # 2 pine needles
surf[(Z < 70) & (n2 > 0.55)] = 6                    # 6 heather
near = np.full((GX, GZ), 9.0)
for bx, bz, rx, rz, *_ in BOULDERS[:3]:
    near = np.minimum(near, np.hypot((X - bx) / (rx + 16), (Z - bz) / (rz + 14)))
surf[near < 1 + 0.3 * (n2 - 0.5)] = 1               # 1 sand washed off the blocks
path_x = 118 + 14 * np.sin(Z / 32.0) - 0.1 * (Z - 140)
surf[(np.abs(X - path_x) < 5 + 2 * n1) & (Z > 126)] = 4  # 4 the sandy path
surf[rockmask] = 5                                  # 5 sandstone

(hgt.astype(np.float32) * U).T.tofile(f"{OUT}/height.bin")  # row-major by z, then x
Image.fromarray(surf.T.astype(np.uint8), "L").save(f"{OUT}/ground.png")

# ---------------------------------------------------------------- ground textures
# Each ground tile holds only the texture: tones from the lit end of its ramp, picked by
# clumpy noise. The light in the game does the rest.
RAMPS = {
    0: [(40, 30, 34), (70, 52, 44), (100, 74, 54), (128, 96, 64), (150, 116, 78)],          # bare dirt (edges)
    1: [(70, 56, 74), (128, 106, 104), (178, 154, 128), (214, 190, 146), (236, 218, 176)],  # sand
    2: [(46, 32, 40), (78, 52, 46), (112, 78, 54), (150, 106, 64), (184, 138, 82)],         # needles
    3: [(26, 34, 40), (40, 58, 44), (62, 86, 50), (92, 116, 58), (134, 150, 72)],           # moss
    4: [(84, 70, 84), (150, 132, 124), (204, 186, 156), (232, 216, 182), (248, 238, 210)],  # path
    5: [(64, 58, 78), (106, 98, 110), (150, 140, 136), (188, 178, 158), (226, 216, 190)],   # sandstone (top)
    6: [(50, 38, 56), (84, 62, 82), (120, 86, 112), (156, 112, 138), (186, 146, 160)],      # heather
    7: [(30, 40, 44), (44, 64, 46), (66, 92, 52), (98, 124, 60), (140, 156, 76)],           # moss on rock
}


def ground_tile(m, seed):
    ramp = np.array(RAMPS[m], float)
    a = vnoise2((TILE, TILE), 4, seed, wrap=True)
    b = np.random.default_rng(seed + 1).random((TILE, TILE))
    tone = np.full((TILE, TILE), 3)
    tone[a > 0.62] = 4
    tone[a < 0.36] = 2
    tone[b > 0.93] = 4
    tone[b < 0.05] = 1
    if m == 2:  # needles: short dark strokes
        for k in range(160):
            x, y = np.random.default_rng(seed + k).integers(0, TILE, 2)
            for t in range(3):
                tone[(y + t) % TILE, (x + t) % TILE] = 2
    return ramp[tone].astype(np.uint8)


# Two variants of every ground, one under the other; the game mixes them in patches.
atlas = np.concatenate([np.concatenate([ground_tile(m, 10 + m + 100 * v) for m in range(8)], axis=1)
                        for v in range(2)], axis=0)
Image.fromarray(atlas).save(f"{OUT}/ground_atlas.png")

# The sandstone of the blocks is drawn by the terrain shader itself (font_rock), per pixel.

# Foliage and bark tiles for the trees.
TREE_RAMPS = {
    "spruce": [(16, 28, 34), (24, 48, 42), (38, 72, 50), (60, 100, 58), (98, 132, 68)],
    "broadleaf": [(22, 34, 32), (38, 62, 40), (62, 94, 48), (100, 130, 58), (150, 166, 76)],
    "pine": [(18, 30, 34), (30, 52, 44), (48, 80, 54), (76, 108, 62), (116, 140, 74)],
    "birchleaf": [(62, 48, 32), (118, 92, 42), (170, 140, 54), (212, 184, 74), (240, 218, 112)],
    "bark": [(32, 24, 30), (56, 40, 40), (84, 60, 52), (114, 84, 64), (144, 110, 80)],
    "pinebark": [(54, 30, 34), (98, 52, 42), (146, 80, 52), (188, 112, 64), (222, 148, 86)],
    "birch": [(20, 18, 22), (124, 120, 126), (184, 180, 176), (222, 218, 208), (244, 240, 228)],
}
tiles = []
for k, (name, rp) in enumerate(TREE_RAMPS.items()):
    rp = np.array(rp, float)
    t = np.full((TILE, TILE), 3)
    a = vnoise2((TILE, TILE), 3, 70 + k, wrap=True)
    b = np.random.default_rng(80 + k).random((TILE, TILE))
    if name in ("bark", "pinebark"):
        t[(np.arange(TILE)[None, :] % 3 == 0).repeat(TILE, 0)] = 2  # vertical furrows
        t[b > 0.9] = 4
        t[a < 0.3] = 1
    elif name == "birch":
        t[:] = 3
        t[b > 0.85] = 4
        for y in range(0, TILE, 5):  # the black marks on a birch
            for x in range(TILE):
                if np.random.default_rng(y * 31 + x // 6).random() > 0.55:
                    t[y, x] = 0
    else:
        t[a > 0.6] = 4
        t[a < 0.38] = 2
        t[b > 0.88] = 4
        t[b < 0.12] = 1
    tiles.append(rp[t])
Image.fromarray(np.concatenate(tiles, axis=1).astype(np.uint8)).save(f"{OUT}/tree_atlas.png")


# ---------------------------------------------------------------- sprites and their normal maps
def normal_map(spr):
    """A normal map from the silhouette and the painted shading, like Sprite Fusion's tool."""
    a = spr[..., 3] > 0
    dist = distance_transform_edt(np.pad(a, 1))[1:-1, 1:-1]
    height = gaussian_filter(np.sqrt(dist) * 1.15 + spr[..., :3].mean(-1) * 0.6, 0.6)
    gy, gx = np.gradient(height)
    n = np.stack([-gx, gy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    out = np.zeros(spr.shape)
    out[..., :3] = n * 0.5 + 0.5
    out[..., 3] = spr[..., 3]
    return out


def save_sheet(frames, name):
    h = max(f.shape[0] for f in frames)
    w = max(f.shape[1] for f in frames)
    sheet = np.zeros((h, w * len(frames), 4))
    for k, f in enumerate(frames):
        oy, ox = h - f.shape[0], k * w + (w - f.shape[1]) // 2
        sheet[oy:oy + f.shape[0], ox:ox + f.shape[1]] = f
    Image.fromarray((sheet * 255).astype(np.uint8), "RGBA").save(f"{OUT}/{name}.png")
    Image.fromarray((normal_map(sheet) * 255).astype(np.uint8), "RGBA").save(f"{OUT}/{name}_n.png")
    return w, h


P = dict(sl.P)
P["e"] = (40, 30, 40)  # eyes
HEAD_BACK = ["    yy      ", "   yyyy     ", "  yyyyYY    ", "  hhhhhh    "]
HEAD_FRONT = ["    yy      ", "   yyyy     ", "  yyyyYY    ", "  ssssss    ", "  sesses    ", "   ssss     "]
HEAD_SIDE = ["    yy      ", "   yyyy     ", "   yyyYY    ", "   hhsss    ", "   hhses    ", "    ssss    "]
BODY_BACK = [" BbbbbbbB   ", "sBbbbbbbBs  ", "sBbcccbbBs  ", "sBbbbbbbBs  ", "SBbbbbbbBS  ", " BBBBBBBB   ", "  rrrRR     "]
BODY_FRONT = [" BrrrrrrB   ", "sBrrrrrRBs  ", "s rrrrrR s  ", "s rrrrrR s  ", "S rrrrRR S  ", "  rrrrRR    ", "  rrrrRR    "]
BODY_SIDE = ["BBBBrrrR    ", "BbbBrrrR    ", "BbbBrrRs    ", "BbbBrrRs    ", "BbbBrrRS    ", "BBBBrrR     ", "   rrR      "]
LEGS = {
    0: ["  oooOO     ", "  oo OO     ", "  oo OO     ", "  oo OO     ", "  pp pp     "],
    1: ["  oooOO     ", "  oo  OO    ", " oo   OO    ", " oo    OO   ", " pp    pp   "],
    2: ["  oooOO     ", "   oo OO    ", "   oo OO    ", "  oo  OO    ", "  pp  pp    "],
}
LEGS_SIDE = {
    0: ["   ooOO     ", "   ooOO     ", "   ooOO     ", "   ooOO     ", "   pppp     "],
    1: ["   ooOO     ", "  oo  OO    ", " oo    OO   ", " oo     O   ", "pp      pp  "],
    2: ["   ooOO     ", "   OOoo     ", "  OO  oo    ", "  O    oo   ", " pp     pp  "],
}
frames = []
for view, head, body in [("back", HEAD_BACK, BODY_BACK), ("front", HEAD_FRONT, BODY_FRONT), ("side", HEAD_SIDE, BODY_SIDE)]:
    for k in (0, 1, 2):
        legs = (LEGS_SIDE if view == "side" else LEGS)[k]
        frames.append(sl.sprite_from_rows(head + body + legs, P))
fw, fh = save_sheet(frames, "player")
import sprites_hd
sprites_hd.main(OUT)  # the player and the other climbers in the same style as Les Sables d'Or


def grass_tuft(seed, kind):
    r = np.random.default_rng(seed)
    ramps = {"grass": [(30, 46, 38), (52, 80, 46), (86, 116, 56), (140, 158, 74)],
             "bracken": [(70, 44, 34), (128, 78, 40), (178, 118, 52), (222, 168, 80)],
             "heather": [(52, 40, 56), (100, 70, 96), (156, 98, 140), (204, 140, 180)]}[kind]
    w, h = 14, 10
    s = np.zeros((h, w, 4))
    hh = h if kind != "heather" else 6
    for b in range(w + 2):
        x0 = r.uniform(1, w - 1)
        lean = r.uniform(-0.45, 0.45)
        ln = r.uniform(hh * 0.45, hh)
        for k in range(int(ln)):
            x = int(round(x0 + lean * k + lean * k * k * 0.05))
            y = h - 1 - k
            if 0 <= x < w:
                f = k / max(ln - 1, 1)
                tone = 0 if f < 0.25 else (1 if f < 0.55 else (2 if f < 0.85 else 3))
                if lean > 0.2 and tone == 3:
                    tone = 2
                s[y, x, :3] = np.array(ramps[tone]) / 255.0
                s[y, x, 3] = 1
    return s


tufts = [grass_tuft(j * 10 + i, kind) for j, kind in enumerate(("grass", "bracken", "heather")) for i in range(6)]
save_sheet(tufts, "tufts")

# Where the tufts grow: one list, one entry per tuft (x, z in metres, variant).
rng = np.random.default_rng(21)
noise_t = vnoise2((240, 210), 9, 55)
plants = []
for k in range(9000):
    x, z = rng.uniform(0, NX), rng.uniform(0, NZ)
    m = surf[int(x * RES), int(z * RES)]
    if m in (4, 5) or (m == 1 and rng.random() < 0.93) or (m == 2 and rng.random() < 0.6):
        continue
    if m == 3 and noise_t[int(x), int(z)] < 0.4:
        continue
    kind = 2 if m == 6 else (1 if m == 2 else 0)
    plants.append([round(x * U, 3), round(z * U, 3), int(kind * 6 + rng.integers(6))])

# ---------------------------------------------------------------- trees and the rest
rng = np.random.default_rng(7)
back = []
for k in range(46):
    x, z = rng.uniform(1, NX - 3), rng.uniform(4, 70)
    kind = "pine" if rng.random() < 0.6 else ("spruce" if rng.random() < 0.6 else "birch")
    back.append([kind, x, z, rng.uniform(62, 86) if kind == "pine" else rng.uniform(34, 52), 100 + k])
for k in range(40):  # a ring of forest around the clearing, so there is no edge to see
    a = k / 40 * np.pi * 2
    x, z = 120 + np.cos(a) * 140 * rng.uniform(0.9, 1.1), 105 + np.sin(a) * 125 * rng.uniform(0.9, 1.1)
    if (0 < x < NX and 0 < z < NZ) or z > NZ * 0.7:
        continue  # not inside the clearing, and not between the camera and you
    kind = "spruce" if rng.random() < 0.5 else "pine"
    back.append([kind, x, z, rng.uniform(40, 80), 200 + k])
for k in range(80):  # the forest goes on behind the clearing
    x, z = rng.uniform(-60, NX + 60), rng.uniform(-90, 0)
    kind = "spruce" if rng.random() < 0.45 else ("pine" if rng.random() < 0.8 else "birch")
    back.append([kind, x, z, rng.uniform(40, 84), 300 + k])
for k in range(90):  # forest beyond the sides, all the way to the front
    side = rng.random() < 0.5
    x = rng.uniform(-70, -4) if side else rng.uniform(NX + 4, NX + 70)
    kind = "spruce" if rng.random() < 0.5 else ("pine" if rng.random() < 0.75 else "broadleaf")
    back.append([kind, x, rng.uniform(-20, NZ + 10), rng.uniform(30, 80) if kind != "broadleaf" else rng.uniform(20, 30), 500 + k])
for k in range(12):  # sides
    for x in (4, NX - 4):
        back.append(["spruce" if k % 2 else "pine", x + rng.uniform(-2, 2), 16 + k * 16, rng.uniform(36, 70), 400 + k * 2 + (x > 9)])
for k in range(13):  # the bank at the back
    back.append(["spruce", 8 + k * 18 + rng.uniform(-3, 3), 5, rng.uniform(34, 50), 440 + k])
for k in range(12):  # low bushes along the front edge
    back.append(["broadleaf", 6 + k * 20 + rng.uniform(-3, 3), NZ - 5, rng.uniform(12, 16), 460 + k])
field = [["spruce", 68, 160, 36, 1], ["broadleaf", 172, 178, 30, 2], ["birch", 56, 124, 38, 3],
         ["birch", 66, 136, 34, 4], ["pine", 180, 96, 62, 5], ["spruce", 216, 182, 46, 6],
         ["spruce", 30, 150, 40, 7], ["broadleaf", 18, 198, 30, 8], ["spruce", 150, 72, 40, 9],
         ["broadleaf", 96, 84, 30, 10]]
trees = [[k, round(x * U, 3), round(z * U, 3), round(h * U, 3), s] for k, x, z, h, s in field + back]

meta = {
    "size": [NX * U, NZ * U], "grid": [GX, GZ], "cell": U / RES, "texel": TEXEL, "tile": TILE,
    "ground_ids": {"sand": 1, "needles": 2, "moss": 3, "path": 4, "rock": 5, "heather": 6},
    "boulders": [{"name": n, "grade": g, "x": bx * U, "z": bz * U, "rx": rx * U, "rz": rz * U}
                 for bx, bz, rx, rz, bh, s, n, g in BOULDERS],
    "trees": trees,
    "plants": plants,
    "player": {"x": 120 * U, "z": 172 * U, "frame": [24, 36], "frames_per_view": 4, "texel": TEXEL},
    "npcs": [{"sprite": "npc_mat", "x": 186 * U, "z": 154 * U, "lift": 0, "texel": TEXEL, "frames": 3},
             {"sprite": "npc_tim", "x": 199 * U, "z": 156 * U, "lift": 0, "texel": TEXEL, "frames": 3},
             {"sprite": "npc_pepe", "x": 40 * U, "z": 102 * U, "lift": 0, "texel": TEXEL, "frames": 3}],
    "pads": [[112 * U, 132 * U, 0], [188 * U, 148 * U, 1], [34 * U, 100 * U, 1]],
}
with open(f"{OUT}/area.json", "w") as f:
    json.dump(meta, f)
print("wrote", OUT, len(plants), "plants", len(trees), "trees")
