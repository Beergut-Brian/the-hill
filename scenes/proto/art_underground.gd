## Art preview of the Underground: the real Underground (tile art, light pass, parallax, props,
## lamps, residents), Jeff on foot with his headlamp and Chuck driving the Front Loader (nose lamp)
## at landing N, after digging a short tunnel and a room off the landing. No input; camera at x2.
##   scripts/tools/shots.sh res://scenes/proto/art_underground.tscn 3 /tmp/x --layer=2
## Args: --layer=0..5 (default 2), --at=car|tooth|gnomes|dragon (look at a treasure / the Dragon).
extends Node2D

const UNDERGROUND := preload("res://scenes/levels/underground.tscn")
const LIGHT_RADIUS := 110.0          # HillGame.LIGHT_RADIUS

var layer := 2
var at := ""
var u: Underground
var cam: Camera2D
var jeff: HillPlayer
var chuck: HillPlayer


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--layer="):
			layer = clampi(int(a.get_slice("=", 1)), 0, 5)
		elif a.begins_with("--at="):
			at = a.get_slice("=", 1)
	u = UNDERGROUND.instantiate()
	add_child(u)
	var feet := u.landing(layer)
	var floor_row := int(feet.y / 16.0) + 1
	var x0 := HillGenerator.SHAFT_X + HillGenerator.ROOM_HALF + 2
	# A 3-high tunnel east of the landing room, then a 7 x 5 dug room.
	for x in range(x0 - 1, x0 + 16):
		for y in range(floor_row - 3, floor_row):
			u.world.dig(Vector2i(x, y))
	for x in range(x0 + 16, x0 + 23):
		for y in range(floor_row - 5, floor_row):
			u.world.dig(Vector2i(x, y))
	jeff = _player(0, Vector2((x0 + 3) * 16.0, feet.y), 1)
	chuck = _player(1, Vector2((x0 + 10) * 16.0, feet.y), -1)
	chuck.drive(Progress.vehicle_data(&"front_loader"))
	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = Vector2((x0 + 4) * 16.0, feet.y - 40.0)
	var focus := _focus()
	if focus != Vector2.INF:
		cam.position = focus
		jeff.position = focus + Vector2(-40, 0)
		jeff.position.y = _floor_y(jeff.position)
		chuck.position = focus + Vector2(-110, 0)
		# A pocket dug toward the find so both stand in the open.
		var c0 := u.world.shape.cell_at(focus + Vector2(-8, -8))
		for x in range(-9, 1):
			for y in range(-1, 1):
				u.world.dig(c0 + Vector2i(x, y))
		jeff.position.y = _floor_y(jeff.position)
		chuck.position.y = _floor_y(chuck.position)
	add_child(cam)
	cam.make_current()
	u.world.update_chunks()


func _player(p: int, pos: Vector2, face: int) -> HillPlayer:
	var n := HillPlayer.new()
	n.name = "P%d" % (p + 1)
	n.player = p
	n.position = pos
	n.facing = face
	n.intent_source = func() -> Dictionary: return {"move": Vector2.ZERO}
	n.world = u.world
	u.players_root.add_child(n)
	u.world.track(n)
	u.world.add_light(n, LIGHT_RADIUS)
	VehicleLamp.attach(n, u.world)
	return n


## A point of interest for --at, or INF.
func _focus() -> Vector2:
	var ids := {"car": &"buried_car", "tooth": &"giant_tooth", "gnomes": &"gnome_room"}
	if ids.has(at):
		var c := u.treasure_cell(ids[at])
		if c.x >= 0:
			for s in u.generator.treasure_spots:
				if s.id == ids[at]:
					var r: Rect2i = s.rect
					return Vector2(r.position.x + r.size.x * 0.5, r.end.y) * 16.0 - Vector2(0, 2)
	if at == "dragon" and u.look and u.look.residents.has(&"dragon"):
		return u.look.residents[&"dragon"].position + Vector2(-60, -2)
	return Vector2.INF


func _floor_y(pos: Vector2) -> float:
	var c := u.world.shape.cell_at(pos)
	for k in range(-6, 30):
		if u.world.is_solid(c + Vector2i(0, k)) and not u.world.is_solid(c + Vector2i(0, k - 1)):
			return (c.y + k) * 16.0 - 2.0
	return pos.y
