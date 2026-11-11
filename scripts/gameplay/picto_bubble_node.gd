## The PictoBubble scene (`scenes/ui/picto_bubble.tscn`): one picture bubble in the world, for
## arcs, barks and prompts. Follows a speaker, pops in, fades out and frees itself after `secs`
## (0 = stays until hide_bubble()). Pictures only, never words; drawing is PictoBubble's.
##   PictoBubbleNode.pop(parent, speaker, [&"rock", &"face_happy"], 1.6)
class_name PictoBubbleNode
extends Node2D

const SCENE := "res://scenes/ui/picto_bubble.tscn"
const POP_SECS := 0.15
const FADE_SECS := 0.25

## Who the tail points at (followed every frame); null = stays where it was put.
var speaker: Node2D
## Tail tip, from the speaker's origin (their feet).
var head := Vector2(0, -34)
var pics: Array = []
## Seconds on screen; 0 = until hide_bubble().
var secs := 1.6
## Size multiplier on top of the pop-in.
var k := 1.0
var _age := 0.0
var _leaving := -1.0
var _tracks := false


## Instances the scene under `parent`, pointing at `speaker`.
static func pop(parent: Node, at: Node2D, p: Array, s := 1.6, tip := Vector2(0, -34)) -> PictoBubbleNode:
	var b: PictoBubbleNode = (load(SCENE) as PackedScene).instantiate()
	b.speaker = at
	b.pics = p
	b.secs = s
	b.head = tip
	parent.add_child(b)
	return b


func _ready() -> void:
	z_as_relative = false
	z_index = UndergroundLook.GLOW_Z + 2
	_tracks = is_instance_valid(speaker)
	_follow()


## Swap the pictures (pops in again only if it had gone).
func show_pics(p: Array) -> void:
	if _leaving >= 0.0:
		_age = 0.0
	pics = p
	_leaving = -1.0
	queue_redraw()


## Fade out now, then free.
func hide_bubble() -> void:
	if _leaving < 0.0:
		_leaving = 0.0


func alpha() -> float:
	var a := 1.0
	if secs > 0.0:
		a = clampf((secs - _age) / FADE_SECS, 0.0, 1.0)
	if _leaving >= 0.0:
		a = minf(a, clampf(1.0 - _leaving / FADE_SECS, 0.0, 1.0))
	return a


func _process(delta: float) -> void:
	_age += delta
	if _leaving >= 0.0:
		_leaving += delta
	if (secs > 0.0 and _age >= secs) or _leaving >= FADE_SECS or (_tracks and not is_instance_valid(speaker)):
		queue_free()
		return
	_follow()
	queue_redraw()


func _follow() -> void:
	if _tracks and is_instance_valid(speaker):
		global_position = speaker.global_position + head


func _draw() -> void:
	var p := clampf(_age / POP_SECS, 0.0, 1.0)
	PictoBubble.draw(self, Vector2.ZERO, pics, alpha(), k * (0.6 + 0.4 * p + 0.12 * sin(p * PI)))
