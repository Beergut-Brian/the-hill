## TileWorld's bookkeeping for FallingBody and BreakableProp.
## - resting: support cell -> sleeping bodies resting there (registered when a body falls asleep).
##   Removing a solid tile wakes exactly the bodies indexed at that cell; nothing else wakes them.
## - props: support cell -> props standing there; removing one makes the prop re-check its support.
## - awake cap: past world.max_awake_bodies, wake requests wait in a FIFO queue.
## - bodies whose chunk is not loaded are frozen; on load they come back asleep (awake if their
##   support went away meanwhile, or if they were falling when frozen).
extends RefCounted

var world: TileWorld
var bodies: Array[FallingBody] = []
var resting: Dictionary[Vector2i, Array] = {}
var props: Dictionary[Vector2i, Array] = {}
var queue: Array[FallingBody] = []


func _init(p_world: TileWorld) -> void:
	world = p_world


func add(b: FallingBody) -> void:
	if bodies.has(b):
		return
	bodies.append(b)
	b.world = world
	b._sleep_cb = _on_sleep_changed.bind(b)
	b.sleeping_state_changed.connect(b._sleep_cb)
	if not b.sleeping and not b.freeze and awake_count() > world.max_awake_bodies:
		_sleep(b)
		queue.append(b)
	_sync_one(b)


func remove(b: FallingBody) -> void:
	if not bodies.has(b):
		return
	bodies.erase(b)
	queue.erase(b)
	_unrest(b)
	if b._sleep_cb.is_valid() and b.sleeping_state_changed.is_connected(b._sleep_cb):
		b.sleeping_state_changed.disconnect(b._sleep_cb)
	b.world = null


func awake_count() -> int:
	var n := 0
	for b in bodies:
		if not b.sleeping and not b.freeze:
			n += 1
	return n


func request_wake(b: FallingBody) -> void:
	if not is_instance_valid(b) or not b.sleeping:
		return
	if b.freeze:
		b._wake_on_load = true
		return
	if awake_count() < world.max_awake_bodies:
		_wake(b)
	elif not queue.has(b):
		queue.append(b)


func release_queue() -> void:
	if queue.is_empty():
		return
	var awake := awake_count()
	while not queue.is_empty() and awake < world.max_awake_bodies:
		var b: FallingBody = queue.pop_front()
		if is_instance_valid(b) and b.sleeping and not b.freeze:
			_wake(b)
			awake += 1


## A solid tile at cell went away.
func on_support_removed(cell: Vector2i) -> void:
	wake_resting_on(cell)
	var ps: Array = props.get(cell, [])
	for p in ps.duplicate():
		if is_instance_valid(p):
			p._check_support()


func wake_resting_on(cell: Vector2i) -> void:
	var arr: Array = resting.get(cell, [])
	for b in arr.duplicate():
		request_wake(b)


func sync_frozen() -> void:
	for b in bodies.duplicate():
		if is_instance_valid(b):
			_sync_one(b)
		else:
			bodies.erase(b)


func add_prop(p: BreakableProp) -> void:
	for c in p.support_cells():
		props.get_or_add(c, []).append(p)


func remove_prop(p: BreakableProp) -> void:
	for c in p.support_cells():
		var arr: Array = props.get(c, [])
		arr.erase(p)
		if arr.is_empty():
			props.erase(c)


## Cells whose removal should wake a body resting here: below each overlapped cell, plus sides.
func support_cells(b: FallingBody) -> Array[Vector2i]:
	var shape := world.shape
	var p := world.local_pos(b)
	var half := maxf(maxf(b.size_px.x, b.size_px.y) * 0.5 - 1.0, 1.0)
	var c0 := shape.cell_at(p - Vector2(half, half))
	var c1 := shape.cell_at(p + Vector2(half, half))
	var out: Array[Vector2i] = []
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var s := shape.below(Vector2i(x, y))
			for t in [s, shape.sides(s)[0], shape.sides(s)[1]]:
				if not out.has(t):
					out.append(t)
	return out


func _supported(b: FallingBody) -> bool:
	var shape := world.shape
	var p := world.local_pos(b)
	var half := maxf(maxf(b.size_px.x, b.size_px.y) * 0.5 - 1.0, 1.0)
	var c0 := shape.cell_at(p - Vector2(half, half))
	var c1 := shape.cell_at(p + Vector2(half, half))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if world.is_solid(shape.below(Vector2i(x, y))):
				return true
	return false


func _sync_one(b: FallingBody) -> void:
	var key := world.shape.chunk_of(world.shape.cell_at(world.local_pos(b)))
	var loaded := world._chunks.has(key)
	if not loaded and not b.freeze:
		b._wake_on_load = b._wake_on_load or not b.sleeping
		b._frozen_by_world = true
		queue.erase(b)
		b.freeze = true
	elif loaded and b._frozen_by_world:
		b._frozen_by_world = false
		b.freeze = false
		_sleep(b)
		if b._wake_on_load or not _supported(b):
			b._wake_on_load = false
			request_wake(b)


func _sleep(b: FallingBody) -> void:
	b.sleeping = true
	_rest(b)


func _wake(b: FallingBody) -> void:
	_unrest(b)
	queue.erase(b)
	b.sleeping = false


func _rest(b: FallingBody) -> void:
	_unrest(b)
	b._rest_cells = support_cells(b)
	for c in b._rest_cells:
		resting.get_or_add(c, []).append(b)


func _unrest(b: FallingBody) -> void:
	for c in b._rest_cells:
		var arr: Array = resting.get(c, [])
		arr.erase(b)
		if arr.is_empty():
			resting.erase(c)
	b._rest_cells = []


func _on_sleep_changed(b: FallingBody) -> void:
	if not is_instance_valid(b) or b.freeze:
		return
	if b.sleeping:
		_rest(b)
		release_queue()
	else:
		_unrest(b)
