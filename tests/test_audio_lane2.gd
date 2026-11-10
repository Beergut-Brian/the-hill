## Audio lane 2 (2026-11-10, hill-audio-2): the cues that lane wired on top of the audio pass.
## Every new or newly played cue resolves to a real file (no beep), every vehicle's engine follows
## its speed, the horn plays once per press, the Dragon's snore plays on `dragon_snored` and gets
## louder by depth (HillAudio no longer shakes the camera itself), `lighthouse_on` plays when a
## Lighthouse is placed, a vehicle bucket scoop plays `scoop`, and the new rate caps hold.
class_name TestAudioLane2
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const VEHICLES := [&"front_loader", &"excavator", &"dump_truck", &"crane", &"drill_rig"]
const NEW_CUES := ["lighthouse_on", "scoop", "dragon_snore", "dump_truck_reverse",
	"engine_front_loader", "engine_excavator", "engine_dump_truck", "engine_crane", "engine_drill_rig",
	"horn_front_loader", "horn_excavator", "horn_dump_truck", "horn_crane", "horn_drill_rig"]


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
var _real_profile := ""


func before() -> void:
	_real_profile = Save.profile
	Game.quit_exits = false


func after() -> void:
	Save.profile = _real_profile
	Save._load()
	Game.quit_exits = true


func before_test() -> void:
	for p in Audio._pool:
		p.stop()
	Audio.reset_caps()
	Audio.synth_missing = false
	Save.profile = "test_audio_lane2"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = IDLE.duplicate()


func after_test() -> void:
	Audio.synth_missing = true
	Audio.engine_stop(97)
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Save.wipe()
	Game._set_state(Game.State.LOBBY)
	Audio.music_state(&"up", 0, false, 0.01)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Stops every SFX voice (a snore rings for ~2 s; its one-voice cap would hold the next back).
func _hush() -> void:
	for p in Audio._pool:
		p.stop()


## When `cue` last started (Audio's clock), -100 if never.
func _started(cue: String) -> float:
	return float(Audio._last_start.get(Audio.resolve_name(cue), -100.0))


func _hill() -> HillGame:
	var g := HillGame.new()
	g.start_players = [P1]
	_game = g
	get_tree().root.add_child(g)
	return g


func _join(g: HillGame) -> HillPlayer:
	Players.join_virtual(P1)
	var node := g.player_node(P1)
	if node == null:
		node = g.wake(P1)
	node.intent_source = func() -> Dictionary: return _intent
	return node


func _ride(g: HillGame, id: StringName, pos: Vector2) -> HillPlayer:
	var node := _join(g)
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	g.park_new(id, pos, HillGame.HILLVILLE)
	g.place_player(P1, HillGame.HILLVILLE, pos)
	node.velocity = Vector2.ZERO
	assert_bool(g.hop_in(node)).is_true()
	return node


func _fake_audio() -> Array:
	var g := FakeGame.new()
	_game = g
	var ha := HillAudio.new()
	ha.game = g
	g.add_child(ha)
	get_tree().root.add_child(g)
	return [g, ha]


## A stand-in player at tile row `row` (global == underground-local here: no underground node).
func _at_row(g: FakeGame, row: int) -> void:
	var n := Node2D.new()
	g.add_child(n)
	n.global_position = Vector2(100.0 * 16.0, row * 16.0 + 4.0)
	g.players[P1] = n
	g.director.scenes[P1] = &"underground"


# --- every new cue is a real file -----------------------------------------------------------

func test_every_new_cue_resolves_to_a_real_file() -> void:
	for c: String in NEW_CUES:
		assert_bool(Audio.has_cue(c)).override_failure_message("no file for " + c).is_true()
		var s := Audio.stream_for(c)
		assert_object(s).is_not_null()
		assert_str(s.resource_path).starts_with("res://assets/audio/sfx/")


# --- engines and horns ----------------------------------------------------------------------

func test_every_vehicles_engine_pitch_follows_speed() -> void:
	for v in VEHICLES:
		Audio.engine(97, "engine_%s" % v)
		var last := 0.0
		for k in [0.0, 0.25, 0.5, 0.75, 1.0]:
			Audio.engine_speed(97, k)
			var pitch := Audio.engine_pitch(97)
			assert_float(pitch).override_failure_message("%s at %.2f" % [v, k]).is_greater(last)
			last = pitch
		assert_float(last).is_equal_approx(Audio.ENGINE_PITCH.y, 0.001)
		Audio.engine_stop(97)
	assert_int(Audio.engine_count()).is_equal(0)


func test_the_horn_plays_once_per_press_and_is_that_vehicles_horn() -> void:
	var g := _hill()
	var node := _ride(g, &"dump_truck", Vector2(Hillville.SHAFT_X - 600.0, 0))
	await _physics(3)
	var honks := [0]
	node.honked.connect(func() -> void: honks[0] += 1)
	var before := _started("dump_truck_horn")
	_intent = {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": true}
	await _physics(2)
	var first := _started("dump_truck_horn")
	assert_float(first).is_greater(before)
	await _physics(40)       # held: no repeats
	assert_int(honks[0]).is_equal(1)
	assert_float(_started("dump_truck_horn")).is_equal(first)
	assert_float(_started("horn")).is_equal(-100.0)    # never the generic fallback in a vehicle
	_intent = IDLE.duplicate()
	await _physics(15)
	_intent = {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": true}
	await _physics(2)
	assert_int(honks[0]).is_equal(2)
	assert_float(_started("dump_truck_horn")).is_greater(first)


# --- scoop ----------------------------------------------------------------------------------

func test_a_vehicle_bucket_scoop_plays_scoop() -> void:
	var g := _hill()
	var hv := g.hillville
	var c := -1
	for i in range(10, Hillville.COLS - 10):
		if hv.scrub_at(i) > 0 and absf(i * 16.0 - Hillville.SHAFT_X) > 200.0:
			c = i
			break
	assert_int(c).is_greater(0)
	var node := _ride(g, &"front_loader", Vector2(c * 16.0 + 4.0, 0))
	node.facing = 1
	await _physics(2)
	Audio.reset_caps()
	assert_bool(node.dig_now(Vector2.RIGHT)).is_true()
	assert_float(_started("scoop")).is_greater(-100.0)


# --- the Dragon's snore (W-17) --------------------------------------------------------------

func test_hill_audio_no_longer_shakes_the_camera_itself() -> void:
	var ha := HillAudio.new()
	assert_bool(ha.has_method("_shake")).is_false()
	assert_bool("shake_left" in ha).is_false()
	ha.free()


func test_snore_plays_on_dragon_snored_louder_by_depth() -> void:
	var pair := _fake_audio()
	var g: FakeGame = pair[0]
	var ha: HillAudio = pair[1]
	_at_row(g, HillGenerator.CAVERN.position.y + 10)      # the Bottom, in her cavern
	ha._on_dragon_snored(1.0)
	assert_int(ha.snores_played).is_equal(1)
	assert_float(ha.last_snore_db).is_equal_approx(0.0, 0.01)
	# A second snore inside the cue's cap is held back (one snore at a time).
	Audio.advance(0.5)
	ha._on_dragon_snored(1.0)
	assert_int(ha.snores_played).is_equal(1)
	# Just inside her reach above the cavern: her loudness is small, the layer's is the floor.
	Audio.advance(2.0)
	_hush()
	_at_row(g, HillGenerator.CAVERN.position.y - 10)      # Crystal
	ha._on_dragon_snored(0.1)
	assert_int(ha.snores_played).is_equal(2)
	assert_float(ha.last_snore_db).is_equal_approx(linear_to_db(ha.snore_volume(4)), 0.01)
	assert_float(ha.last_snore_db).is_less(-1.0)


func test_distant_snore_runs_out_of_her_reach_and_stands_down_inside_it() -> void:
	var pair := _fake_audio()
	var g: FakeGame = pair[0]
	var ha: HillAudio = pair[1]
	var dbs := []
	for row in [50, 100, 160]:            # Clay, Stone, Ice: all out of her reach
		Audio.advance(2.0)
		_hush()
		_at_row(g, row)
		assert_bool(ha.in_dragon_reach(g.players[P1].global_position)).is_false()
		ha._snore(g.players, HillAudio.SNORE_EVERY + 0.01)
		dbs.append(ha.last_snore_db)
	assert_int(ha.snores_played).is_equal(3)
	assert_float(dbs[1]).is_greater(dbs[0])
	assert_float(dbs[2]).is_greater(dbs[1])
	# Topsoil: silent. In her reach: our clock stands down (hers owns it, and the reveal is quiet).
	Audio.advance(2.0)
	_hush()
	_at_row(g, 10)
	ha._snore(g.players, HillAudio.SNORE_EVERY + 0.01)
	_at_row(g, HillGenerator.CAVERN.position.y + 5)
	assert_bool(ha.in_dragon_reach(g.players[P1].global_position)).is_true()
	Audio.advance(2.0)
	_hush()
	ha._snore(g.players, HillAudio.SNORE_EVERY + 0.01)
	assert_int(ha.snores_played).is_equal(3)


func test_in_the_game_her_snore_reaches_the_cavern() -> void:
	var g := _hill()
	_join(g)
	await _physics(2)
	var ha: HillAudio = g.find_child("HillAudio", true, false)
	assert_object(ha).is_not_null()
	var u := g.underground
	var r := u.residents
	var feet := Vector2(r.dragon.position.x - UndergroundResidents.REVEAL_NEAR - 40.0, HillGenerator.CAVERN.end.y * 16.0 - 2.0)
	g.place_player(P1, HillGame.UNDERGROUND, feet)
	var heard := [0]
	r.dragon_snored.connect(func(_k: float) -> void: heard[0] += 1)
	await _physics(int(UndergroundResidents.SNORE_EVERY * 60.0) + 30)
	assert_int(heard[0]).is_greater_equal(1)
	assert_int(ha.snores_played).is_greater_equal(1)
	assert_float(ha.last_snore_db).is_equal_approx(0.0, 0.01)
	assert_bool(g.story.dragon_met()).is_false()


# --- lighthouse_on (B-07) -------------------------------------------------------------------

func test_placing_a_lighthouse_plays_lighthouse_on_and_a_barn_does_not() -> void:
	_fake_audio()
	Events.building_placed.emit(&"barn", Vector2i(3, 0))
	await get_tree().create_timer(HillAudio.LIGHTHOUSE_DELAY + 0.2).timeout
	assert_float(_started("lighthouse_on")).is_equal(-100.0)
	Events.building_placed.emit(&"lighthouse", Vector2i(9, 0))
	await get_tree().create_timer(HillAudio.LIGHTHOUSE_DELAY + 0.2).timeout
	assert_float(_started("lighthouse_on")).is_greater(-100.0)


# --- caps -----------------------------------------------------------------------------------

func test_new_rate_caps_hold() -> void:
	assert_bool(Audio.play("lighthouse_on")).is_true()
	assert_bool(Audio.play("lighthouse_on")).is_false()
	Audio.advance(1.1)
	if Audio.playing_count("lighthouse_on") > 0:
		assert_bool(Audio.play("lighthouse_on")).is_false()   # still ringing: one voice at a time
	_hush()
	assert_bool(Audio.play("lighthouse_on")).is_true()
	assert_bool(Audio.play("scoop")).is_true()
	assert_bool(Audio.play("scoop")).is_false()
	assert_bool(Audio.play("dump_truck_horn")).is_true()
	assert_bool(Audio.play("dump_truck_horn")).is_false()
	for i in 200:
		Audio.advance(0.11)
		Audio.play("scoop")
		Audio.play("lighthouse_on")
		assert_int(Audio.playing_count("scoop")).is_less_equal(int(Audio.cap_of("scoop")[1]))
		assert_int(Audio.playing_count("lighthouse_on")).is_less_equal(1)
