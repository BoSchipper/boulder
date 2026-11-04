"""JRPG-style transition from the walking world to the climbing screen, as stills."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy.ndimage import map_coordinates

FONT = "/Users/prive/boulder/assets/fonts/kenney_kenney-fonts/Fonts/Kenney Pixel.ttf"
W, H = 960, 540
ow_ui = np.array(Image.open("ow_avond.png").convert("RGB")).astype(float) / 255
ow = np.array(Image.open("ow_avond_noui.png").convert("RGB")).astype(float) / 255
climb_src = Image.open("godot_1.png").convert("RGB")
bg = Image.open("/Users/prive/boulder/assets/climb/marierose/rock_avond.png").convert("RGB")
climb_src.paste(bg.crop((0, 0, 480, 22)), (0, 0))
climb_src = climb_src.crop((0, 0, 480, 270)).resize((W, H), Image.NEAREST)
climb = np.array(climb_src).astype(float) / 255
CX, CY = 516, 200  # the block you walk up to
yy, xx = np.mgrid[0:H, 0:W]


def zoom_blur(img, strength, scale):
    out = np.zeros_like(img)
    n = 12
    for k in range(n):
        s = scale * (1 - strength * k / n)
        y = CY + (yy - CY) * s
        x = CX + (xx - CX) * s
        for c in range(3):
            out[..., c] += map_coordinates(img[..., c], [y, x], order=1, mode="nearest")
    return out / n


def save(a, name):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(name)


# 1: you press A, the world holds its breath: the edges darken, the block glows.
f1 = ow_ui.copy()
v = np.hypot((xx - CX) / W, (yy - CY) / H)
f1 *= (1 - 0.6 * np.clip(v * 1.6, 0, 1))[..., None]
f1 += np.exp(-v ** 2 / 0.006)[..., None] * np.array([0.25, 0.18, 0.08])
save(f1, "tr_1.png")

# 2: the camera rushes into the block.
f2 = zoom_blur(ow, 0.35, 0.55)
f2 *= (1 - 0.5 * np.clip(v * 1.4, 0, 1))[..., None]
save(f2, "tr_2.png")

# 3: a burst of chalk: the world breaks into tiles of dust, the rock shows through.
tile = 24
ty, tx = yy // tile, xx // tile
d_tile = np.hypot(tx * tile + tile / 2 - CX, ty * tile + tile / 2 - CY)
rnd = np.random.default_rng(2).random((H // tile + 1, W // tile + 1))[ty, tx]
t = 0.55  # how far the burst is
reveal = (d_tile / 700 + rnd * 0.25) < t
chalk = np.clip(1 - np.abs(d_tile / 700 + rnd * 0.25 - t) / 0.12, 0, 1)
inner = np.maximum(np.abs((xx % tile) - tile / 2), np.abs((yy % tile) - tile / 2)) < tile / 2 * (1 - chalk * 0.6)
f3 = np.where(reveal[..., None], climb, zoom_blur(ow, 0.4, 0.4))
dust = np.array([0.98, 0.96, 0.92])
f3 = np.where((chalk > 0.05)[..., None] & inner[..., None], f3 * (1 - chalk[..., None]) + dust * chalk[..., None], f3)
puff = np.random.default_rng(5)
for k in range(260):  # loose specks of chalk
    a = puff.uniform(0, 2 * np.pi); r = puff.uniform(200, 520)
    px, py = int(CX + np.cos(a) * r), int(CY + np.sin(a) * r * 0.7)
    s = puff.integers(2, 6)
    if 0 <= px < W - s and 0 <= py < H - s:
        f3[py:py + s, px:px + s] = dust
save(f3, "tr_3.png")

# 4: the climbing screen, with the name of the problem on a plate.
im = Image.fromarray((climb * 255).astype(np.uint8))
d = ImageDraw.Draw(im)
big = ImageFont.truetype(FONT, 48)
small = ImageFont.truetype(FONT, 16)
GOLD = (222, 186, 110)
x0, y0, w, h = W // 2 - 190, 70, 380, 84
d.rectangle([x0, y0, x0 + w, y0 + h], fill=(28, 22, 32))
d.rectangle([x0 + 3, y0 + 3, x0 + w - 3, y0 + h - 3], outline=GOLD)
for cx, cy in [(x0 + 3, y0 + 3), (x0 + w - 3, y0 + 3), (x0 + 3, y0 + h - 3), (x0 + w - 3, y0 + h - 3)]:
    d.rectangle([cx - 3, cy - 3, cx + 3, cy + 3], fill=(240, 210, 140))
tw = d.textlength("La Marie-Rose", font=big)
d.text((W // 2 - tw / 2, y0 + 4), "La Marie-Rose", font=big, fill=(250, 238, 214))
sub = "6a   ·   Bas Cuvier"
tw = d.textlength(sub, font=small)
d.text((W // 2 - tw / 2, y0 + 56), sub, font=small, fill=GOLD)
im.save("tr_4.png")

# The strip: four frames side by side, in two rows, numbered.
fr = [Image.open(f"tr_{k}.png") for k in range(1, 5)]
sheet = Image.new("RGB", (W * 2 + 30, H * 2 + 30), (20, 18, 24))
sd = ImageDraw.Draw(sheet)
for k, f in enumerate(fr):
    x, y = 10 + (k % 2) * (W + 10), 10 + (k // 2) * (H + 10)
    sheet.paste(f, (x, y))
    sd.rectangle([x + 8, y + H - 40, x + 40, y + H - 8], fill=(28, 22, 32))
    sd.text((x + 17, y + H - 42), str(k + 1), font=ImageFont.truetype(FONT, 32), fill=GOLD)
sheet = sheet.resize((sheet.width // 2 * 2 // 2, sheet.height // 2), Image.LANCZOS) if False else sheet
sheet.save("overgang_filmstrip.png")
print("ok")
