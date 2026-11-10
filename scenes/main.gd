## Boot scene: the lobby (start screen and main menu), then The Hill (HillGame) under Main, before
## UI, so pause and the Debug overlay stay on top. The lobby's look is data/menu_skin.tres.
## Restart (back to the lobby) saves and frees the game. --demo skips the lobby (Game.demo) and
## plays with both players virtual.
## --proto / --proto-auto boot the Phase 1 prototype instead and skip the lobby.
extends Node2D

const PROTO_SCENE := "res://scenes/proto/foundation_proto.tscn"

## The running HillGame, or null in the lobby.
var game: HillGame
var _proto: Node


## &"proto" for --proto, &"auto" for --proto-auto, else &"".
static func proto_mode(args: PackedStringArray) -> StringName:
	if args.has("--proto-auto"):
		return &"auto"
	if args.has("--proto"):
		return &"proto"
	return &""


func _ready() -> void:
	var mode := proto_mode(OS.get_cmdline_user_args() + OS.get_cmdline_args())
	if mode != &"":
		_boot_proto(mode == &"auto")
		return
	_restore_clock()
	Game.lobby_ready.connect(_on_lobby_ready)
	Game.back_to_lobby.connect(_clear_game)
	Audio.music_state(&"up", 0, false)   # the sunny theme from the lobby on
	Game.round_started.connect(_on_round_started)
	if Game.demo:
		# The demo plays from a wiped save in a throwaway profile, never the kid's.
		Save.profile = "demo"
		Save.wipe()
		(func() -> void:
			Players.join_virtual(Players.P1)
			Players.join_virtual(Players.P2)
			Game.start_round()).call_deferred()
	elif Game.state != Game.State.LOBBY:
		Game.to_lobby()


## The lobby's look is the Showtime skin, data/menu_skin.tres (logo, each player's picked character
## from the sprite sheets, Hillville blurred behind). Here only the clock: the lobby's Hillville shows the time of
## day the save left off at (--time=... freezes it instead; --demo keeps the default morning).
func _restore_clock() -> void:
	if Game.demo:
		return
	var td = Save.get_value("time_of_day")
	if td is Dictionary:
		TimeOfDay.load_save(td)


func _on_lobby_ready(players: Array) -> void:
	_start_game(players)


func _on_round_started(_round: int) -> void:
	if game == null:
		_start_game([])


func _start_game(players: Array) -> void:
	if game != null:
		return
	game = HillGame.new()
	game.start_players = players.duplicate()
	add_child(game)
	move_child(game, $UI.get_index())


func _clear_game() -> void:
	if game == null:
		return
	game.autosave()
	game.queue_free()
	game = null


## Boots the prototype (before UI, so pause and the Debug overlay keep working) and plays straight
## away. Restart from the pause menu rebuilds it instead of showing the lobby.
func _boot_proto(auto: bool) -> void:
	_proto = (load(PROTO_SCENE) as PackedScene).instantiate()
	_proto.auto = auto
	add_child(_proto)
	move_child(_proto, $UI.get_index())
	Game.back_to_lobby.connect(func() -> void:
		var fresh := (load(PROTO_SCENE) as PackedScene).instantiate()
		fresh.auto = auto
		var at := _proto.get_index()
		_proto.queue_free()
		add_child(fresh)
		move_child(fresh, at)
		_proto = fresh
		Game.start_round.call_deferred())
	Game.start_round()
