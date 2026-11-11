## scripts/tools/sync_characters.sh against a throwaway characters repo and a throwaway game
## (SYNC_CHARACTERS_ROOT): the chooser's catchphrase is vendored (docs/ui.md "Chooser voice").
## Needs bash, git and python3 (skips without).
class_name TestSyncCharacters
extends GdUnitTestSuite

const BASE := "user://test_sync_characters"

var _base := ""
var _lib := ""
var _game := ""


func before() -> void:
	SuiteSandbox.enter("sync_characters")   # first: never the real profile, settings or picks file
	_base = ProjectSettings.globalize_path(BASE)
	_lib = _base.path_join("lib")
	_game = _base.path_join("game")


func after() -> void:
	_wipe()
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(_lib)
	_put(_lib.path_join("models/sprocket.glb"), "not really a glb")
	_put(_game.path_join("assets/CREDITS.md"), "# Credits\n")


func _wipe() -> void:
	if _base != "" and _base.ends_with("test_sync_characters") and DirAccess.dir_exists_absolute(_base):
		OS.execute("rm", ["-rf", "--", _base])


func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _has(rel: String) -> bool:
	var p := _game.path_join(rel)
	return FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p)


func _sh(cmd: String, out: Array = []) -> int:
	return OS.execute("bash", ["-c", cmd + " 2>&1"], out)


func _tools_missing() -> bool:
	return _sh("command -v git && command -v python3") != 0


func _sync(tag: String) -> Dictionary:
	var out := []
	var tool := ProjectSettings.globalize_path("res://scripts/tools/sync_characters.sh")
	var code := _sh("SYNC_CHARACTERS_ROOT='%s' bash '%s' '%s' %s" % [_game, tool, _lib, tag], out)
	return { "code": code, "log": "\n".join(out) }


## A character with voice/lib/catchphrase_big.ogg gets voice/catchphrase.ogg and a "catchphrase"
## path (only that file from lib/, and it is not a bark); one without gets "".
func test_vendors_the_catchphrase() -> void:
	if _tools_missing():
		push_warning("test_sync_characters: no git/python3 here, skipped")
		return
	for f in ["cheer.ogg", "lib/catchphrase_big.ogg", "lib/catchphrase_calm.ogg", "lib/sigh.ogg"]:
		_put(_lib.path_join("voices/whistle/" + f), "ogg " + f)
	_put(_lib.path_join("characters.json"), JSON.stringify({ "roster": ["sprocket", "whistle"],
			"defaults": { "P1": "sprocket", "P2": "whistle" }, "player_colours": {},
			"characters": [{ "id": "sprocket", "name": "Sprocket", "playable": true,
				"model_3d": "models/sprocket.glb" },
				{ "id": "whistle", "name": "Whistle", "playable": true, "voice": "voices/whistle/" }] }))
	_sh("cd '%s' && git init -q && git add -A && git -c user.name=t -c user.email=t@t.invalid " % _lib
			+ "-c commit.gpgsign=false commit -qm voice && git tag v9.1.0")
	var r := _sync("v9.1.0")
	assert_int(r.code).override_failure_message(r.log).is_equal(0)
	var d = JSON.parse_string(FileAccess.get_file_as_string(_game.path_join("data/roster.json")))
	var w: Dictionary = d.characters.whistle
	assert_str(w.catchphrase).is_equal("res://assets/characters/whistle/voice/catchphrase.ogg")
	assert_array(w.barks).is_equal(["cheer"])
	assert_str(d.characters.sprocket.catchphrase).is_equal("")
	var phrase := _game.path_join("assets/characters/whistle/voice/catchphrase.ogg")
	assert_str(FileAccess.get_file_as_string(phrase)).is_equal("ogg lib/catchphrase_big.ogg")
	assert_bool(_has("assets/characters/whistle/voice/lib")).is_false()
	assert_bool(_has("assets/characters/whistle/voice/sigh.ogg")).is_false()
	assert_bool(_has("assets/characters/whistle/voice/catchphrase_calm.ogg")).is_false()
	var credits := FileAccess.get_file_as_string(_game.path_join("assets/CREDITS.md"))
	assert_str(credits).contains("characters/whistle/voice/catchphrase.ogg")


## Residents listed in scripts/tools/sync_residents.txt get only their voice barks (top-level
## voice/*.ogg: no glb, no lib/, no source/), a "residents" block and CREDITS rows. A resident with
## no recorded audio gets no folder (a stale one goes), a playable id in the list is skipped, and a
## rerun is idempotent and leaves unrelated files alone.
func test_vendors_resident_voice_packs_only_when_recorded() -> void:
	if _tools_missing():
		push_warning("test_sync_characters: no git/python3 here, skipped")
		return
	for f in ["burrow_oh.ogg", "burrow_eep.ogg", "lib/cheer.ogg", "source/master.ogg", "README.md"]:
		_put(_lib.path_join("characters/burrow/voice/" + f), "ogg " + f)
	_put(_lib.path_join("characters/quiet/voice/README.md"), "to be rendered")
	_put(_lib.path_join("models/burrow.glb"), "not really a glb")
	_put(_lib.path_join("characters.json"), JSON.stringify({ "roster": ["sprocket"],
			"defaults": { "P1": "sprocket" }, "player_colours": {},
			"characters": [{ "id": "sprocket", "name": "Sprocket", "playable": true,
				"model_3d": "models/sprocket.glb" },
				{ "id": "burrow", "name": "The Burrower", "playable": false, "model_3d": "models/burrow.glb",
					"voice": "characters/burrow/voice/" },
				{ "id": "quiet", "name": "The Quiet One", "playable": false, "voice": "characters/quiet/voice/" }] }))
	_sh("cd '%s' && git init -q && git add -A && git -c user.name=t -c user.email=t@t.invalid " % _lib
			+ "-c commit.gpgsign=false commit -qm residents && git tag v9.2.0")
	_put(_game.path_join("scripts/tools/sync_residents.txt"), "# residents\nburrow\nquiet  # none yet\nsprocket\n")
	_put(_game.path_join("assets/characters/quiet/voice/old.ogg"), "stale")
	_put(_game.path_join("assets/sprites/keep.txt"), "not ours")
	var r := _sync("v9.2.0")
	assert_int(r.code).override_failure_message(r.log).is_equal(0)
	var d = JSON.parse_string(FileAccess.get_file_as_string(_game.path_join("data/roster.json")))
	assert_array(d.roster).is_equal(["sprocket"])
	assert_bool(d.characters.has("burrow")).is_false()
	assert_array(d.residents.keys()).is_equal(["burrow"])
	assert_str(d.residents.burrow.voice).is_equal("res://assets/characters/burrow/voice/")
	assert_array(d.residents.burrow.barks).is_equal(["burrow_eep", "burrow_oh"])
	assert_str(FileAccess.get_file_as_string(_game.path_join("assets/characters/burrow/voice/burrow_oh.ogg"))) \
			.is_equal("ogg burrow_oh.ogg")
	for gone in ["assets/characters/burrow/burrow.glb", "assets/characters/burrow/voice/lib",
			"assets/characters/burrow/voice/master.ogg", "assets/characters/burrow/voice/cheer.ogg",
			"assets/characters/quiet"]:
		assert_bool(_has(gone)).override_failure_message(gone).is_false()
	assert_bool(_has("assets/sprites/keep.txt")).is_true()
	var credits := FileAccess.get_file_as_string(_game.path_join("assets/CREDITS.md"))
	assert_str(credits).contains("characters/burrow/voice/*.ogg").contains("The Burrower voice barks")
	# Rerun: same result, nothing else touched.
	var before_json := FileAccess.get_file_as_string(_game.path_join("data/roster.json"))
	r = _sync("v9.2.0")
	assert_int(r.code).override_failure_message(r.log).is_equal(0)
	assert_str(FileAccess.get_file_as_string(_game.path_join("data/roster.json"))).is_equal(before_json)
	assert_str(FileAccess.get_file_as_string(_game.path_join("assets/CREDITS.md"))).is_equal(credits)
	assert_bool(_has("assets/sprites/keep.txt")).is_true()
