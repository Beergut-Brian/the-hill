## SuiteSandbox: a suite gets its own save profile, settings file and picks file, and the real
## roster, whatever a game suite before it left behind (another profile name, a saved solo, a
## picks file with other characters, a fixture roster, launch args), and puts it all back after.
class_name TestIsolation
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const DIRTY_SETTINGS := "user://test_isolation_left_settings.json"
const DIRTY_PICKS := "user://test_isolation_left_players.json"
const DIRTY_PROFILE := "test_isolation_family"

var _real := {}


## What a game's suite might leave: its own profile name, a saved solo, other picks, a fixture.
func before() -> void:
	_real = { "profile": Save.profile, "settings": Save.settings_path, "picks": Roster.picks_path,
			"data": Roster.data_path, "args": Roster.args_override }
	Save.use_profile(DIRTY_PROFILE)
	Save.set_value("family", "keep me")
	Save.flush()
	Save.settings_path = DIRTY_SETTINGS
	Save.set_setting("solo", true)
	Roster.picks_path = DIRTY_PICKS
	var f := FileAccess.open(DIRTY_PICKS, FileAccess.WRITE)
	f.store_string(JSON.stringify({ DIRTY_PROFILE: { "P1": "chuck", "P2": "jeff" },
			SuiteSandbox.profile_for("isolation"): { "P1": "chuck", "P2": "jeff" } }))
	f.close()
	Roster.data_path = "res://tests/fixtures/roster_three.json"
	Roster.args_override = PackedStringArray(["--p1-char=pip"])
	Roster.reload()


func after() -> void:
	SuiteSandbox.leave()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % DIRTY_PROFILE))
	Save.wipe_settings()
	DirAccess.remove_absolute(DIRTY_PICKS)
	Save.settings_path = _real.settings
	Save.reload_settings()
	Save.use_profile(_real.profile)
	Roster.picks_path = _real.picks
	Roster.data_path = _real.data
	Roster.args_override = _real.args
	Roster.reload()


func _picks_text() -> String:
	return FileAccess.get_file_as_string(DIRTY_PICKS)


func test_enter_gives_a_clean_world_and_leave_restores_it() -> void:
	var picks_before := _picks_text()
	SuiteSandbox.enter("isolation")
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("isolation"))
	assert_object(Save.get_value("family")).is_null()
	assert_str(Save.settings_path).is_equal(SuiteSandbox.settings_for("isolation"))
	assert_bool(Save.get_setting("solo", false)).is_false()
	assert_str(Roster.picks_path).is_equal(SuiteSandbox.picks_for("isolation"))
	assert_str(Roster.data_path).is_equal(SuiteSandbox.ROSTER)
	assert_str(Roster.pick(P1)).is_equal("jeff")              # defaults: no args, no saved picks
	assert_str(Roster.pick(P2)).is_equal("chuck")
	for path in [Save.settings_path, Roster.picks_path]:
		assert_bool(path == "user://settings.json" or path == Roster.shared_path()).is_false()
	# The suite boots the game and writes to its own files only.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Players.join_virtual(P1)
	main.get_node("UI/Lobby").press_b(P1)
	main.get_node("UI/Lobby").choose(P1, 1)
	Save.set_setting("solo", true)
	Save.set_value("suite", 1)
	Save.flush()
	main.free()
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()
	Players.reset()
	SuiteSandbox.leave()
	assert_bool(FileAccess.file_exists(SuiteSandbox.settings_for("isolation"))).is_false()
	assert_bool(FileAccess.file_exists(SuiteSandbox.picks_for("isolation"))).is_false()
	assert_bool(FileAccess.file_exists("user://saves/%s.json" % SuiteSandbox.profile_for("isolation"))).is_false()
	assert_str(Save.profile).is_equal(DIRTY_PROFILE)
	assert_str(Save.get_value("family", "")).is_equal("keep me")
	assert_str(Save.settings_path).is_equal(DIRTY_SETTINGS)
	assert_bool(Save.get_setting("solo", false)).is_true()
	assert_str(Roster.picks_path).is_equal(DIRTY_PICKS)
	assert_str(_picks_text()).is_equal(picks_before)          # the other files are untouched
	assert_str(Roster.pick(P1)).is_equal("pip")


func test_entering_twice_still_restores_the_first_world() -> void:
	SuiteSandbox.enter("isolation")
	SuiteSandbox.enter("isolation_b")                         # a suite that never called leave()
	SuiteSandbox.leave()
	assert_str(Save.profile).is_equal(DIRTY_PROFILE)
	assert_str(Save.settings_path).is_equal(DIRTY_SETTINGS)
	assert_str(Roster.picks_path).is_equal(DIRTY_PICKS)


## The build-machine bug: a scripted chooser run left Chuck as P1 in the real shared picks file, and
## test_lobby then booted with Chuck as P1. A run like this never starts on the shared file at all,
## and a picks file that was there before the suite (Chuck P1, Jeff P2, under every profile) leaves
## the lobby on the defaults and is not rewritten.
func test_a_real_picks_file_before_the_run_leaves_the_defaults() -> void:
	# This very run (gdUnit) booted on the scratch file, and so does every scripted run.
	var run := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	assert_str(Roster.boot_picks_path(run)).is_equal(Roster.SCRATCH_PICKS)
	assert_str(Save.boot_settings_path(run)).is_equal(Save.SCRATCH_SETTINGS)
	for scripted in [["-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"], ["--", "--shots=1,3"],
			["--", "--ui=chooser"], ["--", "--demo"], ["--", "--demo", "--demo-beat=lineup"],
			["--", "--screenshot-after=2"]]:
		assert_str(Roster.boot_picks_path(PackedStringArray(scripted))).is_equal(Roster.SCRATCH_PICKS)
		assert_str(Save.boot_settings_path(PackedStringArray(scripted))).is_equal(Save.SCRATCH_SETTINGS)
	for played in [[], ["--profile=p1"], ["--", "--p1-char=chuck"], ["--", "--demolition"]]:
		assert_str(Roster.boot_picks_path(PackedStringArray(played))).is_equal(Roster.shared_path())
		assert_str(Save.boot_settings_path(PackedStringArray(played))).is_equal("user://settings.json")
	# A "real" picks file with other characters under every profile a run might use.
	var stale := {}
	for profile in ["p1", Save.profile, SuiteSandbox.profile_for("isolation"), "gdunit"]:
		stale[profile] = { "P1": "chuck", "P2": "jeff" }
	var f := FileAccess.open(DIRTY_PICKS, FileAccess.WRITE)
	f.store_string(JSON.stringify(stale))
	f.close()
	Roster.data_path = SuiteSandbox.ROSTER
	Roster.args_override = PackedStringArray(["--gdunit-isolation"])
	Roster.reload()
	assert_str(Roster.pick(P1)).is_equal("chuck")                # the stand-in really is in play
	var before_text := _picks_text()
	SuiteSandbox.enter("isolation")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_str(Roster.pick(P2)).is_equal("chuck")
	main.get_node("UI/Lobby").press_b(P1)
	main.get_node("UI/Lobby").choose(P1, 1)                      # a pick changes: written to the sandbox only
	main.free()
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()
	Players.reset()
	SuiteSandbox.leave()
	assert_str(_picks_text()).is_equal(before_text)
