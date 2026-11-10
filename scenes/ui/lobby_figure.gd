## The Hill's placeholder lobby figures: Jeff (P1, green, a box body, a hard hat and a hint of a
## chicken comb peeking out under it) and Chuck (P2, red, a box body and a hard hat). Flat shapes in
## _draw(). The lobby calls set_joined(on) and wave() (see lobby_character.gd).
class_name LobbyFigure
extends Control

const INK := Color("1e1e26")
const HAT := Color("f2c94c")
const COMB := Color("e8433a")

@export var player: int = 0

var _joined := false
var _arm := 0.3
var _hop := 0.0
var _tw: Tween


func set_joined(on: bool) -> void:
	_joined = on
	queue_redraw()


func is_joined() -> bool:
	return _joined


func wave() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_set_hop, 0.0, 1.0, 0.12)
	_tw.tween_method(_set_hop, 1.0, 0.0, 0.16)
	for i in 3:
		_tw.tween_method(_set_arm, 0.3, -0.9, 0.14)
		_tw.tween_method(_set_arm, -0.9, 0.3, 0.14)


func _set_arm(a: float) -> void:
	_arm = a
	queue_redraw()


func _set_hop(h: float) -> void:
	_hop = h
	queue_redraw()


func _draw() -> void:
	var col: Color = Players.COLOR[player].lightened(0.35)
	var ink := INK
	var hat := HAT
	if not _joined:
		col = Color(1, 1, 1, 0.12)
		ink = Color(1, 1, 1, 0.12)
		hat = Color(1, 1, 1, 0.12)
	var w := size.x
	var h := size.y
	var lift := -_hop * h * 0.06
	# Box body with a head box on top.
	var body := Rect2(w * 0.27, h * 0.44 + lift, w * 0.46, h * 0.56)
	var head := Rect2(w * 0.32, h * 0.18 + lift, w * 0.36, h * 0.25)
	# Arm: from the shoulder (P1 waves with the right hand, P2 with the left).
	var side := 1.0 if player == 0 else -1.0
	var shoulder := Vector2(w * 0.5 + side * w * 0.2, h * 0.52 + lift)
	var hand := shoulder + Vector2.from_angle(side * (_arm - PI / 2 + 0.9) + (0.0 if side > 0 else PI)) * h * 0.3
	draw_line(shoulder, hand, ink, w * 0.12 + 8.0)
	draw_line(shoulder, hand, col, w * 0.12)
	draw_rect(Rect2(hand - Vector2.ONE * (w * 0.07 + 4), Vector2.ONE * (w * 0.14 + 8)), ink)
	draw_rect(Rect2(hand - Vector2.ONE * w * 0.07, Vector2.ONE * w * 0.14), col)
	draw_rect(body.grow(6.0), ink)
	draw_rect(body, col)
	draw_rect(head.grow(6.0), ink)
	draw_rect(head, col)
	if player == 0:
		# Jeff: a hint of a chicken comb, three bumps peeking out from under the hat's back.
		for k in 3:
			var c := Vector2(head.position.x + head.size.x * (0.12 + k * 0.14) * (1.0), head.position.y - h * 0.085)
			draw_circle(c, w * 0.045 + 3.0, ink if _joined else Color(1, 1, 1, 0.12))
			draw_circle(c, w * 0.045, COMB if _joined else Color(1, 1, 1, 0.12))
	# Hard hat: dome and brim.
	var dome := Rect2(head.position.x + head.size.x * 0.06, head.position.y - h * 0.07, head.size.x * 0.88, h * 0.09)
	var brim := Rect2(head.position.x - w * 0.05, head.position.y + h * 0.005, head.size.x + w * 0.1, h * 0.03)
	draw_rect(dome.grow(5.0), ink)
	draw_rect(brim.grow(5.0), ink)
	draw_rect(dome, hat)
	draw_rect(brim, hat)
	draw_rect(Rect2(dome.get_center().x - w * 0.02, dome.position.y, w * 0.04, dome.size.y), hat.darkened(0.15))
	if _joined:
		var eye_y := head.position.y + head.size.y * 0.5
		draw_rect(Rect2(head.position.x + head.size.x * 0.25, eye_y, w * 0.05, h * 0.04), ink)
		draw_rect(Rect2(head.position.x + head.size.x * 0.62, eye_y, w * 0.05, h * 0.04), ink)
		draw_rect(Rect2(head.position.x + head.size.x * 0.3, eye_y + h * 0.075, head.size.x * 0.4, h * 0.02), ink)
