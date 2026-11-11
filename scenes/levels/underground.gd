## The underground: a TileWorld (RectShape 200 x 300) built by HillGenerator from data/layers and
## data/blocks, a backdrop tinted by layer, a landing room with a cage at the top of every layer,
## boulders, the seeded treasure props, darkness bands from LayerData and the water gush.
## Wires the world's signals to Events, Audio and particle bursts. HillGame owns the players and
## adds them under the "Players" child (the director does that); HillGame gives them headlamps.
## The art (HillTileArt tiles and walls, UndergroundLook: parallax, water, props, lamps, residents)
## is visuals only and falls back to the flat look when the sheets are missing.
class_name Underground
extends Node2D

signal treasure_dug(id: StringName, player: int)
## The Crane hauled boulder `index` (into boulders / generator.boulder_spots) out.
signal boulder_hauled(index: int, player: int)

const BLOCK_ORDER: Array[StringName] = [&"dirt", &"clay", &"stone", &"ice", &"crystal", &"edgestone", &"strangestone", &"sand", &"pebbles", &"pipe", &"ore", &"geode", &"gaterock", &"hardrock"]
const BLOCK_DIR := "res://data/blocks/"
const LAYER_DIR := "res://data/layers/"
const TREASURE_DIR := "res://data/treasures/"
const HAZARD_DIR := "res://data/hazards/"
const GATE_DIR := "res://data/gates/"
const WIDTH := HillGenerator.WIDTH
const HEIGHT := HillGenerator.HEIGHT
const DEFAULT_SEED := 20261110
const BOULDER_SIZE := 26.0
## Contract "Water gush": a breached pocket refills its emptied cells for this long.
const GUSH_TIME := 2.0
const GUSH_TICK := 0.1
const GUSH_PER_TICK := 3
const TREASURE_COLORS := {&"buried_car": Color("d9534f"), &"giant_tooth": Color("f4f1e6"), &"gnome_room": Color("8e6c4a")}
const DARK := Color(0.07, 0.06, 0.09)
## Each Water Tower up top drains this many water cells around every player underground per tick.
const DRAIN_EVERY := 0.4
const DRAIN_PER_TOWER := 2
const DRAIN_REACH := 14
## Stone blocks a hauled boulder gives (into the Crane's backpack).
const BOULDER_BLOCKS := 4
## W-20: these break into chunks (cut from their picture) when dug under. Every other treasure
## drops whole (W-19), like a boulder, and stays where it lands.
const BREAKS: Array[StringName] = [&"buried_car", &"bathtub", &"gnome_room"]
## W-19 / W-20: A (a dig or a swing) by a player within this many px of a loose treasure or a
## chunk, plus the thing's own half size, picks it up. Only once it has had time to land.
const GRAB_REACH := 26.0
const GRAB_AFTER_FRAMES := 24

@export var world_seed := DEFAULT_SEED

var world: TileWorld
var generator: HillGenerator
var blocks: Dictionary = {}          # StringName -> BlockData
var props: Dictionary = {}           # StringName treasure id -> Array[BreakableProp]
var boulders: Array[FallingBody] = []
## W-19: a pickup treasure that came loose (dropped whole, or the bathtub's chunks): id -> Array of
## FallingBody. It is found only when a player picks it up with A (then all of it goes at once).
var loose: Dictionary = {}
## W-20: chunks of a treasure that stays (the car, the Gnome Room's walls; already found when they
## broke): A by one pops it into the backpack as a block of the layer, nothing else changes.
var rubble: Array[FallingBody] = []
var players_root: Node2D
## 0..1, the elevator animates it; flash_layer says which landing's cage.
var cage_flash := 0.0:
	set(v):
		cage_flash = v
		if _cages:
			_cages.queue_redraw()
var flash_layer := 0

var _layers: Array = []
var _cages: Node2D
var look: UndergroundLook
## W-24: the Strangestone question bubble and sparkle when a dig bounces off it.
var strange: StrangeBubble
## One per water pocket (generator.pockets, the big Clay pocket first).
var _gushes: Array = []
## Kid-safe hazards (bonk, float, cave-in) and the residents' behaviour; see their scripts.
var hazards: Hazards
var residents: UndergroundResidents
## W-03 / W-11: roots, waving worms, snow drifts on the rinks and the frozen fish (pictures only).
var life: DepthLife
## Which residents have been met (thaw, reveal); HillGame swaps in its saved Story.
var story := Story.new()
## PT10-4: hit points, cracks, the unlock bands' signs and bonks (scripts/gameplay/dig_feel.gd).
var dig_feel: DigFeel
var _drain_t := 0.0


func _ready() -> void:
	name = "Underground"
	var shape := RectShape.new(WIDTH, HEIGHT)
	var palette := build_palette()
	var ids := {}
	for i in palette.size():
		ids[palette[i].id] = i
	_layers = load_rows(LAYER_DIR)
	_layers.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	generator = HillGenerator.new()
	generator.configure(_layers, ids, load_rows(TREASURE_DIR))
	generator.configure_hazards(load_rows(HAZARD_DIR))
	generator.configure_block_depths(blocks)
	generator.configure_gates(load_rows(GATE_DIR), int(ids.get(&"gaterock", 0)), int(ids.get(&"hardrock", -1)))
	var back := Node2D.new()
	back.name = "Backdrop"
	back.z_index = -100
	back.draw.connect(_draw_backdrop.bind(back))
	add_child(back)
	world = TileWorld.new()
	world.name = "World"
	world.add_to_group(&"tile_world")
	if HillTileArt.available():
		world.tile_art = HillTileArt.new(generator, world.collision_layer)
	world.setup(shape, generator, palette, world_seed)
	add_child(world)
	var bands: Array = []
	for l: LayerData in _layers:
		bands.append({"from": l.depth_from, "to": l.depth_to, "darkness": l.darkness, "tint": l.light_tint})
	world.set_darkness(bands)
	for r: Rect2i in generator.pockets:
		_gushes.append({"rect": r, "t": -1.0, "acc": 0.0, "done": false, "cells": _cells_of(r)})
	_spawn_bodies()
	var keeper := Node2D.new()
	keeper.name = "Keeper"
	keeper.position = landing(0)
	world.add_child(keeper)
	world.track(keeper)
	_cages = Node2D.new()
	_cages.name = "Cages"
	_cages.z_index = 2
	_cages.draw.connect(_draw_cages)
	add_child(_cages)
	look = UndergroundLook.new()
	add_child(look)
	look.build(self)
	strange = StrangeBubble.new()
	add_child(strange)
	players_root = Node2D.new()
	players_root.name = "Players"
	add_child(players_root)
	hazards = Hazards.new()
	add_child(hazards)
	hazards.setup(self)
	residents = UndergroundResidents.new()
	add_child(residents)
	residents.setup(self)
	life = DepthLife.new()
	world.add_child(life)
	life.setup(self)
	dig_feel = DigFeel.new()
	world.add_child(dig_feel)
	dig_feel.setup(self)
	world.tile_dug.connect(_on_tile_dug)
	world.dig_blocked.connect(_on_dig_blocked)
	world.body_landed.connect(_on_body_landed)
	world.prop_broke.connect(_on_prop_broke)
	world.water_entered.connect(_on_water_entered)
	players_root.child_entered_tree.connect(_on_player_added)
	world.update_chunks()


func build_palette() -> Array[TileDef]:
	var air := TileDef.new()
	air.id = &"air"
	air.color = Color(0, 0, 0, 0)
	air.solid = false
	air.breakable = false
	var out: Array[TileDef] = [air]
	for id in BLOCK_ORDER:
		var b := load(BLOCK_DIR + String(id) + ".tres") as BlockData
		blocks[id] = b
		out.append(b)
	return out


static func load_rows(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			out.append(load(dir + file))
	return out


# --- API for HillGame and the HUD ---------------------------------------------------------------

func layers() -> Array:
	return _layers


func layer_index_at(pos: Vector2) -> int:
	return generator.layer_of_depth(int(floor(pos.y / 16.0)))


## Where a rider arriving at layer i stands (feet), beside the shaft.
func landing(layer_index: int) -> Vector2:
	var i := clampi(layer_index, 0, generator.landings.size() - 1)
	return Vector2((HillGenerator.SHAFT_X + 1) * 16.0, generator.landing_floor(i) * 16.0 - 2.0)


func cage_rect(layer_index: int) -> Rect2:
	var r := generator.cage_cells(layer_index)
	return Rect2(Vector2(r.position) * 16.0, Vector2(r.size) * 16.0 + Vector2(0, 4))


## The layer whose cage the feet at pos stand in, or -1.
func cage_zone_at(pos: Vector2) -> int:
	for i in generator.landings.size():
		if cage_rect(i).has_point(pos):
			return i
	return -1


func treasure_cell(id: StringName) -> Vector2i:
	for s in generator.treasure_spots:
		if s.id == id:
			return (s.rect as Rect2i).position
	# The frozen fish is not a seeded spot: the first rink's fish.
	if id == HillGenerator.FISH and not generator.fish_cells.is_empty():
		return generator.fish_cells[0]
	return Vector2i(-1, -1)


func get_camera_limits() -> Rect2:
	return Rect2(0, 0, WIDTH * 16.0, HEIGHT * 16.0)


func block_color(id: StringName) -> Color:
	var b: BlockData = blocks.get(id)
	return b.color if b else Color.SADDLE_BROWN


## The big Clay pocket has gushed (the demo waits for it).
func big_pocket_gushed() -> bool:
	return not _gushes.is_empty() and (_gushes[0].t > 0.0 or bool(_gushes[0].done))


func is_gushing() -> bool:
	for g in _gushes:
		if g.t > 0.0:
			return true
	return false


# --- bodies ------------------------------------------------------------------------------------

## Bodies come before the first chunk load, so they start asleep and indexed on their support.
func _spawn_bodies() -> void:
	var cs := 16.0
	for r: Rect2i in generator.boulder_spots:
		var b := FallingBody.new()
		b.name = "Boulder%d" % boulders.size()
		b.round = true
		b.size_px = Vector2.ONE * BOULDER_SIZE
		b.color = Color(0.62, 0.58, 0.54)
		b.collision_mask = 1 | 2
		b.position = Vector2((r.position.x + r.size.x * 0.5) * cs, r.end.y * cs - BOULDER_SIZE * 0.5)
		world.add_child(b)
		boulders.append(b)
	for s in generator.treasure_spots:
		var r: Rect2i = s.rect
		var prop := BreakableProp.new()
		prop.name = "%s_%d" % [s.id, (props.get(s.id, []) as Array).size()]
		prop.footprint = r.size
		prop.color = TREASURE_COLORS.get(s.id, Color("f2c94c"))
		prop.position = Vector2(r.position) * cs
		prop.set_meta(&"treasure", s.id)
		prop.whole = not BREAKS.has(s.id)
		world.add_child(prop)
		if not props.has(s.id):
			props[s.id] = []
		props[s.id].append(prop)


# --- world wiring ------------------------------------------------------------------------------

func _on_tile_dug(cell: Vector2i, block: StringName, player: int) -> void:
	Events.tile_dug.emit(cell, block, player)
	var data: BlockData = blocks.get(block)
	var cue := String(data.dig_sound) if data != null and data.dig_sound != &"" else "dig_%s" % block
	Audio.play(cue)
	burst(world.shape.center_of(cell), block_color(block), 10)
	for s in generator.treasure_spots:
		if not loose.has(s.id) and (s.rect as Rect2i).grow(2).has_point(cell) and not _under(s.rect, cell):
			_found(s.id, player, (s.rect as Rect2i))
	if player >= 0:
		grab_loose(_player_node(player))
	if generator.fish_at(cell) >= 0:
		_dig_fish(cell, player)
	for i in _gushes.size():
		var g: Dictionary = _gushes[i]
		if g.t < 0.0 and not g.done and (g.rect as Rect2i).grow(1).has_point(cell):
			start_gush(i)


## W-19: the row right under a treasure. Digging there does not find it: it comes loose instead
## (once enough of that row is gone) and is found when a player picks it up.
static func _under(rect: Rect2i, cell: Vector2i) -> bool:
	return cell.y == rect.end.y and cell.x >= rect.position.x and cell.x < rect.end.x


func _found(id: StringName, player: int, rect: Rect2i) -> void:
	if not Progress.find_treasure(id, player):
		return
	Audio.play(HillAudio.treasure_cue(id))
	var center := (Vector2(rect.position) + Vector2(rect.size) * 0.5) * 16.0
	burst(center, Color("fff2a8"), 24, 160.0)
	burst(center, Color("f2c94c"), 16, 90.0)
	var td := Progress.treasure_data(id)
	if td != null and not td.stays:
		_pick_up(id, player, center)
	treasure_dug.emit(id, player)


## W-11: a frozen fish dug out of a rink floor. The first one is the treasure (the reveal flies it
## into the bag, onto the shelf); every later one wiggles free and swims off (a splash, no treasure).
func _dig_fish(cell: Vector2i, player: int) -> void:
	if Progress.has_treasure(HillGenerator.FISH):
		if life != null:
			life.free_fish(cell)
		return
	_found(HillGenerator.FISH, player, Rect2i(cell, Vector2i.ONE))


## A pickup treasure: its prop (and any pieces) leaves the ground and the reveal pops it up over
## the finder (or the nearest player), then it flies into their bag.
func _pick_up(id: StringName, player: int, center: Vector2) -> void:
	for prop in props.get(id, []):
		_free_prop(prop, false)
	props.erase(id)
	var who: Node2D = _player_node(player)
	if who == null:
		var best := INF
		for c in players_root.get_children() if players_root != null else []:
			var d := (c as Node2D).global_position.distance_to(to_global(center))
			if d < best:
				best = d
				who = c
	var rv := TreasureReveal.new()
	rv.id = id
	rv.target = who
	rv.position = center
	world.add_child(rv)
	world.add_light(rv, 90.0)


func _player_node(p: int) -> Node2D:
	if p < 0 or players_root == null:
		return null
	for c in players_root.get_children():
		if c is HillPlayer and (c as HillPlayer).player == p:
			return c
	return null


## Frees a treasure prop and drops its lamp (UndergroundLook's "Glow") from the world's lights.
func _free_prop(prop: Variant, now: bool) -> void:
	if not is_instance_valid(prop):
		return
	var n := prop as Node
	for c in n.find_children("*", "Node2D", true, false):
		world.remove_light(c)
	world.remove_light(n as Node2D)
	if now:
		n.free()
	else:
		n.queue_free()


## After loading a save: found pickups are gone from the ground, hauled boulders stay hauled, and
## a treasure whose ground was dug away drops (or breaks) again, landing about where it was.
func after_load() -> void:
	for id: StringName in props.keys():
		var td := Progress.treasure_data(id)
		if td != null and not td.stays and Progress.has_treasure(id):
			for prop in props[id]:
				_free_prop(prop, true)
			props.erase(id)
	for id: StringName in props.keys():
		for prop in (props[id] as Array).duplicate():
			if prop is BreakableProp and is_instance_valid(prop):
				(prop as BreakableProp)._check_support()
	for i in Progress.hauled:
		if i >= 0 and i < boulders.size() and is_instance_valid(boulders[i]):
			boulders[i].free()


## The nearest boulder still in the ground within `reach` px of `pos`, as an index, or -1.
func boulder_near(pos: Vector2, reach: float) -> int:
	var best := -1
	var bd := reach
	for i in boulders.size():
		var b := boulders[i]
		if not is_instance_valid(b) or Progress.hauled.has(i):
			continue
		var d := b.global_position.distance_to(pos)
		if d <= bd:
			bd = d
			best = i
	return best


## The Crane hauls boulder `i` out: it is gone for good (saved in Progress.hauled).
func haul_boulder(i: int, player := -1) -> void:
	if i < 0 or i >= boulders.size() or Progress.hauled.has(i):
		return
	Progress.hauled.append(i)
	var b := boulders[i]
	if is_instance_valid(b):
		burst(b.position, Color(0.75, 0.7, 0.65), 14, 120.0)
		b.queue_free()
	boulder_hauled.emit(i, player)


func _on_dig_blocked(cell: Vector2i, block: StringName, player: int) -> void:
	Audio.play("dig_blocked")
	burst(world.shape.center_of(cell), Color.WHITE, 8, 70.0)
	if block == &"strangestone" and strange != null:
		strange.bounce(cell, player)


## V-07: a boulder (or piece) landing thumps the view of anyone near, more the closer and harder.
const FALL_NEAR := 14.0 * 16.0
func _on_body_landed(b: Node2D, speed: float) -> void:
	Audio.play("fall")
	if b == null or players_root == null:
		return
	_on_body_landed_loose(b)
	var at := to_local(b.global_position)
	for n in players_root.get_children():
		var pl := n as HillPlayer
		if pl == null:
			continue
		var d := to_local(pl.global_position).distance_to(at)
		if d < FALL_NEAR:
			var k := (1.0 - d / FALL_NEAR) * clampf(speed / 300.0, 0.4, 1.0)
			ScreenKick.kick(pl.player, 1.0 + 2.5 * k, 0.25)


## W-19 / W-20: a prop's ground went. A whole drop falls like a boulder (its picture, sparkle and
## lamp ride along); a break crumbles into picture chunks with a happy crumble. Pieces are loot, not
## walls: they land on tiles but never block a player. A pickup treasure is now loose (found when a
## player picks it up); one that stays (car, tooth, Gnome Room) is found now, as before.
func _on_prop_broke(prop: Node2D, pieces: Array) -> void:
	var bp := prop as BreakableProp
	var whole := bp != null and bp.whole
	var tint: Color = bp.color if bp != null else Color.WHITE
	if whole:
		Audio.play("pop")
		burst(prop.position + Vector2(bp.footprint) * 8.0, Color(0.8, 0.7, 0.55), 10, 70.0)
	else:
		Audio.play("wall_crumble")
		for piece in pieces:
			burst((piece as Node2D).position, tint.lightened(0.3), 4, 90.0)
	var now := Engine.get_physics_frames()
	for piece in pieces:
		(piece as FallingBody).collision_layer = 4
		# They do land on each other, so a crumbled car settles as a little heap, not one row.
		(piece as FallingBody).collision_mask |= 4
		(piece as Node).set_meta(&"loose_at", now)
	if not prop.has_meta(&"treasure"):
		return
	var id: StringName = prop.get_meta(&"treasure")
	if not whole:
		# Its lamp goes with the prop (freed next frame): drop it from the world's lights first.
		for c in prop.find_children("*", "Node2D", true, false):
			world.remove_light(c)
		world.remove_light(prop)
	var arr: Array = props.get(id, [])
	arr.erase(prop)
	arr.append_array(pieces)
	for piece in pieces:
		(piece as Node).set_meta(&"treasure", id)
	var td := Progress.treasure_data(id)
	if td != null and not td.stays:
		if not loose.has(id):
			loose[id] = []
		(loose[id] as Array).append_array(pieces)
		return
	if not whole:
		for piece in pieces:
			rubble.append(piece)
	_found(id, -1, Rect2i(world.shape.cell_at(prop.position + Vector2(8, 8)), bp.footprint))


func _on_body_landed_loose(b: Node2D) -> void:
	if b.has_meta(&"treasure") and loose.has(b.get_meta(&"treasure")):
		# A loose treasure lands with a little sparkle: it is still there to pick up.
		burst(b.position + Vector2(0, -6), Color("fff2a8"), 8, 70.0)


func _on_player_added(n: Node) -> void:
	var pl := n as HillPlayer
	if pl != null and not pl.swung.is_connected(_on_swung):
		pl.swung.connect(_on_swung.bind(pl))


func _on_swung(_cell: Vector2i, pl: HillPlayer) -> void:
	grab_loose(pl)


## W-19 / W-20: the player's A picks up the nearest loose thing in reach, once it has landed. A
## loose treasure is found (the reveal pops it over them and all of its pieces go); a chunk of the
## car or the Gnome Room pops into their backpack as one block of the layer (a full backpack: a
## puff and it stays). True when something was picked up.
func grab_loose(pl: HillPlayer) -> bool:
	if pl == null or not is_instance_valid(pl) or not pl.is_inside_tree():
		return false
	var at := world.to_local(pl.global_position) - Vector2(0, pl.body_size().y * 0.5)
	var best: FallingBody = null
	var bd := INF
	for b in _loose_bodies():
		var d := world.local_pos(b).distance_to(at)
		if d < bd and d <= GRAB_REACH + maxf(b.size_px.x, b.size_px.y) * 0.5 and _landed(b):
			bd = d
			best = b
	if best == null:
		return false
	var id: StringName = best.get_meta(&"treasure", &"")
	if loose.has(id):
		for b in loose[id]:
			if is_instance_valid(b):
				burst((b as Node2D).position, Color("fff2a8"), 8, 80.0)
		loose.erase(id)
		var cell := world.shape.cell_at(world.local_pos(best))
		_found(id, pl.player, Rect2i(cell, Vector2i.ONE))
		return true
	var block := main_block_at(world.local_pos(best).y)
	if not pl.keep_block(block):
		burst(world.local_pos(best), Color(1, 1, 1, 0.8), 6, 60.0)
		Audio.play("backpack_full")
		return false
	rubble.erase(best)
	Audio.play("pop")
	burst(world.local_pos(best), block_color(block), 10, 100.0)
	best.queue_free()
	return true


func _loose_bodies() -> Array[FallingBody]:
	var out: Array[FallingBody] = []
	for id in loose:
		for b in loose[id]:
			if is_instance_valid(b):
				out.append(b)
	for b in rubble:
		if is_instance_valid(b):
			out.append(b)
	return out


func _landed(b: FallingBody) -> bool:
	var since := Engine.get_physics_frames() - int(b.get_meta(&"loose_at", 0))
	return since >= GRAB_AFTER_FRAMES and (b.sleeping or b.linear_velocity.length() < 40.0)


## The main block (biggest block_mix share) of the layer at depth y (px).
func main_block_at(y: float) -> StringName:
	var l: LayerData = _layers[clampi(layer_index_at(Vector2(0, y)), 0, _layers.size() - 1)]
	var best: StringName = &"dirt"
	var bw := -1.0
	for b in l.block_mix:
		if float(l.block_mix[b]) > bw and blocks.has(StringName(b)):
			bw = float(l.block_mix[b])
			best = StringName(b)
	return best


func _on_water_entered(cell: Vector2i) -> void:
	Audio.play("flood")
	burst(world.shape.center_of(cell), Color(0.4, 0.7, 1.0), 8)


## Contract "Water gush": a breached pocket (index into generator.pockets, 0 = the big Clay one)
## refills its emptied cells for GUSH_TIME.
func start_gush(i := 0) -> void:
	if i < 0 or i >= _gushes.size():
		return
	var g: Dictionary = _gushes[i]
	g.t = GUSH_TIME
	g.acc = 0.0
	Audio.play("flood")
	var r: Rect2i = g.rect
	burst((Vector2(r.position) + Vector2(r.size) * 0.5) * 16.0, Color(0.5, 0.8, 1.0), 20, 140.0)


func _physics_process(delta: float) -> void:
	for g: Dictionary in _gushes:
		if g.t > 0.0:
			_step_gush(g, delta)
	_drain_t += delta
	if _drain_t >= DRAIN_EVERY:
		_drain_t = 0.0
		drain(Progress.count_buildings(&"water_tower") * DRAIN_PER_TOWER)


## Water Towers up top: removes up to `n` water cells near each player underground (nearest first,
## the gush's refill still runs). Returns how many went.
func drain(n: int) -> int:
	if n <= 0 or players_root == null or players_root.get_child_count() == 0:
		return 0
	var cells := world.water_cells()
	if cells.is_empty():
		return 0
	var gone := 0
	for c in players_root.get_children():
		var at := world.shape.cell_at(world.to_local((c as Node2D).global_position))
		var near: Array = cells.filter(func(w: Vector2i) -> bool:
			return absi(w.x - at.x) <= DRAIN_REACH and absi(w.y - at.y) <= DRAIN_REACH)
		near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
		for k in mini(n, near.size()):
			world.set_water(near[k], false)
			cells.erase(near[k])
			gone += 1
	return gone


func _step_gush(g: Dictionary, delta: float) -> void:
	g.t -= delta
	g.acc += delta
	while g.acc >= GUSH_TICK:
		g.acc -= GUSH_TICK
		var n := 0
		for c: Vector2i in g.cells:
			if n >= GUSH_PER_TICK:
				break
			if world.is_loaded(c) and not world.is_solid(c) and not world.has_water(c):
				world.set_water(c, true)
				n += 1
	if g.t <= 0.0:
		g.t = -1.0
		g.done = true


## A one-shot particle puff in the world, freed when it finishes.
func burst(pos: Vector2, color: Color, amount: int, speed := 110.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 5
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = color
	p.finished.connect(p.queue_free)
	world.add_child(p)
	p.emitting = true


func _cells_of(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.end.y - 1, r.position.y - 1, -1):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


# --- drawing -----------------------------------------------------------------------------------

func _draw_backdrop(back: Node2D) -> void:
	for l: LayerData in _layers:
		var top := l.depth_from * 16.0
		var h := (mini(l.depth_to, HEIGHT) - l.depth_from) * 16.0
		back.draw_rect(Rect2(0, top, WIDTH * 16.0, h), l.hue.darkened(0.78))
	# The shaft: a darker column with rails from landing to landing.
	var x0 := HillGenerator.SHAFT_X * 16.0
	back.draw_rect(Rect2(x0, 0, 32, HEIGHT * 16.0), Color(0.05, 0.04, 0.06))


func _draw_cages() -> void:
	if look:
		look.draw_cages(_cages)
		return
	var bar := Color("c9c9c9")
	var gold := Color("f2c94c")
	var x0 := HillGenerator.SHAFT_X * 16.0
	for i in generator.landings.size():
		var r := cage_rect(i)
		r.size.y -= 4
		var flash := cage_flash if i == flash_layer else 0.0
		# Rails up to the previous landing's floor, over the rock: the shaft reads as one line.
		if i > 0:
			var top := generator.landing_floor(i - 1) * 16.0 + 16.0
			for rx in [x0 + 2.0, x0 + 30.0]:
				_cages.draw_line(Vector2(rx, top), Vector2(rx, r.position.y - 3), Color(0.55, 0.5, 0.45, 0.7), 2.0)
		_cages.draw_rect(r.grow(1.0), DARK, false, 2.0)
		_cages.draw_rect(Rect2(r.position.x - 1, r.position.y - 3, r.size.x + 2, 3), gold)
		if flash > 0.0:
			_cages.draw_rect(r, Color(gold, 0.6 * flash))
		for k in 4:
			var x := r.position.x + 4 + k * (r.size.x - 8) / 3.0
			_cages.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y * maxf(flash, 0.15)), bar, 1.0)
		# The layer's hue as a lamp over the door, so each landing has its own colour.
		var l: LayerData = _layers[i]
		_cages.draw_circle(Vector2(r.position.x - 10, r.position.y + 4), 4.0, l.hue.lightened(0.3))
