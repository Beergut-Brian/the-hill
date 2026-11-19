## PT-1119-1 "You can always get back out" (Kaden 2026-11-19: "if you dig a certain way it's
## basically impossible to get out since the elevator is at the top of each level").
## The trap-finder (TrapAudit) digs the shapes a player really makes and drives the player out with
## the real controls; the elevator stops at any row beside the shaft; the step carve climbs out of a
## locked gate band and round undiggable rock; the rope rescue (hold Y) always works, only with the
## hold; its hint shows only when stuck; two players get out on their own.
## The full matrix (every layer x every shape x climb / rope) is the `--trap-audit` run
## (handoff/trap-audit-after.log); here each shape runs once, the layers rotating so all are used.
class_name TestGetOut
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SUITE := "get_out"
const SHAFT := HillGenerator.SHAFT_X

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


func _idle() -> Dictionary:
	return {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}


func _join(p: int, intent: Dictionary) -> HillPlayer:
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


func _audit() -> TrapAudit:
	var a := TrapAudit.new()
	a.game = _game
	_game.add_child(a)
	return a


## Stages `shape` on `layer` and puts p's feet in it (re-placed once the chunks are in).
func _stage(a: TrapAudit, p: int, shape: String, layer: int) -> HillPlayer:
	var s := a.stage(shape, layer)
	var node := _game.player_node(p)
	for k in 3:
		_game.place_player(p, &"underground", s.feet)
		node.velocity = Vector2.ZERO
		await _physics(20)
		if node.global_position.distance_to(s.feet) < 3.0:
			break
	return node


# --- the trap-finder ------------------------------------------------------------------------------

func test_trap_finder_every_shape_gets_out_with_the_real_controls() -> void:
	_make()
	_join(P1, _idle())
	var a := _audit()
	var n := a.layer_count()
	var results: Array = []
	var i := 0
	for shape: String in TrapAudit.SHAPES:
		var layer := i % n
		if not a.applies(shape, layer):
			layer = (layer + 1) % (n - 1)
		if shape == "mole":
			layer = 1   # the Mole only takes shovels in Topsoil and Clay
		i += 1
		for mode in TrapAudit.MODES:
			results.append(await a.run_one(shape, layer, mode))
	print(TrapAudit.summary(results))
	for r: Dictionary in results:
		var label := "%s on layer %d by %s (%s)" % [r.shape, r.layer, r.mode, r.reason]
		assert_str(String(r.note)).override_failure_message("not staged: " + label).not_contains("could not")
		assert_bool(r.ok).override_failure_message("stuck: " + label).is_true()
		assert_float(r.secs).override_failure_message("too slow: " + label).is_less(20.0)


# --- (a) the elevator stops at any row beside the shaft -------------------------------------------

func test_a_beside_the_shaft_mid_layer_calls_the_car_to_that_row_and_rides_up() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	var a := _audit()
	var stone := 2
	node = await _stage(a, P1, "pit10_shaft", stone)
	node.intent_source = func() -> Dictionary: return it
	for k in 3:
		node.keep_block(&"stone")
	await _physics(3)
	var row := _game.elevator.stop_row_of(P1)
	var f := _game.underground.generator.landing_floor(stone)
	assert_int(row).is_equal(f + 10)
	assert_int(_game.elevator.prompt_of(P1)).is_equal(1)
	# A + down still digs (a kid digging a pit by the cage); A alone calls the car.
	it.move = Vector2(0, 1)
	await _physics(2)
	assert_int(_game.elevator.prompt_of(P1)).is_equal(0)
	it.move = Vector2.ZERO
	await _physics(2)
	it.dig = true
	await _physics(2)
	it.dig = false
	assert_bool(_game.elevator.is_riding(P1)).is_true()
	# The car comes down the rope to this row, between the landings.
	var want: float = _game.underground.shaft_pos_of_row(float(row))
	assert_float(want).is_greater(float(stone)).is_less(float(stone + 1))
	await _until(func() -> bool: return absf(_game.elevator.car_position() - want) < 0.01, 120)
	assert_float(_game.elevator.car_position()).is_equal_approx(want, 0.01)
	assert_float(_game.underground.find_child("ShaftRope", false, false).car_rect(want).end.y).is_equal_approx(row * 16.0 + 4.0, 0.5)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"hillville", 200)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_int(Inventory.count(&"stone")).is_equal(3)   # the backpack went on the pile as usual
	a.restore()


func test_the_shaft_cannot_be_dug_and_a_landing_room_is_still_the_cage() -> void:
	_make()
	var node := _join(P1, _idle())
	var u := _game.underground
	_game.place_player(P1, &"underground", u.landing(1))
	await _physics(5)
	var c := Vector2i(SHAFT, u.generator.landing_floor(1) + 5)
	var def := u.world.tile_def(u.world.get_tile(c)) as BlockData
	assert_bool(u.dig_feel.can_break(node, c, def)).is_false()
	assert_str(String(u.dig_feel.need_picture(c, def))).is_equal("shaft")
	# In a landing room the stop is the cage (no second stop beside it).
	assert_int(u.shaft_stop_at(u.landing(1) + Vector2(-20, 0))).is_equal(-1)
	assert_str(String(_game.elevator.cage_of(P1))).is_equal("u1")


# --- (b) the step carve ----------------------------------------------------------------------------

func test_a_step_carves_gate_rock_above_the_feet_but_never_digs_down_into_it() -> void:
	_make()
	var it := _idle()
	_join(P1, it)
	var a := _audit()
	var node := await _stage(a, P1, "gate", 1)
	node.intent_source = func() -> Dictionary: return it
	var u := _game.underground
	var band: Dictionary = u.generator.gate_bands[1]
	var feet_row := int(floor((node.global_position.y - 1.0) / 16.0))
	# Above the feet (the way out): a step may carve the band's rock.
	var above := Vector2i(int(node.global_position.x / 16.0) + 2, int(band.from))
	assert_int(int(band.from)).is_less(feet_row)
	assert_bool(node.step_cell_ok(above)).is_true()
	# Down into the next layer's band, from on top of it: still a bonk.
	a.restore()
	a._air(Rect2i(SHAFT - 31, int(band.from) - 2, 2, 2))
	_game.place_player(P1, &"underground", Vector2((SHAFT - 30) * 16.0, int(band.from) * 16.0 - 1.0))
	await _physics(10)
	assert_array(node.dig_targets(Vector2i(0, 1))).is_empty()
	a.restore()


func test_a_step_blocked_by_hard_rock_overhead_carves_sideways_instead() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	var u := _game.underground
	var w := u.world
	var hard := int(u.generator._ids[&"hardrock"])
	var dirt := int(u.generator._ids[&"dirt"])
	var cx := 60
	var cy := 20
	for y in range(cy - 6, cy + 3):
		for x in range(cx - 4, cx + 5):
			w.set_tile(Vector2i(x, y), dirt)
	for y in [cy - 3, cy - 2]:
		for x in range(cx - 4, cx + 5):
			w.set_tile(Vector2i(x, y), hard)
	w.set_tile(Vector2i(cx, cy - 1), 0)
	w.set_tile(Vector2i(cx, cy), 0)
	for k in 3:
		_game.place_player(P1, &"underground", Vector2((cx + 0.5) * 16.0, (cy + 1) * 16.0 - 1.0))
		node.velocity = Vector2.ZERO
		await _physics(20)
	u.dig_feel.tuning = DigTuning.instant()
	node.facing = 1
	it.move = Vector2(0, -1)
	await _physics(2)
	assert_bool(node.step_cell_ok(Vector2i(cx, cy - 2))).is_false()
	assert_bool(node.step_dig()).is_true()
	# The neighbour at body height went instead of nothing happening.
	assert_bool(w.is_solid(Vector2i(cx + 1, cy)) and w.is_solid(Vector2i(cx - 1, cy))).is_false()


# --- (c) the rope rescue -------------------------------------------------------------------------

func test_the_rope_never_fires_without_the_full_hold() -> void:
	_make()
	var it := _idle()
	_join(P1, it)
	var a := _audit()
	var node := await _stage(a, P1, "pit10", 0)
	node.intent_source = func() -> Dictionary: return it
	var at := node.global_position
	# Taps, and a hold let go at 1.0 s: the ring fills and drains, nothing else.
	for k in 4:
		it.horn = true
		await _physics(6)
		it.horn = false
		await _physics(10)
	it.horn = true
	await _physics(60)
	assert_float(_game.rescue.hold_of(P1)).is_greater(0.5).is_less(1.0)
	it.horn = false
	await _physics(120)
	assert_float(_game.rescue.hold_of(P1)).is_equal(0.0)
	assert_bool(_game.rescue.is_pulling(P1)).is_false()
	assert_bool(node.locked).is_false()
	assert_float(node.global_position.distance_to(at)).is_less(4.0)
	# Never automatic: standing stuck for ages does nothing by itself either.
	for k in 15:
		_game.rescue._track_stuck(P1, node, 1.0)
	await _physics(30)
	assert_bool(_game.rescue.stuck(P1)).is_true()
	assert_bool(_game.rescue.is_pulling(P1)).is_false()
	assert_float(node.global_position.distance_to(at)).is_less(4.0)
	assert_bool(_game.rescue.can_hold(node)).is_true()
	a.restore()


func test_the_rope_pulls_you_to_the_nearest_landing_above_with_the_backpack_and_a_skips() -> void:
	_make()
	var it := _idle()
	_join(P1, it)
	var a := _audit()
	var node := await _stage(a, P1, "tunnel", 2)
	node.intent_source = func() -> Dictionary: return it
	for k in 4:
		node.keep_block(&"stone")
	var pulled := []
	_game.rescue.pulled.connect(func(p: int, layer: int) -> void: pulled.append([p, layer]))
	it.horn = true   # held all the way through (see the end)
	var held := await _until(func() -> bool: return _game.rescue.is_pulling(P1), 200)
	assert_float(held / 60.0).is_between(RopeRescue.HOLD - 0.1, RopeRescue.HOLD + 0.2)
	assert_bool(node.locked).is_true()
	await _physics(5)
	# A skips the rest of the beat.
	it.dig = true
	var rest := await _until(func() -> bool: return not _game.rescue.is_pulling(P1), 200)
	it.dig = false
	assert_float(rest / 60.0).is_less(RopeRescue.PULL - RopeRescue.DROP_T)
	assert_array(pulled).is_equal([[P1, 2]])
	assert_float(node.global_position.distance_to(_game.underground.landing(2))).is_less(4.0)
	assert_int(node.backpack_count()).is_equal(4)
	assert_bool(node.locked).is_false()
	# In the cage: the A blinks, and the A held through the beat does not ride by itself.
	await _physics(3)
	assert_int(_game.elevator.prompt_of(P1)).is_equal(1)
	assert_bool(_game.elevator.is_riding(P1)).is_false()
	# Y still held from the start does not drop a second rope.
	await _physics(int(RopeRescue.HOLD * 60.0) + 20)
	assert_bool(_game.rescue.is_pulling(P1)).is_false()
	it.horn = false
	a.restore()


func test_the_rope_hint_shows_only_when_stuck() -> void:
	_make()
	var it := _idle()
	_join(P1, it)
	var a := _audit()
	var node := await _stage(a, P1, "pit10", 1)
	node.intent_source = func() -> Dictionary: return it
	var has_y := func() -> bool:
		for h in HillHintLayer.for_player(_game, node):
			if h.button == "y" and h.icon == &"rope_up":
				return true
		return false
	assert_bool(has_y.call()).is_false()
	for k in 9:
		_game.rescue._track_stuck(P1, node, 1.0)
	assert_bool(has_y.call()).is_false()
	for k in 2:
		_game.rescue._track_stuck(P1, node, 1.0)
	assert_bool(has_y.call()).is_true()
	# A tile higher: not stuck any more.
	node.global_position.y -= 20.0
	_game.rescue._track_stuck(P1, node, 0.016)
	assert_bool(has_y.call()).is_false()
	# Beside the shaft (the car reaches you) it never shows.
	a.restore()
	node = await _stage(a, P1, "pit10_shaft", 1)
	for k in 15:
		_game.rescue._track_stuck(P1, node, 1.0)
	assert_bool(has_y.call()).is_false()
	# The pause menu's help always shows it.
	var pm: Control = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pm)
	assert_object(pm.find_child("RopeHelp", true, false)).is_not_null()
	pm.free()
	a.restore()


# --- two players ---------------------------------------------------------------------------------

func test_two_players_get_out_on_their_own() -> void:
	_make()
	var i1 := _idle()
	var i2 := _idle()
	_join(P1, i1)
	_join(P2, i2)
	var a := _audit()
	var u := _game.underground
	# P1 in a pit far from the shaft in Clay, P2 at the bottom of a pit by the shaft in Stone.
	var n1 := await _stage(a, P1, "pit10", 1)
	var n2 := await _stage(a, P2, "pit10_shaft", 2)
	n1.intent_source = func() -> Dictionary: return i1
	n2.intent_source = func() -> Dictionary: return i2
	await _physics(3)
	# P1 holds Y; P2 is not pulled along, P2's car does not take P1.
	i1.horn = true
	await _until(func() -> bool: return _game.rescue.is_pulling(P1), 200)
	assert_bool(_game.rescue.is_pulling(P2)).is_false()
	i1.horn = false
	assert_int(_game.elevator.prompt_of(P2)).is_equal(1)
	i2.dig = true
	await _physics(2)
	i2.dig = false
	assert_bool(_game.elevator.is_riding(P2)).is_true()
	assert_bool(_game.elevator.is_riding(P1)).is_false()
	await _until(func() -> bool: return not _game.rescue.is_pulling(P1), 200)
	assert_float(n1.global_position.distance_to(u.landing(1))).is_less(4.0)
	await _physics(3)
	i1.dig = true
	await _physics(2)
	i1.dig = false
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"hillville" and _game.director.scene_of(P2) == &"hillville", 300)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_str(String(_game.director.scene_of(P2))).is_equal("hillville")
	a.restore()
