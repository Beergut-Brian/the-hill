## Who is holding which controller. Autoload: Players.
## First controller to press a button becomes P1 (green), the next becomes P2 (red).
## Joypad events in the p1_* / p2_* actions are rebound to the joined device so
## Input.is_action_pressed("p1_action") only fires for P1's pad. Keyboard stays as a fallback.
extends Node

const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }
const PREFIX := { P1: "p1_", P2: "p2_" }
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "action", "jump", "book", "horn"]
## Device id for a keyboard or --demo player: no pad events are rebound.
const VIRTUAL := -2
## Solo (playtest only): Select + Start held together this long, in real seconds, toggles it.
const SOLO_HOLD := 2.0
const SOLO_BUTTONS := [JOY_BUTTON_BACK, JOY_BUTTON_START]
const SoloMarker := preload("res://scripts/autoload/solo_marker.gd")

signal player_joined(player: int, device: int)
signal player_left(player: int)
signal solo_changed(on: bool)

## One device plays both players; only the focused player's actions have events.
var solo := false
var solo_focus := P1

var _device_of := { P1: -1, P2: -1 }
var _solo_device := VIRTUAL
var _saved_events := {}          # action name -> Array[InputEvent] as they were before solo
var _held := {}                  # device -> seconds Select + Start have been held together
var _paused_before := {}         # device -> was the tree paused when the hold began
var _last_us := 0
var _marker: CanvasLayer


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_marker = SoloMarker.new()
	add_child(_marker)
	_last_us = Time.get_ticks_usec()
	if solo_from_args(OS.get_cmdline_user_args()):
		set_solo.call_deferred(true)


func _process(_delta: float) -> void:
	# Real time, so --timescale and pause don't change how long the hold takes.
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000000.0
	_last_us = now
	for d in Input.get_connected_joypads():
		var both := Input.is_joy_button_pressed(d, SOLO_BUTTONS[0]) \
				and Input.is_joy_button_pressed(d, SOLO_BUTTONS[1])
		if hold_step(d, both, dt):
			_undo_hold_pause(d)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index in SOLO_BUTTONS:
		var other: int = SOLO_BUTTONS[1] if event.button_index == SOLO_BUTTONS[0] else SOLO_BUTTONS[0]
		if not Input.is_joy_button_pressed(event.device, other):
			_paused_before[event.device] = get_tree().paused
	if event is InputEventKey and event.pressed and not event.echo:
		_keyboard_join(event)
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var device: int = event.device
	if device in _device_of.values():
		return
	for player in [P1, P2]:
		if _device_of[player] == -1:
			_assign(player, device)
			return


func is_active(player: int) -> bool:
	return _device_of.get(player, -1) != -1


func device_of(player: int) -> int:
	return _device_of.get(player, -1)


func active_players() -> Array[int]:
	var out: Array[int] = []
	for p in [P1, P2]:
		if is_active(p):
			out.append(p)
	return out


func action(player: int, action_name: String) -> String:
	return PREFIX[player] + action_name


func move_vector(player: int) -> Vector2:
	return Input.get_vector(
		action(player, "move_left"), action(player, "move_right"),
		action(player, "move_up"), action(player, "move_down"))


func join_virtual(player: int) -> void:
	if not is_active(player):
		_assign(player, VIRTUAL)


static func solo_from_args(args: PackedStringArray) -> bool:
	return args.has("--solo")


## The hold rule, fed once a frame per pad. Toggles solo after SOLO_HOLD s of both buttons held;
## the buttons must come up before the next toggle. Returns true when it toggled.
func hold_step(device: int, both_down: bool, delta: float) -> bool:
	if not both_down:
		_held.erase(device)
		return false
	var t: float = _held.get(device, 0.0)
	if t < 0.0:
		return false   # already toggled on this hold
	t += delta
	if t < SOLO_HOLD:
		_held[device] = t
		return false
	_held[device] = -1.0
	set_solo(not solo, device)
	return true


## device: the pad that drives both players; VIRTUAL = the keyboard and any pad.
func set_solo(on: bool, device: int = VIRTUAL) -> void:
	if on == solo:
		return
	solo = on
	if on:
		_solo_device = device
		_saved_events.clear()
		for p in [P1, P2]:
			for a in ACTIONS:
				var list: Array[InputEvent] = []
				for ev in InputMap.action_get_events(action(p, a)):
					list.append(ev.duplicate())
				_saved_events[action(p, a)] = list
		var joined: Array[int] = []
		for p in [P1, P2]:
			if not is_active(p):
				joined.append(p)
			_device_of[p] = device
		solo_focus = P1
		_apply_solo_map()
		Audio.play("solo_on")
		_marker.show_solo(true)
		solo_changed.emit(true)
		for p in joined:
			player_joined.emit(p, device)
	else:
		_restore_map()
		# P1 keeps the solo pad; after --solo, the pad that held the buttons.
		var keep := device if _solo_device == VIRTUAL else _solo_device
		_device_of[P1] = keep
		_rebind(P1, keep)
		_device_of[P2] = -1
		_held.clear()
		Audio.play("solo_off")
		_marker.show_solo(false)
		solo_changed.emit(false)
		player_left.emit(P2)


func set_solo_focus(player: int) -> void:
	if not solo or player == solo_focus:
		return
	solo_focus = player
	_apply_solo_map()


## Tests: solo off, nobody joined, InputMap back to project.godot.
func reset() -> void:
	if solo:
		_restore_map()
	solo = false
	solo_focus = P1
	_held.clear()
	_paused_before.clear()
	if _marker:
		_marker.show_solo(false, false)
	_device_of = { P1: -1, P2: -1 }
	for p in [P1, P2]:
		_rebind(p, -1)


func _apply_solo_map() -> void:
	for a in ACTIONS:
		var to := action(solo_focus, a)
		InputMap.action_erase_events(action(P1, a))
		InputMap.action_erase_events(action(P2, a))
		var pad_done := false
		for p in [P1, P2]:
			for ev: InputEvent in _saved_events[action(p, a)]:
				var is_pad := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
				if is_pad and pad_done:
					continue
				var copy := ev.duplicate()
				if is_pad:
					copy.device = -1 if _solo_device == VIRTUAL else _solo_device
				InputMap.action_add_event(to, copy)
			pad_done = true


func _restore_map() -> void:
	for name: String in _saved_events:
		InputMap.action_erase_events(name)
		for ev: InputEvent in _saved_events[name]:
			InputMap.action_add_event(name, ev.duplicate())
	_saved_events.clear()


## A Start press that was part of the hold should not leave the game paused.
func _undo_hold_pause(device: int) -> void:
	if not _paused_before.get(device, true) and get_tree().paused and Game.state == Game.State.PAUSED:
		Game.resume()
	_paused_before.erase(device)


## Keyboard fallback for development: a P1 key joins P1, a P2 key joins P2.
func _keyboard_join(event: InputEventKey) -> void:
	for player in [P1, P2]:
		if is_active(player):
			continue
		for a in ACTIONS:
			if event.is_action_pressed(action(player, a)):
				_assign(player, VIRTUAL)
				return


func _assign(player: int, device: int) -> void:
	_device_of[player] = device
	_rebind(player, device)
	Audio.play("player_join")
	player_joined.emit(player, device)


## Points the player's pad events at device (-1 = any pad). VIRTUAL leaves them alone.
func _rebind(player: int, device: int) -> void:
	if device == VIRTUAL:
		return
	for a in ACTIONS:
		for ev in InputMap.action_get_events(action(player, a)):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = device


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	if solo and device == _solo_device:
		set_solo(false)
	for player in [P1, P2]:
		if _device_of[player] == device:
			_device_of[player] = -1
			player_left.emit(player)
