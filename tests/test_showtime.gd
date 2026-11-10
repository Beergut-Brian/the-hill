## The Showtime menu kit: skin, backdrop modes, character slots, the launch beat and the wipe.
class_name TestShowtime
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const Backdrop := preload("res://scenes/ui/kit/menu_backdrop.gd")

var _main: Node
var _real_settings := ""
var _launched := 0
var _covered := 0


func _on_launching() -> void:
	_launched += 1


func _on_cover() -> void:
	_covered += 1


func before() -> void:
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_showtime.json"


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func before_test() -> void:
	Save.wipe_settings()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	UiStyle.use_skin(null)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


func _scene(root: Node) -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func test_default_skin_and_use_skin() -> void:
	UiStyle.use_skin(null)
	assert_object(UiStyle.skin()).is_not_null()
	var sk := MenuSkin.new()
	sk.title_text = "Spaceballs"
	sk.accent = Color("ffc928")
	UiStyle.use_skin(sk)
	assert_that(UiStyle.accent).is_equal(Color("ffc928"))
	_boot()
	assert_str(_lobby().get_node("TitleArt/TitleLabel").text).is_equal("SPACEBALLS")
	sk.title_text = "Junk Yard Zap"
	UiStyle.use_skin(sk)   # live: every open menu redraws
	assert_str(_lobby().get_node("TitleArt/TitleLabel").text).is_equal("JUNK YARD ZAP")


func test_title_text_on_the_lobby_wins_over_the_skin() -> void:
	var sk := MenuSkin.new()
	sk.title_text = "From skin"
	UiStyle.use_skin(sk)
	_boot()
	_lobby().title_text = "From code"
	assert_str(_lobby().get_node("TitleArt/TitleLabel").text).is_equal("FROM CODE")


func test_character_slot_hosts_every_kind() -> void:
	var sk := MenuSkin.new()
	sk.p1_character = _scene(Node3D.new())
	sk.p2_character = _scene(Node2D.new())
	sk.character_scale = 4.0
	sk.pixel_art = true
	UiStyle.use_skin(sk)
	_boot()
	var s1: CharacterSlot = _lobby().get_node("Spots/P1/Character")
	var s2: CharacterSlot = _lobby().get_node("Spots/P2/Character")
	assert_bool(s1.character is Node3D).is_true()
	assert_int(s1.find_children("*", "SubViewport", true, false).size()).is_equal(1)
	assert_int(s1.find_children("*", "Camera3D", true, false).size()).is_equal(1)
	assert_bool(s2.character is Node2D).is_true()
	assert_that((s2.character as Node2D).scale).is_equal(Vector2(4, 4))
	assert_int((s2.character as Node2D).texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	UiStyle.use_skin(null)   # back to the placeholder
	assert_bool(s1.character is Control).is_true()


func test_backdrop_modes() -> void:
	var sk := MenuSkin.new()
	sk.backdrop = MenuSkin.Backdrop.SCENE
	sk.backdrop_scene = _scene(Node3D.new())
	UiStyle.use_skin(sk)
	_boot()
	var bd: Backdrop = _lobby().get_node("Backdrop")
	assert_object(bd.world).is_not_null()
	# A 3D world without a camera gets the skin's.
	assert_int(bd.find_children("*", "Camera3D", true, false).size()).is_equal(1)
	sk.backdrop = MenuSkin.Backdrop.TEXTURE
	sk.backdrop_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	UiStyle.use_skin(sk)
	assert_object(bd.world).is_null()
	assert_int(bd.find_children("*", "TextureRect", false, false).size()).is_equal(1)
	sk.backdrop = MenuSkin.Backdrop.SCENE
	sk.backdrop_scene = null   # falls back to the still
	UiStyle.use_skin(sk)
	assert_int(bd.find_children("*", "TextureRect", false, false).size()).is_equal(1)


func test_last_beat_launches_and_cannot_cancel() -> void:
	_boot()
	var lobby := _lobby()
	_launched = 0
	lobby.launching.connect(_on_launching)
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS - ShowtimeWipe.IN_TIME)
	assert_int(_launched).is_equal(1)
	assert_bool(lobby.get_node("Spots/P1").go).is_true()
	assert_object(get_tree().root.get_node_or_null("ShowtimeWipe")).is_not_null()
	lobby.press_b(P1)   # too late to back out
	assert_bool(lobby.counting).is_true()
	lobby.count_step(1.0)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	lobby.open()
	assert_bool(lobby.get_node("Spots/P1").go).is_false()


func test_play_chip_counts_players() -> void:
	_boot()
	var play: MenuItem = _lobby().get_node("Buttons/Play")
	assert_str(play.chip).is_equal("")
	await _pad_b(5)
	assert_str(play.chip).is_equal("1P")
	await _pad_b(6)
	assert_str(play.chip).is_equal("2P")
	assert_array(play.chip_players).is_equal([P1, P2])


func _pad_b(device: int) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = JOY_BUTTON_B
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func test_wipe_covers_then_finishes() -> void:
	_covered = 0
	var w := ShowtimeWipe.run(_on_cover, "ROUND 2", "CHUCK KICKS FIRST")
	assert_bool(w.busy()).is_true()
	await w.covered
	assert_int(_covered).is_equal(1)
	await w.finished
	assert_bool(w.busy()).is_false()


func test_long_labels_shrink_to_fit() -> void:
	var item := MenuItem.new()
	assert_int(item._fit("BACK TO OPEN JAR", 116, 300.0)).is_less(116)
	assert_int(item._fit("PLAY", 116, 1000.0)).is_equal(116)
	item.free()


func test_every_menu_cue_has_a_sound() -> void:
	for cue in ["ui_move", "ui_back", "ui_confirm", "ui_tick", "ui_toggle", "player_ready",
			"player_unready", "count_tick", "ui_go", "ui_wipe", "ui_card", "ui_pause"]:
		assert_bool(UiSound.has_file(cue) or UiSound.stream(cue) != null).is_true()
