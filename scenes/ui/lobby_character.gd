## Placeholder lobby character: a chunky little figure in the player's colour with a hard ink
## outline, so the template's stage reads before a game hands over Jeff and Chuck (MenuSkin).
## The lobby calls set_joined(on), wave() and cheer() on whatever stands on the podium.
extends Control

@export var player: int = 0

var _joined := false
var _arm := 0.0
var _t := 0.0
var _tw: Tween


func set_joined(on: bool) -> void:
	_joined = on
	queue_redraw()


func wave() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	for i in 3:
		_tw.tween_method(_set_arm, 0.0, 1.0, 0.12)
		_tw.tween_method(_set_arm, 1.0, 0.0, 0.12)


func cheer() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_set_arm, _arm, 1.0, 0.1)
	_tw.tween_interval(0.6)
	_tw.tween_method(_set_arm, 1.0, 0.0, 0.25)


func _set_arm(a: float) -> void:
	_arm = a
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var col: Color = UiStyle.player_color(player).lightened(0.12)
	var ink := UiStyle.INK_SHOW
	var w := size.x
	var h := size.y
	var bob := sin(_t * 2.2 + player) * 4.0
	var cx := w * 0.5
	var feet := h - 4.0
	var bw := w * 0.44
	var body := Rect2(cx - bw * 0.5, feet - h * 0.42 + bob, bw, h * 0.42 - bob)
	var head := Vector2(cx, body.position.y - h * 0.15)
	var hr := w * 0.22
	# Arms: up when cheering or waving, down at rest.
	for s in [-1.0, 1.0]:
		var sh := Vector2(cx + s * bw * 0.42, body.position.y + h * 0.08)
		var up := _arm if s > 0.0 or _arm > 0.5 else 0.0
		var dir := Vector2(s * 0.55, 0.85).lerp(Vector2(s * 0.5, -0.9), up).normalized()
		var hand := sh + dir * h * 0.2
		draw_line(sh, hand, ink, w * 0.1 + 12.0, true)
		draw_line(sh, hand, col, w * 0.1, true)
		draw_circle(hand, w * 0.065 + 6.0, ink)
		draw_circle(hand, w * 0.065, col.lightened(0.2))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(bw * 0.4))
	sb.border_color = ink
	sb.set_border_width_all(6)
	sb.anti_aliasing = true
	draw_style_box(sb, body)
	# Belly patch.
	draw_circle(Vector2(cx, body.get_center().y + 8), bw * 0.24, col.lightened(0.3))
	draw_circle(head, hr + 6.0, ink)
	draw_circle(head, hr, col.lightened(0.25))
	var eye := hr * 0.16
	for s in [-1.0, 1.0]:
		var e := head + Vector2(s * hr * 0.36, -hr * 0.05)
		if _joined:
			draw_circle(e, eye, ink)
			draw_circle(e + Vector2(-eye * 0.3, -eye * 0.35), eye * 0.35, Color.WHITE)
		else:
			draw_line(e - Vector2(eye, 0), e + Vector2(eye, 0), ink, 5.0, true)
	if _joined:
		draw_arc(head + Vector2(0, hr * 0.25), hr * 0.32, 0.25, PI - 0.25, 16, ink, 6.0, true)
	# A headband in the player's colour, so the silhouette says who it is.
	draw_arc(head, hr * 0.9, PI + 0.5, TAU - 0.5, 20, UiStyle.player_color(player).darkened(0.25), hr * 0.18, true)
