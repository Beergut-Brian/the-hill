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
	super()
	process_priority = 1000   # measure after everything else this frame
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
	if _clock >= _next_report:
		print("BENCH t=%02d %s split=%s" % [roundi(_next_report), format_stats(stats(_window)), str(game.director.is_split())])
		_window = PackedFloat32Array()
		_next_report += REPORT_EVERY
	if _clock >= secs:
		finish()


func finish() -> void:
	if done:
		return
	done = true
	var s := stats(_frames)
	summary_line = "BENCH %s frames=%d secs=%.1f tier=%s adapter=\"%s\"" % [
			format_stats(s), s.frames, _clock, Graphics.tier, Graphics.adapter]
	print(summary_line)
	if quits:
		Game.quit(0)
