## A-15 / P-06 (barks-personality-1): every bark trigger fires on something the player can see,
## shows a picture bubble over the speaker, and its cooldown (read from a scratch BarkTuning file,
## never data/barks.tres) holds it back until it is due again.
class_name TestBarks
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SCRATCH := "user://test_barks_tuning.tres"
const NO_PACKS := "res://tests/fixtures/voice_packs_none/"


class FakeDirector extends RefCounted:
	var scenes := {}

	func scene_of(p: int) -> StringName:
		return scenes.get(p, &"")


class FakePlayer extends Node2D:
	var vehicle = null
	var velocity := Vector2.ZERO


class FakeTown extends Node2D:
	var sprites := {}
	var talking := {}

	func sprite_of(id: StringName) -> Node2D:
		return sprites.get(id)

	func saying(id: StringName) -> Array:
		return talking.get(id, [])


class FakeResidents extends Node2D:
	var mole: Node2D
	var foreman: Node2D
	var dragon: Node2D


class FakeUnderground extends Node2D:
	var residents: FakeResidents


class FakeGame extends Node2D:
	var players := {}
	var director := FakeDirector.new()
	var town: FakeTown
	var underground: FakeUnderground
	var story = null


var _game: FakeGame
var _barks: HillBarks
var _picks := {}


func before() -> void:
	SuiteSandbox.enter("barks")
	var t := BarkTuning.new()     # the scratch settings file: short, distinct cooldowns
	t.rock_every = 12.0           # (all above Audio.BARK_REPEAT, Audio's own same-line cap)
	t.narrate_every = 9.0
	t.narrate_speed = 0.5
	t.near_radius = 50.0
	t.mole_every = 10.0
	t.foreman_every = 11.0
	t.dragon_every = 13.0
	t.bubble_secs = 1.0
	assert_int(ResourceSaver.save(t, SCRATCH)).is_equal(OK)


func after() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	SuiteSandbox.leave()


func before_test() -> void:
	_picks = Roster._picks.duplicate()
	Roster._picks[P1] = "jeff"
	Roster._picks[P2] = "chuck"
	Audio.pack_root = NO_PACKS
	Audio._voice.stop()
	Audio.reset_caps()
	Audio.advance(30.0)
	_game = FakeGame.new()
	_game.town = FakeTown.new()
	_game.add_child(_game.town)
	_game.underground = FakeUnderground.new()
	_game.underground.residents = FakeResidents.new()
	_game.underground.add_child(_game.underground.residents)
	_game.add_child(_game.underground)
	for p in [P1, P2]:
		var pl := FakePlayer.new()
		pl.position = Vector2(-1000, -1000)     # far from everyone
		_game.add_child(pl)
		_game.players[p] = pl
	_barks = HillBarks.new()
	_barks.game = _game
	_barks.tuning_path = SCRATCH
	_game.add_child(_barks)
	get_tree().root.add_child(_game)
	_barks.set_physics_process(false)    # the test drives the clock


func after_test() -> void:
	Roster._picks = _picks
	Audio.pack_root = Audio.CHARACTERS_DIR
	Audio._voice.stop()
	if is_instance_valid(_game):
		_game.free()


## Lets Audio's one-voice gap pass (the line ended) and moves both clocks on.
func _pass(secs: float) -> void:
	Audio._voice.stop()
	Audio.advance(secs)
	_barks.step(secs)


func _count(who: String, cue: String) -> int:
	return _barks.fired.filter(func(f: Dictionary) -> bool: return f.who == who and f.cue == cue).size()


func _resident(id: StringName, at: Vector2, under := false) -> Node2D:
	var n := Node2D.new()
	n.position = at
	if under:
		_game.underground.residents.set("foreman" if id == &"gnome_foreman" else String(id), n)
		_game.underground.residents.add_child(n)
	else:
		_game.town.sprites[id] = n
		_game.town.add_child(n)
	return n


func test_the_scratch_tuning_is_read_and_sets_each_cooldown() -> void:
	assert_float(_barks.tuning.rock_every).is_equal(12.0)
	assert_float(_barks.tuning.cooldown("mole/oh_dear")).is_equal(10.0)
	assert_float(_barks.tuning.cooldown("gnome_foreman/mutter")).is_equal(11.0)
	assert_float(_barks.tuning.cooldown("dragon/rumble")).is_equal(13.0)
	assert_float(BarkTuning.load_from("res://no/such/file.tres").rock_every).is_equal(BarkTuning.new().rock_every)


func test_a_bark_waits_for_its_cooldown_and_never_repeats_every_frame() -> void:
	var mole := _resident(&"mole", Vector2(100, 0))
	_game.players[P1].position = Vector2(110, 0)
	for i in 60:     # one second of frames standing next to the Mole
		_pass(1.0 / 60.0)
	assert_int(_count("mole", "oh_dear")).is_equal(1)
	_pass(8.0)      # 9 s in: still inside the 10 s cooldown (Audio's own gaps have passed)
	assert_int(_count("mole", "oh_dear")).is_equal(1)
	_pass(1.5)
	assert_int(_count("mole", "oh_dear")).is_equal(2)
	assert_bool(_barks.ready_for("mole/oh_dear")).is_false()
	assert_object(mole).is_not_null()


func test_jeff_names_a_rock_he_digs_up_and_shows_it() -> void:
	_game.players[P1].position = Vector2(300, 300)
	Events.tile_dug.emit(Vector2i(1, 1), &"dirt", P1)       # dirt is not a rock
	assert_int(_count("jeff", "rock_name")).is_equal(0)
	Events.tile_dug.emit(Vector2i(1, 1), &"stone", P2)      # Chuck does not name rocks
	assert_int(_count("jeff", "rock_name")).is_equal(0)
	Events.tile_dug.emit(Vector2i(1, 1), &"stone", P1)
	assert_int(_count("jeff", "rock_name")).is_equal(1)
	var b := _barks.bubbles()
	assert_int(b.size()).is_equal(1)
	assert_object(b[0].speaker).is_same(_game.players[P1])
	assert_array(b[0].pics).contains([&"rock"])
	_pass(3.0)
	Events.tile_dug.emit(Vector2i(2, 1), &"stone", P1)      # same kind, inside the cooldown
	assert_int(_count("jeff", "rock_name")).is_equal(1)
	Events.tile_dug.emit(Vector2i(3, 1), &"clay", P1)       # new, but Audio's same-line cap holds
	assert_int(_count("jeff", "rock_name")).is_equal(1)
	_pass(6.0)
	Events.tile_dug.emit(Vector2i(3, 2), &"clay", P1)       # a new kind skips the rock cooldown
	assert_int(_count("jeff", "rock_name")).is_equal(2)
	Events.tile_dug.emit(Vector2i(4, 1), &"stone", P1)      # known kind: waits for the cooldown
	assert_int(_count("jeff", "rock_name")).is_equal(2)
	_pass(12.5)
	Events.tile_dug.emit(Vector2i(4, 2), &"stone", P1)
	assert_int(_count("jeff", "rock_name")).is_equal(3)


func test_chuck_narrates_while_he_drives_somewhere() -> void:
	var v: VehicleData = load("res://data/vehicles/dump_truck.tres")
	var chuck: FakePlayer = _game.players[P2]
	chuck.vehicle = v
	_pass(0.1)
	assert_int(_count("chuck", "narrate")).is_equal(1)       # climbing in
	assert_array(_barks.bubbles()[0].pics).contains([StringName("vehicle:%s" % v.id)])
	for i in 10:                                             # parked: no narration
		_pass(1.0)
	assert_int(_count("chuck", "narrate")).is_equal(1)
	chuck.velocity = Vector2(float(v.speed), 0)
	for i in 10:
		_pass(1.0)
	assert_int(_count("chuck", "narrate")).is_equal(2)
	var jeff: FakePlayer = _game.players[P1]                 # Jeff drives quietly
	jeff.vehicle = v
	jeff.velocity = Vector2(float(v.speed), 0)
	for i in 4:
		_pass(1.0)
	assert_int(_barks.fired.filter(func(f: Dictionary) -> bool: return f.who == "jeff").size()).is_equal(0)


func test_the_mole_says_oh_dear_when_a_player_walks_up() -> void:
	var mole := _resident(&"mole", Vector2(500, 0))
	_pass(0.1)
	assert_int(_count("mole", "oh_dear")).is_equal(0)        # nobody near
	_game.players[P2].position = Vector2(520, 0)
	_pass(0.1)
	assert_int(_count("mole", "oh_dear")).is_equal(1)
	assert_object(_barks.bubbles()[0].speaker).is_same(mole)
	mole.visible = false                                     # off screen: quiet
	_pass(10.0)
	assert_int(_count("mole", "oh_dear")).is_equal(1)
	mole.visible = true
	_game.town.talking[&"mole"] = [&"heart"]                  # already in a story bubble: quiet
	_pass(10.0)
	assert_int(_count("mole", "oh_dear")).is_equal(1)


func test_the_foreman_mutters_when_a_player_walks_up_underground() -> void:
	var fm := _resident(&"gnome_foreman", Vector2(40, 900), true)
	_game.players[P1].position = Vector2(60, 900)
	_pass(0.1)
	assert_int(_count("gnome_foreman", "mutter")).is_equal(0)  # P1 is up top: other world
	_game.director.scenes[P1] = &"underground"
	_pass(0.1)
	assert_int(_count("gnome_foreman", "mutter")).is_equal(1)
	assert_object(_barks.bubbles()[0].speaker).is_same(fm)


func test_the_dragon_yawns_asleep_and_rumbles_awake() -> void:
	_resident(&"dragon", Vector2(0, 0))
	_game.players[P1].position = Vector2(20, 0)
	_pass(0.1)
	assert_int(_count("dragon", "yawn")).is_equal(1)
	assert_int(_count("dragon", "rumble")).is_equal(0)
	Events.dragon_woken.emit()
	_pass(3.0)
	assert_int(_count("dragon", "rumble")).is_equal(1)
	assert_array(_barks.bubbles().back().pics).contains([&"heart"])


func test_the_bubble_fades_and_frees_itself() -> void:
	Events.tile_dug.emit(Vector2i(1, 1), &"ice", P1)
	var b: BarkBubble = _barks.bubbles()[0]
	b._process(2.0)
	await get_tree().process_frame
	assert_bool(is_instance_valid(b)).is_false()
