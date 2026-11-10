## Boot scene: lobby (start screen and main menu), drop-in players, round loop, pause menu.
## Replace the Arena node with this game's level scene; keep the node names other lanes use.
## A pad that joins mid-game waits on its spawn (see-through) and plays from the next round.
## --proto / --proto-auto: the Arena is replaced by the Phase 1 prototype and the lobby is skipped.
extends Node2D

@onready var spawns: Node2D = $Arena/Spawns
@onready var players_root: Node2D = $Arena/Players

const PLAYER_SCENE := preload("res://scenes/players/player.tscn")
const PROTO_SCENE := "res://scenes/proto/foundation_proto.tscn"
var _players := {}
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
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.lobby_ready.connect(_on_lobby_ready)
	Game.back_to_lobby.connect(_clear_players)
	Game.round_started.connect(_on_round_started)
	if Game.demo:
		(func() -> void:
			Players.join_virtual(Players.P1)
			Players.join_virtual(Players.P2)
			Game.start_round()).call_deferred()
	elif Game.state != Game.State.LOBBY:
		Game.to_lobby()


func _on_lobby_ready(players: Array) -> void:
	for p in players:
		_spawn(p)


func _on_round_started(_round: int) -> void:
	for p in Players.active_players():
		_spawn(p)
		_players[p].waiting = false


func _on_player_joined(player: int, _device: int) -> void:
	if Game.state != Game.State.LOBBY:
		_spawn(player, true)


func _on_player_left(player: int) -> void:
	if _players.has(player):
		_players[player].queue_free()
		_players.erase(player)


func _clear_players() -> void:
	for p in _players.values():
		p.queue_free()
	_players.clear()


func _spawn(player: int, waiting := false) -> void:
	if _players.has(player):
		return
	var p := PLAYER_SCENE.instantiate()
	p.player = player
	p.waiting = waiting
	p.global_position = spawns.get_child(player).global_position
	players_root.add_child(p)
	_players[player] = p


## Swaps the Arena for the prototype (before UI, so pause and the Debug overlay keep working) and
## plays straight away. Restart from the pause menu rebuilds it instead of showing the lobby.
func _boot_proto(auto: bool) -> void:
	$Arena.free()
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
