## Dynamic split screen for up to two players across any number of hosted 2D scenes.
## Game-agnostic: no autoloads, nothing outside this folder. See README.md.
##
## Scenes live in hidden "host" SubViewports (own World2D = own canvas + own physics space,
## never rendered, always ticking). Two "view" SubViewports borrow a host's world_2d to show it.
class_name ScreenDirector
extends Control

signal split_changed(is_split: bool)
signal entered_scene(player: int, scene: StringName)

@export var tween_time: float = 0.3
@export var zoom: float = 2.0
@export var join_at: float = 0.6
@export var split_at: float = 0.8
## Push non-pointer input events (keys, joypad, actions) into every host, so `_input` and
## `_unhandled_input` reach nodes inside hosted scenes. Pointer events are never forwarded.
@export var forward_input: bool = true

const DIVIDER_WIDTH := 6.0
const DIVIDER_OUTLINE := 2.0
const DIVIDER_OUTLINE_COLOR := Color(0.07, 0.06, 0.09)
const HOST_SIZE := Vector2i(2, 2)
const MIN_VIEW_PX := 2

var colors: Array[Color] = [Color("3cc24a"), Color("e4393c")]
## 0 = one view .. 1 = fully split. Read-only from outside.
var split_amount: float = 0.0

var _built := false
var _split := false
var _phase := 0.0          # linear 0..1; split_amount = smoothstep(_phase)
var _hosts := {}           # StringName -> SubViewport
var _roots := {}           # StringName -> Node
var _player_node := {}     # int -> Node2D
var _player_scene := {}    # int -> StringName
var _containers: Array[SubViewportContainer] = []
var _views: Array[SubViewport] = []
var _cameras: Array[Camera2D] = []
var _divider: Control
var _rects: Array[Rect2] = [Rect2(), Rect2()]
var _blank_world := World2D.new()
var _last_mid := Vector2.ZERO
var _last_mid_scene: StringName = &""
var _host_layer: Node


# --- public API ----------------------------------------------------------------------------

func add_scene(id: StringName, root: Node) -> void:
	_build()
	assert(not _hosts.has(id), "ScreenDirector: scene %s already added" % id)
	var host := SubViewport.new()
	host.name = "Host_%s" % id
	host.size = HOST_SIZE
	host.world_2d = World2D.new()
	host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.disable_3d = true
	host.audio_listener_enable_2d = false
	_host_layer.add_child(host)
	if root.get_parent():
		root.get_parent().remove_child(root)
	host.add_child(root)
	_hosts[id] = host
	_roots[id] = root


func scene_root(id: StringName) -> Node:
	return _roots.get(id)


func add_player(player: int, node: Node2D, scene: StringName) -> void:
	assert(player == 0 or player == 1, "ScreenDirector: player must be 0 or 1")
	assert(_roots.has(scene), "ScreenDirector: unknown scene %s" % scene)
	var pos := node.global_position if node.is_inside_tree() else node.position
	_player_node[player] = node
	_place(player, scene, pos)


func remove_player(player: int) -> void:
	_player_node.erase(player)
	_player_scene.erase(player)


func move_player(player: int, scene: StringName, position: Vector2) -> void:
	assert(_player_node.has(player), "ScreenDirector: player %d not added" % player)
	assert(_roots.has(scene), "ScreenDirector: unknown scene %s" % scene)
	_place(player, scene, position)
	_update_view_worlds()
	entered_scene.emit(player, scene)


func scene_of(player: int) -> StringName:
	return _player_scene.get(player, &"")


func is_split() -> bool:
	return _split


func camera_of(player: int) -> Camera2D:
	_build()
	return _cameras[_view_index_of(player)]


func view_rect_of(player: int) -> Rect2:
	_build()
	var r := _rects[_view_index_of(player)]
	if split_amount <= 0.0:
		r = Rect2(Vector2.ZERO, size)
	return Rect2(global_position + r.position, r.size)


## The split decision. offset = b - a in world px; screen_world = full screen in world px.
static func wants_split(was_split: bool, same_scene: bool, offset: Vector2, screen_world: Vector2,
		players: int, join_at: float = 0.6, split_at: float = 0.8) -> bool:
	if players <= 1:
		return false
	if not same_scene:
		return true
	var ax := absf(offset.x)
	var ay := absf(offset.y)
	if ax > screen_world.x * split_at or ay > screen_world.y * split_at:
		return true
	if ax <= screen_world.x * join_at and ay <= screen_world.y * join_at:
		return false
	return was_split


# --- lifecycle -----------------------------------------------------------------------------

func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host_layer = Node.new()
	_host_layer.name = "Hosts"
	add_child(_host_layer)
	for i in 2:
		var c := SubViewportContainer.new()
		c.name = "View%d" % i
		c.stretch = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.focus_mode = Control.FOCUS_NONE
		add_child(c)
		var v := SubViewport.new()
		v.name = "Viewport"
		v.size = Vector2i(MIN_VIEW_PX, MIN_VIEW_PX)
		v.world_2d = _blank_world
		v.disable_3d = true
		v.gui_disable_input = true
		v.handle_input_locally = false
		c.add_child(v)
		var cam := Camera2D.new()
		cam.name = "Camera"
		cam.position_smoothing_enabled = false
		cam.zoom = Vector2(zoom, zoom)
		v.add_child(cam)
		_containers.append(c)
		_views.append(v)
		_cameras.append(cam)
	_divider = Control.new()
	_divider.name = "Divider"
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.draw.connect(_draw_divider)
	add_child(_divider)
	if is_inside_tree():
		_copy_render_settings()
	_layout()


func _enter_tree() -> void:
	if _built:
		_copy_render_settings()


func _copy_render_settings() -> void:
	var outer := get_viewport()
	if outer == null:
		return
	for v in _views:
		v.canvas_item_default_texture_filter = outer.canvas_item_default_texture_filter
		v.snap_2d_transforms_to_pixel = outer.snap_2d_transforms_to_pixel
		v.snap_2d_vertices_to_pixel = outer.snap_2d_vertices_to_pixel


func _input(event: InputEvent) -> void:
	if not forward_input or event is InputEventMouse or event is InputEventScreenTouch \
			or event is InputEventScreenDrag or event is InputEventGesture:
		return
	for host: SubViewport in _hosts.values():
		host.push_input(event, true)


func _process(delta: float) -> void:
	_build()
	var count := _player_node.size()
	var same: bool = count == 2 and _player_scene[0] == _player_scene[1]
	var offset := Vector2.ZERO
	if count == 2:
		offset = _pos(1) - _pos(0)
	var want := wants_split(_split, same, offset, _screen_world(), count, join_at, split_at)
	if want != _split:
		_split = want
		split_changed.emit(_split)
	var target := 1.0 if _split else 0.0
	if tween_time <= 0.0:
		_phase = target
	else:
		_phase = move_toward(_phase, target, delta / tween_time)
	split_amount = smoothstep(0.0, 1.0, _phase)
	_update_view_worlds()
	_layout()
	_update_cameras(count, same)


# --- internals -----------------------------------------------------------------------------

func _screen_world() -> Vector2:
	return size / maxf(zoom, 0.001)


func _pos(player: int) -> Vector2:
	return (_player_node[player] as Node2D).global_position


## Which view (0 left, 1 right) shows this player. Player 1 alone uses the right view.
func _view_index_of(player: int) -> int:
	return 1 if player == 1 else 0


func _primary_is_right() -> bool:
	return _player_node.size() == 1 and _player_node.has(1)


func _place(player: int, scene: StringName, pos: Vector2) -> void:
	var node: Node2D = _player_node[player]
	var root: Node = _roots[scene]
	var parent: Node = root.get_node_or_null(^"Players")
	if parent == null:
		parent = root
	if node.get_parent() != parent:
		if node.get_parent():
			node.get_parent().remove_child(node)
		parent.add_child(node)
	node.global_position = pos
	if node is RigidBody2D:
		(node as RigidBody2D).linear_velocity = Vector2.ZERO
		(node as RigidBody2D).angular_velocity = 0.0
	elif "velocity" in node:
		node.set("velocity", Vector2.ZERO)
	node.reset_physics_interpolation()
	_player_scene[player] = scene


func _update_view_worlds() -> void:
	if not _built:
		return
	# Left view shows player 0's scene (or player 1's when they are alone); right view player 1's.
	var left_scene: StringName = scene_of(0)
	if left_scene == &"":
		left_scene = scene_of(1)
	var right_scene: StringName = scene_of(1)
	if right_scene == &"":
		right_scene = left_scene
	_set_world(0, left_scene)
	_set_world(1, right_scene)


func _set_world(view: int, scene: StringName) -> void:
	var w: World2D = _blank_world
	if _hosts.has(scene):
		w = (_hosts[scene] as SubViewport).world_2d
	if _views[view].world_2d != w:
		_views[view].world_2d = w


func _boundary_x() -> float:
	var w := size.x
	if _primary_is_right():
		return lerpf(0.0, w * 0.5, split_amount)
	return lerpf(w, w * 0.5, split_amount)


func _layout() -> void:
	var w := size.x
	var h := size.y
	var bx := roundf(_boundary_x())
	_rects[0] = Rect2(0, 0, bx, h)
	_rects[1] = Rect2(bx, 0, w - bx, h)
	var show := [true, true]
	if split_amount <= 0.0:
		show = [not _primary_is_right(), _primary_is_right()]
		_rects[0] = Rect2(0, 0, w, h)
		_rects[1] = Rect2(0, 0, w, h)
	for i in 2:
		var c := _containers[i]
		var r := _rects[i]
		c.visible = show[i]
		_views[i].render_target_update_mode = \
				SubViewport.UPDATE_ALWAYS if show[i] else SubViewport.UPDATE_DISABLED
		_views[i].audio_listener_enable_2d = show[i]
		c.position = r.position
		c.size = Vector2(maxf(r.size.x, MIN_VIEW_PX), maxf(r.size.y, MIN_VIEW_PX))
	_divider.visible = split_amount > 0.0
	_divider.position = Vector2(bx - DIVIDER_WIDTH * 0.5 - DIVIDER_OUTLINE, 0)
	_divider.size = Vector2(DIVIDER_WIDTH + DIVIDER_OUTLINE * 2.0, h)
	_divider.modulate.a = split_amount
	_divider.queue_redraw()


func _draw_divider() -> void:
	var h := _divider.size.y
	var o := DIVIDER_OUTLINE
	var half := DIVIDER_WIDTH * 0.5
	_divider.draw_rect(Rect2(0, 0, DIVIDER_WIDTH + o * 2.0, h), DIVIDER_OUTLINE_COLOR)
	_divider.draw_rect(Rect2(o, 0, half, h), colors[0])
	_divider.draw_rect(Rect2(o + half, 0, half, h), colors[1])


func _update_cameras(count: int, same: bool) -> void:
	var targets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var scenes: Array[StringName] = [scene_of(0), scene_of(1)]
	if count == 2 and same:
		var mid := (_pos(0) + _pos(1)) * 0.5
		_last_mid = mid
		_last_mid_scene = scenes[0]
		for i in 2:
			targets[i] = mid.lerp(_pos(i), split_amount)
	elif count == 2:
		# Different scenes: each camera on its own player; the one that stayed eases off the
		# last shared midpoint so the full-screen view does not pop as the divider slides in.
		for i in 2:
			targets[i] = _pos(i)
			if scenes[i] == _last_mid_scene:
				targets[i] = _last_mid.lerp(_pos(i), split_amount)
	elif count == 1:
		var p: int = _player_node.keys()[0]
		targets[0] = _pos(p)
		targets[1] = _pos(p)
	else:
		return
	for i in 2:
		var cam := _cameras[i]
		cam.zoom = Vector2(zoom, zoom)
		cam.position = targets[i].round()
		var scene := scenes[i]
		if count == 1 or scene == &"":
			scene = scene_of(_player_node.keys()[0])
		_apply_limits(cam, _roots.get(scene))


func _apply_limits(cam: Camera2D, root: Node) -> void:
	if root != null and root.has_method("get_camera_limits"):
		var r: Rect2 = root.call("get_camera_limits")
		cam.limit_enabled = true
		cam.limit_left = int(r.position.x)
		cam.limit_top = int(r.position.y)
		cam.limit_right = int(r.end.x)
		cam.limit_bottom = int(r.end.y)
	else:
		cam.limit_enabled = false
