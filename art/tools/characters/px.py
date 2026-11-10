# Copied unchanged from openjar-characters, branch feature/the-hill-residents, tools/pixel/px.py (approved drafts, D46 a). Do not edit here.
"""Tiny pixel-art helpers (Pillow only). Sprites are drawn at native size from flat shapes,
then given a 1 px outline, then scaled up by an integer with nearest-neighbour."""
from PIL import Image, ImageDraw, ImageFont

OUT = "#2A1E2C"          # the library's dark (same as the Jarling eye colour)
PAPER = "#FFFDF4"


def rgba(c, a=255):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


class Spr:
    def __init__(s, w, h):
        s.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        s.d = ImageDraw.Draw(s.im)

    def e(s, x0, y0, x1, y1, c): s.d.ellipse((x0, y0, x1, y1), fill=rgba(c))
    def r(s, x0, y0, x1, y1, c): s.d.rectangle((x0, y0, x1, y1), fill=rgba(c))
    def p(s, pts, c): s.d.polygon(pts, fill=rgba(c))
    def l(s, pts, c): s.d.line(pts, fill=rgba(c), width=1)
    def arc(s, box, a0, a1, c): s.d.arc(box, a0, a1, fill=rgba(c), width=1)
    def cut(s, x0, y0, x1, y1): s.d.rectangle((x0, y0, x1, y1), fill=(0, 0, 0, 0))

    def px(s, c, *pts):
        for x, y in pts:
            if 0 <= x < s.im.width and 0 <= y < s.im.height:
                s.im.putpixel((x, y), rgba(c))

    def done(s, ol=OUT):
        return outline(s.im, ol)


def outline(im, col=OUT):
    """Every transparent pixel that touches the sprite (4-neighbour) becomes outline."""
    src, out = im.load(), im.copy()
    dst, c = out.load(), rgba(col)
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    dst[x, y] = c
                    break
    return out


def up(im, k): return im.resize((im.width * k, im.height * k), Image.NEAREST)
def mirror(im): return im.transpose(Image.FLIP_LEFT_RIGHT)


def silhouette(im, col=OUT):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", im.size, rgba(col)), (0, 0), im.split()[3])
    return out


def font(size): return ImageFont.load_default(size=size)


def bubble(w, h, tail=0.2, k=4):
    """Speech bubble, w x h in art pixels plus a 5 px tail, scaled by k. No text ever goes in it."""
    s = Spr(w + 2, h + 8)
    s.d.rounded_rectangle((1, 1, w, h), radius=5, fill=rgba(PAPER))
    tx = int(w * tail)
    s.p([(tx, h), (tx + 7, h), (tx - 2, h + 6)], PAPER)
    return up(s.done(), k)


# ---- pictogram icons, 24 x 24 art pixels -------------------------------------------------
DIRT, CLAY, STONE, WOOD, STEEL = "#8A5A3C", "#D9823B", "#7F8FA6", "#B07A3C", "#B8C4D0"
LIT, GEM, WATER, SLATE_ROOF = "#FFD86B", "#4FD6E0", "#5AA9E6", "#5B6378"


def _ic(): return Spr(24, 24)


def ic_arrow():
    s = _ic(); s.r(3, 11, 15, 13, OUT); s.p([(14, 6), (21, 12), (14, 18)], OUT); return s.im


def ic_plus():
    s = _ic(); s.r(10, 5, 13, 18, OUT); s.r(5, 10, 18, 13, OUT); return s.im


def ic_blocks():
    s = _ic()
    for x, y, c in ((2, 13, DIRT), (12, 13, STONE), (7, 4, CLAY)):
        s.r(x, y, x + 8, y + 8, c); s.r(x + 1, y + 1, x + 3, y + 2, "#FFFFFF")
    return s.done()


def ic_shovel():
    s = _ic(); s.r(11, 3, 12, 14, WOOD); s.r(9, 2, 14, 3, WOOD)
    s.p([(8, 14), (15, 14), (15, 19), (12, 22), (11, 22), (8, 19)], STEEL)
    s.r(9, 15, 10, 18, "#FFFFFF"); return s.done()


def ic_wall():
    """Gnome hats peeking over a bricked-up wall."""
    s = _ic()
    for x in (4, 10, 16):
        s.p([(x, 9), (x + 2, 3), (x + 3, 3), (x + 5, 9)], "#1E9AA0")
    s.r(2, 9, 21, 21, STONE)
    for y in (12, 16, 20):
        s.r(2, y, 21, y, "#56627A")
    for x, y in ((7, 9), (15, 9), (11, 13), (19, 13), (5, 17), (14, 17)):
        s.r(x, y, x, y + 2, "#56627A")
    return s.done()


def ic_ice():
    """Somebody is in that ice cube."""
    s = _ic(); s.r(4, 3, 19, 21, "#BFE6F5")
    s.e(8, 6, 15, 13, "#7A4A2A"); s.r(9, 13, 14, 19, "#D9A441"); s.r(15, 9, 17, 11, "#D99A6C")
    s.l([(5, 8), (8, 5)], "#FFFFFF"); s.l([(5, 12), (10, 4)], "#FFFFFF"); return s.done()


def ic_snore():
    """A hill, shaken by a snore; smoke rings float out of the top."""
    s = _ic(); s.p([(2, 22), (8, 12), (15, 12), (21, 22)], "#C9A66B")
    s.l([(11, 13), (10, 16), (12, 18), (11, 21)], OUT)
    for box in ((9, 6, 13, 9), (13, 1, 19, 5)):
        s.arc(box, 0, 360, "#8D8796")
    s.l([(1, 14), (3, 12)], OUT); s.l([(22, 14), (20, 12)], OUT); s.l([(0, 18), (2, 17)], OUT)
    s.l([(23, 18), (21, 17)], OUT); return s.im


def _gem(s, x, y):
    s.p([(x, y + 3), (x + 3, y), (x + 8, y), (x + 11, y + 3), (x + 6, y + 10), (x + 5, y + 10)], GEM)
    s.l([(x + 3, y + 1), (x + 5, y + 3)], "#FFFFFF")


def _spark(s, x, y, c=LIT):
    s.px(c, (x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))


def ic_gift(kind):
    s = _ic()
    if kind == "mole":            # a found treasure, glowing in the dirt
        s.e(2, 3, 21, 22, LIT); s.e(5, 6, 18, 19, "#FFF1B8"); _gem(s, 6, 8)
    elif kind == "foreman":       # blocks dug overnight
        s.e(13, 1, 21, 9, LIT); s.e(11, 0, 18, 7, PAPER)      # moon
        for x, y, c in ((2, 15, DIRT), (9, 15, STONE), (16, 15, CLAY), (6, 9, STONE)):
            s.r(x, y, x + 6, y + 6, c)
    elif kind == "caveman":       # a treasure on display, polished
        s.r(7, 16, 16, 21, "#EDE6D6"); s.r(5, 14, 18, 15, "#EDE6D6"); _gem(s, 6, 3)
        im = s.done(); s.im = im; _spark(s, 3, 4); _spark(s, 20, 7); _spark(s, 19, 1); return s.im
    else:                         # warmth
        s.e(3, 8, 12, 16, "#FFB37A"); s.e(11, 8, 20, 16, "#FFB37A")
        s.p([(3, 13), (20, 13), (12, 22), (11, 22)], "#FFB37A")
        im = s.done(); s.im = im
        for x in (6, 11, 16):
            s.l([(x, 6), (x + 1, 4), (x, 2), (x + 1, 0)], "#F7932F")
        return s.im
    return s.done()


def ic_home(kind, fixed):
    """The four ruins (fixed=False) and what they become (fixed=True, with a light on)."""
    s = _ic(); win = LIT if fixed else OUT
    if kind == "mole":            # Old Shed -> Lost & Found
        s.r(5, 12, 18, 21, WOOD)
        s.p([(3, 12), (11, 5), (12, 5), (20, 12)] if fixed else [(3, 13), (8, 9), (17, 12), (20, 14)], SLATE_ROOF)
        s.r(7, 15, 10, 21, "#6E4A26"); s.r(13, 14, 16, 17, win)
        if not fixed:
            s.cut(15, 18, 18, 21); s.l([(12, 12), (13, 21)], "#6E4A26")
    elif kind == "foreman":       # Crooked Watchtower -> Gnome Village
        if fixed:
            s.r(9, 7, 14, 21, STONE); s.p([(7, 7), (11, 1), (12, 1), (16, 7)], "#1E9AA0")
            for x in (2, 17):
                s.r(x, 16, x + 4, 21, "#EDE6D6"); s.p([(x - 1, 16), (x + 2, 12), (x + 5, 16)], "#F7932F")
                s.r(x + 2, 18, x + 3, 19, LIT)
        else:
            s.p([(8, 21), (11, 8), (17, 9), (14, 21)], STONE); s.p([(9, 8), (15, 2), (19, 9)], "#1E9AA0")
        s.r(11, 11, 12, 13, win)
    elif kind == "caveman":       # Flooded Cabin -> The Museum
        s.r(4, 11, 19, 21, "#A8703A"); s.p([(2, 11), (11, 4), (12, 4), (21, 11)], SLATE_ROOF)
        for y in (14, 17, 20):
            s.r(4, y, 19, y, "#7C4E24")
        s.r(13, 13, 16, 16, win); s.r(7, 15, 10, 21, "#6E4A26")
        if fixed:
            s.p([(10, 9), (11, 7), (12, 7), (13, 9), (12, 11), (11, 11)], GEM)
        else:
            s.r(0, 16, 23, 22, WATER); s.px("#FFFFFF", (2, 16), (3, 16), (9, 16), (10, 16), (17, 16), (18, 16))
    else:                         # Ruined Keep -> Dragon Perch
        s.r(5, 9, 18, 21, STONE); s.r(10, 15, 13, 21, "#56627A"); s.r(7, 11, 8, 13, win); s.r(15, 11, 16, 13, win)
        if fixed:
            for x in (5, 9, 13, 17):
                s.r(x, 6, x + 1, 8, STONE)
            s.e(4, 0, 19, 7, "#A88BE0"); s.e(2, 1, 8, 6, "#A88BE0"); s.px(OUT, (4, 4), (5, 4))  # she is home
        else:
            s.p([(5, 9), (5, 5), (8, 8), (11, 6), (13, 9)], STONE); s.l([(15, 9), (14, 13), (16, 16)], OUT)
    return s.done()
