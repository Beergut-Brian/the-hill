## The X-button build book for one player: a page of building cards, each a picture of the
## building and its cost as stacked block squares (columns of 5, BlockData colours). No words, no
## numbers. Greyed when the pile can't afford it. The focused card lifts and glows in the player's
## colour. Anchored to director.view_rect_of(player) (the full viewport without a director).
## BuildController creates it, feeds it input (steer) and asks focused_id().
## Pictures, never words, say what a card needs or gives: a bubble on the Garage card shows the
## vehicle it opens next (and, greyed beside it, the treasure that vehicle still waits for); cards
## in `locked` (after the others, greyed) show the vehicle that opens them, e.g. the Crane for the
## Lighthouse and the Water Tower. Picking a locked card bounces its bubble (hint()).
class_name BuildBook
extends Control

const CARD := Vector2(250, 330)
const GAP := 34.0
const SQUARE := 20.0
const LIFT := 26.0
const BLOCK_ORDER := [&"dirt", &"clay", &"stone", &"ice", &"crystal", &"strangestone", &"edgestone"]

var player := 0
var controller: Node
var rows: Array = []          # BuildingData
var locked: Array = []        # BuildingData shown greyed after `rows`, with what opens them
var focus := 0

var _open := false
var _last_x := 0
var _lift: Array = []
var _shake := 0.0
var _hint := 0.0
var _k := 1.0
var _tw: Tween


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift.resize(_count())
	_lift.fill(0.0)
	_anchor()
	Events.inventory_changed.connect(_on_inventory)


func _exit_tree() -> void:
	if Events.inventory_changed.is_connected(_on_inventory):
		Events.inventory_changed.disconnect(_on_inventory)


func _on_inventory(_b: StringName, _n: int) -> void:
	queue_redraw()


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	focus = clampi(focus, 0, maxi(_count() - 1, 0))
	Audio.play("book_open")
	_anchor()
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var t := _new_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not _open:
		return
	_open = false
	Audio.play("book_close")
	if not is_inside_tree():
		queue_free()
		return
	var t := _new_tween()
	t.tween_property(self, "scale", Vector2(0.8, 0.8), 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "modulate:a", 0.0, 0.14)
	t.chain().tween_callback(queue_free)


func _new_tween() -> Tween:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel()
	return _tw


## Left/right on the stick: one card per push.
func steer(x: float) -> void:
	var s := 0
	if x > 0.5:
		s = 1
	elif x < -0.5:
		s = -1
	elif absf(x) > 0.3:
		return
	if s != 0 and s != _last_x and _count() > 0:
		focus = posmod(focus + s, _count())
		Audio.play("ui_move")
		queue_redraw()
	_last_x = s


func _count() -> int:
	return rows.size() + locked.size()


func _row(i: int) -> BuildingData:
	return rows[i] if i < rows.size() else locked[i - rows.size()]


func focused_id() -> StringName:
	return _row(focus).id if focus < _count() else &""


func focused_locked() -> bool:
	return focus >= rows.size() and focus < _count()


func locked_ids() -> Array:
	return locked.map(func(d: BuildingData) -> StringName: return d.id)


## A locked card was picked: its picture of what opens it bounces, with a curious little sound.
func hint() -> void:
	_hint = 0.6
	Audio.play("book_hint")


func card_ids() -> Array:
	return rows.map(func(d: BuildingData) -> StringName: return d.id)


func card_affordable(i: int) -> bool:
	return Inventory.can_afford(rows[i].cost)


## Can't afford: the focused card wobbles.
func shake() -> void:
	_shake = 0.35


func _anchor() -> void:
	var r := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var g = controller.game if controller != null else null
	var dir = g.get("director") if g != null else null
	if dir != null and dir.has_method("view_rect_of"):
		r = dir.view_rect_of(player)
	if global_position != r.position or size != r.size:
		global_position = r.position
		size = r.size
		pivot_offset = size * 0.5
		queue_redraw()


func _process(delta: float) -> void:
	_anchor()
	var moving := false
	for i in _lift.size():
		var target := LIFT if i == focus else 0.0
		var v: float = lerpf(_lift[i], target, minf(1.0, delta * 14.0))
		if absf(v - _lift[i]) > 0.05:
			moving = true
		_lift[i] = v
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		moving = true
	if _hint > 0.0:
		_hint = maxf(0.0, _hint - delta)
		moving = true
	if moving:
		queue_redraw()


func _draw() -> void:
	var n := maxi(_count(), 1)
	var need := Vector2(n * CARD.x + (n + 1) * GAP, CARD.y + 2 * GAP + LIFT)
	_k = minf(1.0, minf((size.x - 40) / need.x, (size.y - 40) / need.y))
	var panel_size := need * _k
	var origin := (size - panel_size) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	draw_style_box(UiStyle.panel(UiStyle.PANEL), Rect2(origin, panel_size))
	draw_style_box(UiStyle.outline(UiStyle.player_color(player), 6), Rect2(origin, panel_size))
	for i in _count():
		var pos := origin + Vector2(GAP + i * (CARD.x + GAP), GAP + LIFT) * _k
		pos.y -= _lift[i] * _k if i < _lift.size() else 0.0
		if i == focus and _shake > 0.0:
			pos.x += sin(_shake * 70.0) * 10.0 * _k
		_draw_card(Rect2(pos, CARD * _k), _row(i), i == focus, i >= rows.size())


func _draw_card(r: Rect2, d: BuildingData, focused: bool, is_locked := false) -> void:
	var can := Inventory.can_afford(d.cost) and not is_locked
	var pc := UiStyle.player_color(player)
	if focused:
		draw_style_box(UiStyle.glow(pc, UiStyle.RADIUS, int(30 * _k)), r)
	draw_style_box(UiStyle.panel(UiStyle.PANEL_RAISED if can else UiStyle.PANEL, UiStyle.RADIUS, int(10 * _k)), r)
	if focused:
		draw_style_box(UiStyle.outline(pc, int(maxf(3.0, 6 * _k)), UiStyle.RADIUS), r)
	# The picture: sky, a strip of grass, the building standing on it.
	var pic := Rect2(r.position + Vector2(16, 16) * _k, Vector2(r.size.x - 32 * _k, r.size.y * 0.56))
	var sky := StyleBoxFlat.new()
	sky.bg_color = Color("b5e3f7") if can else Color("5b5856")
	sky.set_corner_radius_all(int(14 * _k))
	draw_style_box(sky, pic)
	var grass_y := pic.end.y - 18 * _k
	draw_rect(Rect2(pic.position.x, grass_y, pic.size.x, 18 * _k), Color("4f9a3a") if can else Color("4a4745"))
	var fp := Vector2(d.footprint)
	var room := Vector2(pic.size.x - 36 * _k, grass_y - pic.position.y - 14 * _k)
	var unit := minf(room.x / fp.x, room.y / fp.y)
	var bsize := fp * unit
	var brect := Rect2(Vector2(pic.get_center().x - bsize.x * 0.5, grass_y - bsize.y), bsize)
	Building.paint(self, d.id, brect, 0.0, not can)
	# The cost: one square per block, columns of 5 from the bottom, one block type after another.
	var cols: Array = []   # [color, count in this column]
	var keys: Array = []
	for b in BLOCK_ORDER:
		if d.cost.has(b):
			keys.append(b)
	for b in d.cost:
		if not keys.has(StringName(str(b))):
			keys.append(StringName(str(b)))
	for b in keys:
		var left := int(d.cost.get(b, d.cost.get(String(b), 0)))
		while left > 0:
			cols.append([Hillville.block_color(b), mini(5, left)])
			left -= 5
	var sq := SQUARE * _k
	var step := sq + 4 * _k
	var area_top := pic.end.y + 12 * _k
	var area_h := r.end.y - area_top - 12 * _k
	var fit := minf(1.0, minf((r.size.x - 24 * _k) / maxf(cols.size() * step, 1.0), area_h / (5 * step)))
	sq *= fit
	step *= fit
	var total_w := cols.size() * step - (step - sq)
	var x := r.get_center().x - total_w * 0.5
	var base := area_top + area_h * 0.5 + 2.5 * step
	for c in cols:
		for k in c[1]:
			var sr := Rect2(x, base - (k + 1) * step, sq, sq)
			var col: Color = c[0]
			if not can:
				var l := col.get_luminance()
				col = Color(l, l, l).darkened(0.35)
			draw_rect(sr, col)
			draw_rect(sr, Color(0.05, 0.04, 0.04), false, maxf(1.5, 2.5 * _k))
		x += step
	if not can:
		draw_style_box(UiStyle.panel(Color(0, 0, 0, 0.3), UiStyle.RADIUS, 0), r)
	_draw_needs(pic, d, focused, is_locked)


## The picture bubbles: what opens a locked card, what a Garage gives next.
func _draw_needs(pic: Rect2, d: BuildingData, focused: bool, is_locked: bool) -> void:
	var rad := pic.size.x * 0.2
	var bounce := sin(_hint * 18.0) * 8.0 * _k if focused and _hint > 0.0 else 0.0
	var c := Vector2(pic.end.x - rad * 0.9, pic.position.y + rad * 0.9 - bounce)
	if is_locked and d.needs_vehicle != &"":
		_bubble(c, rad, true)
		_vehicle_pic(c, rad, Progress.vehicle_data(d.needs_vehicle), false)
		return
	if d.effect != &"next_vehicle":
		return
	var v := Progress.next_in_line()
	if v == null:
		return
	var waits := v.needs_treasure != &"" and not Progress.has_treasure(v.needs_treasure)
	_bubble(c, rad, false)
	_vehicle_pic(c, rad, v, waits)
	if waits:
		var tc := Vector2(pic.position.x + rad * 0.9, c.y)
		_bubble(tc, rad * 0.8, true)
		_treasure_pic(tc, rad * 0.8, v.needs_treasure)


## A round picture bubble; `ask`: a gold ring (something to find or get first).
func _bubble(c: Vector2, rad: float, ask: bool) -> void:
	draw_circle(c, rad + 3.0 * _k, Color(0.07, 0.06, 0.09))
	draw_circle(c, rad, Color("fff6dc"))
	if ask:
		draw_arc(c, rad - 2.0 * _k, 0.0, TAU, 32, Color("ffd23f"), maxf(2.0, 4.0 * _k))


func vehicle_scale(d: VehicleData, rad: float) -> float:
	var s := Vehicle.body_size(d)
	return maxf(1.0, floorf(rad * 1.5 / maxf(s.x + 24.0, s.y + 20.0)))


func _vehicle_pic(c: Vector2, rad: float, d: VehicleData, grey: bool) -> void:
	if d == null:
		return
	var k := vehicle_scale(d, rad)
	var feet := c + Vector2(0, Vehicle.body_size(d).y * 0.5 * k)
	draw_set_transform(feet.round(), 0.0, Vector2(k, k))
	Vehicle.draw_vehicle(self, d, 1, Color(0, 0, 0, 0), 0.0, 0.0, 0.0)
	draw_set_transform(Vector2.ZERO)
	if grey:
		draw_circle(c, rad, Color(0.35, 0.33, 0.32, 0.55))


## The treasure, as a dark silhouette until it is found.
func _treasure_pic(c: Vector2, rad: float, id: StringName) -> void:
	var tex := SpriteArt.texture("treasures/%s.png" % id)
	var found := Progress.has_treasure(id)
	if tex == null:
		draw_circle(c, rad * 0.5, Color("f4ecd8") if found else Color(0.2, 0.18, 0.22))
		return
	var ts := Vector2(tex.get_size())
	var k := maxf(1.0, floorf(rad * 1.4 / maxf(ts.x, ts.y)))
	var sz := ts * k
	draw_texture_rect(tex, Rect2((c - sz * 0.5).round(), sz), false, Color.WHITE if found else Color(0.18, 0.16, 0.22, 0.9))
