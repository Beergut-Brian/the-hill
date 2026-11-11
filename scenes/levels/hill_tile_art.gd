## The Hill's tile art (palette A "Sandbox"): terrain tiles by palette id, texture variant and open
## mask from `tiles/terrain.png`, back walls by layer from `tiles/walls.png` behind dug cells only.
## Cells that were air in the base world (caves, the Bottom cavern, landing rooms) get no wall, so
## the parallax backdrop shows there. Sheet layouts: .scratch/ART_SPEC.md, sizes from the manifest.
class_name HillTileArt
extends TileArt

const TERRAIN := "res://assets/sprites/tiles/terrain.png"
const WALLS := "res://assets/sprites/tiles/walls.png"
const MANIFEST := "res://assets/sprites/manifest.json"
const VARIANTS := 4

var generator: HillGenerator
var collision_layer := 1
var cell := 16
var _tile_set: TileSet
## Palette id -> the palette id whose terrain column it is drawn with (tiles with no column of their
## own, such as the C-22 puzzle tiles; Puzzles draws their detail over them).
var looks_like: Dictionary = {}


func _init(p_generator: HillGenerator, p_collision_layer := 1) -> void:
	generator = p_generator
	collision_layer = p_collision_layer
	var m := manifest()
	var t: Dictionary = m.get("terrain", m.get("tiles/terrain", {}))
	if t.has("frame"):
		cell = int(t.frame[0])


## True when the sheets are imported (tests and tools can run without the art).
static func available() -> bool:
	return ResourceLoader.exists(TERRAIN) and ResourceLoader.exists(WALLS)


static func manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return d if d is Dictionary else {}


func tile_set() -> TileSet:
	if _tile_set:
		return _tile_set
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cell, cell)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, collision_layer)
	var h := cell * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var terrain := _atlas(load(TERRAIN))
	ts.add_source(terrain, SOLID_SOURCE)
	for at in _coords(terrain):
		terrain.create_tile(at)
		var td := terrain.get_tile_data(at, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
	var walls := _atlas(load(WALLS))
	ts.add_source(walls, WALL_SOURCE)
	for at in _coords(walls):
		walls.create_tile(at)
	_tile_set = ts
	return ts


func _atlas(tex: Texture2D) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(cell, cell)
	return src


func _coords(src: TileSetAtlasSource) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size := src.texture.get_size() / cell
	for y in int(size.y):
		for x in int(size.x):
			out.append(Vector2i(x, y))
	return out


func solid_coords(c: Vector2i, id: int, open: int) -> Vector2i:
	id = int(looks_like.get(id, id))
	return Vector2i((id - 1) * VARIANTS + cell_hash(c) % VARIANTS, open)


func wall_coords(c: Vector2i, base_id: int, ceiling: bool) -> Vector2i:
	if base_id <= 0:
		return NO_TILE
	var layer := clampi(generator.layer_of_depth(c.y), 0, 5)
	return Vector2i(layer * VARIANTS + cell_hash(c) % VARIANTS, 1 if ceiling else 0)
