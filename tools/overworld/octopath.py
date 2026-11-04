"""Mockup of the walking world in the style of Octopath Traveler: a low camera looking into
a stage, a wall of pine trunks behind the clearing, dappled light through the canopy,
haze in the depth, strong blur in front and behind, bloom, god rays, pixel sprites.

    python3 octopath.py [avond|middag] out.png [noui]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, zoom
import sprites_lib as sl

TIME = sys.argv[1] if len(sys.argv) > 1 else "avond"
OUTFILE = sys.argv[2] if len(sys.argv) > 2 else "octopath.png"
NOUI = len(sys.argv) > 3 and sys.argv[3] == "noui"
FONT_DIR = "/Users/prive/boulder/assets/fonts/kenney_kenney-fonts/Fonts/"

W, H = 960, 540
S = 3
FY = 0.42   # a low camera: the ground is strongly foreshortened
FZ = 0.95   # and walls and faces stand up tall
NX, NZ = W // S, 440
Y_OFF = -6

LOOKS = {
    "avond": dict(sun=(-0.82, 0.36, 0.3), light=(1.2, 0.78, 0.44), amb=(0.16, 0.14, 0.3),
                  haze=(0.95, 0.6, 0.42), deep=(0.36, 0.26, 0.42), shaft=(1.0, 0.7, 0.38),
                  clock="19:42", part="Avond"),
    "middag": dict(sun=(-0.35, 0.8, 0.4), light=(1.05, 1.02, 0.92), amb=(0.24, 0.27, 0.38),
                   haze=(0.78, 0.86, 0.9), deep=(0.4, 0.46, 0.52), shaft=(1.0, 0.96, 0.82),
                   clock="13:10", part="Middag"),
}
L = LOOKS[TIME]
SUN = np.array(L["sun"]); SUN = SUN / np.linalg.norm(SUN)
AMB, LIGHT = np.array(L["amb"]), np.array(L["light"])


def vnoise(shape, cell, seed):
    g = np.random.default_rng(seed).random((shape[0] // cell + 3, shape[1] // cell + 3))
    return zoom(g, cell, order=3)[: shape[0], : shape[1]]


zz, xx = np.mgrid[0:NZ, 0:NX]

# ---------------------------------------------------------------- ground
# The forest floor rises gently towards the back, into a bank under the trees.
hgt = 26 * np.clip(1 - zz / 170, 0, 1) ** 1.6 + 3 * vnoise((NZ, NX), 40, 1) + 0.8 * vnoise((NZ, NX), 6, 2)
BOULDERS = [  # x, z, rx, rz, height, seed
    (168, 262, 40, 24, 46, 1),
    (52, 214, 30, 18, 36, 2),
    (282, 300, 28, 17, 30, 3),
    (112, 338, 10, 6, 9, 4),
    (236, 196, 16, 10, 14, 5),
]
mat = np.full((NZ, NX), 1)  # 0 sand 1 needles 2 moss 3 path 4 rock 5 heather 6 bracken
n1, n2 = vnoise((NZ, NX), 22, 41), vnoise((NZ, NX), 14, 42)
mat[n2 > 0.58] = 2
mat[(n1 > 0.7) & (zz > 150)] = 6
mat[(zz < 150) & (n2 > 0.5)] = 5
near = np.full((NZ, NX), 9.0)
for bx, bz, rx, rz, *_ in BOULDERS[:3]:
    near = np.minimum(near, np.hypot((xx - bx) / (rx + 26), (zz - bz) / (rz + 22)))
mat[near < 1 + 0.25 * (n1 - 0.5)] = 0
# a sandy path winding in from the front
path_x = 165 + 22 * np.sin(zz / 55.0) - 0.08 * (zz - 300)
mat[(np.abs(xx - path_x) < 9 + 3 * n2) & (zz > 285)] = 3

rock = np.zeros((NZ, NX), bool)
bump = vnoise((NZ, NX), 7, 9) - 0.5
for bx, bz, rx, rz, bh, seed in BOULDERS:
    wob = 1 + 0.12 * (vnoise((NZ, NX), 11, seed) - 0.5)
    ang = np.arctan2(zz - bz, xx - bx)
    lobes = 1 + 0.1 * np.sin(3 * ang + seed) + 0.06 * np.sin(5 * ang + 2 * seed)
    r = np.sqrt(((xx - bx) / (rx * wob * lobes)) ** 2 + ((zz - bz) / (rz * wob * lobes)) ** 2)
    inside = r < 1
    tilt = 1 + 0.18 * (xx - bx) / rx  # rises to the right: its top faces the low sun
    shape = bh * tilt * np.clip(1 - r ** 5, 0, 1) ** 0.3 + inside * (bh * 0.09 * bump * np.clip(r * 2, 0, 1))
    top = np.where(inside, hgt + shape, hgt)
    rock |= inside & (top > hgt + 1)
    hgt = np.maximum(hgt, top)
mat[rock] = 4


def ground(x, z):
    return hgt[int(np.clip(z, 0, NZ - 1)), int(np.clip(x, 0, NX - 1))]


# ---------------------------------------------------------------- trees and canopy
rng = np.random.default_rng(5)
TREES = []
for k in range(34):  # the wall of trunks at the back
    TREES.append((rng.uniform(0, NX), rng.uniform(10, 140), "pine" if rng.random() < 0.8 else "birch"))
TREES += [(8, 230, "pine"), (316, 250, "pine"), (300, 180, "birch"), (30, 300, "birch")]
FRONT = [(14, 436, "pine"), (300, 438, "birch")]  # big blurred trunks right in front of you
occ_lo = np.full((NZ, NX), 1e9)
occ_hi = np.full((NZ, NX), -1e9)
holes = vnoise((NZ, NX), 6, 33)
for x, z, kind in TREES + FRONT:
    g = ground(x, z)
    d = np.hypot(xx - x, zz - z)
    t = d < 2
    occ_lo[t] = np.minimum(occ_lo[t], g)
    occ_hi[t] = np.maximum(occ_hi[t], g + 170)
# The canopy over the clearing has holes: that is where the sun comes through.
canopy = (holes > 0.45) & ((zz < 150) | (xx > 300))
occ_lo[canopy] = np.minimum(occ_lo[canopy], 90)
occ_hi[canopy] = np.maximum(occ_hi[canopy], 170)

YOU = (160, 318)
for x, z in [YOU, (276, 322), (262, 334), (98, 250)]:
    d = np.hypot(xx - x, zz - z)
    p = d < 2.5
    occ_lo[p] = np.minimum(occ_lo[p], ground(x, z))
    occ_hi[p] = np.maximum(occ_hi[p], ground(x, z) + 20)

# ---------------------------------------------------------------- light
gz, gx = np.gradient(hgt)
normal = np.stack([-gx, np.ones_like(hgt), -gz], -1)
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
lam = np.clip(normal @ SUN, 0, 1)
shadow = np.zeros((NZ, NX))
horiz = np.hypot(SUN[0], SUN[2])
step = np.array([SUN[0], SUN[2]]) / horiz
rise = SUN[1] / horiz
for t in range(2, 320, 2):
    rx_ = (xx + step[0] * t).round().astype(int)
    rz_ = (zz + step[1] * t).round().astype(int)
    inside = (rx_ >= 0) & (rx_ < NX) & (rz_ >= 0) & (rz_ < NZ)  # a ray that leaves the world is free
    sx, sz = np.clip(rx_, 0, NX - 1), np.clip(rz_, 0, NZ - 1)
    ray = hgt + 1.0 + rise * t
    blocked = inside & ((hgt[sz, sx] > ray) | ((occ_lo[sz, sx] < ray) & (occ_hi[sz, sx] > ray)))
    shadow = np.maximum(shadow, blocked)
shadow = np.clip(gaussian_filter(shadow, 0.7), 0, 1)

cell = vnoise((NZ, NX), 1, 5)
spot = vnoise((NZ, NX), 3, 6)
TOPS = {
    0: [(212, 186, 140), (194, 168, 124), (228, 206, 164)],
    1: [(122, 82, 52), (98, 66, 44), (150, 104, 62)],
    2: [(86, 104, 54), (68, 86, 46), (112, 128, 64)],
    3: [(236, 220, 184), (220, 202, 164), (246, 234, 204)],
    4: [(168, 158, 140), (144, 136, 124), (188, 178, 156)],
    5: [(112, 80, 100), (88, 66, 82), (144, 100, 128)],
    6: [(150, 96, 48), (120, 76, 42), (186, 130, 64)],
}
ALB = np.zeros((NZ, NX, 3))
pick = np.where(cell < 0.33, 0, np.where(cell < 0.8, 1, 2))
pick = np.where(spot > 0.72, 2, np.where(spot < 0.25, 1, pick))
for m, cols in TOPS.items():
    sel = mat == m
    ALB[sel] = np.array(cols, float)[pick][sel]
lich = (vnoise((NZ, NX), 4, 12) > 0.66) & rock
ALB[lich] = (112, 128, 80)
ALB /= 255.0


def lit_level(l):
    return np.where(l > 0.6, 1.0, np.where(l > 0.34, 0.7, np.where(l > 0.12, 0.42, 0.16)))


TOPC = ALB * (AMB + LIGHT * (lit_level(lam) * (1 - shadow))[..., None])

# ---------------------------------------------------------------- render the ground
img = np.zeros((H, W, 3))
img[:] = np.array(L["deep"])
depth = np.full((H, W), -1.0)
colx = np.arange(W) // S
ROCKSIDE = np.array((158, 148, 132)) / 255.0
ROCKTEX = vnoise((200, NX), 3, 77) * 0.6 + vnoise((200, NX), 9, 78) * 0.4
STREAK = vnoise((200, NX), 1, 79)
CRACK = vnoise((200, NX), 5, 80)
for z in range(NZ):
    h = hgt[z, colx]
    hn = hgt[min(z + 1, NZ - 1), colx]
    y0 = z * S * FY - h * S * FZ + Y_OFF
    yf = (z + 1) * S * FY - h * S * FZ + Y_OFF
    y1 = (z + 1) * S * FY - np.minimum(hn, h) * S * FZ + Y_OFF
    if z == NZ - 1:
        y1 = np.full_like(y1, H)
    a = np.clip(np.floor(y0).astype(int), 0, H)
    f = np.clip(np.floor(yf).astype(int), 0, H)
    b = np.clip(np.ceil(y1).astype(int), 0, H)
    is_rock = rock[z, colx]
    nrm = normal[z, colx]
    fn = np.stack([nrm[:, 0], np.full(W, 0.2), np.maximum(nrm[:, 2], 0.55)], -1)
    fn /= np.linalg.norm(fn, axis=-1, keepdims=True)
    fl = np.clip(fn @ SUN, 0, 1)
    fsh = shadow[z, colx]
    top = TOPC[z, colx]
    dirt = ALB[z, colx] * 0.8
    span = int((b - a).max()) + 1
    for k in range(span):
        y = a + k
        ok = y < b
        if not ok.any():
            continue
        cols = np.nonzero(ok)[0]
        yy = y[cols]
        c = top[cols].copy()
        face = yy >= f[cols]
        if face.any():
            fc = cols[face]
            hp = h[fc] - (yy[face] - yf[fc]) / (S * FZ)
            hi_ = np.clip(hp.astype(int), 0, 199)
            alb = np.where(is_rock[fc, None], ROCKSIDE[None] * (0.8 + 0.4 * ROCKTEX[hi_, fc // S][:, None]), dirt[fc])
            streak = (STREAK[np.clip(hi_ // 5, 0, 199), fc // S] > 0.78) & is_rock[fc]
            alb[streak] *= 0.72
            band = (((hp + 7 * ROCKTEX[np.clip(hi_ // 3, 0, 199), fc // S]) % 12.0) < 0.9) & is_rock[fc]
            alb[band] *= 0.78
            crack = (np.abs(CRACK[hi_, fc // S] - 0.5) < 0.012) & is_rock[fc]
            alb[crack] *= 0.5
            lvl = lit_level(fl[fc]) * 0.9 * (1 - fsh[fc])
            cc = alb * (AMB + LIGHT * lvl[:, None])
            # a crisp lit lip where the sunny top of a block turns over into its face
            lip = ((yy[face] - f[fc]) < 2) & is_rock[fc] & (fsh[fc] < 0.5)
            cc[lip] = cc[lip] * 1.25 + 0.05
            c[face] = cc
        img[yy, cols] = c
        depth[yy, cols] = z

# ---------------------------------------------------------------- sprites
P = sl.P
sprites = []
for x, z, kind in TREES:
    sprites.append((z, x, ground(x, z), sl.pine() if kind == "pine" else sl.birch(), 3, False))
for x, z, kind in FRONT:
    sprites.append((z, x, ground(x, z), sl.pine() if kind == "pine" else sl.birch(), 5, False))
sprites.append((YOU[1], YOU[0], ground(*YOU), sl.sprite_from_rows(sl.YOU_ROWS, P), 3, False))
sprites.append((322, 276, ground(276, 326) + 12, sl.sprite_from_rows(sl.CLIMBER_ROWS, P), 3, False))
sprites.append((334, 262, ground(262, 334), sl.sprite_from_rows(sl.SPOTTER_ROWS, P), 3, False))
sprites.append((330, 278, ground(278, 330), sl.sprite_from_rows(sl.PAD_ROWS, sl.PAD_P), 3, True))
sprites.append((290, 166, ground(166, 290), sl.sprite_from_rows(sl.PAD_ROWS, sl.PAD2_P), 3, True))
sprites.append((250, 98, ground(98, 250), sl.sprite_from_rows(sl.SITTER_ROWS, P), 3, False))
sprites.append((248, 94, ground(94, 248), sl.sprite_from_rows(sl.PAD_ROWS[:5], sl.PAD_P), 3, True))
r = np.random.default_rng(21)
for k in range(1900):
    x, z = r.uniform(0, NX), r.uniform(60, NZ)
    zi, xi = int(z), int(x)
    m = mat[zi, xi]
    if rock[zi, xi] or m == 3 or (m == 0 and r.random() < 0.85):
        continue
    kind = "heather" if m == 5 else ("bracken" if m == 6 or (m == 1 and r.random() < 0.12) else "grass")
    tex = 3 if z < 400 else 5  # big plants right in front of the camera
    sprites.append((z, x, ground(x, z), sl.tuft(kind, k), tex, False))
sprites.sort(key=lambda s_: s_[0])
for z, x, g, spr, tex, flat in sprites:
    big = np.repeat(np.repeat(spr, tex, 0), tex, 1)
    sh_, sw_ = big.shape[:2]
    sx = int(x * S - sw_ / 2)
    sy = int(z * S * FY - g * S * FZ + Y_OFF - sh_)
    if flat:
        sy += int(sh_ * 0.6)
    insh = shadow[int(np.clip(z, 0, NZ - 1)), int(np.clip(x, 0, NX - 1))]
    tint = (0.45 + 0.55 * AMB / AMB.max()) if insh > 0.5 else (0.7 + 0.4 * LIGHT / LIGHT.max())
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
        c = big[j, ok, :3][vis]
        img[y, xs2[vis]] = c * tint
        depth[y, xs2[vis]] = z

# ---------------------------------------------------------------- post
yy_, xx_ = np.mgrid[0:H, 0:W]
# haze: the far side of the clearing fades into warm light, the deep forest into purple
far = np.clip((230 - depth) / 230, 0, 1) ** 1.3
far[depth < 0] = 1
up = np.clip(1 - yy_ / (H * 0.55), 0, 1)
haze = np.array(L["haze"]) * up[..., None] + np.array(L["deep"]) * (1 - up[..., None])
img = img * (1 - 0.5 * far[..., None]) + haze * 0.5 * far[..., None]

# depth of field: sharp where you stand, soft in front and far behind
fz = YOU[1]
dz = np.where(depth < 0, 200, np.abs(depth - fz))
amount = np.clip((dz - 34) / 40.0, 0, 4.0 - 0.001)
amount = np.maximum(amount, np.clip((depth - 395) / 12.0, 0, 3.999))
levels = [0, 1.4, 2.8, 4.6, 7.0]
stack = np.stack([img] + [np.stack([gaussian_filter(img[..., c], s_) for c in range(3)], -1) for s_ in levels[1:]])
lo_ = amount.astype(int)
fr = (amount - lo_)[..., None]
out = np.take_along_axis(stack, lo_[None, ..., None].repeat(3, -1), 0)[0] * (1 - fr) + \
      np.take_along_axis(stack, np.minimum(lo_ + 1, 4)[None, ..., None].repeat(3, -1), 0)[0] * fr

# god rays: through the canopy from the upper left
across = xx_ * 0.82 - yy_ * 0.57
rays = np.clip(np.sin(across / 19.0) * 0.6 + np.sin(across / 47.0 + 1.3) * 0.7 + 0.25 * np.sin(across / 7.0), 0, 1) ** 3
rays *= np.clip(1.1 - yy_ / H, 0, 1) * np.clip(1.25 - xx_ / W, 0, 1)
out += rays[..., None] * np.array(L["shaft"]) * (0.22 if TIME == "avond" else 0.1)

# bloom
bright = np.clip(out - 0.78, 0, None)
out += np.stack([gaussian_filter(bright[..., c], 8) * 0.8 + gaussian_filter(bright[..., c], 30) * 0.9 for c in range(3)], -1)

# bokeh and floating motes, and a few falling leaves in focus
r = np.random.default_rng(3)
add = np.zeros((H, W, 3))
for k in range(70):
    mx, my = r.uniform(0, W), r.uniform(0, H)
    blur = amount[int(my), int(mx)]
    d2 = (xx_ - mx) ** 2 + (yy_ - my) ** 2
    if blur > 1.5:
        rad = 3 + blur * 3
        add += (d2 < rad * rad)[..., None] * np.array(L["shaft"]) * 0.09
    else:
        add += np.exp(-d2 / 1.5)[..., None] * np.array(L["shaft"]) * 0.8
out += add
for k in range(14):
    lx, ly = int(r.uniform(80, W - 80)), int(r.uniform(140, 420))
    col = np.array((0.95, 0.6, 0.25)) if r.random() < 0.6 else np.array((0.9, 0.82, 0.3))
    out[ly:ly + 3, lx:lx + 4] = col
    out[ly + 1, lx - 1] = col * 0.7

# grade: deep shadows, warm highlights, strong vignette
lum = out.mean(-1, keepdims=True)
out = lum + (out - lum) * 1.25
out = out + (1 - np.clip(lum, 0, 1)) * np.array([0.03, 0.0, 0.06])
v = ((xx_ / W - 0.5) ** 2 * 1.4 + (yy_ / H - 0.5) ** 2 * 1.2)
out *= (1 - 0.95 * v)[..., None]
out = 1 - np.exp(-np.clip(out, 0, None) * 1.6)
im = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))

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

    # Octopath shows the place name once, centred, when you arrive; the rest stays quiet.
    t = "BAS CUVIER"
    tw = d.textlength(t, font=big_f)
    d.line([W / 2 - 170, 40, W / 2 - tw / 2 - 16, 40], fill=GOLD)
    d.line([W / 2 + tw / 2 + 16, 40, W / 2 + 170, 40], fill=GOLD)
    d.text((W / 2 - tw / 2, 22), t, font=big_f, fill=(250, 238, 214))
    t = "Fontainebleau  ·  " + L["part"]
    tw = d.textlength(t, font=small_f)
    d.text((W / 2 - tw / 2, 52), t, font=small_f, fill=GOLD)
    px_ = int(YOU[0] * S) + 30
    py_ = int(YOU[1] * S * FY - ground(*YOU) * S * FZ + Y_OFF) - 100
    plate(px_, py_, 172, 52)
    d.text((px_ + 14, py_ + 2), "La Marie-Rose", font=big_f, fill=(250, 238, 214))
    d.ellipse([px_ + 14, py_ + 32, px_ + 28, py_ + 46], fill=(110, 170, 90))
    d.text((px_ + 18, py_ + 31), "A", font=small_f, fill=(20, 30, 20))
    d.text((px_ + 34, py_ + 30), "Klimmen      6a", font=small_f, fill=GOLD)
im.save(OUTFILE)
print("saved", OUTFILE)
