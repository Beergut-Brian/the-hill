## The Hill plays whoever was picked in the chooser: players, drivers, sleepers and podiums draw the
## Roster pick (the game's own sheet for Jeff / Chuck, a sheet built from the pixel form for anyone
## else), names follow the pick, voices fall back, and the stand-in fixture never ships.
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const STANDIN := "res://tests/fixtures/roster_standin.json"
const PICKS := "user://test_hill_chooser_players.json"
const Lobby := preload("res://scenes/ui/lobby.gd")
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _real := {}
var _game: HillGame
var _main: Node


func before() -> void:
	SuiteSandbox.enter("hill_chooser")   # first: never the real profile, settings or picks file
	_real = {"settings": Save.settings_path, "profile": Save.profile, "picks": Roster.picks_path,
			"data": Roster.data_path}
	Save.settings_path = "user://test_settings_hill_chooser.json"
	Save.reload_settings()
	Roster.picks_path = PICKS
	Roster.data_path = STANDIN
	Game.quit_exits = false


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real.settings
	Save.reload_settings()
	Save.profile = _real.profile
	Save._load()
	DirAccess.remove_absolute(PICKS)
	Roster.picks_path = _real.picks
	Roster.data_path = _real.data
	Roster.args_override = PackedStringArray()
	Roster.reload()
	CharacterSheet.clear()
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))
	Game.quit_exits = true
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	Save.profile = "test_hill_chooser"
	Save.wipe()
	DirAccess.remove_absolute(PICKS)
	Roster.data_path = STANDIN
	_picks([])
	Players.reset()
	Inventory.clear()
	Progress.reset()
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _picks(args: Array) -> void:
	Roster.args_override = PackedStringArray(["--no-picks"] + args)
	Roster.reload()


func _make_game() -> HillGame:
	Game._set_state(Game.State.PLAYING)
	_game = HillGame.new()
	get_tree().root.add_child(_game)
	return _game


func _join(p: int) -> HillPlayer:
	Players.join_virtual(p)
	var node := _game.player_node(p)
	if node == null:
		node = _game.wake(p)
	node.intent_source = func() -> Dictionary: return IDLE
	return node


# --- spawn follows the pick --------------------------------------------------------------------

func test_defaults_are_jeff_and_chuck_on_their_own_sheets() -> void:
	assert_str(SpriteArt.char_of(P1)).is_equal("jeff")
	assert_str(SpriteArt.char_of(P2)).is_equal("chuck")
	assert_str(SpriteArt.char_file(P1)).is_equal("characters/jeff.png")
	assert_str(SpriteArt.char_file(P2)).is_equal("characters/chuck.png")


func test_swapped_picks_swap_the_bodies() -> void:
	_picks(["--p1-char=chuck", "--p2-char=jeff"])
	assert_str(SpriteArt.char_file(P1)).is_equal("characters/chuck.png")
	assert_str(SpriteArt.char_file(P2)).is_equal("characters/jeff.png")
	_make_game()
	var p1 := _join(P1)
	assert_bool(["idle", "air"].has(p1._pose()[0])).is_true()
	assert_str(SpriteArt.char_file(p1.player)).is_equal("characters/chuck.png")
	# The P1 slot keeps P1's colour whoever it plays.
	assert_that(Players.COLOR[p1.player]).is_equal(Players.COLOR[P1])


func test_a_pixel_form_only_character_gets_a_built_sheet() -> void:
	_picks(["--p1-char=pip"])
	assert_str(SpriteArt.char_of(P1)).is_equal("pip")
	var file := SpriteArt.char_file(P1)
	assert_str(file).is_equal("roster/pip.png")
	assert_bool(CharacterSheet.is_built("pip")).is_true()
	assert_bool(SpriteArt.has(file)).is_true()
	# Every row the game's own sheets have, same frame counts.
	var own: Dictionary = SheetSprite.entry("characters/jeff.png").rows
	for anim: String in own:
		assert_int(int(SpriteArt.row(file, anim).get("frames", 0))).is_equal(int(own[anim].frames))
	# Pivot on the feet, every used frame drawn (nothing blank).
	assert_vector(SpriteArt.pivot(file)).is_equal(Vector2(CharacterSheet.PIVOT))
	var img := SpriteArt.texture(file).get_image()
	for anim: String in own:
		var r := SpriteArt.row(file, anim)
		for f in int(r.frames):
			var rect := Rect2i(f * CharacterSheet.FRAME.x, int(r.row) * CharacterSheet.FRAME.y,
					CharacterSheet.FRAME.x, CharacterSheet.FRAME.y)
			assert_bool(img.get_region(rect).is_invisible()).override_failure_message(
					"%s frame %d is blank" % [anim, f]).is_false()


func test_residents_never_become_a_player_body() -> void:
	# A resident sheet (no dig rows) is never used, even if an id matched it.
	assert_str(CharacterSheet.file_of("mole")).is_equal("")
	assert_str(CharacterSheet.file_of("dragon")).is_equal("")
	assert_bool(Roster.has("mole")).is_false()


# --- gear on the picked body -------------------------------------------------------------------

func test_the_stand_in_walks_digs_and_drives_with_its_gear() -> void:
	_picks(["--p1-char=pip"])
	_make_game()
	var p := _join(P1)
	var file := SpriteArt.char_file(P1)
	p.velocity = Vector2(120, 0)
	assert_bool(["walk", "air"].has(p._pose()[0])).is_true()
	p._swing = 0.5
	var dig: Array = p._pose()
	assert_bool(["dig_side", "dig_down"].has(dig[0])).is_true()
	assert_bool(SpriteArt.row(file, dig[0]).is_empty()).is_false()
	p._swing = 0.0
	# Underground in the Loader: the vehicle's nose lamp hangs on the stand-in's node, and the
	# ride frame (head over the cab) comes from the stand-in's sheet.
	p.drive(Progress.vehicle_data(&"front_loader"))
	_game.place_player(P1, &"underground", _game.underground.landing(0) + Vector2(-64, 0))
	assert_object(p.vehicle).is_not_null()
	assert_object(p.get_node_or_null(^"NoseLamp")).is_not_null()
	assert_bool(SpriteArt.row(file, "ride").is_empty()).is_false()
	assert_bool(SpriteArt.row(file, "sleep").is_empty()).is_false()
	# Drawing it all (on foot, driving, a sleeper in the bucket) raises nothing.
	p.queue_redraw()
	await get_tree().process_frame
	p.stop_driving()
	p.queue_redraw()
	await get_tree().process_frame
	assert_object(p.vehicle).is_null()


# --- names follow the pick ---------------------------------------------------------------------

func test_the_game_skin_names_the_pick_not_jeff_and_chuck() -> void:
	var sk := UiStyle.skin()
	assert_str(sk.p1_name).is_equal("")
	assert_str(sk.p2_name).is_equal("")
	assert_str(sk.player_name(P1)).is_equal("JEFF")
	_picks(["--p1-char=pip", "--p2-char=jeff"])
	assert_str(sk.player_name(P1)).is_equal("PIP")
	assert_str(sk.player_name(P2)).is_equal("JEFF")
	# The round card has no character names baked in.
	assert_str(sk.round_card_title.to_upper()).not_contains("JEFF")
	assert_str(sk.round_card_title.to_upper()).not_contains("CHUCK")


func test_podiums_show_and_swap_to_the_pick() -> void:
	_picks(["--p1-char=pip"])
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var lobby: Lobby = _main.get_node("UI/Lobby")
	var who: HillMenuCharacter = (lobby.get_node("Spots/P1/Character") as CharacterSlot).character
	assert_str(who.file()).is_equal("roster/pip.png")
	assert_object(who.sprite).is_not_null()
	var p2: HillMenuCharacter = (lobby.get_node("Spots/P2/Character") as CharacterSlot).character
	assert_str(p2.file()).is_equal("characters/chuck.png")
	# The chooser swaps P1 back to Jeff in place.
	Players.join_virtual(P1)
	lobby.press_b(P1)
	assert_bool(lobby.choose(P1, 1)).is_true()     # pip -> wrap -> jeff
	await get_tree().create_timer(0.3).timeout
	assert_str(Roster.pick(P1)).is_equal("jeff")
	assert_str(who.file()).is_equal("characters/jeff.png")


# --- voices ------------------------------------------------------------------------------------

func test_a_character_without_barks_falls_back_never_to_another_voice() -> void:
	# Nobody in v0.3.0 has barks: every swap falls back to the generic char_swap cue.
	for id in Roster.roster():
		var who := Roster.info(id)
		if who.barks.is_empty():
			assert_bool(Roster.bark(id)).is_false()
		# A character's voice folder is its own, never another character's.
		if who.voice != "":
			assert_str(who.voice).contains("/%s/" % id)
	assert_str(Roster.info("pip").voice).is_equal("")
	assert_bool(Roster.bark("pip")).is_false()


# --- the fixture never ships -------------------------------------------------------------------

func test_the_stand_in_fixture_is_not_exported_or_in_the_real_roster() -> void:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://export_presets.cfg")).is_equal(OK)
	var sections: Array[String] = []
	for s in cfg.get_sections():
		if not s.ends_with(".options"):
			sections.append(s)
	assert_int(sections.size()).is_greater(0)
	for s: String in sections:
		var ex := str(cfg.get_value(s, "exclude_filter", "")).split(",")
		assert_bool(ex.has("tests/*")).override_failure_message("%s does not exclude tests/*" % s).is_true()
		assert_str(str(cfg.get_value(s, "include_filter", ""))).not_contains("tests")
	var real := FileAccess.get_file_as_string("res://data/roster.json")
	assert_str(real).not_contains("tests/")
	assert_str(real).not_contains("\"pip\"")
	# The flag that loads it is ignored when the file is not there (an export).
	assert_str(load("res://scripts/autoload/Debug.gd").roster_data_arg(PackedStringArray(["--roster-data=res://tests/nope.json"]))).is_equal("")
	assert_str(load("res://scripts/autoload/Debug.gd").roster_data_arg(PackedStringArray(["--roster-data=" + STANDIN]))).is_equal(STANDIN)
