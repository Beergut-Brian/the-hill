## Settings, small and real: music volume, sound volume, screen shake, solo playtest mode.
## Per install, saved through Save.set_setting the moment a value changes. Up/down picks a row,
## left/right (or A) changes it, B goes back. The lobby and the pause menu each hold one.
## Games read screen shake with SettingsPanel.screen_shake() before shaking the camera.
class_name SettingsPanel
extends Control

signal closed()

const MUSIC := "music_volume"
const SOUND := "sound_volume"
const SHAKE := "screen_shake"
const SOLO := "solo_playtest"
const DEFAULTS := { MUSIC: 0.8, SOUND: 1.0, SHAKE: true, SOLO: false }

enum Row { MUSIC, SOUND, SHAKE, SOLO }

var active := false
var focus := Row.MUSIC

var _tw: Tween

@onready var _card: Control = $Card
@onready var _wedge: Control = $Wedge
@onready var _rows: Array = [$Card/Rows/Music, $Card/Rows/Sound, $Card/Rows/Shake, $Card/Rows/Solo]


static func screen_shake() -> bool:
	return Save.get_setting(SHAKE, DEFAULTS[SHAKE])


static func value_of(key: String):
	return Save.get_setting(key, DEFAULTS[key])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("openjar_skinned")
	apply_skin()
	Players.solo_changed.connect(_on_solo_changed)


func apply_skin() -> void:
	UiStyle.style_title($Card/Heading, 150, UiStyle.CREAM, 0.0, UiStyle.INK_SHOW, 0)
	$Card/Heading.text = "SETTINGS"
	$Card/Caption.add_theme_color_override("font_color", Color(UiStyle.CREAM, 0.7))


func open() -> void:
	_refresh()
	active = true
	visible = true
	_set_focus(Row.MUSIC, false)
	UiSound.play("ui_confirm")
	_slide(true)


func close() -> void:
	if not active:
		return
	active = false
	UiSound.play("ui_back")
	_slide(false)
	closed.emit()


## Hidden at once, no sound (the menu behind it went away).
func dismiss() -> void:
	active = false
	visible = false


## One frame of MenuInput.read(). B backs out.
func handle(input: Dictionary) -> void:
	if input.b != -1:
		close()
		return
	if input.move.y != 0:
		move_focus(input.move.y)
	if input.move.x != 0:
		adjust(input.move.x)
	elif input.a != -1:
		adjust(1, true)


func move_focus(dir: int) -> void:
	_set_focus(MenuItem.step(_rows, focus, dir) as Row)


## Slider rows step by 0.1; toggles flip (A) or go on/off (right/left).
func adjust(dir: int, pressed := false) -> void:
	var row: SettingRow = _rows[focus]
	if pressed:
		row.press()
	if row.kind == SettingRow.Kind.SLIDER:
		var v := clampf(snappedf(row.value + dir * 0.1, 0.1), 0.0, 1.0)
		if pressed and row.value >= 1.0:
			v = 0.0   # A on a full slider wraps round
		_apply(focus, v)
	else:
		_apply(focus, not row.is_on() if pressed else dir > 0)
	if row.kind == SettingRow.Kind.SLIDER:
		UiSound.play("ui_tick", 0.8 + 0.5 * row.value)
	else:
		UiSound.play("ui_toggle", 1.1 if row.is_on() else 0.9)


func _apply(row: Row, v) -> void:
	match row:
		Row.MUSIC:
			Save.set_setting(MUSIC, v)
			Audio.set_volume("Music", v)
		Row.SOUND:
			Save.set_setting(SOUND, v)
			Audio.set_volume("SFX", v)
		Row.SHAKE:
			Save.set_setting(SHAKE, v)
		Row.SOLO:
			Save.set_setting(SOLO, v)
			Players.set_solo(v)
	_refresh()


func _refresh() -> void:
	_rows[Row.MUSIC].value = value_of(MUSIC)
	_rows[Row.SOUND].value = value_of(SOUND)
	_rows[Row.SHAKE].value = 1.0 if value_of(SHAKE) else 0.0
	_rows[Row.SOLO].value = 1.0 if Players.solo else 0.0


func _set_focus(to: Row, sound := true) -> void:
	if sound:
		UiSound.play("ui_move", 1.12 - 0.08 * to)
	focus = to
	for i in _rows.size():
		_rows[i].focused = i == focus


func _on_solo_changed(on: bool) -> void:
	if Save.get_setting(SOLO, false) != on:
		Save.set_setting(SOLO, on)
	if is_node_ready():
		_refresh()


func _slide(on: bool) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.12 if on else 0.18).from(0.0 if on else 1.0)
	if on:
		_tw.tween_property(_wedge, "edge", 946.0, 0.3).from(1500.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_card, "position:x", 0.0, 0.3).from(500.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		MenuItem.slam_all(_rows, 0.06, 0.05)
	else:
		_tw.tween_property(_card, "position:x", 300.0, 0.18).from(0.0)
		_tw.chain().tween_callback(func() -> void: visible = active)
