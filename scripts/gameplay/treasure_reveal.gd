## The reveal moment for a pickup treasure (Underground._pick_up): the treasure pops out of the
## ground, grows to 2.5x over a turning sunburst with sparkles (`treasure_reveal`), holds for a
## moment so he can see it, then shrinks and flies into the finder's bag (`treasure_pickup`).
## About 2 s, never blocks play; frees itself. A child of the TileWorld (world px).
class_name TreasureReveal
extends Node2D

const POP_TIME := 0.45
const HOLD_TIME := 1.0
const FLY_TIME := 0.45
const RISE := 44.0
const BIG := 2.5
const GOLD := Color("ffd23f")
const CREAM := Color("fff2a8")

signal done()

var id: StringName
## The player the treasure flies to (may be null: it just fades).
var target: Node2D

var t := 0.0
var _start := Vector2.ZERO
var _tex: Texture2D


func _ready() -> void:
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_start = position
	_tex = SpriteArt.texture("treasures/%s.png" % id)
	Audio.play("treasure_reveal")


func total_time() -> float:
	return POP_TIME + HOLD_TIME + FLY_TIME


func _process(delta: float) -> void:
	t += delta
	if t >= total_time():
		Audio.play("treasure_pickup")
		var w := get_parent() as TileWorld
		if w != null:
			w.remove_light(self)
		done.emit()
		queue_free()
		return
	if t < POP_TIME:
		var k := t / POP_TIME
		position = _start + Vector2(0, -RISE * _ease_out(k))
	elif t < POP_TIME + HOLD_TIME:
		position = _start + Vector2(0, -RISE + sin((t - POP_TIME) * 6.0) * 2.0)
	else:
		var k := (t - POP_TIME - HOLD_TIME) / FLY_TIME
		var from := _start + Vector2(0, -RISE)
		var to := from
		if target != null and is_instance_valid(target):
			to = target.position - Vector2(0, 30) if target.get_parent() == get_parent() else \
					get_parent().to_local(target.global_position) - Vector2(0, 30)
		position = from.lerp(to, k * k)
	queue_redraw()


static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func scale_now() -> float:
	if t < POP_TIME:
		return lerpf(0.6, BIG, _ease_out(t / POP_TIME))
	if t < POP_TIME + HOLD_TIME:
		return BIG
	return lerpf(BIG, 0.4, (t - POP_TIME - HOLD_TIME) / FLY_TIME)


func _draw() -> void:
	var s := scale_now()
	var glow := 1.0 if t < POP_TIME + HOLD_TIME else 1.0 - (t - POP_TIME - HOLD_TIME) / FLY_TIME
	# Sunburst: 10 turning wedges behind the treasure.
	var r := 22.0 * s
	for k in 10:
		var a := t * 1.4 + k * TAU / 10.0
		var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.12) * r, Vector2.from_angle(a + 0.12) * r])
		draw_colored_polygon(pts, Color(GOLD, 0.35 * glow))
	draw_circle(Vector2.ZERO, 12.0 * s, Color(CREAM, 0.35 * glow))
	# Sparkle stars on a ring.
	for k in 6:
		var a := -t * 2.0 + k * TAU / 6.0
		var p := Vector2.from_angle(a) * (16.0 * s + sin(t * 9.0 + k) * 3.0)
		var z := 2.0 + 1.5 * absf(sin(t * 7.0 + k))
		draw_line(p - Vector2(z, 0), p + Vector2(z, 0), Color(1, 1, 1, glow), 1.5)
		draw_line(p - Vector2(0, z), p + Vector2(0, z), Color(1, 1, 1, glow), 1.5)
	if _tex != null:
		var sz := Vector2(_tex.get_size()) * s
		draw_texture_rect(_tex, Rect2((-sz * 0.5).round(), sz), false)
	else:
		draw_rect(Rect2(Vector2(-6, -6) * s, Vector2(12, 12) * s), GOLD)
