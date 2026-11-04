"""Mockup of the walking world in HD-2D, after Lumina: a diorama of tile blocks with pixel
textures seen from above at an angle, organic Font boulders, small pixel sprites, sun and
cast shadows, tilt-shift blur, bloom, light shafts and floating motes.

    python3 overworld.py [avond|middag] out.png
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, zoom

TIME = sys.argv[1] if len(sys.argv) > 1 else "avond"
OUTFILE = sys.argv[2] if len(sys.argv) > 2 else "overworld.png"
FONT_DIR = "/Users/prive/boulder/assets/fonts/kenney_kenney-fonts/Fonts/"

W, H = 960, 540
S = 3            # screen pixels per cell
FY = 0.72        # ground foreshortening
FZ = 0.70        # height foreshortening
NX, NZ = W // S, 262
TILE = 12        # cells per tile
rng = np.random.default_rng(4)

LOOKS = {
    # sun towards (x right, y up, z towards camera), sun colour, ambient (shade) colour
    "avond": dict(sun=(-0.78, 0.42, 0.42), light=(1.08, 0.76, 0.46), amb=(0.2, 0.17, 0.36),
                  shaft=(1.0, 0.72, 0.42), haze=(0.95, 0.6, 0.45), clock="19:42", part="Avond"),
    "middag": dict(sun=(-0.35, 0.82, 0.45), light=(0.92, 0.9, 0.84), amb=(0.27, 0.29, 0.42),
                   shaft=(1.0, 0.95, 0.8), haze=(0.8, 0.85, 0.9), clock="13:10", part="Middag"),
}
L = LOOKS[TIME]
SUN = np.array(L["sun"]); SUN = SUN / np.linalg.norm(SUN)


def vnoise(shape, cell, seed):
    r = np.random.default_rng(seed)
    g = r.random((shape[0] // cell + 3, shape[1] // cell + 3))
    z = zoom(g, cell, order=3)[: shape[0], : shape[1]]
    return z


# ---------------------------------------------------------------- the world
zz, xx = np.mgrid[0:NZ, 0:NX]
tz, tx = zz // TILE, xx // TILE
NTZ, NTX = NZ // TILE + 1, NX // TILE + 1

BOULDERS = [  # x, z (cells), rx, rz, height, seed
    (172, 118, 36, 22, 52, 1),
    (58, 92, 30, 20, 40, 2),
    (276, 150, 27, 18, 34, 3),
    (118, 196, 12, 8, 12, 4),
    (238, 82, 15, 10, 16, 5),
]

# Terrain in tiles: a raised bank at the back, the clearing, a low front edge.
th = np.full((NTZ, NTX), 6.0)
tmat = np.zeros((NTZ, NTX), int)          # 0 sand 1 litter 2 moss 3 path 5 heather
tn = vnoise((NTZ, NTX), 3, 41)
tn2 = vnoise((NTZ, NTX), 2, 42)
for j in range(NTZ):
    for i in range(NTX):
        edge = 5 + int(1.5 * np.sin(i * 0.7) + (tn2[j, i] > 0.7))
        if j < edge:
            th[j, i] = 14 + 4 * (j < edge - 2) + (4 if j < 2 else 0)
            tmat[j, i] = 5 if tn2[j, i] > 0.68 else (2 if tn[j, i] > 0.5 else 1)
        elif j > 18:
            th[j, i] = 3
            tmat[j, i] = 1 if tn2[j, i] > 0.4 else 2
        else:
            # Font blocks stand in pale sand washed off them; around that, moss and needles
            near = min(np.hypot((i * TILE + 6 - bx) / (rx + 22), (j * TILE + 6 - bz) / (rz + 20)) for bx, bz, rx, rz, *_ in BOULDERS[:3])
            tmat[j, i] = 0 if near < 1 or tn[j, i] > 0.8 else (1 if tn2[j, i] > 0.5 else 2)
# A sandy path from the front to the block, and steps up the bank.
path = [(21, 14), (20, 14), (19, 14), (18, 14), (17, 13), (16, 13), (15, 13), (14, 14), (13, 14), (12, 15),
        (11, 16), (10, 17), (9, 18), (8, 19), (7, 20), (6, 20), (5, 21), (4, 21)]
for j, i in path:
    tmat[j, i] = 3
    if j < 7:
        th[j, i] = min(th[j, i], 6 + (7 - j) * 3)
    if i + 1 < NTX:
        tmat[j, i + 1] = 3 if j > 6 else tmat[j, i + 1]
hgt = th[tz, tx].astype(float)
mat = tmat[tz, tx].copy()
# A little unevenness inside a tile, like Lumina's soft blocks.
hgt += 0.6 * (vnoise((NZ, NX), 9, 1) - 0.5)

# Font boulders: rounded, steep, cauliflower swellings, layers.
rock = np.zeros((NZ, NX), bool)
bump = vnoise((NZ, NX), 7, 9) - 0.5
for bx, bz, rx, rz, bh, seed in BOULDERS:
    wob = 1 + 0.12 * (vnoise((NZ, NX), 11, seed) - 0.5)
    ang = np.arctan2(zz - bz, xx - bx)
    lobes = 1 + 0.1 * np.sin(3 * ang + seed) + 0.06 * np.sin(5 * ang + 2 * seed)
    r = np.sqrt(((xx - bx) / (rx * wob * lobes)) ** 2 + ((zz - bz) / (rz * wob * lobes)) ** 2)
    inside = r < 1
    tilt = 1 + 0.22 * (bx - xx) / rx  # higher on one side, like most Font blocks
    shape = bh * tilt * np.clip(1 - r ** 5, 0, 1) ** 0.3
    shape += inside * (bh * 0.09 * bump * np.clip(r * 2, 0, 1))
    base = hgt
    top = np.where(inside, base + shape, base)
    rock |= inside & (top > base + 1)
    hgt = np.maximum(hgt, top)
mat[rock] = 4

# Trees: positions; their crowns and trunks shade the ground (the shadow test uses them).
TREES = [  # x, z, kind
    (20, 58, "pine"), (96, 48, "pine"), (150, 40, "birch"), (214, 52, "pine"), (300, 60, "pine"),
    (2, 160, "pine"), (318, 130, "birch"), (262, 64, "pine"), (60, 54, "birch"),
    (316, 236, "birch"), (8, 128, "pine"), (318, 196, "pine"), (226, 100, "pine"), (34, 210, "birch"),
]
occ_lo = np.full((NZ, NX), 1e9)
occ_hi = np.full((NZ, NX), -1e9)
holes = vnoise((NZ, NX), 5, 33)


def ground(x, z):
    return hgt[int(np.clip(z, 0, NZ - 1)), int(np.clip(x, 0, NX - 1))]


for x, z, kind in TREES:
    g = ground(x, z)
    tall, crown, lo = (160, 24, 105) if kind == "pine" else (90, 12, 58)
    d = np.hypot(xx - x, (zz - z) * 1.2)
    t = d < 1.6
    occ_lo[t] = np.minimum(occ_lo[t], g)
    occ_hi[t] = np.maximum(occ_hi[t], g + tall)
    c = (d < crown * (0.8 + 0.4 * holes)) & (holes > 0.32)
    occ_lo[c] = np.minimum(occ_lo[c], g + lo)
    occ_hi[c] = np.maximum(occ_hi[c], g + tall)

# People: you on the path, a climber on the block on the right, a spotter, one resting.
YOU = (166, 168)
PEOPLE = [YOU, (270, 171), (256, 186), (100, 128)]
for x, z in PEOPLE:
    d = np.hypot(xx - x, zz - z)
    p = d < 2.2
    occ_lo[p] = np.minimum(occ_lo[p], ground(x, z))
    occ_hi[p] = np.maximum(occ_hi[p], ground(x, z) + 22)

# ---------------------------------------------------------------- light per cell
gz, gx = np.gradient(hgt)
normal = np.stack([-gx, np.ones_like(hgt), -gz], -1)  # dh/dz > 0 means the slope faces away
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
lam = np.clip(normal @ SUN, 0, 1)

# Cast shadows: march from every cell towards the sun.
shadow = np.zeros((NZ, NX))
horiz = np.hypot(SUN[0], SUN[2])
step = np.array([SUN[0] / horiz, SUN[2] / horiz])
rise = SUN[1] / horiz
for t in range(2, 200, 2):
    sx = np.clip((xx + step[0] * t).round().astype(int), 0, NX - 1)
    sz = np.clip((zz + step[1] * t).round().astype(int), 0, NZ - 1)
    ray = hgt + 1.0 + rise * t
    blocked = (hgt[sz, sx] > ray) | ((occ_lo[sz, sx] < ray) & (occ_hi[sz, sx] > ray))
    shadow = np.maximum(shadow, blocked)
shadow = np.clip(gaussian_filter(shadow, 0.6), 0, 1)

# ---------------------------------------------------------------- materials
cell_rand = vnoise((NZ, NX), 1, 5)
spot = vnoise((NZ, NX), 3, 6)
TOPS = {
    0: [(214, 186, 140), (198, 170, 126), (226, 204, 160)],   # sand
    1: [(150, 104, 62), (122, 84, 52), (176, 126, 70)],       # leaf litter, autumn
    2: [(104, 116, 60), (86, 98, 52), (128, 138, 70)],        # moss
    3: [(244, 232, 204), (232, 218, 186), (250, 242, 220)],   # path sand
    4: [(170, 160, 142), (146, 138, 126), (188, 178, 156)],   # sandstone
    5: [(128, 92, 110), (100, 78, 88), (156, 108, 132)],      # heather
}
SIDES = {0: (176, 140, 98), 1: (142, 100, 66), 2: (130, 98, 64), 3: (190, 160, 116), 4: (160, 150, 134), 5: (130, 96, 70)}
ROCKTEX = vnoise((140, NX), 3, 77) * 0.6 + vnoise((140, NX), 9, 78) * 0.4
STREAK = vnoise((140, NX), 1, 79)


def top_albedo():
    out = np.zeros((NZ, NX, 3))
    for m, cols in TOPS.items():
        sel = mat == m
        pick = np.where(cell_rand < 0.33, 0, np.where(cell_rand < 0.8, 1, 2))
        pick = np.where(spot > 0.72, 2, np.where(spot < 0.25, 1, pick))
        c = np.array(cols, float)[pick]
        out[sel] = c[sel]
    # lichen and patina on the boulders
    lich = (vnoise((NZ, NX), 4, 12) > 0.68) & rock
    out[lich] = np.array([120, 132, 86])
    pat = (vnoise((NZ, NX), 6, 13) > 0.7) & rock
    out[pat] = out[pat] * 0.78
    # tile seams, very faint
    seam = ((xx % TILE == 0) | (zz % TILE == 0)) & ~rock
    out[seam] *= 0.93
    return out / 255.0


ALB = top_albedo()
AMB = np.array(L["amb"])
LIGHT = np.array(L["light"])


def shade(albedo, l, sh):
    lvl = np.where(l > 0.62, 1.0, np.where(l > 0.36, 0.72, np.where(l > 0.14, 0.45, 0.2)))
    lit = lvl * (1 - sh)
    return albedo * (AMB[None] + LIGHT[None] * lit[..., None])


TOPC = shade(ALB.reshape(-1, 3), lam.ravel(), shadow.ravel()).reshape(NZ, NX, 3)

# ---------------------------------------------------------------- render terrain
img = np.zeros((H, W, 3))
sky = np.linspace(0, 1, H)[:, None, None]
img[:] = np.array(L["haze"]) * 0.5
depth = np.full((H, W), -1.0)
ypix = np.arange(H)
colx = np.arange(W) // S
Y_OFF = -46

for z in range(NZ):
    h = hgt[z, colx]
    hn = hgt[min(z + 1, NZ - 1), colx]
    y0 = z * S * FY - h * S * FZ + Y_OFF
    y_face = (z + 1) * S * FY - h * S * FZ + Y_OFF
    y1 = (z + 1) * S * FY - np.minimum(hn, h) * S * FZ + Y_OFF
    if z == NZ - 1:
        y1 = np.full_like(y1, H)
    a = np.clip(np.floor(y0).astype(int), 0, H)
    f = np.clip(np.floor(y_face).astype(int), 0, H)
    b = np.clip(np.ceil(y1).astype(int), 0, H)
    m = mat[z, colx]
    face_alb = np.array([SIDES[k] for k in m], float) / 255.0
    is_rock = m == 4
    # steep faces of a block take the block's texture and its sandstone layers
    rock_side = np.array(SIDES[4], float) / 255.0
    nrm = normal[z, colx]
    face_n = np.stack([nrm[:, 0], np.full(W, 0.25), np.maximum(nrm[:, 2], 0.6)], -1)
    face_n /= np.linalg.norm(face_n, axis=-1, keepdims=True)
    face_l = np.clip(face_n @ SUN, 0, 1)
    face_sh = shadow[z, colx]
    top_c = TOPC[z, colx]
    for k in range(int((b - a).max()) + 1):
        y = a + k
        ok = y < b
        if not ok.any():
            continue
        cols = np.nonzero(ok)[0]
        yy = y[cols]
        on_face = yy >= f[cols]
        c = top_c[cols].copy()
        if on_face.any():
            fc = cols[on_face]
            hp = h[fc] - (yy[on_face] - y_face[fc]) / (S * FZ)  # the height of this pixel
            alb = face_alb[fc].copy()
            rf_ = is_rock[fc]
            hi_ = np.clip(hp.astype(int), 0, 139)
            tex = ROCKTEX[hi_, fc // S]
            rk = rock_side[None] * (0.82 + 0.36 * tex[:, None])
            rk[(STREAK[np.clip(hi_ // 6, 0, 139), fc // S] > 0.8)] *= 0.8  # dark streaks of patina
            band = ((hp + 6 * ROCKTEX[np.clip(hi_ // 3, 0, 139), fc // S]) % 13.0) < 0.8
            rk[band] *= 0.8
            low = hp - ground(0, 0) < 0  # not used
            alb[rf_] = rk[rf_]
            dirt = ((hp % 4.0) < 0.7) & ~is_rock[fc]
            alb[dirt] *= 0.85
            lvl = np.where(face_l[fc] > 0.55, 0.85, np.where(face_l[fc] > 0.3, 0.55, 0.25)) * (1 - face_sh[fc])
            cc = alb * (AMB[None] + LIGHT[None] * lvl[:, None])
            # the dark line under a terrace lip
            lip = (yy[on_face] - f[fc]) < 1
            cc[lip & ~is_rock[fc]] *= 0.75
            c[on_face] = cc
        img[yy, cols] = c
        depth[yy, cols] = z

# ---------------------------------------------------------------- sprites
def sprite_from_rows(rows, palette):
    hgt_ = len(rows)
    wid = max(len(r) for r in rows)
    out = np.zeros((hgt_, wid, 4))
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch in palette:
                out[j, i, :3] = np.array(palette[ch]) / 255.0
                out[j, i, 3] = 1
    return out


P = {
    "y": (240, 186, 70), "Y": (196, 140, 50), "h": (70, 46, 40), "s": (226, 170, 130), "S": (170, 116, 96),
    "r": (200, 86, 62), "R": (140, 58, 54), "o": (110, 112, 72), "O": (76, 76, 56), "p": (120, 74, 128),
    "b": (80, 118, 170), "B": (54, 82, 128), "w": (236, 232, 220), "c": (120, 150, 190), "C": (86, 104, 140),
    "g": (90, 150, 110), "G": (60, 104, 80), "k": (40, 34, 42),
}
# You, from behind, with a crash pad on your back.
YOU_ROWS = [
    "     y      ",
    "    yyyy    ",
    "   yyyYY    ",
    "   hhhhh    ",
    "  BbbbbbbB  ",
    " sBbbbbbbBs ",
    " sBbcccbbBs ",
    " sBbbbbbbBs ",
    " sBbbbbbbBs ",
    " SBbbbbbbBS ",
    "  BbbbbbbB  ",
    "  BBBBBBBB  ",
    "   rrrRR    ",
    "   oooOO    ",
    "   oo OO    ",
    "   oo OO    ",
    "   oo OO    ",
    "   pp pp    ",
]
CLIMBER_ROWS = [
    " s       s  ",
    " s       s  ",
    " sS  y  Ss  ",
    "  s yyyY s  ",
    "  rrhhhhRr  ",
    "   rrrrRR   ",
    "   rrrrRR   ",
    "   rrrrRR b ",
    "   ooooOO b ",
    "  oo    OO  ",
    " oo      OO ",
    " pp      pp ",
]
SPOTTER_ROWS = [
    " s      s ",
    " sS    Ss ",
    "  s hh s  ",
    "  ghhhhG  ",
    "   gggG   ",
    "   gggG   ",
    "   gggG   ",
    "   kkkk   ",
    "   kk kk  ",
    "   kk kk  ",
    "   kk kk  ",
    "   ww ww  ",
]
SITTER_ROWS = [
    "    hh     ",
    "   hhhh    ",
    "   ssss    ",
    "  rrrrRR   ",
    "  rrrrRRs  ",
    "  ooooOOOO ",
    " ooOOOOOOww",
]
PAD_ROWS = ["CCCCCCCCCCCCCCCCCCCCCC", "CccccccccccccccccccccC", "CccccccccccccccccccccC",
            "CccccccccccccccccccccC", "CCCCCCCCCCCCCCCCCCCCCC", "BBBBBBBBBBBBBBBBBBBBBB"]
PAD_P = {"C": (64, 86, 120), "c": (82, 112, 150), "B": (40, 50, 70)}
PAD2_P = {"C": (150, 70, 60), "c": (186, 92, 70), "B": (90, 40, 40)}


def pine():
    w, h = 76, 170
    s = np.zeros((h, w, 4))
    r = np.random.default_rng(7)
    for y in range(30, h):
        t = (y - 30) / (h - 30)
        half = 2.0 + 1.6 * t
        for x in range(int(w / 2 - half), int(w / 2 + half) + 1):
            lit = x < w / 2 - half * 0.2
            base = (190, 104, 60) if y < 100 else (112, 88, 74)  # orange high up, grey bark low
            c = np.array(base) * (1.12 if lit else 0.68)
            if r.random() < 0.15 or (y > 100 and (y // 3) % 3 == 0 and r.random() < 0.5):
                c *= 0.78
            s[y, x] = [*(c / 255), 1]
    pads = [(w / 2 + r.uniform(-20, 20), r.uniform(6, 66), r.uniform(9, 16), r.uniform(4, 7)) for _ in range(9)]
    pads.sort(key=lambda p: p[1])
    for cx, cy, rx, ry in pads:
        # the branch to the pad
        for k in range(30):
            bx_ = w / 2 + (cx - w / 2) * k / 29
            by_ = cy + 6 + 4 * (1 - k / 29)
            if 0 <= int(bx_) < w and 0 <= int(by_) < h:
                s[int(by_), int(bx_)] = [0.42, 0.26, 0.18, 1]
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                u, v = (x - cx) / rx, (y - cy) / ry
                edge = 1 + 0.25 * np.sin(x * 1.7 + y) * r.random()
                if u * u + v * v > edge or not (0 <= x < w and 0 <= y < h):
                    continue
                k = -0.6 * u - v + r.normal(0, 0.35)
                c = (112, 140, 82) if k > 0.9 else ((76, 104, 66) if k > -0.1 else ((50, 72, 56) if k > -0.9 else (34, 50, 44)))
                s[y, x] = [*(np.array(c) / 255), 1]
    return s


def birch():
    w, h = 30, 96
    s = np.zeros((h, w, 4))
    r = np.random.default_rng(8)
    for y in range(26, h):
        for x in (14, 15):
            c = np.array((232, 228, 214)) * (1.0 if x == 14 else 0.75)
            if r.random() < 0.18:
                c = np.array((40, 36, 40))
            s[y, x] = [*(c / 255), 1]
    for k in range(150):
        cx = w / 2 + r.normal(0, 6)
        cy = r.uniform(3, 34)
        rad = r.uniform(1.5, 3.5)
        for y in range(int(cy - rad), int(cy + rad) + 1):
            for x in range(int(cx - rad), int(cx + rad) + 1):
                if 0 <= x < w and 0 <= y < h and (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad:
                    side = (x - cx) / rad - (y - cy) / rad
                    c = (170, 150, 60) if side > 0.3 else ((226, 204, 96) if side < -0.6 else (200, 180, 76))
                    s[y, x] = [*(np.array(c) / 255), 1]
    return s


def tuft(kind, seed):
    r = np.random.default_rng(seed)
    if kind == "bracken":
        w, h, cols = 14, 9, [(150, 96, 44), (196, 136, 60), (226, 176, 86)]
    elif kind == "heather":
        w, h, cols = 9, 5, [(96, 70, 80), (170, 96, 150), (214, 140, 186)]
    else:
        w, h, cols = 7, 6, [(80, 100, 52), (122, 140, 66), (176, 186, 96)]
    s = np.zeros((h, w, 4))
    for k in range(w):
        lean = r.uniform(-0.6, 0.6)
        L_ = r.integers(h // 2, h + 1)
        x0 = r.uniform(1, w - 2)
        for t in range(L_):
            x = int(x0 + lean * t)
            y = h - 1 - t
            if 0 <= x < w:
                c = cols[0] if t < L_ * 0.4 else (cols[2] if lean < 0 else cols[1])
                s[y, x] = [*(np.array(c) / 255), 1]
    return s


sprites = []  # (z, x, ground height, rgba, texel size, flat)
for x, z, kind in TREES:
    sprites.append((z, x, ground(x, z), pine() if kind == "pine" else birch(), 2, False))
pal = {**P}
sprites.append((YOU[1], YOU[0], ground(*YOU), sprite_from_rows(YOU_ROWS, pal), 3, False))
sprites.append((171, 270, ground(270, 175) + 14, sprite_from_rows(CLIMBER_ROWS, pal), 3, False))  # on the face
sprites.append((186, 256, ground(256, 186), sprite_from_rows(SPOTTER_ROWS, pal), 3, False))
sprites.append((178, 272, ground(272, 178), sprite_from_rows(PAD_ROWS, PAD_P), 3, True))
sprites.append((142, 172, ground(172, 142), sprite_from_rows(PAD_ROWS, PAD2_P), 3, True))
sprites.append((128, 100, ground(100, 128), sprite_from_rows(SITTER_ROWS, pal), 3, False))
sprites.append((126, 96, ground(96, 126), sprite_from_rows(PAD_ROWS[:5], PAD_P), 3, True))
r = np.random.default_rng(21)
for k in range(1500):
    x = r.uniform(0, NX); z = r.uniform(0, NZ)
    zi, xi = int(z), int(x)
    if rock[zi, xi] or mat[zi, xi] == 3:
        continue
    m = mat[zi, xi]
    kind = "heather" if m == 5 else ("bracken" if m == 1 and r.random() < 0.6 else "grass")
    if m == 0 and r.random() < 0.8:
        continue
    sprites.append((z, x, ground(x, z), tuft(kind, k), 2, False))
sprites.sort(key=lambda s_: s_[0])

for z, x, g, spr, tex, flat in sprites:
    big = np.repeat(np.repeat(spr, tex, 0), tex, 1)
    sh_, sw_ = big.shape[:2]
    sx = int(x * S - sw_ / 2)
    sy = int(z * S * FY - g * S * FZ + Y_OFF - sh_)
    if flat:
        sy += sh_ // 2
    insh = shadow[int(np.clip(z, 0, NZ - 1)), int(np.clip(x, 0, NX - 1))]
    for j in range(sh_):
        y = sy + j
        if not 0 <= y < H:
            continue
        xs_ = np.arange(sw_) + sx
        ok = (xs_ >= 0) & (xs_ < W) & (big[j, :, 3] > 0)
        if not ok.any():
            continue
        xs2 = xs_[ok]
        vis = depth[y, xs2] <= z + 0.5
        xs3 = xs2[vis]
        c = big[j, ok, :3][vis]
        if insh > 0.5 and sh_ < 80:
            c = c * (0.55 + 0.45 * AMB / AMB.max())
        else:
            c = c * (0.75 + 0.35 * LIGHT / LIGHT.max())
        img[y, xs3] = c
        depth[y, xs3] = z

# ---------------------------------------------------------------- the post: diorama look
lin = np.clip(img, 0, 3)
# tilt-shift: sharp around your row, blurred above and below
focus = YOU[1] * S * FY - ground(*YOU) * S * FZ + Y_OFF - 20
levels = [0, 1.2, 2.6, 4.5, 7.0]
blurred = [lin] + [np.stack([gaussian_filter(lin[..., c], s_) for c in range(3)], -1) for s_ in levels[1:]]
dist = np.abs(ypix - focus)
amount = np.clip((dist - 105) / 65.0, 0, len(levels) - 1.001)
lo = amount.astype(int)
fr = (amount - lo)[:, None, None]
stack = np.stack(blurred)
rows = np.arange(H)
out = stack[lo, rows] * (1 - fr) + stack[lo + 1, rows] * fr

# light shafts from the low sun, from the upper left
yy_, xx_ = np.mgrid[0:H, 0:W]
along = (xx_ * 0.55 + yy_ * 0.85)
across = (xx_ * 0.85 - yy_ * 0.55)
beams = np.clip(np.sin(across / 23.0) * 0.5 + np.sin(across / 61.0 + 1.0) * 0.6 + 0.1 * np.sin(across / 9.0), 0, 1) ** 2
beams *= np.clip(1.2 - yy_ / H, 0, 1) * np.clip(1.3 - xx_ / W, 0, 1)
out += beams[..., None] * np.array(L["shaft"]) * (0.07 if TIME == "avond" else 0.03)

# bloom
lum = out.mean(-1)
bright = np.clip(out - 0.9, 0, None)
bloom = np.stack([gaussian_filter(bright[..., c], 10) + gaussian_filter(bright[..., c], 28) for c in range(3)], -1)
out += bloom * 0.6

# floating motes: dust in the sun, bokeh where it is blurred
r = np.random.default_rng(3)
mote = np.zeros((H, W))
for k in range(36):
    mx, my = r.uniform(0, W), r.uniform(0, H)
    bl = 1 + 5 * np.clip((abs(my - focus) - 70) / 120, 0, 1)
    d2 = (xx_ - mx) ** 2 + (yy_ - my) ** 2
    if bl > 2.5:
        mote += 0.12 * (d2 < (bl * 1.6) ** 2)
    else:
        mote += np.exp(-d2 / 2.0) * 0.9
out += mote[..., None] * np.array(L["shaft"]) * 0.8

# grade: warm highlights, purple in the shade, a vignette
lum = out.mean(-1, keepdims=True)
out = out + (1 - np.clip(lum, 0, 1)) * np.array([0.05, 0.0, 0.08]) * (1.0 if TIME == "avond" else 0.4)
v = ((xx_ / W - 0.5) ** 2 * 1.2 + (yy_ / H - 0.5) ** 2) ** 1.0
out *= (1 - 0.55 * v)[..., None]
lum = out.mean(-1, keepdims=True)
out = lum + (out - lum) * 1.3  # a little more colour
out = 1 - np.exp(-np.clip(out, 0, None) * 1.55)  # soft roll-off
out = np.clip(out, 0, 1)
im = Image.fromarray((out * 255).astype(np.uint8))

# ---------------------------------------------------------------- UI, in pixel type
if len(sys.argv) > 3 and sys.argv[3] == "noui":
    im.save(OUTFILE)
    sys.exit()
d = ImageDraw.Draw(im)
big_f = ImageFont.truetype(FONT_DIR + "Kenney Pixel.ttf", 32)
small_f = ImageFont.truetype(FONT_DIR + "Kenney Pixel.ttf", 16)
GOLD = (222, 186, 110)


def plate(x, y, w, h):
    d.rectangle([x, y, x + w, y + h], fill=(28, 22, 32))
    d.rectangle([x + 2, y + 2, x + w - 2, y + h - 2], outline=GOLD)
    for cx, cy in [(x + 2, y + 2), (x + w - 2, y + 2), (x + 2, y + h - 2), (x + w - 2, y + h - 2)]:
        d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=(240, 210, 140))


plate(14, 14, 214, 52)
d.text((28, 16), "BAS CUVIER", font=big_f, fill=(250, 238, 214))
d.text((28, 44), "Fontainebleau", font=small_f, fill=GOLD)
plate(W - 150, 14, 136, 52)
d.text((W - 136, 16), L["clock"], font=big_f, fill=(250, 238, 214))
d.text((W - 136, 44), L["part"], font=small_f, fill=GOLD)
# the prompt over the block in front of you
px_ = int(YOU[0] * S) + 34
py_ = int(YOU[1] * S * FY - ground(*YOU) * S * FZ + Y_OFF) - 92
plate(px_, py_, 172, 52)
d.text((px_ + 14, py_ + 2), "La Marie-Rose", font=big_f, fill=(250, 238, 214))
d.ellipse([px_ + 14, py_ + 32, px_ + 28, py_ + 46], fill=(110, 170, 90))
d.text((px_ + 18, py_ + 31), "A", font=small_f, fill=(20, 30, 20))
d.text((px_ + 34, py_ + 30), "Klimmen      6a", font=small_f, fill=GOLD)
im.save(OUTFILE)
print("saved", OUTFILE)
