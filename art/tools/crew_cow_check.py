"""Read check for the Gnome crew and cow sheets (make_crew_cow_art.py --check DIR).

Per character: the 3D side view (flat trace render), the pixel form at 1x and at game scale (x2, The
Hill on a 1080p TV), a 16 px reduction of the same 3D view and its flat silhouette, then every prop
cell by cell at x8 with a "should read as" caption. Needs the trace renders in .scratch/trace and the
library's trace3d (read-only import).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
import make_crew_cow_art as M  # noqa: E402

BG = (255, 253, 244, 255)
INK = (42, 30, 44, 255)

PROPS = {
    "gnome_crew": [
        ("idle", "whistle at rest (front)", "a yellow referee whistle on a wood cord, on his chest BELOW the beard tip; not a pipe, nothing at his mouth"),
        ("march", "whistle at rest (side, marching)", "the same whistle hanging forward off his chest under the beard"),
        ("whistle", "whistle blown (side)", "a yellow whistle held out IN FRONT of the face at the mouth corner, sound lines out front; clear of the beard"),
        ("idle_side", "hard hat on the cone tip", "a tiny white hard hat sitting on the very tip of the teal cone"),
    ],
    "cow": [
        ("pail", "pail in her mouth", "a teal pail with a grey rim, hanging by its handle from her mouth (hold style in_mouth)"),
        ("pail_walk", "pail while walking", "the same pail, carried along at the muzzle while she walks"),
        ("idle", "horns, muzzle, patches", "two cream horn nubs, a pink muzzle, black patches on a white coat: a cow"),
    ],
}
SIDE = {"gnome_crew": ("gnome_crew_whistle", "side", "whistle"), "cow": ("cow_pail", "side", "pail")}


def font(n):
    return ImageFont.load_default(size=n)


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def silhouette(im):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3]:
                out.putpixel((x, y), INK)
    return out


def tiny(cid, name, view):
    """The 3D view reduced straight to 16 px tall (outline included), facing right."""
    sys.path.insert(0, os.path.join(M.LIB, "tools", "pixel"))
    import trace3d as T3
    T3.SRC = M.SRC
    T3.PAL[cid] = M.PAL[cid]
    T3.CANVAS[cid] = (32, 16)
    m = json.load(open(os.path.join(M.SRC, name + ".json")))
    s = 14 / (m["views"][view]["height_m"] * m["px_per_m"])
    tag = name[len(cid) + 1:] if name.startswith(cid + "_") else ""
    _k, rows = T3.reduce(cid, tag, view, s)
    im = M.outline(M.sprite(rows, M.PAL[cid])).transpose(Image.FLIP_LEFT_RIGHT)
    return im.crop(im.getbbox())


def frame(made, cid, row, col=0):
    f, fw, fh, rows, _c = made[cid]
    sheet = Image.open(os.path.join(M.SPRITES, f)).convert("RGBA")
    r = rows[row]["row"]
    im = sheet.crop((col * fw, r * fh, (col + 1) * fw, (r + 1) * fh))
    return im


def check(made, cid, title):
    W = 2600
    out = Image.new("RGBA", (W, 1400), BG)
    d = ImageDraw.Draw(out)
    d.text((20, 12), title, fill=INK, font=font(24))
    y = 52
    name, view, row = SIDE[cid]
    r3 = Image.open(os.path.join(M.SRC, f"{name}_{view}.png")).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    r3 = r3.crop(r3.getbbox())
    k3 = 220 / r3.height
    r3 = r3.resize((round(r3.width * k3), 220), Image.LANCZOS)
    px1 = frame(made, cid, row)
    px1 = px1.crop(px1.getbbox())
    t16 = tiny(cid, name, view)
    cells = [("3D side view (master)", r3), ("pixel 1x", px1), ("pixel x2 (game scale)", up(px1, 2)),
             ("pixel x4", up(px1, 4)), ("16 px from 3D, 1x", t16), ("16 px x4", up(t16, 4)),
             ("16 px silhouette x4", up(silhouette(t16), 4))]
    x = 20
    base = y + 240
    for label, im in cells:
        out.alpha_composite(im, (x, base - im.height))
        d.text((x, base + 8), label, fill=INK, font=font(16))
        x += max(im.width, int(d.textlength(label, font=font(16)))) + 36
    y = base + 50
    d.text((20, y), "Props, cell by cell (x8), and what each should read as:", fill=INK, font=font(20))
    y += 34
    for row_name, what, should in PROPS[cid]:
        n = made[cid][3][row_name]["frames"]
        x = 20
        h = 0
        for c in range(n):
            im = up(frame(made, cid, row_name, c), 8)
            bg = Image.new("RGBA", im.size, (214, 232, 214, 255))
            bg.alpha_composite(im)
            out.alpha_composite(bg, (x, y))
            x += im.width + 10
            h = im.height
        d.text((x + 10, y + 10), f"{row_name}: {what}", fill=INK, font=font(18))
        d.text((x + 10, y + 40), f"should read as: {should}", fill=INK, font=font(16))
        y += h + 16
        if y > out.height - 340:
            break
    return out.crop((0, 0, W, y + 10))


def main(made, outdir):
    os.makedirs(outdir, exist_ok=True)
    for cid, title in (("gnome_crew", "Gnome crew: read check (traced from the Gnome Foreman's 3D master, no clipboard)"),
                       ("cow", "Barn cow: read check (traced from the cow proposal's 3D master, quadruped, pail in_mouth)")):
        im = check(made, cid, title)
        p = os.path.join(outdir, f"{cid}_read_check.png")
        im.convert("RGB").save(p)
        print("wrote", p)
    for cid in ("gnome_crew", "cow"):                    # the sheets themselves at x4 on a light ground
        f = made[cid][0]
        sh = Image.open(os.path.join(M.SPRITES, f)).convert("RGBA")
        bg = Image.new("RGBA", sh.size, (214, 232, 214, 255))
        bg.alpha_composite(sh)
        up(bg, 4).convert("RGB").save(os.path.join(outdir, f"{cid}_sheet_x4.png"))
