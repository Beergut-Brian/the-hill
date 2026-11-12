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
	var pockets: Array[Rect2i] = []
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



## One trigger per event: Jeff digging a fish out flops (HillAudio) and HillBarks, the only owner of
## his rock bark, stays quiet; he names the ice on the next plain ice tile. Through the real signal,
## so both listeners hear the same dig.
func test_a_fish_dug_by_jeff_flops_without_a_rock_name() -> void:
	var real: String = Roster._picks.get(Roster.P1, "")
	Roster._picks[Roster.P1] = "jeff"
	var jeff := Node2D.new()
	_game.add_child(jeff)
	_game.players[Roster.P1] = jeff
	_u().generator.fish[Vector2i(4, 5)] = 0
	var rock_names := func() -> int:
		return _ha.barks.fired.filter(func(f: Dictionary) -> bool:
			return f.who == "jeff" and f.cue == "rock_name").size()
	Events.tile_dug.emit(Vector2i(4, 5), &"ice", Roster.P1)
	assert_int(Audio.playing_count("fish_flop")).is_equal(1)
	assert_int(rock_names.call()).is_equal(0)
	assert_bool(Audio._voice.playing).is_false()
	Events.tile_dug.emit(Vector2i(3, 5), &"ice", Roster.P1)
	assert_int(rock_names.call()).is_equal(1)
	assert_int(Audio.playing_count("fish_flop")).is_equal(1)   # plain ice: no second flop
	Roster._picks[Roster.P1] = real


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


## A-19 live: dev's C-22 has no drain-kind puzzle; the water a player drains is a water pocket
## (`generator.pockets`). Its water running out into the tunnel gurgles; still pocket water does not.
func test_a_water_pocket_running_out_into_the_tunnel_gurgles() -> void:
	_u().generator.pockets = [Rect2i(10, 10, 3, 3)]
	_fill_pocket()
	_checks(10)
	assert_bool(_ha.gurgling).is_false()
	# A dig breaches the side: each check one cell runs out to the right, inside the margin.
	var pocket: Array = _u().world.wet.keys()
	for i in 3:
		_u().world.wet.erase(pocket[i])
		_u().world.wet[Vector2i(13 + i % HillAudio.POCKET_MARGIN, 12)] = true
		_checks(1)
	assert_bool(_ha.gurgling).is_true()
	_checks(int(ceil(HillAudio.GURGLE_HOLD / HillAudio.GURGLE_POLL)) + 1)
	assert_bool(_ha.gurgling).is_false()


## The regions: drain puzzles by their rects, pockets grown by the margin, other puzzle kinds and
## empty pockets skipped.
func test_drain_regions_cover_drain_puzzles_and_grown_pockets_only() -> void:
	var g := FakeGen.new()
	g.puzzles = [{"kind": &"boulder_wall", "rect": Rect2i(0, 0, 4, 4)}, _drain()]
	g.pockets = [Rect2i(20, 20, 4, 2), Rect2i()]
	var regions := HillAudio.drain_regions(g)
	assert_int(regions.size()).is_equal(2)
	assert_int((regions[0] as Array).size()).is_equal(3)
	assert_bool(regions[1][0] == Rect2i(20, 20, 4, 2).grow(HillAudio.POCKET_MARGIN)).is_true()
	assert_array(HillAudio.drain_regions(null)).is_empty()


## The real world: the generated Clay pocket sits still (no gurgle) until a tunnel is opened beside
## it, then its water runs out and the gurgle plays. Staged: the cells beside the pocket are set to
## air directly and the water is stepped by hand, no waiting on the clock.
func test_the_real_clay_pocket_is_quiet_until_it_is_breached() -> void:
	var u: Underground = load("res://scenes/levels/underground.tscn").instantiate()
	_game.underground = u
	_game.add_child(u)
	var pocket: Rect2i = u.generator.pocket
	assert_bool(pocket.size != Vector2i.ZERO).is_true()
	var eye := Node2D.new()
	u.world.add_child(eye)
	eye.position = u.world.shape.center_of(pocket.get_center())
	u.world.track(eye)
	u.world.update_chunks(-1)
	u.world.water_hz = 0.0          # the test steps the water itself
	for i in 40:
		u.world.step_water()
	assert_bool(u.world.has_water(Vector2i(pocket.position.x + 1, pocket.end.y - 1))).is_true()
	for i in 10:
		u.world.step_water()
		_checks(1)
	assert_bool(_ha.gurgling).is_false()
	# Open a tunnel off the pocket's bottom-right corner, inside the margin.
	var air := 0
	for x in range(pocket.end.x, pocket.end.x + HillAudio.POCKET_MARGIN):
		for y in range(pocket.end.y - 2, pocket.end.y):
			u.world.set_tile(Vector2i(x, y), air)
	var ran := false
	for i in 20:
		u.world.step_water()
		_checks(1)
		ran = ran or _ha.gurgling
	assert_bool(ran).is_true()
