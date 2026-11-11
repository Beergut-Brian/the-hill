## One underground engineering puzzle (C-22) in one layer (data/puzzles/<id>.tres). HillGenerator
## places it on its own seeded stream after every other placement, so adding puzzles moves nothing.
## Kid-safe by contract: no text, nothing taken, solved with the stick and A; the reward is a gift
## of blocks that pops with a sparkle.
##   drain        A flooded pocket behind a dirt wall, a nook, a drain plug, a chute to a dry sump.
##                Dig the wall (the channel) and open the plug: the water runs away.
##   boulder_wall A boulder on a wooden strut over a drop onto a cracked wall a shovel bounces off.
##                Knock the strut out: the boulder falls and breaks the wall into pieces.
##   heavy_block  A heavy stone block in a tunnel. Hand digging bounces; the Front Loader or the
##                Dump Truck lifts it out.
class_name PuzzleData
extends Resource

@export var kind: StringName
@export var id: StringName
## LayerData id.
@export var layer: StringName
## Placed within NEAR_X / NEAR_Y of the layer's landing (met in the first minutes) when it fits.
@export var near_landing: bool = true
## Blocks of the layer's main block the gift gives when the puzzle is solved.
@export var gift: int = 6
## heavy_block: VehicleData ids that lift it.
@export var lifted_by: Array[StringName] = []
