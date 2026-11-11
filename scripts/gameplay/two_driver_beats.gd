## --demo --demo-beat=drivers for the two-vehicles lane (2026-11-10, H-09): P1 in the Excavator and
## P2 in the Front Loader on the same underground layer. They drive toward each other, dig down
## together, dig sideways apart, and P1 honks (the Excavator's cab spins) while P2 keeps digging.
## The real systems play it out through each player's own intent.
class_name TwoDriverBeats
extends VehicleBeats

const TWO_BEATS := ["drivers"]
const ROOM := Rect2i(40, 14, 40, 4)


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or game.player_node(P2) == null or t < START:
		return
	if beat == "drivers":
		_drivers()


func _feet(cx: int) -> Vector2:
	return Vector2((cx + 0.5) * 16.0, ROOM.end.y * 16.0 - 1.0)


func _drivers() -> void:
	var a: HillPlayer = game.player_node(P1)
	var b: HillPlayer = game.player_node(P2)
	match _stage:
		0:
			var w := _ug().world
			for y in range(ROOM.position.y, ROOM.end.y):
				for x in range(ROOM.position.x, ROOM.end.x):
					w.set_tile(Vector2i(x, y), 0)
			_ride(P1, &"excavator", HillGame.UNDERGROUND, _feet(50))
			_ride(P2, HillGame.LOADER, HillGame.UNDERGROUND, _feet(68))
			a.facing = 1
			b.facing = -1
			_next("stage: P1 Excavator, P2 Loader, one layer")
		1:
			if _since() > 0.8:
				_hold(P1, Vector2(1, 0))
				_hold(P2, Vector2(-1, 0))
				if _since() > 1.5:
					_next("both drove: P1 x %d, P2 x %d" % [int(a.global_position.x), int(b.global_position.x)])
		2:
			_hold(P1, Vector2(0, 1), true)
			_hold(P2, Vector2(0, 1), true)
			if _since() > 2.0:
				_next("both dug down: bags %d / %d" % [a.backpack_count(), b.backpack_count()])
		3:
			_hold(P1, Vector2(-1, 0), true)
			_hold(P2, Vector2(1, 0), true)
			if _since() > 2.0:
				_next("both dug sideways: bags %d / %d" % [a.backpack_count(), b.backpack_count()])
		4:
			_hold(P2, Vector2(1, 0), true)
			_intent[P1]["horn"] = true
			if _since() > 1.0:
				_next("P1 honked, P2 dug on (drivers %s)" % [game.drivers])
		5:
			if _since() > 2.0:
				_next("done")
