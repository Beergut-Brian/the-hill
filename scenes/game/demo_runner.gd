## --demo: the scripted first-playable run. HillGame adds it when Game.demo is true. It drives
## both players only through their `intent_source` (the same move / dig / jump / book / horn a pad
## gives: no teleporting, no granted blocks), from a deterministic timeline in physics time. Each
## step runs until its condition holds or its timeout passes, so it can never hang; every beat
## prints a "demo: <t> <event>" line so screenshot times can be picked.
##   P1: walks to the Front Loader and hops in, drives into the cage and rides down alone (split),
##       digs a straight shaft from Topsoil to the Clay landing, tunnels left over the Buried Car and
##       digs down onto it, rides up (the backpack dumps into the pile); more trips dig Clay until
##       the Garage is affordable, the last one breaks into the water pocket (gush). Up top P1
##       builds the Garage through the book, hops out and into the Excavator and drives it.
##   P2: scoops scrub near the shaft (rocks give stone, trees dirt) and builds the Barn.
class_name HillDemoRunner
extends Node

const P1 := 0
const P2 := 1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const KEYS := ["dig", "jump", "book", "horn"]
const TILE := 16.0
const NEAR := 4.0
const MAX_TRIPS := 4
## Plot cells: the Barn and the Garage stand in the clear yard left of the shaft.
const BARN_CELL := 32
const GARAGE_CELL := 35
## P2 scoops only left of this after the Barn stands (so A never picks the Barn up).
const SCOOP_LIMIT_X := 1470.0
const STONE_WANT := 10
## Seconds the open book and the held ghost stay on screen before A.
const BUILD_DWELL := 0.7
## P2 clears scrub between these after the Barn, then waits near the yard.
const P2_SCOOP_FROM := 1150.0
const P2_WAIT_X := 1460.0
const EXCAVATOR_SCOOP_X := 1490.0
const EXCAVATOR_PARK_X := 1700.0

## [timeout seconds]; P1's steps by name, in order (the trip loop jumps back).
const STEPS := {
	&"walk_to_loader": 8.0,
	&"drive_to_cage": 10.0,
	&"ride_down": 5.0,
	&"dig_to_clay": 30.0,
	&"tunnel_left": 25.0,
	&"dig_to_car": 12.0,
	&"farm_clay": 30.0,
	&"dig_to_water": 20.0,
	&"back_to_cage": 20.0,
	&"ride_up": 5.0,
	&"leave_cage": 6.0,
	&"build_garage": 25.0,
	&"wait_excavator": 12.0,
	&"hop_out": 3.0,
	&"into_excavator": 8.0,
	&"drive_excavator": 10.0,
	&"idle": INF,
}

## HillGame.
var game: Node
var t := 0.0
var step: StringName = &"walk_to_loader"
var step_time := 0.0
var trips := 0
var p2_mode: StringName = &"scoop"
var p2_time := 0.0
var _held := {P1: IDLE.duplicate(), P2: IDLE.duplicate()}
var _intent := {P1: IDLE.duplicate(), P2: IDLE.duplicate()}
var _pulse_at := {P1: {}, P2: {}}
var _frame := 0
var _sub := 0
var _p2_col := -1
var _ex_seen := -1.0
var _bsub := {P1: 0, P2: 0}
var _sub_t := 0.0
var _dwell := {P1: 0.0, P2: 0.0}   # time in the current build stage (book open / ghost held)
var _dwell_stage := {P1: -1, P2: -1}


func _ready() -> void:
	name = "DemoRunner"
	log_event("start: %s" % step)


func log_event(what: String) -> void:
	print("demo: %6.2f %s" % [t, what])


func intent_for(player: int) -> Dictionary:
	return _intent.get(player, IDLE)


func _physics_process(delta: float) -> void:
	_frame += 1
	t += delta
	_hook_players()
	var p1: HillPlayer = game.player_node(P1)
	var p2: HillPlayer = game.player_node(P2)
	for p in [P1, P2]:
		_held[p] = IDLE.duplicate()
	if p1 != null:
		step_time += delta
		var done := _drive_p1(p1)
		if not done and step_time >= float(STEPS[step]):
			log_event("timeout in %s" % step)
			done = true
		if done:
			_next(_after(step))
	if p2 != null:
		p2_time += delta
		_drive_p2(p2)
	for p in [P1, P2]:
		_intent[p] = _held[p]


func _hook_players() -> void:
	for p in [P1, P2]:
		var node: HillPlayer = game.player_node(p)
		if node != null and not node.intent_source.is_valid():
			node.intent_source = intent_for.bind(p)


func _next(s: StringName) -> void:
	if s == step:
		return
	step = s
	step_time = 0.0
	_sub = 0
	log_event(String(s))


# --- P1 ----------------------------------------------------------------------------------------

## The step after `s` (the trip loop decides here).
func _after(s: StringName) -> StringName:
	match s:
		&"walk_to_loader": return &"drive_to_cage"
		&"drive_to_cage": return &"ride_down"
		&"ride_down":
			if trips == 0:
				return &"dig_to_clay"
			return &"farm_clay"
		&"dig_to_clay": return &"tunnel_left"
		&"tunnel_left": return &"dig_to_car"
		&"dig_to_car": return &"back_to_cage"
		&"farm_clay":
			return &"dig_to_water" if not _gushed() and _will_afford() else &"back_to_cage"
		&"dig_to_water": return &"back_to_cage"
		&"back_to_cage": return &"ride_up"
		&"ride_up":
			trips += 1
			log_event("pile: dirt %d clay %d stone %d" % [Inventory.count(&"dirt"), Inventory.count(&"clay"), Inventory.count(&"stone")])
			return &"leave_cage"
		&"leave_cage":
			if _garage_ready() or trips >= MAX_TRIPS:
				return &"build_garage"
			return &"drive_to_cage"
		&"build_garage": return &"wait_excavator"
		&"wait_excavator": return &"hop_out"
		&"hop_out": return &"into_excavator"
		&"into_excavator": return &"drive_excavator"
		&"drive_excavator":
			log_event("done: car %s, barn %d, garage %d, excavator %s" % [Progress.has_treasure(&"buried_car"),
				Progress.count_buildings(&"barn"), Progress.count_buildings(&"garage"), Progress.has_vehicle(&"excavator")])
			return &"idle"
	return &"idle"


## Sets P1's intent for this step; true when the step's condition holds.
func _drive_p1(p1: HillPlayer) -> bool:
	var d: ScreenDirector = game.director
	var ug: Underground = game.underground
	var el: HillElevator = game.elevator
	match step:
		&"walk_to_loader":
			var lx: float = game.loader_position().pos.x
			if _go_to(P1, p1, _hv_x(p1), lx - 18.0):
				_pulse(P1, "jump")
			return game.drivers.get(HillGame.LOADER, -1) == P1
		&"drive_to_cage":
			_go_to(P1, p1, _hv_x(p1), Hillville.SHAFT_X)
			return el.is_riding(P1)
		&"ride_down":
			return d.scene_of(P1) == HillGame.UNDERGROUND and not el.is_riding(P1)
		&"dig_to_clay":
			# A straight shaft down the left side of the landing room, Topsoil to the Clay landing.
			var lp := _ug_pos(p1)
			if _sub == 0:
				if _go_to(P1, p1, lp.x, _room_left_x() + 32.0):
					_sub = 1
				return false
			_hold(P1, Vector2.DOWN, true)
			return lp.y >= ug.landing(_clay()).y - 4.0 and p1.is_on_floor()
		&"tunnel_left":
			# Left along the Clay landing's floor, over the Buried Car (too high to find it yet).
			var target := _car_dig_x()
			var lp := _ug_pos(p1)
			if lp.x > target + NEAR:
				_hold(P1, Vector2.LEFT, true)
				return false
			return _go_to(P1, p1, lp.x, target)
		&"dig_to_car":
			var lp := _ug_pos(p1)
			if not Progress.has_treasure(&"buried_car"):
				if _go_to(P1, p1, lp.x, _car_dig_x()):
					_hold(P1, Vector2.DOWN, true)
				return false
			if _sub == 0:
				log_event("buried car found")
				_sub = 1
			return step_time > 1.0
		&"farm_clay":
			# Through the tunnel and on into fresh Clay until the pile + backpack pay for a Garage.
			_hold(P1, Vector2.LEFT, true)
			return _will_afford() or p1.is_full()
		&"dig_to_water":
			_hold(P1, Vector2.RIGHT, true)
			if _gushed():
				if _sub == 0:
					log_event("water gush")
					_sub = 1
				_hold(P1, Vector2.ZERO)
				return step_time > 0.6
			return false
		&"back_to_cage":
			if d.scene_of(P1) != HillGame.UNDERGROUND:
				return true
			var lp := _ug_pos(p1)
			_go_to(P1, p1, lp.x, (HillGenerator.SHAFT_X + 1) * TILE)
			return el.is_riding(P1)
		&"ride_up":
			return d.scene_of(P1) == HillGame.HILLVILLE and not el.is_riding(P1)
		&"leave_cage":
			# Out of the cage (it re-arms only once you step out), toward the yard.
			return _go_to(P1, p1, _hv_x(p1), _feet_for(GARAGE_CELL, 3, -1), -1)
		&"build_garage":
			return _build(P1, p1, &"garage", GARAGE_CELL, -1)
		&"wait_excavator":
			if game.vehicles.has(&"excavator"):
				if _ex_seen < 0.0:
					_ex_seen = step_time
					log_event("excavator rolls out")
				return step_time - _ex_seen > 1.6
			return false
		&"hop_out":
			if p1.vehicle != null:
				_pulse(P1, "jump")
				return false
			return step_time > 0.4
		&"into_excavator":
			var v: Vehicle = game.vehicles.get(&"excavator")
			if v == null:
				return true
			if _go_to(P1, p1, _hv_x(p1), v.position.x + 6.0):
				_pulse(P1, "jump")
			return game.drivers.get(&"excavator", -1) == P1
		&"drive_excavator":
			# A little spin: left to the scrub past the Barn, a scoop, then back to the Garage.
			var x := _hv_x(p1)
			match _sub:
				0:
					if _go_to(P1, p1, x, EXCAVATOR_SCOOP_X, -1):
						_sub = 1
						_sub_t = step_time
				1:
					_hold(P1, Vector2.ZERO, true)
					if step_time - _sub_t > 1.5:
						_sub = 2
				2:
					return _go_to(P1, p1, x, EXCAVATOR_PARK_X)
			return false
		&"idle":
			if fmod(step_time, 6.0) < 0.05:
				_pulse(P1, "horn")
			return false
	return true


# --- P2 ----------------------------------------------------------------------------------------

func _drive_p2(p2: HillPlayer) -> void:
	var x := _hv_x(p2)
	if game.director.scene_of(P2) != HillGame.HILLVILLE:
		return
	match p2_mode:
		&"scoop":
			var barn := Progress.building_data(&"barn")
			if Progress.count_buildings(&"barn") == 0 and Inventory.count(&"stone") >= STONE_WANT \
					and barn != null and Inventory.can_afford(barn.cost):
				_p2_to(&"barn")
				return
			var kinds := [Hillville.Scrub.ROCK] if Inventory.count(&"stone") < STONE_WANT else [Hillville.Scrub.TREE, Hillville.Scrub.STUMP]
			var limit := SCOOP_LIMIT_X if Progress.count_buildings(&"barn") > 0 else BARN_CELL * Hillville.PLOT - 2.0
			_scoop_kind(p2, x, kinds, limit)
		&"barn":
			if _build(P2, p2, &"barn", BARN_CELL, 1):
				_p2_to(&"after_barn")
			elif p2_time > 20.0:
				log_event("P2 timeout building the barn")
				_p2_to(&"after_barn")
		&"after_barn":
			# Keeps clearing scrub just left of the Barn, then waits by the yard: a horn, a hop.
			if not _scoop_kind(p2, x, [Hillville.Scrub.ROCK, Hillville.Scrub.TREE, Hillville.Scrub.STUMP], SCOOP_LIMIT_X, P2_SCOOP_FROM):
				if _go_to(P2, p2, x, P2_WAIT_X, 1) and fmod(p2_time, 5.0) < 0.05:
					_pulse(P2, "jump")
			if fmod(p2_time, 7.0) < 0.05:
				_pulse(P2, "horn")


func _p2_to(m: StringName) -> void:
	p2_mode = m
	p2_time = 0.0
	_p2_col = -1
	log_event("P2 %s" % m)


## Walks to the nearest scrub column of `kinds` in [from, limit) and holds A until it is clear;
## false when there is none left there.
func _scoop_kind(pl: HillPlayer, x: float, kinds: Array, limit: float, from := 0.0) -> bool:
	var hv: Hillville = game.hillville
	if _p2_col < 0 or hv.scrub_at(_p2_col) == 0:
		_p2_col = -1
		var best := INF
		for c in range(int(from / TILE), int(limit / TILE)):
			if hv.scrub_at(c) > 0 and kinds.has(hv.scrub_kind(c)) and c * TILE + 8.0 < limit:
				var dx := absf(c * TILE + 8.0 - x)
				if dx < best:
					best = dx
					_p2_col = c
		if _p2_col < 0:
			return false
	var cx := _p2_col * TILE + 8.0
	if _go_to(P2, pl, x, cx):
		_hold(P2, Vector2.ZERO, true)
	return true


# --- building through the book -----------------------------------------------------------------

## X, steer to the card, A (pays, ghost), walk to the plot facing `face`, A. True once placed.
func _build(p: int, pl: HillPlayer, id: StringName, cell: int, face: int) -> bool:
	var build: BuildController = game.build
	var d := Progress.building_data(id)
	var before := Progress.count_buildings(id)
	if before > 0 and not build.has_ghost(p):
		if _bsub[p] == 0:
			_bsub[p] = 1
			var at := -1
			for b in Progress.buildings:
				if b.id == id:
					at = b.cell.x
			log_event("P%d placed the %s at cell %d" % [p + 1, id, at])
		return true
	var x := _hv_x(pl)
	var feet := _feet_for(cell, d.footprint.x, face)
	if build.has_ghost(p):
		# Show the ghost a moment before it drops.
		if _go_to(p, pl, x, feet, face) and _dwelt(p, 2, BUILD_DWELL):
			_pulse(p, "dig")
		return false
	if not build.captures(p):
		_dwelt(p, 0, 0.0)
		if not Inventory.can_afford(d.cost):
			return false
		if _go_to(p, pl, x, feet, face):
			_pulse(p, "book")
		return false
	var book := build.book_of(p)
	if book == null:
		return false
	if not _dwelt(p, 1, BUILD_DWELL):
		return false
	if book.focused_id() != id:
		_held[p].move = Vector2.RIGHT if _frame % 10 < 5 else Vector2.ZERO
		return false
	_pulse(p, "dig")
	return false


## True once player p has been in build `stage` for `secs` (a new stage restarts the clock).
func _dwelt(p: int, stage: int, secs: float) -> bool:
	if _dwell_stage[p] != stage:
		_dwell_stage[p] = stage
		_dwell[p] = 0.0
	_dwell[p] += get_physics_process_delta_time()
	return _dwell[p] >= secs


# --- helpers -----------------------------------------------------------------------------------

## Feet x that puts a `width`-cell ghost exactly on `cell` when facing `face` (BuildController.plot_cell_for).
static func _feet_for(cell: int, width: int, face: int) -> float:
	return cell * Hillville.PLOT + width * Hillville.PLOT * 0.5 - face * Hillville.PLOT * (1.0 + width * 0.5)


func _hv_x(pl: Node2D) -> float:
	return (game.hillville as Node2D).to_local(pl.global_position).x


func _ug_pos(pl: Node2D) -> Vector2:
	return (game.underground.world as Node2D).to_local(pl.global_position)


func _clay() -> int:
	var ls: Array = game.underground.layers()
	for i in ls.size():
		if (ls[i] as LayerData).id == &"clay":
			return i
	return 1


func _room_left_x() -> float:
	return float(HillGenerator.SHAFT_X - HillGenerator.ROOM_HALF) * TILE


func _car_rect() -> Rect2i:
	for s in game.underground.generator.treasure_spots:
		if s.id == &"buried_car":
			return s.rect
	return Rect2i(80, 36, 3, 2)


## Where the Loader digs down onto the car: just right of its cavity, still within reach of it.
func _car_dig_x() -> float:
	var r := _car_rect()
	return float(r.end.x + 2) * TILE


func _gushed() -> bool:
	var ug: Underground = game.underground
	return ug.is_gushing() or bool(ug._gush.done)


func _garage_ready() -> bool:
	var g := Progress.building_data(&"garage")
	return Progress.has_treasure(&"buried_car") and g != null and Inventory.can_afford(g.cost)


## The pile plus P1's backpack pays for the Garage.
func _will_afford() -> bool:
	var g := Progress.building_data(&"garage")
	var p1: HillPlayer = game.player_node(P1)
	if g == null or p1 == null:
		return true
	for b in g.cost:
		if Inventory.count(b) + int(p1.backpack.get(b, 0)) < int(g.cost[b]):
			return false
	return true


## Moves toward `target` x; true when there (and facing `face`, if given).
func _go_to(p: int, pl: HillPlayer, x: float, target: float, face := 0) -> bool:
	var dx := target - x
	if absf(dx) > NEAR:
		_held[p].move = Vector2(signf(dx), 0.0)
		return false
	if face != 0 and pl.facing != face:
		_held[p].move = Vector2(face * 0.25, 0.0)
		return false
	return true


func _hold(p: int, move: Vector2, dig := false) -> void:
	_held[p].move = move
	_held[p].dig = dig


## One frame of a button, never two frames running (HillPlayer derives presses from edges).
func _pulse(p: int, key: String) -> void:
	var last: int = _pulse_at[p].get(key, -100)
	if _frame - last < 4:
		return
	_pulse_at[p][key] = _frame
	_held[p][key] = true
