## Start a new game from the menu (PT12-1, Kaden 2026-11-12): Continue + New Hill only with a save;
## New Hill asks and needs A held HOLD_TIME s; confirming keeps the old hill as a backup and the next
## game starts on a world with no edits; Restore last hill swaps it back; only 3 backups are kept.
## Every test runs in a scratch saves folder (Save.saves_dir) and its own profile, never a real save.
class_name TestNewGame
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const DIR := "user://test_new_game_saves"

var _main: Node
var _real_dir := ""


func before() -> void:
	SuiteSandbox.enter("new_game")   # first: never the real profile, settings or picks file
	_real_dir = Save.saves_dir
	Save.saves_dir = DIR
	Game.quit_exits = false


func after() -> void:
	_clear_dir()
	Save.saves_dir = _real_dir
	Save._load()
	Game.quit_exits = true
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	_clear_dir()
	Save._load()   # nothing there: a first run
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


func _clear_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, f])


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


## A save on disk holding `marker` (and a few summary keys).
func _seed(marker: String) -> void:
	Save.set_value("marker", marker)
	Save.set_value("buildings", [{"id": "house", "cell": [3, 0]}])
	Save.set_value("players", [{"deepest": 1, "scene": "hillville"}, {"deepest": 0, "scene": "hillville"}])
	Save.flush()


func _hold_through(q: HoldConfirm) -> bool:
	q.move_focus(1)
	q.press_a()
	return q.hold_step(true, HoldConfirm.HOLD_TIME + 0.01)


func _start_game() -> void:
	var lobby := _lobby()
	lobby.press_a(P1)
	lobby.press_a(P2)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)


# --- the menu ------------------------------------------------------------------

func test_first_run_shows_only_play() -> void:
	_boot()
	var lobby := _lobby()
	var play: MenuItem = lobby.get_node("Buttons/Play")
	var new: MenuItem = lobby.get_node("Buttons/NewHill")
	assert_str(play.text).is_equal("Play")
	assert_bool(new.visible).is_false()
	assert_int(MenuItem.step(lobby._items, Lobby.Choice.PLAY, 1)).is_equal(Lobby.Choice.SETTINGS)


func test_menu_shows_continue_and_new_hill_with_a_save() -> void:
	_seed("old")
	_boot()
	var lobby := _lobby()
	assert_str((lobby.get_node("Buttons/Play") as MenuItem).text).is_equal("Continue")
	assert_bool((lobby.get_node("Buttons/NewHill") as MenuItem).visible).is_true()
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)   # Continue focused
	lobby.move_focus(1)
	assert_int(lobby.focus).is_equal(Lobby.Choice.NEW)


# --- New Hill needs the hold ---------------------------------------------------

func test_new_hill_without_the_hold_does_nothing() -> void:
	_seed("old")
	_boot()
	Players.join_virtual(P1)
	var lobby := _lobby()
	lobby.set_ready(P1, false, true)
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	var q := lobby.new_hill
	assert_bool(q.active).is_true()
	assert_int(q.focus).is_equal(HoldConfirm.Choice.CANCEL)   # Keep first
	assert_str(q.summary.layer).is_equal("Clay")
	assert_int(q.summary.buildings).is_equal(1)
	# A held over from the menu behind never counts, however long.
	q.move_focus(1)
	assert_bool(q.hold_step(true, 5.0)).is_false()
	# A tap: a press and a short hold, then let go.
	q.press_a()
	assert_bool(q.hold_step(true, HoldConfirm.HOLD_TIME * 0.5)).is_false()
	assert_float(q.progress).is_greater(0.0)
	assert_bool(q.hold_step(false, 0.016)).is_false()
	assert_bool(q.active).is_true()
	# B cancels.
	lobby.press_b(P1)
	assert_bool(q.active).is_false()
	# A on Keep cancels too.
	lobby.press_a(P1)
	q.press_a()
	assert_bool(q.active).is_false()
	assert_bool(Save.has_save()).is_true()
	assert_str(Save.get_value("marker")).is_equal("old")
	assert_bool(Save.has_backup()).is_false()


func test_hold_backs_up_and_the_next_game_has_no_edits() -> void:
	# Play a game, dig into the world, back to the menu: that is the save.
	_boot()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	_start_game()
	var world: TileWorld = _main.game.underground.world
	var fresh_edits := world.edits.tiles.size()
	var cell := Vector2i(12, 30)
	world.set_tile(cell, 0 if world.get_tile(cell) != 0 else 1)
	assert_int(world.edits.tiles.size()).is_greater(fresh_edits)
	Game.to_lobby()
	await await_idle_frame()
	assert_bool(Save.has_save()).is_true()
	var lobby := _lobby()
	assert_str((lobby.get_node("Buttons/Play") as MenuItem).text).is_equal("Continue")
	# New Hill, held through.
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	assert_bool(_hold_through(lobby.new_hill)).is_true()
	var list := Save.backups()
	assert_int(list.size()).is_equal(1)
	assert_str(list[0].get_file()).starts_with(Save.profile + ".backup-")
	assert_str(list[0].get_base_dir()).is_equal(DIR)
	var kept := Save.read_save(list[0])
	assert_int((kept.world.edits as Array).size()).is_equal((fresh_edits + 1) * 3)
	assert_bool(Save.has_save()).is_false()
	assert_bool(FileAccess.file_exists("%s/%s.json" % [DIR, Save.profile])).is_false()
	# The normal ready-up, as a first run.
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_str((lobby.get_node("Buttons/Play") as MenuItem).text).is_equal("Play")
	assert_bool((lobby.get_node("Buttons/NewHill") as MenuItem).visible).is_false()
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)
	await await_idle_frame()
	_start_game()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_int(_main.game.underground.world.edits.tiles.size()).is_equal(fresh_edits)
	assert_bool(_main.game.underground.world.edits.tiles.has(cell)).is_false()


# --- Restore -------------------------------------------------------------------

func test_restore_swaps_the_last_hill_back() -> void:
	_seed("old")
	assert_str(Save.start_new()).is_not_empty()
	_seed("new")
	assert_bool(Save.restore_last()).is_true()
	assert_str(Save.get_value("marker")).is_equal("old")
	# The hill it replaced is the newest backup now: a restore undoes the same way.
	var list := Save.backups()
	assert_int(list.size()).is_equal(1)
	assert_str(Save.read_save(list[0]).marker).is_equal("new")
	assert_bool(Save.restore_last()).is_true()
	assert_str(Save.get_value("marker")).is_equal("new")


func test_restore_in_settings_shows_only_with_a_backup_and_needs_the_hold() -> void:
	_seed("old")
	_boot()
	var lobby := _lobby()
	var settings: SettingsPanel = lobby.get_node("Settings")
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	assert_bool(settings.get_node("Card/Rows/Restore").visible).is_false()
	for i in 6:
		settings.move_focus(1)
	assert_int(settings.focus).is_equal(SettingsPanel.Row.SOLO)   # Restore is skipped
	settings.close()
	# New Hill, then play the new one a little (a save of its own).
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	assert_bool(_hold_through(lobby.new_hill)).is_true()
	_seed("new")
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	assert_bool(settings.get_node("Card/Rows/Restore").visible).is_true()
	for i in 6:
		settings.move_focus(1)
	assert_int(settings.focus).is_equal(SettingsPanel.Row.RESTORE)
	settings.adjust(1, true)   # A
	assert_bool(settings.asking()).is_true()
	assert_str(settings.restore.summary.layer).is_equal("Clay")
	# A tap does nothing.
	settings.restore.move_focus(1)
	settings.restore.press_a()
	settings.restore.hold_step(true, 0.3)
	settings.restore.hold_step(false, 0.016)
	assert_str(Save.get_value("marker")).is_equal("new")
	assert_bool(_hold_through(settings.restore)).is_true()
	assert_str(Save.get_value("marker")).is_equal("old")
	assert_str((lobby.get_node("Buttons/Play") as MenuItem).text).is_equal("Continue")


func test_restore_from_the_pause_menu_goes_back_to_the_lobby_first() -> void:
	_seed("old")
	Save.start_new()
	_boot()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	_start_game()
	Game.pause()
	var pm: PauseMenu = _main.get_node("UI/PauseMenu")
	pm.press(PauseMenu.Choice.SETTINGS)
	var settings: SettingsPanel = pm.get_node("Settings")
	for i in 6:
		settings.move_focus(1)
	settings.adjust(1, true)
	assert_bool(_hold_through(settings.restore)).is_true()
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_str(Save.get_value("marker")).is_equal("old")
	# The game played meanwhile was saved first, and is the newest backup now.
	assert_bool(Save.read_save(Save.backups()[0]).has("world")).is_true()


func test_pause_menu_has_back_to_menu() -> void:
	_boot()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	_start_game()
	Game.pause()
	var pm: PauseMenu = _main.get_node("UI/PauseMenu")
	assert_str((pm.get_node("Card/Buttons/Restart") as MenuItem).text).is_equal("Back to menu")
	pm.press(PauseMenu.Choice.RESTART)
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	await await_idle_frame()
	assert_str((_lobby().get_node("Buttons/Play") as MenuItem).text).is_equal("Continue")


# --- backups -------------------------------------------------------------------

func test_backups_capped_at_three_newest_kept() -> void:
	for i in 5:
		_seed("hill%d" % i)
		Save.start_new()
	var list := Save.backups()
	assert_int(list.size()).is_equal(Save.BACKUPS_KEPT)
	assert_str(Save.read_save(list[0]).marker).is_equal("hill4")
	assert_str(Save.read_save(list[2]).marker).is_equal("hill2")


func test_nothing_to_keep_makes_no_backup() -> void:
	assert_str(Save.start_new()).is_empty()
	assert_bool(Save.has_backup()).is_false()
	assert_bool(Save.restore_last()).is_false()


func test_never_touches_the_real_saves_folder() -> void:
	_seed("old")
	Save.start_new()
	assert_str(Save.saves_dir).is_equal(DIR)
	assert_bool(Save.profile.begins_with(SuiteSandbox.PROFILE_PREFIX)).is_true()
	for f in DirAccess.get_files_at(_real_dir):
		assert_bool(f.begins_with(Save.profile + ".backup-")).is_false()
