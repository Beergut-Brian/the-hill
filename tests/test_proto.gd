## The Phase 1 prototype (scenes/proto): boot, elevator ride and re-arming, digging into the shared
## pile, the set piece (boulder, water pocket), split rules, the --proto flags and Audio's synth beep.
class_name TestProto
extends GdUnitTestSuite

const PROTO := preload("res://scenes/proto/foundation_proto.tscn")
const MAIN := preload("res://scenes/main.gd")
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false}

var _proto: FoundationProto
var _entered: Array = []
var _dug: Array = []
var _on_entered := func(p: int, s: StringName) -> void: _entered.append([p, s])
var _on_dug := func(c: Vector2i, b: StringName, p: int) -> void: _dug.append([c, b, p])


func before_test() -> void:
	Players.reset()
	Inventory.clear()
	_entered.clear()
	_dug.clear()
	Events.entered_scene.connect(_on_entered)
	Events.tile_dug.connect(_on_dug)


func after_test() -> void:
	if is_instance_valid(_proto):
		_proto.free()
	Events.entered_scene.disconnect(_on_entered)
	Events.tile_dug.disconnect(_on_dug)
	Players.reset()
	Inventory.clear()
	Audio.synth_missing = true


func _make() -> FoundationProto:
	_proto = PROTO.instantiate()
	_proto.verbose = false
	get_tree().root.add_child(_proto)
	return _proto


func _join(player: int, intent: Dictionary = IDLE) -> ProtoPlayer:
	Players.join_virtual(player)
	var p: ProtoPlayer = _proto.players[player]
	p.intent_source = func() -> Dictionary: return intent
	return p


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Physics frames until cond() holds (or max_frames); returns how many it took.
func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


# --- boot --------------------------------------------------------------------------------------

func test_scene_runs_and_hosts_both_scenes() -> void:
	_make()
	await _physics(30)
	assert_object(_proto.director.scene_root(FoundationProto.HILLVILLE)).is_not_null()
	assert_object(_proto.director.scene_root(FoundationProto.UNDERGROUND)).is_not_null()
	_join(Players.P1)
	await _physics(5)
	assert_str(String(_proto.director.scene_of(Players.P1))).is_equal("hillville")
	_proto.teleport(Players.P1, FoundationProto.UNDERGROUND, ProtoUnderground.ARRIVAL + Vector2(-40, 0))
	await _physics(5)
	assert_array(_proto.world.loaded_chunks()).is_not_empty()
	assert_bool(_proto.world.is_loaded(Vector2i(100, 11))).is_true()
	assert_object(_proto.players[Players.P1].world).is_same(_proto.world)


# --- elevator ----------------------------------------------------------------------------------

func test_elevator_rides_down_under_a_second_and_rearms_only_after_leaving() -> void:
	_make()
	var p := _join(Players.P1)
	await _physics(2)
	p.position = ProtoHillville.ARRIVAL
	var down := FoundationProto.UNDERGROUND
	var frames := await _until(func() -> bool: return _proto.director.scene_of(Players.P1) == down, 120)
	assert_float(frames / float(Engine.physics_ticks_per_second)).is_less_equal(0.8)
	assert_str(String(_proto.director.scene_of(Players.P1))).is_equal("underground")
	assert_array(_entered).contains([[Players.P1, down]])
	assert_bool(_proto.world.is_loaded(_proto.world.shape.cell_at(p.position))).is_true()
	# Standing in the arrival cage does not ride back.
	await _physics(90)
	assert_str(String(_proto.director.scene_of(Players.P1))).is_equal("underground")
	assert_bool(_proto.elevator.is_riding(Players.P1)).is_false()
	# Out of the zone, then back in: rides up.
	p.position = Vector2(1560, 190)
	await _physics(5)
	p.position = ProtoUnderground.ARRIVAL
	var up := FoundationProto.HILLVILLE
	frames = await _until(func() -> bool: return _proto.director.scene_of(Players.P1) == up, 120)
	assert_float(frames / float(Engine.physics_ticks_per_second)).is_less_equal(0.8)
	assert_array(_entered).contains([[Players.P1, up]])
	assert_object(p.world).is_null()


# --- dig ---------------------------------------------------------------------------------------

func test_dig_right_removes_two_cells_and_fills_the_pile() -> void:
	_make()
	var p := _join(Players.P1, {"move": Vector2.RIGHT, "dig": true, "jump": false})
	_proto.teleport(Players.P1, FoundationProto.UNDERGROUND, Vector2(1640, 190))
	var w := _proto.world
	var feet := Vector2i(104, 11)
	var head := Vector2i(104, 10)
	assert_bool(w.is_solid(feet) and w.is_solid(head)).is_true()
	var before := Inventory.count(&"dirt")
	await _until(func() -> bool: return not w.is_solid(feet) and not w.is_solid(head), 90)
	assert_bool(w.is_solid(feet)).is_false()
	assert_bool(w.is_solid(head)).is_false()
	assert_bool(w.is_solid(Vector2i(104, 12))).is_true()
	var cells := _dug.map(func(d: Array) -> Vector2i: return d[0])
	assert_array(cells).contains([feet, head])
	assert_int(Inventory.count(&"dirt")).is_greater_equal(before + 2)
	assert_int(p.player).is_equal(Players.P1)


# --- set piece ---------------------------------------------------------------------------------

func test_boulder_sleeps_then_falls_when_undercut() -> void:
	_make()
	var b := _proto.underground.boulder
	await _until(func() -> bool: return b.sleeping, 120)
	assert_bool(b.sleeping).is_true()
	var landed: Array = []
	_proto.world.body_landed.connect(func(body: Node2D, _s: float) -> void: landed.append(body))
	var y0 := b.position.y
	_proto.world.dig(Vector2i(109, 10))
	_proto.world.dig(Vector2i(110, 10))
	await _until(func() -> bool: return not landed.is_empty(), 120)
	assert_float(b.position.y).is_greater(y0 + 4.0)
	assert_array(landed).contains([b])


## The pocket is deeper than the tunnel: breached from the side, its top spills along the tunnel as
## a one-high sheet and the part below the tunnel floor stays as a pool a player floats in.
func test_water_pocket_pours_into_the_tunnel_and_a_player_floats() -> void:
	_make()
	await _physics(2)
	var w := _proto.world
	w.water_hz = 0.0                                     # step the water by hand
	var pocket := ProtoGenerator.WATER_POCKET
	var floor_row := ProtoGenerator.LANDING.end.y        # 12: the tunnel floor
	for y in range(pocket.position.y, pocket.end.y):
		for x in range(pocket.position.x, pocket.end.x):
			assert_bool(w.has_water(Vector2i(x, y))).is_true()
	assert_int(pocket.end.y - floor_row).is_greater_equal(3)
	var n := w.water_count()
	for x in range(ProtoGenerator.LANDING.end.x, pocket.position.x):   # dig the tunnel up to the wall
		w.dig(Vector2i(x, floor_row - 2))
		w.dig(Vector2i(x, floor_row - 1))
	for i in 300:
		w.step_water()
	assert_int(w.water_count()).is_equal(n)
	# Poured: a level sheet along the tunnel floor, one cell high.
	var sheet := 0
	for x in range(ProtoGenerator.LANDING.end.x, pocket.position.x):
		if w.has_water(Vector2i(x, floor_row - 1)):
			sheet += 1
		assert_bool(w.has_water(Vector2i(x, floor_row - 2))).is_false()
	assert_int(sheet).is_greater_equal(8)
	var top := 0
	for x in range(pocket.position.x, pocket.end.x):
		if w.has_water(Vector2i(x, pocket.position.y)):
			top += 1
	assert_int(top).is_less_equal(1)                    # the pocket's top row emptied
	# The pool below the tunnel floor is still full.
	for y in range(floor_row, pocket.end.y):
		for x in range(pocket.position.x, pocket.end.x):
			assert_bool(w.has_water(Vector2i(x, y))).is_true()
	# A player dropped into the pool floats: wet, off the floor, never down at the bottom.
	var p := _join(Players.P1)
	var cs := float(w.shape.cell_size)
	_proto.teleport(Players.P1, FoundationProto.UNDERGROUND, Vector2((pocket.position.x + 4.5) * cs, (floor_row - 1) * cs))
	var wet := 0
	var grounded := 0
	var deepest := 0.0
	for i in 150:
		await get_tree().physics_frame
		if i >= 30:                                      # it bobs at the surface, never stands
			wet += 1 if p.in_water() else 0
			grounded += 1 if p.is_on_floor() else 0
			deepest = maxf(deepest, p.position.y)
	assert_int(grounded).is_equal(0)
	assert_int(wet).is_greater_equal(40)
	assert_float(deepest).is_less(pocket.end.y * cs - cs)


# --- split -------------------------------------------------------------------------------------

func test_solo_is_one_view_and_up_and_down_splits() -> void:
	_make()
	await _physics(2)
	assert_bool(_proto.director.is_split()).is_false()   # nobody: the anchor holds the view
	_join(Players.P1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_proto.director.is_split()).is_false()
	_proto.teleport(Players.P1, FoundationProto.UNDERGROUND, ProtoUnderground.ARRIVAL + Vector2(-40, 0))
	await get_tree().process_frame
	assert_bool(_proto.director.is_split()).is_false()   # alone underground: still full screen
	_join(Players.P2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_proto.director.is_split()).is_true()    # one up, one down
	_proto.teleport(Players.P2, FoundationProto.UNDERGROUND, ProtoUnderground.ARRIVAL + Vector2(-24, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_proto.director.is_split()).is_false()   # both down, close: joined


# --- boot flags and audio ----------------------------------------------------------------------

func test_proto_mode_flags() -> void:
	assert_str(String(MAIN.proto_mode(PackedStringArray([])))).is_equal("")
	assert_str(String(MAIN.proto_mode(PackedStringArray(["--demo"])))).is_equal("")
	assert_str(String(MAIN.proto_mode(PackedStringArray(["--proto"])))).is_equal("proto")
	assert_str(String(MAIN.proto_mode(PackedStringArray(["--", "--proto-auto"])))).is_equal("auto")
	assert_str(String(MAIN.proto_mode(PackedStringArray(["--proto", "--proto-auto"])))).is_equal("auto")


func test_audio_synth_beep_for_missing_cues() -> void:
	var cue := "proto_test_missing_cue"
	assert_bool(Audio.has_cue(cue)).is_false()
	Audio.synth_missing = true
	var s := Audio.stream_for(cue)
	assert_object(s).is_instanceof(AudioStreamWAV)
	assert_float(s.get_length()).is_between(0.05, 0.15)
	assert_object(Audio.stream_for(cue)).is_same(s)
	assert_object(Audio.stream_for("dig_" + cue)).is_not_same(s)
	Audio.play(cue)
	Audio.synth_missing = false
	assert_object(Audio.stream_for(cue)).is_null()
	Audio.play(cue)
