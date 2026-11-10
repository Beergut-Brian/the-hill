## The Showtime stage behind the main menu: the game's own world, blurred (MenuSkin.backdrop), under
## a slowly turning sunburst in the skin's colours, and a floor disc for the podiums.
##   SUNBURST  sunburst only (the template's default)
##   SCENE     MenuSkin.backdrop_scene runs live in a SubViewport at 1/4 resolution, blurred
##   TEXTURE   MenuSkin.backdrop_texture, blurred (the still fallback)
##   SCREEN    whatever the game draws behind the menu (its level in main.tscn), blurred
## Rebuilt by apply_skin() when UiStyle.use_skin() is called.
extends Control

const SUNBURST := preload("res://scenes/ui/kit/sunburst.gdshader")
const SOFT_BLUR := preload("res://scenes/ui/kit/soft_blur.gdshader")
const SCREEN_BLUR := preload("res://scenes/ui/kit/blur_dim.gdshader")
## The world renders at 1/SHRINK of the screen: cheap, and soft before the blur even starts.
const SHRINK := 4

## Floor disc centre and radii, in 1080p pixels (the podiums stand on it).
@export var floor_centre := Vector2(560, 905)
@export var floor_radius := Vector2(700, 190)

var world: Node   ## the live backdrop_scene instance (SCENE mode), or null
var _layers: Array[Node] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	add_to_group("openjar_skinned")
	resized.connect(queue_redraw)
	apply_skin()


func apply_skin() -> void:
	for n in _layers:
		remove_child(n)
		n.queue_free()
	_layers.clear()
	world = null
	var sk := UiStyle.skin()
	var mode := sk.backdrop
	if mode == MenuSkin.Backdrop.SCENE and sk.backdrop_scene == null:
		mode = MenuSkin.Backdrop.TEXTURE if sk.backdrop_texture else MenuSkin.Backdrop.SUNBURST
	if mode == MenuSkin.Backdrop.TEXTURE and sk.backdrop_texture == null:
		mode = MenuSkin.Backdrop.SUNBURST
	match mode:
		MenuSkin.Backdrop.SCENE:
			var box := SubViewportContainer.new()
			box.stretch = true
			box.stretch_shrink = SHRINK
			box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			box.material = _blur_material(SOFT_BLUR, sk)
			var vp := SubViewport.new()
			vp.own_world_3d = true
			vp.handle_input_locally = false
			vp.gui_disable_input = true
			vp.size_2d_override_stretch = true
			vp.size_2d_override = Vector2i(1920, 1080)
			vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST \
					if sk.pixel_art else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
			box.add_child(vp)
			world = sk.backdrop_scene.instantiate()
			world.process_mode = Node.PROCESS_MODE_PAUSABLE
			vp.add_child(world)
			if world is Node3D and world.find_children("*", "Camera3D", true, false).is_empty():
				var cam := Camera3D.new()
				cam.fov = sk.backdrop_camera_fov
				vp.add_child(cam)
				cam.look_at_from_position(sk.backdrop_camera_position, sk.backdrop_camera_target)
				cam.current = true
			_add_layer(box)
		MenuSkin.Backdrop.TEXTURE:
			var tr := TextureRect.new()
			tr.texture = sk.backdrop_texture
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.material = _blur_material(SOFT_BLUR, sk)
			_add_layer(tr)
		MenuSkin.Backdrop.SCREEN:
			var cr := ColorRect.new()
			var m := ShaderMaterial.new()
			m.shader = SCREEN_BLUR
			m.set_shader_parameter("lod", sk.blur)
			m.set_shader_parameter("tint", Color(sk.deep, 0.2))
			cr.material = m
			_add_layer(cr)
	var sun := ColorRect.new()
	var sm := ShaderMaterial.new()
	sm.shader = SUNBURST
	sm.set_shader_parameter("a", sk.accent2)
	sm.set_shader_parameter("b", sk.accent2.darkened(0.22))
	sm.set_shader_parameter("deep", sk.deep)
	sm.set_shader_parameter("alpha", 1.0 if mode == MenuSkin.Backdrop.SUNBURST else sk.sunburst_over_world)
	sun.material = sm
	_add_layer(sun)
	var fl := Control.new()
	fl.draw.connect(_draw_floor.bind(fl))
	_add_layer(fl)


func _add_layer(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_layers.append(c)


func _blur_material(sh: Shader, sk: MenuSkin) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("radius", sk.blur)
	m.set_shader_parameter("tint", Color(sk.deep, 0.18))
	return m


func _draw_floor(c: Control) -> void:
	var deep := UiStyle.deep()
	_ellipse(c, floor_centre + Vector2(0, 8), floor_radius * 1.05, Color(deep, 0.75))
	_ellipse(c, floor_centre, floor_radius, Color(deep.lightened(0.14), 0.92))


func _ellipse(c: CanvasItem, at: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 64:
		var a := TAU * i / 64.0
		pts.append(at + Vector2(cos(a) * r.x, sin(a) * r.y))
	c.draw_colored_polygon(pts, col)
