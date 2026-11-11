## --demo --demo-beat=<name> for the gap-close lane (2026-11-10). Like the other beat runners it sets
## the stage directly, then the real systems play it out (the real build book, the real dig).
##   workshop  P1 in the yard with 15 stone picks the Workshop in the book and drops it: it unfolds,
##             a big gold shovel pops over P1's head (and P2's), then the hammer strikes the anvil
##             with sparks and clangs while P1 stands near, and the chimney puffs.
##   shovel    A Workshop stands; P1 at the Topsoil landing digs sideways, then down: each bite is two
##             cells deep with a gold glint, and quicker than before.
##   house     Night; a House stands by the yard and P2 is out of the game: P2's sleepy Zs drift out of
##             the House's attic window (not the Loader's bucket); then P2 wakes and hops out of the
##             House door with a puff (B-03).
##   exhaust   P1 drives the Front Loader along the yard and stops: puffs from the exhaust while it
##             idles and rolls (H-11).
## hill_game loads this by path (a class reference from hill_game made a parse cycle for other lanes).
class_name GapBeats
extends HazardBeats

const GAP_BEATS := ["workshop", "shovel", "exhaust", "house"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"workshop": _workshop()
		"shovel": _shovel()
		"exhaust": _exhaust()
		"house": _house()


func _workshop() -> void:
	match _stage:
		0:
			var loader: Node2D = game.vehicles.get(HillGame.LOADER)
			if loader != null:
				loader.position.x = Hillville.SHAFT_X + 520.0   # out of the yard
			Inventory.add(&"stone", 15)
			_yard(P1, 34 * 48 + 10)
			if game.player_node(P2) != null:
				_yard(P2, 33 * 48, -1)
			_next("stage: P1 in the yard with 15 stone")
		1:
			if _since() > 1.5:
				game.build._pick(P1, &"workshop")
				_next("ghost")
		2:
			if _since() > 0.8:
				game.build._drop(P1)
				_next("workshop placed (unfold, shovel pops over the heads)")
		3:
			if _since() > 2.5:
				_next("hammering (sparks, clang while P1 is near)")
		4:
			if _since() > 4.0:
				_next("done")


func _shovel() -> void:
	match _stage:
		0:
			if Progress.count_buildings(&"workshop") == 0:
				Progress.add_building(&"workshop", Vector2i(40, 0))
			var li := _layer(&"dirt") if _layer(&"dirt") > 0 else 0
			_place(P1, _ug().landing(li) + Vector2(-24, 0))
			_next("stage: P1 at the Topsoil landing, a Workshop up top")
		1:
			_hold(P1, Vector2.LEFT, true)
			if _since() > 2.5:
				_next("dug sideways (two cells a bite, glint)")
		2:
			_hold(P1, Vector2.DOWN, true)
			if _since() > 1.5:
				_next("dug down")
		3:
			if _since() > 2.0:
				_next("done")


func _exhaust() -> void:
	match _stage:
		0:
			var loader: Node2D = game.vehicles.get(HillGame.LOADER)
			_yard(P1, (loader.position.x if loader != null else Hillville.SHAFT_X + 200.0) - 30.0)
			_next("stage: P1 by the Loader")
		1:
			if _since() > 0.5:
				game.player_node(P1).call("_on_b", game.build)
				_next("hopped in")
		2:
			_hold(P1, Vector2.RIGHT)
			if _since() > 2.0:
				_next("drove (puffs trail)")
		3:
			if _since() > 3.0:
				_next("idle puffs; done")


func _house() -> void:
	match _stage:
		0:
			Progress.add_building(&"house", Vector2i(36, 0))
			game.build.rebuild()
			TimeOfDay.set_time(0.8)
			TimeOfDay.frozen = true
			Players._device_of[P2] = -1        # P2 has not joined yet (else the game wakes them at once)
			if game.player_node(P2) != null:
				game.despawn(P2)
			var loader: Node2D = game.vehicles.get(HillGame.LOADER)
			if loader != null:
				loader.position.x = 31 * 48.0       # parked by P1, clear of the House door
			_yard(P1, 33 * 48, 1)
			_next("stage: night, a House, P2 asleep")
		1:
			if _since() > 4.0:
				Players.join_virtual(P2)          # a press: the game wakes P2 (HillGame._physics_process)
				_next("P2 joins: out of the House door")
		2:
			if _since() > 2.0:
				_next("done")
