## H-09: both players drive different vehicles at once (Two-vehicles lane, 2026-11-10). P1 drives
## the Excavator and P2 the Front Loader on the same underground layer: both move and dig in the
## same frames, neither takes the other's pad, the camera keeps both (one camera close, split far),
## a bystander keeps their powers and boards a free vehicle with B, and each driven vehicle carries
## its driver's stripe row (green / red).
class_name TestTwoDrivers
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const EXC := &"excavator"
const LOADER := &"front_loader"
## A long, 4-tall room on one layer (cells), floor at row 18.
const ROOM := Rect2i(30, 14, 70, 4)
const FLOOR_Y := 18 * 16.0 - 1.0

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}
var _dug := {}


func before() -> void:
	SuiteSandbox.enter("two_drivers")   # first: never the real profile, settings or picks file
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_two_drivers.json"
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
	Save.profile = "test_two_drivers"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = {P1: IDLE.duplicate(), P2: IDLE.duplicate()}
	_dug = {P1: 0, P2: 0}


func after_test() -> void:
	if Events.tile_dug.is_connected(_on_dug):
		Events.tile_dug.disconnect(_on_dug)
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Save.wipe()
	Game._set_state(Game.State.LOBBY)


func _on_dug(_cell: Vector2i, _block: StringName, p: int) -> void:
	_dug[p] = int(_dug.get(p, 0)) + 1


# --- set-up ------------------------------------------------------------------------------------

func _make() -> HillGame:
	_game = HillGame.new()
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	Events.tile_dug.connect(_on_dug)
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


func _hold(p: int, move: Vector2, dig := false, jump := false) -> void:
	_intent[p] = {"move": move, "dig": dig, "jump": jump, "book": false, "horn": false}


func _carve(room: Rect2i) -> void:
	var w := _game.underground.world
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.set_tile(Vector2i(x, y), 0)


## Parks vehicle `id` underground at cell column `cx` (the Loader's existing node is moved down).
func _park_below(id: StringName, cx: int) -> Vehicle:
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	var at := Vector2(cx * 16.0 + 8.0, FLOOR_Y)
	var v: Vehicle = _game.vehicles.get(id)
	if v == null:
		return _game.park_new(id, at, HillGame.UNDERGROUND)
	if v.get_parent() != null:
		v.get_parent().remove_child(v)
	v.position = at
	_game._park(v, HillGame.UNDERGROUND)
	return v


## Both players on the same layer: P1 in the Excavator at column `c1`, P2 in the Loader at `c2`.
func _two_drivers(c1: int, c2: int) -> Array[HillPlayer]:
	_make()
	_carve(ROOM)
	var a := _join(P1)
	var b := _join(P2)
	_park_below(EXC, c1)
	_park_below(LOADER, c2)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(c1 * 16.0 + 8.0, FLOOR_Y))
	_game.place_player(P2, HillGame.UNDERGROUND, Vector2(c2 * 16.0 + 8.0, FLOOR_Y))
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	assert_bool(_game.hop_in(a)).is_true()
	assert_bool(_game.hop_in(b)).is_true()
	assert_that(a.vehicle.id).is_equal(EXC)
	assert_that(b.vehicle.id).is_equal(LOADER)
	return [a, b]


# --- H-09 --------------------------------------------------------------------------------------

func test_excavator_and_loader_drive_and_dig_at_the_same_time_on_one_layer() -> void:
	var both := _two_drivers(50, 70)
	var a := both[0]
	var b := both[1]
	await _physics(10)
	assert_bool(a.is_on_floor()).is_true()
	assert_bool(b.is_on_floor()).is_true()
	# Drive toward each other in the same frames.
	var ax := a.global_position.x
	var bx := b.global_position.x
	_hold(P1, Vector2(1, 0))
	_hold(P2, Vector2(-1, 0))
	await _physics(20)
	assert_float(a.global_position.x).is_greater(ax + 20.0)
	assert_float(b.global_position.x).is_less(bx - 20.0)
	assert_int(a.facing).is_equal(1)
	assert_int(b.facing).is_equal(-1)
	# Dig down together: both holes open, each credited to its own driver.
	_hold(P1, Vector2(0, 1), true)
	_hold(P2, Vector2(0, 1), true)
	await _physics(40)
	_hold(P1, Vector2.ZERO)
	_hold(P2, Vector2.ZERO)
	assert_int(int(_dug[P1])).is_greater(0)
	assert_int(int(_dug[P2])).is_greater(0)
	assert_int(a.backpack_count()).is_greater(0)
	assert_int(b.backpack_count()).is_greater(0)
	# Still each in their own vehicle.
	assert_that(_game.drivers.get(EXC)).is_equal(P1)
	assert_that(_game.drivers.get(LOADER)).is_equal(P2)


func test_neither_vehicle_takes_the_other_players_input() -> void:
	var both := _two_drivers(45, 75)
	var a := both[0]
	var b := both[1]
	await _physics(10)
	var bx := b.global_position.x
	var b_dug := int(_dug[P2])
	var b_face := b.facing
	# Only P1 drives and digs: P2's Loader does not move, turn, dig or honk.
	_hold(P1, Vector2(-1, 0))
	await _physics(15)
	_hold(P1, Vector2(0, 1), true)
	_intent[P1]["horn"] = true
	await _physics(20)
	assert_float(absf(b.global_position.x - bx)).is_less(1.0)
	assert_int(b.facing).is_equal(b_face)
	assert_int(int(_dug[P2])).is_equal(b_dug)
	assert_float(b.cab_spin).is_equal(0.0)
	assert_float(a.cab_spin).is_greater(0.0)
	_hold(P1, Vector2.ZERO)
	await _physics(30)
	# Only P2 drives: the Excavator stays put.
	var ax := a.global_position.x
	var a_dug := int(_dug[P1])
	_hold(P2, Vector2(1, 0))
	await _physics(15)
	_hold(P2, Vector2(1, 0), true)
	await _physics(15)
	_hold(P2, Vector2.ZERO)
	assert_float(absf(a.global_position.x - ax)).is_less(1.0)
	assert_int(int(_dug[P1])).is_equal(a_dug)
	assert_float(b.global_position.x).is_greater(bx)


func test_one_player_hopping_out_leaves_the_other_driving() -> void:
	var both := _two_drivers(55, 62)
	var a := both[0]
	var b := both[1]
	await _physics(10)
	# P1 hops out right next to P2's Loader: P2 keeps driving it.
	_hold(P1, Vector2.ZERO, false, true)
	await _physics(2)
	_hold(P1, Vector2.ZERO)
	assert_object(a.vehicle).is_null()
	assert_that(b.vehicle.id).is_equal(LOADER)
	assert_that(_game.drivers.get(LOADER)).is_equal(P2)
	assert_bool(_game.drivers.has(EXC)).is_false()
	# The Excavator is parked where P1 got out.
	var v: Vehicle = _game.vehicles[EXC]
	assert_bool(v.is_inside_tree()).is_true()


func test_a_bystander_keeps_their_powers_and_boards_the_free_vehicle_with_b() -> void:
	_make()
	_carve(ROOM)
	var a := _join(P1)
	var b := _join(P2)
	_park_below(EXC, 50)
	_park_below(LOADER, 80)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(50 * 16.0 + 8.0, FLOOR_Y))
	_game.place_player(P2, HillGame.UNDERGROUND, Vector2(52 * 16.0 + 8.0, FLOOR_Y))
	assert_bool(_game.hop_in(a)).is_true()
	await _physics(10)
	# P2 on foot beside P1's Excavator: B cannot take it, it is a jump.
	var y0 := b.global_position.y
	_hold(P2, Vector2.ZERO, false, true)
	await _physics(6)
	assert_object(b.vehicle).is_null()
	assert_that(a.vehicle.id).is_equal(EXC)
	assert_float(b.global_position.y).is_less(y0 - 4.0)
	_hold(P2, Vector2.ZERO)
	await _physics(40)
	# On foot P2 still digs (and walks) while P1 drives.
	var before := int(_dug[P2])
	_hold(P2, Vector2(0, 1), true)
	_hold(P1, Vector2(-1, 0))
	await _physics(20)
	_hold(P2, Vector2.ZERO)
	_hold(P1, Vector2.ZERO)
	assert_int(int(_dug[P2])).is_greater(before)
	assert_object(b.vehicle).is_null()
	await _physics(30)
	# P1 gets out; the Excavator is free and P2 boards it with B.
	_hold(P1, Vector2.ZERO, false, true)
	await _physics(2)
	_hold(P1, Vector2.ZERO)
	assert_object(a.vehicle).is_null()
	var ex: Vehicle = _game.vehicles[EXC]
	b.global_position = Vector2(ex.position.x + 10.0, ex.position.y)
	b.velocity = Vector2.ZERO
	await _physics(2)
	_hold(P2, Vector2.ZERO, false, true)
	await _physics(2)
	_hold(P2, Vector2.ZERO)
	assert_object(b.vehicle).is_not_null()
	assert_that(b.vehicle.id).is_equal(EXC)
	assert_that(_game.drivers.get(EXC)).is_equal(P2)
	assert_object(a.vehicle).is_null()


func test_two_b_presses_at_one_free_vehicle_give_it_to_one_player() -> void:
	_make()
	_carve(ROOM)
	var a := _join(P1)
	var b := _join(P2)
	_park_below(EXC, 50)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(49 * 16.0, FLOOR_Y))
	_game.place_player(P2, HillGame.UNDERGROUND, Vector2(51 * 16.0 + 14.0, FLOOR_Y))
	await _physics(10)
	_hold(P1, Vector2.ZERO, false, true)
	_hold(P2, Vector2.ZERO, false, true)
	await _physics(2)
	_hold(P1, Vector2.ZERO)
	_hold(P2, Vector2.ZERO)
	var driving := 0
	for n: HillPlayer in [a, b]:
		if n.vehicle != null:
			driving += 1
			assert_that(_game.drivers.get(EXC)).is_equal(n.player)
	assert_int(driving).is_equal(1)
	assert_bool(_game.vehicles[EXC].is_inside_tree()).is_false()


func test_the_camera_frames_both_drivers_close_and_splits_to_each_driver_far() -> void:
	var both := _two_drivers(50, 58)
	var a := both[0]
	var b := both[1]
	await _physics(10)
	a.set_physics_process(false)
	b.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _game.director
	assert_bool(dir.is_split()).is_false()
	for n: HillPlayer in [a, b]:
		assert_bool(_on_screen(n, dir.camera_of(n.player))).is_true()
	# Far apart on the same layer: split, each half follows its own driver.
	a.set_physics_process(true)
	b.set_physics_process(true)
	a.global_position.x = 32 * 16.0
	b.global_position.x = 98 * 16.0
	await _physics(4)
	a.set_physics_process(false)
	b.set_physics_process(false)
	for i in 60:
		await get_tree().process_frame
	assert_bool(dir.is_split()).is_true()
	for n: HillPlayer in [a, b]:
		var cam := dir.camera_of(n.player)
		assert_bool(_on_screen(n, cam)).is_true()
	assert_object(dir.camera_of(P1)).is_not_same(dir.camera_of(P2))


## The node's feet are inside its camera's view (camera position +- half the visible area).
func _on_screen(n: Node2D, cam: Camera2D) -> bool:
	var vp := cam.get_viewport()
	var half := Vector2(vp.get_visible_rect().size) / cam.zoom * 0.5
	var c := cam.get_screen_center_position()
	var d := n.global_position - c
	return absf(d.x) <= half.x and absf(d.y) <= half.y


func test_each_driven_vehicle_shows_its_drivers_stripe_row() -> void:
	for id: StringName in [EXC, LOADER]:
		var file := "vehicles/%s.png" % id
		assert_bool(SpriteArt.has(file)).is_true()
		assert_bool(SpriteArt.row(file, "green").is_empty()).is_false()
		assert_bool(SpriteArt.row(file, "red").is_empty()).is_false()
		assert_int(int(SpriteArt.row(file, "green").get("row", -1))).is_not_equal(int(SpriteArt.row(file, "red").get("row", -1)))
	assert_str(Vehicle.row_name(P1)).is_equal("green")
	assert_str(Vehicle.row_name(P2)).is_equal("red")
	assert_str(Vehicle.row_name(-1)).is_equal("cream")
