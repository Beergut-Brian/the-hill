## Optional tile art for a TileWorld (docs/contracts.md "Tile art and the light pass"). Set
## `TileWorld.tile_art` before `setup()`. The world asks it for one TileSet and, per cell, which atlas
## tile to draw: solid cells by their open mask, air cells by their back wall (or none).
## The default implementation reproduces the flat look: override all three in a game subclass.
class_name TileArt
extends RefCounted

## Open-mask bits: that side touches a cell that is not solid.
const OPEN_UP := 1
const OPEN_RIGHT := 2
const OPEN_DOWN := 4
const OPEN_LEFT := 8
## Atlas source ids in tile_set().
const SOLID_SOURCE := 0
const WALL_SOURCE := 1
const NO_TILE := Vector2i(-1, -1)


## Source 0: solid tiles (with collision on physics layer 0); source 1: back walls (no collision).
func tile_set() -> TileSet:
	return null


## Atlas coords in source 0 for a solid cell with tile id `id`. `open`: OPEN_* bits.
func solid_coords(_cell: Vector2i, id: int, _open: int) -> Vector2i:
	return Vector2i(id - 1, 0)


## Atlas coords in source 1 for an air cell whose base tile is `base_id` (0: air in the base world).
## `ceiling`: the cell above is solid. NO_TILE: no wall, whatever is behind the world shows.
func wall_coords(_cell: Vector2i, _base_id: int, _ceiling: bool) -> Vector2i:
	return NO_TILE


## A cheap, stable hash of a cell (for picking texture variants).
static func cell_hash(cell: Vector2i) -> int:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff
