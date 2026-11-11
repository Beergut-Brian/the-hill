## Store art from the real game (GAME.md "Store art"): starts a fresh HillGame in a throwaway save
## profile, stages one moment with the real systems, then swaps in a store camera (and hides the
## HUD) and saves one frame. Gameplay code is untouched: this scene only drives players and the camera.
##   grid  Chuck in the Excavator scoops into the Clay layer, the fossil pops out and flies,
##         Jeff hops and cheers beside him.
##   hero  Hillville at dusk: everyone home, the Dragon curled on her perch on the peak, a little
##         town in front of it.
## Run through art/tools/render_store.sh (needs a renderer):
##   godot-render --path . --resolution 1920x1080 res://art/store/store_shot.tscn -- --shot=grid --out=/abs/x.png
class_name StoreShot
extends Node

const P1 := 0
const P2 := 1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
## Grid: frames taken this long after the fossil is dug (the reveal grows over POP_TIME).
const GRID_AFTER := 0.62

var shot := "grid"
var out := ""
var game: HillGame
var t := 0.0
var cam_center := Vector2.ZERO
var cam_zoom := 2.0
var _intent := {P1: IDLE.duplicate(), P2: IDLE.duplicate()}
var _stage := 0
var _found_at := -1.0
var _saving := false
var _fossil := Vector2.ZERO


func _ready() -> void:
	process_priority = 1000            # after the ScreenDirector moved its cameras
	process_physics_priority = -10     # intents are set before the players read them
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	Save.profile = "store"   # never the kid's save or settings
	Save.settings_path = "user://store_settings.json"
	Save.reload_settings()
	Save.wipe()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	Game.start_round()
	game = HillGame.new()
	game.load_saved = false
	add_child(game)
	TimeOfDay.running = false
	TimeOfDay.set_time(0.5 if shot == "grid" else 0.67)
	game.hud.visible = false
	for p in [P1, P2]:
		var node: HillPlayer = game.player_node(p)
		if node != null:
			node.intent_source = _intent_for.bind(p)


func _intent_for(p: int) -> Dictionary:
	return _intent.get(p, IDLE)


func _physics_process(delta: float) -> void:
	t += delta
	for p in [P1, P2]:
		_intent[p] = IDLE.duplicate()
		var node: HillPlayer = game.player_node(p)
		if node != null and node.intent_source.get_object() != self:
			node.intent_source = _intent_for.bind(p)
	if t < 1.0:
		return
	if shot == "hero":
		_hero()
	else:
		_grid()


func _process(_delta: float) -> void:
	if game == null or game.director == null:
		return
	game.hud.visible = false
	for cam: Camera2D in game.director._cameras:
		cam.position_smoothing_enabled = false
		cam.global_position = cam_center
		cam.zoom = Vector2(cam_zoom, cam_zoom)


# --- grid ---------------------------------------------------------------------------------------

func _grid() -> void:
	var u := game.underground
	match _stage:
		0:
			var r := Rect2i()
			for sp in u.generator.treasure_spots:
				if sp.id == &"fossil":
					r = sp.rect
			# A tall room left of the fossil, two cells of clay between: Chuck scoops into it.
			var floor_y := r.end.y
			var room := Rect2i(r.position.x - 10, floor_y - 5, 8, 5)
			for y in range(room.position.y, room.end.y):
				for x in range(room.position.x, room.end.x):
					u.world.set_tile(Vector2i(x, y), 0)
			var feet_y := floor_y * 16.0 - 1.0
			_ride(P2, &"excavator", Vector2((room.end.x - 2) * 16.0, feet_y))
			game.player_node(P2).facing = 1
			_place(P1, Vector2((room.position.x + 2.5) * 16.0, feet_y))
			game.player_node(P1).facing = 1
			_fossil = Vector2((r.position.x + 0.5) * 16.0, feet_y)
			cam_zoom = 3.6
			u.treasure_dug.connect(func(_id: StringName, _p: int) -> void: _found_at = t, CONNECT_ONE_SHOT)
			_stage = 1
			print("store: grid staged, fossil at ", r)
		1:
			_cheer(P1)
			# Frame Jeff, Chuck's scoop and the fossil; feet a third of the way up.
			cam_center = Vector2((game.player_node(P1).global_position.x + _fossil.x) * 0.5 + 6.0, _fossil.y - 60.0)
			if t > 2.2:
				_intent[P2] = {"move": Vector2(1, 0), "dig": true, "jump": false, "book": false, "horn": false}
			if _found_at >= 0.0 and t - _found_at >= GRID_AFTER:
				_stage = 2
				_save()
			elif t > 20.0:
				push_error("store: the fossil was never dug")
				_stage = 2
				_save()


func _cheer(p: int) -> void:
	var node: HillPlayer = game.player_node(p)
	if node != null and node.is_on_floor():
		_intent[p] = {"move": Vector2.ZERO, "dig": false, "jump": true, "book": false, "horn": false}


# --- hero ---------------------------------------------------------------------------------------

func _hero() -> void:
	match _stage:
		0:
			for id in [Story.MOLE, Story.FOREMAN, Story.CAVEMAN, Story.DRAGON]:
				var s := game.story.state(id)
				s.encounters = s.encounters_to_arrive
				s.phase = ResidentState.Phase.RESTORED
			game.story.changed.emit()
			game.ruins.sync_story()
			game.town.sync_story()
			# A little Hillville in front of the peak: he chose barns, of course.
			for b in [[&"lighthouse", 139], [&"barn", 141], [&"water_tower", 144], [&"house", 147], [&"barn", 150]]:
				Progress.add_building(b[0], Vector2i(b[1], 0))
			game.build.rebuild()
			_stage = 1
		1:
			if t > 1.6:
				var keep := game.hillville.ruin_rect(&"ruined_keep")
				_ride(P2, &"excavator", Vector2(keep.position.x - 250.0, 0))
				game.player_node(P2).facing = 1
				game.place_player(P1, HillGame.HILLVILLE, Vector2(keep.position.x - 190.0, 0))
				game.player_node(P1).facing = 1
				cam_center = Vector2(7090.0, -125.0)
				cam_zoom = 2.1
				_stage = 2
		2:
			if t > 5.0:
				_stage = 3
				_save()


# --- helpers ------------------------------------------------------------------------------------

func _place(p: int, feet: Vector2) -> void:
	if game.player_node(p) == null:
		return
	game.place_player(p, HillGame.UNDERGROUND, feet)
	game.player_node(p).velocity = Vector2.ZERO


func _ride(p: int, id: StringName, pos: Vector2) -> void:
	var scene := HillGame.HILLVILLE if shot == "hero" else HillGame.UNDERGROUND
	var node: HillPlayer = game.player_node(p)
	if node == null:
		return
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


func _save() -> void:
	if _saving:
		return
	_saving = true
	await RenderingServer.frame_post_draw
	if out != "":
		get_viewport().get_texture().get_image().save_png(out)
		print("store: wrote ", out)
	get_tree().quit()
