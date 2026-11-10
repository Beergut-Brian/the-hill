## Sound on every action. Autoload: Audio.
## play("cue") looks for assets/audio/sfx/cue.ogg, or cue_1.ogg..cue_N.ogg and picks one.
## Missing cues warn once and never crash. While synth_missing is on, a missing SFX cue plays a short
## generated beep instead (pitch from the cue name; dig_* cues get a low thud), so placeholder
## builds are never silent. Music and barks stay silent when missing.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://addons/openjar/characters/"
const POOL_SIZE := 12
const SYNTH_RATE := 22050
const SYNTH_LENGTH := 0.09
## Pentatonic, 220..880 Hz: placeholder beeps that never clash.
const SYNTH_NOTES: Array[float] = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
## dig_* cues: low thuds, so digging does not sound like a doorbell.
const SYNTH_THUDS: Array[float] = [65.41, 73.42, 82.41, 98.0, 110.0, 130.81]

## false: missing SFX cues are silent.
var synth_missing := true

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _warned := {}
var _cache := {}
var _synth := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	set_volume("Music", Save.get_setting("music_volume", 0.8))
	set_volume("SFX", Save.get_setting("sound_volume", 1.0))


## bus: "Music" or "SFX"; linear 0..1 (the Settings sliders). 0 mutes.
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


func play(cue: String, _position = null) -> void:
	var stream := stream_for(cue)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return
	_pool[0].stream = stream
	_pool[0].play()


## A real file exists for this SFX cue.
func has_cue(cue: String) -> bool:
	return not _variants(SFX_DIR, cue).is_empty()


## What play(cue) would play: a file variant, the synth beep (synth_missing), or null.
func stream_for(cue: String) -> AudioStream:
	var stream := _resolve(SFX_DIR, cue)
	if stream == null and synth_missing:
		stream = synth_stream(cue)
	return stream


## The placeholder beep for a cue: ~0.09 s, 22050 Hz 16-bit mono, fast decay. Cached per cue.
func synth_stream(cue: String) -> AudioStreamWAV:
	if _synth.has(cue):
		return _synth[cue]
	var thud := cue.begins_with("dig_")
	var notes := SYNTH_THUDS if thud else SYNTH_NOTES
	var freq: float = notes[absi(cue.hash()) % notes.size()]
	var n := int(SYNTH_RATE * SYNTH_LENGTH)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = cue.hash()
	for i in n:
		var t := float(i) / SYNTH_RATE
		var env := minf(t / 0.003, 1.0) * exp(-t * (45.0 if thud else 32.0))
		# Thuds glide down an octave and carry a little noise; beeps are sine plus a soft overtone.
		var f := freq * (2.0 - minf(t / SYNTH_LENGTH, 1.0)) if thud else freq
		phase += TAU * f / SYNTH_RATE
		var v := sin(phase) + 0.25 * sin(phase * 2.0)
		if thud:
			v = v * 0.8 + rng.randf_range(-0.35, 0.35)
		data.encode_s16(i * 2, int(clampf(v * env * 0.6, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SYNTH_RATE
	wav.stereo = false
	wav.data = data
	_synth[cue] = wav
	return wav


func music(track: String, fade: float = 0.5) -> void:
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func bark(character: String, bark_name: String) -> void:
	var stream := _resolve("%s%s/voice/" % [VOICE_DIR, character], bark_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0
			p.play()
			return


func _resolve(dir: String, cue: String) -> AudioStream:
	var key := dir + cue
	var variants := _variants(dir, cue)
	if variants.is_empty():
		if not _warned.has(key):
			_warned[key] = true
			push_warning("Audio: no file for cue '%s' in %s" % [cue, dir])
		return null
	return variants.pick_random()


func _variants(dir: String, cue: String) -> Array:
	var key := dir + cue
	if _cache.has(key):
		return _cache[key]
	var variants: Array = []
	if ResourceLoader.exists(dir + cue + ".ogg"):
		variants.append(load(dir + cue + ".ogg"))
	else:
		var i := 1
		while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue, i]):
			variants.append(load("%s%s_%d.ogg" % [dir, cue, i]))
			i += 1
	_cache[key] = variants
	return variants
