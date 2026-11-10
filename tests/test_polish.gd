## Polish lane (2026-11-10), in simulated physics time: Lighthouses light Stone and then one more
## layer each (B-07, W-10, W-22); a cow per Barn (B-02); the gnome crew's saved stamp (C-13, S-09);
## the juice: kicks on big scoops and boulder landings, the Strangestone "?" bubble and the Dragon's
## snore sway (V-07, W-24, W-17), all off with Settings screen shake off.
class_name TestPolish
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_polish.json"
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
	Save.profile = "test_polish"
	Save.wipe()
	Save.set_setting(SettingsPanel.SHAKE, true)
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
	return _game


func _join() -> HillPlayer:
	Players.join_virtual(P1)
	var node := _game.player_node(P1)
	if node == null:
		node = _game.wake(P1)
	node.intent_source = func() -> Dictionary: return _intent[P1]
	return node


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _layer(id: StringName) -> LayerData:
	for l: LayerData in _game.underground.layers():
		if l.id == id:
			return l
	return null


func _index(id: StringName) -> int:
	var ls := _game.underground.layers()
	for i in ls.size():
		if (ls[i] as LayerData).id == id:
			return i
	return -1


func _dark(id: StringName) -> float:
	return _game.underground.world.darkness_at(_layer(id).depth_from + 2)


# --- B-07 / W-10 / W-22: the Lighthouse lights a layer --------------------------------------------

func test_a_lighthouse_lights_stone_and_each_more_lights_the_next_layer_down() -> void:
	_make()
	_join()
	await _physics(2)
	var look := _game.underground.look
	var stone := _layer(&"stone")
	var ice := _layer(&"ice")
	assert_float(_dark(&"stone")).is_equal_approx(stone.darkness, 0.001)
	assert_object(_game.underground.get_node_or_null(NodePath("Beacon%d" % _index(&"stone")))).is_null()
	# One Lighthouse: Stone fades in (not at once), then is lit; Ice stays dark.
	Progress.add_building(&"lighthouse", Vector2i(35, 0))
	await _physics(24)
	var mid := look.lit_amount(_index(&"stone"))
	assert_float(mid).is_less(1.0)
	await _physics(90)
	assert_float(look.lit_amount(_index(&"stone"))).is_equal(1.0)
	assert_float(_dark(&"stone")).is_equal_approx(stone.darkness * UndergroundLook.LIT_SHARE, 0.001)
	assert_float(_dark(&"ice")).is_equal_approx(ice.darkness, 0.001)
	assert_object(_game.underground.get_node_or_null(NodePath("Beacon%d" % _index(&"stone")))).is_not_null()
	# A second one lights Ice too.
	Progress.add_building(&"lighthouse", Vector2i(37, 0))
	await _physics(110)
	assert_float(_dark(&"ice")).is_equal_approx(ice.darkness * UndergroundLook.LIT_SHARE, 0.001)
	assert_array(look.lit_indices(2)).contains_exactly([_index(&"stone"), _index(&"ice")])
	# Topsoil and Clay are never touched (the headlamp layers).
	assert_float(_dark(&"clay")).is_equal_approx(_layer(&"clay").darkness, 0.001)
	# The up-top Lighthouse has its beam.
	_game.build.rebuild()
	var b := _game.build.building_node(0)
	assert_object(b.beam).is_not_null()


func test_a_saved_lighthouse_lights_stone_after_a_reload() -> void:
	_make()
	_join()
	await _physics(2)
	Progress.add_building(&"lighthouse", Vector2i(35, 0))
	_game.save.save_now()
	_game.free()
	Players.reset()
	Progress.reset()
	_make(true)
	_join()
	await _physics(100)
	assert_float(_dark(&"stone")).is_equal_approx(_layer(&"stone").darkness * UndergroundLook.LIT_SHARE, 0.001)


func test_building_a_lighthouse_flares_its_lamp() -> void:
	_make()
	_join()
	await _physics(2)
	Progress.vehicles.append(&"crane")
	Inventory.add(&"stone", 20)
	Inventory.add(&"crystal", 5)
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(34 * 48 + 10, 0))
	_game.player_node(P1).facing = 1
	await _physics(2)
	_game.build._pick(P1, &"lighthouse")
	await _physics(2)
	_game.build._drop(P1)
	await _physics(40)
	var b := _game.build.building_node(0)
	assert_str(String(b.data.id)).is_equal("lighthouse")
	assert_bool(b.beam.flaring()).is_true()


# --- B-02: cows from barns ---------------------------------------------------------------------

func test_every_barn_has_a_cow_in_its_yard_and_a_new_one_trots_out() -> void:
	_make()
	_join()
	await _physics(2)
	assert_int(_game.cows.cow_count()).is_equal(0)
	for c in [32, 37, 43]:
		Progress.add_building(&"barn", Vector2i(c, 0))
	await _physics(2)
	assert_int(_game.cows.cow_count()).is_equal(3)
	await _physics(240)
	for c: Dictionary in _game.cows.cows:
		assert_float(absf(float(c.x) - float(c.home))).is_less_equal(BarnCows.YARD + 0.01)
	# The newest cow comes out of her door with a heart.
	Progress.add_building(&"barn", Vector2i(45, 0))
	await _physics(1)
	var last: Dictionary = _game.cows.cows[3]
	assert_str(String(last.state)).is_equal("trot")
	assert_float(float(last.heart)).is_greater(0.0)
	# Not a barn: no cow.
	Progress.add_building(&"house", Vector2i(50, 0))
	await _physics(1)
	assert_int(_game.cows.cow_count()).is_equal(4)
	# Moving a barn moves her yard.
	Progress.move_building(0, Vector2i(20, 0))
	await _physics(1)
	assert_float(float(_game.cows.cows[0].home)).is_equal(21.0 * 48.0)


func test_a_hundred_barns_is_a_hundred_cows() -> void:
	_make()
	_join()
	await _physics(2)
	for i in 100:
		Progress.add_building(&"barn", Vector2i(i % 150, 0))
	await _physics(2)
	assert_int(_game.cows.cow_count()).is_equal(100)


func test_walking_into_a_cow_makes_her_hop() -> void:
	_make()
	_join()
	await _physics(2)
	Progress.add_building(&"barn", Vector2i(35, 0))
	await _physics(2)
	var c: Dictionary = _game.cows.cows[0]
	c.heart = 0.0
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(float(c.x), 0))
	await _physics(3)
	assert_float(float(_game.cows.cows[0].heart)).is_greater(0.0)


# --- C-13 / S-09: the gnome crew's stamp ---------------------------------------------------------

func test_every_save_stamps_the_time_and_a_clock_set_back_gives_nothing() -> void:
	_make()
	_join()
	await _physics(2)
	_game.save.save_now()
	var stamp := int(Save.get_value("gnome_stamp", 0))
	assert_int(absi(stamp - int(Time.get_unix_time_from_system()))).is_less_equal(2)
	# A stamp from the future (the clock moved back): no pile, no clip, no crash.
	_game.story.state(Story.FOREMAN).phase = ResidentState.Phase.RESTORED
	assert_int(_game.ruins.crew_return(-3600.0)).is_equal(0)
	assert_bool(_game.ruins.crew_clip_playing()).is_false()
	# Eight hours away: a pile and the march.
	assert_int(_game.ruins.crew_return(8 * 3600.0)).is_greater(0)
	assert_bool(_game.ruins.crew_clip_playing()).is_true()


# --- V-07 / W-24 / W-17: juice -------------------------------------------------------------------

func test_kicks_are_small_short_and_off_with_screen_shake_off() -> void:
	_make()
	_join()
	await _physics(2)
	ScreenKick.kick(P1, 50.0, 10.0)
	await _physics(2)
	assert_bool(_game.kick.active(P1)).is_true()
	assert_float(_game.kick.peak(P1)).is_less_equal(ScreenKick.MAX_PX + 0.75)
	await _physics(int(ScreenKick.MAX_SECS * 60.0) + 4)
	assert_bool(_game.kick.active(P1)).is_false()
	assert_vector(_game.director.camera_of(P1).offset).is_equal(Vector2.ZERO)
	Save.set_setting(SettingsPanel.SHAKE, false)
	ScreenKick.kick(P1, 3.0, 0.3)
	await _physics(2)
	assert_bool(_game.kick.active(P1)).is_false()


func test_a_big_scoop_kicks_and_a_loader_scoop_does_not() -> void:
	_make()
	var node := _join()
	await _physics(2)
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(30 * 48, 0))
	node.facing = -1
	await _physics(2)
	assert_int(node._scoop()).is_between(1, HillPlayer.BIG_SCOOP - 1)   # on foot: one tile
	await _physics(1)
	assert_bool(_game.kick.active(P1)).is_false()
	# Fresh scrub further along for the Excavator's 3x2 bucket.
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(22 * 48, 0))
	_game.park_new(&"excavator", Vector2(22 * 48, 0), HillGame.HILLVILLE)
	_game.hop_in(node)
	node.facing = -1
	await _physics(2)
	assert_object(node.vehicle).is_not_null()
	assert_int(node._scoop()).is_greater_equal(HillPlayer.BIG_SCOOP)
	await _physics(1)
	assert_bool(_game.kick.active(P1)).is_true()


func test_a_boulder_landing_near_kicks_and_far_does_not() -> void:
	_make()
	_join()
	await _physics(2)
	var u := _game.underground
	var at := u.landing(1)
	_game.place_player(P1, HillGame.UNDERGROUND, at)
	await _physics(2)
	var far := Node2D.new()
	u.add_child(far)
	far.position = at + Vector2(0, 2000)
	u._on_body_landed(far, 300.0)
	await _physics(1)
	assert_bool(_game.kick.active(P1)).is_false()
	far.position = at + Vector2(32, -16)
	u._on_body_landed(far, 300.0)
	await _physics(1)
	assert_bool(_game.kick.active(P1)).is_true()
	far.queue_free()


func test_strangestone_bounces_with_a_question_bubble_and_edgestone_does_not() -> void:
	_make()
	_join()
	await _physics(2)
	var u := _game.underground
	_game.place_player(P1, HillGame.UNDERGROUND, u.landing(5))
	await _physics(2)
	u._on_dig_blocked(Vector2i(3, 299), &"edgestone", P1)
	assert_bool(u.strange.showing(P1)).is_false()
	u._on_dig_blocked(Vector2i(60, 299), &"strangestone", P1)
	assert_bool(u.strange.showing(P1)).is_true()
	await _physics(int(StrangeBubble.LIFE * 60.0) + 4)
	assert_bool(u.strange.showing(P1)).is_false()


func test_the_dragon_snore_sways_the_cavern_and_not_topsoil() -> void:
	_make()
	_join()
	await _physics(2)
	var u := _game.underground
	var r := u.residents
	# Topsoil: she snores on, nobody feels it.
	_game.place_player(P1, HillGame.UNDERGROUND, u.landing(0))
	await _physics(int(UndergroundResidents.SNORE_EVERY * 60.0) + 20)
	assert_int(r.snores).is_equal(0)
	# In the cavern, out of her first-meeting reach: a snore, a gentle sway, no reveal.
	var feet := Vector2(r.dragon.position.x - UndergroundResidents.REVEAL_NEAR - 40.0, HillGenerator.CAVERN.end.y * 16.0 - 2.0)
	_game.place_player(P1, HillGame.UNDERGROUND, feet)
	var felt := [0.0]
	r.dragon_snored.connect(func(k: float) -> void: felt[0] = k)
	await _physics(int(UndergroundResidents.SNORE_EVERY * 60.0) + 20)
	assert_int(r.snores).is_greater_equal(1)
	assert_float(felt[0]).is_equal(1.0)
	assert_bool(_game.story.dragon_met()).is_false()
	await _physics(10)
	assert_float(_game.kick.peak(P1)).is_greater(0.0)


# --- H-03: the Excavator turns all the way round -------------------------------------------------

func test_the_excavator_spins_round_on_the_horn_and_the_loader_does_not() -> void:
	_make()
	var node := _join()
	await _physics(2)
	_game.hop_in(node)          # the Front Loader by the shaft
	if node.vehicle == null:
		_game.park_new(HillGame.LOADER, node.position, HillGame.HILLVILLE)
		_game.hop_in(node)
	node.honk()
	assert_float(node.cab_spin).is_equal(0.0)
	_game.hop_out(node, true)
	await _physics(2)
	_game.park_new(&"excavator", node.position, HillGame.HILLVILLE)
	_game.hop_in(node)
	await _physics(1)
	assert_str(String(node.vehicle.id)).is_equal("excavator")
	node.honk()
	assert_float(node.cab_spin).is_equal(1.0)
	await _physics(20)
	assert_float(node.cab_spin).is_between(0.01, 0.99)
	await _physics(int(HillPlayer.CAB_SPIN * 60.0) + 4)
	assert_float(node.cab_spin).is_equal(0.0)
