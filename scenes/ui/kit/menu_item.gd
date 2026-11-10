## One menu entry: a slanted Showtime bar with a text label (drawn in capitals). The menu that owns
## it moves the focus and presses it; this draws. Unfocused: a bar in the skin's deep colour with
## cream text. Focused: the only light thing on screen, a cream bar that grows past its mark and
## settles, with the accent block and chevrons. Pressed: it flashes the accent and squashes, then
## springs back. `slam_in()` slams it in from off screen. `progress` (0..1) fills it (hold to start).
## Bars lean like everything else and step back along the lean as they go down the list.
class_name MenuItem
extends Control

## Where the bar runs off screen: RIGHT for menus on the right wedge (the lobby), LEFT for the pause
## menu, NONE for a bar that sits inside its own card (the leave question).
enum Bleed { NONE, LEFT, RIGHT }

@export var text := "Item":
	set(v):
		text = v
		queue_redraw()
@export var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
@export var bleed := Bleed.RIGHT
@export var height := 104.0
@export var height_focused := 150.0
@export var text_size := 70
@export var text_size_focused := 116
## A tag on the focused bar, e.g. "2P", with a dot per player in chip_players.
var chip := "":
	set(v):
		chip = v
		queue_redraw()
var chip_players: Array = []

var focused := false:
	set(v):
		if v == focused:
			return
		focused = v
		_animate_focus()
var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

var _f := 0.0        # focus amount, 0..1 (overshoots on the way in)
var _press := 0.0    # press squash, 0..1
var _in := 1.0       # slam-in, 0 (off screen) .. 1 (home)
var _tw: Tween
var _tw_in: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(0, lerpf(height, height_focused, clampf(_f, 0.0, 1.15)))


## Next focusable index from `from` in direction dir (skips disabled; stays put at the ends).
static func step(items: Array, from: int, dir: int) -> int:
	var i := from + dir
	while i >= 0 and i < items.size():
		if not items[i].disabled:
			return i
		i += dir
	return from


## Slams a list of items in one after another.
static func slam_all(items: Array, delay := 0.0, gap := 0.05) -> void:
	for i in items.size():
		items[i].slam_in(delay + gap * i)


func press() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_method(_set_press, 0.0, 1.0, 0.06)
	tw.tween_method(_set_press, 1.0, 0.0, 0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## In from off screen, past its mark, and back.
func slam_in(delay := 0.0) -> void:
	if not is_inside_tree():
		return
	if _tw_in:
		_tw_in.kill()
	_in = 0.0
	queue_redraw()
	_tw_in = create_tween()
	_tw_in.tween_interval(delay)
	_tw_in.tween_method(_set_in, 0.0, 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_focus() -> void:
	if _tw:
		_tw.kill()
	if not is_inside_tree():
		_set_f(1.0 if focused else 0.0)
		return
	_tw = create_tween()
	_tw.tween_method(_set_f, _f, 1.0 if focused else 0.0, 0.22 if focused else 0.14) \
			.set_trans(Tween.TRANS_BACK if focused else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_f(v: float) -> void:
	_f = v
	update_minimum_size()
	queue_redraw()


func _set_press(v: float) -> void:
	_press = v
	queue_redraw()


func _set_in(v: float) -> void:
	_in = v
	queue_redraw()


## How far this bar steps back along the lean (bars further down sit further left).
func _shift() -> float:
	return -position.y * UiStyle.LEAN if get_parent() is Container else 0.0


## The bar's rectangle in local coordinates, before the press squash.
func bar_rect() -> Rect2:
	var k := _f
	var off := (1.0 - _in) * 1100.0
	var sh := _shift()
	match bleed:
		Bleed.RIGHT:
			var x := 100.0 - 70.0 * k + sh + off
			return Rect2(x, 0, size.x - x + 600.0, size.y)
		Bleed.LEFT:
			var right := size.x * (0.84 + 0.16 * k) + sh - off
			return Rect2(-700.0, 0, right + 700.0, size.y)
	return Rect2(0, 0, size.x, size.y)


func _draw() -> void:
	var r := _draw_frame()
	var k := clampf(_f, 0.0, 1.0)
	var col := UiStyle.CREAM.lerp(UiStyle.INK_SHOW, k)
	if _press > 0.5:
		col = UiStyle.INK_SHOW
	if disabled:
		col = Color(UiStyle.CREAM, 0.35)
	var fs := int(lerpf(text_size, text_size_focused, clampf(_f, 0.0, 1.1)))
	var label := text.to_upper()
	var cy := r.get_center().y
	match bleed:
		Bleed.RIGHT:
			var tx := r.position.x + lerpf(90.0, 186.0, k) + 30.0 * (_f - k)
			var room := size.x - tx - UiStyle.SAFE.x * 0.5 - (_chip_width() + 60.0 if chip != "" and k > 0.5 else 0.0)
			var w := UiStyle.draw_show(self, Vector2(tx, cy), label, _fit(label, fs, room), col)
			if chip != "" and k > 0.5:
				_draw_chip(Vector2(tx + w + 60.0, cy), k)
		Bleed.LEFT:
			var tx := maxf(r.position.x, 0.0) + 64.0
			UiStyle.draw_show(self, Vector2(tx, cy), label, _fit(label, fs, r.end.x - 132.0 * k - 30.0 - tx), col)
		_:
			UiStyle.draw_show(self, Vector2(r.get_center().x + 30.0 * k, cy), label, _fit(label, fs, r.size.x - 100.0 * k - 40.0), col, 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Bar, shadow, accent block, chevrons and progress, in the press squash. Returns the bar rect.
## Leaves the squash transform set so the caller's text squashes with it.
func _draw_frame() -> Rect2:
	var r := bar_rect()
	var k := clampf(_f, 0.0, 1.0)
	var c := r.get_center()
	if bleed == Bleed.RIGHT:
		c.x = r.position.x + 300.0
	elif bleed == Bleed.LEFT:
		c.x = r.end.x - 300.0
	var s := Vector2(1.0 + 0.05 * _press, 1.0 - 0.2 * _press)
	draw_set_transform(c - c * s, 0.0, s)
	var flash := _press > 0.5
	var fill := UiStyle.bar_color().lerp(UiStyle.CREAM, k)
	if flash:
		fill = UiStyle.accent
	if disabled:
		fill = Color(UiStyle.bar_color(), 0.5)
	var shadow := Color(UiStyle.INK_SHOW, lerpf(0.6, 1.0, k))
	UiStyle.slab(self, r, fill, shadow, lerpf(9.0, 15.0, k) * (1.0 - 0.5 * _press))
	if progress > 0.0:
		var pw := r.size.x * progress
		if bleed == Bleed.RIGHT:
			pw = (size.x - r.position.x) * progress
		UiStyle.para(self, Rect2(r.position, Vector2(pw, r.size.y)), Color(UiStyle.accent, 0.9))
	if k > 0.02:
		var bw := 132.0 if bleed != Bleed.NONE else 92.0
		var block := Rect2(r.position, Vector2(bw, r.size.y))
		if bleed == Bleed.LEFT:
			block.position.x = r.end.x - bw
		var bc := UiStyle.CREAM if flash else UiStyle.accent
		# The block grows out of the bar's edge as focus arrives.
		if bleed == Bleed.LEFT:
			block = Rect2(block.end.x - bw * k, block.position.y, bw * k, block.size.y)
		else:
			block.size.x = bw * k
		UiStyle.para(self, block, bc)
		var ch := minf(r.size.y * 0.42, 68.0)
		var cc := block.get_center() + Vector2(r.size.y * UiStyle.LEAN * 0.0, 0)
		draw_set_transform(c - c * s, 0.0, s)
		UiStyle.chevrons(self, cc, ch * k, Color(UiStyle.INK_SHOW, k), false)
	return r


## The font size that fits `label` in `room` px (never bigger than fs).
func _fit(label: String, fs: int, room: float) -> int:
	var w := UiStyle.show_width(label, fs)
	return fs if w <= room or w <= 0.0 else maxi(int(fs * room / w), 24)


func _chip_width() -> float:
	return 70.0 + 38.0 * chip_players.size() + UiStyle.show_width(chip, 44)


func _draw_chip(at: Vector2, k: float) -> void:
	var w := _chip_width()
	var r := Rect2(at.x, at.y - 34.0, w, 68.0)
	UiStyle.para(self, r, Color(UiStyle.INK_SHOW, k))
	var x := r.position.x + 40.0
	for p in chip_players:
		draw_circle(Vector2(x, at.y), 15.0, UiStyle.player_color(p), true, -1.0, true)
		x += 38.0
	UiStyle.draw_show(self, Vector2(x + 2.0, at.y), chip, 44, Color(UiStyle.CREAM, k))
