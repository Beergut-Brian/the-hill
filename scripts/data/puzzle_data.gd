## C-22: one underground engineering puzzle (data/puzzles/<id>.tres). HillGenerator places `count`
## of them in `layer` per seed, on their own random stream, only when that layer's LayerData lists
## `kind` in its `hazards`. The cells are unbreakable by hand (the world's edgestone tile) and drawn
## over with the puzzle's own picture (Puzzles); only the rule below opens them.
##   &"boulder_wall": a cracked slab (`size`: its width x rows) of `block` (data/blocks) with a boulder
##       resting GAP rows above it and a small chamber under it (a stone floor). Dig under the boulder:
##       it drops, and when `block`'s BlockData.boulder_breaks is on, a body big and fast enough
##       (BlockData.boulder_min_px / boulder_min_speed) breaks the whole slab open.
##   &"vehicle_block": a heavy block (`size` cells, the world's unbreakable edgestone underneath).
##       Only `vehicle` digging at it moves it: `hits` digs and it is gone, `gives` x `gives_count`
##       into that vehicle's backpack.
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
## boulder_wall: the BlockData id the slab is made of (its boulder_* fields are the break rule).
@export var block: StringName = &"hardrock"
## vehicle_block: the VehicleData id that clears it, and how many of its digs it takes.
@export var vehicle: StringName = &""
@export var hits: int = 2
## What clearing gives (block id, how many), into the clearing vehicle's backpack.
@export var gives: StringName = &""
@export var gives_count: int = 0
