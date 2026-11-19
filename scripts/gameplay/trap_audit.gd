## PT-1119-1 trap-finder (Kaden 2026-11-19: "if you dig a certain way it's basically impossible to
## get out"). For a layer and a dig shape a player really makes, it stages the shape around the
## layer's landing (tiles only, from the generated rock; every changed cell is put back after),
## puts the player at the bottom of it, then drives that player with the real controls (stick,
## A, B, Y through `intent_source`; no teleports) until they are back up top, and says how long it
## took or why they stalled. Two ways out are tried for every shape:
##   climb  a kid's way: walk / dig / carve steps toward the shaft (stick diagonal-up + A), B when
##          a ledge is in reach, and A as soon as the elevator's A blinks over the head.
##   rope   hold Y (the rope rescue, PT-1119-1 c), then A in the landing's cage.
## Every run prints one `trap:` line. Used by tests/test_get_out.gd (a subset, real time) and by
## the `--trap-audit` scripted run (HillGame adds TrapAudit.Runner; every layer x every shape):
##   godot --headless --path . --fixed-fps 60 -- --trap-audit [--trap-layers=0,2] [--trap-shapes=pit3,tunnel]
##         [--trap-modes=climb,rope] [--trap-shots --shot-dir=/abs/dir] [--trap-tag=after]
##         [--trap-hint-wait=11]   (rope runs stand still first, so the hint panel offers the rope)
## (`--trap-shots` needs a renderer: run it through godot-render like scripts/tools/shots.sh.)
class_name TrapAudit
extends Node

const P1 := 0
const P2 := 1
const IDLE := {"move": Vector2.ZERO, "dig": false, "jump": false, "book": false, "horn": false}
const SHAPES := ["pit3", "pit6", "pit10", "pit10_shaft", "overhang", "tunnel", "gate", "flood",
		"sand", "hole1", "mole", "lid", "wet_landing"]
const MODES := ["climb", "rope"]
## Give up after this long (game seconds) and report the stall.
const CLIMB_CAP := 40.0
const ROPE_CAP := 20.0
## No new height (STALL_PX) for STALL_SECS = a stall; its cause is logged once per run.
const STALL_SECS := 4.0
const STALL_PX := 8.0
## Columns left of the shaft where the far shapes are dug (clear of the Clay pocket on the right).
const FAR := 14
const SHAFT := HillGenerator.SHAFT_X

var game: Node
var shots := false
var tag := ""
## Rope runs first stand still this long (the hint panel's "Y: rope up" shows), for frames.
var hint_wait := 0.0
## Climb runs give up after this long (game s); frame runs shorten it (`--trap-cap=`).
var climb_cap := CLIMB_CAP
var _it := {P1: IDLE.duplicate(), P2: IDLE.duplicate()}
var _saved := {}        # cell -> tile, for every cell a staging changed
var _wet: Array[Vector2i] = []
var _water0 := {}       # water cells near the staging before it (restore puts them back)
const WATER_MARGIN := 30


func _ug() -> Node:
	return game.underground


func _world() -> TileWorld:
	return game.underground.world


func layer_count() -> int:
	return _ug().layers().size()


func _floor(layer: int) -> int:
	return _ug().generator.landing_floor(layer)


func _bottom(layer: int) -> int:
	var l: LayerData = _ug().layers()[layer]
	return mini(l.depth_to, HillGenerator.STRANGE_FROM) - 5


func _tile(block: StringName) -> int:
	return int(_ug().generator._ids.get(block, 1))


## True when the shape makes sense on this layer (no gate under the Bottom).
func applies(shape: String, layer: int) -> bool:
	if shape == "gate":
		return layer < layer_count() - 1
	return true


# --- staging -------------------------------------------------------------------------------------

func _put(c: Vector2i, id: int) -> void:
	var w := _world()
	if not _saved.has(c):
		_saved[c] = w.get_tile(c)
	w.set_tile(c, id)


func _air(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(Vector2i(x, y), 0)


func _fill(r: Rect2i, id: int, keep_air := true) -> void:
	var w := _world()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if keep_air and not w.is_solid(c):
				continue
			_put(c, id)


func _snapshot(r: Rect2i) -> void:
	var w := _world()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not _saved.has(c):
				_saved[c] = w.get_tile(c)


## Puts every staged cell back as generated, and the water in and around it as it was before
## the staging (poured water flows on, so the whole neighbourhood is compared).
func restore() -> void:
	var w := _world()
	for c: Vector2i in _saved:
		if w.get_tile(c) != _saved[c]:
			w.set_tile(c, _saved[c])
	var box := _box()
	if box.size != Vector2i.ZERO:
		for c: Vector2i in w.water_cells():
			if box.has_point(c) and not _water0.has(c):
				w.set_water(c, false)
		for c: Vector2i in _water0:
			if box.has_point(c) and not w.has_water(c) and not w.is_solid(c):
				w.set_water(c, true)
	_wet.clear()
	_water0.clear()
	_saved.clear()


## The staged cells' bounding box, grown by WATER_MARGIN.
func _box() -> Rect2i:
	var box := Rect2i()
	var first := true
	for c: Vector2i in _saved:
		if first:
			box = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			box = box.expand(c)
	for c: Vector2i in _wet:
		box = box.expand(c)
	return box.grow(WATER_MARGIN) if not first else Rect2i()


## Digs the shape into the rock of `layer` (tiles only) and returns where the player's feet go:
## {feet: Vector2, note: String}. The way in is always a tunnel from the landing room, as a
## player would have dug it.
func stage(shape: String, layer: int) -> Dictionary:
	if _saved.is_empty() and _wet.is_empty():
		_water0.clear()
		for c: Vector2i in _world().water_cells():
			_water0[c] = true
	var f := _floor(layer)
	# Everything the escape may dig too (steps, side digs) goes back after the run.
	_snapshot(Rect2i(SHAFT - 50, f - 8, 102, _bottom(layer) + 14 - (f - 8)))
	var x := SHAFT - FAR            # far pits: columns x, x+1
	var room_left := SHAFT - HillGenerator.ROOM_HALF
	# The way in: a 2-high tunnel from the landing room out to the pit.
	var lane := Rect2i(x, f - 2, room_left - x, 2)
	var note := ""
	var feet := Vector2.ZERO
	match shape:
		"pit3", "pit6", "pit10":
			var d := int(shape.trim_prefix("pit"))
			_air(lane)
			_air(Rect2i(x, f, 2, d))
			feet = _cell_feet(Vector2(x + 1, f + d))
			note = "%d-deep pit, %d tiles from the shaft" % [d, SHAFT - x]
		"pit10_shaft":
			# Dug straight down from the landing room right beside the cage.
			_air(Rect2i(SHAFT - 2, f, 2, 10))
			feet = _cell_feet(Vector2(SHAFT - 1, f + 10))
			note = "10-deep pit beside the shaft"
		"overhang":
			# Down 4, then a room under the rock: the player stands under the overhang.
			_air(lane)
			_air(Rect2i(x, f, 2, 4))
			_air(Rect2i(x - 7, f + 4, 9, 3))
			feet = _cell_feet(Vector2(x - 5.5, f + 7))
			note = "pit 4 deep opening into a room 3 high under an overhang"
		"tunnel":
			# Down beside the shaft to the bottom of the layer, then far out sideways.
			var b := _bottom(layer)
			_air(Rect2i(SHAFT - 2, f, 2, b - f))
			_air(Rect2i(SHAFT - 42, b - 2, 42, 2))
			feet = _cell_feet(Vector2(SHAFT - 41, b))
			note = "pit by the shaft to the layer's bottom (%d deep), then a 40-tile tunnel" % (b - f)
		"gate":
			# A vehicle hole through the Gate Rock band under this layer (hopped out at its bottom):
			# on foot the band is not yours to dig yet.
			var d: int = (_ug().layers()[layer + 1] as LayerData).depth_from
			var gx := SHAFT - 30
			_air(Rect2i(gx, f - 2, room_left - gx, 2))
			_air(Rect2i(gx - 1, f, 3, d + 4 - f))
			feet = _cell_feet(Vector2(gx + 0.5, d + 4))
			note = "vehicle hole through the locked gate band at rows %d-%d" % [d - 2, d]
		"flood":
			_air(lane)
			_air(Rect2i(x, f, 2, 6))
			for yy in range(f, f + 6):
				for xx in [x, x + 1]:
					_world().set_water(Vector2i(xx, yy), true)
					_wet.append(Vector2i(xx, yy))
			feet = _cell_feet(Vector2(x + 1, f + 6))
			note = "6-deep pit full of water"
		"sand":
			_fill(Rect2i(x - 3, f, 8, 8), _tile(&"sand"))
			_air(lane)
			_air(Rect2i(x, f, 2, 6))
			feet = _cell_feet(Vector2(x + 1, f + 6))
			note = "6-deep pit in sand"
		"hole1":
			_air(lane)
			_air(Rect2i(x, f, 1, 6))
			feet = _cell_feet(Vector2(x + 0.5, f + 6))
			note = "1-wide hole 6 deep"
		"mole":
			_air(lane)
			_air(Rect2i(x, f, 2, 6))
			feet = _cell_feet(Vector2(x + 1, f + 6))
			note = "6-deep pit, the Mole takes the shovel at the bottom"
		"wet_landing":
			# The landing room under water (the Clay pocket burst into it): you float, the cage is
			# under you.
			var room: Rect2i = _ug().generator.landings[layer]
			for yy in range(room.position.y, room.end.y):
				for xx in range(room.position.x, room.end.x):
					var c := Vector2i(xx, yy)
					if not _world().is_solid(c):
						_world().set_water(c, true)
						_wet.append(c)
			feet = _cell_feet(Vector2(room.position.x + 2, room.end.y))
			note = "the landing room flooded to the ceiling"
		"lid":
			# Driven down through Hard Rock (vehicle only) and hopped out at the bottom.
			_air(lane)
			_fill(Rect2i(x - 3, f, 8, 3), _tile(&"hardrock"))
			_air(Rect2i(x, f, 2, 7))
			feet = _cell_feet(Vector2(x + 1, f + 7))
			note = "7-deep pit whose top 3 rows are vehicle-only Hard Rock"
	return {"feet": feet, "note": note}


## Feet on the floor of cell row `row` (the player stands on the cell below), x in cells.
static func _cell_feet(c: Vector2) -> Vector2:
	return Vector2(c.x * 16.0, c.y * 16.0 - 1.0)


# --- driving -------------------------------------------------------------------------------------

func _intent(p: int) -> Dictionary:
	return _it[p]


func attach(p: int) -> HillPlayer:
	var node: HillPlayer = game.player_node(p)
	if node != null:
		node.intent_source = _intent.bind(p)
	return node


## The lowest landing whose floor is above the feet (a landing level with the feet counts when
## `level`): where the climb bot heads.
func landing_above(feet_y: float, level := false) -> int:
	var row := int(floor((feet_y - 1.0) / 16.0)) + 1
	var best := 0
	for i in layer_count():
		if _floor(i) < row or (level and _floor(i) == row):
			best = i
	return best


## One frame of the climb bot for player p (state in st).
func bot_climb(p: int, st: Dictionary) -> void:
	var node: HillPlayer = game.player_node(p)
	var it: Dictionary = _it[p]
	it.jump = false
	it.horn = false
	if node == null or node.locked or game.elevator.is_riding(p):
		it.move = Vector2.ZERO
		it.dig = false
		return
	if game.elevator.prompt_of(p) == 1:
		# The A blinks over the head: let go of the stick and tap A.
		it.move = Vector2.ZERO
		it.dig = not it.dig
		return
	var pos := node.global_position
	# A landing level with the feet counts when it is near (the cage across the room); a far
	# one is behind rock: climb toward the one above instead.
	var li := landing_above(pos.y, true)
	if absf(_ug().landing(li).x - pos.x) > 12 * 16.0:
		li = landing_above(pos.y)
	# In a landing room (standing or floating): that room's cage.
	var feet_cell := Vector2i(int(floor(pos.x / 16.0)), int(floor((pos.y - 1.0) / 16.0)))
	for i in layer_count():
		if (_ug().generator.landings[i] as Rect2i).has_point(feet_cell):
			li = i
	var land: Vector2 = _ug().landing(li)
	var dx := land.x - pos.x
	var dy := land.y - pos.y
	it.dig = true
	if dy < -6.0:
		# Climb a staircase toward the shaft and keep that way (turning round walks back down the
		# steps); after a fall aim at the shaft again.
		if pos.y > float(st.get("ref_y", pos.y)) + 40.0:
			st.dir = 0.0
		if float(st.get("dir", 0.0)) == 0.0:
			st.dir = signf(dx) if dx != 0.0 else 1.0
			st.ref_y = pos.y
		st.ref_y = minf(float(st.ref_y), pos.y)
		it.move = Vector2(float(st.dir) * 0.7, -0.7)
		if node.is_on_floor() and node.is_on_wall() and Engine.get_physics_frames() % 30 == 0:
			it.jump = true
	elif dy > 10.0 and absf(dx) < 40.0 and not node.in_water():
		it.move = Vector2(0, 1)
	else:
		it.move = Vector2(signf(dx), 0)
		if node.is_on_floor() and node.is_on_wall() and Engine.get_physics_frames() % 20 == 0:
			it.jump = true


## One frame of the rope bot: hold Y until the crew pulls you up, then A in the cage.
func bot_rope(p: int, st: Dictionary) -> void:
	var node: HillPlayer = game.player_node(p)
	var it: Dictionary = _it[p]
	it.move = Vector2.ZERO
	it.jump = false
	if node == null or game.elevator.is_riding(p):
		it.dig = false
		it.horn = false
		return
	if not st.get("pulled", false):
		it.dig = false
		it.horn = true
		var r: Object = game.get("rescue")
		if r != null and r.is_pulling(p):
			st.pulled = true   # (a lock alone may be the Mole's theft: keep holding)
		return
	it.horn = false
	if node.locked:
		it.dig = false
		return
	if game.elevator.prompt_of(p) == 1:
		it.dig = not it.dig
	else:
		it.dig = false
		var land: Vector2 = _ug().landing(landing_above(node.global_position.y, true))
		it.move = Vector2(signf(land.x - node.global_position.x), 0)


## Why player p is not getting higher right now (the step toward `dir`).
func why_stuck(p: int, dir: int) -> String:
	var node: HillPlayer = game.player_node(p)
	if node == null or node.world == null:
		return "not underground"
	if not node.can_dig():
		return "no shovel (the Mole has it)"
	var w := node.world
	var feel := DigFeel.of(w)
	for c in node.step_cells():
		var def := w.tile_def(w.get_tile(c))
		var bd := def as BlockData
		if def != null and (not def.breakable or (bd != null and bd.dig_tier > 0) \
				or (feel != null and not feel.can_break(node, c, bd))):
			if node.has_method("step_cell_ok") and node.step_cell_ok(c):
				continue
			return "tile above can't be dug at this tier (%s at %s)" % [bd.id if bd != null else &"?", c]
	var g: Dictionary = node._step_geometry(dir)
	if not w.is_solid(Vector2i(g.front, g.row)):
		return "no foothold: step carve can't target air (%s)" % Vector2i(g.front, g.row)
	if node.in_water():
		return "floating in water"
	return "climbing too slowly (landing out of reach)"


## Runs one escape: stages `shape` on `layer`, puts P1 there and drives them out with `mode`.
## Returns {shape, layer, mode, ok, secs, reason, note}.
func run_one(shape: String, layer: int, mode: String) -> Dictionary:
	var out := {"shape": shape, "layer": layer, "mode": mode, "ok": false, "secs": -1.0, "reason": "", "note": ""}
	if mode == "rope" and game.get("rescue") == null:
		out.reason = "no rope rescue in this build"
		_log(out)
		return out
	await _until_calm()
	var s := stage(shape, layer)
	out.note = s.note
	var node := attach(P1)
	game.place_player(P1, &"underground", s.feet)
	node.velocity = Vector2.ZERO
	node.has_shovel = true
	_it[P1] = IDLE.duplicate()
	await _frames(20)   # settle on the floor (and let the chunks load)
	# The chunks around a staged shape load over a few frames (S-21) and their first frames can
	# shove a body placed in fresh air; once they are in, put the player back on the spot.
	for k in 3:
		if node.global_position.distance_to(s.feet) < 3.0:
			break
		game.place_player(P1, &"underground", s.feet)
		node.velocity = Vector2.ZERO
		await _frames(20)
	if OS.has_environment("TRAP_DEBUG"):
		var cs := []
		for yy in range(int(s.feet.y / 16.0) - 3, int(s.feet.y / 16.0) + 2):
			var row := ""
			for xx in range(int(s.feet.x / 16.0) - 3, int(s.feet.x / 16.0) + 3):
				row += "#" if _world().is_solid(Vector2i(xx, yy)) else "."
			cs.append(row)
		var bodies := []
		for b in _ug().boulders + _ug().rubble:
			if is_instance_valid(b) and b.global_position.distance_to(node.global_position) < 80:
				bodies.append(b.global_position)
		var phys := ""
		var space := node.get_world_2d().direct_space_state
		for xx in range(int(s.feet.x / 16.0) - 3, int(s.feet.x / 16.0) + 3):
			var q := PhysicsPointQueryParameters2D.new()
			q.position = _world().to_global(Vector2(xx * 16 + 8, int(s.feet.y / 16.0) * 16 - 8))
			phys += "#" if not space.intersect_point(q).is_empty() else "."
		print("dbg placed=%s now=%s cells=%s phys=%s bodies=%s wpos=%s" % [s.feet, node.global_position, cs, phys, bodies, _world().global_position])
	if shape == "mole":
		var res: Node = _ug().residents
		if res == null or not res.steal(node):
			out.note += " (the Mole could not steal now)"
	var lname := String((_ug().layers()[layer] as LayerData).id)
	if shots:
		await _frames(20)
		await Debug.screenshot("%s_%s_%s%s" % [lname, shape, mode, ("_" + tag) if tag != "" else ""])
	var st := {}
	var cap := climb_cap if mode == "climb" else ROPE_CAP
	var frames := 0
	var best := node.global_position.y
	var since := 0
	var reasons: Array = []
	var mid_shot := false
	var snaps := {}
	var suffix := ("_" + tag) if tag != "" else ""
	if mode == "rope" and hint_wait > 0.0:
		await _frames(int(hint_wait * 60.0))
		if shots:
			await Debug.screenshot("%s_%s_%s_hint%s" % [lname, shape, mode, suffix])
	while frames < int(cap * 60.0):
		if game.director.scene_of(P1) == &"hillville":
			break
		if mode == "climb":
			bot_climb(P1, st)
		else:
			bot_rope(P1, st)
		await get_tree().physics_frame
		frames += 1
		if shots:
			await _snap(node, mode, "%s_%s_%s" % [lname, shape, mode], suffix, snaps)
		if OS.has_environment("TRAP_DEBUG") and (frames % 30 == 0 or frames < 12):
			print("dbg f=%d pos=%s vel=%s floor=%s wall=%s move=%s dig=%s horn=%s prompt=%d locked=%s stop=%d key=%s" % [frames, node.global_position,
					node.velocity, node.is_on_floor(), node.is_on_wall(), _it[P1].move, _it[P1].dig, _it[P1].horn,
					game.elevator.prompt_of(P1), node.locked, game.elevator.stop_row_of(P1) if game.elevator.has_method("stop_row_of") else -9,
					game.elevator.cage_of(P1)] + " story=%s %s" % [game.story_scenes.get("_locked") if game.get("story_scenes") else "-", game.story_scenes.player.get("id") if game.get("story_scenes") and game.story_scenes.get("player") else "-"])
		if node.global_position.y < best - STALL_PX:
			best = node.global_position.y
			since = 0
		elif not node.locked and not game.elevator.is_riding(P1):
			since += 1
			if since == int(STALL_SECS * 60.0):
				var why := why_stuck(P1, int(st.get("dir", node.facing)) if st.get("dir", 0.0) != 0.0 else node.facing)
				if not reasons.has(why):
					reasons.append(why)
				if shots and not mid_shot:
					mid_shot = true
					await Debug.screenshot("%s_%s_%s_stuck%s" % [lname, shape, mode, ("_" + tag) if tag != "" else ""])
	out.ok = game.director.scene_of(P1) == &"hillville"
	out.secs = frames / 60.0
	out.reason = "; ".join(reasons) if not reasons.is_empty() else ("" if out.ok else "timeout")
	_it[P1] = IDLE.duplicate()
	await _until_free(P1)
	restore()
	_log(out)
	return out


## Frames at the moments that tell the story: the ring half full, the rope pulling, landed in the
## cage, and the car arriving at a stop beside the shaft.
func _snap(node: HillPlayer, mode: String, base: String, suffix: String, done: Dictionary) -> void:
	var r: Object = game.get("rescue")
	var want := ""
	if mode == "rope" and r != null:
		if r.hold_of(P1) >= 0.6 and not done.has("ring"):
			want = "ring"
		elif r.is_pulling(P1) and node.modulate.a < 0.75 and not done.has("pull"):
			want = "pull"
		elif done.has("pull") and not r.is_pulling(P1) and game.elevator.prompt_of(P1) == 1 and not done.has("landed"):
			want = "landed"
	elif mode == "climb" and game.elevator.is_riding(P1) and not done.has("car"):
		if absf(game.elevator.car_position() - float(game.elevator.car_at)) > 0.001 or game.elevator.has_method("stop_row_of"):
			if game.elevator._calls.size() > 0:
				var c: Dictionary = game.elevator._calls[0]
				if float(c.t) / maxf(float(c.dur), 0.001) > 0.8:
					want = "car"
	if want == "":
		return
	done[want] = true
	await Debug.screenshot("%s_%s%s" % [base, want, suffix])


func _log(r: Dictionary) -> void:
	print("trap: layer=%s shape=%s mode=%s ok=%s secs=%.2f reason=\"%s\" note=\"%s\"" % [
		String((_ug().layers()[r.layer] as LayerData).id), r.shape, r.mode, r.ok, r.secs, r.reason, r.note])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Waits (at most 30 s) until no story scene plays, the Mole is not mid-theft and P1 is free, so
## one run never spills into the next.
func _until_calm() -> void:
	var n := 0
	while n < 1800:
		var st: Node = game.get("story_scenes")
		var res: Node = _ug().residents
		var node: HillPlayer = game.player_node(P1)
		var busy: bool = (st != null and st.is_playing()) or (res != null and res.theft_time() >= 0.0) \
				or (node != null and node.locked) or game.elevator.is_riding(P1)
		if not busy:
			return
		await get_tree().physics_frame
		n += 1


func _until_free(p: int) -> void:
	var n := 0
	while n < 240 and (game.elevator.is_riding(p) or (game.player_node(p) != null and game.player_node(p).locked)):
		await get_tree().physics_frame
		n += 1


## Every (layer, shape, mode) asked for; returns the results.
func run(layers: Array, shapes: Array, modes: Array) -> Array:
	var results: Array = []
	for layer in layers:
		for shape in shapes:
			if not applies(shape, layer):
				continue
			for mode in modes:
				results.append(await run_one(shape, layer, mode))
	return results


static func summary(results: Array) -> String:
	var ok := 0
	var worst := 0.0
	var fails: Array = []
	for r in results:
		if r.ok:
			ok += 1
			worst = maxf(worst, r.secs)
		elif not String(r.reason).begins_with("no rope rescue"):
			fails.append("%s/%d/%s" % [r.shape, r.layer, r.mode])
	return "trap-audit: %d/%d out, slowest %.2f s, stuck: %s" % [ok, results.size(), worst, ", ".join(fails) if not fails.is_empty() else "none"]


## `--trap-audit`: HillGame adds this instead of the demo runner. Runs the asked matrix with P1
## (P2 waits up top), prints every `trap:` line and the summary, then quits.
class Runner:
	extends Node
	var game: Node
	var audit: TrapAudit

	func _ready() -> void:
		name = "TrapAuditRunner"
		audit = TrapAudit.new()
		audit.game = game
		add_child(audit)
		var layers: Array = range(audit.layer_count())
		var shapes: Array = TrapAudit.SHAPES.duplicate()
		var modes: Array = TrapAudit.MODES.duplicate()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--trap-layers="):
				layers = Array(a.trim_prefix("--trap-layers=").split(",", false)).map(func(s): return int(s))
			elif a.begins_with("--trap-shapes="):
				shapes = Array(a.trim_prefix("--trap-shapes=").split(",", false))
			elif a.begins_with("--trap-modes="):
				modes = Array(a.trim_prefix("--trap-modes=").split(",", false))
			elif a == "--trap-shots":
				audit.shots = true
			elif a.begins_with("--trap-tag="):
				audit.tag = a.trim_prefix("--trap-tag=")
			elif a.begins_with("--trap-cap="):
				audit.climb_cap = float(a.trim_prefix("--trap-cap="))
			elif a.begins_with("--trap-hint-wait="):
				audit.hint_wait = float(a.trim_prefix("--trap-hint-wait="))
		_go(layers, shapes, modes)

	func _go(layers: Array, shapes: Array, modes: Array) -> void:
		while game.player_node(P1) == null:
			await get_tree().physics_frame
		await audit._frames(60)
		var results: Array = await audit.run(layers, shapes, modes)
		print(TrapAudit.summary(results))
		get_tree().quit()
