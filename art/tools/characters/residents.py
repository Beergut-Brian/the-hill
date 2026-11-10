# Copied unchanged from openjar-characters, branch feature/the-hill-residents, tools/pixel/residents.py (approved drafts, D46 a). Do not edit here.
"""Pixel sprites for the Hill residents (Pillow only). Flat colours from .scratch/DESIGN.md."""
from PIL import Image
from px import Spr, OUT, rgba, PAPER

W, H = 40, 32
TEAR, SWEAT, BLUSH = "#8FD3F4", "#8FD3F4", "#F7A6C0"
EXPRS = {
    "mole": ["squint", "happy", "sorry", "hopeful", "startled"],
    "foreman": ["stern", "approving", "sorry", "hopeful", "whistle"],
    "caveman": ["delighted", "baffled", "sorry", "hopeful", "amazed"],
    "dragon": ["sleepy", "yawn", "happy", "sorry", "hopeful"],
}


def fin(s):
    """Outline, then make the figure exactly rows 0..31 of the 40 x 32 canvas (asserts height 32)."""
    im = s.done()
    bb = im.getbbox()
    assert bb and bb[3] - bb[1] == H, f"height {bb[3]-bb[1] if bb else None}"
    assert bb[0] >= 0 and bb[2] <= W
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(im.crop((0, bb[1], W, bb[3])), (0, 0))
    return out


def drop(s, x, y):
    s.px(SWEAT, (x, y), (x, y + 1), (x + 1, y + 1)); s.px(SWEAT, (x, y + 2))


# ---------------------------------------------------------------- the Mole
SLATE, BELLY, PINK, NOSE, WOOD, STEEL, DIRT, DIRT2 = (
    "#56607A", "#8792AC", "#F2A0A8", "#E0607A", "#B07A3C", "#B8C4D0", "#8A5A3C", "#6E4528")


def mole_face(s, ex, x0=0):
    for sx in (16, 24):
        x = sx + x0
        if ex in ("squint",):
            s.px(OUT, (x - 1, 5), (x, 5), (x + 1, 5))
        elif ex == "happy":
            s.px(OUT, (x - 1, 6), (x, 5), (x + 1, 6))
        elif ex == "sorry":
            s.px(OUT, (x - 1, 5), (x, 5), (x + 1, 5))
        elif ex == "hopeful":
            s.px(OUT, (x, 5), (x, 6)); s.px("#FFFFFF", (x + 1, 5))
        elif ex == "startled":
            s.r(x - 1, 4, x + 1, 6, "#FFFFFF"); s.px(OUT, (x, 5))
    if ex == "sorry":
        s.px(OUT, (14, 4), (15, 4), (16, 3), (17, 3), (23, 3), (24, 3), (25, 4), (26, 4))
    if ex == "hopeful":
        s.px(OUT, (15, 3), (16, 3), (17, 3), (23, 3), (24, 3), (25, 3))
    if ex == "startled":
        s.px(OUT, (15, 2), (16, 2), (17, 2), (23, 2), (24, 2), (25, 2))
    if ex in ("happy", "sorry", "hopeful"):
        s.px(PINK, (14, 8), (15, 8), (25, 8), (26, 8))
    if ex in ("sorry", "startled"):
        drop(s, 11, 5)
    m = {"squint": [(19, 14), (20, 14), (21, 14)],
         "happy": [(18, 14), (19, 15), (20, 15), (21, 15), (22, 14)],
         "sorry": [(18, 14), (19, 13), (20, 14), (21, 13), (22, 14)],
         "hopeful": [(19, 14), (20, 15), (21, 14)],
         "startled": [(20, 14), (19, 15), (21, 15), (20, 16)]}[ex]
    s.px(OUT, *m)


def mole(view="front", pose="idle", expr="squint"):
    s = Spr(W, H)
    if view == "front":
        if pose == "popup":
            s.e(10, 8, 30, 26, SLATE)
        else:
            s.e(8, 9, 32, 29, SLATE)
        s.e(13, 1, 27, 15, SLATE)
        if pose != "popup":
            s.e(13, 16, 27, 28, BELLY)
            s.r(11, 29, 17, 30, PINK); s.r(23, 29, 29, 30, PINK)
        s.e(18, 7, 22, 12, PINK); s.px(NOSE, (19, 11), (20, 11), (21, 11), (20, 12))
        mole_face(s, expr)
        if pose == "idle":
            for x in (2, 31):
                s.e(x, 17, x + 7, 26, PINK); s.px(NOSE, (x + 2, 24), (x + 3, 24), (x + 5, 24))
        else:
            if pose == "popup":
                s.e(3, 21, 36, 40, DIRT); s.cut(0, 31, 39, 39)
                s.e(3, 20, 12, 27, DIRT); s.e(28, 20, 37, 27, DIRT)
                s.px(DIRT2, (8, 27), (10, 26), (20, 25), (31, 28), (28, 24), (14, 29), (5, 29))
            s.r(30, 10, 31, 27, WOOD); s.p([(28, 9), (33, 9), (34, 3), (32, 1), (29, 1), (27, 3)], STEEL)
            s.r(29, 3, 30, 7, "#FFFFFF")
            for y in (17, 22) if pose == "bouquet" else (19, 23):
                s.e(26, y, 34, y + 5, PINK); s.px(NOSE, (28, y + 4), (30, y + 4), (32, y + 4))
    elif view == "side":
        s.e(8, 9, 30, 29, SLATE); s.e(13, 1, 29, 15, SLATE); s.e(17, 16, 30, 28, BELLY)
        s.e(3, 22, 11, 27, PINK); s.r(13, 29, 19, 30, PINK); s.r(21, 29, 27, 30, PINK)
        s.p([(26, 6), (33, 9), (26, 12)], PINK); s.px(NOSE, (32, 9), (31, 9), (32, 10))
        ex = {"squint": [(24, 5), (25, 5), (26, 5)], "happy": [(23, 6), (24, 5), (25, 6)]}.get(expr, [(24, 5), (25, 5), (26, 5)])
        s.px(OUT, *ex)
        s.e(24, 17, 32, 26, PINK); s.px(NOSE, (27, 24), (29, 24), (31, 24))
    else:
        s.e(8, 9, 32, 29, SLATE); s.e(13, 1, 27, 15, SLATE)
        s.e(18, 24, 22, 29, PINK); s.r(11, 29, 17, 30, PINK); s.r(23, 29, 29, 30, PINK)
        for x in (2, 31):
            s.e(x, 17, x + 7, 26, PINK)
    return fin(s)


# ---------------------------------------------------------------- the Gnome Foreman
TEAL, HARD, BEARD, VEST, CREAM, SKIN, FNOSE, BOOT, YEL = (
    "#1E9AA0", "#F4F1E6", "#EDE6D6", "#F7932F", "#F4F1E6", "#E8B48C", "#E59A86", "#4A3B3B", "#FFD23F")


def foreman(view="front", pose="idle", expr=None):
    expr = expr or ("whistle" if pose == "whistle" else "stern")
    s = Spr(W, H)
    s.p([(19, 1), (21, 1), (27, 15), (13, 15)], TEAL)
    s.r(14, 15, 26, 15, TEAL)
    s.r(14, 16, 26, 19, SKIN)
    s.r(15, 23, 25, 28, VEST); s.r(14, 24, 26, 28, VEST); s.r(16, 24, 16, 28, CREAM); s.r(24, 24, 24, 28, CREAM)
    s.r(14, 29, 19, 30, BOOT); s.r(21, 29, 26, 30, BOOT)
    if view == "back":
        s.r(14, 16, 26, 19, BEARD); s.p([(13, 19), (27, 19), (25, 25), (15, 25)], BEARD)
    else:
        s.p([(13, 19), (27, 19), (24, 25), (20, 27), (16, 25)], BEARD)
    if view == "front":
        s.e(18, 17, 22, 20, FNOSE)
        e = expr
        for sx, d in ((16, 1), (24, -1)):
            if e == "approving":
                s.px(OUT, (sx - 1, 18), (sx, 17), (sx + 1, 18))
            elif e == "hopeful":
                s.px(OUT, (sx, 17), (sx, 18), (sx + d, 17), (sx + d, 18)); s.px("#FFFFFF", (sx, 17))
            else:
                s.px(OUT, (sx, 17), (sx, 18))
            by = 16
            if e == "stern":
                s.px(BEARD, (sx - 1, by), (sx, by), (sx + 1, by), (sx - d, by + 1) if False else (sx + d * 2, by + 1))
            elif e == "sorry":
                s.px(BEARD, (sx - 1, by), (sx, by), (sx + 1, by), (sx - d * 2, by + 1))
            else:
                s.px(BEARD, (sx - 1, by), (sx, by), (sx + 1, by))
        if e in ("approving", "sorry", "hopeful"):
            s.px(FNOSE, (14, 19), (26, 19))
        if e == "sorry":
            drop(s, 29, 15)
        if e == "whistle" or pose == "whistle":
            s.px(OUT, (19, 22), (21, 22), (20, 21), (20, 23)); s.px(YEL, (20, 22), (22, 22), (23, 22))
        else:
            s.px(YEL, (25, 25), (26, 25), (25, 26)); s.px("#C98A1A", (24, 24), (23, 23), (22, 22), (21, 22))
    if pose == "hat_in_hands":
        s.e(15, 20, 25, 27, OUT); s.e(16, 21, 24, 26, HARD); s.r(13, 25, 27, 26, OUT); s.r(14, 25, 26, 25, HARD); s.px(OUT, (18, 23), (19, 23))
        s.r(14, 24, 16, 26, SKIN); s.r(24, 24, 26, 26, SKIN)
    else:
        s.e(18, 1, 22, 4, HARD); s.r(17, 4, 23, 4, HARD); s.r(18, 3, 22, 4, HARD)
        if pose == "whistle":
            s.r(3, 21, 10, 28, WOOD); s.r(4, 22, 9, 27, PAPER); s.r(10, 25, 12, 26, SKIN)
            s.p([(26, 23), (28, 22), (33, 16), (31, 15)], VEST); s.r(32, 13, 35, 16, SKIN)
            s.px(YEL, (10, 18), (10, 19), (10, 20), (6, 17), (6, 18), (6, 19), (7, 14), (8, 14))
            s.px(YEL, (30, 9), (31, 9), (32, 9))
        else:
            s.r(4, 19, 12, 28, WOOD); s.r(5, 20, 11, 27, PAPER); s.r(7, 18, 9, 19, STEEL)
            s.px(WOOD, (6, 22), (7, 22), (8, 22), (9, 22), (10, 22), (6, 24), (7, 24), (8, 24), (9, 25), (7, 26))
            s.r(12, 24, 14, 26, SKIN)
            s.r(27, 24, 29, 28, VEST); s.r(28, 29, 29, 29, SKIN)
        if pose == "whistle":
            pass
    if pose == "hat_in_hands":
        s.r(11, 24, 14, 28, VEST); s.r(26, 24, 29, 28, VEST)
    if view == "side":
        s.e(24, 17, 29, 21, FNOSE); s.px(OUT, (22, 17), (22, 18)); s.px(BEARD, (21, 16), (22, 16), (23, 16))
    return fin(s)


# ---------------------------------------------------------------- the Caveman
HAIR, CSKIN, TUN, SPOT, ICE, CLOTH, STR = "#7A4A2A", "#D99A6C", "#D9A441", "#7C4E24", "#BFE6F5", "#F3EAD2", "#1E9AA0"


def cave_face(s, ex):
    for sx, d in ((16, 1), (24, -1)):
        if ex in ("delighted", "hopeful"):
            s.r(sx - 1, 12, sx + 1, 14, "#FFFFFF"); s.px(OUT, (sx, 13), (sx, 14)); s.px("#FFFFFF", (sx + d, 12) if False else (sx - 1, 12))
        elif ex == "amazed":
            s.r(sx - 1, 11, sx + 1, 14, "#FFFFFF"); s.px(OUT, (sx, 12), (sx, 13))
        elif ex == "baffled":
            big = sx == 16
            s.r(sx - 1, 12 if big else 13, sx + 1, 14, "#FFFFFF"); s.px(OUT, (sx, 13), (sx, 14))
        elif ex == "sorry":
            s.px(OUT, (sx - 1, 13), (sx, 13), (sx + 1, 13), (sx, 14))
    s.px(HAIR, *[(x, 10) for x in (14, 15, 16, 17, 23, 24, 25, 26)])
    if ex in ("delighted", "amazed", "hopeful"):
        s.px(HAIR, *[(x, 11) for x in (14, 15, 25, 26)])
    if ex == "baffled":
        s.px(HAIR, (14, 11), (15, 11), (16, 11), (25, 9), (24, 9), (23, 9), (26, 10), (25, 10), (24, 10), (23, 11))
    if ex == "sorry":
        s.px(HAIR, (14, 11), (15, 11), (16, 10), (17, 10), (26, 11), (25, 11), (24, 10), (23, 10))
        s.px(BLUSH, (14, 15), (15, 15), (25, 15), (26, 15)); drop(s, 29, 9)
    s.px("#C57F52", (20, 14), (20, 15))
    if ex == "delighted":
        s.r(16, 17, 24, 19, OUT); s.r(17, 17, 23, 17, "#FFFDF4")
    elif ex == "amazed":
        s.r(18, 17, 22, 20, OUT)
    elif ex == "baffled":
        s.px(OUT, (21, 18), (22, 18), (23, 18), (20, 17), (19, 17))
    elif ex == "sorry":
        s.px(OUT, (18, 18), (19, 17), (20, 18), (21, 17), (22, 18))
    elif ex == "hopeful":
        s.px(OUT, (18, 17), (19, 18), (20, 18), (21, 18), (22, 17)); s.px("#FFD86B", (12, 9), (11, 9), (12, 8), (12, 10))
    if ex in ("delighted",):
        s.px(BLUSH, (14, 16), (15, 16), (25, 16), (26, 16))


def caveman(view="front", pose="idle", expr="delighted"):
    s = Spr(W, H)
    s.e(5, 4, 35, 25, HAIR)
    s.r(6, 22, 34, 28, CSKIN) if False else s.e(5, 21, 35, 30, CSKIN)
    s.cut(0, 29, 39, 31)
    s.p([(13, 22), (34, 22), (34, 28), (31, 27), (28, 28), (25, 27), (22, 28), (19, 27), (16, 28), (13, 27)], TUN)
    s.px(SPOT, (24, 24), (30, 25), (19, 25), (16, 24), (28, 22), (33, 26))
    s.e(7, 3, 33, 24, HAIR) if False else None
    s.e(6, 4, 34, 24, HAIR)
    s.r(8, 29, 17, 30, CSKIN); s.r(23, 29, 32, 30, CSKIN); s.r(13, 28, 16, 28, CSKIN); s.r(24, 28, 27, 28, CSKIN)
    s.e(15, 3, 25, 9, HAIR)
    s.r(17, 1, 23, 6, ICE); s.px("#FFFFFF", (18, 2), (19, 2), (18, 3))
    if view != "back":
        s.e(12, 8, 28, 20, CSKIN)
        cave_face(s, expr) if view == "front" else None
    if view == "side":
        s.e(18, 8, 32, 20, CSKIN); s.px(OUT, (27, 13), (27, 14)); s.px(HAIR, (26, 10), (27, 10), (28, 10))
        s.px(OUT, (28, 17), (29, 17), (30, 17))
    if view == "front" and pose in ("idle", "polish", "wave"):
        pass
    if pose == "idle" or view != "front":
        s.r(2, 22, 7, 27, CSKIN)
        s.r(30, 20, 34, 25, CSKIN)
        s.r(34, 9, 35, 21, WOOD); s.e(31, 3, 38, 12, CLOTH); s.r(31, 12, 38, 13, STR); s.px(CLOTH, (34, 14))
    elif pose == "polish":
        s.r(2, 22, 7, 27, CSKIN)
        s.p([(15, 28), (17, 23), (23, 23), (25, 28), (20, 30)], "#4FD6E0")
        s.r(18, 24, 19, 25, "#FFFFFF"); s.e(20, 19, 28, 26, CLOTH); s.r(26, 25, 33, 26, WOOD)
        s.r(26, 19, 28, 22, STR); s.r(31, 24, 34, 28, CSKIN)
        s.px("#FFD86B", (13, 22), (12, 22), (14, 22), (13, 21), (13, 23), (29, 28), (30, 28), (29, 27))
    else:
        s.r(2, 15, 7, 21, CLOTH) if False else None
        s.r(31, 8, 35, 21, CSKIN); s.r(30, 4, 36, 9, CSKIN); s.px(OUT, (32, 4), (34, 4))
        s.r(4, 22, 6, 27, CSKIN); s.r(4, 14, 5, 24, WOOD); s.e(2, 9, 8, 16, CLOTH); s.r(2, 16, 8, 16, STR)
    return fin(s)


# ---------------------------------------------------------------- Jeff and Chuck (pixel form)
JYEL, JOR, GRN, JEANS, COMB = "#FFD84D", "#F7932F", "#3CC24A", "#3B5BA5", "#D63384"
RED = "#E4393C"


def jeff(view="front"):
    s = Spr(W, H)
    s.r(19, 1, 21, 4, COMB); s.px(COMB, (18, 3), (22, 3))
    s.e(12, 3, 28, 20, JYEL)
    s.e(12, 2, 28, 10, GRN); s.r(12, 6, 28, 8, GRN); s.r(10, 9, 30, 10, GRN)
    s.r(19, 1, 21, 5, COMB)
    s.e(10, 14, 30, 28, JYEL)
    s.p([(11, 25), (29, 25), (31, 30), (9, 30)], JEANS); s.r(11, 25, 29, 25, JEANS)
    s.cut(19, 27, 21, 30)
    s.r(9, 29, 18, 30, JOR); s.r(22, 29, 31, 30, JOR)
    s.e(4, 15, 11, 25, JYEL); s.e(29, 15, 36, 25, JYEL); s.px(GRN, (5, 24), (6, 24), (7, 24), (33, 24), (34, 24), (35, 24), (4, 23), (36, 23))
    s.p([(18, 13), (22, 13), (20, 17)], JOR)
    s.px(OUT, (16, 12), (24, 12), (16, 11), (24, 11))
    return fin(s)


def chuck(view="front"):
    s = Spr(W, H)
    s.e(12, 8, 28, 21, "#E8B48C")
    s.e(12, 1, 28, 12, "#2B2B33"); s.r(12, 7, 28, 10, "#2B2B33")
    s.r(10, 10, 30, 11, RED); s.r(19, 1, 21, 7, RED)
    s.px("#FFD84D", (18, 5), (19, 5), (20, 5), (19, 6), (21, 6), (18, 7))
    s.px(OUT, (16, 14), (24, 14), (16, 13), (24, 13), (18, 18), (19, 19), (20, 19), (21, 19), (22, 18))
    s.r(10, 20, 30, 26, "#1E1E26"); s.px(RED, (15, 22), (16, 21), (17, 21), (18, 22), (17, 23), (16, 23))
    s.r(5, 21, 9, 26, "#1E1E26"); s.r(31, 21, 35, 26, "#1E1E26"); s.r(5, 27, 8, 27, "#E8B48C"); s.r(32, 27, 35, 27, "#E8B48C")
    s.r(12, 27, 19, 28, JEANS); s.r(21, 27, 28, 28, JEANS); s.r(12, 29, 19, 30, "#8A5A2B"); s.r(21, 29, 28, 30, "#8A5A2B")
    s.r(10, 26, 30, 27, JEANS)
    return fin(s)


# ---------------------------------------------------------------- the Dragon
LIL, SHADE, DCREAM, PEACH, CHEEK, SMOKE = "#A88BE0", "#8C6FC8", "#FFF0C9", "#FFB37A", "#F7A6C0", "#C9C4D4"
STRIPE = "#F0DAA6"


def _ring(s, x0, y0, x1, y1, w, c):
    s.e(x0, y0, x1, y1, c)
    s.cut_e = None
    s.d.ellipse((x0 + w, y0 + w, x1 - w, y1 - w), fill=(0, 0, 0, 0))


def _tail(s, pts, r, c):
    for x, y in pts:
        s.e(x - r, y - r, x + r, y + r, c)


def _dface(s, ex, cx, ey, dx=19):
    """Face centred on cx; eyes at y=ey."""
    for sx, d in ((cx - dx, 1), (cx + dx, -1)):
        if ex == "sleepy" or ex == "sorry":
            s.e(sx - 7, ey - 5, sx + 7, ey + 5, OUT); s.r(sx - 8, ey - 6, sx + 8, ey - 1, LIL)
            s.px("#FFFFFF", (sx - 3, ey + 1), (sx - 2, ey + 1))
            s.r(sx - 7, ey - 2, sx + 7, ey - 1, SHADE)
        elif ex == "hopeful":
            s.e(sx - 6, ey - 6, sx + 6, ey + 6, OUT); s.r(sx - 3, ey - 4, sx - 1, ey - 2, "#FFFFFF"); s.px("#FFFFFF", (sx + 2, ey + 2))
        elif ex in ("yawn",):
            s.arc((sx - 7, ey - 4, sx + 7, ey + 6), 200, 340, OUT); s.arc((sx - 7, ey - 5, sx + 7, ey + 5), 200, 340, OUT)
        elif ex == "happy":
            s.arc((sx - 7, ey - 2, sx + 7, ey + 10), 200, 340, OUT); s.arc((sx - 7, ey - 3, sx + 7, ey + 9), 200, 340, OUT)
    if ex in ("sorry", "hopeful"):
        for sx, d in ((cx - dx, 1), (cx + dx, -1)):
            for i in range(9):
                s.px(SHADE, (sx - 8 + i if d == 1 else sx - 8 + i, ey - 11 + (i // 3 if ex == "sorry" else 0) * (1 if d == 1 else 1) if False else ey - 12 + (-(i // 3) if (ex == "sorry") == (d == 1) else (i // 3)) + (2 if ex == "sorry" else 0)))
    s.e(cx - 12, ey + 7, cx - 2, ey + 14, CHEEK) if False else None
    s.e(cx - dx - 12, ey + 6, cx - dx + 4, ey + 17, CHEEK); s.e(cx + dx - 4, ey + 6, cx + dx + 12, ey + 17, CHEEK)
    s.r(cx - 4, ey + 8, cx - 3, ey + 9, OUT); s.r(cx + 3, ey + 8, cx + 4, ey + 9, OUT)
    my = ey + 14
    if ex == "yawn":
        s.e(cx - 12, my - 6, cx + 12, my + 20, OUT); s.e(cx - 8, my + 8, cx + 8, my + 19, CHEEK)
    elif ex == "happy":
        s.arc((cx - 9, my - 8, cx + 9, my + 4), 20, 160, OUT); s.arc((cx - 9, my - 9, cx + 9, my + 3), 20, 160, OUT)
    elif ex == "sorry":
        s.arc((cx - 7, my, cx + 7, my + 8), 200, 340, OUT); s.arc((cx - 7, my - 1, cx + 7, my + 7), 200, 340, OUT)
    elif ex == "hopeful":
        s.arc((cx - 6, my - 6, cx + 6, my + 2), 20, 160, OUT)
    else:
        s.arc((cx - 5, my - 5, cx + 5, my + 1), 20, 160, OUT)
    if ex == "sorry":
        drop(s, cx + dx + 14, ey - 8); s.px(SWEAT, (cx + dx + 14, ey - 9), (cx + dx + 14, ey - 10))


def dragon(pose="sit", expr="sleepy"):
    if pose == "asleep":
        s = Spr(160, 72)
        _tail(s, [(146, 52), (140, 62), (125, 64), (108, 64), (92, 62), (84, 58)], 7, LIL)
        s.e(14, 12, 150, 70, SHADE); s.e(12, 10, 146, 66, LIL)
        s.e(60, 30, 125, 66, DCREAM)
        for x in (72, 86, 100, 114):
            s.arc((x, 32, x + 28, 66), 190, 250, STRIPE)
        for x in (50, 72, 94, 116):
            s.e(x, 3, x + 14, 15, PEACH)
        s.e(110, 12, 140, 28, PEACH)
        s.e(4, 24, 70, 70, LIL); s.e(7, 20, 22, 36, DCREAM); s.e(34, 20, 49, 36, DCREAM)
        s.e(6, 40, 20, 54, CHEEK); s.e(50, 40, 64, 54, CHEEK)
        for sx in (25, 49):
            s.arc((sx - 9, 36, sx + 9, 52), 20, 160, OUT); s.arc((sx - 9, 37, sx + 9, 53), 20, 160, OUT)
        s.arc((29, 50, 41, 60), 20, 160, OUT); s.px(OUT, (34, 47), (36, 47))
        s.e(76, 52, 90, 66, "#4FD6E0"); s.r(79, 54, 81, 56, "#FFFFFF")
        _tail(s, [(78, 64), (70, 62)], 0, LIL); s.e(60, 54, 76, 68, PEACH)
        _ring(s, 6, 1, 30, 15, 5, SMOKE); _ring(s, 34, 4, 48, 12, 3, SMOKE)
        im = s.done()
        out = Image.new("RGBA", (160, 72), (0, 0, 0, 0)); out.paste(im, (0, 0)); return out
    s = Spr(128, 112)
    ex = "yawn" if pose == "yawn" else expr
    # tail curling round to the front
    s.e(26, 44, 108, 110, SHADE)
    s.e(20, 40, 102, 106, LIL)
    for x, y in ((86, 30), (95, 44), (101, 58), (104, 72)):
        s.e(x - 5, y - 5, x + 5, y + 5, PEACH)
    s.e(18, 66, 38, 90, PEACH); s.e(94, 66, 112, 88, PEACH)
    s.e(41, 62, 85, 108, DCREAM)
    for y in (70, 80, 90, 98):
        s.arc((46, y - 8, 80, y + 8), 20, 160, STRIPE)
    s.e(18, 76, 40, 100, LIL); s.e(88, 76, 110, 100, LIL)
    s.e(26, 94, 58, 110, LIL); s.e(70, 94, 102, 110, LIL)
    for x in (34, 44):
        s.e(x, 99, x + 7, 106, DCREAM)
    _tail(s, [(108, 100), (116, 94), (118, 82), (112, 72), (100, 74)], 0, LIL)
    s.e(86, 80, 120, 108, LIL); s.e(74, 98, 124, 110, LIL)
    s.e(100, 56, 114, 70, PEACH)
    s.e(22, 3, 106, 66, LIL)
    s.e(28, 0, 42, 14, DCREAM); s.e(86, 0, 100, 14, DCREAM)
    s.e(20, 2, 108, 66, LIL)
    s.r(32, 3, 38, 8, DCREAM) if False else None
    s.e(50, 34, 78, 60, "#B79BEA")
    _dface(s, ex, 64, 30)
    im = s.done()
    out = Image.new("RGBA", (128, 112), (0, 0, 0, 0)); out.paste(im, (0, 0)); return out


# ---------------------------------------------------------------- heads
HEAD_BOX = {"mole": (9, 0, 31, 17), "foreman": (12, 0, 30, 23), "caveman": (5, 0, 31, 22),
            "jeff": (8, 0, 32, 22), "chuck": (8, 0, 32, 22), "dragon": (14, 0, 114, 72)}


def head(name, expr=None):
    if name == "dragon":
        im = dragon("sit", expr or "sleepy")
    elif name in ("jeff", "chuck"):
        im = {"jeff": jeff, "chuck": chuck}[name]()
    else:
        im = {"mole": mole, "foreman": foreman, "caveman": caveman}[name]("front", "idle", expr or EXPRS[name][0])
    return im.crop(HEAD_BOX[name])
