## H-03 and H-05 (Vehicles lane, 2026-11-10), in simulated physics time: the Excavator digs a pond
## that fills with water (and keeps it across a reload); the Crane's wrecking ball bonks a building
## and the pile without taking anything; Up + A lifts a building on the hook and A sets it down; a
## ride down with the Crane aboard is lowered down the shaft on the cable in under 2 s.
class_name TestCranePond
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_crane_pond.json"
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
	Save.profile = "test_crane_pond"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = {P1: IDLE.duplicate(), P2: IDLE.duplicate()}


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Save.wipe()
	Game._set_state(Game.State.LOBBY)


func _make(load_saved := false) -> HillGame:
	_game = HillGame.new()
	_game.load_saved = load_saved
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	return _game


func _join(p: int) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return _intent[p]
	return node


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(p: int, move: Vector2, dig := false) -> void:
	_intent[p] = {"move": move, "dig": dig, "jump": false, "book": false, "horn": false}


## One A press (held two frames, then let go).
func _press(p: int, move := Vector2.ZERO) -> void:
	_hold(p, move, true)
	await _physics(2)
	_hold(p, Vector2.ZERO)


## Unlocks `id`, parks it at `pos` in `scene`, P1 hops in. The Loader goes out of the yard.
func _ride(id: StringName, scene: StringName, pos: Vector2) -> HillPlayer:
	var node := _join(P1)
	var loader: Vehicle = _game.vehicles.get(HillGame.LOADER)
	if loader != null:
		loader.position.x = Hillville.SHAFT_X + 520.0
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	_game.park_new(id, pos, scene)
	_game.place_player(P1, scene, pos)
	node.velocity = Vector2.ZERO
	assert_bool(_game.hop_in(node)).is_true()
	assert_that(node.vehicle.id).is_equal(id)
	return node


func test_excavator_digs_a_pond_that_fills_with_water_and_keeps_it_after_a_reload() -> void:
	_make()
	var hv := _game.hillville
	var p := _ride(&"excavator", HillGame.HILLVILLE, Vector2(34 * 48, 0))
	p.facing = 1
	await _physics(3)
	assert_array(hv.pond_columns()).is_empty()
	_hold(P1, Vector2.ZERO, true)
	await _physics(40)   # two digs (0.35 s apart): two tiles deep
	_hold(P1, Vector2.ZERO)
	var cols := hv.pond_columns()
	assert_int(cols.size()).is_equal(3)
	for c in cols:
		assert_int(hv.pond_depth(c)).is_equal(Hillville.POND_DEEP)
		assert_int(c).is_greater(floori(p.global_position.x / Hillville.TILE))   # ahead of the bucket
	assert_int(Inventory.count(&"dirt")).is_equal(3 * Hillville.POND_DEEP)
	assert_float(hv.pond_water(cols[0])).is_less(1.0)
	await _physics(90)
	for c in cols:
		assert_float(hv.pond_water(c)).is_equal(1.0)
	# Nobody builds on a pond.
	assert_bool(hv.ground_clear(cols[0] / 3, 1)).is_false()
	# A full pond splashes instead of digging deeper (still something to see and hear).
	await _press(P1)
	await _physics(2)
	assert_int(hv.pond_depth(cols[0])).is_equal(Hillville.POND_DEEP)
	_game.save.save_now()
	_game.free()
	_make(true)
	assert_array(_game.hillville.pond_columns()).is_equal(cols)
	assert_float(_game.hillville.pond_water(cols[0])).is_equal(1.0)


func test_excavator_scoops_scrub_first_and_never_digs_a_pond_in_the_shaft_or_under_a_building() -> void:
	_make()
	var hv := _game.hillville
	var x := hv.nearest_scrub(30 * 48)
	var p := _ride(&"excavator", HillGame.HILLVILLE, Vector2(x - 20, 0))
	p.facing = 1
	await _physics(3)
	var before := hv.scrub_left()
	await _press(P1)
	await _physics(2)
	assert_int(hv.scrub_left()).is_less(before)
	assert_array(hv.pond_columns()).is_empty()
	assert_int(hv.dig_pond(Vector2(Hillville.SHAFT_X - 40, 0), 1, 3)).is_equal(0)
	Progress.add_building(&"barn", Vector2i(44, 0))
	assert_int(hv.dig_pond(Vector2(44 * 48 - 10, 0), 1, 3)).is_equal(0)
	assert_array(hv.pond_columns()).is_empty()


func test_crane_wrecking_ball_bonks_a_building_and_the_pile_and_takes_nothing() -> void:
	_make()
	Progress.add_building(&"barn", Vector2i(36, 0))
	_game.build.rebuild()
	var p := _ride(&"crane", HillGame.HILLVILLE, Vector2(36 * 48 - 46, 0))
	p.facing = 1
	await _physics(3)
	var hits: Array = []
	p.ability.ball_hit.connect(func(w: Array) -> void: hits.append(w))
	var barn := _game.build.building_node(0)
	await _press(P1)
	assert_float(p.ability.ball).is_greater_equal(0.0)
	assert_bool(_game.build.has_ghost(P1)).is_false()   # A swung the ball, it did not pick the barn up
	await _physics(24)
	assert_array(hits).is_equal([[&"building"]])
	assert_float(barn.skew).is_greater(0.2)            # leans right over, away from the ball
	await _physics(110)
	assert_float(absf(barn.skew)).is_less(0.05)        # and springs back up
	assert_int(Progress.buildings.size()).is_equal(1)
	assert_that(Progress.buildings[0].cell).is_equal(Vector2i(36, 0))
	# The pile: it leans and blocks tumble, but every block stays in the pile.
	Inventory.add(&"dirt", 10)
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.PILE_X + 6 * 16 + 38, 0))
	p.facing = -1
	await _physics(3)
	await _press(P1)
	await _physics(26)
	assert_array(hits[1]).contains([&"pile"])
	assert_float(absf(_game.hillville.pile_lean)).is_greater(0.0)
	assert_int(Inventory.count(&"dirt")).is_equal(10)


func test_crane_ball_knocks_scrub_clear() -> void:
	_make()
	var hv := _game.hillville
	var x := hv.nearest_scrub(30 * 48)
	var p := _ride(&"crane", HillGame.HILLVILLE, Vector2(x - 20, 0))
	p.facing = 1
	await _physics(3)
	var before := hv.scrub_left()
	await _press(P1)
	await _physics(26)
	assert_int(hv.scrub_left()).is_less(before)


func test_crane_lifts_a_building_with_up_a_and_sets_it_down_somewhere_else() -> void:
	_make()
	Progress.add_building(&"barn", Vector2i(34, 0))
	_game.build.rebuild()
	var p := _ride(&"crane", HillGame.HILLVILLE, Vector2(34 * 48 - 40, 0))
	p.facing = 1
	await _physics(3)
	await _press(P1, Vector2(0, -1))
	await _physics(30)
	var g := _game.build.ghost_of(P1)
	assert_object(g).is_not_null()
	assert_object(p.ability.carried()).is_same(g)
	assert_float(-g.position.y).is_equal_approx(VehicleAbility.LIFT_PX, 0.5)   # up on the hook
	assert_bool(p.ability.draw_state().has("lift")).is_true()
	_hold(P1, Vector2(1, 0))
	await _physics(54)
	_hold(P1, Vector2.ZERO)
	await _physics(2)
	await _press(P1)
	await _physics(2)
	assert_bool(_game.build.has_ghost(P1)).is_false()
	assert_float(g.position.y).is_equal(0.0)
	assert_int(Progress.buildings[0].cell.x).is_greater(34)
	await _physics(20)
	assert_float(p.ability.lift).is_equal(0.0)


func test_a_ride_down_with_the_crane_is_lowered_down_the_shaft_on_the_cable_in_under_two_seconds() -> void:
	_make()
	var li := 2
	Progress.deepest[P1] = li
	var p := _ride(&"crane", HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X - 4, 0))
	var to := _game.underground.landing(li)
	var frames := 0
	var mid_seen := false
	var started := false
	_game.elevator.ride_started.connect(func(_r: Array, _f: StringName) -> void: started = true)
	while frames < 300:
		await _physics(1)
		if started:
			frames += 1
		var cr := _game.elevator.crane_ride
		if cr != null and cr.is_lowering(P1):
			if p.global_position.y > CraneRide.MOUTH_Y + 40.0 and p.global_position.y < to.y - 40.0:
				mid_seen = true
		elif cr != null and _game.director.scene_of(P1) == HillGame.UNDERGROUND and not p.locked:
			break
	assert_bool(mid_seen).is_true()                         # seen on the way down the shaft
	assert_float(p.global_position.distance_to(to)).is_less(20.0)
	assert_int(frames).is_less(120)                         # cage sink + cable: under 2 s at 60 fps
	assert_bool(p.locked).is_false()


func test_a_ride_down_without_the_crane_is_the_plain_elevator() -> void:
	_make()
	var p := _join(P1)
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X, 0))
	await _physics(120)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
	assert_bool(_game.elevator.crane_ride == null or not _game.elevator.crane_ride.is_lowering(P1)).is_true()
	assert_float(p.global_position.distance_to(_game.underground.landing(0))).is_less(20.0)
