## Launch-readiness (hill-launch-ready-1): what ships in the export, and the lobby's hold-to-start
## tag. The session flow itself is framed by tests/fixtures/session_flow.tscn and soaked by
## tests/fixtures/soak.tscn (both need a real run, see docs/launch-checklist.md).
extends GdUnitTestSuite

const LobbySpot := preload("res://scenes/ui/lobby_spot.gd")
## Names of real people that have been in this repo's notes. None may ship in a build.
const PEOPLE := ["kaden", "gary"]


func _export_sections() -> Array[String]:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://export_presets.cfg")).is_equal(OK)
	var out: Array[String] = []
	for s in cfg.get_sections():
		if not s.ends_with(".options"):
			out.append(s)
	return out


## GAME.md and the other notes hold the producer's and the family's notes: no export packs them.
func test_no_design_notes_ship_in_the_export() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var sections := _export_sections()
	assert_int(sections.size()).is_greater(0)
	for s: String in sections:
		var inc := str(cfg.get_value(s, "include_filter", ""))
		assert_str(inc).not_contains(".md")
		var ex := str(cfg.get_value(s, "exclude_filter", "")).split(",")
		for folder in ["docs/*", "playtests/*", "tests/*"]:
			assert_bool(ex.has(folder)).override_failure_message("%s does not exclude %s" % [s, folder]).is_true()


## Everything the include_filter packs as-is (data/**/*.json, store/*) names no real person.
func test_shipped_data_names_no_real_people() -> void:
	var files: Array[String] = []
	_json_under("res://data", files)
	_json_under("res://store", files)
	assert_bool(files.has("res://data/story/lines.json")).is_true()
	for path in files:
		var text := FileAccess.get_file_as_string(path).to_lower()
		for who: String in PEOPLE:
			assert_bool(text.contains(who)) \
					.override_failure_message("%s names '%s'" % [path, who]).is_false()


func _json_under(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".json"):   # what include_filter packs; .md notes stay behind
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_json_under(dir_path.path_join(d), out)


## The READY! stamp sat on top of the "STARTING SOLO" tag while A was held on Play (frame
## alone_02_holding_a_alone.png): it steps aside for the hold and comes back when A is let go.
func test_the_ready_stamp_steps_aside_while_a_is_held_to_start_alone() -> void:
	var spot: Control = auto_free(LobbySpot.new())
	spot.joined = true
	spot.readied = true
	assert_bool(spot.shows_stamp()).is_true()
	spot.hold = 0.4
	assert_bool(spot.shows_stamp()).is_false()
	spot.hold = 0.0
	assert_bool(spot.shows_stamp()).is_true()
	spot.readied = false
	assert_bool(spot.shows_stamp()).is_false()
