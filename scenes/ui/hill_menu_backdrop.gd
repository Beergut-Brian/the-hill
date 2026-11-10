## The Showtime lobby's backdrop for The Hill (MenuSkin.Backdrop.SCENE): Hillville live, as the save
## left it (scrub cleared so far), framed on the mine shaft, with the sky, lamps and tint of the
## current TimeOfDay. The kit runs it in a 1920x1080 SubViewport at 1/4 size and blurs it.
## It only reads the save and the clock; it never writes either.
extends Node2D

## Where the camera looks: the head-frame, a little above the ground so the sky fills the top.
const LOOK := Vector2(Hillville.SHAFT_X + 120.0, -170.0)
const ZOOM := 2.0

var hillville: Hillville


func _ready() -> void:
	hillville = Hillville.new()
	var hd = Save.get_value("hillville") if not Game.demo else null
	if hd is Dictionary:
		hillville.load_save(hd)
	add_child(hillville)
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.position = LOOK
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	cam.make_current()
