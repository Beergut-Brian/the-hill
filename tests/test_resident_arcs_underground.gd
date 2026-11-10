## The residents' arcs underground (Gameplay lane, 2026-11-10), in simulated physics time on a real
## HillGame: the Mole's three shovel thefts (never blocking, never while driving) bring him up; the
## opened Gnome Room frees the crew; the Caveman follows to the shaft; the Dragon's second meeting
## brings her up in pieces; every phase survives a save; the Lost & Found visit glows and gives.
class_name TestResidentArcsUnderground
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

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


func _join(p: int) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return _intent[p]
	return node


func _reload() -> void:
	_game.save.save_now()
	_game.free()
	Players.reset()
	_make(true)
	_join(P1)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


func _hold(move: Vector2, dig := false) -> void:
	_intent[P1] = {"move": move, "dig": dig, "jump": false, "book": false, "horn": false}


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


func _spot(id: StringName) -> Rect2i:
	for s in _game.underground.generator.treasure_spots:
		if s.id == id:
			return s.rect
	return Rect2i()


func _mole_encounters() -> int:
	return _game.story.state(Story.MOLE).encounters


# --- the Mole ----------------------------------------------------------------------------------

func test_three_thefts_bring_the_mole_up_and_there_is_no_fourth() -> void:
	_make()
	var p := _join(P1)
	var res := _game.underground.residents
	res.steal_cooldown = 0.0
	_stage(Rect2i(60, 14, 8, 2), Vector2i(64, 15))
	await _physics(5)
	var stolen := [0]
	res.shovel_stolen.connect(func(_p: int) -> void: stolen[0] += 1)
	for i in 3:
		assert_bool(res.steal(p)).is_true()
		assert_str(String(res.mole_state())).is_equal("theft")
		await _until(func() -> bool: return res.theft_time() < 0.0, 300)
		assert_float(res.theft_time()).is_less(0.0)
		assert_int(_mole_encounters()).is_equal(i + 1)
		if i < 2:
			# Back at home, still stealing.
			assert_bool(res.mole.visible).is_true()
			assert_vector(res.mole.position).is_equal(res.mole_home)
			assert_int(_game.story.phase(Story.MOLE)).is_equal(ResidentState.Phase.ENCOUNTERED)
	assert_int(stolen[0]).is_equal(3)
	assert_bool(_game.story.arrived(Story.MOLE)).is_true()
	assert_bool(res.mole.visible).is_false()
	# No fourth: neither on request nor from digging on foot.
	assert_bool(res.steal(p)).is_false()
	_hold(Vector2(1, 0), true)
	await _physics(240)
	assert_int(stolen[0]).is_equal(3)
	assert_int(_mole_encounters()).is_equal(3)
	assert_bool(res.mole.visible).is_false()


func test_digging_on_foot_brings_a_theft_that_never_blocks_digging_or_walking() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var res := u.residents
	_stage(Rect2i(56, 14, 4, 2), Vector2i(59, 15))
	await _physics(5)
	var dug := [0]
	var on_dug := func(_c: Vector2i, _b: StringName, who: int) -> void:
		if who == P1:
			dug[0] += 1
	Events.tile_dug.connect(on_dug)
	_hold(Vector2(1, 0), true)
	await _until(func() -> bool: return res.theft_time() >= 0.0, 600)
	assert_float(res.theft_time()).is_greater_equal(0.0)
	assert_int(dug[0]).is_greater_equal(UndergroundResidents.STEAL_FIRST)
	var x0 := p.global_position.x
	var d0: int = dug[0]
	var bag0 := p.backpack_count()
	# Keeps digging and walking through the whole theft.
	await _until(func() -> bool: return res.theft_time() < 0.0, 300)
	assert_int(_mole_encounters()).is_equal(1)
	assert_int(dug[0]).is_greater(d0 + 3)
	assert_float(p.global_position.x).is_greater(x0 + 32.0)
	assert_int(p.backpack_count()).is_greater_equal(bag0)
	# The cooldown: digging on does not bring a second one at once.
	await _physics(180)
	assert_int(_mole_encounters()).is_equal(1)
	Events.tile_dug.disconnect(on_dug)


func test_driving_never_brings_a_theft() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var res := u.residents
	res.steal_cooldown = 0.0
	var room := Rect2i(56, 12, 6, 4)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			u.world.set_tile(Vector2i(x, y), 0)
	var feet := Vector2(59 * 16.0, room.end.y * 16.0 - 1.0)
	if not Progress.has_vehicle(&"excavator"):
		Progress.vehicles.append(&"excavator")
	_game.park_new(&"excavator", feet, HillGame.UNDERGROUND)
	_game.place_player(P1, HillGame.UNDERGROUND, feet)
	p.velocity = Vector2.ZERO
	assert_bool(_game.hop_in(p)).is_true()
	assert_object(p.vehicle).is_not_null()
	var dug := [0]
	var on_dug := func(_c: Vector2i, _b: StringName, who: int) -> void:
		if who == P1:
			dug[0] += 1
	Events.tile_dug.connect(on_dug)
	_hold(Vector2(1, 0), true)
	await _physics(360)
	assert_int(dug[0]).is_greater(UndergroundResidents.STEAL_FIRST * 2)
	assert_int(_mole_encounters()).is_equal(0)
	assert_float(res.theft_time()).is_less(0.0)
	Events.tile_dug.disconnect(on_dug)


func test_a_lost_and_found_visit_glows_unfound_treasure_and_gives_blocks() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var res := u.residents
	for i in 3:
		_game.story.steal_shovel()
	assert_bool(_game.story.restore(Story.MOLE)).is_true()
	assert_bool(res.steal(p)).is_false()
	var r := _spot(&"bottle_caps")
	assert_bool(r.size != Vector2i.ZERO).is_true()
	_stage(Rect2i(r.position.x - 9, r.end.y - 2, 4, 2), Vector2i(r.position.x - 6, r.end.y - 1))
	await _physics(5)
	var block := res._layer_block(u.to_local(p.global_position).y - 8.0)
	var before := Inventory.count(block)
	assert_bool(res.visit_now(p)).is_true()
	await _physics(10)
	assert_bool(res.mole_visiting()).is_true()
	assert_bool(res.mole.visible).is_true()
	var glow := res.glowing_treasures()
	assert_array(glow).contains([&"bottle_caps"])
	for id in glow:
		assert_bool(Progress.has_treasure(id)).is_false()
	await _until(func() -> bool: return not res.mole_visiting(), int(UndergroundResidents.VISIT_STAY * 60) + 30)
	assert_bool(res.mole_visiting()).is_false()
	assert_int(Inventory.count(block)).is_equal(before + UndergroundResidents.VISIT_GIFT)
	assert_array(res.glowing_treasures()).is_empty()
	# A found treasure never glows.
	Progress.find_treasure(&"bottle_caps", P1)
	assert_bool(res.visit_now(p)).is_true()
	await _physics(10)
	assert_array(res.glowing_treasures()).not_contains([&"bottle_caps"])


# --- the gnome crew ----------------------------------------------------------------------------

func test_opening_the_gnome_room_frees_the_crew() -> void:
	_make()
	_join(P1)
	var res := _game.underground.residents
	assert_int(res.crew.size()).is_equal(3)
	assert_str(String(res.crew_state())).is_equal("walled")
	assert_int(_game.story.phase(Story.FOREMAN)).is_equal(ResidentState.Phase.UNMET)
	var gr := _spot(&"gnome_room")
	# A room left of the cavity, one cell of rock short of "found" range; dig right into it.
	_stage(Rect2i(gr.position.x - 8, gr.end.y - 2, 5, 2), Vector2i(gr.position.x - 4, gr.end.y - 1))
	await _physics(5)
	_hold(Vector2(1, 0), true)
	await _until(func() -> bool: return res.crew_state() != &"walled", 240)
	assert_bool(Progress.has_treasure(&"gnome_room")).is_true()
	assert_str(String(res.crew_state())).is_equal("freeing")
	assert_bool(_game.story.arrived(Story.FOREMAN)).is_true()
	_hold(Vector2.ZERO)
	await _until(func() -> bool: return res.crew_state() == &"gone", 60 * 8)
	assert_str(String(res.crew_state())).is_equal("gone")
	for c in res.crew:
		assert_bool(c.visible).is_false()
	assert_bool(res.free_crew()).is_false()


func test_a_gnome_room_found_in_the_save_frees_the_crew_on_load() -> void:
	_make()
	_join(P1)
	# Found without the event (an older save): the crew is still walled in.
	Progress.treasures.append(&"gnome_room")
	assert_str(String(_game.underground.residents.crew_state())).is_equal("walled")
	_reload()
	var res := _game.underground.residents
	assert_str(String(res.crew_state())).is_equal("freeing")
	assert_bool(_game.story.arrived(Story.FOREMAN)).is_true()


# --- the Caveman -------------------------------------------------------------------------------

func test_the_caveman_follows_then_walks_into_the_shaft() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var res := u.residents
	var ice := 3
	var room: Rect2i = u.generator.landings[ice]
	# A tunnel on from the landing room's right end.
	var tunnel := Rect2i(room.end.x, room.position.y, 14, room.size.y)
	_stage(tunnel, Vector2i(room.end.x - 1, room.end.y - 1))
	await _until(func() -> bool: return res.caveman_state() == &"following", int((UndergroundResidents.THAW_SECS + 2.5) * 60))
	assert_str(String(res.caveman_state())).is_equal("following")
	assert_bool(_game.story.arrived(Story.CAVEMAN)).is_true()
	# Walk off down the tunnel: he keeps up at about FOLLOW_GAP.
	_hold(Vector2(1, 0))
	await _physics(45)
	_hold(Vector2.ZERO)
	await _physics(40)
	assert_str(String(res.caveman_state())).is_equal("following")
	var gap := absf(res.caveman.position.x - u.to_local(p.global_position).x)
	assert_float(gap).is_between(UndergroundResidents.FOLLOW_GAP - 6.0, UndergroundResidents.FOLLOW_GAP + 6.0)
	# Back to the shaft: he walks in and goes up.
	_hold(Vector2(-1, 0))
	await _until(func() -> bool: return res.caveman_state() == &"leaving", 240)
	assert_str(String(res.caveman_state())).is_equal("leaving")
	_hold(Vector2.ZERO)
	await _until(func() -> bool: return res.caveman_state() == &"gone", 60 * 6)
	assert_str(String(res.caveman_state())).is_equal("gone")
	assert_bool(res.caveman.visible).is_false()


# --- the Dragon --------------------------------------------------------------------------------

func test_the_dragon_second_meeting_brings_her_up_and_not_before_the_first() -> void:
	_make()
	var p := _join(P1)
	var u := _game.underground
	var res := u.residents
	var d := res.dragon
	var feet_y := HillGenerator.CAVERN.end.y * 16.0 - 2.0
	# Not before the first meeting.
	assert_bool(res.wake()).is_false()
	assert_bool(_game.story.wake_dragon()).is_false()
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(d.position.x - 140.0, feet_y))
	p.velocity = Vector2.ZERO
	await _until(func() -> bool: return res.dragon_state() == &"waking", 30)
	assert_str(String(res.dragon_state())).is_equal("waking")
	assert_int(_game.story.phase(Story.DRAGON)).is_equal(ResidentState.Phase.ENCOUNTERED)
	await _until(func() -> bool: return res.dragon_state() == &"asleep", int(UndergroundResidents.REVEAL_TIME * 60) + 10)
	# Straight after the yawn she sleeps on a moment, even with a player near.
	assert_str(String(res.dragon_state())).is_equal("asleep")
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2(d.position.x - 60.0, feet_y))
	p.velocity = Vector2.ZERO
	await _physics(int(UndergroundResidents.WAKE_GRACE * 60) - 10)
	assert_str(String(res.dragon_state())).is_equal("asleep")
	await _until(func() -> bool: return res.dragon_state() == &"waking_up", 30)
	assert_str(String(res.dragon_state())).is_equal("waking_up")
	await _until(func() -> bool: return not res.dragon_bubble().is_empty(), 90)
	assert_array(res.dragon_bubble()).contains([&"face_sheepish"])
	await _until(func() -> bool: return res.dragon_state() == &"leaving", int(UndergroundResidents.WAKE_LEAVE * 60) + 10)
	assert_bool(_game.story.arrived(Story.DRAGON)).is_true()
	assert_bool(d.visible).is_false()
	await _until(func() -> bool: return res.dragon_state() == &"gone", 60 * 8)
	assert_str(String(res.dragon_state())).is_equal("gone")
	assert_bool(res.wake()).is_false()


# --- saves -------------------------------------------------------------------------------------

func test_every_phase_survives_a_save() -> void:
	_make()
	_join(P1)
	var st := _game.story
	for i in 3:
		st.steal_shovel()
	Progress.find_treasure(&"gnome_room", P1)
	st.thaw_caveman()
	st.meet_dragon()
	st.wake_dragon()
	assert_bool(st.restore(Story.DRAGON)).is_true()
	await _physics(2)
	assert_bool(_game.underground.look.ice_warm).is_true()
	_reload()
	await _physics(3)
	var u := _game.underground
	var res := u.residents
	assert_bool(_game.story.arrived(Story.MOLE)).is_true()
	assert_bool(res.mole.visible).is_false()
	assert_bool(res.steal(_game.player_node(P1))).is_false()
	assert_bool(_game.story.arrived(Story.FOREMAN)).is_true()
	assert_str(String(res.crew_state())).is_equal("gone")
	for c in res.crew:
		assert_bool(c.visible).is_false()
	assert_str(String(res.caveman_state())).is_equal("gone")
	assert_bool(res.caveman.visible).is_false()
	assert_str(String(res.dragon_state())).is_equal("gone")
	assert_bool(res.dragon.visible).is_false()
	# The Dragon Perch: the Ice band is warm (softer darkness).
	assert_bool(u.look.ice_warm).is_true()
	var ice: LayerData = load("res://data/layers/ice.tres")
	var mid := (ice.depth_from + ice.depth_to) / 2
	assert_float(u.world.darkness_at(mid)).is_less(ice.darkness - 0.1)


func test_a_cold_save_keeps_the_ice_layer_cold() -> void:
	_make()
	_join(P1)
	var u := _game.underground
	var ice: LayerData = load("res://data/layers/ice.tres")
	var mid := (ice.depth_from + ice.depth_to) / 2
	assert_bool(u.look.ice_warm).is_false()
	assert_float(u.world.darkness_at(mid)).is_equal_approx(ice.darkness, 0.0001)
