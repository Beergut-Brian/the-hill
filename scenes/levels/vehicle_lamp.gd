## A driven vehicle's nose lamp underground: a child of the driver (a HillPlayer; while driving the
## node *is* the vehicle). It sits on the vehicle sheet's `nose_lamp` point (manifest, relative to the
## pivot, mirrored by `facing`) and is a registered light of `world` only while its parent drives.
class_name VehicleLamp
extends Node2D

const RADIUS := 190.0
const STRENGTH := 1.0

var world: TileWorld
var _lit := false


static func attach(driver: Node2D, p_world: TileWorld) -> VehicleLamp:
	var lamp: VehicleLamp = driver.get_node_or_null(^"NoseLamp")
	if lamp == null:
		lamp = VehicleLamp.new()
		lamp.name = "NoseLamp"
		driver.add_child(lamp)
	lamp.world = p_world
	lamp._lit = false
	lamp._sync()
	return lamp


static func detach(driver: Node2D) -> void:
	var lamp: VehicleLamp = driver.get_node_or_null(^"NoseLamp")
	if lamp:
		if lamp.world:
			lamp.world.remove_light(lamp)
		lamp.queue_free()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var p := get_parent()
	var d = p.get("vehicle") if p else null
	var on: bool = d != null and world != null and is_instance_valid(world)
	if on:
		var file := "vehicles/%s.png" % d.id
		var nose := SheetSprite.point(file, "nose_lamp", Vector2(14, -18))
		var face: int = p.get("facing") if p.get("facing") != null else 1
		position = Vector2(nose.x * face, nose.y)
	if on != _lit:
		_lit = on
		if on:
			world.add_light(self, RADIUS, STRENGTH)
		elif world and is_instance_valid(world):
			world.remove_light(self)
