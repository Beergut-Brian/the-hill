## The residents' arcs up top (Gameplay lane, 2026-11-10), in simulated physics time: silhouettes
## once met, Arrival bubbles (what they did + sheepish, then their ruin + hopeful), restore cards in
## the build book only while ARRIVED, paying rebuilds the ruin plank by plank and the resident moves
## in with the light on, never restorable twice, never refuses anything else; each payoff (Lost &
## Found bundle, overnight crew, Museum shelf, Dragon Perch); every arc state survives a reload.
class_name TestResidentArcs
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const ALL := [&"mole", &"gnome_foreman", &"caveman", &"dragon"]

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}


func before() -> void:
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_arcs.json"
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
	Save.profile = "test_arcs"
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


func _make(load_saved := false) -> HillGame:
	_game = HillGame.new()
	_game.load_saved = load_saved
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


func _total() -> int:
	var n := 0
	for b in [&"dirt", &"clay", &"stone", &"ice", &"crystal"]:
		n += Inventory.count(b)
	return n


func _arrive(id: StringName) -> void:
	var s := _game.story.state(id)
	s.encounters = s.encounters_to_arrive
	s.phase = ResidentState.Phase.ARRIVED
	_game.story.changed.emit()


func _pay_for(ruin: StringName) -> void:
	var cost: Dictionary = Progress.building_data(ruin).cost
	for b in cost:
		Inventory.add(StringName(str(b)), int(cost[b]))


func _stand_at(x: float) -> void:
	_game.place_player(P1, HillGame.HILLVILLE, Vector2(x, 0))
	_game.player_node(P1).velocity = Vector2.ZERO


func _restore(id: StringName) -> void:
	var ruin: StringName = Story.RUIN_OF[id]
	_arrive(id)
	_pay_for(ruin)
	assert_bool(_game.restore_ruin(ruin)).is_true()
	await _until(func() -> bool: return not _game.ruins.is_rebuilding(id), 240)


# --- data and rules ----------------------------------------------------------------------------

func test_every_ruin_has_a_home_row_and_a_fair_cost() -> void:
	var blocks := Underground.load_rows(Underground.BLOCK_DIR)
	var met_depth := {&"mole": 0, &"gnome_foreman": 70, &"caveman": 130, &"dragon": 260}
	for id: StringName in ALL:
		var ruin := Progress.building_data(Story.RUIN_OF[id])
		assert_bool(ruin.is_ruin).is_true()
		assert_str(String(ruin.resident)).is_equal(String(id))
		assert_str(String(ruin.restores_into)).is_equal(String(Story.HOME_OF[id]))
		var home := Progress.building_data(Story.HOME_OF[id])
		assert_object(home).is_not_null()
		assert_str(String(home.from_ruin)).is_equal(String(ruin.id))
		assert_that(home.footprint).is_equal(ruin.footprint)
		assert_bool(Rules.restore_cost_is_fair(ruin, met_depth[id], blocks)).is_true()
		assert_bool(Building.has_art(home.id)).is_true()


# --- encounter -> arrival up top ---------------------------------------------------------------

func test_silhouettes_show_once_met_and_arrival_pleads_in_pictures() -> void:
	_make()
	_join()
	await _physics(2)
	assert_bool(_game.hillville._silhouette.get(&"old_shed", false)).is_false()
	_game.story.steal_shovel()
	await _physics(1)
	assert_int(_game.story.phase(&"mole")).is_equal(ResidentState.Phase.ENCOUNTERED)
	assert_bool(_game.hillville._silhouette.get(&"old_shed", false)).is_true()
	assert_bool(_game.town.mole.visible).is_false()
	_game.story.steal_shovel()
	_game.story.steal_shovel()
	assert_int(_game.story.phase(&"mole")).is_equal(ResidentState.Phase.ARRIVED)
	assert_bool(_game.story.steal_shovel()).is_false()
	# He comes up and waits by the shaft with the shovel; the bubble plays when P1 walks up.
	_stand_at(Hillville.SHAFT_X - 500.0)
	await _until(func() -> bool: return _game.town.mole_mode() == &"wait", 120)
	assert_bool(_game.town.mole.visible).is_true()
	assert_array(_game.town.saying(&"mole")).is_empty()
	_stand_at(TownResidents.MOLE_WAIT_X - 60.0)
	await _until(func() -> bool: return not _game.town.saying(&"mole").is_empty(), 60)
	assert_array(_game.town.saying(&"mole")).is_equal([&"shovel", &"face_sheepish"])
	await _physics(int(TownResidents.TALK_PART * 60) + 4)
	assert_array(_game.town.saying(&"mole")).is_equal([&"ruin:old_shed", &"face_hopeful"])


func test_the_crew_appears_up_top_only_once_freed() -> void:
	_make()
	_join()
	await _physics(2)
	for c in _game.town.crew:
		assert_bool(c.visible).is_false()
	assert_bool(_game.story.free_crew()).is_true()
	await _physics(1)
	assert_int(_game.story.phase(&"gnome_foreman")).is_equal(ResidentState.Phase.ARRIVED)
	for c in _game.town.crew:
		assert_bool(c.visible).is_true()


func test_the_dragon_comes_up_in_pieces_and_waits_by_the_keep() -> void:
	_make()
	_join()
	await _physics(2)
	assert_bool(_game.story.wake_dragon()).is_false()   # not before her first meeting
	_game.story.meet_dragon()
	assert_bool(_game.story.wake_dragon()).is_true()
	await _physics(1)
	assert_str(String(_game.town.dragon_mode())).is_equal("pieces")
	await _until(func() -> bool: return _game.town.dragon_mode() == &"wait", 60 * 12)
	assert_str(String(_game.town.dragon_mode())).is_equal("wait")
	assert_float(_game.town.dragon.position.x).is_equal_approx(TownResidents.DRAGON_WAIT.x, 1.0)


# --- fix-up ------------------------------------------------------------------------------------

func test_restore_card_only_while_arrived_and_paying_rebuilds_plank_by_plank() -> void:
	_make()
	_join()
	await _physics(2)
	var b := _game.build
	var shed := _game.hillville.ruin_rect(&"old_shed")
	_stand_at(shed.position.x - 30.0)
	assert_array(b.restore_rows(P1)).is_empty()
	# Never in the book as a normal card.
	assert_array(b.book_rows().map(func(d: BuildingData) -> StringName: return d.id)).not_contains([&"lost_and_found", &"museum", &"gnome_village", &"dragon_perch"])
	_arrive(&"mole")
	_arrive(&"caveman")
	var ids: Array = b.restore_rows(P1).map(func(d: BuildingData) -> StringName: return d.id)
	assert_array(ids).is_equal([&"lost_and_found", &"museum"])   # the ruin you stand at first
	var card: BuildingData = b.restore_rows(P1)[0]
	assert_dict(card.cost).is_equal(Progress.building_data(&"old_shed").cost)
	# Short of blocks: the card is there but greyed; picking it pays nothing and restores nothing.
	b.book_pressed(P1)
	assert_str(String(b.book_of(P1).focused_id())).is_equal("lost_and_found")
	b.book_input(P1, Vector2.ZERO, true, false)
	assert_int(_game.story.phase(&"mole")).is_equal(ResidentState.Phase.ARRIVED)
	b.book_pressed(P1)
	# Enough: A pays and the shed rebuilds plank by plank.
	_pay_for(&"old_shed")
	var dirt := Inventory.count(&"dirt")
	b.book_pressed(P1)
	b.book_input(P1, Vector2.ZERO, true, false)
	assert_int(Inventory.count(&"dirt")).is_equal(dirt - 10)
	assert_int(_game.story.phase(&"mole")).is_equal(ResidentState.Phase.RESTORED)
	assert_bool(_game.ruins.is_rebuilding(&"mole")).is_true()
	assert_bool(_game.hillville.is_ruin_restored(&"old_shed")).is_true()
	await _physics(3)
	var home: Building = _game.ruins.homes[&"mole"]
	var mid := home.reveal
	assert_float(mid).is_greater(0.0)
	assert_float(mid).is_less(1.0)
	await _until(func() -> bool: return not _game.ruins.is_rebuilding(&"mole"), 240)
	assert_float(home.reveal).is_equal(1.0)
	assert_bool(_game.ruins.light_on(&"mole")).is_true()
	# Never twice; never a ghost, never in Progress.buildings (can't be moved or undone).
	assert_bool(_game.restore_ruin(&"old_shed")).is_false()
	assert_bool(b.has_ghost(P1)).is_false()
	assert_int(Progress.buildings.size()).is_equal(0)
	assert_array(b.restore_rows(P1).map(func(d: BuildingData) -> StringName: return d.id)).is_equal([&"museum"])
	# He moves in by his door.
	await _until(func() -> bool: return _game.town.mole_mode() == &"home", 120)
	assert_float(absf(_game.town.mole.position.x - _game.ruins.door_of(&"mole").x)).is_less(80.0)


# --- payoffs -----------------------------------------------------------------------------------

func test_lost_and_found_leaves_a_bundle_that_a_player_picks_up() -> void:
	_make()
	_join()
	await _physics(2)
	await _restore(&"mole")
	_stand_at(Hillville.SHAFT_X)
	assert_bool(_game.ruins.has_bundle()).is_false()
	_game.ruins.found_every = 1.0
	await _physics(64)
	assert_bool(_game.ruins.has_bundle()).is_true()
	var before := Inventory.count(&"dirt")
	_stand_at(_game.ruins.door_of(&"mole").x - 26.0)
	await _physics(3)
	assert_bool(_game.ruins.has_bundle()).is_false()
	assert_int(Inventory.count(&"dirt")).is_equal(before + RuinSites.FOUND_BLOCKS)


func test_gnome_village_crew_leaves_a_capped_pile_after_time_away() -> void:
	_make()
	_join()
	await _physics(2)
	assert_int(_game.ruins.crew_return(10 * 3600.0)).is_equal(0)   # no village yet
	await _restore(&"gnome_foreman")
	assert_str(String(_game.town.foreman_mode())).is_equal("tower")
	assert_int(_game.ruins.crew_return(600.0)).is_equal(0)          # under 30 minutes
	var before := _total()
	var n := _game.ruins.crew_return(100 * 3600.0)
	assert_int(n).is_equal(Rules.GNOME_CAP)
	assert_bool(_game.ruins.crew_clip_playing()).is_true()
	var after := _total()
	assert_int(after - before).is_equal(n)


func test_the_crew_award_runs_on_load_from_the_saved_stamp() -> void:
	_make()
	_join()
	await _physics(2)
	await _restore(&"gnome_foreman")
	_game.save.save_now()
	# Pretend the save was written three hours ago.
	Save.set_value("gnome_stamp", int(Time.get_unix_time_from_system()) - 3 * 3600)
	Save.flush()
	_game.free()
	Players.reset()
	Inventory.clear()
	_make(true)
	_join()
	assert_bool(_game.ruins.crew_clip_playing()).is_true()
	assert_int(Inventory.count(&"dirt")).is_greater_equal(Rules.GNOME_FLOOR)


func test_museum_takes_the_treasure_shelf_and_the_caveman_polishes() -> void:
	_make()
	_join()
	await _physics(2)
	Progress.find_treasure(&"bottle_caps", P1)
	var x0 := _game.shelf.position.x
	await _restore(&"caveman")
	assert_bool(_game.shelf.museum).is_true()
	assert_float(_game.shelf.position.x).is_not_equal(x0)
	assert_str(String(_game.town.caveman_mode())).is_equal("museum")
	_stand_at(_game.shelf.position.x - 80.0)
	await _physics(60 * 4)
	assert_str(String(_game.shelf.polishing)).is_equal("bottle_caps")


func test_dragon_perch_flies_her_up_and_warms_the_ice() -> void:
	_make()
	_join()
	await _physics(2)
	_game.story.meet_dragon()
	_game.story.wake_dragon()
	await _until(func() -> bool: return _game.town.dragon_mode() == &"wait", 60 * 12)
	assert_bool(_game.story.ice_warm()).is_false()
	await _restore(&"dragon")
	assert_bool(_game.story.ice_warm()).is_true()
	await _until(func() -> bool: return _game.town.dragon_mode() == &"perch", 60 * 8)
	assert_str(String(_game.town.dragon_mode())).is_equal("perch")
	assert_float(_game.town.dragon.position.y).is_less(-80.0)   # up on the perch


func test_residents_react_to_a_building_placed_near_them() -> void:
	_make()
	_join()
	await _physics(2)
	_arrive(&"mole")
	await _until(func() -> bool: return _game.town.mole_mode() == &"wait", 120)
	Progress.add_building(&"barn", Vector2i(int(TownResidents.MOLE_WAIT_X / 48.0) - 4, 0))
	await _physics(1)
	assert_array(_game.town.saying(&"mole")).is_equal([&"home:barn", &"heart"])


func test_town_gags_pond_and_dump_truck() -> void:
	_make()
	_join()
	await _physics(2)
	for id in [&"mole", &"caveman"]:
		await _restore(id)
	await _physics(30)
	_game.town._mole.cd_pond = 0.0
	_stand_at(Hillville.POND.get_center().x - 100.0)
	await _until(func() -> bool: return _game.town.mole_mode() == &"pond", 120)
	assert_str(String(_game.town.mole_mode())).is_equal("pond")
	if not Progress.has_vehicle(&"dump_truck"):
		Progress.vehicles.append(&"dump_truck")
	_game.park_new(&"dump_truck", _game.town.caveman.position + Vector2(80, 0))
	await _until(func() -> bool: return _game.town.caveman_mode() == &"baffled", 60)
	assert_array(_game.town.saying(&"caveman")).is_equal([&"question"])


# --- save --------------------------------------------------------------------------------------

func test_every_arc_state_survives_a_reload() -> void:
	_make()
	_join()
	await _physics(2)
	_game.story.steal_shovel()                     # mole: ENCOUNTERED, 1
	_arrive(&"caveman")                            # caveman: ARRIVED
	await _restore(&"gnome_foreman")               # foreman: RESTORED
	_game.story.meet_dragon()                      # dragon: ENCOUNTERED
	_game.story.extras["found_waiting"] = true
	_game.save.save_now()
	_game.free()
	Players.reset()
	_make(true)
	_join()
	await _physics(2)
	var st := _game.story
	assert_int(st.phase(&"mole")).is_equal(ResidentState.Phase.ENCOUNTERED)
	assert_int(st.state(&"mole").encounters).is_equal(1)
	assert_int(st.phase(&"caveman")).is_equal(ResidentState.Phase.ARRIVED)
	assert_int(st.phase(&"gnome_foreman")).is_equal(ResidentState.Phase.RESTORED)
	assert_int(st.phase(&"dragon")).is_equal(ResidentState.Phase.ENCOUNTERED)
	assert_bool(st.extras.get("found_waiting", false)).is_true()
	assert_bool(_game.hillville.is_ruin_restored(&"crooked_watchtower")).is_true()
	assert_bool(_game.hillville.is_ruin_restored(&"old_shed")).is_false()
	assert_bool(_game.ruins.homes.has(&"gnome_foreman")).is_true()
	assert_bool(_game.ruins.light_on(&"gnome_foreman")).is_true()
	assert_bool(_game.hillville._silhouette.get(&"ruined_keep", false)).is_true()
	assert_str(String(_game.town.foreman_mode())).is_equal("tower")
