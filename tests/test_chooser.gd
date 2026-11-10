## The character chooser on the lobby podiums: cycle, skip the other player's pick, locked while
## ready, B unlocks, solo, the name plate, 3D and pixel characters, the pick survives a relaunch.
## Uses a three-character fixture roster and its own picks and settings files.
class_name TestChooser
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const THREE := "res://tests/fixtures/roster_three.json"
const FILE := "user://test_chooser_players.json"

var _main: Node
var _real := {}


func before() -> void:
	_real = { "settings": Save.settings_path, "picks": Roster.picks_path, "data": Roster.data_path }
	Save.settings_path = "user://test_settings_chooser.json"
	Roster.picks_path = FILE
	Roster.data_path = THREE


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real.settings
	Save.reload_settings()
	DirAccess.remove_absolute(FILE)
	Roster.picks_path = _real.picks
	Roster.data_path = _real.data
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Save.wipe_settings()
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	Roster.data_path = THREE
	Roster.args_override = PackedStringArray(["--test-chooser"])
	Roster.reload()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	UiStyle.use_skin(null)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()


func _boot() -> Lobby:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main.get_node("UI/Lobby")


func _slot(lobby: Lobby, p: int) -> CharacterSlot:
	return lobby.get_node("Spots/P%d/Character" % (p + 1))


## Joined, then B: on the podium, not ready, free to choose.
func _join_unready(lobby: Lobby, p: int) -> void:
	Players.join_virtual(p)
	lobby.press_b(p)


func test_cycles_and_skips_the_other_players_pick() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	assert_bool(lobby.get_node("Spots/P1").can_change).is_true()
	assert_bool(lobby.choose(P1, 1)).is_true()       # jeff -> (chuck is P2's) -> pip
	assert_str(Roster.pick(P1)).is_equal("pip")
	assert_str(UiStyle.skin().player_name(P1)).is_equal("PIP")
	assert_bool(lobby.choose(P1, 1)).is_true()       # pip -> wrap -> jeff
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_bool(lobby.choose(P1, -1)).is_true()      # jeff -> wrap -> pip
	assert_str(Roster.pick(P1)).is_equal("pip")
	assert_str(Roster.pick(P2)).is_equal("chuck")    # never the same character twice


func test_ready_locks_and_b_unlocks() -> void:
	var lobby := _boot()
	Players.join_virtual(P1)                          # joins ready
	assert_bool(lobby.get_node("Spots/P1").can_change).is_false()
	assert_bool(lobby.choose(P1, 1)).is_false()
	assert_str(Roster.pick(P1)).is_equal("jeff")
	lobby.press_b(P1)
	assert_bool(lobby.get_node("Spots/P1").can_change).is_true()
	assert_bool(lobby.choose(P1, 1)).is_true()
	lobby.press_a(P1)
	assert_bool(lobby.readied[P1]).is_true()
	assert_bool(lobby.choose(P1, 1)).is_false()
	assert_str(Roster.pick(P1)).is_equal("pip")


func test_not_joined_cannot_choose() -> void:
	var lobby := _boot()
	assert_bool(lobby.choose(P2, 1)).is_false()
	assert_bool(lobby.get_node("Spots/P2").can_change).is_false()


func test_stick_and_keys_drive_it() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	Input.action_press(Players.action(P1, "move_right"))
	assert_int(lobby._left_right(P1)).is_equal(1)
	Input.action_release(Players.action(P1, "move_right"))
	Input.action_press(Players.action(P1, "move_left"))
	assert_int(lobby._left_right(P1)).is_equal(-1)
	Input.action_release(Players.action(P1, "move_left"))


func test_nobody_free_bumps() -> void:
	Roster.data_path = "res://tests/fixtures/roster_two.json"     # Jeff and Chuck only
	Roster.reload()
	var lobby := _boot()
	_join_unready(lobby, P1)
	assert_bool(lobby.choose(P1, 1)).is_false()
	assert_str(Roster.pick(P1)).is_equal("jeff")


func test_swap_changes_the_3d_character_in_place() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	var slot := _slot(lobby, P1)
	var who := slot.character
	assert_bool(who is Node3D).is_true()
	assert_str(who.get("id")).is_equal("jeff")
	lobby.choose(P1, 1)
	var tw: Tween = slot.get("_tw")
	tw.custom_step(0.05)
	assert_float(slot.scale.y).is_less(0.8)              # squashed down
	assert_str(who.get("id")).is_equal("jeff")
	tw.custom_step(0.05)                                 # the bottom of the squash: the swap
	assert_object(slot.character).is_same(who)           # same rig, new model
	assert_str(who.get("id")).is_equal("pip")
	assert_int(lobby.get_node("Spots/P1").find_children("*", "Poof", false, false).size()).is_equal(1)
	tw.custom_step(0.5)
	assert_that(slot.scale).is_equal(Vector2.ONE)        # popped back to full size


func test_pixel_mode_uses_the_pixel_form() -> void:
	var sk := MenuSkin.new()
	sk.pixel_art = true
	sk.character_scale = 6.0
	UiStyle.use_skin(sk)
	var lobby := _boot()
	var slot := _slot(lobby, P2)
	assert_bool(slot.character is Node2D).is_true()
	assert_str(slot.character.get("id")).is_equal("chuck")
	assert_that((slot.character as Node2D).scale).is_equal(Vector2(6, 6))
	_join_unready(lobby, P2)
	lobby.choose(P2, 1)
	(slot.get("_tw") as Tween).custom_step(0.1)
	assert_str(slot.character.get("id")).is_equal("pip")


func test_skin_scene_with_set_character_is_told_the_pick() -> void:
	var root := Node3D.new()
	root.set_script(load("res://scenes/ui/kit/roster_jarling.gd"))
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	var sk := MenuSkin.new()
	sk.p1_character = ps
	UiStyle.use_skin(sk)
	var lobby := _boot()
	assert_str(_slot(lobby, P1).character.get("id")).is_equal("jeff")


func test_fixed_name_in_the_skin_wins() -> void:
	var sk := MenuSkin.new()
	sk.p1_name = "KICKER"
	UiStyle.use_skin(sk)
	assert_str(UiStyle.skin().player_name(P1)).is_equal("KICKER")
	assert_str(UiStyle.skin().player_name(P2)).is_equal("CHUCK")


func test_solo_select_switches_the_podium() -> void:
	var lobby := _boot()
	Players.set_solo(true)
	assert_bool(lobby.readied[P1] and lobby.readied[P2]).is_true()
	lobby.press_b(P1)
	assert_bool(lobby.counting).is_false()
	assert_bool(lobby.choose(P2, 1)).is_false()       # the pad drives P1
	assert_bool(lobby.choose(P1, 1)).is_true()
	assert_str(Roster.pick(P1)).is_equal("pip")
	lobby.solo_switch()
	assert_int(Players.solo_focus).is_equal(P2)
	assert_bool(lobby.get_node("Spots/P1").can_change).is_false()
	lobby.press_b(P2)
	assert_bool(lobby.choose(P2, 1)).is_true()        # chuck -> (pip is P1's) -> jeff
	assert_str(Roster.pick(P2)).is_equal("jeff")


func test_pick_persists_across_a_relaunch() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	lobby.choose(P1, 1)
	# the file is keyed by save profile first, then slot; read the profile the game actually used
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	assert_str(str(saved.get(Roster._profile(), {}).get("P1", ""))).is_equal("pip")
	_main.free()
	Players.reset()
	Roster.reload()                                     # the game (or another one) starts again
	lobby = _boot()
	assert_str(Roster.pick(P1)).is_equal("pip")
	assert_str(_slot(lobby, P1).character.get("id")).is_equal("pip")
	assert_str(UiStyle.skin().player_name(P1)).is_equal("PIP")
