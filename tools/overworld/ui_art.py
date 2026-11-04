"""Pixel art for the interface of the walking world, at the 480 x 270 scale of the UI:

- frame.png     a 16 x 16 nine-slice window: a dark outer line, a gold line, a dark gap and
                a thin inner gold line, small gold studs in the corners, a dark translucent fill
- plate.png     a 12 x 12 nine-slice name plate: one gold line, a warmer fill
- ornament.png  a 40 x 7 line for beside a title: a gold line that runs out, with a diamond

    python3 tools/overworld/ui_art.py assets/ui
"""
import os
import sys
import numpy as np
from PIL import Image

INK = (24, 18, 28)
GOLD = (222, 186, 110)
GOLD_LIGHT = (250, 228, 168)
GOLD_DARK = (150, 116, 66)
FILL = (24, 18, 28, 232)
PLATE = (52, 34, 40, 240)


def frame():
    a = np.zeros((16, 16, 4), np.uint8)
    a[:, :] = FILL
    for d, c in [(0, INK), (1, GOLD), (2, INK), (3, GOLD_DARK)]:
        a[d, d:16 - d, :3] = c; a[15 - d, d:16 - d, :3] = c
        a[d:16 - d, d, :3] = c; a[d:16 - d, 15 - d, :3] = c
        a[d, d:16 - d, 3] = 255; a[15 - d, d:16 - d, 3] = 255
        a[d:16 - d, d, 3] = 255; a[d:16 - d, 15 - d, 3] = 255
    a[1, 2:14, :3] = GOLD_LIGHT                    # light along the top
    for y, x in [(1, 1), (1, 14), (14, 1), (14, 14)]:   # a stud in each corner
        a[y - 1:y + 2, x - 1:x + 2] = (*GOLD, 255)
        a[y, x] = (*GOLD_LIGHT, 255)
    for y, x in [(0, 0), (0, 15), (15, 0), (15, 15)]:
        a[y, x, 3] = 0
    return a


def plate():
    a = np.zeros((12, 12, 4), np.uint8)
    a[:, :] = PLATE
    for d, c in [(0, INK), (1, GOLD)]:
        a[d, d:12 - d] = (*c, 255); a[11 - d, d:12 - d] = (*c, 255)
        a[d:12 - d, d] = (*c, 255); a[d:12 - d, 11 - d] = (*c, 255)
    a[1, 2:10, :3] = GOLD_LIGHT
    for y, x in [(0, 0), (0, 11), (11, 0), (11, 11)]:
        a[y, x, 3] = 0
    return a


def ornament():
    """Beside a title, pointing away from it (this one goes left of the title; mirror it)."""
    a = np.zeros((7, 40, 4), np.uint8)
    for x in range(0, 33):
        fade = x / 33.0                             # runs out towards the far end
        if fade > 0.15 or x % 2 == 0:
            a[3, x] = (*GOLD, int(255 * min(1.0, 0.25 + fade)))
    a[2, 20:33] = (*GOLD_DARK, 160)
    cx = 36                                          # the diamond next to the title
    for dy in range(-3, 4):
        w = 3 - abs(dy)
        a[3 + dy, cx - w:cx + w + 1] = (*GOLD, 255)
    a[1, cx] = (*GOLD_LIGHT, 255); a[2, cx - 1:cx + 1] = (*GOLD_LIGHT, 255)
    return a


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/ui"
    os.makedirs(out, exist_ok=True)
    for name, img in [("frame", frame()), ("plate", plate()), ("ornament", ornament())]:
        Image.fromarray(img, "RGBA").save(f"{out}/{name}.png")
    print("wrote", out)
