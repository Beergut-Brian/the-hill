## The Mole's arc, rebuilt (GAME.md playtest item 3). He does not show himself at first: while a
## player digs on foot in Topsoil or Clay, three hints come first, spread over the gap before each
## theft (data/story/mole_arc.json):
##   0 wobble   a tile beside the digger wobbles and drops crumbs (something is behind it)
##   1 trail    a little line of dirt mounds pops up along the tunnel, running away
##   2 shadow   a shovel-shaped shadow slides along the wall behind the digger
## Then HillStory plays "mole_theft" (he sneaks in, you see him, he takes the shovel), the player
## cannot dig for a moment, and "mole_return" (fade, you wake up top by the shaft, he hands it
## back, sheepish). Each theft needs a minimum of real play time underground, tiles dug and depth
## since the last; the counters are saved in resident_arcs.mole_arc. The third makes him ARRIVED.
class_name MoleArc
extends Node2D

const TUNING := "res://data/story/mole_arc.json"
const DIRT := Color(0.5, 0.36, 0.25)
const DARK := Color(0.08, 0.05, 0.04)
const HINT_SECS := [2.6, 2.4, 2.4]
const HINT_NAMES: Array[StringName] = [&"wobble", &"trail", &"shadow"]

var story_host: Object
var game: HillGame
var tuning: Dictionary = {}
## The hint on screen: {kind, t, at: Vector2 (underground local), dir, cell, color}.
var hint := {}
## Every hint shown (tests and the beat log): [kind, ...].
var shown: Array = []

var _last_digger := -1


func setup(p_game: HillGame) -> void:
	game = p_game
	name = "MoleArc"
	z_as_relative = false
	z_index = UndergroundLook.GLOW_Z + 1
	tuning = load_tuning()
	game.underground.add_child(self)
	Events.tile_dug.connect(_on_tile_dug)


func _exit_tree() -> void:
	if Events.tile_dug.is_connected(_on_tile_dug):
		Events.tile_dug.disconnect(_on_tile_dug)


static func load_tuning() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(TUNING)) if FileAccess.file_exists(TUNING) else null
	if d is Dictionary:
		return d
	return {"thefts": [{"secs": 75, "tiles": 10, "depth": 0}], "hints_at": [0.3, 0.55, 0.8], "layers": ["topsoil", "clay"]}


## Saved counters since the last theft: {secs, tiles, hints}.
func state() -> Dictionary:
	var st: Dictionary = game.story.extras.get("mole_arc", {})
	if st.is_empty():
		st = {"secs": 0.0, "tiles": 0, "hints": 0}
		game.story.extras["mole_arc"] = st
	return st


func reset() -> void:
	game.story.extras["mole_arc"] = {"secs": 0.0, "tiles": 0, "hints": 0}
	hint = {}


func active() -> bool:
	return not game.story.in_town(Story.MOLE)


## The gap the next theft needs: {secs, tiles, depth}.
func need() -> Dictionary:
	var list: Array = tuning.get("thefts", [])
	var n := game.story.state(Story.MOLE).encounters
	return list[clampi(n, 0, list.size() - 1)] if not list.is_empty() else {"secs": 60, "tiles": 10, "depth": 0}


## 0..1: how far into the gap before the next theft (the smaller of time and tiles).
func progress() -> float:
	var st := state()
	var nd := need()
	return minf(float(st.secs) / maxf(1.0, float(nd.secs)), float(st.tiles) / maxf(1.0, float(nd.tiles)))


func _digging_layer(pl: HillPlayer) -> bool:
	var u := game.underground
	var i := u.layer_index_at(u.to_local(pl.global_position))
	var ls := u.layers()
	return i >= 0 and i < ls.size() and (tuning.get("layers", []) as Array).has(String((ls[i] as LayerData).id))


func _on_foot_below(p: int) -> HillPlayer:
	var pl := game.player_node(p)
	if pl == null or pl.vehicle != null or game.director.scene_of(p) != HillGame.UNDERGROUND:
		return null
	if game.elevator.is_riding(p):
		return null
	return pl


func _on_tile_dug(_cell: Vector2i, _block: StringName, p: int) -> void:
	if not active() or p < 0:
		return
	var pl := _on_foot_below(p)
	if pl == null or not _digging_layer(pl):
		return
	_last_digger = p
	state().tiles = int(state().tiles) + 1


func _physics_process(delta: float) -> void:
	if not hint.is_empty():
		hint.t = float(hint.t) + delta
		if float(hint.t) >= HINT_SECS[int(hint.idx)]:
			hint = {}
		queue_redraw()
	if not active() or story_host == null or story_host.call("is_playing"):
		return
	var pl := _on_foot_below(_last_digger) if _last_digger >= 0 else null
	var anyone := false
	for p: int in game.players:
		if _on_foot_below(p) != null:
			anyone = true
	if not anyone:
		return
	var st := state()
	st.secs = float(st.secs) + delta
	if pl == null or not _digging_layer(pl) or bool(story_host.call("shovel_gone", pl.player)):
		return
	var f := progress()
	var at: Array = tuning.get("hints_at", [0.3, 0.55, 0.8])
	var h := int(st.hints)
	if h < at.size() and h < 3 and f >= float(at[h]) and hint.is_empty():
		show_hint(h, pl)
		return
	var res: UndergroundResidents = game.underground.residents
	var deep := rows_below_landing(pl) >= int(need().get("depth", 0)) or int(need().get("depth", 0)) <= 0
	if f >= 1.0 and h >= mini(3, at.size()) and hint.is_empty() and deep and (res == null or not res.is_rescuing()):
		story_host.call("start_theft", pl.player)


## How many rows below the Topsoil landing (where the elevator lets you off) `pl` stands.
func rows_below_landing(pl: HillPlayer) -> int:
	var u := game.underground
	return int(floor((u.to_local(pl.global_position).y - u.landing(0).y) / 16.0))


## Shows hint `idx` next to `pl` (beats and tests call it directly).
func show_hint(idx: int, pl: HillPlayer) -> void:
	var u := game.underground
	var feet := u.to_local(pl.global_position)
	var dir := float(pl.facing if pl.facing != 0 else 1)
	hint = {"idx": idx, "kind": HINT_NAMES[idx], "t": 0.0, "at": feet, "dir": dir, "p": pl.player}
	state().hints = idx + 1
	shown.append(HINT_NAMES[idx])
	match idx:
		0:
			var cell := _wobble_cell(pl)
			hint.cell = cell
			var def = u.world.tile_def(u.world.get_tile(cell)) if cell != Vector2i(-9999, -9999) else null
			hint.color = u.block_color((def as BlockData).id) if def is BlockData else DIRT
			Audio.play("mole_dig")
			Audio.play("rock_crack")
			if cell != Vector2i(-9999, -9999):
				var w := u.world
				u.burst(u.to_local(w.to_global(w.shape.center_of(cell))) + Vector2(0, 6), hint.color, 10, 70.0)
		1:
			hint.dir = -dir
			Audio.play("mole_dig")
			u.burst(feet + Vector2(-dir * 26.0, -4), DIRT, 8, 60.0)
		2:
			Audio.play("mole_pop")
	queue_redraw()


func _wobble_cell(pl: HillPlayer) -> Vector2i:
	var w := game.underground.world
	var c: Vector2i = w.shape.cell_at(w.to_local(pl.global_position))
	var f := pl.facing if pl.facing != 0 else 1
	for o in [Vector2i(f * 2, -1), Vector2i(-f * 2, -1), Vector2i(f * 2, -2), Vector2i(-f * 2, -2), Vector2i(f, -3), Vector2i(0, -3), Vector2i(f * 3, -1)]:
		if w.is_solid(c + o):
			return c + o
	return c + Vector2i(f * 2, -1)


func _draw() -> void:
	if hint.is_empty():
		return
	var t := float(hint.t)
	var life := float(HINT_SECS[int(hint.idx)])
	var a := clampf(minf(t / 0.2, (life - t) / 0.4), 0.0, 1.0)
	var at: Vector2 = hint.at
	var dir := float(hint.dir)
	match String(hint.kind):
		"wobble":
			var cell: Vector2i = hint.cell
			var w := game.underground.world
			var c := game.underground.to_local(w.to_global(w.shape.center_of(cell)))
			var ang := sin(t * 26.0) * 0.16 * (1.0 if fmod(t, 0.9) < 0.6 else 0.25)
			draw_set_transform(c, ang, Vector2.ONE)
			var col: Color = hint.color
			draw_rect(Rect2(-8, -8, 16, 16), Color(col.lightened(0.1), a))
			draw_rect(Rect2(-8, -8, 16, 16), Color(DARK, a * 0.9), false, 2.0)
			draw_line(Vector2(-3, -8), Vector2(1, -1), Color(DARK, a * 0.7), 1.0)
			draw_line(Vector2(1, -1), Vector2(-2, 6), Color(DARK, a * 0.7), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 6:
				var ft := fmod(t * 1.6 + i * 0.23, 1.0)
				draw_rect(Rect2(c + Vector2(-7 + i * 3, 8 + ft * 18.0), Vector2(3, 3)), Color(col.darkened(0.25), a * (1.0 - ft)))
		"trail":
			# Little mounds push up one after another, running away along the tunnel floor.
			for i in 7:
				var appear := 0.16 * i
				if t < appear:
					continue
				var k := clampf((t - appear) / 0.15, 0.0, 1.0)
				var p := at + Vector2(dir * (26.0 + i * 13.0), -1.0)
				var r := 7.0 * k
				draw_circle(p, r + 1.2, Color(DARK, a * 0.8))
				draw_circle(p, r, Color(DIRT.lightened(0.12), a))
				draw_circle(p + Vector2(-2, -2) * k, r * 0.45, Color(DIRT.lightened(0.35), a))
				if k < 1.0:
					for j in 3:
						draw_rect(Rect2(p + Vector2(-4 + j * 4, -r - 5.0 * k), Vector2(2, 2)), Color(DIRT.darkened(0.2), a))
		"shadow":
			# A big shovel-shaped shadow slides along the wall behind the digger, carried by
			# someone small and round (ears and a nose): you only see the shadow.
			var x := lerpf(-70.0, 70.0, clampf(t / life, 0.0, 1.0)) * -dir
			var c := at + Vector2(x, -26.0 + sin(t * 9.0) * 2.0)
			var col := Color(DARK, 0.62 * a)
			draw_set_transform(c, 0.0, Vector2(1.8 * -dir, 1.8))
			_shovel_shadow(Vector2.ZERO, col)
			draw_circle(Vector2(8, 9), 6.0, col)
			draw_circle(Vector2(4, 4), 2.2, col)
			draw_circle(Vector2(12, 4), 2.2, col)
			draw_circle(Vector2(14, 10), 2.0, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shovel_shadow(c: Vector2, col: Color) -> void:
	draw_line(c + Vector2(7, -10), c + Vector2(-2, 2), col, 2.5)
	draw_line(c + Vector2(5, -11), c + Vector2(9, -8), col, 2.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-1, 0), c + Vector2(-8, 4), c + Vector2(-8, 10), c + Vector2(-3, 10), c + Vector2(2, 3)]), col)
