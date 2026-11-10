## The menu's side of the Showtime stage: a dark wedge in the skin's deep colour with two racing
## stripes (accent and cream) along its leaning edge. side RIGHT: the lobby and settings; LEFT: the
## pause menu, where the stripe takes the colour of whoever paused (stripe_color).
## `edge` is where the wedge's edge meets the top of the screen; tween it to grow or slide the wedge.
extends Control

enum Side { LEFT, RIGHT }

@export var side := Side.RIGHT
@export var edge := 1206.0:
	set(v):
		edge = v
		queue_redraw()
@export_range(0.0, 1.0) var opacity := 0.92
## Empty (alpha 0): the skin's accent.
var stripe_color := Color(0, 0, 0, 0):
	set(v):
		stripe_color = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	add_to_group("openjar_skinned")
	resized.connect(queue_redraw)


func apply_skin() -> void:
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var w := size.x
	var lean := h * UiStyle.LEAN
	var deep := Color(UiStyle.deep(), opacity)
	var stripe := stripe_color if stripe_color.a > 0.0 else UiStyle.accent
	if side == Side.RIGHT:
		_quad(edge, w + 10.0, deep, lean)
		_quad(edge - 30.0, edge, stripe, lean)
		_quad(edge - 60.0, edge - 44.0, UiStyle.CREAM, lean)
	else:
		_quad(-10.0, edge, deep, lean)
		_quad(edge, edge + 34.0, stripe, lean)
		_quad(edge + 48.0, edge + 64.0, UiStyle.CREAM, lean)


## A leaning band between x0 and x1 at the top of the screen.
func _quad(x0: float, x1: float, col: Color, lean: float) -> void:
	var h := size.y
	draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1 - lean, h), Vector2(x0 - lean, h)]), col)
