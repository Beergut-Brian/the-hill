## Short, small camera kicks for juice (V-07, W-17): a big scoop up top, a boulder landing near you,
## the Dragon's snore at the Bottom. HillGame adds one; anything calls ScreenKick.kick(player, px,
## secs). Each kick is a few pixels for a fraction of a second and fades out; the strongest one
## running wins. Settings "screen shake" off = nothing moves. `sway` is a slow up-down roll (the
## snore) instead of a jitter.
class_name ScreenKick
extends Node

const GROUP := &"screen_kick"
## Hard limits so nothing ever gets big or long.
const MAX_PX := 4.0
const MAX_SECS := 0.9

var game: Node
var _kicks := {}           # player -> {px, t, dur, sway}
var _peak := {}            # player -> largest offset length applied since the last peak() read
var _t := 0.0


func _ready() -> void:
	name = "ScreenKick"
	add_to_group(GROUP)


## Kicks player p's view (no-op without a ScreenKick in the tree).
static func kick(p: int, px: float, secs: float, sway := false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var k := tree.get_first_node_in_group(GROUP) as ScreenKick
	if k != null:
		k.add(p, px, secs, sway)


func add(p: int, px: float, secs: float, sway := false) -> void:
	if not SettingsPanel.screen_shake() or px <= 0.0 or secs <= 0.0:
		return
	px = minf(px, MAX_PX)
	secs = minf(secs, MAX_SECS)
	var cur: Dictionary = _kicks.get(p, {})
	if not cur.is_empty() and float(cur.px) * float(cur.t) / float(cur.dur) >= px:
		return
	_kicks[p] = {"px": px, "t": secs, "dur": secs, "sway": sway}


func active(p: int) -> bool:
	return _kicks.has(p)


## The biggest offset applied to p's camera since the last call (tests).
func peak(p: int) -> float:
	var v: float = _peak.get(p, 0.0)
	_peak[p] = 0.0
	return v


func _process(delta: float) -> void:
	_t += delta
	for p in _kicks.keys():
		var k: Dictionary = _kicks[p]
		k.t -= delta
		var cam := _cam(p)
		if k.t <= 0.0:
			_kicks.erase(p)
			if cam != null:
				cam.offset = Vector2.ZERO
			continue
		var f: float = float(k.t) / float(k.dur)
		var off: Vector2
		if k.sway:
			off = Vector2(sin(_t * 9.0) * 0.4, sin(_t * 6.0)) * float(k.px) * sin(f * PI)
		else:
			off = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * float(k.px) * f
		off = off.round()
		if cam != null:
			cam.offset = off
		_peak[p] = maxf(float(_peak.get(p, 0.0)), off.length())


func _cam(p: int) -> Camera2D:
	var dir = game.get("director") if game != null else null
	if dir == null or not dir.has_method("camera_of"):
		return null
	return dir.camera_of(p)
