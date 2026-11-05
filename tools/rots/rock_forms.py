"""Boulder face built from rock forms, so holds come out of the shape of the rock itself.

Sandstone layers that step back, scooped-out hollows, rounded bulges and pockets make
one height map. The same map gives the picture and the grip, so what you see is what
holds. Rendered flat-shaded with cool shadows and warm light, with or without ink.
"""
import math
import sys
import numpy as np
from PIL import Image, ImageFilter

W, H = 480, 270
FLOOR = 258
CX = 248
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
ys, xs = np.mgrid[0:H, 0:W].astype(float)


def noise(cell, seed):
    r = np.random.default_rng(seed)
    grid = r.random((H // cell + 2, W // cell + 2))
    gy, gx = ys / cell, xs / cell
    y0, x0 = gy.astype(int), gx.astype(int)
    fy, fx = gy - y0, gx - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = grid[y0, x0] * (1 - fx) + grid[y0, x0 + 1] * fx
    b = grid[y0 + 1, x0] * (1 - fx) + grid[y0 + 1, x0 + 1] * fx
    return (a * (1 - fy) + b * fy - 0.5) * 2


def blob(x, y, rx, ry):
    return np.exp(-(((xs - x) / rx) ** 2 + ((ys - y) / ry) ** 2))


# Every block is a spec: its outline, how domed it is, and the forms on its face. The
# first one, La Marie-Rose, is the block from the first mockups; the others come from a
# seed and a few numbers that set their character.
SPECS = {
    "marierose": dict(lean=0, hw=114, top0=26, drop=74, dome=46, chalk=0.0, feet_max=0.6,
        title="La Marie-Rose", grade="6a",
        bulges=[(200, 100, 40, 34, 7), (300, 90, 36, 30, 6), (230, 160, 44, 26, 5), (300, 220, 42, 30, 6), (190, 230, 36, 24, 5)],
        layers=[(180, 10, 4.5), (151, 11, 1.6), (123, 12, 3.0), (94, 13, 1.6), (62, 14, 2.4)],
        scoops=[(210, 200, 22, 12, 5), (300, 132, 16, 10, 4), (232, 74, 18, 9, 4), (180, 120, 12, 14, 3)],
        slopers=[(272, 142, 13, 9, 6), (250, 58, 16, 10, 7), (320, 205, 15, 11, 6), (176, 166, 10, 8, 4)],
        pockets=[(240, 120, 4.5, 7), (195, 72, 2.2, 4), (306, 62, 2.6, 4), (340, 128, 2.2, 4), (228, 206, 2.0, 3)],
        crack=(294, 118, 184)),
    # Small and friendly: deep rims all the way up, chalked.
    "premiere": dict(lean=-4, seed=21, hw=82, top0=104, drop=40, dome=36, layer_depth=(2.6, 4.2), layer_gap=26,
        scoop_n=2, sloper_n=2, pocket_n=3, crack=None, chalk=0.0, feet_max=0.62, title="La Premiere", grade="2"),
    # Les Sables teaches the holds with a direction one at a time, on blocks 2, 3 and 4; La Lame
    # then asks for all three. `directional` writes a direction map, `tip` is told once.
    # Tall and round like a slide: rims low down, then three slopers up the middle, small
    # edges between them for your feet.
    "toboggan": dict(lean=-6, seed=22, hw=88, top0=34, drop=60, dome=52, layer_depth=(2.4, 3.8), layer_gap=28,
        scoop_n=1, sloper_n=0, pocket_n=2, crack=None, chalk=0.0, feet_max=0.6, title="Le Toboggan", grade="2+",
        layers_below=176, start=(246, 186, 30),
        big_slopers=[(226, 150, 18, 11, 7.5), (266, 112, 19, 11, 7.5), (230, 74, 19, 11, 7.5)],
        edges=[(262, 176, 10, 1.6), (246, 132, 8, 1.3), (250, 96, 8, 1.3)], directional=True,  # mostly for feet
        tip="Slopers: pull them straight down, never sideways.\nStand up past one and press down on it."),
    # A wide slab, your feet carry much more: underclings you stand up over, and pockets.
    "dalle": dict(lean=-14, seed=23, hw=132, top0=78, drop=46, dome=30, layer_depth=(2.2, 3.3), layer_gap=24,
        scoop_n=1, sloper_n=0, pocket_n=5, crack=None, chalk=0.0, feet_max=0.82, title="La Dalle aux Fourmis", grade="3",
        layers_below=214, start=(246, 206, 26), underclings=[(212, 194, 18), (268, 160, 18), (230, 128, 16)],
        edges=[(258, 214, 10, 2.2), (240, 176, 8, 2.0), (252, 104, 8, 2.0)], directional=True,
        tip="Underclings: grab them from below,\nthen stand up high on your feet."),
    # One big pot halfway up to rest in, with a flake on each side: side pulls both ways.
    "potdechalk": dict(lean=2, seed=24, hw=104, top0=58, drop=58, dome=44, layer_depth=(2.0, 3.4), layer_gap=34,
        scoop_n=2, sloper_n=1, pocket_n=3, crack=None, pot=(0.5, 9.0), chalk=0.0, feet_max=0.62,
        title="Le Pot de Chalk", grade="3+", layers_below=210, start=(252, 192, 22),
        flakes=[(206, 168, 236, 1), (290, 82, 150, -1)], edges=[(250, 214, 10, 2.2), (262, 120, 8, 2.0)],
        directional=True, tip="Side pulls: lean away from the crack,\nthe way it faces."),
    # A dyno: a good ledge halfway, then smooth bulging rock and one big jug far above it,
    # too far to reach. You have to jump. Steep, so smears on the blank part hold little.
    "saut": dict(lean=6, seed=26, hw=96, top0=24, drop=54, dome=44, layer_depth=(2.4, 3.6), layer_gap=27,
        scoop_n=3, sloper_n=2, pocket_n=4, crack=None, chalk=0.0, feet_max=0.5, dyno=(150, 56),
        title="Le Saut", grade="4a"),
    # An overhang: the block leans out over you, wider at the top than at its foot. Big
    # rims facing down, a roof edge to pull over. Your feet carry little.
    "toit": dict(lean=24, seed=27, hw=100, top0=40, drop=40, dome=30, layer_depth=(3.0, 4.4), layer_gap=30,
        scoop_n=2, sloper_n=1, pocket_n=5, crack=None, chalk=0.0, feet_max=0.3, overhang=True,
        title="Le Toit", grade="4a",
        tip="Overhang: hold tension as you move a hand,\nor your feet cut loose. Hook a heel to rest."),
    # The test block for holds with a direction: a flake you lay back on, an undercling you
    # stand up over, a big sloper on top. Few rims, so these three have to do the work.
    # `directional` writes a direction map: the game then asks how you pull, not only where.
    "lame": dict(lean=0, seed=28, hw=112, top0=38, drop=48, dome=40, layer_depth=(2.2, 3.2), layer_gap=30,
        scoop_n=1, sloper_n=0, pocket_n=3, crack=None, chalk=0.0, feet_max=0.6, title="La Lame", grade="3+",
        layers_below=200,
        flakes=[(286, 112, 206, -1)],            # lip x, top, bottom; the crack is on this side: pull that way
        underclings=[(204, 150, 26)],            # x and y of the bottom edge, half its width
        big_slopers=[(238, 78, 30, 17, 7.5)],    # x, y, rx, ry, depth
        edges=[(236, 188, 16, 2.6), (262, 122, 12, 2.2),  # small edges to step between them
               (277, 84, 7, 1.6)],  # a crimp beside the sloper: one hand stays there while the other tops out
        directional=True),
}
SPEC = {}
CX = 248
HW = 114
half = top = INSIDE = None


def configure(name):
    """Sets up the outline and the forms of one block; everything else reads these."""
    global SPEC, half, top, INSIDE, HW
    S = dict(SPECS[name])
    HW = S["hw"]
    lean = -26 if S.get("overhang") else 12  # an overhang is widest at the top
    half = HW + lean * np.clip((ys - (S["top0"] + 84)) / 150, 0, 1) + 5 * np.sin(ys / 41.0 + 1) + 2 * noise(14, 50)
    top = S["top0"] + ((xs - CX) / HW) ** 4 * S["drop"] + 5 * np.sin(xs / 33.0) + 2 * noise(12, 51)
    INSIDE = (np.abs(xs - CX) < half) & (ys > top) & (ys < FLOOR + 1)
    if "layers" not in S:
        r = np.random.default_rng(S["seed"])
        y_top = S["top0"] + 22
        S["layers"] = []
        y = FLOOR - 30
        k = 0
        while y > y_top:
            S["layers"].append((y + r.uniform(-4, 4), S["seed"] * 10 + k, r.uniform(*S["layer_depth"])))
            y -= S["layer_gap"] * r.uniform(0.85, 1.15)
            k += 1
        def spot():
            while True:
                x, y = r.uniform(CX - HW * 0.8, CX + HW * 0.8), r.uniform(y_top, FLOOR - 20)
                if INSIDE[int(y), int(x)]:
                    return x, y
        S["bulges"] = [(*spot(), r.uniform(30, 44), r.uniform(22, 34), r.uniform(4, 7)) for _ in range(4)]
        S["scoops"] = [(*spot(), r.uniform(12, 22), r.uniform(8, 13), r.uniform(3, 5)) for _ in range(S["scoop_n"])]
        S["slopers"] = [(*spot(), r.uniform(10, 16), r.uniform(8, 11), r.uniform(4, 7)) for _ in range(S["sloper_n"])]
        S["pockets"] = [(*spot(), r.uniform(2.0, 4.0), r.uniform(3, 6)) for _ in range(S["pocket_n"])]
        if "pot" in S:  # the big pot that gives the block its name
            fy, depth = S["pot"]
            S["pockets"].append((CX + r.uniform(-20, 20), S["top0"] + (FLOOR - S["top0"]) * fy, 8.0, depth))
        if "dyno" in S:
            # Nothing between the ledge and the jug: only a smooth swelling of rock.
            y_from, y_to = S["dyno"]
            blank = lambda y, pad=0: y_to - pad < y < y_from + 4 + pad
            S["layers"] = [l for l in S["layers"] if not blank(l[0], 6)]
            for key in ("scoops", "slopers", "pockets"):
                S[key] = [f for f in S[key] if not (blank(f[1], 10) and abs(f[0] - CX) < HW * 0.7)]
            S["bulges"] = [b for b in S["bulges"] if not blank(b[1], 4)] + [(CX + 6, (y_from + y_to) / 2, 40, 30, 4)]
            S["rims"] = [(y_from, 40, 4.0), (y_to, 26, 5.5)]  # the ledge you jump from, the jug
        if S.get("crack"):
            cx = CX + r.uniform(-HW * 0.4, HW * 0.4)
            y0 = r.uniform(S["top0"] + 50, FLOOR - 110)
            S["crack"] = (cx, y0, y0 + r.uniform(50, 80))
        if "layers_below" in S:  # rims only low down, at the start
            S["layers"] = [l for l in S["layers"] if l[0] > S["layers_below"]]
        # Around a flake, an undercling or a big sloper the rock stays plain, so they read.
        def clear(f):
            x, y = f[0], f[1]
            return any(abs(x - lx) < 34 and y0 - 12 < y < y1 + 8 for lx, y0, y1, _ in S.get("flakes", [])) or \
                any(abs(x - ux) < 36 and uy - 34 < y < uy + 14 for ux, uy, _ in S.get("underclings", [])) or \
                any(abs(x - sx) < 44 and y < sy + 26 for sx, sy, *_ in S.get("big_slopers", []))
        for key in ("scoops", "slopers", "pockets", "bulges"):
            S[key] = [f for f in S[key] if not clear(f)]
    SPEC = S


def height_map():
    S = SPEC
    hm = S["dome"] * np.clip(1 - ((xs - CX) / (half + 6)) ** 2, 0, 1) ** 0.6
    hm += 26 * np.clip((ys - top) / 40, 0, 1) ** 0.7
    hm += 2.0 * noise(36, 1) + 0.35 * noise(11, 2) + 0.1 * noise(4, 3)
    # Font sandstone is round: big soft swellings, like a cauliflower.
    for x, y, rx, ry, d in S["bulges"]:
        hm += d * blob(x, y, rx, ry)
    # Sandstone layers: where a layer sticks out over the next, its lower rim is an edge.
    # The step is deep in places (a jug) and runs out to nothing (a crimp, then no hold).
    for y0, seed, depth in S["layers"]:
        line = y0 + 6 * noise(60, seed) + 2.5 * noise(17, seed + 20)
        along = np.clip(noise(30, seed + 40) * 2.2 - 0.02, 0, 1) * np.clip(1 - ((xs - CX) / (HW - 14)) ** 2, 0, 1)
        step = 1 / (1 + np.exp((ys - line) / 0.9))  # 1 above the rim, 0 below
        hm += depth * along * (step - 0.5) * 2
        hm -= depth * along * 0.7 * np.exp(-((ys - line - 3) / 3.5) ** 2)  # undercut below
    # Every problem has a start: a clear rim you can reach from the ground.
    if "seed" in S:
        sx, sy, sw = S.get("start", (CX, FLOOR - 84, 46))  # where it is, and half its width
        line = sy + 2.0 * noise(40, S["seed"] + 300)
        along = np.clip(1 - ((xs - sx) / sw) ** 2, 0, 1)
        d = S["layer_depth"][1]
        step = 1 / (1 + np.exp((ys - line) / 0.9))
        hm += d * along * (step - 0.5) * 2
        hm -= d * along * 0.7 * np.exp(-((ys - line - 3) / 3.5) ** 2)
    # Rims that are always there, the whole width given: a dyno's ledge and its jug.
    for y0, w, d in S.get("rims", []):
        line = y0 + 1.5 * noise(40, S["seed"] + 310 + int(y0))
        along = np.clip(1 - ((xs - CX) / w) ** 2, 0, 1) ** 0.5
        step = 1 / (1 + np.exp((ys - line) / 0.9))
        hm += d * along * (step - 0.5) * 2
        hm -= d * along * 0.7 * np.exp(-((ys - line - 3) / 3.5) ** 2)
    # Scooped hollows: the top rim of a scoop is a slopey edge, the inside is in shadow.
    for x, y, rx, ry, d in S["scoops"]:
        hm -= d * blob(x, y, rx, ry)
    # Rounded bulges: slopers, good only from below.
    for x, y, rx, ry, d in S["slopers"]:
        hm += d * blob(x, y, rx, ry)
    # Pockets, the holes of Font.
    for x, y, r, d in S["pockets"]:
        hm -= d * blob(x, y, r * 1.2, r * 0.8)
    # A crack that you can pull sideways on.
    if S.get("crack"):
        cx, y0, y1 = S["crack"]
        cx_line = cx + 3 * np.sin(ys / 9.0) + 1.5 * noise(8, 70)
        hm -= 3.0 * np.exp(-((xs - cx_line) / 1.1) ** 2) * ((ys > y0) & (ys < y1))
    # A flake: a slab standing proud beside a vertical lip, with a dark crack behind it.
    for lx, y0, y1, side in S.get("flakes", []):
        span = _flake_span(y0, y1)
        lip = _flake_lip(lx)
        away = -side * (xs - lip)  # > 0 on the slab, away from the crack
        proud = 1 / (1 + np.exp(-away / 0.8)) * np.clip(1 - (away / 58) ** 2, 0, 1)
        hm += 8.0 * proud * span
        hm -= 3.2 * np.exp(-((xs - lip - side * 2.5) / 1.6) ** 2) * span
    # An undercling: a round lump cut off flat underneath; you grab its bottom edge palm up.
    for ux, uy, uw in S.get("underclings", []):
        edge = _under_edge(uy)
        lump = np.clip(1 - ((xs - ux) / uw) ** 2 - ((ys - edge) / 24) ** 2, 0, 1) ** 0.45
        cut = 1 / (1 + np.exp((ys - edge) / 0.7))
        hm += 7.5 * lump * cut
        along = np.clip(1 - ((xs - ux) / (uw * 0.9)) ** 2, 0, 1)
        hm -= 2.4 * along * np.exp(-((ys - edge - 2.5) / 2.2) ** 2)  # shadow under the edge
    # Small edges, only a few pixels tall (the long rims above run the whole height).
    for ex0, ey0, ew, ed in S.get("edges", []):
        a = np.clip(1 - ((xs - ex0) / ew) ** 2, 0, 1) ** 0.7 * np.exp(-((ys - ey0) / 7.0) ** 2)
        st = 1 / (1 + np.exp((ys - ey0) / 0.9))
        hm += ed * a * (st - 0.5) * 2
        hm -= ed * a * 0.7 * np.exp(-((ys - ey0 - 3) / 3.0) ** 2)
    # A big sloper: one round bulge, nothing to curl over. Shaped like a dome, so it shows in
    # the rock's own light and shade, with its own small shadow under it.
    for x, y, rx, ry, d in S.get("big_slopers", []):
        hm += d * _dome(x, y, rx, ry)
    return hm


def _dome(x, y, rx, ry):
    r2 = ((xs - x) / (rx * 0.95)) ** 2 + ((ys - y) / (ry * 0.95)) ** 2
    return _blur(np.clip(1 - r2, 0, 1) ** 0.55, 1.4)


def _flake_span(y0, y1):
    return np.clip((ys - y0) / 10, 0, 1) * np.clip((y1 - ys) / 10, 0, 1)


def _flake_lip(lx):
    return lx + 2.5 * np.sin(ys / 13.0) + 1.2 * noise(9, 401)


def _under_edge(uy):
    return uy + 1.2 * noise(30, 402)


def dir_map():
    """Which way a hand has to pull for each hold to work, and how much that matters. Most
    holds want a pull down and forgive a lot; a pocket takes almost any pull; a flake wants
    a pull towards its crack, an undercling a pull up, a sloper a pull straight down.
    Returns (dx, dy, strict): the pull direction and how strict the hold is (0 to 1)."""
    S = SPEC
    dx = np.zeros((H, W))
    dy = np.ones((H, W))
    strict = np.full((H, W), 0.5)
    for x, y, r, d in S["pockets"]:
        strict[blob(x, y, r * 2.2, r * 1.8) > 0.3] = 0.25
    for x, y, rx, ry, d in S.get("big_slopers", []):
        m = blob(x, y, rx, ry) > 0.2
        dx[m], dy[m], strict[m] = 0, 1, 1.0
    for ux, uy, uw in S.get("underclings", []):
        edge = _under_edge(uy)
        m = (np.abs(xs - ux) < uw) & (ys > edge - 4) & (ys < edge + 7)
        dx[m], dy[m], strict[m] = 0, -1, 0.85
    for lx, y0, y1, side in S.get("flakes", []):
        lip = _flake_lip(lx)
        m = (np.abs(xs - lip) < 5) & (ys > y0) & (ys < y1)
        dx[m], dy[m], strict[m] = side, 0, 0.85
    return dx, dy, strict


configure("marierose")

SUN = [-0.35, -0.7, 0.62]  # x, y on screen, z out of the rock towards you


def lighting(hm):
    gy, gx = np.gradient(hm)
    n = np.dstack([-gx, -gy, np.ones_like(hm)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    sun = np.array(SUN, float)
    sun /= np.linalg.norm(sun)
    direct = np.clip((n * sun).sum(axis=2), 0, 1) * 0.62 / max(sun[2], 0.3)  # flat rock stays as bright
    # Cast shadow: march towards the sun; a higher spot in the way blocks the light.
    shadow = np.zeros_like(hm)
    flat = math.hypot(sun[0], sun[1])
    steps = int(4 + 6 * flat)  # a low sun throws longer shadows
    for k in range(1, steps):
        dy, dx = int(round(sun[1] / flat * k)), int(round(sun[0] / flat * k))
        shifted = np.roll(np.roll(hm, -dy, 0), -dx, 1)
        shadow = np.maximum(shadow, (shifted - hm - k * sun[2] / flat * 1.2) > 0)
    # Cavities stay dark: anything lower than its surroundings.
    k = np.exp(-(np.arange(-10, 11) / 4.0) ** 2 / 2)
    k /= k.sum()
    blur = np.apply_along_axis(lambda r: np.convolve(r, k, "same"), 1, hm)
    blur = np.apply_along_axis(lambda c: np.convolve(c, k, "same"), 0, blur)
    cavity = np.clip((blur - hm) / 2.5, 0, 1)
    return direct * (1 - 0.75 * shadow) - 0.35 * cavity


def grip_map(hm):
    """What the hand finds: a rim to pull down on, with a drop below it."""
    gy, _ = np.gradient(hm)
    below = np.roll(gy, -2, 0)
    rim = np.clip(-below, 0, None) * np.clip(1 - np.abs(gy) * 0.8, 0, 1)
    return np.clip(rim / 2.0, 0, 1) * INSIDE


def _blur(a, sigma):
    k = np.exp(-(np.arange(-3 * int(sigma), 3 * int(sigma) + 1) / sigma) ** 2 / 2)
    k /= k.sum()
    a = np.apply_along_axis(lambda r: np.convolve(r, k, "same"), 1, a)
    return np.apply_along_axis(lambda c: np.convolve(c, k, "same"), 0, a)


def hand_map(hm):
    """How well a hand holds, 0 to 1. Best on a deep rim or in a pocket; around it the
    grip runs out, so you can still take the edge of a hold, it just costs more."""
    gy, _ = np.gradient(hm)
    rim = np.clip(-np.roll(gy, -2, 0), 0, None) * np.clip(1 - np.abs(gy) * 0.8, 0, 1) / 1.5
    cavity = np.clip((_blur(hm, 3) - hm) / 3.0, 0, 1)
    up = np.clip(gy - _blur(gy, 6), 0, None) * 0.3  # the top of a bulge: a sloper, at best so-so
    raw = np.clip(np.maximum(rim, cavity * 0.9) + up, 0, 1)
    spread = _blur(raw, 2.5) * 1.4
    grip = np.clip(np.maximum(raw, spread), 0, 1)
    # Your fingers curl over a rim into the dark groove below it: the groove you see holds
    # as well as the rim, fading out a few pixels further down.
    groove = grip.copy()
    for k in range(1, 5):
        groove = np.maximum(groove, np.roll(grip, k, 0) * (1 - 0.06 * k))
    out = np.clip(groove ** 0.85, 0, 1) * INSIDE
    # A big sloper holds fairly, over its whole lower half, if you pull it straight down with
    # a long arm (the direction map and the game decide that).
    for x, y, rx, ry, d in SPEC.get("big_slopers", []):
        b = blob(x, y, rx, ry) * (ys > y - ry * 0.4)
        out = np.maximum(out, 0.62 * np.clip((b - 0.3) / 0.35, 0, 1) ** 0.5 * INSIDE)
    # The top lip: over the top edge you can always grab the block and mantle up.
    below = INSIDE.copy()
    for k in range(1, 7):
        below &= np.roll(INSIDE, k, 0)
    lip = INSIDE & ~below
    return np.where(lip, np.maximum(out, 0.62), out)


def foot_map(hm):
    """How well a foot stands, 0 to 1. Anything facing up takes a foot, bare rock still
    lets you smear, and only the undercut below a rim is no good."""
    gy, _ = np.gradient(hm)
    up = np.clip(gy * 0.6, 0, 1)
    rim = np.clip(-np.roll(gy, -2, 0) / 2.0, 0, 1)
    under = np.clip(-gy * 0.5, 0, 1)
    q = 0.35 + 0.65 * np.clip(_blur(np.maximum(up, rim), 1.2) * 1.6, 0, 1) - 0.3 * under
    return np.clip(q, 0, 1) * INSIDE


HEAT = [(0.0, (60, 40, 60)), (0.15, (150, 40, 50)), (0.4, (225, 110, 40)), (0.7, (250, 200, 70)), (1.0, (255, 250, 210))]
COOL = [(0.0, (60, 40, 60)), (0.3, (50, 70, 120)), (0.5, (50, 120, 150)), (0.75, (90, 190, 140)), (1.0, (220, 250, 200))]


def ramp(v, stops):
    out = np.zeros(v.shape + (3,))
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        m = (v >= a) & (v <= b)
        f = ((v[m] - a) / (b - a))[:, None]
        out[m] = np.array(ca) * (1 - f) + np.array(cb) * f
    return out


def heat(kind):
    hm = height_map()
    img = np.array(render(FONT, background=True), float)
    grey = img.mean(axis=2, keepdims=True)
    img = img * 0.2 + grey * 0.3
    q = hand_map(hm) if kind == "hand" else foot_map(hm)
    col = ramp(q, HEAT if kind == "hand" else COOL)
    alpha = np.clip(q * 3, 0, 0.92)[..., None] if kind == "hand" else np.full(q.shape + (1,), 0.85)
    img[INSIDE] = (img * (1 - alpha) + col * alpha)[INSIDE]
    return Image.fromarray(img.clip(0, 255).astype(np.uint8))


# Cool shadow, warm light: three to four flat tones, a fourth for deep shade.
FONT = [(58, 52, 66), (98, 92, 104), (150, 136, 124), (196, 178, 150), (226, 212, 182)]
GREY = [(38, 32, 38), (66, 58, 66), (98, 90, 96), (134, 126, 130), (170, 162, 164)]


def tones(light, levels=(0.18, 0.42, 0.66, 0.84)):
    t = np.zeros(light.shape, int)
    for i, lv in enumerate(levels):
        t += light > lv
    return t


def backdrop(img):
    sky_top, sky_low = np.array([206, 222, 214]), np.array([168, 190, 176])
    img[:] = sky_top * (1 - ys / H)[..., None] + sky_low * (ys / H)[..., None]
    # Layers of forest, paler with distance, a few trunks in each.
    layers = [((176, 196, 184), 150, 34, 81, 2, 9), ((140, 166, 146), 175, 28, 82, 3, 6), ((96, 124, 100), 205, 22, 83, 5, 4)]
    for col, base, amp, seed, width, count in layers:
        r = np.random.default_rng(seed)
        trunk = np.array(col) * 0.78
        for x in r.integers(0, W, count):
            img[:FLOOR, x:x + width] = trunk
        crowns = base - 90 - amp * (0.5 + 0.5 * noise(16, seed + 5))
        img[ys < crowns - 40 + 0 * xs] = img[ys < crowns - 40 + 0 * xs]
        edge = base - amp * (0.5 + 0.5 * noise(14, seed)) - 6 * np.abs(np.sin(xs / 7.0 + seed))
        img[ys > edge] = col
    img[ys > FLOOR - 5 + 3 * np.sin(xs / 5.0)] = (104, 134, 80)


def overhang_light(rock, hm):
    """Under a roof the sun does not reach the face: it is in shade, only the tops of the
    rims catch light, and warm light bounces up from the sand. The roof edge is bright."""
    gy, _ = np.gradient(hm)
    tops = np.clip(gy * 0.9, 0, 1)                                   # surfaces facing up
    depth = np.clip((ys - top) / (FLOOR - top + 1), 0, 1)           # 0 at the roof, 1 at the foot
    shade = np.round((0.5 + 0.12 * depth + 0.38 * tops) * 8) / 8  # in steps, like the rest
    bounce = (np.round(np.clip((ys - (FLOOR - 70)) / 70, 0, 1) * 3) / 3)[..., None] * np.array([34, 22, 6])
    out = rock * shade[..., None] + bounce
    out = out * np.array([0.92, 0.9, 1.04]) + np.array([4, 0, 14])  # shade leans to purple
    roof = (ys - top < 9) & (ys - top >= 0)
    lit = rock * 1.08 + np.array([10, 8, 0])
    out[roof] = lit[roof]
    out[(ys - top >= 9) & (ys - top < 12)] *= 0.55                   # the dark line under the edge
    return np.clip(out, 0, 255)


def backdrop_shadow(img):
    """The pool of shade on the sand under the roof: an oval, dithered at its edge."""
    d = ((xs - CX) / (HW + 26)) ** 2 + ((ys - FLOOR - 1) / 7.0) ** 2
    dither = ((xs + ys) % 2) * 0.15
    img[(d < 0.85 + dither) & (ys > FLOOR - 12)] *= 0.7


def side_view(palette, sun_left=True):
    """The block seen from the side, its face to the left: how much it leans out over you
    (or back, on a slab) shows at a glance. Shown for a moment before you climb."""
    img = np.zeros((H, W, 3))
    backdrop(img)
    rows = np.nonzero(INSIDE.any(axis=1))[0]
    height = FLOOR - rows.min()
    lean = math.radians(SPEC.get("lean", 0))
    depth = height * 0.62
    v = (FLOOR - ys).astype(float)
    fx = W / 2 - depth / 2 + height * math.tan(lean) / 2   # the foot of the face
    t = np.clip(v / height, 0, 1)
    front = fx - v * math.tan(lean) - 5 * np.sin(t * math.pi)    # the face leans, a little round
    back = fx + depth + 14 * np.sin(t * math.pi) - v * math.tan(lean) * 0.35
    u = (xs - (front + back) / 2) / ((back - front) / 2 + 1e-6)
    crown = height - 16 + 16 * np.clip(1 - u ** 2, 0, 1) ** 0.5  # a round top
    inside = (xs > front) & (xs < back) & (v >= 0) & (v < crown) & (ys <= FLOOR)
    pal = np.array(palette, float)
    tone = np.full(ys.shape, 2)
    near_top = inside & ~np.roll(inside, 6, 0)
    tone[near_top] = 4                                            # the sun on the top
    face = inside & ~np.roll(inside, -8, 1) & ~near_top            # the face, a few pixels deep
    tone[face] = 1 if lean > 0.15 else 3                          # in shade under an overhang
    if lean > 0.15:
        dim = inside & ~near_top & (u < -0.15 + 0.08 * np.sin(ys / 9.0))
        tone[dim & (tone == 2)] = 1                                # the underside is in shade
    tone[inside & ~np.roll(inside, 4, 1) & ~near_top] = 3          # the far side catches light
    strata = inside & (((ys + (xs - W / 2) * 0.08).astype(int) % 26) == 0) & (noise(8, 120) > 0.35)
    tone[strata] = np.maximum(tone[strata] - 1, 0)
    rock = pal[tone]
    speck = inside & (noise(2, 121) > 0.8)
    rock[speck] = rock[speck] * 0.9
    img[inside] = rock[inside]
    # its shadow on the sand, under the overhang
    under = (ys > FLOOR - 3) & (ys <= FLOOR + 4) & (xs > front[FLOOR] - 30 - height * max(math.tan(lean), 0) * 0.8) & (xs < back[FLOOR] + 8)
    img[under] *= 0.75
    edge = inside & ~(np.roll(inside, 1, 0) & np.roll(inside, -1, 0) & np.roll(inside, 1, 1) & np.roll(inside, -1, 1))
    img[edge] = (43, 35, 41)
    img[FLOOR + 1:] = (226, 211, 174)
    return Image.fromarray(img.clip(0, 255).astype(np.uint8))


def render(palette, ink=False, background=False, show_grip=False):
    hm = height_map()
    light = lighting(hm)
    t = tones(light)
    img = np.zeros((H, W, 3))
    img[:] = (43, 35, 41)
    if background:
        backdrop(img)
    pal = np.array(palette, float)
    rock = pal[t]
    # Lichen and dark water streaks: Font blocks are never one colour.
    streak = (noise(5, 90) * 0.6 + noise(20, 91)) > 0.75
    streak &= ((xs // 3 + (ys // 9)) % 7 < 5)
    rock[streak] = rock[streak] * 0.82
    for x, y, rx, ry, d in SPEC.get("big_slopers", []):
        worn = streak & ((((xs - x) / rx) ** 2 + ((ys - y) / ry) ** 2) < 0.9)
        rock[worn] = pal[t][worn]  # worn smooth by hands: no streaks on a big sloper
    moss = (noise(9, 92) + 0.5 * noise(3, 93) > 0.6) & ((ys > 215) | (np.abs(xs - CX) > HW - 19))
    rock[moss] = rock[moss] * 0.5 + np.array([104, 124, 72]) * 0.5
    if SPEC.get("chalk", 0.0) > 0.0:
        # Popular easy problems are chalked: white smudges on the holds everyone takes.
        g = hand_map(hm)
        smudge = (g > 0.62) & (noise(2, 95) + 0.6 * noise(5, 96) > 0.9 - SPEC["chalk"])
        rock[smudge] = rock[smudge] * 0.45 + np.array([244, 240, 230]) * 0.55
    if SPEC.get("overhang"):
        rock = overhang_light(rock, hm)
        backdrop_shadow(img)
    img[INSIDE] = rock[INSIDE]
    if ink:
        ink_lines(img, hm, t)
    img[FLOOR + 1:] = (226, 211, 174) if background else (31, 26, 29)
    if background:  # the block sits in the sand
        contact = (ys > FLOOR) & (ys < FLOOR + 5) & (np.abs(xs - CX) < HW + 18 - (ys - FLOOR) * 2)
        img[contact] = (196, 178, 140)
    if show_grip:
        g = grip_map(hm)
        grey = img.mean(axis=2, keepdims=True)
        img[:] = img * 0.25 + grey * 0.35  # dim the picture, then light up what holds
        on = g > 0.22
        q = np.clip((g[on, None] - 0.22) * 2.0, 0, 1)
        img[on] = np.array([200, 90, 60]) * (1 - q) + np.array([255, 236, 120]) * q
    return Image.fromarray(img.clip(0, 255).astype(np.uint8))


def ink_lines(img, hm, t):
    """Comic-style ink: the silhouette, and lines where the rock turns sharply away."""
    ink = np.array((30, 24, 30), float)
    solid = INSIDE & ~(np.roll(INSIDE, 1, 0) & np.roll(INSIDE, -1, 0) & np.roll(INSIDE, 1, 1) & np.roll(INSIDE, -1, 1))
    gy, gx = np.gradient(hm)
    crease = (np.roll(t, -1, 0) - t <= -2) | (np.abs(gy) > 1.7)
    crease &= INSIDE
    img[crease] = ink
    # Hatching in the deepest shadow only.
    hatch = (t == 0) & (((xs + ys) % 4) == 0) & INSIDE
    img[hatch] = ink
    img[solid] = ink


def up(im, s=3):
    return im.resize((im.width * s, im.height * s), Image.NEAREST)


if __name__ == "__main__":
    up(render(FONT, background=True)).save(f"{OUT}/5-vormen-cairn.png")
    up(render(FONT, ink=True, background=True)).save(f"{OUT}/6-vormen-inkt.png")
    up(render(GREY)).save(f"{OUT}/7-vormen-grijs.png")
    up(render(FONT, background=True, show_grip=True)).save(f"{OUT}/8-greepkaart.png")
    up(heat("hand")).save(f"{OUT}/9-heatmap-handen.png")
    up(heat("foot")).save(f"{OUT}/10-heatmap-voeten.png")
