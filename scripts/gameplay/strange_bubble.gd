## W-24: Strangestone is a curious wall. A dig that bounces off it gets a ring of sparkles at the
## tile and a picture bubble with a big "?" over the digger's head (a symbol, not a word): it is a
## wonder, not a wall telling you off. One bubble per player at a time; a fresh bounce re-pops it.
## Underground adds it; Underground._on_dig_blocked calls bounce(). Drawn above the darkness.
class_name StrangeBubble
extends Node2D

const LIFE := 1.6
const SPARK_LIFE := 0.6
const GLOW_Z := 12
const RUNE := Color("b8a6ff")

var u: Node2D
## player -> {t, cell}
var bubbles := {}
var _sparks: Array = []    # [{pos, t}]
var _had := false


func _ready() -> void:
	name = "StrangeBubble"
	z_index = GLOW_Z
	z_as_relative = false
	u = get_parent() as Node2D


func bounce(cell: Vector2i, player: int) -> void:
	var cur: Dictionary = bubbles.get(player, {})
	# Holding dig against it keeps the bubble up without re-popping it every swing.
	var pop := cur.is_empty() or float(cur.t) > 0.5
	bubbles[player] = {"t": 0.0 if pop else float(cur.t), "cell": cell}
	_sparks.append({"pos": (Vector2(cell) + Vector2(0.5, 0.5)) * 16.0, "t": 0.0})


func showing(player: int) -> bool:
	return bubbles.has(player)


func _process(delta: float) -> void:
	for p in bubbles.keys():
		bubbles[p].t += delta
		if bubbles[p].t > LIFE:
			bubbles.erase(p)
	for i in range(_sparks.size() - 1, -1, -1):
		_sparks[i].t += delta
		if _sparks[i].t > SPARK_LIFE:
			_sparks.remove_at(i)
	var busy := not bubbles.is_empty() or not _sparks.is_empty()
	if busy or _had:
		queue_redraw()
	_had = busy


func _head_of(p: int) -> Vector2:
	var root: Node = u.get("players_root") if u != null else null
	if root != null:
		for n in root.get_children():
			if n is HillPlayer and (n as HillPlayer).player == p:
				return to_local((n as Node2D).global_position) + Vector2(0, -34)
	return Vector2.ZERO


func _draw() -> void:
	for s in _sparks:
		var k: float = s.t / SPARK_LIFE
		for j in 6:
			var a := j * TAU / 6.0 + k * 1.5
			var p: Vector2 = s.pos + Vector2(cos(a), sin(a)) * (6.0 + 14.0 * k)
			var c := Color(RUNE, 1.0 - k)
			draw_line(p - Vector2(2.5, 0), p + Vector2(2.5, 0), c, 1.5)
			draw_line(p - Vector2(0, 2.5), p + Vector2(0, 2.5), c, 1.5)
	for p in bubbles:
		var t: float = bubbles[p].t
		var tip := _head_of(p)
		if tip == Vector2.ZERO:
			continue
		var pop := minf(t / 0.18, 1.0)
		var k := 0.6 + 0.5 * pop - 0.1 * clampf((t - 0.18) / 0.12, 0.0, 1.0)   # overshoot, settle
		var alpha := clampf((LIFE - t) / 0.3, 0.0, 1.0)
		var bob := sin(t * 6.0) * 1.5
		PictoBubble.draw(self, tip + Vector2(0, bob), [&"question"], alpha, k)
