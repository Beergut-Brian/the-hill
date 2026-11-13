## PT1112-1 (Kaden 2026-11-12, second report of PT10-6): "The character jumps around when going left
## and right." The real game scene runs with input for N frames and every check is in SCREEN px: the
## view's canvas transform applied to where the body is actually painted (HillPlayer.body_box), the
## camera and a parked vehicle. PT10-6's tests measured the player's world x, which never moved;
## the painted body did (SpriteArt mirrored a flipped frame one frame width off the pivot).
class_name TestTurnJump
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SUITE := "turn_jump"
## A turn in place may move the body, the camera or the scene at most this much on screen.
const STILL_PX := 1.0

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


func _frame() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await _frame()


## The canvas -> screen transform of the view that shows player `viewer`.
func _xf(viewer: int) -> Transform2D:
	return _game.director.camera_of(viewer).get_viewport().get_canvas_transform()


## Where p's body is painted on viewer's screen (opaque pixels, screen px).
func _body(p: int, viewer := -1) -> Rect2:
	var n := _game.player_node(p)
	return _xf(p if viewer < 0 else viewer) * n.global_transform * n.body_box()


func _loader_x(viewer: int) -> float:
	var v: Node2D = _game.vehicles.get(HillGame.LOADER)
	return (_xf(viewer) * v.global_position).x


## Up top on flat ground left of the parked Loader.
func _yard(p: int, dx: float) -> HillPlayer:
	var lx: float = _game.loader_position().pos.x
	_game.place_player(p, HillGame.HILLVILLE, Vector2(lx - 140.0 + dx, 0))
	var n := _game.player_node(p)
	n.velocity = Vector2.ZERO
	n.facing = 1
	return n


## Underground in a Topsoil room, feet on its floor at column `at`.
func _room(p: int, room: Rect2i, at: int) -> HillPlayer:
	var w := _game.underground.world
	var dirt := w.get_tile(Vector2i(room.position.x, room.end.y + 2))
	for y in range(room.position.y - 4, room.end.y + 3):
		for x in range(room.position.x - 6, room.end.x + 6):
			w.set_tile(Vector2i(x, y), dirt if not room.has_point(Vector2i(x, y)) else 0)
	_game.place_player(p, HillGame.UNDERGROUND, Vector2((at + 0.5) * 16.0, room.end.y * 16.0 - 1.0))
	var n := _game.player_node(p)
	n.velocity = Vector2.ZERO
	n.facing = 1
	return n


class Spread:
	var lo := {}
	var hi := {}

	func add(key: String, v: float) -> void:
		lo[key] = minf(lo.get(key, INF), v)
		hi[key] = maxf(hi.get(key, -INF), v)

	func of(key: String) -> float:
		return float(hi[key]) - float(lo[key])


## Records after the director and CameraLead have placed the cameras (process_priority 100), so
## every sample is what that frame's screen shows.
class Probe:
	extends Node
	var fn: Callable

	func _ready() -> void:
		process_priority = 100

	func _process(_d: float) -> void:
		fn.call()


func _probe(fn: Callable) -> Probe:
	var pr := Probe.new()
	pr.fn = fn
	_game.add_child(pr)
	return pr


## Drives p's stick by physics tick (gdUnit runs a varying number of ticks per awaited frame):
## `script` is [[ticks, stick x], ...]. Returns once every tick has been fed.
func _drive(p: int, script: Array) -> void:
	var st := {"tick": 0}
	var plan: Array[float] = []
	for step: Array in script:
		for i in int(step[0]):
			plan.append(float(step[1]))
	var it := _idle()
	_game.player_node(p).intent_source = func() -> Dictionary:
		var k: int = st.tick
		st.tick = k + 1
		it.move = Vector2(plan[k] if k < plan.size() else 0.0, 0)
		return it
	while int(st.tick) < plan.size() + 10:
		await get_tree().physics_frame
	await _frames(2)


## Kaden's input: n short taps, left first (5 ticks of full stick = 0.083 s, then 25 idle).
func _taps(n: int) -> Array:
	var out := []
	for k in n:
		out.append([5, -1.0 if k % 2 == 0 else 1.0])
		out.append([25, 0.0])
	return out


func _assert_still(s: Spread, keys: Array) -> void:
	for key: String in keys:
		assert_float(s.of(key)).override_failure_message(
				"%s moved %.2f px on screen while turning in place (%.2f .. %.2f)" % [key, s.of(key), s.lo[key], s.hi[key]]).is_less_equal(STILL_PX)


# --- turning in place -----------------------------------------------------------------------------

## The facings p went through, without repeats.
func _facings(p: int, into: Array) -> void:
	var f := _game.player_node(p).facing
	if into.is_empty() or into.back() != f:
		into.append(f)


func test_turn_in_place_up_top_moves_nothing_on_screen() -> void:
	_make()
	_join(P1, _idle())
	_yard(P1, 0)
	await _frames(10)
	var s := Spread.new()
	var seen := []
	_probe(func() -> void:
		s.add("body", _body(P1).get_center().x)
		s.add("camera", _game.director.camera_of(P1).get_screen_center_position().x * 2.0)
		s.add("loader", _loader_x(P1))
		_facings(P1, seen))
	await _drive(P1, _taps(6))
	assert_array(seen).is_equal([1, -1, 1, -1, 1, -1, 1])
	_assert_still(s, ["body", "camera", "loader"])
	assert_float(_game.player_node(P1).global_position.x).is_equal_approx(_game.loader_position().pos.x - 140.0, 0.01)


func test_turn_in_place_underground_moves_nothing_on_screen() -> void:
	_make()
	_join(P1, _idle())
	_room(P1, Rect2i(60, 14, 8, 2), 63)
	await _frames(10)
	var s := Spread.new()
	var seen := []
	_probe(func() -> void:
		s.add("body", _body(P1).get_center().x)
		s.add("camera", _game.director.camera_of(P1).get_screen_center_position().x * 2.0)
		_facings(P1, seen))
	await _drive(P1, _taps(6))
	assert_array(seen).is_equal([1, -1, 1, -1, 1, -1, 1])
	_assert_still(s, ["body", "camera"])


func test_holding_the_stick_after_the_turn_walks() -> void:
	_make()
	var n := _join(P1, _idle())
	_yard(P1, 0)
	await _frames(10)
	var x0 := n.global_position.x
	await _drive(P1, [[30, -1.0]])
	# 0.1 s turning in place, then walking: 24 ticks of 200 px/s is 80 px.
	assert_int(n.facing).is_equal(-1)
	assert_float(x0 - n.global_position.x).is_between(70.0, 90.0)


func test_the_backpack_stays_on_the_back_after_a_turn() -> void:
	_make()
	var n := _join(P1, _idle())
	_yard(P1, 0)
	await _frames(4)
	for want: int in [1, -1]:
		n.facing = want
		await _frames(2)
		var body := n.body_box()
		var bag := n.bag_rect()
		# Behind the body (the side it is not facing) and touching its back edge, never in front of
		# it or floating free (the "small brown box" beside the character in Kaden's video).
		var back_x := body.position.x if want > 0 else body.end.x
		assert_bool(bag.get_center().x * want < 0.0).is_true()
		assert_float(absf(bag.get_center().x - back_x)).is_less_equal(6.0)


# --- walking ----------------------------------------------------------------------------------------

func test_walk_and_reverse_follows_smoothly_never_a_step() -> void:
	_make()
	_join(P1, _idle())
	_yard(P1, 0)
	await _frames(10)
	var cam := _game.director.camera_of(P1)
	var st := {"cam": cam.get_screen_center_position().x, "tick": Engine.get_physics_frames(),
			"body0": _body(P1).get_center().x, "step": 0.0, "body": 0.0}
	_probe(func() -> void:
		var c := cam.get_screen_center_position().x
		var ticks := maxi(1, Engine.get_physics_frames() - int(st.tick))
		st.step = maxf(float(st.step), absf(c - float(st.cam)) / ticks)
		st.cam = c
		st.tick = Engine.get_physics_frames()
		st.body = maxf(float(st.body), absf(_body(P1).get_center().x - float(st.body0))))
	await _drive(P1, [[40, -1.0], [40, 1.0], [40, -1.0], [40, 1.0]])
	# A tick of walking is 200 / 60 = 3.3 world px: the camera never moves more than that (+ its
	# pixel rounding) per tick, and the body stays on its spot on screen through every reversal
	# (walk frames differ in width by a pixel or two).
	assert_float(float(st.step)).is_less_equal(HillPlayer.WALK / 60.0 + 1.0)
	assert_float(float(st.body)).is_less_equal(3.0)


# --- two players ------------------------------------------------------------------------------------

func test_two_players_one_screen_turning_moves_nothing() -> void:
	_make()
	_join(P1, _idle())
	_join(P2, _idle())
	await _frames(30)   # P2 tumbles out of the Loader
	_yard(P1, 0)
	_yard(P2, 60)
	await _frames(30)
	assert_bool(_game.director.is_split()).is_false()
	var s := Spread.new()
	_probe(func() -> void:
		s.add("P1 body", _body(P1, P1).get_center().x)
		s.add("P2 body", _body(P2, P1).get_center().x)
		s.add("camera", _game.director.camera_of(P1).get_screen_center_position().x * 2.0)
		s.add("loader", _loader_x(P1)))
	await _drive(P1, _taps(6))
	assert_int(_game.player_node(P1).facing).is_equal(1)
	_assert_still(s, ["P1 body", "P2 body", "camera", "loader"])


func test_two_players_split_turning_moves_nothing() -> void:
	_make()
	_join(P1, _idle())
	_join(P2, _idle())
	await _frames(30)
	_yard(P1, 0)
	_room(P2, Rect2i(60, 14, 8, 2), 63)
	await _frames(40)   # the divider slides in
	assert_bool(_game.director.is_split()).is_true()
	assert_float(_game.director.split_amount).is_equal(1.0)
	var s := Spread.new()
	_probe(func() -> void:
		s.add("P1 body", _body(P1).get_center().x)
		s.add("P1 camera", _game.director.camera_of(P1).get_screen_center_position().x * 2.0)
		s.add("P2 body", _body(P2).get_center().x)
		s.add("P2 camera", _game.director.camera_of(P2).get_screen_center_position().x * 2.0))
	await _drive(P1, _taps(4))
	await _drive(P2, _taps(4))
	_assert_still(s, ["P1 body", "P1 camera", "P2 body", "P2 camera"])


# --- the mirror itself --------------------------------------------------------------------------------

func test_flipped_frame_is_mirrored_about_the_pivot_column() -> void:
	var fs := Vector2(32, 32)
	var pv := Vector2(16, 32)
	var right := SpriteArt.painted_rect(fs, pv, Vector2(100, 50), false)
	var left := SpriteArt.painted_rect(fs, pv, Vector2(100, 50), true)
	# The "line" mirror (even-width bodies) maps the pivot line onto itself.
	var line := SpriteArt.painted_rect(fs, pv, Vector2(100, 50), true, 0.0)
	assert_float(right.get_center().x + line.get_center().x).is_equal(200.0)
	# The pivot pixel (column pv.x, canvas [100, 101)) is the same pixel both ways; the frames are
	# mirror images about its centre (100.5).
	assert_float(right.position.x + pv.x).is_equal(100.0)
	assert_float(left.position.x + (fs.x - 1.0 - pv.x)).is_equal(100.0)
	assert_float(right.get_center().x + left.get_center().x).is_equal(201.0)
	assert_float(left.size.x).is_equal(fs.x)


func test_every_player_sheet_turns_in_place() -> void:
	var files: Array[String] = ["characters/jeff.png", "characters/chuck.png"]
	# A roster character with only a pixel form (Kaden's TV had one): the runtime-built sheet.
	var tex: Texture2D = load("res://assets/characters/jeff/pixel.png")
	files.append(CharacterSheet.register("turn_jump_built", tex.get_image()))
	for file in files:
		var fs := SpriteArt.frame_size(file)
		for anim in ["idle", "walk", "dig_side", "air"]:
			var r := SpriteArt.row(file, anim)
			if r.is_empty():
				continue
			var a := SpriteArt.body_box(file, 0, int(r.row), Vector2.ZERO, false)
			var b := SpriteArt.body_box(file, 0, int(r.row), Vector2.ZERO, true)
			var moved := absf(a.get_center().x - b.get_center().x)
			# Never the old frame-width jump (the turn only swaps which side the shovel is on).
			assert_float(moved).override_failure_message("%s %s moves %.1f px when it turns" % [file, anim, moved]
					).is_less(fs.x * 0.25)
	# The hand-made sheets are drawn centred on the pivot column: they turn exactly in place.
	for file in ["characters/jeff.png", "characters/chuck.png"]:
		var r := SpriteArt.row(file, "idle")
		var a := SpriteArt.body_box(file, 0, int(r.row), Vector2.ZERO, false)
		var b := SpriteArt.body_box(file, 0, int(r.row), Vector2.ZERO, true)
		assert_float(absf(a.get_center().x - b.get_center().x)).is_less_equal(0.5)
	CharacterSheet.clear()


## The built sheet's body sits on the pivot column (odd width) or the pivot line (even width) and
## the sheet says which, so a flip mirrors it onto itself either way.
func test_built_sheet_body_turns_exactly_in_place() -> void:
	for w in [9, 10, 13, 14]:
		var img := Image.create_empty(w, 20, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1))
		var sheet := CharacterSheet.build(img)
		var file := CharacterSheet.register("turn_jump_w%d" % w, img)
		var lo := 999
		var hi := -1
		for x in CharacterSheet.FRAME.x:
			for y in CharacterSheet.FRAME.y:
				if sheet.get_pixel(x, y).is_equal_approx(Color(1, 0, 1)):
					lo = mini(lo, x)
					hi = maxi(hi, x)
		# Frame columns lo..hi; mirrored, column c lands at (fs - 1 - c) of the flipped paint.
		var fs := SpriteArt.frame_size(file)
		var pv := SpriteArt.pivot(file)
		var right := SpriteArt.painted_rect(fs, pv, Vector2.ZERO, false, SpriteArt.flip_shift(file))
		var left := SpriteArt.painted_rect(fs, pv, Vector2.ZERO, true, SpriteArt.flip_shift(file))
		var c_right := right.position.x + (lo + hi + 1) * 0.5
		var c_left := left.position.x + fs.x - (lo + hi + 1) * 0.5
		assert_float(c_left).override_failure_message("width %d: body centre %.1f facing right, %.1f facing left" % [w, c_right, c_left]
				).is_equal(c_right)
	CharacterSheet.clear()
