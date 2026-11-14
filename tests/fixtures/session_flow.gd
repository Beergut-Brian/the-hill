## Launch-readiness: drives the real boot scene (scenes/main.tscn) through a whole session with
## synthetic pad events (Input.parse_input_event, so Players, MenuInput, the lobby and the pause
## menu all see ordinary presses) and saves a frame at each step through Debug.screenshot.
## Not shipped (tests/ is excluded from exports). Run with a renderer:
##   godot-render --path . --resolution 1920x1080 res://tests/fixtures/session_flow.tscn -- \
##       --flow=two --shot-dir=/abs/dir --profile=flowtest
## --flow=two: both pads ready up, play, pause (P2), the leave question, drop-out / drop-in,
##             Select + Start held 2 s (solo on, then off), back to the menu, quit from the menu.
## --flow=alone: one pad, holds A on Play to start alone, then quits through pause > Back to Open Jar.
## --flow=solo: booted with --solo (both ready, countdown); B stops it, Select switches the podium,
##             holding A starts, quits from pause.
## Every step prints "flow: <t> <step>"; the process must exit 0 by itself (Game.quit).
## Select + Start: Players reads the hold from Input.get_connected_joypads(), which synthetic pads
## never join, so the driver feeds Players.hold_step() itself, the same call Players._process makes.
extends Node

const MAIN := "res://scenes/main.tscn"
const A := JOY_BUTTON_A
const B := JOY_BUTTON_B
const START := JOY_BUTTON_START
const SELECT := JOY_BUTTON_BACK

var flow := "two"
var _t := 0.0
var _n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--flow="):
			flow = a.trim_prefix("--flow=")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred((load(MAIN) as PackedScene).instantiate())
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	# What Players._process does for each connected pad (synthetic pads 0 and 1 never connect).
	for d in [0, 1]:
		var both := Input.is_joy_button_pressed(d, SELECT) and Input.is_joy_button_pressed(d, START)
		if Players.hold_step(d, both, delta):
			Players.call("_undo_hold_pause", d)


func log_step(what: String) -> void:
	print("flow: %7.2f %s (state %s, players %s, solo %s)" % [_t, what, Game.State.keys()[Game.state],
			str(Players.active_players()), Players.solo])


func shot(tag: String) -> void:
	_n += 1
	var name := "%s_%02d_%s" % [flow, _n, tag]
	log_step("shot " + name)
	await Debug.screenshot(name)


func wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func button(device: int, idx: int, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = idx
	ev.pressed = down
	ev.pressure = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func tap(device: int, idx: int) -> void:
	button(device, idx, true)
	await wait(0.12)
	button(device, idx, false)
	await wait(0.25)


## Stick down (+1) or up (-1) for one menu step.
func stick(device: int, dir: int) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = JOY_AXIS_LEFT_Y
	ev.axis_value = float(dir)
	Input.parse_input_event(ev)
	await wait(0.12)
	var up := InputEventJoypadMotion.new()
	up.device = device
	up.axis = JOY_AXIS_LEFT_Y
	up.axis_value = 0.0
	Input.parse_input_event(up)
	await wait(0.25)


func until(cond: Callable, secs: float, what: String) -> bool:
	var left := secs
	while not cond.call():
		if left <= 0.0:
			log_step("TIMEOUT waiting for " + what)
			return false
		await wait(0.1)
		left -= 0.1
	return true


func story_busy() -> bool:
	var s := get_tree().get_first_node_in_group("hill_story")
	return s != null and s.call("is_playing")


func pause_menu() -> Node:
	return get_tree().get_first_node_in_group("openjar_pause_menu")


## From the pause menu: down to Back to Open Jar, A, then the question's Leave, A.
func leave_from_pause(device: int) -> void:
	for i in 4:
		await stick(device, 1)
	await wait(0.3)
	await shot("pause_door_focused")
	await tap(device, A)
	await wait(0.6)
	await shot("pause_leave_question")
	await stick(device, 1)
	await wait(0.3)
	await shot("pause_leave_focused")
	log_step("quit: A on Leave")
	await tap(device, A)


func _run() -> void:
	await wait(2.5)
	await shot("main_menu")
	match flow:
		"two":
			await _two()
		"alone":
			await _alone()
		"solo":
			await _solo()
	await wait(5.0)
	log_step("STILL RUNNING 5 s after quit (force-close needed)")
	get_tree().quit(3)


func _into_play() -> void:
	await until(func() -> bool: return Game.state == Game.State.PLAYING, 12.0, "PLAYING")
	await wait(2.0)
	await shot("playing_first_frame")
	await until(func() -> bool: return not story_busy(), 60.0, "the intro to end")
	await wait(1.5)
	await shot("playing")


func _two() -> void:
	await tap(0, A)
	await wait(0.5)
	await shot("p1_ready")
	await tap(1, A)
	await wait(0.6)
	await shot("both_ready_countdown")
	await _into_play()
	await tap(1, START)
	await wait(0.8)
	await shot("pause_by_p2")
	# The leave question, then Stay: B backs out, B again resumes.
	for i in 4:
		await stick(1, 1)
	await wait(0.3)
	await shot("pause_door_focused")
	await tap(1, A)
	await wait(0.6)
	await shot("pause_leave_question")
	await tap(1, B)
	await wait(0.3)
	await tap(1, B)
	await wait(0.8)
	await shot("resumed")
	# Drop-out: P2's pad goes away mid-game.
	Input.joy_connection_changed.emit(1, false)
	await wait(2.0)
	await shot("p2_dropped_out")
	# Drop-in: a press on that pad wakes P2 again, no menu.
	await tap(1, A)
	await wait(2.5)
	await shot("p2_dropped_in")
	# Select + Start held 2 s on P1's pad: solo on.
	button(0, SELECT, true)
	button(0, START, true)
	await until(func() -> bool: return Players.solo, 4.0, "solo on")
	button(0, START, false)
	button(0, SELECT, false)
	await wait(0.6)
	await shot("solo_on_select_start")
	button(0, SELECT, true)
	button(0, START, true)
	await until(func() -> bool: return not Players.solo, 4.0, "solo off")
	button(0, START, false)
	button(0, SELECT, false)
	await wait(0.6)
	await shot("solo_off")
	await tap(1, A)   # P2 back in for the menu
	await wait(1.0)
	# Pause > Back to menu (one stick step down from Resume).
	await tap(0, START)
	await wait(0.6)
	await stick(0, 1)
	await tap(0, A)
	await until(func() -> bool: return Game.state == Game.State.LOBBY, 5.0, "LOBBY")
	await wait(1.5)
	await shot("back_to_menu_continue")
	# Quit from the menu: down to Back to Open Jar, A, Leave, A.
	for i in 4:
		await stick(0, 1)
	await tap(0, A)
	await wait(0.6)
	await shot("menu_leave_question")
	await stick(0, 1)
	await wait(0.3)
	await shot("menu_leave_focused")
	log_step("quit: A on Leave")
	await tap(0, A)


func _alone() -> void:
	await tap(0, A)
	await wait(0.4)
	button(0, A, true)
	await wait(0.9)
	await shot("holding_a_alone")
	await wait(1.2)
	button(0, A, false)
	await _into_play()
	await tap(0, START)
	await wait(0.8)
	await shot("pause_by_p1")
	await leave_from_pause(0)


func _solo() -> void:
	await until(func() -> bool: return Players.solo, 3.0, "--solo")
	await wait(0.5)
	await shot("solo_menu_both_ready_countdown")
	# Solo readies both and counts down (lobby.open). B on the one pad stops it (P1 un-readies),
	# Select moves the pad to P2's podium, and holding A there starts the game.
	await tap(0, B)
	await wait(0.5)
	await shot("solo_b_stops_the_countdown")
	await tap(0, SELECT)
	await wait(0.5)
	await shot("solo_select_p2_podium")
	button(0, A, true)
	await wait(0.9)
	await shot("solo_holding_a")
	await wait(1.2)
	button(0, A, false)
	await _into_play()
	await tap(0, START)
	await wait(0.8)
	await shot("solo_pause")
	await leave_from_pause(0)
