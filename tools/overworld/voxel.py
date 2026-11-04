"""Mockup of the walking world as a voxel diorama, like Lumina and the HD-2D video: every
tree, bush, grass blade and rock is built from small cubes, each cube a 'pixel' with its
own colour. Ray traced with sun shadows, ambient occlusion, haze, depth of field and bloom.
Pixel sprites for the people.

    python3 voxel.py [avond|middag] out.png [noui]
"""
import sys
import time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, zoom
import sprites_lib as sl

TIME = sys.argv[1] if len(sys.argv) > 1 else "avond"
OUTFILE = sys.argv[2] if len(sys.argv) > 2 else "voxel.png"
NOUI = len(sys.argv) > 3 and sys.argv[3] == "noui"
FONT_DIR = "/Users/prive/boulder/assets/fonts/kenney_kenney-fonts/Fonts/"
W, H = 960, 540
T0 = time.time()

LOOKS = {
    "avond": dict(sun=(-0.8, 0.34, 0.46), sun_c=(1.45, 0.88, 0.5), sky=(0.36, 0.38, 0.62),
                  haze=(1.0, 0.72, 0.52), bounce=(0.22, 0.14, 0.08), clock="19:42", part="Avond"),
    "middag": dict(sun=(-0.4, 0.82, 0.42), sun_c=(1.25, 1.2, 1.08), sky=(0.46, 0.56, 0.78),
                   haze=(0.8, 0.88, 0.95), bounce=(0.12, 0.12, 0.08), clock="13:10", part="Middag"),
}
L = LOOKS[TIME]
SUN = np.array(L["sun"]); SUN /= np.linalg.norm(SUN)

# ---------------------------------------------------------------- the world in voxels
NXv, NYv, NZv = 240, 104, 210
G = np.zeros((NXv, NYv, NZv), np.uint8)
X, Z = np.mgrid[0:NXv, 0:NZv]


def vnoise2(shape, cell, seed):
    g = np.random.default_rng(seed).random((shape[0] // cell + 3, shape[1] // cell + 3))
    return zoom(g, cell, order=3)[: shape[0], : shape[1]]


def vnoise3(shape, cell, seed):
    g = np.random.default_rng(seed).random(tuple(s // cell + 3 for s in shape))
    return zoom(g, cell, order=1)[: shape[0], : shape[1], : shape[2]]


rng = np.random.default_rng(7)
# Ground: a forest floor that rises into a bank under the trees at the back.
ground = 6 + 2.5 * vnoise2((NXv, NZv), 30, 1) + 16 * np.clip(1 - Z / 70, 0, 1) ** 1.5
ground = ground.round().astype(int)
BOULDERS = [  # x, z, rx, rz, height, seed
    (122, 112, 26, 16, 28, 1),
    (42, 84, 20, 13, 22, 2),
    (196, 132, 18, 12, 18, 3),
    (88, 150, 6, 4, 5, 4),
    (164, 76, 10, 7, 9, 5),
]
n1, n2 = vnoise2((NXv, NZv), 18, 41), vnoise2((NXv, NZv), 11, 42)
surf = np.full((NXv, NZv), 3)                         # moss
surf[n1 > 0.6] = 2                                    # pine needles
surf[(Z < 70) & (n2 > 0.55)] = 16                     # heather on the bank
near = np.full((NXv, NZv), 9.0)
for bx, bz, rx, rz, *_ in BOULDERS[:3]:
    near = np.minimum(near, np.hypot((X - bx) / (rx + 16), (Z - bz) / (rz + 14)))
surf[near < 1 + 0.3 * (n2 - 0.5)] = 1                 # sand washed off the blocks
path_x = 118 + 14 * np.sin(Z / 32.0) - 0.1 * (Z - 140)
surf[(np.abs(X - path_x) < 5 + 2 * n1) & (Z > 126)] = 19

ys = np.arange(NYv)[None, :, None]
fill = ys < ground[:, None, :]
G[fill] = 2
top_y = ground - 1
G[X, top_y, Z] = surf

# Font blocks: rounded, steep, layered sandstone with lichen on top.
band_noise = vnoise3((NXv, NYv, NZv), 6, 9)
for bx, bz, rx, rz, bh, seed in BOULDERS:
    wob = 1 + 0.12 * (vnoise2((NXv, NZv), 9, seed) - 0.5)
    ang = np.arctan2(Z - bz, X - bx)
    lobes = 1 + 0.1 * np.sin(3 * ang + seed) + 0.07 * np.sin(5 * ang + 2 * seed)
    r = np.sqrt(((X - bx) / (rx * wob * lobes)) ** 2 + ((Z - bz) / (rz * wob * lobes)) ** 2)
    tilt = 1 + 0.18 * (X - bx) / rx
    hh = bh * tilt * np.clip(1 - r ** 5, 0, 1) ** 0.3 + (r < 1) * bh * 0.08 * (vnoise2((NXv, NZv), 5, seed + 9) - 0.5)
    top = np.where(r < 1, ground + hh, 0).round().astype(int)
    col = (ys < top[:, None, :]) & (ys >= ground[:, None, :] - 1)
    layered = ((ys + 4 * band_noise) % 7) < 1.0
    G[col] = 5
    G[col & np.broadcast_to(layered, col.shape)] = 6
    # lichen on the topmost voxel of a block, here and there
    has = top > ground
    lich = has & (vnoise2((NXv, NZv), 3, seed + 20) > 0.62)
    xi, zi = np.nonzero(lich)
    G[xi, np.clip(top[xi, zi] - 1, 0, NYv - 1), zi] = 7
    # sandstone also stains darker where water runs down the front
    stain = has & (vnoise2((NXv, NZv), 2, seed + 30) > 0.72)
    xi, zi = np.nonzero(stain)
    for k in range(1, 8):
        yy = np.clip(top[xi, zi] - 1 - k, 0, NYv - 1)
        keep = G[xi, yy, zi] == 5
        G[xi[keep], yy[keep], zi[keep]] = 6


def gy(x, z):
    """The height of the top of whatever stands at x, z."""
    col = globals().get("G1", G)[int(np.clip(x, 0, NXv - 1)), :, int(np.clip(z, 0, NZv - 1))]
    filled = np.nonzero(col)[0]
    return int(filled.max()) + 1 if filled.size else 0


def blob(cx, cy, cz, rx, ry, rz, mat, mat_lit=None, density=0.62, seed=0):
    x0, x1 = int(max(cx - rx - 1, 0)), int(min(cx + rx + 2, NXv))
    y0, y1 = int(max(cy - ry - 1, 0)), int(min(cy + ry + 2, NYv))
    z0, z1 = int(max(cz - rz - 1, 0)), int(min(cz + rz + 2, NZv))
    if x0 >= x1 or y0 >= y1 or z0 >= z1:
        return
    xs_, ys_, zs_ = np.mgrid[x0:x1, y0:y1, z0:z1]
    d = ((xs_ - cx) / rx) ** 2 + ((ys_ - cy) / ry) ** 2 + ((zs_ - cz) / rz) ** 2
    rnd = np.random.default_rng(seed).random(d.shape)
    inside = (d < 1) & ((d < 0.55) | (rnd < density))
    sub = G[x0:x1, y0:y1, z0:z1]
    sub[inside & (sub == 0)] = mat
    if mat_lit is not None:  # the top and the sunny side of a clump are lighter
        lit = inside & (((ys_ - cy) / ry - (xs_ - cx) / rx * 0.6) > 0.35)
        sub[lit & (sub == mat)] = mat_lit


def pine(x, z, h, seed):
    g = gy(x, z)
    r = np.random.default_rng(seed)
    for y in range(g, min(g + h, NYv)):
        m = 8 if y > g + h * 0.45 else 9
        G[int(x):int(x) + 2, y, int(z):int(z) + 2] = m
    for k in range(6):  # flat pads of needles high up, like a Scots pine
        cy = g + h * r.uniform(0.62, 0.98)
        blob(x + r.uniform(-8, 8), cy, z + r.uniform(-6, 6), r.uniform(7, 12), r.uniform(3, 5), r.uniform(6, 10),
             10, 11, 0.7, seed * 10 + k)


def spruce(x, z, h, seed):
    """A cone of rings, like the firs in the reference picture."""
    g = gy(x, z)
    for y in range(g, min(g + h, NYv)):
        G[int(x), y, int(z)] = 9
    for k, frac in enumerate(np.linspace(0.18, 0.95, 7)):
        cy = g + h * frac
        rad = (1.05 - frac) * h * 0.38 + 1.5
        blob(x, cy, z, rad, 2.2, rad, 10, 11, 0.8, seed * 10 + k)


def birch(x, z, h, seed):
    g = gy(x, z)
    r = np.random.default_rng(seed)
    for y in range(g, min(g + h, NYv)):
        G[int(x), y, int(z)] = 13 if r.random() < 0.2 else 12
    for k in range(5):
        blob(x + r.uniform(-4, 4), g + h * r.uniform(0.6, 1.0), z + r.uniform(-4, 4), r.uniform(3, 5), r.uniform(2.5, 4),
             r.uniform(3, 5), 14, 24, 0.55, seed * 10 + k)


for k in range(46):  # the forest at the back and the sides
    x, z = rng.uniform(1, NXv - 3), rng.uniform(4, 70)
    kind = rng.random()
    if kind < 0.55:
        pine(x, z, int(rng.uniform(62, 86)), k)
    elif kind < 0.8:
        spruce(x, z, int(rng.uniform(34, 52)), k)
    else:
        birch(x, z, int(rng.uniform(30, 42)), k)
for x, z, f in [(8, 120, pine), (232, 108, spruce), (222, 160, birch), (14, 170, spruce), (228, 196, pine), (4, 204, birch)]:
    f(x, z, 50 if f is pine else 32, int(x + z))

# low plants: bracken, bushes, grass blades, heather flowers, mushrooms
for k in range(90):
    x, z = rng.uniform(0, NXv), rng.uniform(60, NZv)
    if near[int(x), int(z)] < 1.1 or surf[int(x), int(z)] == 19:
        continue
    g = gy(x, z)
    if rng.random() < 0.55:
        blob(x, g + 1, z, rng.uniform(2, 4), rng.uniform(1.2, 2.2), rng.uniform(2, 3.5), 15, 25, 0.5, 500 + k)
    else:
        blob(x, g + 1.5, z, rng.uniform(3, 6), rng.uniform(2, 3.5), rng.uniform(3, 5), 26, 27, 0.75, 600 + k)
mx, mz = np.nonzero((surf == 3) | (surf == 2) | (surf == 16))
pick = rng.random(mx.size)
for sel, hgt_, m in [(pick < 0.22, 1, 4), (pick < 0.07, 2, 4)]:
    xi, zi = mx[sel], mz[sel]
    for k in range(hgt_):
        yy = ground[xi, zi] + k
        ok = (yy < NYv) & (G[xi, np.clip(yy, 0, NYv - 1), zi] == 0)
        G[xi[ok], yy[ok], zi[ok]] = 4
flw = (surf[mx, mz] == 16) & (pick > 0.8)
G[mx[flw], ground[mx[flw], mz[flw]], mz[flw]] = 17
yel = (surf[mx, mz] == 3) & (pick > 0.985)
G[mx[yel], ground[mx[yel], mz[yel]], mz[yel]] = 28
for x, z in [(70, 128), (72, 130), (176, 168)]:  # little red mushrooms by a stump
    g = gy(x, z)
    G[x, g, z] = 21
    G[x - 1:x + 2, g + 1, z - 1:z + 2] = 20
G[66:70, gy(68, 126):gy(68, 126) + 3, 124:128] = 9  # the stump

# Crash pads in front of the blocks, and a wooden sign by the path.
for x0, z0, m in [(112, 130, 18), (188, 146, 22), (34, 98, 18)]:
    g = gy(x0 + 5, z0 + 3)
    G[x0:x0 + 11, g:g + 2, z0:z0 + 7] = m
    G[x0:x0 + 11, g + 1, z0 + 3] = 23  # the fold
sx_, sz_ = 146, 172
g = gy(sx_, sz_)
G[sx_, g:g + 9, sz_] = 22
G[sx_ - 5:sx_ + 6, g + 6:g + 10, sz_] = 22
print("world", round(time.time() - T0, 1), "s")

# Twice as fine, and smoothed: round shapes made of small cubes, not big Minecraft blocks.
# Thin things (blades, flowers, trunks, the sign) stay crisp and one fine cube wide.
G1 = G
R = 2
thin = np.isin(G1, [4, 17, 28, 20, 21, 12, 13, 8, 9])
occ = zoom(((G1 > 0) & ~thin).astype(np.float32), R, order=1) > 0.5
Gm = zoom(G1, R, order=0)
G = np.where(occ, Gm, 0).astype(np.uint8)
del occ
tz = zoom(thin, R, order=0)
tz &= (np.arange(G.shape[0]) % 2 == 0)[:, None, None]
tz &= (np.arange(G.shape[2]) % 2 == 0)[None, None, :]
G[tz] = Gm[tz]
del Gm, tz
print("fine world", G.shape, round(time.time() - T0, 1), "s")

PAL = {
    1: (214, 192, 148), 2: (112, 80, 54), 3: (84, 114, 54), 4: (130, 160, 66), 5: (178, 168, 148), 6: (150, 142, 130),
    7: (122, 140, 84), 8: (178, 96, 58), 9: (98, 80, 70), 10: (46, 78, 50), 11: (78, 116, 60), 12: (232, 228, 216),
    13: (40, 36, 40), 14: (204, 176, 70), 15: (176, 116, 52), 16: (112, 96, 84), 17: (176, 110, 168), 18: (64, 96, 150),
    19: (232, 218, 184), 20: (196, 46, 40), 21: (236, 230, 214), 22: (128, 88, 56), 23: (40, 52, 76), 24: (232, 210, 110),
    25: (214, 160, 76), 26: (62, 98, 52), 27: (96, 136, 64), 28: (240, 206, 70),
}
LUT = np.zeros((256, 3))
for k, c in PAL.items():
    LUT[k] = np.array(c) / 255.0
LUT = LUT ** 2.0  # to linear light


# ---------------------------------------------------------------- the ray tracer
DIMS = np.array(G.shape)


def trace(orig, dirs, max_steps):
    """Steps every ray voxel by voxel. Returns hit, voxel, the axis of the face it entered, t."""
    n = len(dirs)
    inv = 1.0 / np.where(np.abs(dirs) < 1e-9, 1e-9, dirs)
    t0 = (0 - orig) * inv
    t1 = (DIMS - orig) * inv
    tmin = np.minimum(t0, t1).max(1)
    tmax = np.maximum(t0, t1).min(1)
    start = np.maximum(tmin, 0) + 1e-4
    alive = tmax > start
    p = orig + dirs * start[:, None]
    vox = np.clip(np.floor(p).astype(int), 0, DIMS - 1)
    step = np.sign(dirs).astype(int)
    tnext = ((vox + (step > 0)) - orig) * inv
    tdelta = np.abs(inv)
    axis = np.argmax(np.minimum(t0, t1), 1)
    t = start.copy()
    hit = np.zeros(n, bool)
    hit_vox = np.zeros((n, 3), int)
    hit_axis = np.zeros(n, int)
    hit_t = np.full(n, 1e9)
    idx = np.nonzero(alive)[0]
    vox, tnext, axis, t = vox[idx], tnext[idx], axis[idx], t[idx]
    step_i, tdelta_i = step[idx], tdelta[idx]
    for s in range(max_steps):
        if idx.size == 0:
            break
        m = G[vox[:, 0], vox[:, 1], vox[:, 2]]
        got = m > 0
        if got.any():
            gi = idx[got]
            hit[gi] = True
            hit_vox[gi] = vox[got]
            hit_axis[gi] = axis[got]
            hit_t[gi] = t[got]
        keep = ~got
        a = np.argmin(tnext, 1)
        ar = np.arange(len(a))
        t = tnext[ar, a]
        vox[ar, a] += step_i[ar, a]
        tnext[ar, a] += tdelta_i[ar, a]
        axis = a
        inside = np.all((vox >= 0) & (vox < DIMS), 1)
        keep &= inside
        idx, vox, tnext, axis, t = idx[keep], vox[keep], tnext[keep], axis[keep], t[keep]
        step_i, tdelta_i = step_i[keep], tdelta_i[keep]
    return hit, hit_vox, hit_axis, hit_t


# camera
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
orig = np.repeat(CAM[None], len(dirs), 0)
hit, hv, ha, ht = trace(orig * R, dirs, 1500)
ht = ht / R
print("primary", round(time.time() - T0, 1), "s", hit.mean())

# normals: the face the ray came in through
nrm = np.zeros((len(dirs), 3))
ar = np.arange(len(dirs))
nrm[ar, ha] = -np.sign(dirs[ar, ha])
pos = orig + dirs * ht[:, None]

# sun shadows, with a little jitter for soft edges
hi = np.nonzero(hit)[0]
jit = np.random.default_rng(1).normal(0, 0.035, (hi.size, 3))
sdir = SUN[None] + jit
sdir /= np.linalg.norm(sdir, axis=1, keepdims=True)
sorig = (pos[hi] + nrm[hi] * 0.01) * R
shit, _, _, _ = trace(sorig, sdir, 800)
shadow = np.zeros(len(dirs))
shadow[hi] = shit
print("shadow", round(time.time() - T0, 1), "s")

# ambient occlusion: how many voxels crowd the space in front of the face
ao = np.zeros(len(dirs))
v = hv[hi]
n_ = nrm[hi].astype(int)
outside = v + n_
uvs = []
for a in range(3):
    pass
# the two axes along the face
ax = ha[hi]
u_ax = (ax + 1) % 3
v_ax = (ax + 2) % 3
fu = pos[hi, u_ax] - np.floor(pos[hi, u_ax])
fv = pos[hi, v_ax] - np.floor(pos[hi, v_ax])
p2 = pos[hi] * R
fu = p2[np.arange(hi.size), u_ax] - np.floor(p2[np.arange(hi.size), u_ax])
fv = p2[np.arange(hi.size), v_ax] - np.floor(p2[np.arange(hi.size), v_ax])
occ = np.zeros(hi.size)
for du, dv, wgt in [(1, 0, None), (-1, 0, None), (0, 1, None), (0, -1, None), (1, 1, 0), (1, -1, 0), (-1, 1, 0), (-1, -1, 0)]:
    q = outside.copy()
    q[np.arange(hi.size), u_ax] += du
    q[np.arange(hi.size), v_ax] += dv
    inb = np.all((q >= 0) & (q < DIMS), 1)
    qc = np.clip(q, 0, DIMS - 1)
    full = (G[qc[:, 0], qc[:, 1], qc[:, 2]] > 0) & inb
    wu = fu if du > 0 else (1 - fu) if du < 0 else np.ones_like(fu)
    wv = fv if dv > 0 else (1 - fv) if dv < 0 else np.ones_like(fv)
    w = (wu * wv) ** 2 * (0.6 if du and dv else 1.0)
    occ += full * w
# a few voxels further out, for the big soft darkening under trees and against walls
for k in (2, 5, 8):
    q = np.clip(v + n_ * k, 0, DIMS - 1)
    for du in (-4, 4):
        for dv in (-4, 4):
            qq = q.copy()
            qq[np.arange(hi.size), u_ax] += du
            qq[np.arange(hi.size), v_ax] += dv
            qq = np.clip(qq, 0, DIMS - 1)
            occ += 0.09 * (G[qq[:, 0], qq[:, 1], qq[:, 2]] > 0)
ao[hi] = np.clip(1 - 0.32 * occ, 0.2, 1)

# Round light: the normal of the smoothed shape, not of the cube face.
B = gaussian_filter((G > 0).astype(np.float32), 1.6)
q = np.clip(v + n_, 1, DIMS - 2)
grad = np.stack([B[q[:, 0] + 1, q[:, 1], q[:, 2]] - B[q[:, 0] - 1, q[:, 1], q[:, 2]],
                 B[q[:, 0], q[:, 1] + 1, q[:, 2]] - B[q[:, 0], q[:, 1] - 1, q[:, 2]],
                 B[q[:, 0], q[:, 1], q[:, 2] + 1] - B[q[:, 0], q[:, 1], q[:, 2] - 1]], -1)
del B
smooth = -grad / (np.linalg.norm(grad, axis=1, keepdims=True) + 1e-6)
ok_ = np.linalg.norm(grad, axis=1) > 1e-3
blend = np.where(ok_[:, None], 0.25 * nrm[hi] + 0.75 * smooth, nrm[hi])
nrm[hi] = blend / np.linalg.norm(blend, axis=1, keepdims=True)
print("normals", round(time.time() - T0, 1), "s")

# ---------------------------------------------------------------- shading
mat = np.zeros(len(dirs), int)
mat[hi] = G[v[:, 0], v[:, 1], v[:, 2]]
alb = LUT[mat]
h_ = (v[:, 0] * 73856093 ^ v[:, 1] * 19349663 ^ v[:, 2] * 83492791) % 1000 / 1000.0
var = np.ones(len(dirs))
var[hi] = 0.86 + 0.28 * h_  # every voxel its own shade: that is the pixel-art texture
alb = alb * var[:, None]
# a faint dark rim on every cube face, so the blocks read as blocks
edge = np.minimum(np.minimum(fu, 1 - fu), np.minimum(fv, 1 - fv))
rim = np.ones(len(dirs))
rim[hi] = 1.0  # no dark edges: the cubes should not read as blocks
alb *= rim[:, None]
lam = np.clip(nrm @ SUN, 0, 1)
up_ = np.clip(nrm[:, 1], 0, 1)
sky = np.array(L["sky"]) ** 2.0 * 1.4
bounce = np.array(L["bounce"])
light = (np.array(L["sun_c"]) ** 1.0) * (lam * (1 - shadow))[:, None] * 1.25
amb = (sky[None] * (0.45 + 0.55 * up_[:, None]) + bounce[None] * (1 - up_[:, None])) * ao[:, None]
col = alb * (light + amb)
# leaves let a little light through
leaf = np.isin(mat, [10, 11, 14, 24, 26, 27, 4])
col[leaf] += alb[leaf] * np.array(L["sun_c"]) * 0.18 * (1 - shadow[leaf, None])

# sky and haze
skyc = np.zeros((len(dirs), 3))
tsky = np.clip(dirs[:, 1] * 2 + 0.5, 0, 1)[:, None]
skyc = (np.array(L["haze"]) ** 2.0) * (1 - tsky) + sky[None] * tsky
col[~hit] = skyc[~hit]
dist = np.where(hit, ht, 600)
fog = 1 - np.exp(-np.clip(dist - 170, 0, None) / 220.0)
col = col * (1 - fog[:, None] * 0.6) + (np.array(L["haze"]) ** 2.0)[None] * 0.7 * fog[:, None] * 0.6
img = col.reshape(H, W, 3)
depth = dist.reshape(H, W)
print("shade", round(time.time() - T0, 1), "s")

# ---------------------------------------------------------------- sprites: the people
def project(p):
    d = p - CAM
    z = d @ fwd
    xs = (d @ right) / z / np.tan(FOV / 2) * (H / 2) + W / 2
    ys = -(d @ upv) / z / np.tan(FOV / 2) * (H / 2) + H / 2
    return xs, ys, np.linalg.norm(d)


from scipy.ndimage import distance_transform_edt


def sprite_light(spr, sunlit):
    """A normal map from the silhouette and the painted shading, then sun and sky on it."""
    a = spr[..., 3] > 0
    dist = distance_transform_edt(np.pad(a, 1))[1:-1, 1:-1]
    lum_ = spr[..., :3].mean(-1)
    height = np.sqrt(dist) * 1.15 + lum_ * 0.6
    height = gaussian_filter(height, 0.6)
    gy_, gx_ = np.gradient(height)
    n = np.stack([-gx_, gy_, np.ones_like(height)], -1)  # y up on screen
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    world = n[..., :1] * right + n[..., 1:2] * upv - n[..., 2:3] * fwd
    lam_ = np.clip(world @ SUN, 0, 1) * sunlit
    up_s = np.clip(world[..., 1], 0, 1)
    alb_ = spr[..., :3] ** 2.0
    c = alb_ * (np.array(L["sun_c"]) * 1.25 * lam_[..., None] + sky * (0.5 + 0.5 * up_s[..., None]) + bounce)
    return np.concatenate([c, spr[..., 3:]], -1)


P = sl.P
YOU = (120.0, 150.0)
people = [
    (YOU, sl.YOU_ROWS, 0.0),
    ((193.0, 146.0), sl.CLIMBER_ROWS, 9.0),   # on the right block
    ((186.0, 152.0), sl.SPOTTER_ROWS, 0.0),
    ((40.0, 100.0), sl.SITTER_ROWS, 0.0),
]
for (x, z), rows, lift in sorted(people, key=lambda p_: p_[0][1]):
    spr = sl.sprite_from_rows(rows, P)
    g = gy(x, z) if lift == 0 else gy(x, z - 6) * 0 + ground[int(x), int(z)] + lift
    xs, ys, dd = project(np.array([x, g, z]))
    scale = 3
    big = np.repeat(np.repeat(spr, scale, 0), scale, 1)
    sh_, sw_ = big.shape[:2]
    ox, oy = int(xs - sw_ / 2), int(ys - sh_)
    # sun or shade where it stands
    sh_ray, _, _, _ = trace(np.array([[x, g + 6, z]]) * R, SUN[None], 600)
    lit_sprite = sprite_light(spr, 0.0 if sh_ray[0] else 1.0)
    big = np.repeat(np.repeat(lit_sprite, scale, 0), scale, 1)
    for j in range(sh_):
        yy_ = oy + j
        if not 0 <= yy_ < H:
            continue
        xx_ = np.arange(sw_) + ox
        ok = (xx_ >= 0) & (xx_ < W) & (big[j, :, 3] > 0)
        xx2 = xx_[ok]
        vis = depth[yy_, xx2] > dd - 3
        img[yy_, xx2[vis]] = big[j, ok, :3][vis]
        depth[yy_, xx2[vis]] = dd
    # a soft round shadow at the feet
    for j in range(-4, 5):
        for i in range(-12, 13):
            if (i / 12) ** 2 + (j / 4) ** 2 < 1:
                yy_, xx_ = int(ys + j), int(xs + i)
                if 0 <= yy_ < H and 0 <= xx_ < W and depth[yy_, xx_] > dd - 6:
                    img[yy_, xx_] *= 0.75

# ---------------------------------------------------------------- post
_, ys_you, d_you = project(np.array([YOU[0], gy(*YOU), YOU[1]]))
dz = np.abs(depth - d_you)
amount = np.clip((dz - 18) / 22.0, 0, 3.999)
levels = [0, 1.5, 3.2, 5.5, 8.5]
stack = np.stack([img] + [np.stack([gaussian_filter(img[..., c], s_) for c in range(3)], -1) for s_ in levels[1:]])
lo_ = amount.astype(int)
fr = (amount - lo_)[..., None]
yy_, xx_ = np.mgrid[0:H, 0:W]
out = stack[lo_, yy_, xx_] * (1 - fr) + stack[np.minimum(lo_ + 1, 4), yy_, xx_] * fr

# god rays and bloom
across = xx_ * 0.8 - yy_ * 0.6
rays = np.clip(np.sin(across / 21.0) * 0.6 + np.sin(across / 53.0 + 1.3) * 0.7, 0, 1) ** 3
rays *= np.clip(1.0 - yy_ / H, 0, 1) * np.clip(1.2 - xx_ / W, 0, 1)
out += rays[..., None] * (np.array(L["haze"]) ** 2.0) * (0.1 if TIME == "avond" else 0.04)
bright = np.clip(out - 0.95, 0, None)
out += np.stack([gaussian_filter(bright[..., c], 6) * 0.5 + gaussian_filter(bright[..., c], 24) * 0.6 for c in range(3)], -1)
# motes and bokeh
r = np.random.default_rng(3)
for k in range(40):
    mx_, my_ = r.uniform(0, W), r.uniform(0, H)
    b = amount[int(my_), int(mx_)]
    d2 = (xx_ - mx_) ** 2 + (yy_ - my_) ** 2
    c = np.array(L["haze"]) ** 2.0
    out += ((d2 < (4 + b * 4) ** 2) * 0.06)[..., None] * c if b > 1.5 else (np.exp(-d2 / 1.5) * 1.2)[..., None] * c

# tone map, grade, vignette
out = 1 - np.exp(-out * 1.5)
out = out ** (1 / 2.2)
lum = out.mean(-1, keepdims=True)
out = lum + (out - lum) * 1.25
v_ = (xx_ / W - 0.5) ** 2 * 1.3 + (yy_ / H - 0.5) ** 2 * 1.2
out *= (1 - 0.7 * v_)[..., None]
out = np.clip(out, 0, 1)
# cinematic bars
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
        for cx, cy in [(x + 2, y + 2), (x + w - 2, y + 2), (x + 2, y + h - 2), (x + w - 2, y + h - 2)]:
            d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=(240, 210, 140))

    t = "BAS CUVIER"
    tw = d.textlength(t, font=big_f)
    d.text((W / 2 - tw / 2, 44), t, font=big_f, fill=(250, 238, 214))
    d.line([W / 2 - 170, 62, W / 2 - tw / 2 - 16, 62], fill=GOLD)
    d.line([W / 2 + tw / 2 + 16, 62, W / 2 + 170, 62], fill=GOLD)
    t = "Fontainebleau  ·  " + L["part"]
    tw = d.textlength(t, font=small_f)
    d.text((W / 2 - tw / 2, 74), t, font=small_f, fill=GOLD)
    xs, ys, _ = project(np.array([YOU[0], gy(*YOU), YOU[1]]))
    px_, py_ = int(xs) + 34, int(ys) - 110
    plate(px_, py_, 172, 52)
    d.text((px_ + 14, py_ + 2), "La Marie-Rose", font=big_f, fill=(250, 238, 214))
    d.ellipse([px_ + 14, py_ + 32, px_ + 28, py_ + 46], fill=(110, 170, 90))
    d.text((px_ + 18, py_ + 31), "A", font=small_f, fill=(20, 30, 20))
    d.text((px_ + 34, py_ + 30), "Klimmen      6a", font=small_f, fill=GOLD)
im.save(OUTFILE)
print("saved", OUTFILE, round(time.time() - T0, 1), "s")
