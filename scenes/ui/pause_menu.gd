## Pause menu, Showtime style: the game stays visible, softened and tinted, and a dark wedge slides
## in from the left edged in the pauser's colour, with a big PAUSED, a "PLAYER 2 PAUSED" tag and
## slanted bars: Resume, Back to menu (Choice.RESTART: saves, back to the lobby, where Continue /
## New Hill wait), Settings, Story (the intro scene again, via
## the "hill_story" group), then the big door icon (128 px, 140 px focused) with "Back to Open Jar"
## beneath it: back to the launcher, asks first, then Game.quit() (saves first).
## Either pad moves the cursor, A presses, B resumes or backs out of Settings / the question.
## Left / right step through the list too (right = down); with no row that way they refuse.
## Every other button (X, Y, shoulders, triggers, stick clicks, Select) refuses: the soft honk and a
## wobble on the focused item (docs/press-answers.md).
## Start is Game's (it resumes from anywhere). Shown while Game.state == PAUSED.
extends Control

enum Choice { RESUME, RESTART, SETTINGS, STORY, DOOR }

var focus := Choice.RESUME
## The player whose Start opened the menu (P1 for the keyboard).
var paused_by := Players.P1:
	set(v):
		paused_by = v
		if is_node_ready():
			_apply_pauser()

var _tw: Tween

@onready var _buttons: Array = [$Card/Buttons/Resume, $Card/Buttons/Restart, $Card/Buttons/Settings, $Card/Buttons/Story, $Card/Door/Icon]
@onready var _card: Control = $Card
@onready var _wedge: Control = $Wedge
@onready var _by: Control = $Card/PausedBy
@onready var _settings: SettingsPanel = $Settings
@onready var _confirm: ConfirmDialog = $Confirm
@onready var _door: IconButton = $Card/Door/Icon
@onready var _door_label: Label = $Card/Door/Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("openjar_pause_menu")
	Game.state_changed.connect(_on_state_changed)
	_confirm.chosen.connect(_on_confirm_chosen)
	add_to_group("openjar_skinned")
	_by.draw.connect(_draw_paused_by)
	apply_skin()
	visible = Game.state == Game.State.PAUSED
	_set_focus(Choice.RESUME, false)


## Before Game sees the Start press: remember whose it was.
func _input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING or not event.is_action_pressed("pause"):
		return
	if Players.solo:
		paused_by = Players.solo_focus
		return
	paused_by = Players.P1
	if event is InputEventJoypadButton:
		for p in [Players.P1, Players.P2]:
			if Players.device_of(p) == event.device:
				paused_by = p


func _process(_delta: float) -> void:
	if not visible or Game.state != Game.State.PAUSED:
		return
	# Settings brings its own wedge; the pause wedge steps aside for it.
	_card.visible = not _settings.active
	_wedge.visible = not _settings.active
	var input := MenuInput.read()
	if _confirm.active:
		_confirm.handle(input)
	elif _settings.active:
		_settings.handle(input)
	else:
		if input.move.y != 0:
			move_focus(input.move.y)
		elif input.move.x != 0:
			side_step(input.move.x)
		if input.a != -1:
			press()
		elif input.b != -1:
			back()
		elif input.other != -1 and not MenuInput.owned_elsewhere(input):
			refuse(input.button)


func move_focus(dir: int) -> void:
	_set_focus(MenuItem.step(_buttons, focus, dir) as Choice)


## Left / right: the next row that way (right = down the list), or a refusal at the end.
func side_step(dir: int) -> void:
	var to := MenuItem.step(_buttons, focus, dir)
	if to == focus:
		refuse("left" if dir < 0 else "right")
	else:
		_set_focus(to as Choice)


## A press that does nothing here: the honk and a wobble on the focused item.
func refuse(button := "") -> void:
	MenuInput.refuse(_buttons[focus], button)


func press(choice: Choice = focus) -> void:
	_set_focus(choice, false)
	_buttons[choice].press()
	match choice:
		Choice.RESUME:
			Game.resume()
		Choice.RESTART:
			UiSound.play("ui_confirm")
			Game.to_lobby()
		Choice.SETTINGS:
			_settings.open()
		Choice.STORY:
			UiSound.play("ui_confirm")
			Game.resume()
			get_tree().call_group(&"hill_story", &"replay_intro")
		Choice.DOOR:
			_confirm.open()


## B: out of the question or Settings, else resume.
func back() -> void:
	if _confirm.active:
		_confirm.choose(false)
	elif _settings.active and _settings.asking():
		_settings.restore.choose(false)
	elif _settings.active:
		_settings.close()
	else:
		UiSound.play("ui_back")
		Game.resume()


func in_submenu() -> bool:
	return _settings.active or _confirm.active


func _set_focus(to: Choice, sound := true) -> void:
	# Bumping the end still makes a sound: every move does something.
	if sound:
		UiSound.play("ui_move", 1.12 - 0.08 * to)
	focus = to
	for i in _buttons.size():
		_buttons[i].focused = i == focus
	_style_door_label()


func _on_confirm_chosen(leave: bool) -> void:
	if leave:
		Game.quit()


func _on_state_changed(_from: int, to: int) -> void:
	visible = to == Game.State.PAUSED
	_settings.dismiss()
	_confirm.dismiss()
	if not visible:
		return
	_set_focus(Choice.RESUME, false)
	_card.visible = true
	_wedge.visible = true
	UiSound.play("ui_pause")
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(self, "modulate:a", 1.0, 0.12).from(0.0)
	_tw.tween_property(_wedge, "edge", 1010.0, 0.3).from(-300.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_card, "position:x", 0.0, 0.3).from(-500.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	MenuItem.slam_all(_buttons, 0.1, 0.05)
	# The door's words come in with the door.
	_door_label.position.x = -500.0
	_tw.tween_property(_door_label, "position:x", 0.0, 0.34).set_delay(0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## UiStyle.use_skin() calls this on every open menu.
func apply_skin() -> void:
	var dim := $Dim.material as ShaderMaterial
	if dim:
		dim.set_shader_parameter("tint", Color(UiStyle.deep(), 0.4))
	# The Hill's accent on the door (set here, not as a scene override).
	_door.tint = UiStyle.accent
	_apply_pauser()


## Under the door: cream and big when it is focused, softer when not.
func _style_door_label() -> void:
	if _door_label == null:
		return
	var on := focus == Choice.DOOR
	UiStyle.style_title(_door_label, 46 if on else 38, UiStyle.CREAM if on else Color(UiStyle.CREAM, 0.75), 420.0)


func _apply_pauser() -> void:
	var col := UiStyle.player_color(paused_by)
	_wedge.stripe_color = col
	UiStyle.style_title($Card/Heading, 220, UiStyle.CREAM, 0.0, col, 0)
	$Card/Heading.text = "PAUSED"
	_by.queue_redraw()


func _draw_paused_by() -> void:
	var col := UiStyle.player_color(paused_by)
	var text := "%s PAUSED" % UiStyle.player_name(paused_by).to_upper()
	var w := UiStyle.show_width(text, 40) + 56.0
	UiStyle.para(_by, Rect2(0, 0, w, _by.size.y), col)
	UiStyle.draw_show(_by, Vector2(26, _by.size.y * 0.5), text, 40, Color.WHITE)
