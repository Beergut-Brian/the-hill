## One player's place on the Showtime stage: a spotlit podium in their colour with their character
## on it (the Character child), and a slanted name plate under it: "P1 JEFF". Empty: the podium is
## dim, the character a shadow, the plate says "[a] JOIN" and pulses. Joined: lit, "[a] Ready up".
## Ready: a READY! stamp slams onto the plate (GO! once the round is starting). `hold` (0..1) fills
## the plate while that player holds A on Play to start alone. Colours here only mean "this player".
extends Control

@export var player: int = 0
## Kept from the first kit: how opaque the podium and plate are (0..1).
@export_range(0.0, 1.0) var fill_alpha := 1.0:
	set(v):
		fill_alpha = v
		queue_redraw()

var joined := false:
	set(v):
		joined = v
		_light_to(1.0 if v else 0.0)
var readied := false:
	set(v):
		if v and not readied:
			_stamp_in()
		readied = v
		queue_redraw()
var hold := 0.0:
	set(v):
		hold = clampf(v, 0.0, 1.0)
		queue_redraw()
## The round is starting: the stamp says GO!.
var go := false:
	set(v):
		go = v
		queue_redraw()

const PODIUM_Y := 560.0
const PLATE_Y := 640.0

var _t := 0.0
var _light := 0.0
var _stamp := 1.0
var _tw_light: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	add_to_group("openjar_skinned")
	var slot := get_node_or_null("Character")
	if slot and slot.has_method("host"):
		slot.host(player)


func apply_skin() -> void:
	var slot := get_node_or_null("Character")
	if slot and slot.has_method("host"):
		slot.host(player)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not joined or hold > 0.0:
		queue_redraw()


func _light_to(v: float) -> void:
	if not is_inside_tree():
		_light = v
		queue_redraw()
		return
	if _tw_light:
		_tw_light.kill()
	_tw_light = create_tween()
	_tw_light.tween_method(func(x: float) -> void: _light = x; queue_redraw(), _light, v, 0.25)


func _stamp_in() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: _stamp = x; queue_redraw(), 0.0, 1.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ellipse(c: Vector2, r: Vector2, col: Color, n := 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
	return pts


func _draw() -> void:
	var pc := UiStyle.player_color(player)
	var deep := UiStyle.deep()
	var lit := _light
	var a := fill_alpha
	var col := deep.lightened(0.25).lerp(pc, lit)
	var cx := size.x * 0.5
	# Spotlight from above.
	var beam := Color(1, 1, 1, 0.05 + 0.1 * lit)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 70, -400), Vector2(cx + 70, -400),
			Vector2(cx + 235, PODIUM_Y), Vector2(cx - 235, PODIUM_Y)]), beam)
	# Podium: cream base ring, body, lit top.
	_ellipse(Vector2(cx, PLATE_Y - 18), Vector2(232, 50), Color(UiStyle.CREAM, 0.9 * a))
	var r := Vector2(200, 46)
	var body := PackedVector2Array([Vector2(cx - r.x, PODIUM_Y)])
	for i in 25:
		var an := PI * i / 24.0
		body.append(Vector2(cx - cos(an) * r.x * 1.06, PLATE_Y - 30 + sin(an) * r.y))
	body.append(Vector2(cx + r.x, PODIUM_Y))
	draw_colored_polygon(body, Color(col.darkened(0.12), a))
	_ellipse(Vector2(cx, PODIUM_Y), r, Color(col.lightened(0.3), a))
	_ellipse(Vector2(cx, PODIUM_Y), r * 0.78, Color(col.lightened(0.45 * lit + 0.1), a))
	# Name plate.
	var plate := Rect2(10, PLATE_Y, size.x - 70, 96)
	var plate_col := pc if joined else UiStyle.bar_color()
	UiStyle.slab(self, plate, Color(plate_col, a), UiStyle.INK_SHOW, 10.0)
	if hold > 0.0:
		UiStyle.para(self, Rect2(plate.position, Vector2(plate.size.x * hold, plate.size.y)), Color(UiStyle.CREAM, 0.55))
	var tag := Rect2(plate.position, Vector2(112, plate.size.y))
	UiStyle.para(self, tag, UiStyle.INK_SHOW)
	var cy := plate.get_center().y
	UiStyle.draw_show(self, Vector2(tag.position.x + 34, cy), "P%d" % (player + 1), 62, pc)
	var nx := tag.end.x + 24.0
	if not joined:
		var pulse := 0.65 + 0.35 * (0.5 + 0.5 * sin(_t * 3.0))
		UiStyle.draw_glyph(self, Vector2(nx + 26, cy), 46, "a", pulse)
		UiStyle.draw_show(self, Vector2(nx + 64, cy), "JOIN", 58, Color(UiStyle.CREAM, pulse))
	else:
		UiStyle.draw_show(self, Vector2(nx, cy), UiStyle.skin().player_name(player), 62, Color.WHITE)
	if hold > 0.0:
		_tag(Vector2(plate.position.x + 130, PLATE_Y - 40), "STARTING SOLO")
	elif joined and not readied:
		_tag(Vector2(plate.end.x - 230, PLATE_Y - 40), "[a] Ready up")
	if readied:
		_draw_stamp(Vector2(plate.end.x - 50, PLATE_Y - 14))


## A small dark tag above the plate.
func _tag(at: Vector2, text: String) -> void:
	var w := UiStyle.rich_width(text, UiStyle.Role.HINT, 28) + 44.0
	UiStyle.para(self, Rect2(at.x, at.y - 24, w, 48), UiStyle.INK_SHOW)
	UiStyle.draw_rich(self, Vector2(at.x + 22, at.y), text, UiStyle.Role.HINT, UiStyle.CREAM, 0, 28)


## The READY! stamp, knocked on at an angle; slams in from big.
func _draw_stamp(at: Vector2) -> void:
	var s := lerpf(1.8, 1.0, _stamp)
	draw_set_transform(at, deg_to_rad(-9.0), Vector2(s, s))
	var label := "GO!" if go else "READY!"
	var f := UiStyle.font(UiStyle.Role.CAPTION)
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 40.0
	var r := Rect2(-w * 0.5, -32, w, 62)
	var alpha := clampf(_stamp * 1.5, 0.0, 1.0)
	draw_rect(r, Color(UiStyle.accent if go else UiStyle.CREAM, alpha))
	draw_rect(r, Color(UiStyle.INK_SHOW, alpha), false, 6.0)
	UiStyle.draw_text(self, Vector2(0, -1), label, UiStyle.Role.CAPTION, Color(UiStyle.INK_SHOW, alpha), 1, 44)
	draw_set_transform_matrix(Transform2D.IDENTITY)
