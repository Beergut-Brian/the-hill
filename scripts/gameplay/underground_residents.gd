## What the residents do underground (their sprites come from UndergroundLook.residents; this node
## moves them and draws their little effects). None of them has collision, so they never block a
## tunnel, and each keeps to the room it lives in. All timers run in physics time.
## - Mole (Topsoil landing room): shuffles about, squinting; waves when a player comes close.
##   When a cave-in traps a player he dives, pops out beside them, digs them free with a happy pop,
##   waves, and goes home. (Hazards frees anyone by TRAP_MAX even if he is busy.)
## - Gnome Foreman (Gnome Room, Stone): one "noted" whistle and a salute hop when a player arrives.
## - Caveman (Ice landing room, frozen): a player's headlamp beside his ice block warms it (drips,
##   a warm glow); after THAW_SECS it cracks, he laughs, hops and heads for the shaft: he is now up
##   top by the fire (Story.thaw_caveman, saved). Warmth is never lost by stepping away.
## - Dragon (Bottom cavern, asleep): the first player to come near plays the reveal once (saved):
##   she stirs, yawns three smoke rings (never fire), purrs, and goes back to sleep.
class_name UndergroundResidents
extends Node2D

signal mole_rescued(player: int)
signal caveman_thawed()
signal dragon_revealed()

const MOLE_FILE := "characters/mole.png"
const CAVEMAN_FILE := "characters/caveman.png"
const WAVE_NEAR := 96.0
const WAVE_REARM := 170.0
const MOLE_SPEED := 18.0
## Mole rescue timeline (seconds after the cave-in).
const DIVE_AT := 0.15
const POP_AT := 0.9
const FREE_AT := 1.6
const LEAVE_AT := 2.9
const HOME_AT := 3.5
const WHISTLE_NEAR := 110.0
const THAW_NEAR := 64.0
const THAW_SECS := 3.0
const REVEAL_NEAR := 300.0
const REVEAL_TIME := 4.6
const SMOKE_AT: Array[float] = [1.3, 2.0, 2.7]
## The Dragon's mouth from her feet pivot (sheet: head on the left).
const DRAGON_MOUTH := Vector2(-48, -16)
const ICE := Color(0.7, 0.9, 1.0)
const WARM := Color(1.0, 0.72, 0.4)
const HEART := Color("ff8fb1")
const OUTLINE := Color("3a2a44")

var u: Underground
var mole: SheetSprite
var foreman: SheetSprite
var caveman: SheetSprite
var dragon: SheetSprite
var mole_home := Vector2.ZERO
var warmth := 0.0

var _t := 0.0
var _mole := {"state": &"wander", "t": 0.0, "target": 0.0, "pause": 1.0, "wave": 0.0, "armed": true}
var _rescues: Array = []              # [{p, pocket: Rect2i}] waiting for the Mole
var _rescue := {}                     # the one in progress: {p, pocket, t, at: Vector2, freed}
var _mole_room := Vector2.ZERO        # x range he shuffles in
var _foreman_armed := true
var _foreman_hop := 0.0
var _whistle := 0.0
var _foreman_y := 0.0
var _cave := {"state": &"frozen", "t": 0.0, "drip": 0.0}
var _caveman_home := Vector2.ZERO
var _dragon := {"state": &"asleep", "t": 0.0}
var _dragon_scale := Vector2.ONE
var _rings: Array = []                # [{pos, t}]
var _waves: Array = []                # [{pos, t, dir}] hello arcs


func setup(p_u: Underground) -> void:
	u = p_u
	name = "Residents"
	z_index = 7
	var r: Dictionary = u.look.residents if u.look != null else {}
	mole = r.get(&"mole")
	foreman = r.get(&"foreman")
	caveman = r.get(&"caveman")
	dragon = r.get(&"dragon")
	if mole != null:
		mole_home = mole.position
		var room: Rect2i = u.generator.landings[0]
		_mole_room = Vector2(room.position.x * 16.0 + 12.0, HillGenerator.SHAFT_X * 16.0 - 14.0)
		_mole.target = mole_home.x
	if foreman != null:
		_foreman_y = foreman.position.y
	if caveman != null:
		_caveman_home = caveman.position
	if dragon != null:
		_dragon_scale = dragon.scale
	u.hazards.trapped.connect(_on_trapped)
	sync_story()


## Applies the saved Story: a thawed Caveman is up top, not in the ice.
func sync_story() -> void:
	if caveman != null and u.story.is_thawed() and _cave.state == &"frozen":
		_cave.state = &"gone"
		caveman.visible = false


func is_rescuing() -> bool:
	return not _rescue.is_empty() or not _rescues.is_empty()


func mole_state() -> StringName:
	return _mole.state


func _physics_process(delta: float) -> void:
	_t += delta
	var ps := u.hazards.players()
	_tick_mole(ps, delta)
	_tick_foreman(ps, delta)
	_tick_caveman(ps, delta)
	_tick_dragon(ps, delta)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += delta
		if _rings[i].t > 2.2:
			_rings.remove_at(i)
	for i in range(_waves.size() - 1, -1, -1):
		_waves[i].t += delta
		if _waves[i].t > 1.0:
			_waves.remove_at(i)
	queue_redraw()


func _nearest(ps: Array[HillPlayer], at: Vector2) -> HillPlayer:
	var best: HillPlayer = null
	var d := INF
	for pl in ps:
		var dd := _local(pl).distance_to(at)
		if dd < d:
			d = dd
			best = pl
	return best


func _local(pl: Node2D) -> Vector2:
	return u.to_local(pl.global_position)


# --- Mole --------------------------------------------------------------------------------------

func _on_trapped(p: int, pocket: Rect2i) -> void:
	_rescues.append({"p": p, "pocket": pocket})


func _tick_mole(ps: Array[HillPlayer], delta: float) -> void:
	if mole == null:
		return
	if _rescue.is_empty() and not _rescues.is_empty():
		var job: Dictionary = _rescues.pop_front()
		if u.hazards.is_trapped(int(job.p)):
			_start_rescue(job)
	if not _rescue.is_empty():
		_step_rescue(delta)
		return
	# Home: shuffle between spots in the landing room, pausing to squint; wave at visitors.
	var near := _nearest(ps, mole.position)
	var dist := _local(near).distance_to(mole.position) if near != null else INF
	if dist > WAVE_REARM:
		_mole.armed = true
	if _mole.wave > 0.0:
		_mole.wave -= delta
		mole.position.y = mole_home.y - absf(sin(_mole.wave * 12.0)) * 4.0
		if near != null:
			mole.flip_h = _local(near).x < mole.position.x
		return
	mole.position.y = mole_home.y
	if dist < WAVE_NEAR and _mole.armed:
		_mole.armed = false
		_mole.wave = 1.3
		Audio.play("mole_wave")
		var dir := -1.0 if near != null and _local(near).x < mole.position.x else 1.0
		_waves.append({"pos": mole.position + Vector2(dir * 12.0, -20.0), "t": 0.0, "dir": dir})
		return
	if _mole.pause > 0.0:
		_mole.pause -= delta
		return
	var dx: float = _mole.target - mole.position.x
	if absf(dx) < 1.0:
		_mole.pause = 1.2 + fmod(_t * 7.31, 1.6)
		_mole.target = lerpf(_mole_room.x, _mole_room.y, fmod(_t * 0.618 + 0.3, 1.0))
		return
	mole.position.x += signf(dx) * minf(absf(dx), MOLE_SPEED * delta)
	mole.flip_h = dx < 0.0


func _start_rescue(job: Dictionary) -> void:
	var pocket: Rect2i = job.pocket
	# Beside the pocket, on the side nearer his home, feet on the pocket's floor.
	var side := -1.0 if mole_home.x < pocket.position.x * 16.0 else 1.0
	var x := pocket.position.x * 16.0 - 8.0 if side < 0.0 else pocket.end.x * 16.0 + 8.0
	_rescue = {"p": job.p, "pocket": pocket, "t": 0.0, "at": Vector2(x, pocket.end.y * 16.0), "side": side, "stage": 0}
	_mole.state = &"rescue"
	_mole.wave = 0.0


func _step_rescue(delta: float) -> void:
	var r := _rescue
	r.t += delta
	var t: float = r.t
	if r.stage == 0 and t >= DIVE_AT:
		r.stage = 1
		Audio.play("mole_dig")
		u.burst(mole.position + Vector2(0, -6), Color(0.5, 0.36, 0.25), 10, 90.0)
		mole.visible = false
	elif r.stage == 1 and t >= POP_AT:
		r.stage = 2
		Audio.play("mole_dig")
		mole.position = r.at
		mole.flip_h = r.side > 0.0
		mole.visible = true
		u.burst(r.at + Vector2(0, -8), Color(0.5, 0.36, 0.25), 14, 110.0)
	elif r.stage == 2:
		# Rising out of his mound.
		mole.position.y = r.at.y + maxf(0.0, 16.0 * (1.0 - (t - POP_AT) / 0.3))
		if t >= FREE_AT:
			r.stage = 3
			mole.position.y = r.at.y
			if u.hazards.is_trapped(int(r.p)):
				u.hazards.free_player(int(r.p), true)
			u.burst(r.at + Vector2(-r.side * 10.0, -24.0), HEART, 12, 90.0)
			_waves.append({"pos": r.at + Vector2(-r.side * 12.0, -22.0), "t": 0.0, "dir": -r.side})
			mole_rescued.emit(int(r.p))
	elif r.stage == 3:
		mole.position.y = r.at.y - absf(sin((t - FREE_AT) * 10.0)) * 5.0
		if t >= LEAVE_AT:
			r.stage = 4
			Audio.play("mole_dig")
			u.burst(mole.position + Vector2(0, -6), Color(0.5, 0.36, 0.25), 10, 90.0)
			mole.visible = false
	elif r.stage == 4 and t >= HOME_AT:
		mole.position = mole_home
		mole.visible = true
		u.burst(mole_home + Vector2(0, -6), Color(0.5, 0.36, 0.25), 8, 70.0)
		_rescue = {}
		_mole.state = &"wander"
		_mole.target = mole_home.x
		_mole.pause = 1.0


# --- Gnome Foreman -----------------------------------------------------------------------------

func _tick_foreman(ps: Array[HillPlayer], delta: float) -> void:
	if foreman == null:
		return
	_whistle = maxf(0.0, _whistle - delta)
	_foreman_hop = maxf(0.0, _foreman_hop - delta)
	foreman.position.y = _foreman_y - (sin(_foreman_hop / 0.4 * PI) * 5.0 if _foreman_hop > 0.0 else 0.0)
	var near := _nearest(ps, foreman.position)
	if near == null:
		return
	var d := _local(near).distance_to(foreman.position)
	if d > WAVE_REARM + 40.0:
		_foreman_armed = true
	elif d < WHISTLE_NEAR and _foreman_armed:
		_foreman_armed = false
		_foreman_hop = 0.4
		_whistle = 0.6
		Audio.play("whistle")


# --- Caveman -----------------------------------------------------------------------------------

func _tick_caveman(ps: Array[HillPlayer], delta: float) -> void:
	if caveman == null:
		return
	match _cave.state:
		&"frozen":
			var center := _caveman_home + Vector2(0, -16)
			var near := _nearest(ps, center)
			if near == null or _local(near).distance_to(center) > THAW_NEAR:
				return
			warmth = minf(THAW_SECS, warmth + delta)
			var k := warmth / THAW_SECS
			caveman.modulate = Color.WHITE.lerp(Color(1.25, 1.05, 0.85), k)
			_cave.drip -= delta
			if _cave.drip <= 0.0:
				_cave.drip = 0.35
				Audio.play("ice_drip")
				var x := _caveman_home.x + (fmod(_t * 13.7, 1.0) - 0.5) * 28.0
				u.burst(Vector2(x, _caveman_home.y - 4.0), ICE, 3, 30.0)
			if warmth >= THAW_SECS:
				thaw()
		&"thawing":
			_cave.t += delta
			var t: float = _cave.t
			if t < 1.4:
				# The laugh: three bouncy hops.
				caveman.position.y = _caveman_home.y - absf(sin(t * PI / 0.45)) * 7.0
			else:
				# Off to the shaft with a bow-legged bounce, then up he goes.
				var shaft_x := HillGenerator.SHAFT_X * 16.0 + 16.0
				var dir := signf(shaft_x - caveman.position.x)
				caveman.flip_h = dir < 0.0
				caveman.position.x += dir * minf(absf(shaft_x - caveman.position.x), 55.0 * delta)
				caveman.position.y = _caveman_home.y - absf(sin(t * 9.0)) * 2.0
				if absf(shaft_x - caveman.position.x) < 2.0:
					caveman.modulate.a = maxf(0.0, caveman.modulate.a - delta * 2.5)
					if caveman.modulate.a <= 0.0:
						_cave.state = &"gone"
						caveman.visible = false


## The ice cracks and he laughs; Story records it (once). False when he was already free.
func thaw() -> bool:
	if _cave.state != &"frozen" or not u.story.thaw_caveman():
		return false
	_cave.state = &"thawing"
	_cave.t = 0.0
	caveman.modulate = Color.WHITE
	UndergroundLook.set_anim(caveman, CAVEMAN_FILE, "idle")
	Audio.play("ice_crack")
	Audio.play("caveman_laugh")
	var c := _caveman_home + Vector2(0, -18)
	u.burst(c, ICE, 30, 170.0)
	u.burst(c, Color.WHITE, 12, 120.0)
	u.burst(c + Vector2(0, -10), HEART, 8, 70.0)
	caveman_thawed.emit()
	return true


func caveman_state() -> StringName:
	return _cave.state


# --- Dragon ------------------------------------------------------------------------------------

func _tick_dragon(ps: Array[HillPlayer], delta: float) -> void:
	if dragon == null:
		return
	if _dragon.state == &"asleep":
		if u.story.dragon_met():
			return
		var cav := HillGenerator.CAVERN
		for pl in ps:
			var at := _local(pl)
			if at.y > cav.position.y * 16.0 and absf(at.x - dragon.position.x) < REVEAL_NEAR:
				reveal()
				return
		return
	if _dragon.state != &"waking":
		return
	_dragon.t += delta
	var t: float = _dragon.t
	# Stir (0..0.7), the big yawn (0.7..3.2), settle back to sleep (3.2..REVEAL_TIME).
	var stretch := 0.0
	if t < 0.7:
		stretch = 0.03 * t / 0.7
	elif t < 3.2:
		stretch = 0.03 + 0.07 * sin(clampf((t - 0.7) / 2.5, 0.0, 1.0) * PI)
	else:
		stretch = 0.03 * maxf(0.0, 1.0 - (t - 3.2) / 0.8)
	dragon.scale = _dragon_scale * Vector2(1.0 - stretch * 0.4, 1.0 + stretch)
	for i in SMOKE_AT.size():
		if int(_dragon.get("rings", 0)) == i and t >= SMOKE_AT[i]:
			_dragon["rings"] = i + 1
			_rings.append({"pos": dragon.position + DRAGON_MOUTH * dragon.scale, "t": 0.0})
			Audio.play("smoke_ring")
	if t >= 3.2 and not _dragon.get("purred", false):
		_dragon["purred"] = true
		Audio.play("dragon_purr")
		u.burst(dragon.position + Vector2(-20, -60), HEART, 14, 80.0)
	if t >= REVEAL_TIME:
		dragon.scale = _dragon_scale
		_dragon.state = &"asleep"
		Audio.play("dragon_snore")


## The first meeting: once per save (Story.meet_dragon). False when it already happened.
func reveal() -> bool:
	if dragon == null or _dragon.state != &"asleep" or not u.story.meet_dragon():
		return false
	_dragon = {"state": &"waking", "t": 0.0, "rings": 0}
	Audio.play("dragon_yawn")
	dragon_revealed.emit()
	return true


func dragon_state() -> StringName:
	return _dragon.state


# --- drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	for r in _rings:
		# A smoke ring drifts up and left, grows and fades: soft, round, never fire.
		var k: float = r.t / 2.2
		var at: Vector2 = r.pos + Vector2(-22.0 * k, -56.0 * k)
		var rad := 7.0 + 15.0 * k
		var a := 0.95 * (1.0 - k * k)
		draw_arc(at, rad, 0.0, TAU, 24, Color(OUTLINE, a * 0.6), 7.0)
		draw_arc(at, rad, 0.0, TAU, 24, Color(0.93, 0.93, 0.97, a), 4.5)
	for w in _waves:
		# "Hello": three little arcs beside a waving paw.
		var a: float = 1.0 - float(w.t)
		for k in 3:
			var rr: float = 3.0 + k * 3.5 + float(w.t) * 4.0
			var start: float = -0.8 if float(w.dir) > 0.0 else PI - 0.8
			draw_arc(w.pos, rr, start, start + 1.6, 6, Color(1, 0.95, 0.6, a), 1.5)
	if foreman != null and _whistle > 0.0:
		var at := foreman.position + Vector2(-9, -20)
		var a := _whistle / 0.6
		for k in 3:
			var d := Vector2(-1, -0.4 + k * 0.4).normalized()
			draw_line(at + d * 3.0, at + d * (7.0 + (1.0 - a) * 4.0), Color(1, 1, 1, a), 1.5)
	if caveman != null and _cave.state == &"frozen" and warmth > 0.0:
		var k := warmth / THAW_SECS
		draw_circle(_caveman_home + Vector2(0, -18), 20.0 + 6.0 * sin(_t * 6.0), Color(WARM, 0.12 + 0.18 * k))
