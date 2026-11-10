## What the residents do underground (their sprites come from UndergroundLook.residents; this node
## moves them and draws their little effects). None of them has collision, so they never block a
## tunnel, and each keeps to the room it lives in. All timers run in physics time.
## - Mole (Topsoil landing room): shuffles about, squinting; waves when a player comes close.
##   When a cave-in traps a player he dives, pops out beside them, digs them free with a happy pop,
##   waves, and goes home. (Hazards frees anyone by TRAP_MAX even if he is busy.)
##   The arc (Story, saved): until he has ARRIVED, a player digging on foot in Topsoil or Clay gets
##   their shovel "stolen" (after STEAL_FIRST tiles, then every STEAL_EVERY, STEAL_COOLDOWN apart,
##   never during a rescue): he pops up beside them, the shovel arcs into his paws, a sheepish
##   picture bubble, it arcs straight back with hearts, he dives and pops up at home. The player is
##   never slowed or locked. After the third he waves and dives "up" (he waits at the shaft up top)
##   and his home sprite is hidden; he still comes for every cave-in. Once his Lost & Found stands
##   (RESTORED) he visits a player underground every VISIT_EVERY s with a bundle: unfound treasure
##   near him glows gold, and when he leaves he drops a found thing (3 blocks of that layer).
## - Gnome crew (Gnome Room, Stone): the Foreman is up top from the start; his crew of three is
##   walled in, hard hats bobbing over the bricks (a muffled whistle when a player comes near).
##   Opening the Gnome Room (the treasure) crumbles the wall: they hop, whistle, Story.free_crew,
##   and march off out of the room (the way the player came in) and fade: they are up top now.
## - Caveman (Ice landing room, frozen): a player's headlamp beside his ice block warms it (drips,
##   a warm glow); after THAW_SECS it cracks, he laughs, hops and follows the nearest player at
##   FOLLOW_GAP, hooting; when they are at the shaft or ride up (or after FOLLOW_MAX) he walks into
##   the shaft and fades: he is now up top by the fire (Story.thaw_caveman, saved).
## - Dragon (Bottom cavern, asleep): the first player to come near plays the reveal once (saved):
##   she stirs, yawns three smoke rings (never fire), purrs, and goes back to sleep. At the second
##   meeting (a player within WAKE_NEAR, or lingering within LINGER_NEAR) she wakes for good:
##   stretch, two picture bubbles (the shaken hill, sheepish; the Ruined Keep, hopeful), a purr,
##   Story.wake_dragon, and she goes up the shaft in three pieces, head first. Never fire or shake.
class_name UndergroundResidents
extends Node2D

signal mole_rescued(player: int)
signal caveman_thawed()
signal dragon_revealed()
## W-17: a sleeping snore was felt by a player (loudness 0..1, 1 in the cavern).
signal dragon_snored(loudness: float)
## The Mole took a shovel (and is about to give it straight back). Story already counted it.
signal shovel_stolen(player: int)
## The Gnome Room's wall crumbled: the crew is free.
signal crew_freed()
## The Dragon's second meeting is done: she is on her way up.
signal dragon_woke()
## A Lost & Found visit ended with a gift of `count` blocks of `block`.
signal mole_gift(block: StringName, count: int)

const MOLE_FILE := "characters/mole.png"
const CAVEMAN_FILE := "characters/caveman.png"
const DRAGON_FILE := "characters/dragon.png"
const WAVE_NEAR := 96.0
const WAVE_REARM := 170.0
const MOLE_SPEED := 18.0
## Mole rescue timeline (seconds after the cave-in).
const DIVE_AT := 0.15
const POP_AT := 0.9
const FREE_AT := 1.6
const LEAVE_AT := 2.9
const HOME_AT := 3.5
## Shovel thefts: tiles dug on foot in Topsoil / Clay before the first, then between thefts, and
## the least physics time from one theft's end to the next.
const STEAL_FIRST := 6
const STEAL_EVERY := 14
const STEAL_COOLDOWN := 20.0
const STEAL_LAYERS: Array[StringName] = [&"topsoil", &"clay"]
## Theft timeline (seconds): pop up beside, grab (the shovel arcs over), hold it with the bubble,
## give it back (arcs to the player), dive, pop up at home. The third waves and dives "up".
const T_POP := 0.3
const T_GRAB := 0.6
const T_HOLD := 1.0
const T_BACK := 2.1
const T_GIVEN := 2.5
const T_DIVE := 2.8
const T_HOME := 3.2
const T_WAVE_UP := 2.6
const T_DIVE_UP := 3.5
const POP_SIDE := 26.0
## Lost & Found visits (Mole RESTORED).
const VISIT_EVERY := Vector2(25.0, 35.0)
const VISIT_STAY := 6.0
const VISIT_GLOW_TILES := 12
const VISIT_GIFT := 3
const WHISTLE_NEAR := 110.0
const CREW_SCALE := 0.8
const CREW_MARCH_AT := 1.8
const CREW_STEP := 0.22
const CREW_STEP_PX := 6.0
const CREW_FADE := Vector2(3.0, 4.0)   # seconds after the march starts: fade from, gone at
const BRICK := Color("b5654a")
## The wall's height: the crew (CREW_SCALE) shows hard hats and eyes over it.
const WALL_H := 13.0
const THAW_NEAR := 64.0
const THAW_SECS := 3.0
const FOLLOW_GAP := 30.0
const FOLLOW_MAX := 25.0
const FOLLOW_SPEED := 240.0
const SHAFT_NEAR := 48.0
const HOOT_EVERY := 2.4
const REVEAL_NEAR := 300.0
const REVEAL_TIME := 4.6
const SMOKE_AT: Array[float] = [1.3, 2.0, 2.7]
## The second meeting: close (from her middle), or lingering a while a bit further off; never
## straight after the first meeting's yawn.
const WAKE_NEAR := 100.0
const LINGER_NEAR := 170.0
const LINGER_SECS := 2.0
const WAKE_GRACE := 1.5
## Second meeting timeline: stretch, bubble one, bubble two, purr (and Story), then the pieces.
const WAKE_BUBBLE1 := 1.0
const WAKE_BUBBLE2 := 3.0
const WAKE_PURR := 5.0
const WAKE_LEAVE := 5.6
const PIECE_GAP := 0.45
const PIECE_SLIDE := 420.0
## The Dragon's mouth and head from her feet pivot (sheet: head on the left).
const DRAGON_MOUTH := Vector2(-48, -16)
const DRAGON_HEAD := Vector2(-52, -46)
const ICE := Color(0.7, 0.9, 1.0)
const WARM := Color(1.0, 0.72, 0.4)
const HEART := Color("ff8fb1")
const GOLD := Color("ffd23f")
const DIRT := Color(0.5, 0.36, 0.25)
const OUTLINE := Color("3a2a44")

var u: Underground
var mole: SheetSprite
## The crew's first member (kept under the old name: tests and tools look for it).
var foreman: SheetSprite
var crew: Array[SheetSprite] = []
var caveman: SheetSprite
var dragon: SheetSprite
var mole_home := Vector2.ZERO
var warmth := 0.0
## Tunable for tests and beats (the GAME.md numbers are the constants).
var steal_cooldown := STEAL_COOLDOWN

var _t := 0.0
var _mole := {"state": &"wander", "t": 0.0, "target": 0.0, "pause": 1.0, "wave": 0.0, "armed": true}
var _rescues: Array = []              # [{p, pocket: Rect2i}] waiting for the Mole
var _rescue := {}                     # the one in progress: {p, pocket, t, at: Vector2, freed}
var _mole_room := Vector2.ZERO        # x range he shuffles in
var _theft := {}                      # {p, t, at, side, stage, last, shovel: Vector2}
var _dug := 0                         # qualifying tiles since the last theft
var _steal_ready := 0.0               # _t from which the next theft may start
var _visit := {}                      # {p, t, at, stage, block, glow: Array}
var _visit_in := 0.0
var _gift := {}                       # the dropped bundle popping: {pos, t}
var _crew := {"state": &"walled", "t": 0.0, "armed": true, "hop": 0.0, "bubble": 0.0}
var _crew_home: Array[Vector2] = []
var _wall := Rect2()
var _bricks: Array = []               # crumbling: [{pos, v, t}]
var _whistle := 0.0
var _whistle_at := Vector2.ZERO
var _cave := {"state": &"frozen", "t": 0.0, "drip": 0.0, "hoot": 0.0}
var _caveman_home := Vector2.ZERO
var _dragon := {"state": &"asleep", "t": 0.0}
var _dragon_scale := Vector2.ONE
## W-17 snore: seconds to the next one, how far above the cavern it is still felt, and a count.
const SNORE_EVERY := 5.0
const SNORE_REACH := 40.0 * 16.0
var snores := 0
var _snore_t := 2.0
var _dragon_rest := 0.0               # grace after the first meeting's yawn
var _linger := 0.0
var _pieces: Array = []               # [{src: Rect2, pos: Vector2, t, rise: bool, gone: bool, cue}]
var _rings: Array = []                # [{pos, t}]
var _waves: Array = []                # [{pos, t, dir}] hello arcs
var _over: Node2D                     # bubbles, the shovel, glows and pieces: above the darkness


func setup(p_u: Underground) -> void:
	u = p_u
	name = "Residents"
	z_index = 7
	_over = Node2D.new()
	_over.name = "Over"
	_over.z_as_relative = false
	_over.z_index = UndergroundLook.GLOW_Z + 1
	_over.draw.connect(_draw_over)
	add_child(_over)
	var r: Dictionary = u.look.residents if u.look != null else {}
	mole = r.get(&"mole")
	caveman = r.get(&"caveman")
	dragon = r.get(&"dragon")
	for i in 3:
		var c: SheetSprite = r.get(StringName("crew_%d" % i))
		if c != null:
			crew.append(c)
			_crew_home.append(c.position)
	foreman = crew[0] if not crew.is_empty() else r.get(&"foreman")
	if not _crew_home.is_empty():
		var x0 := _crew_home[0].x
		var x1 := _crew_home[_crew_home.size() - 1].x
		var fy := _crew_home[0].y
		_wall = Rect2(x0 - 16.0, fy - WALL_H, x1 - x0 + 32.0, WALL_H)
	if mole != null:
		mole_home = mole.position
		var room: Rect2i = u.generator.landings[0]
		_mole_room = Vector2(room.position.x * 16.0 + 12.0, HillGenerator.SHAFT_X * 16.0 - 14.0)
		_mole.target = mole_home.x
	if caveman != null:
		_caveman_home = caveman.position
	if dragon != null:
		_dragon_scale = dragon.scale
	_visit_in = VISIT_EVERY.x
	u.hazards.trapped.connect(_on_trapped)
	Events.tile_dug.connect(_on_tile_dug)
	Events.treasure_found.connect(_on_treasure_found)
	u.story.changed.connect(sync_story)
	# Deferred: HillGame loads the save (Progress, then Story) right after this, in the same frame.
	sync_story.call_deferred()


func _exit_tree() -> void:
	if Events.tile_dug.is_connected(_on_tile_dug):
		Events.tile_dug.disconnect(_on_tile_dug)
	if Events.treasure_found.is_connected(_on_treasure_found):
		Events.treasure_found.disconnect(_on_treasure_found)


## Applies the saved Story (also live, on Story.changed): a Mole up top is hidden at home, a freed
## crew is gone (an opened Gnome Room frees them now), a thawed Caveman is up top, a woken Dragon is
## gone from the cavern, and the Dragon Perch warms the Ice layer. Never cuts a moment short.
func sync_story() -> void:
	var st := u.story
	if mole != null and st.in_town(Story.MOLE) and _mole.state == &"wander":
		mole.visible = false
	if _crew.state == &"walled":
		if st.in_town(Story.FOREMAN):
			_crew.state = &"gone"
			for c in crew:
				c.visible = false
		elif Progress.has_treasure(&"gnome_room"):
			free_crew()
	elif not st.in_town(Story.FOREMAN) and Progress.has_treasure(&"gnome_room"):
		# Freed before a save loaded over the Story (setup runs before HillSave.apply).
		st.free_crew()
	if caveman != null and st.is_thawed() and _cave.state == &"frozen":
		_cave.state = &"gone"
		caveman.visible = false
	if dragon != null and st.in_town(Story.DRAGON) and _dragon.state == &"asleep":
		_dragon.state = &"gone"
		dragon.visible = false
	if u.look != null:
		u.look.set_ice_warm(st.ice_warm())


func is_rescuing() -> bool:
	return not _rescue.is_empty() or not _rescues.is_empty()


func mole_state() -> StringName:
	return _mole.state


func _physics_process(delta: float) -> void:
	_t += delta
	var ps := u.hazards.players()
	_tick_mole(ps, delta)
	_tick_crew(ps, delta)
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
	for i in range(_bricks.size() - 1, -1, -1):
		var b: Dictionary = _bricks[i]
		b.t += delta
		b.v.y += 420.0 * delta
		b.pos += b.v * delta
		if b.t > 0.9:
			_bricks.remove_at(i)
	if not _gift.is_empty():
		_gift.t += delta
		if _gift.t > 0.9:
			_gift = {}
	_whistle = maxf(0.0, _whistle - delta)
	queue_redraw()
	_over.queue_redraw()


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


func _player(p: int) -> HillPlayer:
	for pl in u.hazards.players():
		if pl.player == p:
			return pl
	return null


func _layer_id_at(y: float) -> StringName:
	var i := u.layer_index_at(Vector2(0, y))
	return (u.layers()[i] as LayerData).id if i >= 0 and i < u.layers().size() else &""


# --- Mole --------------------------------------------------------------------------------------

func _on_trapped(p: int, pocket: Rect2i) -> void:
	_rescues.append({"p": p, "pocket": pocket})


func _tick_mole(ps: Array[HillPlayer], delta: float) -> void:
	if mole == null:
		return
	if not _rescues.is_empty():
		# A cave-in always comes first: a theft gives the shovel back now, a visit leaves its gift.
		if not _theft.is_empty():
			_end_theft(true)
		if not _visit.is_empty():
			_end_visit()
	if _rescue.is_empty() and not _rescues.is_empty():
		var job: Dictionary = _rescues.pop_front()
		if u.hazards.is_trapped(int(job.p)):
			_start_rescue(job)
	if not _rescue.is_empty():
		_step_rescue(delta)
		return
	if not _theft.is_empty():
		_step_theft(delta)
		return
	if u.story.restored(Story.MOLE):
		_tick_visits(ps, delta)
		if not _visit.is_empty():
			return
	if u.story.in_town(Story.MOLE):
		mole.visible = false
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
		if mole.visible:
			u.burst(mole.position + Vector2(0, -6), DIRT, 10, 90.0)
		mole.visible = false
	elif r.stage == 1 and t >= POP_AT:
		r.stage = 2
		Audio.play("mole_dig")
		mole.position = r.at
		mole.flip_h = r.side > 0.0
		mole.visible = true
		u.burst(r.at + Vector2(0, -8), DIRT, 14, 110.0)
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
			u.burst(mole.position + Vector2(0, -6), DIRT, 10, 90.0)
			mole.visible = false
	elif r.stage == 4 and t >= HOME_AT:
		mole.position = mole_home
		# Up top for good (ARRIVED or living in his Lost & Found): he goes back up, not home.
		mole.visible = not u.story.in_town(Story.MOLE)
		if mole.visible:
			u.burst(mole_home + Vector2(0, -6), DIRT, 8, 70.0)
		_rescue = {}
		_mole.state = &"wander"
		_mole.target = mole_home.x
		_mole.pause = 1.0


## Story: true while the Mole still steals shovels (not ARRIVED or RESTORED).
func mole_steals() -> bool:
	return not u.story.in_town(Story.MOLE)


func _on_tile_dug(cell: Vector2i, _block: StringName, p: int) -> void:
	if mole == null or p < 0 or not mole_steals():
		return
	var pl := _player(p)
	if pl == null or pl.vehicle != null:
		return
	if not STEAL_LAYERS.has(_layer_id_at(cell.y * 16.0 + 8.0)):
		return
	_dug += 1
	var need := STEAL_FIRST if u.story.state(Story.MOLE).encounters == 0 else STEAL_EVERY
	if _dug >= need and _t >= _steal_ready:
		steal(pl)


## The Mole takes `pl`'s shovel (and gives it straight back). False when he cannot now (busy,
## rescuing, or he has arrived). Thefts never touch the player: digging and walking go on.
func steal(pl: HillPlayer) -> bool:
	if mole == null or pl == null or not mole_steals() or not _theft.is_empty() or is_rescuing():
		return false
	var feet := _local(pl)
	var side := -float(pl.facing) if pl.facing != 0 else -1.0
	var at := Vector2(feet.x + side * POP_SIDE, feet.y + 1.0)
	_theft = {"p": pl.player, "t": 0.0, "at": at, "side": side, "stage": 0, "last": false,
			"shovel": feet + Vector2(0, -14)}
	_dug = 0
	_mole.state = &"theft"
	_mole.wave = 0.0
	Audio.play("mole_dig")
	if mole.visible:
		u.burst(mole.position + Vector2(0, -6), DIRT, 8, 80.0)
	mole.visible = false
	return true


## Seconds into the current theft, or -1 (the beat runner logs the bubble from it).
func theft_time() -> float:
	return float(_theft.t) if not _theft.is_empty() else -1.0


func _hand(p: int, fallback: Vector2) -> Vector2:
	var pl := _player(p)
	return _local(pl) + Vector2(pl.facing * 6.0, -14.0) if pl != null else fallback


func _step_theft(delta: float) -> void:
	var th := _theft
	th.t += delta
	var t: float = th.t
	var at: Vector2 = th.at
	var paws := at + Vector2(-th.side * 4.0, -15.0)
	var hand := _hand(int(th.p), paws)
	if th.stage == 0 and t >= T_POP:
		th.stage = 1
		Audio.play("mole_dig")
		mole.position = at
		mole.visible = true
		mole.flip_h = th.side > 0.0
		u.burst(at + Vector2(0, -8), DIRT, 14, 110.0)
	if th.stage >= 1:
		var k := clampf((t - T_POP) / 0.25, 0.0, 1.0)
		mole.position.y = at.y + 14.0 * (1.0 - k)
	if th.stage == 1 and t >= T_GRAB:
		th.stage = 2
		th.from = hand
		Audio.play("mole_steal")
		if u.story.steal_shovel():
			th.last = not mole_steals()
		shovel_stolen.emit(int(th.p))
	if th.stage == 2:
		var k := clampf((t - T_GRAB) / (T_HOLD - T_GRAB), 0.0, 1.0)
		th.shovel = th.from.lerp(paws, k) + Vector2(0, -22.0 * sin(k * PI))
		if t >= T_HOLD:
			th.stage = 3
			Audio.play("mole_sorry")
	if th.stage == 3:
		th.shovel = paws + Vector2(0, sin(t * 14.0) * 1.0)
		if t >= T_BACK:
			th.stage = 4
			th.from = paws
	if th.stage == 4:
		var k := clampf((t - T_BACK) / (T_GIVEN - T_BACK), 0.0, 1.0)
		th.shovel = (th.from as Vector2).lerp(hand, k) + Vector2(0, -18.0 * sin(k * PI))
		if t >= T_GIVEN:
			th.stage = 5
			Audio.play("shovel_back")
			u.burst(hand + Vector2(0, -6), HEART, 10, 80.0)
	if th.stage == 5:
		mole.position.y = at.y - absf(sin((t - T_GIVEN) * 10.0)) * 3.0
		if th.last and t >= T_WAVE_UP and not th.get("waved", false):
			th.waved = true
			Audio.play("mole_wave")
			_waves.append({"pos": at + Vector2(th.side * -12.0, -22.0), "t": 0.0, "dir": -th.side})
		if t >= (T_DIVE_UP if th.last else T_DIVE):
			th.stage = 6
			Audio.play("mole_dig")
			u.burst(mole.position + Vector2(0, -6), DIRT, 12, 100.0)
			if th.last:
				# Up he goes: a little puff trail rising from where he dived.
				for k in 3:
					u.burst(at + Vector2(0, -20.0 - 18.0 * k), DIRT, 4, 50.0)
			mole.visible = false
	if th.stage == 6 and (th.last or t >= T_HOME):
		_end_theft(false)


## Ends a theft: `now` (a rescue needs him) gives the shovel back at once.
func _end_theft(now: bool) -> void:
	if _theft.is_empty():
		return
	if now and int(_theft.stage) >= 2 and int(_theft.stage) < 5:
		Audio.play("shovel_back")
		u.burst(_hand(int(_theft.p), _theft.at) + Vector2(0, -6), HEART, 8, 70.0)
	_theft = {}
	_steal_ready = _t + steal_cooldown
	_mole.state = &"wander"
	_mole.pause = 1.0
	mole.position = mole_home
	_mole.target = mole_home.x
	mole.visible = not u.story.in_town(Story.MOLE)
	if mole.visible and not now:
		Audio.play("mole_dig")
		u.burst(mole_home + Vector2(0, -6), DIRT, 8, 70.0)


# --- Mole: Lost & Found visits -------------------------------------------------------------------

func _tick_visits(ps: Array[HillPlayer], delta: float) -> void:
	if not _visit.is_empty():
		_step_visit(delta)
		return
	if ps.is_empty():
		return
	_visit_in -= delta
	if _visit_in <= 0.0:
		visit_now(ps[int(_t * 3.7) % ps.size()])


## Starts a Lost & Found visit beside `pl` (the nearest underground player when null). False when
## he is not restored, busy, or nobody is underground.
func visit_now(pl: HillPlayer = null) -> bool:
	if mole == null or not u.story.restored(Story.MOLE) or not _visit.is_empty() or not _theft.is_empty() or is_rescuing():
		return false
	if pl == null:
		var ps := u.hazards.players()
		if ps.is_empty():
			return false
		pl = ps[0]
	var feet := _local(pl)
	var side := -float(pl.facing) if pl.facing != 0 else -1.0
	var at := Vector2(feet.x + side * (POP_SIDE + 4.0), feet.y + 1.0)
	_visit = {"p": pl.player, "t": 0.0, "at": at, "side": side, "stage": 0, "glow": []}
	_mole.state = &"visit"
	mole.visible = false
	return true


func mole_visiting() -> bool:
	return not _visit.is_empty() and int(_visit.stage) < 2


## Unfound treasures glowing for the visit in progress (ids).
func glowing_treasures() -> Array:
	return (_visit.get("glow", []) as Array).duplicate() if mole_visiting() else []


func _glow_list(at: Vector2) -> Array:
	var out: Array = []
	var me := Vector2i(int(at.x / 16.0), int((at.y - 8.0) / 16.0))
	for s in u.generator.treasure_spots:
		if Progress.has_treasure(s.id) or out.has(s.id):
			continue
		var r: Rect2i = s.rect
		var dx := maxi(0, maxi(r.position.x - me.x, me.x - (r.end.x - 1)))
		var dy := maxi(0, maxi(r.position.y - me.y, me.y - (r.end.y - 1)))
		if maxi(dx, dy) <= VISIT_GLOW_TILES:
			out.append(s.id)
	return out


func _step_visit(delta: float) -> void:
	var v := _visit
	v.t += delta
	var t: float = v.t
	var at: Vector2 = v.at
	if v.stage == 0:
		v.stage = 1
		Audio.play("mole_dig")
		Audio.play("mole_hello")
		mole.position = at
		mole.visible = true
		mole.flip_h = v.side > 0.0
		u.burst(at + Vector2(0, -8), DIRT, 14, 110.0)
		_waves.append({"pos": at + Vector2(-v.side * 12.0, -22.0), "t": 0.0, "dir": -v.side})
		v.glow = _glow_list(at)
		if not (v.glow as Array).is_empty():
			Audio.play("treasure_hint")
	if v.stage == 1:
		mole.position.y = at.y + 14.0 * (1.0 - clampf(t / 0.25, 0.0, 1.0)) - absf(sin(t * 3.0)) * 1.5
		if fmod(t, 1.0) < delta:
			v.glow = _glow_list(at)
		if t >= VISIT_STAY:
			_end_visit()


## He leaves: drops a found thing (VISIT_GIFT blocks of this layer, into the shared pile) and dives.
func _end_visit() -> void:
	if _visit.is_empty():
		return
	var at: Vector2 = _visit.at
	var block := _layer_block(at.y - 8.0)
	Inventory.add(block, VISIT_GIFT)
	Audio.play("mole_gift")
	Audio.play("mole_dig")
	u.burst(at + Vector2(-_visit.side * 12.0, -10.0), GOLD, 14, 120.0)
	u.burst(at + Vector2(-_visit.side * 12.0, -10.0), u.block_color(block), 10, 90.0)
	u.burst(at + Vector2(0, -6), DIRT, 10, 90.0)
	_gift = {"pos": at + Vector2(-_visit.side * 12.0, -6.0), "t": 0.0, "block": block}
	mole_gift.emit(block, VISIT_GIFT)
	_visit = {}
	_visit_in = lerpf(VISIT_EVERY.x, VISIT_EVERY.y, fmod(_t * 0.618, 1.0))
	_mole.state = &"wander"
	mole.position = mole_home
	mole.visible = false


## The layer's main block at depth y (px): its biggest block_mix share.
func _layer_block(y: float) -> StringName:
	var i := u.layer_index_at(Vector2(0, y))
	var l: LayerData = u.layers()[clampi(i, 0, u.layers().size() - 1)]
	var best: StringName = &"dirt"
	var bw := -1.0
	for b in l.block_mix:
		if float(l.block_mix[b]) > bw and u.blocks.has(StringName(b)):
			bw = float(l.block_mix[b])
			best = StringName(b)
	return best


# --- Gnome crew --------------------------------------------------------------------------------

func crew_state() -> StringName:
	return _crew.state


func _on_treasure_found(id: StringName, _p: int) -> void:
	if id == &"gnome_room":
		free_crew()


## The Gnome Room is open: the wall crumbles and the crew comes out (Story.free_crew, once).
func free_crew() -> bool:
	if crew.is_empty() or _crew.state != &"walled":
		return false
	# They march out the way the player came in (towards the nearest player), else to the shaft.
	var dir := signf(_shaft_x() - _crew_home[0].x)
	var near := _nearest(u.hazards.players(), _wall.get_center())
	if near != null and absf(_local(near).x - _wall.get_center().x) > 4.0:
		dir = signf(_local(near).x - _wall.get_center().x)
	_crew = {"state": &"freeing", "t": 0.0, "armed": false, "hop": 0.0, "bubble": 0.0, "steps": -1, "dir": dir}
	u.story.free_crew()
	Audio.play("wall_crumble")
	Audio.play("whistle")
	_whistle = 0.6
	_whistle_at = _crew_home[1 if _crew_home.size() > 1 else 0] + Vector2(-8, -18)
	var c := _wall.get_center()
	u.burst(c, BRICK, 22, 150.0)
	u.burst(c, Color(0.85, 0.8, 0.7), 12, 110.0)
	for row in 3:
		for col in int(_wall.size.x / 8.0):
			var pos := _wall.position + Vector2(col * 8.0 + 4.0, row * WALL_H / 3.0 + 2.0)
			var away := signf(pos.x - c.x) if absf(pos.x - c.x) > 2.0 else 0.0
			_bricks.append({"pos": pos, "v": Vector2(away * (40.0 + fmod(col * 37.0, 50.0)), -60.0 - row * 30.0), "t": 0.0})
	crew_freed.emit()
	return true


func _tick_crew(ps: Array[HillPlayer], delta: float) -> void:
	if crew.is_empty():
		return
	_crew.t += delta
	var t: float = _crew.t
	match _crew.state:
		&"walled":
			# Hard hats bob over the bricks; a muffled whistle and a hop when someone comes near.
			_crew.hop = maxf(0.0, _crew.hop - delta)
			_crew.bubble = maxf(0.0, _crew.bubble - delta)
			for i in crew.size():
				var hop: float = sin(_crew.hop / 0.4 * PI) * 5.0 if _crew.hop > 0.0 else 0.0
				crew[i].position.y = _crew_home[i].y - 1.5 - sin(_t * 3.0 + i * 1.9) * 1.5 - hop
			var near := _nearest(ps, _wall.get_center())
			if near == null:
				return
			var d := _local(near).distance_to(_wall.get_center())
			if d > WAVE_REARM + 40.0:
				_crew.armed = true
			elif d < WHISTLE_NEAR and _crew.armed:
				_crew.armed = false
				_crew.hop = 0.4
				_crew.bubble = 2.4
				_whistle = 0.6
				_whistle_at = _crew_home[0] + Vector2(-8, -18)
				Audio.play("whistle_muffled")
		&"freeing":
			# Three happy hops (a whistle on each), then the march.
			for i in crew.size():
				crew[i].position.y = _crew_home[i].y - absf(sin((t + i * 0.12) * PI / 0.5)) * 8.0
			var hop := int(t / 0.5)
			if hop != int(_crew.get("hops", 0)) and hop < 3:
				_crew.hops = hop
				Audio.play("whistle")
				_whistle = 0.5
			if t >= CREW_MARCH_AT:
				_crew.state = &"marching"
				_crew.t = 0.0
				for i in crew.size():
					crew[i].position.y = _crew_home[i].y
		&"marching":
			# Sharp little steps towards the shaft, in a line, fading as they go: up top now.
			var dir: float = _crew.get("dir", 1.0)
			var step := int(t / CREW_STEP)
			var lift := 3.0 if fmod(t, CREW_STEP) < CREW_STEP * 0.4 else 0.0
			if step != int(_crew.get("steps", -1)):
				_crew.steps = step
				Audio.play("march_step")
			var a := 1.0 - clampf((t - CREW_FADE.x) / (CREW_FADE.y - CREW_FADE.x), 0.0, 1.0)
			for i in crew.size():
				var c := crew[i]
				c.flip_h = dir < 0.0
				c.position = _crew_home[i] + Vector2(dir * step * CREW_STEP_PX, -lift if (step + i) % 2 == 0 else 0.0)
				c.modulate.a = a
			if t >= CREW_FADE.y:
				_crew.state = &"gone"
				for c in crew:
					c.visible = false


# --- Caveman -----------------------------------------------------------------------------------

func _shaft_x() -> float:
	return HillGenerator.SHAFT_X * 16.0 + 16.0


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
			# The laugh: three bouncy hops, then he tags along.
			caveman.position.y = _caveman_home.y - absf(sin(t * PI / 0.45)) * 7.0
			if t >= 1.4:
				caveman.position.y = _caveman_home.y
				_cave.state = &"following"
				_cave.t = 0.0
				_cave.hoot = 0.0
		&"following":
			_cave.t += delta
			var near := _nearest(ps, caveman.position)
			# Off he goes when they are at the shaft, rode up (nobody left down here), or after a while.
			if near == null or _cave.t >= FOLLOW_MAX or absf(_local(near).x - _shaft_x()) < SHAFT_NEAR:
				_cave.state = &"leaving"
				Audio.play("caveman_hoot")
				_waves.append({"pos": caveman.position + Vector2(0, -30), "t": 0.0, "dir": -1.0 if caveman.flip_h else 1.0})
				return
			var to := _local(near)
			var side := signf(caveman.position.x - to.x)
			if side == 0.0:
				side = 1.0
			var goal_x := to.x + side * FOLLOW_GAP
			var dx := goal_x - caveman.position.x
			caveman.position.x += signf(dx) * minf(absf(dx), minf(FOLLOW_SPEED, absf(dx) * 6.0 + 20.0) * delta)
			caveman.flip_h = to.x < caveman.position.x
			var base_y := lerpf(caveman.get_meta(&"feet_y", to.y), to.y + 1.0, minf(1.0, delta * 8.0))
			caveman.set_meta(&"feet_y", base_y)
			caveman.position.y = base_y - absf(sin(_cave.t * 9.0)) * (3.0 if absf(dx) > 1.0 else 0.8)
			_cave.hoot -= delta
			if _cave.hoot <= 0.0:
				_cave.hoot = HOOT_EVERY
				Audio.play("caveman_hoot")
				var dir := -1.0 if caveman.flip_h else 1.0
				_waves.append({"pos": caveman.position + Vector2(dir * 10.0, -26.0), "t": 0.0, "dir": dir})
		&"leaving":
			# Into the shaft with a bow-legged bounce, then up he goes.
			_cave.t += delta
			var shaft_x := _shaft_x()
			var dir := signf(shaft_x - caveman.position.x)
			caveman.flip_h = dir < 0.0
			caveman.position.x += dir * minf(absf(shaft_x - caveman.position.x), 70.0 * delta)
			var base_y: float = caveman.get_meta(&"feet_y", caveman.position.y)
			caveman.position.y = base_y - absf(sin(_cave.t * 9.0)) * 2.0
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
	caveman.set_meta(&"feet_y", _caveman_home.y)
	UndergroundLook.set_anim(caveman, CAVEMAN_FILE, "idle")
	Audio.play("ice_crack")
	Audio.play("caveman_laugh")
	var c := _caveman_home + Vector2(0, -18)
	u.burst(c, ICE, 30, 170.0)
	u.burst(c, Color.WHITE, 12, 120.0)
	u.burst(c + Vector2(0, -10), HEART, 8, 70.0)
	caveman_thawed.emit()
	return true


## frozen, thawing (the laugh), following, leaving (into the shaft), gone (up top).
func caveman_state() -> StringName:
	return _cave.state


# --- Dragon ------------------------------------------------------------------------------------

func _tick_dragon(ps: Array[HillPlayer], delta: float) -> void:
	if dragon == null:
		return
	match _dragon.state:
		&"asleep":
			_tick_snore(ps, delta)
			var cav := HillGenerator.CAVERN
			var st := u.story
			if not st.dragon_met():
				for pl in ps:
					var at := _local(pl)
					if at.y > cav.position.y * 16.0 and absf(at.x - dragon.position.x) < REVEAL_NEAR:
						reveal()
						return
				return
			if st.phase(Story.DRAGON) != ResidentState.Phase.ENCOUNTERED:
				return
			# The second meeting: come close, or stay near a little while.
			_dragon_rest = maxf(0.0, _dragon_rest - delta)
			if _dragon_rest > 0.0:
				return
			var lingering := false
			for pl in ps:
				var at := _local(pl)
				if at.y <= cav.position.y * 16.0:
					continue
				var d := absf(at.x - dragon.position.x)
				if d < WAKE_NEAR:
					wake()
					return
				lingering = lingering or d < LINGER_NEAR
			_linger = _linger + delta if lingering else maxf(0.0, _linger - delta)
			if _linger >= LINGER_SECS:
				wake()
		&"waking":
			_tick_reveal(delta)
		&"waking_up":
			_tick_wake(delta)
		&"leaving":
			_tick_pieces(delta)


## W-17: while she sleeps, a slow snore every SNORE_EVERY seconds: a smoke puff from her nose and a
## gentle sway of the view for anyone in the cavern, fainter up through the Crystal layer, none
## above. Never during the first meeting (S6 keeps the reveal shake-free).
## TODO(audio): a periodic `dragon_snore` call waits for the cue in assets/audio/CUES.md
## (PLAN-STATUS W-17); `dragon_snored` is the hook for it.
func _tick_snore(ps: Array[HillPlayer], delta: float) -> void:
	_snore_t -= delta
	if _snore_t > 0.0:
		return
	_snore_t = SNORE_EVERY
	var top := HillGenerator.CAVERN.position.y * 16.0
	var loudest := 0.0
	for pl in ps:
		var at := _local(pl)
		var k := 0.0
		if at.y > top:
			k = 1.0
		elif at.y > top - SNORE_REACH:
			k = 0.35 * (1.0 - (top - at.y) / SNORE_REACH)
		if k > 0.0:
			ScreenKick.kick(pl.player, 0.6 + 1.4 * k, 0.8, true)
			loudest = maxf(loudest, k)
	if loudest > 0.0:
		snores += 1
		_rings.append({"pos": dragon.position + DRAGON_MOUTH * dragon.scale, "t": 0.0})
		dragon_snored.emit(loudest)


func _tick_reveal(delta: float) -> void:
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
		_dragon = {"state": &"asleep", "t": 0.0}
		_dragon_rest = WAKE_GRACE
		_linger = 0.0
		Audio.play("dragon_snore")


## The first meeting: once per save (Story.meet_dragon). False when it already happened.
func reveal() -> bool:
	if dragon == null or _dragon.state != &"asleep" or not u.story.meet_dragon():
		return false
	_dragon = {"state": &"waking", "t": 0.0, "rings": 0}
	Audio.play("dragon_yawn")
	dragon_revealed.emit()
	return true


## The second meeting: she wakes for good (Story.wake_dragon at the purr). False unless she was met
## once, is asleep in the cavern and has not come up yet.
func wake() -> bool:
	if dragon == null or _dragon.state != &"asleep" or u.story.phase(Story.DRAGON) != ResidentState.Phase.ENCOUNTERED:
		return false
	_dragon = {"state": &"waking_up", "t": 0.0, "stage": 0}
	Audio.play("dragon_stretch")
	return true


func _tick_wake(delta: float) -> void:
	_dragon.t += delta
	var t: float = _dragon.t
	# A long, happy stretch (front up, then settle), then she sits up while she "talks".
	var s := 0.0
	if t < WAKE_BUBBLE1:
		s = 0.09 * sin(t / WAKE_BUBBLE1 * PI)
	dragon.scale = _dragon_scale * Vector2(1.0 + s * 0.6, 1.0 + s)
	if _dragon.stage == 0 and t >= WAKE_BUBBLE1:
		_dragon.stage = 1
		Audio.play("dragon_mumble")
	elif _dragon.stage == 1 and t >= WAKE_BUBBLE2:
		_dragon.stage = 2
		Audio.play("dragon_hopeful")
	elif _dragon.stage == 2 and t >= WAKE_PURR:
		_dragon.stage = 3
		Audio.play("dragon_purr")
		u.burst(dragon.position + Vector2(-30, -60), HEART, 18, 90.0)
		u.story.wake_dragon()
		Events.dragon_woken.emit()
		dragon_woke.emit()
	elif _dragon.stage == 3 and t >= WAKE_LEAVE:
		_start_pieces()


## The bubble showing now in the second meeting (for the beat log), or [].
func dragon_bubble() -> Array:
	if _dragon.state != &"waking_up":
		return []
	match int(_dragon.stage):
		1: return [&"shaken_hill", &"face_sheepish"]
		2: return [&"ruin:ruined_keep", &"face_hopeful"]
	return []


## Up the shaft in three slices of her sprite (head, middle, tail), one after another.
func _start_pieces() -> void:
	dragon.scale = _dragon_scale
	_dragon = {"state": &"leaving", "t": 0.0}
	_pieces.clear()
	var tex := dragon.texture
	var fs := Vector2(SheetSprite.frame_size(DRAGON_FILE)) if tex != null else Vector2(160, 72)
	var w := fs.x / 3.0
	var tl := dragon.position + dragon.offset * dragon.scale
	for i in 3:
		var src := Rect2(dragon.frame_coords.x * fs.x + i * w, dragon.frame_coords.y * fs.y, w, fs.y)
		_pieces.append({"src": src, "pos": tl + Vector2(i * w, 0) * dragon.scale, "size": Vector2(w, fs.y) * dragon.scale,
				"t": -i * PIECE_GAP, "rise": false, "gone": false, "vy": 0.0})
	dragon.visible = false
	Audio.play("dragon_boing")


func _tick_pieces(delta: float) -> void:
	var left := 0
	var top := HillGenerator.CAVERN.position.y * 16.0 - 260.0
	for pc in _pieces:
		if pc.gone:
			continue
		left += 1
		pc.t += delta
		if pc.t < 0.0:
			continue
		var cx: float = pc.pos.x + pc.size.x * 0.5
		if not pc.rise:
			var dx := _shaft_x() - cx
			pc.pos.x += signf(dx) * minf(absf(dx), PIECE_SLIDE * delta)
			pc.hop = absf(sin(pc.t * 11.0)) * 6.0
			if absf(dx) < 1.0:
				pc.rise = true
				pc.hop = 0.0
				Audio.play("dragon_whoosh")
		else:
			pc.vy = minf(pc.vy + 900.0 * delta, 520.0)
			pc.pos.y -= pc.vy * delta
			if pc.pos.y + pc.size.y < top:
				pc.gone = true
	if left == 0:
		_dragon = {"state": &"gone", "t": 0.0}
		_pieces.clear()


## asleep, waking (the first meeting's yawn), waking_up (the second meeting), leaving (the pieces
## go up the shaft), gone (up top).
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
	if _whistle > 0.0:
		var a := _whistle / 0.6
		for k in 3:
			var d := Vector2(-1, -0.4 + k * 0.4).normalized()
			draw_line(_whistle_at + d * 3.0, _whistle_at + d * (7.0 + (1.0 - a) * 4.0), Color(1, 1, 1, a), 1.5)
	if _crew.state == &"walled" and _wall.size.x > 0.0:
		_draw_wall()
	for b in _bricks:
		var a := 1.0 - clampf((float(b.t) - 0.5) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(b.pos - Vector2(3.5, 2), Vector2(7, 4)), Color(OUTLINE, a))
		draw_rect(Rect2(b.pos - Vector2(3, 1.5), Vector2(6, 3)), Color(BRICK, a))
	if caveman != null and _cave.state == &"frozen" and warmth > 0.0:
		var k := warmth / THAW_SECS
		draw_circle(_caveman_home + Vector2(0, -18), 20.0 + 6.0 * sin(_t * 6.0), Color(WARM, 0.12 + 0.18 * k))


## A brick wall across the crew, only their hard hats over it.
func _draw_wall() -> void:
	var r := _wall
	draw_rect(r.grow(1.0), OUTLINE)
	var bw := 8.0
	var bh := r.size.y / 3.0
	for row in 3:
		var off := bw * 0.5 if row % 2 == 1 else 0.0
		var x := r.position.x - off
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + bw, r.end.x)
			var br := Rect2(x0, r.position.y + row * bh, x1 - x0 - 1.0, bh - 1.0)
			draw_rect(br, BRICK.darkened(0.08 * ((row + int(x / bw)) % 2)))
			x += bw
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.5), BRICK.lightened(0.3))


## Above the darkness: the stolen shovel, the picture bubbles, the treasure glow, the gift and the
## Dragon's pieces, so they always read.
func _draw_over() -> void:
	if not _theft.is_empty():
		var th := _theft
		var st: int = th.stage
		if st >= 2 and st <= 4:
			PictoBubble.picture(_over, &"shovel", th.shovel, 16.0)
		var t: float = th.t
		if t >= T_HOLD - 0.1 and t < T_DIVE:
			var a := clampf((t - T_HOLD + 0.1) / 0.2, 0.0, 1.0) * clampf((T_DIVE - t) / 0.25, 0.0, 1.0)
			var pop := 0.7 + 0.3 * clampf((t - T_HOLD + 0.1) / 0.15, 0.0, 1.0)
			PictoBubble.draw(_over, mole.position + Vector2(0, -30), [&"shovel", &"face_sheepish"], a, pop)
	if mole_visiting():
		var t: float = _visit.t
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		for s in u.generator.treasure_spots:
			if not (_visit.glow as Array).has(s.id):
				continue
			var r := Rect2(Vector2((s.rect as Rect2i).position) * 16.0, Vector2((s.rect as Rect2i).size) * 16.0)
			_over.draw_rect(r.grow(3.0 + pulse * 2.0), Color(GOLD, 0.10 + 0.08 * pulse))
			_over.draw_rect(r, Color(GOLD, 0.16 + 0.14 * pulse))
			_over.draw_rect(r.grow(2.0), Color(1.0, 0.95, 0.6, 0.35 + 0.3 * pulse), false, 1.5)
			for k in 3:
				var sp := r.position + Vector2(fmod(k * 0.37 + _t * 0.2, 1.0) * r.size.x, fmod(k * 0.61 + _t * 0.13, 1.0) * r.size.y)
				PictoBubble.picture(_over, &"star", sp, 6.0 + 2.0 * pulse, 0.8)
		# The bundle he carries: a little sack with a gold tie.
		var b := mole.position + Vector2(-float(_visit.side) * 12.0, -9.0 - absf(sin(t * 3.0)) * 1.5)
		_draw_bundle(_over, b, 1.0)
		if t > 0.4 and t < 2.4:
			var a := clampf((t - 0.4) / 0.2, 0.0, 1.0) * clampf((2.4 - t) / 0.3, 0.0, 1.0)
			PictoBubble.draw(_over, mole.position + Vector2(0, -30), [&"star", &"face_happy"], a)
	if not _gift.is_empty():
		var k: float = _gift.t / 0.9
		var p: Vector2 = _gift.pos + Vector2(0, -26.0 * sin(k * PI))
		_draw_bundle(_over, p, 1.0 - k * k)
		var bc := u.block_color(_gift.block)
		for i in VISIT_GIFT:
			var q := p + Vector2((i - 1) * 9.0, -10.0 - 10.0 * k)
			_over.draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color(OUTLINE, 1.0 - k))
			_over.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(bc, 1.0 - k))
	if crew.size() > 1 and _crew.state == &"walled" and _crew.bubble > 0.0:
		var a := clampf(_crew.bubble / 0.3, 0.0, 1.0) * clampf((2.4 - _crew.bubble) / 0.2, 0.0, 1.0)
		PictoBubble.draw(_over, crew[1].position + Vector2(0, -30), [&"wall", &"face_hopeful"], a)
	if crew.size() > 1 and _crew.state == &"freeing" and _crew.t > 0.3:
		var a := clampf((_crew.t - 0.3) / 0.2, 0.0, 1.0)
		PictoBubble.draw(_over, crew[1].position + Vector2(0, -24), [&"heart", &"face_happy"], a)
	if _dragon.state == &"waking_up":
		var pics := dragon_bubble()
		if not pics.is_empty():
			var t: float = _dragon.t
			var t0 := WAKE_BUBBLE1 if int(_dragon.stage) == 1 else WAKE_BUBBLE2
			var a := clampf((t - t0) / 0.2, 0.0, 1.0) * clampf((t0 + 2.0 - t) / 0.2, 0.0, 1.0)
			PictoBubble.draw(_over, dragon.position + DRAGON_HEAD * dragon.scale, pics, a, 1.3)
	if not _pieces.is_empty() and dragon != null and dragon.texture != null:
		for i in range(_pieces.size() - 1, -1, -1):
			var pc: Dictionary = _pieces[i]
			if pc.gone:
				continue
			var at: Vector2 = pc.pos - Vector2(0, float(pc.get("hop", 0.0)))
			_over.draw_texture_rect_region(dragon.texture, Rect2(at, pc.size), pc.src)


static func _draw_bundle(ci: CanvasItem, c: Vector2, a: float) -> void:
	if a <= 0.01:
		return
	ci.draw_circle(c, 6.5, Color(OUTLINE, a))
	ci.draw_circle(c, 5.5, Color(Color("c89a5a"), a))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(3, -5), c + Vector2(0, -9)]), Color(Color("c89a5a"), a))
	ci.draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 2)), Color(GOLD, a))
