## The Treasure Shelf up top, right of the Caveman's fire (Hillville zone &"shelf"): a cabinet
## with one board per layer, Topsoil at the top. Every treasure row of that layer has a slot: a
## found one stands there in colour, one still underground is a dark silhouette, so "how many are
## left per layer" reads without numbers (until the Museum takes over that job).
## A treasure found since a player was last up here sparkles in its slot; the first player to walk
## up to the shelf sees it pop into place (`shelf_place`, a gold puff). Visual only, no collision.
class_name TreasureShelf
extends Node2D

const FILE := "props/treasure_shelf.png"
const X := 48 * 48.0
const NEAR := 150.0
const ICON_H := 15.0
const FALLBACK_SIZE := Vector2(128, 112)
const GOLD := Color("ffd23f")

## HillGame (untyped: tests use fakes).
var game: Node
var layer_ids: Array[StringName] = [&"topsoil", &"clay", &"stone", &"ice", &"crystal", &"bottom"]
## id -> seconds of pop left (< 0: still waiting for a player to come and look).
var fresh := {}

var _t := 0.0

signal placed(id: StringName)


func setup(p_game: Node) -> void:
	game = p_game
	name = "TreasureShelf"
	position = Vector2(X, 0)
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var u = game.get("underground") if game != null else null
	if u != null and u.has_method("layers"):
		layer_ids.clear()
		for l: LayerData in u.layers():
			layer_ids.append(l.id)
	Events.treasure_found.connect(_on_found)


func _exit_tree() -> void:
	if Events.treasure_found.is_connected(_on_found):
		Events.treasure_found.disconnect(_on_found)


func _on_found(id: StringName, _p: int) -> void:
	fresh[id] = -1.0
	queue_redraw()


## Board index -> [{id, found}] in id order (tests, the Museum later).
func slots() -> Array:
	var out: Array = []
	for lid in layer_ids:
		var row: Array = []
		for t: TreasureData in Progress.treasures_in_layer(lid):
			row.append({"id": t.id, "found": Progress.has_treasure(t.id)})
		out.append(row)
	return out


func _process(delta: float) -> void:
	_t += delta
	var near := _player_near()
	for id in fresh.keys():
		var v: float = fresh[id]
		if v < 0.0 and near:
			fresh[id] = 1.2
			Audio.play("shelf_place")
			var hv = game.get("hillville") if game != null else null
			if hv != null and hv.has_method("puff"):
				hv.puff(position + _slot_pos(id) + Vector2(0, -2), GOLD, 8)
			placed.emit(id)
		elif v > 0.0:
			fresh[id] = v - delta
			if fresh[id] <= 0.0:
				fresh.erase(id)
	queue_redraw()


func _player_near() -> bool:
	if game == null or not game.has_method("player_node"):
		return false
	for p in [0, 1]:
		var n = game.player_node(p)
		if n == null:
			continue
		var dir = game.get("director")
		if dir != null and dir.scene_of(p) != &"hillville":
			continue
		if absf((n as Node2D).global_position.x - global_position.x) < NEAR:
			return true
	return false


func _boards() -> Array:
	var e := SheetSprite.entry(FILE)
	var piv: Vector2 = Vector2(e.pivot[0], e.pivot[1]) if e.has("pivot") else Vector2(FALLBACK_SIZE.x * 0.5, FALLBACK_SIZE.y)
	var out: Array = []
	var raw: Array = e.get("shelves", [])
	if raw.is_empty():
		for i in 6:
			raw.append([10, 24 + i * 15, FALLBACK_SIZE.x - 20])
	for b in raw:
		out.append([Vector2(b[0], b[1]) - piv, float(b[2])])
	return out


## Where treasure `id` stands (shelf-local px, its feet).
func _slot_pos(id: StringName) -> Vector2:
	var boards := _boards()
	var s := slots()
	for i in mini(s.size(), boards.size()):
		var row: Array = s[i]
		for k in row.size():
			if row[k].id == id:
				var b: Array = boards[i]
				var step: float = b[1] / float(row.size())
				return (b[0] as Vector2) + Vector2(step * (k + 0.5), 0)
	return Vector2.ZERO


func _draw() -> void:
	var tex := SpriteArt.texture(FILE)
	if tex != null:
		SpriteArt.draw(self, FILE, 0, 0, Vector2.ZERO)
	else:
		var r := Rect2(Vector2(-FALLBACK_SIZE.x * 0.5, -FALLBACK_SIZE.y), FALLBACK_SIZE)
		draw_rect(r.grow(2), Color(0.23, 0.16, 0.27))
		draw_rect(r, Color("a47148"))
	var boards := _boards()
	var s := slots()
	for i in mini(s.size(), boards.size()):
		var row: Array = s[i]
		for k in row.size():
			var id: StringName = row[k].id
			var at := _slot_pos(id)
			var b: Array = boards[i]
			var room: float = b[1] / float(row.size()) - 2.0
			_draw_icon(id, at, room, row[k].found)


func _draw_icon(id: StringName, feet: Vector2, room: float, found: bool) -> void:
	var tex := SpriteArt.texture("treasures/%s.png" % id)
	var pop: float = fresh.get(id, 0.0)
	var k := 1.0
	if found and pop > 0.0:
		k = 1.0 + 0.5 * sin(pop / 1.2 * PI)
	if tex == null:
		draw_rect(Rect2(feet - Vector2(4, 8) * k, Vector2(8, 8) * k), GOLD if found else Color(0.15, 0.13, 0.18, 0.8))
		return
	var ts := Vector2(tex.get_size())
	var sc := minf(1.0, minf(ICON_H / ts.y, room / ts.x)) * k
	var sz := ts * sc
	var mod := Color.WHITE if found else Color(0.13, 0.11, 0.16, 0.75)
	draw_texture_rect(tex, Rect2(Vector2(feet.x - sz.x * 0.5, feet.y - sz.y).round(), sz), false, mod)
	if found and fresh.has(id):
		# Twinkles: waiting (slow) or popping into place (fast).
		var sp := 3.0 if pop < 0.0 else 9.0
		for j in 3:
			var a := _t * sp + j * TAU / 3.0
			var p := feet + Vector2(cos(a) * (sz.x * 0.5 + 3.0), -sz.y * 0.5 + sin(a) * (sz.y * 0.5 + 3.0))
			draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color(1, 1, 1, 0.9), 1.0)
			draw_line(p - Vector2(0, 2), p + Vector2(0, 2), Color(1, 1, 1, 0.9), 1.0)
