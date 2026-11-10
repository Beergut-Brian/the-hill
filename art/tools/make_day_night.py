#!/usr/bin/env python3
"""Day / dusk / night strip for The Hill: palettes A, B, C on one Hillville crop.

    python3 art/tools/make_day_night.py     # writes art/direction2/day_night_strip.png (1920x1080)

Each column is a 212x360 crop of the 640x360 mock, graded and lit at 1x, then scaled x3 nearest.
"""
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hillpix as hp  # noqa: E402
import make_direction as md  # noqa: E402
from hillpix import A, WHITE  # noqa: E402

W, H = md.W, md.H
CROP_X, CROP_W = 294, 212
COL_W, GUTTER = 636, 6
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "direction2", "day_night_strip.png")
HORIZON = 17 * hp.T
MAGENTA = (255, 0, 255)

NIGHT_TOP, NIGHT_HORIZON = hp.hx("#0b1030"), hp.hx("#2a3270")
NIGHT_GRADE = (0.50, 0.55, 0.85)
DUSK_GRADE = (1.0, 0.90, 0.84)
DUSK_BAND = (255, 128, 72)
WARM = (255, 200, 110)
LAMP = (255, 236, 150)

# lamp positions in the 640x360 scene (loader sprite is pasted at 394, gy - 53)
LANTERN = (352, 222)
NOSE_LAMP = (460, 244)
ROOF_LAMP = (432, 222)
CAGE = (330, 262)
CHUCK = (386, 256)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def sky_layer(kind, P):
    im = Image.new("RGBA", (W, H), A(P["c"]["sky2"]))
    d = ImageDraw.Draw(im)
    if kind == "night":
        n = 10
        for i in range(n):
            y0, y1 = HORIZON * i // n, HORIZON * (i + 1) // n
            d.rectangle([0, y0, W, y1], fill=A(lerp(NIGHT_TOP, NIGHT_HORIZON, i / (n - 1))))
        rnd = random.Random(7)
        for _ in range(110):
            x, y = rnd.randrange(W), int(rnd.random() ** 1.6 * (HORIZON - 40))
            c = rnd.choice(((240, 240, 255), (200, 210, 255), (255, 240, 200)))
            im.putpixel((x, y), A(c))
            if rnd.random() < .1:   # a few plus-shaped stars
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    im.putpixel((x + dx, y + dy), A(lerp(c, NIGHT_HORIZON, .5)))
        mx, my = 446, 58
        d.ellipse([mx - 10, my - 10, mx + 10, my + 10], fill=A((205, 205, 190)))
        d.ellipse([mx - 10, my - 10, mx + 8, my + 8], fill=A((244, 240, 214)))
        for cx, cy, r in ((mx - 3, my - 3, 2), (mx + 3, my + 3, 1), (mx - 4, my + 4, 1)):
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=A((214, 210, 184)))
        return im
    hp.sky(im, P, HORIZON)
    if kind == "day":
        sx, sy, col = 452, 12, P["c"]["sun"]
    else:
        top = 60
        for y in range(top, HORIZON):
            t = (y - top) / (HORIZON - top)
            row = Image.new("RGBA", (W, 1), A(DUSK_BAND)[:3] + (round(235 * t ** 0.9),))
            im.alpha_composite(row, (0, y))
        sx, sy, col = 452, 120, (255, 160, 70)
    d = ImageDraw.Draw(im)
    d.ellipse([sx - 13, sy, sx + 13, sy + 26], fill=A(col))
    d.ellipse([sx - 10, sy + 3, sx + 10, sy + 23], fill=A((255, 244, 200) if kind == "dusk" else WHITE))
    return im


def glow(layer, xy, r, col, a=255, blur=None):
    """Soft radial pool on a transparent layer."""
    g = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([xy[0] - r, xy[1] - r, xy[0] + r, xy[1] + r], fill=col + (a,))
    g = g.filter(ImageFilter.GaussianBlur(blur or r / 2.2))
    layer.alpha_composite(g)


def cone(layer, apex, length, spread, col, a, tilt=0):
    g = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    x, y = apex
    ImageDraw.Draw(g).polygon([(x, y - 1), (x + length, y + tilt - spread), (x + length, y + tilt + spread), (x, y + 1)],
                              fill=col + (a,))
    g = g.filter(ImageFilter.GaussianBlur(3))
    layer.alpha_composite(g)


def screen(base, layer):
    """Add light: screen the layer's colour (scaled by its alpha) over the image."""
    rgb = Image.new("RGB", base.size, (0, 0, 0))
    rgb.paste(layer.convert("RGB"), mask=layer.getchannel("A"))
    out = ImageChops.screen(base.convert("RGB"), rgb)
    return out.convert("RGBA")


def render(kind):
    P = hp.build(hp.PALETTES[{"day": "a", "dusk": "b", "night": "c"}[kind]])
    scene = md.scene_hillville(P, sky_fill=MAGENTA, sun=False, clouds=(kind != "night"))
    sky = sky_layer(kind, P)
    mask = Image.new("L", scene.size, 0)
    sp, mp = scene.load(), mask.load()
    for y in range(HORIZON + 1):
        for x in range(W):
            if sp[x, y][:3] == MAGENTA:
                mp[x, y] = 255
    world = scene
    if kind == "night":
        tint = Image.new("RGB", scene.size, tuple(round(255 * v) for v in NIGHT_GRADE))
        graded = ImageChops.multiply(scene.convert("RGB"), tint).convert("RGBA")
        pool = Image.new("L", scene.size, 0)           # Chuck keeps his colours in a soft pool of light
        ImageDraw.Draw(pool).ellipse([CHUCK[0] - 17, CHUCK[1] - 24, CHUCK[0] + 17, CHUCK[1] + 16], fill=235)
        pool = pool.filter(ImageFilter.GaussianBlur(5))
        world = Image.composite(scene, graded, pool)
    if kind == "dusk":
        tint = Image.new("RGB", scene.size, tuple(round(255 * v) for v in DUSK_GRADE))
        world = ImageChops.multiply(scene.convert("RGB"), tint).convert("RGBA")
    out = Image.composite(sky, world, mask).convert("RGBA")

    L = Image.new("RGBA", out.size, (0, 0, 0, 0))
    if kind == "dusk":
        glow(L, LANTERN, 14, WARM, 150)
        glow(L, LANTERN, 3, (255, 240, 180), 255, 1)
        glow(L, CAGE, 7, WARM, 70)
        glow(L, ROOF_LAMP, 4, LAMP, 130, 2)
        glow(L, NOSE_LAMP, 6, LAMP, 190, 2)
        cone(L, NOSE_LAMP, 30, 7, LAMP, 70, tilt=10)
    elif kind == "night":
        glow(L, LANTERN, 40, WARM, 210)
        glow(L, LANTERN, 14, (255, 225, 150), 230)
        glow(L, LANTERN, 3, (255, 245, 200), 255, 1)
        glow(L, CAGE, 14, WARM, 130)
        glow(L, CHUCK, 20, (255, 210, 150), 70)
        glow(L, ROOF_LAMP, 9, LAMP, 190, 3)
        glow(L, NOSE_LAMP, 9, LAMP, 230, 3)
        cone(L, NOSE_LAMP, 62, 15, LAMP, 190, tilt=12)
        glow(L, (484, 268), 14, WARM, 110)               # warm patch where the beam lands
    out = screen(out, L)
    if kind != "day":   # lamp lenses and lantern core stay crisp
        d = ImageDraw.Draw(out)
        for x, y in (LANTERN,):
            d.rectangle([x - 1, y - 2, x + 1, y + 2], fill=A((255, 244, 190)))
    return out.crop((CROP_X, 0, CROP_X + CROP_W, H))


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    strip = Image.new("RGB", (1920, 1080), hp.hx("#14121a")[:3])
    labels = {"day": "DAY  (A SANDBOX)", "dusk": "DUSK  (B STORYBOOK)", "night": "NIGHT  (C LANTERN + NIGHT GRADE)"}
    for i, kind in enumerate(("day", "dusk", "night")):
        x0 = i * (COL_W + GUTTER)
        crop = render(kind)
        strip.paste(crop.resize((COL_W, 1080), Image.NEAREST).convert("RGB"), (x0, 0))
        hp.text(strip, 6 + 4, 4, labels[kind], WHITE, hp.hx("#14121a"), size=6)
        hp.flush(strip, 3, ox=x0, oy=0)
    strip.save(OUT)
    print("wrote", OUT, strip.size, "crop x", CROP_X, "..", CROP_X + CROP_W)


if __name__ == "__main__":
    main()
