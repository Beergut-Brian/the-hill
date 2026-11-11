## Gap-close lane (2026-11-10): the Workshop (B-06: bigger shovel, quicker digging, faster vehicles,
## hammering and sparks, the upgrade pop), exhaust puffs (H-11) and the picked characters speaking
## with their library voices (P-06, A-15). Own settings, picks and save profile; the fixture roster
## (tests/fixtures/roster_voice_pip.json), never the real roster's contents.
class_name TestGapClose
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const FIXTURE := "res://tests/fixtures/roster_voice_pip.json"
const PICKS := "user://test_picks_gap_close.json"

var _game: HillGame
var _real := {}


func before() -> void:
	_real = {"profile": Save.profile, "settings": Save.settings_path, "data": Roster.data_path, "picks": Roster.picks_path}
	Save.settings_path = "user://test_settings_gap_close.json"
	Save.reload_settings()
	Game.quit_exits = false


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real.settings
	Save.reload_settings()
	Save.flush()
	Save.profile = _real.profile
	Save._load()
	Roster.data_path = _real.data
	Roster.picks_path = _real.picks
	Roster.reload()
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Game.quit_exits = true


func before_test() -> void:
	Save.profile = "test_gap_close"
	Save.wipe()
	Roster.data_path = FIXTURE
	Roster.picks_path = PICKS
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Roster.reload()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Audio.reset_caps()
	Game._set_state(Game.State.PLAYING)


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _make() -> HillGame:
	_game = HillGame.new()
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	# PT10-4: these cases check what a bite takes, not how many hits (test_dig_progression).
	_game.underground.dig_feel.tuning = DigTuning.instant()
	return _game


func _join(p: int, intent: Dictionary = IDLE) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return intent
	return node


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


# --- B-06 Workshop -------------------------------------------------------------------------------

func test_the_workshop_is_a_book_card_for_fifteen_stone() -> void:
	var d := Progress.building_data(&"workshop")
	assert_object(d).is_not_null()
	assert_dict(d.cost).is_equal({&"stone": 15})
	assert_str(String(d.effect)).is_equal("dig_power")
	assert_bool(d.needs_vehicle == &"" and d.needs_treasure == &"").is_true()
	assert_bool(SpriteArt.has("buildings/workshop.png")).is_true()
	_make()
	var ids: Array = _game.build.book_rows().map(func(r: BuildingData) -> StringName: return r.id)
	assert_array(ids).contains([&"workshop"])
	# Before the Lighthouse: Stone comes before Crystal.
	assert_int(BuildController.ORDER.find(&"workshop")).is_less(BuildController.ORDER.find(&"lighthouse"))


func test_tool_level_counts_workshops_up_to_the_cap() -> void:
	assert_int(Progress.tool_level()).is_equal(0)
	Progress.add_building(&"barn", Vector2i(30, 0))
	assert_int(Progress.tool_level()).is_equal(0)
	Progress.add_building(&"workshop", Vector2i(36, 0))
	assert_int(Progress.tool_level()).is_equal(1)
	for i in 5:
		Progress.add_building(&"workshop", Vector2i(40 + i * 2, 0))
	assert_int(Progress.tool_level()).is_equal(Progress.TOOL_MAX)


func test_the_bigger_shovel_bites_one_cell_deeper_on_foot() -> void:
	_make()
	var p := _join(P1)
	var land := _game.underground.landing(0) + Vector2(-64, 0)
	_game.place_player(P1, &"underground", land)
	var w := _game.underground.world
	var under := w.shape.cell_at(land + Vector2(0, 4))
	var deeper := under + Vector2i(0, 1)
	assert_bool(w.is_solid(under) and w.is_solid(deeper)).is_true()
	assert_bool(p.has_big_shovel()).is_false()
	var before := p.dig_cells(Vector2i(0, 1)).size()
	# Without a Workshop: one bite takes the cell underfoot, and the next from here finds only air.
	assert_bool(p.dig_now(Vector2.DOWN)).is_true()
	assert_bool(w.is_solid(under)).is_false()
	assert_bool(w.is_solid(deeper)).is_true()
	assert_bool(p.dig_now(Vector2.DOWN)).is_false()
	# With one: the shovel reaches a cell further.
	Progress.add_building(&"workshop", Vector2i(36, 0))
	assert_bool(p.has_big_shovel()).is_true()
	assert_int(p.dig_cells(Vector2i(0, 1)).size()).is_equal(before + 1)
	assert_bool(p.dig_now(Vector2.DOWN)).is_true()
	assert_bool(w.is_solid(deeper)).is_false()
	# Driving: the vehicle's own bucket shape, no extra cell.
	p.drive(Progress.vehicle_data(&"front_loader"))
	assert_bool(p.has_big_shovel()).is_false()


func test_a_workshop_digs_quicker_and_drives_faster_capped() -> void:
	_make()
	var p := _join(P1)
	assert_float(p.dig_every()).is_equal_approx(HillPlayer.DIG_EVERY, 0.0001)
	assert_float(p.drive_scale()).is_equal(1.0)
	Progress.add_building(&"workshop", Vector2i(36, 0))
	assert_float(p.dig_every()).is_equal_approx(HillPlayer.DIG_EVERY / (1.0 + HillPlayer.TOOL_DIG), 0.0001)
	assert_float(p.drive_scale()).is_equal_approx(1.0 + HillPlayer.TOOL_DRIVE, 0.0001)
	for i in 4:
		Progress.add_building(&"workshop", Vector2i(40 + i * 2, 0))
	assert_float(p.drive_scale()).is_equal_approx(1.0 + HillPlayer.TOOL_DRIVE * Progress.TOOL_MAX, 0.0001)
	# A driven vehicle really goes faster on flat ground up top.
	p.drive(Progress.vehicle_data(&"front_loader"))
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X + 300.0, 0))
	p.intent_source = func() -> Dictionary: return {"move": Vector2.RIGHT, "dig": false, "jump": false, "book": false, "horn": false}
	await _physics(20)
	assert_float(absf(p.velocity.x)).is_greater(p.vehicle.speed * 1.2)


func test_building_a_workshop_pops_the_shovel_over_every_player_with_one_sound() -> void:
	_make()
	var a := _join(P1)
	var b := _join(P2)
	await _physics(2)
	assert_float(a.tool_pop).is_equal(0.0)
	Progress.add_building(&"barn", Vector2i(30, 0))
	assert_float(a.tool_pop).is_equal(0.0)
	var cue := Audio.resolve_name("tool_upgrade")
	var playing := Audio.playing_count(cue)
	Progress.add_building(&"workshop", Vector2i(36, 0))
	assert_float(a.tool_pop).is_equal(1.0)
	assert_float(b.tool_pop).is_equal(1.0)
	assert_str(cue).is_not_equal("tool_upgrade")
	assert_int(Audio.playing_count(cue)).is_equal(playing + 1)    # one sound for both players
	await _physics(30)
	assert_float(a.tool_pop).is_greater(0.0)
	assert_float(a.tool_pop).is_less(1.0)


func test_the_workshop_hammers_with_sparks_and_clangs_only_near_a_player() -> void:
	_make()
	var p := _join(P1)
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X + 1500.0, 0))
	Progress.add_building(&"workshop", Vector2i(36, 0))
	_game.build.rebuild()
	var b := _game.build.building_node(0)
	assert_object(b.fx).is_not_null()
	var fx := b.fx
	# Far away: the hammer strikes and sparks fly, but no clang.
	p.position.x = b.position.x + 48.0 + WorkshopFx.HEAR + 200.0
	fx.step(WorkshopFx.BEAT)
	assert_int(fx.strikes).is_equal(1)
	assert_int(fx.sparks_alive()).is_greater(0)
	assert_int(fx.clangs).is_equal(0)
	# The hammer is down on the strike and up between.
	fx.step(0.25)
	assert_float(fx.hammer_lift()).is_greater(0.5)
	# Near: every strike clangs.
	p.position.x = b.position.x + 60.0
	fx.step(WorkshopFx.BEAT)
	assert_int(fx.strikes).is_equal(2)
	assert_int(fx.clangs).is_equal(1)
	assert_str(Audio.resolve_name("workshop_hammer")).is_not_equal("workshop_hammer")
	# The sparks burn out.
	fx.step(0.6)
	fx.step(0.6)
	assert_int(fx.sparks_alive()).is_equal(0)


func test_a_ghost_workshop_does_not_hammer() -> void:
	var g := Building.make(Progress.building_data(&"workshop"))
	g.ghost = true
	add_child(g)
	g.fx.step(WorkshopFx.BEAT * 2.0)
	assert_int(g.fx.strikes).is_equal(0)
	g.free()


# --- B-03 House: the sleeper moves in at night ---------------------------------------------------

func test_by_night_the_absent_p2_sleeps_in_the_house_and_by_day_in_the_bucket() -> void:
	var was := TimeOfDay.time
	var froze := TimeOfDay.frozen
	TimeOfDay.frozen = true
	TimeOfDay.set_time(0.3)
	_make()
	_join(P1)
	await _physics(2)
	assert_int(_game.sleeper_in(HillGame.LOADER)).is_equal(P2)
	# No House: the bucket even at night.
	TimeOfDay.set_time(0.8)
	assert_float(Building.current_lights()).is_greater_equal(HillGame.HOUSE_NIGHT)
	await _physics(40)
	assert_int(_game.house_sleeper()).is_equal(-1)
	assert_int(_game.sleeper_in(HillGame.LOADER)).is_equal(P2)
	# A House: by night P2 sleeps there (Zs from its window), the bucket is empty.
	Progress.add_building(&"house", Vector2i(36, 0))
	_game.build.rebuild()
	await _physics(40)
	var house := _game.house_node()
	assert_object(house).is_not_null()
	assert_int(house.sleeper).is_equal(P2)
	assert_int((_game.vehicles[HillGame.LOADER] as Vehicle).sleeper).is_equal(-1)
	# Dawn: back to the bucket.
	TimeOfDay.set_time(0.3)
	await _physics(40)
	assert_int(house.sleeper).is_equal(-1)
	assert_int((_game.vehicles[HillGame.LOADER] as Vehicle).sleeper).is_equal(P2)
	TimeOfDay.set_time(was)
	TimeOfDay.frozen = froze


func test_waking_at_night_comes_out_of_the_house_door() -> void:
	var was := TimeOfDay.time
	var froze := TimeOfDay.frozen
	TimeOfDay.frozen = true
	TimeOfDay.set_time(0.8)
	_make()
	_join(P1)
	Progress.add_building(&"house", Vector2i(36, 0))
	_game.build.rebuild()
	await _physics(40)
	var house := _game.house_node()
	assert_int(house.sleeper).is_equal(P2)
	var p2 := _join(P2)
	assert_float(p2.position.distance_to(house.door_position())).is_less(8.0)
	assert_int(house.sleeper).is_equal(-1)
	assert_int((_game.vehicles[HillGame.LOADER] as Vehicle).sleeper).is_equal(-1)
	TimeOfDay.set_time(was)
	TimeOfDay.frozen = froze


# --- H-11 exhaust puffs ----------------------------------------------------------------------------

func test_exhaust_puffs_quicker_while_rolling_from_each_vehicles_stack() -> void:
	assert_float(Vehicle.exhaust_rate(true)).is_greater(Vehicle.exhaust_rate(false) * 2.0)
	for id in [&"front_loader", &"excavator", &"dump_truck", &"drill_rig"]:
		var file := "vehicles/%s.png" % id
		var fs := Vector2(SpriteArt.frame_size(file))
		var piv := SpriteArt.pivot(file)
		var right := Vehicle.exhaust_point(id, fs, piv, 1)
		var left := Vehicle.exhaust_point(id, fs, piv, -1)
		assert_float(left.x).is_equal(-right.x)
		# Up on the body and inside the sprite's width.
		assert_float(right.y).is_less(-fs.y * 0.5)
		assert_float(absf(right.x)).is_less(fs.x * 0.5)


# --- P-06 / A-15 library voices ------------------------------------------------------------------

func test_a_library_voice_pack_says_its_lines_for_game_cues() -> void:
	# Pip's pack (a library pack) has no "rock_name" line: the library's "cheer" stands in.
	var s := Audio.bark_stream("pip", "rock_name")
	assert_object(s).is_not_null()
	assert_str(s.resource_path).starts_with("res://assets/characters/boxbot/voice/cheer")
	assert_str(Audio.bark_stream("pip", "found").resource_path).contains("/voice/win")
	assert_str(Audio.bark_stream("pip", "narrate").resource_path).contains("/voice/ready")
	assert_bool(Audio.bark_is_real("pip", "found")).is_true()
	# No pack (Jeff in the fixture, voice ""): the placeholder, never a library line. Jeff's real pack
	# ships in assets/ since openjar-characters v0.5.3, so point the pack folder at an empty path here.
	var real_root: String = Audio.pack_root
	Audio.pack_root = "res://tests/fixtures/no_voice_packs/"
	assert_bool(Audio.bark_is_real("jeff", "rock_name")).is_false()
	Audio.pack_root = real_root


func test_the_finder_cheers_in_their_own_voice_and_a_voiceless_pick_stays_quiet() -> void:
	assert_bool(Roster.set_pick(P1, "pip")).is_true()
	_make()
	_join(P1)
	_join(P2)
	await _physics(2)
	var v: VoiceLines = _game.get_node("VoiceLines")
	assert_object(v).is_not_null()
	Events.treasure_found.emit(&"buried_car", P2)      # Chuck: no pack
	assert_array(v.queue).is_empty()
	Events.treasure_found.emit(&"buried_car", P1)
	assert_int(v.queue.size()).is_equal(1)
	assert_str(String(v.queue[0].who)).is_equal("pip")
	v.step(VoiceLines.AFTER + 0.05)
	assert_array(v.said).contains([["pip", "found"]])


func test_a_workshop_gets_a_cheer_from_each_voiced_player() -> void:
	assert_bool(Roster.set_pick(P2, "pip")).is_true()
	_make()
	_join(P1)
	_join(P2)
	await _physics(2)
	var v: VoiceLines = _game.get_node("VoiceLines")
	Progress.add_building(&"workshop", Vector2i(36, 0))
	assert_int(v.queue.size()).is_equal(1)              # P1 is Jeff (no pack)
	assert_str(String(v.queue[0].cue)).is_equal("upgrade")
	# Ordinary buildings: a cheer now and then, not on every one.
	Progress.add_building(&"barn", Vector2i(30, 0))
	Progress.add_building(&"barn", Vector2i(32, 0))
	assert_int(v.queue.size()).is_equal(2)
