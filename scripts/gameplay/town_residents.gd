## The residents up top, beside the shaft pile (visuals only, no collision, never in the way):
## - The Gnome Foreman and his crew stand just right of the pile. When blocks land on the pile (a
##   ride up dumps backpacks) the crew hops and cheers, and the Foreman blows one "noted" whistle
##   and holds up a picture of the build book. When a building is placed they march past it in a
##   line (two whistles) and come back.
## - The Caveman, once thawed (Story), waits by a campfire past the crew, hoots and hops when a
##   player comes by.
## The arcs (Story): a resident who has ARRIVED waits near the shaft "hat in hands" (the Mole holds
## the shovel like a bouquet, the Foreman his hard hat, the Caveman beams by his fire, the Dragon
## curls beside the Ruined Keep on the peak) and, when a player comes close, says in pictures what
## they did (sheepish) and then shows their ruin (hopeful). Once their ruin is rebuilt they move in
## (on_rebuilt) and live there: wandering, reacting to buildings placed near them, and their gags:
## the Mole pops up in the pond by mistake and honks the horn of a parked vehicle, the Caveman is
## baffled by the Dump Truck and polishes the Museum shelf, the Foreman inspects barns.
## HillGame adds this to Hillville. Timers run in physics time.
class_name TownResidents
extends Node2D

signal cheered()
signal marched(building: StringName)

const FOREMAN_FILE := "characters/foreman.png"
const CAVEMAN_FILE := "characters/caveman.png"
const MOLE_FILE := "characters/mole.png"
const DRAGON_FILE := "characters/dragon.png"
const MOLE_WAIT_X := Hillville.SHAFT_X - 76.0
## The Dragon waits on the peak, left of the Ruined Keep (cell 153).
const DRAGON_WAIT := Vector2(153 * 48.0 - 70.0, 0.0)
const DRAGON_SCALE := 0.8
const TALK_NEAR := 150.0
const TALK_REARM := 320.0
const TALK_PART := 2.2
const WHAT := {&"mole": &"shovel", &"gnome_foreman": &"wall", &"caveman": &"ice", &"dragon": &"shaken_hill"}
const WALK := 70.0
const POND_NEAR := 320.0
const POND_EVERY := 45.0
const HONK_NEAR := 260.0
const HONK_EVERY := 50.0
const BAFFLE_NEAR := 150.0
const INSPECT_EVERY := 30.0
const REACT_NEAR := 280.0
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
var mole: SheetSprite
var dragon: SheetSprite
var _front: Node2D
var _say := {}              # id -> [{pics: Array, t: float}] queued picture bubbles
var _talk_armed := {}       # id -> bool (rearms when every player has walked away)
var _hop := {}              # id -> seconds of happy hop left
var _mole := {"mode": &"away", "t": 0.0, "cd_pond": 8.0, "cd_honk": 12.0, "x": 0.0}
var _fm := {"mode": &"idle", "t": 0.0, "cd": 10.0, "x": 0.0, "to": 0.0}
var _cave := {"mode": &"idle", "t": 0.0, "cd": 0.0, "polish": 0.0}
var _drag := {"mode": &"away", "t": 0.0}


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
	mole = _sprite(MOLE_FILE, "idle", Vector2(MOLE_WAIT_X, 0.0))
	mole.visible = false
	dragon = _sprite(DRAGON_FILE, "asleep", DRAGON_WAIT)
	dragon.scale = Vector2.ONE * DRAGON_SCALE
	dragon.visible = false
	_fm.x = CREW_X + CREW_SIZE * CREW_GAP
	# Held things and bubbles draw in front of the sprites.
	_front = Node2D.new()
	_front.name = "Front"
	_front.draw.connect(_draw_arcs)
	add_child(_front)
	for b in Inventory.to_save():
		_counts[StringName(str(b))] = Inventory.count(StringName(str(b)))
	Events.inventory_changed.connect(_on_inventory_changed)
	Events.building_placed.connect(_on_building_placed)
	var st := story()
	if st != null:
		st.changed.connect(sync_story)
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
	if st == null:
		return
	if st.restored(Story.CAVEMAN) and _cave.mode == &"idle" and not _rebuilding(Story.CAVEMAN):
		_cave.mode = &"museum"
		caveman.position = _museum_spot()
	# The crew is walled in underground until the Gnome Room is opened.
	for c in crew:
		c.visible = st.in_town(Story.FOREMAN)
	if st.restored(Story.FOREMAN) and _fm.mode == &"idle" and not _rebuilding(Story.FOREMAN):
		_fm.mode = &"tower"
		_fm.x = _door(Story.FOREMAN).x
	# The Mole: waiting at the shaft, or at home by the Lost & Found.
	if st.in_town(Story.MOLE) and _mole.mode == &"away":
		if st.restored(Story.MOLE) and not _rebuilding(Story.MOLE):
			_mole_to(&"home", _mole_home(), false)
		elif st.arrived(Story.MOLE):
			_mole_to(&"wait", Vector2(MOLE_WAIT_X, 0), _t > 0.0)
	# The Dragon: from a save straight to her spot; live, she comes up the shaft in pieces.
	if st.in_town(Story.DRAGON) and _drag.mode == &"away":
		if st.restored(Story.DRAGON) and not _rebuilding(Story.DRAGON):
			_drag = {"mode": &"perch", "t": 0.0}
		elif _t > 0.0:
			_drag = {"mode": &"pieces", "t": 0.0}
			Audio.play("elevator_clank")
		else:
			_drag = {"mode": &"wait", "t": 0.0}
	_place_dragon()


func _rebuilding(id: StringName) -> bool:
	var r = game.get("ruins") if game != null else null
	return r != null and r.is_rebuilding(id)


func _door(id: StringName) -> Vector2:
	var r = game.get("ruins") if game != null else null
	if r != null:
		return r.door_of(id)
	return hillville.ruin_rect(Story.RUIN_OF.get(id, &"")).get_center() * Vector2(1, 0)


func _mole_home() -> Vector2:
	return _door(Story.MOLE) + Vector2(22, 0)


func _museum_spot() -> Vector2:
	var sh = game.get("shelf") if game != null else null
	if sh != null and sh.museum:
		return sh.polish_spot()
	return _door(Story.CAVEMAN) + Vector2(30, 0)


func _perch() -> Vector2:
	var r := hillville.ruin_rect(Story.RUIN_OF[Story.DRAGON])
	return Vector2(r.get_center().x, r.position.y + 30.0)


## Who stands where: the arc's sprites by id.
func sprite_of(id: StringName) -> SheetSprite:
	match id:
		Story.MOLE:
			return mole
		Story.FOREMAN:
			return foreman
		Story.CAVEMAN:
			return caveman
		Story.DRAGON:
			return dragon
	return null


## Shows a picture bubble over a resident for `secs` (queued after any bubble already showing).
func say(id: StringName, pics: Array, secs := TALK_PART) -> void:
	if not _say.has(id):
		_say[id] = []
	(_say[id] as Array).append({"pics": pics, "t": secs})


func saying(id: StringName) -> Array:
	var q: Array = _say.get(id, [])
	return q[0].pics if not q.is_empty() else []


## The Arrival bubble: what they did (sheepish), then their ruin (hopeful).
func plead(id: StringName) -> void:
	_say[id] = []
	say(id, [WHAT[id], &"face_sheepish"])
	say(id, [StringName("ruin:%s" % Story.RUIN_OF[id]), &"face_hopeful"])
	_hop[id] = 0.5
	Audio.play("resident_hm")
	Audio.play("resident_hope")


func mole_mode() -> StringName:
	return _mole.mode


func dragon_mode() -> StringName:
	return _drag.mode


func foreman_mode() -> StringName:
	return _fm.mode


func caveman_mode() -> StringName:
	return _cave.mode


## Story just moved `id` to RESTORED: the building is going up; they wait for it (on_rebuilt).
func on_restored(id: StringName) -> void:
	_say[id] = []
	_hop[id] = 1.2
	Audio.play("resident_cheer")


## Their home stands: they move in, happy.
func on_rebuilt(id: StringName) -> void:
	var door := _door(id)
	match id:
		Story.MOLE:
			_mole_to(&"home", _mole_home(), true)
		Story.FOREMAN:
			hillville.puff(foreman.position + Vector2(0, -14), CREAM, 10)
			_fm.mode = &"tower"
			_fm.x = door.x
			foreman.position = Vector2(door.x, 0)
			hillville.puff(door + Vector2(0, -14), Color("ffd23f"), 12)
			Audio.play("whistle")
		Story.CAVEMAN:
			hillville.puff(caveman.position + Vector2(0, -14), CREAM, 10)
			_cave.mode = &"museum"
			var sh = game.get("shelf") if game != null else null
			var hv_r := hillville.ruin_rect(Story.RUIN_OF[Story.CAVEMAN])
			if sh != null:
				sh.museum_at(hv_r)
			caveman.position = _museum_spot()
			hillville.puff(caveman.position + Vector2(0, -14), Color("ffd23f"), 12)
			Audio.play("caveman_hoot")
		Story.DRAGON:
			_drag = {"mode": &"fly", "t": 0.0, "from": dragon.position}
			Audio.play("dragon_flap")
	say(id, [StringName("home:%s" % Story.HOME_OF[id]), &"heart"], 2.4)
	_hop[id] = 1.0


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
	# Anyone living nearby is delighted.
	var mid := (cell.x + w * 0.5) * PLOT
	for rid: StringName in [Story.MOLE, Story.FOREMAN, Story.CAVEMAN, Story.DRAGON]:
		var sp := sprite_of(rid)
		if sp != null and sp.visible and absf(sp.position.x - mid) < REACT_NEAR:
			_hop[rid] = 0.8
			say(rid, [StringName("home:%s" % id), &"heart"], 1.8)
			Audio.play("resident_happy")


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
	_tick_arcs(delta)
	if TimeOfDay.has_method("world_tint"):
		modulate = TimeOfDay.world_tint()
	queue_redraw()


func _foreman_busy() -> bool:
	return _fm.mode != &"idle"


func _idle() -> void:
	var all: Array[SheetSprite] = crew.duplicate()
	if not _foreman_busy():
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
	var line: Array[SheetSprite] = []
	if not _foreman_busy():
		line.append(foreman)
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
	if _cave.mode == &"idle":
		caveman.position.y = -absf(sin(_hoot * PI * 3.0)) * 6.0 if _hoot > 0.0 else 0.0


func _draw() -> void:
	if _book > 0.0:
		_draw_book_bubble(foreman.position + Vector2(0, -44), minf(1.0, _book * 3.0))
	if caveman.visible and _cave.mode != &"museum":
		_draw_fire(Vector2(FIRE_X, 0.0))
	if _front != null:
		_front.queue_redraw()


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


# --- the arcs: waiting, moving in, town life ----------------------------------------------------

func _players_x() -> Array:
	var xs: Array = []
	if hillville == null or hillville.players_root() == null:
		return xs
	for pl in hillville.players_root().get_children():
		if pl is Node2D:
			xs.append((pl as Node2D).position.x)
	return xs


func _near(x: float, r: float) -> bool:
	for px in _players_x():
		if absf(float(px) - x) < r:
			return true
	return false


func _tick_arcs(delta: float) -> void:
	var st := story()
	if st == null:
		return
	# Bubbles.
	for id in _say.keys():
		var q: Array = _say[id]
		if q.is_empty():
			continue
		q[0].t -= delta
		if q[0].t <= 0.0:
			q.pop_front()
	for id in _hop.keys():
		_hop[id] = maxf(0.0, _hop[id] - delta)
	# Arrival: a waiting resident pleads when a player comes close (again after they left).
	for id: StringName in [Story.MOLE, Story.FOREMAN, Story.CAVEMAN, Story.DRAGON]:
		var sp := sprite_of(id)
		if not st.arrived(id) or sp == null or not sp.visible:
			continue
		if id == Story.DRAGON and _drag.mode != &"wait":
			continue
		var reach := TALK_NEAR * (1.6 if id == Story.DRAGON else 1.0)
		if not _near(sp.position.x, TALK_REARM):
			_talk_armed[id] = true
		elif _near(sp.position.x, reach) and _talk_armed.get(id, true) and not _bubble_near(sp.position.x):
			_talk_armed[id] = false
			plead(id)
	_tick_mole(st, delta)
	_tick_foreman_town(st, delta)
	_tick_caveman_town(st, delta)
	_tick_dragon(st, delta)


## True while any resident within 140 px of x is showing a bubble (so they take turns).
func _bubble_near(x: float) -> bool:
	for id in _say:
		var sp := sprite_of(id)
		if sp != null and not saying(id).is_empty() and absf(sp.position.x - x) < 140.0:
			return true
	return false


## Moves the Mole by tunnel (a dive here, a pop there) or straight there when not animated.
func _mole_to(mode: StringName, at: Vector2, tunnel: bool) -> void:
	if tunnel and mole.visible:
		hillville.puff(mole.position + Vector2(0, -4), Color(0.5, 0.36, 0.25), 8)
		Audio.play("mole_dig")
	_mole.mode = &"tunnel" if tunnel else mode
	_mole.then = mode
	_mole.to = at
	_mole.t = 0.0
	if not tunnel:
		mole.position = at
		_mole.x = at.x
		mole.visible = true
	else:
		mole.visible = false


func _mole_rest() -> Vector2:
	var st := story()
	return _mole_home() if st != null and st.restored(Story.MOLE) else Vector2(MOLE_WAIT_X, 0)


func _tick_mole(st: Story, delta: float) -> void:
	if not st.in_town(Story.MOLE):
		return
	_mole.t += delta
	_mole.cd_pond = maxf(0.0, _mole.cd_pond - delta)
	_mole.cd_honk = maxf(0.0, _mole.cd_honk - delta)
	var t: float = _mole.t
	match _mole.mode:
		&"tunnel":
			if t >= 0.8:
				_mole.mode = _mole.then
				_mole.t = 0.0
				mole.position = _mole.to
				_mole.x = _mole.to.x
				mole.visible = true
				hillville.puff(mole.position + Vector2(0, -4), Color(0.5, 0.36, 0.25), 10)
				Audio.play("mole_dig")
				if _mole.mode == &"pond":
					Audio.play("splash")
					hillville.puff(mole.position, Color(0.55, 0.8, 1.0), 16)
		&"wait", &"home":
			# Shuffle about a little (home) or stand with the bouquet (wait), bobbing.
			var base: Vector2 = _mole_rest()
			if _mole.mode == &"home":
				mole.position.x = base.x + sin(_t * 0.35) * 36.0
				mole.flip_h = cos(_t * 0.35) < 0.0
			else:
				mole.position.x = base.x
			mole.position.y = -absf(sin(_t * 9.0)) * 4.0 * minf(1.0, _hop.get(Story.MOLE, 0.0) * 2.0)
			if not saying(Story.MOLE).is_empty():
				return
			# Gags (only where a player can see them).
			var pond := Hillville.POND
			if _mole.cd_pond <= 0.0 and _near(pond.get_center().x, POND_NEAR):
				_mole.cd_pond = POND_EVERY
				_mole_to(&"pond", Vector2(pond.get_center().x - 24.0, 8.0), true)
				return
			var v := _empty_vehicle()
			if _mole.cd_honk <= 0.0 and v != null:
				_mole.cd_honk = HONK_EVERY
				_mole.vehicle = v
				_mole_to(&"honk", v.position + Vector2(-20, 0), true)
		&"pond":
			# Popped up in the pond by mistake: flail, splash, climb out, shake off, go home.
			var bank := Vector2(Hillville.POND.end.x + 14.0, 0)
			if t < 1.4:
				mole.position.y = 8.0 - absf(sin(t * 10.0)) * 3.0
				if int(t * 6.0) != int((t - delta) * 6.0):
					hillville.puff(mole.position + Vector2(0, -6), Color(0.55, 0.8, 1.0), 3)
			elif t < 2.0:
				var k := (t - 1.4) / 0.6
				mole.position = Vector2(lerpf(Hillville.POND.get_center().x - 24.0, bank.x, k), 8.0 * (1.0 - k) - sin(k * PI) * 26.0)
				mole.flip_h = false
			elif t < 2.9:
				mole.position = bank
				mole.position.x = bank.x + sin(t * 40.0) * 1.5
				if int(t * 8.0) != int((t - delta) * 8.0):
					hillville.puff(mole.position + Vector2(0, -12), Color(0.55, 0.8, 1.0), 2)
					if t < 2.2:
						Audio.play("shake_off")
			else:
				_mole_to(_mole_rest_mode(), _mole_rest(), true)
		&"honk":
			# Hop up on an empty vehicle, honk twice, hop off.
			var v = _mole.get("vehicle")
			if v == null or not is_instance_valid(v) or not (v as Node).is_inside_tree():
				_mole_to(_mole_rest_mode(), _mole_rest(), true)
				return
			var seat: Vector2 = (v as Node2D).position + Vector2(-4, -30)
			if t < 0.35:
				mole.position = ((v as Node2D).position + Vector2(-20, 0)).lerp(seat, t / 0.35) - Vector2(0, sin(t / 0.35 * PI) * 14.0)
			elif t < 1.9:
				mole.position = seat - Vector2(0, absf(sin(t * 7.0)) * 2.0)
				for at in [0.55, 1.2]:
					if t >= at and t - delta < at:
						var d: VehicleData = (v as Vehicle).data
						Audio.play(String(d.sounds.get(&"horn", "honk")) if d != null and d.sounds.has(&"horn") else "honk")
						_hop[Story.MOLE] = 0.4
			else:
				_mole_to(_mole_rest_mode(), _mole_rest(), true)


func _mole_rest_mode() -> StringName:
	var st := story()
	return &"home" if st != null and st.restored(Story.MOLE) else &"wait"


## A parked vehicle up top with nobody in it and a player close enough to see the Mole honk.
func _empty_vehicle() -> Node2D:
	var vs = game.get("vehicles") if game != null else null
	if not (vs is Dictionary):
		return null
	for id in vs:
		var v = vs[id]
		if v is Vehicle and is_instance_valid(v) and (v as Node).is_inside_tree() and hillville.is_ancestor_of(v) and (v as Vehicle).sleeper < 0:
			if _near((v as Node2D).position.x, HONK_NEAR):
				return v
	return null


## Where the Dump Truck is up top (parked or driven), or INF.
func _dump_truck_x() -> float:
	var vs = game.get("vehicles") if game != null else null
	if vs is Dictionary and vs.has(&"dump_truck"):
		var v = vs[&"dump_truck"]
		if is_instance_valid(v) and (v as Node).is_inside_tree() and hillville.is_ancestor_of(v):
			return (v as Node2D).position.x
	var dr = game.get("drivers") if game != null else null
	if dr is Dictionary and dr.has(&"dump_truck") and game.has_method("player_node"):
		var pn = game.player_node(int(dr[&"dump_truck"]))
		if pn != null and hillville.is_ancestor_of(pn):
			return hillville.to_local((pn as Node2D).global_position).x
	return INF


func _tick_caveman_town(st: Story, delta: float) -> void:
	if not caveman.visible:
		return
	_cave.t += delta
	_cave.cd = maxf(0.0, _cave.cd - delta)
	var truck := _dump_truck_x()
	if _cave.mode != &"baffled" and _cave.cd <= 0.0 and absf(truck - caveman.position.x) < BAFFLE_NEAR:
		_cave.back = _cave.mode
		_cave.mode = &"baffled"
		_cave.t = 0.0
		_cave.cd = 15.0
		caveman.flip_h = truck < caveman.position.x
		_say[Story.CAVEMAN] = []
		say(Story.CAVEMAN, [&"question"], 2.4)
		Audio.play("caveman_huh")
	match _cave.mode:
		&"baffled":
			# Leans in, jumps back, scratches his head.
			var t: float = _cave.t
			caveman.position.y = -absf(sin(t * 5.0)) * 3.0 if t > 1.0 else (-sin(t / 0.3 * PI) * 9.0 if t < 0.3 else 0.0)
			if t >= 2.6:
				_cave.mode = _cave.back
		&"museum":
			var spot := _museum_spot()
			caveman.position.x = spot.x + sin(_t * 1.7) * 3.0
			caveman.position.y = -absf(sin(_t * 6.0)) * 1.5 - (absf(sin(_hop.get(Story.CAVEMAN, 0.0) * 10.0)) * 6.0)
			caveman.flip_h = false
			_cave.polish -= delta
			if _cave.polish <= 0.0:
				_cave.polish = 3.0
				var sh = game.get("shelf") if game != null else null
				if sh != null and sh.polish() != &"" and _near(spot.x, 400.0):
					Audio.play("polish")
	if _cave.mode == &"idle" and _hop.get(Story.CAVEMAN, 0.0) > 0.0:
		caveman.position.y = -absf(sin(_hop[Story.CAVEMAN] * 12.0)) * 6.0


func _tick_foreman_town(st: Story, delta: float) -> void:
	if not st.in_town(Story.FOREMAN):
		return
	_fm.t += delta
	_fm.cd = maxf(0.0, _fm.cd - delta)
	var home_x: float = _door(Story.FOREMAN).x if st.restored(Story.FOREMAN) else CREW_X + CREW_SIZE * CREW_GAP
	match _fm.mode:
		&"idle", &"tower":
			if _fm.mode == &"tower":
				foreman.position = Vector2(home_x, -absf(sin(_hop.get(Story.FOREMAN, 0.0) * 12.0)) * 6.0)
				# The shift whistle from the tower now and then.
				if int(_t / 40.0) != int((_t - delta) / 40.0) and _near(home_x, 500.0):
					Audio.play("whistle")
					_hop[Story.FOREMAN] = 0.4
			if _fm.cd > 0.0 or is_marching() or is_cheering() or not saying(Story.FOREMAN).is_empty():
				return
			var barn := _nearest_barn(home_x)
			if barn != INF and _near(home_x, 600.0):
				_fm.back = _fm.mode
				_fm.mode = &"to_barn"
				_fm.to = barn
				_fm.x = foreman.position.x
				_fm.cd = INSPECT_EVERY
				Audio.play("whistle")
		&"to_barn", &"back":
			var goal: float = _fm.to if _fm.mode == &"to_barn" else home_x
			var dir := signf(goal - _fm.x)
			_fm.x += dir * minf(absf(goal - _fm.x), WALK * delta)
			foreman.flip_h = dir < 0.0
			foreman.position = Vector2(_fm.x, -absf(sin(_t * 11.0)) * 2.5)
			if absf(goal - _fm.x) < 0.5:
				if _fm.mode == &"to_barn":
					_fm.mode = &"inspect"
					_fm.t = 0.0
					say(Story.FOREMAN, [&"home:barn", &"star"], 1.8)
					Audio.play("clipboard")
				else:
					_fm.mode = _fm.back
		&"inspect":
			foreman.position.y = -absf(sin(_fm.t * 4.0)) * 2.0
			if _fm.t >= 2.0:
				_fm.mode = &"back"
				Audio.play("whistle")


## The middle of the nearest barn within 1200 px of x, or INF.
func _nearest_barn(x: float) -> float:
	var best := INF
	for b in Progress.buildings:
		if b.id != &"barn":
			continue
		var mid: float = b.cell.x * PLOT + PLOT
		if absf(mid - x) < 1200.0 and absf(mid - x) < absf(best - x):
			best = mid
	return best


func _place_dragon() -> void:
	match _drag.mode:
		&"wait":
			dragon.visible = true
			dragon.position = DRAGON_WAIT
			dragon.rotation = 0.0
		&"perch":
			dragon.visible = true
			dragon.position = _perch()
			dragon.rotation = 0.0
		&"pieces":
			dragon.visible = false


func _tick_dragon(st: Story, delta: float) -> void:
	if _drag.mode == &"away":
		return
	_drag.t += delta
	var t: float = _drag.t
	match _drag.mode:
		&"pieces":
			# Head, middle and tail come up out of the shaft one at a time, then she shakes herself
			# together and flies off to wait by the keep.
			for i in 3:
				if t >= i * 0.6 and t - delta < i * 0.6:
					Audio.play("elevator_ding")
					hillville.puff(Vector2(Hillville.SHAFT_X, -40), CREAM, 8)
			if t >= 2.4 and t - delta < 2.4:
				Audio.play("dragon_purr")
				hillville.puff(Vector2(Hillville.SHAFT_X, -30), Color("ff8fb1"), 14)
			if t >= 3.2:
				_drag = {"mode": &"fly", "t": 0.0, "from": Vector2(Hillville.SHAFT_X, 0), "to": DRAGON_WAIT, "then": &"wait"}
				dragon.visible = true
				Audio.play("dragon_flap")
		&"fly":
			var from: Vector2 = _drag.get("from", dragon.position)
			var to: Vector2 = _drag.get("to", _perch())
			var dur := clampf(from.distance_to(to) / 900.0, 1.4, 6.0)
			var k := clampf(t / dur, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			dragon.position = from.lerp(to, e) - Vector2(0, sin(k * PI) * minf(260.0, 60.0 + from.distance_to(to) * 0.1))
			dragon.flip_h = to.x < from.x
			dragon.rotation = sin(t * 9.0) * 0.06
			if int(t * 2.5) != int((t - delta) * 2.5):
				Audio.play("dragon_flap")
			if k >= 1.0:
				dragon.rotation = 0.0
				dragon.flip_h = false
				_drag = {"mode": _drag.get("then", &"perch"), "t": 0.0}
				hillville.puff(dragon.position, CREAM, 14)
				if _drag.mode == &"perch":
					Audio.play("dragon_purr")
					_hop[Story.DRAGON] = 0.8
		&"perch", &"wait":
			# Asleep and content; a lazy snore ring now and then.
			if int(t / 5.0) != int((t - delta) / 5.0) and _near(dragon.position.x, 500.0):
				Audio.play("dragon_snore")


func _draw_arcs() -> void:
	var st := story()
	if st == null:
		return
	# Hat in hands.
	if mole.visible and st.arrived(Story.MOLE) and _mole.mode == &"wait":
		_draw_bouquet(mole.position + Vector2(9, -10))
	if foreman.visible and st.arrived(Story.FOREMAN) and not _foreman_busy():
		_draw_hat(foreman.position + Vector2(-9, -9))
	if st.arrived(Story.CAVEMAN) and caveman.visible and _cave.mode == &"idle":
		for j in 2:
			var a := _t * 3.0 + j * PI
			var p := caveman.position + Vector2(cos(a) * 14.0, -24.0 + sin(a) * 6.0)
			_front.draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color(1, 1, 0.8, 0.9), 1.0)
			_front.draw_line(p - Vector2(0, 2), p + Vector2(0, 2), Color(1, 1, 0.8, 0.9), 1.0)
	if _drag.mode == &"pieces":
		_draw_pieces(_drag.t)
	if dragon.visible and (_drag.mode == &"perch" or _drag.mode == &"wait"):
		# Snore puffs.
		for j in 3:
			var k := fmod(_t * 0.35 + j / 3.0, 1.0)
			var head := dragon.position + Vector2(-44, -40) * DRAGON_SCALE
			_front.draw_arc(head + Vector2(-10 * k, -30 * k), 3.0 + 5.0 * k, 0.0, TAU, 12, Color(1, 1, 1, 0.6 * (1.0 - k)), 2.0)
	# Bubbles over heads.
	for id in _say:
		var pics := saying(id)
		var sp := sprite_of(id)
		if pics.is_empty() or sp == null or not sp.visible:
			continue
		var q: Array = _say[id]
		var left: float = q[0].t
		var a := clampf(left * 4.0, 0.0, 1.0)
		PictoBubble.draw(_front, sp.position + _head(id), pics, a, 1.0)


func _head(id: StringName) -> Vector2:
	match id:
		Story.DRAGON:
			return Vector2(-40, -58) * DRAGON_SCALE
		Story.MOLE:
			return Vector2(0, -30)
	return Vector2(0, -34)


## The shovel held like a bouquet, with three flowers.
func _draw_bouquet(at: Vector2) -> void:
	PictoBubble.picture(_front, &"shovel", at, 16.0)
	for k in 3:
		var p := at + Vector2(-6 + k * 3, -9 - (k % 2) * 3)
		_front.draw_circle(p, 2.2, [Color("ff8fb1"), GOLD, Color("8fd3f4")][k])
		_front.draw_circle(p, 0.8, Color.WHITE)


## A hard hat held in both hands.
func _draw_hat(at: Vector2) -> void:
	_front.draw_circle(at, 5.0, OUTLINE)
	_front.draw_circle(at, 4.0, GOLD)
	_front.draw_rect(Rect2(at + Vector2(-6.5, 0), Vector2(13, 2.5)), OUTLINE)
	_front.draw_rect(Rect2(at + Vector2(-5.5, 0.5), Vector2(11, 1.5)), GOLD)


## The Dragon up the shaft in three slices: head, middle, tail (the elevator was not built for her).
func _draw_pieces(t: float) -> void:
	var tex := SpriteArt.texture(DRAGON_FILE)
	if tex == null:
		return
	var fs := SpriteArt.frame_size(DRAGON_FILE)
	var w := fs.x / 3.0
	var sc := DRAGON_SCALE
	for i in 3:
		var k := clampf((t - i * 0.6) / 0.5, 0.0, 1.0)
		if k <= 0.0:
			continue
		# Rises out of the cage, then slides into place left to right; gathered by 2.4 s.
		var join := clampf((t - 2.0) / 0.4, 0.0, 1.0)
		var spread := lerpf(18.0, 0.0, join)
		var x := Hillville.SHAFT_X - fs.x * sc * 0.5 + i * w * sc + (i - 1) * spread
		var y := -fs.y * sc - 30.0 * (1.0 - k) + (1.0 - k) * 40.0 - absf(sin(t * 6.0 + i)) * 3.0 * (1.0 - join)
		_front.draw_texture_rect_region(tex, Rect2(Vector2(x, y), Vector2(w, fs.y) * sc), Rect2(i * w, 0, w, fs.y), Color(1, 1, 1, k))
