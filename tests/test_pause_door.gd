## The pause menu's big door icon back to Open Jar (template pause-door, FR-3): it is in the
## scene (128 px, 140 px focused, "Back to Open Jar" beneath it), the cursor stops on it, A asks
## first (then Game.quit, which saves), B resumes, and the d-pad (read through MenuInput) reaches it.
## Real (synthetic) pad events on pads 5 and 6; own profile, settings and picks file (SuiteSandbox).
class_name TestPauseDoor
extends GdUnitTestSuite

const PAD1 := 5
const PAD2 := 6
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

var _pm: PauseMenu
var _quits := 0


func before() -> void:
	SuiteSandbox.enter("pause_door")   # first: never the real profile, settings or picks file
	Game.quit_exits = false
	Game.quit_requested.connect(_on_quit)


func after() -> void:
	Game.quit_requested.disconnect(_on_quit)
	Game.quit_exits = true
	SuiteSandbox.leave()   # last: the real files come back


func before_test() -> void:
	Save.wipe()
	Save.wipe_settings()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.PLAYING)
	get_tree().paused = false
	_quits = 0


func after_test() -> void:
	for dev in [PAD1, PAD2]:
		for b: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			_button(dev, b, false)
	if is_instance_valid(_pm):
		_pm.free()
	get_tree().paused = false
	Players.reset()
	Game._set_state(Game.State.LOBBY)


func _on_quit() -> void:
	_quits += 1


func _button(device: int, button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## A whole press: down, a couple of frames for the menu's _process to read it, up.
func _tap(device: int, button: JoyButton) -> void:
	_button(device, button, true)
	await await_idle_frame()
	await await_idle_frame()
	_button(device, button, false)
	await await_idle_frame()


## Both pads join (a button press, as a child does), the pause menu is up, the game paused.
func _paused() -> PauseMenu:
	_button(PAD1, JOY_BUTTON_Y, true)
	_button(PAD1, JOY_BUTTON_Y, false)
	_button(PAD2, JOY_BUTTON_Y, true)
	_button(PAD2, JOY_BUTTON_Y, false)
	await await_idle_frame()
	_pm = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_pm)
	Game.pause()
	await await_idle_frame()
	assert_bool(_pm.visible).is_true()
	return _pm


func _door(pm: Node) -> IconButton:
	return pm.get_node("Card/Door/Icon")


func test_door_icon_is_in_the_pause_scene() -> void:
	var pm: Node = auto_free((load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate())
	var door: Node = pm.get_node_or_null("Card/Door/Icon")
	assert_object(door).is_instanceof(IconButton)
	var icon := door as IconButton
	assert_int(icon.icon).is_equal(IconButton.Icon.DOOR)
	assert_vector(icon.size).is_equal(Vector2(128, 128))
	assert_float(icon.size.x * icon.focus_scale).is_equal_approx(140.0, 0.01)
	var label: Label = pm.get_node("Card/Door/Label")
	assert_str(label.text).is_equal("Back to Open Jar")
	# Beneath the icon, centred under it, and inside the 1080 px screen.
	assert_float(label.position.y).is_greater(icon.position.y + 128.0)
	assert_float(label.position.x + label.size.x * 0.5).is_equal_approx(icon.position.x + 64.0, 1.0)
	var door_box: Control = pm.get_node("Card/Door")
	assert_float(door_box.position.y + label.position.y + label.size.y).is_less_equal(1080.0)
	# The text bar is gone: no MenuItem called Door left in the bar list.
	assert_object(pm.get_node_or_null("Card/Buttons/Door")).is_null()


func test_door_icon_takes_the_focus_and_is_the_last_stop() -> void:
	var pm := await _paused()
	var door := _door(pm)
	assert_bool(door.focused).is_false()
	for i in 4:
		pm.move_focus(1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_bool(door.focused).is_true()
	pm.move_focus(1)   # bumps the end: stays on the door
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	pm.move_focus(-1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.STORY)
	assert_bool(door.focused).is_false()


func test_dpad_reaches_the_door() -> void:
	var pm := await _paused()
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	await _tap(PAD1, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESTART)
	await _tap(PAD2, JOY_BUTTON_DPAD_DOWN)   # either pad
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)
	await _tap(PAD1, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.STORY)
	await _tap(PAD1, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_bool(_door(pm).focused).is_true()
	await _tap(PAD2, JOY_BUTTON_DPAD_UP)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.STORY)


func test_a_on_the_door_asks_first_then_quits_saved() -> void:
	var pm := await _paused()
	Save.set_value("pause_door_quit", 1)
	for i in 4:
		pm.move_focus(1)
	await _tap(PAD1, JOY_BUTTON_A)
	var confirm: ConfirmDialog = pm.get_node("Confirm")
	assert_bool(confirm.active).is_true()   # asks first
	assert_int(_quits).is_equal(0)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	await _tap(PAD1, JOY_BUTTON_B)   # B in the question: stay
	assert_bool(confirm.active).is_false()
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	assert_int(_quits).is_equal(0)
	await _tap(PAD2, JOY_BUTTON_A)   # ask again, then leave
	assert_bool(confirm.active).is_true()
	confirm.choose(true)
	assert_int(_quits).is_equal(1)
	assert_bool(Save._dirty).is_false()   # Game.quit saved first
	Save.wipe()


func test_b_resumes() -> void:
	var pm := await _paused()
	for i in 4:
		pm.move_focus(1)
	await _tap(PAD2, JOY_BUTTON_B)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(get_tree().paused).is_false()
	assert_bool(pm.visible).is_false()
	assert_int(_quits).is_equal(0)


func test_door_wears_the_hill_accent() -> void:
	var pm := await _paused()
	assert_that(_door(pm).tint).is_equal(UiStyle.accent)
