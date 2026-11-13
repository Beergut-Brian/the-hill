## Standing feel rules (2026-11-13 audit). Rule 5 (every press answers; a press that does nothing
## says so) and rule 4 (one pad plays both players: Select in solo moves the pad to the other
## player in play, as it does in the lobby). Before this audit: X underground was silent, Select in
## play played Game.restart's confirm + round-start sounds and changed nothing, the shoulders,
## triggers and stick clicks were silent, and in play solo had no way to reach P2.
class_name TestFeelRules
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const PAD := 5
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _refused: Array = []


func before() -> void:
	SuiteSandbox.enter("feel_rules")   # own profile, settings and picks file
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
	_refused.clear()


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.set_solo(false)
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


func _tap(device: int, button: JoyButton) -> void:
	_button(device, button, true)
	_button(device, button, false)


func _make() -> HillGame:
	_game = HillGame.new()
	get_tree().root.add_child(_game)
	return _game


func _watch(node: HillPlayer) -> void:
	node.refused.connect(func(b: String) -> void: _refused.append([node.player, b]))


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(node: HillPlayer, key: String) -> void:
	var it := IDLE.duplicate()
	node.intent_source = func() -> Dictionary: return it
	await _physics(2)
	it[key] = true
	await _physics(2)
	it[key] = false
	await _physics(2)


func test_x_underground_refuses_and_up_top_opens_the_book() -> void:
	_make()
	Players.join_virtual(P1)
	var p1 := _game.wake(P1)
	_game.place_player(P1, HillGame.UNDERGROUND, _game.underground.landing(0) + Vector2(96, 0))
	assert_object(p1.world).is_not_null()
	_watch(p1)
	await _press(p1, "book")
	assert_array(_refused).contains_exactly([[P1, "x"]])
	# Up top X opens the build book (that press does something: no refusal).
	_refused.clear()
	_game.free()
	Progress.reset()
	_make()
	var up := _game.wake(P1)
	_watch(up)
	await _press(up, "book")
	assert_array(_refused).is_empty()
	assert_bool(_game.build.captures(P1)).is_true()


func test_select_in_play_refuses_and_never_restarts() -> void:
	_tap(PAD, JOY_BUTTON_Y)   # join P1 on a pad
	_make()
	var p1 := _game.wake(P1)
	_watch(p1)
	var rounds := Game.round_index
	_tap(PAD, JOY_BUTTON_BACK)
	assert_array(_refused).contains_exactly([[P1, "select"]])
	assert_int(Game.round_index).is_equal(rounds)   # Game.restart (round-start fanfare) never ran
	assert_int(Game.state).is_equal(Game.State.PLAYING)


func test_unused_buttons_and_triggers_refuse() -> void:
	_tap(PAD, JOY_BUTTON_Y)
	_make()
	var p1 := _game.wake(P1)
	_watch(p1)
	_tap(PAD, JOY_BUTTON_LEFT_SHOULDER)
	_tap(PAD, JOY_BUTTON_RIGHT_STICK)
	var t := InputEventJoypadMotion.new()
	t.device = PAD
	t.axis = JOY_AXIS_TRIGGER_RIGHT
	t.axis_value = 1.0
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	Input.parse_input_event(t)   # still held: one refusal per pull, not per event
	Input.flush_buffered_events()
	t.axis_value = 0.0
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	assert_int(_refused.size()).is_equal(3)


func test_select_in_solo_play_moves_the_pad_to_the_other_player() -> void:
	_tap(PAD, JOY_BUTTON_Y)
	Players.set_solo(true, PAD)
	_make()
	_game.wake(P1)
	assert_int(Players.solo_focus).is_equal(P1)
	_tap(PAD, JOY_BUTTON_BACK)
	assert_int(Players.solo_focus).is_equal(P2)
	await _physics(3)
	assert_bool(_game.players.has(P2)).override_failure_message("P2 did not wake on the switch").is_true()
	# The pad's D-pad now walks P2, not P1.
	_button(PAD, JOY_BUTTON_DPAD_RIGHT, true)
	assert_vector(Players.move_vector(P2)).is_equal(Vector2.RIGHT)
	assert_vector(Players.move_vector(P1)).is_equal(Vector2.ZERO)
	_button(PAD, JOY_BUTTON_DPAD_RIGHT, false)
	_tap(PAD, JOY_BUTTON_BACK)
	assert_int(Players.solo_focus).is_equal(P1)
	assert_array(_refused).is_empty()


func test_select_with_start_held_is_the_solo_hold_not_a_switch() -> void:
	_tap(PAD, JOY_BUTTON_Y)
	Players.set_solo(true, PAD)
	_make()
	_game.wake(P1)
	_button(PAD, JOY_BUTTON_START, true)
	_tap(PAD, JOY_BUTTON_BACK)
	_button(PAD, JOY_BUTTON_START, false)
	assert_int(Players.solo_focus).is_equal(P1)
	Game._set_state(Game.State.PLAYING)
	get_tree().paused = false
