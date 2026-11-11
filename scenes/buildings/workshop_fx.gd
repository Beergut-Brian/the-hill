## B-06: the Workshop at work. A hammer swings down onto the anvil in the open bay every BEAT
## seconds, each strike throws gold sparks, and the chimney puffs smoke. The clang
## (`workshop_hammer`) only sounds while a player stands near, so it never nags from across town.
## Pure drawing on top of the Building sprite (assets/sprites/buildings/workshop.png, 96 x 96,
## origin bottom-left on the ground). No faces.
class_name WorkshopFx
extends Node2D

const BEAT := 1.1
## The strike lands this far into a beat; the hammer is up for the rest.
const DOWN_AT := 0.82
const HEAR := 300.0
## Sprite points (origin bottom-left, y up negative).
const ANVIL := Vector2(37, -19)
const PIVOT := Vector2(27, -8)
## How far the hammer swings up (radians, back toward the bay's left wall, under the sign).
const SWING := 0.7
const CHIMNEY := Vector2(73.5, -96)
const SPARK_G := 260.0
const IRON := Color(0.33, 0.35, 0.47)
const IRON_LIT := Color(0.67, 0.71, 0.77)
const HANDLE := Color(0.66, 0.44, 0.24)
const OUTLINE := Color(0.23, 0.16, 0.27)
const SPARK := Color(1.0, 0.86, 0.3)

var building: Node2D
## Strikes so far (tests read it).
var strikes := 0
## Clangs actually played (tests read it).
var clangs := 0
var _t := 0.0
var _sparks: Array = []
var _smoke: Array = []
var _smoke_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 6
	z_index = 0


func _process(delta: float) -> void:
	step(delta)


## Advances the animation by delta (tests call it directly).
func step(delta: float) -> void:
	if not _active():
		return
	for s in _sparks:
		s.life += delta
		s.vel.y += SPARK_G * delta
		s.pos += s.vel * delta
	_sparks = _sparks.filter(func(s): return s.life < s.max)
	var before := fmod(_t, BEAT)
	_t += delta
	var now := fmod(_t, BEAT)
	if (before < DOWN_AT and now >= DOWN_AT) or (delta >= BEAT):
		_strike()
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = 0.8
		_smoke.append({"pos": CHIMNEY + Vector2(_rng.randf_range(-2, 2), 0), "life": 0.0})
	for m in _smoke:
		m.life += delta
		m.pos += Vector2(6.0, -16.0) * delta
	_smoke = _smoke.filter(func(m): return m.life < 2.4)
	queue_redraw()


## How raised the hammer is: 0 = down on the anvil, 1 = all the way up (SWING radians).
func hammer_lift() -> float:
	var ph := fmod(_t, BEAT)
	if ph < DOWN_AT:
		# Rises quickly after the strike, then hangs, then drops.
		var up := clampf(ph / 0.3, 0.0, 1.0)
		var drop := clampf((ph - (DOWN_AT - 0.12)) / 0.12, 0.0, 1.0)
		return 1.0 * up * (1.0 - drop * drop)
	return 0.0


func sparks_alive() -> int:
	return _sparks.size()


func player_near() -> bool:
	var hv := _hillville()
	if hv == null or building == null:
		return false
	var mid := building.position.x + 48.0
	for p in hv.players_root().get_children():
		if p is HillPlayer and absf((p as Node2D).position.x - mid) < HEAR:
			return true
	return false


func _active() -> bool:
	if building == null:
		return true
	return not bool(building.get("ghost")) and float(building.get("reveal")) >= 1.0


func _strike() -> void:
	strikes += 1
	for i in 7:
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		_sparks.append({"pos": ANVIL + Vector2(0, -2), "vel": Vector2.from_angle(a) * _rng.randf_range(50, 120),
				"life": 0.0, "max": _rng.randf_range(0.25, 0.5)})
	if player_near():
		clangs += 1
		Audio.play("workshop_hammer")


func _hillville() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("players_root"):
			return n
		n = n.get_parent()
	return null


func _draw() -> void:
	if not _active():
		return
	for m in _smoke:
		var k: float = m.life / 2.4
		draw_circle(m.pos, 3.0 + k * 7.0, Color(0.92, 0.9, 0.86, 0.75 * (1.0 - k)))
	# The hammer: a handle from the pivot, a head that meets the anvil at lift 0.
	var ang := -SWING * hammer_lift()
	var rest := ANVIL + Vector2(1, -5) - PIVOT
	var head := PIVOT + rest.rotated(ang)
	draw_line(PIVOT, head, OUTLINE, 4.0)
	draw_line(PIVOT, head, HANDLE, 2.0)
	var dir := (head - PIVOT).normalized()
	var side := Vector2(-dir.y, dir.x)
	var box := PackedVector2Array([head - side * 5 - dir * 3, head + side * 5 - dir * 3,
			head + side * 5 + dir * 3, head - side * 5 + dir * 3])
	draw_colored_polygon(box, OUTLINE)
	var inner := PackedVector2Array([head - side * 4 - dir * 2, head + side * 4 - dir * 2,
			head + side * 4 + dir * 2, head - side * 4 + dir * 2])
	draw_colored_polygon(inner, IRON)
	draw_line(head - side * 4 - dir * 2, head + side * 4 - dir * 2, IRON_LIT, 1.0)
	# Sparks off the anvil, and a flash on the strike.
	var ph := fmod(_t, BEAT)
	if ph >= DOWN_AT and ph < DOWN_AT + 0.1:
		draw_circle(ANVIL + Vector2(0, -3), 5.0, Color(1.0, 0.95, 0.6, 0.8))
	for s in _sparks:
		var a: float = 1.0 - s.life / s.max
		draw_line(s.pos, s.pos - s.vel * 0.03, Color(SPARK, a), 2.0)
