## PT-1119-1 (c), Kaden 2026-11-19 "if you dig a certain way it's basically impossible to get out":
## a rope rescue that always works. On foot underground, **hold Y** (the `horn` action; on foot a
## press only toots) for HOLD seconds: a gold ring fills over the character while it is held (let
## go and it drains). Full: the Gnome crew drops a rope from above (a hard hat at its top, a
## whistle), a picture bubble of the rope pops over the head, and the player is pulled up and out
## of sight (input locked for PULL; A or B skips straight to the landing) and lands at the nearest
## landing above them, beside the shaft (in the cage, so the A blinks), backpack kept. Never
## automatic: nothing happens without the hold.
## The hint panel offers it ("Y: rope up") only to a player who has not got a tile higher for
## STUCK_SECS while below their landing and out of the car's reach (stuck()); the pause menu's
## help shows it always (RopeHelp).
## HillGame adds one to the Underground (game.rescue); it reads each player's intent() itself.
class_name RopeRescue
extends Node2D

signal pulled(player: int, layer: int)

const HOLD := 1.5
const PULL := 1.5
## Beat timeline inside PULL: the rope drops, then the pull-up (fade out), then the landing.
const DROP_T := 0.35
const PLACE_T := 1.15
const ROPE_FROM := 150.0     # px above the head the rope hangs from
const STUCK_SECS := 10.0
const STUCK_RISE := 16.0     # a tile higher resets the stuck clock
const GOLD := Color("ffd23f")
const DARK := Color(0.07, 0.06, 0.09)

## HillGame (untyped so this script stands alone).
var game: Node
var _hold := {}      # player -> seconds Y held (on foot underground)
var _pulls := {}     # player -> {t, landing, from: Vector2, to: Vector2, prev: {dig, jump}, skipped}
var _stuck := {}     # player -> {t, deep: float}
var _tick := {}
var _need_release := {}   # player -> true after a pull until Y is let go (no second rope from one hold)


func _ready() -> void:
	name = "RopeRescue"
	z_as_relative = false
	z_index = UndergroundLook.GLOW_Z + 1   # over the darkness, like the residents' bubbles


## 0..1: how full player p's ring is.
func hold_of(p: int) -> float:
	return clampf(float(_hold.get(p, 0.0)) / HOLD, 0.0, 1.0)


func is_pulling(p: int) -> bool:
	return _pulls.has(p)


## True when the hint panel should offer the rope to player p.
func stuck(p: int) -> bool:
	return float((_stuck.get(p, {}) as Dictionary).get("t", 0.0)) >= STUCK_SECS


## The landing whose floor is nearest above (or level with) the feet at `feet`.
func landing_for(feet: Vector2) -> int:
	var ug: Node = game.underground
	var row := int(floor((feet.y - 1.0) / 16.0)) + 1
	var best := 0
	for i in ug.layers().size():
		if ug.generator.landing_floor(i) <= row:
			best = i
	return best


## Whether player p (node) may hold for the rope now: on foot, underground, free to move.
func can_hold(node: HillPlayer) -> bool:
	if node == null or node.world == null or node.vehicle != null or node.locked:
		return false
	if game.director.scene_of(node.player) != &"underground":
		return false
	var el: Object = game.get("elevator")
	return el == null or not el.is_riding(node.player)


func _physics_process(delta: float) -> void:
	if game == null:
		return
	for p: int in _pulls.keys():
		_step_pull(p, delta)
	for p: int in game.players:
		var node: HillPlayer = game.players[p]
		if _pulls.has(p):
			continue
		_track_stuck(p, node, delta)
		var held := can_hold(node) and bool(node.intent().get("horn", false))
		if not held:
			_need_release.erase(p)
		if not held or _need_release.has(p):
			_hold[p] = maxf(0.0, float(_hold.get(p, 0.0)) - delta * 3.0)
			continue
		var was := float(_hold.get(p, 0.0))
		_hold[p] = was + delta
		_tick[p] = float(_tick.get(p, 0.0)) + delta
		if _tick[p] >= 0.3:
			_tick[p] = 0.0
			Audio.play("ui_move")   # the ring fills with a tick (the press itself tooted the horn)
		if _hold[p] >= HOLD:
			start(p)
	queue_redraw()


func _track_stuck(p: int, node: HillPlayer, delta: float) -> void:
	var st: Dictionary = _stuck.get(p, {"t": 0.0, "deep": node.global_position.y})
	_stuck[p] = st
	var ug: Node = game.underground
	var el: Object = game.get("elevator")
	var below := false
	if can_hold(node):
		var i := landing_for(node.global_position)
		below = node.global_position.y > ug.generator.landing_floor(i) * 16.0 + 24.0
	var reach := el != null and int(el.prompt_of(p)) != 0
	var y := node.global_position.y
	if not below or reach:
		st.t = 0.0
		st.deep = y
		return
	st.deep = maxf(float(st.deep), y)
	if y < float(st.deep) - STUCK_RISE:
		st.t = 0.0
		st.deep = y
		return
	st.t = float(st.t) + delta


## Starts the pull-up for player p (the hold filled; tests may call it directly).
func start(p: int) -> void:
	var node: HillPlayer = game.player_node(p)
	if node == null or _pulls.has(p):
		return
	var i := landing_for(node.global_position)
	_hold[p] = 0.0
	node.locked = true
	node.velocity = Vector2.ZERO
	var it: Dictionary = node.intent()
	_pulls[p] = {"t": 0.0, "landing": i, "from": node.global_position,
			"to": game.underground.landing(i), "prev": {"dig": it.get("dig", false), "jump": it.get("jump", false)}}
	Audio.play("whistle")
	Audio.play("crane_hook")
	PictoBubbleNode.pop(game.underground, node, [&"rope"], PULL - 0.2)


func _step_pull(p: int, delta: float) -> void:
	var r: Dictionary = _pulls[p]
	var node: HillPlayer = game.player_node(p)
	if node == null:
		_pulls.erase(p)
		return
	var it: Dictionary = node.intent()
	# A or B (a fresh press) skips the beat.
	for k in ["dig", "jump"]:
		var now := bool(it.get(k, false))
		if now and not bool(r.prev.get(k, false)) and r.t < PLACE_T:
			r.t = PLACE_T
		r.prev[k] = now
	var was := float(r.t)
	r.t = was + delta
	node.locked = true
	if float(r.t) < DROP_T:
		return
	if was < DROP_T:
		Audio.play("float_up")
	if float(r.t) < PLACE_T:
		var k := (float(r.t) - DROP_T) / (PLACE_T - DROP_T)
		node.ride_offset = -48.0 * k * k
		node.modulate.a = 1.0 - k
		return
	if not r.has("placed"):
		r.placed = true
		node.ride_offset = 0.0
		game.place_player(p, &"underground", r.to)
		node.velocity = Vector2.ZERO
		Audio.play("crew_cheer")
		pulled.emit(p, int(r.landing))
	node.modulate.a = clampf((float(r.t) - PLACE_T) / maxf(PULL - PLACE_T, 0.01), 0.0, 1.0)
	if float(r.t) >= PULL:
		node.modulate.a = 1.0
		node.locked = false
		_pulls.erase(p)
		_stuck.erase(p)
		_need_release[p] = true


# --- drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	if game == null:
		return
	for p: int in game.players:
		var node: HillPlayer = game.players[p]
		if node.world == null:
			continue
		var head := node.global_position - global_position + Vector2(0, -node.body_size().y - 26.0)
		var k := hold_of(p)
		if k > 0.0 and not _pulls.has(p):
			_ring(head, k, Players.COLOR.get(p, GOLD))
		if _pulls.has(p):
			_rope(_pulls[p], node)


## The filling ring over the head: a dark disc, the Y glyph, gold filling clockwise.
func _ring(c: Vector2, k: float, col: Color) -> void:
	draw_circle(c, 12.0, Color(DARK, 0.85))
	draw_arc(c, 10.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, GOLD, 4.0, true)
	draw_arc(c, 13.0, 0, TAU, 32, Color(col, 0.8), 1.5, true)
	UiStyle.draw_glyph(self, c, 14.0, "y", 1.0)


func _rope(r: Dictionary, node: HillPlayer) -> void:
	var from: Vector2 = r.from - global_position
	var t := float(r.t)
	var top := from + Vector2(0, -node.body_size().y - ROPE_FROM)
	var hand := from + Vector2(0, -node.body_size().y + 4.0)
	var down := clampf(t / DROP_T, 0.0, 1.0)
	var end := top.lerp(hand, down)
	if t >= DROP_T and t < PLACE_T:
		end.y += node.ride_offset
	if t >= PLACE_T:
		return
	draw_line(top, end, ShaftRope.ROPE_DARK, 3.0)
	draw_line(top, end, ShaftRope.ROPE, 1.5)
	var y := top.y
	while y < end.y:
		draw_line(Vector2(top.x - 1, y), Vector2(top.x + 1, y + 2), ShaftRope.ROPE_DARK, 1.0)
		y += 6.0
	# The crew at the top: a hard hat holding the rope.
	PictoBubble.picture(self, &"hardhat", top + Vector2(0, -6), 22.0)
