"""Style E, picture book: no pixels. Wobbly ink lines, flat gouache fills with a painted
shadow side, rounded hand-cut earth, pools of light on a blue night wash, paper grain.
Drawn at 2x and scaled down, so one 16 px cell is a 48 px drawing at 1080p."""
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import scenes2 as S
from scenes2 import E, L, P, R

hp, T = S.hp, 16
U = 6                     # work pixels per 1x pixel (48 px cell, supersampled x2)
INK = (56, 40, 48)
HEX = dict(
    top="#b07a4a", clay="#e08a4f", stone="#9aa3b2", ice="#bfe6f5", crys="#a678d8", cav="#8a4a5e", strange="#2f7f7a", edge="#b9b4ae",
    barn="#c9553d", barn2="#b04630", roof="#6a4a48", roof2="#5d7fae", trim="#fff6dc", dark="#4a3238", brick="#c96f4f",
    plaster="#fbeccc", wood="#a8774a", wood2="#c99a62", door="#8a5a36", glass="#aee0ee", lamp="#fff0a0", lampo="#ff9a3a",
    oldwood="#9a8f84", oldwood2="#857a70", oldroof="#766e6c", rock="#b3aca4", rock2="#d2ccc4", moss="#b9c44e",
    metal="#b7c0cc", metal2="#8791a0", veh="#ffc02e", veh2="#e09a1c", stripe="#fff3d6", p1="#3cc24a", p2="#e4393c",
    tyre="#4a4650", leaf="#4fae93", leaf2="#86d2b4", flame="#ffb030", gold="#ffd23e", gold2="#fff6b8", gem="#5fe0ee",
    gem2="#e0fbff", bone="#fff3da", grass="#b4cc4a", grass2="#8fae3a", rope="#c9ad7a", water="#5aa8e0", lava="#ff8a3a",
    copper="#e8894a", skin="#f6c39c", costume="#ffd84d", jeans="#5a80c8", boots="#96603a", shirt="#3a3640", pink="#ff8ab8",
    beak="#ff9a3a", white="#ffffff", cloud="#ffffff", hill="#a8cf6a", far="#c4e2b8", keep="#b8b0b4", sky="#76bfe6", sky2="#fbf0d2",
    night="#3c3a86")
COL = {k: hp.hx(v) for k, v in HEX.items()}
COL.update(ink=INK, dirtb=COL["top"], stoneb=COL["stone"], clayb=COL["clay"])
GLOW = {"torch", "coin", "gem", "hoard"}

JEFF = [E("skin", 6, -1.5, 3.5, 2), E("skin", 14, -1.5, 3.5, 2), P("jeans", R(4.5, -9, 9, -2)), P("jeans", R(11, -9, 15.5, -2)),
        E("costume", 10, -13, 7.5, 6.5), E("p1", 2.5, -12, 2.5, 3), E("p1", 17.5, -12, 2.5, 3)]
JHEAD = [E("costume", 10, -22, 8.5, 7.5), E("skin", 11, -21, 6, 5), L("ink", [(8.5, -22), (10.5, -22.4)], 1), L("ink", [(13, -22.4), (15, -22)], 1),
         P("white", [(8.5, -19.6), (15, -19.6), (13.5, -16.8), (10, -16.8)]), E("pink", 10, -34, 2.6, 2.2),
         P("p1", [(1.5, -26), (3, -31), (8, -33.5), (13, -33.5), (17.5, -31), (19, -26)]), P("beak", [(17, -25.6), (22.5, -24), (17, -22.6)]),
         P("p1", R(1, -27.4, 21, -25.4))]
CHUCK = [P("boots", [(3, 0), (3, -5), (8.5, -5), (8.5, -2), (10.5, 0)]), P("boots", [(11, 0), (11, -5), (16.5, -5), (16.5, -2), (19, 0)]),
         P("jeans", R(4, -10, 8.5, -4.5)), P("jeans", R(11.5, -10, 16, -4.5)), P("shirt", [(3, -9), (2.5, -17), (17.5, -17), (17, -9)]),
         L("p2", [(8, -12), (10, -14.5), (12.5, -13), (11, -11), (9.5, -12.5)], 1), E("white", 14, -15, .7),
         E("skin", 1.8, -11, 2, 2.6), E("skin", 18.2, -11, 2, 2.6)]
CHEAD = [E("skin", 10, -22, 7, 6.5), L("ink", [(7.5, -24.2), (10.5, -22.8)], 1.4), L("ink", [(12.5, -22.8), (15.5, -24.2)], 1.4),
         E("ink", 9.5, -21.3, .8), E("ink", 13.5, -21.3, .8), L("ink", [(9.5, -18.2), (14, -18.2)], 1),
         P("p2", [(3, -25), (3.5, -30), (7, -32), (13, -32), (16.5, -30), (17, -25)]), P("p2", [(15, -26.6), (23.5, -25.5), (23, -24.2), (15, -24.6)]),
         E("costume", 11, -28.5, 2, 1.6)]


def char(who, dig=False, lamp=False):
    s = (JEFF + JHEAD) if who == "jeff" else (CHUCK + CHEAD)
    if dig:
        s = [L("wood", [(17, -12), (25, -2)], 2), P("metal", [(24, -5), (28.5, -3.5), (27.5, 2), (23, 0)])] + s
    return s + ([E("lamp", 17, -29.5, 1.6)] if lamp else [])


def wob(pts, closed, amp):
    """Subdivide and nudge with a slow sine so edges look drawn by hand, not ruled."""
    out, n = [], len(pts)
    for i in range(n if closed else n - 1):
        (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
        k = max(1, int(math.hypot(x1 - x0, y1 - y0) / 16))
        for j in range(k):
            x, y = x0 + (x1 - x0) * j / k, y0 + (y1 - y0) * j / k
            out.append((x + amp * math.sin(x * .041 + y * .033), y + amp * math.cos(x * .037 - y * .046)))
    if not closed:
        out.append(pts[-1])
    return out


def obj(prims, u=U, lw=None, ink=INK):
    """Draw shared primitives as an inked, painted cut-out. Returns (layer, ox, oy) in work pixels."""
    lw = lw or max(3, round(u * .8))
    xs, ys = [], []
    flat = []
    for p in prims:
        if p[1] == "h":                         # a driver: just the head, in the cab
            hx_, hy = p[2]
            for m, k, g, *w in (JHEAD if p[0] == "jeff" else CHEAD):
                f = .82
                g2 = (hx_ + g[0] * f - 4, hy + (g[1] + 16) * f, g[2] * f, g[3] * f) if k == "e" else [(hx_ + x * f - 4, hy + (y + 16) * f) for x, y in g]
                flat.append((m, k, g2) + tuple(w))
        else:
            flat.append(p)
    for p in flat:
        if p[1] == "e":
            xs += [p[2][0] - p[2][2], p[2][0] + p[2][2]]
            ys += [p[2][1] - p[2][3], p[2][1] + p[2][3]]
        else:
            xs += [q[0] for q in p[2]]
            ys += [q[1] for q in p[2]]
    x0, y0 = min(xs) - 3, min(ys) - 3
    im = Image.new("RGBA", (int((max(xs) + 3 - x0) * u), int((max(ys) + 3 - y0) * u)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for p in flat:
        c = COL[p[0]]
        if p[1] == "l":
            pts = wob([((x - x0) * u, (y - y0) * u) for x, y in p[2]], False, u * .25)
            w = max(2, round(p[3] * u))
            if p[3] >= 2:
                d.line(pts, fill=ink, width=w + 2 * lw - 2, joint="curve")
            d.line(pts, fill=c, width=w if p[3] >= 2 else max(lw - 1, w * 2 // 3), joint="curve")
            continue
        if p[1] == "e":
            cx, cy, rx, ry = p[2]
            pts = [((cx + rx * math.cos(a / 16 * math.pi) - x0) * u, (cy + ry * math.sin(a / 16 * math.pi) - y0) * u) for a in range(32)]
        else:
            pts = [((x - x0) * u, (y - y0) * u) for x, y in p[2]]
        pts = wob(pts, True, u * .28)
        d.polygon(pts, fill=c)
        if p[0] != "ink":
            d.line(pts + pts[:2], fill=ink, width=lw, joint="curve")
    a = im.getchannel("A")
    s = int(u * 1.6)
    side = ImageChops.subtract(a, ImageChops.offset(a, -s, -s)).filter(ImageFilter.GaussianBlur(u * .4))
    im.paste(Image.new("RGBA", im.size, (70, 40, 80, 255)), (0, 0), side.point(lambda v: v * 2 // 7))
    lit = ImageChops.subtract(a, ImageChops.offset(a, s, s)).filter(ImageFilter.GaussianBlur(u * .4))
    im.paste(Image.new("RGBA", im.size, (255, 250, 225, 255)), (0, 0), lit.point(lambda v: v // 6))
    im.putalpha(a)
    return im, int(x0 * u), int(y0 * u)


def up(small, W, H, blur=3.4):
    return small.resize((small.width * T, small.height * T), Image.NEAREST).filter(ImageFilter.GaussianBlur(blur)).resize((W, H), Image.BICUBIC)


def tmask(sc, fn):
    m = Image.new("L", (sc["cols"], sc["rows"]), 0)
    for y in range(sc["rows"]):
        for x in range(sc["cols"]):
            if fn(x, y):
                m.putpixel((x, y), 255)
    return m


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def doodles(d, sc, k, tx, ty):
    """Sparse hand-drawn marks that say what the material is."""
    C = U * T
    r = hp._rng("e" + k, tx, ty)
    x, y = tx * C + r.randrange(C // 5, C * 3 // 5), ty * C + r.randrange(C // 5, C * 3 // 5)
    dk, lt, w = shade(COL[k], .78), shade(COL[k], 1.22), 5
    if k == "top":
        if r.random() < .6:
            d.ellipse([x, y, x + 22, y + 15], fill=lt, outline=dk, width=3)
        d.line([x + 30, y + 30, x + 36, y + 38, x + 42, y + 30], fill=dk, width=4)
    elif k == "clay":
        d.line([(tx * C + i * C / 4, y + 9 * math.sin(i * 1.7 + ty + tx * 1.3)) for i in range(5)], fill=dk if (tx + ty) % 3 else lt, width=w, joint="curve")
    elif k == "stone":
        if r.random() < .7:
            d.line([x, y, x + 18, y + 12, x + 12, y + 30, x + 30, y + 40], fill=dk, width=w, joint="curve")
        else:
            d.polygon([(x, y + 8), (x + 20, y), (x + 34, y + 14), (x + 12, y + 26)], fill=lt, outline=dk)
    elif k == "ice":
        d.line([x, y + 34, x + 34, y], fill=(255, 255, 255), width=w)
        d.line([x + 14, y + 40, x + 36, y + 18], fill=(255, 255, 255), width=3)
    elif k == "crys":
        d.polygon([(x + 12, y - 8), (x + 26, y + 14), (x + 12, y + 40), (x, y + 14)], fill=lt, outline=INK)
        d.line([x + 12, y - 8, x + 12, y + 40], fill=dk, width=3)
    elif k == "cav":
        d.arc([x, y, x + 40, y + 34], 200, 340, fill=dk, width=w)
        if r.random() < .4:
            d.ellipse([x + 44, y + 30, x + 52, y + 38], fill=COL["lava"])
    elif k == "strange":
        d.line([tx * C, ty * C + C // 2, tx * C + C, ty * C + C // 2], fill=dk, width=4)
        d.line([tx * C + (C // 2 if ty % 2 else 4), ty * C, tx * C + (C // 2 if ty % 2 else 4), ty * C + C // 2], fill=dk, width=4)
        if r.random() < .3:
            g = shade(COL["strange"], 2.3)
            (d.ellipse if r.random() < .5 else d.rectangle)([x, y, x + 24, y + 24], outline=g, width=4)
            d.line([x + 12, y - 6, x + 12, y + 30], fill=g, width=4)
    else:
        for i in range(-1, 4):
            if ty % 3 == 0:
                d.line([tx * C + i * 32, ty * C + C, tx * C + i * 32 + 40, ty * C], fill=(255, 208, 70), width=12)
        d.ellipse([x, y, x + 12, y + 12], outline=dk, width=3)


def sky(W, H, sc):
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    hz = sc["surf"] * T * U
    a, b = COL["sky"], COL["sky2"]
    for i in range(24):                          # broad brush bands, then softened
        t = (i / 23) ** 1.3
        d.rectangle([0, hz * i // 24, W, hz], fill=tuple(int(a[j] + (b[j] - a[j]) * t + (6 if i % 2 else -6)) for j in range(3)))
    im = im.filter(ImageFilter.GaussianBlur(14))
    if sc["hill"] is None:
        return im
    d = ImageDraw.Draw(im)
    sx, sy = int(W * .8), 330
    for i in range(12):
        an = i * math.pi / 6
        d.line([sx + 150 * math.cos(an), sy + 150 * math.sin(an), sx + 200 * math.cos(an), sy + 200 * math.sin(an)], fill=(255, 226, 120), width=12)
    d.ellipse([sx - 110, sy - 110, sx + 110, sy + 110], fill=(255, 232, 130), outline=(240, 180, 70), width=6)
    for cx, cy, s in ((420, 300, 1), (1500, 520, .8), (2500, 250, 1.1), (3500, 620, .7)):
        c, ox, oy = obj([E("cloud", 0, 0, 22, 9), E("cloud", -12, -6, 10, 8), E("cloud", 4, -10, 13, 10), E("cloud", 18, -4, 9, 7), E("cloud", 0, 1, 24, 6)],
                        U * s * 1.6, 4, (150, 190, 215))
        im.paste(c, (int(cx + ox), int(cy + oy)), c)
    hx_ = sc["hill"] * U
    for cx, rx, ry, c in ((hx_ - 1500, 1100, 420, "far"), (hx_ + 1700, 1000, 380, "far"), (hx_, 1500, 720, "hill")):
        pts = wob([(cx + rx * math.cos(i / 40 * math.pi), hz + 60 - ry * math.sin(i / 40 * math.pi)) for i in range(41)], False, 7)
        d.polygon(pts, fill=COL[c])
        d.line(pts, fill=shade(COL[c], .6), width=7, joint="curve")
        for i in range(26):                      # little tree-tuft arcs on the hillside
            r = hp._rng("h" + c, i, 0)
            x, y = cx + r.uniform(-.8, .8) * rx, hz - r.uniform(.05, .6) * ry
            if (x - cx) ** 2 / rx ** 2 + (hz + 60 - y) ** 2 / ry ** 2 < .8:
                d.arc([x, y, x + 60, y + 44], 180, 360, fill=shade(COL[c], .72), width=6)
    k, ox, oy = obj([P("keep", [(0, 0), (0, -22), (3, -22), (3, -25), (6, -25), (6, -22), (9, -22), (9, -25), (12, -25), (12, -22), (15, -22), (15, -10), (22, -4), (22, 0)]),
                     P("dark", R(5, -10, 9, 0))])
    im.paste(k, (hx_ - 60 + ox, hz - 655 + oy), k)
    return im


def render(sc):
    w, cols, rows = sc["w"], sc["cols"], sc["rows"]
    C = U * T
    W, H = cols * C, rows * C
    nz = Image.effect_noise((W // 28, H // 28), 70).resize((W, H), Image.BICUBIC)
    npos, nneg = nz.point(lambda v: max(0, v - 128) // 2), nz.point(lambda v: max(0, 128 - v) // 2)

    def cut(m, thr=127):
        return ImageChops.subtract(ImageChops.add(m, npos), nneg).point(lambda v: 255 if v > thr else 0)

    im = sky(W, H, sc) if sc["surf"] is not None else Image.new("RGB", (W, H), COL["dark"])
    solid = cut(up(tmask(sc, lambda x, y: w.solid[y][x] is not None), W, H))
    earth = Image.new("RGB", (W, H), COL["top"])
    kinds = [k for k in hp.LAYERS if any(k in row for row in w.back)]
    for k in kinds:
        earth.paste(COL[k], (0, 0), up(tmask(sc, lambda x, y: w.back[y][x] == k), W, H, 2.2).point(lambda v: 255 if v > 118 else 0))
    d = ImageDraw.Draw(earth)
    for ty in range(rows):
        for tx in range(cols):
            if w.back[ty][tx]:
                doodles(d, sc, w.back[ty][tx], tx, ty)
            ore = sc["ores"].get((tx, ty))
            if ore:
                r = hp._rng("ore", tx, ty)
                for _ in range(3):
                    x, y = tx * C + r.randrange(10, C - 34), ty * C + r.randrange(10, C - 34)
                    d.ellipse([x, y, x + 26, y + 22], fill=COL[ore], outline=INK, width=4)
                    d.ellipse([x + 6, y + 5, x + 12, y + 10], fill=(255, 255, 255))
    wall = ImageChops.multiply(earth, Image.new("RGB", (W, H), (150, 132, 160)))
    cave = Image.new("RGB", (W, H), (58, 36, 62))
    dc = ImageDraw.Draw(cave)
    for i in range(0, W, 300):
        dc.ellipse([i - 60, H * .86 - 150 - 60 * math.sin(i), i + 420, H * .86 + 300], fill=(84, 52, 80), outline=(44, 28, 50), width=6)
    wall.paste(cave, (0, 0), up(tmask(sc, lambda x, y: (x, y) in sc["far"]), W, H))
    dw = ImageDraw.Draw(wall)
    for (tx, ty), fl in w.fluid.items():
        top = (tx, ty - 1) not in w.fluid
        y0 = ty * C + (20 if top else 0)
        dw.rectangle([tx * C, y0, tx * C + C, ty * C + C], fill=COL[fl])
        if top:
            dw.line([(tx * C + i * C / 4, y0 + 7 * math.sin(i * 1.6 + tx)) for i in range(5)], fill=(255, 255, 255), width=7, joint="curve")
        elif (tx + ty) % 2:
            dw.arc([tx * C + 20, y0 + 30, tx * C + 70, y0 + 60], 200, 340, fill=shade(COL[fl], 1.25 if fl == "water" else 1.3), width=5)
    sb = solid.filter(ImageFilter.GaussianBlur(16))
    earth.paste(shade(INK, 1.1), (0, 0), ImageChops.multiply(solid, ImageChops.invert(sb)).point(lambda v: min(150, v * 2)))   # darker rim of the cut
    wall.paste((40, 26, 52), (0, 0), ImageChops.multiply(ImageChops.invert(solid), sb).point(lambda v: min(120, v * 3 // 2)))     # shadow under the edge
    ground = Image.composite(earth, wall, solid)
    anyk = cut(up(tmask(sc, lambda x, y: w.back[y][x] is not None or (x, y) in sc["far"]), W, H))
    im.paste(ground, (0, 0), anyk)
    edge = ImageChops.lighter(ImageChops.difference(solid.filter(ImageFilter.MaxFilter(5)), solid.filter(ImageFilter.MinFilter(5))),
                              ImageChops.difference(anyk.filter(ImageFilter.MaxFilter(5)), anyk.filter(ImageFilter.MinFilter(5))))
    im.paste(INK, (0, 0), edge)
    d = ImageDraw.Draw(im)
    if sc["surf"] is not None:                    # grass: one fat wobbly band along the surface, then tufts
        y = sc["surf"] * C
        for tx in range(cols):
            if w.is_solid(tx, sc["surf"]):
                wild = tx not in w.plot
                top = [(tx * C + i * 16, y - 10 - 5 * math.sin((tx * C + i * 16) * .05)) for i in range(7)]
                d.polygon(top + [(tx * C + C, y + 22 + 6 * math.sin(tx * 2.1)), (tx * C, y + 22 + 6 * math.sin(tx * 2.1 - 2.1))], fill=COL["grass"])
                d.line(top, fill=shade(COL["grass2"], .7), width=5, joint="curve")
                for i in range(6 if wild else 1):
                    r = hp._rng("g", tx, i)
                    x, hgt = tx * C + r.randrange(C), r.randrange(26, 60) if wild else 16
                    d.line([x, y - 6, x + r.randrange(-12, 12), y - 6 - hgt], fill=shade(COL["grass2"], .8), width=5)
    im = im.convert("RGBA")
    glow = []
    for kind, x, y, o in sc["ents"]:
        if kind in ("jeff", "chuck"):
            lay, ox, oy = obj(char(kind, o.get("dig"), o.get("lamp")), U * .9)
        else:
            lay, ox, oy = obj(S.SHAPES[kind](**o))
        im.alpha_composite(lay, (max(0, x * U + ox), y * U + oy), (max(0, -(x * U + ox)), 0))
        if kind in GLOW or o.get("lamp"):
            glow.append((lay, (x * U + ox, y * U + oy)))
    im = im.convert("RGB")
    lm = S.lightmap(sc)
    lum = up(lm.convert("L"), W, H, 5)
    dark = ImageChops.subtract(ImageChops.add(lum, npos.point(lambda v: v // 6)), nneg.point(lambda v: v // 6)).point(lambda v: 205 if v < 60 else 120 if v < 135 else 0).filter(ImageFilter.GaussianBlur(5))
    im = Image.composite(ImageChops.multiply(im, Image.new("RGB", (W, H), COL["night"])), im, dark)     # painted night wash, two steps
    pool = Image.new("RGB", (W, H))
    dp = ImageDraw.Draw(pool)
    for tx, ty, c in sc["lights"]:
        if min(c) < 1:
            dp.ellipse([tx * C - 60, ty * C - 60, tx * C + C + 60, ty * C + C + 60], fill=tuple(int(70 * v) for v in c))
    im = ImageChops.screen(im, pool.filter(ImageFilter.GaussianBlur(40))).convert("RGBA")
    d = ImageDraw.Draw(im)
    for lay, (x, y) in glow:
        im.alpha_composite(lay, (x, y))
        cx, cy = x + lay.width // 2, y + lay.height // 3
        for i in range(8):                       # glow ticks: how a picture book says "this shines"
            an = i * math.pi / 4 + .3
            rx, ry = lay.width * .5 + 8, lay.height * (.36 if lay.height > 60 else .5) + 8
            d.line([cx + rx * math.cos(an), cy + ry * math.sin(an), cx + (rx + 20) * math.cos(an), cy + (ry + 20) * math.sin(an)], fill=(255, 240, 170), width=6)
    paper = Image.effect_noise((W // 10, H // 10), 46).resize((W, H), Image.BICUBIC).point(lambda v: 238 + (v - 128) // 8)
    grain = Image.effect_noise((W // 2, H // 2), 20).resize((W, H), Image.BILINEAR).point(lambda v: 250 + (v - 128) // 18)
    tex = ImageChops.multiply(paper, grain)
    out = ImageChops.multiply(im.convert("RGB"), Image.merge("RGB", (tex, tex, tex)).point(lambda v: min(255, v * 17 // 16)))
    out = out.crop((0, 0, W, 2160)).resize((W // 2, 1080), Image.LANCZOS)
    S.put_labels(out, sc, 48)
    return out


def palette():
    art = Image.new("RGBA", (780, 800), (0, 0, 0, 0))
    art.paste(hp.hx("#f6ecd6"), (0, 0, 780, 800))
    for prims, x, y, u in ((char("jeff", dig=True), 30, 250, 6), (char("chuck"), 260, 250, 6), (S.SHAPES["hoard"](), 450, 240, 5),
                           (S.SHAPES["loader"](), 30, 520, 5), (S.SHAPES["tree"](), 560, 540, 4.5),
                           (S.SHAPES["barn"](), 30, 790, 4), (S.SHAPES["house"](), 340, 790, 4), (S.SHAPES["boulder"](), 600, 790, 5)):
        lay, ox, oy = obj(prims, u)
        art.alpha_composite(lay, (int(x + ox + 3 * u), int(y + oy)))
    Lr = [(S.NAMES[k], [shade(COL[k], .58), shade(COL[k], .78), COL[k], shade(COL[k], 1.22)]) for k in hp.LAYERS]
    Lr += [("Players, costume, skin", [COL[k] for k in ("p1", "p2", "costume", "skin", "jeans", "boots")]),
           ("Vehicle, metal, tyre", [COL[k] for k in ("veh", "veh2", "stripe", "metal", "tyre", "lamp")]),
           ("Buildings", [COL[k] for k in ("barn", "roof", "roof2", "plaster", "wood", "trim", "oldwood")]),
           ("Nature", [COL[k] for k in ("grass", "leaf", "leaf2", "rock", "water", "lava", "moss")]),
           ("Treasure, ore, light", [COL[k] for k in ("gold", "gem", "copper", "bone", "flame")]),
           ("Sky, ink, night wash", [COL["sky"], COL["sky2"], COL["hill"], COL["far"], INK, COL["night"]])]
    return S.card("E  Picture book", "No pixels: 48 px per cell at 1080p. One flat colour per material (wall, rim, flat, mark), one warm ink line, "
                  "a blue night wash for the dark, cream paper under everything.", Lr, art)
