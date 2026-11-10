## Audio lane (2026-11-10): every cue the code plays and every cue in GAME.md resolves to a real
## file, variants rotate, rate caps hold, engines follow speed, the layered music switches up /
## down / cavern with crossfades (and the split keeps its theme), barks fall back to placeholders,
## treasures get bigger with depth, and a simulated 5-minute soak never runs away.
class_name TestAudio
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const VEHICLES := [&"front_loader", &"excavator", &"dump_truck", &"crane", &"drill_rig"]
## The GAME.md Audio table (design names; ALIASES map them onto the files).
const DESIGN_CUES := ["scoop", "tip", "treasure", "fall", "bonk", "flood", "elevator", "build_place",
	"build_move", "tree_fall", "rock_crack", "gnome_whistle", "dragon_snore", "dump_truck_reverse",
	"treasure_small", "treasure_big", "treasure_huge", "resident_arrive", "plank", "light_on",
	"payoff_mole", "payoff_caveman", "payoff_gnomes", "payoff_dragon", "plank", "whistle_muffled",
	"elevator_clank", "elevator_ding"]


class FakeDirector extends RefCounted:
	var scenes := {}

	func scene_of(p: int) -> StringName:
		return scenes.get(p, &"")


class FakeGame extends Node:
	var players := {}
	var director := FakeDirector.new()
	var underground = null
	var story = null


var _game: Node
var _intent := {}


func before_test() -> void:
	for p in Audio._pool:     # earlier suites may leave voices ringing (and caps full)
		p.stop()
	Audio._voice.stop()
	Audio.reset_caps()
	Audio.synth_missing = false


func after_test() -> void:
	Audio.synth_missing = true
	for k in [97, 98, 99]:
		Audio.engine_stop(k)
	if is_instance_valid(_game):
		_game.free()
	Audio.music_state(&"up", 0, false, 0.01)


# --- every cue has a file --------------------------------------------------------------------

func _scan(dir: String, out: Dictionary) -> void:
	var re := RegEx.new()
	re.compile("Audio\\.play\\(\"([a-z0-9_]+)\"")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string(dir + f)):
				out[m.get_string(1)] = dir + f
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + d + "/", out)


func _all_cues() -> Dictionary:
	var cues := {}
	_scan("res://scripts/", cues)
	_scan("res://scenes/", cues)
	for c in DESIGN_CUES:
		cues[c] = "GAME.md"
	for f in DirAccess.get_files_at("res://data/blocks/"):
		if f.ends_with(".tres"):
			var b = load("res://data/blocks/" + f)
			cues[String(b.dig_sound) if b.dig_sound != &"" else "dig_%s" % b.id] = f
	for v in VEHICLES:
		var d: VehicleData = load("res://data/vehicles/%s.tres" % v)
		for k in d.sounds:
			cues[String(d.sounds[k])] = "data/vehicles/%s.tres" % v
		cues["engine_%s" % v] = "GAME.md"
		cues["horn_%s" % v] = "GAME.md"
	for t in DirAccess.get_files_at("res://data/treasures/"):
		if t.ends_with(".tres"):
			cues[HillAudio.treasure_cue(StringName(t.get_basename()))] = t
	return cues


func test_every_cue_resolves_to_a_file() -> void:
	var cues := _all_cues()
	assert_int(cues.size()).is_greater(100)
	var missing: Array = []
	for c: String in cues:
		if not Audio.has_cue(c) and not UiSound.CUES.has(c):   # menu cues: the kit's synth
			missing.append("%s (%s)" % [c, cues[c]])
	assert_array(missing).is_empty()


func test_every_vehicle_has_its_own_engine_and_horn() -> void:
	var engines := {}
	var horns := {}
	for v in VEHICLES:
		var e := Audio.stream_for("engine_%s" % v)
		var h := Audio.stream_for("horn_%s" % v)
		assert_object(e).is_not_null()
		assert_object(h).is_not_null()
		engines[e.resource_path] = true
		horns[h.resource_path] = true
	assert_int(engines.size()).is_equal(5)
	assert_int(horns.size()).is_equal(5)


func test_music_files_are_in() -> void:
	for t in ["music_up", "music_down", "music_cavern"]:
		assert_bool(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % t)).is_true()
	assert_bool(ResourceLoader.exists("res://assets/audio/music/music_down_layer_1.wav")).is_true()


# --- variants and caps -----------------------------------------------------------------------

func test_variants_rotate_without_repeats() -> void:
	assert_int(Audio.variant_count("dig_dirt")).is_equal(3)
	var seen := {}
	var last := ""
	for i in 12:
		var s := Audio.stream_for("dig_dirt")
		assert_str(s.resource_path).is_not_equal(last)
		last = s.resource_path
		if i < 3:
			seen[last] = true
	assert_int(seen.size()).is_equal(3)   # one full bag = every variant once


func test_rate_cap_blocks_a_too_quick_repeat_and_the_voice_cap_holds() -> void:
	assert_bool(Audio.play("dig_dirt")).is_true()
	assert_bool(Audio.play("dig_dirt")).is_false()      # inside the 60 ms gap
	Audio.advance(0.07)
	assert_bool(Audio.play("dig_dirt")).is_true()
	var cap: Array = Audio.cap_of("dragon_snore")
	assert_int(int(cap[1])).is_equal(1)
	assert_bool(Audio.play("dragon_snore")).is_true()
	Audio.advance(5.0)
	if Audio.playing_count("dragon_snore") > 0:
		assert_bool(Audio.play("dragon_snore")).is_false()   # still snoring: one at a time


func test_simulated_five_minute_soak_never_runs_away() -> void:
	var cues := ["dig_dirt", "dig_stone", "dig_clay", "fall", "scoop", "pile_dump", "build_place",
		"build_pickup", "tree_fall", "rock_crack", "whistle", "treasure", "jump", "horn_crane"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Audio.engine(98, "engine_front_loader")
	Audio.engine(99, "engine_dump_truck")
	for step in 3000:     # 5 min at 0.1 s, ~6 sounds a step
		Audio.advance(0.1)
		for k in 6:
			Audio.play(cues[rng.randi() % cues.size()])
		Audio.engine_speed(98, rng.randf())
		Audio.engine(99, "engine_dump_truck")
		for c in cues:
			assert_int(Audio.playing_count(c)).is_less_equal(int(Audio.cap_of(c)[1]))
		Audio.bark("jeff", "rock_name")
	assert_int(Audio.voice_count()).is_less_equal(Audio.POOL_SIZE)
	assert_int(Audio.engine_count()).is_equal(2)
	assert_int(Audio.get_child_count()).is_less_equal(Audio.POOL_SIZE + 3 + 2)


# --- engines ---------------------------------------------------------------------------------

func test_engine_pitch_follows_speed() -> void:
	Audio.engine(97, "engine_excavator")
	assert_int(Audio.engine_count()).is_greater_equal(1)
	Audio.engine_speed(97, 0.0)
	assert_float(Audio.engine_pitch(97)).is_equal_approx(Audio.ENGINE_PITCH.x, 0.001)
	Audio.engine_speed(97, 0.5)
	var half := Audio.engine_pitch(97)
	Audio.engine_speed(97, 1.0)
	assert_float(Audio.engine_pitch(97)).is_equal_approx(Audio.ENGINE_PITCH.y, 0.001)
	assert_float(half).is_between(Audio.ENGINE_PITCH.x + 0.05, Audio.ENGINE_PITCH.y - 0.05)
	Audio.engine_speed(97, 3.0)    # clamped
	assert_float(Audio.engine_pitch(97)).is_equal_approx(Audio.ENGINE_PITCH.y, 0.001)
	Audio.engine_stop(97)
	assert_float(Audio.engine_pitch(97)).is_equal(0.0)


func test_driving_in_the_game_runs_that_vehicles_engine() -> void:
	Save.profile = "test_audio"
	Save.wipe()
	Players.reset()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	var g := HillGame.new()
	g.start_players = [P1]
	_game = g
	get_tree().root.add_child(g)
	Players.join_virtual(P1)
	var node := g.player_node(P1)
	if node == null:
		node = g.wake(P1)
	_intent = {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
	node.intent_source = func() -> Dictionary: return _intent
	var pos := Vector2(Hillville.PILE_X - 300.0, 0)
	g.park_new(&"dump_truck", pos, HillGame.HILLVILLE)
	g.place_player(P1, HillGame.HILLVILLE, pos)
	assert_bool(g.hop_in(node)).is_true()
	for i in 4:
		await get_tree().physics_frame
	assert_int(Audio.engine_count()).is_equal(1)
	var idle := Audio.engine_pitch(P1)
	_intent = {"move": Vector2.LEFT, "dig": false, "jump": false, "book": false, "horn": false}
	for i in 40:
		await get_tree().physics_frame
	assert_float(Audio.engine_pitch(P1)).is_greater(idle)
	g.hop_out(node)
	for i in 3:
		await get_tree().physics_frame
	assert_int(Audio.engine_count()).is_equal(0)
	g.free()
	Players.reset()
	Progress.reset()
	Save.wipe()
	Game._set_state(Game.State.LOBBY)


# --- music -----------------------------------------------------------------------------------

func test_music_crossfades_up_down_and_cavern() -> void:
	Audio.music_state(&"up", 0, false, 0.01)
	await get_tree().create_timer(0.1).timeout
	assert_float(Audio.music_volume("up")).is_equal(0.0)
	assert_float(Audio.music_volume("down")).is_equal(Audio.SILENT_DB)
	assert_int(Audio.music_layers()).is_equal(4)
	Audio.music_state(&"down", 2, false, 0.6)
	assert_float(Audio.music_target("down")).is_equal(0.0)
	assert_float(Audio.music_target("up")).is_equal(Audio.SILENT_DB)
	assert_float(Audio.music_target("layer_2")).is_equal(0.0)
	assert_float(Audio.music_target("layer_3")).is_equal(Audio.SILENT_DB)
	await get_tree().create_timer(0.25).timeout
	var mid := Audio.music_volume("down")
	assert_float(mid).is_between(Audio.SILENT_DB + 1.0, -1.0)     # crossfading, not a cut
	await get_tree().create_timer(0.6).timeout
	assert_float(Audio.music_volume("down")).is_equal(0.0)
	assert_float(Audio.music_volume("up")).is_equal(Audio.SILENT_DB)
	Audio.music_state(&"down", 5, true, 0.01)
	assert_float(Audio.music_target("cavern")).is_equal(0.0)
	assert_float(Audio.music_target("layer_4")).is_equal(0.0)
	await get_tree().create_timer(0.1).timeout
	assert_float(Audio.music_volume("cavern")).is_equal(0.0)


func test_big_moments_duck_the_music() -> void:
	Audio.advance(5.0)
	assert_bool(Audio.play("treasure_huge")).is_true()
	await get_tree().create_timer(0.3).timeout
	assert_float(Audio.duck_db()).is_less(-3.0)


func test_theme_follows_most_players_and_a_split_keeps_it() -> void:
	var g := FakeGame.new()
	_game = g
	var a := Node2D.new()
	var b := Node2D.new()
	g.add_child(a)
	g.add_child(b)
	g.players = {P1: a, P2: b}
	var ha := HillAudio.new()
	ha.game = g
	g.add_child(ha)
	get_tree().root.add_child(g)
	Audio.music_state(&"up", 0, false, 0.01)
	g.director.scenes = {P1: &"hillville", P2: &"underground"}
	b.global_position = Vector2(100, 16 * 150)
	var m := ha.music_for(g.players)
	assert_str(String(m.theme)).is_equal("up")      # a tie keeps the theme
	assert_int(m.zone).is_greater(0)                # but the layers follow the digger
	g.director.scenes = {P1: &"underground", P2: &"underground"}
	m = ha.music_for(g.players)
	assert_str(String(m.theme)).is_equal("down")
	Audio.music_state(m.theme, m.zone, m.cavern, 0.01)
	g.director.scenes = {P1: &"hillville", P2: &"underground"}
	assert_str(String(ha.music_for(g.players).theme)).is_equal("down")
	b.global_position = Vector2((HillGenerator.CAVERN.position.x + 10) * 16.0, (HillGenerator.CAVERN.position.y + 10) * 16.0)
	assert_bool(ha.music_for(g.players).cavern).is_true()


func test_snore_gets_louder_with_depth() -> void:
	var ha := HillAudio.new()
	var g := FakeGame.new()
	_game = g
	ha.game = g
	g.add_child(ha)
	get_tree().root.add_child(g)
	var last := -1.0
	for i in 6:
		assert_float(ha.snore_volume(i)).is_greater_equal(last)
		last = ha.snore_volume(i)
	assert_float(ha.snore_volume(0)).is_equal(0.0)
	assert_float(ha.snore_volume(5)).is_equal(1.0)


func test_treasures_get_bigger_with_depth() -> void:
	assert_str(HillAudio.treasure_cue(&"bottle_caps")).is_equal("treasure_small")
	assert_str(HillAudio.treasure_cue(&"buried_car")).is_equal("treasure")
	assert_str(HillAudio.treasure_cue(&"dino_skeleton")).is_equal("treasure_big")
	assert_str(HillAudio.treasure_cue(&"dragon_egg")).is_equal("treasure_huge")
	assert_str(HillAudio.treasure_cue(&"no_such_thing")).is_equal("treasure")


# --- barks -----------------------------------------------------------------------------------

func test_barks_fall_back_to_placeholders_and_are_rate_capped() -> void:
	for pair in [["jeff", "rock_name"], ["chuck", "narrate"], ["mole", "oh_dear"],
			["gnome_foreman", "mutter"], ["gnome_foreman", "whistle"], ["dragon", "rumble"], ["dragon", "yawn"]]:
		assert_object(Audio.bark_stream(pair[0], pair[1])).is_not_null()
		assert_bool(Audio.bark_is_real(pair[0], pair[1])).is_false()
	assert_object(Audio.bark_stream("jeff", "no_such_line")).is_null()
	Audio.advance(30.0)
	assert_bool(Audio.bark("mole", "oh_dear")).is_true()
	assert_bool(Audio.bark("jeff", "rock_name")).is_false()     # one bark at a time
	Audio._voice.stop()
	assert_bool(Audio.bark("jeff", "rock_name")).is_false()     # BARK_GAP
	Audio.advance(Audio.BARK_GAP + 0.1)
	assert_bool(Audio.bark("jeff", "rock_name")).is_true()
	Audio._voice.stop()
	Audio.advance(Audio.BARK_GAP + 0.1)
	assert_bool(Audio.bark("jeff", "rock_name")).is_false()     # BARK_REPEAT for the same line
	Audio._voice.stop()
