## Lava pockets (W-14, hill-lava-1): placed by the generator from data/hazards at a fixed count per
## seed (same seed, same pools), and a bounce that is an upward impulse only: no damage, a 1 s
## "hot" flame on the player, a small camera kick, and it happens with no shovel too.
class_name TestLava
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("lava")   # first: never the real profile, settings or picks file
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_lava.json"
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
	Save.profile = "test_lava"
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


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


func _feet(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * 16.0, cell.y * 16.0 - 1.0)


func _stats(p: HillPlayer) -> Dictionary:
	return {
		"backpack": p.backpack_count(), "capacity": p.capacity(), "vehicle": p.vehicle,
		"pile": Inventory.to_save().duplicate(), "treasures": Progress.treasures.size(),
		"vehicles": Progress.vehicles.size(), "shovel": p.has_shovel,
	}


## A generator built from the real layer and hazard data with world seed `s`.
func _gen(u: Underground, s: int) -> HillGenerator:
	var g := HillGenerator.new()
	var ids := {}
	var palette := u.build_palette()
	for i in palette.size():
		ids[palette[i].id] = i
	g.configure(u.layers(), ids, Underground.load_rows(Underground.TREASURE_DIR))
	g.configure_hazards(Underground.load_rows(Underground.HAZARD_DIR))
	g.setup(RectShape.new(Underground.WIDTH, Underground.HEIGHT), s)
	return g


func _lava_row() -> HazardData:
	for h: HazardData in Underground.load_rows(Underground.HAZARD_DIR):
		if h.kind == &"lava_pocket":
			return h
	return null


# --- placement: density and seed ---------------------------------------------------------------

func test_lava_pockets_are_crystal_layer_data() -> void:
	var row := _lava_row()
	assert_object(row).is_not_null()
	assert_str(String(row.layer)).is_equal("crystal")
	assert_int(row.count).is_greater(0)
	var crystal: LayerData = load("res://data/layers/crystal.tres")
	assert_bool(crystal.hazards.has(&"lava")).is_true()


func test_lava_density_is_fixed_and_the_same_seed_gives_the_same_pockets() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var row := _lava_row()
	var crystal_li := u.generator._layer_index(&"crystal")
	var crystal: LayerData = u.generator.layer_rows[crystal_li]
	var by_seed := {}
	for s in [11, 4242, 90001]:
		var a := _gen(u, s)
		var b := _gen(u, s)
		# Fixed density: the data row's count, every seed.
		assert_int(a.lava_pockets.size()).is_equal(row.count)
		# Same seed, same pockets.
		assert_int(b.lava_pockets.size()).is_equal(a.lava_pockets.size())
		for i in a.lava_pockets.size():
			assert_bool(a.lava_pockets[i].room == b.lava_pockets[i].room).is_true()
			assert_bool(a.lava_pockets[i].pool == b.lava_pockets[i].pool).is_true()
		for lp in a.lava_pockets:
			var room: Rect2i = lp.room
			assert_int(lp.layer).is_equal(crystal_li)
			assert_int(room.position.y).is_greater_equal(crystal.depth_from)
			assert_int(room.end.y).is_less_equal(crystal.depth_to)
		by_seed[s] = a.lava_pockets.map(func(lp: Dictionary) -> Rect2i: return lp.pool)
	# Different seeds move them (not one fixed layout dressed as random).
	assert_bool(by_seed[11] == by_seed[4242] and by_seed[4242] == by_seed[90001]).is_false()


# --- the bounce --------------------------------------------------------------------------------

func test_a_bounce_is_an_upward_impulse_and_shows_hot_for_a_second() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var pool: Rect2i = u.generator.lava_pockets[0].pool
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(Vector2i(pool.position.x, pool.end.y)))
	p.velocity = Vector2(30.0, 0.0)
	assert_bool(u.hazards.is_hot(P1)).is_false()
	u.hazards.bounce(p)
	# Straight up at LAVA_HOP, the sideways speed kept.
	assert_float(p.velocity.y).is_equal(-Hazards.LAVA_HOP)
	assert_float(p.velocity.x).is_equal(30.0)
	assert_bool(u.hazards.is_hot(P1)).is_true()
	# The camera beat on the cause.
	var kick := get_tree().get_first_node_in_group(ScreenKick.GROUP) as ScreenKick
	if kick != null and SettingsPanel.screen_shake():
		assert_bool(kick.active(P1)).is_true()
	# The flame goes after HOT_SECS (moved off the pool so it does not bounce again).
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(Vector2i(pool.position.x - 3, pool.end.y)))
	var n := await _until(func() -> bool: return not u.hazards.is_hot(P1), 120)
	assert_int(n).is_between(40, 70)
	assert_float(Hazards.HOT_SECS).is_equal(1.0)


func test_standing_in_lava_takes_nothing() -> void:
	_make()
	var p := _join()
	p.keep_block(&"crystal")
	Inventory.add(&"crystal", 3)
	var u := _game.underground
	var pool: Rect2i = u.generator.lava_pockets[0].pool
	var before := _stats(p)
	var hops := [0]
	u.hazards.bounced.connect(func(_p: int) -> void: hops[0] += 1)
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(Vector2i(pool.get_center().x, pool.end.y)))
	p.velocity = Vector2.ZERO
	var n := await _until(func() -> bool: return hops[0] >= 3, 400)
	assert_int(n).is_less(400)
	assert_dict(_stats(p)).is_equal(before)
	assert_bool(u.hazards.is_stunned(P1) or u.hazards.is_trapped(P1)).is_false()
	assert_bool(is_instance_valid(p) and p.is_inside_tree()).is_true()
	assert_int(Game.state).is_equal(Game.State.PLAYING)


func test_a_player_with_no_shovel_still_bounces() -> void:
	_make()
	var p := _join()
	p.has_shovel = false
	var u := _game.underground
	var pool: Rect2i = u.generator.lava_pockets[0].pool
	var hops := [0]
	u.hazards.bounced.connect(func(_p: int) -> void: hops[0] += 1)
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(Vector2i(pool.get_center().x, pool.end.y)))
	p.velocity = Vector2.ZERO
	var n := await _until(func() -> bool: return hops[0] >= 1, 120)
	assert_int(n).is_less(120)
	assert_bool(u.hazards.is_hot(P1)).is_true()
	assert_bool(p.has_shovel).is_false()
