## Cows from barns (B-02): every Barn in Hillville has one cow that wanders its yard, grazes and
## swishes her tail. More barns, more cows: a hundred barns is a hundred cows. A Barn placed live
## sends its cow trotting out of the door with a little hop and a heart; a player walking into a
## cow makes her hop and show a heart. Moving a Barn moves its cow's yard with it.
## Placeholder art: drawn in code (no library cow is approved for play yet; the Jarling cow is
## still a proposal). Visuals only, no collision, nothing saved: cows follow Progress.buildings.
class_name BarnCows
extends Node2D

const PLOT := 48.0
const YARD := 70.0           # how far a cow strays either side of her barn
const SPEED := 18.0
const TROT := 46.0           # walking out of a new barn
const NEAR_PLAYER := 22.0
const OUTLINE := Color("2a1e24")
const HIDE := Color("f4efe6")
const PATCH := Color("3a2c30")
const SNOUT := Color("f2a0a8")
const HORN := Color("e8d9a8")
const HEART := Color("ff5d8f")

var hillville: Hillville
var game: Node
## One per barn, in Progress.buildings order: {home, x, dir, state, t, hop, heart, seed, out}.
var cows: Array = []
var _t := 0.0


func setup(p_game: Node, p_hillville: Hillville) -> void:
	game = p_game
	hillville = p_hillville
	name = "BarnCows"
	Events.building_placed.connect(_on_building_placed)
	sync()


func _exit_tree() -> void:
	if Events.building_placed.is_connected(_on_building_placed):
		Events.building_placed.disconnect(_on_building_placed)


## The middle of every Barn's door, in placement order.
func barn_homes() -> Array[float]:
	var out: Array[float] = []
	for b in Progress.buildings:
		if b.id == &"barn":
			out.append((float((b.cell as Vector2i).x) + 1.0) * PLOT)
	return out


## Matches the herd to the barns: new barns get a cow standing in her yard, moved barns move it.
func sync() -> void:
	var homes := barn_homes()
	while cows.size() > homes.size():
		cows.pop_back()
	for i in homes.size():
		if i >= cows.size():
			cows.append(_new_cow(i, homes[i]))
		elif not is_equal_approx(cows[i].home, homes[i]):
			cows[i].x += homes[i] - cows[i].home
			cows[i].home = homes[i]


func _new_cow(i: int, home: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021 + i * 7919
	return {"home": home, "x": home + rng.randf_range(-YARD, YARD), "dir": 1 if rng.randf() < 0.5 else -1,
			"state": &"walk", "t": rng.randf_range(0.5, 3.0), "hop": 0.0, "heart": 0.0,
			"seed": rng.randi(), "out": 0.0, "patches": rng.randi_range(0, 3)}


func _on_building_placed(id: StringName, _cell: Vector2i) -> void:
	if id != &"barn":
		return
	sync()
	# The newest cow trots out of her door, hops and shows a heart.
	var c: Dictionary = cows[cows.size() - 1]
	c.x = c.home
	c.dir = 1 if (cows.size() % 2) == 0 else -1
	c.state = &"trot"
	c.t = 1.4
	c.out = 1.0
	c.hop = 0.5
	c.heart = 1.6
	if hillville != null:
		hillville.puff(Vector2(c.home, 0), Color(0.85, 0.75, 0.6), 6)


func cow_count() -> int:
	return cows.size()


func _process(delta: float) -> void:
	_t += delta
	sync()
	modulate = TimeOfDay.world_tint()
	var feet := _player_feet()
	for c: Dictionary in cows:
		c.t -= delta
		c.hop = maxf(0.0, c.hop - delta)
		c.heart = maxf(0.0, c.heart - delta)
		c.out = maxf(0.0, c.out - delta * 0.6)
		match c.state:
			&"walk", &"trot":
				c.x += c.dir * (TROT if c.state == &"trot" else SPEED) * delta
				if absf(c.x - c.home) > YARD:
					c.x = c.home + signf(c.x - c.home) * YARD
					c.dir = -signi(int(c.x - c.home))
				if c.t <= 0.0:
					c.state = &"graze"
					c.t = 1.5 + float(c.seed % 5) * 0.6
			&"graze":
				if c.t <= 0.0:
					c.state = &"walk"
					c.t = 1.5 + float((c.seed >> 3) % 5) * 0.7
					if c.seed % 3 == 0 or absf(c.x - c.home) > YARD * 0.6:
						c.dir = -c.dir if absf(c.x - c.home) < YARD * 0.6 else -signi(int(c.x - c.home))
					c.seed = (c.seed * 1103515245 + 12345) & 0x7fffffff
		# A player bumping in: a happy hop and a heart (once per visit).
		var near := false
		for f in feet:
			if absf(f.x - c.x) < NEAR_PLAYER and f.y > -30.0:
				near = true
		if near and not c.get("touched", false):
			c.hop = 0.45
			c.heart = 1.4
			# TODO(audio): `cow_moo` is not in assets/audio/CUES.md yet (PLAN-STATUS B-02).
		c["touched"] = near
	queue_redraw()


func _player_feet() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if hillville == null:
		return out
	for n in hillville.players_root().get_children():
		if n is Node2D:
			out.append(to_local((n as Node2D).global_position))
	return out


func _draw() -> void:
	for c: Dictionary in cows:
		_draw_cow(c)


## A chunky side-view cow, about 30 x 20 px, facing c.dir: body, patches, head, legs, tail.
func _draw_cow(c: Dictionary) -> void:
	var d: int = c.dir
	var hop := sin(clampf(c.hop / 0.45, 0.0, 1.0) * PI) * 7.0
	var walking: bool = c.state != &"graze"
	var step := sin(_t * (14.0 if c.state == &"trot" else 8.0) + c.home) if walking else 0.0
	var base := Vector2(roundf(c.x), -hop)
	var s := 1.0 - 0.25 * float(c.out)          # a new cow pops out a little small, then grows
	draw_set_transform(base, 0.0, Vector2(d * s, s))
	# Legs (two pairs, swinging opposite).
	var legs := [-10.0, -6.0, 6.0, 10.0]
	for i in legs.size():
		var lx: float = legs[i]
		var sw := step * (2.0 if i % 2 == 0 else -2.0)
		draw_rect(Rect2(lx - 1.5 + sw, -8, 4, 8), OUTLINE)
		draw_rect(Rect2(lx - 0.5 + sw, -8, 2, 6), HIDE)
	# Body.
	var body := Rect2(-15, -21, 30, 14)
	draw_rect(body.grow(1.5), OUTLINE)
	draw_rect(body, HIDE)
	var patches := [Rect2(-11, -20, 8, 6), Rect2(2, -15, 7, 6), Rect2(-4, -21, 5, 4), Rect2(8, -21, 5, 5)]
	for k in 2 + int(c.patches) % 3:
		draw_rect(patches[(k + int(c.patches)) % patches.size()], PATCH)
	draw_rect(Rect2(-6, -8, 7, 3), SNOUT)                     # udder
	# Tail: swishes.
	var tail := Vector2(-17, -17 + sin(_t * 3.0 + c.home) * 3.0)
	draw_line(Vector2(-15, -19), tail, OUTLINE, 2.0)
	draw_circle(tail + Vector2(0, 2), 2.0, PATCH)
	# Head: up when walking, down to the grass when grazing.
	var hy := -22.0 if walking else -12.0
	var head := Rect2(13, hy, 11, 10)
	draw_rect(head.grow(1.5), OUTLINE)
	draw_rect(head, HIDE)
	draw_rect(Rect2(head.end.x - 5, head.end.y - 4, 6, 5).grow(0.5), OUTLINE)
	draw_rect(Rect2(head.end.x - 5, head.end.y - 4, 6, 5), SNOUT)
	draw_rect(Rect2(head.position.x + 5, head.position.y + 2, 2, 2), OUTLINE)   # eye
	draw_rect(Rect2(head.position.x + 1, head.position.y - 3, 2, 3), HORN)
	draw_rect(Rect2(head.position.x - 2, head.position.y + 1, 3, 2), PATCH)       # ear
	if not walking:
		# Grass tuft in her mouth.
		draw_line(Vector2(head.end.x, 0), Vector2(head.end.x + 2, -4), Color("5aa14a"), 1.5)
		draw_line(Vector2(head.end.x + 3, 0), Vector2(head.end.x + 4, -5), Color("5aa14a"), 1.5)
	draw_set_transform(Vector2.ZERO)
	if c.heart > 0.0:
		var k: float = 1.0 - c.heart / 1.6
		var at := base + Vector2(d * 18.0, -34.0 - k * 14.0)
		var a := clampf(c.heart / 0.4, 0.0, 1.0)
		draw_circle(at + Vector2(-2.5, 0), 3.2, Color(HEART, a))
		draw_circle(at + Vector2(2.5, 0), 3.2, Color(HEART, a))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-5.5, 1), at + Vector2(5.5, 1), at + Vector2(0, 7)]), Color(HEART, a))
