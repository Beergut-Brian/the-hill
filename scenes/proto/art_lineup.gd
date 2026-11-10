## Art preview: the residents lineup in-game. A strip of Hillville's ground with, left to right,
## Jeff, Chuck, the Mole, the Gnome Foreman, the Caveman, the Dragon, then the Front Loader (Jeff
## driving) and the Excavator (Chuck driving). Camera at zoom 2. No input. `--buildings` looks at
## the buildings (barn, house, garage half open, lighthouse) instead.
##   scripts/tools/shots.sh res://scenes/proto/art_lineup.tscn 2 /tmp/x -- --time=night
extends Node2D

const HILLVILLE := preload("res://scenes/levels/hillville.tscn")
const X0 := 2600.0
const RESIDENTS := [["mole", 85.0], ["foreman", 130.0], ["caveman", 175.0], ["dragon", 285.0]]

var cam: Camera2D


func _ready() -> void:
	var hv: Node2D = HILLVILLE.instantiate()
	add_child(hv)
	for p in 2:
		var who := _player(p, X0 + p * 40.0)
		who.facing = 1
	for r in RESIDENTS:
		var s := SheetSprite.make("characters/%s.png" % r[0], "idle" if r[0] != "dragon" else "asleep")
		s.position = Vector2(X0 + float(r[1]), 0)
		add_child(s)
	var loader := _player(0, X0 + 420.0)
	loader.drive(Progress.vehicle_data(&"front_loader"))
	var exc := _player(1, X0 + 510.0)
	exc.drive(Progress.vehicle_data(&"excavator"))
	if OS.get_cmdline_user_args().has("--buildings"):
		var x := X0 - 120.0
		for id in [&"barn", &"house", &"garage", &"lighthouse"]:
			var b := Building.make(load("res://data/buildings/%s.tres" % id))
			b.position = Vector2(x, 0)
			if id == &"garage":
				b.door_open = 0.5
			add_child(b)
			x += b.size_px().x + 20.0
	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = Vector2(X0 + 285.0, -50.0)
	if OS.get_cmdline_user_args().has("--buildings"):
		cam.position = Vector2(X0 + 40.0, -60.0)
	add_child(cam)
	cam.make_current()


func _player(index: int, x: float) -> HillPlayer:
	var p := HillPlayer.new()
	p.player = index
	p.locked = true
	p.position = Vector2(x, 0)
	add_child(p)
	return p
