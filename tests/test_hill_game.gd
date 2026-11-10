## The Hill's game flow (HillGame): elevator rules (pure Door + destination, and a real ride),
## backpack, save round trip, drop-in (P2 out of the bucket, solo), underground generation (edges,
## floor, buried car, water gush), vehicles (hop in / out, roll-out).
class_name TestHillGame
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const Door := HillElevator.Door

var _game: HillGame
var _real_profile := ""


func before() -> void:
	_real_profile = Save.profile
	Game.quit_exits = false


func after() -> void:
	Save.flush()
	Save.profile = _real_profile
	Save._load()
	Game.quit_exits = true


func before_test() -> void:
	Save.profile = "test_hill_game"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _make(load_saved := false, start: Array = []) -> HillGame:
	_game = HillGame.new()
	_game.load_saved = load_saved
	_game.start_players = start
	get_tree().root.add_child(_game)
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


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


# --- elevator rules (no scene) -----------------------------------------------------------------

func test_door_waits_then_closes() -> void:
	var d := Door.new()
	assert_array(d.step({P1: &"hillville"}, {}, 0.0)).is_empty()
	for i in 9:
		assert_array(d.step({P1: &"hillville"}, {}, 0.1)).is_empty()
	var rides := d.step({P1: &"hillville"}, {}, 0.1)
	assert_int(rides.size()).is_equal(1)
	assert_array(rides[0].riders).is_equal([P1])


func test_everyone_in_the_cage_rides_together() -> void:
	var d := Door.new()
	d.step({P1: &"hillville", P2: &""}, {}, 0.0)
	for i in 5:
		d.step({P1: &"hillville", P2: &""}, {}, 0.1)
	var rides := []
	for i in 6:
		rides = d.step({P1: &"hillville", P2: &"hillville"}, {}, 0.1)
		if not rides.is_empty():
			break
	assert_int(rides.size()).is_equal(1)
	assert_array(rides[0].riders).is_equal([P1, P2])


func test_stepping_out_leaves_the_ride() -> void:
	var d := Door.new()
	d.step({P1: &"hillville", P2: &"hillville"}, {}, 0.0)
	d.step({P1: &"hillville", P2: &"hillville"}, {}, 0.5)
	var rides := d.step({P1: &"hillville", P2: &""}, {}, 0.6)
	assert_array(rides[0].riders).is_equal([P1])
	# Alone: stepping out before it closes cancels the ride.
	var e := Door.new()
	e.step({P1: &"u2"}, {}, 0.0)
	e.step({P1: &"u2"}, {}, 0.5)
	assert_array(e.step({P1: &""}, {}, 0.6)).is_empty()
	assert_float(e.progress(&"u2")).is_equal(0.0)


func test_a_skips_the_wait() -> void:
	var d := Door.new()
	d.step({P1: &"hillville"}, {}, 0.0)
	var rides := d.step({P1: &"hillville"}, {P1: true}, 0.016)
	assert_int(rides.size()).is_equal(1)


func test_rearms_only_after_stepping_out() -> void:
	var d := Door.new()
	d.step({P1: &"u0"}, {P1: true}, 0.0)
	d.arrived([P1])
	for i in 30:
		assert_array(d.step({P1: &"hillville"}, {}, 0.1)).is_empty()
	d.step({P1: &""}, {}, 0.1)
	d.step({P1: &"hillville"}, {}, 0.1)
	assert_int(d.step({P1: &"hillville"}, {P1: true}, 0.1).size()).is_equal(1)


func test_down_lands_at_the_deepest_rider_layer_up_goes_to_hillville() -> void:
	var to := HillElevator.destination(&"hillville", [P1, P2], {P1: 1, P2: 3})
	assert_str(String(to.scene)).is_equal("underground")
	assert_int(to.layer).is_equal(3)
	assert_int(HillElevator.destination(&"hillville", [P1], {P1: 0, P2: 3}).layer).is_equal(0)
	assert_str(String(HillElevator.destination(&"underground", [P2], {}).scene)).is_equal("hillville")


# --- a real ride -------------------------------------------------------------------------------

func test_ride_down_to_deepest_and_up_dumps_backpacks() -> void:
	_make()
	var p := _join(P1)
	Progress.visit_layer(P1, 2)
	_game.place_player(P1, &"hillville", _game.hillville.arrival() + Vector2(0, -1))
	_game.elevator.door.must_exit.erase(P1)
	var frames := await _until(func() -> bool: return _game.director.scene_of(P1) == &"underground", 200)
	assert_int(frames).is_less(int((HillElevator.DOOR_WAIT + HillElevator.RIDE_TIME) * 60) + 12)
	var land := _game.underground.landing(2)
	assert_float(p.global_position.distance_to(land)).is_less(20.0)
	assert_bool(p.locked).is_false()
	# Standing in the landing cage does not ride again until P1 steps out.
	await _physics(90)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
	p.keep_block(&"clay")
	p.keep_block(&"clay")
	p.keep_block(&"dirt")
	_game.place_player(P1, &"underground", land + Vector2(60, 0))
	await _physics(2)
	_game.place_player(P1, &"underground", land)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"hillville", 200)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_int(Inventory.count(&"clay")).is_equal(2)
	assert_int(Inventory.count(&"dirt")).is_equal(1)
	assert_int(p.backpack_count()).is_equal(0)
	# Every ride autosaves.
	assert_that(Save.get_value("seed")).is_not_null()


# --- backpack ----------------------------------------------------------------------------------

func test_backpack_fills_and_capacity_follows_barns() -> void:
	var p := HillPlayer.new()
	var cap := Progress.backpack_capacity()
	assert_int(cap).is_equal(Progress.BACKPACK_START * Progress.BACKPACK_PER_SIZE)
	for i in cap:
		assert_bool(p.keep_block(&"dirt")).is_true()
	assert_bool(p.is_full()).is_true()
	assert_bool(p.keep_block(&"dirt")).is_false()
	assert_int(p.backpack_count()).is_equal(cap)
	Progress.add_building(&"barn", Vector2i(3, 0))
	assert_int(p.capacity()).is_equal(cap + Progress.BACKPACK_PER_SIZE)
	assert_bool(p.keep_block(&"clay")).is_true()
	p.free()


func test_full_backpack_never_stops_digging() -> void:
	_make()
	var hold := {"move": Vector2.DOWN, "dig": true, "jump": false, "book": false, "horn": false}
	var p := _join(P1, hold)
	var land := _game.underground.landing(0) + Vector2(-64, 0)
	_game.place_player(P1, &"underground", land)
	for i in p.capacity():
		p.keep_block(&"dirt")
	var w := _game.underground.world
	var below := w.shape.cell_at(land + Vector2(0, 4))
	var start_y := p.global_position.y
	await _until(func() -> bool: return p.global_position.y > start_y + 40.0, 120)
	assert_bool(w.is_solid(below)).is_false()
	assert_float(p.global_position.y).is_greater(start_y + 40.0)
	assert_int(p.backpack_count()).is_equal(p.capacity())


# --- save --------------------------------------------------------------------------------------

func test_save_round_trip() -> void:
	_make(true)
	_join(P1)
	var w := _game.underground.world
	var cell := Vector2i(60, 20)
	assert_bool(w.is_solid(cell)).is_true()
	w.dig(cell, [Vector2i.ZERO], P1)
	Inventory.add(&"stone", 7)
	Progress.find_treasure(&"buried_car", P1)
	assert_str(String(Progress.unlock_next_vehicle())).is_equal("excavator")
	Progress.visit_layer(P1, 2)
	_game.place_player(P1, &"underground", _game.underground.landing(1) + Vector2(-40, 0))
	_game.autosave()
	_game.free()
	Inventory.clear()
	Progress.reset()
	Save._load()
	_make(true)
	_join(P1)
	assert_bool(_game.underground.world.is_solid(cell)).is_false()
	assert_int(Inventory.count(&"stone")).is_equal(7)
	assert_bool(Progress.has_treasure(&"buried_car")).is_true()
	assert_bool(_game.vehicles.has(&"excavator")).is_true()
	assert_bool(_game.vehicles.has(&"front_loader")).is_true()
	assert_int(Progress.deepest_of(P1)).is_equal(2)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
	assert_float(_game.player_node(P1).global_position.distance_to(_game.underground.landing(2))).is_less(1.0)


# --- drop-in -----------------------------------------------------------------------------------

func test_p2_sleeps_in_the_bucket_then_drops_in_and_plays() -> void:
	Players.join_virtual(P1)
	_make(false, [P1])
	var loader: Vehicle = _game.vehicles[&"front_loader"]
	assert_bool(_game.players.has(P2)).is_false()
	assert_int(loader.sleeper).is_equal(P2)
	var right := {"move": Vector2.RIGHT, "dig": false, "jump": false, "book": false, "horn": false}
	Players.join_virtual(P2)
	var p2 := _game.player_node(P2)
	assert_object(p2).is_not_null()
	assert_int(loader.sleeper).is_equal(-1)
	assert_float(absf(p2.global_position.x - loader.position.x)).is_less(40.0)
	p2.intent_source = func() -> Dictionary: return right
	await _physics(30)
	var x0 := p2.global_position.x
	await _physics(20)
	assert_float(p2.global_position.x).is_greater(x0 + 20.0)


func test_solo_p1_alone_plays_and_p2_waits_for_focus() -> void:
	Players.set_solo(true)
	_make(false, [P1, P2])
	assert_bool(_game.players.has(P1)).is_true()
	assert_bool(_game.players.has(P2)).is_false()
	var p1 := _game.player_node(P1)
	var right := {"move": Vector2.RIGHT, "dig": false, "jump": false, "book": false, "horn": false}
	p1.intent_source = func() -> Dictionary: return right
	await _physics(20)
	var x0 := p1.global_position.x
	await _physics(20)
	assert_float(p1.global_position.x).is_greater(x0 + 20.0)
	Players.set_solo_focus(P2)
	await _physics(2)
	assert_bool(_game.players.has(P2)).is_true()


func test_player_leaving_despawns_and_anchor_returns() -> void:
	_make()
	_join(P1)
	Players.player_left.emit(P1)
	assert_bool(_game.players.has(P1)).is_false()
	assert_bool(_game._anchor_on).is_true()


# --- vehicles ----------------------------------------------------------------------------------

func test_hop_in_drive_and_hop_out() -> void:
	_make()
	var p := _join(P1)
	var loader: Vehicle = _game.vehicles[&"front_loader"]
	p.global_position = loader.position + Vector2(-26, 0)
	assert_bool(_game.hop_in(p)).is_true()
	assert_object(p.vehicle).is_not_null()
	assert_bool(loader.is_inside_tree()).is_false()
	p.global_position += Vector2(-100, 0)
	_game.hop_out(p)
	assert_object(p.vehicle).is_null()
	assert_bool(loader.is_inside_tree()).is_true()
	assert_float(absf(loader.position.x - (p.global_position.x + 6.0))).is_less(1.0)


func test_garage_rolls_out_a_parked_excavator() -> void:
	_make()
	_game.hillville.vehicle_rolls_out.emit(&"excavator", Vector2(2400, 0))
	assert_bool(_game.vehicles.has(&"excavator")).is_true()
	await _physics(70)
	assert_float(_game.vehicles[&"excavator"].position.x).is_greater(2440.0)


func test_vehicle_dig_fits_its_body() -> void:
	_make()
	var p := _join(P1)
	_game.place_player(P1, &"underground", _game.underground.landing(0) + Vector2(-64, 0))
	p.drive(Progress.vehicle_data(&"front_loader"))
	var cells := p.dig_cells(Vector2i(-1, 0))
	assert_int(cells.size()).is_greater_equal(2)   # a column as tall as the Loader
	var down := p.dig_cells(Vector2i(0, 1))
	assert_int(down.size()).is_greater_equal(2)    # a row as wide as the Loader
	p.stop_driving()
	p.drive(Progress.vehicle_data(&"excavator"))
	assert_int(p.dig_cells(Vector2i(0, 1)).size()).is_greater_equal(3)


# --- underground generation --------------------------------------------------------------------

func test_edges_and_floor_are_unbreakable() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var w := u.world
	var blocked: Array = []
	w.dig_blocked.connect(func(c: Vector2i, _b: StringName, _p: int) -> void: blocked.append(c))
	for cell in [Vector2i(0, 50), Vector2i(1, 120), Vector2i(199, 50), Vector2i(198, 200), Vector2i(50, 296), Vector2i(150, 299)]:
		assert_bool(w.is_solid(cell)).is_true()
		assert_array(w.dig(cell)).is_empty()
	assert_int(blocked.size()).is_equal(6)
	assert_str(String(w.tile_def(w.get_tile(Vector2i(0, 50))).id)).is_equal("edgestone")
	assert_str(String(w.tile_def(w.get_tile(Vector2i(50, 296))).id)).is_equal("strangestone")
	# Six layers, a landing each, a cavern in The Bottom, Clay mixes in some dirt.
	assert_int(u.layers().size()).is_equal(6)
	for i in 6:
		assert_int(u.cage_zone_at(u.landing(i))).is_equal(i)
		assert_int(u.layer_index_at(u.landing(i))).is_equal(i)
	assert_bool(w.is_solid(Vector2i(100, 280))).is_false()
	var dirt := 0
	for x in range(10, 190, 3):
		if w.tile_def(w.get_tile(Vector2i(x, 50))).id == &"dirt":
			dirt += 1
	assert_int(dirt).is_greater(0)


func test_buried_car_in_clay_found_by_digging_next_to_it() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var car := u.treasure_cell(&"buried_car")
	assert_int(u.layer_index_at(Vector2(car) * 16.0)).is_equal(1)
	var off := HillGenerator.SHAFT_X - car.x
	assert_int(off).is_between(10, 30)
	assert_bool(Progress.has_treasure(&"buried_car")).is_false()
	# The cell under the car's left corner, one column out.
	var w := u.world
	var target := car + Vector2i(-2, 1)
	assert_bool(w.is_solid(target)).is_true()
	w.dig(target, [Vector2i.ZERO], P1)
	assert_bool(Progress.has_treasure(&"buried_car")).is_true()
	# Every treasure row is placed.
	for id in [&"giant_tooth", &"gnome_room"]:
		assert_int(u.treasure_cell(id).x).is_greater(0)


func test_breached_pocket_gushes_for_about_two_seconds() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var w := u.world
	for i in 6:
		w.update_chunks()
	var pocket := u.generator.pocket
	var start := w.water_count()
	assert_int(start).is_greater_equal(pocket.size.x * pocket.size.y)
	# A tunnel along the pocket's bottom row, out to the left.
	var row := pocket.end.y - 1
	for x in range(pocket.position.x - 8, pocket.position.x):
		w.dig(Vector2i(x, row))
	assert_bool(u.is_gushing()).is_true()
	await _physics(int(Underground.GUSH_TIME * 60) + 10)
	assert_bool(u.is_gushing()).is_false()
	var after_gush := w.water_count()
	assert_int(after_gush).is_greater(start)
	await _physics(60)
	assert_int(w.water_count()).is_equal(after_gush)


# --- up top ------------------------------------------------------------------------------------

func test_up_top_a_scoops_scrub_x_opens_the_book_y_honks() -> void:
	_make()
	var intent := IDLE.duplicate()
	var p := _join(P1)
	p.intent_source = func() -> Dictionary: return intent
	var hv := _game.hillville
	var x := hv.nearest_scrub(hv.spawn_point(P1).x)
	p.global_position = Vector2(x - 4.0, 0)
	p.facing = 1
	var before := hv.scrub_left()
	intent.dig = true
	await _physics(3)
	intent.dig = false
	assert_int(hv.scrub_left()).is_less(before)
	var pile := 0
	for b in [&"dirt", &"stone"]:
		pile += Inventory.count(b)
	assert_int(pile).is_greater(0)
	intent.book = true
	await _physics(2)
	intent.book = false
	assert_bool(_game.build.captures(P1)).is_true()
	await _physics(2)
	intent.book = true
	await _physics(2)
	intent.book = false
	assert_bool(_game.build.captures(P1)).is_false()
	var honks := [0]
	p.honked.connect(func() -> void: honks[0] += 1)
	intent.horn = true
	await _physics(2)
	assert_int(honks[0]).is_equal(1)


func test_main_boots_the_lobby_with_jeff_and_chuck_then_the_hill() -> void:
	Game._set_state(Game.State.LOBBY)
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))   # the game's skin, whatever an earlier suite set
	var main: Node = auto_free(load("res://scenes/main.tscn").instantiate())
	add_child(main)
	var lobby: Node = main.get_node("UI/Lobby")
	assert_str(UiStyle.skin().title()).is_equal("The Hill")
	assert_object(lobby.get_node("Spots/P1/Character").character).is_instanceof(HillMenuCharacter)
	assert_int(lobby.get_node("Spots/P2/Character").character.player).is_equal(P2)
	assert_object(main.get_node_or_null("Arena")).is_null()
	Players.join_virtual(P1)
	Game.finish_lobby([P1])
	assert_object(main.game).is_not_null()
	assert_int(main.game.get_index()).is_less(main.get_node("UI").get_index())
	assert_bool(main.game.players.has(P1)).is_true()
	Game.to_lobby()
	await await_idle_frame()
	assert_object(main.game).is_null()
