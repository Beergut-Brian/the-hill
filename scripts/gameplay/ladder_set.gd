## PT10-7c: ladders underground, a hook for the Gnome crew (data/ladders.tres; empty for now).
## A ladder is one column of cells from `top` to `bottom` row. A player on foot whose body is on a
## ladder cell climbs it with up / down (no gravity while on it) and hangs there with the stick let
## go. The crew (or anything else) adds ladders at runtime with add(); ShaftRope draws them as two
## rails and rungs until Art gives them a sprite.
class_name LadderSet
extends Resource

## Ladders as Vector3i(column, top row, bottom row).
@export var ladders: Array[Vector3i] = []
## Climb speed on a ladder (px/s).
@export var climb_speed: float = 110.0

const PATH := "res://data/ladders.tres"


static func load_default() -> LadderSet:
	if ResourceLoader.exists(PATH):
		var t := load(PATH) as LadderSet
		if t != null:
			return t.duplicate(true)
	return LadderSet.new()


## Adds a ladder in `column` from row `top` to row `bottom` (inclusive).
func add(column: int, top: int, bottom: int) -> void:
	ladders.append(Vector3i(column, mini(top, bottom), maxi(top, bottom)))
	emit_changed()


func clear() -> void:
	ladders.clear()
	emit_changed()


## True when `cell` is on a ladder.
func at(cell: Vector2i) -> bool:
	for l in ladders:
		if cell.x == l.x and cell.y >= l.y and cell.y <= l.z:
			return true
	return false
