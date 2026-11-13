## Launch-readiness soak: boots the real boot scene with --demo and loops it for --soak-secs (real
## seconds, default 1800). Each cycle: the scripted demo plays (both players, digging, riding the
## elevator, building, driving) until it idles or 240 s pass; then pause, resume, pause, Back to menu
## (the pause menu's own press), 3 s in the menu, every third cycle New Hill (Save.start_new), and
## Play again (Game.finish_lobby, which builds a fresh HillGame and a fresh demo run). Logs object and
## node counts per cycle so a leak shows. Ends with Game.quit() (exit 0).
## Not shipped (tests/ is excluded from exports). Run:
##   godot --headless --path . res://tests/fixtures/soak.tscn -- --demo --soak-secs=1800
extends Node

const MAIN := "res://scenes/main.tscn"
const CYCLE_CAP := 240.0

var soak_secs := 1800.0
var _t := 0.0
var cycles := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--soak-secs="):
			soak_secs = float(a.trim_prefix("--soak-secs="))
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred((load(MAIN) as PackedScene).instantiate())
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta


func say(what: String) -> void:
	print("soak: %8.1f c%02d %s | objects %d nodes %d orphans %d mem %.1f MB" % [_t, cycles, what,
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])


func wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _demo_idle() -> bool:
	var main := get_tree().root.get_node_or_null("Main")
	var game: Node = main.get("game") if main != null else null
	if game == null:
		return false
	var runner := game.get_node_or_null("DemoRunner")
	return runner != null and runner.get("step") == &"idle"


func _run() -> void:
	await wait(1.0)
	while _t < soak_secs:
		cycles += 1
		say("cycle start")
		var left := minf(CYCLE_CAP, soak_secs - _t)
		while left > 0.0 and not _demo_idle():
			await wait(1.0)
			left -= 1.0
		say("demo idle" if _demo_idle() else "cycle cap")
		await wait(minf(10.0, maxf(soak_secs - _t, 0.0)))
		if _t >= soak_secs:
			break
		Game.pause()
		await wait(1.0)
		Game.resume()
		await wait(1.0)
		Game.pause()
		await wait(0.5)
		var pm := get_tree().get_first_node_in_group("openjar_pause_menu")
		pm.call("press", 1)   # Choice.RESTART: Back to menu
		await wait(3.0)
		say("in the menu (state %s)" % Game.State.keys()[Game.state])
		if cycles % 3 == 0:
			say("new hill: backup " + Save.start_new())
		Game.finish_lobby([Players.P1, Players.P2])
		await wait(1.0)
	say("done after %d cycles" % cycles)
	Game.quit()
	await wait(5.0)
	say("STILL RUNNING after quit")
	get_tree().quit(3)
