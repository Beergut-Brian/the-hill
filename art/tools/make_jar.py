# Builds store/jar.glb: The Hill's tiny world for the Open Jar launcher's hub jar. Art lane.
# Run through art/tools/make_jar.sh (Blender 5.2.3, background). Same pipeline as Junk Yard Zap's
# and Spaceballs' jars.
#
# Launcher contract (openjar-launcher docs/contracts.md, "Jar world"):
# Y up, origin at the centre of the floor, fits a cylinder r 0.8 m x h 1.9 m, reads from every side
# (turntable), no text, <= 5,000 triangles, <= 8 materials, textures <= 512 px, no external files.
# Flat colours come from one 32 px palette texture with per-face UVs: the launcher's runtime
# GLTFDocument drops vertex colours on untextured materials.
#
# The diorama: a round plug of the hill, cut away at the front. Its sides are the six layers
# (Topsoil, Clay, Stone, Ice, Crystal, The Bottom) with crystals poking out all round; the cut shows
# the dig shaft with the elevator cage, a tunnel, a fossil and the dragon egg. On the grass top:
# the wooden headframe over the shaft (Hillville's tower), a little hill with the Lighthouse, a red
# barn, the yellow Front Loader (no face), a block pile and trees. Palette A "Sandbox"
# (art/direction/palettes.md). No text, no faces, nothing sharp or scary.
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "store/jar.glb")


def hexc(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


# Palette A "Sandbox": per layer (deep, low, mid, high, wall, wall dark), then surface and props.
LAYERS = [  # bottom to top: name, height, ramp
    ("bottom", 0.12, ["6c1d4c", "862e54", "a8455f", "d57d95", "542c3d", "432331"]),
    ("crystal", 0.13, ["572c93", "7444b8", "a865e6", "db98fa", "553f73", "44325c"]),
    ("ice", 0.13, ["677ea1", "8fafc9", "c4ecfb", "d8fbff", "4f8fc4", "3f729d"]),
    ("stone", 0.15, ["414276", "5b6693", "7f93b8", "aec7df", "45495c", "373a4a"]),
    ("clay", 0.15, ["942712", "ba5423", "e8913c", "fbcf79", "74462f", "5d3826"]),
    ("topsoil", 0.16, ["63251b", "7b432b", "9a6a40", "cdae79", "4d3429", "3e2a21"]),
]
LAYERS = [(n, h, [hexc(c) for c in ramp]) for n, h, ramp in LAYERS]
HILL = hexc("b4e07a")
GRASS = hexc("8ccf3c")
GRASS_DARK = hexc("5fa830")
LEAF = hexc("2f9a74")
LEAF2 = hexc("47b583")
WOOD = hexc("a8703c")
WOOD_DARK = hexc("6b4a3a")
WALL = hexc("fbe8c0")
ROOF = hexc("5a6f9c")
BARN = hexc("c4532f")
METAL = hexc("aab4c4")
VEH = hexc("f7b322")
VEH_DARK = hexc("c98a12")
TYRE = hexc("40405a")
GLASS = hexc("bfeeff")
GOLD = hexc("ffd23f")
PINK = hexc("ff6fa8")
ROCK = hexc("a9a29a")
CREAM = hexc("f4e6c4")
SHAFT = hexc("2c1f1b")

R = 0.64                       # plug radius
SEGS = 32                      # around the plug
NOTCH = (-math.radians(45), math.radians(225))   # the solid runs CCW from -45 deg to 225 deg; the cut faces -Y (front)
TOP = sum(h for _, h, _ in LAYERS)
GRASS_H = 0.045


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


PALETTE = {}
PAL_CELLS = 8
PAL_CELL_PX = 4


def pal_uv(c):
    key = tuple(round(x, 4) for x in c[:3])
    if key not in PALETTE:
        assert len(PALETTE) < PAL_CELLS * PAL_CELLS, "palette full"
        PALETTE[key] = len(PALETTE)
    i = PALETTE[key]
    return ((i % PAL_CELLS + 0.5) / PAL_CELLS, (i // PAL_CELLS + 0.5) / PAL_CELLS)


def colour_faces(obj, fn):
    me = obj.data
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        u = pal_uv(fn(poly.index, poly.center))
        for li in poly.loop_indices:
            uv.data[li].uv = u


def from_bmesh(name, bm, colour, smooth=False):
    for f in bm.faces:
        f.smooth = smooth
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    colour_faces(obj, colour if callable(colour) else (lambda i, p: colour))
    return obj


def place(obj, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    obj.location = loc
    obj.rotation_euler = rot
    obj.scale = scale
    return obj


def cylinder(name, r1, r2, depth, segs, colour, cap=True, smooth=False):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return from_bmesh(name, bm, colour, smooth)


def sphere(name, r, segs, rings, colour, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return from_bmesh(name, bm, colour, smooth)


def ico(name, r, subdiv, colour, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    return from_bmesh(name, bm, colour, smooth)


def rbox(name, size, colour, bevel=0.01, segs=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0 and min(size) >= 0.03:   # thin parts stay sharp: the bevel triangles go where they show
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES", profile=0.5)
    return from_bmesh(name, bm, colour, smooth=segs > 1)


def torus(name, r_major, r_minor, colour, segs=14, ring=6):
    bm = bmesh.new()
    for i in range(segs):
        for j in range(ring):
            a, b = 2 * math.pi * i / segs, 2 * math.pi * j / ring
            bm.verts.new(((r_major + r_minor * math.cos(b)) * math.cos(a), (r_major + r_minor * math.cos(b)) * math.sin(a), r_minor * math.sin(b)))
    bm.verts.ensure_lookup_table()
    for i in range(segs):
        for j in range(ring):
            bm.faces.new([bm.verts[i * ring + j], bm.verts[((i + 1) % segs) * ring + j],
                          bm.verts[((i + 1) % segs) * ring + (j + 1) % ring], bm.verts[i * ring + (j + 1) % ring]])
    return from_bmesh(name, bm, colour, smooth=True)


def gem(name, r, h, colour):
    """A rounded-off crystal: a short 6-sided bipyramid."""
    bm = bmesh.new()
    ring = [bm.verts.new((r * math.cos(a), r * math.sin(a), 0)) for a in [k * math.pi / 3 for k in range(6)]]
    top, bot = bm.verts.new((0, 0, h)), bm.verts.new((0, 0, -h * 0.5))
    for k in range(6):
        bm.faces.new([ring[k], ring[(k + 1) % 6], top])
        bm.faces.new([ring[(k + 1) % 6], ring[k], bot])
    return from_bmesh(name, bm, colour)


_pal_mat = None


def palette_material():
    global _pal_mat
    if _pal_mat is None:
        _pal_mat = bpy.data.materials.new("hill_palette")
        _pal_mat.use_nodes = True
        nt = _pal_mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        t = nt.nodes.new("ShaderNodeTexImage")
        t.interpolation = "Closest"
        t.name = "pal"
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.75
    return _pal_mat


def bake_palette():
    px = PAL_CELLS * PAL_CELL_PX
    img = bpy.data.images.new("hill_palette", px, px, alpha=False)
    buf = [1.0] * (px * px * 4)
    for c, i in PALETTE.items():
        srgb = [12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055 for x in c]
        cx, cy = (i % PAL_CELLS) * PAL_CELL_PX, (i // PAL_CELLS) * PAL_CELL_PX
        for y in range(cy, cy + PAL_CELL_PX):
            for x in range(cx, cx + PAL_CELL_PX):
                buf[(y * px + x) * 4:(y * px + x) * 4 + 3] = srgb
    img.pixels = buf
    img.pack()
    palette_material().node_tree.nodes["pal"].image = img


# ---------------------------------------------------------------- the plug (Blender Z up, -Y front)

def _hash(*k):
    return random.Random(hash(k) & 0xFFFFFFFF).random()


def wedge(name, r, z0, z1, rows, cols, side_col, cut_col, top_col=None, bottom=False):
    """A slab of the plug: the 270 deg solid from NOTCH[0] CCW to NOTCH[1], outer side split into
    `rows`, the two cut faces into rows x cols cells. side_col(seg, row), cut_col(face, col, row)
    with col 0 at the axis; top_col() caps the top when given."""
    a0, a1 = NOTCH
    bm = bmesh.new()
    zs = [z0 + (z1 - z0) * k / rows for k in range(rows + 1)]
    angs = [a0 + (a1 - a0) * i / SEGS for i in range(SEGS + 1)]
    ring = [[bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a in angs] for z in zs]
    axis = [bm.verts.new((0, 0, z)) for z in zs]
    cols_of = {}
    for row in range(rows):
        for i in range(SEGS):
            f = bm.faces.new([ring[row][i], ring[row][i + 1], ring[row + 1][i + 1], ring[row + 1][i]])
            cols_of[f] = side_col(i, row)
    for face, a in ((0, a0), (1, a1)):
        grid = [[bm.verts.new((r * c / cols * math.cos(a), r * c / cols * math.sin(a), z)) for c in range(cols + 1)] for z in zs]
        for row in range(rows):
            for c in range(cols):
                q = [grid[row][c], grid[row][c + 1], grid[row + 1][c + 1], grid[row + 1][c]]
                f = bm.faces.new(q if face == 1 else list(reversed(q)))
                cols_of[f] = cut_col(face, c, row)
    if top_col is not None:
        for i in range(SEGS):
            f = bm.faces.new([axis[-1], ring[-1][i], ring[-1][i + 1]])
            cols_of[f] = top_col()
    if bottom:
        for i in range(SEGS):
            f = bm.faces.new([axis[0], ring[0][i + 1], ring[0][i]])
            cols_of[f] = side_col(i, 0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    order = [cols_of[f] for f in bm.faces]
    return from_bmesh(name, bm, lambda i, p: order[i])


def plug():
    z = 0.0
    cols = 7
    for li, (name, h, ramp) in enumerate(LAYERS):
        deep, low, mid, high, wall, wall_dark = ramp
        rows = 2

        def side(seg, row, li=li, low=low, mid=mid, high=high, deep=deep):
            v = _hash(li, seg, row)
            return high if v < 0.12 else low if v < 0.42 else deep if v < 0.47 else mid

        def cut(face, c, row, li=li, name=name, low=low, mid=mid, high=high, wall=wall, wall_dark=wall_dark):
            if c == 0 and name not in ("bottom",):
                return SHAFT if face == 0 else wall_dark                  # the dig shaft, cut in half
            if name == "clay" and face == 1 and row == 0 and 1 <= c <= 4:
                return wall                                             # a side tunnel off the shaft
            if name == "bottom" and face == 0 and row == 1 and 1 <= c <= 3:
                return wall                                             # the egg's warm pocket
            v = _hash(li, face, c, row, 9)
            return high if v < 0.15 else low if v < 0.45 else mid

        wedge("Layer_" + name, R, z, z + h, rows, cols, side, cut, bottom=(li == 0))
        z += h
    # Grass cap, a touch wider, overhanging the topsoil.
    wedge("Grass", R + 0.012, TOP, TOP + GRASS_H, 1, cols,
          lambda s, r: GRASS_DARK if _hash(s, 77) < 0.3 else GRASS,
          lambda f, c, r: SHAFT if c == 0 else GRASS_DARK,
          top_col=lambda: GRASS)


def layer_z(name):
    z = 0.0
    for n, h, _ in LAYERS:
        if n == name:
            return z, h
        z += h
    raise KeyError(name)


def in_cut(angle_deg):
    return 215.0 < angle_deg % 360.0 < 325.0


def on_side(name, angle_deg, z, r_off=0.0):
    assert not in_cut(angle_deg), "%s decoration at %.0f deg would float in the cut" % (name, angle_deg)
    a = math.radians(angle_deg)
    return (math.cos(a) * (R + r_off), math.sin(a) * (R + r_off), z), a


def cut_point(face, u, z, off=0.012):
    """A point on cut face 0 (at -45 deg) or 1 (at 225 deg), u = 0..1 from the axis, nudged out."""
    a = NOTCH[face]
    n = a - math.pi / 2 if face == 0 else a + math.pi / 2    # outward normal of that face (into the notch)
    return (math.cos(a) * R * u + math.cos(n) * off, math.sin(a) * R * u + math.sin(n) * off, z), n


def underground_bits():
    # Crystals poke out of the Crystal layer all round, and a few up through the Ice.
    z0, h = layer_z("crystal")
    ramp = LAYERS[1][2]
    for k in range(9):
        ang = -30 + k * 30 + (_hash(k, 3) - 0.5) * 12
        at, a = on_side("crystal", ang, z0 + h * (0.35 + 0.4 * _hash(k, 4)), -0.02)
        g = gem("Crystal%d" % k, 0.04 + 0.012 * _hash(k, 5), 0.065, ramp[3] if k % 2 else ramp[2])
        place(g, at, (0, math.radians(60 + 20 * _hash(k, 6)), a))
    z0, h = layer_z("ice")
    for k in range(5):
        at, a = on_side("ice", -10 + k * 55, z0 + h * 0.5, -0.01)
        b = ico("IceLump%d" % k, 0.035, 1, LAYERS[2][2][3], smooth=False)
        place(b, at, scale=(1.2, 1.2, 0.8))
    # Gold nuggets in the Stone layer, pebbles in the Topsoil.
    z0, h = layer_z("stone")
    for k in range(6):
        at, a = on_side("stone", 20 + k * 38, z0 + h * (0.3 + 0.4 * _hash(k, 8)), -0.012)
        place(ico("Gold%d" % k, 0.024, 1, GOLD, smooth=False), at)
    z0, h = layer_z("topsoil")
    for k in range(7):
        at, a = on_side("topsoil", -20 + k * 36, z0 + h * (0.25 + 0.5 * _hash(k, 9)), -0.01)
        place(sphere("Pebble%d" % k, 0.022, 6, 4, ROCK), at, scale=(1.3, 1.3, 0.8))

    # In the cut: the fossil in the Clay, the egg in its pocket, gems on the Crystal face.
    z0, h = layer_z("clay")
    at, n = cut_point(0, 0.55, z0 + h * 0.55)
    f = torus("Fossil", 0.04, 0.014, CREAM, 12, 5)
    place(f, at, (math.pi / 2, 0, n + math.pi / 2), (1, 1, 0.7))
    f2 = sphere("FossilCore", 0.022, 8, 5, CREAM)
    place(f2, at, scale=(1, 1, 1))
    z0, h = layer_z("bottom")
    at, n = cut_point(0, 0.33, z0 + h * 0.5 + 0.035, off=0.04)
    egg = sphere("DragonEgg", 0.045, 10, 7, lambda i, p: GOLD if (int((p.z + 0.05) * 60) % 3 == 0) else PINK)
    place(egg, at, scale=(1, 1, 1.25))
    z0, h = layer_z("crystal")
    for k, u in enumerate((0.45, 0.75)):
        at, n = cut_point(1, u, z0 + h * (0.4 + 0.2 * k), off=0.0)
        g = gem("CutGem%d" % k, 0.03, 0.05, LAYERS[1][2][3])
        place(g, at, (0, math.radians(70), n))


def shaft_and_headframe():
    # The elevator cage in the cut shaft, hanging from the headframe's wheel.
    cz = layer_z("stone")[0] + 0.1
    cage_at = (0.0, -0.055, cz)
    cage = rbox("Cage", (0.08, 0.08, 0.1), METAL, 0.008)
    place(cage, cage_at)
    floor = rbox("CageFloor", (0.09, 0.09, 0.014), WOOD_DARK, 0.004)
    place(floor, (cage_at[0], cage_at[1], cz - 0.05))
    roofc = rbox("CageRoof", (0.09, 0.09, 0.014), VEH, 0.004)
    place(roofc, (cage_at[0], cage_at[1], cz + 0.055))
    hf_h = 0.42
    top_z = TOP + GRASS_H
    cable_len = top_z + hf_h - 0.03 - (cz + 0.06)
    cable = cylinder("Cable", 0.005, 0.005, cable_len, 5, SHAFT)
    place(cable, (0.0, -0.055, cz + 0.06 + cable_len / 2))
    # The headframe: a lattice tower over the shaft mouth (Hillville's tower), wheel and cap on top.
    base, tip = 0.13, 0.075
    for sx in (-1, 1):
        for sy in (-1, 1):
            p0 = Vector((sx * base, sy * base + 0.03, top_z))
            p1 = Vector((sx * tip, sy * tip + 0.03, top_z + hf_h))
            d = p1 - p0
            leg = rbox("Leg", (0.022, 0.022, d.length), WOOD, 0.004)
            leg.rotation_mode = "QUATERNION"
            leg.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
            leg.location = (p0 + p1) / 2
    for k, zf in enumerate((0.3, 0.62)):
        w = base + (tip - base) * zf
        for side in range(4):
            a = side * math.pi / 2
            bar = rbox("Brace", (2 * w + 0.02, 0.014, 0.014), WOOD_DARK, 0.003)
            place(bar, (math.sin(a) * w, -math.cos(a) * w + 0.03, top_z + hf_h * zf), (0, 0, a))
    deck = rbox("Deck", (0.2, 0.2, 0.02), WOOD_DARK, 0.005)
    place(deck, (0, 0.03, top_z + hf_h))
    wheel = torus("Wheel", 0.055, 0.012, METAL, 16, 5)
    place(wheel, (0, 0.03, top_z + hf_h + 0.07), (math.pi / 2, 0, 0))
    hub = cylinder("WheelHub", 0.018, 0.018, 0.03, 8, WOOD_DARK)
    place(hub, (0, 0.03, top_z + hf_h + 0.07), (math.pi / 2, 0, 0))
    cap = cylinder("Cap", 0.13, 0.02, 0.06, 4, ROOF)
    place(cap, (0, 0.03, top_z + hf_h + 0.16), (0, 0, math.pi / 4))
    lamp = ico("Lamp", 0.018, 1, GOLD)
    place(lamp, (0.09, -0.06, top_z + hf_h - 0.03))
    # The shaft mouth on the grass, behind the cut corner.
    mouth = rbox("Mouth", (0.13, 0.13, 0.006), SHAFT, 0.0)
    place(mouth, (0, 0.035, top_z + 0.003), (0, 0, math.pi / 4))
    for k, (dx, dy) in enumerate([(-0.11, 0.1), (0.11, 0.1), (0.13, -0.07), (-0.13, -0.07)]):
        post = rbox("Post%d" % k, (0.02, 0.02, 0.05), WOOD_DARK, 0.004)
        place(post, (dx, dy + 0.035, top_z + 0.025))


def mound():
    top_z = TOP + GRASS_H
    m = sphere("Hill", 0.34, 16, 8, lambda i, p: HILL if p.z > 0.15 else GRASS)
    place(m, (0.12, 0.3, top_z - 0.05), scale=(1.0, 0.75, 0.62))
    peak = (0.12, 0.33, top_z - 0.05 + 0.34 * 0.62)
    # The Lighthouse on the peak: cream and blue bands, a gold lamp, a blue cap.
    lh_h = 0.26
    bands = cylinder("Lighthouse", 0.055, 0.04, lh_h, 10, lambda i, p: ROOF if int((p.z + lh_h / 2) / (lh_h / 4)) % 2 else WALL)
    place(bands, (peak[0], peak[1], peak[2] + lh_h / 2 - 0.02))
    gallery = cylinder("Gallery", 0.055, 0.055, 0.015, 10, WOOD_DARK)
    place(gallery, (peak[0], peak[1], peak[2] + lh_h - 0.015))
    lamp = cylinder("LampRoom", 0.035, 0.035, 0.05, 8, GOLD)
    place(lamp, (peak[0], peak[1], peak[2] + lh_h + 0.02))
    roof = cylinder("LampCap", 0.05, 0.005, 0.05, 8, ROOF)
    place(roof, (peak[0], peak[1], peak[2] + lh_h + 0.07))


def barn(at, yaw):
    x, y, z = at
    g = []
    body = rbox("Barn", (0.2, 0.15, 0.12), BARN, 0.008)
    g.append(place(body, (x, y, z + 0.06)))
    roof = rbox("BarnRoof", (0.22, 0.12, 0.12), WOOD_DARK, 0.008)
    g.append(place(roof, (x, y, z + 0.12), (math.pi / 4, 0, 0), (1, 0.9, 0.9)))
    for side in (-1, 1):
        door = rbox("BarnDoor", (0.075, 0.006, 0.08), WALL, 0.0)
        g.append(place(door, (x, y + side * 0.077, z + 0.045)))
        inner = rbox("BarnDoorIn", (0.06, 0.008, 0.065), BARN, 0.0)
        g.append(place(inner, (x, y + side * 0.078, z + 0.045)))
        for d in (-1, 1):
            bar = rbox("BarnX", (0.085, 0.009, 0.01), WALL, 0.0)
            g.append(place(bar, (x, y + side * 0.08, z + 0.045), (0, d * 0.82, 0)))
        loft = rbox("Loft", (0.04, 0.006, 0.03), WALL, 0.0)
        g.append(place(loft, (x, y + side * 0.077, z + 0.13)))
    turn(g, at, yaw, 1.25)


def loader(at, yaw):
    """The Front Loader, yellow, no face: body, cab with glass, four fat tyres, a bucket on arms."""
    x, y, z = at
    g = []
    g.append(place(rbox("LoaderBody", (0.16, 0.09, 0.06), VEH, 0.012, 2), (x, y, z + 0.075)))
    g.append(place(rbox("LoaderCab", (0.08, 0.08, 0.075), VEH_DARK, 0.01, 2), (x - 0.025, y, z + 0.14)))
    for side in (-1, 1):
        g.append(place(rbox("LoaderGlass", (0.055, 0.004, 0.045), GLASS, 0.0), (x - 0.025, y + side * 0.041, z + 0.145)))
    g.append(place(rbox("LoaderGlassF", (0.004, 0.06, 0.045), GLASS, 0.0), (x + 0.0155, y, z + 0.145)))
    g.append(place(rbox("LoaderRoof", (0.09, 0.09, 0.012), VEH, 0.004), (x - 0.025, y, z + 0.183)))
    for dx in (-0.05, 0.055):
        for side in (-1, 1):
            t = cylinder("Tyre", 0.04, 0.04, 0.03, 12, TYRE, smooth=True)
            g.append(place(t, (x + dx, y + side * 0.055, z + 0.04), (math.pi / 2, 0, 0)))
            h = cylinder("Rim", 0.018, 0.018, 0.032, 8, METAL)
            g.append(place(h, (x + dx, y + side * 0.055, z + 0.04), (math.pi / 2, 0, 0)))
    for side in (-1, 1):
        arm = rbox("Arm", (0.11, 0.012, 0.016), VEH_DARK, 0.003)
        g.append(place(arm, (x + 0.1, y + side * 0.04, z + 0.08), (0, 0.45, 0)))
    bucket = rbox("Bucket", (0.05, 0.13, 0.05), METAL, 0.01)
    g.append(place(bucket, (x + 0.16, y, z + 0.035), (0, -0.25, 0)))
    for k, c in enumerate((LAYERS[4][2][2], LAYERS[3][2][2])):
        b = rbox("Load%d" % k, (0.03, 0.03, 0.03), c, 0.004)
        g.append(place(b, (x + 0.16, y - 0.025 + k * 0.045, z + 0.07), (0, 0, 0.3 * k)))
    turn(g, at, yaw, 1.45)


def turn(objs, at, yaw, size=1.0):
    """Grows a group of parts by `size` about `at`, then spins it about the vertical through `at`."""
    c = Vector(at)
    for o in objs:
        o.scale = Vector(o.scale) * size
        p = (Vector(o.location) - c) * size
        o.location = c + Vector((p.x * math.cos(yaw) - p.y * math.sin(yaw), p.x * math.sin(yaw) + p.y * math.cos(yaw), p.z))
        if o.rotation_mode == "QUATERNION":
            continue
        e = o.rotation_euler.copy()
        o.rotation_mode = "XYZ"
        mat = e.to_matrix()
        from mathutils import Matrix
        o.rotation_euler = (Matrix.Rotation(yaw, 3, "Z") @ mat).to_euler()


def tree(at, s, colour):
    trunk = cylinder("Trunk", 0.014 * s, 0.012 * s, 0.07 * s, 6, WOOD)
    place(trunk, (at[0], at[1], at[2] + 0.035 * s))
    leaf = ico("Leaf", 0.06 * s, 1, colour)
    place(leaf, (at[0], at[1], at[2] + 0.1 * s), scale=(1, 1, 1.1))


def block_pile(at):
    x, y, z = at
    cols = [LAYERS[5][2][2], LAYERS[4][2][2], LAYERS[3][2][2], LAYERS[2][2][2], LAYERS[1][2][2], LAYERS[4][2][3]]
    spots = [(-0.03, -0.03, 0), (0.03, -0.03, 0), (-0.03, 0.03, 0), (0.03, 0.03, 0), (0.0, 0.0, 1), (0.0, 0.03, 1)]
    for k, (dx, dy, lv) in enumerate(spots[:5]):
        b = rbox("Block%d" % k, (0.05, 0.05, 0.05), cols[k], 0.006)
        place(b, (x + dx, y + dy, z + 0.025 + lv * 0.05), (0, 0, 0.15 * k))


def surface():
    top_z = TOP + GRASS_H
    mound()
    barn((-0.34, 0.16, top_z), math.radians(-25))
    loader((0.36, -0.08, top_z), math.radians(200))
    block_pile((0.2, 0.16, top_z))
    for k, (ang, r, s) in enumerate([(100, 0.52, 1.0), (140, 0.5, 1.2), (60, 0.55, 0.9), (180, 0.5, 0.9), (20, 0.52, 1.1), (-25, 0.5, 0.85)]):
        a = math.radians(ang)
        tree((math.cos(a) * r, math.sin(a) * r, top_z if ang not in (60, 100) else top_z + 0.03), s, LEAF if k % 2 else LEAF2)
    for k in range(6):
        a = math.radians(-30 + k * 42)
        f = sphere("Flower%d" % k, 0.012, 6, 4, PINK if k % 2 else GOLD)
        place(f, (math.cos(a) * 0.58, math.sin(a) * 0.58, top_z + 0.008))


def main():
    reset()
    plug()
    underground_bits()
    shaft_and_headframe()
    surface()
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not o.data.materials:
            o.data.materials.append(palette_material())
    bake_palette()
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print("make_jar: %d triangles, %d palette colours" % (tris, len(PALETTE)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True,
                              export_vertex_color="NONE",
                              export_animations=False, export_lights=False, export_cameras=False,
                              export_image_format="AUTO")
    print("make_jar: wrote", OUT)


main()
