"""Trees you can walk around: smooth 3D shapes (distance fields) for the mockup renderer.
A spruce of stacked wavy tiers, a round broadleaf of bulging clumps, a tall Scots pine with
flat pads of needles, a birch. Each part has a material; the bumps make the clumps leafy."""
import numpy as np

BARK, PINEBARK, BIRCH, SPRUCE, OAK, PINE, BIRCHLEAF = 30, 31, 32, 34, 35, 36, 37
FOLIAGE = (SPRUCE, OAK, PINE, BIRCHLEAF)


def _bumps(p, f, seed):
    return (np.sin(p[:, 0] * f + seed) * np.sin(p[:, 1] * f * 1.31 + seed * 2.1) * np.sin(p[:, 2] * f * 0.87 + seed * 3.7)
            + 0.5 * np.sin(p[:, 0] * f * 2.3 + seed * 5) * np.sin(p[:, 2] * f * 2.1 + seed))


class Tree:
    def __init__(self):
        self.parts = []  # (kind, params, material, bump)
        self.lo = np.full(3, 1e9)
        self.hi = np.full(3, -1e9)

    def _box(self, lo, hi):
        self.lo = np.minimum(self.lo, lo - 1.5)
        self.hi = np.maximum(self.hi, hi + 1.5)

    def cyl(self, cx, cz, y0, y1, r0, r1, mat):
        self.parts.append(("cyl", (cx, cz, y0, y1, r0, r1), mat, 0))
        r = max(r0, r1)
        self._box(np.array([cx - r, y0, cz - r]), np.array([cx + r, y1, cz + r]))

    def ell(self, c, r, mat, bump=0.7):
        self.parts.append(("ell", (np.array(c, float), np.array(r, float)), mat, bump))
        self._box(np.array(c) - r, np.array(c) + r)

    def cone(self, cx, cz, y0, ht, R, mat, seed, bump=0.6):
        self.parts.append(("cone", (cx, cz, y0, ht, R, seed), mat, bump))
        self._box(np.array([cx - R * 1.2, y0 - 1, cz - R * 1.2]), np.array([cx + R * 1.2, y0 + ht, cz + R * 1.2]))

    def sdf(self, p):
        best = np.full(len(p), 1e9)
        mat = np.zeros(len(p), int)
        for kind, prm, m, bump in self.parts:
            if kind == "cyl":
                cx, cz, y0, y1, r0, r1 = prm
                rho = np.hypot(p[:, 0] - cx, p[:, 2] - cz)
                t = np.clip((p[:, 1] - y0) / (y1 - y0), 0, 1)
                d = np.maximum(np.maximum(rho - (r0 + (r1 - r0) * t), y0 - p[:, 1]), p[:, 1] - y1)
            elif kind == "ell":
                c, r = prm
                k = np.linalg.norm((p - c) / r, axis=1)
                d = (k - 1) * r.min()
            else:
                cx, cz, y0, ht, R, seed = prm
                dx, dz = p[:, 0] - cx, p[:, 2] - cz
                rho = np.hypot(dx, dz)
                th = np.arctan2(dz, dx)
                Rw = R * (1 + 0.13 * np.sin(7 * th + seed) + 0.06 * np.sin(13 * th + 2 * seed))
                yy = p[:, 1] - y0
                droop = 0.32 * rho  # the underside of a tier hangs down at the tips
                d = np.maximum(np.maximum((rho - Rw * (1 - yy / ht)) / np.sqrt(1 + (R / ht) ** 2), -(yy + droop)), yy - ht)
            if bump:
                d = d - bump * _bumps(p, 0.85, len(self.parts) * 0.7 + (seed if kind == "cone" else 0))
            closer = d < best
            best = np.where(closer, d, best)
            mat = np.where(closer, m, mat)
        return best, mat


def spruce(x, z, g, h, seed):
    t = Tree()
    t.cyl(x, z, g - 1, g + h * 0.95, 1.1, 0.35, BARK)
    for i in range(7):  # separate tiers, each a wavy skirt that droops at the tips
        t.cone(x, z, g + h * (0.12 + 0.118 * i), h * 0.21, h * (0.3 - 0.037 * i), SPRUCE, seed + i, 0.45)
    return t


def broadleaf(x, z, g, h, seed):
    r = np.random.default_rng(seed)
    t = Tree()
    t.cyl(x, z, g - 1, g + h * 0.62, 1.7, 1.0, BARK)
    t.cyl(x + 2, z, g + h * 0.4, g + h * 0.7, 0.8, 0.5, BARK)
    c = np.array([x, g + h * 0.7, z])
    t.ell(c, [h * 0.26, h * 0.22, h * 0.26], OAK, 1.0)
    for k in range(7):
        a = r.uniform(0, 2 * np.pi)
        off = np.array([np.cos(a) * h * 0.2, r.uniform(-0.08, 0.16) * h, np.sin(a) * h * 0.2])
        rr = h * r.uniform(0.14, 0.2)
        t.ell(c + off, [rr, rr * 0.85, rr], OAK, 0.9)
    return t


def scots_pine(x, z, g, h, seed):
    r = np.random.default_rng(seed)
    t = Tree()
    t.cyl(x, z, g - 1, g + h * 0.5, 1.5, 1.1, BARK)
    t.cyl(x, z, g + h * 0.5, g + h * 0.93, 1.1, 0.6, PINEBARK)
    for k in range(6):
        cy = g + h * r.uniform(0.7, 0.96)
        t.ell([x + r.uniform(-6, 6), cy, z + r.uniform(-5, 5)], [r.uniform(6, 9), r.uniform(2.6, 3.6), r.uniform(6, 9)], PINE, 0.8)
    return t


def birch(x, z, g, h, seed):
    r = np.random.default_rng(seed)
    t = Tree()
    t.cyl(x, z, g - 1, g + h * 0.92, 0.75, 0.4, BIRCH)
    for k in range(5):
        rr = r.uniform(3.5, 5.0)
        t.ell([x + r.uniform(-3.5, 3.5), g + h * r.uniform(0.55, 0.95), z + r.uniform(-3, 3)], [rr, rr * 1.1, rr], BIRCHLEAF, 0.7)
    return t


def trace(trees, orig, dirs, tmax, steps=110):
    """Sphere-traces every ray against every tree it can reach. Returns hit, t, tree, material."""
    n = len(orig)
    if dirs.ndim == 1:
        dirs = np.repeat(dirs[None], n, 0)
    best_t = np.asarray(tmax, float).copy() if np.ndim(tmax) else np.full(n, float(tmax))
    hit = np.zeros(n, bool)
    which = np.full(n, -1)
    mat = np.zeros(n, int)
    inv = 1.0 / np.where(np.abs(dirs) < 1e-9, 1e-9, dirs)
    for k, tr in enumerate(trees):
        t0 = (tr.lo - orig) * inv
        t1 = (tr.hi - orig) * inv
        tin = np.maximum(np.minimum(t0, t1).max(1), 0)
        tout = np.minimum(np.maximum(t0, t1).min(1), best_t)
        idx = np.nonzero(tout > tin)[0]
        t = tin[idx]
        tend = tout[idx]
        for s in range(steps):
            if idx.size == 0:
                break
            p = orig[idx] + dirs[idx] * t[:, None]
            d, m = tr.sdf(p)
            got = d < 0.05
            if got.any():
                gi = idx[got]
                closer = t[got] < best_t[gi]
                gi = gi[closer]
                best_t[gi] = t[got][closer]
                hit[gi] = True
                which[gi] = k
                mat[gi] = m[got][closer]
            t = t + np.maximum(d * 0.75, 0.04)
            keep = ~got & (t < tend)
            idx, t, tend = idx[keep], t[keep], tend[keep]
    return hit, best_t, which, mat


def normal(trees, which, p, eps=0.35):
    n = np.zeros_like(p)
    for k, tr in enumerate(trees):
        sel = which == k
        if not sel.any():
            continue
        q = p[sel]
        g = []
        for a in range(3):
            e = np.zeros(3); e[a] = eps
            g.append(tr.sdf(q + e)[0] - tr.sdf(q - e)[0])
        n[sel] = np.stack(g, -1)
    return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)


def min_dist(trees, p):
    d = np.full(len(p), 1e9)
    for tr in trees:
        near = np.all((p > tr.lo - 6) & (p < tr.hi + 6), 1)
        if near.any():
            d[near] = np.minimum(d[near], tr.sdf(p[near])[0])
    return d
