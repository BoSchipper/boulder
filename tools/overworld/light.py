"""Mockup of the walking world the Octopath way: smooth shapes with pixel art in the
texture, not in the geometry. Light is worked out per texel and falls in a few tones of a
palette ramp, like the rock in the climbing screen. Grass, bracken and trees are drawn
pixel sprites facing the camera.

    python3 smooth.py [avond|middag] out.png [noui]
"""
import sys
import time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, zoom, map_coordinates, distance_transform_edt
import sprites_lib as sl
import trees_sdf as ts

TIME = sys.argv[1] if len(sys.argv) > 1 else "avond"
OUTFILE = sys.argv[2] if len(sys.argv) > 2 else "smooth.png"
NOUI = len(sys.argv) > 3 and sys.argv[3] == "noui"
FONT_DIR = "/Users/prive/boulder/assets/fonts/kenney_kenney-fonts/Fonts/"
W, H = 960, 540
T0 = time.time()

# The light makes the colour: sun (key) and sky (fill), then a grade per time of day.
LOOKS = {
    # summer midday: a high clear sun, cool blue-green shade, airy haze, rich greens
    "middag": dict(sun=(-0.35, 0.86, 0.38), sun_c=(1.2, 1.12, 0.96), amb=(0.34, 0.44, 0.58),
                   haze=(0.66, 0.8, 0.86), sky=(0.55, 0.72, 0.92), forest=(0.16, 0.26, 0.24),
                   expo=1.35, sat=1.4, rays=0.04, bloom=(0.82, 0.5), vign=0.35, flies=0,
                   lift=(0.0, 0.02, 0.03), clock="13:10", part="Middag"),
    # warm evening: a low orange sun from the side, long shadows, warm dusky shade, glow
    "avond": dict(sun=(-0.86, 0.24, 0.2), sun_c=(1.9, 0.98, 0.42), amb=(0.3, 0.19, 0.24),
                  haze=(1.0, 0.6, 0.34), sky=(0.95, 0.62, 0.42), forest=(0.17, 0.1, 0.1),
                  expo=1.5, sat=1.3, rays=0.24, bloom=(0.6, 1.1), vign=0.65, flies=70,
                  lift=(0.05, 0.015, 0.0), clock="20:41", part="Avond"),
}
L = LOOKS[TIME]
SUN = np.array(L["sun"]); SUN /= np.linalg.norm(SUN)
SUNC, AMB = np.array(L["sun_c"]), np.array(L["amb"])
SHADE = AMB

# ---------------------------------------------------------------- the world: a height field
NX, NZ = 240, 210          # world units (one unit is about 13 cm)
RES = 2                    # height samples per unit
TX = 0.5                   # one texel of the pixel textures, in world units


def vnoise2(shape, cell, seed):
    g = np.random.default_rng(seed).random((shape[0] // cell + 3, shape[1] // cell + 3))
    return zoom(g, cell, order=3)[: shape[0], : shape[1]]


GX, GZ = NX * RES, NZ * RES
X, Z = np.mgrid[0:GX, 0:GZ] / RES
hgt = 6 + 2.5 * vnoise2((GX, GZ), 60, 1) + 16 * np.clip(1 - Z / 70, 0, 1) ** 1.5
BOULDERS = [(122, 112, 26, 16, 28, 1), (42, 84, 20, 13, 22, 2), (196, 132, 18, 12, 18, 3),
            (88, 150, 6, 4, 5, 4), (164, 76, 10, 7, 9, 5)]
rockmask = np.zeros((GX, GZ), bool)
for bx, bz, rx, rz, bh, seed in BOULDERS:
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
surf[n1 > 0.6] = 2                                  # 2 needles
surf[(Z < 70) & (n2 > 0.55)] = 16                   # 16 heather
near = np.full((GX, GZ), 9.0)
for bx, bz, rx, rz, *_ in BOULDERS[:3]:
    near = np.minimum(near, np.hypot((X - bx) / (rx + 16), (Z - bz) / (rz + 14)))
surf[near < 1 + 0.3 * (n2 - 0.5)] = 1               # 1 sand
path_x = 118 + 14 * np.sin(Z / 32.0) - 0.1 * (Z - 140)
surf[(np.abs(X - path_x) < 5 + 2 * n1) & (Z > 126)] = 19
surf[rockmask] = 5


def H_at(x, z):
    x, z = np.asarray(x, float), np.asarray(z, float)
    v = map_coordinates(hgt, [np.atleast_1d(x) * RES, np.atleast_1d(z) * RES], order=1, mode="nearest")
    return v if x.ndim else v[0]


def S_at(x, z):
    xi = np.clip((np.asarray(x) * RES).astype(int), 0, GX - 1)
    zi = np.clip((np.asarray(z) * RES).astype(int), 0, GZ - 1)
    return surf[xi, zi]


# trees and people shade the ground: simple occluders on the same grid
rng = np.random.default_rng(7)
TREES = []
for k in range(46):
    x, z = rng.uniform(1, NX - 3), rng.uniform(4, 70)
    kind = "pine" if rng.random() < 0.6 else ("spruce" if rng.random() < 0.6 else "birch")
    TREES.append((x, z, kind, rng.uniform(62, 86) if kind == "pine" else rng.uniform(34, 52)))
occ_lo = np.full((GX, GZ), 1e9)
occ_hi = np.full((GX, GZ), -1e9)
holes = vnoise2((GX, GZ), 8, 33)
for x, z, kind, h in TREES:
    g = float(H_at(x, z))
    d = np.hypot(X - x, Z - z)
    t = d < 1.2
    occ_lo[t] = g; occ_hi[t] = g + h
    crown = (10 if kind == "pine" else 7) * (0.8 + 0.4 * holes)
    lo = g + h * (0.6 if kind == "pine" else 0.2)
    c = d < crown
    occ_lo[c] = np.minimum(occ_lo[c], lo); occ_hi[c] = np.maximum(occ_hi[c], g + h)
YOU = (120.0, 150.0)
PEOPLE = [(YOU, sl.YOU_ROWS, 0.0), ((193.0, 146.0), sl.CLIMBER_ROWS, 9.0),
          ((186.0, 152.0), sl.SPOTTER_ROWS, 0.0), ((40.0, 100.0), sl.SITTER_ROWS, 0.0)]
for (x, z), _, lift in PEOPLE:
    g = float(H_at(x, z))
    p = np.hypot(X - x, Z - z) < 1.5
    occ_lo[p] = np.minimum(occ_lo[p], g + lift); occ_hi[p] = np.maximum(occ_hi[p], g + lift + 14)
# Trees in the clearing itself: real 3D shapes, so you walk between and behind them.
FIELD = []
for f, x, z, h, seed in [(ts.spruce, 68, 160, 36, 1), (ts.broadleaf, 172, 178, 30, 2), (ts.birch, 56, 124, 38, 3),
                         (ts.birch, 66, 136, 34, 4), (ts.scots_pine, 180, 96, 62, 5), (ts.spruce, 216, 182, 46, 6),
                         (ts.spruce, 30, 150, 40, 7), (ts.broadleaf, 18, 198, 30, 8), (ts.spruce, 150, 72, 40, 9),
                         (ts.broadleaf, 96, 84, 30, 10)]:
    FIELD.append(f(x, z, float(H_at(x, z)), h, seed))
print("world", round(time.time() - T0, 1))

# ---------------------------------------------------------------- camera and ray march
CAM = np.array([120.0, 80.0, 268.0])
LOOK = np.array([120.0, 18.0, 108.0])
fwd = LOOK - CAM; fwd /= np.linalg.norm(fwd)
right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
upv = np.cross(right, fwd)
FOV = np.radians(36)
py, px = np.mgrid[0:H, 0:W]
sx = (px + 0.5 - W / 2) / (H / 2) * np.tan(FOV / 2)
sy = -(py + 0.5 - H / 2) / (H / 2) * np.tan(FOV / 2)
dirs = fwd[None] + sx.reshape(-1, 1) * right[None] + sy.reshape(-1, 1) * upv[None]
dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
N = len(dirs)
TOP = hgt.max() + 1
t = np.where(dirs[:, 1] < 0, (CAM[1] - TOP) / -np.minimum(dirs[:, 1], -1e-6), 1e9)
t = np.maximum(t, 0)
hit = np.zeros(N, bool)
tt = np.full(N, 1e9)
idx = np.nonzero(dirs[:, 1] < 0)[0]
tc = t[idx]
for s in range(900):
    if idx.size == 0:
        break
    p = CAM + dirs[idx] * tc[:, None]
    inside = (p[:, 0] >= 0) & (p[:, 0] < NX) & (p[:, 2] >= 0) & (p[:, 2] < NZ)
    below = p[:, 1] < H_at(p[:, 0], p[:, 2])
    got = below & inside
    if got.any():
        # refine between the last two steps
        lo_, hi_ = tc[got] - 0.5, tc[got]
        dd = dirs[idx[got]]
        for _ in range(6):
            mid = (lo_ + hi_) / 2
            pm = CAM + dd * mid[:, None]
            b = pm[:, 1] < H_at(pm[:, 0], pm[:, 2])
            hi_ = np.where(b, mid, hi_); lo_ = np.where(b, lo_, mid)
        hit[idx[got]] = True
        tt[idx[got]] = hi_
    gone = got | (p[:, 1] < 0) | (tc > 700)
    idx, tc = idx[~gone], tc[~gone] + 0.5
pos = CAM + dirs * np.where(hit, tt, 0)[:, None]
print("march", round(time.time() - T0, 1), hit.mean())
th_, ttr, twh, tmt = ts.trace(FIELD, np.repeat(CAM[None], N, 0), dirs, np.where(hit, tt, 700.0))
hit_t = hit & ~th_
print("trees", round(time.time() - T0, 1), th_.mean())

# ---------------------------------------------------------------- texels
# The hit point snaps to the centre of its texel: everything after this is worked out per
# texel, so light and shadow come out in crisp pixels on the smooth shape.
hi = np.nonzero(hit_t)[0]
p = pos[hi]


def normal_at(x, z):
    e = 0.5
    dx = H_at(x + e, z) - H_at(x - e, z)
    dz = H_at(x, z + e) - H_at(x, z - e)
    n = np.stack([-dx / (2 * e), np.ones_like(dx), -dz / (2 * e)], -1)
    return n / np.linalg.norm(n, axis=1, keepdims=True)


n0 = normal_at(p[:, 0], p[:, 2])
steep = np.abs(n0[:, 1]) < 0.55
# on flat ground the texels lie in x, z; on steep faces they stand up in x (or z) and y
cx = (np.floor(p[:, 0] / TX) + 0.5) * TX
cz = (np.floor(p[:, 2] / TX) + 0.5) * TX
face_x = steep & (np.abs(n0[:, 2]) >= np.abs(n0[:, 0]))
face_z = steep & ~face_x
cy = (np.floor(p[:, 1] / TX) + 0.5) * TX
c = np.stack([cx, H_at(cx, cz), cz], -1)
c[face_x] = np.stack([cx[face_x], cy[face_x], p[face_x, 2]], -1)
c[face_z] = np.stack([p[face_z, 0], cy[face_z], cz[face_z]], -1)
nrm = normal_at(c[:, 0], c[:, 2])
ti = np.stack([np.floor(c[:, 0] / TX), np.floor(c[:, 1] / TX), np.floor(c[:, 2] / TX)], -1).astype(np.int64)
thash = ((ti[:, 0] * 73856093) ^ (ti[:, 1] * 19349663) ^ (ti[:, 2] * 83492791)) % 1000 / 1000.0

# sun shadow from the texel centre, over the height field and the occluders
lit = np.ones(hi.size)
sp = c + nrm * 0.3
horiz = np.hypot(SUN[0], SUN[2])
alive = np.arange(hi.size)
for k in range(1, 300):
    q = sp[alive] + SUN * k * 0.8
    out = (q[:, 0] < 0) | (q[:, 0] >= NX) | (q[:, 2] < 0) | (q[:, 2] >= NZ) | (q[:, 1] > 120)
    xi = np.clip((q[:, 0] * RES).astype(int), 0, GX - 1)
    zi = np.clip((q[:, 2] * RES).astype(int), 0, GZ - 1)
    blocked = ~out & ((q[:, 1] < H_at(q[:, 0], q[:, 2])) | ((occ_lo[xi, zi] < q[:, 1]) & (occ_hi[xi, zi] > q[:, 1])))
    lit[alive[blocked]] = 0
    alive = alive[~(blocked | out)]
    if alive.size == 0:
        break
tsh, _, _, _ = ts.trace(FIELD, sp, SUN, 300.0, 70)
lit[tsh] = 0
print("shadow", round(time.time() - T0, 1))


def hf_shadow(spts):
    """The same sun test for points on the trees: height field and the back trees."""
    lit_ = np.ones(len(spts))
    alive_ = np.arange(len(spts))
    for k in range(1, 300):
        q = spts[alive_] + SUN * k * 0.8
        out_ = (q[:, 0] < 0) | (q[:, 0] >= NX) | (q[:, 2] < 0) | (q[:, 2] >= NZ) | (q[:, 1] > 120)
        xi = np.clip((q[:, 0] * RES).astype(int), 0, GX - 1)
        zi = np.clip((q[:, 2] * RES).astype(int), 0, GZ - 1)
        bl = ~out_ & ((q[:, 1] < H_at(q[:, 0], q[:, 2])) | ((occ_lo[xi, zi] < q[:, 1]) & (occ_hi[xi, zi] > q[:, 1])))
        lit_[alive_[bl]] = 0
        alive_ = alive_[~(bl | out_)]
        if alive_.size == 0:
            break
    return lit_

# ambient occlusion from the height field around the texel
ao = np.zeros(hi.size)
for rad in (2.0, 6.0):
    for a in np.linspace(0, 2 * np.pi, 8, endpoint=False):
        hx = H_at(c[:, 0] + np.cos(a) * rad, c[:, 2] + np.sin(a) * rad)
        ao += np.clip((hx - c[:, 1]) / rad, 0, 1)
ao = np.clip(1 - ao / 10, 0.35, 1)
ao *= np.clip(0.45 + ts.min_dist(FIELD, c + np.array([0, 2.5, 0])) / 5, 0.45, 1)  # darker under the trees

# ---------------------------------------------------------------- palette ramps
# Each material is a ramp from its deepest shade (cool, purple) to its sunlit top (warm).
# The light falls on one step of the ramp per texel.
RAMPS = {
    1: [(70, 56, 74), (128, 106, 104), (178, 154, 128), (214, 190, 146), (236, 218, 176)],     # sand
    2: [(46, 32, 40), (78, 52, 46), (112, 78, 54), (150, 106, 64), (184, 138, 82)],            # needles
    3: [(26, 34, 40), (40, 58, 44), (62, 86, 50), (92, 116, 58), (134, 150, 72)],             # moss
    5: [(64, 58, 78), (106, 98, 110), (150, 140, 136), (188, 178, 158), (226, 216, 190)],      # sandstone
    16: [(50, 38, 56), (84, 62, 82), (120, 86, 112), (156, 112, 138), (186, 146, 160)],        # heather
    19: [(84, 70, 84), (150, 132, 124), (204, 186, 156), (232, 216, 182), (248, 238, 210)],    # path
    38: [(56, 60, 66), (88, 98, 86), (126, 138, 104), (164, 172, 126), (198, 202, 150)],       # lichen
    30: [(32, 24, 30), (56, 40, 40), (84, 60, 52), (114, 84, 64), (144, 110, 80)],             # bark
    31: [(54, 30, 34), (98, 52, 42), (146, 80, 52), (188, 112, 64), (222, 148, 86)],           # pine bark, orange
    32: [(62, 58, 70), (124, 120, 126), (184, 180, 176), (222, 218, 208), (244, 240, 228)],    # birch bark
    33: [(20, 18, 22), (34, 30, 34), (46, 40, 44), (60, 54, 56), (76, 70, 70)],                # birch marks
    34: [(16, 28, 34), (24, 48, 42), (38, 72, 50), (60, 100, 58), (98, 132, 68)],              # spruce
    35: [(22, 34, 32), (38, 62, 40), (62, 94, 48), (100, 130, 58), (150, 166, 76)],            # broadleaf
    36: [(18, 30, 34), (30, 52, 44), (48, 80, 54), (76, 108, 62), (116, 140, 74)],             # pine needles
    37: [(62, 48, 32), (118, 92, 42), (170, 140, 54), (212, 184, 74), (240, 218, 112)],        # birch leaves
}
mat = S_at(c[:, 0], c[:, 2])
# The rock in facets: every facet of the stone takes one light, like a painted rock. The
# facets come from Voronoi cells over the surface; their borders are the cracks.
rk = np.nonzero(mat == 5)[0]
CELL = 5.0
q = c[rk] / CELL
base = np.floor(q).astype(np.int64)
d1 = np.full(rk.size, 1e9); d2 = np.full(rk.size, 1e9); pt1 = np.zeros((rk.size, 3)); j1 = np.zeros((rk.size, 3))
for ox in (-1, 0, 1):
    for oy in (-1, 0, 1):
        for oz in (-1, 0, 1):
            cid = base + np.array([ox, oy, oz])
            hsh = np.abs(cid[:, 0] * 73856093 ^ cid[:, 1] * 19349663 ^ cid[:, 2] * 83492791)
            jit = np.stack([(hsh % 1000) / 1000, (hsh // 1000 % 1000) / 1000, (hsh // 1000000 % 1000) / 1000], -1)
            ptc = cid + 0.15 + 0.7 * jit
            d = np.linalg.norm(q - ptc, axis=1)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            pt1 = np.where(closer[:, None], ptc, pt1)
            j1 = np.where(closer[:, None], jit, j1)
            d1 = np.where(closer, d, d1)
fc = pt1 * CELL
nf = normal_at(fc[:, 0], fc[:, 2]) + 0.22 * (j1 - 0.5)
nf /= np.linalg.norm(nf, axis=1, keepdims=True)
nr = 0.5 * nrm[rk] + 0.5 * nf
nrm[rk] = nr / np.linalg.norm(nr, axis=1, keepdims=True)
crack = np.zeros(hi.size, bool)
crack[rk] = ((d2 - d1) * CELL < 0.25) & (j1[:, 0] > 0.55)  # only some borders are real cracks
lam = np.clip(nrm @ SUN, 0, 1) * lit
level = lam * 0.85 + 0.22 * ao + 0.08 * nrm[:, 1] - 0.22
# texture detail inside the material: cracks, layers, speckles move one step on the ramp
detail = np.zeros(hi.size)
detail += np.where(thash > 0.94, 0.12, 0) - np.where(thash < 0.05, 0.12, 0)
# sandstone strata: a dark seam with a lit ledge just above it
rock_steep = (mat == 5) & steep
sn = vnoise2((128, 128), 10, 3)[ti[:, 0] % 128, ti[:, 2] % 128]
fy = ((c[:, 1] + 4 * sn) % 4.6) / 4.6
detail -= (rock_steep & (fy < 0.09)) * 0.36
detail += (rock_steep & (fy >= 0.09) & (fy < 0.2)) * 0.18
detail -= crack * 0.32
# dark streaks of patina where rain runs down the faces, fading out lower down
streak = vnoise2((480, 8), 3, 71)[(ti[:, 0] + ti[:, 2]) % 480, 0]
detail -= rock_steep * (streak > 0.68) * 0.2
# the round holes of Font sandstone: small and dark in the middle of some facets
holes_ = np.zeros(hi.size, bool)
holes_[rk] = (d1 * CELL < 0.45) & (j1[:, 1] > 0.8)
detail -= holes_ * 0.6
# the strata stand out more on Font sandstone
# moss in clumps on top of the blocks, grey-green lichen on the faces
clump = vnoise2((480, 480), 6, 61)[ti[:, 0] % 480, (ti[:, 2] + ti[:, 1]) % 480]
mat[(mat == 5) & (nrm[:, 1] > 0.6) & (clump > 0.58)] = 3
mat[(mat == 5) & steep & (clump > 0.74)] = 38
# ordered dither at the band edges, like hand-drawn pixel shading
bayer = np.array([[0, 2], [3, 1]]) / 4.0 - 0.375
dith = bayer[ti[:, 0] % 2, (ti[:, 1] + ti[:, 2]) % 2] * 0.04
tone = np.clip(3 + np.round(detail * 5), 1, 4).astype(int)
col = np.zeros((hi.size, 3))
for m, ramp in RAMPS.items():
    sel = mat == m
    col[sel] = np.array(ramp, float)[tone[sel]] / 255.0
col = col ** 2.2


def lighting(lam_, ao_, up_, d_):
    """Sun in four hard steps per texel, sky fill in two: pixel-art light on smooth shapes."""
    key = np.clip(np.round((lam_ * 1.1 + d_) * 4) / 4, 0, 1)
    fill = np.where(ao_ + d_ > 0.62, 1.0, 0.62) * (0.65 + 0.35 * up_)
    return SUNC * key[:, None] * 1.15 + AMB * fill[:, None]


col = col * lighting(lam, ao, np.clip(nrm[:, 1], 0, 1), dith)

img = np.zeros((N, 3))
tsky = np.clip(dirs[:, 1] * 2 + 0.5, 0, 1)[:, None]
# beyond the clearing: the deep forest, dark, with warm light only high up
forest = np.array(L["forest"]) ** 2.2
tsky = np.clip((dirs[:, 1] + 0.05) * 4, 0, 1)[:, None]
forest = np.array(L["forest"]) ** 2.2
img[:] = forest * (1 - tsky) + (np.array(L["haze"]) ** 2.2) * 0.8 * tsky
img[hi] = col
depth = np.full(N, 900.0)
depth[hi] = tt[hi]

# the trees in the clearing, per texel like everything else
tk = np.nonzero(th_)[0]
ptk = CAM + dirs[tk] * ttr[tk, None]
ctk = (np.floor(ptk / TX) + 0.5) * TX
wk = twh[tk]
nk = ts.normal(FIELD, wk, ctk)
lit_k = hf_shadow(ptk + nk * 0.5)
shk, _, _, _ = ts.trace(FIELD, ptk + nk * 0.6, SUN, 300.0, 70)
lit_k[shk] = 0
aok = np.clip(0.3 + ts.min_dist(FIELD, ctk + nk * 2.0) / 2.5, 0.3, 1)
mk = tmt[tk].copy()
tik = np.floor(ctk / TX).astype(np.int64)
hk = np.abs(tik[:, 0] * 73856093 ^ tik[:, 1] * 19349663 ^ tik[:, 2] * 83492791) % 1000 / 1000.0
mk[(mk == 32) & (tik[:, 1] % 5 == 0) & (hk > 0.45)] = 33  # the black marks on a birch
lamk = np.clip(nk @ SUN, 0, 1) * lit_k
leafy = np.isin(mk, ts.FOLIAGE)
levk = np.zeros(tk.size)
levk += np.where(leafy & (hk > 0.8), 0.2, 0) - np.where(leafy & (hk < 0.2), 0.2, 0)  # leaves
levk += np.where(~leafy & (hk > 0.85), 0.2, 0) - np.where(~leafy & (tik[:, 0] % 3 == 0), 0.2, 0)  # bark
dk = bayer[tik[:, 0] % 2, (tik[:, 1] + tik[:, 2]) % 2] * 0.05
stk = np.clip(3 + np.round(levk * 5), 1, 4).astype(int)
colk = np.zeros((tk.size, 3))
for m, ramp in RAMPS.items():
    sel = mk == m
    colk[sel] = np.array(ramp, float)[stk[sel]] / 255.0
colk = colk ** 2.2
colk = colk * lighting(lamk, aok, np.clip(nk[:, 1], 0, 1), dk)
colk[leafy] += colk[leafy] * SUNC * 0.12 * lit_k[leafy, None]  # sun through the leaves
img[tk] = colk
depth[tk] = ttr[tk]
img = img.reshape(H, W, 3)
depth = depth.reshape(H, W)
print("shade", round(time.time() - T0, 1))

# ---------------------------------------------------------------- sprites
def project(pnt):
    d = pnt - CAM
    zc = d @ fwd
    xs = (d @ right) / zc / np.tan(FOV / 2) * (H / 2) + W / 2
    ys = -(d @ upv) / zc / np.tan(FOV / 2) * (H / 2) + H / 2
    return xs, ys, np.linalg.norm(d)


def px_per_unit(dd):
    return (H / 2) / np.tan(FOV / 2) / dd


def sprite_light(spr, sunlit):
    a = spr[..., 3] > 0
    dist = distance_transform_edt(np.pad(a, 1))[1:-1, 1:-1]
    height = gaussian_filter(np.sqrt(dist) * 1.15 + spr[..., :3].mean(-1) * 0.6, 0.6)
    gy_, gx_ = np.gradient(height)
    n = np.stack([-gx_, gy_, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    world = n[..., :1] * right + n[..., 1:2] * upv - n[..., 2:3] * fwd
    lam_ = np.clip(world @ SUN, 0, 1) * sunlit
    alb_ = spr[..., :3] ** 2.2
    key = np.clip(np.round(lam_ * 1.1 * 4) / 4, 0, 1)
    cc = alb_ * (SUNC * key[..., None] * 1.15 + AMB * 0.9)
    return np.concatenate([cc, spr[..., 3:]], -1)


def grass_tuft(seed, kind):
    """An Octopath-style clump: thick blades in four tones, dark at the root, lit tips."""
    r = np.random.default_rng(seed)
    ramps = {"grass": [(30, 46, 38), (52, 80, 46), (86, 116, 56), (140, 158, 74)],
             "bracken": [(70, 44, 34), (128, 78, 40), (178, 118, 52), (222, 168, 80)],
             "heather": [(52, 40, 56), (100, 70, 96), (156, 98, 140), (204, 140, 180)]}[kind]
    w, h = (14, 10) if kind != "heather" else (10, 6)
    s = np.zeros((h, w, 4))
    for b in range(w + 2):
        x0 = r.uniform(1, w - 1)
        lean = r.uniform(-0.45, 0.45)
        ln = r.uniform(h * 0.45, h)
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


sprites = []  # (depth, xs, ys, rgba already lit, pixels per texel)
for x, z, kind, h in TREES:
    spr = sl.pine() if kind != "birch" else sl.birch()
    g = float(H_at(x, z))
    xs, ys, dd = project(np.array([x, g, z]))
    scale = h * px_per_unit(dd) / spr.shape[0]
    sprites.append((dd, xs, ys, sprite_light(spr, 1.0), scale))
for (x, z), rows, lift in PEOPLE:
    g = float(H_at(x, z)) + lift
    xs, ys, dd = project(np.array([x, g, z]))
    sprites.append((dd - 1, xs, ys, sprite_light(sl.sprite_from_rows(rows, sl.P), 1.0), 3))
for x0, z0, pal in [(112, 132, sl.PAD2_P), (188, 148, sl.PAD_P), (34, 100, sl.PAD_P)]:
    g = float(H_at(x0 + 5, z0))
    xs, ys, dd = project(np.array([x0 + 5, g, z0]))
    sprites.append((dd, xs, ys + 8, sprite_light(sl.sprite_from_rows(sl.PAD_ROWS, pal), 1.0), 3))
vnoise_tufts = vnoise2((240, 210), 9, 55)
r = np.random.default_rng(21)
tufts = {k: [grass_tuft(j * 10 + i, k) for i in range(6)] for j, k in enumerate(("grass", "bracken", "heather"))}
tufts_todo = []
for k in range(5200):
    x, z = r.uniform(0, NX), r.uniform(60, NZ)
    m = int(S_at(x, z))
    if m in (5, 19) or (m == 1 and r.random() < 0.93) or (m == 2 and r.random() < 0.6):
        continue
    if m == 3 and vnoise_tufts[int(x) % 240, int(z) % 210] < 0.4:
        continue  # bare patches of moss between the clumps
    kind = "heather" if m == 16 else ("bracken" if m == 2 else "grass")
    g = float(H_at(x, z))
    xs, ys, dd = project(np.array([x, g, z]))
    if not (-40 < xs < W + 40 and -20 < ys < H + 40):
        continue
    tufts_todo.append((dd, xs, ys + 1, kind, int(r.integers(6)), TX * px_per_unit(dd), x, g, z))
base_ = np.array([[t_[6], t_[7] + 1.5, t_[8]] for t_ in tufts_todo])
sun_ok = hf_shadow(base_)
sun_ok[ts.trace(FIELD, base_, SUN, 300.0, 70)[0]] = 0
lit_cache = {}
for (dd, xs, ys, kind, v, sc, *_), ok_ in zip(tufts_todo, sun_ok):
    key_ = (kind, v, ok_)
    if key_ not in lit_cache:
        lit_cache[key_] = sprite_light(tufts[kind][v], float(ok_))
    sprites.append((dd, xs, ys, lit_cache[key_], sc))
sprites.sort(key=lambda s_: -s_[0])  # far first

for dd, xs, ys, spr, scale in sprites:
    hh_, ww_ = spr.shape[:2]
    th_, tw_ = max(int(round(hh_ * scale)), 1), max(int(round(ww_ * scale)), 1)
    if th_ > 1200:
        continue
    yi = (np.arange(th_) / scale).astype(int).clip(0, hh_ - 1)
    xi = (np.arange(tw_) / scale).astype(int).clip(0, ww_ - 1)
    big = spr[yi][:, xi]
    ox, oy = int(xs - tw_ / 2), int(ys - th_)
    y0, y1 = max(oy, 0), min(oy + th_, H)
    x0, x1 = max(ox, 0), min(ox + tw_, W)
    if y0 >= y1 or x0 >= x1:
        continue
    patch = big[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    m = (patch[..., 3] > 0) & (depth[y0:y1, x0:x1] > dd - 2)
    img[y0:y1, x0:x1][m] = patch[..., :3][m]
    depth[y0:y1, x0:x1][m] = dd
print("sprites", round(time.time() - T0, 1))

# ---------------------------------------------------------------- post
fog = 1 - np.exp(-np.clip(np.minimum(depth, 400) - 200, 0, None) / 260.0)
img = img * (1 - fog[..., None] * 0.4) + (np.array(L["haze"]) ** 2.2) * 0.55 * fog[..., None] * 0.4
_, _, d_you = project(np.array([YOU[0], float(H_at(*YOU)), YOU[1]]))
amount = np.clip((np.abs(depth - d_you) - 18) / 22.0, 0, 3.999)
levels = [0, 1.5, 3.2, 5.5, 8.5]
stack = np.stack([img] + [np.stack([gaussian_filter(img[..., c_], s_) for c_ in range(3)], -1) for s_ in levels[1:]])
lo_ = amount.astype(int)
fr = (amount - lo_)[..., None]
yy_, xx_ = np.mgrid[0:H, 0:W]
out = stack[lo_, yy_, xx_] * (1 - fr) + stack[np.minimum(lo_ + 1, 4), yy_, xx_] * fr
across = xx_ * 0.8 - yy_ * 0.6
rays = np.clip(np.sin(across / 21.0) * 0.6 + np.sin(across / 53.0 + 1.3) * 0.7, 0, 1) ** 3
rays *= np.clip(1.0 - yy_ / H, 0, 1) * np.clip(1.2 - xx_ / W, 0, 1)
out += rays[..., None] * (np.array(L["haze"]) ** 2.2) * L["rays"]
# fireflies in the dusk: little warm lights low over the grass
rf = np.random.default_rng(9)
for k in range(L["flies"]):
    fx, fy = rf.uniform(40, W - 40), rf.uniform(H * 0.35, H * 0.92)
    d2 = (xx_ - fx) ** 2 + (yy_ - fy) ** 2
    out += (np.exp(-d2 / 1.2) * 3.0)[..., None] * np.array([1.0, 0.85, 0.35])
thr, amt = L["bloom"]
bright = np.clip(out - thr, 0, None)
out += np.stack([gaussian_filter(bright[..., c_], 5) * 0.6 * amt + gaussian_filter(bright[..., c_], 22) * 0.8 * amt for c_ in range(3)], -1)
r = np.random.default_rng(3)
for k in range(40):
    mx_, my_ = r.uniform(0, W), r.uniform(0, H)
    b = amount[int(my_), int(mx_)]
    d2 = (xx_ - mx_) ** 2 + (yy_ - my_) ** 2
    cc = np.array(L["haze"]) ** 2.2
    out += ((d2 < (4 + b * 4) ** 2) * 0.05)[..., None] * cc if b > 1.5 else (np.exp(-d2 / 1.5) * 1.0)[..., None] * cc
out = 1 - np.exp(-np.clip(out, 0, None) * L["expo"])
out = out ** (1 / 2.2)
lum = out.mean(-1, keepdims=True)
out = lum + (out - lum) * L["sat"]
out += (1 - np.clip(lum, 0, 1)) * np.array(L["lift"])  # tint the shadows: blue-green at noon, warm at dusk
v_ = (xx_ / W - 0.5) ** 2 * 1.3 + (yy_ / H - 0.5) ** 2 * 1.2
out *= (1 - L["vign"] * v_)[..., None]
out = np.clip(out, 0, 1)
out[:34] = 0.02
out[H - 34:] = 0.02
im = Image.fromarray((out * 255).astype(np.uint8))

if not NOUI:
    d = ImageDraw.Draw(im)
    big_f = ImageFont.truetype(FONT_DIR + "Kenney Pixel.ttf", 32)
    small_f = ImageFont.truetype(FONT_DIR + "Kenney Pixel.ttf", 16)
    GOLD = (222, 186, 110)

    def plate(x, y, w, h):
        d.rectangle([x, y, x + w, y + h], fill=(24, 18, 28))
        d.rectangle([x + 2, y + 2, x + w - 2, y + h - 2], outline=GOLD)
        for cx_, cy_ in [(x + 2, y + 2), (x + w - 2, y + 2), (x + 2, y + h - 2), (x + w - 2, y + h - 2)]:
            d.rectangle([cx_ - 2, cy_ - 2, cx_ + 2, cy_ + 2], fill=(240, 210, 140))

    tl = "BAS CUVIER"
    tw = d.textlength(tl, font=big_f)
    d.text((W / 2 - tw / 2, 44), tl, font=big_f, fill=(250, 238, 214))
    d.line([W / 2 - 170, 62, W / 2 - tw / 2 - 16, 62], fill=GOLD)
    d.line([W / 2 + tw / 2 + 16, 62, W / 2 + 170, 62], fill=GOLD)
    tl = "Fontainebleau  ·  " + L["part"]
    tw = d.textlength(tl, font=small_f)
    d.text((W / 2 - tw / 2, 74), tl, font=small_f, fill=GOLD)
    xs, ys, _ = project(np.array([YOU[0], float(H_at(*YOU)), YOU[1]]))
    px_, py_ = int(xs) + 34, int(ys) - 110
    plate(px_, py_, 172, 52)
    d.text((px_ + 14, py_ + 2), "La Marie-Rose", font=big_f, fill=(250, 238, 214))
    d.ellipse([px_ + 14, py_ + 32, px_ + 28, py_ + 46], fill=(110, 170, 90))
    d.text((px_ + 18, py_ + 31), "A", font=small_f, fill=(20, 30, 20))
    d.text((px_ + 34, py_ + 30), "Klimmen      6a", font=small_f, fill=GOLD)
im.save(OUTFILE)
print("saved", OUTFILE, round(time.time() - T0, 1))
