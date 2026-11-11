## --demo --demo-beat=<name> for the loose things lane (2026-11-10, W-19 / W-20). Like the other
## beat runners it sets the stage (carves a room, places P1) and the real systems play it out.
##   drop       The dinosaur skeleton: the row under it is dug, it drops whole into the room below with a
##              little bounce, lands, sparkles and stays; P1 walks up and picks it up with A.
##   crumble    The Buried Car: the row under it is dug, it crumbles into picture chunks (a happy
##              crumble); the car is found (the Garage); P1 walks up and pops chunks into the bag.
##   mole_fall  The Mole's floor at home is dug out: he drops, bounces, puffs dust, waves at P1
##              and shuffles on from where he landed.
class_name LooseBeats
extends HazardBeats

const LOOSE_BEATS := ["drop", "crumble", "mole_fall"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"drop": _drop(&"dino_skeleton")
		"crumble": _drop(&"buried_car")
		"mole_fall": _mole_fall()


func _spot(id: StringName) -> Rect2i:
	for sp in _ug().generator.treasure_spots:
		if sp.id == id:
			return sp.rect
	return Rect2i()


## Both W-19 and W-20 the same way: a room two tall under the prop and to its left, P1 in it.
func _drop(id: StringName) -> void:
	var u := _ug()
	var r := _spot(id)
	match _stage:
		0:
			var room := Rect2i(r.position.x - 7, r.end.y + 1, r.size.x + 7, 2)
			_stage_players(room, Vector2i(room.position.x + 2, room.end.y - 1), Vector2i(room.position.x, room.end.y - 1))
			u.world.body_landed.connect(func(_b: Node2D, s: float) -> void: log_event("landed %.0f" % s))
			u.treasure_dug.connect(func(tid: StringName, _p: int) -> void: log_event("found %s" % tid))
			_next("stage: under %s %s" % [id, r])
		1:
			if _since() > 1.0:
				var cells: Array[Vector2i] = []
				for x in range(r.position.x, r.end.x):
					cells.append(Vector2i(x, r.end.y) - Vector2i(r.position.x, r.end.y))
				u.world.dig(Vector2i(r.position.x, r.end.y), cells, P1)
				_next("dug under: loose %s rubble %d" % [u.loose.keys(), u.rubble.size()])
		2:
			if _since() > 2.5:
				_next("walk up")
		3:
			var pl: HillPlayer = game.player_node(P1)
			var reach := (r.position.x - 1) * 16.0
			_hold(P1, Vector2(1, 0) if pl.global_position.x < reach else Vector2.ZERO, pl.global_position.x >= reach - 8.0)
			if not u.loose.has(id) and (Progress.has_treasure(id) and u.rubble.size() < r.size.x * r.size.y - 1 or _since() > 6.0):
				_next("picked up: bag %d rubble %d" % [pl.backpack_count(), u.rubble.size()])
		4:
			if _since() > 3.0:
				_next("done")


func _mole_fall() -> void:
	var u := _ug()
	var res := u.residents
	if res == null or res.mole == null:
		if _stage == 0:
			_next("no mole")
		return
	match _stage:
		0:
			var home := res.mole.position
			_place(P1, Vector2(home.x + 6.0 * 16.0, home.y - 1.0))
			_next("stage: P1 by the Mole at %s" % home)
		1:
			if _since() > 1.2:
				var col := int(floor(res.mole.position.x / 16.0))
				var row := int(floor((res.mole_floor + 2.0) / 16.0))
				for y in range(row, row + 3):
					for x in range(col - 2, col + 3):
						u.world.set_tile(Vector2i(x, y), 0)
				_next("floor dug out under the Mole")
		2:
			if res.mole_falls > 0 and not res._mole.get("falling", false):
				_next("landed at %.0f, waves" % res.mole_floor)
		3:
			if _since() > 4.0:
				_next("done")
