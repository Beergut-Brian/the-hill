## --demo --demo-beat=<name> for the residents' arcs up top (the Arrival and Fix-up beats and the
## town life). Like HillBeatRunner it sets the stage directly (the Story phases, the pile, where P1
## stands), then the real systems play it: the real build book, the real restore, the real gags.
##   arrive          Mole, Foreman and Caveman are waiting at the shaft; P1 walks up: each shows in
##                   pictures what they did (sheepish) and then their ruin (hopeful).
##   restore_mole    At the Old Shed: the book opens on its restore card, A pays, it rebuilds plank
##                   by plank into the Lost & Found, the Mole tunnels in, a light comes on; then a
##                   found bundle appears at the door and P1 picks it up.
##   restore_gnomes  At the Crooked Watchtower: restored into the Gnome Village, the Foreman moves
##                   in and inspects a barn; then the overnight crew's pile marches out at the shaft.
##   restore_caveman At the Flooded Cabin: restored into the Museum, the shelf moves onto its dock,
##                   he polishes; full boards get a star.
##   restore_dragon  At the Ruined Keep: she pleads, then it rebuilds into the Dragon Perch and she
##                   flies up onto it.
##   town            Everyone moved in: the Mole pops up in the pond, honks a parked vehicle; the
##                   Caveman is baffled by the Dump Truck.
class_name ArcBeats
extends HillBeatRunner

const ARC_BEATS := ["arrive", "restore_mole", "restore_gnomes", "restore_caveman", "restore_dragon", "town"]


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"arrive": _arrive_beat()
		"restore_mole": _restore_beat(Story.MOLE)
		"restore_gnomes": _restore_beat(Story.FOREMAN)
		"restore_caveman": _restore_beat(Story.CAVEMAN)
		"restore_dragon": _restore_beat(Story.DRAGON)
		"town": _town_beat()


func _story() -> Story:
	return game.story


## Puts a resident straight into `phase` (as if their encounters had happened).
func set_phase(id: StringName, phase: ResidentState.Phase) -> void:
	var s := _story().state(id)
	s.encounters = s.encounters_to_arrive
	s.phase = phase
	_story().changed.emit()


func _up(p: int, x: float) -> void:
	if game.player_node(p) != null:
		game.place_player(p, HillGame.HILLVILLE, Vector2(x, 0))


# --- arrive ------------------------------------------------------------------------------------

func _arrive_beat() -> void:
	match _stage:
		0:
			for id in [Story.MOLE, Story.FOREMAN, Story.CAVEMAN]:
				set_phase(id, ResidentState.Phase.ARRIVED)
			_up(P1, Hillville.SHAFT_X - 330.0)
			_up(P2, Hillville.SHAFT_X - 380.0)
			_next("stage: three residents waiting at the shaft")
		1:
			_hold(P1, Vector2(1, 0))
			if not game.town.saying(Story.MOLE).is_empty():
				_next("the Mole: shovel + sheepish")
		2:
			if _since() > TownResidents.TALK_PART:
				_next("the Mole: Old Shed + hopeful")
		3:
			_hold(P1, Vector2(1, 0))
			if not game.town.saying(Story.FOREMAN).is_empty():
				_next("the Foreman: wall + sheepish")
		4:
			_hold(P1, Vector2(1, 0))
			if not game.town.saying(Story.CAVEMAN).is_empty():
				_next("the Caveman: ice + sheepish")
		5:
			if _since() > TownResidents.TALK_PART + 0.4:
				_next("the Caveman: Flooded Cabin + hopeful")
		6:
			if _since() > 2.5:
				_next("done")


# --- restore -----------------------------------------------------------------------------------

func _restore_beat(id: StringName) -> void:
	var ruin: StringName = Story.RUIN_OF[id]
	var r: Rect2 = game.hillville.ruin_rect(ruin)
	match _stage:
		0:
			set_phase(id, ResidentState.Phase.ARRIVED)
			var cost: Dictionary = Progress.building_data(ruin).cost
			for b in cost:
				Inventory.add(StringName(str(b)), int(cost[b]) + 5)
			if id == Story.CAVEMAN:
				for tid in [&"buried_car", &"bottle_caps", &"boot", &"bike", &"bathtub", &"fossil", &"giant_tooth", &"pirate_chest"]:
					Progress.find_treasure(tid, P1)
			if id == Story.FOREMAN:
				Progress.add_building(&"barn", Vector2i(int(r.position.x / 48.0) + 5, 0))
				game.build.rebuild()
			TimeOfDay.set_time(0.62)   # dusk, so the light coming on shows
			# Stand left of the ruin, facing it.
			_up(P1, r.position.x - 40.0)
			_up(P2, r.position.x - 90.0)
			if id == Story.DRAGON:
				game.town._drag = {"mode": &"wait", "t": 0.0}
				game.town._place_dragon()
			_next("stage: %s waiting, pile can pay" % id)
		1:
			if id == Story.DRAGON and _since() < 0.2:
				_hold(P1, Vector2(1, 0))   # step up so she pleads
			if _since() > (3.2 if id == Story.DRAGON else 0.8):
				game.build.book_pressed(P1)
				_next("book open on the restore card: %s" % game.build.book_of(P1).focused_id())
		2:
			if _since() > 1.6:
				game.build.book_input(P1, Vector2.ZERO, true, false)
				_next("paid: rebuilding plank by plank")
		3:
			if not game.ruins.is_rebuilding(id):
				_next("rebuilt; %s moves in, light on" % id)
		4:
			if _since() > 2.6:
				_payoff(id)
				_next("payoff: %s" % id)
		5:
			if id == Story.MOLE:
				if _since() > 1.5:
					_hold(P1, Vector2(1, 0))
				if not game.ruins.has_bundle():
					_next("picked up the found bundle")
			elif _since() > 3.5:
				_next("payoff shown")
		6:
			if _since() > 2.0:
				_next("done")


func _payoff(id: StringName) -> void:
	match id:
		Story.MOLE:
			game.ruins.leave_bundle()
			_up(P1, game.ruins.door_of(Story.MOLE).x - 150.0)
		Story.FOREMAN:
			_up(P1, Hillville.SHAFT_X + 40.0)
			game.ruins.crew_return(8.0 * 3600.0)
		Story.CAVEMAN:
			_up(P1, game.shelf.position.x - 130.0)
		Story.DRAGON:
			pass


# --- town --------------------------------------------------------------------------------------

func _town_beat() -> void:
	var town: TownResidents = game.town
	match _stage:
		0:
			for id in [Story.MOLE, Story.FOREMAN, Story.CAVEMAN, Story.DRAGON]:
				set_phase(id, ResidentState.Phase.RESTORED)
			game.ruins.sync_story()
			town.sync_story()
			game.shelf.museum_at(game.ruins.home_rect(Story.CAVEMAN))
			town._mole.cd_pond = 0.0
			_up(P1, Hillville.POND.get_center().x - 120.0)
			_up(P2, Hillville.POND.get_center().x - 170.0)
			_next("stage: everyone home; P1 by the pond")
		1:
			if town.mole_mode() == &"pond" and _since() > 0.5:
				_next("the Mole pops up in the pond")
		2:
			if town.mole_mode() != &"pond" and town.mole_mode() != &"tunnel":
				# A parked Dump Truck right by the Caveman at the Museum.
				if not Progress.has_vehicle(&"dump_truck"):
					Progress.vehicles.append(&"dump_truck")
				game.park_new(&"dump_truck", town.caveman.position + Vector2(90, 0))
				_up(P1, town.caveman.position.x - 60.0)
				town._mole.cd_honk = 0.0
				_next("the Dump Truck parks by the Caveman")
		3:
			if town.caveman_mode() == &"baffled" and _since() > 0.6:
				_next("the Caveman is baffled")
		4:
			if town.mole_mode() == &"honk" and _since() > 0.3:
				_next("the Mole honks the truck")
			elif _since() > 12.0:
				_next("no honk (cooldown)")
		5:
			if _since() > 2.0:
				_next("done")
