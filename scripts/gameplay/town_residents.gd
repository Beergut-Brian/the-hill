## The residents up top, beside the shaft pile (visuals only, no collision, never in the way):
## - The Gnome Foreman and his crew stand just right of the pile. When blocks land on the pile (a
##   ride up dumps backpacks) the crew hops and cheers, and the Foreman blows one "noted" whistle
##   and holds up a picture of the build book. When a building is placed they march past it in a
##   line (two whistles) and come back.
## - The Caveman, once thawed (Story), waits by a campfire past the crew, hoots and hops when a
##   player comes by.
## HillGame adds this to Hillville. Timers run in physics time.
class_name TownResidents
extends Node2D

signal cheered()
signal marched(building: StringName)

const FOREMAN_FILE := "characters/foreman.png"
const CAVEMAN_FILE := "characters/caveman.png"
## The crew's spot: right of the pile (Hillville.PILE_X is its left edge, two plots wide).
const CREW_X := Hillville.PILE_X + 112.0
const CREW_GAP := 15.0
const CREW_SIZE := 3
const FIRE_X := Hillville.PILE_X + 214.0
## Blocks arriving within GAIN_WINDOW count as one delivery; CHEER_MIN or more is a cheer.
const GAIN_WINDOW := 0.3
const CHEER_MIN := 3
const CHEER_TIME := 1.4
const BOOK_TIME := 2.6
const MARCH_SPEED := 95.0
const MARCH_PAST := 56.0
const HOOT_NEAR := 110.0
const PLOT := 48.0
const OUTLINE := Color("3a2a44")
const CREAM := Color("f4e8c8")
const GOLD := Color("ffd23f")
const CREW_TINTS: Array[Color] = [Color(1.0, 0.92, 0.92), Color(0.92, 1.0, 0.92), Color(0.92, 0.95, 1.0)]

var game: Node
var hillville: Hillville
var foreman: SheetSprite
var crew: Array[SheetSprite] = []
var caveman: SheetSprite

var _t := 0.0
var _counts := {}
var _gain := 0
var _gain_t := -1.0
var _cheer := 0.0
var _book := 0.0
var _march := {}            # {target: float, t, out: bool, id}
var _marches: Array = []
var _hoot := 0.0
var _hoot_armed := true
var _quiet := 1.0           # ignore the pile filling from a save at boot


func setup(p_game: Node, hv: Hillville) -> void:
	game = p_game
	hillville = hv
	name = "TownResidents"
	foreman = _sprite(FOREMAN_FILE, "idle", Vector2(CREW_X + CREW_SIZE * CREW_GAP, 0.0))
	foreman.flip_h = true
	for i in CREW_SIZE:
		var s := _sprite(FOREMAN_FILE, "idle", Vector2(CREW_X + i * CREW_GAP, 0.0))
		s.scale = Vector2.ONE * 0.8
		s.modulate = CREW_TINTS[i % CREW_TINTS.size()]
		s.flip_h = true
		crew.append(s)
	caveman = _sprite(CAVEMAN_FILE, "idle", Vector2(FIRE_X - 26.0, 0.0))
	caveman.visible = false
	for b in Inventory.to_save():
		_counts[StringName(str(b))] = Inventory.count(StringName(str(b)))
	Events.inventory_changed.connect(_on_inventory_changed)
	Events.building_placed.connect(_on_building_placed)
	sync_story()


func _exit_tree() -> void:
	if Events.inventory_changed.is_connected(_on_inventory_changed):
		Events.inventory_changed.disconnect(_on_inventory_changed)
	if Events.building_placed.is_connected(_on_building_placed):
		Events.building_placed.disconnect(_on_building_placed)


func _sprite(file: String, anim: String, feet: Vector2) -> SheetSprite:
	var s := SheetSprite.make(file, anim)
	if s == null:
		s = SheetSprite.new()
	s.position = feet
	add_child(s)
	return s


func story() -> Story:
	var s = game.get("story") if game != null else null
	return s as Story


## Shows the Caveman by his fire once he has thawed (from a save, or live with a puff).
func sync_story() -> void:
	var st := story()
	var show := st != null and st.is_thawed()
	if show and not caveman.visible and _t > 0.0:
		hillville.puff(caveman.position + Vector2(0, -16), CREAM, 12)
		Audio.play("caveman_hoot")
	caveman.visible = show


func caveman_here() -> bool:
	return caveman.visible


func is_cheering() -> bool:
	return _cheer > 0.0


func is_marching() -> bool:
	return not _march.is_empty()


func _on_inventory_changed(block: StringName, count: int) -> void:
	var was: int = _counts.get(block, 0)
	_counts[block] = count
	if count <= was or _quiet > 0.0:
		return
	_gain += count - was
	if _gain_t < 0.0:
		_gain_t = GAIN_WINDOW


func _on_building_placed(id: StringName, cell: Vector2i) -> void:
	var w := 2
	var path := "res://data/buildings/%s.tres" % id
	if ResourceLoader.exists(path):
		var d := load(path) as BuildingData
		if d != null:
			w = d.footprint.x
	_marches.append({"id": id, "from": cell.x * PLOT, "to": (cell.x + w) * PLOT})


func cheer() -> void:
	_cheer = CHEER_TIME
	_book = BOOK_TIME
	Audio.play("crew_cheer")
	Audio.play("whistle")
	for s in crew:
		hillville.puff(s.position + Vector2(0, -26), GOLD, 5)
	hillville.puff(foreman.position + Vector2(0, -30), Color("ff8fb1"), 6)
	cheered.emit()


func _physics_process(delta: float) -> void:
	_t += delta
	_quiet = maxf(0.0, _quiet - delta)
	if game != null and game.get("story") != null:
		var st: Story = game.story
		if st.is_thawed() != caveman.visible:
			sync_story()
	if _gain_t >= 0.0:
		_gain_t -= delta
		if _gain_t < 0.0:
			if _gain >= CHEER_MIN and _march.is_empty():
				cheer()
			_gain = 0
	_cheer = maxf(0.0, _cheer - delta)
	_book = maxf(0.0, _book - delta)
	if _march.is_empty() and not _marches.is_empty() and _cheer <= 0.0:
		_start_march(_marches.pop_front())
	if not _march.is_empty():
		_step_march(delta)
	else:
		_idle()
	_tick_caveman(delta)
	if TimeOfDay.has_method("world_tint"):
		modulate = TimeOfDay.world_tint()
	queue_redraw()


func _idle() -> void:
	var all: Array[SheetSprite] = crew.duplicate()
	all.append(foreman)
	for i in all.size():
		var s := all[i]
		s.position.x = CREW_X + i * CREW_GAP
		s.flip_h = true
		var hop := 0.0
		if _cheer > 0.0:
			hop = absf(sin((CHEER_TIME - _cheer) * 9.0 + i * 0.9)) * 8.0
		s.position.y = -hop


func _start_march(m: Dictionary) -> void:
	# Out past the building's far side and back home, in a line, the Foreman leading.
	var home := CREW_X
	var far: float = m.to + MARCH_PAST if m.to > home else m.from - MARCH_PAST
	_march = {"id": m.id, "x": home, "target": far, "out": true}
	Audio.play("whistle")
	Audio.play("whistle")
	Audio.play("crew_march")
	marched.emit(m.id)


func _step_march(delta: float) -> void:
	var goal: float = _march.target if _march.out else CREW_X
	var dir := signf(goal - _march.x)
	_march.x += dir * minf(absf(goal - _march.x), MARCH_SPEED * delta)
	if absf(goal - _march.x) < 0.5:
		if _march.out:
			_march.out = false
		else:
			_march = {}
			return
	var lead := 1.0 if dir >= 0.0 else -1.0
	var line: Array[SheetSprite] = [foreman]
	line.append_array(crew)
	for i in line.size():
		var s := line[i]
		s.flip_h = lead < 0.0
		s.position.x = _march.x - lead * i * CREW_GAP
		# Marching, never walking: sharp little steps.
		s.position.y = -absf(sin(_t * 11.0 + i * PI * 0.5)) * 3.0


func _tick_caveman(delta: float) -> void:
	if not caveman.visible:
		return
	_hoot = maxf(0.0, _hoot - delta)
	var near := INF
	if hillville != null and hillville.players_root() != null:
		for pl in hillville.players_root().get_children():
			if pl is Node2D:
				near = minf(near, absf((pl as Node2D).position.x - caveman.position.x))
	if near > HOOT_NEAR * 1.6:
		_hoot_armed = true
	if near < HOOT_NEAR and _hoot_armed:
		_hoot_armed = false
		_hoot = 1.0
		Audio.play("caveman_hoot")
	caveman.position.y = -absf(sin(_hoot * PI * 3.0)) * 6.0 if _hoot > 0.0 else 0.0


func _draw() -> void:
	if _book > 0.0:
		_draw_book_bubble(foreman.position + Vector2(0, -44), minf(1.0, _book * 3.0))
	if caveman.visible:
		_draw_fire(Vector2(FIRE_X, 0.0))


## A picture bubble with an open build book in it, pointing at the Foreman.
func _draw_book_bubble(at: Vector2, a: float) -> void:
	var r := Rect2(at + Vector2(-13, -11), Vector2(26, 20))
	draw_rect(r.grow(1.5), Color(OUTLINE, a))
	draw_rect(r, Color(1, 1, 1, a))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 9), at + Vector2(3, 9), at + Vector2(0, 15)]), Color(1, 1, 1, a))
	var page := Color(0.85, 0.3, 0.25, a)
	draw_rect(Rect2(at + Vector2(-9, -7), Vector2(8, 11)), page)
	draw_rect(Rect2(at + Vector2(1, -7), Vector2(8, 11)), page)
	draw_rect(Rect2(at + Vector2(-8, -6), Vector2(6, 9)), Color(CREAM, a))
	draw_rect(Rect2(at + Vector2(2, -6), Vector2(6, 9)), Color(CREAM, a))
	# A tiny house on the left page, a block stack on the right.
	draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -2), at + Vector2(-5, -5), at + Vector2(-2, -2)]), Color(0.75, 0.25, 0.2, a))
	draw_rect(Rect2(at + Vector2(-7, -2), Vector2(4, 4)), Color(0.85, 0.65, 0.4, a))
	draw_rect(Rect2(at + Vector2(3, 0), Vector2(2, 2)), Color(0.6, 0.45, 0.3, a))
	draw_rect(Rect2(at + Vector2(5, 0), Vector2(2, 2)), Color(0.78, 0.45, 0.2, a))
	draw_rect(Rect2(at + Vector2(4, -2), Vector2(2, 2)), Color(0.55, 0.55, 0.6, a))


func _draw_fire(at: Vector2) -> void:
	draw_circle(at + Vector2(0, -8), 26.0 + sin(_t * 7.0) * 2.0, Color(1.0, 0.7, 0.35, 0.18))
	# Logs.
	draw_line(at + Vector2(-10, -1), at + Vector2(10, -4), OUTLINE, 5.0)
	draw_line(at + Vector2(-10, -4), at + Vector2(10, -1), OUTLINE, 5.0)
	draw_line(at + Vector2(-9, -1.5), at + Vector2(9, -4), Color("8a5a3c"), 3.0)
	draw_line(at + Vector2(-9, -4), at + Vector2(9, -1.5), Color("a47148"), 3.0)
	for k in 3:
		var f := sin(_t * (9.0 + k * 2.3) + k) * 1.5
		var h := 13.0 - k * 3.5 + f
		var w := 7.0 - k * 2.0
		var col: Color = [Color("ff7a2f"), Color("ffb13b"), Color("ffe27a")][k]
		draw_colored_polygon(PackedVector2Array([at + Vector2(-w, -4), at + Vector2(f * 0.6, -4 - h), at + Vector2(w, -4)]), col)
