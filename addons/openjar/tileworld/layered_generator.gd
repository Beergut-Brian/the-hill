## A simple default generator that works with ANY WorldShape: it only asks `shape.depth_of(cell)`.
## Bands of tiles by depth, air above `surface_depth`, an optional unbreakable border on the rim of
## the shape, a few noise caves, and water pockets (caves deeper than `water_from_depth` start full).
## No boulders: bodies are the game's business. Deterministic per seed, call-order independent.
class_name LayeredGenerator
extends WorldGenerator

## [{from: int, tile: int}, ...]: the tile at a depth is the last band whose `from` <= depth.
var bands: Array = [{"from": 0, "tile": 1}]
## Cells shallower than this are air (0 = no air).
var surface_depth := 0
## When > 0: cells with a 4-neighbour outside the shape get this tile (make it unbreakable).
var border_tile := 0
## Noise caves: a cell is cave air where noise > cave_threshold (noise is about -1..1; > 1 = none).
var cave_threshold := 0.55
var cave_frequency := 0.06
## Caves start this many tiles below the surface at the earliest.
var cave_min_depth := 4
## Caves at or deeper than this start full of water (< 0 = no water).
var water_from_depth := -1
var water_pockets := true

var _noise: FastNoiseLite


func setup(p_shape: WorldShape, p_seed: int) -> void:
	super.setup(p_shape, p_seed)
	_noise = FastNoiseLite.new()
	_noise.seed = p_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = cave_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var sorted := bands.duplicate()
	sorted.sort_custom(func(a, b): return int(a["from"]) < int(b["from"]))
	bands = sorted


func base_tile(cell: Vector2i) -> int:
	var depth := shape.depth_of(cell)
	if depth < surface_depth:
		return 0
	if border_tile > 0 and _on_rim(cell):
		return border_tile
	if _is_cave(cell, depth):
		return 0
	return _band_tile(depth)


func base_water(cell: Vector2i) -> bool:
	if not water_pockets or water_from_depth < 0:
		return false
	var depth := shape.depth_of(cell)
	if depth < water_from_depth or depth < surface_depth:
		return false
	if border_tile > 0 and _on_rim(cell):
		return false
	return _is_cave(cell, depth)


func _band_tile(depth: int) -> int:
	var tile := 0
	for b in bands:
		if depth >= int(b["from"]):
			tile = int(b["tile"])
	return tile


func _is_cave(cell: Vector2i, depth: int) -> bool:
	if depth < surface_depth + cave_min_depth:
		return false
	return _noise.get_noise_2d(cell.x, cell.y) > cave_threshold


func _on_rim(cell: Vector2i) -> bool:
	return not (shape.contains(cell + Vector2i.LEFT) and shape.contains(cell + Vector2i.RIGHT)
			and shape.contains(cell + Vector2i.UP) and shape.contains(cell + Vector2i.DOWN))
