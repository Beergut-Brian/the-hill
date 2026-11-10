## TileWorld water: a set of full cells, simulated and drawn only in loaded chunks.
## Truth = generator.base_water overridden by EditStore.water; `live` mirrors it for loaded cells.
## A tick moves each active water cell to `shape.below`, else to a free `shape.sides` cell (only if
## it can fall from there or water presses from above, so flat water settles). Moves only into
## loaded, in-shape, non-solid, dry cells: the count never grows. Only cells near a change are
## checked (the active set), so a still lake costs nothing. Draws translucent quads (z above tiles).
extends Node2D

const NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ENTER_COOLDOWN := 0.5

var world: TileWorld
var live: Dictionary[Vector2i, bool] = {}
var color := Color(0.25, 0.55, 1.0, 0.55)

var _active: Dictionary[Vector2i, bool] = {}
var _blocked: Dictionary[Vector2i, bool] = {}
var _rng := RandomNumberGenerator.new()
var _drain_acc := 0.0
var _enter_cooldown := 0.0
var _changed := false


func _init(p_world: TileWorld) -> void:
	world = p_world
	name = "Water"
	z_index = 1


func reset(p_seed: int) -> void:
	_rng.seed = hash(p_seed) ^ 0x5eed
	live.clear()
	_active.clear()
	_blocked.clear()
	_drain_acc = 0.0
	_enter_cooldown = 0.0
	queue_redraw()


func on_chunk_loaded(cells: Array[Vector2i]) -> void:
	for c in cells:
		if world._stored_water(c):
			live[c] = true
			_active[c] = true
	for c in _blocked:
		_active[c] = true
	_blocked.clear()
	queue_redraw()


func on_chunk_freed(cells: Array) -> void:
	for c in cells:
		if live.erase(c):
			_changed = true
		_active.erase(c)
		_blocked.erase(c)
	queue_redraw()


func set_water(cell: Vector2i, on: bool) -> void:
	if not world.shape.contains(cell):
		return
	if on and world.is_solid(cell):
		return
	if on == world.base_water_of(cell):
		world.edits.water.erase(cell)
	else:
		world.edits.water[cell] = on
	if world.is_loaded(cell):
		if on:
			live[cell] = true
		else:
			live.erase(cell)
		touch(cell)
		_changed = true
		queue_redraw()


## Something changed at cell: check it and its neighbours next tick.
func touch(cell: Vector2i) -> void:
	_active[cell] = true
	for n in NEIGHBOURS:
		_active[cell + n] = true


func step() -> void:
	var dt := 1.0 / world.water_hz if world.water_hz > 0.0 else 0.1
	_enter_cooldown = maxf(0.0, _enter_cooldown - dt)
	if not _active.is_empty():
		_flow()
	if world.drain_per_second > 0.0:
		_drain(dt)
	if _changed:
		_changed = false
		queue_redraw()


func _flow() -> void:
	var shape := world.shape
	# Deepest first, so falling water moves as a body instead of stretching.
	var by_depth: Dictionary[int, Array] = {}
	for c in _active:
		if live.has(c):
			by_depth.get_or_add(shape.depth_of(c), []).append(c)
	_active.clear()
	var depths := by_depth.keys()
	depths.sort()
	depths.reverse()
	var moved: Dictionary[Vector2i, bool] = {}
	for d in depths:
		for c: Vector2i in by_depth[d]:
			if not moved.has(c) and live.has(c):
				_try_move(c, moved)


func _try_move(c: Vector2i, moved: Dictionary[Vector2i, bool]) -> void:
	var shape := world.shape
	var b := shape.below(c)
	if b != c:
		var fb := _free(b)
		if fb == 1:
			_move(c, b, moved)
			return
		if fb == -1:
			_blocked[c] = true
	var sides := shape.sides(c)
	if _rng.randi() & 1:
		sides = [sides[1], sides[0]]
	var pressed := _water_above(c)
	for s in sides:
		var fs := _free(s)
		if fs == -1:
			_blocked[c] = true
		if fs != 1:
			continue
		if pressed or _free(shape.below(s)) == 1:
			_move(c, s, moved)
			return


## 1 free, 0 blocked (solid, wet or outside), -1 not loaded.
func _free(x: Vector2i) -> int:
	if not world.shape.contains(x):
		return 0
	if not world.is_loaded(x):
		return -1
	if live.has(x) or world.is_solid(x):
		return 0
	return 1


func _water_above(c: Vector2i) -> bool:
	for n in NEIGHBOURS:
		var u := c + n
		if live.has(u) and world.shape.below(u) == c:
			return true
	return false


func _move(from: Vector2i, to: Vector2i, moved: Dictionary[Vector2i, bool]) -> void:
	set_water(from, false)
	set_water(to, true)
	moved[to] = true
	if _enter_cooldown <= 0.0 and world.edits.tiles.get(to, -1) == 0 \
			and world.is_solid_id(world.base_tile_of(to)):
		_enter_cooldown = ENTER_COOLDOWN
		world.water_entered.emit(to)


## Removes surface cells (no water above) at drain_per_second.
func _drain(dt: float) -> void:
	_drain_acc += world.drain_per_second * dt
	while _drain_acc >= 1.0 and not live.is_empty():
		var victim := Vector2i.ZERO
		var found := false
		for c in live:
			if not _water_above(c):
				victim = c
				found = true
				break
		if not found:
			break
		set_water(victim, false)
		_drain_acc -= 1.0
	if live.is_empty():
		_drain_acc = 0.0


func _draw() -> void:
	var cs := float(world.shape.cell_size) if world.shape else 16.0
	var size := Vector2(cs, cs)
	for c in live:
		draw_rect(Rect2(Vector2(c) * cs, size), color)
