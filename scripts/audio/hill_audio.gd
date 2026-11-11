## The Hill's audio director (Audio lane). HillGame adds one; it only listens and calls Audio.
## - Engines: one looped engine per driving player (vehicle.sounds.engine), pitched by speed.
## - Music: the layered theme follows the players (see THEME RULE below), a layer per depth zone,
##   the Dragon's choir in her cavern.
## - Dragon snore (W-17, A-13): no clock of its own. It plays on the Dragon's `dragon_snored`
##   (UndergroundResidents), so the sound, her puff and the cavern sway are one moment; louder by
##   depth (LayerData.snore_volume) for the deepest underground player. The sway is the residents'
##   (ScreenKick); this file never moves a camera.
## - Barks: the walk-up and in-play barks (Jeff names rocks, Chuck narrates his driving, the
##   residents talk when a player walks up) live in HillBarks, a child of this node, with their own
##   cooldowns and picture bubbles. This file keeps the story-moment barks (encounter, arrival,
##   the Dragon waking, the Foreman inspecting a new building). Audio.bark() rate-caps them all.
## - Resident arcs: arrival, light-on and each payoff from the Events signals.
##
## THEME RULE (the dynamic split): the theme follows where most players are. One up and one down
## (a tie) keeps whichever theme is already playing, so the music never flips back and forth on a
## split; the depth layers and the cavern choir follow the underground player either way (they are
## beat-free beds in D, so they sit under both melodies).
class_name HillAudio
extends Node

## Snore quieter than this (linear) is skipped (Topsoil is 0).
const SNORE_MIN := 0.05
## Resident id -> payoff cue.
const PAYOFF := {&"mole": "payoff_mole", &"caveman": "payoff_caveman",
	&"gnome_foreman": "payoff_gnomes", &"dragon": "payoff_dragon"}
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
## A-15 / P-06: Jeff's rocks, Chuck's narration and the residents' walk-up barks.
var barks: HillBarks
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
	barks = HillBarks.new()
	barks.game = game
	add_child(barks)
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
	_hook_snore()


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
		var vel = node.get("velocity")
		var speed := absf(vel.x if vel is Vector2 else 0.0) / maxf(float(v.speed), 1.0)
		Audio.engine_speed(p, speed)


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
