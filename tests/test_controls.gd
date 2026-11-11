## Feel & controls lane (playtest 2026-11-10, PT10-6 to PT10-9): turning and aim (the character,
## the dig and the marker line up; turning never swings the view), the elevator ridden with A,
## the context button hints, and getting back up out of the mine.
class_name TestControls
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SUITE := "controls"

var _game: HillGame


func before() -> void:
	SuiteSandbox.enter(SUITE, "res://tests/fixtures/roster_two.json")
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


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _make() -> HillGame:
	_game = HillGame.new()
	_game.load_saved = false
	get_tree().root.add_child(_game)
	return _game


func _idle() -> Dictionary:
	return {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}


func _join(p: int, intent: Dictionary) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return intent
	return node


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


func _world() -> TileWorld:
	return _game.underground.world


## Fills rows y0..y1 of columns x0..x1 with Topsoil dirt, then carves `room` to air, and puts p's
## feet on the room's floor at column `at` (cell centre).
func _room(p: int, room: Rect2i, at: int) -> HillPlayer:
	var w := _world()
	var dirt := w.get_tile(Vector2i(room.position.x, room.end.y + 2))
	for y in range(room.position.y - 4, room.end.y + 3):
		for x in range(room.position.x - 6, room.end.x + 6):
			w.set_tile(Vector2i(x, y), dirt if not room.has_point(Vector2i(x, y)) else 0)
	_game.place_player(p, &"underground", Vector2((at + 0.5) * 16.0, room.end.y * 16.0 - 1.0))
	var node := _game.player_node(p)
	node.velocity = Vector2.ZERO
	return node


# --- PT10-6 turning and aim ---------------------------------------------------------------------

func test_turning_on_foot_never_swings_the_view() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	_room(P1, Rect2i(60, 14, 8, 2), 63)
	await _physics(2)
	var cam := _game.director.camera_of(P1)
	var lo := INF
	var hi := -INF
	for k in 8:
		it.move = Vector2(1 if k % 2 == 0 else -1, 0)
		it.dig = true
		for f in 20:
			await get_tree().physics_frame
			await get_tree().process_frame
			var sx := (node.global_position.x - cam.get_screen_center_position().x) * cam.zoom.x
			lo = minf(lo, sx)
			hi = maxf(hi, sx)
	# The character stays put on their screen while turning; what is left is the follow easing
	# while walking (before PT10-6 the lead swung ~190 px of a 960 px half-screen each turn).
	assert_float(hi - lo).is_less(80.0)
	assert_float(absf(_game.camera.lead_of(P1).x)).is_less(1.0)


func test_side_dig_takes_the_tile_next_to_the_body() -> void:
	_make()
	var node := _join(P1, _idle())
	_room(P1, Rect2i(60, 14, 3, 2), 61)
	await _physics(2)
	node.set_physics_process(false)
	var w := _world()
	# Standing in column 61 (room 60..62): right of the body is 62 (air), so nothing is dug and
	# never column 63 beyond it.
	assert_bool(node.dig_now(Vector2(1, 0))).is_false()
	assert_bool(w.is_solid(Vector2i(63, 15))).is_true()
	# Against the wall: the tile that touches the body.
	node.global_position.x = 62.5 * 16.0
	for cell in node.dig_cells(Vector2i(1, 0)):
		assert_int(cell.x).is_equal(63)
	assert_bool(node.dig_now(Vector2(1, 0))).is_true()
	assert_bool(w.is_solid(Vector2i(63, 15))).is_false()
	assert_bool(w.is_solid(Vector2i(64, 15))).is_true()
	node.set_physics_process(true)


func test_marker_is_the_next_dig_and_moves_with_the_player() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	_room(P1, Rect2i(60, 14, 3, 2), 62)
	it.move = Vector2(1, 0)
	await _physics(3)
	var mark := node.dig_marker_cell()
	assert_bool(node.dig_targets(node.aim).has(mark)).is_true()
	assert_int(mark.x).is_equal(63)
	it.move = Vector2(-1, 0)
	await _physics(30)
	# Facing left at the room's left wall: the marker is on the tile left of the body.
	assert_int(node.facing).is_equal(-1)
	assert_int(node.dig_marker_cell().x).is_equal(59)
	it.move = Vector2.ZERO
	it.dig = true
	await _until(func() -> bool: return not _world().is_solid(Vector2i(59, 15)), 30)
	assert_bool(_world().is_solid(Vector2i(59, 15))).is_false()


func test_a_wobbly_stick_aiming_down_never_flips_facing() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	_room(P1, Rect2i(60, 14, 3, 2), 61)
	node.facing = 1
	for k in 10:
		it.move = Vector2(0.3 if k % 2 == 0 else -0.3, 0.95)
		await _physics(2)
		assert_int(node.facing).is_equal(1)
		assert_vector(Vector2(node.aim)).is_equal(Vector2(0, 1))
	# A diagonal keeps the axis it had until the other is clearly stronger.
	it.move = Vector2(0.8, 0.7)
	await _physics(1)
	assert_vector(Vector2(node.aim)).is_equal(Vector2(0, 1))
	it.move = Vector2(1, 0.2)
	await _physics(1)
	assert_vector(Vector2(node.aim)).is_equal(Vector2(1, 0))


func test_no_shovel_no_dig() -> void:
	var scr := GDScript.new()
	scr.source_code = "extends HillPlayer\nvar has_shovel := false\n"
	scr.reload()
	var pl: HillPlayer = scr.new()
	assert_bool(pl.shovel_ok()).is_false()
	pl.free()
	var plain := HillPlayer.new()
	assert_bool(plain.shovel_ok()).is_true()
	plain.free()
