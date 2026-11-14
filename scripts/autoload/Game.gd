## Session state machine. Autoload: Game.
## LOBBY (start screen / main menu) -> PLAYING <-> PAUSED, ROUND_END between rounds.
## CLI (after --): --demo skips the lobby and plays with two virtual players.
extends Node

## TITLE is the old name of LOBBY, kept so games written against it still compile.
enum State { LOBBY, PLAYING, PAUSED, ROUND_END, TITLE = 0 }

signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)
signal lobby_ready(players: Array)
signal back_to_lobby()
signal quit_requested()

var state: State = State.LOBBY
var round_index: int = 0
var demo := false
## Tests turn this off so quit() does everything but exit.
var quit_exits := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	# --bench (S-20) is a scripted demo too: two virtual players on a wiped throwaway save.
	demo = OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_user_args().has("--bench")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
	elif event.is_action_pressed("restart") and state in [State.PLAYING, State.ROUND_END]:
		restart()


func start_round() -> void:
	round_index += 1
	get_tree().paused = false
	_set_state(State.PLAYING)
	Audio.play("round_start")
	round_started.emit(round_index)


func end_round(result: Dictionary = {}) -> void:
	_set_state(State.ROUND_END)
	Audio.play("round_end")
	Save.flush()
	round_ended.emit(round_index, result)


func pause() -> void:
	get_tree().paused = true
	Audio.play("pause")
	_set_state(State.PAUSED)


func resume() -> void:
	get_tree().paused = false
	Audio.play("pause")
	_set_state(State.PLAYING)


func restart() -> void:
	get_tree().paused = false
	Audio.play("ui_confirm")
	start_round()


## Back to the start screen: the game clears its level on back_to_lobby.
func to_lobby() -> void:
	get_tree().paused = false
	Save.flush()
	round_index = 0
	_set_state(State.LOBBY)
	back_to_lobby.emit()


## The lobby countdown finished.
func finish_lobby(players: Array) -> void:
	lobby_ready.emit(players)
	start_round()


## Clean exit, code 0 for the launcher, which resumes when the process ends.
func quit(code: int = 0) -> void:
	quit_requested.emit()
	Save.flush()
	if quit_exits:
		get_tree().quit(code)


func _set_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	state_changed.emit(from, to)
