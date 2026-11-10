## Prototype underground: a TileWorld (RectShape 200 x 300) over a dark backdrop, palette from
## data/blocks, ProtoGenerator bands from data/layers, depth darkness from the LayerData rows, the
## set piece's boulder and buried car, and the elevator cage drawn at the bottom of the shaft.
## A hidden keeper is tracked at the landing so the set piece stays loaded and live from the start.
class_name ProtoUnderground
extends Node2D

const BLOCK_ORDER: Array[StringName] = [&"dirt", &"clay", &"stone", &"ice", &"crystal", &"edgestone", &"strangestone"]
const BLOCK_DIR := "res://data/blocks/"
const LAYER_DIR := "res://data/layers/"
const WIDTH := 200
const HEIGHT := 300
const ARRIVAL := Vector2(1600, 190)
const BOULDER_SIZE := 24.0

@export var world_seed := 20261109

var world: TileWorld
var blocks: Dictionary = {}    # StringName -> BlockData
var boulder: FallingBody
var prop: BreakableProp
var cage_flash := 0.0:
	set(v):
		cage_flash = v
		if _cage:
			_cage.queue_redraw()

var _cage: Node2D


func _ready() -> void:
	name = "Underground"
	var shape := RectShape.new(WIDTH, HEIGHT)
	var palette := build_palette()
	var ids := {}
	for i in palette.size():
		ids[palette[i].id] = i
	var gen := ProtoGenerator.new()
	gen.configure(load_layers(), ids)
	var cs := float(shape.cell_size)
	var back := Node2D.new()
	back.name = "Backdrop"
	back.z_index = -100
	back.draw.connect(func() -> void:
		back.draw_rect(Rect2(0, 0, WIDTH * cs, HEIGHT * cs), Color("24160d")))
	add_child(back)
	world = TileWorld.new()
	world.name = "World"
	world.add_to_group(&"tile_world")
	world.setup(shape, gen, palette, world_seed)
	add_child(world)
	var bands: Array = []
	for l: LayerData in load_layers():
		bands.append({"from": l.depth_from, "to": l.depth_to, "darkness": l.darkness, "tint": l.light_tint})
	world.set_darkness(bands)
	_spawn_set_piece(cs)
	var keeper := Node2D.new()
	keeper.name = "Keeper"
	keeper.position = ARRIVAL
	world.add_child(keeper)
	world.track(keeper)
	_cage = Node2D.new()
	_cage.name = "Cage"
	_cage.z_index = 2
	_cage.draw.connect(_draw_cage)
	add_child(_cage)
	var players := Node2D.new()
	players.name = "Players"
	add_child(players)
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


func load_layers() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(LAYER_DIR):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			out.append(load(LAYER_DIR + file))
	out.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	return out


## Bodies are added before the first chunk load, so they come up asleep and indexed on their support.
func _spawn_set_piece(cs: float) -> void:
	var bc := ProtoGenerator.BOULDER_CAVITY
	boulder = FallingBody.new()
	boulder.name = "Boulder"
	boulder.round = true
	boulder.size_px = Vector2.ONE * BOULDER_SIZE
	boulder.color = Color(0.62, 0.58, 0.54)
	boulder.collision_mask = 1 | 2
	boulder.position = Vector2((bc.position.x + bc.size.x * 0.5) * cs, bc.end.y * cs - BOULDER_SIZE * 0.5)
	world.add_child(boulder)
	var pc := ProtoGenerator.PROP_CAVITY
	prop = BreakableProp.new()
	prop.name = "BuriedCar"
	prop.footprint = pc.size
	prop.color = Color("d9534f")
	prop.position = Vector2(pc.position) * cs
	world.add_child(prop)


func get_camera_limits() -> Rect2:
	var cs := float(world.shape.cell_size)
	return Rect2(0, 0, WIDTH * cs, HEIGHT * cs)


func cage_zone() -> Rect2:
	var cs := float(world.shape.cell_size)
	var r := ProtoGenerator.CAGE
	return Rect2(Vector2(r.position) * cs, Vector2(r.size) * cs + Vector2(0, 4))


func _draw_cage() -> void:
	var r := cage_zone()
	r.size.y -= 4
	var dark := Color(0.07, 0.06, 0.09)
	var bar := Color("c9c9c9")
	_cage.draw_rect(r.grow(1.0), dark, false, 2.0)
	_cage.draw_rect(Rect2(r.position.x - 1, r.position.y - 3, r.size.x + 2, 3), Color("f2c94c"))
	if cage_flash > 0.0:
		_cage.draw_rect(r, Color("f2c94c", 0.6 * cage_flash))
	for i in 4:
		var x := r.position.x + 4 + i * (r.size.x - 8) / 3.0
		_cage.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y * maxf(cage_flash, 0.15)), bar, 1.0)
