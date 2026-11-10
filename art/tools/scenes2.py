"""Round 2 direction mocks: the scenes and the object shapes, shared by every style.

A scene is data (a hillpix.World grid, lights, entities). An object is a list of flat
primitives in 1x pixels (16 per tile), origin at its bottom-left on the ground, y up is
negative. Each style (hill_d.py, hill_e.py) draws the same data its own way, so the
styles can be compared like for like. Vehicles have no faces: lamps are lights.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hillpix as hp  # noqa: E402

T = 16
NAMES = hp.LAYER_NAMES


def R(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def P(mat, pts):
    return (mat, "p", pts)


def E(mat, cx, cy, rx, ry=None):
    return (mat, "e", (cx, cy, rx, ry or rx))


def L(mat, pts, w=1):
    return (mat, "l", pts, w)


# ------------------------------------------------------------------ shapes
def barn():
    gable = [(4, -34), (11, -50), (25, -59), (47, -59), (61, -50), (68, -34)]
    return [P("roof", [(0, -33), (8, -52), (24, -62), (48, -62), (64, -52), (72, -33)]),
            P("barn", gable + [(68, -5), (4, -5)]), P("stone", R(2, -5, 70, 0)),
            L("trim", gable, 2), L("trim", [(4, -34), (68, -34)], 1),
            P("dark", R(31, -51, 41, -41)), L("trim", R(31, -51, 41, -41) + [(31, -51)], 1),
            P("trim", R(25, -29, 47, -5)), P("barn2", R(27, -27, 45, -5)),
            L("trim", [(27, -27), (45, -5)], 1), L("trim", [(45, -27), (27, -5)], 1), L("trim", [(36, -27), (36, -5)], 1)]


def house():
    return [P("brick", R(38, -53, 45, -38)), P("stone", R(3, -4, 53, 0)), P("plaster", R(5, -27, 51, -4)),
            P("roof2", [(0, -26), (13, -45), (43, -45), (56, -26)]),
            L("wood", [(5, -27), (5, -4)], 2), L("wood", [(51, -27), (51, -4)], 2), L("wood", [(24, -26), (24, -4)], 1),
            P("door", R(11, -20, 20, -4)), E("lamp", 18, -12, .8),
            P("trim", R(28, -21, 43, -9)), P("glass", R(30, -19, 41, -11)),
            L("trim", [(35.5, -19), (35.5, -11)], 1), L("trim", [(30, -15), (41, -15)], 1)]


def shed():
    return [P("oldwood", [(6, 0), (3, -24), (11, -28), (13, 0)]), P("oldwood2", [(15, 0), (16, -23), (23, -20), (22, 0)]),
            P("oldwood", [(26, 0), (27, -14), (33, -17), (33, 0)]), P("oldroof", [(-1, -21), (21, -35), (30, -31), (8, -17)]),
            L("oldwood2", [(30, -17), (50, -1)], 3), E("rock", 40, -3, 6, 4), E("rock", 47, -2, 4, 3),
            E("moss", 8, -24, 5, 2), E("moss", 24, -32, 4, 1.5), E("moss", 41, -6, 3, 1.5)]


def headframe():
    return [L("rope", [(22, -44), (22, 14)], 1), L("wood", [(4, 0), (15, -56)], 4), L("wood", [(40, 0), (29, -56)], 4),
            L("wood2", [(8, -18), (34, -40)], 2), L("wood2", [(36, -18), (10, -40)], 2),
            E("metal", 22, -47, 7), E("dark", 22, -47, 2), P("wood", R(11, -58, 33, -54)),
            P("roof", [(7, -58), (22, -70), (37, -58)]), L("metal2", [(37, -36), (41, -36)], 1), E("lamp", 41, -32, 2.5, 3)]


def loader(stripe="stripe", driver=None, load=None):
    s = [P("metal", [(73, -31), (92, -27), (95, -6), (78, -3), (71, -14)]), L("metal2", [(73, -31), (92, -27)], 1)]
    s += [P("metal2", [(x, -4), (x + 4, -5), (x + 3, 1)]) for x in (79, 85, 91)]
    if load:
        s += [E(load, 82, -30, 8, 5), E(load, 88, -27, 5, 3)]
    s += [L("veh2", [(54, -31), (79, -19)], 5), L("metal2", [(55, -22), (74, -13)], 2),
          P("veh", R(8, -31, 68, -12)), P(stripe, R(8, -20, 68, -17)), P("veh2", R(8, -14, 68, -12)),
          P("metal2", R(44, -49, 47, -38)), P("veh", R(40, -39, 70, -20))]
    s += [L("veh2", [(x, -35), (x, -26)], 1) for x in (46, 50, 54)]
    s += [E("metal2", 67, -30, 4), E("lamp", 67, -30, 2.6), P("veh", R(14, -52, 38, -28)), P("glass", R(18, -48, 35, -34))]
    if driver:
        s.append((driver, "h", (20, -34)))
    s += [L("veh2", [(18, -33), (35, -33)], 1), P(stripe, R(11, -56, 41, -51)), P("lampo", R(24, -59, 28, -56)),
          P("lamp", R(40, -51, 43, -48)),
          E("tyre", 22, -13, 13), E("veh2", 22, -13, 6), E("metal2", 22, -13, 2),
          E("tyre", 58, -11, 11), E("veh2", 58, -11, 5), E("metal2", 58, -11, 2)]
    return s


def tree(lean=0):
    return [P("wood", [(17, 0), (18 + lean, -30), (22 + lean, -30), (24, 0)]), E("leaf", 20 + lean, -40, 17, 14),
            E("leaf", 10 + lean, -34, 10, 9), E("leaf", 31 + lean, -35, 10, 9), E("leaf", 20 + lean, -52, 12, 10),
            E("leaf2", 15 + lean, -55, 6, 4), E("leaf2", 8 + lean, -37, 5, 3.5), E("leaf2", 27 + lean, -40, 5, 3.5)]


SHAPES = {
    "barn": barn, "house": house, "shed": shed, "headframe": headframe, "loader": loader, "tree": tree,
    "bush": lambda: [E("leaf", 9, -6, 9, 7), E("leaf", 19, -8, 9, 8), E("leaf2", 16, -11, 4, 3)],
    "stump": lambda: [P("wood", [(1, 0), (4, -9), (14, -9), (17, 0)]), E("wood2", 9, -9, 5, 2)],
    "rock": lambda: [P("rock", [(0, 0), (3, -8), (10, -11), (18, -8), (21, 0)]), P("rock2", [(5, -7), (10, -9), (13, -6), (7, -4)])],
    "boulder": lambda: [E("rock", 11, -11, 11), E("rock2", 8, -14, 5, 4), L("dark", [(12, -9), (15, -5), (14, -2)], 1)],
    "pile": lambda: [P("dirtb", R(0, -10, 10, 0)), P("stoneb", R(11, -10, 21, 0)), P("clayb", R(5, -20, 15, -10))],
    "torch": lambda: [L("wood", [(2, 0), (2, -9)], 2), E("flame", 2, -11, 2.5, 3.5)],
    "coin": lambda: [E("gold", 5, -5, 5), E("gold2", 4, -6, 2)],
    "gem": lambda: [P("gem", [(5, 0), (0, -6), (3, -10), (7, -10), (10, -6)]), P("gem2", [(3, -10), (5, -6), (7, -10)])],
    "bone": lambda: [L("bone", [(2, -3), (14, -3)], 3), E("bone", 2, -2, 2.5), E("bone", 2, -5, 2.5), E("bone", 14, -2, 2.5), E("bone", 14, -5, 2.5)],
    "hoard": lambda: [E("gold", 26, -4, 26, 6), E("gold", 22, -9, 15, 6), E("gold2", 18, -11, 8, 2.5), E("gold", 30, -13, 7, 4),
                      P("gem", [(36, -4), (33, -9), (36, -12), (39, -9)]), P("gem2", [(10, -3), (8, -7), (10, -9), (12, -7)])],
    "fence": lambda: [L("oldwood", [(x, 0), (x, -12)], 2) for x in (2, 14, 26)] + [L("oldwood", [(0, -8), (28, -9)], 2)],
    "tuft": lambda: [L("grass2", [(4, 0), (1, -9)], 1), L("grass2", [(5, 0), (5, -12)], 1), L("grass2", [(6, 0), (10, -8)], 1)],
}


# ------------------------------------------------------------------ scenes
def _scene(w, **k):
    d = dict(w=w, cols=w.cols, rows=w.rows, surf=None, ents=[], lights=[], amb=None, labels=[], far=set(), ores={}, hill=None)
    d.update(k)
    return d


def layers(tag):
    w = hp.World(40, 23)
    bands = [(1, "top"), (4, "clay"), (7, "stone"), (11, "ice"), (14, "crys"), (17, "cav"), (21, "strange")]
    w.fill(bands, edge_cols=(0, 39))
    w.dig(36, 1, 37, 18)                      # the shaft, on the dark side: daylight falls down it
    w.dig(5, 2, 12, 3)                        # Jeff's tunnel
    w.dig(16, 5, 21, 6, "water")
    w.dig(5, 8, 15, 9)
    w.dig(18, 7, 18, 9)                       # boulder chute
    w.dig(5, 12, 10, 12)
    w.dig(26, 11, 33, 12)                     # dark side tunnel with one torch
    w.dig(7, 15, 12, 15)
    w.dig(15, 15, 18, 16, "lava")
    w.dig(26, 15, 35, 15)
    w.dig(6, 18, 35, 19)
    w.dig(10, 17, 30, 17)
    far = {(x, y) for y in (17, 18, 19) for x in range(6, 36) if not w.is_solid(x, y)}
    ents = [("torch", 6 * T + 4, 4 * T, {}), ("jeff", 11 * T, 4 * T, dict(dig=True)), ("coin", 14 * T + 2, 3 * T - 2, {}),
            ("bone", 9 * T, 6 * T - 4, {}), ("torch", 8 * T, 10 * T, {}), ("boulder", 18 * T - 3, 9 * T - 6, {}),
            ("gem", 22 * T, 9 * T, {}), ("gem", 13 * T, 14 * T - 3, {}), ("torch", 8 * T, 13 * T, {}),
            ("torch", 31 * T, 13 * T, {}), ("torch", 9 * T, 16 * T, {}), ("hoard", 17 * T, 20 * T, {}),
            ("torch", 8 * T, 20 * T, {}), ("torch", 30 * T, 20 * T, {}), ("gem", 31 * T, 9 * T - 4, {})]
    warm = (1.0, .82, .55)
    lights = [(6, 3, warm), (12, 2, (1, .95, .8)), (8, 9, warm), (8, 12, warm), (31, 12, warm), (9, 15, warm),
              (16, 14, (1, .5, .2)), (17, 14, (1, .5, .2)), (8, 19, warm), (30, 19, warm), (20, 19, (1, .85, .4)),
              (22, 8, (.5, .9, 1)), (31, 8, (.5, .9, 1)), (13, 13, (.75, .5, 1)), (28, 15, (.6, .4, .9)), (33, 15, (.6, .4, .9))]
    ores = {(24, 5): "copper", (25, 5): "copper", (25, 6): "copper", (11, 5): "copper", (22, 8): "gem", (31, 8): "gem",
            (3, 8): "gold", (3, 9): "gold", (2, 9): "gold", (13, 10): "gold", (14, 10): "gold", (29, 9): "gold", (28, 9): "gold",
            (20, 12): "gem", (13, 13): "gem", (3, 15): "gem"}
    labels = [(tag, 1.3, .12)] + [(NAMES[k].upper(), 1.3, y + .15) for y, k in bands]
    labels += [("EDGESTONE", 1.3, 10.1), ("LIT: TORCHES EVERYWHERE", 13, .12), ("UNLIT: ONLY REAL LIGHT", 27, .12)]
    return _scene(w, surf=1, ents=ents, lights=lights, ores=ores, far=far, labels=labels,
                  amb=lambda x: max(0.0, min(.8, (25.5 - x) * .3)))


def hillville(tag, cols=40):
    w = hp.World(cols, 23)
    w.fill([(17, "top"), (21, "clay")])
    w.dig(20, 17, 21, 22)
    w.plot = set(range(0, 31))
    g = 17 * T
    ents = [("fence", -8, g, {}), ("shed", 10, g, {}), ("tree", 58, g, {}), ("house", 98, g, {}), ("barn", 166, g, {}),
            ("pile", 250, g, {}), ("headframe", 314, g, {}), ("chuck", 370, g, {}), ("loader", 396, g, {}),
            ("stump", 500, g, {}), ("tuft", 508, g, {}), ("rock", 524, g, {}), ("bush", 548, g, {}), ("tuft", 574, g, {}),
            ("tree", 566, g, dict(lean=-2)), ("tree", 602, g, dict(lean=2)), ("tuft", 630, g, {}), ("coin", 12 * T, 19 * T + 6, {})]
    return _scene(w, surf=17, ents=ents, hill=400, ores={(27, 19): "copper", (28, 19): "copper", (5, 20): "copper"},
                  labels=[(tag, .3, .2)])


def split_up(tag):
    w = hp.World(20, 23)
    w.fill([(17, "top"), (21, "clay")])
    w.plot = set(range(0, 13))
    g = 17 * T
    ents = [("barn", -44, g, {}), ("pile", 36, g, {}), ("loader", 96, g, dict(stripe="p2", driver="chuck", load="dirtb")),
            ("rock", 212, g, {}), ("tuft", 236, g, {}), ("stump", 246, g, {}), ("tree", 268, g, {}), ("tuft", 300, g, {})]
    return _scene(w, surf=17, ents=ents, hill=150, labels=[(tag, .3, .2)])


def split_down():
    w = hp.World(20, 23)
    w.fill([(0, "top"), (2, "clay"), (6, "stone"), (19, "ice")])
    w.dig(2, 0, 3, 12)
    w.dig(4, 11, 12, 12)
    w.dig(13, 3, 17, 4, "water")
    w.dig(15, 8, 15, 10)
    ents = [("boulder", 15 * T - 3, 10 * T - 4, {}), ("jeff", 11 * T + 2, 13 * T, dict(dig=True, lamp=True)),
            ("gem", 14 * T, 12 * T + 10, {}), ("torch", 5 * T, 13 * T, {}), ("coin", 8 * T, 16 * T, {})]
    lights = [(11, 11, (1, .95, .8)), (12, 11, (1, .95, .8)), (13, 11, (1, .95, .8)), (12, 12, (1, .95, .8)), (13, 12, (1, .95, .8)), (5, 12, (1, .82, .55)), (2, 0, (1, 1, 1)), (3, 0, (1, 1, 1)),
              (14, 12, (.5, .9, 1))]
    ores = {(8, 8): "gold", (9, 8): "gold", (9, 9): "gold", (14, 12): "gem", (6, 15): "gold", (17, 14): "copper", (18, 14): "copper"}
    return _scene(w, ents=ents, lights=lights, ores=ores)


def lightmap(sc):
    """Tile light like the engine will do it: sky and lamps are sources, light spreads to
    neighbours, losing more through solid ground. Returns an RGB image, one pixel per tile."""
    w, cols, rows = sc["w"], sc["cols"], sc["rows"]
    Lm = [[[0.0] * 3 for _ in range(cols)] for _ in range(rows)]
    if sc["surf"] is not None:
        for x in range(cols):
            y = 0
            while y < rows and not w.is_solid(x, y):
                Lm[y][x] = [1.0] * 3
                y += 1
    for x, y, c in sc["lights"]:
        Lm[y][x] = [max(a, b) for a, b in zip(Lm[y][x], c)]
    for _ in range(18):
        for y in range(rows):
            for x in range(cols):
                k = .62 if w.is_solid(x, y) else .9
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < cols and 0 <= ny < rows:
                        for c in range(3):
                            v = Lm[ny][nx][c] * k
                            if v > Lm[y][x][c]:
                                Lm[y][x][c] = v
    im = Image.new("RGB", (cols, rows))
    for y in range(rows):
        for x in range(cols):
            a = sc["amb"](x) if sc["amb"] else 0
            im.putpixel((x, y), tuple(int(255 * min(1, max(a, v))) for v in Lm[y][x]))
    return im


# ------------------------------------------------------------------ sheet helpers
def font(size):
    from PIL import ImageFont
    return ImageFont.load_default(size)


def plate(im, x, y, s, size=20, fg=(250, 244, 230), bg=(22, 18, 28, 215)):
    from PIL import ImageDraw
    d = ImageDraw.Draw(im, "RGBA")
    f = font(size)
    w = d.textlength(s, font=f)
    d.rounded_rectangle([x, y, x + w + 14, y + size + 10], 5, fill=bg)
    d.text((x + 7, y + 3), s, font=f, fill=fg)


def put_labels(im, sc, cell):
    for s, tx, ty in sc["labels"]:
        plate(im, int(tx * cell), int(ty * cell), s, 20)


def card(title, blurb, groups, art):
    """Palette sheet, 1920x1080: named swatch rows with hex values on the left, sprites on the right."""
    from PIL import ImageDraw
    im = Image.new("RGB", (1920, 1080), (26, 22, 30))
    d = ImageDraw.Draw(im)
    d.text((40, 26), title, font=font(44), fill=(250, 244, 230))
    d.text((42, 84), blurb, font=font(20), fill=(190, 184, 176))
    y = 132
    for name, cols in groups:
        d.text((40, y + 14), name, font=font(20), fill=(230, 224, 210))
        for i, c in enumerate(cols):
            x = 250 + i * 104
            d.rounded_rectangle([x, y, x + 96, y + 34], 4, fill=tuple(c))
            d.text((x + 8, y + 37), "#%02x%02x%02x" % tuple(c), font=font(15), fill=(160, 156, 150))
        y += 62
    im.paste(art, (1920 - art.width - 40, 130), art if art.mode == "RGBA" else None)
    return im
