## --bench [--bench-secs=N] (S-20): a fixed two-player split-screen route through the busiest parts
## of The Hill, for frame rates on the real TV box. HillGame adds it instead of the demo runner.
## Four legs of a quarter of the run each; the players are always apart (split screen):
##   1  P1 walks the Crystal landing (crystal glow, darkness shader; crystal is too tough to dig), P2
##      walks Hillville along every vehicle parked in a row.
##   2  P1 digs Topsoil by the shaft (boulders, falling dirt, particles), P2 walks by the crew and pile.
##   3  both underground: P1 walks the Bottom cavern (the Dragon), P2 digs Clay (the water pocket).
##   4  P1 walks Hillville by the vehicles, P2 walks the Crystal landing.
## Every 5 s it prints "BENCH t=… avg=… low1=… ms=… worst=…" (that window), at the end
## "BENCH avg=… low1=… ms=… worst=… frames=… secs=… tier=… adapter=…" (the whole run, the first second
## after the start skipped as warm-up), then quits with code 0.
## Every 5 s line and the final "WORK draws=… dark_chunks=… dark_lights=… per_chunk=… taps=…" line
## say how much the frame asked of the GPU (hill-igpu-2): draw calls, darkness chunk sprites, the
## lights their shader loops over and how often a pixel runs that loop. A/B on the box:
## `--bench-nocull` (every chunk loops over every light) and `--bench-four-tap` (low's darkness as
## before hill-igpu-2).
## Frame times are wall clock (Time.get_ticks_usec), not delta, so a capped or stalled frame counts;
## the route itself runs on game time, so every run walks the same legs.
extends HillBeatRunner

const REPORT_EVERY := 5.0
const WARMUP := 1.0
const LEGS := 4
## Walkers turn round this often so they never wedge against a wall.
const TURN := 2.0

var secs := 60.0
## Quit when done (tests turn it off and read `summary_line`).
var quits := true
var summary_line := ""
var done := false
var _leg := -1
var _frames := PackedFloat32Array()     # ms, whole run after warm-up
var _window := PackedFloat32Array()     # ms, since the last report
var _last_us := 0
var _clock := 0.0                       # game s since START
var _next_report := REPORT_EVERY
## Frames over HITCH_LOG_MS print a "HITCH …" line with what changed that frame; frames over
## HITCH_MS count toward the final "HITCH count>33ms=…" line (S-21).
const HITCH_MS := 33.0
## `--bench-log-ms=N` moves the log threshold (a software renderer needs ~25 ms for any frame).
var hitch_log_ms := 25.0
var hitch_line := ""
var hitches := 0
## The slowest frame: where it was and what it did (on the final HITCH line, hill-igpu-2).
var _worst_ms := 0.0
var _worst_at := ""
var _what := PackedStringArray()        # events since the last measured frame
var _chunks_in := 0
var _chunks_out := 0
var _last_nodes := 0
var _last_objects := 0
var _last_res := 0
## Work per frame (hill-igpu-2): draw calls, darkness chunk sprites and the lights their shader
## loops over (summed), so a change can be shown to do the same frame fewer ways on any machine.
var work_line := ""
var _work := {"frames": 0, "draws": 0.0, "sprites": 0.0, "lights": 0.0, "max_lights": 0}
var _wwin := {"frames": 0, "draws": 0.0, "sprites": 0.0, "lights": 0.0, "max_lights": 0}


## {"avg": fps, "low1": fps of the slowest 1 % of frames, "ms": mean ms, "worst": max ms, "frames": n}.
static func stats(frame_ms: PackedFloat32Array) -> Dictionary:
	var n := frame_ms.size()
	if n == 0:
		return {"avg": 0.0, "low1": 0.0, "ms": 0.0, "worst": 0.0, "frames": 0}
	var total := 0.0
	for v in frame_ms:
		total += v
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var k := maxi(1, ceili(n * 0.01))
	var slow := 0.0
	for i in k:
		slow += sorted[n - 1 - i]
	slow /= k
	return {"avg": 1000.0 * n / maxf(total, 0.001), "low1": 1000.0 / maxf(slow, 0.001),
			"ms": total / n, "worst": sorted[n - 1], "frames": n}


static func format_stats(s: Dictionary) -> String:
	return "avg=%.1f low1=%.1f ms=%.2f worst=%.2f" % [s.avg, s.low1, s.ms, s.worst]


func _ready() -> void:
	beat = "bench"
	secs = Graphics.bench_secs
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-log-ms="):
			hitch_log_ms = maxf(1.0, float(a.trim_prefix("--bench-log-ms=")))
	super()
	process_priority = 1000   # measure after everything else this frame
	if game != null and game.underground != null:
		if OS.get_cmdline_user_args().has("--bench-nocull"):
			game.underground.world._darkness.cull_lights = false   # A/B: every chunk loops over every light
		if OS.get_cmdline_user_args().has("--bench-four-tap"):
			game.underground.world._darkness.one_tap = false   # A/B: low's darkness as before hill-igpu-2
		game.underground.world.chunk_loaded.connect(func(_k): _chunks_in += 1)
		if game.underground.world.has_signal(&"chunk_freed"):
			game.underground.world.chunk_freed.connect(func(_k): _chunks_out += 1)
	print("BENCH start secs=%.0f tier=%s adapter=\"%s\" (%s)" % [secs, Graphics.tier, Graphics.adapter, Graphics.reason])


func _physics_process(delta: float) -> void:
	super(delta)
	if done or game == null or game.player_node(P1) == null or t < START:
		return
	var leg := mini(LEGS - 1, int(floor((t - START) / (secs / LEGS))))
	if leg != _leg:
		_leg = leg
		_stage_leg(leg)
	var turn := 1.0 if int(floor((t - START) / TURN)) % 2 == 0 else -1.0
	match leg:
		0:
			_hold(P1, Vector2(turn, 0))
			_hold(P2, Vector2(turn, 0))
		1:
			_hold(P1, Vector2(1, 0.6), true)
			_hold(P2, Vector2(-turn, 0))
		2:
			_hold(P1, Vector2(turn, 0))
			_hold(P2, Vector2(-1, 0), true)
		3:
			_hold(P1, Vector2(turn, 0))
			_hold(P2, Vector2(-turn, 0))


func _stage_leg(leg: int) -> void:
	var u := _ug()
	match leg:
		0:
			_park_row()
			_place(P1, u.landing(_layer(&"crystal")) + Vector2(-30, 0))
			_town(P2, Hillville.SHAFT_X - 400.0)
		1:
			var cage := u.cage_rect(0)
			_place(P1, Vector2(cage.end.x + 24.0, cage.end.y - 5.0))
			_town(P2, TownResidents.CREW_X)
		2:
			_place(P1, u.landing(_layer(&"bottom")) + Vector2(-40, 0))
			_place(P2, u.landing(_layer(&"clay")) + Vector2(-30, 0))
		3:
			_town(P1, Hillville.SHAFT_X - 500.0)
			_place(P2, u.landing(_layer(&"crystal")) + Vector2(30, 0))
	log_event("bench leg %d (split %s)" % [leg + 1, str(game.director.is_split())])
	_what.append("leg %d" % (leg + 1))


func _town(p: int, x: float) -> void:
	if game.player_node(p) != null:
		game.place_player(p, HillGame.HILLVILLE, Vector2(x, 0))


## Every vehicle parked in a row left of the shaft, so Hillville draws all of them.
func _park_row() -> void:
	var x := Hillville.SHAFT_X - 560.0
	var i := 0
	for id in [&"dump_truck", &"crane", &"excavator", &"drill_rig"]:
		if not Progress.has_vehicle(id):
			Progress.vehicles.append(id)
		if not game.vehicles.has(id):
			game.park_new(id, Vector2(x + 110.0 * i, 0))
		i += 1


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if done or t < START:
		_last_us = now
		return
	if _last_us == 0:
		_last_us = now
		return
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	# The route runs on game time (t), so legs land the same on any machine; frames are wall time.
	_clock = t - START
	if _clock < WARMUP:
		return
	_frames.append(ms)
	_window.append(ms)
	_note_frame(ms)
	_note_work()
	if _clock >= _next_report:
		print("BENCH t=%02d %s split=%s %s" % [roundi(_next_report), format_stats(stats(_window)),
				str(game.director.is_split()), format_work(_wwin)])
		_window = PackedFloat32Array()
		_wwin = {"frames": 0, "draws": 0.0, "sprites": 0.0, "lights": 0.0, "max_lights": 0}
		_next_report += REPORT_EVERY
	if _clock >= secs:
		finish()


func _note_work() -> void:
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var sprites := 0
	var lights := 0
	if game != null and game.underground != null:
		var d = game.underground.world._darkness
		sprites = d.stat_sprites
		lights = d.stat_light_sum
	for w in [_work, _wwin]:
		w.frames += 1
		w.draws += draws
		w.sprites += sprites
		w.lights += lights
		w.max_lights = maxi(w.max_lights, lights)


## "draws=… dark_chunks=… dark_lights=… per_chunk=… taps=…": per-frame means. dark_lights sums
## over the darkness chunk sprites the lights each one's shader loops over; taps is how many times
## a pixel runs that loop (4 = one per nearest cell, 1 = one_tap).
func format_work(w: Dictionary) -> String:
	var n := maxf(1.0, float(w.frames))
	var per := float(w.lights) / maxf(1.0, float(w.sprites))
	var taps := 4
	if game != null and game.underground != null and game.underground.world._darkness.one_tap:
		taps = 1
	return "draws=%.0f dark_chunks=%.1f dark_lights=%.1f per_chunk=%.2f taps=%d" % [
			w.draws / n, w.sprites / n, w.lights / n, per, taps]


## One line per slow frame: what the frame did (leg switches, chunks built/freed, node, object and
## resource count changes, draw calls) so a stall can be traced to its cause.
func _note_frame(ms: float) -> void:
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	if ms > HITCH_MS:
		hitches += 1
	if ms > _worst_ms:
		_worst_ms = ms
		_worst_at = "t=%.2f leg=%d chunks=+%d/-%d nodes=%+d draws=%d%s" % [_clock, _leg + 1, _chunks_in, _chunks_out,
				nodes - _last_nodes, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				(" " + ",".join(_what)) if not _what.is_empty() else ""]
	if ms > hitch_log_ms:
		print("HITCH t=%.2f ms=%.1f leg=%d chunks=+%d/-%d nodes=%+d objs=%+d res=%+d draws=%d phys=%.1f proc=%.1f %s" % [
				_clock, ms, _leg + 1, _chunks_in, _chunks_out, nodes - _last_nodes, objs - _last_objects,
				res - _last_res,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, ",".join(_what)])
	_last_nodes = nodes
	_last_objects = objs
	_last_res = res
	_chunks_in = 0
	_chunks_out = 0
	_what = PackedStringArray()


func finish() -> void:
	if done:
		return
	done = true
	var s := stats(_frames)
	summary_line = "BENCH %s frames=%d secs=%.1f tier=%s adapter=\"%s\"" % [
			format_stats(s), s.frames, _clock, Graphics.tier, Graphics.adapter]
	print(summary_line)
	hitch_line = "HITCH count>33ms=%d worst=%.2f frames=%d worst_at %s" % [hitches, s.worst, s.frames, _worst_at]
	print(hitch_line)
	work_line = "WORK %s max_dark_lights=%d" % [format_work(_work), _work.max_lights]
	print(work_line)
	if quits:
		Game.quit(0)

