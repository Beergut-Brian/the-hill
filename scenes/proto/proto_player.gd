## A prototype player: a 12 x 28 px capsule in the player's colour, origin at the feet, so it fits a
## 1-wide, 2-tall dug tunnel. Driven by an intent {move: Vector2, dig: bool, jump: bool} read each
## physics frame from `intent_source` (default: this player's pad / keys; the auto-run and tests swap
## it). In a TileWorld (`world` set) gravity is world.shape.gravity_at() and water lifts it; up top
## gravity is plain down. Dig removes tiles in the aim direction underground, scoops up top.
class_name ProtoPlayer
extends CharacterBody2D

signal swung(cell: Vector2i)   # a dig that found nothing to remove: a tiny swing, no sound

const WIDTH := 12.0
const HEIGHT := 28.0
const WALK := 200.0
const JUMP := 300.0          # about 46 px: clears 2 tiles
const GRAVITY := 980.0       # up top only; underground asks the world
const DIG_EVERY := 0.14
const SCOOP_EVERY := 0.35
const WATER_DAMP := 5.0
const PUSH := 12.0
const DARK := Color(0.07, 0.06, 0.09)

var player := 0
var world: TileWorld
## During the elevator ride: no input, no gravity.
var locked := false
## Callable() -> Dictionary {move, dig, jump}. Empty: read this player's input.
var intent_source := Callable()
var facing := 1
## Visual only: the elevator sinks (+) or lifts (-) the capsule, in px.
var ride_offset := 0.0

var _squash := 0.0
var _swing := 0.0
var _dig_cd := 0.0
var _in_water := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = WIDTH * 0.5
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector2(0, -HEIGHT * 0.5)
	add_child(cs)


func intent() -> Dictionary:
	if intent_source.is_valid():
		return intent_source.call()
	return {
		"move": Players.move_vector(player),
		"dig": Input.is_action_pressed(Players.action(player, "action")),
		"jump": Input.is_action_pressed(Players.action(player, "jump")),
	}


func gravity() -> Vector2:
	if world != null and world.shape != null:
		return world.shape.gravity_at(world.to_local(global_position))
	return Vector2(0.0, GRAVITY)


func in_water() -> bool:
	return _in_water


func _physics_process(delta: float) -> void:
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_swing = move_toward(_swing, 0.0, delta * 6.0)
	queue_redraw()
	if locked:
		velocity = Vector2.ZERO
		return
	var it := intent()
	var move: Vector2 = it.get("move", Vector2.ZERO)
	var g := gravity()
	up_direction = -g.normalized() if g != Vector2.ZERO else Vector2.UP
	var side := Vector2(-up_direction.y, up_direction.x)
	if absf(move.x) > 0.2:
		facing = 1 if move.x > 0.0 else -1
	velocity = side * move.x * WALK + up_direction * velocity.dot(up_direction)
	var lift := Vector2.ZERO
	if world != null:
		lift = world.buoyancy_at(world.to_local(global_position + up_direction * HEIGHT * 0.5))
	var wet := lift != Vector2.ZERO
	if wet != _in_water:
		_in_water = wet
		if wet:
			Audio.play("splash")
			_squash = 1.0
	velocity += (g + lift) * delta
	if wet:
		velocity *= maxf(0.0, 1.0 - WATER_DAMP * delta)
	if it.get("jump", false) and is_on_floor():
		velocity = side * velocity.dot(side) + up_direction * JUMP
		_squash = 1.0
		Audio.play("jump")
	move_and_slide()
	_push_bodies(move)
	if it.get("dig", false):
		_dig_cd -= delta
		if _dig_cd <= 0.0:
			_dig_cd = SCOOP_EVERY if world == null else DIG_EVERY
			_dig(move)
	else:
		_dig_cd = 0.0


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


func _dig(move: Vector2) -> void:
	if world == null:
		Audio.play("scoop")
		_squash = 1.0
		return
	var aim := Vector2i(facing, 0)
	if absf(move.y) > absf(move.x) and absf(move.y) > 0.2:
		aim = Vector2i(0, 1 if move.y > 0.0 else -1)
	elif absf(move.x) > 0.2:
		aim = Vector2i(1 if move.x > 0.0 else -1, 0)
	var targets := _dig_targets(aim)
	var any := false
	for c in targets:
		if world.is_solid(c):
			any = true
	if not any:
		_swing = 1.0
		swung.emit(targets[0])
		return
	var offsets: Array[Vector2i] = []
	for c in targets:
		offsets.append(c - targets[0])
	world.dig(targets[0], offsets, player)
	_swing = 1.0
	_squash = maxf(_squash, 0.4)


## Cells a dig in `aim` reaches. Sideways: the first of the next two columns with anything solid at
## feet or head height (so a body standing in the way does not stop the tunnel), 1 wide x 2 tall.
func _dig_targets(aim: Vector2i) -> Array[Vector2i]:
	var up := up_direction
	var side := Vector2(-up.y, up.x)
	var p := world.to_local(global_position)
	var s := world.shape
	if aim.y > 0:
		return [s.cell_at(p - up * 4.0)]
	if aim.y < 0:
		return [s.cell_at(p + up * (HEIGHT + 6.0))]
	var first: Array[Vector2i] = []
	for i in 2:
		var reach := side * aim.x * (WIDTH * 0.5 + 4.0 + s.cell_size * i)
		var feet := s.cell_at(p + reach + up * 4.0)
		var head := s.cell_at(p + reach + up * (HEIGHT - 8.0))
		var pair: Array[Vector2i] = [feet, head]
		if i == 0:
			first = pair
		if world.is_solid(feet) or world.is_solid(head):
			return pair
	return first


func _draw() -> void:
	var sx := 1.0 + _squash * 0.25
	var sy := 1.0 - _squash * 0.25
	draw_set_transform(Vector2(0, ride_offset), 0.0, Vector2(sx, sy))
	var c: Color = Players.COLOR.get(player, Color.WHITE)
	var r := WIDTH * 0.5
	var top := -HEIGHT + r
	var bot := -r
	draw_rect(Rect2(-r - 1, top, WIDTH + 2, bot - top), DARK)
	draw_circle(Vector2(0, top), r + 1, DARK)
	draw_circle(Vector2(0, bot), r + 1, DARK)
	draw_rect(Rect2(-r, top, WIDTH, bot - top), c)
	draw_circle(Vector2(0, top), r, c)
	draw_circle(Vector2(0, bot), r, c)
	var ex := 1.0 * facing
	draw_rect(Rect2(ex - 4, top - 2, 2, 3), DARK)
	draw_rect(Rect2(ex + 2, top - 2, 2, 3), DARK)
	if _swing > 0.0:
		# A little shovel arc on the facing side.
		var a := lerpf(-1.2, 0.6, 1.0 - _swing) * facing
		var hand := Vector2(r * facing, -HEIGHT * 0.45)
		var tip := hand + Vector2(cos(a) * 9.0 * facing, sin(a) * 9.0)
		draw_line(hand, tip, DARK, 2.0)
		draw_rect(Rect2(tip - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.85, 0.9))
	draw_set_transform(Vector2.ZERO)
