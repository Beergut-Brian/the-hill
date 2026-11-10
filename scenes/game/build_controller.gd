## Up-top building: the per-player build book, the ghost that follows the player one plot ahead,
## snapping to Hillville's plot grid, placing (with the unfold), picking up and moving for free,
## and the Garage's vehicle unlock. Reads `game.hillville`, `game.director` (may be null) and
## `game.player_node(p)` (`global_position` feet, `facing`, `honk()`, `bump()`).
class_name BuildController
extends Node

const PLOT := 48
const BUILDING_DIR := "res://data/buildings/"
## Book card order; any other showable row comes after, by id.
const ORDER := [&"barn", &"house", &"garage", &"lighthouse", &"water_tower"]

## The HillGame (or a test fake). Falls back to the parent.
var game: Node

var _st := {}   # player -> {book, ghost: Building, paid: Dictionary, move_from: Vector2i}


func _ready() -> void:
	if game == null:
		game = get_parent()
	Events.entered_scene.connect(_on_entered_scene)
	Events.treasure_found.connect(_on_treasure_found)


func _exit_tree() -> void:
	if Events.entered_scene.is_connected(_on_entered_scene):
		Events.entered_scene.disconnect(_on_entered_scene)
	if Events.treasure_found.is_connected(_on_treasure_found):
		Events.treasure_found.disconnect(_on_treasure_found)


func _s(p: int) -> Dictionary:
	if not _st.has(p):
		_st[p] = {"book": null, "ghost": null, "paid": {}, "move_from": Vector2i.ZERO}
	return _st[p]


func _hv() -> Hillville:
	return game.hillville if game != null else null


func _pn(p: int) -> Node2D:
	return game.player_node(p) if game != null else null


## Feet in Hillville-local px, and facing.
func _feet(p: int) -> Vector2:
	var pn := _pn(p)
	if pn == null:
		return Vector2.ZERO
	return _hv().to_local(pn.global_position)


func _facing(p: int) -> int:
	var pn := _pn(p)
	return 1 if pn == null or int(pn.facing) >= 0 else -1


# --- the seam ----------------------------------------------------------------------------------

## The book is open for this player: HillPlayer must not move or act.
func captures(player: int) -> bool:
	var b = _s(player).book
	return b != null and is_instance_valid(b) and b.is_open()


## X: open the book (or close it). With a ghost in hand, the ghost goes back first.
func book_pressed(player: int) -> void:
	if captures(player):
		_close_book(player)
		return
	if has_ghost(player):
		cancel(player)
	_open_book(player)


func book_input(player: int, move: Vector2, a_pressed: bool, b_pressed: bool) -> void:
	if not captures(player):
		return
	var book = _s(player).book
	book.steer(move.x)
	if b_pressed:
		_close_book(player)
	elif a_pressed:
		_pick(player, book.focused_id())


func has_ghost(player: int) -> bool:
	var g = _s(player).ghost
	return g != null and is_instance_valid(g)


## A up top: drop the ghost, or pick up a building in reach. True when it used the press.
func action(player: int) -> bool:
	if captures(player):
		return true
	if has_ghost(player):
		_drop(player)
		return true
	var idx := building_in_reach(player)
	if idx < 0:
		return false
	_pick_up(player, idx)
	return true


## B with a ghost: a picked-up building goes back, a new one is refunded. True when it used the press.
func cancel(player: int) -> bool:
	if not has_ghost(player):
		return false
	var s := _s(player)
	var g: Building = s.ghost
	if g.index >= 0:
		g.position = Vector2(s.move_from.x * PLOT, 0)
		g.ghost = false
		g.bump()
	else:
		for k in s.paid:
			Inventory.add(StringName(str(k)), int(s.paid[k]))
		g.queue_free()
		_hv().puff(g.position + Vector2(g.size_px().x * 0.5, 0), Color(0.9, 0.9, 0.9), 8)
	Audio.play("build_cancel")
	s.ghost = null
	s.paid = {}
	return true


## Recreates every Building from Progress.buildings: no unfolds, no unlocks (after loading a save).
func rebuild() -> void:
	for p in _st:
		_close_book(p)
		_st[p].ghost = null
		_st[p].paid = {}
	var root := _hv().buildings_root()
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	for i in Progress.buildings.size():
		var b: Dictionary = Progress.buildings[i]
		var d := Progress.building_data(b.id)
		if d == null:
			continue
		var node := Building.make(d)
		node.index = i
		node.position = Vector2(b.cell.x * PLOT, 0)
		root.add_child(node)


# --- extras (tests, HUD, demo) -----------------------------------------------------------------

## The book's cards: every showable, non-ruin BuildingData row whose vehicle (if any) is unlocked, in ORDER.
func book_rows() -> Array:
	return _rows(false)


## Cards shown greyed at the end of the book with a picture of what opens them (the Lighthouse and
## the Water Tower before the Crane). Picking one bounces the picture; it is never a dead end.
func locked_rows() -> Array:
	return _rows(true)


func _rows(locked: bool) -> Array:
	var rows: Array = []
	for f in DirAccess.get_files_at(BUILDING_DIR):
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var d := Progress.building_data(StringName(file.get_basename()))
		if d == null or d.is_ruin or d.from_ruin != &"" or not d.can_show_in_book(Progress.treasures, 0):
			continue
		var waits := d.needs_vehicle != &"" and not Progress.has_vehicle(d.needs_vehicle)
		if waits != locked:
			continue   # the Lighthouse waits for the Crane
		rows.append(d)
	rows.sort_custom(func(a: BuildingData, b: BuildingData) -> bool:
		var ia := ORDER.find(a.id)
		var ib := ORDER.find(b.id)
		ia = ORDER.size() if ia < 0 else ia
		ib = ORDER.size() if ib < 0 else ib
		return ia < ib if ia != ib else String(a.id) < String(b.id))
	return rows


## Restore cards: one per ruin whose resident is waiting (ARRIVED), drawn as the building it
## becomes at the ruin's restore cost (a copy of the restored row). The ruin the player stands at
## comes first, so opening the book "on the ruin" focuses its card.
func restore_rows(player := -1) -> Array:
	var st = game.get("story") if game != null else null
	if not (st is Story):
		return []
	var rows: Array = []
	var here := &""
	var hv := _hv()
	if player >= 0 and hv != null and _pn(player) != null:
		var x := _feet(player).x
		for rid in hv.ruin_ids():
			var r: Rect2 = hv.ruin_rect(rid)
			if x > r.position.x - PLOT and x < r.end.x + PLOT:
				here = rid
	for rid: StringName in [&"old_shed", &"crooked_watchtower", &"flooded_cabin", &"ruined_keep"]:
		var ruin := Progress.building_data(rid)
		if ruin == null or not Rules.can_restore(ruin, (st as Story).state(ruin.resident), true):
			continue
		var home := Progress.building_data(ruin.restores_into)
		if home == null:
			continue
		var card: BuildingData = home.duplicate()
		card.cost = ruin.cost.duplicate()
		if rid == here:
			rows.push_front(card)
		else:
			rows.append(card)
	return rows


func book_of(player: int) -> Control:
	var b = _s(player).book
	return b if b != null and is_instance_valid(b) else null


func ghost_of(player: int) -> Building:
	return _s(player).ghost if has_ghost(player) else null


## Plot cell the ghost snaps to: its centre one plot ahead of the feet along facing, rounded.
static func plot_cell_for(feet_x: float, facing: int, width: int) -> int:
	var ahead := feet_x + facing * PLOT * (1.0 + width * 0.5)
	return floori((ahead - width * PLOT * 0.5) / PLOT + 0.5)


func ghost_cell(player: int) -> Vector2i:
	var g := ghost_of(player)
	var w := g.data.footprint.x if g != null else 1
	return Vector2i(plot_cell_for(_feet(player).x, _facing(player), w), 0)


## True when a `width`-cell building may stand at `cell_x` (ignoring Progress building `ignore`).
func plot_clear(cell_x: int, width: int, ignore := -1) -> bool:
	if not _hv().ground_clear(cell_x, width):
		return false
	for i in Progress.buildings.size():
		if i == ignore:
			continue
		var b: Dictionary = Progress.buildings[i]
		var d := Progress.building_data(b.id)
		var bw := d.footprint.x if d != null else 1
		if cell_x < b.cell.x + bw and b.cell.x < cell_x + width:
			return false
	return true


## Progress index of the placed building under or just ahead of the player's feet, or -1.
func building_in_reach(player: int) -> int:
	var x := _feet(player).x
	var f := _facing(player)
	var lo := minf(x - 8, x + f * PLOT)
	var hi := maxf(x + 8, x + f * PLOT)
	var best := -1
	var best_d := INF
	for i in Progress.buildings.size():
		var b: Dictionary = Progress.buildings[i]
		var d := Progress.building_data(b.id)
		if d == null or d.is_ruin:
			continue
		var x0: float = b.cell.x * PLOT
		var x1 := x0 + d.footprint.x * PLOT
		if x1 < lo or x0 > hi:
			continue
		var dist := absf((x0 + x1) * 0.5 - x)
		if dist < best_d:
			best_d = dist
			best = i
	return best


func building_node(index: int) -> Building:
	for c in _hv().buildings_root().get_children():
		if c is Building and c.index == index and not c.is_queued_for_deletion():
			return c
	return null


# --- internals ---------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	for p in _st:
		if has_ghost(p):
			_update_ghost(p)


func _update_ghost(p: int) -> void:
	var g: Building = _s(p).ghost
	var cell := ghost_cell(p)
	g.position = Vector2(cell.x * PLOT, 0)
	g.ghost_ok = plot_clear(cell.x, g.data.footprint.x, g.index)


func _book_parent() -> Node:
	var layer: Node = game.get_node_or_null("Director/BookLayer") if game != null else null
	return layer if layer != null else self


func _open_book(p: int) -> void:
	var s := _s(p)
	if s.book != null and is_instance_valid(s.book):
		s.book.queue_free()
	var book := BuildBook.new()
	book.player = p
	book.controller = self
	book.rows = restore_rows(p) + book_rows()
	book.locked = locked_rows()
	_book_parent().add_child(book)
	s.book = book
	book.open()


func _close_book(p: int) -> void:
	var s := _s(p)
	if s.book != null and is_instance_valid(s.book):
		s.book.close()
	s.book = null


func _pick(p: int, id: StringName) -> void:
	var d := Progress.building_data(id)
	if d == null:
		return
	if d.from_ruin != &"":
		_restore(p, d.from_ruin)
		return
	var bk = _s(p).book
	if bk != null and is_instance_valid(bk) and bk.focused_locked():
		bk.hint()
		return
	if not Inventory.spend(d.cost):
		_s(p).book.shake()
		_honk(p)
		return
	Audio.play("build_pick")
	_close_book(p)
	var g := Building.make(d)
	g.ghost = true
	_hv().buildings_root().add_child(g)
	var s := _s(p)
	s.ghost = g
	s.paid = d.cost.duplicate()
	_update_ghost(p)
	g.bump()


## A restore card: pay the ruin's cost from the pile, then HillGame rebuilds it plank by plank.
func _restore(p: int, ruin_id: StringName) -> void:
	var ruin := Progress.building_data(ruin_id)
	if ruin == null or game == null or not game.has_method("restore_ruin"):
		return
	if not Inventory.can_afford(ruin.cost):
		_s(p).book.shake()
		_honk(p)
		return
	Audio.play("build_pick")
	_close_book(p)
	game.restore_ruin(ruin_id)


func _pick_up(p: int, idx: int) -> void:
	var node := building_node(idx)
	if node == null:
		return
	var s := _s(p)
	s.ghost = node
	s.paid = {}
	s.move_from = Progress.buildings[idx].cell
	node.ghost = true
	node.bump()
	Audio.play("build_pickup")
	_update_ghost(p)


func _drop(p: int) -> void:
	_update_ghost(p)
	var s := _s(p)
	var g: Building = s.ghost
	var cell := ghost_cell(p)
	if not plot_clear(cell.x, g.data.footprint.x, g.index):
		g.flash_bad()
		_honk(p)
		return
	s.ghost = null
	s.paid = {}
	g.ghost = false
	g.position = Vector2(cell.x * PLOT, 0)
	var pn := _pn(p)
	if pn != null and pn.has_method("bump"):
		pn.bump()
	if g.index >= 0:
		Progress.move_building(g.index, cell)
		Audio.play("build_place")
		g.bump()
		_hv().puff(g.position + Vector2(g.size_px().x * 0.5, 0), Color(0.85, 0.75, 0.6), 8)
		return
	g.index = Progress.add_building(g.data.id, cell)
	Audio.play("build_place")
	Audio.play("cheer")
	var t := g.unfold()
	if g.data.effect == &"next_vehicle":
		_garage(g, t)


func _garage(g: Building, unfold: Tween) -> void:
	await unfold.finished
	if not is_instance_valid(g):
		return
	if Progress.next_vehicle() == null and Progress.next_in_line() != null:
		# Waiting for its treasure (the Drill Rig needs the Giant Tooth): the door stays shut
		# until it is found (redeem_garages). The card showed the tooth.
		g.bump()
		Audio.play("garage_waits")
		return
	await g.open_door().finished
	if not is_instance_valid(g):
		return
	var id := Progress.unlock_next_vehicle()
	if id != &"":
		_hv().vehicle_rolls_out.emit(id, g.door_position())


## A Garage built while its vehicle waited for a treasure opens once the treasure is found: the
## newest waiting Garage's door rolls up and the vehicle rolls out. Returns how many opened.
func redeem_garages() -> int:
	var n := 0
	while Progress.garages_waiting() > 0 and Progress.next_vehicle() != null:
		var g := _waiting_garage(n)
		var id := Progress.unlock_next_vehicle()
		n += 1
		if g == null or _hv() == null:
			continue
		var door := g.door_position()
		var tw := g.open_door()
		tw.finished.connect(func() -> void:
			if is_instance_valid(g):
				_hv().vehicle_rolls_out.emit(id, door))
	return n


## The waiting Garage nodes, newest first; `skip` already used.
func _waiting_garage(skip: int) -> Building:
	if _hv() == null:
		return null
	var found := 0
	for i in range(Progress.buildings.size() - 1, -1, -1):
		if Progress.buildings[i].id != &"garage":
			continue
		var node := building_node(i)
		if node != null and node.door_open < 0.5:
			if found == skip:
				return node
			found += 1
	return null


func _on_treasure_found(_id: StringName, _p: int) -> void:
	if Progress.garages_waiting() > 0:
		redeem_garages()


func _honk(p: int) -> void:
	var pn := _pn(p)
	if pn != null and pn.has_method("honk"):
		pn.honk()
	else:
		Audio.play("honk")


func _on_entered_scene(p: int, scene: StringName) -> void:
	if scene != &"hillville":
		_close_book(p)
		cancel(p)
