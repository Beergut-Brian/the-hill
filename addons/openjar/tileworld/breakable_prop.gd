## A multi-tile prop standing in a TileWorld (the car, a wall): `footprint` tiles, top-left at its
## position, static collision, drawn as a flat coloured rect by default. The cells under it are
## `shape.below` of its bottom-row cells (footprint cells whose below is outside the footprint).
## When the solid share of those drops below `support_needed` (checked when one of them is dug),
## it breaks: one awake FallingBody per footprint cell, TileWorld.prop_broke, then it frees itself.
class_name BreakableProp
extends Node2D

@export var footprint := Vector2i(3, 2)
@export var support_needed: float = 0.5
@export var color := Color(0.75, 0.32, 0.25)

var world: TileWorld
var broken := false
var _body: StaticBody2D


func _ready() -> void:
	var n := get_parent()
	while n != null and not n is TileWorld:
		n = n.get_parent()
	world = n as TileWorld
	var size := Vector2(footprint) * _cell_size()
	_body = StaticBody2D.new()
	if world:
		_body.collision_layer = world.collision_layer
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = size * 0.5
	_body.add_child(cs)
	add_child(_body)
	if world:
		world._register_prop(self)
	queue_redraw()


func _exit_tree() -> void:
	if world and not broken:
		world._unregister_prop(self)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(footprint) * _cell_size())
	draw_rect(r, color)
	draw_rect(r.grow(-1.0), color.darkened(0.35), false, 2.0)


func _cell_size() -> float:
	return float(world.shape.cell_size) if world and world.shape else 16.0


func footprint_cells() -> Array[Vector2i]:
	var origin := world.shape.cell_at(world.local_pos(self) + Vector2.ONE * _cell_size() * 0.5)
	var cells: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			cells.append(origin + Vector2i(x, y))
	return cells


func support_cells() -> Array[Vector2i]:
	var cells := footprint_cells()
	var out: Array[Vector2i] = []
	for c in cells:
		var b := world.shape.below(c)
		if not cells.has(b) and not out.has(b):
			out.append(b)
	return out


func support_share() -> float:
	var under := support_cells()
	if under.is_empty():
		return 1.0
	var solid := 0
	for c in under:
		if world.is_solid(c):
			solid += 1
	return solid / float(under.size())


func _check_support() -> void:
	if not broken and support_share() < support_needed:
		break_apart()


func break_apart() -> void:
	if broken or world == null:
		return
	broken = true
	world._unregister_prop(self)
	remove_child(_body)
	_body.queue_free()
	var cs := _cell_size()
	var cells := footprint_cells()
	var pieces: Array = []
	for c in cells:
		var p := FallingBody.new()
		p.color = color
		p.size_px = Vector2.ONE * (cs - 2.0)
		p.position = world.shape.center_of(c)
		world.add_child(p)
		pieces.append(p)
	for c in cells:
		world._bodies.wake_resting_on(c)
	world.prop_broke.emit(self, pieces)
	queue_free()
