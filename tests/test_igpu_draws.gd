## hill-igpu-2: draw calls on the bench route. Cracks go out as one triangle array (TriBatch) and
## only near a player; the deep hazard art (lava pools, ice holes) is drawn only near a player.
extends GdUnitTestSuite

const P1 := Players.P1

var _game: HillGame


func before() -> void:
	SuiteSandbox.enter("igpu_draws", "res://tests/fixtures/roster_two.json")
	Game.quit_exits = false


func after() -> void:
	Game.quit_exits = true
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	DigFeel.demo_open = false


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	_game = null


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _make() -> HillGame:
	_game = HillGame.new()
	_game.load_saved = false
	get_tree().root.add_child(_game)
	return _game


func _join_underground(at: Vector2) -> HillPlayer:
	var pl := _game.player_node(P1)
	if pl == null:
		pl = _game.wake(P1)
	_game.place_player(P1, &"underground", at)
	return _game.player_node(P1)


# --- TriBatch ------------------------------------------------------------------------------------

func test_tri_batch_keeps_every_shape_as_triangles_in_order() -> void:
	var b := TriBatch.new()
	b.line(Vector2(0, 0), Vector2(10, 0), Color.RED, 2.0)
	assert_int(b.points.size()).is_equal(4)
	assert_int(b.indices.size()).is_equal(6)
	# A width-2 line along x is a quad 1 px either side.
	assert_float(b.points[0].distance_to(Vector2(0, 0))).is_equal_approx(1.0, 0.0001)
	assert_float(absf(b.points[2].y)).is_equal_approx(1.0, 0.0001)
	b.circle(Vector2(5, 5), 3.0, Color.BLUE)
	assert_int(b.points.size()).is_equal(4 + 1 + TriBatch.CIRCLE_SEGMENTS)
	assert_int(b.indices.size()).is_equal(6 + 3 * TriBatch.CIRCLE_SEGMENTS)
	b.polygon(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(0, 4)]), Color.GREEN)
	assert_int(b.indices.size()).is_equal(6 + 3 * TriBatch.CIRCLE_SEGMENTS + 3)
	# Colours ride per vertex, in the order the shapes came in (later shapes blend on top).
	assert_that(b.colors[0]).is_equal(Color.RED)
	assert_that(b.colors[4]).is_equal(Color.BLUE)
	assert_that(b.colors[b.colors.size() - 1]).is_equal(Color.GREEN)
	for i in b.indices:
		assert_int(i).is_less(b.points.size())
	# Degenerate shapes add nothing.
	var e := TriBatch.new()
	e.line(Vector2.ONE, Vector2.ONE, Color.RED, 2.0)
	e.circle(Vector2.ZERO, 0.0, Color.RED)
	assert_bool(e.is_empty()).is_true()
	var n := Node2D.new()
	add_child(n)
	b.flush(n)
	assert_bool(b.is_empty()).is_true()
	n.free()


func test_outside_a_split_screen_everything_is_in_view() -> void:
	var n := Node2D.new()
	add_child(n)
	var views := DigFeel.visible_rects(n)
	assert_int(views.size()).is_equal(1)
	assert_bool(DigFeel.in_view(Rect2(99999, -99999, 4, 4), views)).is_true()
	assert_bool(DigFeel.in_view(Rect2(0, 0, 4, 4), [] as Array[Rect2])).is_false()
	n.free()


# --- in the game ---------------------------------------------------------------------------------

func test_cracks_are_drawn_only_where_a_view_looks_in_one_batch() -> void:
	_make()
	await _physics(2)
	var feel := _game.underground.dig_feel
	var w := _game.underground.world
	var at := Vector2(60.5 * 16.0, 14.0 * 16.0)
	_join_underground(at)
	await _physics(15)   # the camera follows a few frames after the jump
	var views := ScreenDirector.view_rects_of(w.get_world_2d())
	assert_int(views.size()).is_equal(1)
	assert_bool(views[0].has_point(_game.player_node(P1).global_position)) \
			.override_failure_message("%s not in %s" % [_game.player_node(P1).global_position, views[0]]).is_true()
	var here := w.shape.cell_at(at) + Vector2i(1, 1)
	var far := here + Vector2i(100, 0)   # 1600 px away: off any view at zoom 2
	feel.damage[here] = 1
	feel.damage[far] = 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(feel.drawn_cracks).is_equal(1)
	# The far one is still there (it shows when a view gets there).
	assert_bool(feel.damage.has(far)).is_true()
	_game.place_player(P1, &"underground", w.shape.center_of(far))
	await _physics(15)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(feel.drawn_cracks).is_equal(1)
	# Nothing left in the batch between frames.
	assert_bool(feel._batch.is_empty()).is_true()
	# Nobody underground: no view shows it, nothing is built.
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X - 300.0, 0))
	await _physics(3)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(ScreenDirector.view_rects_of(w.get_world_2d()).size()).is_equal(0)
	assert_int(feel.drawn_cracks).is_equal(0)
	assert_int(feel.drawn_signs).is_equal(0)


func test_deep_hazard_art_draws_only_what_a_view_shows() -> void:
	_make()
	await _physics(2)
	var g := _game.underground.generator
	var art: Node2D = _game.underground.world.get_node("DeepHazardArt")
	var pool: Rect2i = g.lava_pockets[0].pool
	_join_underground(Vector2(pool.position.x * 16.0 + 8.0, pool.position.y * 16.0 - 2.0))
	await _physics(5)
	await get_tree().process_frame
	await get_tree().process_frame
	var views := DigFeel.visible_rects(art)
	var want := 0
	var total := 0
	for lp in g.lava_pockets:
		total += 1
		var r := Rect2(Vector2((lp.pool as Rect2i).position) * 16.0, Vector2((lp.pool as Rect2i).size) * 16.0).grow(40.0)
		want += 1 if DigFeel.in_view(r, views) else 0
	for ih in g.ice_holes:
		total += 1
		want += 1 if DigFeel.in_view(art.hole_box(ih), views) else 0
	assert_int(want).is_greater_equal(1)
	assert_int(want).is_less(total)
	assert_int(art.drawn).is_equal(want)
