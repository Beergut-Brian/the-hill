## PT-1119-1: the pause menu's help, always shown: "hold Y: rope up" (the Y glyph in a hold ring,
## the crew's rope with an up arrow, and the words for the grown-up). PauseMenu adds it to its card.
class_name RopeHelp
extends Control



func _ready() -> void:
	name = "RopeHelp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(560, 70)


func _draw() -> void:
	var h := 46.0
	var c := Vector2(h * 0.5 + 6.0, size.y * 0.5)
	draw_circle(c, h * 0.5 + 7.0, Color(1.0, 0.82, 0.25, 0.9), false, 4.0, true)
	ButtonHints.draw_button(self, c, h, "y")
	HillHintLayer.draw_rope_icon(self, Rect2(c + Vector2(h * 0.5 + 16.0, -h * 0.5), Vector2(h, h)), 1.0)
	var font := get_theme_default_font()
	var fs := 30
	draw_string(font, Vector2(c.x + h * 1.5 + 34.0, size.y * 0.5 + fs * 0.35), "hold: rope up", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff5e6"))
