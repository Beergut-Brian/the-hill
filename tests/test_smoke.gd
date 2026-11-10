## gdUnit4 smoke tests: the boot scene loads and the autoloads answer.
class_name TestSmoke
extends GdUnitTestSuite

var _real_settings := ""


func before() -> void:
	# Its own settings file: nothing here may write into the real user://settings.json.
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_smoke.json"
	Save.reload_settings()


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func test_main_scene_loads() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	assert_object(scene).is_not_null()
	var instance := scene.instantiate()
	assert_object(instance).is_not_null()
	instance.free()


func test_players_colors_are_green_and_red() -> void:
	assert_object(Players).is_not_null()
	assert_that(Players.COLOR[Players.P1].to_html(false)).is_equal("3cc24a")
	assert_that(Players.COLOR[Players.P2].to_html(false)).is_equal("e4393c")


func test_input_map_has_every_player_action() -> void:
	for p in [Players.P1, Players.P2]:
		for a in Players.ACTIONS:
			assert_bool(InputMap.has_action(Players.action(p, a))).is_true()
	for g in ["pause", "restart", "debug_overlay", "debug_screenshot"]:
		assert_bool(InputMap.has_action(g)).is_true()


func test_game_round_cycle() -> void:
	var before := Game.round_index
	Game.start_round()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_int(Game.round_index).is_equal(before + 1)
	Game.end_round({})
	assert_int(Game.state).is_equal(Game.State.ROUND_END)


func test_save_roundtrip() -> void:
	Save.set_value("smoke", 42)
	Save.flush()
	assert_int(Save.get_value("smoke", 0)).is_equal(42)
	Save.wipe()
	assert_object(Save.get_value("smoke")).is_null()


func test_profile_from_args_accepts_both_forms() -> void:
	assert_str(Save.profile_from_args(PackedStringArray(["--profile=p2"]), "p1")).is_equal("p2")
	assert_str(Save.profile_from_args(PackedStringArray(["--", "--profile=kid"]), "p1")).is_equal("kid")
	assert_str(Save.profile_from_args(PackedStringArray(["--profile=../x"]), "p1")).is_equal("p1")
	assert_str(Save.profile_from_args(PackedStringArray([]), "p1")).is_equal("p1")
