## A settings row: a slanted bar with the label on the left and its value on the right, as a
## 10-segment meter with the number, or ON / OFF chips. Same focus, slam and squash as MenuItem.
## The settings panel changes `value`.
class_name SettingRow
extends MenuItem

enum Kind { SLIDER, TOGGLE }

@export var kind := Kind.SLIDER
@export var detail := ""
## Slider: 0..1 in steps of 0.1. Toggle: 0 or 1.
var value := 1.0:
	set(v):
		if v != value and is_inside_tree() and kind == Kind.SLIDER:
			_bump()
		value = v
		queue_redraw()

var _pop := 0.0


func _init() -> void:
	super()
	height = 112.0
	height_focused = 126.0
	text_size = 56
	text_size_focused = 62


func is_on() -> bool:
	return value >= 0.5


func _bump() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _pop = v; queue_redraw(), 1.0, 0.0, 0.2)


func _draw() -> void:
	var r := _draw_frame()
	var k := clampf(_f, 0.0, 1.0)
	var ink := UiStyle.CREAM.lerp(UiStyle.INK_SHOW, k)
	var cy := r.get_center().y
	var x := r.position.x + lerpf(64.0, 150.0, k)
	if detail != "" and k > 0.5:
		UiStyle.draw_show(self, Vector2(x, cy - 14.0), text.to_upper(), int(lerpf(text_size, text_size_focused, k)) - 6, ink)
		UiStyle.draw_rich(self, Vector2(x + 4.0, cy + 34.0), detail, UiStyle.Role.HINT, Color(UiStyle.INK_SHOW, 0.7 * k), 0, 24)
	else:
		UiStyle.draw_show(self, Vector2(x, cy), text.to_upper(), int(lerpf(text_size, text_size_focused, k)), ink)
	var right := size.x - UiStyle.SAFE.x * 0.5 + _shift()
	if kind == Kind.SLIDER:
		var lit := roundi(value * 10)
		var meter_on := UiStyle.skin().accent2 if k > 0.5 else UiStyle.accent
		var off := Color(UiStyle.INK_SHOW, 0.16) if k > 0.5 else Color(1, 1, 1, 0.14)
		var x0 := right - 140.0 - 10 * 34.0
		for i in 10:
			var h := 56.0 + (10.0 * _pop if i == lit - 1 else 0.0)
			UiStyle.para(self, Rect2(x0 + i * 34.0, cy - h * 0.5, 24, h), meter_on if i < lit else off)
		UiStyle.draw_show(self, Vector2(right, cy), str(roundi(value * 100)), 58, ink, 2)
	else:
		for j in 2:
			var on := j == 0
			var lit := on == is_on()
			var cr := Rect2(right - 340.0 + j * 170.0, cy - 33.0, 156.0, 66.0)
			UiStyle.para(self, cr, UiStyle.accent if lit else (Color(UiStyle.INK_SHOW, 0.14) if k > 0.5 else Color(1, 1, 1, 0.12)))
			var tc := UiStyle.INK_SHOW if lit else Color(ink, 0.55)
			UiStyle.draw_show(self, cr.get_center() + Vector2(6, 0), "ON" if on else "OFF", 44, tc, 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)
