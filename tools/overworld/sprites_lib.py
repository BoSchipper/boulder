import numpy as np

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


