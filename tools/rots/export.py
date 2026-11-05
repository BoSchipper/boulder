"""Writes the boulder for the climbing test: the picture at four times of day, and the
two grip maps the game reads (how well a hand or a foot holds at each pixel), and
the outline of the block.

    python3 tools/rots/export.py assets/climb [block ...]

Every block gets its own folder, with route.json for its name, grade and how steep it is.
"""
import json
import os
import sys
import numpy as np
from PIL import Image
import rock_forms as rf

# Must match TIMES in scripts/movetest/test_cairn.gd: sun (x, y on screen, z towards
# you), light colour (multiply) and shade colour (added to the dark parts).
TIMES = {
    "ochtend": ([0.5, -0.55, 0.6], [0.94, 0.98, 1.06], [0, 6, 24]),
    "middag": ([-0.35, -0.7, 0.62], [1.0, 1.0, 1.0], [0, 0, 0]),
    "avond": ([-0.8, -0.32, 0.42], [1.14, 0.95, 0.8], [12, 0, 30]),
    "schemering": ([-0.25, -0.5, 0.85], [0.72, 0.74, 0.92], [16, 10, 42]),
}


def grade(im, mul, add):
    x = np.array(im).astype(float)
    if mul != [1.0, 1.0, 1.0]:
        lum = x.mean(axis=2, keepdims=True) / 255
        x = x * (0.8 + 0.2 * lum) * np.array(mul) + (1 - lum) * np.array(add)
    return Image.fromarray(x.clip(0, 255).astype(np.uint8))


def front_tufts(out):
    """Grass tufts in the bottom corners of the climbing screen, close to the camera and so
    out of focus: blurred once here. Shared by every block."""
    from PIL import ImageDraw, ImageFilter
    layer = Image.new("RGBA", (rf.W, rf.H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = np.random.default_rng(9)
    for cx in list(r.uniform(-10, 80, 9)) + list(r.uniform(400, 490, 9)):
        base = rf.H + 6
        for k in range(5):
            a = r.uniform(-0.6, 0.6)
            ln = r.uniform(18, 40)
            tip = (cx + np.sin(a) * ln, base - np.cos(a) * ln)
            col = (int(r.uniform(40, 70)), int(r.uniform(80, 110)), int(r.uniform(40, 60)), 255)
            d.polygon([(cx - 4, base), (cx + 4, base), tip], fill=col)
    layer.filter(ImageFilter.GaussianBlur(2.2)).save(f"{out}/front_tufts.png")


def main(out, names):
    front_tufts(out)
    for name in names:
        rf.configure(name)
        d = f"{out}/{name}"
        os.makedirs(d, exist_ok=True)
        for t, (sun, mul, add) in TIMES.items():
            rf.SUN = sun
            grade(rf.render(rf.FONT, background=True), mul, add).save(f"{d}/rock_{t}.png")
        grade(rf.side_view(rf.FONT), *TIMES["avond"][1:]).save(f"{d}/side.png")
        hm = rf.height_map()
        for kind, m in (("hand", rf.hand_map(hm)), ("foot", rf.foot_map(hm))):
            Image.fromarray((m * 255).clip(0, 255).astype(np.uint8), "L").save(f"{d}/{kind}_map.png")
        # The outline of the block: off the rock there is nothing to hold or stand on.
        Image.fromarray((rf.INSIDE * 255).astype(np.uint8), "L").save(f"{d}/rock_mask.png")
        rows = np.nonzero(rf.INSIDE.any(axis=1))[0]
        cols = np.nonzero(rf.INSIDE.any(axis=0))[0]
        S = rf.SPEC
        route = {"title": S["title"], "grade": S["grade"], "feet_max": S["feet_max"],
                 "top_y": int(rows.min()) + 10, "left": int(cols.min()), "right": int(cols.max()),
                 "high": int(rows.min()), "floor": rf.FLOOR,
                 "lean": S.get("lean", 0)}
        if S.get("directional"):
            # Which way each hold wants to be pulled (red, green) and how strict it is (blue).
            dx, dy, strict = rf.dir_map()
            rgb = np.dstack([dx * 0.5 + 0.5, dy * 0.5 + 0.5, strict])
            Image.fromarray((rgb * 255).round().clip(0, 255).astype(np.uint8), "RGB").save(f"{d}/dir_map.png")
            route["directional"] = True
        if S.get("tip"):
            route["tip"] = S["tip"]  # told the first time you climb it
        with open(f"{d}/route.json", "w") as f:
            json.dump(route, f)
        print("wrote", d, route)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:] or list(rf.SPECS))
