## The prototype elevator: stepping into a cage zone rides automatically (no button), for that player
## only. Lock, Audio "elevator", a RIDE_TIME drop (the capsule sinks up top / rises underground, the
## cage flashes), then director.move_player() into the other cage zone and unlock. A zone only
## re-arms for a player once that player has stepped out of it. Physics time, so tests can count frames.
class_name ProtoElevator
extends Node

signal ride_started(player: int, from: StringName)
signal ride_finished(player: int, to: StringName)

## The whole ride, start to arrival, in seconds of game time (contract: under a second).
const RIDE_TIME := 0.5
const SINK_PX := 18.0

var director: ScreenDirector
## StringName scene id -> its root (has cage_zone() and a cage_flash property).
var scenes: Dictionary = {}
## StringName -> the scene the cage leads to and where it puts you.
var other := {&"hillville": &"underground", &"underground": &"hillville"}
var arrival := {}

var _riding := {}      # player -> seconds into the ride
var _must_exit := {}   # player -> true until they leave the zone they arrived in


func is_riding(player: int) -> bool:
	return _riding.has(player)


func forget(player: int) -> void:
	_riding.erase(player)
	_must_exit.erase(player)


func check(players: Dictionary, delta: float) -> void:
	for p: int in players:
		var node: ProtoPlayer = players[p]
		if _riding.has(p):
			_advance(p, node, delta)
			continue
		var scene := director.scene_of(p)
		var root: Node = scenes.get(scene)
		if root == null:
			continue
		var inside: bool = root.cage_zone().has_point(node.position)
		if not inside:
			_must_exit.erase(p)
		elif not _must_exit.has(p):
			_start(p, node, scene)


func _start(p: int, node: ProtoPlayer, scene: StringName) -> void:
	_riding[p] = 0.0
	node.locked = true
	Audio.play("elevator")
	ride_started.emit(p, scene)


func _advance(p: int, node: ProtoPlayer, delta: float) -> void:
	var t: float = _riding[p] + delta
	_riding[p] = t
	var from := director.scene_of(p)
	var k := clampf(t / RIDE_TIME, 0.0, 1.0)
	# Up top the capsule sinks into the cage; underground it rises up the shaft.
	node.ride_offset = SINK_PX * k * (1.0 if from == &"hillville" else -1.0)
	node.modulate.a = 1.0 - k * 0.7
	var root: Node = scenes[from]
	root.cage_flash = absf(sin(k * PI * 3.0))
	if t < RIDE_TIME:
		return
	root.cage_flash = 0.0
	var to: StringName = other[from]
	_riding.erase(p)
	_must_exit[p] = true
	node.ride_offset = 0.0
	node.modulate.a = 1.0
	director.move_player(p, to, arrival[to])
	node.locked = false
	(scenes[to] as Node).cage_flash = 1.0
	_fade_flash(scenes[to])
	ride_finished.emit(p, to)


func _fade_flash(root: Node) -> void:
	var tw := root.create_tween()
	tw.tween_property(root, "cage_flash", 0.0, 0.3)
