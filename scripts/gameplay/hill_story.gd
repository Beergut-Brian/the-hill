## The Hill's story director (GAME.md "Playtest 2026-11-10 changes" 1-3): hosts the reusable
## CutscenePlayer and decides when each cutscene plays.
##   intro           a new save (once; saved as resident_arcs.intro_seen), and from the pause menu
##   mole_theft      MoleArc: after the hints, he sneaks in and takes the shovel
##   mole_return     NO_SHOVEL_SECS later: fade, wake up top by the shaft, he hands it back
##   crew_freed / caveman_thaw / dragon_reveal / dragon_wake   each resident's encounter
##   arrive          a resident has come up and a player is up top to see them
##   movein          a restored ruin finished rebuilding
##   vehicle_unlock  a Garage rolls a new vehicle out (Foreman Dot shows it off)
## A moment that happens while another scene plays (or while someone rides the elevator or the
## crane) waits in a queue. In the full --demo only the story beats play scenes (other lanes'
## beats keep their timing); --demo-beat=intro|theft|return|mole|arrive_scene|movein_scene|unlock
## show one each (scripts/gameplay/story_beats.gd).
class_name HillStory
extends Node

const NO_SHOVEL_SECS := 3.0
## Tunable for tests (NO_SHOVEL_SECS in play).
var no_shovel_secs := NO_SHOVEL_SECS
const INTRO_DELAY := 0.8
const SPAWN_Z := 7
const RESIDENT_SHEETS := {&"mole": "characters/mole.png", &"gnome_foreman": "characters/foreman.png",
		&"caveman": "characters/caveman.png", &"dragon": "characters/dragon.png"}
## Line-id stems per resident (lines.json arrive_<stem>, movein_<stem>).
const STEM := {&"mole": "mole", &"gnome_foreman": "foreman", &"caveman": "caveman", &"dragon": "dragon"}
const ARRIVE_PICS := {&"mole": [&"shovel", &"face_sheepish"], &"gnome_foreman": [&"wall", &"face_sheepish"],
		&"caveman": [&"ice", &"face_sheepish"], &"dragon": [&"shaken_hill", &"face_sheepish"]}

var game: HillGame
var player: CutscenePlayer
var mole: MoleArc
## Cutscenes play by themselves (false in the full --demo and in tests that build a bare game).
var auto := true
## [{id, ctx}] waiting their turn.
var queue: Array = []
## Every scene that started, in order (tests and the beat log).
var played: Array = []

var _saved_intent := {}            # player -> true: locked by this scene (released at the end)
var _locked := false
var _no_shovel := {}               # {p, t} the window between the theft and the return
var _intro_in := -1.0
var _dragon_state: StringName = &""
var _skip_arrive := {}
var _hooked := {}


func _ready() -> void:
	name = "HillStory"
	add_to_group(&"hill_story")
	player = CutscenePlayer.new()
	player.host = self
	game.director.add_child(player)
	player.finished.connect(_on_finished)
	mole = MoleArc.new()
	mole.story_host = self
	mole.setup(game)
	Events.resident_arrived.connect(_on_arrived)
	if game.hillville != null and game.hillville.has_signal(&"vehicle_rolls_out"):
		game.hillville.connect(&"vehicle_rolls_out", _on_vehicle_rolls_out)
	if game.ruins != null:
		game.ruins.rebuilt.connect(_on_rebuilt)
	var res := residents()
	if res != null:
		res.crew_freed.connect(func() -> void: _want(&"crew_freed", {"focus": "crew"}))
		res.caveman_thawed.connect(func() -> void: _want(&"caveman_thaw", {"focus": "caveman"}))
		res.dragon_revealed.connect(func() -> void: _want(&"dragon_reveal", {"focus": "dragon"}))
		res.auto_steal = false
		res.hide_home = true
	# Only a real game plays its moments by itself: the full --demo and bare test games do not.
	auto = game.load_saved and not Game.demo
	if auto and game.load_saved and not intro_seen():
		_intro_in = INTRO_DELAY


func _exit_tree() -> void:
	if Events.resident_arrived.is_connected(_on_arrived):
		Events.resident_arrived.disconnect(_on_arrived)
	if _locked:
		cutscene_lock(false)


func residents() -> UndergroundResidents:
	return game.underground.residents if game != null and game.underground != null else null


func intro_seen() -> bool:
	return bool(game.story.extras.get("intro_seen", false))


func is_playing() -> bool:
	return player != null and player.is_playing()


## The pause menu's Story entry (group "hill_story"): the intro again, from wherever you are.
func replay_intro() -> void:
	_want(&"intro", {}, true)


## Plays scene `id` now if nothing blocks it, else queues it. `front`: ahead of the queue.
func _want(id: StringName, ctx := {}, front := false) -> void:
	if not auto and not ctx.get("forced", false) and id != &"intro":
		return
	if front:
		queue.push_front({"id": id, "ctx": ctx})
	else:
		queue.append({"id": id, "ctx": ctx})
	_pump()


## Plays `id` straight away (beats and tests); false when one is playing or it cannot start.
func play_now(id: StringName, ctx := {}) -> bool:
	if not _ready_for(id, ctx):
		return false
	return _start(id, ctx)


func _start(id: StringName, ctx: Dictionary) -> bool:
	if not player.play(id, ctx):
		return false
	played.append(id)
	if id == &"intro":
		game.story.extras["intro_seen"] = true
	return true


func _pump() -> void:
	if is_playing() or queue.is_empty():
		return
	# The first one that can play now (an up-top scene waits for someone up top without holding
	# up an underground one behind it).
	for i in queue.size():
		var job: Dictionary = queue[i]
		if _ready_for(job.id, job.ctx):
			queue.remove_at(i)
			_start(job.id, job.ctx)
			return


## Not while someone rides the elevator or the crane (they are locked by it), and up-top scenes
## need someone up top.
func _ready_for(id: StringName, ctx: Dictionary) -> bool:
	if is_playing() or game.players.is_empty():
		return false
	for p: int in game.players:
		if (game.players[p] as HillPlayer).locked:
			return false
	if id in [&"arrive", &"movein", &"vehicle_unlock", &"intro"]:
		return _anyone_in(HillGame.HILLVILLE)
	if id == &"mole_return":
		return game.players.has(int(ctx.get("victim", -1)))
	return true


func _anyone_in(scene: StringName) -> bool:
	for p: int in game.players:
		if game.director.scene_of(p) == scene:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _intro_in >= 0.0:
		_intro_in -= delta
		if _intro_in < 0.0 and not intro_seen():
			_want(&"intro")
	if not _no_shovel.is_empty():
		_no_shovel.t -= delta
		if _no_shovel.t <= 0.0 and not is_playing():
			var p := int(_no_shovel.p)
			_no_shovel = {}
			_want(&"mole_return", return_ctx(p), true)
	var res := residents()
	if res != null:
		var ds := res.dragon_state()
		if ds != _dragon_state:
			_dragon_state = ds
			if ds == &"waking_up":
				_want(&"dragon_wake", {"focus": "dragon"})
	for p: int in game.players:
		var pl: HillPlayer = game.players[p]
		if not _hooked.has(pl.get_instance_id()):
			_hooked[pl.get_instance_id()] = true
			pl.no_shovel.connect(_on_no_shovel.bind(p))
	if _locked:
		# Someone who woke mid-scene is held too.
		for p: int in game.players:
			if not _saved_intent.has(p):
				_hold(p)
	_pump()


# --- moments -------------------------------------------------------------------------------------

## MoleArc: the hints are done and the gap has passed. He sneaks in on `p`.
func start_theft(p: int) -> bool:
	var pl := game.player_node(p)
	if pl == null or is_playing():
		return false
	return play_now(&"mole_theft", theft_ctx(p))


func theft_ctx(p: int) -> Dictionary:
	var pl := game.player_node(p)
	var back := -float(pl.facing if pl != null and pl.facing != 0 else 1) * 40.0
	return {"victim": p, "back": back, "near": back * 0.45, "away": -back * 2.0, "focus": "victim", "forced": true}


func return_ctx(p: int) -> Dictionary:
	var last := game.story.state(Story.MOLE).encounters + 1 >= Story.TO_ARRIVE[Story.MOLE]
	return {"victim": p, "focus": "victim", "last": last, "forced": true,
			"mole_line": "mole_return_last" if last else "mole_relieved"}


func _on_arrived(id: StringName) -> void:
	if _skip_arrive.get(id, false):
		_skip_arrive.erase(id)
		return
	_want(&"arrive", {"res": String(id), "stem": STEM.get(id, "mole"), "focus": "resident", "pics": ARRIVE_PICS.get(id, [])})


func _on_rebuilt(resident: StringName) -> void:
	_want(&"movein", {"res": String(resident), "stem": STEM.get(resident, "mole"), "focus": "home",
			"pics": [StringName("home:%s" % Story.HOME_OF.get(resident, &"")), &"heart"]})


func _on_vehicle_rolls_out(id: StringName, door: Vector2) -> void:
	var line_id := "unlock_%s" % id
	if CutscenePlayer.line(line_id).is_empty():
		line_id = "unlock_any"
	_want(&"vehicle_unlock", {"vehicle": String(id), "door": door, "line": line_id, "focus": "vehicle",
			"pics": [StringName("vehicle:%s" % id), &"star"]})


func _on_finished(id: StringName, _skipped: bool) -> void:
	match id:
		&"mole_theft":
			_no_shovel = {"p": int(player.context().get("victim", 0)), "t": no_shovel_secs}
	_pump()


# --- CutscenePlayer host -------------------------------------------------------------------------

func cutscene_actor(n: String) -> Node2D:
	var ctx := player.context()
	match n:
		"p1":
			return game.player_node(Players.P1)
		"p2":
			return game.player_node(Players.P2)
		"victim":
			return game.player_node(int(ctx.get("victim", 0)))
		"loader":
			var v: Vehicle = game.vehicles.get(HillGame.LOADER)
			return v if v != null and v.is_inside_tree() else null
		"vehicle":
			var v2: Vehicle = game.vehicles.get(StringName(str(ctx.get("vehicle", ""))))
			return v2 if v2 != null and v2.is_inside_tree() else null
		"resident":
			return _town_sprite(StringName(str(ctx.get("res", ""))))
		"crew":
			var res := residents()
			return res.crew[1 if res.crew.size() > 1 else 0] if res != null and not res.crew.is_empty() else null
		"caveman":
			return residents().caveman if residents() != null else null
		"dragon":
			return residents().dragon if residents() != null else null
	return null


func _town_sprite(id: StringName) -> Node2D:
	if game.town == null:
		return null
	var s := game.town.sprite_of(id)
	return s if s != null and s.is_inside_tree() else null


func cutscene_spawn(n: String, sheet: String, scene: String, pos: Vector2) -> Node2D:
	var file := sheet
	if not sheet.contains("/"):
		file = RESIDENT_SHEETS.get(StringName(sheet), CharacterSheet.file_of(sheet))
	var s := SheetSprite.make(file, "idle")
	if s == null:
		s = SheetSprite.new()
	s.name = "Cut_" + n
	s.set_meta(&"sheet", file)
	if _scene_of_ctx(scene) == HillGame.UNDERGROUND:
		s.z_index = SPAWN_Z
		var res := residents()
		(res if res != null else game.underground).add_child(s)
	else:
		var pr: Node = game.hillville.players_root()
		pr.get_parent().add_child(s)
		pr.get_parent().move_child(s, pr.get_index())
	s.global_position = pos
	return s


func cutscene_anim(n: String, anim: String) -> void:
	var a := player._actor(n)
	if a is SheetSprite and a.has_meta(&"sheet"):
		var e := SheetSprite.entry(String(a.get_meta(&"sheet")))
		var rows: Dictionary = e.get("rows", {})
		if rows.has(anim):
			var s := a as SheetSprite
			s.row = int(rows[anim].get("row", 0))
			s.frames = int(rows[anim].get("frames", 1))
			s.fps = float(rows[anim].get("fps", 0))
			s.frame_coords = Vector2i(0, s.row)


## "@victim" scenes play where the victim is; else the scene's own.
func _scene_of_ctx(scene: String) -> StringName:
	if scene == "@victim":
		return game.director.scene_of(int(player.context().get("victim", 0)))
	return StringName(scene) if scene != "" else HillGame.HILLVILLE


func cutscene_anchor(n: String) -> Vector2:
	var ctx := player.context()
	match n:
		"shaft":
			return game.hillville.arrival()
		"players_left":
			var x := INF
			var y := 0.0
			for p: int in game.players:
				if game.director.scene_of(p) == HillGame.HILLVILLE and game.players[p].position.x < x:
					x = game.players[p].position.x
					y = game.players[p].position.y
			return Vector2(x, y) if x != INF else game.hillville.spawn_point(0)
		"players_mid":
			var sum := Vector2.ZERO
			var k := 0
			for p: int in game.players:
				if game.director.scene_of(p) == HillGame.HILLVILLE:
					sum += game.players[p].position
					k += 1
			return sum / k if k > 0 else game.hillville.spawn_point(0)
		"door":
			return ctx.get("door", Vector2.INF)
		"home":
			if game.ruins != null:
				var r: Rect2 = game.ruins.home_rect(StringName(str(ctx.get("res", ""))))
				return Vector2(r.get_center().x, r.end.y)
		"mole_wait":
			return game.town.mole.position if game.town != null and game.town.mole != null else game.hillville.arrival() - Vector2(40, 0)
	return Vector2.INF


func cutscene_head(n: String) -> Vector2:
	match n:
		"dragon":
			return Vector2(-52, -60)
		"crew", "resident", "mole", "caveman":
			return Vector2(0, -30)
		"loader", "vehicle":
			return Vector2(0, -44)
	return Vector2(0, -34)


func cutscene_views() -> Array:
	var out: Array = []
	var d := game.director
	if game.players.is_empty():
		return out
	var ps: Array = game.players.keys()
	ps.sort()
	var off := player.global_position
	if not d.is_split():
		out.append({"camera": d.camera_of(ps[0]), "rect": Rect2(d.view_rect_of(ps[0]).position - off, d.view_rect_of(ps[0]).size)})
		return out
	for p: int in ps:
		var r := d.view_rect_of(p)
		out.append({"camera": d.camera_of(p), "rect": Rect2(r.position - off, r.size)})
	return out


func cutscene_character(n: String) -> String:
	match n:
		"p1":
			return CharacterSheet.id_of(Players.P1)
		"p2":
			return CharacterSheet.id_of(Players.P2)
		"victim":
			return CharacterSheet.id_of(int(player.context().get("victim", 0)))
		"pip":
			return "mayor_pip"
		"dot":
			return "foreman_dot"
		"mole":
			return "mole"
		"resident":
			return str(player.context().get("res", ""))
	return n


func cutscene_skip_pressed() -> bool:
	for p in [Players.P1, Players.P2]:
		if Players.is_active(p) and Input.is_action_just_pressed(Players.action(p, "action")):
			return true
	return false


## Uses the player's own `locked` (no input, no motion: hops and walks in the scene are not fought
## by physics). Only players this locked are released, and never one the elevator is carrying.
func cutscene_lock(on: bool) -> void:
	_locked = on
	if on:
		for p: int in game.players:
			_hold(p)
	else:
		for p: int in _saved_intent:
			var pl := game.player_node(p)
			if pl != null and is_instance_valid(pl) and not game.elevator.is_riding(p):
				pl.locked = false
		_saved_intent.clear()


func _hold(p: int) -> void:
	var pl := game.player_node(p)
	if pl == null or pl.locked:
		return
	_saved_intent[p] = true
	pl.locked = true


func cutscene_call(fn: String, args: Dictionary) -> void:
	var ctx := player.context()
	var victim := game.player_node(int(ctx.get("victim", 0)))
	match fn:
		"take_shovel":
			if victim != null:
				victim.has_shovel = false
		"give_shovel":
			if victim != null:
				victim.has_shovel = true
				victim.show_tool_upgrade()
			if bool(ctx.get("last", false)):
				_skip_arrive[Story.MOLE] = true
			game.story.steal_shovel()
			mole.reset()
			Audio.play("shovel_back")
		"wake_top":
			if victim != null:
				var at := game.hillville.arrival() + Vector2(-44, 0)
				if game.director.scene_of(victim.player) != HillGame.HILLVILLE or victim.global_position.distance_to(at) > 4.0:
					if victim.vehicle != null:
						game.hop_out(victim, true)
					game.place_player(victim.player, HillGame.HILLVILLE, at)
				victim.facing = 1
		"dirt":
			var a := player._actor(String(args.get("who", "mole")))
			if a != null:
				if a.get_parent() is Node2D and game.underground.is_ancestor_of(a):
					game.underground.burst(game.underground.to_local(a.global_position) + Vector2(0, -6), Color(0.5, 0.36, 0.25), 14, 110.0)
				else:
					game.hillville.puff(a.global_position + Vector2(0, -4), Color(0.5, 0.36, 0.25), 12)
		"confetti":
			var b := player._actor(String(args.get("who", "pip")))
			if b != null:
				for c in [Color("ffd23f"), Color("ff8fb1"), Color("58c4f0"), Color("3cc24a")]:
					game.hillville.puff(b.global_position + Vector2(0, -30), c, 6)
		"bump":
			var who := player._actor(String(args.get("who", "victim")))
			if who is HillPlayer:
				(who as HillPlayer).bump()
		_:
			push_warning("HillStory: unknown call '%s'" % fn)


## A dig press with empty hands: a bubble (the shovel, a question) and a soft bonk.
func _on_no_shovel(p: int) -> void:
	player.pop_bubble("p%d" % (p + 1), [&"shovel", &"question"], 1.4)
	Audio.play("dig_blocked")


## The no-shovel window: true while `p` waits to wake up top.
func shovel_gone(p: int) -> bool:
	return not _no_shovel.is_empty() and int(_no_shovel.p) == p
