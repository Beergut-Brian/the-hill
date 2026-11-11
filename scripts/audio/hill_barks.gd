## A-15 / P-06: who talks, when (Audio lane). HillAudio adds one; it only listens, reads where the
## players and residents stand, and calls Audio.bark(). It never moves anyone.
## - Jeff names a rock the moment he digs one up (every new kind at once, then now and then).
## - Chuck narrates while he is driving somewhere (and once as he climbs in).
## - The Mole says "oh dear", the Gnome Foreman mutters at his clipboard and the Dragon rumbles
##   (or yawns, asleep) when a player walks up to them.
## Every bark has its own cooldown (data/barks.tres, BarkTuning) on top of Audio's one-voice gap,
## and a bark that plays shows a picture bubble over whoever spoke (sound and visual together;
## pictures only, no words).
class_name HillBarks
extends Node

## Jeff only names "real" rocks.
const ROCKS: Array[StringName] = [&"stone", &"edgestone", &"strangestone", &"ice", &"crystal", &"clay"]
## Resident -> [cue awake, cue asleep] for the walk-up bark.
const NEAR_CUE := {&"mole": ["oh_dear", "oh_dear"], &"gnome_foreman": ["mutter", "mutter"],
	&"dragon": ["rumble", "yawn"]}
## Bark -> the pictures in its bubble.
const PICS := {
	"jeff/rock_name": [&"rock", &"face_happy"],
	"mole/oh_dear": [&"question", &"face_sheepish"],
	"gnome_foreman/mutter": [&"hardhat", &"face_hopeful"],
	"dragon/rumble": [&"heart", &"face_happy"],
	"dragon/yawn": [&"zzz"],
}
## Where the bubble's tail points, from the speaker's origin (their feet).
const HEAD := {&"mole": Vector2(0, -30), &"dragon": Vector2(0, -72), &"player": Vector2(0, -40),
	&"driver": Vector2(0, -52)}

var game: Node
var tuning_path := BarkTuning.PATH
var tuning: BarkTuning
## Every bark that played: {who, cue, t} (tests, the bark log).
var fired: Array = []
var _t := 0.0
var _last := {}            # "who/cue" -> time it last played
var _named := {}           # rock kinds Jeff has named
var _driving := {}         # player -> vehicle id
var _drive_t := {}         # player -> seconds driving fast since the last narration
var _dragon_awake := false
var _bubbles: Array = []
var _log := "--bark-log" in OS.get_cmdline_args() + OS.get_cmdline_user_args()


func _ready() -> void:
	name = "HillBarks"
	if game == null:
		game = get_parent().get("game") if get_parent() != null else null
	tuning = BarkTuning.load_from(tuning_path)
	Events.tile_dug.connect(_on_tile_dug)
	Events.dragon_woken.connect(_on_dragon_woken)
	var story = game.get("story") if game != null else null
	if story != null and story.has_method("phase"):
		_dragon_awake = story.phase(&"dragon") >= ResidentState.Phase.ARRIVED


func _exit_tree() -> void:
	for b in _bubbles:
		if is_instance_valid(b):
			b.queue_free()
	_bubbles.clear()


func _physics_process(delta: float) -> void:
	step(delta)


## One tick (tests call it directly).
func step(delta: float) -> void:
	_t += delta
	var players := _players()
	_narration(players, delta)
	_walk_ups(players)
	_bubbles = _bubbles.filter(func(b) -> bool: return is_instance_valid(b) and not b.is_queued_for_deletion())


## True if "who/cue" is past its cooldown.
func ready_for(key: String) -> bool:
	return not _last.has(key) or _t - float(_last[key]) >= tuning.cooldown(key)


## Plays one bark from speaker (a Node2D the players can see) and pops its bubble. False when the
## cooldown or Audio's one-voice rule holds it back. `force` skips this bark's own cooldown.
func say(who: String, cue: String, speaker: Node2D, pics: Array, head: Vector2, force := false) -> bool:
	var key := "%s/%s" % [who, cue]
	if not force and not ready_for(key):
		return false
	if not Audio.bark(who, cue):
		return false
	_last[key] = _t
	fired.append({"who": who, "cue": cue, "t": _t})
	if _log:
		print("bark: t=%.1f %s at %s" % [_t, key, speaker.global_position if speaker != null else Vector2.ZERO])
	if speaker != null and is_instance_valid(speaker) and speaker.get_parent() != null and not pics.is_empty():
		var b := BarkBubble.new()
		b.speaker = speaker
		b.head = head
		b.pics = pics
		b.secs = tuning.bubble_secs
		speaker.get_parent().add_child(b)
		_bubbles.append(b)
	return true


func bubbles() -> Array:
	return _bubbles.filter(func(b) -> bool: return is_instance_valid(b) and not b.is_queued_for_deletion())


# --- Jeff names rocks ----------------------------------------------------------------------------

func _on_tile_dug(cell: Vector2i, block: StringName, p: int) -> void:
	if p < 0 or _pick(p) != "jeff" or not ROCKS.has(block):
		return
	# A fish cell is the fish's moment (HillAudio plays `fish_flop`): Jeff does not name the ice.
	if HillAudio.is_fish(game, cell):
		return
	var pl = _players().get(p)
	if not pl is Node2D:
		return
	# Every new kind of rock gets its name straight away; after that, now and then.
	if say("jeff", "rock_name", pl, PICS["jeff/rock_name"], HEAD[&"player"], not _named.has(block)):
		_named[block] = true


# --- Chuck narrates ------------------------------------------------------------------------------

func _narration(players: Dictionary, delta: float) -> void:
	for p in _driving.keys():
		if not players.has(p) or not players[p].get("vehicle") is VehicleData:
			_driving.erase(p)
	for p: int in players:
		var node = players[p]
		var v = node.get("vehicle")
		if not v is VehicleData or _pick(p) != "chuck":
			continue
		var pics := [StringName("vehicle:%s" % v.id), &"face_happy"]
		if _driving.get(p, &"") != v.id:
			_driving[p] = v.id
			_drive_t[p] = 0.0
			say("chuck", "narrate", node, pics, HEAD[&"driver"])     # climbing in
			continue
		var vel = node.get("velocity")
		var speed := absf(vel.x if vel is Vector2 else 0.0) / maxf(float(v.speed), 1.0)
		if speed < tuning.narrate_speed:
			continue
		_drive_t[p] = float(_drive_t.get(p, 0.0)) + delta
		if _drive_t[p] >= tuning.narrate_every and say("chuck", "narrate", node, pics, HEAD[&"driver"]):
			_drive_t[p] = 0.0


# --- residents, when a player walks up -----------------------------------------------------------

## [{id, node, under}] for every resident sprite on screen right now (town and underground).
func speakers() -> Array:
	var out: Array = []
	var town = game.get("town") if game != null else null
	if town != null and town.has_method("sprite_of"):
		for id: StringName in NEAR_CUE:
			var sp = town.sprite_of(id)
			if sp is Node2D and not (town.has_method("saying") and not town.saying(id).is_empty()):
				out.append({"id": id, "node": sp, "under": false})
	var u = game.get("underground") if game != null else null
	var r = u.get("residents") if u != null else null
	if r != null and not (r.has_method("is_rescuing") and r.is_rescuing()):
		for id: StringName in NEAR_CUE:
			var key := "foreman" if id == &"gnome_foreman" else String(id)
			var sp = r.get(key)
			if sp is Node2D:
				out.append({"id": id, "node": sp, "under": true})
	return out.filter(func(s: Dictionary) -> bool: return is_instance_valid(s.node) and s.node.is_visible_in_tree())


func _walk_ups(players: Dictionary) -> void:
	if players.is_empty():
		return
	var dir = game.get("director") if game != null else null
	for s: Dictionary in speakers():
		var id: StringName = s.id
		var cue: String = NEAR_CUE[id][0 if _dragon_awake or id != &"dragon" else 1]
		var key := "%s/%s" % [id, cue]
		if not ready_for(key):
			continue
		var sp: Node2D = s.node
		for p: int in players:
			var pl = players[p]
			if not pl is Node2D:
				continue
			var under: bool = dir != null and dir.has_method("scene_of") and dir.scene_of(p) == &"underground"
			if under != s.under:
				continue
			if pl.global_position.distance_to(sp.global_position) <= tuning.near_radius:
				say(String(id), cue, sp, PICS.get(key, []), HEAD.get(id, Vector2(0, -34)))
				break


func _on_dragon_woken() -> void:
	_dragon_awake = true


func _players() -> Dictionary:
	var ps = game.get("players") if game != null else null
	return ps if ps is Dictionary else {}


func _pick(p: int) -> String:
	return Roster.pick(p) if Roster.has_method("pick") else ""
