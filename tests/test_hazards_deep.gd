## The deep layers' comedy hazards (Hazards lane, 2026-11-10), in simulated physics time: ice
## glides (W-11) on foot and driving and stops once the Dragon Perch warms it; a slide ends in an
## ice hole and drifts gently a layer down (W-13); a lava pad bounces, bounded, and never hurts
## (W-14). Adding them moved none of the hazards placed before.
class_name TestHazardsDeep
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("hazards_deep")   # first: never the real profile, settings or picks file
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_hazards_deep.json"
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
	Save.profile = "test_hazards_deep"
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


func _hold(x: float) -> void:
	_intent[P1] = {"move": Vector2(x, 0), "dig": false, "jump": false, "book": false, "horn": false}


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
		"vehicles": Progress.vehicles.size(),
	}


func _cell_of(p: HillPlayer) -> Vector2i:
	var w := _game.underground.world
	return w.shape.cell_at(w.to_local(p.global_position) + Vector2(0, -4))


## The rink nearest the Ice landing (the one met first).
func _rink() -> Dictionary:
	var best := {}
	var bd := 1 << 20
	for ih in _game.underground.generator.ice_holes:
		var d := absi((ih.rink as Rect2i).get_center().x - HillGenerator.SHAFT_X) + (ih.rink as Rect2i).position.y
		if d < bd:
			bd = d
			best = ih
	return best


## Puts P1 near the far-from-hole end of the rink, facing the hole.
func _on_rink(ih: Dictionary) -> HillPlayer:
	var p := _game.player_node(P1)
	var rink: Rect2i = ih.rink
	var x := rink.position.x + 2 if int(ih.dir) > 0 else rink.end.x - 3
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(Vector2i(x, rink.end.y)))
	p.velocity = Vector2.ZERO
	p.facing = int(ih.dir)
	return p


# --- placement ---------------------------------------------------------------------------------

func test_ice_holes_and_lava_pockets_place_from_data_and_move_nothing_else() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var g := u.generator
	var ice := g._layer_index(&"ice")
	var crystal := g._layer_index(&"crystal")
	assert_int(g.ice_holes.size()).is_equal(3)
	assert_int(g.lava_pockets.size()).is_equal(4)
	for ih in g.ice_holes:
		var rink: Rect2i = ih.rink
		var hole: Rect2i = ih.hole
		var nest: Rect2i = ih.nest
		assert_int(ih.layer).is_equal(ice)
		# The rink's floor is ice up to the hole; the hole is wide enough for the Drill Rig.
		var floor_cells := range(rink.position.x, hole.position.x) if int(ih.dir) > 0 else range(hole.end.x, rink.end.x)
		for x in floor_cells:
			var def := u.world.tile_def(u.world.get_tile(Vector2i(x, rink.end.y)))
			assert_bool(def is BlockData and (def as BlockData).slippery).is_true()
		assert_float(hole.size.x * 16.0).is_greater(Vehicle.SIZES[&"drill_rig"].x)
		# The chute is open all the way down to a nest a layer down, on a solid floor.
		# PT10-4: except the Crystal band's Gate Rock across it (the Drill Rig opens it).
		for y in range(hole.position.y, hole.end.y):
			if not g.gate_band_at(y).is_empty():
				continue
			assert_bool(u.world.is_solid(Vector2i(hole.position.x + 1, y))).is_false()
		assert_int(g.layer_of_depth(nest.position.y)).is_equal(ice + 1)
		assert_bool(u.world.is_solid(Vector2i(nest.get_center().x, nest.end.y))).is_true()
	for lp in g.lava_pockets:
		var pool: Rect2i = lp.pool
		assert_int(lp.layer).is_equal(crystal)
		assert_bool(u.world.is_solid(Vector2i(pool.position.x, pool.end.y))).is_true()
		assert_bool(u.world.is_solid(pool.position)).is_false()
	# The rows placed before (cave-ins, pockets, boulders, treasures) are where they were without
	# the deep rows: those live on their own random stream.
	var old := HillGenerator.new()
	var ids := {}
	var palette := u.build_palette()
	for i in palette.size():
		ids[palette[i].id] = i
	old.configure(u.layers(), ids, Underground.load_rows(Underground.TREASURE_DIR))
	old.configure_hazards(Underground.load_rows(Underground.HAZARD_DIR).filter(
		func(h: HazardData) -> bool: return h.kind != &"ice_hole" and h.kind != &"lava_pocket"))
	old.setup(RectShape.new(Underground.WIDTH, Underground.HEIGHT), u.world_seed)
	assert_array(old.boulder_spots).is_equal(g.boulder_spots)
	assert_array(old.pockets).is_equal(g.pockets)
	assert_int(old.cave_ins.size()).is_equal(g.cave_ins.size())
	for i in old.cave_ins.size():
		assert_bool(old.cave_ins[i].rect == g.cave_ins[i].rect).is_true()
	assert_int(old.treasure_spots.size()).is_equal(g.treasure_spots.size())
	for i in old.treasure_spots.size():
		assert_bool(old.treasure_spots[i].rect == g.treasure_spots[i].rect).is_true()


# --- ice slide and hole ------------------------------------------------------------------------

func test_a_slide_on_ice_ends_in_a_hole_and_drifts_gently_a_layer_down() -> void:
	_make()
	var p := _join()
	p.keep_block(&"ice")
	Inventory.add(&"stone", 2)
	var u := _game.underground
	var ih := _rink()
	assert_bool(ih.is_empty()).is_false()
	# PT10-4: the Crystal band's Gate Rock crosses the chute until a Drill Rig breaks it; this case
	# is the slide and the drift, so the band is broken here (test_dig_progression covers the band).
	var hole: Rect2i = ih.hole
	for y in range(hole.position.y, hole.end.y):
		if not u.generator.gate_band_at(y).is_empty():
			for x in range(hole.position.x, hole.end.x):
				u.world.set_tile(Vector2i(x, y), 0)
	_on_rink(ih)
	await _physics(10)
	var before := _stats(p)
	var events := {"slid": 0, "dropped": 0, "nested": 0}
	u.hazards.slid.connect(func(_p: int) -> void: events.slid += 1)
	u.hazards.dropped.connect(func(_p: int, _h: int) -> void: events.dropped += 1)
	u.hazards.nested.connect(func(_p: int, _h: int) -> void: events.nested += 1)
	# Half a second's push toward the hole, then let go: the ice keeps them going.
	_hold(float(ih.dir))
	await _physics(48)
	_hold(0.0)
	var at_release := p.global_position.x
	await _physics(6)
	assert_bool(u.hazards.is_sliding(P1) or u.hazards.is_dropping(P1)).is_true()
	assert_float(absf(p.velocity.x)).is_greater(40.0)
	assert_int(events.slid).is_equal(1)
	# It ends in the hole; the drift down never goes faster than HOLE_FALL (plus one frame's pull).
	var fastest := [0.0]
	var n := await _until(func() -> bool:
		fastest[0] = maxf(fastest[0], p.velocity.y)
		return events.nested > 0, 900)
	assert_int(n).is_less(900)
	assert_float(absf(p.global_position.x - at_release)).is_greater(16.0)
	assert_int(events.dropped).is_equal(1)
	assert_float(fastest[0]).is_less_equal(Hazards.HOLE_FALL + 980.0 / 60.0 + 1.0)
	# A layer down, in the nest, standing, and nothing taken.
	var nest: Rect2i = ih.nest
	assert_bool(nest.grow(1).has_point(_cell_of(p))).is_true()
	assert_int(u.layer_index_at(u.world.to_local(p.global_position))).is_equal(int(ih.layer) + 1)
	assert_bool(u.hazards.is_dropping(P1) or u.hazards.is_sliding(P1)).is_false()
	assert_bool(u.hazards.is_stunned(P1) or u.hazards.is_trapped(P1)).is_false()
	var now := _stats(p)
	assert_int(now.backpack).is_equal(before.backpack)
	assert_int(now.capacity).is_equal(before.capacity)
	assert_dict(now.pile).is_equal(before.pile)


func test_a_vehicle_skates_into_the_hole_too() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var ih := _rink()
	_on_rink(ih)
	p.drive(load("res://data/vehicles/front_loader.tres"))
	await _physics(10)
	var dropped := [0]
	u.hazards.dropped.connect(func(_p: int, _h: int) -> void: dropped[0] += 1)
	_hold(float(ih.dir))
	await _physics(96)
	_hold(0.0)
	var n := await _until(func() -> bool: return dropped[0] > 0, 300)
	assert_int(n).is_less(300)
	assert_object(p.vehicle).is_not_null()


func test_warm_ice_does_not_slide_and_other_ground_never_does() -> void:
	_make()
	var p := _join()
	var u := _game.underground
	var ih := _rink()
	# Warm (the Dragon Perch stands): the stick is the stick again.
	var st := _game.story.state(Story.DRAGON)
	st.phase = ResidentState.Phase.RESTORED
	assert_bool(_game.story.ice_warm()).is_true()
	_on_rink(ih)
	await _physics(10)
	_hold(float(ih.dir))
	await _physics(30)
	_hold(0.0)
	await _physics(3)
	assert_float(absf(p.velocity.x)).is_less(1.0)
	assert_bool(u.hazards.is_sliding(P1)).is_false()
	# On plain ground (the Clay landing) a let-go stops at once too.
	st.phase = ResidentState.Phase.UNMET
	_game.place_player(P1, HillGame.UNDERGROUND, u.landing(u.generator._layer_index(&"clay")) + Vector2(-40, 0))
	p.velocity = Vector2.ZERO
	await _physics(10)
	_hold(-1.0)
	await _physics(20)
	_hold(0.0)
	await _physics(3)
	assert_float(absf(p.velocity.x)).is_less(1.0)


# --- lava ---------------------------------------------------------------------------------------

func test_lava_bounces_a_bounded_hop_and_never_hurts() -> void:
	_make()
	var p := _join()
	p.keep_block(&"crystal")
	Inventory.add(&"crystal", 3)
	var u := _game.underground
	var lp: Dictionary = u.generator.lava_pockets[0]
	var pool: Rect2i = lp.pool
	# The hop: visible (two tiles or more) and short (at most five tiles, under the room's roof).
	assert_float(u.hazards.hop_height()).is_between(32.0, 80.0)
	assert_float(u.hazards.hop_height()).is_less((lp.room as Rect2i).size.y * 16.0)
	_game.place_player(P1, HillGame.UNDERGROUND, _feet(Vector2i(pool.get_center().x, pool.end.y)))
	p.velocity = Vector2.ZERO
	var before := _stats(p)
	var hops := [0]
	u.hazards.bounced.connect(func(_p: int) -> void: hops[0] += 1)
	var floor_y := p.global_position.y
	var top := [floor_y]
	var n := await _until(func() -> bool:
		top[0] = minf(top[0], p.global_position.y)
		return hops[0] >= 3, 400)
	assert_int(n).is_less(400)
	# Every launch is LAVA_HOP and the peak stays within hop_height (plus a frame's step).
	assert_float(floor_y - top[0]).is_greater(24.0)
	assert_float(floor_y - top[0]).is_less_equal(u.hazards.hop_height() + 8.0)
	# No damage path: nothing taken, no stun, no trap, still here, still playing.
	assert_bool(u.hazards.is_stunned(P1) or u.hazards.is_trapped(P1)).is_false()
	assert_bool(is_instance_valid(p) and p.is_inside_tree()).is_true()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	var now := _stats(p)
	assert_int(now.backpack).is_equal(before.backpack)
	assert_int(now.capacity).is_equal(before.capacity)
	assert_dict(now.pile).is_equal(before.pile)
	# Walking off the pad ends the bouncing.
	_hold(1.0)
	await _physics(90)
	_hold(0.0)
	await _physics(40)
	var count: int = hops[0]
	await _physics(40)
	assert_int(hops[0]).is_equal(count)
	assert_bool(p.is_on_floor()).is_true()
