## A vehicle's lamps as light sprites (additive): a soft cone ahead of the round nose lamp and a
## small glow on the square roof lamp. A child of a Vehicle (`data`) or of the driving HillPlayer
## (`vehicle`); points come from the vehicle sheet's manifest (`nose_lamp`, `roof_lamp`), mirrored by
## the parent's `facing`. On when the vehicle is in a TileWorld's world (underground: full) or when
## TimeOfDay.lights() > 0.05 (up top: scaled by it).
class_name VehicleGlow
extends Node2D

const CONE_ALPHA := 0.85
const GLOW_ALPHA := 0.9

var _cone := Sprite2D.new()
var _glow := Sprite2D.new()
var _id: StringName = &""
var _under := false
var _check := 0.0


static func attach(parent: Node2D) -> VehicleGlow:
	var g := VehicleGlow.new()
	g.name = "Glow"
	parent.add_child(g)
	return g


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for s: Sprite2D in [_cone, _glow]:
		s.material = mat
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.visible = false
		add_child(s)
	_cone.texture = SpriteArt.texture("fx/cone.png")
	_glow.texture = SpriteArt.texture("fx/glow.png")
	z_index = 1


## 0..1 how much the lamps shine now.
func strength() -> float:
	if _under:
		return 1.0
	var tod := get_node_or_null(^"/root/TimeOfDay")
	var l: float = tod.call("lights") if tod != null and tod.has_method("lights") else 0.0
	return l if l > 0.05 else 0.0


func _is_underground(parent: Node) -> bool:
	if parent.get("world") != null:
		return true
	var w := get_world_2d()
	for n in get_tree().get_nodes_in_group(&"tile_world"):
		if n is CanvasItem and (n as CanvasItem).get_world_2d() == w:
			return true
	return false


func _process(delta: float) -> void:
	var p := get_parent()
	var d = p.get("vehicle") if p.get("vehicle") != null else p.get("data")
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_under = _is_underground(p)
	if d == null or not (d is VehicleData):
		_cone.visible = false
		_glow.visible = false
		return
	var file := "vehicles/%s.png" % d.id
	if not SpriteArt.has(file):
		_cone.visible = false
		_glow.visible = false
		return
	var s := strength()
	var face: int = p.get("facing") if p.get("facing") != null else 1
	_cone.visible = s > 0.0
	_glow.visible = s > 0.0
	if s <= 0.0:
		return
	var nose := SpriteArt.point(file, "nose_lamp")
	var roof := SpriteArt.point(file, "roof_lamp")
	var cs := Vector2(_cone.texture.get_size())
	# Cone apex is its left middle; mirrored it grows to the left.
	_cone.position = (Vector2(nose.x * face - (cs.x if face < 0 else 0.0), nose.y - cs.y * 0.5)).round()
	_cone.flip_h = face < 0
	_cone.modulate = Color(1, 0.93, 0.7, CONE_ALPHA * s)
	var gs := Vector2(_glow.texture.get_size()) * 0.5
	_glow.scale = Vector2(0.5, 0.5)
	_glow.position = Vector2(roof.x * face, roof.y).round() - gs * 0.5
	_glow.modulate = Color(1, 0.9, 0.6, GLOW_ALPHA * s)
