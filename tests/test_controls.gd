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


# --- PT10-9 the elevator rides with A -------------------------------------------------------------

func _press_a(it: Dictionary) -> void:
	it.dig = true
	await _physics(2)
	it.dig = false


func _in_top_cage(p: int) -> void:
	_game.place_player(p, &"hillville", _game.hillville.arrival() + Vector2(0, -1))


func test_standing_in_the_cage_shows_a_and_only_a_rides() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	Progress.visit_layer(P1, 1)
	_in_top_cage(P1)
	await _physics(90)
	# No walk-in: still up top after 1.5 s, with the blinking A over the head.
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_int(node.lift_prompt()).is_equal(1)
	assert_bool(node.lift_ready()).is_true()
	await _press_a(it)
	assert_int(node.lift_prompt()).is_equal(2)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"underground" and not node.locked, 120)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
	assert_float(node.global_position.distance_to(_game.underground.landing(1))).is_less(20.0)
	# A held from before the ride does not send them straight back up.
	it.dig = true
	await _physics(60)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
	it.dig = false
	await _physics(2)
	# Up: A again in the landing cage (the car is already here: no call).
	node.keep_block(&"clay")
	await _press_a(it)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"hillville" and not node.locked, 120)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_int(Inventory.count(&"clay")).is_equal(1)


func test_a_with_the_stick_sideways_digs_out_of_the_cage_instead() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	_game.place_player(P1, &"underground", _game.underground.landing(0))
	await _physics(3)
	it.move = Vector2(-1, 0)
	await _press_a(it)
	await _physics(20)
	assert_bool(_game.elevator.is_riding(P1)).is_false()
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")


func test_a_partner_within_the_radius_rides_along_one_further_away_stays() -> void:
	_make()
	var it := _idle()
	var a := _join(P1, it)
	var b := _join(P2, _idle())
	_in_top_cage(P1)
	var radius := _game.elevator.tuning.pull_radius_px()
	assert_float(_game.elevator.tuning.pull_radius_tiles).is_equal_approx(3.0, 0.01)
	var zone: Rect2 = _game.hillville.cage_zone()
	_game.place_player(P2, &"hillville", Vector2(zone.end.x + radius - 10.0, -1))
	await _physics(3)
	await _press_a(it)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"underground" and not a.locked, 120)
	assert_str(String(_game.director.scene_of(P2))).is_equal("underground")
	assert_bool(b.locked).is_false()
	# Back up: P2 now far from the landing cage stays below.
	_game.place_player(P2, &"underground", _game.underground.landing(0) + Vector2(radius + 80.0, 0))
	await _physics(3)
	await _press_a(it)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"hillville" and not a.locked, 120)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_str(String(_game.director.scene_of(P2))).is_equal("underground")


func test_p2_alone_rides_and_p1_in_the_other_scene_is_never_pulled() -> void:
	_make()
	_join(P1, _idle())
	var it := _idle()
	var b := _join(P2, it)
	_game.place_player(P1, &"underground", _game.underground.landing(0))
	_in_top_cage(P2)
	await _physics(3)
	await _press_a(it)
	await _until(func() -> bool: return _game.director.scene_of(P2) == &"underground" and not b.locked, 120)
	assert_str(String(_game.director.scene_of(P2))).is_equal("underground")
	assert_bool(_game.elevator.is_riding(P1)).is_false()


# --- PT10-7b the car is called down the rope -------------------------------------------------------

func test_a_at_a_deep_landing_calls_the_car_down_then_rides_up() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	for i in 4:
		Progress.visit_layer(P1, i)
	_game.place_player(P1, &"underground", _game.underground.landing(3))
	assert_int(_game.elevator.car_at).is_equal(-1)
	await _physics(3)
	await _press_a(it)
	# The car comes down the rope: part-way there, the rider waits (dim A).
	await _physics(6)
	var at := _game.elevator.car_position()
	assert_float(at).is_greater(-1.0)
	assert_float(at).is_less(3.0)
	assert_int(node.lift_prompt()).is_equal(2)
	var rope: ShaftRope = _game.underground.get_node_or_null(^"ShaftRope")
	assert_object(rope).is_not_null()
	assert_int(rope.deepest_reached()).is_equal(3)
	var frames := await _until(func() -> bool: return _game.director.scene_of(P1) == &"hillville" and not node.locked, 200)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	# Call (at most call_max) + ride: well under 2 s.
	assert_int(frames).is_less(int((_game.elevator.tuning.call_max + HillElevator.RIDE_TIME) * 60.0) + 10)
	assert_int(_game.elevator.car_at).is_equal(-1)


# --- PT10-8 context button hints ------------------------------------------------------------------

func _icons(p: int) -> Dictionary:
	_game.hints.refresh()
	var out := {}
	for h in _game.hints.panel_of(p).hints():
		out[h.button] = h.icon
	return out


func test_hints_follow_the_context_the_same_frame() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	# Up top on foot, away from vehicles: B jump, X book (no A: nothing to dig up top on foot).
	_game.place_player(P1, &"hillville", Vector2(Hillville.SHAFT_X + 300, 0))
	await _physics(2)
	assert_dict(_icons(P1)).is_equal({"b": &"jump", "x": &"book"})
	# Beside the Front Loader: B gets in.
	var lx: float = _game.loader_position().pos.x
	_game.place_player(P1, &"hillville", Vector2(lx - 30.0, 0))
	await _physics(2)
	assert_dict(_icons(P1)).is_equal({"b": &"enter", "x": &"book"})
	# In it: A scoops, B gets out.
	assert_bool(_game.hop_in(node)).is_true()
	assert_dict(_icons(P1)).is_equal({"a": &"scoop", "b": &"exit", "x": &"book"})
	_game.hop_out(node, true)
	# In the cage: A rides.
	_game.place_player(P1, &"hillville", _game.hillville.arrival() + Vector2(0, -1))
	await _physics(3)
	assert_dict(_icons(P1)).is_equal({"a": &"ride", "b": &"jump", "x": &"book"})
	# Underground on foot: A digs, B jumps; stick up: A climbs.
	_room(P1, Rect2i(60, 14, 4, 2), 61)
	await _physics(2)
	assert_dict(_icons(P1)).is_equal({"a": &"dig", "b": &"jump"})
	it.move = Vector2(0, -1)
	await _physics(1)
	assert_dict(_icons(P1)).is_equal({"a": &"climb", "b": &"jump"})


func test_each_player_gets_their_own_panel_in_their_corner() -> void:
	_make()
	_join(P1, _idle())
	_join(P2, _idle())
	_game.place_player(P1, &"hillville", Vector2(Hillville.SHAFT_X + 300, 0))
	_room(P2, Rect2i(60, 14, 4, 2), 61)
	await _physics(3)
	_icons(P1)
	var a: ButtonHints = _game.hints.panel_of(P1)
	var b: ButtonHints = _game.hints.panel_of(P2)
	assert_object(a).is_not_null()
	assert_object(b).is_not_null()
	assert_bool(b.align_right).is_true()
	assert_bool(a.get_global_rect().get_center().x < b.get_global_rect().get_center().x).is_true()
	# Inside each player's own view (split: P1 left half, P2 right half).
	assert_bool(_game.director.view_rect_of(P1).encloses(a.get_global_rect())).is_true()
	assert_bool(_game.director.view_rect_of(P2).encloses(b.get_global_rect())).is_true()
	assert_dict(_icons(P2)).is_equal({"a": &"dig", "b": &"jump"})


func test_button_hints_kit_pops_changed_rows_and_takes_custom_icons() -> void:
	var bh: ButtonHints = preload("res://scenes/ui/kit/button_hints.tscn").instantiate()
	add_child(bh)
	assert_bool(bh.show_hints([{"button": "b", "icon": &"jump"}, {"button": "a", "icon": &"dig"}])).is_true()
	assert_str(bh.hints()[0].button).is_equal("a")
	assert_bool(bh.show_hints([{"button": "a", "icon": &"dig"}, {"button": "b", "icon": &"jump"}])).is_false()
	var drawn := [false]
	ButtonHints.register_icon(&"test_icon", func(_ci: CanvasItem, _r: Rect2, _a: float) -> void: drawn[0] = true)
	ButtonHints.draw_icon(bh, &"test_icon", Rect2(0, 0, 10, 10))
	assert_bool(drawn[0]).is_true()
	bh.show_hints([])
	assert_array(bh.hints()).is_empty()
	bh.free()
