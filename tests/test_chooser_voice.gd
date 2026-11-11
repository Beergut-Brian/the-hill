## The chooser voice (docs/ui.md "Chooser voice"): Roster.catchphrase() and its bark fallback, and
## the lobby saying the podium's catchphrase once, SAY_SETTLE s after the last left / right.
## Own settings and picks files and a fixture roster (tests/fixtures/roster_voice.json):
## ana (catchphrase + bark), bo (bark only), cy (catchphrase file missing + bark), dee (nothing),
## eve (catchphrase only). P1 is ana, P2 is bo.
class_name TestChooserVoice
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const VOICE := "res://tests/fixtures/roster_voice.json"
const PHRASE := "res://tests/fixtures/voice/catchphrase.ogg"
const BARK := "res://tests/fixtures/voice/cheer.ogg"
const PICKS := "user://test_chooser_voice_players.json"

var _main: Node
var _said: Array = []
var _real := {}


func before() -> void:
	SuiteSandbox.enter("chooser_voice")   # first: never the real profile, settings or picks file
	_real = { "settings": Save.settings_path, "picks": Roster.picks_path, "data": Roster.data_path }
	Save.settings_path = "user://test_settings_chooser_voice.json"
	Save.reload_settings()
	Roster.picks_path = PICKS
	Roster.data_path = VOICE
	Roster.said.connect(_on_said)


func after() -> void:
	Roster.said.disconnect(_on_said)
	Save.wipe_settings()
	Save.settings_path = _real.settings
	Save.reload_settings()
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(PICKS)
	Roster.picks_path = _real.picks
	Roster.data_path = _real.data
	Roster.args_override = PackedStringArray()
	Roster.reload()
	SuiteSandbox.leave()   # last: the real profile, settings and picks come back


func before_test() -> void:
	Save.wipe_settings()
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(PICKS)
	Roster.data_path = VOICE
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	_said.clear()


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	UiStyle.use_skin(null)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	for p in [-1, P1, P2]:
		Roster.voice_player(p).stop()
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()


func _on_said(player: int, id: String, path: String) -> void:
	_said.append([player, id, path])


func _boot() -> Lobby:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main.get_node("UI/Lobby")


## Joined and un-readied, with the join's own catchphrase already said and forgotten.
func _join_unready(lobby: Lobby, p: int) -> void:
	Players.join_virtual(p)
	lobby.press_b(p)
	lobby.voice_step(1.0)
	_said.clear()


# --- Roster.catchphrase() ---

func test_catchphrase_plays_the_file() -> void:
	assert_bool(Roster.catchphrase("ana")).is_true()
	assert_str(Roster.last_said[-1]).is_equal(PHRASE)
	assert_object(Roster.voice_player().stream).is_equal(load(PHRASE))


func test_catchphrase_falls_back_to_bark() -> void:
	assert_bool(Roster.catchphrase("bo")).is_true()     # no catchphrase: a bark
	assert_str(Roster.last_said[-1]).is_equal(BARK)
	assert_bool(Roster.catchphrase("cy")).is_true()     # catchphrase file missing: a bark
	assert_str(Roster.last_said[-1]).is_equal(BARK)


func test_catchphrase_false_with_no_voice() -> void:
	assert_bool(Roster.catchphrase("dee")).is_false()
	assert_bool(Roster.catchphrase("nobody")).is_false()
	assert_array(_said).is_empty()


func test_catchphrase_is_not_a_bark() -> void:
	assert_array(Roster.info("ana").barks).is_equal(["cheer"])
	assert_bool(Roster.bark("eve")).is_false()          # a catchphrase alone is no bark
	assert_bool(Roster.catchphrase("eve")).is_true()


func test_each_slot_has_its_own_voice() -> void:
	assert_object(Roster.voice_player(P1)).is_not_same(Roster.voice_player(P2))
	assert_object(Roster.voice_player(P1)).is_not_same(Roster.voice_player())
	assert_bool(Roster.catchphrase("ana", P1)).is_true()
	assert_bool(Roster.catchphrase("bo", P2)).is_true()
	assert_object(Roster.voice_player(P1).stream).is_equal(load(PHRASE))   # P2 did not cut it
	assert_array(_said).is_equal([[P1, "ana", PHRASE], [P2, "bo", BARK]])
	var b1 := AudioServer.get_bus_index(Roster.voice_player(P1).bus)
	var b2 := AudioServer.get_bus_index(Roster.voice_player(P2).bus)
	assert_float((AudioServer.get_bus_effect(b1, 0) as AudioEffectPanner).pan).is_less(0.0)
	assert_float((AudioServer.get_bus_effect(b2, 0) as AudioEffectPanner).pan).is_greater(0.0)


# --- the lobby chooser ---

func test_three_fast_steps_say_only_the_last_after_the_settle() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	for i in 3:                                          # ana -> cy -> dee -> eve (bo is P2's)
		if i > 0:
			lobby.voice_step(0.1)                        # faster than the settle
		assert_bool(lobby.choose(P1, 1)).is_true()
	assert_str(Roster.pick(P1)).is_equal("eve")
	assert_array(_said).is_empty()                       # nothing while scrolling
	lobby.voice_step(Lobby.SAY_SETTLE - 0.05)
	assert_array(_said).is_empty()
	lobby.voice_step(0.1)
	assert_array(_said).is_equal([[P1, "eve", PHRASE]])


func test_standing_still_never_repeats() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	lobby.choose(P1, 1)
	lobby.voice_step(Lobby.SAY_SETTLE + 0.01)
	assert_int(_said.size()).is_equal(1)
	for i in 20:
		lobby.voice_step(0.5)
	assert_int(_said.size()).is_equal(1)
	assert_bool(lobby.say_pending(P1)).is_false()


func test_scrolling_back_says_it_again() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	lobby.choose(P1, -1)                                 # ana -> eve
	lobby.voice_step(1.0)
	lobby.choose(P1, 1)                                  # eve -> ana
	lobby.voice_step(1.0)
	lobby.choose(P1, -1)                                 # ana -> eve again
	lobby.voice_step(1.0)
	assert_array(_said).is_equal([[P1, "eve", PHRASE], [P1, "ana", PHRASE], [P1, "eve", PHRASE]])


func test_a_head_shake_says_nothing() -> void:
	Roster.data_path = "res://tests/fixtures/roster_two.json"
	Roster.reload()
	var lobby := _boot()
	Players.join_virtual(P2)
	_join_unready(lobby, P1)
	assert_bool(lobby.choose(P1, 1)).is_false()          # nobody free
	assert_bool(lobby.say_pending(P1)).is_false()


func test_joining_says_the_pick_once() -> void:
	var lobby := _boot()
	Players.join_virtual(P1)
	assert_array(_said).is_empty()
	lobby.voice_step(Lobby.SAY_SETTLE + 0.01)
	assert_array(_said).is_equal([[P1, "ana", PHRASE]])
	assert_bool(lobby.readied[P1]).is_true()             # the join still readies, as before
	lobby.voice_step(1.0)
	assert_int(_said.size()).is_equal(1)


func test_two_players_each_on_their_own_voice() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	_join_unready(lobby, P2)
	lobby.choose(P1, 1)                                  # ana -> cy
	lobby.choose(P2, 1)                                  # bo -> dee
	lobby.choose(P2, 1)                                  # dee -> eve
	lobby.voice_step(Lobby.SAY_SETTLE + 0.01)
	assert_int(_said.size()).is_equal(2)
	assert_array(_said).contains([[P1, "cy", BARK], [P2, "eve", PHRASE]])


func test_leaving_cancels_a_pending_line() -> void:
	var lobby := _boot()
	_join_unready(lobby, P1)
	lobby.choose(P1, 1)
	lobby._on_player_left(P1)                            # as Players.player_left does
	lobby.voice_step(1.0)
	assert_array(_said).is_empty()
