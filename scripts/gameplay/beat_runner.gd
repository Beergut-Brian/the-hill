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
##   garage  Up top with the Excavator owned: P1 builds a second Garage; the Dump Truck rolls out.
##   truck   P1 drives the Dump Truck with a full bed to the pile, reverses (beep), tips it all out.
##   crane   P1 in the Crane beside a Clay boulder: the hook drops, lifts it and hauls it out.
##   drill   P1 starts the Drill Rig in Topsoil: it drills 5 wide straight down on its own.
##   treasure P1 digs into the bottle caps by the Topsoil landing: the reveal pops them up and into
##           the bag; then up top they pop onto the Treasure Shelf.
##   book    Up top with two vehicles: the build book on the Garage card (its picture bubble shows
##           the Crane it gives next), then on the Water Tower (locked: a Crane bubble that bounces);
##           then with the Crane the Garage card shows the Drill Rig and the Giant Tooth it waits for.
##   shelf   Most treasures found, a Water Tower built: P1 walks up to the Treasure Shelf.
##   lineup  All five vehicles in a row up top, P1 in the Dump Truck, P2 in the Crane.
##   steal   P1 digs on foot in Topsoil: the Mole pops up, takes the shovel (sheepish bubble) and
##           gives it straight back while P1 keeps digging.
##   walled  P1 beside the Gnome Room (the crew's hats bob over a brick wall, a bubble), digs in:
##           the wall crumbles, the crew hops, whistles and marches off.
##   follow  The Caveman thaws and follows P1 down a tunnel and back to the shaft, then goes up.
##   wake    The Dragon (met once) wakes for good as P1 walks up: two picture bubbles, a purr, and
##           she goes up the shaft in three pieces.
##   visit   The Mole's Lost & Found stands: he visits P1 near the bottle caps, they glow gold, and
##           he leaves a little bundle of blocks.
class_name HillBeatRunner
extends Node

const P1 := 0
const P2 := 1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const BEATS := ["bonk", "float", "rescue", "cheer", "thaw", "reveal", "crystal", "garage", "truck", "crane", "drill", "treasure", "book", "shelf", "lineup", "steal", "walled", "follow", "wake", "visit"]
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
	# PT10-9: A rides the elevator now; scripted beats keep the old walk-in cage.
	if game != null and game.get("elevator") != null:
		game.elevator.walk_in = true
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
		"garage": _garage()
		"truck": _truck()
		"crane": _crane()
		"drill": _drill()
		"treasure": _treasure()
		"book": _book()
		"shelf": _shelf()
		"lineup": _lineup()
		"steal": _steal()
		"walled": _walled()
		"follow": _follow()
		"wake": _wake()
		"visit": _visit()


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


# --- vehicles and treasures ----------------------------------------------------------------------

## Unlocks `id` (if needed), parks it at `pos` in `scene` and puts player p in its seat.
func _ride(p: int, id: StringName, scene: StringName, pos: Vector2) -> HillPlayer:
	var node: HillPlayer = game.player_node(p)
	if node == null:
		return null
	if node.vehicle != null:
		game.hop_out(node, true)
	if not Progress.has_vehicle(id):
		Progress.vehicles.append(id)
	var v: Vehicle = game.vehicles.get(id)
	if v != null and v.is_inside_tree():
		v.get_parent().remove_child(v)
		game.vehicles.erase(id)
		v.queue_free()
	game.park_new(id, pos, scene)
	game.place_player(p, scene, pos)
	node.velocity = Vector2.ZERO
	game.hop_in(node)
	return node


func _garage() -> void:
	match _stage:
		0:
			Progress.find_treasure(&"buried_car", P1)
			Progress.add_building(&"garage", Vector2i(26, 0))
			if not Progress.has_vehicle(&"excavator"):
				Progress.vehicles.append(&"excavator")
			game.build.rebuild()
			Inventory.add(&"clay", 40)
			Inventory.add(&"stone", 20)
			game.place_player(P1, HillGame.HILLVILLE, Vector2(32 * 48 + 10, 0))
			game.player_node(P1).facing = 1
			if game.player_node(P2) != null:
				game.place_player(P2, HillGame.HILLVILLE, Vector2(31 * 48, 0))
			Events.vehicle_unlocked.connect(func(id: StringName) -> void: log_event("unlocked %s" % id), CONNECT_ONE_SHOT)
			_next("stage: yard, one Garage built, blocks for another")
		1:
			if _since() > 0.8:
				game.build._pick(P1, &"garage")
				_next("ghost")
		2:
			if _since() > 0.8:
				game.build._drop(P1)
				_next("garage 2 placed")
		3:
			if _since() > 4.5:
				_next("done")


func _truck() -> void:
	match _stage:
		0:
			var loader: Vehicle = game.vehicles.get(HillGame.LOADER)
			if loader != null:
				loader.position.x -= 360.0   # out of the truck's way
			var node := _ride(P1, &"dump_truck", HillGame.HILLVILLE, Vector2(Hillville.PILE_X - 300.0, 0))
			for i in node.capacity():
				node.backpack[[&"dirt", &"clay", &"stone"][i % 3]] = int(node.backpack.get([&"dirt", &"clay", &"stone"][i % 3], 0)) + 1
			node.facing = 1
			if game.player_node(P2) != null:
				game.place_player(P2, HillGame.HILLVILLE, Vector2(Hillville.PILE_X - 420.0, 0))
			node.ability.tipped.connect(func(n: int) -> void: log_event("tipped %d blocks" % n), CONNECT_ONE_SHOT)
			_next("stage: full truck, %d blocks" % node.backpack_count())
		1:
			_hold(P1, Vector2(1, 0))
			if game.player_node(P1).global_position.x > Hillville.PILE_X - 130.0:
				_next("at the pile")
		2:
			_hold(P1, Vector2(-1, 0))
			if _since() > 0.8:
				_next("reversed")
		3:
			_hold(P1, Vector2.ZERO, _since() < 0.2)
			if _since() > 3.0:
				_next("done")


func _crane() -> void:
	var u := _ug()
	match _stage:
		0:
			# The Clay boulder nearest the shaft; a room beside it, the Crane on the room's floor.
			var li := _layer(&"clay")
			var best := -1
			var bd := 1 << 20
			for i in u.generator.boulder_spots.size():
				var r: Rect2i = u.generator.boulder_spots[i]
				if u.generator.layer_of_depth(r.position.y) == li and _near_shaft(r) < bd:
					bd = _near_shaft(r)
					best = i
			var r: Rect2i = u.generator.boulder_spots[best]
			var room := Rect2i(r.position.x - 7, r.end.y - 4, 7, 4)
			var w := u.world
			for y in range(room.position.y, room.end.y):
				for x in range(room.position.x, room.end.x):
					w.set_tile(Vector2i(x, y), 0)
			var feet := Vector2((room.position.x + 3) * 16.0, room.end.y * 16.0 - 1.0)
			var node := _ride(P1, &"crane", HillGame.UNDERGROUND, feet)
			node.facing = 1
			_place(P2, feet + Vector2(-50, 0))
			node.ability.hauled.connect(func(i: int) -> void: log_event("hauled boulder %d" % i), CONNECT_ONE_SHOT)
			_next("stage: Crane beside boulder %d" % best)
		1:
			if _since() > 0.8:
				_hold(P1, Vector2.ZERO, true)
				_next("hook")
		2:
			if _since() > 3.0:
				_next("done")


func _drill() -> void:
	var u := _ug()
	match _stage:
		0:
			Progress.find_treasure(&"giant_tooth", P1)
			var room := Rect2i(60, 14, 8, 4)
			var w := u.world
			for y in range(room.position.y, room.end.y):
				for x in range(room.position.x, room.end.x):
					w.set_tile(Vector2i(x, y), 0)
			var feet := Vector2(64 * 16.0, room.end.y * 16.0 - 1.0)
			var node := _ride(P1, &"drill_rig", HillGame.UNDERGROUND, feet)
			_place(P2, feet + Vector2(-60, 0))
			node.ability.drill_changed.connect(func(on: bool) -> void: log_event("drill %s" % ("on" if on else "off")))
			_next("stage: Drill Rig in Topsoil")
		1:
			if _since() > 0.6:
				_hold(P1, Vector2.ZERO, true)
				_next("A: drill")
		2:
			if _since() > 6.0:
				_hold(P1, Vector2.ZERO, true)
				_next("A: stop at row %d" % int(game.player_node(P1).global_position.y / 16.0))
		3:
			if _since() > 1.5:
				_next("done")


func _treasure() -> void:
	var u := _ug()
	match _stage:
		0:
			var r: Rect2i = Rect2i()
			for sp in u.generator.treasure_spots:
				if sp.id == &"bottle_caps":
					r = sp.rect
			# A room left of the find, one cell of dirt between; P1 digs right into it.
			var room := Rect2i(r.position.x - 8, r.end.y - 2, 5, 2)
			_stage_players(room, Vector2i(room.end.x - 1, r.end.y - 1), Vector2i(room.position.x, r.end.y - 1))
			u.treasure_dug.connect(func(id: StringName, _p: int) -> void: log_event("found %s" % id), CONNECT_ONE_SHOT)
			_next("stage: beside the bottle caps")
		1:
			_hold(P1, Vector2(1, 0), true)
			if Progress.has_treasure(&"bottle_caps"):
				_next("reveal")
		2:
			if _since() > 2.6:
				game.place_player(P1, HillGame.HILLVILLE, Vector2(TreasureShelf.X - 220.0, 0))
				if game.player_node(P2) != null:
					game.place_player(P2, HillGame.HILLVILLE, Vector2(TreasureShelf.X - 270.0, 0))
				game.shelf.placed.connect(func(id: StringName) -> void: log_event("shelf %s" % id), CONNECT_ONE_SHOT)
				_next("up top")
		3:
			_hold(P1, Vector2(1, 0))
			if game.player_node(P1).global_position.x > TreasureShelf.X - 90.0:
				_next("at the shelf")
		4:
			if _since() > 2.0:
				_next("done")


func _book() -> void:
	var b: BuildController = game.build
	match _stage:
		0:
			Progress.find_treasure(&"buried_car", P1)
			Progress.add_building(&"garage", Vector2i(26, 0))
			for v in [&"excavator", &"dump_truck"]:
				if not Progress.has_vehicle(v):
					Progress.vehicles.append(v)
			b.rebuild()
			Inventory.add(&"clay", 25)
			Inventory.add(&"stone", 12)
			Inventory.add(&"dirt", 30)
			game.place_player(P1, HillGame.HILLVILLE, Vector2(33 * 48, 0))
			b.book_pressed(P1)
			_next("stage: book open")
		1:
			var book := b.book_of(P1) as BuildBook
			if book != null and _since() > 0.6 and book.focused_id() != &"garage":
				_step_book(book)
			elif book != null and book.focused_id() == &"garage" and _since() > 0.6:
				_next("on the Garage card")
		2:
			var book := b.book_of(P1) as BuildBook
			if _since() > 2.5 and book != null:
				if book.focused_id() != &"water_tower":
					_step_book(book)
				else:
					b.book_input(P1, Vector2.ZERO, true, false)
					_next("picked the locked Water Tower")
		3:
			if _since() > 2.0:
				# The Crane comes: the next Garage gives the Drill Rig, which waits for the tooth.
				Progress.vehicles.append(&"crane")
				b.book_pressed(P1)
				b.book_pressed(P1)
				var book := b.book_of(P1) as BuildBook
				book.focus = book.card_ids().find(&"garage")
				_next("crane owned: Garage card shows the Drill Rig and the tooth")
		4:
			if _since() > 2.5:
				_next("done")


func _step_book(book: BuildBook) -> void:
	book.focus = posmod(book.focus + 1, book.rows.size() + book.locked.size())
	book.queue_redraw()
	Audio.play("ui_move")


func _shelf() -> void:
	match _stage:
		0:
			for id in [&"buried_car", &"bottle_caps", &"boot", &"bathtub", &"fossil", &"giant_tooth", &"dino_skeleton", &"pirate_chest", &"dragon_egg"]:
				Progress.find_treasure(id, P1)
			Progress.add_building(&"water_tower", Vector2i(52, 0))
			game.build.rebuild()
			game.place_player(P1, HillGame.HILLVILLE, Vector2(TreasureShelf.X - 260.0, 0))
			if game.player_node(P2) != null:
				game.place_player(P2, HillGame.HILLVILLE, Vector2(TreasureShelf.X - 300.0, 0))
			_next("stage: nine treasures found")
		1:
			_hold(P1, Vector2(1, 0))
			if game.player_node(P1).global_position.x > TreasureShelf.X - 70.0:
				_next("at the shelf")
		2:
			if _since() > 3.0:
				_next("done")


func _lineup() -> void:
	match _stage:
		0:
			var x := Hillville.SHAFT_X - 560.0
			var loader: Vehicle = game.vehicles.get(HillGame.LOADER)
			if loader != null:
				loader.position.x = x
			_ride(P1, &"dump_truck", HillGame.HILLVILLE, Vector2(x + 110.0, 0))
			_ride(P2, &"crane", HillGame.HILLVILLE, Vector2(x + 210.0, 0))
			for id in [&"excavator", &"drill_rig"]:
				if not Progress.has_vehicle(id):
					Progress.vehicles.append(id)
			game.park_new(&"excavator", Vector2(x - 90.0, 0))
			game.park_new(&"drill_rig", Vector2(x + 320.0, 0))
			_next("stage: lineup")
		1:
			if _since() > 3.0:
				_next("done")


# --- resident arcs (underground) ---------------------------------------------------------------

func _steal() -> void:
	var u := _ug()
	var res := u.residents
	match _stage:
		0:
			# A little Topsoil room off to the left of the landing; P1 digs right into the dirt.
			var room := Rect2i(56, 14, 4, 2)
			_stage_players(room, Vector2i(59, 15), Vector2i(56, 15))
			res.shovel_stolen.connect(func(_p: int) -> void: log_event("shovel taken"), CONNECT_ONE_SHOT)
			_next("stage: P1 digging in Topsoil")
		1:
			_hold(P1, Vector2(1, 0), true)
			if res.theft_time() >= 0.0:
				_next("mole pops up")
		2:
			_hold(P1, Vector2(1, 0), true)
			if res.theft_time() >= UndergroundResidents.T_HOLD + 0.2:
				_next("bubble")
		3:
			_hold(P1, Vector2(1, 0), true)
			if res.theft_time() >= UndergroundResidents.T_GIVEN:
				_next("shovel back")
		4:
			_hold(P1, Vector2(1, 0), true)
			if res.theft_time() < 0.0 and _since() > 1.0:
				_next("done (mole met %d)" % u.story.state(Story.MOLE).encounters)


func _walled() -> void:
	var u := _ug()
	var res := u.residents
	match _stage:
		0:
			var gr := Rect2i()
			for sp in u.generator.treasure_spots:
				if sp.id == &"gnome_room":
					gr = sp.rect
			var room := Rect2i(gr.position.x - 8, gr.end.y - 2, 5, 2)
			_stage_players(room, Vector2i(gr.position.x - 4, gr.end.y - 1), Vector2i(room.position.x, gr.end.y - 1))
			res.crew_freed.connect(func() -> void: log_event("wall crumbles"), CONNECT_ONE_SHOT)
			_next("stage: beside the Gnome Room")
		1:
			# Step up to the wall: the hats hop and a bubble shows the wall.
			_hold(P1, Vector2(1, 0))
			if _since() > 0.4:
				_next("at the wall (bubble)")
		2:
			if _since() > 2.2:
				_next("dig in")
		3:
			_hold(P1, Vector2(1, 0), true)
			if res.crew_state() != &"walled":
				_next("crew free")
		4:
			if res.crew_state() == &"marching" and not _stage_flag("march"):
				log_event("march")
			if res.crew_state() == &"gone" and _since() > 1.0:
				_next("done")


func _follow() -> void:
	var u := _ug()
	var res := u.residents
	match _stage:
		0:
			var ice := _layer(&"ice")
			var room: Rect2i = u.generator.landings[ice]
			var tunnel := Rect2i(room.end.x, room.position.y, 16, room.size.y)
			_stage_players(tunnel, Vector2i(room.end.x - 1, room.end.y - 1), Vector2i(room.position.x + 1, room.end.y - 1))
			_next("stage: P1 by the ice block")
		1:
			if res.caveman_state() == &"following":
				_next("following")
		2:
			_hold(P1, Vector2(1, 0))
			if _since() > 1.0:
				_next("down the tunnel")
		3:
			_hold(P1, Vector2(0.15, 0))
			if _since() > 1.2:
				_next("back to the shaft")
		4:
			_hold(P1, Vector2(-1, 0))
			if res.caveman_state() == &"leaving":
				_next("caveman into the shaft")
		5:
			if res.caveman_state() == &"gone" and _since() > 0.8:
				_next("done")


func _wake() -> void:
	var u := _ug()
	var res := u.residents
	match _stage:
		0:
			# Met once already (the first meeting's yawn is the "reveal" beat).
			u.story.meet_dragon()
			var d: Node2D = res.dragon
			var feet_y := HillGenerator.CAVERN.end.y * 16.0 - 2.0
			_place(P1, Vector2(d.position.x - 240.0, feet_y))
			_place(P2, Vector2(d.position.x - 290.0, feet_y))
			res.dragon_woke.connect(func() -> void: log_event("purr: she is coming up"), CONNECT_ONE_SHOT)
			_next("stage: the Bottom cavern, the Dragon met once")
		1:
			_hold(P1, Vector2(0.6, 0))
			_hold(P2, Vector2(0.6, 0))
			if res.dragon_state() == &"waking_up":
				_next("she wakes")
		2:
			if res.dragon_bubble().has(&"face_sheepish"):
				_next("bubble: the shaken hill")
		3:
			if res.dragon_bubble().has(&"face_hopeful"):
				_next("bubble: the Ruined Keep")
		4:
			if res.dragon_state() == &"leaving":
				_next("pieces")
		5:
			_hold(P1, Vector2(-1, 0))
			_hold(P2, Vector2(-1, 0))
			if res.dragon_state() == &"gone" and _since() > 0.5:
				_next("done")


func _visit() -> void:
	var u := _ug()
	var res := u.residents
	match _stage:
		0:
			for i in 3:
				u.story.steal_shovel()
			u.story.restore(Story.MOLE)
			var r := Rect2i()
			for sp in u.generator.treasure_spots:
				if sp.id == &"bottle_caps":
					r = sp.rect
			var room := Rect2i(r.position.x - 9, r.end.y - 2, 5, 2)
			_stage_players(room, Vector2i(r.position.x - 6, r.end.y - 1), Vector2i(room.position.x, r.end.y - 1))
			res.mole_gift.connect(func(b: StringName, n: int) -> void: log_event("gift %d %s" % [n, b]), CONNECT_ONE_SHOT)
			_next("stage: Lost & Found restored, P1 near the bottle caps")
		1:
			if _since() > 0.6 and res.visit_now(game.player_node(P1)):
				_next("mole visits")
		2:
			if _since() > 1.0:
				_next("glow %s" % [res.glowing_treasures()])
		3:
			if not res.mole_visiting():
				_next("he leaves a bundle")
		4:
			if _since() > 1.5:
				_next("done")


## True the first time `key` is asked for in this beat (one-off log lines).
func _stage_flag(key: String) -> bool:
	if has_meta(key):
		return true
	set_meta(key, true)
	return false
