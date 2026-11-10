## TileWorld water: a set of full cells, simulated and drawn only in loaded chunks.
## Truth = generator.base_water overridden by EditStore.water; `live` mirrors it for loaded cells.
## A tick moves each active water cell (deepest first):
##   1. to `shape.below` if that is free;
##   2. else toward a drop: to a free `shape.sides` cell when, scanning on along the level line from
##      it for up to `world.flow_reach` cells (all free and loaded), one has a free `below`; the side
##      with the nearer drop wins, so a cell never wanders between two holes;
##   3. else, if water presses from above, to any free side cell.
## So poured water runs out into a flat sheet, and a sheet with no drop within reach lies still.
## Moves only into loaded, in-shape, non-solid, dry cells: the count never grows. Only cells near a
## change are checked (the active set; a removed tile wakes water within flow_reach), so a still
## lake costs nothing. Draws translucent quads (z above tiles).
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


## wet: the cells of the new chunk that hold water (TileWorld works it out while loading).
func on_chunk_loaded(wet: Array[Vector2i]) -> void:
	for c in wet:
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
		world._mark_edited(cell)
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


## A tile went away at cell: water within r cells may now see a drop.
func touch_area(cell: Vector2i, r: int) -> void:
	touch(cell)
	if live.is_empty() or r <= 0:
		return
	for y in range(cell.y - r, cell.y + r + 1):
		for x in range(cell.x - r, cell.x + r + 1):
			var c := Vector2i(x, y)
			if live.has(c):
				_active[c] = true


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
	var best := c
	var best_d := 1 << 30
	var first_free := c
	for s in sides:
		var fs := _free(s)
		if fs == -1:
			_blocked[c] = true
		if fs != 1:
			continue
		if first_free == c:
			first_free = s
		var d := _drop_ahead(c, s)
		if d > 0 and d < best_d:
			best_d = d
			best = s
	if best != c:
		_move(c, best, moved)
	elif first_free != c and _water_above(c):
		_move(c, first_free, moved)


## From c through its free side cell s and on along the level line, up to flow_reach cells (each
## free and loaded): the 1-based distance to the first one with a free `below`, or 0 for none.
func _drop_ahead(c: Vector2i, s: Vector2i) -> int:
	var shape := world.shape
	var prev := c
	var cur := s
	for i in maxi(world.flow_reach, 1):
		if i > 0:
			var f := _free(cur)
			if f != 1:
				if f == -1:
					_blocked[c] = true
				return 0
		var under := shape.below(cur)
		if under != cur:
			var fu := _free(under)
			if fu == 1:
				return i + 1
			if fu == -1:
				_blocked[c] = true
				return 0
		var nxt := _next_along(prev, cur)
		prev = cur
		cur = nxt
	return 0


## The level neighbour of cur that continues away from prev (follows the curve on a disk).
func _next_along(prev: Vector2i, cur: Vector2i) -> Vector2i:
	var sd := world.shape.sides(cur)
	var a: Vector2i = sd[0]
	var b: Vector2i = sd[1]
	if a == prev:
		return b
	if b == prev:
		return a
	return a if (a - prev).length_squared() > (b - prev).length_squared() else b


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
	_wake_lines(from)
	if _enter_cooldown <= 0.0 and world.edits.tiles.get(to, -1) == 0 \
			and world.is_solid_id(world.base_tile_of(to)):
		_enter_cooldown = ENTER_COOLDOWN
		world.water_entered.emit(to)


## `cell` just went dry. Water on its level line may have been scanning into it (a blocked path
## that is now open) and water on the line above sees a new drop: wake the nearest water cell each
## way along both lines within flow_reach (cells further on would scan into those first). Nothing
## to do when water sits right above: it falls in next tick (touch() woke it).
func _wake_lines(cell: Vector2i) -> void:
	var shape := world.shape
	var u := cell
	for n in NEIGHBOURS:
		if shape.below(cell + n) == cell:
			u = cell + n
			break
	if u != cell and live.has(u):
		return
	_wake_along(cell)
	if u != cell and _free(u) == 1:
		_wake_along(u)


func _wake_along(start: Vector2i) -> void:
	for first in world.shape.sides(start):
		var prev := start
		var cur: Vector2i = first
		for i in maxi(world.flow_reach, 1):
			if live.has(cur):
				_active[cur] = true
				break
			if _free(cur) != 1:
				break
			var nxt := _next_along(prev, cur)
			prev = cur
			cur = nxt


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
