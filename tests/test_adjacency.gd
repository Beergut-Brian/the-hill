## Town adjacency (C-23, C-26): the data row, pair detection, the ghost's preview hearts and the
## reward for a new happy pair (sparkles, a pop, flowers, a chime), against a tiny fake game like
## test_hill_build. Frames are stepped by hand so nothing depends on timing.
class_name TestAdjacency
extends GdUnitTestSuite


class FakePlayer extends Node2D:
	var player := 0
	var facing := 1

	func honk() -> void:
		pass

	func bump() -> void:
		pass


class FakeGame extends Node:
	var hillville: Hillville
	var director = null
	var build: BuildController
	var story: Story
	var ruins = null
	var players := {}

	func player_node(p: int) -> Node2D:
		return players.get(p)


var _game: FakeGame
var _hv: Hillville
var _build: BuildController
var _adj: TownAdjacency
var _p: FakePlayer
var _made: Array = []


func before() -> void:
	SuiteSandbox.enter("adjacency", "res://tests/fixtures/roster_two.json")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Progress.reset()
	Inventory.clear()
	_made.clear()
	_game = FakeGame.new()
	_hv = Hillville.new()
	_game.hillville = _hv
	_game.add_child(_hv)
	_hv.load_save({"seed": _hv.layout_seed, "left": "0".repeat(Hillville.COLS)})   # no scrub
	_p = FakePlayer.new()
	_hv.players_root().add_child(_p)
	_game.players[0] = _p
	_build = BuildController.new()
	_build.name = "Build"
	_game.build = _build
	_game.add_child(_build)
	_game.story = Story.new()
	get_tree().root.add_child(_game)


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Progress.reset()
	Inventory.clear()


## Adds TownAdjacency (after the stage is set, like HillGame after a load).
func _start() -> void:
	_adj = TownAdjacency.new()
	_hv.add_child(_adj)
	_adj.setup(_game, _hv)
	_adj.pair_made.connect(func(a: StringName, b: StringName) -> void: _made.append([a, b]))


func _step(sec: float) -> void:
	var n := ceili(sec * 60.0)
	for i in n:
		_build._process(1.0 / 60.0)
		_adj._process(1.0 / 60.0)


func _stand(id: StringName, cell: int) -> int:
	var i := Progress.add_building(id, Vector2i(cell, 0))
	_build.rebuild()
	return i


## Stands the player so a 2-wide ghost snaps to `cell`.
func _aim(cell: int) -> void:
	_p.facing = 1
	_p.global_position = Vector2(cell * 48 + 48 - 48 * 2.0 + 12, 0)


func _ghost(id: StringName, cell: int) -> void:
	var d := Progress.building_data(id)
	for k in d.cost:
		Inventory.add(StringName(str(k)), int(d.cost[k]))
	_aim(cell)
	_build._pick(0, id)
	assert_bool(_build.has_ghost(0)).is_true()
	assert_int(_build.ghost_cell(0).x).is_equal(cell)


func _spot(id: StringName, cell: int, w := 2) -> Dictionary:
	return {"key": "%s@%d" % [id, cell], "id": id, "x0": cell * 48.0, "x1": (cell + w) * 48.0, "top": -96.0}


# --- data --------------------------------------------------------------------------------------

func test_adjacency_data_row_loads_with_pairs_and_a_radius() -> void:
	var d := load(TownAdjacency.DATA_PATH) as AdjacencyData
	assert_object(d).is_not_null()
	assert_int(d.radius_plots).is_greater(0)
	assert_bool(d.likes(&"barn", &"house")).is_true()
	assert_bool(d.likes(&"house", &"barn")).is_true()   # either order
	assert_bool(d.likes(&"barn", &"gnome_village")).is_true()   # the Foreman's home and the barns
	assert_bool(d.likes(&"water_tower", &"pond")).is_true()
	assert_bool(d.likes(&"barn", &"barn")).is_false()
	# Every id in the data is a real building row or a town landmark.
	for p in d.pairs:
		assert_int(p.size()).is_equal(2)
		for id in p:
			var ok := TownAdjacency.LANDMARKS.has(StringName(id)) or Progress.building_data(StringName(id)) != null
			assert_bool(ok).override_failure_message("unknown id in adjacency.tres: %s" % id).is_true()


# --- pair detection ----------------------------------------------------------------------------

func test_pairs_need_liking_and_nearness() -> void:
	var d := load(TownAdjacency.DATA_PATH) as AdjacencyData
	var r := d.radius_plots
	var near := [_spot(&"barn", 10), _spot(&"house", 12 + r)]           # exactly r plots apart
	assert_int(TownAdjacency.find_pairs(near, d).size()).is_equal(1)
	var far := [_spot(&"barn", 10), _spot(&"house", 13 + r)]            # one plot too far
	assert_int(TownAdjacency.find_pairs(far, d).size()).is_equal(0)
	var strangers := [_spot(&"barn", 10), _spot(&"barn", 12)]           # side by side, no liking
	assert_int(TownAdjacency.find_pairs(strangers, d).size()).is_equal(0)
	var order := [_spot(&"house", 20), _spot(&"barn", 17)]              # order in the list does not matter
	assert_int(TownAdjacency.find_pairs(order, d).size()).is_equal(1)


func test_a_hundred_barns_and_one_house_only_pairs_the_neighbours() -> void:
	var d := load(TownAdjacency.DATA_PATH) as AdjacencyData
	var spots: Array = []
	for i in 100:
		spots.append(_spot(&"barn", i * 2))   # a solid row of barns, cells 0..199
	spots.append(_spot(&"house", 200))
	var t0 := Time.get_ticks_usec()
	var pairs := TownAdjacency.find_pairs(spots, d)
	var us := Time.get_ticks_usec() - t0
	# Barns ending within radius plots of the house: x1 in [200 - r, 200].
	var expect := 0
	for i in 100:
		if 200 - (i * 2 + 2) <= d.radius_plots:
			expect += 1
	assert_int(pairs.size()).is_equal(expect)
	assert_int(us).is_less(20000)


func test_town_pairs_follow_progress_and_count_restored_homes() -> void:
	_stand(&"barn", 32)
	_stand(&"house", 35)
	_stand(&"garage", 50)   # nobody near it
	_start()
	assert_int(_adj.pairs.size()).is_equal(1)
	var pr: Dictionary = _adj.pairs.values()[0]
	assert_array([pr.a.id, pr.b.id]).contains_exactly_in_any_order([&"barn", &"house"])
	# The Foreman's Gnome Village (restored) likes a barn beside it.
	var r := _hv.ruin_rect(Story.RUIN_OF[Story.FOREMAN])
	_stand(&"barn", int(r.end.x / 48.0) + 1)
	_step(0.5)
	assert_int(_adj.pairs.size()).is_equal(1)   # not restored yet: still a ruin
	_game.story.state(Story.FOREMAN).phase = ResidentState.Phase.RESTORED
	_step(1.2)
	assert_int(_adj.pairs.size()).is_equal(2)
	assert_bool(_adj.pairs.keys().any(func(k: String) -> bool: return k.contains("home:gnome_foreman"))).is_true()


# --- ghost preview -----------------------------------------------------------------------------

func test_ghost_previews_hearts_only_where_it_would_be_happy() -> void:
	_stand(&"barn", 32)
	_start()
	_ghost(&"house", 45)           # far from the barn
	_step(0.1)
	assert_bool(_adj.previews.has(0)).override_failure_message(str(_adj.previews.get(0, []).map(func(s): return [s.key, s.x0, s.x1, s.ghost.x0]))).is_false()
	_aim(35)                       # one plot from the barn
	_step(0.1)
	assert_int(_adj.previews.get(0, []).size()).is_equal(1)
	assert_str(String(_adj.previews[0][0].id)).is_equal("barn")
	assert_int(_adj.celebrations).is_equal(0)   # a preview is not the reward
	assert_int(_adj.pairs.size()).is_equal(0)
	_aim(31)                       # on top of the barn: a red ghost shows no hearts
	_step(0.1)
	assert_bool(_build.ghost_of(0).ghost_ok).is_false()
	assert_bool(_adj.previews.has(0)).is_false()
	_build.cancel(0)
	_step(0.1)
	assert_bool(_adj.previews.has(0)).is_false()


func test_a_carried_building_previews_against_the_others_not_its_old_spot() -> void:
	_stand(&"barn", 32)
	var h := _stand(&"house", 35)
	_start()
	assert_int(_adj.pairs.size()).is_equal(1)
	_aim(35)
	_p.global_position.x = 35 * 48 + 48   # standing on the house
	assert_int(_build.building_in_reach(0)).is_equal(h)
	assert_bool(_build.action(0)).is_true()   # picked up
	_step(0.1)
	assert_bool(_adj.pairs.values()[0].alive).is_false()   # its flowers wilt while it is carried
	_aim(29)                                     # the other side of the barn: still near
	_step(0.1)
	assert_int(_adj.previews.get(0, []).size()).is_equal(1)


# --- reward ------------------------------------------------------------------------------------

func test_dropping_a_happy_pair_celebrates_once_with_sparkles_flowers_and_a_chime() -> void:
	_stand(&"barn", 32)
	_start()
	_ghost(&"house", 35)
	_step(0.1)
	assert_bool(_build.action(0)).is_true()     # drop
	_step(0.4)
	assert_int(_adj.celebrations).is_equal(0)   # waits for the unfold
	_step(0.5)
	assert_int(_adj.celebrations).is_equal(1)
	assert_int(_made.size()).is_equal(1)
	assert_array(_made[0]).contains_exactly_in_any_order([&"barn", &"house"])
	assert_int(_adj._sparks.size()).is_greater(8)
	var pr: Dictionary = _adj.pairs.values()[0]
	assert_float(pr.pop).is_greater_equal(0.0)   # the big heart pops
	assert_int(pr.flowers.size()).is_greater_equal(3)
	# Flowers stand on the ground between the two (a little under each front).
	for f in pr.flowers:
		assert_float(f.x).is_between(33 * 48.0, 36 * 48.0)
	var g0: float = pr.grow
	_step(2.0)
	assert_float(pr.grow).is_greater(g0)
	assert_float(pr.grow).is_equal(1.0)
	assert_int(_adj.celebrations).is_equal(1)   # once, not every frame
	_step(1.5)
	assert_int(_adj.celebrations).is_equal(1)


func test_town_hearts_and_heart_preview_cues_have_files() -> void:
	for cue in ["town_hearts", "heart_preview"]:
		assert_bool(FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % cue)).override_failure_message(cue).is_true()


func test_moving_away_wilts_the_flowers_and_a_loaded_town_does_not_recelebrate() -> void:
	_stand(&"barn", 32)
	var h := _stand(&"house", 35)
	_start()
	assert_int(_adj.pairs.size()).is_equal(1)
	assert_float(_adj.pairs.values()[0].grow).is_equal(1.0)   # already grown on load
	_step(1.0)
	assert_int(_adj.celebrations).is_equal(0)
	Progress.move_building(h, Vector2i(50, 0))
	_build.rebuild()
	_step(1.5)
	assert_int(_adj.pairs.size()).is_equal(0)
	assert_int(_adj.celebrations).is_equal(0)
	Progress.move_building(h, Vector2i(35, 0))   # back beside the barn: happy again
	_step(1.0)
	assert_int(_adj.celebrations).is_equal(1)
