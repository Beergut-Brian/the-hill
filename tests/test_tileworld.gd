## TileWorld module: chunks, edit-only saves, dig, falling bodies, props, water, darkness, and the
## polar swap: the same helpers run on a RectShape and on a DiskShape world.
class_name TestTileWorld
extends GdUnitTestSuite

const DIRT := 1
const STONE := 2
const TW_DIR := "res://addons/openjar/tileworld/"


# --- fixtures ----------------------------------------------------------------------------------

func _palette() -> Array[TileDef]:
	var air := TileDef.new()
	air.id = &"air"
	air.solid = false
	air.breakable = false
	var dirt := TileDef.new()
	dirt.id = &"dirt"
	dirt.color = Color(0.5, 0.35, 0.2)
	var stone := TileDef.new()
	stone.id = &"stone"
	stone.color = Color(0.4, 0.4, 0.45)
	stone.breakable = false
	return [air, dirt, stone]


func _gen() -> LayeredGenerator:
	var g := LayeredGenerator.new()
	g.bands = [{"from": 0, "tile": DIRT}]
	g.cave_threshold = 2.0
	return g


func _world(shape: WorldShape, radius := 1) -> TileWorld:
	var w := TileWorld.new()
	w.water_hz = 0.0
	w.chunk_radius = radius
	w.setup(shape, _gen(), _palette(), 1234)
	add_child(w)
	auto_free(w)
	return w


func _tracker(w: TileWorld, cell: Vector2i) -> Node2D:
	var n := Node2D.new()
	n.position = w.shape.center_of(cell)
	w.add_child(n)
	w.track(n)
	return n


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _await_sleep(b: FallingBody, max_frames := 240) -> void:
	for i in max_frames:
		if b.sleeping:
			return
		await get_tree().physics_frame


func _carve(w: TileWorld, cells: Array) -> void:
	for c in cells:
		w.set_tile(c, 0)


func _box(origin: Vector2i, down: Vector2i, side: Vector2i, rows: Array, cols: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in rows:
		for j in cols:
			out.append(origin + down * i + side * j)
	return out


# --- shared helpers (run on both shapes) -------------------------------------------------------

## The loaded set is exactly the shape's neighbourhood of the tracked node's chunk.
func _check_chunks_follow(w: TileWorld, node: Node2D) -> void:
	w.update_chunks()
	var key := w.shape.chunk_of(w.shape.cell_at(node.position))
	assert_array(_sorted(w.loaded_chunks())).is_equal(_sorted(w.shape.neighbourhood(key, w.chunk_radius)))
	for k in w.loaded_chunks():
		assert_bool(w.shape.chunk_cells(k).size() > 0).is_true()


## Dig cells (all solid), check edit-only save, round trip through JSON into a fresh world.
func _check_save_roundtrip(make_shape: Callable, cells: Array[Vector2i]) -> void:
	var a := _world(make_shape.call())
	_tracker(a, cells[0])
	a.update_chunks()
	assert_array(a.to_save()["edits"]).is_empty()
	assert_array(a.to_save()["water"]).is_empty()
	var n := 0
	for c in cells:
		n += a.dig(c).size()
	assert_int(n).is_equal(cells.size())
	assert_int(a.to_save()["edits"].size()).is_equal(n * 3)
	a.set_tile(cells[0], a.base_tile_of(cells[0]))
	assert_int(a.to_save()["edits"].size()).is_equal((n - 1) * 3)
	a.set_water(cells[1], true)
	a.set_water(cells[2], true)
	var text := JSON.stringify(a.to_save())
	var b := _world(make_shape.call())
	b.load_save(JSON.parse_string(text))
	var region: Array[Vector2i] = []
	for c in cells:
		for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			region.append(c + d)
	for c in region:   # b has no chunks loaded yet
		assert_int(b.get_tile(c)).is_equal(a.get_tile(c))
		assert_bool(b.has_water(c)).is_equal(a.has_water(c))
	_tracker(b, cells[0])
	b.update_chunks()
	for c in region:
		assert_int(b.get_tile(c)).is_equal(a.get_tile(c))
		assert_bool(b.has_water(c)).is_equal(a.has_water(c))
	assert_bool(b.has_water(cells[1])).is_true()


## A body in a one-cell hole sleeps and stays; a far dig leaves it; digging under it drops it.
func _check_body_falls(w: TileWorld, cell: Vector2i) -> FallingBody:
	w.set_tile(cell, 0)
	var b := FallingBody.new()
	b.position = w.shape.center_of(cell)
	w.add_child(b)
	w.update_chunks()
	assert_bool(b.freeze).is_false()
	await _await_sleep(b)
	assert_bool(b.sleeping).is_true()
	var p0 := b.position
	for i in 60:
		await get_tree().physics_frame
		assert_bool(b.sleeping).is_true()
	assert_float(b.position.distance_to(p0)).is_less(0.5)
	var far := cell + (w.shape.sides(cell)[0] - cell) * 8
	assert_int(w.dig(far).size()).is_equal(1)
	await _frames(20)
	assert_bool(b.sleeping).is_true()
	var c := cell
	for i in 3:
		c = w.shape.below(c)
		w.dig(c)
	await _frames(5)
	await _await_sleep(b)
	assert_bool(b.sleeping).is_true()
	assert_int(w.shape.depth_of(w.shape.cell_at(b.position))).is_greater(w.shape.depth_of(cell))
	return b


## A sealed pocket stays put; opened into a cave below, it flows down without ever growing.
func _check_water(w: TileWorld, origin: Vector2i, down: Vector2i, side: Vector2i) -> void:
	var pocket := _box(origin, down, side, range(0, 4), range(0, 6))
	_carve(w, pocket)
	for c in pocket:
		w.set_water(c, true)
	var n := pocket.size()
	assert_int(w.water_count()).is_equal(n)
	var before := _sorted(w.water_cells())
	for i in 200:
		w.step_water()
		assert_int(w.water_count()).is_equal(n)
	assert_array(_sorted(w.water_cells())).is_equal(before)
	var depth0 := 0
	for c in w.water_cells():
		depth0 = maxi(depth0, w.shape.depth_of(c))
	_carve(w, _box(origin, down, side, range(5, 15), range(-5, 11)))
	assert_array(_sorted(w.water_cells())).is_equal(before)
	for c in _box(origin, down, side, [4], range(0, 6)):
		w.dig(c)
	var bad := 0
	for i in 300:
		w.step_water()
		assert_int(w.water_count()).is_equal(n)
		for c in w.water_cells():
			if w.is_solid(c) or not w.shape.contains(c):
				bad += 1
	assert_int(bad).is_equal(0)
	var depth1 := 0
	for c in w.water_cells():
		depth1 = maxi(depth1, w.shape.depth_of(c))
	assert_int(depth1).is_greater(depth0)
	var wet: Vector2i = w.water_cells()[0]
	var at := w.shape.center_of(wet)
	assert_float(w.buoyancy_at(at).dot(w.shape.gravity_at(at))).is_less(0.0)
	var dry := w.shape.center_of(origin - down * 3)
	assert_vector(w.buoyancy_at(dry)).is_equal(Vector2.ZERO)
	w.drain_per_second = 50.0
	for i in 20:
		w.step_water()
	assert_int(w.water_count()).is_equal(0)


# --- 1. chunks ---------------------------------------------------------------------------------

func test_chunks_load_and_free() -> void:
	var w := _world(RectShape.new(256, 256, 32))
	var loads := {}
	var frees := {}
	w.chunk_loaded.connect(func(k): loads[k] = loads.get(k, 0) + 1)
	w.chunk_freed.connect(func(k): frees[k] = frees.get(k, 0) + 1)
	var a := _tracker(w, Vector2i(40, 40))          # chunk (1, 1)
	_check_chunks_follow(w, a)
	assert_int(w.loaded_chunks().size()).is_equal(9)
	var first := _sorted(w.loaded_chunks())
	a.position = w.shape.center_of(Vector2i(40 + 96, 40))   # 3 chunks right: (4, 1)
	_check_chunks_follow(w, a)
	assert_int(w.loaded_chunks().size()).is_equal(9)
	for k in first:
		assert_int(frees.get(k, 0)).is_equal(1)
		assert_bool(w.loaded_chunks().has(k)).is_false()
	for k in w.loaded_chunks():
		assert_int(loads.get(k, 0)).is_equal(1)
	var b := _tracker(w, Vector2i(5, 250))           # corner chunk (0, 7): clamped 2x2
	w.update_chunks()
	var want := {}
	for k in w.shape.neighbourhood(Vector2i(4, 1)):
		want[k] = true
	for k in w.shape.neighbourhood(Vector2i(0, 7)):
		want[k] = true
	assert_int(w.shape.neighbourhood(Vector2i(0, 7)).size()).is_equal(4)
	assert_array(_sorted(w.loaded_chunks())).is_equal(_sorted(want.keys()))
	w.update_chunks()
	for k in w.loaded_chunks():
		assert_int(loads.get(k, 0)).is_equal(1)
	w.untrack(a)
	w.untrack(b)
	w.update_chunks()
	assert_array(w.loaded_chunks()).is_empty()
	for k in want:
		assert_int(frees.get(k, 0)).is_equal(1)


func test_chunk_budget_limits_new_chunks_per_call() -> void:
	var w := _world(RectShape.new(256, 256, 32))
	_tracker(w, Vector2i(40, 40))
	w.update_chunks(2)
	assert_int(w.loaded_chunks().size()).is_equal(2)
	w.update_chunks(2)
	assert_int(w.loaded_chunks().size()).is_equal(4)
	w.update_chunks()
	assert_int(w.loaded_chunks().size()).is_equal(9)


# --- 2. saves ----------------------------------------------------------------------------------

func test_save_is_edit_only_and_round_trips() -> void:
	var cells: Array[Vector2i] = []
	for x in range(10, 16):
		cells.append(Vector2i(x, 20))
	_check_save_roundtrip(func(): return RectShape.new(128, 128, 32), cells)


func test_dig_in_unloaded_chunk_shows_on_load() -> void:
	var w := _world(RectShape.new(256, 256, 32))
	var far := Vector2i(200, 200)
	assert_array(w.loaded_chunks()).is_empty()
	assert_int(w.dig(far).size()).is_equal(1)
	assert_int(w.get_tile(far)).is_equal(0)
	_tracker(w, far)
	w.update_chunks()
	var layer: TileMapLayer = w._chunks[w.shape.chunk_of(far)]
	assert_int(layer.get_cell_source_id(far)).is_equal(-1)
	assert_int(layer.get_cell_source_id(far + Vector2i.RIGHT)).is_equal(0)
	assert_vector(Vector2(layer.get_cell_atlas_coords(far + Vector2i.RIGHT))).is_equal(Vector2(DIRT - 1, 0))


func test_load_save_accepts_ints_and_floats() -> void:
	var s := EditStore.new()
	s.load_save({"edits": [1.0, 2.0, 0.0, 3, 4, 2], "water": [5.0, 6.0, 1.0]})
	assert_int(s.tiles[Vector2i(1, 2)]).is_equal(0)
	assert_int(s.tiles[Vector2i(3, 4)]).is_equal(2)
	assert_bool(s.water[Vector2i(5, 6)]).is_true()


# --- 3. dig ------------------------------------------------------------------------------------

func test_dig_signals_blocked_air_and_offsets() -> void:
	var w := _world(RectShape.new(64, 64, 32))
	var dug: Array = []
	var blocked: Array = []
	w.tile_dug.connect(func(c, block, p): dug.append([c, block, p]))
	w.dig_blocked.connect(func(c, block, p): blocked.append([c, block, p]))
	var offs: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	var got := w.dig(Vector2i(10, 10), offs, 1)
	assert_array(_sorted(got)).is_equal(_sorted([Vector2i(10, 10), Vector2i(11, 10), Vector2i(10, 11)]))
	assert_int(dug.size()).is_equal(3)
	assert_that(dug[0]).is_equal([Vector2i(10, 10), &"dirt", 1])
	assert_int(w.get_tile(Vector2i(11, 10))).is_equal(0)
	# Air: ignored, no signal.
	assert_array(w.dig(Vector2i(10, 10), [Vector2i.ZERO], 0)).is_empty()
	assert_int(dug.size()).is_equal(3)
	# Unbreakable: bounce.
	w.set_tile(Vector2i(20, 20), STONE)
	assert_array(w.dig(Vector2i(20, 20), [Vector2i.ZERO], 2)).is_empty()
	assert_int(blocked.size()).is_equal(1)
	assert_that(blocked[0]).is_equal([Vector2i(20, 20), &"stone", 2])
	assert_int(w.get_tile(Vector2i(20, 20))).is_equal(STONE)
	# Outside the shape: nothing.
	assert_array(w.dig(Vector2i(-5, -5))).is_empty()
	assert_int(w.get_tile(Vector2i(-5, -5))).is_equal(0)


# --- 4. falling --------------------------------------------------------------------------------

func test_falling_body_wake_rules() -> void:
	var w := _world(RectShape.new(128, 128, 32))
	_tracker(w, Vector2i(40, 40))
	await _check_body_falls(w, Vector2i(40, 40))


func test_awake_cap_queues_wakes() -> void:
	var w := _world(RectShape.new(128, 64, 32), 4)
	_tracker(w, Vector2i(64, 20))
	w.update_chunks()
	var bodies: Array[FallingBody] = []
	var cells: Array[Vector2i] = []
	for i in 6:
		var c := Vector2i(8 + i * 20, 20)
		cells.append(c)
		w.set_tile(c, 0)
		var b := FallingBody.new()
		b.position = w.shape.center_of(c)
		w.add_child(b)
		bodies.append(b)
	for b in bodies:
		await _await_sleep(b)
		assert_bool(b.sleeping).is_true()
	w.max_awake_bodies = 3
	var landed := []
	w.body_landed.connect(func(body, _speed): landed.append(body))
	for c in cells:
		for d in range(1, 4):
			w.dig(c + Vector2i(0, d))
	var most := 0
	for i in 400:
		most = maxi(most, w.awake_bodies())
		await get_tree().physics_frame
	assert_int(most).is_less_equal(3)
	assert_int(most).is_greater(0)
	for i in 6:
		assert_bool(bodies[i].sleeping).is_true()
		assert_int(w.shape.cell_at(bodies[i].position).y).is_equal(23)
	assert_int(landed.size()).is_greater_equal(6)


func test_body_in_unloaded_chunk_is_frozen() -> void:
	var w := _world(RectShape.new(256, 128, 32))
	var t := _tracker(w, Vector2i(5, 5))
	w.update_chunks()
	var cell := Vector2i(200, 60)
	w.set_tile(cell, 0)
	var b := FallingBody.new()
	b.position = w.shape.center_of(cell)
	w.add_child(b)
	w.update_chunks()
	assert_bool(b.freeze).is_true()
	await _frames(10)
	assert_vector(b.position).is_equal(w.shape.center_of(cell))
	w.dig(cell + Vector2i.DOWN)   # undercut while unloaded
	t.position = b.position
	w.update_chunks()
	assert_bool(b.freeze).is_false()
	await _frames(60)
	assert_int(w.shape.cell_at(b.position).y).is_greater(cell.y)


# --- 5. props ----------------------------------------------------------------------------------

func test_breakable_prop_breaks_when_undercut() -> void:
	var w := _world(RectShape.new(64, 64, 32))
	_tracker(w, Vector2i(10, 10))
	w.update_chunks()
	_carve(w, _box(Vector2i(10, 10), Vector2i.DOWN, Vector2i.RIGHT, range(0, 2), range(0, 3)))
	var prop := BreakableProp.new()
	prop.footprint = Vector2i(3, 2)
	prop.position = Vector2(10, 10) * 16.0
	w.add_child(prop)
	var broke: Array = []
	w.prop_broke.connect(func(p, pieces): broke.append([p, pieces]))
	assert_array(_sorted(prop.support_cells())).is_equal(_sorted([Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12)]))
	w.dig(Vector2i(10, 12))
	assert_array(broke).is_empty()
	assert_bool(prop.broken).is_false()
	w.dig(Vector2i(11, 12))
	assert_int(broke.size()).is_equal(1)
	assert_object(broke[0][0]).is_same(prop)
	var pieces: Array = broke[0][1]
	assert_int(pieces.size()).is_equal(6)
	for p in pieces:
		assert_bool(p is FallingBody).is_true()
		assert_bool(p.is_inside_tree()).is_true()
	await _frames(2)
	assert_bool(is_instance_valid(prop)).is_false()


# --- 6. water ----------------------------------------------------------------------------------

func test_water_bounds_rect() -> void:
	var w := _world(RectShape.new(64, 64, 32), 2)
	_tracker(w, Vector2i(20, 20))
	w.update_chunks()
	_check_water(w, Vector2i(20, 10), Vector2i.DOWN, Vector2i.RIGHT)


func test_water_never_enters_unloaded_chunk() -> void:
	var w := _world(RectShape.new(128, 64, 32), 0)
	var t := _tracker(w, Vector2i(5, 5))
	w.update_chunks()
	_carve(w, _box(Vector2i(31, 2), Vector2i.DOWN, Vector2i.RIGHT, range(0, 4), [0]))
	_carve(w, _box(Vector2i(32, 5), Vector2i.DOWN, Vector2i.RIGHT, [0], range(0, 6)))   # into chunk (1, 0)
	for y in range(2, 6):
		w.set_water(Vector2i(31, y), true)
	var before := _sorted(w.water_cells())
	for i in 50:
		w.step_water()
	assert_array(_sorted(w.water_cells())).is_equal(before)
	w.chunk_radius = 1
	t.position = w.shape.center_of(Vector2i(33, 5))
	w.update_chunks()
	for i in 50:
		w.step_water()
	assert_int(w.water_count()).is_equal(4)
	var spread := false
	for c in w.water_cells():
		spread = spread or c.x >= 32
	assert_bool(spread).is_true()


# --- 7. polar swap -----------------------------------------------------------------------------

func test_polar_chunks_follow_tracked_node() -> void:
	var w := _world(DiskShape.new(96))
	var n := Node2D.new()
	n.position = Vector2.from_angle(2.3) * 90.0 * 16.0
	w.add_child(n)
	w.track(n)
	_check_chunks_follow(w, n)
	n.position = Vector2.from_angle(-0.7) * 40.0 * 16.0
	_check_chunks_follow(w, n)
	w.untrack(n)
	w.update_chunks()
	assert_array(w.loaded_chunks()).is_empty()


func test_polar_save_round_trip() -> void:
	var cells: Array[Vector2i] = []
	for y in range(-3, 3):
		cells.append(Vector2i(-80, y))
	_check_save_roundtrip(func(): return DiskShape.new(96), cells)


func test_polar_body_falls_toward_core() -> void:
	var w := _world(DiskShape.new(96))
	var cell := Vector2i(-96 + 10, 0)
	_tracker(w, cell)
	var x0 := w.shape.center_of(cell).x
	var b: FallingBody = await _check_body_falls(w, cell)
	assert_float(b.position.x).is_greater(x0 + 8.0)
	assert_float(b.position.length()).is_less(w.shape.center_of(cell).length())


func test_polar_water_moves_toward_core() -> void:
	var w := _world(DiskShape.new(96), 2)
	_tracker(w, Vector2i(-64, 0))
	w.update_chunks()
	_check_water(w, Vector2i(-72, -2), Vector2i.RIGHT, Vector2i.DOWN)


func test_chunk_manager_knows_no_concrete_shape() -> void:
	for f in ["tile_world.gd", "body_index.gd", "water_sim.gd", "darkness_overlay.gd",
			"falling_body.gd", "breakable_prop.gd", "edit_store.gd", "layered_generator.gd"]:
		var src := FileAccess.get_file_as_string(TW_DIR + f)
		assert_str(src).is_not_empty()
		assert_bool(src.contains("RectShape")).is_false()
		assert_bool(src.contains("DiskShape")).is_false()


# --- 8. darkness -------------------------------------------------------------------------------

func test_darkness_bands_and_sprites() -> void:
	var w := _world(RectShape.new(256, 128, 32))
	var t := _tracker(w, Vector2i(5, 5))
	w.update_chunks()
	assert_array(w._darkness.sprite_keys()).is_empty()
	w.set_darkness([
		{"from": 0, "to": 10, "darkness": 0.0},
		{"from": 10, "to": 50, "darkness": 0.5, "tint": Color(0.0, 0.0, 0.1)},
		{"from": 50, "to": 9999, "darkness": 0.9},
	])
	assert_float(w.darkness_at(5)).is_equal(0.0)
	assert_float(w.darkness_at(10)).is_equal(0.5)
	assert_float(w.darkness_at(49)).is_equal(0.5)
	assert_float(w.darkness_at(60)).is_equal(0.9)
	assert_float(w.darkness_at(-3)).is_equal(0.0)
	assert_array(_sorted(w._darkness.sprite_keys())).is_equal(_sorted(w.loaded_chunks()))
	t.position = w.shape.center_of(Vector2i(200, 100))
	w.update_chunks()
	assert_array(_sorted(w._darkness.sprite_keys())).is_equal(_sorted(w.loaded_chunks()))
	var lamp := Node2D.new()
	w.add_child(lamp)
	w.add_light(lamp, 100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(w._darkness.material_shared.get_shader_parameter("light_count")).is_equal(1)
	w.set_darkness([])
	assert_array(w._darkness.sprite_keys()).is_empty()


# --- 9. chunk-load fast paths ------------------------------------------------------------------

## A generator with rim, bands, caves and water, so every branch of base_chunk is hit.
func _busy_gen() -> LayeredGenerator:
	var g := LayeredGenerator.new()
	g.surface_depth = 3
	g.border_tile = STONE
	g.bands = [{"from": 0, "tile": DIRT}, {"from": 20, "tile": STONE}]
	g.cave_threshold = 0.2
	g.cave_min_depth = 2
	g.water_from_depth = 12
	return g


func _check_base_chunk(shape: WorldShape, keys: Array[Vector2i]) -> void:
	var g := _busy_gen()
	g.setup(shape, 99)
	var kinds := {}
	for k in keys:
		var cells := shape.chunk_cells(k)
		var fast := g.base_chunk(cells)
		assert_int(fast.size()).is_equal(cells.size())
		var bad := 0
		for i in cells.size():
			var want := g.base_tile(cells[i]) | (WorldGenerator.WATER_BIT if g.base_water(cells[i]) else 0)
			if fast[i] != want:
				bad += 1
			kinds[fast[i]] = true
		assert_int(bad).is_equal(0)
	# Air, both bands, the rim and water all showed up.
	for v in [0, DIRT, STONE, WorldGenerator.WATER_BIT]:
		assert_bool(kinds.has(v)).is_true()


func test_base_chunk_matches_per_cell_rect() -> void:
	var shape := RectShape.new(96, 96, 32)
	var keys: Array[Vector2i] = []
	for cy in 3:
		for cx in 3:
			keys.append(Vector2i(cx, cy))
	_check_base_chunk(shape, keys)


func test_base_chunk_matches_per_cell_disk() -> void:
	var shape := DiskShape.new(64, 16)
	var keys: Array[Vector2i] = []
	for ring in shape.rings():
		for s in shape.sectors_in(ring):
			keys.append(Vector2i(ring, s))
	_check_base_chunk(shape, keys)


## A subclass that overrides base_tile keeps its overrides on the bulk path.
class _Override extends LayeredGenerator:
	func base_tile(cell: Vector2i) -> int:
		return 0 if cell.x == 5 else super.base_tile(cell)


func test_base_chunk_respects_subclass_overrides() -> void:
	var shape := RectShape.new(32, 32, 32)
	var g := _Override.new()
	g.bands = [{"from": 0, "tile": DIRT}]
	g.cave_threshold = 2.0
	g.setup(shape, 1)
	var cells := shape.chunk_cells(Vector2i.ZERO)
	var ids := g.base_chunk(cells)
	for i in cells.size():
		assert_int(ids[i]).is_equal(0 if cells[i].x == 5 else DIRT)


func test_disk_chunk_cells_cache_agrees_with_chunk_of() -> void:
	var shape := DiskShape.new(64, 16)
	var seen := {}
	for ring in shape.rings():
		for s in shape.sectors_in(ring):
			var k := Vector2i(ring, s)
			var a := shape.chunk_cells(k)
			a.append(Vector2i(9999, 9999))            # callers get a copy
			var b := shape.chunk_cells(k)
			assert_int(b.size()).is_equal(a.size() - 1)
			for c in b:
				assert_bool(shape.contains(c)).is_true()
				assert_that(shape.chunk_of(c)).is_equal(k)
				assert_bool(seen.has(c)).is_false()
				seen[c] = true
	var inside := 0
	for y in range(-64, 64):
		for x in range(-64, 64):
			if shape.contains(Vector2i(x, y)):
				inside += 1
	assert_int(seen.size()).is_equal(inside)


func test_budgeted_frees_wait_for_a_call_without_loads() -> void:
	var w := _world(RectShape.new(256, 256, 32))
	var t := _tracker(w, Vector2i(40, 40))
	w.update_chunks()
	t.position = w.shape.center_of(Vector2i(40 + 32, 40))   # one chunk right: 3 in, 3 out
	var n := {"loads": 0, "frees": 0}
	w.chunk_loaded.connect(func(_k): n["loads"] += 1)
	w.chunk_freed.connect(func(_k): n["frees"] += 1)
	var calls := 0
	while calls < 20 and (n["loads"] < 3 or n["frees"] < 3):
		var l0: int = n["loads"]
		var f0: int = n["frees"]
		w.update_chunks(1)
		calls += 1
		assert_int(n["loads"] - l0).is_less_equal(1)
		assert_int(n["frees"] - f0).is_less_equal(2)
		assert_bool(n["loads"] > l0 and n["frees"] > f0).is_false()
	assert_int(n["loads"]).is_equal(3)
	assert_int(n["frees"]).is_equal(3)
	assert_array(_sorted(w.loaded_chunks())).is_equal(_sorted(w.shape.neighbourhood(Vector2i(2, 1))))


func test_edited_chunk_reloads_with_edits_and_untouched_chunk_without() -> void:
	var w := _world(RectShape.new(256, 64, 32), 0)
	var t := _tracker(w, Vector2i(5, 5))
	w.update_chunks()
	w.dig(Vector2i(6, 6))
	w.set_water(Vector2i(6, 6), true)
	w.set_tile(Vector2i(70, 5), 0)                        # unloaded chunk (2, 0)
	assert_bool(w._edited_chunks.has(Vector2i(0, 0))).is_true()
	assert_bool(w._edited_chunks.has(Vector2i(2, 0))).is_true()
	assert_bool(w._edited_chunks.has(Vector2i(1, 0))).is_false()
	t.position = w.shape.center_of(Vector2i(70, 5))
	w.update_chunks()
	assert_bool(w.is_loaded(Vector2i(70, 5))).is_true()
	assert_bool(w.is_solid(Vector2i(70, 5))).is_false()
	assert_bool(w._chunks[Vector2i(2, 0)].get_cell_source_id(Vector2i(70, 5)) == -1).is_true()
	assert_bool(w._chunks[Vector2i(2, 0)].get_cell_source_id(Vector2i(71, 5)) == 0).is_true()
	t.position = w.shape.center_of(Vector2i(5, 5))
	w.update_chunks()
	assert_bool(w.has_water(Vector2i(6, 6))).is_true()
	assert_bool(w.is_solid(Vector2i(6, 6))).is_false()
	var data := w.to_save()
	var b := _world(RectShape.new(256, 64, 32), 0)
	b.load_save(data)
	assert_bool(b._edited_chunks.has(Vector2i(0, 0))).is_true()
	assert_bool(b._edited_chunks.has(Vector2i(2, 0))).is_true()


# --- 10. body bookkeeping per frame ------------------------------------------------------------

func test_only_awake_bodies_are_synced_without_chunk_changes() -> void:
	var w := _world(RectShape.new(256, 64, 32), 0)
	var t := _tracker(w, Vector2i(10, 10))
	w.update_chunks()
	var resting: Array[FallingBody] = []
	for i in 6:
		var c := Vector2i(2 + i * 4, 10)
		w.set_tile(c, 0)
		var b := FallingBody.new()
		b.position = w.shape.center_of(c)
		w.add_child(b)
		resting.append(b)
	for b in resting:
		await _await_sleep(b)
	w.update_chunks()
	assert_int(w._bodies.synced_last).is_equal(0)          # nothing awake, nothing changed
	# An awake body walks out of the loaded chunk with no chunk change: it is frozen.
	_carve(w, _box(Vector2i(28, 12), Vector2i.DOWN, Vector2i.RIGHT, [0], range(0, 4)))
	var roller := FallingBody.new()
	roller.position = w.shape.center_of(Vector2i(28, 12))
	w.add_child(roller)
	w.update_chunks()
	assert_int(w._bodies.synced_last).is_equal(1)
	roller.position = w.shape.center_of(Vector2i(33, 12))   # chunk (1, 0): not loaded
	w.update_chunks()
	assert_bool(roller.freeze).is_true()
	# A chunk change checks every body.
	t.position = w.shape.center_of(Vector2i(40, 10))
	w.update_chunks()
	assert_int(w._bodies.synced_last).is_equal(7)
	assert_bool(roller.freeze).is_false()


func test_awake_cap_holds_when_bodies_wake_behind_the_index() -> void:
	var w := _world(RectShape.new(128, 64, 32), 4)
	_tracker(w, Vector2i(64, 20))
	w.update_chunks()
	var cap := 4
	var bodies: Array[FallingBody] = []
	for i in 12:
		var c := Vector2i(6 + i * 9, 20)
		w.set_tile(c, 0)
		w.set_tile(c + Vector2i.UP, 0)
		var b := FallingBody.new()
		b.position = w.shape.center_of(c + Vector2i.UP)      # one cell up: a short fall
		w.add_child(b)
		bodies.append(b)
	await _frames(1)
	w.max_awake_bodies = cap
	var most := 0
	for i in 600:
		await get_tree().physics_frame
		most = maxi(most, w.awake_bodies())
		if i == 200:
			for b in bodies:
				b.sleeping = false                           # the engine waking them, say
	assert_int(most).is_less_equal(cap)
	for b in bodies:
		assert_bool(b.sleeping).is_true()
		var cell := w.shape.cell_at(b.position)
		assert_bool(w.is_solid(w.shape.below(cell))).is_true()
	assert_array(w._bodies.queue).is_empty()
