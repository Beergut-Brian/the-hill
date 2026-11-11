## Every suite that boots the game or touches a shared file runs inside this: its own save
## profile, settings file and picks file, and the real roster, whatever ran before it (template
## or game suites, in any order, even one that crashed before its after()). Never the family's
## profile, user://settings.json or the launcher's players.json.
##   func before() -> void: SuiteSandbox.enter("lobby")
##   func after() -> void:  SuiteSandbox.leave()
## Read the picks file as file[Save.profile], never file.p1 or file.gdunit.
class_name SuiteSandbox
extends RefCounted

const PROFILE_PREFIX := "gdunit_"
const ROSTER := "res://data/roster.json"

static var _real := {}
static var suite := ""


static func profile_for(name: String) -> String:
	return PROFILE_PREFIX + name


static func settings_for(name: String) -> String:
	return "user://test_settings_%s.json" % name


static func picks_for(name: String) -> String:
	return "user://test_%s_players.json" % name


## Point Save and Roster at this suite's own files, empty, with the real roster and no launch args.
static func enter(name: String, roster_path := ROSTER) -> void:
	if not _real.is_empty():
		leave()   # a suite before us never left: restore first so we keep the real paths
	_real = { "profile": Save.profile, "settings": Save.settings_path, "picks": Roster.picks_path,
			"data": Roster.data_path, "args": Roster.args_override }
	suite = name
	Save.use_profile(profile_for(name))
	Save.wipe()
	Save.settings_path = settings_for(name)
	Save.wipe_settings()
	Roster.picks_path = picks_for(name)
	_remove_picks()
	Roster.data_path = roster_path
	Roster.args_override = PackedStringArray(["--gdunit-" + name])   # not this run's real args
	Roster.reload()


## Remove this suite's files and put the real paths back.
static func leave() -> void:
	if _real.is_empty():
		return
	Save.wipe_settings()
	_remove_picks()
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % Save.profile))
	Save.settings_path = _real.settings
	Save.reload_settings()
	Save.use_profile(_real.profile)
	Roster.picks_path = _real.picks
	Roster.data_path = _real.data
	Roster.args_override = _real.args
	_real = {}
	suite = ""
	Roster.reload()


static func _remove_picks() -> void:
	for f in [Roster.picks_path, Roster.picks_path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
