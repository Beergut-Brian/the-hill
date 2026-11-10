## The Showtime transition: three leaning stripes (cream, green, red) chase across the screen pulling
## the skin's deep colour behind them, hold on an optional "ROUND 1" card, then wipe off the other
## side. The lobby plays it into round 1; a game can play it anywhere:
##   ShowtimeWipe.run(func(): load_next_level(), "ROUND 2", "CHUCK KICKS FIRST", UiStyle.player_color(1))
## on_cover runs once the screen is fully covered (swap scenes there). Sounds: ui_wipe, ui_card.
class_name ShowtimeWipe
extends CanvasLayer

signal covered()
signal finished()

const IN_TIME := 0.42
const OUT_TIME := 0.5
const HOLD := 0.14
const CARD_HOLD := 0.95
const LEAN_PX := 330.0

## 0..1 covering, 1..2 uncovering. -1: idle (hidden).
var t := -1.0:
	set(v):
		t = v
		_canvas.queue_redraw()
var title := ""
var subtitle := ""
var subtitle_color := Color.WHITE

var _canvas := Control.new()
var _card := 0.0
var _tw: Tween


## The shared wipe under the scene tree root (made on first use), playing.
static func run(on_cover := Callable(), card_title := "", card_subtitle := "",
		card_color := Color(0, 0, 0, 0)) -> ShowtimeWipe:
	var tree := Engine.get_main_loop() as SceneTree
	var w := tree.root.get_node_or_null("ShowtimeWipe") as ShowtimeWipe
	if w == null:
		w = ShowtimeWipe.new()
		w.name = "ShowtimeWipe"
		tree.root.add_child(w)
	w.play(on_cover, card_title, card_subtitle, card_color)
	return w


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_wipe)
	add_child(_canvas)


func busy() -> bool:
	return t >= 0.0


func play(on_cover := Callable(), card_title := "", card_subtitle := "", card_color := Color(0, 0, 0, 0)) -> void:
	title = card_title
	subtitle = card_subtitle
	subtitle_color = card_color if card_color.a > 0.0 else UiStyle.skin().accent2
	_card = 0.0
	if _tw:
		_tw.kill()
	UiSound.play("ui_wipe")
	t = 0.0
	_tw = create_tween()
	_tw.tween_property(self, "t", 1.0, IN_TIME).from(0.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(func() -> void:
		if on_cover.is_valid():
			on_cover.call()
		covered.emit())
	if title != "":
		_tw.tween_callback(func() -> void: UiSound.play("ui_card"))
		_tw.tween_method(_set_card, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_interval(CARD_HOLD - 0.3)
	else:
		_tw.tween_interval(HOLD)
	_tw.tween_callback(func() -> void: UiSound.play("ui_wipe", 1.15))
	_tw.tween_property(self, "t", 2.0, OUT_TIME).from(1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(func() -> void:
		t = -1.0
		finished.emit())


## Jump to a moment, for screenshots and tests: 0..1 in, 1..2 out; card 0..1.
func pose(at: float, card := 0.0) -> void:
	if _tw:
		_tw.kill()
	_card = card
	t = at


func _set_card(v: float) -> void:
	_card = v
	_canvas.queue_redraw()


func _stripes() -> Array:
	return [[UiStyle.CREAM, 44.0], [UiStyle.player_color(0), 120.0], [UiStyle.player_color(1), 120.0]]


func _band(x: float, w: float, col: Color, h: float) -> void:
	# A leaning band whose bottom-right corner is at x.
	_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - w + LEAN_PX, 0), Vector2(x + LEAN_PX, 0),
			Vector2(x, h), Vector2(x - w, h)]), col)


func _draw_wipe() -> void:
	if t < 0.0:
		return
	var view := _canvas.size
	var span := view.x + LEAN_PX + 700.0
	var deep := UiStyle.deep()
	if t <= 1.0:
		var front := -LEAN_PX + span * t
		var edge := front
		for sp: Array in _stripes():
			_band(edge, sp[1], sp[0], view.y)
			edge -= sp[1]
		_band(edge, edge + LEAN_PX + 300.0, deep, view.y)
	else:
		var tail := -LEAN_PX - 300.0 + span * (t - 1.0)
		_band(view.x + LEAN_PX + 10.0, view.x + LEAN_PX + 10.0 - tail, deep, view.y)
		var e := tail
		var st := _stripes()
		st.reverse()
		for sp: Array in st:
			_band(e, sp[1], sp[0], view.y)
			e -= sp[1]
	if title != "" and _card > 0.0 and t <= 1.4:
		var a := clampf(1.0 - (t - 1.0) * 4.0, 0.0, 1.0) if t > 1.0 else 1.0
		var c := view * 0.5 + Vector2(0, -40)
		var s := lerpf(1.4, 1.0, _card)
		_canvas.draw_set_transform(c, deg_to_rad(-5.0), Vector2(s, s))
		var acc := Color(UiStyle.accent, a)
		var ink := Color(UiStyle.INK_SHOW, a)
		UiStyle.draw_show(_canvas, Vector2(10, 12), title, 260, ink, 1, 40, ink)
		UiStyle.draw_show(_canvas, Vector2.ZERO, title, 260, acc, 1, 34, ink)
		if subtitle != "":
			var w := UiStyle.show_width(subtitle, 56) + 110.0
			var r := Rect2(-w * 0.5, 120, w, 88)
			UiStyle.slab(_canvas, r, Color(subtitle_color, a), ink, 10.0)
			UiStyle.draw_show(_canvas, r.get_center() + Vector2(8, 0), subtitle, 56, Color(1, 1, 1, a), 1)
		_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
