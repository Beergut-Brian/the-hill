## The big question that needs a hold: New Hill ("Start a new hill?") and Restore last hill. Same
## card as the leave question (ConfirmDialog), plus a picture of the hill and its summary chips
## (HillSummary). Two bars, "Keep" focused first; the other bar only goes off after A is *held*
## HOLD_TIME s, with a ring filling round the A glyph and ticks rising. Let go early: it drains.
## B (or A on Keep) cancels. Never a one-press wipe. Built in code; owners call handle() per frame.
class_name HoldConfirm
extends Control

signal chosen(confirmed: bool)

enum Choice { CANCEL, CONFIRM }

const HOLD_TIME := 1.0
const TICK_EVERY := 0.125
const CARD := Rect2(400, 140, 1120, 800)

var active := false
var focus := Choice.CANCEL
## 0..1 of the hold.
var progress := 0.0
## Screenshots: the hold stays where it is.
var freeze := false

var heading := "START A NEW HILL?"
var body := "Your current hill is kept as a backup."
var summary := {}
## The hint under the bars.
var hint := "[lr] Choose    Hold [a] to start    [b] Back"

var _armed := false
var _ticks := 0
var _tw: Tween
var _card: Panel
var _heading: Label
var _picture: TextureRect
var _info: Control
var _body: Label
var _ring: Control
var _buttons: Array = []


func _init() -> void:
	name = "HoldConfirm"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.04, 0.03, 0.1, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = Panel.new()
	_card.name = "Card"
	_card.position = CARD.position
	_card.size = CARD.size
	_card.pivot_offset = CARD.size * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_heading = Label.new()
	_heading.name = "Heading"
	_heading.position = Vector2(60, 24)
	_heading.size = Vector2(1000, 120)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(_heading)
	_info = Control.new()
	_info.name = "Summary"
	_info.position = Vector2(60, 150)
	_info.size = Vector2(1000, 300)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.draw.connect(_draw_info)
	_card.add_child(_info)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.position = Vector2(80, 166)
	_picture.size = Vector2(480, 270)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_card.add_child(_picture)
	_body = Label.new()
	_body.name = "Body"
	_body.position = Vector2(60, 462)
	_body.size = Vector2(1000, 60)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(_body)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.position = Vector2(90, 556)
	row.size = Vector2(940, 110)
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	for n in ["Cancel", "Confirm"]:
		var b := MenuItem.new()
		b.name = n
		b.bleed = MenuItem.Bleed.NONE
		b.height = 92.0
		b.height_focused = 106.0
		b.text_size = 50
		b.text_size_focused = 58
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_buttons.append(b)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.size = CARD.size
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_card.add_child(_ring)
	var line := HintLine.new()
	line.name = "Hint"
	line.position = Vector2(40, 712)
	line.size = Vector2(1040, 44)
	line.color = Color(UiStyle.CREAM, 0.78)
	_card.add_child(line)
	set_texts("Keep this hill", "New hill")


func _ready() -> void:
	UiStyle.showtime_card(_card)
	_body.theme_type_variation = &"BodyLabel"
	_body.add_theme_color_override("font_color", Color(UiStyle.CREAM, 0.88))
	_body.add_theme_font_size_override("font_size", 38)


func set_texts(cancel: String, confirm: String) -> void:
	_buttons[Choice.CANCEL].text = cancel
	_buttons[Choice.CONFIRM].text = confirm


## Opens the question. picture: a small view of the hill (null: the summary takes the card).
func open(what := {}, picture: Texture2D = null) -> void:
	summary = what
	_heading.text = heading
	UiStyle.style_title(_heading, 76, UiStyle.CREAM, 1000.0, UiStyle.INK_SHOW, 0)
	_body.text = body
	(_card.get_node("Hint") as HintLine).text = hint
	_picture.texture = picture
	_picture.visible = picture != null
	_info.queue_redraw()
	active = true
	visible = true
	_set_progress(0.0)
	_armed = false
	_set_focus(Choice.CANCEL, false)
	UiSound.play("ui_confirm")
	if _tw:
		_tw.kill()
	if is_inside_tree():
		_tw = create_tween().set_parallel()
		_tw.tween_property(self, "modulate:a", 1.0, 0.16).from(0.0)
		_tw.tween_property(_card, "scale", Vector2.ONE, 0.24).from(Vector2.ONE * 0.92) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		MenuItem.slam_all(_buttons, 0.08, 0.06)


func dismiss() -> void:
	active = false
	visible = false
	_picture.texture = null
	_armed = false
	_set_progress(0.0)


## One frame of MenuInput.read(); the hold reads held A on every joined pad itself.
func handle(input: Dictionary, delta := -1.0) -> void:
	if not active:
		return
	if input.b != -1:
		choose(false)
		return
	var dir: int = input.move.x if input.move.x != 0 else input.move.y
	if dir != 0:
		move_focus(dir)
	if input.a != -1:
		press_a()
	if freeze:
		return
	hold_step(any_a_down(), delta if delta >= 0.0 else get_process_delta_time())


## A fresh press: on Keep it cancels; on the other bar it starts the hold (a press carried over
## from the menu behind never counts: only a press made while the question is up arms it).
func press_a() -> void:
	if not active:
		return
	if focus == Choice.CANCEL:
		choose(false)
		return
	_armed = true
	_buttons[Choice.CONFIRM].press()
	UiSound.play("ui_tick", 0.8)


## Feeds the hold one frame. Returns true when it completed (and chose).
func hold_step(down: bool, delta: float) -> bool:
	if not active:
		return false
	if not (_armed and down and focus == Choice.CONFIRM):
		if _armed and progress > 0.0:
			UiSound.play("ui_back", 0.8)   # let go early: it drains
		if progress > 0.0:
			_drain()
		_armed = false
		return false
	_set_progress(progress + delta / HOLD_TIME)
	while _ticks < int(progress * HOLD_TIME / TICK_EVERY):
		_ticks += 1
		UiSound.play("ui_tick", 0.8 + 0.7 * progress)
	if progress < 1.0:
		return false
	_armed = false
	choose(true)
	return true


func move_focus(dir: int) -> void:
	var to := MenuItem.step(_buttons, focus, dir) as Choice
	if to != focus:
		_armed = false
		_set_progress(0.0)
	_set_focus(to)


func choose(confirmed: bool) -> void:
	if not active:
		return
	_buttons[Choice.CONFIRM if confirmed else Choice.CANCEL].press()
	UiSound.play("ui_go" if confirmed else "ui_back")
	active = false
	_set_progress(0.0)
	_picture.texture = null   # the live view may go away now (a New Hill rebuilds the backdrop)
	if confirmed and is_inside_tree():
		# A last punch of the card before it goes.
		var tw := create_tween()
		tw.tween_property(_card, "scale", Vector2.ONE * 1.06, 0.07)
		tw.tween_property(self, "modulate:a", 0.0, 0.16)
		tw.tween_callback(func() -> void: visible = active)
	else:
		visible = false
	chosen.emit(confirmed)


## Is A held on any joined pad (or the keyboard)?
static func any_a_down() -> bool:
	for p in Players.active_players():
		if Input.is_action_pressed(Players.action(p, "action")):
			return true
	return false


func _drain() -> void:
	var from := progress
	_ticks = 0
	if not is_inside_tree():
		_set_progress(0.0)
		return
	var tw := create_tween()
	tw.tween_method(_set_progress, from, 0.0, 0.18)


func _set_progress(v: float) -> void:
	progress = clampf(v, 0.0, 1.0)
	if progress == 0.0:
		_ticks = 0
	if _buttons.size() > Choice.CONFIRM:
		_buttons[Choice.CONFIRM].progress = progress
	if _ring:
		_ring.queue_redraw()


func _set_focus(to: Choice, sound := true) -> void:
	if sound:
		UiSound.play("ui_move")
	focus = to
	for i in _buttons.size():
		_buttons[i].focused = i == focus
	_ring.queue_redraw()


## The ring round the A glyph at the right end of the hold bar: fills as A is held.
func _draw_ring() -> void:
	var b: Control = _buttons[Choice.CONFIRM]
	var r := Rect2(b.position + b.get_parent().position, b.size)
	var c := Vector2(r.position.x + 50.0 + r.size.y * UiStyle.LEAN * 0.5, r.get_center().y)
	var on := focus == Choice.CONFIRM
	var rad := 40.0 * (1.0 + 0.08 * progress)
	_ring.draw_circle(c, rad + 7.0, Color(UiStyle.INK_SHOW, 0.9 if on else 0.5), true, -1.0, true)
	_ring.draw_arc(c, rad, 0.0, TAU, 48, Color(UiStyle.CREAM, 0.25), 9.0, true)
	if progress > 0.0:
		_ring.draw_arc(c, rad, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UiStyle.accent, 10.0, true)
	UiStyle.draw_glyph(_ring, c, 46.0, "a", 1.0 if on else 0.55)


## The picture's frame and the summary chips (buildings, deepest layer, treasures).
func _draw_info() -> void:
	var pic := _picture.visible
	if pic:
		var pr := Rect2(_picture.position - _info.position, _picture.size).grow(8.0)
		_info.draw_rect(pr, UiStyle.CREAM)
		_info.draw_rect(pr.grow(-4.0), UiStyle.INK_SHOW, false, 4.0)
	var x := 540.0 if pic else 250.0
	var lines := [
		["house", "%d building%s" % [summary.get("buildings", 0), "" if summary.get("buildings", 0) == 1 else "s"]],
		["layer", "Dug to %s" % summary.get("layer", "Topsoil")],
		["gem", "%d treasure%s" % [summary.get("treasures", 0), "" if summary.get("treasures", 0) == 1 else "s"]],
	]
	for i in lines.size():
		var cy := 40.0 + i * 92.0
		UiStyle.para(_info, Rect2(x, cy - 36.0, 440.0, 72.0), Color(UiStyle.INK_SHOW, 0.85))
		_icon(Vector2(x + 52.0, cy), lines[i][0])
		UiStyle.draw_show(_info, Vector2(x + 100.0, cy), String(lines[i][1]).to_upper(), 40, UiStyle.CREAM)


func _icon(c: Vector2, kind: String) -> void:
	match kind:
		"house":
			_info.draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -2), c + Vector2(0, -26),
					c + Vector2(24, -2)]), UiStyle.accent)
			_info.draw_rect(Rect2(c + Vector2(-18, -2), Vector2(36, 26)), UiStyle.CREAM)
			_info.draw_rect(Rect2(c + Vector2(-6, 8), Vector2(12, 16)), UiStyle.INK_SHOW)
		"layer":
			var col: Color = summary.get("layer_color", Color("8a5a2b"))
			for k in 3:
				_info.draw_rect(Rect2(c + Vector2(-24, -24 + k * 17), Vector2(48, 14)), col.darkened(0.25 * k))
		"gem":
			_info.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(22, -6),
					c + Vector2(0, 26), c + Vector2(-22, -6)]), Color("6fd6ff"))
			_info.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(8, -6),
					c + Vector2(-8, -6)]), Color(1, 1, 1, 0.7))
