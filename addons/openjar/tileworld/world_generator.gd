## The seeded base world. Subclass it per game; TileWorld stores only the differences from it.
## Both functions must be deterministic for a (shape, seed) and independent of call order.
class_name WorldGenerator
extends RefCounted

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
