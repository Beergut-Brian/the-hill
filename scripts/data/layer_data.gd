## One depth band of the underground (data/layers/<id>.tres), ordered by depth_from.
class_name LayerData
extends Resource

@export var id: StringName
@export var depth_from: int
## Exclusive.
@export var depth_to: int
## Block id -> weight (float).
@export var block_mix: Dictionary
## Minor kinds (GAME.md's Blocks column): block id -> share (0..1) of the layer's main-block cells
## it takes, laid out by the block's `minor_shape`. Applied after block_mix and only to main-block
## cells, so every other cell of a seeded world is the same with or without them.
@export var minor_kinds: Dictionary = {}
## &"water_pocket", &"boulder", &"mole", &"lava" ...
@export var hazards: Array[StringName]
## 0 daylight .. 1 black, before Lighthouses.
@export var darkness: float
## Colour of the darkness (blue glow in Ice).
@export var light_tint: Color = Color.BLACK
## 0..1, dragon_snore loudness in this layer.
@export var snore_volume: float
## The layer's dominant hue (art direction, depth strip).
@export var hue: Color


## depth_from <= depth < depth_to.
func contains(depth: int) -> bool:
	return depth >= depth_from and depth < depth_to
