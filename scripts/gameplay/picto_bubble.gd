## Picture speech bubbles for the residents' arcs: no words, no numbers. A bubble is a rounded
## white panel with a tail pointing down at the speaker, holding a row of pictures; the last one is
## usually a face. Pure draw helpers (call from a CanvasItem's _draw()); the scene that shows one
## in the world, following a speaker, is `scenes/ui/picto_bubble.tscn` (PictoBubbleNode).
## Costs and prompts: draw_cost() (one square per block, no numbers) and draw_round() (a round
## "this opens it / you get this" bubble) are what the build book's cards use.
##   PictoBubble.draw(self, mouth, [&"shovel", &"face_sheepish"], alpha)
## Pictures: &"shovel", &"wall" (a brick wall with hats peeking over), &"ice" (an ice cube),
## &"shaken_hill" (a hill with wobble lines), &"heart", &"house", &"star", &"question",
## &"face_sheepish", &"face_hopeful", &"face_happy", and &"ruin:<building id>" /
## &"home:<building id>": that building's sprite, scaled to fit.
## Story lane: &"deed" (a rolled scroll with a seal and a little hill), &"shaft" (the head-frame),
## &"tree", &"rock", &"exclaim", &"zzz", &"sparkle", &"hardhat", &"vehicle:<id>" (its sprite).
class_name PictoBubble
extends RefCounted

const CELL := 22.0
const PAD := 4.0
const OUTLINE := Color("3a2a44")
const PAPER := Color("fffaf0")
const SKIN := Color("ffd9a8")
const GOLD := Color("ffd23f")
const PINK := Color("ff8fb1")


## Size of a bubble with n pictures (without the tail), at scale k.
static func size_for(n: int, k := 1.0) -> Vector2:
	return Vector2(n * CELL + (n + 1) * PAD, CELL + 2 * PAD) * k


## Draws the bubble whose tail tip is at `tip` (the speaker's head), pictures left to right.
## `pop` 0..1 scales it in (0.6 -> 1 with a little overshoot handled by the caller's curve).
static func draw(ci: CanvasItem, tip: Vector2, pics: Array, alpha := 1.0, k := 1.0) -> void:
	if alpha <= 0.01 or pics.is_empty():
		return
	var sz := size_for(pics.size(), k)
	var r := Rect2(tip + Vector2(-sz.x * 0.5, -sz.y - 7.0 * k), sz)
	var ol := Color(OUTLINE, alpha)
	var paper := Color(PAPER, alpha)
	var tail := PackedVector2Array([tip, tip + Vector2(-5, -8) * k, tip + Vector2(5, -8) * k])
	_round_rect(ci, r.grow(1.5 * k), 5.0 * k, ol)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 1.5) * k, tip + Vector2(-7, -8.5) * k, tip + Vector2(7, -8.5) * k]), ol)
	_round_rect(ci, r, 4.0 * k, paper)
	ci.draw_colored_polygon(tail, paper)
	for i in pics.size():
		var c := r.position + Vector2(PAD + i * (CELL + PAD) + CELL * 0.5, PAD + CELL * 0.5) * k
		picture(ci, StringName(str(pics[i])), c, CELL * k, alpha)


static func _round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - 2 * rad, r.size.y), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - 2 * rad), col)
	for p in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.position.x + rad, r.end.y - rad), r.end - Vector2(rad, rad)]:
		ci.draw_circle(p, rad, col)


## One picture centred at c, fitting a box of side s.
static func picture(ci: CanvasItem, id: StringName, c: Vector2, s: float, a := 1.0) -> void:
	var u := s / 22.0
	var ol := Color(OUTLINE, a)
	var sid := String(id)
	if sid.begins_with("ruin:") or sid.begins_with("home:"):
		_building(ci, StringName(sid.get_slice(":", 1)), c, s, a)
		return
	if sid.begins_with("vehicle:"):
		_sprite(ci, "vehicles/%s.png" % sid.get_slice(":", 1), c, s, a)
		return
	match id:
		&"shovel":
			# Handle up-right, blade down-left.
			ci.draw_line(c + Vector2(7, -9) * u, c + Vector2(-2, 2) * u, ol, 4.0 * u)
			ci.draw_line(c + Vector2(7, -9) * u, c + Vector2(-2, 2) * u, Color("a47148", a), 2.0 * u)
			ci.draw_line(c + Vector2(5, -10) * u, c + Vector2(9, -7) * u, ol, 3.0 * u)
			var blade := PackedVector2Array([c + Vector2(-1, 0) * u, c + Vector2(-8, 4) * u, c + Vector2(-8, 9) * u, c + Vector2(-3, 9) * u, c + Vector2(2, 3) * u])
			ci.draw_colored_polygon(blade, Color("b8c4cc", a))
			ci.draw_polyline(_loop(blade), ol, 1.2 * u)
		&"wall":
			for row in 3:
				for col in 3:
					var off := 3.0 * u if row % 2 == 1 else 0.0
					var br := Rect2(c + Vector2(-10 + col * 7 - off, -1 + row * 4) * u, Vector2(6.5, 3.5) * u)
					ci.draw_rect(br, Color("b5654a", a))
					ci.draw_rect(br, ol, false, 0.8 * u)
			# Three little hard hats peeking over.
			for hx in [-6.0, 0.0, 6.0]:
				var hc := c + Vector2(hx, -3) * u
				ci.draw_circle(hc, 2.8 * u, Color(GOLD, a))
				ci.draw_rect(Rect2(hc + Vector2(-3.6, 0) * u, Vector2(7.2, 1.4) * u), Color(GOLD, a))
				ci.draw_arc(hc, 2.8 * u, PI, TAU, 8, ol, 0.8 * u)
		&"ice":
			var box := Rect2(c - Vector2(8, 8) * u, Vector2(16, 16) * u)
			ci.draw_rect(box, Color(0.72, 0.9, 1.0, a))
			ci.draw_rect(box, ol, false, 1.2 * u)
			ci.draw_line(c + Vector2(-5, -5) * u, c + Vector2(-1, -5) * u, Color(1, 1, 1, a), 1.5 * u)
			# Someone small inside.
			ci.draw_circle(c + Vector2(0, -1) * u, 3.0 * u, Color(SKIN, a * 0.8))
			ci.draw_rect(Rect2(c + Vector2(-3, 2) * u, Vector2(6, 5) * u), Color(Color("8a5a3c"), a * 0.8))
		&"shaken_hill":
			var hill := PackedVector2Array([c + Vector2(-10, 8) * u, c + Vector2(-4, -4) * u, c + Vector2(0, -7) * u, c + Vector2(5, -3) * u, c + Vector2(10, 8) * u])
			ci.draw_colored_polygon(hill, Color("6dbb4a", a))
			ci.draw_polyline(_loop(hill), ol, 1.2 * u)
			for side in [-1.0, 1.0]:
				for k in 2:
					var x: float = side * (12.0 + k * 3.0)
					ci.draw_line(c + Vector2(x, -4 + k * 2) * u, c + Vector2(x, 4 + k * 2) * u, ol, 1.2 * u)
		&"heart":
			ci.draw_circle(c + Vector2(-3.5, -2) * u, 4.5 * u, Color(PINK, a))
			ci.draw_circle(c + Vector2(3.5, -2) * u, 4.5 * u, Color(PINK, a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -0.5) * u, c + Vector2(8, -0.5) * u, c + Vector2(0, 8) * u]), Color(PINK, a))
		&"house":
			ci.draw_rect(Rect2(c + Vector2(-7, -1) * u, Vector2(14, 9) * u), Color("f2d7a0", a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1) * u, c + Vector2(0, -9) * u, c + Vector2(9, -1) * u]), Color("c8372d", a))
			ci.draw_rect(Rect2(c + Vector2(-2, 2) * u, Vector2(4, 6) * u), Color("8a5a2b", a))
		&"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := (9.0 if i % 2 == 0 else 4.0) * u
				pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * rr)
			ci.draw_colored_polygon(pts, Color(GOLD, a))
			ci.draw_polyline(_loop(pts), ol, 1.0 * u)
		&"question":
			ci.draw_arc(c + Vector2(0, -3) * u, 5.0 * u, PI * 1.05, TAU + PI * 0.45, 10, ol, 3.0 * u)
			ci.draw_line(c + Vector2(1.5, 1.5) * u, c + Vector2(0, 4) * u, ol, 3.0 * u)
			ci.draw_circle(c + Vector2(0, 8) * u, 1.8 * u, ol)
		&"face_sheepish", &"face_hopeful", &"face_happy":
			_face(ci, id, c, u, a)
		&"deed":
			# A cream scroll, rolled at both ends, a little green hill on it and a red seal.
			var paper := Color("f6e7c1", a)
			ci.draw_rect(Rect2(c + Vector2(-8, -6) * u, Vector2(16, 12) * u), paper)
			for ex in [-9.0, 9.0]:
				ci.draw_circle(c + Vector2(ex, -6) * u, 2.2 * u, Color("e0c98f", a))
				ci.draw_circle(c + Vector2(ex, 6) * u, 2.2 * u, Color("e0c98f", a))
				ci.draw_rect(Rect2(c + Vector2(ex - 2.2, -6) * u, Vector2(4.4, 12) * u), Color("e0c98f", a))
			ci.draw_rect(Rect2(c + Vector2(-11.2, -8.2) * u, Vector2(22.4, 16.4) * u), ol, false, 1.0 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 3) * u, c + Vector2(-1, -3) * u, c + Vector2(2, -1) * u, c + Vector2(6, 3) * u]), Color("6dbb4a", a))
			ci.draw_circle(c + Vector2(5, 5) * u, 2.6 * u, Color("c8372d", a))
		&"shaft":
			# The mine head-frame: two legs, a cross beam, a wheel on top, a dark hole below.
			var wood := Color("8a5a2b", a)
			ci.draw_rect(Rect2(c + Vector2(-7, 6) * u, Vector2(14, 4) * u), Color("2a1d18", a))
			ci.draw_line(c + Vector2(-7, 7) * u, c + Vector2(-3, -6) * u, wood, 2.2 * u)
			ci.draw_line(c + Vector2(7, 7) * u, c + Vector2(3, -6) * u, wood, 2.2 * u)
			ci.draw_line(c + Vector2(-5, 1) * u, c + Vector2(5, 1) * u, wood, 1.8 * u)
			ci.draw_circle(c + Vector2(0, -7) * u, 3.6 * u, ol)
			ci.draw_circle(c + Vector2(0, -7) * u, 2.4 * u, Color("b8c4cc", a))
			ci.draw_line(c + Vector2(0, -7) * u, c + Vector2(0, 7) * u, ol, 0.8 * u)
		&"tree":
			ci.draw_rect(Rect2(c + Vector2(-1.5, 2) * u, Vector2(3, 7) * u), Color("8a5a2b", a))
			ci.draw_circle(c + Vector2(0, -3) * u, 7.0 * u, ol)
			ci.draw_circle(c + Vector2(0, -3) * u, 6.0 * u, Color("4f9e3a", a))
			ci.draw_circle(c + Vector2(-2, -5) * u, 2.0 * u, Color("6dbb4a", a))
		&"rock":
			var rk := PackedVector2Array([c + Vector2(-8, 7) * u, c + Vector2(-6, -2) * u, c + Vector2(-1, -6) * u, c + Vector2(6, -3) * u, c + Vector2(8, 7) * u])
			ci.draw_colored_polygon(rk, Color("9aa3a8", a))
			ci.draw_polyline(_loop(rk), ol, 1.2 * u)
			ci.draw_line(c + Vector2(-3, -2) * u, c + Vector2(-1, -4) * u, Color(1, 1, 1, a * 0.7), 1.2 * u)
		&"exclaim":
			ci.draw_line(c + Vector2(0, -9) * u, c + Vector2(0, 3) * u, Color("e4393c", a), 4.0 * u)
			ci.draw_circle(c + Vector2(0, 8) * u, 2.2 * u, Color("e4393c", a))
		&"zzz":
			for i in 3:
				var o := c + Vector2(-6 + i * 5, 5 - i * 5) * u
				var zs := (3.0 + i) * u
				ci.draw_polyline(PackedVector2Array([o + Vector2(-zs, -zs), o + Vector2(zs, -zs), o + Vector2(-zs, zs), o + Vector2(zs, zs)]), ol, 1.4 * u)
		&"sparkle":
			for i in 3:
				var spots: Array[Vector2] = [Vector2(-4, -3), Vector2(5, -5), Vector2(2, 6)]
				var sizes: Array[float] = [5.0, 3.5, 3.0]
				var o: Vector2 = c + spots[i] * u
				var r: float = sizes[i] * u
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r), o + Vector2(r * 0.3, 0), o + Vector2(0, r), o + Vector2(-r * 0.3, 0)]), Color(GOLD, a))
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-r, 0), o + Vector2(0, r * 0.3), o + Vector2(r, 0), o + Vector2(0, -r * 0.3)]), Color(GOLD, a))
		&"hardhat":
			ci.draw_circle(c + Vector2(0, 2) * u, 7.0 * u, Color(GOLD, a))
			ci.draw_rect(Rect2(c + Vector2(-10, 2) * u, Vector2(20, 3) * u), Color(GOLD, a))
			ci.draw_rect(Rect2(c + Vector2(-10, 2) * u, Vector2(20, 3) * u), ol, false, 0.9 * u)
			ci.draw_arc(c + Vector2(0, 2) * u, 7.0 * u, PI, TAU, 12, ol, 1.0 * u)
			ci.draw_rect(Rect2(c + Vector2(-1, -5) * u, Vector2(2, 7) * u), Color(Color("e0b020"), a))
		_:
			ci.draw_circle(c, 6.0 * u, Color(GOLD, a))


static func _face(ci: CanvasItem, id: StringName, c: Vector2, u: float, a: float) -> void:
	var ol := Color(OUTLINE, a)
	ci.draw_circle(c, 9.5 * u, ol)
	ci.draw_circle(c, 8.5 * u, Color(Color("ffe27a"), a))
	match id:
		&"face_sheepish":
			# Eyes looking aside, a wobbly little mouth, one sweat drop. Funny-sad, never crying.
			ci.draw_circle(c + Vector2(-2, -2) * u, 1.3 * u, ol)
			ci.draw_circle(c + Vector2(3.5, -2) * u, 1.3 * u, ol)
			var m := PackedVector2Array()
			for i in 6:
				m.append(c + Vector2(-3.5 + i * 1.4, 4.0 + (0.8 if i % 2 == 0 else -0.8)) * u)
			ci.draw_polyline(m, ol, 1.2 * u)
			ci.draw_circle(c + Vector2(7, -5) * u, 1.6 * u, Color(0.55, 0.8, 1.0, a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(5.6, -5.4) * u, c + Vector2(8.4, -5.4) * u, c + Vector2(7, -8.5) * u]), Color(0.55, 0.8, 1.0, a))
		&"face_hopeful":
			# Big round eyes with a shine, a small open smile, brows up.
			for ex in [-3.2, 3.2]:
				ci.draw_circle(c + Vector2(ex, -1.5) * u, 2.0 * u, ol)
				ci.draw_circle(c + Vector2(ex + 0.6, -2.2) * u, 0.7 * u, Color(1, 1, 1, a))
				ci.draw_line(c + Vector2(ex - 1.8, -5.5) * u, c + Vector2(ex + 1.8, -6.2) * u, ol, 1.0 * u)
			ci.draw_arc(c + Vector2(0, 2.5) * u, 2.6 * u, 0.15, PI - 0.15, 8, ol, 1.3 * u)
		_:
			ci.draw_arc(c + Vector2(-3, -1.5) * u, 1.6 * u, PI, TAU, 6, ol, 1.2 * u)
			ci.draw_arc(c + Vector2(3, -1.5) * u, 1.6 * u, PI, TAU, 6, ol, 1.2 * u)
			ci.draw_arc(c + Vector2(0, 1.5) * u, 4.5 * u, 0.2, PI - 0.2, 10, ol, 1.6 * u)


static func _building(ci: CanvasItem, id: StringName, c: Vector2, s: float, a: float) -> void:
	var file := "buildings/%s.png" % id
	var tex := SpriteArt.texture(file)
	if tex == null:
		picture(ci, &"house", c, s, a)
		return
	var fs := SpriteArt.frame_size(file)
	if fs == Vector2.ZERO:
		fs = Vector2(tex.get_size())
	var k := minf(s / fs.x, s / fs.y)
	var sz := fs * k
	ci.draw_texture_rect_region(tex, Rect2(c - sz * 0.5, sz), Rect2(Vector2.ZERO, fs), Color(1, 1, 1, a))


## First frame of any sheet under assets/sprites/, scaled to fit the box.
static func _sprite(ci: CanvasItem, file: String, c: Vector2, s: float, a: float) -> void:
	var tex := SpriteArt.texture(file)
	if tex == null:
		picture(ci, &"star", c, s, a)
		return
	var fs := SpriteArt.frame_size(file)
	if fs == Vector2.ZERO:
		fs = Vector2(tex.get_size())
	var k := minf(s / fs.x, s / fs.y)
	var sz := fs * k
	ci.draw_texture_rect_region(tex, Rect2(c - sz * 0.5, sz), Rect2(Vector2.ZERO, fs), Color(1, 1, 1, a))


static func _loop(p: PackedVector2Array) -> PackedVector2Array:
	var l := p.duplicate()
	l.append(p[0])
	return l


# --- costs and prompt bubbles (build book cards; reused by any card or prompt) ------------------

## A round picture bubble at c (a prompt: "this opens it", "you get this"); `ask` adds a gold
## ring (something to find or get first). Draw the picture inside it after.
static func draw_round(ci: CanvasItem, c: Vector2, rad: float, ask := false, k := 1.0) -> void:
	ci.draw_circle(c, rad + 3.0 * k, Color(0.07, 0.06, 0.09))
	ci.draw_circle(c, rad, Color("fff6dc"))
	if ask:
		ci.draw_arc(c, rad - 2.0 * k, 0.0, TAU, 32, GOLD, maxf(2.0, 4.0 * k))


## A cost as columns of squares: one square per block, columns of `per` from the bottom, one block
## type after another (`order` first, then any others). Returns [[block id, count in column], ...].
static func cost_columns(cost: Dictionary, order: Array = [], per := 5) -> Array:
	var keys: Array = []
	for b in order:
		if cost.has(b) or cost.has(String(b)):
			keys.append(StringName(str(b)))
	for b in cost:
		if not keys.has(StringName(str(b))):
			keys.append(StringName(str(b)))
	var cols: Array = []
	for b in keys:
		var left := int(cost.get(b, cost.get(String(b), 0)))
		while left > 0:
			cols.append([b, mini(per, left)])
			left -= per
	return cols


## Draws a cost (no numbers: one square per block) centred in `area`. `color_of(block id) -> Color`;
## `dim` greys it (can't afford). Squares shrink to fit the area.
static func draw_cost(ci: CanvasItem, area: Rect2, cost: Dictionary, color_of: Callable, dim := false,
		order: Array = [], sq := 20.0, k := 1.0, per := 5) -> void:
	var cols := cost_columns(cost, order, per)
	if cols.is_empty():
		return
	var s := sq * k
	var step := s + 4 * k
	var fit := minf(1.0, minf(area.size.x / maxf(cols.size() * step, 1.0), area.size.y / (per * step)))
	s *= fit
	step *= fit
	var total_w := cols.size() * step - (step - s)
	var x := area.get_center().x - total_w * 0.5
	var base := area.get_center().y + per * 0.5 * step
	for c in cols:
		for i in c[1]:
			var sr := Rect2(x, base - (i + 1) * step, s, s)
			var col: Color = color_of.call(c[0])
			if dim:
				var l := col.get_luminance()
				col = Color(l, l, l).darkened(0.35)
			ci.draw_rect(sr, col)
			ci.draw_rect(sr, Color(0.05, 0.04, 0.04), false, maxf(1.5, 2.5 * k))
		x += step
