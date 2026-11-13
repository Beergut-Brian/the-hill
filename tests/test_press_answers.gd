## Every press answers (FR-5, docs/press-answers.md): on each menu screen a press that does nothing
## plays the soft refusal (honk) and wobbles the focused item, and nothing else changes. Presses that
## already do something keep doing it (Start in pause resumes, a join press joins, Select in solo
## switches). Template screens (lobby, pause, settings, the leave question) plus The Hill's own
## HoldConfirm questions (New Hill in the lobby, Restore last hill in settings). Boots main.tscn with
## real pad events (devices 5 and 6), in its own sandbox (its own profile, settings file and saves
## folder, never the real ones).
class_name TestPressAnswers
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const DIR := "user://test_press_answers_saves"

var _main: Node
var _real_dir := ""


func before() -> void:
	SuiteSandbox.enter("press_answers")   # first: never the real profile, settings or picks file
	_real_dir = Save.saves_dir
	Save.saves_dir = DIR
	Game.quit_exits = false


func after() -> void:
	_clear_dir()
	Save.saves_dir = _real_dir
	Save._load()
	Game.quit_exits = true
	SuiteSandbox.leave()   # last: the real files come back


func _clear_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])


func before_test() -> void:
	_clear_dir()
	Save._load()   # nothing there: a first run
	Save.wipe_settings()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _pad(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func _trigger(device: int, axis: JoyAxis) -> void:
	for v in [1.0, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis
		ev.axis_value = v
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func _honks() -> int:
	return UiSound.plays.get(MenuInput.REFUSE_CUE, 0)


## Two real pads join (B: joined, not ready) on the lobby.
func _lobby_with_pads() -> Lobby:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _pad(5, JOY_BUTTON_B)
	await _pad(6, JOY_BUTTON_B)
	await await_idle_frame()
	return _main.get_node("UI/Lobby")


func _paused() -> PauseMenu:
	var lobby := await _lobby_with_pads()
	lobby.press_a(P1)
	lobby.press_a(P2)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	Game.pause()
	await await_idle_frame()
	await await_idle_frame()
	return _main.get_node("UI/PauseMenu")


# ---- lobby -------------------------------------------------------------------------------------

func test_lobby_unused_buttons_refuse_and_change_nothing() -> void:
	var lobby := await _lobby_with_pads()
	var play: MenuItem = lobby.get_node("Buttons/Play")
	var r0 := MenuInput.refusals
	var h0 := _honks()
	var picks := [Roster.pick(P1), Roster.pick(P2)]
	await _pad(5, JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("x")
	assert_int(_honks()).is_equal(h0 + 1)
	assert_bool(play.is_wobbling()).is_true()
	for b in [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
			JOY_BUTTON_LEFT_STICK, JOY_BUTTON_START, JOY_BUTTON_BACK]:
		await _pad(6, b)
	await _trigger(5, JOY_AXIS_TRIGGER_RIGHT)
	assert_int(MenuInput.refusals).is_equal(r0 + 8)
	assert_str(MenuInput.last_refused).is_equal("rt")
	# Nothing else changed.
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)
	assert_bool(lobby.readied[P1] or lobby.readied[P2]).is_false()
	assert_bool(lobby.in_submenu()).is_false()
	assert_array([Roster.pick(P1), Roster.pick(P2)]).is_equal(picks)


func test_lobby_b_with_nothing_to_back_out_of_refuses() -> void:
	var lobby := await _lobby_with_pads()
	var r0 := MenuInput.refusals   # the two B joins were joins, not refusals
	await _pad(5, JOY_BUTTON_B)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_bool(lobby.readied[P1]).is_false()
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)


func test_lobby_join_press_is_not_a_refusal() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_B)
	await _pad(6, JOY_BUTTON_X)   # X joins P2 too
	assert_bool(Players.is_active(P1) and Players.is_active(P2)).is_true()
	assert_int(MenuInput.refusals).is_equal(r0)


func test_lobby_left_right_on_a_locked_podium_refuses() -> void:
	var lobby := await _lobby_with_pads()
	lobby.set_ready(P1, true)
	var pick := Roster.pick(P1)
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_DPAD_RIGHT)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("right")
	assert_str(Roster.pick(P1)).is_equal(pick)
	assert_bool(lobby.readied[P1]).is_true()


func test_lobby_select_in_solo_still_switches() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	Players.set_solo(true, 5)
	await await_idle_frame()
	await await_idle_frame()
	var r0 := MenuInput.refusals
	assert_int(Players.solo_focus).is_equal(P1)
	await _pad(5, JOY_BUTTON_BACK)
	assert_int(Players.solo_focus).is_equal(P2)
	assert_int(MenuInput.refusals).is_equal(r0)


# ---- pause -------------------------------------------------------------------------------------

func test_pause_unused_buttons_refuse_and_change_nothing() -> void:
	var pm := await _paused()
	var resume: MenuItem = pm.get_node("Card/Buttons/Resume")
	var r0 := MenuInput.refusals
	var h0 := _honks()
	await _pad(5, JOY_BUTTON_Y)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(_honks()).is_equal(h0 + 1)
	assert_bool(resume.is_wobbling()).is_true()
	await _pad(6, JOY_BUTTON_LEFT_SHOULDER)
	await _pad(6, JOY_BUTTON_BACK)   # Select: restart is PLAYING only
	await _trigger(5, JOY_AXIS_TRIGGER_LEFT)
	assert_int(MenuInput.refusals).is_equal(r0 + 4)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	assert_bool(pm.in_submenu()).is_false()


func test_pause_left_right_cycle_then_refuse_at_the_end() -> void:
	var pm := await _paused()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_DPAD_LEFT)   # nothing above Resume
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	assert_bool(pm.get_node("Card/Buttons/Resume").is_wobbling()).is_true()
	# Right = down the list: Restart, Settings, (Story when the hill has one), the door.
	var seen := []
	for i in 5:
		if pm.focus == PauseMenu.Choice.DOOR:
			break
		var want := MenuItem.step(pm._buttons, pm.focus, 1)
		await _pad(5, JOY_BUTTON_DPAD_RIGHT)
		assert_int(pm.focus).is_equal(want)
		seen.append(pm.focus)
	assert_array(seen).contains([PauseMenu.Choice.RESTART, PauseMenu.Choice.SETTINGS, PauseMenu.Choice.DOOR])
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	await _pad(6, JOY_BUTTON_DPAD_RIGHT)   # past the door: refuse, the door wobbles
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_int(MenuInput.refusals).is_equal(r0 + 2)
	var door: IconButton = pm.get_node("Card/Door/Icon")
	assert_bool(door.is_wobbling()).is_true()
	assert_int(door.wobbles).is_equal(1)
	var up := MenuItem.step(pm._buttons, pm.focus, -1)
	await _pad(5, JOY_BUTTON_DPAD_LEFT)
	assert_int(pm.focus).is_equal(up)
	assert_int(Game.state).is_equal(Game.State.PAUSED)


func test_pause_start_still_resumes() -> void:
	var pm := await _paused()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_START)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_int(MenuInput.refusals).is_equal(r0)
	assert_bool(pm.visible).is_false()


# ---- settings ----------------------------------------------------------------------------------

func test_settings_unused_button_refuses_and_changes_nothing() -> void:
	var pm := await _paused()
	pm.move_focus(1)
	pm.move_focus(1)
	pm.press()   # Settings
	var settings: SettingsPanel = pm.get_node("Settings")
	assert_bool(settings.active).is_true()
	await await_idle_frame()
	var before := [SettingsPanel.value_of(SettingsPanel.MUSIC), SettingsPanel.value_of(SettingsPanel.SOUND),
			SettingsPanel.value_of(SettingsPanel.SHAKE), Players.solo]
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_bool(pm.get_node("Settings/Card/Rows/Music").is_wobbling()).is_true()
	assert_bool(settings.active).is_true()
	assert_int(settings.focus).is_equal(SettingsPanel.Row.MUSIC)
	assert_array([SettingsPanel.value_of(SettingsPanel.MUSIC), SettingsPanel.value_of(SettingsPanel.SOUND),
			SettingsPanel.value_of(SettingsPanel.SHAKE), Players.solo]).is_equal(before)
	assert_str(Save.settings_path).is_equal(SuiteSandbox.settings_for("press_answers"))   # never the real file


# ---- leave the game? ---------------------------------------------------------------------------

func test_confirm_unused_button_refuses_and_stays_open() -> void:
	var lobby := await _lobby_with_pads()
	lobby.focus_item(Lobby.Choice.DOOR)
	lobby.press_a(P1)
	var confirm: ConfirmDialog = lobby.get_node("Confirm")
	assert_bool(confirm.active).is_true()
	await await_idle_frame()
	var r0 := MenuInput.refusals
	await _pad(6, JOY_BUTTON_RIGHT_SHOULDER)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_bool(confirm.get_node("Card/Buttons/Cancel").is_wobbling()).is_true()
	assert_bool(confirm.active).is_true()
	assert_int(confirm.focus).is_equal(ConfirmDialog.Choice.CANCEL)
	await _pad(6, JOY_BUTTON_START)   # Start in the lobby's question: nothing, so refuse
	assert_int(MenuInput.refusals).is_equal(r0 + 2)
	assert_bool(confirm.active).is_true()
	assert_int(Game.state).is_equal(Game.State.LOBBY)


# ---- The Hill's own: New Hill and Restore last hill (HoldConfirm) -------------------------------

## A save on disk, so the lobby shows Continue and New Hill.
func _seed(marker: String) -> void:
	Save.set_value("marker", marker)
	Save.set_value("buildings", [{"id": "house", "cell": [3, 0]}])
	Save.set_value("players", [{"deepest": 1, "scene": "hillville"}, {"deepest": 0, "scene": "hillville"}])
	Save.flush()


func _assert_question_refuses(q: HoldConfirm, lobby: Lobby, marker: String) -> void:
	await await_idle_frame()
	var r0 := MenuInput.refusals
	var h0 := _honks()
	var focus := q.focus
	await _pad(5, JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(_honks()).is_equal(h0 + 1)
	assert_bool((q._buttons[focus] as MenuItem).is_wobbling()).is_true()
	await _pad(6, JOY_BUTTON_LEFT_SHOULDER)
	await _trigger(6, JOY_AXIS_TRIGGER_RIGHT)
	await _pad(5, JOY_BUTTON_START)
	assert_int(MenuInput.refusals).is_equal(r0 + 4)
	# Nothing else changed: still asking, same bar, no hold started, the save untouched.
	assert_bool(q.active).is_true()
	assert_int(q.focus).is_equal(focus)
	assert_float(q.progress).is_equal(0.0)
	assert_str(Save.get_value("marker")).is_equal(marker)
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_int(lobby.focus).is_not_equal(-1)


func test_new_hill_question_refuses_unused_buttons() -> void:
	_seed("old")
	var lobby := await _lobby_with_pads()
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	var q := lobby.new_hill
	assert_bool(q.active).is_true()
	q.move_focus(1)   # on "Start new": a refusal must not start the hold either
	await _assert_question_refuses(q, lobby, "old")
	assert_int(Save.backups().size()).is_equal(0)


func test_restore_question_refuses_unused_buttons() -> void:
	_seed("old")
	Save.start_new()   # "old" is now the backup
	_seed("now")
	var lobby := await _lobby_with_pads()
	var settings: SettingsPanel = lobby.get_node("Settings")
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	settings.open_restore()
	assert_bool(settings.asking()).is_true()
	var backups := Save.backups().size()
	await _assert_question_refuses(settings.restore, lobby, "now")
	assert_bool(settings.active).is_true()
	assert_int(Save.backups().size()).is_equal(backups)
