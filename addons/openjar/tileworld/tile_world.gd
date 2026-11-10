## A chunked, diggable 2D tile world (see README.md and docs/contracts.md "Module: TileWorld").
## Only chunks around tracked nodes exist as TileMapLayer children (with collision); tiles, digging,
## water state and saves work everywhere. The chunk manager only asks the WorldShape (chunk_of,
## chunk_cells, neighbourhood), so a new world shape is a new WorldShape subclass and nothing else.
## Positions given to the shape are local to this node (translate the world freely; do not rotate it).
class_name TileWorld
extends Node2D

signal tile_dug(cell: Vector2i, block: StringName, player: int)
signal dig_blocked(cell: Vector2i, block: StringName, player: int)
signal chunk_loaded(key: Vector2i)
signal chunk_freed(key: Vector2i)
signal body_landed(body: Node2D, speed: float)
signal prop_broke(prop: Node2D, pieces: Array)
signal water_entered(cell: Vector2i)

const WaterSim := preload("water_sim.gd")
const BodyIndex := preload("body_index.gd")
const DarknessOverlay := preload("darkness_overlay.gd")
const _WATER_BIT := 1 << 20
const _ID_MASK := _WATER_BIT - 1

var shape: WorldShape
var generator: WorldGenerator
var palette: Array[TileDef] = []
var world_seed := 0
var max_awake_bodies: int = 60
var chunk_radius: int = 1
## New chunks built per physics frame (direct update_chunks() calls are unlimited by default).
var chunk_budget_per_frame := 2
var drain_per_second: float = 0.0
## Water ticks per second from _physics_process; <= 0 means only explicit step_water() calls.
var water_hz := 10.0
## Use this TileSet instead of the generated one: atlas source 0, tile id N at atlas (N-1, 0).
var tile_set_override: TileSet
## Physics layer of the generated TileSet's collision.
var collision_layer := 1:
	set(v):
		collision_layer = v
		if _tile_set and _tile_set != tile_set_override and _tile_set.get_physics_layers_count() > 0:
			_tile_set.set_physics_layer_collision_layer(0, v)
var edits := EditStore.new()

var _tile_set: TileSet
var _solid := PackedByteArray()
var _breakable := PackedByteArray()
var _chunks: Dictionary[Vector2i, TileMapLayer] = {}
var _chunk_cells: Dictionary[Vector2i, Array] = {}
## Base tile of every cell of a loaded chunk, | _WATER_BIT when it starts full of water.
var _base: Dictionary[Vector2i, int] = {}
var _tracked: Array[Node2D] = []
var _last_track_keys: Array[Vector2i] = []
var _chunks_pending := true
var _water: WaterSim
var _bodies: BodyIndex
var _darkness: DarknessOverlay
var _water_acc := 0.0


func setup(p_shape: WorldShape, p_generator: WorldGenerator, p_palette: Array[TileDef], p_seed: int) -> void:
	for key in _chunks.keys():
		_free_chunk(key)
	shape = p_shape
	generator = p_generator
	palette = p_palette
	world_seed = p_seed
	generator.setup(shape, world_seed)
	edits.clear()
	_solid.resize(palette.size())
	_breakable.resize(palette.size())
	for i in palette.size():
		var def := palette[i]
		_solid[i] = 1 if i > 0 and def != null and def.solid else 0
		_breakable[i] = 1 if i > 0 and def != null and def.breakable else 0
	_tile_set = tile_set_override if tile_set_override else _build_tile_set()
	if _water == null:
		_water = WaterSim.new(self)
		add_child(_water)
		_darkness = DarknessOverlay.new(self)
		add_child(_darkness)
		_bodies = BodyIndex.new(self)
	_water.reset(world_seed)
	_chunks_pending = true


# --- tiles -------------------------------------------------------------------------------------

## Edits over the base; 0 outside the shape.
func get_tile(cell: Vector2i) -> int:
	var e = edits.tiles.get(cell)
	if e != null:
		return e
	var b = _base.get(cell)
	if b != null:
		return b & _ID_MASK
	if not shape.contains(cell):
		return 0
	return generator.base_tile(cell)


func base_tile_of(cell: Vector2i) -> int:
	var b = _base.get(cell)
	if b != null:
		return b & _ID_MASK
	return generator.base_tile(cell) if shape.contains(cell) else 0


func base_water_of(cell: Vector2i) -> bool:
	var b = _base.get(cell)
	if b != null:
		return (b & _WATER_BIT) != 0
	return shape.contains(cell) and generator.base_water(cell)


func tile_def(id: int) -> TileDef:
	return palette[id] if id >= 0 and id < palette.size() else null


func is_solid(cell: Vector2i) -> bool:
	return is_solid_id(get_tile(cell))


func is_solid_id(id: int) -> bool:
	return id > 0 and id < _solid.size() and _solid[id] == 1


## True when the cell belongs to a loaded chunk.
func is_loaded(cell: Vector2i) -> bool:
	return _base.has(cell)


## Records an edit (or clears it if id is the base tile). Wakes what rested on a removed solid.
func set_tile(cell: Vector2i, id: int) -> void:
	if not shape.contains(cell):
		return
	var old := get_tile(cell)
	if old == id:
		return
	if id == base_tile_of(cell):
		edits.tiles.erase(cell)
	else:
		edits.tiles[cell] = id
	var layer: TileMapLayer = _chunks.get(shape.chunk_of(cell))
	if layer:
		if id > 0:
			layer.set_cell(cell, 0, Vector2i(id - 1, 0))
		else:
			layer.erase_cell(cell)
	var was := is_solid_id(old)
	var now := is_solid_id(id)
	if now and has_water(cell):
		set_water(cell, false)
	if was != now:
		_water.touch(cell)
	if was and not now:
		_bodies.on_support_removed(cell)


## Removes every breakable solid tile at cell + offset; returns the cells removed.
func dig(cell: Vector2i, offsets: Array[Vector2i] = [Vector2i.ZERO], player: int = -1) -> Array[Vector2i]:
	var removed: Array[Vector2i] = []
	for o in offsets:
		var c := cell + o
		var id := get_tile(c)
		if not is_solid_id(id):
			continue
		var block: StringName = palette[id].id
		if _breakable[id] == 0:
			dig_blocked.emit(c, block, player)
			continue
		set_tile(c, 0)
		removed.append(c)
		tile_dug.emit(c, block, player)
	return removed


# --- chunks ------------------------------------------------------------------------------------

func track(node: Node2D) -> void:
	if not _tracked.has(node):
		_tracked.append(node)
		_chunks_pending = true


func untrack(node: Node2D) -> void:
	_tracked.erase(node)
	_chunks_pending = true


func loaded_chunks() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_chunks.keys())
	return out


## Loads chunks around tracked nodes and frees the rest. `budget` < 0: no limit on new chunks.
func update_chunks(budget: int = -1) -> void:
	if shape == null:
		return
	var keys: Array[Vector2i] = []
	for n in _tracked.duplicate():
		if not is_instance_valid(n):
			_tracked.erase(n)
			continue
		keys.append(shape.chunk_of(shape.cell_at(local_pos(n))))
	if keys != _last_track_keys or _chunks_pending:
		_last_track_keys = keys
		var wanted: Dictionary[Vector2i, bool] = {}
		for k in keys:
			for w in shape.neighbourhood(k, chunk_radius):
				wanted[w] = true
		for k in _chunks.keys():
			if not wanted.has(k):
				_free_chunk(k)
		var made := 0
		_chunks_pending = false
		for k in wanted:
			if _chunks.has(k):
				continue
			if budget >= 0 and made >= budget:
				_chunks_pending = true
				break
			_load_chunk(k)
			made += 1
	_bodies.sync_frozen()


func local_pos(n: Node2D) -> Vector2:
	if n.is_inside_tree() and is_inside_tree():
		return to_local(n.global_position)
	return n.position


func _load_chunk(key: Vector2i) -> void:
	var cells := shape.chunk_cells(key)
	var layer := TileMapLayer.new()
	layer.name = "Chunk_%d_%d" % [key.x, key.y]
	layer.tile_set = _tile_set
	layer.z_index = -1
	for c in cells:
		var b := generator.base_tile(c)
		var v := b
		if not is_solid_id(b) and generator.base_water(c):
			v |= _WATER_BIT
		_base[c] = v
		var e = edits.tiles.get(c)
		var id: int = e if e != null else b
		if id > 0:
			layer.set_cell(c, 0, Vector2i(id - 1, 0))
	add_child(layer)
	_chunks[key] = layer
	_chunk_cells[key] = cells
	_water.on_chunk_loaded(cells)
	_darkness.add_chunk(key, cells)
	chunk_loaded.emit(key)


func _free_chunk(key: Vector2i) -> void:
	var layer: TileMapLayer = _chunks[key]
	_chunks.erase(key)
	remove_child(layer)
	layer.queue_free()
	var cells: Array = _chunk_cells[key]
	_chunk_cells.erase(key)
	_water.on_chunk_freed(cells)
	for c in cells:
		_base.erase(c)
	_darkness.remove_chunk(key)
	chunk_freed.emit(key)


func _build_tile_set() -> TileSet:
	var cs := shape.cell_size
	var n := maxi(palette.size() - 1, 1)
	var img := Image.create_empty(cs * n, cs, false, Image.FORMAT_RGBA8)
	for i in range(1, palette.size()):
		var col: Color = palette[i].color if palette[i] else Color.MAGENTA
		img.fill_rect(Rect2i((i - 1) * cs, 0, cs, cs), col.darkened(0.3))
		img.fill_rect(Rect2i((i - 1) * cs + 1, 1, cs - 2, cs - 2), col)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cs, cs)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, collision_layer)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(cs, cs)
	ts.add_source(src, 0)
	var h := cs * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for i in range(1, palette.size()):
		var at := Vector2i(i - 1, 0)
		src.create_tile(at)
		if _solid[i] == 1:
			var td := src.get_tile_data(at, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	return ts


# --- bodies and props --------------------------------------------------------------------------

func add_body(body: FallingBody) -> void:
	_bodies.add(body)


func remove_body(body: FallingBody) -> void:
	_bodies.remove(body)


func awake_bodies() -> int:
	return _bodies.awake_count()


func _register_prop(prop: BreakableProp) -> void:
	_bodies.add_prop(prop)


func _unregister_prop(prop: BreakableProp) -> void:
	_bodies.remove_prop(prop)


func _on_body_landed(body: Node2D, speed: float) -> void:
	if is_instance_valid(body):
		body_landed.emit(body, speed)


# --- water -------------------------------------------------------------------------------------

func has_water(cell: Vector2i) -> bool:
	if _base.has(cell):
		return _water.live.has(cell)
	return shape.contains(cell) and _stored_water(cell)


## Water state from edits over the base, ignoring the live simulation.
func _stored_water(cell: Vector2i) -> bool:
	var e = edits.water.get(cell)
	var on: bool = e if e != null else base_water_of(cell)
	return on and not is_solid(cell)


func set_water(cell: Vector2i, on: bool) -> void:
	_water.set_water(cell, on)


## Water cells in loaded chunks.
func water_count() -> int:
	return _water.live.size()


## Water cells in loaded chunks (a copy).
func water_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_water.live.keys())
	return out


func buoyancy_at(pos: Vector2) -> Vector2:
	if has_water(shape.cell_at(pos)):
		return -shape.gravity_at(pos) * 1.6
	return Vector2.ZERO


func step_water() -> void:
	_water.step()


# --- darkness ----------------------------------------------------------------------------------

## [{from: int, to: int, darkness: float, tint: Color}] by depth_of; [] removes the dark.
func set_darkness(bands: Array) -> void:
	_darkness.set_bands(bands)


func darkness_at(depth: int) -> float:
	return _darkness.darkness_at(depth)


func add_light(node: Node2D, radius_px: float) -> void:
	_darkness.lights[node] = radius_px


func remove_light(node: Node2D) -> void:
	_darkness.lights.erase(node)


# --- save --------------------------------------------------------------------------------------

func to_save() -> Dictionary:
	return edits.to_save(world_seed)


func load_save(data: Dictionary) -> void:
	if int(data.get("seed", world_seed)) != world_seed:
		push_warning("TileWorld.load_save: save seed %s differs from world seed %d" % [data.get("seed"), world_seed])
	edits.load_save(data)
	var keys := _chunks.keys()
	for k in keys:
		_free_chunk(k)
	for k in keys:
		_load_chunk(k)
	_bodies.sync_frozen()


# --- frame -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if shape == null:
		return
	update_chunks(chunk_budget_per_frame)
	_bodies.release_queue()
	if water_hz > 0.0:
		var period := 1.0 / water_hz
		_water_acc = minf(_water_acc + delta, period * 2.0)
		if _water_acc >= period:
			_water_acc -= period
			step_water()


func _process(_delta: float) -> void:
	if _darkness:
		_darkness.update_lights()
