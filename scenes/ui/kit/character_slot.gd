## The character on a lobby podium (Spots/P*/Character). Hosts MenuSkin.p1_character / p2_character:
##   Control  fills the slot
##   Node2D   stands with its origin on the podium (feet), scaled by MenuSkin.character_scale
##   Node3D   shown in its own lit SubViewport with a transparent background, turning slowly
## Empty skin: the template's placeholder (lobby_character.gd). The lobby calls set_joined(), wave()
## and cheer() here; they go on to the character if it has them, and the slot itself hops on cheer.
## Not joined: the character is a dark shadow.
class_name CharacterSlot
extends Control

const PLACEHOLDER := preload("res://scenes/ui/lobby_character.gd")

var player := 0
## The hosted character (the scene's root), whatever its type.
var character: Node
var _pivot3d: Node3D
var _joined := false
var _t := 0.0
var _base_y := 0.0
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_base_y = position.y


func host(p: int) -> void:
	player = p
	for c in get_children():
		c.queue_free()
	_pivot3d = null
	var sk := UiStyle.skin()
	var scene := sk.character(p)
	var node: Node = scene.instantiate() if scene else null
	if node == null:
		var ph := Control.new()
		ph.set_script(PLACEHOLDER)
		ph.set("player", p)
		node = ph
	character = node
	if node is Node3D:
		var box := SubViewportContainer.new()
		box.stretch = true
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		box.add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.85, 0.85, 1.0)
		env.environment.ambient_light_energy = 0.55
		vp.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-38, 25 if p == 0 else -25, 0)
		key.light_energy = 1.3
		vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, 160, 0)
		rim.light_energy = 0.6
		rim.light_color = sk.accent2.lightened(0.4)
		vp.add_child(rim)
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0, sk.camera_3d_height + 0.3, sk.camera_3d_distance),
				Vector3(0, sk.camera_3d_height, 0))
		_pivot3d = Node3D.new()
		_pivot3d.rotation_degrees.y = 18.0 if p == 0 else -18.0
		vp.add_child(_pivot3d)
		_pivot3d.add_child(node)
		add_child(box)
	elif node is Node2D:
		var n2 := node as Node2D
		n2.position = Vector2(size.x * 0.5, size.y)
		n2.scale = Vector2.ONE * sk.character_scale
		if sk.pixel_art:
			n2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(n2)
		resized.connect(func() -> void: n2.position = Vector2(size.x * 0.5, size.y))
	else:
		var cn := node as Control
		cn.set_anchors_preset(Control.PRESET_FULL_RECT)
		cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cn)
	set_joined(_joined)


func _process(delta: float) -> void:
	_t += delta
	if _pivot3d:
		# A slow turntable.
		_pivot3d.rotation_degrees.y = (18.0 if player == 0 else -18.0) + sin(_t * 0.6) * 22.0


func set_joined(on: bool) -> void:
	_joined = on
	modulate = Color.WHITE if on else Color(0.16, 0.13, 0.3, 0.85)
	if character and character.has_method("set_joined"):
		character.set_joined(on)


func wave() -> void:
	if character and character.has_method("wave"):
		character.wave()
	_hop(26.0)


## The round is starting: everybody jumps.
func cheer() -> void:
	if character and character.has_method("cheer"):
		character.cheer()
	elif character and character.has_method("wave"):
		character.wave()
	_hop(60.0)


func _hop(h: float) -> void:
	if not is_inside_tree():
		return
	if _tw:
		_tw.kill()
	position.y = _base_y
	_tw = create_tween()
	_tw.tween_property(self, "position:y", _base_y - h, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:y", _base_y, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
