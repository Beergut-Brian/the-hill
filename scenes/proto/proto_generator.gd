## The prototype's underground: LayeredGenerator bands from data/layers (each band's tile is the
## heaviest block in its block_mix), an edgestone rim, strangestone at the bottom, and a
## hand-authored set piece near the top centre that overrides the noise so the demo is deterministic:
## elevator shaft, landing room, boulder cavity, buried-car cavity and a water pocket.
## Tiles and water only; proto_underground.gd spawns the boulder and the prop.
class_name ProtoGenerator
extends LayeredGenerator

const SHAFT := Rect2i(99, 1, 2, 8)          # x 99..100, y 1..8
const LANDING := Rect2i(96, 9, 8, 3)        # x 96..103, y 9..11; floor is row 12
const CAGE := Rect2i(99, 10, 2, 2)          # bottom of the shaft: the underground cage zone
const BOULDER_CAVITY := Rect2i(109, 8, 2, 2)
const PROP_CAVITY := Rect2i(113, 8, 3, 2)
const WATER_POCKET := Rect2i(119, 6, 8, 4)  # floor is row 10: the tunnel breaches it
const CALM := Rect2i(88, 0, 47, 19)         # x 88..134, y 0..18: no noise caves here
const STRANGE_FROM := 294

var strange_tile := 0


## layers: LayerData rows; ids: block id -> palette index.
func configure(layers: Array, ids: Dictionary) -> void:
	var sorted := layers.duplicate()
	sorted.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	bands = []
	water_from_depth = -1
	for l: LayerData in sorted:
		var best: StringName = &""
		var weight := -INF
		for k in l.block_mix:
			if float(l.block_mix[k]) > weight:
				weight = float(l.block_mix[k])
				best = StringName(str(k))
		bands.append({"from": l.depth_from, "tile": int(ids.get(best, 1))})
		if water_from_depth < 0 and l.hazards.has(&"water_pocket"):
			water_from_depth = l.depth_from
	border_tile = int(ids.get(&"edgestone", 0))
	strange_tile = int(ids.get(&"strangestone", 0))


func base_tile(cell: Vector2i) -> int:
	if _carved(cell):
		return 0
	if strange_tile > 0 and shape.depth_of(cell) >= STRANGE_FROM and not _on_rim(cell):
		return strange_tile
	if CALM.has_point(cell):
		if border_tile > 0 and _on_rim(cell):
			return border_tile
		return _band_tile(shape.depth_of(cell))
	return super.base_tile(cell)


func base_water(cell: Vector2i) -> bool:
	if WATER_POCKET.has_point(cell):
		return true
	if CALM.has_point(cell):
		return false
	return super.base_water(cell)


func _carved(cell: Vector2i) -> bool:
	for r in [SHAFT, LANDING, BOULDER_CAVITY, PROP_CAVITY, WATER_POCKET]:
		if (r as Rect2i).has_point(cell):
			return true
	return false
