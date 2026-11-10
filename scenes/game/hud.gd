## The in-game HUD, per player view (director.view_rect_of), inside the 5% safe area, no numbers
## and no text: a depth strip (the six layers' hues stacked, a sun cap for up top, a marker in the
## player's colour where they are) on the view's outer edge, and the backpack icon (a bag that
## fills with the colours of the blocks it holds; full = round, happy, bouncing) beside it.
class_name HillHud
extends Control

const SAFE := 0.05
const STRIP_W := 22.0
const STRIP_H := 260.0
const BAG := Vector2(46, 52)
const DARK := Color(0.07, 0.06, 0.09)

## HillGame (untyped so this script stands alone).
var game: Node
var _t := 0.0
var _counts := {}    # player -> last backpack count, for a little pop when it changes
var _pop := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	for p in _pop.keys():
		_pop[p] = move_toward(_pop[p], 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	if game == null or game.players.is_empty():
		return
	for p: int in game.players:
		var r: Rect2 = game.director.view_rect_of(p)
		r.position -= global_position
		_draw_for(p, r)


func _draw_for(p: int, view: Rect2) -> void:
	var node: Node2D = game.players[p]
	var safe := view.grow_individual(-view.size.x * SAFE, -view.size.y * SAFE, -view.size.x * SAFE, -view.size.y * SAFE)
	var right_side: bool = p == Players.P2
	var x := safe.end.x - STRIP_W if right_side else safe.position.x
	var top := safe.position.y + 26.0
	_draw_strip(p, node, Rect2(x, top, STRIP_W, STRIP_H))
	var bx := x - BAG.x - 18.0 if right_side else x + STRIP_W + 18.0
	_draw_bag(p, node, Vector2(bx, safe.position.y))


func _draw_strip(p: int, node: Node2D, r: Rect2) -> void:
	var layers: Array = game.underground.layers()
	if layers.is_empty():
		return
	var c: Color = Players.COLOR.get(p, Color.WHITE)
	# Sun cap: up top.
	var sun := Vector2(r.get_center().x, r.position.y - 14.0)
	draw_circle(sun, 13.0, DARK)
	draw_circle(sun, 11.0, Color("ffd54a"))
	draw_rect(r.grow(2.0), DARK)
	var total := 0.0
	for l: LayerData in layers:
		total += l.depth_to - l.depth_from
	var y := r.position.y
	for l: LayerData in layers:
		var h := r.size.y * (l.depth_to - l.depth_from) / total
		draw_rect(Rect2(r.position.x, y, r.size.x, h - 1.0), l.hue)
		y += h
	# The marker: on the sun up top; else at the player's depth.
	var at: Vector2
	if game.director.scene_of(p) == &"underground":
		var depth := clampf(node.global_position.y / 16.0, 0.0, total)
		at = Vector2(r.get_center().x, r.position.y + r.size.y * depth / total)
	else:
		at = sun
	var side := 1.0 if p == Players.P1 else -1.0
	var tip := at + Vector2(side * (r.size.x * 0.5 + 4.0), 0)
	var tri := PackedVector2Array([tip, tip + Vector2(side * 14.0, -9.0), tip + Vector2(side * 14.0, 9.0)])
	var big := PackedVector2Array([tip - Vector2(side * 2.5, 0), tip + Vector2(side * 16.5, -11.5), tip + Vector2(side * 16.5, 11.5)])
	draw_colored_polygon(big, DARK)
	draw_colored_polygon(tri, c)
	draw_circle(at, 7.0, DARK)
	draw_circle(at, 5.0, c)


func _draw_bag(p: int, node: Node2D, at: Vector2) -> void:
	var count: int = node.backpack_count()
	var cap: int = maxi(1, node.capacity())
	if _counts.get(p, -1) != count:
		if _counts.has(p):
			_pop[p] = 1.0
		_counts[p] = count
	var full := count >= cap
	var fill := clampf(float(count) / cap, 0.0, 1.0)
	var pop: float = _pop.get(p, 0.0)
	var bounce := absf(sin(_t * 5.0)) * 8.0 if full else 0.0
	var s := BAG * (1.0 + pop * 0.12)
	if full:
		s = Vector2(maxf(s.x, s.y), maxf(s.x, s.y)) * 1.05
	var c := at + Vector2(BAG.x * 0.5, BAG.y * 0.5 + 8.0 - bounce)
	var body := Rect2(c - s * 0.5, s)
	var leather := Color("a47148")
	# Strap.
	draw_arc(c + Vector2(0, -s.y * 0.5), s.x * 0.28, PI, TAU, 12, DARK, 6.0)
	draw_arc(c + Vector2(0, -s.y * 0.5), s.x * 0.28, PI, TAU, 12, leather.darkened(0.2), 3.0)
	if full:
		draw_circle(c, s.x * 0.5 + 3.0, DARK)
		draw_circle(c, s.x * 0.5, leather)
	else:
		draw_rect(body.grow(3.0), DARK)
		draw_rect(body, leather)
	# Contents: stacked bands in the colours of the blocks held, from the bottom up.
	var inner := body.grow(-5.0)
	if count > 0:
		var y := inner.end.y
		var keys: Array = node.backpack.keys()
		keys.sort()
		for k in keys:
			var h := inner.size.y * fill * float(node.backpack[k]) / count
			var col: Color = game.underground.block_color(StringName(k))
			if h < 1.5:
				continue
			if full:
				# Clip the bands to the round bag.
				_draw_band_in_circle(c, s.x * 0.5 - 4.0, y - h, y, col)
			else:
				draw_rect(Rect2(inner.position.x, y - h, inner.size.x, h), col)
			y -= h
	if full:
		# Happy: two dots and a smile on the full bag.
		draw_circle(c + Vector2(-7, -4), 3.0, DARK)
		draw_circle(c + Vector2(7, -4), 3.0, DARK)
		draw_arc(c + Vector2(0, 2), 9.0, 0.35, PI - 0.35, 10, DARK, 3.0)
	# Flap.
	draw_rect(Rect2(body.position.x - 2, body.position.y - 2, body.size.x + 4, 8), leather.darkened(0.25))


func _draw_band_in_circle(c: Vector2, radius: float, y0: float, y1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var y := lerpf(y0, y1, float(i) / steps)
		var dy := clampf(y - c.y, -radius, radius)
		pts.append(Vector2(c.x - sqrt(radius * radius - dy * dy), y))
	for i in range(steps, -1, -1):
		var y := lerpf(y0, y1, float(i) / steps)
		var dy := clampf(y - c.y, -radius, radius)
		pts.append(Vector2(c.x + sqrt(radius * radius - dy * dy), y))
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)
