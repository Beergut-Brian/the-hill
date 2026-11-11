## Loose things lane (W-19, W-20), in simulated physics time: a treasure dug out from under drops
## whole, lands, stays where it lands and is picked up with A; the Buried Car, the bathtub and the
## Gnome Room break into picture chunks with a crumble (the car and the room are found and their
## chunks pop into the backpack as blocks; the bathtub's chunks are the bathtub, picked up whole);
## the Mole falls when his floor is dug out, bounces, waves and walks on.
class_name TestLooseThings
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
	Save.settings_path = "user://test_settings_loose_things.json"
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
	Save.profile = "test_loose_things"
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
	Save.wipe()
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


func _carve(room: Rect2i) -> void:
	var w := _game.underground.world
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.set_tile(Vector2i(x, y), 0)


func _spot(id: StringName) -> Rect2i:
	for sp in _game.underground.generator.treasure_spots:
		if sp.id == id:
			return sp.rect
	return Rect2i()


## Stands P1 underground at feet `pos` (px) and loads the chunks there.
func _stand(p: HillPlayer, pos: Vector2) -> void:
	_game.place_player(P1, HillGame.UNDERGROUND, pos)
	p.velocity = Vector2.ZERO
	_game.underground.world.update_chunks()


## Waits until every body is asleep (a landing, a bounce, then rest).
func _settle(bodies: Array, max_frames := 600) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		if i > 30 and bodies.all(func(b) -> bool: return not is_instance_valid(b) or (b as FallingBody).sleeping):
			return


func _played(cue: String, since: Variant) -> bool:
	return Audio._last_start.get(cue, null) != null and Audio._last_start.get(cue) != since


# --- W-19 ---------------------------------------------------------------------------------------

func test_a_treasure_dug_out_from_under_drops_lands_stays_and_is_picked_up_with_a() -> void:
	_make()
	var u := _game.underground
	var p := _join()
	var r := _spot(&"bottle_caps")
	assert_bool(r.size != Vector2i.ZERO).is_true()
	# A hole three deep under it, and a room beside the hole to stand in (dug well away from it).
	_carve(Rect2i(r.position.x, r.end.y + 1, 1, 3))
	_carve(Rect2i(r.position.x - 6, r.end.y + 2, 6, 2))
	_stand(p, Vector2((r.position.x - 5) * 16.0 + 8.0, (r.end.y + 4) * 16.0 - 1.0))
	await _physics(5)
	u.world.dig(Vector2i(r.position.x, r.end.y), [Vector2i.ZERO], P1)
	# Dug from under: it came loose, and is not found yet (the dig was beside it, too).
	assert_bool(Progress.has_treasure(&"bottle_caps")).is_false()
	assert_bool(u.loose.has(&"bottle_caps")).is_true()
	var b: FallingBody = u.loose[&"bottle_caps"][0]
	if SheetSprite.has_sheet("treasures/bottle_caps.png"):
		assert_object(b.get_node_or_null("Art")).is_not_null()
	await _settle([b])
	assert_bool(b.sleeping).is_true()
	assert_int(u.world.shape.cell_at(b.position).y).is_equal(r.end.y + 3)
	var landed_at := b.position
	await _physics(60)
	assert_float(b.position.distance_to(landed_at)).is_less(0.5)
	assert_bool(Progress.has_treasure(&"bottle_caps")).is_false()
	# A from out of reach does nothing to it; A beside it picks it up (the reveal pops it up).
	p.dig_now(Vector2(1, 0))
	assert_bool(Progress.has_treasure(&"bottle_caps")).is_false()
	_stand(p, Vector2((r.position.x - 1) * 16.0 + 8.0, (r.end.y + 4) * 16.0 - 1.0))
	p.facing = 1
	await _physics(3)
	p.dig_now(Vector2(1, 0))
	assert_bool(Progress.has_treasure(&"bottle_caps")).is_true()
	assert_bool(u.loose.has(&"bottle_caps")).is_false()
	assert_int(u.world.find_children("*", "TreasureReveal", false, false).size()).is_equal(1)
	await _physics(2)
	assert_bool(is_instance_valid(b)).is_false()


func test_the_mole_falls_when_his_floor_is_dug_out_bounces_waves_and_walks_on() -> void:
	_make()
	var u := _game.underground
	var res := u.residents
	assert_object(res.mole).is_not_null()
	await _physics(2)
	var home := res.mole.position
	var floor_row := int(floor((home.y + 2.0) / 16.0))
	var col := int(floor(home.x / 16.0))
	_carve(Rect2i(col - 2, floor_row, 5, 3))
	var waved: Array = []
	var since: Variant = Audio._last_start.get("mole_wave", null)
	var low := home.y
	for i in 240:
		await get_tree().physics_frame
		low = minf(low, res.mole.position.y)
		if res.mole_falls > 0 and not res._mole.get("falling", false) and _played("mole_wave", since):
			waved.append(i)
			break
	assert_int(res.mole_falls).is_equal(1)
	assert_array(waved).is_not_empty()
	assert_float(res.mole_floor).is_equal_approx(home.y + 48.0, 0.5)
	assert_float(res.mole.position.y).is_less_equal(res.mole_floor + 0.5)
	assert_bool(res.mole.visible).is_true()
	# Never hurt: nothing happened to any player; he shuffles on at the new floor.
	await _physics(200)
	assert_float(res.mole.position.y).is_less_equal(res.mole_floor + 0.5)
	assert_float(res.mole.position.y).is_greater(home.y + 40.0)
	assert_int(res.mole_falls).is_equal(1)


# --- W-20 ---------------------------------------------------------------------------------------

## Digs out the row under a prop and a hole two deep below it; returns the pieces it broke into.
func _undercut(id: StringName) -> Array:
	var u := _game.underground
	var r := _spot(id)
	_carve(Rect2i(r.position.x, r.end.y + 1, r.size.x, 2))
	var broke: Array = []
	u.world.prop_broke.connect(func(_p, pieces): broke.append_array(pieces), CONNECT_ONE_SHOT)
	for x in range(r.position.x, r.end.x):
		u.world.set_tile(Vector2i(x, r.end.y), 0)
	return broke


func test_the_car_and_the_gnome_room_crumble_into_chunks_that_pop_into_the_backpack() -> void:
	_make()
	var u := _game.underground
	var p := _join()
	for id: StringName in [&"buried_car", &"gnome_room"]:
		var r := _spot(id)
		_stand(p, Vector2((r.position.x - 3) * 16.0, (r.end.y + 3) * 16.0 - 1.0))
		_carve(Rect2i(r.position.x - 4, r.end.y + 1, 4, 2))
		await _physics(3)
		var since: Variant = Audio._last_start.get("wall_crumble", null)
		var pieces := _undercut(id)
		assert_int(pieces.size()).is_equal(r.size.x * r.size.y)
		assert_bool(_played("wall_crumble", since)).is_true()
		# Nothing is lost: the treasure is found (the Garage, the crew), and its chunks are rubble.
		assert_bool(Progress.has_treasure(id)).is_true()
		for piece in pieces:
			assert_bool(u.rubble.has(piece)).is_true()
			if SheetSprite.has_sheet("treasures/%s.png" % id):
				assert_float((piece as FallingBody).self_modulate.a).is_equal(0.0)
		await _settle(pieces)
		var before := p.backpack_count()
		var near: FallingBody = null
		for piece in pieces:
			if near == null or (piece as Node2D).position.x < near.position.x:
				near = piece
		_stand(p, near.position + Vector2(-14.0, 6.0))
		await _physics(3)
		var left := u.rubble.size()
		assert_bool(u.grab_loose(p)).is_true()
		assert_int(p.backpack_count()).is_equal(before + 1)
		assert_int(u.rubble.size()).is_equal(left - 1)
	assert_str(String(u.residents.crew_state())).is_not_equal("walled")


func test_the_bathtub_crumbles_and_picking_up_a_chunk_gets_the_whole_bathtub() -> void:
	_make()
	var u := _game.underground
	var p := _join()
	var r := _spot(&"bathtub")
	_stand(p, Vector2((r.position.x - 3) * 16.0, (r.end.y + 3) * 16.0 - 1.0))
	_carve(Rect2i(r.position.x - 4, r.end.y + 1, 4, 2))
	await _physics(3)
	var pieces := _undercut(&"bathtub")
	assert_int(pieces.size()).is_equal(6)
	assert_bool(Progress.has_treasure(&"bathtub")).is_false()
	assert_int((u.loose[&"bathtub"] as Array).size()).is_equal(6)
	await _settle(pieces)
	var near: FallingBody = pieces[0]
	for piece in pieces:
		if (piece as Node2D).position.x < near.position.x:
			near = piece
	_stand(p, near.position + Vector2(-14.0, 6.0))
	await _physics(3)
	assert_bool(u.grab_loose(p)).is_true()
	assert_bool(Progress.has_treasure(&"bathtub")).is_true()
	assert_int(p.backpack_count()).is_equal(0)
	await _physics(2)
	for piece in pieces:
		assert_bool(is_instance_valid(piece)).is_false()
	assert_int(u.world.find_children("*", "TreasureReveal", false, false).size()).is_equal(1)


func test_digging_the_whole_row_under_a_wide_treasure_in_one_swing_does_not_find_it() -> void:
	_make()
	var u := _game.underground
	var p := _join()
	var r := _spot(&"bike")
	assert_int(r.size.x).is_greater(1)
	_carve(Rect2i(r.position.x - 6, r.end.y + 1, r.size.x + 6, 2))
	_stand(p, Vector2((r.position.x - 5) * 16.0 + 8.0, (r.end.y + 3) * 16.0 - 1.0))
	await _physics(3)
	var row: Array[Vector2i] = []
	for x in r.size.x:
		row.append(Vector2i(x, 0))
	u.world.dig(Vector2i(r.position.x, r.end.y), row, P1)
	assert_bool(Progress.has_treasure(&"bike")).is_false()
	assert_bool(u.loose.has(&"bike")).is_true()
