## Kid-safe hazards and the residents' behaviour (Gameplay lane, 2026-11-10), in simulated physics
## time: hazard rows place from data, darkness comes from data, a bonk / float / cave-in never takes
## anything, a trapped player is always free within Hazards.TRAP_MAX, residents never block a path,
## the Caveman's thaw and the Dragon's reveal fire once and save, the crew cheers and marches.
class_name TestHazardsResidents
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
	Save.settings_path = "user://test_settings_hazards.json"
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
	Save.profile = "test_hazards"
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


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


## Carves an air room and stands P1's feet on its floor at `cell`.
func _stage(room: Rect2i, cell: Vector2i) -> HillPlayer:
	var w := _game.underground.world
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.set_tile(Vector2i(x, y), 0)
	var p := _game.player_node(P1)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2((cell.x + 0.5) * 16.0, (cell.y + 1) * 16.0 - 1.0))
	p.velocity = Vector2.ZERO
	return p


## Everything a hazard must never take: the backpack, capacity, vehicle, pile, progress.
func _stats(p: HillPlayer) -> Dictionary:
	return {
		"backpack": p.backpack_count(), "capacity": p.capacity(), "vehicle": p.vehicle,
		"pile": Inventory.to_save().duplicate(), "treasures": Progress.treasures.size(),
		"deepest": Progress.deepest_of(P1), "vehicles": Progress.vehicles.size(),
	}


func _assert_nothing_lost(before: Dictionary, now: Dictionary) -> void:
	assert_int(now.backpack).is_greater_equal(before.backpack)
	assert_int(now.capacity).is_greater_equal(before.capacity)
	assert_object(now.vehicle).is_same(before.vehicle)
	for b in before.pile:
		assert_int(int(now.pile.get(b, 0))).is_greater_equal(int(before.pile[b]))
	assert_int(now.treasures).is_greater_equal(before.treasures)
	assert_int(now.deepest).is_greater_equal(before.deepest)
	assert_int(now.vehicles).is_greater_equal(before.vehicles)


# --- data --------------------------------------------------------------------------------------

func test_hazard_rows_place_per_layer_with_a_few_near_the_first_landings() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	var g := u.generator
	var rows := Underground.load_rows(Underground.HAZARD_DIR)
	assert_int(rows.size()).is_greater_equal(5)
	var want := {&"cave_in": 0, &"water_pocket": 1}
	for h: HazardData in rows:
		assert_str(String(h.id)).is_not_empty()
		assert_int(g._layer_index(h.layer)).is_greater_equal(0)
		if want.has(h.kind):
			want[h.kind] += h.count
	assert_int(g.cave_ins.size()).is_equal(want[&"cave_in"])
	assert_int(g.pockets.size()).is_equal(want[&"water_pocket"])
	assert_bool(g.pockets[0] == g.pocket).is_true()
	# The first ten minutes (Topsoil and Clay) meet a few, not many: at least one cave-in and one
	# boulder near the Topsoil landing, and no more than a handful of hazards in those two layers.
	var near_cave := 0
	for c in g.cave_ins:
		var r: Rect2i = c.rect
		assert_bool(r.position.y >= 0 and r.end.y <= HillGenerator.STRANGE_FROM).is_true()
		if c.layer == 0 and absi(r.position.x - HillGenerator.SHAFT_X) <= HillGenerator.NEAR_X.y + r.size.x:
			near_cave += 1
	assert_int(near_cave).is_greater_equal(1)
	var shallow := 0
	for r in g.boulder_spots:
		if r.position.y < 70:
			shallow += 1
	shallow += g.cave_ins.filter(func(c: Dictionary) -> bool: return c.layer <= 1).size()
	shallow += g.pockets.filter(func(r: Rect2i) -> bool: return r.position.y < 70).size()
	assert_int(shallow).is_between(4, 16)
	# Every pocket starts full of water.
	for r: Rect2i in g.pockets:
		assert_bool(g.base_water(r.get_center())).is_true()


func test_darkness_values_load_from_data() -> void:
	var u: Underground = auto_free(load("res://scenes/levels/underground.tscn").instantiate())
	add_child(u)
	for l: LayerData in u.layers():
		var mid := (l.depth_from + mini(l.depth_to, Underground.HEIGHT)) / 2
		assert_float(u.world.darkness_at(mid)).is_equal_approx(l.darkness, 0.0001)
	var top: LayerData = load("res://data/layers/topsoil.tres")
	var clay: LayerData = load("res://data/layers/clay.tres")
	assert_float(top.darkness).is_equal_approx(0.3, 0.0001)
	assert_float(clay.darkness).is_equal_approx(0.6, 0.0001)


# --- hazards -----------------------------------------------------------------------------------

func test_a_falling_boulder_bonks_briefly_and_takes_nothing() -> void:
	_make()
	var p := _join(P1)
	p.keep_block(&"dirt")
	Inventory.add(&"clay", 3)
	var u := _game.underground
	var r: Rect2i = u.generator.boulder_spots[0]
	_stage(Rect2i(r.position.x - 3, r.end.y, 6, 5), Vector2i(r.position.x + 1, r.end.y + 4))
	var before := _stats(p)
	var hits := [0]
	u.hazards.bonked.connect(func(_p: int) -> void: hits[0] += 1)
	var n := await _until(func() -> bool: return hits[0] > 0, 240)
	assert_int(hits[0]).is_equal(1)
	assert_int(n).is_less(240)
	# The stun is under a second, and while it lasts the player's input reads idle.
	_intent[P1] = {"move": Vector2(1, 0), "dig": false, "jump": false, "book": false, "horn": false}
	assert_bool(u.hazards.is_stunned(P1)).is_true()
	assert_dict(p.intent()).is_equal(IDLE)
	var stunned := await _until(func() -> bool: return not u.hazards.is_stunned(P1), 120)
	assert_int(stunned).is_less(60)
	assert_dict(p.intent()).is_equal(_intent[P1])
	_assert_nothing_lost(before, _stats(p))


func test_a_breached_pocket_floats_the_player_and_takes_nothing() -> void:
	_make()
	var p := _join(P1)
	p.keep_block(&"clay")
	var u := _game.underground
	var pocket := u.generator.pocket
	var row := pocket.end.y - 1
	_stage(Rect2i(pocket.position.x - 6, row - 1, 5, 2), Vector2i(pocket.position.x - 2, row))
	var before := _stats(p)
	var floated := [false]
	u.hazards.floated.connect(func(_p: int) -> void: floated[0] = true)
	_intent[P1] = {"move": Vector2(1, 0), "dig": true, "jump": false, "book": false, "horn": false}
	await _until(func() -> bool: return floated[0], 360)
	assert_bool(floated[0]).is_true()
	_intent[P1] = IDLE.duplicate()
	var y0 := p.global_position.y
	await _physics(90)
	# Afloat: the water lifts rather than sinks.
	assert_float(p.global_position.y).is_less_equal(y0 + 2.0)
	_assert_nothing_lost(before, _stats(p))


func test_digging_into_a_cave_in_traps_then_the_mole_frees_in_time() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var z: Dictionary = u.generator.cave_ins[0]
	var r: Rect2i = z.rect
	var floor_y := r.end.y - 2
	_stage(Rect2i(r.position.x - 5, floor_y - 1, 5, 2), Vector2i(r.position.x - 1, floor_y))
	await _physics(10)
	var before := _stats(p)
	var by_mole := [false]
	u.hazards.freed.connect(func(_p: int, m: bool) -> void: by_mole[0] = m)
	_intent[P1] = {"move": Vector2(1, 0), "dig": true, "jump": false, "book": false, "horn": false}
	await _until(func() -> bool: return u.hazards.is_trapped(P1), 120)
	assert_bool(u.hazards.is_trapped(P1)).is_true()
	_intent[P1] = IDLE.duplicate()
	var before_free := _stats(p)
	var n := await _until(func() -> bool: return not u.hazards.is_trapped(P1), int(Hazards.TRAP_MAX * 60) + 5)
	assert_int(n).is_less_equal(int(Hazards.TRAP_MAX * 60))
	assert_bool(by_mole[0]).is_true()
	# The way back is open again: the cell left of the pocket is air.
	var pocket := u.hazards.body_cells(p)
	assert_bool(u.world.is_solid(pocket.position + Vector2i(-1, 0))).is_false()
	_assert_nothing_lost(before, _stats(p))
	_assert_nothing_lost(before_free, _stats(p))
	# The Mole goes home afterwards.
	await _until(func() -> bool: return not u.residents.is_rescuing(), 240)
	assert_vector(u.residents.mole.position).is_equal(u.residents.mole_home)


func test_a_trapped_player_is_free_within_trap_max_even_without_the_mole() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	u.residents.mole = null
	var at := u.landing(1)
	# A little tunnel off the Clay landing, away from the room (cave-ins never fill rooms).
	var c := Vector2i(int(at.x / 16.0) + 12, int(at.y / 16.0))
	_stage(Rect2i(c.x - 2, c.y - 1, 5, 2), c)
	await _physics(10)
	var before := _stats(p)
	assert_bool(u.hazards.cave_in(p)).is_true()
	assert_bool(u.hazards.is_trapped(P1)).is_true()
	var n := await _until(func() -> bool: return not u.hazards.is_trapped(P1), int(Hazards.TRAP_MAX * 60) + 30)
	assert_int(n).is_less_equal(int(Hazards.TRAP_MAX * 60) + 2)
	_assert_nothing_lost(before, _stats(p))


# --- residents ---------------------------------------------------------------------------------

func test_residents_have_no_collision_and_keep_to_their_rooms() -> void:
	_make()
	_join(P1)
	var u := _game.underground
	var res := u.residents
	for s in [res.mole, res.foreman, res.caveman, res.dragon]:
		assert_object(s).is_not_null()
		assert_bool(s is CollisionObject2D).is_false()
		for n in s.find_children("*", "CollisionObject2D", true, false):
			assert_object(n).is_null()
	# The Mole shuffles for a while: always inside the Topsoil landing room's air, never in rock.
	var room: Rect2i = u.generator.landings[0]
	for i in 20:
		await _physics(30)
		var cell := Vector2i(int(res.mole.position.x / 16.0), int(res.mole.position.y / 16.0) - 1)
		assert_bool(room.has_point(cell)).is_true()
		assert_bool(u.world.is_solid(cell)).is_false()
	# Up top, the crew and the Caveman have no collision either.
	for s in _game.town.find_children("*", "CollisionObject2D", true, false):
		assert_object(s).is_null()


func test_the_caveman_thaws_once_and_it_saves() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var met := [0]
	var on_met := func(id: StringName, _n: int) -> void:
		if id == &"caveman":
			met[0] += 1
	Events.resident_encountered.connect(on_met)
	var ice := 3
	_game.place_player(P1, HillGame.UNDERGROUND, u.landing(ice) + Vector2(40, 0))
	p.velocity = Vector2.ZERO
	await _until(func() -> bool: return u.residents.caveman_state() != &"frozen", int((UndergroundResidents.THAW_SECS + 1.0) * 60))
	assert_str(String(u.residents.caveman_state())).is_equal("thawing")
	assert_bool(_game.story.is_thawed()).is_true()
	assert_int(_game.story.phase(&"caveman")).is_equal(ResidentState.Phase.ARRIVED)
	assert_bool(u.residents.thaw()).is_false()
	await _physics(60 * 6)
	assert_str(String(u.residents.caveman_state())).is_equal("gone")
	assert_int(met[0]).is_equal(1)
	# Up top he waits by the fire.
	assert_bool(_game.town.caveman_here()).is_true()
	Events.resident_encountered.disconnect(on_met)
	_game.save.save_now()
	_game.free()
	Players.reset()
	_make(true)
	_join(P1)
	assert_bool(_game.story.is_thawed()).is_true()
	assert_str(String(_game.underground.residents.caveman_state())).is_equal("gone")
	assert_bool(_game.underground.residents.caveman.visible).is_false()
	await _physics(2)
	assert_bool(_game.town.caveman_here()).is_true()


func test_the_dragon_reveal_plays_once_and_it_saves() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var d := u.residents.dragon
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(d.position.x - 120.0, HillGenerator.CAVERN.end.y * 16.0 - 2.0))
	p.velocity = Vector2.ZERO
	var shown := [0]
	u.residents.dragon_revealed.connect(func() -> void: shown[0] += 1)
	await _until(func() -> bool: return shown[0] > 0, 30)
	assert_int(shown[0]).is_equal(1)
	assert_bool(_game.story.dragon_met()).is_true()
	# A first meeting, not the arrival (the full Dragon arc is later).
	assert_int(_game.story.phase(&"dragon")).is_equal(ResidentState.Phase.ENCOUNTERED)
	await _until(func() -> bool: return u.residents.dragon_state() == &"asleep", int(UndergroundResidents.REVEAL_TIME * 60) + 10)
	assert_str(String(u.residents.dragon_state())).is_equal("asleep")
	assert_vector(d.scale).is_equal(Vector2.ONE)
	# Still standing beside her: no second reveal.
	await _physics(120)
	assert_int(shown[0]).is_equal(1)
	_game.save.save_now()
	_game.free()
	Players.reset()
	_make(true)
	var p2 := _join(P1)
	var u2 := _game.underground
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(u2.residents.dragon.position.x - 120.0, HillGenerator.CAVERN.end.y * 16.0 - 2.0))
	p2.velocity = Vector2.ZERO
	await _physics(60)
	assert_str(String(u2.residents.dragon_state())).is_equal("asleep")
	assert_bool(u2.residents.reveal()).is_false()


func test_the_crew_cheers_at_a_delivery_and_marches_past_a_new_building() -> void:
	_make()
	_join(P1)
	var town := _game.town
	await _physics(70)
	var cheers := [0]
	town.cheered.connect(func() -> void: cheers[0] += 1)
	# One block (a scoop) is not a delivery; a ride's dump is.
	Inventory.add(&"dirt", 1)
	await _physics(30)
	assert_int(cheers[0]).is_equal(0)
	for i in 6:
		Inventory.add(&"dirt", 1)
	await _physics(30)
	assert_int(cheers[0]).is_equal(1)
	var marched := [&""]
	town.marched.connect(func(id: StringName) -> void: marched[0] = id)
	Progress.add_building(&"barn", Vector2i(46, 0))
	await _until(func() -> bool: return town.is_marching(), 200)
	assert_str(String(marched[0])).is_equal("barn")
	await _until(func() -> bool: return not town.is_marching(), 60 * 20)
	assert_bool(town.is_marching()).is_false()
	await _physics(2)
	assert_float(town.foreman.position.x).is_equal_approx(TownResidents.CREW_X + TownResidents.CREW_SIZE * TownResidents.CREW_GAP, 0.5)
