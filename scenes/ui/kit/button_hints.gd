## A small per-player panel of context button hints (docs/ui.md "Button hints"): one row per
## button that matters right now, a controller glyph and a picture of what it does. No words, so
## it fits the kid rules on gameplay screens. Rows pop in when the context changes and the panel
## shrinks / grows to fit; an empty list hides it.
##   var hints := preload("res://scenes/ui/kit/button_hints.tscn").instantiate()
##   hints.show_hints([{"button": "a", "icon": &"dig"}, {"button": "b", "icon": &"jump"}])
## Buttons: "a", "b", "x", "y" (UiStyle glyphs, Xbox layout). Icons: the built-ins below
## (dig, jump, enter, exit, ride, book, scoop, tip, climb, horn, ok, back, hook, drill) or your own
## with ButtonHints.register_icon(&"name", func(ci: CanvasItem, r: Rect2, a: float) -> void: ...).
## `accent` tints the panel edge (a player's colour). `align_right` grows the rows leftward.
class_name ButtonHints
extends Control

const INK := Color(0.07, 0.06, 0.09)
const CREAM := Color("fff5e6")
const ORDER := ["a", "b", "x", "y"]

## Glyph height in px; the picture is the same size.
@export var glyph_height := 44.0
@export var accent := Color("3cc24a")
@export var align_right := false

static var _icons := {}

var _hints: Array = []
var _pop := {}       # button -> 1..0 (a row that just changed)
var _shown := 0.0    # panel fade
var _t := 0.0


static func register_icon(id: StringName, draw: Callable) -> void:
	_icons[id] = draw


## The hint list now (sorted A, B, X, Y). Same list again: nothing happens.
func hints() -> Array:
	return _hints


## Shows `list` ([{button, icon, dim?}]); rows whose picture changed pop. Returns true if changed.
func show_hints(list: Array) -> bool:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ORDER.find(a.button) < ORDER.find(b.button))
	if _same(sorted, _hints):
		return false
	var before := {}
	for h in _hints:
		before[h.button] = h
	for h in sorted:
		var old: Dictionary = before.get(h.button, {})
		if old.is_empty() or old.icon != h.icon:
			_pop[h.button] = 1.0
	_hints = sorted
	queue_redraw()
	return true


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].button != b[i].button or a[i].icon != b[i].icon or bool(a[i].get("dim", false)) != bool(b[i].get("dim", false)):
			return false
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	for k in _pop.keys():
		_pop[k] = move_toward(_pop[k], 0.0, delta * 4.0)
	_shown = move_toward(_shown, 1.0 if not _hints.is_empty() else 0.0, delta * 8.0)
	queue_redraw()


## The panel's size for the current rows (px).
func panel_size() -> Vector2:
	var row := glyph_height + 10.0
	return Vector2(glyph_height * 2.0 + 34.0, row * _hints.size() + 14.0)


func _draw() -> void:
	if _hints.is_empty() or _shown <= 0.0:
		return
	var ps := panel_size()
	var origin := Vector2(size.x - ps.x if align_right else 0.0, size.y - ps.y)
	var panel := Rect2(origin, ps)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.72 * _shown)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(accent, 0.9 * _shown)
	sb.set_border_width_all(3)
	sb.anti_aliasing = true
	draw_style_box(sb, panel)
	var y := panel.position.y + 7.0
	for h in _hints:
		var pop: float = _pop.get(h.button, 0.0)
		var grow := 1.0 + 0.35 * sin(pop * PI)
		var a := _shown * (0.4 if h.get("dim", false) else 1.0)
		var gh := glyph_height * grow
		var c := Vector2(panel.position.x + 12.0 + glyph_height * 0.5, y + glyph_height * 0.5 + 5.0)
		draw_button(self, c, gh, h.button, a, pop)
		var ir := Rect2(c + Vector2(glyph_height * 0.5 + 10.0, -glyph_height * 0.5), Vector2(glyph_height, glyph_height))
		ir = ir.grow((grow - 1.0) * glyph_height * 0.5)
		draw_icon(self, h.icon, ir, a)
		y += glyph_height + 10.0


## A glyph with a dark ring (reads on dirt, sky and menus); `ring` 0..1 adds a gold halo.
static func draw_button(ci: CanvasItem, c: Vector2, h: float, tok: String, alpha := 1.0, ring := 0.0) -> void:
	if ring > 0.0:
		ci.draw_circle(c, h * 0.5 + 3.0 + ring * 4.0, Color(1.0, 0.82, 0.25, alpha * ring * 0.8), true, -1.0, true)
	ci.draw_circle(c, h * 0.5 + 2.5, Color(INK, alpha), true, -1.0, true)
	UiStyle.draw_glyph(ci, c, h, tok, alpha)


## Draws picture `id` in `r` (a registered one first, else a built-in, else a dot).
static func draw_icon(ci: CanvasItem, id: StringName, r: Rect2, alpha := 1.0) -> void:
	if _icons.has(id):
		(_icons[id] as Callable).call(ci, r, alpha)
		return
	var c := r.get_center()
	var s := r.size.x / 44.0
	var ink := Color(INK, alpha)
	var cream := Color(CREAM, alpha)
	var gold := Color(1.0, 0.82, 0.25, alpha)
	var dirt := Color(0.64, 0.44, 0.26, alpha)
	var w := 3.0 * s
	match id:
		&"dig":
			# A shovel biting into a block.
			ci.draw_rect(Rect2(c + Vector2(-4, 6) * s, Vector2(18, 12) * s), dirt)
			ci.draw_line(c + Vector2(-14, -16) * s, c + Vector2(2, 2) * s, ink, 6.0 * s)
			ci.draw_line(c + Vector2(-14, -16) * s, c + Vector2(2, 2) * s, Color(0.66, 0.44, 0.24, alpha), 3.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -2) * s, c + Vector2(8, 4) * s, c + Vector2(6, 12) * s, c + Vector2(-4, 6) * s]), cream)
		&"jump":
			ci.draw_line(c + Vector2(-16, 16) * s, c + Vector2(16, 16) * s, cream, w)
			_arrow(ci, c + Vector2(0, 10) * s, c + Vector2(0, -16) * s, cream, s)
		&"climb":
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-16 + i * 11, 8 - i * 9) * s, Vector2(11, 8 + i * 9) * s), dirt)
			_arrow(ci, c + Vector2(-14, 2) * s, c + Vector2(10, -18) * s, cream, s)
		&"enter", &"exit":
			# A little person, a little vehicle and a big arrow: toward the vehicle = get in,
			# away from it = get out.
			_vehicle(ci, c + Vector2(8, 8) * s, s * 0.85, alpha)
			ci.draw_circle(c + Vector2(-16, 2) * s, 4.0 * s, cream)
			ci.draw_rect(Rect2(c + Vector2(-20, 6) * s, Vector2(8, 10) * s), cream)
			if id == &"enter":
				_arrow(ci, c + Vector2(-18, -12) * s, c + Vector2(4, -12) * s, gold, s)
			else:
				_arrow(ci, c + Vector2(6, -12) * s, c + Vector2(-16, -12) * s, gold, s)
		&"ride":
			# The cage with up and down arrows.
			var cage := Rect2(c + Vector2(-9, -9) * s, Vector2(18, 20) * s)
			ci.draw_rect(cage, ink)
			ci.draw_rect(cage.grow(-2.0 * s), Color(gold, alpha * 0.25))
			ci.draw_rect(cage, gold, false, 2.0 * s)
			ci.draw_line(c + Vector2(0, -20) * s, c + Vector2(0, -9) * s, cream, 2.0 * s)
			_arrow(ci, c + Vector2(15, 6) * s, c + Vector2(15, -16) * s, cream, s * 0.8)
			_arrow(ci, c + Vector2(-15, -14) * s, c + Vector2(-15, 10) * s, cream, s * 0.8)
		&"book":
			var l := PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(-18, -14) * s, c + Vector2(-18, 12) * s, c + Vector2(0, 16) * s])
			var rr := PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(18, -14) * s, c + Vector2(18, 12) * s, c + Vector2(0, 16) * s])
			ci.draw_colored_polygon(l, cream)
			ci.draw_colored_polygon(rr, cream)
			ci.draw_line(c + Vector2(0, -10) * s, c + Vector2(0, 16) * s, ink, 2.0 * s)
			ci.draw_rect(Rect2(c + Vector2(4, -6) * s, Vector2(10, 8) * s), Color(0.9, 0.36, 0.3, alpha))
			ci.draw_rect(Rect2(c + Vector2(-14, -6) * s, Vector2(10, 8) * s), Color(0.35, 0.6, 0.9, alpha))
		&"scoop":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -4) * s, c + Vector2(12, -4) * s, c + Vector2(6, 12) * s, c + Vector2(-12, 12) * s]), gold)
			for i in 3:
				ci.draw_circle(c + Vector2(-8 + i * 7, -8) * s, 4.0 * s, dirt)
		&"tip":
			ci.draw_set_transform(c, -0.5, Vector2.ONE)
			ci.draw_rect(Rect2(Vector2(-16, -8) * s, Vector2(26, 12) * s), Color(0.3, 0.55, 0.9, alpha))
			ci.draw_set_transform(Vector2.ZERO)
			for i in 3:
				ci.draw_circle(c + Vector2(12, 4 + i * 6) * s, 3.5 * s, dirt)
		&"hook":
			ci.draw_line(c + Vector2(0, -18) * s, c + Vector2(0, 2) * s, cream, 2.0 * s)
			ci.draw_arc(c + Vector2(-4, 6) * s, 6.0 * s, 0.0, PI, 10, gold, 3.0 * s)
		&"drill":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -14) * s, c + Vector2(10, -14) * s, c + Vector2(0, 16) * s]), Color(0.6, 0.45, 0.85, alpha))
			for i in 3:
				ci.draw_line(c + Vector2(-7 + i * 2, -8 + i * 8) * s, c + Vector2(7 - i * 2, -4 + i * 8) * s, ink, 2.0 * s)
		&"horn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -4) * s, c + Vector2(0, -12) * s, c + Vector2(0, 12) * s, c + Vector2(-14, 4) * s]), gold)
			for i in 2:
				ci.draw_arc(c + Vector2(2, 0) * s, (8.0 + i * 7.0) * s, -0.8, 0.8, 8, cream, 2.0 * s)
		&"ok":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-14, 0) * s, c + Vector2(-4, 10) * s, c + Vector2(14, -12) * s]), Color(0.45, 0.9, 0.4, alpha), 5.0 * s)
		&"back":
			ci.draw_arc(c + Vector2(2, 2) * s, 12.0 * s, -PI * 0.5, PI * 0.6, 12, cream, w)
			_arrow(ci, c + Vector2(4, -10) * s, c + Vector2(-14, -10) * s, cream, s * 0.8)
		_:
			ci.draw_circle(c, 6.0 * s, cream)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, s: float) -> void:
	ci.draw_line(from, to, col, 4.0 * s)
	var d := (to - from).normalized()
	var side := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([to + d * 6.0 * s, to - d * 4.0 * s + side * 7.0 * s, to - d * 4.0 * s - side * 7.0 * s]), col)


static func _vehicle(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-14, -6) * s, Vector2(26, 10) * s), Color(1.0, 0.75, 0.2, a))
	ci.draw_rect(Rect2(c + Vector2(-6, -16) * s, Vector2(12, 10) * s), Color(1.0, 0.75, 0.2, a))
	ci.draw_rect(Rect2(c + Vector2(-4, -14) * s, Vector2(8, 6) * s), Color(0.6, 0.85, 1.0, a))
	for x in [-8.0, 8.0]:
		ci.draw_circle(c + Vector2(x, 6) * s, 5.0 * s, Color(INK, a))
