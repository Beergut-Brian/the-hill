## PT10-7b: the elevator car on its rope, drawn down the underground shaft. The rope hangs from the
## shaft mouth to the car; below the car a faint guide rope runs on to the deepest landing anyone
## has reached (so you can see the elevator reaches your layer). The car slides along it when it
## is called to a landing, and rides up and down with its riders. HillElevator adds one to the
## Underground; it only draws (HillElevator.car_position() says where the car is).
class_name ShaftRope
extends Node2D

const ROPE := Color(0.62, 0.48, 0.3)
const ROPE_DARK := Color(0.25, 0.17, 0.1)
const GOLD := Color("ffd23f")
const DARK := Color(0.07, 0.06, 0.09)

## HillElevator (untyped: tests can feed a stand-in).
var elevator: Node
var _t := 0.0


func _ready() -> void:
	name = "ShaftRope"
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The car's rect (underground px) at a fractional layer position (-1 = above the top landing).
func car_rect(at: float) -> Rect2:
	var ug: Node = get_parent()
	var n: int = ug.layers().size() if ug.has_method("layers") else 1
	var top: Rect2 = ug.cage_rect(0)
	var above := Rect2(top.position - Vector2(0, top.size.y * 3.0), top.size)
	var lo := int(floor(at))
	var hi := mini(lo + 1, n - 1)
	var k := at - lo
	var a: Rect2 = above if lo < 0 else ug.cage_rect(clampi(lo, 0, n - 1))
	var b: Rect2 = ug.cage_rect(clampi(hi, 0, n - 1)) if hi >= 0 else above
	return Rect2(a.position.lerp(b.position, k), a.size)


func deepest_reached() -> int:
	var d := 0
	var pr := get_node_or_null(^"/root/Progress")
	if pr != null:
		for p in pr.deepest:
			d = maxi(d, int(pr.deepest[p]))
	return d


func _draw() -> void:
	if elevator == null or get_parent() == null or not get_parent().has_method("cage_rect"):
		return
	_draw_ladders()
	var at: float = elevator.car_position()
	var car := car_rect(at)
	var x := car.get_center().x
	var mouth: float = get_parent().cage_rect(0).position.y - 64.0
	var deep: Rect2 = get_parent().cage_rect(deepest_reached())
	# Guide rope from the car down to the deepest landing reached (faint), then the real rope.
	if deep.end.y > car.end.y:
		_rope(Vector2(x, car.end.y), Vector2(x, deep.end.y), 0.35)
	_rope(Vector2(x, mouth), Vector2(x, car.position.y - 6.0), 1.0)
	if at < -0.5:
		return
	# The car: a gold frame with a roof and hook, see-through so riders show inside.
	var r := car.grow(3.0)
	draw_rect(Rect2(r.position.x - 2, r.position.y - 6, r.size.x + 4, 5), DARK)
	draw_rect(Rect2(r.position.x - 1, r.position.y - 5, r.size.x + 2, 3), GOLD)
	draw_circle(Vector2(x, r.position.y - 7), 2.5, DARK)
	draw_rect(r, Color(GOLD, 0.12))
	draw_rect(r, DARK, false, 3.0)
	draw_rect(r.grow(-1.0), Color(GOLD, 0.9), false, 1.0)
	for i in 3:
		var bx := r.position.x + r.size.x * (i + 1) / 4.0
		draw_line(Vector2(bx, r.position.y), Vector2(bx, r.end.y), Color(GOLD, 0.35), 1.0)


func _rope(a: Vector2, b: Vector2, alpha: float) -> void:
	if b.y <= a.y:
		return
	draw_line(a, b, Color(ROPE_DARK, alpha), 3.0)
	draw_line(a, b, Color(ROPE, alpha), 1.5)
	# Twists, so it reads as rope.
	var y := a.y
	while y < b.y:
		draw_line(Vector2(a.x - 1, y), Vector2(a.x + 1, y + 2), Color(ROPE_DARK, alpha * 0.8), 1.0)
		y += 6.0


## PT10-7c: placeholder ladders (two rails, a rung per half tile) until Art draws one.
func _draw_ladders() -> void:
	var g: Node = elevator.get("game")
	var ls: LadderSet = g.get("ladders") if g != null else null
	if ls == null:
		return
	for l in ls.ladders:
		var x0 := l.x * 16.0 + 3.0
		var x1 := l.x * 16.0 + 13.0
		var y0 := l.y * 16.0
		var y1 := (l.z + 1) * 16.0
		for x in [x0, x1]:
			draw_line(Vector2(x, y0), Vector2(x, y1), ROPE_DARK, 3.0)
			draw_line(Vector2(x, y0), Vector2(x, y1), ROPE, 1.5)
		var y := y0 + 4.0
		while y < y1:
			draw_line(Vector2(x0, y), Vector2(x1, y), ROPE, 2.0)
			y += 8.0
