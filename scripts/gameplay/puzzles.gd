## C-22: the underground engineering puzzles HillGenerator placed from data/puzzles.
## - Boulder wall: a cracked slab of the row's `block` (Hard Rock: on foot it bonks with a vehicle
##   picture, a vehicle digs it). A boulder rests WALL_GAP rows above it; dig the ground under the
##   boulder and it drops. The rule is the block's (BlockData.boulder_breaks, boulder_min_px,
##   boulder_min_speed): a big enough body landing fast enough breaks the whole slab open: cracks,
##   dust, a crash, a camera kick and pad rumble near it, a "rock + star" picture bubble, a camera
##   peek for anyone it is off screen for, and the boulder drops on into the little chamber under it
##   (a stone floor). A pebble only clinks. Before: the slab is drawn as cracked bricks with glints,
##   and a "rock + wall" picture bubble floats over it while a player is near.
##   The same rule breaks loose Hard Rock patches a boulder lands on (break_cells).
## - Vehicle block: a heavy block only one vehicle moves (the row's `vehicle`, the Front Loader).
##   Its digs go through the normal vehicle dig (HillPlayer.dig_now -> TileWorld.dig), which reports
##   the unbreakable cell as dig_blocked; Underground hands that here. The right vehicle's dig wobbles
##   it (a thunk, dust); `hits` digs and it pops away, `gives` into that vehicle's backpack. Anyone
##   else (on foot, another vehicle, the Mole) only clunks off it. While a player who is not in that
##   vehicle stands within HINT_REACH, a picture bubble over the block shows the vehicle that does it.
## The state lives in the tiles (edit-only saves): a cleared block or broken slab stays open.
class_name Puzzles
extends Node2D

signal wall_broke(index: int)
signal block_hit(index: int, player: int, left: int)
signal block_cleared(index: int, player: int)
signal broke_cells(cells: Array[Vector2i])

## A player this close (px, slab centre to feet) to a standing wall sees the "rock + wall" bubble.
const WALL_HINT_REACH := 10.0 * 16.0
## A break further than this from a player (px, each axis) is off their screen: camera peek.
## At the 2.0 zoom a full screen is 60 x 34 tiles.
const OFFSCREEN := Vector2(26.0 * 16.0, 14.0 * 16.0)
const PEEK_SECS := 1.6
const BUBBLE_SECS := 1.8

## A player this close (px, block centre to feet) to a vehicle block sees the vehicle bubble.
const HINT_REACH := 5.5 * 16.0
## Everyone underground this close to a breaking wall gets the camera kick.
const KICK_REACH := 20.0 * 16.0
const DUST := Color(0.72, 0.6, 0.46)
const GOLD := Color("ffd23f")
const OUTLINE := Color("3a2a44")
## Cues (Needs the Audio lane); each falls back to a cue that already exists until it lands.
const WALL_CUE := "wall_crash"
const WALL_FALLBACK := "cave_in"
const THUNK_CUE := "heavy_thunk"
const THUNK_FALLBACK := "fall"
const CLEAR_CUE := "heavy_clear"
const CLEAR_FALLBACK := "bundle_pop"

var u: Underground
## Per vehicle block index: hits taken so far.
var _hits := {}
## Per vehicle block index: the physics frame of its last hit (one dig = one hit, however many of
## its cells the dig shape touched).
var _hit_frame := {}
## Per vehicle block index: seconds of wobble left.
var _wobble := {}
## Dust puffs being drawn: [{at: Vector2, t: float, big: bool}].
var _puffs: Array = []
## Per vehicle block index: 0..1 how shown its bubble is.
var _bubble := {}
var art: Node2D
## Per wall index: 0..1 how shown its "rock + wall" bubble is.
var _wall_bubble := {}
## Crack flashes being drawn: [{at: Vector2 (cell centre), t: float, seed: int}].
var _cracks: Array = []
## Camera peeks asked for (tests, beat log): [{player, offset}].
var peeks: Array = []


func setup(p_u: Underground) -> void:
	u = p_u
	name = "Puzzles"
	u.world.body_landed.connect(_on_body_landed)
	_spawn_boulders()
	art = _Art.new()
	art.name = "PuzzleArt"
	art.set("puzzles", self)
	u.world.add_child(art)


## Each wall's boulder: a boulder like every other (bonks, the Crane can haul it), appended to
## u.boulders after the generator's ones (so their indices and saved hauls never move); the wall
## row gets "boulder" = its index there.
func _spawn_boulders() -> void:
	for w: Dictionary in walls():
		var r: Rect2i = w.boulder_rect
		var b := FallingBody.new()
		b.name = "Boulder%d" % u.boulders.size()
		b.round = true
		b.size_px = Vector2.ONE * Underground.BOULDER_SIZE
		b.color = Color(0.62, 0.58, 0.54)
		b.collision_mask = 1 | 2
		b.position = Vector2((r.position.x + r.size.x * 0.5) * 16.0, r.end.y * 16.0 - Underground.BOULDER_SIZE * 0.5)
		w["boulder"] = u.boulders.size()
		u.world.add_child(b)
		u.boulders.append(b)


# --- queries -----------------------------------------------------------------------------------

func walls() -> Array:
	return u.generator.walls if u != null else []


func blocks() -> Array:
	return u.generator.vehicle_blocks if u != null else []


## True while any cell of wall i's slab is still standing.
func wall_standing(i: int) -> bool:
	for c in _cells((walls()[i].slab) as Rect2i):
		if u.world.is_solid(c):
			return true
	return false


## True while any cell of vehicle block i is still there.
func block_standing(i: int) -> bool:
	for c in _cells((blocks()[i].rect) as Rect2i):
		if u.world.is_solid(c):
			return true
	return false


func hits_of(i: int) -> int:
	return int(_hits.get(i, 0))


## The vehicle id the hint shows to player node `pl` right now (a block near them they cannot
## move as they are), or &"".
func vehicle_hint(pl: HillPlayer) -> StringName:
	var i := _near_block(pl)
	if i < 0:
		return &""
	var want: StringName = blocks()[i].vehicle
	if pl.vehicle != null and pl.vehicle.id == want:
		return &""
	return want


func bubble_of(i: int) -> float:
	return float(_bubble.get(i, 0.0))


func _near_block(pl: HillPlayer) -> int:
	if u == null or pl.world == null:
		return -1
	var feet := u.world.to_local(pl.global_position) + Vector2(0, -8)
	for i in blocks().size():
		if not block_standing(i):
			continue
		var r: Rect2i = blocks()[i].rect
		var c := (Vector2(r.position) + Vector2(r.size) * 0.5) * 16.0
		if feet.distance_to(c) <= HINT_REACH:
			return i
	return -1


# --- frame -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if u == null:
		return
	var want := {}
	for pl in u.hazards.players() if u.hazards != null else []:
		var i := _near_block(pl)
		if i >= 0 and vehicle_hint(pl) != &"":
			want[i] = true
	for i in blocks().size():
		var to := 1.0 if want.has(i) else 0.0
		_bubble[i] = move_toward(float(_bubble.get(i, 0.0)), to, delta * 5.0)
	for i in walls().size():
		var near := false
		if wall_standing(i):
			var slab: Rect2i = walls()[i].slab
			var c := (Vector2(slab.position) + Vector2(slab.size) * 0.5) * 16.0
			for pl in u.hazards.players() if u.hazards != null else []:
				if u.world.to_local(pl.global_position).distance_to(c) <= WALL_HINT_REACH:
					near = true
		_wall_bubble[i] = move_toward(wall_bubble_of(i), 1.0 if near else 0.0, delta * 4.0)
	for k in range(_cracks.size() - 1, -1, -1):
		_cracks[k].t += delta
		if float(_cracks[k].t) > 0.5:
			_cracks.remove_at(k)
	for i in _wobble.keys():
		_wobble[i] = maxf(0.0, float(_wobble[i]) - delta)
	for k in range(_puffs.size() - 1, -1, -1):
		_puffs[k].t += delta
		if float(_puffs[k].t) > 0.8:
			_puffs.remove_at(k)


func wobble_of(i: int) -> float:
	return float(_wobble.get(i, 0.0))


func puffs() -> Array:
	return _puffs


# --- boulders break walls (BlockData.boulder_breaks) -------------------------------------------

## Any falling body landing on a block whose BlockData.boulder_breaks is on: big and fast enough
## (boulder_min_px, boulder_min_speed) cracks it away; a boulder-wall slab breaks whole, any other
## such block (Hard Rock patches) breaks under the body and boulder_reach cells along the row. The
## body then carries on down. Too small or slow (a pebble): a clink, nothing breaks.
func _on_body_landed(b: Node2D, speed: float) -> void:
	var fb := b as FallingBody
	if fb == null or u == null:
		return
	var hit := breakable_under(fb)
	if hit.is_empty():
		return
	var cell: Vector2i = hit[0]
	var def := _def(cell)
	if fb.size_px.x < def.boulder_min_px or speed < def.boulder_min_speed:
		Audio.play("dig_blocked")
		return
	var i := u.generator.wall_at(cell)
	if i >= 0:
		break_wall(i)
	else:
		break_cells(_run(hit, def))


## The cells right under body `fb`'s bottom whose block a boulder breaks (left to right).
func breakable_under(fb: FallingBody) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at := u.world.to_local(fb.global_position)
	var half := fb.size_px * 0.5
	for dx in [-half.x * 0.5, 0.0, half.x * 0.5]:
		var c := u.world.shape.cell_at(at + Vector2(dx, half.y + 3.0))
		if out.has(c) or not u.world.is_solid(c):
			continue
		var def := _def(c)
		if def != null and def.boulder_breaks:
			out.append(c)
	return out


## The wall whose standing slab is right under body `fb`'s bottom, or -1.
func wall_under(fb: FallingBody) -> int:
	for c in breakable_under(fb):
		var i := u.generator.wall_at(c)
		if i >= 0:
			return i
	return -1


func _def(cell: Vector2i) -> BlockData:
	return u.world.tile_def(u.world.get_tile(cell)) as BlockData


## `hit` plus the same block up to def.boulder_reach cells further along the row each way.
func _run(hit: Array[Vector2i], def: BlockData) -> Array[Vector2i]:
	var out: Array[Vector2i] = hit.duplicate()
	var tile := u.world.get_tile(hit[0])
	for c in hit:
		for dir in [-1, 1]:
			for k in range(1, def.boulder_reach + 1):
				var n := c + Vector2i(dir * k, 0)
				if out.has(n) or u.world.get_tile(n) != tile or u.generator.wall_at(n) >= 0:
					break
				out.append(n)
	return out


## Breaks wall i's slab open (the cause shows: cracks, dust, a crash, a rumble, a picture bubble,
## a camera peek for anyone far away). False if already open.
func break_wall(i: int) -> bool:
	if i < 0 or i >= walls().size() or not wall_standing(i):
		return false
	var cells: Array[Vector2i] = []
	for c in _cells(walls()[i].slab as Rect2i):
		if u.world.is_solid(c):
			cells.append(c)
	_wall_bubble[i] = 0.0
	break_cells(cells, true)
	wall_broke.emit(i)
	return true


## Cracks `cells` away with the full show; `big` for a whole wall.
func break_cells(cells: Array[Vector2i], big := false) -> void:
	if cells.is_empty():
		return
	var lo := Vector2(cells[0])
	var hi := Vector2(cells[0])
	for c in cells:
		lo = lo.min(Vector2(c))
		hi = hi.max(Vector2(c))
		_cracks.append({"at": Vector2(c) * 16.0 + Vector2(8, 8), "t": 0.0, "seed": c.x * 7 + c.y})
		u.world.set_tile(c, 0)
		u.burst(Vector2(c) * 16.0 + Vector2(8, 8), DUST, 6 if big else 8, 150.0)
	var mid := (lo + hi) * 0.5 * 16.0 + Vector2(8, 8)
	_cue(WALL_CUE, WALL_FALLBACK)
	_puffs.append({"at": mid, "t": 0.0, "big": true})
	u.burst(mid + Vector2(0, 16), GOLD, 12 if big else 6, 110.0)
	_kick_near(mid, 5.0 if big else 3.0, 0.45)
	_rumble_near(mid, 0.6 if big else 0.4, 0.35)
	_pop_bubble(mid)
	_peek_far(mid)
	broke_cells.emit(cells)


## The "rock broke it" picture over the break, held a moment (then frees itself).
func _pop_bubble(mid: Vector2) -> void:
	var spot := Node2D.new()
	spot.name = "BreakSpot"
	spot.position = mid
	u.world.add_child(spot)
	PictoBubbleNode.pop(u.world, spot, [&"rock", &"star"], BUBBLE_SECS, Vector2(0, -20))
	get_tree().create_timer(BUBBLE_SECS + 0.5).timeout.connect(spot.queue_free)


## Pad rumble for everyone underground near the break (the felt half of the crash).
func _rumble_near(at: Vector2, strength: float, secs: float) -> void:
	if u.hazards == null:
		return
	for pl in u.hazards.players():
		if u.world.to_local(pl.global_position).distance_to(at) <= KICK_REACH:
			var dev := Players.device_of(pl.player)
			if dev >= 0:
				Input.start_joy_vibration(dev, strength * 0.5, strength, secs)


## A camera beat for any player underground who could not see the break (off their screen): their
## view slides over to it and back (CameraLead.peek), so nothing changes without a visible cause.
func _peek_far(at: Vector2) -> void:
	if u.hazards == null:
		return
	var cam := get_tree().get_first_node_in_group(CameraLead.GROUP) as CameraLead
	for pl in u.hazards.players():
		var off := at - u.world.to_local(pl.global_position)
		if absf(off.x) > OFFSCREEN.x or absf(off.y) > OFFSCREEN.y:
			peeks.append({"player": pl.player, "offset": off})
			if cam != null:
				cam.peek(pl.player, off, PEEK_SECS)


func cracks() -> Array:
	return _cracks


func wall_bubble_of(i: int) -> float:
	return float(_wall_bubble.get(i, 0.0))


func _kick_near(at: Vector2, px: float, secs: float) -> void:
	if u.hazards == null:
		return
	for pl in u.hazards.players():
		if u.world.to_local(pl.global_position).distance_to(at) <= KICK_REACH:
			ScreenKick.kick(pl.player, px, secs)


# --- vehicle block -----------------------------------------------------------------------------

## Underground passes every dig_blocked here first. True when this was a vehicle block hit by the
## vehicle that moves it (the clunk is not played then: the block wobbles or pops instead).
func on_dig_blocked(cell: Vector2i, player: int) -> bool:
	if u == null:
		return false
	var i := u.generator.vehicle_block_at(cell)
	if i < 0:
		return false
	var row: Dictionary = blocks()[i]
	var pl := _player(player)
	if pl == null or pl.vehicle == null or pl.vehicle.id != row.vehicle:
		_bubble[i] = maxf(bubble_of(i), 0.6)
		return false
	var frame := Engine.get_physics_frames()
	if int(_hit_frame.get(i, -1)) == frame:
		return true
	_hit_frame[i] = frame
	_hits[i] = hits_of(i) + 1
	var left := int(row.hits) - hits_of(i)
	block_hit.emit(i, player, maxi(left, 0))
	var r: Rect2i = row.rect
	var mid := (Vector2(r.position) + Vector2(r.size) * 0.5) * 16.0
	if left > 0:
		_wobble[i] = 0.35
		_cue(THUNK_CUE, THUNK_FALLBACK)
		u.burst(mid + Vector2(0, r.size.y * 8.0), DUST, 10, 90.0)
		_puffs.append({"at": mid + Vector2(0, r.size.y * 6.0), "t": 0.0, "big": false})
		ScreenKick.kick(player, 2.0, 0.2)
		return true
	clear_block(i, pl)
	return true


## Clears vehicle block i (its cells go to air) and puts its `gives` into `by`'s backpack.
func clear_block(i: int, by: HillPlayer = null) -> bool:
	if i < 0 or i >= blocks().size() or not block_standing(i):
		return false
	var row: Dictionary = blocks()[i]
	var r: Rect2i = row.rect
	for c in _cells(r):
		if u.world.is_solid(c):
			u.world.set_tile(c, 0)
	if by != null and row.gives != &"":
		for k in int(row.gives_count):
			by.keep_block(row.gives)
	var mid := (Vector2(r.position) + Vector2(r.size) * 0.5) * 16.0
	_cue(CLEAR_CUE, CLEAR_FALLBACK)
	_puffs.append({"at": mid, "t": 0.0, "big": true})
	u.burst(mid, DUST, 22, 140.0)
	u.burst(mid, GOLD, 14, 120.0)
	if by != null:
		by.bump()
		ScreenKick.kick(by.player, 3.0, 0.3)
	_bubble[i] = 0.0
	block_cleared.emit(i, by.player if by != null else -1)
	return true


func _player(p: int) -> HillPlayer:
	if p < 0 or u.hazards == null:
		return null
	for pl in u.hazards.players():
		if pl.player == p:
			return pl
	return null


func _cue(cue: String, fallback: String) -> void:
	Audio.play(cue if Audio.has_cue(cue) else fallback)


static func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


# --- placeholder art: the cracked slab, the heavy block, its bubble, dust puffs -----------------

class _Art extends Node2D:
	var puzzles: Puzzles
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(puzzles) or puzzles.u == null:
			return
		var w := puzzles.u.world
		for wall in puzzles.walls():
			_slab(w, wall)
		for i in puzzles.blocks().size():
			_block(w, i)
		for p in puzzles.puffs():
			_puff(p)
		for c in puzzles.cracks():
			_crack(c)
		for i in puzzles.walls().size():
			var k := puzzles.wall_bubble_of(i)
			if k > 0.01:
				var room: Rect2i = puzzles.walls()[i].room
				var tip := Vector2(room.position.x + room.size.x * 0.2, room.position.y) * 16.0 + Vector2(0, 10 - sin(_t * 3.0) * 2.0)
				PictoBubble.draw(self, tip, [&"rock", &"wall"], k, 0.5 + 0.5 * ease(k, -2.0))
		for i in puzzles.blocks().size():
			var k := puzzles.bubble_of(i)
			if k > 0.01:
				var r: Rect2i = puzzles.blocks()[i].rect
				var tip := Vector2(r.position.x + r.size.x * 0.5, r.position.y) * 16.0 + Vector2(0, -4 - sin(_t * 4.0) * 2.0)
				var s := 0.6 + 0.6 * ease(k, -2.0)
				PictoBubble.draw(self, tip, [StringName("vehicle:%s" % puzzles.blocks()[i].vehicle)], k, s)

	## Cracked bricks: lighter than the ground round them, dark zigzag cracks, a glint peeking up.
	func _slab(w: TileWorld, wall: Dictionary) -> void:
		var slab: Rect2i = wall.slab
		for c in Puzzles._cells(slab):
			if not w.is_solid(c):
				continue
			var r := Rect2(Vector2(c) * 16.0, Vector2(16, 16))
			draw_rect(r, Color("b89a78"))
			draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(16, 1.5)), Color("7d6248"))
			var off := 4.0 if c.x % 2 == 0 else 11.0
			draw_rect(Rect2(r.position + Vector2(off, 0), Vector2(1.5, 7)), Color("7d6248"))
			draw_rect(Rect2(r.position + Vector2(fmod(off + 7.0, 16.0), 8.5), Vector2(1.5, 7.5)), Color("7d6248"))
			# The crack: a zigzag across the cell, heavier in the middle of the slab.
			var a := r.position + Vector2(0, 4 + (c.x % 3) * 3)
			var pts := PackedVector2Array([a, a + Vector2(5, 5), a + Vector2(9, 1), a + Vector2(13, 7), a + Vector2(16, 3)])
			draw_polyline(pts, OUTLINE, 2.0)
		# The slab's rim, so it reads as one wall.
		var all := Rect2(Vector2(slab.position) * 16.0, Vector2(slab.size) * 16.0)
		if puzzles.wall_standing(puzzles.walls().find(wall)):
			draw_rect(all, OUTLINE, false, 2.0)
			var g := 0.5 + 0.5 * sin(_t * 3.0)
			Hazards.draw_star(self, all.position + Vector2(all.size.x * 0.3, all.size.y - 2.0), 2.5, Color(GOLD, g))
			Hazards.draw_star(self, all.position + Vector2(all.size.x * 0.72, all.size.y - 3.0), 2.0, Color(GOLD, 1.0 - g))

	## A big round heavy rock with yellow-and-dark hazard stripes and bolts: "too big for hands".
	func _block(w: TileWorld, i: int) -> void:
		if not puzzles.block_standing(i):
			return
		var r: Rect2i = puzzles.blocks()[i].rect
		var wob := puzzles.wobble_of(i)
		var shake := Vector2(sin(_t * 60.0) * 2.5 * wob / 0.35, 0)
		var box := Rect2(Vector2(r.position) * 16.0 + shake, Vector2(r.size) * 16.0)
		draw_rect(box, OUTLINE)
		var inner := box.grow(-2)
		draw_rect(inner, Color("6f6a72"))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 4)), Color("8d8892"))
		# Stripes across the middle.
		var band := Rect2(inner.position + Vector2(0, inner.size.y * 0.38), Vector2(inner.size.x, inner.size.y * 0.24))
		draw_rect(band, Color("ffc94a"))
		var n := int(band.size.x / 6.0)
		for k in n:
			if k % 2 == 0:
				var x := band.position.x + k * 6.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, band.end.y), Vector2(x + 4, band.position.y),
						Vector2(minf(x + 8, band.end.x), band.position.y), Vector2(minf(x + 4, band.end.x), band.end.y)]), OUTLINE)
		for corner in [inner.position + Vector2(4, 4), Vector2(inner.end.x - 4, inner.position.y + 4),
				Vector2(inner.position.x + 4, inner.end.y - 4), inner.end - Vector2(4, 4)]:
			draw_circle(corner, 2.0, Color("c9c4cc"))
			draw_arc(corner, 2.0, 0.0, TAU, 8, OUTLINE, 1.0)
		# Cracks per hit taken.
		for h in puzzles.hits_of(i):
			var a := inner.position + Vector2(inner.size.x * (0.3 + 0.4 * h), 2)
			draw_polyline(PackedVector2Array([a, a + Vector2(3, 6), a + Vector2(-2, 10), a + Vector2(2, 14)]), OUTLINE, 2.0)

	## A crack flash: dark jagged lines bursting out of the cell, a white core, fading in 0.5 s.
	func _crack(c: Dictionary) -> void:
		var k := float(c.t) / 0.5
		var a := 1.0 - k
		var at: Vector2 = c.at
		draw_circle(at, 6.0 * (1.0 - k), Color(1, 1, 1, a * 0.8))
		for j in 5:
			var ang := (j + 0.3 * (int(c.seed) % 3)) * TAU / 5.0
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			var len := 6.0 + 10.0 * k
			draw_polyline(PackedVector2Array([at, at + d * len * 0.5 + n * 2.0, at + d * len]), Color(OUTLINE, a), 2.0)

	func _puff(p: Dictionary) -> void:
		var k := float(p.t) / 0.8
		var big := bool(p.big)
		var rad := (10.0 + k * (34.0 if big else 16.0))
		var a := 0.75 * (1.0 - k)
		for j in 6:
			var ang := j * TAU / 6.0 + float(p.t)
			var at: Vector2 = p.at + Vector2(cos(ang), sin(ang) * 0.6) * rad
			draw_circle(at, (9.0 if big else 5.0) * (1.0 - k * 0.5), Color(DUST, a))
		draw_circle(p.at, rad * 0.6, Color(DUST.lightened(0.2), a * 0.6))
