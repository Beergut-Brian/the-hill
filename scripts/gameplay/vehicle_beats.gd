## --demo --demo-beat=<name> for the crane-and-pond vehicles lane (2026-11-10, H-03 / H-05). Like
## the other beat runners it sets the stage, then the real systems play it out (real A presses
## through the player's intent, the real elevator).
##   pond   P1 in the Excavator in the yard digs: the ground opens two tiles deep and water seeps
##          in; P1 backs up and digs again beside it, and splashes the full pond.
##   ball   P1 in the Crane swings the wrecking ball at a Barn (it leans right over and springs
##          back), then at the block pile (it leans, blocks tumble), then at a stump and scrub.
##   lift   P1 in the Crane pushes up + A by a Barn: it goes up on the hook, P1 drives it along and
##          sets it down with A.
##   cable  P1 in the Crane and P2 on foot step into the cage: the elevator sinks, then the
##          Crane's cable lowers both down the shaft to the Stone landing in about a second.
class_name VehicleBeats
extends PolishBeats

const VEHICLE_BEATS := ["pond", "ball", "lift", "cable"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"pond": _pond()
		"ball": _ball()
		"lift": _lift()
		"cable": _cable()


func _loader_away() -> void:
	var loader: Vehicle = game.vehicles.get(HillGame.LOADER)
	if loader != null:
		loader.position.x = Hillville.SHAFT_X + 520.0


func _press(p: int, move := Vector2.ZERO) -> void:
	_hold(p, move, true)


func _pond() -> void:
	var hv: Hillville = game.hillville
	match _stage:
		0:
			_loader_away()
			_ride(P1, &"excavator", HillGame.HILLVILLE, Vector2(34 * 48, 0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				_yard(P2, 32 * 48 + 10)
			_next("stage: Excavator in the yard")
		1:
			if _since() > 1.5:
				_press(P1)
				if _since() > 2.3:
					_next("dug %d columns (deepest %d)" % [hv.pond_columns().size(), hv.pond_depth(hv.pond_columns()[0])])
		2:
			if _since() > 1.2:
				_next("filled (%.2f)" % hv.pond_water(hv.pond_columns()[0]))
		3:
			_hold(P1, Vector2(1, 0))
			if _since() > 0.5:
				_next("drove on")
		4:
			_press(P1)
			if _since() > 0.8:
				_next("dug beside: %d columns" % hv.pond_columns().size())
		5:
			if _since() > 1.5:
				_next("pond full")
		6:
			_press(P1)
			if _since() > 0.4:
				_next("splash in the full pond")
		7:
			if _since() > 2.0:
				_next("done")


func _ball() -> void:
	match _stage:
		0:
			_loader_away()
			Progress.add_building(&"barn", Vector2i(36, 0))
			game.build.rebuild()
			for b in [&"dirt", &"clay", &"stone"]:
				Inventory.add(b, 8)
			_ride(P1, &"crane", HillGame.HILLVILLE, Vector2(36 * 48 - 46, 0))
			game.player_node(P1).facing = 1
			game.player_node(P1).ability.ball_hit.connect(func(w: Array) -> void: log_event("ball hit %s" % [w]))
			if game.player_node(P2) != null:
				_yard(P2, 33 * 48)
			_next("stage: Crane by a Barn")
		1, 2:
			if _since() > 1.6:
				_press(P1)
				_next("swing at the barn")
		3:
			if _since() > 1.6:
				game.place_player(P1, HillGame.HILLVILLE, Vector2(Hillville.PILE_X + 6 * 16 + 38, 0))
				game.player_node(P1).facing = -1
				_next("by the pile")
		4:
			if _since() > 1.0:
				_press(P1)
				_next("swing at the pile")
		5:
			if _since() > 1.8:
				game.place_player(P1, HillGame.HILLVILLE, Vector2(32 * 48 + 8, 0))
				game.player_node(P1).facing = -1
				_next("by the scrub")
		6:
			if _since() > 1.0:
				_press(P1)
				_next("swing at the scrub")
		7:
			if _since() > 2.0:
				_next("done")


func _lift() -> void:
	var node: HillPlayer = game.player_node(P1)
	match _stage:
		0:
			_loader_away()
			Progress.add_building(&"barn", Vector2i(34, 0))
			game.build.rebuild()
			_ride(P1, &"crane", HillGame.HILLVILLE, Vector2(34 * 48 - 40, 0))
			node.facing = 1
			if game.player_node(P2) != null:
				_yard(P2, 32 * 48)
			_next("stage: Crane by a Barn")
		1:
			if _since() > 1.5:
				_press(P1, Vector2(0, -1))
				_next("up + A: lift")
		2:
			if _since() > 0.8:
				_next("lifted %.0f px" % -game.build.ghost_of(P1).position.y)
		3:
			_hold(P1, Vector2(1, 0))
			if _since() > 0.9:
				_next("carried along")
		4:
			if _since() > 0.6:
				_press(P1)
				_next("A: set down")
		5:
			if _since() > 0.6:
				_next("barn at cell %d" % Progress.buildings[0].cell.x)
		6:
			if _since() > 1.5:
				_next("done")


func _cable() -> void:
	match _stage:
		0:
			_loader_away()
			var li := _layer(&"stone")
			Progress.deepest[P1] = li
			_ride(P1, &"crane", HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X - 4, 0))
			if game.player_node(P2) != null:
				game.place_player(P2, HillGame.HILLVILLE, Vector2(Hillville.SHAFT_X + 10, 0))
			game.elevator.ride_started.connect(func(r: Array, _f: StringName) -> void: log_event("ride starts %s" % [r]), CONNECT_ONE_SHOT)
			_next("stage: Crane and P2 in the cage (deepest: Stone)")
		1:
			if game.elevator.crane_ride != null:
				game.elevator.crane_ride.landed.connect(func(p: int) -> void: log_event("landed P%d" % (p + 1)))
				_next("cable ride")
		2:
			if _since() > 3.0:
				_next("done")
