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
## Every water pocket; pockets[0] is the big Clay pocket (`pocket`), the rest come from data/hazards.
var pockets: Array[Rect2i] = []
## Cave-in zones: [{rect: Rect2i (loose ground), layer: int, block: StringName}], from data/hazards.
var cave_ins: Array = []
## W-13 ice holes: [{rink: Rect2i (air, its floor row is ice), hole: Rect2i (the chute's columns,
## from the rink floor down to the nest), nest: Rect2i (air at the bottom, a layer down), dir: int
## (+1 when the hole is at the rink's right end), layer: int}], from data/hazards kind ice_hole.
var ice_holes: Array = []
## W-14 lava pockets: [{room: Rect2i (air), pool: Rect2i (the bottom air row's middle: the bounce
## pad), layer: int}], from data/hazards kind lava_pocket.
var lava_pockets: Array = []
## W-11: one frozen fish per ice rink, in a floor block (dig it out: Underground). Not seeded by
## the treasure rows; FISH is the TreasureData id the first one counts as.
const FISH := &"frozen_fish"
var fish_cells: Array[Vector2i] = []
## Cells forced to one tile whatever the noise says: [[Rect2i, tile], ...] (rink and nest floors).
var _forced: Array = []
## Columns of a hole: wide enough for every vehicle (the Drill Rig is 56 px).
const HOLE_W := 4
const NEST := Vector2i(8, 4)

var _ids: Dictionary = {}           # block id -> palette index
var _mix: Array = []                # per layer: [[tile, cumulative weight], ...] heaviest first
var _mix_noise: FastNoiseLite
var _carved: Array[Rect2i] = []
var _calm: Array[Rect2i] = []
var _layer_lut := PackedInt32Array()
## C-17: palette index -> the block's depth_from. A mix entry deeper than the cell falls back to
## the layer's main block (Sand only in the lower Stone layer).
var _min_depth: Dictionary = {}
## Minor kinds per layer index (LayerData.minor_kinds): [[palette index, share, shape, depth_from,
## depth_to], ...]. They only ever replace a main-block cell outside the calm rects (landings,
## treasures, the pocket), so the rest of a seeded world is unchanged by them.
var _minor: Array = []
var _minor_seed := 0
var _vein_noise: FastNoiseLite
## |vein noise| below share * VEIN_K is an ore streak (tuned so the share is about right).
const VEIN_K := 0.55


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
var _hazards: Array = []            # HazardData rows
## PT10-4: the unlock zones, [{gate: DepthGate, from: int, to: int (exclusive), layer: int}] by
## depth. Every cell of those rows (inside the edges) is Gate Rock, whatever was carved there.
var gate_bands: Array = []
var gate_tile := 0
## Hard Rock's palette index (configure_gates) and the rows under a band it keeps clear of.
var hard_tile := -1
const HARD_CLEAR := 6


## DepthGate rows (data/gates) and the Gate Rock palette index. Without them: no bands.
func configure_gates(gates: Array, tile: int, p_hard_tile := -1) -> void:
	gate_bands = []
	gate_tile = tile
	hard_tile = p_hard_tile
	if tile <= 0:
		return
	for g: DepthGate in gates:
		var li := _layer_index(g.opens)
		if li <= 0:
			continue
		var from: int = (layer_rows[li] as LayerData).depth_from
		gate_bands.append({"gate": g, "from": from - g.rows + 1, "to": from + 1, "layer": li})
	gate_bands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.from < b.from)


## The band holding depth `row`, or {}.
func gate_band_at(row: int) -> Dictionary:
	for b: Dictionary in gate_bands:
		if row >= b.from and row < b.to:
			return b
	return {}


## BlockData rows by id (Underground.blocks): mix entries obey each block's depth_from.
func configure_block_depths(blocks: Dictionary) -> void:
	_min_depth = {}
	for k in blocks:
		var b := blocks[k] as BlockData
		if b != null and _ids.has(b.id):
			_min_depth[int(_ids[b.id])] = b.depth_from
	_minor = []
	for l: LayerData in layer_rows:
		var list: Array = []
		for k in l.minor_kinds:
			var m := blocks.get(StringName(str(k))) as BlockData
			if m != null and _ids.has(m.id):
				list.append([int(_ids[m.id]), float(l.minor_kinds[k]), m.minor_shape, m.depth_from, m.depth_to])
		list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		_minor.append(list)

## Near a landing: this many tiles left or right of the shaft, this many rows under the room.
const NEAR_X := Vector2i(10, 30)
const NEAR_Y := 16


## HazardData rows (data/hazards). Without them the generator keeps the first-playable layout.
func configure_hazards(rows: Array) -> void:
	_hazards = rows.duplicate()
	_hazards.sort_custom(func(a: HazardData, b: HazardData) -> bool: return String(a.id) < String(b.id))


func _hazard_count(layer: StringName, kind: StringName, fallback: int) -> int:
	var n := 0
	var any := false
	for h: HazardData in _hazards:
		if h.layer == layer and h.kind == kind:
			n += h.count
			any = true
	return n if any else fallback


func setup(p_shape: WorldShape, p_seed: int) -> void:
	super.setup(p_shape, p_seed)
	_mix_noise = FastNoiseLite.new()
	_mix_noise.seed = p_seed + 7
	_mix_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mix_noise.frequency = 0.11
	_mix_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_minor_seed = p_seed
	_vein_noise = FastNoiseLite.new()
	_vein_noise.seed = p_seed + 911
	_vein_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_vein_noise.frequency = 0.09
	_vein_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
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
	# The first three (the ones that stay put) are placed here with the main rng, exactly as in the
	# first playable; the pickups come after the hazards with their own rng (_plan_pickups), so
	# adding treasure rows never moves the car, the boulders or the hazards.
	for t: TreasureData in _treasures:
		if not t.stays:
			continue
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
		var want := _hazard_count(id, &"boulder", 4)
		for attempt in 40:
			if made >= want:
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
	_plan_hazards(p_seed)
	_plan_pickups(p_seed)
	_plan_deep(p_seed)
	_carved.append(CAVERN)


## The pickup treasures (TreasureData.stays false), by id so the order never depends on the folder.
func _plan_pickups(p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 4111
	var rows := _treasures.filter(func(t: TreasureData) -> bool: return not t.stays and t.id != FISH)
	rows.sort_custom(func(a: TreasureData, b: TreasureData) -> bool: return String(a.id) < String(b.id))
	for t: TreasureData in rows:
		var li := _layer_index(t.layer)
		if li < 0:
			continue
		var l: LayerData = layer_rows[li]
		for n in maxi(t.count, 1):
			var r := _hazard_spot(rng, l, li, t.footprint, t.near_landing and n == 0)
			if r.size == Vector2i.ZERO:
				r = _hazard_spot(rng, l, li, t.footprint, false)
			if r.size == Vector2i.ZERO:
				continue
			treasure_spots.append({"id": t.id, "rect": r, "layer": li})
			_carved.append(Rect2i(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 1))
			_calm.append(r.grow(3))


## data/hazards rows on their own random stream (the first-playable layout above never moves):
## boulders in layers other than Clay and Stone, extra water pockets, cave-in zones. `near_landing`
## of each row go within NEAR_X / NEAR_Y of the layer's landing, the rest anywhere in the layer.
func _plan_hazards(p_seed: int) -> void:
	pockets.clear()
	cave_ins.clear()
	if pocket.size != Vector2i.ZERO:
		pockets.append(pocket)
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 7919
	for h: HazardData in _hazards:
		var li := _layer_index(h.layer)
		if li < 0:
			continue
		if h.kind == &"boulder" and (h.layer == &"clay" or h.layer == &"stone"):
			continue
		if h.kind == &"ice_hole" or h.kind == &"lava_pocket":
			continue   # _plan_deep, on its own stream
		var l: LayerData = layer_rows[li]
		var size := Vector2i(2, 2) if h.kind == &"boulder" else h.size
		for n in h.count:
			var r := _hazard_spot(rng, l, li, size, n < h.near_landing)
			if r.size == Vector2i.ZERO:
				continue
			match h.kind:
				&"boulder":
					boulder_spots.append(r)
					_carved.append(r)
					_calm.append(r.grow(2))
				&"water_pocket":
					pockets.append(r)
					_carved.append(r)
					_calm.append(r.grow(3))
				&"cave_in":
					cave_ins.append({"rect": r, "layer": li, "block": _main_block(l)})
					_calm.append(r.grow(2))


## Ice holes and lava pockets on a third random stream, after everything else (so adding them
## moved nothing that was already placed). Each keeps clear of every calm area.
func _plan_deep(p_seed: int) -> void:
	ice_holes.clear()
	lava_pockets.clear()
	_forced.clear()
	fish_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 104729
	for h: HazardData in _hazards:
		var li := _layer_index(h.layer)
		if li < 0 or (h.kind != &"ice_hole" and h.kind != &"lava_pocket"):
			continue
		var l: LayerData = layer_rows[li]
		var main := int(_ids.get(_main_block(l), 1))
		for n in h.count:
			for attempt in 8:
				var r := _hazard_spot(rng, l, li, h.size, n < h.near_landing)
				if r.size == Vector2i.ZERO:
					continue
				if h.kind == &"ice_hole":
					if _try_ice_hole(r, li, main):
						break
				else:
					var floor_r := Rect2i(r.position.x - 1, r.end.y, r.size.x + 2, 1)
					lava_pockets.append({"room": r, "pool": Rect2i(r.position.x + 2, r.end.y - 1, r.size.x - 4, 1), "layer": li})
					_carved.append(r)
					_calm.append(r.grow(3))
					_forced.append([floor_r, main])
					break


## A rink in layer li: ice floor, a HOLE_W-wide hole at the end away from the shaft whose chute
## drops to a nest at the top of the next layer down. False (nothing placed) if the chute hits a
## calm area.
func _try_ice_hole(r: Rect2i, li: int, ice_tile: int) -> bool:
	var dir := 1 if r.get_center().x > SHAFT_X else -1
	var hx := r.end.x - HOLE_W if dir > 0 else r.position.x
	var nest_y := r.end.y + 8
	if li + 1 < layer_rows.size():
		nest_y = (layer_rows[li + 1] as LayerData).depth_from + 2
	if nest_y + NEST.y + 1 >= STRANGE_FROM:
		return false
	var hole := Rect2i(hx, r.end.y, HOLE_W, nest_y - r.end.y)
	var nest := Rect2i(hx - (NEST.x - HOLE_W) / 2, nest_y, NEST.x, NEST.y)
	if _hits_calm(r.grow(2)) or _hits_calm(hole.grow(1)) or _hits_calm(nest.grow(2)):
		return false
	ice_holes.append({"rink": r, "hole": hole, "nest": nest, "dir": dir, "layer": li})
	_carved.append(r)
	_carved.append(hole)
	_carved.append(nest)
	_calm.append(r.grow(2))
	_calm.append(hole.grow(1))
	_calm.append(nest.grow(2))
	# The rink's floor is all ice (the layer has some stone); the nest's floor is solid.
	var floor_x := r.position.x - 1 if dir > 0 else r.position.x + HOLE_W
	_forced.append([Rect2i(floor_x, r.end.y, r.size.x - HOLE_W + 1, 1), ice_tile])
	# The frozen fish: in the floor, a third of the way from the rink's far end (away from the hole).
	var solid_w := r.size.x - HOLE_W
	var fx := r.position.x + solid_w / 3 if dir > 0 else r.end.x - 1 - solid_w / 3
	fish_cells.append(Vector2i(fx, r.end.y))
	var under := layer_of_depth(nest.end.y)
	_forced.append([Rect2i(nest.position.x - 1, nest.end.y, nest.size.x + 2, 1), int(_ids.get(_main_block(layer_rows[under]), 1))])
	return true


## The ice hole (index into ice_holes) whose chute or nest holds `cell`, or -1.
func ice_hole_at(cell: Vector2i) -> int:
	for i in ice_holes.size():
		if (ice_holes[i].hole as Rect2i).has_point(cell) or (ice_holes[i].nest as Rect2i).has_point(cell):
			return i
	return -1


func _hazard_spot(rng: RandomNumberGenerator, l: LayerData, li: int, size: Vector2i, near: bool) -> Rect2i:
	var floor_y := landing_floor(li)
	for attempt in 60:
		var x: int
		var y: int
		if near:
			var off := rng.randi_range(NEAR_X.x, NEAR_X.y)
			x = SHAFT_X + 1 + off if rng.randf() < 0.5 else SHAFT_X - off - size.x
			y = rng.randi_range(floor_y + 2, floor_y + NEAR_Y)
		else:
			x = rng.randi_range(EDGE + 3, WIDTH - EDGE - 4 - size.x)
			y = rng.randi_range(l.depth_from + 4, mini(l.depth_to, STRANGE_FROM) - 4 - size.y)
		var r := Rect2i(x, y, size.x, size.y)
		if y + size.y >= mini(l.depth_to, STRANGE_FROM) or x < EDGE + 2 or r.end.x > WIDTH - EDGE - 2:
			continue
		if not _hits_calm(r.grow(2)):
			return r
	return Rect2i()


static func _main_block(l: LayerData) -> StringName:
	var best: StringName = &"dirt"
	var w := -1.0
	for k in l.block_mix:
		if float(l.block_mix[k]) > w:
			w = float(l.block_mix[k])
			best = StringName(str(k))
	return best


## The cave-in zone (index into cave_ins) whose loose ground holds `cell`, or -1.
func cave_in_at(cell: Vector2i) -> int:
	for i in cave_ins.size():
		if (cave_ins[i].rect as Rect2i).has_point(cell):
			return i
	return -1


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
	if gate_tile > 0:
		for b: Dictionary in gate_bands:
			if cell.y >= b.from and cell.y < b.to:
				return gate_tile
	for r in _carved:
		if r.has_point(cell):
			if r == CAVERN and not _in_cavern(cell):
				break
			return 0
	for f in _forced:
		if (f[0] as Rect2i).has_point(cell):
			return int(f[1])
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
	var pick: int = (_mix[li] as Array).back()[0]
	for e in _mix[li]:
		if v < e[1]:
			pick = e[0]
			break
	var main: int = (_mix[li] as Array)[0][0]
	var depth := shape.depth_of(cell)
	if int(_min_depth.get(pick, 0)) > depth:
		pick = main
	if pick == main and li < _minor.size() and not (_minor[li] as Array).is_empty():
		var m := _minor_tile(cell, depth, _minor[li])
		# PT10-4: no Hard Rock in a layer's first rows, so breaking a band never lands on it.
		if m > 0 and m == hard_tile and depth < (layer_rows[li] as LayerData).depth_from + HARD_CLEAR:
			return pick
		if m > 0 and not _in_calm(cell):
			return m
	return pick


## The minor kind (palette index) laid into this main-block cell, or 0. Shapes (BlockData.minor_shape):
## run = flat runs of 6 in slots of 8, on every fourth row; patch = clumps in a 3x3 grid; vein =
## thin streaks along a zero line of a noise; dot = lone cells.
func _minor_tile(cell: Vector2i, depth: int, list: Array) -> int:
	for e in list:
		if depth < int(e[3]) or depth >= int(e[4]):
			continue
		var share: float = e[1]
		var salt: int = int(e[0]) * 7919
		var hit := false
		match StringName(e[2]):
			&"run":
				var off := posmod(cell.x, 8)
				hit = posmod(cell.y, 4) == 1 and off >= 1 and off <= 6 \
						and _h01(floori(cell.x / 8.0), cell.y, salt) < share * 4.0 * 8.0 / 6.0
			&"patch":
				hit = _h01(floori(cell.x / 3.0), floori(cell.y / 3.0), salt) < share * 1.5 \
						and _h01(cell.x, cell.y, salt + 1) < 0.67
			&"vein":
				hit = absf(_vein_noise.get_noise_3d(cell.x, cell.y, salt)) < share * VEIN_K
			_:
				hit = _h01(cell.x, cell.y, salt) < share
		if hit:
			return int(e[0])
	return 0


func _in_calm(cell: Vector2i) -> bool:
	for c in _calm:
		if c.has_point(cell):
			return true
	return false


## A stable 0..1 hash of (x, y, salt) and the world seed.
func _h01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ ((salt + _minor_seed) * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


## The fish (index into fish_cells) frozen in `cell`, or -1.
func fish_at(cell: Vector2i) -> int:
	return fish_cells.find(cell)


func base_water(cell: Vector2i) -> bool:
	for p in pockets:
		if p.has_point(cell):
			return true
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
