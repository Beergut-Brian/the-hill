## Story lane (GAME.md playtest 2026-11-10 items 1-3): the reusable CutscenePlayer and its data,
## the intro once per save (and from the pause menu), the Mole's rebuilt arc (hints, theft, no
## shovel, wake up top, shovel back; spaced out; the third brings him up) and that a skip never
## leaves the game half-way. Simulated physics time on a real HillGame, scenes run fast (speed).
## Own profile, settings and picks files and the fixture roster (SuiteSandbox).
class_name TestStoryCutscenes
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const FAST := 12.0

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("story_cutscenes")
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_story.json"
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
	Save.profile = "test_story"
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


func _make(load_saved := false) -> HillGame:
	_game = HillGame.new()
	_game.load_saved = load_saved
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	_game.story_scenes.player.speed = FAST
	_game.story_scenes.no_shovel_secs = 0.3
	return _game


func _join(p: int) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return _intent[p]
	return node


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hs() -> HillStory:
	return _game.story_scenes


func _stage(room: Rect2i, cell: Vector2i) -> HillPlayer:
	var w := _game.underground.world
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.set_tile(Vector2i(x, y), 0)
	var p := _game.player_node(P1)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2((cell.x + 0.5) * 16.0, (cell.y + 1) * 16.0 - 1.0))
	p.velocity = Vector2.ZERO
	return p


# --- data --------------------------------------------------------------------------------------

func test_every_scene_loads_and_every_line_it_speaks_exists() -> void:
	var kinds := ["camera", "camera_back", "spawn", "walk", "hop", "face", "show", "hide", "line", "bubble",
			"item", "hold", "drop", "sound", "fade", "bars", "call", "wait"]
	var fills := {"{stem}": ["mole", "foreman", "caveman", "dragon"], "{line}": ["unlock_dump_truck", "unlock_crane", "unlock_drill_rig", "unlock_any"],
			"{mole_line}": ["mole_return_last", "mole_relieved"]}
	var ids := ["intro", "mole_theft", "mole_return", "crew_freed", "caveman_thaw", "dragon_reveal", "dragon_wake", "arrive", "movein", "vehicle_unlock"]
	for id in ids:
		var d := CutscenePlayer.load_scene(StringName(id))
		assert_bool(d.is_empty()).override_failure_message("no scene %s" % id).is_false()
		for s: Dictionary in d.steps:
			assert_bool(kinds.has(String(s.get("do", "")))).override_failure_message("%s: step %s" % [id, s]).is_true()
			if s.get("do") != "line":
				continue
			var l := String(s.line)
			var options := [l]
			for key: String in fills:
				if l.contains(key):
					options = []
					for v: String in fills[key]:
						options.append(l.replace(key, v))
			for o: String in options:
				for ch in ["jeff", "chuck", "zorp"]:
					assert_bool(CutscenePlayer.line(o, ch).is_empty()).override_failure_message("%s: no line %s for %s" % [id, o, ch]).is_false()


func test_every_line_is_short_and_has_a_voice_direction() -> void:
	var all := CutscenePlayer.lines()
	assert_int(all.size()).is_greater(30)
	for id: String in all:
		var l: Dictionary = all[id]
		assert_int(String(l.text).split(" ").size()).override_failure_message(id).is_less_equal(12)
		assert_str(String(l.get("delivery", ""))).is_not_empty()
		assert_bool(String(l.get("fallback", "")).begins_with("bark:") or String(l.get("fallback", "")).begins_with("sfx:")).is_true()


# --- intro -------------------------------------------------------------------------------------

func test_the_intro_plays_once_on_a_new_save_locks_input_and_is_saved() -> void:
	_make(true)
	var p := _join(P1)
	await _until(func() -> bool: return _hs().is_playing(), 120)
	assert_str(String(_hs().player.current())).is_equal("intro")
	await _physics(2)
	assert_bool(p.locked).is_true()
	await _until(func() -> bool: return not _hs().is_playing(), 2400)
	assert_bool(_hs().is_playing()).is_false()
	assert_bool(p.locked).is_false()
	assert_bool(_hs().intro_seen()).is_true()
	# Mayor Pip and Foreman Dot were temporary actors: gone with the scene.
	await _physics(2)
	assert_object(_game.hillville.find_child("Cut_pip", true, false)).is_null()
	# The save remembers it: a reload does not play it again.
	_game.save.save_now()
	_game.free()
	Players.reset()
	_make(true)
	_join(P1)
	await _physics(90)
	assert_bool(_hs().played.has(&"intro")).is_false()


## Gap-close-8: the depth strips and backpacks fade out while a scene plays (the letterbox bars
## cut them in half otherwise) and come back when it ends.
func test_the_hud_fades_out_under_the_bars_and_back_after() -> void:
	_make(true)
	_join(P1)
	var hud := _game.hud as HillHud
	assert_float(hud.modulate.a).is_equal(1.0)
	await _until(func() -> bool: return _hs().is_playing(), 120)
	assert_bool(hud.in_scene()).is_true()
	await _until(func() -> bool: return hud.modulate.a == 0.0, 600)
	assert_float(hud.modulate.a).is_equal(0.0)
	await _until(func() -> bool: return not _hs().is_playing(), 2400)
	assert_bool(hud.in_scene()).is_false()
	await _until(func() -> bool: return hud.modulate.a == 1.0, 600)
	assert_float(hud.modulate.a).is_equal(1.0)


func test_a_skips_the_intro_at_once_and_the_pause_menu_replays_it() -> void:
	_make(true)
	var p := _join(P1)
	await _until(func() -> bool: return _hs().is_playing(), 120)
	await _physics(30)
	_hs().player.skip()
	await _physics(2)
	assert_bool(_hs().is_playing()).is_false()
	assert_bool(p.locked).is_false()
	assert_bool(_hs().intro_seen()).is_true()
	get_tree().call_group(&"hill_story", &"replay_intro")
	await _physics(2)
	assert_str(String(_hs().player.current())).is_equal("intro")


# --- the Mole ----------------------------------------------------------------------------------

func test_the_theft_takes_the_shovel_you_cannot_dig_then_you_wake_up_top_with_it() -> void:
	_make()
	var p := _join(P1)
	_stage(Rect2i(56, 14, 4, 2), Vector2i(58, 15))
	await _physics(5)
	assert_bool(_hs().start_theft(P1)).is_true()
	await _until(func() -> bool: return not p.has_shovel, 600)
	assert_bool(p.has_shovel).is_false()
	await _until(func() -> bool: return not _hs().is_playing(), 1200)
	# The no-shovel window: on foot, a dig press digs nothing and says so.
	var w := _game.underground.world
	var target := Vector2i(60, 15)
	assert_bool(w.is_solid(target)).is_true()
	var said := [0]
	p.no_shovel.connect(func() -> void: said[0] += 1)
	_hs().no_shovel_secs = 99.0
	_hs()._no_shovel = {"p": P1, "t": 0.6}
	_intent[P1] = {"move": Vector2(1, 0), "dig": true, "jump": false, "book": false, "horn": false}
	await _physics(20)
	assert_bool(w.is_solid(target)).is_true()
	assert_int(said[0]).is_greater(0)
	_intent[P1] = IDLE.duplicate()
	# Then the return: up top by the shaft, shovel back, one encounter.
	await _until(func() -> bool: return _hs().player.current() == &"mole_return", 600)
	await _until(func() -> bool: return not _hs().is_playing(), 1800)
	assert_str(String(_game.director.scene_of(P1))).is_equal(String(HillGame.HILLVILLE))
	assert_float(absf(p.global_position.x - Hillville.SHAFT_X)).is_less(80.0)
	assert_bool(p.has_shovel).is_true()
	assert_int(_game.story.state(Story.MOLE).encounters).is_equal(1)
	assert_bool(p.locked).is_false()


func test_skipping_both_scenes_still_takes_and_gives_the_shovel_back() -> void:
	_make()
	var p := _join(P1)
	_stage(Rect2i(56, 14, 4, 2), Vector2i(58, 15))
	await _physics(5)
	_hs().start_theft(P1)
	await _physics(3)
	_hs().player.skip()
	assert_bool(p.has_shovel).is_false()
	await _until(func() -> bool: return _hs().player.current() == &"mole_return", 600)
	await _physics(3)
	_hs().player.skip()
	await _physics(2)
	assert_bool(p.has_shovel).is_true()
	assert_bool(p.locked).is_false()
	assert_str(String(_game.director.scene_of(P1))).is_equal(String(HillGame.HILLVILLE))
	assert_int(_game.story.state(Story.MOLE).encounters).is_equal(1)


func test_the_third_return_brings_him_up_without_a_second_arrival_scene() -> void:
	_make()
	var p := _join(P1)
	_game.story.steal_shovel()
	_game.story.steal_shovel()
	_hs().auto = true
	_stage(Rect2i(56, 14, 4, 2), Vector2i(58, 15))
	await _physics(5)
	_hs().start_theft(P1)
	await _until(func() -> bool: return _hs().player.current() == &"mole_return", 2400)
	assert_bool(bool(_hs().player.context().get("last", false))).is_true()
	await _until(func() -> bool: return not _hs().is_playing(), 2400)
	await _physics(10)
	assert_bool(_game.story.arrived(Story.MOLE)).is_true()
	assert_bool(p.has_shovel).is_true()
	assert_bool(_hs().played.has(&"arrive")).is_false()
	# He pops up at his waiting spot by the shaft (the town's tunnel-in).
	await _until(func() -> bool: return _game.town.mole.visible, 600)
	assert_bool(_game.town.mole.visible).is_true()


func test_hints_come_first_in_order_and_the_theft_waits_for_its_gap() -> void:
	_make()
	var p := _join(P1)
	_stage(Rect2i(56, 14, 4, 2), Vector2i(58, 15))
	var arc := _hs().mole
	assert_bool(_game.underground.residents.auto_steal).is_false()
	# Lots of digging but no time: no hint, no theft (tiles alone never bring him).
	arc.state().tiles = 500
	arc._last_digger = P1
	await _physics(30)
	assert_array(arc.shown).is_empty()
	assert_bool(_hs().is_playing()).is_false()
	# Time passes underground: the three hints, in order, then the theft.
	var need: Dictionary = arc.need()
	arc.state().secs = float(need.secs) * 0.31
	await _until(func() -> bool: return arc.shown.size() >= 1, 60)
	assert_array(arc.shown).is_equal([&"wobble"])
	await _until(func() -> bool: return arc.hint.is_empty(), 400)
	arc.state().secs = float(need.secs) * 0.56
	await _until(func() -> bool: return arc.shown.size() >= 2, 60)
	await _until(func() -> bool: return arc.hint.is_empty(), 400)
	arc.state().secs = float(need.secs) * 0.81
	await _until(func() -> bool: return arc.shown.size() >= 3, 60)
	assert_array(arc.shown).is_equal([&"wobble", &"trail", &"shadow"])
	assert_bool(_hs().is_playing()).is_false()
	await _until(func() -> bool: return arc.hint.is_empty(), 400)
	arc.state().secs = float(need.secs)
	await _until(func() -> bool: return _hs().is_playing(), 60)
	assert_str(String(_hs().player.current())).is_equal("mole_theft")
	assert_object(p).is_not_null()


func test_the_second_theft_needs_more_play_and_more_depth_than_the_first() -> void:
	var t: Dictionary = MoleArc.load_tuning()
	var list: Array = t.thefts
	assert_int(list.size()).is_equal(3)
	assert_float(float(list[1].secs)).is_greater(float(list[0].secs))
	assert_int(int(list[1].depth)).is_greater(int(list[0].depth))
	assert_int(int(list[2].depth)).is_greater(int(list[1].depth))
	_make()
	_join(P1)
	_game.story.steal_shovel()
	var arc := _hs().mole
	_stage(Rect2i(56, 14, 4, 2), Vector2i(58, 15))   # row 15: shallower than the second theft's depth
	arc.state().secs = 9999.0
	arc.state().tiles = 9999
	arc.state().hints = 3
	arc._last_digger = P1
	await _physics(30)
	assert_bool(_hs().is_playing()).is_false()


# --- other moments -----------------------------------------------------------------------------

func test_a_vehicle_unlock_plays_its_scene_with_foreman_dot() -> void:
	_make()
	_join(P1)
	_hs().auto = true
	var x: float = _game.player_node(P1).global_position.x
	_game.hillville.vehicle_rolls_out.emit(&"dump_truck", Vector2(x + 140.0, 0.0))
	await _until(func() -> bool: return _hs().is_playing(), 60)
	assert_str(String(_hs().player.current())).is_equal("vehicle_unlock")
	assert_str(String(_hs().player.context().line)).is_equal("unlock_dump_truck")
	await _until(func() -> bool: return not _hs().is_playing(), 1800)
	assert_bool(_game.player_node(P1).locked).is_false()


func test_moments_wait_while_a_scene_plays_and_never_while_a_player_rides() -> void:
	_make()
	var p := _join(P1)
	_hs().auto = true
	p.locked = true          # as the elevator does during a ride
	Events.resident_arrived.emit(Story.CAVEMAN)
	await _physics(5)
	assert_bool(_hs().is_playing()).is_false()
	assert_int(_hs().queue.size()).is_equal(1)
	p.locked = false
	await _until(func() -> bool: return _hs().is_playing(), 60)
	assert_str(String(_hs().player.current())).is_equal("arrive")
	assert_int(_hs().queue.size()).is_equal(0)


func test_an_up_top_scene_waiting_does_not_hold_up_one_below() -> void:
	_make()
	_join(P1)
	_hs().auto = true
	_stage(Rect2i(56, 14, 4, 2), Vector2i(58, 15))
	await _physics(3)
	assert_bool(_game.underground.residents.free_crew()).is_true()
	await _until(func() -> bool: return _hs().is_playing(), 60)
	assert_str(String(_hs().player.current())).is_equal("crew_freed")
	# The Foreman's arrival waits for someone up top.
	await _until(func() -> bool: return not _hs().is_playing(), 1200)
	await _physics(5)
	assert_bool(_hs().played.has(&"arrive")).is_false()
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X - 200.0, 0))
	await _until(func() -> bool: return _hs().is_playing(), 60)
	assert_str(String(_hs().player.current())).is_equal("arrive")


func test_a_bare_test_game_and_the_full_demo_play_nothing_by_themselves() -> void:
	_make()
	_join(P1)
	await _physics(80)
	assert_bool(_hs().auto).is_false()
	assert_array(_hs().played).is_empty()
