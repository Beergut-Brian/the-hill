## The Hill's underground: six layers from data/layers (each cell's block picked from its layer's
## block_mix by seeded noise, so Clay has some dirt), Edgestone on the left and right edges,
## Strangestone floor, noise caves, a big open cavern in The Bottom, the elevator shaft with a
## landing room at the top of every layer, a big water pocket in Clay beside the Clay landing,
## boulder cavities in Clay and Stone, and a small cavity for every treasure placement. All
## placements come from the seed in setup(), so they are deterministic and call-order independent.
## Tiles and water only; underground.gd spawns the boulders and the treasure props.
class_name HillGenerator
extends LayeredGenerator

const WIDTH := 200
const HEIGHT := 300
const SHAFT_X := 99                 # shaft columns 99..100
const EDGE := 2                     # edgestone columns on each side
const STRANGE_FROM := 294
const ROOM_HALF := 6                # landing room x 93..106
const ROOM_H := 3                   # rows of air in a landing room; floor below
const CAVERN := Rect2i(24, 266, 152, 24)
## The car sits this many columns left of the shaft (seeded inside this range).
const CAR_REACH := Vector2i(10, 25)

var layer_rows: Array = []          # LayerData sorted by depth
var strange_tile := 0
## Seeded placements, filled by setup().
var landings: Array[Rect2i] = []    # per layer: the room's air
var pocket := Rect2i()              # the big Clay water pocket
var treasure_spots: Array = []      # [{id: StringName, rect: Rect2i (footprint cells), layer: int}]
var boulder_spots: Array[Rect2i] = []   # 2x2 cavities, the boulder sits on the floor

var _ids: Dictionary = {}           # block id -> palette index
var _mix: Array = []                # per layer: [[tile, cumulative weight], ...] heaviest first
var _mix_noise: FastNoiseLite
var _carved: Array[Rect2i] = []
var _calm: Array[Rect2i] = []
var _layer_lut := PackedInt32Array()


## layers: LayerData rows; ids: block id -> palette index; treasures: TreasureData rows.
func configure(layers: Array, ids: Dictionary, treasures: Array = []) -> void:
	layer_rows = layers.duplicate()
	layer_rows.sort_custom(func(a: LayerData, b: LayerData) -> bool: return a.depth_from < b.depth_from)
	_ids = ids
	_treasures = treasures
	bands = []
	_mix = []
	for l: LayerData in layer_rows:
		var entries: Array = []
		var total := 0.0
		for k in l.block_mix:
			entries.append([int(ids.get(StringName(str(k)), 1)), float(l.block_mix[k])])
			total += float(l.block_mix[k])
		entries.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		var acc := 0.0
		for e in entries:
			acc += e[1] / maxf(total, 0.0001)
			e[1] = acc
		_mix.append(entries)
		bands.append({"from": l.depth_from, "tile": entries[0][0] if not entries.is_empty() else 1})
	border_tile = int(ids.get(&"edgestone", 0))
	strange_tile = int(ids.get(&"strangestone", 0))
	water_from_depth = -1
	cave_threshold = 0.6
	cave_min_depth = 6

var _treasures: Array = []


func setup(p_shape: WorldShape, p_seed: int) -> void:
	super.setup(p_shape, p_seed)
	_mix_noise = FastNoiseLite.new()
	_mix_noise.seed = p_seed + 7
	_mix_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mix_noise.frequency = 0.11
	_mix_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_layer_lut = PackedInt32Array()
	_layer_lut.resize(HEIGHT)
	for d in HEIGHT:
		var idx := 0
		for i in layer_rows.size():
			if d >= (layer_rows[i] as LayerData).depth_from:
				idx = i
		_layer_lut[d] = idx
	_plan(p_seed)


## Floor row of layer i's landing (the cage stands on it).
func landing_floor(i: int) -> int:
	return landings[i].end.y


func cage_cells(i: int) -> Rect2i:
	var f := landing_floor(i)
	return Rect2i(SHAFT_X, f - 2, 2, 2)


func layer_of_depth(depth: int) -> int:
	if _layer_lut.is_empty():
		return 0
	return _layer_lut[clampi(depth, 0, HEIGHT - 1)]


func _plan(p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	landings.clear()
	_carved.clear()
	_calm.clear()
	treasure_spots.clear()
	boulder_spots.clear()
	for i in layer_rows.size():
		var from: int = (layer_rows[i] as LayerData).depth_from
		var top := 9 if i == 0 else from + 1
		var room := Rect2i(SHAFT_X - ROOM_HALF, top, ROOM_HALF * 2 + 2, ROOM_H)
		landings.append(room)
		_carved.append(room)
		_calm.append(room.grow(5))
	# The shaft mouth above the first landing (as in the prototype).
	_carved.append(Rect2i(SHAFT_X, 1, 2, landings[0].position.y - 1))
	_calm.append(Rect2i(86, 0, 30, 14))
	# The big water pocket: right of the Clay landing, its top three rows level with the landing
	# room, so a tunnel dug sideways from the landing breaks into it, spills and floods.
	var clay := _layer_index(&"clay")
	if clay >= 0:
		var f := landing_floor(clay)
		pocket = Rect2i(SHAFT_X + 14 + rng.randi_range(0, 3), f - 3, 10, 8)
		_carved.append(pocket)
		_calm.append(pocket.grow(3))
	# Treasures: every row `count` times in its layer; the Buried Car beside the Clay landing.
	for t: TreasureData in _treasures:
		var li := _layer_index(t.layer)
		if li < 0:
			continue
		var l: LayerData = layer_rows[li]
		for n in maxi(t.count, 1):
			var fp := t.footprint
			var r := Rect2i()
			if t.id == &"buried_car" and n == 0 and li == clay:
				var f := landing_floor(clay)
				var off := rng.randi_range(CAR_REACH.x, CAR_REACH.y)
				r = Rect2i(SHAFT_X - off - fp.x, f + 2, fp.x, fp.y)
			else:
				for attempt in 30:
					var x := rng.randi_range(EDGE + 3, WIDTH - EDGE - 4 - fp.x)
					var y := rng.randi_range(l.depth_from + 4, mini(l.depth_to, STRANGE_FROM) - 4 - fp.y)
					r = Rect2i(x, y, fp.x, fp.y)
					if not _hits_calm(r.grow(2)):
						break
			treasure_spots.append({"id": t.id, "rect": r, "layer": li})
			# The cavity: one free cell above and beside the prop, its floor stays solid.
			_carved.append(Rect2i(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 1))
			_calm.append(r.grow(3))
	# Boulders: a few in Clay and Stone, each resting on the floor of a 2x2 cavity.
	for id: StringName in [&"clay", &"stone"]:
		var li := _layer_index(id)
		if li < 0:
			continue
		var l: LayerData = layer_rows[li]
		var made := 0
		for attempt in 40:
			if made >= 4:
				break
			var x := rng.randi_range(EDGE + 3, WIDTH - EDGE - 6)
			var y := rng.randi_range(l.depth_from + 4, l.depth_to - 4)
			var r := Rect2i(x, y, 2, 2)
			if _hits_calm(r.grow(2)):
				continue
			boulder_spots.append(r)
			_carved.append(r)
			_calm.append(r.grow(2))
			made += 1
	_carved.append(CAVERN)


func _layer_index(id: StringName) -> int:
	for i in layer_rows.size():
		if (layer_rows[i] as LayerData).id == id:
			return i
	return -1


func _hits_calm(r: Rect2i) -> bool:
	for c in _calm:
		if c.intersects(r):
			return true
	return false


func is_edge(cell: Vector2i) -> bool:
	return cell.x < EDGE or cell.x >= WIDTH - EDGE


func base_tile(cell: Vector2i) -> int:
	if not shape.contains(cell):
		return 0
	if is_edge(cell) or cell.y == 0:
		return border_tile
	if cell.y >= STRANGE_FROM:
		return strange_tile
	for r in _carved:
		if r.has_point(cell):
			if r == CAVERN and not _in_cavern(cell):
				break
			return 0
	if cell.y >= cave_min_depth and _noise.get_noise_2d(cell.x, cell.y) > cave_threshold:
		var calm := false
		for c in _calm:
			if c.has_point(cell):
				calm = true
				break
		if not calm:
			return 0
	return _mix_tile(cell)


## A rounded cavern: an ellipse inside CAVERN with a flat floor.
func _in_cavern(cell: Vector2i) -> bool:
	var c := Vector2(CAVERN.get_center())
	var h := Vector2(CAVERN.size) * 0.5
	var d := (Vector2(cell) + Vector2(0.5, 0.5) - c) / h
	if cell.y >= int(c.y):
		return absf(d.x) < 1.0
	return d.length_squared() < 1.0


func _mix_tile(cell: Vector2i) -> int:
	var li := layer_of_depth(shape.depth_of(cell))
	if li >= _mix.size() or (_mix[li] as Array).is_empty():
		return _band_tile(shape.depth_of(cell))
	var v := clampf(_mix_noise.get_noise_2d(cell.x, cell.y) * 0.9 + 0.5, 0.0, 0.9999)
	for e in _mix[li]:
		if v < e[1]:
			return e[0]
	return (_mix[li] as Array).back()[0]


func base_water(cell: Vector2i) -> bool:
	return pocket.has_point(cell)


func base_chunk(cells: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(cells.size())
	var i := 0
	for c in cells:
		var v := base_tile(c)
		if v == 0 and base_water(c):
			v = WATER_BIT
		out[i] = v
		i += 1
	return out
