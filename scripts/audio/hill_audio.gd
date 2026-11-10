## The Hill's audio director (Audio lane). HillGame adds one; it only listens and calls Audio.
## - Engines: one looped engine per driving player (vehicle.sounds.engine), pitched by speed.
## - Music: the layered theme follows the players (see THEME RULE below), a layer per depth zone,
##   the Dragon's choir in her cavern.
## - Dragon snore: while she sleeps, a snore every SNORE_EVERY s for anyone underground, louder by
##   depth (LayerData.snore_volume); at the Bottom it nudges that player's camera, gently.
## - Barks: Jeff names rocks, Chuck narrates his driving, the Mole's "oh dear", the Foreman's
##   whistle and mutters, the Dragon's rumbles. Audio.bark() rate-caps them.
## - Resident arcs: arrival, light-on and each payoff from the Events signals.
##
## THEME RULE (the dynamic split): the theme follows where most players are. One up and one down
## (a tie) keeps whichever theme is already playing, so the music never flips back and forth on a
## split; the depth layers and the cavern choir follow the underground player either way (they are
## beat-free beds in D, so they sit under both melodies).
class_name HillAudio
extends Node

const SNORE_EVERY := 5.5
## Snore quieter than this (linear) is skipped (Topsoil is 0).
const SNORE_MIN := 0.05
const SHAKE_PX := 1.5
const SHAKE_SECS := 0.6
## Chuck narrates at most this often while driving, Jeff names a rock at most this often.
const NARRATE_EVERY := 14.0
const ROCK_EVERY := 10.0
## Jeff only names "real" rocks.
const ROCKS: Array[StringName] = [&"stone", &"edgestone", &"strangestone", &"ice", &"crystal", &"clay"]
## Resident id -> payoff cue.
const PAYOFF := {&"mole": "payoff_mole", &"caveman": "payoff_caveman",
	&"gnome_foreman": "payoff_gnomes", &"dragon": "payoff_dragon"}
## Treasure layer -> cue (bigger for rarer: deeper is rarer).
const TREASURE_TIER := {&"topsoil": "treasure_small", &"clay": "treasure", &"stone": "treasure_big",
	&"ice": "treasure_big", &"crystal": "treasure_huge", &"bottom": "treasure_huge"}

var game: Node
var snore_clock := 0.0
var shake_left := 0.0
var _layers: Array = []
var _driving := {}         # player -> vehicle id
var _narrate_at := {}      # player -> seconds since last narration
var _rock_at := -100.0
var _named := {}           # block types Jeff has named this session
var _dragon_awake := false
var _t := 0.0
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
	_snore(players, delta)


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


func _snore(players: Dictionary, delta: float) -> void:
	if shake_left > 0.0:
		shake_left -= delta
		_shake(players, shake_left > 0.0)
	if _dragon_awake:
		return
	snore_clock += delta
	if snore_clock < SNORE_EVERY:
		return
	snore_clock = 0.0
	var dir = game.get("director")
	var loudest := 0.0
	var at_bottom := false
	for p: int in players:
		if dir == null or dir.scene_of(p) != &"underground":
			continue
		var li := _layer_index(players[p].global_position)
		loudest = maxf(loudest, snore_volume(li))
		at_bottom = at_bottom or li >= _layers.size() - 1
	if loudest < SNORE_MIN:
		return
	if Audio.play("dragon_snore", null, linear_to_db(loudest)) and at_bottom:
		shake_left = SHAKE_SECS


## A slow, small sway (not a jitter) on the camera of every player at the Bottom.
func _shake(players: Dictionary, on: bool) -> void:
	var dir = game.get("director")
	if dir == null or not dir.has_method("camera_of"):
		return
	for p: int in players:
		if dir.scene_of(p) != &"underground" or _layer_index(players[p].global_position) < _layers.size() - 1:
			continue
		var cam: Camera2D = dir.camera_of(p)
		if cam == null:
			continue
		if on and SettingsPanel.screen_shake():
			var k := shake_left / SHAKE_SECS
			cam.offset = Vector2(0.0, sin(_t * 18.0) * SHAKE_PX * k)
		else:
			cam.offset = Vector2.ZERO


# --- barks and arcs ------------------------------------------------------------------------------

func _pick(p: int) -> String:
	return Roster.pick(p) if Roster.has_method("pick") else ""


func _on_tile_dug(_cell: Vector2i, block: StringName, p: int) -> void:
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
