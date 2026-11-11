## Roster: who each player is. Priority (args > shared file > defaults), unknown ids, no
## duplicates, the shared picks file (temp path, atomic, keeps other profiles), relaunch.
class_name TestRoster
extends GdUnitTestSuite

const P1 := Roster.P1
const P2 := Roster.P2
const THREE := "res://tests/fixtures/roster_three.json"
const FILE := "user://test_roster/players.json"

var _real := {}


func before() -> void:
	SuiteSandbox.enter("roster")   # first: never the real profile, settings or picks file
	_real = { "data": Roster.data_path, "picks": Roster.picks_path, "profile": Save.profile }


func after() -> void:
	_wipe()
	Roster.data_path = _real.data
	Roster.picks_path = _real.picks
	Roster.args_override = PackedStringArray()
	Save.profile = _real.profile
	Roster.reload()
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	Roster.picks_path = FILE
	Roster.data_path = THREE
	Save.profile = "p1"
	_wipe()
	_launch([])


func _wipe() -> void:
	for f in [FILE, FILE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## A fresh start of the game with these launch args.
func _launch(args: Array) -> void:
	Roster.args_override = PackedStringArray(["--test-roster"] + args)
	Roster.reload()


func _write(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(FILE.get_base_dir())
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func _file() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FILE))


func test_real_roster_is_jeff_and_chuck() -> void:
	Roster.data_path = "res://data/roster.json"
	_launch([])
	assert_array(Roster.roster()).contains(["jeff", "chuck"])
	assert_str(Roster.roster()[0]).is_equal("jeff")
	assert_str(Roster.characters_tag).is_not_empty()
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_str(Roster.pick(P2)).is_equal("chuck")
	for id in Roster.roster():
		var who := Roster.info(id)
		assert_bool(ResourceLoader.exists(who.glb)).is_true()
		assert_bool(ResourceLoader.exists(who.pixel)).is_true()
	assert_str(Roster.info("jeff").name).is_equal("Jeff")
	for resident in ["mole", "dragon", "caveman", "gnome_foreman"]:
		assert_bool(Roster.has(resident)).is_false()


func test_shared_path_is_outside_user() -> void:
	assert_str(Roster.shared_path()).ends_with("openjar/players.json")
	assert_bool(Roster.shared_path().begins_with("user://")).is_false()
	assert_str(Roster.shared_path().get_base_dir().get_base_dir()).is_equal(OS.get_data_dir())


func test_defaults_when_nothing_else() -> void:
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_str(Roster.pick(P2)).is_equal("chuck")


func test_file_beats_defaults() -> void:
	_write({ "p1": { "P1": "pip", "P2": "jeff" } })
	_launch([])
	assert_str(Roster.pick(P1)).is_equal("pip")
	assert_str(Roster.pick(P2)).is_equal("jeff")


func test_args_beat_file() -> void:
	_write({ "p1": { "P1": "pip", "P2": "jeff" } })
	_launch(["--p1-char=chuck", "--p2-char=pip"])
	assert_str(Roster.pick(P1)).is_equal("chuck")
	assert_str(Roster.pick(P2)).is_equal("pip")


func test_file_is_keyed_by_profile() -> void:
	_write({ "p1": { "P1": "pip" }, "kid": { "P1": "chuck", "P2": "jeff" } })
	Save.profile = "kid"
	_launch([])
	assert_str(Roster.pick(P1)).is_equal("chuck")
	assert_str(Roster.pick(P2)).is_equal("jeff")


func test_unknown_ids_fall_back() -> void:
	_write({ "p1": { "P1": "mole", "P2": 7 } })
	_launch(["--p1-char=dragon", "--p2-char="])
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_str(Roster.pick(P2)).is_equal("chuck")
	assert_bool(Roster.set_pick(P1, "mole")).is_false()
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_dict(Roster.info("mole")).is_empty()


func test_broken_file_reads_as_empty() -> void:
	DirAccess.make_dir_recursive_absolute(FILE.get_base_dir())
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	_launch([])
	assert_str(Roster.pick(P1)).is_equal("jeff")


func test_no_duplicates_at_start() -> void:
	_write({ "p1": { "P1": "chuck", "P2": "chuck" } })
	_launch([])
	assert_str(Roster.pick(P1)).is_equal("chuck")
	assert_str(Roster.pick(P2)).is_equal("pip")
	_launch(["--p1-char=jeff", "--p2-char=jeff"])
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_str(Roster.pick(P2)).is_equal("chuck")


func test_set_pick_refuses_the_other_players_character() -> void:
	assert_bool(Roster.set_pick(P1, "chuck")).is_false()
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_bool(Roster.taken("chuck", P1)).is_true()
	assert_bool(Roster.taken("jeff", P1)).is_false()


func test_next_free_skips_taken_and_wraps() -> void:
	assert_str(Roster.next_free(P1, 1)).is_equal("pip")      # jeff -> (chuck taken) -> pip
	assert_str(Roster.next_free(P1, -1)).is_equal("pip")     # jeff -> wrap -> pip
	assert_str(Roster.next_free(P2, 1)).is_equal("pip")
	assert_str(Roster.next_free(P2, -1)).is_equal("pip")     # chuck -> (jeff taken) -> pip
	Roster.set_pick(P1, "pip")
	assert_str(Roster.next_free(P1, 1)).is_equal("jeff")     # pip -> wrap -> jeff
	assert_str(Roster.next_free(P2, 1)).is_equal("jeff")


func test_next_free_with_nobody_free_stays() -> void:
	Roster.data_path = "res://tests/fixtures/roster_two.json"     # Jeff and Chuck only
	_launch([])
	assert_str(Roster.next_free(P1, 1)).is_equal("jeff")
	assert_str(Roster.next_free(P2, -1)).is_equal("chuck")


func test_set_pick_writes_the_shared_file_and_keeps_other_keys() -> void:
	_write({ "kid": { "P1": "chuck" }, "p1": { "P1": "jeff", "P3": "zorp" }, "version": 2 })
	_launch([])
	var seen := []
	Roster.pick_changed.connect(func(p: int, id: String) -> void: seen.append([p, id]))
	assert_bool(Roster.set_pick(P1, "pip")).is_true()
	assert_array(seen).is_equal([[P1, "pip"]])
	var d := _file()
	assert_dict(d.p1).is_equal({ "P1": "pip", "P2": "chuck", "P3": "zorp" })
	assert_dict(d.kid).is_equal({ "P1": "chuck" })
	assert_int(int(d.version)).is_equal(2)
	assert_bool(FileAccess.file_exists(FILE + ".tmp")).is_false()


func test_write_creates_the_folder() -> void:
	DirAccess.remove_absolute(FILE.get_base_dir())
	assert_bool(Roster.set_pick(P2, "pip")).is_true()
	assert_str(_file().p1.P2).is_equal("pip")


func test_pick_survives_a_relaunch() -> void:
	Roster.set_pick(P1, "pip")
	Roster.set_pick(P2, "jeff")
	_launch([])                               # the next game (or this one again) starts
	assert_str(Roster.pick(P1)).is_equal("pip")
	assert_str(Roster.pick(P2)).is_equal("jeff")


func test_args_parse_both_forms() -> void:
	var a := Roster.picks_from_args(PackedStringArray(["--p1-char=chuck", "--", "--p2-char=jeff"]))
	assert_dict(a).is_equal({ P1: "chuck", P2: "jeff" })


func test_does_not_touch_the_games_saves() -> void:
	var before := DirAccess.get_files_at("user://saves") if DirAccess.dir_exists_absolute("user://saves") else PackedStringArray()
	Roster.set_pick(P1, "pip")
	var after := DirAccess.get_files_at("user://saves") if DirAccess.dir_exists_absolute("user://saves") else PackedStringArray()
	assert_array(Array(after)).is_equal(Array(before))
	assert_bool(Roster.picks_path.begins_with("user://saves")).is_false()
