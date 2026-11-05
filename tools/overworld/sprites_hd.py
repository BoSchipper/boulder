"""Pixel sprites for the HD-2D world, in the manner of Octopath Traveler: people about 34
pixels tall with a big head, a dark coloured outline and three tones per colour (light
from the upper left, shade shifted towards purple); and props drawn the same way: a
signpost, a patched tent, a stone fire ring with animated flames, a blanket.

    python3 tools/overworld/sprites_hd.py <out dir>

Writes <name>.png and <name>_n.png (a normal map from silhouette and shading) for each.
Views listed in AI come from an image AI instead (art/ai, cleaned by ai_sprite.py, with
a few pixels touched up); the drawn version stays for every view that has none.
"""
import functools
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, distance_transform_edt, binary_dilation
import ai_sprite

FONT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "kenney_kenney-fonts", "Fonts")
CW, CH = 24, 36  # a character frame
AI_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "art", "ai")
# Views drawn by an image AI, cleaned up by ai_sprite.py; they replace the drawn view.
# image: who stands in it, left to right, as (person, view); None leaves a figure unused.
AI = {
    "player_views.webp": [("player", "front"), ("player", "side"), ("player", "back")],
    "npcs_1.webp": [("sanne", "front"), ("pepe", "front"), ("tim", "front"), ("mat", "front")],
}
AI_HIP = 0.72  # where the legs start, as part of the height
# Touch-ups redraw a few pixels after the cleaning, at game size: (left, top, rows), each
# letter a colour from TOUCH, a dot leaves the pixel as it is. Drawn some 60 pixels high,
# the AI's big eyes shrink to a fleck of white and a dark dot or two: clear eyes instead,
# two pixels high. A blink closes their top pixel.
TOUCH_UPS = {
    ("player", "front"): [(5, 9, ["e.....",
                                  "hchhch",
                                  "hchhch"])],
    ("player", "side"): [(8, 9, ["ch",
                                 "ch"])],
    ("sanne", "front"): [(3, 8, ["hcssch",
                                 "scssch",
                                 ".s...."])],
    ("pepe", "front"): [(5, 7, ["scssc",
                                "scssc"]),
                        # the walking stick, one pixel wide, came out as outline only
                        (1, 20, ["#w.", "#w.", "#w.", "#w#", "#w#", "#w#", "#w#", "#w.", "#w.",
                                 "#w.", "#w.", "#w.", "#w.", "#w.", "#w.", ".#."])],
    ("tim", "front"): [(3, 8, ["rzcsscs",   # no dark hair against the left eye, no grey on the right cheek
                               ".zcsscs",
                               "..s..s."])],
    ("mat", "front"): [(3, 5, [".....m..",    # hair where orange and beige flecks sat in the fringe
                               "...mnnm.",
                               "..nssssn",
                               "n.scsscs",    # a wider face with the eyes apart, and no nose:
                               "..scsscs",    # one pixel of it read as a smear
                               "..ssssss"]),
                       (6, 15, [".qq",          # the mountain on the shirt, a smudge once shrunk
                                ".bq",
                                "gqg"])],
}
TOUCH = {"h": (252, 204, 139), "s": (251, 198, 130), "z": (242, 172, 105),  # skin
         "c": (56, 25, 29), "e": (85, 37, 35), "r": (164, 95, 43),          # eye, dark and ginger hair
         "m": (123, 68, 46), "n": (96, 45, 35),                             # brown hair
         "q": (133, 49, 39), "b": (228, 204, 177), "g": (203, 159, 113),    # red shirt, its print
         "w": (164, 95, 43)}                                                 # wood


def shades(c):
    """Light, base, shade and deep for one colour; shadows lean to purple, light to warm."""
    c = np.array(c, float)
    light = np.clip(c * 1.18 + np.array([14, 10, 0]), 0, 255)
    shade = np.clip(c * 0.68 + np.array([10, 0, 22]), 0, 255)
    deep = np.clip(c * 0.42 + np.array([12, 0, 26]), 0, 255)
    return light, c, shade, deep


class Canvas:
    def __init__(self, w, h):
        self.c = np.zeros((h, w, 4))
        self.w, self.h = w, h

    def px(self, x, y, col):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c[y, x, :3] = col
            self.c[y, x, 3] = 255

    def rect(self, x0, y0, x1, y1, base, light_side=True, shade_bottom=1):
        """A shaded block, inclusive coordinates: lit on the left, shaded on the right."""
        lt, b, sh, dp = shades(base)
        w = x1 - x0 + 1
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                f = (x - x0) / max(w - 1, 1)
                col = b
                if light_side and f < 0.3:
                    col = lt
                elif f > 0.72:
                    col = sh
                if y > y1 - shade_bottom:
                    col = sh if col is not sh else dp
                self.px(x, y, col)

    def round_corners(self):
        """Clip convex corners, so heads and bodies read round, not boxy."""
        a = self.c[..., 3] > 0
        p = np.pad(a, 1)
        n = sum(np.roll(np.roll(p, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)[1:-1, 1:-1]
        cut = a & (n <= 3)
        self.c[cut] = 0

    def outline(self, col=(38, 26, 40)):
        self.round_corners()
        a = self.c[..., 3] > 0
        ring = binary_dilation(a) & ~a
        self.c[ring, :3] = col
        self.c[ring, 3] = 255

    def rgba(self):
        return self.c / 255.0


# ---------------------------------------------------------------- characters
SKINS = {"light": (240, 196, 160), "tan": (214, 160, 118), "dark": (150, 98, 68)}


def character(spec, view, frame):
    """view: front, back, side (facing right); frame 0 stand, 1 and 2 the steps, 3 breathing
    in (the body a pixel lower), 4 standing with the eyes closed (a blink)."""
    cv = Canvas(CW, CH)
    skin = SKINS[spec["skin"]]
    hair, top, legs_c, shoes = spec["hair"], spec["top"], spec["legs"], spec["shoes"]
    bob = 1 if frame in (1, 2, 3) else 0  # the body dips a little on a step, and when breathing
    # legs and shoes
    if view == "side":
        lift = {1: (3, -2), 2: (-3, -2)}.get(frame, (0, 0))
        for k, (dx, up) in enumerate([lift, (-lift[0], 0)]):
            x0 = 10 + dx
            cv.rect(x0, 24 + bob, x0 + 3, 32 + up, legs_c if k == 0 else shades(legs_c)[2])
            cv.rect(x0, 33 + up, x0 + 4, 34 + up, shoes)
    else:
        for k, x0 in enumerate([8, 12]):
            up = 2 if (frame == 1 and k == 0) or (frame == 2 and k == 1) else 0
            cv.rect(x0, 24 + bob, x0 + 3, 32 - up, legs_c)
            cv.rect(x0, 33 - up, x0 + 3, 34 - up, shoes)
    # crash pad on the back: behind everything in front view, over it in back view
    if spec.get("pad") and view == "front":
        cv.rect(5, 14 + bob, 18, 25 + bob, spec["pad"])
    # torso and arms
    sw = 1 if frame == 1 else (-1 if frame == 2 else 0)
    if view == "side":
        cv.rect(9, 14 + bob, 14, 24 + bob, top)
        cv.rect(11 + sw, 15 + bob, 13 + sw, 21 + bob, shades(top)[2] if spec.get("long_sleeves") else skin)
        cv.rect(11 + sw, 22 + bob, 13 + sw, 23 + bob, skin)
        cv.rect(11 + sw, 15 + bob, 13 + sw, 17 + bob, top)
        if spec.get("pad"):
            cv.rect(5, 13 + bob, 9, 26 + bob, spec["pad"])
    else:
        cv.rect(7, 14 + bob, 16, 24 + bob, top)
        sleeve = top if spec.get("long_sleeves") else skin
        cv.rect(5, 15 + bob + sw, 6, 21 + bob + sw, sleeve)
        cv.rect(17, 15 + bob - sw, 18, 21 + bob - sw, sleeve)
        cv.rect(5, 15 + bob + sw, 6, 16 + bob + sw, top)
        cv.rect(17, 15 + bob - sw, 18, 16 + bob - sw, top)
        cv.rect(5, 22 + bob + sw, 6, 23 + bob + sw, skin)
        cv.rect(17, 22 + bob - sw, 18, 23 + bob - sw, skin)
        if spec.get("belt"):
            cv.rect(7, 23 + bob, 16, 23 + bob, spec["belt"], shade_bottom=0)
        if spec.get("chalk") and view == "back":
            cv.rect(15, 22 + bob, 17, 25 + bob, spec["chalk"])
        if spec.get("pad") and view == "back":
            cv.rect(5, 13 + bob, 18, 26 + bob, spec["pad"])
            cv.rect(6, 19 + bob, 17, 19 + bob, shades(spec["pad"])[3], shade_bottom=0)  # the fold
            cv.rect(8, 15 + bob, 9, 24 + bob, (60, 52, 50), shade_bottom=0)          # a strap
    if view == "front" and spec.get("chalk"):
        cv.rect(16, 22 + bob, 18, 25 + bob, spec["chalk"])
    if view == "front" and spec.get("collar"):
        cv.rect(10, 14 + bob, 13, 15 + bob, spec["collar"], shade_bottom=0)
    # head
    hy = 2 + bob
    lt_s, b_s, sh_s, dp_s = shades(skin)
    lt_h, b_h, sh_h, dp_h = shades(hair)
    if view == "side":
        cv.rect(9, hy + 2, 17, hy + 11, skin)
        cv.rect(8, hy, 15, hy + 4, hair)            # top of the head
        cv.rect(8, hy + 4, 12, hy + 9, hair)        # the back of the head
        cv.px(15, hy + 7, (40, 30, 40)); cv.px(15, hy + 6, (40, 30, 40))
        cv.px(16, hy + 9, sh_s)
        cv.px(17, hy + 7, b_s)                      # nose
        if spec.get("beard"):
            cv.rect(13, hy + 9, 17, hy + 12, spec["beard"])
    else:
        cv.rect(7, hy + 2, 16, hy + 11, skin)
        if view == "front":
            for ex in (9, 14):
                if frame == 4:  # blinking: a closed eye is a short line
                    cv.px(ex, hy + 8, (40, 30, 40)); cv.px(ex + (1 if ex == 9 else -1), hy + 8, (40, 30, 40))
                    continue
                cv.px(ex, hy + 7, (40, 30, 40)); cv.px(ex, hy + 8, (40, 30, 40))
                cv.px(ex + (1 if ex == 9 else -1), hy + 7, (250, 244, 236))
            cv.px(8, hy + 9, (232, 140, 130)); cv.px(15, hy + 9, (232, 140, 130))  # blush
            if spec.get("glasses"):
                for ex in (8, 13):
                    for gx in range(ex, ex + 3):
                        cv.px(gx, hy + 6, (60, 50, 60)); cv.px(gx, hy + 9, (60, 50, 60))
            if spec.get("beard"):
                cv.rect(7, hy + 9, 16, hy + 12, spec["beard"])
                cv.rect(10, hy + 10, 13, hy + 10, shades(spec["beard"])[2], shade_bottom=0)
            # hair: top and bangs, longer at the sides for some styles
            cv.rect(6, hy, 17, hy + 3, hair)
            for x in range(7, 17):
                if (x * 3) % 5 < 3:
                    cv.px(x, hy + 4, b_h if x < 12 else sh_h)
            side_len = spec.get("hair_len", 6)
            cv.rect(6, hy + 2, 6, hy + side_len, hair)
            cv.rect(17, hy + 2, 17, hy + side_len, hair)
        else:  # back: all hair
            cv.rect(6, hy, 17, hy + spec.get("hair_len", 6) + 4, hair)
    if spec.get("ponytail"):
        if view == "back":
            cv.rect(10, hy + 9, 13, hy + 16, hair)
        elif view == "side":
            cv.rect(5, hy + 4, 8, hy + 12, hair)
    # hat
    hat = spec.get("hat")
    if hat:
        kind, col = hat
        if kind == "beanie":
            if view == "side":
                cv.rect(8, hy - 2, 16, hy + 2, col); cv.rect(8, hy + 3, 16, hy + 3, shades(col)[2], shade_bottom=0)
                cv.px(10, hy - 3, col)
            else:
                cv.rect(6, hy - 2, 17, hy + 2, col); cv.rect(6, hy + 3, 17, hy + 3, shades(col)[2], shade_bottom=0)
                cv.rect(11, hy - 4, 12, hy - 3, shades(col)[0])
        elif kind == "cap":
            if view == "side":
                cv.rect(8, hy - 1, 15, hy + 2, col); cv.rect(15, hy + 2, 19, hy + 2, shades(col)[2], shade_bottom=0)
            else:
                cv.rect(6, hy - 1, 17, hy + 2, col)
                if view == "front":
                    cv.rect(6, hy + 3, 17, hy + 3, shades(col)[2], shade_bottom=0)
        elif kind == "ranger":
            cv.rect(4, hy + 1, 19, hy + 2, shades(col)[2]) if view != "side" else cv.rect(5, hy + 1, 19, hy + 2, shades(col)[2])
            cv.rect(7, hy - 3, 16, hy + 1, col) if view != "side" else cv.rect(8, hy - 3, 15, hy + 1, col)
            cv.rect(7, hy, 16, hy, spec.get("band", (120, 70, 40)), shade_bottom=0) if view != "side" else None
        elif kind == "flat":
            cv.rect(6, hy - 1, 17, hy + 2, col)
            if view == "front":
                cv.rect(6, hy + 2, 17, hy + 3, shades(col)[2], shade_bottom=0)
        elif kind == "band":
            cv.rect(6, hy + 2, 17, hy + 3, col, shade_bottom=0) if view != "side" else cv.rect(8, hy + 2, 17, hy + 3, col, shade_bottom=0)
    if spec.get("stick") and view != "back":
        for y in range(16, 35):
            cv.px(20, y, (110, 74, 46))
        cv.px(19, 22 + bob, skin)
    cv.outline(spec.get("outline", (40, 26, 38)))
    return cv.rgba()


def dog(frame):
    cv = Canvas(20, 16)
    fur, dark = (206, 152, 88), (150, 98, 58)
    cv.rect(4, 6, 15, 11, fur)                     # body
    cv.rect(13, 2, 18, 8, fur)                     # head
    cv.rect(17, 5, 19, 7, fur)                     # snout
    cv.px(19, 5, (40, 30, 30))                     # nose
    cv.px(16, 4, (40, 30, 30))                     # eye
    cv.rect(13, 1, 14, 4, dark)                    # ear
    cv.rect(1, 4 + (frame % 2), 4, 6 + (frame % 2), fur)  # wagging tail
    for k, x in enumerate([5, 8, 11, 14]):
        up = 1 if (frame == 1 and k % 2 == 0) or (frame == 2 and k % 2 == 1) else 0
        cv.rect(x, 12 - up, x + 1, 14 - up, dark)
    cv.outline((50, 32, 30))
    return cv.rgba()


PEOPLE = {
    "player": dict(skin="light", hair=(78, 50, 40), top=(196, 78, 60), legs=(104, 108, 70), shoes=(110, 70, 124),
                   hat=("beanie", (236, 180, 64)), pad=(64, 96, 150), chalk=(76, 128, 176), hair_len=5),
    "pepe": dict(skin="tan", hair=(220, 216, 208), top=(150, 104, 66), legs=(80, 74, 70), shoes=(70, 50, 40),
                 hat=("flat", (98, 88, 80)), beard=(232, 228, 220), long_sleeves=True, stick=True, hair_len=4,
                 collar=(220, 210, 190)),
    "sanne": dict(skin="light", hair=(168, 74, 44), top=(62, 150, 150), legs=(54, 50, 74), shoes=(230, 220, 210),
                  ponytail=True, hair_len=8, chalk=(220, 120, 140)),
    "mat": dict(skin="light", hair=(96, 45, 35), top=(133, 49, 39), legs=(104, 108, 70), shoes=(150, 60, 50),
                hair_len=6),
    "tim": dict(skin="light", hair=(196, 156, 92), top=(92, 136, 84), legs=(70, 92, 140), shoes=(60, 60, 70),
                hat=("cap", (190, 60, 60)), glasses=True, long_sleeves=True, hair_len=5),
    "boswachter": dict(skin="tan", hair=(92, 66, 50), top=(84, 106, 64), legs=(92, 82, 62), shoes=(58, 42, 34),
                       hat=("ranger", (120, 130, 82)), beard=(100, 72, 54), long_sleeves=True, belt=(80, 56, 40),
                       band=(140, 90, 50), hair_len=4),
    "yara": dict(skin="tan", hair=(54, 36, 30), top=(150, 90, 170), legs=(46, 50, 58), shoes=(240, 200, 70),
                 ponytail=True, hair_len=8, chalk=(70, 70, 80)),
}


# ---------------------------------------------------------------- props
def sign():
    cv = Canvas(52, 40)
    wood, dark = (150, 102, 62), (98, 64, 40)
    for x0 in (8, 41):                                   # posts
        cv.rect(x0, 14, x0 + 3, 39, dark)
    for k, y0 in enumerate((4, 12, 20)):                 # three planks
        cv.rect(2, y0, 49, y0 + 7, wood if k % 2 == 0 else shades(wood)[0])
        for x in range(4, 48, 7):                        # wood grain
            cv.px(x + k, y0 + 3, shades(wood)[2])
            cv.px(x + k + 1, y0 + 3, shades(wood)[2])
    for x, y in [(4, 6), (47, 6), (4, 22), (47, 22)]:    # nails
        cv.px(x, y, (60, 56, 60))
    cv.outline((44, 28, 24))
    img = Image.fromarray(cv.c.astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(os.path.join(FONT_DIR, "Kenney Mini.ttf"), 8)
    for line, y in (("LES SABLES", 5), ("D'OR", 13)):
        w = d.textlength(line, font=f)
        d.text((26 - w / 2, y), line, font=f, fill=(250, 226, 120, 255))
    d.polygon([(19, 23), (30, 23), (30, 21), (34, 25), (30, 29), (30, 27), (19, 27)], fill=(250, 226, 120, 255))
    return np.array(img).astype(float) / 255.0


def tent():
    cv = Canvas(64, 46)
    canvas_c = (222, 128, 64)
    lt, b, sh, dp = shades(canvas_c)
    apex, base_y = (32, 3), 42
    for y in range(apex[1], base_y + 1):
        half = (y - apex[1]) * 0.78
        for x in range(int(32 - half), int(32 + half) + 1):
            col = lt if x < 32 - half * 0.45 else (b if x < 32 + half * 0.2 else sh)
            cv.px(x, y, col)
    for y in range(apex[1] + 2, base_y + 1, 6):           # seams
        half = (y - apex[1]) * 0.78
        for x in range(int(32 - half) + 1, int(32 + half)):
            if x % 2 == 0:
                cv.px(x, y, shades(canvas_c)[2] if x < 32 else dp)
    for x0, y0, c in [(18, 30, (196, 168, 92)), (40, 24, (120, 150, 170))]:  # patches
        cv.rect(x0, y0, x0 + 5, y0 + 4, c)
    for y in range(18, base_y + 1):                        # the open door
        half = (y - 18) * 0.42
        for x in range(int(32 - half), int(32 + half) + 1):
            cv.px(x, y, (40, 26, 30) if abs(x - 32) < half - 1 else dp)
    for x in range(int(32 - 24 * 0.42) - 2, 26):           # the door flap, tied back
        cv.px(x, 30 + (26 - x) // 2, lt)
    for side in (-1, 1):                                   # guy ropes and pegs
        for k in range(14):
            cv.px(32 + side * (31 - k), 40 - k // 2 + 3, (226, 214, 180))
        cv.rect(32 + side * 31 - 1, 41, 32 + side * 31, 44, (140, 120, 100))
    cv.outline((60, 30, 26))
    return cv.rgba()


def _log(cv, p0, p1, r, bark, lit):
    """A round log from p0 to p1, lit from above, its cut end showing at p0; the far end,
    in the middle of the fire, charred or burning."""
    lt, base, sh, dp = shades(bark)
    (x0, y0), (x1, y1) = p0, p1
    d = np.array([x1 - x0, y1 - y0], float)
    L = np.linalg.norm(d)
    u = d / L
    nrm = np.array([-u[1], u[0]])
    if nrm[1] > 0:
        nrm = -nrm                                          # the side that faces up
    for y in range(cv.h):
        for x in range(cv.w):
            v = np.array([x + 0.5 - x0, y + 0.5 - y0])
            t = v @ u
            off = v @ nrm
            if 0 <= t <= L and abs(off) <= r:
                k = off / r                                  # +1 on top, -1 underneath
                col = lt if k > 0.4 else (base if k > -0.4 else sh)
                if int(t) % 5 == 2 and -0.4 < k < 0.4:
                    col = sh                                 # bark
                if t > L - 4:
                    col = ((250, 160, 60) if k > -0.2 else (210, 80, 34)) if lit else ((70, 54, 50) if k > 0 else (44, 34, 36))
                cv.px(x, y, col)
    for y in range(cv.h):                                   # the cut end: pale wood, rings
        for x in range(cv.w):
            dx, dy = x + 0.5 - x0, y + 0.5 - y0
            q = dx * dx / (r * 0.75) ** 2 + dy * dy / r ** 2
            if q <= 1:
                cv.px(x, y, (226, 190, 130) if q < 0.3 or q > 0.7 else (184, 140, 90))


def fire_base(lit=False):
    """A camp fire: two thick logs crossed over each other in a ring of stones."""
    cv = Canvas(32, 21)
    cx, cy = 16, 11
    def stone(x, y, k):
        lt, base, sh, dp = shades((158, 150, 138) if k % 2 else (130, 124, 116))
        for yy in range(-1, 2):
            for xx in range(-2, 3):
                if xx * xx / 4.5 + yy * yy / 2.2 <= 1:
                    cv.px(x + xx, y + yy, lt if yy < 0 and xx < 1 else (base if yy < 1 else sh))
    ring = [(cx + 9.6 * np.cos(a), cy + 4.8 * np.sin(a)) for a in np.linspace(0, 2 * np.pi, 12)[:-1] + 0.2]
    for k, (x, y) in enumerate(ring):
        stone(round(x), round(y), k)
    for y in range(cy - 3, cy + 4):                         # ash or embers in the middle
        for x in range(cx - 7, cx + 8):
            if ((x - cx) / 7.6) ** 2 + ((y - cy) / 3.5) ** 2 <= 1:
                if lit:
                    cv.px(x, y, (236, 108, 36) if (x * 7 + y * 3) % 5 else (255, 214, 120))
                else:
                    cv.px(x, y, (124, 118, 116) if (x * 7 + y * 3) % 4 else (86, 80, 82))
    # two thick logs crossed over each other, sticking out over the stones
    _log(cv, (cx + 11, cy + 5), (cx - 2, cy - 3), 2.0, (104, 68, 42), lit)   # underneath
    _log(cv, (cx - 11, cy + 6), (cx + 3, cy - 3), 2.1, (126, 86, 54), lit)   # over it
    cv.outline((44, 34, 36))
    return cv.rgba()


def flames(n=6, w=17, h=23):
    """Animated flames, white-hot in the middle, orange, red at the tips."""
    frames = []
    rng = np.random.default_rng(4)
    noise = rng.random((h * 3, w))
    noise = gaussian_filter(noise, 1.4)
    yy, xx = np.mgrid[0:h, 0:w]
    ramp = [(0.0, (0, 0, 0, 0)), (0.18, (168, 40, 30, 255)), (0.36, (232, 94, 34, 255)), (0.58, (250, 170, 54, 255)),
            (0.8, (255, 228, 120, 255)), (1.0, (255, 250, 220, 255))]
    for f in range(n):
        shift = f * 5
        nz = noise[(yy + shift) % (h * 3) + 0, xx]
        nz = (nz - nz.min()) / (nz.max() - nz.min())
        up = yy / (h - 1)                                   # 0 at the top, 1 at the bottom
        width = 0.15 + 0.85 * up ** 0.7
        across = 1 - np.abs(xx - w / 2 + 0.5 + 2 * np.sin(yy / 4 + f)) / (w / 2 * width + 0.01)
        heat = np.clip(across, 0, 1) * (0.35 + 0.65 * up) + (nz - 0.5) * 0.55
        heat = np.clip(heat, 0, 1)
        out = np.zeros((h, w, 4))
        for (a, ca), (b2, cb) in zip(ramp[:-1], ramp[1:]):
            sel = (heat >= a) & (heat < b2) if b2 < 1 else (heat >= a)
            out[sel] = cb if heat[sel].mean() > (a + b2) / 2 else ca
        out[heat < 0.18] = 0
        frames.append(out / 255.0)
    return frames


def _ring(cv, col):
    """An outline without rounding the corners: small and thin things keep their pixels."""
    a = cv.c[..., 3] > 0
    ring = binary_dilation(a) & ~a
    cv.c[ring, :3] = col
    cv.c[ring, 3] = 255


def details():
    """Small things lying on the ground, flat: pebbles, a pine cone, a twig, a dry leaf, a
    flat stone, a tuft of dead needles."""
    out = []
    cv = Canvas(10, 8)                                     # pebbles
    for x, y, c in [(2, 4, (150, 142, 132)), (5, 2, (128, 122, 116)), (6, 5, (168, 160, 148))]:
        cv.rect(x, y, x + 1, y + 1, c)
    _ring(cv, (70, 60, 58)); out.append(cv.rgba())
    cv = Canvas(10, 8)                                     # a pine cone
    cv.rect(2, 3, 7, 5, (132, 86, 50))
    for x in (3, 5):
        cv.px(x, 3, (176, 124, 76)); cv.px(x + 1, 5, (96, 60, 38))
    cv.px(8, 4, (96, 60, 38))
    _ring(cv, (60, 40, 30)); out.append(cv.rgba())
    cv = Canvas(10, 8)                                     # a twig
    for x in range(1, 9):
        cv.px(x, 4 - (x // 4), (120, 86, 56))
    cv.px(5, 2, (120, 86, 56)); cv.px(6, 1, (120, 86, 56))
    _ring(cv, (70, 48, 34)); out.append(cv.rgba())
    cv = Canvas(10, 8)                                     # a dry oak leaf
    cv.rect(2, 3, 6, 5, (200, 120, 50)); cv.rect(3, 2, 5, 6, (200, 120, 50))
    cv.px(7, 4, (150, 86, 40)); cv.px(4, 4, (150, 86, 40))
    _ring(cv, (96, 56, 30)); out.append(cv.rgba())
    cv = Canvas(10, 8)                                     # a flat stone
    cv.rect(2, 3, 7, 5, (156, 150, 140)); cv.rect(3, 3, 6, 3, (182, 176, 164))
    _ring(cv, (76, 70, 66)); out.append(cv.rgba())
    cv = Canvas(10, 8)                                     # a little heap of dead needles
    for k in range(9):
        x, y = 1 + (k * 3) % 8, 2 + (k * 5) % 5
        cv.px(x, y, (150, 104, 60)); cv.px(x + 1, y, (124, 84, 50))
    _ring(cv, (80, 56, 36)); out.append(cv.rgba())
    return out


def blanket():
    cv = Canvas(34, 22)
    for y in range(22):
        for x in range(34):
            red = (176, 64, 54)
            check = ((x // 4) + (y // 4)) % 2
            col = red if check else (214, 196, 160)
            if x % 4 == 0 or y % 4 == 0:
                col = shades(col)[2]
            cv.px(x, y, col)
    cv.outline((70, 30, 30))
    return cv.rgba()


# ---------------------------------------------------------------- output
def normal_map(spr):
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


def save(frames, out, name, normals=True):
    h = max(f.shape[0] for f in frames)
    w = max(f.shape[1] for f in frames)
    sheet = np.zeros((h, w * len(frames), 4))
    for k, f in enumerate(frames):
        sheet[h - f.shape[0]:, k * w + (w - f.shape[1]) // 2:k * w + (w - f.shape[1]) // 2 + f.shape[1]] = f
    Image.fromarray((sheet * 255).astype(np.uint8), "RGBA").save(f"{out}/{name}.png")
    if normals:
        Image.fromarray((normal_map(sheet) * 255).astype(np.uint8), "RGBA").save(f"{out}/{name}_n.png")
    return w, h


def _frame_size(f):
    """A figure centred in a full CW x CH frame, standing on its bottom row: the game cuts
    the sheet into frames of that size, so a narrower one would be stretched."""
    out = np.zeros((CH, CW, 4), f.dtype)
    x = (CW - f.shape[1]) // 2
    out[CH - f.shape[0]:, x:x + f.shape[1]] = f
    return out


@functools.lru_cache(maxsize=None)
def _cleaned(image):
    return ai_sprite.clean(os.path.join(AI_DIR, image), CH)


def ai_figures(name):
    """The views of one person that an image AI drew: view -> (figure, the top pixel of
    each eye), touched up."""
    views = {}
    for image, cast in AI.items():
        for who, fig in zip(cast, _cleaned(image)):
            if who is None or who[0] != name:
                continue
            assert fig.shape[0] == CH and fig.shape[1] + 4 <= CW, f"{image} {who}: {fig.shape[1]} x {fig.shape[0]}"
            fig = fig.copy()
            eyes = []
            for x0, y0, rows in TOUCH_UPS.get(who, []):
                for dy, row in enumerate(rows):
                    for dx, key in enumerate(row):
                        if key == ".":
                            continue
                        fig[y0 + dy, x0 + dx] = (ai_sprite.OUTLINE if key == "#" else TOUCH[key]) + (255,)
                        below = rows[dy + 1][dx] if dy + 1 < len(rows) else "."
                        above = rows[dy - 1][dx] if dy > 0 else "."
                        if key == "c" and below == "c" and above != "c":
                            eyes.append((x0 + dx, y0 + dy))
            views[who[1]] = (fig, eyes)
    return views


def ai_views(name):
    """The views of one person that an image AI drew, as four walking frames each."""
    return {view: [_frame_size(f) / 255.0 for f in ai_sprite.walk_frames(fig, AI_HIP, side=view == "side")]
            for view, (fig, eyes) in ai_figures(name).items()}


def ai_npc(name):
    """Standing, breathing in and a blink for someone an image AI drew from the front, or
    None when it did not."""
    front = ai_figures(name).get("front")
    if front is None:
        return None
    fig, eyes = front
    stand, _, _, breath = ai_sprite.walk_frames(fig, AI_HIP)
    blink = stand.copy()
    for x, y in eyes:  # walk_frames added two columns on the left
        blink[y, x + 2] = blink[y, x + 3]  # the skin beside it: a closed eye is a short line
    return [_frame_size(f) / 255.0 for f in (stand, breath, blink)]


def main(out):
    os.makedirs(out, exist_ok=True)
    sizes = {}
    for name, spec in PEOPLE.items():
        if name == "player":   # per view: stand, two steps, breathing in
            views = {v: [character(spec, v, f) for f in (0, 1, 2, 3)] for v in ("back", "front", "side")}
            views.update(ai_views(name))
            frames = views["back"] + views["front"] + views["side"]
        else:                  # stand, breathing in, a blink
            frames = ai_npc(name) or [character(spec, "front", f) for f in (0, 3, 4)]
        sizes[name] = save(frames, out, name if name == "player" else "npc_" + name)
    sizes["dog"] = save([dog(0), dog(3)], out, "npc_biscuit")  # the tail wags
    sizes["details"] = save(details(), out, "details")
    sizes["tent"] = save([tent()], out, "tent")
    sizes["fire_base"] = save([fire_base()], out, "fire_base")
    sizes["fire_lit"] = save([fire_base(True)], out, "fire_lit")
    sizes["flames"] = save(flames(), out, "flames", normals=False)
    sizes["blanket"] = save([blanket()], out, "blanket")
    return sizes


if __name__ == "__main__":
    print(main(sys.argv[1]))
