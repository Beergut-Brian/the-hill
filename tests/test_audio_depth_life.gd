## Audio rows A-16, A-17 (audio-rows-1, 2026-11-11): the depth-life cues heard in the real game, not
## only resolved to files. A Topsoil worm popping out to wave plays `worm_boop` (boop + giggle), the
## first frozen fish dug out flops (`fish_flop`), and a later fish that wiggles free and swims off
## plays `fish_free` (ice crack, splash, bubbles) as well as its flop. Real HillGame, real dig.
class_name TestAudioDepthLife
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}

var _game: HillGame
var _real_profile := ""
var _real_settings := ""
var _intent := {}
var _log := "--cue-log" in OS.get_cmdline_args() + OS.get_cmdline_user_args()


func before() -> void:
	_real_profile = Save.profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_audio_depth_life.json"
	Save.reload_settings()
	Game.quit_exits = false


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.flush()
	Save.profile = _real_profile
	Save._load()
	Game.quit_exits = true


func before_test() -> void:
	Save.profile = "test_audio_depth_life"
	Save.wipe()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.PLAYING)
	_intent = {P1: IDLE.duplicate()}
	_quiet()


func after_test() -> void:
	if is_instance_valid(_game):
		_game.free()
	Players.reset()
	Inventory.clear()
	Progress.reset()
	Game._set_state(Game.State.LOBBY)
	_quiet()


func _quiet() -> void:
	for p in Audio._pool:
		p.stop()
	Audio._voice.stop()
	Audio.reset_caps()


func _make() -> HillPlayer:
	_game = HillGame.new()
	_game.start_players = [P1]
	get_tree().root.add_child(_game)
	Players.join_virtual(P1)
	var node := _game.player_node(P1)
	if node == null:
		node = _game.wake(P1)
	node.intent_source = func() -> Dictionary: return _intent[P1]
	return node


func _put(cell: Vector2i) -> HillPlayer:
	var p := _game.player_node(P1)
	_game.place_player(P1, HillGame.UNDERGROUND, Vector2((cell.x + 0.5) * 16.0, cell.y * 16.0 - 1.0))
	p.velocity = Vector2.ZERO
	return p


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return n


## The SFX cues sounding right now (and printed with --cue-log, the proof run in handoff/).
func _sounding(moment: String) -> Array[String]:
	var out: Array[String] = []
	for p in Audio._pool:
		if p.playing:
			out.append(String(p.get_meta(&"cue", "?")))
	out.sort()
	if _log:
		print("cue-log: %s -> %s" % [moment, ", ".join(out)])
	return out


func test_a_worm_popping_out_to_wave_boops() -> void:
	var p := _make()
	var life := _game.underground.life
	var room: Rect2i = _game.underground.generator.landings[0]
	var wall := Vector2i(room.position.x - 1, room.end.y - 1)
	# Far from both walls: no worm, no boop.
	_put(Vector2i(room.position.x + 7, room.end.y))
	p.set_physics_process(false)
	await _physics(30)
	assert_bool(life.worms.has(wall)).is_false()
	_quiet()
	await _physics(2)
	assert_int(Audio.playing_count("worm_boop")).is_equal(0)
	# Beside the left wall: the worm pops out, and the pop is the worm's boop (not the generic pop).
	p.set_physics_process(true)
	_put(Vector2i(room.position.x, room.end.y))
	p.set_physics_process(false)
	var n := await _until(func() -> bool: return life.worms.has(wall), 30)
	assert_int(n).is_less(30)
	var cues := _sounding("worm pops out at %s" % wall)
	assert_bool(cues.has("worm_boop")).override_failure_message("heard %s" % [cues]).is_true()
	assert_bool(cues.has("pop")).override_failure_message("heard %s" % [cues]).is_false()
	p.set_physics_process(true)


func test_a_dug_fish_flops_and_a_later_one_cracks_free() -> void:
	var p := _make()
	var u := _game.underground
	var g := u.generator
	assert_int(g.fish_cells.size()).is_greater_equal(2)
	# The first fish: the treasure. It flops; nothing swims off, so no crack.
	var a: Vector2i = g.fish_cells[0]
	_put(a)
	p.set_physics_process(false)
	await _physics(2)
	_quiet()
	u.world.dig(a, [Vector2i.ZERO], P1)
	var first := _sounding("first fish dug at %s" % a)
	assert_bool(Progress.has_treasure(HillGenerator.FISH)).is_true()
	assert_bool(first.has("fish_flop")).override_failure_message("heard %s" % [first]).is_true()
	assert_bool(first.has("fish_free")).is_false()
	# A later fish wiggles free and swims off: its flop and the ice-crack splash, not `splash`.
	var b: Vector2i = g.fish_cells[1]
	p.set_physics_process(true)
	_put(b)
	p.set_physics_process(false)
	await _physics(2)
	_quiet()
	u.world.dig(b, [Vector2i.ZERO], P1)
	var later := _sounding("later fish dug at %s" % b)
	assert_int(u.life._fish_free.size()).is_equal(1)
	assert_bool(later.has("fish_flop")).override_failure_message("heard %s" % [later]).is_true()
	assert_bool(later.has("fish_free")).override_failure_message("heard %s" % [later]).is_true()
	assert_bool(later.has("splash")).is_false()
	p.set_physics_process(true)
