## A placed (or ghost) building on Hillville's ground grid: a flat-colour placeholder drawn from
## its BuildingData id. Origin is the footprint's bottom-left corner on the ground (y up is
## negative), so the unfold scale tween grows it out of the ground. No faces.
class_name Building
extends Node2D

const PLOT := 48
const OUTLINE := Color(0.09, 0.07, 0.07)
const GHOST_OK := Color("3cdc5a")
const GHOST_BAD := Color("ff3b30")
const GHOST_ALPHA := 0.6
const UNFOLD_TIME := 0.45
const ART_ROOT := "res://assets/sprites/buildings/"
const LIT_ROOT := ART_ROOT

static var _windows: Dictionary = {}

var data: BuildingData
## Progress.buildings index while placed; -1 for a new ghost.
var index := -1
var ghost := false:
	set(v):
		ghost = v
		_tint()
var ghost_ok := true:
	set(v):
		if v != ghost_ok:
			ghost_ok = v
			_tint()
## Sideways draw offset for the bad-plot shake (position belongs to the grid snap).
var wobble := 0.0:
	set(v):
		wobble = v
		queue_redraw()
var _lights := 0.0
## 0..1: how much of the building stands, from the ground up (a restored ruin rebuilds plank by
## plank). 1 = all of it.
var reveal := 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		queue_redraw()
var _glow: Node2D
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
	if data != null and has_art(data.id) and SpriteArt.has("buildings/%s_lit.png" % data.id):
		_glow = Node2D.new()
		_glow.name = "WindowGlow"
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		_glow.draw.connect(_draw_windows)
		add_child(_glow)


func _process(_delta: float) -> void:
	var l := current_lights() if not ghost else 0.0
	if not is_equal_approx(l, _lights):
		_lights = l
		queue_redraw()
		if _glow:
			_glow.queue_redraw()


## TimeOfDay.lights() (0 when the autoload is not there).
static func current_lights() -> float:
	var tod: Node = Engine.get_main_loop().root.get_node_or_null(^"TimeOfDay") if Engine.get_main_loop() is SceneTree else null
	return float(tod.call("lights")) if tod != null and tod.has_method("lights") else 0.0


func _draw_windows() -> void:
	if ghost or _lights <= 0.02 or data == null:
		return
	var s := size_px()
	paint_glow(_glow, data.id, Rect2(0, -s.y, s.x, s.y), door_open, _lights)


func _tint() -> void:
	modulate = Color(1, 1, 1, GHOST_ALPHA) if ghost else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var s := size_px()
	draw_set_transform(Vector2(wobble, 0))
	var c := GHOST_OK if ghost_ok else GHOST_BAD
	var art := has_art(data.id)
	if ghost and art:
		# The sprite itself, green when the plot is clear and red when not, plus a bar on the ground.
		var r := Rect2(0, -s.y, s.x, s.y)
		paint_art(self, data.id, r, door_open, false, Color.WHITE.lerp(c, 0.65))
		draw_rect(Rect2(0, -3, s.x, 8), c)
		return
	if reveal < 1.0 and art:
		_paint_part(Rect2(0, -s.y, s.x, s.y))
		return
	paint(self, data.id, Rect2(0, -s.y, s.x, s.y), door_open)
	if ghost:
		# Green when the plot is clear, red when not: a wash, a frame and a bar on the ground.
		draw_rect(Rect2(0, -s.y, s.x, s.y), Color(c, 0.3))
		draw_rect(Rect2(2, -s.y + 2, s.x - 4, s.y - 4), c, false, 4.0)
		draw_rect(Rect2(0, -3, s.x, 8), c)
	elif art and _lights > 0.0:
		paint_lit(self, data.id, Rect2(0, -s.y, s.x, s.y), door_open, _lights)


## The bottom `reveal` of the sprite (whole planks: 6 px rows of the sheet).
func _paint_part(r: Rect2) -> void:
	var tex: Texture2D = SpriteArt.texture("buildings/%s.png" % data.id)
	var src := _sheet_rect(data.id, tex, door_open)
	var rows := ceili(src.size.y * reveal / 6.0) * 6.0
	rows = minf(rows, src.size.y)
	if rows <= 0.0:
		return
	var k := r.size.y / src.size.y
	var part := Rect2(src.position.x, src.end.y - rows, src.size.x, rows)
	draw_texture_rect_region(tex, Rect2(Vector2(r.position.x, r.end.y - rows * k).round(), Vector2(r.size.x, rows * k)), part)


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
	modulate = Color(1.0, 0.3, 0.3, 1.0)
	t.tween_property(self, "wobble", 7.0, 0.04)
	t.tween_property(self, "wobble", -7.0, 0.07)
	t.tween_property(self, "wobble", 4.0, 0.06)
	t.tween_property(self, "wobble", 0.0, 0.05)
	t.parallel().tween_property(self, "modulate", Color(1, 1, 1, GHOST_ALPHA), 0.25)


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
	if has_art(id):
		paint_art(ci, id, r, door, grey)
		return
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


# --- sprites -----------------------------------------------------------------------------------

static func has_art(id: StringName) -> bool:
	return SpriteArt.has("buildings/%s.png" % id)


## The Garage door frame (0 shut, 1 half, 2 open) for a door value 0..1.
static func door_frame(door: float) -> int:
	return 0 if door < 0.25 else (1 if door < 0.75 else 2)


static func _sheet_rect(id: StringName, tex: Texture2D, door: float) -> Rect2:
	var fs := SheetSprite.frame_size("buildings/%s.png" % id)
	var frames := maxi(1, tex.get_width() / fs.x)
	var f := door_frame(door) if frames > 1 else 0
	return Rect2(f * fs.x, 0, fs.x, fs.y)


## The building's sprite filling `r` (its footprint; exactly footprint size on the ground).
static func paint_art(ci: CanvasItem, id: StringName, r: Rect2, door := 0.0, grey := false, mod := Color.WHITE) -> void:
	var tex: Texture2D = SpriteArt.texture("buildings/%s.png" % id)
	if grey:
		mod = Color(0.55, 0.53, 0.52, 1.0)
	ci.draw_texture_rect_region(tex, Rect2(r.position.round(), r.size), _sheet_rect(id, tex, door), mod)


## The lit-windows overlay faded in by `amount` (0..1).
static func paint_lit(ci: CanvasItem, id: StringName, r: Rect2, door: float, amount: float) -> void:
	var tex: Texture2D = SpriteArt.texture("buildings/%s_lit.png" % id)
	if tex == null:
		return
	ci.draw_texture_rect_region(tex, Rect2(r.position.round(), r.size), _sheet_rect(id, tex, door), Color(1, 1, 1, amount))


## Soft additive window glows: one fx/window.png per lit window (clusters of the _lit pixels).
static func paint_glow(ci: CanvasItem, id: StringName, r: Rect2, door: float, amount: float) -> void:
	var tex: Texture2D = SpriteArt.texture("buildings/%s_lit.png" % id)
	var soft: Texture2D = SpriteArt.texture("fx/window.png")
	if tex == null or soft == null:
		return
	var f := _sheet_rect(id, tex, door)
	for b: Rect2 in window_boxes(id, tex, f):
		var c := r.position + b.get_center()
		var sz := b.size + Vector2(10, 10)
		ci.draw_texture_rect(soft, Rect2((c - sz * 0.5).round(), sz), false, Color(1, 0.85, 0.5, 0.55 * amount))


## Bounding boxes of the lit pixel clusters in one frame of a _lit sheet (cached).
static func window_boxes(id: StringName, tex: Texture2D, frame: Rect2) -> Array:
	var key := "%s:%d" % [id, int(frame.position.x)]
	if _windows.has(key):
		return _windows[key]
	var img := tex.get_image()
	var seen := {}
	var out: Array = []
	for y in range(int(frame.position.y), int(frame.end.y)):
		for x in range(int(frame.position.x), int(frame.end.x)):
			var p := Vector2i(x, y)
			if seen.has(p) or img.get_pixelv(p).a < 0.3:
				continue
			var lo := p
			var hi := p
			var stack: Array[Vector2i] = [p]
			seen[p] = true
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
				hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = q + o
					if n.x < frame.position.x or n.y < frame.position.y or n.x >= frame.end.x or n.y >= frame.end.y:
						continue
					if not seen.has(n) and img.get_pixelv(n).a >= 0.3:
						seen[n] = true
						stack.append(n)
			var box := Rect2(Vector2(lo) - frame.position, Vector2(hi - lo + Vector2i.ONE))
			if box.size.x * box.size.y >= 4.0:
				out.append(box)
	_windows[key] = out
	return out
