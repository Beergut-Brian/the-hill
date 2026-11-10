## ScreenDirector (addons/openjar/split_screen): the split rule table, the slide, scene hosting,
## per-scene physics, and input forwarding into hosted scenes.
class_name TestSplit
extends GdUnitTestSuite

const SCREEN := Vector2(960, 540)   # one screen in world px (1920x1080 at zoom 2)

var _dir: ScreenDirector
var _changes: Array = []
var _entered: Array = []


func before_test() -> void:
	_changes.clear()
	_entered.clear()


func after_test() -> void:
	if is_instance_valid(_dir):
		_dir.free()


# --- wants_split: GAME.md "Camera and controls" table -------------------------------------

func test_table_both_up_top_close_is_one_camera() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(100, 0), SCREEN, 2)).is_false()
	assert_bool(ScreenDirector.wants_split(true, true, Vector2(100, 20), SCREEN, 2)).is_false()


func test_table_both_up_top_far_is_split() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(900, 0), SCREEN, 2)).is_true()
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(-900, 0), SCREEN, 2)).is_true()


func test_table_both_underground_close_is_one_camera() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(-50, 120), SCREEN, 2)).is_false()


func test_table_both_underground_far_is_split() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(-1000, 30), SCREEN, 2)).is_true()


func test_table_one_up_one_down_is_split_even_at_same_coordinates() -> void:
	assert_bool(ScreenDirector.wants_split(false, false, Vector2.ZERO, SCREEN, 2)).is_true()
	assert_bool(ScreenDirector.wants_split(true, false, Vector2.ZERO, SCREEN, 2)).is_true()


func test_table_solo_is_full_screen_always() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(5000, 5000), SCREEN, 1)).is_false()
	assert_bool(ScreenDirector.wants_split(true, false, Vector2(5000, 0), SCREEN, 1)).is_false()
	assert_bool(ScreenDirector.wants_split(true, false, Vector2.ZERO, SCREEN, 0)).is_false()


func test_hysteresis_between_join_and_split_keeps_state() -> void:
	var between := Vector2(SCREEN.x * 0.7, 0)
	assert_bool(ScreenDirector.wants_split(false, true, between, SCREEN, 2)).is_false()
	assert_bool(ScreenDirector.wants_split(true, true, between, SCREEN, 2)).is_true()
	var between_y := Vector2(0, SCREEN.y * 0.7)
	assert_bool(ScreenDirector.wants_split(false, true, between_y, SCREEN, 2)).is_false()
	assert_bool(ScreenDirector.wants_split(true, true, between_y, SCREEN, 2)).is_true()
	# Edges: exactly join_at joins, just past split_at splits.
	assert_bool(ScreenDirector.wants_split(true, true, Vector2(SCREEN.x * 0.6, 0), SCREEN, 2)).is_false()
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(SCREEN.x * 0.81, 0), SCREEN, 2)).is_true()


func test_vertical_distance_alone_splits() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(0, SCREEN.y * 0.9), SCREEN, 2)).is_true()
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(0, -SCREEN.y * 0.9), SCREEN, 2)).is_true()


func test_custom_thresholds() -> void:
	assert_bool(ScreenDirector.wants_split(false, true, Vector2(SCREEN.x * 0.5, 0), SCREEN, 2, 0.2, 0.4)).is_true()


# --- integration ---------------------------------------------------------------------------

func _scene(scene_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = scene_name
	var players := Node2D.new()
	players.name = "Players"
	root.add_child(players)
	return root


func _make(two_players := true) -> Array[Node2D]:
	_dir = ScreenDirector.new()
	get_tree().root.add_child(_dir)
	_dir.split_changed.connect(func(s: bool) -> void: _changes.append(s))
	_dir.entered_scene.connect(func(p: int, s: StringName) -> void: _entered.append([p, s]))
	_dir.add_scene(&"top", _scene("Top"))
	_dir.add_scene(&"mine", _scene("Mine"))
	var a := Node2D.new()
	var b := Node2D.new()
	a.position = Vector2(100, 100)
	b.position = Vector2(140, 100)
	_dir.add_player(0, a, &"top")
	if two_players:
		_dir.add_player(1, b, &"top")
	else:
		b.free()
		return [a] as Array[Node2D]
	return [a, b] as Array[Node2D]


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _screen_world() -> Vector2:
	return _dir.size / _dir.zoom


func test_close_players_share_one_view() -> void:
	var p := _make()
	await _frames()
	await _frames()
	assert_bool(_dir.is_split()).is_false()
	assert_float(_dir.split_amount).is_equal(0.0)
	assert_that(p[0].get_parent()).is_same(_dir.scene_root(&"top").get_node("Players"))
	assert_that(_dir.view_rect_of(0)).is_equal(_dir.get_global_rect())
	assert_that(_dir.view_rect_of(1)).is_equal(_dir.get_global_rect())
	# The one camera frames the midpoint.
	assert_that(_dir.camera_of(0).position).is_equal(Vector2(120, 100))
	assert_array(_changes).is_empty()


func test_far_splits_slides_and_joins() -> void:
	var p := _make()
	await _frames()
	p[1].global_position = p[0].global_position + Vector2(_screen_world().x * 0.95, 0)
	await _frames()
	assert_bool(_dir.is_split()).is_true()
	assert_array(_changes).is_equal([true])
	await await_millis(150)
	assert_float(_dir.split_amount).is_greater(0.0).is_less(1.0)
	await await_millis(250)
	assert_float(_dir.split_amount).is_equal(1.0)
	assert_array(_changes).is_equal([true])
	var full := _dir.get_global_rect()
	var half := full.size.x * 0.5
	assert_that(_dir.view_rect_of(0)).is_equal(Rect2(full.position, Vector2(half, full.size.y)))
	assert_that(_dir.view_rect_of(1)).is_equal(Rect2(full.position + Vector2(half, 0), Vector2(half, full.size.y)))
	assert_that(_dir.camera_of(0).position).is_equal(p[0].global_position.round())
	assert_that(_dir.camera_of(1).position).is_equal(p[1].global_position.round())
	# Back in range: joins.
	p[1].global_position = p[0].global_position + Vector2(30, 0)
	await _frames()
	assert_bool(_dir.is_split()).is_false()
	assert_array(_changes).is_equal([true, false])
	await await_millis(400)
	assert_float(_dir.split_amount).is_equal(0.0)
	assert_that(_dir.view_rect_of(1)).is_equal(full)


func test_reverse_mid_tween_does_not_pop() -> void:
	var p := _make()
	await _frames()
	p[1].global_position = p[0].global_position + Vector2(_screen_world().x * 0.95, 0)
	await await_millis(150)
	var mid := _dir.split_amount
	p[1].global_position = p[0].global_position + Vector2(30, 0)
	await _frames()
	assert_float(_dir.split_amount).is_greater(0.0).is_less_equal(mid)
	await await_millis(400)
	assert_float(_dir.split_amount).is_equal(0.0)


func test_move_player_to_other_scene_splits_and_rehomes() -> void:
	var p := _make()
	await _frames()
	_dir.move_player(1, &"mine", Vector2(100, 100))
	assert_that(_dir.scene_of(1)).is_equal(&"mine")
	assert_that(_dir.scene_of(0)).is_equal(&"top")
	assert_array(_entered).is_equal([[1, &"mine"]])
	assert_that(p[1].get_parent()).is_same(_dir.scene_root(&"mine").get_node("Players"))
	assert_that(p[1].global_position).is_equal(Vector2(100, 100))
	var top_world := _dir.scene_root(&"top").get_viewport().world_2d
	var mine_world := _dir.scene_root(&"mine").get_viewport().world_2d
	assert_that(_dir.camera_of(1).get_viewport().world_2d).is_same(mine_world)
	assert_that(_dir.camera_of(0).get_viewport().world_2d).is_same(top_world)
	await _frames()
	assert_bool(_dir.is_split()).is_true()
	assert_array(_changes).is_equal([true])
	await await_millis(400)
	assert_float(_dir.split_amount).is_equal(1.0)
	# Back up, close: joins.
	_dir.move_player(1, &"top", p[0].global_position + Vector2(10, 0))
	await _frames()
	assert_bool(_dir.is_split()).is_false()
	assert_that(_dir.camera_of(1).get_viewport().world_2d).is_same(top_world)


func test_solo_never_splits() -> void:
	var p := _make(false)
	await _frames()
	p[0].global_position = Vector2(99999, -99999)
	_dir.move_player(0, &"mine", Vector2(5000, 0))
	await await_millis(100)
	assert_bool(_dir.is_split()).is_false()
	assert_float(_dir.split_amount).is_equal(0.0)
	assert_array(_changes).is_empty()
	assert_that(_dir.view_rect_of(0)).is_equal(_dir.get_global_rect())


func test_solo_player_one_gets_full_screen() -> void:
	_make(false)
	_dir.remove_player(0)
	var b := Node2D.new()
	_dir.add_player(1, b, &"mine")
	await _frames()
	assert_bool(_dir.is_split()).is_false()
	assert_that(_dir.view_rect_of(1)).is_equal(_dir.get_global_rect())
	assert_that(_dir.camera_of(1).get_viewport().world_2d).is_same(_dir.scene_root(&"mine").get_viewport().world_2d)
	assert_bool(_dir.camera_of(1).get_viewport().get_parent().visible).is_true()


func test_removing_a_player_while_split_joins() -> void:
	var p := _make()
	_dir.move_player(1, &"mine", Vector2.ZERO)
	await await_millis(400)
	assert_float(_dir.split_amount).is_equal(1.0)
	_dir.remove_player(1)
	await _frames()
	assert_bool(_dir.is_split()).is_false()
	await await_millis(400)
	assert_float(_dir.split_amount).is_equal(0.0)
	assert_array(_changes).is_equal([true, false])
	p[1].free()


# --- hosting -------------------------------------------------------------------------------

func _faller() -> RigidBody2D:
	var body := RigidBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4
	shape.shape = circle
	body.add_child(shape)
	return body


func test_every_scene_ticks_seen_or_not() -> void:
	var p := _make()
	var unseen := _scene("Unseen")
	_dir.add_scene(&"unseen", unseen)
	var bodies: Array[RigidBody2D] = []
	for id: StringName in [&"top", &"mine", &"unseen"]:
		var body := _faller()
		_dir.scene_root(id).add_child(body)
		bodies.append(body)
	# Player 0 in top, player 1 in mine; nobody looks at "unseen".
	_dir.move_player(1, &"mine", Vector2.ZERO)
	var frames := Engine.get_physics_frames()
	await await_millis(300)
	assert_int(Engine.get_physics_frames() - frames).is_greater(3)
	for body in bodies:
		assert_float(body.position.y).is_greater(5.0)
	assert_that(p[0].get_viewport()).is_not_same(p[1].get_viewport())


func test_scenes_have_separate_physics_spaces() -> void:
	_make()
	var a := _dir.scene_root(&"top") as Node2D
	var b := _dir.scene_root(&"mine") as Node2D
	assert_that(a.get_world_2d().space).is_not_equal(b.get_world_2d().space)
	assert_that(a.get_world_2d()).is_not_same(b.get_world_2d())
	assert_that(a.get_world_2d()).is_not_same(_dir.get_viewport().world_2d)


func test_input_is_forwarded_into_hosted_scenes() -> void:
	_make()
	var got: Array = []
	var catcher := Node.new()
	var src := GDScript.new()
	src.source_code = "extends Node\nvar got: Array\nfunc _unhandled_input(e: InputEvent) -> void:\n\tgot.append(e)\n"
	src.reload()
	catcher.set_script(src)
	catcher.set("got", got)
	_dir.scene_root(&"mine").add_child(catcher)
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	get_tree().root.push_input(ev)
	assert_int(got.size()).is_equal(1)
	_dir.forward_input = false
	get_tree().root.push_input(ev)
	assert_int(got.size()).is_equal(1)
