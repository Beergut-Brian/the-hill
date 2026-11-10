## Hillville scrub and save, the build book's cards, placing / snapping / rejecting / moving
## buildings, the Garage's vehicle unlock and rebuild from Progress. Runs against a tiny fake game.
class_name TestHillBuild
extends GdUnitTestSuite


class FakePlayer extends Node2D:
	var player := 0
	var facing := 1
	var vehicle = null
	var honks := 0
	var bumps := 0

	func honk() -> void:
		honks += 1

	func bump() -> void:
		bumps += 1


class FakeGame extends Node:
	var hillville: Hillville
	var director = null
	var players := {}

	func player_node(p: int) -> Node2D:
		return players.get(p)


var _game: FakeGame
var _hv: Hillville
var _build: BuildController
var _p: FakePlayer
var _moved: Array = []
var _unlocked: Array = []
var _rolled: Array = []
var _on_moved := func(id: StringName, from: Vector2i, to: Vector2i) -> void: _moved.append([id, from, to])
var _on_unlocked := func(id: StringName) -> void: _unlocked.append(id)
var _on_rolled := func(id: StringName, door: Vector2) -> void: _rolled.append([id, door])


func before_test() -> void:
	Progress.reset()
	Inventory.clear()
	_moved.clear()
	_unlocked.clear()
	_rolled.clear()
	_game = FakeGame.new()
	_hv = Hillville.new()
	_game.hillville = _hv
	_game.add_child(_hv)
	_p = FakePlayer.new()
	_hv.players_root().add_child(_p)
	_game.players[0] = _p
	_build = BuildController.new()
	_build.name = "Build"
	_game.add_child(_build)
	get_tree().root.add_child(_game)
	_hv.vehicle_rolls_out.connect(_on_rolled)
	Events.building_moved.connect(_on_moved)
	Events.vehicle_unlocked.connect(_on_unlocked)


func after_test() -> void:
	Events.building_moved.disconnect(_on_moved)
	Events.vehicle_unlocked.disconnect(_on_unlocked)
	if is_instance_valid(_game):
		_game.free()
	Progress.reset()
	Inventory.clear()


## Stands the player so a `width`-cell ghost snaps to `cell` (facing right).
func _aim(cell: int, width := 2, facing := 1) -> void:
	_p.facing = facing
	if facing > 0:
		_p.global_position = Vector2(cell * 48 + width * 24 - 48 * (1.0 + width * 0.5) + 12, 0)
	else:
		_p.global_position = Vector2(cell * 48 + width * 24 + 48 * (1.0 + width * 0.5) + 12, 0)
	assert_int(_build.ghost_cell(0).x if _build.has_ghost(0) else BuildController.plot_cell_for(_p.global_position.x, facing, width)).is_equal(cell)


func _pick(id: StringName) -> void:
	_build.book_pressed(0)
	var book := _build.book_of(0) as BuildBook
	var i := book.card_ids().find(id)
	assert_int(i).is_greater_equal(0)
	for k in i:
		_build.book_input(0, Vector2.RIGHT, false, false)
		_build.book_input(0, Vector2.ZERO, false, false)
	_build.book_input(0, Vector2.ZERO, true, false)


func _place_barn(cell: int) -> int:
	Inventory.add(&"dirt", 10)
	_pick(&"barn")
	_aim(cell)
	assert_bool(_build.action(0)).is_true()
	return Progress.buildings.size() - 1


func _clear_all_scrub() -> void:
	_hv.load_save({"seed": _hv.layout_seed, "left": "0".repeat(Hillville.COLS)})


func _scrub_cell(from: int) -> int:
	for c in range(from, Hillville.CELLS - 2):
		if _hv.cell_owner(c) == &"" and _hv.cell_owner(c + 1) == &"" and not _hv.ground_clear(c, 2):
			return c
	return -1


# --- book --------------------------------------------------------------------------------------

func test_book_cards_affordable_greyed_and_garage_gate() -> void:
	_build.book_pressed(0)
	assert_bool(_build.captures(0)).is_true()
	var book := _build.book_of(0) as BuildBook
	assert_array(book.card_ids()).is_equal([&"barn", &"house"])
	assert_bool(book.card_affordable(0)).is_false()
	Inventory.add(&"dirt", 10)
	assert_bool(book.card_affordable(0)).is_true()
	assert_bool(book.card_affordable(1)).is_false()
	_build.book_pressed(0)
	assert_bool(_build.captures(0)).is_false()
	Progress.find_treasure(&"buried_car")
	_build.book_pressed(0)
	assert_array((_build.book_of(0) as BuildBook).card_ids()).is_equal([&"barn", &"house", &"garage"])


func test_book_moves_and_closes_with_b() -> void:
	_build.book_pressed(0)
	var book := _build.book_of(0) as BuildBook
	assert_int(book.focus).is_equal(0)
	_build.book_input(0, Vector2.RIGHT, false, false)
	_build.book_input(0, Vector2.RIGHT, false, false)   # held: one step only
	assert_int(book.focus).is_equal(1)
	_build.book_input(0, Vector2.ZERO, false, false)
	_build.book_input(0, Vector2.RIGHT, false, false)
	assert_int(book.focus).is_equal(0)   # wraps
	_build.book_input(0, Vector2.ZERO, false, true)
	assert_bool(_build.captures(0)).is_false()


func test_book_anchors_full_viewport_without_director() -> void:
	_build.book_pressed(0)
	var book := _build.book_of(0) as BuildBook
	assert_object(book.get_parent()).is_same(_build)
	assert_vector(book.size).is_equal(book.get_viewport_rect().size)


func test_pick_spends_and_cancel_refunds() -> void:
	Inventory.add(&"dirt", 12)
	_pick(&"barn")
	assert_bool(_build.captures(0)).is_false()
	assert_bool(_build.has_ghost(0)).is_true()
	assert_int(Inventory.count(&"dirt")).is_equal(2)
	assert_bool(_build.cancel(0)).is_true()
	assert_bool(_build.has_ghost(0)).is_false()
	assert_int(Inventory.count(&"dirt")).is_equal(12)
	assert_bool(_build.cancel(0)).is_false()
	assert_int(Progress.buildings.size()).is_equal(0)


func test_cant_afford_honks_and_keeps_book() -> void:
	_pick(&"barn")
	assert_int(_p.honks).is_equal(1)
	assert_bool(_build.has_ghost(0)).is_false()
	assert_bool(_build.captures(0)).is_true()


# --- placement ---------------------------------------------------------------------------------

func test_place_snaps_to_plot_grid() -> void:
	var i := _place_barn(33)
	assert_int(i).is_equal(0)
	assert_bool(_build.has_ghost(0)).is_false()
	assert_that(Progress.buildings[0].cell).is_equal(Vector2i(33, 0))
	var node := _build.building_node(0)
	assert_object(node).is_not_null()
	assert_float(node.position.x).is_equal(33.0 * Hillville.PLOT)
	assert_float(node.position.y).is_equal(0.0)
	assert_int(Progress.backpack_capacity()).is_equal((Progress.BACKPACK_START + 1) * Progress.BACKPACK_PER_SIZE)
	# Facing left snaps too.
	Inventory.add(&"dirt", 10)
	_pick(&"barn")
	_aim(43, 2, -1)
	assert_bool(_build.action(0)).is_true()
	assert_that(Progress.buildings[1].cell).is_equal(Vector2i(43, 0))
	assert_int(_p.honks).is_equal(0)


func test_bad_plots_rejected_with_honk_and_no_spend() -> void:
	_place_barn(33)
	var scrub := _scrub_cell(50)
	assert_int(scrub).is_greater(0)
	for cell in [scrub, 72, 39, 41, 34, -1, Hillville.CELLS - 1]:
		Inventory.add(&"dirt", 10)
		_pick(&"barn")
		var honks := _p.honks
		_aim(cell)
		assert_bool(_build.action(0)).is_true()
		assert_bool(_build.has_ghost(0)).is_true()
		assert_int(_p.honks).is_equal(honks + 1)
		assert_int(Progress.buildings.size()).is_equal(1)
		assert_bool(_build.ghost_of(0).ghost_ok).is_false()
		assert_int(Inventory.count(&"dirt")).is_equal(0)
		_build.cancel(0)
		assert_int(Inventory.count(&"dirt")).is_equal(10)
		Inventory.spend({&"dirt": 10})


func test_scooped_plot_becomes_buildable() -> void:
	var cell := _scrub_cell(50)
	for c in range(cell * 3, cell * 3 + 6):
		while _hv.scrub_at(c) > 0:
			_hv.scoop(Vector2(c * 16 + 8, 0), 1, Vector2i(1, 1), 0)
	assert_bool(_build.plot_clear(cell, 2)).is_true()


func test_a_hundred_barns_never_refused() -> void:
	_clear_all_scrub()
	var placed := 0
	var cell := 0
	while cell < Hillville.CELLS - 1:
		if _build.plot_clear(cell, 2):
			_place_barn(cell)
			placed += 1
			cell += 2
		else:
			cell += 1
	assert_int(placed).is_greater(50)
	assert_int(Progress.count_buildings(&"barn")).is_equal(placed)
	assert_int(_p.honks).is_equal(0)
	assert_int(Progress.backpack_capacity()).is_equal((Progress.BACKPACK_START + placed) * Progress.BACKPACK_PER_SIZE)


# --- move --------------------------------------------------------------------------------------

func test_pick_up_and_move_is_free() -> void:
	_place_barn(33)
	_p.global_position = Vector2(33 * 48 - 20, 0)
	_p.facing = 1
	assert_int(_build.building_in_reach(0)).is_equal(0)
	assert_bool(_build.action(0)).is_true()
	assert_bool(_build.has_ghost(0)).is_true()
	assert_int(_build.ghost_of(0).index).is_equal(0)
	_aim(43, 2, -1)
	assert_bool(_build.action(0)).is_true()
	assert_bool(_build.has_ghost(0)).is_false()
	assert_that(Progress.buildings[0].cell).is_equal(Vector2i(43, 0))
	assert_int(Progress.buildings.size()).is_equal(1)
	assert_int(Inventory.count(&"dirt")).is_equal(0)
	assert_array(_moved).is_equal([[&"barn", Vector2i(33, 0), Vector2i(43, 0)]])
	assert_float(_build.building_node(0).position.x).is_equal(43.0 * 48)
	# Cancel a move: back where it was.
	_p.global_position = Vector2(43 * 48 - 20, 0)
	_p.facing = 1
	assert_bool(_build.action(0)).is_true()
	assert_bool(_build.cancel(0)).is_true()
	assert_float(_build.building_node(0).position.x).is_equal(43.0 * 48)
	assert_that(Progress.buildings[0].cell).is_equal(Vector2i(43, 0))


func test_ruins_cannot_be_picked_up() -> void:
	var r := _hv.ruin_rect(&"crooked_watchtower")
	_p.global_position = Vector2(r.get_center().x, 0)
	assert_bool(_build.action(0)).is_false()
	assert_bool(_build.has_ghost(0)).is_false()


# --- garage ------------------------------------------------------------------------------------

func test_garage_unlocks_excavator_then_still_allowed() -> void:
	Progress.find_treasure(&"buried_car")
	Inventory.add(&"clay", 40)
	Inventory.add(&"stone", 20)
	_pick(&"garage")
	_aim(43, 3)
	assert_bool(_build.action(0)).is_true()
	assert_int(Progress.count_buildings(&"garage")).is_equal(1)
	await get_tree().create_timer(1.3).timeout
	assert_bool(Progress.has_vehicle(&"excavator")).is_true()
	assert_array(_unlocked).is_equal([&"excavator"])
	assert_int(_rolled.size()).is_equal(1)
	assert_that(_rolled[0][0]).is_equal(&"excavator")
	assert_float(_rolled[0][1].x).is_equal(43 * 48 + 72.0)
	assert_float(_build.building_node(0).door_open).is_equal(1.0)
	# A second Garage: nothing left to unlock, still placed.
	_pick(&"garage")
	_aim(33, 3)
	assert_bool(_build.action(0)).is_true()
	assert_int(Progress.count_buildings(&"garage")).is_equal(2)
	await get_tree().create_timer(1.3).timeout
	assert_int(_rolled.size()).is_equal(1)
	assert_int(_p.honks).is_equal(0)


# --- scoop -------------------------------------------------------------------------------------

func _find(kind: int) -> int:
	for c in Hillville.COLS:
		if _hv.scrub_kind(c) == kind:
			return c
	return -1


func test_scoop_tree_and_stump_give_dirt_rock_gives_stone() -> void:
	var t := _find(Hillville.Scrub.TREE)
	var h := _hv.scrub_at(t)
	assert_int(h).is_greater_equal(3)
	var before := _hv.scrub_left()
	assert_int(_hv.scoop(Vector2(t * 16 + 8, 0), 1, Vector2i(1, 1), 0)).is_equal(1)
	assert_int(_hv.scrub_at(t)).is_equal(h - 1)
	assert_int(Inventory.count(&"dirt")).is_equal(1)
	assert_int(_hv.scoop(Vector2(t * 16 + 8, 0), -1, Vector2i(1, 4), 0)).is_equal(h - 1)
	assert_int(_hv.scrub_at(t)).is_equal(0)
	assert_int(Inventory.count(&"dirt")).is_equal(h)
	var r := _find(Hillville.Scrub.ROCK)
	var rh := _hv.scrub_at(r)
	_hv.scoop(Vector2(r * 16 + 2, 0), -1, Vector2i(1, 2), 0)
	assert_int(Inventory.count(&"stone")).is_equal(rh)
	var s := _find(Hillville.Scrub.STUMP)
	_hv.scoop(Vector2(s * 16 + 2, 0), -1, Vector2i(1, 1), 0)
	assert_int(_hv.scrub_at(s)).is_equal(0)
	assert_int(Inventory.count(&"dirt")).is_equal(h + 1)
	assert_int(_hv.scrub_left()).is_equal(before - h - rh - 1)
	assert_float(_hv.nearest_scrub(t * 16.0)).is_not_equal(t * 16.0 + 8.0)


func test_ruins_shaft_and_yard_have_no_scrub() -> void:
	for id in _hv.ruin_ids():
		var r := _hv.ruin_rect(id)
		assert_float(r.size.x).is_greater(0.0)
		assert_int(_hv.scoop(Vector2(r.position.x + 1, 0), 1, Vector2i(3, 4), 0)).is_equal(0)
	assert_int(_hv.scoop(Vector2(Hillville.SHAFT_X - 300, 0), 1, Vector2i(3, 4), 0)).is_equal(0)
	assert_int(Inventory.count(&"dirt") + Inventory.count(&"stone")).is_equal(0)
	assert_bool(_hv.cage_zone().has_point(_hv.arrival())).is_true()
	assert_int(_hv.scrub_left()).is_greater(300)


func test_scrub_layout_is_deterministic() -> void:
	var other := Hillville.new()
	assert_dict(other.to_save()).is_equal(_hv.to_save())
	other.set_layout_seed(99)
	assert_dict(other.to_save()).is_not_equal(_hv.to_save())
	other.free()


func test_hillville_save_round_trip() -> void:
	for c in range(150, 330):
		_hv.scoop(Vector2(c * 16 + 8, 0), 1, Vector2i(1, 1), 0)
	var left := _hv.scrub_left()
	var data = JSON.parse_string(JSON.stringify(_hv.to_save()))
	var fresh := Hillville.new()
	assert_int(fresh.scrub_left()).is_greater(left)
	fresh.load_save(data)
	assert_int(fresh.scrub_left()).is_equal(left)
	for c in Hillville.COLS:
		assert_int(fresh.scrub_at(c)).is_equal(_hv.scrub_at(c))
	fresh.free()


# --- rebuild -----------------------------------------------------------------------------------

func test_rebuild_from_progress() -> void:
	_place_barn(33)
	Progress.load_save({"buildings": [{"id": "barn", "cell": [35, 0]}, {"id": "garage", "cell": [43, 0]}],
			"treasures": ["buried_car"]})
	_build.rebuild()
	await get_tree().process_frame
	var kids := _hv.buildings_root().get_children()
	assert_int(kids.size()).is_equal(2)
	assert_float(_build.building_node(0).position.x).is_equal(35.0 * 48)
	assert_float(_build.building_node(1).position.x).is_equal(43.0 * 48)
	assert_vector(_build.building_node(1).scale).is_equal(Vector2.ONE)
	await get_tree().create_timer(1.2).timeout
	assert_bool(Progress.has_vehicle(&"excavator")).is_false()
	assert_int(_rolled.size()).is_equal(0)
