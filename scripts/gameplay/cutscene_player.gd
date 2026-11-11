## A reusable, data-driven cutscene player (docs/cutscenes.md). A scene is a JSON file in
## data/cutscenes/<id>.json: {"id", "scene", "steps": [...]}. Playing one locks input, slides
## letterbox bars in, eases the camera(s) to the moment, runs the steps (actors walk and hop,
## a voiced line and a picture bubble per beat, items arc between actors, fades, host calls),
## then slides the bars out and hands the camera and input back. A (any player) skips the whole
## scene; skipping still runs every step marked "always" (state changes), so a skip never leaves
## the game half-way. A hard time cap ends any scene, so it never softlocks.
##
## It is game-agnostic: everything about the world comes from the host (duck-typed methods):
##   cutscene_actor(name) -> Node2D            an existing actor ("p1", "loader", ...) or null
##   cutscene_spawn(name, sheet, scene, pos) -> Node2D   a temporary actor (freed at the end)
##   cutscene_anchor(name) -> Vector2          a named world point (INF when unknown)
##   cutscene_views() -> Array                 [{camera: Camera2D, rect: Rect2}] screen views
##   cutscene_lock(on: bool)                   lock / unlock every player's input
##   cutscene_call(fn: String, args: Dictionary)   game hooks (teleport, give the shovel back...)
##   cutscene_skip_pressed() -> bool           A was just pressed by anyone
##   cutscene_character(actor) -> String       the character id an actor speaks as ("" = none)
## Split screen: every view whose camera looks at the actors' world eases to the moment (both
## halves show it); a view on another scene keeps its own camera under the bars.
class_name CutscenePlayer
extends Control

signal started(id: StringName)
signal finished(id: StringName, skipped: bool)
## A beat fired (tests and the beat log read it): kind is the step's "do", detail its main arg.
signal beat(kind: String, detail: String)

const DIR := "res://data/cutscenes/"
const LINES := "res://data/story/lines.json"
const VOICE_DIR := "res://assets/story/voice/"
const BAR_SHARE := 0.11
const BAR_TIME := 0.45
const SKIP_GRACE := 0.5
const MAX_SECS := 90.0
const BUBBLE_K := 1.6
const HEAD := Vector2(0, -34)
const INK := Color("3a2a44")
const GOLD := Color("ffd23f")

var host: Object
## Seconds per step multiplier (tests run scenes fast).
var speed := 1.0

var _data: Dictionary = {}
var _id: StringName = &""
var _steps: Array = []
var _i := 0
var _wait := 0.0
var _t := 0.0
var _playing := false
var _skipping := false
var _ending := 0.0
var _bars := 0.0
var _bars_to := 0.0
var _fade := 0.0
var _fade_from := 0.0
var _fade_to := 0.0
var _fade_t := 1.0
var _fade_dur := 0.0
var _cam := {}                    # {from, to, dx, dy, t, dur, zoom_from, zoom_to, zoom}
var _cam_k := 0.0
var _cam_k_to := 0.0
var _cam_pos := Vector2.INF
var _tasks: Array = []            # background motion: walks, hops, items
var _bubbles: Array = []          # [{who, pics, t, dur}]
var _held: Dictionary = {}        # actor name -> picture id held over its hands
var _spawned: Dictionary = {}     # name -> Node2D
var _voice: AudioStreamPlayer
var _ctx: Dictionary = {}
## Lines that played: [[line id, character, source]] (source: "file", "bark", "sfx", "none").
var said: Array = []
static var _lines: Dictionary = {}


func _init() -> void:
	name = "Cutscene"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 100   # after the director and CameraLead: the camera override wins
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice" if AudioServer.get_bus_index("Voice") != -1 else "Master"
	add_child(_voice)


# --- data ----------------------------------------------------------------------------------------

## The scene's data, or {} when there is no such file.
static func load_scene(id: StringName) -> Dictionary:
	var path := DIR + String(id) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## Every story line by id ({id, character, text, delivery, fallback}).
static func lines() -> Dictionary:
	if _lines.is_empty() and FileAccess.file_exists(LINES):
		var d = JSON.parse_string(FileAccess.get_file_as_string(LINES))
		if d is Dictionary:
			for l in d.get("lines", []):
				_lines[String(l.id)] = l
	return _lines


## The line for `id`, with "{char}" filled by `character` (falling back to "any"), or {}.
static func line(id: String, character := "") -> Dictionary:
	var all := lines()
	if id.contains("{char}"):
		var own := id.replace("{char}", character)
		return all.get(own, all.get(id.replace("{char}", "any"), {}))
	return all.get(id, {})


## Seconds a line holds its bubble: the voice file's length, else read from its word count.
static func line_secs(l: Dictionary) -> float:
	var path := VOICE_DIR + String(l.get("id", "")) + ".ogg"
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path)
		if s != null and s.get_length() > 0.0:
			return clampf(s.get_length() + 0.35, 1.2, 6.0)
	return clampf(0.9 + 0.3 * String(l.get("text", "")).split(" ").size(), 1.6, 4.2)


# --- playing -------------------------------------------------------------------------------------

func is_playing() -> bool:
	return _playing


func current() -> StringName:
	return _id if _playing else &""


## Plays scene `id`. ctx: extra anchors/actors the host reads back via context(). False when one
## is already playing or there is no such scene.
func play(id: StringName, ctx := {}) -> bool:
	if _playing:
		return false
	var d := load_scene(id)
	if d.is_empty() or not d.get("steps") is Array:
		push_warning("Cutscene: no scene '%s'" % id)
		return false
	_data = d
	_id = id
	_ctx = ctx
	_steps = d.steps
	_i = 0
	_wait = 0.0
	_t = 0.0
	_playing = true
	_skipping = false
	_ending = 0.0
	_bars_to = 1.0
	_tasks.clear()
	_bubbles.clear()
	_held.clear()
	_cam = {}
	_cam_k_to = 0.0
	_cam_pos = Vector2.INF
	_call_host("cutscene_lock", [true])
	Audio.play("split")
	started.emit(id)
	beat.emit("start", String(id))
	return true


func context() -> Dictionary:
	return _ctx


## Skips the rest of the scene: every remaining "always" step still runs (instantly).
func skip() -> void:
	if not _playing or _skipping or _ending > 0.0:
		return
	_skipping = true
	Audio.play("pop")
	_voice.stop()
	beat.emit("skip", String(_id))
	for j in range(_i, _steps.size()):
		var s: Dictionary = _steps[j]
		if bool(s.get("always", false)):
			_run(s, true)
	_i = _steps.size()
	_finish_tasks()
	_bubbles.clear()
	_end()


func _process(delta: float) -> void:
	var dt := delta * speed
	_bars = move_toward(_bars, _bars_to, delta / BAR_TIME * (2.0 if _skipping else 1.0))
	_cam_k = move_toward(_cam_k, _cam_k_to, delta / maxf(0.05, float(_cam.get("dur", 0.6)) if _cam_k_to > _cam_k else BAR_TIME))
	if _fade_t < 1.0:
		_fade_t = minf(1.0, _fade_t + dt / maxf(0.01, _fade_dur))
		_fade = lerpf(_fade_from, _fade_to, _fade_t)
	if _playing:
		_t += delta
		if _t > MAX_SECS or (host != null and not is_instance_valid(host)):
			skip()
		elif _ending <= 0.0 and _t > SKIP_GRACE and _host_bool("cutscene_skip_pressed"):
			skip()
		else:
			_tick(dt)
	for i in range(_bubbles.size() - 1, -1, -1):
		_bubbles[i].t += dt
		if _bubbles[i].t >= _bubbles[i].dur:
			_bubbles.remove_at(i)
	_apply_camera(dt)
	queue_redraw()


## A picture bubble over an actor outside any scene (the host's own little moments).
func pop_bubble(who: String, pics: Array, secs := 1.6) -> void:
	for b in _bubbles:
		if b.who == who and b.pics == pics:
			b.t = minf(b.t, 0.2)
			return
	_bubbles.append({"who": who, "pics": pics, "t": 0.0, "dur": secs})


func _tick(dt: float) -> void:
	_step_tasks(dt)
	if _ending > 0.0:
		_ending -= dt
		if _ending <= 0.0:
			_done()
		return
	_wait -= dt
	while _wait <= 0.0 and _i < _steps.size():
		var s: Dictionary = _steps[_i]
		_i += 1
		_wait += _run(s, false)
	if _wait <= 0.0 and _i >= _steps.size():
		_end()


func _end() -> void:
	if _ending > 0.0:
		return
	_bars_to = 0.0
	_cam_k_to = 0.0
	if _fade_to > 0.0 or _fade > 0.0:
		_fade_from = _fade
		_fade_to = 0.0
		_fade_t = 0.0
		_fade_dur = 0.3
	_ending = BAR_TIME
	if _skipping:
		_done()


func _done() -> void:
	_ending = 0.0
	_finish_tasks()
	_held.clear()
	for n: String in _spawned:
		var node: Node2D = _spawned[n]
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_fade = 0.0
	_fade_to = 0.0
	_fade_t = 1.0
	_bars_to = 0.0
	_cam_k_to = 0.0
	var was := _id
	var skipped := _skipping
	_playing = false
	_skipping = false
	_call_host("cutscene_lock", [false])
	beat.emit("end", String(was))
	finished.emit(was, skipped)


# --- steps ---------------------------------------------------------------------------------------

## Runs one step; returns how long the scene waits after it. `instant`: skipping (no motion).
func _run(raw: Dictionary, instant: bool) -> float:
	var s := _resolve(raw)
	if s.has("if") and not bool(_ctx.get(String(s["if"]), false)):
		return 0.0
	if s.has("unless") and bool(_ctx.get(String(s["unless"]), false)):
		return 0.0
	var kind := String(s.get("do", ""))
	var who := String(s.get("who", ""))
	if s.has("needs") and _actor(String(s.needs)) == null:
		return 0.0
	var dur := float(s.get("time", 0.0))
	var wait := float(s.get("wait", dur))
	match kind:
		"camera":
			var cur := _cam_pos if _cam_pos != Vector2.INF else _view_center()
			_cam = {"from": cur, "to": s.get("to", ""), "dx": float(s.get("dx", 0.0)), "dy": float(s.get("dy", 0.0)),
					"t": 0.0, "dur": maxf(0.05, dur if dur > 0.0 else 0.8),
					"zoom_from": float(_cam.get("zoom", _view_zoom())), "zoom": float(s.get("zoom", _cam.get("zoom", _view_zoom())))}
			_cam_k_to = 1.0
			if not s.has("wait"):
				wait = 0.0
		"camera_back":
			_cam_k_to = 0.0
		"spawn":
			var at := _point(s.get("at", ""), s)
			var node: Node2D = _host_call("cutscene_spawn", [who, String(s.get("sheet", "")), String(_data.get("scene", "")), at])
			if node != null:
				_spawned[who] = node
				_face(node, int(s.get("face", 1)))
		"walk":
			var a := _actor(who)
			if a != null:
				var to := _point(s.get("to", ""), s)
				if not s.has("to"):
					to = a.global_position + Vector2(float(s.get("dx", 0.0)), float(s.get("dy", 0.0)))
				to.y = a.global_position.y if not bool(s.get("fly", false)) else to.y
				_face(a, 1 if to.x >= a.global_position.x else -1)
				if instant:
					a.global_position = to
				else:
					_call_host("cutscene_anim", [who, "walk"])
					_tasks.append({"kind": "walk", "who": who, "node": a, "from": a.global_position, "to": to, "t": 0.0, "dur": maxf(0.05, dur if dur > 0.0 else 1.0)})
				if not s.has("wait"):
					wait = 0.0 if s.has("then") else dur
		"hop":
			var a := _actor(who)
			if a != null and not instant:
				_tasks.append({"kind": "hop", "node": a, "base": a.position.y, "h": float(s.get("height", 8.0)), "t": 0.0, "dur": maxf(0.05, dur if dur > 0.0 else 0.35), "times": int(s.get("times", 1))})
				Audio.play(String(s.get("sound", "jump")))
			if not s.has("wait"):
				wait = 0.0
		"face":
			var a := _actor(who)
			if a != null:
				var dir := int(s.get("dir", 1))
				if s.has("toward"):
					var o := _actor(String(s.toward))
					var tp := o.global_position if o != null else _point(s.toward, {})
					dir = 1 if tp.x >= a.global_position.x else -1
				_face(a, dir)
			wait = 0.0
		"show", "hide":
			var a := _actor(who)
			if a != null:
				a.visible = kind == "show"
			wait = 0.0
		"line":
			wait = _say(s, instant)
		"bubble":
			if not instant:
				_bubbles.append({"who": who, "pics": s.get("pics", []), "t": 0.0, "dur": dur if dur > 0.0 else 1.8})
			if not s.has("wait"):
				wait = 0.0 if s.has("then") else (dur if dur > 0.0 else 1.8)
		"item":
			if not instant:
				_tasks.append({"kind": "item", "pic": String(s.get("pic", "")), "from": String(s.get("from", "")), "to": String(s.get("to", "")),
						"t": 0.0, "dur": maxf(0.05, dur if dur > 0.0 else 0.7)})
				Audio.play(String(s.get("sound", "pop")))
			_held.erase(String(s.get("from", "")))
		"hold":
			_held[who] = String(s.get("pic", ""))
			wait = 0.0
		"drop":
			_held.erase(who)
			wait = 0.0
		"sound":
			Audio.play(String(s.get("cue", "")))
			wait = 0.0 if not s.has("wait") else wait
		"fade":
			_fade_from = _fade
			_fade_to = float(s.get("to", 1.0))
			_fade_dur = maxf(0.01, dur if dur > 0.0 else 0.6)
			_fade_t = 0.0
			if instant:
				_fade = _fade_to
				_fade_t = 1.0
		"bars":
			_bars_to = 1.0 if bool(s.get("on", true)) else 0.0
			wait = 0.0
		"call":
			_call_host("cutscene_call", [String(s.get("fn", "")), s.get("args", {})])
		"wait":
			pass
		_:
			push_warning("Cutscene %s: unknown step '%s'" % [_id, kind])
			wait = 0.0
	beat.emit(kind, String(s.get("line", s.get("fn", s.get("pic", who)))))
	return maxf(0.0, wait)


## A step with the play context filled in: a value "@key" becomes ctx[key]; "{key}" inside a
## string becomes str(ctx[key]) ("{char}" is left for the line lookup).
func _resolve(s: Dictionary) -> Dictionary:
	var out := {}
	for k in s:
		out[k] = _fill(s[k])
	return out


func _fill(v):
	if v is String:
		var sv: String = v
		if sv.begins_with("@") and _ctx.has(sv.substr(1)):
			return _ctx[sv.substr(1)]
		for key in _ctx:
			if sv.contains("{%s}" % key):
				sv = sv.replace("{%s}" % key, str(_ctx[key]))
		return sv
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_fill(x))
		return a
	return v


func _say(s: Dictionary, instant: bool) -> float:
	var who := String(s.get("who", ""))
	var a := _actor(who)
	if a == null and s.has("needs"):
		return 0.0
	var ch := String(_host_call("cutscene_character", [who])) if host != null else ""
	var l := line(String(s.get("line", "")), ch)
	var dur := float(s.get("time", 0.0))
	if dur <= 0.0:
		dur = line_secs(l) if not l.is_empty() else 2.0
	if instant:
		return 0.0
	_bubbles.append({"who": who, "pics": s.get("pics", []), "t": 0.0, "dur": dur})
	_play_voice(l, ch)
	if s.has("wait"):
		return float(s.wait)
	return dur


## The line's own file if Gary made it, else the speaker's library bark or an sfx cue.
func _play_voice(l: Dictionary, speaker: String) -> void:
	if l.is_empty():
		return
	var id := String(l.id)
	var path := VOICE_DIR + id + ".ogg"
	var who := String(l.get("character", ""))
	if who == "any" or who == "":
		who = speaker
	if ResourceLoader.exists(path) and (String(l.get("character", "")) == speaker or speaker == "" or String(l.get("character", "")) == "any" or not _is_player_line(l)):
		_voice.stream = load(path)
		_voice.play()
		Audio.duck(-8.0, _voice.stream.get_length())
		said.append([id, who, "file"])
		return
	var fb := String(l.get("fallback", ""))
	if fb.begins_with("bark:"):
		var st := Audio.bark_stream(speaker if speaker != "" else who, fb.substr(5))
		if st != null:
			_voice.stream = st
			_voice.play()
			Audio.duck(-8.0, st.get_length())
			said.append([id, who, "bark"])
			return
		Audio.play("resident_hm")
		said.append([id, who, "sfx"])
	elif fb.begins_with("sfx:"):
		Audio.play(fb.substr(4))
		said.append([id, who, "sfx"])
	else:
		said.append([id, who, "none"])


func _is_player_line(l: Dictionary) -> bool:
	return String(l.get("character", "")) in ["jeff", "chuck", "any"]


func _step_tasks(dt: float) -> void:
	for i in range(_tasks.size() - 1, -1, -1):
		var k: Dictionary = _tasks[i]
		k.t += dt
		var f := clampf(float(k.t) / float(k.dur), 0.0, 1.0)
		var node: Node2D = k.get("node")
		if k.has("node") and not is_instance_valid(node):
			_tasks.remove_at(i)
			continue
		match String(k.kind):
			"walk":
				var gp := (k.from as Vector2).lerp(k.to, smoothstep(0.0, 1.0, f))
				gp.y = (k.from as Vector2).y + ((k.to as Vector2).y - (k.from as Vector2).y) * f - absf(sin(f * PI * 6.0)) * 2.0
				node.global_position = gp
			"hop":
				var times: int = k.times
				var ff := fmod(f * times, 1.0) if f < 1.0 else 1.0
				node.position.y = float(k.base) - sin(ff * PI) * float(k.h)
		if f >= 1.0:
			if String(k.kind) == "hop":
				node.position.y = k.base
			elif String(k.kind) == "walk":
				node.global_position = k.to
				_call_host("cutscene_anim", [String(k.who), "idle"])
			_tasks.remove_at(i)


func _finish_tasks() -> void:
	for k: Dictionary in _tasks:
		var node: Node2D = k.get("node")
		if not is_instance_valid(node):
			continue
		match String(k.kind):
			"walk":
				node.global_position = k.to
				_call_host("cutscene_anim", [String(k.who), "idle"])
			"hop":
				node.position.y = k.base
	_tasks.clear()


# --- actors and points ---------------------------------------------------------------------------

func _actor(n: String) -> Node2D:
	if n == "":
		return null
	if _spawned.has(n) and is_instance_valid(_spawned[n]):
		return _spawned[n]
	var a = _host_call("cutscene_actor", [n])
	return a if a is Node2D and is_instance_valid(a) else null


## A step's point: an actor's feet, a host anchor, or [x, y]; plus dx / dy.
func _point(spec, s: Dictionary) -> Vector2:
	var p := Vector2.INF
	if spec is Array and spec.size() >= 2:
		p = Vector2(float(spec[0]), float(spec[1]))
	elif String(spec) != "":
		var a := _actor(String(spec))
		if a != null:
			p = a.global_position
		else:
			var v = _host_call("cutscene_anchor", [String(spec)])
			if v is Vector2:
				p = v
	if p == Vector2.INF:
		p = _view_center()
	return p + Vector2(float(s.get("dx", 0.0)), float(s.get("dy", 0.0)))


func _face(a: Node2D, dir: int) -> void:
	if a == null or dir == 0:
		return
	if a is Sprite2D:
		# Sheets face right unless the manifest says left; the host's sprites flip with flip_h.
		(a as Sprite2D).flip_h = dir < 0
	elif "facing" in a:
		a.set("facing", dir)


# --- camera --------------------------------------------------------------------------------------

func _views() -> Array:
	var v = _host_call("cutscene_views", [])
	return v if v is Array else []


func _view_center() -> Vector2:
	for v in _views():
		var cam: Camera2D = v.camera
		if cam != null:
			return cam.get_screen_center_position()
	return Vector2.ZERO


func _view_zoom() -> float:
	for v in _views():
		var cam: Camera2D = v.camera
		if cam != null:
			return cam.zoom.x
	return 2.0


func _world() -> World2D:
	for n: String in _spawned:
		if is_instance_valid(_spawned[n]):
			return (_spawned[n] as Node2D).get_world_2d()
	var spec = _cam.get("to", "")
	var a := _actor(String(spec)) if not spec is Array else null
	if a != null:
		return a.get_world_2d()
	var f = _ctx.get("focus", "")
	a = _actor(String(f))
	return a.get_world_2d() if a != null else null


func _apply_camera(dt: float) -> void:
	if _cam.is_empty() or _cam_k <= 0.0:
		return
	_cam.t = float(_cam.t) + dt
	var f := smoothstep(0.0, 1.0, clampf(float(_cam.t) / float(_cam.dur), 0.0, 1.0))
	var target := _point(_cam.to, {"dx": _cam.dx, "dy": _cam.dy})
	_cam_pos = (_cam.from as Vector2).lerp(target, f)
	var z := lerpf(float(_cam.zoom_from), float(_cam.zoom), f)
	var w := _world()
	for v in _views():
		var cam: Camera2D = v.camera
		if cam == null or (w != null and cam.get_world_2d() != w):
			continue
		cam.position = cam.position.lerp(_cam_pos, _cam_k).round()
		cam.zoom = cam.zoom.lerp(Vector2(z, z), _cam_k)


# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	var sz := size
	if _fade > 0.001:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.03, 0.06, _fade))
	for b in _bubbles:
		_draw_bubble(b)
	if _playing or _held.size() > 0:
		for n: String in _held:
			var a := _actor(n)
			if a != null:
				for v in _views():
					var sp := _screen(a, v)
					if sp != Vector2.INF:
						PictoBubble.picture(self, StringName(_held[n]), sp + Vector2(10, -16) * _zoom_of(v), PictoBubble.CELL * _zoom_of(v) * 0.8)
		for k: Dictionary in _tasks:
			if String(k.kind) == "item":
				_draw_item(k)
	if _bars > 0.001:
		var h := sz.y * BAR_SHARE * smoothstep(0.0, 1.0, _bars)
		draw_rect(Rect2(0, 0, sz.x, h), Color.BLACK)
		draw_rect(Rect2(0, sz.y - h, sz.x, h), Color.BLACK)
		if _playing and not _skipping and _ending <= 0.0 and _t > SKIP_GRACE:
			_draw_skip_glyph(Vector2(sz.x - h * 0.9, sz.y - h * 0.5), h * 0.32)


## The A button glyph (green, a white A shape drawn as lines: a glyph, not text) with a little
## fast-forward arrow pair beside it, softly pulsing.
func _draw_skip_glyph(c: Vector2, r: float) -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 4.0)
	draw_circle(c, r * 1.08, Color(0, 0, 0, 0.6))
	draw_circle(c, r, Color(Color("3cc24a"), pulse))
	var w := Color(1, 1, 1, pulse)
	draw_line(c + Vector2(-0.42, 0.5) * r, c + Vector2(0, -0.55) * r, w, r * 0.18)
	draw_line(c + Vector2(0.42, 0.5) * r, c + Vector2(0, -0.55) * r, w, r * 0.18)
	draw_line(c + Vector2(-0.22, 0.12) * r, c + Vector2(0.22, 0.12) * r, w, r * 0.16)
	for k in 2:
		var x0 := c.x - r * 2.9 + k * r * 0.8
		draw_colored_polygon(PackedVector2Array([Vector2(x0, c.y - r * 0.5), Vector2(x0 + r * 0.7, c.y), Vector2(x0, c.y + r * 0.5)]), Color(1, 1, 1, pulse * 0.8))


func _zoom_of(v: Dictionary) -> float:
	var cam: Camera2D = v.camera
	return cam.zoom.x if cam != null else 2.0


## Where an actor's feet are on screen in view v, or INF when that view shows another world.
func _screen(a: Node2D, v: Dictionary, offset := Vector2.ZERO) -> Vector2:
	var cam: Camera2D = v.camera
	if cam == null or a == null or cam.get_world_2d() != a.get_world_2d():
		return Vector2.INF
	var r: Rect2 = v.rect
	var p := r.position + r.size * 0.5 + (a.global_position + offset - cam.get_screen_center_position()) * cam.zoom
	if not r.grow(40.0).has_point(p):
		return Vector2.INF
	return p


func _head_of(n: String) -> Vector2:
	var h = _host_call("cutscene_head", [n])
	return h if h is Vector2 else HEAD


func _draw_bubble(b: Dictionary) -> void:
	var a := _actor(String(b.who))
	if a == null or (b.pics as Array).is_empty():
		return
	var f := float(b.t) / maxf(0.01, float(b.dur))
	var pop := clampf(float(b.t) / 0.18, 0.0, 1.0)
	var alpha := clampf((1.0 - f) * 6.0, 0.0, 1.0)
	for v in _views():
		var tip := _screen(a, v, _head_of(String(b.who)))
		if tip == Vector2.INF:
			continue
		var k := _zoom_of(v) * BUBBLE_K * lerpf(0.6, 1.0, pop) * (1.0 + 0.08 * sin(pop * PI))
		# Keep the bubble inside the view and below the top bar.
		var bs := PictoBubble.size_for((b.pics as Array).size(), k)
		var r: Rect2 = v.rect
		var top := r.position.y + size.y * BAR_SHARE * _bars + 6.0
		tip.y = maxf(tip.y, top + bs.y + 8.0 * k)
		tip.x = clampf(tip.x, r.position.x + bs.x * 0.5 + 6.0, r.end.x - bs.x * 0.5 - 6.0)
		PictoBubble.draw(self, tip, b.pics, alpha, k)


func _draw_item(k: Dictionary) -> void:
	var a := _actor(String(k.from))
	var b := _actor(String(k.to))
	var f := smoothstep(0.0, 1.0, clampf(float(k.t) / float(k.dur), 0.0, 1.0))
	for v in _views():
		var p0 := _screen(a, v, Vector2(0, -16)) if a != null else Vector2.INF
		var p1 := _screen(b, v, Vector2(0, -16)) if b != null else Vector2.INF
		if p0 == Vector2.INF and p1 == Vector2.INF:
			continue
		if p0 == Vector2.INF:
			p0 = p1 + Vector2(0, -60)
		if p1 == Vector2.INF:
			p1 = p0 + Vector2(0, -60)
		var z := _zoom_of(v)
		var p := p0.lerp(p1, f) + Vector2(0, -22.0 * z * sin(f * PI))
		PictoBubble.picture(self, StringName(k.pic), p, PictoBubble.CELL * z * 0.9)
		if f > 0.85:
			for i in 5:
				var ang := TAU * i / 5.0 + float(k.t) * 3.0
				draw_circle(p1 + Vector2.from_angle(ang) * 14.0 * z * (f - 0.85) / 0.15, 2.0 * z, Color(GOLD, 1.0 - (f - 0.85) / 0.15))


# --- host ----------------------------------------------------------------------------------------

func _host_call(m: String, args: Array):
	if host == null or not is_instance_valid(host) or not host.has_method(m):
		return null
	return host.callv(m, args)


func _call_host(m: String, args: Array) -> void:
	_host_call(m, args)


func _host_bool(m: String) -> bool:
	return bool(_host_call(m, []))
