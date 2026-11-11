## --demo --demo-beat=<name> for the town adjacency lane (C-23). Sets the stage, then the real build
## controller and TownAdjacency play it out.
##   adjacency  A Barn stands in the yard; P1 picks a House: the ghost previews soft hearts to the
##              Barn (the Barn hops, a ping), P1 drops it: sparkle burst, big heart pop, both hop,
##              the chime, and flowers grow between them while hearts float back and forth.
##   pond       P1 by the pond with a Water Tower ghost: hearts reach to the pond; drop, hearts.
##   heart_row  A row of happy pairs in the yard (Barn + House, Garage + Workshop, Workshop + the
##              shaft): hearts over every roof, flowers between.
## hill_game loads this by path, like GapBeats.
extends GapBeats

const ADJACENCY_BEATS := ["adjacency", "pond", "heart_row"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"adjacency": _adjacency()
		"pond": _pond()
		"heart_row": _town()


func _clear_scrub() -> void:
	var hv: Hillville = game.hillville
	hv.load_save({"seed": hv.layout_seed, "left": "0".repeat(Hillville.COLS)})


func _loader_away(x: float) -> void:
	var loader: Node2D = game.vehicles.get(HillGame.LOADER)
	if loader != null:
		loader.position.x = x


func _adj() -> TownAdjacency:
	return game.get("adjacency") as TownAdjacency


func _adjacency() -> void:
	match _stage:
		0:
			_loader_away(Hillville.SHAFT_X + 520.0)
			Progress.add_building(&"barn", Vector2i(32, 0))
			game.build.rebuild()
			Inventory.add(&"dirt", 20)
			Inventory.add(&"clay", 10)
			_yard(P1, 35 * 48 - 60, 1)
			if game.player_node(P2) != null:
				_yard(P2, 31 * 48, 1)
			_next("stage: a Barn in the yard, P1 beside it")
		1:
			if _since() > 1.2:
				game.build._pick(P1, &"house")
				_next("house ghost: preview hearts reach to the Barn")
		2:
			if _since() > 2.5:
				game.build._drop(P1)
				_next("house dropped (pairs %d)" % _adj().pairs.size())
		3:
			if _since() > 1.0:
				_next("celebrated %d (sparkles, heart pop, flowers growing)" % _adj().celebrations)
		4:
			if _since() > 3.0:
				_next("done: hearts float, flowers stand")


func _pond() -> void:
	match _stage:
		0:
			_clear_scrub()
			_loader_away(Hillville.SHAFT_X + 520.0)
			Inventory.add(&"stone", 20)
			Inventory.add(&"ice", 10)
			_yard(P1, 110 * 48 + 20, 1)
			_next("stage: P1 by the pond")
		1:
			if _since() > 1.2:
				game.build._pick(P1, &"water_tower")
				_next("water tower ghost: preview hearts reach to the pond")
		2:
			if _since() > 2.5:
				game.build._drop(P1)
				_next("water tower dropped")
		3:
			if _since() > 3.5:
				_next("done (celebrated %d)" % _adj().celebrations)


func _town() -> void:
	match _stage:
		0:
			_loader_away(Hillville.SHAFT_X + 700.0)
			for b in [[&"barn", 25], [&"house", 28], [&"garage", 31], [&"workshop", 35]]:
				Progress.add_building(b[0], Vector2i(b[1], 0))
			game.build.rebuild()
			_clear_scrub()
			_yard(P1, 30 * 48, 1)
			if game.player_node(P2) != null:
				_yard(P2, 33 * 48, -1)
			_next("stage: Barn+House, Workshop by the shaft and the Garage")
		1:
			if _since() > 3.0:
				_next("pairs %d" % _adj().pairs.size())
		2:
			if _since() > 2.0:
				_next("done")
