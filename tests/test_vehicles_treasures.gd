## Vehicles 2-4 (Dump Truck, Crane, Drill Rig), the treasures of every layer and the Treasure Shelf
## (Gameplay lane, 2026-11-10), in simulated physics time: each unlock path (Garage N gives vehicle
## N; the Drill Rig's Garage waits for the Giant Tooth), each ability (tip and reverse, hook a
## boulder, drill down on its own), the pickup reveal and the shelf, the build book's picture
## cards, the Water Tower's drain and the save round-trip of all of it.
class_name TestVehiclesTreasures
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const LADDER := [&"front_loader", &"excavator", &"dump_truck", &"crane", &"drill_rig"]

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("vehicles_treasures")   # first: never the real profile, settings or picks file
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_vehicles.json"
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
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	Save.profile = "test_vehicles"
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


## Unlocks `id`, parks it at `pos` in `scene`, P1 hops in.
func _ride(id: StringName, scene: StringName, pos: Vector2) -> HillPlayer:
	var node := _join(P1)
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	_game.park_new(id, pos, scene)
	_game.place_player(P1, scene, pos)
	node.velocity = Vector2.ZERO
	assert_bool(_game.hop_in(node)).is_true()
	assert_that(node.vehicle.id).is_equal(id)
	return node


func _carve(room: Rect2i) -> void:
	var w := _game.underground.world
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.set_tile(Vector2i(x, y), 0)


func _pile_total() -> int:
	var n := 0
	for b in [&"dirt", &"clay", &"stone", &"ice", &"crystal"]:
		n += Inventory.count(b)
	return n


# --- the ladder --------------------------------------------------------------------------------

func test_ladder_is_five_vehicles_with_their_own_abilities_and_faceless_art() -> void:
	var ids: Array = Progress.vehicle_rows().map(func(v: VehicleData) -> StringName: return v.id)
	assert_array(ids).is_equal(LADDER)
	var abilities := {}
	for v: VehicleData in Progress.vehicle_rows():
		assert_int(v.order).is_equal(LADDER.find(v.id))
		assert_bool(SpriteArt.has("vehicles/%s.png" % v.id)).is_true()
		for k in [&"engine", &"horn", &"dig"]:
			assert_bool(v.sounds.has(k)).is_true()
		if v.order >= 2:
			assert_str(String(v.ability)).is_not_empty()
			assert_bool(abilities.has(v.ability)).is_false()
			abilities[v.ability] = true
			assert_vector(Vehicle.body_size(v)).is_equal(Vector2(SheetSprite.entry("vehicles/%s.png" % v.id).box[0],
					SheetSprite.entry("vehicles/%s.png" % v.id).box[1]))
	assert_float(Progress.vehicle_data(&"dump_truck").carry).is_equal(5.0)
	assert_str(String(Progress.vehicle_data(&"drill_rig").needs_treasure)).is_equal("giant_tooth")


func test_each_garage_gives_the_next_vehicle_and_the_drill_garage_waits_for_the_tooth() -> void:
	_make()
	var rolled: Array = []
	_game.hillville.vehicle_rolls_out.connect(func(id: StringName, _d: Vector2) -> void: rolled.append(id))
	Progress.find_treasure(&"buried_car")
	for k in 4:
		Progress.add_building(&"garage", Vector2i(10 + k * 4, 0))
		Progress.unlock_next_vehicle()
	assert_array(Progress.vehicles).is_equal([&"front_loader", &"excavator", &"dump_truck", &"crane"])
	# The fourth Garage is built but the Drill Rig waits for the Giant Tooth.
	assert_int(Progress.garages_waiting()).is_equal(1)
	assert_that(Progress.next_in_line().id).is_equal(&"drill_rig")
	_game.build.rebuild()
	Progress.find_treasure(&"giant_tooth")
	assert_bool(Progress.has_vehicle(&"drill_rig")).is_true()
	assert_int(Progress.garages_waiting()).is_equal(0)
	await _physics(50)
	assert_array(rolled).contains([&"drill_rig"])
	assert_bool(_game.vehicles.has(&"drill_rig")).is_true()


# --- abilities ---------------------------------------------------------------------------------

func test_dump_truck_carries_five_backpacks_and_tips_the_whole_load_onto_the_pile() -> void:
	_make()
	var p := _ride(&"dump_truck", HillGame.HILLVILLE, Vector2(Hillville.PILE_X - 300.0, 0))
	assert_int(p.capacity()).is_equal(Progress.backpack_capacity() * 5)
	for i in p.capacity():
		p.keep_block(&"dirt" if i % 2 else &"clay")
	var load := p.backpack_count()
	assert_int(load).is_equal(p.capacity())
	_hold(P1, Vector2.ZERO, true)
	await _physics(2)
	_hold(P1, Vector2.ZERO)
	assert_float(p.ability.tipping).is_greater_equal(0.0)
	await _physics(80)
	assert_int(p.backpack_count()).is_equal(0)
	assert_int(_pile_total()).is_equal(load)
	assert_float(p.ability.bed).is_equal(0.0)


func test_dump_truck_reverses_with_a_beep_before_it_turns_round() -> void:
	_make()
	var p := _ride(&"dump_truck", HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X - 600.0, 0))
	p.facing = 1
	var x0 := p.global_position.x
	_hold(P1, Vector2(-1, 0))
	await _physics(30)
	assert_int(p.facing).is_equal(1)
	assert_float(p.global_position.x).is_less(x0 - 10.0)
	assert_bool(p.ability.is_reversing()).is_true()
	await _physics(45)
	assert_int(p.facing).is_equal(-1)


func test_crane_hooks_a_boulder_out_for_good_and_it_stays_gone_after_a_reload() -> void:
	_make()
	var u := _game.underground
	var i := 0
	var r: Rect2i = u.generator.boulder_spots[i]
	_carve(Rect2i(r.position.x - 7, r.end.y - 4, 7, 4))
	var feet := Vector2((r.position.x - 4) * 16.0, r.end.y * 16.0 - 1.0)
	var p := _ride(&"crane", HillGame.UNDERGROUND, feet)
	p.facing = 1
	await _physics(3)
	_hold(P1, Vector2.ZERO, true)
	await _physics(2)
	_hold(P1, Vector2.ZERO)
	assert_array(Progress.hauled).contains([i])
	assert_int(int(p.backpack.get(&"stone", 0))).is_equal(Underground.BOULDER_BLOCKS)
	await _physics(70)
	assert_bool(is_instance_valid(u.boulders[i])).is_false()
	# Nothing in reach any more: A digs instead.
	assert_int(u.boulder_near(p.global_position, VehicleAbility.HOOK_REACH)).is_not_equal(i)
	_game.save.save_now()
	_game.free()
	Progress.reset()
	_make(true)
	assert_array(Progress.hauled).contains([i])
	assert_bool(is_instance_valid(_game.underground.boulders[i])).is_false()


func test_drill_rig_drills_five_wide_straight_down_on_its_own_until_told_to_stop() -> void:
	_make()
	Progress.find_treasure(&"giant_tooth")
	_carve(Rect2i(56, 14, 10, 4))
	var feet := Vector2(61 * 16.0, 18 * 16.0 - 1.0)
	var p := _ride(&"drill_rig", HillGame.UNDERGROUND, feet)
	await _physics(5)
	var y0 := p.global_position.y
	var x0 := p.global_position.x
	_hold(P1, Vector2.ZERO, true)
	await _physics(1)
	_hold(P1, Vector2(1, 0))      # steering is ignored while it drills
	assert_bool(p.ability.drilling).is_true()
	await _physics(150)
	assert_float(p.global_position.y - y0).is_greater(6 * 16.0)
	assert_float(absf(p.global_position.x - x0)).is_less(2.0)
	# 5 wide: the columns two either side of the middle are gone at the bit's depth.
	var c := _game.underground.world.shape.cell_at(Vector2(x0, y0 + 40.0))
	for dx in range(-2, 3):
		assert_bool(_game.underground.world.is_solid(c + Vector2i(dx, 0))).is_false()
	_hold(P1, Vector2.ZERO, true)
	await _physics(1)
	_hold(P1, Vector2.ZERO)
	assert_bool(p.ability.drilling).is_false()


# --- treasures ---------------------------------------------------------------------------------

func test_every_layer_but_the_bottom_has_treasures_placed_in_it() -> void:
	_make()
	var u := _game.underground
	var ls := u.layers()
	for li in ls.size():
		var l: LayerData = ls[li]
		var rows := Progress.treasures_in_layer(l.id)
		if l.id == &"bottom":
			continue
		assert_int(rows.size()).is_greater_equal(1)
		for t: TreasureData in rows:
			var cell := u.treasure_cell(t.id)
			assert_int(cell.x).is_greater(0)
			assert_int(u.generator.layer_of_depth(cell.y)).is_equal(li)
			assert_bool(SpriteArt.has("treasures/%s.png" % t.id)).is_true()
	# The pickups never moved the Buried Car's first-playable spot (it is placed first).
	var car := u.treasure_cell(&"buried_car")
	assert_int(HillGenerator.SHAFT_X - car.x).is_between(HillGenerator.CAR_REACH.x, HillGenerator.CAR_REACH.y + 3)


func test_a_pickup_pops_up_flies_into_the_bag_and_lands_on_the_shelf() -> void:
	_make()
	var u := _game.underground
	var p := _join(P1)
	var r: Rect2i
	for sp in u.generator.treasure_spots:
		if sp.id == &"bottle_caps":
			r = sp.rect
	_carve(Rect2i(r.position.x - 8, r.end.y - 2, 5, 2))
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2((r.position.x - 3.5) * 16.0, r.end.y * 16.0 - 1.0))
	p.velocity = Vector2.ZERO
	p.facing = 1
	var found: Array = []
	u.treasure_dug.connect(func(id: StringName, _p: int) -> void: found.append(id))
	_hold(P1, Vector2(1, 0), true)
	var n := 0
	while not Progress.has_treasure(&"bottle_caps") and n < 120:
		await get_tree().physics_frame
		n += 1
	_hold(P1, Vector2.ZERO)
	assert_bool(Progress.has_treasure(&"bottle_caps")).is_true()
	assert_array(found).contains([&"bottle_caps"])
	assert_bool(u.props.has(&"bottle_caps")).is_false()
	var reveals := u.world.find_children("*", "TreasureReveal", false, false)
	assert_int(reveals.size()).is_equal(1)
	await get_tree().create_timer(2.2).timeout
	assert_int(u.world.find_children("*", "TreasureReveal", false, false).size()).is_equal(0)
	# Up top it waits on the shelf, sparkling, until a player walks up to it.
	var shelf := _game.shelf
	assert_bool(shelf.fresh.has(&"bottle_caps")).is_true()
	var top: Array = shelf.slots()[0]
	assert_bool(top.any(func(s: Dictionary) -> bool: return s.id == &"bottle_caps" and s.found)).is_true()
	assert_bool(top.any(func(s: Dictionary) -> bool: return not s.found)).is_true()
	var placed: Array = []
	shelf.placed.connect(func(id: StringName) -> void: placed.append(id))
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(TreasureShelf.X - 40.0, 0))
	await _physics(5)
	assert_array(placed).is_equal([&"bottle_caps"])


func test_the_buried_car_still_stays_where_it_lies() -> void:
	_make()
	var u := _game.underground
	var car := u.treasure_cell(&"buried_car")
	u.world.dig(car + Vector2i(-2, 0), [Vector2i.ZERO], P1)
	assert_bool(Progress.has_treasure(&"buried_car")).is_true()
	assert_bool(u.props.has(&"buried_car")).is_true()
	assert_int(u.world.find_children("*", "TreasureReveal", false, false).size()).is_equal(0)


# --- build book --------------------------------------------------------------------------------

func test_book_shows_crane_buildings_locked_with_a_crane_picture_until_the_crane_comes() -> void:
	_make()
	var b := _game.build
	assert_array(b.locked_rows().map(func(d: BuildingData) -> StringName: return d.id)).is_equal([&"lighthouse", &"water_tower"])
	assert_array(b.book_rows().map(func(d: BuildingData) -> StringName: return d.id)).not_contains([&"lighthouse", &"water_tower"])
	b._open_book(P1)
	var book := b.book_of(P1) as BuildBook
	assert_array(book.locked_ids()).is_equal([&"lighthouse", &"water_tower"])
	book.focus = book.rows.size()
	assert_bool(book.focused_locked()).is_true()
	var before := Progress.buildings.size()
	b._pick(P1, book.focused_id())
	assert_int(Progress.buildings.size()).is_equal(before)
	assert_bool(b.has_ghost(P1)).is_false()
	b._close_book(P1)
	Progress.vehicles.append(&"crane")
	assert_array(b.locked_rows()).is_empty()
	assert_array(b.book_rows().map(func(d: BuildingData) -> StringName: return d.id)).contains([&"lighthouse", &"water_tower"])


func test_water_tower_drains_flooded_tunnels_near_a_player() -> void:
	_make()
	var u := _game.underground
	var p := _join(P1)
	var pocket: Rect2i = u.generator.pocket
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2((pocket.position.x - 2) * 16.0, pocket.end.y * 16.0))
	u.world.update_chunks()
	await _physics(2)
	var before := u.world.water_count()
	assert_int(before).is_greater(0)
	await _physics(40)
	assert_int(u.world.water_count()).is_equal(before)   # no Water Tower: nothing drains
	Progress.add_building(&"water_tower", Vector2i(20, 0))
	await _physics(60)
	assert_int(u.world.water_count()).is_less(before)
	assert_object(p).is_not_null()


# --- save --------------------------------------------------------------------------------------

func test_vehicles_treasures_buildings_survive_a_reload() -> void:
	_make()
	Progress.find_treasure(&"buried_car")
	Progress.find_treasure(&"bottle_caps")
	Progress.find_treasure(&"dragon_egg")
	Progress.add_building(&"garage", Vector2i(26, 0))
	Progress.add_building(&"garage", Vector2i(33, 0))
	Progress.add_building(&"water_tower", Vector2i(50, 0))
	for v in [&"excavator", &"dump_truck", &"crane"]:
		Progress.vehicles.append(v)
	Progress.hauled.append(3)
	_game.save.save_now()
	_game.free()
	Progress.reset()
	_make(true)
	assert_array(Progress.vehicles).is_equal([&"front_loader", &"excavator", &"dump_truck", &"crane"])
	assert_array(Progress.treasures).contains_exactly_in_any_order([&"buried_car", &"bottle_caps", &"dragon_egg"])
	assert_int(Progress.count_buildings(&"garage")).is_equal(2)
	assert_int(Progress.count_buildings(&"water_tower")).is_equal(1)
	assert_array(Progress.hauled).is_equal([3])
	# Found pickups are gone from the ground; the car (it stays) is still there.
	assert_bool(_game.underground.props.has(&"bottle_caps")).is_false()
	assert_bool(_game.underground.props.has(&"dragon_egg")).is_false()
	assert_bool(_game.underground.props.has(&"boot")).is_true()
	assert_bool(_game.underground.props.has(&"buried_car")).is_true()
	# Each Garage stores its vehicle: the Excavator parks at Garage 1, the Dump Truck at Garage 2.
	for id in [&"excavator", &"dump_truck", &"crane"]:
		assert_bool(_game.vehicles.has(id)).is_true()
	assert_float(_game.vehicles[&"excavator"].position.x).is_equal(_game.garage_spot(&"excavator").x)
	assert_float(_game.vehicles[&"dump_truck"].position.x).is_equal((33 * 48 + 72) + HillGame.ROLL_OUT_PX)
