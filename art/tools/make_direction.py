#!/usr/bin/env python3
"""Render the art-direction option mocks for The Hill.

    python3 art/tools/make_direction.py          # writes art/direction/*.png and palettes.md

Every mock is composed at 640x360 and scaled x3 nearest-neighbour to 1920x1080.
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hillpix as hp  # noqa: E402
from hillpix import A, T, WHITE  # noqa: E402

W, H, SCALE = 640, 360, 3
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "direction")


def put(im, spr, x, ground_y):
    """Paste a sprite standing on ground_y (sprites carry a 1 px outline margin)."""
    im.alpha_composite(spr, (x, ground_y - spr.height + 1))


def mini_block(P, kind):
    return hp.outline(_pad(hp.tile(P, kind, 3, 5).crop((0, 0, 8, 8))), P["outline"])


def _pad(im):
    c = hp.canvas(im.width + 2, im.height + 2)
    c.paste(im, (1, 1))
    return c


def backdrop(im, P, horizon, peak_x, sun_x):
    hp.sky(im, P, horizon)
    d = ImageDraw.Draw(im)
    s = P["c"]["sun"]
    d.ellipse([sun_x - 13, 20, sun_x + 13, 46], fill=A(s))
    d.ellipse([sun_x - 10, 23, sun_x + 10, 43], fill=A(WHITE))
    hl = P["ramps"]["hill"]
    w = im.width
    # the Hill itself, with the Ruined Keep waiting on the peak
    d.ellipse([peak_x - 420, horizon - 60, peak_x - 60, horizon + 120], fill=A(hl[3]))
    d.ellipse([peak_x + 40, horizon - 46, peak_x + 380, horizon + 100], fill=A(hl[3]))
    d.ellipse([peak_x - 230, horizon - 132, peak_x + 230, horizon + 170], fill=A(hl[1]))
    d.ellipse([peak_x - 230, horizon - 132, peak_x + 222, horizon + 170], fill=A(hl[2]))
    k = P["ramps"]["weath"][2]
    kx, ky = peak_x - 12, horizon - 133
    notch = im.getpixel((kx + 21, ky - 14))
    d.rectangle([kx, ky - 16, kx + 22, ky + 4], fill=A(k))
    for x in (kx, kx + 6, kx + 12):
        d.rectangle([x, ky - 20, x + 3, ky - 16], fill=A(k))
    d.polygon([(kx + 15, ky - 16), (kx + 22, ky - 6), (kx + 22, ky - 16)], fill=notch)
    d.rectangle([kx + 8, ky - 8, kx + 12, ky + 4], fill=A(P["ramps"]["weath"][0]))
    d.line([kx, ky - 16, kx, ky + 4], fill=A(P["ramps"]["weath"][3]))


def scene_layers(P):
    im = Image.new("RGBA", (W, H), A(P["c"]["sky2"]))
    hp.sky(im, P, 16)
    wd = hp.World(40, 23)
    bands = [(0, None), (1, "top"), (4, "clay"), (7, "stone"), (10, "ice"), (13, "crys"), (16, "cav"), (20, "strange")]
    wd.fill(bands, edge_cols=(0, 39))
    wd.scrub = set(range(14, 33))
    wd.dig(4, 1, 5, 18)                    # the mine shaft
    wd.dig(6, 2, 12, 3)                    # topsoil tunnel
    wd.dig(6, 5, 8, 6)
    wd.dig(17, 5, 22, 6, fluid="water")    # water pocket
    wd.dig(16, 5, 16, 5)
    wd.dig(6, 8, 11, 9)
    wd.dig(12, 6, 13, 9)                   # boulder chute
    wd.dig(6, 11, 10, 12)
    wd.dig(6, 14, 9, 15)
    wd.dig(20, 14, 24, 15, fluid="lava")   # lava pocket
    wd.dig(2, 17, 37, 18)                  # the Dragon's cavern
    alcoves = {"top": 2, "clay": 5, "stone": 8, "ice": 11, "crys": 14}
    for k, y in alcoves.items():
        wd.dig(34, y, 37, y + 1)
    wd.render(im, P)
    d = ImageDraw.Draw(im)
    R = P["ramps"]
    # rope down the shaft
    d.line([88, 0, 88, 19 * T - 1], fill=A(R["metal"][1]))
    # roots and a waving worm in the topsoil
    for x0 in (150, 260, 420):
        pts = [(x0, 22), (x0 + 3, 27), (x0 + 1, 33), (x0 + 5, 38)]
        d.line(pts, fill=A(R["wood"][3]))
        d.line([(x0 + 3, 27), (x0 + 8, 30)], fill=A(R["wood"][3]))
    wx, wy = 7 * T + 2, 2 * T + 6
    for i, (dx, dy) in enumerate(((0, 0), (1, -1), (2, -2), (3, -2), (4, -3), (5, -5), (5, -6))):
        d.rectangle([wx + dx, wy + dy, wx + dx + 1, wy + dy + 1], fill=A(P["c"]["pink"]))
    d.point((wx + 6, wy - 6), fill=A(P["outline"]))
    # treasure sparkling through the dirt, two tiles from Jeff
    tx, ty = 14 * T + 3, 3 * T + 3
    im.alpha_composite(hp.treasure(P, "cap"), (tx, ty))
    hp.sparkle(im, tx + 8, ty + 1, P)
    hp.sparkle(im, tx - 9, ty + 9, P, big=False)
    hp.sparkle(im, tx + 15, ty - 7, P, big=False)
    put(im, hp.jeff(P), 9 * T - 2, 4 * T)
    # clay: an old pipe
    d.rectangle([26 * T, 5 * T + 5, 30 * T, 5 * T + 10], fill=A(R["metal"][2]))
    d.line([26 * T, 5 * T + 5, 30 * T, 5 * T + 5], fill=A(R["metal"][3]))
    d.line([26 * T, 5 * T + 10, 30 * T, 5 * T + 10], fill=A(R["metal"][0]))
    for x in (26 * T, 28 * T + 4, 30 * T - 2):
        d.rectangle([x, 5 * T + 3, x + 2, 5 * T + 12], fill=A(R["metal"][1]))
    # stone: ore, a gem, and a falling boulder
    for ox, oy in ((16, 8), (24, 7), (29, 9), (20, 9)):
        for dx, dy in ((3, 4), (5, 5), (6, 3), (9, 9), (10, 10), (4, 11)):
            d.rectangle([ox * T + dx, oy * T + dy, ox * T + dx + 1, oy * T + dy + 1], fill=A(R["gold"][2]))
            d.point((ox * T + dx, oy * T + dy), fill=A(R["gold"][3]))
    im.alpha_composite(hp.treasure(P, "gem"), (27 * T + 3, 8 * T + 3))
    hp.sparkle(im, 27 * T + 10, 8 * T + 3, P)
    bx, by = 12 * T + 3, 7 * T + 2
    for x in (bx + 5, bx + 12, bx + 19):
        d.line([x, by - 14 - (x % 5), x, by - 3], fill=A(WHITE))
    im.alpha_composite(hp.boulder(P), (bx, by))
    hp.puff(im, bx - 1, by + 4, 2, P)
    hp.puff(im, bx + 27, by + 8, 2, P)
    # ice: a frozen fish
    fx, fy = 17 * T, 11 * T + 4
    fish = hp.sprite(["..ff....f", ".ffff..ff", "fEfffffff", ".ffff..ff", "..ff....f"],
                     {"f": R["water"][3], "E": P["outline"]}, R["ice"][0])
    im.alpha_composite(fish, (fx, fy))
    d.rectangle([22 * T, 10 * T, 26 * T, 10 * T + 3], fill=A(WHITE))   # snow
    # cavern: stalactites, a gold heap, warm cracks
    for cx, n in ((9, 9), (14, 6), (21, 11), (30, 7), (24, 5)):
        d.polygon([(cx * T - 5, 17 * T), (cx * T + 5, 17 * T), (cx * T, 17 * T + n)], fill=A(R["cav"][1]))
        d.line([cx * T - 5, 17 * T, cx * T, 17 * T + n], fill=A(R["cav"][3]))
    hp.blob(d, 17 * T, 19 * T - 5, 22, 6, R["gold"])
    d.rectangle([17 * T - 24, 19 * T - 1, 17 * T + 24, 19 * T + 6], fill=A(R["cav"][2]))
    d.line([17 * T - 22, 19 * T, 17 * T + 22, 19 * T], fill=A(R["cav"][3]))
    for sx in (-12, 3, 14):
        hp.sparkle(im, 17 * T + sx, 19 * T - 8 - abs(sx) // 4, P, big=sx == 3)
    # every layer: both players against that layer's dug-out wall, and a name plate
    names = dict(alcoves, cav=17)
    wd = None
    for k, y in names.items():
        gy = (y + 2) * T
        put(im, hp.jeff(P, shovel=False), 34 * T + 3, gy)
        put(im, hp.chuck(P), 36 * T - 1, gy)
    plate = P["outline"]
    for k, y in (("top", 1), ("clay", 4), ("stone", 7), ("ice", 10), ("crys", 13), ("cav", 16), ("strange", 21)):
        hp.text(im, 28 * T + 4, y * T + 3, hp.LAYER_NAMES[k].upper(), WHITE, plate)
    hp.text(im, 1 * T + 6, 6 * T + 3, "EDGESTONE", WHITE, plate)
    return im


def scene_hillville(P):
    im = Image.new("RGBA", (W, H), A(P["c"]["sky2"]))
    G = 17
    gy = G * T
    backdrop(im, P, gy, 400, 560)
    im.alpha_composite(hp.cloud(P, 46), (60, 40))
    im.alpha_composite(hp.cloud(P, 34), (250, 22))
    im.alpha_composite(hp.cloud(P, 40), (450, 64))
    wd = hp.World(40, 23)
    wd.fill([(0, None), (G, "top"), (G + 4, "clay")])
    wd.dig(20, G, 21, 22)
    wd.plot = set(range(7, 18)) | set(range(23, 31))
    wd.scrub = set(range(0, 7)) | set(range(31, 40))
    R = P["ramps"]
    # behind the ground line
    put(im, hp.tree(P, "leaf", 1), 68, gy)
    put(im, hp.tree(P, "leaf2", 2), 590, gy)
    put(im, hp.tree(P, "leaf", 3), 548, gy)
    wd.render(im, P)
    d = ImageDraw.Draw(im)
    d.line([336, gy - 20, 336, H], fill=A(R["metal"][1]))
    put(im, hp.fence(P, 3, broken=(1,)), 0, gy)
    put(im, hp.old_shed(P), 22, gy)
    put(im, hp.house(P), 112, gy)
    for i, (px, py, r) in enumerate(((164, gy - 70, 3), (169, gy - 79, 4), (176, gy - 90, 5))):
        hp.puff(im, px, py, r, P)
    put(im, hp.barn(P), 188, gy)
    put(im, hp.headframe(P), 306, gy)
    # the shared block pile at the shaft
    for i, (k, bx, by) in enumerate((("top", 284, 0), ("top", 293, 0), ("clay", 288, 9), ("stone", 276, 0))):
        im.alpha_composite(mini_block(P, k), (bx, gy - 9 - by))
    put(im, hp.chuck(P), 370, gy)
    put(im, hp.loader(P), 394, gy)
    hp.puff(im, 441, gy - 52, 3, P)
    hp.puff(im, 436, gy - 60, 4, P)
    put(im, hp.stump(P), 492, gy)
    put(im, hp.rock(P), 514, gy)
    put(im, hp.stump(P), 572, gy)
    put(im, hp.rock(P, 16, 11), 620, gy)
    # a treasure hint under the town
    tx, ty = 12 * T + 3, (G + 2) * T + 3
    im.alpha_composite(hp.treasure(P, "cap"), (tx, ty))
    hp.sparkle(im, tx + 8, ty + 1, P)
    return im


def darkness(im, cx, cy, P):
    """Headlamp: three stepped rings with a checker seam. No smooth falloff."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** .5 + (5 if (x + y) % 2 else 0)
            f = 1 if dist < 70 else (.8 if dist < 104 else (.62 if dist < 140 else .46))
            if f < 1:
                r, g, b, a = px[x, y]
                px[x, y] = (int(r * f), int(g * f), int(b * f + (1 - f) * 26), a)


def badge(im, x, y, col, P):
    d = ImageDraw.Draw(im)
    d.ellipse([x - 8, y - 8, x + 8, y + 8], fill=A(P["outline"]))
    d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=A(WHITE))
    d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=A(col))


def scene_split(P):
    R = P["ramps"]
    # --- up top: Chuck in the Front Loader, clearing scrub
    up = Image.new("RGBA", (320, H), A(P["c"]["sky2"]))
    G = 14
    gy = G * T
    backdrop(up, P, gy, 60, 250)
    up.alpha_composite(hp.cloud(P, 40), (120, 50))
    wd = hp.World(20, 23)
    wd.fill([(0, None), (G, "top"), (G + 5, "clay")])
    wd.plot = set(range(0, 13))
    wd.scrub = set(range(13, 20))
    put(up, hp.tree(P, "leaf2", 4), 262, gy)
    wd.render(up, P)
    put(up, hp.barn(P), -30, gy)
    put(up, hp.loader(P, stripe=hp.RED, driver=hp.chuck(P), load="rock"), 104, gy)
    hp.puff(up, 151, gy - 53, 3, P)
    hp.puff(up, 145, gy - 62, 5, P)
    put(up, hp.rock(P), 212, gy)
    put(up, hp.stump(P), 240, gy)
    put(up, hp.tree(P, "leaf", 5), 222, gy) if False else None
    tx, ty = 6 * T + 3, (G + 3) * T + 3
    up.alpha_composite(hp.treasure(P, "cap"), (tx, ty))
    hp.sparkle(up, tx + 8, ty + 1, P)
    badge(up, 16, 16, hp.RED, P)
    # --- down below: Jeff digging at the clay/stone seam by headlamp
    dn = Image.new("RGBA", (320, H), A(P["back"]["stone"][0]))
    wd = hp.World(20, 23)
    wd.fill([(0, "clay"), (6, "stone"), (20, "ice")])
    wd.dig(2, 0, 3, 12)
    wd.dig(4, 11, 11, 12)
    wd.dig(10, 2, 14, 3, fluid="water")
    wd.dig(15, 6, 16, 12)
    wd.render(dn, P)
    d = ImageDraw.Draw(dn)
    d.line([48, 0, 48, 13 * T - 1], fill=A(R["metal"][1]))
    for ox, oy in ((7, 8), (12, 15), (5, 16), (17, 15)):
        for dx, dy in ((3, 4), (5, 5), (6, 3), (9, 9), (10, 10), (4, 11)):
            d.rectangle([ox * T + dx, oy * T + dy, ox * T + dx + 1, oy * T + dy + 1], fill=A(R["gold"][2]))
    tx, ty = 13 * T + 3, 12 * T + 3
    dn.alpha_composite(hp.treasure(P, "gem"), (tx, ty))
    bx, by = 15 * T + 3, 7 * T
    for x in (bx + 5, bx + 12, bx + 19):
        d.line([x, by - 14 - (x % 5), x, by - 3], fill=A(WHITE))
    dn.alpha_composite(hp.boulder(P), (bx, by))
    put(dn, hp.jeff(P), 8 * T, 13 * T)
    # dig particles in the block colour
    for dx, dy in ((30, -8), (34, -15), (38, -5), (33, -22), (40, -12)):
        d.rectangle([8 * T + dx, 13 * T + dy, 8 * T + dx + 1, 13 * T + dy + 1], fill=A(R["stone"][3]))
    darkness(dn, 8 * T + 10, 12 * T - 4, P)
    hp.sparkle(dn, tx + 8, ty + 1, P)
    hp.sparkle(dn, tx - 8, ty + 10, P, big=False)
    badge(dn, 304, 16, hp.GREEN, P)
    d = ImageDraw.Draw(dn)
    d.rounded_rectangle([98, 338, 222, 354], 4, fill=A(P["outline"]))
    for i, k in enumerate(("top", "top", "clay", "clay", "clay", "stone", "stone", "stone", "stone")):
        dn.alpha_composite(mini_block(P, k), (104 + i * 13, 341))
    im = Image.new("RGBA", (W, H))
    im.paste(up, (0, 0))
    im.paste(dn, (320, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([317, 0, 322, H], fill=A(P["outline"]))
    d.line([319, 0, 319, H], fill=A(WHITE))
    d.line([320, 0, 320, H], fill=A(WHITE))
    return im


SURFACE = ["sky1", "sky2", "cloud", "hill", "grass", "leaf", "leaf2", "wood", "wall", "roof", "roof2", "barn",
           "weath", "metal", "veh", "tyre", "glass", "water", "lava", "gold", "pink", "rock", "rune", "outline"]


def card(P):
    bgc = hp.hx("#26262e")
    im = Image.new("RGBA", (W, H), A(bgc))
    d = ImageDraw.Draw(im)
    hp.text(im, 6, 4, "THE HILL  PALETTE " + P["name"].upper(), WHITE, size=10)
    hp.text(im, 250, 6, P["mood"], hp.hx("#c8c8d4"))
    for i, n in enumerate(("deep", "low", "mid", "high", "wall", "wall-d")):
        hp.text(im, 72 + i * 44, 20, n, hp.hx("#9a9aa8"))
    for row, k in enumerate(hp.LAYERS):
        y = 32 + row * 41
        hp.text(im, 4, y + 6, hp.LAYER_NAMES[k], WHITE)
        cols = list(P["ramps"][k]) + list(P["back"][k])
        for i, c in enumerate(cols):
            x = 70 + i * 44
            d.rectangle([x, y, x + 41, y + 22], fill=A(c))
            hp.text(im, x, y + 24, hp.tohex(c), hp.hx("#c8c8d4"))
        x = 340
        d.rectangle([x, y - 2, x + 55, y + 34], fill=A(P["back"][k][0]))
        for tx in range(4):
            im.alpha_composite(hp.tile(P, k, tx + 2, row).crop((0, 0, 14, 4)), (x + tx * 14, y + 31))
        im.alpha_composite(hp.jeff(P, shovel=False), (x + 4, y - 2))
        im.alpha_composite(hp.chuck(P), (x + 30, y - 2))
    for i, n in enumerate(SURFACE):
        x = 408 + (i % 2) * 116
        y = 32 + (i // 2) * 24
        c = P["c"][n]
        d.rectangle([x, y, x + 21, y + 17], fill=A(c))
        hp.text(im, x + 26, y - 1, n, WHITE)
        hp.text(im, x + 26, y + 8, hp.tohex(c), hp.hx("#c8c8d4"))
    for i, (n, c) in enumerate((("P1 Jeff", hp.GREEN), ("P2 Chuck", hp.RED))):
        x = 408 + i * 116
        d.rectangle([x, 326, x + 21, 343], fill=A(c))
        hp.text(im, x + 26, 325, n, WHITE)
        hp.text(im, x + 26, 334, hp.tohex(c), hp.hx("#c8c8d4"))
    return im


def scene_rules(P):
    """Reference sheet for pixel-rules.md: the two players at 1x, 2x and 6x, the ramp, the vehicle face."""
    bgc = hp.hx("#26262e")
    im = Image.new("RGBA", (W, H), A(bgc))
    d = ImageDraw.Draw(im)
    R = P["ramps"]
    hp.text(im, 6, 4, "THE HILL  PIXEL RULES  (shown in palette " + P["name"].upper() + ")", WHITE, size=10)
    # big: 6x, on the stone wall and on sky
    for i, (spr, bg) in enumerate(((hp.jeff(P), P["back"]["stone"][0]), (hp.chuck(P), P["c"]["sky2"]))):
        x = 8 + i * 170
        d.rectangle([x, 24, x + 161, 221], fill=A(bg))
        im.alpha_composite(spr.resize((spr.width * 6, spr.height * 6), Image.NEAREST), (x + 6 + i * 20, 28))
    hp.text(im, 8, 224, "JEFF  P1  green hat + wing tips", WHITE)
    hp.text(im, 178, 224, "CHUCK  P2  red hat + swirl", WHITE)
    # real size and 2x on every layer wall
    hp.text(im, 8, 240, "real size (32 px) on each layer's tunnel wall, and at 2x", hp.hx("#c8c8d4"))
    for i, k in enumerate(hp.LAYERS[:6]):
        x = 8 + i * 56
        d.rectangle([x, 252, x + 53, 286], fill=A(P["back"][k][0]))
        im.alpha_composite(hp.jeff(P, shovel=False), (x + 3, 253))
        im.alpha_composite(hp.chuck(P), (x + 29, 253))
    for i, spr in enumerate((hp.jeff(P), hp.chuck(P))):
        d.rectangle([8 + i * 60, 290, 62 + i * 60, 356], fill=A(P["ramps"]["top"][2] if i == 0 else P["back"]["crys"][0]))
        im.alpha_composite(spr.resize((spr.width * 2, spr.height * 2), Image.NEAREST), (10 + i * 62, 291))
    # ramp rule
    hp.text(im, 350, 24, "4-shade ramp: deep, low, MID, high. Hue-shifted.", WHITE)
    for row, k in enumerate(("top", "stone", "veh", "p1", "p2", "costume")):
        for i, c in enumerate(R[k]):
            d.rectangle([350 + i * 26, 36 + row * 14, 350 + i * 26 + 24, 36 + row * 14 + 11], fill=A(c))
        hp.text(im, 458, 37 + row * 14, k, hp.hx("#c8c8d4"))
    d.rectangle([500, 36, 524, 117], fill=A(P["outline"]))
    hp.text(im, 528, 37, "outline", hp.hx("#c8c8d4"))
    hp.text(im, 528, 50, "(tinted, never", hp.hx("#c8c8d4"))
    hp.text(im, 528, 60, "pure black)", hp.hx("#c8c8d4"))
    # light direction
    d.rectangle([350, 128, 468, 176], fill=A(P["c"]["sky2"]))
    im.alpha_composite(hp.boulder(P), (358, 140))
    im.alpha_composite(hp.rock(P), (392, 152))
    im.alpha_composite(hp.treasure(P, "cap"), (428, 136))
    im.alpha_composite(hp.treasure(P, "gem"), (446, 152))
    d.line([352, 130, 362, 140], fill=A(P["c"]["sun"]))
    d.line([352, 130, 357, 130], fill=A(P["c"]["sun"]))
    d.line([352, 130, 352, 135], fill=A(P["c"]["sun"]))
    hp.text(im, 474, 130, "light from top-left:", WHITE)
    hp.text(im, 474, 142, "high spot up-left, low", hp.hx("#c8c8d4"))
    hp.text(im, 474, 152, "crescent down-right,", hp.hx("#c8c8d4"))
    hp.text(im, 474, 162, "1 px outline all round", hp.hx("#c8c8d4"))
    # vehicle face
    d.rectangle([350, 186, 632, 296], fill=A(P["c"]["sky2"]))
    d.rectangle([350, 284, 632, 296], fill=A(R["top"][2]))
    put(im, hp.loader(P), 356, 284)
    put(im, hp.loader(P, stripe=hp.GREEN, driver=hp.jeff(P, shovel=False)), 450, 284)
    put(im, hp.loader(P, stripe=hp.RED, driver=hp.chuck(P)), 540, 284)
    hp.text(im, 350, 300, "vehicle face: headlight eyes + bumper smile on the hood.", WHITE)
    hp.text(im, 350, 312, "empty: cream stripe. driven: the player's colour.", hp.hx("#c8c8d4"))
    hp.text(im, 350, 328, "tiles: no outline, lit edges. sprites: 1 px outline.", hp.hx("#c8c8d4"))
    for i, k in enumerate(hp.LAYERS):
        im.alpha_composite(hp.tile(P, k, i + 3, 2), (350 + i * 18, 340))
    return im


def up(im, clear=True):
    big = im.resize((W * SCALE, H * SCALE), Image.NEAREST).convert("RGB")
    hp.flush(big, SCALE, clear=clear)
    return big


def checks(P):
    """Player-pop numbers: CIE76 delta-E of each player colour against every layer."""
    rows, worst = [], 999
    for k in hp.LAYERS:
        vals = []
        for pc in (hp.GREEN, hp.RED):
            for bgc in (P["ramps"][k][2], P["back"][k][0]):
                vals.append(hp.delta_e(pc, bgc))
        worst = min(worst, min(vals))
        rows.append((k, vals))
    tres = [n for n in SURFACE + hp.LAYERS if any(hp.reserved_hue(c) for c in P["ramps"][n])] + \
           [k + " wall" for k in hp.LAYERS if any(hp.reserved_hue(c) for c in P["back"][k])]
    return rows, worst, tres


def separation(P):
    """Closest pair of layer mids (CIE76): the number that says whether depth reads."""
    pairs = sorted((hp.delta_e(P["ramps"][a][2], P["ramps"][b][2]), a, b)
                   for i, a in enumerate(hp.LAYERS) for b in hp.LAYERS[i + 1:])
    return pairs[0]


def palettes_md(pals):
    L = ["# The Hill: palette options", "",
         "Generated by `art/tools/make_direction.py` from the specs in `art/tools/hillpix.py`. Do not hand-edit;",
         "change the spec and re-run. Swatch cards: `palette_a.png`, `palette_b.png`, `palette_c.png`.", "",
         "Fixed in every option (identity, from the character library): P1 green `#3cc24a`, P2 red `#e4393c`,",
         "Jeff's costume `#ffd84d`, jeans `#3b5ba5`, Chuck's boots `#8a5a2b`, shirt shadow `#1e1e26`.", "",
         "Each layer ramp is four shades (deep, low, mid, high) plus two dug-out wall shades. Shadows shift hue",
         "toward the option's shadow hue and highlights toward its light hue (see `pixel-rules.md`).", ""]
    for P in pals:
        k = P["k"]
        L += ["## " + P["name"], "", P["mood"], "",
              "Shadow hue %d°, light hue %d°, %d° shift per step. Outline `%s`." % (k["sh_hue"], k["hi_hue"], k["deg"], hp.tohex(P["outline"])), "",
              "| Layer | deep | low | mid | high | wall | wall dark |", "| --- | --- | --- | --- | --- | --- | --- |"]
        for n in hp.LAYERS:
            cs = list(P["ramps"][n]) + list(P["back"][n])
            L.append("| %s | %s |" % (hp.LAYER_NAMES[n], " | ".join("`%s`" % hp.tohex(c) for c in cs)))
        L += ["", "| Surface and props | mid | | | mid |", "| --- | --- | --- | --- | --- |"]
        for i in range(0, len(SURFACE), 2):
            a, b = SURFACE[i], SURFACE[i + 1]
            L.append("| %s | `%s` | | %s | `%s` |" % (a, hp.tohex(P["c"][a]), b, hp.tohex(P["c"][b])))
        rows, worst, tres = checks(P)
        L += ["", "Player pop (CIE76 ΔE; under 25 would be a fail, 40+ is comfortable):", "",
              "| Layer | green on tile | green on wall | red on tile | red on wall |", "| --- | --- | --- | --- | --- |"]
        for n, v in rows:
            L.append("| %s | %s |" % (hp.LAYER_NAMES[n], " | ".join("%.0f" % x for x in v)))
        L += ["", "Worst case ΔE %.0f. Environment colours inside a player's reserved hue band: %s." % (worst, ", ".join(tres) or "none"), ""]
        sd, sa, sb = separation(P)
        L += ["Closest two layers: %s and %s, ΔE %.0f (under 20 would smear at TV distance). The hoard gold on the cavern"
              % (hp.LAYER_NAMES[sa], hp.LAYER_NAMES[sb], sd),
              "tile is ΔE %.0f, on the cavern wall %.0f." % (hp.delta_e(P["c"]["gold"], P["ramps"]["cav"][2]),
                                                             hp.delta_e(P["c"]["gold"], P["back"]["cav"][0])), ""]
    return "\n".join(L)


def main():
    os.makedirs(OUT, exist_ok=True)
    pals = [hp.build(hp.PALETTES[k]) for k in "abc"]
    grid = Image.new("RGB", (W * 3, H * 3))
    for i, P in enumerate(pals):
        k = P["key"]
        up(card(P)).save(os.path.join(OUT, "palette_%s.png" % k))
        for j, (name, fn) in enumerate((("layers", scene_layers), ("hillville", scene_hillville), ("split", scene_split))):
            im = fn(P)
            up(im, clear=False).save(os.path.join(OUT, "%s_%s.png" % (k, name)))
            grid.paste(im.convert("RGB"), (i * W, j * H))
            if j == 0:
                hp.text(im, 100, 3, P["name"].upper(), WHITE, P["outline"], size=12)
            hp.flush(grid, 1, i * W, j * H)
        rows, worst, tres = checks(P)
        print(P["name"], "worst dE %.0f" % worst, "trespass:", tres, "closest layers: %.0f %s/%s" % separation(P))
    up(scene_rules(pals[0])).save(os.path.join(OUT, "pixel-rules.png"))
    d = ImageDraw.Draw(grid)
    for x in (W, 2 * W):
        d.line([x, 0, x, H * 3], fill=(255, 255, 255), width=2)
    grid.save(os.path.join(OUT, "compare.png"))
    with open(os.path.join(OUT, "palettes.md"), "w") as f:
        f.write(palettes_md(pals))


if __name__ == "__main__":
    main()
