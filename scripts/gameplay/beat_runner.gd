## --demo --demo-beat=<name>: a short scripted showcase of one hazard or resident moment, for
## screenshots and the playtest briefing. HillGame adds it instead of HillDemoRunner. Unlike the
## full --demo it sets the stage directly (places both players, carves a little room, and for
## "cheer" fills P1's backpack), then lets the real systems play the moment out: the boulder
## really falls, the pocket really gushes, the Mole really digs, the elevator really dumps.
## Every beat prints "beat: <t> <event>" lines so shot times can be picked.
##   bonk    a Topsoil boulder drops on P1's head: stars, a short stun, carry on.
##   float   P1 digs from the Clay landing into the big water pocket: gush, float up.
##   rescue  P1 digs into a Topsoil cave-in zone: rumble, trapped, the Mole digs them out.
##   cheer   P1 rides up with a full backpack: the crew cheers, the Foreman shows the build book;
##           then a Barn goes up beside them and the crew marches past it.
##   thaw    P1 stands by the Caveman's ice with the headlamp: drips, crack, laugh, off he goes;
##           then up top he waits by his fire.
##   reveal  P1 walks into the Bottom cavern: the Dragon yawns smoke rings and goes back to sleep.
##   crystal P1 stands in the Crystal layer (the darkness check with headlamps).
class_name HillBeatRunner
extends Node

const P1 := 0
const P2 := 1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const BEATS := ["bonk", "float", "rescue", "cheer", "thaw", "reveal", "crystal"]
## Seconds after the game starts before the stage is set (the wipe card clears).
const START := 1.0

var game: Node
var beat := ""
var t := 0.0
var _stage := 0
var _at := 0.0
var _intent := {P1: IDLE.duplicate(), P2: IDLE.duplicate()}


static func beat_arg(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--demo-beat="):
			return a.trim_prefix("--demo-beat=")
	return ""


func _ready() -> void:
	name = "BeatRunner"
	log_event("start %s" % beat)


func log_event(what: String) -> void:
	# The shot clock (Debug's --shots time) too, so screenshot times can be picked.
	print("beat: %6.2f (shot %5.2f) %s" % [t, float(Debug.get("_clock")), what])


func _intent_for(p: int) -> Dictionary:
	return _intent.get(p, IDLE)


func _physics_process(delta: float) -> void:
	t += delta
	for p in [P1, P2]:
		var node: HillPlayer = game.player_node(p)
		if node != null and (not node.intent_source.is_valid() or node.intent_source.get_object() is Hazards):
			node.intent_source = _intent_for.bind(p)
		_intent[p] = IDLE.duplicate()
	if game.player_node(P1) == null or t < START:
		return
	match beat:
		"bonk": _bonk()
		"float": _float()
		"rescue": _rescue()
		"cheer": _cheer()
		"thaw": _thaw()
		"reveal": _reveal()
		"crystal": _crystal()


func _next(what: String) -> void:
	_stage += 1
	_at = t
	log_event(what)


func _since() -> float:
	return t - _at


func _ug() -> Underground:
	return game.underground


func _hold(p: int, move: Vector2, dig := false) -> void:
	_intent[p] = {"move": move, "dig": dig, "jump": false, "book": false, "horn": false}


## Carves an air room (cells) and puts P1's feet on its floor at `p1_cell`, P2 at `p2_cell`.
func _stage_players(room: Rect2i, p1_cell: Vector2i, p2_cell: Vector2i) -> void:
	var w := _ug().world
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.set_tile(Vector2i(x, y), 0)
	_place(P1, Vector2((p1_cell.x + 0.5) * 16.0, (p1_cell.y + 1) * 16.0 - 1.0))
	_place(P2, Vector2((p2_cell.x + 0.5) * 16.0, (p2_cell.y + 1) * 16.0 - 1.0))


func _place(p: int, feet: Vector2) -> void:
	if game.player_node(p) == null:
		return
	game.place_player(p, HillGame.UNDERGROUND, feet)
	var node: HillPlayer = game.player_node(p)
	node.velocity = Vector2.ZERO


func _layer(id: StringName) -> int:
	var ls := _ug().layers()
	for i in ls.size():
		if (ls[i] as LayerData).id == id:
			return i
	return 0


# --- bonk --------------------------------------------------------------------------------------

func _bonk() -> void:
	var u := _ug()
	match _stage:
		0:
			# The shallowest boulder; a shaft under its cavity, P1 at the bottom looking up.
			# The Topsoil boulder nearest the shaft (the one met first).
			var best := 0
			var bd := 1 << 20
			for i in u.generator.boulder_spots.size():
				var r: Rect2i = u.generator.boulder_spots[i]
				if r.position.y < 30 and _near_shaft(r) < bd:
					bd = _near_shaft(r)
					best = i
			var r: Rect2i = u.generator.boulder_spots[best]
			var room := Rect2i(r.position.x - 3, r.end.y, 6, 5)
			_stage_players(room, Vector2i(r.position.x + 1, room.end.y - 1), Vector2i(room.position.x, room.end.y - 1))
			u.hazards.bonked.connect(func(p: int) -> void: log_event("bonk P%d" % (p + 1)), CONNECT_ONE_SHOT)
			_next("stage: boulder %d over P1" % best)
		1:
			if _since() > 2.6:
				_next("walk off")
		2:
			_hold(P1, Vector2(-1, 0))
			if _since() > 1.5:
				_next("done")


# --- float -------------------------------------------------------------------------------------

func _float() -> void:
	var u := _ug()
	match _stage:
		0:
			var pocket := u.generator.pocket
			var row := pocket.end.y - 1
			# A tunnel from the pocket's left wall, one cell short of breaking in.
			var room := Rect2i(pocket.position.x - 7, row - 1, 6, 2)
			_stage_players(room, Vector2i(pocket.position.x - 2, row), Vector2i(room.position.x, row))
			_next("stage: tunnel to the pocket")
		1:
			_hold(P1, Vector2(1, 0), true)
			if u.is_gushing():
				_next("gush")
		2:
			_hold(P1, Vector2(-0.3, 0))
			if _since() > 5.0:
				_next("done")


# --- rescue ------------------------------------------------------------------------------------

func _rescue() -> void:
	var u := _ug()
	match _stage:
		0:
			var z := 0
			for i in u.generator.cave_ins.size():
				if u.generator.cave_ins[i].layer < u.generator.cave_ins[z].layer or \
						(u.generator.cave_ins[i].layer == u.generator.cave_ins[z].layer and _near_shaft(u.generator.cave_ins[i].rect) < _near_shaft(u.generator.cave_ins[z].rect)):
					z = i
			var r: Rect2i = u.generator.cave_ins[z].rect
			# A room left of the zone, its floor on the zone's bottom row; P1 beside the zone.
			var floor_y := r.end.y - 2
			var room := Rect2i(r.position.x - 6, floor_y - 1, 6, 2)
			_stage_players(room, Vector2i(r.position.x - 1, floor_y), Vector2i(room.position.x, floor_y))
			u.hazards.trapped.connect(func(p: int, _r: Rect2i) -> void: log_event("trapped P%d" % (p + 1)), CONNECT_ONE_SHOT)
			u.hazards.freed.connect(func(p: int, m: bool) -> void: log_event("freed P%d by mole=%s" % [p + 1, m]), CONNECT_ONE_SHOT)
			_next("stage: cave-in zone %d" % z)
		1:
			_hold(P1, Vector2(1, 0), true)
			if u.hazards.is_trapped(P1):
				_next("trapped")
		2:
			if not u.hazards.is_trapped(P1) and _since() > 2.5:
				_next("walk out")
		3:
			_hold(P1, Vector2(-1, 0))
			if _since() > 1.5:
				_next("done")


func _near_shaft(r: Rect2i) -> int:
	return absi(r.position.x - HillGenerator.SHAFT_X)


# --- cheer -------------------------------------------------------------------------------------

func _cheer() -> void:
	var u := _ug()
	match _stage:
		0:
			# P1 in the Topsoil cage with a full backpack; P2 waits up top by the crew.
			var cage := u.cage_rect(0)
			_place(P1, Vector2(cage.get_center().x, cage.end.y - 5.0))
			var node: HillPlayer = game.player_node(P1)
			for i in node.capacity():
				node.keep_block(&"dirt" if i % 3 else &"clay")
			if game.player_node(P2) != null:
				game.place_player(P2, HillGame.HILLVILLE, Vector2(TownResidents.CREW_X + 150.0, 0))
			game.town.cheered.connect(func() -> void: log_event("crew cheers"), CONNECT_ONE_SHOT)
			_next("stage: P1 rides up with a full backpack")
		1:
			if game.director.scene_of(P1) == HillGame.HILLVILLE and _since() > 3.5:
				# A Barn in the yard right of the crew: they march past it.
				var cell := Vector2i(int(TownResidents.CREW_X / 48.0) + 3, 0)
				Progress.add_building(&"barn", cell)
				game.build.rebuild()
				Audio.play("build_place")
				_next("barn placed at %d" % cell.x)
		2:
			if _since() > 9.0:
				_next("done")


# --- thaw --------------------------------------------------------------------------------------

func _thaw() -> void:
	var u := _ug()
	match _stage:
		0:
			var ice := _layer(&"ice")
			var at := u.landing(ice)
			_place(P1, at + Vector2(40, 0))
			_place(P2, at + Vector2(-40, 0))
			u.residents.caveman_thawed.connect(func() -> void: log_event("thawed"), CONNECT_ONE_SHOT)
			_next("stage: P1 beside the ice block")
		1:
			if u.residents.caveman_state() == &"gone" or _since() > 9.0:
				_next("caveman gone up")
		2:
			if _since() > 1.0:
				game.place_player(P1, HillGame.HILLVILLE, Vector2(TownResidents.FIRE_X - 140.0, 0))
				game.place_player(P2, HillGame.HILLVILLE, Vector2(TownResidents.FIRE_X - 190.0, 0))
				_next("up top: the Caveman by his fire")
		3:
			_hold(P1, Vector2(0.5, 0))
			if _since() > 1.2:
				_next("done")


# --- reveal ------------------------------------------------------------------------------------

func _reveal() -> void:
	var u := _ug()
	match _stage:
		0:
			var d: Node2D = u.residents.dragon
			var feet_y := HillGenerator.CAVERN.end.y * 16.0 - 2.0
			_place(P1, Vector2(d.position.x - UndergroundResidents.REVEAL_NEAR - 60.0, feet_y))
			_place(P2, Vector2(d.position.x - UndergroundResidents.REVEAL_NEAR - 110.0, feet_y))
			u.residents.dragon_revealed.connect(func() -> void: log_event("reveal"), CONNECT_ONE_SHOT)
			_next("stage: the Bottom cavern")
		1:
			_hold(P1, Vector2(1, 0))
			_hold(P2, Vector2(1, 0))
			if u.residents.dragon_state() == &"waking":
				_next("dragon wakes")
		2:
			if u.residents.dragon_state() == &"asleep":
				_next("back to sleep")
		3:
			if _since() > 2.0:
				_next("done")


# --- crystal -----------------------------------------------------------------------------------

func _crystal() -> void:
	var u := _ug()
	if _stage == 0:
		var li := _layer(&"crystal")
		var at := u.landing(li)
		_place(P1, at + Vector2(-30, 0))
		_place(P2, at + Vector2(-70, 0))
		_next("stage: Crystal landing")
	elif _stage == 1 and _since() > 3.0:
		_next("done")
