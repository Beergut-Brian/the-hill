#!/usr/bin/env python3
"""The Hill: every in-game sprite sheet, drawn in code (no generative model).

    python3 art/tools/make_game_art.py          # writes assets/sprites/** and manifest.json

Look: palette A "Sandbox" (art/tools/hillpix.py) with D's depth (darker back walls, parallax caves,
light done by the engine). Rules: art/direction/pixel-rules.md. Deterministic: every random draw is
seeded, so re-running gives byte-identical PNGs. Prints a check report at the end (reserved hues,
player-vs-tile contrast, frame counts).
"""
import json
import math
import os
import random
import sys
import zlib

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "characters"))

import hillpix as hp                      # noqa: E402  palette A kit
import residents as rs                    # noqa: E402  approved resident drafts (openjar-characters)

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "sprites")
T = 16
P = hp.build(hp.PALETTES["a"])
R = P["ramps"]
C = P["c"]
OL = P["outline"]                       # A outline #3a2a44
WHITE = (255, 255, 255)
CLEAR = (0, 0, 0, 0)
LAMP = hp.hx("#ffec96")                 # pale warm lamp lens
LIT_WIN = hp.hx("#ffe08a")              # night window glow
COMB = hp.hx("#D63384")                 # Jeff's comb, approved raspberry (characters repo)

# Underground palette ids 1..7 (underground.gd BLOCK_ORDER) and wall layers 0..5.
BLOCKS = ["top", "clay", "stone", "ice", "crys", "edge", "strange"]
BLOCK_NAMES = ["dirt", "clay", "stone", "ice", "crystal", "edgestone", "strangestone"]
WALLS = ["top", "clay", "stone", "ice", "crys", "cav"]
WALL_NAMES = ["topsoil", "clay", "stone", "ice", "crystal", "bottom"]

MANIFEST = {}
USED = {}        # file -> set of colours, for the reserved-hue check
ENV = set()      # files whose colours must stay out of the players' hues


def A(c, a=255):
    return tuple(c[:3]) + (a,)


def rng(*key):
    return random.Random(zlib.crc32(repr(key).encode()))


def save(im, rel, env=True):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    USED[rel] = {px[:3] for px in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()) if px[3]}
    if env:
        ENV.add(rel)
    return rel


def shade(c, steps=1, f=.82):
    """One step darker along A's shadow direction (hue toward 265, a touch more saturation)."""
    h, s, v = hp._hsv(c)
    for _ in range(steps):
        h = hp._keep_out(hp._toward(h, 265, 6), h) if s > .03 else h
        s, v = min(1, s + .04), v * f
    return hp._rgb(h, s, v)


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a[:3], b[:3]))


def outline(im, col=OL):
    return hp.outline(im, col)


def put(p, w, h, x, y, c):
    if 0 <= x < w and 0 <= y < h:
        p[x, y] = A(c) if len(c) == 3 else c


def grid(im, rows, legend, ox=0, oy=0):
    """Paint an ASCII grid; '.' and unknown chars are skipped."""
    p = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in legend and legend[ch] is not None:
                put(p, im.width, im.height, ox + x, oy + y, legend[ch])


# =============================================================================== tiles
def texture(kind, v):
    """16x16 seamless texture: features stay inside the tile, the base is the ramp's mid,
    so any two variants sit side by side with no seam."""
    dp, lo, mid, hi = R[kind]
    r = rng("tex", kind, v)
    im = Image.new("RGBA", (T, T), A(mid))
    p = im.load()

    def S(x, y, c):
        if 0 <= x < T and 0 <= y < T:
            p[x, y] = A(c)

    def specks(n, c, m=1):
        for _ in range(n):
            S(r.randrange(m, T - m), r.randrange(m, T - m), c)

    if kind == "top":
        specks(6, lo)
        specks(3, hi)
        specks(1, dp)
        for _ in range(1 + (v % 2)):                      # a pebble: lit top, dark under
            x, y = r.randrange(2, 12), r.randrange(2, 13)
            w = r.choice((2, 3))
            for i in range(w):
                S(x + i, y, hi)
                S(x + i, y + 1, lo)
            S(x + w, y + 1, dp)
        if v == 3:                                        # a little root
            x, y = r.randrange(3, 9), r.randrange(3, 8)
            for i in range(5):
                S(x + i, y + (i // 2), lo)
    elif kind == "clay":
        # strata: same height at the tile edges for every variant, different wiggle inside
        a, b = (1.4, .5), (-.8, 1.1)
        amp = [(1.3, 0), (1.1, .6), (1.5, -.4), (.9, .9)][v]
        for x in range(T):
            t = 2 * math.pi * x / T
            for base, (k1, k2) in ((4, a), (11, b)):
                y = base + round(amp[0] * k1 * math.sin(t) + amp[1] * k2 * math.sin(2 * t))
                S(x, y, lo)
                if (x + base + v) % 4 == 0:
                    S(x, y - 1, hi)
        for _ in range(1 + v % 2):
            x, y = r.randrange(2, 12), r.randrange(2, 13)
            S(x, y, dp), S(x + 1, y, dp), S(x, y - 1, hi)
    elif kind == "stone":
        # two or three cobbles per tile, each a closed shape lit top-left
        boxes = [[(1, 1, 8, 6), (9, 2, 14, 8), (2, 8, 10, 14)], [(1, 2, 7, 9), (8, 1, 14, 6), (8, 8, 14, 14), (2, 11, 6, 14)],
                 [(2, 1, 13, 6), (1, 8, 7, 14), (9, 8, 14, 13)], [(1, 1, 6, 5), (7, 3, 14, 10), (1, 7, 6, 14), (8, 12, 13, 14)]][v]
        for x0, y0, x1, y1 in boxes:
            for x in range(x0 + 1, x1):
                S(x, y0, hi)
                S(x, y1, lo)
            for y in range(y0 + 1, y1):
                S(x0, y, hi)
                S(x1, y, lo)
            S(x1, y1, dp)
        specks(2, dp, 2)
    elif kind == "ice":
        for _ in range(2):
            x, y, n = r.randrange(1, 10), r.randrange(6, 14), r.randrange(3, 6)
            for i in range(n):
                S(x + i, y - i, hi)
            S(x + n - 1, y - n, WHITE)
        specks(4, lo)
        if v % 2:
            S(r.randrange(3, 13), r.randrange(3, 13), WHITE)
    elif kind == "crys":
        specks(4, lo)
        for _ in range(1 + (v > 1)):
            cx, cy, n = r.randrange(4, 12), r.randrange(1, 6), r.randrange(6, 9)
            for i in range(n):
                hw = min(i, n - 1 - i, 2)
                for dx in range(-hw, hw + 1):
                    S(cx + dx, cy + i, hi if dx < 0 else (dp if dx > 0 else mid))
            S(cx - 1, cy + 2, WHITE)
    elif kind == "edge":
        # big dressed blocks, joints never on the tile border
        for y in (5, 11):
            for x in range(1, 15):
                S(x, y, lo)
            for x in range(1, 15):
                S(x, y + 1, hi) if y + 1 < 15 else None
        jx = [4, 10, 7, 12][v]
        for y in range(6, 11):
            S(jx, y, lo)
            S(jx + 1, y, hi)
        for x, y in ((3, 2), (12, 3), (6, 13))[: 1 + v % 3]:
            S(x, y, dp)
    elif kind == "strange":
        # brickwork: joints at x 7 (upper course) and x 15 (lower course); a faint rune on some
        for x in range(T):
            S(x, 7, dp)
            S(x, 15, dp)
            S(x, 0, hi) if x not in (7, 8) else None
            S(x, 8, hi) if x not in (15, 0) else None
        for y in range(0, 7):
            S(7, y, dp)
            S(8, y, hi) if y else None
        for y in range(8, 15):
            S(15, y, dp)
            S(0, y, hi) if y > 8 else None
        for y in (6, 14):
            for x in range(T):
                if p[x, y][:3] == mid:
                    S(x, y, lo)
        if v < 2:
            g = hp.RUNES[v * 2 + 1].split()
            rc = C["rune"] if v == 0 else mix(C["rune"], mid, .55)
            for gy, row in enumerate(g):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        S(9 + gx, 1 + gy, rc)
    return im


def hazard_band(im, side):
    """Edgestone's exposed face: gold and plum diagonal stripes, 4 px deep."""
    p = im.load()
    for y in range(T):
        for i in range(4):
            x = i if side == "left" else T - 1 - i
            c = C["gold"] if ((x + y) // 3) % 2 == 0 else OL
            p[x, y] = A(c)


def edge_tile(kind, v, mask):
    """mask: bit 1 up, 2 right, 4 down, 8 left = that side touches open space."""
    im = texture(kind, v)
    dp, lo, mid, hi = R[kind]
    p = im.load()
    up, rt, dn, lf = mask & 1, mask & 2, mask & 4, mask & 8
    if kind == "edge":
        if lf:
            hazard_band(im, "left")
        if rt:
            hazard_band(im, "right")
    if dn:
        for x in range(T):
            p[x, 14] = A(lo)
            p[x, 15] = A(dp)
    if rt and kind != "edge":
        for y in range(T):
            p[15, y] = A(dp)
            if p[14, y][:3] == mid:
                p[14, y] = A(lo)
    if lf and kind != "edge":
        for y in range(T):
            p[0, y] = A(hi)
    if up:
        for x in range(T):
            p[x, 0] = A(hi)
            if x % 3 and not (rt and x == 15):
                p[x, 1] = A(hi)
    for cx, cy, a, b in ((0, 0, up, lf), (15, 0, up, rt), (0, 15, dn, lf), (15, 15, dn, rt)):
        if a and b:
            p[cx, cy] = CLEAR
    return im


def make_tiles():
    sheet = Image.new("RGBA", (len(BLOCKS) * 4 * T, 16 * T), CLEAR)
    for i, kind in enumerate(BLOCKS):
        for v in range(4):
            for m in range(16):
                sheet.paste(edge_tile(kind, v, m), ((i * 4 + v) * T, m * T))
    save(sheet, "tiles/terrain.png")
    MANIFEST["terrain"] = {"file": "tiles/terrain.png", "frame": [T, T], "variants": 4,
                           "column": "(id - 1) * 4 + variant", "row": "open mask: 1 up, 2 right, 4 down, 8 left",
                           "ids": {str(i + 1): BLOCK_NAMES[i] for i in range(len(BLOCKS))}}
    icons = Image.new("RGBA", (len(BLOCKS) * T, T), CLEAR)
    for i, kind in enumerate(BLOCKS):
        icons.paste(edge_tile(kind, 0, 15), (i * T, 0))
    save(icons, "icons/blocks.png")
    MANIFEST["block_icons"] = {"file": "icons/blocks.png", "frame": [T, T], "column": "id - 1",
                               "ids": {str(i + 1): BLOCK_NAMES[i] for i in range(len(BLOCKS))}}


def wall_colors(kind):
    return P["back"][kind]


def make_walls():
    sheet = Image.new("RGBA", (len(WALLS) * 4 * T, 2 * T), CLEAR)
    for i, kind in enumerate(WALLS):
        bg, bgd = wall_colors(kind)
        for v in range(4):
            for row in range(2):
                im = Image.new("RGBA", (T, T), A(bg))
                p = im.load()
                r = rng("wall", kind, v)
                for _ in range(4):
                    x, y = r.randrange(1, 14), r.randrange(row * 5 + 1, 15)
                    p[x, y] = A(bgd)
                    if r.random() < .5:
                        p[x + 1, y] = A(bgd)
                if v == 2:                          # a faint crack
                    x, y = r.randrange(3, 10), r.randrange(row * 5 + 3, 11)
                    for k in range(4):
                        p[x + k, y + (k % 2)] = A(bgd)
                if row:
                    for y in range(3):
                        for x in range(T):
                            p[x, y] = A(bgd)
                    for x in range(v % 2, T, 2):
                        p[x, 3] = A(bgd)
                sheet.paste(im, ((i * 4 + v) * T, row * T))
    save(sheet, "tiles/walls.png")
    MANIFEST["walls"] = {"file": "tiles/walls.png", "frame": [T, T], "variants": 4,
                         "column": "layer * 4 + variant", "rows": {"plain": {"row": 0}, "ceiling": {"row": 1}},
                         "layers": {str(i): WALL_NAMES[i] for i in range(len(WALLS))}}


def make_water():
    dp, lo, mid, hi = R["water"]
    im = Image.new("RGBA", (32, 32), CLEAR)
    p = im.load()
    for f in range(2):
        for row in range(2):
            ox, oy = f * T, row * T
            for y in range(T):
                for x in range(T):
                    if row == 0 and y < 4:
                        continue
                    p[ox + x, oy + y] = A(mid, 200)
            if row == 0:
                for x in range(T):
                    p[ox + x, oy + 4] = A(hi, 220)
                for x in range(T):
                    if (x + f * 4) % 8 in (0, 1, 2):
                        p[ox + x, oy + 4] = A(WHITE, 230)
                    if (x + f * 4) % 8 == 1:
                        p[ox + x, oy + 3] = A(WHITE, 230)
            for k in range(2):
                x = (3 + k * 7 + f * 3 + row * 2) % 13
                y = 7 + k * 4 if row == 0 else 3 + k * 7
                for i in range(3):
                    p[ox + x + i, oy + y] = A(hi, 200)
    save(im, "tiles/water.png")
    MANIFEST["water"] = {"file": "tiles/water.png", "frame": [T, T],
                         "rows": {"surface": {"row": 0, "frames": 2, "fps": 3}, "body": {"row": 1, "frames": 2, "fps": 3}}}


def make_grass():
    gd, gl, gm, gh = R["grass"]
    im = Image.new("RGBA", (64, T), CLEAR)
    p = im.load()
    for v in range(4):
        r = rng("grass", v)
        depth = [4, 5, 4, 5, 3, 4, 5, 4, 4, 3, 4, 5, 5, 4, 4, 4]
        r.shuffle(depth)
        depth[0] = depth[15] = 4                  # meet the neighbour cap at the same depth
        for x in range(T):
            for y in range(depth[x]):
                p[v * T + x, y] = A(gh if y == 0 else (gl if y == depth[x] - 1 else gm))
            if depth[x] >= 4 and r.random() < .25:
                p[v * T + x, depth[x]] = A(gl)
        for _ in range(2):
            x = r.randrange(1, 15)
            p[v * T + x, 1] = A(gh)
    save(im, "surface/grass.png")
    MANIFEST["grass"] = {"file": "surface/grass.png", "frame": [T, T], "frames": 4,
                         "note": "drawn over the top row of the ground; transparent below the grass"}


# =============================================================================== backdrops
def wave(x, w, terms, seed):
    """Sum of sines with whole periods over w: tileable horizontally."""
    r = rng("wave", seed)
    y = 0.0
    for k, a in terms:
        y += a * math.sin(2 * math.pi * k * x / w + r.random() * 6.28)
    return y


def make_parallax_underground():
    W, H = 256, 128
    sheet = Image.new("RGBA", (2 * W, len(WALLS) * H), CLEAR)
    for i, kind in enumerate(WALLS):
        wall, _wd = wall_colors(kind)
        d1, d2 = shade(wall, 1, .80), shade(wall, 2, .80)
        if kind == "cav":
            d1, d2 = shade(wall, 1, .84), shade(wall, 2, .82)
        far = Image.new("RGBA", (W, H), A(d2))
        p = far.load()
        for x in range(W):
            ceil = 22 + wave(x, W, ((1, 7), (3, 4), (7, 2)), (kind, "c"))
            floor_ = 98 + wave(x, W, ((2, 8), (5, 3), (9, 1.5)), (kind, "f"))
            for y in range(H):
                if y < ceil or y > floor_:
                    p[x, y] = A(d1)
        # a few far rock columns
        r = rng("farcol", kind)
        for j in range(2):
            cx, w = r.randrange(j * 128, j * 128 + 100), r.randrange(10, 18)
            ph = r.random() * 6.28
            for y in range(H):
                ww = w - abs(y - 64) // 10 + round(2 * math.sin(y * .21 + ph))
                lo_ = round(1.5 * math.sin(y * .13 + ph * 2))
                for dx in range(-ww // 2 + lo_, ww // 2 + 1 + lo_):
                    p[(cx + dx) % W, y] = A(d1)
        if kind == "cav":
            for _ in range(40):
                x, y = r.randrange(W), r.randrange(H)
                p[x, y] = A(mix(C["lava"], d2, .35) if r.random() < .6 else C["gold"])
        near = Image.new("RGBA", (W, H), CLEAR)
        q = near.load()
        nc = shade(wall, 1, .90) if kind != "cav" else shade(wall, 1, .92)
        r = rng("near", kind)
        xs = [16 + j * 42 + r.randrange(0, 18) for j in range(6)]
        for j, cx in enumerate(xs):
            kindj = j % 3
            if kindj == 0:          # pillar floor to ceiling, waisted
                ph = r.random() * 6.28
                for y in range(H):
                    hw = 6 + abs(y - 64) // 7 + round(1.5 * math.sin(y * .3 + ph))
                    sh = round(2 * math.sin(y * .09 + ph))
                    for dx in range(-hw + sh, hw + 1 + sh):
                        q[(cx + dx) % W, y] = A(nc)
            elif kindj == 1:        # stalactite from the top
                ln = r.randrange(30, 56)
                for y in range(ln):
                    hw = max(0, round(8 * (1 - y / ln)))
                    for dx in range(-hw, hw + 1):
                        q[(cx + dx) % W, y] = A(nc)
            else:                   # stalagmite from the floor
                ln = r.randrange(26, 48)
                for y in range(ln):
                    hw = max(0, round(9 * (1 - y / ln)))
                    for dx in range(-hw, hw + 1):
                        q[(cx + dx) % W, H - 1 - y] = A(nc)
        for x in range(W):          # a ragged ceiling and floor lip so the strip reads as a cave
            t = 4 + round(wave(x, W, ((4, 2), (11, 1.2)), (kind, "nt")))
            b = 5 + round(wave(x, W, ((3, 2), (13, 1)), (kind, "nb")))
            for y in range(max(0, t)):
                q[x, y] = A(nc)
            for y in range(max(0, b)):
                q[x, H - 1 - y] = A(nc)
        if kind == "cav":
            r = rng("embers", kind)
            for _ in range(24):
                x, y = r.randrange(W), r.randrange(H)
                if q[x, y][3]:
                    q[x, y] = A(C["lava"])
        sheet.paste(far, (0, i * H))
        sheet.paste(near, (W, i * H))
    save(sheet, "parallax/underground.png")
    MANIFEST["parallax_underground"] = {
        "file": "parallax/underground.png", "strip": [256, 128],
        "rows": {WALL_NAMES[i]: {"row": i} for i in range(len(WALLS))},
        "far": {"x": 0}, "near": {"x": 256}, "tileable": "horizontal"}


def make_parallax_hillville():
    W, H = 512, 96
    sheet = Image.new("RGBA", (W, 3 * H), CLEAR)
    # far mountains: two shades of a pale blue-lilac, snow-free, soft
    m1, m2 = hp.hx("#a9c3e6"), hp.hx("#8fa9d8")
    far = sheet.load()
    for x in range(W):
        a = 40 + wave(x, W, ((1, 14), (3, 9), (5, 5), (11, 2)), "mt1")
        b = 60 + wave(x, W, ((2, 10), (4, 6), (9, 3)), "mt2")
        for y in range(H):
            if y >= b:
                far[x, y] = A(m2)
            elif y >= a:
                far[x, y] = A(m1)
    # near hills: A hill greens (yellow-green)
    hd, hl, hm, hh = R["hill"]
    for x in range(W):
        top = 34 + wave(x, W, ((1, 16), (2, 8), (5, 3)), "hill")
        for y in range(H):
            if y >= top:
                c = hh if y < top + 2 else (hm if y < 78 + wave(x, W, ((3, 4),), "hb") else hl)
                far[x, H + y] = A(c)
    # tree line: teal crowns, rounded bumps, two shades
    ld, ll, lm, lh = R["leaf"]
    r = rng("treeline")
    crowns = []
    x = 0
    while x < W:
        crowns.append((x, r.randrange(44, 62), r.randrange(9, 15)))
        x += r.randrange(12, 20)
    layer = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(layer)
    for cx, cy, rr in crowns:
        for off in (-W, 0, W):
            d.ellipse([cx + off - rr, cy - rr, cx + off + rr, cy + rr], fill=A(ll))
    for cx, cy, rr in crowns:
        for off in (-W, 0, W):
            d.ellipse([cx + off - rr + 2, cy - rr + 1, cx + off + rr - 4, cy + rr - 5], fill=A(lm))
    d.rectangle([0, 66, W, H], fill=A(ll))
    sheet.alpha_composite(layer, (0, 2 * H))
    save(sheet, "parallax/hillville.png")
    MANIFEST["parallax_hillville"] = {
        "file": "parallax/hillville.png", "strip": [512, 96],
        "rows": {"mountains": {"row": 0}, "hills": {"row": 1}, "trees": {"row": 2}}, "tileable": "horizontal"}


def make_sky_bits():
    im = Image.new("RGBA", (256, 96), CLEAR)
    d = ImageDraw.Draw(im)
    # sun 32x32: disc, pale rim ring (A style), no face
    sun = hp.hx("#fff3a0")
    d.ellipse([1, 1, 30, 30], fill=A(hp.hx("#ffe36a")))
    d.ellipse([3, 3, 28, 28], fill=A(sun))
    d.ellipse([6, 6, 25, 25], fill=A(WHITE))
    d.ellipse([7, 7, 13, 12], fill=A(hp.hx("#fffbe0")))
    # moon 24x24 at (32,0): a crescent with two craters
    mo = Image.new("RGBA", (24, 24), CLEAR)
    md = ImageDraw.Draw(mo)
    md.ellipse([1, 1, 22, 22], fill=A(hp.hx("#f4f1d8")))
    md.ellipse([8, -1, 27, 18], fill=CLEAR)
    md.point((5, 14), fill=A(hp.hx("#d8d2b0")))
    md.point((6, 15), fill=A(hp.hx("#d8d2b0")))
    md.point((9, 18), fill=A(hp.hx("#d8d2b0")))
    im.alpha_composite(mo, (32, 0))
    pos = {"sun": [0, 0, 32, 32], "moon": [32, 0, 24, 24]}
    x = 64
    for k, w in enumerate((48, 40, 64)):
        cl = hp.cloud(P, w)
        im.alpha_composite(cl, (x, 2))
        pos["cloud%d" % k] = [x, 2, w, 18]
        x += w + 4
    # star field 128x64 at (0,32): 2 px and 1 px stars, tileable (no star on the border)
    r = rng("stars")
    p = im.load()
    for _ in range(26):
        sx, sy = r.randrange(1, 126), r.randrange(1, 62)
        p[sx, 32 + sy] = A(WHITE)
        if r.random() < .3:
            p[sx + 1, 32 + sy] = A(hp.hx("#cfd8ff"))
            p[sx, 32 + sy + 1] = A(hp.hx("#cfd8ff"))
    pos["stars"] = [0, 32, 128, 64]
    save(im, "surface/sky_bits.png")
    MANIFEST["sky_bits"] = {"file": "surface/sky_bits.png", "regions": pos,
                            "note": "regions are [x, y, w, h]; stars tile horizontally and vertically"}


# =============================================================================== Jeff and Chuck
# Head and torso come from hillpix's approved A sprites (pixel-rules "Jeff (P1)" / "Chuck (P2)").
# Arms, legs and the shovel are drawn per pose. Grid column c sits at frame x = GX + c.
GX, CW = 7, 32
HEAD = {"jeff": hp.JEFF[:16], "chuck": hp.CHUCK[:16]}


def _torso(rows):
    """Torso rows 16..21 with both arms cleared (arms are drawn per pose)."""
    out = []
    for r in rows:
        r = list(r)
        for c in (0, 1, 2, 14, 15, 16, 17):
            r[c] = "."
        out.append("".join(r))
    return out


TORSO = {"jeff": _torso(hp.JEFF[16:22]), "chuck": _torso(hp.CHUCK[16:22])}
# Jeff's puffy chest is wider than his arms' gap; give the side columns back as body shading.
TORSO["jeff"][1] = "..YYYWWYYYYYYYy..."
TORSO["chuck"][2] = "...cCRCCRRCTCc...."
TORSO["chuck"][3] = "...cCRCRCCRCCc...."

LEGS = {
    "jeff": {
        "stand": ["....BBBBBBBBBb....", "....BBBNbBBNBb....", "....BBBb.BBBBb....", "....BBBb.BBBBb....",
                  "....BBBb.BBBBb....", "....SSSs..SSSs....", "....SSSSSs.SSSSSs.", "....SSSSSs.SSSSSs."],
        "contact": ["....BBBBBBBBBb....", "....BBBNbBBNBb....", "...bbbb..BBBBb....", "..bbbb....BBBBb...",
                    ".bbbb......BBBBb..", ".sss........SSSs..", "sssss.......SSSSSs", ".ssss.......SSSSSs"],
        "pass": ["....BBBBBBBBBb....", "....BBBNbBBNBb....", "....bbbBBBBBb.....", "...bbbb.BBBBb.....",
                 "..bbbb..BBBBb.....", "..ssss..BBBBb.....", ".sssss..SSSSSSs...", "........SSSSSSs...",
                 "........SSSSSSs..."],
        "contact2": ["....BBBBBBBBBb....", "....BBBNbBBNBb....", "...BBBB..bbbbb....", "..BBBB....bbbbb...",
                     ".BBBB......bbbbb..", ".SSS........ssss..", "SSSSS.......ssssss", ".SSSS.......ssssss"],
        "pass2": ["....BBBBBBBBBb....", "....BBBNbBBNBb....", ".....BBBBbbbbb....", ".....BBBBb.bbbb...",
                  ".....BBBBb..bbbb..", ".....BBBBb..ssss..", "....SSSSSSs.sssss.", "....SSSSSSs.......",
                  "....SSSSSSs......."],
        "tuck": ["....BBBBBBBBBb....", "...BBBNbBBBNBBb...", "..BBBBb...BBBBBb..", "..SSSs.....SSSSs..",
                 ".SSSSs.....SSSSSs.", ".SSSs.......SSSSs."],
        "dangle": ["....BBBBBBBBBb....", "....BBBNbBBNBb....", "....BBBb.BBBBb....", "...BBBb...BBBBb...",
                   "...BBBb...BBBBb...", "..BBBb.....BBBBb..", "..SSSs.....SSSSs..", "..SSSSs....SSSSSs.",
                   "...SSSs.....SSSSs."],
        "crouch": ["...BBBBBBBBBBb....", "..BBBBNbBBBNBBb...", ".BBBBb....BBBBBb..", ".SSSs......SSSSs..",
                   "SSSSSs.....SSSSSs.", "SSSSSs.....SSSSSs."],
    },
    "chuck": {
        "stand": ["....BBBBBBBBBb....", "....BBBBbBBBBb....", "....BBBb.BBBBb....", "....BBBb.BBBBb....",
                  "....NNNn.NNNNn....", "....NNNn.NNNNn....", "....NNNNn.NNNNNn..", "....N.NNn.N.NNNn.."],
        "contact": ["....BBBBBBBBBb....", "....BBBBbBBBBb....", "...bbbb..BBBBb....", "..bbbb....BBBBb...",
                    ".nnnn......NNNNn..", "nnnn.......NNNNn..", "nnnnn......NNNNNNn", "n.nnn......N.NNNNn"],
        "pass": ["....BBBBBBBBBb....", "....BBBBbBBBBb....", "....bbbBBBBBb.....", "...bbbb.BBBBb.....",
                 "..nnnn..BBBBb.....", ".nnnn...NNNNn.....", "nnnnn...NNNNn.....", "n.nn....NNNNNNn...",
                 "........N.NNNNn..."],
        "contact2": ["....BBBBBBBBBb....", "....BBBBbBBBBb....", "...BBBB..bbbbb....", "..BBBB....bbbbb...",
                     ".NNNN......nnnnn..", "NNNN.......nnnnn..", "NNNNN......nnnnnnn", "N.NNN......n.nnnnn"],
        "pass2": ["....BBBBBBBBBb....", "....BBBBbBBBBb....", ".....BBBBbbbbb....", ".....BBBBb.bbbb...",
                  ".....BBBBb..nnnn..", ".....NNNNn..nnnnn.", ".....NNNNn..nnnnnn", ".....NNNNNn.n.nnn.",
                  ".....N.NNNn......."],
        "tuck": ["....BBBBBBBBBb....", "...BBBBbBBBBBBb...", "..NNNn.....NNNNn..", ".NNNn......NNNNn..",
                 ".NNNNn.....NNNNNNn", ".N.NNn.....N.NNNNn"],
        "dangle": ["....BBBBBBBBBb....", "....BBBBbBBBBb....", "....BBBb.BBBBb....", "...BBBb...BBBBb...",
                   "...NNNn...NNNNn...", "..NNNn.....NNNNn..", "..NNNn.....NNNNn..", "..NNNNn....NNNNNNn",
                   "..N.NNn....N.NNNNn"],
        "crouch": ["...BBBBBBBBBBb....", "..BBBBbBBBBBBBb...", ".NNNn.....NNNNNn..", ".NNNn......NNNNn..",
                   "NNNNNn.....NNNNNNn", "N.NNNn.....N.NNNNn"],
    },
}


def char_legend(who):
    L = dict(hp._legend(P))
    L["P"] = COMB
    L["p"] = shade(COMB, 1)
    if who == "chuck":
        L["H"] = R["p2"][3]
        L["N"], L["n"] = R["boots"][2], R["boots"][0]
    else:
        L["s"] = R["skin"][1]
        L["b"] = R["jeans"][1]
    return L


def arm_cols(who):
    """(sleeve, sleeve shade, hand) colours."""
    if who == "jeff":
        return R["costume"][2], R["costume"][1], R["p1"][2]
    return R["shirt"][2], hp.hx("#1E1E26"), R["skin"][2]


def line_px(x0, y0, x1, y1):
    pts = []
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        pts.append((round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)))
    return pts


def draw_arm(im, who, shoulder, hand, back=False):
    sl, sd, hc = arm_cols(who)
    if back:
        sl = sd
    p = im.load()
    for x, y in line_px(*shoulder, *hand):
        for dx in (0, 1):
            for dy in (0, 1):
                put(p, im.width, im.height, x + dx, y + dy, sl)
    hx_, hy = hand
    for dx in (0, 1):
        for dy in (0, 1):
            put(p, im.width, im.height, hx_ + dx, hy + dy, hc)
    if who == "jeff" and not back:      # wing tip feathers: one green pixel trails the hand
        put(p, im.width, im.height, hx_ - 1, hy + 1, R["p1"][1])


def draw_shovel(im, grip, ang, front=14, back=2):
    """Grip on the hand; ang in degrees (0 = right, -90 = up). Blade 5 wide x 6 long, lit up-left."""
    p = im.load()
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    gx, gy = grip[0] + .5, grip[1] + .5
    wd = R["wood"]
    for x, y in line_px(round(gx - ux * back - .5), round(gy - uy * back - .5), round(gx + ux * front - .5), round(gy + uy * front - .5)):
        put(p, im.width, im.height, x, y, wd[2])
    md, ml, mm, mh = R["metal"]
    bx, by = gx + ux * front, gy + uy * front
    for y in range(im.height):
        for x in range(im.width):
            u = (x + .5 - bx) * ux + (y + .5 - by) * uy
            v = -(x + .5 - bx) * uy + (y + .5 - by) * ux
            if 0 <= u < 6.5 and abs(v) <= 2.6 and not (u >= 5 and abs(v) > 1.6):
                # light from the top-left: the half of the blade facing up-left is lit
                sv = 1 if v > 0 else -1
                toward_light = (sv * -uy) * -1 + (sv * ux) * -1 > 0
                c = mm if abs(v) < .8 else (mh if toward_light else ml)
                p[x, y] = A(c)


POSES = {
    # name: legs, lift, head dx, back-arm (dx, dy), hand (x, y), shovel angle, shovel front, shovel back
    "idle0": ("stand", 0, 0, (0, 0), (22, 21), -90, 14, 2),
    "idle1": ("stand", 0, 0, (0, 1), (22, 22), -90, 14, 2),
    "walk0": ("contact", 0, 0, (1, 0), (22, 21), -90, 14, 2),
    "walk1": ("pass", 0, 0, (0, 0), (22, 20), -90, 14, 2),
    "walk2": ("contact2", 0, 0, (-1, 0), (22, 21), -90, 14, 2),
    "walk3": ("pass2", 0, 0, (0, 0), (22, 20), -90, 14, 2),
    "jump": ("tuck", 2, 0, (-1, -3), (23, 15), -90, 13, 2),
    "fall": ("dangle", 0, 0, (-1, -4), (24, 14), -75, 13, 2),
    "side0": ("stand", 0, -1, (0, 0), (18, 16), -150, 9, 6),
    "side1": ("contact", 0, 1, (1, -1), (22, 19), 0, 3, 8),
    "side2": ("stand", 0, 0, (0, 0), (21, 20), 35, 3, 7),
    "down0": ("stand", 0, 0, (0, -1), (22, 11), -90, 3, 8),
    "down1": ("crouch", 0, 1, (0, 0), (24, 18), 90, 6, 8),
    "down2": ("stand", 0, 0, (0, 0), (23, 17), 60, 4, 8),
}


def strip_outline(im, col):
    """Remove the 1 px outer outline (pixels of `col` that touch transparency)."""
    src = im.load()
    out = im.copy()
    o = out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] and src[x, y][:3] == tuple(col[:3]):
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] == 0:
                        o[x, y] = CLEAR
                        break
    return out


def shut_eyes(head, who):
    head = [list(r) for r in head]
    if who == "jeff":
        for c0 in (4, 12):
            head[10][c0] = head[10][c0 + 1] = "S"
            head[10][c0 - 1] = head[10][c0 + 2] = "E"
            head[11][c0] = head[11][c0 + 1] = "E"
    else:
        for c0 in (6, 12):
            head[10][c0] = head[10][c0 + 1] = "S"
            head[11][c0 - 1] = head[11][c0] = head[11][c0 + 1] = "E"
    return ["".join(r) for r in head]


def figure(who, pose, shovel=True, eyes_shut=False):
    legs_name, lift, hdx, barm, hand, ang, front, back = POSES[pose]
    L = char_legend(who)
    legs = LEGS[who][legs_name]
    im = Image.new("RGBA", (CW, 32), CLEAR)
    ly = 31 - len(legs) - lift
    ty = ly - 6
    hy = ty - 16
    if pose == "idle1" and who == "jeff":
        hy += 1
        ty += 1
    head = shut_eyes(HEAD[who], who) if eyes_shut else HEAD[who]
    torso = TORSO[who]
    if pose == "idle1" and who == "chuck":          # chest puff: head up 1, an extra chest row
        hy -= 1
        torso = [torso[0]] + torso
        ty -= 1
    # back arm first, shovel, body, then the front arm over the grip
    bdx, bdy = barm
    draw_arm(im, who, (GX + 2 + bdx, ty + 2 + bdy), (GX + 1 + bdx, ty + 4 + bdy + (0 if bdy >= 0 else 0)), back=True)
    if shovel:
        draw_shovel(im, hand, ang, front, back)
    grid(im, legs, L, GX, ly)
    grid(im, torso, L, GX, ty)
    grid(im, head, L, GX + hdx, hy)
    if shovel:
        draw_arm(im, who, (GX + 13, ty + 2), hand)
    else:
        draw_arm(im, who, (GX + 13, ty + 2), (GX + 14, ty + 4))
    return im


def make_player(who):
    rows = [("idle", ["idle0", "idle1"], 2), ("walk", ["walk0", "walk1", "walk2", "walk3"], 8),
            ("air", ["jump", "fall"], 0), ("dig_side", ["side0", "side1", "side2"], 10),
            ("dig_down", ["down0", "down1", "down2"], 10), ("ride", ["ride"], 0), ("sleep", ["sleep0", "sleep1"], 2)]
    sheet = Image.new("RGBA", (4 * CW, len(rows) * 32), CLEAR)
    man_rows = {}
    for ri, (name, frames, fps) in enumerate(rows):
        for fi, f in enumerate(frames):
            if f == "ride":
                body = figure(who, "idle0", shovel=False)
                im = Image.new("RGBA", (CW, 32), CLEAR)
                im.alpha_composite(body.crop((0, 0, CW, 14)), (0, 0))
                im = outline(im)
            elif f.startswith("sleep"):
                body = figure(who, "idle0", shovel=False, eyes_shut=True)
                if f == "sleep1":                      # breathing: the chest rises 1 px
                    b2 = body.copy()
                    chest = body.crop((0, 17, CW, 23))
                    b2.paste(Image.new("RGBA", (CW, 6), CLEAR), (0, 17))
                    b2.alpha_composite(chest, (-1, 17))
                    body = b2
                lying = body.rotate(-90, expand=True)      # head to the right
                bb = lying.getbbox()
                lying = lying.crop(bb)
                im = Image.new("RGBA", (CW, 32), CLEAR)
                im.alpha_composite(lying, ((CW - lying.width) // 2, 31 - lying.height))
                im = outline(im)
            else:
                im = outline(figure(who, f))
            sheet.alpha_composite(im, (fi * CW, ri * 32))
        man_rows[name] = {"row": ri, "frames": len(frames), "fps": fps}
    man_rows["air"]["names"] = ["jump", "fall"]
    man_rows["dig_side"]["hold"] = {"1": 2}
    man_rows["dig_down"]["hold"] = {"1": 2}
    save(sheet, "characters/%s.png" % who, env=False)
    MANIFEST[who] = {"file": "characters/%s.png" % who, "frame": [CW, 32], "pivot": [16, 32], "rows": man_rows,
                     "facing": "right", "hand": [23, 22],
                     "note": "ride = head and shoulders at the frame top; dig hit frame holds 2 ticks"}


# =============================================================================== residents
def bob(im, cut, col=rs.OUT):
    """Idle frame 2: everything above row `cut` sinks 1 px (a breath), re-outlined clean."""
    base = strip_outline(im, hp.hx(col))
    out = base.copy()
    top = base.crop((0, 0, base.width, cut))
    out.paste(Image.new("RGBA", (base.width, cut + 1), CLEAR), (0, 0))
    out.alpha_composite(top, (0, 1))
    return hp.outline(out, hp.hx(col))


def frozen(im):
    """The Caveman inside a pale ice block."""
    base = im.copy()
    block = Image.new("RGBA", im.size, CLEAR)
    d = ImageDraw.Draw(block)
    ice = R["ice"]
    d.rounded_rectangle([3, 1, 36, 30], 3, fill=A(ice[3], 90))
    d.rectangle([4, 27, 35, 29], fill=A(ice[2], 140))
    d.line([5, 2, 34, 2], fill=A(WHITE, 220))
    d.line([4, 3, 4, 25], fill=A(WHITE, 200))
    for x0, y0 in ((8, 12), (26, 6), (30, 20)):
        for i in range(4):
            d.point((x0 + i, y0 - i), fill=A(WHITE, 230))
    d.line([35, 4, 35, 29], fill=A(ice[1], 200))
    base.alpha_composite(block)
    return hp.outline(base, hp.hx(rs.OUT))


def make_residents():
    for name, fn, cut in (("mole", lambda: rs.mole("front", "idle", "squint"), 18),
                          ("foreman", lambda: rs.foreman("front", "idle"), 16),
                          ("caveman", lambda: rs.caveman("front", "idle", "delighted"), 20)):
        f0 = fn()
        f1 = bob(f0, cut)
        rows = [f0, f1]
        sheet = Image.new("RGBA", (80, 64 if name == "caveman" else 32), CLEAR)
        sheet.alpha_composite(f0, (0, 0))
        sheet.alpha_composite(f1, (40, 0))
        man = {"idle": {"row": 0, "frames": 2, "fps": 2}}
        if name == "caveman":
            sheet.alpha_composite(frozen(f0), (0, 32))
            man["frozen"] = {"row": 1, "frames": 1, "fps": 0}
        save(sheet, "characters/%s.png" % name, env=False)
        MANIFEST[name] = {"file": "characters/%s.png" % name, "frame": [40, 32], "pivot": [20, 32], "rows": man}
    # the Dragon, asleep around her hoard
    d0 = rs.dragon("asleep")
    hoard = Image.new("RGBA", d0.size, CLEAR)
    hd = ImageDraw.Draw(hoard)
    g = R["gold"]
    hd.ellipse([56, 54, 104, 78], fill=A(g[1]))
    hd.ellipse([58, 55, 101, 75], fill=A(g[2]))
    hd.ellipse([64, 56, 84, 64], fill=A(g[3]))
    r = rng("hoard")
    for _ in range(14):
        x, y = r.randrange(60, 100), r.randrange(57, 70)
        hd.ellipse([x, y, x + 3, y + 2], outline=A(g[1]))
    hd.point((70, 57), fill=A(WHITE))
    hd.point((88, 60), fill=A(WHITE))
    hd.polygon([(92, 58), (96, 56), (99, 58), (95, 63)], fill=A(hp.hx("#4FD6E0")))
    hd.point((95, 57), fill=A(WHITE))
    hoard = hoard.crop((0, 0, 160, 71))
    dd = strip_outline(d0, hp.hx(rs.OUT))
    body = Image.new("RGBA", d0.size, CLEAR)
    body.alpha_composite(dd)
    body.alpha_composite(hoard)
    f0 = hp.outline(body, hp.hx(rs.OUT))
    f1b = body.copy()
    top = body.crop((0, 0, 160, 44))
    f1b.paste(Image.new("RGBA", (160, 45), CLEAR), (0, 0))
    f1b.alpha_composite(top, (0, 1))
    f1b.alpha_composite(hoard)
    f1 = hp.outline(f1b, hp.hx(rs.OUT))
    sheet = Image.new("RGBA", (320, 72), CLEAR)
    sheet.alpha_composite(f0, (0, 0))
    sheet.alpha_composite(f1, (160, 0))
    save(sheet, "characters/dragon.png", env=False)
    MANIFEST["dragon"] = {"file": "characters/dragon.png", "frame": [160, 72], "pivot": [80, 72],
                          "rows": {"asleep": {"row": 0, "frames": 2, "fps": 1}}}


def make_characters():
    make_player("jeff")
    make_player("chuck")
    make_residents()


# =============================================================================== vehicles
# No faces (pixel-rules "Vehicle style: no faces"): one round nose lamp + one square roof work light.
STRIPES = {"cream": R["wall"][2], "green": R["p1"][2], "red": R["p2"][2]}
GLASS_A = 110
EXC = hp.ramp(hp.hx("#f5902a"), P)          # Excavator orange (hue 30, outside the red band)


def wheel(d, box, spokes, ramp_body):
    td, tl, tm, th = R["tyre"]
    vd, vl, vm, vh = ramp_body
    x0, y0, x1, y1 = box
    d.ellipse(box, fill=A(tm))
    d.arc([x0 + 1, y0 + 1, x1 - 1, y1 - 1], 190, 280, fill=A(th))
    d.arc([x0, y0, x1, y1], 20, 120, fill=A(td))
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = (x1 - x0) / 2
    hr = r * .52
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=A(vl))
    d.ellipse([cx - hr, cy - hr, cx + hr - 1, cy + hr - 1], fill=A(vm))
    md = R["metal"]
    d.rectangle([round(cx - .5), round(cy - .5), round(cx + .5) - 0, round(cy + .5) - 0], fill=A(md[1]))
    for k in range(4):
        a = math.radians(k * 90 + (45 if spokes else 0))
        sx, sy = cx + math.cos(a) * (r - 1.6), cy + math.sin(a) * (r - 1.6)
        d.point((round(sx - .5), round(sy - .5)), fill=A(td))


def glass(im, box):
    d = ImageDraw.Draw(im)
    gd, gl, gm, gh = R["glass"]
    d.rectangle(box, fill=A(gm, GLASS_A))
    x0, y0, x1, y1 = box
    d.line([x0, y0, x1, y0], fill=A(gl, 170))
    for k in (0, 2):
        for i in range(4):
            d.point((x0 + 2 + k + i, y1 - 2 - i), fill=A(gh, 190))


def nose_lamp(d, x, y):
    """6 px round lamp: metal rim, pale warm lens, one white glint. (x, y) = top-left."""
    md, ml, mm, mh = R["metal"]
    d.ellipse([x, y, x + 5, y + 5], fill=A(ml))
    d.ellipse([x + 1, y + 1, x + 4, y + 4], fill=A(LAMP))
    d.point((x + 2, y + 1), fill=A(WHITE))
    return (x + 3, y + 3)


def roof_lamp(d, x, y):
    md, ml, mm, mh = R["metal"]
    d.rectangle([x, y, x + 3, y + 2], fill=A(ml))
    d.rectangle([x + 1, y + 1, x + 3, y + 2], fill=A(LAMP))
    return (x + 2, y + 1)


def loader_body(stripe, bob, spokes):
    """48x34, facing right. Body layer bobs, wheels stay put."""
    W, H = 48, 34
    vd, vl, vm, vh = R["veh"]
    md, ml, mm, mh = R["metal"]
    body = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(body)
    sc = STRIPES[stripe]
    # boom arm from the cab front down to the hinge (bucket is its own sprite)
    d.line([20, 13, 42, 22], fill=A(vl), width=3)
    d.line([20, 12, 41, 21], fill=A(vm), width=1)
    d.line([24, 18, 38, 24], fill=A(mm), width=1)                  # hydraulic ram
    # chassis, counterweight, stripe
    d.rounded_rectangle([3, 17, 6, 25], 2, fill=A(vl))
    d.rounded_rectangle([4, 16, 38, 26], 3, fill=A(vm))
    d.line([6, 16, 36, 16], fill=A(vh))
    d.rectangle([5, 24, 37, 26], fill=A(vl))
    d.rectangle([5, 20, 37, 21], fill=A(sc))
    # hood: rounded, two vent slots, ONE round nose lamp
    d.rounded_rectangle([21, 11, 39, 23], 3, fill=A(vm))
    d.line([23, 11, 36, 11], fill=A(vh))
    d.line([22, 12, 30, 12], fill=A(vh))
    for x in (27, 30, 33):
        d.line([x, 14, x, 18], fill=A(vl))
    d.rectangle([21, 20, 39, 21], fill=A(sc))
    nl = nose_lamp(d, 36, 13)
    # exhaust
    d.rectangle([24, 4, 25, 11], fill=A(mm))
    d.point((24, 5), fill=A(mh))
    d.rectangle([23, 3, 26, 4], fill=A(ml))
    # cab, glass, roof in the driver's colour, square work light
    d.rounded_rectangle([5, 4, 21, 19], 2, fill=A(vm))
    d.line([6, 5, 6, 18], fill=A(vh))
    glass(body, [8, 7, 19, 15])
    d = ImageDraw.Draw(body)
    d.rectangle([5, 16, 21, 17], fill=A(vl))
    d.rounded_rectangle([4, 2, 22, 4], 1, fill=A(sc))
    d.line([5, 2, 20, 2], fill=A(hp.ramp(sc, P)[3]))
    rl = roof_lamp(d, 18, 0)
    d.point((43, 22), fill=A(md))
    d.point((42, 21), fill=A(ml))
    wl = Image.new("RGBA", (W, H), CLEAR)
    wd = ImageDraw.Draw(wl)
    wheel(wd, [6, 18, 20, 32], spokes, R["veh"])
    wheel(wd, [27, 21, 38, 32], spokes, R["veh"])
    im = Image.new("RGBA", (W, H), CLEAR)
    im.alpha_composite(wl)
    im.alpha_composite(body, (0, bob))
    # wheels in front of the chassis bottom edge
    im.alpha_composite(wl.crop((0, 26, W, H)), (0, 26))
    return outline(im), {"nose_lamp": [nl[0], nl[1] + bob], "roof_lamp": [rl[0], rl[1] + bob]}


BUCKET = [(1, -2), (5, -2), (15, 7), (16, 10), (14, 12), (3, 12), (0, 10), (-2, 5), (-1, 0)]
BUCKET_IN = [(5, 0), (13, 8), (11, 9), (4, 2)]


def rot(pts, a, ox, oy, s=1.0):
    ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
    return [(ox + s * (x * ca - y * sa), oy + s * (x * sa + y * ca)) for x, y in pts]


def draw_bucket(im, ox, oy, a, s=1.0):
    d = ImageDraw.Draw(im)
    md, ml, mm, mh = R["metal"]
    pts = rot(BUCKET, a, ox, oy, s)
    d.polygon(pts, fill=A(mm))
    d.line(pts[1:3], fill=A(mh))                                     # the open rim, lit
    d.line(pts[-3:], fill=A(mh))                                      # rounded back, lit
    d.line(pts[3:6], fill=A(ml))                                      # underside
    d.polygon(rot(BUCKET_IN, a, ox, oy, s), fill=A(md))
    for tx, ty in ((16.5, 11), (14, 12.5)):                           # chunky teeth, round tips
        (cx, cy), = rot([(tx, ty)], a, ox, oy, s)
        d.ellipse([cx - 1.5, cy - 1.2, cx + 1.5, cy + 1.2], fill=A(mh))
    d.ellipse([ox - 1.5, oy - 1.5, ox + 1.5, oy + 1.5], fill=A(ml))   # hinge pin
    d.point((round(ox - .5), round(oy - .5)), fill=A(md))


def make_front_loader():
    W, H = 48, 34
    sheet = Image.new("RGBA", (4 * W, 3 * H), CLEAR)
    pts = {}
    for ri, stripe in enumerate(("cream", "green", "red")):
        for ci, (bob, spokes) in enumerate(((0, False), (1, False), (0, False), (0, True))):
            im, pts = loader_body(stripe, bob, spokes)
            sheet.alpha_composite(im, (ci * W, ri * H))
    save(sheet, "vehicles/front_loader.png")
    MANIFEST["front_loader"] = {
        "file": "vehicles/front_loader.png", "frame": [W, H], "pivot": [20, 34], "box": [28, 26],
        "rows": {"cream": {"row": 0, "frames": 4, "fps": 2}, "green": {"row": 1, "frames": 4, "fps": 2},
                 "red": {"row": 2, "frames": 4, "fps": 2}},
        "columns": {"idle": [0, 1], "drive": [2, 3]},
        "head": [14, 38], "nose_lamp": pts["nose_lamp"], "roof_lamp": pts["roof_lamp"], "bucket": [43, 22],
        "note": "rows = stripe/roof colour: cream empty, green P1, red P2. Draw the driver's ride frame "
                "with its pivot on `head`, behind the body; the glass is see-through."}
    BW = 40
    bs = Image.new("RGBA", (3 * BW, BW), CLEAR)
    for i, a in enumerate((0, -40, -85)):
        f = Image.new("RGBA", (BW, BW), CLEAR)
        draw_bucket(f, 20, 20, a)
        bs.alpha_composite(outline(f), (i * BW, 0))
    save(bs, "vehicles/front_loader_bucket.png")
    MANIFEST["front_loader_bucket"] = {"file": "vehicles/front_loader_bucket.png", "frame": [BW, BW], "pivot": [20, 20],
                                       "rows": {"tool": {"row": 0, "frames": 3, "fps": 0, "names": ["rest", "mid", "full"]}}}


def excavator_body(stripe, bob, tread):
    W, H = 56, 44
    vd, vl, vm, vh = EXC
    md, ml, mm, mh = R["metal"]
    td, tl, tm, th = R["tyre"]
    sc = STRIPES[stripe]
    tr = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(tr)
    d.rectangle([14, 29, 40, 33], fill=A(ml))
    d.rounded_rectangle([6, 33, 48, 42], 4, fill=A(tm))
    d.line([9, 33, 45, 33], fill=A(th))
    d.rounded_rectangle([9, 35, 45, 40], 2, fill=A(tl))
    for x in range(8 + tread * 2, 47, 4):
        d.point((x, 34), fill=A(td))
        d.point((x, 42), fill=A(td))
    for x in (12, 20, 27, 34, 42):
        d.ellipse([x - 2, 35, x + 2, 39], fill=A(mm))
        d.point((x - 1, 36), fill=A(mh))
    body = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([3, 19, 12, 30], 3, fill=A(vl))                # counterweight
    d.rounded_rectangle([5, 18, 47, 30], 4, fill=A(vm))
    d.line([8, 18, 44, 18], fill=A(vh))
    d.rectangle([6, 28, 46, 30], fill=A(vl))
    d.rectangle([6, 23, 46, 24], fill=A(sc))
    nl = nose_lamp(d, 43, 19)
    d.rectangle([30, 10, 31, 18], fill=A(mm))                         # exhaust
    d.rectangle([29, 9, 32, 10], fill=A(ml))
    d.rounded_rectangle([9, 4, 26, 21], 2, fill=A(vm))                 # cab
    d.line([10, 5, 10, 20], fill=A(vh))
    glass(body, [12, 7, 24, 16])
    d = ImageDraw.Draw(body)
    d.rectangle([9, 17, 26, 18], fill=A(vl))
    d.rounded_rectangle([8, 2, 27, 4], 1, fill=A(sc))
    d.line([9, 2, 26, 2], fill=A(hp.ramp(sc, P)[3]))
    rl = roof_lamp(d, 23, 0)
    d.ellipse([35, 17, 40, 22], fill=A(ml))                           # boom root pin
    d.point((37, 19), fill=A(md))
    im = Image.new("RGBA", (W, H), CLEAR)
    im.alpha_composite(tr)
    im.alpha_composite(body, (0, bob))
    return outline(im), {"nose_lamp": [nl[0], nl[1] + bob], "roof_lamp": [rl[0], rl[1] + bob]}


def make_excavator():
    W, H = 56, 44
    sheet = Image.new("RGBA", (4 * W, 3 * H), CLEAR)
    for ri, stripe in enumerate(("cream", "green", "red")):
        for ci, (bob, tread) in enumerate(((0, 0), (1, 0), (0, 0), (0, 1))):
            im, pts = excavator_body(stripe, bob, tread)
            sheet.alpha_composite(im, (ci * W, ri * H))
    save(sheet, "vehicles/excavator.png")
    MANIFEST["excavator"] = {
        "file": "vehicles/excavator.png", "frame": [W, H], "pivot": [28, 44], "box": [40, 40],
        "rows": {"cream": {"row": 0, "frames": 4, "fps": 2}, "green": {"row": 1, "frames": 4, "fps": 2},
                 "red": {"row": 2, "frames": 4, "fps": 2}},
        "columns": {"idle": [0, 1], "drive": [2, 3]},
        "head": [18, 38], "nose_lamp": pts["nose_lamp"], "roof_lamp": pts["roof_lamp"], "arm": [37, 19],
        "note": "drive frames move the track treads; the arm is its own sprite with its pivot on `arm`"}
    # arm: boom up from the root, stick down to the bucket. Root at (8, 30) in a 56x60 frame.
    AW, AH = 56, 60
    ox, oy = 8, 30
    arms = Image.new("RGBA", (3 * AW, AH), CLEAR)
    vd, vl, vm, vh = EXC
    md, ml, mm, mh = R["metal"]
    poses = [((20, -14), (32, 8), 20), ((20, -17), (34, -2), -30), ((18, -20), (30, -14), -80)]
    for i, ((ex, ey), (wx, wy), ba) in enumerate(poses):
        f = Image.new("RGBA", (AW, AH), CLEAR)
        d = ImageDraw.Draw(f)
        E, Wr = (ox + ex, oy + ey), (ox + wx, oy + wy)
        d.line([(ox, oy), E], fill=A(vl), width=6)
        d.line([(ox, oy - 2), (E[0], E[1] - 2)], fill=A(vm), width=3)
        d.line([(ox, oy - 3), (E[0] - 1, E[1] - 3)], fill=A(vh), width=1)
        d.line([(ox + 3, oy + 2), (E[0] - 3, E[1] + 3)], fill=A(mm), width=1)   # ram
        d.line([E, Wr], fill=A(vl), width=4)
        d.line([(E[0] - 1, E[1]), (Wr[0] - 1, Wr[1])], fill=A(vm), width=2)
        d.ellipse([E[0] - 2, E[1] - 2, E[0] + 2, E[1] + 2], fill=A(ml))
        draw_bucket(f, Wr[0], Wr[1], ba + 0, .85)
        arms.alpha_composite(outline(f), (i * AW, 0))
    save(arms, "vehicles/excavator_arm.png")
    MANIFEST["excavator_arm"] = {"file": "vehicles/excavator_arm.png", "frame": [AW, AH], "pivot": [ox, oy],
                                 "rows": {"tool": {"row": 0, "frames": 3, "fps": 0, "names": ["rest", "mid", "full"]}}}


def make_vehicles():
    make_front_loader()
    make_excavator()


# =============================================================================== buildings
def planks(im, box, r4, step=6, horiz=False, seed=1):
    hp.planks(im, box, r4, step=step, horiz=horiz, seed=seed)


def win(d, box, frame_c, lit_d=None, panes=True):
    """Window: frame, glass, cross panes. Glass pixels also go on the lit layer."""
    x0, y0, x1, y1 = box
    gd, gl, gm, gh = R["glass"]
    d.rectangle(box, fill=A(frame_c))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=A(gm))
    d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=A(gl))
    d.line([x0 + 2, y1 - 2, x0 + 4, y1 - 4], fill=A(WHITE))
    if panes:
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        d.line([cx, y0 + 1, cx, y1 - 1], fill=A(frame_c))
        d.line([x0 + 1, cy, x1 - 1, cy], fill=A(frame_c))
    if lit_d is not None:
        lit_d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=A(LIT_WIN))
        if panes:
            lit_d.line([cx, y0 + 1, cx, y1 - 1], fill=CLEAR)
            lit_d.line([x0 + 1, cy, x1 - 1, cy], fill=CLEAR)


def finish(im, lit=None):
    """Outline the building; the lit layer keeps only pixels that sit on the building."""
    o = outline(im)
    if lit is None:
        return o, None
    a = o.split()[3]
    out = Image.new("RGBA", o.size, CLEAR)
    out.paste(lit, (0, 0), Image.eval(a, lambda v: 255 if v else 0))
    return o, out


def barn():
    W = H = 96
    im, lit = Image.new("RGBA", (W, H), CLEAR), Image.new("RGBA", (W, H), CLEAR)
    b, rf, cr = R["barn"], R["roof2"], R["wall"]
    d, ld = ImageDraw.Draw(im), ImageDraw.Draw(lit)
    d.polygon([(1, 46), (11, 23), (31, 6), (64, 6), (84, 23), (94, 46)], fill=A(rf[2]))
    d.line([(1, 46), (11, 23), (31, 6), (64, 6)], fill=A(rf[3]))
    d.line([(64, 7), (84, 24), (93, 46)], fill=A(rf[1]))
    planks(im, (8, 46, 87, 94), b, step=6, seed=3)
    d = ImageDraw.Draw(im)
    d.polygon([(8, 46), (17, 26), (34, 12), (61, 12), (78, 26), (87, 46)], fill=A(b[2]))
    for x in range(13, 87, 6):
        d.line([x, 14 if 33 < x < 62 else (27 if 18 < x < 77 else 40), x, 46], fill=A(b[1]))
    trim = [(8, 46), (17, 26), (34, 12), (61, 12), (78, 26), (87, 46)]
    d.line(trim, fill=A(cr[2]), width=2)
    d.rectangle([8, 45, 87, 46], fill=A(cr[2]))
    # hayloft
    d.rectangle([39, 20, 56, 36], fill=A(cr[2]))
    d.rectangle([41, 22, 54, 34], fill=A(P["back"]["top"][1]))
    ld.rectangle([41, 22, 54, 29], fill=A(LIT_WIN))
    d.rectangle([41, 30, 54, 34], fill=A(R["gold"][2]))
    d.line([42, 29, 53, 29], fill=A(R["gold"][3]))
    # side windows
    win(d, [13, 56, 23, 66], cr[2], ld)
    win(d, [72, 56, 82, 66], cr[2], ld)
    # big X door
    d.rectangle([30, 56, 65, 94], fill=A(cr[2]))
    d.rectangle([32, 58, 63, 94], fill=A(b[1]))
    d.line([32, 58, 47, 94], fill=A(cr[2]), width=2)
    d.line([47, 58, 32, 94], fill=A(cr[2]), width=2)
    d.line([48, 58, 63, 94], fill=A(cr[2]), width=2)
    d.line([63, 58, 48, 94], fill=A(cr[2]), width=2)
    d.line([47, 58, 47, 94], fill=A(cr[1]))
    d.line([48, 58, 48, 94], fill=A(cr[2]))
    d.rectangle([8, 92, 30, 94], fill=A(b[0]))
    d.rectangle([66, 92, 87, 94], fill=A(b[0]))
    return finish(im, lit)


def house():
    W = H = 96
    im, lit = Image.new("RGBA", (W, H), CLEAR), Image.new("RGBA", (W, H), CLEAR)
    wl, rf, wd = R["wall"], R["roof"], R["wood"]
    planks(im, (62, 8, 72, 30), R["barn"], step=4, horiz=True, seed=5)
    planks(im, (10, 44, 86, 94), wl, step=5, horiz=True, seed=7)
    d, ld = ImageDraw.Draw(im), ImageDraw.Draw(lit)
    d.rectangle([60, 6, 74, 8], fill=A(R["barn"][1]))
    d.polygon([(2, 46), (24, 16), (72, 16), (94, 46)], fill=A(rf[2]))
    for y in range(21, 46, 5):
        x0 = 2 + (46 - y) * 22 // 30
        d.line([x0 + 1, y, 96 - x0 - 3, y], fill=A(rf[1]))
        for x in range(x0 + 3 + (y % 10), 96 - x0 - 3, 9):
            d.line([x, y, x, y + 4], fill=A(rf[1]))
    d.line([(3, 45), (24, 16), (72, 16)], fill=A(rf[3]))
    d.line([(72, 17), (93, 45)], fill=A(rf[0]))
    d.rectangle([2, 45, 94, 47], fill=A(rf[0]))
    # attic round window
    d.ellipse([42, 24, 54, 36], fill=A(wd[1]))
    d.ellipse([44, 26, 52, 34], fill=A(R["glass"][2]))
    ld.ellipse([44, 26, 52, 34], fill=A(LIT_WIN))
    d.line([48, 26, 48, 34], fill=A(wd[1]))
    ld.line([48, 26, 48, 34], fill=CLEAR)
    # door
    d.rectangle([18, 60, 35, 94], fill=A(wd[1]))
    d.rectangle([20, 62, 33, 94], fill=A(wd[2]))
    d.line([20, 62, 20, 94], fill=A(wd[3]))
    d.rectangle([23, 66, 30, 72], fill=A(R["glass"][2]))
    ld.rectangle([23, 66, 30, 72], fill=A(LIT_WIN))
    d.rectangle([30, 79, 31, 80], fill=A(R["gold"][2]))
    d.rectangle([16, 92, 37, 94], fill=A(R["rock"][1]))
    # window with flower box
    win(d, [48, 56, 76, 76], wd[1], ld)
    d.rectangle([46, 77, 78, 81], fill=A(wd[2]))
    d.line([46, 77, 78, 77], fill=A(wd[3]))
    for i, x in enumerate(range(48, 78, 3)):
        d.point((x, 76), fill=A(C["pink"] if i % 2 else R["gold"][2]))
        d.point((x + 1, 76), fill=A(R["leaf"][2]))
    d.rectangle([10, 92, 86, 94], fill=A(wl[0]))
    return finish(im, lit)


def garage(door):
    W, H = 144, 96
    im, lit = Image.new("RGBA", (W, H), CLEAR), Image.new("RGBA", (W, H), CLEAR)
    wl, rf, wd, mt = R["wall"], R["roof"], R["wood"], R["metal"]
    planks(im, (8, 30, 136, 94), wl, step=5, horiz=True, seed=9)
    d, ld = ImageDraw.Draw(im), ImageDraw.Draw(lit)
    d.polygon([(2, 32), (12, 14), (132, 14), (142, 32)], fill=A(rf[2]))
    for y in (19, 24, 29):
        d.line([4 + (32 - y) // 2, y, 140 - (32 - y) // 2, y], fill=A(rf[1]))
    d.line([(3, 31), (12, 14), (132, 14)], fill=A(rf[3]))
    d.line([(132, 15), (141, 31)], fill=A(rf[0]))
    d.rectangle([2, 31, 142, 33], fill=A(rf[0]))
    # sign plate with a wrench (no text)
    d.rounded_rectangle([58, 18, 86, 28], 2, fill=A(R["gold"][2]))
    d.line([59, 18, 85, 18], fill=A(R["gold"][3]))
    d.line([64, 23, 79, 23], fill=A(mt[1]), width=2)
    d.ellipse([62, 20, 67, 26], fill=A(mt[1]))
    d.point((63, 22), fill=A(R["gold"][2]))
    d.ellipse([77, 21, 81, 25], fill=A(mt[1]))
    # door opening and roller door
    x0, y0, x1, y1 = 28, 42, 108, 94
    d.rectangle([x0 - 3, y0 - 3, x1 + 3, y1], fill=A(wd[1]))
    d.line([x0 - 3, y0 - 3, x1 + 3, y0 - 3], fill=A(wd[3]))
    inside = P["back"]["top"][0]
    d.rectangle([x0, y0, x1, y1], fill=A(inside))
    d.rectangle([x0, y1 - 3, x1, y1], fill=A(P["back"]["top"][1]))
    # a tool board and a hanging bulb inside, seen when the door is up
    d.rectangle([x0 + 6, y0 + 10, x0 + 24, y0 + 22], fill=A(wd[1]))
    for k, c in enumerate((mt[2], R["gold"][2], mt[3])):
        d.line([x0 + 9 + k * 5, y0 + 12, x0 + 9 + k * 5, y0 + 19], fill=A(c), width=2)
    d.line([70, y0, 70, y0 + 8], fill=A(mt[0]))
    d.ellipse([67, y0 + 8, 73, y0 + 14], fill=A(LAMP))
    ld.ellipse([64, y0 + 6, 76, y0 + 17], fill=A(LIT_WIN))
    shut = round((y1 - y0 + 1) * (1 - door))
    if shut > 0:
        d.rectangle([x0, y0, x1, y0 + shut - 1], fill=A(mt[2]))
        ld.rectangle([x0, y0, x1, y0 + shut - 1], fill=CLEAR)
        for y in range(y0 + 4, y0 + shut, 5):
            d.line([x0, y, x1, y], fill=A(mt[1]))
            d.line([x0, y - 1, x1, y - 1], fill=A(mt[3])) if y - 1 > y0 else None
        d.rectangle([x0, y0 + shut - 2, x1, y0 + shut - 1], fill=A(mt[0]))
        d.rectangle([64, y0 + shut - 5, 72, y0 + shut - 4], fill=A(mt[0]))   # handle
    # side windows and the lamp over the door
    win(d, [114, 46, 130, 60], wd[1], ld)
    win(d, [11, 46, 21, 60], wd[1], ld)
    d.rectangle([66, 33, 74, 35], fill=A(mt[1]))
    d.rectangle([67, 36, 73, 37], fill=A(LAMP))
    ld.rectangle([67, 36, 73, 37], fill=A(LIT_WIN))
    d.rectangle([8, 92, 25, 94], fill=A(wl[0]))
    d.rectangle([111, 92, 136, 94], fill=A(wl[0]))
    return finish(im, lit)


def lighthouse():
    W, H = 48, 144
    im, lit = Image.new("RGBA", (W, H), CLEAR), Image.new("RGBA", (W, H), CLEAR)
    d, ld = ImageDraw.Draw(im), ImageDraw.Draw(lit)
    wl, rf, mt, rk = R["wall"], R["roof"], R["metal"], R["rock"]
    top, bot = 42, 130
    for y in range(top, bot + 1):
        t = (y - top) / (bot - top)
        hw = round(10 + 5 * t)
        band = ((y - top) // 14) % 2 == 1
        col = rf if band else wl
        d.line([24 - hw, y, 23 + hw, y], fill=A(col[2]))
        d.point((24 - hw, y), fill=A(col[3]))
        d.point((24 - hw + 1, y), fill=A(col[3]))
        d.point((23 + hw, y), fill=A(col[1]))
        d.point((22 + hw, y), fill=A(col[1]))
    d.rounded_rectangle([3, 128, 44, 142], 3, fill=A(rk[2]))
    d.line([5, 128, 42, 128], fill=A(rk[3]))
    d.rectangle([4, 140, 43, 142], fill=A(rk[1]))
    for x in (10, 19, 30, 38):
        d.line([x, 131, x, 139], fill=A(rk[1]))
    # door
    d.rectangle([19, 114, 28, 128], fill=A(R["wood"][1]))
    d.rectangle([20, 116, 27, 128], fill=A(R["wood"][2]))
    d.rectangle([19, 113, 28, 114], fill=A(R["wood"][1]))
    # window slits
    for y in (64, 92):
        d.rectangle([21, y, 26, y + 7], fill=A(R["wood"][1]))
        d.rectangle([22, y + 1, 25, y + 6], fill=A(R["glass"][2]))
        ld.rectangle([22, y + 1, 25, y + 6], fill=A(LIT_WIN))
    # gallery and railing
    d.rectangle([7, 37, 40, 41], fill=A(mt[2]))
    d.line([7, 37, 40, 37], fill=A(mt[3]))
    d.line([8, 41, 40, 41], fill=A(mt[0]))
    for x in range(8, 41, 4):
        d.line([x, 31, x, 36], fill=A(mt[1]))
    d.line([8, 31, 39, 31], fill=A(mt[1]))
    # lantern room
    d.rectangle([14, 18, 33, 36], fill=A(mt[1]))
    d.rectangle([16, 20, 31, 35], fill=A(R["glass"][2]))
    d.ellipse([19, 22, 28, 31], fill=A(LAMP))
    d.point((21, 24), fill=A(WHITE))
    ld.rectangle([16, 20, 31, 35], fill=A(LIT_WIN))
    for x in (20, 27):
        d.line([x, 20, x, 35], fill=A(mt[1]))
        ld.line([x, 20, x, 35], fill=CLEAR)
    ld.ellipse([19, 22, 28, 31], fill=A(hp.hx("#fff6c8")))
    # dome
    d.pieslice([11, 6, 36, 30], 180, 360, fill=A(rf[2]))
    d.arc([11, 6, 36, 30], 190, 260, fill=A(rf[3]))
    d.rectangle([11, 17, 36, 18], fill=A(rf[0]))
    d.line([23, 1, 23, 6], fill=A(mt[1]))
    d.point((23, 1), fill=A(R["gold"][2]))
    return finish(im, lit)


def headframe():
    W, H = 96, 124
    im, lit = Image.new("RGBA", (W, H), CLEAR), Image.new("RGBA", (W, H), CLEAR)
    d, ld = ImageDraw.Draw(im), ImageDraw.Draw(lit)
    w, m = R["wood"], R["metal"]
    cx = 48
    # cable first (behind the beams)
    d.line([cx, 16, cx, 86], fill=A(m[0]))
    for s in (-1, 1):
        x0, x1 = cx + 32 * s, cx + 8 * s
        d.line([x0, 122, x1, 18], fill=A(w[1]), width=5)
        d.line([x0 - s, 122, x1 - s, 18], fill=A(w[2]), width=3)
        d.line([x0 - 2, 122, x1 - 2, 18], fill=A(w[3]))
    for y in (48, 80):
        half = round(32 - (124 - y) / 104 * 24)
        d.rectangle([cx - half - 1, y - 2, cx + half + 1, y + 2], fill=A(w[1]))
        d.line([cx - half - 1, y - 2, cx + half + 1, y - 2], fill=A(w[3]))
    d.line([cx - 15, 50, cx + 21, 78], fill=A(w[1]), width=2)
    d.line([cx + 15, 50, cx - 21, 78], fill=A(w[1]), width=2)
    # head beam, little roof, wheel
    d.rectangle([cx - 16, 22, cx + 16, 26], fill=A(w[2]))
    d.line([cx - 16, 22, cx + 16, 22], fill=A(w[3]))
    d.polygon([(cx - 20, 6), (cx, 0), (cx + 20, 6)], fill=A(R["roof2"][2]))
    d.line([(cx - 20, 6), (cx, 0)], fill=A(R["roof2"][3]))
    d.ellipse([cx - 12, 4, cx + 12, 28], fill=A(m[1]))
    d.ellipse([cx - 11, 5, cx + 10, 26], fill=A(m[2]))
    d.ellipse([cx - 8, 8, cx + 7, 23], fill=A(m[0]))
    d.ellipse([cx - 6, 10, cx + 5, 21], fill=A(m[2]))
    for a in range(0, 360, 60):
        d.line([cx, 16, cx + round(6 * math.cos(math.radians(a))), 16 + round(6 * math.sin(math.radians(a)))], fill=A(m[1]))
    d.ellipse([cx - 2, 14, cx + 1, 17], fill=A(m[3]))
    d.arc([cx - 11, 5, cx + 10, 26], 200, 260, fill=A(m[3]))
    # cage at the bottom (34 x 37, as the code's cage)
    d.rectangle([cx - 17, 87, cx + 16, 123], outline=A(m[2]))
    d.rectangle([cx - 17, 85, cx + 16, 89], fill=A(R["gold"][2]))
    d.line([cx - 17, 85, cx + 16, 85], fill=A(R["gold"][3]))
    d.rectangle([cx - 17, 121, cx + 16, 123], fill=A(m[1]))
    for x in (-9, -3, 3, 9):
        d.line([cx + x, 90, cx + x, 120], fill=A(m[1]))
    d.line([cx - 16, 90, cx - 16, 120], fill=A(m[3]))
    # lantern on the right leg
    lx, ly = 70, 56
    d.line([lx - 4, ly - 4, lx, ly - 4], fill=A(m[0]))
    d.line([lx, ly - 4, lx, ly - 1], fill=A(m[0]))
    d.rectangle([lx - 2, ly, lx + 2, ly + 1], fill=A(m[1]))
    d.rectangle([lx - 2, ly + 2, lx + 2, ly + 6], fill=A(R["gold"][2]))
    d.point((lx - 1, ly + 3), fill=A(WHITE))
    d.rectangle([lx - 2, ly + 7, lx + 2, ly + 7], fill=A(m[1]))
    ld.rectangle([lx - 2, ly + 2, lx + 2, ly + 6], fill=A(hp.hx("#fff2b0")))
    o, l = finish(im, lit)
    return o, l, {"lantern": [lx, ly + 4], "wheel": [cx, 16], "cage": [cx - 17, 85, 34, 39]}


# ---- ruins: weathered, gaps, moss, leaning; a dark door gap for a resident silhouette
def moss(d, spots):
    g = R["grass"]
    for x, y, w in spots:
        d.rectangle([x, y, x + w, y + 1], fill=A(g[2]))
        d.point((x + 1, y + 2), fill=A(g[1]))
        d.point((x, y), fill=A(g[3]))


def lean(im, dx_per_row, pivot_y):
    """Pixel-clean lean: each row shifts by (pivot_y - y) * dx_per_row."""
    out = Image.new("RGBA", im.size, CLEAR)
    for y in range(im.height):
        out.alpha_composite(im.crop((0, y, im.width, y + 1)), (round((pivot_y - y) * dx_per_row), y))
    return out


def stones(im, box, r4, seed, rows=7, gaps=()):
    """Dressed stone blocks, lit top-left, joints in low."""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(im)
    dp, lo, mid, hi = r4
    d.rectangle(box, fill=A(mid))
    r = rng("stones", seed)
    y = y0
    k = 0
    while y < y1:
        hgt = rows + r.randrange(-1, 2)
        x = x0 - (k % 2) * 5
        while x < x1:
            w = r.randrange(9, 15)
            bx0, bx1, by1 = max(x, x0), min(x + w - 1, x1), min(y + hgt - 1, y1)
            c = mid if r.random() < .75 else (hi if r.random() < .4 else lo)
            d.rectangle([bx0, y, bx1, by1], fill=A(c))
            d.line([bx0, y, bx1, y], fill=A(hi))
            d.line([bx1, y, bx1, by1], fill=A(lo))
            d.line([bx0, by1, bx1, by1], fill=A(lo))
            x += w
        y += hgt
        k += 1
    for gx0, gy0, gx1, gy1 in gaps:
        d.rectangle([gx0, gy0, gx1, gy1], fill=CLEAR)


def door_gap(d, box):
    x0, y0, x1, y1 = box
    dark, darker = P["back"]["top"]
    d.rectangle([x0, y0 + 4, x1, y1], fill=A(darker))
    d.pieslice([x0, y0, x1, y0 + 8], 180, 360, fill=A(darker))
    d.line([x0 + 1, y1, x1 - 1, y1], fill=A(dark))
    return [(x0 + x1 + 1) // 2, (y0 + y1 + 1) // 2]


def old_shed():
    W = H = 96
    k, rf = R["weath"], R["roof"]
    base = Image.new("RGBA", (W, H), CLEAR)
    planks(base, (14, 40, 70, 94), k, step=6, seed=11)
    d = ImageDraw.Draw(base)
    dark = P["back"]["top"][1]
    for x0, ytop in ((20, 52), (56, 62)):                           # missing planks
        d.rectangle([x0, ytop, x0 + 4, 94], fill=A(dark))
    d.rectangle([62, 40, 70, 50], fill=CLEAR)                        # a bitten corner
    door = door_gap(d, [32, 58, 50, 94])
    d.polygon([(51, 60), (60, 63), (58, 94), (50, 92)], fill=A(k[1]))   # door off its hinge
    d.line([(51, 60), (60, 63)], fill=A(k[3]))
    shed = lean(base, 1 / 9, 94)
    d = ImageDraw.Draw(shed)
    # what is left of the roof, slid down one side
    d.polygon([(4, 44), (20, 24), (52, 30), (46, 42)], fill=A(rf[1]))
    d.line([(5, 43), (20, 24), (52, 30)], fill=A(rf[3]))
    d.line([(46, 42), (6, 45)], fill=A(rf[0]))
    d.polygon([(60, 48), (90, 78), (86, 84), (56, 54)], fill=A(k[1]))  # fallen wall half
    d.line([(60, 48), (90, 78)], fill=A(k[3]))
    d.rectangle([72, 90, 93, 93], fill=A(k[2]))                       # loose board
    d.line([72, 90, 93, 90], fill=A(k[3]))
    moss(d, [(10, 44, 6), (26, 27, 5), (58, 52, 5), (16, 88, 5), (76, 88, 4), (66, 64, 3)])
    o, _ = finish(shed)
    return o, {"door": [door[0] + round((94 - door[1]) / 9), door[1]]}


def crooked_watchtower():
    W, H = 96, 144
    k = R["weath"]
    base = Image.new("RGBA", (W, H), CLEAR)
    stones(base, (26, 44, 66, 142), k, "tower", rows=8, gaps=[(58, 44, 66, 56), (62, 56, 66, 62)])
    d = ImageDraw.Draw(base)
    door = door_gap(d, [37, 114, 55, 142])
    d.rectangle([42, 70, 49, 80], fill=A(P["back"]["top"][1]))       # a dark window
    d.line([28, 90, 34, 96], fill=A(k[0]))
    d.line([34, 96, 33, 102], fill=A(k[0]))
    tw = lean(base, 1 / 7, 142)
    d = ImageDraw.Draw(tw)
    wd, r2 = R["wood"], R["roof2"]
    # broken platform and a crooked roof, the tower leans right
    d.polygon([(36, 44), (90, 38), (88, 44), (38, 49)], fill=A(wd[2]))
    d.line([(36, 44), (90, 38)], fill=A(wd[3]))
    for x in (44, 60, 76):
        d.line([x, 47 - (x - 36) // 9, x - 2, 56 - (x - 36) // 9], fill=A(wd[1]), width=2)
    d.polygon([(42, 38), (62, 6), (86, 30), (74, 32), (64, 22), (60, 36)], fill=A(r2[2]))
    d.line([(42, 38), (62, 6)], fill=A(r2[3]))
    d.line([(62, 6), (86, 30)], fill=A(r2[1]))
    d.line([(62, 9), (62, 36)], fill=A(wd[1]))
    moss(d, [(30, 128, 6), (54, 100, 4), (44, 60, 5), (70, 40, 4)])
    for x, y in ((16, 140), (20, 139), (74, 140)):                    # rubble
        d.ellipse([x, y - 3, x + 5, y + 2], fill=A(k[1]))
        d.point((x + 1, y - 2), fill=A(k[3]))
    o, _ = finish(tw)
    shift = round((142 - door[1]) / 7)
    return o, {"door": [door[0] + shift, door[1]]}


def flooded_cabin():
    W = H = 96
    wd, r2 = R["wood"], R["roof2"]
    base = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(base)
    for i, y in enumerate(range(44, 95, 6)):                          # logs
        d.rounded_rectangle([10, y, 84, y + 5], 2, fill=A(wd[2]))
        d.line([12, y, 82, y], fill=A(wd[3]))
        d.line([12, y + 5, 82, y + 5], fill=A(wd[1]))
        d.ellipse([7, y, 13, y + 5], fill=A(wd[3]))
        d.ellipse([8, y + 1, 12, y + 4], fill=A(wd[1]))
    door = door_gap(d, [36, 56, 54, 86])
    d.rectangle([62, 54, 76, 66], fill=A(wd[1]))                      # broken window
    d.rectangle([64, 56, 74, 64], fill=A(P["back"]["top"][1]))
    d.line([64, 56, 70, 62], fill=A(R["glass"][2]))
    # sagging roof with a hole
    d.polygon([(2, 46), (44, 16), (92, 40), (88, 46)], fill=A(r2[2]))
    d.line([(2, 46), (44, 16)], fill=A(r2[3]))
    d.line([(44, 16), (92, 40)], fill=A(r2[1]))
    d.polygon([(52, 26), (64, 30), (58, 36)], fill=CLEAR)
    for y in range(24, 46, 6):
        d.line([max(4, 44 - (y - 16) * 42 // 30), y, min(90, 44 + (y - 16) * 48 // 24), y], fill=A(r2[1]))
    # sinking: the left side sits lower (column shift)
    cab = Image.new("RGBA", (W, H), CLEAR)
    for x in range(W):
        cab.alpha_composite(base.crop((x, 0, x + 1, H)), (x, round((60 - x) / 14)))
    d = ImageDraw.Draw(cab)
    moss(d, [(12, 50, 6), (70, 44, 5), (28, 76, 4)])
    o, _ = finish(cab)
    # the pond over the bottom (drawn in the sprite, translucent)
    wr = R["water"]
    pond = Image.new("RGBA", (W, H), CLEAR)
    pd = ImageDraw.Draw(pond)
    pd.rectangle([0, 82, W - 1, H - 1], fill=A(wr[2], 200))
    pd.line([0, 82, W - 1, 82], fill=A(wr[3], 230))
    for x in range(3, W, 9):
        pd.line([x, 82, x + 2, 82], fill=A(WHITE, 230))
    for x, y in ((12, 88), (50, 91), (74, 86)):
        pd.line([x, y, x + 3, y], fill=A(wr[3], 210))
    o.alpha_composite(pond)
    return o, {"door": [door[0], door[1] + round((60 - door[0]) / 14)], "waterline": 82}


def ruined_keep():
    W = H = 144
    k, rk = R["weath"], R["rock"]
    im = Image.new("RGBA", (W, H), CLEAR)
    stones(im, (14, 34, 130, 118), k, "keep", rows=9,
           gaps=[(70, 34, 84, 44), (110, 34, 130, 50), (122, 50, 130, 60)])
    stones(im, (10, 6, 44, 40), k, "keeptower", rows=8, gaps=[(10, 6, 15, 10)])
    d = ImageDraw.Draw(im)
    for x in range(48, 128, 12):                                       # crenels
        d.rectangle([x, 34, x + 5, 38], fill=CLEAR)
    for x in (14, 26, 38):
        d.rectangle([x, 2, x + 5, 6], fill=A(k[2]))
        d.line([x, 2, x + 5, 2], fill=A(k[3]))
    d.rectangle([24, 16, 29, 26], fill=A(P["back"]["top"][1]))       # arrow slit
    door = door_gap(d, [60, 82, 84, 118])
    d.line([96, 44, 102, 58], fill=A(k[0]))                           # crack
    d.line([102, 58, 99, 68], fill=A(k[0]))
    d.rectangle([92, 70, 101, 80], fill=A(P["back"]["top"][1]))
    # ivy (teal leaves) and moss
    lf = R["leaf"]
    for x, y in ((18, 60), (20, 66), (17, 72), (22, 78), (19, 84), (124, 64), (126, 70)):
        d.rectangle([x, y, x + 2, y + 2], fill=A(lf[2]))
        d.point((x, y), fill=A(lf[3]))
    moss(d, [(48, 32, 6), (88, 32, 5), (30, 112, 5), (106, 108, 6)])
    # the rocky peak it stands on
    d.polygon([(0, 143), (6, 124), (20, 116), (60, 118), (100, 115), (126, 118), (140, 128), (143, 143)], fill=A(rk[2]))
    d.line([(6, 124), (20, 116), (60, 118), (100, 115), (126, 118)], fill=A(rk[3]))
    for x, y in ((24, 128), (70, 132), (110, 126), (40, 138)):
        d.line([x, y, x + 6, y + 2], fill=A(rk[1]))
    d.rectangle([2, 140, 141, 143], fill=A(rk[1]))
    o, _ = finish(im)
    return o, {"door": door}


def make_buildings():
    for name, fn in (("barn", barn), ("house", house), ("lighthouse", lighthouse)):
        im, lit = fn()
        save(im, "buildings/%s.png" % name)
        save(lit, "buildings/%s_lit.png" % name, env=False)
        MANIFEST[name] = {"file": "buildings/%s.png" % name, "lit": "buildings/%s_lit.png" % name,
                          "frame": list(im.size), "pivot": [0, im.height], "pivot_note": "bottom-left on the ground"}
    sheet, lsheet = Image.new("RGBA", (3 * 144, 96), CLEAR), Image.new("RGBA", (3 * 144, 96), CLEAR)
    for i, door in enumerate((0, .5, 1)):
        im, lit = garage(door)
        sheet.alpha_composite(im, (i * 144, 0))
        lsheet.alpha_composite(lit, (i * 144, 0))
    save(sheet, "buildings/garage.png")
    save(lsheet, "buildings/garage_lit.png", env=False)
    MANIFEST["garage"] = {"file": "buildings/garage.png", "lit": "buildings/garage_lit.png", "frame": [144, 96],
                          "pivot": [0, 96], "rows": {"door": {"row": 0, "frames": 3, "fps": 0, "names": ["shut", "half", "open"]}}}
    im, lit, pts = headframe()
    save(im, "buildings/headframe.png")
    save(lit, "buildings/headframe_lit.png", env=False)
    MANIFEST["headframe"] = dict({"file": "buildings/headframe.png", "lit": "buildings/headframe_lit.png",
                                  "frame": list(im.size), "pivot": [48, 124], "pivot_note": "shaft centre on the ground",
                                  "cage_note": "cage = [x, y, w, h]"}, **pts)
    for name, fn in (("old_shed", old_shed), ("crooked_watchtower", crooked_watchtower),
                     ("flooded_cabin", flooded_cabin), ("ruined_keep", ruined_keep)):
        im, pts = fn()
        save(im, "buildings/%s.png" % name)
        MANIFEST[name] = dict({"file": "buildings/%s.png" % name, "frame": list(im.size), "pivot": [0, im.height]}, **pts)


# =============================================================================== props
def tree_img(tiles, cut=False):
    im = Image.new("RGBA", (32, 64), CLEAR)
    d = ImageDraw.Draw(im)
    w, lf = R["wood"], R["leaf"]
    h = tiles * 16
    top = 64 - h
    if cut:
        d.rectangle([12, top + 2, 19, 63], fill=A(w[2]))
        d.rectangle([18, top + 2, 19, 63], fill=A(w[1]))
        d.line([12, top + 2, 12, 63], fill=A(w[3]))
        d.ellipse([11, top, 20, top + 4], fill=A(hp.hx("#e2c08a")))
        d.ellipse([13, top + 1, 18, top + 3], outline=A(w[2]))
        if tiles >= 2:
            d.line([19, top + 12, 23, top + 9], fill=A(w[2]), width=2)
            d.point((24, top + 8), fill=A(lf[2]))
            d.point((23, top + 7), fill=A(lf[3]))
        d.polygon([(9, 63), (12, 57), (12, 63)], fill=A(w[2]))
        d.polygon([(22, 63), (19, 57), (19, 63)], fill=A(w[1]))
        return outline(im)
    if tiles == 1:                                         # a bush
        for cx, cy, r in ((16, 55, 7), (10, 58, 5), (22, 58, 5)):
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=A(lf[1]))
        for cx, cy, r in ((16, 55, 7), (10, 58, 5), (22, 58, 5)):
            d.ellipse([cx - r, cy - r, cx + r - 2, cy + r - 2], fill=A(lf[2]))
        d.ellipse([12, 50, 16, 53], fill=A(lf[3]))
        d.rectangle([7, 62, 25, 63], fill=A(lf[1]))
        return outline(im)
    trunk_top = top + h * 6 // 10
    d.rectangle([13, trunk_top, 18, 63], fill=A(w[2]))
    d.rectangle([17, trunk_top, 18, 63], fill=A(w[1]))
    d.line([13, trunk_top, 13, 63], fill=A(w[3]))
    d.polygon([(10, 63), (13, 58), (13, 63)], fill=A(w[2]))
    d.polygon([(21, 63), (18, 58), (18, 63)], fill=A(w[1]))
    s = h / 64
    blobs = [(16, top + 26 * s + 2, 13 * s + 1), (7 + 2 * (1 - s), top + 31 * s + 2, 8 * s + 1),
             (25 - 2 * (1 - s), top + 31 * s + 2, 8 * s + 1), (16, top + 13 * s + 1, 10 * s + 1)]
    for cx, cy, r in blobs:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=A(lf[1]))
    for cx, cy, r in blobs:
        d.ellipse([cx - r, cy - r, cx + r - 2, cy + r - 3], fill=A(lf[2]))
    for cx, cy, r in ((13, top + 10 * s + 1, 4 * s + 1), (5, top + 28 * s, 3 * s + .5), (23, top + 24 * s, 3 * s + .5), (12, top + 23 * s, 4 * s + 1)):
        d.ellipse([cx - r, cy - r + 1, cx + r, cy + r - 1], fill=A(lf[3]))
    r = rng("tree", tiles)
    for _ in range(8):
        x, y = r.randrange(3, 29), r.randrange(top + 3, top + round(36 * s))
        if im.getpixel((x, y))[3]:
            d.point((x, y), fill=A(lf[0]))
    return outline(im)


def boulder_frames():
    r4 = R["rock"]
    base = Image.new("RGBA", (26, 26), CLEAR)
    d = ImageDraw.Draw(base)
    hp.blob(d, 13, 13, 11, 11, r4)
    marks = Image.new("RGBA", (26, 26), CLEAR)
    m = ImageDraw.Draw(marks)
    m.line([15, 8, 18, 12], fill=A(r4[0]))
    m.line([18, 12, 16, 16], fill=A(r4[0]))
    m.point((8, 17), fill=A(r4[0]))
    m.point((7, 16), fill=A(r4[1]))
    m.rectangle([10, 12, 11, 13], fill=A(r4[1]))
    frames = []
    a = base.split()[3]
    for k in range(4):
        f = base.copy()
        f.alpha_composite(marks.rotate(-90 * k))
        f.putalpha(a)
        frames.append(outline(f))
    return frames


def make_props():
    sheet = Image.new("RGBA", (4 * 32, 2 * 64), CLEAR)
    for i, t in enumerate((4, 3, 2, 1)):
        sheet.alpha_composite(tree_img(t), (i * 32, 0))
        sheet.alpha_composite(tree_img(t, cut=True), (i * 32, 64))
    save(sheet, "props/tree.png")
    MANIFEST["tree"] = {"file": "props/tree.png", "frame": [32, 64], "pivot": [16, 64],
                        "rows": {"tree": {"row": 0, "frames": 4, "fps": 0, "tiles": [4, 3, 2, 1]},
                                 "trunk": {"row": 1, "frames": 4, "fps": 0, "tiles": [4, 3, 2, 1]}},
                        "note": "tree = whole tree that tall; trunk = what is left after the crown is scooped"}
    rk = Image.new("RGBA", (48, 16), CLEAR)
    small = Image.new("RGBA", (16, 16), CLEAR)
    d = ImageDraw.Draw(small)
    hp.blob(d, 8, 10, 6, 5, R["rock"])
    d.line([9, 9, 10, 11], fill=A(R["rock"][0]))
    rk.alpha_composite(outline(small), (0, 0))
    wide = Image.new("RGBA", (32, 16), CLEAR)
    d = ImageDraw.Draw(wide)
    hp.blob(d, 12, 9, 10, 6, R["rock"])
    hp.blob(d, 23, 11, 7, 4, R["rock"])
    d.line([14, 8, 16, 11], fill=A(R["rock"][0]))
    d.line([25, 10, 26, 12], fill=A(R["rock"][0]))
    rk.alpha_composite(outline(wide), (16, 0))
    save(rk, "props/rock.png")
    MANIFEST["rock"] = {"file": "props/rock.png", "regions": {"small": [0, 0, 16, 16], "wide": [16, 0, 32, 16]},
                        "pivot": "bottom-centre of each region"}
    st = Image.new("RGBA", (16, 16), CLEAR)
    st.alpha_composite(hp.stump(P).crop((0, 0, 18, 13)).crop((1, 0, 17, 13)), (0, 3))
    save(st, "props/stump.png")
    MANIFEST["stump"] = {"file": "props/stump.png", "frame": [16, 16], "pivot": [8, 16]}
    bs = Image.new("RGBA", (4 * 26, 26), CLEAR)
    for i, f in enumerate(boulder_frames()):
        bs.alpha_composite(f, (i * 26, 0))
    save(bs, "props/boulder.png")
    MANIFEST["boulder"] = {"file": "props/boulder.png", "frame": [26, 26], "pivot": [13, 13],
                           "rows": {"roll": {"row": 0, "frames": 4, "fps": 8}}}


# =============================================================================== treasures
def buried_car():
    im = Image.new("RGBA", (48, 32), CLEAR)
    d = ImageDraw.Draw(im)
    car = hp.ramp(hp.hx("#3fb3c4"), P)
    gd, gl, gm, gh = R["glass"]
    md, ml, mm, mh = R["metal"]
    d.rounded_rectangle([12, 4, 34, 16], 5, fill=A(car[2]))           # roof and cabin
    d.rounded_rectangle([2, 12, 45, 25], 5, fill=A(car[2]))
    d.line([14, 4, 32, 4], fill=A(car[3]))
    d.line([4, 12, 44, 12], fill=A(car[3]))
    d.rectangle([3, 22, 44, 25], fill=A(car[1]))
    d.rounded_rectangle([15, 7, 22, 13], 2, fill=A(gm))
    d.rounded_rectangle([24, 7, 31, 13], 2, fill=A(gm))
    d.line([16, 12, 19, 8], fill=A(WHITE))
    d.line([25, 12, 28, 8], fill=A(gh))
    d.line([23, 14, 23, 22], fill=A(car[1]))                           # door line
    d.rectangle([25, 16, 27, 16], fill=A(mh))                          # handle
    d.rectangle([40, 15, 45, 18], fill=A(LAMP))                        # one headlamp at the nose
    d.point((41, 15), fill=A(WHITE))
    d.rectangle([1, 20, 46, 21], fill=A(mm))                           # chrome bumper line
    for cx in (12, 36):                                                 # big wheels
        d.ellipse([cx - 6, 18, cx + 6, 30], fill=A(R["tyre"][2]))
        d.ellipse([cx - 3, 21, cx + 3, 27], fill=A(mm))
        d.point((cx - 1, 22), fill=A(mh))
    for x, y in ((6, 16), (30, 18), (18, 5)):                           # a bit of rust and dirt
        d.rectangle([x, y, x + 2, y + 1], fill=A(R["barn"][1]))
    return outline(im)


def giant_tooth():
    im = Image.new("RGBA", (32, 32), CLEAR)
    d = ImageDraw.Draw(im)
    bone = hp.ramp(hp.hx("#f4ecd8"), P)
    d.rounded_rectangle([4, 3, 27, 18], 6, fill=A(bone[2]))
    d.polygon([(6, 14), (14, 14), (12, 29), (8, 29)], fill=A(bone[2]))
    d.polygon([(17, 14), (26, 14), (23, 29), (19, 29)], fill=A(bone[2]))
    d.polygon([(21, 16), (26, 14), (23, 29), (22, 29)], fill=A(bone[1]))
    d.ellipse([12, 1, 19, 6], fill=CLEAR)                            # the bite notch
    d.rounded_rectangle([4, 3, 12, 8], 3, fill=A(bone[3]))
    d.rectangle([7, 5, 9, 6], fill=A(WHITE))
    d.line([24, 6, 24, 16], fill=A(bone[1]))
    d.line([16, 8, 16, 14], fill=A(bone[1]))
    return outline(im)


def gnome_room():
    im = Image.new("RGBA", (64, 48), CLEAR)
    stones(im, (1, 1, 62, 46), R["stone"], "gnomeroom", rows=6)
    d = ImageDraw.Draw(im)
    wd = R["wood"]
    d.rectangle([6, 8, 57, 41], fill=A(hp.hx("#f2d39a")))               # warm plaster inside
    d.rectangle([6, 36, 57, 41], fill=A(wd[2]))                         # floor boards
    d.line([6, 36, 57, 36], fill=A(wd[3]))
    d.rectangle([6, 8, 57, 9], fill=A(wd[1]))                           # ceiling beam
    # tiny door
    d.rounded_rectangle([42, 20, 52, 36], 4, fill=A(wd[1]))
    d.rounded_rectangle([43, 21, 51, 36], 4, fill=A(hp.hx("#1E9AA0")))
    d.point((49, 29), fill=A(R["gold"][2]))
    # hanging lamp
    d.line([24, 10, 24, 14], fill=A(R["metal"][0]))
    d.rectangle([22, 15, 26, 19], fill=A(R["gold"][2]))
    d.rectangle([23, 16, 25, 18], fill=A(LAMP))
    # little bed with a teal pointy hat on the post
    d.rectangle([9, 30, 26, 35], fill=A(wd[2]))
    d.rectangle([10, 28, 25, 31], fill=A(WHITE))
    d.rectangle([18, 28, 25, 31], fill=A(C["pink"]))
    d.rectangle([9, 24, 10, 35], fill=A(wd[1]))
    d.polygon([(7, 25), (13, 25), (10, 17)], fill=A(hp.hx("#1E9AA0")))
    d.point((10, 17), fill=A(WHITE))
    # tiny table and a cup
    d.rectangle([30, 30, 38, 31], fill=A(wd[3]))
    d.line([31, 32, 31, 35], fill=A(wd[1]))
    d.line([37, 32, 37, 35], fill=A(wd[1]))
    d.rectangle([33, 27, 35, 29], fill=A(R["gold"][2]))
    return outline(im), {"lamp": [24, 17], "door": [47, 28]}


def finds():
    im = Image.new("RGBA", (6 * 16, 16), CLEAR)
    g, md = R["gold"], R["metal"]
    items = []
    f = Image.new("RGBA", (16, 16), CLEAR)                               # bottle cap
    d = ImageDraw.Draw(f)
    for a in range(0, 360, 30):
        x, y = 8 + 6 * math.cos(math.radians(a)), 8 + 6 * math.sin(math.radians(a))
        d.point((round(x - .5), round(y - .5)), fill=A(g[1]))
    d.ellipse([3, 3, 12, 12], fill=A(g[2]))
    d.ellipse([5, 5, 10, 10], fill=A(g[1]))
    d.point((5, 4), fill=A(WHITE))
    d.point((4, 5), fill=A(g[3]))
    items.append(f)
    f = Image.new("RGBA", (16, 16), CLEAR)                               # boot
    d = ImageDraw.Draw(f)
    b = R["boots"]
    d.rectangle([4, 2, 9, 11], fill=A(b[2]))
    d.rounded_rectangle([4, 8, 14, 13], 2, fill=A(b[2]))
    d.rectangle([4, 12, 14, 13], fill=A(b[0]))
    d.line([4, 2, 9, 2], fill=A(b[3]))
    d.line([5, 3, 5, 10], fill=A(b[3]))
    items.append(f)
    f = Image.new("RGBA", (16, 16), CLEAR)                               # bike
    d = ImageDraw.Draw(f)
    rf = R["roof"]
    for cx in (4, 12):
        d.ellipse([cx - 3, 7, cx + 3, 13], outline=A(R["tyre"][2]))
    d.line([4, 10, 7, 6, 11, 6, 12, 10], fill=A(rf[2]))
    d.line([7, 6, 8, 10, 11, 6], fill=A(rf[2]))
    d.line([6, 4, 8, 4], fill=A(R["tyre"][2]))
    d.line([11, 6, 11, 3], fill=A(md[2]))
    d.line([10, 3, 13, 3], fill=A(md[2]))
    items.append(f)
    f = Image.new("RGBA", (16, 16), CLEAR)                               # fossil (ammonite)
    d = ImageDraw.Draw(f)
    rk = R["weath"]
    d.ellipse([2, 2, 13, 13], fill=A(rk[2]))
    d.arc([2, 2, 13, 13], 180, 270, fill=A(rk[3]))
    d.arc([4, 4, 11, 11], 0, 300, fill=A(rk[0]))
    d.arc([6, 6, 9, 9], 0, 300, fill=A(rk[0]))
    for a in range(200, 520, 40):
        x, y = 7.5 + 5.5 * math.cos(math.radians(a)), 7.5 + 5.5 * math.sin(math.radians(a))
        d.line([7.5 + 3.5 * math.cos(math.radians(a)), 7.5 + 3.5 * math.sin(math.radians(a)), x, y], fill=A(rk[1]))
    items.append(f)
    f = Image.new("RGBA", (16, 16), CLEAR)                               # bone
    d = ImageDraw.Draw(f)
    bone = hp.ramp(hp.hx("#f4ecd8"), P)
    d.line([4, 11, 11, 4], fill=A(bone[2]), width=3)
    for cx, cy in ((3, 10), (5, 12), (10, 3), (12, 5)):
        d.ellipse([cx - 2, cy - 2, cx + 1, cy + 1], fill=A(bone[2]))
    d.line([5, 9, 9, 5], fill=A(bone[3]))
    d.point((2, 9), fill=A(WHITE))
    items.append(f)
    f = Image.new("RGBA", (16, 16), CLEAR)                               # gem
    d = ImageDraw.Draw(f)
    gem = hp.ramp(hp.hx("#4fd6e0"), P)
    d.polygon([(2, 6), (5, 3), (10, 3), (13, 6), (8, 13), (7, 13)], fill=A(gem[2]))
    d.polygon([(2, 6), (5, 3), (7, 6)], fill=A(gem[3]))
    d.polygon([(8, 13), (13, 6), (9, 6)], fill=A(gem[1]))
    d.line([2, 6, 13, 6], fill=A(gem[1]))
    d.point((5, 4), fill=A(WHITE))
    items.append(f)
    for i, f in enumerate(items):
        im.alpha_composite(outline(f), (i * 16, 0))
    return im


def sparkles():
    im = Image.new("RGBA", (4 * 9, 9), CLEAR)
    p = im.load()
    g = R["gold"][3]
    shapes = [[(0, 0, WHITE)],
              [(0, 0, WHITE), (1, 0, g), (-1, 0, g), (0, 1, g), (0, -1, g)],
              [(0, 0, WHITE)] + [(i * sx, i * sy, WHITE if i == 1 else g) for i in (1, 2, 3, 4) for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
              + [(1, 1, g), (-1, 1, g), (1, -1, g), (-1, -1, g)],
              [(0, 0, WHITE), (1, 0, g), (-1, 0, g), (0, 1, g), (0, -1, g)]]
    for k, sh in enumerate(shapes):
        for dx, dy, c in sh:
            p[k * 9 + 4 + dx, 4 + dy] = A(c)
    return im


def make_treasures():
    save(buried_car(), "treasures/buried_car.png")
    MANIFEST["buried_car"] = {"file": "treasures/buried_car.png", "frame": [48, 32], "tiles": [3, 2]}
    save(giant_tooth(), "treasures/giant_tooth.png")
    MANIFEST["giant_tooth"] = {"file": "treasures/giant_tooth.png", "frame": [32, 32], "tiles": [2, 2]}
    gr, pts = gnome_room()
    save(gr, "treasures/gnome_room.png")
    MANIFEST["gnome_room"] = dict({"file": "treasures/gnome_room.png", "frame": [64, 48], "tiles": [4, 3]}, **pts)
    save(finds(), "treasures/finds.png")
    MANIFEST["finds"] = {"file": "treasures/finds.png", "frame": [16, 16],
                         "names": ["bottle_cap", "boot", "bike", "fossil", "bone", "gem"]}
    save(sparkles(), "treasures/sparkle.png", env=False)
    MANIFEST["sparkle"] = {"file": "treasures/sparkle.png", "frame": [9, 9], "pivot": [4, 4],
                           "rows": {"sparkle": {"row": 0, "frames": 4, "fps": 8}}}


# =============================================================================== fx (soft: light only)
def make_fx():
    g = Image.new("RGBA", (64, 64), CLEAR)
    p = g.load()
    for y in range(64):
        for x in range(64):
            r = math.hypot(x - 31.5, y - 31.5) / 32
            a = max(0.0, 1 - r) ** 1.8
            p[x, y] = (255, 255, 255, round(255 * a))
    save(g, "fx/glow.png", env=False)
    c = Image.new("RGBA", (128, 64), CLEAR)
    p = c.load()
    for y in range(64):
        for x in range(128):
            t = x / 127
            ang = abs(y - 31.5) / max(1.0, 4 + x * .42)
            a = max(0.0, 1 - ang) ** 1.2 * (1 - t) ** .7 * min(1.0, x / 6)
            p[x, y] = (255, 246, 214, round(235 * a))
    save(c, "fx/cone.png", env=False)
    w = Image.new("RGBA", (16, 16), CLEAR)
    p = w.load()
    for y in range(16):
        for x in range(16):
            dx, dy = max(0, abs(x - 7.5) - 3) / 4.5, max(0, abs(y - 7.5) - 3) / 4.5
            a = max(0.0, 1 - math.hypot(dx, dy)) ** 1.5
            p[x, y] = LIT_WIN + (round(255 * a),)
    save(w, "fx/window.png", env=False)
    MANIFEST["fx"] = {"glow": {"file": "fx/glow.png", "frame": [64, 64], "pivot": [32, 32]},
                      "cone": {"file": "fx/cone.png", "frame": [128, 64], "pivot": [0, 32]},
                      "window": {"file": "fx/window.png", "frame": [16, 16], "pivot": [8, 8]},
                      "note": "soft sprites for additive light only (pixel-rules exception)"}


# =============================================================================== check
IDENTITY = {tuple(c) for c in R["p1"] + R["p2"]}


def report():
    lines = []
    tres = []
    for f in sorted(ENV):
        ok = IDENTITY if f.startswith("vehicles/") else set()     # the driver's stripe is identity
        bad = sorted(hp.tohex(c) for c in USED[f] if hp.reserved_hue(c) and c not in ok)
        if bad:
            tres.append("%s: %s" % (f, " ".join(bad[:8])))
    lines.append("reserved-hue trespasses: %d" % len(tres))
    lines += ["  " + t for t in tres]
    worst = 999
    lines.append("player pop, CIE76 dE (green/red vs tile mid, wall):")
    for kind in BLOCKS + ["cav"]:
        tile = R[kind][2]
        wall = P["back"][kind][0]
        vals = [hp.delta_e(hp.GREEN, tile), hp.delta_e(hp.GREEN, wall), hp.delta_e(hp.RED, tile), hp.delta_e(hp.RED, wall)]
        worst = min(worst, *vals)
        lines.append("  %-8s %3.0f %3.0f %3.0f %3.0f" % (kind, *vals))
    lines.append("  worst %.0f (under 25 fails)" % worst)
    counts = []
    for k, m in MANIFEST.items():
        if "rows" in m and any(isinstance(v, dict) and "frames" in v for v in m["rows"].values()):
            counts.append("%s %s" % (k, ",".join("%s:%d" % (a, b["frames"]) for a, b in m["rows"].items() if "frames" in b)))
        elif "frames" in m:
            counts.append("%s %d" % (k, m["frames"]))
    lines.append("frames: " + "; ".join(counts))
    print("\n".join(lines))
    return len(tres) == 0 and worst >= 25


STEPS = [make_tiles, make_walls, make_water, make_grass, make_parallax_underground, make_parallax_hillville,
         make_sky_bits, make_characters, make_vehicles,
         make_buildings, make_props, make_treasures, make_fx]


def main():
    for step in STEPS:
        step()
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(MANIFEST, f, indent=1, sort_keys=True)
        f.write("\n")
    ok = report()
    print("wrote %d sheets to assets/sprites/" % len(USED))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
