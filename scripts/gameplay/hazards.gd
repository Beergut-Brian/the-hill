## The underground's kid-safe hazards (GAME.md: "Floods float, boulders bonk, cave-ins get you
## dug out by the Mole"). Nothing here touches a backpack, the pile, a vehicle or progress.
## - Bonk: a falling boulder that lands on a player's head bounces off; the player sees stars and
##   is stunned for STUN seconds (input reads idle, gravity still works), then carries on.
## - Float: a player who enters water gets a bubble trail and a cue; the world's buoyancy lifts them.
## - Cave-in: digging into a cave-in zone (generator.cave_ins, from data/hazards) drops the ceiling
##   after a short rumble: the air around the player fills with the layer's block, leaving them in
##   a pocket. `trapped` fires; the Mole (UndergroundResidents) digs them out. Whatever happens,
##   a trapped player is free within TRAP_MAX seconds (the pocket's fill is dug out).
## - Slide (W-11): on ice (BlockData.slippery) the stick's left/right only nudges a glide that
##   keeps going when let go and turns slowly, on foot or driving, so the player and every vehicle
##   skate, with spray and speed streaks at the feet. Not once the Dragon Perch warms the ice.
## - Ice hole (W-13): an ice rink (generator.ice_holes) ends in a hole; a slide carries the player
##   in and they drift down its chute at no more than HOLE_FALL px/s with snowflakes, a layer down,
##   onto a snow pile in the nest (a soft pop). Nothing is lost; they dig on from there.
## - Lava (W-14): a lava pocket's pool (generator.lava_pockets) is a bounce pad: standing on it
##   launches the player LAVA_HOP px/s up (a hop of at most hop_height(), about 4 tiles), with a
##   boing and an orange splash. It never hurts and never ends anything.
## Stun hooks the player's `intent_source` (wrapping whatever source it had); the player script is
## not changed. All timers run in physics time.
class_name Hazards
extends Node2D

signal bonked(player: int)
signal floated(player: int)
signal rumbled(player: int, zone: int)
signal trapped(player: int, pocket: Rect2i)
signal freed(player: int, by_mole: bool)
signal slid(player: int)
signal dropped(player: int, hole: int)
signal nested(player: int, hole: int)
signal bounced(player: int)

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
## Ice: how fast (stick units per second) a glide catches up with a push, and how slowly it lets go.
const ICE_PUSH := 3.0
const ICE_GRIP := 0.7
## The fastest a player sinks down an ice hole's chute (px/s): a drift, not a fall.
const HOLE_FALL := 210.0
## Lava: the launch speed (px/s up) and the pause before the same player bounces again.
const LAVA_HOP := 360.0
const LAVA_COOL := 0.3
const SNOW := Color(0.94, 0.97, 1.0)
const LAVA := Color("ff8a2a")
const LAVA_TOP := Color("ffc94a")

var u: Underground
var _stun := {}          # player -> seconds left
var _cool := {}          # player -> seconds until the next bonk may land
var _orig := {}          # player -> the intent_source we wrapped
var _wet := {}           # player -> bool
var _bubble_t := {}      # player -> seconds until the next bubble puff
var _pending: Array = [] # [{p, t, zone}]
var _traps := {}         # player -> {t, filled: Array[Vector2i], pocket: Rect2i}
var _zones_used := {}    # cave-in zone index -> true (each zone caves in once per visit)
var _glide := {}         # player -> the left/right the ice is carrying them with (-1..1)
var _sliding := {}       # player -> true while the ice carries them (on ice, or airborne off it)
var _slide_cd := {}      # player -> seconds until the next slide whoosh
var _drop := {}          # player -> ice hole index while drifting down its chute
var _hop_cd := {}        # player -> seconds until the next lava bounce
var _hop_t := {}         # player -> seconds since the last lava bounce (for the splash ring)
var art: Node2D


func setup(p_u: Underground) -> void:
	u = p_u
	name = "Hazards"
	z_index = 6
	# Before the players: the chute drift and the lava launch set velocity they then move by.
	process_physics_priority = -1
	u.world.tile_dug.connect(_on_tile_dug)
	art = _DeepArt.new()
	art.name = "DeepHazardArt"
	art.set("hazards", self)
	u.world.add_child(art)


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


func is_sliding(p: int) -> bool:
	return bool(_sliding.get(p, false))


func glide_of(p: int) -> float:
	return float(_glide.get(p, 0.0))


func is_dropping(p: int) -> bool:
	return _drop.has(p)


## Seconds since player p last bounced off lava (INF if never).
func since_bounce(p: int) -> float:
	return float(_hop_t.get(p, INF))


## The highest a lava bounce lifts anyone (px), from LAVA_HOP and the world's gravity.
func hop_height() -> float:
	var g := u.world.shape.gravity if u != null and u.world != null and u.world.shape != null else 980.0
	return LAVA_HOP * LAVA_HOP / (2.0 * g)


func ice_slips() -> bool:
	return u == null or u.story == null or not u.story.ice_warm()


## True when a slippery block is under any part of the player's feet.
func on_ice(pl: HillPlayer) -> bool:
	if not pl.is_on_floor():
		return false
	var feet := u.world.to_local(pl.global_position)
	var hw := pl.body_size().x * 0.5 - 1.0
	for dx in [-hw, 0.0, hw]:
		var c := u.world.shape.cell_at(feet + Vector2(dx, 3.0))
		var def := u.world.tile_def(u.world.get_tile(c))
		if def is BlockData and (def as BlockData).slippery:
			return true
		# Teetering over an ice hole's lip still slides (so a wide vehicle tips in, not stops).
		var i := u.generator.ice_hole_at(c)
		if i >= 0 and (u.generator.ice_holes[i].hole as Rect2i).has_point(c):
			return true
	return false


## The lava pocket whose pool the player's feet stand in, or -1.
func lava_under(pl: HillPlayer) -> int:
	var feet := u.world.to_local(pl.global_position)
	var c := u.world.shape.cell_at(feet + Vector2(0, -4.0))
	for i in u.generator.lava_pockets.size():
		if (u.generator.lava_pockets[i].pool as Rect2i).has_point(c):
			return i
	return -1


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
	for p in _slide_cd.keys():
		_slide_cd[p] = maxf(0.0, float(_slide_cd[p]) - delta)
	for p in _hop_cd.keys():
		_hop_cd[p] = maxf(0.0, float(_hop_cd[p]) - delta)
	for p in _hop_t.keys():
		_hop_t[p] = float(_hop_t[p]) + delta
	_check_holes(ps)
	_check_lava(ps)
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
	var it: Dictionary
	if src.is_valid():
		it = src.call()
	else:
		# The player's own pad: read it through the player with no source set.
		var mine := pl.intent_source
		pl.intent_source = Callable()
		it = pl.intent()
		pl.intent_source = mine
	return _ice(pl, it)


# --- slide (W-11) ------------------------------------------------------------------------------

## On ice the left/right the player asks for only steers a glide: it keeps going after letting go
## and swings round slowly. Off ice (on a floor) the glide is exactly the stick again.
func _ice(pl: HillPlayer, it: Dictionary) -> Dictionary:
	var p := pl.player
	var raw: Vector2 = it.get("move", Vector2.ZERO)
	var eff := float(_glide.get(p, raw.x))
	var was := is_sliding(p)
	var dt := get_physics_process_delta_time()
	var icy := ice_slips() and on_ice(pl)
	if icy:
		var pushing := absf(raw.x) > 0.2 and (absf(eff) < 0.05 or signf(raw.x) == signf(eff)) and absf(raw.x) >= absf(eff)
		eff = move_toward(eff, raw.x, (ICE_PUSH if pushing else ICE_GRIP) * dt)
		_sliding[p] = absf(eff) > 0.15 and absf(eff - raw.x) > 0.15
	elif was and not pl.is_on_floor():
		# Still carried by the slide through the air (off a ledge, into a hole), fading slowly.
		eff = move_toward(eff, raw.x, ICE_GRIP * dt)
	else:
		eff = raw.x
		_sliding[p] = false
	# A glide that runs into a wall stops there (never pinned against it).
	if absf(eff) > 0.0 and pl.is_on_wall() and pl.get_wall_normal().x * eff < 0.0 and absf(raw.x) < 0.2:
		eff = 0.0
		_sliding[p] = false
	_glide[p] = eff
	if is_sliding(p) and not was and absf(eff) > 0.45 and float(_slide_cd.get(p, 0.0)) <= 0.0:
		_slide_cd[p] = 0.8
		Audio.play("dragon_whoosh")
		var feet := u.world.to_local(pl.global_position)
		u.burst(feet + Vector2(0, -2), SNOW, 10, 90.0)
		pl.bump()
		slid.emit(p)
	if is_equal_approx(eff, raw.x):
		return it
	var out := it.duplicate()
	out.move = Vector2(eff, raw.y)
	return out


# --- ice hole (W-13) and lava (W-14) -----------------------------------------------------------

func _check_holes(ps: Array[HillPlayer]) -> void:
	for pl in ps:
		var p := pl.player
		var size := pl.body_size()
		var mid := u.world.to_local(pl.global_position) + Vector2(0, -size.y * 0.5)
		var cell := u.world.shape.cell_at(mid)
		var i := u.generator.ice_hole_at(cell)
		if i >= 0 and pl.velocity.y > HOLE_FALL:
			pl.velocity.y = HOLE_FALL
		var in_chute := i >= 0 and (u.generator.ice_holes[i].hole as Rect2i).has_point(cell)
		if in_chute and not _drop.has(p) and not pl.is_on_floor():
			_drop[p] = i
			Audio.play("float_up")
			u.burst(mid, SNOW, 14, 70.0)
			dropped.emit(p, i)
		elif _drop.has(p) and pl.is_on_floor():
			var hole := int(_drop[p])
			_drop.erase(p)
			_glide[p] = 0.0
			_sliding[p] = false
			Audio.play("pop")
			var feet := u.world.to_local(pl.global_position)
			u.burst(feet, SNOW, 22, 120.0)
			pl.bump()
			nested.emit(p, hole)


func _check_lava(ps: Array[HillPlayer]) -> void:
	for pl in ps:
		var p := pl.player
		if float(_hop_cd.get(p, 0.0)) > 0.0 or not pl.is_on_floor() or pl.velocity.y < -1.0:
			continue
		if lava_under(pl) < 0:
			continue
		bounce(pl)


## Launches pl straight up off a lava pad: LAVA_HOP px/s, never more. Takes nothing.
func bounce(pl: HillPlayer) -> void:
	var p := pl.player
	_hop_cd[p] = LAVA_COOL
	_hop_t[p] = 0.0
	pl.velocity = Vector2(pl.velocity.x, -LAVA_HOP)
	pl.bump()
	Audio.play("dragon_boing")
	var feet := u.world.to_local(pl.global_position)
	u.burst(feet, LAVA, 16, 140.0)
	u.burst(feet, LAVA_TOP, 8, 90.0)
	bounced.emit(p)


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

	func _busy() -> bool:
		if not is_instance_valid(hazards):
			return false
		var p := player.player
		return hazards.is_stunned(p) or hazards.is_sliding(p) or hazards.is_dropping(p) or hazards.since_bounce(p) < 0.45

	func _process(delta: float) -> void:
		_t += delta
		if _busy():
			queue_redraw()
		elif _t > 0.0:
			_t = 0.0
			queue_redraw()

	func _draw() -> void:
		if not _busy():
			return
		var p := player.player
		var size := player.body_size()
		var h := size.y
		if hazards.is_stunned(p):
			for k in 4:
				var a := _t * 7.0 + k * TAU / 4.0
				var at := Vector2(cos(a) * 11.0, -h - 6.0 + sin(a) * 3.5)
				Hazards.draw_star(self, at, 4.0, GOLD)
		if hazards.is_sliding(p) and not hazards.is_dropping(p):
			# Skating: speed streaks behind and an ice spray kicked up at the feet.
			var dir := signf(hazards.glide_of(p))
			for k in 3:
				var y := -h * (0.25 + 0.25 * k)
				var len := 10.0 + 4.0 * sin(_t * 20.0 + k * 2.0)
				var x0 := -dir * (size.x * 0.5 + 3.0 + k * 2.0)
				draw_line(Vector2(x0, y), Vector2(x0 - dir * len, y), Color(1, 1, 1, 0.75), 2.0)
			for k in 5:
				var f := fmod(_t * 3.0 + k * 0.2, 1.0)
				var at := Vector2(-dir * (size.x * 0.5 + f * 14.0), -2.0 - sin(f * PI) * 7.0)
				draw_circle(at, 1.8 * (1.0 - f) + 0.6, Hazards.SNOW)
		if hazards.is_dropping(p):
			# Drifting down: snowflakes rising past (we sink), the arms-up float of a feather.
			for k in 6:
				var f := fmod(_t * 0.9 + k / 6.0, 1.0)
				var at := Vector2(sin(k * 2.3 + _t * 2.0) * (size.x * 0.5 + 8.0), -h * 1.2 + (1.0 - f) * -10.0 + f * h * 1.4)
				Hazards.draw_flake(self, at, 3.0, Color(1, 1, 1, 0.9))
		var since := hazards.since_bounce(p)
		if since < 0.45:
			# Boing: an orange ring springs out under the feet.
			var k := since / 0.45
			draw_arc(Vector2(0, -2), 6.0 + k * 18.0, PI, TAU, 14, Color(Hazards.LAVA_TOP, 1.0 - k), 3.0)


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


static func draw_flake(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	for k in 3:
		var a := k * PI / 3.0
		var d := Vector2(cos(a), sin(a)) * r
		ci.draw_line(at - d, at + d, col, 1.5)


# --- the lava pools, ice-hole lips and snow nests, drawn in the world ---------------------------

class _DeepArt extends Node2D:
	var hazards: Hazards
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(hazards) or hazards.u == null:
			return
		var g := hazards.u.generator
		for lp in g.lava_pockets:
			_lava(lp.pool)
		for ih in g.ice_holes:
			_hole(ih)

	## A bright, juicy orange pool on the floor of the bottom row: a wobbly top, bubbles, glints.
	func _lava(pool: Rect2i) -> void:
		var x0 := pool.position.x * 16.0
		var x1 := pool.end.x * 16.0
		var base := pool.end.y * 16.0
		# A warm glow above it.
		for k in 3:
			draw_rect(Rect2(x0 - 6 - k * 4, base - 22 - k * 6, x1 - x0 + 12 + k * 8, 22 + k * 6), Color(1.0, 0.55, 0.15, 0.07))
		var top := PackedVector2Array()
		var n := int((x1 - x0) / 4.0)
		for i in n + 1:
			var x := x0 + (x1 - x0) * i / n
			top.append(Vector2(x, base - 9.0 + sin(_t * 3.0 + x * 0.12) * 1.6))
		var poly := top.duplicate()
		poly.append(Vector2(x1, base))
		poly.append(Vector2(x0, base))
		draw_colored_polygon(poly, Hazards.LAVA)
		draw_polyline(top, Hazards.LAVA_TOP, 2.0)
		draw_polyline(top, Hazards.OUTLINE, 1.0)
		# Short yellow dashes, like orange juice.
		for i in int((x1 - x0) / 14.0):
			var x := x0 + 6.0 + i * 14.0 + fmod(_t * 6.0, 14.0) * 0.3
			draw_line(Vector2(x, base - 4.0), Vector2(x + 5.0, base - 4.0), Color("ffe27a"), 1.5)
		# Bubbles that rise and pop.
		for i in 4:
			var f := fmod(_t * 0.7 + i * 0.37, 1.0)
			var x := x0 + (x1 - x0) * fmod(0.17 + i * 0.29, 1.0)
			draw_circle(Vector2(x, base - 9.0 - f * 8.0), 2.5 * (1.0 - f) + 0.5, Hazards.LAVA_TOP)

	## Icicles over the hole's lip, frost along the rink, flakes drifting into the chute, and a
	## round snow pile in the nest a layer down.
	func _hole(ih: Dictionary) -> void:
		var rink: Rect2i = ih.rink
		var hole: Rect2i = ih.hole
		var nest: Rect2i = ih.nest
		var floor_y := rink.end.y * 16.0
		var hx0 := hole.position.x * 16.0
		var hx1 := hole.end.x * 16.0
		# Glints skating along the ice floor toward the hole.
		var dir := float(ih.dir)
		var from := rink.position.x * 16.0 if dir > 0 else hx1
		var to := hx0 if dir > 0 else rink.end.x * 16.0
		for k in 3:
			var f := fmod(_t * 0.5 + k / 3.0, 1.0)
			var x := lerpf(from, to, f) if dir > 0 else lerpf(to, from, f)
			Hazards.draw_star(self, Vector2(x, floor_y - 1.0), 2.5, Color(1, 1, 1, 0.8 * sin(f * PI)))
		# Frosty lips on both sides of the hole, icicles hanging into it.
		for side in [hx0, hx1]:
			draw_rect(Rect2(side - 5.0, floor_y - 2.0, 10.0, 4.0), Hazards.SNOW)
			for k in 3:
				var x: float = side + (-1.0 if side == hx1 else 1.0) * (2.0 + k * 4.0)
				var ln := 6.0 + (k % 2) * 4.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2.0, floor_y), Vector2(x + 2.0, floor_y), Vector2(x, floor_y + ln)]), Color(0.8, 0.94, 1.0, 0.95))
		# Flakes drifting down the chute's first few tiles.
		for k in 8:
			var f := fmod(_t * 0.25 + k / 8.0, 1.0)
			var at := Vector2(lerpf(hx0 + 8.0, hx1 - 8.0, fmod(k * 0.39, 1.0)) + sin(_t * 1.5 + k) * 5.0, floor_y + f * 96.0)
			Hazards.draw_flake(self, at, 2.5, Color(1, 1, 1, 0.85 * (1.0 - f)))
		# The snow pile in the nest: soft and round.
		var nb := nest.end.y * 16.0
		var cx := (nest.position.x + nest.size.x * 0.5) * 16.0
		var hw := nest.size.x * 0.5 * 16.0 - 6.0
		var pile := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			pile.append(Vector2(cx + cos(a) * hw, nb + sin(a) * 9.0))
		var outline := PackedVector2Array()
		for q in pile:
			outline.append(q + (q - Vector2(cx, nb)).normalized() * 1.5)
		draw_colored_polygon(outline, Hazards.OUTLINE)
		draw_colored_polygon(pile, Hazards.SNOW)
		draw_circle(Vector2(cx - hw * 0.4, nb - 5.0), 2.0, Color(0.8, 0.9, 1.0))
