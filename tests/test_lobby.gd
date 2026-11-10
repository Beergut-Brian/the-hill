## Lobby (ready-up, hold to start alone, solo), pause menu (restart -> lobby, door -> confirm ->
## Game.quit), settings (persist, solo), focus by both pads, B backs out, mid-game joins, --demo.
## Boots main.tscn with virtual players and synthetic pad events.
class_name TestLobby
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

var _main: Node
var _quits := 0
var _readies: Array = []


var _real_settings := ""
var _real_profile := ""


func before() -> void:
	_real_settings = Save.settings_path
	_real_profile = Save.profile
	Save.settings_path = "user://test_settings_lobby.json"
	Game.quit_exits = false
	Game.quit_requested.connect(_on_quit)
	Game.lobby_ready.connect(_on_lobby_ready)


func after() -> void:
	Game.quit_requested.disconnect(_on_quit)
	Game.lobby_ready.disconnect(_on_lobby_ready)
	Game.quit_exits = true
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.flush()
	Save.profile = _real_profile
	Save._load()
	Save.reload_settings()


func before_test() -> void:
	# Boots save the game: never into the real profile.
	Save.profile = "test_lobby"
	Save.wipe()
	Save.wipe_settings()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	_quits = 0
	_readies.clear()


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _on_quit() -> void:
	_quits += 1


func _on_lobby_ready(players: Array) -> void:
	_readies.append(players)


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


func _pause_menu() -> PauseMenu:
	return _main.get_node("UI/PauseMenu")


func _settings_of(menu: Node) -> SettingsPanel:
	return menu.get_node("Settings")


func _confirm_of(menu: Node) -> ConfirmDialog:
	return menu.get_node("Confirm")


func _finish_countdown() -> void:
	_lobby().count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)


# --- lobby ---------------------------------------------------------------------

func test_boots_into_lobby() -> void:
	_boot()
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_bool(_lobby().visible).is_true()
	assert_bool(_pause_menu().visible).is_false()
	assert_int(Game.State.TITLE).is_equal(Game.State.LOBBY)


func test_join_readies_and_b_unreadies() -> void:
	_boot()
	var lobby := _lobby()
	Players.join_virtual(P1)
	assert_bool(lobby.readied[P1]).is_true()
	assert_bool(lobby.get_node("Spots/P1").readied).is_true()
	assert_bool(lobby.counting).is_false()   # one player alone has to hold A
	lobby.press_b(P1)
	assert_bool(lobby.readied[P1]).is_false()
	assert_bool(lobby.get_node("Spots/P1").joined).is_true()
	lobby.press_a(P1)
	assert_bool(lobby.readied[P1]).is_true()


func _pad(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func test_real_pad_a_joins_ready_b_unreadies() -> void:
	_boot()
	var lobby := _lobby()
	await _pad(5, JOY_BUTTON_A)
	assert_int(Players.device_of(P1)).is_equal(5)
	assert_bool(lobby.readied[P1]).is_true()
	await _pad(5, JOY_BUTTON_B)
	assert_bool(lobby.readied[P1]).is_false()
	await _pad(6, JOY_BUTTON_B)   # joining with B: in, but not ready
	assert_int(Players.device_of(P2)).is_equal(6)
	assert_bool(lobby.readied[P2]).is_false()
	assert_bool(lobby.get_node("Spots/P2").joined).is_true()


func test_both_ready_counts_down_then_starts() -> void:
	_boot()
	var lobby := _lobby()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	assert_bool(lobby.counting).is_true()
	lobby.count_step(Lobby.COUNT_STEP * 1.5)
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	lobby.count_step(Lobby.COUNT_STEP * 2.0)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_array(_readies).is_equal([[P1, P2]])
	assert_int(_main.game.players.size()).is_equal(2)
	assert_bool(lobby.visible).is_false()


func test_unready_cancels_countdown() -> void:
	_boot()
	var lobby := _lobby()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	lobby.press_b(P2)
	assert_bool(lobby.counting).is_false()
	_finish_countdown()
	assert_int(Game.state).is_equal(Game.State.LOBBY)


func test_hold_a_starts_alone() -> void:
	_boot()
	var lobby := _lobby()
	Players.join_virtual(P1)
	assert_bool(lobby.hold_step(P1, true, 1.0)).is_false()
	assert_bool(lobby.hold_step(P1, false, 0.1)).is_false()   # let go: starts over
	assert_bool(lobby.hold_step(P1, true, 1.0)).is_false()
	assert_float(lobby.get_node("Spots/P1").hold).is_greater(0.5)
	assert_bool(lobby.hold_step(P1, true, 0.6)).is_true()
	assert_bool(lobby.counting).is_true()
	_finish_countdown()
	assert_array(_readies).is_equal([[P1]])
	assert_int(Game.state).is_equal(Game.State.PLAYING)


func test_hold_does_nothing_until_ready() -> void:
	_boot()
	var lobby := _lobby()
	Players.join_virtual(P1)
	lobby.press_b(P1)
	assert_bool(lobby.hold_step(P1, true, 5.0)).is_false()
	assert_bool(lobby.counting).is_false()


func test_solo_readies_both() -> void:
	_boot()
	Players.set_solo(true)
	var lobby := _lobby()
	assert_bool(lobby.readied[P1]).is_true()
	assert_bool(lobby.readied[P2]).is_true()
	assert_bool(lobby.counting).is_true()


func test_lobby_door_asks_then_quits() -> void:
	_boot()
	var lobby := _lobby()
	var confirm := _confirm_of(lobby)
	Players.join_virtual(P1)
	lobby.focus_item(Lobby.Choice.DOOR)
	lobby.press_a(P1)
	assert_bool(confirm.active).is_true()
	assert_int(confirm.focus).is_equal(ConfirmDialog.Choice.CANCEL)   # Stay first
	assert_int(_quits).is_equal(0)
	confirm.handle({ "move": Vector2i.ZERO, "a": P1, "b": -1 })   # A on Stay
	assert_bool(confirm.active).is_false()
	assert_int(_quits).is_equal(0)
	lobby.press_a(P1)
	confirm.move_focus(1)
	confirm.handle({ "move": Vector2i.ZERO, "a": P1, "b": -1 })   # A on Leave
	assert_int(_quits).is_equal(1)


func test_lobby_menu_has_text_labels() -> void:
	_boot()
	var labels := []
	for item in _lobby().get_node("Buttons").get_children():
		labels.append(item.text)
	assert_array(labels).is_equal(["Play", "Settings", "Back to Open Jar"])
	assert_str(_lobby().get_node("TitleArt/TitleLabel").text).is_not_empty()
	assert_array(UiStyle.PLAYER_COLORS).is_equal([Players.COLOR[P1], Players.COLOR[P2]])


func _stick(device: int, y: float) -> void:
	for v in [y, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = JOY_AXIS_LEFT_Y
		ev.axis_value = v
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func test_focus_moves_with_either_pad() -> void:
	_boot()
	var lobby := _lobby()
	await _pad(5, JOY_BUTTON_B)   # join without readying: no countdown
	await _pad(6, JOY_BUTTON_B)
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)
	await _stick(6, 1.0)
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)
	await _stick(5, 1.0)
	assert_int(lobby.focus).is_equal(Lobby.Choice.DOOR)
	await _stick(5, 1.0)   # bumps the end
	assert_int(lobby.focus).is_equal(Lobby.Choice.DOOR)
	await _stick(6, -1.0)
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)
	await _pad(6, JOY_BUTTON_A)   # P2 opens Settings
	assert_bool(_settings_of(lobby).active).is_true()
	await _stick(5, 1.0)   # P1 moves inside it
	assert_int(_settings_of(lobby).focus).is_equal(SettingsPanel.Row.SOUND)


func test_b_goes_back() -> void:
	_boot()
	var lobby := _lobby()
	var settings := _settings_of(lobby)
	var confirm := _confirm_of(lobby)
	await _pad(5, JOY_BUTTON_B)
	lobby.focus_item(Lobby.Choice.SETTINGS)
	await _pad(5, JOY_BUTTON_A)
	assert_bool(settings.active).is_true()
	await _pad(5, JOY_BUTTON_B)
	assert_bool(settings.active).is_false()
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)
	lobby.focus_item(Lobby.Choice.DOOR)
	await _pad(5, JOY_BUTTON_A)
	assert_bool(confirm.active).is_true()
	await _pad(5, JOY_BUTTON_B)
	assert_bool(confirm.active).is_false()
	assert_int(_quits).is_equal(0)
	await _pad(5, JOY_BUTTON_B)   # nothing open, not ready: back to Play
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)


# --- settings ------------------------------------------------------------------

func test_settings_persist() -> void:
	_boot()
	var lobby := _lobby()
	var settings := _settings_of(lobby)
	Players.join_virtual(P1)
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	settings.adjust(-1)                       # music 0.8 -> 0.7
	settings.move_focus(1)
	settings.adjust(-1)                       # sound 1.0 -> 0.9
	settings.move_focus(1)
	settings.adjust(-1)                       # screen shake off
	assert_float(Audio.get_volume("Music")).is_equal_approx(0.7, 0.01)
	assert_bool(FileAccess.file_exists(Save.settings_path)).is_true()
	Save.reload_settings()                    # as on the next boot
	assert_float(Save.get_setting(SettingsPanel.MUSIC)).is_equal_approx(0.7, 0.001)
	assert_float(Save.get_setting(SettingsPanel.SOUND)).is_equal_approx(0.9, 0.001)
	assert_bool(SettingsPanel.screen_shake()).is_false()
	settings.adjust(1)
	assert_bool(SettingsPanel.screen_shake()).is_true()


func test_settings_solo_toggle_saves_and_readies_on_close() -> void:
	_boot()
	var lobby := _lobby()
	var settings := _settings_of(lobby)
	Players.join_virtual(P1)
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	for i in 3:
		settings.move_focus(1)
	assert_int(settings.focus).is_equal(SettingsPanel.Row.SOLO)
	settings.adjust(1, true)
	assert_bool(Players.solo).is_true()
	assert_bool(Save.get_setting(SettingsPanel.SOLO)).is_true()
	assert_bool(lobby.counting).is_false()    # not behind the open panel
	settings.close()
	assert_bool(lobby.counting).is_true()


func test_saved_solo_stays_off_at_boot() -> void:
	Save.set_setting(SettingsPanel.SOLO, true)
	_boot()
	await await_idle_frame()
	assert_bool(Players.solo).is_false()


# --- pause menu ----------------------------------------------------------------

func _play_two() -> void:
	_boot()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	_finish_countdown()


func test_pause_shows_menu_and_resume() -> void:
	_play_two()
	Game.pause()
	assert_bool(_pause_menu().visible).is_true()
	assert_bool(get_tree().paused).is_true()
	_pause_menu().press(PauseMenu.Choice.RESUME)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pause_menu().visible).is_false()


func test_pause_door_asks_then_quits() -> void:
	_play_two()
	Save.set_value("menus_quit", 1)
	Game.pause()
	var pm := _pause_menu()
	for i in 4:
		pm.move_focus(1)   # the last one bumps the end, stays on the door
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	pm.press()
	var confirm := _confirm_of(pm)
	assert_bool(confirm.active).is_true()
	assert_int(_quits).is_equal(0)
	pm.back()   # B: Stay
	assert_bool(confirm.active).is_false()
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	pm.press()
	confirm.choose(true)
	assert_int(_quits).is_equal(1)
	assert_bool(Save._dirty).is_false()   # quit saved first
	Save.wipe()


func test_pause_b_backs_out_then_resumes() -> void:
	_play_two()
	Game.pause()
	var pm := _pause_menu()
	pm.press(PauseMenu.Choice.SETTINGS)
	assert_bool(_settings_of(pm).active).is_true()
	pm.back()
	assert_bool(_settings_of(pm).active).is_false()
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	pm.back()
	assert_int(Game.state).is_equal(Game.State.PLAYING)


func test_pause_shows_who_paused() -> void:
	_boot()
	await _pad(5, JOY_BUTTON_B)
	await _pad(6, JOY_BUTTON_B)
	_lobby().press_a(P1)
	_lobby().press_a(P2)
	_finish_countdown()
	await _pad(6, JOY_BUTTON_START)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	assert_int(_pause_menu().paused_by).is_equal(P2)


func test_restart_returns_to_lobby() -> void:
	_play_two()
	Game.pause()
	_pause_menu().press(PauseMenu.Choice.RESTART)
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_int(Game.round_index).is_equal(0)
	assert_bool(get_tree().paused).is_false()
	var lobby := _lobby()
	assert_bool(lobby.visible).is_true()
	assert_bool(lobby.readied[P1]).is_false()
	assert_bool(lobby.get_node("Spots/P2").joined).is_true()   # pads stay joined
	await await_idle_frame()
	assert_object(_main.game).is_null()
	lobby.press_a(P1)
	lobby.press_a(P2)
	_finish_countdown()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_int(Game.round_index).is_equal(1)


# --- joins mid-game, demo ------------------------------------------------------

## The Hill drops a late joiner straight in (out of the Front Loader's bucket), no waiting.
func test_late_joiner_drops_in() -> void:
	_boot()
	Players.join_virtual(P1)
	_lobby().hold_step(P1, true, Lobby.HOLD_TO_START)
	_finish_countdown()
	assert_bool(_main.game.players.has(P2)).is_false()
	Players.join_virtual(P2)
	var p2: HillPlayer = _main.game.player_node(P2)
	assert_object(p2).is_not_null()
	assert_int(p2.player).is_equal(P2)
	assert_bool(p2.locked).is_false()


func test_demo_skips_lobby() -> void:
	Game.demo = true
	_boot()
	await await_idle_frame()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_array(Players.active_players()).is_equal([P1, P2])
	assert_bool(_lobby().visible).is_false()


# --- solo mode (Players) -------------------------------------------------------

func test_solo_flag_parsing() -> void:
	assert_bool(Players.solo_from_args(PackedStringArray(["--solo"]))).is_true()
	assert_bool(Players.solo_from_args(PackedStringArray([]))).is_false()
	assert_bool(Players.solo).is_false()


func test_select_start_hold_toggles_solo() -> void:
	assert_bool(Players.hold_step(3, true, 1.0)).is_false()
	assert_bool(Players.hold_step(3, true, 1.1)).is_true()
	assert_bool(Players.solo).is_true()
	assert_array(Players.active_players()).is_equal([P1, P2])
	assert_bool(Players.hold_step(3, true, 5.0)).is_false()   # same hold: no second toggle
	Players.hold_step(3, false, 0.1)
	Players.hold_step(3, true, 2.1)
	assert_bool(Players.solo).is_false()
	assert_array(Players.active_players()).is_equal([P1])


func test_solo_focus_moves_the_pad() -> void:
	Players.set_solo(true, 3)
	var pad := func(a: String) -> int:
		return InputMap.action_get_events(a).filter(
				func(e): return e is InputEventJoypadButton).size()
	assert_int(pad.call("p1_action")).is_equal(1)
	assert_int(pad.call("p2_action")).is_equal(0)
	Players.set_solo_focus(P2)
	assert_int(pad.call("p1_action")).is_equal(0)
	assert_int(pad.call("p2_action")).is_equal(1)
