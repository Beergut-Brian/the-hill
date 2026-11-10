#!/usr/bin/env python3
"""The Hill: the four restored ruins, drawn in code (no generative model).

    python3 art/tools/make_restored_art.py      # writes 8 PNGs to assets/sprites/buildings/, merges manifest.json

Each ruin on the hill (old_shed, crooked_watchtower, flooded_cabin, ruined_keep) is restored in-game into
a new building. Same look as make_game_art.py (palette A "Sandbox", outline #3a2a44, its helpers), same
footprint as the ruin it replaces. Each building also gets a `_lit` night-window layer like barn_lit.
Deterministic: every random draw is seeded. Only touches the files and manifest keys listed in BUILDINGS.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import make_game_art as g                 # noqa: E402  helpers only; its main() is guarded
import hillpix as hp                      # noqa: E402

A, R, C, P, CLEAR, WHITE, LAMP, LIT_WIN = g.A, g.R, g.C, g.P, g.CLEAR, g.WHITE, g.LAMP, g.LIT_WIN
win, finish, stones, moss, planks = g.win, g.finish, g.stones, g.moss, g.planks
DARK = P["back"]["top"][1]
FLAME = hp.hx("#fff2b0")


def canvases(W, H):
    im, lit = Image.new("RGBA", (W, H), CLEAR), Image.new("RGBA", (W, H), CLEAR)
    return im, lit, ImageDraw.Draw(im), ImageDraw.Draw(lit)


def round_win(d, ld, box, frame_c):
    """Tiny round window (gnome houses, towers)."""
    x0, y0, x1, y1 = box
    d.ellipse(box, fill=A(frame_c))
    d.ellipse([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=A(R["glass"][2]))
    d.point((x0 + 2, y0 + 2), fill=A(WHITE))
    ld.ellipse([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=A(LIT_WIN))


def plank_door(d, box, wd, arch=False):
    """Closed wooden door with a frame, planks and a gold knob. Returns its bottom-centre."""
    x0, y0, x1, y1 = box
    if arch:
        r = (x1 - x0) // 2
        d.pieslice([x0, y0, x1, y0 + 2 * r], 180, 360, fill=A(wd[1]))
        d.rectangle([x0, y0 + r, x1, y1], fill=A(wd[1]))
        d.pieslice([x0 + 2, y0 + 2, x1 - 2, y0 + 2 * r - 2], 180, 360, fill=A(wd[2]))
        d.rectangle([x0 + 2, y0 + r, x1 - 2, y1], fill=A(wd[2]))
        top = y0 + 3
    else:
        d.rectangle(box, fill=A(wd[1]))
        d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1], fill=A(wd[2]))
        top = y0 + 2
    for x in range(x0 + 5, x1 - 2, 4):
        d.line([x, top + (2 if arch else 0), x, y1], fill=A(wd[1]))
    d.line([x0 + 2, top + (4 if arch else 0), x0 + 2, y1], fill=A(wd[3]))
    ky = (y0 + y1) // 2 + 3
    d.rectangle([x1 - 4, ky, x1 - 3, ky + 1], fill=A(R["gold"][2]))
    return [(x0 + x1 + 1) // 2, y1]


# =============================================================================== Lost and Found
def lost_and_found():
    W = H = 96
    im, lit, d, ld = canvases(W, H)
    wd, rf, cr, k, mt, gd = R["wood"], R["roof"], R["wall"], R["weath"], R["metal"], R["gold"]
    # the shed, stood up straight: same 14..70 plank body, now painted warm wood
    planks(im, (12, 40, 72, 94), wd, step=6, seed=11)
    d = ImageDraw.Draw(im)
    for x0 in (20, 66):                                              # the old gaps, patched in grey boards
        d.rectangle([x0, 76, x0 + 4, 94], fill=A(k[2]))
        d.line([x0, 76, x0 + 4, 76], fill=A(k[3]))
        d.line([x0 + 4, 77, x0 + 4, 94], fill=A(k[1]))
    # a tidy gable roof in the shed's blue
    d.polygon([(4, 44), (42, 14), (80, 44)], fill=A(rf[2]))
    for y in range(22, 44, 5):
        half = (y - 14) * 38 // 30
        d.line([42 - half + 2, y, 42 + half - 2, y], fill=A(rf[1]))
    d.line([(5, 43), (42, 14)], fill=A(rf[3]))
    d.line([(43, 15), (79, 43)], fill=A(rf[0]))
    d.rectangle([4, 43, 80, 45], fill=A(rf[0]))
    # round attic vent
    d.ellipse([37, 26, 47, 36], fill=A(wd[1]))
    d.ellipse([39, 28, 45, 34], fill=A(R["glass"][2]))
    ld.ellipse([39, 28, 45, 34], fill=A(LIT_WIN))
    # main door (where the ruin's gap was)
    door = plank_door(d, [28, 60, 44, 94], wd)
    d.rectangle([31, 64, 41, 69], fill=A(R["glass"][2]))
    ld.rectangle([31, 64, 41, 69], fill=A(LIT_WIN))
    d.rectangle([26, 92, 46, 94], fill=A(R["rock"][1]))
    # counter window with a striped awning
    win(d, [49, 56, 68, 72], cr[2], ld, panes=False)
    for i, x in enumerate(range(47, 71, 4)):
        d.polygon([(x, 49), (x + 3, 49), (x + 3, 54), (x, 54)], fill=A(cr[2] if i % 2 else rf[2]))
    d.line([47, 49, 70, 49], fill=A(cr[3]))
    for x in range(47, 71, 4):
        d.point((x + 1, 55), fill=A(cr[1] if (x // 4) % 2 else rf[1]))
    d.rectangle([47, 73, 70, 75], fill=A(wd[3]))                     # counter ledge
    d.line([47, 75, 70, 75], fill=A(wd[1]))
    ld.rectangle([52, 64, 59, 71], fill=CLEAR)
    d.rectangle([52, 66, 59, 72], fill=A(gd[2]))                     # a lost thing on the counter: a gold box
    d.line([52, 66, 59, 66], fill=A(gd[3]))
    d.line([55, 66, 55, 72], fill=A(gd[1]))
    d.ellipse([61, 69, 65, 72], fill=A(C["pink"]))                   # and a ball
    d.point((62, 69), fill=A(WHITE))
    ld.rectangle([61, 69, 65, 72], fill=CLEAR)
    # small round mole door under the counter
    d.ellipse([54, 82, 66, 96], fill=A(wd[1]))
    d.rectangle([54, 90, 66, 94], fill=A(wd[1]))
    d.ellipse([56, 84, 64, 96], fill=A(wd[0]))
    d.rectangle([56, 90, 64, 94], fill=A(wd[0]))
    d.point((62, 89), fill=A(gd[2]))
    d.rectangle([12, 95, 72, 95], fill=CLEAR)
    # hanging sign: a bracket off the roof and a board with a magnifying glass
    d.line([72, 47, 90, 47], fill=A(mt[1]))
    d.line([73, 46, 89, 46], fill=A(mt[2]))
    d.line([77, 48, 77, 50], fill=A(mt[0]))
    d.line([88, 48, 88, 50], fill=A(mt[0]))
    d.rounded_rectangle([74, 51, 92, 66], 2, fill=A(gd[2]))
    d.line([75, 51, 91, 51], fill=A(gd[3]))
    d.line([75, 66, 91, 66], fill=A(gd[1]))
    d.ellipse([77, 53, 86, 62], fill=A(mt[0]))
    d.ellipse([79, 55, 84, 60], fill=A(R["glass"][2]))
    d.point((80, 56), fill=A(WHITE))
    d.line([85, 61, 89, 65], fill=A(wd[0]), width=2)
    # crate of odd finds by the shed
    d.rectangle([74, 80, 93, 94], fill=A(wd[2]))
    d.line([74, 80, 93, 80], fill=A(wd[3]))
    d.line([74, 87, 93, 87], fill=A(wd[1]))
    d.line([74, 80, 74, 94], fill=A(wd[3]))
    d.line([93, 81, 93, 94], fill=A(wd[1]))
    d.line([74, 80, 93, 94], fill=A(wd[1]))
    bt = R["boots"]                                                  # a boot sticking up
    d.rectangle([77, 69, 81, 79], fill=A(bt[2]))
    d.rectangle([77, 76, 85, 79], fill=A(bt[2]))
    d.line([77, 69, 77, 79], fill=A(bt[3]))
    d.line([77, 79, 85, 79], fill=A(bt[0]))
    d.rectangle([77, 69, 81, 70], fill=A(bt[1]))
    d.line([78, 72, 80, 72], fill=A(bt[3]))
    d.line([78, 74, 80, 74], fill=A(bt[3]))
    g.cap_at(d, 88, 77, R["metal"])                                  # a bottle cap
    d.rectangle([85, 72, 87, 79], fill=A(R["glass"][1]))             # a bottle neck
    d.point((85, 73), fill=A(WHITE))
    # mended, with a little moss left
    moss(d, [(13, 44, 4), (80, 79, 3)])
    o, l = finish(im, lit)
    return o, l, door


# =============================================================================== Gnome Village
def gnome_house(d, ld, x, ground, w, h, kind, seed):
    """A tiny gnome house: cream walls, a round window, a little door, red-brick or mushroom roof."""
    cr, wd, b = R["wall"], R["wood"], R["barn"]
    top = ground - h
    d.rectangle([x, top, x + w, ground], fill=A(cr[2]))
    d.line([x, top, x, ground], fill=A(cr[3]))
    d.line([x + w, top, x + w, ground], fill=A(cr[1]))
    d.line([x, ground, x + w, ground], fill=A(cr[1]))
    dx = x + 2 if seed % 2 else x + w - 6
    d.rectangle([dx, ground - 7, dx + 4, ground], fill=A(wd[1]))
    d.pieslice([dx, ground - 9, dx + 4, ground - 5], 180, 360, fill=A(wd[1]))
    d.point((dx + 3, ground - 3), fill=A(R["gold"][2]))
    wx = x + w - 6 if seed % 2 else x + 2
    round_win(d, ld, [wx, top + 3, wx + 4, top + 7], wd[1])
    if kind == "mush":
        cap = [x - 4, top - 9, x + w + 4, top + 5]
        d.pieslice(cap, 180, 360, fill=A(b[2]))
        d.arc(cap, 195, 250, fill=A(b[3]))
        d.line([x - 4, top - 2, x + w + 4, top - 2], fill=A(b[1]))
        cx = x + w // 2
        for sx, sy in ((cx - 4, top - 6), (cx + 3, top - 5), (x - 1, top - 3), (x + w, top - 4)):
            d.rectangle([sx, sy, sx + 1, sy + 1], fill=A(cr[3]))
    else:
        d.polygon([(x - 3, top), (x + w // 2, top - 13), (x + w + 3, top)], fill=A(b[2]))
        d.line([(x - 3, top), (x + w // 2, top - 13)], fill=A(b[3]))
        d.line([(x + w // 2 + 1, top - 12), (x + w + 3, top)], fill=A(b[1]))
        d.line([x - 3, top, x + w + 3, top], fill=A(b[0]))


def gnome_village():
    W, H = 96, 144
    im, lit, d, ld = canvases(W, H)
    rk, wd, r2, mt, gd = R["rock"], R["wood"], R["roof2"], R["metal"], R["gold"]
    # the tower, stood up straight
    stones(im, (30, 48, 62, 142), rk, "tower", rows=8)
    d = ImageDraw.Draw(im)
    win(d, [40, 66, 52, 80], wd[1], ld)
    win(d, [41, 92, 51, 102], wd[1], ld, panes=False)
    door = plank_door(d, [38, 116, 54, 142], wd, arch=True)
    # lookout platform with a rail
    d.rectangle([20, 44, 72, 49], fill=A(wd[2]))
    d.line([20, 44, 72, 44], fill=A(wd[3]))
    d.line([20, 49, 72, 49], fill=A(wd[1]))
    for x in (24, 68):
        d.line([x, 50, 31 if x < 40 else 61, 58], fill=A(wd[1]), width=2)
    for x in range(21, 73, 5):
        d.line([x, 36, x, 43], fill=A(wd[1]))
    d.line([20, 36, 72, 36], fill=A(wd[2]))
    d.line([20, 35, 72, 35], fill=A(wd[3]))
    # posts and a pointed roof over the lookout
    for x in (28, 64):
        d.line([x, 24, x, 43], fill=A(wd[1]), width=2)
    d.polygon([(22, 26), (46, 4), (70, 26)], fill=A(r2[2]))
    d.line([(22, 26), (46, 4)], fill=A(r2[3]))
    d.line([(47, 5), (70, 26)], fill=A(r2[1]))
    d.rectangle([22, 25, 70, 27], fill=A(r2[1]))
    for y in (12, 18):
        half = (y - 4) * 24 // 22
        d.line([46 - half + 2, y, 46 + half - 2, y], fill=A(r2[1]))
    # tiny flag
    d.line([46, 0, 46, 5], fill=A(mt[1]))
    d.polygon([(47, 0), (54, 2), (47, 4)], fill=A(gd[2]))
    d.point((47, 1), fill=A(gd[3]))
    # gnome houses clustered round the base
    gnome_house(d, ld, 4, 142, 13, 14, "point", 1)
    gnome_house(d, ld, 63, 142, 8, 9, "point", 4)
    gnome_house(d, ld, 73, 142, 17, 15, "mush", 2)
    gnome_house(d, ld, 19, 142, 10, 9, "mush", 3)
    # tiny lamp post
    lx = 34
    d.line([lx, 128, lx, 142], fill=A(mt[0]))
    d.rectangle([lx - 2, 124, lx + 2, 127], fill=A(LAMP))
    d.line([lx - 2, 123, lx + 2, 123], fill=A(mt[1]))
    d.line([lx - 1, 142, lx + 1, 142], fill=A(mt[1]))
    ld.rectangle([lx - 2, 124, lx + 2, 127], fill=A(FLAME))
    moss(d, [(30, 136, 4), (56, 60, 3)])
    o, l = finish(im, lit)
    return o, l, door


# =============================================================================== Museum
def gold_cup(d, x, y):
    gd = R["gold"]
    d.pieslice([x, y - 4, x + 10, y + 6], 0, 180, fill=A(gd[2]))
    d.line([x, y + 1, x + 10, y + 1], fill=A(gd[3]))
    d.arc([x - 2, y + 1, x + 2, y + 5], 90, 270, fill=A(gd[1]))
    d.arc([x + 8, y + 1, x + 12, y + 5], 270, 90, fill=A(gd[1]))
    d.line([x + 5, y + 6, x + 5, y + 8], fill=A(gd[1]))
    d.rectangle([x + 2, y + 9, x + 8, y + 10], fill=A(gd[2]))
    d.point((x + 2, y + 2), fill=A(WHITE))
    return [x - 2, y, x + 12, y + 10]


def bone(d, x, y):
    b = g.BONE
    d.rectangle([x + 3, y + 1, x + 12, y + 3], fill=A(b[2]))
    for ex in (x, x + 13):
        d.ellipse([ex, y - 1, ex + 2, y + 1], fill=A(b[2]))
        d.ellipse([ex, y + 3, ex + 2, y + 5], fill=A(b[2]))
    d.line([x + 3, y + 3, x + 12, y + 3], fill=A(b[1]))
    d.line([x + 3, y + 1, x + 12, y + 1], fill=A(b[3]))
    return [x, y - 1, x + 15, y + 5]


def museum():
    W = H = 96
    im, lit, d, ld = canvases(W, H)
    wd, cr, rk, r2, rf = R["wood"], R["wall"], R["rock"], R["roof2"], R["roof"]
    # solid stone base, raised above the pond (bottom rows may sit in the water)
    stones(im, (4, 76, 91, 94), rk, "museum_base", rows=6)
    d = ImageDraw.Draw(im)
    # the cabin's log walls, now dry and straight, behind a column front
    for y in range(40, 76, 6):
        d.rounded_rectangle([10, y, 85, y + 5], 2, fill=A(wd[2]))
        d.line([12, y, 83, y], fill=A(wd[3]))
        d.line([12, y + 5, 83, y + 5], fill=A(wd[1]))
    # pediment roof
    d.rectangle([4, 34, 91, 39], fill=A(cr[2]))
    d.line([4, 34, 91, 34], fill=A(cr[3]))
    d.line([4, 39, 91, 39], fill=A(cr[1]))
    d.polygon([(2, 33), (48, 10), (93, 33)], fill=A(r2[2]))
    d.line([(2, 33), (48, 10)], fill=A(r2[3]))
    d.line([(49, 11), (93, 33)], fill=A(r2[1]))
    d.polygon([(14, 30), (48, 15), (81, 30)], fill=A(cr[2]))
    d.line([(14, 30), (48, 15)], fill=A(cr[3]))
    d.line([14, 30, 81, 30], fill=A(cr[1]))
    d.line([2, 33, 93, 33], fill=A(r2[0]))
    # a gold star in the pediment (a picture, no letters)
    pts = g.star_pts(48, 24, 5, 2)
    d.polygon(pts, fill=A(R["gold"][2]))
    d.point((47, 22), fill=A(R["gold"][3]))
    # columns
    for x in (6, 30, 60, 84):
        d.rectangle([x, 40, x + 5, 75], fill=A(cr[2]))
        d.line([x, 40, x, 75], fill=A(cr[3]))
        d.line([x + 5, 40, x + 5, 75], fill=A(cr[1]))
        d.line([x + 2, 42, x + 2, 73], fill=A(cr[1]))
        d.rectangle([x - 1, 40, x + 6, 41], fill=A(cr[3]))
        d.rectangle([x - 1, 74, x + 6, 75], fill=A(cr[1]))
    # display windows with treasures in them
    for box, thing in (([13, 46, 28, 70], gold_cup), ([66, 46, 81, 70], bone)):
        win(d, box, wd[1], ld, panes=False)
        x0, y0, x1, y1 = box                                         # dark velvet back so the treasure pops
        d.rectangle([x0 + 1, y0 + 2, x1 - 1, y1 - 1], fill=A(rf[1]))
        d.line([x0 + 2, y0 + 3, x0 + 5, y0 + 3], fill=A(R["glass"][2]))
        d.point((x0 + 2, y0 + 4), fill=A(R["glass"][2]))
        cx = (box[0] + box[2]) // 2
        d.rectangle([box[0] + 1, box[3] - 5, box[2] - 1, box[3] - 1], fill=A(wd[3]))   # plinth
        d.line([box[0] + 1, box[3] - 5, box[2] - 1, box[3] - 5], fill=A(WHITE))
        ld.rectangle([box[0] + 1, box[3] - 5, box[2] - 1, box[3] - 1], fill=CLEAR)
        tb = thing(d, cx - 5, box[3] - 16) if thing is gold_cup else thing(d, cx - 7, box[3] - 9)
        ld.rectangle(tb, fill=CLEAR)
    # the door between the middle columns, with a fan light
    door = plank_door(d, [39, 50, 56, 75], wd, arch=True)
    d.pieslice([41, 52, 54, 64], 180, 360, fill=A(R["glass"][2]))
    ld.pieslice([41, 52, 54, 64], 180, 360, fill=A(LIT_WIN))
    d.line([47, 52, 47, 58], fill=A(wd[1]))
    ld.line([47, 52, 47, 58], fill=CLEAR)
    # steps
    d.rectangle([36, 76, 59, 78], fill=A(rk[3]))
    d.rectangle([33, 79, 62, 81], fill=A(rk[2]))
    d.line([33, 81, 62, 81], fill=A(rk[1]))
    moss(d, [(6, 88, 5), (78, 90, 5), (50, 92, 4)])
    o, l = finish(im, lit)
    return o, l, door


# =============================================================================== Dragon Perch
def round_tower(im, box, r4, seed):
    """Stone round tower: dressed stones, then a lit left edge and a shaded right edge."""
    x0, y0, x1, y1 = box
    stones(im, box, r4, seed, rows=8)
    d = ImageDraw.Draw(im)
    w = x1 - x0
    d.rectangle([x0, y0, x0 + 1, y1], fill=A(r4[3]))
    d.rectangle([x1 - max(2, w // 8), y0, x1, y1], fill=A(r4[1]))
    d.line([x1, y0, x1, y1], fill=A(r4[0]))


def dragon_perch():
    W = H = 144
    im, lit, d, ld = canvases(W, H)
    k, rk, wd, gd, mt, b = R["weath"], R["rock"], R["wood"], R["gold"], R["metal"], R["barn"]
    # the big middle drum, then two shorter round towers in front of its sides
    round_tower(im, (28, 30, 116, 118), rk, "perch_mid")
    d = ImageDraw.Draw(im)
    d.rectangle([28, 30, 116, 33], fill=A(rk[1]))                     # shadow under the nest
    for x0, x1 in ((4, 36), (108, 140)):
        round_tower(im, (x0, 60, x1, 118), rk, "perch_%d" % x0)
        d = ImageDraw.Draw(im)
        d.rectangle([x0 - 1, 54, x1 + 1, 59], fill=A(k[2]))           # cap and crenels
        d.line([x0 - 1, 54, x1 + 1, 54], fill=A(k[3]))
        d.line([x0 - 1, 59, x1 + 1, 59], fill=A(k[1]))
        for x in range(x0 + 1, x1 - 2, 8):
            d.rectangle([x, 49, x + 4, 53], fill=A(k[2]))
            d.line([x, 49, x + 4, 49], fill=A(k[3]))
            d.line([x + 4, 50, x + 4, 53], fill=A(k[1]))
    # the nest: a wide woven bowl on top of the drum, straw-gold rim
    d.chord([12, 2, 132, 46], 0, 180, fill=A(gd[1]))                  # bowl underside
    for i, y in enumerate(range(26, 46, 4)):                          # woven courses
        half = round(60 * (1 - ((y - 24) / 22) ** 2) ** .5)
        d.line([72 - half + 2, y, 72 + half - 2, y], fill=A(wd[2]))
        for x in range(72 - half + 3 + (i % 2) * 4, 72 + half - 4, 8):
            d.line([x, y + 1, x + 3, y + 1], fill=A(gd[2]))
    d.ellipse([12, 14, 132, 34], fill=A(gd[2]))                       # rim
    d.arc([12, 14, 132, 34], 180, 300, fill=A(gd[3]))
    d.arc([12, 14, 132, 34], 20, 160, fill=A(gd[1]))
    d.ellipse([24, 17, 120, 30], fill=A(wd[1]))                       # the hollow
    d.chord([24, 17, 120, 30], 180, 360, fill=A(wd[0]))
    d.arc([24, 17, 120, 30], 20, 160, fill=A(gd[3]))
    r = g.rng("nest")
    for _ in range(26):                                               # loose straws along the rim
        x = r.randrange(16, 128)
        y = 24 + (r.randrange(-8, -5) if r.random() < .5 else r.randrange(5, 8))
        if abs(x - 72) > 50:
            y = 24 + r.randrange(-3, 4)
        d.line([x, y, x + r.choice((-2, 2)), y], fill=A(r.choice((gd[3], gd[1]))))
    # arched door and its frame
    d.rectangle([56, 76, 88, 118], fill=A(k[2]))
    d.pieslice([56, 66, 88, 98], 180, 360, fill=A(k[2]))
    d.line([56, 82, 56, 118], fill=A(k[3]))
    d.arc([56, 66, 88, 98], 180, 270, fill=A(k[3]))
    door = plank_door(d, [60, 70, 84, 118], wd, arch=True)
    d.rectangle([66, 92, 78, 93], fill=A(mt[1]))                      # iron band
    d.rectangle([66, 104, 78, 105], fill=A(mt[1]))
    # windows: arched on the side towers, round on the drum
    for x in (15, 119):
        win(d, [x, 70, x + 10, 84], wd[1], ld, panes=False)
        d.line([x + 5, 71, x + 5, 83], fill=A(wd[1]))
        ld.line([x + 5, 71, x + 5, 83], fill=CLEAR)
    round_win(d, ld, [64, 44, 80, 60], wd[1])
    d.line([72, 45, 72, 59], fill=A(wd[1]))
    d.line([65, 52, 79, 52], fill=A(wd[1]))
    ld.line([72, 45, 72, 59], fill=CLEAR)
    ld.line([65, 52, 79, 52], fill=CLEAR)
    # banners hung under the nest, warm colours, a plain diamond and stripe
    for x, col, trim in ((40, b, gd), (92, R["pink"], gd)):
        d.line([x - 1, 38, x + 13, 38], fill=A(mt[1]))
        d.polygon([(x, 39), (x + 12, 39), (x + 12, 70), (x + 6, 64), (x, 70)], fill=A(col[2]))
        d.line([x, 39, x, 69], fill=A(col[3]))
        d.line([x + 12, 40, x + 12, 69], fill=A(col[1]))
        d.line([x + 1, 43, x + 11, 43], fill=A(trim[2]))
        d.polygon([(x + 6, 48), (x + 9, 53), (x + 6, 58), (x + 3, 53)], fill=A(trim[2]))
        d.point((x + 5, 50), fill=A(trim[3]))
    # braziers either side of the door
    for x in (44, 92):
        d.line([x + 4, 108, x + 4, 117], fill=A(mt[0]), width=2)
        d.line([x + 1, 117, x + 7, 117], fill=A(mt[1]))
        d.pieslice([x - 1, 98, x + 9, 110], 0, 180, fill=A(mt[1]))
        d.line([x - 1, 104, x + 9, 104], fill=A(mt[2]))
        d.polygon([(x, 103), (x + 2, 97), (x + 4, 100), (x + 5, 94), (x + 7, 99), (x + 8, 103)], fill=A(gd[2]))
        d.polygon([(x + 2, 103), (x + 4, 99), (x + 6, 103)], fill=A(FLAME))
        ld.polygon([(x, 103), (x + 2, 97), (x + 4, 100), (x + 5, 94), (x + 7, 99), (x + 8, 103)], fill=A(LIT_WIN))
        ld.polygon([(x + 2, 103), (x + 4, 99), (x + 6, 103)], fill=A(FLAME))
    # ivy kept, moss trimmed
    lf = R["leaf"]
    for x, y in ((8, 84), (10, 90), (7, 96), (134, 88), (132, 94)):
        d.rectangle([x, y, x + 2, y + 2], fill=A(lf[2]))
        d.point((x, y), fill=A(lf[3]))
    # the rocky peak it stands on, as the ruin
    d.polygon([(0, 143), (6, 124), (20, 116), (60, 118), (100, 115), (126, 118), (140, 128), (143, 143)], fill=A(rk[2]))
    d.line([(6, 124), (20, 116), (60, 118), (100, 115), (126, 118)], fill=A(rk[3]))
    for x, y in ((24, 128), (70, 132), (110, 126), (40, 138)):
        d.line([x, y, x + 6, y + 2], fill=A(rk[1]))
    d.rectangle([2, 140, 141, 143], fill=A(rk[1]))
    d.rectangle([56, 118, 88, 120], fill=A(k[3]))                      # door step
    d.line([56, 120, 88, 120], fill=A(k[1]))
    o, l = finish(im, lit)
    return o, l, door


# =============================================================================== write
BUILDINGS = [("lost_and_found", lost_and_found), ("gnome_village", gnome_village),
             ("museum", museum), ("dragon_perch", dragon_perch)]


def main():
    path = os.path.join(g.OUT, "manifest.json")
    with open(path) as f:
        manifest = json.load(f)
    bad = []
    for name, fn in BUILDINGS:
        im, lit, door = fn()
        g.save(im, "buildings/%s.png" % name)
        g.save(lit, "buildings/%s_lit.png" % name, env=False)
        manifest[name] = {"door": door, "file": "buildings/%s.png" % name, "lit": "buildings/%s_lit.png" % name,
                          "frame": list(im.size), "pivot": [0, im.height], "pivot_note": "bottom-left on the ground"}
        f = "buildings/%s.png" % name
        bad += ["%s: %s" % (f, hp.tohex(c)) for c in sorted(g.USED[f]) if hp.reserved_hue(c)]
        print("%-15s %dx%d door %s" % (name, im.width, im.height, door))
    with open(path, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    print("reserved-hue trespasses: %d" % len(bad))
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
