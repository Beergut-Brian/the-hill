## A line of hint text with controller glyphs: "[a] Select   [b] Back". See UiStyle.draw_rich.
## strip = true: on the dark slanted Showtime strip (runs off the right edge), cream text.
class_name HintLine
extends Control

@export var text := "":
	set(v):
		text = v
		queue_redraw()
@export var role := UiStyle.Role.HINT
@export_enum("Left", "Center", "Right") var align := 1
@export var color := UiStyle.TEXT_DIM
@export var strip := false:
	set(v):
		strip = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if strip:
		UiStyle.para(self, Rect2(0, 0, size.x + 200.0, size.y), UiStyle.INK_SHOW)
		var right := size.x - (UiStyle.SAFE.x - (get_viewport_rect().size.x - get_global_rect().end.x))
		UiStyle.draw_rich(self, Vector2(right, size.y * 0.5), text, role, UiStyle.CREAM, 2, 30)
		return
	var x: float = [0.0, size.x * 0.5, size.x][align]
	UiStyle.draw_rich(self, Vector2(x, size.y * 0.5), text, role, color, align)
