## C-22 underground engineering puzzles (Puzzles lane, 2026-11-10): placed from data/puzzles on
## their own stream (nothing placed before moved), and each one solvable from a fresh save by
## replaying the stick-and-A input a five-year-old would use, in simulated physics time. Nothing
## is ever taken; every solve gives a gift.
class_name TestPuzzles
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
	Save.settings_path = "user://test_settings_puzzles.json"
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
	Save.profile = "test_puzzles"
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


func _make() -> HillGame:
	_game = HillGame.new()
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


func _press(x: float, dig: bool) -> void:
	_intent[P1] = {"move": Vector2(x, 0), "dig": dig, "jump": false, "book": false, "horn": false}


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


## Stands P1 with their feet on the floor under `cell`.
func _stand(cell: Vector2i, facing: int) -> HillPlayer:
	var p := _game.player_node(P1)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2((cell.x + 0.5) * 16.0, (cell.y + 1) * 16.0 - 1.0))
	p.velocity = Vector2.ZERO
	p.facing = facing
	return p


func _stats(p: HillPlayer) -> Dictionary:
	return {
		"backpack": p.backpack_count(), "capacity": p.capacity(), "vehicle": p.vehicle,
		"pile": Inventory.to_save().duplicate(), "treasures": Progress.treasures.size(),
		"vehicles": Progress.vehicles.size(),
	}


func _assert_nothing_lost(before: Dictionary, now: Dictionary) -> void:
	assert_int(now.backpack).is_greater_equal(before.backpack)
	assert_int(now.capacity).is_greater_equal(before.capacity)
	assert_object(now.vehicle).is_same(before.vehicle)
	for b in before.pile:
		assert_int(int(now.pile.get(b, 0))).is_greater_equal(int(before.pile[b]))
	assert_int(now.treasures).is_greater_equal(before.treasures)
	assert_int(now.vehicles).is_greater_equal(before.vehicles)


func _total(p: HillPlayer) -> int:
	var n := p.backpack_count()
	var pile: Dictionary = Inventory.to_save()
	for k in pile:
		n += int(pile[k])
	return n


func _puzzle(kind: StringName) -> Dictionary:
	for pz in _game.underground.generator.puzzles:
		if pz.kind == kind:
			return pz
	return {}


func _solid(w: TileWorld, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if w.is_solid(Vector2i(x, y)):
				return true
	return false


func _wet(w: TileWorld, r: Rect2i) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if w.has_water(Vector2i(x, y)):
				n += 1
	return n


# --- placement ---------------------------------------------------------------------------------

func test_puzzles_place_from_data_and_move_nothing_else() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var g := u.generator
	var kinds := {}
	for pz in g.puzzles:
		kinds[pz.kind] = pz
		var row := load(Underground.PUZZLE_DIR + String(pz.id) + ".tres") as PuzzleData
		assert_int(pz.layer).is_equal(g._layer_index(row.layer))
		var r: Rect2i = pz.rect
		assert_int(g.layer_of_depth(r.position.y)).is_equal(pz.layer)
		assert_int(g.layer_of_depth(r.end.y - 1)).is_equal(pz.layer)
	assert_array(kinds.keys()).contains_exactly_in_any_order([&"drain", &"boulder_wall", &"heavy_block"])
	assert_str(String(g.layer_rows[kinds[&"drain"].layer].id)).is_equal("clay")
	assert_str(String(g.layer_rows[kinds[&"boulder_wall"].layer].id)).is_equal("stone")
	assert_str(String(g.layer_rows[kinds[&"heavy_block"].layer].id)).is_equal("topsoil")
	# The drain: a full pocket, a diggable wall, a plug, a sump bigger than the pocket.
	var d: Dictionary = kinds[&"drain"]
	var pocket: Rect2i = d.pocket
	var sump: Rect2i = d.sump
	assert_int(_wet(u.world, pocket)).is_equal(pocket.get_area())
	assert_int(sump.get_area()).is_greater(pocket.get_area())
	assert_int(_wet(u.world, sump)).is_equal(0)
	var wall_def := u.world.tile_def(u.world.get_tile((d.wall as Rect2i).position))
	assert_bool(wall_def.breakable).is_true()
	assert_str(String(u.world.tile_def(u.world.get_tile((d.plug as Rect2i).position)).id)).is_equal("drain_plug")
	# The water can reach the chute: every pocket cell within flow_reach of it.
	assert_int((d.chute as Rect2i).position.x - pocket.position.x).is_less_equal(u.world.flow_reach)
	# The boulder: on its strut, over a drop onto the cracked wall.
	var b: Dictionary = kinds[&"boulder_wall"]
	assert_str(String(u.world.tile_def(u.world.get_tile((b.strut as Rect2i).position)).id)).is_equal("strut")
	assert_str(String(u.world.tile_def(u.world.get_tile((b.crack as Rect2i).position)).id)).is_equal("cracked_wall")
	assert_bool(u.world.tile_def(u.world.get_tile((b.crack as Rect2i).position)).breakable).is_false()
	assert_bool(u.puzzles.boulders.has(g.puzzles.find(b))).is_true()
	# The heavy block plugs a tunnel a Dump Truck fits in.
	var h: Dictionary = kinds[&"heavy_block"]
	assert_str(String(u.world.tile_def(u.world.get_tile((h.block as Rect2i).position)).id)).is_equal("heavy_stone")
	assert_float((h.tunnel as Rect2i).size.y * 16.0).is_greater(Vehicle.SIZES[&"dump_truck"].y)
	assert_float((h.tunnel as Rect2i).size.x * 16.0).is_greater(Vehicle.SIZES[&"dump_truck"].x)
	# Everything placed before (landings, treasures, boulders, pockets, cave-ins, ice holes, lava)
	# is where it was without the puzzle rows, and so is every tile away from the puzzles.
	var old := HillGenerator.new()
	var ids := {}
	var palette := u.build_palette()
	for i in palette.size():
		ids[palette[i].id] = i
	old.configure(u.layers(), ids, Underground.load_rows(Underground.TREASURE_DIR))
	old.configure_hazards(Underground.load_rows(Underground.HAZARD_DIR))
	# Same block depths as Underground (sand's depth_from): only the puzzle rows are left out.
	old.configure_block_depths(u.blocks)
	old.setup(RectShape.new(Underground.WIDTH, Underground.HEIGHT), u.world_seed)
	assert_int(old.puzzles.size()).is_equal(0)
	assert_array(old.landings).is_equal(g.landings)
	assert_array(old.boulder_spots).is_equal(g.boulder_spots)
	assert_array(old.pockets).is_equal(g.pockets)
	assert_int(old.cave_ins.size()).is_equal(g.cave_ins.size())
	for i in old.cave_ins.size():
		assert_bool(old.cave_ins[i].rect == g.cave_ins[i].rect).is_true()
	assert_int(old.treasure_spots.size()).is_equal(g.treasure_spots.size())
	for i in old.treasure_spots.size():
		assert_bool(old.treasure_spots[i].rect == g.treasure_spots[i].rect).is_true()
	assert_int(old.ice_holes.size()).is_equal(g.ice_holes.size())
	for i in old.ice_holes.size():
		assert_bool(old.ice_holes[i].rink == g.ice_holes[i].rink).is_true()
	assert_int(old.lava_pockets.size()).is_equal(g.lava_pockets.size())
	for i in old.lava_pockets.size():
		assert_bool(old.lava_pockets[i].room == g.lava_pockets[i].room).is_true()
	var away: Array[Rect2i] = []
	for pz in g.puzzles:
		away.append((pz.rect as Rect2i).grow(3))
	var moved := 0
	for y in range(0, Underground.HEIGHT, 2):
		for x in range(0, Underground.WIDTH, 2):
			var c := Vector2i(x, y)
			if away.any(func(r: Rect2i) -> bool: return r.has_point(c)):
				continue
			if old.base_tile(c) != g.base_tile(c) or old.base_water(c) != g.base_water(c):
				moved += 1
	assert_int(moved).is_equal(0)


# --- 1. drain the pocket -----------------------------------------------------------------------

func test_drain_dig_the_channel_open_the_plug_and_the_water_runs_away() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var pz := _puzzle(&"drain")
	var i := u.generator.puzzles.find(pz)
	var nook: Rect2i = pz.nook
	_stand(Vector2i(nook.end.x - 1, nook.end.y - 1), -1)
	await _physics(10)
	assert_bool(u.puzzles.is_solved(i)).is_false()
	var before := _stats(p)
	var total := _total(p)
	var got := [-2]
	u.puzzles.solved.connect(func(k: int, who: int) -> void:
		if k == i:
			got[0] = who)
	# Left + A: the dirt wall goes, the pocket spills into the nook.
	_press(-1.0, true)
	await _until(func() -> bool: return not _solid(u.world, pz.wall), 120)
	assert_bool(_solid(u.world, pz.wall)).is_false()
	_intent[P1] = IDLE.duplicate()
	await _physics(30)
	assert_int(_wet(u.world, nook)).is_greater(0)
	# Right + A: the plug opens, the water runs down the chute into the sump.
	_press(1.0, true)
	await _until(func() -> bool: return not _solid(u.world, pz.plug), 240)
	assert_bool(_solid(u.world, pz.plug)).is_false()
	_intent[P1] = IDLE.duplicate()
	await _until(func() -> bool: return u.puzzles.is_solved(i), 900)
	assert_bool(u.puzzles.is_solved(i)).is_true()
	assert_int(_wet(u.world, pz.pocket)).is_equal(0)
	assert_int(_wet(u.world, pz.sump)).is_greater(0)
	assert_int(got[0]).is_equal(P1)
	_assert_nothing_lost(before, _stats(p))
	assert_int(_total(p)).is_greater_equal(total + (pz.data as PuzzleData).gift)


# --- 2. drop the boulder on the cracked wall ---------------------------------------------------

func test_boulder_knock_the_strut_out_and_the_boulder_breaks_the_wall() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var pz := _puzzle(&"boulder_wall")
	var i := u.generator.puzzles.find(pz)
	var nook: Rect2i = pz.nook
	var crack: Rect2i = pz.crack
	_stand(Vector2i(nook.end.x - 1, nook.end.y - 1), 1)
	await _physics(10)
	var before := _stats(p)
	var total := _total(p)
	# A shovel bounces off the cracked wall: hand digging it does nothing.
	var bounced := [0]
	u.world.dig_blocked.connect(func(_c: Vector2i, b: StringName, _p: int) -> void:
		if b == &"cracked_wall":
			bounced[0] += 1)
	u.world.dig(crack.position, [Vector2i.ZERO], P1)
	assert_int(bounced[0]).is_equal(1)
	assert_bool(_solid(u.world, crack)).is_true()
	# Right + A: the strut is knocked out, the boulder drops and breaks the wall.
	var boulder: FallingBody = u.puzzles.boulders[i]
	var y0 := boulder.position.y
	_press(1.0, true)
	await _until(func() -> bool: return not _solid(u.world, pz.strut), 120)
	assert_bool(_solid(u.world, pz.strut)).is_false()
	_intent[P1] = IDLE.duplicate()
	await _until(func() -> bool: return u.puzzles.is_solved(i), 600)
	assert_bool(u.puzzles.is_solved(i)).is_true()
	assert_bool(_solid(u.world, crack)).is_false()
	# It lands in the room under the wall, where the gift was.
	await _physics(20)
	await _until(func() -> bool: return boulder.sleeping, 300)
	assert_float(boulder.position.y).is_greater(y0 + 8 * 16.0)
	_assert_nothing_lost(before, _stats(p))
	assert_int(_total(p)).is_greater_equal(total + (pz.data as PuzzleData).gift)


# --- 3. the block that needs a vehicle ---------------------------------------------------------

func _try_heavy(vehicle: StringName) -> Dictionary:
	var p := _game.player_node(P1)
	var u := _game.underground
	var pz := _puzzle(&"heavy_block")
	var block: Rect2i = pz.block
	if vehicle != &"":
		p.drive(Progress.vehicle_data(vehicle))
	var w := Vehicle.body_size(p.vehicle).x / 16.0
	_stand(Vector2i(block.position.x - int(ceil(w * 0.5)) - 1, block.end.y - 1), 1)
	await _physics(10)
	_press(1.0, true)
	await _physics(90)
	_intent[P1] = IDLE.duplicate()
	await _physics(10)
	return {"solid": _solid(u.world, block)}


func test_heavy_block_bounces_a_hand_and_the_loader_lifts_it_out() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var pz := _puzzle(&"heavy_block")
	var i := u.generator.puzzles.find(pz)
	var heavy := [0]
	u.puzzles.too_heavy.connect(func(k: int, _p: int) -> void:
		if k == i:
			heavy[0] += 1)
	var before := _stats(p)
	# By hand: bounces, the Loader picture pops, nothing moves, nothing is lost.
	var r: Dictionary = await _try_heavy(&"")
	assert_bool(r.solid).is_true()
	assert_int(heavy[0]).is_greater(0)
	assert_bool(u.puzzles.is_solved(i)).is_false()
	_assert_nothing_lost(before, _stats(p))
	# The Excavator cannot lift it either.
	var by_hand: int = heavy[0]
	r = await _try_heavy(&"excavator")
	assert_bool(r.solid).is_true()
	assert_int(heavy[0]).is_greater(by_hand)
	assert_bool(u.puzzles.is_solved(i)).is_false()
	p.stop_driving()
	# The Front Loader (the first vehicle) lifts it out: stone and the gift go in the bag.
	var total := _total(p)
	r = await _try_heavy(&"front_loader")
	assert_bool(r.solid).is_false()
	assert_bool(u.puzzles.is_solved(i)).is_true()
	assert_int(_total(p)).is_greater_equal(total + Puzzles.HEAVY_BLOCKS + (pz.data as PuzzleData).gift)


func test_heavy_block_the_dump_truck_lifts_it_too_and_a_reload_knows_it_is_solved() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var pz := _puzzle(&"heavy_block")
	var i := u.generator.puzzles.find(pz)
	var r: Dictionary = await _try_heavy(&"dump_truck")
	assert_bool(r.solid).is_false()
	assert_bool(u.puzzles.is_solved(i)).is_true()
	# A reload reads it from the saved tiles, with no second gift.
	var gifts := [0]
	u.puzzles.solved.connect(func(_k: int, _p: int) -> void: gifts[0] += 1)
	var saved := u.world.to_save()
	u.world.load_save(saved)
	u.puzzles.done[i] = false
	u.after_load()
	assert_bool(u.puzzles.is_solved(i)).is_true()
	await _physics(20)
	assert_int(gifts[0]).is_equal(0)
	assert_object(p.vehicle).is_not_null()
