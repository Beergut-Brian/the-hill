## Sound on every action. Autoload: Audio. Cue list and mix notes: assets/audio/CUES.md.
##
## play("cue") plays assets/audio/sfx/cue.(ogg|wav), or rotates through cue_1..cue_N (shuffled,
## never the same variant twice in a row). ALIASES map the design names (GAME.md: engine_<v>,
## horn_<v>, gnome_whistle, tip, build_move) onto the names the code plays. Every cue is rate
## capped (CAPS: a minimum gap and a maximum of simultaneous voices) so a digging frenzy never
## stacks up; big moments duck the music (DUCKS). Missing cues warn once and never crash; while
## synth_missing is on a missing SFX cue plays a short generated beep so a build is never silent.
##
## Buses: Master (hard limiter at -1 dB, nothing clips) <- Music (duck amplifier), SFX, Voice.
## Engines: engine(key, cue) starts a looped engine per key (a player), engine_speed(key, 0..1)
## pitches it (ENGINE_PITCH) and opens it up, engine_stop(key). engine_level(key, db) gives a
## non-engine loop (the drain gurgle) its own level instead.
## Music: music_state(theme, zone, cavern) drives the layered theme: one AudioStreamSynchronized of
## music_up, music_down and music_down_layer_1..N, crossfaded by stream volume, plus music_cavern
## on its own looped player. music(track) still plays a single file.
## Barks: bark(character, cue) plays one line on the Voice bus from the character's voice pack
## (Roster voice dir, else assets/characters/<id>/voice/), else the synth placeholder in
## assets/audio/voice/<id>_<cue>[_n].ogg. One bark at a time, rate capped; false when skipped.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://assets/audio/voice/"
const CHARACTERS_DIR := "res://assets/characters/"
const POOL_SIZE := 16
const SYNTH_RATE := 22050
const SYNTH_LENGTH := 0.09
## Pentatonic, 220..880 Hz: placeholder beeps that never clash.
const SYNTH_NOTES: Array[float] = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
## dig_* cues: low thuds, so digging does not sound like a doorbell.
const SYNTH_THUDS: Array[float] = [65.41, 73.42, 82.41, 98.0, 110.0, 130.81]
const SILENT_DB := -60.0

## Design names (GAME.md Audio table) -> the cue the files are named after.
const ALIASES := {
	"engine_front_loader": "front_loader_engine", "engine_excavator": "excavator_engine",
	"engine_dump_truck": "dump_truck_engine", "engine_crane": "crane_engine",
	"engine_drill_rig": "drill_rig_engine",
	"horn_front_loader": "front_loader_horn", "horn_excavator": "excavator_horn",
	"horn_dump_truck": "dump_truck_horn", "horn_crane": "crane_horn", "horn_drill_rig": "drill_rig_horn",
	"gnome_whistle": "whistle", "tip": "dump_truck_tip", "build_move": "build_pickup",
	"restore_plank": "plank", "dig_edgestone": "dig_stone", "dig_strangestone": "dig_stone",
	# B-06 Workshop: stand-ins until Audio makes its own (gap-close-1, "Needs other lanes").
	"workshop_hammer": "elevator_clank", "tool_upgrade": "treasure_pickup",
}
## [minimum seconds between two starts, maximum voices at once]. A key ending in * is a prefix.
## Anything not listed: DEFAULT_CAP.
const DEFAULT_CAP := [0.05, 3]
const CAPS := {
	"dig_*": [0.06, 3], "mole_dig": [0.2, 1], "swing": [0.08, 2], "fall": [0.08, 3],
	"pile_dump": [0.1, 2], "march_step": [0.09, 2], "whistle": [0.12, 2], "ice_drip": [0.5, 1],
	"dragon_snore": [1.5, 1], "jump": [0.08, 2], "splash": [0.15, 2], "ui_move": [0.03, 2],
	"treasure*": [0.1, 2], "bonk": [0.2, 2], "flood": [0.5, 1], "plank": [0.06, 2],
	"*_horn": [0.15, 1], "horn": [0.15, 1], "honk": [0.3, 1], "dump_truck_reverse": [0.6, 1],
	"backpack_full": [1.5, 1], "*_dig": [0.1, 2], "book_*": [0.1, 1],
	"drill_rig_spin": [0.25, 1], "scoop": [0.1, 2], "rock_crack": [0.08, 2], "tree_fall": [0.2, 2],
	"worm_boop": [0.25, 2],
}
## Cues that duck the music: [dB, hold seconds].
const DUCKS := {
	"treasure_big": [-6.0, 1.2], "treasure_huge": [-9.0, 2.0], "treasure": [-4.0, 0.8],
	"build_place": [-4.0, 1.0], "elevator": [-4.0, 1.4], "light_on": [-6.0, 1.2],
	"resident_arrive": [-6.0, 1.2], "payoff_*": [-10.0, 2.0], "dragon_yawn": [-6.0, 1.4],
	"cave_in": [-4.0, 0.8],
}
const BARK_DUCK_DB := -5.0
## Gap after any bark before the next one, and before the same character + cue again.
const BARK_GAP := 2.5
const BARK_REPEAT := 8.0
## Engine pitch at standstill and at full speed; volume (dB) idling and at full speed.
const ENGINE_PITCH := Vector2(0.8, 1.35)
const ENGINE_DB := Vector2(-7.0, 0.0)
const MUSIC_FADE := 1.5

## false: missing SFX cues are silent.
var synth_missing := true
## The most SFX voices that were playing at once (the soak reads it).
var peak_voices := 0
## Which cues were playing at that peak (cue -> voices).
var peak_mix := {}

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cavern: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _engines := {}           # key -> {player, target_pitch, target_db}
var _warned := {}
var _cache := {}
var _synth := {}
var _bags := {}              # cue -> remaining shuffled variant indices
var _last_pick := {}         # cue -> index last played
var _last_start := {}        # cue -> seconds
var _cap_cache := {}
var _duck_db := 0.0
var _duck_until := 0.0
var _duck_amp: AudioEffectAmplify
var _clock := 0.0
## Set on the way out: nothing new starts (a scene leaving after us must not restart the music).
var _closed := false
var _bark_at := -100.0
var _bark_last := {}         # "char/cue" -> seconds
# Layered music
var _sync: AudioStreamSynchronized
var _sync_names: Array[String] = []        # stream index -> "up" | "down" | "layer_1" ...
var _sync_db: Array[float] = []            # current volume per stream
var _sync_target: Array[float] = []
var _cavern_target := SILENT_DB
var _music_fade := MUSIC_FADE
var _state := {"theme": &"", "zone": 0, "cavern": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_cavern = AudioStreamPlayer.new()
	_cavern.bus = "Music"
	_cavern.volume_db = SILENT_DB
	add_child(_cavern)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	set_volume("Music", Save.get_setting("music_volume", 0.8))
	set_volume("SFX", Save.get_setting("sound_volume", 1.0))
	set_volume("Voice", Save.get_setting("sound_volume", 1.0))
	# Let the mix thread drop its playbacks before the engine counts leaks at exit.
	Game.quit_requested.connect(func() -> void:
		if Game.quit_exits:   # tests call Game.quit() without exiting: keep playing then
			_release())


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var m := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(m) == 0:
		_duck_amp = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(m, _duck_amp)
	else:
		_duck_amp = AudioServer.get_bus_effect(m, 0) as AudioEffectAmplify
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)


func _process(delta: float) -> void:
	_clock += delta
	var now := _now()
	# Ducking: fast down, slow back up.
	var target := _duck_db if now < _duck_until else 0.0
	if _duck_amp != null:
		var cur := _duck_amp.volume_db
		var rate := 60.0 if target < cur else 8.0
		_duck_amp.volume_db = move_toward(cur, target, rate * delta)
	# Engines glide to their pitch and level.
	for key in _engines:
		var e: Dictionary = _engines[key]
		var p: AudioStreamPlayer = e.player
		p.pitch_scale = move_toward(p.pitch_scale, e.target_pitch, 1.5 * delta)
		p.volume_db = move_toward(p.volume_db, e.target_db, 30.0 * delta)
	# Music crossfades.
	if _sync != null:
		var step := (-SILENT_DB) / maxf(_music_fade, 0.01) * delta
		for i in _sync_db.size():
			if _sync_db[i] != _sync_target[i]:
				_sync_db[i] = move_toward(_sync_db[i], _sync_target[i], step)
				_sync.set_sync_stream_volume(i, _sync_db[i])
	if _cavern.stream != null and _cavern.volume_db != _cavern_target:
		var cstep := (-SILENT_DB) / maxf(_music_fade, 0.01) * delta
		_cavern.volume_db = move_toward(_cavern.volume_db, _cavern_target, cstep)


## Rate caps and ducks run on process time (pauses included), so a fixed-fps headless run is
## capped like real play. advance() moves it on in tests.
func _now() -> float:
	return _clock


func advance(secs: float) -> void:
	_clock += secs


## bus: "Music", "SFX" or "Voice"; linear 0..1 (the Settings sliders). 0 mutes.
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)
	if bus == "SFX" and AudioServer.get_bus_index("Voice") != -1:
		# Voices follow the Sound slider (there is no third slider).
		var v := AudioServer.get_bus_index("Voice")
		AudioServer.set_bus_volume_db(v, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(v, linear <= 0.0)


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


# --- SFX ------------------------------------------------------------------------------------------

## Plays a cue. volume_db: extra gain (the snore by depth). False when skipped by the rate cap or
## when there is nothing to play.
func play(cue: String, _position = null, volume_db: float = 0.0) -> bool:
	if _closed:
		return false
	var name := resolve_name(cue)
	if not _allowed(name):
		return false
	var stream := stream_for(cue)
	if stream == null:
		return false
	var p := _free_player()
	p.stream = stream
	p.pitch_scale = randf_range(0.96, 1.04)
	p.volume_db = volume_db
	p.set_meta(&"cue", name)
	p.play()
	_last_start[name] = _now()
	_maybe_duck(name, stream)
	var n := voice_count()
	if n > peak_voices:
		peak_voices = n
		peak_mix = {}
		for q in _pool:
			if q.playing:
				var c: String = q.get_meta(&"cue", "?")
				peak_mix[c] = int(peak_mix.get(c, 0)) + 1
	return true


## The cue a name plays (follows ALIASES).
func resolve_name(cue: String) -> String:
	return ALIASES.get(cue, cue)


## SFX voices playing right now (engines and music not counted).
func voice_count() -> int:
	var n := 0
	for p in _pool:
		if p.playing:
			n += 1
	return n


## Voices of one cue playing right now.
func playing_count(cue: String) -> int:
	var name := resolve_name(cue)
	var n := 0
	for p in _pool:
		if p.playing and p.get_meta(&"cue", "") == name:
			n += 1
	return n


## [min gap, max voices] for a cue.
func cap_of(cue: String) -> Array:
	var name := resolve_name(cue)
	if _cap_cache.has(name):
		return _cap_cache[name]
	var cap: Array = CAPS.get(name, [])
	if cap.is_empty():
		cap = _wild(CAPS, name, DEFAULT_CAP)
	_cap_cache[name] = cap
	return cap


## Forget rate-cap history (tests).
func reset_caps() -> void:
	_last_start.clear()
	_bark_at = -100.0
	_bark_last.clear()


func _wild(table: Dictionary, name: String, fallback):
	for k: String in table:
		if k.ends_with("*") and name.begins_with(k.trim_suffix("*")):
			return table[k]
		if k.begins_with("*") and name.ends_with(k.trim_prefix("*")):
			return table[k]
	return fallback


func _allowed(name: String) -> bool:
	var cap := cap_of(name)
	if _now() - float(_last_start.get(name, -100.0)) < float(cap[0]):
		return false
	return playing_count(name) < int(cap[1])


func _free_player() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			return p
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	return oldest    # steal the one closest to its end


func _maybe_duck(name: String, stream: AudioStream) -> void:
	var d = DUCKS.get(name, null)
	if d == null:
		d = _wild(DUCKS, name, null)
	if d == null:
		return
	duck(float(d[0]), maxf(float(d[1]), stream.get_length() * 0.8))


## Pull the music down by db for secs (the deepest duck wins while they overlap).
func duck(db: float, secs: float) -> void:
	var now := _now()
	if now >= _duck_until or db < _duck_db:
		_duck_db = db
	_duck_until = maxf(_duck_until, now + secs)


## The music duck right now (dB, 0 = none).
func duck_db() -> float:
	return _duck_amp.volume_db if _duck_amp != null else 0.0


## A real file exists for this SFX cue.
func has_cue(cue: String) -> bool:
	return not _variants(SFX_DIR, resolve_name(cue)).is_empty()


## How many file variants a cue has.
func variant_count(cue: String) -> int:
	return _variants(SFX_DIR, resolve_name(cue)).size()


## What play(cue) would play: the next file variant, the synth beep (synth_missing), or null.
func stream_for(cue: String) -> AudioStream:
	var name := resolve_name(cue)
	var stream := _pick(SFX_DIR, name, UiSound.CUES.has(name))
	if stream == null and UiSound.CUES.has(name):
		stream = UiSound.stream(name)    # menu cues: the Showtime kit's designed synth
	if stream == null and synth_missing:
		stream = synth_stream(name)
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


# --- engines --------------------------------------------------------------------------------------

## Start (or switch) the looped engine for key (a player id). cue: "<vehicle>_engine".
func engine(key, cue: String) -> void:
	if _closed:
		return
	var name := resolve_name(cue)
	if _engines.has(key) and _engines[key].cue == name:
		return
	var stream := _pick(SFX_DIR, name)
	if stream == null:
		engine_stop(key)
		return
	_loop(stream)
	var p: AudioStreamPlayer
	if _engines.has(key):
		p = _engines[key].player
	else:
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
	p.stream = stream
	p.pitch_scale = ENGINE_PITCH.x
	p.volume_db = ENGINE_DB.x
	p.play()
	_engines[key] = {"player": p, "cue": name, "target_pitch": ENGINE_PITCH.x, "target_db": ENGINE_DB.x}


## speed: 0 (standing) .. 1 (top speed). Pitch and level glide there.
func engine_speed(key, speed: float) -> void:
	if not _engines.has(key):
		return
	var s := clampf(speed, 0.0, 1.0)
	_engines[key].target_pitch = lerpf(ENGINE_PITCH.x, ENGINE_PITCH.y, s)
	_engines[key].target_db = lerpf(ENGINE_DB.x, ENGINE_DB.y, sqrt(s))


func engine_stop(key) -> void:
	if not _engines.has(key):
		return
	var p: AudioStreamPlayer = _engines[key].player
	_engines.erase(key)
	p.stop()
	p.queue_free()


## A loop started with engine() that is not an engine (the drain gurgle): set its own level (dB)
## and pitch; they glide there like an engine's.
func engine_level(key, db: float, pitch: float = 1.0) -> void:
	if not _engines.has(key):
		return
	_engines[key].target_db = db
	_engines[key].target_pitch = pitch


## The engine's target level (dB), or SILENT_DB when there is none.
func engine_db(key) -> float:
	return _engines[key].target_db if _engines.has(key) else SILENT_DB


## The engine's target pitch (what it glides to), or 0 when there is none.
func engine_pitch(key) -> float:
	return _engines[key].target_pitch if _engines.has(key) else 0.0


func engine_count() -> int:
	return _engines.size()


func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * w.mix_rate))


# --- music ----------------------------------------------------------------------------------------

## Single-file music (menus): fades the layered theme out.
func music(track: String, fade: float = 0.5) -> void:
	if _closed:
		return
	var stream := _pick(MUSIC_DIR, track)
	if stream == null:
		return
	_loop(stream)
	_sync = null
	_state.theme = &""
	_cavern_target = SILENT_DB
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	_state.theme = &""
	_cavern_target = SILENT_DB
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)
	tw.parallel().tween_property(_cavern, "volume_db", SILENT_DB, fade)


## The layered theme. theme: &"up" or &"down" (which melody); zone: 0 (Topsoil) .. N, layers
## 1..zone of music_down_layer_* come in; cavern: the Dragon's choir on top. Crossfades over fade s.
func music_state(theme: StringName, zone: int, cavern: bool, fade: float = MUSIC_FADE) -> void:
	if _closed:
		return
	_music_fade = fade
	if _sync == null and not _build_sync():
		return
	_state = {"theme": theme, "zone": zone, "cavern": cavern}
	for i in _sync_names.size():
		var n := _sync_names[i]
		var on := false
		if n == "up":
			on = theme == &"up"
		elif n == "down":
			on = theme == &"down"
		else:
			on = zone >= int(n.trim_prefix("layer_"))
		_sync_target[i] = 0.0 if on else SILENT_DB
	if cavern and _cavern.stream == null:
		var c := _pick(MUSIC_DIR, "music_cavern")
		if c != null:
			_loop(c)
			_cavern.stream = c
			_cavern.volume_db = SILENT_DB
			_cavern.play()
	_cavern_target = 0.0 if cavern else SILENT_DB


func music_theme() -> StringName:
	return _state.theme


## {theme, zone, cavern} as last set by music_state.
func music_state_now() -> Dictionary:
	return _state.duplicate()


## Target volume (dB) of a music part: "up", "down", "layer_<n>", "cavern". SILENT_DB when off.
func music_target(part: String) -> float:
	if part == "cavern":
		return _cavern_target
	var i := _sync_names.find(part)
	return _sync_target[i] if i != -1 else SILENT_DB


## Volume (dB) of a music part right now (mid-crossfade it is between SILENT_DB and 0).
func music_volume(part: String) -> float:
	if part == "cavern":
		return _cavern.volume_db if _cavern.stream != null else SILENT_DB
	var i := _sync_names.find(part)
	return _sync_db[i] if i != -1 else SILENT_DB


func music_layers() -> int:
	return maxi(0, _sync_names.size() - 2)


func _build_sync() -> bool:
	var up := _pick(MUSIC_DIR, "music_up")
	var down := _pick(MUSIC_DIR, "music_down")
	if up == null or down == null:
		return false
	var parts: Array[AudioStream] = [up, down]
	_sync_names = ["up", "down"]
	var i := 1
	while _find(MUSIC_DIR, "music_down_layer_%d" % i) != "":
		parts.append(load(_find(MUSIC_DIR, "music_down_layer_%d" % i)))
		_sync_names.append("layer_%d" % i)
		i += 1
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = parts.size()
	_sync_db.clear()
	_sync_target.clear()
	for k in parts.size():
		_loop(parts[k])
		_sync.set_sync_stream(k, parts[k])
		_sync.set_sync_stream_volume(k, SILENT_DB)
		_sync_db.append(SILENT_DB)
		_sync_target.append(SILENT_DB)
	_music.stop()
	_music.stream = _sync
	_music.volume_db = 0.0
	_music.play()
	return true


# --- barks ----------------------------------------------------------------------------------------

## One bark from character (a roster id or a resident id). False when skipped (another bark is
## still talking, too soon, or nothing to play).
func bark(character: String, cue: String) -> bool:
	if _closed:
		return false
	var key := "%s/%s" % [character, cue]
	var now := _now()
	if _voice.playing or now - _bark_at < BARK_GAP or now - float(_bark_last.get(key, -100.0)) < BARK_REPEAT:
		return false
	var stream := bark_stream(character, cue)
	if stream == null:
		return false
	_voice.stream = stream
	_voice.play()
	_bark_at = now
	_bark_last[key] = now
	duck(BARK_DUCK_DB, stream.get_length())
	return true


## P-06: a game cue the shared character library has no line for -> the library lines that fit it
## (openjar-characters voice packs record cheer, join, lose, oops, ready, swap_in, wait, win).
const LIBRARY_CUES := {
	"rock_name": ["cheer"], "narrate": ["ready", "wait"], "found": ["win", "cheer"],
	"built": ["cheer"], "upgrade": ["cheer", "win"], "bonk": ["oops"], "hello": ["join"],
}


## A-15: a Hill bark -> the line ids its speaker's openjar-characters pack plans for it (the bark
## tables in characters/<id>/voice/README.md; v0.5.0 has the tables but no audio yet for any of
## these). Every id found in the pack folder joins one shuffled bag, so the lines take turns.
const PACK_LINES := {
	"mole/oh_dear": ["mole_oh_dear", "mole_oh_deary_me", "mole_oh_dear_dear"],
	"gnome_foreman/whistle": ["foreman_whistle_noted", "foreman_whistle_shift"],
	"gnome_foreman/mutter": ["foreman_hm", "foreman_hm_hm", "foreman_mm", "foreman_pencil_hm"],
	"dragon/rumble": ["dragon_rumble_low", "dragon_rumble_happy"],
	"dragon/yawn": ["dragon_yawn_small", "dragon_yawn_big"],
}

## Where pack folders live (<root><id>/voice/); tests point it at a fixture.
var pack_root := CHARACTERS_DIR


## Where a bark comes from: the voice pack's own line, the pack's planned lines for it (PACK_LINES),
## the pack's library line for that cue (LIBRARY_CUES), then the synth placeholder.
func bark_stream(character: String, cue: String) -> AudioStream:
	var dirs: Array[String] = []
	var roster := get_node_or_null("/root/Roster")
	if roster != null and roster.has(character):
		var v: String = roster.info(character).get("voice", "")
		if v != "":
			dirs.append(v if v.ends_with("/") else v + "/")
	dirs.append("%s%s/voice/" % [pack_root, character])
	for d in dirs:
		var s := _pick(d, cue, true)
		if s != null:
			return s
		s = _pick_lines(d, PACK_LINES.get("%s/%s" % [character, cue], []))
		if s != null:
			return s
		for alt in LIBRARY_CUES.get(cue, []):
			s = _pick(d, alt, true)
			if s != null:
				return s
	return _pick(VOICE_DIR, "%s_%s" % [character, cue], true)


## True when the bark comes from a real voice pack, not the placeholder.
func bark_is_real(character: String, cue: String) -> bool:
	var s := bark_stream(character, cue)
	return s != null and not s.resource_path.begins_with(VOICE_DIR)


func is_barking() -> bool:
	return _voice.playing


# --- files ----------------------------------------------------------------------------------------

## Next variant, rotating through a shuffled bag; never the same one twice in a row.
func _pick(dir: String, cue: String, quiet := false) -> AudioStream:
	var variants := _variants(dir, cue)
	var key := dir + cue
	if variants.is_empty():
		if not quiet and not _warned.has(key):
			_warned[key] = true
			push_warning("Audio: no file for cue '%s' in %s" % [cue, dir])
		return null
	return _from_bag(key, variants)


## One line out of several named lines in one folder (each may have _n variants), taking turns.
func _pick_lines(dir: String, ids: Array) -> AudioStream:
	if ids.is_empty():
		return null
	var key := dir + "|".join(ids)
	if not _cache.has(key):
		var all: Array = []
		for id in ids:
			all.append_array(_variants(dir, id))
		_cache[key] = all
	var variants: Array = _cache[key]
	return null if variants.is_empty() else _from_bag(key, variants)


func _from_bag(key: String, variants: Array) -> AudioStream:
	if variants.size() == 1:
		return variants[0]
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = range(variants.size())
		bag.shuffle()
		if bag[0] == _last_pick.get(key, -1):
			bag.append(bag.pop_front())
	var i: int = bag.pop_front()
	_bags[key] = bag
	_last_pick[key] = i
	return variants[i]


func _find(dir: String, name: String) -> String:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(dir + name + ext):
			return dir + name + ext
	return ""


func _variants(dir: String, cue: String) -> Array:
	var key := dir + cue
	if _cache.has(key):
		return _cache[key]
	var variants: Array = []
	var one := _find(dir, cue)
	if one != "":
		variants.append(load(one))
	else:
		var i := 1
		while _find(dir, "%s_%d" % [cue, i]) != "":
			variants.append(load(_find(dir, "%s_%d" % [cue, i])))
			i += 1
	_cache[key] = variants
	return variants


# --- shutdown -------------------------------------------------------------------------------------

## A player still playing at quit leaks its stream playback (the audio thread lets go later than
## the engine checks). Stops everything and waits a moment of real time for the mix thread.
func stop_all() -> void:
	_release()
	await get_tree().create_timer(0.2, true, false, true).timeout


func _release() -> void:
	_closed = true
	for key in _engines.keys():
		engine_stop(key)
	for p in _pool + [_music, _cavern, _voice]:
		p.stop()
		p.stream = null
	_sync = null
	_sync_names.clear()
	_sync_db.clear()
	_sync_target.clear()
	_state = {"theme": &"", "zone": 0, "cavern": false}
	_cache.clear()
	_bags.clear()


func _exit_tree() -> void:
	_release()
	# Give the mix thread a few buffers (real time) to drop the stopped playbacks before the engine
	# counts leaks; headless fixed-fps runs reach exit in well under one buffer otherwise.
	OS.delay_msec(60)
