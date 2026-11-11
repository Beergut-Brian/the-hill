## The elevator (contract "Elevator rules", reworked for the 2026-11-10 playtest, PT10-9 / PT10-7b):
## standing in a cage (up top, or any landing underground) shows a blinking A over your head; **A
## rides**. Anyone else within ElevatorTuning.pull_radius_tiles of that cage (data/elevator.tres)
## is pulled along; further away they stay. Nothing starts by walking in. Underground the car
## hangs on a rope down the shaft (ShaftRope): A at a landing it is not at calls it there first
## (call_time), then the ride. The ride is RIDE_TIME (lock, sink / rise, cage flash, `elevator`
## cue). Down lands at the deepest layer any rider has visited, at that layer's landing; up empties
## the riders' backpacks into Inventory (`pile_dump`) and lands at hillville.arrival(). Every ride
## autosaves. Scripted runners (the demo, beats) set walk_in: standing DOOR_WAIT in a cage they
## have not just arrived in counts as pressing A, which is how the old cage behaved.
## S-04: on the way down the riders can pick where the cage stops with up / down while it moves
## (LayerPick shows the pictures: Hillville on top, then every layer down to the deepest rider's).
## Down from the deepest layer goes no further; up past the top layer picks Hillville, and the
## cage comes back up. Each press keeps the cage going PICK_LINGER longer (at most PICK_MAX).
## The rules live in Door (who rides, when) and destination() (where to): no scene needed.
class_name HillElevator
extends Node

signal door_started(cage: StringName, player: int)
signal ride_started(riders: Array, from: StringName)
signal ride_finished(riders: Array, to: StringName)

const DOOR_WAIT := 1.0
const RIDE_TIME := 0.6
const SINK_PX := 18.0
## After a pick press the cage keeps going this long, so a second press fits.
const PICK_LINGER := 0.7
## A ride down never lasts longer than this, however many presses.
const PICK_MAX := 4.0
## Stick past this = a press (edge-triggered).
const PICK_PRESS := 0.5
## Picture column offset from the shaft (Hillville, world px): right of the cage, top above ground.
const PICK_AT := Vector2(44, -44)
## The column's bottom stays this far above the bottom of Hillville's camera limits.
const PICK_MARGIN := 28.0   # keeps the deepest picture inside the 5% TV safe area
const HILLVILLE := &"hillville"
const UNDERGROUND := &"underground"


## The door rules, fed once a physics frame. `inside`: player -> the cage key their feet are in
## (&"" = none); `press`: player -> A pressed this frame; `near`: cage key -> players (not in a
## cage) within the pull radius of it. Returns the rides that closed this frame:
## [{cage: StringName, riders: Array[int]}]. Riders are everyone in that cage plus `near`.
class Door:
	var waiting := {}      # cage -> {t: float, riders: Array}: who stands in it, ready
	var must_exit := {}    # player -> true from arriving until they step out (walk_in only)
	var busy := {}         # player -> true while riding (or the car is on its way)
	var walk_in := false   # scripted runners: DOOR_WAIT standing in a cage = pressing A
	var _started: Array = []   # who stepped in on the last step: [[cage, player], ...]

	func step(inside: Dictionary, press: Dictionary, delta: float, near := {}) -> Array:
		for p in inside:
			if inside[p] == &"":
				must_exit.erase(p)
		for key in waiting.keys():
			var w: Dictionary = waiting[key]
			w.riders = w.riders.filter(func(p: int) -> bool: return inside.get(p, &"") == key and not busy.has(p))
			if w.riders.is_empty():
				waiting.erase(key)
		var started: Array = []
		for p in inside:
			var key: StringName = inside[p]
			if key == &"" or busy.has(p):
				continue
			if not waiting.has(key):
				waiting[key] = {"t": -delta, "riders": []}
			if not waiting[key].riders.has(p):
				waiting[key].riders.append(p)
				started.append([key, p])
		_started = started
		var closed: Array = []
		for key in waiting.keys():
			var w: Dictionary = waiting[key]
			w.t += delta
			var go := false
			for p in w.riders:
				if press.get(p, false):
					go = true
				elif walk_in and not must_exit.has(p) and w.t >= DOOR_WAIT - 0.0001:
					go = true
			if not go:
				continue
			var riders: Array = w.riders.duplicate()
			for q in near.get(key, []):
				if not riders.has(q) and not busy.has(q):
					riders.append(q)
			riders.sort()
			closed.append({"cage": key, "riders": riders})
			waiting.erase(key)
			for p in riders:
				busy[p] = true
		return closed

	## Who stepped in on the last step: [[cage, player], ...].
	func just_entered() -> Array:
		return _started

	## The ride is over: under walk_in the riders must step out before that cage takes them again.
	func arrived(riders: Array) -> void:
		for p in riders:
			busy.erase(p)
			must_exit[p] = true

	func forget(p: int) -> void:
		busy.erase(p)
		must_exit.erase(p)
		for key in waiting.keys():
			waiting[key].riders.erase(p)
			if waiting[key].riders.is_empty():
				waiting.erase(key)

	## True while someone stands in cage `key`, ready to press A.
	func is_ready(key: StringName) -> bool:
		return waiting.has(key)

	## 0..1 of the walk-in wait for a cage (0 when nobody waits); only walk_in uses it.
	func progress(key: StringName) -> float:
		if not waiting.has(key):
			return 0.0
		return clampf(waiting[key].t / DOOR_WAIT, 0.0, 1.0)


## Where a ride from `from` goes. Down: the deepest layer any rider visited. Up: Hillville.
static func destination(from: StringName, riders: Array, deepest: Dictionary) -> Dictionary:
	if from == HILLVILLE:
		var d := 0
		for p in riders:
			d = maxi(d, int(deepest.get(p, 0)))
		return {"scene": UNDERGROUND, "layer": d}
	return {"scene": HILLVILLE, "layer": -1}


static func cage_key(scene: StringName, layer: int) -> StringName:
	return HILLVILLE if scene == HILLVILLE else StringName("u%d" % layer)


## HillGame (untyped so this script stands alone).
var game: Node
var door := Door.new()
var _rides: Array = []   # {riders, from, cage, t, to}
## H-05: a ride down with the Crane aboard ends on the Crane's cable (CraneRide), made on first use.
var crane_ride: CraneRide
var tuning: ElevatorTuning = ElevatorTuning.load_default()
## PT10-7b: where the car hangs on the rope: -1 up top, else the landing (layer index).
var car_at := -1
## PT10-7b: cars on their way to a caller: {cage, riders, t, dur, from, to} (layers, -1 = top).
var _calls: Array = []
## Scripted runners (demo, beats): standing in a cage for DOOR_WAIT rides, as before PT10-9.
var walk_in: bool:
	get:
		return door.walk_in
	set(v):
		door.walk_in = v
var _rope: ShaftRope


## PT10-9: what the glyph over player p shows: 0 nothing, 1 ready (blinking A: they stand in a
## cage), 2 moving (a dim, steady A: the car is coming or they are riding).
func prompt_of(player: int) -> int:
	if door.busy.has(player):
		return 2
	for key in door.waiting:
		if door.waiting[key].riders.has(player):
			return 1
	return 0


## True when A belongs to the elevator for player p (they stand in a cage, or are riding): the
## player does not dig, scoop or build with it.
func wants_a(player: int) -> bool:
	return prompt_of(player) != 0


## Where the car is on its rope now (a layer index, fractional while it moves; -1 = up top).
func car_position() -> float:
	for c in _calls:
		var k := clampf(c.t / maxf(c.dur, 0.001), 0.0, 1.0)
		# Ease out: it rushes along the rope and slows into the landing, so the caller sees it come.
		return lerpf(float(c.from), float(c.to), 1.0 - pow(1.0 - k, 3.0))
	for r in _rides:
		var k := clampf(r.t / maxf(float(r.get("until", RIDE_TIME)), 0.001), 0.0, 1.0)
		if r.from == UNDERGROUND:
			return lerpf(float(String(r.cage).trim_prefix("u")), -1.0, k)
		return lerpf(-1.0, float(r.get("pick", r.to.layer)), k)
	return float(car_at)


func is_riding(player: int) -> bool:
	return door.busy.has(player)


func forget(player: int) -> void:
	door.forget(player)
	for r in _rides:
		r.riders.erase(player)
	for c in _calls:
		c.riders.erase(player)


## The cage key the player's feet are in, or &"".
func cage_of(player: int) -> StringName:
	var node: Node2D = game.player_node(player)
	if node == null:
		return &""
	var scene: StringName = game.director.scene_of(player)
	if scene == HILLVILLE:
		var hv: Node = game.hillville
		if hv != null and hv.has_method("cage_zone") and (hv.cage_zone() as Rect2).has_point(node.global_position):
			return HILLVILLE
	elif scene == UNDERGROUND:
		var i: int = game.underground.cage_zone_at(node.global_position)
		if i >= 0:
			return cage_key(UNDERGROUND, i)
	return &""


## Players within the pull radius of each occupied cage (not in a cage themselves, same scene):
## cage key -> [players].
func _near(inside: Dictionary) -> Dictionary:
	var out := {}
	var keys := {}
	for p in inside:
		if inside[p] != &"":
			keys[inside[p]] = p
	for key: StringName in keys:
		var scene: StringName = game.director.scene_of(keys[key])
		var rect := cage_rect_of(key)
		for q: int in game.players:
			if inside.get(q, &"") != &"" or door.busy.has(q) or game.director.scene_of(q) != scene:
				continue
			var feet: Vector2 = game.players[q].global_position
			var nearest := Vector2(clampf(feet.x, rect.position.x, rect.end.x), clampf(feet.y, rect.position.y, rect.end.y))
			if feet.distance_to(nearest) <= tuning.pull_radius_px():
				if not out.has(key):
					out[key] = []
				out[key].append(q)
	return out


## The cage's zone (global px) for a cage key.
func cage_rect_of(key: StringName) -> Rect2:
	if key == HILLVILLE:
		var hv: Node = game.hillville
		return hv.cage_zone() if hv != null and hv.has_method("cage_zone") else Rect2()
	return game.underground.cage_rect(int(String(key).trim_prefix("u")))


func check(delta: float) -> void:
	var inside := {}
	var press := {}
	for p: int in game.players:
		if door.busy.has(p):
			continue
		inside[p] = cage_of(p)
		press[p] = bool(game.players[p].get("a_press_frame"))
	for r in door.step(inside, press, delta, _near(inside)):
		_call(r.cage, r.riders)
	for e in door.just_entered():
		Audio.play("cage_door")
		door_started.emit(e[0], e[1])
	_animate_doors()
	for c in _calls.duplicate():
		_advance_call(c, delta)
	for r in _rides.duplicate():
		_advance(r, delta)
	_ensure_rope()


## PT10-7b: A was pressed in `cage`: if the car is elsewhere it comes down / up the rope first.
func _call(cage: StringName, riders: Array) -> void:
	var at := -1 if cage == HILLVILLE else int(String(cage).trim_prefix("u"))
	var dur := tuning.call_time(car_at, at)
	for p in riders:
		var node: Node = game.player_node(p)
		if node != null:
			node.locked = true
	if dur <= 0.0:
		_start(cage, riders)
		return
	Audio.play("elevator_clank")
	_calls.append({"cage": cage, "riders": riders.duplicate(), "t": 0.0, "dur": dur, "from": car_at, "to": at})


func _advance_call(c: Dictionary, delta: float) -> void:
	c.t += delta
	if c.t < c.dur:
		return
	_calls.erase(c)
	car_at = c.to
	Audio.play("elevator_ding")
	_start(c.cage, c.riders)


func _ensure_rope() -> void:
	var ug: Node = game.underground
	if ug == null or (_rope != null and is_instance_valid(_rope)):
		return
	_rope = ShaftRope.new()
	_rope.elevator = self
	ug.add_child(_rope)


func _animate_doors() -> void:
	var hv: Node = game.hillville
	var hv_wait := door.progress(HILLVILLE) if walk_in else (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)) * float(door.is_ready(HILLVILLE))
	if hv != null and "cage_flash" in hv and not _cage_busy(HILLVILLE):
		hv.cage_flash = hv_wait * 0.35
	var ug: Node = game.underground
	for i in ug.layers().size():
		var key := cage_key(UNDERGROUND, i)
		if door.waiting.has(key) and not _cage_busy(key):
			ug.flash_layer = i
			ug.cage_flash = (door.progress(key) if walk_in else 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)) * 0.35


func _cage_busy(key: StringName) -> bool:
	for r in _rides:
		if r.cage == key:
			return true
	return false


func _start(cage: StringName, riders: Array) -> void:
	var from := HILLVILLE if cage == HILLVILLE else UNDERGROUND
	var to := destination(from, riders, Progress.deepest)
	for p in riders:
		var node: Node = game.player_node(p)
		if node != null:
			node.locked = true
	Audio.play("elevator")
	var ride := {"riders": riders.duplicate(), "from": from, "cage": cage, "t": 0.0, "to": to}
	if from == HILLVILLE:
		ride.deep = int(to.layer)
		ride.pick = int(to.layer)
		ride.until = RIDE_TIME
		ride.prev = {}
		ride.pictures = _make_pictures(riders, int(to.layer))
	_rides.append(ride)
	if from == UNDERGROUND:
		game.underground.flash_layer = int(String(cage).trim_prefix("u"))
	ride_started.emit(riders, from)


func _crane_ride() -> CraneRide:
	if crane_ride == null or not is_instance_valid(crane_ride):
		crane_ride = CraneRide.new()
		crane_ride.game = game
		game.underground.add_child(crane_ride)
	return crane_ride


## The layer the current ride down will stop at for player p (-1 = Hillville), or -2 when p is
## not riding down.
func pick_of(player: int) -> int:
	for r in _rides:
		if r.has("pick") and r.riders.has(player):
			return r.pick
	return -2


## Moves the pick of player p's ride down by `dir` (+1 deeper, -1 up). True if it moved.
func nudge_pick(player: int, dir: int) -> bool:
	for r in _rides:
		if r.has("pick") and r.riders.has(player):
			return _nudge(r, dir)
	return false


func _nudge(r: Dictionary, dir: int) -> bool:
	var to := clampi(int(r.pick) + dir, -1, int(r.deep))
	var moved: bool = to != r.pick
	r.pick = to
	r.until = minf(maxf(r.until, r.t + PICK_LINGER), PICK_MAX)
	Audio.play("ui_move")
	var pics: LayerPick = r.pictures
	if pics != null and is_instance_valid(pics):
		pics.set_pick(to, moved)
	return moved


func _read_picks(r: Dictionary) -> void:
	for p in r.riders:
		var node: Node = game.player_node(p)
		if node == null or not node.has_method("intent"):
			continue
		var it: Dictionary = node.intent()
		var y: float = (it.get("move", Vector2.ZERO) as Vector2).y
		var was: float = r.prev.get(p, 0.0)
		r.prev[p] = y
		if y > PICK_PRESS and was <= PICK_PRESS:
			_nudge(r, 1)
		elif y < -PICK_PRESS and was >= -PICK_PRESS:
			_nudge(r, -1)


func _make_pictures(riders: Array, deep: int) -> LayerPick:
	var hv: Node = game.hillville
	if hv == null or game.underground == null:
		return null
	var pics := LayerPick.new()
	var all: Array = game.underground.layers()
	pics.layers = all.slice(0, clampi(deep + 1, 1, maxi(all.size(), 1)))
	pics.riders = riders.duplicate()
	pics.pick = deep
	var at: Vector2 = hv.arrival() if hv.has_method("arrival") else Vector2.ZERO
	pics.position = at + PICK_AT
	# Hillville's camera stops at its ground depth: a long column rises so its bottom stays in view.
	var limits: Rect2 = hv.get_camera_limits() if hv.has_method("get_camera_limits") else Rect2()
	if limits.size.y > 0.0:
		var bottom := pics.position.y + LayerPick.slot_y(pics.layers.size())
		pics.position.y -= maxf(0.0, bottom - (limits.end.y - PICK_MARGIN))
	hv.add_child(pics)
	return pics


func _end_pictures(r: Dictionary) -> void:
	var pics: LayerPick = r.get("pictures")
	if pics != null and is_instance_valid(pics):
		pics.queue_free()
	r.pictures = null


## Picked Hillville on the way down: the cage comes back up and everyone steps out where they were.
func _back_up(r: Dictionary) -> void:
	for p in r.riders:
		var node: Node2D = game.player_node(p)
		if node == null:
			continue
		node.ride_offset = 0.0
		node.modulate.a = 1.0
		node.locked = false
	Audio.play("cage_door")
	door.arrived(r.riders)
	car_at = -1
	var hv: Node = game.hillville
	if hv != null and "cage_flash" in hv:
		hv.cage_flash = 1.0
		var tw := hv.create_tween()
		tw.tween_property(hv, "cage_flash", 0.0, 0.3)
	ride_finished.emit(r.riders, HILLVILLE)


func _advance(r: Dictionary, delta: float) -> void:
	r.t += delta
	if r.has("pick"):
		_read_picks(r)
	var k := clampf(r.t / RIDE_TIME, 0.0, 1.0)
	var root: Node = game.hillville if r.from == HILLVILLE else game.underground
	for p in r.riders:
		var node: Node2D = game.player_node(p)
		if node == null:
			continue
		node.ride_offset = SINK_PX * k * (1.0 if r.from == HILLVILLE else -1.0)
		node.modulate.a = 1.0 - k * 0.7
	if root != null and "cage_flash" in root:
		root.cage_flash = absf(sin(k * PI * 3.0))
	if r.t < float(r.get("until", RIDE_TIME)):
		return
	_rides.erase(r)
	if root != null and "cage_flash" in root:
		root.cage_flash = 0.0
	var to: Dictionary = r.to
	if r.has("pick"):
		_end_pictures(r)
		if int(r.pick) < 0:
			_back_up(r)
			return
		to = {"scene": UNDERGROUND, "layer": int(r.pick)}
	var dumped := false
	var cable: bool = to.scene == UNDERGROUND and CraneRide.wants(game, r.riders)
	var i := 0
	for p in r.riders:
		var node: Node2D = game.player_node(p)
		if node == null:
			continue
		node.ride_offset = 0.0
		node.modulate.a = 1.0
		var pos: Vector2
		if to.scene == HILLVILLE:
			var bag: Dictionary = node.take_backpack()
			for b in bag:
				Inventory.add(StringName(b), int(bag[b]))
				dumped = true
			pos = game.hillville.arrival()
		else:
			pos = game.underground.landing(to.layer)
		pos.x += (i - (r.riders.size() - 1) * 0.5) * 14.0
		if cable:
			game.place_player(p, to.scene, CraneRide.mouth(pos))
			_crane_ride().lower(node, pos)
		else:
			game.place_player(p, to.scene, pos)
			node.locked = false
		i += 1
	if dumped:
		Audio.play("pile_dump")
	door.arrived(r.riders)
	car_at = -1 if to.scene == HILLVILLE else int(to.layer)
	var dest: Node = game.hillville if to.scene == HILLVILLE else game.underground
	if to.scene == UNDERGROUND:
		game.underground.flash_layer = to.layer
	if dest != null and "cage_flash" in dest:
		dest.cage_flash = 1.0
		var tw := dest.create_tween()
		tw.tween_property(dest, "cage_flash", 0.0, 0.3)
	ride_finished.emit(r.riders, to.scene)
	if game.has_method("autosave"):
		game.autosave()
