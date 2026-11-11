#!/usr/bin/env python3
"""The Hill, dig lane (PT10-4): adds the Gate Rock and Hard Rock tiles to the terrain sheet.

    python3 art/tools/make_dig_tiles.py     # rewrites tiles/terrain.png + icons/blocks.png only

Reuses make_game_art's tile kit (edge_tile, palette A ramps) and appends two kinds after the
content lane's twelve, so palette ids 13 (gaterock) and 14 (hardrock) get their columns. Only the
terrain/block_icons manifest entries are patched; every other sheet is left alone. Deterministic.
  gate: deep violet slabs with gold studs (the unlock band; reads as "built", not as rock).
  hard: big iron-grey boulders with a cold shine and a gold fleck (only a vehicle breaks it).
"""
import json
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_game_art as g   # noqa: E402

GATE = g.hp.hx("#4a3d6b")
HARD = g.hp.hx("#5d6678")
GOLD = g.hp.hx("#ffd23f")
g.R["gate"] = g.hp.ramp(GATE, g.P)
g.R["hard"] = g.hp.ramp(HARD, g.P)
g.P["back"]["gate"] = g.P["back"]["stone"]
g.P["back"]["hard"] = g.P["back"]["stone"]
_base_texture = g.texture


def texture(kind, v):
    if kind not in ("gate", "hard"):
        return _base_texture(kind, v)
    T = g.T
    dp, lo, mid, hi = g.R[kind]
    im = g.Image.new("RGBA", (T, T), g.A(mid))
    p = im.load()

    def S(x, y, c):
        if 0 <= x < T and 0 <= y < T:
            p[x, y] = g.A(c)

    if kind == "gate":
        # Two slabs per tile (offset every other variant, like laid stone), lit top-left, dark
        # seams, a gold stud on each slab: reads as a made band, never as the layer's rock.
        split = 7 if v % 2 else 8
        for y in range(T):
            for x in range(T):
                if y in (0, split):
                    S(x, y, hi)
                if y in (split - 1, T - 1):
                    S(x, y, dp)
        seams = (5, 11) if v < 2 else (9, 3)
        for y in range(0, split - 1):
            S(seams[0], y, dp)
            S(seams[0] + 1, y, hi)
        for y in range(split + 1, T - 1):
            S(seams[1], y, dp)
            S(seams[1] + 1, y, hi)
        for sx, sy in ((2 + v % 2, 3), (13 - v % 3, split + 4)):
            S(sx, sy, GOLD)
            S(sx + 1, sy, GOLD)
            S(sx, sy + 1, lo)
            S(sx + 1, sy + 1, dp)
    else:
        # One big rounded boulder per tile with a cold shine and a gold fleck (a haul inside).
        r = g.rng("tex", kind, v)
        cx, cy, rad = 7.5 + (v % 2), 7.5 + (v // 2 % 2) * 0.5, 6.6
        for y in range(T):
            for x in range(T):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d > rad:
                    S(x, y, lo)
                elif d > rad - 1.2:
                    S(x, y, dp)
                elif x + y < cx + cy - 4:
                    S(x, y, hi)
        for i in range(3):
            S(int(cx) - 3 + i, int(cy) - 4, g.WHITE)
        fx, fy = r.randrange(6, 11), r.randrange(8, 12)
        S(fx, fy, GOLD)
        S(fx + 1, fy, GOLD)
    return im


g.texture = texture


def main():
    g.BLOCKS = g.BLOCKS + ["gate", "hard"]
    g.BLOCK_NAMES = g.BLOCK_NAMES + ["gaterock", "hardrock"]
    path = os.path.join(g.OUT, "manifest.json")
    with open(path) as f:
        manifest = json.load(f)
    g.make_tiles()
    for k in ("terrain", "block_icons"):
        manifest[k] = g.MANIFEST[k]
    with open(path, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    print("terrain: %d kinds" % len(g.BLOCKS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
