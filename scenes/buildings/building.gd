## A placed (or ghost) building on Hillville's ground grid: a flat-colour placeholder drawn from
## its BuildingData id. Origin is the footprint's bottom-left corner on the ground (y up is
## negative), so the unfold scale tween grows it out of the ground. No faces.
class_name Building
extends Node2D

const PLOT := 48
const OUTLINE := Color(0.09, 0.07, 0.07)
const GHOST_OK := Color(0.55, 1.0, 0.55, 0.5)
const GHOST_BAD := Color(1.0, 0.35, 0.35, 0.5)
const UNFOLD_TIME := 0.45

var data: BuildingData
## Progress.buildings index while placed; -1 for a new ghost.
var index := -1
var ghost := false:
	set(v):
		ghost = v
		_tint()
var ghost_ok := true:
	set(v):
		ghost_ok = v
		_tint()
## 0 closed .. 1 rolled up (Garage only).
var door_open := 0.0:
	set(v):
		door_open = v
		queue_redraw()


static func make(d: BuildingData) -> Building:
	var b := Building.new()
	b.data = d
	b.name = "Building_%s" % d.id
	return b


func size_px() -> Vector2:
	return Vector2(data.footprint) * PLOT if data != null else Vector2(PLOT, PLOT)


func cell() -> Vector2i:
	return Vector2i(floori(position.x / PLOT), 0)


## Where a vehicle rolls out (Hillville-local, feet): the middle of the door on the ground.
func door_position() -> Vector2:
	return position + Vector2(size_px().x * 0.5, 0)


func _ready() -> void:
	_tint()


func _tint() -> void:
	modulate = (GHOST_OK if ghost_ok else GHOST_BAD) if ghost else Color.WHITE


func _draw() -> void:
	if data == null:
		return
	var s := size_px()
	paint(self, data.id, Rect2(0, -s.y, s.x, s.y), door_open)


## The "clunk": grows out of the ground with an overshoot, a cue and a dust puff.
func unfold() -> Tween:
	scale = Vector2(1, 0.0)
	Audio.play("build_unfold")
	var hv := get_parent()
	while hv != null and not hv.has_method("puff"):
		hv = hv.get_parent()
	if hv != null:
		hv.puff(position + Vector2(size_px().x * 0.5, 0), Color(0.85, 0.75, 0.6), 14)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1, 1), UNFOLD_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


func open_door() -> Tween:
	Audio.play("garage_door")
	var t := create_tween()
	t.tween_property(self, "door_open", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	return t


## A small squash for picked-up / dropped buildings.
func bump() -> void:
	var t := create_tween()
	scale = Vector2(1.08, 0.9)
	t.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A red flash + shake for a bad plot (ghost only).
func flash_bad() -> void:
	var t := create_tween()
	modulate = Color(1.0, 0.1, 0.1, 0.85)
	var x := position.x
	t.tween_property(self, "position:x", x + 6, 0.04)
	t.tween_property(self, "position:x", x - 6, 0.06)
	t.tween_property(self, "position:x", x, 0.04)
	t.parallel().tween_property(self, "modulate", GHOST_BAD, 0.25)


# --- drawing (shared with the build book) ------------------------------------------------------

static func _c(col: Color, grey: bool) -> Color:
	if not grey:
		return col
	var l := col.get_luminance()
	return Color(l, l, l, col.a).lerp(Color(0.25, 0.23, 0.22, col.a), 0.45)


static func _box(ci: CanvasItem, r: Rect2, col: Color, grey: bool, w := 3.0) -> void:
	ci.draw_rect(r, _c(col, grey))
	ci.draw_rect(r, _c(OUTLINE, grey), false, w)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, grey: bool, w := 3.0) -> void:
	ci.draw_colored_polygon(pts, _c(col, grey))
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, _c(OUTLINE, grey), w, true)


## Draws building `id` filling rect `r` (its footprint; the ground is r.end.y). Used by Building
## and by the build book's cards. door: 0..1 (Garage roll-up). grey: the "can't afford" look.
static func paint(ci: CanvasItem, id: StringName, r: Rect2, door := 0.0, grey := false) -> void:
	var w := r.size.x
	var h := r.size.y
	var lw := clampf(w / 40.0, 1.5, 3.0)
	var x0 := r.position.x
	var gy := r.end.y
	match id:
		&"barn":
			var body := Rect2(x0 + w * 0.08, gy - h * 0.62, w * 0.84, h * 0.62)
			var roof := PackedVector2Array([Vector2(x0 + w * 0.02, body.position.y),
					Vector2(x0 + w * 0.5, gy - h * 0.98), Vector2(x0 + w * 0.98, body.position.y)])
			_poly(ci, roof, Color("8c2a22"), grey, lw)
			_box(ci, body, Color("c8372d"), grey, lw)
			var door_r := Rect2(x0 + w * 0.32, gy - h * 0.42, w * 0.36, h * 0.42)
			_box(ci, door_r, Color("a82c24"), grey, lw)
			var white := _c(Color("f6f1e7"), grey)
			ci.draw_rect(door_r.grow(-lw), white, false, lw * 1.2)
			ci.draw_line(door_r.position + Vector2(lw, lw), door_r.end - Vector2(lw, lw), white, lw * 1.2)
			ci.draw_line(Vector2(door_r.position.x + lw, door_r.end.y - lw),
					Vector2(door_r.end.x - lw, door_r.position.y + lw), white, lw * 1.2)
			# Hay loft window.
			_box(ci, Rect2(x0 + w * 0.43, gy - h * 0.72, w * 0.14, h * 0.12), Color("f2c94c"), grey, lw * 0.8)
		&"house":
			var body := Rect2(x0 + w * 0.12, gy - h * 0.58, w * 0.76, h * 0.58)
			var roof := PackedVector2Array([Vector2(x0 + w * 0.02, body.position.y),
					Vector2(x0 + w * 0.5, gy - h * 0.98), Vector2(x0 + w * 0.98, body.position.y)])
			_box(ci, Rect2(x0 + w * 0.66, gy - h * 0.92, w * 0.1, h * 0.2), Color("7d6a5a"), grey, lw)
			_poly(ci, roof, Color("3f6fb5"), grey, lw)
			_box(ci, body, Color("f2d7a0"), grey, lw)
			_box(ci, Rect2(x0 + w * 0.22, gy - h * 0.44, w * 0.2, h * 0.18), Color("8fd3f4"), grey, lw)
			_box(ci, Rect2(x0 + w * 0.55, gy - h * 0.36, w * 0.2, h * 0.36), Color("8a5a2b"), grey, lw)
		&"garage":
			var body := Rect2(x0 + w * 0.04, gy - h * 0.7, w * 0.92, h * 0.7)
			_box(ci, Rect2(x0, gy - h * 0.82, w, h * 0.14), Color("5d6670"), grey, lw)
			_box(ci, body, Color("c9ccd1"), grey, lw)
			var door_r := Rect2(x0 + w * 0.2, gy - h * 0.52, w * 0.6, h * 0.52)
			_box(ci, door_r, Color(0.08, 0.07, 0.08), grey, lw)
			var shut := door_r.size.y * (1.0 - clampf(door, 0.0, 1.0))
			if shut > 1.0:
				var panel := Rect2(door_r.position, Vector2(door_r.size.x, shut))
				_box(ci, panel, Color("f2994a"), grey, lw)
				var slats := int(shut / maxf(h * 0.09, 3.0))
				for i in slats:
					var y := panel.position.y + (i + 1) * h * 0.09
					ci.draw_line(Vector2(panel.position.x + lw, y), Vector2(panel.end.x - lw, y),
							_c(OUTLINE, grey), lw * 0.6)
		_:
			var body := Rect2(x0 + w * 0.1, gy - h * 0.7, w * 0.8, h * 0.7)
			var roof := PackedVector2Array([Vector2(x0, body.position.y), Vector2(x0 + w * 0.5, gy - h),
					Vector2(x0 + w, body.position.y)])
			_poly(ci, roof, Color("6fcf97"), grey, lw)
			_box(ci, body, Color("bdb2a6"), grey, lw)
			_box(ci, Rect2(x0 + w * 0.4, gy - h * 0.4, w * 0.2, h * 0.4), Color("8a5a2b"), grey, lw)
