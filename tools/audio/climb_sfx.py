"""Soft, natural sounds for climbing and falling off a boulder, made from filtered noise: a
hand that scrapes off the rock, the air as you drop, the dull thud on the crash pad, the
sound a hand makes on a good or a poor hold, your breath, and your shoes on rock and sand.

    python3 tools/audio/climb_sfx.py assets/climb/sfx
"""
import sys
import wave
import numpy as np
from scipy.signal import butter, sosfilt

RATE = 22050
rng = np.random.default_rng(7)


def band(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], "bandpass", fs=RATE, output="sos"), x)


def low(x, f):
    return sosfilt(butter(2, f, "lowpass", fs=RATE, output="sos"), x)


def env(n, attack, decay_pow=1.0):
    t = np.linspace(0, 1, n)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * (1 - t) ** decay_pow


def scrape():
    """Fingers sliding off sandstone: grit, a few crackles, fading."""
    n = int(0.32 * RATE)
    grit = band(rng.normal(size=n), 1800, 5200)
    crackle = (rng.random(n) > 0.994) * rng.normal(size=n) * 6
    sand = band(crackle, 900, 4000)
    return (grit * 0.6 + sand) * env(n, 0.05, 1.6)


def whoosh():
    """The air going past as you drop: noise that rises and falls, its pitch sliding down."""
    n = int(0.7 * RATE)
    noise = rng.normal(size=n)
    out = np.zeros(n)
    step = 512
    for k in range(0, n, step):
        f = 900 - 500 * k / n
        seg = band(noise[max(0, k - 2048):k + step], f * 0.6, f * 1.6)[-min(step, n - k):]
        out[k:k + len(seg)] = seg
    t = np.linspace(0, 1, n)
    return out * np.sin(np.pi * t) ** 1.5 * 0.9


def thud():
    """Landing on a crash pad: a low, soft boom, the foam puffing out air, a hiss of sand."""
    n = int(0.55 * RATE)
    t = np.arange(n) / RATE
    boom = np.sin(2 * np.pi * (62 - 30 * t) * t) * np.exp(-t * 14)
    puff = low(rng.normal(size=n), 420) * np.exp(-t * 9) * 2.2
    sand = band(rng.normal(size=n), 2500, 7000) * np.exp(-t * 6) * 0.12
    return boom * 1.1 + puff + sand


def slap():
    """A chalky hand slapping onto a jug: a short, dry knock."""
    n = int(0.18 * RATE)
    t = np.arange(n) / RATE
    knock = band(rng.normal(size=n), 300, 1400) * np.exp(-t * 45)
    dust = band(rng.normal(size=n), 3000, 8000) * np.exp(-t * 25) * 0.25
    low_k = np.sin(2 * np.pi * 140 * t) * np.exp(-t * 40) * 0.6
    return knock + dust + low_k


def grip_good():
    """Fingers closing on a good edge: a short, dry tick of chalky skin on sandstone."""
    n = int(0.09 * RATE)
    t = np.arange(n) / RATE
    tick = band(rng.normal(size=n), 1400, 4800) * np.exp(-t * 80)
    knock = np.sin(2 * np.pi * 260 * t) * np.exp(-t * 60) * 0.7
    return tick * 0.8 + knock


def grip_poor():
    """A hand on a poor spot: a soft rub of skin over grit, no click at all."""
    n = int(0.24 * RATE)
    rub = band(rng.normal(size=n), 700, 2600)
    grain = band((rng.random(n) > 0.985) * rng.normal(size=n) * 3, 1500, 5000)
    return (rub * 0.7 + grain * 0.5) * env(n, 0.3, 1.5)


def breath():
    """One tired breath out: air through the mouth, soft, a little voiced."""
    n = int(0.5 * RATE)
    t = np.arange(n) / RATE
    air = band(rng.normal(size=n), 350, 1800)
    voice = np.sin(2 * np.pi * 140 * t) * 0.08
    return (air + voice) * env(n, 0.18, 1.8)


def effort():
    """A short, sharp breath out as you push off: hff."""
    n = int(0.22 * RATE)
    return band(rng.normal(size=n), 500, 2800) * env(n, 0.04, 2.2)


def step_rock():
    """Climbing-shoe rubber on sandstone: a short scuff and a soft knock."""
    n = int(0.12 * RATE)
    t = np.arange(n) / RATE
    scuff = band(rng.normal(size=n), 900, 3500) * np.exp(-t * 45)
    knock = np.sin(2 * np.pi * 180 * t) * np.exp(-t * 50) * 0.5
    return scuff * 0.7 + knock


def step_sand():
    """A shoe back on the sand: a soft crunch."""
    n = int(0.16 * RATE)
    t = np.arange(n) / RATE
    grains = band((rng.random(n) > 0.96) * rng.normal(size=n) * 3, 2000, 6500) * np.exp(-t * 20)
    thump = low(rng.normal(size=n), 300) * np.exp(-t * 30)
    return grains + thump * 1.5


def write(path, x, gain=0.7):
    x = x / (np.abs(x).max() + 1e-9) * gain
    fade = min(200, len(x))
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    out = sys.argv[1]
    write(f"{out}/scrape.wav", scrape(), 0.5)
    write(f"{out}/whoosh.wav", whoosh(), 0.35)
    write(f"{out}/thud.wav", thud(), 0.8)
    write(f"{out}/slap.wav", slap(), 0.7)
    # added later: written after the others so their random noise stays the same
    write(f"{out}/grip_good.wav", grip_good(), 0.55)
    write(f"{out}/grip_poor.wav", grip_poor(), 0.4)
    write(f"{out}/breath.wav", breath(), 0.35)
    write(f"{out}/effort.wav", effort(), 0.4)
    write(f"{out}/step_rock.wav", step_rock(), 0.4)
    write(f"{out}/step_sand.wav", step_sand(), 0.35)
    print("wrote", out)
