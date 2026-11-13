## Standing feel rules (2026-11-13 audit), rule 1: the D-pad moves the character in play. test_dpad
## proves the actions carry the D-pad; this suite presses a real (synthetic) pad's D-pad in a real
## HillGame and watches the body move, one case per pad slot, and the pause menu's cursor.
## Staging: each player stands on the ground before the press (bounded wait), and the walk is
## judged by direction and a small distance, never by a frame count.
class_name TestDpadMoves
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const PAD1 := 5
const PAD2 := 6
const PauseMenuScript := preload("res://scenes/ui/pause_menu.gd")

var _game: HillGame


func before() -> void:
	SuiteSandbox.enter("dpad_moves")   # own profile, settings and picks file
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
	get_tree().paused = false


func after_test() -> void:
	for dev in [PAD1, PAD2]:
		for b: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			_button(dev, b, false)
	if is_instance_valid(_game):
		_game.free()
	get_tree().paused = false
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _button(device: int, button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Joins a pad the way a child does (a button press), before the game is up.
func _join(device: int) -> void:
	_button(device, JOY_BUTTON_Y, true)
	_button(device, JOY_BUTTON_Y, false)
	await await_idle_frame()


func _make() -> HillGame:
	_game = HillGame.new()
	get_tree().root.add_child(_game)
	return _game


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Wakes `p` (input from its own pad: no intent_source) and lets it land.
func _stand(p: int) -> HillPlayer:
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	var n := 0
	while not (node.is_on_floor() and absf(node.velocity.x) < 1.0) and n < 300:
		await get_tree().physics_frame
		n += 1
	assert_bool(node.is_on_floor()).override_failure_message("%s never landed" % node.name).is_true()
	return node


## Holds a D-pad direction on `device` until `node` has walked `dist` px that way (or a cap).
func _walk(device: int, button: JoyButton, node: HillPlayer, dist: float) -> float:
	var x0 := node.global_position.x
	var sgn := 1.0 if button == JOY_BUTTON_DPAD_RIGHT else -1.0
	_button(device, button, true)
	var n := 0
	while (node.global_position.x - x0) * sgn < dist and n < 240:
		await get_tree().physics_frame
		n += 1
	_button(device, button, false)
	return node.global_position.x - x0


func test_pad_one_dpad_walks_player_one() -> void:
	await _join(PAD1)
	assert_int(Players.device_of(P1)).is_equal(PAD1)
	_make()
	var p1 := await _stand(P1)
	var right := await _walk(PAD1, JOY_BUTTON_DPAD_RIGHT, p1, 24.0)
	assert_float(right).override_failure_message("P1 D-pad right moved %.1f px" % right).is_greater_equal(24.0)
	await _physics(10)
	var left := await _walk(PAD1, JOY_BUTTON_DPAD_LEFT, p1, 24.0)
	assert_float(left).override_failure_message("P1 D-pad left moved %.1f px" % left).is_less_equal(-24.0)


func test_pad_two_dpad_walks_player_two_and_never_player_one() -> void:
	await _join(PAD1)
	await _join(PAD2)
	assert_int(Players.device_of(P2)).is_equal(PAD2)
	_make()
	var p1 := await _stand(P1)
	var p2 := await _stand(P2)
	var p1_x := p1.global_position.x
	var moved := await _walk(PAD2, JOY_BUTTON_DPAD_LEFT, p2, 24.0)
	assert_float(moved).override_failure_message("P2 D-pad left moved %.1f px" % moved).is_less_equal(-24.0)
	assert_float(absf(p1.global_position.x - p1_x)).is_less(2.0)   # P2's pad never walks P1
	await _physics(10)
	moved = await _walk(PAD2, JOY_BUTTON_DPAD_RIGHT, p2, 24.0)
	assert_float(moved).override_failure_message("P2 D-pad right moved %.1f px" % moved).is_greater_equal(24.0)


func test_dpad_drives_the_front_loader() -> void:
	await _join(PAD1)
	_make()
	var p1 := await _stand(P1)
	var loader: Node2D = _game.vehicles.get(&"front_loader")
	assert_object(loader).is_not_null()
	p1.global_position = loader.global_position   # staged beside the Loader: B gets in
	await _physics(2)
	_button(PAD1, JOY_BUTTON_B, true)
	await _physics(2)
	_button(PAD1, JOY_BUTTON_B, false)
	assert_object(p1.vehicle).override_failure_message("B by the Loader did not hop in").is_not_null()
	await _stand(P1)
	var moved := await _walk(PAD1, JOY_BUTTON_DPAD_RIGHT, p1, 24.0)
	if moved < 24.0:
		await _physics(5)
		moved = await _walk(PAD1, JOY_BUTTON_DPAD_LEFT, p1, 24.0)
		moved = -moved
	assert_float(moved).override_failure_message("the Loader on the D-pad moved %.1f px" % moved).is_greater_equal(24.0)


func test_dpad_moves_the_pause_cursor() -> void:
	await _join(PAD1)
	var pm: Control = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(pm)
	Game.pause()
	await await_idle_frame()
	assert_int(pm.focus).is_equal(PauseMenuScript.Choice.RESUME)
	_button(PAD1, JOY_BUTTON_DPAD_DOWN, true)
	await await_idle_frame()
	await await_idle_frame()
	_button(PAD1, JOY_BUTTON_DPAD_DOWN, false)
	assert_int(pm.focus).is_equal(PauseMenuScript.Choice.RESTART)
	Game.resume()
	pm.free()
