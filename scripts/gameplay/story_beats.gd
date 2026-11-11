## --demo --demo-beat=<name> for the Story lane's cutscenes (HillStory / CutscenePlayer). Each sets
## the stage directly, then the real cutscene plays.
##   intro         the new-save intro: Mayor Pip, the deed, the mineshaft warning, Foreman Dot and
##                 the Front Loader
##   hints         P1 digging in Topsoil: the wobbling tile, the dirt trail, the shovel shadow
##   theft         the Mole sneaks in and takes the shovel; P1 tries to dig with empty hands; fade,
##                 P1 wakes up top by the shaft and he hands the shovel back
##   unlock        a Garage rolls out the Dump Truck; Foreman Dot shows it off
##   arrive_scene  the Mole has come up: his arrival scene at the shaft
##   movein_scene  the Old Shed is rebuilt: the Mole moves into the Lost & Found
##   crew_scene    the Gnome Room opens: the crew's scene
##   dragon_scene  the Dragon's first meeting, as a scene
extends HillBeatRunner

const STORY_BEATS := ["intro", "hints", "theft", "unlock", "arrive_scene", "movein_scene", "crew_scene", "dragon_scene"]


func _hs() -> HillStory:
	return game.story_scenes


func _physics_process(delta: float) -> void:
	super(delta)
	if game.player_node(P1) == null or t < START or _hs() == null:
		return
	match beat:
		"intro": _intro()
		"hints": _hints()
		"theft": _theft()
		"unlock": _unlock()
		"arrive_scene": _arrive()
		"movein_scene": _movein()
		"crew_scene": _crew()
		"dragon_scene": _dragon()


func _watch() -> void:
	if not _hs().player.beat.is_connected(_on_beat):
		_hs().player.beat.connect(_on_beat)


func _on_beat(kind: String, detail: String) -> void:
	if kind in ["start", "end", "skip", "line", "call", "fade", "item", "bubble"]:
		log_event("cutscene %s %s" % [kind, detail])


func _topsoil() -> void:
	_stage_players(Rect2i(56, 14, 4, 2), Vector2i(58, 15), Vector2i(56, 15))
	game.player_node(P1).facing = 1


func _intro() -> void:
	match _stage:
		0:
			_watch()
			_hs().play_now(&"intro")
			_next("intro starts")
		1:
			if not _hs().is_playing():
				_next("intro done")


func _hints() -> void:
	match _stage:
		0:
			_topsoil()
			_next("stage: P1 in Topsoil")
		1:
			if _since() > 0.6:
				_hs().mole.show_hint(0, game.player_node(P1))
				_next("hint: wobble")
		2:
			if _since() > 3.0:
				_hs().mole.show_hint(1, game.player_node(P1))
				_next("hint: trail")
		3:
			if _since() > 3.0:
				_hs().mole.show_hint(2, game.player_node(P1))
				_next("hint: shadow")
		4:
			if _since() > 3.0:
				_next("hints done")


func _theft() -> void:
	match _stage:
		0:
			_topsoil()
			_watch()
			_next("stage: P1 in Topsoil")
		1:
			if _since() > 0.5 and _hs().start_theft(P1):
				_next("theft starts")
		2:
			if not _hs().is_playing():
				_next("no shovel: P1 tries to dig")
		3:
			_hold(P1, Vector2(1, 0), true)
			if _hs().is_playing():
				_next("return starts")
		4:
			if not _hs().is_playing():
				_next("shovel back (has_shovel %s, mole met %d)" % [game.player_node(P1).has_shovel, game.story.state(Story.MOLE).encounters])


func _unlock() -> void:
	match _stage:
		0:
			_hs().auto = true
			_watch()
			var x: float = game.player_node(P1).global_position.x
			game.hillville.vehicle_rolls_out.emit(&"dump_truck", Vector2(x + 140.0, 0.0))
			_next("garage rolls out the Dump Truck")
		1:
			if _since() > 1.0 and not _hs().is_playing():
				_next("unlock done")


func _arrive() -> void:
	match _stage:
		0:
			_hs().auto = true
			_watch()
			var s: ResidentState = game.story.state(Story.MOLE)
			s.encounters = s.encounters_to_arrive
			s.phase = ResidentState.Phase.ARRIVED
			game.story.changed.emit()
			Events.resident_arrived.emit(Story.MOLE)
			_next("the Mole arrives")
		1:
			if _since() > 1.0 and not _hs().is_playing():
				_next("arrive done")


func _movein() -> void:
	match _stage:
		0:
			_hs().auto = true
			_watch()
			var s: ResidentState = game.story.state(Story.MOLE)
			s.encounters = s.encounters_to_arrive
			s.phase = ResidentState.Phase.ARRIVED
			game.story.changed.emit()
			game.place_player(P1, HillGame.HILLVILLE, game.ruins.door_of(Story.MOLE) + Vector2(60, 0))
			_next("stage: P1 at the Old Shed")
		1:
			if _since() > 0.5:
				game.ruins.play_restore(Story.MOLE)
				game.story.restore(Story.MOLE)
				game.town.on_restored(Story.MOLE)
				_next("restore")
		2:
			if _since() > 2.0 and not _hs().is_playing():
				_next("move-in done")


func _crew() -> void:
	match _stage:
		0:
			_hs().auto = true
			_watch()
			_topsoil()
			_next("stage")
		1:
			if _since() > 0.5:
				_ug().residents.free_crew()
				_next("crew freed")
		2:
			if _since() > 1.0 and not _hs().is_playing():
				_next("crew scene done")


func _dragon() -> void:
	match _stage:
		0:
			_hs().auto = true
			_watch()
			_topsoil()
			_next("stage")
		1:
			if _since() > 0.5:
				_ug().residents.reveal()
				_next("dragon reveal")
		2:
			if _since() > 1.0 and not _hs().is_playing():
				_next("dragon scene done")
