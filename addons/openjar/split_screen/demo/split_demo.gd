## ScreenDirector demo: two flat placeholder scenes and a scripted timeline, no input.
##   0-2 s together in A; 2-4 s red walks far right (split); 4-6 s walks back (join);
##   6 s red takes the "elevator" to B (split, different scenes); 9 s back up to A.
## User args: --tween-time=<s> slows the slide to catch it in a shot.
extends Node

const GREEN := Color("3cc24a")
const RED := Color("e4393c")

var director: ScreenDirector
var _green: Node2D
var _red: Node2D
var _clock := 0.0
var _went_down := false
var _came_up := false


class Box:
	extends Node2D
	var rects: Array = []   # [Rect2, Color]

	func _draw() -> void:
		for r in rects:
			draw_rect(r[0], r[1])


class Pawn:
	extends Node2D
	var color := Color.WHITE

	func _draw() -> void:
		var dark := Color(0.07, 0.06, 0.09)
		# 16x32 capsule-ish body, feet at y = 0.
		draw_rect(Rect2(-9, -30, 18, 26), dark)
		draw_circle(Vector2(0, -30), 9, dark)
		draw_circle(Vector2(0, -4), 9, dark)
		draw_rect(Rect2(-8, -30, 16, 26), color)
		draw_circle(Vector2(0, -30), 8, color)
		draw_circle(Vector2(0, -4), 8, color)
		draw_rect(Rect2(-5, -32, 3, 4), dark)
		draw_rect(Rect2(2, -32, 3, 4), dark)


func _ready() -> void:
	director = ScreenDirector.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tween-time="):
			director.tween_time = float(arg.trim_prefix("--tween-time="))
	add_child(director)
	director.add_scene(&"a", _scene_a())
	director.add_scene(&"b", _scene_b())
	_green = _pawn(GREEN)
	_red = _pawn(RED)
	_green.position = Vector2(0, 0)
	_red.position = Vector2(300, 0)
	director.add_player(0, _green, &"a")
	director.add_player(1, _red, &"a")


func _pawn(c: Color) -> Node2D:
	var p := Pawn.new()
	p.color = c
	return p


func _scene_a() -> Node2D:
	var root := Node2D.new()
	root.name = "SceneA"
	var b := Box.new()
	b.rects.append([Rect2(-3000, -2000, 8000, 4000), Color("8fd3f4")])
	b.rects.append([Rect2(-3000, 0, 8000, 400), Color("4f9a3a")])
	b.rects.append([Rect2(-3000, 0, 8000, 6), Color("7ccf52")])
	var cols := [Color("f2c94c"), Color("eb5757"), Color("9b51e0"), Color("2d9cdb"), Color("f2994a")]
	for i in 30:
		var x := -1500 + i * 160
		var h := 24 + (i * 37) % 60
		b.rects.append([Rect2(x, -h, 40, h), cols[i % cols.size()]])
	root.add_child(b)
	var players := Node2D.new()
	players.name = "Players"
	root.add_child(players)
	return root


func _scene_b() -> Node2D:
	var root := Node2D.new()
	root.name = "SceneB"
	var b := Box.new()
	b.rects.append([Rect2(-3000, -2000, 8000, 4000), Color("3b2618")])
	b.rects.append([Rect2(-3000, 0, 8000, 400), Color("24160d")])
	for i in 30:
		var x := -1500 + i * 130
		var h := 20 + (i * 53) % 90
		var g := 0.35 + 0.05 * (i % 4)
		b.rects.append([Rect2(x, -h, 48, h), Color(g, g, g + 0.03)])
	root.add_child(b)
	return root


func _process(delta: float) -> void:
	_clock += delta
	var t := _clock
	_green.position.x = 0.0
	if t >= 2.0 and t < 4.0:
		_red.position.x = minf(300.0 + 1000.0 * (t - 2.0), 1300.0)
	elif t >= 4.0 and t < 6.0:
		_red.position.x = maxf(1300.0 - 1000.0 * (t - 4.0), 300.0)
	if t >= 6.0 and not _went_down:
		_went_down = true
		director.move_player(1, &"b", Vector2(200, 0))
	if t >= 9.0 and not _came_up:
		_came_up = true
		director.move_player(1, &"a", Vector2(300, 0))
