## A boulder, treasure or prop piece in a TileWorld. Ignores project gravity: it applies
## `world.shape.gravity_at(position)` itself (toward the core on a disk). Sleeps when resting and
## only wakes when the tile under it is removed (TileWorld does that), or when something hits it.
## Frozen while its chunk is not loaded. Finds its TileWorld by walking up its parents.
## Draws a flat coloured square (or circle when `round`) and builds its own collision shape.
class_name FallingBody
extends RigidBody2D

const LAND_SPEED := 60.0
const LAND_COOLDOWN_MS := 300
const WATER_DRAG := 3.0

@export var color := Color(0.6, 0.55, 0.5)
@export var size_px := Vector2(14, 14)
@export var round := false
## Pushed up by water (buoyancy_at) and slowed in it.
@export var floats := false

var world: TileWorld

# TileWorld bookkeeping (body_index.gd).
var _rest_cells: Array[Vector2i] = []
var _frozen_by_world := false
var _wake_on_load := false
var _sleep_cb := Callable()
var _prev_speed := 0.0
var _was_contact := false
var _last_land_ms := -100000


func _init() -> void:
	gravity_scale = 0.0
	can_sleep = true
	max_contacts_reported = 4


func _enter_tree() -> void:
	if world != null and is_instance_valid(world):
		world.add_body(self)
		return
	var n := get_parent()
	while n != null and not n is TileWorld:
		n = n.get_parent()
	if n != null:
		(n as TileWorld).add_body(self)


func _exit_tree() -> void:
	if world != null and is_instance_valid(world):
		world.remove_body(self)


func _ready() -> void:
	gravity_scale = 0.0
	var has_shape := false
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			has_shape = true
	if not has_shape:
		var cs := CollisionShape2D.new()
		if round:
			var circle := CircleShape2D.new()
			circle.radius = size_px.x * 0.5
			cs.shape = circle
		else:
			var rect := RectangleShape2D.new()
			rect.size = size_px
			cs.shape = rect
		add_child(cs)
	queue_redraw()


func _draw() -> void:
	var edge := color.darkened(0.35)
	if round:
		draw_circle(Vector2.ZERO, size_px.x * 0.5, color)
		draw_arc(Vector2.ZERO, size_px.x * 0.5 - 0.5, 0.0, TAU, 20, edge, 1.0)
	else:
		var r := Rect2(-size_px * 0.5, size_px)
		draw_rect(r, color)
		draw_rect(r.grow(-0.5), edge, false, 1.0)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if world == null or world.shape == null:
		return
	var local := world.to_local(state.transform.origin) if world.is_inside_tree() else state.transform.origin
	var g := world.shape.gravity_at(local)
	if floats:
		var up := world.buoyancy_at(local)
		if up != Vector2.ZERO:
			g += up
			state.linear_velocity *= maxf(0.0, 1.0 - WATER_DRAG * state.step)
	if world.is_inside_tree():
		g = world.global_transform.basis_xform(g)
	# A constant force, not a velocity change: it is applied before the contact solve, so a
	# resting body reads as still and can fall asleep. Only set on change: setting wakes the body.
	var f := g * mass
	if not f.is_equal_approx(state.get_constant_force()):
		state.set_constant_force(f)
	var contact := state.get_contact_count() > 0
	if contact and not _was_contact and _prev_speed > LAND_SPEED:
		var now := Time.get_ticks_msec()
		if now - _last_land_ms >= LAND_COOLDOWN_MS:
			_last_land_ms = now
			# Deferred: we are inside the physics callback here.
			world._on_body_landed.call_deferred(self, _prev_speed)
	_was_contact = contact
	_prev_speed = state.linear_velocity.length()
