## Audio lane, audio-3 (2026-11-10): the depth-life and puzzle cues. Every new cue resolves to a
## file, the frozen fish flops when it is dug out, and the drain gurgle runs only while a drain
## puzzle's water moves (ducked under a bark) and stops once the water is still.
class_name TestAudioDepth
extends GdUnitTestSuite

const NEW_CUES := {"worm_boop": 2, "fish_flop": 2, "fish_free": 1, "dig_sand": 3, "drain_gurgle": 1}


class FakeWorld extends RefCounted:
	var wet := {}

	func has_water(c: Vector2i) -> bool:
		return wet.has(c)


class FakeGen extends RefCounted:
	var puzzles: Array = []
	var fish := {}

	func fish_at(c: Vector2i) -> int:
		return fish.get(c, -1)


class FakeUnderground extends RefCounted:
	var world := FakeWorld.new()
	var generator := FakeGen.new()


class FakeGame extends Node:
	var players := {}
	var director = null
	var underground = null
	var story = null


var _game: Node
var _ha: HillAudio
var _real_settings := ""


func before() -> void:
	# Its own settings file: nothing here may write into the real user://settings.json.
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_audio_depth.json"
	Save.reload_settings()


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func before_test() -> void:
	for p in Audio._pool:
		p.stop()
	Audio._voice.stop()
	Audio.reset_caps()
	Audio.synth_missing = false
	var g := FakeGame.new()
	g.underground = FakeUnderground.new()
	_game = g
	_ha = HillAudio.new()
	_ha.game = g
	g.add_child(_ha)
	get_tree().root.add_child(g)


func after_test() -> void:
	Audio.synth_missing = true
	Audio.engine_stop(HillAudio.GURGLE_KEY)
	Audio._voice.stop()
	if is_instance_valid(_game):
		_game.free()
	Audio.music_state(&"up", 0, false, 0.01)


func _u() -> FakeUnderground:
	return _game.underground


## A drain puzzle: a 3x3 pocket with a 1x4 chute below it.
func _drain() -> Dictionary:
	return {"kind": &"drain", "rect": Rect2i(10, 10, 3, 7), "pocket": Rect2i(10, 10, 3, 3),
		"chute": Rect2i(11, 13, 1, 4)}


func _fill_pocket() -> void:
	for y in range(10, 13):
		for x in range(10, 13):
			_u().world.wet[Vector2i(x, y)] = true


func _checks(n: int) -> void:
	for i in n:
		_ha._gurgle(HillAudio.GURGLE_POLL)


func test_every_new_cue_resolves_to_its_files() -> void:
	for c: String in NEW_CUES:
		assert_bool(Audio.has_cue(c)).override_failure_message("no file for %s" % c).is_true()
		assert_int(Audio.variant_count(c)).is_equal(NEW_CUES[c])
		assert_object(Audio.stream_for(c)).is_not_null()


func test_digging_a_frozen_fish_out_flops() -> void:
	_u().generator.fish[Vector2i(4, 5)] = 0
	_ha._on_tile_dug(Vector2i(3, 5), &"ice", -1)
	assert_int(Audio.playing_count("fish_flop")).is_equal(0)
	_ha._on_tile_dug(Vector2i(4, 5), &"ice", -1)
	assert_int(Audio.playing_count("fish_flop")).is_equal(1)


func test_gurgle_runs_only_while_the_drain_water_moves() -> void:
	_u().generator.puzzles = [{"kind": &"boulder_wall", "rect": Rect2i(0, 0, 4, 4)}, _drain()]
	_fill_pocket()
	_checks(10)                                       # still water: no gurgle
	assert_bool(_ha.gurgling).is_false()
	assert_float(Audio.engine_db(HillAudio.GURGLE_KEY)).is_equal(Audio.SILENT_DB)
	# The plug opens: each check one cell of the pocket runs down the chute.
	var pocket: Array = _u().world.wet.keys()
	for i in 4:
		_u().world.wet.erase(pocket[i])
		_u().world.wet[Vector2i(11, 13 + i)] = true
		_checks(1)
	assert_bool(_ha.gurgling).is_true()
	assert_float(Audio.engine_db(HillAudio.GURGLE_KEY)).is_equal(HillAudio.GURGLE_DB)
	# The water lies still in the chute: it stops once GURGLE_HOLD has passed, not before.
	_checks(1)
	assert_bool(_ha.gurgling).is_true()
	_checks(int(ceil(HillAudio.GURGLE_HOLD / HillAudio.GURGLE_POLL)))
	assert_bool(_ha.gurgling).is_false()
	assert_float(Audio.engine_db(HillAudio.GURGLE_KEY)).is_equal(Audio.SILENT_DB)


func test_water_that_only_loads_in_or_jumps_once_is_not_running() -> void:
	_u().generator.puzzles = [_drain()]
	_checks(2)
	_fill_pocket()                                    # a chunk loads: more water than before
	_checks(3)
	assert_bool(_ha.gurgling).is_false()
	_u().world.wet.clear()                            # the chunk frees: one jump, then nothing
	_u().world.wet[Vector2i(11, 16)] = true
	_checks(4)
	assert_bool(_ha.gurgling).is_false()


func test_gurgle_ducks_under_a_bark() -> void:
	_u().generator.puzzles = [_drain()]
	_fill_pocket()
	_checks(1)
	var pocket: Array = _u().world.wet.keys()
	for i in 3:
		_u().world.wet.erase(pocket[i])
		_u().world.wet[Vector2i(11, 13 + i)] = true
		_checks(1)
	assert_bool(_ha.gurgling).is_true()
	Audio.advance(30.0)
	assert_bool(Audio.bark("mole", "oh_dear")).is_true()
	_ha._gurgle(0.0)
	assert_float(Audio.engine_db(HillAudio.GURGLE_KEY)).is_equal(HillAudio.GURGLE_DB + HillAudio.GURGLE_BARK_DB)
	Audio._voice.stop()
	_ha._gurgle(0.0)
	assert_float(Audio.engine_db(HillAudio.GURGLE_KEY)).is_equal(HillAudio.GURGLE_DB)


func test_the_gurgle_stops_when_the_audio_director_leaves() -> void:
	_u().generator.puzzles = [_drain()]
	_fill_pocket()
	_checks(1)
	var pocket: Array = _u().world.wet.keys()
	for i in 3:
		_u().world.wet.erase(pocket[i])
		_u().world.wet[Vector2i(11, 13 + i)] = true
		_checks(1)
	assert_bool(_ha.gurgling).is_true()
	_game.free()
	assert_float(Audio.engine_db(HillAudio.GURGLE_KEY)).is_equal(Audio.SILENT_DB)
