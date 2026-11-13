## Gap-close-8: the D-pad walks, aims, climbs and drives exactly like the left stick, in play and in
## every menu (standing rule: no stick-only requirement). Before this, the move actions held only
## the stick and the keys, so a child on the D-pad stood still (only the lobby chooser read it).
## Players adds the four D-pad buttons to every player's move actions at boot (project.godot is
## not this lane's), and the per-pad rebinding keeps P1's D-pad on P1.
class_name TestDpad
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const DIRS := {
	"move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT,
	"move_up": JOY_BUTTON_DPAD_UP,
	"move_down": JOY_BUTTON_DPAD_DOWN,
}


func before() -> void:
	SuiteSandbox.enter("dpad")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Players.reset()


func after_test() -> void:
	for dev in [5, 6]:
		for b: JoyButton in DIRS.values():
			_button(dev, b, false)
	Players.reset()


func _button(device: int, button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _has_dpad(action_name: String, button: JoyButton) -> bool:
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return true
	return false


func _join(device: int) -> void:
	_button(device, JOY_BUTTON_A, true)
	_button(device, JOY_BUTTON_A, false)
	await await_idle_frame()


func test_every_players_move_actions_have_the_dpad() -> void:
	for p in [P1, P2]:
		for a: String in DIRS:
			assert_bool(_has_dpad(Players.action(p, a), DIRS[a])) \
					.override_failure_message("%s has no D-pad" % Players.action(p, a)).is_true()
	# Only once each, however often it is asked for.
	Players.add_dpad()
	var n := 0
	for ev in InputMap.action_get_events(Players.action(P1, "move_left")):
		if ev is InputEventJoypadButton:
			n += 1
	assert_int(n).is_equal(1)


func test_the_dpad_walks_its_own_player_like_the_stick() -> void:
	await _join(5)
	await _join(6)
	assert_int(Players.device_of(P1)).is_equal(5)
	assert_int(Players.device_of(P2)).is_equal(6)
	_button(5, JOY_BUTTON_DPAD_LEFT, true)
	assert_vector(Players.move_vector(P1)).is_equal(Vector2.LEFT)
	assert_vector(Players.move_vector(P2)).is_equal(Vector2.ZERO)   # P1's pad never moves P2
	_button(5, JOY_BUTTON_DPAD_LEFT, false)
	_button(6, JOY_BUTTON_DPAD_DOWN, true)   # down: climb down a ladder, aim the bucket
	assert_vector(Players.move_vector(P2)).is_equal(Vector2.DOWN)
	assert_vector(Players.move_vector(P1)).is_equal(Vector2.ZERO)
	_button(6, JOY_BUTTON_DPAD_DOWN, false)
	assert_vector(Players.move_vector(P2)).is_equal(Vector2.ZERO)


func test_the_dpad_moves_menu_focus() -> void:
	await _join(5)
	_button(5, JOY_BUTTON_DPAD_DOWN, true)
	assert_int(MenuInput.read().move.y).is_equal(1)
	_button(5, JOY_BUTTON_DPAD_DOWN, false)
	await await_idle_frame()
	_button(5, JOY_BUTTON_DPAD_RIGHT, true)
	assert_int(MenuInput.read().move.x).is_equal(1)


func test_solo_hands_the_dpad_to_the_focused_player() -> void:
	await _join(5)
	Players.set_solo(true, 5)
	_button(5, JOY_BUTTON_DPAD_RIGHT, true)
	assert_vector(Players.move_vector(P1)).is_equal(Vector2.RIGHT)
	assert_vector(Players.move_vector(P2)).is_equal(Vector2.ZERO)
	_button(5, JOY_BUTTON_DPAD_RIGHT, false)
	Players.set_solo_focus(P2)
	_button(5, JOY_BUTTON_DPAD_RIGHT, true)
	assert_vector(Players.move_vector(P2)).is_equal(Vector2.RIGHT)
	assert_vector(Players.move_vector(P1)).is_equal(Vector2.ZERO)
	_button(5, JOY_BUTTON_DPAD_RIGHT, false)
	Players.set_solo(false)
