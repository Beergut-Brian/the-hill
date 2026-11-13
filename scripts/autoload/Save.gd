## JSON save under user://saves/<profile>.json. Autoload: Save.
## The launcher passes --profile=<id>; default "p1".
## New Hill (start_new) never deletes: the current save is renamed to
## <profile>.backup-<YYYYMMDD-HHMM>.json beside it (the newest BACKUPS_KEPT are kept) and play starts
## from an empty save. restore_last() swaps the newest backup back in (the save it replaces becomes
## a backup in turn, so a restore can be undone the same way).
## Settings (volumes, screen shake, solo playtest) are per install, not per profile:
## user://settings.json, written on every change.
extends Node

signal saved()
signal loaded()
## start_new() or restore_last() changed which world the save holds (menus refresh on it).
signal slot_changed()

const BACKUPS_KEPT := 3

var profile: String = "p1"
## Tests point this at a scratch folder so they never touch a real profile's save or backups.
var saves_dir := "user://saves"
var _data: Dictionary = {}
var _dirty := false
## Tests point this somewhere else so they never touch the real settings. A test or scripted run
## (scripted_run()) starts on a scratch file, so nothing it changes reaches the family's settings.
var settings_path := boot_settings_path(OS.get_cmdline_args() + OS.get_cmdline_user_args())
var _settings: Dictionary = {}


func _ready() -> void:
	profile = profile_from_args(OS.get_cmdline_args() + OS.get_cmdline_user_args(), profile)
	_load()
	reload_settings()


## The launcher passes --profile=<id> without a "--" separator, so Godot puts it in
## get_cmdline_args(), not get_cmdline_user_args(); accept it in either.
static func profile_from_args(args: PackedStringArray, default: String) -> String:
	var out := default
	for arg in args:
		if arg.begins_with("--profile="):
			var id := arg.trim_prefix("--profile=").strip_edges()
			if id.is_valid_identifier():   # keeps it a plain file name under user://saves
				out = id
	return out


## Flags that mean nobody is playing: gdUnit, --shots / --screenshot-after frames, --ui= / --demo /
## --demo-beat= showcases. Such a run must never read or write the files the family's games share.
const SCRIPTED_FLAGS := ["--shots=", "--screenshot-after=", "--ui=", "--demo", "--demo-beat="]
const SCRATCH_SETTINGS := "user://scratch_settings.json"


static func scripted_run(args: PackedStringArray) -> bool:
	for a in args:
		if a.contains("GdUnitCmdTool") or a.contains("addons/gdUnit4"):
			return true
		for flag in SCRIPTED_FLAGS:
			if a == flag or (flag.ends_with("=") and a.begins_with(flag)):
				return true
	return false


static func boot_settings_path(args: PackedStringArray) -> String:
	return SCRATCH_SETTINGS if scripted_run(args) else "user://settings.json"


func get_value(key: String, default = null):
	return _data.get(key, default)


func set_value(key: String, value) -> void:
	_data[key] = value
	_dirty = true


func flush() -> void:
	if not _dirty:
		return
	DirAccess.make_dir_recursive_absolute(saves_dir)
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not open %s" % _path())
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	_dirty = false
	saved.emit()


func get_setting(key: String, default = null):
	return _settings.get(key, default)


func set_setting(key: String, value) -> void:
	_settings[key] = value
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not open %s" % settings_path)
		return
	f.store_string(JSON.stringify(_settings, "\t"))
	f.close()


func reload_settings() -> void:
	_settings = {}
	if FileAccess.file_exists(settings_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if parsed is Dictionary:
			_settings = parsed


func wipe_settings() -> void:
	_settings = {}
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)


## Switch to another profile's save (the test sandbox): flushes the current one, loads the new.
func use_profile(id: String) -> void:
	flush()
	profile = id
	_load()


func wipe() -> void:
	_data = {}
	_dirty = true
	flush()


func _path() -> String:
	return "%s/%s.json" % [saves_dir, profile]


## The profile holds a world (an empty or missing save is a first run).
func has_save() -> bool:
	return not _data.is_empty()


## This profile's backups, newest first (full paths).
func backups() -> PackedStringArray:
	var out := PackedStringArray()
	var prefix := profile + ".backup-"
	if not DirAccess.dir_exists_absolute(saves_dir):
		return out
	for f in DirAccess.get_files_at(saves_dir):
		if f.begins_with(prefix) and f.ends_with(".json"):
			out.append("%s/%s" % [saves_dir, f])
	out.sort()
	out.reverse()
	return out


func has_backup() -> bool:
	return not backups().is_empty()


## A backup's contents (or the save's own with path ""), {} when unreadable.
func read_save(path := "") -> Dictionary:
	if path == "":
		return _data.duplicate()
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## New Hill: the current save becomes a backup, the profile starts empty (the next game builds a
## fresh world). Returns the backup's path, "" when there was nothing to keep.
func start_new() -> String:
	flush()
	var kept := ""
	if has_save() and FileAccess.file_exists(_path()):
		kept = _backup_current()
	_data = {}
	_dirty = false
	_trim_backups()
	slot_changed.emit()
	return kept


## Restore last hill: the newest backup becomes the save again; the save it replaces (if it holds a
## world) becomes the newest backup. False when there is no backup.
func restore_last() -> bool:
	var list := backups()
	if list.is_empty():
		return false
	flush()
	var newest := list[0]
	var holding := "%s/%s.restoring.json" % [saves_dir, profile]
	if DirAccess.rename_absolute(newest, holding) != OK:
		push_warning("Save: could not move %s" % newest)
		return false
	if has_save() and FileAccess.file_exists(_path()):
		_backup_current()
	DirAccess.rename_absolute(holding, _path())
	_load()
	_dirty = false
	_trim_backups()
	slot_changed.emit()
	return true


## Renames the save file to the next backup name. Two in one minute get b, c, ... (sorts newer).
func _backup_current() -> String:
	var d := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute]
	var base := "%s/%s.backup-%s" % [saves_dir, profile, stamp]
	var path := base + ".json"
	var n := 1
	while FileAccess.file_exists(path):
		path = "%s%s.json" % [base, char(97 + n)]   # ...-1944b.json
		n += 1
	if DirAccess.rename_absolute(_path(), path) != OK:
		push_warning("Save: could not back up %s" % _path())
		return ""
	return path


## Only the newest BACKUPS_KEPT backups stay.
func _trim_backups() -> void:
	var list := backups()
	for i in range(BACKUPS_KEPT, list.size()):
		DirAccess.remove_absolute(list[i])


func _load() -> void:
	if not FileAccess.file_exists(_path()):
		_data = {}
		return
	var text := FileAccess.get_file_as_string(_path())
	var parsed = JSON.parse_string(text)
	_data = parsed if parsed is Dictionary else {}
	loaded.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()
