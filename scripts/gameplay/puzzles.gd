## C-22 underground engineering puzzles (HillGenerator.puzzles, from data/puzzles). Three kinds, each
## solved with the stick and A, none can be lost or undone, and every one ends in a gift of blocks
## that pops with a sparkle and a chime (into the solver's bag, the rest onto the pile):
##   drain        A on the dirt wall beside the nook digs the channel (the pocket floods the nook and
##                floats you, as water does); A on the drain plug opens it (pop, splash) and the water
##                runs down the chute into the sump. Solved when the pocket is dry.
##   boulder_wall A on the wooden strut knocks it out (planks clatter): the boulder drops onto the
##                cracked wall, which breaks into pieces (crumble, rubble falls into the room).
##                Solved when the cracked wall is gone. A shovel just bounces off the cracked wall.
##   heavy_block  On foot (or in any other vehicle) A bounces off it and a little picture of the
##                Loader pops over it. Driving a `lifted_by` vehicle, A lifts it out (bucket sound,
##                it rises and fades, heavy stone's worth of stone goes in the bag).
## Hints are pictures only: a slow glow on the gift; while a player is near and it is unsolved, a
## gold pulse round the tiles to dig and (where there is room) a bobbing arrow pointing at them. Solved state is read from the world (tiles and water are
## saved), so a reloaded game knows without a save key; after_load() syncs it without a gift.
class_name Puzzles
extends Node2D

signal solved(index: int, player: int)
## A heavy block bounced a hand or a vehicle that cannot lift it.
signal too_heavy(index: int, player: int)

const BOULDER_SIZE := 26.0
const HINT_REACH := 12 * 16.0
const POLL := 0.2
## Stone a lifted heavy block gives (into the driver's bag).
const HEAVY_BLOCKS := 3
const PICTURE_TIME := 2.0
const GOLD := Color("f2c94c")
const GLOW := Color("fff2a8")

var u: Underground
var g: HillGenerator
var world: TileWorld
## Per puzzle (index into g.puzzles): solved yet.
var done: Array[bool] = []
## boulder_wall puzzles: index -> FallingBody.
var boulders: Dictionary = {}
var _poll := 0.0
var _t := 0.0
var _picture: Dictionary = {}       # index -> seconds left of the "needs the Loader" picture
var _lights: Array[Node2D] = []


func setup(p_u: Underground) -> void:
	u = p_u
	g = u.generator
	world = u.world
	name = "Puzzles"
	z_index = 3
	done.clear()
	for i in g.puzzles.size():
		done.append(false)
		var pz: Dictionary = g.puzzles[i]
		if pz.kind == &"boulder_wall":
			_spawn_boulder(i, pz)
		var glow := Node2D.new()
		glow.name = "Glow%d" % i
		glow.position = _cell_center(pz.gift)
		add_child(glow)
		world.add_light(glow, 40.0, 0.6)
		_lights.append(glow)
	world.body_landed.connect(_on_body_landed)
	sync_solved()


## Bodies come before the first chunk load, so the boulder starts asleep on its strut.
func _spawn_boulder(i: int, pz: Dictionary) -> void:
	var r: Rect2i = pz.cavity
	var b := FallingBody.new()
	b.name = "PuzzleBoulder%d" % i
	b.round = true
	b.size_px = Vector2.ONE * BOULDER_SIZE
	b.color = Color(0.62, 0.58, 0.54)
	b.collision_mask = 1 | 2
	b.position = Vector2((r.position.x + r.size.x * 0.5) * 16.0, r.end.y * 16.0 - BOULDER_SIZE * 0.5)
	b.set_meta(&"puzzle", i)
	world.add_child(b)
	boulders[i] = b


func count() -> int:
	return g.puzzles.size()


func index_of(id: StringName) -> int:
	for i in g.puzzles.size():
		if g.puzzles[i].id == id:
			return i
	return -1


func is_solved(i: int) -> bool:
	return i >= 0 and i < done.size() and done[i]


## Reads every puzzle's state from the world; no gift (a reload, a test).
func sync_solved() -> void:
	for i in g.puzzles.size():
		done[i] = _world_solved(i)
	queue_redraw()


func after_load() -> void:
	sync_solved()


func _world_solved(i: int) -> bool:
	var pz: Dictionary = g.puzzles[i]
	match pz.kind:
		&"drain":
			for c in _cells(pz.pocket):
				if world.has_water(c):
					return false
			return true
		&"boulder_wall":
			return not _any_solid(pz.crack)
		&"heavy_block":
			return not _any_solid(pz.block)
	return false


# --- A on a puzzle tile -----------------------------------------------------------------------

## Underground asks first when a dig bounces: true = a puzzle used it (no bounce sound or puff).
func on_dig_blocked(cell: Vector2i, block: StringName, player: int) -> bool:
	var i := g.puzzle_at(cell)
	if i < 0:
		return false
	var pz: Dictionary = g.puzzles[i]
	match block:
		&"drain_plug":
			_clear(pz.plug)
			Audio.play("pop")
			Audio.play("splash")
			u.burst(_rect_center(pz.plug), Color(0.5, 0.8, 1.0), 16, 120.0)
			u.burst(_rect_center(pz.plug), Color(0.6, 0.62, 0.66), 8, 80.0)
			queue_redraw()
			return true
		&"strut":
			_clear(pz.strut)
			Audio.play("plank")
			u.burst(_rect_center(pz.strut), Color(0.65, 0.45, 0.25), 18, 140.0)
			var b: FallingBody = boulders.get(i)
			if is_instance_valid(b):
				b.sleeping = false
			queue_redraw()
			return true
		&"heavy_stone":
			var who := _player(player)
			var lifted_by: Array[StringName] = (pz.data as PuzzleData).lifted_by
			if who != null and who.vehicle != null and lifted_by.has(who.vehicle.id):
				_lift(i, who)
				return true
			_picture[i] = PICTURE_TIME
			too_heavy.emit(i, player)
			return false
	return false


func _lift(i: int, who: HillPlayer) -> void:
	var pz: Dictionary = g.puzzles[i]
	var r: Rect2i = pz.block
	_clear(r)
	if who.vehicle.sounds.has(&"dig"):
		Audio.play(String(who.vehicle.sounds[&"dig"]))
	Audio.play("rock_crack")
	who.bump()
	for k in HEAVY_BLOCKS:
		if not who.keep_block(&"stone"):
			Inventory.add(&"stone")
	var ghost := LiftGhost.new()
	ghost.size = Vector2(r.size) * 16.0
	ghost.position = Vector2(r.position) * 16.0
	add_child(ghost)
	u.burst(_rect_center(r), Color(0.45, 0.46, 0.5), 20, 150.0)
	_check(i, who.player)


# --- the boulder and the cracked wall ---------------------------------------------------------

func _on_body_landed(b: Node2D, _speed: float) -> void:
	if b == null or not b.has_meta(&"puzzle"):
		return
	_try_break(int(b.get_meta(&"puzzle")), b as FallingBody)


func _try_break(i: int, b: FallingBody) -> void:
	var pz: Dictionary = g.puzzles[i]
	if not is_instance_valid(b) or not _any_solid(pz.crack):
		return
	var under := world.shape.cell_at(world.to_local(b.global_position) + Vector2(0, BOULDER_SIZE * 0.5 + 4.0))
	if not (pz.crack as Rect2i).grow(1).has_point(under):
		return
	var r: Rect2i = pz.crack
	_clear(r)
	Audio.play("wall_crumble")
	u.burst(_rect_center(r), Color(0.55, 0.58, 0.64), 26, 170.0)
	for c in _cells(r):
		var piece := FallingBody.new()
		piece.name = "Rubble"
		piece.size_px = Vector2(9, 8)
		piece.color = Color(0.42, 0.46, 0.53)
		piece.collision_layer = 4
		piece.collision_mask = 1
		piece.position = _cell_center(c)
		world.add_child(piece)
		piece.sleeping = false
		piece.linear_velocity = Vector2(randf_range(-40.0, 40.0), randf_range(-80.0, -20.0))
	b.sleeping = false
	_check(i, _nearest_player(_rect_center(r)))


# --- tick -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	for k in _picture.keys():
		_picture[k] = float(_picture[k]) - delta
		if _picture[k] <= 0.0:
			_picture.erase(k)
	_poll += delta
	if _poll >= POLL:
		_poll = 0.0
		for i in g.puzzles.size():
			if done[i]:
				continue
			if g.puzzles[i].kind == &"boulder_wall":
				var b: FallingBody = boulders.get(i)
				if is_instance_valid(b) and b.sleeping:
					_try_break(i, b)
			_check(i, -1)
	queue_redraw()


func _check(i: int, player: int) -> void:
	if done[i] or not _world_solved(i):
		return
	done[i] = true
	var pz: Dictionary = g.puzzles[i]
	var at := _cell_center(pz.gift)
	if player < 0:
		player = _nearest_player(at)
	Audio.play("treasure_reveal")
	u.burst(at, GLOW, 24, 160.0)
	u.burst(at, GOLD, 16, 90.0)
	var block := HillGenerator._main_block(g.layer_rows[pz.layer])
	var who := _player(player)
	for k in (pz.data as PuzzleData).gift:
		if who == null or not who.keep_block(block):
			Inventory.add(block)
	if i < _lights.size() and is_instance_valid(_lights[i]):
		world.remove_light(_lights[i])
	solved.emit(i, player)


# --- helpers ----------------------------------------------------------------------------------

func _clear(r: Rect2i) -> void:
	for c in _cells(r):
		if world.is_solid(c):
			world.set_tile(c, 0)


func _any_solid(r: Rect2i) -> bool:
	for c in _cells(r):
		if world.is_solid(c):
			return true
	return false


static func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


static func _cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * 16.0


static func _rect_center(r: Rect2i) -> Vector2:
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * 16.0


func _player(p: int) -> HillPlayer:
	if p < 0 or u.players_root == null:
		return null
	for c in u.players_root.get_children():
		if c is HillPlayer and (c as HillPlayer).player == p:
			return c
	return null


func _nearest_player(at: Vector2) -> int:
	var best := -1
	var bd := INF
	if u.players_root == null:
		return -1
	for c in u.players_root.get_children():
		if c is HillPlayer:
			var d := world.to_local((c as Node2D).global_position).distance_to(at)
			if d < bd:
				bd = d
				best = (c as HillPlayer).player
	return best


func _someone_near(at: Vector2) -> bool:
	if u.players_root == null:
		return false
	for c in u.players_root.get_children():
		if world.to_local((c as Node2D).global_position).distance_to(at) < HINT_REACH:
			return true
	return false


# --- drawing (pictures only) ------------------------------------------------------------------

func _draw() -> void:
	for i in g.puzzles.size():
		var pz: Dictionary = g.puzzles[i]
		match pz.kind:
			&"drain":
				_draw_plug(pz.plug)
				if not done[i]:
					if _any_solid(pz.wall):
						_outline(i, pz.wall)
						_hint(i, _rect_center(pz.wall) + Vector2(0, -30), Vector2.DOWN)
					if _any_solid(pz.plug):
						_outline(i, pz.plug)
						_hint(i, _rect_center(pz.plug) + Vector2(0, -30), Vector2.DOWN)
			&"boulder_wall":
				_draw_strut(pz.strut)
				_draw_crack(pz.crack)
				if not done[i] and _any_solid(pz.strut):
					_outline(i, pz.strut)
			&"heavy_block":
				_draw_heavy(pz.block)
				if not done[i]:
					_outline(i, pz.block)
					if not _picture.has(i):
						_hint(i, _rect_center(pz.block) + Vector2(0, -(pz.block as Rect2i).size.y * 8.0 - 16.0), Vector2.DOWN)
				if _picture.has(i):
					_draw_loader(_rect_center(pz.block) + Vector2(0, -(pz.block as Rect2i).size.y * 8.0 - 22.0), clampf(float(_picture[i]) * 3.0, 0.0, 1.0))
		if not done[i]:
			_draw_gift(_cell_center(pz.gift))


## A slow gold pulse round the tiles to dig, while a player is near.
func _outline(i: int, r: Rect2i) -> void:
	var rect := Rect2(Vector2(r.position) * 16.0, Vector2(r.size) * 16.0)
	if not _someone_near(rect.get_center()):
		return
	var k := 0.5 + 0.5 * sin(_t * 4.0 + i)
	draw_rect(rect.grow(1.0 + k * 2.0), Color(GLOW, 0.35 + 0.45 * k), false, 2.0)


## A bobbing arrow pointing `dir`, shown while a player is near.
func _hint(i: int, at: Vector2, dir: Vector2) -> void:
	if not _someone_near(at):
		return
	var bob := sin(_t * 5.0 + i) * 4.0
	var p := at - dir * bob
	var side := Vector2(-dir.y, dir.x)
	var tip := p + dir * 11.0
	var pts := PackedVector2Array([tip, p - dir * 5.0 + side * 10.0, p - dir * 5.0 - side * 10.0])
	draw_colored_polygon(pts, Color(0.1, 0.08, 0.05, 0.85))
	var inner := PackedVector2Array([tip - dir * 3.0, p - dir * 2.5 + side * 7.0, p - dir * 2.5 - side * 7.0])
	draw_colored_polygon(inner, Color(GLOW, 0.8 + 0.2 * sin(_t * 6.0)))


func _draw_gift(c: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(c, 10.0 + pulse * 3.0, Color(GLOW, 0.18 + 0.12 * pulse))
	var box := Rect2(c + Vector2(-6, -4), Vector2(12, 10))
	draw_rect(box, GOLD)
	draw_rect(box, Color(0.45, 0.3, 0.05), false, 1.0)
	draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 10)), Color("4a90d9"))
	draw_rect(Rect2(c + Vector2(-6, 0), Vector2(12, 2)), Color("4a90d9"))
	draw_circle(c + Vector2(-3, -6), 2.5, Color("4a90d9"))
	draw_circle(c + Vector2(3, -6), 2.5, Color("4a90d9"))


func _draw_plug(r: Rect2i) -> void:
	for c in _cells(r):
		if not world.is_solid(c):
			continue
		var p := _cell_center(c)
		draw_circle(p, 7.0, Color(0.25, 0.27, 0.3))
		draw_arc(p, 7.0, 0.0, TAU, 16, Color(0.75, 0.77, 0.8), 1.5)
		for k in 3:
			var x := -4.0 + k * 4.0
			draw_line(p + Vector2(x, -5), p + Vector2(x, 5), Color(0.75, 0.77, 0.8), 1.0)


func _draw_strut(r: Rect2i) -> void:
	if not _any_solid(r):
		return
	var a := Vector2(r.position) * 16.0
	var s := Vector2(r.size) * 16.0
	draw_rect(Rect2(a, s), Color(0.55, 0.36, 0.18))
	var dark := Color(0.32, 0.2, 0.09)
	draw_rect(Rect2(a + Vector2(2, 0), Vector2(6, s.y)), Color(0.66, 0.45, 0.24))
	draw_rect(Rect2(a + Vector2(s.x - 8, 0), Vector2(6, s.y)), Color(0.66, 0.45, 0.24))
	draw_line(a + Vector2(3, 3), a + s - Vector2(3, 3), dark, 3.0)
	draw_line(a + Vector2(s.x - 3, 3), a + Vector2(3, s.y - 3), dark, 3.0)
	draw_rect(Rect2(a, s), dark, false, 1.0)


func _draw_crack(r: Rect2i) -> void:
	var line := Color(0.08, 0.08, 0.1, 0.9)
	for c in _cells(r):
		if not world.is_solid(c):
			continue
		var p := Vector2(c) * 16.0
		var h := (c.x * 7 + c.y * 13) % 3
		draw_polyline(PackedVector2Array([p + Vector2(2, 3 + h), p + Vector2(7, 8), p + Vector2(5, 12), p + Vector2(11, 15)]), line, 1.5)
		draw_line(p + Vector2(7, 8), p + Vector2(13, 5 + h), line, 1.0)


func _draw_heavy(r: Rect2i) -> void:
	if not _any_solid(r):
		return
	var rect := Rect2(Vector2(r.position) * 16.0, Vector2(r.size) * 16.0)
	draw_rect(rect, Color(0.3, 0.31, 0.36))
	draw_rect(rect.grow(-3), Color(0.38, 0.39, 0.45))
	draw_rect(rect, Color(0.12, 0.12, 0.15), false, 2.0)
	for k in [Vector2(5, 5), Vector2(rect.size.x - 5, 5), Vector2(5, rect.size.y - 5), Vector2(rect.size.x - 5, rect.size.y - 5)]:
		draw_circle(rect.position + k, 2.0, Color(0.7, 0.7, 0.75))
	# A lifting ring on top: it wants a bucket.
	draw_arc(rect.position + Vector2(rect.size.x * 0.5, 2), 5.0, PI, TAU, 10, Color(0.75, 0.75, 0.8), 2.0)


## The "needs the Loader" picture: a tiny yellow loader with its bucket up, in a bubble.
func _draw_loader(c: Vector2, a: float) -> void:
	draw_circle(c, 16.0, Color(1, 1, 1, 0.85 * a))
	draw_arc(c, 16.0, 0.0, TAU, 20, Color(0.1, 0.1, 0.1, a), 1.5)
	var y := Color(0.96, 0.78, 0.15, a)
	draw_rect(Rect2(c + Vector2(-8, -2), Vector2(12, 7)), y)
	draw_rect(Rect2(c + Vector2(-6, -8), Vector2(6, 6)), y)
	draw_rect(Rect2(c + Vector2(-5, -7), Vector2(4, 3)), Color(0.6, 0.85, 1.0, a))
	draw_line(c + Vector2(4, 0), c + Vector2(9, -6), y, 2.0)
	draw_rect(Rect2(c + Vector2(7, -10), Vector2(5, 5)), y)
	draw_circle(c + Vector2(-5, 6), 3.0, Color(0.15, 0.15, 0.15, a))
	draw_circle(c + Vector2(2, 6), 3.0, Color(0.15, 0.15, 0.15, a))


## The lifted heavy block rising and fading.
class LiftGhost extends Node2D:
	var size := Vector2(32, 48)
	var k := 0.0

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_property(self, "k", 1.0, 0.6)
		tw.tween_callback(queue_free)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, -k * 28.0), size)
		draw_rect(r, Color(0.38, 0.39, 0.45, 1.0 - k))
		draw_rect(r, Color(0.12, 0.12, 0.15, 1.0 - k), false, 2.0)
