## TileWorld tile art and light pass (docs/contracts.md "Tile art and the light pass"): open masks
## follow digs (also across a chunk edge), back walls only behind dug cells, the dark never reaches
## alpha 1, lights carry a strength and only the 32 nearest to a tracked node are drawn.
class_name TestArtTileWorld
extends GdUnitTestSuite

const DemoArt := preload("res://addons/openjar/tileworld/demo/demo_tile_art.gd")
const DIRT := 1


func _palette() -> Array[TileDef]:
	var air := TileDef.new()
	air.id = &"air"
	air.solid = false
	air.breakable = false
	var dirt := TileDef.new()
	dirt.id = &"dirt"
	dirt.color = Color(0.5, 0.35, 0.2)
	return [air, dirt]


func _world(shape: WorldShape, surface := 0, radius := 0) -> TileWorld:
	var g := LayeredGenerator.new()
	g.bands = [{"from": 0, "tile": DIRT}]
	g.surface_depth = surface
	g.cave_threshold = 2.0
	var w := TileWorld.new()
	w.water_hz = 0.0
	w.chunk_radius = radius
	w.tile_art = DemoArt.new()
	w.setup(shape, g, _palette(), 1234)
	add_child(w)
	auto_free(w)
	return w


func _tracker(w: TileWorld, cell: Vector2i) -> Node2D:
	var n := Node2D.new()
	n.position = w.shape.center_of(cell)
	w.add_child(n)
	w.track(n)
	return n


func _layer(w: TileWorld, c: Vector2i) -> TileMapLayer:
	return w._chunks.get(w.shape.chunk_of(c))


func _src(w: TileWorld, c: Vector2i) -> int:
	return _layer(w, c).get_cell_source_id(c)


func _open(w: TileWorld, c: Vector2i) -> int:
	assert_int(_src(w, c)).is_equal(TileArt.SOLID_SOURCE)
	return _layer(w, c).get_cell_atlas_coords(c).y


func test_masks_follow_digs_across_a_chunk_edge() -> void:
	var w := _world(RectShape.new(128, 64, 32), 0, 1)
	_tracker(w, Vector2i(31, 10))
	w.update_chunks()
	assert_bool(w.is_loaded(Vector2i(31, 10)) and w.is_loaded(Vector2i(32, 10))).is_true()
	assert_int(_open(w, Vector2i(31, 10))).is_equal(0)
	# (32, 10) is in the next chunk: its left neighbour (31, 10) gets an open right side.
	w.dig(Vector2i(32, 10))
	assert_int(_open(w, Vector2i(31, 10))).is_equal(TileArt.OPEN_RIGHT)
	assert_int(_open(w, Vector2i(32, 11))).is_equal(TileArt.OPEN_UP)
	assert_int(_open(w, Vector2i(32, 9))).is_equal(TileArt.OPEN_DOWN)
	assert_int(_open(w, Vector2i(33, 10))).is_equal(TileArt.OPEN_LEFT)
	# The dug cell shows a back wall with the lip (solid ceiling above).
	assert_int(_src(w, Vector2i(32, 10))).is_equal(TileArt.WALL_SOURCE)
	assert_int(_layer(w, Vector2i(32, 10)).get_cell_atlas_coords(Vector2i(32, 10)).y).is_equal(1)
	# Open the ceiling: the lip moves up a cell.
	w.dig(Vector2i(32, 9))
	assert_int(_layer(w, Vector2i(32, 10)).get_cell_atlas_coords(Vector2i(32, 10)).y).is_equal(0)
	assert_int(_layer(w, Vector2i(32, 9)).get_cell_atlas_coords(Vector2i(32, 9)).y).is_equal(1)
	# Refill: masks go back.
	w.set_tile(Vector2i(32, 9), DIRT)
	w.set_tile(Vector2i(32, 10), DIRT)
	assert_int(_open(w, Vector2i(31, 10))).is_equal(0)
	assert_int(_open(w, Vector2i(32, 10))).is_equal(0)


func test_mask_at_chunk_load_sees_the_unloaded_neighbour() -> void:
	var w := _world(RectShape.new(128, 64, 32), 0, 0)
	var t := _tracker(w, Vector2i(40, 10))
	w.update_chunks()
	assert_bool(w.is_loaded(Vector2i(31, 10))).is_false()
	w.dig(Vector2i(32, 10))
	t.position = w.shape.center_of(Vector2i(10, 10))
	w.update_chunks()
	assert_bool(w.is_loaded(Vector2i(32, 10))).is_false()
	assert_int(_open(w, Vector2i(31, 10))).is_equal(TileArt.OPEN_RIGHT)
	assert_int(_open(w, Vector2i(30, 10))).is_equal(0)


func test_walls_only_behind_dug_cells() -> void:
	var w := _world(RectShape.new(64, 64, 32), 4, 0)
	_tracker(w, Vector2i(10, 10))
	w.update_chunks()
	# Rows 0..3 are air in the base world: no wall, the backdrop shows.
	for x in 8:
		assert_int(_src(w, Vector2i(x, 2))).is_equal(-1)
	assert_int(_open(w, Vector2i(5, 4))).is_equal(TileArt.OPEN_UP)
	w.dig(Vector2i(5, 8))
	assert_int(_src(w, Vector2i(5, 8))).is_equal(TileArt.WALL_SOURCE)
	assert_int(_src(w, Vector2i(6, 8))).is_equal(TileArt.SOLID_SOURCE)
	# A cell set to air that was air in the base keeps no wall.
	w.set_tile(Vector2i(5, 2), DIRT)
	assert_int(_src(w, Vector2i(5, 2))).is_equal(TileArt.SOLID_SOURCE)
	w.set_tile(Vector2i(5, 2), 0)
	assert_int(_src(w, Vector2i(5, 2))).is_equal(-1)


func test_without_art_the_world_is_unchanged() -> void:
	var w := TileWorld.new()
	w.water_hz = 0.0
	var g := LayeredGenerator.new()
	g.bands = [{"from": 0, "tile": DIRT}]
	g.cave_threshold = 2.0
	w.setup(RectShape.new(64, 64, 32), g, _palette(), 1)
	add_child(w)
	auto_free(w)
	_tracker(w, Vector2i(5, 5))
	w.update_chunks()
	w.dig(Vector2i(5, 5))
	var layer := _layer(w, Vector2i(5, 5))
	assert_int(layer.get_cell_source_id(Vector2i(5, 5))).is_equal(-1)
	assert_object(layer.get_cell_atlas_coords(Vector2i(6, 5))).is_equal(Vector2i(0, 0))


func test_dark_never_reaches_black() -> void:
	var w := _world(RectShape.new(64, 64, 32))
	_tracker(w, Vector2i(10, 10))
	w.update_chunks()
	w.set_darkness([{"from": 0, "to": 9999, "darkness": 1.0, "tint": Color.BLACK}])
	assert_float(w.darkness_at(10)).is_equal(1.0)
	var mat := w._darkness.material_shared
	var floor_alpha: float = mat.get_shader_parameter("floor_alpha")
	assert_float(w.darkness_floor).is_equal(0.8)
	# The darkest texel (r = 1) renders at r * floor_alpha, never 1, and the night is not black.
	assert_float(w._darkness.texel(Vector2i(10, 10)).r).is_equal(1.0)
	assert_float(floor_alpha).is_less(1.0)
	var night: Color = mat.get_shader_parameter("night")
	assert_float(night.b).is_greater(0.0)
	w.darkness_floor = 2.0 / 3.0
	assert_float(mat.get_shader_parameter("floor_alpha")).is_equal_approx(2.0 / 3.0, 0.0001)


func test_occlusion_texels_follow_digs() -> void:
	var w := _world(RectShape.new(128, 64, 32), 0, 1)
	_tracker(w, Vector2i(31, 10))
	w.update_chunks()
	w.set_darkness([{"from": 0, "to": 9999, "darkness": 0.6}])
	var d := w._darkness
	assert_int(d.texel(Vector2i(31, 10)).b8).is_equal(255)
	w.dig(Vector2i(32, 10))
	assert_int(d.texel(Vector2i(32, 10)).b8).is_equal(0)
	assert_int(d.texel(Vector2i(31, 10)).b8).is_equal(128)
	assert_int(d.texel(Vector2i(33, 10)).b8).is_equal(128)
	assert_int(d.texel(Vector2i(30, 10)).b8).is_equal(255)
	# Band darkness stays in R.
	assert_int(d.texel(Vector2i(32, 10)).r8).is_equal(roundi(0.6 * 255.0))


func test_lights_strength_and_cap() -> void:
	var w := _world(RectShape.new(128, 64, 32), 0, 1)
	var t := _tracker(w, Vector2i(10, 10))
	w.update_chunks()
	w.set_darkness([{"from": 0, "to": 9999, "darkness": 0.8}])
	var near := Node2D.new()
	near.position = t.position + Vector2(4, 0)
	w.add_child(near)
	auto_free(near)
	w.add_light(near, 64.0, 0.5)
	var far: Array[Node2D] = []
	for i in 40:
		var n := Node2D.new()
		n.position = t.position + Vector2(100 + i * 20, 0)
		w.add_child(n)
		auto_free(n)
		w.add_light(n, 80.0)
		far.append(n)
	await get_tree().process_frame
	await get_tree().process_frame
	var mat := w._darkness.material_shared
	assert_int(mat.get_shader_parameter("light_count")).is_equal(32)
	var picked := w._darkness.pick_lights()
	assert_int(picked.size()).is_equal(32)
	assert_bool(picked.has(near)).is_true()
	assert_bool(picked.has(far[0])).is_true()
	assert_bool(picked.has(far[39])).is_false()
	var arr: PackedVector4Array = mat.get_shader_parameter("lights")
	var found := false
	for v in arr:
		if is_equal_approx(v.z, 64.0) and is_equal_approx(v.w, 0.5):
			found = true
	assert_bool(found).is_true()
	w.remove_light(near)
	assert_bool(w._darkness.pick_lights().has(near)).is_false()


func before() -> void:
	SuiteSandbox.enter("art_tileworld")   # never the real profile, settings or picks file


func after() -> void:
	SuiteSandbox.leave()
