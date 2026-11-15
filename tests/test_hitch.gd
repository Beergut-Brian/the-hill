## S-21: no frame over 33 ms on the bench route. The 150 ms hitch on the TV box (2026-11-14) was a
## jump underground building the whole 3x3 chunk neighbourhood in one frame, each chunk ~11 ms (the
## generator most of it). Pinned here: chunk base tiles are generated on worker threads (prewarm),
## a jump loads only the chunks under the feet, the rest follow the per-frame budget nearest first,
## and a walker going to and fro over a chunk border does not rebuild a column every turn.
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const DIRT := 1


## Counts base_chunk calls made on the main thread (worker-thread calls are prewarm's).
class CountingGen extends LayeredGenerator:
	var main_calls := 0

	func base_chunk(cells: Array[Vector2i]) -> PackedInt32Array:
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			main_calls += 1
		var out := PackedInt32Array()
		out.resize(cells.size())
		for i in cells.size():
			out[i] = DIRT
		return out


var _game: HillGame


func before() -> void:
	SuiteSandbox.enter("hitch")


func after() -> void:
	SuiteSandbox.leave()


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	_game = null
	Players.reset()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _palette() -> Array[TileDef]:
	var air := TileDef.new()
	air.id = &"air"
	air.solid = false
	var dirt := TileDef.new()
	dirt.id = &"dirt"
	return [air, dirt]


func _world(gen: WorldGenerator, size := Vector2i(8, 8)) -> TileWorld:
	var w := TileWorld.new()
	w.water_hz = 0.0
	w.setup(RectShape.new(size.x * 16, size.y * 16, 16), gen, _palette(), 7)
	add_child(w)
	auto_free(w)
	return w


func _keys(size: Vector2i) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			keys.append(Vector2i(x, y))
	return keys


func _wait_prewarm(w: TileWorld) -> void:
	for i in 600:
		if not w.prewarming():
			return
		await get_tree().process_frame


func _tracker(w: TileWorld, chunk: Vector2i) -> Node2D:
	var n := Node2D.new()
	n.position = (Vector2(chunk) * 16.0 + Vector2(8, 8)) * 16.0
	w.add_child(n)
	w.track(n)
	return n


# --- TileWorld ---------------------------------------------------------------------------------

func test_prewarm_generates_off_the_main_thread_and_loads_reuse_it() -> void:
	var gen := CountingGen.new()
	var w := _world(gen)
	w.prewarm(_keys(Vector2i(8, 8)))
	await _wait_prewarm(w)
	assert_bool(w.prewarming()).is_false()
	assert_int(w.cached_chunks()).is_equal(64)
	assert_int(gen.main_calls).is_equal(0)
	var n := _tracker(w, Vector2i(3, 3))
	w.update_chunks()
	assert_int(w.loaded_chunks().size()).is_equal(9)
	assert_int(gen.main_calls).override_failure_message("a chunk load ran the generator").is_equal(0)
	assert_bool(w.is_solid(Vector2i(3 * 16 + 1, 3 * 16 + 1))).is_true()
	n.queue_free()


func test_a_freed_chunk_reloads_without_the_generator() -> void:
	var gen := CountingGen.new()
	var w := _world(gen)
	var n := _tracker(w, Vector2i(1, 1))
	w.update_chunks()
	var first := gen.main_calls
	assert_int(first).is_equal(9)
	n.position = (Vector2(6, 6) * 16.0 + Vector2(8, 8)) * 16.0
	w.update_chunks()
	n.position = (Vector2(1, 1) * 16.0 + Vector2(8, 8)) * 16.0
	w.update_chunks()
	assert_int(gen.main_calls).is_equal(first + 9)   # only (6, 6)'s new neighbourhood
	n.queue_free()


func test_load_under_builds_only_the_feet_then_the_budget_fills_nearest_first() -> void:
	var gen := CountingGen.new()
	var w := _world(gen)
	var keeper := _tracker(w, Vector2i(0, 0))
	w.update_chunks()
	assert_int(w.loaded_chunks().size()).is_equal(4)
	# A jump to chunk (5, 5), feet on its bottom row: its own chunk and the one under it.
	var n := Node2D.new()
	n.position = Vector2(5 * 256 + 128, 6 * 256 - 1)
	w.add_child(n)
	w.track(n)
	w.load_under(n)
	var now := w.loaded_chunks()
	assert_int(now.size()).is_equal(6)
	assert_bool(now.has(Vector2i(5, 5))).is_true()
	assert_bool(now.has(Vector2i(5, 6))).is_true()
	# The per-frame path: never more than chunk_budget_per_frame chunks built in one tick.
	var before := now.size()
	for i in 12:
		await get_tree().physics_frame
		var size := w.loaded_chunks().size()
		assert_int(size - before).is_less_equal(w.chunk_budget_per_frame)
		before = size
	for k in [Vector2i(4, 4), Vector2i(6, 6), Vector2i(4, 6)]:
		assert_bool(w.loaded_chunks().has(k)).is_true()
	keeper.queue_free()
	n.queue_free()


func test_keep_margin_stops_border_thrash() -> void:
	var gen := CountingGen.new()
	var w := _world(gen)
	w.chunk_keep_margin = 1
	var n := _tracker(w, Vector2i(3, 3))
	w.update_chunks()
	assert_int(w.loaded_chunks().size()).is_equal(9)
	var frees := [0]
	w.chunk_freed.connect(func(_k: Vector2i) -> void: frees[0] += 1)
	for i in 6:
		n.position.x += 256.0 if i % 2 == 0 else -256.0   # chunk 4, chunk 3, chunk 4 ...
		w.update_chunks()
	assert_int(frees[0]).override_failure_message("chunks freed walking over a border").is_equal(0)
	n.position = (Vector2(7, 7) * 16.0 + Vector2(8, 8)) * 16.0
	w.update_chunks()
	assert_bool(w.loaded_chunks().has(Vector2i(2, 2))).is_false()   # far away still frees
	n.queue_free()


# --- The Hill ----------------------------------------------------------------------------------

func _make() -> HillGame:
	Save.profile = "test_hitch"
	Save.wipe()
	Players.reset()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_game = HillGame.new()
	get_tree().root.add_child(_game)
	return _game


func test_the_underground_prewarms_every_chunk() -> void:
	var g := _make()
	var w := g.underground.world
	await _wait_prewarm(w)
	assert_int(w.cached_chunks()).is_equal(g.underground.all_chunks().size())
	assert_int(w.chunk_keep_margin).is_equal(1)


func test_a_jump_underground_builds_at_most_the_two_chunks_under_the_feet() -> void:
	var g := _make()
	Players.join_virtual(P1)
	var node := g.player_node(P1)
	if node == null:
		node = g.wake(P1)
	node.intent_source = func() -> Dictionary: return IDLE
	await get_tree().physics_frame
	var w := g.underground.world
	await _wait_prewarm(w)
	var built := [0]
	w.chunk_loaded.connect(func(_k: Vector2i) -> void: built[0] += 1)
	var u := g.underground
	g.place_player(P1, HillGame.UNDERGROUND, u.landing(u.layers().size() - 1))
	assert_int(built[0]).override_failure_message("a jump built %d chunks in one frame" % built[0]).is_less_equal(2)
	var feet := w.shape.cell_at(w.local_pos(node))
	assert_bool(w.is_loaded(feet + Vector2i.DOWN)).is_true()   # a floor this frame
	for i in 20:
		await get_tree().physics_frame
	var key := w.shape.chunk_of(feet)
	for k in w.shape.neighbourhood(key, w.chunk_radius):
		assert_bool(w.loaded_chunks().has(k)).is_true()
