#!/usr/bin/env python3
"""The Hill's pixel logo for the Showtime menus (lobby title_texture).

Writes assets/ui/the_hill_logo.png: 140x32, transparent, palette A "Sandbox" only. The lobby
scales it 8x with nearest filtering (its title box is 1120x260). Deterministic; Pillow only.

    python3 art/tools/make_logo.py
"""
from pathlib import Path

from PIL import Image

W, H = 140, 32
CELL = 3  # one glyph cell = 3x3 logo pixels

OUTLINE = (0x3A, 0x2A, 0x44, 255)
GOLD_HI = (0xFF, 0xF0, 0x9A, 255)
GOLD = (0xFF, 0xD2, 0x3F, 255)
GOLD_LO = (0xF7, 0xB3, 0x22, 255)
GOLD_SH = (0xE8, 0x91, 0x3C, 255)
GRASS = (0x8C, 0xCF, 0x3C, 255)
HILL = (0xB4, 0xE0, 0x7A, 255)
SOIL = (0x9A, 0x6A, 0x40, 255)
SOIL_LO = (0x7B, 0x43, 0x2B, 255)
HOLE = (0x3E, 0x2A, 0x21, 255)

# 5x7 glyphs, "#" = filled cell.
GLYPHS = {
    "T": ["#####", "#####", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "H": ["##.##", "##.##", "##.##", "#####", "##.##", "##.##", "##.##"],
    "E": ["#####", "##...", "##...", "####.", "##...", "##...", "#####"],
    "I": ["##", "##", "##", "##", "##", "##", "##"],
    "L": ["##...", "##...", "##...", "##...", "##...", "##...", "#####"],
}
TEXT = "THE HILL"
GAP = 2  # logo pixels between glyphs (before outline)
SPACE = 8


def text_mask() -> tuple[set, int]:
    pts = set()
    x = 0
    for ch in TEXT:
        if ch == " ":
            x += SPACE
            continue
        g = GLYPHS[ch]
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == "#":
                    for dy in range(CELL):
                        for dx in range(CELL):
                            pts.add((x + gx * CELL + dx, gy * CELL + dy))
        x += len(g[0]) * CELL + GAP
    return pts, x - GAP


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    mask, tw = text_mask()
    th = 7 * CELL
    ox = (W - tw) // 2
    oy = 1

    # The hill under the letters: a wide mound with grass on top and a hole dug in it.
    hill_l, hill_r = 1, W - 2
    top = 19
    cx = (hill_l + hill_r) / 2.0
    half = (hill_r - hill_l) / 2.0
    for x in range(hill_l, hill_r + 1):
        t = abs(x - cx) / half
        y0 = int(round(top + (H - 4 - top) * t * t))
        for y in range(y0, H - 1):
            px[x, y] = GRASS if y < y0 + 2 else (HILL if y < y0 + 3 else SOIL)
    for x in range(hill_l, hill_r + 1):
        for y in range(H - 4, H - 1):
            if px[x, y][3]:
                px[x, y] = SOIL_LO
    hole_x = int(cx) + 4
    for y in range(H - 9, H - 2):
        for x in range(hole_x - 3, hole_x + 4):
            if (x - hole_x) ** 2 * 1.3 + (y - (H - 5)) ** 2 <= 11:
                px[x, y] = HOLE

    # Outline the hill (1 px, outside).
    hill = {(x, y) for x in range(W) for y in range(H) if px[x, y][3]}
    for (x, y) in list(hill):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in hill and 0 <= q[0] < W and 0 <= q[1] < H:
                px[q] = OUTLINE

    # Letters: drop shadow (down 2), outline (1 px, 8-way), then a 4-step gold ramp, lit top-left.
    letters = {(x + ox, y + oy) for (x, y) in mask}
    shadow = {(x, y + 2) for (x, y) in letters}
    ring = set()
    for (x, y) in letters | shadow:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                ring.add((x + dx, y + dy))
    for (x, y) in ring:
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = OUTLINE
    for (x, y) in shadow - letters:
        px[x, y] = GOLD_SH
    for (x, y) in letters:
        ry = y - oy
        if ry < 2:
            c = GOLD_HI
        elif ry >= th - 4:
            c = GOLD_LO
        else:
            c = GOLD
        px[x, y] = c

    out = Path(__file__).resolve().parents[2] / "assets" / "ui" / "the_hill_logo.png"
    img.save(out)
    print(out, img.size)


if __name__ == "__main__":
    main()
