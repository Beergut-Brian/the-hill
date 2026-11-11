## The picture bubble over whoever just barked (HillBarks). Follows the speaker, pops in, fades
## out, then frees itself. Pictures only (PictoBubble), never words.
class_name BarkBubble
extends Node2D

var speaker: Node2D
var head := Vector2(0, -34)
var pics: Array = []
var secs := 1.6
var _age := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = UndergroundLook.GLOW_Z + 2
	_follow()


func _process(delta: float) -> void:
	_age += delta
	if _age >= secs or not is_instance_valid(speaker):
		queue_free()
		return
	_follow()
	queue_redraw()


func _follow() -> void:
	if is_instance_valid(speaker):
		global_position = speaker.global_position + head


func _draw() -> void:
	var pop := clampf(_age / 0.15, 0.0, 1.0)
	var k := 0.6 + 0.4 * pop + 0.12 * sin(pop * PI)
	PictoBubble.draw(self, Vector2.ZERO, pics, clampf((secs - _age) * 4.0, 0.0, 1.0), k)
