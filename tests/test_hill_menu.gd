## The Hill's Showtime skin (data/menu_skin.tres): it loads, it is pixel art at a whole-number scale,
## and the lobby shows Jeff (P1) and Chuck (P2) as pixel characters from the game's sprite sheets,
## with Hillville live behind the stage.
class_name TestHillMenu
extends GdUnitTestSuite

const P1 := 0
const P2 := 1

var _main: Node
var _real_settings := ""
var _real_profile := ""
var _real_picks := ""


func before() -> void:
	_real_settings = Save.settings_path
	_real_profile = Save.profile
	Save.settings_path = "user://test_settings_hill_menu.json"
	Save.reload_settings()
	# Default picks (Jeff, Chuck): never the real shared picks file.
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_hill_menu_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()
	Game.quit_exits = false


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.profile = _real_profile
	Save._load()
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()
	Game.quit_exits = true


func before_test() -> void:
	Save.profile = "test_hill_menu"
	Save.wipe()
	# The game's own skin (use_skin(null) would be the template's defaults, which test_showtime uses).
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func test_skin_loads_as_pixel_art() -> void:
	var sk := UiStyle.skin()
	assert_str(sk.resource_path).is_equal("res://data/menu_skin.tres")
	assert_bool(sk.pixel_art).is_true()
	assert_float(sk.character_scale).is_equal(roundf(sk.character_scale))
	assert_float(sk.character_scale).is_greater_equal(2.0)
	assert_object(sk.title_texture).is_not_null()
	assert_str(sk.title()).is_equal("The Hill")
	assert_int(sk.backdrop).is_equal(MenuSkin.Backdrop.SCENE)
	assert_object(sk.backdrop_scene).is_not_null()


func test_lobby_shows_both_pixel_characters() -> void:
	_boot()
	var lobby: Node = _main.get_node("UI/Lobby")
	var sk := UiStyle.skin()
	for p in [P1, P2]:
		var slot: CharacterSlot = lobby.get_node("Spots/P%d/Character" % (p + 1))
		assert_object(slot).is_instanceof(CharacterSlot)
		var who: HillMenuCharacter = slot.character as HillMenuCharacter
		assert_object(who).is_not_null()
		assert_int(who.player).is_equal(p)
		assert_str(who.file()).is_equal("characters/%s.png" % ["jeff", "chuck"][p])
		assert_object(who.sprite).is_not_null()
		assert_vector(who.scale).is_equal(Vector2.ONE * sk.character_scale)
		assert_int(who.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	# The title is the pixel logo, nearest-filtered.
	var title: TextureRect = lobby.get_node("TitleArt")
	assert_object(title.texture).is_same(sk.title_texture)
	assert_int(title.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	# Hillville runs live behind the stage.
	var world: Node = lobby.get_node("Backdrop").world
	assert_object(world).is_not_null()
	assert_object(world.get("hillville")).is_instanceof(Hillville)


func test_cheer_plays_the_jump() -> void:
	_boot()
	var lobby: Node = _main.get_node("UI/Lobby")
	Players.join_virtual(P1)
	var who: HillMenuCharacter = lobby.get_node("Spots/P1/Character").character
	var air: int = int(SheetSprite.entry(who.file()).rows.air.row)
	who.cheer()
	assert_int(who.current_row()).is_equal(air)
	await await_millis(600)
	assert_int(who.current_row()).is_equal(int(SheetSprite.entry(who.file()).rows.idle.row))
