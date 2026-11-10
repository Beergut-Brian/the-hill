## The chooser's poof: cream puffs burst out from a point and fade, with a few accent sparks.
## Poof.burst(parent, at) adds one, plays it (0.45 s) and frees it. `t` (0..1) poses it for shots.
class_name Poof
extends Control

const TIME := 0.45
const PUFFS := 9

var t := 0.0:
	set(v):
		t = v
		queue_redraw()
var tint := Color.WHITE


static func burst(parent: Node, at: Vector2, color := Color.WHITE) -> Poof:
	var p := Poof.new()
	p.position = at
	p.tint = color
	parent.add_child(p)
	if p.is_inside_tree():
		var tw := p.create_tween()
		tw.tween_property(p, "t", 1.0, TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(p.queue_free)
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var a := 1.0 - smoothstep(0.55, 1.0, t)
	for i in PUFFS:
		var ang := TAU * i / PUFFS + 0.35
		var d := lerpf(30.0, 150.0, t) * (1.0 if i % 2 == 0 else 0.8)
		var c := Vector2(cos(ang) * d, sin(ang) * d * 0.7)
		var r := lerpf(42.0, 16.0, t) * (1.0 if i % 2 == 0 else 0.75)
		draw_circle(c, r + 5.0, Color(UiStyle.INK_SHOW, a * 0.85))
		draw_circle(c, r, Color(UiStyle.CREAM.lerp(tint, 0.18), a))
	# Sparks: short accent strokes flying out between the puffs.
	for i in 6:
		var ang := TAU * i / 6.0
		var d0 := lerpf(60.0, 170.0, t)
		var dir := Vector2(cos(ang), sin(ang) * 0.75)
		draw_line(dir * d0, dir * (d0 + 34.0 * (1.0 - t)), Color(UiStyle.accent, a), 8.0, true)
