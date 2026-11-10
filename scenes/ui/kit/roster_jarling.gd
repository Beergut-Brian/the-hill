## A Roster character's 3D master (its Jarling .glb) on a podium: idles, cheers when readied and
## when the round starts. set_character(id) swaps the model in place (RosterCharacter).
extends Node3D

const SCALE := 1.3
const LOOPS := [&"idle", &"run", &"cheer"]

var id := ""
var _model: Node3D
var _anim: AnimationPlayer
var _joined := false


func set_character(to: String) -> void:
	var who := Roster.info(to)
	if who.is_empty() or who.glb == "" or not ResourceLoader.exists(who.glb):
		return
	id = to
	if _model:
		_model.free()
	_model = (load(who.glb) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for a in LOOPS:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_play(&"idle", 0.0)


func set_joined(on: bool) -> void:
	_joined = on
	_play(&"idle", 0.2)


func wave() -> void:
	_play(&"cheer", 0.1)


func cheer() -> void:
	_play(&"cheer", 0.1)


func _play(a: StringName, blend: float) -> void:
	if _anim and _anim.has_animation(a) and _anim.current_animation != a:
		_anim.play(a, blend)
