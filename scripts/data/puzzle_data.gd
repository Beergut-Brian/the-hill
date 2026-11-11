## C-22: one underground engineering puzzle (data/puzzles/<id>.tres). HillGenerator places `count`
## of them in `layer` per seed, on their own random stream, only when that layer's LayerData lists
## `kind` in its `hazards`. The cells are unbreakable by hand (the world's edgestone tile) and drawn
## over with the puzzle's own picture (Puzzles); only the rule below opens them.
##   &"boulder_wall": a cracked slab (`size`: its width x rows) with a boulder resting GAP rows above
##       it and a small chamber under it (an ore floor). Dig under the boulder: it drops, and a body at
##       least `min_body_px` wide landing on the slab at `min_speed` px/s or more breaks it open.
##   &"vehicle_block": a heavy block (`size` cells). Only `vehicle` digging at it moves it: `hits`
##       digs and it is gone, `gives` x `gives_count` into that vehicle's backpack.
class_name PuzzleData
extends Resource

@export var kind: StringName
@export var id: StringName
## LayerData id.
@export var layer: StringName
@export var count: int = 1
## Of `count`, how many sit near the layer's landing (HillGenerator.NEAR_X / NEAR_Y).
@export var near_landing: int = 0
@export var size: Vector2i = Vector2i(8, 1)
## boulder_wall: the smallest body (px across) and landing speed (px/s) that break the slab.
@export var min_body_px: float = 20.0
@export var min_speed: float = 120.0
## vehicle_block: the VehicleData id that clears it, and how many of its digs it takes.
@export var vehicle: StringName = &""
@export var hits: int = 2
## What clearing gives (block id, how many), into the clearing vehicle's backpack.
@export var gives: StringName = &""
@export var gives_count: int = 0
