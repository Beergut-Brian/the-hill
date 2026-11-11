## --demo --demo-beat=<name> for the Camera lane (2026-11-10, S-04 / S-06):
##   lead   P1 in the Dump Truck in a Topsoil tunnel drives right and digs on (the camera slides
##          ahead and zooms out a little for the truck), stops (it eases back), then drives left.
##          P2 waits up top in the yard (split screen, their own camera).
##   lead   (first 1.5 s on foot, zoom 2.0; then the truck, zoom 1.7)
##   pick   P1 (been down to the Bottom) steps into the cage up top: the pictures show beside the
##          shaft with the cage at the Bottom; up, up, up moves it to Ice ... Clay, down once: it
##          stops at Stone.
class_name CameraBeats
extends VehicleBeats

const CAMERA_BEATS := ["lead", "pick"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"lead": _lead()
		"pick": _pick()


func _log_cam(what: String) -> void:
	var c: CameraLead = game.camera
	log_event("%s (lead %s, zoom %.2f)" % [what, c.lead_of(P1).round(), c.zoom_of(P1)])


func _lead() -> void:
	var w := _ug().world
	match _stage:
		0:
			for y in range(14, 18):
				for x in range(112, 142):
					w.set_tile(Vector2i(x, y), 0)
			_place(P1, Vector2(116 * 16.0, 18 * 16.0 - 1.0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				_yard(P2, Hillville.SHAFT_X - 300)
			_next("stage: P1 on foot in a Topsoil tunnel")
		1:
			if _since() > 1.5:
				_log_cam("on foot")
				_ride(P1, &"dump_truck", HillGame.UNDERGROUND, Vector2(116 * 16.0, 18 * 16.0 - 1.0))
				game.player_node(P1).facing = 1
				_next("in the Dump Truck")
		2:
			if _since() > 1.5:
				_log_cam("drive right")
				_next("")
		3:
			_hold(P1, Vector2(1, 0), true)
			if _since() > 3.0:
				_log_cam("still driving right, digging")
				_next("")
		4:
			if _since() > 0.05:
				_log_cam("stop")
				_next("")
		5:
			if _since() > 2.0:
				_log_cam("eased back")
				_next("")
		6:
			_hold(P1, Vector2(-1, 0))
			if _since() > 2.0:
				_log_cam("driving left")
				_next("")
		7:
			if _since() > 1.5:
				_log_cam("done")
				_next("done")


func _pick() -> void:
	match _stage:
		0:
			for i in 6:
				Progress.visit_layer(P1, i)
			if game.player_node(P2) != null:
				_yard(P2, Hillville.SHAFT_X - 300)
			game.place_player(P1, HillGame.HILLVILLE, game.hillville.arrival() + Vector2(0, -1))
			game.elevator.door.must_exit.erase(P1)
			_next("stage: P1 in the cage up top, been to layer 5")
		1:
			if game.elevator.is_riding(P1) and game.elevator.pick_of(P1) >= -1:
				_next("ride down starts, pick %d" % game.elevator.pick_of(P1))
		2, 4, 6:
			if _since() > 0.35:
				_hold(P1, Vector2(0, -1))
				_next("up: pick %d" % game.elevator.pick_of(P1))
		3, 5, 7:
			if _since() > 0.1:
				_next("released: pick %d" % game.elevator.pick_of(P1))
		8:
			if _since() > 0.5:
				_hold(P1, Vector2(0, 1))
				_next("down: pick %d" % game.elevator.pick_of(P1))
		9:
			if game.director.scene_of(P1) == HillGame.UNDERGROUND:
				_next("landed at layer %d" % _ug().layer_index_at(game.player_node(P1).global_position))
		10:
			if _since() > 1.5:
				_next("done")
