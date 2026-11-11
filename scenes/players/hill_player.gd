## A player in The Hill: a 12 x 28 px capsule in the player's colour with a hard hat, origin at the
## feet; while driving, the node *is* the vehicle (its box, wheels and collision; speed from
## VehicleData; no jump), so the elevator and the director need nothing special.
## Driven by an intent {move: Vector2, dig: bool, jump: bool, book: bool, horn: bool} (held states)
## read each physics frame from `intent_source` (default: this player's pad / keys); presses are
## derived here. Up top (world == null): A asks game.build.action() first, else scoops scrub; X opens
## the build book; while the book captures the player, input goes to it. Underground: A digs in the
## aimed direction (forgiving, hold to keep digging), gravity from the world, water lifts.
## B: cancel a ghost, else hop out / hop in (within HOP_REACH of a parked vehicle), else jump.
## Y: the horn. Always. Does nothing else.
class_name HillPlayer
extends CharacterBody2D

signal swung(cell: Vector2i)       # a dig that found nothing to remove
signal honked()

const WIDTH := 12.0
const HEIGHT := 28.0
const WALK := 200.0
## V-07: a scoop clearing this many tiles or more is "big" and kicks the view.
const BIG_SCOOP := 3
const JUMP := 300.0          # about 46 px: clears 2 tiles
const GRAVITY := 980.0       # up top only; underground asks the world
const DIG_EVERY := 0.14
const VEHICLE_DIG_EVERY := 0.22
const SCOOP_EVERY := 0.35
## B-06: per Workshop level (Progress.tool_level()), digging this much quicker and vehicles this
## much faster; level 1+ also gives the bigger shovel (one more cell per dig on foot).
const TOOL_DIG := 0.35
const TOOL_DRIVE := 0.15
const WATER_DAMP := 5.0
const PUSH := 12.0
const HOP_REACH := 24.0
## PT10-6: the stick must be this far sideways (and clearly more sideways than up / down) to turn,
## so aiming down with a wobbly stick never flips the character back and forth.
const TURN_X := 0.35
## PT10-6: the aim keeps its axis until the other axis is clearly stronger (stick wobble).
const AIM_KEEP := 0.7
## PT10-7a: climbing onto a carved step takes this long (s).
const CLIMB_TIME := 0.18
## PT10-6: how fast the dig marker slides to a new cell (1/s).
const MARK_EASE := 30.0
## PT10-9: in the elevator's cage A rides unless the stick pushes this far sideways (then A digs
## your way out of the landing as usual).
const LIFT_SIDE := 0.5
const STEP_UP := 17.0
const DARK := Color(0.07, 0.06, 0.09)
const HAT := Color("f2c94c")

var player := 0
## HillGame (untyped so this script stands alone in tests).
var game: Node
var world: TileWorld
var locked := false
## The stick this physics frame (zero while locked); the camera lead reads it (S-06).
var move_intent := Vector2.ZERO
var intent_source := Callable()
var facing := 1
var ride_offset := 0.0
## The vehicle being driven, null on foot.
var vehicle: VehicleData
## What only that vehicle does (tip, hook, auto_drill), or null.
var ability: VehicleAbility
## block id -> count. Emptied into Inventory by the elevator going up.
var backpack: Dictionary = {}
## A was pressed this physics frame (the elevator reads it: A skips the door wait).
var a_press_frame := false

var _shape: CollisionShape2D
var _squash := 0.0
var _swing := 0.0
var _honk := 0.0
## H-03: the Excavator turns all the way round on the horn (1 -> 0 over CAB_SPIN seconds).
const CAB_SPIN := 0.7
var cab_spin := 0.0
var _full_pop := 0.0
## B-06: the Workshop's upgrade pop over the head (1 -> 0) and the bigger shovel's glint.
var tool_pop := 0.0
var _glint := 0.0
var _dig_cd := 0.0
var _dig_used := false
var _b_used := false
var _aim := 0.0
## PT10-6: the dig direction this frame (sticky, see aim_of) and the marker (world-local rect of
## the cells the next dig takes; size 0 = nothing to dig there).
var aim := Vector2i(1, 0)
var _mark := Rect2()
var _mark_shown := Rect2()
var _mark_hot := false
## PT10-7a: a climb onto a step in progress: {from, to, t} (global px), or {}.
var _climb := {}
var _a_after_lock := false
var _in_water := false
var _prev := {}
var _t := 0.0


## One upgrade sound per Workshop placement, however many players see the pop.
static var _tool_sound_frame := -1


func _enter_tree() -> void:
	var ev := get_node_or_null(^"/root/Events")
	if ev != null and not ev.building_placed.is_connected(_on_building_placed):
		ev.building_placed.connect(_on_building_placed)


func _exit_tree() -> void:
	var ev := get_node_or_null(^"/root/Events")
	if ev != null and ev.building_placed.is_connected(_on_building_placed):
		ev.building_placed.disconnect(_on_building_placed)


func _on_building_placed(id: StringName, _cell: Vector2i) -> void:
	var pr := get_node_or_null(^"/root/Progress")
	var d: BuildingData = pr.building_data(id) if pr != null else null
	if d == null or d.effect != &"dig_power":
		return
	show_tool_upgrade()
	if _tool_sound_frame != Engine.get_physics_frames():
		_tool_sound_frame = Engine.get_physics_frames()
		Audio.play("tool_upgrade")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	_shape = CollisionShape2D.new()
	add_child(_shape)
	_apply_shape()
	VehicleGlow.attach(self)


func _apply_shape() -> void:
	if _shape == null:
		return
	if vehicle == null:
		var cap := CapsuleShape2D.new()
		cap.radius = WIDTH * 0.5
		cap.height = HEIGHT
		_shape.shape = cap
		_shape.position = Vector2(0, -HEIGHT * 0.5)
	else:
		var s := Vehicle.body_size(vehicle)
		var rect := RectangleShape2D.new()
		rect.size = s - Vector2(0, 1)
		_shape.shape = rect
		_shape.position = Vector2(0, -s.y * 0.5)


func body_size() -> Vector2:
	return Vehicle.body_size(vehicle)


# --- backpack (contract "Backpack") ------------------------------------------------------------

func backpack_count() -> int:
	var n := 0
	for k in backpack:
		n += int(backpack[k])
	return n


func capacity() -> int:
	return int(Progress.backpack_capacity() * (vehicle.carry if vehicle != null else 1.0))


func is_full() -> bool:
	return backpack_count() >= capacity()


## Keeps a dug block; false when the backpack is full (the block is not kept, digging goes on).
func keep_block(block: StringName) -> bool:
	if is_full():
		_full_pop = 1.0
		return false
	backpack[block] = int(backpack.get(block, 0)) + 1
	if is_full():
		_full_pop = 1.0
	return true


## Empties the backpack and returns what was in it.
func take_backpack() -> Dictionary:
	var out := backpack
	backpack = {}
	if ability != null and not out.is_empty():
		ability.on_dump()
	return out


# --- for B and the game ------------------------------------------------------------------------

func honk() -> void:
	var cue := "horn"
	if vehicle != null and vehicle.sounds.has(&"horn"):
		cue = String(vehicle.sounds[&"horn"])
	Audio.play(cue)
	_honk = 1.0
	if vehicle != null and vehicle.id == &"excavator" and cab_spin <= 0.0:
		cab_spin = 1.0
	honked.emit()


func bump() -> void:
	_squash = 1.0


## Starts driving `d` (the game removed the parked node).
func drive(d: VehicleData) -> void:
	vehicle = d
	ability = VehicleAbility.make(self, d)
	_apply_shape()
	_squash = 1.0


## Back on foot; returns what was driven.
func stop_driving() -> VehicleData:
	var d := vehicle
	if ability != null:
		ability.stop()
	ability = null
	vehicle = null
	_apply_shape()
	_squash = 1.0
	return d


func intent() -> Dictionary:
	if intent_source.is_valid():
		return intent_source.call()
	return {
		"move": Players.move_vector(player),
		"dig": Input.is_action_pressed(Players.action(player, "action")),
		"jump": Input.is_action_pressed(Players.action(player, "jump")),
		"book": Input.is_action_pressed(Players.action(player, "book")),
		"horn": Input.is_action_pressed(Players.action(player, "horn")),
	}


func gravity() -> Vector2:
	if world != null and world.shape != null:
		return world.shape.gravity_at(world.to_local(global_position))
	return Vector2(0.0, GRAVITY)


func in_water() -> bool:
	return _in_water


func _build() -> Object:
	if world != null or game == null:
		return null
	return game.get("build")


func _pressed(it: Dictionary, key: String) -> bool:
	return bool(it.get(key, false)) and not bool(_prev.get(key, false))


# --- frame -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_swing = move_toward(_swing, 0.0, delta * 6.0)
	_honk = move_toward(_honk, 0.0, delta * 2.5)
	cab_spin = move_toward(cab_spin, 0.0, delta / CAB_SPIN)
	_full_pop = move_toward(_full_pop, 0.0, delta * 3.0)
	tool_pop = move_toward(tool_pop, 0.0, delta * 0.6)
	_glint = move_toward(_glint, 0.0, delta * 5.0)
	queue_redraw()
	if locked:
		velocity = Vector2.ZERO
		_a_after_lock = true
		_prev = {}
		move_intent = Vector2.ZERO
		a_press_frame = false
		return
	if not _climb.is_empty():
		_climb_step(delta)
		return
	var it := intent()
	var move: Vector2 = it.get("move", Vector2.ZERO)
	var a_press := _pressed(it, "dig")
	# PT10-9: A still held from before a ride (or any lock) is not a new press for the elevator.
	if not it.get("dig", false):
		_a_after_lock = false
	a_press_frame = a_press and not _a_after_lock and absf(move.x) < LIFT_SIDE
	var b_press := _pressed(it, "jump")
	var x_press := _pressed(it, "book")
	var y_press := _pressed(it, "horn")
	_prev = it.duplicate()
	move_intent = move
	if not it.get("jump", false):
		_b_used = false
	if y_press:
		honk()
	# PT10-9: in the elevator's cage, A rides (the elevator reads a_press_frame): no dig, no build.
	if _lift_wants_a():
		if a_press:
			_dig_used = true
		a_press = false
	if ability != null:
		ability.step(delta, it, a_press)
	var build := _build()
	if build != null and build.captures(player):
		if x_press:
			build.book_pressed(player)
		else:
			build.book_input(player, move, a_press, b_press)
		_dig_used = true
		_b_used = true
		_fall_only(delta)
		return
	if x_press and build != null:
		build.book_pressed(player)
		_fall_only(delta)
		return
	if b_press:
		_b_used = _on_b(build)
	var g := gravity()
	up_direction = -g.normalized() if g != Vector2.ZERO else Vector2.UP
	var side := Vector2(-up_direction.y, up_direction.x)
	if absf(move.x) > TURN_X and absf(move.x) > absf(move.y) * AIM_KEEP:
		var want := 1 if move.x > 0.0 else -1
		if ability == null or ability.allow_turn(want, delta):
			facing = want
	aim = aim_of(move, aim)
	_aim = float(aim.y)
	var speed := vehicle.speed * (ability.speed_scale() if ability != null else 1.0) * drive_scale() if vehicle != null else WALK
	velocity = side * move.x * speed + up_direction * velocity.dot(up_direction)
	var lift := Vector2.ZERO
	if world != null:
		lift = world.buoyancy_at(world.to_local(global_position + up_direction * body_size().y * 0.5))
	var wet := lift != Vector2.ZERO
	if wet != _in_water:
		_in_water = wet
		if wet:
			Audio.play("splash")
			_squash = 1.0
	velocity += (g + lift) * delta
	if wet:
		velocity *= maxf(0.0, 1.0 - WATER_DAMP * delta)
	if on_ladder():
		# PT10-7c: on a ladder up / down climbs and letting go hangs (no gravity).
		var speed_l: float = game.ladders.climb_speed
		var vy := move.y * speed_l if absf(move.y) > 0.3 else 0.0
		if vy != 0.0 or not is_on_floor():
			velocity = side * velocity.dot(side) + up_direction * -vy
			if vy != 0.0 and fmod(_t, 0.25) < delta:
				Audio.play("ui_move")
	if vehicle == null and it.get("jump", false) and not _b_used and is_on_floor():
		velocity = side * velocity.dot(side) + up_direction * JUMP
		_squash = 1.0
		Audio.play("jump")
	move_and_slide()
	if vehicle != null:
		_step_up(move)
	_push_bodies(move)
	# H-05: the Crane's A up top is the wrecking ball unless it lifts / sets down a building.
	var a_claimed := ability != null and ability.claims_a(move, build)
	if a_press and build != null and not a_claimed and build.action(player):
		_dig_used = true
	if not it.get("dig", false):
		_dig_used = false
		_dig_cd = 0.0
	elif not _dig_used:
		_dig_cd -= delta
		if _dig_cd <= 0.0:
			_dig_cd = SCOOP_EVERY if world == null else dig_every()
			_dig(move)
	_update_marker(delta, bool(it.get("dig", false)))


func _lift_wants_a() -> bool:
	if absf(move_intent.x) >= LIFT_SIDE:
		return false
	var el: Object = game.get("elevator") if game != null else null
	return el != null and el.has_method("wants_a") and bool(el.wants_a(player))


## True when A rides the elevator right now (in a cage, stick not pushed sideways, not riding).
func lift_ready() -> bool:
	return lift_prompt() == 1 and absf(move_intent.x) < LIFT_SIDE


## PT10-9: the elevator's prompt over this player: 0 none, 1 ready (blink), 2 moving (dim).
func lift_prompt() -> int:
	var el: Object = game.get("elevator") if game != null else null
	return int(el.prompt_of(player)) if el != null and el.has_method("prompt_of") else 0


## False while the story says this player has no shovel (the Mole took it): no digging on foot.
## Reads the story lane's `has_shovel` / `can_dig` flags if they exist (null = not there = true).
func shovel_ok() -> bool:
	if vehicle != null:
		return true
	for flag in ["has_shovel", "can_dig"]:
		var v: Variant = get(flag)
		if v != null and not bool(v):
			return false
	return true


## PT10-6: the cells the next dig takes (solid, diggable at this tier), or [] when it would only
## swing at air. The marker draws exactly these.
func dig_targets(at_aim: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if world == null:
		return out
	var tier := vehicle.dig_tier if vehicle != null else 0
	for c in dig_cells(at_aim):
		if not world.is_solid(c):
			continue
		var def := world.tile_def(world.get_tile(c))
		if def is BlockData and (def as BlockData).dig_tier > tier and def.breakable:
			continue
		out.append(c)
	return out


## The first cell the marker shows (tests and the beat log), or (-9999, -9999) when none.
func dig_marker_cell() -> Vector2i:
	if _mark.size == Vector2.ZERO:
		return Vector2i(-9999, -9999)
	return world.shape.cell_at(_mark.position + Vector2.ONE)


func _update_marker(delta: float, held: bool) -> void:
	_mark_hot = held
	if world == null or locked or not shovel_ok():
		_mark = Rect2()
		_mark_shown = Rect2()
		return
	var cells := step_cells() if is_stepping_aim() else dig_targets(aim)
	if is_stepping_aim() and cells.is_empty():
		# All carved: mark the spot on the step where the climb lands.
		var g := _step_geometry(_step_dir())
		if world.is_solid(Vector2i(g.front, g.row)):
			cells = [Vector2i(g.front, g.row - 2), Vector2i(g.front, g.row - 1)]
	if cells.is_empty():
		_mark = Rect2()
		_mark_shown = Rect2()
		return
	var cs := float(world.shape.cell_size)
	var r := Rect2(Vector2(cells[0]) * cs, Vector2(cs, cs))
	for c in cells:
		r = r.merge(Rect2(Vector2(c) * cs, Vector2(cs, cs)))
	if _mark_shown.size == Vector2.ZERO or _mark.size == Vector2.ZERO:
		_mark_shown = r
	_mark = r
	var k := 1.0 - exp(-MARK_EASE * delta)
	_mark_shown = Rect2(_mark_shown.position.lerp(r.position, k), _mark_shown.size.lerp(r.size, k))


## Seconds between digs underground (quicker with each Workshop level).
func dig_every() -> float:
	return (DIG_EVERY if vehicle == null else VEHICLE_DIG_EVERY) / (1.0 + TOOL_DIG * _tool_level())


## Vehicle speed multiplier from the Workshop.
func drive_scale() -> float:
	return 1.0 + TOOL_DRIVE * _tool_level()


## True on foot once a Workshop stands: each dig takes one more cell in the aimed direction.
func has_big_shovel() -> bool:
	return vehicle == null and _tool_level() > 0


func _tool_level() -> int:
	var pr := get_node_or_null(^"/root/Progress")
	return int(pr.call("tool_level")) if pr != null and pr.has_method("tool_level") else 0


## B-06: a Workshop was just built; show the bigger shovel popping over the head.
func show_tool_upgrade() -> void:
	tool_pop = 1.0
	_squash = 1.0


func _fall_only(delta: float) -> void:
	velocity = Vector2(0.0, velocity.y) + gravity() * delta
	move_and_slide()


## B: cancel a ghost, else hop out, else hop in; true if the press was used (no jump).
func _on_b(build: Object) -> bool:
	if build != null and build.has_ghost(player) and build.cancel(player):
		return true
	if game == null:
		return false
	if vehicle != null:
		game.hop_out(self)
		return true
	return game.hop_in(self)


## Vehicles drive over anything: a 1-tile step in front lifts them up onto it.
func _step_up(move: Vector2) -> void:
	if absf(move.x) < 0.2 or not is_on_floor() or not is_on_wall():
		return
	var up := up_direction * STEP_UP
	var fwd := Vector2(-up_direction.y, up_direction.x) * signf(move.x) * 4.0
	if test_move(global_transform, up):
		return
	if test_move(global_transform.translated(up), fwd):
		return
	global_position += up


## A fallen boulder never blocks a kid: walking into a FallingBody shoves it along.
func _push_bodies(move: Vector2) -> void:
	if absf(move.x) < 0.2:
		return
	var side := Vector2(-up_direction.y, up_direction.x) * signf(move.x)
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as FallingBody
		if body != null and body.linear_velocity.dot(side) < WALK * 0.5:
			body.sleeping = false
			body.apply_central_impulse(side * PUSH * body.mass)


# --- digging -----------------------------------------------------------------------------------

## The dig direction for a stick. `prev` (the last aim) makes it sticky: an aim keeps its axis
## while that axis is still pushed and the other is not clearly stronger (PT10-6, no flicker
## between digging down and sideways on a diagonal).
func aim_of(move: Vector2, prev := Vector2i.ZERO) -> Vector2i:
	var ax := absf(move.x)
	var ay := absf(move.y)
	if prev.y != 0 and ay > 0.3 and ax < ay / AIM_KEEP:
		return Vector2i(0, 1 if move.y > 0.0 else -1)
	if prev.x != 0 and ax > 0.3 and ay < ax / AIM_KEEP:
		return Vector2i(1 if move.x > 0.0 else -1, 0)
	if ay > ax and ay > 0.2:
		return Vector2i(0, 1 if move.y > 0.0 else -1)
	if ax > 0.2:
		return Vector2i(1 if move.x > 0.0 else -1, 0)
	return Vector2i(facing, 0)


func _dig(move: Vector2) -> void:
	if ability != null and ability.on_dig(move):
		return
	if not shovel_ok():
		return
	if is_stepping_aim():
		step_dig()
		return
	dig_now(move)


# --- PT10-7a: dig your way up --------------------------------------------------------------------

## True when A now carves a step up instead of digging: on foot, underground, stick up or
## diagonal-up.
func is_stepping_aim() -> bool:
	return vehicle == null and world != null and move_intent.y < -0.3


## The step toward `dir`: {cols: body columns, front: column, row: feet row} (cells).
func _step_geometry(dir: int) -> Dictionary:
	var s := world.shape
	var p := world.to_local(global_position)
	var hw := body_size().x * 0.5
	var row := s.cell_at(p - Vector2(0, 1)).y
	var c0 := s.cell_at(Vector2(p.x - hw + 0.5, p.y - 1)).x
	var c1 := s.cell_at(Vector2(p.x + hw - 0.5, p.y - 1)).x
	var front := (c1 if dir > 0 else c0) + dir
	return {"cols": range(c0, c1 + 1), "front": front, "row": row}


## The cells still in the way of a step up toward `facing`, in carving order: the rock over the
## head, then the two cells over the step in front. The step itself (front, row) is kept.
func step_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if world == null:
		return out
	var g := _step_geometry(_step_dir())
	var want: Array[Vector2i] = []
	for c: int in g.cols:
		want.append(Vector2i(c, g.row - 2))
	want.append(Vector2i(g.front, g.row - 2))
	want.append(Vector2i(g.front, g.row - 1))
	for c in want:
		if world.is_solid(c):
			out.append(c)
	return out


## The way a step goes: the stick's side on a diagonal; straight up, the way you face, or the
## other way when only that side has a block at your feet to step onto.
func _step_dir() -> int:
	if absf(move_intent.x) > TURN_X:
		return 1 if move_intent.x > 0.0 else -1
	if world != null:
		var g := _step_geometry(facing)
		if not world.is_solid(Vector2i(g.front, g.row)):
			var o := _step_geometry(-facing)
			if world.is_solid(Vector2i(o.front, o.row)):
				return -facing
	return facing


## One A tick of a step up: carve the cells in the way, or (all clear and a block to stand on
## in front) climb onto it. True when something happened.
func step_dig() -> bool:
	_swing = 1.0
	var cells := step_cells()
	if not cells.is_empty():
		# One swing carves the whole step (the dig lane's speed applies per swing).
		for c in cells:
			var def := world.tile_def(world.get_tile(c))
			if def == null or not def.breakable or (def is BlockData and (def as BlockData).dig_tier > 0):
				swung.emit(c)
				return false
		var offsets: Array[Vector2i] = []
		for c in cells:
			offsets.append(c - cells[0])
		world.dig(cells[0], offsets, player)
		_squash = maxf(_squash, 0.4)
		return true
	var g := _step_geometry(_step_dir())
	if not world.is_solid(Vector2i(g.front, g.row)) or not (is_on_floor() or _in_water):
		swung.emit(Vector2i(g.front, g.row))
		return false
	var cs := float(world.shape.cell_size)
	var to_local := Vector2((g.front + 0.5) * cs, g.row * cs - 1.0)
	_climb = {"from": global_position, "to": world.to_global(to_local), "t": 0.0}
	facing = _step_dir()
	velocity = Vector2.ZERO
	Audio.play("jump")
	_squash = 1.0
	return true


## PT10-7c: on foot underground with the body's middle on a ladder cell.
func on_ladder() -> bool:
	if vehicle != null or world == null or game == null:
		return false
	var ls: Variant = game.get("ladders")
	if ls == null:
		return false
	var mid := world.to_local(global_position) - Vector2(0, body_size().y * 0.5)
	return (ls as LadderSet).at(world.shape.cell_at(mid))


func is_climbing() -> bool:
	return not _climb.is_empty()


func _climb_step(delta: float) -> void:
	_climb.t += delta / CLIMB_TIME
	var k := clampf(_climb.t, 0.0, 1.0)
	var from: Vector2 = _climb.from
	var to: Vector2 = _climb.to
	# Up first, then over (a little hop onto the step).
	var up := Vector2(from.x, to.y)
	global_position = from.lerp(up, minf(k * 2.0, 1.0)) if k < 0.5 else up.lerp(to, (k - 0.5) * 2.0)
	velocity = Vector2.ZERO
	if k >= 1.0:
		_climb = {}


## One dig (or scoop up top) toward `move`; true when it removed something.
func dig_now(move: Vector2) -> bool:
	_swing = 1.0
	if world == null:
		return _scoop() > 0
	var a := aim_of(move, aim)
	var targets := dig_cells(a)
	var cells := dig_targets(a)
	if cells.is_empty():
		swung.emit(targets[0] if not targets.is_empty() else Vector2i.ZERO)
		return false
	if vehicle != null and vehicle.sounds.has(&"dig"):
		Audio.play(String(vehicle.sounds[&"dig"]))
	var offsets: Array[Vector2i] = []
	for c in cells:
		offsets.append(c - cells[0])
	world.dig(cells[0], offsets, player)
	_squash = maxf(_squash, 0.4)
	if has_big_shovel():
		_glint = 1.0
	return true


func _scoop() -> int:
	var hv: Node = game.get("hillville") if game != null else null
	var area := vehicle.clear_area if vehicle != null else Vector2i.ONE
	var n := 0
	if hv != null and hv.has_method("scoop"):
		n = hv.scoop(global_position, facing, area, player)
	if n >= BIG_SCOOP:
		# V-07: a big scoop (a tree, or a vehicle's wide bucket) thumps the view a little.
		ScreenKick.kick(player, 1.5 + 0.25 * mini(n, 6), 0.22)
	if n <= 0:
		Audio.play("swing")
		swung.emit(Vector2i.ZERO)
	_squash = 1.0
	return n


## Cells a dig toward `aim` reaches: the body's cross-section in front (so the body fits the hole;
## sideways the first of the next two columns with anything solid, so a body in the way does not
## stop the tunnel) plus the vehicle's dig_shape, rotated by the aim, centred on that front.
func dig_cells(to: Vector2i) -> Array[Vector2i]:
	var s := world.shape
	var cs := float(s.cell_size)
	var p := world.to_local(global_position)
	var size := body_size()
	var hw := size.x * 0.5
	var out: Array[Vector2i] = []
	var anchor: Vector2i
	if to.y != 0:
		var y := p.y + 4.0 if to.y > 0 else p.y - size.y - 6.0
		# Every column the body rests on, even by a pixel (else a body a hair off the grid
		# stands on the one column it did not dig and never falls).
		var x := -hw + 0.5
		while x <= hw - 0.5 + 0.01:
			_add_unique(out, s.cell_at(Vector2(p.x + x, y)))
			x += minf(8.0, maxf(1.0, hw * 2.0 - 1.0))
		_add_unique(out, s.cell_at(Vector2(p.x + hw - 0.5, y)))
		anchor = s.cell_at(Vector2(p.x, y))
	else:
		var first: Array[Vector2i] = []
		var chosen_x := 0.0
		# PT10-6: on foot, the column right after the ones the body stands in (the marker's cell;
		# never one further, so the hole is always next to the character). A vehicle reaches the
		# first of the next two columns with anything solid, so a body in the way does not stop it.
		for i in (2 if vehicle != null else 1):
			var fx := p.x + to.x * (hw + 4.0 + cs * i)
			if vehicle == null:
				fx = p.x + to.x * (hw - 0.5 + cs)
			var col: Array[Vector2i] = []
			var y := p.y - 4.0
			while y >= p.y - size.y + 4.0 - 0.01:
				_add_unique(col, s.cell_at(Vector2(fx, y)))
				y -= 8.0
			_add_unique(col, s.cell_at(Vector2(fx, p.y - size.y + 4.0)))
			if i == 0:
				first = col
				chosen_x = fx
			var any := false
			for c in col:
				if world.is_solid(c):
					any = true
			if any:
				first = col
				chosen_x = fx
				break
		out = first
		anchor = s.cell_at(Vector2(chosen_x, p.y - size.y * 0.5))
	var shape: Array[Vector2i] = [Vector2i.ZERO]
	if vehicle != null and not vehicle.dig_shape.is_empty():
		shape = vehicle.dig_shape
	elif has_big_shovel():
		shape = [Vector2i.ZERO, Vector2i(1, 0)]
	for o in shape:
		_add_unique(out, anchor + rotate_offset(o, to))
	return out


## A dig_shape offset (for facing right) turned to `to`.
static func rotate_offset(o: Vector2i, to: Vector2i) -> Vector2i:
	if to.x < 0:
		return Vector2i(-o.x, o.y)
	if to.y > 0:
		return Vector2i(-o.y, o.x)
	if to.y < 0:
		return Vector2i(o.y, -o.x)
	return o


static func _add_unique(arr: Array[Vector2i], c: Vector2i) -> void:
	if not arr.has(c):
		arr.append(c)


# --- drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	draw_set_transform(Vector2(0, ride_offset))
	var c: Color = Players.COLOR.get(player, Color.WHITE)
	if vehicle != null:
		var moving := absf(velocity.x) > 10.0 and is_on_floor()
		var st := ability.draw_state() if ability != null else {}
		if cab_spin > 0.0:
			# A full turn seen from the side: squeeze to an edge, show the back, come round again.
			var sx := cos((1.0 - cab_spin) * TAU)
			draw_set_transform(Vector2(0, ride_offset - sin((1.0 - cab_spin) * PI) * 3.0), 0.0, Vector2(sx if absf(sx) > 0.12 else 0.12 * signf(sx + 0.0001), 1.0))
		Vehicle.draw_vehicle(self, vehicle, facing, c, _swing * 0.6, _aim, _t, moving, player, st)
		draw_set_transform(Vector2(0, ride_offset))
		if ability != null:
			ability.draw_over(self)
		var sleeper: int = game.sleeper_in(vehicle.id) if game != null and game.has_method("sleeper_in") else -1
		if sleeper >= 0:
			Vehicle.draw_sleeper(self, vehicle, facing, sleeper, 0.0, _t)
	else:
		_draw_body(c)
	_draw_marker(c)
	_draw_effects()
	draw_set_transform(Vector2.ZERO)


## Which animation of the picked character (Jeff / Chuck by default) to show, and its frame (manifest rows).
func _pose() -> Array:
	var file := SpriteArt.char_file(player)
	if _swing > 0.0:
		var n := int(SpriteArt.row(file, "dig_side").get("frames", 3))
		var f := clampi(int((1.0 - _swing) * n), 0, n - 1)
		return ["dig_down" if _aim > 0.3 else "dig_side", f]
	var vy := velocity.dot(up_direction)
	if not is_on_floor() and absf(vy) > 20.0:
		return ["air", 0 if vy > 0.0 else 1]
	if absf(velocity.x) > 10.0:
		return ["walk", SpriteArt.frame_at(file, "walk", _t)]
	return ["idle", SpriteArt.frame_at(file, "idle", _t)]


func _draw_body(c: Color) -> void:
	# Backpack on the back, rounder when full (drawn first: behind the character).
	var full := is_full() and backpack_count() > 0
	var bag := Rect2(-facing * 8 - 3, -22, 6, 10)
	draw_rect(bag.grow(1), DARK)
	draw_rect(bag, Color("a47148").lightened(0.2 if full else 0.0))
	var pose := _pose()
	SpriteArt.draw_char(self, SpriteArt.char_file(player), pose[0], _t, Vector2.ZERO, facing < 0, Color.WHITE, pose[1])


## PT10-9: the A glyph over the head while standing in the elevator: blinking when it is ready to
## go, dim and steady while the car comes or the ride is on.
func _draw_lift_glyph(h: float, state: int) -> void:
	var hz := 2.5
	var el: Object = game.get("elevator") if game != null else null
	if el != null and el.get("tuning") != null:
		hz = float(el.tuning.blink_hz)
	var on := fmod(_t * hz, 1.0) < 0.6
	var alpha := (1.0 if on else 0.35) if state == 1 else 0.45
	var bob := sin(_t * TAU * hz * 0.5) * 1.5 if state == 1 else 0.0
	var at := Vector2(0, -h - 14.0 + bob)
	# Drawn at 2x and scaled down, so the letter is crisp at the game's zoom.
	draw_set_transform(Vector2(0, ride_offset) + at, 0.0, Vector2(0.5, 0.5))
	ButtonHints.draw_button(self, Vector2.ZERO, 30.0, "a", alpha, 1.0 if on and state == 1 else 0.0)
	draw_set_transform(Vector2(0, ride_offset))


## PT10-6: the next dig's cells, outlined with corner brackets in the player's colour (brighter
## while A is held). Drawn by the player, so it moves with them; nothing floats free.
func _draw_marker(c: Color) -> void:
	if _mark_shown.size == Vector2.ZERO or world == null:
		return
	draw_set_transform(Vector2.ZERO)
	var a := to_local(world.to_global(_mark_shown.position))
	var b := to_local(world.to_global(_mark_shown.end))
	var r := Rect2(a, b - a).abs().grow(-1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	var alpha := 0.95 if _mark_hot else 0.55 + 0.25 * pulse
	var arm := minf(7.0, r.size.x * 0.45)
	var col := Color(c.lightened(0.35), alpha)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x <= r.position.x + 0.1 else -1.0
		var sy := 1.0 if corner.y <= r.position.y + 0.1 else -1.0
		for pass_i in 2:
			var w := 5.0 if pass_i == 0 else 3.0
			var cc := Color(DARK, alpha) if pass_i == 0 else col
			draw_line(corner, corner + Vector2(arm * sx, 0), cc, w)
			draw_line(corner, corner + Vector2(0, arm * sy), cc, w)
	if _mark_hot:
		draw_rect(r, Color(c, 0.12 + 0.1 * pulse))
	draw_set_transform(Vector2(0, ride_offset))


func _draw_effects() -> void:
	var h := body_size().y
	var lift := lift_prompt()
	if lift > 0:
		_draw_lift_glyph(h, 2 if lift == 1 and not lift_ready() else lift)
	if _honk > 0.0:
		# The horn: rings popping out of the front.
		var at := Vector2(facing * (body_size().x * 0.5 + 4.0), -h * 0.6)
		for k in 3:
			var rr := 4.0 + (1.0 - _honk) * 14.0 + k * 5.0
			draw_arc(at, rr, -0.7 if facing > 0 else PI - 0.7, 0.7 if facing > 0 else PI + 0.7, 8, Color(1, 0.95, 0.5, _honk), 2.0)
	if _glint > 0.0:
		# The bigger shovel: a gold glint where it bites.
		var gp := Vector2(facing * (body_size().x * 0.5 + 10.0), -h * 0.35)
		if _aim > 0.3:
			gp = Vector2(facing * 4.0, 6.0)
		var gr := 3.0 + (1.0 - _glint) * 6.0
		var gc := Color(1.0, 0.86, 0.3, _glint)
		draw_line(gp - Vector2(gr, 0), gp + Vector2(gr, 0), gc, 2.0)
		draw_line(gp - Vector2(0, gr), gp + Vector2(0, gr), gc, 2.0)
		draw_circle(gp, 2.0, Color(1, 1, 0.85, _glint))
	if tool_pop > 0.0:
		_draw_tool_pop(h)
	if _full_pop > 0.0:
		# Backpack full: a round, happy bag pops up over the head.
		var at := Vector2(0, -h - 12.0 - (1.0 - _full_pop) * 8.0)
		draw_circle(at, 6.0, DARK)
		draw_circle(at, 5.0, Color("a47148").lightened(0.25))
		draw_arc(at + Vector2(0, 0.5), 2.5, 0.3, PI - 0.3, 6, DARK, 1.0)


## B-06: a big gold shovel rises over the head with a ring of sparks (no words).
func _draw_tool_pop(h: float) -> void:
	var k := tool_pop
	var at := Vector2(0, -h - 20.0 - (1.0 - k) * 14.0)
	var a := clampf(k * 3.0, 0.0, 1.0)
	var grow := 1.0 + 0.4 * sin(clampf((1.0 - k) * 4.0, 0.0, 1.0) * PI)
	draw_set_transform(Vector2(0, ride_offset) + at, -0.6, Vector2.ONE * grow)
	draw_line(Vector2(0, 10), Vector2(0, -4), Color(DARK, a), 5.0)
	draw_line(Vector2(0, 10), Vector2(0, -4), Color(0.66, 0.44, 0.24, a), 3.0)
	draw_rect(Rect2(-4, 9, 8, 3), Color(DARK, a))
	var blade := PackedVector2Array([Vector2(-7, -4), Vector2(7, -4), Vector2(6, -14), Vector2(0, -19), Vector2(-6, -14)])
	draw_colored_polygon(blade, Color(DARK, a))
	var inner := PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(4.5, -13), Vector2(0, -17), Vector2(-4.5, -13)])
	draw_colored_polygon(inner, Color(1.0, 0.82, 0.25, a))
	draw_line(Vector2(-2, -7), Vector2(-2, -14), Color(1, 0.96, 0.6, a), 1.5)
	draw_set_transform(Vector2(0, ride_offset))
	for i in 8:
		var ang := TAU * i / 8.0 + (1.0 - k) * 1.5
		var r := 14.0 + (1.0 - k) * 18.0
		draw_circle(at + Vector2.from_angle(ang) * r, 2.0, Color(1.0, 0.9, 0.4, a))
