#!/usr/bin/env python3
"""The Hill: pixel-art direction kit (palettes, tile painters, sprite primitives).

Source for the art-direction option mocks in art/direction/. Everything is drawn
at native resolution (16 px tiles, 32 px characters) and only ever scaled by a
whole number with nearest-neighbour. Not final art: these are the option mocks
and the reference implementation of art/direction/pixel-rules.md.
"""
import colorsys
import math
import random
import zlib

from PIL import Image, ImageDraw, ImageFont

T = 16
GREEN = (0x3C, 0xC2, 0x4A)   # P1, identity only
RED = (0xE4, 0x39, 0x3C)     # P2, identity only
WHITE = (255, 255, 255)
LAYERS = ["top", "clay", "stone", "ice", "crys", "cav", "strange", "edge"]
LAYER_NAMES = {"top": "Topsoil", "clay": "Clay", "stone": "Stone", "ice": "Ice", "crys": "Crystal",
               "cav": "The Bottom", "strange": "Strangestone", "edge": "Edgestone"}


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tohex(c):
    return "#%02x%02x%02x" % tuple(c[:3])


def _hsv(c):
    return colorsys.rgb_to_hsv(*[x / 255 for x in c[:3]])


def _rgb(h, s, v):
    return tuple(round(x * 255) for x in colorsys.hsv_to_rgb(h % 1, min(1, max(0, s)), min(1, max(0, v))))


def _toward(h, target_deg, deg):
    d = ((target_deg / 360 - h + .5) % 1) - .5
    return h + math.copysign(min(abs(d), deg / 360), d)


def ramp(c, P):
    """Four shades (deep, low, mid, high) with hue shift: shadows lean to the
    palette's shadow hue, highlights to its light hue. Never plain darken."""
    h, s, v = _hsv(c)
    k = P["k"]
    hh = _toward(h, k["hi_hue"], k["deg"]) if s > .03 else h
    hi = _rgb(hh, s * (1 - k["hi_desat"]), v + (1 - v) * k["hi_lift"] + .04)
    out = []
    lh, ls, lv = h, s, v
    for _ in range(2):
        lh = _toward(lh, k["sh_hue"], k["deg"]) if ls > .03 else lh
        ls = min(1, ls + k["sh_sat"])
        lv = lv * (1 - k["sh_drop"])
        out.append(_rgb(lh, ls, lv))
    return (out[1], out[0], tuple(c[:3]), hi)


def backwall(c, P):
    """Dug-out tunnel wall behind a layer: same hue family, darker, calmer."""
    h, s, v = _hsv(c)
    k = P["k"]
    h = _toward(h, k["sh_hue"], 10) if s > .03 else h
    bg = _rgb(h, s * k["bg_sat"], v * k["bg_val"])
    h2, s2, v2 = _hsv(bg)
    return bg, _rgb(h2, s2, v2 * .8)


def build(P):
    """Resolve a palette spec (hex strings) into ramps."""
    P = dict(P)
    P["c"] = {n: hx(v) for n, v in P["colors"].items()}
    P["ramps"], P["back"] = {}, {}
    for n in LAYERS:
        base = hx(P["layers"][n])
        P["ramps"][n] = ramp(base, P)
        ov = P.get("back_override", {}).get(n)
        if ov:
            b = hx(ov)
            h, s, v = _hsv(b)
            P["back"][n] = (b, _rgb(h, s, v * .8))
        else:
            P["back"][n] = backwall(base, P)
    for n, c in P["c"].items():
        P["ramps"][n] = ramp(c, P)
    for n, c in CHAR.items():
        P["ramps"][n] = ramp(hx(c), P)
    P["outline"] = P["c"]["outline"]
    return P


# Character colours are fixed by the library look notes and do not change per palette.
CHAR = {
    "costume": "#FFD84D", "jeans": "#3B5BA5", "skin": "#F2C9A0", "boots": "#8A5A2B",
    "p1": "#3CC24A", "p2": "#E4393C", "shirt": "#3A3846", "beak": "#FF9A2E",
}

_K_A = dict(sh_hue=265, hi_hue=55, deg=10, sh_drop=.20, sh_sat=.07, hi_lift=.40, hi_desat=.30, bg_val=.50, bg_sat=.80)
_K_B = dict(sh_hue=290, hi_hue=45, deg=16, sh_drop=.19, sh_sat=.05, hi_lift=.38, hi_desat=.30, bg_val=.55, bg_sat=.70)
_K_C = dict(sh_hue=240, hi_hue=50, deg=12, sh_drop=.28, sh_sat=.08, hi_lift=.42, hi_desat=.25, bg_val=.40, bg_sat=.90)

PALETTES = {
    "a": dict(
        key="a", name="A  Sandbox", mood="Bright toy box. Candy-clean, high value, soft plum outlines.",
        k=_K_A,
        layers=dict(top="#9a6a40", clay="#e8913c", stone="#7f93b8", ice="#c4ecfb", crys="#a865e6",
                    cav="#a8455f", strange="#2e6a7c", edge="#9fa5ad"),
        back_override=dict(ice="#4f8fc4"),
        colors=dict(sky1="#58c4f0", sky2="#a5e3fa", cloud="#ffffff", sun="#fff3a0", hill="#b4e07a",
                    grass="#8ccf3c", leaf="#2f9a74", leaf2="#2f9a74", wood="#a8703c", wall="#fbe8c0",
                    roof="#5a6f9c", roof2="#6b4a3a", barn="#c4532f", weath="#9c8f86", metal="#aab4c4",
                    veh="#f7b322", tyre="#40405a", glass="#bfeeff", water="#3fa0f0", lava="#ff8a2a",
                    gold="#ffd23f", pink="#ff6fa8", rock="#a9a29a", rune="#8af5e4", outline="#3a2a44"),
    ),
    "b": dict(
        key="b", name="B  Storybook", mood="Golden-hour picture book. Dusty, cosy, cream lights, plum shadows.",
        k=_K_B,
        layers=dict(top="#8b6449", clay="#cf7d55", stone="#8090a6", ice="#cfe6ec", crys="#9b7bcb",
                    cav="#c48f30", strange="#3f5372", edge="#a8a39b"),
        back_override=dict(ice="#6a93b0"),
        colors=dict(sky1="#9fd4d8", sky2="#f9e7bd", cloud="#fff8e6", sun="#fff1b8", hill="#cdcc80",
                    grass="#a7b548", leaf="#6f9440", leaf2="#d98a3c", wood="#8f6244", wall="#f0dcb4",
                    roof="#b8684a", roof2="#5c5470", barn="#9c4a3a", weath="#9a8c7c", metal="#a9a9a2",
                    veh="#e8a838", tyre="#4a4050", glass="#cfe8e0", water="#5a9cc0", lava="#f08a3c",
                    gold="#f2c14e", pink="#e88ab0", rock="#a39686", rune="#aef0dc", outline="#4a3030"),
    ),
    "c": dict(
        key="c", name="C  Lantern", mood="Late-afternoon adventure. Deep jewel layers, dark tunnels, glowing finds.",
        k=_K_C,
        layers=dict(top="#6e4230", clay="#c9581c", stone="#43568c", ice="#6cc4f0", crys="#7a35d0",
                    cav="#6a2238", strange="#16304a", edge="#666e7c"),
        back_override=dict(ice="#1f4f90"),
        colors=dict(sky1="#2f7fe0", sky2="#a8dcff", cloud="#fff6e0", sun="#ffe95c", hill="#6fae30",
                    grass="#8ccc28", leaf="#1c8068", leaf2="#1c8068", wood="#7e4826", wall="#ffdc9c",
                    roof="#34468a", roof2="#43293a", barn="#b03a1c", weath="#746b7a", metal="#93a6c8",
                    veh="#ffac00", tyre="#272740", glass="#a4e4ff", water="#2278ff", lava="#ff7a1a",
                    gold="#ffd000", pink="#ff4f9a", rock="#857f8c", rune="#4cf5c0", outline="#16131f"),
    ),
}


# ---------------------------------------------------------------- colour checks
def lab(c):
    def f(u):
        u /= 255
        return u / 12.92 if u <= .04045 else ((u + .055) / 1.055) ** 2.4
    r, g, b = [f(x) for x in c[:3]]
    x = (.4124 * r + .3576 * g + .1805 * b) / .95047
    y = .2126 * r + .7152 * g + .0722 * b
    z = (.0193 * r + .1192 * g + .9505 * b) / 1.08883
    g_ = lambda t: t ** (1 / 3) if t > .008856 else 7.787 * t + 16 / 116
    return (116 * g_(y) - 16, 500 * (g_(x) - g_(y)), 200 * (g_(y) - g_(z)))


def delta_e(a, b):
    return math.dist(lab(a), lab(b))


def hue_deg(c):
    return _hsv(c)[0] * 360


def reserved_hue(c):
    """True when an environment colour trespasses on a player's identity hue."""
    h, s, v = _hsv(c)
    h *= 360
    if s < .45 or v < .45:
        return False
    return 100 <= h <= 150 or h >= 345 or h <= 8


# ---------------------------------------------------------------- primitives
def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def A(c):
    return tuple(c[:3]) + (255,)


def outline(im, col):
    """1 px outer outline in the palette's outline colour (4-neighbour)."""
    w, h = im.size
    src = im.load()
    out = im.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                        o[x, y] = A(col)
                        break
    return out


def sprite(rows, legend, col=None):
    w = max(len(r) for r in rows)
    im = canvas(w + 2, len(rows) + 2)
    p = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in legend:
                p[x + 1, y + 1] = A(legend[ch])
    return outline(im, col) if col else im


def blob(d, cx, cy, rx, ry, r4, hi=True):
    """Lit-from-top-left lump: low crescent bottom-right, mid body, high spot."""
    dp, lo, mid, hi_c = r4
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=A(lo))
    d.ellipse([cx - rx, cy - ry, cx + rx - 2, cy + ry - 2], fill=A(mid))
    if hi:
        d.ellipse([cx - rx * .6, cy - ry * .7, cx - rx * .05, cy - ry * .2], fill=A(hi_c))


def planks(im, box, r4, step=5, horiz=False, seed=1):
    x0, y0, x1, y1 = box
    dp, lo, mid, hi = r4
    d = ImageDraw.Draw(im)
    d.rectangle(box, fill=A(mid))
    rng = random.Random(seed)
    if horiz:
        for y in range(y0 + step - 1, y1, step):
            d.line([x0, y, x1, y], fill=A(lo))
    else:
        for x in range(x0 + step - 1, x1, step):
            d.line([x, y0, x, y1], fill=A(lo))
    for _ in range(max(1, (x1 - x0) * (y1 - y0) // 220)):
        d.point((rng.randint(x0 + 1, x1 - 1), rng.randint(y0 + 1, y1 - 1)), fill=A(dp))
    d.line([x0, y0, x1, y0], fill=A(hi))
    d.line([x0, y0, x0, y1], fill=A(hi))
    d.line([x1, y0 + 1, x1, y1], fill=A(lo))


_FONT = {}
NOTES = []


def text(im, x, y, s, col, plate=None, size=8):
    """Annotation, not game art: queued, then drawn crisp after the integer upscale."""
    NOTES.append((x, y, s, col, plate, size))


def flush(im, scale, ox=0, oy=0, clear=True):
    d = ImageDraw.Draw(im)
    for x, y, s, col, plate, size in NOTES:
        px = max(size * scale, 10)
        f = _FONT.setdefault(px, ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", px))
        X, Y = ox + x * scale, oy + y * scale
        if plate:
            w = f.getlength(s)
            d.rectangle([X - 2 * scale, Y - scale, X + w + 2 * scale, Y + px + 2 * scale], fill=tuple(plate[:3]))
        d.text((X, Y), s, font=f, fill=tuple(col[:3]))
    if clear:
        NOTES.clear()


def sparkle(im, x, y, P, big=True):
    p = im.load()
    g = P["ramps"]["gold"][3]
    pts = [(0, 0, WHITE)]
    n = 3 if big else 1
    for i in range(1, n + 1):
        c = WHITE if i == 1 and big else g
        pts += [(i, 0, c), (-i, 0, c), (0, i, c), (0, -i, c)]
    if big:
        pts += [(1, 1, g), (-1, 1, g), (1, -1, g), (-1, -1, g)]
    for dx, dy, c in pts:
        if 0 <= x + dx < im.width and 0 <= y + dy < im.height:
            p[x + dx, y + dy] = A(c)


# ---------------------------------------------------------------- tiles
RUNES = ["01110 10001 10101 10001 01110", "10001 01010 00100 01010 10001", "00100 01110 10101 00100 00100",
         "11111 00001 01111 01000 01111", "10101 10101 11111 00100 00100"]


def _rng(kind, tx, ty):
    return random.Random((tx * 73856093) ^ (ty * 19349663) ^ zlib.crc32(kind.encode()))


def tile(P, kind, tx, ty):
    dp, lo, mid, hi = P["ramps"][kind]
    r = _rng(kind, tx, ty)
    im = Image.new("RGBA", (T, T), A(mid))
    p = im.load()

    def S(x, y, c):
        if 0 <= x < T and 0 <= y < T:
            p[x, y] = A(c)

    def specks(n, c):
        for _ in range(n):
            S(r.randrange(T), r.randrange(T), c)

    if kind == "top":
        specks(7, lo)
        specks(3, hi)
        if r.random() < .5:
            x, y = r.randrange(1, 13), r.randrange(2, 13)
            S(x, y, hi), S(x + 1, y, hi), S(x, y + 1, lo), S(x + 1, y + 1, dp), S(x + 2, y + 1, dp)
    elif kind == "clay":
        for x in range(T):
            wx = tx * T + x
            for base, ph in ((4, 0), (11, 2.1)):
                y = base + round(1.3 * math.sin(wx * .31 + ph + ty * 1.7))
                S(x, y, lo)
                if (wx // 3 + ty) % 3 == 0:
                    S(x, y - 1, hi)
        for _ in range(r.randrange(1, 3)):
            x, y = r.randrange(1, 14), r.randrange(1, 14)
            S(x, y, dp), S(x + 1, y, dp), S(x, y - 1, hi)
    elif kind == "stone":
        for row in range(2):
            y0 = row * 8
            off = r.randrange(3, 7) if row == 0 else r.randrange(9, 13)
            gap = r.randrange(T)
            for x in range(T):
                if (x - gap) % T > 4:
                    S(x, y0 + 7 + (1 if (x + tx) % 7 == 0 else 0), lo)
            for y in range(y0 + r.randrange(0, 3), y0 + 7):
                S(off + (1 if y % 5 == 0 else 0), y, lo)
            for x in range(off + 1, off + 1 + r.randrange(3, 6)):
                S(x % T, y0, hi)
            S((off + 1) % T, y0 + 1, hi)
        specks(2, dp)
    elif kind == "ice":
        for _ in range(2):
            x, y, n = r.randrange(1, 11), r.randrange(5, 15), r.randrange(3, 6)
            for i in range(n):
                S(x + i, y - i, hi)
            S(x + n - 1, y - n, WHITE)
        specks(4, lo)
        S(r.randrange(T), r.randrange(T), WHITE)
    elif kind == "crys":
        specks(4, lo)
        for _ in range(2):
            cx, cy, n = r.randrange(3, 13), r.randrange(0, 8), r.randrange(6, 9)
            for i in range(n):
                hw = min(i, n - 1 - i, 2)
                for dx in range(-hw, hw + 1):
                    S(cx + dx, cy + i, hi if dx < 0 else (dp if dx > 0 else mid))
            S(cx - 1, cy + 2, WHITE)
    elif kind == "cav":
        specks(7, lo)
        specks(3, dp)
        for _ in range(r.randrange(0, 3)):
            S(r.randrange(T), r.randrange(T), P["c"]["gold"])
        if r.random() < .3:
            x, y = r.randrange(2, 10), r.randrange(3, 13)
            for i in range(r.randrange(3, 6)):
                S(x + i, y + (i % 2), P["c"]["lava"])
    elif kind == "strange":
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 15, 15], outline=A(dp))
        d.rectangle([1, 1, 14, 14], outline=A(lo))
        d.line([1, 1, 14, 1], fill=A(hi))
        g = RUNES[r.randrange(len(RUNES))].split()
        rc = P["c"]["rune"]
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit == "1":
                    S(5 + gx, 5 + gy, rc)
    elif kind == "edge":
        d = ImageDraw.Draw(im)
        d.line([0, 0, 15, 0], fill=A(hi))
        d.line([0, 0, 0, 15], fill=A(hi))
        d.line([0, 15, 15, 15], fill=A(lo))
        d.line([15, 1, 15, 15], fill=A(lo))
        for x, y in ((3, 3), (12, 3), (3, 12), (12, 12)):
            S(x, y, dp)
    return im


def hazard(im, x, y, P, w=5):
    """Edgestone's inner stripe: obviously 'the edge'."""
    p = im.load()
    for yy in range(T):
        for xx in range(w):
            c = P["c"]["gold"] if ((xx + yy + y) // 4) % 2 == 0 else P["outline"]
            p[x + xx, y + yy] = A(c)


class World:
    """A little tile grid for mocks: solid[y][x] / back[y][x] hold layer keys."""

    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.solid = [[None] * cols for _ in range(rows)]
        self.back = [[None] * cols for _ in range(rows)]
        self.fluid = {}
        self.plot = set()     # cleared surface columns (no grass)
        self.scrub = set()    # wild surface columns (tall tufts)

    def fill(self, bands, edge_cols=()):
        """bands: [(first_row, kind)], top to bottom. Jagged seams between layers."""
        for y in range(self.rows):
            for x in range(self.cols):
                kind = None
                for i, (y0, k) in enumerate(bands):
                    if y >= y0:
                        kind = k
                        if y == y0 and i > 0 and bands[i - 1][1] and k != "strange" and zlib.crc32(b"%d,%d" % (x // 2, y0)) % 4 == 0:
                            kind = bands[i - 1][1]
                self.back[y][x] = kind
                self.solid[y][x] = kind
                if x in edge_cols and kind:
                    self.solid[y][x] = self.back[y][x] = "edge"

    def dig(self, x0, y0, x1, y1, fluid=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= y < self.rows and 0 <= x < self.cols:
                    self.solid[y][x] = None
                    if fluid:
                        self.fluid[(x, y)] = fluid

    def is_solid(self, x, y):
        if x < 0 or x >= self.cols or y >= self.rows:
            return True
        if y < 0:
            return False
        return self.solid[y][x] is not None

    def render(self, im, P, ox=0, oy=0):
        px = im.load()
        solids = canvas(*im.size)
        sp = solids.load()
        d = ImageDraw.Draw(im)
        W, H = im.size

        def inb(x, y):
            return 0 <= x < W and 0 <= y < H

        for ty in range(self.rows):
            for tx in range(self.cols):
                X, Y = ox + tx * T, oy + ty * T
                k = self.solid[ty][tx]
                bk = self.back[ty][tx]
                if k is None and bk:
                    bg, bgd = P["back"][bk]
                    d.rectangle([X, Y, X + T - 1, Y + T - 1], fill=A(bg))
                    r = _rng("b" + bk, tx, ty)
                    for _ in range(5):
                        x, y = X + r.randrange(T), Y + r.randrange(T)
                        if inb(x, y):
                            px[x, y] = A(bgd)
                        if inb(x + 1, y) and r.random() < .5:
                            px[x + 1, y] = A(bgd)
                    if self.is_solid(tx, ty - 1) and ty > 0:
                        d.rectangle([X, Y, X + T - 1, Y + 2], fill=A(bgd))
                        for x in range(X, X + T, 2):
                            if inb(x, Y + 3):
                                px[x, Y + 3] = A(bgd)
                    f = self.fluid.get((tx, ty))
                    if f:
                        fr = P["ramps"][f]
                        surface = self.fluid.get((tx, ty - 1)) is None
                        d.rectangle([X, Y + (5 if surface else 0), X + T - 1, Y + T - 1], fill=A(fr[2]))
                        if surface:
                            d.line([X, Y + 5, X + T - 1, Y + 5], fill=A(fr[3]))
                            for x in range(X + (tx * 5) % 7, X + T, 7):
                                d.line([x, Y + 5, min(x + 2, X + T - 1), Y + 5], fill=A(WHITE))
                        for _ in range(3):
                            x, y = X + r.randrange(T - 2), Y + 8 + r.randrange(T - 8)
                            d.line([x, y, x + 2, y], fill=A(fr[3] if f == "water" else P["c"]["gold"]))
                        if self.fluid.get((tx, ty + 1)) is None:
                            d.line([X, Y + T - 2, X + T - 1, Y + T - 2], fill=A(fr[1]))
                            d.line([X, Y + T - 1, X + T - 1, Y + T - 1], fill=A(fr[0]))
                if k is None:
                    continue
                t = tile(P, k, tx, ty)
                tp = t.load()
                dp, lo, mid, hi = P["ramps"][k]
                up, dn = not self.is_solid(tx, ty - 1), not self.is_solid(tx, ty + 1)
                lf, rt = not self.is_solid(tx - 1, ty), not self.is_solid(tx + 1, ty)
                surface = up and (ty == 0 or self.back[ty - 1][tx] is None)
                if dn:
                    for x in range(T):
                        tp[x, 15] = A(dp)
                        tp[x, 14] = A(lo)
                if rt:
                    for y in range(T):
                        tp[15, y] = A(dp)
                if lf:
                    for y in range(T):
                        tp[0, y] = A(hi)
                if up:
                    for x in range(T):
                        tp[x, 0] = A(hi)
                        if x % 3:
                            tp[x, 1] = A(hi)
                if surface and k == "top":
                    if tx in self.plot:
                        for x in range(T):
                            tp[x, 0] = A(hi)
                            tp[x, 1] = A(hi)
                            tp[x, 2] = A(mid if x % 4 else lo)
                    else:
                        gd, gl, gm, gh = P["ramps"]["grass"]
                        rr = _rng("g", tx, ty)
                        for x in range(T):
                            depth = 4 + rr.randrange(3)
                            for y in range(depth):
                                tp[x, y] = A(gh if y == 0 else (gl if y >= depth - 1 else gm))
                for cx, cy, a, b in ((0, 0, up, lf), (15, 0, up, rt), (0, 15, dn, lf), (15, 15, dn, rt)):
                    if a and b:
                        tp[cx, cy] = (0, 0, 0, 0)
                solids.paste(t, (X, Y))
                if surface and k == "top" and tx not in self.plot:
                    gd, gl, gm, gh = P["ramps"]["grass"]
                    rr = _rng("t", tx, ty)
                    n = 5 if tx in self.scrub else 2
                    for _ in range(n):
                        x = X + rr.randrange(T)
                        hgt = rr.randrange(2, 6) if tx in self.scrub else rr.randrange(1, 3)
                        for i in range(1, hgt + 1):
                            if inb(x, Y - i):
                                sp[x, Y - i] = A(gh if i == hgt else gm)
                if k == "edge":
                    if lf or not self.is_solid(tx - 1, ty):
                        pass
        im.alpha_composite(solids)
        # hazard stripe on the inner face of edgestone columns
        for ty in range(self.rows):
            for tx in range(self.cols):
                if self.solid[ty][tx] == "edge":
                    X, Y = ox + tx * T, oy + ty * T
                    if tx + 1 < self.cols and self.solid[ty][tx + 1] != "edge" and 0 <= Y and Y + T <= H:
                        hazard(im, X + T - 5, Y, P)
                    if tx > 0 and self.solid[ty][tx - 1] != "edge" and 0 <= Y and Y + T <= H:
                        hazard(im, X, Y, P)


# ---------------------------------------------------------------- characters
JEFF = [
    "........PP........",
    ".......PPPp.......",
    ".....GGGPPpGG.....",
    "....GHHGGGGGGg....",
    "...GHHGGGGGGGGg...",
    "...GHGGGGGGGGGg...",
    ".GGGGGGGGGGGGGGgg.",
    "..YYYYYOOOOYYYYy..",
    "..YYNNNNOONNNNYy..",
    "..YSssSSSSSSssSy..",
    "..YSEESSSSSSEESy..",
    "..YSSSSSSSSSSSSy..",
    "..YSSEEEEEEEESSy..",
    "..YYSSETTTTESSYy..",
    "...YYSSEEEESSYy...",
    "....YYYYYYYYYy....",
    "...YYYYYYYYYYYy...",
    "..YYYWWYYYYYYYYy..",
    ".YYyYWYYYYYYYyYYy.",
    ".YYyYYYYYYYYYyYYy.",
    ".GGyYYYYYYYYYyGGg.",
    ".GG.yYYYYYYYy.GGg.",
    "....BBBBBBBBBb....",
    "....BBBNbBBNBb....",
    "....BBBb.BBBBb....",
    "....BBBb.BBBBb....",
    "...BBBBb.BBBBBb...",
    "...SSSs...SSSs....",
    "..SSSSs..SSSSSs...",
    "..SSSSs..SSSSSs...",
]
CHUCK = [
    "..................",
    "......RRRRRR......",
    "....RRHHRRRRRr....",
    "...RRHRRRDDRRRr...",
    "...RRRRRDDDDRRr...",
    "...RRRRRRDRDRRr...",
    "..rRRRRRRRRRRRRRRr",
    "...KKSSSSSSSSKK...",
    "...KSSSSSSSSSSK...",
    "...SEEEESSSEEEE...",
    "..SSSSEESSSSEESS..",
    "..SSSSSSSSSSSSSS..",
    "...SSSSSSssSSSS...",
    "...SSSSEEEEESSs...",
    "....SSSSSSSSSs....",
    ".....SSSSSSSs.....",
    "...CCCCCCCCCCCc...",
    "..CCCRRRCCCCCCCc..",
    ".CCcCRCCRRCTCcCCc.",
    ".CCcCRCRCCRCCcCCc.",
    ".SScCCRRRCRCCcSSs.",
    ".SS.cCCCCRCCc.SSs.",
    "....BBBBBBBBBb....",
    "....BBBBbBBBBb....",
    "....BBBb.BBBBb....",
    "....BBBb.BBBBb....",
    "....NNNn.NNNNn....",
    "....NNNn.NNNNn....",
    "...NNNNn.NNNNNNn..",
    "...NnNNn.NnNNNNn..",
]
SHOVEL = ["ww", "ww", ".w", ".w", ".w", ".w", ".w", ".w", ".w", ".w", ".w", ".w", "MMM", "MMm", "MMm", "MMm", ".m."]


def _legend(P):
    R = P["ramps"]
    return {
        "G": R["p1"][2], "g": R["p1"][1], "H": R["p1"][3], "N": R["p1"][2],
        "R": R["p2"][2], "r": R["p2"][1],
        "P": P["c"]["pink"], "p": R["pink"][1],
        "Y": R["costume"][2], "y": R["costume"][1], "W": R["costume"][3], "O": R["beak"][2],
        "S": R["skin"][2], "s": R["skin"][1], "E": P["outline"], "T": WHITE,
        "B": R["jeans"][2], "b": R["jeans"][1],
        "C": R["shirt"][2], "c": hx("#1E1E26"), "K": R["boots"][0], "D": R["costume"][2],
        "w": R["wood"][2], "M": R["metal"][2], "m": R["metal"][1],
    }


def jeff(P, shovel=True, flip=False):
    L = _legend(P)
    body = sprite(JEFF, L)
    im = canvas(26, 32)
    if shovel:
        im.alpha_composite(sprite(SHOVEL, L), (19, 9))
    im.alpha_composite(body, (0, 0))
    im = outline(im, P["outline"])
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def chuck(P, flip=False):
    L = dict(_legend(P))
    L["H"] = P["ramps"]["p2"][3]
    L["N"], L["n"] = P["ramps"]["boots"][2], P["ramps"]["boots"][0]
    im = sprite(CHUCK, L, P["outline"])
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


# ---------------------------------------------------------------- vehicles
def loader(P, stripe=None, driver=None, load=None):
    """Front Loader, facing right. The face lives on the engine hood: two round
    headlight eyes and a bumper smile. 90x52, wheels touch the bottom row."""
    R = P["ramps"]
    vd, vl, vm, vh = R["veh"]
    md, ml, mm, mh = R["metal"]
    td, tl, tm, th = R["tyre"]
    im = canvas(92, 54)
    d = ImageDraw.Draw(im)
    o = 1
    # boom arm and bucket (behind the body)
    d.line([58 + o, 24, 76 + o, 32], fill=A(vl), width=5)
    d.line([56 + o, 30, 72 + o, 36], fill=A(mm), width=2)
    d.polygon([(70 + o, 24), (86 + o, 27), (89 + o, 46), (72 + o, 48), (67 + o, 38)], fill=A(mm))
    d.polygon([(72 + o, 27), (84 + o, 29), (86 + o, 43), (74 + o, 45), (70 + o, 37)], fill=A(ml))
    d.line([70 + o, 24, 86 + o, 27], fill=A(mh))
    for x in (76, 81, 86):
        d.polygon([(x + o, 47), (x + 3 + o, 47), (x + 2 + o, 51)], fill=A(mh))
    if load:
        ld = R[load]
        blob(d, 78 + o, 23, 8, 5, ld)
        blob(d, 83 + o, 25, 4, 3, ld, hi=False)
    # chassis
    d.rounded_rectangle([6 + o, 24, 66 + o, 40], 3, fill=A(vm))
    d.line([8 + o, 24, 64 + o, 24], fill=A(vh))
    d.rectangle([7 + o, 37, 65 + o, 40], fill=A(vl))
    sc = stripe or R["wall"][2]
    d.rectangle([7 + o, 33, 65 + o, 35], fill=A(sc))
    # hood with the face
    d.rounded_rectangle([40 + o, 15, 68 + o, 33], 4, fill=A(vm))
    d.line([43 + o, 15, 65 + o, 15], fill=A(vh))
    d.line([42 + o, 16, 60 + o, 16], fill=A(vh))
    for cx in (50, 61):
        d.ellipse([cx - 4 + o, 18, cx + 4 + o, 26], fill=A(vl))
        d.ellipse([cx - 3 + o, 19, cx + 3 + o, 25], fill=A(WHITE))
        d.rectangle([cx + o, 21, cx + 2 + o, 24], fill=A(P["outline"]))
        d.point((cx + o, 21), fill=A(WHITE))
    d.line([51 + o, 29, 60 + o, 29], fill=A(P["outline"]))
    d.point((50 + o, 28), fill=A(P["outline"]))
    d.point((61 + o, 28), fill=A(P["outline"]))
    d.rectangle([45 + o, 27, 46 + o, 28], fill=A(P["c"]["pink"]))
    d.rectangle([65 + o, 27, 66 + o, 28], fill=A(P["c"]["pink"]))
    # exhaust
    d.rectangle([43 + o, 6, 45 + o, 15], fill=A(mm))
    d.line([43 + o, 6, 43 + o, 15], fill=A(mh))
    d.rectangle([42 + o, 5, 46 + o, 6], fill=A(ml))
    # cab
    d.rounded_rectangle([13 + o, 3, 38 + o, 26], 3, fill=A(vm))
    d.rectangle([17 + o, 7, 35 + o, 20], fill=A(R["glass"][2]))
    d.line([17 + o, 7, 35 + o, 7], fill=A(R["glass"][1]))
    d.line([20 + o, 18, 26 + o, 9], fill=A(R["glass"][3]))
    d.line([22 + o, 18, 28 + o, 9], fill=A(R["glass"][3]))
    if driver is not None:
        head = driver.crop((1, 1, driver.width - 1, 15))
        im.alpha_composite(head.crop((1, 0, 18, 13)), (18 + o, 8))
        d = ImageDraw.Draw(im)
    d.rectangle([13 + o, 21, 38 + o, 23], fill=A(vl))
    d.rounded_rectangle([11 + o, 1, 40 + o, 5], 2, fill=A(stripe or vl))
    d.line([13 + o, 1, 38 + o, 1], fill=A(vh if not stripe else WHITE))
    d.rectangle([24 + o, 0, 27 + o, 0], fill=A(P["c"]["lava"]))
    # wheels
    for cx, cy, r in ((21, 40, 12), (55, 42, 10)):
        d.ellipse([cx - r + o, cy - r, cx + r + o, cy + r], fill=A(tm))
        d.arc([cx - r + 2 + o, cy - r + 2, cx + r - 2 + o, cy + r - 2], 180, 290, fill=A(th))
        d.ellipse([cx - r + 5 + o, cy - r + 5, cx + r - 5 + o, cy + r - 5], fill=A(vl))
        d.ellipse([cx - r + 6 + o, cy - r + 6, cx + r - 7 + o, cy + r - 7], fill=A(vm))
        d.rectangle([cx - 1 + o, cy - 1, cx + o, cy], fill=A(md))
        for a in range(0, 360, 45):
            x, y = cx + round((r - 1) * math.cos(math.radians(a))), cy + round((r - 1) * math.sin(math.radians(a)))
            d.point((x + o, y), fill=A(td))
    return outline(im, P["outline"])


def puff(im, x, y, r, P):
    d = ImageDraw.Draw(im)
    c = P["ramps"]["cloud"]
    d.ellipse([x - r, y - r, x + r, y + r], fill=A(c[1]))
    d.ellipse([x - r, y - r, x + r - 1, y + r - 1], fill=A(c[2]))


# ---------------------------------------------------------------- props
def tree(P, kind="leaf", seed=0):
    R = P["ramps"]
    im = canvas(44, 60)
    d = ImageDraw.Draw(im)
    w = R["wood"]
    d.rectangle([19, 34, 24, 58], fill=A(w[2]))
    d.rectangle([23, 34, 24, 58], fill=A(w[1]))
    d.line([19, 36, 19, 58], fill=A(w[3]))
    d.polygon([(16, 58), (19, 52), (19, 58)], fill=A(w[2]))
    d.polygon([(27, 58), (24, 52), (24, 58)], fill=A(w[1]))
    lf = R[kind]
    for cx, cy, r in ((22, 24, 13), (11, 28, 9), (33, 28, 9), (22, 12, 10)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=A(lf[1]))
    for cx, cy, r in ((22, 24, 13), (11, 28, 9), (33, 28, 9), (22, 12, 10)):
        d.ellipse([cx - r, cy - r, cx + r - 2, cy + r - 3], fill=A(lf[2]))
    for cx, cy, r in ((19, 9, 5), (8, 25, 4), (30, 24, 4), (18, 21, 5)):
        d.ellipse([cx - r, cy - r + 1, cx + r, cy + r - 1], fill=A(lf[3]))
    rng = random.Random(seed)
    for _ in range(10):
        x, y = rng.randrange(6, 38), rng.randrange(6, 34)
        if im.getpixel((x, y))[3]:
            d.point((x, y), fill=A(lf[0]))
    return outline(im, P["outline"])


def rock(P, w=22, h=15, key="rock"):
    im = canvas(w + 2, h + 2)
    d = ImageDraw.Draw(im)
    blob(d, w // 2 + 1, h // 2 + 2, w // 2 - 1, h // 2 - 1, P["ramps"][key])
    d.rectangle([1, h - 1, w, h + 1], fill=(0, 0, 0, 0)) if False else None
    r = P["ramps"][key]
    d.line([w // 2 + 2, h // 2, w // 2 + 4, h // 2 + 3], fill=A(r[0]))
    return outline(im, P["outline"])


def boulder(P, r=11):
    im = canvas(2 * r + 4, 2 * r + 4)
    d = ImageDraw.Draw(im)
    c = r + 2
    blob(d, c, c, r, r, P["ramps"]["rock"])
    k = P["ramps"]["rock"]
    d.line([c + 2, c - 3, c + 5, c + 1], fill=A(k[0]))
    d.line([c + 5, c + 1, c + 3, c + 4], fill=A(k[0]))
    d.point((c - 4, c + 5), fill=A(k[0]))
    d.point((c - 5, c + 4), fill=A(k[1]))
    return outline(im, P["outline"])


def stump(P):
    w = P["ramps"]["wood"]
    im = canvas(18, 13)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 13, 12], fill=A(w[2]))
    d.rectangle([11, 5, 13, 12], fill=A(w[1]))
    d.polygon([(1, 12), (4, 8), (4, 12)], fill=A(w[2]))
    d.polygon([(16, 12), (13, 8), (13, 12)], fill=A(w[1]))
    d.ellipse([3, 1, 14, 6], fill=A(w[3]))
    d.ellipse([6, 2, 11, 5], outline=A(w[2]))
    return outline(im, P["outline"])


def fence(P, n=4, broken=()):
    k = P["ramps"]["weath"]
    rust = P["ramps"]["barn"]
    im = canvas(n * 14 + 6, 22)
    d = ImageDraw.Draw(im)
    for i in range(n):
        x = 2 + i * 14
        if i in broken:
            d.polygon([(x, 20), (x + 2, 20), (x + 7, 12), (x + 5, 11)], fill=A(k[2]))
            continue
        d.rectangle([x, 4, x + 2, 20], fill=A(k[2]))
        d.line([x, 4, x, 20], fill=A(k[3]))
        d.point((x + 1, 3), fill=A(k[2]))
        if i + 1 < n and (i + 1) not in broken:
            for y in (8, 14):
                d.line([x + 3, y, x + 8, y + 1], fill=A(rust[1]))
                d.line([x + 8, y + 1, x + 13, y], fill=A(rust[1]))
    return outline(im, P["outline"])


def cloud(P, w=40):
    c = P["ramps"]["cloud"]
    im = canvas(w, 18)
    d = ImageDraw.Draw(im)
    for cx, cy, r in ((w * .25, 11, 6), (w * .5, 8, 8), (w * .75, 11, 6)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=A(c[2]))
    d.rectangle([4, 12, w - 5, 16], fill=A(c[2]))
    d.line([6, 16, w - 7, 16], fill=A(P["c"]["sky2"]))
    return im


def barn(P):
    R = P["ramps"]
    b, rf, cr = R["barn"], R["roof2"], R["wall"]
    im = canvas(88, 78)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 38), (12, 17), (30, 4), (55, 4), (73, 17), (83, 38)], fill=A(rf[2]))
    d.line([(2, 38), (12, 17), (30, 4), (55, 4)], fill=A(rf[3]))
    d.line([(55, 5), (73, 18), (82, 38)], fill=A(rf[1]))
    planks(im, (8, 38, 77, 76), b, step=6, seed=3)
    d = ImageDraw.Draw(im)
    d.polygon([(8, 38), (16, 20), (32, 9), (53, 9), (69, 20), (77, 38)], fill=A(b[2]))
    for x in range(13, 77, 6):
        d.line([x, 12 if 30 < x < 56 else 24, x, 38], fill=A(b[1]))
    d.polygon([(8, 38), (16, 20), (32, 9), (53, 9), (69, 20), (77, 38), (75, 38), (68, 22), (52, 11), (33, 11), (17, 22), (10, 38)], fill=A(cr[2]))
    d.rectangle([8, 37, 77, 38], fill=A(cr[2]))
    # hayloft
    d.rectangle([36, 17, 49, 30], fill=A(cr[2]))
    d.rectangle([38, 19, 47, 28], fill=A(P["back"]["top"][1]))
    d.rectangle([38, 25, 47, 28], fill=A(R["gold"][2]))
    d.line([39, 24, 46, 24], fill=A(R["gold"][3]))
    # door
    d.rectangle([28, 46, 57, 76], fill=A(cr[2]))
    d.rectangle([30, 48, 55, 76], fill=A(b[1]))
    d.line([30, 48, 55, 76], fill=A(cr[2]), width=2)
    d.line([55, 48, 30, 76], fill=A(cr[2]), width=2)
    d.line([42, 48, 42, 76], fill=A(cr[1]))
    d.line([43, 48, 43, 76], fill=A(cr[2]))
    d.rectangle([8, 74, 77, 76], fill=A(b[0]))
    d.rectangle([30, 74, 55, 76], fill=A(b[0]))
    return outline(im, P["outline"])


def house(P):
    R = P["ramps"]
    wl, rf, wd = R["wall"], R["roof"], R["wood"]
    im = canvas(72, 66)
    d = ImageDraw.Draw(im)
    planks(im, (46, 3, 53, 20), R["barn"], step=4, horiz=True, seed=5)
    planks(im, (9, 31, 61, 64), wl, step=5, horiz=True, seed=7)
    d = ImageDraw.Draw(im)
    d.rectangle([44, 2, 55, 4], fill=A(R["barn"][1]))
    d.polygon([(2, 33), (18, 11), (52, 11), (68, 33)], fill=A(rf[2]))
    for y in range(15, 33, 4):
        x0 = 2 + (33 - y) * 16 // 22
        d.line([x0 + 1, y, 70 - x0 - 1, y], fill=A(rf[1]))
        for x in range(x0 + 3 + (y % 8), 70 - x0 - 1, 8):
            d.line([x, y, x, y + 3], fill=A(rf[1]))
    d.line([(3, 32), (18, 11), (52, 11)], fill=A(rf[3]))
    d.rectangle([2, 32, 68, 33], fill=A(rf[0]))
    # door
    d.rectangle([15, 42, 28, 64], fill=A(wd[1]))
    d.rectangle([17, 44, 26, 64], fill=A(wd[2]))
    d.line([17, 44, 17, 64], fill=A(wd[3]))
    d.rectangle([24, 54, 25, 55], fill=A(R["gold"][2]))
    # window with flower box
    d.rectangle([36, 39, 55, 54], fill=A(wd[1]))
    d.rectangle([38, 41, 53, 52], fill=A(R["glass"][2]))
    d.line([45, 41, 45, 52], fill=A(wd[1]))
    d.line([38, 46, 53, 46], fill=A(wd[1]))
    d.line([39, 45, 42, 42], fill=A(WHITE))
    d.rectangle([35, 55, 56, 58], fill=A(wd[2]))
    for i, x in enumerate(range(37, 56, 3)):
        d.point((x, 54), fill=A(P["c"]["pink"] if i % 2 else R["gold"][2]))
        d.point((x + 1, 55), fill=A(R["leaf"][2]))
    d.rectangle([9, 62, 61, 64], fill=A(wl[0]))
    return outline(im, P["outline"])


def old_shed(P):
    """A ruin: grey weathered boards, missing planks, leaning, moss. Reads 'broken', not 'spooky'."""
    R = P["ramps"]
    k, moss = R["weath"], R["grass"]
    base = canvas(70, 50)
    d = ImageDraw.Draw(base)
    planks(base, (8, 18, 46, 48), k, step=5, seed=11)
    d = ImageDraw.Draw(base)
    dark = P["back"]["top"][1]
    for x0 in (18, 33):
        d.rectangle([x0, 22 if x0 == 18 else 30, x0 + 4, 48], fill=A(dark))
    d.rectangle([38, 18, 46, 26], fill=(0, 0, 0, 0))
    d.polygon([(22, 28), (31, 30), (29, 48), (20, 46)], fill=A(k[1]))     # door off its hinge
    d.line([(22, 28), (31, 30)], fill=A(k[3]))
    d.polygon([(3, 20), (14, 7), (36, 10), (32, 20)], fill=A(k[1]))        # roof, what is left of it
    d.line([(4, 19), (14, 7), (36, 10)], fill=A(k[3]))
    d.polygon([(38, 28), (62, 42), (59, 48), (36, 33)], fill=A(k[1]))      # fallen half
    d.line([(38, 28), (62, 42)], fill=A(k[3]))
    d.rectangle([48, 46, 66, 48], fill=A(k[2]))                             # loose board
    for x, y, w in ((8, 12, 5), (20, 8, 4), (44, 32, 5), (10, 44, 4)):
        d.rectangle([x, y, x + w, y + 1], fill=A(moss[2]))
        d.point((x + 1, y + 2), fill=A(moss[1]))
    out = canvas(76, 50)
    for y in range(50):                                                    # pixel-clean lean
        out.alpha_composite(base.crop((0, y, 70, y + 1)), ((48 - y) // 8, y))
    return outline(out, P["outline"])


def headframe(P):
    R = P["ramps"]
    w, m = R["wood"], R["metal"]
    im = canvas(60, 84)
    d = ImageDraw.Draw(im)
    d.line([30, 14, 30, 82], fill=A(m[1]))
    for (x0, x1) in ((8, 20), (50, 38)):
        d.line([x0, 82, x1, 12], fill=A(w[2]), width=4)
        d.line([x0 - 1, 82, x1 - 1, 12], fill=A(w[3]))
    d.line([12, 62, 46, 40], fill=A(w[1]), width=2)
    d.line([46, 62, 12, 40], fill=A(w[1]), width=2)
    d.rectangle([14, 10, 44, 14], fill=A(w[2]))
    d.line([14, 10, 44, 10], fill=A(w[3]))
    d.polygon([(8, 10), (29, 1), (50, 10)], fill=A(R["roof2"][2]))
    d.line([(8, 10), (29, 1)], fill=A(R["roof2"][3]))
    d.ellipse([23, 12, 37, 26], fill=A(m[2]))
    d.ellipse([26, 15, 34, 23], fill=A(m[0]))
    d.ellipse([28, 17, 32, 21], fill=A(m[3]))
    # elevator cage
    d.rectangle([19, 58, 41, 82], outline=A(m[2]))
    d.rectangle([19, 58, 41, 60], fill=A(m[2]))
    d.rectangle([19, 80, 41, 82], fill=A(m[1]))
    for x in (25, 30, 35):
        d.line([x, 61, x, 79], fill=A(m[1]))
    d.rectangle([44, 30, 47, 34], fill=A(R["gold"][2]))   # lantern
    d.point((45, 31), fill=A(WHITE))
    d.line([45, 26, 45, 29], fill=A(m[0]))
    return outline(im, P["outline"])


def treasure(P, kind="cap"):
    g = P["ramps"]["gold"]
    im = canvas(10, 10)
    d = ImageDraw.Draw(im)
    if kind == "cap":
        d.ellipse([1, 1, 8, 8], fill=A(g[2]))
        d.ellipse([3, 3, 6, 6], fill=A(g[1]))
        d.point((2, 3), fill=A(WHITE))
        d.point((3, 2), fill=A(WHITE))
    else:
        c = P["ramps"]["pink"]
        d.polygon([(4, 1), (8, 4), (4, 8), (1, 4)], fill=A(c[2]))
        d.polygon([(4, 1), (4, 8), (1, 4)], fill=A(c[3]))
        d.point((3, 3), fill=A(WHITE))
    return outline(im, P["outline"])


def sky(im, P, horizon):
    d = ImageDraw.Draw(im)
    s1, s2 = P["c"]["sky1"], P["c"]["sky2"]
    n = 5
    band = max(1, horizon // n)
    px = im.load()
    for i in range(n):
        t = i / (n - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(s1, s2))
        y0 = i * band
        d.rectangle([0, y0, im.width, horizon if i == n - 1 else y0 + band], fill=A(c))
        if i:
            for y in (y0, y0 + 1):
                for x in range((y % 2), im.width, 2):
                    px[x, y - 2] = A(c)
