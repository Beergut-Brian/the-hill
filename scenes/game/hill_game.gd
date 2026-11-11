## The Hill at play: one ScreenDirector (zoom from data/camera.tres, 2.0) hosting Hillville and the Underground, the
## players (drop-in: P2 sleeps in the Front Loader's bucket until P2 joins), the vehicles (parked
## nodes; a driven vehicle *is* its driver), the elevator, the save and the HUD.
## Tree: Game (this) > Director (> Hud, BookLayer), Build (BuildController), Elevator, Save.
## Set `start_players` before adding it (who readied in the lobby; empty = every active player).
class_name HillGame
extends Node

const HILLVILLE := &"hillville"
const UNDERGROUND := &"underground"
const HILLVILLE_SCENES := ["res://scenes/levels/hillville.tscn", "res://scenes/levels/hillville.gd"]
const BUILD_SCENES := ["res://scenes/game/build_controller.gd"]
const UNDERGROUND_SCENE := preload("res://scenes/levels/underground.tscn")
const LOADER := &"front_loader"
const LIGHT_RADIUS := 110.0
const PARK_GAP := 72.0
const ROLL_OUT_PX := 64.0

## Who readied in the lobby; empty: every active player.
var start_players: Array = []
## Tests: false skips loading the save (a fresh run).
var load_saved := true

var director: ScreenDirector
var hillville: Hillville
var underground: Underground
var build: BuildController
var elevator: HillElevator
var save: HillSave
var hud: Control
var book_layer: Control
var players: Dictionary = {}       # int -> HillPlayer
## Which residents have been met (saved as "residents"); the residents' behaviour reads it.
var story := Story.new()
## The residents up top (crew at the pile, the Caveman by his fire).
var town: TownResidents
## B-02: one cow per Barn, wandering its yard.
var cows: BarnCows
## V-07 / W-17: short camera kicks (big scoops, boulder landings, the snore).
var kick: ScreenKick
## S-06: the camera leads in the dig / drive direction; bigger vehicles zoom out (data/camera.tres).
var camera: CameraLead
## Up top right of the Caveman's fire: every treasure found, by layer.
var shelf: TreasureShelf
## The four ruins and the buildings they become (restore, door lights, Lost & Found, the crew).
var ruins: RuinSites
var vehicles: Dictionary = {}      # StringName -> Vehicle (the parked node; out of the tree while driven)
var drivers: Dictionary = {}       # StringName -> player driving it

var _anchor: Node2D
var _anchor_on := false
var _waking := {}
## B-03: who sleeps in the House at night (-1: nobody; the bucket by day). Rechecked every HOUSE_CHECK s.
var _house_sleeper := -1
var _house_check := 0.0
const HOUSE_NIGHT := 0.5
const HOUSE_CHECK := 0.5


func _ready() -> void:
	name = "Game"
	director = ScreenDirector.new()
	director.name = "Director"
	camera = CameraLead.new()
	camera.game = self
	director.zoom = camera.tuning.zoom   # S-07: 2.0 until the TV check (data/camera.tres)
	add_child(director)
	hillville = _make(HILLVILLE_SCENES) as Hillville
	underground = UNDERGROUND_SCENE.instantiate()
	underground.world_seed = HillSave.saved_seed(Underground.DEFAULT_SEED) if load_saved else Underground.DEFAULT_SEED
	underground.story = story
	director.add_scene(HILLVILLE, hillville)
	director.add_scene(UNDERGROUND, underground)
	build = _make(BUILD_SCENES) as BuildController
	if build != null:
		build.name = "Build"
		build.set("game", self)
		add_child(build)
	elevator = HillElevator.new()
	elevator.name = "Elevator"
	elevator.game = self
	add_child(elevator)
	save = HillSave.new()
	save.name = "Save"
	save.game = self
	add_child(save)
	hud = HillHud.new()
	hud.name = "Hud"
	hud.game = self
	director.add_child(hud)
	kick = ScreenKick.new()
	kick.game = self
	add_child(kick)
	add_child(camera)
	var sound := HillAudio.new()   # Audio lane: engines, layered music, snore, barks
	sound.game = self
	add_child(sound)
	var voices := VoiceLines.new()   # P-06: the picked characters speak with their library voices
	voices.game = self
	add_child(voices)
	book_layer = Control.new()
	book_layer.name = "BookLayer"
	book_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	director.add_child(book_layer)
	director.split_changed.connect(_on_split_changed)
	director.entered_scene.connect(func(p: int, s: StringName) -> void: Events.entered_scene.emit(p, s))
	Events.tile_dug.connect(_on_tile_dug)
	if hillville.has_signal(&"vehicle_rolls_out"):
		hillville.connect(&"vehicle_rolls_out", _on_vehicle_rolls_out)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.quit_requested.connect(autosave)
	if load_saved:
		save.apply()
	else:
		Progress.reset()
		Inventory.clear()
	underground.after_load()
	if underground.residents != null:
		underground.residents.sync_story()
	if hillville != null:
		town = TownResidents.new()
		hillville.add_child(town)
		# Behind the players, in front of the buildings.
		hillville.move_child(town, hillville.players_root().get_index())
		town.setup(self, hillville)
		cows = BarnCows.new()
		hillville.add_child(cows)
		hillville.move_child(cows, hillville.players_root().get_index())
		cows.setup(self, hillville)
		shelf = TreasureShelf.new()
		hillville.add_child(shelf)
		hillville.move_child(shelf, hillville.buildings_root().get_index())
		shelf.setup(self)
		ruins = RuinSites.new()
		hillville.add_child(ruins)
		hillville.move_child(ruins, hillville.buildings_root().get_index())
		ruins.setup(self, hillville)
		ruins.rebuilt.connect(_on_rebuilt)
		_sync_museum()
		story.changed.connect(_on_story_changed)
		if load_saved and save.away_seconds >= 0.0:
			ruins.crew_return(save.away_seconds)
	TimeOfDay.running = true
	_spawn_vehicles()
	_anchor = Node2D.new()
	_anchor.name = "Anchor"
	_anchor.position = _loader_spawn() + Vector2(80, -40)
	_set_anchor(true)
	var who := start_players if not start_players.is_empty() else Array(Players.active_players())
	for p in who:
		if _wants(p):
			spawn(p)
	_update_sleeper()
	if Game.demo:
		var beat := HillBeatRunner.beat_arg(OS.get_cmdline_user_args() + OS.get_cmdline_args())
		var runner: Node = HillDemoRunner.new()
		if beat != "":
			var gap: Script = load("res://scripts/gameplay/gap_beats.gd")
			runner = gap.new() if gap.get("GAP_BEATS").has(beat) else CameraBeats.new() if CameraBeats.CAMERA_BEATS.has(beat) else HazardBeats.new() if HazardBeats.HAZARD_BEATS.has(beat) else VehicleBeats.new() if VehicleBeats.VEHICLE_BEATS.has(beat) else PolishBeats.new() if PolishBeats.POLISH_BEATS.has(beat) else ArcBeats.new() if ArcBeats.ARC_BEATS.has(beat) else HillBeatRunner.new()
		runner.set("game", self)
		if beat != "":
			runner.set("beat", beat)
		add_child(runner)


## Restores a ruin whose resident is waiting: pays its cost from the pile, moves the resident to
## RESTORED (Events.ruin_restored) and rebuilds it plank by plank. False (nothing spent) when the
## resident is not waiting or the pile is short.
func restore_ruin(ruin_id: StringName) -> bool:
	var ruin := Progress.building_data(ruin_id)
	if ruin == null or not ruin.is_ruin:
		return false
	if not Rules.can_restore(ruin, story.state(ruin.resident), Inventory.can_afford(ruin.cost)):
		return false
	Inventory.spend(ruin.cost)
	if ruins != null:
		ruins.play_restore(ruin.resident)
	story.restore(ruin.resident)
	if town != null:
		town.on_restored(ruin.resident)
	if save != null:
		save.save_now()
	return true


func _on_rebuilt(resident: StringName) -> void:
	if town != null:
		town.on_rebuilt(resident)
	if resident == Story.CAVEMAN:
		_sync_museum()


func _on_story_changed() -> void:
	if ruins != null:
		ruins.sync_story()


## The Museum stands: the treasure shelf moves onto its dock by the pond (the Caveman's trophy shelf).
func _sync_museum() -> void:
	if shelf != null and ruins != null and story.restored(Story.CAVEMAN) and not ruins.is_rebuilding(Story.CAVEMAN):
		shelf.museum_at(ruins.home_rect(Story.CAVEMAN))


func _exit_tree() -> void:
	TimeOfDay.running = false
	if Events.tile_dug.is_connected(_on_tile_dug):
		Events.tile_dug.disconnect(_on_tile_dug)
	if Game.quit_requested.is_connected(autosave):
		Game.quit_requested.disconnect(autosave)


## A driven vehicle's parked node is out of the tree: free it with the game (no orphan on restart).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for v in vehicles.values():
			if is_instance_valid(v) and not (v as Node).is_inside_tree():
				(v as Node).free()


func _make(paths: Array) -> Node:
	for path: String in paths:
		if not ResourceLoader.exists(path):
			continue
		var res := load(path)
		if res is PackedScene:
			return (res as PackedScene).instantiate()
		if res is GDScript:
			return (res as GDScript).new()
	push_error("HillGame: none of %s exists" % [paths])
	return Node2D.new()


func player_node(p: int) -> HillPlayer:
	return players.get(p)


func world() -> TileWorld:
	return underground.world


func autosave() -> void:
	save.save_now()


## Progress.scene_of from where each spawned player is now (HillSave calls it before saving).
func note_scenes() -> void:
	for p: int in players:
		var s := director.scene_of(p)
		if s != &"":
			Progress.scene_of[p] = s


func _physics_process(delta: float) -> void:
	elevator.check(delta)
	_house_check -= delta
	if _house_check <= 0.0:
		_house_check = HOUSE_CHECK
		if house_sleeper() != _house_sleeper:
			_update_sleeper()
	for p: int in players:
		if director.scene_of(p) == UNDERGROUND and not elevator.is_riding(p):
			Progress.visit_layer(p, underground.layer_index_at(players[p].global_position))
	# A player who is in but not spawned (joined the lobby without readying, or solo focus moved
	# to P2) wakes on their first press.
	for p in [Players.P1, Players.P2]:
		if players.has(p) or not Players.is_active(p) or not _wants(p):
			continue
		if not start_players.is_empty() and not start_players.has(p) and not _pressed_any(p):
			continue
		wake(p)


func _pressed_any(p: int) -> bool:
	for a in ["action", "jump", "book", "horn"]:
		if Input.is_action_just_pressed(Players.action(p, a)):
			return true
	return false


## Solo: the pad drives solo_focus only; P2 stays asleep until the focus moves to P2.
func _wants(p: int) -> bool:
	if not Players.is_active(p):
		return false
	if Players.solo and p == Players.P2 and Players.solo_focus != Players.P2 and not players.has(p):
		return false
	return true


# --- players -----------------------------------------------------------------------------------

func spawn(p: int, at := Vector2.INF, scene: StringName = &"") -> HillPlayer:
	if players.has(p):
		return players[p]
	_set_anchor(false)
	var node := HillPlayer.new()
	node.name = "P%d" % (p + 1)
	node.player = p
	node.game = self
	if scene == &"":
		scene = StringName(Progress.scene_of.get(p, HILLVILLE))
		if scene != UNDERGROUND:
			scene = HILLVILLE
	if at == Vector2.INF:
		if scene == UNDERGROUND:
			at = underground.landing(Progress.deepest_of(p))
		else:
			at = hillville.spawn_point(p)
	node.position = at
	players[p] = node
	director.add_player(p, node, scene)
	_enter(p, scene)
	_update_sleeper()
	return node


func despawn(p: int) -> void:
	var node: HillPlayer = players.get(p)
	if node == null:
		return
	if node.vehicle != null:
		hop_out(node, true)
	players.erase(p)
	elevator.forget(p)
	underground.world.untrack(node)
	underground.world.remove_light(node)
	director.remove_player(p)
	node.queue_free()
	if players.is_empty():
		_set_anchor(true)
	_update_sleeper()


## P2 (or anyone) joins mid-game: the Loader's bucket tips and they tumble out next to it.
func wake(p: int) -> HillPlayer:
	if players.has(p):
		return players[p]
	var at := Vector2.INF
	var scene := HILLVILLE
	var tip_node: Node = null
	var face := 1
	var house := house_node() if house_sleeper() == p else null
	if house != null:
		# B-03: asleep in the House at night: out of the front door with a hop and a puff.
		var node_h := spawn(p, house.door_position() + Vector2(0, -2.0), HILLVILLE)
		node_h.velocity = Vector2(90.0, -200.0)
		node_h.bump()
		hillville.puff(house.door_position(), Hillville.CREAM, 10)
		Audio.play("hop_out")
		house.wake_bump()
		return node_h
	if p == Players.P2 or not players.is_empty():
		var lp := loader_position()
		scene = lp.scene
		face = lp.facing
		at = lp.pos + Vector2(face * 26.0, -2.0)
		tip_node = vehicles.get(LOADER) if drivers.get(LOADER, -1) == -1 else players.get(drivers[LOADER])
	var node := spawn(p, at, scene)
	node.velocity = Vector2(face * 90.0, -160.0)
	node.bump()
	Audio.play("bucket_tip")
	if tip_node is Vehicle:
		var tw := (tip_node as Vehicle).create_tween()
		tw.tween_property(tip_node, "bucket_tip", 1.0, 0.18)
		tw.tween_property(tip_node, "bucket_tip", 0.0, 0.35)
	elif tip_node is HillPlayer:
		(tip_node as HillPlayer).bump()
	return node


## Where the Front Loader is now: {scene, pos (feet), facing}.
func loader_position() -> Dictionary:
	var d: int = drivers.get(LOADER, -1)
	if d >= 0 and players.has(d):
		return {"scene": director.scene_of(d), "pos": players[d].global_position, "facing": players[d].facing}
	var v: Vehicle = vehicles.get(LOADER)
	if v != null and v.is_inside_tree():
		var s := HILLVILLE if _scene_of_node(v) == HILLVILLE else UNDERGROUND
		return {"scene": s, "pos": v.position, "facing": v.facing}
	return {"scene": HILLVILLE, "pos": _loader_spawn(), "facing": 1}


## The sleeping player drawn in vehicle `id`'s bucket, or -1 (by night with a House, they sleep there).
func sleeper_in(id: StringName) -> int:
	if id == LOADER and not players.has(Players.P2) and house_sleeper() < 0:
		return Players.P2
	return -1


## B-03 (GAME.md: "Jeff and Chuck sleep here"): the player asleep in the House, or -1. The absent
## P2 moves from the Loader's bucket into the first House once its lights are on (night), and back
## at dawn; pressing a button then wakes them out of the House's door instead of the bucket.
func house_sleeper() -> int:
	if players.has(Players.P2) or Progress.count_buildings(&"house") == 0:
		return -1
	return Players.P2 if Building.current_lights() >= HOUSE_NIGHT else -1


## The first House's node up top, or null.
func house_node() -> Building:
	if build == null:
		return null
	for i in Progress.buildings.size():
		if Progress.buildings[i].id == &"house":
			return build.building_node(i)
	return null


func _update_sleeper() -> void:
	var v: Vehicle = vehicles.get(LOADER)
	if v != null:
		v.sleeper = sleeper_in(LOADER)
	_house_sleeper = house_sleeper()
	var first := house_node()
	if hillville != null:
		for b in hillville.buildings_root().get_children():
			if b is Building and (b as Building).data != null and (b as Building).data.id == &"house":
				(b as Building).sleeper = _house_sleeper if b == first else -1


## The elevator (and tests): put a player in a scene at a position and set them up there.
func place_player(p: int, scene: StringName, pos: Vector2) -> void:
	director.move_player(p, scene, pos)
	_enter(p, scene)


## Underground: the world knows the player, keeps chunks around them and lights a headlamp.
func _enter(p: int, scene: StringName) -> void:
	var node: HillPlayer = players[p]
	Progress.scene_of[p] = scene
	if scene == UNDERGROUND:
		node.world = underground.world
		underground.world.track(node)
		underground.world.add_light(node, LIGHT_RADIUS)
		VehicleLamp.attach(node, underground.world)
		underground.world.update_chunks()
		Progress.visit_layer(p, underground.layer_index_at(node.position))
	else:
		node.world = null
		underground.world.untrack(node)
		underground.world.remove_light(node)
		VehicleLamp.detach(node)


func _on_player_joined(p: int, _device: int) -> void:
	if Game.state == Game.State.LOBBY or not _wants(p):
		return
	wake(p)


func _on_player_left(p: int) -> void:
	despawn(p)


func _set_anchor(on: bool) -> void:
	if on == _anchor_on:
		return
	_anchor_on = on
	if on:
		director.add_player(0, _anchor, HILLVILLE)
	else:
		director.remove_player(0)


# --- vehicles ----------------------------------------------------------------------------------

func _loader_spawn() -> Vector2:
	if hillville.has_method("loader_spawn"):
		return hillville.loader_spawn()
	return Vector2(1760, 0)


## Every unlocked vehicle parked up top: the Front Loader by the shaft; every other one in front of
## the Garage that opened it (Garage N, in building order, stores vehicle N), else near the shaft.
## The Drill Rig is too big for town: it always parks by the shaft as a landmark.
func _spawn_vehicles() -> void:
	var k := 0
	for id: StringName in Progress.vehicles:
		if vehicles.has(id):
			continue
		var pos := _loader_spawn()
		if id != LOADER:
			var at := garage_spot(id)
			if at == Vector2.INF:
				k += 1
				at = _loader_spawn() - Vector2(PARK_GAP * k, 0)
			pos = at
		park_new(id, pos)


## In front of the Garage that stores vehicle `id` (its door plus the roll-out), or INF.
func garage_spot(id: StringName) -> Vector2:
	var d := Progress.vehicle_data(id)
	if d == null or d.order <= 0 or not d.works_up_top:
		return Vector2.INF
	var n := 0
	for b in Progress.buildings:
		if b.id != &"garage":
			continue
		n += 1
		if n == d.order:
			var g := Progress.building_data(&"garage")
			var w := (g.footprint.x if g != null else 3) * BuildController.PLOT
			return Vector2(b.cell.x * BuildController.PLOT + w * 0.5 + ROLL_OUT_PX, 0)
	return Vector2.INF


func park_new(id: StringName, pos: Vector2, scene: StringName = HILLVILLE) -> Vehicle:
	var d := Progress.vehicle_data(id)
	if d == null:
		return null
	var v := Vehicle.new()
	v.data = d
	v.position = pos
	vehicles[id] = v
	_park(v, scene)
	return v


func _park(v: Vehicle, scene: StringName) -> void:
	var root: Node = director.scene_root(scene)
	root.add_child(v)
	var pr: Node = root.get_node_or_null(^"Players")
	if pr != null:
		root.move_child(v, pr.get_index())


func _scene_of_node(n: Node) -> StringName:
	var a := n.get_parent()
	while a != null:
		if a == hillville:
			return HILLVILLE
		if a == underground:
			return UNDERGROUND
		a = a.get_parent()
	return &""


## B next to a parked vehicle: hop in. True if it used the press.
func hop_in(node: HillPlayer) -> bool:
	var scene := director.scene_of(node.player)
	var best: Vehicle = null
	var best_d := INF
	for id: StringName in vehicles:
		var v: Vehicle = vehicles[id]
		if drivers.has(id) or not v.is_inside_tree() or _scene_of_node(v) != scene:
			continue
		var dx := absf(v.position.x - node.global_position.x) - Vehicle.body_size(v.data).x * 0.5
		var dy := absf(v.position.y - node.global_position.y)
		if dx <= HillPlayer.HOP_REACH and dy <= 24.0 and dx < best_d:
			best = v
			best_d = dx
	if best == null:
		return false
	best.get_parent().remove_child(best)
	drivers[best.data.id] = node.player
	node.global_position = Vector2(best.position.x, minf(best.position.y, node.global_position.y))
	node.facing = best.facing
	node.drive(best.data)
	Audio.play("hop_in")
	return true


## B while driving: hop out; the vehicle stays parked where you are.
func hop_out(node: HillPlayer, quiet := false) -> void:
	if node.vehicle == null:
		return
	var id := node.vehicle.id
	var v: Vehicle = vehicles.get(id)
	node.stop_driving()
	drivers.erase(id)
	if v == null:
		v = Vehicle.new()
		v.data = Progress.vehicle_data(id)
		vehicles[id] = v
	v.position = node.global_position
	v.facing = node.facing
	_park(v, director.scene_of(node.player))
	node.global_position += Vector2(-node.facing * 6.0, 0)
	_update_sleeper()
	if not quiet:
		Audio.play("hop_out")


## A Garage unlocked a vehicle: it appears at the door and rolls out a few tiles.
func _on_vehicle_rolls_out(id: StringName, door: Vector2) -> void:
	if vehicles.has(id):
		return
	var v := park_new(id, door)
	if v == null:
		return
	Audio.play("vehicle_rollout")
	var tw := v.create_tween()
	tw.tween_property(v, "position:x", door.x + ROLL_OUT_PX, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: Audio.play("horn"))


# --- wiring ------------------------------------------------------------------------------------

## Contract "Backpack": a dug block goes into the digger's backpack; full: it puffs, not kept.
func _on_tile_dug(cell: Vector2i, block: StringName, p: int) -> void:
	var node: HillPlayer = players.get(p)
	if node == null or director.scene_of(p) != UNDERGROUND:
		return
	if not node.keep_block(block):
		underground.burst(underground.world.shape.center_of(cell), Color(1, 1, 1, 0.8), 6, 60.0)
		Audio.play("backpack_full")


func _on_split_changed(on: bool) -> void:
	Events.split_changed.emit(on)
	Audio.play("split")
