## The scripted --demo run end to end, headless: HillGame with Game.demo set adds the runner, which
## drives both players through their intents only. It must find the Buried Car, place a Barn and a
## Garage and unlock the Excavator well inside its timeout (about 38 s of game time today).
class_name TestHillDemo
extends GdUnitTestSuite

const LIMIT_S := 90.0

var _game: HillGame
var _real_profile := ""
var _real_settings := ""


func before() -> void:
	_real_profile = Save.profile
	# Its own settings file: nothing here may write into the real user://settings.json.
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_hill_demo.json"
	Save.reload_settings()
	Game.quit_exits = false


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.flush()
	Save.profile = _real_profile
	Save._load()
	Game.quit_exits = true


func before_test() -> void:
	Save.profile = "test_hill_demo"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)


func after_test() -> void:
	Game.demo = false
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func test_demo_finds_the_car_builds_and_unlocks_the_excavator() -> void:
	Players.join_virtual(Players.P1)
	Players.join_virtual(Players.P2)
	Game.demo = true
	_game = HillGame.new()
	_game.load_saved = false
	get_tree().root.add_child(_game)
	var runner := _game.get_node_or_null(^"DemoRunner") as HillDemoRunner
	assert_object(runner).is_not_null()
	var max_frames := int(LIMIT_S * Engine.physics_ticks_per_second)
	var n := 0
	var car_at := -1.0
	while runner.step != &"idle" and n < max_frames:
		await get_tree().physics_frame
		n += 1
		if car_at < 0.0 and Progress.has_treasure(&"buried_car"):
			car_at = runner.t
	assert_float(car_at).is_greater(0.0)
	assert_bool(Progress.has_treasure(&"buried_car")).is_true()
	assert_int(Progress.count_buildings(&"barn")).is_greater_equal(1)
	assert_int(Progress.count_buildings(&"garage")).is_greater_equal(1)
	assert_bool(Progress.has_vehicle(&"excavator")).is_true()
	assert_int(_game.drivers.get(&"excavator", -1)).is_equal(Players.P1)
	assert_str(String(runner.step)).is_equal("idle")
