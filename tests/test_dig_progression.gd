## Dig progression lane (playtest 2026-11-10, PT10-4 and PT10-5): a slow, chunky start (hit
## points, cracks, a pop), unlock bands of Gate Rock between the layers (what opens each one is
## data: data/gates), felt jumps from the Workshop and each vehicle, Hard Rock only a vehicle
## breaks (a big haul), and no clearing the land up top by hand.
class_name TestDigProgression
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SUITE := "dig_progression"

var _game: HillGame


func before() -> void:
	SuiteSandbox.enter(SUITE, "res://tests/fixtures/roster_two.json")
	Game.quit_exits = false


func after() -> void:
	Game.quit_exits = true
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	DigFeel.demo_open = false
	HillPlayer.hand_clear = false


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


func _make() -> HillGame:
	_game = HillGame.new()
	_game.load_saved = false
	get_tree().root.add_child(_game)
	return _game


func _join(p: int, intent: Dictionary) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return intent
	return node


func _intent() -> Dictionary:
	return {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _world() -> TileWorld:
	return _game.underground.world


func _tile(id: StringName) -> int:
	return _world().palette.find(_game.underground.blocks[id])


## Carves `room` out of a block of dirt and stands p on its floor at column `at`.
func _room(p: int, room: Rect2i, at: int) -> HillPlayer:
	var w := _world()
	var dirt := _tile(&"dirt")
	for y in range(room.position.y - 3, room.end.y + 3):
		for x in range(room.position.x - 4, room.end.x + 4):
			w.set_tile(Vector2i(x, y), dirt if not room.has_point(Vector2i(x, y)) else 0)
	_game.place_player(p, &"underground", Vector2((at + 0.5) * 16.0, room.end.y * 16.0 - 1.0))
	var node := _game.player_node(p)
	node.velocity = Vector2.ZERO
	return node


func _drive(p: int, id: StringName, scene: StringName, pos: Vector2) -> HillPlayer:
	var node := _game.player_node(p)
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	var v: Vehicle = _game.vehicles.get(id)
	if v != null and v.is_inside_tree():
		v.get_parent().remove_child(v)
		_game.vehicles.erase(id)
		v.queue_free()
	_game.park_new(id, pos, scene)
	_game.place_player(p, scene, pos)
	node.velocity = Vector2.ZERO
	_game.hop_in(node)
	return node


func _gate(id: StringName) -> DepthGate:
	for b: Dictionary in _game.underground.generator.gate_bands:
		if (b.gate as DepthGate).id == id:
			return b.gate
	return null


func _band(i: int) -> Dictionary:
	return _game.underground.generator.gate_bands[i]


# --- tuning (data) ---------------------------------------------------------------------------------

func test_the_start_is_slow_and_every_upgrade_is_a_felt_jump() -> void:
	var t := DigTuning.get_default()
	var dirt := (load("res://data/blocks/dirt.tres") as BlockData).toughness
	var stone := (load("res://data/blocks/stone.tres") as BlockData).toughness
	# The starting shovel: several hits per dirt tile (it used to be one hit every 0.14 s).
	assert_int(t.hits_for(dirt, 0, -1)).is_greater_equal(3)
	assert_float(t.secs_for(dirt, 0, -1)).is_greater_equal(0.5)
	# Each Workshop level at least halves the time per tile.
	assert_float(t.secs_for(dirt, 1, -1)).is_less_equal(t.secs_for(dirt, 0, -1) * 0.5)
	assert_float(t.secs_for(stone, 2, -1)).is_less(t.secs_for(stone, 1, -1))
	# Vehicles: each tier hits harder than the one before; the Excavator beats the best shovel on stone.
	for tier in range(1, 4):
		assert_int(t.power_for(0, tier)).is_greater(t.power_for(0, tier - 1))
	assert_float(t.secs_for(stone, 0, 1)).is_less(t.secs_for(stone, 1, -1))


func test_every_block_has_hit_points_and_the_bands_are_the_toughest() -> void:
	var gate := load("res://data/blocks/gaterock.tres") as BlockData
	for id in Underground.BLOCK_ORDER:
		var b := load(Underground.BLOCK_DIR + String(id) + ".tres") as BlockData
		assert_int(b.toughness).override_failure_message("%s toughness" % id).is_greater_equal(1)
		if b.breakable:
			assert_int(gate.toughness).is_greater_equal(b.toughness)
	var hard := load("res://data/blocks/hardrock.tres") as BlockData
	assert_bool(hard.vehicle_only).is_true()
	assert_int(hard.haul).is_greater_equal(3)


# --- PT10-4 unlock bands ---------------------------------------------------------------------------

func test_a_band_of_gate_rock_spans_the_hill_over_every_layer_but_the_first() -> void:
	_make()
	await _physics(2)
	var gen := _game.underground.generator
	assert_int(gen.gate_bands.size()).is_equal(gen.layer_rows.size() - 1)
	var gate := _tile(&"gaterock")
	for b: Dictionary in gen.gate_bands:
		# The band ends on the first row of the layer it opens.
		assert_int(int(b.to) - 1).is_equal((gen.layer_rows[b.layer] as LayerData).depth_from)
		for y in range(b.from, b.to):
			for x in range(HillGenerator.EDGE, HillGenerator.WIDTH - HillGenerator.EDGE):
				if gen.base_tile(Vector2i(x, y)) != gate:
					fail("band %s has a gap at (%d, %d)" % [(b.gate as DepthGate).id, x, y])
					return


func test_no_hard_rock_just_under_a_band() -> void:
	_make()
	await _physics(2)
	var gen := _game.underground.generator
	var hard := _tile(&"hardrock")
	var seen := 0
	for b: Dictionary in gen.gate_bands:
		for y in range(b.to, b.to + HillGenerator.HARD_CLEAR - 1):
			for x in range(HillGenerator.EDGE, HillGenerator.WIDTH - HillGenerator.EDGE):
				assert_int(gen.base_tile(Vector2i(x, y))).is_not_equal(hard)
	for y in range(40, 120):
		for x in range(HillGenerator.EDGE, HillGenerator.WIDTH - HillGenerator.EDGE):
			if gen.base_tile(Vector2i(x, y)) == hard:
				seen += 1
	# Hard Rock is there to find in Clay and Stone.
	assert_int(seen).is_greater(40)


func test_what_opens_each_band() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	var pl := _join(P1, it)
	var feel := _game.underground.dig_feel
	var g1 := _gate(&"1_clay")
	var g2 := _gate(&"2_stone")
	var g3 := _gate(&"3_ice")
	var g4 := _gate(&"4_crystal")
	var g5 := _gate(&"5_bottom")
	for g in [g1, g2, g3, g4, g5]:
		assert_object(g).is_not_null()
		assert_bool(feel.gate_open_for(pl, g)).is_false()
	# The first Workshop opens Clay on foot (its signs glow); Stone still waits for a vehicle.
	Progress.add_building(&"workshop", Vector2i(40, 0))
	assert_bool(feel.gate_open_for(pl, g1)).is_true()
	assert_bool(feel.gate_earned(g1)).is_true()
	assert_bool(feel.gate_open_for(pl, g2)).is_false()
	# The Excavator breaks the Stone band; on foot it stays shut.
	_drive(P1, &"excavator", &"underground", Vector2(60 * 16.0, 50 * 16.0))
	assert_bool(feel.gate_open_for(pl, g2)).is_true()
	assert_bool(feel.gate_open_for(pl, g3)).is_false()
	_game.hop_out(pl, true)
	assert_bool(feel.gate_open_for(pl, g2)).is_false()
	# The Gnome crew's help opens the Ice band for everyone, on foot too.
	assert_bool(feel.gate_open_for(pl, g3)).is_false()
	_game.underground.story.free_crew()
	assert_bool(feel.gate_open_for(pl, g3)).is_true()
	# Crystal needs the Drill Rig; the Dragon Egg opens the Bottom for everyone.
	assert_bool(feel.gate_open_for(pl, g4)).is_false()
	assert_bool(feel.gate_open_for(pl, g5)).is_false()
	Progress.find_treasure(&"dragon_egg", P1)
	assert_bool(feel.gate_open_for(pl, g5)).is_true()


# --- PT10-4 the dig itself ---------------------------------------------------------------------------

func test_a_shovel_hit_cracks_and_the_third_pops_the_dirt() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	_join(P1, it)
	var pl := _room(P1, Rect2i(60, 12, 5, 3), 62)
	await _physics(10)
	var below := Vector2i(62, 15)
	var feel := _game.underground.dig_feel
	it.move = Vector2(0, 1)
	it.dig = true
	await _physics(3)
	assert_bool(_world().is_solid(below)).is_true()
	assert_float(feel.crack_of(below)).is_greater(0.0)
	var t := DigTuning.get_default()
	var secs := t.secs_for(3, 0, -1)
	await _physics(int(secs * 60.0) - 6)
	assert_bool(_world().is_solid(below)).override_failure_message("broke too soon").is_true()
	await _physics(10)
	assert_bool(_world().is_solid(below)).override_failure_message("never broke").is_false()
	assert_int(pl.backpack_count()).is_greater_equal(1)


func test_a_dig_at_open_air_is_heard_as_a_swing() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	_join(P1, it)
	var pl := _room(P1, Rect2i(56, 12, 14, 3), 58)
	await _physics(10)
	var cue := Audio.resolve_name("swing")
	assert_bool(Audio.has_cue(cue)).override_failure_message("swing resolves to a real file").is_true()
	Audio.reset_caps()
	assert_bool(Audio._last_start.has(cue)).is_false()
	# Stick right in a wide room: nothing solid in reach, so A swings at air.
	it.move = Vector2(1, 0)
	it.dig = true
	await _physics(3)
	assert_bool(pl.dig_targets(pl.aim_of(Vector2(1, 0))).is_empty()).override_failure_message("staged: air in reach").is_true()
	assert_bool(Audio._last_start.has(cue)).override_failure_message("a dig at open air is heard (A-01)").is_true()


func test_a_closed_band_bonks_and_shows_what_opens_it_then_opens() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	var b := _band(0)
	var top: int = b.from
	var w := _world()
	for y in range(top - 4, top - 1):
		for x in range(60, 66):
			w.set_tile(Vector2i(x, y), 0)
	for x in range(60, 66):
		w.set_tile(Vector2i(x, top - 1), _tile(&"dirt"))
	var pl := _join(P1, it)
	_game.place_player(P1, &"underground", Vector2(62.5 * 16.0, (top - 1) * 16.0 - 1.0))
	await _physics(10)
	it.move = Vector2(0, 1)
	it.dig = true
	await _physics(150)
	var cell := Vector2i(62, top)
	assert_bool(w.is_solid(cell)).is_true()
	assert_str(String(pl.need_hint())).is_equal("shovel_gold")
	var hints := HillHintLayer.for_player(_game, pl)
	assert_str(String(hints[0].icon)).is_equal("need:shovel_gold")
	# The Workshop goes up: the same dig goes through the band into Clay.
	Progress.add_building(&"workshop", Vector2i(40, 0))
	await _physics(240)
	assert_bool(w.is_solid(cell)).is_false()
	var row := w.shape.cell_at(w.to_local(pl.global_position)).y
	assert_int(row).is_greater_equal(int(b.to) - 1)


func test_a_step_up_into_a_closed_band_bonks_too() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	var b := _band(0)
	var w := _world()
	# Stand right under the band, in Clay: up + A must not carve the Gate Rock.
	var floor_row: int = b.to + 3
	for y in range(b.to, floor_row):
		for x in range(60, 64):
			w.set_tile(Vector2i(x, y), 0)
	var pl := _join(P1, it)
	_game.place_player(P1, &"underground", Vector2(61.5 * 16.0, floor_row * 16.0 - 1.0))
	await _physics(10)
	it.move = Vector2(0, -1)
	it.dig = true
	await _physics(60)
	for x in range(60, 64):
		assert_bool(w.is_solid(Vector2i(x, b.to - 1))).is_true()


func test_hard_rock_bonks_on_foot_and_is_a_big_haul_for_a_vehicle() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	_join(P1, it)
	var pl := _room(P1, Rect2i(58, 44, 12, 3), 63)
	var hard := _tile(&"hardrock")
	for y in range(44, 47):
		for x in range(65, 67):
			_world().set_tile(Vector2i(x, y), hard)
	pl.facing = 1
	await _physics(10)
	it.move = Vector2(1, 0)
	it.dig = true
	await _physics(90)
	assert_bool(_world().is_solid(Vector2i(65, 46))).is_true()
	assert_str(String(pl.need_hint())).is_equal("vehicle:front_loader")
	it.dig = false
	it.move = Vector2.ZERO
	_drive(P1, &"front_loader", &"underground", Vector2(61.5 * 16.0, 47 * 16.0 - 1.0))
	pl.facing = 1
	await _physics(10)
	var before := pl.backpack_count()
	it.move = Vector2(1, 0)
	it.dig = true
	await _physics(180)
	# Each Hard Rock tile is several stone at once.
	assert_int(pl.backpack_count() - before).is_greater_equal(4)
	assert_int(int(pl.backpack.get(&"stone", 0))).is_greater_equal(4)


# --- PT10-5 no tearing down the land by hand -----------------------------------------------------------

func test_scrub_by_hand_bonks_and_stays_the_loader_clears_it() -> void:
	_make()
	await _physics(2)
	var it := _intent()
	var pl := _join(P1, it)
	await _physics(2)
	var hv := _game.hillville
	var x := hv.nearest_scrub(float(Hillville.SHAFT_X) - 260.0)
	_game.place_player(P1, &"hillville", Vector2(x - 20.0, 0))
	pl.facing = 1
	await _physics(10)
	var left := hv.scrub_left()
	it.dig = true
	await _physics(3)
	it.dig = false
	await _physics(30)
	it.dig = true
	await _physics(3)
	it.dig = false
	await _physics(5)
	assert_int(hv.scrub_left()).is_equal(left)
	assert_str(String(pl.need_hint())).is_equal("vehicle:front_loader")
	assert_str(String(HillHintLayer.for_player(_game, pl)[0].icon)).is_equal("need:vehicle:front_loader")
	_drive(P1, &"front_loader", &"hillville", Vector2(x - 26.0, 0))
	pl.facing = 1
	await _physics(10)
	for i in 4:
		it.dig = true
		await _physics(3)
		it.dig = false
		await _physics(20)
	assert_int(hv.scrub_left()).is_less(left)


func test_the_demo_exemption_is_off_in_play() -> void:
	assert_bool(DigFeel.demo_open).is_false()
	assert_bool(HillPlayer.hand_clear).is_false()
