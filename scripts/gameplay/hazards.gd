## The underground's kid-safe hazards (GAME.md: "Floods float, boulders bonk, cave-ins get you
## dug out by the Mole"). Nothing here touches a backpack, the pile, a vehicle or progress.
## - Bonk: a falling boulder that lands on a player's head bounces off; the player sees stars and
##   is stunned for STUN seconds (input reads idle, gravity still works), then carries on.
## - Float: a player who enters water gets a bubble trail and a cue; the world's buoyancy lifts them.
## - Cave-in: digging into a cave-in zone (generator.cave_ins, from data/hazards) drops the ceiling
##   after a short rumble: the air around the player fills with the layer's block, leaving them in
##   a pocket. `trapped` fires; the Mole (UndergroundResidents) digs them out. Whatever happens,
##   a trapped player is free within TRAP_MAX seconds (the pocket's fill is dug out).
## Stun hooks the player's `intent_source` (wrapping whatever source it had); the player script is
## not changed. All timers run in physics time.
class_name Hazards
extends Node2D

signal bonked(player: int)
signal floated(player: int)
signal rumbled(player: int, zone: int)
signal trapped(player: int, pocket: Rect2i)
signal freed(player: int, by_mole: bool)

const STUN := 0.7
## Falling at least this fast (px/s) onto a head is a bonk.
const BONK_SPEED := 70.0
const BONK_COOLDOWN := 1.2
const CAVE_DELAY := 0.4
## A trapped player is always free by then, Mole or not.
const TRAP_MAX := 4.0
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const GOLD := Color("ffd23f")
const OUTLINE := Color("3a2a44")
const BUBBLE := Color(0.75, 0.92, 1.0, 0.9)

var u: Underground
var _stun := {}          # player -> seconds left
var _cool := {}          # player -> seconds until the next bonk may land
var _orig := {}          # player -> the intent_source we wrapped
var _wet := {}           # player -> bool
var _bubble_t := {}      # player -> seconds until the next bubble puff
var _pending: Array = [] # [{p, t, zone}]
var _traps := {}         # player -> {t, filled: Array[Vector2i], pocket: Rect2i}
var _zones_used := {}    # cave-in zone index -> true (each zone caves in once per visit)


func setup(p_u: Underground) -> void:
	u = p_u
	name = "Hazards"
	z_index = 6
	u.world.tile_dug.connect(_on_tile_dug)


# --- queries -----------------------------------------------------------------------------------

func players() -> Array[HillPlayer]:
	var out: Array[HillPlayer] = []
	if u == null or u.players_root == null:
		return out
	for n in u.players_root.get_children():
		if n is HillPlayer and (n as HillPlayer).world != null and not n.is_queued_for_deletion():
			out.append(n)
	return out


func is_stunned(p: int) -> bool:
	return float(_stun.get(p, 0.0)) > 0.0


func is_trapped(p: int) -> bool:
	return _traps.has(p)


func trap_time(p: int) -> float:
	return float(_traps[p].t) if _traps.has(p) else 0.0


func pocket_of(p: int) -> Rect2i:
	return _traps[p].pocket if _traps.has(p) else Rect2i()


# --- frame -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var ps := players()
	for pl in ps:
		_wrap(pl)
		_fx_of(pl)
	for p in _stun.keys():
		_stun[p] = maxf(0.0, float(_stun[p]) - delta)
	for p in _cool.keys():
		_cool[p] = maxf(0.0, float(_cool[p]) - delta)
	_check_bonks(ps)
	_check_water(ps, delta)
	for i in range(_pending.size() - 1, -1, -1):
		var c: Dictionary = _pending[i]
		c.t -= delta
		if c.t <= 0.0:
			_pending.remove_at(i)
			var pl := _player(int(c.p))
			if pl != null:
				cave_in(pl)
	for p in _traps.keys():
		var tr: Dictionary = _traps[p]
		tr.t += delta
		if _player(p) == null:
			_traps.erase(p)
			continue
		if _dug_out(tr):
			_traps.erase(p)
			freed.emit(p, false)
		elif tr.t >= TRAP_MAX:
			free_player(p, false)


func _player(p: int) -> HillPlayer:
	for pl in players():
		if pl.player == p:
			return pl
	return null


# --- stun --------------------------------------------------------------------------------------

## Keeps this hazard layer between the player and whatever drives it (pad, demo, test).
func _wrap(pl: HillPlayer) -> void:
	var src := pl.intent_source
	if src.is_valid() and src.get_object() == self and src.get_method() == &"_intent_of":
		return
	_orig[pl.player] = src
	pl.intent_source = _intent_of.bind(pl)


func _intent_of(pl: HillPlayer) -> Dictionary:
	if is_stunned(pl.player):
		return IDLE.duplicate()
	var src: Callable = _orig.get(pl.player, Callable())
	if src.is_valid():
		return src.call()
	# The player's own pad: read it through the player with no source set.
	var mine := pl.intent_source
	pl.intent_source = Callable()
	var it := pl.intent()
	pl.intent_source = mine
	return it


# --- bonk --------------------------------------------------------------------------------------

func _check_bonks(ps: Array[HillPlayer]) -> void:
	for b in u.boulders:
		if not is_instance_valid(b) or b.sleeping or b.linear_velocity.y < BONK_SPEED:
			continue
		var r := b.size_px.x * 0.5
		for pl in ps:
			var size := pl.body_size()
			var feet := pl.global_position
			var head := feet.y - size.y
			if absf(b.global_position.x - feet.x) > size.x * 0.5 + r * 0.8:
				continue
			var bottom := b.global_position.y + r
			if bottom >= head - 3.0 and b.global_position.y < head + size.y * 0.4:
				bonk(pl, b)


## The boulder bounces off sideways and the player sees stars for STUN seconds. Takes nothing.
func bonk(pl: HillPlayer, from: RigidBody2D = null) -> bool:
	var p := pl.player
	if float(_cool.get(p, 0.0)) > 0.0:
		return false
	_cool[p] = BONK_COOLDOWN
	_stun[p] = STUN
	pl.bump()
	Audio.play("bonk")
	var head := pl.global_position + Vector2(0, -pl.body_size().y)
	u.burst(u.world.to_local(head), GOLD, 14, 150.0)
	if from != null:
		var side := signf(from.global_position.x - pl.global_position.x)
		if side == 0.0:
			side = -float(pl.facing)
		from.linear_velocity = Vector2(side * 140.0, -170.0)
		from.angular_velocity = side * 6.0
	bonked.emit(p)
	return true


# --- float -------------------------------------------------------------------------------------

func _check_water(ps: Array[HillPlayer], delta: float) -> void:
	for pl in ps:
		var p := pl.player
		var wet := pl.in_water()
		if wet and not bool(_wet.get(p, false)):
			Audio.play("float_up")
			floated.emit(p)
			_bubble_t[p] = 0.0
		_wet[p] = wet
		if wet:
			_bubble_t[p] = float(_bubble_t.get(p, 0.0)) - delta
			if float(_bubble_t[p]) <= 0.0:
				_bubble_t[p] = 0.25
				var at := pl.global_position + Vector2(0, -pl.body_size().y - 2.0)
				_bubbles(u.world.to_local(at))


func _bubbles(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 12
	p.one_shot = true
	p.emitting = false
	p.amount = 4
	p.lifetime = 0.8
	p.explosiveness = 0.6
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = BUBBLE
	p.finished.connect(p.queue_free)
	u.world.add_child(p)
	p.emitting = true


# --- cave-in -----------------------------------------------------------------------------------

func _on_tile_dug(cell: Vector2i, _block: StringName, player: int) -> void:
	if player < 0:
		return
	var z := u.generator.cave_in_at(cell)
	if z < 0 or _zones_used.has(z) or is_trapped(player):
		return
	for c in _pending:
		if int(c.p) == player:
			return
	_zones_used[z] = true
	_pending.append({"p": player, "t": CAVE_DELAY, "zone": z})
	Audio.play("rumble")
	var r: Rect2i = u.generator.cave_ins[z].rect
	for k in 3:
		u.burst((Vector2(r.position) + Vector2(r.size.x * (0.2 + 0.3 * k), 0.0)) * 16.0, Color(0.55, 0.42, 0.3), 6, 60.0)
	rumbled.emit(player, z)


## The ceiling comes down around `pl`: every air cell touching their body fills with the layer's
## block (never landing rooms, water, edges or the other player). False when nothing could fill.
func cave_in(pl: HillPlayer, block: StringName = &"") -> bool:
	var p := pl.player
	if is_trapped(p):
		return false
	if block == &"":
		var li := u.layer_index_at(u.world.to_local(pl.global_position))
		block = HillGenerator._main_block(u.layers()[li]) if li >= 0 and li < u.layers().size() else &"dirt"
	var id := _palette_id(block)
	if id <= 0:
		return false
	var pocket := body_cells(pl)
	var others: Array[Rect2i] = []
	for o in players():
		if o != pl:
			others.append(body_cells(o))
	var filled: Array[Vector2i] = []
	var ring := pocket.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var c := Vector2i(x, y)
			if pocket.has_point(c) or not _may_fill(c, others):
				continue
			u.world.set_tile(c, id)
			filled.append(c)
	if filled.is_empty():
		return false
	_traps[p] = {"t": 0.0, "filled": filled, "pocket": pocket}
	Audio.play("cave_in")
	pl.bump()
	var center := (Vector2(pocket.position) + Vector2(pocket.size) * 0.5) * 16.0
	u.burst(center + Vector2(0, -24), u.block_color(block), 22, 120.0)
	trapped.emit(p, pocket)
	return true


func _may_fill(c: Vector2i, others: Array[Rect2i]) -> bool:
	var w := u.world
	if not w.is_loaded(c) or w.is_solid(c) or w.has_water(c) or u.generator.is_edge(c):
		return false
	if c.y >= HillGenerator.STRANGE_FROM:
		return false
	for r in u.generator.landings:
		if r.grow(1).has_point(c):
			return false
	for r in others:
		if r.grow(1).has_point(c):
			return false
	return true


## The cells a player's body covers (feet at the bottom).
func body_cells(pl: HillPlayer) -> Rect2i:
	var size := pl.body_size()
	var feet := u.world.to_local(pl.global_position)
	var a := Vector2i(floori((feet.x - size.x * 0.5) / 16.0), floori((feet.y - size.y) / 16.0))
	var b := Vector2i(floori((feet.x + size.x * 0.5 - 0.01) / 16.0), floori((feet.y - 0.01) / 16.0))
	return Rect2i(a, b - a + Vector2i.ONE)


## Digs the cave-in's fill out around player p (the Mole calls this; so does the TRAP_MAX timer).
func free_player(p: int, by_mole := true) -> void:
	if not _traps.has(p):
		return
	var tr: Dictionary = _traps[p]
	_traps.erase(p)
	for c: Vector2i in tr.filled:
		if u.world.is_solid(c):
			u.world.dig(c, [Vector2i.ZERO], -1)
		if u.world.is_solid(c):
			u.world.set_tile(c, 0)
	Audio.play("mole_pop" if by_mole else "dig_free")
	var center := (Vector2(tr.pocket.position) + Vector2(tr.pocket.size) * 0.5) * 16.0
	u.burst(center, Color("ff8fb1"), 18, 150.0)
	u.burst(center, GOLD, 12, 110.0)
	freed.emit(p, by_mole)


## The player dug a side of the fill away themselves.
func _dug_out(tr: Dictionary) -> bool:
	var pocket: Rect2i = tr.pocket
	for c: Vector2i in tr.filled:
		var beside := (c.y >= pocket.position.y and c.y < pocket.end.y) or (c.x >= pocket.position.x and c.x < pocket.end.x)
		if beside and not u.world.is_solid(c):
			return true
	return false


func _palette_id(block: StringName) -> int:
	for i in u.world.palette.size():
		if u.world.palette[i].id == block:
			return i
	return -1


# --- the stars over a bonked head --------------------------------------------------------------

func _fx_of(pl: HillPlayer) -> void:
	if pl.has_node(^"HazardFx"):
		return
	var fx := _StarsFx.new()
	fx.name = "HazardFx"
	fx.hazards = self
	fx.player = pl
	pl.add_child(fx)


class _StarsFx extends Node2D:
	var hazards: Hazards
	var player: HillPlayer
	var _t := 0.0

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(hazards) and hazards.is_stunned(player.player):
			queue_redraw()
		elif _t > 0.0:
			_t = 0.0
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(hazards) or not hazards.is_stunned(player.player):
			return
		var h := player.body_size().y
		for k in 4:
			var a := _t * 7.0 + k * TAU / 4.0
			var at := Vector2(cos(a) * 11.0, -h - 6.0 + sin(a) * 3.5)
			Hazards.draw_star(self, at, 4.0, GOLD)


static func draw_star(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(at + (q - at) * 1.35)
	ci.draw_colored_polygon(outline, OUTLINE)
	ci.draw_colored_polygon(pts, col)
