## --demo --demo-beat=<name> for the Feel & controls lane (2026-11-10, playtest items 6 to 9):
##   turn   P1 digs a Topsoil tunnel on foot holding A and half a stick, turning left / right
##          every 0.6 s.
##          Every physics frame logs "turn:" with P1's feet, where P1 is on their screen, the
##          camera, and the cell the next dig takes (the marker) so the jitter can be measured.
##   lift   P1 stands in the cage up top (the A blinks over the head), P2 two tiles away; A: both
##          ride down. Then P1 at the Stone landing presses A: the car comes down its rope, then
##          up they go. P2 stays below (too far away).
##   climb  P1 deep in Topsoil holds up-right and A: the shovel carves a step, P1 climbs it, again
##          and again (a staircase). Then a ladder (the Gnome crew's hook, placeholder rails) that
##          P1 climbs with up.
##   turn-surface  PT1112-1: P1 up top beside the parked Loader taps left / right in place, then
##          walks left and back, then drives the Loader left and right; logs "tscr:" (body,
##          camera, Loader in screen px) every frame.
##   hints  The hint panels in each context: P1 on foot underground (A dig, B jump), up top
##          beside the Front Loader (B get in, X book), driving it (A scoop, B get out), in the
##          cage (A ride); P2 up top on foot the whole time (B jump, X book).
class_name ControlsBeats
extends CameraBeats

const CONTROLS_BEATS := ["turn", "lift", "hints", "climb", "turn-surface"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"turn": _turn()
		"lift": _lift()
		"hints": _hints()
		"climb": _climb()
		"turn-surface": _turn_surface()


## Where player p's feet are on their own screen (px from the left of their view).
func screen_x(p: int) -> float:
	var cam: Camera2D = game.director.camera_of(p)
	var node: HillPlayer = game.player_node(p)
	var vp := cam.get_viewport_rect().size
	return (node.global_position.x - cam.get_screen_center_position().x) * cam.zoom.x + vp.x * 0.5


func _log_turn() -> void:
	var n: HillPlayer = game.player_node(P1)
	var cam: Camera2D = game.director.camera_of(P1)
	var aim := n.aim_of(n.move_intent)
	var cells := n.dig_cells(aim) if n.world != null else []
	var mark: Vector2i = n.dig_marker_cell() if n.has_method("dig_marker_cell") else (cells[0] if not cells.is_empty() else Vector2i.ZERO)
	print("turn: f=%d t=%.3f feet_y=%.1f feet_x=%.1f screen_x=%.1f cam_x=%.1f facing=%d mark=%s cells=%s" % [
		Engine.get_physics_frames(), t, n.global_position.y, n.global_position.x, screen_x(P1),
		cam.get_screen_center_position().x, n.facing, mark, cells])


func _turn() -> void:
	match _stage:
		0:
			var w := _ug().world
			for y in range(14, 18):
				for x in range(68, 70):
					w.set_tile(Vector2i(x, y), 0)
			_place(P1, Vector2(69.5 * 16.0, 18 * 16.0 - 1.0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				_yard(P2, Hillville.SHAFT_X - 300)
			_next("stage: P1 on foot in a short Topsoil tunnel")
		1:
			if _since() > 1.0:
				_next("turning starts")
		2:
			# Right 0.6 s, left 0.6 s, ... five turns, holding A the whole time.
			var k := int(_since() / 0.6)
			var dir := 1 if k % 2 == 0 else -1
			# Half a stick toward the side and A held: walks back through the tunnel and digs on.
			_hold(P1, Vector2(dir * 0.5, 0), true)
			_log_turn()
			if k >= 6:
				_next("turning done")
		3:
			_log_turn()
			if _since() > 1.0:
				_next("done")


func _a(p: int) -> void:
	_intent[p] = {"move": Vector2.ZERO, "dig": true, "jump": false, "book": false, "horn": false}


func _lift() -> void:
	var el: HillElevator = game.elevator
	match _stage:
		0:
			el.walk_in = false
			Progress.visit_layer(P1, 0)
			Progress.visit_layer(P1, 1)
			game.place_player(P1, HillGame.HILLVILLE, game.hillville.arrival() + Vector2(0, -1))
			if game.player_node(P2) != null:
				game.place_player(P2, HillGame.HILLVILLE, game.hillville.arrival() + Vector2(40, -1))
			_next("stage: P1 in the cage up top, P2 two tiles away")
		1:
			if _since() > 1.5:
				_a(P1)
				_next("A: ride down")
		2:
			if game.director.scene_of(P1) == HillGame.UNDERGROUND and not game.player_node(P1).locked:
				_next("landed: P2 %s" % game.director.scene_of(P2))
		3:
			if _since() > 1.0:
				for i in 4:
					Progress.visit_layer(P1, i)
				_place(P1, _ug().landing(3))
				if game.player_node(P2) != null:
					_place(P2, _ug().landing(0) + Vector2(-90, 0))
				_next("stage: P1 at the Stone landing (car at %d)" % el.car_at)
		4:
			if _since() > 1.0:
				_a(P1)
				_next("A: call the car")
		5:
			if _since() > 0.15 and _since() < 0.2:
				log_event("car at %.2f" % el.car_position())
			if game.director.scene_of(P1) == HillGame.HILLVILLE and not game.player_node(P1).locked:
				_next("up top: P2 %s" % game.director.scene_of(P2))
		6:
			if _since() > 1.0:
				_next("done")


func _hints() -> void:
	match _stage:
		0:
			var w := _ug().world
			for y in range(14, 18):
				for x in range(66, 74):
					w.set_tile(Vector2i(x, y), 0)
			_place(P1, Vector2(70 * 16.0, 18 * 16.0 - 1.0))
			if game.player_node(P2) != null:
				_yard(P2, Hillville.SHAFT_X - 300)
			_next("stage: P1 on foot underground")
		1:
			if _since() > 2.0:
				var lx: float = game.loader_position().pos.x
				game.place_player(P1, HillGame.HILLVILLE, Vector2(lx - 30.0, 0))
				game.player_node(P1).facing = 1
				_next("P1 beside the Front Loader up top")
		2:
			if _since() > 2.0:
				game.hop_in(game.player_node(P1))
				_next("P1 in the Front Loader")
		3:
			if _since() > 2.0:
				game.hop_out(game.player_node(P1), true)
				game.elevator.walk_in = false
				game.place_player(P1, HillGame.HILLVILLE, game.hillville.arrival() + Vector2(0, -1))
				_next("P1 in the cage up top")
		4:
			if _since() > 2.0:
				_next("done")


func _climb() -> void:
	var w := _ug().world
	match _stage:
		0:
			for y in range(19, 21):
				w.set_tile(Vector2i(70, y), 0)
			_place(P1, Vector2(70.5 * 16.0, 21 * 16.0 - 1.0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				_yard(P2, Hillville.SHAFT_X - 300)
			_next("stage: P1 in a pocket deep in Topsoil")
		1:
			if _since() > 1.0:
				_next("up-right + A")
		2:
			_hold(P1, Vector2(0.7, -0.7), true)
			if _since() > 3.5:
				_next("climbed to row %d" % int(game.player_node(P1).global_position.y / 16.0))
		3:
			if _since() > 1.0:
				for y in range(12, 22):
					w.set_tile(Vector2i(60, y), 0)
					w.set_tile(Vector2i(59, y), 0)
				game.ladders.add(60, 12, 21)
				_place(P1, Vector2(60.5 * 16.0, 22 * 16.0 - 1.0))
				_next("ladder")
		4:
			_hold(P1, Vector2(0, -1))
			if _since() > 1.2:
				_next("hanging on the ladder")
		5:
			if _since() > 1.0:
				game.ladders.clear()
				_next("done")


## PT1112-1: Kaden's video (2026-11-12). P1 on foot up top just left of the parked Front Loader
## taps left / right six times (0.08 s of stick each: a turn in place), then walks left and back
## right. Each frame, after the director and CameraLead (process_priority 100), logs "tscr:" with
## where the painted body, the camera and the Loader are on P1's screen (the view's canvas
## transform applied), so a turn that moves anything shows up as a number.
func _process(_delta: float) -> void:
	if beat != "turn-surface" or _stage < 1 or game.player_node(P1) == null:
		return
	var n: HillPlayer = game.player_node(P1)
	var cam: Camera2D = game.director.camera_of(P1)
	var xf := cam.get_viewport().get_canvas_transform()
	var v: Node2D = game.vehicles.get(HillGame.LOADER)
	var vx: float = (xf * v.global_position).x if v != null and v.is_inside_tree() else -1.0
	var box: Rect2 = xf * n.global_transform * n.body_box()
	print("tscr: f=%d t=%.3f facing=%d feet_x=%.2f cam_x=%.2f body_scr_cx=%.2f body_scr_w=%.0f loader_scr_x=%.2f" % [
		Engine.get_process_frames(), t, n.facing, n.global_position.x, cam.position.x,
		box.get_center().x, box.size.x, vx])


func _turn_surface() -> void:
	match _stage:
		0:
			process_priority = 100
			var lx: float = game.loader_position().pos.x
			game.place_player(P1, HillGame.HILLVILLE, Vector2(lx - 140.0, 0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				_yard(P2, Hillville.SHAFT_X - 300)
			_next("stage: P1 on foot up top, left of the Front Loader")
		1:
			if _since() > 1.0:
				_next("taps start")
		2:
			var k := int(_since() / 0.5)
			var dir := -1 if k % 2 == 0 else 1
			_hold(P1, Vector2(dir, 0) if fmod(_since(), 0.5) < 0.08 else Vector2.ZERO)
			if k >= 6:
				_next("walk left")
		3:
			_hold(P1, Vector2(-1, 0))
			if _since() > 0.6:
				_next("walk right")
		4:
			_hold(P1, Vector2(1, 0))
			if _since() > 0.6:
				_next("stand")
		5:
			_hold(P1, Vector2.ZERO)
			if _since() > 1.0:
				var lx: float = game.loader_position().pos.x
				game.place_player(P1, HillGame.HILLVILLE, Vector2(lx - 30.0, 0))
				game.hop_in(game.player_node(P1))
				_next("P1 in the Front Loader: %s" % (game.player_node(P1).vehicle != null))
		6:
			# A flipped vehicle and its bucket mirror in place too (same SpriteArt draw).
			_hold(P1, Vector2(-1, 0) if _since() < 0.5 else Vector2.ZERO)
			if _since() > 1.2:
				_next("drive right")
		7:
			_hold(P1, Vector2(1, 0) if _since() < 0.5 else Vector2.ZERO)
			if _since() > 1.2:
				_next("done")
