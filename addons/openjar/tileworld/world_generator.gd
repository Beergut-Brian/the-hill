## The seeded base world. Subclass it per game; TileWorld stores only the differences from it.
## Both functions must be deterministic for a (shape, seed) and independent of call order.
class_name WorldGenerator
extends RefCounted

## In base_chunk results: set when the cell starts full of water.
const WATER_BIT := 1 << 20

var shape: WorldShape
var world_seed: int


func setup(p_shape: WorldShape, p_seed: int) -> void:
	shape = p_shape
	world_seed = p_seed


## Tile id (palette index) of a cell before any edit. 0 is air.
func base_tile(_cell: Vector2i) -> int:
	return 0


## True when this air cell starts full of water (a water pocket).
func base_water(_cell: Vector2i) -> bool:
	return false


## Every cell of a chunk at once (TileWorld calls this when it loads a chunk): one entry per cell,
## base_tile(cell), | WATER_BIT when base_water(cell). Override it for speed; it must agree with
## base_tile and base_water.
func base_chunk(cells: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(cells.size())
	var i := 0
	for c in cells:
		out[i] = base_tile(c) | (WATER_BIT if base_water(c) else 0)
		i += 1
	return out
