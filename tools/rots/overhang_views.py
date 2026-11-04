"""Mockup: Le Toit seen from three camera angles, to find a view in which an overhang
reads as one. The climbing wall is laid on a plane that leans out over you, with its
relief; a solid block behind it; a simple climber in two poses (tension, feet off).

    python3 tools/rots/overhang_views.py <out.png>
"""
import math
import sys
import numpy as np
from PIL import Image, ImageDraw
import rock_forms as rf

W, H = 480, 270
LEAN = math.radians(24)
DEPTH = 110
rf.configure("toit")
hm = rf.height_map()
relief = (hm - hm.min()) * 0.3
tex = np.array(Image.open("assets/climb/toit/rock_avond.png").convert("RGB")).astype(float)
mask = rf.INSIDE
N = np.array([0.0, -math.sin(LEAN), math.cos(LEAN)])  # the wall faces you and down


def wall(x, y, out=0.0):
    """A point on the wall for picture pixel (x, y), `out` px off it towards you."""
    u, v = x - rf.CX, rf.FLOOR - y
    r = relief[int(np.clip(y, 0, rf.H - 1)), int(np.clip(x, 0, rf.W - 1))]
    return np.array([u, v * math.cos(LEAN), v * math.sin(LEAN) + r]) + N * out


def points():
    """Every visible bit of the block: the face (with its picture), the sides, the top."""
    P, C = [], []
    ys, xs = np.nonzero(mask)
    for sub in ((0, 0), (0.5, 0), (0, 0.5), (0.5, 0.5)):
        x, y = xs + sub[0], ys + sub[1]
        u, v = x - rf.CX, rf.FLOOR - y
        r = relief[ys, xs]
        P.append(np.stack([u, v * math.cos(LEAN), v * math.sin(LEAN) + r], 1))
        C.append(tex[ys, xs])
    # The sides and the top: the block goes back DEPTH behind its face.
    rng = np.random.default_rng(3)
    for y in range(rf.H):
        row = np.nonzero(mask[y])[0]
        if len(row) == 0:
            continue
        for x, side in ((row[0], -1), (row[-1], 1)):
            p = wall(x, y)
            for t in np.arange(0, DEPTH, 0.5):
                P.append((p - np.array([0, 0, t]))[None])
                lit = 1.0 if side < 0 else 0.55       # the evening sun comes from the left
                C.append((np.array([190, 150, 140]) * lit * (0.9 + 0.2 * rng.random()))[None])
    tops = np.where(mask.any(0), mask.argmax(0), -1)
    for x in range(rf.W):
        if tops[x] < 0:
            continue
        p = wall(x, tops[x])
        for t in np.arange(0, DEPTH, 0.5):
            P.append((p - np.array([0, 0, t]) + np.array([0, 2 * math.sin(t / DEPTH * math.pi), 0]))[None])
            moss = rng.random() < 0.25
            C.append((np.array([150, 160, 90]) if moss else np.array([240, 205, 150]) * (0.9 + 0.15 * rng.random()))[None])
    return np.concatenate(P), np.concatenate(C)


PTS, COLS = points()


class Cam:
    def __init__(self, pos, target, f):
        self.pos = np.array(pos, float)
        fwd = np.array(target, float) - self.pos
        fwd /= np.linalg.norm(fwd)
        right = np.cross(fwd, [0, 1, 0])
        right /= np.linalg.norm(right)
        up = np.cross(right, fwd)
        self.R = np.stack([right, up, fwd])
        self.f = f

    def project(self, P):
        d = (np.atleast_2d(P) - self.pos) @ self.R.T
        return np.stack([W / 2 + self.f * d[:, 0] / d[:, 2], H / 2 - self.f * d[:, 1] / d[:, 2], d[:, 2]], 1)


def backdrop(cam):
    """Forest far away above the horizon, sand in front, both from the camera's rays."""
    img = np.zeros((H, W, 3))
    zbuf = np.full((H, W), np.inf)
    jj, ii = np.mgrid[0:H, 0:W]
    dirs = np.stack([(ii - W / 2) / cam.f, -(jj - H / 2) / cam.f, np.ones_like(ii, float)], -1) @ cam.R
    t = -cam.pos[1] / np.where(dirs[..., 1] < -1e-6, dirs[..., 1], -1e-6)
    ground = dirs[..., 1] < -1e-6
    gp = cam.pos + dirs * t[..., None]
    sand = np.array([226, 196, 150]) - 18 * (((np.floor(gp[..., 0] / 6) + np.floor(gp[..., 2] / 6)) % 2) == 0)[..., None]
    far = np.clip(t / 900, 0, 1)[..., None]
    sky_t = np.clip(0.5 + dirs[..., 1] * 1.5, 0, 1)[..., None]
    forest = (1 - sky_t) * np.array([120, 140, 110]) + sky_t * np.array([224, 206, 170])
    img[:] = forest
    img[ground] = (sand * (1 - far) + np.array([200, 190, 160]) * far)[ground]
    zbuf[ground] = (t * np.linalg.norm(dirs, axis=-1))[ground]
    # The shade under the roof on the sand.
    under = ground & (np.abs(gp[..., 0]) < rf.HW) & (gp[..., 2] < 70) & (gp[..., 2] > -10)
    img[under] *= 0.7
    return img, zbuf


def render(cam):
    img, zbuf = backdrop(cam)
    s = cam.project(PTS)
    ok = (s[:, 2] > 1)
    s, c = s[ok], COLS[ok]
    order = np.argsort(-s[:, 2])
    for k in (0, 1):
        for dk in (0, 1):
            x = np.clip(s[order, 0].astype(int) + k, 0, W - 1)
            y = np.clip(s[order, 1].astype(int) + dk, 0, H - 1)
            z = s[order, 2]
            near = z < zbuf[y, x]
            # painter's order: later (closer) points overwrite
            img[y[near], x[near]] = c[order][near]
            zbuf[y[near], x[near]] = z[near]
    return img


SKIN, SHIRT, PANTS, SHOE, HAT, INK = (224, 168, 128), (184, 82, 62), (98, 100, 70), (110, 70, 120), (232, 178, 70), (43, 35, 41)


def climber(pose):
    lh, rh = wall(212, 146, 1), wall(246, 176, 1)
    if pose == "tension":
        lf, rf_ = wall(214, 206, 1), wall(240, 204, 1)
        sh = wall(230, 180, 16)
        hip = wall(230, 206, 13)
    else:  # feet off: you hang straight down from your hands, away from the leaning wall
        lf = rf_ = None
        sh = (lh + rh) / 2 + np.array([0, -30, 4])
        hip = sh + np.array([0, -28, 2])
        lf = hip + np.array([-6, -34, 6])
        rf_ = hip + np.array([6, -33, 3])
    side = np.array([1.0, 0, 0])
    shl, shr = sh - side * 8, sh + side * 8
    hl, hr = hip - side * 5, hip + side * 5
    out = N if pose == "tension" else np.array([0, 0, 1.0])
    el = (shl + lh) / 2 + out * 6 - side * 5
    er = (shr + rh) / 2 + out * 6 + side * 5
    kl = (hl + lf) / 2 + out * 12 - side * 7
    kr = (hr + rf_) / 2 + out * 12 + side * 7
    head = sh + (sh - hip) / np.linalg.norm(sh - hip) * 9 + out * 2
    return dict(lh=lh, rh=rh, lf=lf, rf=rf_, shl=shl, shr=shr, hl=hl, hr=hr, el=el, er=er, kl=kl, kr=kr, sh=sh, hip=hip, head=head)


def draw_climber(img, cam, pose):
    J = climber(pose)
    im = Image.fromarray(img.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    p = {k: cam.project(v)[0] for k, v in J.items()}
    sc = lambda k: cam.f / p[k][2]
    def seg(a, b, w, col):
        ww = max(2, int(round(w * (sc(a) + sc(b)) / 2)))
        d.line([tuple(p[a][:2]), tuple(p[b][:2])], fill=INK, width=ww + 2)
    def seg2(a, b, w, col):
        ww = max(1, int(round(w * (sc(a) + sc(b)) / 2)))
        d.line([tuple(p[a][:2]), tuple(p[b][:2])], fill=col, width=ww)
    limbs = [("hl", "kl", 4, PANTS), ("kl", "lf", 3.5, PANTS), ("hr", "kr", 4, PANTS), ("kr", "rf", 3.5, PANTS),
             ("sh", "hip", 9, SHIRT), ("shl", "el", 3, SKIN), ("el", "lh", 2.5, SKIN), ("shr", "er", 3, SKIN), ("er", "rh", 2.5, SKIN)]
    for a, b, w, col in limbs:
        seg(a, b, w, col)
    for a, b, w, col in limbs:
        seg2(a, b, w, col)
    for f in ("lf", "rf"):
        r = 2.2 * sc(f)
        d.ellipse([p[f][0] - r, p[f][1] - r, p[f][0] + r, p[f][1] + r], fill=SHOE, outline=INK)
    r = 4.5 * sc("head")
    d.ellipse([p["head"][0] - r, p["head"][1] - r, p["head"][0] + r, p["head"][1] + r], fill=HAT, outline=INK)
    return np.array(im).astype(float)


VIEWS = {
    "A  Van opzij": Cam((560, 110, 30), (0, 100, 30), 560),
    "B  Schuin van opzij": Cam((250, 95, 300), (-10, 105, 30), 300),
    "C  Van onderen omhoog": Cam((0, 22, 250), (0, 140, 40), 250),
}


if __name__ == "__main__":
    tiles = []
    for name, cam in VIEWS.items():
        base = render(cam)
        row = [draw_climber(base.copy(), cam, pose) for pose in ("tension", "off")]
        tiles.append((name, row))
    out = Image.new("RGB", (W * 2 * 2 + 12, (H * 2 + 60) * 3), (26, 20, 24))
    from PIL import ImageFont
    F = "assets/fonts/kenney_kenney-fonts/Fonts/"
    big = ImageFont.truetype(F + "Kenney Mini.ttf", 32)
    small = ImageFont.truetype(F + "Kenney Pixel.ttf", 30)
    d = ImageDraw.Draw(out)
    for r, (name, row) in enumerate(tiles):
        y0 = r * (H * 2 + 60)
        d.text((12, y0 + 12), name, font=big, fill=(242, 207, 58))
        for k, im in enumerate(row):
            pic = Image.fromarray(im.clip(0, 255).astype(np.uint8)).resize((W * 2, H * 2), Image.NEAREST)
            out.paste(pic, (k * (W * 2 + 12), y0 + 56))
            d.text((k * (W * 2 + 12) + W * 2 - 230, y0 + 18), "met spanning" if k == 0 else "voeten los", font=small, fill=(255, 246, 228))
    out.save(sys.argv[1])
    print(out.size)
