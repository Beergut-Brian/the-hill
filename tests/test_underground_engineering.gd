## C-22 underground engineering (hill-c22-underground-1, 2026-11-11), seeded and in simulated
## physics time over the real data: the boulder rule comes from data/blocks (BlockData.boulder_breaks)
## not from code, a break off a player's screen gives them a camera peek, walking up to a block that
## needs a vehicle pops that vehicle's picture, and for several seeds every gate band can be reached
## from the layer above's landing on foot or with the vehicle the gates before it already asked for.
class_name TestUndergroundEngineering
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const SEEDS := [Underground.DEFAULT_SEED, 1, 7, 424242, 20261111]

var _game: HillGame
var _u: Underground
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("underground_engineering")
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

func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A carved test room in Clay away from the shaft and the puzzles: `room` air, its floor row of
## `floor_id`. Returns the floor row's cells.
func _room(u: Underground, room: Rect2i, floor_id: StringName) -> Array[Vector2i]:
	var eye := Node2D.new()
	eye.position = Vector2(room.get_center()) * 16.0
	u.world.add_child(eye)
	u.world.track(eye)
	u.world.update_chunks()
	var tile := int(u.world.palette.find(u.blocks[floor_id]))
	var out: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y + 1):
		for x in range(room.position.x - 1, room.end.x + 1):
			var c := Vector2i(x, y)
			if y == room.end.y:
				u.world.set_tile(c, tile)
				out.append(c)
			elif x >= room.position.x and x < room.end.x:
				u.world.set_tile(c, 0)
	return out


func _drop_boulder(u: Underground, at: Vector2) -> FallingBody:
	var b := FallingBody.new()
	b.round = true
	b.size_px = Vector2.ONE * Underground.BOULDER_SIZE
	b.collision_mask = 1 | 2
	b.position = at
	u.world.add_child(b)
	return b


func _test_room() -> Rect2i:
	return Rect2i(30, 48, 12, 5)


# --- the rule is data --------------------------------------------------------------------------

func test_only_blocks_whose_data_says_so_break_under_a_boulder() -> void:
	# The data: Hard Rock breaks under a boulder, the plain layer blocks do not.
	assert_bool((load("res://data/blocks/hardrock.tres") as BlockData).boulder_breaks).is_true()
	for id in [&"dirt", &"clay", &"stone", &"gaterock", &"edgestone"]:
		assert_bool((load("res://data/blocks/%s.tres" % id) as BlockData).boulder_breaks) \
				.override_failure_message("%s breaks under boulders" % id).is_false()
	_u = load("res://scenes/levels/underground.tscn").instantiate()
	get_tree().root.add_child(_u)
	var room := _test_room()
	# A boulder dropped on a Stone floor: nothing breaks.
	var stone := _room(_u, room, &"stone")
	var b := _drop_boulder(_u, Vector2(room.get_center().x * 16.0, (room.position.y + 1) * 16.0))
	await _physics(90)
	for c in stone:
		assert_bool(_u.world.is_solid(c)).is_true()
	b.queue_free()
	# The same drop on Hard Rock: the cells under it crack away and the boulder falls on through.
	var broke: Array = []
	var cracked: Array = []
	_u.puzzles.broke_cells.connect(func(cells) -> void:
		broke.append_array(cells)
		cracked.append(_u.puzzles.cracks().size()))
	var hard := _room(_u, room, &"hardrock")
	b = _drop_boulder(_u, Vector2(room.get_center().x * 16.0, (room.position.y + 1) * 16.0))
	var floor_y := float(room.end.y * 16)
	await _physics(90)
	assert_array(broke).is_not_empty()
	for c: Vector2i in broke:
		assert_bool(hard.has(c)).is_true()
		assert_bool(_u.world.is_solid(c)).is_false()
	# Not the whole row: only under the boulder and boulder_reach along it.
	var reach := (load("res://data/blocks/hardrock.tres") as BlockData).boulder_reach
	assert_int(broke.size()).is_less_equal(3 + 2 * reach)
	assert_bool(_u.world.is_solid(Vector2i(room.position.x, room.end.y))).is_true()
	assert_float(b.position.y).is_greater(floor_y)
	# Each broken cell flashed a crack as it went.
	assert_int(int(cracked[0])).is_greater_equal(broke.size())
	b.queue_free()
	# Turn the rule on for Stone (data, not code): now Stone breaks too.
	var stone_def := _u.blocks[&"stone"] as BlockData
	stone_def.boulder_breaks = true
	broke.clear()
	_room(_u, Rect2i(room.position.x, room.position.y + 6, room.size.x, room.size.y), &"stone")
	b = _drop_boulder(_u, Vector2(room.get_center().x * 16.0, (room.position.y + 7) * 16.0))
	await _physics(90)
	stone_def.boulder_breaks = false
	assert_array(broke).is_not_empty()
	b.queue_free()


func test_a_pebble_only_clinks_on_hard_rock() -> void:
	_u = load("res://scenes/levels/underground.tscn").instantiate()
	get_tree().root.add_child(_u)
	var room := _test_room()
	var hard := _room(_u, room, &"hardrock")
	var broke: Array = []
	_u.puzzles.broke_cells.connect(func(cells) -> void: broke.append_array(cells))
	var p := FallingBody.new()
	p.size_px = Vector2(8, 8)
	p.round = true
	p.collision_mask = 1 | 2
	p.position = Vector2(room.get_center().x * 16.0, room.position.y * 16.0 + 6.0)
	_u.world.add_child(p)
	await _physics(90)
	assert_array(broke).is_empty()
	for c in hard:
		assert_bool(_u.world.is_solid(c)).is_true()
	p.queue_free()


# --- seen, felt, never hidden ------------------------------------------------------------------

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


func test_a_wall_breaking_off_screen_gives_a_camera_peek_and_near_it_does_not() -> void:
	_make()
	var node := _join()
	var u := _game.underground
	var wall: Dictionary = u.generator.walls[0]
	var slab: Rect2i = wall.slab
	var mid := (Vector2(slab.position) + Vector2(slab.size) * 0.5) * 16.0
	# Far: the Topsoil landing is well off the screen from a Clay wall.
	_game.place_player(P1, HillGame.UNDERGROUND, u.landing(0))
	await _physics(5)
	assert_bool(u.puzzles.break_wall(0)).is_true()
	assert_int(u.puzzles.peeks.size()).is_equal(1)
	assert_int(int(u.puzzles.peeks[0].player)).is_equal(P1)
	await _physics(30)
	var pk := _game.camera.peek_of(P1)
	assert_float(pk.length()).is_greater(32.0)
	# It points at the break and eases home again.
	assert_float(pk.normalized().dot((mid - u.world.to_local(node.global_position)).normalized())).is_greater(0.9)
	await _physics(120)
	assert_float(_game.camera.peek_of(P1).length()).is_less(0.5)
	# Near: a Hard Rock break right beside the player needs no peek.
	u.puzzles.peeks.clear()
	var feet := u.world.shape.cell_at(u.world.to_local(node.global_position) + Vector2(0, -4))
	var c := feet + Vector2i(3, 1)
	u.world.set_tile(c, int(u.world.palette.find(u.blocks[&"hardrock"])))
	u.puzzles.break_cells([c])
	assert_array(u.puzzles.peeks).is_empty()
	assert_bool(u.world.is_solid(c)).is_false()


func test_walking_up_to_hard_rock_on_foot_pops_the_vehicle_that_breaks_it() -> void:
	_make()
	var node := _join()
	var u := _game.underground
	_game.place_player(P1, HillGame.UNDERGROUND, u.landing(1))
	await _physics(20)
	assert_str(String(node.need_hint())).is_equal("")
	# A Hard Rock block beside the player at feet height, the side they face.
	var feet := u.world.to_local(node.global_position)
	node.facing = 1
	var c := u.world.shape.cell_at(feet + Vector2(12.0, -6.0))
	u.world.set_tile(c, int(u.world.palette.find(u.blocks[&"hardrock"])))
	await _physics(3)
	var def := u.blocks[&"hardrock"] as BlockData
	var want := u.dig_feel.need_picture(c, def)
	assert_str(String(want)).starts_with("vehicle:")
	assert_str(String(u.dig_feel.walk_up_need(node))).is_equal(String(want))
	assert_str(String(node.need_hint())).is_equal(String(want))
	# Turned away: nothing to show.
	node.facing = -1
	assert_str(String(u.dig_feel.walk_up_need(node))).is_equal("")


# --- a route to every gate ---------------------------------------------------------------------

## A generator configured exactly as Underground._ready does.
func _gen(p_seed: int) -> HillGenerator:
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
	g.configure_puzzles(Underground.load_rows(Underground.PUZZLE_DIR))
	g.configure_block_depths(host.blocks)
	g.configure_gates(Underground.load_rows(Underground.GATE_DIR), int(ids.get(&"gaterock", 0)), int(ids.get(&"hardrock", -1)))
	g.setup(RectShape.new(Underground.WIDTH, Underground.HEIGHT), p_seed)
	g.set_meta("palette", palette)
	return g


## True when `tile` can be dug (or walked) by someone on foot (tier < 0) or in a vehicle of `tier`.
static func _passable(g: HillGenerator, palette: Array, cell: Vector2i, tier: int) -> bool:
	var t := g.base_tile(cell)
	if t == 0:
		return true
	var def := palette[t] as BlockData
	if def == null or not def.breakable or def.id == &"gaterock":
		return false
	if g.vehicle_block_at(cell) >= 0:
		return false
	if tier < 0:
		return not def.vehicle_only and def.dig_tier <= 0
	return def.dig_tier <= tier


## Flood from `start` (a cell) through passable cells, rows top..bottom only; true when a cell
## on row `goal_row` is reached.
static func _reaches(g: HillGenerator, palette: Array, start: Vector2i, goal_row: int, top: int, tier: int) -> bool:
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if c.y == goal_row:
			return true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n.y < top or n.y > goal_row or seen.has(n) or g.is_edge(n):
				continue
			if not _passable(g, palette, n, tier):
				continue
			seen[n] = true
			q.append(n)
	return false


func test_every_gate_band_has_a_route_on_foot_or_with_the_vehicle_already_needed() -> void:
	for s: int in SEEDS:
		var g := _gen(s)
		var palette: Array = g.get_meta("palette")
		assert_int(g.gate_bands.size()).is_greater(0)
		var tier := -1   # on foot, the first time down
		for band: Dictionary in g.gate_bands:
			var li: int = band.layer
			var room: Rect2i = g.landings[li - 1]
			var start := Vector2i(room.position.x + 1, room.end.y - 1)
			var top := room.position.y
			var goal: int = int(band.from) - 1
			var foot := _reaches(g, palette, start, goal, top, -1)
			var ok := foot or (tier >= 0 and _reaches(g, palette, start, goal, top, tier))
			assert_bool(ok).override_failure_message("seed %d: no route from landing %d to the %s band (vehicle tier %d)"
					% [s, li - 1, (band.gate as DepthGate).id, tier]).is_true()
			# The check bites: on foot nobody gets past the band itself (Gate Rock), so a route that
			# skips a gate would show as a failure here.
			assert_bool(_reaches(g, palette, start, int(band.to), top, -1)).is_false()
			# After this band the player has what opened it: a vehicle of its tier (if it asked for one).
			var gate := band.gate as DepthGate
			if gate.shovel_level <= 0:
				tier = maxi(tier, gate.vehicle_tier)
