## Start screen and main menu in one, Showtime style (docs/ui.md): the game's slanted title over a
## turning sunburst (and the game's own world, blurred, if the skin asks), Jeff and Chuck on spotlit
## podiums left, a dark wedge with slanted menu bars right (Play, Settings, Back to Open Jar).
## A on any pad joins and readies that player, B un-readies. Both ready: a 3-step countdown; on its
## last beat the stamps flip to GO!, both characters jump, and the three-stripe wipe covers the
## screen as Game.finish_lobby() starts round 1 (with the skin's "ROUND 1" card). A ready player
## holding A on Play for HOLD_TO_START s starts alone. Back to Open Jar asks "Leave the game?" first.
## Games customise it with a MenuSkin (UiStyle.use_skin, or res://data/menu_skin.tres), in code.
## title_texture / title_text here still work and win over the skin. Keep the node names.
extends Control

signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()
## The countdown's last beat: the wipe is starting.
signal launching()

enum Choice { PLAY, SETTINGS, DOOR }

const HOLD_TO_START := 1.5
const COUNT_STEP := 0.7
const COUNT_DOTS := 3
const P1 := Players.P1
const P2 := Players.P2

## The game's logo or key art, drawn big at the top. Empty: title_text in the display face.
@export var title_texture: Texture2D:
	set(v):
		title_texture = v
		if is_node_ready():
			_apply_title()
## Empty: the project name (application/config/name).
@export var title_text := "":
	set(v):
		title_text = v
		if is_node_ready():
			_apply_title()

## Shown under the round card ("JEFF KICKS FIRST"); set it in code before the countdown ends.
var round_card_subtitle := ""
var round_card_color := Color(0, 0, 0, 0)

var readied := { P1: false, P2: false }
var focus := Choice.PLAY
var counting := false
## Screenshots (UiPreview): the countdown and hold stay where they are.
var freeze := false

var _hold := { P1: 0.0, P2: 0.0 }
var _count_t := 0.0
var _dots_lit := 0
var _solo_pending := false
var _launched := false
var _tw: Tween
var _wipe: ShowtimeWipe

@onready var _spots := { P1: $Spots/P1, P2: $Spots/P2 }
@onready var _buttons := { Choice.PLAY: $Buttons/Play, Choice.SETTINGS: $Buttons/Settings, Choice.DOOR: $Buttons/Door }
@onready var _items: Array = [$Buttons/Play, $Buttons/Settings, $Buttons/Door]
@onready var _countdown: Control = $Countdown
@onready var _settings: SettingsPanel = $Settings
@onready var _confirm: ConfirmDialog = $Confirm
@onready var _title_y: float = $TitleArt.position.y


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("openjar_lobby")
	add_to_group("openjar_skinned")
	UiStyle.skin()
	_apply_title()
	$Footer/Version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_countdown.draw.connect(_draw_countdown)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Players.solo_changed.connect(_on_solo_changed)
	Game.state_changed.connect(_on_state_changed)
	_settings.closed.connect(_on_settings_closed)
	_confirm.chosen.connect(_on_confirm_chosen)
	visible = Game.state == Game.State.LOBBY
	if SettingsPanel.value_of(SettingsPanel.SOLO) and not Players.solo and not Game.demo:
		Players.set_solo.call_deferred(true)
	open()
	UiPreview.run.call_deferred(self)


## Fresh lobby: nobody ready, Play focused. Joined pads keep their panels; solo readies both.
func open() -> void:
	counting = false
	_launched = false
	_dots_lit = 0
	_settings.dismiss()
	_confirm.dismiss()
	$Buttons.visible = true
	_countdown.visible = true
	$TitleArt.scale = Vector2.ONE
	$TitleArt.position.x = 70.0
	$Spots.position.x = 0.0
	for p in [P1, P2]:
		readied[p] = false
		_hold[p] = 0.0
		_spots[p].readied = false
		_spots[p].hold = 0.0
		_spots[p].go = false
		_set_joined(p, Players.is_active(p))
	_buttons[Choice.PLAY].progress = 0.0
	_set_focus(Choice.PLAY, false)
	_countdown.queue_redraw()
	if Players.solo and _live():
		_ready_both()
	if visible and is_inside_tree():
		if _tw:
			_tw.kill()
		_tw = create_tween().set_parallel()
		_tw.tween_property(self, "modulate:a", 1.0, 0.25).from(0.0)
		_tw.tween_property($TitleArt, "position:y", _title_y, 0.5).from(_title_y - 260.0) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		MenuItem.slam_all(_items, 0.08, 0.06)
	_update_chip()


## UiStyle.use_skin() calls this on every open menu.
func apply_skin() -> void:
	_apply_title()
	queue_redraw()


func _live() -> bool:
	return Game.state == Game.State.LOBBY and not Game.demo


## Settings or the leave question is open over the menu.
func in_submenu() -> bool:
	return _settings.active or _confirm.active


func _process(delta: float) -> void:
	if not _live():
		return
	_countdown.queue_redraw()
	if _confirm.active:
		_confirm.handle(MenuInput.read())
		return
	if _settings.active:
		_settings.handle(MenuInput.read())
		return
	var move: int = MenuInput.read().move.y
	if move != 0:
		move_focus(move)
	for p in Players.active_players():
		if Input.is_action_just_pressed(Players.action(p, "action")):
			press_a(p)
		elif Input.is_action_just_pressed(Players.action(p, "jump")):
			press_b(p)
	if freeze or in_submenu():
		return
	for p in [P1, P2]:
		hold_step(p, Players.is_active(p) and Input.is_action_pressed(Players.action(p, "action")), delta)
	count_step(delta)


func move_focus(dir: int) -> void:
	_set_focus(MenuItem.step(_items, focus, dir) as Choice)


func focus_item(choice: Choice) -> void:
	_set_focus(choice)


func press_a(player: int) -> void:
	if in_submenu() or _launched:
		return
	_buttons[focus].press()
	match focus:
		Choice.PLAY:
			if not readied[player]:
				set_ready(player, true)
		Choice.SETTINGS:
			_settings.open()
			_settings_stage(true)
		Choice.DOOR:
			_confirm.open()


func press_b(player: int) -> void:
	if _launched:
		return
	if _confirm.active:
		_confirm.choose(false)
	elif _settings.active:
		_settings.close()
	elif readied[player]:
		set_ready(player, false)
	elif focus != Choice.PLAY:
		UiSound.play("ui_back")
		_set_focus(Choice.PLAY, false)


func set_ready(player: int, on: bool, quiet := false) -> void:
	if readied[player] == on:
		return
	readied[player] = on
	_hold[player] = 0.0
	_spots[player].hold = 0.0
	_spots[player].readied = on
	if on:
		_set_joined(player, true)
		var who: Node = _spots[player].get_node_or_null("Character")
		if who and who.has_method("wave"):
			who.wave()
	if not quiet:
		UiSound.play("player_ready" if on else "player_unready", (1.12 if player == P1 else 0.89) if on else 1.0)
	_update_chip()
	player_readied.emit(player, on)
	if on and readied[P1] and readied[P2]:
		start_countdown()
	elif not on and counting:
		cancel_countdown()


## The hold-to-start-alone rule, fed once a frame per player. Returns true when it started.
func hold_step(player: int, down: bool, delta: float) -> bool:
	if counting or not readied[player] or not down or focus != Choice.PLAY or in_submenu():
		if _hold[player] > 0.0:
			_hold[player] = 0.0
			_spots[player].hold = 0.0
			_update_progress()
		return false
	_hold[player] += delta
	_spots[player].hold = _hold[player] / HOLD_TO_START
	_update_progress()
	if _hold[player] < HOLD_TO_START:
		return false
	_hold[player] = 0.0
	_spots[player].hold = 0.0
	_update_progress()
	start_countdown()
	return true


func start_countdown() -> void:
	if counting:
		return
	counting = true
	_count_t = 0.0
	_dots_lit = 0
	countdown_started.emit()
	_light_next_dot()


func cancel_countdown() -> void:
	if not counting or _launched:
		return
	counting = false
	_dots_lit = 0
	_countdown.queue_redraw()
	UiSound.play("ui_back")
	countdown_cancelled.emit()


func count_step(delta: float) -> void:
	if not counting:
		return
	_count_t += delta
	if not _launched and _count_t >= COUNT_STEP * COUNT_DOTS - ShowtimeWipe.IN_TIME - 0.06:
		# Started a touch early so the stripes have covered the screen when the lobby hides.
		_launch()
	if _count_t >= COUNT_STEP * COUNT_DOTS:
		counting = false
		Game.finish_lobby(ready_players())
	elif _count_t >= COUNT_STEP * _dots_lit and _dots_lit < COUNT_DOTS:
		_light_next_dot()


## The last beat: GO! stamps, the Play bar flashes and squashes, everybody jumps, the wipe starts
## so that it covers the screen just as the round starts.
func _launch() -> void:
	_launched = true
	launching.emit()
	UiSound.play("ui_go")
	_buttons[Choice.PLAY].press()
	for p in ready_players():
		_spots[p].go = true
		var who: Node = _spots[p].get_node_or_null("Character")
		if who and who.has_method("cheer"):
			who.cheer()
		elif who and who.has_method("wave"):
			who.wave()
	if not is_inside_tree() or not visible:
		return
	var sk := UiStyle.skin()
	var card := ""
	if sk.round_card:
		card = sk.round_card_title % (Game.round_index + 1) if "%d" in sk.round_card_title else sk.round_card_title
	_wipe = ShowtimeWipe.run(Callable(), card, round_card_subtitle, round_card_color)


func ready_players() -> Array:
	return [P1, P2].filter(func(p: int) -> bool: return readied[p])


## The big line over the status: who we are waiting for.
func status_headline() -> String:
	if counting:
		return "BOTH PLAYERS READY" if ready_players().size() == 2 else "%s READY" % UiStyle.player_name(ready_players()[0]).to_upper()
	var joined := Players.active_players()
	var ready := ready_players()
	if joined.is_empty():
		return "WHO'S PLAYING?"
	if ready.size() == 1:
		var other: int = P2 if ready[0] == P1 else P1
		if Players.is_active(other):
			return "WAITING FOR %s" % UiStyle.player_name(other).to_upper()
		return "%s READY" % UiStyle.player_name(ready[0]).to_upper()
	return "PRESS [a] ON PLAY"


## What the status line says when nothing is counting.
func status_text() -> String:
	var joined := Players.active_players()
	var ready := ready_players()
	if joined.is_empty():
		return "Press [a] on a controller to join"
	if ready.size() == 1:
		var other: int = P2 if ready[0] == P1 else P1
		if Players.is_active(other):
			return "Waiting for %s, or hold [a] to start solo" % UiStyle.player_name(other)
		return "Hold [a] on Play to start solo"
	return "Press [a] on Play when you're ready"


func _update_progress() -> void:
	_buttons[Choice.PLAY].progress = maxf(_hold[P1], _hold[P2]) / HOLD_TO_START


func _light_next_dot() -> void:
	_dots_lit += 1
	UiSound.play("count_tick", 1.0 + 0.12 * (_dots_lit - 1))
	_countdown.queue_redraw()
	if not _countdown.is_inside_tree():
		return
	_countdown.scale = Vector2.ONE * 1.12
	var tw := _countdown.create_tween()
	tw.tween_property(_countdown, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Play's chip: who is in ("2P" with a dot per player).
func _update_chip() -> void:
	var joined := Players.active_players()
	var play: MenuItem = _buttons[Choice.PLAY]
	play.chip = "%dP" % joined.size() if not joined.is_empty() else ""
	play.chip_players = Array(joined)


func _ready_both() -> void:
	set_ready(P1, true)
	set_ready(P2, true)


func _set_focus(to: Choice, sound := true) -> void:
	# Bumping the end still makes a sound: every move does something.
	if sound:
		UiSound.play("ui_move", 1.12 - 0.1 * to)
	focus = to
	for c in _buttons:
		_buttons[c].focused = c == focus


func _set_joined(player: int, on: bool) -> void:
	_spots[player].joined = on
	_update_chip()
	var who: Node = _spots[player].get_node_or_null("Character")
	if who and who.has_method("set_joined"):
		who.set_joined(on)


func _apply_title() -> void:
	var sk := UiStyle.skin()
	var tex: Texture2D = title_texture if title_texture else sk.title_texture
	$TitleArt.texture = tex
	if sk.pixel_art:
		$TitleArt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var label: Label = $TitleArt/TitleLabel
	label.visible = tex == null
	label.text = (title_text if title_text != "" else sk.title()).to_upper()
	UiStyle.style_title(label, 190, sk.accent, $TitleArt.size.x)


func _on_player_joined(player: int, device: int) -> void:
	if not _live():
		return
	_set_joined(player, true)
	# The join press readies too (whatever is focused), unless it was B.
	# Not behind an open Settings (solo turned on there readies both when it closes).
	if device >= 0 and Input.is_joy_button_pressed(device, JOY_BUTTON_B) or in_submenu() or _launched:
		return
	_set_focus(Choice.PLAY, false)
	set_ready(player, true)


func _on_player_left(player: int) -> void:
	set_ready(player, false, true)
	_set_joined(player, false)


func _on_solo_changed(on: bool) -> void:
	if on and _live():
		# From Settings: ready both once Settings closes, not behind it.
		if in_submenu():
			_solo_pending = true
		else:
			_ready_both()


## Settings' wider wedge: the title shrinks and the podiums step left to make room.
func _settings_stage(on: bool) -> void:
	$Buttons.visible = not on
	_countdown.visible = not on
	if not is_inside_tree():
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($TitleArt, "scale", Vector2.ONE * (0.66 if on else 1.0), 0.3)
	tw.tween_property($TitleArt, "position:x", 70.0 - (190.0 if on else 0.0), 0.3)
	tw.tween_property($Spots, "position:x", -60.0 if on else 0.0, 0.3)


func _on_settings_closed() -> void:
	_settings_stage(false)
	if _solo_pending and Players.solo and _live():
		_ready_both()
	_solo_pending = false


func _on_confirm_chosen(leave: bool) -> void:
	if leave:
		Game.quit()


func _on_state_changed(_from: int, to: int) -> void:
	visible = to == Game.State.LOBBY
	if visible:
		open()
	else:
		_settings.dismiss()
		_confirm.dismiss()


func _draw_countdown() -> void:
	var c := _countdown
	var acc := UiStyle.accent
	if not counting:
		UiStyle.draw_show(c, Vector2(110, 22), status_headline().replace("[a]", "A"), 46, acc)
		UiStyle.draw_rich(c, Vector2(100, 78), status_text(), UiStyle.Role.HINT, Color(UiStyle.CREAM, 0.82), 0, 30)
		return
	var n := maxi(COUNT_DOTS - _dots_lit + 1, 1)
	var w := UiStyle.draw_show(c, Vector2(110, 22), status_headline(), 46, acc)
	UiStyle.draw_show(c, Vector2(110 + w + 30, 30), "GO!" if _launched else str(n), 84, UiStyle.CREAM, 0, 10)
	UiStyle.draw_rich(c, Vector2(100, 78), "Starting in %d   [b] Cancel" % n if not _launched else "Here we go!",
			UiStyle.Role.HINT, Color(UiStyle.CREAM, 0.82), 0, 30)
