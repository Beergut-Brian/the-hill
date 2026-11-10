## TileWorld visual proof, no input: a scripted invisible digger cuts a 3-wide tunnel (sideways then
## down in a RectShape(120, 120); around the rim then inward in a DiskShape(64), whole planet in
## view so the radial gravity reads), undercutting ~15
## boulders seeded in small cavities and opening a water pocket, under depth darkness with a lamp on
## the digger. Shape from the user args: `-- --shape=disk`, default rect.
##   godot --path . res://addons/openjar/tileworld/demo/shape_demo.tscn -- --shape=disk
extends Node2D

const SPEED := 16.0   # tiles per second
const SEED := 7
const BOULDERS := 15
const DISK_RADIUS := 64

var disk := false
var world: TileWorld
var digger: Node2D
var cam: Camera2D
var path: Array[Vector2] = []
var _seg := 0
var _last_cell := Vector2i(1 << 30, 0)
var _tunnel: Array[Vector2i] = []


func _ready() -> void:
	disk = OS.get_cmdline_user_args().has("--shape=disk")
	for y in range(-1, 2):
		for x in range(-1, 2):
			_tunnel.append(Vector2i(x, y))
	var shape: WorldShape
	var gen := LayeredGenerator.new()
	gen.cave_threshold = 0.62
	if disk:
		shape = DiskShape.new(DISK_RADIUS)
		gen.bands = [{"from": 0, "tile": 1}, {"from": 3, "tile": 2}, {"from": 30, "tile": 3}]
		gen.water_from_depth = 48
	else:
		shape = RectShape.new(120, 120)
		gen.surface_depth = 8
		gen.border_tile = 4
		gen.bands = [{"from": 8, "tile": 1}, {"from": 11, "tile": 2}, {"from": 45, "tile": 3}]
		gen.water_from_depth = 60
	_add_backdrop(shape)
	world = TileWorld.new()
	world.chunk_radius = 8 if disk else 2   # 8 covers every chunk of the small planet
	world.setup(shape, gen, _palette(), SEED)
	add_child(world)
	if disk:
		world.set_darkness([
			{"from": 0, "to": 8, "darkness": 0.0},
			{"from": 8, "to": 30, "darkness": 0.35, "tint": Color(0.02, 0.02, 0.08)},
			{"from": 30, "to": 9999, "darkness": 0.6, "tint": Color(0.0, 0.0, 0.03)},
		])
	else:
		world.set_darkness([
			{"from": 0, "to": 15, "darkness": 0.0},
			{"from": 15, "to": 45, "darkness": 0.6, "tint": Color(0.02, 0.02, 0.08)},
			{"from": 45, "to": 9999, "darkness": 0.88, "tint": Color(0.0, 0.0, 0.03)},
		])
	_build_path()
	digger = Node2D.new()
	digger.name = "Digger"
	digger.position = path[0]
	world.add_child(digger)
	world.track(digger)
	world.add_light(digger, 190.0)
	_seed_boulders()
	_seed_water_pocket()
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * (0.5 if disk else 1.0)
	add_child(cam)
	cam.make_current()
	_place_camera()
	world.update_chunks()


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


func _add_backdrop(shape: WorldShape) -> void:
	var bg := Node2D.new()
	bg.name = "Backdrop"
	bg.z_index = -100
	add_child(bg)
	var cs := float(shape.cell_size)
	bg.draw.connect(func():
		if disk:
			bg.draw_rect(Rect2(-6000, -6000, 12000, 12000), Color(0.04, 0.05, 0.12))
			bg.draw_circle(Vector2.ZERO, DISK_RADIUS * cs, Color(0.22, 0.15, 0.1))
		else:
			bg.draw_rect(Rect2(-4000, -4000, 9000, 4000 + 8 * cs), Color(0.55, 0.78, 0.95))
			bg.draw_rect(Rect2(-4000, 8 * cs, 9000, 6000), Color(0.22, 0.15, 0.1)))


func _cell_px(cell: Vector2i) -> Vector2:
	return world.shape.center_of(cell)


func _build_path() -> void:
	var cs := float(world.shape.cell_size)
	if disk:
		var r := (DISK_RADIUS - 12.0) * cs
		for deg in range(-160, -27, 3):
			path.append(Vector2.from_angle(deg_to_rad(deg)) * r)
		var a := deg_to_rad(-28.0)
		path.append(Vector2.from_angle(a) * 10.0 * cs)
	else:
		path.append(_cell_px(Vector2i(4, 24)))
		path.append(_cell_px(Vector2i(72, 24)))
		path.append(_cell_px(Vector2i(72, 104)))


## "Up" at a world position: against gravity.
func _up(pos: Vector2) -> Vector2:
	var g := world.shape.gravity_at(pos)
	return -g.normalized() if g != Vector2.ZERO else Vector2.UP


func _path_point(t: float) -> Vector2:
	# t in 0..1 along the first (sideways / rim) leg.
	var leg := path.size() - 1 if disk else 1
	var f := t * (leg - 1) if disk else t
	var i := clampi(int(f), 0, path.size() - 2)
	return path[i].lerp(path[i + 1], f - i)


func _seed_boulders() -> void:
	var cs := float(world.shape.cell_size)
	for k in BOULDERS:
		var t := 0.08 + 0.84 * k / float(BOULDERS - 1)
		var p := _path_point(t)
		if _near_pocket(p):
			continue
		var up := _up(p)
		var side := Vector2(-up.y, up.x)
		var c0 := world.shape.cell_at(p + up * 2.4 * cs)
		var c1 := world.shape.cell_at(p + up * 3.4 * cs)
		for c in [c0, c1, world.shape.cell_at(p + up * 2.4 * cs + side * cs), world.shape.cell_at(p + up * 3.4 * cs + side * cs)]:
			world.set_tile(c, 0)
		var b := FallingBody.new()
		b.round = k % 3 != 0
		b.color = Color(0.62, 0.58, 0.54) if b.round else Color(0.95, 0.78, 0.2)
		b.position = _cell_px(c0)
		world.add_child(b)


func _pocket_centre() -> Vector2:
	var p := _path_point(0.55)
	return p + _up(p) * 4.4 * world.shape.cell_size


func _near_pocket(p: Vector2) -> bool:
	return p.distance_to(_path_point(0.55)) < 6.0 * world.shape.cell_size


func _seed_water_pocket() -> void:
	var cs := float(world.shape.cell_size)
	var centre := _pocket_centre()
	var up := _up(centre)
	var side := Vector2(-up.y, up.x)
	var c := world.shape.cell_at(centre)
	for y in range(-6, 7):
		for x in range(-6, 7):
			var cell := c + Vector2i(x, y)
			var d := world.shape.center_of(cell) - centre
			if absf(d.dot(up)) <= 3.0 * cs and absf(d.dot(side)) <= 3.5 * cs:
				world.set_tile(cell, 0)
				world.set_water(cell, true)


func _physics_process(delta: float) -> void:
	if _seg < path.size() - 1:
		var step := SPEED * world.shape.cell_size * delta
		while step > 0.0 and _seg < path.size() - 1:
			var to := path[_seg + 1]
			var d := digger.position.distance_to(to)
			if d <= step:
				digger.position = to
				step -= d
				_seg += 1
			else:
				digger.position = digger.position.move_toward(to, step)
				step = 0.0
	var cell := world.shape.cell_at(digger.position)
	if cell != _last_cell:
		_last_cell = cell
		world.dig(cell, _tunnel, 0)
	_place_camera()


func _place_camera() -> void:
	if disk:
		cam.position = Vector2.ZERO
	else:
		cam.position = Vector2(60 * world.shape.cell_size, clampf(digger.position.y, 540.0, 1400.0))
