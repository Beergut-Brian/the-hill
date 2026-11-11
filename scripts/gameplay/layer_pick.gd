## S-04: the pictures beside the shaft while the cage goes down. A column of pictures: the sun over
## Hillville on top, then one picture per layer the riders can reach (that layer's colour around a
## little mosaic of its blocks), deepest at the bottom. A gold cage with the riders' coloured heads
## sits beside the picked one and slides when up / down moves the pick; the picked picture is framed
## gold and bobs. No text. HillElevator makes one per ride down and frees it on arrival.
class_name LayerPick
extends Node2D

const PIC := 40.0
const GAP := 4.0
const DARK := Color(0.07, 0.06, 0.09)
const GOLD := Color("ffd23f")
const SKY := Color("58c4f0")
const GRASS := Color("6fbf3a")
const SUN := Color("ffd54a")
## Block id -> column in icons/blocks.png (assets/sprites/manifest.json "block_icons").
const ICON_COL := {&"dirt": 0, &"clay": 1, &"stone": 2, &"ice": 3, &"crystal": 4, &"edgestone": 5, &"strangestone": 6, &"sand": 7, &"pebbles": 8, &"pipe": 9, &"ore": 10, &"geode": 11, &"gaterock": 12, &"hardrock": 13}

var layers: Array = []      # LayerData, shallowest first (only the reachable ones)
var riders: Array = []      # player ids (their colours on the cage)
var pick := 0               # -1 Hillville, 0.. layer
var _marker_y := 0.0
var _pop := 0.0
var _wiggle := 0.0
var _t := 0.0
var _icons: Texture2D


func _ready() -> void:
	name = "LayerPick"
	z_index = 60
	_icons = HillvilleArt.tex("icons/blocks.png")
	_marker_y = slot_y(pick)


## Top of picture `i` (-1 = Hillville) relative to this node.
static func slot_y(i: int) -> float:
	return (i + 1) * (PIC + GAP)


func set_pick(i: int, moved: bool) -> void:
	pick = i
	if moved:
		_pop = 1.0
	else:
		_wiggle = 1.0   # pressed past the end: a little shake, nothing moves


func _process(delta: float) -> void:
	_t += delta
	_marker_y = lerpf(_marker_y, slot_y(pick), 1.0 - exp(-14.0 * delta))
	_pop = move_toward(_pop, 0.0, delta * 4.0)
	_wiggle = move_toward(_wiggle, 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	for i in range(-1, layers.size()):
		var top := slot_y(i)
		var picked := i == pick
		var grow := (2.0 + 2.0 * _pop + roundf(sin(_t * 6.0))) if picked else 0.0
		var r := Rect2(Vector2(0, top) - Vector2(grow, grow), Vector2(PIC, PIC) + Vector2(grow, grow) * 2.0)
		draw_rect(r.grow(3.0 if picked else 2.0), GOLD if picked else DARK)
		if picked:
			draw_rect(r.grow(1.0), DARK)
		var inner := Rect2(Vector2(0, top), Vector2(PIC, PIC))
		if i < 0:
			_draw_hillville(inner)
		else:
			_draw_layer(inner, layers[i])
		if not picked:
			draw_rect(inner, Color(DARK, 0.35))
	_draw_cage(Vector2(-22.0 + sin(_wiggle * 30.0) * 3.0 * _wiggle, _marker_y + PIC * 0.5))


func _draw_hillville(r: Rect2) -> void:
	draw_rect(r, SKY)
	var ground := Rect2(r.position.x, r.end.y - 11.0, r.size.x, 11.0)
	draw_rect(ground, GRASS)
	draw_rect(Rect2(ground.position + Vector2(0, 4), Vector2(r.size.x, 7)), Color("7a5a3a"))
	draw_circle(r.position + Vector2(25, 10), 6.0, SUN)
	# A little house on the grass.
	var h := Rect2(r.position + Vector2(5, r.size.y - 21), Vector2(12, 10))
	draw_rect(h, Color("e9e2d0"))
	draw_colored_polygon(PackedVector2Array([h.position + Vector2(-2, 0), h.position + Vector2(6, -7), h.position + Vector2(14, 0)]), Color("d0483c"))
	draw_rect(Rect2(h.position + Vector2(5, 4), Vector2(3, 6)), Color("6b4226"))


func _draw_layer(r: Rect2, l: LayerData) -> void:
	draw_rect(r, l.hue)
	# A 2x2 mosaic of the layer's blocks, by weight.
	var cols := _mosaic(l)
	for k in 4:
		var at := r.position + Vector2(4 + (k % 2) * 16, 4 + (k / 2) * 16)
		if _icons != null:
			draw_texture_rect_region(_icons, Rect2(at, Vector2(16, 16)), Rect2(int(cols[k]) * 16, 0, 16, 16))
		else:
			draw_rect(Rect2(at, Vector2(15, 15)), l.hue.darkened(0.2 * (k % 2)))


static func _mosaic(l: LayerData) -> Array:
	var ids: Array = l.block_mix.keys()
	ids.sort_custom(func(a, b) -> bool: return float(l.block_mix[a]) > float(l.block_mix[b]))
	var out: Array = []
	var left := 4
	for id in ids:
		var n := clampi(roundi(float(l.block_mix[id]) * 4.0), 1, left)
		for k in n:
			out.append(ICON_COL.get(id, 0))
		left -= n
		if left <= 0:
			break
	while out.size() < 4:
		out.append(out[0] if not out.is_empty() else 0)
	# Checkerboard two-block layers so both show.
	if out.size() == 4 and out[1] == out[0] and out[2] != out[0]:
		out = [out[0], out[2], out[3], out[1]]
	return out


## The cage: gold frame, the riders' heads in their colours, dark bars over them.
func _draw_cage(c: Vector2) -> void:
	var r := Rect2(c - Vector2(10, 11), Vector2(20, 22))
	draw_rect(r.grow(1.0), DARK)
	draw_rect(r, Color("3a3340"))
	var n := maxi(riders.size(), 1)
	for k in riders.size():
		var x := r.position.x + r.size.x * (k + 1.0) / (n + 1.0)
		draw_circle(Vector2(x, c.y + 1.0), 4.0, Players.COLOR.get(riders[k], Color.WHITE))
	for k in 4:
		var x := r.position.x + 2.0 + k * 5.0
		draw_rect(Rect2(x, r.position.y, 1.0, r.size.y), DARK)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), GOLD)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), GOLD)
	# Pointing at the picture.
	var tip := Vector2(r.end.x + 8.0, c.y)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -6), tip + Vector2(-7, 6)]), GOLD)
