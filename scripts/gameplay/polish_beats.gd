## --demo --demo-beat=<name> for the polish lane (2026-11-10). Like the other beat runners it sets
## the stage directly, then the real systems play it out (the real build book pick and drop, the
## real dig, the real Dragon tick).
##   lighthouse  P2 stands at the Stone landing in the dark; up top P1 builds a Lighthouse: its
##               lamp flares and shines down, and Stone fades from dark to lit with a lantern and a
##               sweeping beam at its landing. Add --time=0.8 for the night sweep up top.
##   cows        Four Barns stand by the shaft, a cow wandering each; P1 builds a fifth and its
##               cow trots out with a hop and a heart; then P1 walks into a cow (hop, heart).
##   strange     P1 stands on Strangestone at the floor of the Bottom cavern and digs down: the
##               shovel bounces, sparkles ring the tile and a "?" bubble pops over P1's head.
##   scoop       P1 in the Excavator scoops a wide patch of scrub: the view thumps a little.
##   snore       P1 stands in the cavern (out of her first-meeting reach) while she sleeps: smoke
##               puffs and the view sways gently with each snore.
##   spin        P1 in the Excavator honks: it turns all the way round (H-03), twice.
class_name PolishBeats
extends ArcBeats

const POLISH_BEATS := ["lighthouse", "cows", "strange", "scoop", "snore", "spin"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"lighthouse": _lighthouse()
		"cows": _cows()
		"strange": _strange()
		"scoop": _scoop()
		"snore": _snore()
		"spin": _spin()


func _yard(p: int, x: float, facing := 1) -> void:
	if game.player_node(p) == null:
		return
	game.place_player(p, HillGame.HILLVILLE, Vector2(x, 0))
	game.player_node(p).facing = facing


func _lighthouse() -> void:
	match _stage:
		0:
			if not Progress.has_vehicle(&"crane"):
				Progress.vehicles.append(&"crane")
			Inventory.add(&"stone", 20)
			Inventory.add(&"crystal", 5)
			_yard(P1, 34 * 48 + 10)
			var li := _layer(&"stone")
			if game.player_node(P2) != null:
				_place(P2, _ug().landing(li) + Vector2(-60, 0))
			_next("stage: P2 in dark Stone, P1 in the yard with stone and crystal")
		1:
			if _since() > 2.5:
				game.build._pick(P1, &"lighthouse")
				_next("ghost")
		2:
			if _since() > 0.8:
				game.build._drop(P1)
				_next("lighthouse placed (flare; Stone fades in)")
		3:
			if _since() > 2.0:
				_next("Stone lit (%.2f)" % _ug().look.lit_amount(_layer(&"stone")))
		4:
			if _since() > 3.0:
				_next("done")


func _cows() -> void:
	match _stage:
		0:
			for c in [32, 37, 43, 45]:
				Progress.add_building(&"barn", Vector2i(c, 0))
			var loader: Vehicle = game.vehicles.get(HillGame.LOADER)
			if loader != null:
				loader.position.x = Hillville.SHAFT_X + 520.0   # out of the yard
			game.build.rebuild()
			Inventory.add(&"dirt", 10)
			_yard(P1, 34 * 48 + 10)
			if game.player_node(P2) != null:
				_yard(P2, 30 * 48 + 20)
			_next("stage: four barns, four cows")
		1:
			if _since() > 2.0:
				game.build._pick(P1, &"barn")
				_next("ghost")
		2:
			if _since() > 0.8:
				game.build._drop(P1)
				_next("barn 5 placed: cow %d trots out" % game.cows.cow_count())
		3:
			if _since() > 2.5:
				_next("walk into a cow")
		4:
			var c: Dictionary = game.cows.cows[0]
			var node: HillPlayer = game.player_node(P1)
			_hold(P1, Vector2(signf(c.x - node.position.x), 0))
			if absf(c.x - node.position.x) < 12.0:
				_next("bumped a cow")
		5:
			if _since() > 2.0:
				_next("done")


func _strange() -> void:
	var u := _ug()
	match _stage:
		0:
			# The first Strangestone row under the cavern floor, near the middle.
			var w := u.world
			var x := int(HillGenerator.CAVERN.get_center().x)
			var y := HillGenerator.CAVERN.end.y
			while y < Underground.HEIGHT + 4 and w.get_tile(Vector2i(x, y)) != u.generator.strange_tile:
				y += 1
			_stage_players(Rect2i(x - 3, y - 4, 7, 4), Vector2i(x, y - 1), Vector2i(x - 3, y - 1))
			_next("stage: on Strangestone at row %d" % y)
		1:
			if _since() > 1.0:
				_next("dig down")
		2:
			_hold(P1, Vector2(0, 1), true)
			if u.strange.showing(P1):
				_next("? bubble")
		3:
			if _since() > 3.0:
				_next("done")


func _scoop() -> void:
	match _stage:
		0:
			_ride(P1, &"excavator", HillGame.HILLVILLE, Vector2(30 * 48, 0))
			game.player_node(P1).facing = -1
			if game.player_node(P2) != null:
				_yard(P2, 35 * 48)
			_next("stage: Excavator at the scrub edge")
		1:
			if _since() > 1.5:
				_hold(P1, Vector2.ZERO, true)
				_next("scoop")
		2:
			if game.kick.active(P1):
				_next("kick")
			elif _since() > 1.0:
				_hold(P1, Vector2.ZERO, true)
				_at = t
		3:
			if _since() > 2.0:
				_next("done")


func _snore() -> void:
	var u := _ug()
	match _stage:
		0:
			# Not met yet and out of her reveal reach, so she just sleeps and snores.
			var dr: Node2D = u.residents.dragon
			var feet_y := HillGenerator.CAVERN.end.y * 16.0 - 2.0
			_place(P1, Vector2(dr.position.x - UndergroundResidents.REVEAL_NEAR - 40.0, feet_y))
			_place(P2, Vector2(dr.position.x - UndergroundResidents.REVEAL_NEAR - 90.0, feet_y))
			u.residents.dragon_snored.connect(func(k: float) -> void: log_event("snore %.2f" % k))
			_next("stage: in the cavern by the sleeping Dragon")
		1:
			if _since() > 12.0:
				_next("done")


func _spin() -> void:
	match _stage:
		0:
			_ride(P1, &"excavator", HillGame.HILLVILLE, Vector2(35 * 48, 0))
			if game.player_node(P2) != null:
				_yard(P2, 33 * 48)
			_next("stage: P1 in the Excavator in the yard")
		1, 2:
			if _since() > 1.5:
				game.player_node(P1).honk()
				_next("honk: cab spins")
		3:
			if _since() > 1.5:
				_next("done")
