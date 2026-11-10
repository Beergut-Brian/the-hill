## "Leave the game?" Two buttons, Stay focused first so a stray double press never quits.
## Left/right (or up/down) moves, A chooses, B is Stay. Emits chosen(true) for Leave.
class_name ConfirmDialog
extends Control

signal chosen(confirmed: bool)

enum Choice { CANCEL, CONFIRM }

var active := false
var focus := Choice.CANCEL

var _tw: Tween

@onready var _card: Control = $Card
@onready var _buttons: Array = [$Card/Buttons/Cancel, $Card/Buttons/Confirm]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_card.pivot_offset = _card.size * 0.5
	UiStyle.showtime_card(_card)
	UiStyle.style_title($Card/Heading, 72, UiStyle.CREAM, $Card/Heading.size.x, UiStyle.INK_SHOW, 0)
	$Card/Heading.text = "LEAVE THE GAME?"
	$Card/Heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Card/Hint.color = Color(UiStyle.CREAM, 0.75)
	$Card/Body.add_theme_color_override("font_color", Color(UiStyle.CREAM, 0.8))


func open() -> void:
	active = true
	visible = true
	_set_focus(Choice.CANCEL, false)
	UiSound.play("ui_confirm")
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(self, "modulate:a", 1.0, 0.16).from(0.0)
	_tw.tween_property(_card, "scale", Vector2.ONE, 0.22).from(Vector2.ONE * 0.94) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	active = false
	visible = false


func handle(input: Dictionary) -> void:
	if input.b != -1:
		choose(false)
		return
	var dir: int = input.move.x if input.move.x != 0 else input.move.y
	if dir != 0:
		move_focus(dir)
	if input.a != -1:
		choose(focus == Choice.CONFIRM)


func move_focus(dir: int) -> void:
	_set_focus(MenuItem.step(_buttons, focus, dir) as Choice)


func choose(confirmed: bool) -> void:
	if not active:
		return
	_buttons[Choice.CONFIRM if confirmed else Choice.CANCEL].press()
	UiSound.play("ui_confirm" if confirmed else "ui_back")
	active = false
	visible = false
	chosen.emit(confirmed)


func _set_focus(to: Choice, sound := true) -> void:
	if sound:
		UiSound.play("ui_move")
	focus = to
	for i in _buttons.size():
		_buttons[i].focused = i == focus
