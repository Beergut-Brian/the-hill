"""Round 2 direction mocks. `python3 art/tools/make_direction2.py [d] [e]` redraws art/direction2/."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenes2 as S  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "direction2")
TAGS = {"d": "D  TERRARIA-LEANING", "e": "E  PICTURE BOOK"}


def split(mod, tag):
    im = Image.new("RGB", (1920, 1080), (16, 12, 20))
    im.paste(mod.render(S.split_up(tag)).crop((0, 0, 956, 1080)), (0, 0))
    im.paste(mod.render(S.split_down()).crop((4, 0, 960, 1080)), (964, 0))
    d = ImageDraw.Draw(im)
    for x, c in ((916, (228, 57, 60)), (980, (60, 194, 74))):      # P2 up top, P1 below
        d.ellipse([x, 20, x + 26, 46], fill=c, outline=(250, 244, 230), width=3)
    return im


def main():
    which = [a for a in sys.argv[1:] if a in TAGS] or list(TAGS)
    for k in which:
        mod = __import__("hill_" + k)
        for name, im in (("layers", mod.render(S.layers(TAGS[k]))), ("hillville", mod.render(S.hillville(TAGS[k]))),
                         ("split", split(mod, TAGS[k])), ("palette", mod.palette())):
            im.convert("RGB").save(os.path.join(OUT, "%s_%s.png" % (k, name)))
            print(k, name, im.size)
    if all(os.path.exists(os.path.join(OUT, "%s_hillville.png" % k)) for k in TAGS):
        sheet = Image.new("RGB", (1920, 1080))
        for i, n in enumerate(("d_layers", "d_hillville", "e_layers", "e_hillville")):
            sheet.paste(Image.open(os.path.join(OUT, n + ".png")).resize((960, 540), Image.LANCZOS), (i % 2 * 960, i // 2 * 540))
        sheet.save(os.path.join(OUT, "compare.png"))
        sheet = Image.new("RGB", (1920, 1080), (16, 12, 20))
        import make_direction as md1                       # A redrawn with the faceless loader
        a = md1.up(md1.scene_hillville(md1.hp.build(md1.hp.PALETTES["a"])))
        for i, src in enumerate((a, Image.open(os.path.join(OUT, "d_hillville.png")), Image.open(os.path.join(OUT, "e_hillville.png")))):
            sheet.paste(src.crop((880, 0, 1516, 1080)), (i * 642, 0))    # same window: headframe, Chuck, Front Loader
            S.plate(sheet, i * 642 + 14, 10, ("A  SANDBOX (round 1)", TAGS["d"], TAGS["e"])[i])
        sheet.save(os.path.join(OUT, "compare_all.png"))


if __name__ == "__main__":
    main()
