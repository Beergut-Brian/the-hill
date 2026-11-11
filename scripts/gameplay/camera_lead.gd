## S-06: the camera leads a little ahead of the player in the direction they dig or drive (so you
## see what's coming) and eases back when they stop; bigger vehicles (data/camera.tres:
## vehicle_zoom, the Dump Truck and Crane) zoom out a little. HillGame adds one.
## It runs after the ScreenDirector each frame (process_priority) and only adjusts what the
## director already decided: each camera's position (the lead, so the scene's camera limits
## still hold) and zoom. The split rules are untouched. A camera that follows one player gets that
## player's lead and zoom; the shared camera (both players on one screen) gets no lead and the
## wider of the two zooms, blending into each player's own as the split slides in.
## ScreenKick's shakes use the camera offset and stack on top.
class_name CameraLead
extends Node

var game: Node
var tuning: CameraTuning = CameraTuning.load_default()
var _lead := {}    # player -> Vector2 (world px, smoothed)
var _zoom := {}    # player -> float (smoothed)
## C-22: a camera beat toward something the player can't see (a wall a boulder broke off screen):
## player -> {offset: Vector2 (world px from them), t: float (seconds in), dur: float}.
var _peek := {}
const GROUP := &"camera_lead"


func _ready() -> void:
	name = "CameraLead"
	process_priority = 10
	add_to_group(GROUP)


## Slides player p's view toward `offset` (world px from them) and back over `secs`: a quick
## ease over (a fifth of the time), a hold, an ease home. A newer peek replaces an older one.
func peek(p: int, offset: Vector2, secs := 1.6) -> void:
	_peek[p] = {"offset": offset, "t": 0.0, "dur": maxf(secs, 0.2)}


## Player p's peek offset right now (world px), ZERO when none.
func peek_of(p: int) -> Vector2:
	var e: Dictionary = _peek.get(p, {})
	if e.is_empty():
		return Vector2.ZERO
	var k := float(e.t) / float(e.dur)
	var w := smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.75, 1.0, k))
	return (e.offset as Vector2) * w


## Player p's current lead (world px from their position).
func lead_of(p: int) -> Vector2:
	return _lead.get(p, Vector2.ZERO)


## Player p's current zoom (screen px per world px).
func zoom_of(p: int) -> float:
	return _zoom.get(p, tuning.zoom)


## Where p is heading: the stick, or (no stick, in a vehicle) the way the vehicle is moving.
func heading(node: HillPlayer) -> Vector2:
	if node.locked:
		return Vector2.ZERO
	var mv: Vector2 = node.move_intent
	var dir := Vector2.ZERO
	if absf(mv.x) > tuning.dead_zone:
		dir.x = signf(mv.x)
	if absf(mv.y) > tuning.dead_zone:
		dir.y = signf(mv.y)
	if dir == Vector2.ZERO and node.vehicle != null and node.velocity.length() > tuning.lead_speed:
		var v := node.velocity
		dir = Vector2(signf(v.x) if absf(v.x) > tuning.lead_speed else 0.0,
				signf(v.y) if absf(v.y) > tuning.lead_speed else 0.0)
	return dir


## Target lead and zoom for p this frame.
func target_of(p: int) -> Dictionary:
	var node: HillPlayer = game.players.get(p)
	if node == null:
		return {"lead": Vector2.ZERO, "zoom": tuning.zoom}
	var under: bool = game.director.scene_of(p) == HillGame.UNDERGROUND
	var lead := Vector2.ZERO
	if under or tuning.lead_up_top:
		lead = heading(node) * (tuning.lead_px if node.vehicle != null else tuning.foot_lead_px)
	var z := tuning.zoom
	if node.vehicle != null and (under or tuning.vehicle_zoom_up_top):
		z *= tuning.zoom_factor(node.vehicle.id)
	return {"lead": lead, "zoom": z}


## One step of the easing (tests call it with a fixed delta).
func step(delta: float) -> void:
	for p in _lead.keys():
		if not game.players.has(p):
			_lead.erase(p)
			_zoom.erase(p)
	for p: int in game.players:
		var t := target_of(p)
		var cur: Vector2 = _lead.get(p, Vector2.ZERO)
		var want: Vector2 = t.lead
		# Grow toward a heading per axis; an axis with no heading eases back.
		var nx := _ease(cur.x, want.x, tuning.lead_in if want.x != 0.0 else tuning.ease_back, delta)
		var ny := _ease(cur.y, want.y, tuning.lead_in if want.y != 0.0 else tuning.ease_back, delta)
		_lead[p] = Vector2(nx, ny)
		if _peek.has(p):
			_peek[p].t += delta
			if float(_peek[p].t) >= float(_peek[p].dur):
				_peek.erase(p)
		_zoom[p] = _ease(_zoom.get(p, tuning.zoom), t.zoom, tuning.zoom_ease, delta)


static func _ease(cur: float, want: float, rate: float, delta: float) -> float:
	var v := lerpf(cur, want, 1.0 - exp(-rate * delta))
	return want if absf(v - want) < 0.01 else v


func _process(delta: float) -> void:
	if game == null or game.director == null:
		return
	step(delta)
	apply()


## Writes the leads and zooms onto the director's cameras (after the director placed them).
func apply() -> void:
	var dir: ScreenDirector = game.director
	var ps: Array = game.players.keys()
	var cams: Array[Camera2D] = [dir.camera_of(0), dir.camera_of(1)]
	if ps.is_empty():
		for cam in cams:
			cam.zoom = Vector2(tuning.zoom, tuning.zoom)
		return
	var shared: bool = ps.size() == 2 and dir.scene_of(0) == dir.scene_of(1)
	var s := dir.split_amount
	for i in 2:
		var p: int = i if ps.size() == 2 else int(ps[0])
		var lead: Vector2 = lead_of(p) + peek_of(p)
		var z: float = zoom_of(p)
		if shared:
			lead *= s
			z = lerpf(minf(zoom_of(0), zoom_of(1)), z, s)
		var cam := cams[i]
		cam.zoom = Vector2(z, z)
		cam.position = (cam.position + lead).round()
