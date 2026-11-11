## C-22 underground engineering puzzles (Underground engineering lane, 2026-11-11), seeded and in
## simulated physics time: the boulder wall and the Front Loader block place from data/puzzles per
## seed (and move nothing else), a boulder dropped on the wall breaks it and a pebble does not, the
## hand, the Mole and another vehicle cannot clear the block (the Front Loader bubble shows), and the
## Front Loader clears it through its normal dig.
class_name TestPuzzles
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const SEED := Underground.DEFAULT_SEED

var _game: HillGame
var _u: Underground
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("puzzles")   # first: never the real profile, settings or picks file
	Game.quit_exits = false


func after() -> void:
	Game.quit_exits = true
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = {P1: IDLE.duplicate()}


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_u):
		_u.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)


# --- helpers -----------------------------------------------------------------------------------

## A generator configured exactly as Underground._ready does (puzzle rows optional).
func _gen(p_seed: int, with_puzzles := true) -> HillGenerator:
	var host: Underground = auto_free(Underground.new())
	var palette := host.build_palette()
	var ids := {}
	for i in palette.size():
		ids[palette[i].id] = i
	var layers := Underground.load_rows(Underground.LAYER_DIR)
	layers.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	var g := HillGenerator.new()
	g.configure(layers, ids, Underground.load_rows(Underground.TREASURE_DIR))
	g.configure_hazards(Underground.load_rows(Underground.HAZARD_DIR))
	g.configure_block_depths(host.blocks)
	if with_puzzles:
		g.configure_puzzles(Underground.load_rows(Underground.PUZZLE_DIR))
	g.setup(RectShape.new(Underground.WIDTH, Underground.HEIGHT), p_seed)
	return g


## An Underground in the tree on its own (no players), with the chunks round `cell` loaded.
func _underground_at_wall() -> Underground:
	_u = load("res://scenes/levels/underground.tscn").instantiate()
	get_tree().root.add_child(_u)
	var slab: Rect2i = _u.generator.walls[0].slab
	var eye := Node2D.new()
	eye.position = Vector2(slab.get_center()) * 16.0
	_u.world.add_child(eye)
	_u.world.track(eye)
	_u.world.update_chunks()
	return _u


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


func _hold(move: Vector2, dig := false) -> void:
	_intent[P1] = {"move": move, "dig": dig, "jump": false, "book": false, "horn": false}


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The block's row, the side of it the shaft is on (+1 right), and a carved room there with P1's
## feet (on foot or in `vehicle`) right beside the block, facing it.
func _beside_block(vehicle: StringName = &"") -> Dictionary:
	var u := _game.underground
	var row: Dictionary = u.generator.vehicle_blocks[0]
	var r: Rect2i = row.rect
	var side := 1 if r.position.x < HillGenerator.SHAFT_X else -1
	var room := Rect2i(r.end.x, r.position.y - 1, 9, r.size.y + 1) if side > 0 else Rect2i(r.position.x - 9, r.position.y - 1, 9, r.size.y + 1)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			u.world.set_tile(Vector2i(x, y), 0)
	var node := _join()
	var reach := 0.5 if vehicle == &"" else 1.5
	var feet := Vector2(((r.end.x + reach) if side > 0 else (r.position.x - reach)) * 16.0, r.end.y * 16.0 - 1.0)
	if vehicle != &"":
		if not Progress.has_vehicle(vehicle):
			Progress.vehicles.append(vehicle)
		var old: Vehicle = _game.vehicles.get(vehicle)
		if old != null and old.is_inside_tree():
			old.get_parent().remove_child(old)
			_game.vehicles.erase(vehicle)
			old.queue_free()
		_game.park_new(vehicle, feet, HillGame.UNDERGROUND)
	_game.place_player(P1, HillGame.UNDERGROUND, feet)
	node.velocity = Vector2.ZERO
	if vehicle != &"":
		assert_bool(_game.hop_in(node)).is_true()
		assert_str(String(node.vehicle.id)).is_equal(String(vehicle))
	node.facing = -side
	return {"row": row, "side": side, "node": node}


# --- placement ---------------------------------------------------------------------------------

func test_same_seed_gives_the_same_placement_and_moves_nothing_else() -> void:
	var a := _gen(SEED)
	var b := _gen(SEED)
	assert_int(a.walls.size()).is_equal(1)
	assert_int(a.vehicle_blocks.size()).is_equal(1)
	assert_str(str(a.walls)).is_equal(str(b.walls))
	assert_str(str(a.vehicle_blocks)).is_equal(str(b.vehicle_blocks))
	# Data, not hard-coded: the rows' layer (Clay) and the Front Loader, near the Clay landing.
	var clay := -1
	for i in a.layer_rows.size():
		if (a.layer_rows[i] as LayerData).id == &"clay":
			clay = i
	assert_int(int(a.walls[0].layer)).is_equal(clay)
	assert_int(int(a.vehicle_blocks[0].layer)).is_equal(clay)
	assert_str(String(a.vehicle_blocks[0].vehicle)).is_equal("front_loader")
	var bx: int = (a.vehicle_blocks[0].rect as Rect2i).get_center().x
	assert_int(absi(bx - HillGenerator.SHAFT_X)).is_less_equal(HillGenerator.NEAR_X.y + 2)
	# The slab is its row's block (data: Hard Rock, which boulders break), the block is a cell
	# nobody digs (the border tile), the pillar is plain ground.
	var slab: Rect2i = a.walls[0].slab
	var slab_def := load("res://data/blocks/%s.tres" % a.walls[0].block) as BlockData
	assert_bool(slab_def.boulder_breaks).is_true()
	for x in range(slab.position.x, slab.end.x):
		assert_int(a.base_tile(Vector2i(x, slab.position.y))).is_equal(int(a._ids[a.walls[0].block]))
	var r: Rect2i = a.vehicle_blocks[0].rect
	assert_int(a.base_tile(r.position)).is_equal(a.border_tile)
	assert_int(a.base_tile((a.walls[0].pillar as Rect2i).position)).is_not_equal(a.border_tile)
	assert_int(a.base_tile((a.walls[0].pillar as Rect2i).position)).is_greater(0)
	# The wall's boulder rests on the pillar.
	var spot: Rect2i = a.walls[0].boulder_rect
	assert_int(spot.end.y).is_equal((a.walls[0].pillar as Rect2i).position.y)
	# Another seed puts them somewhere else.
	var c := _gen(SEED + 1)
	assert_bool(str(c.walls) == str(a.walls) and str(c.vehicle_blocks) == str(a.vehicle_blocks)).is_false()
	# Without the puzzle rows every earlier placement is exactly where it was.
	var plain := _gen(SEED, false)
	assert_int(plain.walls.size()).is_equal(0)
	assert_str(str(plain.boulder_spots)).is_equal(str(a.boulder_spots))
	assert_str(str(plain.pockets)).is_equal(str(a.pockets))
	assert_str(str(plain.cave_ins)).is_equal(str(a.cave_ins))
	assert_str(str(plain.treasure_spots)).is_equal(str(a.treasure_spots))
	assert_str(str(plain.ice_holes)).is_equal(str(a.ice_holes))
	assert_str(str(plain.lava_pockets)).is_equal(str(a.lava_pockets))
	# And every cell outside the puzzles' footprints is the same tile.
	var moved := 0
	for y in range(20, 140, 1):
		for x in range(0, Underground.WIDTH, 3):
			var cell := Vector2i(x, y)
			var inside := (a.walls[0].rect as Rect2i).grow(2).has_point(cell) or r.grow(2).has_point(cell)
			if not inside and a.base_tile(cell) != plain.base_tile(cell):
				moved += 1
	assert_int(moved).is_equal(0)


# --- the boulder wall --------------------------------------------------------------------------

func test_wall_breaks_under_a_boulder_and_not_under_a_pebble() -> void:
	var u := _underground_at_wall()
	var wall: Dictionary = u.generator.walls[0]
	var slab: Rect2i = wall.slab
	var room: Rect2i = wall.room
	var broke: Array = []
	u.puzzles.wall_broke.connect(func(i: int) -> void: broke.append(i))
	await _physics(5)
	# On foot nobody digs the slab (a vehicle-only block: the bonk shows a vehicle picture).
	var def := u.world.tile_def(u.world.get_tile(slab.position)) as BlockData
	assert_bool(def.vehicle_only and def.boulder_breaks).is_true()
	assert_str(String(u.dig_feel.need_picture(slab.position, def))).starts_with("vehicle:")
	# A pebble dropped from the room's ceiling onto the slab: it lands hard, the wall stays.
	var pebble := FallingBody.new()
	pebble.size_px = Vector2(8, 8)
	pebble.round = true
	pebble.collision_mask = 1 | 2
	pebble.position = Vector2((room.position.x + 0.5) * 16.0, room.position.y * 16.0 + 6.0)
	var landed := []
	u.world.body_landed.connect(func(b: Node2D, speed: float) -> void:
		if b == pebble:
			landed.append(speed))
	u.world.add_child(pebble)
	for i in 120:
		await get_tree().physics_frame
		if not landed.is_empty():
			break
	assert_array(landed).is_not_empty()
	assert_float(float(landed[0])).is_greater_equal(def.boulder_min_speed)
	await _physics(10)
	assert_bool(u.puzzles.wall_standing(0)).is_true()
	assert_array(broke).is_empty()
	# Dig the pillar away: the boulder drops onto the slab and breaks it open.
	var boulder: FallingBody = u.boulders[int(wall.boulder)]
	var start_y := boulder.position.y
	var pillar: Rect2i = wall.pillar
	var cells: Array[Vector2i] = []
	for y in range(pillar.position.y, pillar.end.y):
		for x in range(pillar.position.x, pillar.end.x):
			cells.append(Vector2i(x, y) - pillar.position)
	u.world.dig(pillar.position, cells, P1)
	for i in 180:
		await get_tree().physics_frame
		if not broke.is_empty():
			break
	assert_array(broke).is_equal([0])
	assert_bool(u.puzzles.wall_standing(0)).is_false()
	for x in range(slab.position.x, slab.end.x):
		assert_bool(u.world.is_solid(Vector2i(x, slab.position.y))).is_false()
	# The cause shows: a dust puff and cracks over the wall, and the boulder carries on down into the chamber.
	assert_array(u.puzzles.puffs()).is_not_empty()
	assert_array(u.puzzles.cracks()).is_not_empty()
	await _physics(60)
	assert_float(boulder.position.y).is_greater(start_y + 16.0)
	assert_float(boulder.position.y).is_greater(slab.position.y * 16.0)
	# Breaking twice does nothing.
	assert_bool(u.puzzles.break_wall(0)).is_false()


# --- the Front Loader block --------------------------------------------------------------------

func test_the_block_is_not_cleared_by_hand_the_mole_or_another_vehicle() -> void:
	_make()
	var u := _game.underground
	var st := _beside_block()
	var node: HillPlayer = st.node
	var r: Rect2i = st.row.rect
	await _physics(10)
	# The Front Loader bubble shows to a player on foot next to it.
	assert_str(String(u.puzzles.vehicle_hint(node))).is_equal("front_loader")
	await _physics(20)
	assert_float(u.puzzles.bubble_of(0)).is_greater(0.5)
	# The hand: dig at it for a second, it stays and takes no hit.
	_hold(Vector2(-int(st.side), 0), true)
	await _physics(60)
	_hold(Vector2.ZERO)
	assert_bool(u.puzzles.block_standing(0)).is_true()
	assert_int(u.puzzles.hits_of(0)).is_equal(0)
	assert_int(node.backpack_count()).is_equal(0)
	# The Mole (and anything else digging with no player): blocked too.
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			u.world.dig(Vector2i(x, y), [Vector2i.ZERO], -1)
	assert_bool(u.puzzles.block_standing(0)).is_true()
	u.hazards.free_player(P1)
	assert_bool(u.puzzles.block_standing(0)).is_true()
	# Another vehicle (the Excavator, a higher dig tier) only bounces too, and still sees the hint.
	_game.free()
	Players.reset()
	_make()
	u = _game.underground
	st = _beside_block(&"excavator")
	node = st.node
	await _physics(5)
	assert_str(String(u.puzzles.vehicle_hint(node))).is_equal("front_loader")
	_hold(Vector2(-int(st.side), 0), true)
	await _physics(90)
	_hold(Vector2.ZERO)
	assert_bool(u.puzzles.block_standing(0)).is_true()
	assert_int(u.puzzles.hits_of(0)).is_equal(0)


func test_the_front_loader_clears_the_block_with_its_own_dig() -> void:
	_make()
	var u := _game.underground
	var st := _beside_block(&"front_loader")
	var node: HillPlayer = st.node
	var row: Dictionary = st.row
	var hits: Array = []
	var cleared: Array = []
	u.puzzles.block_hit.connect(func(_i: int, p: int, left: int) -> void: hits.append([p, left]))
	u.puzzles.block_cleared.connect(func(i: int, p: int) -> void: cleared.append([i, p]))
	await _physics(5)
	# In the right vehicle there is no hint: it is the one that does the job.
	assert_str(String(u.puzzles.vehicle_hint(node))).is_equal("")
	var bag := node.backpack_count()
	_hold(Vector2(-int(st.side), 0), true)
	for i in 180:
		await get_tree().physics_frame
		if not cleared.is_empty():
			break
	_hold(Vector2.ZERO)
	assert_array(cleared).is_equal([[0, P1]])
	# One hit per dig, `hits` digs in all, the last one clears it.
	assert_int(hits.size()).is_equal(int(row.hits))
	assert_int(int(hits.back()[1])).is_equal(0)
	assert_bool(u.puzzles.block_standing(0)).is_false()
	var r: Rect2i = row.rect
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			assert_bool(u.world.is_solid(Vector2i(x, y))).is_false()
	# It gives its stone into the Loader's backpack, with a puff.
	assert_int(node.backpack_count()).is_equal(bag + int(row.gives_count))
	assert_int(int(node.backpack.get(row.gives, 0))).is_greater_equal(int(row.gives_count))
	assert_bool(u.puzzles.clear_block(0, node)).is_false()
