## Prototype Hillville: a flat 480-tile strip (ground top at y = 0), sky, grass, a row of coloured
## placeholder boxes, and the mine shaft head-frame at x = 0 with its cage zone. Flat colours only.
class_name ProtoHillville
extends Node2D

const LEFT := -1600.0
const WIDTH := 7680.0           # 480 tiles
const GROUND_DEPTH := 160.0
const SKY_TOP := -1200.0
const CAGE := Rect2(-16, -32, 32, 36)   # the cage zone, feet inside it ride down
const ARRIVAL := Vector2(0, -2)

var cage_flash := 0.0:
	set(v):
		cage_flash = v
		queue_redraw()

var _boxes: Array = []   # [Rect2, Color]


func _ready() -> void:
	name = "Hillville"
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, GROUND_DEPTH)
	cs.shape = rect
	cs.position = Vector2(LEFT + WIDTH * 0.5, GROUND_DEPTH * 0.5)
	ground.add_child(cs)
	add_child(ground)
	for side in [-1.0, 1.0]:
		# Walls at both ends so nobody walks off the strip.
		var wall := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(32, 2000)
		wall.shape = wr
		wall.position = Vector2(LEFT - 16 if side < 0 else LEFT + WIDTH + 16, -1000)
		ground.add_child(wall)
	var cols := [Color("f2c94c"), Color("eb5757"), Color("9b51e0"), Color("2d9cdb"), Color("f2994a"),
			Color("6fcf97"), Color("bb6bd9")]
	var x := LEFT + 80.0
	var i := 0
	while x < LEFT + WIDTH - 80.0:
		if absf(x) > 140.0:
			var w := 24.0 + (i * 29) % 56
			var h := 16.0 + (i * 37) % 70
			_boxes.append([Rect2(x, -h, w, h), cols[i % cols.size()]])
		x += 90.0 + (i * 53) % 120
		i += 1
	var players := Node2D.new()
	players.name = "Players"
	add_child(players)
	queue_redraw()


func get_camera_limits() -> Rect2:
	return Rect2(LEFT, SKY_TOP, WIDTH, GROUND_DEPTH - SKY_TOP)


func cage_zone() -> Rect2:
	return CAGE


func _draw() -> void:
	draw_rect(Rect2(LEFT, SKY_TOP, WIDTH, -SKY_TOP), Color("8fd3f4"))
	draw_rect(Rect2(LEFT, -220.0, WIDTH, 220.0), Color("b5e3f7"))
	for b in _boxes:
		var r: Rect2 = b[0]
		draw_rect(r, b[1])
		draw_rect(r.grow(-1.0), (b[1] as Color).darkened(0.3), false, 2.0)
	draw_rect(Rect2(LEFT, 0, WIDTH, GROUND_DEPTH), Color("6b4a2b"))
	draw_rect(Rect2(LEFT, 0, WIDTH, 8), Color("4f9a3a"))
	draw_rect(Rect2(LEFT, 0, WIDTH, 3), Color("7ccf52"))
	_draw_head_frame()


func _draw_head_frame() -> void:
	var timber := Color("8a5a2b")
	var dark := Color(0.07, 0.06, 0.09)
	# Shaft mouth in the ground, legs, cross beams, wheel on top.
	draw_rect(Rect2(-18, 0, 36, 10), dark)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(30 * s, 0), Vector2(8 * s, -96), dark, 7.0)
		draw_line(Vector2(30 * s, 0), Vector2(8 * s, -96), timber, 4.0)
	for y: float in [-40.0, -72.0]:
		var half := 30.0 - (-y / 96.0) * 22.0
		draw_line(Vector2(-half, y), Vector2(half, y), dark, 6.0)
		draw_line(Vector2(-half, y), Vector2(half, y), timber, 3.0)
	draw_circle(Vector2(0, -100), 13, dark)
	draw_circle(Vector2(0, -100), 10, Color("c9c9c9"))
	draw_circle(Vector2(0, -100), 4, dark)
	draw_line(Vector2(0, -100), Vector2(0, -36), dark, 2.0)
	# The cage: dark opening, bars, flashes yellow while riding.
	draw_rect(Rect2(-17, -37, 34, 37), dark)
	draw_rect(Rect2(-14, -34, 28, 34), Color(0.16, 0.14, 0.18).lerp(Color("f2c94c"), cage_flash))
	for bx in [-9.0, -3.0, 3.0, 9.0]:
		draw_line(Vector2(bx, -34), Vector2(bx, -34 + 34 * cage_flash), Color("c9c9c9"), 2.0)
	draw_rect(Rect2(-17, -40, 34, 4), Color("f2c94c"))
