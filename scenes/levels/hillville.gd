## Hillville, the side-view surface: flat ground (top at y = 0) from 0 to WIDTH, scrub to scoop
## (trees, rocks, stumps), four ruins with a silhouette slot on the door, the mine shaft head-frame
## with its cage, and the shaft pile (the shared Inventory as a heap of block squares).
## Flat-colour placeholder art drawn in _draw(). Scrub never collides.
class_name Hillville
extends Node2D

signal vehicle_rolls_out(vehicle_id: StringName, door: Vector2)   # a Garage just unlocked a vehicle

const WIDTH := 7680.0
const SHAFT_X := 1920.0
const PLOT := 48
const TILE := 16
const COLS := 480                     # WIDTH / TILE
const CELLS := 160                    # WIDTH / PLOT
const GROUND_DEPTH := 160.0
const SKY_TOP := -700.0

enum Scrub { NONE, TREE, ROCK, STUMP }

## Ruins on the plot grid: id, first cell. Footprints come from their BuildingData rows.
const RUINS := [
	{"id": &"old_shed", "cell": 2},
	{"id": &"crooked_watchtower", "cell": 72},
	{"id": &"flooded_cabin", "cell": 106},
	{"id": &"ruined_keep", "cell": 153},
]
## Plot cells with no scrub: [from, to) -> what is there (&"" = just a clear yard, buildable).
const ZONES := [
	[0, 2, &"gate"],
	[32, 39, &""],
	[39, 41, &"shaft"],
	[41, 43, &"pile"],
	[43, 47, &""],
	[104, 106, &"pond"],
	[108, 110, &"pond"],
	[152, 153, &"keep_rock"],
	[156, 160, &"keep_rock"],
]
const POND := Rect2(104 * 48, -3, 6 * 48, 17)
const PILE_X := 41 * 48 + 4.0
const PILE_BASE := 12
const PILE_ROWS := 8
const BLOCK_ORDER := [&"dirt", &"clay", &"stone", &"ice", &"crystal", &"strangestone", &"edgestone"]
const BLOCK_DIR := "res://data/blocks/"
const OUTLINE := Color(0.09, 0.07, 0.07)

var cage_flash := 0.0:
	set(v):
		cage_flash = v
		if _shaft != null:
			_shaft.queue_redraw()

## Deterministic scrub layout seed (the save's "seed" may set it before _ready or via set_layout_seed).
var layout_seed := 1

var _kind := PackedByteArray()
var _h := PackedByteArray()           # tiles left per column
var _h0 := PackedByteArray()          # tiles at generation
var _wide := PackedByteArray()        # 1: this rock column joins the one to its right
var _silhouette := {}                 # ruin id -> true once its resident was encountered
var _fx: Array = []
var _cells_kind := {}                 # cell -> zone/ruin StringName

var _back: _Layer
var _ruins: _Layer
var _shaft: _Layer
var _pile: _Layer
var _scrub: _Layer
var _ground: _Layer
var _fx_layer: _Layer
var _buildings: Node2D
var _players: Node2D

static var _block_colors := {}


class _Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


func _init() -> void:
	name = "Hillville"
	_generate()
	_build_nodes()


func _ready() -> void:
	Events.inventory_changed.connect(_on_inventory_changed)


## Children exist from construction, so players_root() / buildings_root() work before _ready.
func _build_nodes() -> void:
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, GROUND_DEPTH)
	cs.shape = rect
	cs.position = Vector2(WIDTH * 0.5, GROUND_DEPTH * 0.5)
	ground.add_child(cs)
	for side in [-1.0, 1.0]:
		var wall := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(32, 2000)
		wall.shape = wr
		wall.position = Vector2(-16.0 if side < 0 else WIDTH + 16.0, -1000)
		ground.add_child(wall)
	add_child(ground)
	_back = _layer("Backdrop", _draw_backdrop)
	_ruins = _layer("Ruins", _draw_ruins)
	_shaft = _layer("Shaft", _draw_head_frame)
	_pile = _layer("Pile", _draw_pile)
	_scrub = _layer("Scrub", _draw_scrub)
	_ground = _layer("GroundArt", _draw_ground)
	_buildings = Node2D.new()
	_buildings.name = "Buildings"
	add_child(_buildings)
	_players = Node2D.new()
	_players.name = "Players"
	add_child(_players)
	_fx_layer = _layer("Fx", _draw_fx)
	set_process(false)


func _exit_tree() -> void:
	if Events.inventory_changed.is_connected(_on_inventory_changed):
		Events.inventory_changed.disconnect(_on_inventory_changed)


func _layer(n: String, f: Callable) -> _Layer:
	var l := _Layer.new()
	l.name = n
	l.fn = f
	add_child(l)
	return l


func _on_inventory_changed(_b: StringName, _n: int) -> void:
	if _pile != null:
		_pile.queue_redraw()


# --- the seam --------------------------------------------------------------------------------

func get_camera_limits() -> Rect2:
	return Rect2(0, SKY_TOP, WIDTH, GROUND_DEPTH - SKY_TOP)


## Feet inside = in the up-top cage.
func cage_zone() -> Rect2:
	return Rect2(SHAFT_X - 16, -32, 32, 36)


## Where a rider coming up appears (feet).
func arrival() -> Vector2:
	return Vector2(SHAFT_X, -2)


func loader_spawn() -> Vector2:
	return Vector2(SHAFT_X - 160, 0)


func spawn_point(player: int) -> Vector2:
	return Vector2(SHAFT_X - 260 - 48 * player, 0)


func players_root() -> Node2D:
	return _players


## Placed Building nodes live here (BuildController).
func buildings_root() -> Node2D:
	return _buildings


## Clears scrub in `area` (tiles wide x tall) toward `facing` from `at` (feet, or the bucket tip):
## scans the column under `at` and area.x columns ahead, takes the first area.x that have scrub,
## up to area.y tiles off the top of each. Blocks go to Inventory. Returns tiles cleared.
func scoop(at: Vector2, facing: int, area: Vector2i, player: int) -> int:
	var dir := 1 if facing >= 0 else -1
	var c0 := floori(at.x / TILE)
	var wide := maxi(area.x, 1)
	var tall := maxi(area.y, 1)
	var cols_hit := 0
	var got := {}
	var cleared := 0
	for i in wide + 1:
		if cols_hit >= wide:
			break
		var c := c0 + i * dir
		if c < 0 or c >= COLS or _h[c] == 0:
			continue
		cols_hit += 1
		var n := mini(tall, _h[c])
		var kind := _kind[c]
		var top := -float(_h[c]) * TILE
		_h[c] -= n
		cleared += n
		var block := &"stone" if kind == Scrub.ROCK else &"dirt"
		got[block] = int(got.get(block, 0)) + n
		_scrub_fx(c, kind, n, top, dir)
	for b in got:
		Inventory.add(b, got[b])
	if cleared > 0:
		_scrub.queue_redraw()
		_ground.queue_redraw()
	return cleared


## Scrub tiles left (tests / demo).
func scrub_left() -> int:
	var n := 0
	for h in _h:
		n += h
	return n


## x of the nearest uncleared scrub column's centre, or INF.
func nearest_scrub(x: float) -> float:
	var best := INF
	for c in COLS:
		if _h[c] > 0:
			var cx := c * TILE + TILE * 0.5
			if absf(cx - x) < absf(best - x):
				best = cx
	return best


func to_save() -> Dictionary:
	var s := ""
	for h in _h:
		s += str(h)
	return {"seed": layout_seed, "left": s}


func load_save(data: Dictionary) -> void:
	var sd := int(data.get("seed", layout_seed))
	if sd != layout_seed:
		set_layout_seed(sd)
	var s := str(data.get("left", ""))
	for c in mini(s.length(), COLS):
		_h[c] = mini(_h0[c], int(s[c]))
	_redraw_all()


# --- extras for BuildController / A ----------------------------------------------------------

func set_layout_seed(s: int) -> void:
	layout_seed = s
	_generate()
	_redraw_all()


## Scrub tiles left in tile column c.
func scrub_at(c: int) -> int:
	return _h[c] if c >= 0 and c < COLS else 0


func scrub_kind(c: int) -> int:
	return _kind[c] if c >= 0 and c < COLS and _h[c] > 0 else Scrub.NONE


## What owns plot cell `cell`: a ruin id, &"shaft", &"pile", &"pond", &"gate", &"keep_rock",
## &"outside", or &"" (free ground; scrub may still stand on it).
func cell_owner(cell: int) -> StringName:
	if cell < 0 or cell >= CELLS:
		return &"outside"
	return _cells_kind.get(cell, &"")


## True when plot cells [cell_x, cell_x + width) are inside the world, have no scrub, ruin,
## shaft, pile or pond. Buildings overlapping is BuildController's check.
func ground_clear(cell_x: int, width: int) -> bool:
	for cell in range(cell_x, cell_x + width):
		if cell_owner(cell) != &"":
			return false
		for k in 3:
			if _h[cell * 3 + k] > 0:
				return false
	return true


func ruin_ids() -> Array:
	return RUINS.map(func(r: Dictionary) -> StringName: return r.id)


## A ruin's footprint in Hillville px (bottom on the ground).
func ruin_rect(id: StringName) -> Rect2:
	for r in RUINS:
		if r.id == id:
			var fp := _ruin_fp(id)
			return Rect2(r.cell * PLOT, -fp.y * PLOT, fp.x * PLOT, fp.y * PLOT)
	return Rect2()


## Shows (or hides) the resident's silhouette in a ruin's door slot.
func show_silhouette(ruin_id: StringName, shown := true) -> void:
	_silhouette[ruin_id] = shown
	if _ruins != null:
		_ruins.queue_redraw()


## A dust puff (Hillville-local), used by scoops and buildings.
func puff(at: Vector2, color := Color(0.85, 0.78, 0.65), n := 10) -> void:
	for i in n:
		var a := randf_range(PI * 1.05, PI * 1.95)
		_fx.append({"k": "p", "pos": at + Vector2(randf_range(-10, 10), -2), "vel": Vector2.from_angle(a) * randf_range(30, 110),
				"life": 0.0, "max": randf_range(0.35, 0.6), "col": color, "r": randf_range(3, 7), "g": 60.0})
	_wake_fx()


static func block_color(id: StringName) -> Color:
	if not _block_colors.has(id):
		var path := BLOCK_DIR + String(id) + ".tres"
		var d: Resource = load(path) if ResourceLoader.exists(path) else null
		_block_colors[id] = d.color if d != null else Color(0.6, 0.6, 0.6)
	return _block_colors[id]


# --- layout ------------------------------------------------------------------------------------

static func _ruin_fp(id: StringName) -> Vector2i:
	var d := Progress.building_data(id)
	return d.footprint if d != null else Vector2i(2, 2)


func _generate() -> void:
	_kind.resize(COLS)
	_h.resize(COLS)
	_h0.resize(COLS)
	_wide.resize(COLS)
	_kind.fill(0)
	_h.fill(0)
	_wide.fill(0)
	_cells_kind.clear()
	for z in ZONES:
		for cell in range(z[0], z[1]):
			_cells_kind[cell] = z[2]
	for r in RUINS:
		var fp := _ruin_fp(r.id)
		for cell in range(r.cell, r.cell + fp.x):
			_cells_kind[cell] = r.id
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var c := 0
	while c < COLS:
		if _cells_kind.has(c / 3):
			c += 1
			continue
		var r := rng.randf()
		if r < 0.18:
			c += 1
			continue
		if r < 0.5:
			_put(c, Scrub.TREE, rng.randi_range(3, 4))
		elif r < 0.75:
			var h := rng.randi_range(1, 2)
			_put(c, Scrub.ROCK, h)
			if rng.randf() < 0.5 and c + 1 < COLS and not _cells_kind.has((c + 1) / 3):
				_wide[c] = 1
				c += 1
				_put(c, Scrub.ROCK, h)
		else:
			_put(c, Scrub.STUMP, 1)
		c += 1 + (1 if rng.randf() < 0.35 else 0)
	_h0 = _h.duplicate()


func _put(c: int, kind: int, h: int) -> void:
	_kind[c] = kind
	_h[c] = h


func _redraw_all() -> void:
	for l in [_back, _ruins, _shaft, _pile, _scrub, _ground]:
		if l != null:
			l.queue_redraw()


# --- fx ----------------------------------------------------------------------------------------

func _scrub_fx(c: int, kind: int, n: int, top: float, dir: int) -> void:
	var cx := c * TILE + TILE * 0.5
	match kind:
		Scrub.TREE:
			Audio.play("tree_fall")
			_fx.append({"k": "tree", "pos": Vector2(cx, top + n * TILE), "h": n * TILE, "dir": dir,
					"crown": _h[c] + n == _h0[c], "life": 0.0, "max": 0.7, "landed": false})
		Scrub.ROCK:
			Audio.play("rock_crack")
			for i in 8:
				_fx.append({"k": "p", "pos": Vector2(cx, top + 6), "vel": Vector2(randf_range(-90, 90), randf_range(-170, -60)),
						"life": 0.0, "max": 0.6, "col": Color("8d97a3"), "r": randf_range(2.5, 4.5), "g": 520.0, "sq": true})
			puff(Vector2(cx, 0), Color(0.8, 0.8, 0.82), 6)
		_:
			Audio.play("stump_pop")
			_fx.append({"k": "p", "pos": Vector2(cx, -8), "vel": Vector2(dir * 40, -260), "life": 0.0, "max": 0.7,
					"col": Color("8a5a2b"), "r": 7.0, "g": 700.0, "sq": true})
			puff(Vector2(cx, 0), Color(0.7, 0.55, 0.38), 8)


func _wake_fx() -> void:
	set_process(true)


func _process(delta: float) -> void:
	var keep: Array = []
	for f in _fx:
		f.life += delta
		if f.k == "p":
			f.vel.y += f.g * delta
			f.pos += f.vel * delta
		elif f.k == "tree" and not f.landed and f.life >= 0.45:
			f.landed = true
			puff(f.pos + Vector2(f.dir * f.h * 0.8, 0), Color(0.6, 0.75, 0.45), 10)
		if f.life < f.max:
			keep.append(f)
	_fx = keep
	if _fx_layer != null:
		_fx_layer.queue_redraw()
	if _fx.is_empty():
		set_process(false)


func _draw_fx(ci: CanvasItem) -> void:
	for f in _fx:
		var k: float = f.life / f.max
		if f.k == "p":
			var col: Color = f.col
			col.a = 1.0 - k
			if f.get("sq", false):
				ci.draw_rect(Rect2(f.pos - Vector2(f.r, f.r), Vector2(f.r, f.r) * 2), col)
			else:
				ci.draw_circle(f.pos, f.r * (1.0 + k), col)
		elif f.k == "tree":
			var t := clampf(f.life / 0.45, 0.0, 1.0)
			var ang: float = f.dir * (PI * 0.5) * t * t
			var a: float = 1.0 if f.life < 0.5 else 1.0 - (f.life - 0.5) / 0.2
			# Falling part: trunk from the cut up, crown on top if it was there.
			var base: Vector2 = f.pos
			ci.draw_set_transform(base, ang)
			ci.draw_rect(Rect2(-4, -f.h, 8, f.h), Color(Color("8a5a2b"), a))
			if f.crown:
				ci.draw_circle(Vector2(0, -f.h + 4), 15, Color(Color("2f8a3a"), a))
				ci.draw_circle(Vector2(-5, -f.h + 1), 10, Color(Color("4fb04a"), a))
			ci.draw_set_transform(Vector2.ZERO, 0.0)


# --- drawing -----------------------------------------------------------------------------------

func _draw_backdrop(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, SKY_TOP, WIDTH, -SKY_TOP), Color("8fd3f4"))
	ci.draw_rect(Rect2(0, -260.0, WIDTH, 260.0), Color("b5e3f7"))
	for i in 14:
		var cx := 300.0 + i * 560.0 + (i * 137) % 200
		var cy := -420.0 + (i * 71) % 160
		for k in 3:
			ci.draw_circle(Vector2(cx + k * 34, cy - (k % 2) * 14), 30, Color(1, 1, 1, 0.85))
	# The hill: a gentle mound around the shaft, the high ridge out to the Keep's peak.
	_mound(ci, SHAFT_X + 300, 2600.0, 170.0, Color("9fd18b"))
	_mound(ci, 4700, 2600.0, 230.0, Color("93c97f"))
	_mound(ci, 7420, 2000.0, 380.0, Color("86bf73"))
	_mound(ci, SHAFT_X, 1500.0, 110.0, Color("aedb98"))


func _mound(ci: CanvasItem, cx: float, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(cx - w * 0.5 + u * w, -h * pow(sin(u * PI), 1.6)))
	pts.append(Vector2(cx + w * 0.5, 4))
	pts.append(Vector2(cx - w * 0.5, 4))
	ci.draw_colored_polygon(pts, col)


func _draw_ground(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, WIDTH, GROUND_DEPTH), Color("6b4a2b"))
	ci.draw_rect(Rect2(0, 0, WIDTH, 8), Color("4f9a3a"))
	ci.draw_rect(Rect2(0, 0, WIDTH, 3), Color("7ccf52"))
	# Pond: a dark basin with water over the edge.
	var basin := PackedVector2Array()
	var water := PackedVector2Array()
	for i in 25:
		var u := float(i) / 24.0
		var x := POND.position.x + u * POND.size.x
		var d := sin(u * PI)
		basin.append(Vector2(x, -3 + 34 * d))
		water.append(Vector2(x, -3 + 30 * d))
	basin.append(Vector2(POND.position.x, -3))
	ci.draw_colored_polygon(basin, Color("4a3420"))
	ci.draw_colored_polygon(water, Color(0.25, 0.55, 0.85))
	ci.draw_rect(Rect2(POND.position.x + 4, -4, POND.size.x - 8, 4), Color(0.25, 0.55, 0.85))
	for k in 3:
		var wx := POND.position.x + 40 + k * 90
		ci.draw_line(Vector2(wx, 5 + k * 3), Vector2(wx + 26, 5 + k * 3), Color(1, 1, 1, 0.5), 2.0)
	ci.draw_line(Vector2(POND.position.x + 6, -3), Vector2(POND.end.x - 6, -3), Color(1, 1, 1, 0.7), 2.0)
	# A faint tick per plot on cleared ground.
	for cell in range(1, CELLS):
		if cell_owner(cell) != &"" or cell_owner(cell - 1) != &"":
			continue
		var c := cell * 3
		if _h[c] == 0 and _h[c - 1] == 0:
			ci.draw_line(Vector2(cell * PLOT, 1), Vector2(cell * PLOT, 6), Color(0.2, 0.4, 0.15, 0.5), 2.0)


func _draw_scrub(ci: CanvasItem) -> void:
	for c in COLS:
		var h := _h[c]
		if h == 0:
			continue
		var x := c * TILE
		var top := -h * TILE
		match _kind[c]:
			Scrub.TREE:
				if h == _h0[c]:
					var trunk := Rect2(x + 4, top + 18, 8, h * TILE - 18)
					ci.draw_rect(trunk.grow(1.5), OUTLINE)
					ci.draw_rect(trunk, Color("8a5a2b"))
					var cc := Vector2(x + 8, top + 12)
					ci.draw_circle(cc, 16.5, OUTLINE)
					ci.draw_circle(cc, 15, Color("2f8a3a"))
					ci.draw_circle(cc + Vector2(-5, -4), 9, Color("4fb04a"))
				else:
					var trunk := Rect2(x + 4, top, 8, h * TILE)
					ci.draw_rect(trunk.grow(1.5), OUTLINE)
					ci.draw_rect(trunk, Color("8a5a2b"))
					ci.draw_rect(Rect2(x + 4, top, 8, 3), Color("e2c08a"))
			Scrub.ROCK:
				var left_join := c > 0 and _wide[c - 1] == 1 and _h[c - 1] > 0
				var right_join := _wide[c] == 1 and c + 1 < COLS and _h[c + 1] > 0
				var r := Rect2(x + (0 if left_join else 1), top + 2, TILE - (0 if left_join else 1) - (0 if right_join else 1), h * TILE - 2)
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color("8d97a3")
				sb.border_color = OUTLINE
				sb.set_border_width_all(2)
				sb.corner_radius_top_left = 0 if left_join else 6
				sb.corner_radius_bottom_left = 0 if left_join else 2
				sb.corner_radius_top_right = 0 if right_join else 6
				sb.corner_radius_bottom_right = 0 if right_join else 2
				if left_join:
					sb.border_width_left = 0
				if right_join:
					sb.border_width_right = 0
				ci.draw_style_box(sb, r)
				ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 4, 3), Color("b8c0ca"))
				ci.draw_line(Vector2(x + 10, top + 5), Vector2(x + 7, top + 11), Color("5d6670"), 1.5)
			_:
				var r := Rect2(x + 2, -11, 12, 11)
				ci.draw_rect(r.grow(1.5), OUTLINE)
				ci.draw_rect(r, Color("8a5a2b"))
				ci.draw_rect(Rect2(x + 2, -11, 12, 3), Color("e2c08a"))
				ci.draw_circle(Vector2(x + 8, -10), 1.5, Color("8a5a2b"))


func _draw_head_frame(ci: CanvasItem) -> void:
	var o := Vector2(SHAFT_X, 0)
	var timber := Color("8a5a2b")
	var dark := Color(0.07, 0.06, 0.09)
	ci.draw_rect(Rect2(o + Vector2(-20, 0), Vector2(40, 10)), dark)
	for s in [-1.0, 1.0]:
		ci.draw_line(o + Vector2(32 * s, 0), o + Vector2(8 * s, -104), dark, 8.0)
		ci.draw_line(o + Vector2(32 * s, 0), o + Vector2(8 * s, -104), timber, 5.0)
	for y: float in [-44.0, -76.0]:
		var half := 32.0 - (-y / 104.0) * 24.0
		ci.draw_line(o + Vector2(-half, y), o + Vector2(half, y), dark, 7.0)
		ci.draw_line(o + Vector2(-half, y), o + Vector2(half, y), timber, 4.0)
	ci.draw_circle(o + Vector2(0, -108), 15, dark)
	ci.draw_circle(o + Vector2(0, -108), 12, Color("c9c9c9"))
	ci.draw_circle(o + Vector2(0, -108), 4, dark)
	ci.draw_line(o + Vector2(0, -108), o + Vector2(0, -38), dark, 2.0)
	ci.draw_rect(Rect2(o + Vector2(-17, -37), Vector2(34, 37)), dark)
	ci.draw_rect(Rect2(o + Vector2(-14, -34), Vector2(28, 34)), Color(0.16, 0.14, 0.18).lerp(Color("f2c94c"), cage_flash))
	for bx in [-9.0, -3.0, 3.0, 9.0]:
		ci.draw_line(o + Vector2(bx, -34), o + Vector2(bx, -34 + 34 * cage_flash), Color("c9c9c9"), 2.0)
	ci.draw_rect(Rect2(o + Vector2(-17, -40), Vector2(34, 4)), Color("f2c94c"))


## The shared pile as a heap of block squares (capped), colour by block.
func _draw_pile(ci: CanvasItem) -> void:
	var counts: Array = []
	var total := 0
	for b in BLOCK_ORDER:
		var n := Inventory.count(b)
		if n > 0:
			counts.append([b, n])
			total += n
	if total == 0:
		return
	var cap := 0
	for r in PILE_ROWS:
		cap += PILE_BASE - r
	var squares: Array = []
	for e in counts:
		var n: int = e[1]
		if total > cap:
			n = maxi(1, roundi(float(n) * cap / total))
		for i in n:
			squares.append(block_color(e[0]))
	squares.resize(mini(squares.size(), cap))
	var s := 8.0
	var i := 0
	for r in PILE_ROWS:
		var w := PILE_BASE - r
		var x0 := PILE_X + r * s * 0.5
		for k in w:
			if i >= squares.size():
				return
			var rect := Rect2(x0 + k * s, -(r + 1) * s, s, s)
			ci.draw_rect(rect, squares[i])
			ci.draw_rect(rect, OUTLINE, false, 1.0)
			i += 1


func _draw_ruins(ci: CanvasItem) -> void:
	for r in RUINS:
		var rect := ruin_rect(r.id)
		match r.id:
			&"old_shed":
				_ruin_shed(ci, rect, r.id)
			&"crooked_watchtower":
				_ruin_tower(ci, rect, r.id)
			&"flooded_cabin":
				_ruin_cabin(ci, rect, r.id)
			&"ruined_keep":
				_ruin_keep(ci, rect, r.id)
	# The gate by the Old Shed and a rusty fence.
	var rust := Color("9b5a3c")
	for x in [8.0, 40.0, 72.0]:
		ci.draw_rect(Rect2(x - 3, -34, 6, 34), OUTLINE)
		ci.draw_rect(Rect2(x - 2, -33, 4, 33), rust)
	for y in [-26.0, -12.0]:
		ci.draw_line(Vector2(8, y), Vector2(72, y + 3), OUTLINE, 4.0)
		ci.draw_line(Vector2(8, y), Vector2(72, y + 3), rust, 2.0)


func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, OUTLINE, 3.0)


func _box(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r, col)
	ci.draw_rect(r, OUTLINE, false, 3.0)


## A dark door with an empty silhouette slot (the resident appears there once encountered).
func _door(ci: CanvasItem, r: Rect2, id: StringName) -> void:
	_box(ci, r, Color("4a3424"))
	var c := r.get_center() + Vector2(0, r.size.y * 0.08)
	var head := Vector2(c.x, r.position.y + r.size.y * 0.28)
	var hr := r.size.x * 0.2
	var body := Rect2(c.x - r.size.x * 0.3, head.y + hr * 0.9, r.size.x * 0.6, r.end.y - head.y - hr * 0.9 - 3)
	var slot := Color(0.85, 0.78, 0.62)
	if _silhouette.get(id, false):
		ci.draw_circle(head, hr, Color(0.03, 0.03, 0.05))
		ci.draw_rect(body, Color(0.03, 0.03, 0.05))
	ci.draw_arc(head, hr, 0, TAU, 20, slot, 2.0)
	ci.draw_rect(body, slot, false, 2.0)


func _ruin_shed(ci: CanvasItem, r: Rect2, id: StringName) -> void:
	var plank := Color("8b7a66")
	var x := r.position.x
	var w := r.size.x
	_poly(ci, PackedVector2Array([Vector2(x + 6, 0), Vector2(x + 10, -54), Vector2(x + w - 10, -44), Vector2(x + w - 4, 0)]), plank)
	for i in 4:
		var px := x + 18 + i * 18
		ci.draw_line(Vector2(px, -4), Vector2(px + 2, -46 + i * 2), Color("6d5e4e"), 2.0)
	_door(ci, Rect2(x + w * 0.36, -40, 28, 40), id)
	# The collapsed roof, slid down one side.
	_poly(ci, PackedVector2Array([Vector2(x - 4, -40), Vector2(x + w * 0.55, -74), Vector2(x + w + 6, -30), Vector2(x + w, -22), Vector2(x + w * 0.55, -62), Vector2(x + 2, -32)]), Color("5f6b58"))
	ci.draw_rect(Rect2(x + w - 18, -10, 22, 10), plank)


func _ruin_tower(ci: CanvasItem, r: Rect2, id: StringName) -> void:
	var x := r.position.x
	var w := r.size.x
	var lean := 22.0
	var top := -r.size.y + 14
	var stone := Color("a39e93")
	_poly(ci, PackedVector2Array([Vector2(x + 14, 0), Vector2(x + 14 + lean, top), Vector2(x + w - 14 + lean, top), Vector2(x + w - 14, 0)]), stone)
	for k in 5:
		var y := -18.0 - k * 22.0
		var off := lean * (-y / -top)
		ci.draw_line(Vector2(x + 16 + off, y), Vector2(x + w - 16 + off, y), Color("7d786e"), 2.0)
	# Broken platform and a crooked little roof.
	_poly(ci, PackedVector2Array([Vector2(x + 2 + lean, top), Vector2(x + w + 4 + lean, top - 4), Vector2(x + w + lean, top + 8), Vector2(x + 4 + lean, top + 10)]), Color("8a5a2b"))
	_poly(ci, PackedVector2Array([Vector2(x + 12 + lean, top - 4), Vector2(x + w * 0.45 + lean + 6, top - 40), Vector2(x + w - 26 + lean, top - 6)]), Color("6b4a3a"))
	_door(ci, Rect2(x + w * 0.5 - 14, -42, 28, 42), id)
	_box(ci, Rect2(x + w * 0.5 - 6 + lean * 0.6, -100, 12, 16), Color(0.12, 0.1, 0.1))


func _ruin_cabin(ci: CanvasItem, r: Rect2, id: StringName) -> void:
	var x := r.position.x
	var w := r.size.x
	var logc := Color("8a5a2b")
	# Sunk and tilted: the left side sits lower in the pond.
	_poly(ci, PackedVector2Array([Vector2(x + 6, 12), Vector2(x + 4, -50), Vector2(x + w - 4, -60), Vector2(x + w - 6, 8)]), logc)
	for k in 4:
		var y := -6.0 - k * 13.0
		ci.draw_line(Vector2(x + 6, y + 2), Vector2(x + w - 6, y - 3), Color("6b4220"), 2.0)
	_poly(ci, PackedVector2Array([Vector2(x - 6, -48), Vector2(x + w * 0.5, -88), Vector2(x + w + 4, -62), Vector2(x + w * 0.5 + 6, -70)]), Color("5b3a26"))
	_door(ci, Rect2(x + w * 0.38, -44, 28, 48), id)
	# Water over the bottom of the cabin.
	ci.draw_rect(Rect2(x - 8, -3, w + 16, 17), Color(0.25, 0.55, 0.85, 0.8))
	ci.draw_line(Vector2(x - 4, -1), Vector2(x + w + 4, -1), Color(1, 1, 1, 0.6), 2.0)


func _ruin_keep(ci: CanvasItem, r: Rect2, id: StringName) -> void:
	var x := r.position.x
	var w := r.size.x
	var stone := Color("9a9aa6")
	# The rocky peak it stands on.
	_poly(ci, PackedVector2Array([Vector2(x - 44, 0), Vector2(x - 20, -24), Vector2(x + w * 0.5, -30), Vector2(x + w + 24, -22), Vector2(x + w + 50, 0)]), Color("7b746a"))
	var base := -26.0
	var top := base - r.size.y + 10
	_box(ci, Rect2(x + 8, top, w - 16, base - top), stone)
	# Broken battlements, one tower stub taller.
	for k in 5:
		if k == 3:
			continue
		_box(ci, Rect2(x + 10 + k * 26, top - 14, 18, 16), stone)
	_box(ci, Rect2(x + 4, top - 44, 34, 46), stone)
	_poly(ci, PackedVector2Array([Vector2(x + w - 40, top), Vector2(x + w - 8, top + 24), Vector2(x + w - 8, top)]), Color("8fd3f4"))
	for k in 3:
		ci.draw_line(Vector2(x + 12, top + 30 + k * 30), Vector2(x + w - 12, top + 30 + k * 30), Color("7c7c88"), 2.0)
	_box(ci, Rect2(x + 16, top - 30, 10, 14), Color(0.12, 0.1, 0.1))
	_door(ci, Rect2(x + w * 0.5 - 20, base - 56, 40, 56), id)
