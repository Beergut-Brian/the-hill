## UiSound: menu sound cues for the Showtime menu kit, with a synthesized fallback.
##
## UiSound.play("ui_confirm") plays the real file when one exists
## (res://assets/audio/sfx/<cue>.ogg or <cue>_1.ogg, via the Audio autoload).
## Otherwise it plays a cue synthesized in code (16-bit mono 44.1 kHz AudioStreamWAV),
## so every menu action makes a sound before the Audio lane delivers files.
## Dropping an .ogg with the same name into assets/audio/sfx replaces the synth
## automatically. Pitch (pitch_scale) only applies to the synth; callers vary it per player.
##
## Cues: ui_move, ui_back, ui_confirm, ui_tick, ui_toggle, player_ready,
## player_unready, player_join, count_tick, ui_go, ui_wipe, ui_card, ui_pause.
class_name UiSound
extends RefCounted

const RATE := 44100
const PEAK := 0.6
const POOL_SIZE := 8
const SFX_DIR := "res://assets/audio/sfx/"

const CUES := {
	"ui_move": "tight arcade tak, 45 ms",
	"ui_back": "reversed tak, rising and slightly lower, 70 ms",
	"ui_confirm": "two-note brass stab (E5, A5) over a low thump",
	"ui_tick": "ratchet tick for settings segments, 25 ms",
	"ui_toggle": "switch clack: noise burst plus low click, 60 ms",
	"player_ready": "3-note rising sting then a stamp chunk, ~300 ms",
	"player_unready": "two descending notes, ~200 ms",
	"player_join": "quick upward blip, ~150 ms",
	"count_tick": "clean 880 Hz beep, 90 ms",
	"ui_go": "bright major chord hit, 350 ms",
	"ui_wipe": "three fast whooshes, ~0.5 s",
	"ui_card": "cymbal swell then quick tail, ~0.7 s",
	"ui_pause": "record-scratch pitch dip then soft low pad, ~0.6 s",
}

static var _cache: Dictionary = {}
static var _warned: Dictionary = {}
static var _pool_node: Node = null
static var _next := 0


## Play a cue: real file through Audio if present, else the synth on a small pool.
static func play(cue: String, pitch := 1.0) -> void:
	if has_file(cue):
		var audio := _audio()
		if audio:
			audio.play(cue)
			return
	var s := stream(cue)
	if s == null:
		if not _warned.has(cue):
			_warned[cue] = true
			push_warning("UiSound: unknown cue '%s'" % cue)
		return
	var node := _ensure_pool()
	if node == null or node.get_child_count() == 0:
		return
	var p := node.get_child(_next % node.get_child_count()) as AudioStreamPlayer
	_next += 1
	if p == null:
		return
	p.stream = s
	p.pitch_scale = maxf(pitch, 0.01)
	if p.is_inside_tree():
		p.play()
	else:
		p.play.call_deferred() # pool node is still being added to the tree


## True when a real sound file replaces the synth for this cue.
static func has_file(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists(SFX_DIR + cue + "_1.ogg")


## The synthesized stream (cached); null for an unknown cue.
static func stream(cue: String) -> AudioStreamWAV:
	if not CUES.has(cue):
		return null
	if not _cache.has(cue):
		_cache[cue] = _to_wav(_build(cue))
	return _cache[cue]


static func _audio() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null("Audio")


static func _ensure_pool() -> Node:
	if _pool_node != null and is_instance_valid(_pool_node):
		return _pool_node
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	var existing := loop.root.get_node_or_null("UiSound")
	if existing != null and not existing.is_queued_for_deletion():
		_pool_node = existing
		return existing
	var n := Node.new()
	n.name = "UiSound"
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		n.add_child(p)
	_pool_node = n
	loop.root.add_child.call_deferred(n)
	return n


# ---- synthesis ----------------------------------------------------------------------

static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := PEAK / peak
	var fade := mini(int(RATE * 0.004), buf.size() / 2)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := buf[i] * gain
		if i < fade:
			v *= float(i) / fade
		elif i >= buf.size() - fade:
			v *= float(buf.size() - 1 - i) / fade
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _blank(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


static func _wave(kind: int, ph: float) -> float:
	var f := fposmod(ph, 1.0)
	match kind:
		0: return sin(f * TAU)
		1: return 1.0 if f < 0.5 else -1.0
		_: return f * 2.0 - 1.0


## Add a tone at `start` seconds. kind: 0 sine, 1 square, 2 saw. env: attack 0..1 of
## length; decay is exponential by `decay`. lp: one-pole lowpass amount (0 = none, 0..1 darker).
static func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		kind := 0, amp := 1.0, decay := 4.0, lp := 0.0, attack := 0.05) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	var y := 0.0
	for i in n:
		if i0 + i >= b.size():
			break
		var t := float(i) / maxi(n - 1, 1)
		ph += lerpf(f0, f1, t) / RATE
		var e := exp(-decay * t) * minf(t / maxf(attack, 0.0001), 1.0)
		var s := _wave(kind, ph)
		y = lerpf(s, y, lp)
		b[i0 + i] += y * e * amp


## Add noise at `start`. env_fn: 0 decay, 1 swell (sin^2 bump), 2 rise then quick tail.
## bright0/bright1: filter openness 0..1 (1 = white) at start/end.
static func _noise(b: PackedFloat32Array, rng: RandomNumberGenerator, start: float, dur: float,
		amp := 1.0, env_kind := 0, bright0 := 1.0, bright1 := 1.0, decay := 6.0) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		if i0 + i >= b.size():
			break
		var t := float(i) / maxi(n - 1, 1)
		var e := 1.0
		match env_kind:
			0: e = exp(-decay * t)
			1: e = pow(sin(t * PI), 2.0)
			2: e = (pow(t / 0.85, 2.0) if t < 0.85 else exp(-30.0 * (t - 0.85)))
		var k := lerpf(bright0, bright1, t)
		y = lerpf(y, rng.randf_range(-1.0, 1.0), clampf(k, 0.02, 1.0))
		b[i0 + i] += y * e * amp


static func _reverse(b: PackedFloat32Array) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	for i in range(b.size() - 1, -1, -1):
		r.append(b[i])
	return r


static func _build(cue: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cue)
	var b: PackedFloat32Array
	match cue:
		"ui_move":
			b = _blank(0.045)
			_tone(b, 0.0, 0.045, 1500.0, 900.0, 1, 0.8, 7.0, 0.0, 0.01)
			_noise(b, rng, 0.0, 0.01, 0.3, 0, 1.0, 1.0, 5.0)
		"ui_back":
			b = _blank(0.07)
			_tone(b, 0.0, 0.07, 1000.0, 600.0, 1, 0.8, 7.0, 0.0, 0.01)
			b = _reverse(b)
		"ui_confirm":
			b = _blank(0.14)
			_tone(b, 0.0, 0.12, 70.0, 60.0, 0, 1.0, 3.0)
			_tone(b, 0.0, 0.07, 659.25, 659.25, 2, 0.5, 3.0, 0.5)
			_tone(b, 0.07, 0.07, 880.0, 880.0, 2, 0.55, 3.0, 0.5)
			_tone(b, 0.07, 0.07, 1318.5, 1318.5, 1, 0.15, 3.0, 0.7)
		"ui_tick":
			b = _blank(0.025)
			_tone(b, 0.0, 0.025, 2200.0, 1800.0, 1, 0.7, 9.0, 0.0, 0.02)
			_noise(b, rng, 0.0, 0.005, 0.4, 0, 1.0, 1.0, 3.0)
		"ui_toggle":
			b = _blank(0.06)
			_noise(b, rng, 0.0, 0.03, 0.7, 0, 0.7, 0.4, 8.0)
			_tone(b, 0.0, 0.06, 220.0, 120.0, 0, 0.9, 8.0, 0.0, 0.02)
			_tone(b, 0.03, 0.03, 1200.0, 800.0, 1, 0.3, 8.0, 0.3)
		"player_ready":
			b = _blank(0.34)
			var notes := [523.25, 659.25, 783.99]
			for i in 3:
				_tone(b, i * 0.07, 0.09, notes[i], notes[i], 2, 0.5, 3.0, 0.4, 0.03)
			_noise(b, rng, 0.22, 0.12, 0.8, 0, 0.12, 0.05, 6.0)
			_tone(b, 0.22, 0.12, 90.0, 45.0, 0, 1.0, 5.0)
		"player_unready":
			b = _blank(0.2)
			_tone(b, 0.0, 0.1, 659.25, 659.25, 1, 0.5, 3.0, 0.5, 0.03)
			_tone(b, 0.1, 0.1, 440.0, 392.0, 1, 0.5, 3.5, 0.5, 0.03)
		"player_join":
			b = _blank(0.15)
			_tone(b, 0.0, 0.15, 440.0, 1100.0, 1, 0.6, 2.5, 0.4, 0.04)
		"count_tick":
			b = _blank(0.09)
			_tone(b, 0.0, 0.09, 880.0, 880.0, 0, 1.0, 2.5, 0.0, 0.05)
		"ui_go":
			b = _blank(0.35)
			for f in [523.25, 659.25, 783.99, 1046.5]:
				_tone(b, 0.0, 0.35, f, f, 2, 0.3, 4.5, 0.3, 0.01)
			_tone(b, 0.0, 0.2, 65.0, 55.0, 0, 0.6, 5.0)
		"ui_wipe":
			b = _blank(0.5)
			for i in 3:
				_noise(b, rng, i * 0.15, 0.2, 0.9, 1, 0.08, 0.5, 0.0)
		"ui_card":
			b = _blank(0.7)
			_noise(b, rng, 0.0, 0.7, 0.9, 2, 0.1, 1.0)
		"ui_pause":
			b = _blank(0.6)
			_tone(b, 0.0, 0.2, 900.0, 120.0, 2, 0.5, 2.0, 0.6, 0.02)
			_noise(b, rng, 0.0, 0.2, 0.25, 0, 0.4, 0.15, 3.0)
			_tone(b, 0.2, 0.4, 110.0, 110.0, 0, 0.5, 2.0, 0.0, 0.3)
			_tone(b, 0.2, 0.4, 164.8, 164.8, 0, 0.3, 2.0, 0.0, 0.3)
		_:
			b = _blank(0.03)
	return b
