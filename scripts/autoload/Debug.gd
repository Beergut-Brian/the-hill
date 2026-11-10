## F3 overlay, F12 screenshot, --screenshot-after=<s> for headless review. Autoload: Debug.
## Real frames without a monitor: --shots=1,3.5,6 [--shot-dir=/abs/dir] saves a PNG at each time (seconds
## after boot) and quits after the last one. Needs a real renderer: run it through scripts/tools/shots.sh.
extends CanvasLayer

var _label: Label
var _shot_after := -1.0
var _shots: Array[float] = []
var _shot_dir := "user://screenshots"
var _clock := 0.0


## `--roster-data=res://tests/fixtures/x.json`: play with another roster file (a test fixture, e.g. the
## stand-in third character for shots), in any scene. Ignored when the file is not there (exports
## ship no tests/), so it can never change a release.
static func roster_data_arg(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--roster-data="):
			var path := a.trim_prefix("--roster-data=")
			return path if FileAccess.file_exists(path) else ""
	return ""


func _ready() -> void:
	# Debug is registered before Roster: set the path now and Roster's own _ready reads it.
	var data := roster_data_arg(OS.get_cmdline_user_args() + OS.get_cmdline_args())
	if data != "":
		Roster.data_path = data
		if Roster.is_inside_tree():
			Roster.reload()
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 20)
	_label.visible = false
	add_child(_label)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-after="):
			_shot_after = float(arg.trim_prefix("--screenshot-after="))
		elif arg.begins_with("--shots="):
			for s in arg.trim_prefix("--shots=").split(",", false):
				_shots.append(float(s))
			_shots.sort()
		elif arg.begins_with("--shot-dir="):
			_shot_dir = arg.trim_prefix("--shot-dir=")


func _process(delta: float) -> void:
	if _label.visible:
		_label.text = "fps %d\nstate %s\nround %d\nplayers %s" % [
			Engine.get_frames_per_second(),
			Game.State.keys()[Game.state],
			Game.round_index,
			str(Players.active_players())]
	if not _shots.is_empty():
		_clock += delta
		if _clock >= _shots[0]:
			var t: float = _shots.pop_front()
			await screenshot("t%05.1fs" % t)
			if _shots.is_empty():
				get_tree().quit()
	if _shot_after >= 0.0:
		_shot_after -= delta
		if _shot_after < 0.0:
			await screenshot()
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_label.visible = not _label.visible
	elif event.is_action_pressed("debug_screenshot"):
		screenshot()


func screenshot(tag: String = "") -> String:
	if DisplayServer.get_name() == "headless":
		# No renderer: report state instead so the Reviewer still gets a signal of life.
		print("screenshot: headless, state=%s players=%s" % [Game.State.keys()[Game.state], str(Players.active_players())])
		return ""
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var stamp := tag if tag != "" else Time.get_datetime_string_from_system().replace(":", "-")
	var path := _shot_dir.path_join("%s.png" % stamp)
	img.save_png(path)
	print("screenshot: ", ProjectSettings.globalize_path(path))
	return path
