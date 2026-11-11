## The Hill's audio director (Audio lane). HillGame adds one; it only listens and calls Audio.
## - Engines: one looped engine per driving player (vehicle.sounds.engine), pitched by speed.
## - Music: the layered theme follows the players (see THEME RULE below), a layer per depth zone,
##   the Dragon's choir in her cavern.
## - Dragon snore (W-17, A-13): no clock of its own. It plays on the Dragon's `dragon_snored`
##   (UndergroundResidents), so the sound, her puff and the cavern sway are one moment; louder by
##   depth (LayerData.snore_volume) for the deepest underground player. The sway is the residents'
##   (ScreenKick); this file never moves a camera.
## - Barks: Jeff names rocks, Chuck narrates his driving, the Mole's "oh dear", the Foreman's
##   whistle and mutters, the Dragon's rumbles. Audio.bark() rate-caps them.
## - Resident arcs: arrival, light-on and each payoff from the Events signals.
## - Frozen fish (W-11): digging a fish out of its ice plays `fish_flop` (a wet flip-flop).
## - Drain puzzle (C-22): while its water runs (the wet cells in a drain puzzle move or drain away),
##   the looped `drain_gurgle` plays, ducked under barks; GURGLE_HOLD s of still water stops it.
##   Water that only appears (a chunk loading) or one jump (a chunk freeing) is not running.
##
## THEME RULE (the dynamic split): the theme follows where most players are. One up and one down
## (a tie) keeps whichever theme is already playing, so the music never flips back and forth on a
## split; the depth layers and the cavern choir follow the underground player either way (they are
## beat-free beds in D, so they sit under both melodies).
class_name HillAudio
extends Node

## Snore quieter than this (linear) is skipped (Topsoil is 0).
const SNORE_MIN := 0.05
## Chuck narrates at most this often while driving, Jeff names a rock at most this often.
const NARRATE_EVERY := 14.0
const ROCK_EVERY := 10.0
## Jeff only names "real" rocks.
const ROCKS: Array[StringName] = [&"stone", &"edgestone", &"strangestone", &"ice", &"crystal", &"clay"]
## Resident id -> payoff cue.
const PAYOFF := {&"mole": "payoff_mole", &"caveman": "payoff_caveman",
	&"gnome_foreman": "payoff_gnomes", &"dragon": "payoff_dragon"}
## The drain gurgle: its level, how far it dips under a bark, how often the water is checked and
## how long the water must be still before it stops.
const GURGLE_KEY := &"drain_gurgle"
const GURGLE_DB := -8.0
const GURGLE_BARK_DB := -9.0
const GURGLE_POLL := 0.2
const GURGLE_HOLD := 0.6
const DRAIN_RECTS: Array[String] = ["rect", "pocket", "nook", "wall", "plug", "chute", "sump"]
## Treasure layer -> cue (bigger for rarer: deeper is rarer).
const TREASURE_TIER := {&"topsoil": "treasure_small", &"clay": "treasure", &"stone": "treasure_big",
	&"ice": "treasure_big", &"crystal": "treasure_huge", &"bottom": "treasure_huge"}

var game: Node
## Snores played, and the linear loudness of the last one (tests, the snore beat).
var snores_played := 0
var last_snore := 0.0
var _snore_src: Object = null
var _layers: Array = []
var _driving := {}         # player -> vehicle id
var _narrate_at := {}      # player -> seconds since last narration
var _rock_at := -100.0
var _named := {}           # block types Jeff has named this session
var _dragon_awake := false
var _t := 0.0
var gurgling := false
var _drain_sig := {}       # drain puzzle index -> [wet count, hash of the wet cells]
var _gurgle_poll := 0.0
var _gurgle_still := 0.0
var _moving := 0           # drain checks in a row that saw the water move
## --audio-log: print voice counts every 30 s of game time (the soak reads it).
var _log_every := 30.0 if "--audio-log" in OS.get_cmdline_args() + OS.get_cmdline_user_args() else 0.0
var _log_at := 0.0


static func treasure_cue(id: StringName) -> String:
	var path := "res://data/treasures/%s.tres" % id
	if not ResourceLoader.exists(path):
		return "treasure"
	var row = load(path)
	return TREASURE_TIER.get(row.get("layer"), "treasure") if row != null else "treasure"


func _ready() -> void:
	name = "HillAudio"
	if game == null:
		game = get_parent()
	_layers = Underground.load_rows(Underground.LAYER_DIR)
	_layers.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	Events.tile_dug.connect(_on_tile_dug)
	Events.resident_encountered.connect(_on_encountered)
	Events.resident_arrived.connect(_on_arrived)
	Events.ruin_restored.connect(_on_restored)
	Events.dragon_woken.connect(_on_dragon_woken)
	Events.building_placed.connect(_on_building_placed)
	var story = game.get("story")
	if story != null and story.has_method("phase"):
		_dragon_awake = story.phase(&"dragon") >= ResidentState.Phase.ARRIVED
	Audio.music_state(&"up", 0, false)


func _exit_tree() -> void:
	for p in _driving.keys():
		Audio.engine_stop(p)
	_driving.clear()
	_gurgle_off()
	Audio.music_state(&"up", 0, false)


func _physics_process(delta: float) -> void:
	_t += delta
	if _log_every > 0.0 and _t >= _log_at:
		_log_at += _log_every
		print("audio: t=%.0f voices=%d peak=%d engines=%d theme=%s zone=%d cavern=%s duck=%.1f" % [
			_t, Audio.voice_count(), Audio.peak_voices, Audio.engine_count(), Audio.music_theme(),
			Audio.music_state_now().zone, Audio.music_state_now().cavern, Audio.duck_db()])
		if _log_every > 0.0 and Audio.peak_voices >= 12:
			print("audio: peak mix ", Audio.peak_mix)
	var players: Dictionary = game.get("players") if game.get("players") is Dictionary else {}
	_engines(players)
	_music(players)
	_hook_snore()
	_gurgle(delta)


# --- engines -------------------------------------------------------------------------------------

func _engines(players: Dictionary) -> void:
	for p in _driving.keys():
		if not players.has(p) or players[p].get("vehicle") == null:
			Audio.engine_stop(p)
			_driving.erase(p)
	for p: int in players:
		var node = players[p]
		var v = node.get("vehicle")
		if not v is VehicleData:
			continue
		if _driving.get(p, &"") != v.id:
			_driving[p] = v.id
			Audio.engine(p, String(v.sounds.get(&"engine", "%s_engine" % v.id)))
			_narrate_at[p] = 0.0
			if _pick(p) == "chuck":
				Audio.bark("chuck", "narrate")
		var vel = node.get("velocity")
		var speed := absf(vel.x if vel is Vector2 else 0.0) / maxf(float(v.speed), 1.0)
		Audio.engine_speed(p, speed)
		# Chuck narrates while he is actually going somewhere.
		if _pick(p) == "chuck" and speed > 0.5:
			_narrate_at[p] = float(_narrate_at.get(p, 0.0)) + get_physics_process_delta_time()
			if _narrate_at[p] >= NARRATE_EVERY and Audio.bark("chuck", "narrate"):
				_narrate_at[p] = 0.0


# --- music ---------------------------------------------------------------------------------------

## {theme, zone, cavern} for these players (pure; tests call it).
func music_for(players: Dictionary) -> Dictionary:
	var ups := 0
	var downs := 0
	var zone := 0
	var cavern := false
	var dir = game.get("director")
	for p: int in players:
		var scene: StringName = dir.scene_of(p) if dir != null else &""
		if scene == &"underground":
			downs += 1
			var pos: Vector2 = players[p].global_position
			var li := _layer_index(pos)
			zone = maxi(zone, li)
			if _in_cavern(pos):
				cavern = true
		elif scene != &"":
			ups += 1
	var theme := Audio.music_theme()
	if downs > ups:
		theme = &"down"
	elif ups > downs or theme == &"":
		theme = &"up"
	return {"theme": theme, "zone": zone, "cavern": cavern}


func _music(players: Dictionary) -> void:
	var m := music_for(players)
	if players.is_empty():
		m = {"theme": Audio.music_theme() if Audio.music_theme() != &"" else &"up", "zone": 0, "cavern": false}
	if m != Audio.music_state_now():
		Audio.music_state(m.theme, m.zone, m.cavern)
		if _log_every > 0.0:
			print("audio: t=%.1f music %s zone %d cavern %s" % [_t, m.theme, m.zone, m.cavern])


func _layer_index(pos: Vector2) -> int:
	var u = game.get("underground")
	if u != null and u.has_method("layer_index_at") and u.get("generator") != null:
		return u.layer_index_at(pos)
	var depth := int(floor(pos.y / 16.0))
	for i in _layers.size():
		if depth < _layers[i].depth_to:
			return i
	return maxi(0, _layers.size() - 1)


func _in_cavern(pos: Vector2) -> bool:
	var c := HillGenerator.CAVERN
	var cell := Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))
	return Rect2i(c.position - Vector2i(2, 4), c.size + Vector2i(4, 8)).has_point(cell)


# --- the Dragon's snore --------------------------------------------------------------------------

## Linear snore loudness for a layer index (LayerData.snore_volume).
func snore_volume(layer_index: int) -> float:
	if _layers.is_empty():
		return 0.0
	return float(_layers[clampi(layer_index, 0, _layers.size() - 1)].snore_volume)


## Listens to the Dragon (the Underground's residents); re-hooks if the Underground is rebuilt.
func _hook_snore() -> void:
	var u = game.get("underground")
	var r = u.get("residents") if u != null else null
	if r == _snore_src or r == null or not r.has_signal(&"dragon_snored"):
		return
	_snore_src = r
	r.dragon_snored.connect(_on_dragon_snored)


## One of her snores: as loud as the deepest underground player hears it, or nothing up top.
## `_sway` is how strongly the cavern felt it (the residents sway the camera; we only sound).
func _on_dragon_snored(_sway: float) -> void:
	if _dragon_awake:
		return
	var players: Dictionary = game.get("players") if game.get("players") is Dictionary else {}
	var dir = game.get("director")
	var loudest := 0.0
	for p: int in players:
		if dir == null or dir.scene_of(p) != &"underground":
			continue
		loudest = maxf(loudest, snore_volume(_layer_index(players[p].global_position)))
	if loudest < SNORE_MIN:
		return
	if Audio.play("dragon_snore", null, linear_to_db(loudest)):
		snores_played += 1
		last_snore = loudest


# --- barks and arcs ------------------------------------------------------------------------------

func _pick(p: int) -> String:
	return Roster.pick(p) if Roster.has_method("pick") else ""


func _on_tile_dug(cell: Vector2i, block: StringName, p: int) -> void:
	# A fish cell is the fish's moment: the flop plays and Jeff does not name the ice on top of it.
	if _is_fish(cell):
		Audio.play("fish_flop")
		return
	if p < 0 or _pick(p) != "jeff" or not ROCKS.has(block):
		return
	# Every new kind of rock gets a name; after that, now and then.
	var due := not _named.has(block) or _t - _rock_at >= ROCK_EVERY * 3.0
	if due and Audio.bark("jeff", "rock_name"):
		_named[block] = true
		_rock_at = _t


func _on_encountered(id: StringName, _count: int) -> void:
	match id:
		&"mole":
			Audio.bark("mole", "oh_dear")
		&"gnome_foreman":
			Audio.bark("gnome_foreman", "whistle")
		&"dragon":
			Audio.bark("dragon", "rumble")


func _on_arrived(id: StringName) -> void:
	Audio.play("resident_arrive")
	match id:
		&"mole":
			Audio.bark("mole", "oh_dear")
		&"gnome_foreman":
			Audio.bark("gnome_foreman", "mutter")
		&"dragon":
			Audio.bark("dragon", "rumble")


func _on_restored(_id: StringName, resident: StringName) -> void:
	Audio.play("light_on")
	var cue: String = PAYOFF.get(resident, "")
	if cue != "":
		get_tree().create_timer(0.7).timeout.connect(Audio.play.bind(cue))


func _on_dragon_woken() -> void:
	_dragon_awake = true
	get_tree().create_timer(2.0).timeout.connect(Audio.bark.bind("dragon", "rumble"))


func _on_building_placed(_id: StringName, _cell: Vector2i) -> void:
	# The Foreman inspects every new building: a clipboard mutter once the march sets off.
	get_tree().create_timer(1.2).timeout.connect(Audio.bark.bind("gnome_foreman", "mutter"))


# --- depth life and puzzles ------------------------------------------------------------------------

## A frozen fish was in `cell` (HillGenerator.fish_at; -1 or no fish on this build: false).
func _is_fish(cell: Vector2i) -> bool:
	var u = game.get("underground") if game != null else null
	var gen = u.get("generator") if u != null else null
	return gen != null and gen.has_method("fish_at") and int(gen.fish_at(cell)) >= 0


## True when any drain puzzle's water moved (or drained away) since the last check.
func _drain_moved() -> bool:
	var u = game.get("underground") if game != null else null
	var gen = u.get("generator") if u != null else null
	var world = u.get("world") if u != null else null
	var pzs = gen.get("puzzles") if gen != null else null
	if world == null or not (pzs is Array):
		return false
	var moved := false
	for i in pzs.size():
		var pz: Dictionary = pzs[i]
		if pz.get("kind") != &"drain":
			continue
		var seen := {}
		var count := 0
		var h := 0
		for key in DRAIN_RECTS:
			var r = pz.get(key)
			if not (r is Rect2i):
				continue
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					if seen.has(c):
						continue
					seen[c] = true
					if world.has_water(c):
						count += 1
						h = hash([h, c])
		var was: Array = _drain_sig.get(i, [])
		_drain_sig[i] = [count, h]
		# Running: still some water, no more of it than before (more = a chunk just loaded in),
		# and not where it was.
		if not was.is_empty() and count > 0 and count <= int(was[0]) and h != int(was[1]):
			moved = true
	return moved


func _gurgle(delta: float) -> void:
	_gurgle_poll += delta
	if _gurgle_poll >= GURGLE_POLL:
		_gurgle_poll = 0.0
		if _drain_moved():
			_gurgle_still = 0.0
			_moving += 1
			# Two moving checks in a row: a chunk half freeing (one jump) is not running water.
			if not gurgling and _moving >= 2:
				gurgling = true
				Audio.engine(GURGLE_KEY, GURGLE_KEY)
		else:
			_moving = 0
		if gurgling and _moving == 0:
			_gurgle_still += GURGLE_POLL
			if _gurgle_still >= GURGLE_HOLD:
				_gurgle_off()
	if gurgling:
		Audio.engine_level(GURGLE_KEY, GURGLE_DB + (GURGLE_BARK_DB if Audio.is_barking() else 0.0))


func _gurgle_off() -> void:
	gurgling = false
	_gurgle_still = 0.0
	Audio.engine_stop(GURGLE_KEY)
