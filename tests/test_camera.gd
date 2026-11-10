## Camera lane (S-04, S-06, S-07): the underground lead (leads in the move direction, eases back),
## the zoom per vehicle (data/camera.tres), and the layer pick on the way down the shaft (the
## picked layer is where the cage stops; up past the top goes back to Hillville).
class_name TestCamera
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2

var _game: HillGame
var _real_profile := ""
var _real_settings := ""


func before() -> void:
	_real_profile = Save.profile
	# Its own settings file: nothing here may write into the real user://settings.json.
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_camera.json"
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
	Save.profile = "test_camera"
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


## Joins p; `intent` is read live (mutate it to steer).
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


## Seconds of camera easing at a fixed step (on top of the real frames).
func _ease(secs: float) -> void:
	for i in int(secs / 0.05):
		_game.camera.step(0.05)


func _underground(p: int) -> HillPlayer:
	var node := _game.player_node(p)
	_game.place_player(p, &"underground", _game.underground.landing(0) + Vector2(160, 0))
	return node


# --- S-06 lead ---------------------------------------------------------------------------------

func test_lead_follows_the_move_direction_and_eases_back() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	_underground(P1)
	var t := _game.camera.tuning
	it.move = Vector2(1, 0)
	await _physics(2)
	_ease(2.0)
	var lead := _game.camera.lead_of(P1)
	assert_float(lead.x).is_greater(t.lead_px.x * 0.9)
	assert_float(absf(lead.y)).is_less(1.0)
	# The camera itself sits ahead of the player (hold the player still to measure it).
	node.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := _game.director.camera_of(P1)
	assert_float(cam.position.x - node.global_position.x).is_greater(t.lead_px.x * 0.6)
	node.set_physics_process(true)
	# Let go: it eases back (not a jump: halfway after a short moment, home after a while).
	it.move = Vector2.ZERO
	await _physics(2)
	_game.camera.step(0.1)
	var mid := _game.camera.lead_of(P1).x
	assert_float(mid).is_greater(0.0)
	_ease(4.0)
	assert_float(absf(_game.camera.lead_of(P1).x)).is_less(1.0)
	# Digging down leads down; left leads left.
	it.move = Vector2(0, 1)
	it.dig = true
	await _physics(2)
	_ease(2.0)
	assert_float(_game.camera.lead_of(P1).y).is_greater(t.lead_px.y * 0.9)
	it.dig = false
	it.move = Vector2(-1, 0)
	await _physics(2)
	_ease(2.0)
	assert_float(_game.camera.lead_of(P1).x).is_less(-t.lead_px.x * 0.9)


func test_no_lead_up_top_or_while_riding() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	it.move = Vector2(1, 0)
	await _physics(2)
	_ease(2.0)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_float(_game.camera.lead_of(P1).length()).is_less(1.0)
	_underground(P1)
	node.locked = true
	await _physics(2)
	_ease(2.0)
	assert_float(_game.camera.lead_of(P1).length()).is_less(1.0)


func test_shared_camera_has_no_lead() -> void:
	_make()
	var it := _idle()
	var a := _join(P1, it)
	var b := _join(P2, _idle())
	_underground(P1)
	_game.place_player(P2, &"underground", a.global_position + Vector2(40, 0))
	it.move = Vector2(1, 0)
	await _physics(2)
	_ease(2.0)
	a.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_game.director.is_split()).is_false()
	assert_float(_game.camera.lead_of(P1).x).is_greater(30.0)
	var mid := (a.global_position + b.global_position) * 0.5
	assert_float(absf(_game.director.camera_of(P1).position.x - mid.x)).is_less(2.0)


# --- S-06 zoom / S-07 --------------------------------------------------------------------------

func test_zoom_per_vehicle_from_data() -> void:
	var t := CameraTuning.load_default()
	assert_float(t.zoom).is_equal(2.0)   # S-07: unchanged until the TV check
	for id in [&"dump_truck", &"crane"]:
		assert_float(t.zoom_factor(id)).is_less(1.0)
		assert_float(t.zoom_factor(id)).is_greater_equal(0.75)   # a little, not a lot
	for id in [&"front_loader", &"excavator", &""]:
		assert_float(t.zoom_factor(id)).is_equal(1.0)
	_make()
	assert_float(_game.director.zoom).is_equal(t.zoom)
	var node := _join(P1, _idle())
	_underground(P1)
	await _physics(2)
	_ease(3.0)
	assert_float(_game.camera.zoom_of(P1)).is_equal_approx(2.0, 0.01)
	for id in [&"dump_truck", &"crane", &"excavator"]:
		node.drive(Progress.vehicle_data(id))
		_ease(4.0)
		assert_float(_game.camera.zoom_of(P1)).is_equal_approx(t.zoom * t.zoom_factor(id), 0.01)
		# process_frame fires before the nodes' _process: the second one sees the first's work.
		await get_tree().process_frame
		await get_tree().process_frame
		assert_float(_game.director.camera_of(P1).zoom.x).is_equal_approx(_game.camera.zoom_of(P1), 0.02)
		node.stop_driving()
	_ease(4.0)
	assert_float(_game.camera.zoom_of(P1)).is_equal_approx(2.0, 0.01)


# --- S-04 layer pick ---------------------------------------------------------------------------

func _into_cage(p: int, deepest: int) -> void:
	for i in deepest + 1:
		Progress.visit_layer(p, i)
	_game.place_player(p, &"hillville", _game.hillville.arrival() + Vector2(0, -1))
	_game.elevator.door.must_exit.erase(p)
	await _until(func() -> bool: return _game.elevator.pick_of(p) >= -1, 120)


func _pictures() -> LayerPick:
	return _game.hillville.get_node_or_null(^"LayerPick") as LayerPick


func test_picked_layer_is_where_the_cage_stops() -> void:
	_make()
	var it := _idle()
	var node := _join(P1, it)
	await _into_cage(P1, 3)
	# Default: the deepest layer; the pictures show Hillville plus layers 0..3.
	assert_int(_game.elevator.pick_of(P1)).is_equal(3)
	var pics := _pictures()
	assert_object(pics).is_not_null()
	assert_int(pics.layers.size()).is_equal(4)
	assert_int(pics.pick).is_equal(3)
	# Up twice with the stick (edge presses) while the cage moves.
	for k in 2:
		it.move = Vector2(0, -1)
		await _physics(2)
		it.move = Vector2.ZERO
		await _physics(2)
	assert_int(_game.elevator.pick_of(P1)).is_equal(1)
	assert_int(pics.pick).is_equal(1)
	await _until(func() -> bool: return _game.director.scene_of(P1) == &"underground", 300)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
	assert_float(node.global_position.distance_to(_game.underground.landing(1))).is_less(20.0)
	assert_bool(node.locked).is_false()
	await get_tree().process_frame
	assert_bool(is_instance_valid(pics) and pics.is_inside_tree()).is_false()


func test_pick_stops_at_the_ends_and_up_top_goes_back_to_hillville() -> void:
	_make()
	var node := _join(P1, _idle())
	await _into_cage(P1, 2)
	assert_bool(_game.elevator.nudge_pick(P1, 1)).is_false()   # no deeper than the deepest
	assert_int(_game.elevator.pick_of(P1)).is_equal(2)
	for k in 5:
		_game.elevator.nudge_pick(P1, -1)
	assert_int(_game.elevator.pick_of(P1)).is_equal(-1)          # Hillville, no further
	await _until(func() -> bool: return not _game.elevator.is_riding(P1), 300)
	assert_str(String(_game.director.scene_of(P1))).is_equal("hillville")
	assert_bool(node.locked).is_false()
	assert_float(node.modulate.a).is_equal(1.0)
	# It does not ride again until P1 steps out of the cage.
	assert_bool(_game.elevator.door.must_exit.has(P1)).is_true()


func test_press_keeps_the_cage_going_but_never_long() -> void:
	_make()
	_join(P1, _idle())
	await _into_cage(P1, 5)
	var frames := 0
	while _game.elevator.is_riding(P1) and frames < 600:
		if frames % 10 == 0:
			_game.elevator.nudge_pick(P1, -1 if (frames / 10) % 2 == 0 else 1)
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(int(HillElevator.PICK_MAX * 60) + 6)
	assert_str(String(_game.director.scene_of(P1))).is_equal("underground")
