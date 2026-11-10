## What only one vehicle does (VehicleData.ability), owned by the HillPlayer driving it. HillPlayer
## calls step() every physics frame, on_dig() before a dig (true = the ability used it),
## allow_turn() / speed_scale() for driving, on_dump() when the elevator empties the backpack and
## draw_state() / draw_over() for the sprites. Every action has a sound and a visual.
##   tip        Dump Truck: carries 5x (data). Up top, A with a load tips the whole bed out onto the
##              pile at once (blocks fly, the crew cheers). Pushing the other way reverses with a
##              beep for a second before it turns round. The elevator dump tips the bed too.
##   hook       Crane: underground, A near a boulder (HOOK_REACH) drops the hook, lifts the boulder
##              and hauls it out for good (BOULDER_BLOCKS stone into the bag). Else A digs 3 tall.
##              Up top it opens the tall buildings in the build book, and A swings the wrecking
##              ball (H-05): at the end of the swing it bonks whatever is in front: a building leans
##              right over and springs back, the pile leans and blocks tumble off (nothing is lost),
##              scrub (stumps, rocks, trees) is knocked clear 4x2. Up + A by a building lifts it
##              on the hook (the boom telescopes up over it) and A sets it down: the build book's
##              move, seen as a crane lift. Riding the elevator down in it is the fast cable ride
##              (CraneRide).
##   pond       Excavator (H-03): up top, A on bare ground (no scrub ahead) digs 3 columns ahead of
##              the bucket a tile deeper (2 at most) and the hollow fills with water: a pond.
##   auto_drill Drill Rig: underground, A starts it drilling 5 wide straight down on its own; A again
##              (or hopping out, or hitting the unbreakable bottom) stops it. Up top it only spins
##              up and puffs: it is too big to work there.
class_name VehicleAbility
extends RefCounted

const TIP_UP := 0.45
const TIP_HOLD := 0.35
const TIP_DOWN := 0.4
const REVERSE_TURN := 1.0
const REVERSE_SPEED := 0.7
const BEEP_EVERY := 0.45
const HOOK_REACH := 88.0
const HOOK_DOWN := 0.4
const HOOK_UP := 0.55
const DRILL_EVERY := 0.16
const DRILL_STUCK := 0.8
const SHAKE_PX := 2.0
## H-05 wrecking ball: one swing, the bonk at BALL_HIT, reach ahead of the cab, rope length.
const BALL_SWING := 0.75
const BALL_HIT := 0.3
const BALL_REACH := 84.0
const BALL_ROPE := 34.0
## How high a lifted building rides (px) and how fast it goes up.
const LIFT_PX := 26.0
const LIFT_TIME := 0.3

var pl: HillPlayer
var data: VehicleData
var kind: StringName

## Dump Truck
var bed := 0.0
var tipping := -1.0
var reverse_t := 0.0
var _beep_t := 0.0
var _beep := 0.0
var _paid := false
## Crane: -1 idle, else seconds into the haul.
var hooking := -1.0
var hook_from := Vector2.ZERO     # hook target (vehicle-local px) while hooking
var ball := -1.0                  # seconds into a wrecking-ball swing, -1 idle
var lift := 0.0                   # 0..1 a carried building off the ground
var _carrying := false
## Drill Rig
var drilling := false
var spin := 0.0
var _drill_cd := 0.0
var _stuck := 0.0
var _shake := 0.0

signal tipped(blocks: int)
signal hauled(index: int)
signal drill_changed(on: bool)
## H-05: the wrecking ball bonked these (StringName: &"building", &"pile", &"scrub").
signal ball_hit(what: Array)
## H-03: the Excavator dug this many pond tiles.
signal pond_dug(tiles: int)


static func make(p: HillPlayer, d: VehicleData) -> VehicleAbility:
	if d == null or d.ability == &"":
		return null
	var a := VehicleAbility.new()
	a.pl = p
	a.data = d
	a.kind = d.ability
	return a


func _cue(key: StringName, fallback: String) -> String:
	return String(data.sounds.get(key, fallback))


func up_top() -> bool:
	return pl.world == null


## Called when the player hops out.
func stop() -> void:
	if drilling:
		set_drilling(false)


func step(delta: float, it: Dictionary, a_press: bool) -> void:
	_beep = move_toward(_beep, 0.0, delta * 3.0)
	match kind:
		&"tip": _step_tip(delta, it)
		&"hook":
			_step_hook(delta)
			_step_ball(delta)
		&"auto_drill": _step_drill(delta, a_press)


## True: the ability used this dig tick (no normal dig).
func on_dig(move: Vector2) -> bool:
	match kind:
		&"tip":
			if tipping >= 0.0:
				return true
			if up_top() and pl.backpack_count() > 0:
				start_tip()
				return true
		&"hook":
			if hooking >= 0.0:
				return true
			if not up_top():
				return try_hook()
			if ball < 0.0:
				start_ball()
			return true
		&"pond":
			if up_top():
				var hv: Node = pl.game.get("hillville") if pl.game != null else null
				if hv != null and hv.has_method("dig_pond"):
					var n: int = hv.dig_pond(pl.global_position, pl.facing, data.clear_area.x, pl.player)
					if n != 0:
						pl.bump()
						if n > 0:
							Audio.play(_cue(&"dig", "excavator_dig"))
							pond_dug.emit(n)
						return true
		&"auto_drill":
			if up_top():
				Audio.play(_cue(&"spin", "drill_rig_spin"))
				spin = 0.6
				var hv: Node = pl.game.get("hillville") if pl.game != null else null
				if hv != null and hv.has_method("puff"):
					hv.puff(hv.to_local(pl.global_position), Color(0.85, 0.8, 0.7), 8)
			return true
	return false


## Dump Truck: may the truck turn to face `want` now? Pushing back reverses first.
func allow_turn(want: int, delta: float) -> bool:
	if kind != &"tip" or want == pl.facing:
		reverse_t = 0.0
		return true
	reverse_t += delta
	_beep_t -= delta
	if _beep_t <= 0.0:
		_beep_t = BEEP_EVERY
		_beep = 1.0
		Audio.play(_cue(&"reverse", "dump_truck_reverse"))
	if reverse_t >= REVERSE_TURN:
		reverse_t = 0.0
		return true
	return false


func is_reversing() -> bool:
	return kind == &"tip" and reverse_t > 0.0


func speed_scale() -> float:
	if kind == &"auto_drill" and drilling:
		return 0.0
	if kind == &"hook" and hooking >= 0.0:
		return 0.0
	return REVERSE_SPEED if is_reversing() else 1.0


## The elevator (or a tip) emptied the backpack.
func on_dump() -> void:
	if kind == &"tip" and tipping < 0.0:
		tipping = 0.0
		_paid = true
		Audio.play(_cue(&"tip", "dump_truck_tip"))


# --- Dump Truck --------------------------------------------------------------------------------

func start_tip() -> void:
	tipping = 0.0
	_paid = false
	Audio.play(_cue(&"tip", "dump_truck_tip"))


func _step_tip(delta: float, it: Dictionary) -> void:
	var mx: float = (it.get("move", Vector2.ZERO) as Vector2).x
	if absf(mx) < 0.2:
		reverse_t = 0.0
		_beep_t = 0.0
	if tipping < 0.0:
		bed = 0.0
		return
	tipping += delta
	if tipping < TIP_UP:
		bed = tipping / TIP_UP
	elif tipping < TIP_UP + TIP_HOLD:
		bed = 1.0
		if not _paid:
			_pay_out()
	elif tipping < TIP_UP + TIP_HOLD + TIP_DOWN:
		bed = 1.0 - (tipping - TIP_UP - TIP_HOLD) / TIP_DOWN
	else:
		bed = 0.0
		tipping = -1.0


## The whole load onto the pile at once.
func _pay_out() -> void:
	_paid = true
	var bag := pl.backpack
	pl.backpack = {}
	var n := 0
	for b in bag:
		Inventory.add(StringName(b), int(bag[b]))
		n += int(bag[b])
	Audio.play("pile_dump")
	var hv: Node = pl.game.get("hillville") if pl.game != null else null
	if hv != null and hv.has_method("puff"):
		var back: Vector2 = hv.to_local(pl.global_position) + Vector2(-pl.facing * 30.0, -6.0)
		for b in bag:
			hv.puff(back, Hillville.block_color(StringName(b)), 6)
	tipped.emit(n)


# --- Crane -------------------------------------------------------------------------------------

func _ug() -> Underground:
	return pl.game.get("underground") if pl.game != null else null


## Hooks the nearest boulder in reach; false when there is none (A digs instead).
func try_hook() -> bool:
	var u := _ug()
	if u == null:
		return false
	var tip := pl.global_position + Vector2(pl.facing * 20.0, -40.0)
	var i := u.boulder_near(tip, HOOK_REACH)
	if i < 0:
		return false
	hook_from = pl.to_local(u.boulders[i].global_position)
	hooking = 0.0
	Audio.play(_cue(&"hook", "crane_hook"))
	u.haul_boulder(i, pl.player)
	for k in Underground.BOULDER_BLOCKS:
		pl.keep_block(&"stone")
	hauled.emit(i)
	return true


func _step_hook(delta: float) -> void:
	if hooking < 0.0:
		return
	hooking += delta
	if hooking >= HOOK_DOWN + HOOK_UP:
		hooking = -1.0
		Audio.play("pop")


## 0..1 how far the hook is from the boom tip to the boulder (and back with it).
func hook_reach() -> float:
	if hooking < 0.0:
		return 0.0
	if hooking < HOOK_DOWN:
		return hooking / HOOK_DOWN
	return 1.0 - (hooking - HOOK_DOWN) / HOOK_UP


## Crane up top: A belongs to the wrecking ball, unless the player pushes up (lift a building)
## or already carries one (set it down). HillPlayer asks before the build controller's A.
func claims_a(move: Vector2, build: Object) -> bool:
	if kind != &"hook" or not up_top():
		return false
	if build != null and build.has_method("has_ghost") and build.has_ghost(pl.player):
		return false
	return move.y > -0.5


func start_ball() -> void:
	ball = 0.0
	Audio.play("swing")


## Pendulum angle (radians, + = toward facing) of the ball at `k` seconds into the swing.
static func ball_angle(k: float) -> float:
	if k < 0.0:
		return sin(Time.get_ticks_msec() * 0.0017) * 0.06
	var u := k / BALL_SWING
	if u < 0.15:
		return -0.6 * u / 0.15
	if u < 0.4:
		return lerpf(-0.6, 1.3, smoothstep(0.0, 1.0, (u - 0.15) / 0.25))
	var w := (u - 0.4) / 0.6
	return 1.3 * cos(w * PI * 1.5) * (1.0 - w)


func _step_ball(delta: float) -> void:
	# Lifting: the carried building rises on the hook.
	var hv: Node = pl.game.get("hillville") if pl.game != null else null
	var g := carried()
	var carrying := g != null
	if carrying and not _carrying:
		Audio.play(_cue(&"hook", "crane_hook"))
	_carrying = carrying
	lift = move_toward(lift, 1.0 if carrying else 0.0, delta / LIFT_TIME)
	if ball < 0.0:
		return
	var was := ball
	ball += delta
	if was < BALL_HIT and ball >= BALL_HIT:
		_ball_hit(hv)
	if ball >= BALL_SWING:
		ball = -1.0


## The placed building this crane carries on the hook, or null.
func carried() -> Building:
	if kind != &"hook" or not up_top() or pl.game == null:
		return null
	var build: Object = pl.game.get("build")
	if build == null or not build.has_method("ghost_of"):
		return null
	var g: Building = build.ghost_of(pl.player)
	return g if g != null and is_instance_valid(g) and g.index >= 0 else null


## Px the build controller lifts this player's ghost off the ground.
func lift_px() -> float:
	return LIFT_PX * ease(lift, -2.0) if kind == &"hook" else 0.0


## The bonk: everything in the swing's reach ahead of the cab.
func _ball_hit(hv: Node) -> void:
	if hv == null:
		return
	var x := pl.global_position.x
	var a := x + pl.facing * 8.0
	var b := x + pl.facing * BALL_REACH
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var what: Array = []
	if hv.has_method("buildings_root"):
		for n in hv.buildings_root().get_children():
			var bd := n as Building
			if bd == null or bd.ghost or bd.data == null:
				continue
			var x0 := bd.global_position.x
			if x0 + bd.size_px().x >= lo and x0 <= hi:
				knock_building(bd, pl.facing)
				what.append(&"building")
	if hv.has_method("pile_span"):
		var sp: Vector2 = hv.pile_span()
		var on_pile := 0
		for blk in Hillville.BLOCK_ORDER:
			on_pile += Inventory.count(blk)
		if sp.y >= lo and sp.x <= hi and on_pile > 0:
			hv.knock_pile(pl.facing)
			what.append(&"pile")
	if hv.has_method("scoop"):
		var n: int = hv.scoop(pl.global_position, pl.facing, data.clear_area, pl.player)
		if n > 0:
			what.append(&"scrub")
			if n >= HillPlayer.BIG_SCOOP:
				ScreenKick.kick(pl.player, 1.5 + 0.25 * mini(n, 6), 0.22)
	if what.has(&"building") or what.has(&"pile"):
		Audio.play("bonk")
		ScreenKick.kick(pl.player, 3.0, 0.25)
	pl.bump()
	ball_hit.emit(what)


## A bonk, never damage: the building leans right over away from the ball and springs back.
static func knock_building(bd: Building, dir: int) -> void:
	var t := bd.create_tween()
	t.tween_property(bd, "skew", dir * 0.45, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.2)
	t.tween_property(bd, "skew", 0.0, 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var hv := bd.get_parent()
	while hv != null and not hv.has_method("puff"):
		hv = hv.get_parent()
	if hv != null:
		hv.puff(bd.position + Vector2(bd.size_px().x * (0.5 + dir * 0.5), 0), Color(0.85, 0.75, 0.6), 8)


# --- Drill Rig ---------------------------------------------------------------------------------

func set_drilling(on: bool) -> void:
	if on == drilling:
		return
	drilling = on
	_stuck = 0.0
	_drill_cd = 0.25
	Audio.play(_cue(&"spin", "drill_rig_spin") if on else "drill_stop")
	drill_changed.emit(on)
	if not on:
		_set_shake(0.0)


func _step_drill(delta: float, a_press: bool) -> void:
	spin = move_toward(spin, 1.0 if drilling else 0.0, delta * 2.5)
	if up_top():
		if drilling:
			set_drilling(false)
		return
	if a_press:
		set_drilling(not drilling)
	if not drilling:
		return
	_drill_cd -= delta
	if _drill_cd > 0.0:
		return
	_drill_cd = DRILL_EVERY
	if pl.dig_now(Vector2(0, 1)):
		_stuck = 0.0
		_shake = 1.0
	elif pl.is_on_floor():
		_stuck += DRILL_EVERY
		if _stuck >= DRILL_STUCK:
			Audio.play("dig_blocked")
			set_drilling(false)
	_shake = move_toward(_shake, 0.0, 0.5)
	_set_shake(_shake)


## A small camera rumble while drilling (Settings: screen shake off = no rumble).
func _set_shake(k: float) -> void:
	var dir = pl.game.get("director") if pl.game != null else null
	if dir == null or not dir.has_method("camera_of"):
		return
	var cam: Camera2D = dir.camera_of(pl.player)
	if cam == null:
		return
	if k > 0.0 and SettingsPanel.screen_shake():
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * SHAKE_PX * k
	else:
		cam.offset = Vector2.ZERO


# --- drawing -----------------------------------------------------------------------------------

## For Vehicle.draw_vehicle: bed (0..1 tip), load (0..1), hook (vehicle-local target, reach 0..1),
## spin (0..1 how fast the bit turns).
func draw_state() -> Dictionary:
	var s := {}
	match kind:
		&"tip":
			s.bed = bed
			s.load = clampf(float(pl.backpack_count()) / maxf(1.0, float(pl.capacity())), 0.0, 1.0)
		&"hook":
			if hooking >= 0.0:
				s.hook = hook_from
				s.reach = hook_reach()
				s.carry = hooking >= HOOK_DOWN
			elif up_top():
				var g := carried()
				if g != null:
					s.lift = pl.to_local(g.global_position + Vector2(g.size_px().x * 0.5, -g.size_px().y))
				else:
					s.ball = ball_angle(ball)
					s.face = pl.facing
		&"auto_drill":
			s.spin = spin
	return s


## Effects over the vehicle: the reverse beep rings at the back.
func draw_over(ci: CanvasItem) -> void:
	if kind == &"tip" and _beep > 0.0:
		var h := Vehicle.body_size(data)
		var at := Vector2(-pl.facing * (h.x * 0.5 + 4.0), -h.y * 0.6)
		for k in 2:
			var rr := 3.0 + (1.0 - _beep) * 10.0 + k * 5.0
			var a0 := PI - 0.7 if pl.facing > 0 else -0.7
			ci.draw_arc(at, rr, a0, a0 + 1.4, 8, Color(1, 0.55, 0.2, _beep), 2.0)
