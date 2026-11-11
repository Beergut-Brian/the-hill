#!/usr/bin/env python3
"""The Hill: the Workshop (B-06), drawn in code (no generative model).

    python3 art/tools/make_workshop_art.py      # writes buildings/workshop.png + _lit, merges manifest.json

Same look as make_game_art.py (palette A "Sandbox", outline #3a2a44, its helpers). 2 x 2 plots (96 x 96).
A stone smithy with a timber top floor, a brick chimney, an open bay with an anvil and a forge glow, and a
hanging sign that is a picture (a hammer crossed with a shovel), never letters. No faces.
The hammer, the sparks and the chimney smoke are drawn in the engine (scenes/buildings/workshop_fx.gd).
Only touches the two files and the manifest key "workshop"; deterministic.
"""
import json
import os
import sys

from PIL import ImageDraw

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import make_game_art as g                 # noqa: E402  helpers only; its main() is guarded
import make_restored_art as ra            # noqa: E402
import hillpix as hp                      # noqa: E402

A, R, P, CLEAR, WHITE, LIT_WIN = g.A, g.R, g.P, g.CLEAR, g.WHITE, g.LIT_WIN
DARK = P["back"]["top"][1]


def workshop():
    W = H = 96
    im, lit, d, ld = ra.canvases(W, H)
    rk, wd, mt, rf, gd, br = R["rock"], R["wood"], R["metal"], R["roof"], R["gold"], R["barn"]
    # brick chimney at the back right (drawn first: the roof overlaps its foot)
    d.rectangle([68, 4, 79, 34], fill=A(br[1]))
    for y in range(6, 34, 4):
        d.line([69, y, 78, y], fill=A(br[0]))
        off = 0 if (y // 4) % 2 else 3
        for x in range(70 + off, 78, 6):
            d.line([x, y - 3, x, y - 1], fill=A(br[0]))
    d.rectangle([66, 2, 81, 5], fill=A(rk[2]))
    d.line([66, 2, 81, 2], fill=A(rk[3]))
    # timber top floor
    g.planks(im, (10, 30, 85, 50), wd, step=5, horiz=True, seed=21)
    d = ImageDraw.Draw(im)
    for x in (10, 36, 59, 85):
        d.rectangle([x - 1, 30, x + 1, 50], fill=A(wd[1]))
    d.line([10, 50, 85, 30], fill=A(wd[1]), width=2)
    # roof: slate blue, over the timber floor
    d.polygon([(2, 32), (22, 12), (74, 12), (94, 32)], fill=A(rf[2]))
    for y in range(16, 32, 4):
        x0 = 2 + (32 - y)
        d.line([x0 + 1, y, 94 - (32 - y) - 1, y], fill=A(rf[1]))
    d.line([(3, 31), (22, 12), (74, 12)], fill=A(rf[3]))
    d.line([(74, 13), (93, 31)], fill=A(rf[0]))
    d.rectangle([2, 31, 94, 33], fill=A(rf[0]))
    # two small top windows
    g.win(d, [16, 36, 27, 46], wd[1], ld)
    g.win(d, [68, 36, 79, 46], wd[1], ld)
    # stone ground floor
    g.stones(im, (6, 50, 89, 94), rk, "workshop_base", rows=6)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 50, 89, 52], fill=A(wd[1]))
    # the open bay: dark inside, a forge glow at the back, an anvil on a stump in front of it
    bay = [24, 58, 71, 94]
    d.rectangle([bay[0] - 2, bay[1] - 2, bay[2] + 2, bay[3]], fill=A(wd[1]))
    d.rectangle(bay, fill=A(DARK))
    d.line([bay[0] + 1, bay[1] + 1, bay[2] - 1, bay[1] + 1], fill=A(wd[0]))
    # forge: a stone hood and coals
    d.rectangle([52, 62, 68, 70], fill=A(rk[1]))
    d.polygon([(54, 62), (66, 62), (62, 58), (58, 58)], fill=A(rk[1]))
    d.rectangle([52, 71, 68, 80], fill=A(rk[2]))
    d.rectangle([54, 72, 66, 76], fill=A(gd[1]))
    d.line([55, 73, 65, 73], fill=A(gd[2]))
    for x in range(55, 66, 3):
        d.point((x, 74), fill=A(gd[3]))
    ld.rectangle([54, 72, 66, 76], fill=A(LIT_WIN))
    d.rectangle([52, 81, 68, 94], fill=A(rk[1]))
    # tools hanging on the back wall: a saw shape, pincers, a spare shovel
    d.line([28, 62, 28, 76], fill=A(wd[2]))
    d.rectangle([26, 76, 30, 80], fill=A(mt[2]))
    d.line([34, 62, 38, 72], fill=A(mt[1]))
    d.line([36, 62, 34, 72], fill=A(mt[1]))
    d.rectangle([41, 63, 47, 66], fill=A(mt[2]))
    d.line([41, 63, 47, 63], fill=A(mt[3]))
    # anvil on a stump (bottom left of the bay)
    d.rectangle([33, 84, 43, 94], fill=A(wd[1]))
    d.line([34, 84, 34, 94], fill=A(wd[2]))
    d.polygon([(28, 78), (47, 78), (45, 81), (41, 82), (41, 84), (35, 84), (35, 82), (31, 81)], fill=A(mt[1]))
    d.line([29, 78, 46, 78], fill=A(mt[3]))
    d.line([31, 79, 44, 79], fill=A(mt[2]))
    # grindstone wheel outside, on the left
    d.rectangle([9, 84, 19, 94], fill=A(wd[1]))
    d.ellipse([7, 72, 21, 86], fill=A(rk[2]))
    d.ellipse([9, 74, 19, 84], fill=A(rk[3]))
    d.ellipse([12, 77, 16, 81], fill=A(wd[1]))
    # crate of bars on the right
    d.rectangle([76, 82, 88, 94], fill=A(wd[2]))
    d.rectangle([76, 82, 88, 84], fill=A(wd[3]))
    d.line([76, 88, 88, 88], fill=A(wd[1]))
    for x in (78, 82, 86):
        d.rectangle([x - 1, 79, x, 82], fill=A(mt[2]))
    # the hanging sign: a picture of a hammer crossed with a shovel, no letters
    d.line([38, 52, 38, 54], fill=A(mt[1]))
    d.line([57, 52, 57, 54], fill=A(mt[1]))
    d.rounded_rectangle([34, 53, 61, 66], 2, fill=A(wd[2]))
    d.rounded_rectangle([35, 54, 60, 65], 2, outline=A(wd[1]))
    d.line([38, 63, 56, 55], fill=A(wd[0]), width=2)          # shovel handle
    d.polygon([(54, 55), (58, 54), (59, 57), (56, 59)], fill=A(mt[3]))
    d.line([39, 55, 55, 63], fill=A(wd[0]), width=2)          # hammer handle
    d.rectangle([36, 54, 41, 57], fill=A(gd[2]))
    d.line([36, 54, 41, 54], fill=A(gd[3]))
    ld.rectangle([34, 53, 61, 66], fill=CLEAR)
    g.moss(d, [(6, 92, 4), (84, 92, 5)])
    o, l = g.finish(im, lit)
    return o, l, [(bay[0] + bay[2] + 1) // 2, bay[3]]


def main():
    path = os.path.join(g.OUT, "manifest.json")
    with open(path) as f:
        manifest = json.load(f)
    im, lit, door = workshop()
    g.save(im, "buildings/workshop.png")
    g.save(lit, "buildings/workshop_lit.png", env=False)
    manifest["workshop"] = {"door": door, "file": "buildings/workshop.png", "lit": "buildings/workshop_lit.png",
                            "frame": list(im.size), "pivot": [0, im.height], "pivot_note": "bottom-left on the ground"}
    f = "buildings/workshop.png"
    bad = ["%s: %s" % (f, hp.tohex(c)) for c in sorted(g.USED[f]) if hp.reserved_hue(c)]
    with open(path, "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("workshop %dx%d door %s; reserved-hue trespasses: %d" % (im.width, im.height, door, len(bad)))
    for b in bad:
        print("  " + b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
