## Which cells exist, how they group into chunks, and which way is down.
## The chunk manager, falling bodies and water only ever ask a WorldShape, so a new world
## (a rectangle, a disk planet) is a new subclass and nothing else. See docs/contracts.md.
## Cells are always squares on one Cartesian grid, y down; only grouping and gravity differ.
class_name WorldShape
extends RefCounted

var cell_size: int = 16
var gravity: float = 980.0


func contains(_cell: Vector2i) -> bool:
	return false


## The chunk key of a cell.
func chunk_of(_cell: Vector2i) -> Vector2i:
	return Vector2i.ZERO


## Every cell of that chunk (only cells inside the shape).
func chunk_cells(_key: Vector2i) -> Array[Vector2i]:
	return []


## Chunk keys to keep alive around a node in chunk `key`. Includes `key`. No duplicates.
func neighbourhood(_key: Vector2i, _radius: int = 1) -> Array[Vector2i]:
	return []


## Acceleration in px/s^2 at a world position.
func gravity_at(_pos: Vector2) -> Vector2:
	return Vector2.ZERO


## The cell that supports this one (one step along gravity).
func below(cell: Vector2i) -> Vector2i:
	return cell


## The two cells level with this one; water spreads there.
func sides(cell: Vector2i) -> Array[Vector2i]:
	return [cell, cell]


## Tiles below the surface.
func depth_of(_cell: Vector2i) -> int:
	return 0


func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i((pos / float(cell_size)).floor())


func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)
