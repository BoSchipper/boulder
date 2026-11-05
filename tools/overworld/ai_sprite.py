"""Turns a sprite drawn by an image AI (ChatGPT and the like) into a real game sprite.

Such an image is pixel art only in looks: a 24 x 36 figure comes back as a 1024 x 1536
picture whose "pixels" are blocks of 19 to 22 screen pixels, not quite square, blurred by
compression, with hundreds of colours. This finds the block grid again, reads one colour
per block, keys out the flat magenta background, reduces the colours, scales the figure
to the game's height and draws a one-pixel outline round it. A sheet with several views
side by side comes back as one figure per view, left to right.

    python3 tools/overworld/ai_sprite.py <image> <out.png> [height]

writes the figures side by side at game size, plus <out>_x8.png to look at.
sprites_hd.py uses clean() and walk_frames() for the sources listed in its AI table.
"""
import sys
from collections import Counter
import numpy as np
from PIL import Image
from scipy.cluster.vq import kmeans2

MAGENTA = np.array([255.0, 0.0, 255.0])
OUTLINE = (40, 26, 38)  # the same dark plum as the drawn sprites


def _period(profile, lo=8.0, hi=48.0):
    """The block size along one axis: the strongest repeat in the edge profile. Of the
    near-equal peaks the largest wins, so a block is not mistaken for half a block."""
    p = profile - profile.mean()
    k = np.arange(len(p))
    sizes = np.arange(lo, hi, 0.05)
    power = np.array([abs((p * np.exp(2j * np.pi * k / s)).sum()) for s in sizes])
    peaks = [i for i in range(1, len(power) - 1) if power[i] >= power[i - 1] and power[i] >= power[i + 1]]
    best = max(power[i] for i in peaks)
    s = max(sizes[i] for i in peaks if power[i] >= 0.85 * best)
    c = (p * np.exp(2j * np.pi * k / s)).sum()
    return s, (-np.angle(c) / (2 * np.pi) * s) % s  # size, and where a block edge falls


def _grid(img):
    """One colour per block of the AI image, with alpha for the background."""
    a = np.asarray(img.convert("RGB")).astype(float)
    fg = np.abs(a - MAGENTA).sum(2) > 120
    ys, xs = np.where(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    part = a[y0:y1, x0:x1]
    sx, ox = _period(np.abs(np.diff(part, axis=1)).sum(2).sum(0))
    sy, oy = _period(np.abs(np.diff(part, axis=0)).sum(2).sum(1))
    ox, oy = x0 + ox + 0.5, y0 + oy + 0.5
    ox -= np.ceil((ox - 0) / sx) * sx  # start the grid before the figure
    oy -= np.ceil((oy - 0) / sy) * sy
    cols = np.arange(ox, a.shape[1], sx)
    rows = np.arange(oy, a.shape[0], sy)
    out = np.zeros((len(rows), len(cols), 4))
    for j, gy in enumerate(rows):
        for i, gx in enumerate(cols):
            # the middle of a block only: its edges are blurred into the neighbours
            cy0, cy1 = int(max(gy + sy * 0.3, 0)), int(min(gy + sy * 0.7, a.shape[0]))
            cx0, cx1 = int(max(gx + sx * 0.3, 0)), int(min(gx + sx * 0.7, a.shape[1]))
            if cy1 <= cy0 or cx1 <= cx0:
                continue
            mask = fg[cy0:cy1, cx0:cx1]
            if mask.mean() > 0.5:
                c = np.median(a[cy0:cy1, cx0:cx1][mask], 0)  # the figure's pixels only, not the background
                if c[1] < 0.25 * min(c[0], c[2]) and min(c[0], c[2]) > 90:
                    c = np.array(OUTLINE, float)  # outline blurred into the magenta: a pink speck otherwise
                out[j, i, :3] = c
                out[j, i, 3] = 255
    return out


def _figures(grid, min_gap=2):
    """Splits a sheet into its figures at empty columns, left to right."""
    used = grid[..., 3].max(0) > 0
    spans, start, gap = [], None, 0
    for x, u in enumerate(list(used) + [False] * min_gap):
        if u:
            start = x if start is None else start
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                spans.append((start, x - gap + 1))
                start = None
    figs = []
    for x0, x1 in spans:
        part = grid[:, x0:x1]
        rows = np.where(part[..., 3].max(1) > 0)[0]
        if len(rows) and (x1 - x0) * len(rows) > 40:  # skip specks
            figs.append(part[rows.min():rows.max() + 1])
    return figs


def _shrink(fig, h):
    """Scales a figure to h rows, each target pixel the most common colour under it."""
    H, W = fig.shape[:2]
    if H <= h:
        return fig
    w = max(1, round(W * h / H))
    out = np.zeros((h, w, 4))
    for j in range(h):
        for i in range(w):
            blk = fig[j * H // h:max((j + 1) * H // h, j * H // h + 1), i * W // w:max((i + 1) * W // w, i * W // w + 1)]
            out[j, i] = Counter(map(tuple, blk.reshape(-1, 4))).most_common(1)[0][0]
    return out


def _outline(fig):
    """Every pixel on the silhouette's edge becomes the outline colour."""
    a = fig[..., 3] > 0
    p = np.pad(a, 1)
    inner = p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    fig = fig.copy()
    fig[a & ~inner, :3] = OUTLINE
    return fig


def clean(path, height=36, colours=28, seed=3):
    """The figures in an AI image as RGBA uint8 arrays, height rows tall, left to right."""
    grid = _grid(Image.open(path))
    # one palette for all views of a sheet, so front, side and back share their colours
    on = grid[..., 3] > 0
    cent, lab = kmeans2(grid[on][:, :3], colours, minit="++", seed=seed)
    grid[on, :3] = np.round(cent[lab])
    return [_outline(_shrink(f, height)).astype(np.uint8) for f in _figures(grid)]


def _shade(px):
    """The far leg: darker and a little purple, like the shade tone of sprites_hd."""
    out = px.copy()
    on = (out[..., 3] > 0) & np.any(out[..., :3] != OUTLINE, -1)
    out[on, :3] = np.clip(out[on, :3] * 0.68 + np.array([10, 0, 22]), 0, 255)
    return out


def _move(px, dx, up):
    """px shifted dx pixels right and up pixels up, empty where it came from."""
    out = np.zeros_like(px)
    h, w = px.shape[:2]
    src = px[up:, max(-dx, 0):w - max(dx, 0)]
    out[:h - up, max(dx, 0):max(dx, 0) + src.shape[1]] = src
    return out


def walk_frames(fig, hip=0.72, side=False):
    """Stand, two steps and breathing in, made from one standing figure the way sprites_hd
    draws its own. On a step or a breath the upper body dips a pixel. From the front or
    the back one foot lifts two pixels; from the side the legs part, the near one lifted
    and the far one darker behind it. `hip` is where the legs start, as part of the height."""
    fig = np.pad(fig, ((0, 0), (2, 2), (0, 0)))  # room for a leg to swing out
    h, w = fig.shape[:2]
    hy = int(round(h * hip))
    feet = np.where(fig[-1, :, 3] > 0)[0]
    mid = (feet.min() + feet.max() + 1) // 2  # between the feet

    def legs_front(lift):
        legs = fig[hy:].copy()
        if lift is not None:  # this leg two pixels up, the foot off the ground
            cols = slice(0, mid) if lift == 0 else slice(mid, w)
            leg = legs[:, cols].copy()
            legs[:, cols] = 0
            legs[:-2, cols] = leg[2:]
        return legs

    def legs_side(lift):
        legs = fig[hy:]
        if lift is None:
            return legs.copy()
        dx = 2 if lift == 0 else -2
        out = _shade(_move(legs, -dx, 0))   # the far leg, on the ground behind
        near = _move(legs, dx, 2)            # the near leg, swung out and lifted
        on = near[..., 3] > 0
        out[on] = near[on]
        return out

    def frame(lift, bob):
        out = np.zeros_like(fig)
        out[hy:] = legs_side(lift) if side else legs_front(lift)
        body = np.zeros_like(fig)
        body[bob:hy + bob] = fig[:hy]
        on = body[..., 3] > 0
        out[on] = body[on]  # the upper body overlaps the top of the legs
        return _outline(out)

    return [fig.copy(), frame(0, 1), frame(1, 1), frame(None, 1)]


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    figs = clean(src, int(sys.argv[3]) if len(sys.argv) > 3 else 36)
    gap = 4
    h = max(f.shape[0] for f in figs)
    sheet = np.zeros((h, sum(f.shape[1] + gap for f in figs) - gap, 4), np.uint8)
    x = 0
    for f in figs:
        sheet[h - f.shape[0]:, x:x + f.shape[1]] = f
        print(f"figure {f.shape[1]} x {f.shape[0]}, {len({tuple(p) for p in f.reshape(-1, 4) if p[3]})} colours")
        x += f.shape[1] + gap
    im = Image.fromarray(sheet, "RGBA")
    im.save(dst)
    im.resize((im.width * 8, im.height * 8), Image.NEAREST).save(dst.rsplit(".", 1)[0] + "_x8.png")
