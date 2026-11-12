## R-11 proof (Proof lane, 2026-11-10): once the Mole is in town he hops on a parked, empty vehicle
## up top near a player and honks its horn twice, at most every 50 s (TownResidents.HONK_EVERY), and
## never with a player in the seat (driving it, or asleep in the bucket) or with nobody near to see.
## Simulated physics time; the 50 s gap is counted frame by frame, not by poking the cooldown.
class_name TestMoleHonk
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
## The empty vehicle: the Excavator. In a solo game the absent P2 sleeps in the Front Loader's
## bucket (HillGame._update_sleeper), so the loader is occupied and never honked; that is its own
## case. (The Excavator's horn, 0.55 s, ends before the second honk at +0.65 s; the longer horns
## are capped to one voice and drop it: see handoff/REPORT.md, proof-gaps-1.)
const TRUCK := &"excavator"
const LOADER := &"front_loader"
## Parked right of the Mole's waiting spot, with P1 beside it but out of his talk range
## (TALK_NEAR), so his arrival bubbles never hold the gag back.
const PARK_X := TownResidents.MOLE_WAIT_X + 320.0

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("mole_honk")
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_mole_honk.json"
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
	SuiteSandbox.leave()


func before_test() -> void:
	Save.profile = "test_mole_honk"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = {P1: IDLE.duplicate()}


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


## Frame counts in this suite are 60 Hz frames (1 s = 60): scaled to the physics tick rate, so a
## budget is the same physics time at 30 or 120 Hz.
func _ticks(n60: int) -> int:
	return int(ceil(n60 * Engine.physics_ticks_per_second / 60.0))


func _physics(n: int) -> void:
	for i in _ticks(n):
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	max_frames = _ticks(max_frames)
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


## A game with P1 up top beside an empty parked vehicle and the Mole waiting in town (ARRIVED).
## Every other parked vehicle is sent far away so only this one can be the honk target.
func _setup(id: StringName = TRUCK) -> Vehicle:
	_game = HillGame.new()
	_game.load_saved = false   # a bare game: no save, no story intro over the frame
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	Players.join_virtual(P1)
	var node := _game.player_node(P1)
	if node == null:
		node = _game.wake(P1)
	node.intent_source = func() -> Dictionary: return _intent[P1]
	await _physics(2)
	for other in _game.vehicles:
		(_game.vehicles[other] as Node2D).position.x = -20000.0
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	var v: Vehicle = _game.vehicles.get(id)
	if v == null or not v.is_inside_tree():
		v = _game.park_new(id, Vector2(PARK_X, 0))
	v.position = Vector2(PARK_X, 0)
	_stand_at(PARK_X - 60.0)
	var s := _game.story.state(&"mole")
	s.encounters = s.encounters_to_arrive
	s.phase = ResidentState.Phase.ARRIVED
	_game.story.changed.emit()
	await _until(func() -> bool: return _game.town.mole_mode() == &"wait", 120)
	assert_str(String(_game.town.mole_mode())).is_equal("wait")
	# His arrival bubbles play first (the sleeping P2 by the shaft is in his talk range); let them end.
	await _until(func() -> bool: return not _game.town.saying(&"mole").is_empty(), 30)
	await _until(func() -> bool: return _game.town.saying(&"mole").is_empty(), 900)
	assert_array(_game.town.saying(&"mole")).is_empty()
	_game.town._mole.cd_pond = 9999.0   # the pond gag is far away anyway; keep it out of the count
	return v


func _stand_at(x: float) -> void:
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(x, 0))
	_game.player_node(P1).velocity = Vector2.ZERO


func _horn_cue(v: Vehicle) -> String:
	var d := v.data
	return Audio.resolve_name(String(d.sounds.get(&"horn", "honk")) if d != null and d.sounds.has(&"horn") else "honk")


func test_the_mole_honks_an_empty_parked_vehicle_near_a_player_and_sits_in_it() -> void:
	var v := await _setup()
	# Count every honk through the Mole's own signal, hooked up before the cooldown is cleared so
	# none can slip past: each emit is one horn press, and played says Audio took the cue.
	# Audio caps a horn to one voice, and voices run on the audio thread's real-time clock, not
	# physics time: a stalled CI box can still be sounding the first horn at the second press, so
	# Audio drops it (honks = 1 on v0.2.0-dev.1). That drop is Audio's cap, not the gag, so each
	# press records whether a horn voice was still sounding when Audio refused it.
	var horn := _horn_cue(v)
	var honks: Array[Vehicle] = []
	var played: Array[bool] = []
	var held: Array[bool] = []   # refused while the cap's voice was still playing
	var at_frame: Array[int] = []
	var on_honk := func(at: Vehicle, ok: bool) -> void:
		honks.append(at)
		played.append(ok)
		held.append(not ok and Audio.playing_count(horn) >= int(Audio.cap_of(horn)[1]))
		at_frame.append(Engine.get_physics_frames())
	_game.town.honked.connect(on_honk)
	_game.town._mole.cd_honk = 0.0
	var waited := await _until(func() -> bool: return _game.town.mole_mode() == &"honk", 60)
	assert_int(waited).is_less(_ticks(60))
	assert_object(_game.town._mole.get("vehicle")).is_same(v)
	# Ride the gag through: he sits on the seat and the horn sounds twice.
	var sat := false
	var frames := 0
	var shot := OS.get_environment("PROOF_FRAME_DIR")   # set by the Proof lane under godot-render
	while _game.town.mole_mode() != &"wait" and frames < _ticks(400):
		await get_tree().physics_frame
		frames += 1
		if _game.town.mole_mode() == &"honk" and _game.town.mole.visible \
				and _game.town.mole.position.distance_to(v.position + Vector2(-4, -30)) < 4.0:
			if not sat and shot != "" and DisplayServer.get_name() != "headless":
				await _physics(20)   # settled on the seat, between the two honks
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(shot.path_join("mole_honk.png"))
			sat = true
	_game.town.honked.disconnect(on_honk)
	assert_bool(sat).override_failure_message("the Mole never sat on the vehicle's seat").is_true()
	assert_int(honks.size()).override_failure_message("honks: %d, want 2" % honks.size()).is_equal(2)
	for at in honks:
		assert_object(at).is_same(v)
	if honks.size() != 2:
		return
	assert_bool(played[0]).override_failure_message("the first honk was not heard").is_true()
	# In real time the first horn has ended by the second press, so play hears both; here the
	# second may only be refused while that first voice is still sounding on the audio clock.
	var gap := float(at_frame[1] - at_frame[0]) / Engine.physics_ticks_per_second
	var horn_len := Audio.stream_for(horn).get_length() / 0.96   # slowest pitch Audio.play picks
	assert_float(horn_len).override_failure_message(
		"the horn (%.2f s) outlasts the gap between honks (%.2f s)" % [horn_len, gap]).is_less(gap)
	assert_bool(played[1] or held[1]).override_failure_message(
		"the second honk was refused with no horn voice still sounding").is_true()
	assert_str(String(_game.town.mole_mode())).is_equal("wait")


func test_the_honk_comes_at_most_every_50_seconds() -> void:
	var v := await _setup()
	_game.town._mole.cd_honk = 0.0
	await _until(func() -> bool: return _game.town.mole_mode() == &"honk", 60)
	assert_str(String(_game.town.mole_mode())).is_equal("honk")
	# Count physics time until the next honk starts (the vehicle and player stay put all along).
	var step := 1.0 / Engine.physics_ticks_per_second
	var t := 0.0
	var left_honk := false
	var max_frames := int(60.0 / step)
	var n := 0
	while n < max_frames:
		await get_tree().physics_frame
		n += 1
		t += step
		var m: StringName = _game.town.mole_mode()
		if m != &"honk":
			left_honk = true
		elif left_honk:
			break
	assert_bool(left_honk).is_true()
	assert_str(String(_game.town.mole_mode())).override_failure_message(
		"no second honk within 60 s of the first").is_equal("honk")
	assert_float(t).is_greater_equal(TownResidents.HONK_EVERY - 0.1)
	assert_float(t).is_less(TownResidents.HONK_EVERY + 2.0)
	assert_object(_game.town._mole.get("vehicle")).is_same(v)


func test_no_honk_with_a_player_in_the_seat() -> void:
	var v := await _setup()
	var node := _game.player_node(P1)
	_stand_at(PARK_X - 10.0)
	await _physics(1)
	assert_bool(_game.hop_in(node)).is_true()
	assert_bool(v.is_inside_tree()).is_false()
	_game.town._mole.cd_honk = 0.0
	await _physics(180)
	assert_str(String(_game.town.mole_mode())).is_equal("wait")
	assert_float(float(_game.town._mole.cd_honk)).is_equal(0.0)   # ready, but nothing to honk


func test_no_honk_with_a_player_asleep_in_the_bucket() -> void:
	# Solo game: P2 has not dropped in and sleeps in the Front Loader's bucket.
	var v := await _setup(LOADER)
	assert_int(v.sleeper).is_greater_equal(0)
	_game.town._mole.cd_honk = 0.0
	await _physics(180)
	assert_str(String(_game.town.mole_mode())).is_equal("wait")


func test_no_honk_with_nobody_near_to_see_it() -> void:
	var v := await _setup()
	_stand_at(PARK_X + TownResidents.HONK_NEAR + 200.0)
	_game.town._mole.cd_honk = 0.0
	await _physics(180)
	assert_str(String(_game.town.mole_mode())).is_equal("wait")
	# Walk back over: now he goes.
	_stand_at(v.position.x - 60.0)
	await _until(func() -> bool: return _game.town.mole_mode() == &"honk", 60)
	assert_str(String(_game.town.mole_mode())).is_equal("honk")
