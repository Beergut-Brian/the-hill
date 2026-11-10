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
const JUMP := 300.0          # about 46 px: clears 2 tiles
const GRAVITY := 980.0       # up top only; underground asks the world
const DIG_EVERY := 0.14
const VEHICLE_DIG_EVERY := 0.22
const SCOOP_EVERY := 0.35
const WATER_DAMP := 5.0
const PUSH := 12.0
const HOP_REACH := 24.0
const STEP_UP := 17.0
const DARK := Color(0.07, 0.06, 0.09)
const HAT := Color("f2c94c")

var player := 0
## HillGame (untyped so this script stands alone in tests).
var game: Node
var world: TileWorld
var locked := false
var intent_source := Callable()
var facing := 1
var ride_offset := 0.0
## The vehicle being driven, null on foot.
var vehicle: VehicleData
## block id -> count. Emptied into Inventory by the elevator going up.
var backpack: Dictionary = {}
## A was pressed this physics frame (the elevator reads it: A skips the door wait).
var a_press_frame := false

var _shape: CollisionShape2D
var _squash := 0.0
var _swing := 0.0
var _honk := 0.0
var _full_pop := 0.0
var _dig_cd := 0.0
var _dig_used := false
var _b_used := false
var _aim := 0.0
var _in_water := false
var _prev := {}
var _t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	_shape = CollisionShape2D.new()
	add_child(_shape)
	_apply_shape()


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
	return out


# --- for B and the game ------------------------------------------------------------------------

func honk() -> void:
	var cue := "horn"
	if vehicle != null and vehicle.sounds.has(&"horn"):
		cue = String(vehicle.sounds[&"horn"])
	Audio.play(cue)
	_honk = 1.0
	honked.emit()


func bump() -> void:
	_squash = 1.0


## Starts driving `d` (the game removed the parked node).
func drive(d: VehicleData) -> void:
	vehicle = d
	_apply_shape()
	_squash = 1.0


## Back on foot; returns what was driven.
func stop_driving() -> VehicleData:
	var d := vehicle
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
	_full_pop = move_toward(_full_pop, 0.0, delta * 3.0)
	queue_redraw()
	if locked:
		velocity = Vector2.ZERO
		_prev = {}
		a_press_frame = false
		return
	var it := intent()
	var move: Vector2 = it.get("move", Vector2.ZERO)
	var a_press := _pressed(it, "dig")
	a_press_frame = a_press
	var b_press := _pressed(it, "jump")
	var x_press := _pressed(it, "book")
	var y_press := _pressed(it, "horn")
	_prev = it.duplicate()
	if not it.get("jump", false):
		_b_used = false
	if y_press:
		honk()
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
	if absf(move.x) > 0.2:
		facing = 1 if move.x > 0.0 else -1
	_aim = move.y if absf(move.y) > 0.3 else 0.0
	var speed := vehicle.speed if vehicle != null else WALK
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
	if vehicle == null and it.get("jump", false) and not _b_used and is_on_floor():
		velocity = side * velocity.dot(side) + up_direction * JUMP
		_squash = 1.0
		Audio.play("jump")
	move_and_slide()
	if vehicle != null:
		_step_up(move)
	_push_bodies(move)
	if a_press and build != null and build.action(player):
		_dig_used = true
	if not it.get("dig", false):
		_dig_used = false
		_dig_cd = 0.0
	elif not _dig_used:
		_dig_cd -= delta
		if _dig_cd <= 0.0:
			_dig_cd = SCOOP_EVERY if world == null else (DIG_EVERY if vehicle == null else VEHICLE_DIG_EVERY)
			_dig(move)


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

func aim_of(move: Vector2) -> Vector2i:
	if absf(move.y) > absf(move.x) and absf(move.y) > 0.2:
		return Vector2i(0, 1 if move.y > 0.0 else -1)
	if absf(move.x) > 0.2:
		return Vector2i(1 if move.x > 0.0 else -1, 0)
	return Vector2i(facing, 0)


func _dig(move: Vector2) -> void:
	_swing = 1.0
	if world == null:
		_scoop()
		return
	var targets := dig_cells(aim_of(move))
	var tier := vehicle.dig_tier if vehicle != null else 0
	var cells: Array[Vector2i] = []
	for c in targets:
		if not world.is_solid(c):
			continue
		var def := world.tile_def(world.get_tile(c))
		if def is BlockData and (def as BlockData).dig_tier > tier and def.breakable:
			continue
		cells.append(c)
	if cells.is_empty():
		swung.emit(targets[0] if not targets.is_empty() else Vector2i.ZERO)
		return
	if vehicle != null and vehicle.sounds.has(&"dig"):
		Audio.play(String(vehicle.sounds[&"dig"]))
	var offsets: Array[Vector2i] = []
	for c in cells:
		offsets.append(c - cells[0])
	world.dig(cells[0], offsets, player)
	_squash = maxf(_squash, 0.4)


func _scoop() -> void:
	var hv: Node = game.get("hillville") if game != null else null
	var area := vehicle.clear_area if vehicle != null else Vector2i.ONE
	var n := 0
	if hv != null and hv.has_method("scoop"):
		n = hv.scoop(global_position, facing, area, player)
	if n <= 0:
		Audio.play("swing")
		swung.emit(Vector2i.ZERO)
	_squash = 1.0


## Cells a dig toward `aim` reaches: the body's cross-section in front (so the body fits the hole;
## sideways the first of the next two columns with anything solid, so a body in the way does not
## stop the tunnel) plus the vehicle's dig_shape, rotated by the aim, centred on that front.
func dig_cells(aim: Vector2i) -> Array[Vector2i]:
	var s := world.shape
	var cs := float(s.cell_size)
	var p := world.to_local(global_position)
	var size := body_size()
	var hw := size.x * 0.5
	var out: Array[Vector2i] = []
	var anchor: Vector2i
	if aim.y != 0:
		var y := p.y + 4.0 if aim.y > 0 else p.y - size.y - 6.0
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
		for i in 2:
			var fx := p.x + aim.x * (hw + 4.0 + cs * i)
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
	for o in shape:
		_add_unique(out, anchor + rotate_offset(o, aim))
	return out


## A dig_shape offset (for facing right) turned to `aim`.
static func rotate_offset(o: Vector2i, aim: Vector2i) -> Vector2i:
	if aim.x < 0:
		return Vector2i(-o.x, o.y)
	if aim.y > 0:
		return Vector2i(-o.y, o.x)
	if aim.y < 0:
		return Vector2i(o.y, -o.x)
	return o


static func _add_unique(arr: Array[Vector2i], c: Vector2i) -> void:
	if not arr.has(c):
		arr.append(c)


# --- drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	var sx := 1.0 + _squash * 0.2
	var sy := 1.0 - _squash * 0.2
	draw_set_transform(Vector2(0, ride_offset), 0.0, Vector2(sx, sy))
	var c: Color = Players.COLOR.get(player, Color.WHITE)
	if vehicle != null:
		Vehicle.draw_vehicle(self, vehicle, facing, c, _swing * 0.6, _aim)
		var sleeper: int = game.sleeper_in(vehicle.id) if game != null and game.has_method("sleeper_in") else -1
		if sleeper >= 0:
			Vehicle.draw_sleeper(self, vehicle, facing, sleeper, 0.0, _t)
	else:
		_draw_body(c)
	draw_set_transform(Vector2(0, ride_offset))
	_draw_effects()
	draw_set_transform(Vector2.ZERO)


func _draw_body(c: Color) -> void:
	var r := WIDTH * 0.5
	var top := -HEIGHT + r
	var bot := -r
	# Backpack on the back, rounder when full.
	var full := is_full() and backpack_count() > 0
	var bag := Rect2(-facing * (r + 3) - 3, top + 6, 6, 10)
	draw_rect(bag.grow(1), DARK)
	draw_rect(bag, Color("a47148").lightened(0.2 if full else 0.0))
	draw_rect(Rect2(-r - 1, top, WIDTH + 2, bot - top), DARK)
	draw_circle(Vector2(0, top), r + 1, DARK)
	draw_circle(Vector2(0, bot), r + 1, DARK)
	draw_rect(Rect2(-r, top, WIDTH, bot - top), c)
	draw_circle(Vector2(0, top), r, c)
	draw_circle(Vector2(0, bot), r, c)
	var ex := 1.0 * facing
	draw_rect(Rect2(ex - 4, top - 1, 2, 3), DARK)
	draw_rect(Rect2(ex + 2, top - 1, 2, 3), DARK)
	# Hard hat.
	draw_rect(Rect2(-r - 1, top - r - 1, WIDTH + 2, 4), DARK)
	draw_rect(Rect2(-r + 1, top - r - 3, WIDTH - 2, 4), HAT)
	draw_rect(Rect2(-r - 1 + facing * 2, top - r + 0.5, WIDTH + 2, 2), HAT)
	if _swing > 0.0:
		var a := lerpf(-1.2, 0.6, 1.0 - _swing) * facing
		var hand := Vector2(r * facing, -HEIGHT * 0.45)
		var tip := hand + Vector2(cos(a) * 9.0 * facing, sin(a) * 9.0)
		draw_line(hand, tip, DARK, 2.0)
		draw_rect(Rect2(tip - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.85, 0.9))


func _draw_effects() -> void:
	var h := body_size().y
	if _honk > 0.0:
		# The horn: rings popping out of the front.
		var at := Vector2(facing * (body_size().x * 0.5 + 4.0), -h * 0.6)
		for k in 3:
			var rr := 4.0 + (1.0 - _honk) * 14.0 + k * 5.0
			draw_arc(at, rr, -0.7 if facing > 0 else PI - 0.7, 0.7 if facing > 0 else PI + 0.7, 8, Color(1, 0.95, 0.5, _honk), 2.0)
	if _full_pop > 0.0:
		# Backpack full: a round, happy bag pops up over the head.
		var at := Vector2(0, -h - 12.0 - (1.0 - _full_pop) * 8.0)
		draw_circle(at, 6.0, DARK)
		draw_circle(at, 5.0, Color("a47148").lightened(0.25))
		draw_arc(at + Vector2(0, 0.5), 2.5, 0.3, PI - 0.3, 6, DARK, 1.0)
