## H-05: "lowers you down a shaft fast". When the elevator goes down with the Crane aboard, the
## riders do not just appear at the landing: they come in at the shaft mouth and the Crane's cable
## lowers them straight down the shaft to the landing in DROP seconds (the whole ride, cage sink
## included, is under 2 s). The cable is drawn from the mouth to each rider; at the bottom it
## clanks, dings, puffs dust and lets go. The elevator asks wants() and hands the riders to lower().
class_name CraneRide
extends Node2D

const DROP := 1.1
const MOUTH_Y := 8.0
const ROPE := Color(0.2, 0.18, 0.2)

## HillGame (untyped so this script stands alone).
var game: Node
var _drops: Array = []   # {node: HillPlayer, from: Vector2, to: Vector2, t: float}

signal landed(player: int)


## True when one of `riders` drives the Crane: the ride down is a cable ride.
static func wants(game_ref: Node, riders: Array) -> bool:
	for p in riders:
		var node: Node = game_ref.player_node(p)
		if node != null and node.get("vehicle") != null and node.vehicle.id == &"crane":
			return true
	return false


## Where a rider bound for `to` comes in (the shaft mouth over it).
static func mouth(to: Vector2) -> Vector2:
	return Vector2(to.x, MOUTH_Y)


## Lowers `node` (already placed at mouth(to), locked) down to `to`.
func lower(node: HillPlayer, to: Vector2) -> void:
	node.locked = true
	_drops.append({"node": node, "from": node.global_position, "to": to, "t": 0.0})
	Audio.play("elevator_clank")
	set_physics_process(true)


func is_lowering(player: int) -> bool:
	for d in _drops:
		if is_instance_valid(d.node) and d.node.player == player:
			return true
	return false


func _ready() -> void:
	name = "CraneRide"
	z_index = 5
	set_physics_process(not _drops.is_empty())


func _physics_process(delta: float) -> void:
	for d in _drops.duplicate():
		var node: HillPlayer = d.node
		if not is_instance_valid(node):
			_drops.erase(d)
			continue
		d.t += delta
		var k := clampf(d.t / DROP, 0.0, 1.0)
		# Quick off the top, a short slow-down for the landing.
		var e := 1.0 - pow(1.0 - k, 2.2)
		node.global_position = (d.from as Vector2).lerp(d.to, e)
		node.velocity = Vector2.ZERO
		if k >= 1.0:
			_drops.erase(d)
			node.locked = false
			node.bump()
			Audio.play("elevator_ding")
			var ug: Node = game.get("underground") if game != null else null
			if ug != null and ug.has_method("burst"):
				ug.burst(node.global_position, Color(0.85, 0.75, 0.6), 10)
			landed.emit(node.player)
	queue_redraw()
	if _drops.is_empty():
		set_physics_process(false)


func _draw() -> void:
	for d in _drops:
		var node: HillPlayer = d.node
		if not is_instance_valid(node):
			continue
		var top := to_local(Vector2(node.global_position.x, MOUTH_Y - 400.0))
		var h := node.body_size().y
		var hook := to_local(node.global_position + Vector2(0, -h - 2.0))
		draw_line(top, hook, Color(0.95, 0.85, 0.5, 0.45), 8.0)
		draw_line(top, hook, ROPE, 3.0)
		draw_rect(Rect2(hook + Vector2(-5, -6), Vector2(10, 7)), Color("1fbfb0"))
		draw_rect(Rect2(hook + Vector2(-5, -6), Vector2(10, 7)), Vehicle.DARK, false, 1.5)
