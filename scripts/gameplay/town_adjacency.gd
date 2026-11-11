## Town adjacency (C-23): buildings that like each other (data/adjacency.tres) and stand near each
## other get hearts floating back and forth between their roofs and a little flower bed growing on
## the ground between them. A new happy pair is felt once: a sparkle burst, a big heart pop, both
## buildings hop, the `town_hearts` chime, and the flowers grow. A ghost in a player's hands
## previews it: soft hearts reach from the ghost to every building it would like there, the
## partners hop and `heart_preview` pings. No text, no numbers.
##
## Spots in town: every placed building (Progress.buildings), every restored resident home (the
## ruin sites, once rebuilt) and the landmarks &"shaft" and &"pond". Visuals only, nothing saved:
## the pairs follow Progress and the Story. Lives in Hillville between the buildings and players.
class_name TownAdjacency
extends Node2D

signal pair_made(a: StringName, b: StringName)

const PLOT := 48.0
const DATA_PATH := "res://data/adjacency.tres"
const HEART := Color("ff5d8f")
const HEART_HI := Color("ffc2d6")
const OUTLINE := Color("2a1e24")
const STEM := Color("3f9e4a")
const GOLD := Color("ffd23f")
const PETALS := [Color("ff8fb1"), Color("ffffff"), Color("ffd23f"), Color("b78cff"), Color("ff6b5a")]
## Landmarks: id -> [x0, x1, top y] in Hillville px.
const LANDMARKS := {
	&"shaft": [39 * 48.0, 41 * 48.0, -150.0],
	&"pond": [104 * 48.0, 110 * 48.0, -8.0],
}
const POLL := 0.2
const CELEBRATE_DELAY := 0.5   # after the unfold
const POP_TIME := 0.7

var data: AdjacencyData
var game: Node
var hillville: Hillville
## Happy pairs now in town: key -> {a: spot, b: spot, grow, alive, wait, pop, flowers: Array}.
var pairs := {}
## Ghost previews: player -> Array of partner spots (only while the ghost sits on a good plot).
var previews := {}
## How many new pairs were celebrated (tests, beat log).
var celebrations := 0

var _t := 0.0
var _poll := 0.0
var _primed := false
var _sparks: Array = []
var _carry_sig: Array = []


func setup(p_game: Node, p_hillville: Hillville, p_data: AdjacencyData = null) -> void:
	game = p_game
	hillville = p_hillville
	data = p_data if p_data != null else load(DATA_PATH) as AdjacencyData
	name = "TownAdjacency"
	Progress.changed.connect(_dirty)
	Events.ruin_restored.connect(_on_restored)
	sync()


func _exit_tree() -> void:
	if Progress.changed.is_connected(_dirty):
		Progress.changed.disconnect(_dirty)
	if Events.ruin_restored.is_connected(_on_restored):
		Events.ruin_restored.disconnect(_on_restored)


# --- pair detection (pure) ---------------------------------------------------------------------

## Empty px between two spots' footprints (negative when they overlap).
static func gap_px(a: Dictionary, b: Dictionary) -> float:
	return maxf(b.x0 - a.x1, a.x0 - b.x1)


## True when two spots are near enough and like each other.
static func happy(a: Dictionary, b: Dictionary, d: AdjacencyData) -> bool:
	return gap_px(a, b) <= d.radius_plots * PLOT + 0.5 and d.likes(a.id, b.id)


## Every happy pair among `spots` ({key, id, x0, x1, top}): [[i, j], ...] indices into `spots`.
## Sorted by x, so a hundred barns in a row is still cheap.
static func find_pairs(spots: Array, d: AdjacencyData) -> Array:
	var order := range(spots.size())
	order.sort_custom(func(i: int, j: int) -> bool: return spots[i].x0 < spots[j].x0)
	var reach := d.radius_plots * PLOT + 0.5
	var out: Array = []
	for oi in order.size():
		var a: Dictionary = spots[order[oi]]
		for oj in range(oi + 1, order.size()):
			var b: Dictionary = spots[order[oj]]
			if b.x0 - a.x1 > reach:
				break   # sorted by x0 and nothing overlaps: everything further right is further away
			if happy(a, b, d):
				out.append([order[oi], order[oj]])
	return out


## The spots `spot` would be happy with (ignoring keys in `skip`).
static func partners_of(spot: Dictionary, spots: Array, d: AdjacencyData, skip := []) -> Array:
	var out: Array = []
	for s in spots:
		if s.key == spot.key or skip.has(s.key):
			continue
		if happy(spot, s, d):
			out.append(s)
	return out


static func pair_key(a: Dictionary, b: Dictionary) -> String:
	return "%s|%s" % [a.key, b.key] if String(a.key) < String(b.key) else "%s|%s" % [b.key, a.key]


# --- town spots ---------------------------------------------------------------------------------

## Everything in town that can be liked: placed buildings, restored homes, landmarks.
func spots() -> Array:
	var out: Array = []
	var build = game.get("build") if game != null else null
	var carried := _carried()
	for i in Progress.buildings.size():
		var b: Dictionary = Progress.buildings[i]
		var d := Progress.building_data(b.id)
		if d == null or d.is_ruin or carried.has(i):
			continue   # a building up on someone's hands is the ghost, not a spot
		var x0: float = b.cell.x * PLOT
		out.append({"key": "b%d" % i, "id": b.id, "x0": x0, "x1": x0 + d.footprint.x * PLOT,
				"top": -d.footprint.y * PLOT, "index": i,
				"node": build.building_node(i) if build is BuildController else null})
	var st = game.get("story") if game != null else null
	var ruins = game.get("ruins") if game != null else null
	if st is Story and hillville != null:
		for rid: StringName in Story.HOME_OF:
			if not (st as Story).restored(rid):
				continue
			if ruins is RuinSites and (ruins as RuinSites).is_rebuilding(rid):
				continue   # celebrate once the last plank is on
			var home: StringName = Story.HOME_OF[rid]
			var r := hillville.ruin_rect(Story.RUIN_OF[rid])
			var hd := Progress.building_data(home)
			var h := hd.footprint.y * PLOT if hd != null else r.size.y
			out.append({"key": "home:%s" % rid, "id": home, "x0": r.position.x, "x1": r.end.x, "top": -h,
					"node": (ruins as RuinSites).homes.get(rid) if ruins is RuinSites else null})
	for id: StringName in LANDMARKS:
		var l: Array = LANDMARKS[id]
		out.append({"key": String(id), "id": id, "x0": l[0], "x1": l[1], "top": l[2], "node": null})
	return out


## The ghost a player carries as a spot, or {} (none, or on a plot it cannot drop on).
func ghost_spot(p: int) -> Dictionary:
	var build = game.get("build") if game != null else null
	if not (build is BuildController):
		return {}
	var g: Building = (build as BuildController).ghost_of(p)
	if g == null or not g.ghost_ok:
		return {}
	var s := g.size_px()
	return {"key": "ghost%d" % p, "id": g.data.id, "x0": g.position.x, "x1": g.position.x + s.x,
			"top": g.position.y - s.y, "index": g.index, "node": g}


## Progress indices of buildings players are carrying (picked up to move).
func _carried() -> Array:
	var out: Array = []
	var build = game.get("build") if game != null else null
	if build is BuildController:
		for p in (build as BuildController)._st:
			var g: Building = (build as BuildController).ghost_of(p)
			if g != null and g.index >= 0:
				out.append(g.index)
	return out


# --- live ---------------------------------------------------------------------------------------

func _dirty() -> void:
	_poll = POLL


func _on_restored(_ruin: StringName, _resident: StringName) -> void:
	_poll = POLL


## Recomputes the happy pairs now. New ones celebrate (after the first sync, which just shows them).
func sync() -> void:
	var all := spots()
	var now := {}
	for ij in find_pairs(all, data):
		var a: Dictionary = all[ij[0]]
		var b: Dictionary = all[ij[1]]
		if a.x0 > b.x0:
			var tmp := a
			a = b
			b = tmp
		now[pair_key(a, b)] = [a, b]
	for k in pairs:
		if not now.has(k):
			pairs[k].alive = false
	for k in now:
		var ab: Array = now[k]
		if pairs.has(k):
			var pr: Dictionary = pairs[k]
			pr.a = ab[0]
			pr.b = ab[1]
			if not pr.alive:
				pr.alive = true
				pr.flowers = _flowers(k, ab[0], ab[1])
			continue
		var fresh := {"a": ab[0], "b": ab[1], "alive": true, "grow": 1.0 if not _primed else 0.0,
				"wait": -1.0 if not _primed else CELEBRATE_DELAY, "pop": -1.0, "flowers": _flowers(k, ab[0], ab[1])}
		pairs[k] = fresh
	_primed = true
	queue_redraw()


func _flowers(key: String, a: Dictionary, b: Dictionary) -> Array:
	var lo: float = a.x1 - 18.0   # the bed reaches a little under both fronts
	var hi: float = b.x0 + 18.0
	if hi - lo < 60.0:
		var mid := (lo + hi) * 0.5
		lo = mid - 30.0
		hi = mid + 30.0
	var n := maxi(3, ceili((hi - lo) / PLOT * data.flowers_per_plot))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var out: Array = []
	for i in n:
		var x := lerpf(lo + 6.0, hi - 6.0, (i + rng.randf_range(0.2, 0.8)) / n)
		out.append({"x": x, "h": rng.randf_range(11.0, 20.0), "col": PETALS[rng.randi() % PETALS.size()],
				"delay": float(i) / n * 0.5, "sway": rng.randf() * TAU})
	return out


func _process(delta: float) -> void:
	_t += delta
	var carry := _carried()
	if carry != _carry_sig:
		_carry_sig = carry
		_poll = 0.0
		sync()
	if _poll > 0.0:
		_poll -= delta
		if _poll <= 0.0:
			sync()
	elif fmod(_t, 1.0) < delta:
		sync()   # restored homes finish rebuilding with no signal of their own
	var dead: Array = []
	for k in pairs:
		var pr: Dictionary = pairs[k]
		if not pr.alive:
			pr.grow = maxf(0.0, pr.grow - delta / 0.6)
			if pr.grow <= 0.0:
				dead.append(k)
			continue
		if pr.wait >= 0.0:
			pr.wait -= delta
			if pr.wait < 0.0:
				_celebrate(pr)
			continue
		pr.grow = minf(1.0, pr.grow + delta / maxf(0.05, data.grow_time))
		if pr.pop >= 0.0:
			pr.pop += delta
			if pr.pop > POP_TIME:
				pr.pop = -1.0
	for k in dead:
		pairs.erase(k)
	_update_previews()
	for s in _sparks:
		s.life += delta
		s.pos += s.vel * delta
		s.vel *= 0.92
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life < s.max)
	queue_redraw()


func _celebrate(pr: Dictionary) -> void:
	pr.pop = 0.0
	pr.grow = 0.0
	celebrations += 1
	Audio.play("town_hearts")
	var top := _arc_top(pr.a, pr.b)
	_burst(top, data.sparkles)
	_burst(_roof(pr.a), data.sparkles / 3)
	_burst(_roof(pr.b), data.sparkles / 3)
	for s in [pr.a, pr.b]:
		var n = s.get("node")
		if n is Building and is_instance_valid(n):
			(n as Building).bump()
	pair_made.emit(pr.a.id, pr.b.id)


func _burst(at: Vector2, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		_sparks.append({"pos": at, "vel": Vector2.from_angle(a) * randf_range(40.0, 120.0), "life": 0.0,
				"max": randf_range(0.5, 0.9), "r": randf_range(3.0, 5.5), "col": GOLD if i % 3 else Color.WHITE})


func _update_previews() -> void:
	var build = game.get("build") if game != null else null
	var players: Array = (build as BuildController)._st.keys() if build is BuildController else []
	var all: Array = []
	for p in players:
		var g := ghost_spot(p)
		if g.is_empty():
			previews.erase(p)
			continue
		if all.is_empty():
			all = spots()
		var skip := []
		if int(g.get("index", -1)) >= 0:
			skip.append("b%d" % g.index)   # a carried building does not like its own old spot
		var found := partners_of(g, all, data, skip)
		var old: Array = previews.get(p, [])
		var old_keys := old.map(func(s: Dictionary) -> String: return s.key)
		var fresh := false
		for s in found:
			if not old_keys.has(s.key):
				fresh = true
				var n = s.get("node")
				if n is Building and is_instance_valid(n):
					(n as Building).bump()
		if fresh:
			Audio.play("heart_preview")
		var keep: Array = []
		for s in found:
			var o: Dictionary = s.duplicate()
			o["ghost"] = g
			keep.append(o)
		if keep.is_empty():
			previews.erase(p)
		else:
			previews[p] = keep


# --- drawing ------------------------------------------------------------------------------------

func _roof(s: Dictionary) -> Vector2:
	return Vector2((s.x0 + s.x1) * 0.5, s.top - 8.0)


func _arc_top(a: Dictionary, b: Dictionary) -> Vector2:
	return _bez(_roof(a), _roof(b), 0.5)


func _bez(p0: Vector2, p1: Vector2, u: float) -> Vector2:
	var c := (p0 + p1) * 0.5 + Vector2(0, -(26.0 + p0.distance_to(p1) * 0.18))
	return p0.lerp(c, u).lerp(c.lerp(p1, u), u)


func _draw() -> void:
	for k in pairs:
		var pr: Dictionary = pairs[k]
		_draw_flowers(pr)
	for k in pairs:
		var pr: Dictionary = pairs[k]
		if pr.alive and pr.wait < 0.0:
			# Every other pair floats its hearts right to left, so a row of pairs is not a conveyor.
			var flip: bool = hash(k) % 2 == 1
			_draw_hearts(_roof(pr.b) if flip else _roof(pr.a), _roof(pr.a) if flip else _roof(pr.b), 1.0, pr.grow)
			if pr.pop >= 0.0:
				var u: float = pr.pop / POP_TIME
				var sc := 1.0 + 1.4 * sin(PI * minf(1.0, u * 1.3))
				_heart(_arc_top(pr.a, pr.b) + Vector2(0, -10.0 * u), 1.6 * sc * (1.0 - u * u), 1.0)
	for p in previews:
		for s in previews[p]:
			var pulse := 0.75 + 0.25 * sin(_t * 7.0)
			_draw_trail(_roof(s.ghost), _roof(s), data.preview_alpha * pulse)
			_draw_hearts(_roof(s.ghost), _roof(s), data.preview_alpha * pulse, 1.0, 1.6)
	for s in _sparks:
		var a: float = 1.0 - s.life / s.max
		_star(s.pos, s.r * (0.6 + a * 0.4), Color(s.col, a))


func _draw_hearts(p0: Vector2, p1: Vector2, alpha: float, grow: float, speed := 1.0) -> void:
	var n := maxi(1, data.hearts)
	for i in n:
		var u := fmod(_t * speed / maxf(0.2, data.heart_time) + float(i) / n, 1.0)
		var fade := clampf(sin(PI * u) * 1.6, 0.0, 1.0)
		var bob := Vector2(0, sin(_t * 3.0 + i) * 2.0)
		_heart(_bez(p0, p1, u) + bob, (0.8 + 0.35 * sin(PI * u)) * (0.4 + 0.6 * grow) * fade, alpha)


func _draw_trail(p0: Vector2, p1: Vector2, alpha: float) -> void:
	for i in 14:
		var u := (i + fmod(_t * 2.0, 1.0)) / 14.0
		draw_circle(_bez(p0, p1, u), 1.8, Color(HEART_HI, alpha * 0.8))


## A heart with an outline; `s` = 1 is about 26 px wide. `a` < 1 fades it toward a pale pink
## (drawn solid: see-through layers would mix the outline into the fill and go muddy).
func _heart(c: Vector2, s: float, a: float) -> void:
	if a <= 0.01 or s <= 0.01:
		return
	var u := s * 1.35
	var fill := HEART.lerp(HEART_HI, clampf(1.0 - a, 0.0, 1.0) * 0.8)
	draw_circle(c + Vector2(-3.5, -2) * u, 5.7 * u, OUTLINE)
	draw_circle(c + Vector2(3.5, -2) * u, 5.7 * u, OUTLINE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9.4, -0.2) * u, c + Vector2(9.4, -0.2) * u, c + Vector2(0, 9.6) * u]), OUTLINE)
	draw_circle(c + Vector2(-3.5, -2) * u, 4.5 * u, fill)
	draw_circle(c + Vector2(3.5, -2) * u, 4.5 * u, fill)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -0.5) * u, c + Vector2(8, -0.5) * u, c + Vector2(0, 8) * u]), fill)
	draw_circle(c + Vector2(-4.5, -3.5) * u, 1.5 * u, Color.WHITE.lerp(fill, 0.3))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.35
		pts.append(c + Vector2.from_angle(i * PI / 4.0) * rr)
	draw_colored_polygon(pts, col)


func _draw_flowers(pr: Dictionary) -> void:
	for f in pr.flowers:
		var g := clampf((pr.grow - f.delay * 0.5) / maxf(0.05, 1.0 - f.delay * 0.5), 0.0, 1.0)
		if g <= 0.0:
			continue
		g = ease(g, -2.0)   # springy
		var h: float = f.h * g
		var sway := sin(_t * 1.6 + f.sway) * 1.5 * g
		var base := Vector2(f.x, 0.0)
		var head := base + Vector2(sway, -h)
		draw_line(base, head, OUTLINE, 3.6)
		draw_line(base, head, STEM, 2.0)
		draw_circle(base.lerp(head, 0.45) + Vector2(3.0, 0), 2.6 * g, OUTLINE)
		draw_circle(base.lerp(head, 0.45) + Vector2(3.0, 0), 1.9 * g, STEM)
		var r := 3.6 * g
		for k in 5:
			var off := Vector2.from_angle(k * TAU / 5.0 + f.sway) * r
			draw_circle(head + off, r * 0.95, OUTLINE)
		for k in 5:
			var off := Vector2.from_angle(k * TAU / 5.0 + f.sway) * r
			draw_circle(head + off, r * 0.75, f.col)
		draw_circle(head, r * 0.6, GOLD if f.col != GOLD else Color("ff8a3d"))
