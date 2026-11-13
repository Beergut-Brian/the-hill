## A settings row that does something instead of holding a value (Restore last hill): the label
## (and detail) on the left, a "HOLD [a]" chip on the right. SettingsPanel opens its question on A.
class_name ActionRow
extends SettingRow


func _draw() -> void:
	var r := _draw_frame()
	var k := clampf(_f, 0.0, 1.0)
	var ink := UiStyle.CREAM.lerp(UiStyle.INK_SHOW, k)
	if disabled:
		ink = Color(UiStyle.CREAM, 0.35)
	var cy := r.get_center().y
	var x := r.position.x + lerpf(64.0, 150.0, k)
	if detail != "" and k > 0.5:
		UiStyle.draw_show(self, Vector2(x, cy - 14.0), text.to_upper(), int(lerpf(text_size, text_size_focused, k)) - 6, ink)
		UiStyle.draw_rich(self, Vector2(x + 4.0, cy + 34.0), detail, UiStyle.Role.HINT, Color(UiStyle.INK_SHOW, 0.7 * k), 0, 24)
	else:
		UiStyle.draw_show(self, Vector2(x, cy), text.to_upper(), int(lerpf(text_size, text_size_focused, k)), ink)
	var right := size.x - UiStyle.SAFE.x * 0.5 + _shift()
	var cr := Rect2(right - 300.0, cy - 33.0, 286.0, 66.0)
	UiStyle.para(self, cr, UiStyle.accent if k > 0.5 else Color(1, 1, 1, 0.12))
	UiStyle.draw_rich(self, cr.get_center() + Vector2(8, 0), "Hold [a]", UiStyle.Role.HINT,
			UiStyle.INK_SHOW if k > 0.5 else Color(ink, 0.6), 1, 34)
	draw_set_transform_matrix(Transform2D.IDENTITY)
