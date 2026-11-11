## --demo --demo-beat=<name> for the Feel & controls lane (2026-11-10, playtest items 6 to 9):
##   turn   P1 digs a Topsoil tunnel on foot holding A and half a stick, turning left / right
##          every 0.6 s.
##          Every physics frame logs "turn:" with P1's feet, where P1 is on their screen, the
##          camera, and the cell the next dig takes (the marker) so the jitter can be measured.
class_name ControlsBeats
extends CameraBeats

const CONTROLS_BEATS := ["turn"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"turn": _turn()


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
