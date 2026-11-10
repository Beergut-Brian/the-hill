"""Style D, Terraria-leaning: dense 16 px material tiles, tile light with soft falloff,
parallax backdrops, grounded 2.6-head characters. Renders a scenes2 scene at 1x, shown x3."""
import colorsys
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import scenes2 as S

hp, T = S.hp, 16
OUT = (24, 18, 26)


def rmp(h):
    r, g, b = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    hh, s, v = colorsys.rgb_to_hsv(r, g, b)
    out = []
    for t in (-1, -.5, 0, .5, 1):
        ss = min(1, s * (1 - .25 * t)) if t < 0 else s * (1 - .35 * t)
        out.append(tuple(int(255 * c) for c in colorsys.hsv_to_rgb(hh, ss, max(0, min(1, v * (1 + .42 * t) + .04 * t)))))
    return out


MID = dict(
    top="#7a5233", clay="#b5562f", stone="#666e7c", ice="#7fb6dc", crys="#6b42a6", cav="#5a3540", strange="#1f4d50", edge="#77777c",
    barn="#8a3d2c", barn2="#74321f", roof="#4c3d3e", roof2="#526684", trim="#d8ceb4", dark="#2a1e22", brick="#93503a",
    plaster="#cfc2a0", wood="#7b5a3a", wood2="#a07a4e", door="#5e4128", glass="#7fb2c8", lamp="#ffe9a0", lampo="#f08a2a",
    oldwood="#6f665c", oldwood2="#5a5148", oldroof="#4f4a48", rock="#857f7a", rock2="#a59f98", moss="#9aa63c",
    metal="#8d96a3", metal2="#5d6570", veh="#dc9a1c", veh2="#a86c12", stripe="#e2d6b4", p1="#3cc24a", p2="#e4393c",
    tyre="#2e2c34", leaf="#2f7d68", leaf2="#58a889", flame="#ffb030", gold="#f2c230", gold2="#fff0a0", gem="#48d0e0",
    gem2="#c8f8ff", bone="#e6dcc0", grass="#7f9a2e", grass2="#a2b63a", rope="#b79b6b", water="#2f6fb0", lava="#f0702a",
    copper="#d0733a", skin="#e8b088", costume="#f0c838", jeans="#3f5f9c", boots="#70452a", shirt="#2a2830", pink="#f078a8",
    beak="#f08a2a", sky="#4a86cf", sky2="#b4d9ee", mount="#8fb0d2", hill="#6f9a66", woods="#3d7468", cloud="#eef2f6")
MID.update(dirtb=MID["top"], stoneb=MID["stone"], clayb=MID["clay"])
RAMP = {k: rmp(v) for k, v in MID.items()}
EMIS = {"flame", "lamp", "lampo", "gold2", "gem2"}
PLANK = {"barn", "barn2", "oldwood", "oldwood2", "door", "wood", "wood2"}
SHING = {"roof", "roof2", "oldroof"}
SMOOTH = {"veh", "veh2", "glass", "metal", "metal2", "stripe", "p1", "p2", "trim", "lamp", "lampo", "tyre", "gold", "gold2", "gem", "gem2", "flame"}


def hs(x, y, s=0):
    h = (x * 73856093 ^ y * 19349663 ^ s * 83492791) & 0xffffffff
    h = ((h ^ h >> 13) * 0x5bd1e995) & 0xffffffff
    return h ^ h >> 15


def vn(x, y, sc=6, s=0):
    gx, gy = x / sc, y / sc
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b, c, d = [hs(x0 + i, y0 + j, s) / 4294967296 for j in (0, 1) for i in (0, 1)]
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy


def ttex(k, X, Y):
    """Shade index 0..4 (or an emissive colour) for world pixel X, Y of block kind k."""
    n, h = vn(X, Y, 5, 1), hs(X, Y) % 100
    if k == "top":
        return 0 if h < 4 else 3 if h < 9 else 2 + (n > .62) - (n < .36)
    if k == "clay":
        w = math.sin((Y + 4 * vn(X, Y, 9, 2)) * 1.25)
        return 0 if h < 2 else 2 + (w > .5) - (w < -.55)
    if k == "stone":
        c = hs((X + int(3 * vn(X, Y, 4, 3))) // 7, (Y + int(3 * vn(X, Y, 4, 4))) // 6, 5) % 3
        return 0 if abs(vn(X, Y, 11, 6) - .5) < .022 else 1 + c
    if k == "ice":
        return 4 if h < 2 else 3 if (X + Y) % 11 < 2 else 2 - (n < .3)
    if k == "crys":
        return 4 if h < 3 else 1 + (X // 3 + Y // 4 + hs(X // 6, Y // 8, 7) % 3) % 3
    if k == "cav":
        return (240, 120, 40) if h < 1 else 1 + (n > .5) + (h > 95)
    if k == "strange":
        if hs(X // T, Y // T, 9) % 3 == 0 and 5 <= X % T < 10 and 5 <= Y % T < 10:
            if hp.RUNES[hs(X // T, Y // T, 8) % len(hp.RUNES)].split()[Y % T - 5][X % T - 5] == "1":
                return (88, 200, 180)
        return 0 if Y % 8 == 0 or (X + (Y // 8) % 2 * 8) % T == 0 else 1 + (n > .6)
    lx, ly = X % T, Y % T
    return 4 if (lx, ly) in ((3, 3), (12, 12)) else 1 if lx in (0, 15) or ly in (0, 15) else 2 + ((lx + ly) % 8 < 2 and Y % 48 < 16)


def mtex(m, x, y):
    h = hs(x, y, 11) % 100
    if m in PLANK:
        return 1 if x % 5 == 0 else 2 + (hs(x // 5, y // 9, 2) % 3 == 0) - (h < 8)
    if m in SHING:
        return 1 if y % 4 == 0 or (x + (y // 4) % 2 * 3) % 6 == 0 else 2 + (h < 15)
    if m in ("stone", "brick", "stoneb"):
        return 1 if y % 5 == 0 or (x + (y // 5) % 2 * 4) % 8 == 0 else 2 + (h < 20)
    if m in SMOOTH:
        return 2 + (h < 4)
    return 2 + (vn(x, y, 3, 12) > .6) - (vn(x, y, 3, 13) > .68)


def bbox(prims):
    xs, ys = [], []
    for p in prims:
        if p[1] == "e":
            cx, cy, rx, ry = p[2]
            xs += [cx - rx, cx + rx]
            ys += [cy - ry, cy + ry]
        elif p[1] == "h":
            xs += [p[2][0], p[2][0] + 16]
            ys += [p[2][1] - 14, p[2][1]]
        else:
            xs += [q[0] for q in p[2]]
            ys += [q[1] for q in p[2]]
    return math.floor(min(xs)) - 3, math.floor(min(ys)) - 3, math.ceil(max(xs)) + 3, math.ceil(max(ys)) + 3


def sprite(prims):
    """Rasterise shared primitives as textured pixel art. Returns (image, emissive, ox, oy)."""
    x0, y0, x1, y1 = bbox(prims)
    w, h = x1 - x0, y1 - y0
    im, em = hp.canvas(w, h), hp.canvas(w, h)
    px, ex = im.load(), em.load()
    for p in prims:
        if p[1] == "h":
            head = char(p[0]).crop((1, 1, 17, 14))
            im.alpha_composite(head, (int(p[2][0] - x0), int(p[2][1] - y0 - 13)))
            continue
        m = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(m)
        if p[1] == "e":
            cx, cy, rx, ry = p[2]
            d.ellipse([cx - rx - x0, cy - ry - y0, cx + rx - x0, cy + ry - y0], fill=255)
        elif p[1] == "p":
            d.polygon([(x - x0, y - y0) for x, y in p[2]], fill=255)
        else:
            d.line([(x - x0, y - y0) for x, y in p[2]], fill=255, width=p[3])
        mp, r, thin = m.load(), RAMP[p[0]], p[1] == "l" and p[3] < 3
        bx = m.getbbox()
        if not bx:
            continue
        for y in range(bx[1], bx[3]):
            for x in range(bx[0], bx[2]):
                if not mp[x, y]:
                    continue
                i = mtex(p[0], x, y)
                if not thin:
                    if not mp[x, max(0, y - 1)] or not mp[max(0, x - 1), y]:
                        i += 1
                    elif not mp[x, min(h - 1, y + 1)] or not mp[min(w - 1, x + 1), y]:
                        i -= 2
                px[x, y] = r[max(0, min(4, i))] + (255,)
                if p[0] in EMIS:
                    ex[x, y] = px[x, y]
    return hp.outline(im, OUT), em, x0 - 1, y0 - 1


JEFF = ["......PP........", ".....PPPp.......", "....GGGPGG......", "...GHHGGGGg.....", "..GHGGGGGGGg....", "..GGGGGGGGGgOO..",
        "..YYYYYYOOOOO...", "..YYSSSSSSSy....", "..YYSSESSESy....", "..YySSSSSSSy....", "..YySETTTESy....", "...YySSSSSy.....",
        "...YYYYYYYYy....", "..YYYYYYYYYYy...", ".YYYYWYYYYYYYy..", ".YYyYYYYYYYyYy..", ".YYyYYYYYYYyYy..", ".YYyYYYYYYYyYy..",
        ".GGyYYYYYYYyGG..", ".GG.YYYYYYYyGG..", "....YYYYYYYy....", "....BBBBBBBb....", "....BBBBBBBb....", "....BBBbBBBb....",
        "....BBBb.BBb....", "....BBBb.BBb....", "....BBBb.BBb....", "....BBBb.BBb....", "....BBb..BBb....", "....SSs..SSs....",
        "...SSSs..SSSs...", "...SSSSs.SSSSs.."]
CHUCK = ["................", "....RRRRRR......", "...RHHRRRRr.....", "...RHRRDDRRr....", "...RRRRDDRRr....", "...RRRRRRRRRRRr.",
         "...KSSSSSSSs....", "...SEESSEESs....", "...SSESSSESs....", "...SSSSSSSSs....", "...SSsEEEESs....", "....SSSSSSs.....",
         "...CCCCCCCCc....", "..CCCCRRCCCCc...", ".CCCCRCCRCTCCc..", ".CCcCRCRCCCcCc..", ".CCcCCRRCCCcCc..", ".CCcCCCCCCCcCc..",
         ".SScCCCCCCCcSS..", ".SS.CCCCCCCcSS..", "....CCCCCCCc....", "....BBBBBBBb....", "....BBBBBBBb....", "....BBBbBBBb....",
         "....BBBb.BBb....", "....BBBb.BBb....", "....BBBb.BBb....", "....BBBb.BBb....", "....NNNn.NNNn...", "....NNNn.NNNn...",
         "....NNNn.NNNNn..", "...NNNNn.NNNNNn."]


def char(who, dig=False, lamp=False):
    r = RAMP
    lg = {"G": r["p1"][2], "g": r["p1"][1], "H": r["p1"][4], "R": r["p2"][2], "r": r["p2"][1], "P": r["pink"][2], "p": r["pink"][1],
          "Y": r["costume"][2], "y": r["costume"][1], "W": r["costume"][4], "O": r["beak"][2], "S": r["skin"][2], "s": r["skin"][1],
          "E": OUT, "T": (255, 255, 255), "B": r["jeans"][2], "b": r["jeans"][0], "C": r["shirt"][2], "c": r["shirt"][0],
          "K": r["boots"][0], "D": r["costume"][2], "N": r["boots"][2], "n": r["boots"][0]}
    if who == "chuck":
        lg["H"] = r["p2"][4]
    body = hp.sprite(JEFF if who == "jeff" else CHUCK, lg)
    im = hp.canvas(26, 34)
    if dig:
        d = ImageDraw.Draw(im)
        d.line([14, 17, 22, 28], fill=r["wood"][3] + (255,))
        d.polygon([(21, 26), (25, 27), (24, 32), (20, 30)], fill=r["metal"][3] + (255,))
    im.alpha_composite(body, (1, 1))
    if lamp:
        im.putpixel((12, 5), (255, 240, 170, 255))
        im.putpixel((13, 5), (255, 255, 255, 255))
    return hp.outline(im, OUT)


def backdrop(W, H, sc):
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    hz = sc["surf"] * T
    a, b = RAMP["sky"][2], RAMP["sky2"][3]
    for y in range(H):
        t = min(1, y / hz) ** 1.4
        d.line([0, y, W, y], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    if sc["hill"] is None:
        return im
    d.ellipse([W * .78 - 9, 30, W * .78 + 9, 48], fill=(255, 246, 214))
    for cx, cy, s in ((60, 40, 1), (250, 66, .8), (430, 34, 1.1), (590, 80, .7)):
        for dx, dy, r in ((0, 0, 9), (10, 2, 7), (-10, 3, 6), (19, 5, 4)):
            d.ellipse([cx + (dx - r) * s, cy + (dy - r * .6) * s, cx + (dx + r) * s, cy + (dy + r * .6) * s], fill=RAMP["cloud"][2 + (dy == 0)])
    for layer, (col, base, amp, sc_) in enumerate(((RAMP["mount"][3], hz - 70, 60, 70), (RAMP["mount"][2], hz - 44, 46, 40))):
        d.polygon([(0, hz)] + [(x, base - amp * vn(x, layer * 50, sc_, 20 + layer) ** 1.5) for x in range(0, W + 4, 4)] + [(W, hz)], fill=col)
    hx_ = sc["hill"]
    d.ellipse([hx_ - 250, hz - 116, hx_ + 250, hz + 120], fill=RAMP["hill"][2])
    px = im.load()
    for y in range(hz - 116, hz):
        for x in range(max(0, hx_ - 250), min(W, hx_ + 250)):
            if px[x, y] == RAMP["hill"][2]:
                v = vn(x, y * 2, 7, 30)
                m = RAMP["hill"]
                px[x, y] = tuple((2 * m[2][i] + m[1 if v < .33 else 3 if v > .7 else 2][i]) // 3 for i in range(3))
    k = RAMP["oldroof"]
    d.rectangle([hx_ - 8, hz - 134, hx_ + 5, hz - 114], fill=k[3])
    d.polygon([(hx_ + 5, hz - 126), (hx_ + 12, hz - 118), (hx_ + 12, hz - 113), (hx_ + 5, hz - 113)], fill=k[2])
    for x in (-8, -3, 2):
        d.rectangle([hx_ + x, hz - 138, hx_ + x + 2, hz - 134], fill=k[3])
    d.rectangle([hx_ - 3, hz - 124, hx_, hz - 114], fill=k[0])
    for x in range(W):
        top = hz - 10 - int(16 * vn(x, 0, 14, 40) + 5 * vn(x, 0, 3, 41))
        for y in range(top, hz):
            px[x, y] = RAMP["woods"][1 + (hs(x, y) % 5 == 0) + (y - top < 3)]
    return im


def cavebg(W, H):
    im = Image.new("RGB", (W, H), (20, 13, 22))
    px = im.load()
    for x in range(W):
        for col, sc_, s, amp in (((38, 24, 38), 30, 50, 34), ((58, 36, 46), 17, 51, 22)):
            up, dn = int(amp * vn(x, 0, sc_, s)), int(amp * vn(x, 9, sc_, s + 5))
            for yy in range(H):
                y = yy % 64
                if y < up or y > 63 - dn:
                    px[x, yy] = col
    return im


def render(sc):
    w, cols, rows = sc["w"], sc["cols"], sc["rows"]
    W, H = cols * T, rows * T
    im = backdrop(W, H, sc) if sc["surf"] is not None else Image.new("RGB", (W, H), (10, 8, 14))
    im = im.convert("RGBA")
    em = hp.canvas(W, H)
    px, ex = im.load(), em.load()
    far = cavebg(W, H).load()
    for ty in range(rows):
        for tx in range(cols):
            k, bk, fl = w.solid[ty][tx], w.back[ty][tx], w.fluid.get((tx, ty))
            if k is None and bk is None:
                continue
            ex_ = [not w.is_solid(tx + dx, ty + dy) for dx, dy in ((0, -1), (-1, 0), (0, 1), (1, 0))]  # up, left, down, right
            for ly in range(T):
                for lx in range(T):
                    X, Y = tx * T + lx, ty * T + ly
                    if k:
                        i = ttex(k, X, Y)
                        if isinstance(i, tuple):
                            px[X, Y] = ex[X, Y] = i + (255,)
                            continue
                        e = (ly == 0 and ex_[0], lx == 0 and ex_[1], ly == 15 and ex_[2], lx == 15 and ex_[3])
                        if any(e):
                            i = 0
                        elif (ly == 1 and ex_[0]) or (lx == 1 and ex_[1]):
                            i += 1
                        elif (ly == 14 and ex_[2]) or (lx == 14 and ex_[3]):
                            i -= 1
                        px[X, Y] = RAMP[k][max(0, min(4, i))] + (255,)
                    elif (tx, ty) in sc["far"]:
                        px[X, Y] = far[X, Y] + (255,)
                    else:
                        i = ttex(bk, X + 5, Y + 3)
                        c = RAMP[bk][max(0, min(2, i - 1))] if not isinstance(i, tuple) else RAMP[bk][1]
                        c = (int(c[0] * .5), int(c[1] * .5), int(c[2] * .6))
                        if fl == "water":
                            top = (tx, ty - 1) not in w.fluid and ly < 2
                            c = RAMP["water"][4 if top and (X + ly * 3) % 7 < 4 else 2 + ((X + Y // 2) % 9 < 2)] if top else tuple((a + 2 * b) // 3 for a, b in zip(c, RAMP["water"][2 - (hs(X // 3, Y, 3) % 9 == 0)]))
                        elif fl == "lava":
                            c = RAMP["lava"][2 + (vn(X, Y, 4, 60) > .55) + (ly < 2 and (tx, ty - 1) not in w.fluid)]
                            ex[X, Y] = c + (255,)
                        px[X, Y] = c + (255,)
            if k == "top" and ty == sc["surf"] and ex_[0]:
                wild = tx not in w.plot
                for lx in range(T):
                    X = tx * T + lx
                    for y in range(ty * T - (hs(X, 0, 70) % (6 if wild else 2) + (1 if wild else 0)), ty * T + 3 + hs(X, 1, 71) % 2):
                        if 0 <= y < H:
                            px[X, y] = RAMP["grass"][3 if y < ty * T else 2 - (hs(X, y, 72) % 4 == 0)] + (255,)
            ore = sc["ores"].get((tx, ty))
            if ore and k:
                for j in range(4):
                    ox, oy = tx * T + 2 + hs(tx, ty, 80 + j) % 10, ty * T + 2 + hs(tx, ty, 90 + j) % 10
                    for dx, dy, i in ((0, 0, 4), (1, 0, 3), (0, 1, 2), (1, 1, 1), (2, 1, 0), (2, 0, 2)):
                        px[ox + dx, oy + dy] = RAMP[ore][i] + (255,)
                    if ore != "copper":
                        ex[ox, oy] = RAMP[ore][4] + (255,)
    for kind, x, y, o in sc["ents"]:
        if kind in ("jeff", "chuck"):
            s, e, ox, oy = char(kind, o.get("dig"), o.get("lamp")), None, 0, -33
        else:
            s, e, ox, oy = sprite(S.SHAPES[kind](**o))
        im.alpha_composite(s, (x + ox, y + oy)) if 0 <= x + ox and x + ox + s.width <= W else im.paste(s, (x + ox, y + oy), s)
        if e:
            em.paste(e, (x + ox + 1, y + oy + 1), e)
    lm = S.lightmap(sc).resize((W, H), Image.BICUBIC).point(lambda v: 20 + int(235 * (v / 255) ** .75))
    out = ImageChops.multiply(im.convert("RGB"), lm)
    out.paste(em, (0, 0), em)
    glow = Image.new("RGB", (W, H))
    g = ImageDraw.Draw(glow)
    for tx, ty, c in sc["lights"]:
        if min(c) < 1:
            g.ellipse([tx * T - 2, ty * T - 2, tx * T + 18, ty * T + 18], fill=tuple(int(120 * v) for v in c))
    e2 = Image.new("RGB", (W, H))
    e2.paste(em, (0, 0), em)
    glow = ImageChops.add(glow.filter(ImageFilter.GaussianBlur(9)), e2.filter(ImageFilter.GaussianBlur(2)).point(lambda v: v * 2 // 3))
    out = ImageChops.screen(out, glow).crop((0, 0, W, 360)).resize((W * 3, 1080), Image.NEAREST)
    S.put_labels(out, sc, 48)
    return out


def palette():
    art = hp.canvas(200, 200)
    for i, who in enumerate(("jeff", "chuck")):
        art.alpha_composite(char(who, dig=i == 0), (4 + i * 30, 6))
    for name, x, base in (("boulder", 70, 40), ("hoard", 100, 40), ("loader", 2, 112), ("tree", 152, 112), ("barn", 4, 194), ("house", 92, 194)):
        s, e, ox, oy = sprite(S.SHAPES[name]())
        art.alpha_composite(s, (x, base - s.height + 2))
    art = art.resize((800, 800), Image.NEAREST)
    L = [(S.NAMES[k], RAMP[k]) for k in hp.LAYERS]
    L += [("Players, costume, skin", [RAMP["p1"][2], RAMP["p2"][2], RAMP["costume"][2], RAMP["skin"][2], RAMP["jeans"][2], RAMP["boots"][2]]),
          ("Vehicle, metal, tyre", [RAMP["veh"][2], RAMP["veh"][1], RAMP["stripe"][2], RAMP["metal"][2], RAMP["tyre"][2], RAMP["lamp"][2]]),
          ("Buildings", [RAMP[k][2] for k in ("barn", "roof", "roof2", "plaster", "wood", "trim", "oldwood")]),
          ("Nature", [RAMP[k][2] for k in ("grass", "leaf", "leaf2", "rock", "water", "lava", "moss")]),
          ("Treasure, ore, light", [RAMP[k][2] for k in ("gold", "gem", "copper", "bone", "flame")]),
          ("Sky and distance", [RAMP["sky"][2], RAMP["sky2"][3], RAMP["mount"][3], RAMP["hill"][2], RAMP["woods"][1], OUT])]
    return S.card("D  Terraria-leaning", "16 px tiles shown x3. Five-shade ramps (dark to light) per material; outline is one near-black plum. "
                  "Light is computed per tile and multiplied over everything.", L, art)
