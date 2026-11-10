## The underground: a TileWorld (RectShape 200 x 300) built by HillGenerator from data/layers and
## data/blocks, a backdrop tinted by layer, a landing room with a cage at the top of every layer,
## boulders, the seeded treasure props, darkness bands from LayerData and the water gush.
## Wires the world's signals to Events, Audio and particle bursts. HillGame owns the players and
## adds them under the "Players" child (the director does that); HillGame gives them headlamps.
class_name Underground
extends Node2D

signal treasure_dug(id: StringName, player: int)

const BLOCK_ORDER: Array[StringName] = [&"dirt", &"clay", &"stone", &"ice", &"crystal", &"edgestone", &"strangestone"]
const BLOCK_DIR := "res://data/blocks/"
const LAYER_DIR := "res://data/layers/"
const TREASURE_DIR := "res://data/treasures/"
const WIDTH := HillGenerator.WIDTH
const HEIGHT := HillGenerator.HEIGHT
const DEFAULT_SEED := 20261110
const BOULDER_SIZE := 26.0
## Contract "Water gush": a breached pocket refills its emptied cells for this long.
const GUSH_TIME := 2.0
const GUSH_TICK := 0.1
const GUSH_PER_TICK := 6
const TREASURE_COLORS := {&"buried_car": Color("d9534f"), &"giant_tooth": Color("f4f1e6"), &"gnome_room": Color("8e6c4a")}
const DARK := Color(0.07, 0.06, 0.09)

@export var world_seed := DEFAULT_SEED

var world: TileWorld
var generator: HillGenerator
var blocks: Dictionary = {}          # StringName -> BlockData
var props: Dictionary = {}           # StringName treasure id -> Array[BreakableProp]
var boulders: Array[FallingBody] = []
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
var _gush := {"t": -1.0, "acc": 0.0, "done": false, "cells": []}


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
	var back := Node2D.new()
	back.name = "Backdrop"
	back.z_index = -100
	back.draw.connect(_draw_backdrop.bind(back))
	add_child(back)
	world = TileWorld.new()
	world.name = "World"
	world.add_to_group(&"tile_world")
	world.setup(shape, generator, palette, world_seed)
	add_child(world)
	var bands: Array = []
	for l: LayerData in _layers:
		bands.append({"from": l.depth_from, "to": l.depth_to, "darkness": l.darkness, "tint": l.light_tint})
	world.set_darkness(bands)
	for c in _cells_of(generator.pocket):
		_gush.cells.append(c)
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
	players_root = Node2D.new()
	players_root.name = "Players"
	add_child(players_root)
	world.tile_dug.connect(_on_tile_dug)
	world.dig_blocked.connect(_on_dig_blocked)
	world.body_landed.connect(func(_b: Node2D, _s: float) -> void: Audio.play("fall"))
	world.prop_broke.connect(_on_prop_broke)
	world.water_entered.connect(_on_water_entered)
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
	return Vector2i(-1, -1)


func get_camera_limits() -> Rect2:
	return Rect2(0, 0, WIDTH * 16.0, HEIGHT * 16.0)


func block_color(id: StringName) -> Color:
	var b: BlockData = blocks.get(id)
	return b.color if b else Color.SADDLE_BROWN


func is_gushing() -> bool:
	return _gush.t > 0.0


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
		if (s.rect as Rect2i).grow(2).has_point(cell):
			_found(s.id, player, (s.rect as Rect2i))
	if _gush.t < 0.0 and not _gush.done and generator.pocket.size != Vector2i.ZERO \
			and generator.pocket.grow(1).has_point(cell):
		start_gush()


func _found(id: StringName, player: int, rect: Rect2i) -> void:
	if not Progress.find_treasure(id, player):
		return
	Audio.play("treasure")
	var center := (Vector2(rect.position) + Vector2(rect.size) * 0.5) * 16.0
	burst(center, Color("fff2a8"), 24, 160.0)
	burst(center, Color("f2c94c"), 16, 90.0)
	treasure_dug.emit(id, player)


func _on_dig_blocked(cell: Vector2i, _block: StringName, _player: int) -> void:
	Audio.play("dig_blocked")
	burst(world.shape.center_of(cell), Color.WHITE, 8, 70.0)


func _on_prop_broke(prop: Node2D, pieces: Array) -> void:
	Audio.play("prop_break")
	for piece in pieces:
		# Pieces are loot, not walls: they land on tiles but never block a player.
		(piece as FallingBody).collision_layer = 4
	if prop.has_meta(&"treasure"):
		var id: StringName = prop.get_meta(&"treasure")
		var bp := prop as BreakableProp
		_found(id, -1, Rect2i(world.shape.cell_at(prop.position + Vector2(8, 8)), bp.footprint))


func _on_water_entered(cell: Vector2i) -> void:
	Audio.play("flood")
	burst(world.shape.center_of(cell), Color(0.4, 0.7, 1.0), 8)


## Contract "Water gush": the breached pocket refills its emptied cells for GUSH_TIME.
func start_gush() -> void:
	_gush.t = GUSH_TIME
	_gush.acc = 0.0
	Audio.play("flood")
	burst((Vector2(generator.pocket.position) + Vector2(generator.pocket.size) * 0.5) * 16.0, Color(0.5, 0.8, 1.0), 20, 140.0)


func _physics_process(delta: float) -> void:
	if _gush.t <= 0.0:
		return
	_gush.t -= delta
	_gush.acc += delta
	while _gush.acc >= GUSH_TICK:
		_gush.acc -= GUSH_TICK
		var n := 0
		for c: Vector2i in _gush.cells:
			if n >= GUSH_PER_TICK:
				break
			if world.is_loaded(c) and not world.is_solid(c) and not world.has_water(c):
				world.set_water(c, true)
				n += 1
	if _gush.t <= 0.0:
		_gush.t = -1.0
		_gush.done = true


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
