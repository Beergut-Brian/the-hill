## Who each player is. Autoload: Roster (docs/contracts.md).
## The playable characters come from data/roster.json (scripts/tools/sync_characters.sh vendors
## them from openjar-characters into assets/characters/<id>/). Each slot's pick resolves, first hit
## in the roster wins: --p1-char= / --p2-char= launch args, then the shared picks file (keyed by
## Save.profile then slot, shared by every Open Jar game and the launcher), then the defaults.
## No two players are the same character. A changed pick is written to the shared file at once.
## Player colours stay with the slot (Players.COLOR), whoever is picked.
extends Node

signal pick_changed(player: int, id: String)

const P1 := 0
const P2 := 1
const SLOT := { P1: "P1", P2: "P2" }
const ARG := { P1: "--p1-char=", P2: "--p2-char=" }

## Tests point this at a fixture, then reload().
var data_path := "res://data/roster.json"
## The shared picks file, outside every game's user://. Tests point this at user://.
var picks_path := shared_path()
## The openjar-characters tag data/roster.json was synced from.
var characters_tag := ""
## Tests set this instead of the real command line ([] = the real one).
var args_override: PackedStringArray = []

var _roster: Array[String] = []
var _chars := {}
var _defaults := {}
var _picks := { P1: "", P2: "" }
var _voice: AudioStreamPlayer


## <OS data dir>/openjar/players.json (Linux ~/.local/share/openjar/players.json).
static func shared_path() -> String:
	return OS.get_data_dir().path_join("openjar").path_join("players.json")


## "--p1-char=chuck" -> {P1: "chuck"}; either side of "--".
static func picks_from_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		for p in ARG:
			if a.begins_with(ARG[p]):
				out[p] = a.trim_prefix(ARG[p]).strip_edges()
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX"
	add_child(_voice)
	reload()


## Re-read roster.json, the launch args and the shared file, and resolve both slots.
func reload() -> void:
	_load_data()
	var args := args_override if not args_override.is_empty() \
			else OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var from_args := picks_from_args(args)
	var saved = _read_file().get(_profile(), {})
	var mine: Dictionary = saved if saved is Dictionary else {}
	var before := _picks.duplicate()
	_picks = { P1: "", P2: "" }
	for p in [P1, P2]:
		for c in [str(from_args.get(p, "")), str(mine.get(SLOT[p], "")), default_for(p)]:
			if has(c):
				_picks[p] = c
				break
		if _picks[p] == "":
			_picks[p] = _first_free(p)
	if _picks[P2] != "" and _picks[P2] == _picks[P1]:
		_picks[P2] = next_free(P2, 1)
		if _picks[P2] == _picks[P1]:
			_picks[P2] = ""   # a one-character roster: P2 has nobody left
	for p in [P1, P2]:
		if _picks[p] != before[p]:
			pick_changed.emit(p, _picks[p])


func roster() -> Array[String]:
	return _roster.duplicate()


func has(id: String) -> bool:
	return id != "" and _chars.has(id)


## {} if unknown. Else id, name, glb, pixel, voice (res:// paths or ""), barks, default_for.
func info(id: String) -> Dictionary:
	if not has(id):
		return {}
	var c: Dictionary = _chars[id].duplicate(true)
	c["id"] = id
	return c


func default_for(player: int) -> String:
	return str(_defaults.get(SLOT.get(player, ""), ""))


func pick(player: int) -> String:
	return _picks.get(player, "")


## Is id someone else's pick (anyone but `by_other_than`)?
func taken(id: String, by_other_than: int) -> bool:
	for p in _picks:
		if p != by_other_than and _picks[p] == id:
			return true
	return false


## Change a slot's character. False (nothing changes) if unknown or the other player has it.
func set_pick(player: int, id: String) -> bool:
	if not has(id) or not _picks.has(player) or taken(id, player):
		return false
	if _picks[player] == id:
		return true
	_picks[player] = id
	_write_file()
	pick_changed.emit(player, id)
	return true


## The next roster id in direction dir (+1 / -1) that the other player hasn't got, wrapping.
## pick(player) when there is no other free character.
func next_free(player: int, dir: int) -> String:
	var n := _roster.size()
	if n == 0:
		return ""
	var at := _roster.find(pick(player))
	var step := 1 if dir >= 0 else -1
	for i in range(1, n + 1):
		var id := _roster[posmod(at + step * i, n)]
		if not taken(id, player):
			return id
	return pick(player)


## A random voice bark for id. False if the character has none yet (play a UI sound instead).
func bark(id: String) -> bool:
	var who := info(id)
	if who.is_empty() or who.voice == "" or who.barks.is_empty():
		return false
	var path := "%s%s.ogg" % [who.voice, who.barks.pick_random()]
	if not ResourceLoader.exists(path):
		return false
	_voice.stream = load(path)
	_voice.play()
	return true


func _first_free(player: int) -> String:
	for id in _roster:
		if not taken(id, player):
			return id
	return ""


func _profile() -> String:
	var save := get_node_or_null("/root/Save")
	return str(save.profile) if save else "p1"


func _load_data() -> void:
	_roster.clear()
	_chars = {}
	_defaults = {}
	characters_tag = ""
	if not FileAccess.file_exists(data_path):
		push_warning("Roster: no %s (run scripts/tools/sync_characters.sh)" % data_path)
		return
	var d = _parse(FileAccess.get_file_as_string(data_path))
	if not d is Dictionary:
		push_warning("Roster: %s is not a JSON object" % data_path)
		return
	characters_tag = str(d.get("characters_tag", ""))
	_defaults = d.get("defaults", {}) if d.get("defaults") is Dictionary else {}
	var chars: Dictionary = d.get("characters", {}) if d.get("characters") is Dictionary else {}
	for id in d.get("roster", []):
		if id is String and chars.get(id) is Dictionary and not _roster.has(id):
			_roster.append(id)
			var c: Dictionary = chars[id]
			_chars[id] = {
				"name": str(c.get("name", id.capitalize())),
				"glb": str(c.get("glb", "")),
				"pixel": str(c.get("pixel", "")),
				"voice": str(c.get("voice", "")),
				"barks": Array(c.get("barks", [])) if c.get("barks") is Array else [],
				"default_for": int(c.get("default_for", 0)),
			}


## The whole shared file; {} if missing or broken.
func _read_file() -> Dictionary:
	if not FileAccess.file_exists(picks_path):
		return {}
	var d = _parse(FileAccess.get_file_as_string(picks_path))
	return d if d is Dictionary else {}


## JSON without an engine error for a broken file (another program may have half-written it).
static func _parse(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null


## Read, change only this profile's slots, keep everything else, write a temp file, rename.
func _write_file() -> void:
	var all := _read_file()
	var mine: Dictionary = all.get(_profile(), {}) if all.get(_profile()) is Dictionary else {}
	for p in [P1, P2]:
		if _picks[p] != "":
			mine[SLOT[p]] = _picks[p]
	all[_profile()] = mine
	var dir := picks_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		push_warning("Roster: could not make %s" % dir)
		return
	var tmp := picks_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Roster: could not write %s" % tmp)
		return
	f.store_string(JSON.stringify(all, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, picks_path) != OK:
		push_warning("Roster: could not rename %s" % tmp)
