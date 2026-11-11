## Each layer's own life, drawn in the TileWorld (world px), pictures only: no collision change,
## no text.
## - W-03 Topsoil: roots hang from dirt ceilings (a few per screen, seeded by cell, they sway a
##   little), and worms live in some dirt cells. When a player stands next to a worm's cell and
##   it has an open side, the worm pops out of the wall (`pop`), waves, then ducks back in and
##   rests a while before it will wave again.
## - W-11 Ice: snow drifts on top of every ice rink's floor (deeper against the far wall), and a
##   frozen fish in one floor block per rink (HillGenerator.fish_cells). Underground digs the fish
##   out: the first one is the treasure; later ones wiggle free here (free_fish) and swim off.
class_name DepthLife
extends Node2D

const CELL := 16.0
## Roughly one dirt ceiling in ROOT_EVERY grows a root; one dirt cell in WORM_EVERY has a worm.
const ROOT_EVERY := 5
const WORM_EVERY := 7
## A worm wakes when a player's body is this close to the face it pops out of.
const NEAR_PX := 40.0
const EMERGE := 0.3
const WAVE := 2.4
const DUCK := 0.3
const REST := 5.0
## Leaving for this long during the wave ducks the worm early.
const LEAVE := 0.6
const FISH_FREE_TIME := 1.6

const OUTLINE := Color("3a2a44")
const ROOT := Color("c99a62")
const ROOT_DARK := Color("7a5233")
const WORM := Color("f59ac0")
const WORM_RING := Color("d9739e")
const WORM_CHEEK := Color("ff7fa8")
const SNOW := Color(0.94, 0.97, 1.0)
const SNOW_SHADE := Color(0.76, 0.87, 1.0)
const ICE_GLAZE := Color(0.85, 0.95, 1.0, 0.3)

enum Phase { OUT, WAVE, IN, REST }

var u: Underground
## Dirt ceiling cell -> its root's seed (only the cells drawn now).
var roots: Dictionary = {}
## Worm cell -> {phase, t, dir (+1 pops out to the right), away}
var worms: Dictionary = {}
var _fish_free: Array = []          # [{pos: Vector2, t: float, dir: int}]
var _t := 0.0
var _dirt := -1
var _ice := -1
var _top_to := 0                    # Topsoil's last row + 1
var _fish_tex: Texture2D


func setup(p_u: Underground) -> void:
	u = p_u
	name = "DepthLife"
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fish_tex = SpriteArt.texture("treasures/%s.png" % HillGenerator.FISH)
	for i in u.world.palette.size():
		match u.world.palette[i].id:
			&"dirt": _dirt = i
			&"ice": _ice = i
	var ls := u.layers()
	_top_to = (ls[0] as LayerData).depth_to if not ls.is_empty() else 0
	for y in range(1, _top_to):
		for x in HillGenerator.WIDTH:
			_check_root(Vector2i(x, y))
	u.world.tile_dug.connect(_on_tile_dug)


# --- queries (tests, beats) -------------------------------------------------------------------

## True when `cell` is a worm's home (whether or not it is out now).
func is_worm_home(cell: Vector2i) -> bool:
	if cell.y < 1 or cell.y >= _top_to or u.generator.is_edge(cell):
		return false
	if _landing_walls().has(cell):
		return true
	return _hash(cell, 31) % WORM_EVERY == 0


## Two roots always hang from the Topsoil landing room's ceiling (the first thing he sees).
func _landing_roots() -> Array[Vector2i]:
	if u.generator.landings.is_empty():
		return []
	var r: Rect2i = u.generator.landings[0]
	return [Vector2i(r.position.x + 2, r.position.y - 1), Vector2i(r.end.x - 4, r.position.y - 1)]


## The worm homes in the Topsoil landing room's two side walls (a worm to meet on arrival).
func _landing_walls() -> Array[Vector2i]:
	if u.generator.landings.is_empty():
		return []
	var r: Rect2i = u.generator.landings[0]
	return [Vector2i(r.position.x - 1, r.end.y - 1), Vector2i(r.end.x, r.end.y - 1)]


## The worm in `cell` is out and waving.
func is_waving(cell: Vector2i) -> bool:
	return worms.has(cell) and int(worms[cell].phase) == Phase.WAVE


## How far the worm in `cell` sticks out, 0 (in the dirt) .. 1.
func worm_out(cell: Vector2i) -> float:
	if not worms.has(cell):
		return 0.0
	var w: Dictionary = worms[cell]
	match int(w.phase):
		Phase.OUT:
			return clampf(w.t / EMERGE, 0.0, 1.0)
		Phase.WAVE:
			return 1.0
		Phase.IN:
			return clampf(1.0 - w.t / DUCK, 0.0, 1.0)
	return 0.0


func waving_worms() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in worms:
		if is_waving(c):
			out.append(c)
	return out


## A fish frozen in `cell` still sits in its ice.
func has_fish(cell: Vector2i) -> bool:
	return u.generator.fish_at(cell) >= 0 and u.world.is_solid(cell)


## A later fish (the treasure is already found) wiggles free of `cell` and swims off.
func free_fish(cell: Vector2i) -> void:
	var at := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	_fish_free.append({"pos": at, "t": 0.0, "dir": 1 if _hash(cell, 5) % 2 == 0 else -1})
	Audio.play("splash")
	u.burst(at, Color(0.75, 0.9, 1.0), 14, 120.0)


# --- roots ------------------------------------------------------------------------------------

func _check_root(c: Vector2i) -> void:
	var ok := c.y >= 1 and c.y < _top_to and not u.generator.is_edge(c) \
			and u.world.get_tile(c) == _dirt and not u.world.is_solid(c + Vector2i.DOWN) \
			and (_hash(c, 17) % ROOT_EVERY == 0 or _landing_roots().has(c))
	if ok:
		roots[c] = _hash(c, 3)
	else:
		roots.erase(c)


func _on_tile_dug(cell: Vector2i, _block: StringName, _player: int) -> void:
	_check_root(cell)
	_check_root(cell + Vector2i.UP)
	worms.erase(cell)


# --- worms ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if u == null:
		return
	var bodies: Array[Vector2] = []
	for p in u.hazards.players() if u.hazards != null else []:
		var feet := u.world.to_local(p.global_position)
		if int(feet.y / CELL) < _top_to + 2:
			bodies.append(feet + Vector2(0, -HillPlayer.HEIGHT * 0.5))
	# Wake the worms beside anyone in Topsoil.
	for b in bodies:
		var at := Vector2i((b / CELL).floor())
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				var c := at + Vector2i(dx, dy)
				if worms.has(c) or not is_worm_home(c) or u.world.get_tile(c) != _dirt:
					continue
				var dir := _open_side(c, b)
				if dir != 0 and _face(c, dir).distance_to(b) <= NEAR_PX:
					worms[c] = {"phase": Phase.OUT, "t": 0.0, "dir": dir, "away": 0.0}
					Audio.play("pop")
					u.burst(_face(c, dir), Color("8b5a2b"), 6, 60.0)
	for c in worms.keys():
		var w: Dictionary = worms[c]
		var near := false
		for b in bodies:
			if _face(c, int(w.dir)).distance_to(b) <= NEAR_PX:
				near = true
				break
		if u.world.get_tile(c) != _dirt or u.world.is_solid(c + Vector2i(int(w.dir), 0)):
			worms.erase(c)
			continue
		w.t += delta
		match int(w.phase):
			Phase.OUT:
				if w.t >= EMERGE:
					w.phase = Phase.WAVE
					w.t = 0.0
			Phase.WAVE:
				w.away = 0.0 if near else float(w.away) + delta
				if w.t >= WAVE or w.away >= LEAVE:
					w.phase = Phase.IN
					w.t = 0.0
			Phase.IN:
				if w.t >= DUCK:
					w.phase = Phase.REST
					w.t = 0.0
			Phase.REST:
				if w.t >= REST and not near:
					worms.erase(c)


## +1 / -1: the open side of `c` (the one facing `toward` when both are open), 0 when walled in.
func _open_side(c: Vector2i, toward: Vector2) -> int:
	var r := not u.world.is_solid(c + Vector2i.RIGHT)
	var l := not u.world.is_solid(c + Vector2i.LEFT)
	if r and l:
		return 1 if toward.x >= (c.x + 0.5) * CELL else -1
	return 1 if r else (-1 if l else 0)


## The middle of the wall face a worm in `c` pops out of.
func _face(c: Vector2i, dir: int) -> Vector2:
	return Vector2((c.x + (1.0 if dir > 0 else 0.0)) * CELL, (c.y + 0.6) * CELL)


func _process(delta: float) -> void:
	_t += delta
	for f in _fish_free:
		f.t += delta
	_fish_free = _fish_free.filter(func(f: Dictionary) -> bool: return f.t < FISH_FREE_TIME)
	queue_redraw()


# --- drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	if u == null:
		return
	var view := _view_rect()
	for c: Vector2i in roots:
		if view.has_point(Vector2(c) * CELL):
			_draw_root(c, int(roots[c]))
	for c: Vector2i in worms:
		_draw_worm(c, worms[c])
	for ih in u.generator.ice_holes:
		if view.intersects(Rect2(Vector2((ih.rink as Rect2i).position) * CELL, Vector2((ih.rink as Rect2i).size + Vector2i(0, 1)) * CELL)):
			_draw_snow(ih)
	for c in u.generator.fish_cells:
		if u.world.is_solid(c) and view.has_point(Vector2(c) * CELL):
			_draw_fish_in_ice(c)
	for f in _fish_free:
		_draw_free_fish(f)


## World px around the players (and the Topsoil landing when there are none), wide enough for a
## TV screen at the closest zoom.
func _view_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for p in u.hazards.players() if u.hazards != null else []:
		var at := u.world.to_local(p.global_position)
		var box := Rect2(at - Vector2(1100, 700), Vector2(2200, 1400))
		r = box if first else r.merge(box)
		first = false
	if first:
		r = Rect2(u.landing(0) - Vector2(1100, 700), Vector2(2200, 1400))
	return r


## A root hanging from the ceiling cell `c`: a wiggly strand 8..20 px with one or two side shoots.
func _draw_root(c: Vector2i, sd: int) -> void:
	var x := (c.x + 0.25 + (sd % 5) * 0.12) * CELL
	var top := (c.y + 1.0) * CELL - 1.0
	var length := 14.0 + float(sd % 13)
	var sway := sin(_t * 1.3 + sd) * 1.2
	var pts := PackedVector2Array()
	var n := 5
	for i in n + 1:
		var k := float(i) / n
		pts.append(Vector2(x + sin(k * 4.0 + sd) * 1.5 + sway * k * k, top + k * length))
	draw_polyline(pts, OUTLINE, 4.5)
	draw_polyline(pts, ROOT, 2.5)
	# Side shoots.
	for s in 1 + sd % 2:
		var i := 2 + s
		var from := pts[i]
		var side := -1.0 if (sd + s) % 2 == 0 else 1.0
		var to := from + Vector2(side * (4.0 + s * 2.0), 4.0 + s)
		draw_line(from, to, OUTLINE, 3.5)
		draw_line(from, to, ROOT, 1.5)
	draw_circle(pts[n], 2.0, OUTLINE)
	draw_circle(pts[n], 1.2, ROOT_DARK)


## A friendly pink worm leaning out of the wall: a curved body of round segments, a head with two
## eyes, rosy cheeks and a smile. While waving the top sways side to side.
func _draw_worm(c: Vector2i, w: Dictionary) -> void:
	var out := worm_out(c)
	if out <= 0.0:
		return
	var dir := float(w.dir)
	var base := _face(c, int(w.dir))
	var wave := 0.0
	if int(w.phase) == Phase.WAVE:
		wave = sin(w.t * 9.0) * 0.55 * minf(1.0, w.t * 4.0)
	var segs := 5
	var pts: Array[Vector2] = []
	for i in segs:
		var k := float(i + 1) / segs * out
		# Out from the wall, then curving up; the wave bends the top part.
		var a := lerpf(0.0, -1.25, k) + wave * k * k
		pts.append(base + Vector2(dir * cos(a) * 11.0 * k, sin(a) * 12.0 * k))
	# Dirt crumbs around the hole.
	draw_circle(base + Vector2(0, 5), 3.0, Color("6b4423"))
	for i in segs:
		var r := 3.6 - i * 0.15
		draw_circle(pts[i], r + 1.0, OUTLINE)
	for i in segs:
		var r := 3.6 - i * 0.15
		draw_circle(pts[i], r, WORM if i % 2 == 0 else WORM_RING)
	var head := pts[segs - 1] + Vector2(dir * 1.5, -2.0)
	draw_circle(head, 5.5, OUTLINE)
	draw_circle(head, 4.5, WORM)
	var face := Vector2(dir * 1.5, 0)
	for e in [-1.6, 1.6]:
		draw_circle(head + face + Vector2(e, -1.0), 1.4, Color.WHITE)
		draw_circle(head + face + Vector2(e + dir * 0.4, -0.8), 0.8, OUTLINE)
	draw_circle(head + face + Vector2(-3.0 * dir, 1.5), 1.0, WORM_CHEEK)
	draw_arc(head + face + Vector2(0, 1.2), 1.6, 0.3, PI - 0.3, 6, OUTLINE, 1.0)


## Snow drifted on a rink's ice floor: a thin cap everywhere, piled up against the far wall, a
## soft bumpy top. Only over floor cells that are still there.
func _draw_snow(ih: Dictionary) -> void:
	var rink: Rect2i = ih.rink
	var dir := int(ih.dir)
	var floor_y := rink.end.y * CELL
	var x0 := rink.position.x if dir > 0 else rink.position.x + HillGenerator.HOLE_W + 1
	var x1 := rink.end.x - HillGenerator.HOLE_W - 1 if dir > 0 else rink.end.x
	var wall_x := (rink.position.x if dir > 0 else rink.end.x) * CELL
	var run := PackedVector2Array()
	for cx in range(x0, x1 + 1):
		var solid := cx < x1 and u.world.is_solid(Vector2i(cx, rink.end.y))
		if solid:
			for k in 4:
				var x := (cx + k / 4.0) * CELL
				run.append(Vector2(x, floor_y - _snow_h(x, wall_x)))
		if (not solid or cx == x1) and run.size() > 0:
			var end_x := run[run.size() - 1].x + CELL / 4.0
			run.append(Vector2(end_x, floor_y - _snow_h(end_x, wall_x)))
			_snow_run(run, floor_y)
			run = PackedVector2Array()


func _snow_h(x: float, wall_x: float) -> float:
	var d := absf(x - wall_x) / CELL
	return 4.0 + 10.0 * exp(-d * 0.5) + sin(x * 0.13) * 1.2 + 1.2


func _snow_run(top: PackedVector2Array, floor_y: float) -> void:
	var poly := top.duplicate()
	poly.append(Vector2(top[top.size() - 1].x, floor_y + 1.0))
	poly.append(Vector2(top[0].x, floor_y + 1.0))
	draw_colored_polygon(poly, SNOW)
	var shade := PackedVector2Array()
	for p in top:
		shade.append(p + Vector2(0, 2.0))
	draw_polyline(shade, SNOW_SHADE, 1.0)
	draw_polyline(top, OUTLINE, 1.0)


## The fish frozen in its block: the fish picture tinted by the ice, a glaze and a twinkle.
func _draw_fish_in_ice(c: Vector2i) -> void:
	var r := Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))
	var tilt := 0.18 * (1.0 if _hash(c, 9) % 2 == 0 else -1.0)
	if _fish_tex != null:
		draw_set_transform(r.get_center(), tilt, Vector2.ONE)
		draw_texture_rect(_fish_tex, Rect2(-Vector2(8, 8), Vector2(16, 16)), false, Color(0.95, 0.98, 1.0))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(r.get_center(), 4.0, Color("ff9a2e"))
	draw_rect(r.grow(-1.0), ICE_GLAZE)
	draw_rect(r.grow(-0.5), Color(1, 1, 1, 0.55), false, 1.0)
	draw_line(r.position + Vector2(3, 12), r.position + Vector2(7, 8), Color(1, 1, 1, 0.7), 1.0)
	var f := fmod(_t * 0.6 + _hash(c, 2) % 7 * 0.13, 1.0)
	if f < 0.35:
		Hazards.draw_star(self, r.position + Vector2(12, 3), 2.5, Color(1, 1, 1, sin(f / 0.35 * PI)))


## A later fish, dug free: hops up out of the ice, wiggles, swims off sideways and fades.
func _draw_free_fish(f: Dictionary) -> void:
	if _fish_tex == null:
		return
	var k: float = f.t / FISH_FREE_TIME
	var dir := float(f.dir)
	var hop := sin(minf(k * 2.0, 1.0) * PI) * 22.0
	var at: Vector2 = f.pos + Vector2(dir * k * 70.0, -hop - k * 10.0)
	var wig := sin(f.t * 18.0) * 0.35
	draw_set_transform(at, wig, Vector2(dir, 1.0) * 1.3)
	draw_texture_rect(_fish_tex, Rect2(-Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, clampf((1.0 - k) * 3.0, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO)
	if fmod(f.t, 0.3) < 0.15:
		draw_circle(at + Vector2(-dir * 10.0, 2.0), 1.5, Color(0.8, 0.93, 1.0, 1.0 - k))


static func _hash(c: Vector2i, salt: int) -> int:
	return absi(hash(Vector3i(c.x, c.y, salt)))
