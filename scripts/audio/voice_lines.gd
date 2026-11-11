## P-06 / A-15: the players' picked characters speak, in their own voice from the shared character
## library (Roster info "voice", openjar-characters packs). Everyone's lines, on top of Jeff naming
## rocks and Chuck narrating (hill_audio.gd):
##   found    a treasure turns up: the finder's "win" (or "cheer"), just after the jingle
##   upgrade  a Workshop goes up: each player's "cheer" (B-06), one after the other
##   built    any other building goes up: a player's "cheer", now and then
##   hello    a resident arrives at the shaft: a player's "join" (a friendly hello)
## Audio.bark() rate-caps every line (one voice at a time, a gap between) and falls back to the
## library line for the cue (Audio.LIBRARY_CUES). Characters without a voice pack (Jeff and Chuck in
## openjar-characters v0.5.0) say nothing here: their placeholder gibberish is reserved for rocks
## and narration. Lines are words in a voice, never text on screen.
class_name VoiceLines
extends Node

## Seconds after the event before the line, so it lands after the event's own sound.
const AFTER := 0.7
## "built" for ordinary buildings: at most one line per this many seconds.
const BUILT_EVERY := 20.0

var game: Node
## [{"at": seconds, "who": character id, "cue": String}], played in order (tests read it).
var queue: Array = []
## Lines that actually played: [[character id, cue]] (tests read it).
var said: Array = []
var _t := 0.0
var _built_at := -1000.0


func _ready() -> void:
	name = "VoiceLines"
	Events.treasure_found.connect(_on_treasure_found)
	Events.building_placed.connect(_on_building_placed)
	Events.resident_arrived.connect(_on_resident_arrived)


func _exit_tree() -> void:
	for pair in [[Events.treasure_found, _on_treasure_found], [Events.building_placed, _on_building_placed],
			[Events.resident_arrived, _on_resident_arrived]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _process(delta: float) -> void:
	step(delta)


## Advances the clock and plays what is due (tests call it directly).
func step(delta: float) -> void:
	_t += delta
	while not queue.is_empty() and float(queue[0].at) <= _t:
		var line: Dictionary = queue.pop_front()
		if Audio.bark(line.who, line.cue):
			said.append([line.who, line.cue])


## True when the character has a library voice pack (Roster "voice").
static func has_voice(id: String) -> bool:
	return id != "" and Roster.has(id) and String(Roster.info(id).get("voice", "")) != ""


func _say(p: int, cue: String, extra := 0.0) -> void:
	var who := Roster.pick(p)
	if not has_voice(who):
		return
	var last := float(queue.back().at) if not queue.is_empty() else _t
	queue.append({"at": maxf(_t + AFTER + extra, last + (Audio.BARK_GAP + 0.1 if not queue.is_empty() else 0.0)), "who": who, "cue": cue})


## Players in the game whose pick has a voice pack.
func _players() -> Array:
	var out: Array = []
	if game != null and game.has_method("player_node"):
		for p in [Players.P1, Players.P2]:
			if game.player_node(p) != null and has_voice(Roster.pick(p)):
				out.append(p)
	return out


func _on_treasure_found(_id: StringName, player: int) -> void:
	if player >= 0:
		_say(player, "found")


func _on_building_placed(id: StringName, _cell: Vector2i) -> void:
	var d: BuildingData = Progress.building_data(id)
	if d != null and d.effect == &"dig_power":
		for p in _players():
			_say(p, "upgrade")
		return
	if _t - _built_at < BUILT_EVERY:
		return
	var ps := _players()
	if not ps.is_empty():
		_built_at = _t
		_say(ps[randi() % ps.size()], "built")


func _on_resident_arrived(_id: StringName) -> void:
	var ps := _players()
	if not ps.is_empty():
		_say(ps[0], "hello", 1.0)
