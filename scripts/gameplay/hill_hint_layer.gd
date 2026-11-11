## PT10-8: the context button hints for The Hill. One ButtonHints panel per player in the bottom
## outer corner of their view (P1 left, P2 right; their own half in split), inside the 5% safe
## area, edged in the player's colour. Every frame it asks for_player() what A, B and X do right
## now and the panel changes the same frame. HillGame adds one under the director, after the HUD.
class_name HillHintLayer
extends Control

const SAFE := 0.05
const PANEL := preload("res://scenes/ui/kit/button_hints.tscn")

## HillGame (untyped so this script stands alone).
var game: Node
var _panels := {}   # player -> ButtonHints


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func panel_of(p: int) -> ButtonHints:
	return _panels.get(p)


func _process(_delta: float) -> void:
	refresh()


## Updates every player's panel (tests call it directly).
func refresh() -> void:
	if game == null:
		return
	for p in _panels.keys():
		if not game.players.has(p):
			_panels[p].queue_free()
			_panels.erase(p)
	for p: int in game.players:
		var bh: ButtonHints = _panels.get(p)
		if bh == null:
			bh = PANEL.instantiate()
			bh.accent = Players.COLOR.get(p, Color.WHITE)
			bh.align_right = p == Players.P2
			add_child(bh)
			_panels[p] = bh
		var view: Rect2 = game.director.view_rect_of(p)
		view.position -= global_position
		var safe := view.grow(-minf(view.size.x, view.size.y) * SAFE)
		var box := Vector2(minf(320.0, safe.size.x * 0.4), minf(260.0, safe.size.y * 0.5))
		bh.position = Vector2(safe.end.x - box.x if bh.align_right else safe.position.x, safe.end.y - box.y)
		bh.size = box
		bh.show_hints(for_player(game, game.players[p]))


## What each button does for this player right now: [{button, icon, dim?}].
static func for_player(game: Node, n: HillPlayer) -> Array:
	var out: Array = []
	if n == null:
		return out
	var p := n.player
	var lift: int = n.lift_prompt()
	if lift == 1 and not n.lift_ready():
		lift = 0
	if n.locked:
		if lift == 2:
			out.append({"button": "a", "icon": &"ride", "dim": true})
		return out
	var build: Object = game.get("build")
	var up_top := n.world == null
	if up_top and build != null and build.captures(p):
		return [{"button": "a", "icon": &"ok"}, {"button": "b", "icon": &"back"}, {"button": "x", "icon": &"book"}]
	if lift == 1:
		out.append({"button": "a", "icon": &"ride"})
	if lift != 1 and up_top and n.vehicle == null and build != null and build.has_ghost(p):
		out.append({"button": "a", "icon": &"ok"})
	if n.vehicle != null:
		if lift != 1:
			out.append({"button": "a", "icon": vehicle_icon(n)})
		out.append({"button": "b", "icon": &"exit"})
	else:
		if lift != 1 and not up_top and n.shovel_ok():
			out.append({"button": "a", "icon": &"climb" if n.is_stepping_aim() else &"dig"})
		var b := &"jump"
		if up_top and build != null and build.has_ghost(p):
			b = &"back"
		elif game.has_method("vehicle_near") and game.vehicle_near(n) != null:
			b = &"enter"
		out.append({"button": "b", "icon": b})
	if up_top and build != null:
		out.append({"button": "x", "icon": &"book"})
	return out


## The picture for A in a vehicle: tip (the Dump Truck up top), drill, else scoop up top / dig below.
static func vehicle_icon(n: HillPlayer) -> StringName:
	var id := n.vehicle.id
	if n.world == null:
		return &"tip" if id == &"dump_truck" else &"scoop"
	if id == &"drill_rig":
		return &"drill"
	if id == &"crane":
		return &"hook"
	return &"dig"
