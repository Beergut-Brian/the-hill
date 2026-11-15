## Many flat-coloured shapes in one draw call (hill-igpu-2). Godot's canvas renderer gives every
## draw_line with a width, draw_circle and draw_colored_polygon a draw call of its own, so a few
## dozen cracks cost hundreds. TriBatch collects the same shapes as triangles, in the order they are
## added, and hands them to the renderer as one triangle array: same pixels, one draw call.
## Use inside _draw(): add shapes, then flush(self) where the first shape would have been drawn.
class_name TriBatch
extends RefCounted

## Segments of a circle (Godot draws its own with more; at the few-pixel radii here they match).
const CIRCLE_SEGMENTS := 24

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


func is_empty() -> bool:
	return indices.is_empty()


func clear() -> void:
	points.clear()
	colors.clear()
	indices.clear()


## draw_line(a, b, col, width) with width > 0: a quad `width` wide along a..b.
func line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var d := b - a
	if d.length_squared() == 0.0:
		return
	var t := d.normalized().orthogonal() * (width * 0.5)
	var i := points.size()
	points.append_array([a - t, a + t, b + t, b - t])
	colors.append_array([col, col, col, col])
	indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])


## draw_circle(c, r, col): a filled disc.
func circle(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	var i := points.size()
	points.append(c)
	colors.append(col)
	for k in CIRCLE_SEGMENTS:
		points.append(c + Vector2.from_angle(k * TAU / CIRCLE_SEGMENTS) * r)
		colors.append(col)
	for k in CIRCLE_SEGMENTS:
		indices.append_array([i, i + 1 + k, i + 1 + (k + 1) % CIRCLE_SEGMENTS])


## draw_colored_polygon(pts, col).
func polygon(pts: PackedVector2Array, col: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var i := points.size()
	points.append_array(pts)
	for _p in pts:
		colors.append(col)
	for k in tri:
		indices.append(i + k)


## Everything added so far as one draw command on `ci` (call from its _draw), then empty.
func flush(ci: CanvasItem) -> void:
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
	clear()
