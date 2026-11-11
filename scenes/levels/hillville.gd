## Hillville, the side-view surface: flat ground (top at y = 0) from 0 to WIDTH, scrub to scoop
## (trees, rocks, stumps), four ruins with a silhouette slot on the door, the mine shaft head-frame
## with its cage, and the shaft pile (the shared Inventory as a heap of block squares).
## Sandbox art (assets/sprites): a sky from TimeOfDay, parallax rows, a baked ground, sprite
## scrub, ruins, head-frame and pile. World layers take TimeOfDay.world_tint(); players do not.
## Scrub never collides.
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
	[47, 49, &"shelf"],
	[104, 106, &"pond"],
	[108, 110, &"pond"],
	[152, 153, &"keep_rock"],
	[156, 160, &"keep_rock"],
]
const POND := Rect2(104 * 48, -3, 6 * 48, 17)
const PILE_X := 41 * 48 + 4.0
const PILE_BASE := 6
const PILE_ROWS := 6
const ICON_COL := {&"dirt": 0, &"clay": 1, &"stone": 2, &"ice": 3, &"crystal": 4, &"edgestone": 5, &"strangestone": 6, &"sand": 7, &"pebbles": 8, &"pipe": 9, &"ore": 10, &"geode": 11, &"gaterock": 12, &"hardrock": 13}
const BLOCK_ORDER := [&"dirt", &"clay", &"pebbles", &"pipe", &"stone", &"ore", &"geode", &"sand", &"ice", &"crystal", &"strangestone", &"edgestone"]
const BLOCK_DIR := "res://data/blocks/"
const OUTLINE := Color(0.23, 0.16, 0.27)
const CREAM := Color("f4e8c8")
const GROUND_ROWS := 10
## H-03: the Excavator digs ponds in free ground. Tiles deep a hollow can go, how long the water
## takes to fill it (after a short wait), and the pond-dirt colour.
const POND_DEEP := 2
const POND_WAIT := 0.25
const POND_FILL := 0.9
const HOLLOW := Color("5b3a22")
const REST_CAM := Vector2(SHAFT_X, -95.0)   # where the parallax anchors line up with the world
const CLOUD_RANGE := Vector2(700.0, 4800.0)
const WARM := Color(1.0, 0.78, 0.45)

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
var _restored := {}                   # ruin id -> true once rebuilt (RuinSites draws the new building)
var _fx: Array = []
var _cells_kind := {}                 # cell -> zone/ruin StringName

var _ruins: _Layer
var _shaft: _Layer
var _pile: _Layer
var _scrub: _Layer
var _ground: _Layer
var _fx_layer: _Layer
var _buildings: Node2D
var _players: Node2D
var _pond: _Layer
var _lights: Node2D
var _sky: _Layer
var _sun: Sprite2D
var _moon: Sprite2D
var _stars: Sprite2D
var _clouds: Array[Sprite2D] = []
var _rows: Array[Sprite2D] = []
var _head_lit: Sprite2D
var _head_glow: Sprite2D
var _door_glows := {}                 # ruin id -> Sprite2D
var _ground_tex: Texture2D
var _water_frame := 0
var _water_t := 0.0
var _sky_t := 1.0
var _dug := PackedByteArray()          # H-03: tiles dug out of the ground per column (a pond)
var _wet := PackedFloat32Array()       # 0..1 water in that hollow; < 0 waits to fill
## H-05: 0..1 how far the pile leans after the wrecking ball (it springs back).
var pile_lean := 0.0:
	set(v):
		pile_lean = v
		if _pile != null:
			_pile.queue_redraw()

static var _block_colors := {}


class _Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


## Calls fn(delta) every frame (cloud drift, the sky refresh, pond waves).
class _Ticker extends Node:
	var fn: Callable

	func _process(delta: float) -> void:
		fn.call(delta)


func _init() -> void:
	name = "Hillville"
	_generate()
	_build_nodes()


func _ready() -> void:
	Events.inventory_changed.connect(_on_inventory_changed)
	TimeOfDay.phase_changed.connect(_on_phase_changed)
	_apply_time()


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
	_build_backdrop()
	_ruins = _layer("Ruins", _draw_ruins)
	_shaft = _layer("Shaft", _draw_head_frame)
	_pile = _layer("Pile", _draw_pile)
	_scrub = _layer("Scrub", _draw_scrub)
	_ground = _layer("GroundArt", _draw_ground)
	_ground_tex = HillvilleArt.bake_ground(COLS, GROUND_ROWS, _carved)
	_pond = _layer("Pond", _draw_pond)
	_build_lights()
	_buildings = Node2D.new()
	_buildings.name = "Buildings"
	add_child(_buildings)
	_players = Node2D.new()
	_players.name = "Players"
	add_child(_players)
	_fx_layer = _layer("Fx", _draw_fx)
	var tick := _Ticker.new()
	tick.name = "Clock"
	tick.fn = _tick
	add_child(tick)
	_apply_time()
	set_process(false)


func _exit_tree() -> void:
	if Events.inventory_changed.is_connected(_on_inventory_changed):
		Events.inventory_changed.disconnect(_on_inventory_changed)
	if TimeOfDay.phase_changed.is_connected(_on_phase_changed):
		TimeOfDay.phase_changed.disconnect(_on_phase_changed)


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


## PT10-5: the scrub column a scoop from `at` facing `facing` would hit first (the same reach as
## scoop() with a 1-wide area), or -1. On foot nothing clears it: the player bonks it instead.
func scrub_in_reach(at: Vector2, facing: int) -> int:
	var dir := 1 if facing >= 0 else -1
	var c0 := floori(at.x / TILE)
	for i in 2:
		var c := c0 + i * dir
		if c >= 0 and c < COLS and _h[c] > 0:
			return c
	return -1


## PT10-5: a bonk on scrub by hand: it shakes (leaves or grit fly, nothing goes) and stays.
func bonk_scrub(c: int) -> void:
	if c < 0 or c >= COLS or _h[c] <= 0:
		return
	var cx := c * TILE + TILE * 0.5
	var top := -float(_h[c]) * TILE
	var leafy := _kind[c] == Scrub.TREE
	var col := Color("6fae4a") if leafy else (Color("8d97a3") if _kind[c] == Scrub.ROCK else Color("8a5a2b"))
	for i in 5:
		_fx.append({"k": "p", "pos": Vector2(cx, top + 4), "vel": Vector2(randf_range(-60, 60), randf_range(-120, -40)),
				"life": 0.0, "max": 0.5, "col": col, "r": randf_range(1.5, 3.0), "g": 420.0, "sq": not leafy})
	_wake_fx()


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
	var d := ""
	for k in _dug:
		d += str(k)
	return {"seed": layout_seed, "left": s, "ponds": d}


func load_save(data: Dictionary) -> void:
	var sd := int(data.get("seed", layout_seed))
	if sd != layout_seed:
		set_layout_seed(sd)
	var s := str(data.get("left", ""))
	for c in mini(s.length(), COLS):
		_h[c] = mini(_h0[c], int(s[c]))
	var d := str(data.get("ponds", ""))
	for c in mini(d.length(), COLS):
		_dug[c] = clampi(int(d[c]), 0, POND_DEEP)
		_wet[c] = 1.0
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


## What owns plot cell `cell`: a ruin id, &"shaft", &"pile", &"shelf", &"pond", &"gate", &"keep_rock",
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
			if _h[cell * 3 + k] > 0 or _dug[cell * 3 + k] > 0:
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


## A restored ruin is no longer drawn (RuinSites stands the new building there) and its door
## light stays on.
func set_ruin_restored(ruin_id: StringName, on := true) -> void:
	_restored[ruin_id] = on
	if _ruins != null:
		_ruins.queue_redraw()
	_apply_time()


func is_ruin_restored(ruin_id: StringName) -> bool:
	return _restored.get(ruin_id, false)


## A dust puff (Hillville-local), used by scoops and buildings.
func puff(at: Vector2, color := CREAM, n := 10) -> void:
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
	_dug.resize(COLS)
	_dug.fill(0)
	_wet.resize(COLS)
	_wet.fill(0.0)
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
	for l in [_ruins, _shaft, _pile, _scrub, _ground, _pond]:
		if l != null:
			l.queue_redraw()


# --- H-03: dug ponds --------------------------------------------------------------------------

## Tiles dug out of tile column c (0 = flat ground).
func pond_depth(c: int) -> int:
	return _dug[c] if c >= 0 and c < COLS else 0


## 0..1 water in the hollow of column c.
func pond_water(c: int) -> float:
	return clampf(_wet[c], 0.0, 1.0) if c >= 0 and c < COLS else 0.0


## Columns a dug pond covers (tests / demo).
func pond_columns() -> Array[int]:
	var out: Array[int] = []
	for c in COLS:
		if _dug[c] > 0:
			out.append(c)
	return out


## May tile column c be dug into a pond? Free yard (no ruin, shaft, pile, the old pond), no scrub
## and no placed building on it.
func pond_ok(c: int) -> bool:
	if c < 0 or c >= COLS or _h[c] > 0:
		return false
	if cell_owner(c / 3) != &"":
		return false
	for b: Dictionary in Progress.buildings:
		var d := Progress.building_data(b.id)
		var w := d.footprint.x if d != null else 1
		if c >= b.cell.x * 3 and c < (b.cell.x + w) * 3:
			return false
	return true


## The Excavator's A up top on bare ground: digs `wide` columns ahead of the bucket one tile
## deeper (up to POND_DEEP); the dirt goes to the pile and water seeps in to fill the hollow.
## 0 when there is scrub to scoop first, or nothing here may be dug (the old pond splashes).
## Returns tiles dug.
func dig_pond(at: Vector2, facing: int, wide: int, player := -1) -> int:
	var dir := 1 if facing >= 0 else -1
	var c0 := floori(at.x / TILE)
	for i in wide + 1:
		if scrub_at(c0 + i * dir) > 0:
			return 0
	var n := 0
	var full := 0
	var first := c0 + dir
	for i in wide:
		var c := first + i * dir
		if not pond_ok(c):
			continue
		if _dug[c] >= POND_DEEP:
			full += 1
			continue
		_dug[c] += 1
		_wet[c] = minf(_wet[c], 0.0) - POND_WAIT / POND_FILL
		n += 1
		var cx := c * TILE + TILE * 0.5
		for k in 3:
			_fx.append({"k": "p", "pos": Vector2(cx, _dug[c] * TILE - 4.0), "vel": Vector2(randf_range(-60, 60) + dir * 40, randf_range(-230, -120)),
					"life": 0.0, "max": 0.7, "col": Color("8a5a2b"), "r": randf_range(2.5, 4.0), "g": 620.0, "sq": true})
	if n > 0:
		Inventory.add(&"dirt", n)
		puff(Vector2((first + dir * (wide - 1) * 0.5) * TILE + TILE * 0.5, 0), Color("e0c89a"), 8)
		Audio.play("scoop")
		_pond.queue_redraw()
		_wake_fx()
		return n
	if full > 0:
		# Already a full pond: the bucket splashes in it.
		_splash(Vector2((first + dir * (wide - 1) * 0.5) * TILE + TILE * 0.5, -2.0))
		Audio.play("splash")
		return -1
	return 0


func _splash(at: Vector2) -> void:
	for i in 10:
		_fx.append({"k": "p", "pos": at + Vector2(randf_range(-14, 14), 0), "vel": Vector2(randf_range(-70, 70), randf_range(-220, -110)),
				"life": 0.0, "max": 0.6, "col": Color(0.55, 0.8, 1.0), "r": randf_range(2.0, 3.5), "g": 600.0})
	_wake_fx()


## Water seeping into new hollows (from _tick).
func _fill_ponds(delta: float) -> void:
	var changed := false
	var started := false
	for c in COLS:
		if _dug[c] == 0 or _wet[c] >= 1.0:
			continue
		var was := _wet[c]
		_wet[c] = minf(1.0, _wet[c] + delta / POND_FILL)
		changed = true
		if was <= 0.0 and _wet[c] > 0.0:
			started = true
			if c % 2 == 0:
				_fx.append({"k": "p", "pos": Vector2(c * TILE + TILE * 0.5, _dug[c] * TILE - 2.0), "vel": Vector2(0, -40),
						"life": 0.0, "max": 0.8, "col": Color(0.75, 0.92, 1.0, 0.9), "r": 2.0, "g": -20.0})
	if started:
		Audio.play("flood")
		_wake_fx()
	if changed:
		_pond.queue_redraw()


## H-05: the wrecking ball knocks the pile: it leans away, blocks tumble off the top, it springs back.
func knock_pile(dir: int) -> void:
	var n := 0
	for b in BLOCK_ORDER:
		n += Inventory.count(b)
	var top := -minf(float(PILE_ROWS), ceilf(n / 4.0)) * TILE
	var cx := PILE_X + PILE_BASE * TILE * 0.5
	for b in BLOCK_ORDER:
		if Inventory.count(b) <= 0:
			continue
		for i in 3:
			_fx.append({"k": "p", "pos": Vector2(cx + randf_range(-20, 20), top + 4.0), "vel": Vector2(dir * randf_range(60, 160), randf_range(-240, -120)),
					"life": 0.0, "max": 0.8, "col": block_color(b), "r": 4.0, "g": 640.0, "sq": true})
	puff(Vector2(cx, 0), Color("e0c89a"), 8)
	_wake_fx()
	var t := create_tween()
	t.tween_property(self, "pile_lean", dir * 1.0, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "pile_lean", 0.0, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Pile x span (the wrecking ball's target).
func pile_span() -> Vector2:
	return Vector2(PILE_X, PILE_X + PILE_BASE * TILE)


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
			puff(Vector2(cx, 0), Color("e6e2d4"), 6)
		_:
			Audio.play("stump_pop")
			_fx.append({"k": "p", "pos": Vector2(cx, -8), "vel": Vector2(dir * 40, -260), "life": 0.0, "max": 0.7,
					"col": Color("8a5a2b"), "r": 7.0, "g": 700.0, "sq": true})
			puff(Vector2(cx, 0), Color("e0c89a"), 8)


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
			puff(f.pos + Vector2(f.dir * f.h * 0.8, 0), Color("b8e0a0"), 10)
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
			var tt := HillvilleArt.tex("props/tree.png")
			if tt != null:
				var fr := HillvilleArt.frame("tree", Vector2(32, 64))
				var tiles := clampi(roundi(f.h / float(TILE)), 1, 4)
				ci.draw_texture_rect_region(tt, Rect2(-fr.x * 0.5, -fr.y, fr.x, fr.y),
						Rect2((4 - tiles) * fr.x, (0 if f.crown else 1) * fr.y, fr.x, fr.y), Color(1, 1, 1, a))
			ci.draw_set_transform(Vector2.ZERO, 0.0)


# --- drawing -----------------------------------------------------------------------------------

func _carved(c: int, _r: int) -> bool:
	var sc := int(SHAFT_X / TILE)
	return c == sc - 1 or c == sc


func _pin(sp: Sprite2D, pos: Vector2) -> void:
	sp.position = pos
	(sp.material as ShaderMaterial).set_shader_parameter("anchor", REST_CAM - pos)


func _sprite(n: String, tx: Texture2D, factor: Vector2, pos: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = n
	sp.texture = tx
	sp.centered = false
	sp.material = HillvilleArt.parallax_material(factor)
	_pin(sp, pos)
	return sp


func _build_backdrop() -> void:
	var back := Node2D.new()
	back.name = "Backdrop"
	add_child(back)
	_sky = _Layer.new()
	_sky.name = "Sky"
	_sky.fn = _draw_sky
	back.add_child(_sky)
	var sheet := "surface/sky_bits.png"
	var star_r := HillvilleArt.region("sky_bits", "stars")
	var stars_tex := HillvilleArt.cut(sheet, Rect2i(star_r))
	if stars_tex != null:
		_stars = _sprite("Stars", stars_tex, Vector2(0.03, 0.05), Vector2(SHAFT_X - 1600, -420))
		_stars.region_enabled = true
		_stars.region_rect = Rect2(0, 0, 3200, 320)
		_stars.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		back.add_child(_stars)
	var sheet_tex := HillvilleArt.tex(sheet)
	if sheet_tex != null:
		for k in ["sun", "moon"]:
			var r := HillvilleArt.region("sky_bits", k)
			var at := AtlasTexture.new()
			at.atlas = sheet_tex
			at.region = r
			var sp := _sprite(k.capitalize(), at, Vector2(0.02, 0.3), Vector2.ZERO)
			sp.offset = -r.size * 0.5
			sp.centered = false
			back.add_child(sp)
			if k == "sun":
				_sun = sp
			else:
				_moon = sp
		for i in 7:
			var r := HillvilleArt.region("sky_bits", "cloud%d" % (i % 3))
			var at := AtlasTexture.new()
			at.atlas = sheet_tex
			at.region = r
			var x := CLOUD_RANGE.x + (CLOUD_RANGE.y - CLOUD_RANGE.x) * (float(i) + 0.5) / 7.0
			var sp := _sprite("Cloud%d" % i, at, Vector2(0.25, 0.6), Vector2(x, -330.0 + (i * 53) % 170))
			sp.scale = Vector2(1.5, 1.5) if i % 2 == 0 else Vector2(1, 1)
			back.add_child(sp)
			_clouds.append(sp)
	# Far mountains, hills, tree line: each its own repeating strip.
	var strip := HillvilleArt.frame("parallax_hillville", Vector2(512, 96))
	var spec := [
		["Mountains", 0, Vector2(0.2, 0.5), -14.0],
		["Hills", 1, Vector2(0.4, 0.65), -6.0],
		["Trees", 2, Vector2(0.6, 0.8), 6.0],
	]
	for e in spec:
		var tx := HillvilleArt.cut("parallax/hillville.png", Rect2i(0, int(e[1]) * int(strip.y), int(strip.x), int(strip.y)))
		if tx == null:
			continue
		var sp := _sprite(e[0], tx, e[2], Vector2(-1000, float(e[3]) - strip.y))
		sp.region_enabled = true
		sp.region_rect = Rect2(0, 0, 8000, strip.y)
		sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		back.add_child(sp)
		_rows.append(sp)


func _build_lights() -> void:
	_lights = Node2D.new()
	_lights.name = "Lights"
	add_child(_lights)
	var hf := HillvilleArt.entry("headframe")
	var fr := HillvilleArt.frame("headframe", Vector2(96, 124))
	var pv := HillvilleArt.point("headframe", "pivot", Vector2(48, 124))
	var org := Vector2(SHAFT_X, 0) - pv
	var lit_path: String = str(hf.get("lit", ""))
	if lit_path != "" and HillvilleArt.tex(lit_path) != null:
		_head_lit = Sprite2D.new()
		_head_lit.name = "HeadFrameLit"
		_head_lit.texture = HillvilleArt.tex(lit_path)
		_head_lit.centered = false
		_head_lit.position = org
		_lights.add_child(_head_lit)
	var glow := HillvilleArt.tex("fx/glow.png")
	if glow != null:
		_head_glow = _glow("LanternGlow", glow, org + HillvilleArt.point("headframe", "lantern", fr * 0.5), 3.0)
		for r in RUINS:
			var door := HillvilleArt.point(String(r.id), "door")
			var win := HillvilleArt.tex("fx/window.png")
			if door != Vector2.ZERO and win != null:
				var rect := ruin_rect(r.id)
				var origin := Vector2(rect.position.x, rect.end.y) - Vector2(0, HillvilleArt.frame(String(r.id)).y)
				_door_glows[r.id] = _glow("DoorGlow_" + String(r.id), win, origin + door, 2.0)


func _glow(n: String, tx: Texture2D, at: Vector2, k: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = n
	sp.texture = tx
	sp.material = HillvilleArt.additive()
	sp.position = at
	sp.scale = Vector2(k, k)
	sp.modulate = Color(WARM, 0.0)
	_lights.add_child(sp)
	return sp


func _on_phase_changed(_p: StringName) -> void:
	_apply_time()


func _tick(delta: float) -> void:
	var drift := 5.0 * delta
	for c in _clouds:
		c.position.x += drift
		if c.position.x > CLOUD_RANGE.y:
			c.position.x -= CLOUD_RANGE.y - CLOUD_RANGE.x
		(c.material as ShaderMaterial).set_shader_parameter("anchor", REST_CAM - c.position)
	_sky_t += delta
	if _sky_t >= 0.25:
		_sky_t = 0.0
		_apply_time()
	_fill_ponds(delta)
	_water_t += delta
	if _water_t >= 0.33:
		_water_t = 0.0
		_water_frame = 1 - _water_frame
		if _pond != null:
			_pond.queue_redraw()


## Sky, sun/moon, stars, the world tint and the lamps for the current TimeOfDay.
func _apply_time() -> void:
	if _sky == null:
		return
	var tint := TimeOfDay.world_tint()
	var lights := TimeOfDay.lights()
	_sky.queue_redraw()
	for n in [_ruins, _shaft, _pile, _scrub, _ground, _pond, _buildings, _fx_layer]:
		if n != null:
			n.modulate = tint
	for sp in _rows:
		sp.modulate = tint
	for sp in _clouds:
		sp.modulate = tint.lerp(Color.WHITE, 0.3)
	var t := TimeOfDay.time
	if _stars != null:
		_stars.modulate = Color(1, 1, 1, clampf((lights - 0.4) / 0.6, 0.0, 1.0))
	if _sun != null:
		var u := clampf(t / 0.66, 0.0, 1.0)
		_pin(_sun, Vector2(SHAFT_X + lerpf(-210.0, 210.0, u), -30.0 - 210.0 * pow(sin(u * PI), 0.8)))
		_sun.visible = t < 0.68
		_sun.modulate = Color(1, 1, 1, clampf((0.68 - t) / 0.12, 0.0, 1.0))
	if _moon != null:
		var mt := t if t >= 0.5 else t + 1.0
		var mu := clampf((mt - 0.64) / 0.42, 0.0, 1.0)
		_pin(_moon, Vector2(SHAFT_X + lerpf(-210.0, 210.0, mu), -30.0 - 190.0 * pow(sin(mu * PI), 0.8)))
		_moon.modulate = Color(1, 1, 1, clampf((lights - 0.5) / 0.5, 0.0, 1.0))
	if _head_lit != null:
		_head_lit.modulate = Color(1, 1, 1, lights)
	if _head_glow != null:
		_head_glow.modulate = Color(WARM, 0.55 * lights)
	for id in _door_glows:
		var sp: Sprite2D = _door_glows[id]
		if _restored.get(id, false):
			sp.modulate = Color(WARM, 0.0)   # RuinSites lights the new building's door
		else:
			sp.modulate = Color(WARM, (0.9 if _silhouette.get(id, false) else 0.4) * lights)


func _draw_sky(ci: CanvasItem) -> void:
	var top := TimeOfDay.sky_top()
	var hor := TimeOfDay.sky_horizon()
	var x0 := -800.0
	var w := WIDTH + 1600.0
	var n := 12
	var h := -SKY_TOP / n
	for i in n:
		var u := (float(i) + 0.5) / n
		ci.draw_rect(Rect2(x0, SKY_TOP + i * h, w, h + 1.0), top.lerp(hor, pow(u, 1.3)))
	var b := TimeOfDay.band()
	if b.a > 0.01:
		for k in 4:
			ci.draw_rect(Rect2(x0, -200.0 + k * 50.0, w, 51.0), Color(b, b.a * 0.18 * (k + 1)))


func _draw_ground(ci: CanvasItem) -> void:
	if _ground_tex != null:
		ci.draw_texture(_ground_tex, Vector2.ZERO)
	else:
		ci.draw_rect(Rect2(0, 0, WIDTH, GROUND_DEPTH), Color("8b5a2b"))
		ci.draw_rect(Rect2(0, 0, WIDTH, 4), Color("5aa84a"))


## The pond: A water over the dirt (shallow at the edges, deeper in the middle).
func _draw_pond(ci: CanvasItem) -> void:
	_draw_dug(ci)
	var wt := HillvilleArt.tex("tiles/water.png")
	if wt == null:
		ci.draw_rect(Rect2(POND.position.x, -3, POND.size.x, 17), Color(0.25, 0.55, 0.85, 0.8))
		return
	var c0 := int(POND.position.x / TILE)
	var c1 := int(POND.end.x / TILE)
	var cab := ruin_rect(&"flooded_cabin")
	for c in range(c0, c1):
		var x := c * TILE
		var f := (c / 2 + _water_frame) % 2
		var in_cabin := x >= cab.position.x and x < cab.end.x
		var mid := c >= c0 + 3 and c < c1 - 3
		if in_cabin:
			ci.draw_texture_rect_region(wt, Rect2(x, -14, TILE, TILE), Rect2(f * TILE, 0, TILE, TILE))
			for y in [2.0, 18.0]:
				ci.draw_texture_rect_region(wt, Rect2(x, y, TILE, TILE), Rect2(f * TILE, TILE, TILE, TILE))
		else:
			ci.draw_texture_rect_region(wt, Rect2(x, -4, TILE, TILE), Rect2(f * TILE, 0, TILE, TILE))
			if mid:
				ci.draw_texture_rect_region(wt, Rect2(x, 12, TILE, TILE), Rect2(f * TILE, TILE, TILE, TILE))


## H-03: dug hollows (dark dirt with a lip), and the water rising in them.
func _draw_dug(ci: CanvasItem) -> void:
	var wt := HillvilleArt.tex("tiles/water.png")
	for c in COLS:
		var d := _dug[c]
		if d == 0:
			continue
		var x := c * TILE
		var deep := d * TILE
		var l := _dug[c - 1] if c > 0 else 0
		var r := _dug[c + 1] if c + 1 < COLS else 0
		ci.draw_rect(Rect2(x, -1, TILE, deep + 1), HOLLOW)
		ci.draw_rect(Rect2(x, deep - 3, TILE, 4), HOLLOW.darkened(0.25))
		if l < d:
			ci.draw_rect(Rect2(x, l * TILE, 3, deep - l * TILE), HOLLOW.darkened(0.35))
		if r < d:
			ci.draw_rect(Rect2(x + TILE - 3, r * TILE, 3, deep - r * TILE), HOLLOW.darkened(0.35))
		var w := clampf(_wet[c], 0.0, 1.0)
		if w <= 0.0:
			continue
		var top := lerpf(float(deep), -4.0, w)
		var h := deep - top
		var f := (c / 2 + _water_frame) % 2
		if wt != null:
			ci.draw_texture_rect_region(wt, Rect2(x, top, TILE, minf(TILE, h)), Rect2(f * TILE, 0, TILE, minf(TILE, h)))
			var y := top + TILE
			while y < deep:
				var hh := minf(TILE, deep - y)
				ci.draw_texture_rect_region(wt, Rect2(x, y, TILE, hh), Rect2(f * TILE, TILE, TILE, hh))
				y += TILE
		else:
			ci.draw_rect(Rect2(x, top, TILE, h), Color(0.25, 0.55, 0.85, 0.85))


func _draw_scrub(ci: CanvasItem) -> void:
	var tree := HillvilleArt.tex("props/tree.png")
	var rock := HillvilleArt.tex("props/rock.png")
	var stump := HillvilleArt.tex("props/stump.png")
	var tf := HillvilleArt.frame("tree", Vector2(32, 64))
	var small := HillvilleArt.region("rock", "small")
	var wide := HillvilleArt.region("rock", "wide")
	for c in COLS:
		var h := _h[c]
		if h == 0:
			continue
		var x := c * TILE
		match _kind[c]:
			Scrub.TREE:
				if tree != null:
					var frame_i := clampi(4 - h, 0, 3)
					var row := 0 if h == _h0[c] else 1
					ci.draw_texture_rect_region(tree, Rect2(x + TILE * 0.5 - tf.x * 0.5, -tf.y, tf.x, tf.y),
							Rect2(frame_i * tf.x, row * tf.y, tf.x, tf.y))
			Scrub.ROCK:
				if rock == null:
					continue
				var left_join := c > 0 and _wide[c - 1] == 1 and _h[c - 1] > 0
				var right_join := _wide[c] == 1 and c + 1 < COLS and _h[c + 1] > 0
				if left_join:
					continue   # drawn with its left half
				for k in h:
					if right_join:
						ci.draw_texture_rect_region(rock, Rect2(x, -(k + 1) * TILE, wide.size.x, wide.size.y), wide)
					else:
						ci.draw_texture_rect_region(rock, Rect2(x, -(k + 1) * TILE, small.size.x, small.size.y), small)
			_:
				if stump != null:
					ci.draw_texture(stump, Vector2(x, -TILE))


func _draw_head_frame(ci: CanvasItem) -> void:
	var tx := HillvilleArt.tex("buildings/headframe.png")
	var pv := HillvilleArt.point("headframe", "pivot", Vector2(48, 124))
	var org := Vector2(SHAFT_X, 0) - pv
	if tx != null:
		ci.draw_texture(tx, org)
	var cg: Array = HillvilleArt.entry("headframe").get("cage", [31, 85, 34, 39])
	if cage_flash > 0.0:
		ci.draw_rect(Rect2(org + Vector2(cg[0], cg[1]), Vector2(cg[2], cg[3])), Color("f2c94c", clampf(cage_flash, 0.0, 1.0) * 0.75))


## The shared pile as a heap of block icons (capped), one icon per block id.
func _draw_pile(ci: CanvasItem) -> void:
	var icons := HillvilleArt.tex("icons/blocks.png")
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
			squares.append(e[0])
	squares.resize(mini(squares.size(), cap))
	var i := 0
	for r in PILE_ROWS:
		var w := PILE_BASE - r
		var x0 := PILE_X + r * TILE * 0.5
		for k in w:
			if i >= squares.size():
				return
			var rect := Rect2(x0 + k * TILE + pile_lean * (r + 1) * 5.0, -(r + 1) * TILE, TILE, TILE)
			if icons != null:
				var col: int = ICON_COL.get(squares[i], 0)
				ci.draw_texture_rect_region(icons, rect, Rect2(col * TILE, 0, TILE, TILE))
			else:
				ci.draw_rect(rect, block_color(squares[i]))
			i += 1


func _draw_ruins(ci: CanvasItem) -> void:
	for r in RUINS:
		if _restored.get(r.id, false):
			continue
		var rect := ruin_rect(r.id)
		var tx := HillvilleArt.tex("buildings/%s.png" % r.id)
		var fr := HillvilleArt.frame(String(r.id))
		var origin := Vector2(rect.position.x, rect.end.y - fr.y)
		if tx != null:
			ci.draw_texture(tx, origin)
		var door := HillvilleArt.point(String(r.id), "door")
		if door != Vector2.ZERO:
			_silhouette_slot(ci, origin + door, r.id)
	# The gate by the Old Shed and a rusty fence.
	var rust := Color("9b5a3c")
	for x in [8.0, 40.0, 72.0]:
		ci.draw_rect(Rect2(x - 3, -34, 6, 34), OUTLINE)
		ci.draw_rect(Rect2(x - 2, -33, 4, 33), rust)
	for y in [-26.0, -12.0]:
		ci.draw_line(Vector2(8, y), Vector2(72, y + 3), OUTLINE, 4.0)
		ci.draw_line(Vector2(8, y), Vector2(72, y + 3), rust, 2.0)


## The empty silhouette slot in a door (the resident's dark shape once they were met).
func _silhouette_slot(ci: CanvasItem, door: Vector2, id: StringName) -> void:
	var head := door + Vector2(0, -9)
	var body := Rect2(door.x - 6, door.y - 3, 12, 14)
	if _silhouette.get(id, false):
		ci.draw_circle(head, 5.0, Color(0.05, 0.04, 0.08))
		ci.draw_rect(body, Color(0.05, 0.04, 0.08))
	ci.draw_arc(head, 5.0, 0, TAU, 14, CREAM, 1.0)
	ci.draw_rect(body, CREAM, false, 1.0)
