## TileWorld fixed-seed performance run, no input: two scripted diggers zigzag down a world while
## bodies are spawned at their feet to keep `world.max_awake_bodies` busy. Vsync, the fps cap and the
## headless idle sleep are off so a frame's wall time is its cost. After a 2 s warm-up it measures
## for --seconds of game time, prints a JSON summary and writes it to --out, then quits.
## Simulation cost per physics tick (no renderer; --fixed-fps makes every frame exactly one tick):
##   godot --headless --fixed-fps 60 --path . res://addons/openjar/tileworld/demo/stress.tscn -- --seconds=60
## Whole frames with a real renderer (software GPU here, so it measures the rasteriser too):
##   godot-render --path . --resolution 1920x1080 res://addons/openjar/tileworld/demo/stress.tscn -- --shape=disk
## Args: --seconds=60 --seed=1234 --shape=rect|disk --bodies=60 --out=<path> (default user://tileworld_stress.json)
##   --tile-art=<script path>: a TileArt script (new() with no args) so the run covers the art path,
##   e.g. res://addons/openjar/tileworld/demo/demo_tile_art.gd
extends Node2D

const WARMUP := 2.0
const SPEED := 12.0   # tiles per second
const MAX_ALIVE := 300
const SPAWNS_PER_FRAME := 2
const FRAME_BUDGET_MS := 16.7

var seconds := 60.0
var world_seed := 1234
var disk := false
var bodies_target := 60
var out_path := "user://tileworld_stress.json"
var tile_art_path := ""

var world: TileWorld
var cam: Camera2D
var diggers: Array[Node2D] = []
var paths: Array[Array] = []
var segs: Array[int] = [0, 0]
var last_cells: Array[Vector2i] = [Vector2i(1 << 30, 0), Vector2i(1 << 30, 0)]
var stamp: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()
var alive: Array[FallingBody] = []
var spawned := 0
var spawn_toggle := 0

var elapsed := 0.0
var measuring := false
var measure_time := 0.0
var prev_us := 0
var finished := false

var frame_ms: Array[float] = []
var physics_ticks := 0
var dig_ms: Array[float] = []
var awake_samples: Array[float] = []
var chunk_samples: Array[float] = []
var water_max := 0
var tiles_dug := 0
var chunk_loads := 0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			world_seed = int(a.get_slice("=", 1))
		elif a.begins_with("--shape="):
			disk = a.get_slice("=", 1) == "disk"
		elif a.begins_with("--bodies="):
			bodies_target = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
		elif a.begins_with("--tile-art="):
			tile_art_path = a.get_slice("=", 1)
	rng.seed = world_seed
	for y in range(-1, 2):
		for x in range(-1, 2):
			stamp.append(Vector2i(x, y))
	var shape: WorldShape
	var gen := LayeredGenerator.new()
	if disk:
		shape = DiskShape.new(150)
		gen.bands = [{"from": 0, "tile": 1}, {"from": 3, "tile": 2}, {"from": 30, "tile": 3}]
	else:
		shape = RectShape.new(200, 300)
		gen.surface_depth = 0
		gen.border_tile = 4
		gen.bands = [{"from": 0, "tile": 1}, {"from": 3, "tile": 2}, {"from": 60, "tile": 3}]
	gen.water_from_depth = 40
	world = TileWorld.new()
	world.chunk_radius = 1
	world.max_awake_bodies = bodies_target
	if tile_art_path != "":
		world.tile_art = (load(tile_art_path) as GDScript).new()
	world.setup(shape, gen, _palette(), world_seed)
	add_child(world)
	if disk:
		world.set_darkness([
			{"from": 0, "to": 8, "darkness": 0.0},
			{"from": 8, "to": 30, "darkness": 0.6, "tint": Color(0.02, 0.02, 0.08)},
			{"from": 30, "to": 9999, "darkness": 0.88, "tint": Color(0.0, 0.0, 0.03)},
		])
	else:
		world.set_darkness([
			{"from": 0, "to": 15, "darkness": 0.0},
			{"from": 15, "to": 45, "darkness": 0.6, "tint": Color(0.02, 0.02, 0.08)},
			{"from": 45, "to": 9999, "darkness": 0.88, "tint": Color(0.0, 0.0, 0.03)},
		])
	_add_backdrop()
	_build_paths()
	for i in 2:
		var d := Node2D.new()
		d.name = "Digger%d" % i
		d.position = paths[i][0]
		world.add_child(d)
		world.track(d)
		world.add_light(d, 150.0)
		diggers.append(d)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_place_camera()
	world.update_chunks()
	world.tile_dug.connect(func(_c: Vector2i, _b: StringName, _p: int): if measuring: tiles_dug += 1)
	world.chunk_loaded.connect(func(_k: Vector2i): if measuring: chunk_loads += 1)
	prev_us = Time.get_ticks_usec()


func _palette() -> Array[TileDef]:
	var defs: Array[TileDef] = []
	for row in [
		[&"air", Color(0, 0, 0, 0), false, false],
		[&"grass", Color(0.36, 0.66, 0.27), true, true],
		[&"dirt", Color(0.55, 0.38, 0.22), true, true],
		[&"stone", Color(0.45, 0.45, 0.5), true, true],
		[&"bedrock", Color(0.2, 0.18, 0.22), true, false],
	]:
		var d := TileDef.new()
		d.id = row[0]
		d.color = row[1]
		d.solid = row[2]
		d.breakable = row[3]
		defs.append(d)
	return defs


func _add_backdrop() -> void:
	var bg := Node2D.new()
	bg.name = "Backdrop"
	bg.z_index = -100
	add_child(bg)
	bg.draw.connect(func():
		bg.draw_rect(Rect2(-8000, -8000, 16000, 16000), Color(0.1, 0.07, 0.05)))


func _cell_px(cell: Vector2i) -> Vector2:
	return world.shape.center_of(cell)


func _build_paths() -> void:
	var cs := float(world.shape.cell_size)
	if disk:
		for start_deg: float in [-120.0, 60.0]:
			var p: Array[Vector2] = []
			var r := 134.0
			var a: float = start_deg
			p.append(Vector2.from_angle(deg_to_rad(a)) * r * cs)
			while r > 20.0:
				for k in range(1, 14):
					p.append(Vector2.from_angle(deg_to_rad(a + 40.0 * k / 13.0)) * r * cs)
				a += 40.0
				r = maxf(r - 8.0, 20.0)
				p.append(Vector2.from_angle(deg_to_rad(a)) * r * cs)
			paths.append(p)
	else:
		for x0: int in [40, 160]:
			var p: Array[Vector2] = []
			var x: int = x0
			var y := 20
			p.append(_cell_px(Vector2i(x, y)))
			var dir := 1
			while y < 280:
				x += 30 * dir
				p.append(_cell_px(Vector2i(x, y)))
				y = mini(y + 8, 280)
				p.append(_cell_px(Vector2i(x, y)))
				dir = -dir
			paths.append(p)


func _advance(i: int, delta: float) -> void:
	var path: Array = paths[i]
	var d := diggers[i]
	var step := SPEED * world.shape.cell_size * delta
	while step > 0.0 and segs[i] < path.size() - 1:
		var to: Vector2 = path[segs[i] + 1]
		var dist := d.position.distance_to(to)
		if dist <= step:
			d.position = to
			step -= dist
			segs[i] += 1
		else:
			d.position = d.position.move_toward(to, step)
			step = 0.0


func _physics_process(delta: float) -> void:
	if finished:
		return
	for i in 2:
		_advance(i, delta)
		var cell := world.shape.cell_at(diggers[i].position)
		if cell != last_cells[i]:
			last_cells[i] = cell
			var d0 := Time.get_ticks_usec()
			world.dig(cell, stamp, i)
			if measuring:
				dig_ms.append((Time.get_ticks_usec() - d0) / 1000.0)
	var made := 0
	while world.awake_bodies() < bodies_target and made < SPAWNS_PER_FRAME:
		_spawn_body()
		made += 1
	_place_camera()
	if measuring:
		physics_ticks += 1
		awake_samples.append(world.awake_bodies())
		chunk_samples.append(world.loaded_chunks().size())
		water_max = maxi(water_max, world.water_count())


func _spawn_body() -> void:
	var b := FallingBody.new()
	b.round = spawn_toggle % 2 == 0
	b.color = Color(0.62, 0.58, 0.54) if b.round else Color(0.95, 0.78, 0.2)
	var digger := spawn_toggle % 2
	spawn_toggle += 1
	b.position = _cell_px(last_cells[digger]) + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
	world.add_child(b)
	alive.append(b)
	spawned += 1
	if alive.size() > MAX_ALIVE:
		var old: FallingBody = alive.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _place_camera() -> void:
	var a := diggers[0].position
	var b := diggers[1].position
	cam.position = (a + b) * 0.5
	var view := get_viewport_rect().size
	var span := (a - b).abs() + Vector2(500.0, 500.0)
	cam.zoom = Vector2.ONE * clampf(minf(view.x / span.x, view.y / span.y), 0.25, 1.0)


func _process(delta: float) -> void:
	if finished:
		return
	var now := Time.get_ticks_usec()
	var ms := (now - prev_us) / 1000.0
	prev_us = now
	elapsed += delta
	if not measuring and elapsed >= WARMUP:
		measuring = true
		return
	if not measuring:
		return
	measure_time += delta
	frame_ms.append(ms)
	if measure_time >= seconds:
		_finish()


static func _pct(sorted: Array[float], p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[int(p * (sorted.size() - 1))]


static func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


static func _max(a: Array[float]) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, v)
	return m


static func _over(a: Array[float], limit: float) -> float:
	if a.is_empty():
		return 0.0
	var n := 0
	for v in a:
		if v > limit:
			n += 1
	return 100.0 * n / a.size()


static func _r(v: float) -> float:
	return snappedf(v, 0.001)


static func _stats(a: Array[float], keys: Array[String]) -> Dictionary:
	var s := a.duplicate()
	s.sort()
	var out := {}
	for k in keys:
		match k:
			"avg": out[k] = _r(_avg(a))
			"p50": out[k] = _r(_pct(s, 0.5))
			"p95": out[k] = _r(_pct(s, 0.95))
			"p99": out[k] = _r(_pct(s, 0.99))
			"max": out[k] = _r(_max(a))
	return out


## Rebuilds every loaded chunk once (free, then load) and times the loads: the chunk build cost.
func _chunk_build_ms() -> Array[float]:
	var out: Array[float] = []
	for k in world.loaded_chunks():
		world._free_chunk(k)
		var t0 := Time.get_ticks_usec()
		world._load_chunk(k)
		out.append((Time.get_ticks_usec() - t0) / 1000.0)
	return out


func _finish() -> void:
	finished = true
	var build_ms := _chunk_build_ms()
	var total_ms := 0.0
	for v in frame_ms:
		total_ms += v
	var res := get_viewport().get_visible_rect().size
	var result := {
		"shape": "disk" if disk else "rect",
		"tile_art": tile_art_path,
		"seed": world_seed,
		"seconds": seconds,
		"bodies_target": bodies_target,
		"display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [int(res.x), int(res.y)],
		"frames": frame_ms.size(),
		"fps_avg": _r(1000.0 * frame_ms.size() / maxf(total_ms, 0.001)),
		"frame_ms": _stats(frame_ms, ["avg", "p50", "p95", "p99", "max"]),
		"frames_over_16_7ms_pct": _r(_over(frame_ms, FRAME_BUDGET_MS)),
		"physics_ticks": physics_ticks,
		"one_tick_per_frame": absi(physics_ticks - frame_ms.size()) <= 2,
		"dig_ms": _stats(dig_ms, ["avg", "p95", "max"]),
		"awake": _stats(awake_samples, ["avg", "max"]),
		"bodies_spawned": spawned,
		"bodies_alive": alive.size(),
		"tiles_dug": tiles_dug,
		"chunk_loads": chunk_loads,
		"chunk_build_ms": _stats(build_ms, ["avg", "p50", "max"]),
		"loaded_chunks": _stats(chunk_samples, ["avg", "max"]),
		"water_cells_max": water_max,
	}
	print("stress: " + JSON.stringify(result))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	else:
		push_error("stress: cannot write %s" % out_path)
	get_tree().quit(0)
